# Research Report: TTS Best Practices for Claude Code Hooks

**Task**: 679 - Research June 2026 TTS best practices for Claude Code hooks
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: ~2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (tts-notify.sh, claude-stop-notify.sh, orchestrator-postflight.sh, settings.json), Claude Code docs, echook, cc-hooks, claude-code-tts projects
**Artifacts**: specs/679_research_tts_best_practices/reports/01_tts-best-practices.md

## Summary

Claude Code's hook system now provides 30+ lifecycle events as of June 2026, but there are no new "AgentComplete" or "TaskComplete" events that improve on Stop for TTS triggering. The existing Notification hook matcher `permission_prompt|elicitation_dialog` is incomplete — `idle_prompt` is a documented, actionable notification type that should be added. The core problem (TTS not firing when /implement or /orchestrate completes) is a deliberate suppression in the project settings.json that needs a targeted fix: the Stop hook should call TTS when no workflow-active marker exists, not just set the wezterm color.

---

## Findings

### 1. Available Claude Code Hook Events

The official Claude Code documentation (June 2026) lists **30 hook event types**:

**Session-scoped**: SessionStart, Setup, SessionEnd  
**Prompt-scoped**: UserPromptSubmit, UserPromptExpansion  
**Tool-scoped**: PreToolUse, PostToolUse, PostToolUseFailure, PostToolBatch  
**Permission-scoped**: PermissionRequest, PermissionDenied  
**Agent-scoped**: SubagentStart, SubagentStop, TeammateIdle  
**Task-scoped**: TaskCreated, TaskCompleted  
**File-scoped**: FileChanged, CwdChanged, WorktreeCreate, WorktreeRemove  
**Lifecycle**: Stop, StopFailure, InstructionsLoaded, ConfigChange, PreCompact, PostCompact  
**Notification**: Notification, MessageDisplay, Elicitation, ElicitationResult  

**Key finding**: There is no new "AgentComplete" or "OrchestratorDone" hook. `Stop` remains the canonical event for "main agent finished responding."

**TaskCompleted** fires when a Claude Code Task tool marks a task complete — this is the internal `TaskCreate`/`TaskUpdate` tool system, NOT the project's own task management in state.json. It is not a useful target for the project's TTS needs.

**SubagentStop** fires with `agent_id` and `agent_type` in the input JSON, making it easy to distinguish from main-agent Stop. The current `claude-stop-notify.sh` correctly detects subagent stops via `agent_id` in stdin JSON.

**stop_hook_active** is a boolean field in the Stop hook input that is `true` when Claude is already continuing because a previous Stop hook blocked stopping (exit code 2). This is critical for preventing infinite loops in blocking Stop hooks.

**For TTS targeting**: The correct approach remains:
- Main agent stop (no `agent_id`) AND no workflow-active marker → fire TTS
- Subagent stop (`agent_id` present) → suppress
- Mid-orchestrator pause (workflow-active marker exists) → suppress
- Orchestrator/lifecycle completion → fire TTS via lifecycle-notify.sh

**The current project architecture is sound.** The specific bug is that `orchestrator-postflight.sh` Stage 8b always passes `--quiet` to `lifecycle-notify.sh`, suppressing TTS even on final completion.

---

### 2. TTS Notification Patterns in AI Coding Tools

Several open-source Claude Code TTS projects were reviewed:

**echook** (ChanMeng666): Most sophisticated. Uses 6 hooks by default (stop, notification, subagent_stop, permission_request, session_start, session_end). Key patterns:
- Debounce timing: 500ms configurable window to prevent duplicate firing
- Rate-limit one-shot: Each `(window, threshold)` fires exactly once (warned at 80%, 95%)  
- Marker-based state: Debounce/snooze markers written to disk persist across invocations
- Speaks Claude's actual final message (truncated 200 chars) — opt-in for privacy
- Status line context monitor: Shows context window and API quota bars alongside audio

**cc-hooks** (husniadil): Simpler. Stop fires "always (contextual with AI)". SubagentStop fires cetek.mp3 sound effect. No documented deduplication.

**claude-code-tts** (ktaletsk): Uses Stop hook to extract text from transcript, strip markdown, feed to kokoro-tts. UserPromptSubmit stops audio playback. No cooldown documented.

**Common "when done" pattern**:
1. Stop hook fires
2. Check for subagent context (agent_id field) — skip if subagent
3. Optional: read transcript to extract Claude's last message for context-aware TTS
4. Play audio in background (non-blocking)
5. Update last-notify timestamp for cooldown

The project's approach of saying "Tab N" rather than reading the transcript is intentionally brief and is well-suited for multi-tab workflows.

---

### 3. Notification Hook Matchers

The official Claude Code docs enumerate these `notification_type` values for the Notification hook matcher:

| notification_type | Trigger condition | Actionable? |
|---|---|---|
| `permission_prompt` | Tool permission request | **Yes** — user must approve |
| `idle_prompt` | Claude idle ≥ 60s waiting for input | **Yes** — user attention needed |
| `auth_success` | Authentication completed | No — informational |
| `elicitation_dialog` | MCP server requests structured input | **Yes** — user must provide data |
| `elicitation_complete` | MCP elicitation finished | No — informational |
| `elicitation_response` | User responded to elicitation | No — informational |

**Current project matcher**: `permission_prompt|elicitation_dialog`

**Assessment**: This is close but incomplete. `idle_prompt` is the third actionable notification type — it fires when Claude has been waiting for user input for 60+ seconds. This is exactly the situation where TTS ("Tab N") would be valuable: the user has walked away and Claude is waiting.

`auth_success` fires when OAuth or similar auth completes — it is purely informational and should NOT trigger TTS. The global settings.json currently uses `matcher: "*"` for Notification which would include `auth_success`. This is a minor issue in the global config.

**Recommended matcher**: `permission_prompt|idle_prompt|elicitation_dialog`

---

### 4. Terminal Tab + TTS Integration Patterns

**WezTerm OSC 1337 UserVar pattern** (current implementation):
- Set via: `printf "\033]1337;SetUserVar=%s=%s\007" VARNAME $(echo -n VALUE | base64)`
- Read in Lua via: `pane:get_user_vars()` or `tab.active_pane.user_vars`
- Events: `user-var-changed` fires immediately; `update-status` fires for status bar
- The current `CLAUDE_STATUS` approach is well-aligned with WezTerm best practices

**Coordination between audio and visual**:
- WezTerm tab color change should happen BEFORE TTS speaks (visual is faster)
- TTS provides ambient notification for users not watching the screen
- The color persists (sticky) until user navigates to tab; TTS is one-shot
- This asymmetry is correct: visual is persistent, audio is momentary

**Pattern from echook**: Status line context monitor alongside TTS — the audio announces, the visual confirms. The two signals are complementary rather than redundant.

**Recommended architecture for the project**:
1. lifecycle-notify.sh calls wezterm-notify.sh first (tab color), then tts-notify.sh (audio)
2. Stop hook (non-workflow): wezterm-notify.sh first, then TTS
3. Both signals should fire together for any user-attention event

The current architecture already follows this pattern in `lifecycle-notify.sh`. The bug is in `orchestrator-postflight.sh` suppressing TTS via `--quiet`.

---

### 5. Deduplication and Cooldown Strategies

**The problem in multi-agent workflows**: When /orchestrate runs, multiple sub-agents complete and fire Stop events in rapid succession. Without deduplication, TTS could speak "Tab N" 5-10 times during a single orchestration run.

**Current project approach**:
- `claude-stop-notify.sh` uses a workflow-active marker file (`.claude/tmp/workflow-active`) to suppress mid-orchestrator Stop fires
- Global `tts-notify.sh` uses a timestamp-based cooldown (`/tmp/claude-tts-last-notify`, default 10s)
- Project tts-notify.sh has no cooldown mechanism of its own

**Best practices from research**:

1. **Marker-file approach** (current, works): Write a marker before work begins, clear it when done. TTS only fires when no marker exists. Problem: marker must be reliably cleared even on failure.

2. **Timestamp cooldown** (global tts uses, echook uses): Write `date +%s` to a file after each TTS. On next invocation, read it and compare with `TTS_COOLDOWN` (10-30s). This is simple, portable, and effective.

3. **One-shot per session** (echook rate-limit pattern): For rate-limit alerts, fire exactly once per threshold per session. Applied to lifecycle TTS: fire exactly once per status transition per task.

4. **PID/lock file approach**: Create a lockfile with the firing process PID. If lockfile exists and PID is live, skip. Overkill for this use case.

5. **Debounce window** (echook 500ms): After first TTS in a batch, suppress for 500ms. Prevents rapid-fire duplicates from near-simultaneous events.

**Recommended for project**:
- Keep the workflow-active marker approach for orchestrator suppression (it works well)
- Add a short timestamp cooldown (5-10s) to the project tts-notify.sh for defense-in-depth
- The cooldown window should be short enough not to suppress legitimate lifecycle announcements that fire in sequence (e.g., "researched" → user prompt → "planned" should both speak)
- Do NOT use cooldown longer than the typical time between user interactions

**The correct fix for tasks 680 and 681 is NOT deduplication** — it is restoring the intentionally-suppressed TTS calls in two specific places:
1. `claude-stop-notify.sh`: When no workflow-active marker, call TTS in addition to wezterm-notify
2. `orchestrator-postflight.sh` Stage 8b: Remove `--quiet` flag (or make it conditional on whether this is mid-orchestrator vs final completion)

---

## Recommendations

### For Task 680 (Fix Stop Hook TTS)

**Problem**: `claude-stop-notify.sh` fires wezterm-notify but NOT tts-notify when no workflow-active marker exists.

**Fix**: Add TTS call after the wezterm-notify call in the "no active workflow" branch:
```bash
# --- No active workflow: interactive / non-lifecycle stop ---
wezterm_script="$SCRIPT_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" 2>/dev/null || true
fi

# TTS announcement (same cases as wezterm: interactive/non-lifecycle stop)
tts_script="$SCRIPT_DIR/tts-notify.sh"
if [[ -f "$tts_script" ]]; then
    bash "$tts_script" 2>/dev/null || true
fi
```

This ensures: non-lifecycle completions (manual Claude runs, /chat, etc.) announce via TTS.

**Add a timestamp cooldown to project tts-notify.sh** (borrow from global version):
- Use `/tmp/claude-tts-last-notify` with 10s default cooldown
- Check cooldown before speaking in BOTH interactive and lifecycle modes
- This prevents double-speak if Stop fires twice quickly

**Update Notification hook matcher** in project settings.json:
- Change `"permission_prompt|elicitation_dialog"` to `"permission_prompt|idle_prompt|elicitation_dialog"`
- This adds the idle_prompt case (Claude waiting 60s+ for user input)

### For Task 681 (Fix Orchestrator Final TTS)

**Problem**: `orchestrator-postflight.sh` Stage 8b always passes `--quiet` to `lifecycle-notify.sh`, suppressing TTS even on final completion of /orchestrate.

**Root cause**: The --quiet flag was added to suppress TTS mid-orchestrate (between phases). But it also suppresses TTS on the final phase completion.

**Fix options**:

Option A: Pass a flag from the calling skill (skill-orchestrate, skill-implementer) indicating whether this is the final completion. `orchestrator-postflight.sh` would pass `--quiet` only when `IS_FINAL_COMPLETION` is not set.

Option B: The orchestrator itself calls `lifecycle-notify.sh` WITHOUT `--quiet` after its own final state machine completes. This is the cleanest architectural solution — the orchestrator controls its own final announcement.

Option C: Remove `--quiet` from `orchestrator-postflight.sh` entirely. This would make TTS fire for every phase completion (researched, planned, completed). This is actually desirable for lifecycle tracking — hearing "Tab 3 researched" then "Tab 3 planned" then "Tab 3 completed" is informative.

**Recommendation**: Option C (remove `--quiet`) for simplicity. The cooldown mechanism prevents rapid-fire if multiple phases complete quickly. The lifecycle vocabulary is already concise ("Tab N researched", "Tab N planned", "Tab N completed").

If Option C causes TTS fatigue in long orchestrations, switch to Option B: orchestrator emits one final "completed" announcement.

### Notification Hook Matcher Update (Both Tasks)

In `specs/679_research_tts_best_practices` context: update the project settings.json Notification hook matcher from:
```
"permission_prompt|elicitation_dialog"
```
to:
```
"permission_prompt|idle_prompt|elicitation_dialog"  
```

Also update global `~/.config/.claude/settings.json` Notification hook from `"*"` to the specific matcher to avoid announcing `auth_success`.

---

## Sources

- [Claude Code Hooks Reference - Official Docs](https://code.claude.com/docs/en/hooks)
- [echook - AI-operated audio notifications for Claude Code](https://github.com/ChanMeng666/claude-code-audio-hooks)
- [cc-hooks - Audio feedback plugin for Claude Code](https://github.com/husniadil/cc-hooks)
- [claude-code-tts - TTS integration with audio ducking](https://github.com/ktaletsk/claude-code-tts)
- [Claude Code Hooks: Complete Reference 2026](https://thepromptshelf.dev/blog/claude-code-hooks-complete-reference-2026/)
- [Claude Code Hooks & Agent SDK Reference 2026](https://www.morphllm.com/claude-code-hooks)
- [WezTerm: Passing Data from a Pane to Lua](https://wezterm.org/recipes/passing-data.html)
- [Claude Code hook schemas gist](https://gist.github.com/FrancisBourre/50dca37124ecc43eaf08328cdcccdb34)
- [SmartScope: Claude Code Hooks Guide](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/)
- [StackToHeap: Having Fun with Claude Code Hooks](https://stacktoheap.com/blog/2025/08/03/having-fun-with-claude-code-hooks/)
