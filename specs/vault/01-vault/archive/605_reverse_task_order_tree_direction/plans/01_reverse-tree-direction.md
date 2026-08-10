# Implementation Plan: Reverse Task Order Tree Direction

- **Task**: 605 - Reverse Task Order tree to show dependents below prerequisites
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/605_reverse_task_order_tree_direction/reports/01_reverse-tree-direction.md
- **Artifacts**: plans/01_reverse-tree-direction.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Reverse the DFS direction in `generate-task-order.sh` so that prerequisite tasks (wave-1, no active deps) appear as roots and dependent tasks are indented children. This requires building a `task_successors` map by inverting `task_deps`, changing two DFS iteration functions to use successors instead of deps, updating two label strings in the script, and updating the `task-order-format.md` documentation to reflect the new semantics.

### Research Integration

The research report identified all required code changes with exact line numbers, confirmed that root selection logic and `update-task-status.sh` need no changes, and provided a concrete mock of the desired output for verification. The `compute_waves()` function already builds a local successors map internally, validating the inversion approach.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is an internal agent-system UX improvement to the task ordering display.

## Goals & Non-Goals

**Goals**:
- Depth-0 tasks in the tree are those with no active prerequisites (wave-1 / unblocked)
- Indented children are tasks that depend on their parent (successors)
- Users can work on unindented tasks first; completed tasks promote their children
- Documentation reflects the new tree semantics

**Non-Goals**:
- Changing wave computation logic (already correct)
- Modifying `update-task-status.sh` (regex is direction-agnostic)
- Changing the grouping-by-topic logic or topic assignment
- Altering the wave table or summary sections of Task Order output

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Diamond deps produce unexpected `(see above)` annotations | M | L | Existing `_topic_section_visited` / `_globally_visited` logic handles this identically for both directions. Research confirmed correct behavior. |
| Successor sorting differs from current dep sorting | L | L | Apply same `sort -n` to successors array as currently applied to deps. |
| Extension core copy drift after sync | L | L | Replace entire file content with updated primary copy. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Script Changes [COMPLETED]

**Goal**: Modify `generate-task-order.sh` to build a successors map, change DFS iteration to use successors, and update label strings.

**Tasks**:
- [x] Add `declare -A task_successors` global declaration near existing `declare -A task_deps` (around line 118) *(completed)*
- [x] Create `build_successors_map()` function that iterates `task_deps` entries and inverts the relationship: for each task's deps, add the task as a successor of each dep. Trim leading spaces from values. *(completed)*
- [x] Call `build_successors_map` after `build_graph` in the main section (after line ~780 where `build_graph` is called) *(completed)*
- [x] In `_print_topic_node()` (lines 456-467): change `local deps="${task_deps[$task_num]:-}"` to `local deps="${task_successors[$task_num]:-}"` *(completed)*
- [x] In `print_tree_node()` (lines 613-626): change `local deps="${task_deps[$task_num]:-}"` to `local deps="${task_successors[$task_num]:-}"` *(completed)*
- [x] In `generate_grouped_section()` (line 336): change label from `"indented = must complete first"` to `"indented = depends on parent"` *(deviation: altered — also updated root selection to start only from tasks with no active deps, so wave-1 tasks are properly selected as DFS entry points)*
- [x] In `generate_dependency_tree()` (line 644): change label from `"indented = must complete first"` to `"indented = depends on parent"` *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - All changes above

**Verification**:
- Script runs without errors: `bash .claude/scripts/generate-task-order.sh --update-todo`
- Wave-1 tasks appear as depth-0 roots in the tree
- Successor tasks appear indented below their prerequisites
- `(see above)` annotations appear for tasks referenced multiple times

---

### Phase 2: Documentation Updates [COMPLETED]

**Goal**: Update `task-order-format.md` to reflect the new tree direction semantics.

**Tasks**:
- [x] Update grouped section header label in format doc (line 158): `"indented = must complete first"` to `"indented = depends on parent"` *(completed)*
- [x] Update Topic Section Structure examples (lines 163-202): show root tasks as wave-1 (no deps), successors indented below *(completed)*
- [x] Update Tree Entry semantics (lines 186-202): change description to "root entries = tasks with no active deps; children = tasks that depend on parent" *(completed)*
- [x] Update Complete Example (lines 247-272): rewrite to show new direction with wave-1 roots *(completed)*
- [x] Update Parsing Patterns Summary (lines 282-293): update grouped section header regex *(completed)*
- [x] Sync extension core copy: replace `.claude/extensions/core/context/formats/task-order-format.md` content with updated primary copy *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/formats/task-order-format.md` - Primary format documentation
- `.claude/extensions/core/context/formats/task-order-format.md` - Extension core copy (sync)

**Verification**:
- Examples in documentation match actual script output format
- No references to old "must complete first" label remain in either file

---

### Phase 3: Verification [COMPLETED]

**Goal**: Run the script against the live task graph and confirm output matches expected mock from research.

**Tasks**:
- [x] Run `bash .claude/scripts/generate-task-order.sh --update-todo` against current `specs/state.json` *(completed)*
- [x] Verify the Task Order section in `specs/TODO.md` shows wave-1 tasks as roots *(completed)*
- [x] Compare output against the mock in the research report (Section 7): confirm 601 is root with 602 indented, 598 is root with 594 indented, etc. *(completed: 594 completed so absent; 598 shows 595/596/599 as children correctly)*
- [x] Verify `(see above)` annotations appear correctly for diamond-dep tasks (e.g., task 599 under both 595 and 596) *(completed: 599 shows (see above) under 595, 596, and 598)*
- [x] Run `grep -r "must complete first" .claude/` to confirm no old labels remain *(completed: only matches in spawn-agent.md prose, not task order labels)*

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- `specs/TODO.md` - Updated by script (Task Order section regenerated)

**Verification**:
- Script exits 0
- Tree direction is reversed in TODO.md output
- No "must complete first" strings remain in `.claude/`

## Testing & Validation

- [ ] `bash .claude/scripts/generate-task-order.sh --update-todo` exits 0
- [ ] Wave-1 tasks (no active deps) appear at depth 0 in grouped tree
- [ ] Successor tasks appear indented below their prerequisites
- [ ] `(see above)` annotations work correctly for multi-parent tasks
- [ ] `update-task-status.sh` Mode A regex still matches tasks at any indent level
- [ ] `grep -r "must complete first" .claude/` returns no matches
- [ ] Extension core copy matches primary `task-order-format.md`

## Artifacts & Outputs

- `specs/605_reverse_task_order_tree_direction/plans/01_reverse-tree-direction.md` (this plan)
- `specs/605_reverse_task_order_tree_direction/summaries/01_reverse-tree-direction-summary.md` (post-implementation)
- `.claude/scripts/generate-task-order.sh` (modified)
- `.claude/context/formats/task-order-format.md` (modified)
- `.claude/extensions/core/context/formats/task-order-format.md` (synced)
- `specs/TODO.md` (Task Order section regenerated)

## Rollback/Contingency

All changes are in version-controlled files. If the reversed tree produces unexpected output:
1. `git checkout -- .claude/scripts/generate-task-order.sh` to restore the script
2. `git checkout -- .claude/context/formats/task-order-format.md` to restore docs
3. Re-run `bash .claude/scripts/generate-task-order.sh --update-todo` to regenerate TODO.md
