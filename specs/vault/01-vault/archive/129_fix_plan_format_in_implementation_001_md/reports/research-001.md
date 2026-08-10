# Research Report: Task #129

**Task**: OC_129 - fix_plan_format_in_implementation_001_md
**Date**: 2026-03-03
**Language**: meta
**Focus**: plan-format-compliance

## Summary

The plan file `specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md` deviates significantly from the standard defined in `.claude/context/core/formats/plan-format.md`. The most critical issue is the placement of status markers in a separate metadata line instead of the phase header, which breaks standard parsing tools.

## Findings

### Status Marker Placement
- **Standard**: `### Phase N: {name} [STATUS]`
- **Current**: 
  ```markdown
  ### Phase N: {name}
  
  **Status**: [STATUS]
  ```
- **Impact**: Tools expecting status in the header will fail to parse the phase status correctly.

### Field Naming Deviations
- **Goal vs Objectives**: Standard uses `**Goal:**`, current file uses `**Objectives**:`.
- **Tasks vs Steps**: Standard uses `**Tasks:**` (bullet checklist), current file uses `**Steps**:` (numbered list) and a separate `**Verification**:` section.
- **Timing vs Estimated Effort**: Standard uses `**Timing:**`, current file uses `**Estimated effort**:`.

### Structure
The current file includes sections like `**Files to modify**:` which are helpful but not strictly part of the standard skeleton. While additional information is generally acceptable, the core fields (Goal, Tasks, Timing) should be present and correctly named for consistency.

## Recommendations

1.  **Move Status to Header**: Rewrite all phase headers to include the status marker (e.g., `### Phase 1: Add Critical "DO NOT IMPLEMENT" Warning Header [COMPLETED]`).
2.  **Remove Redundant Status Line**: Delete the `**Status**: [COMPLETED]` line from each phase body.
3.  **Standardize Field Names**: 
    - Rename `**Objectives**:` to `**Goal**:`.
    - Rename `**Estimated effort**:` to `**Timing**:`.
    - Consolidate `**Steps**:` and `**Verification**:` into `**Tasks**:` or keep them if they provide better clarity for this specific task, but ensure `**Tasks**:` exists if required by tooling. Given the detailed nature of the steps, keeping them as-is might be fine for human readability, but if strict adherence is required, they should be refactored. The primary focus of this task is the **plan format** (specifically status), so fixing the status is the priority.
4.  **Preserve Content**: Ensure no content is lost during the reformatting.

## Risks & Considerations

- **Parsing Logic**: If any scripts currently parse this specific file using the non-standard format, they might break. However, since this is a fix to align with the standard, standard-compliant tools should benefit.

## Next Steps

Run `/plan OC_129` to create an implementation plan to reformat the file.
