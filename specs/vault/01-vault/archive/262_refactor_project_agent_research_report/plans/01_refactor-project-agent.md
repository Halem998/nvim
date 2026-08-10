# Implementation Plan: Refactor project-agent to generate research report

- **Task**: 262 - Refactor project-agent to generate research report instead of timeline
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/262_refactor_project_agent_research_report/reports/01_meta-research.md
- **Artifacts**: plans/01_refactor-project-agent.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Refactor `.claude/extensions/founder/agents/project-agent.md` (912 lines) from a monolithic three-mode agent (PLAN/TRACK/REPORT) that generates Typst timelines into a single-purpose research agent that outputs markdown reports. The core forcing question logic (Stages 3a-3c, 4, 5a, 5b) is preserved intact; approximately 400 lines of mode selection, TRACK/REPORT execution, Typst generation, and PDF compilation are removed. A new Stage 6 generates a structured markdown research report containing WBS, PERT, resource, and critical path data. The result is a ~550-line agent matching the pattern used by market-agent and other founder research agents.

### Research Integration

Key findings from 01_meta-research.md:
- Lines 96-123 (Mode Selection), 401-528 (TRACK/REPORT), 530-666 (Typst/PDF) are removal targets
- Stages 3a-3c, 4, 5a, 5b (forcing questions + schedule calculation) are preserved unchanged
- market-agent.md provides the reference pattern for research-only output
- Raw JSON data must be included in the report for planner-agent consumption

## Goals & Non-Goals

**Goals**:
- Transform project-agent into a research-only agent returning status "researched"
- Preserve all forcing question logic and PERT/CPM calculation stages
- Add markdown research report generation replacing Typst output
- Include raw JSON data blocks in report for downstream planner-agent parsing
- Match the structural pattern of market-agent.md

**Non-Goals**:
- Creating a plan-agent or implementation-agent for timeline generation (tasks 266, 267)
- Modifying skill-project routing (task 263)
- Changing the forcing question content or estimation methodology

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Planner-agent cannot parse raw data from markdown | High | Medium | Use fenced JSON code blocks with clear section headers |
| Removing sections breaks stage numbering continuity | Low | Medium | Renumber stages sequentially during rewrite |
| TRACK/REPORT removal leaves gap in project workflow | Medium | Low | Document as future work in tasks 266-267 |

## Implementation Phases

### Phase 1: Remove mode handling and TRACK/REPORT sections [IN PROGRESS]

**Goal**: Strip the multi-mode architecture, leaving only the PLAN-mode research path.

**Tasks**:
- [ ] Update frontmatter description to: "Project research with WBS, PERT estimation, and resource analysis"
- [ ] Rewrite Overview section (lines 8-16): Remove three-mode description, describe as research agent that gathers project data through forcing questions and outputs a research report
- [ ] Update Agent Metadata (lines 18-24): Change purpose to "Project research with WBS and PERT estimation", update return format to "Brief text summary + metadata file"
- [ ] Modify Allowed Tools (lines 26-37): Remove Bash (no Typst compilation needed), keep AskUserQuestion, Read, Write, Edit, Glob
- [ ] Update Context References (lines 39-51): Remove `mode-selection.md` reference (line 46), remove `project-timeline.typ` template reference (line 50), ensure `return-metadata-file.md` is in "Load for Output"
- [ ] Modify Stage 1 (lines 75-94): Remove `"mode"` field from expected delegation context JSON
- [ ] Delete Stage 2: Mode Selection (lines 96-123): Remove entire section
- [ ] Delete TRACK Mode Execution (lines 401-470): Remove Stages 3T-6T entirely
- [ ] Delete REPORT Mode Execution (lines 472-528): Remove Stages 3R-6R entirely
- [ ] Remove "PLAN Mode Execution" heading (line 127): Stages 3a-5b become the main execution flow without a mode qualifier

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Remove ~270 lines of mode/TRACK/REPORT content

**Verification**:
- No references to "PLAN mode", "TRACK mode", or "REPORT mode" remain in the file
- No references to `mode-selection.md` remain
- Stages 3a through 5b remain intact and unchanged
- The `"mode"` field is absent from Stage 1 delegation context

---

### Phase 2: Remove Typst generation and PDF compilation [NOT STARTED]

**Goal**: Strip all Typst template code and PDF compilation logic.

**Tasks**:
- [ ] Delete Stage 6/6T/6R: Typst Generation (lines 530-637): Remove all Typst template code, color definitions, function inlining strategy, output path conventions
- [ ] Delete Stage 7: PDF Compilation (lines 640-666): Remove typst compile command and error handling
- [ ] Remove Typst compilation failure error case from Error Handling section (lines 845-865)
- [ ] Remove "No Existing Timeline" error case if present (TRACK-specific)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Remove ~150 lines of Typst/PDF content

**Verification**:
- No references to "Typst", "typst", ".typ", or "PDF compilation" remain
- No references to `project-timeline.typ` template remain
- Error Handling section has no Typst-specific cases

---

### Phase 3: Add research report generation stage [NOT STARTED]

**Goal**: Replace Typst output with a new Stage 6 that generates a structured markdown research report.

**Tasks**:
- [ ] Create new Stage 6: Generate Research Report section after Stage 5b
- [ ] Define report output path as `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
- [ ] Include report template with these sections:
  - Project Definition (from Q1-Q3 data)
  - Work Breakdown Structure (hierarchical list from Stage 3 data)
  - PERT Estimates table (from Stage 4 data with project totals and confidence interval)
  - Resource Allocation table (from Stage 5a data)
  - Critical Path Analysis (from Stage 5b calculation)
  - Overallocation Warnings (from Stage 5b detection)
  - Risk Register (derived from dependencies, tight estimates, overallocations)
  - Raw Data section with fenced JSON blocks of WBS, PERT, and Resource data structures
- [ ] Add instruction for agent to use Write tool to create the report file
- [ ] Include directory creation guardrail: `mkdir -p` equivalent via Write tool path

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Add ~80 lines for report generation stage

**Verification**:
- Stage 6 references all data gathered in Stages 3-5
- Report template includes Raw Data section with JSON code blocks
- Output path follows artifact naming convention (specs/{NNN}_{SLUG}/reports/)

---

### Phase 4: Update metadata, summary, and critical requirements [NOT STARTED]

**Goal**: Replace multi-mode metadata templates with a single research-focused template and update all downstream sections.

**Tasks**:
- [ ] Replace Stage 8 metadata section (lines 668-754): Remove PLAN/TRACK/REPORT templates, add single template with status "researched", artifact type "report", and next_steps "Run /plan {N} to create implementation plan"
- [ ] Replace Stage 9 summary section (lines 756-798): Remove TRACK/REPORT summary examples, add single research-focused summary template showing project name, phase count, PERT duration, critical path, and report path
- [ ] Update Error Handling section (lines 800-886): Keep "Invalid Task", "User Abandons Questions", "File Operation Failure" cases; remove Typst-specific and TRACK-specific error cases
- [ ] Update Critical Requirements MUST DO list (lines 888-913): Replace Typst/PDF/mode items with research report items (verify report file exists, include raw data, use "researched" status)
- [ ] Update Critical Requirements MUST NOT list: Remove Typst/mode-specific prohibitions, add research-specific ones (do not generate Typst, do not skip raw data section, do not return "planned" status)
- [ ] Renumber all stages sequentially (0 through 8) to maintain clean flow after deletions

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/project-agent.md` - Modify ~100 lines across metadata, summary, error, and requirements sections

**Verification**:
- Only one metadata template exists with status "researched"
- Only one summary template exists (research-focused)
- No references to "planned", "tracked", or "reported" status values
- Stages numbered sequentially 0-8 without gaps
- MUST DO/MUST NOT lists reference research report behavior only
- Final file is approximately 500-560 lines

## Testing & Validation

- [ ] Verify final line count is in 500-560 range (down from 912)
- [ ] Search for orphaned references: "TRACK", "REPORT", "Typst", "typst", ".typ", "PDF", "mode"
- [ ] Verify all stage numbers are sequential (0 through 8)
- [ ] Verify metadata template returns status "researched" (not "planned")
- [ ] Verify forcing question stages (3a-3c, 4, 5a, 5b) are unchanged from original
- [ ] Verify report template includes Raw Data section with JSON code blocks
- [ ] Verify Context References section no longer references mode-selection.md or project-timeline.typ
- [ ] Verify Allowed Tools section does not include Bash

## Artifacts & Outputs

- `.claude/extensions/founder/agents/project-agent.md` - Refactored research-only agent (~550 lines)
- `specs/262_refactor_project_agent_research_report/plans/01_refactor-project-agent.md` - This plan
- `specs/262_refactor_project_agent_research_report/summaries/01_refactor-project-agent-summary.md` - Execution summary (post-implementation)

## Rollback/Contingency

The original `project-agent.md` is version-controlled in git. If the refactoring introduces issues:
1. `git checkout HEAD -- .claude/extensions/founder/agents/project-agent.md` restores the original
2. Downstream tasks (263, 266, 267) depend on this refactoring; rollback would block them
3. Each phase produces a coherent intermediate state, so partial rollback to any phase boundary is viable
