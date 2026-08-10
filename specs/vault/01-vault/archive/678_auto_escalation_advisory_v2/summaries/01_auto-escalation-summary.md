# Implementation Summary: Task #678

**Completed**: 2026-06-12
**Duration**: ~45 minutes

## Overview

Added advisory-only churn detection to the standard orchestrator (`skill-orchestrate/SKILL.md`) across three phases. The implementation tracks three deflection signals, persists counters in the existing loop guard file, and emits a one-time human-readable warning suggesting `--hard` mode when thresholds are crossed. No existing dispatch logic was altered.

## What Changed

- `.claude/skills/skill-orchestrate/SKILL.md` — Three insertion points added (~80 lines total):
  1. Stage 2: `churn_advisory` sub-object added to fresh-start loop guard creation; five churn counter variables read from existing guard on resume
  2. Stage 5b (new section): `check_churn_advisory()` function implementing three signals (plan revision count, implement no-progress, analysis-only detection) with threshold checks and one-time advisory emission to stderr
  3. Stage 5: `check_churn_advisory` call inserted between postflight status update and artifact linking

## Decisions

- Signal 1 counts `*.md` files in `plans/` directory (avoids reading plan content, preserving context flatness)
- Signal 2 resets to 0 when `phases_delta > 0` to avoid stale stagnation signals after actual progress
- Advisory uses `>&2` (stderr) to avoid contaminating structured output used by callers
- Stage 7 selective jq merge confirmed to preserve `churn_advisory` sub-object (only updates `current_state`, `last_updated`, `cycle_count`)
- `churn_advisory_emitted` boolean persists across invocations so advisory fires exactly once per task lifecycle

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (SKILL.md is a documentation-style orchestration spec)
- Tests: N/A
- Files verified: All grep/line-count checks passed; MT sections confirmed untouched (start at line 725, changes in lines 133-574)

## Notes

The `check_churn_advisory()` function is gated so it skips research/planning dispatches (`dispatch_status == "researched"` or `"planned"`), since `phases_completed` is only meaningful for implementation dispatches. The analysis-only signal uses a grep against `dispatch_summary` with exact deflection phrases matching the research report's documented patterns.
