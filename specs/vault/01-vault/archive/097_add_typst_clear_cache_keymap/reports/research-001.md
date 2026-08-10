# Research Report: Task #97

**Task**: 97 - add_typst_clear_cache_keymap
**Started**: 2026-02-25T00:00:00Z
**Completed**: 2026-02-25T00:15:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: tinymist source code, local Neovim config, tinymist documentation
**Artifacts**: - specs/097_add_typst_clear_cache_keymap/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- A `tinymist_clear_cache` function and `<leader>lC` keymap already exist in `after/ftplugin/typst.lua` (lines 227-231, 240), but the implementation uses `LspRestart tinymist` (full server restart) instead of the proper LSP command
- Tinymist exposes a server-side `tinymist.doClearCache` workspace/executeCommand that clears the comemo memoization cache and analysis cache without restarting the server
- The task should be reframed: replace the current blunt LspRestart approach with the proper `tinymist.doClearCache` LSP command, and optionally rebind to `<leader>l` (lowercase) if that is the intended key

## Context & Scope

The user reports stale tinymist preview cache causing old compiled output to persist after source file updates. A keymap already exists at `<leader>lC` but it restarts the entire LSP server, which is slow, disruptive, and destroys all LSP state (diagnostics, hover, completions) temporarily. The proper approach is to invoke tinymist's built-in cache-clearing LSP command.

### What was researched
1. Existing typst keymaps in this Neovim configuration
2. Tinymist LSP workspace commands for cache clearing
3. Tinymist source code for the exact command interface
4. Community patterns for tinymist cache management in Neovim

## Findings

### Existing Configuration

The file `after/ftplugin/typst.lua` already contains:

**Current clear-cache function (lines 227-231)**:
```lua
local function tinymist_clear_cache()
  pcall(vim.cmd, "TypstPreviewStop")
  vim.cmd("LspRestart tinymist")
  vim.notify("tinymist cache cleared (run <leader>lp to reopen)", vim.log.levels.INFO)
end
```

**Current keymap (line 240)**:
```lua
{ "<leader>lC", tinymist_clear_cache, desc = "clear cache", icon = "...", buffer = 0 },
```

**Issues with current implementation**:
1. Uses `LspRestart tinymist` -- full server restart, not a targeted cache clear
2. Stops the typst preview (unnecessary if only clearing analysis cache)
3. Loses all LSP state temporarily (diagnostics, etc.)
4. Bound to `<leader>lC` (uppercase) -- task description mentions `<leader>l`

**All existing `<leader>l` keymaps in typst ftplugin**:
| Key | Function | Description |
|-----|----------|-------------|
| `<leader>lC` | tinymist_clear_cache | clear cache (current, uses LspRestart) |
| `<leader>lc` | typst_watch | compile (watch) |
| `<leader>le` | show_diagnostics | errors |
| `<leader>lf` | typst_format | format |
| `<leader>ll` | TypstPreviewToggle | live preview (web) |
| `<leader>lp` | TypstPreview | preview (web) |
| `<leader>lP` | pin_main_file | pin main file |
| `<leader>lr` | typst_compile | run (compile once) |
| `<leader>ls` | TypstPreviewSyncCursor | sync cursor (web) |
| `<leader>lu` | unpin_main_file | unpin main file |
| `<leader>lv` | typst_view_pdf | view pdf (Sioyek) |
| `<leader>lw` | typst_watch_stop | stop watch |
| `<leader>lx` | TypstPreviewStop | stop preview |

### Plugin Documentation (tinymist source code)

**Server-side command**: `tinymist.doClearCache`

Found in `crates/tinymist/src/server.rs`:
```rust
.with_command("tinymist.doClearCache", State::clear_cache)
```

**Implementation** in `crates/tinymist/src/cmd.rs`:
```rust
/// Clear all cached resources.
pub fn clear_cache(&mut self, _arguments: Vec<JsonValue>) -> AnySchedulableResponse {
    comemo::evict(0);
    self.project.analysis.clear_cache();
    just_ok(JsonValue::Null)
}
```

**What it clears**:
1. `comemo::evict(0)` -- Evicts all entries from the comemo memoization system (used by Typst's incremental compilation)
2. `self.project.analysis.clear_cache()` -- Clears the analysis cache (completions, diagnostics, hover info caches)

**Arguments**: The function accepts `_arguments: Vec<JsonValue>` but ignores them. The VSCode extension passes the current file URI as an argument, but the server implementation does not use it. No arguments are required.

**VSCode extension reference** (from `editors/vscode/src/extension.ts`):
```typescript
async function commandClearCache(): Promise<void> {
  const activeEditor = window.activeTextEditor;
  if (!activeEditor) return;
  const uri = activeEditor.document.uri.toString();
  await tinymist.executeCommand("tinymist.doClearCache", [uri]);
}
```

### Community Patterns

- **LazyVim typst extra** does not include a cache-clearing keymap
- **Tinymist Neovim docs** only document `tinymist.pinMain` as a Neovim command example
- The `tinymist.doClearCache` command is undocumented for Neovim -- only the VSCode extension wraps it

### Recommendations

**Implementation approach** -- Replace the current function body with a proper LSP command call:

```lua
local function tinymist_clear_cache()
  local clients = vim.lsp.get_clients({ bufnr = 0, name = "tinymist" })
  if #clients == 0 then
    vim.notify("No tinymist LSP client attached", vim.log.levels.WARN)
    return
  end
  for _, client in ipairs(clients) do
    vim.lsp.buf.execute_command({
      command = "tinymist.doClearCache",
      arguments = { vim.api.nvim_buf_get_name(0) },
    })
  end
  vim.notify("tinymist cache cleared", vim.log.levels.INFO)
end
```

**Key design decisions**:
1. **Keep `<leader>lC`** (uppercase C) as the binding -- `<leader>l` alone is the which-key group prefix and cannot serve as a keymap. The task description likely means `<leader>l` followed by a letter within the group.
2. **Remove `TypstPreviewStop`** -- Clearing the analysis cache does not require stopping the preview. The preview will pick up fresh data on next compilation.
3. **Remove `LspRestart`** -- The `doClearCache` command clears caches without restarting the server, preserving all other LSP state.
4. **Follow existing `vim.lsp.buf.execute_command` pattern** -- Matches the style already used by `pin_main_file` and `unpin_main_file` in the same file.
5. **Pass current buffer URI as argument** -- Matches the VSCode extension pattern, even though the server ignores the argument (future-proofing).

**Alternative approach**: If the user specifically wants the keymap on lowercase `<leader>l` + a different letter (e.g., `<leader>ld` for "discard cache"), the key can be changed. Available lowercase letters: `a`, `b`, `d`, `g`, `h`, `i`, `j`, `k`, `m`, `n`, `o`, `q`, `t`, `y`, `z`.

## Decisions
- Use `tinymist.doClearCache` LSP command instead of `LspRestart tinymist`
- Keep `<leader>lC` binding (already exists and is discoverable via which-key)
- Follow existing `vim.lsp.buf.execute_command` pattern from the same file
- Do not stop typst-preview when clearing cache (orthogonal concerns)

## Risks & Mitigations
- **Risk**: `tinymist.doClearCache` may not exist in older tinymist versions
  - **Mitigation**: The installed version is tinymist v0.14.6-rc2 (Typst 0.14.2), which includes this command. The function already wraps with a client check.
- **Risk**: Cache clearing may not fully resolve stale preview output if the issue is in typst-preview.nvim rather than tinymist
  - **Mitigation**: If the stale output persists after `doClearCache`, a fallback approach of restarting the preview (`TypstPreviewStop` then `TypstPreview`) can be added as a second step. But try the targeted approach first.
- **Risk**: The arguments parameter is currently ignored by the server, but passing the URI follows the VSCode convention
  - **Mitigation**: This is defensive coding; if tinymist adds per-file cache clearing in the future, the argument will already be passed correctly.

## Context Extension Recommendations
- **Topic**: tinymist LSP workspace commands
- **Gap**: The neovim-api.md context file does not document tinymist-specific LSP commands (doClearCache, pinMain, etc.)
- **Recommendation**: Add a section to `.claude/context/project/neovim/domain/neovim-api.md` or create a new file `.claude/context/project/neovim/tools/tinymist-commands.md` documenting available tinymist workspace commands

## Appendix

### Search Queries Used
1. `tinymist LSP clear cache command workspace execute` (web)
2. `tinymist "clearCache" LSP command typst stale preview cache neovim` (web)
3. `tinymist github "clearCache" source code command handler rust` (web)
4. `gh search code "clearCache" --repo Myriad-Dreamin/tinymist` (GitHub API)
5. `gh search code "clear_cache" --repo Myriad-Dreamin/tinymist` (GitHub API)
6. Local grep for `typst|tinymist` and `exec_cmd|execute_command` patterns

### References
- [Tinymist GitHub Repository](https://github.com/Myriad-Dreamin/tinymist)
- [Tinymist Neovim Documentation](https://myriad-dreamin.github.io/tinymist/frontend/neovim.html)
- [Tinymist VSCode package.json (commands)](https://github.com/Myriad-Dreamin/tinymist/blob/main/editors/vscode/package.json)
- [Tinymist server.rs (command registration)](https://github.com/Myriad-Dreamin/tinymist/blob/main/crates/tinymist/src/server.rs)
- [Tinymist cmd.rs (clear_cache implementation)](https://github.com/Myriad-Dreamin/tinymist/blob/main/crates/tinymist/src/cmd.rs)
- [LazyVim Typst Extra](https://www.lazyvim.org/extras/lang/typst)
- [Tinymist Language Server Documentation](https://myriad-dreamin.github.io/tinymist/module/lsp.html)

### Environment
- Neovim: v0.11.6
- Tinymist: v0.14.6-rc2 (Typst 0.14.2)
- Plugin manager: lazy.nvim
- Typst preview: chomosuke/typst-preview.nvim v1.x
