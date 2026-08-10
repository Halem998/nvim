# Implementation Summary: Task #576 — Fix OpenCode Session Picker

**Completed**: 2026-05-14
**Duration**: ~30 minutes
**Task**: fix_opencode_session_picker
**Session**: sess_1778807548_475b52

## Changes Made

### Phase 1: Fix session ID extraction in `OpencodeEvent:session.idle` autocmd
Updated the autocmd callback in `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` to correctly traverse the event data structure. The previous code expected `event.data` to contain `session_id` directly, but `event.data` is actually a wrapper table `{ event = { type, properties }, port = N }`.

The new extraction logic:
1. Checks `event.data.event.properties` for `sessionID`, `sessionId`, `id`, `session_id`, or `session.id`
2. Falls back to the original flat-key behavior for backward compatibility
3. Uses `type()` guards at every nested level for safety

This ensures `opencode-last-session.json` is correctly populated when a `session.idle` event fires, which is required for the "Restore last session" feature to function.

### Phase 2: Add stale server disconnect mitigation
Added `pcall`-guarded `require("opencode.events").disconnect()` calls before server-dependent operations in both the restore and browse paths:
- **Restore path**: Disconnect before `server_mod.get()` to force fresh server discovery
- **Browse path**: Disconnect before `opencode_mod.select_session()` to prevent stale cached server objects from causing silent failures

This addresses the risk that `opencode.events.connected_server` caches a dead server object after the terminal is closed.

### Phase 3: Add fallback behavior for missing last session
Changed the restore-path `else` branch (when `last_session_id` is nil) from showing a static warning to redirecting the user to the session browser. The picker still displays "Restore last session (none yet)", but selecting it now opens the browse picker instead of doing nothing.

### Phase 4: Verification and regression testing
- Ran `nvim --headless` syntax validation — passed with no errors
- Reviewed `git diff` to confirm only targeted changes were made
- Verified `lua/neotex/plugins/ai/opencode.lua` is untouched — all task 575 fixes (conditional `toggle()`, idempotent `start()`, port 3000) remain intact
- The "Create new session" code path is completely unchanged

## Files Modified

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`
  - Lines 515–545: Fixed session ID extraction in `OpencodeEvent:session.idle` autocmd
  - Lines 392–396: Added stale-server disconnect in restore path
  - Lines 418–431: Added fallback to browse when no last session exists (also includes disconnect)
  - Lines 433–436: Added stale-server disconnect in browse path

## Verification

- **Build/Syntax**: `nvim --headless -c "luafile ..."` passed with no Lua errors
- **Regression check**: `git diff` shows only the intended changes; `opencode.lua` is untouched
- **Task 575 preservation**: Confirmed — no changes to conditional `toggle()`, idempotent `start()`, or port 3000 configuration

## Notes

- All `disconnect()` calls are wrapped in `pcall(require, "opencode.events")` with existence checks, so they are safe even if the upstream API changes
- The fallback browse path reuses the same cleanup defer pattern as the normal browse path, ensuring `_register_tool_cleanup` is still called
- No upstream plugin changes are required; this is purely a configuration fix
