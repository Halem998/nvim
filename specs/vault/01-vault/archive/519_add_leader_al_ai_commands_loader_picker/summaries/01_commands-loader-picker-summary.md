# Implementation Summary: Add <leader>al AI Commands Loader Picker

## What was done

### Files modified

- **`lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`** (+25 lines): Added `show_commands_picker()` function after `show_tool_picker()`. Uses `vim.ui.select` with Claude Code vs OpenCode, last-tool-first reordering via shared `tool-prefs.json`. Normal mode routes to `ClaudeCommands`/`OpencodeCommands` user commands. Visual mode routes to `send_visual_to_{tool}_with_prompt()` functions.

- **`lua/neotex/plugins/editor/which-key.lua`** (+12 lines): Added `<leader>al` keymaps — normal mode variant (desc: "ai load commands/agents") and visual mode variant (desc: "ai send selection with prompt"). Both use lazy init pattern matching `<leader>as`.

- **`lua/neotex/config/keymaps.lua`** (+2 lines): Added `<leader>al` to header comments at both locations (lines 24 and 79).

## Key design decisions

- Separate `show_commands_picker()` function rather than modifying `show_tool_picker()` — keeps session and commands routing independent
- Mode detection via `vim.api.nvim_get_mode().mode` captured before `vim.ui.select` callback for visual block mode support
- Reuses existing `tool-prefs.json` persistence — user's tool preference consistent across `<C-CR>` and `<leader>al>
