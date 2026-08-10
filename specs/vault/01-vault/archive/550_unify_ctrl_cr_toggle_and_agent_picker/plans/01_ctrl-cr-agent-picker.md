# Implementation Plan: Unify Ctrl-CR Toggle and Agent Picker

- **Task**: 550 - unify_ctrl_cr_toggle_and_agent_picker
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/550_unify_ctrl_cr_toggle_and_agent_picker/reports/01_ctrl-cr-agent-picker.md
- **Artifacts**: plans/01_ctrl-cr-agent-picker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `<C-CR>` toggle works for OpenCode but fails for ClaudeCode because `detect_active_claude()` uses heuristic buffer-name scanning while `claude-code.nvim`'s `toggle()` uses its internal `instances[instance_id]` registry. These two identity systems can disagree, causing the toggle to silently no-op or create a duplicate instance. The fix replaces heuristic detection with a centralized `_active_tool` state variable that is set on tool launch and cleared via `TermClose`/`BufWipeout` autocmds. Additionally, a `<leader>ac` keymap will be added to invoke the agent picker directly.

### Research Integration

The research report (01_ctrl-cr-agent-picker.md) identified five recommendations. This plan implements R1 (fix detection to use plugin registry), R2 (align liveness checks), R3 (add `<leader>ac` keymap), and R4 (centralized `_active_tool` state). R5 (terminal-mode key capture) is addressed as a verification step rather than a code change, since the existing `vim.keymap.set` with `noremap=true` should fire correctly.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_flag set).

## Goals & Non-Goals

**Goals**:
- Make `<C-CR>` toggle ClaudeCode consistently (show/hide) after launching via the picker
- Make `<C-CR>` continue to toggle OpenCode correctly (no regression)
- Add `<leader>ac` keymap to launch the Stage 1 agent picker directly
- Introduce centralized `_active_tool` state tracking with lifecycle-aware cleanup

**Non-Goals**:
- Modifying upstream `claude-code.nvim` plugin code
- Supporting multi-instance Claude Code (only single-instance/"global" mode)
- Adding session switching from within a running tool (existing session pickers handle this)
- Simultaneous toggling of both tools at once

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `claude-code.nvim` API change (instances table location) | H | L | Guard with `pcall`; fall back to buffer-name heuristic if registry inaccessible |
| `_active_tool` state becomes stale if terminal closed by external means | M | M | Use both `TermClose` and `BufWipeout` autocmds to clear; add defensive nil-check in `smart_toggle` |
| `<leader>ac` conflicts with a future keymap | L | L | The `<leader>a` group has few active mappings; `ac` is memorable and semantically clear |
| Regression in OpenCode toggle path | H | L | OpenCode path unchanged; verify in Phase 3 testing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Detection and Add Centralized State Tracking [COMPLETED]

**Goal**: Replace heuristic `detect_active_claude()` with registry-based detection, add `M._active_tool` state variable with autocmd cleanup, and update `smart_toggle()` to use the new state.

**Tasks**:
- [ ] Add `M._active_tool` module variable (nil | "claude" | "opencode") to `ai-tool-picker.lua`
- [ ] Add `M._active_tool_bufnr` to track the buffer number of the active tool terminal
- [ ] Rewrite `detect_active_claude()` to query `claude-code.nvim`'s `instances` registry via `require("claude-code").claude_code.instances` with `pcall` guard, checking `is_valid_terminal_buffer` parity (buffer valid + terminal buftype + jobwait liveness)
- [ ] Update `detect_active_opencode()` -- no functional change needed, but add a comment noting it already uses the authoritative snacks identity
- [ ] Update `show_claude_session_picker()` to set `M._active_tool = "claude"` after successful picker action, and register a `TermClose` autocmd on the resulting buffer to clear it
- [ ] Update `show_opencode_session_picker()` to set `M._active_tool = "opencode"` after successful picker action, and register a `TermClose` autocmd on the resulting buffer to clear it
- [ ] Create a private `_register_tool_cleanup(tool_name, bufnr)` function that sets up the autocmd group `NixAIToolCleanup` with `TermClose` and `BufWipeout` events on the specific buffer, clearing `M._active_tool` and `M._active_tool_bufnr` when fired
- [ ] Update `smart_toggle()` to use a three-tier detection strategy: (1) check `M._active_tool` first (fast path), (2) if nil, fall back to `detect_active_claude()` / `detect_active_opencode()` (backward compat), (3) if both/neither, show picker
- [ ] In `smart_toggle()`, when the fast-path `_active_tool` is set but the underlying buffer is no longer valid (defensive check), clear the state and fall through to detection

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` -- rewrite detection functions, add state tracking, update smart_toggle

**Verification**:
- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.shared.picker.ai-tool-picker')" -c "q"`
- `_active_tool` is nil on fresh load
- After launching ClaudeCode via picker, `_active_tool` is "claude"
- After closing Claude terminal, `_active_tool` resets to nil
- `<C-CR>` toggles Claude visibility (show/hide) without creating duplicate instances

---

### Phase 2: Add leader-ac Keymap [COMPLETED]

**Goal**: Register `<leader>ac` in which-key to invoke the Stage 1 agent picker (`show_tool_picker()`), giving users a direct way to switch agents.

**Tasks**:
- [ ] Add `<leader>ac` entry to the `<leader>a` group in `lua/neotex/plugins/editor/which-key.lua`, using the same `pcall` + `_initialized` guard pattern as `<leader>al`
- [ ] Set description to "ai agent picker" and icon to "󰚩"
- [ ] Verify the keymap does not conflict with any existing mapping in the `<leader>a` group

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` -- add `<leader>ac` entry in the `<leader>a` group

**Verification**:
- `:map <leader>ac` shows the new mapping
- Pressing `<leader>ac` opens the Stage 1 tool picker (ClaudeCode / OpenCode selection)
- The keymap appears in the which-key popup under the "ai" group

---

### Phase 3: Testing and Verification [COMPLETED]

**Goal**: End-to-end verification of all toggle and picker scenarios, including terminal-mode `<C-CR>` capture (R5).

**Tasks**:
- [ ] Test scenario 1: Fresh start, press `<C-CR>` -- should show Stage 1 picker
- [ ] Test scenario 2: Select ClaudeCode from picker, press `<C-CR>` -- should hide Claude window
- [ ] Test scenario 3: Press `<C-CR>` again -- should show Claude window (not create new instance)
- [ ] Test scenario 4: Close Claude terminal (`:bd!`), press `<C-CR>` -- should show Stage 1 picker (state cleared)
- [ ] Test scenario 5: Select OpenCode from picker, press `<C-CR>` -- should hide OpenCode, press again to show
- [ ] Test scenario 6: While inside Claude terminal (terminal mode), press `<C-CR>` -- should toggle (verify R5)
- [ ] Test scenario 7: Press `<leader>ac` with Claude running -- should show Stage 1 picker (allows switching)
- [ ] Test scenario 8: Press `<leader>ac` with nothing running -- should show Stage 1 picker
- [ ] Verify no Lua errors in `:messages` after all scenarios
- [ ] Run module load test: `nvim --headless -c "lua require('neotex.plugins.ai.shared.picker.ai-tool-picker').setup()" -c "q"`

**Timing**: 45 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (manual testing only)

**Verification**:
- All 8 test scenarios pass without error
- No duplicate Claude instances created
- `_active_tool` state transitions correctly across all scenarios

## Testing & Validation

- [ ] Module loads without error in headless mode
- [ ] `<C-CR>` toggles Claude after picker launch (the primary bug fix)
- [ ] `<C-CR>` continues to toggle OpenCode correctly (no regression)
- [ ] `<leader>ac` opens Stage 1 picker in all situations
- [ ] State cleanup fires on terminal close (no stale `_active_tool`)
- [ ] Terminal-mode `<C-CR>` works from inside both Claude and OpenCode terminals
- [ ] No duplicate Claude instances created on repeated toggle

## Artifacts & Outputs

- `specs/550_unify_ctrl_cr_toggle_and_agent_picker/plans/01_ctrl-cr-agent-picker.md` (this plan)
- Modified: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`
- Modified: `lua/neotex/plugins/editor/which-key.lua`

## Rollback/Contingency

If the centralized `_active_tool` approach causes issues, revert `ai-tool-picker.lua` to the previous version via `git checkout HEAD -- lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`. The `<leader>ac` keymap in `which-key.lua` is independent and can be kept or reverted separately. The original heuristic detection is preserved as the fallback path in `smart_toggle()`, so partial rollback (removing only `_active_tool` fast path) is also possible.
