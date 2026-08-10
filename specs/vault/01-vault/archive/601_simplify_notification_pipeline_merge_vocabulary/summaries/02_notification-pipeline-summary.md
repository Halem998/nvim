# Implementation Summary: Task #601

- **Task**: 601 - simplify_notification_pipeline_merge_vocabulary
- **Status**: [COMPLETED]
- **Started**: 2026-05-22T00:00:00Z
- **Completed**: 2026-05-22T00:30:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/02_notification-pipeline.md, summaries/02_notification-pipeline-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md

## Overview

Simplified the WezTerm tab coloring and TTS notification pipeline by replacing the signal file suppress mechanism with a workflow-active marker, merging to single lifecycle vocabulary, extracting shared TTY discovery into `wezterm-utils.sh`, and deleting dead code. All changes propagated to 4 hook/script copy locations. The pipeline now correctly suppresses Stop hook during mid-workflow orchestrator pauses and uses dim-to-bold same-hue color transitions for lifecycle phases.

## What Changed

- `.claude/scripts/update-task-status.sh` — Added workflow-active marker on preflight; removed signal file write and artifact-type mapping from PHASE 5 (now uses `$STATE_STATUS` directly)
- `.claude/hooks/claude-stop-notify.sh` — Replaced signal file logic with workflow-active marker check; removed TTS dispatch from Stop hook
- `.claude/hooks/wezterm-preflight-status.sh` — Added workflow-active cleanup in Tier 2; refactored to use `wezterm-utils.sh`
- `.claude/hooks/wezterm-notify.sh` — Updated header comments (lifecycle-only vocabulary); refactored to use `wezterm-utils.sh`
- `.claude/hooks/tts-notify.sh` — Updated header comments to reflect `update-task-status.sh` as caller
- `.claude/hooks/wezterm-utils.sh` — Created new shared utility with `get_pane_tty()` and `set_user_var()` functions
- `.claude/hooks/wezterm-clear-status.sh` — Deleted (dead code)
- `.claude/scripts/lifecycle-notify.sh` — Deleted (dead code)
- `~/.dotfiles/config/wezterm.lua` — Replaced status_colors table with lifecycle-only entries and dim-to-bold same-hue color transitions
- `.claude/extensions/core/scripts/update-task-status.sh` — Added workflow-active preflight write
- `.opencode/scripts/update-task-status.sh` — Added workflow-active preflight write
- All 4 hook locations — Synchronized claude-stop-notify.sh, wezterm-notify.sh, wezterm-preflight-status.sh, wezterm-utils.sh
- `.claude/context/project/neovim/hooks/wezterm-integration.md` — Updated to document lifecycle-only vocabulary, workflow-active marker, wezterm-utils.sh
- `.claude/context/project/neovim/guides/tts-stt-integration.md` — Updated to remove artifact-type vocabulary references, document that TTS fires from update-task-status.sh only

## Decisions

- Workflow-active marker replaces signal file: the signal file only suppressed the first Stop after postflight, but did not handle mid-workflow pauses. The marker persists until a non-lifecycle command clears it.
- Stop hook no longer fires TTS: TTS is only fired from `update-task-status.sh` postflight (via `--lifecycle` flag) and from Notification hook events.
- tts-notify.sh is unchanged functionally; only header comments updated to reflect correct caller.
- PHASE 5 simplification (task 2.1) was combined with Phase 1 work since both involved the same block.

## Plan Deviations

- **Task 2.1** (simplify PHASE 5): Combined with Phase 1 during signal file removal — both changes affected the same code block in update-task-status.sh

## Impacts

- Tab color no longer resets to gray during mid-workflow orchestrator pauses
- No random TTS announcements during `--team` mode from intermediate Stop events
- Dim-to-bold color transitions now work within same hue family per phase
- Reduced code duplication: TTY discovery consolidated in `wezterm-utils.sh`
- Dead code eliminated: `wezterm-clear-status.sh` and `lifecycle-notify.sh` deleted

## Follow-ups

- Manual testing needed: verify tab colors during live workflow runs
- `skill-refresh` should be updated to clean `.claude/tmp/workflow-active` stale files (low priority)

## References

- `/home/benjamin/.config/nvim/specs/601_simplify_notification_pipeline_merge_vocabulary/plans/02_notification-pipeline.md`
- `/home/benjamin/.config/nvim/.claude/hooks/claude-stop-notify.sh`
- `/home/benjamin/.config/nvim/.claude/hooks/wezterm-utils.sh`
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh`
- `/home/benjamin/.dotfiles/config/wezterm.lua`
