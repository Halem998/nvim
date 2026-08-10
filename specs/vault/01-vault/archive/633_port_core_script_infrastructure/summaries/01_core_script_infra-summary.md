# Implementation Summary: Port Core Script Infrastructure

- **Task**: 633 - port_core_script_infrastructure
- **Status**: [COMPLETED]
- **Started**: 2026-06-07T19:00:00Z
- **Completed**: 2026-06-07T19:50:00Z
- **Effort**: ~50 minutes (automated implementation of 6-phase plan)
- **Dependencies**: None
- **Artifacts**:
  - `specs/633_port_core_script_infrastructure/plans/01_core_script_infra_plan.md` - 6-phase implementation plan
  - `specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md` - Research report (17 missing scripts, 5 stale scripts identified)
  - `specs/633_port_core_script_infrastructure/summaries/01_core_script_infra-summary.md` - This summary
  - `specs/633_port_core_script_infrastructure/progress/phase-{1..6}-progress.json` - Phase progress tracking

## Overview

Successfully ported 17 missing scripts from `.claude/scripts/` to `.opencode/scripts/` and updated 5 stale scripts in `.opencode/`. The work followed a dependency-driven phase ordering (stale shared-dependency scripts first, then foundational, then gateway/workflow/review/validation scripts) to ensure no porting work depended on work not yet done. All 22 ported/updated scripts pass syntax checks, the 3 foundational sourced scripts load correctly with expected function exports, and `update-recommended-order.sh` (the `.opencode/` task ordering system) is preserved untouched.

## What Changed

**17 new scripts ported to `.opencode/scripts/`:**
- `skill-base.sh` (516 lines) — Shared skill lifecycle functions
- `command-gate-in.sh` (73 lines) — Session generation, task lookup, terminal status guard
- `command-gate-out.sh` (82 lines) — Defensive status correction after skill delegation
- `command-route-skill.sh` (66 lines) — Resolve task_type to skill_name via extension manifest
- `parse-command-args.sh` (135 lines) — Superset argument parser
- `dispatch-agent.sh` (128 lines) — Dispatch function for orchestrator (uses `Task` tool references)
- `postflight-workflow.sh` (137 lines) — Unified postflight parameterized by operation type
- `generate-task-order.sh` (895 lines) — Kahn's algorithm task order generator
- `archive-task.sh` (179 lines) — Single-task archival
- `orphan-detection.sh` (142 lines) — Orphaned/misplaced task directory detection
- `memory-harvest.sh` (190 lines) — Memory candidate harvester
- `roadmap-integration.sh` (466 lines) — ROADMAP.md cross-reference and annotation
- `issue-grouping.sh` (401 lines) — Issue clusterer for `/review`
- `tier-selection.sh` (306 lines) — Tiered issue selection for `/review`
- `roadmap-sync.sh` (331 lines) — ROADMAP.md completion annotator
- `validate-context-budgets.sh` (226 lines) — Context budget validator (uses `.opencode/context/index.json`)
- `vault-operation.sh` (247 lines) — Vault archival when task numbering exceeds 1000

**5 stale scripts updated in `.opencode/scripts/`:**
- `update-task-status.sh` — Added `revise` operation support, full tree regeneration via `generate-task-order.sh` for terminal statuses (COMPLETED, ABANDONED, EXPANDED), plan-status update for `plan` operations
- `update-plan-status.sh` — Added `PLANNED` status normalization, improved error messages
- `postflight-research.sh` — Replaced 69-line standalone implementation with thin wrapper (calls `postflight-workflow.sh research`)
- `postflight-plan.sh` — Replaced with thin wrapper (calls `postflight-workflow.sh plan`)
- `postflight-implement.sh` — Replaced with thin wrapper (calls `postflight-workflow.sh implement`)

**3 backup files created:** `postflight-research.sh.bak`, `postflight-plan.sh.bak`, `postflight-implement.sh.bak` — preserve original standalone implementations.

## Decisions

1. **Dependency-driven porting order**: Ported `update-task-status.sh` first because it is called by `skill-base.sh` and other workflow scripts. Ported foundational scripts (skill-base.sh, gate scripts) before dependent gateway/workflow scripts. This avoided cascading breakage.

2. **Path substitution strategy**: Applied targeted `sed` substitutions to scripts that referenced `.claude/`, `.claude/context/`, `.claude/extensions/`, `.claude/docs/`, etc. Some scripts (archive-task.sh, orphan-detection.sh, memory-harvest.sh, issue-grouping.sh, etc.) are mostly path-independent and could be copied as-is.

3. **System-specific adaptations**:
   - `dispatch-agent.sh`: Changed `Agent tool` references to `Task tool` (OpenCode uses `Task` tool).
   - `postflight-workflow.sh`: Already used `specs/tmp/` convention (matching `.opencode/` rules).
   - `validate-context-budgets.sh`: Hardcoded `.claude/context/index.json` path changed to `.opencode/context/index.json`.
   - `parse-command-args.sh`: Comment updated to reference `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` env var (no code change needed).
   - `vault-operation.sh`: References `generate-task-order.sh` via `$SCRIPT_DIR/generate-task-order.sh` — works correctly since both scripts are now in `.opencode/scripts/`.

4. **Thin-wrapper pattern for postflight**: Replaced the 3 stale standalone postflight scripts with 12-line thin wrappers that exec `postflight-workflow.sh` with the operation type. This matches the architectural pattern in `.claude/` and consolidates postflight logic in one place.

5. **Preserved `update-recommended-order.sh`**: The `.opencode/` system uses a different task ordering approach (topological sort with action hints) than `.claude/`'s `generate-task-order.sh` (Kahn's algorithm with dependency waves). Both are now available; `update-recommended-order.sh` remains the active `.opencode/` system. `generate-task-order.sh` was ported for use in `update-task-status.sh` (terminal status regeneration) and for future convergence decisions.

6. **Did not port shared scripts**: The 26 byte-identical shared scripts (check-extension-docs.sh, claude-cleanup.sh, validate-artifact.sh, etc.) require no action. The 15 `.opencode/`-unique scripts (check-command-drift.sh, validate-routing-tables.sh, update-recommended-order.sh, etc.) were preserved untouched.

## Impacts

- **`.opencode/` script foundation is now at parity with `.claude/`**: All 26 shared scripts plus the 17 ported scripts plus the 15 `.opencode/`-unique scripts are in place.
- **Skill lifecycle functions now available**: `skill-base.sh` provides `skill_validate_input`, `skill_preflight_update`, `skill_postflight_update`, `skill_link_artifacts`, `skill_write_orchestrator_handoff`, and 10+ other functions for skill authors to use.
- **`/revise` command support**: The `revise` operation in `update-task-status.sh` enables reviser-agent workflows.
- **Terminal status auto-regeneration**: Tasks transitioning to COMPLETED, ABANDONED, or EXPANDED now trigger full Task Order tree regeneration via `generate-task-order.sh`, keeping TODO.md Task Order in sync with state.
- **Postflight consolidation**: All postflight logic now lives in one script (`postflight-workflow.sh`), making future enhancements easier.
- **Future-proofing**: `dispatch-agent.sh` now uses the `Task` tool semantics that OpenCode subagents require.

## Follow-ups

- **Pre-existing validation failures** (out of scope): `validate-routing-tables.sh` reports 5 errors in the `filetypes` extension manifest (routing entries not in `provides.skills`). `validate-docs.sh` reports 50 `command/` references that should be `commands/`. These pre-existed before this porting task and are unrelated to script infrastructure.
- **Future convergence decision**: Decide whether to keep both `generate-task-order.sh` and `update-recommended-order.sh`, or converge on a single approach.
- **Consider deprecating thin wrappers**: The 3 `postflight-*.sh` thin wrappers are kept for backward compatibility. Future task could remove them in favor of direct `postflight-workflow.sh` calls.
- **`.claude/scripts/postflight-workflow.sh` differs from .opencode/ port**: The `.claude/` version uses `wezterm-notify.sh` and `tts-notify.sh` lifecycle notifications (PHASE 5) which are Claude-Code-specific. The `.opencode/` port omits these since OpenCode has its own notification pipeline.

## References

- **Plan**: `specs/633_port_core_script_infrastructure/plans/01_core_script_infra_plan.md` — 6-phase dependency-driven plan
- **Research**: `specs/633_port_core_script_infrastructure/reports/01_core_script_infra_research.md` — 17 missing scripts, 5 stale scripts, 26 shared, 15 `.opencode/`-unique
- **Progress files**: `specs/633_port_core_script_infrastructure/progress/phase-{1..6}-progress.json`
- **Architectural standards**: `.claude/CLAUDE.md`, `.opencode/AGENTS.md` — System-specific conventions for path substitution, temp file conventions, tool names
