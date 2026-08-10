# Implementation Plan: Task #258

- **Task**: 258 - Create project-agent.md for project timeline generation
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: Task #256 (forcing questions - COMPLETED), Task #257 (project-timeline.typ - COMPLETED)
- **Research Inputs**: specs/258_project_agent/reports/01_project-agent-research.md
- **Artifacts**: plans/01_project-agent-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create `project-agent.md` for the founder extension, implementing project timeline generation with three operational modes (PLAN/TRACK/REPORT), forcing questions for three-point estimation, WBS generation, Gantt chart data preparation, and self-contained Typst output. The agent follows established founder agent patterns with early metadata initialization, mode selection protocol, and phase-based execution flow.

### Research Integration

Key findings from research report:
- Founder agent architecture uses 8-stage execution flow with early metadata (Stage 0)
- Three modes cover full project lifecycle: PLAN (new timelines), TRACK (progress updates), REPORT (status snapshots)
- Forcing questions adapt naturally for PERT three-point estimation (O, M, P per task)
- project-timeline.typ provides all visualization components (Gantt, WBS, PERT, resource matrix)
- Self-contained Typst output pattern established by founder-implement-agent

## Goals & Non-Goals

**Goals**:
- Create project-agent.md with full specification following founder agent patterns
- Implement mode selection protocol (PLAN/TRACK/REPORT)
- Integrate forcing questions for WBS elicitation and three-point estimation
- Define data structures matching project-timeline.typ component requirements
- Enable self-contained Typst generation with inlined template functions
- Support PDF compilation via typst compile

**Non-Goals**:
- Creating the /project command (separate task)
- Creating skill-project skill wrapper (separate task if needed)
- Implementing interactive Gantt chart editing
- Supporting complex dependency types beyond FS initially

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| User provides vague estimates | Medium | High | Strong push-back patterns in forcing questions |
| Typst not installed | Low | Medium | Skip Typst phase with warning (non-blocking) |
| Complex dependency graphs | Medium | Low | Limit to FS dependencies initially |
| Large project overwhelms | Medium | Medium | Recommend <30 tasks per timeline |
| Template inlining bloats output | Low | Medium | Selective inlining of required functions only |

## Implementation Phases

### Phase 1: Agent Foundation [COMPLETED]

**Goal**: Create base agent structure with metadata, overview, and allowed tools sections

**Tasks**:
- [ ] Create `.claude/extensions/founder/agents/project-agent.md`
- [ ] Write frontmatter (name, description)
- [ ] Write Overview section describing agent purpose
- [ ] Write Agent Metadata section (name, purpose, invoked by, return format)
- [ ] Define Allowed Tools section (AskUserQuestion, Read, Write, Edit, Glob, Bash)
- [ ] Write Context References section with on-demand @-references
  - Always load: timeline-frameworks.md, forcing-questions.md, mode-selection.md
  - Load for output: return-metadata-file.md, project-timeline.typ

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Create new file

**Verification**:
- File exists with valid frontmatter
- All required sections present
- Context references point to existing files

---

### Phase 2: Execution Flow - Initialization [COMPLETED]

**Goal**: Define Stage 0-2 of execution flow (early metadata, delegation parsing, mode selection)

**Tasks**:
- [ ] Write Stage 0: Initialize Early Metadata
  - Create metadata file before substantive work
  - Include status "in_progress", started_at timestamp
  - Define partial_progress structure
- [ ] Write Stage 1: Parse Delegation Context
  - Define expected input JSON structure
  - Extract task_number, project_name, description, language
  - Extract metadata_file_path, session_id, delegation_path
- [ ] Write Stage 2: Mode Selection
  - Define PLAN/TRACK/REPORT modes with descriptions
  - AskUserQuestion for mode selection
  - Mode confirmation step
  - Mode-specific flow routing logic

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add execution flow stages 0-2

**Verification**:
- Mode selection question matches mode-selection.md patterns
- Early metadata structure matches return-metadata-file.md schema
- All three modes have clear descriptions

---

### Phase 3: PLAN Mode - WBS Elicitation [COMPLETED]

**Goal**: Define forcing questions for Work Breakdown Structure generation

**Tasks**:
- [ ] Write Stage 3a: Project Definition Questions
  - Q1: Project name and scope
  - Q2: Target completion date (if any)
  - Q3: Key stakeholders
- [ ] Write Stage 3b: Phase Elicitation Questions
  - Q4: Major phases/milestones (push for 3-5 phases)
  - Q5: Phase dependencies (FS relationships)
  - Q6: Deliverables per phase (nouns, not activities)
- [ ] Write Stage 3c: Task Decomposition Questions
  - Q7: Tasks within each phase
  - Q8: Task dependencies within phases
- [ ] Define WBS data structure for storage
  - Hierarchical structure matching wbs-tree() component
  - 100% rule enforcement guidance
- [ ] Include push-back patterns for vague answers
  - "3-5 distinct phases" vs "many tasks"
  - Deliverable-based vs activity-based

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add PLAN mode WBS stages

**Verification**:
- Questions follow one-at-a-time forcing pattern
- Push-back triggers defined for common vague patterns
- Data structure matches wbs-tree() expected format

---

### Phase 4: PLAN Mode - Three-Point Estimation [COMPLETED]

**Goal**: Define forcing questions for PERT three-point estimation per task

**Tasks**:
- [ ] Write Stage 4: Three-Point Estimation Questions
  - Per-task estimation loop
  - Q1: Optimistic duration (best case)
  - Q2: Most likely duration (realistic)
  - Q3: Pessimistic duration (worst case)
- [ ] Define push-back patterns for estimation
  - "A few weeks" -> "What specific number?"
  - "Depends on..." -> "Assume resolved, what then?"
  - "Hard to estimate" -> "Best guess, we can refine"
- [ ] Define PERT calculation logic (conceptual)
  - E = (O + 4M + P) / 6
  - SD = (P - O) / 6
  - 95% CI = E +/- 2*SD
- [ ] Define PERT data structure matching pert-table() component
  - tasks[] with optimistic, likely, pessimistic
  - unit (days, weeks)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add PLAN mode estimation stages

**Verification**:
- Three-point questions cover O, M, P clearly
- Push-back patterns enforce specificity
- Data structure matches pert-table() expected format

---

### Phase 5: PLAN Mode - Resource & Schedule [COMPLETED]

**Goal**: Define resource allocation questions and schedule calculation

**Tasks**:
- [ ] Write Stage 5a: Resource Allocation Questions
  - Q1: Team members working on project
  - Q2: Roles and responsibilities
  - Q3: Availability per period (hours/week or %)
  - Push for: Names and roles, not "the team"
- [ ] Write Stage 5b: Schedule Calculation Logic (conceptual)
  - Forward pass: Early start/finish dates
  - Backward pass: Late start/finish dates
  - Critical path identification (zero float)
- [ ] Define resource data structure matching resource-matrix()
  - team[] array
  - periods[] array
  - allocations[] with member-index, period-index, task, percentage
- [ ] Include overallocation detection guidance
  - Flag when member > 100% capacity in period

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add PLAN mode resource stages

**Verification**:
- Resource questions follow forcing pattern
- Data structures match resource-matrix() expected format
- Overallocation detection logic defined

---

### Phase 6: TRACK & REPORT Modes [COMPLETED]

**Goal**: Define execution flows for TRACK and REPORT modes

**Tasks**:
- [ ] Write TRACK Mode Stages
  - Stage 3T: Locate existing timeline file
  - Stage 4T: Progress update questions per task
    - Q1: Task status (not started/in progress/completed)
    - Q2: Actual start/end dates (if applicable)
    - Q3: Remaining effort estimate
    - Q4: Blockers or risks
  - Stage 5T: Schedule recalculation
  - Stage 6T: Updated Typst generation
- [ ] Write REPORT Mode Stages
  - Stage 3R: Locate existing timeline file
  - Stage 4R: Status data extraction
  - Stage 5R: Executive summary generation
    - Overall progress percentage
    - Critical path status
    - Key risks and blockers
    - Upcoming milestones
  - Stage 6R: Report Typst generation (project-summary component)
- [ ] Define mode-specific output paths
  - TRACK: Updates existing .typ file
  - REPORT: Creates {slug}-report.typ

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add TRACK and REPORT mode sections

**Verification**:
- TRACK mode can update existing timelines
- REPORT mode generates executive summary format
- Both modes handle missing timeline gracefully

---

### Phase 7: Typst Generation & Output [COMPLETED]

**Goal**: Define self-contained Typst generation and PDF compilation stages

**Tasks**:
- [ ] Write Stage 6 (PLAN) / Stage 6T (TRACK) / Stage 6R (REPORT): Typst Generation
  - Self-contained template structure (no imports)
  - Color palette inlining from project-timeline.typ
  - Required function inlining:
    - project-gantt() for Gantt chart
    - pert-table() for estimation display
    - wbs-tree() for WBS visualization
    - resource-matrix() for resource allocation
    - project-summary() for status card
  - Dynamic content population from gathered data
- [ ] Define output path conventions
  - PLAN: `strategy/timelines/{project-slug}.typ`
  - TRACK: Updates existing file
  - REPORT: `strategy/timelines/{project-slug}-report.typ`
- [ ] Write Stage 7: PDF Compilation
  - Check typst availability
  - Run `typst compile` command
  - Handle compilation errors gracefully
  - Skip with warning if typst unavailable
- [ ] Define file structure for generated Typst
  - Header comment with generation metadata
  - Inlined color definitions
  - Inlined helper functions
  - Document content sections

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add Typst generation stages

**Verification**:
- Generated Typst compiles without imports
- Output paths follow convention
- PDF compilation handles missing typst gracefully

---

### Phase 8: Metadata & Error Handling [COMPLETED]

**Goal**: Define metadata file writing, error handling, and return format

**Tasks**:
- [ ] Write Stage 8: Write Metadata File
  - Final status (planned/tracked/reported based on mode)
  - Artifacts array with generated files
  - Metadata object with session_id, agent_type, duration
  - Mode-specific fields (phase_count for PLAN, etc.)
- [ ] Write Stage 9: Return Brief Text Summary
  - 3-6 bullet points
  - Mode-specific content
  - NOT JSON output
- [ ] Write Error Handling section
  - Invalid task (task not found)
  - No existing timeline (for TRACK/REPORT)
  - Typst compilation failure
  - Partial completion (timeout)
- [ ] Write Critical Requirements section
  - MUST DO list (10 items)
  - MUST NOT list (10 items)
- [ ] Add mode-specific return examples
  - PLAN success
  - TRACK success
  - REPORT success
  - Partial/failed scenarios

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add metadata and error handling

**Verification**:
- Metadata structure matches return-metadata-file.md schema
- All error scenarios have recovery guidance
- Return format is brief text (not JSON)

## Testing & Validation

- [ ] Agent file passes markdown linting
- [ ] All @-references point to existing files
- [ ] Mode selection question is clear and unambiguous
- [ ] Forcing questions follow one-at-a-time pattern
- [ ] Data structures match project-timeline.typ component requirements
- [ ] Generated Typst example compiles without errors
- [ ] Error handling covers all identified scenarios
- [ ] Metadata schema matches return-metadata-file.md

## Artifacts & Outputs

- `.claude/extensions/founder/agents/project-agent.md` - Main agent definition
- This plan file as implementation guide

## Rollback/Contingency

- If agent structure doesn't fit founder patterns: Revisit founder-plan-agent.md and strategy-agent.md for additional patterns
- If Typst generation is too complex: Split into separate inline-template generation phase
- If three modes are too much: Start with PLAN mode only, add TRACK/REPORT in follow-up task
