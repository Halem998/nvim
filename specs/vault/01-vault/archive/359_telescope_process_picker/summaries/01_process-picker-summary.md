# Implementation Summary: Task #359

**Completed**: 2026-04-03
**Duration**: 10 minutes

## Changes Made

Created a standalone telescope picker module for viewing and managing background processes tracked by `neotex.util.process`. The picker displays processes in fixed-width columns (name, command, port, uptime, status) with a buffer previewer showing full metadata and recent stdout/stderr output from ring buffers.

## Files Modified

- `lua/neotex/plugins/tools/process-picker.lua` - Created new file (~254 lines): telescope picker with entry maker, buffer previewer, kill action (CR with auto-refresh), and browser open action (C-o)

## Verification

- Build: N/A (utility module, no build step)
- Tests: N/A (requires running Neovim with telescope)
- Files verified: Yes
- Not referenced in tools/init.lua: Confirmed

## Notes

- The module is a utility, not a lazy.nvim plugin spec. It exports `M.show()` for use by which-key mappings (task 360).
- Uses `process.get(id)` in the previewer to access full registry entries with stdout/stderr ring buffers, since `process.list()` returns lightweight info tables without buffers.
- The `<CR>` action kills the selected process and re-opens the picker via `vim.defer_fn` (100ms delay) only if processes remain.
- Cross-platform browser opening: uses `open` on macOS, `xdg-open` on Linux.
