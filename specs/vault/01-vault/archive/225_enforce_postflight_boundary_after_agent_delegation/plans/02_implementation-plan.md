# Implementation Plan: Task #225

- **Task**: 225 - Enforce postflight boundary after agent delegation in skills
- **Status**: [COMPLETED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [01_postflight-boundary.md](../reports/01_postflight-boundary.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan implements enforcement of postflight boundary after agent delegation in skills. The research revealed 8 core skills and 6+ extension skills with overly permissive `allowed-tools` declarations that enable implementation work after agents return. The primary violation example is `skill-lean-implementation` with its "Zero-Debt Verification Gate" running `lake build` and `grep` after the agent completes.

The fix involves: (1) creating a standard document defining allowed vs prohibited operations, (2) updating agent templates to include verification, (3) adding MUST NOT sections to skills, (4) creating a lint script for enforcement.

### Research Integration

Key findings from `01_postflight-boundary.md`:
- 8 core skills + 6 extension skills have `allowed-tools: Task, Bash, Edit, Read, Write`
- Reference implementation (skill-researcher) correctly limits postflight to state-only operations
- Stage 6 "Zero-Debt Verification Gate" in skill-lean-implementation violates boundary
- Root cause: No phase separation enforcement between delegation and postflight

## Goals & Non-Goals

**Goals**:
- Create explicit postflight tool restriction standard
- Move verification gates from skills to agents
- Add MUST NOT boundary sections to all agent-delegating skills
- Create lint script for automated boundary violation detection
- Apply restrictions uniformly to core and extension skills

**Non-Goals**:
- Modifying non-agent-delegating skills (skill-refresh, skill-status-sync)
- Changing tool declarations in command files
- Adding runtime enforcement (lint-time only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking skill functionality | High | Medium | Verify agent includes all moved operations before skill update |
| Incomplete agent verification | Medium | Medium | Test each agent with sample task after update |
| Extension skills missed | Medium | Low | Systematic glob scan of all extension directories |
| Lint false positives | Low | Medium | Use specific patterns, allow manual review |

## Implementation Phases

### Phase 1: Create Postflight Tool Restriction Standard [COMPLETED]

**Goal**: Document the allowed vs prohibited operations during postflight phase.

**Tasks**:
- [ ] Create `.claude/context/core/standards/postflight-tool-restrictions.md`
- [ ] Define allowed tools table: Read (verify artifacts), Bash (jq, git, rm), Edit (specs/* only)
- [ ] Define prohibited tools table: Edit (non-specs), Write (non-specs), MCP tools, Bash (build commands)
- [ ] Add path restriction rules for Edit and Write
- [ ] Add examples of correct vs incorrect postflight operations
- [ ] Update `index.json` to include new standard file

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/core/standards/postflight-tool-restrictions.md` - Create new standard
- `.claude/context/index.json` - Add entry for new standard

**Verification**:
- Standard document exists with complete tables
- Index entry points to correct path

---

### Phase 2: Update Lean Implementation Agent [COMPLETED]

**Goal**: Move verification gate from skill-lean-implementation to lean-implementation-agent.

**Tasks**:
- [ ] Read current lean-implementation-agent definition
- [ ] Add "Final Verification Stage" at end of implementation flow
- [ ] Move sorry count check from skill Stage 6 to agent
- [ ] Move lake build verification from skill Stage 6 to agent
- [ ] Update metadata output to include verification_passed field
- [ ] Document verification failure should set status to "partial"
- [ ] Verify agent produces correct metadata with verification results

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/lean/agents/lean-implementation-agent/AGENT.md` - Add verification stage

**Verification**:
- Agent has Final Verification Stage with sorry check and lake build
- Agent sets status="partial" on verification failure
- Metadata includes verification_passed field

---

### Phase 3: Update skill-lean-implementation Postflight [COMPLETED]

**Goal**: Remove verification gate from skill and add MUST NOT section.

**Tasks**:
- [ ] Remove Stage 6 "Zero-Debt Verification Gate" from skill
- [ ] Renumber remaining stages (7->6, 8->7, etc.)
- [ ] Add MUST NOT section with postflight boundary rules
- [ ] Update Stage 6 (formerly Stage 7) to read verification_passed from metadata
- [ ] Keep status logic but based on metadata, not re-verification
- [ ] Test skill correctly reads agent verification result

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Remove verification, add MUST NOT

**Verification**:
- No lake build or grep commands in skill postflight
- MUST NOT section present
- Status logic reads from metadata not re-runs verification

---

### Phase 4: Update Core Skills with MUST NOT Sections [COMPLETED]

**Goal**: Add postflight boundary MUST NOT section to all 8 core agent-delegating skills.

**Tasks**:
- [ ] Update skill-researcher with MUST NOT section
- [ ] Update skill-planner with MUST NOT section
- [ ] Update skill-implementer with MUST NOT section
- [ ] Update skill-meta with MUST NOT section
- [ ] Update skill-team-research with MUST NOT section
- [ ] Update skill-team-plan with MUST NOT section
- [ ] Update skill-team-implement with MUST NOT section
- [ ] Update skill-orchestrator with MUST NOT section (if applicable)
- [ ] Verify each skill references postflight-tool-restrictions.md standard

**Timing**: 1 hour

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-planner/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-implementer/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-meta/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-team-research/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-team-plan/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-team-implement/SKILL.md` - Add MUST NOT section
- `.claude/skills/skill-orchestrator/SKILL.md` - Add MUST NOT section (if needed)

**Verification**:
- All 8 core skills have MUST NOT section
- Each references postflight-tool-restrictions.md

---

### Phase 5: Update Extension Skills with MUST NOT Sections [COMPLETED]

**Goal**: Add postflight boundary MUST NOT section to extension implementation skills.

**Tasks**:
- [ ] Glob for all extension implementation skills
- [ ] Update skill-neovim-implementation with MUST NOT section
- [ ] Update skill-latex-implementation with MUST NOT section
- [ ] Update skill-typst-implementation with MUST NOT section
- [ ] Update skill-python-implementation with MUST NOT section
- [ ] Update skill-web-implementation with MUST NOT section
- [ ] Update skill-nix-implementation with MUST NOT section
- [ ] Update skill-z3-implementation with MUST NOT section
- [ ] Update skill-epidemiology-implementation with MUST NOT section
- [ ] Check extension research skills (already state-only, may not need update)

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- `.claude/extensions/latex/skills/skill-latex-implementation/SKILL.md`
- `.claude/extensions/typst/skills/skill-typst-implementation/SKILL.md`
- `.claude/extensions/python/skills/skill-python-implementation/SKILL.md`
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.claude/extensions/z3/skills/skill-z3-implementation/SKILL.md`
- `.claude/extensions/epidemiology/skills/skill-epidemiology-implementation/SKILL.md`

**Verification**:
- All extension implementation skills have MUST NOT section
- Each references postflight-tool-restrictions.md

---

### Phase 6: Create Lint Script for Boundary Violations [COMPLETED]

**Goal**: Create automated detection of postflight boundary violations.

**Tasks**:
- [ ] Create `.claude/scripts/lint/lint-postflight-boundary.sh`
- [ ] Detect patterns: Edit on source files after "Stage [5-9]" or "postflight"
- [ ] Detect patterns: lake/nvim/build commands after delegation
- [ ] Detect patterns: MCP tool references after Stage 5
- [ ] Support both core skills and extension skills paths
- [ ] Output violation count with file paths
- [ ] Exit with error code if violations found
- [ ] Add to validate-all-standards.sh under --postflight category

**Timing**: 45 minutes

**Files to modify**:
- `.claude/scripts/lint/lint-postflight-boundary.sh` - Create new script
- `.claude/scripts/validate-all-standards.sh` - Add --postflight category

**Verification**:
- Script runs successfully on clean codebase (0 violations)
- Script detects intentional violation in test file
- validate-all-standards.sh includes --postflight option

---

### Phase 7: Documentation and Testing [COMPLETED]

**Goal**: Update documentation references and verify all changes work together.

**Tasks**:
- [ ] Update thin-wrapper-skill.md to reference postflight-tool-restrictions.md
- [ ] Update skill-lifecycle.md to reference postflight-tool-restrictions.md
- [ ] Run lint-postflight-boundary.sh on all skills (expect 0 violations)
- [ ] Test skill-lean-implementation with sample task to verify no regression
- [ ] Update command-authoring.md if needed
- [ ] Create implementation summary

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/core/patterns/thin-wrapper-skill.md` - Add reference
- `.claude/context/core/patterns/skill-lifecycle.md` - Add reference
- `specs/225_enforce_postflight_boundary_after_agent_delegation/summaries/03_postflight-boundary-summary.md` - Create summary

**Verification**:
- All documentation cross-references correct
- Lint script reports 0 violations
- No regression in skill functionality

## Testing & Validation

- [ ] `lint-postflight-boundary.sh` reports 0 violations across all skills
- [ ] `validate-all-standards.sh --postflight` passes
- [ ] Manual review confirms all MUST NOT sections are consistent
- [ ] skill-lean-implementation reads verification status from metadata (not re-runs)
- [ ] lean-implementation-agent includes Final Verification Stage with lake build

## Artifacts & Outputs

- `.claude/context/core/standards/postflight-tool-restrictions.md` - New standard document
- `.claude/scripts/lint/lint-postflight-boundary.sh` - New lint script
- Updated SKILL.md files (8 core + 8 extension = 16 files)
- Updated lean-implementation-agent AGENT.md
- Updated documentation files (thin-wrapper-skill.md, skill-lifecycle.md)
- Implementation summary at `specs/225_enforce_postflight_boundary_after_agent_delegation/summaries/03_postflight-boundary-summary.md`

## Rollback/Contingency

If implementation causes issues:
1. Revert SKILL.md changes via git - skills are documentation-only, no runtime impact
2. Revert agent changes if verification fails - restore previous verification logic
3. Remove lint script from validate-all-standards.sh if false positives

The changes are primarily documentation and lint enforcement - no runtime code is modified, making rollback straightforward via git revert.
