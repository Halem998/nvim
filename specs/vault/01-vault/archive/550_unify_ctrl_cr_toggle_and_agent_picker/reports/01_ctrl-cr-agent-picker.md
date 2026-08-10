# Research Report: Unify Ctrl-CR Toggle and Agent Picker

- **Task**: 550 - unify_ctrl_cr_toggle_and_agent_picker
- **Started**: 2026-05-08T00:00:00Z
- **Completed**: 2026-05-08T00:30:00Z
- **Effort**: ~30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - `lua/neotex/config/keymaps.lua` -- global keybinding definitions
  - `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` -- unified AI tool picker module
  - `lua/neotex/plugins/ai/claudecode.lua` -- ClaudeCode plugin spec
  - `lua/neotex/plugins/ai/opencode.lua` -- OpenCode plugin spec
  - `lua/neotex/plugins/ai/claude/core/session.lua` -- Claude session management
  - `lua/neotex/plugins/ai/claude/core/session-manager.lua` -- Claude buffer detection
  - `lua/neotex/plugins/editor/which-key.lua` -- leader-key group definitions
  - `~/.local/share/nvim/lazy/claude-code.nvim/lua/claude-code/terminal.lua` -- upstream toggle logic
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` -- upstream OpenCode API
  - `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` -- snacks terminal toggle
- **Artifacts**: `specs/550_unify_ctrl_cr_toggle_and_agent_picker/reports/01_ctrl-cr-agent-picker.md`
- **Standards**: report-format.md

## Project Context

- **Upstream Dependencies**: `claude-code.nvim` (greggh/claude-code.nvim), `opencode.nvim` (NickvanDyke/opencode.nvim), `snacks.nvim` (folke/snacks.nvim)
- **Downstream Dependents**: `keymaps.lua`, `which-key.lua`, all user-facing AI toggle workflows
- **Alternative Paths**: None identified
- **Potential Extensions**: Multi-agent simultaneous toggle, workspace-aware agent routing

## Executive Summary

- `<C-CR>` calls `ai-tool-picker.smart_toggle()` in all modes (n/i/v/t), which detects active terminals and either toggles the running tool or shows a Stage 1 picker
- OpenCode toggle works because `snacks.terminal.toggle("opencode --port", ...)` creates and tracks terminals by command string, allowing reliable show/hide cycles
- ClaudeCode toggle fails because `detect_active_claude()` requires both a valid terminal buffer AND a still-running job (channel liveness check via `jobwait`), which may not detect hidden Claude buffers correctly; but more critically, the `smart_toggle` branch for Claude calls `vim.cmd("ClaudeCode")` which itself calls `claude-code.toggle()` -- but this toggle uses a separate instance registry (`instances[instance_id]`) which may be out of sync with the buffer detection in `detect_active_claude()`
- The root cause is an asymmetry in detection vs toggle plumbing: `detect_active_claude()` scans ALL buffers for terminal names matching "claude", but `ClaudeCode` toggle operates on `instances[instance_id]` keyed by git root -- when detection finds a buffer but the instance table has no entry (or vice versa), the toggle does nothing or creates a new instance instead of showing/hiding
- `<leader>ac` is currently unmapped and available for the agent picker
- Session management exists for both tools: Claude has native JSONL sessions in `~/.claude/projects/`, OpenCode has `neotex-ai/opencode-last-session.json`

## Context and Scope

This research investigates the `<C-CR>` keybinding behavior for toggling AI code assistants (ClaudeCode and OpenCode) and the feasibility of adding a `<leader>ac` keymap to launch the agent picker. The investigation covers the full code path from keypress to terminal visibility change.

## Findings

### 1. Current `<C-CR>` Binding Architecture

The `<C-CR>` binding is defined in `lua/neotex/config/keymaps.lua` (lines 272-294) for all four modes (n, i, v, t). All modes call the same function:

```
ai-tool-picker.smart_toggle()
```

The `smart_toggle()` function (line 335-361 of `ai-tool-picker.lua`) follows this logic:

1. Call `detect_active_claude()` -- checks all buffers for terminal buffers with "claude" in name, verifies channel liveness via `jobwait`
2. Call `detect_active_opencode()` -- checks `snacks.terminal.list()` for terminals with cmd matching `"opencode --port"`
3. If only Claude is active: run `vim.cmd("ClaudeCode")`
4. If only OpenCode is active: run `require("opencode").toggle()`
5. If both or neither: show the Stage 1 tool picker (`M.show_tool_picker()`)

### 2. OpenCode Toggle -- Working Flow

OpenCode's toggle is implemented through `snacks.terminal`:

- **Config** (`opencode.lua` line 56): `opts.server.toggle` calls `require("snacks.terminal").toggle("opencode --port", opencode_win_opts)`
- **snacks.terminal.toggle** (`snacks/terminal.lua` line 218): Looks up terminal by command+opts ID, creates if missing, shows/hides if existing
- **Detection** (`detect_active_opencode()`): Uses `snacks.terminal.list()` then filters by `vim.b[buf].snacks_terminal.cmd` matching `"opencode --port"`

This works because snacks.terminal maintains a persistent `terminals[id]` table keyed by `cmd + cwd + env + vim.v.count1`. The detection function queries this same table. Both detection and toggle use the same identity mechanism.

### 3. ClaudeCode Toggle -- Failing Flow

ClaudeCode's toggle involves two separate identity systems that are not synchronized:

**Detection side** (`detect_active_claude()` in `ai-tool-picker.lua` lines 85-103):
- Scans all vim buffers via `vim.api.nvim_list_bufs()`
- Filters to terminal buffers
- Checks buffer name for "claude" patterns
- Verifies channel liveness via `vim.fn.jobwait()`
- Uses `session_manager.detect_claude_buffers()` which matches `term://.*claude`, `ClaudeCode`, or `claude%-code`

**Toggle side** (`claude-code.nvim/terminal.lua` toggle function):
- Uses `instances[instance_id]` where `instance_id` defaults to `"global"` (since `multi_instance` is not set)
- On toggle: if `instances["global"]` has a valid buffer, it shows/hides the window
- If `instances["global"]` is nil or invalid, it creates a new terminal

**The disconnect**: When Claude is launched through the session picker (via `M.show_claude_session_picker()` -> `session.show_session_picker()` -> either `vim.cmd("ClaudeCode")` or `claude_util.continue()` or `claude_util.open_with_command()`), the buffer gets created properly. However, the session manager's `detect_claude_buffers()` might find the buffer while `claude-code.nvim`'s internal `instances["global"]` may point to a different or stale buffer reference.

More specifically, when `open_with_command()` is called (for continue/resume), it:
1. Temporarily changes `claude_code.config.command` to e.g. `"claude --continue"`
2. Calls `claude_code.toggle()` which creates a new terminal
3. Restores the original command

On the next `<C-CR>` press:
- `detect_active_claude()` finds the terminal buffer (returns true)
- `smart_toggle()` sees only Claude is active, so it runs `vim.cmd("ClaudeCode")`
- `ClaudeCode` calls `claude_code.toggle()` which checks `instances["global"]`
- If the buffer stored in `instances["global"]` is the one from the variant command, it should work
- BUT if there's a mismatch (e.g., the buffer name is `claude-code` but the `instances["global"]` was set to a different bufnr that was cleaned up), the toggle creates a NEW instance instead of showing/hiding

A second failure mode: the `is_valid_terminal_buffer()` check in `terminal.lua` (line 269) validates that `terminal_job_id` exists and `jobwait` returns -1 (still running). If the Claude CLI process exits (e.g., idle timeout), the buffer still exists but `is_valid_terminal_buffer()` returns false, causing the toggle to delete the buffer and create a new one -- which would appear to the user as "nothing happening" (new terminal opens but old one was just closed).

A third failure mode specific to terminal mode: when inside a Claude Code terminal buffer and pressing `<C-CR>`, the terminal might capture the keycode before Neovim's mapping fires. The `<C-CR>` mapping in terminal mode (line 290) should work since it's a `vim.keymap.set` with `noremap=true`, but some terminal programs may intercept Ctrl-Enter.

### 4. Root Cause Analysis

The primary root cause is **identity system mismatch**:

- `detect_active_claude()` uses buffer-name scanning (heuristic)
- `claude-code.nvim toggle()` uses `instances[instance_id]` registry (authoritative)
- These two systems can disagree about whether a Claude buffer exists

Secondary causes:
- Process liveness checks (`jobwait`) can fail if the Claude CLI process exits but the terminal buffer remains
- The session manager's buffer detection patterns (`term://.*claude`, `ClaudeCode`, `claude%-code`) may not match the actual buffer name generated by `generate_buffer_name()` which produces `"claude-code"` (or `"claude-code-<path>"` for multi-instance)

### 5. Session Management

**Claude sessions**:
- Stored as JSONL files in `~/.claude/projects/<hashed-project>/`
- Last session state saved in `~/.local/share/nvim/claude/last_session.json`
- Native session browser in `lua/neotex/plugins/ai/claude/ui/native-sessions.lua`
- Session picker provides three options: new, continue, browse

**OpenCode sessions**:
- Managed by the OpenCode TUI itself
- Last session ID tracked in `~/.local/share/nvim/neotex-ai/opencode-last-session.json`
- Session restoration via `server:select_session(session_id)`
- Session picker provides three options: new, restore, browse

### 6. `<leader>a` Group Mappings

Current mappings in `which-key.lua`:

| Keymap | Description | Status |
|--------|-------------|--------|
| `<leader>a` | ai group | Active |
| `<leader>al` | ai load commands/agents (n+v) | Active |
| `<leader>ad` | opencode diagnostics | Active |
| `<leader>as` | discord sessions | Active |
| `<leader>ar` | link discord | Active |
| `<leader>ay` | toggle yolo mode | Active |
| `<leader>ak` | kill sleep inhibitors | Active |
| `<leader>ac` | (unmapped) | **Available** |

`<leader>ac` is free and semantically appropriate ("ai choose" or "ai code-agent").

### 7. Agent Picker Architecture (Stage 1)

The Stage 1 picker (`show_tool_picker()` in `ai-tool-picker.lua`) uses `vim.ui.select` with two items:
- ClaudeCode
- OpenCode

Ordered by `tool_prefs.last_tool` (persisted to `~/.local/share/nvim/neotex-ai/tool-prefs.json`).

After selection, it routes to:
- Claude: `show_claude_session_picker()` -> delegates to `claude/core/session.show_session_picker()`
- OpenCode: `show_opencode_session_picker()` -> Telescope dropdown with new/restore/browse

## Decisions

- The `<leader>ac` keymap should invoke `show_tool_picker()` (the Stage 1 picker) directly, bypassing `smart_toggle()` detection logic. This gives users explicit control to switch agents regardless of what's currently running.

## Recommendations

### R1: Fix `smart_toggle()` Claude detection to use the plugin's own instance registry

Instead of scanning all buffers heuristically, query `claude-code.nvim`'s internal state:

```lua
local function detect_active_claude()
  local ok, claude_code = pcall(require, "claude-code")
  if not ok then return false, {} end

  -- Check the plugin's own instance registry
  local instances = claude_code.claude_code and claude_code.claude_code.instances or {}
  local active = {}
  for _, bufnr in pairs(instances) do
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
      if buftype == "terminal" then
        table.insert(active, bufnr)
      end
    end
  end
  return #active > 0, active
end
```

This ensures `detect_active_claude()` agrees with what `ClaudeCode` toggle will actually operate on.

### R2: Fix the ClaudeCode toggle to handle hidden but alive buffers

When the toggle finds an instance buffer that is valid but whose window is not visible, it should re-open the window (which it does in `handle_existing_instance()`). The issue is the `is_valid_terminal_buffer()` check which also verifies `terminal_job_id` and `jobwait`. If the job ended, the toggle deletes the buffer and creates a new one.

For the toggle to work consistently, the detection in `smart_toggle()` should mirror the same liveness check that `toggle()` uses. If `toggle()` considers a buffer invalid, `detect_active_claude()` should also return false for it, causing `smart_toggle()` to fall through to the picker instead.

### R3: Add `<leader>ac` keymap in `which-key.lua`

Add the following to the `<leader>a` group in `which-key.lua`:

```lua
{ "<leader>ac", function()
  local ok, picker = pcall(require, "neotex.plugins.ai.shared.picker.ai-tool-picker")
  if not ok then
    vim.notify("AI tool picker module not loaded", vim.log.levels.WARN)
    return
  end
  if not picker._initialized then picker.setup() end
  picker.show_tool_picker()
end, desc = "ai agent picker", icon = "󰚩" },
```

### R4: Consider a unified toggle that uses the same identity for both detection and action

The cleanest fix would be to store the "active tool" state centrally in `ai-tool-picker`:

```lua
M._active_tool = nil  -- "claude" | "opencode" | nil
```

Set this when a tool is launched (in `show_claude_session_picker()` / `show_opencode_session_picker()`) and clear it when the tool's terminal buffer is wiped. Then `smart_toggle()` can simply:

1. If `_active_tool == "claude"`: run `vim.cmd("ClaudeCode")`
2. If `_active_tool == "opencode"`: run `require("opencode").toggle()`
3. If `_active_tool == nil`: show picker

This eliminates the heuristic buffer scanning entirely.

### R5: Handle terminal-mode key capture

For `<C-CR>` in terminal mode, verify the keymap actually fires by testing in a Claude Code terminal. If Claude's TUI captures Ctrl-Enter, consider using `<C-\\><C-n>` prefix to exit terminal mode first, or use a different mechanism (like the `<C-g>` pattern used for OpenCode in `set_terminal_keymaps()`).

## Risks and Mitigations

- **Risk**: Changing `detect_active_claude()` to use plugin internals couples the picker to `claude-code.nvim` API internals
  - **Mitigation**: The `claude_code.claude_code.instances` table is the plugin's documented public interface (exposed on `M.claude_code = terminal.terminal`). Pin to the current API shape and add a `pcall` guard.

- **Risk**: The `_active_tool` state approach (R4) can become stale if a terminal is closed through means other than the picker
  - **Mitigation**: Use a `BufWipeout` or `TermClose` autocmd to clear `_active_tool` when the tracked terminal buffer is destroyed.

- **Risk**: `<leader>ac` conflicts with future mappings
  - **Mitigation**: The `<leader>a` group has few active mappings; `ac` is memorable and unlikely to conflict.

## Appendix

### Key File Paths

| File | Purpose |
|------|---------|
| `lua/neotex/config/keymaps.lua:272-294` | `<C-CR>` binding in all modes |
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | Unified picker module (smart_toggle, detection, stage 1/2) |
| `lua/neotex/plugins/ai/claudecode.lua` | ClaudeCode plugin spec and terminal autocmds |
| `lua/neotex/plugins/ai/opencode.lua` | OpenCode plugin spec and snacks.terminal config |
| `lua/neotex/plugins/ai/claude/core/session.lua` | Claude session picker UI and session management |
| `lua/neotex/plugins/ai/claude/core/session-manager.lua` | Claude buffer detection and session validation |
| `lua/neotex/plugins/ai/claude/claude-session/claude-code.lua` | Claude Code open/continue/resume utilities |
| `lua/neotex/plugins/editor/which-key.lua:243-396` | `<leader>a` group keymappings |
| `~/.local/share/nvim/lazy/claude-code.nvim/lua/claude-code/terminal.lua` | Upstream toggle logic (instances registry) |
| `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` | Snacks terminal toggle (used by OpenCode) |
