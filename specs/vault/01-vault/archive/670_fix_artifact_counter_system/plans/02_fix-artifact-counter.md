# Implementation Plan: Task #670

- **Task**: 670 - fix_artifact_counter_system
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/670_fix_artifact_counter_system/reports/01_artifact-counter-analysis.md
- **Artifacts**: plans/02_fix-artifact-counter.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix four bugs in the artifact counter system (`next_artifact_number` in state.json) that cause filename collisions, counter drift, and confusing numbering in multi-revision workflows. The core fix is a shared reconciliation helper added to all four skill files that produces collision-free artifact numbers, combined with making the reviser skill increment the counter on each revision. Documentation is updated to clarify that `plan_version` is metadata-only and never appears in filenames.

### Research Integration

The research report (01_artifact-counter-analysis.md) identified four bugs with exact file locations and proposed fixes:

1. **Bug 1** (line 123 of skill-reviser): Revision uses `next_artifact_number - 1` and never increments, causing all revisions to share the same artifact number.
2. **Bug 2** (Stage 3a in skill-planner and skill-reviser): No collision check when computed artifact number matches existing files on disk.
3. **Bug 3** (state.json): Counter drift for legacy tasks where `next_artifact_number` does not reflect actual artifact count on disk.
4. **Bug 4** (plan-format.md, artifact-formats.md): `plan_version` vs artifact sequence confusion. Investigation shows `plan_version` is already correctly scoped to state.json metadata only -- the confusion was historical (BimodalLogic task 273) and will be resolved naturally by Bug 1 fix making artifact numbers monotonic.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items are directly advanced by this task. This is an agent-system infrastructure fix that improves reliability of all tasks going through multi-revision cycles.

## Goals & Non-Goals

**Goals**:
- Revisions get unique, incrementing artifact numbers (Bug 1)
- Artifact numbers never collide with existing files on disk (Bug 2)
- Counter automatically reconciles with actual files for legacy tasks (Bug 3)
- Documentation clarifies plan_version is metadata-only, not a filename component (Bug 4)

**Non-Goals**:
- Renaming existing artifacts from prior tasks (historical artifacts are fine)
- Changing the "round" concept where plan/summary share the research round number
- Modifying the plan_version field itself in state.json schema (it stays as useful metadata)
- Creating a separate shared bash script (the reconciliation logic is ~10 lines, inlined in each skill)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Revision counter increment breaks round semantics for plan-after-research | H | L | Revision is explicitly a new planning attempt, not part of the research round. Plan-after-research still uses `current - 1`. Only revision uses `current` and increments. |
| Reconciliation falsely advances counter due to unexpected filenames | M | L | sed pattern strictly matches `NN_` prefix; non-matching files ignored |
| Extension core copies fall out of sync | M | M | Phase 4 explicitly syncs all 4 core copies and verifies byte-identical |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix skill-reviser -- increment counter and add reconciliation [COMPLETED]

**Goal**: Make each revision create an artifact with a unique, monotonically increasing number by (a) using `next_artifact_number` directly instead of `current - 1`, (b) adding disk reconciliation to handle legacy drift, (c) adding collision detection, and (d) incrementing the counter in postflight.

**Tasks**:
- [x] In `.claude/skills/skill-reviser/SKILL.md` Stage 3a (lines 95-123):
  - Change artifact number computation from `artifact_number=$((next_num - 1))` to `artifact_number=$next_num` (use the current counter value directly)
  - Add reconciliation block after reading `next_num`: scan all subdirectories under the task directory for `[0-9][0-9]_*.md` files, extract max artifact number from disk, and if counter is behind disk, advance to `max_on_disk + 1`
  - Add collision check: after computing `artifact_padded`, check if any file matching `${artifact_padded}_*.md` exists in `plans/`; if so, increment until no collision
  - Update the note at line 123 to explain that revision now increments the counter *(completed)*
- [x] In `.claude/skills/skill-reviser/SKILL.md` Stage 8 postflight (around lines 350-363):
  - Add `next_artifact_number` increment via jq (same pattern as skill-team-research Stage 8a, lines 236-244): `jq '(.active_projects[] | select(.project_number == N)).next_artifact_number = ((... // 1) + 1)' specs/state.json` *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-reviser/SKILL.md` - Change artifact number calculation from `current-1` to `current`, add reconciliation, add collision check, add counter increment in postflight

**Verification**:
- Read the modified SKILL.md and confirm: (a) artifact_number uses `next_num` not `next_num - 1`, (b) reconciliation block exists, (c) collision loop exists, (d) postflight increments `next_artifact_number`
- Mentally trace: with `next_artifact_number=5`, revision should produce `05_*.md` and counter becomes 6

---

### Phase 2: Add reconciliation and collision detection to skill-planner and skill-researcher [COMPLETED]

**Goal**: Add the same reconciliation and collision detection logic to skill-planner and skill-researcher so all three skills that produce plan artifacts (planner, reviser) and research artifacts (researcher) handle legacy drift and avoid collisions.

**Tasks**:
- [x] In `.claude/skills/skill-planner/SKILL.md` Stage 3a (lines 110-136):
  - Add reconciliation block after reading `next_num` and computing `artifact_number = next_num - 1`: scan task directory subdirectories for max artifact number on disk; if `artifact_number <= max_on_disk`, set `artifact_number = max_on_disk + 1`
  - Add collision check: after computing `artifact_padded`, check if any file matching `${artifact_padded}_*.md` exists in `plans/`; if so, increment until no collision *(completed)*
- [x] In `.claude/skills/skill-researcher/SKILL.md` Stage 3a (lines 102-120):
  - Add reconciliation block after reading `next_num`: scan task directory subdirectories for max artifact number on disk; if `artifact_number <= max_on_disk`, set `artifact_number = max_on_disk + 1`
  - Add collision check: after computing `artifact_padded`, check if any file matching `${artifact_padded}_*.md` exists in `reports/`; if so, increment until no collision
  - If reconciliation adjusted the number, also update `next_artifact_number` in state.json to `artifact_number + 1` so subsequent operations stay in sync *(completed)*
- [x] In `.claude/skills/skill-team-research/SKILL.md` Stage 3a (lines 79-93):
  - Add the same reconciliation and collision detection as skill-researcher *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Add reconciliation and collision detection to Stage 3a
- `.claude/skills/skill-researcher/SKILL.md` - Add reconciliation and collision detection to Stage 3a
- `.claude/skills/skill-team-research/SKILL.md` - Add reconciliation and collision detection to Stage 3a

**Verification**:
- Each file has reconciliation block (scan disk, compare, advance if behind)
- Each file has collision check (loop until no existing file at prefix)
- Mentally trace legacy scenario: `next_artifact_number=5` but 8 files exist on disk -> researcher uses 09, counter becomes 10

---

### Phase 3: Update documentation for plan_version clarity [COMPLETED]

**Goal**: Add clarifying documentation that `plan_version` is a state.json metadata field only and does not appear in filenames. Update artifact-formats.md to note that revision increments the counter.

**Tasks**:
- [x] In `.claude/context/formats/plan-format.md` (around lines 29-47):
  - Add a clarifying note under the `plan_metadata` schema: "`plan_version` tracks the semantic version of plan evolution and is used in commit messages and human reference. It does NOT appear in filenames. Artifact filenames use the unified `next_artifact_number` sequence." *(completed)*
- [x] In `.claude/rules/artifact-formats.md` under "Unified Sequential Numbering":
  - Update the description to include revision behavior: "**Revision**: Advances the sequence (reads `next_artifact_number`, uses it, increments) -- same as research, since each revision is a new planning attempt."
  - Update the example flow to show revision *(completed)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/context/formats/plan-format.md` - Add plan_version clarification note
- `.claude/rules/artifact-formats.md` - Update sequential numbering docs to include revision behavior

**Verification**:
- plan-format.md has explicit note that plan_version does not appear in filenames
- artifact-formats.md shows revision in the example flow and lists it under the round concept
- No contradictions between the two documents

---

### Phase 4: Sync extension core copies [COMPLETED]

**Goal**: Copy all modified skill files to their extension core counterparts and verify byte-identical.

**Tasks**:
- [x] Copy `.claude/skills/skill-reviser/SKILL.md` to `.claude/extensions/core/skills/skill-reviser/SKILL.md` *(completed)*
- [x] Copy `.claude/skills/skill-planner/SKILL.md` to `.claude/extensions/core/skills/skill-planner/SKILL.md` *(completed)*
- [x] Copy `.claude/skills/skill-researcher/SKILL.md` to `.claude/extensions/core/skills/skill-researcher/SKILL.md` *(completed)*
- [x] Copy `.claude/skills/skill-team-research/SKILL.md` to `.claude/extensions/core/skills/skill-team-research/SKILL.md` *(completed)*
- [x] Verify all 4 pairs are byte-identical using `diff` *(completed: diff reports no differences)*

**Timing**: 10 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/core/skills/skill-reviser/SKILL.md` - Sync from live copy
- `.claude/extensions/core/skills/skill-planner/SKILL.md` - Sync from live copy
- `.claude/extensions/core/skills/skill-researcher/SKILL.md` - Sync from live copy
- `.claude/extensions/core/skills/skill-team-research/SKILL.md` - Sync from live copy

**Verification**:
- `diff` reports no differences between each live/core pair
- All 4 copies are identical

## Testing & Validation

- [ ] Read all 4 modified skill SKILL.md files and confirm reconciliation + collision detection blocks are present
- [ ] Verify skill-reviser uses `next_num` (not `next_num - 1`) and increments counter in postflight
- [ ] Verify skill-planner and skill-researcher do NOT increment counter (existing behavior preserved)
- [ ] Verify all 4 extension core copies are byte-identical to live copies
- [ ] Verify plan-format.md has plan_version clarification
- [ ] Verify artifact-formats.md shows revision in example flow
- [ ] Trace happy path: research(1)->plan(1)->revise(2)->revise(3)->research(4)->plan(4) -- numbers are monotonic

## Artifacts & Outputs

- `specs/670_fix_artifact_counter_system/plans/02_fix-artifact-counter.md` (this plan)
- `specs/670_fix_artifact_counter_system/summaries/02_fix-artifact-counter-summary.md` (after implementation)
- Modified: 4 skill SKILL.md files (live) + 4 extension core copies + 2 documentation files = 10 files total

## Rollback/Contingency

All changes are to `.claude/` markdown skill definitions and documentation. If the fixes cause unexpected behavior:
1. `git checkout HEAD -- .claude/skills/skill-reviser/SKILL.md .claude/skills/skill-planner/SKILL.md .claude/skills/skill-researcher/SKILL.md .claude/skills/skill-team-research/SKILL.md`
2. Sync core copies from reverted live copies
3. The counter value in state.json is unaffected by the code changes (only actual execution would change it)
