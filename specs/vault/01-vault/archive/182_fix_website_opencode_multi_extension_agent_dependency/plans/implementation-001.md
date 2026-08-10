# Implementation Plan: Task #182

- **Task**: 182 - Fix Website opencode multi-extension agent dependency
- **Status**: [NOT STARTED]
- **Effort**: 0.5-1 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: /home/benjamin/.config/nvim/CLAUDE.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-11
- **Feature**: Commit 5 agent files as static files in Website repo, removing extension dependency
- **Estimated Hours**: 0.5-1 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The Website project's `opencode.json` references 5 agent files via `{file:...}` syntax that are dynamically managed by the `web` and `nvim` extensions. When the core agent system reloads, these files are removed, breaking opencode startup. The fix is to commit these 5 agent files as static files directly in the Website repo, eliminating the extension dependency for agent definitions.

### Research Integration

Research report confirms Option A (Static Agent Files) as the recommended approach. The 5 affected files are: `web-research-agent.md`, `web-implementation-agent.md`, `document-converter-agent.md` (from `web` extension), and `neovim-research-agent.md`, `neovim-implementation-agent.md` (from `nvim` extension). All reside in `.opencode/agent/subagents/` and are referenced by `opencode.json`.

## Goals and Non-Goals

**Goals**:
- Eliminate the dependency on `web` and `nvim` extensions for opencode startup
- Make the Website repo self-contained for its agent definitions
- Ensure opencode starts correctly after core agent system reload without manual extension loading

**Non-Goals**:
- Changing the extension system architecture
- Modifying how the `memory` extension works (it provides skills/commands/data, not agents referenced by opencode.json)
- Automating sync between extension source and static copies (manual sync is acceptable)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Static copies diverge from extension source | Low | Medium | Document the source-of-truth relationship; periodic manual sync |
| .gitignore rules exclude the agent files | Medium | Low | Verify .gitignore patterns in Phase 1 before committing |
| Extension reload overwrites static files | Medium | Low | Test that committed files survive extension unload/reload cycle |

## Implementation Phases

### Phase 1: Copy Agent Files and Verify Git Tracking [NOT STARTED]

**Goal**: Copy the 5 agent files from extension sources to the Website repo as static, git-tracked files.

**Tasks**:
- [ ] Check Website repo `.gitignore` for patterns that might exclude `.opencode/agent/subagents/*.md` files
- [ ] If gitignore exclusions exist, add negation rules (e.g., `!.opencode/agent/subagents/*.md`)
- [ ] Copy the 5 agent files from extension sources to `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/`:
  - `web-research-agent.md` (from `.opencode/extensions/web/agents/`)
  - `web-implementation-agent.md` (from `.opencode/extensions/web/agents/`)
  - `document-converter-agent.md` (from `.opencode/extensions/web/agents/`)
  - `neovim-research-agent.md` (from `.opencode/extensions/nvim/agents/`)
  - `neovim-implementation-agent.md` (from `.opencode/extensions/nvim/agents/`)
- [ ] Run `git status` in the Website repo to confirm all 5 files appear as new tracked files
- [ ] Commit the 5 agent files to the Website repo

**Timing**: 20 minutes

**Files to modify**:
- `/home/benjamin/Projects/Logos/Website/.gitignore` - Add negation rules if needed
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/web-research-agent.md` - Static copy
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/web-implementation-agent.md` - Static copy
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/document-converter-agent.md` - Static copy
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/neovim-research-agent.md` - Static copy
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/neovim-implementation-agent.md` - Static copy

**Verification**:
- `git status` shows all 5 files as tracked
- `git diff --cached` confirms file contents match extension sources

---

### Phase 2: Verify Opencode Startup After Core Reload [NOT STARTED]

**Goal**: Confirm that opencode starts correctly after a core agent system reload, without manually loading web/nvim extensions.

**Tasks**:
- [ ] Reload the core agent system (which removes extension-provided files)
- [ ] Verify the 5 static agent files still exist in `.opencode/agent/subagents/` (git-tracked files are not removed by extension unload)
- [ ] Start opencode and confirm no "bad file reference" errors
- [ ] Load the `memory` extension and confirm it loads cleanly alongside the static agent files

**Timing**: 10 minutes

**Files to modify**: None (verification only)

**Verification**:
- All 5 agent files present after core reload
- Opencode starts without errors
- Memory extension loads without conflicts

## Testing and Validation

- [ ] All 5 agent files exist in `.opencode/agent/subagents/` and are git-tracked
- [ ] `.gitignore` does not exclude the agent files
- [ ] Opencode starts successfully after core agent system reload (without loading web/nvim extensions)
- [ ] Memory extension loads cleanly after core reload
- [ ] No duplicate agent definitions when web/nvim extensions are subsequently loaded

## Artifacts and Outputs

- 5 static agent files committed to Website repo
- Updated `.gitignore` (if needed)

## Rollback/Contingency

If the static files cause conflicts with extension loading:
1. Remove the 5 static files from git tracking: `git rm --cached .opencode/agent/subagents/{web-research,web-implementation,document-converter,neovim-research,neovim-implementation}-agent.md`
2. Re-add gitignore exclusions if they were removed
3. Fall back to manual extension loading workflow
