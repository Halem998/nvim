# Research Report: Task #658

**Task**: 658 - Integrate shared postflight into skill-orchestrate
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:30:00Z
**Effort**: ~2 hours research
**Dependencies**: Task 657 (orchestrator-postflight.sh — COMPLETE)
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, orchestrator-postflight.sh, skill-base.sh, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md, architecture docs)
**Artifacts**: specs/658_integrate_shared_postflight_orchestrate/reports/01_integration-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The current skill-orchestrate Stage 5 calls `skill_postflight_update` and `skill_link_artifacts` (from skill-base.sh) inline — but these only fire when `.orchestrator-handoff.json` exists, which is only written by skills when `orchestrator_mode: true`. Research (`orchestrator_mode: false`) and plan (`orchestrator_mode: false`) dispatches never write a handoff, so the current postflight calls are effectively dead code for those phases.
- The fix is to have skill-orchestrate call `orchestrator-postflight.sh` directly after each dispatch by reading `.return-meta.json` (which ALL agents write regardless of `orchestrator_mode`), rather than relying on `.orchestrator-handoff.json` artifact data.
- The two files serve different purposes and must COEXIST: `.orchestrator-handoff.json` is still needed for state machine decisions (status, blockers, continuation), while `.return-meta.json` is the artifact data source for postflight.
- Architecture docs need updates to describe the unified postflight path via orchestrator-postflight.sh.

---

## Context & Scope

Task 657 created `.claude/scripts/orchestrator-postflight.sh` — a 337-line shared pipeline that handles status update, artifact number increment, memory candidate propagation, artifact linking (state.json), TODO.md regeneration, TTS notification, git commit, and cleanup. Skills skill-researcher, skill-planner, and skill-implementer now call this script.

Tasks 659 and 660 have already modified skill-orchestrate/SKILL.md:
- Task 659 added `phase_constraint` to all 12 dispatch contexts
- Task 660 added 7 preflight calls (update-task-status.sh preflight) before each dispatch

This task (658) must now update skill-orchestrate to call `orchestrator-postflight.sh` instead of the inline `skill_postflight_update` and `skill_link_artifacts` calls.

---

## Findings

### 1. The Core Problem: Dead Postflight Code

The current Stage 5 (lines 356-431) reads `.orchestrator-handoff.json` for artifact data:

```bash
handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
```

BUT: research is dispatched with `orchestrator_mode: false` and plan is dispatched with `orchestrator_mode: false`. The handoff-schema.md writing contract states:

> Skills MUST write `.orchestrator-handoff.json` when and ONLY when `"orchestrator_mode": true` appears in the delegation context.

So for research and plan dispatches, `.orchestrator-handoff.json` is NEVER written. Stage 5's `if [ ! -f "$handoff_file" ]` branch fires, which logs a warning and continues — but `dispatch_status` is never set from an existing handoff. The `skill_postflight_update` and `skill_link_artifacts` calls on lines 388–426 are never reached for research/plan.

**This is a bug, not just code to replace.** Research and plan runs under `/orchestrate` currently do NOT get proper postflight processing (no artifact linking, no TODO.md link updates).

### 2. The Solution: Read `.return-meta.json` for Artifact Data

ALL agents (research, plan, implement) write `.return-meta.json` regardless of `orchestrator_mode`. The schema (from return-metadata-file.md) is:

```json
{
  "status": "researched|planned|implemented|partial|failed",
  "artifacts": [{"path": "...", "type": "...", "summary": "..."}],
  "memory_candidates": [...],
  "completion_data": {...},   // implement only
  "partial_progress": {...}   // partial only
}
```

`orchestrator-postflight.sh` already reads this file (Stage 6 of the script):
```bash
status=$(jq -r '.status' "$metadata_file")
artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
...
```

The orchestrator should call `orchestrator-postflight.sh` with the appropriate `OPERATION_TYPE` argument to drive the full postflight pipeline.

### 3. Coexistence of `.return-meta.json` and `.orchestrator-handoff.json`

These files serve orthogonal purposes and must coexist:

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `.orchestrator-handoff.json` | Skills (orchestrator_mode=true) | skill-orchestrate | State machine decisions: status, blockers, continuation context |
| `.return-meta.json` | Agents (always) | orchestrator-postflight.sh | Artifact data: paths, types, summaries, memory candidates |

**Key insight**: The orchestrator still MUST read `.orchestrator-handoff.json` for:
- `dispatch_status` — determines postflight route (researched/planned/implemented/partial/failed)
- `blockers` — determines if blocker escalation needed
- `continuation_context` — determines if implementation should resume
- `next_action_hint` — advisory for state machine
- `phases_completed`/`phases_total` — drift detection

But for artifact linking and status updates, `.return-meta.json` has richer and more reliable data.

### 4. The Integration Pattern

After each dispatch, Stage 5 should:

1. **Continue reading `.orchestrator-handoff.json`** for state machine decisions (status, blockers, continuation) — this is unchanged
2. **Call `orchestrator-postflight.sh`** with `TASK_NUMBER, PROJECT_NAME, PADDED_NUM, SESSION_ID, OPERATION_TYPE` to drive the full postflight pipeline from `.return-meta.json`

The `OPERATION_TYPE` mapping from `dispatch_status`:
- `dispatch_status = "researched"` → `OPERATION_TYPE = "research"` 
- `dispatch_status = "planned"` → `OPERATION_TYPE = "plan"`
- `dispatch_status = "implemented"` → `OPERATION_TYPE = "implement"`

For research dispatches where `.orchestrator-handoff.json` doesn't exist, the orchestrator should also be able to infer `dispatch_status` from `.return-meta.json` as a fallback.

### 5. Exact Lines to Replace — Single-Task Stage 5 (lines 386–426)

Current code that needs replacement (lines 385-426 in SKILL.md):

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

# Artifact linking: extract artifact path/type from handoff and link in TODO.md + state.json
handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
if [ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]; then
  case "$handoff_artifact_type" in
    report)
      field_name='**Research**'
      next_field='**Plan**'
      ;;
    plan)
      field_name='**Plan**'
      next_field='**Description**'
      ;;
    summary)
      field_name='**Summary**'
      next_field='**Description**'
      ;;
    *)
      field_name='**Summary**'
      next_field='**Description**'
      ;;
  esac
  skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
    "$handoff_artifact_summary" "$field_name" "$next_field"
fi
```

**Replacement**: A single call to `orchestrator-postflight.sh` driven by `dispatch_status`:

```bash
# Postflight: delegate to shared pipeline (reads .return-meta.json for artifact data)
case "$dispatch_status" in
  researched)
    bash .claude/scripts/orchestrator-postflight.sh \
      "$task_number" "$PROJECT_NAME" "$PADDED_NUM" "$session_id" "research" "$TASK_TYPE" || \
      echo "[orchestrate] WARNING: research postflight failed (non-blocking)"
    ;;
  planned)
    bash .claude/scripts/orchestrator-postflight.sh \
      "$task_number" "$PROJECT_NAME" "$PADDED_NUM" "$session_id" "plan" "$TASK_TYPE" || \
      echo "[orchestrate] WARNING: plan postflight failed (non-blocking)"
    ;;
  implemented)
    bash .claude/scripts/orchestrator-postflight.sh \
      "$task_number" "$PROJECT_NAME" "$PADDED_NUM" "$session_id" "implement" "$TASK_TYPE" || \
      echo "[orchestrate] WARNING: implement postflight failed (non-blocking)"
    ;;
  *)
    echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
    ;;
esac
```

**Note**: `orchestrator-postflight.sh` Stage 10 (cleanup) deletes `.return-meta.json`. This is intentional — after postflight, the metadata is no longer needed. The orchestrator continues using `.orchestrator-handoff.json` for state decisions (which is NOT deleted by the postflight script).

### 6. Exact Lines to Replace — Multi-Task Stage MT-4 (lines 1020–1063)

Same pattern, but parameterized with `$task_num` and `${session_id}_${task_num}`:

Current code (lines 1019-1063):

```bash
case "$dispatch_status" in
  researched)
    operation="research"
    skill_postflight_update "$task_num" "research" "${session_id}_${task_num}" "$dispatch_status"
    ;;
  planned)
    operation="plan"
    skill_postflight_update "$task_num" "plan" "${session_id}_${task_num}" "$dispatch_status"
    ;;
  implemented)
    operation="implement"
    skill_postflight_update "$task_num" "implement" "${session_id}_${task_num}" "$dispatch_status"
    ;;
  *)
    operation="unknown"
    echo "[orchestrate-mt] Task $task_num status '$dispatch_status' — no postflight update"
    ;;
esac

# Artifact linking (same logic as single-task Stage 5)
handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
... [22 lines of field_name/skill_link_artifacts logic]
```

**Replacement**:

```bash
# Per-task postflight: delegate to shared pipeline
task_type_for_task="${task_types[$task_num]:-general}"
mt_padded=$(printf "%03d" "$task_num")
mt_project_name="${task_dirs[$task_num]#specs/${mt_padded}_}"

case "$dispatch_status" in
  researched)
    bash .claude/scripts/orchestrator-postflight.sh \
      "$task_num" "$mt_project_name" "$mt_padded" "${session_id}_${task_num}" \
      "research" "$task_type_for_task" || \
      echo "[orchestrate-mt] WARNING: research postflight failed for task $task_num (non-blocking)"
    ;;
  planned)
    bash .claude/scripts/orchestrator-postflight.sh \
      "$task_num" "$mt_project_name" "$mt_padded" "${session_id}_${task_num}" \
      "plan" "$task_type_for_task" || \
      echo "[orchestrate-mt] WARNING: plan postflight failed for task $task_num (non-blocking)"
    ;;
  implemented)
    bash .claude/scripts/orchestrator-postflight.sh \
      "$task_num" "$mt_project_name" "$mt_padded" "${session_id}_${task_num}" \
      "implement" "$task_type_for_task" || \
      echo "[orchestrate-mt] WARNING: implement postflight failed for task $task_num (non-blocking)"
    ;;
  *)
    echo "[orchestrate-mt] Task $task_num status '$dispatch_status' — no postflight update"
    ;;
esac
```

### 7. Fallback: Reading .return-meta.json When Handoff Missing

For research dispatches (`orchestrator_mode: false`), `.orchestrator-handoff.json` is never written. The current Stage 5 logs a warning and continues with unset `dispatch_status`. A better fallback is to read `.return-meta.json` to determine `dispatch_status`:

```bash
if [ ! -f "$handoff_file" ]; then
  # No orchestrator handoff — infer status from .return-meta.json (research/plan paths)
  meta_file="${TASK_DIR}/.return-meta.json"
  if [ -f "$meta_file" ] && jq empty "$meta_file" 2>/dev/null; then
    dispatch_status=$(jq -r '.status' "$meta_file")
    echo "[orchestrate] Inferred dispatch_status from .return-meta.json: $dispatch_status"
  else
    echo "[orchestrate] ERROR: No handoff and no .return-meta.json. Skill output missing."
    cycle_count=$((cycle_count + 1))
    continue
  fi
else
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status')
  ...
fi
```

This gracefully handles the case where `orchestrator_mode: false` skills write only `.return-meta.json`.

### 8. Implement Operation: SKIP_COMPLETION_DATA

The `orchestrator-postflight.sh` has a `SKIP_COMPLETION_DATA` environment variable (line 216) used by skill-implementer to prevent double-writing completion data when the skill has already handled it inline.

For the orchestrator, implement dispatches use `orchestrator_mode: true` in skill-implementer. The implementer's own postflight (not the orchestrator's) handles completion_data inline. However, skill-implementer calls `orchestrator-postflight.sh` itself as part of its postflight. So when skill-orchestrate later calls `orchestrator-postflight.sh` for "implement", the `.return-meta.json` has already been deleted by skill-implementer's cleanup (Stage 10).

This means for implement dispatches, the orchestrator's call to `orchestrator-postflight.sh` would fail to find `.return-meta.json` — it would log a warning and run cleanup-only. This is acceptable behavior (the actual postflight was already done by skill-implementer).

**Recommendation**: For the implement case, the orchestrator's postflight call is a no-op (`.return-meta.json` already gone). The orchestrator should still call it for consistency, but should not treat missing metadata as an error. The `orchestrator-postflight.sh` already handles this gracefully (sets `status="failed"`, still runs cleanup).

### 9. Architecture Documentation Updates Needed

Three docs need updates:

**a. `orchestrate-state-machine.md`**: Add a section describing the dual-file read pattern:
- `.orchestrator-handoff.json` for state machine decisions
- `.return-meta.json` (via `orchestrator-postflight.sh`) for artifact postflight

**b. `handoff-schema.md`**: Clarify that `artifacts` array in the handoff is now ADVISORY (for state machine continuation context only) — the authoritative artifact data for linking comes from `.return-meta.json` via the shared postflight script.

**c. `dispatch-agent-spec.md`**: Note that postflight is now unified via `orchestrator-postflight.sh` for all operation types, matching the path used by individual `/research`, `/plan`, `/implement` commands.

### 10. skill_postflight_update and skill_link_artifacts in skill-base.sh

These functions remain in skill-base.sh for use by any skills that call them directly (they are referenced in the postflight of some older patterns). They are NOT removed — only the orchestrator's call sites are replaced. The orchestrator no longer needs to call them because `orchestrator-postflight.sh` handles all of this internally.

---

## Decisions

1. **Do NOT remove `skill_postflight_update` / `skill_link_artifacts` from skill-base.sh** — only remove the orchestrator's call sites; these functions may be used by other skills.
2. **Coexistence is the design**: `.orchestrator-handoff.json` for state machine control; `.return-meta.json` for artifact postflight data. They serve different consumers and MUST NOT be merged.
3. **For research/plan dispatches, infer dispatch_status from `.return-meta.json`** when `.orchestrator-handoff.json` is absent — this fixes the current silent bug where research postflight never fires.
4. **For implement dispatches, the orchestrator's `orchestrator-postflight.sh` call is effectively a no-op** (skill-implementer already ran its own postflight which deleted `.return-meta.json`). This is acceptable and consistent.
5. **The orchestrator's own `.return-meta.json`** (written in Stage 8, line 648) is a different file path (`${TASK_DIR}/.return-meta.json`) from the task's `.return-meta.json`. After postflight is called, the script deletes the task `.return-meta.json`. The orchestrator's own return-meta (for the parent skill invocation) is separate and should NOT be affected.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `.return-meta.json` already deleted by skill-implementer when orchestrator calls postflight for implement | Low | `orchestrator-postflight.sh` handles missing metadata gracefully (status=failed, cleanup-only) |
| `project_name` extraction in MT-4 requires parsing from `task_dirs[$task_num]` | Medium | Use `${task_dirs[$task_num]#specs/${mt_padded}_}` to strip prefix; verify this is reliable |
| `orchestrator-postflight.sh` Stage 10 deletes `.return-meta.json` — this could conflict if called twice | Low | Script is idempotent — cleanup of already-absent files uses `rm -f` (non-fatal) |
| Stage 8 of orchestrate writes orchestrator's own `.return-meta.json` after postflight — not affected | None | Different file path (orchestrator's `.return-meta.json` is for the caller, not the task) |
| Research dispatch (`orchestrator_mode: false`) has no `.orchestrator-handoff.json` — need fallback | Medium | Read `.return-meta.json` as fallback to determine dispatch_status |
| `SKIP_COMPLETION_DATA` env var not set by orchestrator for implement | Low | For implement, postflight is already done by skill-implementer; orchestrator's call is no-op |

---

## Context Extension Recommendations

- **Topic**: Dual-file postflight pattern in orchestrate
- **Gap**: No documented pattern for how orchestrate reads both `.orchestrator-handoff.json` (state machine) and `.return-meta.json` (artifact data) in parallel
- **Recommendation**: Update `handoff-schema.md` to note that artifact data for linking is now sourced from `.return-meta.json` via `orchestrator-postflight.sh`, not from the handoff's `artifacts` array

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (1175 lines, modified by tasks 659 and 660)
- `/home/benjamin/.config/nvim/.claude/scripts/orchestrator-postflight.sh` (337 lines, created by task 657)
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` (476 lines — contains `skill_postflight_update`, `skill_link_artifacts`)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (confirmed calls orchestrator-postflight.sh)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (confirmed calls orchestrator-postflight.sh)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (confirmed calls orchestrator-postflight.sh)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/orchestrate-state-machine.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/dispatch-agent-spec.md`

### Key Line References in skill-orchestrate/SKILL.md
- Stage 5 postflight calls: lines 386-426 (single-task)
- Stage MT-4 postflight calls: lines 1019-1063 (multi-task)
- Stage 5 handoff-reading header: lines 357-372
- Stage 8 orchestrator's own `.return-meta.json`: lines 637-649

### orchestrator-postflight.sh Interface
```bash
bash .claude/scripts/orchestrator-postflight.sh \
    TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]
# OPERATION_TYPE: research | plan | implement
# TASK_TYPE: optional, used for meta-skip of roadmap_items
# SKIP_COMPLETION_DATA: env var, if "true" skips Stage 7b
```
