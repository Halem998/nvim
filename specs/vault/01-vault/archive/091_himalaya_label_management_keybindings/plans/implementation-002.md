# Implementation Plan: Himalaya Label Management Keybindings

- **Date**: 2026-02-13 (Revised)
- **Feature**: Label/flag management keybindings for Himalaya email integration
- **Status**: [COMPLETED]
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)

## Overview

Implement label/flag management keybindings for the Himalaya email client integration. This revision incorporates research-002.md findings on cross-account compatibility (Gmail + Protonmail) and uses **single-letter keybindings only** to avoid multi-key sequences in the himalaya buffer.

### Key Changes from v001

1. **Single-letter keybindings only**: Removed `glc`/`gld` in favor of single keys and commands
2. **Cross-account compatibility**: Account-aware label paths (Gmail top-level vs Protonmail `Labels/`)
3. **Two-tier flag system**: Universal flags (seen, flagged) vs folder-based labels

### Research Integration

From research-002.md:
- Standard IMAP flags (`seen`, `flagged`, `answered`) work universally across Gmail and Protonmail
- Gmail labels are top-level folders; Protonmail labels are under `Labels/` prefix
- Label application should use `message copy` (not `flag add`) for folder-based labels
- Custom IMAP keywords are NOT portable - avoid for labeling

## Goals & Non-Goals

**Goals**:
- Add `l` keybinding for selection-aware flag/label application
- Add `u` keybinding to toggle read/unread status
- Add `s` keybinding to toggle star/flagged status
- Add `L` keybinding for label management menu (create/delete)
- Implement account-aware label handling (Gmail vs Protonmail)
- Update help menu with new keybindings

**Non-Goals**:
- Custom IMAP keywords (not portable between providers)
- Folder/label renaming (not supported by Himalaya CLI)
- X-GM-LABELS Gmail extension (not available via standard IMAP)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Protonmail labels not synced | High | Medium | Document that labels must exist; check folder list first |
| Key conflicts with existing mappings | Medium | Low | `u`, `s`, `l`, `L` are available in email list buffer |
| Account detection fails | Medium | Low | Fallback to top-level folder names |
| Folder operations slow | Low | Low | Show progress notification |

## Implementation Phases

### Phase 1: Create labels.lua Module with Flag Operations [COMPLETED]

**Goal**: Create core module with universal flag operations

**Tasks**:
- [ ] Create `lua/neotex/plugins/tools/himalaya/features/labels.lua` module
- [ ] Implement `toggle_read_status(email_ids)` - toggles `seen` flag
- [ ] Implement `toggle_star_status(email_ids)` - toggles `flagged` flag
- [ ] Implement `get_email_flags(email_id)` - fetches current flags for toggle logic
- [ ] Add selection-aware wrappers: `toggle_read_current()`, `toggle_read_selected()`
- [ ] Add proper error handling and notifications

**Timing**: 30-40 minutes

**Files to create**:
- `lua/neotex/plugins/tools/himalaya/features/labels.lua`

**Verification**:
```bash
nvim --headless -c "lua require('neotex.plugins.tools.himalaya.features.labels')" -c "q"
```
- Module loads without errors
- Functions are exported and callable

---

### Phase 2: Add Label Application Functions [COMPLETED]

**Goal**: Implement label picker with account-aware folder handling

**Tasks**:
- [ ] Implement `show_flag_picker(email_ids)` with standard flags (seen, flagged, answered, deleted, draft)
- [ ] Implement `apply_label(email_ids, label_name)` with account detection
- [ ] Add account-aware path normalization:
  - Gmail: Use label name directly (top-level folder)
  - Protonmail: Prefix with `Labels/` if not present
- [ ] Implement `get_available_labels(account)` filtering system folders
- [ ] Add "Create new folder..." option in picker

**Account-Aware Logic**:
```lua
local function normalize_label_path(label_name, account)
  if account == "logos" and not label_name:match("^Labels/") then
    return "Labels/" .. label_name
  end
  return label_name
end
```

**Timing**: 40-50 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/features/labels.lua`

**Verification**:
- Flag picker shows standard flags
- Account detection works correctly
- Label application uses `message copy` command

---

### Phase 3: Add Folder Management Functions [COMPLETED]

**Goal**: Implement folder/label CRUD operations

**Tasks**:
- [ ] Implement `show_label_management_menu()` with options: Create, Delete
- [ ] Implement `create_folder(name)` using `himalaya folder add`
- [ ] Implement `delete_folder()` with folder picker and confirmation dialog
- [ ] Add validation for folder names (no empty strings)
- [ ] Filter system folders from deletion picker

**Timing**: 25-35 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/features/labels.lua`

**Verification**:
- Create folder prompts for name, creates folder
- Delete folder shows picker, requires confirmation
- System folders excluded from delete picker

---

### Phase 4: Add Single-Letter Keybindings [COMPLETED]

**Goal**: Register all keybindings using single letters only

**Keybinding Mapping**:
| Key | Action | Function |
|-----|--------|----------|
| `u` | Toggle read/unread | `toggle_read_status` (selection-aware) |
| `s` | Toggle star/flagged | `toggle_star_status` (selection-aware) |
| `l` | Apply label/flag picker | `show_flag_picker` (selection-aware) |
| `L` | Label management menu | `show_label_management_menu` |

**Tasks**:
- [ ] Add `u` keybinding for toggle read/unread
- [ ] Add `s` keybinding for toggle star (check conflict with existing 's')
- [ ] Add `l` keybinding for label application
- [ ] Add `L` keybinding for label management menu
- [ ] Update keybindings table in `M.get_keybinding()` function
- [ ] Add descriptions for all new keybindings

**Note**: Verify `s` is available. From research-001, current bindings show `s` and `S` for sync operations. May need to use `*` for star instead, or relocate sync bindings.

**Alternative if `s` conflicts**:
- Use `*` for star/flag toggle (Gmail convention)
- Or use `f` for flag (if available)

**Timing**: 20-25 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/config/ui.lua` - Add keybindings in `setup_email_list_keymaps()`

**Verification**:
- `u` toggles read/unread on current or selected emails
- `l` shows flag/label picker
- `L` shows management menu
- Star keybinding works (whichever key is used)

---

### Phase 5: Update Help Menu [COMPLETED]

**Goal**: Add new keybindings to context-aware help display

**Tasks**:
- [ ] Add "Flags & Labels:" section to help content
- [ ] Include `u`, `l`, `L`, and star keybinding with descriptions
- [ ] Position section appropriately (after Quick Actions)
- [ ] Note account-specific behavior in help text

**Help Content**:
```
Flags & Labels:
  u     Toggle read/unread
  *     Toggle star/flagged
  l     Apply label/flag
  L     Label management (create/delete)
```

**Timing**: 10-15 minutes

**Files to modify**:
- `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua` - Add section to `get_help_content()`

**Verification**:
- Help display (?) shows new Flags & Labels section
- All keybindings documented with descriptions

---

### Phase 6: Testing and Verification [COMPLETED]

**Goal**: Verify all functionality across accounts

**Tasks**:
- [ ] Test `u` toggle read/unread - single email and selection
- [ ] Test star toggle - single email and selection
- [ ] Test `l` flag picker - verify standard flags appear
- [ ] Test `l` on Gmail account - verify label application
- [ ] Test `l` on Protonmail account - verify `Labels/` prefix handling
- [ ] Test `L` create folder - verify folder created
- [ ] Test `L` delete folder - verify confirmation required, folder deleted
- [ ] Verify help menu displays correctly
- [ ] Test error handling for invalid operations

**Timing**: 20-30 minutes

**Verification**:
- All operations complete without errors
- Notifications appear appropriately
- Selection is cleared after bulk operations
- Email list refreshes after flag/label changes
- Account-aware logic works for both Gmail and Protonmail

## Testing & Validation

- [ ] Module loads: `nvim --headless -c "lua require('neotex.plugins.tools.himalaya.features.labels')" -c "q"`
- [ ] Keybindings registered: Open email list, verify `u`, `l`, `L` work
- [ ] Help menu updated: Press `?` in email list, verify Flags & Labels section
- [ ] Toggle read: Press `u`, verify email toggles seen/unseen
- [ ] Toggle star: Verify star keybinding toggles flagged
- [ ] Apply label: Select emails, press `l`, pick label, verify applied
- [ ] Create folder: Press `L`, select Create, enter name, verify created
- [ ] Delete folder: Press `L`, select Delete, pick folder, confirm, verify deleted
- [ ] Cross-account: Test with both Gmail and Protonmail accounts

## Artifacts & Outputs

- `lua/neotex/plugins/tools/himalaya/features/labels.lua` - New module
- `lua/neotex/plugins/tools/himalaya/config/ui.lua` - Updated with keybindings
- `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua` - Updated help content
- `specs/091_himalaya_label_management_keybindings/summaries/implementation-summary-YYYYMMDD.md` - Final summary

## Rollback/Contingency

If implementation fails:
1. Remove new `features/labels.lua` module
2. Revert changes to `config/ui.lua` (remove keybinding lines)
3. Revert changes to `ui/folder_help.lua` (remove Flags & Labels section)
4. Git reset to pre-implementation commit

All changes are additive and do not modify existing functionality, so rollback is straightforward.
