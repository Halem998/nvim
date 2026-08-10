# Implementation Summary: Task #653

**Completed**: 2026-06-10
**Duration**: ~1 hour

## Overview

Migrated all task creation commands, skills, agents, and archive scripts from direct TODO.md editing to the state.json-first pattern. Previously, 8 writers were creating TODO.md entries directly via Edit/sed/python operations, which would be silently overwritten by generate-todo.sh. Now all writers update state.json first, then call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md atomically.

## What Changed

- `.claude/commands/task.md` — Removed Parts A/B/C (sed frontmatter update, Edit task entry, generate-task-order.sh) from Create mode; replaced with single `generate-todo.sh` call. Same pattern for Recover, Expand, Sync, Review/Followup, and Abandon modes. Updated `allowed-tools` frontmatter to remove `Edit(specs/TODO.md)` and `Bash(sed:*)`.
- `.claude/commands/review.md` — Removed "Add task entry" Edit from Section 5.6.3 Step 5; replaced Section 6.5 generate-task-order.sh call with generate-todo.sh; replaced Edit-based goal update in Section 6.7.3 with `active_goal` state.json write + generate-todo.sh; updated doc references.
- `.claude/commands/implement.md` — Removed defensive "Add Summary line to TODO.md" Edit (G9); replaced defensive "fix [IMPLEMENTING] status" Edit with generate-todo.sh call (G10).
- `.claude/scripts/generate-task-order.sh` — Added `active_goal` field support for both `--print` and `--update-todo` modes (reads from state.json instead of only from existing TODO.md).
- `.claude/skills/skill-spawn/SKILL.md` — Removed Stage 3 (TODO.md parent status Edit), Stage 12 (TODO.md new task entries Edit), Stage 14 (TODO.md dependencies Edit); replaced Stage 14b generate-task-order.sh with generate-todo.sh.
- `.claude/skills/skill-fix-it/SKILL.md` — Removed Step 9.2 (TODO.md prepend Edit); replaced Step 9.4 generate-task-order.sh with generate-todo.sh.
- `.claude/skills/skill-project-overview/SKILL.md` — Removed Section 5.4 (TODO.md prepend Edit); Section 5.5 generate-todo.sh call was already correct.
- `.claude/agents/meta-builder-agent.md` — Removed "TODO.md Entry Format" section and "TODO.md Batch Insertion Pattern" Python pseudocode block; replaced Stage 6 generate-task-order.sh with generate-todo.sh.
- `.claude/scripts/archive-task.sh` — Replaced Section C Python block removal (~40 lines) with `generate-todo.sh` call.
- `.claude/scripts/vault-operation.sh` — Removed sed renumber operations on TODO.md; removed Python vault transition comment insertion; replaced Step 5.8.8a generate-task-order.sh with generate-todo.sh.
- `.claude/extensions/core/commands/task.md` — Synced from primary
- `.claude/extensions/core/commands/review.md` — Synced from primary
- `.claude/extensions/core/commands/implement.md` — Synced from primary
- `.claude/extensions/core/skills/skill-spawn/SKILL.md` — Synced from primary
- `.claude/extensions/core/skills/skill-fix-it/SKILL.md` — Synced from primary
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md` — Synced from primary
- `.claude/extensions/core/agents/meta-builder-agent.md` — Synced from primary

## Decisions

- **Goal line feature**: Rather than using Edit to update the goal line in TODO.md, the goal is now written to `active_goal` field in state.json and rendered by generate-task-order.sh (both `--print` and `--update-todo` modes now read `active_goal` from state.json).
- **Vault transition comment**: Removed the Python script that inserted HTML comments into TODO.md frontmatter. Since generate-todo.sh regenerates the entire file, vault transition info is preserved in state.json's `vault_history` array instead.
- **Sync mode**: Simplified to state.json-authoritative model — validates integrity, warns about orphan TODO.md tasks, regenerates TODO.md from state.json. No bidirectional sync needed.
- **Meta-builder-agent batch insertion**: Removed the Python pseudocode for building and inserting markdown batch entries. generate-todo.sh handles ordering (descending project_number), which is equivalent for user visibility.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: N/A
- `bash .claude/scripts/generate-todo.sh --dry-run` produces valid output with correct frontmatter, Task Order, and task entries
- No remaining `sed.*TODO.md`, `python3.*TODO_FILE`, or `insert_after_heading` patterns in any modified file
- All 7 extension copies match their primaries (`diff` shows identical)
- `generate-task-order.sh --print` now reads `active_goal` from state.json for goal line rendering

## Notes

The `generate-task-order.sh` changes are a targeted enhancement: `--print` mode now reads `active_goal` from state.json (previously always empty string), and `--update-todo` mode now checks state.json first before falling back to existing TODO.md goal. This ensures the goal persists correctly through generate-todo.sh regeneration cycles.
