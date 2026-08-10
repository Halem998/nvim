# Implementation Summary: Task #220

**Completed**: 2026-03-16
**Duration**: ~45 minutes

## Changes Made

Added `--fix-it` flag to the `/grant` command that scans grant project directories for embedded `FIX:`, `TODO:`, `NOTE:`, and `QUESTION:` tags in .tex, .md, and .bib files. The implementation follows the same interactive selection pattern as the `/fix-it` command, creating structured tasks with `language="grant"`.

Key features:
- Non-destructive scan operation (no status change to parent grant task)
- Interactive task type selection via AskUserQuestion
- Individual TODO/QUESTION item selection with topic grouping support
- All created tasks have `language="grant"` and `parent_task` linking
- Grant-specific file type support (.tex with % comments, .md with <!-- comments, .bib with % comments)

## Files Modified

- `.claude/extensions/present/commands/grant.md`
  - Added `--fix-it` to argument-hint
  - Added Fix-It row to Modes table
  - Added `N --fix-it` pattern to mode detection
  - Added Fix-It Scan Mode section with GATE IN/DELEGATE/GATE OUT checkpoints

- `.claude/extensions/present/skills/skill-grant/SKILL.md`
  - Added `AskUserQuestion` to allowed-tools
  - Added `fix_it_scan` to workflow_type validation
  - Added `fix_it_scan` row to Workflow Type Routing table (no status changes)
  - Added fix_it_scan cases to preflight and postflight status mappings
  - Added "Fix-It Scan Workflow (Direct Execution)" section with 13 steps (F1-F13)
  - Added Fix-It Scan error handling section

## Implementation Details

### Workflow Structure

The fix_it_scan workflow uses direct execution within skill-grant (no subagent delegation):

1. **F1-F3**: Locate grant directory, scan for tags, early exit if none
2. **F4**: Display tag summary to user
3. **F5-F9**: Interactive selection (task types, individual items, topic grouping)
4. **F10-F11**: Create tasks with language="grant" and parent_task linking
5. **F12-F13**: Git commit and return summary

### Error Handling

- Grant directory not found: Clear error message with checked paths
- No tags found: Informational message (not an error)
- Empty selection: Clean exit with message
- Git commit failure: Non-blocking (warns user)

## Verification

- Command file contains --fix-it in Modes table and argument-hint
- Mode detection handles `N --fix-it` syntax correctly
- Skill accepts fix_it_scan workflow_type
- AskUserQuestion available in skill allowed-tools
- All 13 Fix-It steps (F1-F13) present in skill
- Error handling covers all fix_it_scan scenarios

## Notes

- This implementation reuses patterns from `/fix-it` command but is grant-specific
- All created tasks use `language="grant"` (not auto-detected from file type)
- Parent grant task status is never changed by fix-it scan (non-destructive)
- Topic grouping follows same algorithm as /fix-it (shared terms, proximity, action types)
