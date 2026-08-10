# Implementation Plan: Remove ineffective changes from tasks 92 and 94

- **Task**: 95 - Remove ineffective changes from tasks 92 and 94
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general

## Overview

Tasks 92 and 94 attempted to fix WezTerm new tab directory behavior when spawning tabs from inside Neovim. All changes were ineffective for the reported scenario. The user has decided to accept the default behavior and remove the added complexity. The approach is simple: switch the nvim repo back to the master branch (which predates tasks 92-94 changes, keeping the useful `<leader>mr` keybinding from that commit), and in the dotfiles repo, discard the uncommitted config.fish changes and revert the wezterm.lua commit.

### Research Integration

Research report (research-001.md) identified 4 changes across 2 repositories. The user guidance simplifies this: in the nvim repo, just switch to master (commit bbfaf745) since that already has the correct state. In the dotfiles repo, discard the uncommitted config.fish changes and revert the wezterm.lua commit (8c62b91) to restore the previous state (bd711d8).

## Goals & Non-Goals

**Goals**:
- Remove all ineffective WezTerm directory-fix changes from both repositories
- Restore both repos to their pre-task-92/94 states (except `<leader>mr` which is on master)
- Keep the dotfiles repo clean with no uncommitted changes

**Non-Goals**:
- Actually fixing the WezTerm new-tab-from-Neovim directory issue (user accepts current behavior)
- Removing task 95 spec artifacts (documentation is preserved)

## Risks & Mitigations

- Risk: Losing the `<leader>mr` maildir resync keybinding. Mitigation: master branch (bbfaf745) already contains this keybinding, so switching to master preserves it.
- Risk: Losing uncommitted work in dotfiles. Mitigation: The only uncommitted change is the OSC 7 prompt hook in config.fish, which is exactly what we want to discard.

## Implementation Phases

### Phase 1: Switch nvim repo to master branch [NOT STARTED]

- **Goal:** Restore the nvim repository to the master branch state, discarding all wezterm_tab branch changes (tasks 92, 94, 95 research commits).

- **Tasks:**
  - [ ] Verify current branch is `wezterm_tab` in `~/.config/nvim`
  - [ ] Verify master HEAD is `bbfaf745` (the correct target)
  - [ ] Run `git checkout master` to switch to master branch
  - [ ] Verify HEAD is now `bbfaf745`
  - [ ] Verify `<leader>mr` keybinding is present in which-key.lua
  - [ ] Verify autocmds.lua does NOT have CursorHold in the checktime events

- **Timing:** 5 minutes

- **Files affected:**
  - All files revert to master state (no file edits needed, just branch switch)

- **Verification:**
  - `git branch` shows `* master`
  - `git log --oneline -1` shows `bbfaf745`

---

### Phase 2: Restore dotfiles repo to pre-task state [NOT STARTED]

- **Goal:** Remove the ineffective WezTerm changes from the dotfiles repository: discard uncommitted config.fish changes and revert the wezterm.lua commit.

- **Tasks:**
  - [ ] Verify current state in `~/.dotfiles`: HEAD at `8c62b91`, uncommitted config.fish changes
  - [ ] Discard uncommitted config.fish changes with `git restore config/config.fish`
  - [ ] Revert the wezterm.lua change by resetting to previous commit: `git reset --soft HEAD~1` then `git checkout -- config/wezterm.lua` (or `git revert HEAD`)
  - [ ] Verify config.fish matches the committed version at `03cff57` (no OSC 7 prompt hook)
  - [ ] Verify wezterm.lua has the original `act.SpawnTab("CurrentPaneDomain")` one-liner
  - [ ] Verify `git status` shows clean working tree

- **Timing:** 5 minutes

- **Files affected:**
  - `config/config.fish` - Discard uncommitted OSC 7 prompt hook addition
  - `config/wezterm.lua` - Revert Leader+c callback to original `act.SpawnTab("CurrentPaneDomain")`

- **Verification:**
  - `git status` in `~/.dotfiles` shows clean working tree
  - `grep -c "wezterm_osc7_prompt" config/config.fish` returns 0
  - `grep "SpawnTab" config/wezterm.lua` shows the original simple form

## Testing & Validation

- [ ] nvim repo: `git branch` confirms master, `git log --oneline -1` confirms bbfaf745
- [ ] nvim repo: `nvim --headless -c "lua require('neotex')" -c "q"` loads without errors
- [ ] dotfiles repo: `git status` shows clean working tree
- [ ] dotfiles repo: config.fish has no `__wezterm_osc7_prompt` function
- [ ] dotfiles repo: wezterm.lua has simple `act.SpawnTab("CurrentPaneDomain")`

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-20260224.md (post-implementation)

## Rollback/Contingency

If the master branch state is incorrect:
- nvim repo: `git checkout wezterm_tab` restores the feature branch
- dotfiles repo: `git reflog` can recover the reverted commit
