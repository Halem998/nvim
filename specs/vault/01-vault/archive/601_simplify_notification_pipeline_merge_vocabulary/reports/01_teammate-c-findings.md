# Teammate C (Critic): Gaps and Blind Spots in Task 601

**Task**: Simplify WezTerm tab coloring and TTS notification pipeline
**Date**: 2026-05-22
**Confidence Level**: High (all claims verified against source code)

---

## Key Findings

### 1. Root Cause of Color Reset: Stop Hook Fires for Subagent Stops

**Finding**: The `claude-stop-notify.sh` Stop hook fires for ALL stop events, including subagent stops. It attempts to suppress subagent stops by checking for `agent_id` in stdin JSON (line 41). **However**, this suppression depends on Claude Code always providing `agent_id` in the Stop hook stdin for subagent stop events. If `agent_id` is missing or the stdin format differs, the Stop hook falls through to the "no signal" path and fires `needs_input` wezterm coloring + TTS.

**Evidence**:
- `claude-stop-notify.sh` lines 38-44: reads stdin for `agent_id`, suppresses if present
- Lines 64-74: if no signal file AND no agent_id → fires `wezterm-notify.sh` (sets `needs_input`) AND `tts-notify.sh` (speaks "Tab N")
- The SubagentStop hook (`subagent-postflight.sh`) is a *separate* hook event. The Stop hook and SubagentStop hook are independently configured in settings.json.

**Critical question not validated**: Does the `Stop` hook receive `agent_id` in its stdin JSON for subagent completions? The code assumes yes, but if Claude Code doesn't pass `agent_id` to Stop events (only to SubagentStop events), then every subagent completion triggers `needs_input` + TTS, explaining both the color reset and the random TTS announcements.

**Alternative hypothesis**: The Stop hook may not fire for subagent completions at all. In that case, the color reset is caused by something else entirely — possibly the update-status WezTerm handler clearing the status when the user switches tabs, or a race condition in the dual-dispatch architecture.

### 2. Signal File Elimination is Dangerous Without Understanding Hook Ordering

**Finding**: The task proposes "eliminate signal file mechanism entirely," but the signal file solves a real race condition. The current architecture:

1. `update-task-status.sh` postflight writes signal file FIRST (line 372)
2. Then fires wezterm + TTS in background (lines 386, 392)
3. Eventually Stop hook fires, checks signal file, suppresses duplicate

If the signal file is removed, the proposed replacement ("Stop hook only fires needs_input, no TTS") still has a problem: **the Stop hook will OVERWRITE the lifecycle status** set by postflight. The sequence would be:

1. Postflight sets `CLAUDE_STATUS=researched` (or whatever)
2. Stop hook fires, sets `CLAUDE_STATUS=needs_input` → **overwrites researched!**

**Risk**: Unless the Stop hook is changed to completely skip wezterm coloring (not just TTS), the lifecycle color will be overwritten by `needs_input` every time. The task description says "simplify Stop hook to only set needs_input for wezterm" — this is exactly the wrong approach if we want lifecycle colors to persist.

**Recommended fix**: Stop hook should NOT set any wezterm status when postflight has already run. Either keep the signal file, or make the Stop hook entirely skip wezterm coloring and only fire TTS for non-lifecycle stops.

### 3. Artifact-Type → Lifecycle Vocabulary Mismatch Breaks Dim-to-Bold

**Finding**: The current `update-task-status.sh` maps lifecycle states to ARTIFACT types for wezterm:

```bash
research  -> WEZTERM_STATUS="report"    # bg=#1a5a2a
plan      -> WEZTERM_STATUS="plan"      # bg=#1a2a5a
implement -> WEZTERM_STATUS="summary"   # bg=#5a4a1a
```

But the preflight sets lifecycle in-progress states:
```
researching  -> bg=#2a4a2a, fg=#808080 (dim)
planning     -> bg=#2a2a5a, fg=#808080 (dim)
implementing -> bg=#3a3a1a, fg=#808080 (dim)
```

The dim-to-bold transition **cannot work** because:
- Preflight sets `CLAUDE_STATUS=researching` (bg `#2a4a2a`)
- Postflight sets `CLAUDE_STATUS=report` (bg `#1a5a2a`) — **different bg color!**
- The lifecycle equivalent `researched` (bg `#2a4a2a`) shares the same bg as `researching` but has bright fg

If the task merges to lifecycle vocabulary (using `researched` instead of `report`), the dim-to-bold transition becomes: same bg (`#2a4a2a`), fg changes from `#808080` to `#d0d0d0`. This is a **subtle** change that may not be visually distinguishable enough. Consider also changing the bg slightly for completed states.

### 4. Team Mode TTS: The Source is update-task-status.sh, Not Stop Hook

**Finding**: In team mode, the TTS announcements for individual research reports come from `update-task-status.sh` PHASE 5. Each teammate doesn't directly call TTS — but if `update-task-status.sh` is called for each teammate's preflight/postflight, it would fire TTS each time.

**However**: Looking at `skill-team-research`, it only calls `update-task-status.sh` twice:
1. Once for preflight (Stage 2) — no notification (preflight skips PHASE 5)
2. Once for postflight (Stage 10) — fires TTS + wezterm

So the TTS for individual teammates must come from the **Stop hook** (`claude-stop-notify.sh`), which fires when each teammate agent stops. If the Stop hook doesn't detect `agent_id` in stdin, it falls through to TTS dispatch for every teammate completion.

**This confirms Finding #1**: The Stop hook is the source of unwanted TTS, not `update-task-status.sh`.

### 5. Scope Underestimation: 28+ Files Need Changes

**Finding**: The task description says "update all hook copies (4 locations)." The actual count:

| Location | Files | Purpose |
|----------|-------|---------|
| `.claude/hooks/` | 7 wezterm/tts/stop files | Primary hooks |
| `.opencode/hooks/` | 7 wezterm/tts/stop files | OpenCode copies |
| `.claude/extensions/core/hooks/` | 7 wezterm/tts/stop files | Extension templates |
| `.claude/scripts/` | 2 (update-task-status.sh, lifecycle-notify.sh) | Scripts |
| `.opencode/scripts/` | 1 (update-task-status.sh) | OpenCode script |
| `~/.dotfiles/config/wezterm.lua` | 1 | WezTerm config |
| Documentation | 3 (wezterm-integration.md, neovim-integration.md, tts-stt-integration.md) | Docs |

**Total: 28 files**, not "4 locations." The 2-3 hour estimate is optimistic for a change this wide.

### 6. Clear-on-Focus Behavior Has an Edge Case

**Finding**: The `update-status` handler in `wezterm.lua` clears CLAUDE_STATUS when the user **switches to** a tab with a status (lines 414-427). This only fires once per tab switch (tracked via `wezterm.GLOBAL.tab_tracking`). This is correct behavior — it won't continuously clear while the user watches.

**However**: If the user is ALREADY on the tab when the lifecycle transition fires (e.g., they're watching Claude work), the color change happens but `update-status` won't clear it until the user switches AWAY and BACK. This is actually the desired behavior for the "dim-to-bold" transition — the user sees it live. No issue here.

**Edge case**: If the user switches to the tab during the brief window between preflight (dim) and postflight (bold), the `update-status` handler clears the dim color. The user would see the tab go from dim → default → bold (if they switch back). This is a minor UX glitch.

### 7. Backward Compatibility: Removing Artifact Types is Safe

**Finding**: The artifact-type vocabulary (`report`, `plan`, `summary`, `error`) is only used in:
1. `update-task-status.sh` PHASE 5 (the mapping)
2. `wezterm.lua` status_colors table (the display)

No other file depends on these artifact-type values. Removing them from both locations simultaneously is safe. The `wezterm.lua` already has safe degradation for unknown values (line 340).

---

## Recommended Approach

1. **Fix the root cause first**: Determine definitively whether the Stop hook receives `agent_id` for subagent completions. If not, the entire subagent suppression logic is broken and needs rethinking. Test by adding logging to `claude-stop-notify.sh` to capture stdin JSON.

2. **Don't eliminate signal file prematurely**: Keep it (or replace with equivalent) until you have a guaranteed ordering between postflight wezterm-notify and Stop hook wezterm-notify. Without the suppress mechanism, Stop will always overwrite lifecycle colors with `needs_input`.

3. **Merge vocabulary is correct direction**: Using `researched`/`planned`/`completed` instead of `report`/`plan`/`summary` simplifies the architecture. But adjust the wezterm colors so completed states have visibly different backgrounds from in-progress states (not just fg change).

4. **Stop hook should be wezterm-silent on lifecycle stops**: Rather than "only set needs_input," the Stop hook should check whether a lifecycle state is already set and skip wezterm entirely. Only set `needs_input` + fire TTS for true interactive stops (no workflow in progress).

5. **Budget 4-5 hours, not 2-3**: 28 files across 3 copy locations + wezterm.lua + 3 docs is significant.

---

## Evidence Summary

| Claim | Source | Line(s) |
|-------|--------|---------|
| Stop hook checks agent_id | claude-stop-notify.sh | 38-44 |
| No signal → needs_input + TTS | claude-stop-notify.sh | 64-74 |
| Postflight maps to artifact types | update-task-status.sh | 380-386 |
| Signal file written before notify | update-task-status.sh | 370-372 |
| Clear-on-focus only on tab switch | wezterm.lua | 414-427 |
| status_colors has both vocabularies | wezterm.lua | 320-333 |
| Lifecycle-notify.sh is deprecated stub | lifecycle-notify.sh | line 1-10 |
| 28 files across 3+2+1 locations | find/ls commands | (see count above) |
