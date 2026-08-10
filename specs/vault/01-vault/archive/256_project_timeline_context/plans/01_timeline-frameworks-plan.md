# Implementation Plan: Task #256

- **Task**: 256 - project_timeline_context
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/256_project_timeline_context/reports/01_timeline-frameworks.md
- **Artifacts**: plans/01_timeline-frameworks-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `timeline-frameworks.md` in the founder extension's domain knowledge directory, documenting project management best practices including WBS, milestones, dependencies, PERT estimation, critical path analysis, resource allocation, and risk assessment. The file follows the established pattern of existing domain files (business-frameworks.md, legal-frameworks.md, strategic-thinking.md) with ~250 lines, tables, Unicode diagrams, and practical examples. This provides domain knowledge for a future project-agent.

### Research Integration

Research report (01_timeline-frameworks.md) identified:
- Codebase pattern: H1 title, brief intro, H2 sections with tables/diagrams
- Target line count: 214-276 lines (matching existing domain files)
- Seven PM domain areas: WBS, milestones, dependencies, PERT, CPM, resources, risk
- External sources: PMI, Atlassian, Wrike, Asana documentation

## Goals & Non-Goals

**Goals**:
- Create comprehensive timeline-frameworks.md (~250 lines)
- Cover all 7 PM domain areas from research
- Match structure and style of existing domain files
- Include practical formulas and calculation examples
- Add proper index entry for context discovery

**Non-Goals**:
- Creating the project-agent itself (future task)
- Covering all possible PM methodologies (Agile, Scrum, etc.)
- Duplicating information already in other domain files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| File too long/verbose | M | L | Target 250 lines, use tables over prose |
| Inconsistent style with existing files | M | L | Follow business-frameworks.md structure exactly |
| Missing index entry | L | L | Verify index-entries.json update in final phase |

## Implementation Phases

### Phase 1: File Structure and Introduction [COMPLETED]

**Goal**: Create the file skeleton with header, introduction, and section placeholders

**Tasks**:
- [ ] Create file at `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md`
- [ ] Add H1 title and brief introduction (2 lines)
- [ ] Add all 8 H2 section headers as placeholders

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - create new

**Verification**:
- File exists with correct path
- All section headers present

---

### Phase 2: WBS and Milestones Sections [COMPLETED]

**Goal**: Complete Work Breakdown Structure and Milestone Types sections

**Tasks**:
- [ ] Write WBS section with 100% rule explanation
- [ ] Add WBS best practices table (4 rows)
- [ ] Add WBS types table (deliverable vs phase)
- [ ] Write Milestones section with 5 milestone types table
- [ ] Add milestone lifecycle placement explanation

**Timing**: 25 minutes

**Dependencies**: Phase 1

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - update

**Verification**:
- WBS section has 100% rule, best practices table, types
- Milestones section has 5 types table

---

### Phase 3: Dependencies and PERT Sections [COMPLETED]

**Goal**: Complete Dependency Mapping and Three-Point Estimation sections

**Tasks**:
- [ ] Write dependency types table (FS, SS, FF, SF)
- [ ] Add lag/lead concept explanation
- [ ] Write PERT formula section with beta distribution
- [ ] Add standard deviation formula
- [ ] Include practical calculation example (code block)

**Timing**: 25 minutes

**Dependencies**: Phase 2

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - update

**Verification**:
- Dependency table has 4 types with notation
- PERT section has formula, SD formula, worked example

---

### Phase 4: CPM, Resources, and Risk Sections [COMPLETED]

**Goal**: Complete Critical Path, Resource Allocation, and Risk Assessment sections

**Tasks**:
- [ ] Write Critical Path section with CPM steps
- [ ] Add float/slack concept explanation
- [ ] Write Resource Allocation section with leveling vs smoothing table
- [ ] Add decision matrix diagram (Unicode box-drawing)
- [ ] Write Risk Assessment section with 5x5 matrix visualization
- [ ] Add color coding and action guidance table

**Timing**: 30 minutes

**Dependencies**: Phase 3

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - update

**Verification**:
- CPM section has 7 steps
- Resource section has comparison table and decision matrix
- Risk section has 5x5 matrix with Unicode characters

---

### Phase 5: References and Index Update [COMPLETED]

**Goal**: Add references section and update extension index

**Tasks**:
- [ ] Add References section with external links
- [ ] Update `.claude/extensions/founder/index-entries.json` with new entry
- [ ] Verify file line count is ~250 lines
- [ ] Verify all sections complete and properly formatted

**Timing**: 10 minutes

**Dependencies**: Phase 4

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - finalize
- `.claude/extensions/founder/index-entries.json` - add entry

**Verification**:
- References section has 5+ external links
- Index entry added with correct load_when conditions
- File line count between 214-276 lines

## Testing & Validation

- [ ] File exists at correct path
- [ ] File follows same structure as business-frameworks.md
- [ ] All 7 PM domain areas covered
- [ ] Line count within target range (214-276)
- [ ] Unicode box-drawing characters render correctly
- [ ] Index entry has correct agents, languages, commands
- [ ] No syntax errors in index-entries.json

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - main deliverable
- `.claude/extensions/founder/index-entries.json` - updated with new entry
- `specs/256_project_timeline_context/summaries/01_timeline-frameworks-summary.md` - execution summary

## Rollback/Contingency

If implementation fails:
1. Delete timeline-frameworks.md if incomplete
2. Revert index-entries.json changes via git
3. Task remains in PLANNED status for retry
