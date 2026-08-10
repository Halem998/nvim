# Implementation Summary: Task #201

**Completed**: 2026-03-13
**Duration**: ~15 minutes

## Changes Made

Added header instruction blocks to three task-scoped commands to ensure consistent header display format across all workflow commands. The instruction block is placed immediately after the YAML frontmatter and instructs the command to output a plain-text header line instead of a markdown heading.

## Files Modified

- `.opencode/commands/plan.md` - Added header instruction block with "[Planning]" action verb (lines 5-11)
- `.opencode/commands/implement.md` - Added header instruction block with "[Implementing]" action verb (lines 5-11)
- `.opencode/commands/revise.md` - Added header instruction block with "[Revising]" action verb (lines 5-11)

## Header Format

Each command now produces headers in the format:
```
[Action] Task OC_N: project_name
```

Where:
- `[Planning]` for /plan command
- `[Implementing]` for /implement command
- `[Revising]` for /revise command

This matches the existing pattern established by the `/research` command.

## Verification

- All three command files verified to have header instruction at line 5
- Each file uses the correct action verb for its command
- Horizontal rule separator present after instruction block in each file
- Pattern matches the reference `/research` command format

## Notes

- The fix is additive only - no existing functionality was modified
- The header instruction uses prohibition-first language ("DO NOT start with a markdown heading") for maximum compliance
- Rollback is simple: remove lines 5-11 from each modified file
