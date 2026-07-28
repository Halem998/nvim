# Implementation Plan: Serialize every specs/state.json writer through one mutex-guarded helper

- **Task**: 942 - Serialize every specs/state.json writer through one mutex-guarded helper
- **Status**: [IMPLEMENTING]
- **Effort**: 13 hours
- **Dependencies**: None
- **Research Inputs**: specs/942_serialize_state_json_writers/reports/01_serialize-state-json-writers.md
- **Artifacts**: plans/01_serialize-state-json-writers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every `specs/state.json` read-modify-write in the core extension currently rolls its own
`jq > tmp && mv` sequence: nine scripts plus two inline command-file write blocks, only two of
which acquire the `specs/.scope-lock` mutex — and both of those fail OPEN on acquire timeout,
so the lock stops applying under exactly the contention it exists for. A second, independent
corruption channel runs alongside: five scripts stage through fixed, shared temp paths with
unconditional `rm -f` EXIT traps, so one process's normal exit deletes another's in-flight
staging file regardless of any mutex work. This plan builds one shared helper,
`agent-system/extensions/core/scripts/state-write.sh`, implementing a single
acquire-fail-closed -> private `mktemp` -> jq transform -> `jq empty` validate -> `mv` ->
optional in-mutex TODO.md regen -> release sequence, then converts every writer to call it so no
hand-rolled tmp-and-mv sequence remains. Definition of done: a repo-wide grep over the source
store finds zero remaining `state.json`-targeted tmp-and-mv sequences outside `state-write.sh`,
and a new isolated-temp-root concurrency suite proves both no-lost-update and staging-file
isolation.

**Binding constraint for every phase**: all edits target `agent-system/extensions/core/**`.
`.claude/**` is a gitignored, disposable deploy artifact and must NEVER be an edit target.
Runtime invocation paths inside the edited files still reference `.claude/scripts/...` — that is
the call path, not the edit target. See `.claude/rules/source-store-deploy-boundary.md`.

**Deliverable rule**: no file authored or edited by this plan outside `specs/**` may cite a task
number. Use durable anchors — script names, function names, mechanism names.

### Research Integration

The research report re-measured the baseline at the script level and confirmed it, while raising
the real conversion surface materially and adding two defects the baseline missed. Findings
folded directly into the phase decomposition:

- **Site count is higher than the writer count.** `orchestrator-postflight.sh` alone has ~6
  internal read-modify-write sites and `skill-base.sh` has 4 live ones. Those two scripts each
  get their own phase rather than sharing one with the smaller writers.
- **Two orphaned functions should be deleted, not converted.** `skill-base.sh`'s
  `skill_increment_artifact_number` and `skill_propagate_memory_candidates` are never called;
  `orchestrator-postflight.sh` reimplements both inline. Deleting them shrinks the conversion
  surface by two sites and removes a silent-divergence trap (Recommendation 1).
- **Four sites have no atomicity at all.** `orchestrator-postflight.sh` Stages 7a/7c and the two
  orphaned `skill-base.sh` functions write via `python3 json.load`/`json.dump` directly back to
  `specs/state.json` — no temp file, no `mv`. These convert to jq transforms
  (`.next_artifact_number = (.next_artifact_number // 1) + 1`, `.memory_candidates += $new` via
  `--argjson`), which also removes the fragile triple-quoted-string JSON interpolation.
- **New temp-path collision pair.** `archive-task.sh`'s `"${STATE_FILE}.tmp"` and
  `commands/review.md`'s task-creation write both resolve to the byte-identical literal
  `specs/state.json.tmp` (directly under `specs/`, not `specs/tmp/`).
- **The release ownership check is verified safe.** All five current `task-lock.sh release`
  callers pass the identical `session_id` string used at their matching acquire, so adding the
  check breaks none of them. `cmd_scope_release`/`cmd_commit_release` are the exact
  WARN-and-no-op-always-return-0 precedent to mirror.
- **`generate-todo.sh` needs no internal change.** Its own output write is already atomic
  (`mktemp` + `mv`); the hazard is a lost update on TODO.md itself, closed entirely by caller
  discipline — regen inside the mutex, before release.
- **The deploy gap is real and pre-identified.** Adding `state-write.sh` to `manifest.json`'s
  `provides.scripts` is necessary but not sufficient: headless "Load Core" sync skips
  `copy_scripts` for already-loaded extensions. This gets an explicit manual step, not an
  assumption.

Conversion ordering below follows Recommendation 3 (lowest-risk/most-isolated first).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and `roadmap_flag` is not set, so no
roadmap phases are added. A read-only consultation of `specs/ROADMAP.md` found no items matching
concurrency, serialization, mutex, or state.json themes; this task advances no currently-listed
roadmap item.

## Goals & Non-Goals

**Goals**:
- One shared write helper implementing exactly one serialization sequence, in the source store.
- All nine writers plus both inline command-file `specs/state.json` writes converted to call it;
  zero hand-rolled tmp-and-mv sequences remaining.
- Bounded-retry-then-FAIL-CLOSED mutex acquisition replacing today's fail-open-on-timeout.
- Per-process `mktemp` staging with per-process-scoped EXIT traps, closing the shared-temp
  corruption channel.
- `task-lock.sh cmd_release` verifies caller ownership before removing the lock directory.
- TODO.md regeneration happens inside the same mutex as the write that triggered it.
- `.claude/tmp/workflow-active` becomes per-session across its one writer and all three
  consumers.
- An isolated-temp-root concurrency suite proving no-lost-update and staging-file isolation.

**Non-Goals**:
- Converting extension `SKILL.md` inline `state.json` writes (web, cslib, memory, present,
  python, typst, lean, latex, nix, nvim, z3, founder, epidemiology, formal, literature). Out of
  `file_scope`; recorded as a follow-up in the final phase, not designed here.
- `commands/review.md`'s writes against `specs/reviews/state.json` — a different file, out of
  scope. Only its two `specs/state.json` sites are converted.
- `archive-task.sh`'s write to `archive/state.json` — a different file, out of scope. Only its
  `del()` removal from `specs/state.json` is converted.
- Any change to `cmd_scope_acquire`, `cmd_scope_release`, `cmd_commit_acquire`, or
  `cmd_commit_release`, which already match the target fail-closed + owner-verified pattern.
- Any change to `generate-todo.sh`'s internal write logic.
- Sibling session-scoping work in the same topic (soft build-order preference only; no hard
  dependency edge in either direction).
- Fixing the extension-loader deploy gap itself. This plan works around it with an explicit
  manual step and records it as an open follow-up.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq output formatting for `next_artifact_number` / `memory_candidates` differs from today's `python3 json.dump(..., indent=2)` (key order, int-vs-float) | M | M | Diff a sample `specs/state.json` before/after in the conversion phase. All downstream readers use `jq`, never raw string diffing, so only gross structural change matters. Gate the phase on the diff being confined to the intended keys |
| Fail-closed acquire converts "slow but eventually succeeds" into hard failure under real contention | H | M | This is the explicitly accepted trade-off. Mitigate by surfacing the non-zero exit loudly with an `ABORT:`-prefixed message matching `cmd_acquire`'s existing pattern, so orchestration retry logic can react rather than silently stalling |
| Reentrancy regression: the helper deadlocks against an outer `SCOPE_MUTEX_HELD=1` holder, breaking every `orchestrator-postflight.sh` run that invokes `update-task-status.sh` as a child | H | M | Honor `SCOPE_MUTEX_HELD` as guest-mode exactly as `acquire_state_mutex` already does; cover the nested case explicitly in the concurrency suite before any conversion phase runs |
| `cmd_release` ownership check strands a lock if a future caller passes a different session_id at release than at acquire | M | L | WARN-and-no-op, never force-refuse, always `return 0` — mirroring `cmd_scope_release` exactly. A mismatched future caller degrades to "not released, logged loudly", preserving the existing "release must never fail a caller's cleanup" contract |
| Partial `workflow-active` conversion (writer updated, `wezterm-preflight-status.sh`'s unconditional `rm -f` left alone) silently reintroduces the cross-session deletion hazard | M | M | Convert writer and all three consumers in ONE phase declared `Commit Mode: atomic-batch`; never split across phases |
| Manifest registration does not reach this repo's already-deployed `.claude/scripts/`, so the implementation tests green in the source store while the live runtime still lacks the helper | H | H | Dedicated phase performing the one-off loader-primitive copy and verifying the deployed file exists and is executable; identical to the documented workaround for the shared task-reference pattern library |
| A converted call site silently changes behavior because the helper's jq-filter interface cannot express its transform | M | L | Interface is an arbitrary jq filter plus `--arg`/`--argjson` passthrough, verified against the three real transform shapes (single-task field update, top-level array mutation, `$cands`-scoped bulk `|=`) before any conversion begins |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5, 6, 7, 9 | 3 |
| 4 | 8, 10 | 6, 7 |
| 5 | 11 | 4, 5, 8, 9, 10 |

Phases within the same wave can execute in parallel. Note that Phase 2 (`task-lock.sh`) touches
a file no other phase edits, so it carries no ordering constraint against the conversion chain.

---

### Phase 1: Build the shared `state-write.sh` helper [COMPLETED]

- **Goal:** Create `agent-system/extensions/core/scripts/state-write.sh` implementing exactly one
  serialization sequence, and register it for deploy.
- **Tasks:**
  - [x] Create `agent-system/extensions/core/scripts/state-write.sh` with `set -euo pipefail`,
        the `SCRIPT_DIR`/`PROJECT_ROOT` convention used by sibling scripts, and a
        `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` guard. *(completed: uses `set -uo
        pipefail`, not `-e`, to keep explicit jq-failure branches in control of exit codes)*
  - [x] Define the CLI contract in a top-of-file usage comment: a required jq filter argument, a
        required `--session-id`, passthrough of arbitrary `--arg`/`--argjson` bindings to jq, an
        opt-in `--regen-todo` flag, and an optional `--dry-run` that serializes nothing because
        it writes nothing (matching `update-task-status.sh`'s existing dry-run posture).
  - [x] Implement mutex acquire: skip entirely when `SCOPE_MUTEX_HELD` is non-empty (guest mode,
        with the same explanatory stderr note `acquire_state_mutex` emits today); otherwise call
        `task-lock.sh scope-acquire "$session_id"` and, on non-zero, FAIL CLOSED — emit an
        `ABORT:`-prefixed stderr message naming the current holder and exit non-zero. Do not
        swallow the primitive's return code.
  - [x] On successful acquire, export `SCOPE_MUTEX_HELD=1` and record the returned token.
  - [x] Implement staging: `mktemp` a private temp under `specs/tmp/` (create the directory if
        absent), never a fixed shared path.
  - [x] Install ONE EXIT trap scoped to this process's own `mktemp` path plus mutex release;
        release must be idempotent (guarded by an owned-here flag) and must never fail the exit
        path.
  - [x] Apply the caller's jq filter with the forwarded bindings against `specs/state.json`,
        writing to the private temp. On jq failure, leave `specs/state.json` untouched and exit
        non-zero with a distinct code.
  - [x] Validate with `jq empty` on the temp before any `mv`. On invalid JSON, leave
        `specs/state.json` untouched and exit non-zero with a distinct code.
  - [x] `mv` the temp into `specs/state.json`.
  - [x] When `--regen-todo` is passed, invoke `generate-todo.sh` BEFORE release, inside the
        critical section. A regen failure is a loud warning, not a hard failure (the state write
        already succeeded) — matching `update-task-status.sh`'s existing posture.
  - [x] Release the mutex via `task-lock.sh scope-release "$token"` and unset
        `SCOPE_MUTEX_HELD`; skip both in guest mode.
  - [x] Document every exit code in the top-of-file comment block.
  - [x] Add `state-write.sh` to `manifest.json`'s `provides.scripts` array, inserted
        alphabetically between `skill-base.sh` and `task-lock.sh`.
  - [x] `bash -n` and `shellcheck` (if available) the new script. *(completed: shellcheck not
        available in this environment; `bash -n` passed)*
- **Timing:** 2 hours
- **Depends on:** none
- **Verification Tier:** local
- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/state-write.sh` exits 0.
  - Manual smoke against a throwaway fixture: a single invocation applies a trivial filter and
    the file validates with `jq empty`.
  - `jq -e '.provides.scripts | index("state-write.sh")' agent-system/extensions/core/manifest.json`
    returns a non-null index, and the array remains sorted.
  - No task number appears anywhere in the new file or the manifest diff.

---

### Phase 2: Add ownership verification to `task-lock.sh` release [COMPLETED]

- **Goal:** `cmd_release` verifies the caller's `session_id` against `holder.json` before
  removing the lock directory, without weakening same-session re-entry.
- **Tasks:**
  - [x] Edit `agent-system/extensions/core/scripts/task-lock.sh`'s `cmd_release` to read its
        already-accepted second positional `session_id` argument.
  - [x] Compare it against `holder.json`'s `session_id` field via the existing
        `read_holder_field` helper.
  - [x] On mismatch: emit a loud WARN naming both the given and the current holder session,
        do NOT remove the lock directory, and `return 0` — mirroring `cmd_scope_release`'s
        token-mismatch handling verbatim in shape and tone.
  - [x] On match, or when the lock directory is already absent, preserve today's behavior
        exactly (idempotent `rm -rf`, `return 0`).
  - [x] Leave `cmd_acquire` untouched. Confirm by reading it that same-session re-entry still
        branches on `holder_session = session_id` FIRST, before any staleness check, and returns
        0 immediately. *(completed: confirmed via read, unchanged)*
  - [x] Make no change to `cmd_scope_acquire`, `cmd_scope_release`, `cmd_commit_acquire`, or
        `cmd_commit_release`. *(completed: unchanged)*
  - [x] Update `context/patterns/task-lock.md`'s release-contract section to state that
        `release` is now owner-verified, describing the WARN-and-no-op outcome. Use durable
        anchors only.
- **Timing:** 1 hour
- **Depends on:** none
- **Verification Tier:** interface
- **Scope Hypothesis:** The research report asserts exactly five `task-lock.sh release` call
  sites, all passing the same `session_id` string used at their matching acquire:
  `command-gate-out.sh`, the multi-task batch loops in `commands/implement.md`,
  `commands/plan.md`, `commands/research.md`, and `skills/skill-orchestrate/SKILL.md`. Confirm at
  implementation time by grepping the source store for `task-lock.sh release` and, for each hit,
  reading its matching acquire to verify the identifier expression is character-identical. If a
  sixth site or a mismatched identifier is found, record it and re-evaluate before landing the
  check — do not assume the count.
- **Verification:**
  - `bash -n` on `task-lock.sh` exits 0.
  - `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` still exits 0 (existing
    suite unaffected).
  - Manual fixture check: releasing with a non-matching session_id leaves the lock directory in
    place, emits a WARN, and exits 0; releasing with the matching session_id removes it.

---

### Phase 3: Build the concurrency test suite [COMPLETED]

- **Goal:** An isolated-temp-root suite proving the helper's two load-bearing safety properties
  before any call site depends on it.
- **Tasks:**
  - [x] Create `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` following
        `test-task-lock-reap.sh`'s isolated-temp-root precedent exactly: build a throwaway
        `$TMPROOT`, copy `state-write.sh`, `task-lock.sh`, `generate-todo.sh`, and
        `deploy-root-guard.sh` byte-for-byte into `$TMPROOT/.claude/scripts/`, and fixture a
        minimal `$TMPROOT/specs/state.json` with at least two task entries. Add no testability
        hooks to production code.
  - [x] Reuse the suite's `pass`/`fail`/`info` helper shape and its exit-0-on-all-pass /
        exit-1-on-any-fail contract.
  - [x] **Case: no lost update.** Launch two backgrounded `state-write.sh` invocations targeting
        DIFFERENT task entries, `wait` on both, and assert both mutations are present in the
        final file. Control interleaving through the fixture's own transform cost rather than
        wall-clock `sleep`, consistent with the precedent suite's no-sleeping convention.
        *(completed: first writer uses a heavy `[range(0;20000000)]` jq computation to hold the
        mutex for a real window while the second writer waits)*
  - [x] **Case: staging-file isolation.** Launch one process that claims its `mktemp` temp and
        then fails, firing its EXIT trap, concurrently with a second mid-write process; assert
        the second process's temp file is untouched and its write completes, proving each trap
        is scoped to its own `mktemp` path. *(completed: both run in guest mode
        (`SCOPE_MUTEX_HELD=1`) so they genuinely run concurrently rather than serializing through
        the mutex; bounded polling — not a correctness-bearing sleep — observed up to 2
        concurrent staging files)*
  - [x] **Case: fail-closed acquire.** Pre-claim `specs/.scope-lock` in the fixture and assert a
        `state-write.sh` invocation exits non-zero with the `ABORT:`-prefixed message rather than
        proceeding unserialized.
  - [x] **Case: guest-mode reentrancy.** Invoke `state-write.sh` with `SCOPE_MUTEX_HELD=1`
        exported and the mutex already held by the simulated outer holder; assert it completes
        the write without attempting a nested acquire and without releasing the outer holder's
        mutex.
  - [x] Add `test-state-write-concurrency.sh` to `manifest.json`'s `provides.scripts` array in
        sorted position, matching how `test-task-lock-reap.sh` is registered. *(completed in
        Phase 1's manifest edit, verified present here)*
  - [x] Assert the suite never touches the real `specs/` tree (grep the file for any
        `$PROJECT_ROOT/specs` reference outside the fixture construction). *(completed: zero
        hits; the suite has no `PROJECT_ROOT` variable at all and resolves everything through
        `$TMPROOT`)*
- **Timing:** 2 hours
- **Depends on:** 1
- **Verification Tier:** local
- **Verification:**
  - `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0 with all
    four cases PASS.
  - Real `specs/state.json` is byte-identical before and after a suite run.
  - `jq -e '.provides.scripts | index("test-state-write-concurrency.sh")'` on the manifest
    returns non-null.

---

### Phase 4: Convert the three isolated writers [COMPLETED]

- **Goal:** Convert the lowest-risk, most-isolated writers to `state-write.sh`, removing their
  hand-rolled tmp-and-mv sequences and shared-path EXIT traps.
- **Tasks:**
  - [x] `manage-topics.sh`: convert both write sites (the `add` and `set` subcommands) to
        `state-write.sh` calls; delete the bare
        `trap 'rm -f "$TMP_DIR/state.json.tmp"' EXIT` and the `$TMP_DIR/state.json.tmp`
        staging path entirely. *(completed: also added an optional `--session-id` flag,
        self-generating one when absent, since neither write subcommand previously accepted a
        session_id at all — see Plan Deviations)*
  - [x] `reconcile-artifacts.sh`: convert its append-only artifact-registration write; delete the
        `specs/tmp/state-reconcile.json` staging path. *(completed: also added an optional
        `--session-id` flag with the same self-generation fallback, and moved `commands/task.md`'s
        `sync_session_id` generation earlier so its Sync Mode caller now attributes the mutex
        properly instead of relying on the fallback)*
  - [x] `archive-task.sh`: convert ONLY the `del(.active_projects[] | select(...))` removal from
        `specs/state.json`, eliminating the `"${STATE_FILE}.tmp"` path that collides with
        `commands/review.md`'s literal. Leave the `archive/state.json` write untouched — a
        different file, out of scope. *(completed: also added an optional `--session-id` flag
        with self-generation fallback, since this script was found to have zero callers anywhere
        in the source store — see Scope Hypothesis note below)*
  - [x] For each converted site, confirm the caller passes its session_id through to the helper
        so mutex ownership is attributable. *(completed with a deviation: see Plan Deviations —
        `manage-topics.sh` has dozens of callers across core/cslib/literature that pass no
        session_id; rather than touch every caller file, each converted script gained a
        self-generating `--session-id` fallback identical in shape to
        `command-gate-in.sh`'s pattern, so existing callers keep working unchanged and gain
        attribution only where a caller opts in)*
  - [x] Verify no converted script still contains a `state.json`-targeted `> tmp && mv` sequence.
- **Timing:** 1.5 hours
- **Depends on:** 3
- **Verification Tier:** interface
- **Scope Hypothesis:** This phase asserts exactly four `specs/state.json` write sites across
  three scripts (`manage-topics.sh` 2, `reconcile-artifacts.sh` 1, `archive-task.sh` 1) and
  exactly one write to a non-`specs/state.json` file in `archive-task.sh` that must be left
  alone. Confirm at implementation time by grepping each file for `mv ` and `state.json` and
  enumerating every hit before editing; if the count differs, record the discrepancy rather than
  silently converting more or fewer sites. **Measured: confirmed exactly four sites as
  hypothesized.** Additional finding not in the hypothesis: `archive-task.sh` itself has ZERO
  callers anywhere in the source store (grepped `agent-system/` for `archive-task.sh` outside its
  own file and manifest registration) — it is a standalone, presently-uncalled CLI utility, not a
  gap in this phase's grep.
- **Verification:**
  - `bash -n` on all three scripts exits 0.
  - `grep -n 'state\.json.*tmp\|tmp.*state\.json'` over the three files returns no
    `specs/state.json` staging hits.
  - `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` still exits 0.
  - Dry-run each converted subcommand against a fixture and confirm the resulting
    `specs/state.json` validates with `jq empty` and carries the intended mutation.

---

### Phase 5: Convert the reconcile and predispatch-repair writers [COMPLETED]

- **Goal:** Convert `reconcile-task-status.sh` and `orchestrate-predispatch-review.sh --repair`,
  including the latter's deliberate-mutex-skip rationale.
- **Tasks:**
  - [x] `reconcile-task-status.sh`: convert both write sites inside `link_artifact`'s two-step jq
        to `state-write.sh` calls; remove the `specs/tmp/state.json` shared staging path from
        both. *(completed: session_id was already a required positional argument, forwarded
        directly to state-write.sh)*
  - [x] `orchestrate-predispatch-review.sh`: convert the `--repair` write (the default
        report-only path never writes) to a `state-write.sh` call, preserving its
        `$cands`-scoped bulk `|=` transform shape through the helper's jq-filter interface.
        *(completed: added an optional `--session-id` flag with self-generation fallback, since
        this script had no session_id parameter at all before — see Plan Deviations)*
  - [x] Remove `orchestrate-predispatch-review.sh`'s script-namespaced
        `specs/tmp/orchestrate-predispatch-review.state.tmp` staging path — the helper's
        `mktemp` replaces it.
  - [x] Rewrite that script's header comment claiming it deliberately skips the mutex because it
        is "direct-invocation-only": that reasoning is superseded. State instead that it now
        routes through the shared write helper like every other writer. Use durable anchors.
  - [x] Preserve both scripts' existing error messages that promise `specs/state.json` is "left
        untouched" on transform or validation failure — the helper upholds the same guarantee, so
        the promise stays true.
- **Timing:** 1.5 hours
- **Depends on:** 3
- **Verification Tier:** interface
- **Scope Hypothesis:** This phase asserts three write sites (`reconcile-task-status.sh` 2,
  `orchestrate-predispatch-review.sh` 1, the last reachable only via `--repair`). Confirm at
  implementation time by grepping both files for `mv ` and `state.json` and by checking that the
  default `orchestrate-predispatch-review.sh` path genuinely performs no write; do not assume the
  report-only path is write-free without reading it. **Measured: confirmed exactly three sites as
  hypothesized; verified by fixture run that the default (non-`--repair`) path leaves
  `specs/state.json` byte-identical.**
- **Verification:**
  - `bash -n` on both scripts exits 0.
  - `grep -n 'specs/tmp/state\.json\|orchestrate-predispatch-review\.state\.tmp'` over both files
    returns nothing.
  - `orchestrate-predispatch-review.sh` run WITHOUT `--repair` against a fixture leaves
    `specs/state.json` byte-identical.
  - `orchestrate-predispatch-review.sh --repair` against a fixture applies the bulk transform and
    the result validates with `jq empty`.

---

### Phase 6: Consolidate and convert `skill-base.sh` [COMPLETED]

- **Goal:** Delete the two orphaned dead-code write functions and convert the four live write
  sites to `state-write.sh`.
- **Tasks:**
  - [x] Confirm `skill_increment_artifact_number` and `skill_propagate_memory_candidates` have
        zero call sites anywhere in the source store (grep both names across
        `agent-system/extensions/`), then delete both functions outright. Do not convert dead
        code. *(completed: confirmed zero callers, both deleted)*
  - [x] Convert `skill_propagate_completion_summary`'s two write sites to `state-write.sh` calls.
  - [x] Convert `skill_link_artifacts`'s two write sites to `state-write.sh` calls.
  - [x] Remove every `${SKILL_REPO_ROOT}/specs/tmp/state.json` shared staging reference from the
        file.
  - [x] Thread each converted call's session_id through to the helper. *(completed with a
        deviation: both functions gained an optional trailing `session_id` parameter with a
        self-generating fallback — see Plan Deviations. The ~15 existing call sites across
        core skills and three extension implementation skills were left unedited; a future
        follow-up could thread real session_id values through the core skill call sites
        specifically, since those already have `$session_id` in scope)*
  - [x] Confirm the converted functions still work correctly when invoked from inside an outer
        `SCOPE_MUTEX_HELD=1` critical section (guest mode) — this is their normal calling context
        under `orchestrator-postflight.sh`. *(completed: verified against a fixture with a
        pre-claimed outer mutex; guest mode fires, outer mutex untouched)*
  - [x] Update `docs/architecture/architecture-spec.md`'s `skill-base.sh` function inventory to
        drop the two deleted functions, if they are listed there. *(completed; also updated
        `docs/guides/creating-skills.md`'s equivalent table)*
- **Timing:** 1.5 hours
- **Depends on:** 3
- **Verification Tier:** interface
- **Scope Hypothesis:** This phase asserts four live write sites (two each in
  `skill_propagate_completion_summary` and `skill_link_artifacts`) plus exactly two orphaned,
  zero-call-site functions to delete. Confirm both halves at implementation time: grep the whole
  source store for each orphaned function name to prove zero callers before deleting, and
  enumerate every `state.json`-targeted `mv` in the file to confirm the live-site count. A
  non-zero caller count for either "orphan" invalidates the deletion and must be recorded, not
  worked around. **Measured: confirmed exactly four live sites and exactly two zero-caller
  orphans, matching the hypothesis exactly.**
- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/skill-base.sh` exits 0.
  - `grep -rn 'skill_increment_artifact_number\|skill_propagate_memory_candidates' agent-system/`
    returns no hits.
  - `grep -n 'specs/tmp/state\.json' agent-system/extensions/core/scripts/skill-base.sh` returns
    nothing.
  - A skill lifecycle invocation exercising completion-summary propagation and artifact linking
    against a fixture produces a `specs/state.json` that validates with `jq empty` and carries
    both mutations.

---

### Phase 7: Convert `update-task-status.sh` [NOT STARTED]

- **Goal:** Replace this script's fail-open mutex wrapper and hand-rolled staging with
  `state-write.sh`, keeping its TODO.md regen inside the critical section.
- **Tasks:**
  - [ ] Delete `acquire_state_mutex` and `release_state_mutex`, including the fail-open
        `WARNING: ... proceeding unserialized (non-blocking)` branch — the helper now owns
        acquisition, and the posture is fail-closed.
  - [ ] Convert the PHASE 1 `specs/state.json` write to a `state-write.sh` call with
        `--regen-todo`, so PHASE 2's TODO.md regeneration happens inside the same mutex rather
        than as a separate step after release.
  - [ ] Remove the `$TMP_DIR/state.json.tmp` staging path and its `rm -f` from the `cleanup`
        trap; keep the trap for whatever non-state.json cleanup remains, or delete it if nothing
        remains.
  - [ ] Preserve the existing idempotency check (`state_is_noop`) and the `--dry-run` path
        unchanged; a dry run must still perform no write and no acquire.
  - [ ] Preserve the documented exit-code contract, including code 3 (plan-file update failed
        after `specs/state.json` was written) and its retryability note. Update the header
        comment if the fail-closed change introduces a new failure code.
  - [ ] Update the block comment describing the `.scope-lock` bracket to describe the new
        delegation to the shared helper, keeping the `SCOPE_MUTEX_HELD` guest-mode explanation.
        Use durable anchors.
  - [ ] Keep the `workflow-active` marker write in place for now; it is converted in its own
        phase.
  - [ ] Verify the plan-file / phase-status updates that currently sit outside the mutex bracket
        remain outside it — they touch neither `specs/state.json` nor TODO.md.
- **Timing:** 1.5 hours
- **Depends on:** 3
- **Verification Tier:** interface
- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/update-task-status.sh` exits 0.
  - `grep -n 'proceeding unserialized'` over the file returns nothing.
  - `grep -n 'state\.json\.tmp'` over the file returns nothing.
  - `update-task-status.sh --dry-run` against a fixture leaves `specs/state.json` and TODO.md
    byte-identical.
  - A preflight and a postflight run against a fixture each produce a valid `specs/state.json`
    and a TODO.md regenerated from it.
  - A run with `SCOPE_MUTEX_HELD=1` exported completes without a nested acquire.

---

### Phase 8: Convert `orchestrator-postflight.sh` [NOT STARTED]

- **Goal:** Convert every internal write site, including the two non-atomic `python3` in-place
  writes, and hand mutex ownership to the shared helper.
- **Tasks:**
  - [ ] Stage 7a (`next_artifact_number`): replace the `python3 json.load`/`json.dump` in-place
        write with a `state-write.sh` call applying
        `.next_artifact_number = (.next_artifact_number // 1) + 1`.
  - [ ] Stage 7c (`memory_candidates`): replace the `python3` in-place write and its
        triple-quoted-string JSON interpolation with a `state-write.sh` call applying
        `.memory_candidates += $new` with the payload passed via `--argjson` — the same
        interpolation-avoidance the adjacent reflection stage already uses deliberately.
  - [ ] Stage 7d (`reflection`): convert the existing jq/mv site to a `state-write.sh` call.
  - [ ] Stage 8 (artifact link): convert the two-step jq/mv site to `state-write.sh` calls.
  - [ ] Stage 7b: confirm it delegates to `skill-base.sh`'s converted
        `skill_propagate_completion_summary` and needs no separate write of its own; if any
        inline duplicate remains, convert it.
  - [ ] Remove every `specs/tmp/state.json` shared staging reference from the file.
  - [ ] Decide and implement the mutex ownership shape: either keep the existing Stage 7-8a
        `scope_token` bracket with `SCOPE_MUTEX_HELD=1` exported so each helper call runs as a
        guest (fewer acquire/release cycles, one critical section), or drop the bracket and let
        each helper call acquire independently. Prefer keeping the bracket — it preserves the
        existing all-stages-atomic property — and document the choice in the file's comment.
  - [ ] If the bracket is kept, ensure its EXIT trap still releases on every path and that the
        helper's guest-mode branch never releases the outer holder's mutex.
  - [ ] Diff a sample `specs/state.json` before and after a full postflight run against a
        fixture; confirm the only differences are the intended key mutations and that no
        unintended reformatting of `next_artifact_number` or `memory_candidates` occurred.
- **Timing:** 2 hours
- **Depends on:** 6, 7
- **Verification Tier:** full
- **Scope Hypothesis:** This phase asserts approximately six internal read-modify-write sites
  (Stage 7a, Stage 7b via delegation, Stage 7c, Stage 7d, and two in Stage 8). Confirm at
  implementation time by enumerating every `state.json`-targeted `mv`, every `python3` block
  touching `specs/state.json`, and every stage boundary in the file before editing. The count is
  a hypothesis carried from research, not a fact — record the measured count in the phase
  outcome.
- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/orchestrator-postflight.sh` exits 0.
  - `grep -n 'python3' <file>` returns no block touching `specs/state.json`.
  - `grep -n 'specs/tmp/state\.json' <file>` returns nothing.
  - Full postflight run against a fixture: `specs/state.json` validates with `jq empty`;
    `next_artifact_number` incremented by exactly 1; `memory_candidates` appended without loss;
    reflection and artifact link both present.
  - Before/after `jq -S . | diff` on the fixture shows changes confined to the intended keys.
  - The complete gate set for the repository runs green: `bash -n` across all edited scripts,
    `test-state-write-concurrency.sh`, `test-task-lock-reap.sh`, and
    `scripts/check-task-references.sh`.

---

### Phase 9: Convert the two inline command-file writes [NOT STARTED]

- **Goal:** Convert the `specs/state.json` write blocks embedded in command markdown to
  `state-write.sh` invocations.
- **Tasks:**
  - [ ] `commands/implement.md` Step 4 (completion_summary): replace the inline
        `jq ... specs/state.json > specs/tmp/state.json && mv ...` block with a
        `bash .claude/scripts/state-write.sh` invocation. The runtime path stays
        `.claude/scripts/...`; the EDIT target is
        `agent-system/extensions/core/commands/implement.md`.
  - [ ] `commands/review.md` task-creation write (Section 4): replace the
        `specs/state.json > specs/state.json.tmp && mv ...` block — the literal that collides
        with `archive-task.sh` — with a `state-write.sh` invocation.
  - [ ] `commands/review.md` `active_goal` write (Section 6.7.3): replace the
        `specs/state.json > specs/tmp/state.json && mv ...` block with a `state-write.sh`
        invocation.
  - [ ] Where a converted site is immediately followed by a separate `generate-todo.sh` call,
        fold that regen into the helper's `--regen-todo` flag so it runs inside the mutex.
  - [ ] Leave every `specs/reviews/state.json` write in `review.md` untouched — different file,
        out of scope. Confirm none was converted by accident.
  - [ ] Confirm each converted block still passes the session_id available at that point in the
        command flow.
- **Timing:** 1 hour
- **Depends on:** 3
- **Verification Tier:** interface
- **Scope Hypothesis:** This phase asserts exactly three in-scope `specs/state.json` write blocks
  across two command files (`implement.md` 1, `review.md` 2), plus at least two
  `specs/reviews/state.json` blocks in `review.md` that must remain untouched. Confirm at
  implementation time by grepping both files for `state.json` and classifying every hit as
  in-scope write, out-of-scope write, or read-only before editing.
- **Verification:**
  - `grep -n 'specs/state\.json.*tmp\|specs/state\.json\.tmp'` over both command files returns
    nothing.
  - `grep -c 'specs/reviews/state\.json' agent-system/extensions/core/commands/review.md` is
    unchanged from its pre-edit value.
  - The converted bash blocks are syntactically valid when extracted and run through `bash -n`.
  - No task number appears in either edited file's diff.

---

### Phase 10: Make the `workflow-active` marker per-session [NOT STARTED]

- **Goal:** Convert the global-singleton marker and all three of its consumers together, so no
  session's cleanup can delete another's marker.
- **Tasks:**
  - [ ] Choose the per-session form: either a `{session_id}`-suffixed filename under
        `.claude/tmp/` or a small JSON registry keyed by session_id in the same directory.
        Document the choice and its rationale in the writer's comment.
  - [ ] `scripts/update-task-status.sh` preflight branch: write the marker in the chosen
        per-session form instead of the fixed `../tmp/workflow-active` path.
  - [ ] `hooks/claude-stop-notify.sh`: read the marker in the per-session form; suppress the Stop
        fire when ANY session's marker is present (the suppress semantics are global even though
        the storage is per-session), or scope to the current session if the hook has access to
        one — document which and why.
  - [ ] `hooks/wezterm-preflight-status.sh`: replace the unconditional
        `rm -f .../tmp/workflow-active` with a delete scoped to the current session's marker
        only. This is the specific line that today deletes other sessions' markers.
  - [ ] `hooks/events-log-lifecycle.sh`: update its fallback read of the marker to the
        per-session form.
  - [ ] Handle the migration case: a stale marker left at the old fixed path by a
        pre-conversion run must not break any of the three consumers. Tolerate and clean it.
  - [ ] Verify against a fixture that two simulated concurrent sessions each write their own
        marker and that one session's cleanup leaves the other's intact.
- **Timing:** 1.5 hours
- **Depends on:** 7
- **Verification Tier:** interface
- **Commit Mode:** atomic-batch
- **Scope Hypothesis:** This phase asserts exactly one writer
  (`scripts/update-task-status.sh` preflight branch) and exactly three consumers
  (`hooks/claude-stop-notify.sh`, `hooks/wezterm-preflight-status.sh`,
  `hooks/events-log-lifecycle.sh`). Confirm at implementation time by grepping the entire source
  store for `workflow-active` and classifying every hit as writer, consumer, or comment. A fourth
  consumer invalidates the atomic-batch file set and must be added to it, not deferred — a
  partial conversion reintroduces the exact hazard this phase closes.
- **Verification:**
  - `grep -rn 'workflow-active' agent-system/extensions/core/` shows no remaining unconditional
    fixed-path delete.
  - Two-session fixture: session A writes its marker, session B writes its own, B's ESC-cancel
    cleanup fires; A's marker still exists.
  - `bash -n` on the writer and all three hooks exits 0.
  - Stop-hook suppression still works for a single-session run (no regression to the original
    behavior the marker exists for).

---

### Phase 11: Deploy, audit, and document [NOT STARTED]

- **Goal:** Land the helper in this repo's live `.claude/scripts/`, prove zero hand-rolled
  sequences remain, and record the convention.
- **Tasks:**
  - [ ] Perform the one-off deploy workaround for `state-write.sh` and
        `test-state-write-concurrency.sh`: the headless "Load Core" sync skips `copy_scripts` for
        already-loaded extensions, so a manifest entry alone does not reach an existing deploy.
        Invoke the loader's copy primitives directly (or copy the files explicitly) into
        `.claude/scripts/`, matching the documented workaround used for the shared
        task-reference pattern library.
  - [ ] Verify `.claude/scripts/state-write.sh` exists, is executable, and is byte-identical to
        the source-store file. This is a DEPLOY step, not an edit — the source store remains the
        only edit target.
  - [ ] Run the full audit sweep: grep the entire source store for any remaining
        `specs/state.json`-targeted `> tmp && mv` or `.tmp` staging sequence outside
        `state-write.sh`, across all nine scripts and both command files. Zero hits is the gate.
  - [ ] Grep for any remaining `python3` block touching `specs/state.json`. Zero hits is the
        gate.
  - [ ] Grep for any remaining fail-open-on-mutex-timeout wording. Zero hits is the gate.
  - [ ] Add a `state-write.sh` section to `context/patterns/multi-task-operations.md` describing
        the standing convention: every `specs/state.json` writer goes through the shared helper.
        Update or remove that file's existing note recording this read-modify-write race as a
        known unfixed defect — it is now fixed.
  - [ ] Cross-reference the new convention from `context/patterns/task-lock.md`'s
        scope-acquire/scope-release section.
  - [ ] Record the out-of-scope follow-up explicitly in the implementation summary: fifteen
        extension `SKILL.md` files carry their own inline `specs/state.json` write patterns and
        remain unconverted. Name them; do not silently omit them.
  - [ ] Record the extension-loader deploy gap as still open — this plan worked around it, it did
        not fix it.
  - [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm no deliverable edited by
        this plan cites a task number.
- **Timing:** 1.5 hours
- **Depends on:** 4, 5, 8, 9, 10
- **Verification Tier:** full
- **Scope Hypothesis:** This phase asserts that after conversion, ZERO hand-rolled
  `specs/state.json` tmp-and-mv sequences remain anywhere in `agent-system/extensions/core/**`
  outside `state-write.sh`. This is the plan's definition of done and must be confirmed by an
  actual grep whose output is recorded in the implementation summary, not asserted. Any surviving
  hit is a phase failure, not an acceptable residual.
- **Verification:**
  - Audit greps above all return zero hits; record the exact commands and their output.
  - `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0.
  - `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0.
  - `bash .claude/scripts/check-task-references.sh` exits 0.
  - `bash .claude/scripts/check-extension-docs.sh` exits 0.
  - `bash -n` passes on every script edited by this plan.
  - `.claude/scripts/state-write.sh` exists and matches the source-store file.

---

## Testing & Validation

- [ ] `test-state-write-concurrency.sh` passes all four cases: no lost update, staging-file
      isolation, fail-closed acquire, guest-mode reentrancy.
- [ ] `test-task-lock-reap.sh` still passes — the `cmd_release` ownership check introduces no
      regression.
- [ ] `bash -n` clean on all ten edited/created shell scripts.
- [ ] Zero `specs/state.json`-targeted tmp-and-mv sequences outside `state-write.sh` in the
      source store.
- [ ] Zero `python3` in-place writes against `specs/state.json`.
- [ ] Zero fail-open-on-mutex-timeout code paths.
- [ ] `specs/state.json` validates with `jq empty` after every converted writer's fixture run.
- [ ] Two-session `workflow-active` fixture: neither session deletes the other's marker.
- [ ] `check-task-references.sh` passes — no deliverable outside `specs/**` cites a task number.
- [ ] `check-extension-docs.sh` passes — manifest and README cross-references remain valid.
- [ ] `.claude/scripts/state-write.sh` present, executable, and identical to the source-store
      file after the manual deploy step.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/state-write.sh` (new)
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` (new)
- `agent-system/extensions/core/scripts/task-lock.sh` (modified — `cmd_release` ownership check)
- `agent-system/extensions/core/scripts/update-task-status.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (modified)
- `agent-system/extensions/core/scripts/manage-topics.sh` (modified)
- `agent-system/extensions/core/scripts/skill-base.sh` (modified — 2 functions deleted, 4 sites
  converted)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (modified)
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh` (modified)
- `agent-system/extensions/core/scripts/archive-task.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (modified)
- `agent-system/extensions/core/commands/implement.md` (modified)
- `agent-system/extensions/core/commands/review.md` (modified)
- `agent-system/extensions/core/hooks/claude-stop-notify.sh` (modified)
- `agent-system/extensions/core/hooks/wezterm-preflight-status.sh` (modified)
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (modified)
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` (modified)
- `agent-system/extensions/core/context/patterns/task-lock.md` (modified)
- `agent-system/extensions/core/manifest.json` (modified — two `provides.scripts` entries)
- `specs/942_serialize_state_json_writers/summaries/01_serialize-state-json-writers-summary.md`

## Rollback/Contingency

- Each phase is a separate commit; revert granularity is one phase. The conversion phases (4-9)
  are independent of each other at the file level, so a single bad conversion reverts without
  disturbing the others.
- Phases 1-3 are purely additive (new files plus two manifest entries) and can be reverted with
  no effect on any existing writer.
- Phase 2 (`cmd_release` ownership) is a self-contained edit to one function in one file; revert
  restores the unconditional `rm -rf` exactly.
- Phase 10 is `atomic-batch` — revert the whole writer-plus-three-consumers set together. A
  partial revert reintroduces the cross-session deletion hazard and must not be performed.
- If the fail-closed posture proves too disruptive in live use, the correct response is to widen
  `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` in `task-lock.sh`, NOT to restore a fail-open branch in the
  helper. Fail-open is the defect being removed.
- If the manual deploy step in Phase 11 cannot be completed, the source store remains correct and
  self-consistent; the live `.claude/` deploy simply lacks the new helper until the next full
  "Load Core" sync. Record this state explicitly rather than editing `.claude/**` by hand.
