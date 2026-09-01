# Implementation Summary: Task #133

- **Task**: 133 - Register the ambient-binding defect class and fix the /orchestrate deploy-pending annotation
- **Status**: [IN PROGRESS]
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: N/A (Phase 5 partial)
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_fix-deploy-pending-annotation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Registered a new `AMBIENT_BINDING_MISMATCH` value in the closed system-defect vocabulary (both
the recorder's validator and the discrimination doc's instance table), then fixed the defect it
names: `skill_postflight_update`'s exit-6 deploy-pending annotation block was guarded on an
ambient `TASK_DIR` environment variable that `/orchestrate`'s own postflight call sites never
set, so `deploy_pending`/`deploy_pending_reason` never landed in `.return-meta.json` under
`/orchestrate`. Phases 1-4 (registration, the new optional 6th parameter, the three call-site
updates, and a regression test) are complete and verified. Phase 5 (recording the motivating
incident to `specs/events.jsonl` as end-to-end proof) is blocked by a structural constraint
(`deploy-root-guard.sh`) that this task's own Non-Goals ("do not deploy") correctly forbid
working around; it is left `[PARTIAL]` with a documented one-command follow-up.

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
- Phase 5 closed as `[PARTIAL]`, not `[COMPLETED WITH EXCLUSIONS]`: there is concrete, nameable
  residual work (one recorder command, once deployed), which fails the exclusions marker's "no
  residual work" admission condition and instead matches `PARTIAL`'s "deferred with a tracked
  follow-up" semantics.

## Plan Deviations

- **Phase 1** verification bullet ("`--help` exits 0"): the script's pre-existing `usage()`
  function unconditionally exits 1 for both `--help` and argument errors; unrelated to this
  task's edits. Verified registration by other means instead (grep hits in both files, updated
  "fourteen" wording on an unknown-class rejection, zero remaining "thirteen" occurrences).
- **Phase 4**: `write_deploy_gate_return_meta` required an added `mkdir -p` for the fixture task
  directory not present in `build_fixture_repo` (discovered via a failing exit-3-instead-of-6
  debugging pass; see `progress/phase-4-progress.json`).
- **Phase 5** (tasks 5.2-5.4): deferred. `system-defect-record.sh` requires the DEPLOYED copy to
  satisfy `deploy-root-guard.sh`'s structural check, and the deployed copy is stale (predates
  this task's Phase 1 change). Closing this requires either deploying (prohibited by this plan's
  own Non-Goals) or hand-authoring `.claude/**` (prohibited repo-wide). See the plan's own
  "Phase 5 blocker" note and `progress/phase-5-progress.json`'s `approaches_tried` for the full
  investigation, and its `follow_up_command` field for the exact command to run once unblocked.

## Verification

- Build: N/A (bash scripts) — `bash -n` passes on all four modified shell scripts.
- Tests: A throwaway scratchpad harness sourcing the source-store `skill-base.sh` ran the full
  `test-skill-base-lifecycle.sh` suite including the three new Group 4 cases: **28 passed, 0
  failed**. The real (deploy-first) suite correctly exits 2 against the currently-stale deployed
  copy, via the new harness sanity check — this is the check working as designed, not a failure.
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

- Complete Phase 5: once a deploy has occurred (this task's own deploy-pending resolution, or a
  later cycle), run the recorder command in `progress/phase-5-progress.json`'s
  `follow_up_command` field and verify `tail -1 specs/events.jsonl | jq .` names
  `AMBIENT_BINDING_MISMATCH`.

## References

- Plan: `specs/133_fix_orchestrate_deploy_pending_annotation/plans/01_fix-deploy-pending-annotation.md`
- Research: `specs/133_fix_orchestrate_deploy_pending_annotation/reports/01_fix-deploy-pending-annotation.md`
- Progress: `specs/133_fix_orchestrate_deploy_pending_annotation/progress/phase-{1,2,3,4,5}-progress.json`
- Handoffs: `specs/133_fix_orchestrate_deploy_pending_annotation/handoffs/`
