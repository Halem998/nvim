# Implementation Plan: Unified AI Tool Picker with Session Management

- **Task**: 518 - unified_ai_tool_picker_session_management
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/518_unified_ai_tool_picker_session_management/reports/02_synthesized-research.md
- **Artifacts**: plans/01_unified-ai-picker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Replace the two separate AI tool keybindings (`<C-CR>` for Claude Code and `<C-g>` for OpenCode) with a single `<C-CR>` binding that invokes a unified two-stage picker. Stage 1 presents a 2-item tool selection (Claude Code vs OpenCode) using `vim.ui.select` with last-used-tool persistence. Stage 2 presents a per-tool session management picker offering new session, restore last, and browse-all options. Active terminal detection skips the picker entirely when one tool is already visible. This task also fixes four pre-existing bugs discovered during research: dead `opencode_terminal` filetype detection, 9,611 orphaned backup files, the `<leader>as` collision in which-key, and incorrect `<C-c>` documentation throughout the codebase.

### Research Integration

All findings from the synthesized research report (`reports/02_synthesized-research.md`) are integrated. Key decisions: Stage 1 uses `vim.ui.select` (not Telescope) for the 2-item tool picker; OpenCode terminal detection uses `snacks.terminal.list()` instead of the dead `opencode_terminal` filetype; tool preferences persist to `stdpath("data")/neotex-ai/tool-prefs.json` with atomic writes; OpenCode session tracking persists to `stdpath("data")/neotex-ai/opencode-last-session.json` via `OpencodeEvent:session.idle` autocmd.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No directly relevant items in ROADMAP.md (current roadmap focuses on documentation infrastructure and agent system quality, not AI tool picker changes).

## Goals & Non-Goals

**Goals**:
- Create `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` as the unified picker module
- Implement two-stage picker flow: tool selection (vim.ui.select) then per-tool session picker (Telescope dropdown)
- Remember last tool selection across restarts via JSON persistence with atomic writes
- Detect active AI terminals and toggle them directly, bypassing the picker
- Reuse existing Claude session picker (`show_session_picker`) for Stage 2 Claude path
- Build 3-option OpenCode session picker (new, restore last, browse all) for Stage 2 OpenCode path
- Replace all `<C-CR>` keymap targets with the unified smart_toggle entry point
- Remove global `<C-g>` binding (lines 282-283 of keymaps.lua)
- Fix pre-existing `<leader>as` collision in which-key.lua (lines 257 and 263)
- Fix dead `opencode_terminal` filetype detection in keymaps.lua (lines 121, 133-138)
- Clean up 9,611 orphaned `last_session.json.backup.*` files in `~/.local/share/nvim/claude/`
- Correct `<C-c>` documentation errors in docs/MAPPINGS.md, docs/AI_TOOLING.md, and keymaps.lua header comments

**Non-Goals**:
- No third tool support (Aider, Copilot) -- out of scope
- No context-aware tool selection by filetype or project directory
- No frequency-based or usage-count tool ordering beyond last-selected
- No moving picker implementations from claude/ to shared/ (separate refactor task)
- No unified cross-tool session history picker

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OpenCode server startup delay causes `session.new` or `select_session` to fail | Medium | Medium | Use `vim.wait()` retry loop (up to 2000ms) after `toggle()` before sending TUI commands. The `opencode.command()` API uses `server.get()` which retries but does not account for TUI render delay. |
| Snacks terminal detection misses OpenCode when cwd differs from invocation time | Low | Medium | Use `snacks.terminal.list()` + match `vim.b.snacks_terminal.cmd` field instead of `snacks.terminal.get()`. Verified this is cwd-independent. |
| Removing global `<C-g>` impacts other bindings | Low | High | Only remove n/i mode `<C-g>` at keymaps.lua:283. Telescope uses internal attach_mappings for `<C-g>` close, not global maps. surround.lua `<C-g>s`/`<C-g>S` is a separate key sequence, unaffected. |
| Claude terminal channel > 0 but process already dead (false positive) | Low | Low | Add `vim.fn.jobwait([channel], 0)` check returning -1 to confirm process liveness in Claude detection path. |
| Scope creep into shared picker refactor | Medium | Low | Explicitly scope-gate: only create the new ai-tool-picker.lua module. Do not move existing Claude picker code. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Pre-existing Bugs [COMPLETED]

**Goal**: Clean up the environment and correct documentation before building the new picker. This phase addresses all four confirmed issues from research: the backup file proliferation, dead terminal detection code, which-key collision, and documentation inconsistencies.

**Tasks**:
- [ ] **Task 1.1**: Clean up 9,611 orphaned backup files in `~/.local/share/nvim/claude/`. Run `find ~/.local/share/nvim/claude/ -name "last_session.json.backup.*" -delete` to remove all backup files. Optionally add a backup file count cap to `session-manager.lua` `cleanup_state_file()` to prevent future proliferation.
- [ ] **Task 1.2**: Fix dead `opencode_terminal` filetype detection in `keymaps.lua`. Replace `vim.bo.filetype == "opencode_terminal"` at line 121 with `vim.b.snacks_terminal` and `cmd` string matching. Replace the buffer-local `<C-g>` mapping at lines 133-138 (which never executes) with corrected terminal detection. The block-bound `<C-j>/<C-k>` menu navigation mappings should also be checked for correctness.
- [ ] **Task 1.3**: Fix `<leader>as` collision in `which-key.lua`. Remove line 257 (`<leader>as` → `claude.resume_session()`) and line 263 (`<leader>as` → `opencode.select()`). Replace with a single unified binding -- map `<leader>as` to the new unified tool picker (will reference the module from Phase 2) or the unified session picker.
- [ ] **Task 1.4**: Correct `<C-c>` → `<C-CR>` documentation errors. Update `docs/MAPPINGS.md:123`, `docs/AI_TOOLING.md:38`, `docs/DOCUMENTATION_STANDARDS.md:217`, and keymaps.lua header comments (lines 23, 78) to reference `<C-CR>` instead of `<C-c>`.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/config/keymaps.lua` -- fix terminal detection at lines 121, 133-138; fix header comments at lines 23, 78
- `lua/neotex/plugins/editor/which-key.lua` -- remove lines 257 and 263; add new unified `<leader>as`
- `docs/MAPPINGS.md` -- fix line 123
- `docs/AI_TOOLING.md` -- fix line 38
- `docs/DOCUMENTATION_STANDARDS.md` -- fix line 217
- `lua/neotex/plugins/ai/claude/core/session-manager.lua` -- optional: add backup file count cap

**Verification**:
- `last_session.json.backup.*` files are gone from `~/.local/share/nvim/claude/`
- Keymaps.lua header no longer references `<C-c>` for AI toggle
- which-key.lua has exactly one `<leader>as` binding
- Docs reference `<C-CR>` for all AI tool toggles

### Phase 2: Build the Core ai-tool-picker.lua Module [COMPLETED]

**Goal**: Create the unified two-stage picker module with tool persistence, active terminal detection, and both Stage 2 session picker paths.

**Tasks**:
- [ ] **Task 2.1**: Create `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` with module skeleton (`M.setup()`, data directory creation, preferences loading).
- [ ] **Task 2.2**: Implement tool preference persistence. Write `load_tool_prefs()` and `save_tool_prefs(tool)` using `vim.fn.stdpath("data") .. "/neotex-ai/tool-prefs.json"` with schema `{last_tool: "claude" | "opencode", last_updated: <unix timestamp>}`. Use atomic `io.open` + `vim.fn.json_encode` writes -- no backup proliferation.
- [ ] **Task 2.3**: Implement active terminal detection for both tools. For Claude: use `session-manager.detect_claude_buffers()` with channel liveness check (`vim.fn.jobwait([channel], 0)` returning -1). For OpenCode: use `snacks.terminal.list()` iterating entries and matching `vim.b.snacks_terminal.cmd` for `"opencode --port"`.
- [ ] **Task 2.4**: Implement `smart_toggle()` entry point. Priority logic: if only one tool is visible, toggle it directly. If both visible, fall through to picker. If neither visible, show Stage 1 picker.
- [ ] **Task 2.5**: Implement Stage 1 `show_tool_picker()` using `vim.ui.select` with 2 options (`"Claude Code"`, `"OpenCode"`), reordered to show the last-selected tool first. On selection, save preference and delegate to the appropriate Stage 2 function.
- [ ] **Task 2.6**: Implement Stage 2 Claude path `show_claude_session_picker()`. Direct delegation to `require("neotex.plugins.ai.claude.core.session").show_session_picker()` -- no changes needed.
- [ ] **Task 2.7**: Implement Stage 2 OpenCode path `show_opencode_session_picker()`. Build a Telescope dropdown with 3 options: (a) "Create new session" calling `opencode.toggle()` + `opencode.command("session.new")` with retry; (b) "Restore last session (X ago)" reading from `stdpath("data")/neotex-ai/opencode-last-session.json`, calling `opencode.toggle()` + `server:select_session(last_id)` with retry; (c) "Browse all sessions" calling `opencode.toggle()` + `opencode.select_session()`.
- [ ] **Task 2.8**: Implement OpenCode session tracking. Register an autocmd on `OpencodeEvent:session.idle` that extracts the session ID from the event data and writes it to `stdpath("data")/neotex-ai/opencode-last-session.json` with schema `{session_id: "<id>", timestamp: <unix timestamp>}` using atomic writes.
- [ ] **Task 2.9**: Implement `setup()` function. Create data directories (`neotex-ai/`), load tool preferences, and register the `OpencodeEvent:session.idle` autocmd.

**Timing**: 1 hour 15 minutes

**Depends on**: 1

**Files to create**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` -- full module (~200 lines)

**Verification**:
- `setup()` creates `~/.local/share/nvim/neotex-ai/` directory
- `smart_toggle()` detects active Claude terminal and toggles it
- `smart_toggle()` detects active OpenCode terminal and toggles it
- Stage 1 picker shows last-selected tool first
- Stage 2 Claude options match existing `show_session_picker()`
- Stage 2 OpenCode picker offers 3 options

### Phase 3: Integrate Keymaps and Clean Up Bindings [COMPLETED]

**Goal**: Wire up the new module to all existing keybindings, remove the old `<C-g>` global binding, and finalize the which-key configuration.

**Tasks**:
- [ ] **Task 3.1**: Update `keymaps.lua` lines 264-279. Replace all four `<C-CR>` mode mappings (n, i, v, t) to call `require("neotex.plugins.ai.shared.picker.ai-tool-picker").smart_toggle()` instead of `require("neotex.plugins.ai.claude").smart_toggle()`. Update the description to "Unified AI tool picker".
- [ ] **Task 3.2**: Remove global `<C-g>` mapping at keymaps.lua lines 282-283. Delete the `map({ "n", "i" }, "<C-g>", ...)` block. Keep the comment at line 285 about `<leader>aoo`.
- [ ] **Task 3.3**: Update which-key.lua `<leader>as` binding (placed earlier in Phase 1, Task 1.3) to reference the new module: `require("neotex.plugins.ai.shared.picker.ai-tool-picker").show_tool_picker()` with description "AI tool picker" and `icon = "󰚩"`.
- [ ] **Task 3.4**: Add lazy loading hook. Ensure `ai-tool-picker.lua` `setup()` is called. This can be done via the keymap function itself (check if initialised, call setup if not) or via an autocmd in `VeryLazy` event.

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/config/keymaps.lua` -- update `<C-CR>` targets, remove `<C-g>`, fix header comments
- `lua/neotex/plugins/editor/which-key.lua` -- update `<leader>as` binding target

**Verification**:
- `<C-CR>` triggers unified picker in all modes (n, i, v, t)
- `<C-g>` in normal/insert mode does nothing (no mapping)
- `<leader>as` shows the unified AI tool picker
- `<leader>as` description in which-key says "AI tool picker"

### Phase 4: Polish, Test, and Verify [COMPLETED]

**Goal**: End-to-end validation of all picker paths, edge cases, and documentation updates.

**Tasks**:
- [ ] **Task 4.1**: Verify smart toggle behavior. Test: open Claude Code via `<C-CR>` → new session, press `<C-CR>` again to toggle off (no picker). Test: same for OpenCode. Test: open both Claude and OpenCode side-by-side, press `<C-CR>` → Stage 1 picker appears (both visible, fall through).
- [ ] **Task 4.2**: Verify last-tool persistence. Select OpenCode in Stage 1, reopen picker, verify OpenCode is listed first. Select Claude Code, reopen, verify Claude Code is listed first. Restart Neovim, verify preference survived.
- [ ] **Task 4.3**: Verify OpenCode session flow. Test "Create new session": picker opens, `session.new` is sent, terminal is active. Test "Restore last session": after a session is created and `session.idle` fires, reopen picker, verify the restore option shows time-ago. Test "Browse all sessions": verify `opencode.select_session()` opens the full session list.
- [ ] **Task 4.4**: Verify `<C-g>` removal didn't break anything. Test Telescope `<C-g>` close-picker still works. Test surround.lua `<C-g>s` in insert mode still works. Test surround `<C-g>S` in visual mode still works.
- [ ] **Task 4.5**: Update `docs/AI_TOOLING.md` with a new section documenting the unified picker workflow, the two-stage flow, and all relevant keybindings.

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `docs/AI_TOOLING.md` -- add unified picker section

**Verification**:
- All smart toggle edge cases work (single visible, both visible, neither visible)
- Last-tool persistence survives Neovim restart
- OpenCode session restore tracks sessions correctly
- Telescope and surround `<C-g>` bindings unaffected
- Documentation is accurate and complete

## Testing & Validation

- [ ] `<C-CR>` triggers unified picker in normal, insert, visual, and terminal modes
- [ ] Active Claude terminal detected and toggled directly (no picker)
- [ ] Active OpenCode terminal detected and toggled directly (no picker)
- [ ] Both terminals visible: picker shown (not toggled)
- [ ] Claude Stage 2: "Create new session" opens Claude Code
- [ ] Claude Stage 2: "Restore previous session" continues last session
- [ ] Claude Stage 2: "Browse all sessions" opens native session picker
- [ ] OpenCode Stage 2: "Create new session" opens OpenCode and sends session.new
- [ ] OpenCode Stage 2: "Restore last session" restores tracked session
- [ ] OpenCode Stage 2: "Browse all sessions" opens select_session()
- [ ] Last-tool selection persists through picker re-opening
- [ ] Last-tool selection persists through Neovim restart
- [ ] `<C-g>` in normal mode does nothing (no global mapping)
- [ ] Telescope `<C-g>` close picker still works
- [ ] surround.lua `<C-g>s` in insert mode still works
- [ ] `opencode_terminal` filetype no longer used as detection mechanism anywhere
- [ ] No new backup file proliferation from tool-prefs.json or opencode-last-session.json
- [ ] `<leader>as` in which-key shows "AI tool picker"

## Artifacts & Outputs

- `specs/518_unified_ai_tool_picker_session_management/plans/01_unified-ai-picker.md` -- this plan
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` -- **NEW**: unified two-stage picker module
- `lua/neotex/config/keymaps.lua` -- modified: updated `<C-CR>` targets, removed `<C-g>`
- `lua/neotex/plugins/editor/which-key.lua` -- modified: resolved `<leader>as` collision
- `docs/MAPPINGS.md` -- modified: corrected `<C-c>` → `<C-CR>`
- `docs/AI_TOOLING.md` -- modified: corrected `<C-c>` → `<C-CR>`; added unified picker section
- `docs/DOCUMENTATION_STANDARDS.md` -- modified: corrected `<C-c>` → `<C-CR>`
- `lua/neotex/plugins/ai/claude/core/session-manager.lua` -- optionally modified: backup file cap

## Rollback/Contingency

If the unified picker is broken or causes regressions:

1. **Revert keymaps.lua changes**: Restore `<C-CR>` to call `require("neotex.plugins.ai.claude").smart_toggle()` (the original target). Restore the global `<C-g>` mapping at line 283.
2. **Revert which-key.lua changes**: Restore lines 257 and 263 with their original `<leader>as` mappings.
3. **Remove ai-tool-picker.lua**: The module is self-contained -- deleting it has no side effects on other modules.
4. **Keep bug fixes**: The Phase 1 bug fixes (documentation corrections, terminal detection fix, backup cleanup) are independently valuable and should NOT be reverted.
