# Implementation Plan: Auto-update plan phase status on implement preflight

- **Task**: 742 - Auto-update plan phase status on implement preflight
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/742_implement_phase_auto_status/reports/01_phase-auto-status-research.md
- **Artifacts**: plans/01_phase-auto-status-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the `update_plan_file()` function in `.claude/scripts/update-task-status.sh` to call the existing but unused `update-phase-status.sh` script during implement preflight. The addition discovers the first `[NOT STARTED]` phase in the plan file and marks it `[IN PROGRESS]`, ensuring phase status is automatically advanced when implementation begins or resumes. This is a narrow, additive change of approximately 20 lines inserted after the existing `update-plan-status.sh` call.

### Research Integration

Research report confirmed:
- Integration point is `update_plan_file()` at lines 198-237 of `update-task-status.sh`
- `update-phase-status.sh` exists and is fully functional but never called by any script
- The call goes after the existing `update-plan-status.sh` invocation (after line 236)
- Phase detection uses `grep -m1` on plan file headings for `[NOT STARTED]`, extracting the phase number via `sed`
- Must support dry-run mode, non-fatal failure, and executable guard (matching existing patterns)
- Option B (discover first NOT STARTED phase) is recommended over hardcoding phase 1, for correct resume behavior

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Automatically mark the first `[NOT STARTED]` phase as `[IN PROGRESS]` during implement preflight
- Support resume scenarios where earlier phases are already completed
- Maintain existing non-fatal, guarded calling pattern
- Respect dry-run mode

**Non-Goals**:
- Modifying `update-phase-status.sh` itself (it already works correctly)
- Handling postflight phase status updates (out of scope for this task)
- Adding phase status updates for non-implement operations

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plan file has no NOT STARTED phases | L | L | Guard: skip call if `$first_phase` is empty |
| Non-standard phase heading format | L | L | Non-fatal guard: `\|\| { echo "Warning..." }` |
| Plan directory not found | L | M | Guard: check `plan_dir` existence before grep |
| Phase number extraction fails | L | L | Fallback to empty string via `\|\| echo ""` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add phase status auto-advance to update_plan_file() [COMPLETED]

**Goal**: Insert the phase status update logic into `update_plan_file()` so that the first NOT STARTED phase is marked IN PROGRESS during implement preflight.

**Tasks**:
- [ ] Add phase auto-advance block after the existing `update-plan-status.sh` call (after line 236, before the closing `}` of `update_plan_file()`)
- [ ] The block must: (a) only run on preflight (`$operation == "preflight"`), (b) check `$phase_script` is executable, (c) handle dry-run mode, (d) resolve the plan directory (padded + unpadded fallback), (e) find the latest plan file, (f) extract the first NOT STARTED phase number via `grep -m1` + `sed`, (g) call `update-phase-status.sh` with the discovered phase number and `IN_PROGRESS` status, (h) wrap in non-fatal guard
- [ ] Verify the script still passes `bash -n` syntax check
- [ ] Test manually with `--dry-run` to confirm dry-run output

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Add ~20 lines inside `update_plan_file()` after the existing plan status call

**Verification**:
- `bash -n .claude/scripts/update-task-status.sh` exits 0 (syntax valid)
- `bash .claude/scripts/update-task-status.sh --dry-run preflight <task_num> implement <session>` shows phase status dry-run message
- Running real preflight on a task with a plan file marks the first NOT STARTED phase as [IN PROGRESS]

---

## Testing & Validation

- [ ] `bash -n .claude/scripts/update-task-status.sh` passes (no syntax errors)
- [ ] Dry-run mode shows phase status update message without modifying files
- [ ] Real preflight on a planned task marks first NOT STARTED phase [IN PROGRESS]
- [ ] Running on a task with no plan file produces no error (silent skip)
- [ ] Running on a task where all phases are completed produces no error (silent skip)
- [ ] Resume scenario: task with Phase 1 COMPLETED, Phase 2 NOT STARTED correctly advances Phase 2

## Artifacts & Outputs

- `.claude/scripts/update-task-status.sh` (modified)
- specs/742_implement_phase_auto_status/plans/01_phase-auto-status-plan.md (this plan)
- specs/742_implement_phase_auto_status/summaries/01_phase-auto-status-summary.md (after implementation)

## Rollback/Contingency

Remove the added block (lines after the existing `update-plan-status.sh` call, before the closing `}` of `update_plan_file()`). The change is purely additive and isolated within one function, so removal restores the prior behavior exactly.
