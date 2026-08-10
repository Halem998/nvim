# Implementation Summary: Task #658

**Completed**: 2026-06-11
**Duration**: ~30 minutes

## Overview

Replaced skill-orchestrate's inline `skill_postflight_update` and `skill_link_artifacts` calls in Stage 5 (single-task) and Stage MT-4 (multi-task) with calls to the shared `orchestrator-postflight.sh` script. This fixes a bug where research and plan dispatches (which use `orchestrator_mode: false` and do not write `.orchestrator-handoff.json`) were receiving no postflight processing. Three architecture docs were also updated to document the unified postflight path.

## What Changed

- `.claude/skills/skill-orchestrate/SKILL.md` — Stage 5: Replaced `skill_postflight_update` case block and `skill_link_artifacts` block with `orchestrator-postflight.sh` calls; added `.return-meta.json` fallback for `dispatch_status` when handoff is absent; restructured handoff-absent branch to set all dispatch variables before falling through to shared postflight logic
- `.claude/skills/skill-orchestrate/SKILL.md` — Stage MT-4: Same replacement for multi-task postflight loop; added per-task variable extraction (`mt_padded`, `mt_project_name`, `mt_task_type`, `mt_session`); added `.return-meta.json` fallback that marks task as failed only if both handoff AND return-meta are absent
- `.claude/docs/architecture/orchestrate-state-machine.md` — Added "Postflight Pipeline" section before "Context Flatness Guarantee" documenting the dual-file read pattern, `.return-meta.json` fallback, and `orchestrator-postflight.sh` call pattern
- `.claude/docs/architecture/handoff-schema.md` — Added advisory note to `artifacts` field definition clarifying that the handoff artifacts are ADVISORY context for state machine dispatch; authoritative artifact data for linking comes from `.return-meta.json` via the shared postflight script
- `.claude/docs/architecture/dispatch-agent-spec.md` — Added "Postflight Integration" section documenting call sites, operation_type mapping, and no-op behavior for implement dispatches where skill-implementer already ran postflight internally

## Decisions

- Restructured Stage 5 from `if/else` (blocking error) to `if/else` with fallback: when handoff is absent, infer `dispatch_status` from `.return-meta.json` rather than treating it as an unrecoverable error. This is the correct path for research/plan dispatches.
- In MT-4, when both handoff AND return-meta are absent, the task is marked as failed in multi-state (more aggressive than Stage 5, which just sets `dispatch_status=failed` and lets postflight handle it). This is correct because MT mode needs to track per-task failure state explicitly.
- Project name extraction in MT-4 uses string prefix stripping (`${task_dir#specs/${mt_padded}_}`) rather than re-reading state.json, to avoid extra I/O in the per-task loop.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (markdown/pseudocode files only)
- Tests: N/A
- Files verified: Yes
- Zero occurrences of `skill_postflight_update` in SKILL.md: confirmed
- Zero occurrences of `skill_link_artifacts` in SKILL.md: confirmed
- `orchestrator-postflight.sh` appears 8 times in SKILL.md (4 per stage): confirmed
- `.return-meta.json` fallback exists in both Stage 5 and Stage MT-4: confirmed
- Stage 8 orchestrator metadata write path unaffected: confirmed

## Notes

The implement dispatch case uses `orchestrator-postflight.sh` even though skill-implementer may have already called it internally. This is intentional and safe: the outer call is a no-op because `.return-meta.json` was already cleaned up by the inner invocation. The script handles missing metadata gracefully by setting `status=failed` and running cleanup only.
