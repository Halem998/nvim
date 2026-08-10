# Research Report: Task #72 - Fix Himalaya Sidebar Leader Keybindings in Help

**Task**: 72 - Fix Himalaya sidebar help showing leader keybindings that conflict with toggle selection
**Language**: neovim  
**Started**: 2026-03-13T19:00:00Z  
**Completed**: 2026-03-13T20:00:00Z  
**Effort**: 1 hour  
**Dependencies**: None  
**Sources/Inputs**: 
- Codebase analysis of Himalaya plugin
- folder_help.lua (line 61 comment about leader conflict)
- which-key.lua (leader keybinding definitions)
- config/ui.lua (sidebar keymap configuration)
- Git history (commit 7b6f3f74)

---

## Executive Summary

The issue was that the Himalaya sidebar help display (triggered by pressing `?` in the sidebar buffer) was incorrectly showing leader keybindings (`<leader>mA`, `<leader>mf`, `<leader>ms`) in the Folder Management section. Since the leader key is mapped to `<Space>` and `<Space>` is used for toggle selection in the sidebar buffer, these leader keybindings cannot function in the sidebar context.

**Key Findings**:
1. The fix has already been implemented in `folder_help.lua` (lines 61-62)
2. The folder management section was removed from help content
3. Sidebar now shows only single-key bindings that don't conflict with `<Space>`
4. Leader keybindings still work globally via which-key but are not displayed in sidebar help

---

## Context & Scope

### Problem Description
When viewing the Himalaya email sidebar and pressing `?` to show help, the Folder Management section was displaying leader keybindings:
- `<leader>mA` - Switch account
- `<leader>mf` - Change folder  
- `<leader>ms` - Sync folder

These keybindings don't work in the sidebar buffer because:
1. The leader key is mapped to `<Space>` in this Neovim configuration
2. `<Space>` is already used for toggle selection in the sidebar buffer (see `config/ui.lua` line 208)
3. This creates a keybinding conflict

### Scope of Research
- Locate help content definition for sidebar
- Identify where leader keybindings were being displayed
- Verify current state of fix
- Document recommended approach

---

## Findings

### Codebase Patterns

#### 1. Help Content Definition
**File**: `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua`

The help content is built in `M.get_help_content(folder_type)` function (lines 44-194). Key sections:

```lua
-- Line 53-59: Selection section (showing <Space> toggle)
local base_selection = {
  "Selection:",
  "  <Space>   - Toggle selection",
  "  n         - Select email",
  "  p         - Deselect email",
  ""
}

-- Line 61-62: Folder management section (REMOVED)
-- Folder management section removed - <leader> mappings conflict with <Space> toggle in sidebar
local base_folder_mgmt = {}
```

**Analysis**: Lines 61-62 clearly document that the folder management section was removed due to the leader/space conflict.

#### 2. Sidebar Keymap Configuration
**File**: `lua/neotex/plugins/tools/himalaya/config/ui.lua`

Sidebar keymaps are defined in `M.setup_sidebar_keymaps(bufnr)` (lines 520-580):

```lua
-- Line 208: Space toggle selection in email list
keymap('n', '<Space>', function()
  local ok, email_list = pcall(require, 'neotex.plugins.tools.himalaya.ui.email_list')
  if ok and email_list.toggle_selection then
    email_list.toggle_selection()
  end
end, vim.tbl_extend('force', opts, { desc = 'Toggle email selection' }))

-- Lines 565-571: Single-key account switch (replacement for leader)
keymap('n', 'a', function()
  local ok, commands = pcall(require, 'neotex.plugins.tools.himalaya.commands.ui')
  if ok and commands.switch_account then
    commands.switch_account()
  end
end, vim.tbl_extend('force', opts, { desc = 'Switch account' }))
```

**Analysis**: The sidebar uses single-key bindings ('a' for switch account, 'c' for change folder) instead of leader keybindings.

#### 3. Global Leader Keybindings
**File**: `lua/neotex/plugins/editor/which-key.lua`

Global leader keybindings are defined for mail operations (lines 499-515):

```lua
{ "<leader>mA", "<cmd>HimalayaAccounts<CR>", desc = "switch account", icon = "" },
{ "<leader>mf", "<cmd>HimalayaFolder<CR>", desc = "change folder", icon = "" },
{ "<leader>ms", "<cmd>HimalayaSyncInbox<CR>", desc = "sync inbox", icon = "" },
```

**Analysis**: These global leader keybindings still exist and work when NOT in the sidebar buffer. They are properly scoped to normal mode outside of the himalaya sidebar.

### External Resources

No external documentation was required as this is an internal codebase issue related to keybinding conflicts.

---

## Decisions

### Decision 1: Remove Leader Keybindings from Sidebar Help
**Status**: Already implemented  
**Rationale**: Leader keybindings (mapped to `<Space>`) conflict with the toggle selection functionality in the sidebar buffer.  
**Implementation**: Set `base_folder_mgmt = {}` to remove the folder management section entirely.

### Decision 2: Use Single-Key Bindings in Sidebar
**Status**: Already implemented  
**Rationale**: Single-key bindings ('a', 'c', 'r') don't conflict with any existing functionality.  
**Implementation**: See `config/ui.lua` lines 520-580 for sidebar keymap definitions.

### Decision 3: Preserve Global Leader Keybindings
**Status**: Already implemented  
**Rationale**: Global leader keybindings (`<leader>mA`, etc.) are still useful when outside the sidebar buffer.  
**Implementation**: Kept in `which-key.lua` with no changes needed.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Users confused about missing leader keybindings in help | Low | Help text now shows single-key alternatives ('a', 'c', etc.) |
| Users try to use leader keybindings in sidebar | Low | They won't work due to `<Space>` conflict, but single-key alternatives exist |
| Documentation inconsistencies | Medium | README.md still lists leader keybindings as general reference (acceptable) |

---

## Context Extension Recommendations

**Topic**: Himalaya keybinding architecture  
**Gap**: No consolidated documentation explaining the relationship between global leader keybindings and buffer-local single-key bindings.  
**Recommendation**: Add context file at `.claude/context/plugins/himalaya-keybindings.md` documenting:
- Global leader keybindings (which-key)
- Sidebar-specific keybindings (config/ui.lua)
- Email list keybindings (config/ui.lua)
- Compose buffer keybindings (config/ui.lua)
- The rationale for different binding schemes per buffer

---

## Appendix

### Search Queries Used
1. `grep -rn "himalaya" --include="*.lua"` - Found all Himalaya-related files
2. `grep -rn "sidebar" --include="*.lua"` - Found sidebar-specific code
3. `grep -rn "show_help\|help.*sidebar" --include="*.lua"` - Found help display code
4. `grep -n "leader\|<leader>" folder_help.lua` - Found leader keybinding references
5. `git log --oneline --grep="himalaya"` - Found related git history

### Relevant File Paths
| File | Purpose | Lines |
|------|---------|-------|
| `lua/neotex/plugins/tools/himalaya/ui/folder_help.lua` | Help content definition | 1-305 |
| `lua/neotex/plugins/tools/himalaya/config/ui.lua` | Keymap configurations | 136-580 |
| `lua/neotex/plugins/tools/himalaya/commands/ui.lua` | UI commands including show_help | 1-656 |
| `lua/neotex/plugins/editor/which-key.lua` | Global leader keybindings | 499-515 |
| `lua/neotex/plugins/tools/himalaya/ui/sidebar.lua` | Sidebar implementation | 1-544 |

### Git History
- Commit `7b6f3f74`: "task 72: create fix himalaya sidebar help showing leader keybindings" - Created the task
- Commit `c6367f24`: "task 86: create Fix himalaya sent folder display and add missing sidebar keybindings" - Related sidebar improvements

---

## Summary

**Current Status**: The fix has already been implemented in the codebase. The folder management section was removed from `folder_help.lua` (lines 61-62) to prevent showing leader keybindings that conflict with the `<Space>` toggle selection in the sidebar buffer.

**Recommended Action**: 
1. Mark task as complete
2. Verify fix is working by:
   - Opening Himalaya sidebar (`<leader>mm`)
   - Pressing `?` to show help
   - Confirming no leader keybindings (`<leader>mA`, etc.) appear in help
   - Confirming single-key alternatives ('a' for account, 'c' for change folder) are shown

**No code changes required** - the fix is already in place.
