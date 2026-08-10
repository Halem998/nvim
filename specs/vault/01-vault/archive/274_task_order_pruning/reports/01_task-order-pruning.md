# Research Report: Task Order Pruning

**Task**: 274 - Add Task Order pruning for completed/abandoned tasks
**Date**: 2026-03-24
**Language**: meta

## Summary

Task Order pruning removes completed, abandoned, and expanded tasks from the Task Order section in TODO.md during /review execution. This keeps the Task Order focused on active work.

## Context

- Task 272 defined the Task Order format specification at `.claude/context/core/formats/task-order-format.md`
- Task 273 added Section 2.6 to `/review` command that parses the Task Order into `task_order_state`
- This task (274) adds Section 6.5 that prunes stale entries using the parsed state

## Insertion Point

The new section is placed between:
- Section 6 (Update Registries) - line ~828
- Section 7 (Git Commit) - line ~829

This ensures pruning happens before the git commit captures the changes.

## Design Decisions

1. **Cross-reference with state.json**: Use `status` field from state.json (completed, abandoned) rather than TODO.md status markers, since state.json is the machine-readable source of truth
2. **EXPANDED status**: Check TODO.md markers for [EXPANDED] since this status is not always in state.json
3. **Chain reconnection**: When removing a node from a dependency chain, reconnect its predecessor to its successor to preserve ordering intent
4. **Empty category removal**: Remove entire category subsection if all tasks are pruned
5. **Inline dependency cleanup**: Remove pruned task numbers from `(depends: ...)` annotations

## Scope

- Modifies: `.claude/commands/review.md`
- No new files created (beyond artifacts)
- No changes to state.json schema or task-order-format.md
