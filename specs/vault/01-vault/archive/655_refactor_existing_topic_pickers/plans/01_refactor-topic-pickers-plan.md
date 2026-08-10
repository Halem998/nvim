# Implementation Plan: Task #655

- **Task**: 655 - refactor_existing_topic_pickers
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 654 (create_topic_management_utilities) -- COMPLETED
- **Research Inputs**: specs/655_refactor_existing_topic_pickers/reports/01_refactor-topic-pickers.md
- **Artifacts**: plans/01_refactor-topic-pickers-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace duplicated inline topic picker logic across 4 locations in the agent system with references to the shared `topic-assignment-pattern.md` and calls to `manage-topics.sh` (both created by task 654). Three locations are pure replacements of existing inline code; one (skill-todo Stage 2.5) is an additive new stage. After each live file is edited, its extension copy in `.claude/extensions/core/` must be synced. The net effect is approximately -111 lines of inline duplication replaced by canonical pattern references.

### Research Integration

Research report (`01_refactor-topic-pickers.md`) confirmed:
- All 4 locations use Mode A (Interactive) from the pattern document
- Extension copies are identical to live files (zero-diff confirmed)
- `manage-topics.sh set` internally calls `add`, so a single `set` call suffices per topic assignment
- meta-builder has two edit points: Interview Stage 4.5 (picker) and Stage 6 Step 4b (deferred state update loop)
- task.md --sync detection block (lines 353-363) must be preserved; only the picker and maintenance blocks are replaced

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace inline topic picker logic in `commands/task.md` Step 4.5 (lines 133-170) with pattern reference and script calls
- Replace inline topic picker logic in `agents/meta-builder-agent.md` Interview Stage 4.5 (lines 552-606) and Stage 6 Step 4b (lines 1359-1374) with pattern reference and script calls
- Replace inline topic picker logic in `commands/task.md` --sync Step 6.5 (lines 364-413) with pattern reference and script calls, preserving the detection block (lines 351-363)
- Add new Stage 2.5 TopicRevision to `skills/skill-todo/SKILL.md` using Mode A pattern reference
- Sync all extension copies in `.claude/extensions/core/` after each live file edit
- Achieve approximately -111 lines net reduction across all files

**Non-Goals**:
- Modifying the shared utilities themselves (manage-topics.sh, topic-assignment-pattern.md)
- Changing topic picker behavior or UI wording (purely structural refactor)
- Updating any files outside the 4 target locations and their extension copies

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension copies drift from live files | M | L | Copy live file to extension path after each edit; verify with diff |
| Detection block in --sync Step 6.5 accidentally removed | H | L | Phase 2 instructions explicitly preserve lines 351-363; verification step diffs before/after |
| meta-builder Stage 6 Step 4b edit missed | M | M | Plan calls out both edit points in Phase 3 as separate checklist items |
| Incorrect line offsets due to prior edits in same file | M | M | Phase 1 and Phase 2 both edit task.md; Phase 2 must account for line shifts from Phase 1 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Refactor commands/task.md Step 4.5 (Create Task topic picker) [COMPLETED]

**Goal**: Replace 38 lines of inline topic picker in Step 4.5 (lines 133-170) with a pattern reference and manage-topics.sh calls.

**Tasks**:
- [ ] Read `.claude/commands/task.md` lines 125-185 to confirm exact boundaries
- [ ] Replace lines 133-170 (inline jq reads, AskUserQuestion picker, "New topic..." handling, active_topics maintenance) with a concise reference block:
  - Reference `@.claude/context/patterns/topic-assignment-pattern.md` (Mode A: Interactive)
  - After topic selection, call `bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"`
  - Preserve the step numbering (4.5) and purpose header
- [ ] Verify the surrounding steps (4 and 5) remain intact and contextually connected
- [ ] Copy edited live file to extension: `cp .claude/commands/task.md .claude/extensions/core/commands/task.md`
- [ ] Verify sync: `diff .claude/commands/task.md .claude/extensions/core/commands/task.md`

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Replace Step 4.5 inline picker (lines 133-170) with pattern reference
- `.claude/extensions/core/commands/task.md` - Sync copy of above

**Verification**:
- Step 4.5 references `topic-assignment-pattern.md` (Mode A) and calls `manage-topics.sh set`
- No inline jq for `active_topics` remains in Step 4.5
- Step 5 (Create slug) follows immediately after the replacement block
- Extension copy is identical to live file

---

### Phase 2: Refactor commands/task.md --sync Step 6.5 (topic backfill picker) [COMPLETED]

**Goal**: Replace 50 lines of inline backfill picker in --sync Step 6.5 (lines 364-413) with pattern reference and script calls, while preserving the detection block (lines 351-363).

**Tasks**:
- [ ] Read `.claude/commands/task.md` from the --sync section to confirm boundaries (note: line numbers will have shifted after Phase 1 edits if run sequentially; use content matching, not absolute line numbers)
- [ ] Preserve the detection block intact:
  - Step 6.5 header and purpose
  - The `missing_topics` jq query that identifies tasks needing backfill (original lines 353-363)
  - The "If any tasks need backfill" conditional gate
- [ ] Replace the picker interaction block (original lines 364-413) with:
  - Reference to `@.claude/context/patterns/topic-assignment-pattern.md` (Mode A, per-task backfill variant)
  - Note: loop over detected tasks with header "Topic Backfill ({i} of {total})"
  - After each topic selection: `bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"`
  - Remove the inline `active_topics` maintenance jq and the separate "apply assignments" jq
- [ ] Verify step 7 (Git commit) follows the replacement block
- [ ] Copy edited live file to extension (same cp as Phase 1, since it is the same file)
- [ ] Verify sync with diff

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Replace --sync Step 6.5 picker block (lines 364-413), keep detection block (lines 351-363)
- `.claude/extensions/core/commands/task.md` - Sync copy of above

**Verification**:
- Detection block (`missing_topics` jq) is preserved verbatim
- Picker block references `topic-assignment-pattern.md` (Mode A) and calls `manage-topics.sh set`
- No inline jq for `active_topics` remains in Step 6.5 picker section
- Step 7 follows the replacement block
- Extension copy matches live file

---

### Phase 3: Refactor agents/meta-builder-agent.md (two edit points) [COMPLETED]

**Goal**: Replace Interview Stage 4.5 (55 lines, lines 552-606) and Stage 6 Step 4b (16 lines, lines 1359-1374) with pattern references and manage-topics.sh calls.

**Tasks**:
- [ ] Read `.claude/agents/meta-builder-agent.md` lines 545-615 to confirm Stage 4.5 boundaries
- [ ] Replace Interview Stage 4.5 (lines 552-606) with a concise reference block:
  - Keep the heading `### Interview Stage 4.5: AssignTopic (Topic Assignment)`
  - Keep the purpose description (1 sentence)
  - Reference `@.claude/context/patterns/topic-assignment-pattern.md` (Mode A: Interactive, batch variant)
  - Note: question wording is plural ("Assign a topic to these tasks?")
  - Note: captures `batch_topic` for use in Stage 5 confirmation and Stage 6 state update
  - Do NOT include inline jq, AskUserQuestion JSON, or active_topics maintenance
- [ ] Read `.claude/agents/meta-builder-agent.md` lines 1350-1385 to confirm Stage 6 Step 4b boundaries (note: line numbers will shift after Stage 4.5 edit)
- [ ] Replace Stage 6 Step 4b (lines 1359-1374) with manage-topics.sh calls:
  - Keep the step header `4b. **Update active_topics**`
  - Replace the inline jq loop with:
    ```bash
    for topic in "${new_topics[@]}"; do
      [[ -z "$topic" ]] && continue
      bash .claude/scripts/manage-topics.sh add "$topic"
    done
    ```
  - Then for each task: `bash .claude/scripts/manage-topics.sh set "$task_num" "$batch_topic"`
  - Keep the explanatory note about topics already in active_topics being skipped
- [ ] Verify Interview Stage 5 follows after the Stage 4.5 replacement
- [ ] Verify Step 4a (generate-todo.sh) follows after the Step 4b replacement
- [ ] Copy edited live file to extension: `cp .claude/agents/meta-builder-agent.md .claude/extensions/core/agents/meta-builder-agent.md`
- [ ] Verify sync with diff

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Replace Interview Stage 4.5 (lines 552-606) and Stage 6 Step 4b (lines 1359-1374) with pattern references and script calls
- `.claude/extensions/core/agents/meta-builder-agent.md` - Sync copy of above

**Verification**:
- Interview Stage 4.5 references `topic-assignment-pattern.md` (Mode A, batch variant) and captures `batch_topic`
- No inline jq for `active_topics` or AskUserQuestion JSON remains in Stage 4.5
- Stage 6 Step 4b uses `manage-topics.sh add` loop and `manage-topics.sh set` instead of inline jq
- Interview Stage 5 (ReviewAndConfirm) is untouched
- Step 4a (generate-todo.sh) is untouched
- Extension copy is identical to live file

---

### Phase 4: Add skill-todo Stage 2.5 TopicRevision (additive) [COMPLETED]

**Goal**: Insert a new Stage 2.5 TopicRevision between existing Stage 2 (ScanTasks) and Stage 3 (DetectOrphans) in skill-todo/SKILL.md, using Mode A pattern reference.

**Tasks**:
- [ ] Read `.claude/skills/skill-todo/SKILL.md` lines 30-50 to confirm insertion point (between Stage 2 closing tag and Stage 3 opening tag)
- [ ] Insert new Stage 2.5 block after the closing `</stage>` of Stage 2 and before Stage 3's `<stage>` tag:
  ```xml
  <stage id="2.5" name="TopicRevision">
    <action>Optional: backfill topics on active tasks missing the topic field</action>
    <process>
      Detect active tasks without a topic:
      ```bash
      missing=$(jq -r '.active_projects[] |
        select(.status == "completed" | not) |
        select(.status == "abandoned" | not) |
        select(.status == "expanded" | not) |
        select(.topic == null or .topic == "") |
        "\(.project_number)|\(.project_name)"' specs/state.json)
      ```

      If no tasks need backfill, skip this stage.

      For each task needing a topic, follow the topic assignment pattern from
      @.claude/context/patterns/topic-assignment-pattern.md (Mode A, per-task backfill).
      Use header "Topic Backfill ({i} of {total})".

      After each selection:
      ```bash
      bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
      ```
    </process>
  </stage>
  ```
- [ ] Verify Stage 2 and Stage 3 remain intact around the insertion
- [ ] Copy edited live file to extension: `cp .claude/skills/skill-todo/SKILL.md .claude/extensions/core/skills/skill-todo/SKILL.md`
- [ ] Verify sync with diff

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Insert new Stage 2.5 between Stage 2 and Stage 3
- `.claude/extensions/core/skills/skill-todo/SKILL.md` - Sync copy of above

**Verification**:
- Stage 2.5 exists between Stage 2 (ScanTasks) and Stage 3 (DetectOrphans)
- Stage 2.5 references `topic-assignment-pattern.md` (Mode A) and calls `manage-topics.sh set`
- No inline `active_topics` maintenance jq in Stage 2.5
- The detection jq (filtering active non-terminal tasks without topics) is present
- Extension copy is identical to live file

---

## Testing & Validation

- [ ] Verify no inline `active_topics` jq remains in any of the 4 modified live files (grep for `active_topics.*jq` or `active_topics.*index`)
- [ ] Verify all 4 locations reference `topic-assignment-pattern.md`
- [ ] Verify all 4 locations call `manage-topics.sh` (set or add)
- [ ] Verify extension copies match live files: `diff .claude/commands/task.md .claude/extensions/core/commands/task.md && diff .claude/agents/meta-builder-agent.md .claude/extensions/core/agents/meta-builder-agent.md && diff .claude/skills/skill-todo/SKILL.md .claude/extensions/core/skills/skill-todo/SKILL.md`
- [ ] Verify task.md --sync detection block (missing_topics jq) is preserved
- [ ] Verify meta-builder Interview Stage 5 (ReviewAndConfirm) is untouched
- [ ] Verify skill-todo Stage 3 (DetectOrphans) is untouched

## Artifacts & Outputs

- `specs/655_refactor_existing_topic_pickers/plans/01_refactor-topic-pickers-plan.md` (this plan)
- Modified files (6 total):
  - `.claude/commands/task.md` (live + extension copy)
  - `.claude/agents/meta-builder-agent.md` (live + extension copy)
  - `.claude/skills/skill-todo/SKILL.md` (live + extension copy)

## Rollback/Contingency

All changes are to markdown/documentation files with no runtime impact. If any edit breaks the agent system's ability to parse these files:
1. Revert individual files via `git checkout -- .claude/commands/task.md` (etc.)
2. Extension copies can be restored the same way or by re-copying from the reverted live file
3. No database, build, or runtime state is affected by these changes
