# Implementation Plan: Add <leader>al AI Commands Loader Picker

- **Task**: 519 - Add <leader>al AI commands loader picker
- **Status**: [COMPLETED]
- **Effort**: < 1 hour
- **Dependencies**: 518 (reuses ai-tool-picker.lua infrastructure)
- **Research Inputs**: specs/519_add_leader_al_ai_commands_loader_picker/reports/01_commands-loader-picker.md
- **Artifacts**: plans/01_commands-loader-picker.md (this file)
- **Standards**:
  - .opencode/rules/artifact-formats.md
  - .opencode/rules/state-management.md
- **Type**: neovim

## Overview

Add `<leader>al` keymap that opens a unified `vim.ui.select` picker (Claude Code vs OpenCode, last-used-first ordering) routing to their respective commands/extension pickers. Reuses task 518's `ai-tool-picker.lua` persistence infrastructure. Two files changed: `ai-tool-picker.lua` (+~25 lines) and `which-key.lua` (+~12 lines). 30 min effort.

## Research Integration

Research report `01_commands-loader-picker.md` confirmed:
- Existing `show_tool_picker()` hardcodes session routing — need separate function
- Visual mode requires mode-aware dispatch in callback
- All infrastructure exists: persistence, picker pattern, command facades

## Goals & Non-Goals

- **Goals**:
  - Add `show_commands_picker()` to `ai-tool-picker.lua` routing to ClaudeCommands/OpencodeCommands
  - Support both normal mode (commands browser) and visual mode (send selection with prompt)
  - Reuse existing `tool-prefs.json` for last-tool-first ordering
  - Add `<leader>al` to which-key group
  - Update documentation (header comments, AI_TOOLING.md, MAPPINGS.md)
- **Non-Goals**:
  - No session management (handled by `<C-CR>`)
  - No new persistence files
  - No keymaps.lua body changes (all in which-key.lua)
  - No third tool support

## Risks & Mitigations

- **Risk**: `nvim_get_mode().mode` returns wrong value in picker callback. **Mitigation**: Mode is captured before `vim.ui.select` runs and is stable.
- **Risk**: `<leader>al>` conflicts with existing keymaps. **Mitigation**: Confirmed no `<leader>al>` binding exists.
- **Risk**: Which-key visual/normal mode collision. **Mitigation**: Use `mode` field to disambiguate — same pattern as `<leader>ac>` and `<leader>ao>`.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add show_commands_picker and <leader>al keymaps [COMPLETED]

- **Goal:** Add unified AI commands picker function and keybindings
- **Tasks:**
  - [ ] Add `show_commands_picker()` function to `ai-tool-picker.lua` after `show_tool_picker()` (line 164)
  - [ ] Function presents `vim.ui.select` with Claude Code vs OpenCode, last-tool-first
  - [ ] Normal mode callback: `vim.cmd("ClaudeCommands")` or `vim.cmd("OpencodeCommands")`
  - [ ] Visual mode callback: `send_visual_to_{tool}_with_prompt()`
  - [ ] Add `<leader>al>` normal mode entry to which-key.lua (desc: "ai load commands/agents")
  - [ ] Add `<leader>al>` visual mode entry to which-key.lua (desc: "ai send selection with prompt")
  - [ ] Update `keymaps.lua` header comments (lines 24 and 78) with `<leader>al>` line
  - [ ] Update `docs/AI_TOOLING.md` keybindings list and picker table
  - [ ] Update `docs/MAPPINGS.md` with new `<leader>al>` row
  - [ ] Verify: `<leader>al>` in normal mode -> picker -> commands browser opens
  - [ ] Verify: `<leader>al>` in visual mode -> picker -> sends selection with prompt
- **Timing:** ~30 minutes
- **Depends on:** none

## Testing & Validation

- [ ] `<leader>al>` in normal mode shows picker with Claude Code / OpenCode
- [ ] Last-used tool appears first after selection
- [ ] Selecting Claude in normal mode opens `ClaudeCommands` picker
- [ ] Selecting OpenCode in normal mode opens `OpencodeCommands` picker
- [ ] Selecting Claude in visual mode sends selection with prompt
- [ ] Selecting OpenCode in visual mode sends selection with prompt
- [ ] Cancelling picker (Esc) does nothing
- [ ] Pickers open within Telescope UI framework already in use

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (modified — add `show_commands_picker()`)
- `lua/neotex/plugins/editor/which-key.lua` (modified — add `<leader>al>` entries)
- `lua/neotex/config/keymaps.lua` (modified — header comments only)
- `docs/AI_TOOLING.md` (modified — keybindings and picker tables)
- `docs/MAPPINGS.md` (modified — new row)

## Rollback/Contingency

- `<leader>al>` not visible in which-key: verify which-key.lua syntax, check for duplicate key conflicts
- Commands picker doesn't open: verify `ClaudeCommands`/`OpencodeCommands` user commands are registered (they are)
- Visual mode doesn't send selection: verify `send_visual_to_{tool}_with_prompt()` functions exist (they do)
- Full revert: remove `show_commands_picker()` from ai-tool-picker.lua, remove `<leader>al>` entries from which-key.lua
