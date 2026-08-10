# Implementation Plan: Fix OpenCode Session Picker Timing

- **Task**: 544 — fix_opencode_session_picker
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/544_fix_opencode_session_picker/reports/01_session-picker-timing.md
- **Artifacts**: plans/01_session-picker-timing-fix.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: neovim

## Overview

Replace two unreliable `vim.defer_fn(1000)` timing workarounds in the OpenCode session picker's `show_opencode_session_picker()` function with direct `Server.get()` Promise chains. The opencode.nvim plugin provides `Server.get()` which already polls for server readiness (5 retries at 1-second intervals via pgrep, lsof, and curl validation). The "restore" path additionally has a Promise/sync bug where `server_mod.get()` returns a Promise but is used synchronously. Both defer_fn blocks are in `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` lines 302-318. The "create new session" path requires no changes.

### Research Integration

The research report `01_session-picker-timing.md` identified that: (a) `Server.get()` provides robust polling (5 retries, 1s intervals) superior to a single 1-second delay, (b) the "restore" path treats a Promise as a synchronous server object, failing silently inside pcall, (c) `opencode_mod.select_session()` already calls `Server.get()` internally so the 1-second defer is wasted overhead. The report recommends replacing both defer_fn blocks with direct Promise chains using `Server.get()` for restore and a direct `select_session()` call for browse.

## Goals & Non-Goals

**Goals**:
- Replace `vim.defer_fn(1000)` + synchronous `server_mod.get()` in "Restore last session" path with `Server.get()` Promise chain
- Remove `vim.defer_fn(1000)` wrapper from "Browse all sessions" path
- Add user-facing error notifications via `vim.notify()` replacing silent `pcall`
- Preserve existing `OpencodeEvent:session.idle` autocmd (line 381) unchanged

**Non-Goals**:
- Changes to the opencode.nvim plugin itself
- Changes to "Create new session" behavior
- Changes to terminal detection or tool preference persistence
- Adding new autocmds for `OpencodeEvent:server.connected`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `Server.get()` polling takes longer than expected under heavy system load, causing perceived delay | Low | Low | 5-second max poll matches current behavior; the old 1-second defer was insufficient anyway |
| `toggle()` followed immediately by `Server.get()` has a race where the pgrep hasn't discovered the process yet | Medium | Low | `Server.get()` calls `poll()` after `find()` failure, retrying every 1 second — this is the standard plugin behavior for cold starts |
| Promise rejection without a clear error message confuses the user | Low | Low | `.catch()` handler provides explicit error notification with `vim.notify()` |
| Browser session picker shows "no sessions" because server isn't ready when `select_session()` calls `Server.get()` | Low | Low | `select_session()` internally uses `Server.get()` which handles the cold-start case via polling |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix "Restore last session" with Server.get() Promise chain [COMPLETED]

**Goal**: Replace the `vim.defer_fn(1000)` block in the "restore" choice branch (lines 302-313) with a direct `Server.get()` Promise chain that properly resolves the server before calling `select_session()`.

**Tasks**:
- [ ] **Task 1.1**: Replace `vim.defer_fn(1000)` + sync `server_mod.get()` with `server_mod.get():next(function(server) server:select_session(last_session_id) end):catch(function(err) vim.notify(...) end)`
- [ ] **Task 1.2**: Keep the existing `last_session_id` nil-guard and `vim.notify("No previous...")` fallback unchanged

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — lines 302-313, replace the restore branch block

**Verification**:
- Start with no OpenCode server running
- Open the session picker, select "Restore last session"
- Verify the terminal opens and the session picker appears (either restoring a known session or showing the session list)
- Simulate server startup failure: verify error notification appears instead of silent failure
- Verify that choosing "Restore" when `last_session_id` is nil shows the WARN notification

---

### Phase 2: Remove defer_fn from "Browse all sessions" [COMPLETED]

**Goal**: Remove the unnecessary `vim.defer_fn(1000, ...)` wrapper from the "browse" choice branch (lines 314-318) and call `opencode_mod.select_session()` directly, since it internally polls via `Server.get()`.

**Tasks**:
- [ ] **Task 2.1**: Replace `vim.defer_fn(function() pcall(opencode_mod.select_session) end, 1000)` with a direct `opencode_mod.select_session()` call
- [ ] **Task 2.2**: The `select_session()` function already has its own `.catch()` for error notification, so no additional error handling is needed at this call site

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — lines 314-318, replace the browse branch block

**Verification**:
- Open the session picker, select "Browse all sessions"
- Verify the terminal opens and the session browser picker appears
- Verify that browsing sessions works within 5 seconds of cold server start (the internal polling window)
- Verify that selecting a session from the browser correctly switches to it

## Testing & Validation

- [ ] **Restore path — cold start**: Open session picker, select "Restore last session" with no server running; verify terminal opens and session restores (or picker appears) within 5 seconds
- [ ] **Restore path — server already running**: With an active OpenCode session, open the picker and select "Restore last session"; verify immediate session switch
- [ ] **Restore path — no saved session**: Clear `opencode-last-session.json`, open picker, select "Restore"; verify WARN notification appears
- [ ] **Restore path — server startup failure**: Kill any opencode process, block the port, open picker, select "Restore"; verify ERROR notification appears (not silent failure)
- [ ] **Browse path — cold start**: Open session picker, select "Browse all sessions"; verify session browser appears within 5 seconds
- [ ] **Browse path — server already running**: With an active session, select "Browse all sessions"; verify session browser appears immediately
- [ ] **New session path**: Open picker, select "Create new session"; verify it still works (terminal opens, no errors)
- [ ] **Session tracking**: Open a session, wait for idle event, check `opencode-last-session.json` was updated by the existing autocmd

## Artifacts & Outputs

- `specs/544_fix_opencode_session_picker/plans/01_session-picker-timing-fix.md` — this plan
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` — modified (lines 302-318)

## Rollback/Contingency

If the `Server.get()` Promise chain causes issues: revert to the original `vim.defer_fn(1000)` blocks. The original code is contained within a single `attach_mappings` callback and can be restored atomically from `git diff` or from the prior commit.

If `Server.get()` polling is insufficient for slow systems: increase the polling retry count in the plugin's `poll()` function (server/init.lua:394-425) or fall back to the hybrid `OpencodeEvent:server.connected` autocmd approach documented in the research report appendix.
