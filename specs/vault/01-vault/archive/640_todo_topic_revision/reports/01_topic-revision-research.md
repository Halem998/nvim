# Research Report: Task #640

**Task**: 640 - Add topic revision stage to /todo skill and "New topic..." option to /task --sync backfill
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:00:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `.claude/skills/skill-todo/SKILL.md` — full stage listing
- `.claude/commands/task.md` — Step 4.5 and Step 6.5
- `.claude/rules/state-management.md` — topic/active_topics field definitions
- `.claude/context/reference/state-management-schema.md` — full schema reference
- `.claude/scripts/generate-task-order.sh` — load_topics() function and Uncategorized logic
**Artifacts**:
- `specs/640_todo_topic_revision/reports/01_topic-revision-research.md`
**Standards**: report-format.md

---

## Executive Summary

- `skill-todo/SKILL.md` has **zero topic awareness** — no stage reads or assigns topics during the archival workflow
- `/task --sync` Step 6.5 has a topic backfill picker but **only allows picking from existing `active_topics`** — no "New topic..." option
- Step 4.5 in `/task` (create mode) already has the full "New topic..." pattern including AskUserQuestion with free-text follow-up, `active_topics` maintenance, and jq update logic — this is the exact reuse target
- Best insertion point in skill-todo: **new Stage 2.5**, between ScanTasks (Stage 2) and DetectOrphans (Stage 3), operating on completed/abandoned tasks before archival
- Orphan topic cleanup: detect topics in `active_topics` with zero remaining references after archival, then prompt to remove them from the array

---

## Context & Scope

The agent system supports a `topic` field on task entries and an `active_topics` top-level array in `state.json`. The `generate-task-order.sh` script renders tasks grouped by topic in the `## Task Order` section of `TODO.md`. Tasks without a `topic` field appear under `### Uncategorized`.

The gap: two entry points exist where topics should be assignable or revisable, but both lack full functionality:
1. `/todo` (archival) — zero topic handling
2. `/task --sync` Step 6.5 — has backfill but missing "New topic..." option

---

## Findings

### Current State of Topic Handling in skill-todo

**Result: None.** The skill has 16 stages (1–16 including 10.5). Zero mention of `topic`, `active_topics`, or any topic-related operation exists anywhere in `SKILL.md`. The skill's `<task>` declaration ("Parse arguments, scan for archivable tasks, update states, generate CHANGE_LOG entries, suggest memory harvesting") does not include topic management.

Existing stages in sequence order:
1. ParseArguments
2. ScanTasks — reads state.json, identifies completed/abandoned tasks
3. DetectOrphans — scans specs/ directories vs state files
4. DetectMisplaced — finds misplaced directories
5. ScanRoadmap — reads ROADMAP.md
6. ScanMetaSuggestions — scans meta tasks for README suggestions
7. HarvestMemories — collects/deduplicates memory candidates
8. DryRunOutput — preview if --dry-run
9. InteractivePrompts — AskUserQuestion for orphans, misplaced, TODO.md orphans, memory harvest
10. ArchiveTasks (checkpoint: vault_check_complete) — moves tasks to archive, vault threshold check
10.5. RegenerateTaskOrder — runs generate-task-order.sh --update-todo
11. UpdateRoadmap
12. UpdateREADME
13. UpdateChangelog
14. CreateMemories
15. GitCommit
16. OutputResults

### Current State of Topic Handling in /task --sync (Step 6.5)

Step 6.5 ("Topic backfill for tasks missing the `topic` field") does the following:

1. Detects active non-terminal tasks (excludes completed, abandoned, expanded) with null or empty `topic`
2. Reads `active_topics` from state.json
3. Presents AskUserQuestion multiSelect "allowing the user to assign topics from the dynamic list"

**The gap**: The spec says "No auto-inference heuristic -- purely picker-based" and does not include a "New topic..." option. The user is constrained to choosing from existing `active_topics` only — they cannot create a new topic during backfill.

**Exact current content of Step 6.5** (from task.md lines 373–389):

```
6.5. **Topic backfill** for tasks missing the `topic` field:

   Detect active tasks without a topic:
   ```bash
   missing_topics=$(jq -r '.active_projects[] |
     select(.status == "completed" | not) |
     select(.status == "abandoned" | not) |
     select(.status == "expanded" | not) |
     select(.topic == null or .topic == "") |
     "\(.project_number)|\(.project_name)"
   ' specs/state.json)
   ```

   If any tasks need backfill, read `active_topics` from state.json and present **AskUserQuestion** multiSelect allowing the user to assign topics from the dynamic list. No auto-inference heuristic -- purely picker-based.

   Apply accepted assignments via jq `(.active_projects[] | select(.project_number == N)) |= . + {topic: "value"}`.
```

**Missing**: A "New topic..." option like Step 4.5 provides — including free-text follow-up prompt and `active_topics` array maintenance.

### The AskUserQuestion Pattern from Step 4.5 (for Reuse)

Step 4.5 in create mode (task.md lines 133–169) is the reference implementation:

```json
{
  "question": "Assign a topic to this task?",
  "header": "Topic Assignment",
  "multiSelect": false,
  "options": [
    "... one option per active_topics entry ...",
    { "label": "New topic...", "description": "Enter a custom topic name (will be added to active_topics)" },
    { "label": "Skip (no topic)", "description": "Task will appear under Uncategorized in Task Order" }
  ]
}
```

If "New topic..." is selected: prompt for topic name (free-text via AskUserQuestion), then:
```bash
jq --arg t "$topic" '
  if ((.active_topics // []) | index($t)) == null
  then .active_topics = ((.active_topics // []) + [$t])
  else . end' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

This is the exact pattern to replicate in both `/task --sync` Step 6.5 and the new `/todo` stage.

For `/todo`, the AskUserQuestion must handle **multiple tasks** in a single interaction (not one-at-a-time), since `/todo` operates on a batch. The pattern should present a grouped picker: for each uncategorized completed/abandoned task, allow topic selection (including "New topic..." and "Skip") before archiving.

### Recommended Insertion Point in skill-todo

**New Stage 2.5: TopicRevision** — inserted between Stage 2 (ScanTasks) and Stage 3 (DetectOrphans).

**Rationale**:
- Stage 2 already identifies completed/abandoned tasks (the candidate set)
- Stage 2.5 should operate on that candidate set before any destructive operations (archival, directory moves)
- Stage 3+ performs file system operations; topic assignment is purely state.json data, so it belongs before the I/O phases
- Stage 8 (DryRunOutput) already occurs after Stage 2.5, so its preview block must be updated to include topic revision stats

**Stage 2.5 behavior**:
1. From the Stage 2 scan results, identify tasks with null/empty `topic`
2. If none have missing topics, skip Stage 2.5 entirely (no prompt)
3. Read `active_topics` from state.json
4. Present AskUserQuestion for each uncategorized task (or grouped batch): options = existing topics + "New topic..." + "Skip (no topic)"
5. If "New topic..." chosen: follow-up free-text prompt, append new value to `active_topics`
6. Apply assignments to the in-memory task list (these will be persisted in Stage 10's archival writes, since archival copies the full task JSON including the `topic` field)
7. Update dry_run preview stats: `topic_revisions_pending` count

**Important**: The topic field is written to `specs/archive/state.json` (not `specs/state.json`) during archival. The assignment must either (a) update `specs/state.json` before Stage 10 moves the task to archive, or (b) be applied directly during the archival write in Stage 10. Option (a) is cleaner — Stage 2.5 writes to `specs/state.json` using jq, and Stage 10's existing archival code reads the full task entry at that point.

### Schema Requirements

**`topic` field** (per-task, optional):
- Type: string
- Format: kebab-case value from the `active_topics` array (e.g., `"completeness"`, `"agent-system"`)
- Semantics: absent/null means task appears under "Uncategorized" in Task Order
- Storage: `active_projects[N].topic` in `state.json`; also copied to `completed_projects[N].topic` in `archive/state.json`

**`active_topics` field** (top-level, optional):
- Type: string[]
- Semantics: canonical ordered list of topic taxonomy values; used by task-creation commands for picker population and by `generate-task-order.sh` for rendering order
- Storage: `state.json` top-level array (not inside any task entry)
- Maintenance: append-only during task lifecycle; needs orphan cleanup when topics become unreferenced

**jq access patterns**:
```bash
# Read topic for a task
jq -r --arg n "640" '.active_projects[] | select(.project_number == ($n | tonumber)) | .topic // ""' specs/state.json

# Read active_topics list
jq -r '.active_topics // [] | .[]' specs/state.json

# Assign topic to task (safe update)
jq --argjson n 640 --arg t "agent-system" '
  (.active_projects[] | select(.project_number == $n)) |= . + {topic: $t}
' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Add topic to active_topics if not already present
jq --arg t "new-topic" '
  if ((.active_topics // []) | index($t)) == null
  then .active_topics = ((.active_topics // []) + [$t])
  else . end
' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Orphan Topic Cleanup Logic

An "orphan topic" is a value in `active_topics` that is no longer referenced by any active task's `topic` field.

**Detection** (after Stage 10 archival, before Stage 10.5 regeneration):
```bash
# Get active_topics values
active_topics_list=$(jq -r '.active_topics // [] | .[]' specs/state.json)

# Get all topic values still in use by remaining active tasks
used_topics=$(jq -r '
  .active_projects[] |
  select(.status == "completed" | not) |
  select(.status == "abandoned" | not) |
  select(.status == "expanded" | not) |
  .topic // "" |
  select(. != "")
' specs/state.json | sort -u)

# Identify orphans = active_topics entries not in used_topics
```

**When to check**: After Stage 10 (ArchiveTasks) completes, when `active_projects` has been pruned of the archived tasks. At this point, some topics may have zero remaining task references.

**User interaction**: If orphan topics are detected, present an AskUserQuestion multiSelect:
```json
{
  "question": "Remove unused topics from active_topics?",
  "header": "Orphan Topic Cleanup",
  "description": "These topics are no longer referenced by any active task.",
  "multiSelect": true,
  "options": [
    { "label": "agent-system", "description": "No active tasks use this topic" },
    { "label": "formula-refactor", "description": "No active tasks use this topic" }
  ]
}
```

Selected topics are removed from the `active_topics` array:
```bash
jq --argjson orphans '["agent-system", "formula-refactor"]' '
  .active_topics = [.active_topics[] | select(. as $t | $orphans | index($t) == null)]
' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Placement in skill-todo**: This check belongs in Stage 10 as sub-step 10.x (after archival completes, before the vault check), or as a new Stage 10.3 between ArchiveTasks and RegenerateTaskOrder.

### generate-task-order.sh load_topics() Verification

The `load_topics()` function (lines 212–234) confirms:
- Reads `task.topic` from state.json for each non-terminal active task via jq
- Stores result in `task_topic[task_num]` associative array
- Reads `active_topics` top-level array for canonical ordering
- In `generate_grouped_section()` (lines 361–458): tasks with empty `task_topic` value go to `### Uncategorized` section
- In the wave table (lines 529–593): topics column shows distinct topic values per wave

The script's `Topic assignment:` comment (line 25–26) explicitly states: "No heuristic is provided here; topic assignment is project-specific and handled by downstream tools (e.g., /task, /meta)." This confirms `/todo` and `/task --sync` are the intended downstream tools for topic backfill.

---

## Decisions

- **Stage numbering**: Insert as Stage 2.5 (between ScanTasks and DetectOrphans) in skill-todo
- **Reuse source**: Step 4.5 from `/task` create mode is the canonical AskUserQuestion pattern
- **Orphan cleanup placement**: New sub-step within Stage 10, after archival and before vault check (or as Stage 10.3)
- **Scope of /todo topic revision**: Only operates on tasks in the archival batch (completed/abandoned), not all active tasks
- **State write timing**: Stage 2.5 writes topic assignments to `specs/state.json` immediately (not deferred); Stage 10 then copies the full task entry (including topic) to archive

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| User cancels topic picker mid-batch | Partial assignments are written per-task; cancellation skips remaining tasks, already-assigned tasks retain assignments |
| "New topic..." creates duplicate via different capitalization | jq index check is case-sensitive; document that topics should be kebab-case lowercase |
| Orphan cleanup removes a topic still referenced by archived tasks | Orphan check only scans `active_projects`, not archive; orphan topics may still appear in archive data — this is acceptable since archive is read-only reference |
| Stage 2.5 adds latency when many tasks lack topics | Skip entirely if zero uncategorized tasks in archival batch |
| /task --sync Step 6.5 is rarely run; backfill stays incomplete | The /todo Stage 2.5 fills the gap since /todo is the primary recurring command |

---

## Context Extension Recommendations

- **Topic**: `/todo` topic revision workflow
- **Gap**: No documented pattern for batch topic assignment across multiple tasks in a single AskUserQuestion session
- **Recommendation**: After implementation, add a context note in `.claude/context/patterns/` documenting the batch-picker approach used in Stage 2.5

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/skills/skill-todo/SKILL.md` — 823 lines, 16 stages
- `/home/benjamin/.config/nvim/.claude/commands/task.md` — 729 lines, 6 modes
- `/home/benjamin/.config/nvim/.claude/rules/state-management.md` — 136 lines
- `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md` — 406 lines
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` — 896 lines

### Key Line References
- `skill-todo` Stage 2 (ScanTasks): lines 31–39
- `skill-todo` Stage 9 (InteractivePrompts): lines 203–228
- `skill-todo` Stage 10 (ArchiveTasks): lines 230–634
- `/task` Step 4.5 (topic picker with "New topic..."): lines 133–169
- `/task` Step 6.5 (--sync backfill, no "New topic..."): lines 373–389
- `state-management-schema.md` `active_topics` definition: lines 73–74
- `state-management-schema.md` `topic` field definition: lines 87 (table row)
- `generate-task-order.sh` `load_topics()`: lines 212–234
- `generate-task-order.sh` Uncategorized section: lines 430–457
