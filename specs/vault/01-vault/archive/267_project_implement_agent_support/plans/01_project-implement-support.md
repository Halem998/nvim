# Implementation Plan: Add project support to founder-implement-agent

- **Task**: 267 - Add project support to founder-implement-agent
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task #263 (skill-project research workflow), Task #266 (project plan agent support)
- **Research Inputs**: specs/267_project_implement_agent_support/reports/01_meta-research.md
- **Artifacts**: plans/01_project-implement-support.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add project-timeline type support to founder-implement-agent.md, moving Typst timeline generation responsibility from project-agent into the standard founder implementation pipeline. The agent currently handles market-sizing, competitive-analysis, and gtm-strategy; this plan adds a fourth report type with a 5-phase flow covering WBS generation, PERT/CPM calculations, resource allocation, Gantt visualization in Typst, and PDF compilation. The implementation also adds PLAN/TRACK/REPORT mode handling and follows existing resume-support patterns.

### Research Integration

Research report (01_meta-research.md) identified:
- The 5-phase flow structure (Timeline Structure, PERT, Resource Allocation, Gantt/Typst, PDF)
- Mode handling (PLAN/TRACK/REPORT) stored in `forcing_data.mode` in state.json
- Type detection keywords: project, timeline, WBS, PERT, milestone, Gantt, deliverable, critical path
- The Typst template at `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` (833 lines)
- Context files already registered in index-entries.json

## Goals & Non-Goals

**Goals**:
- Add project-timeline type detection to founder-implement-agent
- Define 5-phase implementation flow for project-timeline reports
- Support PLAN/TRACK/REPORT modes with mode-specific behavior
- Generate Typst timeline documents and compile to PDF
- Follow existing resume support patterns for phase recovery
- Reference the project-timeline.typ template and timeline-frameworks.md context

**Non-Goals**:
- Modifying the project-timeline.typ template itself
- Changing the existing 3 report type flows (market-sizing, competitive-analysis, gtm-strategy)
- Implementing the actual project-agent refactor (that is Task #262)
- Adding new context files to index-entries.json (already registered)

## Risks & Mitigations

- **Typst template complexity (Medium)**: The project-timeline.typ template is 833 lines with Gantt chart rendering, PERT diagrams, and resource tables. Mitigation: Use the self-contained typst pattern already established in the agent (inline all needed functions rather than importing).
- **Mode interaction complexity (Low-Medium)**: TRACK and REPORT modes modify behavior across multiple phases. Mitigation: Define clear mode branching at the start of each phase with a mode-dispatch table.
- **Dependency on unreleased tasks (Low)**: Tasks #263 and #266 must complete first for the full pipeline to work. Mitigation: The agent change is additive -- it adds a new type branch that does not affect existing types, so it can be implemented independently and tested once dependencies land.

## Implementation Phases

### Phase 1: Type Detection and Context References [COMPLETED]

**Goal**: Add project-timeline to the agent's type detection logic and context reference sections.

**Tasks**:
- [ ] Add project-timeline keywords to Stage 2 type detection logic (keywords: project, timeline, WBS, PERT, milestone, Gantt, deliverable, critical path)
- [ ] Add `project-timeline` to the report type table alongside market-sizing, competitive-analysis, gtm-strategy
- [ ] Add context references for project-timeline:
  - `@.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ`
  - `@.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md`
- [ ] Add project-timeline template to Stage 4 template loading table
- [ ] Add mode extraction from plan (read `forcing_data.mode` -- defaults to PLAN if absent)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Context References section, Stage 2, Stage 4

**Verification**:
- The report type table has 4 entries (market-sizing, competitive-analysis, gtm-strategy, project-timeline)
- Context references section lists project-timeline.typ and timeline-frameworks.md
- Stage 4 template table includes project-timeline row

---

### Phase 2: Project-Timeline 5-Phase Flow Definition [COMPLETED]

**Goal**: Define the complete 5-phase execution flow for project-timeline reports, matching the structure of the existing 3 report type flows.

**Tasks**:
- [ ] Add "Project-Timeline Phase Flow" section after the GTM Strategy Phase Flow section
- [ ] Define Phase 1: Timeline Structure and WBS Generation
  - Read research report (WBS, task hierarchy)
  - Read plan (phase structure, ordering)
  - Organize into chronological timeline format
  - Validate completeness (all tasks accounted for)
  - Extract data from research report sections
- [ ] Define Phase 2: PERT Calculations and Critical Path
  - Calculate expected durations using (O + 4M + P) / 6
  - Build dependency graph from WBS
  - Identify critical path (longest path through graph)
  - Calculate float/slack for non-critical tasks
  - Generate PERT summary table
- [ ] Define Phase 3: Resource Allocation Matrix
  - Map team members to tasks from research data
  - Detect resource conflicts (over-allocation)
  - Suggest leveling adjustments
  - Generate allocation table
- [ ] Define Phase 4: Gantt Chart and Typst Visualization
  - Generate self-contained Typst file at `strategy/timelines/{project-slug}.typ`
  - Inline project-timeline.typ template functions (self-contained pattern)
  - Include Gantt chart, PERT diagram, resource table
  - Include milestone markers and critical path highlighting
- [ ] Define Phase 5: PDF Compilation and Deliverables
  - Compile Typst to PDF at `founder/{project-slug}.pdf`
  - Generate markdown summary report at `strategy/timelines/{project-slug}-report.md`
  - Follow existing Phase 5 non-blocking error handling pattern

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - New section after GTM Strategy Phase Flow

**Verification**:
- All 5 phases defined with clear inputs, outputs, and data source references
- Phase structure matches the pattern used by market-sizing, competitive-analysis, and gtm-strategy
- Each phase includes research report section references for data extraction

---

### Phase 3: PLAN/TRACK/REPORT Mode Handling [COMPLETED]

**Goal**: Add mode-specific behavior branching for the project-timeline type across all 5 phases.

**Tasks**:
- [ ] Define mode dispatch table at the top of the project-timeline flow:
  - PLAN: Full timeline generation from scratch (default)
  - TRACK: Update existing timeline with progress data (requires prior PLAN output)
  - REPORT: Generate status report comparing planned vs actual
- [ ] Add PLAN mode behavior (default):
  - Phase 1: Generate full WBS from research
  - Phase 2: Calculate all PERT values and critical path
  - Phase 3: Full resource allocation matrix
  - Phase 4: Complete Gantt chart with all elements
  - Phase 5: Full PDF compilation
- [ ] Add TRACK mode behavior:
  - Phase 1: Read existing timeline, overlay progress data
  - Phase 2: Recalculate critical path with actuals
  - Phase 3: Update resource allocation with actual hours
  - Phase 4: Generate updated Gantt with progress overlay
  - Phase 5: PDF with progress indicators
  - Prerequisite check: verify PLAN output exists, fail with guidance if not
- [ ] Add REPORT mode behavior:
  - Phase 1: Read existing timeline + progress data
  - Phase 2: Calculate variance (planned vs actual durations)
  - Phase 3: Resource utilization analysis
  - Phase 4: Generate status report (not full Gantt)
  - Phase 5: PDF status report with variance tables
  - Prerequisite check: verify PLAN output exists

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Mode handling subsections within the project-timeline flow

**Verification**:
- Each mode has clear behavior defined for all 5 phases
- TRACK and REPORT modes include prerequisite checks
- Mode dispatch table is clearly documented

---

### Phase 4: Resume Support and Error Handling [COMPLETED]

**Goal**: Ensure project-timeline follows existing resume and error handling patterns.

**Tasks**:
- [ ] Verify resume support applies to project-timeline (the existing Stage 3 resume detection works for all types -- confirm no type-specific changes needed)
- [ ] Add project-timeline to the Stage 3.5 Typst phase check (verify Phase 5 detection includes project-timeline naming)
- [ ] Add project-timeline entries to error handling section:
  - Plan Not Found: same pattern
  - Research Report Not Found: same pattern but note WBS data is critical
  - Phase Failure: include project-specific data (WBS tasks completed, PERT calculations done)
- [ ] Add project-timeline to Stage 6 summary template:
  - Include key results: task count, critical path duration, resource count, milestone count
- [ ] Add project-timeline to Stage 7 metadata template:
  - Include report_type: "project-timeline"
  - Include mode, critical_path_duration, task_count, milestone_count

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Stages 3.5, 6, 7, and error handling section

**Verification**:
- Resume from any phase works identically to other report types
- Summary template includes project-specific metrics
- Metadata includes project-specific fields
- Error handling covers project-timeline-specific failure modes

---

### Phase 5: Self-Contained Typst Example and Verification [COMPLETED]

**Goal**: Add a self-contained Typst content example for project-timeline (matching the market-sizing example already in the agent) and verify the complete implementation.

**Tasks**:
- [ ] Add self-contained project-timeline.typ example showing:
  - Page setup and typography (same navy palette as other reports)
  - Gantt chart rendering functions (inlined from project-timeline.typ)
  - PERT diagram helper functions
  - Resource allocation table functions
  - Milestone markers and critical path highlighting
  - Example content with placeholder data
- [ ] Add the "Key differences" note for project-timeline (same pattern as market-sizing)
- [ ] Review complete agent file for consistency:
  - All 4 report types documented in the overview table
  - All 4 report types have phase flows
  - Context references complete
  - Template loading table complete
  - Summary and metadata templates include project-timeline
- [ ] Verify the agent's Critical Requirements section still applies (no project-timeline-specific additions needed)

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Typst example section and final review pass

**Verification**:
- Self-contained Typst example compiles conceptually (correct typst syntax)
- All 4 report types consistently documented across all stages
- No broken references or missing sections
- Agent file reads coherently as a complete specification

## Testing & Validation

- [ ] Verify the modified agent file parses correctly (no broken markdown)
- [ ] Confirm all 4 report types appear in the type detection table
- [ ] Confirm the project-timeline phase flow follows the same structural pattern as the other 3 types
- [ ] Confirm PLAN/TRACK/REPORT modes are documented with clear phase-by-phase behavior
- [ ] Confirm context references include project-timeline.typ and timeline-frameworks.md
- [ ] Confirm the self-contained Typst example uses correct typst syntax
- [ ] Confirm resume support does not require type-specific changes (existing pattern handles it)

## Artifacts & Outputs

- `plans/01_project-implement-support.md` (this file)
- Modified: `.claude/extensions/founder/agents/founder-implement-agent.md`
- Expected summary: `specs/267_project_implement_agent_support/summaries/01_project-implement-summary.md`

## Rollback/Contingency

The change is additive -- a new section added to founder-implement-agent.md plus minor updates to existing tables and context references. Rollback is straightforward: revert the single file to its pre-modification state via `git checkout`. No other files are affected.
