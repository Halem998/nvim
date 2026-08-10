# Research Report: Task #643

**Task**: 643 - eliminate_dual_postflight
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:15:00Z
**Effort**: 30 minutes
**Dependencies**: Task 642 (fix orchestrator_mode propagation — completed)
**Sources/Inputs**: Codebase — skill-base.sh, skill-orchestrate/SKILL.md, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md, skill-neovim-research/SKILL.md, skill-neovim-implementation/SKILL.md, skill-nix-research/SKILL.md, skill-nix-implementation/SKILL.md, update-task-status.sh
**Artifacts**: specs/643_eliminate_dual_postflight/reports/01_eliminate-dual-postflight.md
**Standards**: report-format.md

---

## Executive Summary

- The dual postflight write occurs in three core skills (skill-researcher, skill-planner, skill-implementer): each calls `skill_postflight_update` unconditionally AND writes the orchestrator handoff, while the orchestrator reads that handoff and immediately calls `update-task-status.sh postflight` a second time for the same task and operation.
- The fix is a single-point guard in `skill-base.sh::skill_postflight_update`: when `orchestrator_mode=true`, skip the `update-task-status.sh postflight` call. Extension skills (neovim, nix) call the script directly and need the guard added inline.
- The `skill_write_orchestrator_handoff` call must remain unconditional (it already has its own `orchestrator_mode` guard and is what the orchestrator depends on).

---

## Context & Scope

Task 642 fixed `orchestrator_mode=true` to be propagated on all three phases (research, plan, implement), not just implement. This means before the task 643 fix, the dual postflight problem now fires on every `/orchestrate` invocation — three times per task lifecycle (once per phase).

The question being answered: exactly which code paths execute `update-task-status.sh postflight` twice for the same task?

---

## Findings

### Current Dual-Write Flow (Step by Step)

For the **research phase** (skill-researcher invoked with orchestrator_mode=true):

1. **Orchestrator preflight** (skill-orchestrate Stage 4 `not_started` handler):
   ```bash
   bash .claude/scripts/update-task-status.sh preflight "$task_number" "research" "$session_id"
   ```
   State: `researching`

2. **skill-researcher Stage 7** (postflight loop, called after subagent returns):
   ```bash
   skill_postflight_update "$task_number" "research" "$session_id" "$SUBAGENT_STATUS"
   # internally calls: bash .claude/scripts/update-task-status.sh postflight ... "research" ...
   ```
   State: `researched` — **FIRST postflight write**

3. **skill-researcher Stage 7** (continues):
   ```bash
   skill_write_orchestrator_handoff "$orchestrator_mode" ... "research" "researched" ... "plan"
   # writes .orchestrator-handoff.json with status="researched"
   ```

4. **Orchestrator Stage 5** (reads handoff after Agent tool returns):
   ```bash
   dispatch_status = "researched"
   bash .claude/scripts/update-task-status.sh postflight "$task_number" "research" "$session_id"
   ```
   State: would set `researched` again — **SECOND postflight write (redundant)**

The same pattern repeats for plan phase (`planned`) and implement phase (`completed`).

Note: The `update-task-status.sh` script has an **idempotency check** (line 122-128) that exits 0 if the status is already at the target. This means the second write does not corrupt state, but it still fires the TTS and WezTerm notification hooks (Phase 5, lines 416-428) redundantly, causing double notifications for each phase transition.

### Code Locations Involved

#### skill-base.sh: `skill_postflight_update` (lines 275-290)

```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  case "$status" in
    researched|planned|revised|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"
      ;;
    *)
      echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
      ;;
  esac
  # Extension hook: postflight (runs after status update, non-blocking)
  skill_run_extension_hook "postflight" ...
}
```

This function is called by: skill-researcher Stage 7, skill-planner Stage 7, skill-implementer Stage 7, skill-team-research, skill-team-plan, skill-team-implement.

#### skill-orchestrate SKILL.md: Stage 5 Handoff Reading (lines 388-401)

```bash
case "$dispatch_status" in
  researched)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "research" "$session_id"
    ;;
  planned)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "plan" "$session_id"
    ;;
  implemented)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "implement" "$session_id"
    ;;
```

This is the orchestrator's intended authoritative postflight. It also fires in the multi-task mode (Stage MT-4, lines 1019-1029) identically.

#### Extension Skills (direct script calls, no `skill_postflight_update`):

- **skill-neovim-research Stage 7** (line 171): `bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"`
- **skill-neovim-implementation Stage 7** (line 204): `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"`
- **skill-nix-research Stage 7** (line 171): `bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"`
- **skill-nix-implementation Stage 7** (line 234): `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"`

These four extension skills do NOT extract `orchestrator_mode` at all — they have no orchestrator awareness. They also do NOT call `skill_write_orchestrator_handoff`. This means:
- They DO have the dual-postflight problem IF the orchestrator were to dispatch them (neovim tasks, nix tasks).
- They do NOT write the handoff JSON, so the orchestrator would fail for these task types (no handoff to read). This is a related but separate issue.

#### skill-reviser Stage 7 (line 300):

```bash
bash .claude/scripts/update-task-status.sh postflight $task_number revise $session_id
```

The reviser is never dispatched with `orchestrator_mode=true` in the current codebase — all reviser calls in skill-orchestrate pass `orchestrator_mode: false`. So reviser is NOT affected by this task.

#### Team Skills (skill-team-research, skill-team-plan, skill-team-implement):

These call `skill_postflight_update` but have no orchestrator_mode awareness and are never dispatched by skill-orchestrate with `orchestrator_mode=true`. Not affected.

---

### Skills That Need the Guard

**Priority 1 — Core skills (have full orchestrator_mode support, just need the guard):**

| Skill | Guard location | Current call |
|-------|----------------|--------------|
| skill-researcher | Stage 7, Step 1 | `skill_postflight_update "$task_number" "research" "$session_id" "$SUBAGENT_STATUS"` |
| skill-planner | Stage 7, Step 1 | `skill_postflight_update "$task_number" "plan" "$session_id" "$SUBAGENT_STATUS"` |
| skill-implementer | Stage 7, Step 1 | `skill_postflight_update "$task_number" "implement" "$session_id" "$SUBAGENT_STATUS"` |

These all route through `skill_postflight_update` in `skill-base.sh`. A single change to `skill-base.sh` could guard all three — IF `orchestrator_mode` were passed as a parameter to `skill_postflight_update`. However, `orchestrator_mode` is a local variable in each skill, not a parameter to `skill_postflight_update`. Two implementation options:

**Option A (centralized fix in skill-base.sh):** Add an `orchestrator_mode` parameter to `skill_postflight_update`:
```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  local orchestrator_mode="${5:-false}"  # NEW PARAMETER
  if [ "$orchestrator_mode" = "true" ]; then
    echo "[skill-base] orchestrator_mode=true — skipping postflight (orchestrator owns status transitions)"
    skill_run_extension_hook "postflight" ...
    return 0
  fi
  ...
}
```
Then each skill call becomes:
```bash
skill_postflight_update "$task_number" "research" "$session_id" "$SUBAGENT_STATUS" "$orchestrator_mode"
```

**Option B (inline guard in each skill):** Wrap the call in each skill:
```bash
if [ "$orchestrator_mode" != "true" ]; then
  skill_postflight_update "$task_number" "research" "$session_id" "$SUBAGENT_STATUS"
fi
```

Option A is cleaner (single file change for centralized behavior) but changes the function signature. Option B requires three skill file changes but is explicit and readable.

**Priority 2 — Extension skills (no orchestrator_mode awareness, need both guard AND handoff writing):**

| Skill | Guard location | Missing capability |
|-------|----------------|-------------------|
| skill-neovim-research | Stage 7 | No orchestrator_mode extraction, no handoff write |
| skill-neovim-implementation | Stage 7 | No orchestrator_mode extraction, no handoff write |
| skill-nix-research | Stage 7 | No orchestrator_mode extraction, no handoff write |
| skill-nix-implementation | Stage 7 | No orchestrator_mode extraction, no handoff write |

These skills need THREE changes each: (1) extract orchestrator_mode in Stage 4, (2) guard the postflight call, (3) add `skill_write_orchestrator_handoff` call. This is a larger change but required for correct orchestration of neovim/nix tasks.

However, based on the task description, the immediate fix is for the core three skills. The extension skills can be addressed in a follow-on task if needed.

---

### Proposed Guard Pattern

**Recommended: Option A — single `skill-base.sh` change + 3 skill call site updates.**

In `skill-base.sh`, modify `skill_postflight_update` to accept an optional 5th parameter:

```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  local orchestrator_mode="${5:-false}"

  # Guard: when orchestrator_mode=true, skip own postflight — orchestrator owns status transitions
  if [ "$orchestrator_mode" = "true" ]; then
    echo "[skill-base] orchestrator_mode=true — skill_postflight_update skipped (orchestrator drives status)"
    skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
    return 0
  fi

  case "$status" in
    researched|planned|revised|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"
      ;;
    *)
      echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
      ;;
  esac
  skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
}
```

In each of the three core skills, add `"$orchestrator_mode"` as the 5th argument:

**skill-researcher Stage 7:**
```bash
skill_postflight_update "$task_number" "research" "$session_id" "$SUBAGENT_STATUS" "$orchestrator_mode"
```

**skill-planner Stage 7:**
```bash
skill_postflight_update "$task_number" "plan" "$session_id" "$SUBAGENT_STATUS" "$orchestrator_mode"
```

**skill-implementer Stage 7 (implemented branch):**
```bash
skill_postflight_update "$task_number" "implement" "$session_id" "$SUBAGENT_STATUS" "$orchestrator_mode"
```

Note: The partial branch in skill-implementer does NOT call `skill_postflight_update` (it does its own state.json update inline). That path does not need the guard — and correctly so, because partial status is not a transition that `update-task-status.sh postflight implement` would cover anyway.

---

## Decisions

- **Option A chosen over Option B**: Centralizing the guard in `skill-base.sh` is preferred because it establishes a single source of truth for the orchestrator_mode contract. Adding a 5th parameter to `skill_postflight_update` is backward-compatible (it defaults to "false"), so existing callers (team skills, standalone use) are unaffected.
- **Extension skills deferred**: The neovim and nix extension skills have a deeper problem (no orchestrator awareness at all). They will need a separate task to add full orchestrator_mode support (guard + handoff write). This task is scoped to the three core skills only.
- **Reviser not in scope**: The reviser is always dispatched with `orchestrator_mode=false` by the orchestrator, so no guard is needed.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| The orchestrator's postflight fires but the skill's extension hook (via `skill_run_extension_hook`) does not | Low | The guard in Option A preserves the extension hook call even when postflight is skipped |
| Notification double-firing (TTS, WezTerm) | Medium | This is the primary symptom being fixed; the idempotency check in `update-task-status.sh` prevents state corruption but not double notifications |
| Backward compatibility of `skill_postflight_update` signature change | Low | 5th parameter defaults to "false" — all existing callers that don't pass it remain unaffected |
| Extension skills still have dual-write problem for neovim/nix tasks | Medium | This is a known gap; document in follow-on task. For now, extension tasks dispatched via `/orchestrate` will get double notifications but not state corruption (idempotency check) |
| The fix must be consistent between single-task and multi-task (MT-4) orchestrate modes | Medium | Both use the same skill dispatch mechanism, so fixing the skill is sufficient — no changes needed in the orchestrator |

---

## Context Extension Recommendations

- **Topic**: Dual-ownership postflight contracts between skills and orchestrator
- **Gap**: No documented rule for which entity owns status transitions when orchestrator_mode=true. The existing comment in skill-base.sh (lines 102-106) mentions orchestrator_mode support but does not define the ownership boundary.
- **Recommendation**: Add a note to `.claude/context/architecture/orchestrate-state-machine.md` (or create a dedicated context file) clarifying: "When orchestrator_mode=true, the orchestrator exclusively owns status transitions in state.json and TODO.md. Skills MUST skip their own `skill_postflight_update` call and only write the handoff JSON."

---

## Appendix

### Files Modified by Fix

1. `.claude/scripts/skill-base.sh` — Add 5th parameter to `skill_postflight_update`
2. `.claude/skills/skill-researcher/SKILL.md` — Add `"$orchestrator_mode"` to Stage 7 call
3. `.claude/skills/skill-planner/SKILL.md` — Add `"$orchestrator_mode"` to Stage 7 call
4. `.claude/skills/skill-implementer/SKILL.md` — Add `"$orchestrator_mode"` to Stage 7 call

### Files NOT Modified (in-scope rationale)

- `skill-orchestrate/SKILL.md` — The orchestrator's postflight in Stage 5 is the authoritative owner; no change needed
- `skill-neovim-research/SKILL.md`, `skill-neovim-implementation/SKILL.md` — Need separate orchestrator_mode onboarding task
- `skill-nix-research/SKILL.md`, `skill-nix-implementation/SKILL.md` — Same as neovim
- `skill-reviser/SKILL.md` — Not dispatched with orchestrator_mode=true
- `skill-team-*.SKILL.md` — Not dispatched by orchestrator
- `update-task-status.sh` — The idempotency check is a good safety net; no change needed

### Exact Line References

- `skill-base.sh::skill_postflight_update`: lines 275-290
- `skill-researcher::Stage 7 Step 1`: lines 149
- `skill-planner::Stage 7 Step 1`: line 148
- `skill-implementer::Stage 7 Step 1 (implemented branch)`: line 209
- `skill-orchestrate::Stage 5 postflight case`: lines 388-401
- `skill-orchestrate::Stage MT-4 postflight case`: lines 1019-1029
