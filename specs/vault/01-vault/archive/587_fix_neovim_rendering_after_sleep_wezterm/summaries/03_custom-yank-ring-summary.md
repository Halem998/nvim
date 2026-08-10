# Implementation Summary: Task #587

**Completed**: 2026-05-21
**Duration**: ~1 hour

## Overview

Replaced yanky.nvim with a custom yank ring module (~270 LOC across 6 modules under `lua/neotex/yank/`). The root cause of post-sleep Neovim freezing was yanky.nvim's `system_clipboard.sync_with_ring = true`, which triggered a blocking `wl-paste` call via `FocusGained` on wake. The custom implementation uses `vim.system()` with a 2-second timeout for all clipboard reads, making it structurally impossible for Wayland clipboard staleness to freeze Neovim.

## What Changed

- `lua/neotex/yank/ring.lua` -- Created: fixed-size circular buffer (65 LOC)
- `lua/neotex/yank/clipboard.lua` -- Created: non-blocking clipboard via `vim.system()` (130 LOC)
- `lua/neotex/yank/highlight.lua` -- Created: thin wrapper around `vim.hl.on_yank()` (22 LOC)
- `lua/neotex/yank/recovery.lua` -- Created: post-sleep rendering recovery (35 LOC)
- `lua/neotex/yank/telescope.lua` -- Created: Telescope picker for yank history (70 LOC)
- `lua/neotex/yank/init.lua` -- Created: entry point, setup, autocommands (105 LOC)
- `lua/neotex/plugins/tools/yank-ring.lua` -- Created: lazy.nvim plugin spec (55 LOC)
- `lua/neotex/plugins/tools/yanky.lua` -- Deleted
- `lua/neotex/plugins/tools/init.lua` -- Updated: yanky_module -> yank_ring_module
- `lua/neotex/plugins/editor/telescope.lua` -- Removed yanky dependency and extension load
- `lua/neotex/plugins/editor/which-key.lua` -- Updated 3 references: YankyTelescopeHistory -> YankTelescopeHistory, require("yanky") -> require("neotex.yank")

## Decisions

- **Global function naming**: Changed `_G.YankyTelescopeHistory` to `_G.YankTelescopeHistory` to distinguish from the old yanky-based implementation.
- **Recovery bundled**: Post-sleep rendering recovery (`:mode`, `:redraw!`, treesitter invalidation) is registered in the same `NeoTexYank` augroup alongside FocusGained clipboard sync, since both address the same user-facing issue.
- **5 autocommands registered**: TextYankPost, FocusGained (clipboard sync), FocusGained (recovery), VimResume (recovery), VimLeavePre (cleanup). The two FocusGained handlers are registered separately from recovery.setup() and clipboard sync, which is by design.
- **wl-paste detected**: System correctly identifies Wayland via `WAYLAND_DISPLAY=wayland-0`.

## Plan Deviations

- None (implementation followed plan exactly)

## Verification

- Neovim startup: Success (exit 0, "Startup OK")
- Module loading: All 6 modules + plugin spec load without error
- Autocommand registration: 5 autocmds in NeoTexYank augroup
- Wayland detection: wl-paste command correctly detected
- Recovery function: `type(r.recover)` returns "function"
- No yanky references: Zero functional references in telescope.lua or which-key.lua

## Notes

- The `lazy-lock.json` yanky.nvim entry will be cleaned up automatically when `:Lazy clean` is run or on next `:Lazy sync`. This requires manual action in a live Neovim session.
- Post-sleep freeze fix will be confirmed through manual testing (put computer to sleep with focused WezTerm Neovim tab).
- The Telescope yank history picker (`<leader>fy` and `<leader>yh`) now uses `vim.fn.setreg` + `vim.cmd('normal! "+p')` instead of yanky's `use_temporary_register` API, which is a more straightforward and maintainable approach.
