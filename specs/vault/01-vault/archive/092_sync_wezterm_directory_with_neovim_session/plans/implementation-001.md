# Implementation Plan: Task #92

- **Task**: 92 - Sync Wezterm terminal directory with Neovim session root
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

The research reveals that OSC 7 integration for WezTerm directory synchronization **already exists** in the codebase at `lua/neotex/config/autocmds.lua` (lines 103-144). The existing implementation emits OSC 7 sequences on VimEnter, DirChanged, and BufEnter events, which enables WezTerm to display the correct directory in tab titles and inherit directories when spawning new tabs/panes.

This plan focuses on **verification** of the existing functionality and **documentation** of the working feature, with an optional enhancement phase for session restoration scenarios.

### Research Integration

Key findings from research-001.md:
- OSC 7 format: `ESC ] 7 ; file://hostname/path BEL` is correctly implemented
- Three autocmds exist: VimEnter (startup), DirChanged (directory changes), BufEnter (non-terminal buffers)
- WezTerm uses OSC 7 for tab titles AND spawn directory inheritance via `pane:get_current_working_dir()`
- Shell PWD cannot be changed via OSC 7 (it is a notification, not a command)

## Goals & Non-Goals

**Goals**:
- Verify the existing OSC 7 implementation works correctly for WezTerm directory sync
- Add SessionLoadPost handler if session restoration does not trigger OSC 7
- Document the working feature in appropriate locations

**Non-Goals**:
- Changing shell PWD (architecturally impossible via OSC 7)
- Modifying WezTerm configuration (Neovim-side solution per task description)
- Adding new terminal escape sequences

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing implementation already works | Low | High | Verification phase first; skip enhancement if working |
| SessionLoadPost not triggered | Medium | Low | Alternative: hook into session plugin events |
| Testing requires manual WezTerm interaction | Low | High | Document verification steps clearly |

## Implementation Phases

### Phase 1: Verify Existing Implementation [NOT STARTED]

**Goal**: Confirm the existing OSC 7 implementation works for the stated use case.

**Tasks**:
- [ ] Run Neovim inside WezTerm and verify tab title shows directory
- [ ] Open a project file (e.g., `nvim ~/.config/nvim/init.lua`) and verify tab title updates
- [ ] Open a new WezTerm tab (Ctrl+Space c) and verify it inherits Neovim's working directory
- [ ] Test `:cd` command and verify tab title updates

**Timing**: 15 minutes

**Verification**:
- Tab title displays correct directory name
- New tabs spawn in Neovim's working directory
- Directory changes via `:cd` update tab title

---

### Phase 2: Test Session Restoration [NOT STARTED]

**Goal**: Verify OSC 7 is emitted correctly when restoring Neovim sessions.

**Tasks**:
- [ ] Save a session with a known working directory
- [ ] Close and reopen Neovim, restore the session
- [ ] Check if tab title reflects the session's working directory
- [ ] If not working, identify the appropriate hook point

**Timing**: 15 minutes

**Files to examine**:
- `lua/neotex/plugins/session.lua` (if exists) - session plugin configuration
- `lua/neotex/config/autocmds.lua` - potential SessionLoadPost addition

**Verification**:
- Session restoration updates WezTerm tab title correctly
- OR: Identified need for SessionLoadPost handler

---

### Phase 3: Implement SessionLoadPost Handler (Conditional) [NOT STARTED]

**Goal**: Add SessionLoadPost autocmd if Phase 2 reveals it is needed.

**Tasks**:
- [ ] Add SessionLoadPost autocmd to emit OSC 7 after session restore
- [ ] Test session restoration with new handler
- [ ] Verify no duplicate emissions occur

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/config/autocmds.lua` - add SessionLoadPost handler inside `if vim.env.WEZTERM_PANE` block

**Code (if needed)**:
```lua
-- Emit OSC 7 after session restoration
api.nvim_create_autocmd("SessionLoadPost", {
  callback = emit_osc7,
  desc = "WezTerm: Update directory after session restore",
})
```

**Verification**:
- Session restoration triggers OSC 7 emission
- Tab title updates correctly after session load

---

### Phase 4: Documentation and Completion [NOT STARTED]

**Goal**: Document the feature and create implementation summary.

**Tasks**:
- [ ] Update relevant documentation with feature description
- [ ] Create implementation summary with verification results
- [ ] Mark task as complete

**Timing**: 15 minutes

**Files to create**:
- `specs/092_sync_wezterm_directory_with_neovim_session/summaries/implementation-summary-{DATE}.md`

**Verification**:
- Documentation reflects current implementation state
- Summary captures verification results

## Testing & Validation

- [ ] WezTerm tab title shows Neovim's working directory on startup
- [ ] Tab title updates when `:cd`, `:lcd`, or `:tcd` commands are executed
- [ ] New WezTerm tabs inherit Neovim's working directory
- [ ] Session restoration (if applicable) updates tab title correctly
- [ ] No error messages in Neovim's `:messages` output

## Artifacts & Outputs

- `specs/092_sync_wezterm_directory_with_neovim_session/plans/implementation-001.md` (this file)
- `specs/092_sync_wezterm_directory_with_neovim_session/summaries/implementation-summary-{DATE}.md`
- Potentially: `lua/neotex/config/autocmds.lua` (if SessionLoadPost needed)

## Rollback/Contingency

- **If SessionLoadPost causes issues**: Remove the single autocmd block; existing VimEnter/DirChanged/BufEnter handlers remain
- **If OSC 7 conflicts with other terminal features**: The entire OSC 7 block is wrapped in `if vim.env.WEZTERM_PANE` and can be disabled by unsetting that environment variable

## Notes

The research clarifies an important distinction:
- **OSC 7 capability**: Tab titles and spawn directory inheritance (WORKING)
- **Shell PWD sync**: Cannot be achieved via OSC 7 (terminal escapes cannot execute shell commands)

If the user's actual requirement is shell PWD synchronization (e.g., a shell prompt showing Neovim's directory), this would require a different approach entirely (e.g., named pipes, environment variable polling, or shared state files). However, the task description suggests the existing OSC 7 solution should suffice.
