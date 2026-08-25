# Implementation Plan: Postflight Deploy Gate for Source-Store Tasks

- **Task**: 83 - Make 'completed' mean 'in effect' for tasks that edit the source store — a postflight deploy gate
- **Status**: [IMPLEMENTING]
- **Effort**: 10.5 hours
- **Dependencies**: 82 (complete — `deploy-headless.sh` runs `verify-deploy.sh --skip-slow` inline and exits 3 for "deploy landed, verification failed")
- **Research Inputs**: specs/083_postflight_deploy_gate_for_source_store_tasks/reports/01_postflight_deploy_gate.md
- **Artifacts**: plans/01_postflight-deploy-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A task whose implementation edits `agent-system/extensions/**` can currently reach `[COMPLETED]`
while its changes remain absent from the running `.claude/` tree, because the only staleness
signal in the system (`check-deploy-freshness.sh`) is advisory by contract and always exits 0.
This plan adds a **check-only, unconditional deploy-freshness backstop inside
`scripts/update-task-status.sh`** — the one chokepoint every completion path funnels through —
which refuses the `postflight … implement` transition (new exit code 6) when the task's own
`modified_files` overlap the source store and the deploy is provably behind. The actual
`deploy-headless.sh` trigger is placed only at already-serialized call sites, uses
baseline-relative `verify-deploy.sh --findings` comparison rather than raw exit codes, and is
licensed by a new additive carve-out subsection in `regeneration-is-manual-only.md`.

Definition of done: a source-store-touching task cannot flip to `completed` while the deploy is
behind; the refusal is an ordering constraint (task stays `implementing`, resumable), never an
exclusion; the carve-out is recorded; and `check-deploy-freshness.sh`'s advisory-only role is
documented as the read-side tier of a now-two-tier staleness model.

### Research Integration

Five binding constraints from `reports/01_postflight_deploy_gate.md` are load-bearing for every
phase below and are restated here so no phase can silently drop one:

1. **The gate cannot live only in `command-gate-out.sh`.** `skill-implementer/SKILL.md` Stage 7
   flips status to `completed` via its own inline `update-task-status.sh` call, which runs
   *before* gate-out and makes gate-out's defensive-correction branch a no-op for the primary
   meta-task path. Multi-task `/implement` bypasses gate-out entirely.
   `scripts/update-task-status.sh` is the one true shared chokepoint (Finding A/B).
2. **`file_scope` correction is required** before implementation (Finding B/E, "Recommended
   Design Summary" point 4). Stated explicitly in Phase 1 and in "Corrected File Scope" below.
3. **The backstop must be CHECK-ONLY and must never invoke `deploy-headless.sh`.** Multi-task
   `/implement` and `skill-orchestrate` both dispatch per-task implementation skills in parallel;
   a deploy fired from inside per-task postflight would race the fail-open `specs/.deploy-lock`
   mutex (Finding E).
4. **Baseline-relative verification is mandatory.** `deploy-headless.sh` exits 3 on *every*
   non-dry-run invocation in this repo today, from pre-existing doc-lint and gate-8 failures other
   tasks own. A raw exit-code check would brick all meta-task completion immediately (Finding D).
5. **The carve-out is mandatory**, additive, placed immediately after the existing
   `## Automated Exception: The Inter-Cycle Self-Modification Checkpoint` subsection, following
   the same three-part not-a-side-effect / not-silent / bounded justification shape, naming the
   new call sites, never editing a byte of the existing sanctioned-caller text, and stating it is
   not precedent (Finding G).

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and `roadmap_flag` is not set, so no
roadmap phases are added and no roadmap consultation was performed.

## Design Decisions

Each decision the research explicitly deferred to planning is resolved here, with its reason, so
implementation does not re-open it.

**D1 — Unconditional backstop, not an opt-in `--deploy-check` flag.** The acceptance criterion is
stated without exception, and an opt-in flag would require threading it through
`skill-implementer/SKILL.md`, `skill-orchestrate/SKILL.md`, and every extension implementation
skill — all outside this task's scope and all orchestrator-adjacent. Unconditional needs zero
skill-file edits. Cost accepted: no per-caller "warn" escape hatch.

**D2 — Refusal leaves the task at `implementing`; it does not transition to `blocked`.** This
mirrors the existing `--phase-check=refuse` shape exactly: no state.json write, no plan-file
stamp, exit non-zero, self-resuming on the next `/implement`. It satisfies
`batch-orchestration-guardrails.md`'s "degrade to an ORDERING CONSTRAINT whenever possible"
principle. `blocked` would signal a human-only remedy, which is wrong here — the remedy is a
deploy, which the serialized trigger sites perform automatically.

**D3 — New exit code 6, not 5.** Exit codes 0-5 are all already allocated in
`update-task-status.sh` (0 success, 1 validation, 2 state.json write failure, 3 plan-file write
failure, 4 phase-check refusal, 5 missing shared library). The research's suggestion of 5 was
based on 4 being the highest allocated and is superseded. This is a Scope Hypothesis on Phase 3,
confirmable by grep.

**D4 — A missing freshness library is INCONCLUSIVE pass-through, not a hard exit.** This
deliberately diverges from the exit-5 precedent the two existing shared libraries use. Those are
loaded for an *opt-in* code path; this backstop is *unconditional*, so a hard environment exit
would block every completion in the system on a deploy-ordering accident. Loud note, pass through.

**D5 — The backstop performs the git-log freshness comparison only; it never calls
`verify-deploy.sh`.** `verify-deploy.sh --skip-slow` costs ~50-70s. Running it on every postflight
is unacceptable. The backstop stays preflight-cheap (one path-scoped `git log -1` per extension).
Baseline-relative `verify-deploy.sh --findings` comparison belongs exclusively to the serialized
deploy-trigger sites, which run at most once per invocation.

**D6 — `skill-orchestrate`'s Stage MT-3 step 7 trigger predicate is NOT widened.** Widening it to
`agent-system/extensions/**` changes the meaning of a heavily cross-referenced mechanism and its
`deployed_critical_paths` idempotence backing store, which is keyed on critical paths rather than
extensions. That is its own task. This plan does not touch `skill-orchestrate/SKILL.md`. See
"Residual: the `/orchestrate` path" under Risks for the bounded consequence and the mitigation
that is in scope.

**D7 — Overlap predicate is path-based, not `task_type`-based.** `modified_files` entries whose
path is at or under `agent-system/extensions` per the directory-prefix rule in
`context/patterns/file-footprint-overlap.md`, reused via `scopes_overlap()` from
`scripts/lib/file-scope-overlap.sh` rather than re-derived. A `general`-typed task can touch the
source store too, and every other file-scope check in this system is path-based.

## Corrected File Scope

The task's admitted `file_scope` is four files. It is insufficient: it omits the one file the gate
must live in. The corrected scope, to be written into `specs/state.json` in Phase 1:

**Already admitted (4)**
1. `agent-system/extensions/core/scripts/command-gate-out.sh`
2. `agent-system/extensions/core/scripts/skill-base.sh`
3. `agent-system/extensions/core/scripts/check-deploy-freshness.sh`
4. `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`

**Added (6)**
5. `agent-system/extensions/core/scripts/update-task-status.sh` — REQUIRED; the chokepoint the
   backstop must live in. Without it the gate cannot reach the primary meta-task completion path.
6. `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh` — NEW; the shared freshness
   comparison, so the algorithm has one home.
7. `agent-system/extensions/core/commands/implement.md` — Step 4's serialized batch trigger.
8. `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — the
   authoritative home of the new mechanism's contract, alongside the Inter-Cycle Redeploy
   Checkpoint it reuses.
9. `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` — extended for the
   library refactor.
10. `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — NEW regression
    suite.

**Explicitly OUT of scope** (do not edit, even if convenient): `skill-implementer/SKILL.md`,
`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, `verify-deploy.sh`,
`deploy-headless.sh`, `context/reference/orchestrator-critical-paths.json`, and every deployed
`.claude/**` file.

## Goals & Non-Goals

**Goals**:
- A task whose `modified_files` overlap `agent-system/extensions/**` cannot flip to `completed`
  while its extension's deploy is provably behind.
- The refusal is an ordering constraint: no state write, no plan stamp, resumable.
- One shared freshness algorithm, two call sites (advisory + blocking), zero duplication.
- Serialized, baseline-relative auto-deploy at exactly two new call sites, each carve-out-recorded.
- `check-deploy-freshness.sh`'s advisory-only contract documented as tier 1 of a two-tier model.

**Non-Goals**:
- Widening `skill-orchestrate`'s Stage MT-3 step 7 predicate (D6) — named as a follow-up.
- Fixing the pre-existing doc-lint and gate-8 failures that make `deploy-headless.sh` exit 3.
  This plan tolerates them by construction (D5, baseline comparison); it does not repair them.
- Detecting *uncommitted* source-store edits. The freshness signal is commit-granular by design;
  see Risks.
- Any preflight blocking. The decision to gate at postflight is settled and is not revisited.
- Editing any deployed `.claude/**` file by hand.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Naive exit-code gate bricks all meta-task completion given today's universal exit 3 | H | H | D5 + baseline-relative `--findings` set difference at trigger sites only; backstop never calls `verify-deploy.sh` at all |
| Parallel per-task postflight races concurrent `deploy-headless.sh` on the fail-open `.deploy-lock` | H | M | Backstop is check-only by contract (Phase 3 verification asserts no `deploy-headless` reference in the backstop block) |
| Unconditional backstop mis-fires on a task that touched nothing in the source store | H | M | Path-based overlap predicate (D7) plus the conclusiveness convention: only "overlap AND provably stale" refuses; everything else passes through |
| Missing shared library turns into a system-wide completion block | H | L | D4: inconclusive pass-through with a loud note, never a hard exit |
| Commit-granular signal misses uncommitted source-store edits | M | M | Documented as an explicit residual in Phase 7's contract text; the Commit-Per-Green-Substep Mandate makes the uncommitted-at-postflight case rare, and `verify-deploy.sh` remains the deep per-file companion |
| `/orchestrate` re-dispatch churn on a refused task (D6) | M | M | Phase 6 makes `skill_postflight_update` capture and surface the refusal (it currently swallows the rc entirely), so the outcome is a named, loud `deploy-pending` deferral bounded by orchestrate's existing cycle bounds — not a silent hang |
| Self-modification: this task's own completion becomes subject to its own gate | M | H | Intended. Phase 8 sequences the deploy before completion and uses the task's own postflight as the acceptance demonstration |
| Test suites copy from the deploy tree, so a new suite cannot see pre-deploy source changes | M | H | Phase 4 requires source-store-preferred resolution for the files under test; verified by executing the suite against unmodified source and confirming it fails, then against modified source and confirming it passes |
| Carve-out drift — a future automated caller added with no recorded exception | M | M | Phase 7 writes the scope-limiter sentence verbatim in the existing subsection's shape and states the carve-out is not precedent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 5, 6 |
| 6 | 8 | 4, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Scope correction and behavioral baselines [COMPLETED]

**Goal**: Write the corrected `file_scope` into `specs/state.json` and capture the pre-change
behavioral baselines that every later phase's "no regression" verification compares against.

**Tasks**:
- [x] Write the ten-entry corrected `file_scope` (see "Corrected File Scope" above) into task 83's *(completed)*
      `specs/state.json` entry via `state-write.sh`, never by hand-editing the file.
- [x] Capture `bash .claude/scripts/check-deploy-freshness.sh /home/benjamin/.config/nvim` stdout, *(completed)*
      stderr, and exit code to a scratch baseline file. This is the byte-comparison target for
      Phase 2.
- [x] Capture `bash .claude/scripts/verify-deploy.sh --findings --quiet` output, filtered to *(completed: 24 pre-existing findings, rc=1)*
      `grep '^FINDING ' | sort -u`, plus its exit code, to a scratch baseline file. This records
      the pre-existing failure set that Phases 5, 6, and 8 must tolerate.
- [x] Confirm by execution that exit codes 0-5 are already allocated in *(completed: 0-5 all in use, 6 free)*
      `scripts/update-task-status.sh` and that 6 is free.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The corrected `file_scope` is asserted to be exactly ten entries and exit
code 6 is asserted to be free. Confirm both by execution: re-read the written `file_scope` back
out of `state.json` with `jq` and count it; run
`grep -nE 'exit [0-9]' agent-system/extensions/core/scripts/update-task-status.sh` and enumerate
the distinct codes. If a sixth code is already in use, pick the lowest free integer and record the
change in this plan before proceeding.

**Files to modify**:
- `specs/state.json` — task 83's `file_scope` array (via `state-write.sh`)

**Verification**:
- `jq '.active_projects[] | select(.project_number == 83) | .file_scope | length'` returns 10.
- Both baseline files exist and are non-empty.
- `grep -c 'exit 6' agent-system/extensions/core/scripts/update-task-status.sh` returns 0.

---

### Phase 2: Extract the freshness comparison into a shared library [COMPLETED]

**Goal**: Create `scripts/lib/deploy-freshness-lib.sh` holding the per-extension path-scoped
git-log comparison exactly once, and re-point `check-deploy-freshness.sh` at it with its
always-exit-0 advisory contract preserved byte-for-byte in observable behavior.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh`, modelled *(completed)*
      structurally on `scripts/lib/file-scope-overlap.sh` (header stating it is the single home of
      the algorithm; safe to source; sets no shell options the caller inherits; exports nothing a
      caller must guess at).
- [x] Export one function that, given a repo root, emits one machine-readable line per extension *(completed: deploy_freshness_stale_names)*
      whose recorded `source_git_head` differs from the recomputed path-scoped revision, and emits
      nothing for every "cannot verify" case (missing/unparseable `.claude-extensions.json`,
      missing `source_dir` or `source_git_head`, `source_dir` absent, not a git repo, `git`/`jq`
      unavailable, empty recomputed revision).
- [x] Export a second function that distinguishes "verified fresh" from "cannot verify" so the *(completed: deploy_freshness_status)*
      blocking caller in Phase 3 can take an INCONCLUSIVE branch. `check-deploy-freshness.sh`
      collapses these two into one silence deliberately; the blocking caller must not.
- [x] Re-point `check-deploy-freshness.sh` at the library using the same deploy-tree-first / *(deviation: altered — used SCRIPT_DIR-relative sibling lookup instead of PROJECT_ROOT-anchored candidates, since this script has no PROJECT_ROOT concept and its own $1 argument names the CONSUMER repo being checked, not its own location; see phase-2-progress.json)*
      source-store-fallback candidate-resolution pattern `update-task-status.sh` already uses for
      `phase-heading-patterns.sh`. Preserve its exact WARN line text, its stderr routing, its
      `exit 0`, and its silence in every cannot-verify case.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the enumerated set of six "cannot verify" silent-skip
branches transcribed from `check-deploy-freshness.sh`'s header. Confirm at implementation time by
re-reading that script's own guard chain top to bottom and by running the existing
`scripts/tests/test-deploy-freshness.sh` suite, whose header claims it pins "both directions and
every silent-skip branch" — if the suite pins fewer branches than the header claims, record the
actual count rather than the claimed one.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh` — new file
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` — source the library, delete
  the now-duplicated inline loop
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` — extend for the library's
  own two exported functions, including the fresh/cannot-verify distinction

**Verification**:
- Run the modified `check-deploy-freshness.sh` and byte-compare stdout, stderr, and exit code
  against Phase 1's captured baseline. Any difference fails the phase.
- `bash agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` exits 0.
- Execute the new library's two functions directly in a scratch shell against (a) the live repo
  and (b) a `mktemp -d` fixture with a deliberately absent `.claude-extensions.json`; confirm the
  stale/fresh/cannot-verify three-way distinction is observable in the second function's output.

---

### Phase 3: The check-only deploy-freshness backstop in update-task-status.sh [COMPLETED]

**Goal**: Add the unconditional, check-only backstop that refuses `postflight … implement` with
exit 6 when the task's own `modified_files` overlap the source store and a deploy is provably
pending. It must never invoke `deploy-headless.sh` or `verify-deploy.sh`.

**Tasks**:
- [x] Add a "Phase 0.5" block immediately after the existing `--phase-check` Phase 0 block, firing *(completed)*
      on `operation == "postflight" && target_status == "implement" && state_is_noop != "true"` —
      the same guard triple, so the two backstops cannot disagree about when they apply.
- [x] Resolve the task's `.return-meta.json` from `task_number` by reusing the existing *(completed)*
      `project_name` -> padded/unpadded `task_dir` chain already implemented for the plan-file
      lookup. No new CLI argument.
- [x] Read `modified_files` and test overlap against `["agent-system/extensions"]` using *(completed)*
      `scopes_overlap()` from `scripts/lib/file-scope-overlap.sh` (call convention:
      `scopes_overlap "$own_scope_json" "$other_scope_json"`, non-empty stdout means overlap).
      Do not re-derive the prefix rule inline.
- [x] Source `deploy-freshness-lib.sh` with deploy-tree-first / source-store-fallback resolution; *(completed)*
      per D4, a missing library prints a loud `[deploy-check]` note and passes through, never
      exits.
- [x] Implement the conclusiveness convention, each branch emitting its own distinguishable *(completed: verified 6 branches + missing-library case via fixture)*
      `[deploy-check]` line to stderr: no `.return-meta.json` -> inconclusive pass-through; empty
      or absent `modified_files` -> inconclusive pass-through; no overlap -> not-applicable
      pass-through; cannot-verify freshness -> inconclusive pass-through; overlap and verified
      fresh -> proceed; **overlap and provably stale -> refuse, exit 6**, with no state.json write
      and no plan-file stamp.
- [x] Honour `--dry-run` exactly as the phase-check block does: preview the refusal, exit 0. *(completed)*
- [x] Update the script's header exit-code table with code 6 and add a paragraph describing the *(completed)*
      backstop, matching the existing `--phase-check` header paragraph's shape.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: Asserts exit code 6 is free (carried from Phase 1) and asserts six
conclusiveness branches. Confirm by running the script with `--dry-run` against a fixture built
for each branch and observing six distinguishable `[deploy-check]` messages; if a branch proves
unreachable or two collapse into one, record the actual branch count here rather than forcing six.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` — new Phase 0.5 block plus header
  exit-code documentation

**Verification**:
- `grep -c 'deploy-headless' agent-system/extensions/core/scripts/update-task-status.sh` returns
  0, and `grep -c 'verify-deploy' …` returns 0. This is the mechanical enforcement of the
  check-only contract (research constraint 3) and must be run, not merely reasoned about.
- `bash -n` passes; `shellcheck` produces no new findings relative to a pre-change run.
- Execute the modified script with `--dry-run` for a task whose `.return-meta.json` has no
  `modified_files`, and confirm exit 0 with the inconclusive note.
- Execute it for `postflight … research` and confirm the block does not fire at all.

---

### Phase 4: Regression suite for the backstop [COMPLETED]

**Goal**: A fixture-driven suite pinning every branch of the new backstop, including the
check-only contract and the refusal's no-write guarantee.

**Tasks**:
- [x] Create `scripts/tests/test-postflight-deploy-gate.sh` modelled structurally on *(completed)*
      `test-update-task-status.sh` (mktemp -d fixture repo, EXIT-trap cleanup, pass/fail/info
      helpers, exit 0 all-pass / 1 any-fail / 2 environment error).
- [x] **Resolution order inversion**: unlike the existing suites, resolve the files under test *(completed)*
      (`update-task-status.sh`, `lib/deploy-freshness-lib.sh`) **source-store-first**, so the
      suite is meaningful before a deploy has run. Every other dependency keeps the existing
      deploy-tree-first order.
- [x] Cover: overlap + stale -> exit 6 with state.json unchanged and plan file unstamped; *(completed: 7 cases, 19 assertions, all pass)*
      overlap + fresh -> exit 0 and transition applied; no overlap -> exit 0; missing
      `.return-meta.json` -> exit 0 with the inconclusive note; missing freshness library ->
      exit 0 with the loud note (D4); `--dry-run` + stale -> exit 0 with the preview line;
      `postflight … research` -> block does not fire.
- [x] Add one contract assertion that the backstop block contains no `deploy-headless` or *(completed)*
      `verify-deploy` reference, so research constraint 3 is enforced by a test rather than by
      reviewer memory.
- [x] Confirm `scripts/tests/run-all.sh` auto-discovers the new suite (it globs *(completed: confirmed via glob match, no registration needed)*
      `scripts/tests/test-*.sh` per extension; no registration edit should be needed).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: Asserts seven test cases and asserts `run-all.sh` needs no registration
edit. Confirm by running the suite and counting reported cases, and by running
`bash agent-system/extensions/core/scripts/tests/run-all.sh` and grepping its suite list for the
new filename. If auto-discovery does not pick it up, add explicit registration and record it here.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — new file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` exits 0 with
  every case reported PASS.
- Negative control: temporarily revert Phase 3's block in a scratch copy, run the suite against
  that copy, and confirm it FAILS. A suite that passes against the unmodified script is not
  testing anything and fails this phase.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` lists the new suite and its overall
  exit code is no worse than a pre-change baseline run.

---

### Phase 5: Serialized deploy trigger — single-task path (command-gate-out.sh) [NOT STARTED]

**Goal**: On a refusal observed at the true single-task `/implement` completion path, run
`deploy-headless.sh` exactly once from `command-gate-out.sh` — a point with no concurrency — then
re-attempt the transition, gated by a baseline-relative `verify-deploy.sh --findings` comparison.

**Tasks**:
- [ ] Extend gate-out's existing `gate_out_rc` handling: alongside the current `rc == 4`
      phase-check branch, add an `rc == 6` deploy-pending branch.
- [ ] In that branch: capture `verify-deploy.sh --findings --quiet | grep '^FINDING ' | sort -u`
      as the pre-baseline; run `deploy-headless.sh`; capture the post-findings set the same way;
      compute the set difference. Fold a `verify-deploy.sh` exit 2 into the findings vocabulary as
      one synthesized sentinel line, exactly as the Inter-Cycle Redeploy Checkpoint does — do not
      special-case it.
- [ ] Branch (a) `deploy-headless.sh` failed to land (exit 1 or 2): report loudly, do NOT
      re-attempt the transition, leave the task at `implementing`. Exit 3 is *not* this branch —
      exit 3 means the deploy landed.
- [ ] Branch (b) at least one newly-introduced finding: report loudly, do NOT re-attempt, leave
      the task at `implementing`.
- [ ] Branch (c) every post finding already present in the pre-baseline (the expected case today):
      announce with a `[PRE-EXISTING VERIFY-DEPLOY FAILURE …]`-shaped banner naming pre/post/new
      finding counts and the post exit code, then re-attempt
      `update-task-status.sh postflight … implement`.
- [ ] Log on fire (naming the task and the matched `agent-system/**` paths), on success (deployed
      artifact count and verify outcome), and on failure (failing gate, exit code, and whether the
      failure is new or pre-existing). This is the "not silent" leg of the Phase 7 carve-out and
      must exist in code before that prose is written.
- [ ] Never re-attempt more than once per gate-out invocation. A successful redeploy clears the
      staleness condition, so no separate idempotence store is needed; a second refusal after a
      successful deploy is a real signal and must surface, not loop.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: Asserts three failure branches mapping onto the Inter-Cycle Redeploy
Checkpoint's (a)/(b)/(c). Confirm at implementation time by re-reading
`batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint` **Failure
contract** and **Exit-2 resolution** subsections and mapping each branch one-to-one; if the
mapping is not one-to-one, record the divergence and its reason rather than silently reshaping it.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` — `rc == 6` branch

**Verification**:
- `bash -n` passes.
- Execute the branch logic in isolation against a scratch fixture with a stubbed
  `deploy-headless.sh` that returns 0, 1, and 3 in turn, and stubbed `verify-deploy.sh` findings
  sets producing empty, new-finding, and all-pre-existing differences. Confirm all three branches
  are reached and produce distinguishable output. Nine combinations is more than needed; cover at
  minimum: (deploy 1) -> branch a; (deploy 3, new finding) -> branch b; (deploy 3, all
  pre-existing) -> branch c with a re-attempt.
- Confirm branch (c) actually re-invokes `update-task-status.sh` by observing the call in the
  stub's log, not by reading the source.

---

### Phase 6: Refusal propagation in skill-base.sh and the multi-task batch trigger [NOT STARTED]

**Goal**: Stop `skill_postflight_update` from silently swallowing a refusal, and add the second
serialized deploy trigger at `commands/implement.md` Step 4 for the multi-task batch path.

**Tasks**:
- [ ] `skill_postflight_update` currently invokes `update-task-status.sh` and proceeds to hooks
      and events without capturing its exit code at all — so a refusal (today's exit 4, and now
      exit 6) is invisible to every caller. Capture the rc into a local, keep the hook and event
      legs running unconditionally as they do today, and return the captured rc from the function.
- [ ] On rc 6 specifically, emit a named `[deploy-check] deploy-pending` line and record a
      `deploy-pending` reason into the task's `.return-meta.json` so `/orchestrate`'s and the team
      skills' own reporting surfaces the deferral instead of showing an unexplained non-completion
      (the D6 residual mitigation).
- [ ] Confirm by execution that returning a non-zero rc from `skill_postflight_update` does not
      abort any existing caller that runs under `set -e` — if any caller would newly abort, guard
      the call site pattern rather than reverting the rc capture, and record which callers were
      checked.
- [ ] In `commands/implement.md` Step 4 (already serial, already runs once after all of Step 3's
      parallel dispatches return), add a batch-refusal deploy trigger: if any dispatched task's
      postflight was refused for deploy staleness, run **one** `deploy-headless.sh` for the whole
      batch using the same (a)/(b)/(c) baseline-relative contract as Phase 5, then re-attempt each
      refused task's transition. Place it before the existing per-task `.return-meta.json`
      deletion loop, which would otherwise destroy the evidence the re-attempt needs.
- [ ] Do not add a trigger anywhere inside Step 3's parallel dispatch region.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: Asserts that `skill_postflight_update` has no existing rc-consuming caller
that would newly abort. Confirm by executing
`grep -rn 'skill_postflight_update' agent-system/extensions` and inspecting each call site's
`set -e` posture; enumerate the call sites found rather than assuming the count.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_postflight_update` rc capture,
  return, and rc-6 reason recording
- `agent-system/extensions/core/commands/implement.md` — Step 4 batch-refusal deploy trigger

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0.
- Source `skill-base.sh` in a scratch shell with a stubbed `update-task-status.sh` returning 0,
  4, and 6 in turn; confirm `skill_postflight_update` returns each rc verbatim and that the
  extension-hook and events legs still ran in all three cases (observe the stubs' logs).
- Confirm the Step 4 trigger text places the deploy strictly before the `.return-meta.json`
  deletion loop by reading the resulting step order back out of the file.

---

### Phase 7: Documentation — mechanism, carve-out, and the two-tier staleness model [NOT STARTED]

**Goal**: Record the mechanism once authoritatively, add the mandatory additive carve-out, and
document `check-deploy-freshness.sh`'s advisory-only role as tier 1 of a two-tier model.

**Tasks**:
- [ ] In `context/patterns/batch-orchestration-guardrails.md`, add a new subsection —
      `### The Postflight Completion-Deploy Gate` — as the single authoritative statement of this
      mechanism: trigger predicate (D7), the check-only contract (research constraint 3), the
      conclusiveness convention and its six branches, exit 6's ordering-constraint semantics (D2),
      the two serialized trigger sites and their shared (a)/(b)/(c) baseline contract, and the
      commit-granularity residual. Cross-reference `### The Inter-Cycle Redeploy Checkpoint` for
      the baseline mechanism by path rather than restating it.
- [ ] Add a Blocking-vs-Advisory classification entry for the new gate, satisfying both criteria:
      computable purely from on-disk structural state, and silent-and-hard-to-detect harm if
      skipped.
- [ ] In `context/patterns/regeneration-is-manual-only.md`, add a new subsection
      `## Automated Exception: The Postflight Completion-Deploy Gate` **immediately after** the
      existing `## Automated Exception: The Inter-Cycle Self-Modification Checkpoint` subsection
      and **before** `### deploy-headless.sh's Inline Verification and Exit Code 3`. Do not edit a
      single byte of the existing subsection.
- [ ] Write the carve-out in the existing subsection's exact three-part shape: **exact and only
      sanctioned call sites** (`command-gate-out.sh`'s post-refusal trigger for the single-task
      path; `commands/implement.md` Step 4's batch-refusal trigger for the multi-task path — and
      an explicit statement that `skill-orchestrate`'s Stage MT-3 step 7 is untouched and needs no
      new exception); **why this is not a side effect of an unrelated operation** (the deploy makes
      live precisely the change that triggered it); **why this is not silent** (naming the Phase 5
      log-on-fire / log-on-success / log-on-failure lines actually written); **why this is
      bounded** (evidence-gated on `modified_files` overlap, never unconditional; fires at most
      once per refusal, with a successful redeploy clearing the triggering condition).
- [ ] Close with the scope-limiter sentence in the existing subsection's shape: this carve-out
      licenses exactly the named call sites, nothing broader; it is **not precedent**; any future
      automated caller still needs its own exception recorded in this same section.
- [ ] Cross-reference the mechanism's authoritative home in `batch-orchestration-guardrails.md` by
      path rather than restating it, matching the existing exception's own cross-reference
      discipline.
- [ ] In `regeneration-is-manual-only.md`'s `## Detecting When You're Stale` section, add the
      two-tier statement: `check-deploy-freshness.sh` is tier 1 (silent, advisory, CHECKPOINT-1,
      always exit 0, never a gate); the postflight backstop is tier 2 (blocking, evidence-gated).
- [ ] Add the same forward-pointer to `check-deploy-freshness.sh`'s own header, keeping its
      existing "ALWAYS EXITS 0. This is not a preflight gate." sentence intact and adding the
      second sanctioned consumer (the shared library, per Phase 2) alongside its existing
      `command-gate-in.sh` caller statement.
- [ ] Add the new library and the new test suite to `regeneration-is-manual-only.md`'s
      `## Related Documentation` list.
- [ ] Record the D6 residual explicitly in the mechanism subsection: `/orchestrate` is covered by
      the backstop's refusal but has no serialized trigger of its own, so a refused task defers
      loudly rather than converging within that invocation; widening Stage MT-3 step 7's predicate
      is the proper fix and is named as follow-up work.

**Timing**: 1.5 hours

**Depends on**: 5, 6

**Verification Tier**: prose

**Scope Hypothesis**: Asserts the carve-out names exactly two new sanctioned call sites. Confirm
at implementation time against what Phases 5 and 6 actually built: run
`grep -rn 'deploy-headless' agent-system/extensions/core/scripts agent-system/extensions/core/commands`
and reconcile every automated invocation site found against the sanctioned list. If a third site
exists, it must either be removed or receive its own carve-out entry — an unrecorded caller is
exactly the drift the existing subsection forbids.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  `### The Postflight Completion-Deploy Gate` subsection and a classification-table entry
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — new additive
  carve-out subsection, two-tier statement, Related Documentation entries
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` — header forward-pointer only

**Verification**:
- `git diff` on `regeneration-is-manual-only.md` shows **zero** modified lines inside the existing
  `## Automated Exception: The Inter-Cycle Self-Modification Checkpoint` subsection. Verify by
  extracting that subsection from both `HEAD` and the working tree and byte-comparing them. Any
  difference fails the phase.
- Confirm by execution that the new subsection sits between the existing exception and
  `### deploy-headless.sh's Inline Verification and Exit Code 3`: `grep -n '^#'` the file and check
  the heading order.
- `bash .claude/scripts/check-extension-docs.sh --quiet` produces no *new* findings relative to
  Phase 1's baseline.
- `bash .claude/scripts/check-task-references.sh --quiet` produces no new findings — these
  deliverables live outside `specs/**` and must not cite task numbers.
- Re-run `check-deploy-freshness.sh` and byte-compare against Phase 1's baseline; a header-only
  edit must not change observable output.

---

### Phase 8: Deploy, verify, and self-demonstrate the gate [NOT STARTED]

**Goal**: Make the change live and prove the acceptance criterion by execution — including on this
task's own completion, which is the intended dogfooding case.

**Tasks**:
- [ ] Commit all source-store changes from Phases 2-7 (each phase commits its own green sub-steps
      as it goes; this step confirms nothing is left uncommitted, since the freshness signal is
      commit-granular and an uncommitted edit would make the gate report a false "fresh").
- [ ] Capture a fresh `verify-deploy.sh --findings --quiet` pre-baseline.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` once, deliberately and by hand. Record its
      exit code; exit 3 is the expected outcome given the repo's documented pre-existing failures.
- [ ] Capture the post-deploy findings set and compute the set difference against the pre-baseline.
      A non-empty difference means this task introduced a new failure and the phase fails.
- [ ] Confirm the deployed tree carries the change: byte-diff the source-store and deployed copies
      of `update-task-status.sh`, `check-deploy-freshness.sh`, `command-gate-out.sh`,
      `skill-base.sh`, and `lib/deploy-freshness-lib.sh`. All five must be identical.
- [ ] Confirm `check-deploy-freshness.sh` no longer reports `core` stale.
- [ ] Run the full suite from the deployed tree: `bash .claude/scripts/tests/run-all.sh`. Its
      outcome must be no worse than Phase 1's baseline, and both
      `test-postflight-deploy-gate.sh` and `test-deploy-freshness.sh` must pass.
- [ ] **Acceptance demonstration**: with the deploy fresh, confirm this task's own
      `postflight … implement` transition is permitted. Then, in a scratch fixture (never the live
      tree), stage a deliberately stale extension and confirm the same call refuses with exit 6,
      writes nothing to `state.json`, and stamps no plan file.
- [ ] Record in the implementation summary: this task's own completion was itself subject to the
      gate it introduced, and which of the two outcomes above the live run produced.

**Timing**: 1 hour

**Depends on**: 4, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts five deployed files must be byte-identical to their source-store
counterparts. Confirm by enumerating the actual changed file set from
`git diff --name-only` over the task's own commits, restricted to
`agent-system/extensions/core/`, rather than trusting this list of five. Any file in that set with
a deploy target must be byte-compared.

**Files to modify**:
- None in the source store. This phase deploys and verifies. `.claude/**` changes are produced by
  `deploy-headless.sh`, never by hand.

**Verification**:
- The pre/post findings set difference is empty.
- All five (or the confirmed actual set of) byte-diffs are empty.
- `check-deploy-freshness.sh` prints no WARN for `core`.
- `run-all.sh` outcome is no worse than baseline.
- Both acceptance demonstrations produce their expected outcome, observed from actual command
  output — not inferred from reading the code.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — all cases pass
- [ ] `bash agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` — all cases pass
- [ ] `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — no regression
- [ ] `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — no regression
- [ ] `bash .claude/scripts/tests/run-all.sh` — outcome no worse than the Phase 1 baseline
- [ ] `check-deploy-freshness.sh` output byte-identical to baseline after Phases 2 and 7
- [ ] `verify-deploy.sh --findings` set difference across the Phase 8 deploy is empty
- [ ] `check-extension-docs.sh` and `check-task-references.sh` produce no new findings
- [ ] Negative control: the new suite fails against a pre-Phase-3 copy of `update-task-status.sh`
- [ ] Contract assertion: no `deploy-headless`/`verify-deploy` reference inside the backstop block

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` (new)
- Modified: `update-task-status.sh`, `check-deploy-freshness.sh`, `command-gate-out.sh`,
  `skill-base.sh`, `commands/implement.md`, `test-deploy-freshness.sh`
- Modified docs: `batch-orchestration-guardrails.md` (new authoritative subsection),
  `regeneration-is-manual-only.md` (new additive carve-out + two-tier statement)
- Corrected `file_scope` in `specs/state.json`
- `specs/083_postflight_deploy_gate_for_source_store_tasks/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase commits independently, so rollback is per-phase `git revert` in reverse dependency
order (8 -> 7 -> 6 -> 5 -> 4 -> 3 -> 2 -> 1) followed by one deliberate `deploy-headless.sh` run
to restore the deployed tree.

The single highest-risk failure mode is a backstop that refuses when it should not, which would
block completion system-wide. Its containment is threefold: (1) the conclusiveness convention
makes every non-conclusive case a pass-through, so the default posture is permissive; (2) D4
guarantees a missing library degrades to pass-through rather than a hard exit; (3) the emergency
escape is a single deliberate `bash .claude/scripts/deploy-headless.sh`, which clears the
triggering condition for every affected task at once — the same remedy the refusal message names.

If Phase 3 lands but Phases 5-6 do not, the system is in a coherent intermediate state: the gate
refuses and the operator deploys by hand. That is strictly better than today's silent false
`[COMPLETED]` and is a safe stopping point if the task must be interrupted.
