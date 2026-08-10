# Implementation Summary: Remove language-to-task_type Compatibility Shim

- **Task**: 394 - Remove language-to-task_type backward compatibility shim
- **Status**: [COMPLETED]
- **Started**: 2026-04-13T00:00:00Z
- **Completed**: 2026-04-13T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 393 (completed)
- **Artifacts**:
  - [Plan](../plans/01_remove-compat-shim.md)
  - [Summary](../summaries/01_remove-compat-shim-summary.md) (this file)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary.md

## Overview

Removed all backward compatibility shims that treated the old `language` field as `task_type` across the agent system. This completes the field rename migration started in task 393 by eliminating fallback chains (`.task_type // .language // "general"`) and direct `.language` field reads from 51 files.

## What Changed

- Replaced `.task_type // .language // "general"` with `.task_type // "general"` in 19 core files (6 commands, 8 core skills, 5 extension skills)
- Replaced `(.task_type // .language)` with `.task_type` in 3 jq filter patterns in `todo.md`
- Updated 18 extension skills to read `.task_type` instead of `.language` (10 founder, 4 present, 2 nvim, 1 nix, 1 web)
- Updated 11 extension commands to read `.task_type` instead of `.language` (9 founder, 2 present)
- Removed backward compatibility note from `state-management-schema.md`
- Updated `context-discovery.md` to reference `task_types` instead of `languages` in 4 locations
- Fixed orchestrator.md session registry to use `task_type` key instead of `language`
- Removed stale "backward compat" and "fall back to language" comments

## Decisions

- Left `.language` references in documentation/example files (docs/guides/, docs/examples/) that describe historical patterns or hypothetical systems
- Left treesitter guide `.language` reference (treesitter syntax, not jq field)
- Simplified `deck.md` validation to check `task_type` directly instead of cross-checking both `language` and `task_type` fields
- Fixed inconsistent bash syntax in meeting.md and funds.md (used `| not` pattern, standardized to `!=`)

## Impacts

- All active task routing now reads exclusively from `task_type` field
- The `language` field in state.json is no longer read by any command, skill, or agent
- Archived state.json entries with old `language` field are untouched (historical record)
- No behavioral change since all active tasks already had `task_type` populated

## Follow-ups

- None required -- migration is complete

## References

- Plan: `specs/394_remove_language_to_task_type_compat_shim/plans/01_remove-compat-shim.md`
- Research: `specs/394_remove_language_to_task_type_compat_shim/reports/01_remove-compat-shim.md`
