# Research Report: Task #576 — Fix OpenCode Session Picker

**Task**: 576 — fix_opencode_session_picker
**Started**: 2026-05-14T17:42:00Z
**Completed**: 2026-05-14T17:55:00Z
**Effort**: 1.5 hours
**Dependencies**: Task 575 (audit_opencode_session_picker_failure)
**Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (current implementation)
  - `lua/neotex/plugins/ai/opencode.lua` (plugin config with snacks.terminal)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` (public API)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` (Server.get(), find(), poll())
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` (session picker UI)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/events.lua` (event dispatch)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/config.lua` (config defaults)
  - `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` (terminal lifecycle)
  - `specs/575_audit_opencode_session_picker_failure/` (prior task artifacts)
**Artifacts**: `specs/576_fix_opencode_session_picker/reports/01_fix_opencode_session_picker.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Task 575 fixes are committed and correct**: The duplicate terminal creation race condition identified in task 575 has been fixed. The code now uses conditional `toggle()`, idempotent `start()`, and explicit port 3000.
- **Primary remaining bug**: The `OpencodeEvent:session.idle` autocmd in `ai-tool-picker.lua` extracts the session ID from the wrong path in the event data structure. It looks for `event.data.session_id`, but `event.data` is actually `{ event = response, port = N }`. The session ID (if present) is nested inside `event.data.event.properties`. Because of this bug, `opencode-last-session.json` is never written, so **"Restore last session" always shows "(none yet)" and does nothing**.
- **Secondary concern — stale connected_server**: `opencode.events.connected_server` is cached and may not be cleared when the terminal is closed. If stale, `Server.get()` returns a dead server object, causing `get_sessions()` and `select_session()` to fail silently.
- **"Browse all sessions" should work after 575 fix**: The browse path delegates to `opencode.select_session()` → `Server.get()` → `start()` → terminal creation → session picker. This flow is correct. If it's still reported as broken, the cause is likely either a stale `connected_server` or upstream plugin timing issues.

## Context & Scope

### What Was Researched

The OpenCode session picker (triggered via `<C-CR>` → OpenCode → Stage 2 picker) offers three options:
1. **"Create new session"** — Calls `toggle()`, opens terminal. Works.
2. **"Restore last session"** — Relies on `last_session_id` read from `opencode-last-session.json`. Broken because the file is never populated.
3. **"Browse all sessions"** — Calls `opencode.select_session()` which internally uses `Server.get()`. Should work after task 575 fix, but may fail due to stale server caching.

### Investigation Scope
- Verify the state of task 575 fixes in the working tree
- Trace the session tracking autocmd and identify why `opencode-last-session.json` is never written
- Analyze the `event.data` structure passed by `opencode.events`
- Examine `Server.get()` caching behavior and stale server risks
- Check for additional race conditions or API mismatches

## Findings

### 1. Session Tracking Autocmd Has Wrong Data Path (CRITICAL)

**File**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua:510-530`
**Current code**:
```lua
callback = function(event)
  local session_id = nil
  local data = event.data
  if type(data) == "string" then
    session_id = data
  elseif type(data) == "table" then
    session_id = data.session_id or data.id or data.session
  end
  if session_id then
    ensure_data_dir()
    atomic_write(opencode_session_file, {
      session_id = session_id,
      timestamp = os.time(),
    })
  end
end,
```

**Root cause**: In `opencode/events.lua`, events are dispatched with:
```lua
data = {
  event = response,  -- opencode.server.Event { type, properties }
  port = _server.port,
},
```

The callback expects `event.data` to contain the session ID directly (`data.session_id`), but `data` is actually a wrapper table. The actual event is at `data.event`, and its properties are at `data.event.properties`.

**Impact**: `session_id` is always `nil`. The `atomic_write` is never executed. `opencode-last-session.json` does not exist (verified on disk). When the picker loads, `last_session_id` is `nil`, so "Restore last session" displays "(none yet)" and does nothing.

### 2. Stale connected_server Cache (MEDIUM)

**File**: `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua:428-454`

`Server.get()` caches the connected server in `opencode.events.connected_server`. On subsequent calls, it returns the cached server immediately:
```lua
local connected_server = require("opencode.events").connected_server
return find()
  ...
```
And `find()` does:
```lua
return connected_server and Promise.resolve(connected_server)
```

**Risk**: If the opencode terminal is closed (e.g., via `:q` or `snacks.terminal.close()`), the server process dies, but `connected_server` may not be cleared immediately. The SSE subscription error handler eventually calls `disconnect()`, but there's a window where `Server.get()` returns a dead server.

**Impact**: If a dead server is returned, subsequent API calls like `get_sessions()` or `select_session()` will fail. The user sees no session picker or no session restoration.

### 3. Task 575 Fixes Are Correctly Applied (VERIFIED)

**Files**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`, `lua/neotex/plugins/ai/opencode.lua`

Git commit `c06deb576` (task 575) made the following changes:
- Restructured `attach_mappings` to only call `opencode_mod.toggle()` for "new" sessions
- Changed `start()` to use `snacks.terminal.get()` with dedup guard
- Set `attach_cmd = "opencode --port 3000"` and `opts.server.port = 3000`

These changes eliminate the duplicate terminal creation race. The code matches the task 575 recommendations exactly.

### 4. "Browse all sessions" Code Path Is Correct (VERIFIED)

**File**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua:417-425`

The browse path:
1. Calls `opencode_mod.select_session()`
2. `select_session()` → `require("opencode.ui.select_session").select_session()`
3. `select_session()` → `require("opencode.server").get()`
4. `Server.get()` → `find()` → `Server.new(3000)` or `start()` + `poll()`
5. Once server found, `get_sessions()` → `Promise.select()` shows picker
6. On selection, `server:select_session(result.session.id)`

This chain is correct. The Promise-based approach properly handles cold starts via `start()` + `poll()`.

### 5. Upstream Fire-and-Forget select_session (LOW)

**File**: `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua:266-268`

`Server:select_session()` is fire-and-forget:
```lua
function Server:select_session(session_id)
  return self:curl("/tui/select-session", "POST", { sessionID = session_id }, nil)
end
```

No Promise is returned. If the TUI ignores the request during initialization, there's no error propagated. This is an upstream limitation, not something we can fix in our config.

### 6. Empty Sessions Edge Case (LOW)

If `get_sessions()` returns an empty array, `Promise.select()` (which wraps `vim.ui.select`) may show an empty or confusing picker. This is an edge case for new opencode installations with no prior sessions.

## Decisions

1. **The task 575 fix for the duplicate terminal race is correct and should be preserved.** Do not revert the conditional `toggle()` or the idempotent `start()`.
2. **The primary fix for task 576 is correcting the session ID extraction in the event autocmd.** This will restore "Restore last session" functionality.
3. **We should also add stale-server mitigation** by explicitly disconnecting before `Server.get()` calls in our picker code.
4. **Event property names are inferred** from plugin API conventions (`sessionID`, `id`, `session_id`). We should try multiple candidates for robustness.
5. **If `session.idle` events do not contain a session ID at all**, we need a fallback strategy: poll `get_sessions()` on server connection to discover and save the active session.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `session.idle` properties don't contain session ID | High | Try multiple property paths; add fallback to `get_sessions()` polling |
| Stale `connected_server` causes browse/restore to fail | Medium | Disconnect stale server before calling `Server.get()` |
| `select_session()` fire-and-forget fails silently | Low | Add `vim.defer_fn` verification or accept upstream limitation |
| Empty sessions array confuses picker | Low | Handle empty sessions gracefully (show message or open new session) |
| Changing event callback breaks other listeners | Low | Only change the specific `session.idle` callback in our module |

## Recommendations

### Immediate Fix (for task 576)

#### 1. Fix session ID extraction in `ai-tool-picker.lua`

Update the `OpencodeEvent:session.idle` autocmd callback:

```lua
callback = function(event)
  local session_id = nil
  local data = event.data
  if type(data) == "table" and type(data.event) == "table" then
    local props = data.event.properties
    if type(props) == "table" then
      session_id = props.sessionID
        or props.sessionId
        or props.id
        or props.session_id
        or (props.session and props.session.id)
    end
  end
  if session_id then
    ensure_data_dir()
    atomic_write(opencode_session_file, {
      session_id = session_id,
      timestamp = os.time(),
    })
  end
end,
```

#### 2. Add stale server disconnect before session operations

Before calling `server_mod.get()` or `opencode_mod.select_session()`, explicitly disconnect any stale server:

```lua
-- In the restore path:
require("opencode.events").disconnect()
server_mod.get()...

-- In the browse path:
require("opencode.events").disconnect()
opencode_mod.select_session()...
```

This ensures `Server.get()` performs fresh discovery instead of returning a cached dead server.

#### 3. Save session ID on explicit user selection

In the browse path, after `opencode_mod.select_session()` resolves, the session ID is selected by the user. We can hook into this by wrapping the call:

```lua
-- After opencode_mod.select_session() resolves, save the selected session
-- (Requires upstream plugin to expose the selection, or we can add our own wrapper)
```

However, since `opencode.select_session()` doesn't expose the result, the event-based tracking (once fixed) is the primary mechanism.

#### 4. Fallback when no last session exists

In the restore path, if `last_session_id` is nil, offer to browse sessions instead of just showing a warning:

```lua
if last_session_id then
  -- restore path
else
  vim.notify("No previous session found — opening session browser", vim.log.levels.INFO)
  require("opencode.events").disconnect()
  opencode_mod.select_session()
end
```

### Verification Steps

1. Open opencode, create/activate a session, wait for idle
2. Check that `~/.local/share/nvim/neotex-ai/opencode-last-session.json` is created with a valid `session_id`
3. Close opencode terminal completely
4. Open the AI picker (<C-CR>), select OpenCode, choose "Restore last session"
5. Verify exactly one terminal opens and the session is restored
6. Close opencode, repeat with "Browse all sessions"
7. Verify session picker appears and session selection works
8. Check `:messages` for errors

## Context Extension Recommendations

- **Topic**: opencode.nvim event data structure
- **Gap**: The exact structure of `OpencodeEvent:*` event properties is not documented in `.opencode/context/`
- **Recommendation**: Add a context file documenting the event wrapper structure (`event.data = { event = { type, properties }, port = N }`) and common property paths for different event types

## Appendix: File Reference Map

| File | Lines | Role |
|------|-------|------|
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | 510-530 | Broken session tracking autocmd |
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | 391-426 | Restore/browse paths (correct after 575) |
| `lua/neotex/plugins/ai/opencode.lua` | 38, 49-64 | Config with explicit port and idempotent start |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/events.lua` | 24-63 | Event dispatch and connected_server cache |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` | 348-454 | Server.get(), find(), poll() logic |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` | 14-46 | Browse sessions picker implementation |
| `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` | 86-205 | Terminal creation, dedup, and open() behavior |

## Appendix: Search Queries Used

- `read specs/575_audit_opencode_session_picker_failure/reports/01_session-picker-audit.md` — prior research
- `read specs/575_audit_opencode_session_picker_failure/summaries/01_session-picker-fix-summary.md` — prior implementation
- `git show c06deb576` — verify committed fixes
- `read lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — current picker code
- `read lua/neotex/plugins/ai/opencode.lua` — current plugin config
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/events.lua` — event dispatch structure
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` — Server API
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` — session picker UI
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` — public API
- `read ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` — terminal lifecycle
- `grep "properties" ~/.local/share/nvim/lazy/opencode.nvim/lua/` — event property usage patterns
- `cat ~/.local/share/nvim/neotex-ai/opencode-last-session.json` — verify session file existence
