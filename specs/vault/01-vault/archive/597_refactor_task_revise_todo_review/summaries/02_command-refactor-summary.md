# Implementation Summary: Refactor /task, /revise, /todo, /review
- **Task**: 597 - Refactor /task, /revise, /todo, /review for consistency
- **Status**: [COMPLETED]
- **Started**: 2026-05-22T13:00:00Z
- **Completed**: 2026-05-22T14:30:00Z
- **Artifacts**: plans/02_command-refactor.md

## Overview

Refactored four secondary commands (/task, /revise, /todo, /review) for consistency with the new agent architecture, extracting 8 utility scripts and integrating memory harvest automation. The work spanned 8 phases across phases results artifacts, reducing total command file sizes and centralizing reusable logic into standalone bash scripts.

## What Changed

- `.claude/commands/revise.md` — Refactored from 160L to 125L; replaced inline CHECKPOINT 1/3 logic with shared command-gate-in.sh and command-gate-out.sh calls; added `--orchestrator` flag with `skill_write_orchestrator_handoff()` integration
- `.claude/commands/todo.md` — Refactored from 1046L to 630L; extracted archival, memory harvest, vault operation, roadmap sync, and orphan detection into dedicated scripts
- `.claude/commands/review.md` — Refactored from 1039L to 810L; extracted issue grouping, roadmap integration, and tier selection into dedicated scripts (810L vs ~450L target; see Deviations)
- `.claude/commands/task.md` — Minor updates, 710L to 714L (slight increase due to added recover-mode improvements)
- `.claude/scripts/memory-harvest.sh` — New 5808L script; harvests memory candidates from completed task artifacts with deduplication
- `.claude/scripts/archive-task.sh` — New 5223L script; handles task archival, state.json update, and TODO.md status transitions
- `.claude/scripts/orphan-detection.sh` — New 3865L script; detects orphaned task directories not referenced in state.json
- `.claude/scripts/roadmap-sync.sh` — New 11914L script; dual-phase scan+apply architecture for ROADMAP.md annotation with Python helper
- `.claude/scripts/vault-operation.sh` — New 8225L script; handles vault archival and task renumbering with jq-based state manipulation
- `.claude/scripts/issue-grouping.sh` — New 13709L script; Python 3-backed clustering algorithm for review issue grouping
- `.claude/scripts/roadmap-integration.sh` — New 16049L script; matches completed tasks against ROADMAP.md phases and checkboxes
- `.claude/scripts/tier-selection.sh` — New 10519L script; tier-based issue selection logic extracted from /review

## Decisions

- Python 3 used in issue-grouping.sh for the stateful clustering algorithm since jq lacks variable mutation; the algorithm logic was preserved verbatim from review.md
- roadmap-sync.sh split into dual-phase (scan + apply) architecture for correctness; the plan estimated ~210L but resulted in 331L due to the added phase-switching overhead
- memory-harvest.sh implemented as a top-level script body rather than wrapping in a named function (no benefit for a single-purpose invocation script)
- `vault-operation.sh` uses `jq -s 'length'` on newline-delimited objects for renumber count detection
- Recover-mode gate-in for /task (Task 5.3) was intentionally skipped: gate-in only supports the standard flow and recover mode already has adequate documentation via inline comments

## Plan Deviations

- **Phase 1 (memory-harvest.sh)**: Implemented as a plain script body rather than a named `harvest_memories()` function; equivalent logic, no functional impact
- **Phase 3 (roadmap-sync.sh)**: 331L vs plan estimate of ~210L due to dual-phase scan+apply architecture adding parameter parsing overhead
- **Phase 5 (task.md recover-mode gate-in)**: Task 5.3 intentionally skipped; recover mode gate-in not needed (anticipated in plan description)
- **Phase 6 (issue-grouping.sh)**: Python 3 used for clustering algorithm instead of pure bash/jq; Python available in execution environment
- **Phase 7 (review.md)**: 810L vs ~450L target; plan's line count estimates for extracted sections were approximately 2x actual sizes; all three sections correctly extracted but remaining inline logic outside Phase 7 scope was not touched

## Impacts

- /todo and /review now delegate complex multi-step logic to standalone scripts, making individual operations unit-testable independently
- memory-harvest.sh enables the /todo command to automatically surface memory candidates from completed tasks, closing a 47-task candidate gap
- /revise --orchestrator integration enables skill-orchestrate to chain /revise within automated pipelines without manual handoff
- All 8 new scripts pass `bash -n` syntax validation

## Follow-ups

- review.md is still 810L (vs original 1039L); further extraction of remaining inline logic could reduce it toward the ~450L target if desired
- task.md ended slightly higher (714L vs 710L) due to recover-mode improvements; no action needed
- roadmap-sync.sh Python helper is embedded in the shell script; could be factored into a dedicated .py file if it grows

## References

- `specs/597_refactor_task_revise_todo_review/plans/02_command-refactor.md`
- `specs/597_refactor_task_revise_todo_review/phases/02_phase-1-results.md` through `02_phase-7-results.md`
- `specs/597_refactor_task_revise_todo_review/phases/03_phase-2-results.md`
