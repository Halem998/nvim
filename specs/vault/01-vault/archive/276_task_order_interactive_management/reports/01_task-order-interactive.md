# Research Report: Interactive Task Order Management

**Task**: 276 - Add interactive Task Order management to /review
**Date**: 2026-03-24
**Language**: meta

## Summary

This report covers the design for adding interactive AskUserQuestion prompts to the /review command's Task Order management. The new Section 6.7 will allow users to control category placement and dependency updates for tasks added or modified during review.

## Findings

### Existing AskUserQuestion Patterns

The /review command already uses AskUserQuestion in Section 5.5.6 (Interactive Group Selection) and Section 5.5.7 (Granularity Selection). These establish the pattern:

1. JSON blocks with `question`, `header`, `multiSelect`, and `options` fields
2. Options have `label` and `description` sub-fields
3. Selection handling described in prose after each JSON block
4. Multi-step flows use sequential AskUserQuestion calls

### Integration Points

- **Section 6.5** (Prune Task Order): Produces `pruned_tasks` list with count and numbers
- **Section 6.6** (Insert New Tasks): Produces `tasks_created` with category assignments
- **Section 6.7** (new): Consumes both outputs for interactive override
- **Section 7** (Git Commit): Already commits TODO.md changes; needs minor update to commit message

### Skip Conditions

Section 6.7 should be skipped when:
1. `task_order_state.exists == false` AND no tasks were created
2. Neither Section 6.5 nor 6.6 made any changes (no pruning, no insertions)

### Category System

From task-order-format.md, categories use numbered markdown headers:
- Critical Path (main dependency chain)
- Code Cleanup (refactoring and tech debt)
- Experimental (uncertain outcomes)
- Deferred (postponed)
- Backlog (unordered)

### Dependency Chain Format

Dependency chains use arrow syntax in code blocks:
```
272 -> 273 -> 274
```

New dependencies need to be appended to existing chains or create new chain entries.

## Recommendations

1. Place Section 6.7 after 6.6 and before 7 (Git Commit)
2. Use the same AskUserQuestion JSON style as Section 5.5.6
3. Include skip conditions to avoid unnecessary prompts during simple reviews
4. Support category reassignment per-task for fine-grained control
5. Support dependency selection via multiSelect on existing tasks
6. Include goal statement update for significant changes
