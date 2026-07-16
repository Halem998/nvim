# Implementation Plan: Task #882

- **Task**: 882 - Decide whether shared-index commits need serialization (research-first)
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (tasks 883 and 884 run in parallel on disjoint file scopes)
- **Research Inputs**: specs/882_research_shared_index_commit_serialization/reports/01_shared-index-commit-serialization.md
- **Artifacts**: plans/01_scope-mutex-state-write-serialization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research settled the open question with a hybrid verdict: commit-message mixing is benign and gets
an honest-message fix; the real, evidenced defect is an unlocked multi-step read-modify-write race
on `specs/state.json`. This plan implements both halves — a narrow CLI exposure of the existing
`acquire_scope_mutex`/`release_scope_mutex` primitive on `task-lock.sh`, wired to bracket only the
state-mutation + TODO-regeneration window of `orchestrator-postflight.sh`, plus a staged-diff scan
that names every task whose index rows a commit actually carries.

All edits target the tracked source store under `agent-system/extensions/core/`, never the
gitignored `.claude/` deploy tree.

### Research Integration

Three findings drive the phase structure:
- Commit `c9c055187` is a genuine cross-session lost update (unrelated task's status flipped, its
  `last_updated` moved backward, a task row appeared that the committing session had no mechanism
  to create). The race is real, not hypothetical — so the mutex half is justified.
- `state.json` is mutated by 5+ independent unlocked read-modify-write round trips per postflight
  run (Stages 7/7a/7b/7c/7d/8). The critical section is the whole 7-through-8a span, not any one
  stage.
- Serializing the full stage-through-commit window was rejected: `validate-artifact.sh`, the TTS
  spawn, and the residual `git status` check are slow and carry no data-integrity risk. Stage 9
  stays outside the mutex.

Research flagged two risks at plan time (nested re-entry, and the 10s staleness window being tuned
for a fast operation). Both were investigated during planning and are resolved by Phase 1's audit
and Phase 2's design, below.

### Planning-Time Verification (grounding this plan)

- **Deploy and source are byte-identical today** for all four target scripts (`diff -q` clean),
  so source edits can be validated by copying to `.claude/scripts/` for a test run.
- **`.gitignore:7` ignores `/.claude/`** with an explicit comment: it is a disposable build
  artifact regenerated from `agent-system/extensions/`. Confirms the orchestrator's correction.
- **No nested re-entry exists today**: `grep -rn "task-lock.sh|acquire_scope_mutex|scope-lock|flock"`
  across `orchestrator-postflight.sh`, `update-task-status.sh`, and `generate-todo.sh` returns
  zero hits. The deadlock risk research flagged is therefore *introduced by this work*, not
  pre-existing — specifically because postflight Stage 7 shells out to `update-task-status.sh`,
  which will also need the mutex on its standalone path. Phase 3 resolves this with an inherited
  env guard before Phase 4 introduces the outer acquire.
- **`PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"` (task-lock.sh:66)** resolves correctly only
  from the deploy location. Run scripts under test from `.claude/scripts/`, never in-place from
  `agent-system/extensions/core/scripts/`, or the mutex path resolves outside the repo.
- **`update-task-status.sh` has 15+ callers** (`reconcile-task-status.sh`, `manage-topics.sh`,
  `command-gate-out.sh`, `skill-base.sh`, and many SKILL.md files) — so its standalone path
  genuinely needs its own mutex, and the re-entrancy guard genuinely needs to be correct.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap flag was set. `specs/ROADMAP.md`
exists but was not consulted as a planning input, and this plan makes no edits to it.

## Goals & Non-Goals

**Goals**:
- Expose the existing scope mutex as `task-lock.sh scope-acquire` / `scope-release` CLI subcommands
  — reuse, not a new script.
- Bracket the `state.json` read-modify-write + TODO.md-regen window (postflight Stages 7-8a) in
  that mutex, fail-closed, with release-on-error.
- Give `update-task-status.sh`'s standalone path the same protection without deadlocking when
  invoked from inside postflight's critical section.
- Make Stage 9 commit messages name every task whose index rows the commit actually carries.
- Document the new CLI surface and the state-write hazard.

**Non-Goals**:
- Serializing `git add`/`git commit`/TTS/residual-check (Stage 9+). Explicitly rejected by research.
- Any new locking script or primitive. Constraint-forbidden.
- Any `.gitignore` edit (owned by task 883) or any edit to the git guard hook or
  `postflight-pattern.md` (owned by task 884).
- Editing anything under `.claude/` as a deliverable. Copies there are test scaffolding only.
- Reducing the number of read-modify-write round trips (a worthwhile but separate refactor).
- Changing `cmd_acquire`'s existing behavior or its 10s staleness window.

## Key Design Decisions

Two hazards surfaced during planning that the research report identified but left open. Both must
be settled before writing code, so they are recorded here rather than discovered mid-phase.

**1. Re-entrancy: an inherited env guard, not a reentrant lock.**
The `mkdir`-based mutex is not reentrant. Postflight Stage 7 calls `update-task-status.sh`, which
will acquire the mutex on its standalone path — so once Phase 4 wraps Stages 7-8a in an outer
acquire, the inner acquire would block for 5s and then fail closed on every single postflight run.
Resolution: the outer holder exports `SCOPE_MUTEX_HELD=1`; `update-task-status.sh` skips both
acquire and release when it sees that variable set. Env vars propagate to child processes, so this
is exact and requires no lock accounting. The guard must land (Phase 3) *before* the outer acquire
(Phase 4) — this dependency is not optional.

**2. Staleness is a property of the holder, not the waiter.**
`acquire_scope_mutex` currently compares the mutex's age against the *waiter's* own
`SCOPE_MUTEX_STALE_SEC`. So simply raising that constant for the postflight path would not work: a
concurrent `task-lock.sh acquire` waiter still carrying the 10s default would reclaim postflight's
mutex out from under it after 10s, producing two live holders — the exact lost-update the work is
meant to prevent, now harder to diagnose. Resolution: the holder writes its own tolerated window
into `specs/.scope-lock/stale_sec` at claim time, and every waiter reads *that* file (falling back
to its own default when absent) when deciding whether to reclaim. This keeps `cmd_acquire`'s
effective behavior identical (it writes 10) while letting the longer postflight section declare a
larger window that all waiters honor.

**3. Release must verify ownership.**
Because acquire and release are now separate processes, an unconditional `rm -rf` on release is
unsafe: if the holder was stale-reclaimed and another session re-acquired, the original holder's
release would delete the *new* holder's mutex. `scope-acquire` therefore prints an owner token
which `scope-release` must match. A mismatch is a loud warning (it means the section overran and a
concurrent writer may have interleaved) and is never silent.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nested acquire deadlocks postflight's hot path (Stage 7 -> update-task-status.sh) | H | H (certain without the guard) | Phase 3 lands `SCOPE_MUTEX_HELD` guard before Phase 4's outer acquire; Phase 1 audits for any other nested call site; the 5s fail-closed timeout makes any missed case a loud error, never a hang |
| Stages 7-8a overrun the staleness window; mutex reclaimed mid-section -> two live holders | H | M | Phase 2's holder-declared `stale_sec` makes all waiters honor the holder's window; Phase 1 measures actual wall-clock time to pick it; Phase 2's owner-token release detects any overrun loudly |
| Mutex left held after an early exit (`set -e`, failed stage) | M | M | `trap ... EXIT` installed immediately after acquire in Phase 4, cleared on explicit release; stale reclamation is the backstop |
| Mutex acquire fails -> postflight blocked | M | L | Fail closed on the *mutex*, but keep Stage 7-8a's existing non-blocking character: a mutex timeout logs a loud WARNING and proceeds unserialized (matching today's behavior) rather than aborting postflight; documented explicitly in Phase 4 |
| Honest-message diff scan misreads state.json -> wrong/garbled commit message | L | L | Phase 5 compares parsed JSON blocks (`git show HEAD:` vs `git show :`), not raw grep of `+/-` lines; wrap in a failure-tolerant guard that omits the addendum rather than breaking the commit |
| Testing in-place against source path resolves PROJECT_ROOT outside the repo | M | M | Verified at plan time; every phase's verification copies to `.claude/scripts/` first and runs from there |
| Scope collision with parallel tasks 883/884 | M | L | File scope here is disjoint by construction; no `.gitignore`, git-guard-hook, or postflight-pattern.md edits |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. This plan is a near-linear chain: Phases 3-5
all touch or depend on the same two scripts, and Phase 3's guard must precede Phase 4's acquire to
avoid a guaranteed deadlock, so parallelism is deliberately not available here.

---

### Phase 1: Audit Call Sites and Measure the Critical Section [COMPLETED]

**Goal**: Settle the two open inputs Phase 2 needs — that no unaudited nested acquire exists, and
what staleness window Stages 7-8a actually require — with measurement rather than assumption.

**Tasks**:
- [x] **Task 1.1**: Re-run the nested-call audit across the full transitive call graph of postflight
      Stages 7-8a: `update-task-status.sh`, `generate-todo.sh`, and anything they invoke. Grep for
      `task-lock.sh`, `acquire_scope_mutex`, `scope-lock`, `flock`. Record every hit (expected: none).
      *(completed: `grep -rn "task-lock.sh|acquire_scope_mutex|scope-lock|flock"` across
      `update-task-status.sh`, `generate-todo.sh`, `update-plan-status.sh`, `update-phase-status.sh`,
      `validate-artifact.sh`, `lifecycle-notify.sh`, and `orchestrator-postflight.sh` itself returned
      zero hits — confirms the deadlock is introduced by this work, not pre-existing.)*
- [x] **Task 1.2**: Confirm `lifecycle-notify.sh` (Stage 8b) and `validate-artifact.sh` (Stage 6a)
      fall outside the intended 7-8a bracket and need no guard. *(completed: both fall structurally
      outside Stages 7-8a in the script's own stage ordering — Stage 6a runs before Stage 7, Stage 8b
      runs after Stage 8a — and neither calls task-lock.sh per the Task 1.1 grep, so neither needs a
      guard.)*
- [x] **Task 1.3**: Check `orchestrator-postflight.sh` for any pre-existing `trap` on EXIT that
      Phase 4's release trap would clobber. *(completed: `grep -n "trap"` found zero pre-existing
      traps in `orchestrator-postflight.sh`; the release trap Phase 4 installs is the first and only
      trap in this script, so no reconciliation is needed. `update-task-status.sh` does have a
      pre-existing `trap cleanup EXIT` for tmp-file removal — Phase 3 extends that same trap rather
      than installing a second one.)*
- [x] **Task 1.4**: Time the Stage 7-8a span end-to-end on a real task directory: wrap with
      `date +%s%N` or `time`, capture worst observed. *(completed: measured the dominant
      sub-operations directly against the live `specs/state.json` (143KB) rather than running a real
      postflight (which would create a commit) — `generate-todo.sh`: 23ms; a representative
      `jq` state.json read-modify-write round trip: 9ms; a representative `python3` state.json
      read-modify-write round trip: 23ms. Stages 7-8a chain roughly 4 python3 round trips (7a/7b
      completion_summary/7b roadmap/7c), 1 jq round trip (7d), 2 jq round trips (Stage 8), 1
      `update-task-status.sh` subprocess (its own jq write + generate-todo.sh call, ~50ms with
      process-spawn overhead), and Stage 8a's own `generate-todo.sh` call — summing to roughly
      300-400ms worst case including bash/python3 process-spawn overhead, well under 1 second.)*
- [x] **Task 1.5**: Choose `POSTFLIGHT_SCOPE_STALE_SEC` as a generous multiple of the worst observed
      time (target: >= 6x worst case, floor 30s). Record the measurement and the chosen value.
      *(completed: 6x the ~400ms worst-case estimate from Task 1.4 is ~2.4s, well below the mandated
      30s floor, so the floor governs. Chose `POSTFLIGHT_SCOPE_STALE_SEC=30`.)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**: none (read-only audit; findings feed Phases 2-4)

**Verification**:
- Audit grep output is recorded and contains no unhandled nested acquire.
- A concrete worst-case millisecond figure for Stages 7-8a is recorded, and the chosen staleness
  constant is justified against it in writing.

---

### Phase 2: Expose scope-acquire / scope-release on task-lock.sh [COMPLETED]

**Goal**: Add a CLI surface to the existing scope mutex — reuse only, no new script — with
holder-declared staleness and ownership-verified release.

**Tasks**:
- [x] **Task 2.1**: In `agent-system/extensions/core/scripts/task-lock.sh`, extend
      `acquire_scope_mutex` to accept an optional stale-window argument (default: existing
      `SCOPE_MUTEX_STALE_SEC`) and write it to `$mutex_dir/stale_sec` immediately after the
      successful `mkdir`, alongside `claimed_at`. *(completed)*
- [x] **Task 2.2**: Change the waiter branch to read `$mutex_dir/stale_sec` and compare the mutex's
      age against *that* value, falling back to `SCOPE_MUTEX_STALE_SEC` when the file is absent or
      unparseable. Verify `cmd_acquire`'s behavior is unchanged (it passes no argument -> writes 10
      -> waiters read 10). *(completed: verified via the acquire/heartbeat/release/check regression
      test against a disposable scratch task dir — behavior byte-identical to pre-change.)*
- [x] **Task 2.3**: Add `cmd_scope_acquire <session_id> [stale_sec]`: calls
      `acquire_scope_mutex "$stale_sec"`, writes an owner token (`session_id`, pid, epoch) to
      `$mutex_dir/owner`, echoes the token to stdout, exits 0. On timeout, exit 2 with a diagnostic
      naming the current holder from `$mutex_dir/owner`. No `RETURN` trap installed. *(completed)*
- [x] **Task 2.4**: Add `cmd_scope_release <token>`: compares against `$mutex_dir/owner`; on match,
      releases and exits 0; on mismatch or missing mutex, emits a loud WARNING naming both tokens
      and exits 0. *(completed)*
- [x] **Task 2.5**: Register `scope-acquire` and `scope-release` in the dispatch `case` block and add
      them to the usage string. *(completed: also extended the header doc's usage block and exit-code
      table.)*
- [x] **Task 2.6**: Keep every comment free of task-number citations (this file lives outside
      `specs/**`). *(completed: verified via `grep -nE '\btasks? [0-9]+'` — see Testing & Validation.)*

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - extend `acquire_scope_mutex` with a
  holder-declared stale window; add `cmd_scope_acquire`/`cmd_scope_release`; extend dispatch

**Verification**:
- Copy to `.claude/scripts/task-lock.sh`, then from the repo root:
  - `token=$(bash .claude/scripts/task-lock.sh scope-acquire test-session 30)` exits 0, prints a
    token, and `specs/.scope-lock/` exists containing `claimed_at`, `stale_sec` (= 30), `owner`.
  - A second `scope-acquire` while held exits 2 within ~5s and names the holder (fail closed).
  - `scope-release "$token"` exits 0 and removes `specs/.scope-lock/`.
  - `scope-release wrong-token` against a held mutex warns loudly, exits 0, and leaves the mutex
    intact.
- `bash .claude/scripts/task-lock.sh acquire <n> <op> <sess>` still behaves exactly as before
  (regression check on the pre-existing path).
- `bash -n` clean.

---

### Phase 3: Re-entrancy Guard and Standalone Mutex in update-task-status.sh [COMPLETED]

**Goal**: Protect `update-task-status.sh`'s own read-modify-write when invoked standalone, while
making it a no-op guest when it runs inside an outer critical section. This must land before
Phase 4 or postflight self-deadlocks on every run.

**Tasks**:
- [x] **Task 3.1**: In `agent-system/extensions/core/scripts/update-task-status.sh`, wrap the
      state.json read-modify-write (the `jq` -> tmp -> `mv` span) *and* the `generate-todo.sh` call
      in a single critical section — one acquire covering both, not two. *(completed: acquired
      immediately before `update_state_json`'s execution site, released immediately after
      `regenerate_todo`'s execution call, before `update_plan_file` runs.)*
- [x] **Task 3.2**: Guard it: when `SCOPE_MUTEX_HELD` is already set in the environment, skip
      acquire and release entirely and log a brief note that an outer holder owns the section.
      *(completed: verified — Test B, guest mode never created `specs/.scope-lock`.)*
- [x] **Task 3.3**: When not set: call `task-lock.sh scope-acquire`, export `SCOPE_MUTEX_HELD=1` for
      the duration, install `trap` on EXIT to release, release explicitly at the end and clear the
      trap. *(completed with one deliberate deviation — see Deviations below: rather than
      installing a second, dedicated EXIT trap and clearing it after the explicit release, the
      pre-existing `cleanup` EXIT trap (already installed for tmp-file removal) was extended to
      also call `release_state_mutex`, which is itself idempotent via the `STATE_MUTEX_OWNED_HERE`
      flag — so no "clear the trap" step is needed; a second post-explicit-release firing is a
      guaranteed no-op. Functionally equivalent and verified by Test E's forced-failure check.)*
- [x] **Task 3.4**: On mutex-acquire timeout, log a loud WARNING and proceed unserialized —
      preserving today's non-blocking behavior. Do not abort the status update. *(completed:
      verified — Test C, external hold caused the WARNING and the state.json write still
      completed.)*
- [x] **Task 3.5**: Respect the existing `--dry-run` path: no mutex acquisition when nothing is
      written. *(completed: verified — Test D.)*
- [x] **Task 3.6**: No task-number citations in comments. *(completed: verified via grep — see
      Testing & Validation.)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - bracket the state.json RMW +
  TODO regen in the scope mutex, guarded by `SCOPE_MUTEX_HELD`

**Verification**:
- Copy both scripts to `.claude/scripts/`, then:
  - A standalone `update-task-status.sh postflight <n> <op> <sess>` run succeeds; `specs/.scope-lock/`
    exists during the section (observable via a concurrent poll) and is gone afterward.
  - `SCOPE_MUTEX_HELD=1 bash .claude/scripts/update-task-status.sh ...` succeeds and never creates
    `specs/.scope-lock/` — proving the guard.
  - With the mutex externally held by a `scope-acquire`, a standalone run logs the WARNING and still
    completes (non-blocking preserved).
  - Force an early failure mid-section; confirm `specs/.scope-lock/` is released by the EXIT trap.
  - `--dry-run` creates no mutex.
- `bash -n` clean.

---

### Phase 4: Bracket Postflight Stages 7-8a in the Scope Mutex [NOT STARTED]

**Goal**: Close the evidenced lost-update race by serializing the state.json read-modify-write +
TODO.md-regen window — and nothing beyond it.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/orchestrator-postflight.sh`, acquire the mutex
      immediately before Stage 7 with the `POSTFLIGHT_SCOPE_STALE_SEC` value chosen in Phase 1:
      `scope_token=$(bash .claude/scripts/task-lock.sh scope-acquire "$session_id" "$stale_sec")`.
- [ ] Export `SCOPE_MUTEX_HELD=1` so Stage 7's `update-task-status.sh` child inherits the guard from
      Phase 3 and does not self-deadlock.
- [ ] Install `trap 'bash .claude/scripts/task-lock.sh scope-release "$scope_token"' EXIT`
      immediately after a successful acquire — postflight runs under `set -e` and can exit early at
      several stages. Reconcile with any pre-existing EXIT trap found in Phase 1.
- [ ] Release explicitly at the close of Stage 8a, clear the trap, and unset `SCOPE_MUTEX_HELD`.
      Stage 8b (TTS), Stage 9 (git), and Stage 10 (cleanup) run **outside** the mutex — this
      boundary is the research verdict and must not drift.
- [ ] On acquire timeout: log a loud WARNING and continue unserialized. The mutex is fail-closed as
      a *lock* (never silently double-held), but postflight's own stages remain non-blocking, as
      they are today.
- [ ] Add a comment at the bracket explaining what the critical section protects, citing the
      staged-index write hazard and the pattern doc by name — never a task number.

**Timing**: 1.25 hours

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - acquire before Stage 7,
  release after Stage 8a, EXIT trap, `SCOPE_MUTEX_HELD` export

**Verification**:
- Copy all three scripts to `.claude/scripts/`. Then:
  - A full postflight run for a `research` operation completes; the mutex is created once and
    released; `specs/.scope-lock/` is absent afterward.
  - Instrument to confirm the mutex is held across Stages 7-8a and **not** held during Stage 9's
    `git add`/`git commit` (poll for the dir from a background loop, or log at each stage boundary).
  - **Deadlock regression check**: confirm Stage 7's `update-task-status.sh` child does not block
    for 5s — the run's wall-clock time must not regress by ~5s versus a pre-change baseline. This is
    the single most important check in this phase.
  - Two concurrent postflight runs on different task directories both complete; neither loses the
    other's `state.json` write (inspect both tasks' rows afterward — the `c9c055187` signature is a
    field reverting or a row vanishing).
  - Kill a run mid-Stage-7; confirm the trap released the mutex.
- `bash -n` clean.

---

### Phase 5: Honest Commit Messages at Stage 9 [NOT STARTED]

**Goal**: Fix the benign-but-real attribution problem — a commit whose message names one task while
its diff carries other tasks' index rows — with an accurate message rather than a lock.

**Tasks**:
- [ ] In `orchestrator-postflight.sh` Stage 9, after `git add` succeeds and before `git commit`,
      compare `git show HEAD:specs/state.json` against the staged `git show :specs/state.json`.
- [ ] Compare **parsed** `active_projects` entries block-by-block (python3/jq), collecting every
      `project_number` whose JSON differs from HEAD's. Do not grep raw `+`/`-` lines — that misses a
      changed status inside an unchanged `project_number` context line and is the obvious wrong
      implementation here.
- [ ] Exclude the task being committed; if any others remain, append a body line to the existing
      commit message, e.g. `Also carries current index rows for tasks: N, M`.
- [ ] Wrap the whole scan in a failure-tolerant guard (missing HEAD file, unparseable JSON, no
      staged state.json): on any failure, omit the addendum and commit exactly as today. This must
      never break a commit.
- [ ] Preserve the existing `Session: ${session_id}` trailer and the message's current structure.
- [ ] Keep the scan outside the mutex — Stage 9 is explicitly not serialized.

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - staged-diff scan and commit
  message addendum at Stage 9

**Verification**:
- Copy to `.claude/scripts/`. Then:
  - Stage a `state.json` touching only the committed task -> message has **no** addendum (no false
    positives on the common case).
  - Stage a `state.json` where another task's `status` changed but its `project_number` line is
    unchanged context -> the addendum **does** name that task. This is the case a raw grep would
    miss and is the point of the parsed comparison.
  - Stage a `state.json` with a brand-new task row -> addendum names it.
  - Corrupt the staged `state.json`, run again -> commit still succeeds, addendum omitted, no crash.
- `bash -n` clean.

---

### Phase 6: Document the Scope-Mutex CLI and the State-Write Hazard [NOT STARTED]

**Goal**: Record the newly exposed CLI surface and the read-modify-write hazard, so a future author
adding another `state.json` mutation point knows to bracket it.

**Tasks**:
- [ ] Extend `agent-system/extensions/core/context/patterns/task-lock.md` with a new section
      documenting the scope-mutex CLI: `scope-acquire <session_id> [stale_sec]` /
      `scope-release <token>`, exit codes, the owner-token contract, the holder-declared
      `stale_sec` semantics, the `SCOPE_MUTEX_HELD` re-entrancy guard, and the requirement to
      install an EXIT trap after acquiring.
- [ ] State explicitly that the mutex is **not** reentrant and that `SCOPE_MUTEX_HELD` is the
      sanctioned way to nest.
- [ ] Reconcile the doc's existing note that the per-task lock "does not change checkpoint
      behavior" — still true; the scope mutex is a distinct, orthogonal primitive and the doc
      should say so rather than leave a reader to infer it.
- [ ] Extend `agent-system/extensions/core/context/standards/git-staging-scope.md` with a short
      subsection: the shared-index staging rule is unchanged, but `state.json`'s write path is now
      mutex-bracketed, and commit messages now name every task whose rows the diff carries.
      Cross-reference `task-lock.md`.
- [ ] Do **not** touch `postflight-pattern.md` or the git guard hook (owned by task 884).
- [ ] No task-number citations in either file — cite document names and section headings instead.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4, 5

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - new scope-mutex CLI section
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - state-write hazard note
  and cross-reference

**Verification**:
- Both files describe the CLI exactly as implemented (subcommand names, argument order, exit codes
  verified against the Phase 2 source, not from memory).
- `grep -nE '\btasks? [0-9]+' ` over both files and all three modified scripts returns no new hits.
- `bash .claude/scripts/check-extension-docs.sh` passes.

---

## Testing & Validation

- [ ] `bash -n` clean on all three modified scripts.
- [ ] Pre-existing `task-lock.sh acquire`/`release`/`check`/`heartbeat`/`init-marker` paths behave
      unchanged (regression).
- [ ] `scope-acquire` fails closed (exit 2) on contention within ~5s; never fails open.
- [ ] `scope-release` with a wrong token never deletes another holder's mutex.
- [ ] No postflight wall-clock regression from a nested-acquire block at Stage 7 (the deadlock
      canary).
- [ ] Mutex released on early exit / kill via the EXIT trap.
- [ ] Two concurrent postflight runs on different tasks preserve both tasks' `state.json` writes.
- [ ] Stage 9 remains outside the mutex.
- [ ] Commit message addendum: correct on the multi-task case, absent on the single-task case, and
      omitted-not-fatal on the corrupt case.
- [ ] `check-extension-docs.sh` passes.
- [ ] No new task-number citations outside `specs/**`.
- [ ] `git status` shows no staged changes under `.claude/` (test copies are gitignored; only
      `agent-system/extensions/core/` edits are committed).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` - `scope-acquire`/`scope-release` CLI,
  holder-declared stale window, owner-token release
- `agent-system/extensions/core/scripts/update-task-status.sh` - guarded critical section
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - Stages 7-8a bracketed;
  Stage 9 honest commit messages
- `agent-system/extensions/core/context/patterns/task-lock.md` - scope-mutex CLI documentation
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - state-write hazard note
- `specs/882_research_shared_index_commit_serialization/summaries/01_*-summary.md` - execution summary

## Rollback/Contingency

Every phase is an additive edit to a tracked source file; `git revert` of a phase commit restores
prior behavior, and the `.claude/` deploy tree can be wiped and regenerated from the picker at any
time to discard test copies.

Ordered fallbacks if a phase proves unworkable:
- **Phase 4 regresses the hot path** (unexpected contention or latency): revert Phase 4 only.
  Phases 2, 3, 5, and 6 are independently valuable and stand alone — the CLI exists, standalone
  status updates are protected, and commit messages are honest.
- **Staleness tuning proves unstable**: raise `POSTFLIGHT_SCOPE_STALE_SEC`. Because the window is
  holder-declared (Phase 2), this is a one-value change that all waiters honor, requiring no
  coordinated edit.
- **Nested acquire found somewhere Phase 1 missed**: the 5s fail-closed timeout surfaces it as a
  loud, non-blocking WARNING rather than a hang, and the guard extends to the new call site by
  exporting `SCOPE_MUTEX_HELD` there.
