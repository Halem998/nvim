# Implementation Summary: Task #587

**Completed**: 2026-05-21
**Duration**: ~30 minutes

## Overview

Replaced yanky.nvim with a lightweight 4-module custom yank ring under `lua/neotex/yank/`. The custom module captures yanks via `TextYankPost`, highlights via `vim.hl.on_yank()`, and provides a Telescope history picker with filetype-aware preview. All yanky.nvim references were removed from the codebase.

## What Changed

- `lua/neotex/yank/ring.lua` - Created: circular buffer with consecutive deduplication, most-recent-first order
- `lua/neotex/yank/highlight.lua` - Created: thin wrapper around `vim.hl.on_yank()`, respects macro execution check
- `lua/neotex/yank/telescope.lua` - Created: Telescope picker with buffer previewer; paste uses `setreg` + `normal! p` to avoid OSC 52 trigger
- `lua/neotex/yank/init.lua` - Created: entry point, registers `NeoTexYank` augroup with `TextYankPost` and `VimLeavePre` handlers
- `lua/neotex/plugins/tools/yank-ring.lua` - Created: lazy.nvim plugin spec using `dir` field, loads on `VeryLazy`, no keys table
- `lua/neotex/plugins/tools/init.lua` - Updated: switched `yanky_module` -> `yank_module`, loading `yank-ring` spec
- `lua/neotex/plugins/editor/telescope.lua` - Removed `"gbprod/yanky.nvim"` dependency and `load_extension("yank_history")` call
- `lua/neotex/plugins/editor/which-key.lua` - Updated `<leader>fy`, `<leader>yc`, `<leader>yh` to use `require("neotex.yank")` directly
- `lua/neotex/plugins/tools/yanky.lua` - Deleted

## Decisions

- Preserved `_G.YankyTelescopeHistory` global in yank-ring.lua config for backward compatibility with any existing references; which-key.lua calls were also updated to use direct requires
- Used `dir`-based local plugin spec (not a string repo spec) following the same pattern as himalaya-plugin in the same codebase
- No `keys` table in plugin spec to avoid lazy.nvim intercepting native y/p/P operators

## Plan Deviations

- **Task 3.8** skipped: interactive Telescope picker cannot be tested in headless mode; autocommands verified in Phase 1 via `nvim_get_autocmds`
- **Task 3.9** skipped: `:Lazy clean` requires interactive Neovim session; user should run manually to remove yanky.nvim from lazy-lock.json

## Verification

- Module loading: All 4 modules load without error in headless mode
- Autocommands: `NeoTexYank` augroup contains `TextYankPost` and `VimLeavePre` autocommands (verified)
- Plugin spec: `neotex.plugins.tools` includes yank dir spec (verified)
- yanky.lua: Deleted (verified)
- yanky references: No `require("yanky")` or `_G.YankyTelescopeHistory` calls remain in codebase
- Neovim startup: Clean, no errors

## Notes

To fully clean up yanky.nvim from the plugin manager, run `:Lazy clean` in Neovim to remove the yanky.nvim plugin from the lazy-lock.json lockfile. The plugin will no longer be loaded since no spec references it.
