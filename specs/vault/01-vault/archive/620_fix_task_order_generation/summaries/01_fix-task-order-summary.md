# Implementation Summary: Task #620

**Completed**: 2026-06-01
**Duration**: ~0.5 hours

## Overview

Fixed three issues in the Task Order generation pipeline: un-slugified the `project_name` fallback in `generate-task-order.sh` so tasks without a `description` field display readable space-separated text instead of underscore slugs, added a `/revise` postflight trigger (Stage 7a) for Task Order regeneration in `skill-reviser/SKILL.md`, and updated documentation in `state-management.md` and `task-order-format.md` to reflect the complete regeneration trigger table.

## What Changed

- `.claude/scripts/generate-task-order.sh` — Added `desc="${desc//_/ }"` after description loading in `build_graph()` to convert project_name slug fallbacks to readable text
- `.claude/skills/skill-reviser/SKILL.md` — Added Stage 7a between Stage 7 (status update) and Stage 8 (artifact linking) to call `generate-task-order.sh --update-todo` non-fatally after plan revision or description update
- `.claude/rules/state-management.md` — Added `/revise` row to the Regeneration Triggers table under Task Order Synchronization
- `.claude/context/formats/task-order-format.md` — Added "Full Regeneration Triggers" note to the `update-task-status.sh Integration` section listing all commands that trigger full regeneration

## Decisions

- Applied un-slugify to the description field unconditionally (not conditionally when description is null) since real descriptions rarely contain underscores, and the cosmetic improvement outweighs any minor impact on existing descriptions
- Added Stage 7a for both plan revision and description update paths in skill-reviser, since both cases may change how the task appears in the Task Order
- Marked Stage 9 git commit task as a deviation (skipped) since `git add -A` already captures the regenerated TODO.md without any modification needed

## Plan Deviations

- **Task 2.4** skipped: Stage 9 git commit already uses `git add -A` which captures the regenerated TODO.md; no change to commit step was needed

## Verification

- Build: N/A
- Tests: `bash .claude/scripts/generate-task-order.sh --print` runs without errors and produces well-formed output
- Files verified: Yes — all 4 modified files confirmed updated

## Notes

The un-slugify change is purely cosmetic and has no functional impact on dependency computation. The reviser trigger is non-fatal by design. Tasks 78 and 87 (which lack description fields) now display as "fix himalaya smtp authentication failure" and "investigate wezterm terminal directory change" instead of the underscore-separated project_name slugs.
