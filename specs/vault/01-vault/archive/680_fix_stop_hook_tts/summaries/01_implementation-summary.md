# Implementation Summary: Task #680

**Completed**: 2026-06-12
**Duration**: ~45 minutes

## Overview

Added audible TTS notification to the Stop hook so Claude announces "Tab N" when it halts and needs user input. A 10-second cooldown deduplication mechanism was added to `tts-notify.sh` using a shared `/tmp/claude-tts-last-notify` timestamp file (matching the global version), preventing double-announcement when both the Stop hook path and the lifecycle path (task 681) fire TTS within seconds of each other. Additionally, `idle_prompt` was added to the Notification hook matcher in `settings.json` so TTS fires when Claude is idle for 60+ seconds.

## What Changed

- `.claude/hooks/tts-notify.sh` — Added `TTS_COOLDOWN` (default 10s) and `LAST_NOTIFY_FILE` (`/tmp/claude-tts-last-notify`) declarations; added cooldown check block after piper model validation; added `date +%s > "$LAST_NOTIFY_FILE"` timestamp writes after both lifecycle and interactive `speak` calls; updated header comment to document `TTS_COOLDOWN` env var
- `.claude/hooks/claude-stop-notify.sh` — Updated comment from "no TTS" to "TTS + wezterm"; inserted `tts-notify.sh` existence check and call (with `2>/dev/null || true`) after the wezterm call in the non-workflow-active branch
- `.claude/settings.json` — Added `idle_prompt` to the Notification hook matcher (`permission_prompt|idle_prompt|elicitation_dialog`)

## Decisions

- Used `/tmp/claude-tts-last-notify` as the cooldown file path (matches global `~/.config/.claude/hooks/tts-notify.sh`) to enable cross-script deduplication between the Stop hook path and the lifecycle path
- Cooldown check uses `[[ "$TTS_COOLDOWN" -gt 0 ]]` guard to allow `TTS_COOLDOWN=0` to fully bypass cooldown (useful for testing)
- `tts-notify.sh` called with no arguments in Stop hook so it uses interactive mode ("Tab N"), consistent with Notification hook behavior
- Error tolerance maintained: `bash "$tts_script" 2>/dev/null || true` mirrors the existing wezterm call pattern

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: All 8 test cases from plan's Testing & Validation section passed
- Files verified: Yes — syntax checks (`bash -n`) pass for both hook scripts; JSON validation passes for settings.json; cooldown path confirmed shared with global version; subagent and workflow-active suppression confirmed functional

## Notes

- Task 681 (concurrent parallel task) modifies `skill-orchestrate/SKILL.md`, `lifecycle-notify.sh`, `orchestrator-postflight.sh`, and `wezterm-preflight-status.sh` — no file overlap with this task
- The stale workflow-active marker issue (which can suppress Stop TTS when a marker was not cleared) is addressed by task 681 which clears the marker on orchestrate completion
- The 10-second cooldown window is much shorter than typical user interaction gaps, so false suppression of legitimate consecutive TTS is unlikely
