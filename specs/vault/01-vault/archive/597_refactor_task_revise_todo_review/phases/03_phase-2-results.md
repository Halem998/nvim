# Phase 2 Results: Create /todo Utility Scripts

**Task**: 597 - Refactor /task, /revise, /todo, /review for consistency with new architecture
**Phase**: 2 of 8
**Completed**: 2026-05-22
**Status**: COMPLETED

## What Was Created

- `.claude/scripts/orphan-detection.sh` — New script (103L)
- `.claude/scripts/archive-task.sh` — New script (112L)
- `.claude/scripts/vault-operation.sh` — New script (175L)

## Implementation Details

### orphan-detection.sh

Extracts Steps 2.5-2.6 from todo.md. Accepts three arguments: `specs_dir`, `state_json`, `archive_state_json`. Gracefully handles missing `archive/state.json` (treats as empty). Output uses delimiter format:

```
---orphaned_in_specs---
specs/NNN_slug/
---orphaned_in_archive---
specs/archive/NNN_slug/
---misplaced_in_specs---
specs/NNN_slug/
```

Each section prints only the matching directories (empty sections have no entries). Callers parse by reading lines between delimiters.

### archive-task.sh

Extracts Steps 5A-5D from todo.md. Accepts `task_number`, `project_name`, and optional `--dry-run`. Operations in order:

1. **A**: Adds task entry to `archive/state.json` (to `completed_projects` or `archived_projects` based on status)
2. **B**: Removes task from `state.json` active_projects using `del()` (Issue #1132-safe)
3. **C**: Removes task entry from TODO.md using a Python one-liner (best-effort, warns on miss)
4. **D**: Moves task directory from `specs/` to `specs/archive/`, checking padded then unpadded format

The `--dry-run` flag reports what would happen without making changes.

### vault-operation.sh

Extracts Step 5.7 from todo.md. Accepts `state_json` and optional `--confirmed` flag. Without `--confirmed`, exits 0 (no-op) when `next_project_number <= 1000`. Steps:

1. Detects vault threshold
2. Creates `specs/vault/NN-vault/` directory
3. Moves `specs/archive/` into vault, relocates `archive/state.json` to vault root
4. Creates `meta.json` in vault (vault_number, created_at, archived_count, final_task_number)
5. Reinitializes `specs/archive/` with empty `completed_projects`
6. Renumbers tasks > 1000 in state.json, renames directories (4-digit -> 3-digit), updates TODO.md entries
7. Resets `next_project_number` and updates `vault_count`/`vault_history` in state.json
8. Adds vault transition comment to TODO.md
9. Calls `generate-task-order.sh --update-todo` for post-renumber Task Order regeneration (non-fatal)

### Deviation from Plan

The `renumber_count` detection in vault-operation.sh uses `jq -s 'length'` on newline-delimited objects (since the input from the jq filter outputs one object per line). This required careful piping -- the detection produces the correct count.

The archive-task.sh TODO.md update step uses a Python one-liner for reliable multi-line entry removal. This is more robust than sed for the task entry pattern, which can appear in various formats (`- #N:`, `  - #N:`, `- **#N**:`).

## Verification Results

All checks passed:

```
bash -n .claude/scripts/orphan-detection.sh   # syntax OK
bash -n .claude/scripts/archive-task.sh       # syntax OK
bash -n .claude/scripts/vault-operation.sh    # syntax OK

# orphan-detection.sh with real specs/ (no orphans in current repo):
bash orphan-detection.sh specs/ specs/state.json specs/archive/state.json
# Output: three empty sections (correct -- no orphans currently)

# archive-task.sh dry-run with non-existent task:
bash archive-task.sh 999 nonexistent --dry-run
# Exit 1: "task 999 not found in active_projects" (correct)

# vault-operation.sh with current state (next_project_number <= 1000):
bash vault-operation.sh specs/state.json
# Exit 0 silently (correct no-op behavior)
```

## Files Affected

- `.claude/scripts/orphan-detection.sh` — Created (executable)
- `.claude/scripts/archive-task.sh` — Created (executable)
- `.claude/scripts/vault-operation.sh` — Created (executable)
- `specs/597_refactor_task_revise_todo_review/plans/02_command-refactor.md` — Phase 2 marked COMPLETED
