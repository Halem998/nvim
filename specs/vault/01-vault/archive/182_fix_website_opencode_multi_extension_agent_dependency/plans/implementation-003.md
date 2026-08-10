# Implementation Plan: Task #182 (Revision 3 - Zero-Overlap)

- **Task**: 182 - Fix Website opencode multi-extension agent dependency
- **Status**: [COMPLETED]
- **Effort**: 0.5-1 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md), [research-003.md](../reports/research-003.md)
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**: /home/benjamin/.config/nvim/CLAUDE.md
- **Type**: meta
- **Date**: 2026-03-11 (Revised)
- **Feature**: Eliminate extension overlap by removing duplicates
- **Estimated Hours**: 0.5-1 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-003.md](../reports/research-003.md) - Zero-overlap architecture

## Overview

This revision implements the **zero-overlap** approach: remove duplicate agents from extensions rather than managing overlap. The `document-converter-agent.md` is removed from web extension (filetypes already provides `document-agent.md`). Neovim agents remain in nvim extension only. Website's opencode.json is updated to remove the document-converter reference.

### Revision Rationale

- v1 (implementation-001.md): Option A - static files in Website (abandoned)
- v2 (implementation-002.md): Option B - self-contained web extension (abandoned)
- **v3 (this plan)**: Zero-overlap - remove duplicates, let extensions be focused

### Key Changes from v2

1. Do NOT add neovim agents to web extension
2. REMOVE document-converter-agent from web extension
3. Update Website opencode.json to remove document-converter agent definition

## Goals and Non-Goals

**Goals**:
- Eliminate all extension overlap (no duplicate agents)
- Keep extensions focused on their core purpose
- Update Website to work without document-converter agent

**Non-Goals**:
- Adding agents to make extensions self-contained
- Implementing dependency management between extensions
- Changing the filetypes extension (it already has document-agent.md)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Website needs document conversion | Low | Low | Can load filetypes extension if needed, or use inline prompt |
| Breaking change for web extension users | Low | Low | Document the change; filetypes provides better document-agent |

## Implementation Phases

### Phase 1: Remove document-converter from web Extension [NOT STARTED]

**Goal**: Delete the duplicate document-converter-agent.md from web extension.

**Tasks**:
- [ ] Delete `.opencode/extensions/web/agents/document-converter-agent.md`
- [ ] Edit `.opencode/extensions/web/manifest.json`:
  - Change `"agents": ["web-implementation-agent.md", "web-research-agent.md", "document-converter-agent.md"]`
  - To: `"agents": ["web-implementation-agent.md", "web-research-agent.md"]`
- [ ] Verify manifest.json is valid JSON
- [ ] Commit changes to nvim config repo

**Timing**: 10 minutes

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/extensions/web/agents/document-converter-agent.md` - DELETE
- `/home/benjamin/.config/nvim/.opencode/extensions/web/manifest.json` - Remove agent from provides.agents

**Verification**:
- File deleted
- manifest.json valid and lists only 2 agents
- Git commit successful

---

### Phase 2: Update Website opencode.json [NOT STARTED]

**Goal**: Remove document-converter agent definition from Website since it's no longer provided by web extension.

**Tasks**:
- [ ] Navigate to Website repo: `/home/benjamin/Projects/Logos/Website/`
- [ ] Edit `opencode.json`:
  - Delete the entire `"document-converter"` agent definition (lines 154-166)
- [ ] Verify opencode.json is valid JSON
- [ ] Commit changes to Website repo

**Timing**: 10 minutes

**Files to modify**:
- `/home/benjamin/Projects/Logos/Website/opencode.json` - Remove document-converter agent

**Verification**:
- opencode.json valid
- No document-converter agent definition
- Git commit successful

---

### Phase 3: Verify Zero-Overlap Works [NOT STARTED]

**Goal**: Confirm opencode starts correctly after changes.

**Tasks**:
- [ ] In Website repo, reload core agent system
- [ ] Load only the `web` extension via `<leader>ao`
- [ ] Verify opencode starts without "bad file reference" errors
- [ ] Verify web-research and web-implementation agents work
- [ ] Load `nvim` extension if neovim agents needed
- [ ] Load `memory` extension for memory functionality

**Timing**: 10 minutes

**Files to modify**: None (verification only)

**Verification**:
- Opencode starts with web extension only
- No errors about missing document-converter-agent
- Can load additional extensions as needed

## Testing and Validation

- [ ] document-converter-agent.md deleted from web extension
- [ ] web/manifest.json lists only 2 agents
- [ ] Website opencode.json has no document-converter definition
- [ ] Opencode starts successfully with web extension loaded
- [ ] No extension overlap exists

## Artifacts and Outputs

- Updated web extension (document-converter removed)
- Updated Website opencode.json

## Rollback/Contingency

If removing document-converter causes issues:
1. Restore the file from git: `git checkout HEAD~1 -- .opencode/extensions/web/agents/document-converter-agent.md`
2. Restore manifest.json entry
3. Consider using filetypes extension for document conversion instead
