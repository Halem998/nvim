# Research Report: Task 518 - Teammate A Findings

**Task**: 518 - Unified AI Tool Picker with Two-Stage Session Management
**Focus**: Implementation Approaches and Patterns
**Researcher**: Teammate A (Primary Angle)

---

## Key Findings

### 1. Claude Code Session Management (Current Implementation)

**`claude/core/session.lua` - `smart_toggle()`**

The current `smart_toggle()` is the entry point from `<C-CR>`:

```lua
function M.smart_toggle()
  local session_manager = require("neotex.plugins.ai.claude.core.session-manager")
  local claude_buffers = session_manager.detect_claude_buffers()
  local claude_buf_exists = #claude_buffers > 0

  if claude_buf_exists then
    vim.cmd("ClaudeCode")               -- just toggle (show/hide)
  else
    local has_recent_session = M.check_for_recent_session()
    local native_sessions = require("neotex.plugins.ai.claude.ui.native-sessions")
    local all_sessions = native_sessions.get_all_sessions()
    local has_any_sessions = all_sessions and #all_sessions > 0

    if has_recent_session or has_any_sessions then
      M.show_session_picker()           -- 3-option dropdown picker
    else
      vim.cmd("ClaudeCode")             -- no sessions: just start new
      M.save_session_state()
    end
  end
end
```

**`show_session_picker()` offers three options:**
- "Create new session" -> `vim.cmd("ClaudeCode")`
- "Restore previous session (X ago)" -> `claude_util.continue()` (uses `--continue` flag)
- "Browse all sessions" -> `native_sessions.show_session_picker()` (full Telescope list)

**Buffer detection** uses `session_manager.detect_claude_buffers()` which looks for `buftype == 'terminal'` with names matching `term://.*claude`, `ClaudeCode`, or `claude-code`. Checks `channel > 0` for active verification.

**State persistence**: `~/.local/share/nvim/claude/last_session.json` stores `{cwd, timestamp, git_root, branch}`.

### 2. OpenCode Session Management (Available API)

**`opencode.nvim` public API** (`/home/benjamin/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua`):

```lua
-- Toggle the snacks terminal window
opencode.toggle()

-- Send a TUI command to the running opencode process
opencode.command("session.new")    -- start new session in TUI
opencode.command("session.list")   -- open session browser in TUI (shows list inside the TUI)

-- Select session via Neovim-side picker (vim.ui.select)
opencode.select_session()          -- queries server API, shows picker, calls server:select_session(id)
```

**Server API** (`server/init.lua`):
- `server:get_sessions(callback)` - GET `/session` - returns `[{id, title, time: {created, updated}}]`
- `server:select_session(session_id)` - POST `/tui/select-session` - switches active session
- Sessions have `time.updated` in milliseconds (Unix timestamp * 1000)

**Critical distinction**:
- `opencode.command("session.list")` sends a TUI keypress command that opens the session browser *inside the opencode terminal* - requires the terminal to be running first
- `opencode.select_session()` is a Neovim-side picker that queries the HTTP API - works independently of the TUI state
- `opencode.command("session.new")` sends TUI command to start a new session *within* the running TUI

**OpenCode terminal detection**: OpenCode uses `snacks.terminal` with cmd `"opencode --port"`. Detection:
```lua
local term = require("snacks.terminal").get("opencode --port", opencode_win_opts)
-- term is nil if not started, or a snacks.win object
-- term:win_valid() checks if the window is currently visible
-- term:buf_valid() checks if the buffer exists
```

The `opencode_win_opts` must match exactly what was used when opening - the same table reference is needed to find the terminal by ID.

**Buffer-local `<C-g>`** in `keymaps.lua` line 138: Applied only to `opencode_terminal` filetype buffers (`vim.bo.filetype == "opencode_terminal"`). This is set by the snacks terminal integration and is terminal-mode only. Completely separate from the global `<C-g>` in normal/insert modes.

### 3. Current Keybindings

```lua
-- keymaps.lua lines 265-283
map("n", "<C-CR>", function() require("neotex.plugins.ai.claude").smart_toggle() end, ...)
map("i", "<C-CR>", ...)
map("v", "<C-CR>", ...)
map("t", "<C-CR>", ...)

-- Global OpenCode toggle (to be removed)
map({ "n", "i" }, "<C-g>", function() require("opencode").toggle() end, {}, "Toggle Opencode")

-- Buffer-local (keep this one)
buf_map(0, "t", "<C-g>", "<cmd>lua require('opencode').toggle()<CR>", "Toggle Opencode")
-- Only set when is_opencode == true in set_terminal_keymaps()
```

### 4. Shared Picker Infrastructure

The `shared/picker/config.lua` provides parameterized configuration presets for Claude vs OpenCode. It is used for the *commands/artifacts picker* (`ClaudeCommands`, `OpencodeCommands`), not for session management. The session picker would need to be built separately or extend this pattern.

### 5. OpenCode Session Parity Analysis

| Feature | Claude Code | OpenCode Equivalent |
|---------|-------------|---------------------|
| New session | `vim.cmd("ClaudeCode")` (no --continue) | `opencode.command("session.new")` (TUI command) OR just `opencode.toggle()` when no session |
| Restore last session | `vim.cmd("ClaudeCodeContinue")` | No direct equivalent - `session.list` + select last one |
| Browse sessions | `native_sessions.show_session_picker()` | `opencode.select_session()` (uses `vim.ui.select`) |
| Detect active terminal | `session_manager.detect_claude_buffers()` | `snacks.terminal.get("opencode --port", opts)` |

**Key gap**: OpenCode has no "restore last session" primitive equivalent to Claude's `--continue`. The best approach is:
1. Track last OpenCode session ID in a JSON file (same pattern as Claude's `last_session.json`)
2. When "restore last" is selected: ensure opencode is running, then call `server:select_session(last_id)`

---

## Recommended Implementation Approach

### Architecture: New Module `shared/picker/ai-tool-picker.lua`

Create a unified module at `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` with the following structure:

#### Stage 0: Persistence

```lua
local data_dir = vim.fn.stdpath("data") .. "/neotex-ai"
local prefs_file = data_dir .. "/tool-picker-prefs.json"

local function load_prefs()
  -- returns { last_tool = "claude"|"opencode" }
end

local function save_prefs(prefs)
  -- writes JSON to prefs_file
end
```

Also track last OpenCode session ID:
```lua
local opencode_state_file = data_dir .. "/opencode-last-session.json"
```

#### Stage 1: Active Terminal Detection

```lua
local function is_claude_active()
  local session_manager = require("neotex.plugins.ai.claude.core.session-manager")
  return #session_manager.detect_claude_buffers() > 0
end

local function is_opencode_active()
  -- Must use the same opts table used when opening the terminal
  -- Best approach: expose a function from the opencode config or use buf detection
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
      if ft == "opencode_terminal" then
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
        if buftype == "terminal" then
          return true
        end
      end
    end
  end
  return false
end
```

**Alternative for OpenCode detection** (more reliable): Check via `snacks.terminal` list:
```lua
local function is_opencode_active()
  local ok, snacks_terminal = pcall(require, "snacks.terminal")
  if not ok then return false end
  for _, term in ipairs(snacks_terminal.list()) do
    if term:win_valid() then
      local buf = term.buf
      if buf and vim.api.nvim_buf_is_valid(buf) then
        local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
        if ft == "opencode_terminal" then return true end
      end
    end
  end
  return false
end
```

#### Stage 2: Smart Toggle Entry Point

```lua
function M.smart_toggle()
  -- If Claude is visible, just toggle it off
  if is_claude_active() then
    vim.cmd("ClaudeCode")
    return
  end

  -- If OpenCode terminal is visible (window open), just toggle it
  if is_opencode_active() then
    require("opencode").toggle()
    return
  end

  -- Neither is active - show Stage 1 tool picker
  M.show_tool_picker()
end
```

#### Stage 3: Stage 1 Tool Picker

```lua
function M.show_tool_picker()
  local prefs = load_prefs()
  local options = {
    { display = "Claude Code", value = "claude", icon = "" },
    { display = "OpenCode",    value = "opencode", icon = "󰘳" },
  }

  -- Reorder to show last-used first
  if prefs.last_tool == "opencode" then
    options = { options[2], options[1] }
  end

  -- Telescope dropdown picker
  pickers.new(require("telescope.themes").get_dropdown({...}), {
    prompt_title = "AI Tool",
    finder = finders.new_table({ results = options, ... }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local tool = selection.value.value
        save_prefs({ last_tool = tool })
        M.show_session_picker(tool)   -- Stage 2
      end)
      return true
    end,
  }):find()
end
```

#### Stage 4: Stage 2 Session Picker (per tool)

**For Claude Code** - reuse existing logic:
```lua
local function show_claude_session_picker()
  -- Directly call existing M.show_session_picker() from session.lua
  require("neotex.plugins.ai.claude.core.session").show_session_picker()
end
```

**For OpenCode** - new equivalent:
```lua
local function show_opencode_session_picker()
  local options = {
    { display = "New session",           value = "new",     icon = "󰈔" },
    { display = "Restore last session",  value = "last",    icon = "󰊢" },
    { display = "Browse all sessions",   value = "browse",  icon = "󰑐" },
  }

  pickers.new(require("telescope.themes").get_dropdown({...}), {
    prompt_title = "OpenCode Session",
    ...
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local choice = selection.value.value
        if choice == "new" then
          -- Ensure opencode is running, then start new session
          require("opencode").toggle()           -- open the terminal
          vim.defer_fn(function()
            require("opencode").command("session.new")
          end, 300)  -- wait for server to be ready
        elseif choice == "last" then
          _restore_last_opencode_session()
        elseif choice == "browse" then
          -- Use opencode.select_session() which has its own Neovim-side picker
          -- First ensure server is running
          require("opencode").toggle()
          vim.defer_fn(function()
            require("opencode").select_session()
          end, 300)
        end
      end)
      return true
    end,
  }):find()
end
```

**Restore last OpenCode session**:
```lua
local function _restore_last_opencode_session()
  local state = load_opencode_state()
  if not state or not state.last_session_id then
    -- No tracked session, just open normally
    require("opencode").toggle()
    return
  end
  -- Start opencode and select the session
  require("opencode").toggle()
  vim.defer_fn(function()
    local ok, server_mod = pcall(require, "opencode.server")
    if ok then
      server_mod.get():next(function(server)
        server:select_session(state.last_session_id)
      end)
    end
  end, 500)
end
```

**Track last OpenCode session**: Subscribe to OpenCode events:
```lua
-- In the opencode.lua config, add event listener
vim.api.nvim_create_autocmd("User", {
  pattern = "OpenCodeSessionChanged",  -- if available
  callback = function(event)
    save_opencode_state({ last_session_id = event.data.session_id })
  end
})
```

*Note*: OpenCode events are exposed via `opencode.events`. The `session.idle` event fires with session data. Alternatively, save state when `session.new` or session selection is made.

#### Keymap Changes

**keymaps.lua** - replace the block at lines 264-283:
```lua
-- Unified AI tool picker
map("n", "<C-CR>", function()
  require("neotex.plugins.ai.shared.picker.ai-tool-picker").smart_toggle()
end, {}, "Toggle AI Tool (Claude Code / OpenCode)")
map("i", "<C-CR>", ...)
map("v", "<C-CR>", ...)
map("t", "<C-CR>", ...)

-- Remove the global <C-g> mapping (line 283)
-- Keep buffer-local <C-g> in set_terminal_keymaps() for OpenCode terminals
```

---

## Evidence and Examples

### Existing Smart Toggle Decision Logic (direct reference)

`claude/core/session.lua` lines 404-429: Smart toggle checks for active buffers first (direct toggle), then checks for available sessions (show picker), then falls back to new session. This exact three-way decision tree should be replicated at the unified picker level.

### OpenCode Server API Confirmation

`opencode.nvim/lua/opencode/server/init.lua` lines 247-268:
- `Server:get_sessions(callback)` returns `opencode.server.Session[]` with `{id, title, time: {created, updated}}`
- `Server:select_session(session_id)` POSTs to `/tui/select-session` with `{sessionID: session_id}`
- Sessions have millisecond timestamps (`time.updated / 1000` = Unix seconds)

### `select_session()` Existing Implementation

`opencode.nvim/lua/opencode/ui/select_session.lua`: Already implements a session picker using `vim.promise` and `vim.ui.select`. The `opencode.select_session()` API wraps this. This could be used for the "Browse all sessions" option to avoid duplicating the picker logic.

### Buffer Filetype for OpenCode Detection

`keymaps.lua` line 121: `vim.bo.filetype == "opencode_terminal"` is the reliable way to identify OpenCode buffers, set automatically by the snacks terminal integration.

### `session.list` Is a TUI Command, Not a Neovim Picker

`opencode/api/command.lua` line 5: `'session.list'` is a TUI keypress command sent to the running OpenCode terminal process. It opens the session browser *inside* the TUI. Requires the OpenCode server to be running. This is *different* from `select_session()` which is purely Neovim-side.

---

## Confidence Levels

| Area | Confidence | Notes |
|------|-----------|-------|
| Claude Code detection and toggle logic | High | Direct code inspection |
| Claude session picker reuse | High | `show_session_picker()` is clean, self-contained |
| OpenCode `select_session()` API | High | Well-documented, inspected source |
| OpenCode `session.new` command | High | TUI command - requires server running first |
| OpenCode terminal visibility detection | Medium | `snacks.terminal.list()` + filetype check is reliable but needs testing |
| Last session tracking for OpenCode | Medium | Need to hook into server events or manual tracking; `opencode.events` module needs closer review |
| `defer_fn` timing for OpenCode server startup | Low | 300-500ms is a guess; server startup time is variable; may need retry logic |
| Stage 1 picker "remember last tool" | High | Standard JSON persistence pattern, already used by Claude session state |

---

## Open Questions for Implementation

1. **OpenCode server startup delay**: When `opencode.toggle()` is called and the server isn't running, how long before the server accepts `tui_execute_command`? The `opencode.command()` API already handles this via `server.get()` which retries - but if the TUI needs to be rendered first, there may be an additional delay.

2. **`session.list` vs `select_session()`**: For the "Browse all sessions" option, should we use `opencode.command("session.list")` (opens native TUI browser in the terminal) or `opencode.select_session()` (Neovim-side picker)? The Neovim-side picker (`select_session()`) gives more UI control and is consistent with the Telescope approach used for Claude. Recommend `select_session()` for better feature parity.

3. **OpenCode event subscription**: The `opencode.events` module exists - does it expose session change events that can be used to track `last_session_id`? If not, the simplest approach is to save state whenever the user selects a session via our picker.

4. **Stage 2 picker title**: Should the Stage 2 picker show which tool was selected in the title? e.g., "Claude Code Session" vs "OpenCode Session". Yes, for clarity.

5. **`<C-CR>` in terminal mode with Claude active**: The current code maps `t` mode. When Claude Code is active and focused, pressing `<C-CR>` should toggle it off. The `t` mode mapping calling `smart_toggle()` -> `ClaudeCode` (toggle) achieves this correctly.
