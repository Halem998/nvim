# Implementation Summary: Task #362

**Completed**: 2026-04-03
**Duration**: ~30 minutes

## Changes Made

Created `.claude/scripts/update-task-status.sh` -- a centralized shell script that atomically updates task status across state.json, TODO.md task entries, and TODO.md Task Order section. The script replaces duplicated inline jq/sed patterns across skill-researcher, skill-planner, and skill-implementer with a single invocation point.

Key features:
- Status mapping for all 6 operation/target combinations (preflight/postflight x research/plan/implement)
- Atomic state.json updates via write-to-tmp-then-mv pattern using `specs/tmp/`
- TODO.md task entry status line updates (`- **Status**: [STATUS]`)
- TODO.md Task Order section updates (`**{N}** [STATUS]`)
- Optional plan file status via existing `update-plan-status.sh` (implement operations only)
- Idempotency: exits 0 silently if already at target status
- `--dry-run` flag for previewing changes without writing
- Structured exit codes (0=success, 1=validation, 2=state.json fail, 3=TODO.md fail)
- Cleanup trap for temporary files on error paths

## Files Modified

- `.claude/scripts/update-task-status.sh` - Created new file (333 lines, executable)

## Verification

- Build: N/A (shell script)
- Tests: Passed (validation, dry-run, idempotency, edge cases all verified)
- Files verified: Yes
- Syntax check: bash -n passes

## Notes

- The script uses `-E` (extended regex) for grep to avoid stray backslash warnings with markdown patterns
- Uses the two-step jq pattern per Issue #1132 guidance (avoids `!=` operator)
- Tasks 363-365 will refactor workflow skills to call this script instead of inline status updates
- The script does NOT handle completion_data fields (completion_summary, claudemd_suggestions, roadmap_items) -- those remain in skill-implementer per the plan's non-goals
