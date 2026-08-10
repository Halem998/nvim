# Implementation Plan: Update /implement for Multi-Task Support

- **Task**: 353 - Update /implement command for multi-task support
- **Status**: [COMPLETED]
- **Effort**: 30 minutes
- **Dependencies**: 350
- **Research Inputs**: specs/353_implement_multi_task_support/reports/01_implement-cmd-multi-task.md
- **Artifacts**: plans/01_implement-cmd-multi-task.md (this file)
- **Standards**: plan-format.md
- **Type**: meta

## Overview

Apply the multi-task operations pattern from `.claude/context/patterns/multi-task-operations.md` to `.claude/commands/implement.md`. This adds STAGE 0 (argument parsing and dispatch) before the existing GATE IN checkpoint, enabling `/implement 7, 22-24` syntax while preserving backward compatibility with single-task usage.

## Goals & Non-Goals

**Goals**:
- Add multi-task argument parsing (ranges, comma-separated lists)
- Add batch validation with implement-specific status checks
- Add parallel agent dispatch via batch skill
- Add batch commit and consolidated output formats
- Update frontmatter and Arguments section for new syntax

**Non-Goals**:
- Modifying the existing single-task flow (CHECKPOINT 1-3)
- Creating the batch skill itself (separate task)
- Adding per-task flags or focus prompts

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accidentally modifying single-task flow | Regression | Use targeted Edit tool insertions only |
| Inconsistent status validation | Wrong tasks processed | Use same status list from GATE IN step 3 |

## Implementation Phases

### Phase 1: Update Frontmatter and Arguments [COMPLETED]

**Steps**:
1. Change `argument-hint` from `TASK_NUMBER [--team [--team-size N]] [--force]` to `TASK_NUMBERS [--team [--team-size N]] [--force]`
2. Update Arguments section to document multi-task syntax
3. Add note about ranges and comma-separated lists

**Verification**: Read modified lines, confirm no other changes

### Phase 2: Insert STAGE 0 and Multi-Task Dispatch [COMPLETED]

**Steps**:
1. Insert STAGE 0: PARSE TASK NUMBERS section between the Options/team-mode note and CHECKPOINT 1
2. Include `parse_task_args()` pseudocode from pattern doc Section 1
3. Include dispatch decision (single vs multi-task)
4. Insert multi-task dispatch subsections:
   - Batch validation with implement-specific allowed statuses
   - Batch session ID generation
   - Skill invocation (skill-batch-dispatch)
   - Batch commit format (full and partial success)
   - Consolidated output format
   - --force flag handling note
5. Ensure single-task fallthrough connects to existing CHECKPOINT 1

**Verification**: Read full file, confirm CHECKPOINT 1 through CHECKPOINT 3 unchanged, confirm STAGE 0 precedes GATE IN

## Testing & Validation

- Verify file is valid markdown
- Verify existing single-task sections (CHECKPOINT 1-3) are byte-identical to original
- Verify STAGE 0 appears before CHECKPOINT 1
- Verify frontmatter argument-hint is updated

## Artifacts & Outputs

| Artifact | Path |
|----------|------|
| Research report | specs/353_implement_multi_task_support/reports/01_implement-cmd-multi-task.md |
| Implementation plan | specs/353_implement_multi_task_support/plans/01_implement-cmd-multi-task.md |
| Modified command | .claude/commands/implement.md |
| Summary | specs/353_implement_multi_task_support/summaries/01_implement-cmd-multi-task-summary.md |

## Rollback/Contingency

Revert changes to implement.md via `git checkout -- .claude/commands/implement.md`. No other files are modified.
