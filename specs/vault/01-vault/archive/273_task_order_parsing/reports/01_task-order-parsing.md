# Research Report: Task Order Parsing for /review Command

**Task**: 273
**Date**: 2026-03-24
**Language**: meta

## Summary

Task 272 created the Task Order format specification at `.claude/context/core/formats/task-order-format.md`. This task adds parsing of that format to the /review command so downstream tasks (274-276) can manipulate the parsed data.

## Findings

### Current review.md Structure

The /review command at `.claude/commands/review.md` has these relevant sections:
- Section 2.5: Roadmap Integration (parses ROAD_MAP.md)
- Section 2.5.2: Cross-Reference Roadmap with Project State
- Section 2.5.3: Annotate Completed Roadmap Items
- Section 3: Analyze Findings

The new Section 2.6 should be inserted between 2.5.3 and 3, following the same instructional style with pseudocode/bash snippets and JSON structure examples.

### Task Order Format Elements to Parse

From the format specification, the parser needs to handle:

1. **Section boundaries**: `## Task Order` to `## Tasks`
2. **Metadata**: Update timestamp and goal statement
3. **Categories**: Numbered subsections with optional subtitles
4. **Dependency chains**: Arrow notation in code blocks
5. **Task entries**: Both ordered (numbered) and unordered (bulleted)
6. **Inline dependencies**: Parenthetical dependency notes

### Parsing Strategy

Line-by-line parsing within the Task Order section boundaries, building a structured `task_order_state` object. The parser should:
- Use regex patterns from the format specification
- Build an adjacency list for the dependency graph
- Collect all task numbers for cross-referencing
- Handle missing Task Order section gracefully

### Integration Points

The `task_order_state` structure will be consumed by:
- Task 274: Pruning completed/abandoned tasks
- Task 275: Inserting newly created tasks
- Task 276: Interactive category placement

## Recommendations

1. Add Section 2.6 with context loading reference to `task-order-format.md`
2. Use the same instructional style as Section 2.5 (Roadmap Integration)
3. Include graceful fallback when Task Order section is absent
4. Store parsed data in `task_order_state` for downstream sections
