# Implementation Plan: Revise /grant Command Design

- **Task**: 215 - Revise grant command design
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: Research analysis of hybrid design approach
- **Artifacts**: plans/02_grant-command-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan implements the hybrid design (Option C) for the /grant command. The core insight is that /grant should work like /task for task creation (setting language="grant"), then leverage existing /research and /plan commands through language-based routing. The /grant command retains grant-specific flags (--draft, --budget, --finish) for specialized workflows not covered by the core command suite.

### Research Integration

Key findings from research analysis:
- **Option A (Extend /task)**: Simple but loses grant-specific UX
- **Option B (Grant Orchestrator)**: Powerful but creates redundancy with /research, /plan, /implement
- **Option C (Hybrid)**: Task creation mode + grant-specific flags + core command routing = optimal balance

## Goals & Non-Goals

**Goals**:
- Enable `/grant "Description"` to create tasks with language="grant" (mirroring /task)
- Route /research and /plan to skill-grant when language="grant"
- Add --draft flag for narrative drafting workflow
- Add --budget flag for budget development workflow
- Add --finish flag for final export to submission directory
- Maintain backward compatibility with existing workflow_type syntax during transition

**Non-Goals**:
- Duplicating /research, /plan, /implement functionality within /grant
- Creating new status markers beyond existing grant workflow markers
- Implementing progress tracking (--progress) in this iteration

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing /grant workflows | High | Medium | Maintain backward compatibility for workflow_type syntax |
| Language routing conflicts | Medium | Low | Ensure manifest.json routing entries are correct |
| Status transition confusion | Medium | Medium | Document clear status transitions for each mode |

## Implementation Phases

### Phase 1: Add Task Creation Mode to /grant [NOT STARTED]

**Goal**: Enable `/grant "Description"` to create tasks with language="grant"

**Tasks**:
- [ ] Read and understand current /grant command structure
- [ ] Add mode detection logic to differentiate between task creation and workflow execution
- [ ] Implement task creation mode mirroring /task command:
  - Parse description from $ARGUMENTS
  - Improve description (slug expansion, verb inference)
  - Create slug from description
  - Update state.json with new task (language="grant")
  - Update TODO.md frontmatter and add task entry
  - Git commit with standard format
- [ ] Test task creation mode with various descriptions

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add task creation mode

**Verification**:
- `/grant "Research NIH R01 funding for AI project"` creates task with language="grant"
- state.json shows new task with correct language
- TODO.md shows new task entry

---

### Phase 2: Add --draft Flag for Narrative Drafting [NOT STARTED]

**Goal**: Enable `/grant N --draft` for narrative section drafting

**Tasks**:
- [ ] Add --draft flag parsing to mode detection
- [ ] Map --draft to proposal_draft workflow internally
- [ ] Update argument-hint to include --draft syntax
- [ ] Add documentation for --draft usage
- [ ] Ensure status transitions: [RESEARCHED] -> [PLANNING] -> [PLANNED]

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add --draft flag handling

**Verification**:
- `/grant 500 --draft` invokes proposal_draft workflow
- Output indicates "Draft created" with artifact path

---

### Phase 3: Add --budget Flag for Budget Development [NOT STARTED]

**Goal**: Enable `/grant N --budget` for line-item budget development

**Tasks**:
- [ ] Add --budget flag parsing to mode detection
- [ ] Map --budget to budget_develop workflow internally
- [ ] Update argument-hint to include --budget syntax
- [ ] Add documentation for --budget usage
- [ ] Ensure status transitions: [RESEARCHED] -> [PLANNING] -> [PLANNED]

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add --budget flag handling

**Verification**:
- `/grant 500 --budget` invokes budget_develop workflow
- Output indicates "Budget developed" with artifact path

---

### Phase 4: Add --finish Flag for Export [NOT STARTED]

**Goal**: Enable `/grant N --finish PATH` to export completed grant to submission directory

**Tasks**:
- [ ] Add --finish flag parsing with required PATH argument
- [ ] Design export workflow:
  - Collect all grant artifacts (reports, drafts, budgets)
  - Validate all required sections are complete
  - Copy/generate final documents to specified PATH
  - Create submission checklist if needed
- [ ] Implement export logic in skill-grant
- [ ] Add documentation for --finish usage

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add --finish flag handling
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Add finish workflow stage

**Verification**:
- `/grant 500 --finish ~/submissions/NIH_R01/` exports grant materials
- Output lists exported files and validates completeness

---

### Phase 5: Update Extension Routing [NOT STARTED]

**Goal**: Ensure /research and /plan route correctly for language="grant" tasks

**Tasks**:
- [ ] Verify manifest.json has correct routing entries
- [ ] Update EXTENSION.md Language Routing table if needed
- [ ] Verify skill-grant is invoked by /research when language="grant"
- [ ] Verify skill-grant is invoked by /plan when language="grant"
- [ ] Test end-to-end workflow: /grant "Desc" -> /research N -> /plan N

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Verify/update routing
- `.claude/extensions/present/EXTENSION.md` - Update routing documentation

**Verification**:
- `/research 500` (with language="grant") routes to skill-grant
- `/plan 500` (with language="grant") routes to skill-grant
- End-to-end workflow completes without manual routing

---

### Phase 6: Update Documentation [NOT STARTED]

**Goal**: Update EXTENSION.md with complete revised /grant command documentation

**Tasks**:
- [ ] Document task creation mode syntax and examples
- [ ] Document --draft flag with examples
- [ ] Document --budget flag with examples
- [ ] Document --finish flag with examples
- [ ] Document recommended workflow:
  1. `/grant "Description"` - Create grant task
  2. `/research N` - Research funders (routes to skill-grant)
  3. `/plan N` - Plan proposal (routes to skill-grant)
  4. `/grant N --draft` - Draft narrative sections
  5. `/grant N --budget` - Develop budget
  6. `/grant N --finish PATH` - Export for submission
- [ ] Update Language Routing table
- [ ] Update Skill-Agent Mapping table if needed

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Complete documentation update

**Verification**:
- EXTENSION.md contains complete /grant command reference
- Examples cover all modes and flags
- Workflow documentation is clear and actionable

---

### Phase 7: Verification and Testing [NOT STARTED]

**Goal**: Verify all changes work correctly end-to-end

**Tasks**:
- [ ] Test task creation mode:
  - `/grant "Research NSF CAREER funding"` creates task correctly
  - Task has language="grant" in state.json
- [ ] Test core command routing:
  - `/research N` routes to skill-grant for grant tasks
  - `/plan N` routes to skill-grant for grant tasks
- [ ] Test grant-specific flags:
  - `/grant N --draft` creates narrative draft
  - `/grant N --budget` creates line-item budget
  - `/grant N --finish PATH` exports materials
- [ ] Test backward compatibility:
  - `/grant N funder_research` still works (deprecated but supported)
- [ ] Verify git commits follow conventions

**Timing**: 30 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- All test cases pass
- No regressions in existing functionality

## Testing & Validation

- [ ] Task creation mode creates task with language="grant"
- [ ] /research N routes correctly for grant tasks
- [ ] /plan N routes correctly for grant tasks
- [ ] --draft flag triggers proposal_draft workflow
- [ ] --budget flag triggers budget_develop workflow
- [ ] --finish flag exports to specified path
- [ ] Backward compatibility: workflow_type syntax still works
- [ ] Git commits follow task conventions

## Artifacts & Outputs

- plans/02_grant-command-plan.md (this file)
- Modified: `.claude/extensions/present/commands/grant.md`
- Modified: `.claude/extensions/present/skills/skill-grant/SKILL.md`
- Modified: `.claude/extensions/present/EXTENSION.md`
- Possibly modified: `.claude/extensions/present/manifest.json`

## Rollback/Contingency

If implementation fails:
1. Revert command changes: `git checkout .claude/extensions/present/commands/grant.md`
2. Revert skill changes: `git checkout .claude/extensions/present/skills/skill-grant/SKILL.md`
3. Revert documentation: `git checkout .claude/extensions/present/EXTENSION.md`
4. Existing /grant workflows remain functional
