# Implementation Summary: Task #639

**Completed**: 2026-06-08
**Duration**: ~20 minutes

## Overview

Replaced all 16 bash function references in `.claude/skills/skill-orchestrate/SKILL.md` that assumed `source skill-base.sh` was available. The executing agent reads SKILL.md as markdown guidance and never sources the script, so all three function calls (`skill_preflight_update`, `skill_postflight_update`, `skill_link_artifact_from_handoff`) were silently dropped. All 16 sites now use standalone bash invocations that agents can execute directly via the Bash tool.

## What Changed

- `.claude/skills/skill-orchestrate/SKILL.md` — Replaced 8 `skill_preflight_update` calls, 6 `skill_postflight_update` calls, and 2 `skill_link_artifact_from_handoff` calls with equivalent standalone bash commands

## Decisions

- Preflight replacements use `bash .claude/scripts/update-task-status.sh preflight <task> <op> <session>` (4-arg form)
- Postflight replacements use `bash .claude/scripts/update-task-status.sh postflight <task> <op> <session>` — the 5th arg (dispatch_status) is dropped because the script reads state.json to determine the correct target status
- Artifact linking was inlined as a bash block using the two-step jq pattern (Issue #1132-safe `select(.type == $atype | not)`) with a `case` statement mapping artifact types to `link-artifact-todo.sh` field arguments
- Single-task sections preserve `$task_number` and `$session_id`; multi-task sections preserve `$task_num` and `${session_id}_${task_num}`

## Plan Deviations

- None (implementation followed plan exactly)

## Verification

- `grep -c 'skill_preflight_update' SKILL.md` → 0
- `grep -c 'skill_postflight_update' SKILL.md` → 0
- `grep -c 'skill_link_artifact_from_handoff' SKILL.md` → 0
- `grep -c 'update-task-status.sh' SKILL.md` → 14
- `grep -c 'link-artifact-todo.sh' SKILL.md` → 6 (3 case branches × 2 sites)
- Code fence count: 74 (even — no unclosed blocks)
- Build: N/A
- Tests: N/A
- Files verified: Yes

## Notes

The inlined artifact linking block uses `specs/tmp/` as the jq scratch directory. This directory is created by `mkdir -p specs/tmp` before each write and is safe to leave as an empty directory. The block is identical in both the single-task (Stage 5) and multi-task (Stage MT-4) sections, with only the task variable name differing (`$task_number` vs `$task_num`).
