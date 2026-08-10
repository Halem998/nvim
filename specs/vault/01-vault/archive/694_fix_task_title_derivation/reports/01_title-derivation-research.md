# Research Report: Task #694

**Task**: 694 - Fix task title derivation in task creation flows
**Started**: 2026-06-14T19:30:00Z
**Completed**: 2026-06-14T19:55:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (task.md, generate-todo.sh, meta-builder-agent.md, skill-fix-it/SKILL.md, skill-project-overview/SKILL.md, state.json files across projects)
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- The bug was introduced by commit `5c50df770` (task 692 phase 1-4) on 2026-06-14 at 11:00 AM, which added `"title": $desc` to task creation templates. This makes `title` identical to the full `description` field.
- The correct behavior is to derive `title` from `project_name` (capitalize first letter, replace underscores with spaces), matching the existing fallback in `generate-todo.sh` lines 192-196.
- There are **two primary locations** with the bug (`task.md` Create mode step 6 and Expand mode step 3 comment) plus **extension core copies** that must be kept in sync.
- The `meta-builder-agent.md` and `skill-fix-it/SKILL.md` handle title correctly (they use distinct title and description values from user interviews or hardcoded short strings).
- `cslib/specs/state.json` task 197 had title==description at creation but was already manually corrected in a later commit. The task description asks us to clean up this entry, but it no longer has the long title. No active tasks across any project currently have the title==description bug.
- `generate-todo.sh` already handles the case where `title` is null/absent by deriving from `project_name`. The fix should make `task.md` set `title` to a derived short form, or omit the `title` field entirely (relying on the fallback).

---

## Context & Scope

The agent system stores task entries in `specs/state.json` with a `title` field used by `generate-todo.sh` to render headings in `TODO.md`. Prior to commit `5c50df770`, this `title` field was absent from new task entries, causing `generate-todo.sh` to use its fallback (derive from `project_name`). Commit `5c50df770` (task 692, "persist description in task creation flows") added `"title": $desc` alongside `"description": $desc`, causing the title to be the full long description string — sometimes hundreds of characters.

Scope: All task creation flows that write to `state.json`, across the nvim project and any child projects that received synced copies.

---

## Findings

### 1. Root Cause: Where the Bug Was Introduced

**Commit**: `5c50df770` ("task 692 phase 1-4: add description/title to all task creation flows")
**Date**: 2026-06-14 at 11:00:46 UTC-7

The commit modified:
1. `.claude/commands/task.md` — Create mode step 6
2. `.claude/agents/meta-builder-agent.md` — Stage 6 jq template (added `$desc` note but not actual change)
3. `.claude/extensions/core/commands/task.md` — Same as #1
4. `.claude/extensions/core/agents/meta-builder-agent.md`
5. `.claude/extensions/core/skills/skill-fix-it/SKILL.md`

The stated goal was to persist description. The bug is that the same value (`$desc`, the full improved description) was written to both `"title"` and `"description"`.

### 2. generate-todo.sh Fallback Behavior (Lines 191-200)

The correct behavior is already documented in `generate-todo.sh`:

```bash
# Title fallback: derive from project_name if title is empty
if [[ -z "$title" || "$title" == "null" ]]; then
  if [[ -n "$project_name" && "$project_name" != "null" ]]; then
    # Replace underscores with spaces and capitalize first letter
    title="${project_name//_/ }"
    title="${title^}"
  else
    title="Task ${task_num}"
  fi
fi
```

This means:
- If `title` is null or absent in `state.json`, `generate-todo.sh` derives it as: replace `_` with space, capitalize first letter.
- Example: `fix_task_title_derivation` → `Fix task title derivation`
- The simplest fix is to **not write a `title` field** (omit it), letting the fallback handle it automatically.
- Alternatively, compute the derived title explicitly in the jq command and write it as a short value.

### 3. Affected Locations

#### LOCATION 1 (BUG - PRIMARY): `.claude/commands/task.md` — Create Mode, Step 6
**File**: `/home/benjamin/.config/nvim/.claude/commands/task.md`
**Lines**: 218-219
**Bug**:
```json
"title": $desc,
"description": $desc,
```
Both `title` and `description` receive `$desc` (the full improved description, potentially hundreds of characters).

**Fix**: Remove the `"title": $desc,` line from the jq template. The `description` field should be preserved. The `title` fallback in `generate-todo.sh` will derive it from `project_name`.

Alternatively, compute a derived title explicitly. However, the `project_name` slug is computed from `$improved_desc` in step 5, so the derived title would be `$improved_desc | lowercase | underscore → space | capitalize`, which is essentially what `generate-todo.sh` does from `project_name`.

**Recommendation**: Remove `"title": $desc,` from line 218. The `description` field at line 219 is correct and should remain.

#### LOCATION 2 (BUG - SECONDARY): `.claude/commands/task.md` — Expand Mode, Step 3 comment
**File**: `/home/benjamin/.config/nvim/.claude/commands/task.md`
**Lines**: 352-354
**Bug**:
```bash
# Each subtask jq entry MUST include "title" and "description" fields:
#   "title": $subtask_desc,
#   "description": $subtask_desc,
```
This instructs the LLM agent executing the expand mode to set `title` = `description` for each subtask.

**Fix**: Change the comment to either:
- Remove the `"title"` instruction entirely (let fallback handle it from project_name)
- Or instruct to derive title from subtask description: `"title": (derive short form from slug)`

**Recommendation**: Remove the `"title": $subtask_desc,` line from the comment block. Subtask project_names are set by the agent, so `generate-todo.sh` will derive a readable title from them.

#### LOCATION 3 (CORRECT): `.claude/agents/meta-builder-agent.md` — Stage 6 state.json Entry
**File**: `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md`
**Lines**: 692-706
**Status**: CORRECT — no fix needed

The meta-builder-agent uses `"{task.title}"` and `"{task.description}"` which come from distinct fields populated during the multi-turn interview (Stage 3A). The interview explicitly collects both a `title` (from the task breakdown discussion) and a separate `description` from the user. These are different values, so the meta-builder-agent correctly distinguishes them.

However, there is a subtle risk: the note at line 704 says `$task_title` comes from `task_list[].title` and `$task_description` from `task_list[].description`. During the interview, the `task_list` may populate `title` and `description` as the same value if the agent doesn't create them as distinct fields. This is an execution-time concern, not a template bug.

#### LOCATION 4 (CORRECT): `skill-fix-it/SKILL.md` — Step 9.1 state.json Entry
**File**: `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md`
**Lines**: 494, 510
**Status**: CORRECT — no fix needed

The skill-fix-it uses `"{title}"` and `"{description}"` as template variables. These are populated from hardcoded short title strings defined in Sections 8.2a-8.5 of the SKILL.md (e.g., `"Update context files from NOTE: tags"`, `"Fix issues from FIX:/NOTE: tags"`, `"{topic_label}: {item_count} TODO items"`). These titles are short and distinct from the description content. This is correct behavior.

#### LOCATION 5 (CORRECT): `skill-project-overview/SKILL.md` — Section 5.3
**File**: `/home/benjamin/.config/nvim/.claude/skills/skill-project-overview/SKILL.md`
**Line**: 401
**Status**: CORRECT — no fix needed

Uses a hardcoded short title `"Generate project-overview.md"` which is clearly distinct from its description.

#### LOCATION 6 (BUG - COPY): `.claude/extensions/core/commands/task.md`
**File**: `/home/benjamin/.config/nvim/.claude/extensions/core/commands/task.md`
**Lines**: 218-219 (same offset as Location 1)
**Status**: Same bug as Location 1 — this is the extension core copy that gets synced

**Fix**: Same as Location 1 — remove `"title": $desc,` from the jq template.

#### LOCATION 7 (BUG - COPY): `cslib/.claude/commands/task.md`
**File**: `/home/benjamin/Projects/cslib/.claude/commands/task.md`
**Lines**: 218-219
**Status**: Same bug as Location 1 — this is a project copy

**Fix**: Same as Location 1 — remove `"title": $desc,` from the jq template.

### 4. Task.md Files WITHOUT the Bug

- `/home/benjamin/.config/.claude/commands/task.md` (parent/shared config) — never had `title` in step 6 template; uses older format
- `/home/benjamin/Projects/theorem_proving_in_lean4/.claude/commands/task.md` — file dated Jun 11, predates the bug commit (Jun 14); no `title` in step 6 template

### 5. cslib Task 197 State

**Current state**: Task 197 was created with the bug (title == full 318-char description). The creation commit `d8b84dca` (2026-06-14 12:08 local) is confirmed to show `title == description` for task 197. A subsequent manual correction changed the title to `"Scope initial Modal/ upstream PR (~300 LOC)"` — verified via `git show d8b84dca:specs/state.json`.

**Current state.json**: Task 197 currently has a short title `"Scope initial Modal/ upstream PR (~300 LOC)"` (43 chars) distinct from the full description (318 chars). The title is no longer overly long.

**Task description says**: "Fix should also clean up cslib task 197 state.json entry to remove the overly long title field."

Interpretation: The task description was written when the overly long title was still in state.json. Since it was already manually fixed (but the title field still exists, differing from the fallback), the fix could either:
1. **Leave as-is**: The title is already short and distinct from description.
2. **Remove the title field**: Letting the fallback derive `"Modal upstream initial pr"` from `project_name` = `modal_upstream_initial_pr`.
3. **Keep but update**: If the title field should exactly match the project_name fallback, update it to `"Modal upstream initial pr"`.

The simplest approach consistent with the task goal (having titles derived from project_name) is to **remove the title field** from task 197's state.json entry, so the fallback behavior takes effect. This also serves as a concrete example to validate the fix works.

### 6. No Other Tasks Require Cleanup

Scanning all active task entries across nvim, cslib, zed, ModelChecker, BimodalHarness, and theorem_proving_in_lean4 projects: **no active tasks currently have `title == description` with a long title.** The bug in task 197 (cslib) was already manually corrected.

---

## Decisions

1. The correct fix for task.md Create mode is to **remove the `"title": $desc,` line** (not replace it with a derived title). The fallback in `generate-todo.sh` already correctly derives the title from `project_name`, and the `project_name` slug is built from the same `$improved_desc` value. Keeping the `"description"` field is correct and should remain.

2. The fix must be applied to **three files**: the nvim-project task.md, the extensions/core copy, and the cslib copy.

3. The meta-builder-agent.md and skill-fix-it/SKILL.md do NOT need changes — they correctly use distinct title and description values.

4. The expand mode step 3 comment in task.md needs the `"title": $subtask_desc,` instruction removed to prevent agents from writing long titles for subtasks.

5. For cslib task 197: since it was already manually corrected but still has a `title` field (with a handwritten short title), the cleanest resolution is to **remove the `title` field** to make the fallback apply, or leave it since it's now short. The task description says "remove the overly long title field" — since the title is no longer overly long, a pragmatic interpretation is to leave it, but to validate the fix, remove it.

---

## Risks & Mitigations

- **Risk**: After removing `"title": $desc`, existing tasks with `title` already set in state.json are unaffected (generate-todo.sh only uses fallback when title is null/absent).
- **Risk**: The meta-builder-agent interview may produce task_list entries where `title == description` if the agent conflates them. Mitigation: the meta-builder-agent instructions already clearly separate these in the interview stage — low risk.
- **Risk**: The extensions/core copy is a separate file that must be kept in sync manually. Mitigation: the fix is simple (one line removal) and easy to verify.
- **Risk**: Other child projects (e.g., ModelChecker, BimodalHarness) have task.md copies that predate the bug and do NOT have `title` in step 6 — they will continue to work correctly without changes.

---

## Recommended Changes (Summary)

| File | Location | Change |
|------|----------|--------|
| `/home/benjamin/.config/nvim/.claude/commands/task.md` | Line 218, Create mode step 6 | Remove `"title": $desc,` |
| `/home/benjamin/.config/nvim/.claude/commands/task.md` | Lines 352-354, Expand mode step 3 comment | Remove `#   "title": $subtask_desc,` line |
| `/home/benjamin/.config/nvim/.claude/extensions/core/commands/task.md` | Same lines as above | Same changes (sync copy) |
| `/home/benjamin/Projects/cslib/.claude/commands/task.md` | Same lines as above | Same changes (project copy) |
| `/home/benjamin/Projects/cslib/specs/state.json` | Task 197 entry | Remove or keep `title` field (already corrected to short value; remove for consistency with fallback approach) |

**Files NOT needing changes:**
- `.claude/agents/meta-builder-agent.md` (correct behavior)
- `.claude/extensions/core/agents/meta-builder-agent.md` (correct behavior)
- `skill-fix-it/SKILL.md` and its extension core copy (correct behavior)
- `skill-project-overview/SKILL.md` and its extension core copy (correct behavior)
- `theorem_proving_in_lean4/.claude/commands/task.md` (predates bug, no title in template)
- `.config/.claude/commands/task.md` (shared parent config, also no title in template)

---

## Context Extension Recommendations

- The `generate-todo.sh` fallback behavior (title derivation from project_name) should be documented in a context file so future agents know to rely on it rather than setting `title` redundantly. Suggested location: `.claude/context/patterns/task-title-derivation.md`
