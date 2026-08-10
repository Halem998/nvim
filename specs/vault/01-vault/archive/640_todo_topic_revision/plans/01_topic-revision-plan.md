# Implementation Plan: Add topic revision to /todo and "New topic..." to /task --sync

- **Task**: 640 - Add topic revision stage to /todo skill and "New topic..." option to /task --sync backfill
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/640_todo_topic_revision/reports/01_topic-revision-research.md
- **Artifacts**: plans/01_topic-revision-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The agent system supports a `topic` field on task entries and an `active_topics` array in state.json, but two key entry points lack full topic functionality: `/todo` has zero topic handling, and `/task --sync` Step 6.5 lacks a "New topic..." option. This plan adds a new Stage 2.5 (TopicRevision) to skill-todo for assigning topics to uncategorized tasks before archival, adds orphan topic cleanup after archival in Stage 10, and extends `/task --sync` Step 6.5 with "New topic..." + free-text follow-up using the canonical pattern from Step 4.5.

### Research Integration

Research report `01_topic-revision-research.md` confirmed:
- skill-todo has zero topic awareness across all 16 stages
- Best insertion point: Stage 2.5 between ScanTasks (Stage 2) and DetectOrphans (Stage 3)
- Step 4.5 in `/task` create mode is the canonical AskUserQuestion pattern with "New topic..." (lines 133-169 of task.md)
- Step 6.5 (lines 373-389 of task.md) only shows existing `active_topics` -- no "New topic..." option
- Orphan topic cleanup belongs after Stage 10 archival, before Stage 10.5 regeneration
- jq access patterns and schema constraints are fully documented

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation requested.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add Stage 2.5 (TopicRevision) to skill-todo/SKILL.md so `/todo` prompts users to assign topics to uncategorized tasks before archival
- Add orphan topic cleanup sub-step after Stage 10 archival to remove unreferenced topics from `active_topics`
- Add "New topic..." option and free-text follow-up to `/task --sync` Step 6.5 backfill picker
- Reuse the canonical AskUserQuestion topic picker pattern from `/task` Step 4.5

**Non-Goals**:
- Changing the topic picker in Step 4.5 (it already works correctly)
- Adding topic auto-inference heuristics (the system is explicitly picker-based)
- Modifying generate-task-order.sh (it already handles topics correctly)
- Touching state.json schema (the `topic` and `active_topics` fields already exist)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage 2.5 adds latency when many tasks lack topics | L | M | Skip entirely when zero uncategorized tasks in archival batch |
| "New topic..." creates duplicate via case mismatch | M | L | jq index check is case-sensitive; document kebab-case-lowercase convention in picker description |
| Orphan cleanup removes topic still used by archived tasks | L | L | Orphan check only scans active_projects, not archive; this is acceptable since archive is read-only |
| SKILL.md stage numbering disruption | M | L | Use 2.5 (fractional) numbering to avoid renumbering existing stages |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add Stage 2.5 and orphan cleanup to skill-todo/SKILL.md [COMPLETED]

**Goal**: Insert topic revision stage and orphan topic cleanup into the /todo archival workflow.

**Tasks**:
- [x] Insert new `<stage id="2.5" name="TopicRevision">` between Stage 2 (ScanTasks) and Stage 3 (DetectOrphans) in SKILL.md *(completed)*
- [x] Stage 2.5 process: detect archival-batch tasks with null/empty `topic` field using jq query against state.json *(completed)*
- [x] Stage 2.5 process: if uncategorized tasks found, read `active_topics` from state.json and present per-task AskUserQuestion with options: existing topics + "New topic..." + "Skip (no topic)" *(completed)*
- [x] Stage 2.5 process: if "New topic..." selected, follow-up free-text AskUserQuestion for topic name, then append to `active_topics` if not already present (using jq index() check) *(completed)*
- [x] Stage 2.5 process: write topic assignments to state.json immediately via jq (so Stage 10 archival copies the full task entry including topic) *(completed)*
- [x] Stage 2.5 process: if zero uncategorized tasks in batch, skip stage entirely with no prompt *(completed)*
- [x] Insert new `<stage id="10.3" name="OrphanTopicCleanup">` between Stage 10 (ArchiveTasks) and Stage 10.5 (RegenerateTaskOrder) *(completed)*
- [x] Stage 10.3 process: after archival, detect topics in `active_topics` not referenced by any remaining active non-terminal task *(completed)*
- [x] Stage 10.3 process: if orphan topics found, present AskUserQuestion multiSelect to remove selected orphans from `active_topics` array *(completed)*
- [x] Stage 10.3 process: if no orphan topics, skip stage silently *(completed)*
- [x] Update Stage 8 (DryRunOutput) preview block to include topic revision stats: count of uncategorized tasks in archival batch *(completed)*
- [x] Update the `<task>` element description to mention topic revision *(completed)*
- [x] Update Stage 16 (OutputResults) summary to include topic assignment count *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` -- insert Stage 2.5 (TopicRevision), Stage 10.3 (OrphanTopicCleanup), update Stages 8 and 16

**Verification**:
- Stage 2.5 XML block exists between Stage 2 and Stage 3 with correct id and name attributes
- Stage 10.3 XML block exists between Stage 10 and Stage 10.5 with orphan detection jq and AskUserQuestion
- Stage 8 DryRunOutput mentions topic revision stats
- Stage 16 OutputResults mentions topic assignment count
- All jq commands use `select(.status == "completed" | not)` pattern (not `!=`) per jq-escaping-workarounds.md
- The `<task>` element includes topic revision in its description

---

### Phase 2: Add "New topic..." to /task --sync Step 6.5 [COMPLETED]

**Goal**: Extend the `/task --sync` topic backfill picker with "New topic..." option and free-text follow-up, matching the canonical pattern from Step 4.5.

**Tasks**:
- [x] Expand Step 6.5 in task.md to show full AskUserQuestion JSON spec with options: existing `active_topics` entries + "New topic..." + "Skip (no topic)" *(completed)*
- [x] Add "New topic..." handling: free-text AskUserQuestion follow-up for topic name input *(completed)*
- [x] Add `active_topics` maintenance: append new topic to array if not already present (reuse jq pattern from Step 4.5 lines 162-169) *(completed)*
- [x] Ensure the per-task assignment jq pattern applies the selected topic correctly *(completed)*
- [x] Add descriptive comment noting this mirrors the Step 4.5 pattern *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` -- expand Step 6.5 (lines 373-389) with "New topic..." option, free-text follow-up, and `active_topics` maintenance

**Verification**:
- Step 6.5 AskUserQuestion JSON includes "New topic..." and "Skip (no topic)" options alongside existing topics
- Free-text follow-up prompt exists for "New topic..." selection
- jq `active_topics` append pattern matches Step 4.5 (lines 162-169)
- Per-task assignment jq pattern is present
- No use of `!=` in jq commands

## Testing & Validation

- [x] Read SKILL.md after edits and verify Stage 2.5 is positioned between Stage 2 and Stage 3 *(completed)*
- [x] Read SKILL.md after edits and verify Stage 10.3 is positioned between Stage 10 and Stage 10.5 *(completed)*
- [x] Read task.md after edits and verify Step 6.5 contains "New topic..." option *(completed)*
- [x] Verify all jq commands in new content use safe `| not` pattern instead of `!=` *(completed)*
- [x] Verify XML stage id attributes use correct fractional numbering (2.5, 10.3) *(completed)*
- [x] Verify no duplicate stage ids exist in SKILL.md *(completed)*
- [x] Grep for "topic" in SKILL.md to confirm new stages appear and no unintended changes elsewhere *(completed)*

## Artifacts & Outputs

- `specs/640_todo_topic_revision/plans/01_topic-revision-plan.md` (this file)
- `.claude/skills/skill-todo/SKILL.md` (modified)
- `.claude/commands/task.md` (modified)

## Rollback/Contingency

Both changes are additive insertions into existing markdown/XML specification files. If either change causes issues:
- Stage 2.5: Remove the `<stage id="2.5">...</stage>` block and revert Stage 8/16 edits
- Stage 10.3: Remove the `<stage id="10.3">...</stage>` block
- Step 6.5: Revert to the original 17-line block (lines 373-389 of task.md)
- Git revert of the implementation commit restores all files to their pre-change state
