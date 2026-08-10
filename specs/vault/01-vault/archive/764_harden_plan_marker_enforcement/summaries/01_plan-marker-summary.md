# Implementation Summary: Task #764

**Completed**: 2026-06-23
**Duration**: ~1 hour

## Overview

Hardened plan marker enforcement in the general implementation agent system by replacing soft
behavioral instructions with a computationally enforced contract. The root cause of stale markers
was that Stage 4A/4D used direct Edit tool calls with no verification, and no post-implementation
checkpoint confirmed all phases were marked [COMPLETED]. This task adds mandatory Stage 5a
(Verify and Repair Plan Markers), routes 4A/4D through `update-phase-status.sh`, extends
`validate-artifact.sh` with a `--verify-completion` flag, and documents `plan_markers_verified`
in the orchestrator handoff schema.

## What Changed

- `.claude/agents/general-implementation-agent.md` — Replaced Stage 4A/4D Edit tool instructions with `update-phase-status.sh` bash calls (with Edit fallback); inserted Stage 5a (mandatory marker verification and repair between Stage 5 and Stage 6); added HARD CONTRACT block to Critical Requirements
- `.claude/agents/general-implementation-hard-agent.md` — Synced Stage 4A/4D to use `update-phase-status.sh`; added Stage 5a with single-phase dispatch caveat; updated single-phase stop text to route through Stage 5a
- `.claude/scripts/validate-artifact.sh` — Added `--verify-completion` flag; added plan-specific completion checking block (counts stale headings, lists stale lines for diagnosis, checks top-level Status field); updated usage comment
- `.claude/docs/architecture/handoff-schema.md` — Added `plan_markers_verified` boolean field to JSON schema, Field Definitions, and Successful Implementation example; added orchestrator warning behavior documentation

## Decisions

- **Fallback retained**: Stage 4A/4D still include an Edit tool fallback in case `update-phase-status.sh` is unavailable; the script is preferred but the Edit path ensures robustness
- **PARTIAL stages treated as stale**: The `--verify-completion` flag treats `[PARTIAL]` and `[BLOCKED]` headings as errors (not just `[NOT STARTED]` and `[IN PROGRESS]`), because those statuses indicate incomplete implementation
- **Stage 5a does not block Stage 6**: If repair fails after the repair loop, Stage 5a logs a diagnostic error and continues to Stage 6 rather than blocking the agent. The orchestrator's `plan_markers_verified` field signals the anomaly.
- **Hard-mode single-phase caveat**: In single-phase dispatch mode (`phase_number` set), Stage 5a in the hard-mode agent only verifies the assigned phase heading, not all plan phases (other phases legitimately remain non-COMPLETED in per-phase orchestration)

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (meta task, no build required)
- Tests: Passed — `validate-artifact.sh --verify-completion` on task 762 plan returns [PASS]; `update-phase-status.sh` idempotent call on task 764 phase 1 returns exit 0; task 764 plan file shows all 4 phases [COMPLETED]
- Files verified: Yes

## Notes

The `update-phase-status.sh` script already existed with idempotency, error reporting, and
logging to `.claude/logs/phase-transitions.log`. The key change is that agent instructions now
route through it rather than using direct Edit calls. Extension-specific implementation agents
(neovim, nix, lean4) retain their current approach and can adopt the pattern in a future task.
