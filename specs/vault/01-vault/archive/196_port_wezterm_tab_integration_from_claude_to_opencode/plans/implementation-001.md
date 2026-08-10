# Implementation Plan: Port Wezterm Tab Integration Features

- **Task**: OC_196 - port_wezterm_tab_integration_from_claude_to_opencode
- **Status**: [COMPLETED]
- **Effort**: 65 minutes
- **Dependencies**: None
- **Research Inputs**: specs/OC_196_port_wezterm_tab_integration_from_claude_to_opencode/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port the remaining wezterm tab integration features from `.claude/` to `.opencode/`. Research identified only two gaps that need addressing: (1) the Notification hook for TTS alerts on permission/idle prompts, and (2) the claude-ready-signal.sh in SessionStart to reduce Neovim sidebar initialization delay. All other wezterm integration scripts are already present and enhanced in `.opencode/`.

### Research Integration

Research report `research-001.md` identified:
- **Gap 1**: `.claude/settings.json` has a `Notification` hook (lines 127-136) that triggers TTS on `permission_prompt|idle_prompt|elicitation_dialog` events. This is completely missing from `.opencode/settings.json`.
- **Gap 2**: `.claude/settings.json` SessionStart includes `claude-ready-signal.sh` (line 76) which eliminates ~30 second Neovim sidebar delay. `.opencode/settings.json` SessionStart (lines 64-78) lacks this.
- The tts-notify.sh script already exists in `.opencode/hooks/` and is adapted for opencode paths.
- The claude-ready-signal.sh script exists at `~/.config/nvim/scripts/claude-ready-signal.sh` and works for both systems.

## Goals & Non-Goals

**Goals**:
- Add Notification hook to `.opencode/settings.json` for TTS notifications on permission/idle/elicitation events
- Add claude-ready-signal.sh invocation to `.opencode/settings.json` SessionStart hook
- Verify both changes work correctly
- Update documentation if needed

**Non-Goals**:
- Do not modify any hook scripts (already working)
- Do not modify `.claude/settings.json`
- Do not add new features beyond what's in `.claude/`
- Do not change existing hook ordering unless necessary

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Notification hook not supported by opencode | High | Medium | Test immediately after adding; if unsupported, document in plan and mark as known limitation |
| claude-ready-signal.sh path issues | Medium | Low | Verify script exists at `~/.config/nvim/scripts/claude-ready-signal.sh` before implementation |
| JSON syntax error in settings.json | High | Low | Validate JSON after each edit; use jq to verify syntax |
| Hook ordering conflicts | Low | Low | Maintain same order as `.claude/settings.json` for SessionStart entries |

## Implementation Phases

### Phase 1: Add Notification Hook [COMPLETED]

**Goal**: Add the Notification hook configuration to `.opencode/settings.json` for TTS alerts on permission prompts, idle prompts, and elicitation dialogs.

**Tasks**:
- [ ] Verify `.opencode/hooks/tts-notify.sh` exists and is executable
- [ ] Read current `.opencode/settings.json` to confirm structure
- [ ] Add `Notification` array to the `hooks` object (after `SubagentStop`)
- [ ] Configure matcher as `permission_prompt|idle_prompt|elicitation_dialog`
- [ ] Configure hook command as `bash .opencode/hooks/tts-notify.sh 2>/dev/null || echo '{}'``
- [ ] Validate JSON syntax with `jq`

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/settings.json` - Add Notification hook configuration (lines ~129-130 area)

**Verification**:
- [ ] JSON is valid: `jq . .opencode/settings.json > /dev/null && echo "Valid JSON"`
- [ ] Notification hook is present in hooks object
- [ ] Matcher pattern matches: `permission_prompt|idle_prompt|elicitation_dialog`
- [ ] Command path is correct: references `.opencode/hooks/tts-notify.sh`

---

### Phase 2: Add Claude-Ready Signal to SessionStart [COMPLETED]

**Goal**: Add claude-ready-signal.sh invocation to SessionStart hook to eliminate Neovim sidebar initialization delay.

**Tasks**:
- [ ] Verify `~/.config/nvim/scripts/claude-ready-signal.sh` exists
- [ ] Read current SessionStart configuration in `.opencode/settings.json`
- [ ] Add claude-ready-signal.sh hook to SessionStart with matcher `startup`
- [ ] Ensure proper ordering: after log-session.sh, before or alongside other startup hooks
- [ ] Configure command as `bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'``
- [ ] Validate JSON syntax with `jq`

**Timing**: 20 minutes

**Files to modify**:
- `.opencode/settings.json` - Add claude-ready-signal.sh to SessionStart hook (lines 64-78 area)

**Verification**:
- [ ] JSON is valid: `jq . .opencode/settings.json > /dev/null && echo "Valid JSON"`
- [ ] SessionStart contains the new hook
- [ ] Command path is correct: references `~/.config/nvim/scripts/claude-ready-signal.sh`
- [ ] Matcher is set to `startup`
- [ ] Timeout is appropriate (use default or match .claude/ pattern)

---

### Phase 3: Documentation Update and Final Verification [COMPLETED]

**Goal**: Update documentation to reflect the changes and perform final verification.

**Tasks**:
- [ ] Read `.opencode/docs/guides/tts-stt-integration.md` to check if Notification hook documentation exists
- [ ] Update documentation if the Notification hook was already documented but not implemented
- [ ] Create diff comparing `.claude/settings.json` and `.opencode/settings.json` hooks sections
- [ ] Verify all wezterm-related hooks are present in both configurations
- [ ] Document any differences or limitations

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/docs/guides/tts-stt-integration.md` - Update if needed (optional)

**Verification**:
- [ ] Diff shows Notification hook is now present in `.opencode/settings.json`
- [ ] Diff shows claude-ready-signal.sh is now present in SessionStart
- [ ] Documentation matches implementation (if updated)
- [ ] All changes are backward compatible

## Testing & Validation

- [ ] JSON syntax validation passes for `.opencode/settings.json`
- [ ] Notification hook configuration matches `.claude/settings.json` structure
- [ ] SessionStart hook includes claude-ready-signal.sh
- [ ] All hook paths reference existing scripts
- [ ] No duplicate hook entries created
- [ ] Hook execution order is logical and matches `.claude/` pattern

## Artifacts & Outputs

- `.opencode/settings.json` - Updated with Notification hook and claude-ready-signal.sh
- `.opencode/docs/guides/tts-stt-integration.md` - Updated if documentation was out of sync (optional)
- `specs/OC_196_port_wezterm_tab_integration_from_claude_to_opencode/plans/implementation-001.md` - This plan
- `specs/OC_196_port_wezterm_tab_integration_from_claude_to_opencode/summaries/` - Implementation summary (created during /implement)

## Rollback/Contingency

If implementation fails:

1. **Backup restoration**: The git history will contain the previous working version
2. **Manual rollback**: `git checkout .opencode/settings.json` to restore original
3. **Partial failure**: If only one phase fails, revert just those changes using git
4. **Notification hook unsupported**: Document as known limitation and remove the hook configuration

**Rollback command**:
```bash
git checkout .opencode/settings.json
```

## Notes

- The `.opencode/` version of wezterm integration is actually MORE advanced than `.claude/` in several areas (wezterm-task-number.sh sets TASK_NAME and TASK_ACTION)
- This implementation completes the feature parity between the two systems
- The claude-ready-signal.sh script is shared between both systems and works identically
- Consider verifying the Notification hook works by triggering a permission prompt during testing
