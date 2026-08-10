# Implementation Plan: Add generic/edit task_type fallback to founder-plan-agent

- **Task**: 334 - Add generic/edit task_type fallback to founder-plan-agent
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/01_generic-fallback.md
- **Artifacts**: plans/01_generic-fallback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Add a generic/edit fallback path to founder-plan-agent.md so that tasks which do not match any specialized template (market-sizing, competitive-analysis, gtm-strategy, contract-review, project-timeline, cost-breakdown) receive a structured plan conforming to plan-format.md rather than an improvised free-form plan. The change touches Stage 4 (type routing) and Stage 5 (phase structure) of the agent definition, plus Critical Requirement #6.

### Research Integration

**Research Report**: [01_generic-fallback.md](../reports/01_generic-fallback.md)

**Key Findings**: The agent has no fallback when task_type is null or unrecognized, defaulting to market-sizing which is incorrect for edit/maintenance tasks. The generic fallback should use variable phase counts (1-3 task-specific phases) and conditionally include report/PDF phases only when the task produces a document.

## Goals & Non-Goals

**Goals**:
- Add `generic` entry to Stage 4 task_type and keyword tables
- Replace "default to market-sizing" with "default to generic"
- Add Generic/Edit phase structure to Stage 5
- Update Critical Requirement #6 to allow variable phase counts for generic type

**Non-Goals**:
- Adding cost-breakdown phase structure (separate concern)
- Modifying existing specialized phase structures
- Changing the research agent or skill routing

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent edits from task 333 | Medium | High | Use content-based Edit operations, re-read file before each edit |
| Generic type too vague for agent to follow | Low | Low | Provide clear examples and decision criteria for phase generation |

## Implementation Phases

### Phase 1: Update Stage 4 Type Routing [COMPLETED]

**Goal**: Add generic entry to task_type lookup and change default fallback from market-sizing to generic

**Tasks**:
- [ ] Add `generic | generic | (none)` row to the primary task_type table in Stage 4
- [ ] Add generic keywords to the keyword fallback table: `edit, update, fix, configure, replace, rename, refactor, maintain, cleanup, setup`
- [ ] Change "Default to market-sizing if unclear" to "Default to generic if unclear"

**Timing**: 15 minutes

### Phase 2: Add Generic/Edit Phase Structure to Stage 5 [COMPLETED]

**Goal**: Add a Generic/Edit section after the Project Timeline section with flexible phase structure

**Tasks**:
- [ ] Add "Generic/Edit:" section header with introductory guidance
- [ ] Define Phase 1-3 as task-scope-dependent (agent generates phases from research report context)
- [ ] Document conditional inclusion of Phase 4 (Report/Typst) and Phase 5 (PDF) -- include only when the task produces a deliverable report
- [ ] Add guidance note explaining that edit/maintenance tasks should have 1-3 phases only

**Timing**: 20 minutes

### Phase 3: Update Critical Requirements and Metadata [COMPLETED]

**Goal**: Amend Critical Requirement #6 and metadata to accommodate variable phase counts for generic type

**Tasks**:
- [ ] Update Critical Requirement #6 to note that generic type uses 1-5 phases (variable based on scope)
- [ ] Add `generic` to the report_type list in Stage 7 metadata schema
- [ ] Update the Overview section to include "generic/edit" in the parenthetical list of task types
- [ ] Verify consistency across all changed sections

**Timing**: 10 minutes

## Testing & Validation

- [ ] Verify Stage 4 table includes generic row
- [ ] Verify keyword fallback table includes generic keywords
- [ ] Verify default changed from market-sizing to generic
- [ ] Verify Generic/Edit phase structure follows plan-format.md conventions
- [ ] Verify Critical Requirement #6 updated
- [ ] Read full file end-to-end to check no structural damage

## Artifacts & Outputs

- plans/01_generic-fallback.md (this plan)
- `.claude/extensions/founder/agents/founder-plan-agent.md` (modified)

## Rollback/Contingency

If edits cause structural damage to founder-plan-agent.md:
1. Use `git checkout -- .claude/extensions/founder/agents/founder-plan-agent.md` to restore
2. Re-read the file fresh and retry with smaller, more targeted edits
