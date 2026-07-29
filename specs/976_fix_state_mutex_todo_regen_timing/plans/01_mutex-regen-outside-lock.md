# Implementation Plan: Move TODO regeneration out of the state mutex critical section

- **Task**: 976 - Move TODO regeneration out of the state mutex critical section (or extend the window)
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: Task 965
- **Research Inputs**: specs/976_fix_state_mutex_todo_regen_timing/reports/01_mutex-timing-defect.md
- **Artifacts**: plans/01_mutex-regen-outside-lock.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`state-write.sh --regen-todo` runs `generate-todo.sh` inside the `specs/.scope-lock` critical
section, holding the mutex for a measured 6.88s against the live 101-task state.json — longer
than the 5000ms waiter acquire budget and more than half the 10s staleness reclaim window. The
fix is to release the mutex immediately after the atomic `mv` and run regeneration
unsynchronized, which drops the critical section to a measured ~13ms; a single-pass jq rewrite
of `generate-todo.sh` then removes the wall-clock cost itself, and a new isolated-temp-root test
locks in both properties. Definition of done: two concurrent status flips both succeed with a
consistent final state, the measured mutex hold for a status flip is well under 1s, and the
existing `test-state-write-concurrency.sh` suite still passes 4/4.

### Research Integration

The research report is followed as written on its primary recommendation (items 1 + 3 + 4, with
item 2 as optional defense-in-depth). Key findings carried into phase design:

- `release_mutex()` is already idempotent and already a no-op when `MUTEX_OWNED_HERE=false`, so
  "release early, then regen, then let the EXIT trap's second release be a no-op" needs no new
  machinery and leaves guest mode (nested under `orchestrator-postflight.sh`'s own
  `POSTFLIGHT_SCOPE_STALE_SEC=30` bracket) byte-for-byte unchanged.
- `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` is a hardcoded constant with no CLI parameter and no env-var
  indirection. Raising `stale_sec` alone therefore cannot close the spurious-ABORT failure mode;
  it is additive hardening only, never a substitute for Phase 1.
- The dominant cost in `generate-todo.sh` is jq subprocess-spawn count (~2.3ms per spawn),
  not input size — so the rewrite target is spawn count, not parse efficiency.

**One correction to the research's stated expectation.** The report predicts the single-pass jq
rewrite takes `generate-todo.sh` "from ~6.9s to well under 1s". That is not reachable within the
declared file scope: `generate-todo.sh` shells out to `generate-task-order.sh --print`, which
independently costs **2.38s** (measured directly), and that script is not in this task's
`file_scope`. The realistic Phase 4 target is therefore ~2.5-3.0s total wall time, of which
~2.4s is the out-of-scope `generate-task-order.sh` and the per-task loop drops from ~4.5s to
well under 0.5s. See the Scope Notes section below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided in the delegation context).

## Scope Notes

Two items surfaced that sit outside the task's declared `file_scope`. Neither is silently
expanded into; both are recorded here for the implementer and for the task's own follow-up
accounting.

1. **`generate-task-order.sh` is 2.38s of the 6.88s and is out of `file_scope`.** It is invoked
   by `generate-todo.sh` (in `generate_todo()`, the Task Order section) and will remain the
   dominant residual cost after Phase 4. This does **not** threaten the verification bar, because
   Phase 1 removes regeneration from the critical section entirely — the residual 2.4s is a
   wall-clock/UX cost, not a mutex-hold cost. **Do not modify `generate-task-order.sh` in this
   task.** If its cost is judged worth eliminating, that is a separate follow-up.

2. **`task-lock.sh` is in `file_scope` but is not required to change.** Phase 1 alone satisfies
   the verification bar with three orders of magnitude of margin. Phase 2 (optional) changes only
   the argument `state-write.sh` passes to `scope-acquire`, not `task-lock.sh` itself. No phase
   in this plan edits `task-lock.sh`; making `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` overridable is
   deliberately excluded as unnecessary once the critical section is ~13ms.

## Goals & Non-Goals

**Goals**:
- Reduce the `state-write.sh` mutex hold time for a `--regen-todo` status flip from ~6.9s to
  well under 1s, verifiably.
- Preserve guest mode (`SCOPE_MUTEX_HELD=1`) behavior exactly, so `orchestrator-postflight.sh`'s
  existing widened-bracket design continues to work unchanged.
- Eliminate the per-task jq subprocess storm in `generate-todo.sh` while producing
  byte-identical TODO.md output.
- Add a regression guard that fails if regeneration is ever moved back inside the mutex.

**Non-Goals**:
- Making `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` parameterizable (not needed once the hold is ~13ms).
- A generation-counter / re-check scheme for TODO.md regeneration. The task description
  explicitly sanctions last-writer-wins semantics for a generated view; `generate-todo.sh`'s
  existing atomic tempfile-then-`mv` write already precludes a torn file.
- Speeding up or otherwise touching `generate-task-order.sh` (see Scope Notes).
- Any change to `.claude/**`. That tree is a disposable deploy artifact; all edits land in
  `agent-system/extensions/core/scripts/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Early release breaks guest-mode reentrancy; a nested call releases an outer holder's mutex | H | L | `release_mutex()` is already guarded by `MUTEX_OWNED_HERE`, which is only ever set on the owned-here path. Case 4 of `test-state-write-concurrency.sh` exercises exactly this distinction and must still pass. |
| `state-write.sh` is the funnel for every state.json write in the repo; a mistake is high blast radius | H | L | Phase 1 is a deliberately minimal, independently revertible diff (move one block, add one call). Full existing suite re-run before the phase closes. |
| Single-pass jq rewrite silently changes TODO.md formatting | M | M | Phase 4 captures a golden baseline from the real state.json BEFORE editing and asserts byte-identical output after. Rewrite does not close until the diff is empty. |
| New timing test becomes vacuous once Phase 4 makes regeneration fast | M | H | Phase 3's fixture substitutes a controlled slow regeneration stub inside `$TMPROOT` rather than depending on the real script's wall-clock cost, so the assertion is independent of Phase 4. |
| Source-store edits do not reach the live `.claude/scripts/` tree, so downstream tasks see no change | M | M | Phase 5 redeploys and diffs the deployed copy against the source store before the task closes. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Wave 2's three phases own disjoint files
(`state-write.sh`, a new test file, `generate-todo.sh` respectively).

---

### Phase 1: Release the mutex before TODO regeneration [COMPLETED]

**Goal**: `state-write.sh --regen-todo` releases the `specs/.scope-lock` mutex immediately after
the atomic `mv` and runs `generate-todo.sh` outside the critical section, with guest-mode
behavior unchanged.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/state-write.sh`, insert an explicit
      `release_mutex` call immediately after the `mv "$STAGE_FILE" "$STATE_FILE"` / `STAGE_FILE=""`
      pair and BEFORE the `if [ "$REGEN_TODO" = true ]` block. *(completed)*
- [x] Confirm no other statement is moved: the regeneration block itself stays where it is, and
      the `trap cleanup EXIT` remains registered (its later `release_mutex` becomes a no-op
      because `MUTEX_OWNED_HERE` is already `false`). *(completed)*
- [x] Update the `--regen-todo` usage comment in the file header, which currently states that
      regeneration "runs INSIDE the critical section, after the `mv` and before mutex release".
      Replace with an accurate description: regeneration runs AFTER mutex release in owned-here
      mode, and inside the outer caller's bracket in guest mode. State the last-writer-wins
      trade-off for TODO.md in one sentence. *(completed)*
- [x] Add a short inline comment at the new `release_mutex` call explaining why it is there
      (regeneration wall time exceeds the mutex acquire budget and staleness window). Reference
      the variable names `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` and `SCOPE_MUTEX_STALE_SEC` as durable
      anchors — do NOT cite any task number in the script. *(completed)*
- [x] Verify guest mode is untouched by reading `release_mutex()` and confirming its
      `MUTEX_OWNED_HERE = true` guard makes the new call a no-op when `SCOPE_MUTEX_HELD=1` was
      inherited. *(completed: confirmed by code inspection — MUTEX_OWNED_HERE stays false on the
      guest branch of acquire_mutex(), so release_mutex() is a no-op there)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: full

**Verification**:
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` passes 4/4,
  including case 4 (guest-mode reentrancy) and case 3 (fail-closed acquire).
- `bash -n agent-system/extensions/core/scripts/state-write.sh` clean.
- Manual read-through confirming exactly one behavioral change: the position of the first
  `release_mutex` call relative to the regeneration block.
- Confirm no task-number citation was introduced into the script (deliverable rule).

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh` - explicit `release_mutex` before the
  regeneration block; corrected header comment for `--regen-todo`.

---

### Phase 2: Defense-in-depth staleness widening [COMPLETED]

**Goal**: `state-write.sh` passes an explicit staleness window to `scope-acquire` instead of
silently inheriting the 10s default, mirroring `orchestrator-postflight.sh`'s existing posture.

**Optional phase.** The verification bar is already met by Phase 1 alone (critical section drops
to ~13ms). This phase adds margin against a future slow operation being introduced inside the
now-regeneration-free critical section. It may be skipped without affecting the task's stated
verification bar; if skipped, record that decision rather than dropping the phase silently.

**Tasks**:
- [x] In `acquire_mutex()` in `state-write.sh`, define a named constant near the top of the file
      (e.g. `STATE_WRITE_SCOPE_STALE_SEC=30`) and pass it as the second argument to
      `task-lock.sh scope-acquire "$SESSION_ID"`. *(completed)*
- [x] Confirm against `cmd_scope_acquire()` in `task-lock.sh` that the second positional argument
      is the optional `stale_sec` override and that passing it requires no change to
      `task-lock.sh`. *(completed: confirmed, no change to task-lock.sh)*
- [x] Add a one-line comment stating explicitly that this widens the STALENESS window only, and
      that `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` is a separate, non-overridable constant that this
      change does not affect — so a future reader does not mistake it for a fix to waiter-timeout
      ABORTs. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Verification**:
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` still passes 4/4
  (case 3's fail-closed acquire assertion is the one most sensitive to this change — confirm it
  still fails closed rather than waiting longer).
- `bash -n` clean.

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh` - named staleness constant, passed to
  `scope-acquire`.

---

### Phase 3: Regression test for mutex hold time and concurrent status flips [COMPLETED]

**Goal**: A new isolated-temp-root test proves (a) two concurrent `state-write.sh --regen-todo`
calls both succeed with a consistent final state, and (b) the mutex is released before
regeneration runs.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/test-state-write-regen-timing.sh`, following
      `test-state-write-concurrency.sh`'s conventions exactly: throwaway `$TMPROOT`, scripts
      copied byte-for-byte into `$TMPROOT/.claude/scripts/`, fixture `specs/state.json`, no
      testability hooks added to production code, `pass`/`fail`/`info` helpers, exit 0 on all
      pass and 1 on any failure. *(completed)*
- [x] Case 1 (mutex released before regeneration): replace the COPIED `generate-todo.sh` inside
      `$TMPROOT` with a controlled stub that blocks on an observable predicate (e.g. writes a
      marker file, then waits for a release file to appear, on a bounded budget). Start
      `state-write.sh --regen-todo` in the background; wait for the stub's marker; then, from the
      foreground, acquire `specs/.scope-lock` via `task-lock.sh scope-acquire` and assert the
      acquire SUCCEEDS while the stub is still blocked. Release the stub, reap the background
      job, assert exit 0. *(completed)*
- [x] Case 2 (two concurrent status flips both succeed): launch two `state-write.sh --regen-todo`
      calls concurrently, each applying a distinct, commutative increment to the fixture state.
      Assert both exit 0 (no ABORT / exit 2) and that the final `state.json` reflects BOTH
      writes — the no-lost-update property, checked by value, not by exit code alone. *(completed)*
- [x] Case 3 (guest mode still serializes regeneration): with `SCOPE_MUTEX_HELD=1` exported and
      an outer holder owning the mutex, assert the inner `state-write.sh --regen-todo` does NOT
      release the outer holder's mutex — i.e. the mutex is still held after the inner call
      returns. *(completed)*
- [x] Document at the top of the new file why the regeneration stub is a controlled dependency
      rather than a violation of the "scripts under test are copied unmodified" convention: the
      script under test is `state-write.sh`; `generate-todo.sh` is a dependency whose cost the
      fixture controls, exactly as the precedent suite controls transform cost through a heavy jq
      `range` rather than a blind `sleep`. *(completed)*
- [x] Use real predicates and bounded polling throughout. No blind `sleep` to fake an ordering.
      *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the new test file is the ONLY file it creates or
modifies, and that it needs no change to `test-state-write-concurrency.sh`. Confirm at
implementation time by (a) running `git status --short` after the phase and checking exactly one
new untracked file under `agent-system/extensions/core/scripts/`, and (b) re-running the existing
suite unchanged. A second hypothesis: the fixture needs only `state-write.sh`, `task-lock.sh`,
and `deploy-root-guard.sh` copied (NOT `generate-task-order.sh`), because the regeneration stub
replaces the real `generate-todo.sh`. Confirm by running the new test and checking it does not
error on a missing script; if the real `generate-todo.sh` is used in any case,
`generate-task-order.sh` MUST also be copied into the fixture or that case's regeneration will
exit 1 and the assertion will be vacuous.

**Verification**:
- New test exits 0 with all cases passing against the post-Phase-1 `state-write.sh`.
- Adversarial check: temporarily revert Phase 1's `release_mutex` placement in a scratch copy and
  confirm case 1 FAILS. A regression guard that cannot fail on the pre-fix code is not a guard.
  Restore the fixed version afterwards.
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` still 4/4.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-state-write-regen-timing.sh` - new test file.

---

### Phase 4: Single-pass jq rewrite of generate-todo.sh [NOT STARTED]

**Goal**: Replace the per-task jq subprocess storm with one full-file jq pass, producing
byte-identical TODO.md output.

**Tasks**:
- [ ] BEFORE any edit, capture a golden baseline against the real repository state:
      `bash .claude/scripts/generate-todo.sh --dry-run --no-log > <scratch>/todo-golden.txt`
      and record its wall time. This is the correctness oracle for the whole phase.
- [ ] Replace the outer loop's per-task status-only full-file jq call in `generate_todo()` — the
      one feeding `terminal_count`/`active_count` — so status is read from the single upstream
      pass instead of re-parsing `state.json` once per task.
- [ ] Replace `generate_task_entry()`'s field extraction: emit ONE jq call over
      `active_projects` producing, per task and already sorted descending by `project_number`,
      all fields the current code extracts (`project_number`, `project_name`, `title`, `status`,
      `task_type`, `topic`, `effort`, `description`, `dependencies`, `artifacts`) in a
      newline-safe encoding (NDJSON with base64-encoded fields, or a delimiter-per-record scheme
      that survives the multi-line `description` values present in the live state.json).
- [ ] Convert the bash side to pure formatting: `printf`/string interpolation plus the existing
      artifact type-grouping associative-array logic, with zero jq spawns per task.
- [ ] Fold the existing `sort -rn` into the jq pass, removing the separate
      `jq ... | sort -rn` pipeline.
- [ ] Preserve every existing formatting rule exactly: title fallback from `project_name`,
      omission of empty/`null` `effort`/`topic`/`description`, `Dependencies: None` vs
      `Task N, Task M`, single-artifact inline `- **Type**: [path]` vs multi-artifact indented
      list, the `specs/` prefix strip, and the `\n---\n\n` separator placement.
- [ ] Diff the regenerated dry-run output against the golden baseline. The phase does not close
      until the diff is empty.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: The research asserts 8-12 jq spawns per task and ~1,000-1,200 total across
101 tasks, and predicts a post-rewrite wall time "well under 1s". The spawn counts are plausible
but unconfirmed, and the wall-time prediction is known to be wrong: `generate-task-order.sh`
independently costs 2.38s (measured) and is out of scope, so the achievable total is ~2.5-3.0s.
Confirm at implementation time by (a) counting actual jq invocations before and after — e.g. run
under a jq wrapper on `$PATH` that increments a counter, or reason from the final source that no
jq call remains inside the per-task loop; and (b) timing `generate-todo.sh --dry-run` before and
after and reporting BOTH the total and the total minus the `generate-task-order.sh` component.
Report measured numbers; do not restate the research's or this plan's estimates as results.

**Verification**:
- `diff <golden baseline> <post-rewrite --dry-run output>` is empty.
- Measured wall time reported for before and after, with the `generate-task-order.sh` component
  broken out separately.
- `bash -n agent-system/extensions/core/scripts/generate-todo.sh` clean.
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` still 4/4.
- Edge cases checked against the live data: at least one task with a multi-line `description`,
  one with multiple artifacts of the same type, one with no artifacts, and one with empty
  `topic`/`effort` all render identically to the golden baseline (implied by the empty diff, but
  confirm these cases actually exist in the fixture data rather than assuming coverage).

**Files to modify**:
- `agent-system/extensions/core/scripts/generate-todo.sh` - single-pass jq extraction in
  `generate_task_entry()` and `generate_todo()`.

---

### Phase 5: Deploy sync and full verification sweep [NOT STARTED]

**Goal**: The live `.claude/scripts/` tree carries the fixed scripts, and the complete
verification bar is demonstrated end to end.

**Tasks**:
- [ ] Redeploy the core extension so `.claude/scripts/state-write.sh` and
      `.claude/scripts/generate-todo.sh` reflect the source store (via the headless deploy path
      at `agent-system/extensions/core/scripts/deploy-headless.sh`, or the loader's Load Core
      sync). Note the known deploy-mechanism gap: a brand-new script file may not reach an
      already-deployed repo automatically — the new test file from Phase 3 must be confirmed
      present at `.claude/scripts/test-state-write-regen-timing.sh` or explicitly reported as
      not deployed.
- [ ] `diff` each changed source-store script against its deployed counterpart; both must be
      identical.
- [ ] Run both test suites from the deployed tree:
      `test-state-write-concurrency.sh` and `test-state-write-regen-timing.sh`.
- [ ] Measure the live mutex hold for a real status flip and report the number. Acceptable
      method: time a `state-write.sh --regen-todo` invocation against a scratch copy of the real
      state.json with the regeneration step instrumented, or time the acquire-to-release window
      directly. Report the measured value against the "under 1s" bar.
- [ ] Run `bash .claude/scripts/check-task-references.sh` (or the source-store equivalent) to
      confirm no task-number citation leaked into any modified script.
- [ ] Record in the implementation summary which phases landed, any skipped optional phase
      (Phase 2), and the measured before/after numbers.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Verification**:
- Deployed and source-store copies diff clean for every modified script.
- Both suites pass from the deployed tree.
- Measured mutex hold for a status flip reported and under 1s.
- No task-number citations in `agent-system/extensions/core/scripts/**` changes.

**Files to modify**:
- None (verification and deploy only). Deploy writes to `.claude/**` via the sanctioned deploy
  process, which is not a source-store-boundary violation.

---

## Testing & Validation

- [ ] `test-state-write-concurrency.sh` passes 4/4 after every phase (no-lost-update, staging
      isolation, fail-closed acquire, guest-mode reentrancy).
- [ ] New `test-state-write-regen-timing.sh` passes all cases, and is demonstrated to FAIL
      against a pre-fix `state-write.sh`.
- [ ] Two concurrent `state-write.sh --regen-todo` calls both exit 0 with a final state
      reflecting both writes.
- [ ] Measured mutex hold time for a status flip is under 1s (research measured ~13ms for the
      write cycle without regeneration).
- [ ] `generate-todo.sh --dry-run` output is byte-identical to the pre-rewrite golden baseline.
- [ ] Measured `generate-todo.sh` wall time reported before and after, with the out-of-scope
      `generate-task-order.sh` component broken out.
- [ ] `bash -n` clean on every modified script.
- [ ] No task-number citations introduced outside `specs/**`.

## Artifacts & Outputs

- `specs/976_fix_state_mutex_todo_regen_timing/plans/01_mutex-regen-outside-lock.md` (this file)
- `specs/976_fix_state_mutex_todo_regen_timing/summaries/01_mutex-regen-outside-lock-summary.md`
- Modified: `agent-system/extensions/core/scripts/state-write.sh`
- Modified: `agent-system/extensions/core/scripts/generate-todo.sh`
- New: `agent-system/extensions/core/scripts/test-state-write-regen-timing.sh`

## Rollback/Contingency

Each phase is an independently revertible commit against a distinct file, so rollback is
per-phase rather than all-or-nothing.

- **Phase 1** is a single moved call plus a comment. `git revert` of its commit restores the
  in-mutex regeneration exactly. Because it is on the critical path for four downstream tasks,
  revert only on a demonstrated correctness failure in `test-state-write-concurrency.sh`, not on
  a timing disappointment.
- **Phase 2** is optional and independently revertible; reverting it restores the inherited 10s
  default with no effect on Phase 1's benefit.
- **Phase 4** is the highest-churn change. If the golden-baseline diff cannot be driven to empty
  within the phase budget, revert `generate-todo.sh` to its pre-phase state and close the phase
  as `[COMPLETED WITH EXCLUSIONS]` with the diff evidence recorded. Phase 1 alone satisfies the
  task's verification bar, so an abandoned Phase 4 does not block the task or its dependents.
- Before any rollback that would discard uncommitted work, run
  `bash .claude/scripts/git-snapshot.sh 976` first.
