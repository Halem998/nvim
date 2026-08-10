# Research Report: Task #575 — Audit OpenCode Session Picker Failure Modes

**Task**: 575 — audit_opencode_session_picker_failure
**Started**: 2026-05-14T00:00:00Z
**Completed**: 2026-05-14T00:45:00Z
**Effort**: 2-3 hours
**Dependencies**: Task 544 (archived)
**Sources/Inputs**: 
  - `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (current implementation)
  - `lua/neotex/plugins/ai/opencode.lua` (plugin config with snacks.terminal)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` (Server.get(), poll(), find())
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/process/unix.lua` (pgrep/lsof discovery)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` (session picker UI)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` (public API: toggle, select_session)
  - `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/terminal.lua` (plugin's own terminal module)
  - `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` (snacks.terminal implementation)
  - `specs/archive/544_fix_opencode_session_picker/` (prior task artifacts)
**Artifacts**: `specs/575_audit_opencode_session_picker_failure/reports/01_session-picker-audit.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Primary failure mode**: The task 544 fix introduced a **duplicate terminal creation race condition**. On cold start, `toggle()` opens one `opencode --port` terminal, then `Server.get()` fails to discover the process before it opens its HTTP port, triggering `start()` which calls `snacks.terminal.open()` directly — creating a second terminal and a second opencode process. This results in multiple servers being discovered, causing `find()` to show a server-selection picker instead of restoring or browsing sessions.
- **Secondary failure mode**: `opencode --port` uses a random port with no explicit configuration. `Server.get()` must discover the port via `pgrep` → `lsof`, which is slow and race-prone on cold starts.
- **Tertiary failure mode**: The `Server:select_session()` endpoint (`POST /tui/select-session`) is fire-and-forget with no Promise feedback. If the TUI ignores the request during initialization, there is no error propagated to the caller.
- **Recommended approach**: Remove the redundant `toggle()` call before session API invocations; fix `start()` to be idempotent via `snacks.terminal.get(..., {create = false})`; optionally configure an explicit port for faster discovery.

## Context & Scope

### What Was Researched

The OpenCode session picker (triggered via `<C-CR>` → OpenCode → Stage 2 picker) offers three options:
1. **"Create new session"** — Calls `toggle()`, opens terminal. Works.
2. **"Restore last session"** — Calls `toggle()`, then `Server.get()` Promise chain → `server:select_session(last_session_id)`. Reported as failing.
3. **"Browse all sessions"** — Calls `toggle()`, then `opencode_mod.select_session()`. Reported as failing.

Task 544 replaced the original `vim.defer_fn(1000)` timing workarounds with Promise-based `Server.get()` chains. The user reports both options still fail.

### Investigation Scope
- Reconstruct exact code paths from keypress to session API call
- Trace `snacks.terminal` lifecycle (creation, dedup, jobstart)
- Trace `Server.get()` discovery logic (find → get_all → pgrep → lsof → curl-validate)
- Analyze `start()` function behavior and its interaction with `toggle()`
- Examine `opencode.terminal` module vs snacks.terminal integration
- Check for error-swallowing patterns in Promise chains

## Findings

### 1. Duplicate Terminal Creation Race (CRITICAL)

**File**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua:381`
**Code**:
```lua
opencode_mod.toggle()  -- Creates terminal T1, starts opencode process P1
-- ...
server_mod.get()       -- May fail discovery, triggering start() → creates T2/P2
```

**Root cause chain**:
1. `toggle()` → `snacks.terminal.toggle("opencode --port", opts)` → `get()` → `open()` → creates terminal, calls `jobstart("opencode --port")`
2. Immediately after, `server_mod.get()` → `find()` → `Server.get_all()` → `process.get()` → `pgrep -f "opencode.*--port"` then `lsof`
3. The opencode process may not have opened its HTTP port yet; `lsof` returns no ports → `process.get()` returns `{}`
4. `Server.get_all()` rejects with "No `opencode` processes found"
5. `Server.get()` `.catch()` handler calls `start()` → `snacks.terminal.open(attach_cmd, opencode_win_opts)`
6. `snacks.terminal.open()` **bypasses dedup** — it calls `Snacks.win(opts.win)` directly, creates a NEW buffer/window, starts a NEW job, and overwrites `terminals[tid]`
7. Result: **two opencode processes** running, with only the most recently created terminal tracked by snacks

**Impact on restore/browse**:
- When `poll()` eventually retries `find()` → `get_all()`, `pgrep` discovers **both PIDs**
- `lsof` finds **both ports**
- `Server.get_all()` validates both via `Server.new(port)` (curl to `/path`)
- `find()` filters by CWD overlap — both servers share CWD
- `#servers_sharing_cwd == 2` → `find()` calls `require("opencode.ui.select_server").select_server(...)`
- **User sees a "select server" picker instead of the expected session restore/browser**

This is an intermittent failure — it works when opencode starts fast enough for `pgrep/lsof` to succeed on the first `find()` attempt, and fails when it doesn't.

### 2. No Explicit Port Configuration (HIGH)

**File**: `lua/neotex/plugins/ai/opencode.lua:38`
**Code**:
```lua
local attach_cmd = "opencode --port"
```

The `--port` flag is present but **no port number is specified**, so opencode assigns a random port. The `opts.server.port` config option is **not set**.

**Impact**:
- `Server.get()`'s `find()` skips the fast path (`connected_server` → `port_opt`) and falls through to the slow `Server.get_all()` path
- `get_all()` must run `pgrep -f "opencode.*--port"` → `lsof -Fpn -w -iTCP -sTCP:LISTEN` for every invocation
- This adds ~100-500ms to discovery and is inherently race-prone on cold starts
- With an explicit port (e.g., `opencode --port 3000` + `opts.server.port = 3000`), `find()` would call `Server.new(3000)` directly, skipping process discovery entirely

### 3. Redundant `toggle()` Before Session APIs (HIGH)

**File**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua:381, 391, 411`

Both restore and browse paths call `opencode_mod.toggle()` before invoking session APIs. But:
- `opencode_mod.select_session()` internally calls `Server.get()`, which calls `start()` if no server exists
- `server_mod.get()` also calls `start()` if no server exists

**Impact**:
- The `toggle()` call is **redundant** for restore/browse — the session APIs will start the server themselves if needed
- More importantly, `toggle()` + `Server.get()` creates the double-startup race described in Finding 1
- Removing `toggle()` from restore/browse paths and letting `Server.get()` handle startup would eliminate the duplicate creation

### 4. `Server:select_session()` Is Fire-and-Forget (MEDIUM)

**File**: `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua:266-268`
**Code**:
```lua
function Server:select_session(session_id)
  return self:curl("/tui/select-session", "POST", { sessionID = session_id }, nil)
end
```

This returns a `job_id` from `curl()` but **not a Promise**. The caller (`ai-tool-picker.lua`) cannot await success or failure.

**Impact**:
- If the TUI is still initializing when `select_session()` is called, the POST may be accepted but ignored
- No error is propagated back to `ai-tool-picker.lua`
- The user sees the terminal open but the session doesn't change, with no visible error
- The default `on_error` handler in `curl()` would `vim.notify` an error, but this is asynchronous and may not be seen

### 5. `opencode.terminal` Module Not Used (LOW)

**File**: `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/terminal.lua`

The opencode.nvim plugin provides its own `terminal.lua` with `toggle()`/`open()` that manage a single `winid`/`bufnr`. However, the config in `opencode.lua` overrides `opts.server` to use `snacks.terminal` instead.

**Impact**:
- The plugin's `Server.get()` → `start()` path was likely designed assuming `opencode.terminal` (which uses module-level singleton state)
- With `snacks.terminal`, multiple terminals can coexist, and `open()` bypasses dedup
- This architectural mismatch contributes to the duplicate creation issue

### 6. `snacks.terminal` Dedup Bypassed by `open()` (HIGH)

**File**: `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua:88-171`

`snacks.terminal.get()` has dedup logic:
```lua
function M.get(cmd, opts)
  local id = M.tid(cmd, opts)
  if not (terminals[id] and terminals[id]:buf_valid()) and (opts.create ~= false) then
    local ret = M.open(cmd, opts)
    -- ...
  end
  return terminals[id], created
end
```

But `M.open()` has **no dedup** — it always creates a new terminal:
```lua
function M.open(cmd, opts)
  local terminal = Snacks.win(opts.win)
  local tid = M.tid(cmd, opts)
  terminals[tid] = terminal  -- Overwrites any existing entry!
  -- ...starts new job...
end
```

**Impact**:
- The config's `start()` function calls `snacks.terminal.open()` directly
- This bypasses `get()`'s dedup check
- Combined with `Server.get()` calling `start()` on failure, this guarantees duplicate creation on cold-start races

### 7. Error Handling Is Correct but Asynchronous (LOW)

**File**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua:394-406, 411`

The restore path has a `.catch()` handler that `vim.notify()` on error. The browse path delegates to `opencode_mod.select_session()` which has its own `.catch()`. Errors are NOT silently swallowed.

**Impact**:
- If `Server.get()` times out after 5 seconds, the user sees: "Failed to restore session: ..."
- If `select_session()` fails, the user sees an error notification from opencode.nvim
- The real problem is not error swallowing, but **wrong behavior without errors** (duplicate servers causing unexpected picker)

## Decisions

1. **The 544 fix was correct in replacing `vim.defer_fn(1000)` with Promise chains, but it introduced a new race condition by keeping the `toggle()` call before session APIs.** The `toggle()` + `Server.get()` combination is the actual root cause.
2. **`Server.get()` is not the wrong API to use** — it provides robust polling. The problem is calling it after `toggle()` has already started a server, which causes `Server.get()` to fail discovery (process not ready yet) and then call `start()` again.
3. **`snacks.terminal.open()` must not be called directly for server-starting functions** — it must go through `snacks.terminal.get()` with dedup, or be guarded by an existence check.
4. **Configuring an explicit port would significantly improve reliability** by bypassing `pgrep/lsof` discovery entirely.
5. **`/tui/select-session` endpoint behavior cannot be fully verified from the Neovim side** — it requires runtime testing with an actual opencode TUI. However, the endpoint is used internally by the plugin and assumed functional.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Removing `toggle()` changes user experience (terminal may not appear immediately) | Low | `Server.get()` calls `start()` which opens the terminal; user still sees it appear |
| Fixing `start()` to check dedup may leave stale terminals untracked | Low | `snacks.terminal.get()` with `create = false` followed by `open()` only if nil ensures no duplicates; old terminals remain visible but tracked |
| Explicit port may conflict with other services | Low | Use a high port (e.g., 3000) or derive from CWD hash; document in config |
| `Server:select_session()` still fails silently if TUI ignores POST | Medium | Add a verification step: after `select_session()`, poll `server:get_sessions()` to confirm the active session changed |
| Changing port requires updating discord-link.lua port discovery | Medium | `discord-link.lua` already discovers port dynamically via `ss`/`lsof`; explicit port would make it faster |

## Recommendations

### Immediate Fix (for task 576)

1. **Remove `toggle()` from restore/browse paths** in `ai-tool-picker.lua`:
   - "Restore": Just call `server_mod.get():next(...)` directly. `Server.get()` will call `start()` if needed.
   - "Browse": Just call `opencode_mod.select_session()` directly. It already calls `Server.get()` internally.
   - "New": Keep `toggle()` — this path doesn't need session APIs.

2. **Fix `start()` to be idempotent** in `opencode.lua`:
   ```lua
   start = function()
     local term = require("snacks.terminal").get(attach_cmd, opencode_win_opts)
     if not term then
       require("snacks.terminal").open(attach_cmd, opencode_win_opts)
     end
   end,
   ```
   Or simply use `snacks.terminal.toggle()` in `start()`:
   ```lua
   start = function()
     require("snacks.terminal").toggle(attach_cmd, opencode_win_opts)
   end,
   ```
   `toggle()` calls `get()` which has dedup, so it won't create duplicates.

3. **(Optional) Configure explicit port**:
   ```lua
   local attach_cmd = "opencode --port 3000"
   -- ...
   opts.server.port = 3000
   ```
   This makes `Server.get()`'s `find()` use the fast `Server.new(3000)` path instead of `get_all()`.

### Verification Steps

1. Cold start: close all opencode terminals, kill all opencode processes, select "Restore" — verify ONE terminal opens and session restores (or picker appears if no saved session)
2. Cold start: select "Browse" — verify ONE terminal opens and session browser appears
3. Warm start: with opencode already running, select "Restore" — verifies no duplicate creation
4. Check `:messages` after each test for errors
5. Verify `pgrep -f "opencode.*--port" | wc -l` returns 1 after each cold-start test

## Appendix: File Reference Map

| File | Lines | Role |
|------|-------|------|
| `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` | 381, 391-412 | Session picker attach_mappings with toggle + Server.get() race |
| `lua/neotex/plugins/ai/opencode.lua` | 38, 49-60 | Config: attach_cmd, server.start/stop/toggle using snacks.terminal |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` | 266-268, 303-332, 334-346, 348-390, 392-425, 428-454 | Server API: select_session, get_all, start, find, poll, get |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/process/unix.lua` | 49-70 | pgrep + lsof process discovery |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` | 61-72, 135-142 | Public API: select_session, toggle |
| `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` | 14-46 | Session browser picker implementation |
| `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` | 88-171, 192-205, 218-221 | Terminal creation, dedup in get(), no dedup in open() |

## Appendix: Search Queries Used

- `grep "opencode" specs/575_* specs/archive/544_*` — task context and prior research
- `read lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — current implementation
- `read lua/neotex/plugins/ai/opencode.lua` — plugin configuration
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` — Server API
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/process/unix.lua` — process discovery
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/ui/select_session.lua` — session picker UI
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode.lua` — public API
- `read ~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/terminal.lua` — plugin terminal module
- `read ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/terminal.lua` — snacks.terminal implementation
- `grep "port" lua/neotex/plugins/ai/opencode.lua` — port configuration check
