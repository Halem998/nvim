# Implementation Summary: Task #243

**Completed**: 2026-03-19
**Duration**: ~45 minutes

## Changes Made

Created the Recommended Order utility script that provides three functions for maintaining the "## Recommended Order" section in TODO.md. The script uses topological sorting (Kahn's algorithm) to order tasks based on their dependencies, with action hints derived from task status.

## Files Modified

- `.claude/scripts/update-recommended-order.sh` - Created new utility script (~550 lines)
  - `add_to_recommended_order TASK_NUM` - Insert task based on dependency position
  - `remove_from_recommended_order TASK_NUM` - Remove task entry and renumber
  - `refresh_recommended_order` - Regenerate entire section from state.json

- `.claude/rules/state-management.md` - Added Recommended Order Section documentation
  - Section format specification
  - Entry components table
  - Action hint derivation rules
  - Utility script usage examples
  - Integration points for workflow commands
  - Topological sort algorithm explanation

- `specs/TODO.md` - Updated with new Recommended Order section

## Verification

- All three functions tested:
  - `add`: Inserts at correct position based on dependencies, idempotent
  - `remove`: Handles first/middle/last positions, renumbers correctly, no-op on missing
  - `refresh`: Topologically sorts all active tasks, creates section if missing
- Edge cases verified:
  - Empty section handling
  - Missing section creation
  - Non-existent task handling
  - Circular dependency detection (warning issued)
- Script exits with appropriate codes (0 for success, 1 for errors)

## Notes

The script uses Kahn's algorithm for topological sorting, which:
1. Builds a dependency graph from state.json
2. Processes tasks with no unresolved dependencies first
3. Decrements in-degree of dependent tasks as dependencies are processed
4. Detects circular dependencies (tasks remaining with non-zero in-degree)

Integration with workflow commands (task #244) will connect this utility to:
- `/task` - Call add after creating tasks
- `skill-implementer` - Call remove after task completion
- `skill-spawn` - Call refresh after spawning subtasks
- `skill-todo` - Call remove for archived tasks
