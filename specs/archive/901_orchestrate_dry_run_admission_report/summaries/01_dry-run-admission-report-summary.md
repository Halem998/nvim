# Implementation Summary: Task #901

**Completed**: 2026-07-25
**Duration**: single session

## Overview

Added a strictly read-only `--dry-run` flag to `/orchestrate` that prints the full admission
analysis (file_scope collisions, lock contention, unmet predecessors, wave assignment, and
handoff-triage routing) instead of dispatching. Extracted the handoff-triage rule that previously
existed as two independently-maintained descriptions (single-task Stage 4's prose and multi-task
Stage MT-4's phase-grouping table) into one executable classifier consumed by both the live
dispatch path and the new dry-run report, per Decision D1 (engine-branched: `single` vs `mt`,
matching the identical `len(task_numbers)` test `/orchestrate` STAGE 0 already uses to select an
engine).

## What Changed

- `agent-system/extensions/core/scripts/parse-command-args.sh` — added `DRY_RUN_FLAG`
  (header doc, Step 4 default + scan, Step 5 `FOCUS_PROMPT` strip, Step 6 export), following the
  `CLEAN_FLAG`/`FORCE_FLAG` convention exactly.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — new. Shared,
  read-only handoff-triage classifier taking `<engine single|mt> <task_number>...`, emitting
  NDJSON (`orchestrate-triage-v1`). Transcribes both the `mt` and `single` precedence tables,
  including the one row where they genuinely diverge (`partial` with neither continuation nor
  blockers: `mt` -> `implement`, `single` -> `exit_partial`).
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — new. Composes
  `orchestrate-batch-admit.sh` (file_scope collisions, reused unmodified), `task-lock.sh check`
  (lock contention, `check`-only), an out-of-batch predecessor scan, and
  `orchestrate-triage-classify.sh` (handoff routing) into a six-section report (Header, Checks
  run, Admitted, Excluded, Notes, Recommended split) printed unconditionally in that order.
- `agent-system/extensions/core/commands/orchestrate.md` — Options table row for `--dry-run`;
  a STAGE 0 short-circuit (before the `len(TASK_NUMBERS)` branch) that calls the report script and
  stops; an explicit prohibition block (no MULTI-TASK DISPATCH, no CHECKPOINT 1/3, no Agent/Skill
  tool, no lock acquire); an Output section line.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4 now calls
  `orchestrate-triage-classify.sh mt` ahead of the retained (byte-identical, now
  documentation-labelled) Phase grouping table, with a stated degradation fallback to the table on
  classifier failure. The single-task `State: partial` handler gained a cross-reference to
  `orchestrate-triage-classify.sh single` and a note on the intentional `mt`/`single` divergence.
- `agent-system/extensions/core/manifest.json` — registered both new scripts in
  `provides.scripts`, alphabetically ordered.
- `specs/901_orchestrate_dry_run_admission_report/fixtures/state-dry-run.json` and
  `fixtures/handoffs/{954,955,956}-handoff.json` — synthetic fixture covering every table row: a
  clean admittable pair, a cross-batch file_scope collision, an out-of-batch non-terminal
  predecessor, an in-batch predecessor, three `partial` variants (blockers-only,
  neither-blockers-nor-continuation, valid continuation), a terminal task, a blocked task, a
  researching-status task, an unknown-status task, and MAX_TASKS-trim overflow tasks.
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` (6 assertions)
  and `tests/test-dry-run-report.sh` (14 assertions) — both use the scratch-deploy-tree pattern
  from task 900's precedent (`mktemp -d`, copy scripts + `deploy-root-guard.sh`, seed
  `specs/state.json` from the fixture, `trap cleanup EXIT`); both pass 100% and leave the real
  repository `.claude/` tree and `specs/state.json` untouched.

## Decisions

- Followed the plan's Decision D1 (Option A) verbatim: the classifier takes an explicit `engine`
  argument rather than picking one winning semantics for the Stage 4/MT-4 discrepancy — the
  divergence is asserted by test (triage-classify test 3), not resolved away.
- Followed D2/D3 verbatim: two separate scripts (classifier vs. report composer), and
  `orchestrate-batch-admit.sh` was read but never modified.

## Plan Deviations

- None (implementation followed plan). One bug was found and fixed during Phase 2 testing (the
  lookup `jq` call in `orchestrate-triage-classify.sh` was initially missing `-n`, causing it to
  silently read from stdin and emit nothing) — this was a self-caught implementation defect fixed
  before Phase 2 was marked complete, not a plan deviation.

## Verification

- Build: N/A (bash/jq scripts + markdown)
- Tests: Passed — `test-triage-classify.sh` 6/6, `test-dry-run-report.sh` 14/14
- Files verified: Yes — `bash -n` clean on all three modified/new scripts; manifest entries
  present; no task-number citations introduced outside `specs/**`; `.claude/**` untouched
  (all edits targeted `agent-system/extensions/core/**` per the source-store rule)

## Notes

The new scripts become live only after the core extension is re-deployed from the source store
(`agent-system/extensions/core/**`) to `.claude/` via the normal loader path (`<leader>al` /
"Load Core"). All manual testing in this implementation used scratch deploy trees precisely so
verification did not depend on that redeploy happening first.
