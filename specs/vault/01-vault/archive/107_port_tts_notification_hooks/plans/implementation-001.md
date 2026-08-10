# Implementation Plan: Task #107

- **Task**: 107 - port_tts_notification_hooks
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5-1 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-02
- **Feature**: Extend TTS triggers to Notification hook events and port documentation
- **Estimated Hours**: 0.5-1 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The TTS notification system (`tts-notify.sh`) is already present and identical in both nvim/.claude/ and ProofChecker/.claude/. No porting of the script itself is needed. The implementation extends TTS triggers from the current `Stop` event to also fire on `Notification` hook events (`permission_prompt`, `idle_prompt`, `elicitation_dialog`), enabling audio alerts when Claude needs user input. Additionally, the comprehensive `tts-stt-integration.md` documentation from ProofChecker is ported to nvim/.claude/docs/guides/.

### Research Integration

- TTS script is byte-for-byte identical across both projects (confirmed via diff)
- The `Notification` hook event provides JSON on stdin with `notification_type` and `message` fields
- The script currently ignores stdin, so adding stdin reading must be backward-compatible with the existing `Stop` hook (which also sends JSON on stdin)
- ProofChecker has a 305-line `tts-stt-integration.md` guide that is missing from nvim
- The existing cooldown mechanism (10s default) naturally prevents notification spam across event types

## Goals & Non-Goals

**Goals**:
- Add `Notification` hook entries to `settings.json` for input-needed events
- Modify `tts-notify.sh` to read stdin JSON and customize messages by event type
- Port `tts-stt-integration.md` documentation from ProofChecker
- Update documentation to reflect new Notification triggers

**Non-Goals**:
- Changing the TTS engine or voice model
- Modifying STT functionality
- Adding per-event-type cooldowns (shared cooldown is sufficient)
- Supporting non-WezTerm terminals

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| stdin reading breaks existing Stop hook behavior | H | L | Stop hook also sends JSON on stdin; the script will read it and fall through to default case |
| Notification hook not available in older Claude Code versions | M | L | Hook simply will not fire if event type does not exist; no error |
| TTS spam from rapid permission prompts | L | M | Existing 10-second cooldown applies across all event types |
| ProofChecker documentation references differ from nvim paths | L | M | Adapt file paths during port, verify all references |

## Implementation Phases

### Phase 1: Extend tts-notify.sh for Notification Events [COMPLETED]

**Goal**: Modify the TTS script to read stdin JSON, detect the hook event type, and customize the spoken message based on whether Claude stopped, needs permission, or has a question.

**Tasks**:
- [ ] Read stdin JSON at the start of the script (with timeout to avoid hanging if no stdin)
- [ ] Parse `hook_event_name` and `notification_type` fields using jq
- [ ] Add case statement to select message based on notification type:
  - `Stop` (or empty/default): "Tab N" (current behavior, unchanged)
  - `permission_prompt`: "Tab N needs permission"
  - `idle_prompt`: "Tab N needs input"
  - `elicitation_dialog`: "Tab N has a question"
- [ ] Ensure backward compatibility: if stdin is empty or not JSON, fall back to current behavior
- [ ] Update script header comments to document new Notification event support

**Timing**: 15-20 minutes

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Add stdin JSON parsing and message customization

**Verification**:
- Script still works correctly when called from Stop hook (no stdin parsing required, default behavior)
- Script reads notification_type from stdin JSON and produces correct message variants
- Script does not hang if stdin is empty (use timeout on read)
- `bash -c 'echo "{\"hook_event_name\":\"Notification\",\"notification_type\":\"permission_prompt\"}" | bash .claude/hooks/tts-notify.sh'` produces correct message in log

---

### Phase 2: Add Notification Hook to settings.json [COMPLETED]

**Goal**: Register the `Notification` hook event in settings.json so Claude Code triggers `tts-notify.sh` on input-needed events.

**Tasks**:
- [ ] Add `Notification` hook section to settings.json hooks object
- [ ] Use matcher pattern `permission_prompt|idle_prompt|elicitation_dialog` to filter relevant notification types
- [ ] Register `tts-notify.sh` as the hook command (same invocation pattern as Stop hook)
- [ ] Validate resulting JSON is well-formed

**Timing**: 5-10 minutes

**Files to modify**:
- `.claude/settings.json` - Add Notification hook entry

**Verification**:
- `python3 -m json.tool .claude/settings.json` succeeds (valid JSON)
- Notification hook section lists tts-notify.sh with correct matcher
- Existing hooks (Stop, UserPromptSubmit, SessionStart, SubagentStop, PreToolUse, PostToolUse) are unchanged

---

### Phase 3: Port and Update Documentation [COMPLETED]

**Goal**: Port the comprehensive TTS/STT integration guide from ProofChecker and update it for nvim-specific paths and the new Notification trigger events.

**Tasks**:
- [ ] Copy `tts-stt-integration.md` from ProofChecker to `.claude/docs/guides/tts-stt-integration.md`
- [ ] Update file path references from ProofChecker context to nvim context
- [ ] Add section documenting new Notification triggers (event types, message variants, when they fire)
- [ ] Correct cooldown documentation (script default is 10s, not 60s as stated in ProofChecker doc)
- [ ] Update the "How It Works" section to mention Notification events alongside Stop events
- [ ] Add Notification events to the workflow examples section
- [ ] Update `.claude/docs/guides/neovim-integration.md` to cross-reference the full TTS/STT guide
- [ ] Document software dependencies table (piper-tts, espeak-ng, alsa-utils, pulseaudio, jq, wezterm)

**Timing**: 15-20 minutes

**Files to modify**:
- `.claude/docs/guides/tts-stt-integration.md` - New file (ported and updated from ProofChecker)
- `.claude/docs/guides/neovim-integration.md` - Add cross-reference to full TTS/STT guide

**Verification**:
- `tts-stt-integration.md` exists and documents all Notification trigger types
- Cooldown value matches script default (10 seconds)
- All file path references point to nvim/.claude/ locations (no ProofChecker paths)
- `neovim-integration.md` links to the new guide
- Software dependencies are documented with NixOS package names

---

## Testing & Validation

- [ ] `bash -n .claude/hooks/tts-notify.sh` passes (no syntax errors)
- [ ] `python3 -m json.tool .claude/settings.json` passes (valid JSON)
- [ ] Script handles empty stdin gracefully (no hang, falls back to default "Tab N" message)
- [ ] Script handles Stop hook JSON on stdin (produces default "Tab N" message)
- [ ] Script handles Notification JSON with permission_prompt type (produces "Tab N needs permission")
- [ ] Script handles Notification JSON with elicitation_dialog type (produces "Tab N has a question")
- [ ] Documentation has no broken internal links
- [ ] All file paths in documentation reference nvim/.claude/ locations

## Artifacts & Outputs

- Modified `.claude/hooks/tts-notify.sh` with Notification event support
- Modified `.claude/settings.json` with Notification hook registration
- New `.claude/docs/guides/tts-stt-integration.md` (ported and updated)
- Updated `.claude/docs/guides/neovim-integration.md` with cross-reference

## Rollback/Contingency

To revert all changes:
1. `git checkout -- .claude/hooks/tts-notify.sh` - restore original script
2. `git checkout -- .claude/settings.json` - restore original hooks config
3. `git rm .claude/docs/guides/tts-stt-integration.md` - remove ported doc
4. `git checkout -- .claude/docs/guides/neovim-integration.md` - restore original doc

The Notification hook is side-effect only and cannot break existing functionality. If the hook fires but the script fails, it exits with `echo '{}'` which Claude Code treats as success.
