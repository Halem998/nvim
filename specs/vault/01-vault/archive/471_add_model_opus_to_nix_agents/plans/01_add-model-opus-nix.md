# Implementation Plan: Add model: opus to Nix Agent Frontmatter

- **Task**: 471 - add_model_opus_to_nix_agents
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/471_add_model_opus_to_nix_agents/reports/01_nix-agent-frontmatter.md
- **Artifacts**: plans/01_add-model-opus-nix.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/docs/reference/standards/agent-frontmatter-standard.md
- **Type**: meta

## Overview

Both nix agent files (deployed copies and extension source copies) are missing `model: opus` in their YAML frontmatter, violating the agent-frontmatter-standard that requires all extension agents to declare `model: opus`. This plan adds the missing field to all 4 files in a single phase. The change is purely additive and non-breaking.

### Research Integration

- [01_nix-agent-frontmatter.md](../reports/01_nix-agent-frontmatter.md) -- Confirmed 4 files need identical one-line additions; provided exact edit locations.

## Goals & Non-Goals

- **Goals**:
  - Add `model: opus` to all 4 nix agent frontmatter blocks
  - Update both deployed copies (`.claude/agents/`) and extension source copies (`.claude/extensions/nix/agents/`)
  - Achieve full compliance with agent-frontmatter-standard

- **Non-Goals**:
  - Changing any agent behavior or configuration beyond frontmatter
  - Modifying other agents that already have `model: opus`
  - Refactoring agent file structure

## Risks & Mitigations

- **Risk**: Updating only deployed copies, losing the fix on next extension reload.
  - **Mitigation**: Update all 4 files (2 deployed + 2 extension source) in the same phase.
- **Risk**: Malformed YAML frontmatter after edit.
  - **Mitigation**: Verify each file loads correctly with `nvim --headless -c "lua require('...')" -c q` or manual inspection of frontmatter structure.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |

Phases within the same wave can execute in parallel.

### Phase 1: Add model: opus to All Nix Agent Files [NOT STARTED]

- **Goal:** Add `model: opus` line to YAML frontmatter in all 4 nix agent files
- **Tasks:**
  - [ ] Edit `.claude/agents/nix-research-agent.md`: add `model: opus` after `description:` line, before closing `---`
  - [ ] Edit `.claude/agents/nix-implementation-agent.md`: add `model: opus` after `description:` line, before closing `---`
  - [ ] Edit `.claude/extensions/nix/agents/nix-research-agent.md`: add `model: opus` after `description:` line, before closing `---`
  - [ ] Edit `.claude/extensions/nix/agents/nix-implementation-agent.md`: add `model: opus` after `description:` line, before closing `---`
  - [ ] Verify all 4 files have valid YAML frontmatter with `name`, `description`, and `model` fields
- **Timing:** 10 minutes
- **Depends on:** none

## Testing & Validation

- [ ] Confirm each of the 4 files contains `model: opus` in the frontmatter block
- [ ] Verify frontmatter structure matches reference pattern from `general-research-agent.md` (name, description, model)
- [ ] Ensure no other content in agent files was modified

## Artifacts & Outputs

- plans/01_add-model-opus-nix.md (this plan)
- summaries/01_add-model-opus-nix-summary.md (after implementation)

## Rollback/Contingency

- Remove the `model: opus` line from each file. The system defaults to Opus regardless, so the removal has no functional impact.
- Use `git revert` on the implementation commit if needed.
