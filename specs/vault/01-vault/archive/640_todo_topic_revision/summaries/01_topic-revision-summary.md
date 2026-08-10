# Implementation Summary: Task #640

**Completed**: 2026-06-08
**Duration**: ~20 minutes

## Overview

Added topic revision functionality to the `/todo` skill and extended the `/task --sync` step 6.5 with a "New topic..." option. The `/todo` skill now prompts users to assign topics to uncategorized active tasks before archival (Stage 2.5) and removes orphaned topics from `active_topics` after archival (Stage 10.3). The `/task --sync` step 6.5 now mirrors the canonical Step 4.5 per-task picker pattern with "New topic..." free-text entry and `active_topics` maintenance.

## What Changed

- `.claude/skills/skill-todo/SKILL.md` — Added Stage 2.5 (TopicRevision) between Stage 2 and Stage 3, added Stage 10.3 (OrphanTopicCleanup) between Stage 10 and Stage 10.5, updated Stage 8 dry-run preview to include topic revision stats, updated Stage 16 output to include topic assignment counts, updated `<task>` element description
- `.claude/commands/task.md` — Expanded Step 6.5 from minimal stub to full per-task AskUserQuestion spec matching Step 4.5 pattern, including "New topic..." option, free-text follow-up, `active_topics` maintenance jq pattern, and per-task assignment jq pattern

## Decisions

- Stage 2.5 acts on ALL active non-terminal tasks missing a topic (not just the archival batch), giving a broader housekeeping opportunity before archival
- Stage 10.3 OrphanTopicCleanup checks after archival so topics freed by the just-archived tasks are correctly identified as orphaned
- Step 6.5 uses per-task (not multiSelect-all) prompting to match Step 4.5's UX pattern, showing one picker per uncategorized task
- jq uses `select(.status == "completed" | not)` throughout (Issue #1132 workaround)

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (markdown/XML specification files)
- Tests: N/A
- Files verified: Yes — stage ordering confirmed via grep; "New topic..." confirmed in task.md; no `!=` operators in new jq content

## Notes

- Stage 2.5 description notes that when `active_topics` is empty, only "New topic..." and "Skip (no topic)" are shown
- Stage 10.3 uses set-difference (`active_topics - referenced_topics`) to identify orphans cleanly
- The `specs/state.json.tmp` pattern is used for atomic jq writes (matches established codebase pattern)
