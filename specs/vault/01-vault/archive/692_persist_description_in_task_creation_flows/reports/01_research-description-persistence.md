# Research Report: Task #692

**Task**: 692 - Persist description in task creation flows
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:15:00Z
**Effort**: Low
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/commands/task.md`, `.claude/agents/meta-builder-agent.md`, `.claude/skills/skill-fix-it/SKILL.md`, `.claude/skills/skill-spawn/SKILL.md`, `.claude/skills/skill-project-overview/SKILL.md`, `.claude/scripts/generate-todo.sh`
**Artifacts**:
- specs/692_persist_description_in_task_creation_flows/reports/01_research-description-persistence.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `generate-todo.sh` already reads and renders `description` (and `title`) fields from state.json — no script changes needed
- **4 confirmed gaps** in task creation flows: `commands/task.md` Create Task (step 6), `commands/task.md` Expand Mode (step 3), `agents/meta-builder-agent.md` Stage 6 CreateTasks, and `skills/skill-fix-it/SKILL.md` step 9.1
- **2 flows that already include description**: `commands/task.md` --review mode (step 8, the reference pattern) and `skills/skill-spawn/SKILL.md` (Stage 11, already has `"description": $desc`)
- **1 additional gap beyond the 4 listed**: `skills/skill-project-overview/SKILL.md` step 5.3 — omits both `description` and `title`
- **Recommended fix**: Add `"description": $desc` and `"title": $title` to each missing jq template; both `.claude/` and `.claude/extensions/core/` copies are identical (must sync both)

---

## Context & Scope

### What Was Researched

The research audited every task creation flow in the agent system to find where state.json entries are written without `description` or `title` fields. The `generate-todo.sh` script at line 169/182-189/299-302 was confirmed to extract and render these fields when present.

### Key Schema Confirmation

`generate-todo.sh` (lines 162–302) already handles both fields:
```bash
title: (.title // ""),
description: (.description // "")
```

And renders them:
- **Title** (line 191–199): Falls back to `project_name` → `"Task N"` if empty. Stored `title` takes priority.
- **Description** (lines 299–302): Rendered as `**Description**: {text}` when non-null/non-empty.

No changes needed in `generate-todo.sh`.

---

## Findings

### Reference Pattern (Correct Implementation)

**Location**: `commands/task.md` step 8 (--review mode), lines 604–620

This is the gold standard. The jq template:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$description" \
  --arg topic "$parent_topic" \
  '.next_project_number = ($next_num + 1) |
   .active_projects = [{
     "project_number": '$next_num',
     "project_name": "followup_{parent_N}_phase_{P}",
     "status": "not_started",
     "task_type": "'{task_type}'",
     "topic": (if ($topic == "" | not) then $topic else null end),
     "description": $desc,
     "parent_task": '{parent_N}',
     "created": $ts,
     "last_updated": $ts
   } | if .topic == null then del(.topic) else . end] + .active_projects'
```

Key fields present: `"description": $desc`. No `"title"` field — description alone is used.

**Also correct**: `skills/skill-spawn/SKILL.md` Stage 11 (lines 344–368):
```bash
'.active_projects += [{
  "project_number": $num,
  "project_name": $name,
  "status": "researched",
  "task_type": $lang,
  "description": $desc,
  "effort": $effort,
  "parent_task": $parent,
  ...
}]'
```
Spawn already stores description. No changes needed here.

---

### Gap 1: commands/task.md — Create Task Mode (Step 6)

**File**: `.claude/commands/task.md` (lines 161–175)  
**Also**: `.claude/extensions/core/commands/task.md` (identical copy)

**Current jq template** (step 6):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg topic "$topic" \
  '.next_project_number = {NEW_NUMBER} |
   .active_projects = [{
     "project_number": {N},
     "project_name": "slug",
     "status": "not_started",
     "task_type": "detected",
     "topic": (if ($topic == "" | not) then $topic else null end),
     "created": $ts,
     "last_updated": $ts
   } | if .topic == null then del(.topic) else . end] + .active_projects'
```

**Problem**: Step 3 computes an improved description from `$ARGUMENTS` (slug expansion, verb inference, formatting normalization), but this improved description is never passed to the jq call. There is also no `$title` variable — the improved description IS the title.

**Required fix**:
1. After step 3 (improve description), capture the result as `$improved_desc`
2. Add `--arg desc "$improved_desc"` to the jq call
3. Add `"description": $desc` to the template object
4. Optionally add `"title": $desc` (same value — the improved description serves as the title)

**Decision on title**: The `generate-todo.sh` already derives a display title from `project_name` (slug) as fallback. Adding an explicit `"title"` field is optional but improves fidelity — the improved description is human-readable while the slug is not. Recommend adding `"title": $desc` as well.

---

### Gap 2: commands/task.md — Expand Mode (Step 3)

**File**: `.claude/commands/task.md` (lines 299–307)  
**Also**: `.claude/extensions/core/commands/task.md` (identical copy)

**Current pattern** (step 3):
```bash
# Include "topic": parent_topic in each subtask jq entry (if parent has a topic)
```

The text says "using the Create Task jq pattern for each" — meaning it inherits Gap 1's missing fields. No explicit jq template is shown for the subtask entries. Each subtask is created as a new task, and the Create Task jq pattern (Gap 1) is referenced.

**Required fix**: Same as Gap 1 — when creating each subtask entry, include:
- `"description": $desc` — the subtask description (which the implementer should derive from the parent's natural breakpoints)
- `"title": $desc` — same as description (human-readable name for the subtask)

The subtask description should be derived from the task analysis (step 2), not just the parent's DESCRIPTION. Each subtask gets its own description.

---

### Gap 3: agents/meta-builder-agent.md — Stage 6 CreateTasks

**File**: `.claude/agents/meta-builder-agent.md` (lines 688–700)  
**Also**: `.claude/extensions/core/agents/meta-builder-agent.md` (identical copy)

**Current state.json entry template** (Stage 6):
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

**Problem**: The meta-builder-agent collects detailed task information during the interview (Stage 3A), including:
- `task_list[].title` — human-readable task titles
- `task_list[].description` — detailed task descriptions (or effort notes)

These are used in the confirmation table (Stage 5) and visualization (Stage 6 DeliverSummary), but the actual state.json entry only stores `project_name` (slug derived from title), `task_type`, `topic`, and `dependencies`. The `title` and `description` fields are not persisted.

**Required fix**: Add to the state.json entry template:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "task_type": "meta",
  "topic": "agent-system",
  "title": "{task.title}",
  "description": "{task.description}",
  "dependencies": [35, 34],
  "artifacts": []
}
```

And in the bash loop, pass variables:
```bash
--arg title "$task_title" \
--arg desc "$task_description" \
```

And add to the jq template:
```bash
"title": $title,
"description": $desc,
```

Both fields are already available from the `task_list` data structure.

---

### Gap 4: skills/skill-fix-it/SKILL.md — Step 9.1

**File**: `.claude/skills/skill-fix-it/SKILL.md` (lines 487–508)  
**Also**: `.claude/extensions/core/skills/skill-fix-it/SKILL.md` (identical copy)

**Current state.json entry template** (step 9.1):

For tasks with dependency:
```json
{
  "project_number": {N},
  "project_name": "{slug}",
  "status": "not_started",
  "task_type": "{task_type}",
  "topic": "{auto-inferred topic}",
  "dependencies": [learn_it_task_num]
}
```

For all other tasks:
```json
{
  "project_number": {N},
  "project_name": "{slug}",
  "status": "not_started",
  "task_type": "{task_type}",
  "topic": "{auto-inferred topic}"
}
```

**Problem**: The skill computes `title` (lines 401–402) and `description` (lines 401–402) for each task:
```
"title": "{tag content, truncated to 60 chars}",
"description": "{full tag content}\n\nSource: {file}:{line}",
```

These are used to build the task object internally (for the confirmation table), but the actual jq write at step 9.1 omits them.

**Required fix**: Add `"title": $title` and `"description": $desc` to both json templates in step 9.1. Pass them via `--arg title "$title"` and `--arg desc "$description"` in the jq call.

---

### Gap 5 (Additional): skills/skill-project-overview/SKILL.md — Step 5.3

**File**: `.claude/skills/skill-project-overview/SKILL.md` (lines 392–404)  
**Also**: `.claude/extensions/core/skills/skill-project-overview/SKILL.md` (identical copy)

**Current state.json entry** (step 5.3):
```bash
jq --argjson num "$next_num" \
   --arg name "$task_slug" \
   --arg topic "$topic" \
   '.active_projects += [{
     "project_number": $num,
     "project_name": $name,
     "status": "researched",
     "task_type": "meta",
     "topic": (if ($topic == "" | not) then $topic else null end),
     "next_artifact_number": 2
   } | if .topic == null then del(.topic) else . end] | .next_project_number = ($num + 1)'
```

**Problem**: No `description` or `title` fields. This is a single-task creation (hardcoded task slug `generate_project_overview`), but should still store a description for consistency.

**Required fix**: Add:
- `"title": "Generate project-overview.md"` (static string, known at write time)
- `"description": "Generate .claude/context/repo/project-overview.md from repository scan findings and user interview. See ${task_dir}/reports/01_project-overview-scan.md for collected data."` (static or slightly dynamic)

This is lower priority than the 4 main gaps since it's a single fixed-description task, but should be fixed for completeness.

---

### generate-todo.sh — Confirmed Complete (No Changes Needed)

**File**: `.claude/scripts/generate-todo.sh` (lines 159–303)

The script correctly:
1. Extracts `title` and `description` from each task entry via jq (lines 162–178)
2. Falls back gracefully when `title` is empty: uses `project_name` with underscores-to-spaces and capitalization (lines 191–199)
3. Renders description as `**Description**: {text}` only when non-null/non-empty (lines 299–302)

**No changes needed** to `generate-todo.sh`.

---

### Extension Copy Sync Requirement

All affected files exist as identical copies in `.claude/extensions/core/`. Any change to:
- `.claude/commands/task.md` → must also update `.claude/extensions/core/commands/task.md`
- `.claude/agents/meta-builder-agent.md` → must also update `.claude/extensions/core/agents/meta-builder-agent.md`
- `.claude/skills/skill-fix-it/SKILL.md` → must also update `.claude/extensions/core/skills/skill-fix-it/SKILL.md`
- `.claude/skills/skill-project-overview/SKILL.md` → must also update `.claude/extensions/core/skills/skill-project-overview/SKILL.md`

Verified with `diff` — all pairs are currently identical. The extension copies are sync targets.

---

## Decisions

1. **Fix scope**: Fix all 5 gaps (4 listed + skill-project-overview). The 5th gap is low-effort and improves consistency.
2. **Fields to add**: Both `"description"` and `"title"` fields where available. In Create Task (Gap 1/2), the improved description serves as both — use the same value for both fields. In meta-builder (Gap 3) and fix-it (Gap 4), distinct title and description exist and should both be stored.
3. **Extension copies**: Must be updated in sync. Both `.claude/` and `.claude/extensions/core/` copies must be changed together.
4. **generate-todo.sh**: No changes required — already handles both fields correctly.
5. **skill-spawn**: No changes required — already includes `"description": $desc`.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| jq variable injection issues with description containing newlines/quotes | Use `--arg` (not `--argjson`); `--arg` handles multiline strings and quotes safely |
| Forgetting to update extension copies | Implementation plan should list both paths explicitly for each change |
| Title/description mismatch in meta-builder where task has no separate description field | Use title as description fallback when description is empty |

---

## Summary: Change Inventory

| Location | Main File | Extension Copy | Fields to Add |
|----------|-----------|----------------|---------------|
| task.md Create Task (step 6) | `.claude/commands/task.md` | `.claude/extensions/core/commands/task.md` | `description`, `title` |
| task.md Expand Mode (step 3) | `.claude/commands/task.md` | `.claude/extensions/core/commands/task.md` | `description`, `title` |
| meta-builder-agent Stage 6 | `.claude/agents/meta-builder-agent.md` | `.claude/extensions/core/agents/meta-builder-agent.md` | `description`, `title` |
| skill-fix-it step 9.1 | `.claude/skills/skill-fix-it/SKILL.md` | `.claude/extensions/core/skills/skill-fix-it/SKILL.md` | `description`, `title` |
| skill-project-overview step 5.3 | `.claude/skills/skill-project-overview/SKILL.md` | `.claude/extensions/core/skills/skill-project-overview/SKILL.md` | `description`, `title` |

**Total files**: 5 main + 5 extension copies = **10 file edits**
