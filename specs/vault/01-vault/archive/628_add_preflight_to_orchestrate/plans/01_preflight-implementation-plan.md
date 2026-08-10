# Implementation Plan: Add Preflight Status Updates to skill-orchestrate

- **Task**: 628 - Add preflight status updates to skill-orchestrate
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/628_add_preflight_to_orchestrate/reports/01_preflight-orchestrate-research.md
- **Artifacts**: plans/01_preflight-implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

skill-orchestrate currently has full postflight coverage but zero preflight calls before agent dispatches. This creates a status gap where tasks remain in their prior status (e.g., `not_started`) during active work, making it impossible for users or tooling to detect that a task is being worked on. This plan adds `skill_preflight_update()` calls at exactly 8 dispatch points (5 single-task, 3 multi-task) to match the pattern used by standalone skills (`skill-researcher`, `skill-planner`, `skill-implementer`).

### Research Integration

The research report identified:
- 5 missing preflight call points in single-task mode (Stage 4 state handlers + Stage 6 blocker escalation Step 5)
- 3 missing preflight call points in multi-task mode (Stage MT-4 dispatch loops)
- The exact `skill_preflight_update` signature: `skill_preflight_update "$task_number" "$operation" "$session_id"`
- Confirmed that `skill-base.sh` is already sourced at Stage 0 (line 33)
- Confirmed idempotency: `update-task-status.sh` short-circuits if already at target status
- Confirmed that internal dispatches (blocker research fork, drift inspection fork, reviser-agent) should NOT have preflight calls

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `skill_preflight_update()` calls before all 5 lifecycle dispatch points in single-task mode
- Add `skill_preflight_update()` calls before all 3 lifecycle dispatch loops in multi-task mode
- Ensure status transitions match standalone skill behavior (task immediately shows `[RESEARCHING]`/`[PLANNING]`/`[IMPLEMENTING]`)
- Maintain idempotency safety for states that are already in-progress

**Non-Goals**:
- Modifying `skill-base.sh` or `update-task-status.sh` (reference only, no changes needed)
- Adding preflight to internal orchestration dispatches (blocker research fork, drift inspection fork, reviser-agent)
- Adding postflight calls (already correct and complete)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Preflight fails on corrupt state.json | L | L | `update-task-status.sh` exits non-zero; orchestrate treats as non-blocking warning (same pattern as postflight) |
| Double-preflight for `implementing` state | L | M | Idempotency check in `update-task-status.sh` prevents double-update; safe to call redundantly |
| MT-mode parallel preflight races | M | L | Each task has its own entry in state.json; jq updates are per-task and do not race |
| Misplacement of preflight call after dispatch instead of before | H | L | Verification phase explicitly audits placement order |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2      | 1          |
| 3    | 3      | 1, 2       |

Phases within the same wave can execute in parallel.

### Phase 1: Add Preflight Calls to Single-Task State Handlers [COMPLETED]

**Goal**: Add `skill_preflight_update` before all 5 lifecycle dispatch points in single-task mode (Stages 4 and 6).

**Tasks**:
- [x] Add preflight before `not_started` research dispatch (Stage 4, ~line 200) *(completed)*
  - Insert `skill_preflight_update "$task_number" "research" "$session_id"` in a bash block immediately before the `dispatch_instructions = dispatch_agent "$RESEARCH_AGENT"` pseudocode
- [x] Add preflight before `researched` plan dispatch (Stage 4, ~line 228) *(completed)*
  - Insert `skill_preflight_update "$task_number" "plan" "$session_id"` immediately before the `dispatch_instructions = dispatch_agent "planner-agent"` pseudocode
- [x] Add preflight before `planned`/`implementing` implement dispatch (Stage 4, ~line 251) *(completed)*
  - Insert `skill_preflight_update "$task_number" "implement" "$session_id"` immediately before the `dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT"` pseudocode
- [x] Add preflight before `partial` continuation implement dispatch (Stage 4, ~line 278) *(completed)*
  - Insert `skill_preflight_update "$task_number" "implement" "$session_id"` immediately before the continuation `dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT"` pseudocode
- [x] Add preflight before blocker escalation Step 5 re-implement dispatch (Stage 6, ~line 562) *(completed)*
  - Insert `skill_preflight_update "$task_number" "implement" "$session_id"` immediately before `dispatch_agent "$IMPLEMENT_AGENT"` in `blocker_escalation()` Step 5

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add 5 preflight calls in Stages 4 and 6

**Edit patterns** (old_string -> new_string for each insertion):

**1. `not_started` research dispatch** (~line 200):
```
OLD:
```
dispatch_instructions = dispatch_agent "$RESEARCH_AGENT" \

NEW:
```bash
# Preflight: mark task as RESEARCHING before dispatch
skill_preflight_update "$task_number" "research" "$session_id"
```

```
dispatch_instructions = dispatch_agent "$RESEARCH_AGENT" \
```

**2. `researched` plan dispatch** (~line 228):
```
OLD:
dispatch_instructions = dispatch_agent "planner-agent" \

NEW:
```bash
# Preflight: mark task as PLANNING before dispatch
skill_preflight_update "$task_number" "plan" "$session_id"
```

dispatch_instructions = dispatch_agent "planner-agent" \
```

**3. `planned`/`implementing` implement dispatch** (~line 251):
```
OLD:
dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Implement task $task_number following the plan

NEW:
```bash
# Preflight: mark task as IMPLEMENTING before dispatch
skill_preflight_update "$task_number" "implement" "$session_id"
```

dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Implement task $task_number following the plan
```

**4. `partial` continuation dispatch** (~line 278):
```
OLD:
dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Resume implementation for task $task_number from continuation handoff

NEW:
```bash
# Preflight: mark task as IMPLEMENTING before resume dispatch
skill_preflight_update "$task_number" "implement" "$session_id"
```

dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Resume implementation for task $task_number from continuation handoff
```

**5. Blocker escalation Step 5** (~line 562):
```
OLD:
  dispatch_agent "$IMPLEMENT_AGENT" \
    "Implement task $task_number following the revised plan

NEW:
  # Preflight: mark task as IMPLEMENTING before re-dispatch
  skill_preflight_update "$task_number" "implement" "$session_id"

  dispatch_agent "$IMPLEMENT_AGENT" \
    "Implement task $task_number following the revised plan
```

**Verification**:
- Count exactly 5 occurrences of `skill_preflight_update` added in single-task mode sections (Stages 4 and 6)
- Confirm no `skill_preflight_update` appears inside `invoke_drift_inspection()` function
- Confirm no `skill_preflight_update` appears before blocker research fork (Step 2) or reviser-agent dispatch (Step 4)
- Confirm each preflight call appears BEFORE its corresponding dispatch, not after

---

### Phase 2: Add Preflight Calls to Multi-Task Dispatch Loops [COMPLETED]

**Goal**: Add `skill_preflight_update` inside each of the 3 dispatch loops in Stage MT-4, using the MT session_id convention `${session_id}_${task_num}`.

**Tasks**:
- [x] Add preflight inside research_tasks dispatch loop (Stage MT-4, ~line 902) *(completed)*
  - Insert `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"` inside the `for task_num in "${research_tasks[@]}"` loop, before the Agent tool invocation comment
- [x] Add preflight inside plan_tasks dispatch loop (Stage MT-4, ~line 923) *(completed)*
  - Insert `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"` inside the `for task_num in "${plan_tasks[@]}"` loop, before the Agent tool invocation comment
- [x] Add preflight inside implement_tasks dispatch loop (Stage MT-4, ~line 944) *(completed)*
  - Insert `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"` inside the `for task_num in "${implement_tasks[@]}"` loop, before the Agent tool invocation comment

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add 3 preflight calls in Stage MT-4

**Edit patterns**:

**1. Research loop** (~line 917):
```
OLD:
  # Invoke Agent tool: subagent_type=$r_agent
  # Dispatch: dispatch_agent "$r_agent" "Research task $task_num: $description" "$dispatch_context" "false"
  echo "[orchestrate-mt] Dispatching research for task $task_num -> $r_agent"

NEW:
  # Preflight: mark task as RESEARCHING before dispatch
  skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"

  # Invoke Agent tool: subagent_type=$r_agent
  # Dispatch: dispatch_agent "$r_agent" "Research task $task_num: $description" "$dispatch_context" "false"
  echo "[orchestrate-mt] Dispatching research for task $task_num -> $r_agent"
```

**2. Plan loop** (~line 939):
```
OLD:
  # Invoke Agent tool: subagent_type=planner-agent
  echo "[orchestrate-mt] Dispatching planning for task $task_num -> planner-agent"

NEW:
  # Preflight: mark task as PLANNING before dispatch
  skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"

  # Invoke Agent tool: subagent_type=planner-agent
  echo "[orchestrate-mt] Dispatching planning for task $task_num -> planner-agent"
```

**3. Implement loop** (~line 967):
```
OLD:
  # Invoke Agent tool: subagent_type=$i_agent
  echo "[orchestrate-mt] Dispatching implement for task $task_num -> $i_agent"

NEW:
  # Preflight: mark task as IMPLEMENTING before dispatch
  skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"

  # Invoke Agent tool: subagent_type=$i_agent
  echo "[orchestrate-mt] Dispatching implement for task $task_num -> $i_agent"
```

**Verification**:
- Count exactly 3 occurrences of `skill_preflight_update` added in multi-task sections (Stage MT-4)
- Confirm each call uses `"${session_id}_${task_num}"` (not bare `$session_id`)
- Confirm each call uses `$task_num` (not `$task_number`)
- Confirm each preflight appears inside the dispatch loop, before the Agent tool invocation

---

### Phase 3: Verification and Audit [COMPLETED]

**Goal**: Verify all dispatch points have matching preflight/postflight pairs and no internal dispatches received preflight calls.

**Tasks**:
- [x] Count total `skill_preflight_update` calls in SKILL.md: must be exactly 8 *(completed: count=8)*
- [x] Count total `skill_postflight_update` calls in SKILL.md: must remain unchanged (existing count) *(completed: count=6, unchanged)*
- [x] Verify preflight/postflight pairing for each lifecycle operation: *(completed)*
  - Research: 2 preflight (1 single-task + 1 MT) / postflight in Stage 5 + MT postflight loop
  - Plan: 2 preflight (1 single-task + 1 MT) / postflight in Stage 5 + MT postflight loop
  - Implement: 4 preflight (3 single-task + 1 MT) / postflight in Stage 5 + MT postflight loop
- [x] Verify NO preflight in `invoke_drift_inspection()` function (Stage 5a) *(completed: verified clean)*
- [x] Verify NO preflight before blocker research fork (Stage 6, Step 2, `dispatch_agent ""`) *(completed: verified clean)*
- [x] Verify NO preflight before reviser-agent dispatches (Stage 5a drift revision + Stage 6 Step 4) *(completed: verified clean)*
- [x] Verify the file still has correct markdown structure (no broken code fences or headings) *(completed)*

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- `grep -c 'skill_preflight_update' .claude/skills/skill-orchestrate/SKILL.md` returns 8
- `grep -c 'skill_postflight_update' .claude/skills/skill-orchestrate/SKILL.md` returns same count as before changes
- No `skill_preflight_update` appears between `invoke_drift_inspection()` function start and end
- No `skill_preflight_update` appears between `# Step 2: RESEARCH FORK` and `# Step 3: READ FINDINGS`
- No `skill_preflight_update` appears between `# Step 4: REVISE PLAN` and `# Step 5: RE-DISPATCH`

## Testing & Validation

- [x] Grep count: exactly 8 `skill_preflight_update` calls in SKILL.md *(completed: count=8)*
- [x] Grep count: `skill_postflight_update` count unchanged from baseline *(completed: count=6)*
- [x] All 5 single-task preflight calls appear BEFORE their corresponding `dispatch_agent` / `dispatch_instructions` *(completed)*
- [x] All 3 multi-task preflight calls appear BEFORE the `# Invoke Agent tool` comment in each loop *(completed)*
- [x] No preflight calls in `invoke_drift_inspection()`, blocker research fork, or reviser-agent dispatches *(completed)*
- [x] SKILL.md markdown structure is valid (no broken fences, headings, or indentation) *(completed)*

## Artifacts & Outputs

- `specs/628_add_preflight_to_orchestrate/plans/01_preflight-implementation-plan.md` (this plan)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified file with 8 new preflight calls)

## Rollback/Contingency

Revert the single modified file using git:
```bash
git checkout -- .claude/skills/skill-orchestrate/SKILL.md
```
The change is purely additive (no existing lines modified or removed), so partial rollback is also safe -- individual preflight calls can be removed independently.
