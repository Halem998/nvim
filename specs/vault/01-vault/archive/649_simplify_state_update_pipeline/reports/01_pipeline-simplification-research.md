# Research Report: Task #649

**Task**: 649 - Simplify state update pipeline to state.json-only with TODO.md regeneration
**Started**: 2026-06-10T23:00:00Z
**Completed**: 2026-06-10T23:15:00Z
**Effort**: ~2 hours implementation
**Dependencies**: Task 648 (generate-todo.sh — completed)
**Sources/Inputs**: Codebase analysis of all pipeline scripts
**Artifacts**: specs/649_simplify_state_update_pipeline/reports/01_pipeline-simplification-research.md
**Standards**: report-format.md

---

## Executive Summary

- `update-task-status.sh` has 5 phases: Phase 1 (state.json update) and Phase 4 (plan file status) stay; Phases 2 and 3 (TODO.md awk/sed surgery) are replaced with a single `generate-todo.sh` call
- `postflight-workflow.sh` already only touches state.json; the TODO.md surgery was never in it — no changes needed there beyond wiring generate-todo.sh
- `skill_link_artifacts` in `skill-base.sh` does two things: (1) state.json artifact array updates (keep) and (2) calls `link-artifact-todo.sh` (remove — generate-todo.sh renders artifacts)
- `link-artifact-todo.sh` has two callers: `skill-base.sh` (via `skill_link_artifacts`) and `skill-orchestrate/SKILL.md` (direct calls) and `skill-reviser/SKILL.md` (direct call) — all must be updated
- Deprecation logging should go to `.claude/logs/deprecation.log` using the same `[TIMESTAMP] script: LEVEL message` format established by other logs, so task 652 can `grep "DEPRECATED"` to verify old paths are unused

---

## Context & Scope

The current pipeline was designed when TODO.md was the authoritative human-facing view. Task 647 enriched state.json to v1.1.0 and task 648 created `generate-todo.sh` which can regenerate all of TODO.md from state.json alone. The goal of this task is to make state.json the single write target, then regenerate TODO.md from it, eliminating the fragile awk/sed text surgery that currently keeps TODO.md in sync.

---

## Findings

### update-task-status.sh — Complete Phase Map

The script is organized into 5 labeled phases:

**PHASE 1 (lines 137–195): Update state.json** — KEEP AS-IS
- Acquires flock lock, updates `status`, `last_updated`, `session_id` via jq
- This is the core machine state write — unchanged

**PHASE 2 (lines 200–267): Update TODO.md task entry status** — REMOVE
- Function `update_todo_task_entry()`
- Greps for `### {N}.` heading line, then searches for `**Status**:` within next 10 lines
- Uses awk single-pass replacement to change `[STATUS]` on that specific line
- Writes via mktemp + mv
- **Replacement**: `generate-todo.sh` will render the correct status from state.json

**PHASE 3 (lines 272–368): Update TODO.md Task Order section** — REMOVE
- Function `update_todo_task_order()`
- Two modes: Mode B (terminal statuses) calls `generate-task-order.sh --update-todo`; Mode A (non-terminal) does in-place sed on tree lines
- Falls back to full regeneration via `generate-task-order.sh` on failures
- **Replacement**: `generate-todo.sh` calls `generate-task-order.sh --print` internally already

**PHASE 4 (lines 373–409): Plan file status update** — KEEP AS-IS
- Function `update_plan_file()`
- Only fires for `implement:preflight`, `implement:postflight`, and `plan:postflight`
- Delegates to `update-plan-status.sh` — this is not TODO.md surgery, it's updating the plan file's own status header
- Must be retained

**PHASE 5 (lines 433–445): Dual-dispatch lifecycle notifications** — KEEP AS-IS
- Fires WezTerm tab color and TTS on postflight
- Unrelated to TODO.md surgery

**After phases (lines 411–451): Execution and result reporting** — SIMPLIFY
- Currently calls `update_todo_task_entry()` and `update_todo_task_order()` and checks `$todo_failed`
- Replace entire block: after state.json update + plan file update, call `generate-todo.sh` once
- Remove `todo_failed` variable and exit code 3

**Exit code 3 (line 451)**: Currently returned when TODO.md updates fail but state.json succeeded. This exit code is used in zero callers (verified by grep). Can be removed.

#### What the new update-task-status.sh execution flow looks like

```
Phase 1: update state.json (flock-protected)
  |
  v
Phase 4: update plan file (if implement/plan operation)
  |
  v
Phase NEW: call generate-todo.sh (replaces Phases 2+3)
  |
  v
Phase 5: fire lifecycle notifications (postflight only)
  |
  v
Exit 0 (success)
```

### postflight-workflow.sh — Assessment

Reviewing the script carefully: `postflight-workflow.sh` does NOT contain any TODO.md awk/sed surgery. It only:
1. Updates `status` and timestamps in state.json (Step 1)
2. Filters existing artifacts of the same type from state.json (Step 2)
3. Adds the new artifact entry to state.json (Step 3)

**Conclusion**: `postflight-workflow.sh` is already state.json-only. The simplification needed here is:
- After Step 3, call `generate-todo.sh` to regenerate TODO.md
- This ensures the artifact appears in the rendered TODO.md without requiring `link-artifact-todo.sh`

Note: `postflight-workflow.sh` is currently only used as a standalone script (called by the thin wrapper scripts `postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`). Skills use `skill-base.sh` functions instead. Verify which callers actually invoke postflight-workflow.sh vs. skill_link_artifacts.

### link-artifact-todo.sh — Deprecation Plan

**Current callers** (all must be migrated away from):
1. `skill-base.sh:383-384` — inside `skill_link_artifacts()` function
2. `skill-orchestrate/SKILL.md:436-438` — direct call pattern for handoff artifacts
3. `skill-orchestrate/SKILL.md:1077-1079` — direct call pattern (multi-task orchestration section)
4. `skill-reviser/SKILL.md:383` — direct call after plan artifact linking
5. `reconcile-task-status.sh:154-157` — called during reconciliation (this is a recovery tool)
6. `skill-project-overview/SKILL.md:391-393` — optional usage with "if available" guard

**Deprecation approach**:
- Add a deprecation warning to the top of `link-artifact-todo.sh` that logs to `.claude/logs/deprecation.log`
- Keep the script fully functional (don't break callers that haven't been migrated yet)
- Log format: `[TIMESTAMP] link-artifact-todo: DEPRECATED called by task N (field_name=X path=Y)`
- After migration, task 652 verifies zero `DEPRECATED` entries appear in `deprecation.log` during a workflow run

**Callers NOT to migrate in task 649**:
- `reconcile-task-status.sh` — this is a repair/recovery tool that directly writes specific artifact links; it should eventually call `generate-todo.sh` instead but may need separate treatment
- `skill-project-overview/SKILL.md` — optional usage; can be updated but is low priority

### skill-base.sh — Function Changes Needed

**`skill_link_artifacts()` (lines 359–386)**:
- Currently does: (1) two-step state.json artifact array update, then (2) calls `link-artifact-todo.sh`
- New behavior: keep (1) exactly as-is; replace (2) with call to `generate-todo.sh`
- The state.json artifact update (Steps 1+2 in the function) must remain — generate-todo.sh reads from state.json, so artifacts must be in state.json first

**`skill_preflight_update()` (lines 140–147)**:
- Calls `update-task-status.sh preflight` — this already works correctly
- No change needed in the function itself; changes are inside `update-task-status.sh`
- After task 649 changes update-task-status.sh, preflight will call generate-todo.sh automatically

**`skill_postflight_update()` (lines 277–298)**:
- Calls `update-task-status.sh postflight` — same as above
- No change needed in the function itself

**`skill_link_artifact_from_handoff()` (lines 398–425)**:
- Calls `skill_link_artifacts()` at the end — indirect call to `link-artifact-todo.sh`
- Will be fixed automatically when `skill_link_artifacts()` is updated

### Skills That Directly Call link-artifact-todo.sh

These require direct code changes (not mediated through skill-base.sh):

1. **skill-orchestrate/SKILL.md** — Three locations:
   - Lines 436–438: artifact linking after research/plan/implement handoff processing
   - Lines 1077–1079: same in multi-task orchestration section
   - Replace both blocks with `generate-todo.sh` call (or remove if generate-todo.sh is now called inside `update-task-status.sh` earlier in the flow)

2. **skill-reviser/SKILL.md** — Line 383:
   - Direct call: `bash .claude/scripts/link-artifact-todo.sh $task_number '**Plan**' '**Description**' "$artifact_path"`
   - Replace with `generate-todo.sh` call

### Deprecation Logging Format for Task 652 Validation

Create `.claude/logs/deprecation.log` using the established log format:

```
[2026-06-10T23:00:00Z] link-artifact-todo: DEPRECATED called (task=649, field=**Research**, path=specs/649_slug/reports/01_report.md)
[2026-06-10T23:00:01Z] update-task-status: DEPRECATED todo-surgery phase2 called (task=650, status=RESEARCHING)
[2026-06-10T23:00:01Z] update-task-status: DEPRECATED todo-surgery phase3 called (task=650, status=RESEARCHING)
```

Task 652 validation command:
```bash
grep "DEPRECATED" .claude/logs/deprecation.log | tail -20
```

If the file is empty or the entries are all from before task 649's deploy, then the old paths are confirmed unused.

**Implementation**: In update-task-status.sh, before removing Phases 2 and 3, first add deprecation logging (guarded behind a `DEPRECATION_LOG` feature flag during transition). During transition, keep old code paths as logged fallbacks. After task 652 confirms zero invocations, task 652 removes the fallback code.

Transition flag approach:
```bash
PIPELINE_MODE="${PIPELINE_MODE:-new}"  # "new" | "legacy"

if [[ "$PIPELINE_MODE" == "legacy" ]]; then
  log_deprecation "update-task-status" "phase2" "$task_number" "$TODO_STATUS"
  update_todo_task_entry  # old path, logs DEPRECATED
fi
# Always run new path
generate-todo.sh
```

---

## Decisions

1. `postflight-workflow.sh` requires only a `generate-todo.sh` call added at the end — no structural changes
2. Phase 4 (plan file status) in `update-task-status.sh` is preserved unchanged
3. Phase 5 (notifications) in `update-task-status.sh` is preserved unchanged
4. The `exit 3` status code (TODO.md failure) is removed; state.json + generate-todo.sh don't have that failure mode
5. Deprecation log goes to `.claude/logs/deprecation.log` (new file, consistent format)
6. During transition, old TODO.md surgery code is wrapped in `PIPELINE_MODE=legacy` guard and logs `DEPRECATED`
7. `reconcile-task-status.sh` is deferred — it's a repair/recovery tool and needs careful separate treatment

---

## Risks & Mitigations

**Risk 1: generate-todo.sh is slower than in-place awk** (generates entire TODO.md ~1s vs microseconds)
- Mitigation: Acceptable tradeoff. Current TODO.md has ~17 tasks = fast. Log elapsed time already present in generate-todo.sh. If performance becomes an issue, the log provides data.

**Risk 2: Concurrent write collision (multiple agents updating state.json simultaneously)**
- Mitigation: update-task-status.sh already uses `flock -x -w 30` for Phase 1. Since generate-todo.sh is called after the lock is released, two agents could call generate-todo.sh in parallel. The last-write-wins on TODO.md is acceptable because both agents write the same content (both read from the now-updated state.json).

**Risk 3: skill-orchestrate and skill-reviser still call link-artifact-todo.sh directly**
- Mitigation: These callers must be updated in the same implementation task. Deprecation logging in link-artifact-todo.sh will surface any missed callers.

**Risk 4: TODO.md becomes empty or corrupted if generate-todo.sh fails**
- Mitigation: generate-todo.sh already uses atomic write (mktemp + mv). If it fails with non-zero exit, no write occurs. Wrap `generate-todo.sh` calls in `|| echo "WARNING: generate-todo.sh failed (non-fatal)"` to prevent cascade failures.

**Risk 5: reconcile-task-status.sh continues calling link-artifact-todo.sh**
- Mitigation: reconcile-task-status.sh is a recovery/repair tool invoked rarely. The deprecation log will show if it's called. Task 652 can decide whether to update it.

**Risk 6: postflight-workflow.sh thin-wrapper scripts (postflight-research.sh etc.) are called by unknown code**
- Mitigation: Grep confirms these wrappers simply exec postflight-workflow.sh. Changes to postflight-workflow.sh propagate automatically.

---

## Fallback Strategy for Transition Period

1. **Add `PIPELINE_MODE` environment variable** to update-task-status.sh and skill-base.sh
   - `PIPELINE_MODE=legacy` restores old awk/sed behavior (for rollback)
   - `PIPELINE_MODE=new` (default after task 649) uses generate-todo.sh

2. **Keep deprecated functions** `update_todo_task_entry()` and `update_todo_task_order()` in update-task-status.sh but wrapped in `[[ "$PIPELINE_MODE" == "legacy" ]]` guards

3. **Add deprecation logging** to `link-artifact-todo.sh` unconditionally — every invocation is logged even in new pipeline mode, so task 652 can verify zero calls

4. **Task 652 cleanup**: After confirming zero DEPRECATED log entries, remove legacy code paths and the `PIPELINE_MODE` variable

---

## Context Extension Recommendations

None for this meta task — changes are entirely within .claude/scripts/ and .claude/skills/.

---

## Appendix

### Files to Modify

| File | Change Type | Summary |
|------|-------------|---------|
| `.claude/scripts/update-task-status.sh` | Modify | Remove Phases 2+3 (awk/sed), add generate-todo.sh call, add deprecation logging for old paths, remove exit code 3 |
| `.claude/scripts/postflight-workflow.sh` | Modify | Add generate-todo.sh call after Step 3 (artifact linking to state.json) |
| `.claude/scripts/skill-base.sh` | Modify | In `skill_link_artifacts()`: replace `link-artifact-todo.sh` call with `generate-todo.sh` call |
| `.claude/scripts/link-artifact-todo.sh` | Deprecate | Add DEPRECATED logging at entry; keep fully functional; mark with DEPRECATED comment in header |
| `.claude/skills/skill-orchestrate/SKILL.md` | Modify | Replace 2 direct `link-artifact-todo.sh` blocks with `generate-todo.sh` |
| `.claude/skills/skill-reviser/SKILL.md` | Modify | Replace direct `link-artifact-todo.sh` call with `generate-todo.sh` |

### Files to Leave Unchanged (This Task)

| File | Reason |
|------|--------|
| `.claude/scripts/reconcile-task-status.sh` | Recovery tool; needs separate analysis |
| `.claude/skills/skill-project-overview/SKILL.md` | Optional/guarded call; low priority |
| All other skills | Use `skill_link_artifacts()` which is updated via skill-base.sh |

### Call Graph (Current)

```
skill_preflight_update()
  └─> update-task-status.sh preflight
        ├─ Phase 1: state.json update (KEEP)
        ├─ Phase 2: TODO.md task entry awk (REMOVE)
        ├─ Phase 3: TODO.md task order awk (REMOVE)
        ├─ Phase 4: plan file update (KEEP)
        └─ Phase 5: notifications (KEEP)

skill_postflight_update()
  └─> update-task-status.sh postflight
        └─ (same phases)

skill_link_artifacts()
  ├─ jq: state.json artifact array update (KEEP)
  └─> link-artifact-todo.sh (REMOVE, add generate-todo.sh)

postflight-workflow.sh
  ├─ jq: state.json status update (KEEP)
  ├─ jq: state.json artifact filter (KEEP)
  └─ jq: state.json artifact add (KEEP)
     → [add generate-todo.sh call here]
```

### Call Graph (Target — New Pipeline)

```
skill_preflight_update()
  └─> update-task-status.sh preflight
        ├─ Phase 1: state.json update
        ├─ Phase 4: plan file update (when applicable)
        ├─ Phase NEW: generate-todo.sh call
        └─ Phase 5: notifications (postflight only)

skill_postflight_update()
  └─> update-task-status.sh postflight
        └─ (same phases)

skill_link_artifacts()
  ├─ jq: state.json artifact array update
  └─> generate-todo.sh (replaces link-artifact-todo.sh)

postflight-workflow.sh
  ├─ jq: state.json status update
  ├─ jq: state.json artifact filter
  ├─ jq: state.json artifact add
  └─> generate-todo.sh (new call at end)
```

### Deprecation Log Format

File: `.claude/logs/deprecation.log`

```
[ISO8601] SCRIPT_NAME: DEPRECATED DESCRIPTION (context_key=value ...)
```

Examples:
```
[2026-06-10T23:00:00Z] link-artifact-todo: DEPRECATED task=649 field=**Research** path=specs/649_slug/reports/01.md
[2026-06-10T23:00:01Z] update-task-status: DEPRECATED phase2-todo-surgery task=650 status=RESEARCHING
[2026-06-10T23:00:01Z] update-task-status: DEPRECATED phase3-task-order task=650 status=RESEARCHING
```

Task 652 verification:
```bash
# Verify no old paths were triggered
if grep -q "DEPRECATED" .claude/logs/deprecation.log; then
  echo "OLD PATHS STILL IN USE — inspect deprecation.log"
  grep "DEPRECATED" .claude/logs/deprecation.log | tail -20
else
  echo "CLEAN: No deprecated paths used"
fi
```
