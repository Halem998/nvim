# Research Report: Task #92 (Supplement)

**Task**: 92 - Sync Wezterm terminal directory with Neovim session root
**Date**: 2026-02-24
**Focus**: Persisting directory change in parent shell after Neovim exits

## Summary

The prior research (research-001) correctly identified that OSC 7 cannot change the parent shell's working directory -- it only informs WezTerm of the current directory for display and spawn purposes. This supplemental research focuses on the user's actual requirement: when Neovim exits, the parent shell should be left in Neovim's working directory, not the directory the shell was in before Neovim launched. Three viable approaches were identified, with the "shell wrapper + lastdir file" pattern being the recommended solution due to its proven reliability across the file manager ecosystem.

## The Core Problem

When a user runs `nvim` from a shell in WezTerm:

1. The shell is in directory `/home/user/some/old/path`
2. Neovim opens with session root at `/home/user/projects/myproject`
3. OSC 7 correctly tells WezTerm about `/home/user/projects/myproject` (tab title updates)
4. User closes Neovim
5. The shell returns to `/home/user/some/old/path` -- this is the problem
6. User wants the shell to be at `/home/user/projects/myproject` instead

This is a fundamental Unix process model constraint: child processes (Neovim) cannot change the working directory of parent processes (the shell). OSC 7 only updates WezTerm's metadata about the pane; it does not affect the shell process.

## Findings

### 1. The "lastdir file" Pattern (File Manager Ecosystem)

This is a well-established pattern used by terminal file managers (vifm, yazi, nnn, ranger) to persist directory changes after exit. The mechanism works as follows:

**Step 1 - Child process writes directory to a known file on exit:**
```lua
-- Neovim VimLeavePre autocmd
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local cwd = vim.fn.getcwd()
    local file = io.open(vim.fn.expand("~/.cache/nvim/lastdir"), "w")
    if file then
      file:write(cwd)
      file:close()
    end
  end,
  desc = "Write current directory to lastdir file for shell wrapper",
})
```

**Step 2 - Shell wrapper function reads the file after the child exits and performs cd:**

Fish shell wrapper (modeled after yazi's pattern):
```fish
function nvim
  command nvim $argv
  if test -f ~/.cache/nvim/lastdir
    set -l lastdir (cat ~/.cache/nvim/lastdir)
    if test -d "$lastdir"; and test "$lastdir" != "$PWD"
      builtin cd -- "$lastdir"
    end
    rm -f ~/.cache/nvim/lastdir
  end
end
```

**Why this works:** The wrapper function runs *in the parent shell process*. After Neovim exits, the wrapper reads the file and executes `cd` within the shell itself, changing the shell's actual working directory.

**Reference implementations:**
- Vifm: uses `--choose-dir` flag to write exit directory to a temporary file
- Yazi: uses `--cwd-file` flag with a `mktemp` temporary file
- nnn: writes to `~/.config/nnn/.lastd`

### 2. WezTerm User Variable + send_text Approach

WezTerm provides a `user-var-changed` event and `pane:send_text()` API that could theoretically inject a `cd` command into the shell after Neovim exits:

**Step 1 - Neovim sets a user variable on exit:**
```lua
-- VimLeavePre: set user var with target directory
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local cwd = vim.fn.getcwd()
    -- OSC 1337 SetUserVar
    io.write(string.format("\027]1337;SetUserVar=%s=%s\007",
      "NVIM_EXIT_DIR",
      vim.fn.system("echo -n " .. vim.fn.shellescape(cwd) .. " | base64"):gsub("\n", "")))
    io.flush()
  end,
})
```

**Step 2 - WezTerm event handler sends cd command to the pane:**
```lua
-- In wezterm.lua
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "NVIM_EXIT_DIR" and value ~= "" then
    -- Wait briefly for shell prompt to be ready after nvim exits
    wezterm.sleep_ms(100)
    pane:send_text("cd " .. value .. "\n")
  end
end)
```

**Advantages:**
- No file I/O needed
- Uses WezTerm's native event system
- Works without modifying shell configuration

**Disadvantages:**
- Timing is fragile: the shell must be ready to accept input when send_text fires
- The `cd` command appears in the terminal output (visible to user)
- The `user-var-changed` event fires while Neovim is still running (during VimLeavePre), so the shell may not yet be in the foreground
- Requires base64 encoding of the directory path
- `pane:send_text()` injects raw text into the terminal input stream, which could interfere with whatever the shell is doing at that moment
- The command appears in shell history

**Assessment:** This approach has significant timing and reliability issues. The event fires *before* Neovim fully exits, so the shell prompt is not yet available to receive the `cd` command. This makes it fragile.

### 3. Fish Shell `--on-process-exit` Event Handler

Fish shell supports event handlers that trigger when a process exits:

```fish
function __nvim_cd_on_exit --on-process-exit %self
  # This fires for every child process exit, so we need to filter
  # Unfortunately, fish's --on-process-exit fires for ALL child processes
  # There is no way to target only nvim exits specifically
end
```

**Assessment:** Not viable. Fish's `--on-process-exit` fires for every child process and does not provide enough context to distinguish Neovim exits from other commands. The wrapper function approach is simpler and more targeted.

### 4. Named Pipe / FIFO Approach

A FIFO could be created that the shell monitors in the background:

```fish
# Shell creates FIFO and monitors it
set -l fifo /tmp/nvim-cd-$fish_pid
mkfifo $fifo
# Background job reads from FIFO
while read -l dir < $fifo
  cd $dir
end &
```

**Assessment:** Overly complex, fragile, and adds a background process. The lastdir file approach is superior in every way.

## Comparison Matrix

| Approach | Reliability | Complexity | Shell Modification | WezTerm Modification | Visible Side Effects |
|----------|-------------|------------|-------------------|---------------------|---------------------|
| lastdir file + wrapper | High | Low | Fish config.fish | None | None |
| WezTerm user-var + send_text | Low | Medium | None | wezterm.lua | cd appears in terminal |
| Fish process-exit event | Low | Medium | Fish config.fish | None | None |
| Named pipe / FIFO | Medium | High | Fish config.fish | None | Background process |

## Recommendation: Shell Wrapper + lastdir File

The recommended approach is the "lastdir file" pattern for these reasons:

1. **Proven pattern**: Used by vifm, yazi, nnn, ranger, and other terminal file managers for years
2. **High reliability**: No timing issues -- the file is written before Neovim exits, and the wrapper reads it after Neovim fully exits
3. **No visible side effects**: No `cd` command appears in the terminal
4. **Minimal complexity**: Two small pieces of code (Neovim autocmd + fish wrapper)
5. **No WezTerm changes required**: Works with any terminal emulator
6. **Directory persists correctly**: After Neovim exits, the shell is in the new directory; all subsequent commands, new tabs (via OSC 7 from fish), and shell operations use the new directory

### Implementation Details

**File location**: `~/.cache/nvim/lastdir`
- Uses XDG cache directory convention
- Single file, overwritten each time (no accumulation)
- Cleaned up by the wrapper after reading

**Neovim side** (in `lua/neotex/config/autocmds.lua`):
- Add a `VimLeavePre` autocmd inside the existing `if vim.env.WEZTERM_PANE` block (or unconditionally, since it is useful in any terminal)
- Write `vim.fn.getcwd()` to `~/.cache/nvim/lastdir`
- Ensure the cache directory exists with `vim.fn.mkdir()`

**Fish shell side** (in `~/.config/fish/config.fish`):
- Define a wrapper function named `nvim` that shadows the nvim binary
- Use `command nvim $argv` to call the real nvim
- After exit, read `~/.cache/nvim/lastdir`, validate, and `cd`
- Clean up the file

**Edge cases to handle:**
- Neovim started without changing directory (lastdir same as current) -- no-op `cd`
- lastdir file does not exist (Neovim crashed) -- no-op
- lastdir path no longer exists (deleted during session) -- no-op, validate with `test -d`
- Multiple Neovim instances -- last one to exit wins (acceptable trade-off; could use PID-specific files if needed)
- The wrapper should use `builtin cd` to avoid infinite recursion if the user has also aliased `cd`

### Integration with Existing OSC 7

The lastdir file approach complements the existing OSC 7 integration:
- **OSC 7** (already working): Keeps WezTerm tab titles and new-tab spawning correct while Neovim is running
- **lastdir file** (new): Keeps the shell in the correct directory after Neovim exits
- **Fish shell OSC 7 hook** (already working): Will automatically emit OSC 7 when the fish wrapper performs `cd`, keeping WezTerm's metadata current after the directory change

Together, these three components create a seamless experience:
1. Open Neovim -> OSC 7 updates tab title to Neovim's root
2. Work in Neovim -> OSC 7 tracks directory changes
3. Exit Neovim -> lastdir file tells fish to cd -> fish's OSC 7 hook updates WezTerm

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Wrapper shadows nvim binary | Low | Use `command nvim` to call the real binary |
| Multiple nvim instances write same file | Low | Last-writer-wins is acceptable; PID-specific files if needed |
| Cache directory does not exist | Low | Create with `mkdir -p` in autocmd |
| File left behind after crash | Low | Stale file is harmless; wrapper validates directory exists |
| User does not want cd on every exit | Medium | Could add opt-out (e.g., `:cq` exit code check, or environment variable) |

## Appendix

### Search Queries Used
- "WezTerm OSC 7 shell integration change parent shell working directory persist after child process exits"
- "neovim VimLeave write file parent shell cd directory change persist after exit trap"
- "fish shell wrapper function nvim cd after exit lastdir file"
- "nnn ranger vifm file manager shell cd after exit directory change persist mechanism"
- "yazi fish shell wrapper function cwd-file temporary file cd after exit implementation"
- "WezTerm user-var-changed event trigger shell command cd directory change from pane"
- "WezTerm SendString inject_output cd command into pane shell from lua event handler"
- "WezTerm pane send_text send_paste method documentation lua API"

### Files Examined
- `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua` (existing OSC 7 integration, lines 103-144)
- `/home/benjamin/.dotfiles/config/wezterm.lua` (WezTerm configuration)
- `/home/benjamin/.config/fish/config.fish` (fish shell configuration with existing OSC 7 hook)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ui/sessions.lua` (session manager plugin)
- `/home/benjamin/.config/nvim/specs/092_sync_wezterm_directory_with_neovim_session/reports/research-001.md` (prior research)
- `/home/benjamin/.config/nvim/specs/092_sync_wezterm_directory_with_neovim_session/plans/implementation-001.md` (prior plan)

### References
- [Vifm Wiki: How to set shell working directory after leaving Vifm](https://wiki.vifm.info/index.php/How_to_set_shell_working_directory_after_leaving_Vifm)
- [Yazi Quick Start: Shell wrapper for directory persistence](https://yazi-rs.github.io/docs/quick-start/)
- [WezTerm Shell Integration](https://wezterm.org/shell-integration.html)
- [WezTerm user-var-changed event](https://wezterm.org/config/lua/window-events/user-var-changed.html)
- [WezTerm pane:send_text()](https://wezterm.org/config/lua/pane/send_text.html)
- [WezTerm pane:send_paste()](https://wezterm.org/config/lua/pane/send_paste.html)
- [WezTerm SendString action](https://wezterm.org/config/lua/keyassignment/SendString.html)
- [WezTerm Passing Data from a pane to Lua](https://wezterm.org/recipes/passing-data.html)
- [Fish shell function documentation](https://fishshell.com/docs/current/cmds/function.html)
- [Neovim autocmd documentation](https://neovim.io/doc/user/autocmd.html)

## Next Steps

1. Revise the implementation plan (implementation-002.md) to use the lastdir file approach
2. Implementation consists of two changes:
   - Add `VimLeavePre` autocmd to `lua/neotex/config/autocmds.lua`
   - Add `nvim` wrapper function to `~/.config/fish/config.fish`
3. Test the full flow: open nvim, verify directory written, exit, verify shell cd
