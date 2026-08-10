# Research Report: Recommended Order Integration

**Task**: 243 - Recommended Order Integration
**Date**: 2026-03-19
**Focus**: Analyze workflow commands to identify modifications needed for Recommended Order section maintenance

## Summary

The user wants to add a "## Recommended Order" section to TODO.md that is automatically maintained when tasks are created, completed, or spawned. This requires modifying 4 workflow commands and their associated skills to update this section during their postflight operations.

## Section Format Analysis

From ProofChecker's TODO.md, the Recommended Order section uses:

```markdown
## Recommended Order

1. **995** -> plan + implement (unblocks 988, 989, 997)
2. **996** -> soundness wiring (independent, bounded)
3. **988** -> dense completeness (after 995)
```

Key elements:
- Numbered list (1., 2., 3., ...)
- Bold task number (`**995**`)
- Arrow separator (`->`)
- Action note (plan + implement, independent, small, etc.)
- Parenthetical dependencies/notes (unblocks X, Y; after X)

## Commands/Skills to Modify

### 1. /task Command (task.md)

**Current Behavior**: Creates task entry in TODO.md and state.json, then commits.

**Required Changes**:
- **Add to Recommended Order**: When task has dependencies, insert into Recommended Order section
- **Position Logic**:
  - If task depends on other tasks -> insert after those dependencies in the list
  - If task has no dependencies -> append to end of list (or user-specified position)
  - If task is blocked -> skip adding to Recommended Order until unblocked

**Integration Point**: Step 7 (Update TODO.md) - add logic to also update Recommended Order section

**Complexity**: Medium - needs dependency analysis to determine position

### 2. /implement Command (implement.md) via skill-implementer

**Current Behavior**: Executes plan, updates status to COMPLETED, creates summary.

**Required Changes**:
- **Remove from Recommended Order**: When task completes, remove its entry from the section
- **Reorder dependents**: Tasks that were "after {N}" may now be unblocked - could optionally move them up

**Integration Point**: CHECKPOINT 2 GATE OUT, Step 4 (after completion_summary) or skill-implementer Stage 7

**Complexity**: Low - simple removal operation

### 3. /spawn Command (spawn.md) via skill-spawn

**Current Behavior**: Creates new tasks to unblock parent, establishes dependencies.

**Required Changes**:
- **Insert spawned tasks before parent**: Spawned tasks must complete before parent
- **Update parent position**: Parent task's entry should note "depends on spawned tasks"
- **Topological insertion**: Respect dependency order of spawned tasks themselves

**Integration Point**: skill-spawn Stage 12 (Update TODO.md with New Task Entries)

**Complexity**: Medium - needs to integrate with existing topological sort

### 4. /todo Command (todo.md) via skill-todo

**Current Behavior**: Archives completed/abandoned tasks, updates CHANGE_LOG.

**Required Changes**:
- **Cleanup**: Remove archived tasks from Recommended Order section
- **Defensive cleanup**: Any completed/abandoned task in Recommended Order should be removed

**Integration Point**: Stage 10 (ArchiveTasks) - add Recommended Order cleanup step

**Complexity**: Low - simple removal operation

## State Schema Changes

### Option A: No Schema Change (Recommended)

The Recommended Order section is derived from existing state.json fields:
- `dependencies` array already exists
- `status` field already exists
- Position in section can be computed from dependency graph

**Algorithm**:
```
1. Build dependency graph from active_projects[].dependencies
2. Topologically sort tasks
3. Generate Recommended Order from sorted list, filtering to non-completed
4. Include action hints based on status (not_started -> "research", researched -> "plan", planned -> "implement")
```

### Option B: Add explicit_order field

Add optional `recommended_order_position` field to state.json entries for manual override.

**Not recommended** - adds complexity and can desync from actual dependencies.

## Implementation Approach

### Centralized Helper Function

Create a shared utility function in `.claude/lib/` or `.claude/scripts/`:

```bash
# update-recommended-order.sh
# Usage: update-recommended-order.sh add|remove|refresh TASK_NUM [POSITION]

function add_to_recommended_order() {
  local task_num=$1
  local position=$2  # optional, defaults to dependency-based position
  # ...
}

function remove_from_recommended_order() {
  local task_num=$1
  # ...
}

function refresh_recommended_order() {
  # Regenerate entire section from state.json dependency graph
  # ...
}
```

### Per-Command Integration

1. **task.md**: Call `add_to_recommended_order` after creating task
2. **skill-implementer**: Call `remove_from_recommended_order` after completion
3. **skill-spawn**: Call `refresh_recommended_order` after creating spawned tasks (simplest approach)
4. **skill-todo**: Call `remove_from_recommended_order` for each archived task

## Recommended Minimal Task Set

Given the Task Minimization Principle, I recommend **2 tasks**:

### Task 1: Create Recommended Order Helper Utility

Create the centralized utility script with functions:
- `add_to_recommended_order TASK_NUM`
- `remove_from_recommended_order TASK_NUM`
- `refresh_recommended_order` (regenerate from dependency graph)
- Document the section format and integration points

Effort: 2-3 hours

### Task 2: Integrate Utility into Workflow Commands

Modify 4 files to call the utility:
1. `/task` command - call add after task creation
2. `skill-implementer` - call remove after completion
3. `skill-spawn` - call refresh after spawning
4. `skill-todo` - call remove for each archived task

Effort: 3-4 hours

**Total: 5-7 hours, 2 tasks**

## Alternative: Single Task Approach

All changes could be done in a single task since:
- The utility and integrations are tightly coupled
- Testing requires all pieces together
- Changes are small per file (~10-20 lines each)

However, the 2-task approach provides:
- Clear separation of concerns
- Testable intermediate state (utility can be tested standalone)
- Easier review and rollback

## Dependencies

- Task 1 is foundational (no dependencies)
- Task 2 depends on Task 1

## Files to Modify

| File | Task | Changes |
|------|------|---------|
| `.claude/scripts/update-recommended-order.sh` | 1 | New file - utility functions |
| `.claude/commands/task.md` | 2 | Add call to add function |
| `.claude/skills/skill-implementer/SKILL.md` | 2 | Add call to remove function |
| `.claude/skills/skill-spawn/SKILL.md` | 2 | Add call to refresh function |
| `.claude/skills/skill-todo/SKILL.md` | 2 | Add call to remove function |
| `.claude/rules/state-management.md` | 2 | Document Recommended Order format |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Format drift | Medium | Document format in state-management.md, use single utility |
| Circular dependencies | Low | Leverage existing dependency validation in /spawn |
| Performance on large lists | Low | Recommended Order is typically <20 items |

## Recommendations

1. **Create utility first** - enables standalone testing
2. **Use refresh pattern for /spawn** - simplest, avoids complex insertion logic
3. **Document format in rules** - ensures consistency across commands
4. **Keep section optional** - commands should not fail if section missing

## Next Steps

1. Create task 243 for utility script
2. Create task 244 for command integrations (depends on 243)
3. Run `/plan 243` to generate implementation plan
