# Implementation Plan: Task #630

- **Task**: 630 - Consolidate orchestrate postflight with skill-base.sh pattern
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/630_consolidate_orchestrate_postflight/reports/01_consolidate-postflight.md
- **Artifacts**: plans/01_consolidate-postflight.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The orchestrate skill (SKILL.md) contains a 24-line artifact-type-to-field-name mapping case block that is duplicated identically in Stage 5 (single-task postflight, lines ~409-426) and Stage MT-4 (multi-task postflight, lines ~1046-1063). This plan extracts the mapping into a new `skill_link_artifact_from_handoff()` helper function in `skill-base.sh`, then replaces both duplicate blocks with single-line calls to the new helper. Net reduction is approximately 31 lines.

### Research Integration

The research report confirmed that the orchestrate skill already routes through `skill_postflight_update()` and `skill_link_artifacts()` from `skill-base.sh` -- no parallel postflight implementation exists. The actual duplication is the artifact type to field name mapping case statement, which appears identically in two locations within SKILL.md. The recommended approach (Option A) is to add the helper to `skill-base.sh` since the mapping is a system-wide convention.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task. The work aligns with the "Agent System Quality" theme in Phase 1 but does not correspond to a specific checklist item.

## Goals & Non-Goals

**Goals**:
- Eliminate the duplicated 24-line case block between Stage 5 and Stage MT-4
- Add a reusable `skill_link_artifact_from_handoff()` helper to `skill-base.sh`
- Preserve identical runtime behavior (no functional changes)

**Non-Goals**:
- Refactoring the `skill_postflight_update` dispatch logic (already uses skill-base.sh correctly)
- Consolidating handoff reading logic beyond the artifact-linking case block
- Modifying any other skills (only orchestrate calls this pattern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New helper not sourced at call sites | H | L | Both Stage 5 and MT-4 already source skill-base.sh at Stage 1 (line 54); no additional sourcing needed |
| Handoff JSON quoting issues in function parameter | M | L | Use same `echo "$handoff" \| jq` pattern as existing code; tested by passing handoff variable directly |
| Regression in artifact linking | H | L | Verify by grepping for old case block to confirm complete removal; manual test with /orchestrate on a test task |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add skill_link_artifact_from_handoff() to skill-base.sh [COMPLETED]

**Goal**: Create the new helper function in the shared skill library.

**Tasks**:
- [x] Add `skill_link_artifact_from_handoff()` function after the existing `skill_link_artifacts()` function (after line ~367) *(completed)*
- [x] Function signature: `skill_link_artifact_from_handoff "$task_number" "$handoff_json"` *(completed)*
- [x] Extract artifact path, type, and summary from handoff JSON using jq *(completed)*
- [x] Guard for empty/null artifact path (return 0 early) *(completed)*
- [x] Map artifact type to field_name and next_field using a case statement (report -> Research/Plan, plan -> Plan/Description, summary/default -> Summary/Description) *(completed)*
- [x] Call `skill_link_artifacts` with the mapped values *(completed)*
- [x] Add function documentation comment block following existing convention *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Add new function (~20 lines) after `skill_link_artifacts` block

**Verification**:
- Function exists in skill-base.sh after the edit
- `bash -n .claude/scripts/skill-base.sh` passes (syntax check)
- Function signature matches: `skill_link_artifact_from_handoff "$task_number" "$handoff_json"`

---

### Phase 2: Refactor Stage 5 and Stage MT-4 in SKILL.md [COMPLETED]

**Goal**: Replace both duplicate case blocks with calls to the new helper.

**Tasks**:
- [x] In Stage 5 (lines ~404-429): replace the artifact extraction, guard, case block, and `skill_link_artifacts` call with a single call to `skill_link_artifact_from_handoff "$task_number" "$handoff"` *(completed)*
- [x] In Stage MT-4 (lines ~1041-1066): replace the identical block with a single call to `skill_link_artifact_from_handoff "$task_num" "$handoff"` *(completed)*
- [x] Preserve the surrounding code in both locations (handoff reading, drift detection, loop guard, multi-state tracking) *(completed)*
- [x] Update the comment in Stage MT-4 (line ~1041 `# Artifact linking (same logic as single-task Stage 5)`) to reference the shared helper instead *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace ~48 lines across two locations with ~2 lines each

**Verification**:
- `grep -c "handoff_artifact_type" .claude/skills/skill-orchestrate/SKILL.md` returns 0 (old variable removed from both blocks)
- `grep -c "skill_link_artifact_from_handoff" .claude/skills/skill-orchestrate/SKILL.md` returns 2 (one call per location)
- No other references to the old case block pattern remain

---

### Phase 3: Verification and Cleanup [COMPLETED]

**Goal**: Confirm no regressions and no remaining duplicates.

**Tasks**:
- [x] Run `bash -n .claude/scripts/skill-base.sh` to confirm syntax validity *(completed: SYNTAX OK)*
- [x] Grep across all skill files to confirm no other callers use the old inline pattern: `grep -rn "handoff_artifact_type" .claude/skills/` *(completed: none found)*
- [x] Verify the new function handles edge cases: empty artifact path returns 0, unknown type defaults to Summary/Description *(completed: guard and default case in place)*
- [x] Confirm no other skills need to be updated (research report confirmed only orchestrate uses this pattern) *(completed)*

**Timing**: 10 minutes

**Depends on**: 2

**Files to modify**:
- None (verification only)

**Verification**:
- All grep checks pass as documented above
- `bash -n` syntax check passes
- Net line count reduction confirmed (~31 lines fewer across both files combined)

## Testing & Validation

- [ ] `bash -n .claude/scripts/skill-base.sh` passes syntax validation
- [ ] `grep -c "handoff_artifact_type" .claude/skills/skill-orchestrate/SKILL.md` returns 0
- [ ] `grep -c "skill_link_artifact_from_handoff" .claude/skills/skill-orchestrate/SKILL.md` returns 2
- [ ] `grep -c "skill_link_artifact_from_handoff" .claude/scripts/skill-base.sh` returns 1 (the function definition)
- [ ] No other skill files reference the old inline artifact-type mapping pattern

## Artifacts & Outputs

- `.claude/scripts/skill-base.sh` - Modified (new function added)
- `.claude/skills/skill-orchestrate/SKILL.md` - Modified (two blocks replaced)
- `specs/630_consolidate_orchestrate_postflight/plans/01_consolidate-postflight.md` - This plan

## Rollback/Contingency

Both modified files are tracked by git. If the refactor introduces issues:
1. `git checkout -- .claude/scripts/skill-base.sh .claude/skills/skill-orchestrate/SKILL.md`
2. The original duplicate blocks are functionally correct; rollback restores them identically
