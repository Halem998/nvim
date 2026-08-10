# Research Report: Task #353

**Task**: 353 - Update /implement command for multi-task support
**Started**: 2026-04-02T14:00:00Z
**Completed**: 2026-04-02T14:15:00Z
**Effort**: Small
**Dependencies**: 350
**Sources/Inputs**: multi-task-operations.md pattern doc, task 350 research report, current implement.md
**Artifacts**: specs/353_implement_multi_task_support/reports/01_implement-cmd-multi-task.md
**Standards**: report-format.md

## Executive Summary

- The `/implement` command at `.claude/commands/implement.md` follows the standard 3-checkpoint flow (GATE IN -> DELEGATE -> GATE OUT -> COMMIT)
- Changes needed: add STAGE 0 for multi-task argument parsing before GATE IN, add multi-task dispatch branch for batch validation and parallel agent spawning
- The existing single-task flow (CHECKPOINT 1 through CHECKPOINT 3) remains entirely unchanged
- Implement-specific considerations: the `--force` flag must apply uniformly in multi-task mode, and allowed statuses for batch validation are `planned`, `implementing`, `partial`, `researched`, `not_started`
- No sibling commands (research.md, plan.md) have been updated yet, so this is the first command to receive multi-task support

## Context and Scope

Task 350 produced the multi-task operations pattern document at `.claude/context/patterns/multi-task-operations.md`. This task applies that pattern specifically to the `/implement` command. The pattern defines argument parsing (Section 1), dispatch flow (Section 4), batch validation (Section 5), parallel spawning (Section 6), batch commits (Section 8), and consolidated output (Section 9).

## Findings

### 1. Current implement.md Structure

The file has 349 lines organized as:
- **Frontmatter** (lines 1-6): description, allowed-tools, argument-hint, model
- **Arguments section** (lines 12-13): Documents `$1` as task number, `--force` option
- **Options table** (lines 15-27): `--team`, `--team-size N`, `--force` flags
- **CHECKPOINT 1: GATE IN** (lines 33-75): Session ID, task lookup, validation, plan loading, resume detection
- **STAGE 1.5: PARSE FLAGS** (lines 77-98): Extract team and force flags
- **STAGE 2: DELEGATE** (lines 100-187): Extension routing, skill selection, Skill tool invocation
- **CHECKPOINT 2: GATE OUT** (lines 189-273): Return validation, artifact verification, completion summary, plan status check
- **CHECKPOINT 3: COMMIT** (lines 275-304): Git commit for completion or partial
- **Output** (lines 306-328): Display format for completion/partial
- **Error Handling** (lines 330-349): Failure guidance

### 2. Implement-Specific Considerations

**Status validation**: The implement command allows these statuses: `planned`, `implementing`, `partial`, `researched`, `not_started`. This is broader than `/plan` (which only allows `researched`) because implement supports resume from partial states.

**--force flag**: In single-task mode, `--force` bypasses status validation (allows re-implementing completed tasks). In multi-task mode, `--force` should apply uniformly to all tasks, bypassing the status check for each.

**Resume detection**: The single-task flow detects resume points by scanning plan phase markers. In multi-task mode, each spawned agent handles its own resume detection independently -- no special handling needed at the dispatch level.

**Extension routing**: The single-task flow routes to language-specific implementation skills. In multi-task mode, the batch skill handles per-task language extraction and routing internally.

### 3. Changes Required

1. **Frontmatter**: Change `argument-hint` from `TASK_NUMBER` to `TASK_NUMBERS` (plural)
2. **STAGE 0 insertion**: New section before CHECKPOINT 1 with `parse_task_args()` pseudocode and dispatch decision
3. **Multi-task dispatch section**: Batch validation, session ID generation, skill invocation, batch commit, consolidated output
4. **Arguments section update**: Document multi-task syntax (ranges, comma-separated lists)
5. **No changes** to CHECKPOINT 1 through CHECKPOINT 3 or Error Handling

## Decisions

1. Insert STAGE 0 between the Options section and CHECKPOINT 1
2. Multi-task dispatch section goes immediately after STAGE 0 dispatch decision
3. Single-task flow starts at "Continue to CHECKPOINT 1" and is unchanged
4. Status validation for multi-task uses same allowed list as single-task GATE IN

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Breaking existing single-task flow | Single-task falls through unchanged; all existing content preserved |
| Large insertion making file unwieldy | Clear section headers and separation between multi-task and single-task flows |
