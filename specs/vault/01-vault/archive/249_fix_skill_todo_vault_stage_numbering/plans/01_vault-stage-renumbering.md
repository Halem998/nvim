# Implementation Plan: Fix skill-todo Vault Stage Numbering

- **Task**: 249 - fix_skill_todo_vault_stage_numbering
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [01_vault-stage-numbering.md](../reports/01_vault-stage-numbering.md)
- **Artifacts**: plans/01_vault-stage-renumbering.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix vault detection stages in skill-todo being skipped by the model due to fractional stage IDs (10.5-10.9) lacking transition directives from Stage 10. The model follows implicit sequential flow between integer stages, causing it to jump from Stage 10 (ArchiveTasks) directly to Stage 11 (UpdateRoadmap), bypassing vault detection, confirmation, creation, renumbering, and state reset entirely.

The fix involves renumbering vault stages 10.5-10.9 to proper integers 11-15, shifting existing stages 11-16 to 16-21, adding an explicit transition directive at Stage 10, and updating all internal stage references.

### Research Integration

Research report analyzed the stage structure and confirmed:
- Stage 10 (ArchiveTasks) has no exit directive pointing to Stage 10.5
- All other skills use contiguous integer stage IDs with implicit sequential flow
- Internal transitions within vault stages (10.5 -> 10.6 -> ... -> 10.9) are correctly defined but unreachable
- The fix requires both renumbering AND adding explicit transition at Stage 10

## Goals & Non-Goals

**Goals**:
- Renumber vault stages from fractional IDs (10.5-10.9) to integers (11-15)
- Shift post-vault stages (11-16) to new IDs (16-21)
- Add explicit transition directive at end of Stage 10
- Update all internal transition references to use new stage numbers
- Ensure contiguous integer stage numbering throughout skill-todo

**Non-Goals**:
- Modifying vault operation logic (detection, confirmation, creation, renumbering, reset)
- Changing other skills' stage numbering
- Refactoring vault stages beyond renumbering

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed reference update | Stage transitions break | Medium | Grep for all "Stage 10." and "Stage 11" patterns |
| Skip-to-stage logic outdated | Vault bypass still occurs | Medium | Verify "Skip to Stage 11" becomes "Skip to Stage 16" |
| Stage ID regex mismatch | XML parser fails | Low | Test with `grep 'stage id="'` after changes |

## Implementation Phases

### Phase 1: Renumber Vault Stages [COMPLETED]

**Goal**: Convert fractional vault stage IDs (10.5-10.9) to integers (11-15)

**Tasks**:
- [ ] Change `<stage id="10.5"` to `<stage id="11"` (DetectVaultThreshold)
- [ ] Change `<stage id="10.6"` to `<stage id="12"` (VaultConfirmation)
- [ ] Change `<stage id="10.7"` to `<stage id="13"` (CreateVault)
- [ ] Change `<stage id="10.8"` to `<stage id="14"` (RenumberTasks)
- [ ] Change `<stage id="10.9"` to `<stage id="15"` (ResetState)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage ID attributes

**Verification**:
- Grep confirms no remaining `id="10.5"` through `id="10.9"` patterns
- Grep confirms `id="11"` through `id="15"` exist

---

### Phase 2: Shift Post-Vault Stages [COMPLETED]

**Goal**: Renumber existing stages 11-16 to 16-21 to make room for vault stages

**Tasks**:
- [ ] Change `<stage id="11"` to `<stage id="16"` (UpdateRoadmap)
- [ ] Change `<stage id="12"` to `<stage id="17"` (UpdateREADME)
- [ ] Change `<stage id="13"` to `<stage id="18"` (UpdateChangelog)
- [ ] Change `<stage id="14"` to `<stage id="19"` (CreateMemories)
- [ ] Change `<stage id="15"` to `<stage id="20"` (GitCommit)
- [ ] Change `<stage id="16"` to `<stage id="21"` (OutputResults)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage ID attributes

**Verification**:
- Grep confirms `id="16"` through `id="21"` exist
- Grep confirms no duplicate stage IDs
- Total of 21 stages exist (1-21)

---

### Phase 3: Add Stage 10 Transition Directive [COMPLETED]

**Goal**: Add explicit transition at end of Stage 10 pointing to Stage 11 (DetectVaultThreshold)

**Tasks**:
- [ ] Locate end of Stage 10 process block (after step 8e, before `</process>`)
- [ ] Insert step 9 with explicit transition instruction:
  ```
  9. **TRANSITION**: After archiving tasks, continue to Stage 11 (DetectVaultThreshold)
     to determine if vault operation is needed based on next_project_number threshold.
  ```

**Timing**: 10 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Stage 10 process block

**Verification**:
- Stage 10 now ends with explicit transition to Stage 11
- The transition references DetectVaultThreshold by name

---

### Phase 4: Update Internal Transition References [COMPLETED]

**Goal**: Update all "Continue to Stage X" and "Skip to Stage X" references to use new stage numbers

**Tasks**:
- [ ] Update "Continue to Stage 10.6" to "Continue to Stage 12" (in Stage 11)
- [ ] Update "Continue to Stage 10.7" to "Continue to Stage 13" (in Stage 12)
- [ ] Update "Continue to Stage 10.8" to "Continue to Stage 14" (in Stage 13)
- [ ] Update "Continue to Stage 10.9" to "Continue to Stage 15" (in Stage 14)
- [ ] Update all "Continue to Stage 11" references (in vault stages) to "Continue to Stage 16"
- [ ] Update "Skip to Stage 11 (UpdateRoadmap)" to "Skip to Stage 16 (UpdateRoadmap)" (in Stage 12)
- [ ] Update any remaining "Stage 11" references in vault stage content to "Stage 16"

**Timing**: 20 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Transition references in stages 11-15

**Verification**:
- Grep for "Stage 10." returns no matches
- Grep for "Stage 11" returns only references in Stages 1-10 and 16+ (not vault stages)
- All vault stages (11-15) reference Stage 16 as their terminal transition

---

### Phase 5: Verification and Testing [COMPLETED]

**Goal**: Verify all changes are consistent and no broken references remain

**Tasks**:
- [ ] Grep for `stage id="` and verify contiguous integers 1-21
- [ ] Grep for "Continue to Stage" and verify all references point to valid stage IDs
- [ ] Grep for "Skip to Stage" and verify all references point to valid stage IDs
- [ ] Verify no remaining fractional stage references (10.5, 10.6, 10.7, 10.8, 10.9)
- [ ] Read through Stage 10 -> Stage 11 -> Stage 12 flow to verify logical transition
- [ ] Verify Stage 12 (VaultConfirmation) skip logic goes to Stage 16 (UpdateRoadmap)
- [ ] Verify Stage 15 (ResetState) continues to Stage 16 (UpdateRoadmap)

**Timing**: 20 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- All stage IDs are contiguous integers 1-21
- All transition references are valid
- Vault workflow flow is logically correct: 10 -> 11 -> 12 -> 13 -> 14 -> 15 -> 16
- Skip path is correct: 10 -> 11 (vault not needed) -> 16

---

## Testing & Validation

- [ ] `grep -E 'stage id="[0-9]+"' .claude/skills/skill-todo/SKILL.md` returns stages 1-21
- [ ] `grep -E 'stage id="10\.[0-9]"' .claude/skills/skill-todo/SKILL.md` returns no matches
- [ ] `grep "Continue to Stage" .claude/skills/skill-todo/SKILL.md` shows only valid integer references
- [ ] `grep "Skip to Stage" .claude/skills/skill-todo/SKILL.md` shows only valid integer references
- [ ] Manual review confirms Stage 10 ends with transition to Stage 11
- [ ] Manual review confirms Stage 12 (VaultConfirmation) skip goes to Stage 16

## Artifacts & Outputs

- `.claude/skills/skill-todo/SKILL.md` - Updated skill with renumbered stages
- `specs/249_fix_skill_todo_vault_stage_numbering/plans/01_vault-stage-renumbering.md` - This plan
- `specs/249_fix_skill_todo_vault_stage_numbering/summaries/02_vault-stage-renumbering-summary.md` - Implementation summary

## Rollback/Contingency

If implementation causes issues:
1. Revert `.claude/skills/skill-todo/SKILL.md` using git: `git checkout HEAD -- .claude/skills/skill-todo/SKILL.md`
2. The original fractional stage structure will be restored
3. Consider alternative fix: adding only the transition directive without renumbering (less clean but functional)
