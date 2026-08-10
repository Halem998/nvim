# Research Report: Task #258

**Task**: 258 - Create project-agent.md for project timeline generation
**Started**: 2026-03-23T00:00:00Z
**Completed**: 2026-03-23T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task #256 (forcing questions module - COMPLETED), Task #257 (project-timeline.typ - COMPLETED)
**Sources/Inputs**:
  - `.claude/extensions/founder/agents/founder-plan-agent.md` - Agent structure patterns
  - `.claude/extensions/founder/agents/founder-implement-agent.md` - Agent execution flow
  - `.claude/extensions/founder/agents/strategy-agent.md` - Forcing questions integration
  - `.claude/extensions/founder/agents/market-agent.md` - Mode selection patterns
  - `.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md` - Forcing questions framework
  - `.claude/extensions/founder/context/project/founder/patterns/mode-selection.md` - Mode selection protocol
  - `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - PM domain knowledge
  - `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Typst template
  - `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema
  - `.claude/context/core/formats/report-format.md` - Report structure
  - `.claude/agents/planner-agent.md` - Core agent patterns
**Artifacts**:
  - `specs/258_project_agent/reports/01_project-agent-research.md` (this file)
**Standards**: report-format.md, artifact-formats.md, return-metadata-file.md

## Executive Summary

- **Founder agent architecture** provides established patterns: early metadata initialization (Stage 0), mode selection protocol, forcing questions integration, and phased execution with self-contained Typst output
- **Three operational modes** identified: PLAN (create new timeline), TRACK (update existing), REPORT (generate status report)
- **Forcing questions integration** adapts the existing framework for three-point estimation, gathering optimistic/likely/pessimistic durations for each task
- **WBS generation** follows timeline-frameworks.md patterns: hierarchical decomposition, 100% rule enforcement, deliverable-based structure
- **Typst output** must be self-contained (no imports) following founder-implement-agent's established pattern; outputs to `strategy/timelines/{project-slug}.typ`
- **Dependency mapping** supports all four types (FS/SS/FF/SF) with lag/lead time, enabling critical path identification

## Context & Scope

This research analyzes existing patterns in the founder extension to inform the design of `project-agent.md`, a new agent for project timeline generation. The agent must integrate:

1. **Forcing questions** (Task #256) - For eliciting three-point estimates from users
2. **project-timeline.typ** (Task #257) - For rendering professional Gantt charts, WBS trees, PERT tables, and resource matrices

The agent will be invoked through a new `/project` command (to be created separately) and will follow the established founder agent architecture.

## Findings

### 1. Founder Agent Architecture Patterns

All founder agents follow a consistent structure with these critical patterns:

**Stage 0: Early Metadata Initialization**
```json
{
  "status": "in_progress",
  "started_at": "{ISO8601 timestamp}",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, parsing delegation context"
  }
}
```

This pattern, present in all founder agents, ensures metadata exists even if the agent is interrupted mid-execution.

**Phased Execution Flow**:
1. Stage 0: Early metadata initialization
2. Stage 1: Parse delegation context
3. Stage 2: Mode selection (via AskUserQuestion)
4. Stages 3-N: Domain-specific forcing questions
5. Final stages: Artifact generation, metadata write, text summary return

**Return Format**: Brief text summary (NOT JSON) to console; metadata written to file.

### 2. Mode Selection Design

Based on mode-selection.md patterns and project management domain needs:

| Mode | Posture | Focus | Use Case |
|------|---------|-------|----------|
| **PLAN** | Create new | WBS + Gantt + estimates | Starting a new project |
| **TRACK** | Update existing | Progress updates | Ongoing project management |
| **REPORT** | Status output | Executive summary | Stakeholder communication |

**Mode Selection Protocol** (adapted from strategy-agent.md):
```
Before we begin, select your operational mode:

A) PLAN - "Create from scratch" - Define WBS, estimate tasks, generate timeline
B) TRACK - "Update progress" - Mark completions, add actuals, flag risks
C) REPORT - "Status snapshot" - Generate executive summary, identify blockers

Which mode best describes your need?
```

### 3. Forcing Questions for Three-Point Estimation

The forcing-questions.md pattern adapts naturally for PERT estimation:

**Per-Task Estimation Questions**:

```
Q1: Optimistic Duration
"If everything goes perfectly for '{task_name}', what's the minimum duration?"
Push for: Specific number with unit (days, weeks)
Reject: Ranges or "it depends"

Q2: Most Likely Duration
"What's the realistic expected duration for '{task_name}'?"
Push for: Specific number based on experience or comparable work
Reject: Padding or sandbagging

Q3: Pessimistic Duration
"If complications arise for '{task_name}', what's the maximum duration?"
Push for: Specific worst-case, not infinite
Consider: Dependencies failing, scope changes, resource unavailability
```

**Push-Back Patterns for Estimation**:

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "A few weeks" | "What specific number? 2 weeks? 3 weeks?" |
| "Depends on..." | "Assume those dependencies are resolved. What then?" |
| "Same as last time" | "What was the actual duration last time? In days?" |
| "Hard to estimate" | "Give me your best guess. We can refine later." |

### 4. WBS Generation Patterns

From timeline-frameworks.md, WBS generation follows:

**The 100% Rule**: Each level captures 100% of parent's work (no gaps, no overlaps).

**Recommended Structure**:
```
1.0 Project Name
├── 1.1 Phase 1
│   ├── 1.1.1 Deliverable A
│   └── 1.1.2 Deliverable B
├── 1.2 Phase 2
│   ├── 1.2.1 Deliverable C
│   └── 1.2.2 Deliverable D
└── 1.3 Phase 3
    └── 1.3.1 Deliverable E
```

**Forcing Questions for WBS**:

```
Q1: What are the major phases or milestones?
Push for: 3-5 distinct phases with clear boundaries
Reject: Overlapping or vague phases

Q2: For each phase, what are the deliverables?
Push for: Noun-based deliverables (what), not activities (how)
Reject: Activities disguised as deliverables

Q3: Are there any dependencies between phases?
Push for: Explicit predecessor relationships
Consider: FS (most common), SS, FF, SF types
```

### 5. Gantt Chart Data Preparation

project-timeline.typ's `project-gantt()` function expects:

```typst
#project-gantt(
  start-date: "2026-01-01",
  end-date: "2026-06-30",
  tasks: (
    (name: "Planning", id: "plan", start: "2026-01-01", end: "2026-01-15"),
    (name: "Development", id: "dev", start: "2026-01-16", end: "2026-03-01",
     dependencies: ("plan",), critical: true),
  ),
  milestones: (
    (name: "MVP Release", date: "2026-02-15"),
  ),
)
```

**Data Required Per Task**:
- `name`: Human-readable task name
- `id`: Machine identifier (for dependency references)
- `start`: ISO date string
- `end`: ISO date string
- `dependencies`: Array of predecessor task IDs
- `critical`: Boolean (on critical path?)

**Data Derivation**:
- Start/end dates calculated from PERT estimates and dependencies
- Critical path determined via forward/backward pass algorithm
- Milestones extracted from phase boundaries

### 6. Resource Allocation Integration

project-timeline.typ's `resource-matrix()` supports:

```typst
#resource-matrix(
  team: ("Alice", "Bob", "Carol"),
  periods: ("Week 1", "Week 2", "Week 3"),
  allocations: (
    (0, 0, "Planning", 100),  // (member-index, period-index, task, percentage)
    (1, 1, "Design", 50),
    (2, 2, "Frontend", 100),
  ),
)
```

**Forcing Questions for Resources**:

```
Q1: Who are the team members working on this project?
Push for: Names and roles
Consider: Part-time vs full-time availability

Q2: What's each person's capacity per period?
Push for: Percentage or hours per week
Flag: Overallocation (>100% capacity)
```

### 7. Self-Contained Typst Generation Pattern

From founder-implement-agent.md Phase 5:

**CRITICAL**: Generated .typ files must be self-contained with all template functions inlined. This avoids import path resolution issues.

```typst
// Self-contained project timeline document
// Generated by project-agent
// Professional styling: Navy palette

// ============================================================================
// Inlined Color Palette and Typography
// ============================================================================

#let navy-dark = rgb("#0a2540")
// ... (all colors inlined)

#set page(
  paper: "us-letter",
  margin: (top: 1.1in, bottom: 1.0in, left: 1.1in, right: 1.1in),
)

// ... (all helper functions inlined)

// ============================================================================
// Document Content
// ============================================================================

= Project Timeline: {project_name}

// ... (generated content)
```

**Output Path**: `strategy/timelines/{project-slug}.typ`

**Compilation**:
```bash
typst compile "strategy/timelines/{project-slug}.typ" "strategy/timelines/{project-slug}.pdf"
```

### 8. Agent Structure Recommendation

Based on analyzed patterns, project-agent.md should follow this structure:

```markdown
---
name: project-agent
description: Project timeline planning with WBS, PERT estimation, and Gantt generation
---

## Overview
## Agent Metadata
## Allowed Tools
## Context References
## Execution Flow
  - Stage 0: Early Metadata Initialization
  - Stage 1: Parse Delegation Context
  - Stage 2: Mode Selection (PLAN/TRACK/REPORT)
  - Stage 3: Mode-specific forcing questions
    - PLAN: WBS definition, task estimation, resource allocation
    - TRACK: Progress updates, actual vs planned
    - REPORT: Status data collection
  - Stage 4: Data Processing (PERT calculation, critical path)
  - Stage 5: Typst Generation (self-contained)
  - Stage 6: PDF Compilation
  - Stage 7: Metadata File Write
  - Stage 8: Text Summary Return
## Mode-Specific Flows
## Error Handling
## Critical Requirements
```

### 9. PERT Calculation Implementation

From timeline-frameworks.md:

```
Expected Duration (E) = (O + 4M + P) / 6
Standard Deviation (SD) = (P - O) / 6
95% Confidence Interval = E +/- 2*SD
```

The agent should:
1. Collect O, M, P for each task via forcing questions
2. Calculate E and SD
3. Sum expected durations along paths
4. Identify critical path (longest path)
5. Calculate project-level confidence interval

### 10. Critical Path Analysis

**Algorithm Steps** (from timeline-frameworks.md):
1. Forward pass: Calculate early start/finish
2. Backward pass: Calculate late start/finish
3. Identify critical tasks (zero float)

The agent should highlight critical tasks in the Gantt chart using `critical: true` flag.

## Decisions

1. **Three modes (PLAN/TRACK/REPORT)** - Covers the full project lifecycle from initial planning through execution and reporting
2. **One-question-at-a-time forcing** - Maintains forcing-questions.md pattern for estimation accuracy
3. **Self-contained Typst output** - Follows founder-implement-agent precedent to avoid import issues
4. **Output to strategy/timelines/** - Parallel to strategy/ directory for other founder outputs
5. **PERT over simple estimation** - Three-point estimation provides risk-aware scheduling

## Recommendations

### Implementation Phase Structure

**Phase 1: Agent Definition**
- Create project-agent.md with full specification
- Define all three mode flows (PLAN, TRACK, REPORT)
- Include forcing question sequences for each mode

**Phase 2: Forcing Questions Integration**
- Define task-level three-point estimation questions
- Define WBS elicitation questions
- Define resource allocation questions

**Phase 3: Data Processing**
- PERT calculation functions (conceptual)
- Critical path identification logic
- Schedule calculation (dates from durations + dependencies)

**Phase 4: Typst Generation**
- Self-contained template with inlined functions
- All project-timeline.typ components integrated
- Dynamic content population

**Phase 5: Skill and Command Integration**
- skill-project creation
- /project command creation (separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| User provides vague estimates | Medium | High | Strong push-back patterns in forcing questions |
| Typst not installed | Low | Medium | Phase skipping with warning (non-blocking) |
| Complex dependency graphs | Medium | Low | Limit to FS dependencies initially; extend later |
| Large project overwhelms | Medium | Medium | Recommend <30 tasks per timeline; suggest decomposition |

## Appendix

### File References

**Completed Dependencies**:
- Task #256: `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` (329 lines)
- Task #257: `.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` (833 lines)

**Key Patterns Referenced**:
- `.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md`
- `.claude/extensions/founder/context/project/founder/patterns/mode-selection.md`

**Agent Architecture References**:
- `.claude/extensions/founder/agents/founder-plan-agent.md`
- `.claude/extensions/founder/agents/founder-implement-agent.md`
- `.claude/extensions/founder/agents/strategy-agent.md`
- `.claude/agents/planner-agent.md`

### project-timeline.typ Component Summary

| Component | Function | Data Required |
|-----------|----------|---------------|
| `project-gantt()` | Gantt chart | tasks[], milestones[], dates |
| `pert-estimate()` | Single task PERT | O, M, P values |
| `pert-table()` | Multi-task PERT | tasks[] with O, M, P |
| `resource-matrix()` | Resource allocation | team[], periods[], allocations[] |
| `wbs-tree()` | WBS diagram | project name, phases[] with tasks[] |
| `project-risk-matrix()` | Risk quadrant | high-high[], high-low[], etc. |
| `project-summary()` | Status card | name, dates, status, progress |
| `critical-task()` | Critical path styling | name, dates |
| `milestone-badge()` | Milestone marker | name, date |
