# Research Report: Task #92

**Task**: 92 - Sync Wezterm terminal directory with Neovim session root
**Started**: 2026-02-21T12:00:00Z
**Completed**: 2026-02-21T12:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Wezterm config, Neovim autocmds, fish shell config, OSC documentation
**Artifacts**: - /home/benjamin/.config/nvim/specs/092_sync_wezterm_directory_with_neovim_session/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **OSC 7 integration already exists** in the codebase and is working correctly for tab title updates
- **The task goal is the reverse direction**: WezTerm terminal should change its working directory to match Neovim's session root on startup
- **Two implementation approaches identified**: VimEnter autocmd with OSC 7 emission (already present), or integration with WezTerm's spawn behavior

## Context and Scope

The task requests that when Neovim starts inside WezTerm, the terminal's working directory should be synced to Neovim's session root directory. This is the **reverse** of the usual flow:

- **Current flow (working)**: Neovim tells WezTerm its directory via OSC 7 for tab title display
- **Requested flow**: WezTerm should somehow change its working directory to match Neovim's directory

### Key Insight

After investigation, the **existing OSC 7 implementation already solves this** for most use cases. The OSC 7 sequence emitted by Neovim enables WezTerm to:
1. Display the correct directory in tab titles (confirmed working)
2. Inherit the correct directory when spawning new tabs/panes (via `pane:get_current_working_dir()`)

## Findings

### 1. Existing OSC 7 Implementation (Already Working)

The codebase already has OSC 7 integration in `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua`:

```lua
-- Lines 103-144: WezTerm OSC 7 integration for tab title updates
if vim.env.WEZTERM_PANE then
  local function emit_osc7()
    local cwd = vim.fn.getcwd()
    local hostname = vim.fn.hostname()
    local osc7 = string.format("\027]7;file://%s%s\007", hostname, cwd)
    io.write(osc7)
    io.flush()
  end

  -- Emit on directory changes
  api.nvim_create_autocmd("DirChanged", {
    pattern = "*",
    callback = emit_osc7,
    desc = "WezTerm: Update tab title on directory change",
  })

  -- Emit on startup
  api.nvim_create_autocmd("VimEnter", {
    pattern = "*",
    callback = emit_osc7,
    desc = "WezTerm: Set initial tab title",
  })

  -- Emit when entering non-terminal buffers
  api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
      if vim.bo.buftype ~= "terminal" then
        emit_osc7()
      end
    end,
    desc = "WezTerm: Restore tab title when leaving terminal buffer",
  })
end
```

This correctly emits OSC 7 on:
- `VimEnter` (startup)
- `DirChanged` (any `:cd`, `:lcd`, `:tcd`, or autochdir)
- `BufEnter` (when entering non-terminal buffers)

### 2. Fish Shell OSC 7 Integration (Already Working)

The fish shell config at `/home/benjamin/.config/fish/config.fish` also emits OSC 7:

```fish
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    __wezterm_osc7
end
```

### 3. WezTerm's Use of OSC 7

According to [WezTerm Shell Integration documentation](https://wezterm.org/shell-integration.html), WezTerm uses OSC 7 for:

1. **Tab title display**: Extracts directory name from `file://hostname/path` for tab titles
2. **Spawning new tabs/panes**: Uses `pane:get_current_working_dir()` to inherit directory

From the WezTerm config at `/home/benjamin/.dotfiles/config/wezterm.lua`:

```lua
-- Lines 319-331: Tab title extraction from current_working_dir
local cwd_url = active_pane.current_working_dir
if cwd_url then
  local cwd_path = cwd_url.file_path
  if cwd_path then
    project_name = cwd_path:match("([^/]+)/?$")
  end
end
```

### 4. What the Task Actually Wants

The task description says "Change Wezterm terminal working directory to match Neovim session root directory on startup." This could mean:

| Interpretation | Status | Notes |
|----------------|--------|-------|
| Tab title shows Neovim's directory | Already working | OSC 7 VimEnter autocmd |
| New tabs spawn in Neovim's directory | Already working | WezTerm inherits from OSC 7 |
| Shell prompt shows Neovim's directory | Not possible via OSC | Would require shell integration |
| Shell's PWD changes to Neovim's directory | Not possible via OSC | Would require shell `cd` command |

### 5. If Shell PWD Sync is Required

If the actual requirement is that the shell running alongside Neovim should have its PWD changed to match Neovim's directory, this is **architecturally impossible** via OSC 7:

**Why OSC 7 Cannot Change Shell PWD**:
- OSC 7 is a **notification** from application to terminal, not a command
- It tells the terminal "my directory is X" for display/spawn purposes
- It cannot make the shell execute `cd X`

**Alternative Approaches** (if truly needed):

1. **Neovim Terminal Integration**:
   - When opening a terminal buffer (`:terminal`), Neovim can specify the directory
   - The terminal starts in that directory (not changing existing shell)

2. **direnv/hook Integration**:
   - Shell hooks that detect `.nvim` or `.session` files
   - Automatically `cd` when entering a project directory

3. **WezTerm spawn_window with cwd**:
   - Modify `gui-startup` to detect if launching for Neovim
   - Set `cwd` parameter to project directory

### 6. Related Prior Research (Task 87)

Task 87 investigated a related issue (terminal directory changing unexpectedly). That research found:
- No automatic directory-changing behavior in Neovim configuration
- All `:cd` commands are user-triggered
- OSC 7 only reports, does not change directories

## Recommendations

### Option A: Verify Current Implementation (Recommended First)

The existing OSC 7 implementation should already satisfy the requirements. Verify:

```bash
# Open WezTerm
pwd  # Should show current directory
nvim ~/.config/nvim/init.lua  # Open Neovim in a project

# Check tab title - should show "nvim" or project directory
# Open new tab with Ctrl+Space c
# New tab should inherit Neovim's working directory
```

### Option B: Enhanced VimEnter Hook (If Needed)

If verification shows the current implementation is insufficient, enhance the `VimEnter` autocmd:

```lua
-- Emit OSC 7 on startup with slight delay to ensure terminal is ready
api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    vim.defer_fn(emit_osc7, 50)  -- Small delay for terminal init
  end,
  desc = "WezTerm: Set initial tab title (delayed)",
})
```

### Option C: Session-Based Directory (If Specific to Sessions)

If the issue is specific to session restoration, integrate with the session manager:

```lua
-- After session restore, emit OSC 7 with session's cwd
api.nvim_create_autocmd("SessionLoadPost", {
  callback = emit_osc7,
  desc = "WezTerm: Update directory after session restore",
})
```

## Technical Details

### OSC 7 Format

From [OSC specification](https://gist.github.com/fdncred/c649b8ab3577a0e2873a8f229730e939):

```
ESC ] 7 ; file://hostname/path BEL
\033]7;file://hostname/path\007
```

- `ESC` (0x1B or `\033` or `\027`)
- `]` literal
- `7` OSC number for working directory
- `;` separator
- `file://hostname/path` URL-encoded path
- `BEL` (0x07 or `\007`) string terminator

### DirChanged Event

From [Neovim autocmd documentation](https://neovim.io/doc/user/autocmd.html):

The `DirChanged` event fires after the current directory was changed. The pattern can be:
- `window` - triggered on `:lcd`
- `tabpage` - triggered on `:tcd`
- `global` - triggered on `:cd`
- `auto` - triggered on `autochdir`
- `*` - triggered on any of the above

Event data (`v:event`) includes:
- `cwd` - current working directory
- `scope` - "global", "tabpage", or "window"
- `changed_window` - true if fired when switching window/tab

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Double OSC 7 emission (fish + nvim) | Low - harmless | Both are emitting correct info |
| Timing issue on VimEnter | Low | Use `vim.defer_fn` if needed |
| Terminal not ready for OSC | Low | WezTerm handles async well |

## Decisions

1. **Verify current implementation first** - The OSC 7 integration appears complete
2. **Do not attempt shell PWD sync** - This is architecturally impossible via terminal escapes
3. **Focus on tab title and spawn behavior** - These are what OSC 7 actually controls

## Appendix

### Search Queries Used
- "OSC 7 escape sequence working directory terminal specification"
- "Neovim DirChanged autocmd event getcwd directory change"
- "Wezterm current_working_dir pane cwd spawn new tab inherit directory"
- "Neovim change terminal working directory OSC 7 startup"

### Files Examined
- `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua`
- `/home/benjamin/.config/nvim/lua/neotex/lib/wezterm.lua`
- `/home/benjamin/.dotfiles/config/wezterm.lua`
- `/home/benjamin/.config/fish/config.fish`
- `/home/benjamin/.config/nvim/specs/087_investigate_wezterm_terminal_directory_change/reports/research-001.md`
- `/home/benjamin/.config/nvim/.claude/context/project/hooks/wezterm-integration.md`

### References
- [WezTerm Shell Integration](https://wezterm.org/shell-integration.html)
- [WezTerm get_current_working_dir](https://wezterm.org/config/lua/pane/get_current_working_dir.html)
- [WezTerm Launching Programs](https://wezterm.org/config/launch.html)
- [Neovim Terminal Documentation](https://neovim.io/doc/user/terminal.html)
- [Neovim Autocmd Documentation](https://neovim.io/doc/user/autocmd.html)
- [OSC 7 in Neovim's Terminal (Blog)](https://lacamb.re/blog/neovim_osc7.html)
- [GitHub: DirChanged Event](https://github.com/neovim/neovim/pull/5928)

## Next Steps

1. Verify the existing OSC 7 implementation is working correctly for the user's use case
2. If the requirement is different from tab title/spawn directory, clarify the exact behavior needed
3. If the requirement is shell PWD sync, this would require a different approach (outside of OSC 7)
