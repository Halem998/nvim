# Phase 3 Results: Refactor /todo and Create roadmap-sync.sh

**Completed**: 2026-05-22
**Phase**: 3 of 8

## What Was Done

### Created `.claude/scripts/roadmap-sync.sh` (331L)

New utility script with two phases:
- **scan phase**: Reads archivable tasks JSON, separates meta from non-meta tasks, scans ROADMAP.md using three strategies (explicit roadmap_items, exact Task N reference, future summary-based). Outputs JSON array of matches to stdout, counts to stderr.
- **apply phase**: Reads matches JSON file, applies completion/abandonment annotations to ROADMAP.md using Python for reliable string replacement. Outputs annotation counts.

Key design decisions:
- Scan and apply phases are separate CLI modes (`roadmap-sync.sh scan ...` / `roadmap-sync.sh apply ...`) sharing state via a temp JSON file -- cleaner than a single monolithic invocation
- Python `printf '%s\n'` approach used for the annotation script instead of heredoc-in-loop (avoids bash syntax error with process substitution)
- Uses file-based jq filter to safely handle `task_type != "meta"` (Issue #1132-safe)

### Refactored `.claude/commands/todo.md` (630L, was 1046L -- 40% reduction)

All five utility scripts are now called from todo.md:

| Step | Script | Replaces |
|------|--------|---------|
| 2.5 | `orphan-detection.sh` | 90L of inline bash scanning loops |
| 3.5 | `roadmap-sync.sh scan` | 130L of roadmap scanning code |
| 5.0 (loop) | `memory-harvest.sh` + `archive-task.sh` | 80L of per-task archival code |
| 5.5 | `roadmap-sync.sh apply` | 80L of annotation application code |
| 5.7 | `vault-operation.sh` | 140L of vault operation code |

Memory harvest integrated into archival loop (Step 5.0):
- Calls `memory-harvest.sh "$task_number"` before each `archive-task.sh` call
- Accumulates `total_harvested` count
- Displays `Memories: {H} harvested` in final output section

Roadmap state passes between scan and apply phases via temp JSON file:
- `specs/tmp/todo_archivable_$$.json` - Input for scan phase
- `specs/tmp/todo_roadmap_matches_$$.json` - Output from scan, input for apply

## Verification

- `roadmap-sync.sh` passes `bash -n` syntax check
- `roadmap-sync.sh` has executable bit set
- `todo.md` reduced from 1046L to 630L (40% reduction; above 400-500L target due to retained orphan/misplaced inline logic and metrics sync which have no dedicated scripts)
- All 5 utility scripts referenced in todo.md
- Memory harvest present in archival loop (line 258)
- Harvest count appears in output section (line 542: `Memories: {H} harvested`)

## Deviations from Plan

- **roadmap-sync.sh is 331L** (plan estimated ~210L): The dual-phase architecture (scan + apply as separate CLI commands) plus Python annotation script adds lines. The plan expected a single-phase script; splitting into two phases adds parameter parsing and mode-switching overhead.
- **todo.md is 630L** (plan target ~400-500L): Steps E, F (orphan/misplaced inline logic) and metrics sync (Steps 5.6-5.8) are retained inline since no utility scripts were planned for them. The 40% reduction is meaningful given the complexity retained.
