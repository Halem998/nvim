# Implementation Plan: Fix Task Title Derivation

- **Task**: 694 - Fix task title derivation in task.md step 6
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/694_fix_task_title_derivation/reports/01_title-derivation-research.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the `"title": $desc,` line from the jq template in `task.md` Create mode (step 6) and the corresponding comment in Expand mode (step 3). The `generate-todo.sh` fallback already correctly derives titles from `project_name` (replace underscores with spaces, capitalize first letter). The fix must be applied to three copies of `task.md`: the nvim project copy, the extension core copy, and the cslib project copy.

### Research Integration

Research report (01_title-derivation-research.md) confirmed:
- Bug introduced by commit `5c50df770` (task 692) which added `"title": $desc` to jq templates
- Two bug locations per file: Create mode line 218, Expand mode comment lines 352-354
- `meta-builder-agent.md`, `skill-fix-it/SKILL.md`, and `skill-project-overview/SKILL.md` are correct and need no changes
- cslib `state.json` no longer exists (specs directory only contains archive), so no cleanup needed there

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this fix. This is a regression fix for the agent system.

## Goals & Non-Goals

**Goals**:
- Remove the redundant `"title": $desc,` line from task creation jq templates in all three copies of `task.md`
- Remove the misleading Expand mode comment that instructs agents to set `"title": $subtask_desc`
- Ensure new tasks rely on the `generate-todo.sh` fallback for title derivation from `project_name`

**Non-Goals**:
- Modifying `generate-todo.sh` (the fallback behavior is already correct)
- Changing `meta-builder-agent.md` or `skill-fix-it/SKILL.md` (they correctly use distinct title/description values)
- Adding explicit title derivation logic to `task.md` (the fallback is sufficient)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing tasks with `title` field already set are unaffected | L | N/A | `generate-todo.sh` only uses fallback when title is null/absent |
| Extension core copy drifts from project copy | M | L | Fix is identical across all three files; verify with diff |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove title from jq templates [COMPLETED]

**Goal**: Remove the `"title": $desc,` line from Create mode and the title comment from Expand mode across all three copies of `task.md`.

**Tasks**:
- [ ] In `.claude/commands/task.md` line 218: remove `"title": $desc,`
- [ ] In `.claude/commands/task.md` lines 352-354: remove the three-line comment block instructing to include title (lines: `# Each subtask jq entry MUST include "title" and "description" fields:`, `#   "title": $subtask_desc,`, `#   "description": $subtask_desc,`), replace with a single comment: `# Each subtask jq entry MUST include a "description" field:`
- [ ] In `.claude/extensions/core/commands/task.md`: apply identical changes (same line numbers)
- [ ] In `/home/benjamin/Projects/cslib/.claude/commands/task.md`: apply identical changes (same line numbers)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/nvim/.claude/commands/task.md` - Remove title line 218, fix comment lines 352-355
- `/home/benjamin/.config/nvim/.claude/extensions/core/commands/task.md` - Same changes
- `/home/benjamin/Projects/cslib/.claude/commands/task.md` - Same changes

**Verification**:
- `grep -n '"title": \$desc' .claude/commands/task.md` returns no matches
- `grep -n '"title": \$subtask_desc' .claude/commands/task.md` returns no matches
- Same grep on extension core copy and cslib copy returns no matches
- `diff .claude/commands/task.md .claude/extensions/core/commands/task.md` shows no differences in the modified sections

---

### Phase 2: Validate fix [COMPLETED]

**Goal**: Confirm the title derivation fallback works correctly for existing and new tasks.

**Tasks**:
- [ ] Run `bash .claude/scripts/generate-todo.sh` and verify TODO.md renders correctly
- [ ] Verify no regressions by checking that existing tasks with title fields still display correctly
- [ ] Verify tasks without title fields derive titles from `project_name` correctly

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None (validation only)

**Verification**:
- `generate-todo.sh` completes without errors
- TODO.md contains correct task titles for all active tasks
- No task titles appear as full multi-sentence descriptions

## Testing & Validation

- [ ] `grep -rn '"title": \$desc' .claude/commands/task.md .claude/extensions/core/commands/task.md` returns no matches
- [ ] `grep -rn '"title": \$subtask_desc' .claude/commands/task.md .claude/extensions/core/commands/task.md` returns no matches
- [ ] `bash .claude/scripts/generate-todo.sh` completes without errors
- [ ] TODO.md renders correctly with derived titles

## Artifacts & Outputs

- plans/01_implementation-plan.md (this file)
- summaries/01_title-derivation-summary.md (post-implementation)

## Rollback/Contingency

Re-add `"title": $desc,` line to the jq templates in all three `task.md` files. Since the title field is additive (generate-todo.sh falls back when absent), removing it is safe and easily reversible.
