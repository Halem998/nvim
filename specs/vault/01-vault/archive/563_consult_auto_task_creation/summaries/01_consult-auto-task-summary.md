# Implementation Summary: Task #563

- **Task**: 563 - Make /consult always create a task automatically
- **Status**: [COMPLETED]
- **Started**: 2026-05-13T00:00:00Z
- **Completed**: 2026-05-13T01:00:00Z
- **Effort**: 1 hour
- **Dependencies**: Task 562 (completed)
- **Artifacts**:
  - [specs/563_consult_auto_task_creation/plans/01_consult-auto-task-plan.md]
  - [specs/563_consult_auto_task_creation/reports/01_consult-auto-task-research.md]
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

This task eliminates the standalone/temp-file mode from `/consult` and makes every invocation automatically create a task entry in state.json and TODO.md. The changes touch six files across two project copies (nvim extension and Vision project mirror). The existing "attach to existing task" path (`/consult --legal 458`) is preserved unchanged.

## What Changed

- **`consult.md` Gate In Step 4**: Replaced "Resolve Task Context if task number" with "Create or Resolve Task" — a two-branch logic that either looks up an existing task (task_number input) or auto-creates a new one using slug generation, state.json update, and TODO.md update
- **`consult.md` Gate In Overview/Syntax/Input Types**: Updated to remove "standalone immediate-mode" language; now documents that every invocation creates a task automatically
- **`consult.md` Gate Out**: Always displays task number, task slug, report path, and "Next: /plan {N}"; git commit is now unconditional (no longer wrapped in `if task_number` guard)
- **`skill-consult/SKILL.md` Stage 2**: Removed the standalone `else` branch that set `metadata_file="/tmp/consult-meta-${session_id}.json"`; now always derives task_dir from task_number
- **`skill-consult/SKILL.md` Stage 8**: Removed entirely (was `rm -f "$metadata_file"` cleanup); renamed to "Return Brief Summary" to avoid deleting task-directory metadata files
- **`skill-consult/SKILL.md` Stage 9**: Changed "Task attached: {task_number or 'standalone'}" to "Task: #{task_number}"
- **`skill-consult/SKILL.md` Stage 6/7**: Removed `if [ -n "$task_number" ]` conditionals — artifact linking and git commit now always execute
- **`legal-analysis-agent.md` Stage 6**: Updated comment from "or a standalone path if immediate-mode" to "the task directory is always present since every consultation creates or attaches to a task"
- All six files updated: 3 nvim extension + 3 Vision project mirror

## Decisions

- Auto-task creation belongs in Gate In of `consult.md`, not in `skill-consult` — the command owns task lifecycle
- Task type for auto-created consult tasks: `founder` (matches extension domain)
- Slug prefix convention: `consult_{domain}_{slug_from_input}` (max 50 chars total)
- Status after auto-creation: `not_started` (consultation is standalone output, not a research/plan phase)
- The `rm -f "$metadata_file"` cleanup stage was removed entirely (not scoped) to avoid any risk of deleting task-directory files

## Impacts

- Every `/consult` invocation now creates a persistent task entry with tracked artifacts
- Gate Out always displays task number and recommends `/plan N` as next step
- Git commit always occurs after consultation (previously conditional on task_number being set)
- `skill-consult` is simpler — no conditional branching on standalone vs task-attached mode
- The Vision project mirror is kept in sync (only Agent vs Task tool references differ, as expected)

## Follow-ups

- None required. The consultation's task status remains `not_started` after consultation; user runs `/plan N` to continue the workflow

## References

- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/consult.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-consult/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-analysis-agent.md`
- `/home/benjamin/Projects/Logos/Vision/.claude/commands/consult.md`
- `/home/benjamin/Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md`
- `/home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md`
- `specs/563_consult_auto_task_creation/plans/01_consult-auto-task-plan.md`
- `specs/563_consult_auto_task_creation/reports/01_consult-auto-task-research.md`
