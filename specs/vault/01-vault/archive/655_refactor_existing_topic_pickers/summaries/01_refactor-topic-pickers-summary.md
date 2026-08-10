# Implementation Summary: Task #655

**Completed**: 2026-06-10
**Duration**: ~30 minutes

## Overview

Replaced duplicated inline topic picker logic in 4 locations across 3 files with references to the shared `topic-assignment-pattern.md` document and calls to `manage-topics.sh`. Net reduction is approximately -111 lines of inline duplication. All extension copies in `.claude/extensions/core/` were synced after each live file edit.

## What Changed

- `.claude/commands/task.md` — Phase 1: Replaced Step 4.5 inline picker (38 lines) with 6-line pattern reference + `manage-topics.sh set` call. Phase 2: Replaced --sync Step 6.5 picker block (50 lines) with 5-line reference block; detection block (lines 353-363) preserved verbatim.
- `.claude/agents/meta-builder-agent.md` — Phase 3: Replaced Interview Stage 4.5 (55 lines) with 4-line pattern reference capturing `batch_topic`; replaced Stage 6 Step 4b (16 lines) with `manage-topics.sh add` loop + `manage-topics.sh set` calls.
- `.claude/skills/skill-todo/SKILL.md` — Phase 4: Inserted new Stage 2.5 TopicRevision between Stage 2 (ScanTasks) and Stage 3 (DetectOrphans) using Mode A pattern reference.
- `.claude/extensions/core/commands/task.md` — Synced copy of task.md
- `.claude/extensions/core/agents/meta-builder-agent.md` — Synced copy of meta-builder-agent.md
- `.claude/extensions/core/skills/skill-todo/SKILL.md` — Synced copy of SKILL.md

## Decisions

- Used `manage-topics.sh set` (not `add`) for the single-task assignment cases since `set` internally calls `add` (idempotent)
- Kept the `manage-topics.sh add` loop in meta-builder Stage 6 Step 4b to register batch topics before the per-task `set` calls, matching the original intent of the inline jq loop
- Stage 2.5 in skill-todo is purely additive — no existing stages were modified

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (documentation files only)
- Tests: N/A
- Files verified: Yes — grep confirms no inline `active_topics` jq remains in any modified file; all 3 files reference `topic-assignment-pattern.md` and call `manage-topics.sh`; all extension copies diff-identical to live files

## Notes

All edited files are markdown/documentation files with no runtime impact. The detection block in task.md --sync Step 6.5 (`missing_topics` jq query) was preserved verbatim. meta-builder Interview Stage 5 (ReviewAndConfirm) was untouched. skill-todo Stage 3 (DetectOrphans) was untouched.
