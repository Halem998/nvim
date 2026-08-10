# Implementation Summary: Task #550

**Completed**: 2026-05-08
**Plan**: specs/550_unify_ctrl_cr_toggle_and_agent_picker/plans/01_ctrl-cr-agent-picker.md

## Changes Made

Replaced heuristic buffer-name detection with a three-tier detection strategy in `smart_toggle()` to fix the `<C-CR>` toggle failing for ClaudeCode. Added centralized `_active_tool` state tracking with lifecycle-aware cleanup via `TermClose`/`BufWipeout` autocmds. Added `<leader>ac` keymap to invoke the agent picker directly.

### Detection Rewrite

- `detect_active_claude()` now queries `claude-code.nvim`'s internal `instances` registry via `require("claude-code").claude_code.instances` with pcall guard, using `_is_live_terminal()` for parity with upstream's `is_valid_terminal_buffer()` check (buffer valid + terminal buftype + jobwait liveness)
- Falls back to heuristic buffer-name scanning via `session-manager.detect_claude_buffers()` if the plugin registry is inaccessible
- `_is_live_terminal()` shared helper ensures detection and toggle use identical liveness criteria

### State Tracking

- `M._active_tool` (nil | "claude" | "opencode") tracks which tool was last launched via the picker
- `M._active_tool_bufnr` tracks the buffer number for defensive validity checks
- `_register_tool_cleanup()` creates a `NixAIToolCleanup` augroup with `TermClose` + `BufWipeout` autocmds on the specific buffer to auto-clear state when the terminal is destroyed
- State is set after picker selection (deferred 500ms to allow terminal creation) and re-registered during Tier 2 detection fallback

### Smart Toggle Three-Tier Strategy

1. **Fast path**: Check `M._active_tool` + verify buffer still alive via `_is_live_terminal()`
2. **Detection fallback**: Query plugin registries (`claude-code.nvim` instances, `snacks.terminal.list()`)
3. **Picker fallback**: Show Stage 1 tool picker when both or neither tool is active

### New Keymap

- `<leader>ac` in which-key.lua invokes `show_tool_picker()` directly with pcall guard and initialization check

## Files Modified

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` -- rewrote detection, added state tracking, updated smart_toggle
- `lua/neotex/plugins/editor/which-key.lua` -- added `<leader>ac` entry in the `<leader>a` group

## Verification

- Neovim startup: Success (no errors)
- Module loading: Success (`require('neotex.plugins.ai.shared.picker.ai-tool-picker')` loads cleanly)
- `_active_tool` nil on fresh load: Verified
- `_initialized` true after setup: Verified
- All public API functions present: Verified
- which-key module loads: Success

## Notes

- The `_register_tool_cleanup` augroup uses `clear = true`, so registering a new tool automatically deregisters the previous one's cleanup autocmd, which is correct since only one tool should be active at a time
- The 500ms defer in session pickers is a pragmatic delay to allow the terminal buffer to be created by the upstream plugin before detecting it; the defensive nil-check in `smart_toggle` handles the case where this timing is insufficient
- Phase 3 testing scenarios (1-8) require interactive Neovim with terminal access and cannot be fully automated in headless mode; the user should verify toggle behavior manually
