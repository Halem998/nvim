# Research Report: Task #266

**Task**: 266 - Add project support to founder-plan-agent
**Generated**: 2026-03-24
**Status**: Researched
**Effort**: 1-2 hours
**Dependencies**: Task #262
**Sources/Inputs**: Codebase analysis of founder-plan-agent.md, project-agent.md
**Artifacts**: specs/266_project_command_documentation/reports/01_meta-research.md

---

## Executive Summary

- founder-plan-agent currently handles three report types: market-sizing, competitive-analysis, gtm-strategy
- Task 262 will refactor project-agent to produce research reports containing WBS, PERT estimates, resource data, and dependencies
- founder-plan-agent needs a new `project-timeline` report type with keyword detection and a 5-phase plan structure
- A new planning context file may be needed to guide project-timeline plan generation
- Changes are confined to 2-3 files in the founder extension

## Context and Scope

**Goal**: After task 262 refactors project-agent to produce a research report (with WBS, PERT estimates, resource data, dependencies), the founder-plan-agent needs to create implementation plans for project timeline tasks.

**Current state**: The founder-plan-agent detects report type from research report keywords:

| Keywords | Report Type |
|----------|-------------|
| market, sizing, TAM, SAM, SOM | market-sizing |
| competitive, competitor, analysis | competitive-analysis |
| GTM, go-to-market, strategy, launch | gtm-strategy |

No project/timeline keyword detection exists. Default falls through to market-sizing.

**Target state**: Add a fourth report type `project-timeline` with its own keyword detection, phase structure, and output conventions.

## Findings

### Codebase Patterns

#### founder-plan-agent.md Structure (Current)

The agent follows a clear flow:
1. Stage 0: Initialize early metadata
2. Stage 1: Parse delegation context
3. Stage 2: Locate and read research report
4. Stage 3: Parse research report (type-specific extraction)
5. Stage 4: Determine report type (keyword matching)
6. Stage 5: Generate plan artifact (type-specific phases)
7. Stage 6: Write plan file
8. Stage 7: Write metadata file
9. Stage 8: Return brief text summary

Key design principles:
- Agent does NOT ask forcing questions (those are gathered during research)
- Plan is entirely based on the research report content
- Each report type has its own phase structure (all have 5 phases)
- Phase 5 MUST be named exactly "Typst Document Generation" for existing types

#### project-agent.md Research Report Structure (Post-Task-262)

The refactored project-agent research report will contain:
- Project scope and success criteria (from forcing questions)
- Work Breakdown Structure (hierarchical phases and tasks)
- PERT estimates per task (optimistic, most likely, pessimistic, expected)
- Resource allocation (team members, availability, assignments)
- Task dependencies (inter-phase and intra-phase)
- Risk register (identified risks and mitigations)

This data maps directly to the plan phases needed.

#### Existing Phase Structures

All three current report types follow the same pattern:
- Phases 1-3: Domain-specific analysis work
- Phase 4: Report Generation (synthesize into markdown)
- Phase 5: Typst Document Generation (compile to PDF)

### Required Changes

#### 1. Keyword Detection (Stage 4)

Add to the keyword detection table in founder-plan-agent.md:

| Keywords | Report Type | Template |
|----------|-------------|----------|
| project, timeline, WBS, PERT, milestone, Gantt, deliverable, schedule, critical path | project-timeline | project-timeline.md |

#### 2. Research Report Parsing (Stage 3)

Add a new extraction section for project-timeline reports:

```markdown
**For project-timeline reports:**
- **Project Scope**: name, completion criteria, target date
- **Stakeholders**: names, roles, approval authority
- **WBS**: hierarchical phases and tasks with deliverables
- **PERT Estimates**: per-task O/M/P values and calculated expected durations
- **Resource Data**: team members, availability percentages, task assignments
- **Dependencies**: inter-phase and intra-phase task dependencies
- **Risk Register**: identified risks, severity, mitigations
```

#### 3. Phase Structure for project-timeline

Five phases aligned with project management workflow:

- **Phase 1: Timeline Structure and WBS Validation**
  - Organize WBS from research into timeline format
  - Validate completeness (100% rule)
  - Establish phase boundaries and milestones
  - Inputs: WBS data, project scope from research
  - Outputs: Validated WBS structure, milestone list

- **Phase 2: PERT Calculations and Critical Path Analysis**
  - Calculate expected durations from three-point estimates
  - Run forward/backward pass for early/late dates
  - Identify critical path and compute float/slack
  - Inputs: PERT estimates, dependencies from research
  - Outputs: Critical path identification, schedule with float values

- **Phase 3: Resource Allocation Matrix**
  - Map team members to tasks based on research data
  - Check for overallocation conflicts
  - Validate availability against schedule
  - Inputs: Resource data, schedule from Phase 2
  - Outputs: Resource allocation matrix, overallocation warnings

- **Phase 4: Gantt Chart and Typst Visualization**
  - Generate Typst timeline document
  - Include WBS, PERT table, resource matrix, Gantt chart
  - Output at `strategy/timelines/{slug}.typ`
  - Inputs: All data from Phases 1-3
  - Outputs: `strategy/timelines/{slug}.typ`

- **Phase 5: PDF Compilation and Deliverables**
  - Compile Typst to PDF
  - Generate executive status summary if needed
  - Inputs: Typst file from Phase 4
  - Outputs: `strategy/timelines/{slug}.pdf`, optional status report

**Note on Phase 5 naming**: Unlike existing report types where Phase 5 is "Typst Document Generation", the project-timeline type names Phase 5 "PDF Compilation and Deliverables" because Typst generation happens in Phase 4 (the Gantt chart IS the primary Typst output). The plan agent instructions should clarify this distinction.

#### 4. Report Output Conventions

| Field | Value |
|-------|-------|
| Typst Location | `strategy/timelines/{project-slug}.typ` |
| PDF Location | `strategy/timelines/{project-slug}.pdf` |
| Typst Template | `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` |

These match the existing project-agent output path conventions.

#### 5. Context File (Optional)

A new context file at `.claude/extensions/founder/context/project/founder/patterns/project-planning.md` could provide:
- Project management terminology reference
- WBS validation rules (100% rule, deliverable-based decomposition)
- PERT calculation formulas
- Critical path method description
- Resource leveling guidance

This would be referenced from the "Context References" section of founder-plan-agent.md.

If created, an entry should be added to `.claude/extensions/founder/index-entries.json` for context discovery.

## Files Affected

| File | Action | Description |
|------|--------|-------------|
| `.claude/extensions/founder/agents/founder-plan-agent.md` | Modify | Add project-timeline keyword detection, parsing, phase structure |
| `.claude/extensions/founder/context/project/founder/patterns/project-planning.md` | Create (optional) | Project planning guidance context |
| `.claude/extensions/founder/index-entries.json` | Modify (if context created) | Add index entry for new context file |

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Task 262 changes research report format | High | Coordinate parsing section with 262's output spec |
| Phase 5 naming inconsistency with other types | Low | Document the distinction clearly in the agent file |
| project-timeline keywords overlap with general usage | Low | Require multiple keyword matches or check report header |

## Decisions

- The project-timeline type uses 5 phases like all other types, maintaining consistency
- Typst generation moves to Phase 4 (not Phase 5) because the Gantt chart IS the Typst output
- Phase 5 becomes PDF compilation, which is a departure from the "Typst Document Generation" naming used by other types
- A context file is optional but recommended for implementation quality

## Implementation Notes

The implementation should:
1. Add the keyword detection row to the Stage 4 table
2. Add a "For project-timeline reports" section to Stage 3
3. Add the phase structure under "Phase Structure by Report Type"
4. Update the Context References section if a planning context file is created
5. Ensure the metadata output includes `report_type: "project-timeline"`
