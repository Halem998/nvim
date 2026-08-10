# Implementation Plan: Fix orchestrate postflight status sync and Task Order regeneration

- **Task**: 624 - Fix orchestrate postflight status sync and Task Order regeneration
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/624_orchestrate_postflight_status_sync/reports/01_postflight-sync-research.md
- **Artifacts**: plans/01_postflight-sync-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/orchestrate` command's Stage 5 handoff reading block extracts `dispatch_status` but never calls `skill_postflight_update()`, leaving state.json and TODO.md Task Order stale after each agent dispatch. The defensive backup in `command-gate-out.sh` also fails because it lacks an `orchestrate` case and has an operator precedence bug. This plan addresses all three issues across two files (plus the extension mirror copy).

### Research Integration

Research confirmed three coordinated fixes needed: (1) add `skill_postflight_update()` call in SKILL.md Stage 5 after the drift detection block; (2) add `orchestrate)` case to `command-gate-out.sh`; (3) fix `&&`/`||` operator precedence on lines 63-64. The `skill_postflight_update()` function is already sourced via `skill-base.sh` in Stage 1 and has an idempotency guard, so double-updates are safe.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- State.json and TODO.md Task Order are updated after each successful orchestrate dispatch
- The defensive backup in `command-gate-out.sh` correctly handles `orchestrate` operations
- Operator precedence in the conditional guard is fixed to prevent spurious corrections

**Non-Goals**:
- Changing the orchestrate state machine logic or loop structure
- Modifying `skill-base.sh` or `update-task-status.sh` (both confirmed correct)
- Adding new orchestrate features or changing dispatch behavior

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Double-update when dispatched skill also calls postflight | L | M | `update-task-status.sh` has idempotency check (lines 116-126): exits no-op if current status matches target |
| Extension mirror drifts from canonical copy | M | L | Phase 2 applies identical edits to both files; verify byte-for-byte match post-edit |
| Precedence fix changes behavior for valid operations | M | L | Fix only tightens the condition -- requires `expected_status` to be set before OR conditions evaluate |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add postflight status update call in SKILL.md Stage 5 [COMPLETED]

**Goal**: After reading the orchestrator handoff, call `skill_postflight_update()` to trigger state.json and TODO.md Task Order regeneration for successful dispatches.

**Tasks**:
- [x] Edit `.claude/skills/skill-orchestrate/SKILL.md` to insert a postflight case statement after the drift detection block and before the closing `fi` of the handoff `else` branch *(completed)*

**File**: `.claude/skills/skill-orchestrate/SKILL.md`

**Location**: Lines 342-343 (between the drift detection closing `fi` and the handoff branch closing `fi`)

**Before** (lines 342-345):
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

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Insert postflight call in Stage 5 handoff else branch

**Verification**:
- The case statement is inside the `else` branch (only runs when handoff file exists)
- `skill_postflight_update` is called with correct 4-arg signature: `task_number`, `operation`, `session_id`, `dispatch_status`
- Only `researched`, `planned`, `implemented` trigger updates; other statuses log and skip
- The `fi` that closes the handoff branch comes after the new case statement

---

### Phase 2: Fix command-gate-out.sh (orchestrate case + operator precedence) [COMPLETED]

**Goal**: Add `orchestrate` to the operation case statement and fix the `&&`/`||` operator precedence bug in the defensive correction guard. Apply to both canonical and extension mirror copies.

**Tasks**:
- [x] Edit `.claude/scripts/command-gate-out.sh` to add `orchestrate)` case and fix precedence *(completed)*
- [x] Edit `.claude/extensions/core/scripts/command-gate-out.sh` with identical changes *(completed)*

**File 1**: `.claude/scripts/command-gate-out.sh`
**File 2**: `.claude/extensions/core/scripts/command-gate-out.sh`

**Location**: Lines 56-64 in both files

**Change A -- Add orchestrate case** (lines 56-61):

Before:
```bash
case "$operation" in
  research)  expected_status="researched" ;;
  plan)      expected_status="planned" ;;
  implement) expected_status="completed" ;;
  *)         expected_status="" ;;
esac
```

After:
```bash
case "$operation" in
  research)    expected_status="researched" ;;
  plan)        expected_status="planned" ;;
  implement)   expected_status="completed" ;;
  orchestrate) expected_status="completed" ;;
  *)           expected_status="" ;;
esac
```

**Change B -- Fix operator precedence** (lines 63-64):

Before:
```bash
if [ -n "$expected_status" ] && [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; then
```

After:
```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/command-gate-out.sh` - Add orchestrate case (line 59) and fix precedence (lines 63-64)
- `.claude/extensions/core/scripts/command-gate-out.sh` - Identical changes (mirror copy)

**Verification**:
- `orchestrate` maps to `expected_status="completed"`
- The `{ ... }` grouping ensures the guard requires `expected_status` to be non-empty before any OR branch is evaluated
- Both files are byte-for-byte identical after edits (diff to confirm)

## Testing & Validation

- [ ] Run `bash -n .claude/scripts/command-gate-out.sh` to verify no syntax errors
- [ ] Run `bash -n .claude/extensions/core/scripts/command-gate-out.sh` to verify no syntax errors
- [ ] Verify both command-gate-out.sh files are identical: `diff .claude/scripts/command-gate-out.sh .claude/extensions/core/scripts/command-gate-out.sh`
- [ ] Confirm SKILL.md has the postflight case statement inside the correct `else` branch by inspecting surrounding context
- [ ] Grep for `skill_postflight_update` in SKILL.md to confirm it appears in Stage 5

## Artifacts & Outputs

- `specs/624_orchestrate_postflight_status_sync/plans/01_postflight-sync-plan.md` (this plan)
- Modified: `.claude/skills/skill-orchestrate/SKILL.md`
- Modified: `.claude/scripts/command-gate-out.sh`
- Modified: `.claude/extensions/core/scripts/command-gate-out.sh`

## Rollback/Contingency

All changes are additive insertions or minimal edits to existing lines. Revert via `git checkout` of the three modified files if any issues arise. The idempotency guard in `update-task-status.sh` ensures that even if the postflight call fires unexpectedly, it produces a no-op when the status is already correct.
