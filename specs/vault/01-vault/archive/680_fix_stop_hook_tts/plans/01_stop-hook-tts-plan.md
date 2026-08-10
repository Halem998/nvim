# Implementation Plan: Fix Stop Hook TTS

- **Task**: 680 - Fix Stop hook to fire TTS when user attention is needed
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 679 (TTS best practices research, completed)
- **Research Inputs**: specs/680_fix_stop_hook_tts/reports/01_stop-hook-tts-research.md
- **Artifacts**: plans/01_stop-hook-tts-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Stop hook (`claude-stop-notify.sh`) currently fires only the WezTerm tab color change when Claude halts without a workflow-active marker, but never calls `tts-notify.sh` for an audible alert. This plan adds a TTS call alongside the existing WezTerm call so the user hears "Tab N" when Claude stops and needs input. It also adds a 10-second timestamp cooldown to `tts-notify.sh` to prevent double-announcement when both the lifecycle path (task 681) and the Stop hook path fire TTS within seconds of each other. Finally, `settings.json` gains `idle_prompt` in the Notification matcher so TTS fires when Claude waits 60+ seconds for user input.

### Research Integration

Key findings from the research report:

1. Line 59 of `claude-stop-notify.sh` has an explicit "no TTS" comment and no `tts-notify.sh` call -- this is the single insertion point.
2. The project `tts-notify.sh` has no cooldown, unlike the global version at `~/.config/.claude/hooks/tts-notify.sh` which uses `/tmp/claude-tts-last-notify` with a 10-second window.
3. The cooldown file path must be `/tmp/claude-tts-last-notify` (shared with the global version) to enable cross-script dedup.
4. The `idle_prompt` event type is missing from the Notification matcher in `settings.json` line 140.
5. Subagent suppression at line 40-45 gates the TTS branch safely; no reordering needed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add TTS announcement ("Tab N") when the Stop hook fires in the non-workflow-active branch
- Add 10-second cooldown dedup to `tts-notify.sh` (shared `/tmp/claude-tts-last-notify` file)
- Add `idle_prompt` to the Notification hook matcher in `settings.json`
- Maintain error tolerance: TTS failures must not break the Stop hook

**Non-Goals**:
- Modifying `skill-orchestrate/SKILL.md` or `orchestrator-postflight.sh` (task 681 territory)
- Adding `lifecycle-notify.sh` changes (task 681 territory)
- Fixing the stale workflow-active marker issue (task 681 clears it on orchestrate completion)
- Adding mid-orchestrate dim tab colors (separate concern, lower priority)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Double-announcement with task 681 lifecycle TTS | M | H (without cooldown) | Shared `/tmp/claude-tts-last-notify` cooldown file deduplicates within 10s window |
| Cooldown suppresses a legitimate consecutive TTS | L | L | 10s window is much shorter than typical user interaction gaps |
| `tts-notify.sh` failure breaks Stop hook exit code | H | L | Call uses `2>/dev/null \|\| true` pattern, matching existing wezterm call |
| Stale workflow-active marker still suppresses Stop TTS | M | M | Acceptable interim state; task 681 fixes root cause by clearing marker on orchestrate completion |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Add Cooldown to tts-notify.sh [COMPLETED]

**Goal**: Add timestamp-based cooldown dedup to the project `tts-notify.sh`, matching the global version's pattern. This must land first because Phase 2 adds a new caller that could trigger double-announcement without it.

**Tasks**:
- [x] Add `TTS_COOLDOWN` and `LAST_NOTIFY_FILE` variable declarations after line 30 (after `LOG_FILE` declaration) *(completed)*
- [x] Add cooldown check block after line 105 (after the piper model check `fi`, before the LIFECYCLE_MODE section at line 107) -- checks elapsed time against `TTS_COOLDOWN`, exits if within window *(completed)*
- [x] Add `date +%s > "$LAST_NOTIFY_FILE"` timestamp write after each successful `speak` call in both lifecycle mode (after line 114) and interactive mode (after line 125) *(completed)*
- [x] Update the script header comment block to document `TTS_COOLDOWN` env var (matching global version's documentation pattern) *(completed)*

**Interface contract for task 681**: Task 681's lifecycle path calls this same `tts-notify.sh` with `--lifecycle STATUS`. Both modes share the cooldown file at `/tmp/claude-tts-last-notify`. Task 681 does not need to add cooldown logic -- it gets it for free from this change.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Add cooldown variables, check block, and timestamp writes

**Verification**:
- `bash -n .claude/hooks/tts-notify.sh` passes (syntax check)
- `TTS_ENABLED=0 bash .claude/hooks/tts-notify.sh` exits cleanly (disabled path still works)
- `grep -c 'LAST_NOTIFY_FILE' .claude/hooks/tts-notify.sh` returns 3+ (declaration + check + writes)
- `grep 'TTS_COOLDOWN' .claude/hooks/tts-notify.sh` shows variable declaration with default 10
- Manual test: `TTS_COOLDOWN=0 bash .claude/hooks/tts-notify.sh` should speak immediately (cooldown disabled)

---

### Phase 2: Add TTS Call to claude-stop-notify.sh [COMPLETED]

**Goal**: Insert a `tts-notify.sh` call in the non-workflow-active branch of the Stop hook, alongside the existing `wezterm-notify.sh` call. After this change, when Claude stops without a workflow-active marker, the user hears "Tab N" and sees the tab turn gray.

**Tasks**:
- [x] Update comment on line 59: change "Fire needs_input wezterm color only (no TTS for non-lifecycle stops)" to "Fire needs_input wezterm color + TTS announcement for user attention" *(completed)*
- [x] Insert TTS call block between the wezterm `fi` (line 63) and `exit_success` (line 65): check for `tts-notify.sh` existence, call with `2>/dev/null || true` *(completed)*
- [x] No arguments to `tts-notify.sh` -- interactive mode speaks "Tab N" *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/hooks/claude-stop-notify.sh` - Update comment and add TTS call block (lines 58-65)

**Verification**:
- `bash -n .claude/hooks/claude-stop-notify.sh` passes (syntax check)
- `grep 'tts-notify' .claude/hooks/claude-stop-notify.sh` shows the new call
- `grep -v 'no TTS' .claude/hooks/claude-stop-notify.sh | wc -l` confirms old comment removed
- Manual test: trigger a Stop hook without workflow-active marker; verify "Tab N" is spoken (or verify log entry with `TTS_ENABLED=0`)

---

### Phase 3: Update settings.json Matcher and End-to-End Verification [COMPLETED]

**Goal**: Add `idle_prompt` to the Notification hook matcher in `settings.json` so TTS fires when Claude is idle for 60+ seconds. Verify all three changes work together.

**Tasks**:
- [x] Edit `.claude/settings.json` line 140: change `"permission_prompt|elicitation_dialog"` to `"permission_prompt|idle_prompt|elicitation_dialog"` *(completed)*
- [x] Run `jq . .claude/settings.json > /dev/null` to verify JSON validity *(completed)*
- [x] Run `bash -n .claude/hooks/claude-stop-notify.sh && bash -n .claude/hooks/tts-notify.sh` to verify both scripts pass syntax check *(completed)*
- [x] Verify cooldown dedup end-to-end: confirm `/tmp/claude-tts-last-notify` path appears in both project `tts-notify.sh` and global `~/.config/.claude/hooks/tts-notify.sh` *(completed)*
- [x] Verify subagent suppression: confirm `agent_id` check in `claude-stop-notify.sh` still precedes the TTS branch *(completed)*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/settings.json` - Update Notification matcher on line 140

**Verification**:
- `jq '.hooks.Notification[0].matcher' .claude/settings.json` returns `"permission_prompt|idle_prompt|elicitation_dialog"`
- `bash -n .claude/hooks/claude-stop-notify.sh` passes
- `bash -n .claude/hooks/tts-notify.sh` passes
- `grep -c 'idle_prompt' .claude/settings.json` returns 1
- `grep '/tmp/claude-tts-last-notify' .claude/hooks/tts-notify.sh` returns match (shared cooldown path)

## Testing & Validation

- [x] `bash -n .claude/hooks/claude-stop-notify.sh` -- syntax valid *(completed)*
- [x] `bash -n .claude/hooks/tts-notify.sh` -- syntax valid *(completed)*
- [x] `jq . .claude/settings.json > /dev/null` -- JSON valid *(completed)*
- [x] `TTS_ENABLED=0 bash .claude/hooks/tts-notify.sh` -- exits 0 (disabled path) *(completed)*
- [x] `TTS_ENABLED=0 bash .claude/hooks/tts-notify.sh --lifecycle researched` -- exits 0 (lifecycle disabled path) *(completed)*
- [x] Cooldown file path `/tmp/claude-tts-last-notify` is shared between project and global `tts-notify.sh` *(completed)*
- [x] Subagent suppression: `echo '{"agent_id":"sub1"}' | bash .claude/hooks/claude-stop-notify.sh` exits without firing TTS *(completed)*
- [x] Workflow-active suppression: `touch .claude/tmp/workflow-active && bash .claude/hooks/claude-stop-notify.sh` exits without firing TTS; `rm .claude/tmp/workflow-active` *(completed)*

## Artifacts & Outputs

- `specs/680_fix_stop_hook_tts/plans/01_stop-hook-tts-plan.md` (this file)
- `.claude/hooks/tts-notify.sh` (modified: cooldown mechanism)
- `.claude/hooks/claude-stop-notify.sh` (modified: TTS call added)
- `.claude/settings.json` (modified: idle_prompt in Notification matcher)

## Rollback/Contingency

All three changes are additive and independently revertible:

1. **tts-notify.sh cooldown**: Remove the `TTS_COOLDOWN`, `LAST_NOTIFY_FILE` declarations, the cooldown check block, and the timestamp writes. The script reverts to its pre-cooldown behavior.
2. **claude-stop-notify.sh TTS call**: Remove the `tts-notify.sh` call block and restore the original "no TTS" comment. The Stop hook reverts to wezterm-only behavior.
3. **settings.json matcher**: Remove `idle_prompt|` from the matcher string. Notifications revert to permission_prompt and elicitation_dialog only.

If TTS is problematic at runtime, set `TTS_ENABLED=0` in the environment to disable all TTS without code changes.
