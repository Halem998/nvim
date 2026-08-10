# Research Report: Task #249

**Task**: 249 - fix_skill_todo_vault_stage_numbering
**Started**: 2026-03-19T00:00:00Z
**Completed**: 2026-03-19T00:30:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**:
- Codebase analysis of skill-todo SKILL.md
- Comparison with skill-implementer, skill-planner, skill-refresh
- Transition pattern analysis across all skills
**Artifacts**:
- specs/249_fix_skill_todo_vault_stage_numbering/reports/01_vault-stage-numbering.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root Cause Confirmed**: Stage 10 (ArchiveTasks) lacks an explicit exit directive to Stage 10.5 (DetectVaultThreshold), causing the model to skip directly to Stage 11
- **Pattern Comparison**: All other skills use contiguous integer stage IDs (1, 2, 3, ...) with implicit sequential flow
- **Recommended Fix**: Renumber vault stages 10.5-10.9 to proper integers (11-15) and shift existing stages 11-16 to 16-21
- **Secondary Fix**: Add explicit transition instructions at end of Stage 10 (now Stage 10)

## Context & Scope

The task is to fix vault detection stages in skill-todo SKILL.md being skipped by the model. The root cause is that fractional stage IDs (10.5-10.9) lack transition directives from Stage 10, so the model jumps directly from Stage 10 to Stage 11 (UpdateRoadmap), completely bypassing the vault operation workflow.

### Current Stage Structure

| Current ID | Stage Name | Problem |
|------------|------------|---------|
| 10 | ArchiveTasks | No exit directive pointing to 10.5 |
| 10.5 | DetectVaultThreshold | Fractional ID, unreachable |
| 10.6 | VaultConfirmation | Fractional ID, unreachable |
| 10.7 | CreateVault | Fractional ID, unreachable |
| 10.8 | RenumberTasks | Fractional ID, unreachable |
| 10.9 | ResetState | Fractional ID, unreachable |
| 11 | UpdateRoadmap | Model jumps here from Stage 10 |
| 12 | UpdateREADME | - |
| 13 | UpdateChangelog | - |
| 14 | CreateMemories | - |
| 15 | GitCommit | - |
| 16 | OutputResults | - |

## Findings

### 1. Codebase Patterns

**Stage Numbering Convention**: All other skills use contiguous integer stage IDs:
- `skill-implementer`: Stages 1-11 (integers only)
- `skill-planner`: Stages 1-11 (integers only)
- `skill-refresh`: Uses Steps (Step 1-5), not XML stage elements

**Transition Pattern**: Skills rely on implicit sequential flow between integer stages. When a stage completes, the model naturally proceeds to the next integer stage (Stage N -> Stage N+1).

**Fractional IDs are Non-Standard**: The 10.5-10.9 pattern is unique to skill-todo and violates the implicit sequential assumption. The model has no instruction to look for fractional stage IDs after completing Stage 10.

### 2. Stage 10 Exit Analysis

Current Stage 10 ending (lines 354-356):
```xml
        e. If no directory found, log warning:
           ```
           Warning: TODO.md orphan {N} has no directory in specs/
           Archive entry created but no files moved
           ```
    </process>
  </stage>
```

**Critical Missing Element**: No `<transition>` or exit comment indicating where to proceed next. The `</stage>` tag closes, and the model sees Stage 11 (UpdateRoadmap) as the next sequential stage.

### 3. Fractional Stage Internal Transitions

The fractional stages DO contain internal transition directives (good):
- Stage 10.5 line 413: "Continue to Stage 10.6 if vault_needed=true"
- Stage 10.6 line 452: "Continue to Stage 10.7"
- Stage 10.6 line 455: "Skip to Stage 11 (UpdateRoadmap)"
- Stage 10.7 line 537: "Continue to Stage 10.8"
- Stage 10.8 line 646: "Continue to Stage 10.9"
- Stage 10.9 line 719: "Continue to Stage 11"

**However**, these are unreachable because Stage 10 never directs execution to Stage 10.5 in the first place.

### 4. Root Cause Diagnosis

The failure mode is:
1. Model executes Stage 10 (ArchiveTasks) completely
2. Model looks for next stage - sees Stage 11 (UpdateRoadmap) as next integer
3. Model skips 10.5, 10.6, 10.7, 10.8, 10.9 entirely
4. Vault detection, confirmation, creation, renumbering, and state reset never execute

### 5. Comparison with Working Skills

`skill-implementer` Stage 10 -> Stage 11 transition (lines 366-376):
```
### Stage 10: Cleanup

Remove marker and metadata files:
...

---

### Stage 11: Return Brief Summary
```

The `---` separator and `### Stage 11:` header establish clear sequential flow. No fractional stages exist to cause confusion.

## Recommendations

### Primary Fix: Renumber Stages to Integers

Renumber the vault stages (10.5-10.9) to proper integer IDs (11-15), then shift the remaining stages (11-16) up by 5 to become (16-21).

**New Stage Structure**:

| New ID | Old ID | Stage Name |
|--------|--------|------------|
| 10 | 10 | ArchiveTasks |
| 11 | 10.5 | DetectVaultThreshold |
| 12 | 10.6 | VaultConfirmation |
| 13 | 10.7 | CreateVault |
| 14 | 10.8 | RenumberTasks |
| 15 | 10.9 | ResetState |
| 16 | 11 | UpdateRoadmap |
| 17 | 12 | UpdateREADME |
| 18 | 13 | UpdateChangelog |
| 19 | 14 | CreateMemories |
| 20 | 15 | GitCommit |
| 21 | 16 | OutputResults |

### Secondary Fix: Add Stage 10 Exit Directive

At the end of Stage 10's `<process>` block (after step 8e), add:

```xml
      9. Continue to Stage 11 (DetectVaultThreshold) to check if vault operation is needed.
    </process>
  </stage>
```

This explicit transition directive ensures the model follows the vault detection flow.

### Update Internal Transition References

All internal transition references need to be updated:
- "Continue to Stage 10.6" -> "Continue to Stage 12"
- "Continue to Stage 10.7" -> "Continue to Stage 13"
- "Continue to Stage 10.8" -> "Continue to Stage 14"
- "Continue to Stage 10.9" -> "Continue to Stage 15"
- "Continue to Stage 11" -> "Continue to Stage 16" (in vault stages)
- "Skip to Stage 11 (UpdateRoadmap)" -> "Skip to Stage 16 (UpdateRoadmap)"

## Implementation Approach

### Phase 1: Renumber Stage IDs

1. Change `<stage id="10.5"` to `<stage id="11"`
2. Change `<stage id="10.6"` to `<stage id="12"`
3. Change `<stage id="10.7"` to `<stage id="13"`
4. Change `<stage id="10.8"` to `<stage id="14"`
5. Change `<stage id="10.9"` to `<stage id="15"`
6. Change `<stage id="11"` to `<stage id="16"`
7. Change `<stage id="12"` to `<stage id="17"`
8. Change `<stage id="13"` to `<stage id="18"`
9. Change `<stage id="14"` to `<stage id="19"`
10. Change `<stage id="15"` to `<stage id="20"`
11. Change `<stage id="16"` to `<stage id="21"`

### Phase 2: Add Transition Directive to Stage 10

Insert at end of Stage 10 process block:

```xml
      9. **TRANSITION**: After archiving tasks, continue to Stage 11 (DetectVaultThreshold)
         to determine if vault operation is needed based on next_project_number threshold.
```

### Phase 3: Update Internal References

Search and replace all "Continue to Stage 10.X" and "Skip to Stage 11" references to use new integer IDs.

### Phase 4: Verification

1. Verify all stage IDs are contiguous integers (10, 11, 12, ..., 21)
2. Verify all internal transition references point to valid stage IDs
3. Test /todo command execution with next_project_number > 1000

## Decisions

1. **Renumbering over adding transition only**: Simply adding a transition directive at Stage 10 would work, but fractional stage IDs remain non-standard and may cause confusion in future maintenance. Full renumbering is the cleaner solution.

2. **Explicit transition directive in Stage 10**: Even with integer IDs, adding an explicit transition comment improves clarity and documents the branching logic (vault stages may skip to Stage 16 if vault not needed).

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Reference update missed | Grep for all "Stage 10." and "Stage 11" references to ensure complete coverage |
| Vault logic broken by renumbering | Test with mock next_project_number > 1000 scenario |
| Skip-to-Stage-11 logic outdated | Ensure all "Skip to Stage 11" become "Skip to Stage 16" |

## Appendix

### Search Queries Used

1. `stage id="10\.5|10\.6|10\.7|10\.8|10\.9"` - Found fractional stage definitions
2. `Continue to Stage|Skip to Stage` - Found internal transition directives
3. Stage structure comparison across skill-implementer, skill-planner, skill-refresh

### Key Code Locations

- skill-todo SKILL.md lines 281-356: Stage 10 (ArchiveTasks) - missing exit directive
- skill-todo SKILL.md lines 358-720: Stages 10.5-10.9 (vault operations)
- skill-todo SKILL.md lines 723-859: Stages 11-16 (post-archive operations)
