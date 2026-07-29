# Implementation Summary: Task #976

- **Task**: 976 - Move TODO regeneration out of the state mutex critical section (or extend the window)
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T00:00:00Z
- **Completed**: 2026-07-29T02:45:00Z
- **Effort**: ~3 hours
- **Dependencies**: Task 965
- **Artifacts**: plans/01_mutex-regen-outside-lock.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`state-write.sh --regen-todo` used to run `generate-todo.sh` inside the `specs/.scope-lock`
critical section, holding the mutex for a measured ~6.9s against the live 101-task state.json --
longer than the 5000ms waiter acquire budget and more than half the 10s staleness reclaim window.
All five plan phases landed: the mutex is now released immediately after the atomic `mv` and
before regeneration runs (Phase 1), the staleness window was additionally widened as
defense-in-depth (Phase 2), a new regression suite proves both properties and adversarially fails
against the pre-fix code (Phase 3), `generate-todo.sh` was rewritten to a single full-file jq
pass with pure-bash formatting (Phase 4), and a full verification sweep was run with one
documented, policy-driven exclusion around the live redeploy step (Phase 5).

## What Changed

- `agent-system/extensions/core/scripts/state-write.sh` -- moved `release_mutex` to run
  immediately after the atomic `mv`/`STAGE_FILE=""` reset and before the `--regen-todo` block
  (Phase 1); added `STATE_WRITE_SCOPE_STALE_SEC=30` passed as the `stale_sec` argument to
  `task-lock.sh scope-acquire` (Phase 2); corrected the file-header usage comment for
  `--regen-todo`.
- `agent-system/extensions/core/scripts/generate-todo.sh` -- rewrote `generate_todo()` and
  `generate_task_entry()` to use a single full-file jq pass (`sort_by(-.project_number)`, all 10
  fields per task joined by the ASCII Unit Separator and base64-encoded once per row) instead of
  ~8-12 jq spawns per task; pure-bash formatting (`mapfile -d`, `_strip_trailing_nl` nameref
  helper) with zero jq spawns and one `base64 -d` spawn per task in the per-task loop.
- `agent-system/extensions/core/scripts/test-state-write-regen-timing.sh` -- new isolated-temp-root
  regression suite (3 cases: mutex released before regeneration begins, two concurrent
  `--regen-todo` status flips both succeed with no lost update, guest mode still serializes
  regeneration without releasing an outer holder's mutex). Adversarially confirmed to FAIL against
  a scratch pre-fix copy of `state-write.sh`.

## Decisions

- Phase 2 (staleness widening) was NOT skipped despite being marked optional in the plan -- it is
  cheap, strictly additive margin, and was implemented.
- The plan's literal "NDJSON with base64-encoded fields" (one `@base64` per field) was tried first
  and abandoned once measurement showed it merely traded ~8-12 jq spawns/task for ~8 base64
  spawns/task (wall time barely moved). The final design base64-encodes the WHOLE row once per
  task, cutting decode to exactly one subprocess spawn per task.
- Row/field splitting uses `mapfile -d $'\x1f'` (ASCII Unit Separator as record delimiter), not
  `IFS=... read`, after discovering two real bash pitfalls during implementation (see Plan
  Deviations).

## Plan Deviations

- **Task 4.3** (field-encoding scheme) altered: per-field `@base64` encoding was replaced with
  whole-row `@base64` encoding after measurement showed the per-field approach did not remove the
  subprocess-spawn cost it was meant to remove. See the plan's Phase 4 "Deviation" note for the
  full technical account, including two bash correctness pitfalls discovered and fixed along the
  way (tab/whitespace-class IFS collapsing an empty field; plain `read`'s line-oriented truncation
  of multi-line fields).
- **Task 5.1** (redeploy via `deploy-headless.sh`) skipped: `context/patterns/regeneration-is-manual-only.md`'s
  `## Automated Exception` subsection restricts automated invocation of `deploy-headless.sh` to
  exactly one sanctioned call site (`skill-orchestrate`'s Stage MT-3 step 7), which this
  general-implementation-agent `/implement` dispatch is not. `state-write.sh`/`generate-todo.sh`
  are also not on `orchestrator-critical-paths.json`'s critical-path list, so even that sanctioned
  checkpoint would not have fired for this task's own changes. See Phase 5's full Reasoned
  Exclusions record in the plan for the complete accounting, including an incidental hand-copy of
  `generate-todo.sh` into the deployed tree made during Phase 4 debugging, discovered and reverted
  within this same phase.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-state-write-concurrency.sh` 4/4 pass after every phase; new
  `test-state-write-regen-timing.sh` 3/3 pass, and adversarially confirmed to FAIL (case 1) against
  a scratch pre-fix copy of `state-write.sh`
- Files verified: Yes (`bash -n` clean on all three modified/created scripts)
- Measured mutex hold for a `--regen-todo` status flip: **77ms** (>10x margin under the 1s bar),
  measured via mutex-directory-lifetime polling against an isolated-root copy of the real
  state.json during a real `--regen-todo` call
- `generate-todo.sh --dry-run` output: byte-identical (empty diff) to the pre-rewrite golden
  baseline, verified in both `--dry-run` and real atomic-write mode, and independently
  re-confirmed from a fully isolated throwaway root
- `generate-todo.sh` wall time: paired, interleaved before/after measurement under identical
  concurrent system load (3 rounds each) -- pre-rewrite averaged ~9.6s total, post-rewrite
  averaged ~4.1s total (~2.3x reduction); subtracting the out-of-`file_scope`
  `generate-task-order.sh` component (~2.3-3.0s) from each, the in-scope per-task loop dropped
  from ~7.1s to ~1.6s (~4.4x reduction). jq spawn count reduced from ~8-12/task to exactly 2 for
  the whole run.
- No task-number citations introduced in any modified/created script (verified via
  `grep -inE "task [0-9]|tasks [0-9]"`)

## Impacts

- Removes the spurious-ABORT failure mode in parallel multi-task dispatch caused by
  `--regen-todo`'s mutex hold exceeding `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` (5000ms) and risking
  reclaim from a live holder within `SCOPE_MUTEX_STALE_SEC` (10s, now additionally widened to 30s
  for `state-write.sh` specifically).
- `generate-todo.sh` is also substantially faster standalone (any caller benefits, not only
  `state-write.sh --regen-todo`).
- The deployed `.claude/scripts/` tree remains stale for `state-write.sh`, `generate-todo.sh`, and
  `test-state-write-regen-timing.sh` until a human runs the interactive `<leader>al` "Load Core" /
  "Sync all" sync, or the sanctioned automated checkpoint fires for a future change that DOES touch
  a declared critical path. This is a real, live consequence for tasks 975, 977, 978, 979
  (blocked on this task) -- they should not assume the LIVE deployed scripts reflect this fix until
  a redeploy actually runs.

## Follow-ups

- Redeploy `.claude/scripts/` (interactive `<leader>al` "Load Core"/"Sync all", human-invoked) to
  actually put this fix into effect for live dispatches; source-store edits alone do not deploy
  themselves.
- Open question, not acted on: should `scripts/state-write.sh` and `scripts/generate-todo.sh` be
  added to `orchestrator-critical-paths.json`'s `critical_paths` list? Both are orchestrator-wide
  concurrency/rendering machinery of the kind that list exists to protect, yet neither is
  currently on it. Left for separate consideration; out of this task's declared `file_scope`.
- Optional, not pursued: eliminating `generate-task-order.sh`'s own ~2.3-3.0s cost (out of this
  task's `file_scope` per the plan's Scope Notes) remains the dominant residual cost in
  `generate-todo.sh`'s total wall time.

## References

- `specs/976_fix_state_mutex_todo_regen_timing/plans/01_mutex-regen-outside-lock.md`
- `specs/976_fix_state_mutex_todo_regen_timing/reports/01_mutex-timing-defect.md`
- `specs/976_fix_state_mutex_todo_regen_timing/progress/phase-{1,2,3,4,5}-progress.json`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
