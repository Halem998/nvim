# Implementation Summary: Task #590

- **Task**: 590 - fix_task_number_parsing_display
- **Status**: [COMPLETED]
- **Started**: 2026-05-21T10:40:00Z
- **Completed**: 2026-05-21T10:55:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Artifacts**:
  - [specs/590_fix_task_number_parsing_display/plans/01_task-number-parsing.md]
  - [specs/590_fix_task_number_parsing_display/summaries/01_task-number-parsing-summary.md]
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Replaced the 2-tier set/clear regex in `wezterm-task-number.sh` with a 3-tier SET/CLEAR/PRESERVE pattern that supports all task-bearing commands, compact multi-task spec display, and preservation of task numbers during free-text follow-up exchanges. The change was applied to all 4 copies of the hook and both documentation files updated accordingly.

## What Changed

- `.claude/hooks/wezterm-task-number.sh` — Replaced 2-tier logic with 3-tier: Tier 1 SET (10 command patterns including multi-task syntax), Tier 2 CLEAR (slash commands without task), Tier 3 PRESERVE (free text/follow-ups); updated header comment
- `.claude/extensions/core/hooks/wezterm-task-number.sh` — Identical copy (md5sum verified)
- `.opencode/hooks/wezterm-task-number.sh` — Identical copy (md5sum verified)
- `.opencode/extensions/core/hooks/wezterm-task-number.sh` — Identical copy (md5sum verified)
- `.claude/context/project/neovim/hooks/wezterm-integration.md` — Updated wezterm-task-number.sh section: expanded command list (10 patterns), updated behavior description to 3-tier, updated TASK_NUMBER values to include multi-task spec example
- `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` — Same documentation updates

## Decisions

- Used `SHOULD_SET` / `SHOULD_CLEAR` boolean variables rather than inline set/clear for cleaner conditional logic in the 3-way output block
- Captured multi-task spec broadly (`[0-9][0-9,' '-]*`) then post-processed: strip from first `--`, trim trailing spaces/commas, remove internal spaces — keeps regex readable and handles edge cases cleanly
- Bash character class `' '` in character set avoids needing `[[:space:]]` inside `[]`, consistent with POSIX bracket expressions

## Plan Deviations

- None (implementation followed plan)

## Impacts

- `/spawn N` prompts now correctly set tab task number (was silently ignored before)
- `/task --recover N`, `--expand N`, `--abandon N`, `--review N` now correctly set task number
- `/errors --fix N` now correctly sets task number
- Multi-task prompts (`/research 7, 22-24, 59`) now display full compact spec `#7,22-24,59` instead of just `#7`
- Follow-up answers to agent questions ("yes proceed", "focus on LSP errors") no longer clear the task number from the tab title

## Follow-ups

- Manual WezTerm test recommended: verify `/research 7, 22-24 --team` sets tab to `#7,22-24` (strips `--team`)
- Manual test recommended: free-text follow-up preserves tab task number across multi-turn workflow

## References

- Plan: `specs/590_fix_task_number_parsing_display/plans/01_task-number-parsing.md`
- Research: `specs/590_fix_task_number_parsing_display/reports/01_task-number-parsing.md`
- Hook: `.claude/hooks/wezterm-task-number.sh`
- Documentation: `.claude/context/project/neovim/hooks/wezterm-integration.md`
