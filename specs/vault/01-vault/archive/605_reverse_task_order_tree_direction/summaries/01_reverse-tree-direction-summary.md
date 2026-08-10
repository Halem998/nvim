# Implementation Summary: Task #605

**Completed**: 2026-05-22
**Duration**: ~30 minutes

## Overview

Reversed the DFS direction in `generate-task-order.sh` so that prerequisite tasks (wave-1, no active deps) now appear as roots and dependent tasks appear as indented children. The change required building a `task_successors` map by inverting `task_deps`, updating two DFS iteration functions to traverse successors, adding root-selection logic to the topic section, and updating documentation to reflect the new tree semantics.

## What Changed

- `.claude/scripts/generate-task-order.sh` — Added `task_successors` global, `build_successors_map()` function, root-selection logic in `generate_grouped_section()`, changed `_print_topic_node()` and `print_tree_node()` to iterate successors, updated two label strings
- `.claude/context/formats/task-order-format.md` — Updated grouped section header format/regex, Topic Section Structure examples, Tree Entry semantics, Complete Example, Parsing Patterns Summary
- `.claude/extensions/core/context/formats/task-order-format.md` — Synced with updated primary copy
- `specs/TODO.md` — Task Order section regenerated with new tree direction

## Decisions

- Added explicit root-selection pass in `generate_grouped_section()` (not in original plan): the topic loop needed to first iterate tasks with no active deps before falling through to remaining unvisited tasks. Without this, lower-numbered dependent tasks (e.g., task 595, which precedes its prerequisite 598 numerically) would appear as roots.
- Used `task_successors["$tn"]="${task_successors[$tn]:-}"` to handle unbound variable under `set -euo pipefail` for tasks with no successors.

## Plan Deviations

- **Task 1.6** altered: In addition to changing the label in `generate_grouped_section()`, added a two-pass root-selection loop that starts DFS only from wave-1 tasks (no active deps), then falls through to remaining unvisited tasks. This was necessary because the topic section iterates tasks in numeric order, and lower-numbered dependent tasks would otherwise be printed as depth-0 roots before their prerequisites.

## Verification

- Build: N/A
- Tests: N/A
- Script runs without errors: Yes (exits 0)
- Wave-1 tasks appear at depth 0: Yes (597, 598, 601, 605)
- Successor tasks indented below prereqs: Yes
- `(see above)` annotations correct: Yes (task 599 shows under 595, 596, and 598)
- No old "must complete first" labels in task order code: Confirmed

## Notes

The two occurrences of "must complete first" remaining in `.claude/agents/spawn-agent.md` and `.claude/extensions/core/agents/spawn-agent.md` are in documentation prose instructing agents NOT to use that phrase. They are unrelated to task order display labels.
