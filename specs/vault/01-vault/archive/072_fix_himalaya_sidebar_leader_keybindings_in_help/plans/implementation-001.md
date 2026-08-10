# Implementation Plan: Fix Himalaya Sidebar Leader Keybindings in Help

- **Task**: 72 - fix_himalaya_sidebar_leader_keybindings_in_help
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/research-072.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/standards/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: neovim

## Overview

This plan addresses the fix for Himalaya sidebar help incorrectly displaying leader keybindings that conflict with the toggle selection functionality. The fix has already been implemented in `folder_help.lua` (lines 61-62), which removed the folder management section from help content to prevent showing leader keybindings (`<leader>mA`, `<leader>mf`, `<leader>ms`) that conflict with `<Space>` toggle selection.

**Definition of Done**: The sidebar help displays only non-conflicting single-key bindings ('a' for account, 'c' for folder change), with no leader keybindings visible.

### Research Integration

Research report `research-072.md` confirmed:
- The folder management section was already removed from `folder_help.lua`
- Single-key alternatives are in use in the sidebar (`a` for account switch, `c` for change folder)
- Global leader keybindings remain functional outside the sidebar via which-key
- The conflict exists because `<leader>` is mapped to `<Space>`, which is used for toggle selection in the sidebar

## Goals & Non-Goals

**Goals**:
- Verify the fix is correctly implemented in `folder_help.lua`
- Confirm sidebar help shows no leader keybindings
- Document the fix and its rationale
- Ensure single-key alternatives are documented in help

**Non-Goals**:
- No code changes needed (fix already implemented)
- No new keybindings to add
- No modification to global leader keybindings

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fix verification fails | Medium | Low | Re-examine `folder_help.lua` implementation |
| Users confused about missing leader keybindings | Low | Medium | Verify single-key alternatives are clearly documented in help |
| README documentation inconsistent | Low | Medium | Document that README lists global keybindings as reference |

## Implementation Phases

### Phase 1: Verify Fix Implementation [COMPLETED]

**Goal**: Confirm the fix is correctly implemented and functioning

**Tasks**:
- [ ] Open `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua` and verify lines 61-62 show `base_folder_mgmt = {}`
- [ ] Verify the comment explains the leader/space conflict
- [ ] Open Himalaya sidebar with `<leader>mm`
- [ ] Press `?` to display help
- [ ] Confirm no leader keybindings (`<leader>mA`, `<leader>mf`, `<leader>ms`) appear in help
- [ ] Confirm single-key alternatives ('a', 'c') are shown instead

**Timing**: 30 minutes

**Verification**:
- `folder_help.lua` lines 61-62 contain `base_folder_mgmt = {}`
- Comment reads: "Folder management section removed - <leader> mappings conflict with <Space> toggle in sidebar"
- Help display shows Selection section with `<Space>` toggle but no Folder Management section with leader bindings

---

### Phase 2: Documentation and Task Completion [COMPLETED]

**Goal**: Document the fix and mark task as complete

**Tasks**:
- [ ] Create summary documenting what was fixed
- [ ] Update task status to completed
- [ ] Verify no regressions in sidebar functionality

**Timing**: 30 minutes

**Verification**:
- Summary created at `summaries/001_himalaya-sidebar-keybindings-summary.md`
- All sidebar functions work correctly (toggle selection, account switch, folder change)
- Task status updated in state.json and TODO.md

---

## Testing & Validation

- [ ] Verify `folder_help.lua` contains empty `base_folder_mgmt` table (lines 61-62)
- [ ] Open Himalaya sidebar and press `?` to show help
- [ ] Confirm no `<leader>mA`, `<leader>mf`, `<leader>ms` appear in help text
- [ ] Confirm single-key bindings 'a' (switch account) and 'c' (change folder) appear in help
- [ ] Test that `<Space>` toggle selection still works in sidebar
- [ ] Test that global leader keybindings `<leader>mA`, `<leader>mf`, `<leader>ms` work outside sidebar

## Artifacts & Outputs

- `summaries/001_himalaya-sidebar-keybindings-summary.md` - Documentation of the fix
- Updated task status in `state.json` and `TODO.md`

## Rollback/Contingency

Since the fix is already implemented and verified, no rollback is needed. If verification reveals issues:

1. Check that `folder_help.lua` was not inadvertently reverted
2. Verify the `base_folder_mgmt = {}` line is still present
3. If missing, restore from git history (commit 7b6f3f74 or later)

## Notes

**Important**: This is a verification-only plan. The actual code fix was already implemented in a previous commit. The purpose of this plan is to:

1. Verify the existing implementation is correct
2. Document the fix for future reference
3. Ensure no regressions exist
4. Mark the task as properly completed

The fix addresses a keybinding conflict where:
- `<leader>` is mapped to `<Space>` in this Neovim configuration
- `<Space>` is used for toggle selection in the Himalaya sidebar buffer
- Therefore, leader keybindings cannot function in the sidebar context
- Solution: Remove leader keybindings from sidebar help, use single-key alternatives instead
