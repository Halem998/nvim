# Research Report: Task OC_196 - Supplementary Analysis

**Task**: OC_196 - port_wezterm_tab_integration_from_claude_to_opencode
**Date**: 2026-03-13
**Focus**: TTS constraint analysis and best practices review

## Executive Summary

Analysis confirms that the existing .claude/ TTS implementation correctly matches the user's constraint. The implementation plan for .opencode/ is sound but can be **improved with focus detection** to prevent unnecessary TTS when the terminal is already focused (user is actively watching).

**User's Constraint**: TTS alerts ONLY when:
1. Claude finishes responding (Stop hook)
2. Claude needs input (permission_prompt, idle_prompt)
3. Claude has a question in interactive mode (elicitation_dialog)

**Current .claude/ Status**: Already implements this correctly via Stop and Notification hooks.

**Recommendation for .opencode/**: Port the hooks as planned, optionally add focus detection.

## Constraint Validation

### Current .claude/settings.json Implementation

| Hook Event | Matcher | TTS Trigger | User Want |
|------------|---------|-------------|-----------|
| Stop | `*` | Claude finished | Finishes |
| Notification | `permission_prompt` | Permission needed | Needs input |
| Notification | `idle_prompt` | Idle > 60 seconds | Needs input |
| Notification | `elicitation_dialog` | MCP question dialog | Question in interactive mode |

**Verdict**: The current .claude/ implementation exactly matches the user's constraint. No changes needed to .claude/.

### .opencode/ Gap Analysis

The .opencode/ system is MISSING:
- Notification hook entirely (no TTS on permission/idle/elicitation)

The existing plan correctly addresses this gap.

## Web Research Findings

### OpenCode Plugin Architecture (Alternative Approach)

From the OpenCode documentation and community plugins:

1. **Plugin-Based Approach**: OpenCode supports JavaScript/TypeScript plugins that can hook into events like:
   - `complete` - Generation completed
   - `question` - Question tool invoked
   - `session.idle` - Session idle
   - `subagent_complete` - Subagent finished

2. **opencode-notifier Plugin**: Community plugin providing desktop notifications and sounds for:
   - Permission needed
   - Generation complete
   - Errors
   - Question tool invoked

3. **opencode-smart-voice-notify**: Advanced TTS plugin with multiple engine support (ElevenLabs, Edge TTS, Windows SAPI, OpenAI-compatible).

**Recommendation**: For this task, continue with shell-based hooks (already implemented) for consistency with .claude/. Plugin-based approach is an enhancement for future consideration.

### Best Practice: Focus Detection

From the "smart-voice-notify" plugin documentation:

> "TTS reminders are never suppressed, even when focused, since users may step away after seeing the toast. Focus detection suppresses sound and desktop notifications when the terminal is focused."

**Key Insight**: TTS should only fire when the terminal is NOT focused, since the user can already see Claude waiting.

**Implementation Options**:
1. **wezterm cli get-current-pane** - Check if current pane is focused
2. **Check WEZTERM_PANE against active pane** - Compare current pane to focused pane
3. **$TERM_PROGRAM + window focus detection** - OS-level focus detection

### Best Practice: Cooldown Mechanism

The existing tts-notify.sh implements a 10-second cooldown (`TTS_COOLDOWN=10`). This prevents notification spam when multiple events fire in quick succession.

**Current Implementation**: Already correct.

## Plan Review and Improvements

### Original Plan Assessment

| Phase | Description | Assessment |
|-------|-------------|------------|
| Phase 1 | Add Notification Hook | Correct - addresses missing TTS trigger |
| Phase 2 | Add claude-ready-signal | Correct - but NOT TTS related |
| Phase 3 | Documentation Update | Correct - ensures consistency |

### Recommended Improvements

#### Improvement 1: Focus Detection (Optional Enhancement)

Add focus detection to tts-notify.sh to suppress TTS when terminal is focused:

```bash
# Check if WezTerm pane is focused (add to tts-notify.sh)
is_pane_focused() {
    if [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm &>/dev/null; then
        FOCUSED_PANE=$(wezterm cli list --format=json 2>/dev/null | \
            jq -r '.[] | select(.is_active == true) | .pane_id' 2>/dev/null)
        [[ "$WEZTERM_PANE" == "$FOCUSED_PANE" ]]
    else
        return 1  # Assume not focused if can't determine
    fi
}

# Skip TTS if pane is focused
if is_pane_focused; then
    log "Pane is focused - skipping TTS notification"
    exit_success
fi
```

**Impact**: Prevents TTS from firing when user is actively watching the terminal.

**Trade-off**: Users who step away after seeing a toast won't get TTS. However, idle_prompt fires after 60 seconds, which would catch this case.

#### Improvement 2: Differentiated Messages (Optional)

Currently all events say "Tab N". Could differentiate:

| Event | Current Message | Enhanced Message |
|-------|-----------------|------------------|
| Stop | "Tab N" | "Tab N done" |
| permission_prompt | "Tab N" | "Tab N permission" |
| idle_prompt | "Tab N" | "Tab N waiting" |
| elicitation_dialog | "Tab N" | "Tab N question" |

**Impact**: User knows what to expect before switching tabs.

**Implementation**: Add to tts-notify.sh:

```bash
case "$NOTIFICATION_TYPE" in
    permission_prompt) SUFFIX="permission" ;;
    idle_prompt) SUFFIX="waiting" ;;
    elicitation_dialog) SUFFIX="question" ;;
    *) SUFFIX="" ;;
esac

# For Stop hook (no notification_type)
if [[ "$HOOK_EVENT_NAME" == "Stop" ]] || [[ -z "$NOTIFICATION_TYPE" ]]; then
    SUFFIX="done"
fi

MESSAGE="$TAB_PREFIX${SUFFIX:+ $SUFFIX}"
```

### Revised Plan Recommendation

Keep the original plan structure but add:

**Phase 1.5: Focus Detection Enhancement (Optional)**
- Add is_pane_focused() function to .opencode/hooks/tts-notify.sh
- Skip TTS if pane is focused
- This is optional and can be deferred

**No changes to Phase 2 or Phase 3** - they remain correct.

## Claude Code Hook Events Reference

From official documentation at code.claude.com/docs/en/hooks:

| Hook Event | When It Fires | TTS Appropriate |
|------------|---------------|-----------------|
| SessionStart | Session starts/resumes | No |
| Stop | Claude finished responding | Yes - "finishes" |
| Notification | Needs attention | Yes - based on type |
| UserPromptSubmit | User sends message | No |
| PreToolUse | Before tool execution | No |
| PostToolUse | After tool execution | No |
| SubagentStop | Subagent finishes | No (handled by Stop) |

### Notification Types Detail

| Type | Description | TTS in User Constraint |
|------|-------------|------------------------|
| permission_prompt | Tool permission request | Yes - "needs input" |
| idle_prompt | Waiting > 60 seconds | Yes - "needs input" |
| elicitation_dialog | MCP tool question | Yes - "question in interactive mode" |
| auth_success | Auth completed | No - not in constraint |

**Note**: auth_success is NOT included in the Notification matcher, which is correct per user's constraint.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Focus detection API changes | Low | Medium | Fallback to always-notify if detection fails |
| OpenCode doesn't support Notification hook | Medium | High | Test after implementation; graceful degradation |
| Cooldown too aggressive | Low | Low | Current 10s is reasonable; make configurable |

## Recommendations Summary

### Required (Per Original Plan)
1. Add Notification hook to .opencode/settings.json - **Keep as planned**
2. Add claude-ready-signal.sh to SessionStart - **Keep as planned**
3. Update documentation - **Keep as planned**

### Optional Enhancements (Future)
1. **Focus detection** - Suppress TTS when terminal is focused
2. **Differentiated messages** - Say what type of notification
3. **Plugin migration** - Consider OpenCode native plugins for better integration

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [OpenCode Plugins Documentation](https://opencode.ai/docs/plugins/)
- [opencode-smart-voice-notify Plugin](https://github.com/MasuRii/opencode-smart-voice-notify)
- [opencode-notifier Plugin](https://github.com/mohak34/opencode-notifier)
- [Claude Code Hooks Mastery Guide](https://github.com/disler/claude-code-hooks-mastery)
- [Claude Code Notification Hooks Setup](https://alexop.dev/posts/claude-code-notification-hooks/)

## Next Steps

1. Proceed with `/implement 196` using existing plan
2. Optionally add focus detection as Phase 1.5
3. Test Notification hook support in OpenCode environment
