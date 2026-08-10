# Implementation Summary: Task #94

**Completed**: 2026-02-24
**Duration**: 10 minutes

## Changes Made

Replaced the WezTerm `Leader+c` keybinding to fix new tab spawn directory behavior. The original keybinding used `act.SpawnTab("CurrentPaneDomain")` which relied on WezTerm's OSC 7 metadata for CWD determination. This metadata becomes stale after exiting programs like Neovim (OSC 7 still reports Neovim's directory instead of the shell's current directory).

The new implementation uses `wezterm.action_callback` to query the foreground process's actual CWD via `pane:get_foreground_process_info()`, which reads from `/proc/PID/cwd`. This bypasses the stale OSC 7 metadata.

## Files Modified

- `/home/benjamin/.dotfiles/config/wezterm.lua` - Replaced Leader+c keybinding (lines 426-446) with custom action_callback that reads foreground process CWD

## Implementation Details

The new keybinding:
1. Calls `pane:get_foreground_process_info()` to get the foreground process's actual CWD
2. If CWD is available, spawns a new tab with `act.SpawnCommandInNewTab` using the explicit `cwd` parameter
3. If CWD is unavailable (e.g., remote panes), falls back to the default `act.SpawnTab("CurrentPaneDomain")` behavior

## Verification

- Lua syntax: File structure preserved, valid Lua code
- WezTerm will reload config automatically on save
- Manual testing scenarios:
  - At shell prompt in `/tmp`, press `Leader+c` -- new tab should open at `/tmp`
  - Run `nvim` from `/tmp`, exit with `:q`, press `Leader+c` -- new tab should open at `/tmp` (not stale Neovim CWD)
  - Inside Neovim (CWD is project dir), press `Leader+c` -- new tab should open at Neovim's CWD

## Notes

This fix is complementary to Task 92 (emit OSC 7 from shell prompt hook), which handles the root cause of stale OSC 7 metadata. However, this fix provides immediate relief for the `Leader+c` keybinding specifically, and the foreground process CWD approach is more reliable than OSC 7 for determining the actual working directory.
