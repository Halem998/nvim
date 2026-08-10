# Research Report: Task #639

**Task**: 639 - Fix /orchestrate TODO.md status sync and artifact linking
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:05:00Z
**Effort**: 15 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase — SKILL.md, skill-base.sh, update-task-status.sh, link-artifact-todo.sh
**Artifacts**: specs/639_fix_orchestrate_todo_sync/reports/01_todo-sync-analysis.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `skill-orchestrate/SKILL.md` calls `skill_preflight_update`, `skill_postflight_update`, and `skill_link_artifact_from_handoff` as if they were available bash functions, but the executing agent reads SKILL.md as markdown guidance, not a sourced script. The agent never runs `source .claude/scripts/skill-base.sh`, so all three function calls are silently dropped.
- The fix is to replace every function-call reference in SKILL.md with the equivalent direct bash commands — calling `update-task-status.sh` and `link-artifact-todo.sh` inline, and inlining the `skill_link_artifact_from_handoff` logic.
- There are **8 preflight call sites**, **5 postflight call sites**, and **2 artifact-linking call sites** spread across single-task Stages 4/5 and multi-task Stages MT-3/MT-4.

---

## Context & Scope

The root cause is an architectural mismatch: `SKILL.md` files are read as agent instruction documents, not executed as bash. Function-call syntax in code blocks is interpreted as pseudocode/guidance by the agent. When the agent executes bash blocks, it creates its own subshell without sourcing `skill-base.sh`, so the shell functions are undefined and the calls are no-ops.

The fix must replace every function call with a self-contained bash invocation that the agent can run directly.

---

## Findings

### Function Signatures (from skill-base.sh)

**`skill_preflight_update "$task_number" "$operation" "$session_id"`**
- Delegates to: `bash .claude/scripts/update-task-status.sh preflight "$task_number" "$operation" "$session_id"`
- Also runs an extension hook (can be omitted in SKILL.md since TASK_TYPE/TASK_DIR may not be set in orchestrate context)

**`skill_postflight_update "$task_number" "$operation" "$session_id" "$status"`**
- Delegates to: `bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"`
- Only runs if `$status` is one of `researched|planned|revised|implemented`
- Also runs an extension hook (can be omitted)

**`skill_link_artifact_from_handoff "$task_number" "$handoff_json"`**
- Extracts `artifacts[0].{path,type,summary}` from handoff JSON
- Maps type to `field_name`/`next_field`:
  - `report` -> `'**Research**'` / `'**Plan**'`
  - `plan`   -> `'**Plan**'` / `'**Description**'`
  - `summary` (default) -> `'**Summary**'` / `'**Description**'`
- Calls `skill_link_artifacts` which calls `bash .claude/scripts/link-artifact-todo.sh "$task_number" "$field_name" "$next_field" "$artifact_path"`
- Also updates `state.json` artifacts array (two-step jq via `specs/tmp/state.json`)

### Script CLI Interfaces

**`update-task-status.sh`**
```
Usage: .claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> [--dry-run]
  operation:     preflight | postflight
  target_status: research | plan | implement | revise
```
Updates state.json status, TODO.md **Status** field, and TODO.md Task Order section atomically.

**`link-artifact-todo.sh`**
```
Usage: .claude/scripts/link-artifact-todo.sh <task_number> <field_name> <next_field> <artifact_path> [--dry-run]
  field_name: '**Research**', '**Plan**', or '**Summary**'
  next_field: '**Plan**', '**Description**', or '**Summary**'
```
Updates TODO.md task entry to link the artifact under the correct field.

---

### Complete Inventory of Function References in SKILL.md

#### Single-Task Mode

**Preflight calls (Stage 4 state handlers)**

| Line | Call | Context |
|------|------|---------|
| 202 | `skill_preflight_update "$task_number" "research" "$session_id"` | State: `not_started` — before research dispatch |
| 231 | `skill_preflight_update "$task_number" "plan" "$session_id"` | State: `researched` — before plan dispatch |
| 261 | `skill_preflight_update "$task_number" "implement" "$session_id"` | State: `planned`/`implementing` — before implement dispatch |
| 294 | `skill_preflight_update "$task_number" "implement" "$session_id"` | State: `partial` (continuation) — before resume dispatch |
| 559 | `skill_preflight_update "$task_number" "implement" "$session_id"` | Inside `blocker_escalation()` Step 5 — before re-dispatch |

**Postflight calls (Stage 5 handoff reading)**

| Line | Call | Context |
|------|------|---------|
| 391 | `skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"` | After research dispatch returns `researched` |
| 394 | `skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"` | After plan dispatch returns `planned` |
| 397 | `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"` | After implement dispatch returns `implemented` |

**Artifact linking (Stage 5 handoff reading)**

| Line | Call | Context |
|------|------|---------|
| 405 | `skill_link_artifact_from_handoff "$task_number" "$handoff"` | After postflight status update, links artifact from handoff |

#### Multi-Task Mode (Stages MT-3/MT-4)

**Preflight calls (Stage MT-4)**

| Line | Call | Context |
|------|------|---------|
| 917 | `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"` | Research dispatch loop |
| 942 | `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"` | Plan dispatch loop |
| 973 | `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"` | Implement dispatch loop |

**Postflight calls (Stage MT-4 — after parallel dispatch completes)**

| Line | Call | Context |
|------|------|---------|
| 1001 | `skill_postflight_update "$task_num" "research" "${session_id}_${task_num}" "$dispatch_status"` | After research handoff read |
| 1005 | `skill_postflight_update "$task_num" "plan" "${session_id}_${task_num}" "$dispatch_status"` | After plan handoff read |
| 1009 | `skill_postflight_update "$task_num" "implement" "${session_id}_${task_num}" "$dispatch_status"` | After implement handoff read |

**Artifact linking (Stage MT-4)**

| Line | Call | Context |
|------|------|---------|
| 1018 | `skill_link_artifact_from_handoff "$task_num" "$handoff"` | After per-task postflight |

---

### Exact Replacement Commands

#### Replacement for `skill_preflight_update "$task_number" "$op" "$session_id"`

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" "$op" "$session_id"
```

Examples from SKILL.md:
- Line 202: `bash .claude/scripts/update-task-status.sh preflight "$task_number" "research" "$session_id"`
- Line 231: `bash .claude/scripts/update-task-status.sh preflight "$task_number" "plan" "$session_id"`
- Line 261: `bash .claude/scripts/update-task-status.sh preflight "$task_number" "implement" "$session_id"`
- Line 294: `bash .claude/scripts/update-task-status.sh preflight "$task_number" "implement" "$session_id"`
- Line 559: `bash .claude/scripts/update-task-status.sh preflight "$task_number" "implement" "$session_id"`
- Line 917: `bash .claude/scripts/update-task-status.sh preflight "$task_num" "research" "${session_id}_${task_num}"`
- Line 942: `bash .claude/scripts/update-task-status.sh preflight "$task_num" "plan" "${session_id}_${task_num}"`
- Line 973: `bash .claude/scripts/update-task-status.sh preflight "$task_num" "implement" "${session_id}_${task_num}"`

#### Replacement for `skill_postflight_update "$task_number" "$op" "$session_id" "$dispatch_status"`

The function only calls the script for success statuses. Replicate that guard:

```bash
case "$dispatch_status" in
  researched|planned|revised|implemented)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$op" "$session_id"
    ;;
  *)
    echo "[orchestrate] Non-success status '$dispatch_status' — postflight skipped"
    ;;
esac
```

However, in Stage 5, the postflight calls are already inside a `case "$dispatch_status" in` block that only reaches them for the correct statuses. So the replacement can be simpler:

- Line 391: `bash .claude/scripts/update-task-status.sh postflight "$task_number" "research" "$session_id"`
- Line 394: `bash .claude/scripts/update-task-status.sh postflight "$task_number" "plan" "$session_id"`
- Line 397: `bash .claude/scripts/update-task-status.sh postflight "$task_number" "implement" "$session_id"`
- Line 1001: `bash .claude/scripts/update-task-status.sh postflight "$task_num" "research" "${session_id}_${task_num}"`
- Line 1005: `bash .claude/scripts/update-task-status.sh postflight "$task_num" "plan" "${session_id}_${task_num}"`
- Line 1009: `bash .claude/scripts/update-task-status.sh postflight "$task_num" "implement" "${session_id}_${task_num}"`

#### Replacement for `skill_link_artifact_from_handoff "$task_number" "$handoff"`

This requires inlining the full logic (type mapping + state.json update + link-artifact-todo.sh call). The handoff variable holds the JSON string.

```bash
# Inline skill_link_artifact_from_handoff
_handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
_handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
_handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')

if [ -n "$_handoff_artifact_path" ] && [ "$_handoff_artifact_path" != "null" ]; then
  case "$_handoff_artifact_type" in
    report)
      _field_name='**Research**'
      _next_field='**Plan**'
      ;;
    plan)
      _field_name='**Plan**'
      _next_field='**Description**'
      ;;
    summary|*)
      _field_name='**Summary**'
      _next_field='**Description**'
      ;;
  esac
  # Update state.json artifacts array (two-step, Issue #1132 safe)
  mkdir -p specs/tmp
  jq --arg atype "$_handoff_artifact_type" \
    '(.active_projects[] | select(.project_number == '"$task_number"')).artifacts =
      [(.active_projects[] | select(.project_number == '"$task_number"')).artifacts // [] | .[] | select(.type == $atype | not)]' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
  jq --arg path "$_handoff_artifact_path" \
     --arg type "$_handoff_artifact_type" \
     --arg summary "$_handoff_artifact_summary" \
    '(.active_projects[] | select(.project_number == '"$task_number"')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
  # Link in TODO.md
  bash .claude/scripts/link-artifact-todo.sh "$task_number" "$_field_name" "$_next_field" "$_handoff_artifact_path" 2>/dev/null || \
    echo "WARNING: link-artifact-todo.sh exited non-zero (non-blocking)"
fi
```

For multi-task mode (line 1018), replace `$task_number` with `$task_num` and `$handoff` with `$handoff` (same variable name is already used there).

---

## Decisions

- Replace all function-call pseudocode with direct bash invocations inline in SKILL.md code blocks.
- Do NOT add a `source .claude/scripts/skill-base.sh` line to SKILL.md as the fix. While this would technically work for function calls, it creates a fragile dependency on shell state across agent-interpreted code blocks and would require the agent to understand sourcing semantics.
- The inline `skill_link_artifact_from_handoff` replacement must include the `specs/tmp` mkdir guard since `skill_link_artifacts` in skill-base.sh uses `specs/tmp/state.json` as a temp file.
- The jq two-step pattern (remove then add) for `state.json` artifact linking must use the `select(.type == $atype | not)` form to avoid Issue #1132.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SKILL.md is long (1130 lines); edits must be surgical | Use exact line numbers; verify old_string is unique before editing |
| `specs/tmp/` directory may not exist | Add `mkdir -p specs/tmp` before jq two-step in artifact linking block |
| Multi-task session IDs use `${session_id}_${task_num}` format | Preserve this distinction in replacement calls |
| Blocker escalation (line 559) is inside a bash function definition block | Replacement is identical to other preflight calls; no special handling needed |

---

## Appendix

### Search Approach
- Read SKILL.md in full (1130 lines) to catalog all function references
- Read skill-base.sh in full (517 lines) to understand function implementations
- Read update-task-status.sh header (80 lines) for CLI interface
- Read link-artifact-todo.sh header (80 lines) for CLI interface

### Summary Count
| Function | Single-task | Multi-task | Total |
|----------|-------------|------------|-------|
| `skill_preflight_update` | 5 | 3 | 8 |
| `skill_postflight_update` | 3 | 3 | 6 |
| `skill_link_artifact_from_handoff` | 1 | 1 | 2 |
| **Total** | **9** | **7** | **16** |
