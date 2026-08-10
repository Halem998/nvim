# Implementation Plan: Update /plan for Multi-Task Support

- **Task**: 352 - Update /plan command for multi-task support
- **Status**: [COMPLETED]
- **Effort**: 30 minutes
- **Dependencies**: 350
- **Research Inputs**: specs/352_plan_multi_task_support/reports/01_plan-cmd-multi-task.md
- **Artifacts**: plans/01_plan-cmd-multi-task.md (this file)
- **Standards**: plan-format.md
- **Type**: meta

## Overview

Update `.claude/commands/plan.md` to accept multiple task numbers (e.g., `/plan 7, 22-24, 59`) by adding STAGE 0 argument parsing and a multi-task dispatch branch before the existing single-task flow. The existing CHECKPOINT 1 through CHECKPOINT 3 remain unchanged.

## Goals & Non-Goals

**Goals**:
- Add STAGE 0: PARSE TASK NUMBERS with `parse_task_args()` pseudocode
- Add multi-task dispatch branch with batch validation, parallel agent spawning, batch commit, and consolidated output
- Update frontmatter `argument-hint` to reflect plural task numbers
- Update Arguments section to document multi-task syntax

**Non-Goals**:
- Modify the existing single-task flow (CHECKPOINT 1 through CHECKPOINT 3)
- Create new skill files (batch dispatch skill is defined elsewhere)
- Modify state.json or TODO.md

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Accidental modification of single-task flow | Use precise Edit tool targeting; verify existing sections unchanged |
| Inconsistency with pattern doc | Inline pseudocode directly from pattern doc |

## Implementation Phases

### Phase 1: Update Frontmatter and Arguments [COMPLETED]

**Files**: `.claude/commands/plan.md`

**Steps**:
1. Change `argument-hint` from `TASK_NUMBER [--team [--team-size N]]` to `TASK_NUMBERS [--team [--team-size N]]`
2. Update the Arguments section to document multi-task syntax (ranges, comma-separated lists, single task fallthrough)

**Verification**: Read plan.md and confirm frontmatter and Arguments section are updated

### Phase 2: Insert STAGE 0 and Multi-Task Dispatch [COMPLETED]

**Files**: `.claude/commands/plan.md`

**Steps**:
1. Insert STAGE 0: PARSE TASK NUMBERS section before CHECKPOINT 1: GATE IN
2. Include `parse_task_args()` pseudocode from pattern doc Section 1
3. Include dispatch decision (single-task fallthrough vs multi-task)
4. Add multi-task dispatch subsection with:
   - Batch validation (status must be `researched`)
   - Generate batch session ID
   - Invoke batch skill with validated task list
   - Batch commit format
   - Consolidated output format
5. Add a note about the existing single-task flow continuing unchanged after STAGE 0

**Verification**: Read plan.md and confirm STAGE 0 is inserted before CHECKPOINT 1, and all multi-task dispatch content is present

## Testing & Validation

- Verify the existing single-task flow sections (CHECKPOINT 1 through CHECKPOINT 3) are completely unchanged
- Verify STAGE 0 appears before CHECKPOINT 1 in the file
- Verify the frontmatter argument-hint says TASK_NUMBERS
- Verify batch validation uses `researched` as the allowed status

## Artifacts & Outputs

| Artifact | Path |
|----------|------|
| Modified command | `.claude/commands/plan.md` |
| Research report | `specs/352_plan_multi_task_support/reports/01_plan-cmd-multi-task.md` |
| Implementation plan | `specs/352_plan_multi_task_support/plans/01_plan-cmd-multi-task.md` |
| Summary | `specs/352_plan_multi_task_support/summaries/01_plan-cmd-multi-task-summary.md` |

## Rollback/Contingency

If changes break the command, revert with `git checkout -- .claude/commands/plan.md`. The existing single-task flow is not modified, so rollback should only be needed for STAGE 0 issues.
