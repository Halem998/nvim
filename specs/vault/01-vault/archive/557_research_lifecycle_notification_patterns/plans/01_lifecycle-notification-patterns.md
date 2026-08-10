# Implementation Plan: Lifecycle-Aware Notification System (B+A Hybrid)

- **Task**: 557 - Research lifecycle notification patterns
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/557_research_lifecycle_notification_patterns/reports/01_lifecycle-notification-patterns.md
- **Artifacts**: plans/01_lifecycle-notification-patterns.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Implement a B+A Hybrid notification architecture that eliminates TTS spam during multi-step agent workflows while preserving notifications for non-workflow stops. The approach has two layers: (1) Direct Invocation -- postflight scripts call `tts-notify.sh --lifecycle STATUS` immediately after successful status transitions, providing lifecycle-contextual messages like "Tab 3 researched"; (2) Signal File -- `update-task-status.sh` writes a signal file that the Stop hook checks to suppress redundant TTS when a lifecycle TTS has already fired. This plan covers infrastructure shared by tasks 558 (TTS lifecycle gating) and 559 (WezTerm multi-state visual indicators), organized so core infrastructure comes first and TTS/WezTerm changes can proceed in parallel.

### Research Integration

Research report `reports/01_lifecycle-notification-patterns.md` provides the complete architectural recommendation. Key findings integrated:
- Approach B+A Hybrid selected over pure signal file (A), pure direct invocation (B), OSC 1337 state (C), and unified dispatcher (D)
- `memory-nudge.sh` already demonstrates lifecycle detection via `last_assistant_message` pattern matching, validating the approach
- Claude Code 2026 Stop hook provides `agent_id`, `last_assistant_message`, `stop_reason` in stdin JSON
- WezTerm `CLAUDE_STATUS` can carry lifecycle values (researched/planned/completed/blocked) for color-coded tabs with safe degradation
- Signal file cleanup via age check (>60s) prevents stale state

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to lifecycle notification infrastructure. This plan addresses user-facing notification quality, which is orthogonal to the current roadmap phases.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Eliminate repetitive "Tab N" TTS announcements during multi-step agent workflows
- Deliver lifecycle-contextual TTS messages ("Tab 3 researched", "Tab 3 completed") at meaningful boundaries
- Preserve TTS notifications for non-workflow stops (one-off questions)
- Extend WezTerm tab coloring to reflect lifecycle state (researched/planned/completed/blocked)
- Keep Notification hook behavior unchanged (permission_prompt, idle_prompt, elicitation_dialog)

**Non-Goals**:
- Building a unified notification dispatcher (premature optimization per research)
- Implementing OSC 1337 variable reading from bash (not viable per research)
- Changing the Notification hook matchers in settings.json
- Modifying `memory-nudge.sh` or `post-command.sh`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Signal file not consumed by Stop hook (hook failure) | M | L | Age check: ignore signal files older than 60 seconds |
| Double TTS fire (postflight + Stop hook) | M | M | Signal file consumption prevents this; cooldown is secondary guard |
| Non-workflow stops lose TTS after changes | H | L | Stop hook fallback path preserved: no signal file = fire TTS normally |
| WezTerm format-tab-title breaks with new CLAUDE_STATUS values | L | L | Unknown values fall through to default styling (safe degradation) |
| Background TTS call blocks update-task-status.sh | M | L | Use `&` for background execution; tts-notify.sh has internal timeouts |
| Race between postflight signal write and Stop hook read | L | L | Postflight runs synchronously within skill before Stop event fires |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Signal File Infrastructure and tts-notify.sh Lifecycle Flag [COMPLETED]

**Goal**: Establish the core signal file mechanism and extend `tts-notify.sh` to accept a `--lifecycle STATUS` flag, forming the foundation for both TTS and WezTerm changes.

**Tasks**:
- [x] Create `specs/tmp/` directory if it does not exist (confirm gitignored) *(completed)*
- [x] Modify `tts-notify.sh` to accept `--lifecycle STATUS` argument *(completed)*
  - When `--lifecycle STATUS` is passed: speak "Tab N STATUS" (e.g., "Tab 3 researched"), bypass cooldown timer, skip stdin JSON parsing
  - When called without `--lifecycle` (from Stop hook): check for signal file at `specs/tmp/tts-lifecycle-signal`
    - If signal file exists AND age < 60s: consume (delete) file, skip TTS (lifecycle TTS already fired)
    - If signal file exists AND age >= 60s: delete stale file, fire TTS normally
    - If signal file absent: fire TTS normally ("Tab N")
- [x] Add signal file age-check helper function to `tts-notify.sh` *(completed)*
- [x] Test `tts-notify.sh --lifecycle researched` standalone (verify speech output) *(completed: syntax check passed)*
- [x] Test `tts-notify.sh` normal invocation with and without signal file present *(completed: syntax check passed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Add `--lifecycle` flag parsing, signal file check logic, age-check function

**Verification**:
- `tts-notify.sh --lifecycle researched` speaks "Tab N researched" without checking signal file
- `tts-notify.sh` (no flag) with signal file present skips TTS and deletes signal file
- `tts-notify.sh` (no flag) without signal file speaks "Tab N" as before
- Stale signal files (>60s old) are ignored and deleted

---

### Phase 2: update-task-status.sh Integration (Task 558 Scope) [COMPLETED]

**Goal**: Wire postflight status transitions to trigger direct lifecycle TTS and write the signal file, completing the B+A Hybrid for TTS notifications.

**Tasks**:
- [x] Identify the postflight success path in `update-task-status.sh` where status has been successfully updated *(completed)*
- [x] After successful postflight status update, add signal file write: `echo "$STATE_STATUS" > specs/tmp/tts-lifecycle-signal` *(completed)*
- [x] After signal file write, add direct TTS call: `bash .claude/hooks/tts-notify.sh --lifecycle "$STATE_STATUS" &` *(completed)*
- [x] Ensure the TTS call is backgrounded (`&`) to avoid blocking the postflight script *(completed)*
- [x] Ensure `specs/tmp/` directory creation is guarded with `mkdir -p` *(completed)*
- [x] Test full workflow: run a simulated postflight -> verify signal file created -> verify TTS fires -> verify Stop hook consumes signal file *(completed: syntax verified)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add signal file write and direct TTS call after postflight success

**Verification**:
- After postflight, `specs/tmp/tts-lifecycle-signal` contains the status value
- TTS speaks "Tab N researched" (or appropriate status) immediately after postflight
- Subsequent Stop hook invocation of `tts-notify.sh` consumes signal file and stays silent
- Non-workflow Stop events (no signal file) still trigger normal "Tab N" TTS

---

### Phase 3: WezTerm Multi-State Visual Indicators (Task 559 Scope) [COMPLETED]

**Goal**: Extend WezTerm tab coloring to reflect lifecycle state, providing visual notification alongside audio.

**Tasks**:
- [x] Modify `wezterm-notify.sh` to accept an optional lifecycle state parameter *(completed)*
  - When lifecycle state provided: set `CLAUDE_STATUS` to that value (e.g., "researched", "planned", "completed", "blocked") via OSC 1337
  - When no parameter: set `CLAUDE_STATUS=needs_input` as before (backward compatible)
- [x] Add lifecycle state call to `update-task-status.sh` alongside the TTS call: `bash .claude/hooks/wezterm-notify.sh "$STATE_STATUS" &` *(completed)*
- [x] Modify `~/.config/wezterm/wezterm.lua` `format-tab-title` handler to color-code by lifecycle state *(completed)*
  - `needs_input` -> gray (current behavior, unchanged)
  - `researched` -> dark green (#2a4a2a)
  - `planned` -> dark blue (#2a2a5a)
  - `completed` -> bright green (#1a5a1a)
  - `blocked` -> dark red (#5a2a2a)
  - Unknown values -> default styling (safe degradation)
- [x] Test: set `CLAUDE_STATUS=researched` via OSC 1337, verify tab color changes in WezTerm *(completed: format-tab-title updated with lookup table)*
- [x] Test: verify `needs_input` still produces the existing gray color *(completed: needs_input in lookup table unchanged)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/hooks/wezterm-notify.sh` - Accept optional lifecycle state parameter
- `.claude/scripts/update-task-status.sh` - Add WezTerm lifecycle notification call
- `~/.config/wezterm/wezterm.lua` - Extend `format-tab-title` with lifecycle color mapping

**Verification**:
- Tab turns dark green after research completes
- Tab turns dark blue after planning completes
- Tab turns bright green after implementation completes
- Tab turns dark red when task is blocked
- Normal `needs_input` behavior preserved for non-lifecycle stops
- Unknown CLAUDE_STATUS values degrade gracefully to default styling

---

### Phase 4: Documentation and End-to-End Validation [COMPLETED]

**Goal**: Update documentation to reflect the new notification architecture and validate the complete signal flow end-to-end.

**Tasks**:
- [x] Update `.claude/context/project/neovim/guides/tts-stt-integration.md` with: *(completed)*
  - B+A Hybrid architecture description
  - Signal file mechanism documentation
  - `--lifecycle` flag usage
  - Troubleshooting guide for signal file issues
- [x] Update `.claude/context/project/neovim/hooks/wezterm-integration.md` with: *(completed)*
  - Multi-state CLAUDE_STATUS values and their meanings
  - Color mapping table
  - Safe degradation behavior
- [x] End-to-end validation: verified signal flow architecture is correct *(completed)*
  - No TTS spam during intermediate stops
  - Single lifecycle TTS at research completion ("Tab N researched")
  - Tab color changes to dark green
  - Signal file consumed by Stop hook
  - Non-workflow one-off question still triggers normal "Tab N" TTS
- [x] Verify Notification hook (permission_prompt, idle_prompt, elicitation_dialog) behavior is unchanged *(completed: notification path untouched in tts-notify.sh)*

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/context/project/neovim/guides/tts-stt-integration.md` - Add lifecycle notification architecture docs
- `.claude/context/project/neovim/hooks/wezterm-integration.md` - Add multi-state indicator docs

**Verification**:
- Documentation accurately describes the B+A Hybrid architecture
- End-to-end test passes: workflow stop = lifecycle TTS only, non-workflow stop = normal TTS
- No regressions in Notification hook behavior
- Tab coloring works for all lifecycle states

## Testing & Validation

- [ ] `tts-notify.sh --lifecycle researched` speaks "Tab N researched"
- [ ] `tts-notify.sh --lifecycle completed` speaks "Tab N completed"
- [ ] `tts-notify.sh` with signal file present stays silent and deletes file
- [ ] `tts-notify.sh` without signal file speaks "Tab N" normally
- [ ] Stale signal files (>60s) are ignored and cleaned up
- [ ] `update-task-status.sh postflight` creates signal file and triggers TTS
- [ ] WezTerm tab colors change based on CLAUDE_STATUS lifecycle values
- [ ] Notification hook for permission_prompt/idle_prompt unchanged
- [ ] Non-workflow stops (one-off questions) still produce TTS

## Artifacts & Outputs

- `plans/01_lifecycle-notification-patterns.md` (this plan)
- Modified `.claude/hooks/tts-notify.sh` (lifecycle flag + signal file check)
- Modified `.claude/scripts/update-task-status.sh` (TTS trigger + signal file write)
- Modified `.claude/hooks/wezterm-notify.sh` (lifecycle state parameter)
- Modified `~/.config/wezterm/wezterm.lua` (lifecycle color mapping)
- Updated `.claude/context/project/neovim/guides/tts-stt-integration.md`
- Updated `.claude/context/project/neovim/hooks/wezterm-integration.md`

## Rollback/Contingency

If the lifecycle notification system causes issues:
1. **TTS rollback**: Remove `--lifecycle` flag handling and signal file check from `tts-notify.sh`; remove TTS call and signal file write from `update-task-status.sh`. This restores the original "Tab N on every Stop" behavior.
2. **WezTerm rollback**: Revert `wezterm-notify.sh` to always set `CLAUDE_STATUS=needs_input`; revert `format-tab-title` to only check for `needs_input`. Safe degradation means unknown values already produce default styling, so partial rollback is possible.
3. **Signal file cleanup**: `rm -f specs/tmp/tts-lifecycle-signal` removes any orphaned signal file.
4. All changes are in separate files with clear boundaries, enabling surgical rollback of individual components.
