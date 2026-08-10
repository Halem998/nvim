# Research Report: Task #655

**Task**: 655 - refactor_existing_topic_pickers
**Started**: 2026-06-10T00:00:00Z
**Completed**: 2026-06-10T00:15:00Z
**Effort**: 1 hour
**Dependencies**: Task 654 (create_topic_management_utilities) — COMPLETED
**Sources/Inputs**: Codebase examination of 4 target files + 2 shared utilities
**Artifacts**: - specs/655_refactor_existing_topic_pickers/reports/01_refactor-topic-pickers.md
**Standards**: report-format.md

---

## Executive Summary

- Four locations contain inline topic picker logic; three are clearly duplicated, one (skill-todo) needs a new stage added
- The shared utilities from task 654 are in place: `manage-topics.sh` (list/add/set/validate) and `topic-assignment-pattern.md` (3 modes with canonical bash)
- The refactoring is mechanical: each location becomes a 4-line reference block plus `manage-topics.sh` calls; no behavioural changes
- Extension copies in `.claude/extensions/core/` are **identical** to live files (zero-diff confirmed) and must be updated in sync

---

## Context & Scope

Task 654 created two shared utilities:
- `.claude/scripts/manage-topics.sh` — atomic state.json operations (list/add/set/validate)
- `.claude/context/patterns/topic-assignment-pattern.md` — canonical 3-mode pattern document

Task 655 refactors the 4 locations that still carry inline duplicated logic to reference those utilities. Implementation writes no new behaviour; it shrinks files and establishes the canonical reference.

---

## Findings

### Location 1 — commands/task.md Step 4.5 (lines 133–170)

**File**: `.claude/commands/task.md`
**Section**: Create Task Mode, Step 4.5 "Detect topic from active_topics in state.json"
**Lines**: 133–170 (38 lines)

**What it does**:
- Reads `existing_topics` via inline jq
- Shows AskUserQuestion picker with dynamic options
- Handles "New topic..." free-text follow-up
- Maintains `active_topics` via inline jq snippet (lines 162–169)

**Mode**: Interactive (Mode A in pattern document)

**Location-specific notes**:
- The picker question is `"Assign a topic to this task?"` (singular — one task)
- The "Skip" description says `"Task will appear under Uncategorized in Task Order"` — keep this wording
- The `active_topics` maintenance jq on lines 162–169 must be replaced by `manage-topics.sh add` + `manage-topics.sh set`

**Minimal replacement** (Step 4.5 replacement block, ~6 lines):
```markdown
4.5. **Detect topic** (Mode A: Interactive):

   Follow the topic assignment pattern from
   @.claude/context/patterns/topic-assignment-pattern.md (Mode A).

   After obtaining the topic:
   ```bash
   bash .claude/scripts/manage-topics.sh add "$topic"
   bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"
   ```
```

**Lines removed**: 133–170 (38 lines inline → ~6 lines reference)

---

### Location 2 — agents/meta-builder-agent.md Interview Stage 4.5 (lines 552–606)

**File**: `.claude/agents/meta-builder-agent.md`
**Section**: Stage 3A Interactive Interview, Interview Stage 4.5 AssignTopic
**Lines**: 552–606 (55 lines) — the AssignTopic stage body

**What it does**:
- Reads `active_topics` via inline jq
- Builds picker options with descriptions ("Existing topic from active_topics")
- Shows AskUserQuestion with question "Assign a topic to these tasks?"
- Handles "New topic..." follow-up with kebab-case guidance
- Captures `batch_topic` for use in Stage 5 and Stage 6

**Mode**: Interactive batch variant (Mode A — same picker but assigns to all tasks in batch)

**Location-specific notes**:
- The question wording is `"Assign a topic to these tasks?"` (plural — batch)
- The "Skip" description differs: `"Tasks will appear under Uncategorized in Task Order"` (plural)
- `batch_topic` is a batch variable used across multiple task creations; the state update is deferred to Stage 6 (lines 1359–1374) rather than done immediately
- Stage 6 Step 4b (lines 1359–1374) also contains inline `active_topics` maintenance jq that should be replaced by `manage-topics.sh add` calls

**Two replacements needed**:

1. **Interview Stage 4.5** (lines 552–606): Replace with pattern reference that notes the batch variant (plural question wording, deferred state update)

2. **Stage 6 Step 4b** (lines 1359–1374): Replace inline jq loop with `manage-topics.sh add` calls:
   ```bash
   for topic in "${new_topics[@]}"; do
     [[ -z "$topic" ]] && continue
     bash .claude/scripts/manage-topics.sh add "$topic"
   done
   ```
   Then for each task after its state.json entry is written:
   ```bash
   bash .claude/scripts/manage-topics.sh set "$task_num" "$batch_topic"
   ```

**Lines removed from Stage 4.5**: 552–606 (55 lines → ~8 lines reference)
**Lines removed from Stage 6 4b**: 1359–1374 (16 lines → ~5 lines)

---

### Location 3 — commands/task.md --sync Step 6.5 (lines 351–413)

**File**: `.claude/commands/task.md`
**Section**: Sync Mode (--sync), Step 6.5 "Topic backfill for tasks missing the topic field"
**Lines**: 351–413 (63 lines)

**What it does**:
- Detects active tasks without a `topic` field
- Reads `existing_topics` via inline jq
- Shows per-task AskUserQuestion picker mirroring Step 4.5 pattern
- Handles "New topic..." follow-up
- Maintains `active_topics` via inline jq snippet (same pattern as Step 4.5 lines 162–169)
- Applies accepted assignments via jq

**Mode**: Interactive per-task backfill (Mode A variant)

**Location-specific notes**:
- The picker header is `"Topic Backfill ({i} of {total})"` — loop counter in header
- The picker question is `"Assign a topic to task {N} ({project_name})?"` — task-specific wording
- The "New topic..." follow-up uses a different question: `"Enter a topic name for task {N}:"` (simpler)
- After getting topic, uses separate jq to set topic on the task (`active_projects |= map(if .project_number == $n then . + {topic: $t} else . end)`) — this should become `manage-topics.sh set "$task_num" "$topic"`
- The per-task nature (loop with counter header) is the key distinction from Step 4.5

**Minimal replacement**:
- Keep the task-detection block (lines 353–363) — this logic detects which tasks need backfill
- Replace inline jq reads and AskUserQuestion block with pattern reference noting per-task loop variant
- Replace inline `active_topics` maintenance and `apply assignments` jq with `manage-topics.sh add` + `manage-topics.sh set`

**Lines removed**: Approximately lines 364–413 (50 lines → ~8 lines reference)

---

### Location 4 — skills/skill-todo/SKILL.md Stage 2.5 (NOT YET PRESENT)

**File**: `.claude/skills/skill-todo/SKILL.md`
**Section**: Between Stage 2 (ScanTasks) and Stage 3 (DetectOrphans)
**Lines**: Currently stage 2 ends around line 40, stage 3 begins at line 42

**Status**: Stage 2.5 does NOT currently exist in skill-todo. This location requires **adding** a new stage (not replacing existing inline code).

**What the new stage does**:
During `/todo`, active tasks may need topic revision — either to add topics to un-topiced tasks, or to update existing topics. This stage presents an interactive picker for any active tasks that lack a topic, using Mode A from the pattern document.

**Proposed stage skeleton** (to be added between Stage 2 and Stage 3):

```xml
<stage id="2.5" name="TopicRevision">
  <action>Optional: backfill or revise topics on active tasks</action>
  <process>
    Follow the topic assignment pattern from
    @.claude/context/patterns/topic-assignment-pattern.md (Mode A, per-task backfill).

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

    For each task needing a topic, show Mode A picker with header
    "Topic Backfill ({i} of {total})". After selection:
    ```bash
    bash .claude/scripts/manage-topics.sh add "$topic"
    bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
    ```
  </process>
</stage>
```

**Lines added**: ~20 lines (new stage, no lines removed)

---

## Extension Copies

The `.claude/extensions/core/` directory contains exact mirrors of all 4 files:

| Live file | Extension copy | Diff status |
|-----------|---------------|-------------|
| `.claude/commands/task.md` | `.claude/extensions/core/commands/task.md` | Identical (zero diff) |
| `.claude/agents/meta-builder-agent.md` | `.claude/extensions/core/agents/meta-builder-agent.md` | Identical (zero diff) |
| `.claude/skills/skill-todo/SKILL.md` | `.claude/extensions/core/skills/skill-todo/SKILL.md` | Identical (trailing newline only) |

**Note**: There is no extension copy of `skill-todo/SKILL.md` that contains any additional topic logic. Both files are in sync.

**Implementation rule**: For every edit to a live file, apply the identical edit to its extension copy. The simplest approach is to copy the edited live file over the extension copy after all edits are complete.

---

## Shared Utilities Interface

### manage-topics.sh subcommands

| Subcommand | Signature | Notes |
|-----------|-----------|-------|
| `list` | `bash .claude/scripts/manage-topics.sh list` | Prints one topic per line |
| `add` | `bash .claude/scripts/manage-topics.sh add "$topic"` | Idempotent |
| `set` | `bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"` | Adds to active_topics + sets on task |
| `validate` | `bash .claude/scripts/manage-topics.sh validate "$topic"` | Exit 0/1 |

`set` calls `add` internally — calling `add` before `set` is harmless but redundant. Callers that only need to set a topic on a task can use `set` alone.

### topic-assignment-pattern.md modes

| Mode | When to use | AskUserQuestion shown? |
|------|-------------|------------------------|
| A: Interactive | User is actively creating/reviewing tasks | Yes |
| B: Inherit | Derived tasks (expand, recover, spawn) | No |
| C: Suggest | Batch task creation (review, fix-it) | No |

Locations 1, 2, 3, and 4 all use **Mode A** (interactive).

---

## Implementation Summary

| Location | File | Lines affected | Change type | Net line delta |
|----------|------|---------------|-------------|----------------|
| 1: task.md Step 4.5 | commands/task.md | 133–170 (38 lines) | Replace inline with reference | ~-32 |
| 2a: meta-builder Stage 4.5 | agents/meta-builder-agent.md | 552–606 (55 lines) | Replace inline with reference | ~-47 |
| 2b: meta-builder Stage 6 4b | agents/meta-builder-agent.md | 1359–1374 (16 lines) | Replace inline jq loop with script calls | ~-10 |
| 3: task.md --sync Step 6.5 | commands/task.md | 364–413 (~50 lines) | Replace inline picker + jq with reference | ~-42 |
| 4: skill-todo Stage 2.5 | skills/skill-todo/SKILL.md | (new — between lines 40–42) | Add new stage referencing pattern | ~+20 |
| Extension copies | extensions/core/... | same as above | Copy edited live files | same |

**Total net reduction in live files**: approximately -111 lines of inline logic replaced by references.

---

## Key Observations and Decisions

1. **skill-todo Stage 2.5 is additive, not reductive**: The current skill-todo has no topic picker at all. The stage needs to be written fresh, using the pattern document as its sole content source. This is still a win (no inline duplication) but differs from the other 3 locations which are pure replacements.

2. **meta-builder has two topic-related locations** (Stage 4.5 and Stage 6 Step 4b): Both need updating. Stage 4.5 is the interactive picker; Stage 6 Step 4b is the deferred state-update loop. Both should call manage-topics.sh.

3. **task.md --sync Step 6.5 detection logic must be preserved**: Lines 353–363 (the `missing_topics` jq that identifies tasks needing backfill) are unique to --sync mode and should remain inline. Only the picker interaction and jq maintenance blocks need replacement.

4. **Extension copies are identical to live files**: Apply the same edits to extension copies. The most reliable approach is to `cp` the modified live file over the extension copy once edits are finalized.

5. **Batch topic assignment vs per-task**: meta-builder assigns one topic to all tasks in the batch (`batch_topic`). The --sync backfill assigns per-task. Both use Mode A but with different loop structure. The pattern document covers both adequately under Mode A.

6. **manage-topics.sh `set` includes `add`**: When callers want to set a topic on a specific task, `set` alone is sufficient. The pattern document shows both calls for clarity; the implementation can use just `set`.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Extension copies getting out of sync | Apply edits to live file, then `cp` to extension copy immediately |
| skill-todo Stage 2.5 being skipped if no tasks need backfill | Pattern reference explicitly states skip condition |
| meta-builder batch_topic deferred state update missed | Explicitly call out Stage 6 Step 4b as a second edit point |
| task.md --sync detection logic accidentally removed | Note in plan: detection block (lines 353–363) stays; only picker + maintenance blocks change |

---

## Appendix: Exact Line Ranges

### commands/task.md (line 133–413)
- Lines 133–170: Step 4.5 topic picker — **REPLACE**
- Lines 351–363: --sync backfill detection — **KEEP**
- Lines 364–413: --sync picker + state maintenance — **REPLACE**

### agents/meta-builder-agent.md
- Lines 552–606: Interview Stage 4.5 AssignTopic — **REPLACE**
- Lines 1359–1374: Stage 6 Step 4b active_topics maintenance — **REPLACE**

### skills/skill-todo/SKILL.md
- After line 40 (end of Stage 2): **ADD** Stage 2.5 TopicRevision

### extensions/core/* (all three files)
- Same edits as live files
