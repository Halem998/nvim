# Research Report: Fix Stop Hook TTS

**Task**: 680 - Fix Stop hook to fire TTS when user attention is needed
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 679 (TTS best practices research)
**Sources/Inputs**: Codebase (claude-stop-notify.sh, tts-notify.sh, wezterm-notify.sh, wezterm-preflight-status.sh, orchestrator-postflight.sh, lifecycle-notify.sh, update-task-status.sh, settings.json), global ~/.config/.claude/hooks/tts-notify.sh, task 679 research report
**Artifacts**: specs/680_fix_stop_hook_tts/reports/01_stop-hook-tts-research.md
**Standards**: report-format.md

---

## Executive Summary

- **Root cause confirmed**: Line 59-63 of `.claude/hooks/claude-stop-notify.sh` fires `wezterm-notify.sh` but has an explicit comment "no TTS for non-lifecycle stops" and no `tts-notify.sh` call. This is the single change needed to restore TTS on `/implement`, `/todo`, `/orchestrate` completion.
- **Project tts-notify.sh has no cooldown**: Unlike the global `~/.config/.claude/hooks/tts-notify.sh` (which uses `/tmp/claude-tts-last-notify` with 10s cooldown), the project version has no dedup mechanism at all. Cooldown must be added.
- **Double-announcement risk is real for task 681**: When orchestrator-postflight fires TTS via lifecycle-notify.sh and then clears the workflow-active marker (task 681 change), the main-agent Stop will fire seconds later. The shared cooldown timestamp file at `/tmp/claude-tts-last-notify` will prevent the double-speak — but ONLY if both callers update the same file.
- **Notification matcher gap confirmed**: `idle_prompt` is missing from settings.json. The fix is a one-line string change.
- **Subagent suppression is safe**: The Stop hook reads STDIN_JSON once at line 40 and checks `agent_id` before reaching the wezterm/TTS section. TTS placement (after the marker check, as a parallel call to wezterm-notify) is safe.

---

## Current Behavior Analysis

### Signal Flow for `/implement N` (broken path)

```
User runs /implement N
  -> UserPromptSubmit fires wezterm-preflight-status.sh
     -> Sets CLAUDE_STATUS=implementing (tab turns gold)
  -> update-task-status.sh preflight runs
     -> Writes .claude/tmp/workflow-active
  -> [... agent works ...]
  -> orchestrator-postflight.sh Stage 8b runs
     -> lifecycle-notify.sh "completed" --quiet  (tab color only, NO TTS)
     -> workflow-active marker NOT cleared here
  -> Main agent Stop fires
     -> claude-stop-notify.sh:
        Line 40: reads STDIN_JSON (agent_id check passes — no agent_id)
        Line 54: workflow-active marker EXISTS -> exit_success (silently suppressed)
  -> RESULT: TTS never fires
```

The workflow-active marker is written on preflight but is only cleared in two places:
1. `wezterm-preflight-status.sh` Tier 2 — fires on ANY non-lifecycle slash command (e.g., next `/task` or `/research` typed by user)
2. Never cleared by orchestrator-postflight.sh itself

This means: after every `/implement` completion, the workflow-active marker remains until the user types another non-lifecycle command. The final Stop (main agent halting after sending its response) fires while the marker is still present → silently suppressed.

### Signal Flow for Interactive Stop (broken path)

```
User asks Claude a question (no /command)
  -> UserPromptSubmit Tier 3: no-op (marker preserved from prior lifecycle command)
  -> [... agent works ...]
  -> Main agent Stop fires
     -> claude-stop-notify.sh:
        If marker exists from last lifecycle run -> suppressed (bug)
        If marker was cleared -> wezterm-notify only (correct suppression of TTS was intentional)
```

The comment on line 59 says "no TTS for non-lifecycle stops." This WAS intentional — the original design was: TTS fires only via lifecycle-notify.sh. But lifecycle-notify.sh is always called with `--quiet`, so TTS never fires anywhere.

---

## Proposed Change Set (File by File)

### Change 1: `.claude/hooks/claude-stop-notify.sh`

**Purpose**: Add TTS call alongside the existing wezterm-notify call in the non-workflow-active branch.

**Current state (lines 58-65)**:
```bash
# --- No active workflow: interactive / non-lifecycle stop ---
# Fire needs_input wezterm color only (no TTS for non-lifecycle stops)
wezterm_script="$SCRIPT_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" 2>/dev/null || true
fi

exit_success
```

**Proposed change**:
```bash
# --- No active workflow: interactive / non-lifecycle stop ---
# Fire needs_input wezterm color + TTS announcement for user attention
wezterm_script="$SCRIPT_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" 2>/dev/null || true
fi

# TTS announcement: speaks "Tab N" to alert user Claude has stopped
tts_script="$SCRIPT_DIR/tts-notify.sh"
if [[ -f "$tts_script" ]]; then
    bash "$tts_script" 2>/dev/null || true
fi

exit_success
```

**Line reference**: Lines 58-65. Insert the TTS block between the wezterm call and `exit_success`.

**Arguments**: No arguments — `tts-notify.sh` with no args uses interactive mode (speaks "Tab N").

**Error handling**: Consistent with wezterm call: `2>/dev/null || true` makes the call non-blocking and error-tolerant.

**Subagent suppression**: The `agent_id` check at line 40-45 exits before reaching this code. Safe.

**Stdin consumption**: STDIN_JSON is read once at line 40 (`STDIN_JSON=$(cat 2>/dev/null || echo '{}')`). The tts-notify.sh call receives no stdin (not piped). Safe.

---

### Change 2: `.claude/hooks/tts-notify.sh` — Add Cooldown Mechanism

**Purpose**: Add a timestamp cooldown to the project tts-notify.sh, matching the pattern from the global version. This prevents double-announcement when both orchestrator-postflight (task 681's lifecycle TTS) and Stop hook TTS fire within the cooldown window.

**Current state**: The project tts-notify.sh has no cooldown mechanism at all (lines 1-128 have no `/tmp/claude-tts-last-notify` reference).

**Proposed addition** — Insert after the `LOG_FILE` declaration (after line 30) and before `Parse arguments` (before line 32):

```bash
# Cooldown configuration
TTS_COOLDOWN="${TTS_COOLDOWN:-10}"
LAST_NOTIFY_FILE="/tmp/claude-tts-last-notify"
```

Then insert a cooldown check block after the piper/model checks (after line 105, before the LIFECYCLE_MODE section at line 111). The check goes at the point where we know TTS will fire:

```bash
# Check cooldown (shared timestamp file with global tts-notify.sh)
if [[ -f "$LAST_NOTIFY_FILE" ]]; then
    LAST_TIME=$(cat "$LAST_NOTIFY_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_TIME))
    if (( ELAPSED < TTS_COOLDOWN )); then
        log "Cooldown active: ${ELAPSED}s < ${TTS_COOLDOWN}s - skipping TTS"
        exit_success
    fi
fi
```

Then, after each `speak` call succeeds (in both lifecycle and interactive modes), update the cooldown timestamp:

```bash
# Update cooldown timestamp
date +%s > "$LAST_NOTIFY_FILE"
```

**Cooldown file location**: `/tmp/claude-tts-last-notify` — same path as global version. This is intentional: BOTH the project tts-notify.sh AND the global tts-notify.sh share this file, enabling cross-project dedup.

**Cooldown env var**: `TTS_COOLDOWN` — same as global version. Default: 10 seconds.

**Cooldown applies to**: Both lifecycle mode and interactive mode. The cooldown file is checked before both LIFECYCLE_MODE and INTERACTIVE_MODE sections.

**Why 10 seconds**: Short enough not to suppress legitimate successive lifecycle announcements (research → plan → implement each takes minutes apart). Long enough to dedup a Stop hook firing 1-2 seconds after lifecycle-notify.sh.

**Exact insertion point**:
- Cooldown vars: after line 30 (`LOG_FILE="specs/tmp/claude-tts-notify.log"`)
- Cooldown check block: after line 105 (after `fi` closing the piper model check), before line 107 (blank line before `# LIFECYCLE_MODE` section)
- Timestamp write: after each `speak` call, before `log` and `exit_success` in both modes

---

### Change 3: `.claude/settings.json` — Notification Matcher

**Purpose**: Add `idle_prompt` to the Notification hook matcher so TTS fires when Claude is waiting for user input (60+ seconds idle).

**Current state (line 140)**:
```json
"matcher": "permission_prompt|elicitation_dialog",
```

**Proposed change**:
```json
"matcher": "permission_prompt|idle_prompt|elicitation_dialog",
```

**Location**: Line 140 in `.claude/settings.json`, within the `"Notification"` hook section.

**Rationale**: `idle_prompt` fires when Claude has been waiting for user input for ≥ 60 seconds. This is exactly the case where TTS matters: the user is away from the keyboard and Claude is blocked waiting for them. The 679 report confirmed this as an actionable notification type.

---

## Cooldown Design (Detailed)

### File Location
`/tmp/claude-tts-last-notify` — identical to global version path. Using `/tmp` (not `specs/tmp/`) ensures the file persists across Claude sessions within a machine boot and is shared between the project tts-notify.sh (called by Stop hook and Notification hook) and the global version (if active). This cross-script sharing is the dedup mechanism for task 681's double-announcement scenario.

### Env Var
`TTS_COOLDOWN` — default 10 seconds. Configurable per-session via environment variable (same as global version). User can set `TTS_COOLDOWN=0` to disable cooldown or `TTS_COOLDOWN=30` for longer dedup windows.

### Applies to Both Modes
Cooldown applies equally to lifecycle mode (`--lifecycle STATUS`) and interactive mode (no args). Both modes update the timestamp after speaking. This prevents:
- Two consecutive lifecycle events from spamming (extremely unlikely given orchestrator timing)
- A lifecycle TTS + Stop hook TTS firing within 10 seconds of each other (the primary dedup case)
- A permission_prompt Notification TTS + Stop hook TTS firing simultaneously

### Does NOT Apply to
The cooldown should NOT be bypassed for any mode. Even lifecycle announcements should respect the cooldown — if `orchestrator-postflight.sh` fires "Tab 3 completed" via lifecycle-notify.sh, the Stop hook's "Tab 3" firing 2 seconds later is redundant and should be suppressed by the 10-second cooldown.

---

## Double-Announcement Dedup Strategy (Task 681 Interaction)

### The Scenario (Post Task 681)

After task 681 is implemented, orchestrator-postflight.sh (or equivalent) will:
1. Call `lifecycle-notify.sh "completed"` WITHOUT `--quiet` → fires TTS ("Tab N completed")
2. Clear the workflow-active marker

Then, seconds later:
3. Main agent Stop fires
4. `claude-stop-notify.sh` detects no workflow-active marker → reaches the TTS branch
5. Calls `tts-notify.sh` → would speak "Tab N" (interactive mode)

Result without cooldown: user hears "Tab 3 completed" then "Tab 3" within ~2 seconds. Confusing.

### Dedup via Shared Cooldown File

With the cooldown added to project tts-notify.sh:

- Step 1: lifecycle-notify.sh calls `tts-notify.sh --lifecycle completed` → speaks "Tab 3 completed" → writes timestamp to `/tmp/claude-tts-last-notify`
- Step 5: claude-stop-notify.sh calls `tts-notify.sh` → checks cooldown → ELAPSED < 10s → suppressed

User hears exactly one announcement: "Tab 3 completed". The Stop hook TTS is silently suppressed.

### Why This Works Correctly

- The timestamp is shared: both lifecycle-notify.sh and claude-stop-notify.sh call the same `tts-notify.sh` file, which will check and update the same `/tmp/claude-tts-last-notify` file.
- The timing gap between lifecycle TTS and Stop hook TTS is typically 1-5 seconds (background process timing).
- 10-second cooldown comfortably covers this gap.
- The cooldown does NOT prevent TTS when the user legitimately submits a new prompt (that clears the workflow-active marker) and then Claude responds 15+ seconds later — elapsed time will exceed cooldown.

### Task Ordering Recommendation

Task 680 (this task) should be implemented BEFORE task 681, OR the two changes should coordinate:
- Task 680 adds TTS call to claude-stop-notify.sh + adds cooldown to tts-notify.sh
- Task 681 removes `--quiet` from orchestrator-postflight.sh Stage 8b + clears workflow-active marker before final Stop

If task 681 is implemented without task 680's cooldown, the double-announcement will occur. If task 680 is implemented without task 681, the TTS fires for interactive/manual stops but lifecycle completions still have no TTS (acceptable interim state).

---

## Subagent Suppression Verification

### Stdin Consumed Once

In `claude-stop-notify.sh`, STDIN is read exactly once:
```bash
STDIN_JSON=$(cat 2>/dev/null || echo '{}')  # Line 40
```

The subsequent `tts-notify.sh` call is a subprocess call with no stdin piping:
```bash
bash "$tts_script" 2>/dev/null || true
```

`tts-notify.sh` itself does NOT read from stdin (it has no `cat` or `read` for stdin). The global version does read stdin (`HOOK_INPUT=$(timeout 1s cat 2>/dev/null || echo '{}')` line 41) but the PROJECT tts-notify.sh does not.

**Conclusion**: Adding the TTS call after line 63 is safe. No stdin-consumed-twice risk.

### Subagent Check Placement

The subagent check at lines 40-45 runs before the workflow-active check (line 54) and before the TTS branch (lines 58-65). Both checks correctly gate the TTS branch. Order:
1. Read STDIN_JSON (line 40)
2. Check agent_id → exit if subagent (lines 41-45)
3. Check workflow-active marker → exit if mid-orchestrate (lines 51-56)
4. Fire wezterm-notify + TTS (lines 58-65, proposed)

This is the correct order and no reordering is needed.

---

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Double-announcement after task 681 | High (without cooldown) | Cooldown in tts-notify.sh shares `/tmp/claude-tts-last-notify` file with lifecycle path |
| TTS fires on every subagent stop | None | agent_id check at line 40-45 gates this; tested in task 679 research |
| Cooldown suppresses legitimate consecutive TTS | Low | 10s window << typical time between user interactions |
| Stale workflow-active marker suppresses interactive TTS | Present (pre-task-681) | Cleared by wezterm-preflight-status.sh Tier 2 on next slash command; task 681 fixes root cause |
| tts-notify.sh called without WEZTERM_PANE set | Handled | get_tab_prefix() falls back to "Tab" if WEZTERM_PANE unset |
| piper/aplay not installed | Handled | tts-notify.sh exits_success gracefully if piper/aplay missing |
| `/tmp` path not writable | Very low | `/tmp` is writable by all users on Linux; fallback: cooldown check fails gracefully |

---

## Summary of Changes

| File | Change | Lines |
|------|--------|-------|
| `.claude/hooks/claude-stop-notify.sh` | Add `tts-notify.sh` call in non-workflow-active branch | After line 63, before `exit_success` |
| `.claude/hooks/claude-stop-notify.sh` | Update comment on line 59 (remove "no TTS" statement) | Line 59 |
| `.claude/hooks/tts-notify.sh` | Add `TTS_COOLDOWN` and `LAST_NOTIFY_FILE` vars | After line 30 |
| `.claude/hooks/tts-notify.sh` | Add cooldown check block | After line 105 |
| `.claude/hooks/tts-notify.sh` | Add timestamp write after each `speak` call | After `speak` in lifecycle mode (line ~114) and interactive mode (line ~125) |
| `.claude/settings.json` | Add `idle_prompt` to Notification matcher | Line 140 |

**Out of scope for task 680** (handled by task 681):
- `orchestrator-postflight.sh`: Remove `--quiet` from lifecycle-notify.sh call
- Clearing workflow-active marker before final Stop in orchestrator flow

---

## Appendix: Key File References

- `.claude/hooks/claude-stop-notify.sh` lines 40-65: STDIN read + subagent check + workflow-active check + wezterm call
- `.claude/hooks/tts-notify.sh` lines 1-128: full project TTS script (no cooldown currently)
- `~/.config/.claude/hooks/tts-notify.sh` lines 69-78: cooldown check pattern to copy
- `~/.config/.claude/hooks/tts-notify.sh` line 132: timestamp write pattern to copy
- `.claude/scripts/lifecycle-notify.sh` lines 39-43: how tts-notify.sh is called with `--lifecycle STATUS`
- `.claude/scripts/orchestrator-postflight.sh` lines 304-314: Stage 8b with `--quiet` flag (task 681 target)
- `.claude/scripts/update-task-status.sh` lines 146-150: workflow-active marker write (preflight only, never cleared on postflight)
- `.claude/hooks/wezterm-preflight-status.sh` lines 71 and 87: only place workflow-active marker is cleared (Tier 2 slash commands)
- `.claude/settings.json` line 140: current Notification hook matcher
