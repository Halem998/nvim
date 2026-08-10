# Implementation Plan: Task #620

- **Task**: 620 - Fix generate-task-order.sh to properly handle Task Order sections
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/620_fix_task_order_generation/reports/01_task-order-research.md
- **Artifacts**: plans/01_fix-task-order.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix three issues in the Task Order generation pipeline: (1) un-slugify the `project_name` fallback in `generate-task-order.sh` so tasks without a `description` field display readable text instead of underscore slugs, (2) add a `/revise` postflight trigger for Task Order regeneration so the section stays current after plan revisions, and (3) verify end-to-end that completed task pruning works correctly and document the full set of regeneration triggers. The script's core filtering logic is already correct; the fixes target data presentation and trigger coverage gaps.

### Research Integration

Key findings from `reports/01_task-order-research.md`:
- The script correctly filters completed/abandoned/expanded tasks via `select(.status == "completed" | not)`. The stale Task Order in BimodalLogic is caused by the section never being regenerated, not by a script bug.
- Tasks with `description: null` in state.json fall back to `project_name` slugs (e.g., `copyright_headers_universe_polymorphism_line_limits`), which appear unreadable. Fix: un-slugify by replacing underscores with spaces.
- `/revise` postflight calls `update-task-status.sh postflight plan` which only does Mode A (in-place status update), never full regeneration. Adding a direct call to `generate-task-order.sh --update-todo` after the status update would close this gap.
- `link-artifact-todo.sh` is safe and does not interact with the Task Order section.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Un-slugify `project_name` fallback so Task Order displays readable descriptions
- Add `/revise` postflight trigger for Task Order regeneration
- Verify and document that completed task pruning works end-to-end
- Update format documentation to reflect the full trigger table

**Non-Goals**:
- Adding a `--preserve-headings` mode for BimodalLogic (deferred; requires separate design)
- Populating missing `description` fields in BimodalLogic's state.json (data quality fix, out of scope)
- Modifying `link-artifact-todo.sh` (confirmed safe per research)
- Changing the Task Order format itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Un-slugify regex breaks on edge-case project_name values | M | L | Use simple `_` to space replacement; test with sample slugs |
| Revise postflight regeneration overwrites hand-curated Task Order | M | M | Only affects projects using auto-generated format; BimodalLogic issue is deferred separately |
| sed replacement in generate-task-order.sh alters wrong lines | H | L | The `build_graph` description loading uses bash variable substitution, not sed on TODO.md |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Un-slugify project_name fallback in generate-task-order.sh [COMPLETED]

**Goal**: Make Task Order display readable descriptions when tasks lack a `description` field in state.json, by converting underscore-separated `project_name` slugs into space-separated text.

**Tasks**:
- [x] In `build_graph()` function (around line 143-144), after `desc="${line#*|}"`, add a line to replace underscores with spaces: `desc="${desc//_/ }"` *(completed)*
- [x] Verify the un-slugify applies only to the `task_desc` map population, not to any file path or variable name usage *(completed)*
- [x] Test by running `generate-task-order.sh --print` against the local nvim project's state.json to confirm output format *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - Add underscore-to-space replacement in `build_graph()` after description extraction

**Verification**:
- Run `bash .claude/scripts/generate-task-order.sh --print` and confirm tasks without descriptions show space-separated words instead of underscore slugs
- Confirm tasks WITH descriptions are unaffected (the `//` fallback means `description` takes priority over `project_name`)

---

### Phase 2: Add /revise postflight trigger for Task Order regeneration [COMPLETED]

**Goal**: Ensure the Task Order section is regenerated after `/revise` completes, so description updates and status changes are reflected in the tree.

**Tasks**:
- [x] In `skill-reviser/SKILL.md`, after the Stage 7 status update (`update-task-status.sh postflight plan`), add a Stage 7a that calls `generate-task-order.sh --update-todo` for full Task Order regeneration *(completed)*
- [x] The new stage should be non-fatal (wrapped in `|| { echo "Warning: ..."; }` pattern matching existing usage in skill-todo) *(completed)*
- [x] Add the regeneration as a separate bash code block with clear documentation *(completed)*
- [x] Update the Stage 9 git commit to note Task Order regeneration in the commit scope (no change to commit message format needed, just ensure the regenerated TODO.md is included in `git add`) *(deviation: skipped — git add -A in Stage 9 already captures all changes including the regenerated TODO.md; no modification needed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-reviser/SKILL.md` - Add Stage 7a for Task Order regeneration after status update

**Verification**:
- Read the modified SKILL.md and confirm the new stage follows the non-fatal pattern used in skill-todo Stage 10.5
- Confirm the stage is placed after Stage 7 (status update) and before Stage 8 (artifact linking)

---

### Phase 3: Update documentation and verify end-to-end [COMPLETED]

**Goal**: Update format documentation to reflect the complete regeneration trigger table, including the new `/revise` trigger, and verify the full pipeline works correctly.

**Tasks**:
- [x] Update `state-management.md` Task Order Synchronization section: add `/revise` to the Regeneration Triggers table *(completed)*
- [x] Update `task-order-format.md` if it contains a triggers section (update the `update-task-status.sh Integration` section to note the `/revise` postflight trigger) *(completed)*
- [x] Verify `generate-task-order.sh --print` runs without errors on the nvim project *(completed)*
- [x] Verify the script correctly excludes any completed/abandoned tasks from the output *(completed)*
- [x] Confirm the wave table and grouped sections render correctly *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/rules/state-management.md` - Add `/revise` to Regeneration Triggers table
- `.claude/context/formats/task-order-format.md` - Add note about `/revise` postflight trigger in the Generation section

**Verification**:
- Grep for "revise" in state-management.md and task-order-format.md to confirm additions
- Run `bash .claude/scripts/generate-task-order.sh --print` and verify output is well-formed
- Count tasks in output vs active non-terminal tasks in state.json to confirm completed task pruning

---

## Testing & Validation

- [ ] `bash .claude/scripts/generate-task-order.sh --print` produces valid output with readable descriptions
- [ ] Tasks without `description` field show space-separated project_name instead of underscore slugs
- [ ] Tasks with `description` field are displayed unchanged
- [ ] No completed/abandoned/expanded tasks appear in the output
- [ ] Wave table and grouped topic sections are well-formed
- [ ] Skill-reviser SKILL.md contains the new Task Order regeneration stage
- [ ] state-management.md Regeneration Triggers table includes `/revise`

## Artifacts & Outputs

- `plans/01_fix-task-order.md` (this plan)
- Modified `.claude/scripts/generate-task-order.sh`
- Modified `.claude/skills/skill-reviser/SKILL.md`
- Modified `.claude/rules/state-management.md`
- Modified `.claude/context/formats/task-order-format.md`

## Rollback/Contingency

All changes are to `.claude/` infrastructure files tracked in git. If any modification causes issues:
- `git diff .claude/scripts/generate-task-order.sh` to review changes
- `git checkout .claude/scripts/generate-task-order.sh` to revert specific file
- The un-slugify change is purely cosmetic and has no functional impact on dependency computation
- The reviser trigger is non-fatal by design and will not block `/revise` operations
