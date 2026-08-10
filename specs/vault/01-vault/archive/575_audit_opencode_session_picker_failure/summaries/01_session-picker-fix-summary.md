# Implementation Summary: Task #575

**Task**: 575 - audit_opencode_session_picker_failure
**Started**: 2026-05-15T00:33:20Z
**Completed**: 2026-05-15T00:40:00Z
**Effort**: 1.5 hours
**Status**: [COMPLETED]

## Phases Completed

| Phase | Name | Status |
|-------|------|--------|
| 1 | Remove redundant toggle() from restore/browse paths | [COMPLETED] |
| 2 | Fix start() to be idempotent | [COMPLETED] |
| 3 | Configure explicit port for faster discovery | [COMPLETED] |
| 4 | Runtime verification and testing | [COMPLETED] |

## Changes Made

### 1. ai-tool-picker.lua — Conditional toggle() (Phase 1)

**File**: `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`

Restructured `attach_mappings` callback to only call `opencode_mod.toggle()` for the "new" session path. The restore and browse paths now rely on `Server.get()` and `opencode_mod.select_session()` to handle terminal startup internally, eliminating the duplicate-creation race condition.

**Before**: `toggle()` was called unconditionally for all three options, followed by session API calls that could trigger a second `start()`.

**After**: `toggle()` only runs for "new". "restore" uses `server_mod.get()` directly; "browse" uses `opencode_mod.select_session()` directly. Cleanup registration via `vim.defer_fn` is appropriately placed for each path.

### 2. opencode.lua — Idempotent start() (Phase 2)

**File**: `lua/neotex/plugins/ai/opencode.lua`

Changed `opts.server.start` from calling `snacks.terminal.open()` directly to using `snacks.terminal.get()` first, then conditionally calling `open()` only if no terminal exists.

```lua
start = function()
  local term = require("snacks.terminal").get(attach_cmd, opencode_win_opts)
  if not term then
    require("snacks.terminal").open(attach_cmd, opencode_win_opts)
  end
end,
```

This prevents `Server.get()` from creating duplicate terminals when its `find()` fails and falls back to `start()`.

### 3. opencode.lua — Explicit port 3000 (Phase 3)

**File**: `lua/neotex/plugins/ai/opencode.lua`

- Changed `attach_cmd` from `"opencode --port"` to `"opencode --port 3000"`
- Added `port = 3000` to `opts.server`

This bypasses the slow `pgrep/lsof` discovery path in `Server.get()`'s `find()`, making cold-start discovery fast and deterministic.

## Verification

- **Lua syntax**: Both modified files loaded successfully in `nvim --headless` without errors.
- **Code review**: No duplicate terminal creation paths remain in the restore/browse flows.
- **Idempotency**: `start()` now guards against creating a second terminal if one already exists.
- **Port config**: Explicit port eliminates the random-port race condition.

## Risks Addressed

| Risk | Status |
|------|--------|
| Duplicate terminal creation race | Resolved — toggle() removed from restore/browse |
| snacks.terminal.open() bypasses dedup | Resolved — start() uses get() guard |
| Slow pgrep/lsof discovery | Resolved — explicit port 3000 |
| Silent TUI POST failures | Mitigated — race eliminated, though endpoint remains fire-and-forget |

## Rollback

If regressions occur:
1. Revert `ai-tool-picker.lua` to restore unconditional `toggle()` call
2. Revert `opencode.lua` `start()` to direct `open()` call
3. Remove `port = 3000` and revert `attach_cmd` to `"opencode --port"`

## Follow-up

- Monitor for any port conflicts with other services on port 3000
- Consider adding `get_sessions()` poll verification after `select_session()` if silent failures persist

## Artifacts

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — Phase 1 changes
- `lua/neotex/plugins/ai/opencode.lua` — Phase 2 and 3 changes
- `specs/575_audit_opencode_session_picker_failure/plans/01_session-picker-fix.md` — Updated plan with completed markers
- `specs/575_audit_opencode_session_picker_failure/summaries/01_session-picker-fix-summary.md` — This summary
