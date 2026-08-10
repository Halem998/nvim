# Implementation Summary: Task #649

**Completed**: 2026-06-10
**Duration**: ~1 hour

## Overview

Refactored the task status update pipeline from a dual-write model (state.json + direct TODO.md awk/sed surgery) to a state.json-first model where TODO.md is regenerated from state.json via `generate-todo.sh`. All primary callers of `link-artifact-todo.sh` were updated across 14 files. Old code paths are preserved as logged fallbacks in `update-task-status.sh` behind a `PIPELINE_MODE` guard.

## What Changed

- `.claude/scripts/update-task-status.sh` — Added `PIPELINE_MODE` variable (default: `new`), `log_deprecation()` helper, `regenerate_todo()` function; wrapped Phases 2+3 (awk/sed TODO.md surgery) in `PIPELINE_MODE=legacy` guard with deprecation logging; removed `todo_failed` variable and exit code 3
- `.claude/scripts/skill-base.sh` — Replaced `link-artifact-todo.sh` call in `skill_link_artifacts()` with `generate-todo.sh` call
- `.claude/scripts/postflight-workflow.sh` — Added `generate-todo.sh` call after Step 3 (artifact add)
- `.claude/scripts/link-artifact-todo.sh` — Added deprecation header comment and runtime logging to `.claude/logs/deprecation.log` on every invocation
- `.claude/scripts/reconcile-task-status.sh` — Added deprecation logging inline (deferred migration per plan; script still calls `link-artifact-todo.sh`)
- `.claude/skills/skill-orchestrate/SKILL.md` — Replaced 2 `link-artifact-todo.sh` case blocks with `generate-todo.sh` calls
- `.claude/skills/skill-reviser/SKILL.md` — Replaced `link-artifact-todo.sh` call with `generate-todo.sh` call
- `.claude/extensions/core/skills/skill-researcher/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-planner/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-reviser/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-team-plan/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-team-implement/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/skills/skill-team-research/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/skills/skill-project-overview/SKILL.md` — Replaced `link-artifact-todo.sh` with `generate-todo.sh`
- `.claude/extensions/core/scripts/skill-base.sh` — Replaced `link-artifact-todo.sh` call with `generate-todo.sh`
- `.claude/rules/artifact-formats.md` — Updated PROHIBITION note to reference `generate-todo.sh`
- `.claude/extensions/core/rules/artifact-formats.md` — Updated PROHIBITION note
- `.claude/context/patterns/artifact-linking-todo.md` — Added deprecation notice
- `.claude/extensions/core/context/patterns/artifact-linking-todo.md` — Added deprecation notice

## Decisions

- The `PIPELINE_MODE=legacy` fallback preserves exact existing awk/sed behavior for emergency rollback
- `reconcile-task-status.sh` migration deferred to task 652 (recovery tool needs separate analysis)
- Extension core skill copies were updated in addition to primary `.claude/skills/` files since both are active

## Plan Deviations

- **Additional files updated**: The plan identified primary `.claude/skills/` files only; extension core skills in `.claude/extensions/core/skills/` also had `link-artifact-todo.sh` calls and were updated (6 additional files beyond the plan scope). Same change, broader coverage.

## Verification

- Build: N/A
- Tests: `generate-todo.sh` produces valid TODO.md output; `update-task-status.sh --dry-run` shows new pipeline path; `PIPELINE_MODE=legacy` dry-run shows deprecation log entries; final audit shows only `reconcile-task-status.sh` retains `link-artifact-todo.sh` calls (deferred per plan)
- Files verified: Yes

## Notes

The rollback path is `PIPELINE_MODE=legacy` which restores the old awk/sed TODO.md update behavior. Task 652 performs final cleanup after confirming zero legacy usage via the deprecation log at `.claude/logs/deprecation.log`.
