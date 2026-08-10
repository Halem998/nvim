# Research Report: Task #756

**Task**: 756 - Fix orchestrate Stage 5 to link artifacts via .return-meta.json fallback
**Started**: 2026-06-22T00:00:00Z
**Completed**: 2026-06-22T00:05:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (.claude/skills/skill-orchestrate/SKILL.md, .claude/scripts/skill-base.sh, .claude/context/formats/return-metadata-file.md, .claude/skills/skill-researcher/SKILL.md, .claude/skills/skill-planner/SKILL.md)
**Artifacts**: specs/756_fix_orchestrate_artifact_linking/reports/01_artifact-linking-fix.md
**Standards**: report-format.md

## Executive Summary

- Stage 5 of skill-orchestrate has a dead `if [ ! -f "$handoff_file" ]` branch that only logs an error and increments cycle_count — it skips all artifact linking and status postflight
- When agents are dispatched directly (not via the skill layer with `orchestrator_mode: true`), no `.orchestrator-handoff.json` is written, triggering this branch
- The fix is: in the `! -f "$handoff_file"` branch, read `.return-meta.json` from `$TASK_DIR`, extract `status`, `artifacts[0].path/type/summary`, then call the same `skill_postflight_update` + `skill_link_artifacts` logic that the `else` branch uses
- The type mapping and field_name/next_field logic already exists in the `else` branch and can be reused verbatim

## Context & Scope

### Problem

`/orchestrate` dispatches agents via the Agent tool. When dispatching, it sets `orchestrator_mode: true` in the delegation context. Properly-integrated skills call `skill_write_orchestrator_handoff` (from `skill-base.sh`) which writes `specs/{NNN}_{SLUG}/.orchestrator-handoff.json`. Stage 5 then reads this handoff to determine dispatch status, update state.json, and link artifacts.

However, when orchestrate dispatches agents directly (bypassing the skill layer, or when `orchestrator_mode` is not propagated), no handoff file is written. The current `if [ ! -f "$handoff_file" ]` branch simply:

```bash
echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
echo "This may mean orchestrator_mode was not propagated correctly."
# Increment cycle and continue — state.json may still have been updated
```

This means:
1. No `skill_postflight_update` call → task status stays stuck in "researching"/"planning"/"implementing"
2. No `skill_link_artifacts` call → artifact paths never appear in state.json/TODO.md

### What Agents Do Write

All agents (general-research-agent, planner-agent, general-implementation-agent, etc.) always write `.return-meta.json` to `specs/{NNN}_{SLUG}/.return-meta.json`. This is the primary metadata exchange format. The `.orchestrator-handoff.json` is a secondary, orchestrator-specific artifact that wraps a subset of the same data.

## Findings

### Codebase Patterns

#### Stage 5 Current Structure (lines 346-441 of SKILL.md)

```bash
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
  echo "This may mean orchestrator_mode was not propagated correctly."
  # Increment cycle and continue — state.json may still have been updated
else
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  # ... reads blockers, continuation, next_hint, phases_completed, phases_total
  
  # Postflight status update
  case "$dispatch_status" in
    researched) skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status" ;;
    planned)    skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status" ;;
    implemented) skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" ;;
  esac

  # Artifact linking
  handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
  handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
  handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
  if [ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]; then
    case "$handoff_artifact_type" in
      report)  field_name='**Research**'; next_field='**Plan**' ;;
      plan)    field_name='**Plan**'; next_field='**Description**' ;;
      summary) field_name='**Summary**'; next_field='**Description**' ;;
      *)       field_name='**Summary**'; next_field='**Description**' ;;
    esac
    skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
      "$handoff_artifact_summary" "$field_name" "$next_field"
  fi
fi
```

#### Variables Available in Stage 5

From Stage 1 setup (lines 64-75):
- `PADDED_NUM` = zero-padded task number (e.g., "756")
- `PROJECT_NAME` = task slug (e.g., "fix_orchestrate_artifact_linking")
- `TASK_DIR` = "specs/${PADDED_NUM}_${PROJECT_NAME}"
- `task_number` = unpadded task number

From Stage 2 setup (line 128):
- `handoff_file` = "${TASK_DIR}/.orchestrator-handoff.json"

The `.return-meta.json` path is: `"${TASK_DIR}/.return-meta.json"` (consistent with `skill_read_metadata` in skill-base.sh).

#### .return-meta.json Schema (relevant fields)

```json
{
  "status": "researched|planned|implemented|partial|failed|blocked",
  "artifacts": [
    {
      "type": "report|plan|summary|implementation",
      "path": "specs/756_foo/reports/01_bar.md",
      "summary": "Brief description"
    }
  ]
}
```

The `status` values match exactly what the `else` branch's `case` statement expects (`researched`, `planned`, `implemented`).

The `artifacts[0].type` values (`report`, `plan`, `summary`) match exactly what the artifact linking `case` statement expects.

#### skill_postflight_update Signature

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
# operation: "research" | "plan" | "implement"
# status: "researched" | "planned" | "implemented" | (others skipped)
```

This function is already sourced via `skill-base.sh` in the orchestrator context.

#### skill_link_artifacts Signature

```bash
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" \
  "$artifact_summary" "$field_name" "$next_field"
# artifact_type: passed directly to state.json (uses "report", "plan", "summary" from handoff)
```

Note: The comment on `skill_link_artifacts` says `"research" | "plan" | "summary"` but the function just passes the string through to jq. The handoff schema (and `.return-meta.json`) both use `"report"` for research artifacts, and the Stage 5 `else` branch passes `"report"` directly — so the fallback should do the same.

### How Standalone Skills Handle Postflight

Both `skill-researcher` (Stage 6-8) and `skill-planner` (Stage 6-8) follow this identical pattern:

1. Read `.return-meta.json` → extract `status`, `artifact_path`, `artifact_type`, `artifact_summary`
2. If `status == "researched"`: call `update-task-status.sh postflight $task_number research $session_id`
3. Call the two-step jq pattern to link artifact in state.json
4. Call `generate-todo.sh` to regenerate TODO.md

The orchestrator's `skill_postflight_update` and `skill_link_artifacts` wrappers replicate this same logic. The fallback code can call these wrappers directly.

## Decisions

- **Use .return-meta.json as authoritative fallback**: When `.orchestrator-handoff.json` is absent, `.return-meta.json` is always present (agents always write it)
- **Reuse existing case statement logic**: The type mapping (`report -> **Research**`, etc.) already exists in the `else` branch — duplicate it into the `if` branch
- **Non-blocking approach**: If `.return-meta.json` is also absent, log a warning and increment cycle (same behavior as current)
- **No change to drift detection or commit logic**: These rely on `phases_completed`/`phases_total` from the handoff; with no handoff, skip drift detection and per-cycle commit (both already require handoff data to be meaningful)

## Exact Code Change

Replace the current `if [ ! -f "$handoff_file" ]` branch in Stage 5:

### Current (lines ~346-350 of SKILL.md)

```bash
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
  echo "This may mean orchestrator_mode was not propagated correctly."
  # Increment cycle and continue — state.json may still have been updated
else
```

### Replacement

```bash
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] WARNING: No orchestrator handoff found. Falling back to .return-meta.json."
  meta_file="${TASK_DIR}/.return-meta.json"
  if [ -f "$meta_file" ] && jq empty "$meta_file" 2>/dev/null; then
    dispatch_status=$(jq -r '.status' "$meta_file")
    meta_artifact_path=$(jq -r '.artifacts[0].path // ""' "$meta_file")
    meta_artifact_type=$(jq -r '.artifacts[0].type // ""' "$meta_file")
    meta_artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$meta_file")
    echo "[orchestrate] Fallback dispatch result from .return-meta.json: $dispatch_status"

    # Postflight status update (same logic as else branch)
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
        echo "[orchestrate] Fallback status '$dispatch_status' — no postflight update needed"
        ;;
    esac

    # Artifact linking (same logic as else branch)
    if [ -n "$meta_artifact_path" ] && [ "$meta_artifact_path" != "null" ]; then
      case "$meta_artifact_type" in
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
      skill_link_artifacts "$task_number" "$meta_artifact_path" "$meta_artifact_type" \
        "$meta_artifact_summary" "$field_name" "$next_field"
    fi
  else
    echo "[orchestrate] ERROR: Neither handoff nor .return-meta.json found. State.json may be stale."
    echo "This may mean orchestrator_mode was not propagated correctly."
    # Increment cycle and continue — no postflight possible without metadata
  fi
else
```

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `.return-meta.json` has `status: "in_progress"` (agent interrupted mid-run) | The `case` statement's `*)` branch logs "no postflight needed" and skips update — same as current behavior for non-terminal statuses |
| Double postflight if handoff AND return-meta both exist | Existing code: only enters fallback when `! -f "$handoff_file"` — no double-trigger possible |
| Type mismatch: return-meta uses "report", state.json expects "research" | Existing `else` branch already passes "report" to `skill_link_artifacts` and it works — fallback uses same values |
| Drift detection skipped in fallback path | Drift detection requires `phases_completed`/`phases_total` from the handoff; these are not available in `.return-meta.json` under normal research/plan dispatches — acceptable to skip |
| Per-cycle commit skipped in fallback path | Commit logic requires `dispatch_status = "implemented"` and `phases_completed > 0` from handoff — fallback reads `dispatch_status` from meta but lacks `phases_completed`, so commit is skipped; acceptable since the agent's own commit (via skill-base.sh) already committed the changes |

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — lines 60-75 (variable setup), 128 (handoff_file), 340-441 (Stage 5)
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — lines 224-366 (skill_read_metadata, skill_postflight_update, skill_link_artifacts, skill_cleanup)
- `/home/benjamin/.config/nvim/.claude/context/formats/return-metadata-file.md` — full schema
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` — lines 326-459 (Stage 6-9 postflight pattern)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` — lines 351-468 (Stage 6-10 postflight pattern)
