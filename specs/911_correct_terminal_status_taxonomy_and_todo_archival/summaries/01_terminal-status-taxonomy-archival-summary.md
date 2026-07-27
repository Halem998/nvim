# Implementation Summary: Task #911

**Completed**: 2026-07-26
**Duration**: ~1.5 hours

## Overview

`/todo`'s archival scan previously matched only `status == "completed"` and `status ==
"abandoned"`, so tasks that reach the genuinely-terminal `expanded` state could never be
archived. This implementation widens both archival sites — `commands/todo.md` and
`skills/skill-todo/SKILL.md` — to include `expanded`, routes those tasks into
`completed_projects` (no third archive array), excludes them from ROADMAP.md matching the same
way meta tasks already are, and adds a subtasks-defer guard that holds back an expanded parent
while any of its `subtasks[]` is still non-terminal. Separately, the one documentation line in
`merge-sources/claudemd.md` that conflated `BLOCKED`/`PARTIAL` with `ABANDONED`/`EXPANDED` under a
single "Terminal/exception states" label is split into two correctly-labelled bullets.

## What Changed

- `agent-system/extensions/core/merge-sources/claudemd.md` — split the single conflated
  "Terminal/exception states" bullet into two bullets: `[ABANDONED]`, `[EXPANDED]` (terminal) and
  `[BLOCKED]`, `[PARTIAL]` (non-terminal exception states), agreeing with
  `context/standards/status-markers.md`.
- `agent-system/extensions/core/commands/todo.md` — widened the scan, the roadmap-exclusion
  buckets (renamed `meta_tasks[]`/`non_meta_tasks[]` to `roadmap_excluded_tasks[]`/
  `roadmap_eligible_tasks[]`), the Step 5A/5B archive routing, the Step 5D directory-move loop,
  the dry-run template, the Step 7 output, and the Notes section to cover `expanded` alongside
  `completed`/`abandoned`. Added a subtasks-defer guard in Step 3 (`archivable_tasks[]` /
  `deferred_expanded[]` / `deferred_expanded_nums[]`) and amended the Step 5B `del()` filter to
  subtract deferred parent numbers so a deferred expanded parent is never silently dropped from
  `active_projects`.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — mirrored all of the above: Stage 2
  `ScanTasks` now identifies `expanded` tasks and applies the identical subtasks-defer guard;
  Stage 5 `ScanRoadmap` excludes expanded tasks with the same structural reasoning; Stage 7
  `HarvestMemories` gained a note that expanded tasks are deliberately not harvested; Stage 10
  `ArchiveTasks` routes expanded to `completed_projects` and consumes the guard-filtered list for
  all four sub-steps; Stages 8, 13, 15, and 16 report/record expanded and deferred counts.

## Decisions

- Kept the `del()` pattern (never `map(select(... != ...))`) per the Issue #1132-safe convention
  already established in both files.
- Used a `case` statement for status classification in the guard, rather than `!=` comparisons,
  per the same convention.
- Left Stage 2.5 `TopicRevision` in `skill-todo/SKILL.md` untouched — it already excluded
  `expanded` alongside `completed`/`abandoned`, confirming the omission fixed elsewhere was an
  incremental-maintenance gap rather than a design decision.
- Left `commands/todo.md`'s Step 3.5.2 (`completed_with_summaries` extraction) untouched — it is
  dead code (the value it computes is never referenced elsewhere in the file) and was outside the
  plan's explicit rename scope.

## Plan Deviations

- **Phase 3, Step 5B `del()` filter**: the plan's literal jq snippet
  `($deferred | index(.project_number))` does not parse the way intended — after the `$deferred |`
  pipe, `.` inside `index()`'s argument rebinds to `$deferred` itself (an array) rather than to
  the array element under test, so jq raises `Cannot index array with string "project_number"`.
  This was caught by testing the filter against a representative `state.json` fixture before
  claiming completion, as required. Fixed by binding the element first:
  `. as $item | ($deferred | index($item.project_number))`, then re-verified end-to-end against
  the same fixture (both the guard partitioning and the corrected `del()` filter behave exactly
  as the plan specifies: deferred parents survive the removal, non-deferred completed/abandoned/
  expanded tasks are removed, non-terminal tasks and terminal subtasks are untouched). The same
  corrected form was mirrored into `skill-todo/SKILL.md`'s guard description.

## Verification

- Build: N/A (markdown command/skill definitions, no build step)
- Tests: N/A (no executable test suite for these files; validated by targeted inspection and a
  live jq fixture test — see Plan Deviations)
- Files verified: Yes — all three in-scope files modified; `git status --short .claude/` empty
  throughout; no `!=` introduced into executable jq; no new task-number citations introduced
  (confirmed via `git diff` against the two pre-existing hits found by grep)

## Notes

- The Step 5B jq filter fix (see Plan Deviations) is the single most load-bearing correctness
  detail in this task, per the plan's own risk assessment — it was tested end-to-end against a
  synthetic `state.json` with nine tasks covering all four subtasks-defer-guard edge cases
  (missing subtasks, terminal subtask, non-terminal subtask, subtask absent from
  `active_projects`) before being committed.
- Cross-task artifact-path reachability beyond the parent/child subtasks-defer guard remains a
  known, pre-existing limitation of archival (plain directory `mv`, plus vault renumbering) — out
  of scope per the plan's explicit non-goals, and documented as such in both archival sites' Notes
  sections.
