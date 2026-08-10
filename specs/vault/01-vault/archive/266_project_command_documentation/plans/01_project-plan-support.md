# Implementation Plan: Add project support to founder-plan-agent

- **Task**: 266 - Add project support to founder-plan-agent
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: Task #262 (refactor project-agent to produce research reports)
- **Research Inputs**: specs/266_project_command_documentation/reports/01_meta-research.md
- **Artifacts**: plans/01_project-plan-support.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend founder-plan-agent.md to handle the `project-timeline` report type. The agent currently detects three report types (market-sizing, competitive-analysis, gtm-strategy) via keyword matching but has no support for project management tasks. This plan adds keyword detection, research report parsing instructions, and a 5-phase plan structure for project-timeline reports. An optional planning context file provides project management reference material.

### Research Integration

- Research report 01_meta-research.md confirmed the agent's Stage 3-5 structure and identified exact insertion points for keyword table, parsing section, and phase structure.
- Phase 5 naming differs from existing types: "PDF Compilation and Deliverables" instead of "Typst Document Generation" because Typst generation occurs in Phase 4 for this report type.
- Output paths follow existing project-agent conventions: `strategy/timelines/{slug}.typ` and `.pdf`.

## Goals & Non-Goals

**Goals**:
- Add `project-timeline` keyword detection to Stage 4 of founder-plan-agent.md
- Add project-timeline research report parsing instructions to Stage 3
- Define 5-phase plan structure for project-timeline reports
- Update output conventions with Typst/PDF paths for project timelines
- Optionally create a project-planning context file for implementation quality

**Non-Goals**:
- Modifying the project-agent itself (that is task 262)
- Adding project-timeline support to founder-implement-agent (that is task 267)
- Updating manifest.json routing (that is task 268)
- Implementing PERT calculation logic (that happens during implementation, not planning)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Task 262 not yet complete, research report format may change | H | M | Base parsing on research report spec from task 262's research; coordinate if format changes |
| Keyword overlap with general terms (project, schedule) | L | L | Require multiple keyword matches; check report header for explicit type marker |
| Phase 5 naming inconsistency with other report types | L | L | Document the distinction clearly in agent file with a note explaining why |

## Implementation Phases

### Phase 1: Keyword Detection and Report Parsing [COMPLETED]

**Goal**: Add project-timeline keyword detection to Stage 4 and parsing instructions to Stage 3 of founder-plan-agent.md.

**Tasks**:
- [ ] Read current founder-plan-agent.md to identify exact insertion points
- [ ] Add keyword row to Stage 4 detection table: `project, timeline, WBS, PERT, milestone, Gantt, deliverable, schedule, critical path` -> `project-timeline`
- [ ] Add "For project-timeline reports" extraction section to Stage 3 covering: Project Scope, Stakeholders, WBS, PERT Estimates, Resource Data, Dependencies, Risk Register
- [ ] Update report output conventions table with Typst/PDF paths for project-timeline
- [ ] Verify keyword table and parsing section are consistent with existing patterns

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Add keyword row and parsing section

**Verification**:
- Keyword table has 4 rows (market-sizing, competitive-analysis, gtm-strategy, project-timeline)
- Stage 3 has a "For project-timeline reports" section parallel to existing type sections

---

### Phase 2: Phase Structure Definition [COMPLETED]

**Goal**: Add the 5-phase project-timeline plan structure under "Phase Structure by Report Type" in founder-plan-agent.md.

**Tasks**:
- [ ] Add Phase 1: Timeline Structure and WBS Validation (organize WBS, validate 100% rule, establish milestones)
- [ ] Add Phase 2: PERT Calculations and Critical Path Analysis (expected durations, forward/backward pass, critical path, float/slack)
- [ ] Add Phase 3: Resource Allocation Matrix (team-to-task mapping, overallocation checks, availability validation)
- [ ] Add Phase 4: Gantt Chart and Typst Visualization (generate Typst timeline at `strategy/timelines/{slug}.typ`)
- [ ] Add Phase 5: PDF Compilation and Deliverables (compile Typst to PDF, generate executive summary)
- [ ] Add note explaining Phase 5 naming difference from other report types
- [ ] Ensure each phase includes: inputs, outputs, and verification criteria

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Add phase structure section

**Verification**:
- Phase structure has 5 phases with consistent formatting
- Each phase lists inputs, outputs, and verification criteria
- Phase 4 handles Typst generation (not Phase 5)
- Phase 5 handles PDF compilation

---

### Phase 3: Planning Context File (Optional) [COMPLETED]

**Goal**: Create a project-planning context file with project management reference material and register it in the extension's index entries.

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/patterns/project-planning.md` with:
  - Project management terminology reference
  - WBS validation rules (100% rule, deliverable-based decomposition)
  - PERT calculation formulas (Expected = (O + 4M + P) / 6)
  - Critical path method description (forward pass, backward pass, float)
  - Resource leveling guidance
- [ ] Add context reference to founder-plan-agent.md "Context References" section
- [ ] Add entry to `.claude/extensions/founder/index-entries.json` for context discovery

**Timing**: 20 minutes

**Files to create**:
- `.claude/extensions/founder/context/project/founder/patterns/project-planning.md`

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Add context reference
- `.claude/extensions/founder/index-entries.json` - Add index entry

**Verification**:
- Context file contains PERT formula, CPM description, WBS rules
- Index entry has correct path and load_when conditions
- Agent file references the new context file

---

### Phase 4: Verification and Testing [COMPLETED]

**Goal**: Verify all changes are consistent, correctly formatted, and the agent file remains valid.

**Tasks**:
- [ ] Re-read the complete founder-plan-agent.md to verify structural integrity
- [ ] Verify all 4 report types have parallel structure (keyword table, parsing, phases)
- [ ] Verify no existing report type sections were accidentally modified
- [ ] Check that metadata output section includes `report_type: "project-timeline"`
- [ ] Validate index-entries.json is valid JSON after modification

**Timing**: 10 minutes

**Files to verify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md`
- `.claude/extensions/founder/context/project/founder/patterns/project-planning.md`
- `.claude/extensions/founder/index-entries.json`

**Verification**:
- Agent file parses as valid markdown with consistent heading structure
- All four report types have keyword detection, parsing section, and phase structure
- Index entries JSON is valid

## Testing & Validation

- [ ] Keyword detection table has exactly 4 rows with no overlapping primary keywords
- [ ] Stage 3 parsing section for project-timeline covers all 7 data categories from research
- [ ] Phase structure has 5 phases with inputs/outputs for each
- [ ] Context file contains PERT formula and CPM description
- [ ] No existing report type sections were modified
- [ ] All file paths in the plan match actual extension directory structure

## Artifacts & Outputs

- `.claude/extensions/founder/agents/founder-plan-agent.md` (modified)
- `.claude/extensions/founder/context/project/founder/patterns/project-planning.md` (new)
- `.claude/extensions/founder/index-entries.json` (modified)

## Rollback/Contingency

All changes are additions to existing files (new table rows, new sections) or new files. Rollback is straightforward:
- Revert founder-plan-agent.md to pre-change state via git
- Delete the new project-planning.md context file
- Remove the added index entry from index-entries.json
