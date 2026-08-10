# Research Report: Task #641

**Task**: 641 - Fix meta-builder-agent topic assignment — replace nonexistent keyword heuristic with interactive topic picker
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:00:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: meta-builder-agent.md, task.md, state-management-schema.md (codebase)
**Artifacts**: specs/641_meta_builder_topic_picker/reports/01_topic-picker-research.md

---

## Executive Summary

- The meta-builder-agent references a "keyword heuristic" for topic inference that does not exist — `/task` uses an interactive AskUserQuestion picker (Step 4.5), not keyword inference
- Stage 3.5 is named "AnalyzeTopics (Topic Clustering)" but its actual function is *task consolidation* (merging related tasks); topic group labels generated in this stage are discarded and never become `topic` field values
- The correct fix is to add a batch topic assignment step in Stage 5 (ReviewAndConfirm), before the final confirmation, using the same dynamic picker pattern from `/task` Step 4.5
- Batch topic assignment (one question, one topic for all tasks) is the right model for `/meta`; per-task assignment would require N extra dialog rounds for large batches

---

## Context & Scope

The meta-builder-agent (`/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md`) creates
multiple tasks in batch when the user runs `/meta`. It references a "Topic Auto-Inference" mechanism
at line 676 that silently calls a keyword heuristic — but that heuristic does not exist anywhere in
the codebase. The result is that all batch-created tasks are stored without a `topic` field, appearing
as "Uncategorized" in the Task Order section of TODO.md.

This research documents the exact broken state, the correct pattern from `/task`, and a precise
integration plan for the fix.

---

## Findings

### 1. Current (Broken) State of Topic Assignment

**Location**: `meta-builder-agent.md`, line 676, inside Stage 6 CreateTasks loop

**Exact text**:
```
**Topic Auto-Inference**: Before building the state.json entry, run the keyword heuristic
(same as `/task` topic inference) against each task's title and description. The inferred
topic is shown in the Stage 5 confirmation table (Topic column). If the user selects "Revise",
they can change topic assignments.
```

**Why it is broken**:

1. `/task` Step 4.5 does NOT use a "keyword heuristic". It uses an interactive `AskUserQuestion`
   picker built from `active_topics` in state.json. There is no keyword-to-topic inference logic
   anywhere in the system.

2. The Stage 5 confirmation table (line 566-574) has a "Topic" column:
   ```
   | # | Title | Language | Topic | Effort | Dependencies |
   ```
   The note on line 574 says "Topics are auto-inferred from task title/description; user can revise
   by selecting 'Revise'." Since the heuristic doesn't exist, this column is always empty in
   practice.

3. The Stage 6 active_topics maintenance code (lines 1361-1376) correctly handles writing
   `new_topics` to `active_topics`, but there is no upstream logic that sets `new_topics`. The
   array is always empty, so `active_topics` is never extended through `/meta`.

4. The state.json entry template at lines 678-689 includes `"topic": "agent-system"` as an example,
   implying topics should be written. In practice, the `topic` field is omitted for all
   meta-created tasks.

**Net effect**: Every task created by `/meta` lands in "Uncategorized" in Task Order, which
defeats the purpose of the topic taxonomy maintained in `active_topics`.

---

### 2. Stage 3.5 Naming Confusion

**Stage name in file**: `### Interview Stage 3.5: AnalyzeTopics (Topic Clustering)`

**Actual function**: Task consolidation — merging multiple user-provided tasks into fewer,
more coherent tasks. The stage generates "topic labels" per group (e.g., "Export Functionality
(command + skill)"), but these are *display labels for the consolidation picker*, not `topic`
field values to be stored in state.json.

**The confusion**:
- The name "AnalyzeTopics" and the word "Topic Clustering" make it sound like this stage
  assigns the `topic` field for each task.
- The stage does generate group labels that look like topic names.
- But the only outcome captured (line 532) is "Updated task_list (may be consolidated),
  consolidation_mode" — not any topic assignments.
- After the user accepts or declines consolidation, the group labels are completely discarded.

**Proposed rename**: Stage 3.5 should be renamed to something like "AnalyzeConsolidation
(Task Merging)" or simply "ConsolidateTasks" to accurately reflect its purpose and eliminate
the expectation that it handles topic assignment.

---

### 3. The `/task` Step 4.5 Pattern to Adapt

**Location**: `task.md` lines 133-170

**Pattern summary**:

1. Read `active_topics` from state.json:
   ```bash
   existing_topics=$(jq -r '.active_topics // [] | .[]' specs/state.json)
   ```

2. Build dynamic `AskUserQuestion` options from the array:
   ```json
   {
     "question": "Assign a topic to this task?",
     "header": "Topic Assignment",
     "multiSelect": false,
     "options": [
       { "label": "topic-a", "description": "Assign to topic-a" },
       { "label": "topic-b", "description": "Assign to topic-b" },
       { "label": "New topic...", "description": "Enter a custom topic name (will be added to active_topics)" },
       { "label": "Skip (no topic)", "description": "Task will appear under Uncategorized in Task Order" }
     ]
   }
   ```
   When `active_topics` is empty, show only "New topic..." and "Skip (no topic)".

3. If "New topic..." is selected: prompt free-text via a second `AskUserQuestion`, then append
   to `active_topics` before writing the task entry.

4. If "Skip (no topic)": set `topic = null` (omit from state.json entry).

5. **Active Topics Maintenance** after topic is known:
   ```bash
   if [[ -n "$topic" ]]; then
     jq --arg t "$topic" '
       if ((.active_topics // []) | index($t)) == null
       then .active_topics = ((.active_topics // []) + [$t])
       else . end' \
       specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
   fi
   ```

**For `/meta` (batch mode)**: The same picker is shown *once*, and the chosen topic is applied
to all tasks in the batch. This is appropriate because:
- `/meta` creates a coherent batch of related tasks (all for the same system change)
- Asking per-task would create unnecessary friction for 3-8 task batches
- The user can always run `/task --sync` or edit individual tasks afterward if differentiation
  is needed

---

### 4. Integration Into the Stage 5 Confirmation Flow

**Where to insert**: After Stage 4 (AssessComplexity) data is collected, and BEFORE the
Stage 5 confirmation table is presented. Specifically, a new **Stage 4.5: AssignTopic**
should be inserted.

**Why before Stage 5**: The Stage 5 table already has a "Topic" column. The topic must be
known before that table is rendered, so it can be shown to the user for review rather than
left blank.

**Proposed Stage 4.5: AssignTopic**

```
### Interview Stage 4.5: AssignTopic

**Question** (via AskUserQuestion):
Read active_topics from state.json, then present:

{
  "question": "Assign a topic to these tasks?",
  "header": "Topic Assignment",
  "multiSelect": false,
  "options": [
    // one option per active_topics entry
    { "label": "New topic...", "description": "Enter a custom topic name" },
    { "label": "Skip (no topic)", "description": "Tasks will appear under Uncategorized" }
  ]
}

If "New topic...": prompt free-text for topic name.
If "Skip (no topic)": set batch_topic = null.

Capture: batch_topic (string or null)
```

Then in Stage 5, populate the Topic column from `batch_topic`:
- If `batch_topic` is set: all rows show the topic value
- If null: all rows show "(none)"

Update line 574 note to read:
"Topic assigned via Step 4.5 picker; applies to all tasks in this batch."

In Stage 6 CreateTasks, each task gets `"topic": batch_topic` in its state.json entry (omitting
the field if null). The existing active_topics maintenance block at lines 1361-1376 already
handles appending to `active_topics` correctly — it just needs `batch_topic` to be set.

---

### 5. State.json Entry Template Needs

The example state.json entry at lines 678-689 is correct in structure:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "task_type": "meta",
  "topic": "agent-system",
  "dependencies": [35, 34],
  "artifacts": []
}
```

The `topic` field is optional (omit when null). The example shows this correctly. No template
changes are needed — the fix is ensuring `batch_topic` is actually populated before this
template is used.

The state-management-schema.md confirms:
- `topic`: string, optional, kebab-case, from `active_topics` array
- `active_topics`: string[], optional, canonical ordered list maintained at the top level

---

### 6. Batch vs. Per-Task Topic Assignment

**Recommendation: Batch (one topic for all tasks)**

Rationale:
- `/meta` is explicitly a *system-level change builder* — a single invocation creates a
  coherent set of changes to one part of the agent system (e.g., "fix the orchestrate TODO sync").
  These tasks are naturally in the same domain/topic.
- Showing N separate topic pickers for N tasks would create unacceptable UX friction. A
  3-task batch becomes a 6-7 dialog flow instead of 4-5.
- The existing `topic` taxonomy is coarse-grained (e.g., "agent-system", "completeness").
  Per-task differentiation within a single `/meta` invocation is rarely meaningful.
- If different tasks in the batch genuinely need different topics (rare edge case), the user
  can edit state.json directly or use a future `/task --sync` backfill.

**Alternative considered: Per-task assignment**
- Would require Stage 4.5 to loop over each task_list entry with individual pickers
- Creates N AskUserQuestion calls instead of 1
- Appropriate if tasks often span multiple topic domains, but this is not the typical `/meta`
  usage pattern

---

## Decisions

1. The keyword heuristic referenced at line 676 does not exist and must be replaced entirely
   with an interactive picker — not supplemented or extended.

2. Stage 3.5 should be renamed from "AnalyzeTopics (Topic Clustering)" to "ConsolidateTasks"
   (or similar) to eliminate the naming confusion with topic assignment.

3. Topic assignment should happen at a new Stage 4.5, producing a single `batch_topic` value
   applied to all tasks in the batch.

4. The Stage 5 Topic column should display `batch_topic` (or "(none)") rather than "auto-inferred".

5. The active_topics maintenance block in Stage 6 Step 4b (lines 1361-1376) is already
   correct and requires no changes — it just needs `batch_topic` to be provided by Stage 4.5.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Stage 3.5 rename breaks cross-references in other files | Grep for "AnalyzeTopics" across .claude/ before renaming; update all references |
| "Topic Consolidation" header text in AskUserQuestion (line 468) confuses users | Change header to "Task Consolidation" to match actual purpose |
| Batch topic may be wrong for multi-domain `/meta` sessions | Document "Skip (no topic)" as the escape hatch; add note that per-task topics can be edited in state.json |
| Stage 4.5 adds friction for simple single-task `/meta` invocations | Stage 4.5 should only show when task count >= 1; behavior is identical to `/task` Step 4.5 for single tasks |

---

## Context Extension Recommendations

- **Topic**: The distinction between "task consolidation" (Stage 3.5) and "topic assignment" (Step 4.5) in batch task creation
- **Gap**: No documentation explains that Stage 3.5 group labels are purely for consolidation display and are not stored as `topic` field values
- **Recommendation**: Add a note to `.claude/docs/reference/standards/multi-task-creation-standard.md` clarifying that "Topic Grouping" in the 8-component pattern refers to the consolidation display grouping, not the `topic` field assignment

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` (1440 lines)
  - Lines 383-534: Stage 3.5 AnalyzeTopics (consolidation flow)
  - Lines 555-594: Stage 5 ReviewAndConfirm (confirmation table, AskUserQuestion)
  - Lines 665-691: Topic Auto-Inference section (the broken heuristic reference)
  - Lines 1341-1393: Stage 6 status update steps including active_topics maintenance (4b)

- `/home/benjamin/.config/nvim/.claude/commands/task.md` (728 lines)
  - Lines 133-170: Step 4.5 topic picker pattern (the correct reference implementation)

- `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md`
  - Lines 10-18: `active_topics` top-level field
  - Line 73: `active_topics` field description
  - Line 87: `topic` project entry field description

### Key Grep Results

```
grep -n "AnalyzeTopics\|Topic\|3\.5\|consolidat" meta-builder-agent.md
-> Line 383: Interview Stage 3.5: AnalyzeTopics (Topic Clustering)
-> Line 462: 3.5.5: Present Topic Consolidation Picker
-> Line 468: "header": "Topic Consolidation"
-> Line 574: Topics are auto-inferred from task title/description...
-> Line 676: Topic Auto-Inference: ... run the keyword heuristic (same as /task topic inference)
-> Line 1361: 4b. Update active_topics (after all tasks created...)
```
