# Implementation Summary: Task #133

- **Task**: 133 - Register the ambient-binding defect class and fix the /orchestrate deploy-pending annotation
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T19:25:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fix-deploy-pending-annotation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Registered a new `AMBIENT_BINDING_MISMATCH` value in the closed system-defect vocabulary (both
the recorder's validator and the discrimination doc's instance table), then fixed the defect it
names: `skill_postflight_update`'s exit-6 deploy-pending annotation block was guarded on an
ambient `TASK_DIR` environment variable that `/orchestrate`'s own postflight call sites never
set, so `deploy_pending`/`deploy_pending_reason` never landed in `.return-meta.json` under
`/orchestrate`. All five phases are now complete and verified. Phases 1-4 (registration, the new
optional 6th parameter, the three call-site updates, and a regression test) were completed and
committed in a prior dispatch. Phase 5 (recording the motivating incident to `specs/events.jsonl`
as end-to-end proof) was initially blocked by a structural constraint (`deploy-root-guard.sh`)
that this task's own Non-Goals ("do not deploy") correctly forbade working around in that
dispatch; once a later `/orchestrate` cycle ran the sanctioned inter-cycle redeploy checkpoint
and landed Phase 1's class registration in the deployed recorder, the deferred follow-up command
was run to completion in this dispatch.

## What Changed

- `agent-system/extensions/core/scripts/system-defect-record.sh` — added `AMBIENT_BINDING_MISMATCH`
  to the closed `case` validator and the `--defect-class` usage listing; updated all "thirteen"
  occurrences to "fourteen".
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — added the new
  instance's table row and a narrating paragraph, following the doc's established voice.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_postflight_update` gained an
  optional 6th `task_dir_override` argument (`local _task_dir="${6:-${TASK_DIR:-}}"`), substituted
  into the four `${TASK_DIR:-}`/`${TASK_DIR}` references inside the exit-6 block only. Every
  existing 4-arg/5-arg call site is unchanged (default resolves identically).
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` — all three
  `skill_postflight_update` call sites (research, plan, implement branches) now pass
  `"$task_dir"` as the 6th argument. Zero literal `TASK_DIR` references remain in this file.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — added a harness
  sanity check (exits 2, naming the stale path, if the sourced `skill-base.sh` lacks the Phase 2
  change) plus two fixture helpers and three new Group 4 cases (primary: 6th arg + TASK_DIR
  unset; regression-guard: 6th arg omitted + TASK_DIR exported; non-blocking: neither set)
  exercising the real exit-6 annotation path against a genuine overlap+STALE deploy-gate refusal.

## Decisions

- Class name `AMBIENT_BINDING_MISMATCH` (mechanism-named, per the table's established convention),
  matching the plan's Decisions Recorded section.
- Fix approach: additive optional 6th parameter (option b), not `export TASK_DIR` (option a) —
  removes the ambient coupling at its root rather than satisfying it once more.
- `skill_run_extension_hook`'s own `${TASK_DIR:-}` argument left unchanged (out of this task's
  narrow scope, per CONTRACT 4).
- Phase 5 was closed as `[PARTIAL]` (not `[COMPLETED WITH EXCLUSIONS]`) in the dispatch that
  discovered the blocker, since there was concrete, nameable residual work (one recorder
  command, once deployed) at that time. In this dispatch, once the deploy occurred and the
  follow-up command was run to a verified exit 0 with a well-formed `specs/events.jsonl` record,
  Phase 5 was closed `[COMPLETED]`.

## Plan Deviations

- **Phase 1** verification bullet ("`--help` exits 0"): the script's pre-existing `usage()`
  function unconditionally exits 1 for both `--help` and argument errors; unrelated to this
  task's edits. Verified registration by other means instead (grep hits in both files, updated
  "fourteen" wording on an unknown-class rejection, zero remaining "thirteen" occurrences).
- **Phase 4**: `write_deploy_gate_return_meta` required an added `mkdir -p` for the fixture task
  directory not present in `build_fixture_repo` (discovered via a failing exit-3-instead-of-6
  debugging pass; see `progress/phase-4-progress.json`).
- **Phase 5** (tasks 5.2-5.4): initially deferred in a prior dispatch, because
  `system-defect-record.sh` requires the DEPLOYED copy to satisfy `deploy-root-guard.sh`'s
  structural check, and the deployed copy was then stale (predated this task's Phase 1 change).
  Resolved in this dispatch: the orchestrator ran the sanctioned inter-cycle redeploy checkpoint
  (`deploy-headless.sh`), the deployed copy now recognizes `AMBIENT_BINDING_MISMATCH`
  (`grep -c` returns 2), and the recorded `follow_up_command` from
  `progress/phase-5-progress.json` was run, exiting 0 and appending event_id
  `evt_1788290690039_Ld0M8J` to `specs/events.jsonl`.

## Verification

- Build: N/A (bash scripts) — `bash -n` passes on all four modified shell scripts.
- Tests: A throwaway scratchpad harness sourcing the source-store `skill-base.sh` ran the full
  `test-skill-base-lifecycle.sh` suite including the three new Group 4 cases: **28 passed, 0
  failed**. Phase 5's end-to-end recorder invocation against the now-redeployed
  `.claude/scripts/system-defect-record.sh` exited 0 and produced a well-formed
  `specs/events.jsonl` line (`tail`/`grep` + `jq .` verified: `event_type: "system_defect"`,
  `defect_class: "AMBIENT_BINDING_MISMATCH"`, `task: 133`).
- Files verified: Yes — `grep -n "AMBIENT_BINDING_MISMATCH"` hits both Phase 1 files; the
  discrimination doc's instance table has 14 data rows; `grep -rn "TASK_DIR"
  orchestrate-stage5-postflight.sh` returns zero matches; `git diff --stat` confined to the five
  files listed above (plus this task's own `specs/` artifacts) across all phases.

## Impacts

- `/orchestrate`'s postflight will now correctly surface `deploy_pending: true` and a non-null
  `deploy_pending_reason` in a task's `.return-meta.json` on a genuine exit-6 completion-deploy
  gate refusal, matching the documented "defers loudly" contract in
  `context/patterns/regeneration-is-manual-only.md`, instead of silently deferring.
  Notably, this task's own eventual postflight is expected to hit exactly that refusal (its
  `modified_files` overlap `agent-system/extensions/**`) — a live, self-referential confirmation
  of the fix once this dispatch's own outcome is reported.
- The system-defect vocabulary now has a 14th named instance for "a downstream guard keyed to an
  ambient/global shell variable that only some callers populate," available for future recordings
  of the same shape.

## Follow-ups

- None. All five phases are complete and verified.

## References

- Plan: `specs/133_fix_orchestrate_deploy_pending_annotation/plans/01_fix-deploy-pending-annotation.md`
- Research: `specs/133_fix_orchestrate_deploy_pending_annotation/reports/01_fix-deploy-pending-annotation.md`
- Progress: `specs/133_fix_orchestrate_deploy_pending_annotation/progress/phase-{1,2,3,4,5}-progress.json`
- Handoffs: `specs/133_fix_orchestrate_deploy_pending_annotation/handoffs/`
