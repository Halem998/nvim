# Implementation Plan: Enrich state.json Schema as Single Source of Truth

- **Task**: 647 - Enrich state.json schema to be the single complete source of truth
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/647_enrich_state_json_schema/reports/01_team-research.md
- **Artifacts**: plans/01_enrich-state-schema.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Enrich the state.json schema so it contains all metadata needed to generate TODO.md without any reverse-parsing. The current schema is missing `title` on 11 of 17 active tasks, `description` on 4 tasks, `effort` on 1 task, and `topic`/`dependencies` on 2 legacy tasks. This plan adds the `title` field to the official schema reference, backfills all missing fields from TODO.md headings and entries, updates the `generate-task-order.sh` fallback chain to prefer `title`, and bumps the schema version to 1.1.0 to signal the enrichment to downstream scripts.

### Research Integration

Key findings from the team research report (01_team-research.md):

- 11 of 17 nvim tasks missing `title` field; all cslib tasks missing it entirely
- `title` and `description` are undocumented in `state-management-schema.md` despite being used in practice
- `generate-task-order.sh` uses `(.description // .project_name)` fallback -- does not see `title`
- 51 references to `project_name` across scripts; only display-text paths need `title` fallback
- `parent_task` and `blocker_reason` are low-value fields (skip per Critic recommendation)
- Schema version bump to "1.1.0" recommended to signal enrichment

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `title` field to all 11 existing tasks missing it in state.json (backfill from TODO.md headings)
- Ensure `description` is present for all 4 tasks currently missing it
- Fill missing `effort`, `topic`, and `dependencies` fields on legacy tasks (78, 87)
- Document `title` and `description` as schema fields in `state-management-schema.md`
- Update `generate-task-order.sh` to use `(.title // .description // .project_name)` fallback
- Bump schema version to "1.1.0"

**Non-Goals**:
- Adding `parent_task` or `blocker_reason` fields (low value, per research)
- Creating a migration script for other projects (cslib, BimodalLogic) -- that is out of scope
- Modifying `generate-todo.sh` (that is task 648)
- Filesystem artifact reconciliation (separate concern)
- Changing lazy directory creation patterns

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Title backfill has wrong text | L | L | Cross-reference TODO.md headings exactly; titles are unambiguous |
| jq update corrupts state.json | H | L | Use flock locking (already in place from task 645); validate JSON after each write |
| generate-task-order.sh fallback breaks display | M | L | Test with `--dry-run` style output comparison before and after |
| Schema version bump breaks scripts | L | L | Version is informational; no script currently reads it for branching |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Backfill missing fields in state.json [COMPLETED]

**Goal**: Add `title`, `description`, `effort`, `topic`, and `dependencies` to all task entries currently missing them.

**Tasks**:
- [x] Add `title` field to task 646 ("Harden TODO.md status updates") from TODO.md heading *(completed)*
- [x] Add `title` field to task 645 ("Fix parallel write safety for state.json") from TODO.md heading *(completed)*
- [x] Add `title` field to task 644 ("Add reconciliation preflight to orchestrator") from TODO.md heading *(completed)*
- [x] Add `title` field to task 643 ("Eliminate dual postflight ownership") from TODO.md heading *(completed)*
- [x] Add `title` field to task 642 ("Fix orchestrator_mode=false for research/plan dispatch") from TODO.md heading *(completed)*
- [x] Add `title` field to task 641 ("Fix meta-builder-agent topic assignment") from TODO.md heading *(completed)*
- [x] Add `title` field to task 640 ("Add topic revision stage to /todo skill") from TODO.md heading *(completed)*
- [x] Add `title` field to task 639 ("Fix /orchestrate TODO.md status sync and artifact linking") from TODO.md heading *(completed)*
- [x] Add `title` field to task 638 ("Fix generate-task-order.sh to create Task Order section when missing") from TODO.md heading *(completed)*
- [x] Add `title` field to task 87 ("Investigate terminal directory change when opening neovim in wezterm") from TODO.md heading *(completed)*
- [x] Add `title` field to task 78 ("Fix Himalaya SMTP authentication failure when sending emails") from TODO.md heading *(completed)*
- [x] Add `description` to task 639 from TODO.md (currently missing) *(completed)*
- [x] Add `description` to task 638 from TODO.md (currently missing) *(completed)*
- [x] Add `description` to task 87 from TODO.md (currently missing) *(completed)*
- [x] Add `description` to task 78 from TODO.md (currently missing) *(completed)*
- [x] Add `effort` field to task 87 (set to "TBD" matching TODO.md) *(completed)*
- [x] Add `topic` field to task 87 (set to "wezterm-notifications" or appropriate value) *(completed)*
- [x] Add `topic` field to task 78 (set to appropriate value, e.g., leave null or use existing topic) *(completed: wezterm-notifications)*
- [x] Add `dependencies` field to task 87 (empty array `[]`) *(completed)*
- [x] Bump schema version from "1.0.0" to "1.1.0" *(completed)*
- [x] Validate resulting state.json with `jq empty` to confirm valid JSON *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `specs/state.json` - Add missing fields to 11 task entries, bump version

**Verification**:
- `jq empty specs/state.json` succeeds (valid JSON)
- `jq '.active_projects[] | select(.title == null or .title == "") | .project_number' specs/state.json` returns empty (all tasks have title)
- `jq '.active_projects[] | select(.description == null or .description == "") | .project_number' specs/state.json` returns empty (all tasks have description)
- `jq '.version' specs/state.json` returns "1.1.0"

---

### Phase 2: Update state-management-schema.md to document new fields [COMPLETED]

**Goal**: Formalize `title` and `description` in the official schema reference so agents and scripts can rely on documented field specifications.

**Tasks**:
- [x] Add `title` to the Project Entry Fields table as a required string field with description: "Human-readable task title from creation. Used for TODO.md heading generation. Distinct from project_name which is the filesystem slug." *(completed)*
- [x] Add `description` to the Project Entry Fields table as a required string field with description: "Full task description including subsections. Stored as-is; multiline content uses literal newlines in JSON string." *(completed)*
- [x] Add a note clarifying the distinction between `project_name` (filesystem slug, snake_case) and `title` (display text, natural language) *(completed)*
- [x] Update the example JSON structure at the top of the file to include `title` and `description` fields *(completed)*
- [x] Note the version bump to 1.1.0 in the schema reference *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - Add `title` and `description` to field reference table

**Verification**:
- `title` appears in the Project Entry Fields table with type `string` and required `Yes`
- `description` appears in the Project Entry Fields table with type `string` and required `Yes`
- Example JSON structure includes both fields

---

### Phase 3: Update generate-task-order.sh fallback chain [COMPLETED]

**Goal**: Update the display text fallback in `generate-task-order.sh` to prefer `title` over `description` for task labels in the Task Order section.

**Tasks**:
- [x] Save current Task Order output for comparison (run `generate-task-order.sh` and capture output) *(completed)*
- [x] Update line 136 in `generate-task-order.sh`: change `(.description // .project_name)` to `(.title // .description // .project_name)` *(completed)*
- [x] Run `generate-task-order.sh` again and compare output to verify improved display (titles should now appear instead of truncated descriptions) *(completed: tasks 78 and 87 now show human-readable titles)*
- [x] Run `generate-task-order.sh --update-todo` to regenerate the Task Order section in TODO.md with the improved display *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - Update jq fallback chain on line 136

**Verification**:
- `grep "title // .description // .project_name" .claude/scripts/generate-task-order.sh` matches
- Task Order in TODO.md shows human-readable titles for tasks 78 and 87 (previously showed slugs)
- No task labels are empty or missing

---

### Phase 4: Validate completeness and cross-check [COMPLETED]

**Goal**: Comprehensive validation that state.json now contains all fields needed for TODO.md generation, and that no data was lost or corrupted during migration.

**Tasks**:
- [x] Run completeness audit: every task has `project_number`, `project_name`, `title`, `status`, `task_type`, `description`, `created`, `last_updated`, `dependencies`, `artifacts` *(completed: all 17 tasks pass)*
- [x] Cross-check all `title` values against TODO.md headings to confirm exact match *(completed: all 11 newly added titles match exactly)*
- [x] Verify `description` values match TODO.md description blocks (spot-check 3-4 tasks) *(completed: tasks 639, 638, 87, 78 verified)*
- [x] Confirm `effort` is present on all tasks (or explicitly null/absent for tasks where it was never set) *(completed: task 87 set to "TBD", all others already had effort)*
- [x] Verify state.json validates cleanly: `jq empty specs/state.json` *(completed: OK)*
- [x] Verify no task numbers were changed or duplicated *(completed: count=17, same as before)*
- [x] Confirm schema version is "1.1.0" *(completed)*

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only validation phase)

**Verification**:
- All audit checks pass with zero missing fields
- `jq '.active_projects | length' specs/state.json` returns 17 (same count as before)
- Cross-reference sample confirms data fidelity

## Testing & Validation

- [ ] `jq empty specs/state.json` succeeds (valid JSON)
- [ ] All 17 tasks have `title` field present and non-empty
- [ ] All 17 tasks have `description` field present and non-empty
- [ ] `generate-task-order.sh` runs without errors and produces correct output
- [ ] TODO.md Task Order section regenerated with human-readable titles
- [ ] `state-management-schema.md` documents both `title` and `description`
- [ ] Schema version reads "1.1.0"

## Artifacts & Outputs

- `specs/state.json` - Enriched with `title`, `description`, and missing metadata fields
- `.claude/context/reference/state-management-schema.md` - Updated field reference table
- `.claude/scripts/generate-task-order.sh` - Updated fallback chain
- `specs/647_enrich_state_json_schema/plans/01_enrich-state-schema.md` - This plan

## Rollback/Contingency

State.json is under git version control. If the migration introduces corruption:
1. `git checkout -- specs/state.json` to restore the pre-migration version
2. `git checkout -- .claude/context/reference/state-management-schema.md` to restore schema docs
3. `git checkout -- .claude/scripts/generate-task-order.sh` to restore original fallback

All changes are additive (new fields on existing entries) so partial rollback is also safe -- removing just the `title` field would leave state.json in its original state.
