# Phase 5 Results: Refactor /task with gate-in for applicable modes

**Completed**: 2026-05-22
**Task**: 597
**Phase**: 5

## Summary

Applied `command-gate-in.sh` to Expand mode and Abandon mode in `/task`, eliminating the repeated
inline jq validation blocks (task lookup + error-check + exit) in both modes. Documented why Recover
mode intentionally retains its inline archive lookup.

## Changes Made

### `.claude/commands/task.md`

**Expand mode (--expand N)**:
- Replaced 7-line inline jq lookup + error-check block with:
  ```bash
  source .claude/scripts/command-gate-in.sh "$task_number" "expand"
  ```
- gate-in exports SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
- Step 2 updated to reference DESCRIPTION exported by gate-in (no separate description extraction needed)

**Abandon mode (--abandon N)**:
- Replaced 7-line inline jq lookup + error-check block with:
  ```bash
  source .claude/scripts/command-gate-in.sh "$task_number" "abandon"
  slug="$PROJECT_NAME"
  ```
- gate-in provides terminal status guard (cannot abandon already-abandoned/completed tasks)
- Added separate minimal `task_data` read after gate-in (required for `--argjson task` in archive jq)
- Directory move uses PADDED_NUM from gate-in (removed duplicate `printf "%03d"` call)

**Recover mode (--recover N)**:
- Intentionally NOT modified
- Added HTML comment documenting why: gate-in reads active_projects only; recover mode
  looks up from `specs/archive/state.json` (completed_projects array)

**Review mode (--review N)**:
- Unchanged (plan specifies this mode is out of scope for Phase 5)

**Create, Sync modes**:
- Unchanged (no task number lookup, not applicable)

## Line Count

- Before: 710L
- After: 714L
- Delta: +4L (net increase due to added NOTE comment in Recover mode and explanatory prose)
- Target was ~665L but that estimate assumed more aggressive code removal; the archive
  jq insert in Abandon mode still requires a task_data read post-gate-in

## Deviation

**Recover mode gate-in (Task 5.3)**: Evaluated and intentionally skipped. gate-in only supports
active_projects lookup; recover mode sources from archive/state.json. Documented with NOTE
comment in the command file. This deviation was anticipated in the original plan task description.

## Verification

- `source .claude/scripts/command-gate-in.sh` appears in both Expand and Abandon mode sections
- Inline jq validation blocks (task_data check + `if [ -z "$task_data" ]` + exit) removed from modes 3 and 5
- Recover mode retains inline archive lookup with explanatory NOTE comment
- Create, Sync, and Review modes are unchanged
