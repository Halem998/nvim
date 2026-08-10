# Research Report: Task #352

**Task**: 352 - Update /plan command for multi-task support
**Started**: 2026-04-02T14:00:00Z
**Completed**: 2026-04-02T14:15:00Z
**Effort**: Small
**Dependencies**: 350 (multi-task operations pattern)
**Sources/Inputs**: `.claude/commands/plan.md`, `.claude/context/patterns/multi-task-operations.md`, `specs/350_multi_task_operations_pattern/reports/01_multi-task-ops.md`
**Artifacts**: specs/352_plan_multi_task_support/reports/01_plan-cmd-multi-task.md
**Standards**: report-format.md

## Executive Summary

- The current `/plan` command in `.claude/commands/plan.md` accepts a single `TASK_NUMBER` argument and follows the standard GATE IN -> PARSE FLAGS -> DELEGATE -> GATE OUT -> COMMIT checkpoint flow
- The multi-task operations pattern (task 350) defines STAGE 0 argument parsing, batch validation, parallel dispatch, batch commit, and consolidated output
- For `/plan`, the allowed "from" status is `researched` (the only valid status for planning); status validation must use this constraint
- The existing single-task flow (CHECKPOINT 1 through CHECKPOINT 3) must remain unchanged -- STAGE 0 and the multi-task dispatch branch are inserted BEFORE the existing flow
- The frontmatter `argument-hint` must change from `TASK_NUMBER` to `TASK_NUMBERS` (plural) to reflect the new syntax

## Context and Scope

This research covers the specific changes needed to `.claude/commands/plan.md` to add multi-task support following the pattern defined in `.claude/context/patterns/multi-task-operations.md`.

## Findings

### 1. Current plan.md Structure

The command file has these sections:
- **Frontmatter**: description, allowed-tools, argument-hint, model
- **Arguments**: Documents `$1` as task number
- **Options**: `--team` and `--team-size N` flags
- **Execution**: CHECKPOINT 1 (GATE IN) -> STAGE 1.5 (PARSE FLAGS) -> STAGE 2 (DELEGATE) -> CHECKPOINT 2 (GATE OUT) -> CHECKPOINT 3 (COMMIT)
- **Output**: Single-task output format
- **Error Handling**: GATE IN, DELEGATE, GATE OUT failure scenarios

### 2. Changes Required

1. **Frontmatter**: Change `argument-hint` from `TASK_NUMBER [--team [--team-size N]]` to `TASK_NUMBERS [--team [--team-size N]]`

2. **Arguments section**: Update to document multi-task syntax (ranges, comma-separated lists)

3. **New STAGE 0: PARSE TASK NUMBERS**: Insert before CHECKPOINT 1
   - Inline `parse_task_args()` pseudocode from pattern doc Section 1
   - Dispatch decision: single-task falls through, multi-task branches

4. **New multi-task dispatch section**: After STAGE 0, before existing GATE IN
   - Batch validation (check existence + status = `researched`)
   - Generate batch session ID
   - Invoke batch skill with validated task list
   - Batch commit format (from pattern doc Section 8)
   - Consolidated output format (from pattern doc Section 9)

5. **No changes to existing single-task flow**: CHECKPOINT 1 through CHECKPOINT 3 remain identical

### 3. Plan-Specific Considerations

- **Status validation**: For `/plan`, the only valid "from" status is `researched`. The pattern doc table confirms this.
- **Agent type**: The planner agent is used (routed via `skill-planner` or extension routing)
- **Action verb**: "create implementation plan" (used in batch commit format)
- **Next step suggestion**: After batch planning, the next step is `/implement {task_numbers}`
- **Output status**: `[PLANNED]` for succeeded tasks

## Decisions

1. Insert STAGE 0 immediately before CHECKPOINT 1: GATE IN in the Execution section
2. Add multi-task dispatch as a subsection within STAGE 0 (not a separate top-level section)
3. Keep the Arguments section concise -- reference the pattern doc for full parsing details
4. Use `researched` as the sole allowed status for batch validation

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accidental modification of single-task flow | Breaks existing `/plan N` usage | Use Edit tool with precise old_string targeting |
| Inconsistency with research.md changes (task 351) | User confusion | Follow pattern doc exactly for all three commands |
| Missing edge case in argument parsing | Incorrect task dispatch | Pattern doc covers edge cases; inline the pseudocode verbatim |
