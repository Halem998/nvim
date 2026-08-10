# Research Report: Task #202

**Task**: 202 - Implement trailing-edge debounce for TTS session.idle notifications
**Started**: 2026-03-13T12:38:00Z
**Completed**: 2026-03-13T12:45:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, opencode event documentation
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

The TTS notification system currently uses a **leading-edge debounce** that fires immediately on `session.idle` and ignores subsequent events for 3 seconds. The requested change is a **trailing-edge debounce** that waits 1.5 seconds after `session.idle` before firing, cancelling if `session.status:busy` fires before the timer expires.

### Key Findings:

1. **Current Implementation**: `wezterm-hooks.js` line 24-34 uses leading-edge debounce (fires first, ignores subsequent)
2. **Target Pattern**: Trailing-edge debounce (waits, fires if no cancellation)
3. **Event System**: OpenCode fires `session.status` events with status type that can indicate "busy"
4. **Implementation Location**: `.opencode/plugins/wezterm-hooks.js` (the JavaScript plugin)
5. **No Status Events Currently Handled**: The plugin only handles `session.idle`, not `session.status`

### Recommended Approach:

Modify `wezterm-hooks.js` to:
1. Use `setTimeout` for 1.5 second trailing delay
2. Store the timer handle to enable cancellation
3. Listen for `session.status` events with busy status to cancel pending timers

---

## Context

### Problem Statement

When sub-agents run during multi-step operations (e.g., `/research` invoking a sub-agent), `session.idle` fires for each sub-agent completion. This causes premature TTS announcements mid-operation:

```
User runs /research 202
  -> Orchestrator delegates to skill-researcher
    -> session.idle fires (sub-agent "idle") -> TTS "Tab 4" [PREMATURE]
  -> skill-researcher returns
  -> Main agent continues
  -> More work...
  -> session.idle fires (actual completion) -> TTS "Tab 4"
```

The current 3-second leading-edge debounce does not solve this because the sub-agent completions can be spaced more than 3 seconds apart.

### Current Implementation Analysis

#### File: `.opencode/plugins/wezterm-hooks.js`

```javascript
// Lines 24-34: Current leading-edge debounce
let lastTtsMs = 0;
const TTS_DEBOUNCE_MS = 3000;

return {
  event: async ({ event }) => {
    if (event.type === "session.idle") {
      const now = Date.now();
      if (now - lastTtsMs < TTS_DEBOUNCE_MS) return;  // Leading edge: skip if too recent
      lastTtsMs = now;                                  // Update timestamp
      // Fire immediately
      await $`bash ${hookDir}/tts-notify.sh`.cwd(directory).quiet().nothrow();
      await $`bash ${hookDir}/wezterm-notify.sh`.cwd(directory).quiet().nothrow();
    }
    // ...
  }
}
```

**Behavior**: Fires on first `session.idle`, ignores any within 3 seconds.

**Problem**: Does not wait to see if more activity follows.

---

## Findings

### 1. OpenCode Event System

From `.opencode/context/openagents-repo/plugins/context/capabilities/events.md`:

| Event | Description | Trigger |
|-------|-------------|---------|
| `session.idle` | Session completed (no more activity expected) | After response completes |
| `session.status` | Session status changed | When session state transitions |
| `session.created` | New session started | On session initialization |
| `session.updated` | Session state changed | On various state changes |

From `OpenAgentsControl/evals/framework/src/sdk/event-stream-handler.ts` (lines 434-445):

```typescript
case 'session.status':
  const statusSessionId = event.properties?.sessionID;
  const status = event.properties?.status;

  if (statusSessionId && this.activeSessions.has(statusSessionId)) {
    if (status?.type === 'idle') {
      // Session went idle
    }
  }
  break;
```

**Key Insight**: `session.status` events include a `status.type` property that can be `"idle"` or (inferred) other values like `"busy"` or `"active"`.

### 2. Trailing-Edge Debounce Pattern

The trailing-edge debounce pattern defers execution until a quiet period:

```javascript
let pendingTimer = null;

function trailingDebounce(fn, delay) {
  return function() {
    clearTimeout(pendingTimer);  // Cancel any pending execution
    pendingTimer = setTimeout(() => {
      pendingTimer = null;
      fn();                      // Execute after quiet period
    }, delay);
  };
}
```

**Properties**:
- First event: Starts timer, does NOT fire
- Subsequent events within delay: Restart timer
- After delay with no events: Fire
- Cancellation: Clear timer on "busy" event

### 3. Session Status Detection

To cancel the pending TTS when session becomes busy:

```javascript
if (event.type === "session.status") {
  const status = event.properties?.status;
  if (status?.type !== "idle") {
    // Session is busy/active, cancel pending TTS
    clearTimeout(pendingTtsTimer);
    pendingTtsTimer = null;
  }
}
```

### 4. Existing Debounce Patterns in Codebase

From `.opencode/extensions/nvim/context/project/neovim/domain/lua-patterns.md` (line 161):

```lua
-- Lua trailing-edge debounce example (for reference)
local function debounce(fn, ms)
  return function(...)
    local args = {...}
    if timer then timer:stop() end
    timer = vim.defer_fn(function()
      fn(unpack(args))
    end, ms)
  end
end
```

**Note**: The JavaScript implementation will follow the same pattern with `setTimeout`/`clearTimeout`.

### 5. Recommended Timer Value

Task description specifies 1.5 seconds (1500ms). This is reasonable because:
- Typical sub-agent transitions take < 1 second
- Long enough to catch rapid successive idle events
- Short enough to not noticeably delay user notification

---

## Implementation Recommendations

### Approach: Modify `wezterm-hooks.js`

#### Changes Required:

1. **Add timer state variable** (module-level):
   ```javascript
   let pendingTtsTimer = null;
   const TTS_TRAILING_DELAY_MS = 1500;
   ```

2. **Handle `session.idle` with trailing debounce**:
   ```javascript
   if (event.type === "session.idle") {
     clearTimeout(pendingTtsTimer);  // Reset timer on each idle
     pendingTtsTimer = setTimeout(async () => {
       pendingTtsTimer = null;
       await $`bash ${hookDir}/tts-notify.sh`.cwd(directory).quiet().nothrow();
       await $`bash ${hookDir}/wezterm-notify.sh`.cwd(directory).quiet().nothrow();
     }, TTS_TRAILING_DELAY_MS);
   }
   ```

3. **Handle `session.status` for cancellation**:
   ```javascript
   else if (event.type === "session.status") {
     const status = event.properties?.status;
     if (status?.type !== "idle" && pendingTtsTimer) {
       clearTimeout(pendingTtsTimer);
       pendingTtsTimer = null;
     }
   }
   ```

4. **Remove old leading-edge debounce logic**:
   - Delete `lastTtsMs` variable
   - Delete `TTS_DEBOUNCE_MS` constant
   - Delete the `if (now - lastTtsMs < TTS_DEBOUNCE_MS) return;` check

### Edge Cases to Consider

| Scenario | Behavior |
|----------|----------|
| Single `session.idle` | Waits 1.5s, fires TTS |
| Rapid `session.idle` events (< 1.5s apart) | Resets timer each time, fires once after last |
| `session.idle` then `session.status:busy` | Cancels timer, no TTS |
| `permission.asked` / `question.asked` | Fire immediately (no change to existing logic) |
| Timer in progress, then `permission.asked` | Both should fire (permission is important) |

### Configuration Considerations

The trailing delay should be configurable via environment variable (consistent with existing `TTS_COOLDOWN`):

```javascript
const TTS_TRAILING_DELAY_MS = parseInt(process.env.TTS_TRAILING_DELAY ?? "1500", 10);
```

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `session.status` events not fired reliably | TTS never cancelled mid-operation | Fallback: existing behavior with trailing delay still groups notifications |
| Timer too short | Still fires mid-operation | Make delay configurable, start with 1.5s |
| Timer too long | User annoyed by notification delay | Keep at 1.5s, document that delay exists |
| JavaScript async/await with setTimeout | May need Promise wrapper | Use standard async pattern |

---

## Testing Strategy

### Manual Test Cases:

1. **Simple command**: Run `/research 202`, verify TTS fires ~1.5s after completion
2. **Multi-agent operation**: Run `/implement` with multiple phases, verify only ONE TTS at end
3. **Permission prompt**: Verify `permission.asked` still fires TTS immediately
4. **Rapid commands**: Type multiple commands quickly, verify TTS consolidation

### Verification Commands:

```bash
# Watch TTS log during testing
tail -f /home/benjamin/.config/nvim/specs/tmp/claude-tts-notify.log

# Check for multiple rapid notifications
grep "Notification sent" specs/tmp/claude-tts-notify.log | tail -20
```

---

## Decisions

1. **Timer value**: 1500ms (as specified in task description)
2. **Cancellation trigger**: `session.status` with non-idle status type
3. **Permission events**: Keep immediate (no delay for user-blocking events)
4. **Configuration**: Add `TTS_TRAILING_DELAY` environment variable

---

## Next Steps

1. Run `/plan 202` to create implementation plan
2. Implement changes to `wezterm-hooks.js`
3. Test with multi-agent operations
4. Update documentation in `tts-stt-integration.md`

---

## Appendix: File Locations

| File | Purpose | Line Count |
|------|---------|------------|
| `.opencode/plugins/wezterm-hooks.js` | TTS notification plugin (modify) | 64 lines |
| `.opencode/hooks/tts-notify.sh` | TTS shell script (no change) | 145 lines |
| `.opencode/docs/guides/tts-stt-integration.md` | Documentation (update) | 356 lines |
| `specs/tmp/claude-tts-notify.log` | TTS notification log (testing) | varies |

---

## Context Extension Recommendations

None for meta tasks - this is internal .claude/ system modification.

---

**Report Prepared By**: general-research-agent
**Review Status**: Complete
**Confidence Level**: High (based on codebase analysis and event documentation)
