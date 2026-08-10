# Implementation Summary: Task #629

**Completed**: 2026-06-01
**Duration**: ~30 minutes

## Overview

Added "revise" as a valid target_status across three files to bring the `/revise` command into alignment with the standard preflight/postflight lifecycle pattern used by `/research`, `/plan`, and `/implement`. Tasks now transition through `[REVISING]` when revision starts and `[REVISED]` on successful completion.

## What Changed

- `.claude/scripts/update-task-status.sh` — Added "revise" to usage string, validation whitelist, and case statement (two new entries: `preflight:revise` -> revising/REVISING, `postflight:revise` -> revised/REVISED)
- `.claude/scripts/skill-base.sh` — Added "revised" to the postflight success-status allow-list in `skill_postflight_update` (comment and case pattern)
- `.claude/skills/skill-reviser/SKILL.md` — Replaced Stage 2 "skip preflight" rationale with `skill_preflight_update "$task_number" "revise" "$session_id"` call; changed Stage 7 postflight command from `plan` to `revise`; updated Stage 11 example output from `[PLANNED]` to `[REVISED]`

## Decisions

- No changes made to `update_plan_file()` in `update-task-status.sh` -- revised plans are new artifacts, not status header updates, so no plan file status update is needed for the `revise` operation
- The `skill_preflight_update` function signature was not changed; the existing function already accepts "revise" as operation parameter now that `update-task-status.sh` accepts it

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: Dry-run preflight outputs `task 629 status 'planned' -> 'revising'`; dry-run postflight outputs `task 629 status 'planned' -> 'revised'`
- Files verified: Yes -- all three modified files confirmed via grep

## Notes

The changes are purely additive: new branches appended to existing case statements and a new pattern added to an existing allow-list. No existing `/research`, `/plan`, or `/implement` behavior is affected.
