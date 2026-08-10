# Implementation Plan: Fix archive-task.sh TODO.md Cleanup

- **Task**: 616 - Fix archive-task.sh TODO.md cleanup
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/616_fix_archive_task_todo_cleanup/reports/01_archive-todo-cleanup.md
- **Artifacts**: plans/01_archive-todo-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Step C block in `archive-task.sh` (lines 110-138) uses a Python regex matching `- #N:` format, which never exists in TODO.md. The actual format is `### N. Title` blocks separated by `---` horizontal rules. This plan replaces the broken Python regex with a line-by-line block removal approach anchored on `^### {N}\. `, then syncs the fix to the extension copy.

### Research Integration

Key findings from the research report:
- The broken regex (`r'^[ \t]*-[ \t]+(?:\*\*)?#' + ...`) matches a format that has never existed in TODO.md
- TODO.md task blocks start with `### {N}. {Title}` and end at the next `---` separator
- Line-by-line removal is more robust than a single regex with `re.DOTALL` for handling edge cases (last task without trailing `---`, multi-line descriptions)
- Both `.claude/scripts/archive-task.sh` and `.claude/extensions/core/scripts/archive-task.sh` are byte-identical and need the same fix

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this fix.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace the broken Python regex in Step C with working block removal logic
- Handle edge cases: last task without trailing `---`, partial number matches (e.g., task 6 vs 61)
- Keep the fix as best-effort (`|| true`) so archive continues even if TODO cleanup fails
- Sync both copies of archive-task.sh

**Non-Goals**:
- Changing the Step C error semantics (it remains non-fatal)
- Modifying dry-run behavior (dry-run already exits before Step C)
- Altering the Task Order section handling (handled separately by `generate-task-order.sh`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Partial number match (task 6 matching `### 61.`) | H | L | Anchor regex with `^### {N}\. ` (literal dot + space) |
| Last task has no trailing `---` | M | L | Line-by-line stops at next `### ` heading or EOF |
| Extension copy diverges after fix | M | L | Apply identical fix to both files; verify with diff |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Step C in archive-task.sh [COMPLETED]

**Goal**: Replace the broken Python regex block with a working line-by-line block removal that matches the actual `### N. Title` format in TODO.md.

**Tasks**:
- [x] Replace lines 113-137 in `.claude/scripts/archive-task.sh` (the comment about wrong pattern plus the entire Python heredoc) with corrected Python heredoc *(completed)*
- [x] The replacement Python code must:
  - Use `^### {task_num}\. ` as block start anchor (with `re.escape` on task_num)
  - Iterate line-by-line, setting `in_block = True` when the start line is found
  - Skip all lines while `in_block` is True
  - End the block when `line.strip() == '---'` or a new `### ` heading is encountered or EOF
  - Consume the trailing `---` separator line (do not leave it behind)
  - Write the filtered content back to the file only if changes were made
  - Print status messages matching the existing convention *(completed)*
- [x] Verify the fix preserves the `if [ -f "$TODO_FILE" ]` guard and `|| true` error semantics *(completed)*
- [x] Copy the fixed `.claude/scripts/archive-task.sh` over `.claude/extensions/core/scripts/archive-task.sh` *(completed)*
- [x] Run `diff` to confirm both copies are identical after the fix *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/archive-task.sh` - Replace Step C Python heredoc (lines 113-137)
- `.claude/extensions/core/scripts/archive-task.sh` - Sync identical fix

**Verification**:
- Both files are byte-identical after the fix (`diff` returns no output)
- The new Python heredoc uses `^### {N}\. ` anchoring
- The `|| true` and `if [ -f "$TODO_FILE" ]` guards remain intact

---

### Phase 2: Test Block Removal [COMPLETED]

**Goal**: Verify the fixed Python logic correctly removes task blocks from a TODO.md-formatted test input.

**Tasks**:
- [x] Create a test by running the Python snippet against a synthetic TODO.md string containing:
  - A target task block (e.g., `### 616. Test Task`) with metadata lines and a `---` separator
  - A preceding task block that should remain intact
  - A following task block that should remain intact *(completed)*
- [x] Verify the target block is fully removed (heading through `---`) *(completed)*
- [x] Verify surrounding blocks are untouched *(completed)*
- [x] Test edge case: target task is the last block (no trailing `---`) *(completed)*
- [x] Test edge case: partial number match (removing task 6 must not remove task 61) *(completed)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None (test only, using inline Python execution)

**Verification**:
- All test cases pass with correct output
- No surrounding content is damaged

## Testing & Validation

- [x] Run the fixed Python heredoc against a synthetic multi-block TODO.md to confirm correct block removal *(completed)*
- [x] Confirm partial number match safety (task 6 does not match `### 61.`) *(completed)*
- [x] Confirm last-task-in-file edge case (block at EOF with no trailing `---`) *(completed)*
- [x] Verify both script copies are identical via `diff` *(completed)*
- [x] Verify the `|| true` error semantics are preserved (script does not abort on Python failure) *(completed)*

## Artifacts & Outputs

- `.claude/scripts/archive-task.sh` - Fixed Step C block
- `.claude/extensions/core/scripts/archive-task.sh` - Synced copy
- `specs/616_fix_archive_task_todo_cleanup/plans/01_archive-todo-plan.md` - This plan

## Rollback/Contingency

Both files are tracked in git. If the fix introduces regressions, revert with `git checkout HEAD -- .claude/scripts/archive-task.sh .claude/extensions/core/scripts/archive-task.sh`.
