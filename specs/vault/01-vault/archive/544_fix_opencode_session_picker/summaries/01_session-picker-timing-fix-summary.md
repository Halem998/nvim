# Implementation Summary: Fix OpenCode Session Picker Timing

- **Task**: 544 — fix_opencode_session_picker
- **Status**: [COMPLETED]
- **Effort**: 2 hours (estimated)
- **Started**: 2026-05-08T00:58:00Z
- **Completed**: 2026-05-08T01:00:00Z
- **Plan**: specs/544_fix_opencode_session_picker/plans/01_session-picker-timing-fix.md
- **Research**: specs/544_fix_opencode_session_picker/reports/01_session-picker-timing.md
- **Artifacts**: summaries/01_session-picker-timing-fix-summary.md (this file)
- **Standards**: summary-format.md

## What Was Implemented

Replaced two `vim.defer_fn(1000)` timing workarounds in the OpenCode session picker's `show_opencode_session_picker()` function in `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (lines 302-323) with proper async patterns.

### Changes Made

**Phase 1 — "Restore last session" (lines 302-317)**:
- Replaced `vim.defer_fn(1000)` + synchronous `server_mod.get()` with `server_mod.get():next(function(server) server:select_session(last_session_id) end):catch(...)` Promise chain
- `Server.get()` properly returns a Promise that resolves with a Server instance — the old code treated the Promise as a Server, silently failing inside `pcall`
- Added `vim.notify()` error handler with descriptive message on failure (replacing silent `pcall`)
- Kept existing nil-guard for `last_session_id` with WARN notification unchanged

**Phase 2 — "Browse all sessions" (lines 321-322)**:
- Removed `vim.defer_fn(function() pcall(opencode_mod.select_session) end, 1000)` wrapper
- Replaced with direct `opencode_mod.select_session()` call — this function internally uses `Server.get()` which has its own 5-retry polling, making the 1-second defer both unnecessary and wasteful

**Unchanged**:
- "Create new session" path (just calls `toggle()`) — already correct
- `OpencodeEvent:session.idle` autocmd (line 381) for last-session tracking — already correct
- Terminal detection, tool preference persistence, all other functionality

## How It Works

1. User selects an option in the session picker
2. `toggle()` opens the OpenCode terminal (starts server process)
3. For **restore**: `Server.get()` polls for server readiness (pgrep → lsof → curl-validate, 5 retries at 1s intervals), then calls `server:select_session(id)` on resolve or shows error notification on reject
4. For **browse**: `select_session()` internally calls `Server.get()`, then shows the session browser picker, then calls `server:select_session(selected_id)` — all async with built-in error handling
5. For **new**: terminal opens with a fresh session, no follow-up needed

## Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| Server starts in <1s | `find()` succeeds immediately |
| Server starts in 2-5s | `poll()` retries, catches it on retry 2-5 |
| Server takes >5s | `poll()` rejects, `.catch()` shows error notification |
| Server already running | `find()` finds connected_server immediately |
| No saved sessions | "none yet" shown in picker, restore shows WARN notification |
| Network error on curl | `Server.new()` rejects, `get_all()` filters out |
| Multiple servers | Plugin shows server selection UI (existing behavior) |

## Files Modified

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — lines 302-323 replaced
