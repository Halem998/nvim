# Research Report: Generic/Edit Task Type Fallback for founder-plan-agent

**Task**: 334 - Add generic/edit task_type fallback to founder-plan-agent
**Date**: 2026-03-30

## Summary

The founder-plan-agent currently handles 6 task_types in Stage 4 (market, analyze, strategy, legal, project, sheet) and provides specialized phase structures in Stage 5 for 5 of them (market-sizing, competitive-analysis, gtm-strategy, contract-review, project-timeline). Cost-breakdown (sheet) is listed in Stage 4 but has no corresponding phase structure in Stage 5.

When a founder task does not match any of these types -- for example, a simple edit/maintenance task like "replace values in a document" -- the agent has no fallback and improvises a free-form plan that does not conform to plan-format.md.

## Findings

### Current Coverage Gap

**Stage 4 (Determine Report Type)**:
- Primary lookup table: market, analyze, strategy, legal, project, sheet
- Keyword fallback table: covers the same 6 types
- Default behavior: "Default to market-sizing if unclear" -- incorrect for non-analysis tasks

**Stage 5 (Generate Plan Artifact)**:
- Phase structures defined for: Market Sizing, Competitive Analysis, GTM Strategy, Contract Review, Project Timeline
- Missing: cost-breakdown phase structure (sheet type)
- Missing: generic/edit fallback phase structure

### Task Types That Need the Fallback

1. Edit/maintenance tasks (e.g., "replace all instances of X with Y in document")
2. Configuration tasks (e.g., "update settings in a config file")
3. Mixed tasks that span multiple types
4. Any task created without a founder command (task_type is null/absent)

### Design Requirements

1. Add `generic` entry to Stage 4 task_type table and keyword fallback
2. Add a "Generic/Edit" phase structure to Stage 5
3. The generic fallback should use plan-format.md structure directly
4. Phase count should be flexible (1-3 analysis phases based on task scope)
5. Phase 4 (Report/Typst) and Phase 5 (PDF) should be conditional -- only included when the task actually produces a report/document output
6. For edit/maintenance tasks, skip report generation phases entirely

### plan-format.md Requirements

The standard plan format requires:
- 7 metadata fields: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type
- 7 sections: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency
- Phase format: `### Phase N: {name} [STATUS]` with Goal, Tasks, Timing

### Integration Points

- Stage 4: Add `generic` to primary table and as the catch-all default (replacing "default to market-sizing")
- Stage 5: Add "Generic/Edit" section after Project Timeline section
- Critical requirement #6 in agent ("Always generate 5-phase structure...") needs amendment to allow variable phase counts for generic type

## Recommendations

1. Add `generic | generic | (none)` to Stage 4 task_type table
2. Change default from "market-sizing" to "generic" in keyword fallback
3. Add Generic/Edit phase structure with 1-3 task-specific phases + conditional report phases
4. Update Critical Requirement #6 to allow variable phase count for generic type
