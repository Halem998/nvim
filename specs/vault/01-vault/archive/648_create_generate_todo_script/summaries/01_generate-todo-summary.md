# Implementation Summary: Task #648

**Completed**: 2026-06-10
**Duration**: ~1 hour

## Overview

Created `.claude/scripts/generate-todo.sh`, a self-contained bash script that generates the entire `specs/TODO.md` from `specs/state.json` as the sole input. The script produces YAML frontmatter, delegates the Task Order section to the existing `generate-task-order.sh --print`, and generates all task entries in descending project_number order with complete field formatting and artifact linking.

## What Changed

- `.claude/scripts/generate-todo.sh` — Created new script (executable, 200+ lines)
- `.claude/logs/generate-todo.log` — Created on first run (auto-created)
- `specs/648_create_generate_todo_script/plans/01_generate-todo-script.md` — Phase status markers updated

## Decisions

- **Task Order delegation**: Calls `generate-task-order.sh --print` rather than absorbing its 882-line Kahn/DFS logic, avoiding duplication and reusing tested code.
- **Artifact grouping**: research and report artifact types both map to `**Research**` label; multiple artifacts of the same type render as a multi-line list; single artifacts render inline.
- **Blank line between sections**: Added an explicit blank line before `## Tasks` because `generate-task-order.sh --print` strips trailing newlines via bash variable substitution.
- **Atomic write**: Uses `mktemp -p "$(dirname "$TODO_FILE")"` + `mv` so no partial/corrupted output can occur; `trap cleanup_temp EXIT` ensures temp file cleanup on error.
- **jq safety**: All `select()` calls use `| not` pattern to avoid jq Issue #1132 `!=` escaping.
- **printf safety**: All user data uses `printf '%s'` pattern to prevent format string injection.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (bash script)
- Tests: All 5 validation tests passed
  - Script runs without errors
  - Diff against current TODO.md shows only expected data differences (state.json enrichment)
  - Idempotency: two consecutive runs produce identical output
  - `--no-log` suppresses all log output
  - `--dry-run` prints to stdout without modifying TODO.md
  - Log file contains structured START/INFO/OK/WROTE entries
  - Terminal tasks in Tasks section but not in Task Order (11 terminal, 6 active)
  - `---` separator between entries but not after last entry
- Files verified: Yes

## Notes

The remaining diff between generated output and the current TODO.md is expected: the state.json was enriched by task 647 with more complete descriptions, and the TODO.md was not regenerated after that enrichment. Once task 649 integrates generate-todo.sh into the pipeline, all future state changes will automatically regenerate TODO.md, eliminating any drift.
