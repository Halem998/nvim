# Implementation Plan: Task Order Pruning

**Task**: 274 - Add Task Order pruning for completed/abandoned tasks
**Date**: 2026-03-24
**Language**: meta
**Complexity**: simple
**Total Effort**: 30 minutes

## Plan Metadata

```json
{
  "phases": 1,
  "total_effort_hours": 0.5,
  "complexity": "simple",
  "research_integrated": true,
  "plan_version": 1,
  "reports_integrated": [
    {
      "path": "reports/01_task-order-pruning.md",
      "integrated_in_plan_version": 1,
      "integrated_date": "2026-03-24"
    }
  ]
}
```

## Phase Dependencies

No dependencies between phases (single phase).

### Phase 1: Add Section 6.5 to review.md [COMPLETED]

**Goal**: Insert pruning logic between Section 6 (Update Registries) and Section 7 (Git Commit).

**Steps**:
1. Read `.claude/commands/review.md` to identify insertion point
2. Use Edit tool to insert Section 6.5 with subsections:
   - 6.5.1: Identify tasks to prune (cross-reference state.json)
   - 6.5.2: Remove pruned tasks from categories (with renumbering)
   - 6.5.3: Update dependency chains (reconnect neighbors)
   - 6.5.4: Update inline dependency references
   - 6.5.5: Update timestamp with pruning changelog
   - 6.5.6: Write updated Task Order to TODO.md
3. Update Section 7 (Git Commit) to include TODO.md from Task Order changes
4. Verify file structure is consistent

**Verification**:
- Section numbering is consistent (6 -> 6.5 -> 7 -> 8)
- All subsections follow the instructional pseudocode style
- Git commit section captures TODO.md changes from pruning
