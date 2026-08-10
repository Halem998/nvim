# Research Report: Task Order Insertion

**Task**: 275 - Add Task Order insertion for newly created review tasks
**Date**: 2026-03-24
**Session**: sess_1774418015_604b89

## Summary

Research into how the /review command should insert newly created tasks into the Task Order section of TODO.md.

## Findings

### Integration Point

The /review command creates tasks in Section 5.6 (Task Creation from Selection). After tasks are created and state is updated, a new Section 6.6 should insert those tasks into the Task Order section.

Section 6.5 (pruning, task 274) is being implemented in parallel. Section 6.6 must be placed after 6.5 and before Section 7 (Git Commit).

### Category Mapping Strategy

New tasks from /review need to be mapped to Task Order categories:

| Source/Severity | Target Category |
|-----------------|----------------|
| Critical/High review issues | Critical Path (or first category) |
| Medium review issues | Code Cleanup |
| Low review issues | Backlog |
| Roadmap-sourced tasks | Matching roadmap category or Deferred |

### Task Entry Format

Per task-order-format.md, entries use:
- Ordered: `{N}. **{task_number}** [{STATUS}] -- {description}`
- Unordered: `- **{task_number}** [{STATUS}] -- {description}`

New tasks from review should use unordered (bullet) format since they are appended without strict ordering within categories.

### Edge Cases

1. **No Task Order section exists**: If tasks were created but no Task Order section exists, generate a new one using the generation template from task-order-format.md.
2. **Target category missing**: If the desired category doesn't exist, create it with the next available number.
3. **Dependencies**: If new tasks have dependencies from Section 5.6 that map to existing Task Order tasks, add inline dependency notes.

### Data Flow

The `task_order_state` structure (parsed in Section 2.6) provides:
- `exists` flag
- `categories` array with task lists
- `all_task_numbers` for dedup
- `dependency_graph` for chain updates

New tasks come from Section 5.6.3 state updates, which track created task numbers and their metadata.

## Recommendations

1. Use unordered (bullet) entries for all newly inserted tasks
2. Append to end of matching category's task list
3. Create missing categories with next sequential number
4. Update timestamp with count and task numbers of added tasks
5. Use Edit tool for surgical TODO.md updates
