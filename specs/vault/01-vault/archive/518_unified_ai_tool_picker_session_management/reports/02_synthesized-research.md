# Synthesized Research Report: Task 518 - Unified AI Tool Picker

- **Task**: 518 - Unified AI tool picker with two-stage session management
- **Started**: 2026-05-03T14:00:00Z
- **Completed**: 2026-05-03T16:30:00Z
- **Effort**: 2 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - specs/518_unified_ai_tool_picker_session_management/reports/01_teammate-a-findings.md
  - specs/518_unified_ai_tool_picker_session_management/reports/01_teammate-c-findings.md
  - specs/518_unified_ai_tool_picker_session_management/reports/01_teammate-d-findings.md
  - lua/neotex/config/keymaps.lua (keybinding definitions, terminal detection)
  - lua/neotex/plugins/ai/claude/core/session.lua (smart_toggle, show_session_picker)
  - lua/neotex/plugins/ai/claude/core/session-manager.lua (detect_claude_buffers, state persistence)
  - lua/neotex/plugins/ai/opencode.lua (OpenCode snacks.terminal configuration)
  - lua/neotex/plugins/editor/which-key.lua (<leader>as collision, model selector pattern)
  - lua/neotex/plugins/ai/shared/picker/config.lua (shared picker infrastructure)
  - lua/neotex/plugins/ai/opencode/commands/picker.lua (cross-module dependency)
  - opencode.nvim/lua/opencode.lua (public API: toggle, select_session, command)
  - opencode.nvim/lua/opencode/ui/select_session.lua (session picker impl)
  - opencode.nvim/lua/opencode/server/init.lua (session/event API)
  - opencode.nvim/lua/opencode/events.lua (SSE event subscription)
  - opencode.nvim/lua/opencode/api/command.lua (TUI commands)
  - opencode.nvim/lua/opencode/terminal.lua (terminal buffer management)
  - snacks.nvim/lua/snacks/terminal.lua (filetype, tid, get API)
  - docs/MAPPINGS.md (keybinding documentation)
  - docs/AI_TOOLING.md (AI tool references)
- **Artifacts**:
  - specs/518_unified_ai_tool_picker_session_management/reports/02_synthesized-research.md
- **Standards**: report-format.md

## Executive Summary

- Two-stage picker architecture is confirmed correct. Stage 1 (2-item tool choice) should use `vim.ui.select`, not Telescope. Stage 2 (per-tool session management) reuses existing Claude picker and builds an equivalent 3-option picker for OpenCode.
- The `opencode_terminal` filetype at keymaps.lua:121 is dead code: snacks.nvim always sets `snacks_terminal`. OpenCode terminal detection must use `snacks.terminal.get()` or buffer-name matching, not filetype.
- JSON persistence for last-tool tracking should use a clean atomic write pattern, not the backup-on-failure approach that created 9,611 orphaned files in `~/.local/share/nvim/claude/`.
- The `<leader>as` collision in which-key (both Claude sessions and OpenCode select mapped to same key) must be resolved as part of this task.
- Documentation at `docs/MAPPINGS.md:123` and `docs/AI_TOOLING.md:38` incorrectly documents `<C-c>` as the Claude Code toggle; actual binding is `<C-CR>`.
- OpenCode lacks a "restore last session" primitive. This must be implemented via last-session-ID tracking in a JSON file with `server:select_session()`.
- The cross-module dependency (`opencode/commands/picker.lua` → `claude/commands/picker/init.lua`) is a design debt noted but out of scope for this task.

## Context & Scope

### What is being researched
A unified keybinding (`<C-CR>`) that replaces both the current `<C-CR>` (Claude Code smart toggle) and `<C-g>` (OpenCode toggle) global bindings. The workflow is two-stage: first pick which AI tool to use, then pick session management action (new, restore last, browse all) tailored to the selected tool.

### Constraints
- Must integrate with existing Telescope-based picker infrastructure for Claude Code session management
- Must use snacks.nvim terminal for OpenCode (already configured in `opencode.lua`)
- Must not break surround.lua's `<C-g>s`/`<C-g>S` insert-mode bindings
- Must not break Telescope's `<C-g>` close-picker binding

### In scope
- New unified picker module at `shared/picker/ai-tool-picker.lua`
- Stage 1: 2-item tool picker with last-selection persistence
- Stage 2: Claude session picker reuse + new OpenCode session picker
- Active terminal detection for both tools (skip picker if one is visible)
- `<C-CR>` keybinding replacement across all modes (n, i, v, t)
- `<leader>as` collision resolution
- Documentation corrections for `<C-c>` → `<C-CR>`

### Out of scope
- Moving `claude/commands/picker/init.lua` to `shared/picker/` (separate refactor task)
- Frequency-based tool ordering beyond last-selected (future enhancement)
- Context-aware tool selection by filetype/directory (future enhancement)
- Full session count display in Stage 1 picker (future enhancement)
- Unified session history picker combining both tools (separate task)

## Findings

### Consensus Findings (all teammates agree)

1. **Module location**: New module at `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`. This aligns with the existing `shared/picker/config.lua` and keeps AI tool infrastructure consolidated.

2. **Smart toggle pattern**: Before showing any picker, check if an active terminal is visible. If Claude is visible in the current layout, `vim.cmd("ClaudeCode")` to toggle it off. If OpenCode is visible, `require("opencode").toggle()` to hide it. Only show the picker when neither is active.

3. **Claude session picker reuse**: Stage 2 for Claude directly delegates to `require("neotex.plugins.ai.claude.core.session").show_session_picker()`, which provides the existing 3-option dropdown (new/continue/browse).

4. **OpenCode last-session tracking needed**: OpenCode has no `--continue` equivalent. A JSON file at `stdpath("data") .. "/opencode/last-session.json"` storing `{last_session_id, timestamp}` is required to enable the "restore last session" option. Session ID must be captured via an `OpencodeEvent:session.idle` autocmd.

5. **`<C-CR>` replaces both current bindings**: The global `<C-g>` mapping (keymaps.lua:283) must be removed. Buffer-local `<C-g>` in OpenCode terminals (keymaps.lua:138) should be preserved (though currently dead code - see verified findings).

6. **`<leader>as` collision must be resolved**: which-key.lua:257 maps `<leader>as` to `claude.resume_session()` and line 263 maps `<leader>as` to `opencode.select()`. The OpenCode binding wins due to last-writer-wins. Both bindings must be differentiated or replaced with a unified AI sessions picker.

7. **Pre-existing documentation inconsistency**: `docs/MAPPINGS.md:123`, `docs/AI_TOOLING.md:38`, and keymaps.lua header comments (lines 23, 78) all document `<C-c>` as the Claude Code toggle. The actual binding is `<C-CR>`. These must be corrected.

8. **Stage 2 picker structure**: The session picker for both tools should offer three options: (a) create new session, (b) restore most recent session (with time-ago display), (c) browse all sessions with full picker.

### Verified Code Findings (direct inspection)

1. **`opencode_terminal` filetype is dead code (CONFIRMED)**:
   - snacks.nvim sets `buftype = "snacks_terminal"` at line 34 of `snacks/terminal.lua`
   - `opencode.nvim` only sets `"opencode_ask"` filetype (for the ask input), never `"opencode_terminal"`
   - `keymaps.lua:121` (`vim.bo.filetype == "opencode_terminal"`) is always false
   - The buffer-local `<C-g>` at keymaps.lua:138 never executes
   - **Fix required**: OpenCode terminal detection must use `snacks.terminal.get("opencode --port", opts)` or buffer-name matching

2. **9,611 backup files confirmed (CONFIRMED)**:
   - `~/.local/share/nvim/claude/` contains 9,611 `last_session.json.backup.*` files
   - Caused by `session-manager.lua:293-298` (`cleanup_state_file()` renames corrupted state to backup)
   - The 5-second timer at line 467-470 continuously calls `sync_state_with_processes()` → `validate_state_file()` → `cleanup_state_file()`
   - **Do not replicate this pattern**. Use atomic `io.open` + write + rename, or `vim.g` in-memory only

3. **Cross-module dependency confirmed (CONFIRMED)**:
   - `opencode/commands/picker.lua:8`: `local internal = require("neotex.plugins.ai.claude.commands.picker.init")`
   - OpenCode's picker facade depends on Claude's module
   - No functional impact on task 518, but noted as design debt for future refactor

4. **`<leader>as` collision confirmed (CONFIRMED)**:
   - which-key.lua:257: `{ "<leader>as", function() require("neotex.plugins.ai.claude").resume_session() end, desc = "claude sessions" }`
   - which-key.lua:263: `{ "<leader>as", function() require("opencode").select() end, desc = "opencode select" }`
   - OpenCode binding wins. Claude sessions mapping silently shadowed
   - Description "opencode select" is misleading: calls `opencode.select()` which is the full feature selector, not a session picker

5. **Documentation errors confirmed (CONFIRMED)**:
   - `docs/MAPPINGS.md:123`: `| <C-c> | All | Toggle Claude Code sidebar |`
   - `docs/AI_TOOLING.md:38`: `**Keybindings**: <C-c> (toggle)`
   - keymaps.lua header comment line 23: `<C-c> | Toggle Claude Code (overridden in Telescope)`
   - keymaps.lua header comment line 78: `<C-c> | Toggle Claude Code (global binding, not autolist)`
   - Actual binding at keymaps.lua:265-279: `<C-CR>`

6. **OpenCode event system usable for session tracking (CONFIRMED)**:
   - `opencode/events.lua` subscribes to SSEs and fires `OpencodeEvent:<event.type>` autocmds
   - Available event types include `session.idle`, `message.updated`, `message.part.updated`
   - `session.idle` fires with session data that includes the session ID
   - Can be used to update last-session tracking: listen for `OpencodeEvent:session.idle`
   - Connected server port is passed as `data.port` in autocmd data

7. **OpenCode `select_session()` uses server API internally (CONFIRMED)**:
   - `opencode/ui/select_session.lua`: queries `/session` endpoint, sorts by `time.updated` desc
   - `opencode/init.lua:61-72`: `M.select_session()` wraps this, calls `server:select_session(result.session.id)` after selection
   - `server/init.lua:263-268`: `Server:select_session(session_id)` POSTs to `/tui/select-session` with `{sessionID: session_id}`
   - This can be used for "Browse all sessions" in OpenCode Stage 2

8. **Snacks terminal detection caveat (CONFIRMED)**:
   - `snacks/terminal.lua:176-184`: `tid()` includes `opts.cwd or vim.fn.getcwd(0)` in the terminal ID
   - If cwd changes between invocation and detection, `snacks.terminal.get("opencode --port", opts)` returns nil
   - This means the opencode_win_opts used in `lua/neotex/plugins/ai/opencode.lua` (lines 37-47) does NOT include an explicit `cwd`, so `getcwd(0)` at time of open is used
   - **Mitigation**: For detection, iterate all active terminal buffers checking buffer name or use `snacks.terminal.list()` and match by `cmd` field in `vim.b.snacks_terminal`

### Open Questions and Disagreements

#### 1. Telescope vs `vim.ui.select` for Stage 1 (RESOLVED)

- **Teammate A**: Recommends Telescope dropdown (consistency with existing session picker pattern)
- **Teammate C**: Recommends `vim.ui.select` (lighter, matches project conventions for small selections)
- **Teammate D**: Strongly recommends `vim.ui.select` (snacks-enhanced, established pattern at worktree.lua:78 and which-key.lua:424 for model selection)
- **Resolution**: Use `vim.ui.select`. The project already uses `vim.ui.select` for 2-4 item choices (worktree type, AI model, binary confirmations). Loading Telescope machinery for exactly 2 items is unnecessary overhead. The model selector at which-key.lua:424 follows exactly this pattern. Snacks picker is already configured and can style `vim.ui.select`.

#### 2. JSON file vs in-memory persistence for last tool (RESOLVED)

- **Teammate A**: Recommends JSON at `stdpath("data") .. "/neotex-ai/tool-picker-prefs.json"` (follows Claude session pattern)
- **Teammate C**: Recommends `vim.g.ai_last_tool` (avoids backup proliferation, cross-restart persistence is marginal for 2 items)
- **Teammate D**: Recommends JSON at `stdpath("data") .. "/ai_tool_state.json"` with usage counts (frequency-based ordering)
- **Resolution**: Use JSON file for cross-restart persistence, but with clean implementation. Write via `io.open` + `vim.fn.json_encode` + no backup-on-failure proliferation. The file is small (~50 bytes) and the cross-restart memory is genuinely useful: users often work exclusively with one tool for days. Track `last_selected` only; defer usage counts to a future enhancement. Location: `vim.fn.stdpath("data") .. "/neotex-ai/tool-prefs.json"` to avoid polluting the existing `claude/` directory.

#### 3. OpenCode Stage 2 implementation approach (RESOLVED)

- **Teammate A**: Build a new 3-option OpenCode session picker mirroring Claude's, using `select_session()` for browse, tracking last ID for restore
- **Teammate C**: Points out OpenCode has no session picker infrastructure; building one is significant scope
- **Resolution**: Build the 3-option picker for OpenCode. The scope is smaller than it appears because:
  - `opencode.select_session()` already exists and handles "Browse all sessions" (50 lines to integrate, not build)
  - "New session" is `require("opencode").toggle()` followed by `opencode.command("session.new")` (existing APIs)
  - "Restore last" is the only genuinely new feature: track session ID, call `server:select_session(last_id)` after ensuring server is running
  - The picker UI is ~40 lines of Telescope dropdown code (standard pattern, already done for Claude)

#### 4. "Both terminals visible" behavior (RESOLVED)

- **Teammate C**: Identifies this as undefined - neither A nor D addressed it
- **Resolution**: When both terminals are visible simultaneously (realistic with wide monitors):
  - If only Claude is visible: toggle Claude off
  - If only OpenCode is visible: toggle OpenCode off
  - If both are visible: show Stage 1 picker (let user choose which to act on)
  - This is the safest behavior that doesn't surprise the user

#### 5. Snacks terminal detection reliability (NOTED)

- **Teammate A**: Uses filetype `opencode_terminal` (proven wrong)
- **Teammate C**: Recommends `snacks.terminal.get("opencode --port", opts)` but notes cwd coupling issue
- **Resolution**: Use `snacks.terminal.list()` and match by buffer-local variable. Each terminal stores `vim.b.snacks_terminal = {cmd, id, cwd, env}`. Iterate `snacks.terminal.list()` entries, check `term.buf` for `vim.b.snacks_terminal.cmd` matching `"opencode --port"`. This is cwd-independent.

## Decisions

### Module structure

```
lua/neotex/plugins/ai/shared/picker/
  config.lua           -- existing: parameterized picker presets
  ai-tool-picker.lua   -- NEW: unified two-stage picker module
```

### Stage 1: Tool selection (vim.ui.select)

```lua
-- Two options, reordered to show last-selected first
vim.ui.select({"Claude Code", "OpenCode"}, {
  prompt = "AI Tool:",
}, function(choice)
  if choice == "Claude Code" then
    show_claude_session_picker()
  elseif choice == "OpenCode" then
    show_opencode_session_picker()
  end
end)
```

### Stage 2: Claude session picker (reuse existing)

```lua
local function show_claude_session_picker()
  require("neotex.plugins.ai.claude.core.session").show_session_picker()
end
```

### Stage 2: OpenCode session picker (new, Telescope dropdown)

Three options in a Telescope dropdown matching the Claude pattern:
- "Create new session" → `require("opencode").toggle()` then `opencode.command("session.new")`
- "Restore last session (X ago)" → `require("opencode").toggle()` then `server:select_session(last_id)`
- "Browse all sessions" → `require("opencode").toggle()` then `require("opencode").select_session()`

### Smart toggle entry point

```lua
function M.smart_toggle()
  if is_claude_active() and is_claude_visible() then
    vim.cmd("ClaudeCode")
    return
  end
  if is_opencode_active() and is_opencode_visible() then
    require("opencode").toggle()
    return
  end
  M.show_tool_picker()
end
```

OpenCode active detection using snacks.terminal.list():
```lua
local function is_opencode_active()
  local ok, snacks_term = pcall(require, "snacks.terminal")
  if not ok then return false end
  for _, term in ipairs(snacks_term.list()) do
    if term:buf_valid() and term.buf then
      local st = vim.b[term.buf].snacks_terminal
      if st and st.cmd == "opencode --port" then
        return true
      end
    end
  end
  return false
end
```

### Persistence

File: `vim.fn.stdpath("data") .. "/neotex-ai/tool-prefs.json"`
Schema: `{ last_tool: "claude" | "opencode", last_updated: <unix timestamp> }`
Write pattern: atomic using `io.open` with `"w"` mode, no backup proliferation

File: `vim.fn.stdpath("data") .. "/neotex-ai/opencode-last-session.json"`
Schema: `{ session_id: "<id>", timestamp: <unix timestamp> }`
Updated via: `OpencodeEvent:session.idle` autocmd

### Keymap changes

keymaps.lua lines 264-283:
- Replace all `<C-CR>` mappings to call `require("neotex.plugins.ai.shared.picker.ai-tool-picker").smart_toggle()`
- Remove global `<C-g>` mapping at line 283
- Keep comment at line 285 (`-- OpenCode toggle: Use <leader>aoo via which-key`)

which-key.lua:
- Remove line 257 (`<leader>as` → `claude.resume_session`)
- Remove line 263 (`<leader>as` → `opencode.select`)
- Add: `<leader>as` → unified AI session picker or AI tool picker

## Recommendations

### Phase 1: Fix pre-existing issues before building

1. **Fix OpenCode terminal detection everywhere**: Replace all uses of `opencode_terminal` filetype with snacks.terminal-based detection. This affects `keymaps.lua:121,133-138` and any code that assumes `opencode_terminal` filetype.

2. **Clean up the 9,611 backup files**: Add a cleanup step for `last_session.json.backup.*` files. Either a one-time cleanup or a cap on backup file count in `session-manager.lua`.

3. **Correct documentation**: Update `docs/MAPPINGS.md:123`, `docs/AI_TOOLING.md:38`, `docs/DOCUMENTATION_STANDARDS.md:217`, and keymaps.lua header comments (lines 23, 78) to document `<C-CR>` instead of `<C-c>`.

### Phase 2: Core implementation

4. **Create `shared/picker/ai-tool-picker.lua`** with:
   - `setup()` function that creates data directory and reads prefs
   - `smart_toggle()` entry point with active-terminal detection
   - `show_tool_picker()` using `vim.ui.select` with last-tool reordering
   - `show_claude_session_picker()` delegating to existing module
   - `show_opencode_session_picker()` with 3-option Telescope dropdown
   - Session-tracking autocmd for OpenCode (`OpencodeEvent:session.idle`)

5. **Update keymaps.lua**: Replace `<C-CR>` mappings (n, i, v, t) to call new module. Remove global `<C-g>` binding.

6. **Update which-key.lua**: Resolve `<leader>as` collision. Remove both current bindings. Add unified AI sessions mapping or map `<leader>as` to the new unified picker.

### Phase 3: Integration and Polish

7. **Test active terminal detection** for both tools across different cwds
8. **Test defer_fn timing** for OpenCode server startup (300-500ms expected)
9. **Verify `<C-g>s`/`<C-g>S`** in surround.lua still work after removing global `<C-g>`

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| OpenCode server startup delay causes `session.new` to fail | Medium | Medium | Use `vim.wait()` retry loop (up to 2000ms) before sending TUI commands. The `opencode.command()` API uses `server.get()` which retries but doesn't account for TUI render delay. |
| Snacks terminal detection misses OpenCode when cwd changed | Low | Medium | Use `snacks.terminal.list()` + `vim.b.snacks_terminal.cmd` match instead of `get()`. Verified this is cwd-independent. |
| Claude terminal channel > 0 but process already dead | Low | Low | Current `detect_claude_buffers()` uses `channel > 0`. For task 518, add `vim.fn.jobwait([channel], 0)` returning -1 check. |
| `vim.ui.select` looks plain without enhancement | Medium | Low | Snacks picker is already configured and enhances `vim.ui.select`. Icon prefixes provide visual richness even without styling. |
| Breaking `<C-g>` affects Telescope close picker | Low | High | Telescope uses `<C-g>` as `actions.close` (telescope.lua:27). Removing only the global n/i `<C-g>` mapping while keeping Telescope's internal binding avoids this. Verified: Telescope uses its own attach_mappings, not global maps. |
| Scope creep into picker refactor | Medium | Low | Explicitly keep shared picker refactor out of scope. Task 518 only creates the unified tool picker module. |

## Context Extension Recommendations

- **Topic**: AI tool picker integration
- **Gap**: No context documentation exists for the unified AI tool picker workflow. When task 518 is implemented, it introduces a new user-facing interaction pattern (two-stage picker) that differs from the current direct-toggle approach.
- **Recommendation**: After implementation, add a section to `docs/AI_TOOLING.md` documenting the unified picker flow, keybindings, and session management options for both tools.

- **Topic**: Terminal detection patterns
- **Gap**: The codebase has no documented approach for detecting active terminal buffers across tools (Claude Code uses buffer name matching, OpenCode uses snacks.terminal API). This pattern is reusable for future terminal-based integrations.
- **Recommendation**: After task 518 stabilizes, extract terminal detection logic into a shared utility at `shared/terminal-detection.lua` with documented patterns for both tools.

## Appendix

### Key API signatures

**Claude Code session picker** (`claude/core/session.lua`):
```lua
M.smart_toggle()          -- entry point, detects active buffer then shows picker
M.show_session_picker()   -- 3-option Telescope dropdown picker
M.check_for_recent_session() -- validates state file, checks cwd match, 24h recency
```

**OpenCode public API** (`opencode.nvim/lua/opencode.lua`):
```lua
opencode.toggle()         -- toggles configured server (snacks.terminal.toggle)
opencode.command(cmd)     -- sends TUI command (e.g. "session.new", "session.list")
opencode.select_session() -- Neovim-side session picker using server API
```

**OpenCode server API** (`opencode.nvim/lua/opencode/server/init.lua`):
```lua
server:get_sessions(callback)      -- GET /session → [{id, title, time: {created, updated}}]
server:select_session(session_id)  -- POST /tui/select-session {sessionID: session_id}
server:tui_execute_command(cmd)    -- POST /tui/publish {type: "tui.command.execute", properties: {command: cmd}}
```

**OpenCode event system** (`opencode.nvim/lua/opencode/events.lua`):
```lua
-- Fires User autocmds with pattern "OpencodeEvent:<event.type>"
-- Event types: session.idle, session.diff, session.heartbeat,
--              message.updated, message.part.updated, permission.updated,
--              session.error, server.connected, server.instance.disposed
-- Autocmd data: { event: opencode.server.Event, port: integer }
```

**Snacks terminal API** (`snacks.nvim/lua/snacks/terminal.lua`):
```lua
snacks.terminal.open(cmd, opts)    -- open new terminal
snacks.terminal.toggle(cmd, opts)  -- toggle existing or open new
snacks.terminal.get(cmd, opts)     -- returns snacks.win or nil (tid includes cwd)
snacks.terminal.list()             -- returns snacks.win[] for all active terminals
-- Each term has: term.buf (buffer number), term:win_valid(), term:buf_valid()
-- Buffer-local: vim.b[buf].snacks_terminal = {cmd, id, cwd, env}
```

### File inventory

| Path | Purpose | Action for task 518 |
|------|---------|---------------------|
| `lua/neotex/config/keymaps.lua` | Global keybindings, terminal detection | Replace `<C-CR>` blocks (lines 264-283), remove global `<C-g>`, fix terminal detection |
| `lua/neotex/plugins/ai/claude/core/session.lua` | Claude smart_toggle, show_session_picker | No changes needed; reuse existing API |
| `lua/neotex/plugins/ai/claude/core/session-manager.lua` | detect_claude_buffers, state persistence | Optionally fix backup proliferation; no changes needed for picker |
| `lua/neotex/plugins/ai/opencode.lua` | OpenCode plugin config with snacks.terminal | No changes needed; reuse toggle/command APIs |
| `lua/neotex/plugins/editor/which-key.lua` | Keybinding display and leader maps | Remove lines 257, 263; add unified `<leader>as` |
| `lua/neotex/plugins/ai/shared/picker/config.lua` | Parameterized picker presets | No changes needed |
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | **NEW**: Unified two-stage picker | Create this file |
| `docs/MAPPINGS.md` | Keybinding reference (line 123) | Fix `<C-c>` → `<C-CR>` |
| `docs/AI_TOOLING.md` | AI tool documentation (line 38) | Fix `<C-c>` → `<C-CR>`; add unified picker section |
| `docs/DOCUMENTATION_STANDARDS.md` | Documentation policy (line 217) | Fix `<C-c>` → `<C-CR>` |

### Verification checklist for implementation

- [ ] `opencode_terminal` filetype no longer used as detection mechanism
- [ ] OpenCode terminal detection uses `snacks.terminal.list()` + `vim.b.snacks_terminal.cmd`
- [ ] Tool preference file uses atomic write, no backup proliferation
- [ ] `<C-g>` global (n/i) binding removed; Telescope `<C-g>` close still works
- [ ] `<C-g>s`/`<C-g>S` in surround.lua unaffected
- [ ] Both terminals visible simultaneously falls through to picker
- [ ] Claude and OpenCode session pickers both offer new/last/browse options
- [ ] OpenCode "restore last session" tracks session ID via `session.idle` event
- [ ] Documentation correctly references `<C-CR>` for AI tool toggle
