# Research Report: Task #107

**Task**: 107 - port_tts_notification_hooks
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (nvim/.claude/, ProofChecker/.claude/), Claude Code hooks documentation (https://code.claude.com/docs/en/hooks)
**Artifacts**: specs/107_port_tts_notification_hooks/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- **TTS functionality already exists identically in both projects.** The `tts-notify.sh` hook in `nvim/.claude/hooks/` is byte-for-byte identical to the ProofChecker version. No porting is needed.
- **The `Notification` hook event is available** in Claude Code for extending TTS triggers beyond the `Stop` event to include input-needed events (permission prompts, idle prompts, elicitation dialogs).
- **The actual work is extending triggers** to the `Notification` hook event (with matchers for `permission_prompt`, `idle_prompt`, `elicitation_dialog`) and updating documentation.
- **A standalone `tts-stt-integration.md` guide exists in ProofChecker** but is missing from nvim/.claude/docs/. This should be ported.

## Context and Scope

The task description asks to "Port TTS functionality from ProofChecker/.claude/ to nvim/.claude/". Research focused on:

1. Whether TTS already exists in nvim/.claude/
2. What differences exist between the two implementations
3. What the `Notification` hook event provides for extending triggers
4. What documentation gaps exist

## Findings

### 1. TTS Implementation Comparison

**Result: Implementations are identical.**

Both projects have:
- `.claude/hooks/tts-notify.sh` - Identical (confirmed via `diff`, zero differences)
- `.claude/settings.json` - Identical hook configuration
- `.claude/hooks/wezterm-notify.sh` - Visual notification (amber tab highlight)
- `.claude/hooks/wezterm-clear-status.sh` - Clear notification on user prompt
- `.claude/hooks/wezterm-task-number.sh` - Task number in tab title

All 10 hook files in both directories are identical in content (sizes match, diff produces no output).

**Current hook registration in settings.json:**

| Hook Event | Scripts | Purpose |
|-----------|---------|---------|
| `Stop` | `post-command.sh`, `tts-notify.sh`, `wezterm-notify.sh` | TTS + visual notification on completion |
| `UserPromptSubmit` | `wezterm-task-number.sh`, `wezterm-clear-status.sh` | Tab title + clear notification |
| `SessionStart` | `wezterm-clear-task-number.sh`, `log-session.sh`, `claude-ready-signal.sh` | Initialize session |
| `SubagentStop` | `subagent-postflight.sh` | Subagent cleanup |

### 2. Claude Code Notification Hook Event

The `Notification` hook event fires when Claude Code sends notifications. It supports matchers for filtering by notification type:

| Notification Type | When It Fires | Relevance to TTS |
|------------------|---------------|-------------------|
| `permission_prompt` | When Claude needs permission to use a tool | HIGH - user input needed |
| `idle_prompt` | When Claude has been idle | HIGH - user attention needed |
| `elicitation_dialog` | When Claude asks a question via AskUserQuestion | HIGH - user input needed |
| `auth_success` | When authentication succeeds | LOW - informational only |

**Notification hook input schema:**
```json
{
  "session_id": "abc123",
  "transcript_path": "...",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "Notification",
  "message": "Claude needs your permission to use Bash",
  "title": "Permission needed",
  "notification_type": "permission_prompt"
}
```

**Key constraint:** Notification hooks cannot block or modify notifications. They are side-effect only (like logging or audio). This is perfect for TTS use.

### 3. Documentation Gap Analysis

**ProofChecker has but nvim lacks:**
- `.claude/docs/guides/tts-stt-integration.md` - Comprehensive 306-line guide covering:
  - NixOS package requirements (piper-tts, espeak-ng, alsa-utils, vosk, pulseaudio, jq, wezterm)
  - Piper voice model download instructions
  - Vosk speech model download instructions
  - TTS configuration (environment variables, toggling)
  - STT plugin configuration
  - Troubleshooting for both TTS and STT
  - Workflow examples combining both features
  - Technical details (audio format, file locations, model sizes)

**nvim has partial coverage in:**
- `.claude/docs/guides/neovim-integration.md` - Documents TTS in ~40 lines as part of a larger guide
- `.claude/context/project/hooks/wezterm-integration.md` - Documents WezTerm visual notification system

### 4. Current Trigger Behavior

Currently, TTS only fires on the `Stop` hook (when Claude finishes responding). The cooldown is **10 seconds** in the script default (`TTS_COOLDOWN="${TTS_COOLDOWN:-10}"`), while the documentation references 60 seconds.

The `Stop` hook does NOT fire when:
- Claude is waiting for user input (permission prompt)
- Claude is asking a question (elicitation dialog / AskUserQuestion)
- Claude is idle

These are exactly the scenarios where TTS would be most valuable -- the user has context-switched away and needs to know Claude needs attention.

### 5. Software Dependencies

From the ProofChecker `tts-stt-integration.md` and the script itself:

**TTS Dependencies:**
| Package | Purpose | NixOS Package |
|---------|---------|---------------|
| piper-tts | Neural TTS engine | `piper-tts` |
| espeak-ng | Phonemization backend for Piper | `espeak-ng` |
| aplay | ALSA audio playback | `alsa-utils` |
| paplay | PulseAudio audio playback (preferred) | `pulseaudio` |
| jq | JSON parsing for WezTerm tab detection | `jq` |
| wezterm | Terminal emulator with tab detection | `wezterm` |

**Voice Model:**
- Path: `~/.local/share/piper/en_US-lessac-medium.onnx` (~45 MB)
- Source: https://huggingface.co/rhasspy/piper-voices

### 6. Existing WezTerm Tab Number Detection

Both `tts-notify.sh` and `wezterm-integration.md` document a global tab numbering system that ensures TTS announcements match tab bar numbers. This uses `wezterm cli list --format=json` to get all panes, then computes the tab's global position across all windows.

## Recommendations

### Approach: Extend, Don't Port

Since the TTS implementation is already present and identical, the task should be reframed as:

1. **Add `Notification` hook entries** to `settings.json` for `permission_prompt`, `idle_prompt`, and `elicitation_dialog` events
2. **Create a notification-specific TTS script** (or modify `tts-notify.sh` to accept event context) that differentiates messages:
   - Stop: "Tab 3" (current behavior)
   - Permission prompt: "Tab 3 needs permission"
   - Idle/elicitation: "Tab 3 needs input"
3. **Port `tts-stt-integration.md`** from ProofChecker to nvim/.claude/docs/guides/
4. **Update `neovim-integration.md`** to reference the new Notification triggers

### Implementation Design Options

**Option A: Single script, event detection via stdin JSON**

The Notification hook passes JSON on stdin with `notification_type` and `message` fields. A unified `tts-notify.sh` could read stdin to determine the event type and customize the message:

```bash
# Read hook input from stdin
INPUT=$(cat)
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "Stop"')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')

case "$NOTIFICATION_TYPE" in
  permission_prompt) MESSAGE="${TAB_LABEL}needs permission" ;;
  idle_prompt)       MESSAGE="${TAB_LABEL}needs input" ;;
  elicitation_dialog) MESSAGE="${TAB_LABEL}has a question" ;;
  *)                 MESSAGE="${TAB_LABEL}" ;;  # Stop event (current)
esac
```

**Option B: Separate scripts per trigger**

Create `tts-notify-permission.sh`, `tts-notify-input.sh` that wrap the core TTS logic with different messages. More files but simpler per-script logic.

**Recommendation: Option A** - avoids code duplication, leverages the JSON input already available.

### Settings.json Changes

Add to `settings.json`:
```json
"Notification": [
  {
    "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
]
```

### Cooldown Consideration

The current 10-second cooldown (script default) needs review. With multiple trigger events, rapid-fire notifications are more likely. Consider:
- Keeping 10s cooldown for all events (current default)
- Making cooldown per-event-type if too aggressive
- The cooldown file `/tmp/claude-tts-last-notify` is shared across all events, which prevents spam

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Notification hook not available in older Claude Code versions | Low | Medium | Graceful fallback: hook simply won't fire if event doesn't exist |
| TTS spam from rapid permission prompts | Medium | Low | Existing cooldown mechanism (10s) handles this |
| stdin reading breaks existing Stop hook behavior | Low | High | The Stop hook currently ignores stdin; adding stdin reading must be backward-compatible |
| Documentation divergence between projects | Medium | Low | Note that nvim/.claude/ is the canonical source |

## Decisions

- **No porting needed**: The TTS code is already present and identical
- **Extend triggers**: Use `Notification` hook event with type matchers
- **Single script approach**: Modify `tts-notify.sh` to read stdin for event context
- **Port documentation**: Copy and adapt `tts-stt-integration.md` from ProofChecker

## Appendix

### Search Queries Used

1. `grep -ri "tts|text.to.speech|espeak|speech|say|notification.*sound" .claude/` - nvim codebase
2. `grep -ri "tts|piper|espeak|text.to.speech" /home/benjamin/Projects/ProofChecker/.claude/` - ProofChecker codebase
3. `diff -r .claude/hooks/ /home/benjamin/Projects/ProofChecker/.claude/hooks/` - Full comparison
4. Claude Code hooks documentation: https://code.claude.com/docs/en/hooks - Notification event reference

### References

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) - Official hook event documentation
- [Piper TTS](https://github.com/rhasspy/piper) - Neural TTS engine
- ProofChecker `.claude/docs/guides/tts-stt-integration.md` - Comprehensive TTS/STT guide
- nvim `.claude/docs/guides/neovim-integration.md` - Existing partial TTS documentation
- nvim `.claude/context/project/hooks/wezterm-integration.md` - WezTerm integration context
