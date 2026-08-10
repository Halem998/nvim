# Implementation Plan: Task #182 (Revised)

- **Task**: 182 - Fix Website opencode multi-extension agent dependency
- **Status**: [NOT STARTED]
- **Effort**: 1-1.5 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: /home/benjamin/.config/nvim/CLAUDE.md
- **Type**: meta
- **Date**: 2026-03-11 (Revised)
- **Feature**: Make web extension self-contained with all required agents for portability
- **Estimated Hours**: 1-1.5 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

This revision implements **Option B** from the research report: making the `web` extension self-contained by including ALL agents needed by web projects (including neovim agents). This eliminates the need to load multiple extensions (`web` + `nvim`) and improves portability and maintainability.

### Revision Rationale

Option A (static files in Website repo) solves the immediate problem but creates maintenance burden (two copies to sync). Option B makes the extension system work correctly:
- Single extension load provides complete agent coverage
- Extension remains portable to other web projects
- Follows the established extension architecture patterns

### Research Integration

The 5 agents needed by Website are:
- `web-research-agent.md` (already in web extension)
- `web-implementation-agent.md` (already in web extension)
- `document-converter-agent.md` (already in web extension)
- `neovim-research-agent.md` (currently in nvim extension)
- `neovim-implementation-agent.md` (currently in nvim extension)

## Goals and Non-Goals

**Goals**:
- Make web extension self-contained with all 5 required agents
- Single extension load provides complete agent coverage
- Maintain consistency with other extension patterns
- Improve portability for web projects

**Non-Goals**:
- Removing agents from nvim extension (they remain there for nvim-focused projects)
- Changing extension system architecture
- Modifying how opencode.json references agents

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Duplicate agents between web and nvim extensions | Low | High | Acceptable trade-off for self-containment; document canonical source |
| Agent definitions diverge over time | Medium | Medium | Document update workflow; nvim extension remains canonical for neovim agents |
| Large extension size | Low | Low | 2 additional .md files; negligible |

## Implementation Phases

### Phase 1: Add Neovim Agents to Web Extension [NOT STARTED]

**Goal**: Copy neovim agents from nvim extension to web extension and update manifest.

**Tasks**:
- [ ] Copy `neovim-research-agent.md` from `.opencode/extensions/nvim/agents/` to `.opencode/extensions/web/agents/`
- [ ] Copy `neovim-implementation-agent.md` from `.opencode/extensions/nvim/agents/` to `.opencode/extensions/web/agents/`
- [ ] Update `.opencode/extensions/web/manifest.json` to add both agents to the `provides.agents` array
- [ ] Verify manifest JSON is valid
- [ ] Commit changes to nvim config repo

**Timing**: 15 minutes

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/extensions/web/agents/neovim-research-agent.md` - New file (copy)
- `/home/benjamin/.config/nvim/.opencode/extensions/web/agents/neovim-implementation-agent.md` - New file (copy)
- `/home/benjamin/.config/nvim/.opencode/extensions/web/manifest.json` - Add agents to provides.agents

**Verification**:
- Both agent files exist in web extension
- manifest.json lists 5 agents
- JSON syntax is valid

---

### Phase 2: Update Extension Documentation [NOT STARTED]

**Goal**: Document the self-contained nature of web extension and agent source relationships.

**Tasks**:
- [ ] Update `.opencode/extensions/web/README.md` to note that neovim agents are included for self-containment
- [ ] Add note indicating nvim extension remains canonical source for neovim agent definitions
- [ ] Update EXTENSION.md if it lists agents

**Timing**: 10 minutes

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/extensions/web/README.md` - Add self-containment documentation
- `/home/benjamin/.config/nvim/.opencode/extensions/web/EXTENSION.md` - Update if needed

**Verification**:
- Documentation reflects 5 agents
- Canonical source relationship documented

---

### Phase 3: Verify Extension Loading in Website [NOT STARTED]

**Goal**: Confirm web extension provides all 5 agents and opencode starts correctly.

**Tasks**:
- [ ] Navigate to Website repo
- [ ] Reload core agent system (removes all extension files)
- [ ] Load only the `web` extension via `<leader>ao`
- [ ] Verify all 5 agent files exist in `.opencode/agent/subagents/`
- [ ] Start opencode and confirm no "bad file reference" errors
- [ ] Optionally load memory extension and confirm no conflicts

**Timing**: 15 minutes

**Files to modify**: None (verification only)

**Verification**:
- All 5 agent files present after loading only web extension
- opencode starts without errors
- No need to load nvim extension separately

---

### Phase 4: Cleanup and Documentation [NOT STARTED]

**Goal**: Remove temporary static files if present and finalize.

**Tasks**:
- [ ] If static agent files were committed to Website repo (from task 181), they can be removed (extension now provides them)
- [ ] Or keep them as fallback (extension loading will overwrite with same content)
- [ ] Create implementation summary

**Timing**: 10 minutes

**Files to modify**:
- Website repo `.opencode/agent/subagents/` - Optional cleanup of static files

**Verification**:
- Extension-based workflow confirmed working
- No duplicate/conflicting files

## Testing and Validation

- [ ] web extension manifest lists 5 agents
- [ ] All 5 agent files exist in web extension source
- [ ] Loading web extension installs all 5 agents to target project
- [ ] opencode starts successfully with only web extension loaded
- [ ] No errors when subsequently loading memory extension
- [ ] Extension remains compatible with other web projects

## Artifacts and Outputs

- Updated web extension with 5 agents
- Updated manifest.json and documentation
- Implementation summary

## Rollback/Contingency

If the bundled approach causes issues:
1. Remove the added neovim agents from web extension
2. Restore manifest.json to 3 agents
3. Fall back to Option A (static files) from original plan
