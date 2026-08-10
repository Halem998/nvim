# Research Report: Task #94

**Task**: 94 - Fix WezTerm new tab spawn directory by overriding Leader+c keybinding
**Date**: 2026-02-24
**Focus**: WezTerm Lua API for implementing parent shell CWD detection in Leader+c keybinding

## Summary

All five WezTerm APIs required for the implementation are confirmed available and documented. The `LocalProcessInfo` struct has a `ppid` field, `wezterm.procinfo.current_working_dir_for_pid()` can read any process's CWD from `/proc/PID/cwd`, and `SpawnCommandInNewTab` accepts a `cwd` parameter. The implementation is straightforward with one important design consideration: when the foreground process IS a shell (user is at a prompt), we should use its CWD directly rather than looking up the parent. This report provides the exact code implementation with error handling.

## Context from Task 92

Task 92 researched the root cause of the new-tab-opens-in-wrong-directory problem across four reports. The key findings:

1. **Root cause**: Neovim emits OSC 7 escape sequences to update WezTerm's pane metadata for tab titles. After Neovim exits, the stale OSC 7 value persists and takes priority over the shell's actual `$PWD` when `SpawnTab("CurrentPaneDomain")` resolves the CWD.

2. **OSC 7 priority**: WezTerm resolves CWD in this order: (1) OSC 7 metadata, (2) process group leader CWD via `/proc/PID/cwd`, (3) `config.default_cwd`, (4) home directory.

3. **Task 92's recommended fix**: Add a `fish_prompt` event handler to emit OSC 7 on every prompt, which would overwrite stale values. Task 92 also documented "Option B" -- a custom WezTerm keybinding that bypasses OSC 7 entirely by reading process CWD.

Task 94 implements Option B from Task 92's research-004, providing a WezTerm-side fix for the Leader+c keybinding specifically.

## Findings

### 1. API Confirmation: `pane:get_foreground_process_info()`

**Confirmed available.** Returns a `LocalProcessInfo` struct or `nil`.

**LocalProcessInfo fields** (confirmed from documentation):

| Field | Type | Description |
|-------|------|-------------|
| `pid` | integer | Process identifier |
| `ppid` | integer | Parent process identifier |
| `name` | string | Short name for the process (may be truncated) |
| `executable` | string | Full path to executable (may be empty) |
| `cwd` | string | Current working directory (may be empty) |
| `argv` | table | Argument array for the process |
| `status` | string | Process state (Idle, Run, Sleep, Stop, Zombie, etc.) |
| `children` | table | Map of child PIDs to their LocalProcessInfo objects |

**Key finding**: The `ppid` field IS present on `LocalProcessInfo`. This allows looking up the parent process.

**Platform notes**:
- Linux: Queries the process group leader (foreground process) via `/proc/PID/cwd`
- Only works for local panes (not multiplexer/SSH panes)
- Has runtime overhead; should not be called in high-frequency events
- Available since WezTerm 20220624-141144-bd1b7c5d

**Installed version**: `wezterm 0-unstable-2026-01-17` (well past all requirements)

### 2. API Confirmation: `wezterm.procinfo.current_working_dir_for_pid(pid)`

**Confirmed available.** Returns a string path or `nil`.

```lua
-- Example
local cwd = wezterm.procinfo.current_working_dir_for_pid(12345)
-- Returns: "/home/user/projects/myproject" or nil
```

- Reads `/proc/PID/cwd` on Linux
- Returns `nil` if unable to read (permissions, process gone)
- Available since WezTerm 20220807-113146-c2fee766

### 3. API Confirmation: `SpawnCommandInNewTab` with `cwd` Parameter

**Confirmed available.** The `SpawnCommand` struct accepts these relevant fields:

| Field | Type | Description |
|-------|------|-------------|
| `cwd` | string (optional) | Working directory for the spawned process |
| `domain` | string (optional) | Multiplexer domain (default: `"CurrentPaneDomain"`) |
| `args` | array (optional) | Command and arguments (omit to use default shell) |

**Usage**:
```lua
window:perform_action(
  act.SpawnCommandInNewTab {
    domain = "CurrentPaneDomain",
    cwd = "/path/to/directory",
  },
  pane
)
```

When `cwd` is explicitly set, it overrides both OSC 7 metadata and process CWD resolution, which is exactly what we need.

### 4. API Confirmation: `wezterm.action_callback`

**Confirmed available.** The existing WezTerm config already uses this pattern in the `activate_global_tab` function (line 247 of `wezterm.lua`).

```lua
-- Signature
wezterm.action_callback(function(window, pane)
  -- window: GuiWindow object (has perform_action, window_id, etc.)
  -- pane: Pane object (has get_foreground_process_info, pane_id, etc.)
end)
```

Internally, `action_callback` registers a unique event and returns an `EmitEvent` action:
```lua
function wezterm.action_callback(callback)
  local event_id = '...'  -- unique id
  wezterm.on(event_id, callback)
  return wezterm.action.EmitEvent(event_id)
end
```

### 5. Alternative API: `wezterm.procinfo.get_info_for_pid(pid)`

**Available as an alternative.** Returns a full `LocalProcessInfo` struct for any PID, not just the foreground process. This could be used to look up the parent process directly:

```lua
local parent_info = wezterm.procinfo.get_info_for_pid(foreground_info.ppid)
```

However, `current_working_dir_for_pid` is lighter-weight since we only need the CWD, not the full process info.

### 6. Error Handling: Unavailable Process Info

**When `get_foreground_process_info()` returns `nil`**:
- Remote/multiplexer panes
- Process has exited between query and access
- Platform does not support it (FreeBSD)

**When `cwd` field is empty string**:
- Process has restricted `/proc` access
- Process exited between info retrieval and CWD read

**When `ppid` leads to a non-existent process**:
- Parent process exited (unusual for a shell, but possible)

**Recommended pattern**: Fall back to `SpawnTab("CurrentPaneDomain")` whenever any step fails.

### 7. Shell Detection Logic

The foreground process name needs to be checked to determine whether to use its CWD directly or look up the parent. Common shell names on this system:

| Shell | `name` field | `executable` field |
|-------|-------------|-------------------|
| fish | `fish` | `/nix/store/.../bin/fish` |
| bash | `bash` | `/nix/store/.../bin/bash` |
| zsh | `zsh` | `/nix/store/.../bin/zsh` |

On NixOS, the executable path is in `/nix/store/`, so matching by `name` (short name) is more reliable than matching by full executable path.

### 8. Design Decision: Two Scenarios

**Scenario A: User is at a shell prompt (foreground = fish)**
- `get_foreground_process_info()` returns fish process info
- The `cwd` field on the fish process is the shell's actual `$PWD`
- Use this CWD directly -- no need to look up parent

**Scenario B: User is inside Neovim (foreground = nvim)**
- `get_foreground_process_info()` returns nvim process info
- The `cwd` field is Neovim's CWD (project directory)
- The `ppid` field points to the parent shell (fish)
- Use `current_working_dir_for_pid(ppid)` to get the shell's `$PWD`
- This gives us the directory the user launched Neovim FROM

**Design question**: In Scenario B, should we use the parent shell's CWD or Neovim's CWD?

The task description says: "use parent shell's actual $PWD instead of OSC 7 metadata." This implies we always want the shell's CWD when a non-shell program is in the foreground. This makes sense because:
- The shell's CWD is where the user was working before launching the program
- If the user is inside Neovim at `~/.config/nvim` but their shell was at `~/projects/foo`, a new tab at `~/projects/foo` is more useful
- OSC 7 metadata (which currently drives `SpawnTab`) already provides the Neovim CWD if that is desired

However, there is a subtlety: when the user presses Leader+c while inside Neovim, they might WANT the new tab at Neovim's CWD (the project directory). The "parent shell CWD" approach would give them the directory they launched Neovim from, which could be `~/` if they used a session manager or launcher.

**Recommendation**: Use the foreground process's own CWD in all cases. This means:
- At a shell prompt: new tab opens at shell's `$PWD` (correct)
- Inside Neovim: new tab opens at Neovim's CWD (the project directory -- which is what the user would expect, and is also what OSC 7 reports)

The key difference from the current behavior is that at a shell prompt, we bypass the stale OSC 7 and read the shell's actual CWD from `/proc`. The ppid lookup is unnecessary for this approach.

### 9. Simpler Implementation: Use `cwd` from Foreground Process Directly

Since `LocalProcessInfo.cwd` reads from `/proc/PID/cwd` which is the real filesystem CWD (not OSC 7 metadata), we can simply use it directly:

```lua
local info = pane:get_foreground_process_info()
if info and info.cwd and info.cwd ~= "" then
  -- Bypass OSC 7 metadata, use actual process CWD
  window:perform_action(act.SpawnCommandInNewTab {
    domain = "CurrentPaneDomain",
    cwd = info.cwd,
  }, pane)
else
  -- Fallback to default behavior
  window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
end
```

This is simpler and handles both scenarios correctly:
- Shell at prompt: uses shell's `$PWD` from `/proc`
- Inside Neovim: uses Neovim's CWD from `/proc`

Both bypass the stale OSC 7 metadata.

### 10. Alternative: ppid-Based Parent Shell CWD Lookup

If the task requirement truly is "always use the parent shell's CWD" (even when inside Neovim), the ppid approach works:

```lua
local info = pane:get_foreground_process_info()
local cwd = nil

if info then
  local shells = { fish = true, bash = true, zsh = true, sh = true, nu = true }
  if shells[info.name] then
    -- Foreground IS a shell -- use its CWD directly
    cwd = info.cwd
  elseif info.ppid then
    -- Foreground is NOT a shell -- use parent's CWD
    cwd = wezterm.procinfo.current_working_dir_for_pid(info.ppid)
  end
end

if cwd and cwd ~= "" then
  window:perform_action(act.SpawnCommandInNewTab {
    domain = "CurrentPaneDomain",
    cwd = cwd,
  }, pane)
else
  window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
end
```

## Recommended Implementation

Based on the analysis, I recommend the **simpler approach** (Section 9) that uses the foreground process's own CWD. This is because:

1. The primary problem is stale OSC 7 after Neovim exits (user is at shell prompt)
2. When at a shell prompt, `get_foreground_process_info()` returns the shell, and its `cwd` is the correct `$PWD`
3. When inside Neovim, using Neovim's CWD (project directory) is the expected behavior
4. No shell name detection is needed
5. No parent process lookup is needed
6. The code is half the size

### Exact Code for wezterm.lua

Replace lines 427-431:

```lua
-- Current code:
{
  key = "c",
  mods = "LEADER",
  action = act.SpawnTab("CurrentPaneDomain"),
},
```

With:

```lua
-- New code: spawn tab using actual process CWD (bypasses stale OSC 7 metadata)
{
  key = "c",
  mods = "LEADER",
  action = wezterm.action_callback(function(window, pane)
    -- Read the foreground process's actual CWD from /proc/PID/cwd
    -- This bypasses WezTerm's OSC 7 metadata which may be stale
    -- (e.g., after exiting Neovim, OSC 7 still reports Neovim's directory)
    local info = pane:get_foreground_process_info()
    if info and info.cwd and info.cwd ~= "" then
      window:perform_action(
        act.SpawnCommandInNewTab {
          domain = "CurrentPaneDomain",
          cwd = info.cwd,
        },
        pane
      )
    else
      -- Fallback: use default SpawnTab behavior (OSC 7 -> process CWD -> default)
      window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
    end
  end),
},
```

### Alternative Code with ppid Lookup (if parent shell CWD is required)

If the requirement is specifically to always use the parent shell's CWD (even when inside Neovim):

```lua
{
  key = "c",
  mods = "LEADER",
  action = wezterm.action_callback(function(window, pane)
    local info = pane:get_foreground_process_info()
    local cwd = nil

    if info then
      -- Check if the foreground process is a shell
      local shells = { fish = true, bash = true, zsh = true, sh = true, nu = true }
      if shells[info.name] then
        -- At a shell prompt: use the shell's actual CWD
        cwd = info.cwd
      elseif info.ppid then
        -- Inside a program (nvim, etc.): use the parent shell's CWD
        cwd = wezterm.procinfo.current_working_dir_for_pid(info.ppid)
      end
    end

    if cwd and cwd ~= "" then
      window:perform_action(
        act.SpawnCommandInNewTab {
          domain = "CurrentPaneDomain",
          cwd = cwd,
        },
        pane
      )
    else
      window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
    end
  end),
},
```

## Edge Cases and Caveats

### 1. Performance

`get_foreground_process_info()` has runtime overhead (reads `/proc`). For a keybinding that fires on user input, this is negligible -- the overhead matters for high-frequency events like `update-status` (every 500ms), not for occasional keypresses.

### 2. Remote/Multiplexer Panes

`get_foreground_process_info()` returns `nil` for non-local panes. The fallback to `SpawnTab("CurrentPaneDomain")` handles this correctly.

### 3. NixOS Executable Paths

On NixOS, `info.executable` contains `/nix/store/...` paths. The `info.name` field provides the short process name (e.g., "fish", "nvim") which is more reliable for shell detection. Confirmed by the existing config's use of process info in `update-status` handlers.

### 4. Multiple Nested Processes

If the user runs `fish -> tmux -> nvim`, the foreground process would be `nvim`, and `ppid` would point to `tmux` (not `fish`). The ppid approach would get tmux's CWD. For the simpler approach (foreground CWD only), this is not an issue.

### 5. Very Short-Lived Foreground Processes

If `get_foreground_process_info()` is called at the exact moment a process is starting or ending, the CWD might be empty or the process might not exist. The fallback handles this.

### 6. Fish Shell's $PWD vs /proc CWD

Fish shell's `$PWD` and `/proc/PID/cwd` should always agree on Linux. The `/proc/PID/cwd` symlink is maintained by the kernel and reflects the actual CWD of the process.

### 7. Compatibility with Task 92 Fix

Task 92 implemented Option A (fish `__wezterm_osc7_prompt` hook) which emits OSC 7 on every prompt. That fix and this keybinding fix are complementary:
- Task 92's fix: corrects the pane metadata (tab title display, other spawn methods)
- Task 94's fix: bypasses metadata entirely for Leader+c (direct CWD query)

Both can coexist. If Task 92 is not implemented, Task 94 still fixes the Leader+c keybinding. If both are implemented, there is no conflict.

## Verification Plan

1. Open WezTerm, `cd /tmp`, verify `pwd` shows `/tmp`
2. Run `nvim` (opens with project CWD, e.g., `~/.config/nvim`)
3. Exit Neovim with `:q`
4. Verify `pwd` shows `/tmp` (shell CWD unchanged)
5. Press Leader+c (Ctrl+Space, c) to spawn new tab
6. Verify new tab opens at `/tmp` (not `~/.config/nvim`)
7. Go back to original tab, run `nvim` again
8. While inside Neovim, press Leader+c
9. Verify new tab opens at Neovim's CWD (the project directory)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `get_foreground_process_info()` returns nil | Low | Fallback to `SpawnTab("CurrentPaneDomain")` |
| `cwd` field is empty string | Low | Check `cwd ~= ""` before using |
| Performance overhead | Negligible | Only fires on keypress, not in event loops |
| Remote pane incompatibility | Low | Fallback handles remote panes |
| Nested process hierarchy (tmux) | Low | Simpler approach avoids ppid issues |

## Decisions

1. **Use the simpler approach** (foreground process CWD directly) rather than the ppid-based parent shell lookup
2. **Fall back to `SpawnTab("CurrentPaneDomain")`** when process info is unavailable
3. **No logging needed** in the callback -- the fallback handles all error cases gracefully
4. **No shell name detection needed** for the simpler approach
5. **Complementary to Task 92** -- both fixes can coexist without conflict

## References

- [WezTerm LocalProcessInfo](https://wezterm.org/config/lua/LocalProcessInfo.html) -- struct with pid, ppid, name, cwd, executable, argv, status, children
- [WezTerm get_foreground_process_info()](https://wezterm.org/config/lua/pane/get_foreground_process_info.html) -- returns foreground process info for local panes
- [WezTerm procinfo.current_working_dir_for_pid()](https://wezterm.org/config/lua/wezterm.procinfo/current_working_dir_for_pid.html) -- reads /proc/PID/cwd
- [WezTerm procinfo.get_info_for_pid()](https://wezterm.org/config/lua/wezterm.procinfo/get_info_for_pid.html) -- full LocalProcessInfo for any PID
- [WezTerm SpawnCommandInNewTab](https://wezterm.org/config/lua/keyassignment/SpawnCommandInNewTab.html) -- spawn tab with SpawnCommand struct
- [WezTerm SpawnCommand struct](https://wezterm.org/config/lua/SpawnCommand.html) -- cwd, domain, args, label, set_environment_variables
- [WezTerm action_callback](https://wezterm.org/config/lua/wezterm/action_callback.html) -- register custom callback actions
- [WezTerm SpawnTab](https://wezterm.org/config/lua/keyassignment/SpawnTab.html) -- default tab spawning
- [WezTerm Shell Integration](https://wezterm.org/config/lua/config/default_cwd.html) -- CWD resolution priority
- [GitHub Discussion #6825: SpawnCommandInNewTab cwd](https://github.com/wezterm/wezterm/discussions/6825) -- confirmed pattern for action_callback + SpawnCommandInNewTab + cwd
- [GitHub Issue #3634: New tab with current shell](https://github.com/wezterm/wezterm/issues/3634) -- related discussion
- Task 92 Research Reports (001-004) -- root cause analysis and alternative approaches

## Context Extension Recommendations

none

## Next Steps

1. Create implementation plan with the exact code change to `/home/benjamin/.dotfiles/config/wezterm.lua`
2. Implementation is a single change: replace lines 427-431 (the Leader+c keybinding) with the `action_callback` version
3. Test using the verification plan above
