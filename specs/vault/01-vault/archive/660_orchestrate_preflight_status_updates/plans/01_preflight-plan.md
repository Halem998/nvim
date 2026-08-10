# Implementation Plan: Add Preflight Status Updates to skill-orchestrate

- **Task**: 660 - Add preflight status updates to skill-orchestrate state handlers
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/660_orchestrate_preflight_status_updates/reports/01_preflight-analysis.md
- **Artifacts**: plans/01_preflight-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

skill-orchestrate dispatches research, plan, and implement agents without calling `update-task-status.sh preflight` beforehand. This means tasks remain at their prior status (e.g., `not_started`) during active execution, plan files never transition to `[IMPLEMENTING]`, and the `workflow-active` marker is never written during orchestrated runs. The fix inserts one preflight call before each dispatch in both single-task Stage 4 (4 insertion points) and multi-task Stage MT-4 (3 insertion points). All calls use the non-blocking `|| echo WARNING` pattern since orchestrate should not abort on a TODO.md update failure.

### Research Integration

Research report `01_preflight-analysis.md` confirmed:
- 4 insertion points in single-task Stage 4 (`not_started`, `researched`, `planned|implementing`, `partial` with continuation)
- 3 insertion points in multi-task Stage MT-4 (research loop, plan loop, implement loop)
- `update-task-status.sh` has built-in idempotency (exits 0 if already at target status) so no double-preflight risk
- `update-plan-status.sh` is called internally by `update-task-status.sh preflight implement` -- no separate invocation needed
- The `workflow-active` marker is also written by preflight, fixing the Stop hook suppression gap as a side effect

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Tasks show correct in-progress status (`researching`, `planning`, `implementing`) during orchestrated runs
- Plan files show `[IMPLEMENTING]` during orchestrated implementation
- The `workflow-active` marker is written during orchestrated runs
- Both single-task and multi-task modes have consistent preflight behavior

**Non-Goals**:
- Changing the blocking vs. non-blocking behavior of preflight in individual skills
- Modifying `update-task-status.sh` or `update-plan-status.sh` scripts
- Adding preflight calls to blocker escalation or drift inspection dispatches (those are internal recovery mechanisms, not primary lifecycle transitions)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Preflight call fails and logs warning during orchestrate | L | M | Non-blocking pattern (`\|\| echo WARNING`) ensures orchestrate continues; warning is visible in logs |
| Idempotency edge case on partial/continuation resume | L | L | `update-task-status.sh` exits 0 if already at target status -- safe no-op |
| MT-4 sequential preflight adds latency before parallel dispatch | L | L | Preflight is fast (~50ms per call: jq read + sed update); negligible for batch sizes up to 4 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Add preflight calls to single-task Stage 4 handlers [COMPLETED]

**Goal**: Insert `update-task-status.sh preflight` calls before each dispatch in Stage 4 state handlers.

**Tasks**:
- [ ] Add `preflight research` call in the `not_started` / `not started` state handler, immediately before the `dispatch_instructions = dispatch_agent "$RESEARCH_AGENT"` block
- [ ] Add `preflight plan` call in the `researched` state handler, immediately before the `dispatch_instructions = dispatch_agent "planner-agent"` block
- [ ] Add `preflight implement` call in the `planned` or `implementing` state handler, immediately before the `dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT"` block
- [ ] Add `preflight implement` call in the `partial` sub-state (continuation available), immediately before the `dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT"` block for continuation

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage 4 state handlers (lines ~196-298)

**Insertion template** (adapt target per handler):
```bash
# Preflight: update status before dispatch
bash .claude/scripts/update-task-status.sh preflight "$task_number" <target> "$session_id" || \
  echo "[orchestrate] WARNING: preflight <target> update failed (non-blocking)"
```

Where `<target>` is `research`, `plan`, or `implement` depending on the handler.

**Verification**:
- Each of the 4 state handlers (`not_started`, `researched`, `planned|implementing`, `partial` continuation) contains exactly one preflight call before its dispatch
- All preflight calls use the `|| echo "[orchestrate] WARNING:..."` non-blocking pattern
- No preflight calls added to `researching`, `planning`, `blocked`, `completed`, `abandoned`, `expanded`, or unknown state handlers

---

### Phase 2: Add preflight calls to multi-task Stage MT-4 dispatch loops [COMPLETED]

**Goal**: Insert `update-task-status.sh preflight` calls before each dispatch in the MT-4 research, plan, and implement loops.

**Tasks**:
- [ ] Add `preflight research` call inside the research dispatch loop (`for task_num in "${research_tasks[@]}"`), before the `echo "[orchestrate-mt] Dispatching research"` line
- [ ] Add `preflight plan` call inside the plan dispatch loop (`for task_num in "${plan_tasks[@]}"`), before the `echo "[orchestrate-mt] Dispatching planning"` line
- [ ] Add `preflight implement` call inside the implement dispatch loop (`for task_num in "${implement_tasks[@]}"`), before the `echo "[orchestrate-mt] Dispatching implement"` line

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage MT-4 dispatch loops (lines ~901-969)

**Insertion template** (adapt per loop):
```bash
# Preflight: update status before dispatch
bash .claude/scripts/update-task-status.sh preflight "$task_num" <target> "${session_id}_${task_num}" || \
  echo "[orchestrate-mt] WARNING: preflight <target> failed for task $task_num (non-blocking)"
```

Key differences from single-task:
- Uses `$task_num` (not `$task_number`) as the loop variable
- Uses `${session_id}_${task_num}` as the per-task session ID (matches existing dispatch context pattern)
- Log prefix is `[orchestrate-mt]` (not `[orchestrate]`)

**Verification**:
- Each of the 3 dispatch loops contains exactly one preflight call before its dispatch echo/invocation
- Session ID format matches the per-task pattern used in dispatch_context
- All calls use non-blocking `|| echo` pattern

---

### Phase 3: End-to-end verification [COMPLETED]

**Goal**: Verify the complete set of changes is correct and consistent.

**Tasks**:
- [ ] Read the modified SKILL.md and verify all 7 preflight insertion points are present
- [ ] Verify no preflight calls were added to recovery/escalation dispatches (blocker escalation Step 2 research fork, Step 4 reviser-agent, Step 5 re-dispatch implement; drift inspection fork; drift revision reviser-agent)
- [ ] Verify the preflight call in `planned|implementing` handler uses `implement` as the target (not `plan`)
- [ ] Verify the preflight call in `partial` continuation handler uses `implement` as the target
- [ ] Verify MT-4 session IDs use `${session_id}_${task_num}` format consistently
- [ ] Confirm `update-task-status.sh` idempotency handles all edge cases: `not_started -> researching` (normal), `researching -> researching` (no-op), `implementing -> implementing` (no-op for partial resume)

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- Count of preflight calls in Stage 4: exactly 4
- Count of preflight calls in Stage MT-4: exactly 3
- No preflight calls in Stage 6 (blocker escalation) or Stage 5a (drift inspection)
- All 7 calls use non-blocking pattern

## Testing & Validation

- [ ] Count total preflight insertion points in SKILL.md: expect exactly 7 (4 in Stage 4 + 3 in MT-4)
- [ ] Verify each preflight call uses correct target: `research` for not_started, `plan` for researched, `implement` for planned/implementing/partial
- [ ] Verify non-blocking pattern on all 7 calls (no bare `bash .claude/scripts/update-task-status.sh` without `||` fallback)
- [ ] Verify no changes to `update-task-status.sh` or `update-plan-status.sh`
- [ ] Verify recovery dispatches (blocker escalation, drift inspection) remain unchanged

## Artifacts & Outputs

- `.claude/skills/skill-orchestrate/SKILL.md` - Modified with 7 preflight call insertions
- `specs/660_orchestrate_preflight_status_updates/plans/01_preflight-plan.md` - This plan file

## Rollback/Contingency

Revert the single file change with `git checkout -- .claude/skills/skill-orchestrate/SKILL.md`. The preflight calls are purely additive and do not modify any existing logic; removing them restores the previous behavior with no side effects.
