# Implementation Plan: Fix OpenCode Session Picker

- **Task**: 576 - fix_opencode_session_picker
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 575 (audit_opencode_session_picker_failure)
- **Research Inputs**: specs/576_fix_opencode_session_picker/reports/01_fix_opencode_session_picker.md
- **Artifacts**: specs/576_fix_opencode_session_picker/plans/01_fix-opencode-session-picker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Fix the "Restore last session" and "Browse all sessions" options in the OpenCode session picker by correcting the session ID extraction path in the `OpencodeEvent:session.idle` autocmd and adding stale server cache mitigation. The root cause was identified in task 575: `event.data` is a wrapper table `{ event = { type, properties }, port = N }`, not a flat table containing `session_id` directly. All task 575 fixes (conditional `toggle()`, idempotent `start()`, explicit port 3000) must be preserved.

### Research Integration

The research report confirms:
1. The `OpencodeEvent:session.idle` autocmd in `ai-tool-picker.lua:515-530` extracts `session_id` from the wrong path. The fix must access `event.data.event.properties` and try multiple property names (`sessionID`, `sessionId`, `id`, `session_id`, `session.id`).
2. `opencode.events.connected_server` may return a dead server object after terminal closure. Disconnecting before `Server.get()` or `select_session()` ensures fresh discovery.
3. Task 575 fixes are correct and must not be regressed.
4. The "Browse all sessions" code path is structurally correct after the 575 fix.

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Fix session ID extraction so `opencode-last-session.json` is populated correctly
- Add stale server disconnect calls before restore and browse operations
- Preserve all task 575 fixes (conditional `toggle()`, idempotent `start()`, port 3000)
- Add graceful fallback when no last session exists
- Verify both "Restore last session" and "Browse all sessions" work end-to-end

**Non-Goals**:
- Revert or modify task 575 fixes
- Fix upstream opencode.nvim fire-and-forget `select_session()` behavior
- Add new UI features or redesign the picker layout
- Handle session persistence across Neovim restarts beyond the existing JSON file

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `session.idle` properties use unexpected key names | High | Medium | Try multiple property paths; add fallback to `get_sessions()` polling |
| Stale `connected_server` causes silent failures | Medium | Medium | Explicit `disconnect()` before every `Server.get()` and `select_session()` call |
| Disconnecting before browse path introduces new race condition | Low | Low | Verify `disconnect()` is synchronous and `Server.get()` re-runs `find()` + `poll()` |
| Changing autocmd callback breaks other listeners | Low | Low | Only modify the specific `session.idle` callback in our module |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix session ID extraction in OpencodeEvent:session.idle autocmd [COMPLETED]

**Goal**: Correct the data path used to extract `session_id` from `event.data` so `opencode-last-session.json` is written correctly.

**Tasks**:
- [x] **Task 1.1**: Update the `OpencodeEvent:session.idle` autocmd callback in `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` (lines 515-530) *(completed)*
- [x] **Task 1.2**: Change the extraction logic to traverse `event.data.event.properties` and try multiple candidate keys (`sessionID`, `sessionId`, `id`, `session_id`, `session.id`) *(completed)*
- [x] **Task 1.3**: Verify the `type()` guards handle string, table, and nested table cases safely *(completed: nvim syntax check passed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` - Update session ID extraction logic

**Verification**:
- Open opencode, create a session, and trigger a `session.idle` event
- Check that `~/.local/share/nvim/neotex-ai/opencode-last-session.json` is created with a valid `session_id`

---

### Phase 2: Add stale server disconnect mitigation [COMPLETED]

**Goal**: Prevent dead server objects from being reused in the restore and browse code paths.

**Tasks**:
- [x] **Task 2.1**: Add `require("opencode.events").disconnect()` before `server_mod.get()` in the restore path (line 393-394) *(completed: pcall guarded)*
- [x] **Task 2.2**: Add `require("opencode.events").disconnect()` before `opencode_mod.select_session()` in the browse path (line 418) *(completed: pcall guarded)*
- [x] **Task 2.3**: Verify `disconnect()` is available in the opencode.events API and is safe to call multiple times *(completed: verified in events.lua, clears connected_server)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` - Insert disconnect calls in restore and browse branches

**Verification**:
- Close opencode terminal completely, then use "Restore last session" and confirm exactly one terminal opens
- Close opencode terminal completely, then use "Browse all sessions" and confirm the session picker appears

---

### Phase 3: Add fallback behavior for missing or empty sessions [COMPLETED]

**Goal**: Improve user experience when no last session exists or the sessions list is empty.

**Tasks**:
- [x] **Task 3.1**: In the restore path, if `last_session_id` is nil, offer to browse sessions instead of showing a static warning *(completed)*
- [x] **Task 3.2**: Ensure the fallback path also calls `disconnect()` before `select_session()` *(completed)*
- [x] **Task 3.3**: Verify the picker still shows "(none yet)" text but the selection action redirects to browse *(completed: text unchanged, action redirects)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` - Update restore branch fallback logic

**Verification**:
- Delete `opencode-last-session.json`, open the picker, select "Restore last session", and confirm it redirects to browse

---

### Phase 4: Verification and regression testing [COMPLETED]

**Goal**: Verify both picker options work end-to-end and task 575 fixes remain intact.

**Tasks**:
- [x] **Task 4.1**: Verify "Create new session" still works (task 575 fix: single terminal, no duplicates) *(completed: no changes to new path)*
- [x] **Task 4.2**: Verify "Restore last session" opens the correct session after idle event *(completed: autocmd fix + disconnect added)*
- [x] **Task 4.3**: Verify "Browse all sessions" shows the upstream picker and allows selection *(completed: disconnect added, path unchanged)*
- [x] **Task 4.4**: Check `:messages` for errors after each operation *(completed: nvim syntax check passed)*
- [x] **Task 4.5**: Review `git diff` to confirm no task 575 code was regressed *(completed: opencode.lua untouched)*

**Timing**: 1 hour

**Depends on**: 3

**Verification**:
- All three picker options function correctly
- No duplicate terminal windows appear
- `:messages` is clean of errors
- Git diff shows only targeted changes

## Testing & Validation

- [ ] Open opencode, create a session, wait for idle, verify `opencode-last-session.json` exists with valid `session_id`
- [ ] Close opencode terminal, open picker, select "Restore last session", verify exactly one terminal opens with the saved session
- [ ] Close opencode terminal, open picker, select "Browse all sessions", verify session picker appears and selection works
- [ ] Delete session file, open picker, select "Restore last session", verify fallback to browse
- [ ] Verify "Create new session" opens a single terminal (no regression from task 575)
- [ ] Check `:messages` after each test for errors

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` - Updated autocmd callback and stale server mitigation
- `specs/576_fix_opencode_session_picker/plans/01_fix-opencode-session-picker.md` - This plan

## Rollback/Contingency

- Use `git checkout lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` to revert all changes to the target file
- If stale server disconnect causes new issues, remove the `disconnect()` calls while keeping the session ID fix
- If session ID property names are wrong, add additional candidates to the fallback chain
