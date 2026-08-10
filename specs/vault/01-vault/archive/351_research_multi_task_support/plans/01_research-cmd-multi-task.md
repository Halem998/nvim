# Implementation Plan: Update /research for Multi-Task Support

- **Task**: 351 - Update /research command for multi-task support
- **Status**: [COMPLETED]
- **Effort**: 30 minutes
- **Dependencies**: 350
- **Research Inputs**: specs/351_research_multi_task_support/reports/01_research-cmd-multi-task.md
- **Artifacts**: plans/01_research-cmd-multi-task.md (this file)
- **Standards**: plan-format.md
- **Type**: meta

## Overview

Update `.claude/commands/research.md` to accept multiple task numbers (e.g., `/research 7, 22-24, 59`) by adding a STAGE 0 argument parser and multi-task dispatch flow before the existing single-task checkpoint flow. Single-task usage remains unchanged.

## Goals & Non-Goals

**Goals**:
- Add STAGE 0 with `parse_task_args()` before existing GATE IN
- Add multi-task dispatch branch (batch validation, parallel agent spawning, batch commit, consolidated output)
- Update frontmatter argument-hint to show plural syntax
- Update Arguments section to document multi-task input format

**Non-Goals**:
- Modifying the existing single-task flow (CHECKPOINT 1 through CHECKPOINT 3)
- Creating the batch dispatch skill (separate task)
- Implementing /plan or /implement multi-task support (tasks 352-353)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing single-task flow | Only insert new sections; do not modify lines 32-231 |
| Ambiguous argument parsing | Use proven `parse_task_args()` from pattern doc |

## Implementation Phases

### Phase 1: Update frontmatter and Arguments section [COMPLETED]

**Files**: `.claude/commands/research.md`

**Steps**:
1. Change `argument-hint` from `TASK_NUMBER [FOCUS] [--team [--team-size N]]` to `TASK_NUMBERS [FOCUS] [--team [--team-size N]]`
2. Update Arguments section to document multi-task syntax:
   - `$1` becomes task numbers (single, comma-separated, or range)
   - Add examples table showing input formats

**Verification**: Frontmatter and Arguments section updated correctly

### Phase 2: Insert STAGE 0 and multi-task dispatch [COMPLETED]

**Files**: `.claude/commands/research.md`

**Steps**:
1. Insert STAGE 0: PARSE TASK NUMBERS section after the "## Execution" block and before "### CHECKPOINT 1: GATE IN"
2. Include `parse_task_args()` pseudocode from pattern doc Section 1
3. Add dispatch decision (single-task fallthrough vs multi-task branch)
4. Add multi-task dispatch section with:
   - Batch validation of all tasks
   - Batch session ID generation
   - Skill invocation via batch dispatch pattern
   - Batch commit format (full and partial success)
   - Consolidated output format
   - Error handling for partial success

**Verification**: New sections inserted correctly; existing CHECKPOINT 1 through end of file unchanged

## Testing & Validation

- Verify existing single-task flow sections are byte-identical before and after changes
- Verify new STAGE 0 references `parse_task_args()` with correct pseudocode
- Verify multi-task dispatch includes all required components from pattern doc

## Artifacts & Outputs

- Modified: `.claude/commands/research.md`
- Created: Research report, implementation plan, summary

## Rollback/Contingency

Git revert of the single commit restores the original research.md.
