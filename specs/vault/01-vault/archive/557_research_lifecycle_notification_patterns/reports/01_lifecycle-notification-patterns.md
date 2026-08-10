# Research Report: Task #557

**Task**: 557 - Research lifecycle notification patterns for Claude Code hooks
**Started**: 2026-05-13T00:00:00Z
**Completed**: 2026-05-13T00:45:00Z
**Effort**: Medium (research-only)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/hooks/tts-notify.sh`, `wezterm-notify.sh`, `wezterm-clear-status.sh`, `wezterm-task-number.sh`, `memory-nudge.sh`, `subagent-postflight.sh`, `post-command.sh`
- Codebase: `.claude/settings.json` (hook configuration), `.claude/scripts/update-task-status.sh`, `postflight-research.sh`, `postflight-implement.sh`
- Codebase: `~/.config/wezterm/wezterm.lua` (format-tab-title handler, CLAUDE_STATUS, TASK_NUMBER)
- WebSearch: Claude Code hooks documentation (code.claude.com/docs/en/hooks)
- WebSearch: Claude Code hook schemas (gist FrancisBourre/50dca37124ecc43eaf08328cdcccdb34)
- WebSearch: WezTerm user variables (wezterm.org/recipes/passing-data.html)
- WebSearch: Agent UX notification patterns (smashingmagazine.com, hatchworks.com, Cursor/Windsurf notification systems)
- WebSearch: Atomic file operations and race conditions (tldp.org, linuxvox.com)
**Artifacts**: - `specs/557_research_lifecycle_notification_patterns/reports/01_lifecycle-notification-patterns.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current system fires TTS ("Tab N") on EVERY Stop event, creating notification spam during multi-step agent workflows where dozens of intermediate stops occur before a meaningful lifecycle checkpoint
- **Approach B (Direct Invocation)** is the recommended primary approach, augmented with a signal file for the Stop hook to handle edge cases -- forming a **B+A Hybrid**
- Claude Code 2026 provides `stop_reason`, `last_assistant_message`, and `agent_id` in Stop hook stdin JSON, but no native lifecycle-state field; the existing `memory-nudge.sh` already demonstrates text-pattern matching on `last_assistant_message` as a viable detection mechanism
- New Claude Code events (`TaskCompleted`, `TaskCreated`) exist but require experimental agent teams and do not map to the custom task lifecycle (researched/planned/completed)
- WezTerm user variables can carry arbitrary string state via OSC 1337; `CLAUDE_STATUS` can be extended to multi-value without breaking the existing `format-tab-title` handler

## Context and Scope

### Problem Statement

The user runs Claude Code in multiple WezTerm tabs simultaneously. The current TTS hook announces "Tab N" on every Stop event to alert the user which tab needs attention. During agent workflows (`/research`, `/plan`, `/implement`), a single command produces 5-20+ Stop events as subagents work, creating repetitive audio noise. The user wants TTS announcements only at meaningful lifecycle boundaries:

1. Research complete (status -> "researched")
2. Plan created (status -> "planned")
3. Implementation complete (status -> "completed")
4. Task blocked/partial (status -> "blocked" or "partial")
5. Permission prompts / elicitation dialogs (already handled correctly via Notification hook)

### Current Architecture

The hook chain on a typical `/research N` command:

```
UserPromptSubmit -> wezterm-task-number.sh (sets TASK_NUMBER user var)
                 -> wezterm-clear-status.sh (clears CLAUDE_STATUS)

[Orchestrator runs, spawns skill-researcher, spawns research agent]
  SubagentStop -> subagent-postflight.sh (blocks stop if .postflight-pending)

[Multiple intermediate Stop events during orchestrator work]
  Stop -> post-command.sh (logging)
       -> tts-notify.sh  (TTS "Tab N" -- THIS IS THE SPAM)
       -> wezterm-notify.sh (sets CLAUDE_STATUS=needs_input)
       -> memory-nudge.sh (lifecycle detection via pattern matching)

[Skill postflight runs]
  -> update-task-status.sh postflight N research $session_id

[Final Stop -- user actually needs to know]
  Stop -> tts-notify.sh (TTS "Tab N" -- LEGITIMATE)
       -> wezterm-notify.sh
```

### Key Discovery: memory-nudge.sh Pattern

The existing `memory-nudge.sh` hook (lines 77-98) already implements lifecycle detection by pattern-matching `last_assistant_message` from Stop hook stdin JSON. It checks for:
- `task N: complete (research|implementation|plan)` (git commit messages)
- `status.*(researched|planned|completed|implemented)` (status update output)
- `(research|plan|implementation) complete` (natural language)

This proves that lifecycle-aware filtering is already working in the codebase. The TTS hook simply needs the same gating logic.

## Findings

### 1. Claude Code Hook Event Model (2026)

**Stop hook stdin JSON fields**:
```json
{
  "session_id": "string",
  "transcript_path": "string",
  "cwd": "string",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "hook_event_name": "Stop",
  "stop_reason": "end_turn",
  "last_assistant_message": "string (full text of last response)",
  "agent_id": "string (only for subagent contexts)",
  "agent_type": "string (only for subagent/--agent contexts)",
  "stop_hook_active": "boolean (true if a previous Stop hook already ran)",
  "effort": { "level": "low|medium|high|xhigh|max" }
}
```

**Key fields for lifecycle filtering**:
- `agent_id` -- already used by tts-notify.sh to suppress subagent TTS
- `last_assistant_message` -- contains the text of Claude's final response, usable for pattern matching (proven by memory-nudge.sh)
- `stop_reason` -- "end_turn" for normal completion
- `stop_hook_active` -- prevents infinite loops when Stop hook triggers more work

**New events in 2026 (not present in original 12)**:
- `TaskCreated` -- fires when TaskCreate tool is used; has `task_id`, `task_subject`, `task_description`
- `TaskCompleted` -- fires when tasks marked complete; has `task_id`, `task_subject`, `task_status`
- `TeammateIdle` -- fires when a teammate agent goes idle; has `agent_type`, `idle_reason`
- `FileChanged` -- fires when watched files change; supports matcher on filename
- `CwdChanged` -- fires on working directory change
- `WorktreeCreate` / `WorktreeRemove` -- fires on git worktree operations

**Limitation**: `TaskCreated`/`TaskCompleted` require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and refer to Claude's internal task concept (not the user's specs/state.json task lifecycle). They would not reliably fire at researched/planned lifecycle transitions.

### 2. Signal Architecture Evaluation

#### Approach A: Signal File

**Mechanism**: Postflight scripts write a signal file (e.g., `specs/tmp/tts-lifecycle-signal`). Stop hook checks for it, fires TTS only if present, then consumes the file.

```bash
# In update-task-status.sh (after successful postflight update):
echo "$STATE_STATUS" > specs/tmp/tts-lifecycle-signal

# In tts-notify.sh:
if [[ -f "specs/tmp/tts-lifecycle-signal" ]]; then
    STATUS=$(cat specs/tmp/tts-lifecycle-signal)
    rm -f specs/tmp/tts-lifecycle-signal
    # Speak "Tab N researched" / "Tab N completed" etc.
fi
```

| Aspect | Assessment |
|--------|------------|
| Pros | Minimal changes to existing hooks; works with current architecture; atomic file ops via rename; status value available for richer TTS messages |
| Cons | Race window between postflight writing signal and Stop hook reading it (though both run in same turn); orphaned signal files if Stop hook fails; requires cleanup logic |
| Race risk | LOW -- postflight scripts run inline within the skill, and the subsequent Stop event fires after the skill completes; the signal file will exist by the time the Stop hook reads it |
| Complexity | LOW -- 5-10 lines added to each script |

#### Approach B: Direct Invocation

**Mechanism**: Remove TTS from Stop hook entirely. Postflight scripts call `tts-notify.sh` directly with a lifecycle argument. Keep Notification hook for permission prompts.

```bash
# In update-task-status.sh (after successful postflight update):
bash .claude/hooks/tts-notify.sh --lifecycle "$STATE_STATUS" &

# tts-notify.sh modified to accept --lifecycle flag:
# When called with --lifecycle, always speak (bypass cooldown for lifecycle events)
# When called without --lifecycle (from Notification hook), speak as before
```

| Aspect | Assessment |
|--------|------------|
| Pros | Simplest mental model; no coordination files; direct causality (postflight -> TTS); can include lifecycle status in message ("Tab 3 researched") |
| Cons | Postflight scripts become notification-aware (minor coupling); must also handle Notification hook TTS separately; Stop hook no longer fires TTS at all (including for non-workflow stops) |
| Non-workflow stops | This is the key gap -- when a user asks a one-off question (no /research, /plan, /implement), the Stop event fires but no postflight runs. The user would get NO TTS notification for casual interactions. |
| Complexity | MEDIUM -- requires modifying tts-notify.sh to accept a --lifecycle flag, modifying update-task-status.sh, and keeping the Notification hook |

#### Approach C: State-Based (OSC 1337)

**Mechanism**: Postflight scripts set `CLAUDE_LIFECYCLE=researched` via OSC 1337. Stop hook reads this variable and fires TTS only when set, then clears it.

| Aspect | Assessment |
|--------|------------|
| Pros | Leverages existing WezTerm variable pattern; no temp files; enables visual state in tab title |
| Cons | **Fatal flaw**: OSC 1337 variables are per-pane state on WezTerm, not readable from hook scripts. Hooks cannot read pane user vars -- they can only write them. The `format-tab-title` Lua handler reads them, but bash hooks cannot query `pane:get_user_vars()`. Would require WezTerm CLI support for reading user vars, which does not exist. |
| Verdict | **NOT VIABLE** as primary notification gate. However, setting a lifecycle user var for visual tab state IS valuable as a secondary enhancement. |

#### Approach D: Unified Notification Dispatcher

**Mechanism**: Single `notify-dispatch.sh` that centralizes all notification decisions. Called from hooks and postflight with event type argument.

```bash
# From Stop hook:
bash .claude/hooks/notify-dispatch.sh stop

# From postflight:
bash .claude/hooks/notify-dispatch.sh lifecycle researched

# From Notification hook:
bash .claude/hooks/notify-dispatch.sh notification permission_prompt
```

| Aspect | Assessment |
|--------|------------|
| Pros | Single source of truth for all notification logic; extensible; clean separation of routing from delivery |
| Cons | Over-engineered for current needs; requires creating new script and modifying all callers; introduces indirection that makes debugging harder; the existing tts-notify.sh already handles all delivery logic |
| Verdict | Good long-term architecture but premature for a system with only TTS + WezTerm visual as notification channels. The benefit over Approach B is marginal. |

### 3. Recommended Approach: B+A Hybrid

**Primary: Direct Invocation (B) for lifecycle notifications**
- Postflight scripts (specifically `update-task-status.sh`) call TTS directly after successful status update
- The TTS message includes lifecycle context: "Tab 3 researched", "Tab 3 completed"

**Secondary: Signal file (A) for Stop hook awareness**
- `update-task-status.sh` also writes a signal file after postflight status update
- Stop hook checks for signal file. If present: suppress TTS (postflight already handled it). If absent: fire TTS as normal (this handles non-workflow stops like one-off questions)

**Keep unchanged**:
- Notification hook continues calling tts-notify.sh for permission_prompt/idle_prompt/elicitation_dialog
- Stop hook continues calling wezterm-notify.sh for visual tab state (CLAUDE_STATUS=needs_input)

**Signal flow**:

```
Workflow command (/research N):
  1. Orchestrator runs, intermediate stops -> Stop hook sees no signal file
     -> BUT agent_id suppression already silences subagent stops
     -> Intermediate orchestrator stops will still fire (reduced by cooldown)
  2. Skill postflight: update-task-status.sh postflight -> writes signal file
     -> Directly calls tts-notify.sh --lifecycle "researched"
  3. Final Stop event -> Stop hook sees signal file -> consumes it, skips TTS
     -> wezterm-notify.sh still sets CLAUDE_STATUS=needs_input (visual)

Non-workflow command (one-off question):
  1. Claude responds -> Stop hook sees no signal file -> fires TTS normally ("Tab N")
```

**Why this hybrid works better than pure B**:
- Pure B would require removing TTS from the Stop hook entirely, losing non-workflow notifications
- The signal file lets the Stop hook know "a lifecycle TTS already fired this turn, skip"
- This is the same pattern as a "debounce" -- the signal file prevents double-notification

### 4. Notification UX Best Practices

**From agentic AI UX research (2026)**:
- **Interrupt only for irreversible actions or user-required decisions** -- aligns with the lifecycle-only approach
- **Intent Preview pattern** -- show what the agent plans to do before acting; notifications should convey actionable state
- **Interruptibility** -- users should be able to pause/resume without losing state
- **Async notification** -- for multi-agent systems, notify on completion, not on intermediate steps

**How other tools handle it**:
- **Cursor**: Built-in sound notification when chat completes (simple beep, no lifecycle awareness); also supports MCP-based Sound Notification server
- **Windsurf**: Similar MCP-based sound notification; fires on completion or when approval needed
- **Aider**: Terminal bell on completion; no lifecycle-aware filtering
- None of these tools have multi-tab lifecycle-aware notification -- this is a novel pattern specific to the user's multi-tab WezTerm + Claude Code workflow.

### 5. WezTerm Multi-State Indicators

**Current state**: `CLAUDE_STATUS` carries only `"needs_input"` or empty.

**Extension potential**: `CLAUDE_STATUS` can carry any base64-encoded string. The `format-tab-title` handler currently checks for exact string match `"needs_input"`. It can be extended to support richer states:

```lua
-- In format-tab-title handler:
local status = active_pane.user_vars.CLAUDE_STATUS
if status == "needs_input" then
  background = "#3a3a3a"  -- gray (current behavior)
elseif status == "researched" then
  background = "#2a4a2a"  -- dark green
elseif status == "planned" then
  background = "#2a2a5a"  -- dark blue
elseif status == "completed" then
  background = "#1a5a1a"  -- bright green
elseif status == "blocked" then
  background = "#5a2a2a"  -- dark red
end
```

**Implementation**: The postflight TTS call can simultaneously set `CLAUDE_STATUS` to the lifecycle state (instead of generic "needs_input"), providing both audio AND visual notification of what completed. The existing `update-status` handler in wezterm.lua already clears the variable on tab switch.

**Risk**: Changing `CLAUDE_STATUS` values requires updating the wezterm.lua handler. If the handler only checks for `"needs_input"`, new values would be silently ignored (safe degradation).

## Decisions

1. **Approach B+A Hybrid** is recommended for implementation
2. **Approach C (OSC 1337 reading)** is not viable as primary gate but valuable for visual enhancement
3. **Approach D (dispatcher)** is deferred as premature optimization
4. The existing `memory-nudge.sh` pattern-matching approach is proven and can be used as a fallback in the Stop hook, but the signal file approach is cleaner
5. WezTerm multi-state indicators should be implemented as a secondary enhancement in task 559

## Recommendations

### Implementation Plan (for tasks 558 and 559)

**Task 558: Core lifecycle-gated TTS** (3 files modified, 1 pattern):

1. **Modify `update-task-status.sh`**: After successful postflight status update, add:
   - Write signal file: `echo "$STATE_STATUS" > specs/tmp/tts-lifecycle-signal`
   - Direct TTS call: `bash .claude/hooks/tts-notify.sh --lifecycle "$STATE_STATUS" &`

2. **Modify `tts-notify.sh`**: Add `--lifecycle` flag support:
   - When `--lifecycle STATUS` is passed: speak "Tab N STATUS" (e.g., "Tab 3 researched"), bypass cooldown, skip stdin JSON parsing
   - When called from Stop hook (no --lifecycle): check for signal file. If present, consume it and skip TTS. If absent, fire TTS as normal.

3. **Keep settings.json unchanged**: Stop hook still calls tts-notify.sh (for non-workflow stops). Notification hook still calls tts-notify.sh (for permissions).

**Task 559: WezTerm multi-state visual indicators** (2 files modified):

1. **Modify `wezterm-notify.sh`** (or create `wezterm-lifecycle-notify.sh`): Accept lifecycle state parameter, set `CLAUDE_STATUS` to lifecycle value instead of "needs_input"
2. **Modify `wezterm.lua`**: Extend `format-tab-title` to color-code by lifecycle state

### Signal File Cleanup

- Signal file lives at `specs/tmp/tts-lifecycle-signal` (already in gitignored tmp dir)
- Consumed (deleted) by Stop hook after reading
- Stale files cleaned up by `tts-notify.sh` on read (if file is older than 60 seconds, delete and ignore)
- No race condition risk: postflight writes synchronously before the Stop event fires

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Signal file not consumed (Stop hook fails) | Low | Stale file, next non-workflow stop skips TTS | Add age check: ignore signal files older than 60s |
| Postflight TTS + Stop hook TTS double-fire | Medium | Duplicate announcement | Signal file consumption prevents this; also covered by cooldown |
| Non-workflow stops lose TTS after changes | Low | User misses one-off question completion | Stop hook fallback path preserves non-workflow TTS |
| WezTerm format-tab-title breaks with new CLAUDE_STATUS values | Low | Tab coloring reverts to default | New values are unknown strings; handler falls through to default styling (safe degradation) |
| `update-task-status.sh` TTS call blocks script | Low | Slow postflight | Use `&` for background execution; `tts-notify.sh` already handles its own timeouts |

## Appendix

### Search Queries Used
- "Claude Code hooks 2026 Stop hook stdin JSON data event model documentation"
- "Claude Code hooks Stop event stdin JSON fields schema agent_id hook_event_name 2026"
- "WezTerm OSC 1337 user variables format-tab-title multiple states color coding"
- "developer tool notification UX patterns agent coding assistant when to interrupt user 2026"
- "Cursor Windsurf Aider notification system sound alert task completion"
- "Claude Code hooks lifecycle state change event notification filtering best practices"
- "Claude Code TaskCompleted TaskCreated hook event 2026"
- "signal file approach bash race condition atomic filesystem coordination"

### References
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Hook Schemas (Gist)](https://gist.github.com/FrancisBourre/50dca37124ecc43eaf08328cdcccdb34)
- [Claude Code Hooks: Complete Guide to All 12 Lifecycle Events](https://claudefa.st/blog/tools/hooks/hooks-guide)
- [WezTerm: Passing Data from Panes to Lua](https://wezterm.org/recipes/passing-data.html)
- [WezTerm: Shell Integration](https://wezterm.org/shell-integration.html)
- [Designing for Agentic AI: Practical UX Patterns (Smashing Magazine)](https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/)
- [4 UX Design Principles for Multi-Agent AI Systems](https://newsletter.victordibia.com/p/4-ux-design-principles-for-multi)
- [Cursor Agent Notifier (GitHub)](https://github.com/hgbdev/cursor-agent-notifier)
- [Sound Notification MCP](https://mcpmarket.com/zh/server/sound-notification)
- [Atomic File Creation with Temporary Files](https://linuxvox.com/blog/atomic-create-file-if-not-exists-from-bash-script/)
- [Claude Code Hooks - Missing TeammateIdle/TaskCompleted docs (Issue #23545)](https://github.com/anthropics/claude-code/issues/23545)
