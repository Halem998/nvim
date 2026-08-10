# Implementation Plan: Fix plan status update script arguments

- **Task**: 245 - Fix plan status update script arguments in skill-implementer
- **Status**: [COMPLETED]
- **Effort**: 30 minutes
- **Dependencies**: None
- **Research Inputs**: [01_meta-research.md](../reports/01_meta-research.md)
- **Artifacts**: plans/01_fix-script-args.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Fix argument mismatch between `update-plan-status.sh` script (expects 3 arguments: `TASK_NUMBER PROJECT_NAME STATUS`) and skill-implementer calls (incorrectly passing 4 arguments including extraneous `$padded_num`). This bug causes plan file status to not be updated when tasks complete because the script receives wrong positional arguments.

### Research Integration

Research report 01_meta-research.md confirmed:
- Script signature: `update-plan-status.sh TASK_NUMBER PROJECT_NAME STATUS`
- 3 incorrect invocations in skill-implementer/SKILL.md at lines 93, 264, 291
- 3 incorrect invocations in skill-grant/SKILL.md at lines 177, 396, 398
- skill-neovim-implementation/SKILL.md already uses correct 3-argument pattern

## Goals & Non-Goals

**Goals**:
- Remove `$padded_num` from all `update-plan-status.sh` invocations
- Ensure plan file Status field updates correctly during /implement workflow
- Fix both core skill (skill-implementer) and extension skill (skill-grant)

**Non-Goals**:
- Changing the script signature (already correct)
- Modifying any other skills (skill-neovim-implementation already correct)
- Adding new functionality to the status update script

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed invocation | Plan status not updated | Low | Grep search confirmed all locations |
| Line numbers changed | Edit fails | Low | Use exact string matching, not line numbers |

## Implementation Phases

### Phase 1: Fix skill-implementer/SKILL.md [COMPLETED]

**Goal**: Remove extraneous `$padded_num` argument from all 3 script invocations in skill-implementer.

**Tasks**:
- [ ] Edit line 93: Change `"$task_number" "$padded_num" "$project_name" "IMPLEMENTING"` to `"$task_number" "$project_name" "IMPLEMENTING"`
- [ ] Edit line 264: Change `"$task_number" "$padded_num" "$project_name" "COMPLETED"` to `"$task_number" "$project_name" "COMPLETED"`
- [ ] Edit line 291: Change `"$task_number" "$padded_num" "$project_name" "PARTIAL"` to `"$task_number" "$project_name" "PARTIAL"`
- [ ] Verify no other incorrect invocations exist in skill-implementer

**Timing**: 10 minutes

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Remove `$padded_num` from 3 locations

**Verification**:
- Grep confirms no remaining `$padded_num` in `update-plan-status.sh` calls in skill-implementer

---

### Phase 2: Fix skill-grant extension [COMPLETED]

**Goal**: Remove extraneous `$padded_num` argument from all 3 script invocations in skill-grant extension.

**Tasks**:
- [ ] Edit line 177: Change `"$task_number" "$padded_num" "$project_name" "IMPLEMENTING"` to `"$task_number" "$project_name" "IMPLEMENTING"`
- [ ] Edit line 396: Change `"$task_number" "$padded_num" "$project_name" "COMPLETED"` to `"$task_number" "$project_name" "COMPLETED"`
- [ ] Edit line 398: Change `"$task_number" "$padded_num" "$project_name" "PARTIAL"` to `"$task_number" "$project_name" "PARTIAL"`
- [ ] Verify no other incorrect invocations exist in extension skills

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Remove `$padded_num` from 3 locations

**Verification**:
- Grep confirms no remaining incorrect patterns across all extension skills

---

## Testing & Validation

- [ ] `grep -r 'update-plan-status.sh.*\$padded_num' .claude/` returns no results
- [ ] All `update-plan-status.sh` calls pass exactly 3 arguments
- [ ] Syntax verification: skill files contain valid bash code blocks

## Artifacts & Outputs

- plans/01_fix-script-args.md (this file)
- summaries/01_fix-script-args-summary.md (on completion)

## Rollback/Contingency

Changes are isolated to skill definition files. If issues arise:
1. Revert to previous git commit
2. Re-add `$padded_num` argument (though this would restore the bug)

No external dependencies or state changes - rollback is straightforward via git.
