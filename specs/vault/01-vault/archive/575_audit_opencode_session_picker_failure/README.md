# Task 575: Audit OpenCode Session Picker Failure Modes

- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: neovim
- **Dependencies**: Prior research from #544 (archived)

## Description

Diagnose the actual current failure modes for the OpenCode session picker invoked via `<C-CR>` -> OpenCode. Both the "Restore last session" and "Browse all sessions" options do not work as expected, despite a prior fix attempt (task 544) that replaced `vim.defer_fn(1000)` with Promise-based `Server.get()` chains.

### Context

Task 544 (`fix_opencode_session_picker`) was planned and researched with a specific proposed fix: replace the unreliable `vim.defer_fn(1000)` timing workaround with the opencode.nvim plugin's own `Server.get()` polling. The code at `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua:391-412` now uses this Promise-based approach, but the user reports both options still fail.

This task must determine what the actual root cause is NOW, after the 544 fix was applied. Potential failure modes to investigate:

1. **Cold-start race**: After `toggle()` creates the `snacks.terminal`, does `Server.get()`'s `pgrep`-based process discovery find the new process before the 5-second polling timeout expires?
2. **`Snacks` terminal dedup**: Does `snacks.terminal.toggle()` create a NEW process or reuse an existing one? If it deduplicates, the `pgrep` match may succeed but the TUI may not be in the expected state.
3. **Port mismatch**: Does the `opencode --port` command specify an explicit port, and does `Server.get()`'s discovery match it?
4. **`select_session()` API behavior**: Does `opencode_mod.select_session()` work correctly when called immediately after `toggle()`, or does the TUI UI state prevent proper session browsing?
5. **Error swallowing**: Are Promise rejections or API failures being silently swallowed by the current error-handling code?
6. **`Server:select_session()` TUI endpoint**: Does the POST to `/tui/select-session` actually work, or has the TUI API changed?

### Key Files

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — Current session picker implementation (lines 303-412)
- `lua/neotex/plugins/ai/opencode.lua` — Plugin config with `snacks.terminal` server functions
- `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` — `Server.get()`, `Server:select_session()`, `poll()`, `find()`
- `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/process/unix.lua` — Process discovery via pgrep/lsof
- `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` — Session picker UI that `select_session()` delegates to
- `specs/archive/544_fix_opencode_session_picker/` — Prior task with research, plan, and summary

### Prior Research (Task 544)

The 544 research report identified that `Server.get()` provides robust polling (5 retries at 1-second intervals) and recommended replacing `vim.defer_fn(1000)` with Promise chains. The 544 plan marked both phases as COMPLETED, suggesting the fix was applied. However the user still reports failure, meaning either:
- The fix was applied incorrectly
- The fix works but a different failure mode exists
- The plugin's API behavior has changed since 544 was researched

### Verification

- [ ] Determine whether `Server.get()` succeeds or times out in the cold-start scenario
- [ ] Verify `snacks.terminal` process creation and port assignment
- [ ] Test `opencode_mod.select_session()` in isolation (with a running server)
- [ ] Check for error messages in `:messages` or terminal stderr
- [ ] Validate the `/tui/select-session` TUI endpoint behavior
