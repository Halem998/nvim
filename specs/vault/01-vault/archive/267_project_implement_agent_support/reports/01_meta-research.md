# Task 267: Add Project Support to founder-implement-agent

**Status**: Research Complete
**Created**: 2026-03-24
**Dependencies**: Task #263 (skill-project update), Task #266 (project plan support)

---

## Problem Statement

The founder-implement-agent currently handles 3 task types: market-sizing, competitive-analysis, and gtm-strategy. It has no support for project-timeline tasks. After tasks 262 (project-agent refactor) and 266 (project plan support) are complete, the implementer needs to handle the final phase: generating Typst timeline documents and compiling PDFs from the plan.

Currently, project-agent does all of this in a single monolithic invocation. This task moves the implementation-phase work (Typst generation, PDF compilation) into founder-implement-agent.

## Current State Analysis

### founder-implement-agent Phase Flows

The agent reads the plan and branches by report type:

| Report Type | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|-------------|---------|---------|---------|---------|---------|
| market-sizing | TAM Calculation | SAM Narrowing | SOM Projection | Report Generation | Typst + PDF |
| competitive-analysis | Landscape Mapping | Deep Dive Analysis | Differentiation Strategy | Report Generation | Typst + PDF |
| gtm-strategy | Customer Definition | Channel Strategy | Pricing & Positioning | Report Generation | Typst + PDF |
| **project-timeline** | **NOT HANDLED** | | | | |

### What project-agent Currently Does (to be moved here)

From `.claude/extensions/founder/agents/project-agent.md`, the implementation-phase work includes:

1. **Timeline Structure**: Organize WBS into chronological timeline format
2. **PERT Calculations**: Calculate expected durations using (O + 4M + P) / 6 formula
3. **Critical Path Analysis**: Identify longest path through dependency graph
4. **Resource Allocation**: Map team members to tasks, resolve conflicts
5. **Typst Generation**: Generate timeline document using `project-timeline.typ` template
6. **PDF Compilation**: Run `typst compile` to produce PDF output

### Template Reference

The Typst template at `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` (833 lines) contains:
- Gantt chart rendering functions
- PERT diagram support
- Milestone markers
- Resource allocation tables
- Critical path highlighting

## Proposed Changes

### Add project-timeline Phase Flow

```
Phase 1: Timeline Structure & WBS Generation
  - Read research report (WBS, task hierarchy)
  - Read plan (phase structure, ordering)
  - Organize into timeline format
  - Validate completeness (all tasks accounted for)

Phase 2: PERT Calculations & Critical Path
  - Calculate expected durations per task
  - Build dependency graph
  - Identify critical path
  - Calculate float/slack for non-critical tasks
  - Generate PERT summary table

Phase 3: Resource Allocation Matrix
  - Map team members to tasks from research data
  - Detect resource conflicts (over-allocation)
  - Suggest leveling adjustments
  - Generate allocation table

Phase 4: Gantt Chart & Typst Visualization
  - Generate Typst file at strategy/timelines/{project-slug}.typ
  - Use project-timeline.typ template
  - Include Gantt chart, PERT diagram, resource table
  - Include milestone markers and critical path highlighting

Phase 5: PDF Compilation & Deliverables
  - Compile Typst to PDF at founder/{project-slug}.pdf
  - Generate markdown summary at strategy/timelines/{project-slug}-report.md
  - Handle mode-specific output:
    - PLAN mode: Full timeline + Gantt
    - TRACK mode: Progress update overlay
    - REPORT mode: Status report with variance analysis
```

### Mode Handling

The project-agent currently supports PLAN/TRACK/REPORT modes. These should transfer to the implementer:

- **PLAN**: Default mode - generate full timeline from scratch
- **TRACK**: Update existing timeline with progress data (requires prior PLAN)
- **REPORT**: Generate status report comparing planned vs actual

The mode is stored in `forcing_data.mode` in state.json and should be passed through the plan to the implementer.

### Type Detection

Add to the implement agent's type detection logic:
- Keywords: `project`, `timeline`, `WBS`, `PERT`, `milestone`, `Gantt`, `deliverable`, `critical path`
- Report type identifier: `project-timeline`

### Resume Support

Must support resume from any phase (the agent already has this pattern for other types):
- Scan phase markers for first `[NOT STARTED]` or `[IN PROGRESS]` phase
- Resume from that phase
- Mark `[PARTIAL]` if interrupted

## Files Affected

- `.claude/extensions/founder/agents/founder-implement-agent.md` - add project-timeline type detection and phase flow

## Context Files Needed

The implementer will need access to:
- `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Typst template
- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - WBS, PERT, CPM methodology

These are already in index-entries.json and will be loaded by the agent via context discovery.

## Effort Estimate

2-3 hours - significant due to the complexity of the Typst generation and mode handling logic being moved from project-agent.

## Risk Assessment

- **Medium**: The Typst template is complex (833 lines). The implementer needs to correctly interface with it.
- **Low**: Phase flow pattern is well-established from the other 3 types.
- **Low**: Resume support follows existing patterns exactly.
