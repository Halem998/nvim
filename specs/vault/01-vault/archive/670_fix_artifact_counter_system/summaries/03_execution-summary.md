# Implementation Summary: Task #670

**Completed**: 2026-06-14
**Duration**: ~30 minutes

## Overview

Fixed 4 bugs in the artifact counter system (`next_artifact_number` in state.json) that caused filename collisions, counter drift, and confusing numbering in multi-revision workflows. The core fix adds disk reconciliation and collision detection to all skill files that generate artifact numbers, plus makes the reviser skill increment the counter on each revision. Documentation was updated to clarify that `plan_version` is metadata-only and never appears in filenames.

## What Changed

- `.claude/skills/skill-reviser/SKILL.md` — Bug 1+2+3 fix: Stage 3a now uses `next_num` directly (not `next_num - 1`), adds disk reconciliation via `find`+`sed`, adds collision loop; Stage 8a added to increment `next_artifact_number` after each revision
- `.claude/skills/skill-planner/SKILL.md` — Bug 2+3 fix: Stage 3a now has disk reconciliation and collision detection loop; does NOT increment counter (preserves round-sharing semantics)
- `.claude/skills/skill-researcher/SKILL.md` — Bug 2+3 fix: Stage 3a now has disk reconciliation (with state.json sync if advanced) and collision detection loop
- `.claude/skills/skill-team-research/SKILL.md` — Bug 2+3 fix: Stage 5a now has disk reconciliation (with state.json sync if advanced) and collision detection loop
- `.claude/context/formats/plan-format.md` — Bug 4 fix: Added clarifying note that `plan_version` is metadata-only and does NOT appear in filenames; artifact filenames use `next_artifact_number`
- `.claude/rules/artifact-formats.md` — Bug 4 fix: Added "Revision" to the Round Concept bullet list; updated example flow to show revision producing sequential numbers (02, 03) before next research round (04)
- `.claude/extensions/core/skills/skill-reviser/SKILL.md` — Synced from live copy (byte-identical)
- `.claude/extensions/core/skills/skill-planner/SKILL.md` — Synced from live copy (byte-identical)
- `.claude/extensions/core/skills/skill-researcher/SKILL.md` — Synced from live copy (byte-identical)
- `.claude/extensions/core/skills/skill-team-research/SKILL.md` — Synced from live copy (byte-identical)

## Decisions

- Reconciliation pattern uses `find` + `sed` to extract `NN` prefix from all `[0-9][0-9]_*.md` files in all task subdirectories, then takes the max. This is safe: only strictly-prefixed files match, and non-matching filenames are silently ignored.
- `max_on_disk=$((10#$max_on_disk))` is used to strip leading zeros and prevent bash from interpreting octal (e.g., `08` would error without this).
- For skill-researcher and skill-team-research: when reconciliation advances the counter, state.json is updated immediately so the subsequent `next_artifact_number` increment in Stage 7 produces a correct final value.
- For skill-reviser: the counter increment (new Stage 8a) is conditional on `artifact_path` being non-empty (i.e., only increment when a plan was actually created), preventing counter drift on failed revisions.
- Stage 8a (old TTS notification) was renamed to Stage 8b in skill-reviser to accommodate the new Stage 8a counter increment.

## Plan Deviations

- None (implementation followed plan exactly)

## Verification

- Build: N/A (markdown skill files)
- Tests: N/A
- Files verified: All 4 live/core pairs confirmed byte-identical via `diff`
- Traced happy path: research(1)->plan(1)->revise(2)->revise(3)->research(4)->plan(4) is now monotonic

## Notes

The plan noted that Bug 4 (`plan_version` confusion) would be "resolved naturally" by the Bug 1 fix making artifact numbers monotonic. The documentation update in Phase 3 makes this explicit for future readers. The `plan_version` field itself was not modified -- it remains useful metadata for tracking semantic revision history.
