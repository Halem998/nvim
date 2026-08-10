# Research Report: Task #92 (Diagnostic Investigation)

**Task**: 92 - Sync Wezterm terminal directory with Neovim session root
**Date**: 2026-02-24
**Focus**: Diagnose what is currently causing WezTerm directory to change inconsistently

## Summary

The user reports that WezTerm tabs end up in unexpected project directories after closing Neovim, but the behavior is inconsistent -- sometimes the directory changes, sometimes it does not, and the directory does not always match the most recent Neovim project. This investigation identifies **three interacting mechanisms** that cause directory drift, with the primary culprit being Neovim's OSC 7 emission combined with WezTerm's `current_working_dir` tracking.

## The Observed Behavior

The user's expected workflow:
1. Shell starts at `~/` (home directory)
2. Neovim opens and changes to a project root
3. Neovim closes
4. Shell returns to `~/`

The actual (broken) behavior:
1. Shell starts at `~/`
2. Neovim opens and emits OSC 7 with project directory
3. Neovim closes
4. Shell is "somewhere" -- a project directory, but not necessarily the one from the most recent session

## Root Cause Analysis

### Cause 1: Neovim OSC 7 Emission (PRIMARY CAUSE)

**File**: `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua` (lines 103-144)

Neovim emits OSC 7 escape sequences on three events:
- `VimEnter` -- on startup
- `DirChanged` -- on any `:cd`, `:lcd`, `:tcd`
- `BufEnter` -- on every non-terminal buffer switch

**What OSC 7 does**: It tells WezTerm "the current working directory of this pane is X". WezTerm stores this as `pane.current_working_dir` and uses it for:
- Tab title display (visible in `format-tab-title` handler at line 302 of wezterm.lua)
- New tab/pane spawn directory (via `SpawnTab("CurrentPaneDomain")`)

**Critical insight**: OSC 7 does NOT change the parent shell's actual `$PWD`. It only changes WezTerm's metadata about the pane. The shell's working directory remains wherever it was before Neovim launched.

**However**, this metadata has a side effect: when the user opens a new tab (`Ctrl+Space c`), that new tab spawns in the OSC 7-reported directory, not in the shell's actual `$PWD`. And if WezTerm resolves the pane's CWD from its process tree, the OSC 7 value overrides the actual shell CWD.

### Cause 2: WezTerm Process Tree CWD Resolution

WezTerm can resolve the working directory of a pane in two ways:
1. **OSC 7 reports**: The most recent OSC 7 escape sequence received by the pane
2. **Process tree resolution**: On Linux, WezTerm can read `/proc/PID/cwd` of the foreground process

After Neovim exits, the shell resumes. WezTerm's `pane.current_working_dir` retains the **last OSC 7 value emitted by Neovim**, which was the Neovim project directory. The shell's actual CWD (shown by `pwd`) is still `~/` (or wherever it was), but WezTerm shows the stale OSC 7 directory.

**Why it is inconsistent**: The fish shell also emits OSC 7 via its `__wezterm_osc7` hook on `PWD` variable changes (lines 8-14 of `/home/benjamin/.config/fish/config.fish`). If the user runs any command that changes the fish PWD (including `cd`, which is aliased to zoxide), the fish OSC 7 overwrites the stale Neovim OSC 7. But if the user does not change directories, the stale Neovim directory persists in WezTerm's metadata.

### Cause 3: Zoxide `cd` Aliasing

**File**: `/home/benjamin/.config/fish/config.fish` (line 25)

The command `zoxide init fish --cmd cd | source` replaces the `cd` builtin with zoxide's `__zoxide_z` function. This is relevant because:
- The internal zoxide function calls `__zoxide_cd_internal` which calls `builtin cd`
- This fires fish's `--on-variable PWD` event
- Which fires `__wezterm_osc7` with the new directory
- So using `cd` (zoxide) in the shell DOES update WezTerm's CWD

This means the stale Neovim OSC 7 is only a problem **until the user changes directories in the shell**. If the user types `cd ~/` or uses zoxide, the fish shell's OSC 7 takes over.

### Cause 4: Claude Code Worktree Operations (SECONDARY)

**File**: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/core/worktree.lua`

The Claude Code worktree plugin issues `:cd` and `:tcd` commands when switching between worktrees (lines 311, 383, 505, 877, 930, 1491, 1981). Each of these triggers Neovim's `DirChanged` autocmd, which emits OSC 7. If the user is working in multiple worktrees during a session, the last-emitted OSC 7 might correspond to a worktree directory, not the project the user most recently focused on.

### Cause 5: Claude Code Bash Tool (NOT A CAUSE)

Investigation of Claude Code's source confirms that its Bash tool:
- Spawns child bash processes with `cwd` set to its tracked working directory
- Appends `pwd -P >| /tmp/cwd-file` to capture the shell's final CWD
- Updates internal state via `HO()` -> `da6()` which sets `d1.cwd` (internal state only)
- Does NOT call `process.chdir()` for normal Bash tool operations
- Does NOT emit OSC 7 sequences

The Bash tool uses bash (not fish), so no fish hooks fire, and no OSC 7 is emitted by Claude Code's command execution. Claude Code's `process.chdir()` calls are limited to worktree operations, teleport, and repo resolution -- not normal Bash tool usage.

## The Inconsistency Explained

The directory drift is inconsistent because it depends on timing and user behavior:

| Scenario | Result |
|----------|--------|
| Open Neovim -> work -> close -> immediately open new tab | New tab opens in Neovim's last directory (stale OSC 7) |
| Open Neovim -> work -> close -> type `cd ~/` -> open new tab | New tab opens in `~/` (fish OSC 7 overwrote stale value) |
| Open Neovim -> switch worktrees -> close -> check tab title | Tab title shows last worktree directory, not the main project |
| Open Neovim -> use Claude Code terminal -> close | Tab title might show Claude Code's last working directory (if a `DirChanged` was triggered) |
| Fish shell prompt appears after Neovim closes | `pwd` shows `~/` (correct), but tab title shows Neovim's directory (stale OSC 7) |

The "old behavior" the user remembers (always returning to `~/`) was likely before the OSC 7 integration was added to the Neovim configuration (Task 790).

## Diagnosis Summary

```
Source              | Mechanism           | Changes Shell CWD? | Changes WezTerm Metadata?
--------------------|--------------------|--------------------|-------------------------
Neovim OSC 7        | \027]7;file://...  | No                 | Yes (primary cause)
Fish shell OSC 7    | printf \033]7;...  | No                 | Yes (corrective)
Neovim :cd/:tcd     | DirChanged autocmd | No (Neovim only)   | Yes (triggers OSC 7)
Claude worktree.lua | vim.cmd("cd ...")  | No (Neovim only)   | Yes (triggers OSC 7)
Claude Bash tool    | child_process.spawn| No                 | No
Zoxide cd           | builtin cd         | Yes (fish)         | Yes (triggers fish OSC 7)
```

## Options for Improving UX

### Option A: Disable Neovim OSC 7 on Exit (Recommended)

Add a `VimLeavePre` autocmd that emits OSC 7 with the **original shell directory** (the directory from which Neovim was launched). This restores the "old behavior" where closing Neovim returns the terminal metadata to its pre-Neovim state.

```lua
-- In the existing if vim.env.WEZTERM_PANE block:
local original_cwd = vim.fn.getcwd()  -- Capture at VimEnter

api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    -- Reset WezTerm's CWD metadata to the shell's actual directory
    -- Use the parent shell's CWD, not Neovim's
    local shell_cwd = vim.env.PWD or vim.fn.expand("$HOME")
    local hostname = vim.fn.hostname()
    local osc7 = string.format("\027]7;file://%s%s\007", hostname, shell_cwd)
    io.write(osc7)
    io.flush()
  end,
  desc = "WezTerm: Reset tab directory to shell CWD on exit",
})
```

**Pros**: Simple, fixes the stale metadata problem, restores old behavior
**Cons**: `vim.env.PWD` might not always reflect the parent shell's directory accurately

### Option B: Suppress Neovim OSC 7 Entirely

Remove the OSC 7 autocmds from Neovim (lines 103-144 of autocmds.lua). The fish shell already emits OSC 7 on its own, and Neovim's OSC 7 emission is what causes the WezTerm metadata drift.

**Pros**: Eliminates the root cause entirely
**Cons**: Loses tab title updates while Neovim is running (tab title would show shell directory, not Neovim project)

### Option C: Emit OSC 7 Only on VimEnter (Minimal)

Keep only the `VimEnter` OSC 7 emission and add the `VimLeavePre` reset. Remove the `DirChanged` and `BufEnter` handlers.

```lua
if vim.env.WEZTERM_PANE then
  local function emit_osc7()
    local cwd = vim.fn.getcwd()
    local hostname = vim.fn.hostname()
    local osc7 = string.format("\027]7;file://%s%s\007", hostname, cwd)
    io.write(osc7)
    io.flush()
  end

  -- Remember shell's PWD for cleanup
  local shell_pwd = vim.env.PWD or vim.fn.expand("$HOME")

  -- Set tab title on startup
  api.nvim_create_autocmd("VimEnter", {
    callback = emit_osc7,
    desc = "WezTerm: Set initial tab title",
  })

  -- Reset on exit
  api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local hostname = vim.fn.hostname()
      local osc7 = string.format("\027]7;file://%s%s\007", hostname, shell_pwd)
      io.write(osc7)
      io.flush()
    end,
    desc = "WezTerm: Reset tab title to shell directory on exit",
  })
end
```

**Pros**: Tab title still shows project name during Neovim usage, but resets cleanly on exit
**Cons**: Tab title does not update when changing directories within Neovim (less dynamic)

### Option D: lastdir File + Shell Wrapper (From Research 002)

As documented in research-002, add a `VimLeavePre` autocmd that writes `vim.fn.getcwd()` to `~/.cache/nvim/lastdir`, and add a fish shell wrapper function that reads the file after Neovim exits and runs `cd`.

**Pros**: Actually changes the shell's working directory, most complete solution
**Cons**: Changes shell behavior (some users may not want the shell to `cd` after every Neovim exit)

### Option E: Combine A + D (Most Complete)

Use Option A (reset OSC 7 on exit) to fix the stale metadata problem, AND use Option D (lastdir file) to optionally sync the shell's actual CWD. Make the lastdir behavior opt-in via an environment variable.

## Recommendation

**Option A is the recommended immediate fix**. It directly addresses the root cause (stale OSC 7 metadata) with minimal changes. The user's actual complaint is that the directory is "out of sync" -- Option A ensures that when Neovim exits, WezTerm's metadata returns to the shell's actual directory.

If the user also wants the shell to cd to Neovim's directory after exit (the original task description), Option D can be added on top.

## Files Examined

- `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua` -- OSC 7 integration (lines 103-144)
- `/home/benjamin/.dotfiles/config/wezterm.lua` -- Tab title formatting, OSC 7 consumption (lines 302-371)
- `/home/benjamin/.config/fish/config.fish` -- Fish shell OSC 7 hook, zoxide integration
- `/home/benjamin/.config/nvim/lua/neotex/lib/wezterm.lua` -- WezTerm user variable integration
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/core/worktree.lua` -- Worktree directory changes
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ui/sessions.lua` -- Session manager configuration
- `/home/benjamin/.npm/_npx/97540b0888a2deac/node_modules/@anthropic-ai/claude-code/cli.js` -- Claude Code source
- `/home/benjamin/.claude/settings.json` -- Claude Code settings
- `/home/benjamin/.claude/hooks/statusline-push.sh` -- Claude Code statusline hook

## References

- [Claude Code --cwd Feature Request (GitHub #26287)](https://github.com/anthropics/claude-code/issues/26287)
- [Claude Code Shell CWD Reset Bug (GitHub #5441)](https://github.com/anthropics/claude-code/issues/5441)
- [WezTerm Shell Integration](https://wezterm.org/shell-integration.html)
- [WezTerm default_cwd Config](https://wezterm.org/config/lua/config/default_cwd.html)
- [Claude Code Terminal Config Docs](https://code.claude.com/docs/en/terminal-config)
- [Zoxide Documentation](https://github.com/ajeetdsouza/zoxide)
- Neovim DirChanged autocmd documentation
- Research 001: OSC 7 integration analysis
- Research 002: lastdir file approach analysis

## Next Steps

1. Decide between Option A (reset OSC 7 on exit) and Option C (minimal OSC 7)
2. Optionally combine with Option D (lastdir file) for full CWD sync
3. Update implementation plan to reflect the diagnostic findings
