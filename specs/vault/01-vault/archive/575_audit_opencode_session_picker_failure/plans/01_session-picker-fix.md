# Implementation Plan: OpenCode Session Picker Fix

- **Task**: 575 - audit_opencode_session_picker_failure
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 544 (archived)
- **Research Inputs**: specs/575_audit_opencode_session_picker_failure/reports/01_session-picker-audit.md
- **Artifacts**: plans/01_session-picker-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Fix the duplicate terminal creation race condition causing OpenCode session picker restore and browse options to fail. The root cause is a redundant `toggle()` call before session API invocations combined with `snacks.terminal.open()` bypassing dedup in the `start()` callback. The plan removes the redundant toggle, makes `start()` idempotent via `snacks.terminal.get()` guard, and optionally configures an explicit port to eliminate slow `pgrep/lsof` discovery.

### Research Integration

The research report (`01_session-picker-audit.md`) identified three critical failure modes:
1. **Duplicate terminal creation race**: `toggle()` opens terminal T1, then `Server.get()` fails discovery (process not ready), triggering `start()` which calls `snacks.terminal.open()` directly -- creating T2. Both processes are discovered, causing `find()` to show a server-selection picker instead of restoring/browsing sessions.
2. **`snacks.terminal.open()` bypasses dedup**: `open()` always creates a new terminal and overwrites `terminals[tid]`, unlike `get()` which checks for existing terminals.
3. **Random port assignment**: `opencode --port` with no port number forces slow `pgrep/lsof` discovery on every `Server.get()` call.

### Prior Plan Reference

No prior plan exists. Task 544 attempted a fix using Promise-based `Server.get()` chains, which was correct in replacing `vim.defer_fn(1000)` timing workarounds, but inadvertently introduced the duplicate-creation race by retaining the `toggle()` call before session APIs.

### Roadmap Alignment

No ROADMAP.md items directly reference OpenCode session picker reliability. This fix improves the Neovim extension user experience and prevents task spawn blockers caused by broken AI tool workflows.

## Goals & Non-Goals

**Goals**:
- Eliminate duplicate terminal creation on restore/browse cold starts
- Make `opts.server.start()` idempotent so `Server.get()` can safely call it
- Optionally configure explicit port for faster, race-free server discovery
- Verify restore and browse paths work correctly from a cold start

**Non-Goals**:
- Fixing the opencode.nvim plugin itself (upstream code in `~/.local/share/nvim/lazy/`)
- Changing the "Create new session" path (it works correctly)
- Adding Promise-based feedback to `Server:select_session()` (upstream fire-and-forget endpoint)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing `toggle()` changes perceived UX (terminal may appear slightly later) | Low | Medium | `Server.get()` calls `start()` which opens the terminal; user still sees it appear after polling completes |
| `snacks.terminal.get()` with `create = false` may return nil for a valid but untracked terminal | Low | Low | Use `get(..., {create = false})` then `open()` only if nil; old terminals remain visible and functional |
| Explicit port conflicts with another service | Low | Low | Use high port (e.g., 3000) and document; user can change if needed |
| `Server:select_session()` still silently fails if TUI ignores POST during init | Medium | Medium | Mitigated by fixing the race; if still occurs, add `get_sessions()` poll verification as follow-up |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove redundant toggle() from restore/browse paths [COMPLETED]

**Goal**: Eliminate the duplicate-creation race by removing `opencode_mod.toggle()` from restore and browse code paths.

**Tasks**:
- [ ] **Task 1.1**: Read `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` around lines 378-414 to confirm current structure
- [ ] **Task 1.2**: Modify the `attach_mappings` callback so `opencode_mod.toggle()` is only called for "new" sessions, not "restore" or "browse"
- [ ] **Task 1.3**: Move the `vim.defer_fn` terminal registration block to execute only after toggle (for "new" path) or after server connection (for restore/browse paths)
- [ ] **Task 1.4**: Verify the "new" session path remains unchanged and functional

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` - Restructure attach_mappings to conditionally call toggle

**Verification**:
- Diff shows toggle() only inside the "new" branch or at the top before branching
- Restore/browse paths no longer call toggle() before session APIs

---

### Phase 2: Fix start() to be idempotent [COMPLETED]

**Goal**: Prevent `Server.get()` from creating duplicate terminals when it calls `start()` after failed discovery.

**Tasks**:
- [ ] **Task 2.1**: Read `lua/neotex/plugins/ai/opencode.lua` lines 49-60 to confirm current `opts.server` functions
- [ ] **Task 2.2**: Replace `start()` implementation to check for existing terminal before opening:
  ```lua
  start = function()
    local term = require("snacks.terminal").get(attach_cmd, opencode_win_opts)
    if not term then
      require("snacks.terminal").open(attach_cmd, opencode_win_opts)
    end
  end,
  ```
- [ ] **Task 2.3**: Verify `stop()` and `toggle()` implementations remain correct

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/opencode.lua` - Update `opts.server.start()` to guard against duplicate creation

**Verification**:
- `start()` calls `snacks.terminal.get()` first, then conditionally `open()`
- No direct `open()` call without existence check

---

### Phase 3: Configure explicit port for faster discovery [COMPLETED]

**Goal**: Bypass slow `pgrep/lsof` process discovery by assigning a fixed port to the opencode server.

**Tasks**:
- [ ] **Task 3.1**: Choose an explicit port (e.g., 3000) that is unlikely to conflict
- [ ] **Task 3.2**: Update `attach_cmd` from `"opencode --port"` to `"opencode --port 3000"`
- [ ] **Task 3.3**: Set `opts.server.port = 3000` so `Server.get()`'s `find()` uses the fast `Server.new(port)` path
- [ ] **Task 3.4**: Verify `discord-link.lua` dynamic port discovery still works (it uses `ss`/`lsof` which will find the fixed port correctly)

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/ai/opencode.lua` - Update attach_cmd and add port config

**Verification**:
- `attach_cmd` includes explicit port number
- `opts.server.port` is set to matching value

---

### Phase 4: Runtime verification and testing [COMPLETED]

**Goal**: Confirm all three session picker options work correctly from cold and warm starts.

**Tasks**:
- [ ] **Task 4.1**: Cold start test: close all opencode terminals, kill all opencode processes (`pkill -f opencode`), select "Restore" -- verify exactly ONE terminal opens and session restores (or picker appears if no saved session)
- [ ] **Task 4.2**: Cold start test: select "Browse" -- verify exactly ONE terminal opens and session browser picker appears
- [ ] **Task 4.3**: Warm start test: with opencode already running, select "Restore" -- verify no duplicate terminal is created
- [ ] **Task 4.4**: Check `:messages` after each test for errors
- [ ] **Task 4.5**: Shell verification: `pgrep -f "opencode.*--port" | wc -l` returns exactly 1 after each cold-start test
- [ ] **Task 4.6**: Document any remaining issues in a follow-up note

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (manual testing)

**Verification**:
- All three picker options (new, restore, browse) work from cold start
- No duplicate opencode processes observed
- No error messages in `:messages`

## Testing & Validation

- [ ] Cold start "Restore" opens exactly one terminal and restores session
- [ ] Cold start "Browse" opens exactly one terminal and shows session browser
- [ ] Warm start "Restore" reuses existing terminal without creating duplicates
- [ ] `pgrep` confirms single opencode process after cold-start tests
- [ ] `:messages` shows no errors after picker usage

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` - Updated attach_mappings with conditional toggle()
- `lua/neotex/plugins/ai/opencode.lua` - Updated start() with idempotency guard and explicit port
- `specs/575_audit_opencode_session_picker_failure/plans/01_session-picker-fix.md` - This plan
- `specs/575_audit_opencode_session_picker_failure/summaries/` - Implementation summary (to be created by implementer)

## Rollback/Contingency

If the fix introduces regressions:
1. Revert `ai-tool-picker.lua` to restore the `toggle()` call before all branches (reintroduces the race but restores prior behavior)
2. Revert `opencode.lua` `start()` to direct `snacks.terminal.open()` call
3. Remove explicit port config to restore random port assignment
4. The original task 544 Promise-based chains remain intact and should still work for warm starts
