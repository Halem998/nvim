# Implementation Plan: Task #641

- **Task**: 641 - Fix meta-builder-agent topic assignment -- replace nonexistent keyword heuristic with interactive topic picker
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/641_meta_builder_topic_picker/reports/01_topic-picker-research.md
- **Artifacts**: plans/01_topic-picker-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The meta-builder-agent references a "keyword heuristic" for topic inference that does not exist anywhere in the codebase. The `/task` command uses an interactive AskUserQuestion picker for topic assignment, not keyword inference. This plan replaces the phantom heuristic with a real interactive topic picker (new Stage 4.5), renames Stage 3.5 from "AnalyzeTopics" to "AnalyzeConsolidation" to eliminate naming confusion with actual topic assignment, and updates the Stage 5 confirmation table and Stage 6 state.json entry to use the new `batch_topic` value. Cross-references in multi-task-creation-standard.md and meta-guide.md are also updated.

### Research Integration

Key findings from the research report:

- Line 676 of meta-builder-agent.md references a "keyword heuristic (same as `/task` topic inference)" that does not exist. The `/task` command uses an interactive AskUserQuestion picker (Step 4.5), not keyword inference.
- Stage 3.5 is named "AnalyzeTopics (Topic Clustering)" but performs task consolidation (merging related tasks), not topic assignment. Its group labels are display-only and never stored as `topic` field values.
- The correct fix is a new Stage 4.5 (TopicAssignment) presenting a batch topic picker modeled on `/task` Step 4.5, producing a single `batch_topic` for all tasks in the batch.
- The active_topics maintenance block at Stage 6 Step 4b (lines 1361-1376) is already correct and needs no changes -- it just needs `batch_topic` to be populated upstream.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace the nonexistent "keyword heuristic" reference with a working interactive topic picker
- Rename Stage 3.5 to eliminate naming confusion between task consolidation and topic assignment
- Ensure every `/meta`-created task gets a `topic` field when the user assigns one
- Update all cross-references in multi-task-creation-standard.md and meta-guide.md

**Non-Goals**:
- Per-task topic assignment within a batch (batch-level is the correct model for `/meta`)
- Changes to the `/task` command's own topic picker (Step 4.5 is the correct reference implementation)
- Changes to the active_topics maintenance logic (Stage 6 Step 4b is already correct)
- Changes to state-management-schema.md (schema is already correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage 3.5 rename breaks cross-references in other files | M | H | Grep found 5 files with references; all are updated in Phase 2 |
| Stage numbering confusion (inserting 4.5 between 4 and 5) | L | L | Follows existing convention -- Stage 3.5 already uses half-step numbering |
| Batch topic may be wrong for multi-domain `/meta` sessions | L | L | "Skip (no topic)" option provides escape hatch; document this |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Rename Stage 3.5 and add Stage 4.5 in meta-builder-agent.md [COMPLETED]

**Goal**: Rename Stage 3.5 from "AnalyzeTopics (Topic Clustering)" to "AnalyzeConsolidation (Task Consolidation)", add the new Stage 4.5 (TopicAssignment) section, and update Stages 5 and 6 to use `batch_topic`.

**Tasks**:
- [ ] Rename Stage 3.5 heading from `### Interview Stage 3.5: AnalyzeTopics (Topic Clustering)` to `### Interview Stage 3.5: AnalyzeConsolidation (Task Consolidation)`
- [ ] Change the AskUserQuestion header at line 468 from `"header": "Topic Consolidation"` to `"header": "Task Consolidation"`
- [ ] Add new `### Interview Stage 4.5: AssignTopic (Topic Assignment)` section between Stage 4 (AssessComplexity) and Stage 5 (ReviewAndConfirm). Content: read `active_topics` from state.json, present AskUserQuestion with options from active_topics plus "New topic..." and "Skip (no topic)", handle "New topic..." free-text follow-up, capture `batch_topic`
- [ ] Update Stage 5 confirmation table note (line 574) from "Topics are auto-inferred from task title/description; user can revise by selecting 'Revise'" to "Topic assigned via Stage 4.5 picker; applies to all tasks in this batch. User can revise by selecting 'Revise'."
- [ ] Replace the "Topic Auto-Inference" paragraph at line 676 with: "Write `batch_topic` (from Stage 4.5) to the `"topic"` field in each state.json entry. If `batch_topic` is null (user selected 'Skip'), omit the `topic` field."
- [ ] Verify the state.json entry template (lines 678-689) and the note on line 691 remain correct (they should -- `"topic": "agent-system"` is an example value, and the omit-if-null note is already present)

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` -- Stage 3.5 rename, new Stage 4.5, Stage 5 table note, Stage 6 topic auto-inference replacement

**Verification**:
- `grep -n "AnalyzeTopics" .claude/agents/meta-builder-agent.md` returns no results
- `grep -n "AnalyzeConsolidation" .claude/agents/meta-builder-agent.md` returns the Stage 3.5 heading
- `grep -n "AssignTopic" .claude/agents/meta-builder-agent.md` returns the new Stage 4.5 heading
- `grep -n "keyword heuristic" .claude/agents/meta-builder-agent.md` returns no results
- `grep -n "batch_topic" .claude/agents/meta-builder-agent.md` returns references in Stage 4.5, Stage 5, and Stage 6

---

### Phase 2: Update cross-references in multi-task-creation-standard.md and meta-guide.md [COMPLETED]

**Goal**: Update all files that reference the old "AnalyzeTopics" name or "Topic Clustering" stage name to use the new "AnalyzeConsolidation" / "Task Consolidation" naming.

**Tasks**:
- [ ] Update `.claude/docs/reference/standards/multi-task-creation-standard.md`:
  - Line 90: Change "Automatic Topic Clustering" to "Automatic Task Consolidation" and update the parenthetical to reference Stage 3.5 as "AnalyzeConsolidation"
  - Line 374: Change `AnalyzeTopics` to `AnalyzeConsolidation` and "Topic Clustering" to "Task Consolidation" in the table
  - Line 383: Change `Stage 3.5 (AnalyzeTopics)` to `Stage 3.5 (AnalyzeConsolidation)`
  - Line 400: Change "Automatic Topic Clustering (Stage 3.5)" to "Automatic Task Consolidation (Stage 3.5)"
- [ ] Update `.claude/extensions/core/docs/reference/standards/multi-task-creation-standard.md` with the same four changes (this is the extension copy)
- [ ] Update `.claude/context/meta/meta-guide.md` line 79: Change `### Stage 3.5: AnalyzeTopics (Topic Clustering)` to `### Stage 3.5: AnalyzeConsolidation (Task Consolidation)`
- [ ] Update `.claude/extensions/core/context/meta/meta-guide.md` line 79 with the same change (extension copy)

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/docs/reference/standards/multi-task-creation-standard.md` -- 4 text substitutions
- `.claude/extensions/core/docs/reference/standards/multi-task-creation-standard.md` -- 4 text substitutions (mirror)
- `.claude/context/meta/meta-guide.md` -- 1 heading rename
- `.claude/extensions/core/context/meta/meta-guide.md` -- 1 heading rename (mirror)

**Verification**:
- `grep -rn "AnalyzeTopics" .claude/` returns no results
- `grep -rn "Topic Clustering" .claude/` returns no results (in stage names; "Topic" may appear in other contexts)
- `grep -rn "AnalyzeConsolidation" .claude/` returns hits in all 5 updated files

---

### Phase 3: End-to-end verification and cleanup [COMPLETED]

**Goal**: Verify all changes are consistent and no broken references remain.

**Tasks**:
- [ ] Run `grep -rn "keyword heuristic" .claude/` to confirm zero results
- [ ] Run `grep -rn "AnalyzeTopics" .claude/` to confirm zero results
- [ ] Run `grep -rn "Topic Clustering" .claude/` and verify no stage-name references remain
- [ ] Run `grep -rn "Topic Consolidation" .claude/` and verify it has been replaced with "Task Consolidation" in the AskUserQuestion header
- [ ] Read the new Stage 4.5 section in meta-builder-agent.md and verify it follows the `/task` Step 4.5 pattern (AskUserQuestion with dynamic options from active_topics, "New topic..." with free-text follow-up, "Skip (no topic)")
- [ ] Verify the Stage 5 table note references Stage 4.5
- [ ] Verify the Stage 6 topic paragraph references `batch_topic` and no longer mentions "heuristic"

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification phase)

**Verification**:
- All grep checks return expected results (zero hits for removed terms, positive hits for added terms)
- Manual review of Stage 4.5 confirms AskUserQuestion structure matches `/task` Step 4.5 pattern

## Testing & Validation

- [ ] `grep -rn "keyword heuristic" .claude/` returns zero results
- [ ] `grep -rn "AnalyzeTopics" .claude/` returns zero results
- [ ] `grep -rn "AssignTopic" .claude/agents/meta-builder-agent.md` returns the new Stage 4.5 heading
- [ ] `grep -rn "batch_topic" .claude/agents/meta-builder-agent.md` returns references in Stages 4.5, 5, and 6
- [ ] `grep -rn "AnalyzeConsolidation" .claude/` returns hits in meta-builder-agent.md, multi-task-creation-standard.md (x2), and meta-guide.md (x2)
- [ ] `grep -rn "Task Consolidation" .claude/agents/meta-builder-agent.md` returns the AskUserQuestion header in Stage 3.5

## Artifacts & Outputs

- `specs/641_meta_builder_topic_picker/plans/01_topic-picker-plan.md` (this file)
- `.claude/agents/meta-builder-agent.md` (modified: Stage 3.5 rename, new Stage 4.5, Stage 5/6 updates)
- `.claude/docs/reference/standards/multi-task-creation-standard.md` (modified: cross-reference updates)
- `.claude/extensions/core/docs/reference/standards/multi-task-creation-standard.md` (modified: mirror)
- `.claude/context/meta/meta-guide.md` (modified: heading rename)
- `.claude/extensions/core/context/meta/meta-guide.md` (modified: mirror)

## Rollback/Contingency

All changes are text edits in markdown files with no executable side effects. Git revert of the implementation commit restores the prior state. The only risk is behavioral -- if the new Stage 4.5 instructions confuse the meta-builder-agent, the existing "Topic Auto-Inference" paragraph (which silently does nothing) is no worse. To revert: `git revert <commit-hash>`.
