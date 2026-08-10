# Research Report: Task #351

**Task**: 351 - Update /research command for multi-task support
**Started**: 2026-04-02T14:00:00Z
**Completed**: 2026-04-02T14:15:00Z
**Effort**: Small
**Dependencies**: 350 (multi-task operations pattern)
**Sources/Inputs**: `.claude/context/patterns/multi-task-operations.md`, `.claude/commands/research.md`, task 350 research report
**Artifacts**: specs/351_research_multi_task_support/reports/01_research-cmd-multi-task.md
**Standards**: report-format.md

## Executive Summary

- The `/research` command at `.claude/commands/research.md` follows a standard checkpoint flow: GATE IN -> STAGE 1.5 (parse flags) -> STAGE 2 (delegate) -> GATE OUT -> COMMIT
- The multi-task operations pattern (from task 350) defines a STAGE 0 that parses multi-task arguments and dispatches accordingly
- For `/research`, the allowed-from statuses for multi-task validation are: `not_started`, `researched` (matching existing single-task validation which also allows `planned`, `partial`, `blocked`)
- The existing single-task flow (lines 32-231) must remain completely unchanged
- Changes are additive only: new frontmatter hint, new STAGE 0 section, new multi-task dispatch section, updated Arguments documentation

## Findings

### 1. Current research.md Structure

The file has 231 lines organized as:
- **Lines 1-6**: YAML frontmatter (description, allowed-tools, argument-hint, model)
- **Lines 8-9**: Title and description
- **Lines 11-27**: Arguments and Options sections
- **Lines 29-31**: Execution header and note
- **Lines 32-62**: CHECKPOINT 1: GATE IN (session ID, task lookup, validation)
- **Lines 64-90**: STAGE 1.5: PARSE FLAGS (team mode, team size, focus prompt)
- **Lines 92-173**: STAGE 2: DELEGATE (team routing, extension routing, skill invocation)
- **Lines 175-189**: CHECKPOINT 2: GATE OUT (validate return, verify artifacts)
- **Lines 191-204**: CHECKPOINT 3: COMMIT (git add/commit)
- **Lines 206-231**: Output and Error Handling sections

### 2. Changes Required

Per the multi-task operations pattern document (sections 1, 4-6, 8-9):

1. **Frontmatter**: Change `argument-hint` from `TASK_NUMBER` to `TASK_NUMBERS` (plural)
2. **STAGE 0**: Insert before CHECKPOINT 1 with `parse_task_args()` pseudocode and dispatch decision
3. **Multi-task dispatch**: Batch validation, batch session ID, skill invocation via batch dispatch, batch commit format, consolidated output
4. **Arguments section**: Update to document multi-task syntax (ranges, comma-separated lists)

### 3. Research-Specific Considerations

- **Status validation for /research**: The pattern doc (Section 5) lists `not_started, researched` as allowed statuses. However, the current single-task flow (line 57) also allows `planned`, `partial`, `blocked`. The multi-task validation should match the broader set to maintain consistency.
- **Skill routing**: In multi-task mode, each task may have a different language, requiring per-task skill routing. The batch skill handles this internally (pattern doc Section 6).
- **Team mode interaction**: `/research 7, 22-24 --team` would apply team mode to ALL tasks. Cost warning should be included per pattern doc Section 7.

## Decisions

1. Use the same status validation set as single-task flow for consistency
2. STAGE 0 goes between "## Execution" header and "### CHECKPOINT 1: GATE IN"
3. Multi-task dispatch section goes after STAGE 0, before CHECKPOINT 1
4. Arguments section updated to show multi-task syntax with examples
