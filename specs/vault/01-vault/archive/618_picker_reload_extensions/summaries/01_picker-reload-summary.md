# Implementation Summary: Task #618

**Completed**: 2026-05-25
**Duration**: ~30 minutes

## Overview

Added reload functionality to the `<leader>al` extension picker. Two features were implemented: a Unload/Reload/Cancel submenu when pressing `<CR>` on a loaded extension, and a new `[Reload All]` special entry that reloads all loaded extensions in dependency-safe order.

## What Changed

- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` — Replaced direct unload with `vim.ui.select` submenu for loaded extensions; added `is_reload_all` handler; updated all four Ctrl-l/u/s/e guard conditions to skip `[Reload All]` entry
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` — Added `[Reload All]` special entry in `create_special_entries()` after `[Keyboard Shortcuts]` so it appears just above it in the descending-sort picker

## Decisions

- `vim.schedule()` wraps `vim.ui.select` in the submenu to ensure Telescope closes fully before the select dialog appears
- `[Reload All]` sorts non-core extensions first, core extension last, to maintain dependency-safe reload order
- After any submenu choice (Unload, Reload, Cancel, or Esc/nil), the picker reopens with cursor restore (`_restore_extension_name`) for consistent UX
- The inline reload-all loop collects errors per extension and shows a summary notification rather than failing on first error

## Plan Deviations

- None (implementation followed plan)

## Verification

- Neovim startup: Success (both files pass `nvim --headless dofile` without errors)
- Module loading: Success
- Checkhealth: N/A (no new dependencies)

## Notes

The `is_load_all` entry does not exist in the current `entries.lua` (only a handler exists in `init.lua` as a legacy stub). The `[Reload All]` entry follows the `[Keyboard Shortcuts]` pattern with its own sentinel flag `is_reload_all`.
