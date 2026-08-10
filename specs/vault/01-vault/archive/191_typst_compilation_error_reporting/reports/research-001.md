# Research Report: Task #191

**Task**: 191 - Fix typst compilation error reporting
**Started**: 2026-03-12T00:00:00Z
**Completed**: 2026-03-12T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, Neovim documentation, Web search
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Current `typst_compile()` function captures exit code but ignores stderr output
- Typst CLI supports `--diagnostic-format short` producing parseable `file:line:col: level: message` format
- Neovim ships a built-in typst compiler plugin that already configures makeprg and errorformat
- The `show_diagnostics()` function shows LSP diagnostics, not compilation errors (they are different systems)
- **Recommended approach**: Capture stderr in `typst_compile()` and populate quickfix list using `vim.fn.setqflist()`

## Context & Scope

### Problem Statement

When running `<leader>lr` (compile once) on a typst file:
1. Compilation fails with exit code 1
2. Only a generic "Compilation failed (exit code: X)" notification appears
3. The actual error details from typst stderr are not captured or displayed

When running `<leader>le` (show errors):
1. Opens LSP diagnostics float, NOT compilation errors
2. If tinymist LSP has no diagnostics, nothing appears
3. Compilation errors and LSP diagnostics are separate systems

### Scope

This research focuses on:
1. Understanding typst CLI error output formats
2. Identifying how to capture stderr from `vim.fn.jobstart`
3. Learning quickfix integration patterns for compilation errors
4. Reviewing existing implementations (VimTeX, neovim compiler plugin)

## Findings

### 1. Typst CLI Error Output

**Version tested**: typst 0.14.2

**Diagnostic format options**:
- `--diagnostic-format human` (default): Rich formatted output with ASCII art boxes
- `--diagnostic-format short`: Single-line format suitable for parsing

**Short format output**:
```
file.typ:5:15: error: unknown variable: badfunction
```

Pattern: `{file}:{line}:{col}: {level}: {message}`

**Important behaviors**:
- Errors go to stderr (confirmed via testing)
- Typst stops at first error (does not accumulate multiple errors)
- Exit code 1 indicates compilation failure

### 2. Current typst.lua Implementation

**Location**: `after/ftplugin/typst.lua`

**Current `typst_compile()` function** (lines 182-206):
```lua
local function typst_compile()
  local main_file = detect_main_file()
  -- ... command setup ...

  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("Compilation successful", vim.log.levels.INFO)
      else
        vim.notify("Compilation failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
end
```

**Problem**: No `on_stderr` callback to capture error output.

**Current `show_diagnostics()` function** (lines 277-279):
```lua
local function show_diagnostics()
  vim.diagnostic.open_float(nil, { focus = false, scope = "line" })
end
```

**Problem**: Shows LSP diagnostics from tinymist, not typst CLI compilation errors.

### 3. Neovim Built-in Typst Compiler

**Location**: `/usr/share/nvim/runtime/compiler/typst.vim` (or via nix store)

```vim
let s:makeprg = [current_compiler, 'compile', '--diagnostic-format', 'short', '%:S']
execute 'CompilerSet makeprg=' . join(s:makeprg, '\ ')
```

**Note**: Uses `--diagnostic-format short` for parseability. The default errorformat in Vim/Neovim can parse this format since it follows the standard `file:line:col: message` pattern.

### 4. Quickfix Integration Pattern

**From async make implementation** (Phelipe Teles blog):

```lua
local function on_event(job_id, data, event)
  if event == "stdout" or event == "stderr" then
    if data then
      vim.list_extend(lines, data)
    end
  end

  if event == "exit" then
    vim.fn.setqflist({}, " ", {
      title = cmd,
      lines = lines,
      efm = vim.api.nvim_buf_get_option(bufnr, "errorformat")
    })
    vim.api.nvim_command("doautocmd QuickFixCmdPost")
  end
end
```

**Key API**: `vim.fn.setqflist({}, "r", { title = ..., lines = ..., efm = ... })`

**Alternative**: Build items directly without efm parsing:
```lua
vim.fn.setqflist({}, "r", {
  title = "Typst Errors",
  items = {
    { filename = "file.typ", lnum = 5, col = 15, text = "unknown variable: badfunction", type = "E" }
  }
})
```

### 5. VimTeX Quickfix Approach

**From**: `lua/neotex/plugins/text/vimtex.lua`

VimTeX uses:
- `vim.g.vimtex_quickfix_mode = 0` - Controls when quickfix opens
- `vim.g.vimtex_quickfix_ignore_filters` - Filters out noise (Underfull, Overfull, etc.)
- Built-in errorformat for LaTeX log parsing

VimTeX handles this internally in its Vimscript/Lua code, parsing LaTeX log files.

### 6. LSP vs Compilation Errors

**tinymist LSP** (from `lspconfig.lua`):
- Provides real-time diagnostics as you type
- Shown via `vim.diagnostic.open_float()`
- Different from CLI compilation errors

**typst CLI**:
- One-shot compilation
- Errors on stderr
- Requires separate error capture mechanism

**Both systems should work together**:
- LSP for real-time feedback during editing
- Quickfix for compilation errors (especially for errors LSP might miss)

## Recommendations

### Primary Solution: Enhanced `typst_compile()` with Quickfix

Modify `typst_compile()` to:
1. Add `--diagnostic-format short` to command
2. Add `on_stderr` callback to capture errors
3. Use `stderr_buffered = true` for complete output
4. Parse stderr and populate quickfix on exit
5. Open quickfix if errors exist

**Proposed implementation sketch**:

```lua
local function typst_compile()
  local main_file = detect_main_file()
  local root = detect_project_root(main_file)
  local stderr_lines = {}

  local cmd = { "typst", "compile", "--diagnostic-format", "short" }
  if root then
    table.insert(cmd, "--root")
    table.insert(cmd, root)
  end
  table.insert(cmd, main_file)

  vim.notify("Compiling " .. vim.fn.fnamemodify(main_file, ":t") .. "...", vim.log.levels.INFO)

  vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_lines, data)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          vim.fn.setqflist({}, "r", { title = "Typst", items = {} })
          vim.notify("Compilation successful", vim.log.levels.INFO)
        else
          -- Parse short format: file:line:col: level: message
          local items = {}
          for _, line in ipairs(stderr_lines) do
            if line and line ~= "" then
              local file, lnum, col, level, msg = line:match("^(.+):(%d+):(%d+): (%w+): (.+)$")
              if file and lnum then
                table.insert(items, {
                  filename = file,
                  lnum = tonumber(lnum),
                  col = tonumber(col),
                  text = msg,
                  type = level == "error" and "E" or "W"
                })
              end
            end
          end

          vim.fn.setqflist({}, "r", { title = "Typst Errors", items = items })

          if #items > 0 then
            vim.cmd("copen")
            vim.notify("Compilation failed: " .. #items .. " error(s)", vim.log.levels.ERROR)
          else
            vim.notify("Compilation failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
          end
        end
      end)
    end,
  })
end
```

### Secondary: Update `show_diagnostics()` Keybinding

Consider either:
1. **Keep as-is**: `<leader>le` shows LSP diagnostics (current behavior)
2. **Add new binding**: `<leader>lq` to open quickfix (`:copen`)
3. **Rename**: Make `<leader>le` open quickfix with compilation errors

**Recommendation**: Keep `<leader>le` for LSP diagnostics (useful during editing), add `<leader>lq` for quickfix (compilation errors).

### Alternative: Use `:make` Integration

Since Neovim ships a typst compiler plugin:
1. Set `compiler typst` in ftplugin
2. User can run `:make` which uses makeprg and errorformat
3. Errors auto-populate quickfix

**Drawback**: Doesn't integrate with the custom `detect_main_file()` and `detect_project_root()` logic already in typst.lua.

## Decisions

1. **Use direct quickfix population** over errorformat parsing - More explicit, handles edge cases better
2. **Parse in Lua** rather than relying on efm - More control over error handling
3. **Use `stderr_buffered = true`** - Ensures complete output before processing
4. **Use `vim.schedule()`** in callbacks - Required for safe Neovim API calls from job callbacks
5. **Open quickfix automatically on errors** - Immediate feedback to user

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Typst changes output format | Low | Medium | Pin to `--diagnostic-format short` which is stable |
| Relative paths in error output | Medium | Low | Typst outputs paths relative to cwd; may need normalization |
| Multiple errors not captured | Medium | Low | Document that typst stops at first error |
| Quickfix conflicts with other tools | Low | Low | Use unique title "Typst Errors" |

## Appendix

### Search Queries Used
- "neovim typst quickfix error parsing compilation errors vim plugin"
- "typst compile diagnostic-format json stderr error output format"
- "neovim vim.fn.jobstart on_stderr callback capture stderr lua"
- "neovim lua vim.fn.setqflist quickfix list example parse compiler errors"

### References
- [Neovim Quickfix Documentation](http://neovim.io/doc/user/quickfix/)
- [Async :make in Neovim with Lua](https://phelipetls.github.io/posts/async-make-in-nvim-with-lua/)
- [Typst CLI Manual - typst-compile(1)](https://man.archlinux.org/man/extra/typst/typst-compile.1.en)
- [GitHub Issue: Add JSON format for CLI diagnostics](https://github.com/typst/typst/issues/6059)
- [Neovim Job Control Documentation](https://neovim.io/doc/user/job_control.html)

### Files Examined
- `/home/benjamin/.config/nvim/after/ftplugin/typst.lua` - Current implementation
- `/home/benjamin/.config/nvim/lua/neotex/plugins/text/vimtex.lua` - VimTeX quickfix config
- `/home/benjamin/.config/nvim/lua/neotex/plugins/lsp/lspconfig.lua` - tinymist LSP setup
- `/home/benjamin/.config/nvim/lua/neotex/plugins/text/typst-preview.lua` - typst-preview setup
- `/nix/store/.../compiler/typst.vim` - Neovim built-in typst compiler
