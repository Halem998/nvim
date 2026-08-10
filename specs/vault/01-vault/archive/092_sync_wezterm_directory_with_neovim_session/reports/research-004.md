# Research Report: Task #92 (Minimal Fix for New Tab Directory)

**Task**: 92 - Sync Wezterm terminal directory with Neovim session root
**Date**: 2026-02-24
**Focus**: Minimal fix so new WezTerm tabs open at shell's actual $PWD, not OSC 7-reported directory

## Summary

The root cause is now well-understood from prior research: Neovim emits OSC 7 escape sequences to update WezTerm's pane metadata (for tab titles). When the user opens a new tab (Leader+c), WezTerm's `SpawnTab("CurrentPaneDomain")` resolves the CWD using a priority order that prefers the OSC 7-reported directory over the shell's actual process CWD. After Neovim exits, the stale OSC 7 value persists because the fish shell's `__wezterm_osc7` hook only fires `--on-variable PWD` (i.e., only when the user changes directories), not on every prompt. This report evaluates four fix options and recommends **Option A (fish prompt hook)** as the minimal fix.

## The Problem Restated

```
Priority order for SpawnTab CWD (from WezTerm docs):
  1. OSC 7 value (pane metadata)        <-- Neovim's stale value wins here
  2. Process group leader CWD (/proc)   <-- shell's actual $PWD is here
  3. config.default_cwd
  4. Home directory
```

When the user is at a fish shell prompt after exiting Neovim:
- The shell's actual `$PWD` is correct (e.g., `~/`)
- WezTerm's pane metadata still holds Neovim's last OSC 7 value (e.g., `~/.config/nvim`)
- `SpawnTab("CurrentPaneDomain")` reads OSC 7 metadata first, so the new tab opens at `~/.config/nvim`

The user wants: new tabs open at the shell's actual `$PWD`.

## Option Analysis

### Option A: Fish Shell Emits OSC 7 on Every Prompt (RECOMMENDED)

Add a `fish_prompt` event handler that emits OSC 7 with the current `$PWD` on every prompt display. This overwrites Neovim's stale OSC 7 value as soon as the shell prompt appears after Neovim exits.

**Implementation** (in `~/.config/fish/config.fish`):

```fish
# WezTerm shell integration - update cwd
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end

    # Also emit OSC 7 on every prompt to override any stale values
    # from child processes (e.g., Neovim's OSC 7 for tab titles)
    function __wezterm_osc7_prompt --on-event fish_prompt
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end

    # Send initial cwd
    __wezterm_osc7
end
```

**How it works**:
1. Neovim emits OSC 7 with project directory while running (tab title updates work)
2. User exits Neovim
3. Fish shell displays prompt -> `fish_prompt` event fires -> OSC 7 emitted with shell's `$PWD`
4. WezTerm pane metadata is now correct
5. User presses Leader+c -> new tab opens at shell's actual `$PWD`

**Pros**:
- Minimal change: 4 lines of fish config
- No WezTerm config changes needed
- No Neovim config changes needed
- Self-healing: always corrects stale OSC 7 on every prompt
- Works with any program that might emit OSC 7 (not just Neovim)
- Tab title during Neovim usage is unaffected (Neovim continuously emits OSC 7 on BufEnter/DirChanged, overriding the prompt hook while Neovim is running)

**Cons**:
- Emits an extra OSC 7 on every prompt (negligible performance impact -- printf is fast)
- Brief moment between Neovim exit and prompt display where metadata is stale (sub-millisecond, not user-observable)

**Why the tab title is NOT affected during Neovim usage**: While Neovim is the foreground process, the fish prompt does not display, so `fish_prompt` does not fire. Neovim's OSC 7 emissions on `BufEnter` and `DirChanged` remain the most recent OSC 7 value. Only when Neovim exits and fish displays its prompt does the prompt hook fire, at which point overwriting the stale value is exactly what we want.

### Option B: Custom WezTerm Keybinding with Process CWD Query

Replace `SpawnTab("CurrentPaneDomain")` with a custom `action_callback` that queries the foreground process's actual CWD via `get_foreground_process_info().cwd`, bypassing OSC 7 metadata.

**Implementation** (in `~/.dotfiles/config/wezterm.lua`):

```lua
-- Replace the existing Leader+c keybinding:
{
  key = "c",
  mods = "LEADER",
  action = wezterm.action_callback(function(window, pane)
    -- Try to get the actual foreground process CWD (from /proc/PID/cwd)
    local info = pane:get_foreground_process_info()
    local cwd = nil
    if info and info.cwd and info.cwd ~= "" then
      cwd = info.cwd
    end

    if cwd then
      -- Spawn with the actual process CWD, bypassing OSC 7 metadata
      window:perform_action(
        act.SpawnCommandInNewTab {
          domain = "CurrentPaneDomain",
          cwd = cwd,
        },
        pane
      )
    else
      -- Fallback to default behavior
      window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
    end
  end),
},
```

**How it works**:
1. When user presses Leader+c, the callback fires
2. `pane:get_foreground_process_info()` reads `/proc/PID/cwd` of the foreground process
3. If the shell is in the foreground, this returns the shell's actual `$PWD`
4. The new tab is spawned with this CWD, ignoring OSC 7 metadata

**Pros**:
- Directly addresses the SpawnTab CWD resolution
- No shell config changes needed
- No Neovim config changes needed
- Uses WezTerm's native process inspection

**Cons**:
- Only fixes the Leader+c keybinding; does not fix other spawn paths (e.g., WezTerm's native Ctrl+Shift+T if configured, command palette new tab, etc.)
- `get_foreground_process_info()` only works for local panes (not remote/multiplexer)
- `get_foreground_process_info()` has a 300ms TTL cache, which could briefly return stale data
- When Neovim IS the foreground process (user presses Leader+c while in Neovim), the foreground process CWD would be Neovim's CWD, which may or may not be what's wanted
- More complex implementation than Option A
- Does NOT fix the stale pane metadata itself (tab title display after Neovim exits still shows wrong directory until shell emits OSC 7)

**Critical edge case**: If the user presses Leader+c while Neovim is running, `get_foreground_process_info()` returns Neovim's process info, and the CWD would be Neovim's current directory. This is actually the same as what OSC 7 would report, so the behavior is consistent in that case. The difference only matters when the user is at a shell prompt after Neovim exits.

### Option C: WezTerm `default_cwd` Configuration

Set `config.default_cwd` to override the fallback directory.

```lua
config.default_cwd = os.getenv("HOME")
```

**Assessment**: This does NOT help. WezTerm's priority order is OSC 7 > process CWD > default_cwd. Since OSC 7 is already set (stale value from Neovim), `default_cwd` is never consulted. This option is irrelevant to the problem.

### Option D: Neovim Emits "Reset" OSC 7 on Exit (VimLeavePre)

Add a `VimLeavePre` autocmd that emits OSC 7 with the parent shell's `$PWD` (captured at startup via `vim.env.PWD`).

**Implementation** (in `lua/neotex/config/autocmds.lua`):

```lua
-- Inside the existing if vim.env.WEZTERM_PANE block:
local shell_pwd = vim.env.PWD or vim.fn.expand("$HOME")

api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local hostname = vim.fn.hostname()
    local osc7 = string.format("\027]7;file://%s%s\007", hostname, shell_pwd)
    io.write(osc7)
    io.flush()
  end,
  desc = "WezTerm: Reset tab directory to shell CWD on exit",
})
```

**How it works**:
1. On `VimEnter`, capture `vim.env.PWD` (the parent shell's directory)
2. On `VimLeavePre`, emit OSC 7 with the captured shell directory
3. WezTerm metadata resets to the shell's directory before the shell prompt appears

**Pros**:
- Targeted: only runs when Neovim exits
- Fixes the root cause (stale OSC 7) at the source
- No shell or WezTerm config changes

**Cons**:
- `vim.env.PWD` may not always be accurate (e.g., if the shell changed directory before launching Neovim via a function or alias)
- Only fixes Neovim's stale OSC 7; does not fix stale values from other programs
- Timing: `VimLeavePre` fires before Neovim fully exits; there is a brief window where the OSC 7 is sent but the terminal is still in Neovim's alternate screen buffer -- the OSC 7 may or may not be processed depending on WezTerm's handling of escape sequences during alt-screen teardown
- If Neovim crashes or is killed with SIGKILL, `VimLeavePre` does not fire, leaving the metadata stale

## Comparison Matrix

| Criterion | Option A (Fish prompt) | Option B (WezTerm callback) | Option C (default_cwd) | Option D (VimLeavePre) |
|-----------|------------------------|---------------------------|----------------------|----------------------|
| Fixes new tab CWD | Yes | Yes (Leader+c only) | No | Yes |
| Fixes tab title | Yes | No | No | Yes |
| Lines of code | 4 | 15 | 1 | 10 |
| Files modified | 1 (fish config) | 1 (wezterm.lua) | 1 (wezterm.lua) | 1 (autocmds.lua) |
| Self-healing | Yes (every prompt) | No (per-spawn only) | No | No (only on exit) |
| Crash-safe | Yes | N/A | N/A | No |
| Works for all spawn paths | Yes | No (custom keybinds only) | No | Yes |
| Works for all programs | Yes | Yes (process-based) | No | No (Neovim only) |
| Performance impact | Negligible | Negligible | None | None |
| Preserves tab title in Neovim | Yes | N/A | N/A | Yes |

## Recommendation

**Option A (Fish prompt hook)** is the recommended minimal fix for these reasons:

1. **Smallest change**: 4 lines added to `~/.config/fish/config.fish`
2. **Self-healing**: Corrects stale OSC 7 from ANY program, not just Neovim
3. **Crash-safe**: Does not depend on child process exit handlers
4. **Complete coverage**: Fixes both new tab CWD and tab title display
5. **No timing issues**: The prompt hook fires after Neovim fully exits and the shell is ready
6. **Does not affect Neovim tab titles**: While Neovim runs, fish prompt does not display, so the hook does not fire

**Optional enhancement**: Combine Option A with Option D for defense-in-depth. Option D resets the OSC 7 slightly earlier (before the prompt displays), which provides a marginally faster correction. However, Option A alone is sufficient.

**Not recommended**: Option B is more complex, only fixes a single keybinding, and does not fix the tab title display issue. Option C is irrelevant.

## Implementation Plan

### Single change to `~/.config/fish/config.fish`:

Current code (lines 7-14):
```fish
# WezTerm shell integration - update cwd
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Send initial cwd
    __wezterm_osc7
end
```

Modified code:
```fish
# WezTerm shell integration - update cwd
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Emit OSC 7 on every prompt to override stale values from child processes
    function __wezterm_osc7_prompt --on-event fish_prompt
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Send initial cwd
    __wezterm_osc7
end
```

The only addition is the `__wezterm_osc7_prompt` function (3 lines plus 1 comment line).

### Verification Steps

1. Open WezTerm, note `$PWD` (e.g., `~/`)
2. Run `nvim` -- observe tab title changes to show Neovim project directory
3. Exit Neovim -- observe tab title updates to show shell's `$PWD` (the prompt hook fires)
4. Press Leader+c -- new tab should open at shell's `$PWD`, NOT Neovim's directory
5. Repeat with `cd /tmp && nvim && exit` to test different directories

## Files to Modify

- `~/.config/fish/config.fish` -- Add `__wezterm_osc7_prompt` function (4 lines)

No changes needed to:
- `~/.dotfiles/config/wezterm.lua` -- SpawnTab keybinding remains as-is
- `~/.config/nvim/lua/neotex/config/autocmds.lua` -- OSC 7 integration unchanged

## References

- [WezTerm Launching Programs: CWD Resolution Priority](https://wezterm.org/config/launch.html)
- [WezTerm default_cwd](https://wezterm.org/config/lua/config/default_cwd.html)
- [WezTerm SpawnTab](https://wezterm.org/config/lua/keyassignment/SpawnTab.html)
- [WezTerm SpawnCommandInNewTab](https://wezterm.org/config/lua/keyassignment/SpawnCommandInNewTab.html)
- [WezTerm SpawnCommand struct](https://wezterm.org/config/lua/SpawnCommand.html)
- [WezTerm get_foreground_process_info](https://wezterm.org/config/lua/pane/get_foreground_process_info.html)
- [WezTerm LocalProcessInfo](https://wezterm.org/config/lua/LocalProcessInfo.html)
- [WezTerm get_current_working_dir](https://wezterm.org/config/lua/pane/get_current_working_dir.html)
- [WezTerm procinfo.current_working_dir_for_pid](https://wezterm.org/config/lua/wezterm.procinfo/current_working_dir_for_pid.html)
- [WezTerm Shell Integration](https://wezterm.org/shell-integration.html)
- [WezTerm SpawnCommandInNewTab CWD Discussion (GitHub #6825)](https://github.com/wezterm/wezterm/discussions/6825)
- [WezTerm New Tab with Current Shell (GitHub #3634)](https://github.com/wezterm/wezterm/issues/3634)
- [Fish Shell function documentation](https://fishshell.com/docs/current/cmds/function.html)
- [Fish Shell fish_prompt event](https://fishshell.com/docs/current/cmds/fish_prompt.html)
- Research 001: Initial OSC 7 analysis
- Research 002: lastdir file approach for shell CWD persistence
- Research 003: Root cause diagnosis (OSC 7 metadata vs shell $PWD)

## Context Extension Recommendations

none

## Next Steps

1. Implement Option A by modifying `~/.config/fish/config.fish`
2. Verify with the test steps above
3. Optionally add Option D (VimLeavePre reset) for defense-in-depth
