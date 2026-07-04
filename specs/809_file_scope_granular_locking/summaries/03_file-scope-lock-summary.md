# Implementation Summary: Task #809

**Completed**: 2026-07-04
**Duration**: ~1 session (all 5 phases, single agent)

## Overview

Extended `.claude/scripts/task-lock.sh`'s `cmd_acquire` with a cross-task `file_scope` overlap
check that composes with the existing task-number lock (task 788): a fresh overlapping foreign
lock now refuses (exit 1) and a stale overlapping foreign lock warns and proceeds (exit 0),
leaving the foreign lock untouched. The overlap rule reuses `file-footprint-overlap.md`'s
directory-prefix algorithm exactly (transcribed to jq, not restated), and a short-lived
`specs/.scope-lock/` mutex closes the scan-then-mkdir TOCTOU race, failing closed (exit 2) on
timeout. `acquire`'s signature and 0/1/2 exit-code contract are unchanged — the new logic lives
entirely inside `cmd_acquire` plus five new internal helper functions, so no call site needs
edits. All edits were insert-only, coordinated around task 808's concurrent init-marker
additions to the same file (verified via `git diff -U1` hunk isolation).

## What Changed

- `.claude/scripts/task-lock.sh` — added `get_file_scope`, `scopes_overlap`, `find_held_locks`,
  `acquire_scope_mutex`, `release_scope_mutex` helpers (inserted between `age_minutes()` and
  `cmd_acquire()`); wired the mutex-guarded cross-task overlap scan into `cmd_acquire` before the
  own-task `mkdir`, using a function-scoped `trap release_scope_mutex RETURN` to guarantee mutex
  release on every exit path.
- `.claude/extensions/core/scripts/task-lock.sh` — mechanical mirror of the above (`diff -q`
  clean).
- `.claude/context/patterns/task-lock.md` — added a "Cross-Task `file_scope` Overlap Check"
  section, updated `acquire`'s numbered contract and the Scope section, added the cross-task
  ABORT message template, and closed the deferred "`file_scope`-granular cross-task locking"
  Non-Goal with a `~~strikethrough~~` note matching the doc's existing convention.
- `.claude/extensions/core/context/patterns/task-lock.md` — mechanical mirror (`diff -q` clean).
- `.claude/context/patterns/file-footprint-overlap.md` — added a third "Consumers" bullet for
  task-lock's acquire-time repo-wide scan; narrowed the repo-wide-scan "Non-Goals" bullet to
  clarify the algorithm has no scan-scope opinion. Pseudocode block byte-unchanged (verified).
- `.claude/extensions/core/context/patterns/file-footprint-overlap.md` — mechanical mirror
  (`diff -q` clean); this dual copy was discovered to already exist (the plan's assumption that
  it didn't was wrong — see Plan Deviations).

## Decisions

- Used a function-scoped `trap 'release_scope_mutex' RETURN` rather than instrumenting every
  individual `return` statement in `cmd_acquire`. Empirically verified in bash that this fires
  exactly once, on `cmd_acquire`'s own return, regardless of which internal branch executes or
  which nested functions run first — this required zero edits to the pre-existing own-task
  mkdir/holder branches.
- `scopes_overlap(scope_a, scope_b)` emits the overlapping path from `scope_b` (the "foreign"
  side, by the caller convention `scopes_overlap "$own_scope" "$other_scope"`), so the printed
  `overlap_path` always names a path in the OTHER task's declared scope for use in ABORT/WARN
  messages.
- `SCOPE_MUTEX_STALE_SEC=10` chosen as a short, distinct staleness window from
  `TASK_LOCK_STALE_MIN` (default 30 minutes) — a stuck `.scope-lock` is a bug, not ordinary
  contention, so acquisition fails closed after a bounded ~5s retry loop rather than ever
  failing open.

## Plan Deviations

- **Task 1.1** (helper insertion anchor) altered: the plan cited literal line numbers
  ("after line 146, before line 151") that were written before task 808 landed concurrently and
  shifted them. Anchored the insertion by function name (`age_minutes()` / `cmd_acquire()`)
  instead; verified via `git diff -U1` that the insertion is isolated to one hunk and
  `cmd_acquire`/the `case` block are untouched by this task.
- **Task 2.3** (mutex release on every return path) altered: used a `trap ... RETURN` instead of
  per-return-statement release calls (see Decisions above).
- **Task 4.3** (optional `file_scope` parity update in `state.json`) skipped: this dispatch's
  delegation context explicitly forbids modifying `specs/state.json` or `specs/TODO.md` (the
  orchestrator handles those). The update was attempted, then cleanly reverted via `jq` back to
  the original 3-entry `file_scope` array plus a `generate-todo.sh` re-run once the conflict was
  recognized; confirmed no trace remains via `git diff | grep -i extensions/core`.
- **Task 5.4** (mirror `file-footprint-overlap.md` to `extensions/core`) altered: the plan
  assumed no `extensions/core` dual copy existed for this file. `find` confirmed one DOES exist;
  mirrored it too, per the plan's own contingency instruction ("if one exists, mirror it too").

## Verification

- **Build**: N/A (bash script, not compiled).
- **Tests**: All sandbox scenarios passed (sandbox built under the scratchpad dir, mirroring
  `PROJECT_ROOT` layout with tasks 10/11/12 and overlapping/non-overlapping `file_scope`
  entries; never touched the live repo's `specs/`):

  | Scenario | Expected | Observed |
  |----------|----------|----------|
  | Overlap refusal (task 10 held, fresh; task 11 overlapping) | exit 1, ABORT names task 10 + path | exit 1, ABORT correct |
  | Non-overlap allowed (task 10 held; task 12 non-overlapping) | exit 0 | exit 0 |
  | Stale-overlap warn-and-proceed | exit 0, WARN, foreign holder.json untouched | exit 0, WARN; `md5sum` confirmed byte-identical |
  | Empty `file_scope` no-op (both directions) | exit 0, no ABORT/WARN | exit 0, silent, both directions |
  | Same-session bypass (literal same session) | exit 0 | exit 0 |
  | Same-session enforcement (`_10`/`_11`-suffixed sessions) | exit 1 | exit 1, ABORT correct |
  | TOCTOU mutex race (concurrent overlapping acquires) | exactly one exit 0, one exit 1 | confirmed across 6 trials (1 + 5 repeats), no `.scope-lock` leak |
  | Mutex fail-closed (pre-held fresh `.scope-lock`) | exit 2, not 0/1 | exit 2 after ~6s bounded timeout |
  | Regression: fresh same-session re-entry | exit 0 | exit 0 |
  | Regression: different-session fresh same-task | exit 1 | exit 1 |
  | Regression: different-session stale same-task override | exit 0, WARN | exit 0, WARN |

  `bash -n` passed on both `task-lock.sh` copies. `diff -q` confirmed byte-identical parity on
  all three dual-copy pairs (`task-lock.sh`, `task-lock.md`, `file-footprint-overlap.md`).
  `grep` over the diff confirmed no `rm`/`mv`/`write_holder` targets a foreign `lock_dir`
  anywhere in the new code. The live repo's `specs/` was confirmed unmodified by testing (no
  stray `.lock`/`.scope-lock` dirs beyond this task's own live lock).
- **Files verified**: Yes.

## Notes

- Task 808 (init-marker subcommand) landed concurrently in the same file; all 809 edits were
  insert-only and verified disjoint from 808's hunks via `git diff -U1`.
- Task 810 (wiring gate scripts into `/research`/`/plan`/`/revise`) requires zero changes from
  this task, since `acquire`'s signature and exit-code contract are byte-for-byte preserved.
- The optional `file_scope` parity update for task 809's own `state.json` entry (adding the
  three `extensions/core` mirror targets) was intentionally left undone per this dispatch's
  explicit state.json/TODO.md restriction; a future dispatch (or the orchestrator itself) may
  still apply it.
