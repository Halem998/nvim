# Implementation Plan: Revise /grant Command Design (v3)

- **Task**: 215 - Revise grant command design
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: Research analysis of hybrid design approach
- **Artifacts**: plans/03_grant-command-plan.md (this file, revised from v2)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Revision Summary

**Changes from v2**: Added optional prompt parameter to --draft, --budget, and --finish flags. This allows users to provide specific guidance for each operation, similar to how /research accepts an optional focus prompt.

**New syntax**:
- `/grant N --draft ["optional prompt for drafting focus"]`
- `/grant N --budget ["optional prompt for budget guidance"]`
- `/grant N --finish PATH ["optional prompt for export customization"]`

## Overview

This plan implements the hybrid design (Option C) for the /grant command. The core insight is that /grant should work like /task for task creation (setting language="grant"), then leverage existing /research and /plan commands through language-based routing. The /grant command retains grant-specific flags (--draft, --budget, --finish) for specialized workflows not covered by the core command suite.

**Key Enhancement (v3)**: Each grant-specific flag accepts an optional prompt parameter to provide contextual guidance for that operation, enabling more targeted outputs.

### Research Integration

Key findings from research analysis:
- **Option A (Extend /task)**: Simple but loses grant-specific UX
- **Option B (Grant Orchestrator)**: Powerful but creates redundancy with /research, /plan, /implement
- **Option C (Hybrid)**: Task creation mode + grant-specific flags + core command routing = optimal balance

## Goals & Non-Goals

**Goals**:
- Enable `/grant "Description"` to create tasks with language="grant" (mirroring /task)
- Route /research and /plan to skill-grant when language="grant"
- Add --draft flag with optional prompt for narrative drafting workflow
- Add --budget flag with optional prompt for budget development workflow
- Add --finish flag with required PATH and optional prompt for final export
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
| Prompt parsing complexity | Low | Medium | Use clear delimiter patterns for optional prompts |

## Implementation Phases

### Phase 1: Add Task Creation Mode to /grant [COMPLETED]

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

### Phase 2: Add --draft Flag with Optional Prompt [COMPLETED]

**Goal**: Enable `/grant N --draft ["optional prompt"]` for narrative section drafting

**Tasks**:
- [ ] Add --draft flag parsing to mode detection
- [ ] Implement optional prompt capture after --draft flag:
  - If quoted text follows --draft, capture as drafting focus
  - If no text, use default drafting behavior
- [ ] Map --draft to proposal_draft workflow, passing prompt to skill-grant
- [ ] Update skill-grant to accept and use drafting prompt
- [ ] Update argument-hint to include --draft syntax with optional prompt
- [ ] Add documentation for --draft usage with examples

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add --draft flag handling with prompt
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Accept prompt parameter

**Verification**:
- `/grant 500 --draft` invokes proposal_draft workflow with default behavior
- `/grant 500 --draft "Focus on methodology section"` passes prompt to skill
- Output indicates "Draft created" with artifact path

**Examples**:
```bash
/grant 500 --draft                                    # Default drafting
/grant 500 --draft "Focus on innovation and impact"  # Guided drafting
/grant 500 --draft "Expand the methodology section with more detail on experimental design"
```

---

### Phase 3: Add --budget Flag with Optional Prompt [COMPLETED]

**Goal**: Enable `/grant N --budget ["optional prompt"]` for line-item budget development

**Tasks**:
- [ ] Add --budget flag parsing to mode detection
- [ ] Implement optional prompt capture after --budget flag:
  - If quoted text follows --budget, capture as budget focus
  - If no text, use default budget template
- [ ] Map --budget to budget_develop workflow, passing prompt to skill-grant
- [ ] Update skill-grant to accept and use budget prompt
- [ ] Update argument-hint to include --budget syntax with optional prompt
- [ ] Add documentation for --budget usage with examples

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add --budget flag handling with prompt
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Accept prompt parameter

**Verification**:
- `/grant 500 --budget` invokes budget_develop workflow with default behavior
- `/grant 500 --budget "Emphasize equipment costs"` passes prompt to skill
- Output indicates "Budget developed" with artifact path

**Examples**:
```bash
/grant 500 --budget                                   # Default budget development
/grant 500 --budget "Include travel for 3 conferences per year"
/grant 500 --budget "Focus on personnel costs, minimize equipment requests"
```

---

### Phase 4: Add --finish Flag with PATH and Optional Prompt [COMPLETED]

**Goal**: Enable `/grant N --finish PATH ["optional prompt"]` to export completed grant

**Tasks**:
- [ ] Add --finish flag parsing with required PATH argument
- [ ] Implement optional prompt capture after PATH:
  - PATH is required (first argument after --finish)
  - Optional quoted text after PATH provides export customization
- [ ] Design export workflow:
  - Collect all grant artifacts (reports, drafts, budgets)
  - Validate all required sections are complete
  - Apply prompt-based customization (if provided)
  - Copy/generate final documents to specified PATH
  - Create submission checklist if needed
- [ ] Implement export logic in skill-grant
- [ ] Add documentation for --finish usage with examples

**Timing**: 50 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add --finish flag handling with prompt
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Add finish workflow stage with prompt

**Verification**:
- `/grant 500 --finish ~/submissions/NIH_R01/` exports grant materials
- `/grant 500 --finish ~/submissions/ "Generate PDF compilation"` applies customization
- Output lists exported files and validates completeness

**Examples**:
```bash
/grant 500 --finish ~/grants/NSF_CAREER/                           # Default export
/grant 500 --finish ~/grants/NSF_CAREER/ "Compile as single PDF"   # Custom export
/grant 500 --finish ~/submissions/ "Include only narrative and budget, exclude appendices"
```

---

### Phase 5: Update Extension Routing [COMPLETED]

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

### Phase 6: Update Documentation [COMPLETED]

**Goal**: Update EXTENSION.md with complete revised /grant command documentation

**Tasks**:
- [ ] Document task creation mode syntax and examples
- [ ] Document --draft flag with optional prompt examples
- [ ] Document --budget flag with optional prompt examples
- [ ] Document --finish flag with PATH and optional prompt examples
- [ ] Document recommended workflow:
  1. `/grant "Description"` - Create grant task
  2. `/research N ["focus"]` - Research funders (routes to skill-grant)
  3. `/plan N` - Plan proposal (routes to skill-grant)
  4. `/grant N --draft ["prompt"]` - Draft narrative sections
  5. `/grant N --budget ["prompt"]` - Develop budget
  6. `/grant N --finish PATH ["prompt"]` - Export for submission
- [ ] Update Language Routing table
- [ ] Update Skill-Agent Mapping table if needed

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Complete documentation update

**Verification**:
- EXTENSION.md contains complete /grant command reference
- Examples cover all modes, flags, and optional prompts
- Workflow documentation is clear and actionable

---

### Phase 7: Verification and Testing [COMPLETED]

**Goal**: Verify all changes work correctly end-to-end

**Tasks**:
- [ ] Test task creation mode:
  - `/grant "Research NSF CAREER funding"` creates task correctly
  - Task has language="grant" in state.json
- [ ] Test core command routing:
  - `/research N` routes to skill-grant for grant tasks
  - `/plan N` routes to skill-grant for grant tasks
- [ ] Test grant-specific flags without prompts:
  - `/grant N --draft` creates narrative draft with defaults
  - `/grant N --budget` creates line-item budget with defaults
  - `/grant N --finish PATH` exports materials with defaults
- [ ] Test grant-specific flags WITH prompts:
  - `/grant N --draft "Focus on innovation"` uses prompt
  - `/grant N --budget "Emphasize personnel"` uses prompt
  - `/grant N --finish PATH "Compile as PDF"` uses prompt
- [ ] Test backward compatibility:
  - `/grant N funder_research` still works (deprecated but supported)
- [ ] Verify git commits follow conventions

**Timing**: 35 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- All test cases pass
- Optional prompts are correctly passed to skill-grant
- No regressions in existing functionality

## Testing & Validation

- [ ] Task creation mode creates task with language="grant"
- [ ] /research N routes correctly for grant tasks
- [ ] /plan N routes correctly for grant tasks
- [ ] --draft flag works without prompt (default behavior)
- [ ] --draft flag works with prompt (custom behavior)
- [ ] --budget flag works without prompt (default behavior)
- [ ] --budget flag works with prompt (custom behavior)
- [ ] --finish flag works without prompt (default export)
- [ ] --finish flag works with prompt (custom export)
- [ ] Backward compatibility: workflow_type syntax still works
- [ ] Git commits follow task conventions

## Artifacts & Outputs

- plans/03_grant-command-plan.md (this file, revised from v2)
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
