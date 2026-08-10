# Implementation Plan: Integrate Recommended Order utility into workflow commands

- **Task**: 244 - Integrate Recommended Order utility into workflow commands
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #243 (completed)
- **Research Inputs**: [01_recommended-order-research.md](../reports/01_recommended-order-research.md)
- **Artifacts**: plans/01_workflow-integration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

This plan integrates the Recommended Order utility (`update-recommended-order.sh`) into 4 workflow components to automatically maintain the `## Recommended Order` section in TODO.md. The utility was created in task 243 and provides three functions: `add_to_recommended_order`, `remove_from_recommended_order`, and `refresh_recommended_order`. Each integration point is a small, targeted change that sources the utility script and calls the appropriate function.

### Research Integration

From the research report (task 243):
- Four integration points identified: `/task`, `skill-implementer`, `skill-spawn`, `skill-todo`
- Each integration adds 3-5 lines of bash code
- Graceful handling required when section doesn't exist (already implemented in utility)
- Documentation already added to `.claude/rules/state-management.md`

## Goals & Non-Goals

**Goals**:
- Integrate `add_to_recommended_order` call into `/task` command after task creation
- Integrate `remove_from_recommended_order` call into `skill-implementer` postflight after completion
- Integrate `refresh_recommended_order` call into `skill-spawn` postflight after spawning tasks
- Integrate `remove_from_recommended_order` call into `skill-todo` for each archived task
- Ensure graceful handling when Recommended Order section does not exist

**Non-Goals**:
- Modifying the utility script itself (completed in task 243)
- Adding new utility functions
- Changing the section format
- Making the section mandatory

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Utility script path resolution fails | Medium | Low | Use `SCRIPT_DIR` pattern for reliable path resolution |
| Section manipulation causes TODO.md corruption | High | Low | Utility already tested; uses temp files and atomic moves |
| Performance impact on task operations | Low | Low | Each call is <100ms; negligible impact |
| Failure in one integration blocks whole operation | Medium | Low | Non-blocking calls with error logging |

## Implementation Phases

### Phase 1: Integrate into /task command [COMPLETED]

**Goal**: Add call to `add_to_recommended_order` after creating a new task entry.

**Tasks**:
- [ ] Read `.claude/commands/task.md` to locate Step 7 (Update TODO.md)
- [ ] Add utility script sourcing after state.json update
- [ ] Add `add_to_recommended_order $next_num` call after TODO.md update
- [ ] Ensure call is non-blocking (log errors, don't fail command)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/commands/task.md` - Add call in Step 7 (Create Task Mode, after TODO.md update)

**Code to add** (after Step 7 Part B):
```bash
# Update Recommended Order section (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    add_to_recommended_order "$next_num" || echo "Note: Failed to update Recommended Order"
fi
```

**Verification**:
- Create a test task and verify it appears in Recommended Order section
- Verify command completes successfully even if section doesn't exist

---

### Phase 2: Integrate into skill-implementer [COMPLETED]

**Goal**: Add call to `remove_from_recommended_order` in Stage 7 postflight after task completion.

**Tasks**:
- [ ] Read `skill-implementer/SKILL.md` to locate Stage 7 (Update Task Status - Postflight)
- [ ] Add utility script sourcing
- [ ] Add `remove_from_recommended_order $task_number` call after status update to "completed"
- [ ] Ensure call only runs when status is "implemented" (successful completion)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Add call in Stage 7 (after status becomes "completed")

**Code to add** (after updating state.json to "completed"):
```bash
# Remove from Recommended Order section (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    remove_from_recommended_order "$task_number" || echo "Note: Failed to update Recommended Order"
fi
```

**Verification**:
- Complete a task and verify it is removed from Recommended Order section
- Verify postflight completes successfully even if section doesn't exist

---

### Phase 3: Integrate into skill-spawn [COMPLETED]

**Goal**: Add call to `refresh_recommended_order` in Stage 12 after creating spawned tasks.

**Tasks**:
- [ ] Read `skill-spawn/SKILL.md` to locate Stage 12 (Update TODO.md with New Task Entries)
- [ ] Add utility script sourcing
- [ ] Add `refresh_recommended_order` call after all spawned tasks are created
- [ ] Use refresh (not add) to properly recalculate topological order with new dependencies

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-spawn/SKILL.md` - Add call at end of Stage 12

**Code to add** (at end of Stage 12):
```bash
# Refresh Recommended Order section to include spawned tasks (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    refresh_recommended_order || echo "Note: Failed to refresh Recommended Order"
fi
```

**Verification**:
- Spawn tasks from a blocked task and verify Recommended Order is updated with correct dependency order
- Verify spawned tasks appear before parent task in the section

---

### Phase 4: Integrate into skill-todo [COMPLETED]

**Goal**: Add call to `remove_from_recommended_order` in Stage 10 for each archived task.

**Tasks**:
- [ ] Read `skill-todo/SKILL.md` to locate Stage 10 (ArchiveTasks)
- [ ] Add utility script sourcing
- [ ] Add `remove_from_recommended_order` call for each task being archived
- [ ] Handle both completed and abandoned tasks

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add call in Stage 10 process

**Code to add** (in Stage 10, for each archived task):
```bash
# Remove archived task from Recommended Order section (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    remove_from_recommended_order "$task_number" || echo "Note: Failed to update Recommended Order"
fi
```

**Verification**:
- Archive a completed task and verify it is removed from Recommended Order section
- Verify archival completes successfully even if task wasn't in section

---

### Phase 5: Verify all integrations [COMPLETED]

**Goal**: Test all integration points together in a realistic workflow.

**Tasks**:
- [ ] Create a new task via `/task` - verify added to Recommended Order
- [ ] Run `/spawn` on a blocked task - verify refresh updates order correctly
- [ ] Complete a task via `/implement` - verify removed from Recommended Order
- [ ] Archive tasks via `/todo` - verify removed from Recommended Order
- [ ] Test each operation when Recommended Order section doesn't exist (graceful no-op)

**Timing**: 30 minutes

**Verification**:
- All integration points work independently
- All integration points work when section is missing
- No operation fails due to Recommended Order integration
- Section maintains correct topological order through operations

## Testing & Validation

- [ ] `/task "Test description"` creates task and adds to Recommended Order
- [ ] Task creation succeeds when Recommended Order section doesn't exist
- [ ] `/implement N` removes completed task from Recommended Order
- [ ] Implementation succeeds when Recommended Order section doesn't exist
- [ ] `/spawn N` refreshes Recommended Order with correct dependency order
- [ ] Spawn succeeds when Recommended Order section doesn't exist
- [ ] `/todo` removes archived tasks from Recommended Order
- [ ] Archive succeeds when Recommended Order section doesn't exist

## Artifacts & Outputs

- plans/01_workflow-integration.md (this file)
- summaries/02_integration-summary.md (after implementation)

## Rollback/Contingency

Each integration is independent and non-blocking:
- To disable an integration, remove or comment out the utility sourcing and call
- If utility script has bugs, the commands will gracefully continue without updating the section
- No state file modifications - only TODO.md section changes
- All changes are easily reversible via git revert
