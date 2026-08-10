# Implementation Summary: Task #582

## Metadata

- **Task**: 582 - Port command integration (task.md, todo.md, review.md)
- **Status**: [COMPLETED]
- **Started**: 2026-05-15T00:00:00Z
- **Completed**: 2026-05-15T01:00:00Z
- **Artifacts**: plans/01_port-command-integration.md

## Overview

Ported topic picker, task order auto-sync, and simplified Task Order management from the ProofChecker agent system into the nvim-config command files (task.md, todo.md, review.md). All ProofChecker-specific hardcoded topic keywords were replaced with dynamic `active_topics` from state.json. The manual 639-line Task Order management in review.md was replaced with a single `generate-task-order.sh` call plus a simplified goal-update prompt.

## What Changed

- `.claude/commands/task.md` — Added Step 4.5 (dynamic topic picker from `active_topics`), updated Step 6 jq to include conditional topic field with `| not` pattern, replaced old `update-recommended-order.sh` Part C call with `generate-task-order.sh --update-todo`, added Expand Mode Step 2.5 (parent topic inheritance), added Sync Mode Step 6 regen call + Step 6.5 (topic backfill picker), added Review Mode Step 7.5 (parent topic read) and updated Step 8 jq to inherit topic
- `.claude/commands/todo.md` — Added Step 5.8 (post-archival Task Order regeneration after metrics sync), added Step 5.8.8a (post-vault renumbering regen), updated git commit message note to append ", regenerate task order" when regen ran
- `.claude/commands/review.md` — Replaced Section 2.6 category-based parsing with wave+tree parsing (`waves[]` + `tree_entries[]`); added Section 5.6.3 Step 3 extension-aware topic inference (`.claude/`/`specs/` → meta/agent-system, `lua/`/`after/` → neovim topics); replaced Sections 6.5-6.7 (~639 lines of manual Task Order management) with simplified Section 6.5 (single `generate-task-order.sh` call), Section 6.6 tombstone, and Section 6.7 (skip conditions + summary + goal statement update only); updated Section 7 commit message to `{regenerated_or_skipped}` format; updated Standards Reference Dependencies row to `Partial`

## Decisions

- No hardcoded topic keywords: all topic options read dynamically from `active_topics` in state.json; when empty, only "New topic..." and "Skip (no topic)" fallbacks shown
- Sync Mode Step 6 regen call added (present in ProofChecker but not noted in research report); included because Sync Mode reconciles state.json and TODO.md so a regen is appropriate
- Used `| not` pattern throughout for jq empty-string checks to avoid Issue #1132 (`!=` escaping)
- Extension-aware topic inference in review.md uses broad pattern matching (`*neovim*|*nvim*|*lua*`) so it generalizes to future neovim-related topic names

## Plan Deviations

- **Task 2.2** altered: Sync Mode addition included a Step 6 Task Order regen call (present in ProofChecker reference) that was not explicitly listed as a separate checklist item in the plan but was added for completeness consistent with the ProofChecker version

## Impacts

- `/task` command now prompts for topic assignment at creation time
- `/task --expand` propagates parent topic to subtasks
- `/task --sync` detects and offers to backfill topics for existing tasks
- `/task --review` propagates parent topic to follow-up tasks
- `/todo` regenerates Task Order after archival and after vault renumbering
- `/review` parses wave+tree format, infers topics from file paths, uses script for Task Order rather than manual management (~531 line reduction in review.md)

## Follow-ups

- `active_topics` initialization guidance: state-management-schema.md could note that `active_topics` defaults to `[]` and is populated organically via the `/task` picker
- Sync Mode topic backfill could be enhanced with lightweight keyword inference once `active_topics` is established in the nvim-config project

## References

- Plan: `specs/582_port_command_integration/plans/01_port-command-integration.md`
- Research: `specs/582_port_command_integration/reports/01_port-command-integration.md`
- ProofChecker reference: `/home/benjamin/Projects/ProofChecker/.claude/commands/`
