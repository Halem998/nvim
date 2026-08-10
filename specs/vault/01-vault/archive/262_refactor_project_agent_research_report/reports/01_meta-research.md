# Research Report: Task #262

**Task**: 262 - Refactor project-agent to generate research report instead of timeline
**Started**: 2026-03-24
**Completed**: 2026-03-24
**Effort**: Medium (2-3 hours)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of project-agent.md, market-agent.md (reference pattern)
**Artifacts**: This report
**Standards**: report-format.md, return-metadata-file.md

---

## Executive Summary

- project-agent currently operates as a monolithic full-lifecycle agent that gathers data, generates Typst timeline files, compiles PDFs, and supports three modes (PLAN/TRACK/REPORT) -- all in a single invocation
- The refactoring transforms it into a research-only agent matching the pattern used by market-agent, analyze-agent, strategy-agent, and legal-council-agent
- Core data gathering logic (forcing questions, WBS decomposition, PERT estimation) is preserved intact; only the output stage and mode handling change
- The primary file affected is `.claude/extensions/founder/agents/project-agent.md` (913 lines)

## Context and Scope

### Problem Statement

The `/project` command currently runs through research, planning, and implementation phases autonomously in a single agent invocation. This violates the standard phased workflow pattern (`/research` -> `/plan` -> `/implement`) that allows user review between phases. The project-agent needs to be split so that its research phase produces a report (not a Typst file), and timeline generation is deferred to the implementation phase.

### Scope Boundaries

- **In scope**: Modifying project-agent.md to output research reports and return status `"researched"`
- **Out of scope**: Creating the corresponding plan-agent or implementation-agent for timeline generation (separate tasks)
- **Out of scope**: Modifying skill-project routing (may need a follow-up task)

## Findings

### Current project-agent.md Structure (913 lines)

The agent file at `.claude/extensions/founder/agents/project-agent.md` contains these major sections:

| Section | Lines | Description | Action |
|---------|-------|-------------|--------|
| Frontmatter + Overview | 1-16 | Agent metadata, three modes described | **Modify**: Remove TRACK/REPORT from overview |
| Agent Metadata | 18-24 | Name, purpose, invoked-by, return format | **Modify**: Update purpose description |
| Allowed Tools | 26-37 | AskUserQuestion, Read, Write, Edit, Glob, Bash | **Modify**: Remove Bash (no Typst compilation needed) |
| Context References | 39-51 | Timeline frameworks, forcing questions, mode selection, Typst template | **Modify**: Remove Typst template reference, remove mode-selection reference |
| Stage 0: Initialize Early Metadata | 56-73 | Early metadata pattern | **Keep as-is** |
| Stage 1: Parse Delegation Context | 75-94 | Parse mode from input | **Modify**: Remove `"mode"` field |
| Stage 2: Mode Selection | 96-123 | AskUserQuestion for PLAN/TRACK/REPORT | **Remove entirely** |
| Stage 3a: Project Definition Questions | 129-158 | Q1-Q3: Name/scope, target date, stakeholders | **Keep as-is** |
| Stage 3b: Phase Elicitation Questions | 160-194 | Q4-Q6: Phases, dependencies, deliverables | **Keep as-is** |
| Stage 3c: Task Decomposition Questions | 196-249 | Q7-Q8: Tasks within phases, WBS data structure | **Keep as-is** |
| Stage 4: Three-Point Estimation | 253-319 | PERT estimation with push-back patterns | **Keep as-is** |
| Stage 5a: Resource Allocation Questions | 323-348 | Team members, availability, assignments | **Keep as-is** |
| Stage 5b: Schedule Calculation Logic | 349-398 | Forward/backward pass, critical path, overallocation | **Keep as-is** |
| TRACK Mode Execution | 401-470 | Stages 3T-6T: Progress tracking | **Remove entirely** |
| REPORT Mode Execution | 472-528 | Stages 3R-6R: Executive summary | **Remove entirely** |
| Stage 6/6T/6R: Typst Generation | 530-637 | Self-contained Typst template, function inlining, output paths | **Remove entirely** |
| Stage 7: PDF Compilation | 640-666 | Typst compile command, error handling | **Remove entirely** |
| Stage 8: Write Metadata File | 668-754 | Three metadata templates (PLAN/TRACK/REPORT) | **Replace**: Single template with status "researched" |
| Stage 9: Return Brief Text Summary | 756-798 | Three summary templates | **Replace**: Single research-oriented summary |
| Error Handling | 800-886 | Four error scenarios including Typst-specific | **Modify**: Remove Typst compilation failure case |
| Critical Requirements | 888-913 | MUST DO / MUST NOT lists | **Modify**: Update for research-only behavior |

### Sections to Remove (approximately 400 lines)

1. **Stage 2: Mode Selection** (lines 96-123) - No mode selection needed; agent always does research
2. **TRACK Mode Execution** (lines 401-470) - Entire section: Stages 3T, 4T, 5T, 6T
3. **REPORT Mode Execution** (lines 472-528) - Entire section: Stages 3R, 4R, 5R, 6R
4. **Stage 6/6T/6R: Typst Generation** (lines 530-637) - All Typst template code, color definitions, function inlining strategy, output path conventions
5. **Stage 7: PDF Compilation** (lines 640-666) - typst compile command and error handling
6. **TRACK metadata template** (lines 707-730) in Stage 8
7. **REPORT metadata template** (lines 731-754) in Stage 8
8. **TRACK/REPORT summary examples** (lines 777-798) in Stage 9
9. **Typst Compilation Failure error** (lines 845-865) in Error Handling

### Sections to Keep Intact (approximately 350 lines)

1. **Stage 0: Initialize Early Metadata** (lines 56-73) - Standard early metadata pattern
2. **Stage 3a: Project Definition Questions** (lines 129-158) - Q1-Q3 forcing questions
3. **Stage 3b: Phase Elicitation Questions** (lines 160-194) - Q4-Q6 forcing questions
4. **Stage 3c: Task Decomposition Questions** (lines 196-249) - Q7-Q8 forcing questions with WBS data structure
5. **Stage 4: Three-Point Estimation** (lines 253-319) - PERT estimation with push-back patterns and data structure
6. **Stage 5a: Resource Allocation Questions** (lines 323-348) - Team, availability, assignments
7. **Stage 5b: Schedule Calculation Logic** (lines 349-398) - Forward/backward pass, critical path, overallocation detection with data structure

### Sections to Modify

1. **Overview** (lines 8-16): Remove three-mode description; describe as research agent
2. **Agent Metadata** (lines 18-24): Update purpose to "Project research with WBS and PERT estimation"
3. **Allowed Tools** (lines 26-37): Remove Bash (no compilation), keep Edit for potential report updates
4. **Context References** (lines 39-51):
   - Remove: `mode-selection.md` reference (line 46)
   - Remove: `project-timeline.typ` template reference (line 50)
   - Add: `return-metadata-file.md` to "Always Load" or keep in "Load for Output"
5. **Stage 1: Parse Delegation Context** (lines 75-94): Remove `"mode"` field from expected input
6. **Stage 8: Write Metadata File** (lines 668-706): Replace PLAN template with research template returning `"researched"` status
7. **Stage 9: Return Brief Text Summary** (lines 756-776): Update to research-focused summary
8. **Error Handling** (lines 800-886): Remove Typst compilation failure; keep invalid task, user abandons
9. **Critical Requirements** (lines 888-913): Update MUST DO/MUST NOT for research behavior

### New Section: Research Report Generation (replaces Typst Generation)

A new **Stage 6: Generate Research Report** must be added, replacing the Typst generation stages. This stage writes a markdown research report to `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` containing:

#### Report Structure

```markdown
# Project Research Report: {project_name}

## Project Definition
- **Name**: {from Q1}
- **Completion Criteria**: {from Q1}
- **Target Date**: {from Q2}
- **Stakeholders**: {from Q3}

## Work Breakdown Structure
{Hierarchical list from Stage 3 data}

### Phase: {phase_name}
- **Deliverable**: {noun from Q6}
- **Dependencies**: {from Q5}
- **Tasks**:
  1. {task_name} (depends on: {deps from Q8})
  2. ...

## PERT Estimates
{Table from Stage 4 data}

| Phase | Task | Optimistic | Likely | Pessimistic | Expected | Std Dev |
|-------|------|-----------|--------|-------------|----------|---------|
| ... | ... | ... | ... | ... | ... | ... |

**Project Totals**:
- Expected Duration: {E} {unit}
- 95% Confidence Interval: {ci_low} - {ci_high} {unit}

## Resource Allocation
{From Stage 5a data}

| Member | Role | Allocation | Assigned Tasks |
|--------|------|-----------|----------------|
| ... | ... | ... | ... |

## Critical Path Analysis
{From Stage 5b calculation}
- Critical path: {task1} -> {task2} -> ... -> {taskN}
- Critical path duration: {duration}
- Float for non-critical tasks: {summary}

## Overallocation Warnings
{From Stage 5b overallocation detection}

## Risk Register
- {Identified risks from dependencies, tight estimates, overallocations}

## Raw Data
{JSON blocks of WBS, PERT, and Resource data structures for consumption by planner-agent}
```

### Reference Pattern: market-agent.md

The market-agent at `.claude/extensions/founder/agents/market-agent.md` demonstrates the target pattern:

- **Output**: Research report at `specs/{NNN}/reports/01_{short-slug}.md` (not strategy output)
- **Status**: Returns `"researched"` in metadata
- **Separation**: "Final strategy output is generated separately by `founder-implement-agent`" (line 12)
- **Tools**: AskUserQuestion, Read, Write, Glob, WebSearch, Bash (verify only)
- **No compilation step**: Report is markdown, no PDF generation

Key structural parallels:
- Stage 0: Early metadata (identical pattern)
- Stage 1: Parse delegation context (no mode field)
- Stages 2-5: Forcing questions (domain-specific)
- Stage 6: Generate research report (markdown)
- Stage 7: Write report file
- Stage 8: Write metadata file (status: "researched")
- Stage 9: Return brief text summary

### Metadata Return Format

The metadata file should change from:

```json
{
  "status": "planned",
  "artifacts": [{"type": "timeline", "path": "strategy/timelines/{slug}.typ"}],
  "next_steps": "Review timeline and use TRACK mode to update progress"
}
```

To:

```json
{
  "status": "researched",
  "artifacts": [{"type": "report", "path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md"}],
  "next_steps": "Run /plan {N} to create implementation plan"
}
```

## Decisions

1. **Remove all three modes**: PLAN mode becomes the sole execution path (renamed to just "research"). TRACK and REPORT become separate operations handled during implementation phase.
2. **Preserve all forcing question logic**: The question sequences (Stages 3a-3c, 4, 5a) are the core value of this agent and remain unchanged.
3. **Preserve schedule calculation**: Forward/backward pass and critical path analysis (Stage 5b) remain in the research agent since these are analytical findings, not implementation artifacts.
4. **Include raw JSON data in report**: The WBS, PERT, and Resource data structures are included in a "Raw Data" section of the research report so that planner-agent can parse them during the planning phase.
5. **Remove Bash from allowed tools**: Without Typst compilation, Bash is only needed for `mkdir -p` and file verification, which Write/Glob can handle.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Planner-agent cannot parse raw data from markdown report | Medium | High | Use fenced JSON code blocks with clear section headers for reliable parsing |
| Removing TRACK/REPORT leaves no way to update timelines | Low | Medium | These become implementation-phase operations; document the future plan |
| skill-project routing may need updates for new status | Medium | Medium | Verify skill-project handles `"researched"` status correctly; may need follow-up task |
| Forcing question flow is tightly coupled to Typst output | Low | Low | Questions gather data into JSON structures (Stages 3c, 4, 5a); these are independent of output format |

## Implementation Checklist

The following changes are needed in `.claude/extensions/founder/agents/project-agent.md`:

1. [ ] Update frontmatter description: "Project research with WBS, PERT estimation, and resource analysis"
2. [ ] Rewrite Overview section: Single-mode research agent description
3. [ ] Update Agent Metadata: Purpose reflects research output
4. [ ] Modify Allowed Tools: Remove Bash, keep AskUserQuestion/Read/Write/Edit/Glob
5. [ ] Update Context References: Remove mode-selection.md and project-timeline.typ references
6. [ ] Modify Stage 1: Remove `"mode"` field from delegation context
7. [ ] Delete Stage 2 (Mode Selection): Entire section
8. [ ] Keep Stages 3a-3c, 4, 5a, 5b: No changes
9. [ ] Replace Stage 6 (Typst Generation): New "Generate Research Report" stage with markdown template
10. [ ] Delete Stage 7 (PDF Compilation): Entire section
11. [ ] Replace Stage 8 (Metadata): Single template with status `"researched"`
12. [ ] Replace Stage 9 (Summary): Single research-focused summary template
13. [ ] Delete TRACK Mode Execution: Entire section (Stages 3T-6T)
14. [ ] Delete REPORT Mode Execution: Entire section (Stages 3R-6R)
15. [ ] Update Error Handling: Remove Typst compilation failure, remove "No Existing Timeline" case
16. [ ] Update Critical Requirements: Remove Typst/PDF/mode-specific items; add report-specific items

**Estimated result**: ~550 lines (down from 913), with clearer single-purpose architecture.

## Appendix

### Search Queries Used
- Direct file reads: `project-agent.md`, `market-agent.md`
- Pattern comparison across founder extension agents

### Key Line References in project-agent.md
- Lines 10-15: Three-mode overview (to remove)
- Lines 96-123: Mode selection stage (to remove)
- Lines 401-528: TRACK + REPORT mode execution (to remove)
- Lines 530-666: Typst generation + PDF compilation (to remove)
- Lines 668-754: Three metadata templates (to consolidate)
- Lines 888-913: Critical requirements (to update)
