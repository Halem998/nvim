# Implementation Plan: Task #643 -- Eliminate Dual Postflight

- **Task**: 643 - Eliminate dual postflight ownership
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task 642 (fix orchestrator_mode propagation -- completed)
- **Research Inputs**: specs/643_eliminate_dual_postflight/reports/01_eliminate-dual-postflight.md
- **Artifacts**: plans/01_eliminate-dual-postflight.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

When `orchestrator_mode=true`, both the skill and the orchestrator independently call `update-task-status.sh postflight` for the same task, causing double notifications (TTS, WezTerm) even though the idempotency check prevents state corruption. The fix adds an optional 5th `orchestrator_mode` parameter to `skill_postflight_update()` in `skill-base.sh`. When `"true"`, the function skips the `update-task-status.sh` call but still runs the extension hook. The three core skill files are updated to pass `$orchestrator_mode` at the call site.

### Research Integration

The research report confirmed the dual-write path in all three core skills (researcher, planner, implementer) and identified Option A (centralized guard in `skill-base.sh` with 5th parameter) as the preferred approach. Extension skills (neovim, nix) are deferred -- they lack orchestrator_mode awareness entirely and need a separate task. The reviser is not affected (always dispatched with `orchestrator_mode=false`).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Eliminate redundant `update-task-status.sh postflight` call when orchestrator_mode=true
- Preserve extension hook execution regardless of orchestrator_mode
- Maintain backward compatibility for callers that do not pass the 5th parameter

**Non-Goals**:
- Adding orchestrator_mode support to extension skills (neovim, nix) -- separate task
- Modifying the orchestrator's own postflight in skill-orchestrate/SKILL.md
- Changing the idempotency check in update-task-status.sh

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension hook stops running when guard is active | H | L | Guard explicitly calls `skill_run_extension_hook` before returning |
| Existing callers break from signature change | M | L | 5th parameter defaults to "false" -- fully backward compatible |
| Team skills affected unintentionally | M | L | Team skills do not pass orchestrator_mode; default "false" keeps their behavior unchanged |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add orchestrator_mode guard to skill-base.sh [COMPLETED]

**Goal**: Modify `skill_postflight_update()` to accept an optional 5th `orchestrator_mode` parameter and skip the `update-task-status.sh` call when it is `"true"`, while preserving the extension hook.

**Tasks**:
- [ ] In `.claude/scripts/skill-base.sh`, update the function comment (line 272) to document the 5th parameter
- [ ] Add `local orchestrator_mode="${5:-false}"` after the existing parameter declarations (after line 279)
- [ ] Add guard block: if `orchestrator_mode=true`, log a message, call `skill_run_extension_hook`, and return 0 -- before the `case` statement
- [ ] Verify the extension hook call in the guard uses the same arguments as the existing call at line 289

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/skill-base.sh` -- Add 5th parameter and guard block to `skill_postflight_update`

**Verification**:
- `grep -n 'orchestrator_mode' .claude/scripts/skill-base.sh` shows the new parameter and guard
- Function signature comment includes the 5th parameter
- Extension hook call is present in both the guard branch and the normal branch

---

### Phase 2: Update call sites in three core skills [COMPLETED]

**Goal**: Pass `"$orchestrator_mode"` as the 5th argument to `skill_postflight_update` in the researcher, planner, and implementer skill files.

**Tasks**:
- [ ] In `.claude/skills/skill-researcher/SKILL.md` Stage 7 Step 1 (line 149), append `"$orchestrator_mode"` to the `skill_postflight_update` call
- [ ] In `.claude/skills/skill-planner/SKILL.md` Stage 7 Step 1 (line 148), append `"$orchestrator_mode"` to the `skill_postflight_update` call
- [ ] In `.claude/skills/skill-implementer/SKILL.md` Stage 7 Step 1 (line 209), append `"$orchestrator_mode"` to the `skill_postflight_update` call
- [ ] Verify no other `skill_postflight_update` calls in these three files need updating

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` -- Add 5th arg to Stage 7 call
- `.claude/skills/skill-planner/SKILL.md` -- Add 5th arg to Stage 7 call
- `.claude/skills/skill-implementer/SKILL.md` -- Add 5th arg to Stage 7 call

**Verification**:
- `grep 'skill_postflight_update' .claude/skills/skill-researcher/SKILL.md` shows `"$orchestrator_mode"` as 5th arg
- `grep 'skill_postflight_update' .claude/skills/skill-planner/SKILL.md` shows `"$orchestrator_mode"` as 5th arg
- `grep 'skill_postflight_update' .claude/skills/skill-implementer/SKILL.md` shows `"$orchestrator_mode"` as 5th arg

## Testing & Validation

- [ ] Run `bash -n .claude/scripts/skill-base.sh` -- syntax check passes
- [ ] Verify `grep -c 'skill_run_extension_hook' .claude/scripts/skill-base.sh` returns at least 2 (guard branch + normal branch within `skill_postflight_update`, plus other functions)
- [ ] Verify backward compatibility: callers without 5th arg (team skills) still work because parameter defaults to "false"
- [ ] Run `/orchestrate` on a test task and confirm single notification per phase transition (manual end-to-end test)

## Artifacts & Outputs

- `specs/643_eliminate_dual_postflight/plans/01_eliminate-dual-postflight.md` (this plan)
- `specs/643_eliminate_dual_postflight/summaries/01_eliminate-dual-postflight-summary.md` (after implementation)

## Rollback/Contingency

Revert the 4 file changes. The 5th parameter is purely additive and backward-compatible, so removal returns to the pre-fix dual-write behavior without side effects. Git revert of the implementation commit is sufficient.
