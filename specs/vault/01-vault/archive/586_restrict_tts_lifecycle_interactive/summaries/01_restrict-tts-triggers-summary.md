# Implementation Summary: Task #586

- **Task**: 586 - Restrict TTS announcements to lifecycle transitions and interactive prompts
- **Status**: [COMPLETED]
- **Started**: 2026-05-15T22:05:00Z
- **Completed**: 2026-05-15T22:40:00Z
- **Effort**: 35 minutes (5 phases)
- **Dependencies**: None
- **Artifacts**:
  - `specs/586_restrict_tts_lifecycle_interactive/plans/01_restrict-tts-triggers.md`
  - `specs/586_restrict_tts_lifecycle_interactive/summaries/01_restrict-tts-triggers-summary.md` (this file)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Restricted TTS announcements from firing on every Claude turn (via Stop hook) to only two categories: lifecycle transitions (researched/planned/completed) fired by skill postflight Stage 8a, and interactive prompts (permission_prompt/elicitation_dialog) fired via Notification hook. The B+A Hybrid signal file suppression mechanism was fully removed as dead code.

## What Changed

- `.claude/settings.json` - Removed tts-notify.sh from Stop hook; removed idle_prompt from Notification matcher
- `.claude/extensions/core/root-files/settings.json` - Same Stop hook and Notification changes (synced template)
- `.opencode/settings.json` - Same changes with .opencode/ path prefix
- `.claude/hooks/tts-notify.sh` - Simplified from 275 lines to 124 lines: removed normal mode (stdin parsing, cooldown, signal file, subagent guard), kept lifecycle mode and added minimal interactive no-arg path
- `.claude/extensions/core/hooks/tts-notify.sh` - Synced to simplified version
- `.opencode/hooks/tts-notify.sh` - Synced to simplified version
- `.opencode/extensions/core/hooks/tts-notify.sh` - Synced to simplified version
- `.claude/scripts/lifecycle-notify.sh` - Created new wrapper script that calls tts-notify.sh --lifecycle and wezterm-notify.sh in background
- `.claude/scripts/update-task-status.sh` - Removed PHASE 5 signal file write and direct TTS invocation; kept WezTerm tab coloring
- 4 core skills (skill-researcher, skill-planner, skill-implementer, skill-reviser) - Added Stage 8a: Lifecycle TTS Notification
- 4 extension core skills (same names) - Added Stage 8a
- 2 nvim extension skills (skill-neovim-research, skill-neovim-implementation) - Added Stage 8a
- 2 nix extension skills - skill-nix-research got Stage 8a, skill-nix-implementation got Stage 5a (adapted to its divergent stage format)
- 3 copies of tts-stt-integration.md - Updated to remove B+A Hybrid docs and reflect lifecycle + interactive model

## Decisions

- Kept a minimal no-arg path in the simplified tts-notify.sh for Notification hook calls (permission_prompt/elicitation_dialog) that speaks "Tab N" -- avoids changing Notification hook settings.json entry
- Created lifecycle-notify.sh as a wrapper (rather than calling tts-notify.sh directly from skills) to centralize both TTS and WezTerm coloring into one call
- WezTerm tab coloring remains in update-task-status.sh PHASE 5 (distinct UI purpose from TTS)
- skill-nix-implementation uses Stage "5a" (not "8a") since it has a divergent numbered 4-8 postflight format
- Removed TTS_COOLDOWN constant from simplified tts-notify.sh since cooldown logic only applied to the removed normal mode

## Plan Deviations

- None (implementation followed plan exactly across all 5 phases)

## Impacts

- TTS will no longer fire on every Claude response; only fires on lifecycle transitions and when user input is needed
- Skills now fire lifecycle TTS after artifact linking (Stage 8a) rather than having it fire from update-task-status.sh
- The B+A Hybrid signal file mechanism (specs/tmp/tts-lifecycle-signal) is no longer written or read; existing stale signal files are harmless and will be garbage collected
- idle_prompt notifications (60-second inactivity reminders) are eliminated

## Follow-ups

- None required; all changes are complete and verified

## References

- `specs/586_restrict_tts_lifecycle_interactive/plans/01_restrict-tts-triggers.md`
- `specs/586_restrict_tts_lifecycle_interactive/reports/01_restrict-tts-triggers.md`
