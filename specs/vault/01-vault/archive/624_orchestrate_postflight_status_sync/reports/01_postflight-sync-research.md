# Research Report: Task #624

**Task**: 624 - Fix orchestrate command to properly update task status and regenerate Task Order after each agent dispatch
**Started**: 2026-06-01T00:00:00Z
**Completed**: 2026-06-01T00:10:00Z
**Effort**: 30 minutes
**Dependencies**: Tasks 620, 622, 623 (task-order generation chain)
**Sources/Inputs**: Codebase analysis of skill-orchestrate/SKILL.md, command-gate-out.sh, skill-base.sh, update-task-status.sh, and extension mirrors
**Artifacts**: specs/624_orchestrate_postflight_status_sync/reports/01_postflight-sync-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The orchestrate loop (skill-orchestrate/SKILL.md Stage 5) reads dispatch results from the handoff file but never calls `skill_postflight_update()` or any equivalent — completed tasks are silently left at their old status in state.json and TODO.md Task Order
- `command-gate-out.sh` has two bugs: (1) missing `orchestrate)` case so it falls through to `expected_status=""`, disabling the entire defensive correction; (2) operator precedence on lines 63-64 causes the condition to evaluate as `(A && B) || C || D` instead of `A && (B || C || D)`, allowing spurious corrections from unrelated skill statuses
- The fix requires three coordinated changes: Stage 5 of SKILL.md gets a postflight dispatch call, command-gate-out.sh gets the `orchestrate` case added, and the precedence bug fixed
- Both `.claude/scripts/command-gate-out.sh` and `.claude/extensions/core/scripts/command-gate-out.sh` are byte-for-byte identical and both need the same fix

---

## Context & Scope

The `/orchestrate` command drives a task through its full lifecycle (research → plan → implement → complete) autonomously without user interaction. After each agent dispatch it reads the orchestrator handoff JSON to learn the outcome (Stage 5 of SKILL.md). However it never calls back into the postflight status machinery, meaning:

1. state.json remains stale (still shows "planning" after a successful plan, etc.)
2. TODO.md Task Order is never regenerated, so completed tasks remain in the tree
3. `command-gate-out.sh` (the defensive backup) is also broken for orchestrate because the `orchestrate` operation is not in its case statement

---

## Findings

### File 1: skill-orchestrate/SKILL.md — Stage 5 (lines 311-347)

**Location**: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`, lines 311-347

**Current code** (lines 316-347):

```bash
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
  echo "This may mean orchestrator_mode was not propagated correctly."
  # Increment cycle and continue — state.json may still have been updated
else
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  blockers=$(echo "$handoff" | jq -c '.blockers // []')
  continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
  next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  echo "[orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
  [ "$phases_total" -gt 0 ] && echo "[orchestrate] Phase progress: $phases_completed/$phases_total"

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork)
  if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
    # Use awk for floating-point comparison (bash only does integer math)
    completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
    is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
    if [ "$is_below_threshold" = "yes" ]; then
      echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
      invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
    fi
  fi
fi

# Increment cycle_count
cycle_count=$((cycle_count + 1))
```

**Problem**: After extracting `dispatch_status`, there is no call to update state.json or TODO.md. The `skill_postflight_update()` function (available via `source .claude/scripts/skill-base.sh` in Stage 1) is never invoked here.

**What must be added**: After the drift detection block and before the closing `fi`, add a case statement that maps `dispatch_status` to the correct operation and calls `skill_postflight_update()`. This must happen *inside* the `else` branch (i.e., when the handoff file exists), after all other handoff parsing.

The mapping from handoff `dispatch_status` to operation:
- `researched` → operation `"research"`
- `planned` → operation `"plan"`
- `implemented` → operation `"implement"`

The `skill_postflight_update` signature is:
```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
# where $status is "researched|planned|implemented" (triggers the update)
# and $operation is "research|plan|implement" (passed to update-task-status.sh)
```

**Fix to add** (after the drift detection block, before the closing `fi` of the handoff else branch):

```bash
  # Postflight status update: trigger state.json + TODO.md Task Order regeneration
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      ;;
    *)
      echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac
```

---

### File 2: command-gate-out.sh (lines 56-76)

**Locations** (both are byte-for-byte identical):
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-out.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/command-gate-out.sh`

#### Bug 1: Missing `orchestrate` case (lines 56-61)

**Current code**:
```bash
case "$operation" in
  research)  expected_status="researched" ;;
  plan)      expected_status="planned" ;;
  implement) expected_status="completed" ;;
  *)         expected_status="" ;;
esac
```

When `command-gate-out.sh` is called with `operation="orchestrate"`, it falls through to `*)` setting `expected_status=""`. The `if [ -n "$expected_status" ]` guard on line 63 then short-circuits the entire defensive correction block — no update ever happens.

**Fix**: Add `orchestrate) expected_status="completed" ;;` before the catch-all:

```bash
case "$operation" in
  research)    expected_status="researched" ;;
  plan)        expected_status="planned" ;;
  implement)   expected_status="completed" ;;
  orchestrate) expected_status="completed" ;;
  *)           expected_status="" ;;
esac
```

#### Bug 2: Operator precedence on lines 63-64

**Current code**:
```bash
if [ -n "$expected_status" ] && [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; then
```

**Problem**: Shell `&&` has higher precedence than `||`. This evaluates as:
```
([ -n "$expected_status" ] && [ "$skill_status" = "implemented" ])
||
[ "$skill_status" = "researched" ]
||
[ "$skill_status" = "planned" ]
```

This means: if `skill_status` is `"researched"` or `"planned"` — regardless of whether `expected_status` is set — the entire condition is true. This can cause spurious defensive corrections whenever any skill reports one of those statuses, even when the operation is an unknown type (where `expected_status` is empty and the guard should block everything).

**Intended logic**: The guard should require `expected_status` to be set AND the skill status to be one of the three terminal values.

**Fix**: Wrap the OR conditions in a subshell group:
```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

---

### File 3: skill-base.sh — `skill_postflight_update()` (lines 275-290)

**Location**: `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh`, lines 275-290

**Confirmed interface**:
```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"   # "research" | "plan" | "implement"
  local session_id="$3"
  local status="$4"      # "researched" | "planned" | "implemented" (triggers update)
  case "$status" in
    researched|planned|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"
      ;;
    *)
      echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
      ;;
  esac
  # Extension hook: postflight (runs after status update, non-blocking)
  skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
}
```

This function is sourced into skill-orchestrate via `source .claude/scripts/skill-base.sh` in Stage 1 — confirmed available at Stage 5. No changes needed to this file.

---

### File 4: update-task-status.sh — Phase 3 `update_todo_task_order()` (lines 238-307)

**Location**: `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh`, lines 238-307

**Confirmed Mode B path**: When `TODO_STATUS` is `COMPLETED`, `ABANDONED`, or `EXPANDED`, the function calls `generate-task-order.sh --update-todo "$TODO_FILE" "$STATE_FILE"`. This is exactly the full regeneration needed to prune completed tasks from the Task Order tree.

The `postflight:implement` call path is:
1. `skill_postflight_update("N", "implement", "S", "implemented")`
2. → `update-task-status.sh postflight N implement S`
3. → `map_status("postflight", "implement")` → `STATE_STATUS="completed"`, `TODO_STATUS="COMPLETED"`
4. → `update_todo_task_order()` with `TODO_STATUS=COMPLETED`
5. → Mode B: `generate-task-order.sh --update-todo` → full tree regeneration, task pruned

No changes needed to this file.

---

### File 5: Extension Mirror Files

Both `.claude/scripts/command-gate-out.sh` and `.claude/extensions/core/scripts/command-gate-out.sh` are identical byte-for-byte. **Both files need the same two fixes** (orchestrate case + precedence fix).

The extension copy of `skill-base.sh` is also identical to the main copy and needs no changes (same as above).

---

## Decisions

1. **Add postflight call in Stage 5 of SKILL.md** — inside the `else` branch (handoff file exists), after the drift detection block but before the closing `fi`. This is the primary fix.

2. **Use `skill_postflight_update()` not direct bash call** — this maintains the same code path used by other skills and triggers extension hooks correctly.

3. **Fix both copies of command-gate-out.sh** — the extension mirror is a sync copy and must match the canonical version.

4. **The precedence fix uses `{ ... }` grouping** — this is POSIX-compatible bash grouping syntax that correctly groups OR conditions without spawning a subshell.

5. **`orchestrate` maps to `expected_status="completed"`** — orchestrate always drives a task through to completion; the defensive backup should confirm completed status.

---

## Risks & Mitigations

### Risk 1: Double-update when agent already called update-task-status.sh

**Scenario**: The dispatched skill (e.g., neovim-implementation-agent) calls `skill_postflight_update()` internally, and then orchestrate also calls it — two writes to state.json and TODO.md.

**Mitigation**: `update-task-status.sh` has an **idempotency check** at lines 116-126: if `current_state_status == STATE_STATUS` it exits with code 0 as a no-op. So the second call is harmlessly skipped. The Task Order regeneration (`generate-task-order.sh --update-todo`) is also idempotent.

### Risk 2: `skill_postflight_update` runs on `partial` or `failed` status

**Non-issue**: The case statement in the Stage 5 fix only matches `researched`, `planned`, and `implemented`. Statuses of `partial`, `failed`, or anything else fall through to the `*)` branch which logs and skips.

### Risk 3: Extension hook called with wrong TASK_TYPE/TASK_DIR

**Analysis**: `skill_postflight_update()` uses `${TASK_TYPE:-}` and `${TASK_DIR:-}` which are set in Stage 1 of skill-orchestrate as `$TASK_TYPE` and `$TASK_DIR`. These are available as shell variables throughout the loop. No risk.

### Risk 4: `plan_path` undefined during `researched` dispatch

**Non-issue**: The postflight update call doesn't depend on `plan_path`. The variable is only referenced in drift detection and implementation dispatch.

### Risk 5: Precedence fix changes behavior for valid cases

**Analysis**: The fix tightens the condition — it can only reduce spurious corrections, never suppress valid ones. When `expected_status` is set (for known operations) AND `skill_status` is a success value, the guard passes correctly. This is strictly safer.

---

## Complete Before/After for Each Change

### Change 1: SKILL.md Stage 5 — Add postflight call

**File**: `.claude/skills/skill-orchestrate/SKILL.md`

**Before** (insert after line 342, before the `fi` that closes the `else` branch):
```bash
  fi
fi

# Increment cycle_count
```

**After**:
```bash
  fi

  # Postflight status update: trigger state.json + TODO.md Task Order regeneration
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      ;;
    *)
      echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac
fi

# Increment cycle_count
```

---

### Change 2: command-gate-out.sh — Add orchestrate case + fix precedence

**Files**: 
- `.claude/scripts/command-gate-out.sh`
- `.claude/extensions/core/scripts/command-gate-out.sh`

**Before** (lines 56-64):
```bash
case "$operation" in
  research)  expected_status="researched" ;;
  plan)      expected_status="planned" ;;
  implement) expected_status="completed" ;;
  *)         expected_status="" ;;
esac

if [ -n "$expected_status" ] && [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; then
```

**After** (lines 56-64):
```bash
case "$operation" in
  research)    expected_status="researched" ;;
  plan)        expected_status="planned" ;;
  implement)   expected_status="completed" ;;
  orchestrate) expected_status="completed" ;;
  *)           expected_status="" ;;
esac

if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

---

## Root Cause Summary

Completed tasks from orchestrate runs are not removed from TODO.md Task Order because:

1. **Primary gap**: skill-orchestrate Stage 5 reads `dispatch_status` from the handoff but never calls back into the postflight update chain. State.json and TODO.md are updated only if the dispatched skill itself calls postflight (which some do, some don't), and even then Task Order regeneration only happens if the skill reaches Mode B.

2. **Secondary gap**: `command-gate-out.sh` — the designed defensive backup — doesn't recognize "orchestrate" as a valid operation, so `expected_status=""` disables it entirely.

3. **Compounding bug**: The precedence error on lines 63-64 means the defensive correction could fire incorrectly for unrelated operations while still failing to fire for orchestrate.

---

## Appendix: Files Examined

| File | Lines Read | Status |
|------|-----------|--------|
| `.claude/skills/skill-orchestrate/SKILL.md` | 1-370 | No changes needed except Stage 5 insert |
| `.claude/scripts/command-gate-out.sh` | 1-82 | Fix lines 56-64 |
| `.claude/extensions/core/scripts/command-gate-out.sh` | 1-82 | Mirror — same fix |
| `.claude/scripts/skill-base.sh` | 265-310 | No changes needed |
| `.claude/scripts/update-task-status.sh` | 1-307 | No changes needed |
