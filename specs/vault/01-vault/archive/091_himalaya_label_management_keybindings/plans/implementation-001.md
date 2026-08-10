# Implementation Plan: Himalaya Label Management Keybindings

- **Task**: 91 - himalaya_label_management_keybindings
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: Task 86 (sync/account keybindings), Task 88 (threading keybindings)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Implement label/flag management keybindings for the Himalaya email client integration. This adds the ability to apply flags (labels) to emails, create new folders (labels), and delete folders. The implementation leverages the existing selection system for bulk operations and follows established patterns from similar features (archive, move, delete).

### Research Integration

Key findings from research-001.md:
- Himalaya uses `flag add/remove` commands for labeling emails
- Himalaya uses `folder add/delete` commands for label (folder) management
- No folder rename command exists - document as limitation
- Existing selection patterns (`state.get_selected_emails()`) can be reused
- Standard flags: seen, answered, flagged, deleted, draft; custom flags also supported

## Goals & Non-Goals

**Goals**:
- Add `l` keybinding for selection-aware flag application
- Add `glc` keybinding to create new folder/label
- Add `gld` keybinding to delete folder/label with confirmation
- Update help menu to include new keybindings
- Integrate with existing selection system for bulk operations

**Non-Goals**:
- Folder/label renaming (not supported by Himalaya CLI)
- Custom flag creation UI (use standard flags + vim.ui.input for custom)
- Flag display in email list (separate enhancement)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Custom flags not supported by backend | Medium | Medium | Focus on standard flags, document limitation |
| Folder delete loses emails | High | Low | Require confirmation dialog with warning |
| Flag operations slow for many emails | Low | Low | Show progress notification for bulk operations |
| Key conflict with existing mappings | Medium | Low | `l` is available, `gl` prefix is unused |

## Implementation Phases

### Phase 1: Create labels.lua Module [NOT STARTED]

**Goal**: Create the core module with flag/label management functions

**Tasks**:
- [ ] Create `lua/neotex/plugins/tools/himalaya/features/labels.lua` module
- [ ] Implement `show_flag_picker(email_ids)` function with standard flags + custom input option
- [ ] Implement `add_flag(email_ids, flag)` function using `himalaya flag add`
- [ ] Implement `remove_flag(email_ids, flag)` function using `himalaya flag remove`
- [ ] Implement `label_current_email()` wrapper for single email
- [ ] Implement `label_selected_emails()` wrapper for bulk selection
- [ ] Add proper error handling and notifications

**Timing**: 45-60 minutes

**Files to create**:
- `lua/neotex/plugins/tools/himalaya/features/labels.lua`

**Verification**:
- Module loads without errors: `nvim --headless -c "lua require('neotex.plugins.tools.himalaya.features.labels')" -c "q"`
- Functions are exported and callable

---

### Phase 2: Create folder Management Functions [NOT STARTED]

**Goal**: Add folder (label) CRUD operations to labels.lua

**Tasks**:
- [ ] Implement `create_label()` function with vim.ui.input for name
- [ ] Implement `delete_label()` function with folder picker and confirmation
- [ ] Implement `get_folders()` helper to fetch available folders
- [ ] Add validation for folder names (no empty strings, special characters)
- [ ] Add success/failure notifications

**Timing**: 30-40 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/features/labels.lua` - Add folder management functions

**Verification**:
- Create label function prompts for input
- Delete label shows folder picker with confirmation
- Error handling works for invalid folder names

---

### Phase 3: Add Keybindings in config/ui.lua [NOT STARTED]

**Goal**: Register all label-related keybindings in the email list buffer

**Tasks**:
- [ ] Add `l` keybinding for selection-aware label application
- [ ] Add `glc` keybinding for create label
- [ ] Add `gld` keybinding for delete label
- [ ] Update keybindings table in `M.get_keybinding()` function
- [ ] Add descriptions for all new keybindings

**Timing**: 20-30 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/config/ui.lua` - Add keybindings in `setup_email_list_keymaps()`

**Verification**:
- `l` key triggers flag picker when pressed in email list
- `glc` prompts for new label name
- `gld` shows folder picker for deletion
- Keybindings only active in himalaya-list filetype

---

### Phase 4: Update Help Menu [NOT STARTED]

**Goal**: Add new keybindings to the context-aware help display

**Tasks**:
- [ ] Add "Labels:" section to help content in `folder_help.lua`
- [ ] Include `l`, `glc`, `gld` keybindings with descriptions
- [ ] Position section appropriately (after Quick Actions, before Sync & Accounts)

**Timing**: 15-20 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua` - Add labels section to `get_help_content()`

**Verification**:
- Help display (?) shows new Labels section
- All three keybindings documented with descriptions

---

### Phase 5: Testing and Verification [NOT STARTED]

**Goal**: Verify all functionality works correctly

**Tasks**:
- [ ] Test `l` on single email (no selection) - should apply flag to current email
- [ ] Test `l` with multiple emails selected - should apply flag to all selected
- [ ] Test `glc` - should create new folder and show success notification
- [ ] Test `gld` - should show picker, require confirmation, delete folder
- [ ] Test error handling - invalid folder names, network errors
- [ ] Verify help menu displays correctly
- [ ] Test in different folder types (inbox, sent, drafts)

**Timing**: 20-30 minutes

**Verification**:
- All operations complete without errors
- Notifications appear appropriately
- Selection is cleared after bulk operations
- Email list refreshes after flag changes

## Testing & Validation

- [ ] Module loads: `nvim --headless -c "lua require('neotex.plugins.tools.himalaya.features.labels')" -c "q"`
- [ ] Keybindings registered: Open email list, verify `l`, `glc`, `gld` work
- [ ] Help menu updated: Press `?` in email list, verify Labels section appears
- [ ] Flag application: Select emails, press `l`, pick flag, verify applied
- [ ] Folder creation: Press `glc`, enter name, verify folder created
- [ ] Folder deletion: Press `gld`, select folder, confirm, verify deleted
- [ ] Selection awareness: Test with 0, 1, and multiple emails selected

## Artifacts & Outputs

- `lua/neotex/plugins/tools/himalaya/features/labels.lua` - New module
- `lua/neotex/plugins/tools/himalaya/config/ui.lua` - Updated with keybindings
- `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua` - Updated help content
- `specs/091_himalaya_label_management_keybindings/summaries/implementation-summary-YYYYMMDD.md` - Final summary

## Rollback/Contingency

If implementation fails:
1. Remove new `features/labels.lua` module
2. Revert changes to `config/ui.lua` (remove keybinding lines)
3. Revert changes to `ui/folder_help.lua` (remove Labels section)
4. Git reset to pre-implementation commit

All changes are additive and do not modify existing functionality, so rollback is straightforward.
