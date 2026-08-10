# Research Report: Task #544 — Fix OpenCode Session Picker Timing

- **Task**: 544 — fix_opencode_session_picker
- **Started**: 2026-05-07T19:00:00Z
- **Completed**: 2026-05-07T19:30:00Z
- **Effort**: 2-3 hours (estimate verified)
- **Dependencies**: None
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — current implementation (full read)
  - `lua/neotex/plugins/ai/opencode.lua` — plugin config with snacks.terminal
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` — public API (toggle, select_session)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` — Server API, event types, get() with polling
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/events.lua` — SSE subscription and OpencodeEvent dispatch
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` — session picker implementation
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/process/unix.lua` — process discovery via pgrep/lsof
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/config.lua` — default options
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/status.lua` — statusline, idle/error/responding states
  - `~/.local/share/nvim/lazy/opencode.nvim/plugin/events/disconnect.lua` — server.instance.disposed autocmd
  - `~/.local/share/nvim/lazy/opencode.nvim/plugin/events/reload.lua` — file.edited autocmd
  - `~/.local/share/nvim/lazy/opencode.nvim/plugin/events/status.lua` — wildcard OpencodeEvent:* for status
  - `specs/544_fix_opencode_session_picker/README.md` — task specification
  - `specs/archive/518_unified_ai_tool_picker_session_management/reports/02_synthesized-research.md` — prior research (518)
  - Codebase grep: search for OpencodeEvent, defer_fn, server.connected, vim.wait patterns
- **Artifacts**: `specs/544_fix_opencode_session_picker/reports/01_session-picker-timing.md`
- **Standards**: report-format.md

## Executive Summary

- The two `vim.defer_fn(..., 1000)` calls in `show_opencode_session_picker()` (lines 305, 315) are fundamentally unreliable: they assume the OpenCode server starts within 1 second, which fails under load or on slow systems.
- The opencode.nvim plugin itself provides a **robust `Server.get()` function** (server/init.lua:428-453) that polls for the server with 1-second retries up to 5 attempts — this is exactly the mechanism needed.
- `Server.get()` handles discovery (pgrep → pgrep retry → start → poll), and `select_session()` (opencode.lua:61-72) wraps `Server.get()` + session listing + session picker UI.
- **Recommended approach**: Replace `vim.defer_fn(1000)` → `server_mod.get()` / `server.select_session()` with a direct `Server.get()` promise chain for restore, and direct `opencode_mod.select_session()` call for browse. Both internally use the plugin's robust polling.
- The existing `OpencodeEvent:session.idle` autocmd (line 381) for last-session tracking is already correct and needs no changes.
- Edge cases (server startup failure, no sessions, timeout) are handled by the promise catch chain with vim.notify.

## Context & Scope

### What is being researched

The OpenCode session picker offers three options:
1. **"Create new session"** — Works correctly: just calls `opencode_mod.toggle()`.
2. **"Restore last session"** — Partially works: calls `toggle()`, then after a 1-second `vim.defer_fn`, retrieves the server and calls `server.select_session(last_session_id)`. Unreliable timing.
3. **"Browse all sessions"** — Partially works: calls `toggle()`, then after a 1-second `vim.defer_fn`, calls `opencode_mod.select_session()`. Unreliable timing.

### Constraints
- Must use the existing opencode.nvim plugin API — cannot modify the plugin itself.
- The server must be running before session API calls (`select_session`, `get_sessions`) can succeed.
- The task description specifies using `OpencodeEvent:server.connected` or polling for server-ready detection.
- "Create new session" must continue working (no changes needed).
- Must handle edge cases: server startup failure, timeout, no saved sessions.

### In scope
- Replace timing mechanism in `show_opencode_session_picker()`'s `attach_mappings` callback.
- Add proper error handling with user-facing notifications.

### Out of scope
- Changes to the OpenCode plugin itself.
- Changes to `OpencodeEvent:session.idle` autocmd (already correct).
- Changes to tool preference persistence.
- Changes to terminal detection (already correct).

## Findings

### 1. Current Implementation (ai-tool-picker.lua:298-318)

The problematic code is in the Telescope `attach_mappings` callback:

**"Restore last session" path (lines 302-313)**:
```lua
opencode_mod.toggle()
if choice == "restore" then
  if last_session_id then
    local server_mod = require("opencode.server")
    vim.defer_fn(function()
      local server = server_mod.get()
      if server then
        pcall(server.select_session, server, last_session_id)
      end
    end, 1000)
  end
```

Issues:
- `server_mod.get()` returns a **Promise**, not a synchronous server object. `get()` → `nil` check is always falsy because it evaluates to a Promise table (truthy), then `pcall(server.select_session, ...)` fails silently because `server` is a Promise, not a Server instance.
- The 1-second delay is arbitrary and unreliable.

**"Browse all sessions" path (lines 314-318)**:
```lua
opencode_mod.toggle()
if choice == "browse" then
  vim.defer_fn(function()
    pcall(opencode_mod.select_session)
  end, 1000)
end
```

Issues:
- `opencode_mod.select_session()` internally calls `Server.get()` which has its own 5-second polling. The 1-second defer is just wasted time here — it would be fine to call `select_session()` immediately since it polls internally.
- The `pcall` swallows errors silently.

### 2. OpencodeEvent API and `server.connected`

**Event types** (defined at server/init.lua:279-291):
```lua
---@alias opencode.server.event.type
---| "server.connected"           -- First event when server is alive
---| "server.instance.disposed"   -- Server shut down
---| "session.idle"              -- Session became idle
---| "session.diff"              -- Diff produced (strong idle signal)
---| "session.heartbeat"         -- 30-second heartbeat
---| "message.updated"           -- Response streaming
---| "message.part.updated"      -- Response part streaming
---| "permission.updated"        -- Permission state change
---| "permission.replied"        -- Permission answered
---| "session.error"            -- Error in session
```

**How `server.connected` fires** (events.lua:27-63):
- `events.connect(server)` subscribes to SSE on the server's `/event` endpoint.
- The first SSE event received sets `M.connected_server = server` (line 34).
- On each SSE event, an autocmd is fired: `OpencodeEvent:<event.type>` with data `{event = response, port = server.port}`.
- `server.connected` is the **first** event emitted when the SSE subscription is established — it signals the server is fully operational.
- A heartbeat timer (35-second timeout) detects dead connections.

**When `Server.get()` triggers this** (server/init.lua:428-453):
1. `find()` — tries connected server → configured port → discovers via pgrep
2. On failure: calls `start()` (if configured), then `poll()` (retries every 1s, up to 5 times)
3. On success: `events.connect(server)` subscribes to SSEs → `server.connected` event fires

### 3. `Server.get()` Polling Mechanism

The key discovery is that `Server.get()` already solves the timing problem:

```lua
function Server.get()
  local Promise = require("opencode.promise")
  local connected_server = require("opencode.events").connected_server

  return find()
    :catch(function(err)
      if not err then return Promise.reject() end
      local start_ok = pcall(start)
      if not start_ok then return Promise.reject(err) end
      return poll()  -- Retries every 1s, up to 5 attempts
    end)
    :next(function(server)
      if not connected_server or connected_server.port ~= server.port then
        require("opencode.events").connect(server)
      end
      return server
    end)
end
```

**`poll()` details** (server/init.lua:394-425):
```lua
local function poll()
  -- Creates uv timer, retries every 1000ms
  -- Runs find() on each tick
  -- Rejects after 5 retries (5 seconds total)
  -- Cleans up timer on resolve/reject
end
```

**`find()` → `get_all()`** chain:
- `pgrep -f "opencode.*--port"` finds process PIDs
- `lsof -Fpn -w -iTCP -sTCP:LISTEN -p <pids> -a -P -n` gets ports
- `Server.new(port)` curl-validates each candidate, rejecting non-servers
- Returns validated Server instances

### 4. `select_session()` Implementation

From opencode.lua:61-72:
```lua
M.select_session = function()
  return require("opencode.ui.select_session")
    .select_session()
    :next(function(result)
      result.server:select_session(result.session.id)
    end)
    :catch(function(err)
      vim.notify(err, vim.log.levels.ERROR, { title = "opencode" })
    end)
end
```

This calls `Server.get()` → lists sessions → shows picker → calls `server:select_session(id)`. All async, all with built-in polling. Calling this directly (without the 1-second defer) is safe because `Server.get()` handles the polling.

### 5. Existing `OpencodeEvent:session.idle` Autocmd

Lines 377-398 of ai-tool-picker.lua:
```lua
vim.api.nvim_create_autocmd("User", {
  group = "NixAIOpencodeSession",
  pattern = "OpencodeEvent:session.idle",
  callback = function(event)
    -- Extracts session_id from event.data, writes to opencode-last-session.json
  end,
})
```

This is correctly implemented and needs no changes. It tracks the last active session for the "restore" option.

### 6. Existing `OpencodeEvent:server.connected` Listeners in Plugin

The plugin itself registers these autocmds:

| File | Pattern | Purpose |
|------|---------|---------|
| `plugin/events/disconnect.lua` | `OpencodeEvent:server.instance.disposed` | Shut down SSE subscription |
| `plugin/events/reload.lua` | `OpencodeEvent:file.edited` | Auto-reload edited buffers |
| `plugin/events/status.lua` | `OpencodeEvent:*` | Update statusline state |
| `lua/opencode/events.lua` | `OpencodeEvent:<event.type>` | Main SSE dispatch |

There is **no existing listener** specifically for `OpencodeEvent:server.connected` that could conflict with a custom autocmd.

### 7. vim.wait() Polling Patterns in Codebase

The codebase uses `vim.wait()` extensively in tests and the himalaya plugin (30+ occurrences). Notably, `session-manager.lua:354` uses `vim.wait(100)` for Claude buffer detection. However, `openCode.nvim`'s own `Server.get()` already provides a superior Promise-based polling mechanism, making `vim.wait()` unnecessary.

## Recommendations

### Primary Recommendation: Replace defer_fn with direct Promise chain

Replace both `vim.defer_fn(1000)` blocks with direct `Server.get()` Promise chains. This leverages the plugin's own robust polling (5 retries × 1 second) instead of a single arbitrary delay.

**For "Restore last session"** — replace lines 302-313:
```lua
if choice == "restore" then
  if last_session_id then
    local server_mod = require("opencode.server")
    server_mod.get()
      :next(function(server)
        server:select_session(last_session_id)
      end)
      :catch(function(err)
        if err then
          vim.notify(
            "Failed to restore session: " .. tostring(err),
            vim.log.levels.ERROR,
            { title = "OpenCode" }
          )
        end
      end)
  else
    vim.notify("No previous OpenCode session to restore", vim.log.levels.WARN)
  end
end
```

**For "Browse all sessions"** — replace lines 314-318:
```lua
elseif choice == "browse" then
  -- select_session() internally uses Server.get() with built-in polling
  opencode_mod.select_session()
end
```

### Why This Works

1. `toggle()` starts the terminal → `opencode --port` process begins.
2. `Server.get()` → `find()` → pgrep discovers the process → `Server.new(port)` curl-validates → returns Server.
3. If server isn't ready yet: fallback `start()` (no-op since already started) → `poll()` retries every second.
4. After max 5 seconds: either resolves with server or rejects with error.
5. The async pattern is non-blocking — doesn't freeze Neovim while waiting.

### Why This Is Better Than Autocmd-Based Approach

While `OpencodeEvent:server.connected` could be used with a one-shot autocmd:
```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent:server.connected",
  once = true,
  callback = function(args)
    local port = args.data.port
    -- Then reconstruct server and act...
  end,
})
```

The `Server.get()` approach is superior because:
- **No port reconstruction**: autocmd data has `port` but not the full Server object. Extracting session_id requires curl calls that `Server.get()` already handles.
- **Already battle-tested**: `Server.get()` is the plugin's own server discovery mechanism, used by `select_session()`, `select_server()`, and all programmatic APIs.
- **Cleaner error handling**: Promise chain with proper `.catch()` vs. autocmd callback that can't easily propagate errors.
- **No race condition**: Using the autocmd approach, you'd register the listener, then toggle the server. But what if the server was already running? The event already fired. `Server.get()` handles both cold-start and warm-server cases.
- **No resource leak**: Autocmd requires explicit cleanup; the Promise chain self-cleans.

### Hybrid Approach (if autocmd is preferred)

If using `OpencodeEvent:server.connected` is desired (per task requirements), the cleanest hybridization is:

```lua
opencode_mod.toggle()
if choice == "restore" and last_session_id then
  local augroup_name = "OpenCodeRestore" .. tostring(os.time())
  vim.api.nvim_create_augroup(augroup_name, { clear = true })
  local timer = vim.uv.new_timer()

  local function cleanup()
    timer:stop()
    timer:close()
    vim.api.nvim_del_augroup_by_name(augroup_name)
  end

  -- Timeout after 10 seconds
  timer:start(10000, 0, vim.schedule_wrap(function()
    cleanup()
    vim.notify("OpenCode server startup timed out", vim.log.levels.ERROR, { title = "OpenCode" })
  end))

  vim.api.nvim_create_autocmd("User", {
    group = augroup_name,
    pattern = "OpencodeEvent:server.connected",
    once = true,
    callback = function(args)
      cleanup()
      local port = args.data.port
      local server_mod = require("opencode.server")
      server_mod.Server.new(port)
        :next(function(server)
          server:select_session(last_session_id)
        end)
        :catch(function(err)
          vim.notify(
            "Failed to restore session: " .. tostring(err or "unknown"),
            vim.log.levels.ERROR,
            { title = "OpenCode" }
          )
        end)
    end,
  })
end
```

This is more complex than the primary recommendation but satisfies the explicit requirement for `server.connected`.

## Decisions

1. **Primary approach**: Use `Server.get()` Promise chain instead of `vim.defer_fn(1000)` — simpler, uses plugin's own infrastructure, handles both warm and cold server states.
2. **Browse case**: Remove the 1-second defer from `opencode_mod.select_session()` entirely — the function internally polls via `Server.get()`.
3. **Error handling**: Use `.catch()` with `vim.notify()` for user-facing error messages, replacing silent `pcall` that swallows failures.
4. **No changes to session tracking**: The existing `OpencodeEvent:session.idle` autocmd is correct.
5. **No vim.wait()**: The plugin's Promise-based polling is superior to blocking `vim.wait()` calls.

## Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| Server takes <1 second | `Server.get()` find() succeeds immediately |
| Server takes 2-5 seconds | `poll()` retries, catches it on retry 2-5 |
| Server takes >5 seconds | `poll()` rejects, `.catch()` shows error notification |
| Server process killed midway | `events.disconnect()` called automatically by plugin |
| No saved sessions | "none yet" shown in picker, restore shows WARN notification |
| toggle() opened existing terminal | `find()` finds connected_server immediately |
| Network error on curl | `Server.new()` rejects, `get_all()` filters it out |
| Multiple servers on same CWD | Plugin shows server selection UI (existing behavior) |

## Context Extension Recommendations

- **Topic**: opencode.nvim server lifecycle
- **Gap**: The codebase lacks documentation on `Server.get()`'s internal polling mechanism and promise-based API. The existing synthesized research (518) documents event types but not the server discovery flow.
- **Recommendation**: Add a section to `.opencode/context/extensions/nvim-extension.md` covering `Server.get()` flow: find → pgrep → curl-validate → start fallback → poll retry. This would benefit future tasks involving server-dependent operations.

## Appendix: Search Queries

- `grep "OpencodeEvent"` — 20 matches across config, specs, docs
- `grep "defer_fn.*1000"` in *.lua — no direct matches (1000 is passed as second arg, not in pattern)
- `grep "defer_fn"` in *.lua — 151 matches across codebase (pattern is widely used but not all are timing workarounds)
- `grep "server.connected"` — 4 matches (all in specs/docs, none in codebase)
- `grep "vim.wait"` in *.lua — 33 matches, mostly in test files and himalaya plugin
- `glob **/opencode/**/*.lua` — 6 local files in `lua/neotex/`, 30 files in lazy plugin directory
- Full-file reads of 12 key files (ai-tool-picker.lua, opencode.lua, server/init.lua, events.lua, etc.)

## Appendix: File Reference Map

| File | Lines | Role |
|------|-------|------|
| `ai-tool-picker.lua` | 298-318 | Problematic defer_fn blocks |
| `ai-tool-picker.lua` | 368-398 | Correct session.idle autocmd |
| `ai-tool-picker.lua` | 222-324 | Full `show_opencode_session_picker()` |
| `opencode.lua` (top-level) | 61-72 | `select_session()` with internal polling |
| `server/init.lua` | 279-291 | Event type definitions |
| `server/init.lua` | 394-425 | `poll()` — 5×1s retry loop |
| `server/init.lua` | 428-453 | `Server.get()` — main entry with fallback |
| `server/init.lua` | 303-332 | `Server.get_all()` — pgrep + curl filter |
| `server/init.lua` | 263-268 | `Server:select_session()` — POST endpoint |
| `events.lua` | 27-63 | `events.connect()` — SSE subscription + autocmd dispatch |
| `process/unix.lua` | 50-70 | `get()` — pgrep for processes |
| `process/unix.lua` | 5-47 | `get_processes_with_ports()` — lsof for ports |
| `status.lua` | 42-69 | Status state machine |
| `plugin/events/status.lua` | 1-10 | Wildcard `OpencodeEvent:*` autocmd |
| `plugin/events/disconnect.lua` | 1-8 | `server.instance.disposed` cleanup |
