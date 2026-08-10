# Research Report: Task #628

**Task**: 628 - Add preflight status updates to skill-orchestrate
**Started**: 2026-06-01T00:00:00Z
**Completed**: 2026-06-01T00:05:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, skill-base.sh, update-task-status.sh, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md)
**Artifacts**: specs/628_add_preflight_to_orchestrate/reports/01_preflight-orchestrate-research.md
**Standards**: report-format.md

## Executive Summary

- `skill-orchestrate` has full postflight coverage (Stage 5 calls `skill_postflight_update()` after each dispatch) but has zero preflight calls before agent dispatches.
- Standalone skills (`skill-researcher`, `skill-planner`, `skill-implementer`) all call `skill_preflight_update()` in their Stage 2 as the very first action after input validation.
- `skill_preflight_update "$task_number" "$operation" "$session_id"` is the exact signature; it delegates to `update-task-status.sh preflight` which atomically updates 4 locations: state.json, TODO.md task entry, TODO.md Task Order section, and the plan file (for implement/plan ops).
- 6 dispatch points in single-task Stage 4 and 3 dispatch loops in multi-task Stage MT-4 are missing preflight calls. Each is documented below with exact code context and the call that must be added.

---

## Context & Scope

The task requires adding `skill_preflight_update()` calls **before** every agent dispatch in `skill-orchestrate`. The skill currently calls `skill_postflight_update()` after each dispatch (Stage 5 for single-task; per-task postflight loop in Stage MT-4), but never calls `skill_preflight_update()` before dispatching.

This creates a status gap: when orchestrate dispatches a research agent, the task stays at `not_started` until the research agent finishes and postflight fires, so users and tooling cannot tell a task is being worked on during the run.

Standalone commands (`/research`, `/plan`, `/implement`) avoid this by calling preflight first, so users see `[RESEARCHING]` immediately when a command starts.

**Files examined**:
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (1146 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` (478 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` (409 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (Stage 2)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (Stage 2)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (Stage 2)

---

## Findings

### Preflight Function Signature and Behavior

**Function**: `skill_preflight_update()` (defined in `skill-base.sh`, line 140)

```bash
# Usage: skill_preflight_update "$task_number" "$operation" "$session_id"
# operation: "research" | "plan" | "implement" | "revise"
skill_preflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  bash .claude/scripts/update-task-status.sh preflight "$task_number" "$operation" "$session_id"
  # Extension hook: preflight (runs after status update)
  skill_run_extension_hook "preflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
}
```

**What it does** (4 atomic updates via `update-task-status.sh`):
1. **state.json** — Sets `.status` to the in-progress variant (`researching`, `planning`, `implementing`)
2. **TODO.md task entry** — Updates `- **Status**: [RESEARCHING]` (or PLANNING/IMPLEMENTING)
3. **TODO.md Task Order section** — In-place sed on the tree line showing `N [RESEARCHING]`
4. **Plan file** — Marks plan as `[IMPLEMENTING]` (for implement ops only) or `[PLANNED]` (plan:postflight)

The full status mapping from `update-task-status.sh` (line 85-100):
```
preflight:research   -> STATE_STATUS="researching",   TODO_STATUS="RESEARCHING"
preflight:plan       -> STATE_STATUS="planning",       TODO_STATUS="PLANNING"
preflight:implement  -> STATE_STATUS="implementing",   TODO_STATUS="IMPLEMENTING"
```

**Idempotency**: The script short-circuits (exit 0) if already at the target status. Safe to call redundantly.

**Prerequisite**: `skill-base.sh` must already be sourced in the same bash block. The orchestrate skill sources it in Stage 0 (line 33: `source .claude/scripts/skill-base.sh`), so calls within the skill body are always valid.

---

### How Standalone Skills Use Preflight (Reference Pattern)

**skill-researcher/SKILL.md** Stage 2 (line 36):
```bash
skill_preflight_update "$task_number" "research" "$session_id"
```
Called immediately after `skill_validate_input`, before any delegation context construction or agent dispatch.

**skill-planner/SKILL.md** Stage 2 (line 36):
```bash
skill_preflight_update "$task_number" "plan" "$session_id"
```

**skill-implementer/SKILL.md** Stage 2 (line 38):
```bash
skill_preflight_update "$task_number" "implement" "$session_id"
```

The pattern is consistent: preflight fires once per operation type, immediately before the agent is dispatched, using the same `session_id` that will be passed to the subagent.

---

### Missing Preflight Points in skill-orchestrate

#### Single-Task Stage 4: State Handlers

There are 6 dispatch points in Stage 4, none of which call `skill_preflight_update`.

**Dispatch 1 — `not_started` / `not started` state (research dispatch)**
- File location: `skill-orchestrate/SKILL.md`, Stage 4, lines ~200-209
- Current code:
  ```
  dispatch_instructions = dispatch_agent "$RESEARCH_AGENT" \
    "Research task $task_number: $DESCRIPTION${focus_prompt:+. User focus: $focus_prompt}" \
    '{"task_number": N, "task_type": "T", "session_id": "S", "orchestrator_mode": false}' \
    "false"
  ```
- Missing preflight call to add **before** this dispatch:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_preflight_update "$task_number" "research" "$session_id"
  ```

**Dispatch 2 — `researched` state (plan dispatch)**
- File location: `skill-orchestrate/SKILL.md`, Stage 4, lines ~222-234
- Current code:
  ```
  dispatch_instructions = dispatch_agent "planner-agent" \
    "Create implementation plan for task $task_number..."
  ```
- Missing preflight call to add **before** this dispatch:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_preflight_update "$task_number" "plan" "$session_id"
  ```

**Dispatch 3 — `planned` / `implementing` state (implement dispatch)**
- File location: `skill-orchestrate/SKILL.md`, Stage 4, lines ~244-261
- Current code:
  ```
  dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
    "Implement task $task_number following the plan..."
  ```
- Missing preflight call to add **before** this dispatch:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_preflight_update "$task_number" "implement" "$session_id"
  ```
  Note: When status is already `implementing`, the preflight is idempotent (status unchanged).

**Dispatch 4 — `partial` state with continuation context (resume implement)**
- File location: `skill-orchestrate/SKILL.md`, Stage 4, lines ~273-284 (sub-state: continuation available)
- Current code:
  ```
  dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
    "Resume implementation for task $task_number from continuation handoff..."
  ```
- Missing preflight call to add **before** this dispatch:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_preflight_update "$task_number" "implement" "$session_id"
  ```

**Dispatch 5 — Stage 6 blocker escalation: re-dispatch implement (Step 5)**
- File location: `skill-orchestrate/SKILL.md`, Stage 6, lines ~553-564
- Current code (inside `blocker_escalation()` function, Step 5):
  ```
  dispatch_agent "$IMPLEMENT_AGENT" \
    "Implement task $task_number following the revised plan..."
  ```
- Missing preflight call to add **before** this dispatch:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_preflight_update "$task_number" "implement" "$session_id"
  ```
  Note: The blocker research fork (Step 2) and reviser-agent dispatch (Step 4) in the blocker escalation function do NOT need preflight calls because they are internal orchestration steps, not lifecycle transitions tracked in state.json.

**Dispatch 6 — Stage 5a drift inspection: reviser-agent dispatch**
- File location: `skill-orchestrate/SKILL.md`, Stage 5a, lines ~479-486
- The drift reviser dispatch triggers `reviser-agent` but this is an internal correction step, NOT a lifecycle transition. Status remains `partial`. No preflight needed here.

**Summary of single-task missing preflight points:**

| Dispatch # | State | Operation | Line range | Missing call |
|------------|-------|-----------|------------|--------------|
| 1 | `not_started` | research | ~200-209 | `skill_preflight_update "$task_number" "research" "$session_id"` |
| 2 | `researched` | plan | ~222-234 | `skill_preflight_update "$task_number" "plan" "$session_id"` |
| 3 | `planned`/`implementing` | implement | ~244-261 | `skill_preflight_update "$task_number" "implement" "$session_id"` |
| 4 | `partial` (continuation) | implement | ~273-284 | `skill_preflight_update "$task_number" "implement" "$session_id"` |
| 5 | Blocker Step 5 | implement | ~553-564 | `skill_preflight_update "$task_number" "implement" "$session_id"` |

---

#### Multi-Task Stage MT-4: Phase-Aware Dispatch Loops

Stage MT-4 has three dispatch loops (research, plan, implement). Each loops through task arrays and dispatches agents. None calls `skill_preflight_update`.

**MT-Dispatch 1 — Research tasks loop (lines ~901-920)**
```bash
# Dispatch research tasks (concurrent, max 4)
for task_num in "${research_tasks[@]}"; do
  # ...constructs dispatch_context...
  # Invoke Agent tool: subagent_type=$r_agent
  echo "[orchestrate-mt] Dispatching research for task $task_num -> $r_agent"
done
```
Missing preflight call to add **inside the loop, before the Agent invocation**:
```bash
skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"
```
Note: The session_id convention in MT mode is `${session_id}_${task_num}` (as used in the dispatch_context at line ~914).

**MT-Dispatch 2 — Plan tasks loop (lines ~922-941)**
```bash
# Dispatch plan tasks (concurrent, max 4)
for task_num in "${plan_tasks[@]}"; do
  # ...constructs dispatch_context...
  # Invoke Agent tool: subagent_type=planner-agent
  echo "[orchestrate-mt] Dispatching planning for task $task_num -> planner-agent"
done
```
Missing preflight call to add **inside the loop, before the Agent invocation**:
```bash
skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"
```

**MT-Dispatch 3 — Implement tasks loop (lines ~943-968)**
```bash
# Dispatch implement tasks (concurrent, max 4)
for task_num in "${implement_tasks[@]}"; do
  # ...constructs dispatch_context...
  # Invoke Agent tool: subagent_type=$i_agent
  echo "[orchestrate-mt] Dispatching implement for task $task_num -> $i_agent"
done
```
Missing preflight call to add **inside the loop, before the Agent invocation**:
```bash
skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"
```

**Summary of multi-task missing preflight points:**

| MT-Dispatch # | Loop type | Operation | Line range | Missing call |
|---------------|-----------|-----------|------------|--------------|
| MT-1 | research_tasks[@] | research | ~901-920 | `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"` |
| MT-2 | plan_tasks[@] | plan | ~922-941 | `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"` |
| MT-3 | implement_tasks[@] | implement | ~943-968 | `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"` |

---

### Postflight Coverage (Already Correct — No Changes Needed)

**Single-task Stage 5** (lines ~369-382): `skill_postflight_update` is called correctly for all three operations after reading the handoff file:
```bash
case "$dispatch_status" in
  researched) skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status" ;;
  planned)    skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status" ;;
  implemented) skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" ;;
esac
```

**Multi-task Stage MT-4** (lines ~990-1006): Same postflight pattern per-task after reading handoffs. Already correct.

---

## Recommendations

### Implementation Approach

Add `skill_preflight_update()` calls at exactly 8 locations in `skill-orchestrate/SKILL.md`:

**Single-task mode (5 locations):**

1. **Before research dispatch** (State: `not_started`):
   Insert just before the `dispatch_instructions = dispatch_agent "$RESEARCH_AGENT"` pseudocode block.
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_number" "research" "$session_id"
   ```

2. **Before plan dispatch** (State: `researched`):
   Insert just before the `dispatch_instructions = dispatch_agent "planner-agent"` pseudocode block.
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_number" "plan" "$session_id"
   ```

3. **Before implement dispatch** (State: `planned`/`implementing`):
   Insert just before the `dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT"` pseudocode block.
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_number" "implement" "$session_id"
   ```

4. **Before resume-implement dispatch** (State: `partial`, continuation available):
   Insert just before the `dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" "Resume implementation..."` pseudocode block.
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_number" "implement" "$session_id"
   ```

5. **Before blocker Step 5 re-implement dispatch** (Stage 6 `blocker_escalation()`, Step 5):
   Insert just before `dispatch_agent "$IMPLEMENT_AGENT" "Implement task $task_number following the revised plan..."`.
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_number" "implement" "$session_id"
   ```

**Multi-task mode (3 locations):**

6. **Research loop** — Add inside `for task_num in "${research_tasks[@]}"` loop:
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"
   ```

7. **Plan loop** — Add inside `for task_num in "${plan_tasks[@]}"` loop:
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"
   ```

8. **Implement loop** — Add inside `for task_num in "${implement_tasks[@]}"` loop:
   ```bash
   source .claude/scripts/skill-base.sh
   skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"
   ```

### Note on `source .claude/scripts/skill-base.sh`

The skill already sources `skill-base.sh` at Stage 0 (line 33). Within the SKILL.md pseudocode convention, bash blocks are illustrative and Claude re-sources as needed. It is safe and conventional to include `source .claude/scripts/skill-base.sh` at the top of each bash block that calls skill-base functions. However, since the skill documents that skill-base is sourced once in Stage 0, the implementation can omit redundant `source` lines and rely on the Stage 0 source — the key change is just adding the `skill_preflight_update` call lines.

### Idempotency Considerations

- The `update-task-status.sh` script checks if already at the target status and exits 0 (no-op) if so. This means calling `skill_preflight_update "$task_number" "implement" ...` when status is already `implementing` (the `implementing` state handler case) is safe and correct.
- For multi-task mode, if a task is already at `planning` or `implementing` (filtered via `current_statuses`), the idempotency check prevents double-updates.

---

## Decisions

- Only lifecycle dispatch points need preflight calls. Internal orchestration dispatches (blocker research fork, drift inspection fork, reviser-agent for drift/blocker) do NOT need preflight because they do not represent lifecycle transitions tracked in state.json.
- The blocker escalation Step 5 (re-dispatch implement) DOES need a preflight call because it resumes a lifecycle phase after a revision cycle; the task may be in `partial` or `blocked` state and needs to transition to `implementing`.
- MT-mode session_id convention: use `${session_id}_${task_num}` (per existing dispatch_context construction at MT-4 line ~914) for consistency with postflight calls.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Preflight fails (state.json corrupt, task not found) | `update-task-status.sh` exits non-zero; orchestrate should treat preflight failure as non-blocking warning (same as postflight pattern) |
| Double-preflight for `implementing` state | Idempotency check in `update-task-status.sh` prevents double-update |
| MT-mode parallel preflight races | Each task has its own entry in state.json; jq updates are per-task and do not race |
| `skill-base.sh` not sourced in blocker_escalation scope | `source .claude/scripts/skill-base.sh` must be present in the bash block containing the blocker_escalation function, which is already the case (Stage 6 pseudocode context) |

---

## Context Extension Recommendations

- None. The existing `skill-base.sh` documentation and `skill-orchestrate/SKILL.md` are sufficient; this is an additive change, not a new pattern.

---

## Appendix

### Files Consulted

- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh`
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh`
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md`

### Key Line Ranges in skill-orchestrate/SKILL.md

| Section | Lines |
|---------|-------|
| Stage 0 (source skill-base.sh) | 31-47 |
| Stage 4: not_started dispatch | ~200-209 |
| Stage 4: researched dispatch | ~222-234 |
| Stage 4: planned/implementing dispatch | ~244-261 |
| Stage 4: partial continuation dispatch | ~273-284 |
| Stage 5: postflight updates (correct) | ~369-382 |
| Stage 6: blocker_escalation Step 5 | ~553-564 |
| Stage MT-4: research loop | ~901-920 |
| Stage MT-4: plan loop | ~922-941 |
| Stage MT-4: implement loop | ~943-968 |
| Stage MT-4: per-task postflight (correct) | ~990-1006 |
