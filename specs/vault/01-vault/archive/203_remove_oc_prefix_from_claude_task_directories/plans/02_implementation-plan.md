# Implementation Plan: Task #203

- **Task**: 203 - Remove OC_ prefix from .claude/ system task directory creation
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [01_oc-prefix-removal.md](../reports/01_oc-prefix-removal.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Remove the OC_ prefix from all .claude/ system files that incorrectly reference it for task directory creation. Task 194 applied OC_ standardization too broadly, affecting both .opencode/ (correct) and .claude/ (incorrect) systems. This plan reverts .claude/ files to use plain `{NNN}_{SLUG}` format while preserving .opencode/ OC_ usage. The work involves 44 files across core skills/agents, commands, context documentation, and extensions.

### Research Integration

The research report identified:
- **44 files** in .claude/ requiring changes
- **59 files** in .opencode/ that should remain unchanged
- Clear pattern replacements: `OC_{NNN}_{SLUG}` -> `{NNN}_{SLUG}`, `OC_${padded_num}` -> `${padded_num}`
- skill-todo requires special handling to scan both formats during transition

## Goals & Non-Goals

**Goals**:
- Remove OC_ prefix from all .claude/ task directory creation patterns
- Update path templates and header displays in .claude/ files
- Add documentation clarifying the distinction between .claude/ and .opencode/ naming
- Ensure skill-todo handles both directory formats for backward compatibility
- Preserve all .opencode/ OC_ references unchanged

**Non-Goals**:
- Renaming existing `specs/OC_*` directories (archived naturally via /todo)
- Modifying .opencode/ system files
- Creating automated linting rules (future enhancement)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing some OC_ references | Medium | Low | Use grep to verify all instances found |
| Breaking skill-todo scanning | High | Medium | Test with both OC_ and plain directories |
| Incomplete documentation | Low | Low | Review existing docs before finalizing |

## Implementation Phases

### Phase 1: Core Skills [COMPLETED]

**Goal**: Update the 4 core skills that generate task directories and metadata paths.

**Tasks**:
- [ ] Update skill-researcher/SKILL.md - remove OC_ from mkdir patterns, metadata paths, postflight patterns
- [ ] Update skill-planner/SKILL.md - remove OC_ from mkdir patterns, metadata paths, postflight patterns
- [ ] Update skill-implementer/SKILL.md - remove OC_ from mkdir patterns, metadata paths, postflight patterns
- [ ] Update skill-todo/SKILL.md - verify dual-format scanning, update TODO entry patterns, CHANGE_LOG format

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - mkdir and path patterns
- `.claude/skills/skill-planner/SKILL.md` - mkdir and path patterns
- `.claude/skills/skill-implementer/SKILL.md` - mkdir and path patterns
- `.claude/skills/skill-todo/SKILL.md` - scanning patterns (keep dual-format support)

**Verification**:
- Grep for `OC_` in each modified file shows no incorrect references
- skill-todo retains `specs/OC_[0-9]*_*/` and `specs/[0-9]*_*/` scanning patterns

---

### Phase 2: Core Agents [COMPLETED]

**Goal**: Update the 4 core agents that contain mkdir commands and path construction.

**Tasks**:
- [ ] Update general-research-agent.md - remove OC_ from mkdir patterns, metadata paths, examples
- [ ] Update general-implementation-agent.md - remove OC_ from mkdir patterns, metadata paths, examples
- [ ] Update planner-agent.md - remove OC_ from mkdir patterns, metadata paths, examples
- [ ] Update meta-builder-agent.md - remove OC_ from example task directory paths

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/general-research-agent.md` - multiple pattern types
- `.claude/agents/general-implementation-agent.md` - multiple pattern types
- `.claude/agents/planner-agent.md` - multiple pattern types
- `.claude/agents/meta-builder-agent.md` - example paths

**Verification**:
- Grep for `OC_` in each modified file shows no incorrect references
- Example paths use `{NNN}_{SLUG}` format

---

### Phase 3: Commands [COMPLETED]

**Goal**: Update the 3 commands that display task information with OC_ prefix.

**Tasks**:
- [ ] Update research.md - remove OC_ from header display format
- [ ] Update plan.md - remove OC_ from header display format
- [ ] Update implement.md - remove OC_ from header display format

**Timing**: 20 minutes

**Files to modify**:
- `.claude/commands/research.md` - header display format
- `.claude/commands/plan.md` - header display format
- `.claude/commands/implement.md` - header display format

**Verification**:
- Header display patterns use `Task {N}:` not `Task OC_{N}:`

---

### Phase 4: Context and Documentation [COMPLETED]

**Goal**: Update the 10 context/core files with path patterns and examples.

**Tasks**:
- [ ] Update return-metadata-file.md - mkdir patterns, path examples, relationship table
- [ ] Update subagent-return.md - path examples
- [ ] Update early-metadata-pattern.md - mkdir patterns, path examples
- [ ] Update metadata-file-return.md - path patterns
- [ ] Update file-metadata-exchange.md - path patterns
- [ ] Update postflight-control.md - directory patterns
- [ ] Update workflow-interruptions.md - path patterns
- [ ] Update component-checklist.md - path patterns
- [ ] Update generation-guidelines.md - path patterns
- [ ] Update documentation.md (standards) - path patterns

**Timing**: 40 minutes

**Files to modify**:
- `.claude/context/core/formats/return-metadata-file.md`
- `.claude/context/core/formats/subagent-return.md`
- `.claude/context/core/patterns/early-metadata-pattern.md`
- `.claude/context/core/patterns/metadata-file-return.md`
- `.claude/context/core/patterns/file-metadata-exchange.md`
- `.claude/context/core/patterns/postflight-control.md`
- `.claude/context/core/troubleshooting/workflow-interruptions.md`
- `.claude/context/core/architecture/component-checklist.md`
- `.claude/context/core/architecture/generation-guidelines.md`
- `.claude/context/core/standards/documentation.md`

**Verification**:
- All path examples use `{NNN}_{SLUG}` format
- Relationship tables show correct format distinctions

---

### Phase 5: Extension Files [COMPLETED]

**Goal**: Update the 23 extension agent and skill files with mkdir patterns.

**Tasks**:
- [ ] Update nvim extension agents (2 files)
- [ ] Update nvim extension skills (2 files)
- [ ] Update nix extension agents (2 files)
- [ ] Update nix extension skills (2 files)
- [ ] Update web extension agents (2 files)
- [ ] Update web extension skills (2 files)
- [ ] Update lean extension skills (2 files)
- [ ] Update formal extension agents (4 files)
- [ ] Update formal extension skills (4 files)
- [ ] Update filetypes context file (1 file)

**Timing**: 50 minutes

**Files to modify**:
- `.claude/extensions/nvim/agents/neovim-implementation-agent.md`
- `.claude/extensions/nvim/agents/neovim-research-agent.md`
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `.claude/extensions/nix/agents/nix-implementation-agent.md`
- `.claude/extensions/nix/agents/nix-research-agent.md`
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md`
- `.claude/extensions/web/agents/web-implementation-agent.md`
- `.claude/extensions/web/agents/web-research-agent.md`
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- `.claude/extensions/web/skills/skill-web-research/SKILL.md`
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md`
- `.claude/extensions/formal/agents/formal-research-agent.md`
- `.claude/extensions/formal/agents/logic-research-agent.md`
- `.claude/extensions/formal/agents/math-research-agent.md`
- `.claude/extensions/formal/agents/physics-research-agent.md`
- `.claude/extensions/formal/skills/skill-formal-research/SKILL.md`
- `.claude/extensions/formal/skills/skill-logic-research/SKILL.md`
- `.claude/extensions/formal/skills/skill-math-research/SKILL.md`
- `.claude/extensions/formal/skills/skill-physics-research/SKILL.md`
- `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md`

**Verification**:
- Grep for `OC_` in extension directories shows no incorrect references
- mkdir patterns use `${padded_num}_${task_slug}` format

---

### Phase 6: Documentation Clarification [COMPLETED]

**Goal**: Add documentation clarifying the distinction between .claude/ and .opencode/ naming conventions.

**Tasks**:
- [ ] Update .claude/CLAUDE.md Artifact Paths section to explicitly state plain `{NNN}_{SLUG}` format
- [ ] Update .claude/rules/artifact-formats.md to note system-specific prefixes
- [ ] Update .claude/rules/state-management.md Directory Creation section to clarify naming convention

**Timing**: 30 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Artifact Paths section
- `.claude/rules/artifact-formats.md` - Placeholder Conventions section
- `.claude/rules/state-management.md` - Directory Creation section

**Verification**:
- Documentation clearly states: Claude Code uses `{NNN}_{SLUG}`, OC_ prefix reserved for .opencode/
- No ambiguity about which system uses which format

---

### Phase 7: Verification [COMPLETED]

**Goal**: Verify all changes are complete and no OC_ references remain in .claude/ task directory patterns.

**Tasks**:
- [ ] Run comprehensive grep to find any remaining OC_ references in .claude/
- [ ] Verify skill-todo can scan both OC_ and plain directories
- [ ] Create a test task to verify new directory format is used
- [ ] Document any intentional OC_ references (if any remain for backward compatibility)

**Timing**: 20 minutes

**Verification**:
- `grep -r "OC_" .claude/ | grep -v ".opencode"` shows only intentional references
- Test task creates directory without OC_ prefix
- skill-todo successfully processes both directory formats

## Testing & Validation

- [ ] Grep verification: no unintended OC_ references in .claude/
- [ ] skill-todo dual-format scanning works correctly
- [ ] New task creation uses plain `{NNN}_{SLUG}` format
- [ ] Existing `specs/OC_*` directories still processed correctly
- [ ] Documentation accurately describes naming conventions

## Artifacts & Outputs

- plans/02_implementation-plan.md (this file)
- summaries/03_implementation-summary.md (upon completion)
- Updated .claude/ files (44 files)
- Updated documentation (3 files)

## Rollback/Contingency

If changes cause issues:
1. Revert to previous commit before Phase 1
2. Identify specific problematic changes
3. Apply fixes incrementally with testing between phases
4. Consider keeping OC_ prefix temporarily if coordination with .opencode/ is needed
