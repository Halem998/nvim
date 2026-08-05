#!/usr/bin/env bash
# skill-base.sh — Shared skill lifecycle functions
#
# SOURCING SEMANTICS:
#   This file must be sourced within the SAME Bash tool invocation as function calls.
#   Exported variables do NOT persist across separate Bash invocations in Claude Code.
#   Pattern: source this file, then call functions, all within one bash block.
#
#   Example usage in a SKILL.md bash block:
#     source .claude/scripts/skill-base.sh
#     skill_validate_input "$task_number"
#     skill_preflight_update "$task_number" "research" "$session_id"
#
# VARIABLE EXPORTS:
#   skill_validate_input  -> TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM, TASK_DIR
#   skill_read_artifact_number -> ARTIFACT_NUMBER, ARTIFACT_PADDED
#   skill_read_metadata   -> SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES
#
# CONTEXT BUDGET DEFAULTS (overridable by tier enforcement):
#   SKILL_CONTEXT_BUDGET defaults to 8000 (sonnet workers) or 15000 (opus planners).
#   Override before sourcing: SKILL_CONTEXT_BUDGET=15000 source skill-base.sh
SKILL_CONTEXT_BUDGET="${SKILL_CONTEXT_BUDGET:-8000}"

# ─────────────────────────────────────────────────────────────────────────────
# REPO ROOT ANCHOR
# This file is deployed at <repo-root>/.claude/scripts/skill-base.sh, so the repo root is two
# directories up from this file's own location. Resolving from BASH_SOURCE — rather than from
# the ambient working directory or `git rev-parse --show-toplevel` — keeps paths built below
# correct no matter where the caller's shell happens to be, and stays correct inside git
# worktrees and nested repos where `git rev-parse` answers a different question.
# Override only in tests.
SKILL_REPO_ROOT="${SKILL_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export SKILL_REPO_ROOT

# ─────────────────────────────────────────────────────────────────────────────
# EXTENSION HOOKS: Lifecycle hook invocation for loaded extensions.
#
# Extensions may declare hook scripts in manifest.json under a top-level
# "hooks" object (distinct from "provides.hooks" which are file-copy targets):
#
#   "hooks": {
#     "preflight": "scripts/my-preflight.sh",
#     "context_injection": "scripts/my-context.sh",
#     "verification": "scripts/my-verify.sh",
#     "postflight": "scripts/my-postflight.sh"
#   }
#
# Hook scripts are called with 5 positional args:
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation
#
# Missing hook keys or absent extensions.json are silently skipped.
# ─────────────────────────────────────────────────────────────────────────────

# skill_get_extension_dir: Map task_type to extension directory via extensions.json
# Usage: skill_get_extension_dir "$task_type"
# Outputs: absolute path to extension directory, or empty string if not found
skill_get_extension_dir() {
  local task_type="$1"
  # Extension selection manifest lives at the PROJECT ROOT (not inside .claude/)
  # so it survives a .claude/ wipe -- preset-scoped filename for Claude Code.
  local extensions_json=".claude-extensions.json"
  if [ ! -f "$extensions_json" ]; then
    return 0
  fi
  # Find extension with matching task_type
  local ext_name
  ext_name=$(jq -r --arg tt "$task_type" \
    '.loaded_extensions // [] | .[] | select(.task_type == $tt) | .name' \
    "$extensions_json" 2>/dev/null | head -1)
  if [ -z "$ext_name" ] || [ "$ext_name" = "null" ]; then
    return 0
  fi
  echo ".claude/extensions/${ext_name}"
}

# skill_run_extension_hook: Execute a lifecycle hook for the current task_type
# Usage: skill_run_extension_hook "$hook_name" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"
# hook_name: preflight | context_injection | verification | postflight
# Silently skips if: extensions.json missing, extension not loaded, hook not declared, script not found
skill_run_extension_hook() {
  local hook_name="$1"
  local task_number="$2"
  local task_type="$3"
  local task_dir="$4"
  local session_id="$5"
  local operation="$6"

  local ext_dir
  ext_dir=$(skill_get_extension_dir "$task_type")
  if [ -z "$ext_dir" ]; then
    return 0
  fi

  local manifest="${ext_dir}/manifest.json"
  if [ ! -f "$manifest" ]; then
    return 0
  fi

  local hook_script
  hook_script=$(jq -r --arg h "$hook_name" '.hooks[$h] // empty' "$manifest" 2>/dev/null)
  if [ -z "$hook_script" ]; then
    return 0
  fi

  local hook_path="${ext_dir}/${hook_script}"
  if [ ! -x "$hook_path" ]; then
    return 0
  fi

  echo "[skill-base] Running extension hook: ${hook_name} (${hook_path})"
  "$hook_path" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation" || \
    echo "[skill-base] WARNING: Extension hook '${hook_name}' exited non-zero (non-blocking)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Observable-but-non-fatal wrapper around events-append.sh.
#
# Replaces the bare `bash .claude/scripts/events-append.sh ... || true` idiom, which failed
# SILENTLY when the helper was missing -- the defect that hid the events store's non-deployment
# for a full day. This wrapper ALWAYS returns 0 to its caller (a missing/failing events helper
# must never become fatal to the enclosing skill lifecycle stage), but distinguishes "helper
# missing/not executable" from "helper present but exited non-zero" in both a one-time-per-process
# stderr WARNING and a durable sentinel marker under .claude/tmp/, so the failure is surfaceable
# instead of silently swallowed.
#
# Usage: _events_append_observable ".claude/scripts/events-append.sh" --event-type ... [args...]
_EVENTS_APPEND_OBSERVABLE_WARNED=""
_events_append_observable() {
  local helper_path="$1"
  shift
  local kind="" exit_code=""
  if [ ! -x "$helper_path" ]; then
    kind="missing"
  else
    if "$helper_path" "$@" >/dev/null 2>&1; then
      exit_code=0
    else
      exit_code=$?
      kind="failed"
    fi
  fi
  if [ -n "$kind" ]; then
    if [ -z "$_EVENTS_APPEND_OBSERVABLE_WARNED" ]; then
      if [ "$kind" = "missing" ]; then
        echo "[skill-base] WARNING: events-append.sh helper missing or not executable at ${helper_path} (non-blocking)" >&2
      else
        echo "[skill-base] WARNING: events-append.sh helper present but failed (exit ${exit_code}) at ${helper_path} (non-blocking)" >&2
      fi
      _EVENTS_APPEND_OBSERVABLE_WARNED=1
    fi
    mkdir -p ".claude/tmp" 2>/dev/null
    printf '{"kind":"%s","helper_path":"%s","exit_code":"%s","ts":"%s"}\n' \
      "$kind" "$helper_path" "$exit_code" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      >> ".claude/tmp/events-append-observable.log" 2>/dev/null
  fi
  return 0
}

# ORCHESTRATOR MODE: Support for skill-orchestrate dispatch.
# .orchestrator-handoff.json is a hard-mode-implement-only artifact: only the hard-mode
# implementation agent writes it (via the Write tool, per context/contracts/wrap-up.md's H9
# contract). Base-mode research/plan/implement return via .return-meta.json, recovered by
# orchestrate-recover-outcome.sh. Research agents never write a handoff at all.
# See: .claude/docs/architecture/handoff-schema.md and
# .claude/context/schemas/orchestrator-handoff-schema.json

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Validate input task number
# Usage: skill_validate_input "$task_number"
# Exports: TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM, TASK_DIR
# Exit 1 if task not found or in terminal state
skill_validate_input() {
  local task_number="$1"
  PADDED_NUM=$(printf "%03d" "$task_number")
  TASK_DATA=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)
  if [ -z "$TASK_DATA" ]; then
    echo "ERROR: Task $task_number not found in state.json" >&2
    exit 1
  fi
  TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.task_type // "general"')
  TASK_STATUS=$(echo "$TASK_DATA" | jq -r '.status')
  PROJECT_NAME=$(echo "$TASK_DATA" | jq -r '.project_name')
  DESCRIPTION=$(echo "$TASK_DATA" | jq -r '.description // ""')
  TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
  # Absolute companion to TASK_DIR. TASK_DIR stays relative because many existing consumers
  # depend on its relative form; TASK_DIR_ABS is the anchor to hand to dispatched agents and
  # to build write destinations from.
  TASK_DIR_ABS="${SKILL_REPO_ROOT}/${TASK_DIR}"
  # Block terminal states
  if [ "$TASK_STATUS" = "completed" ] || [ "$TASK_STATUS" = "abandoned" ] || [ "$TASK_STATUS" = "expanded" ]; then
    echo "ERROR: Task $task_number is in terminal state [$TASK_STATUS]" >&2
    exit 1
  fi
  export TASK_DATA TASK_TYPE TASK_STATUS PROJECT_NAME DESCRIPTION PADDED_NUM TASK_DIR TASK_DIR_ABS
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Update status to in-progress variant
# Usage: skill_preflight_update "$task_number" "$operation" "$session_id"
# operation: "research" | "plan" | "implement" | "revise"
# Calls extension hook: hooks.preflight (after status update)
skill_preflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local _t0
  _t0=$(date +%s.%N)
  bash .claude/scripts/update-task-status.sh preflight "$task_number" "$operation" "$session_id"
  # Extension hook: preflight (runs after status update)
  skill_run_extension_hook "preflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  # Unified event store: one non-blocking milestone event per lifecycle stage
  local _dur
  _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type lifecycle_stage --category milestone \
    --checkpoint preflight --duration "$_dur" --task "$task_number" --session "$session_id" \
    --message "Preflight stage completed for ${operation}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: Create postflight-pending marker file
# Usage: skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
skill_create_postflight_marker() {
  local padded_num="$1"
  local project_name="$2"
  local session_id="$3"
  local skill_name="$4"
  local operation="$5"
  local task_dir="specs/${padded_num}_${project_name}"
  mkdir -p "$task_dir"
  cat > "${task_dir}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "${skill_name}",
  "operation": "${operation}",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 4: Extension context injection (hook invocation only)
# Usage: skill_context_injection "$task_number" "$session_id" "$operation"
# Calls extension hook: hooks.context_injection
# This function provides a call site for extensions to inject domain-specific
# context before agent delegation. The hook receives task metadata via positional args.
skill_context_injection() {
  local task_number="$1"
  local session_id="$2"
  local operation="${3:-research}"
  local _t0
  _t0=$(date +%s.%N)
  skill_run_extension_hook "context_injection" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  # Unified event store: one non-blocking milestone event per lifecycle stage
  local _dur
  _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type lifecycle_stage --category milestone \
    --checkpoint context_injection --duration "$_dur" --task "$task_number" --session "$session_id" \
    --message "Context injection stage completed for ${operation}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3a: Read artifact number for this task
# Usage: skill_read_artifact_number "$task_number" "$padded_num" "$project_name" "$artifact_dir" "$mode"
# mode: "current" (researcher: use next_artifact_number as-is)
#        "prev"    (planner/implementer: use next_artifact_number - 1)
# Exports: ARTIFACT_NUMBER, ARTIFACT_PADDED
skill_read_artifact_number() {
  local task_number="$1"
  local padded_num="$2"
  local project_name="$3"
  local artifact_dir="$4"  # "reports/" | "plans/" | "summaries/"
  local mode="${5:-prev}"
  local next_num
  next_num=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
    specs/state.json)
  if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
    # Legacy fallback: count existing artifacts in directory
    local count
    count=$(ls "specs/${padded_num}_${project_name}/${artifact_dir}"*[0-9][0-9]*.md 2>/dev/null | wc -l)
    ARTIFACT_NUMBER=$((count + 1))
  elif [ "$mode" = "current" ]; then
    ARTIFACT_NUMBER="$next_num"
  else
    # mode = "prev": planner/implementer share the same round as preceding research
    if [ "$next_num" -le 1 ]; then
      ARTIFACT_NUMBER=1
    else
      ARTIFACT_NUMBER=$((next_num - 1))
    fi
  fi
  ARTIFACT_PADDED=$(printf "%02d" "$ARTIFACT_NUMBER")
  export ARTIFACT_NUMBER ARTIFACT_PADDED
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6: Read agent metadata file
# Usage: skill_read_metadata "$padded_num" "$project_name"
# Exports: SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES
skill_read_metadata() {
  local padded_num="$1"
  local project_name="$2"
  local meta_file="specs/${padded_num}_${project_name}/.return-meta.json"
  if [ ! -f "$meta_file" ] || ! jq empty "$meta_file" 2>/dev/null; then
    echo "Error: Invalid or missing metadata file: $meta_file" >&2
    SUBAGENT_STATUS="failed"
    ARTIFACT_PATH=""
    ARTIFACT_TYPE=""
    ARTIFACT_SUMMARY="Agent did not write metadata"
    MEMORY_CANDIDATES="[]"
  else
    SUBAGENT_STATUS=$(jq -r '.status' "$meta_file")
    ARTIFACT_PATH=$(jq -r '.artifacts[0].path // ""' "$meta_file")
    ARTIFACT_TYPE=$(jq -r '.artifacts[0].type // ""' "$meta_file")
    ARTIFACT_SUMMARY=$(jq -r '.artifacts[0].summary // ""' "$meta_file")
    MEMORY_CANDIDATES=$(jq -c '.memory_candidates // []' "$meta_file")
  fi
  export SUBAGENT_STATUS ARTIFACT_PATH ARTIFACT_TYPE ARTIFACT_SUMMARY MEMORY_CANDIDATES
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 6a: Validate artifact exists and meets format requirements (non-blocking)
# Usage: skill_validate_artifact "$status" "$artifact_path" "$artifact_kind" ["$task_number" "$session_id" "$operation"]
# artifact_kind: "report" | "plan" | "summary"
# Validation only runs when status matches a success state
# Calls extension hook: hooks.verification (after artifact validation)
skill_validate_artifact() {
  local status="$1"
  local artifact_path="$2"
  local artifact_kind="$3"
  local task_number="${4:-}"
  local session_id="${5:-}"
  local operation="${6:-}"
  local _t0
  _t0=$(date +%s.%N)
  if [ "$status" != "failed" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating ${artifact_kind} artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" "$artifact_kind" --fix 2>/dev/null; then
      echo "WARNING: ${artifact_kind} artifact has format issues (non-blocking). Review output above."
    fi
  fi
  # Extension hook: verification (runs after artifact validation, non-blocking)
  if [ -n "$task_number" ]; then
    skill_run_extension_hook "verification" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  fi
  # Unified event store: one non-blocking event per lifecycle stage.
  # category is discriminated by status: a failed/blocked/partial verification is a
  # deviation from the plan, not a clean milestone.
  if [ -n "$task_number" ]; then
    local _dur _category
    _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
    case "$status" in
      failed|blocked|partial) _category="deviation" ;;
      *) _category="milestone" ;;
    esac
    _events_append_observable ".claude/scripts/events-append.sh" \
      --event-type lifecycle_stage --category "$_category" \
      --checkpoint verification --duration "$_dur" --task "$task_number" --session "$session_id" \
      --message "Verification stage completed for ${artifact_kind} (status: ${status})"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Validate every artifact in a task directory against its correct per-file type
# Usage: skill_validate_task_artifacts "$task_dir"
# Non-blocking directory-wide sweep, distinct from skill_validate_artifact above (which
# validates exactly one known (path, kind) pair). validate-artifact.sh takes exactly one file
# and one type per invocation, so a whole-directory sweep needs its own abstraction — centralizing
# it here is what keeps the per-file-type convention (reports/*.md -> report, plans/*.md -> plan,
# summaries/*.md -> summary) from drifting again at future call sites.
skill_validate_task_artifacts() {
  local task_dir="$1"
  local subdir type f
  for pair in "reports:report" "plans:plan" "summaries:summary"; do
    subdir="${pair%%:*}"
    type="${pair##*:}"
    for f in "$task_dir"/"$subdir"/*.md; do
      [ -e "$f" ] || continue
      echo "Validating ${type} artifact: ${f}"
      if ! bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null; then
        echo "WARNING: ${type} artifact ${f} has format issues (non-blocking). Review output above." >&2
      fi
    done
  done
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7: Update status to completed variant
# Usage: skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
# Only updates state when status is a success value (researched/planned/implemented)
# Calls extension hook: hooks.postflight (after status update, non-blocking)
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  # Optional 5th argument: phase-check mode ("warn" or "refuse"), forwarded to
  # update-task-status.sh's opt-in phase-accounting backstop. ABSENT is the default for every
  # existing caller and means the flag is not passed at all, preserving today's exact behavior
  # byte-for-byte. The empty-array expansion pattern below is the same one already used by
  # reconcile-task-status.sh's dry_run_flag=() handling.
  local phase_check_mode="${5:-}"
  local phase_check_args=()
  if [[ -n "$phase_check_mode" ]]; then
    phase_check_args=(--phase-check="$phase_check_mode")
  fi
  local _t0
  _t0=$(date +%s.%N)
  case "$status" in
    researched|planned|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id" "${phase_check_args[@]}"
      ;;
    *)
      echo "[skill-base] Non-success status '${status}' — postflight status update skipped"
      ;;
  esac
  # Extension hook: postflight (runs after status update, non-blocking)
  skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  # Unified event store: one non-blocking milestone event per lifecycle stage
  local _dur
  _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  _events_append_observable ".claude/scripts/events-append.sh" \
    --event-type lifecycle_stage --category milestone \
    --checkpoint postflight --duration "$_dur" --task "$task_number" --session "$session_id" \
    --message "Postflight stage completed for ${operation} (status: ${status})"
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 7b: Propagate completion_summary + roadmap_items to state.json
# Usage: skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type" ["$session_id"]
#
# Single shared implementation of the guarded completion-data write, replacing what were
# previously three independently-maintained copies (skill-implementer, skill-implementer-hard,
# and the orphaned orchestrator-postflight.sh Stage 7b). Every caller — the plain /implement
# producer path AND all four /orchestrate paths (base single-task, base multi-task Stage MT-4,
# hard single-task, hard multi-task via inherited MT-4) — converges on this one function.
#
# Guard semantics (unchanged from the prior three copies):
#   - completion_summary is written only when non-empty.
#   - roadmap_items is written only when task_type is not "meta" AND the value is neither
#     empty nor the literal string "[]".
#
# Routes both writes through state-write.sh, the single mutex-guarded specs/state.json writer
# (${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh -- the SKILL_REPO_ROOT-qualified path, not a
# relative one, so this function keeps working when invoked from a fixture repo via
# SKILL_REPO_ROOT override, exactly like the generate-todo.sh call in skill_link_artifacts
# below). Still uses jq --arg/--argjson exclusively (never shell-interpolated Python string
# literals), so arbitrary prose in a summary — quotes, newlines, triple-quotes, backslashes —
# cannot break the write.
#
# session_id (5th arg, optional) attributes the specs/.scope-lock mutex acquisition. When
# invoked from inside an outer SCOPE_MUTEX_HELD=1 critical section (e.g.
# orchestrator-postflight.sh's Stage 7-8a bracket, this function's normal calling context),
# state-write.sh runs as a guest and never attempts a nested acquire regardless of which
# session_id is passed. If omitted, a session_id is generated inline using the same portable
# pattern command-gate-in.sh uses, so every existing caller keeps working unchanged.
skill_propagate_completion_summary() {
  local task_number="$1"
  local completion_summary="$2"
  local roadmap_items="$3"
  local task_type="$4"
  local session_id="${5:-}"
  if [ -z "$session_id" ]; then
    session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
  fi
  if [ -n "$completion_summary" ]; then
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).completion_summary = $summary' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg summary "$completion_summary" \
      || echo "WARNING: state-write.sh failed to write completion_summary (non-blocking)" >&2
  fi
  if [ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).roadmap_items = $items' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --argjson items "$roadmap_items" \
      || echo "WARNING: state-write.sh failed to write roadmap_items (non-blocking)" >&2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 8: Link artifacts to state.json and TODO.md
# Usage: skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" "$field_name" "$next_field" ["$session_id"]
# artifact_type: "research" | "plan" | "summary"
# field_name:   '**Research**' | '**Plan**' | '**Summary**'
# next_field:   '**Plan**' (research) | '**Description**' (plan/summary)
# Uses two-step jq pattern to avoid Issue #1132 (!=  escaping bug), both steps routed through
# state-write.sh -- see skill_propagate_completion_summary's header comment above for the full
# SKILL_REPO_ROOT-qualified-path and session_id/self-generation rationale, identical here.
skill_link_artifacts() {
  local task_number="$1"
  local artifact_path="$2"
  local artifact_type="$3"
  local artifact_summary="$4"
  local field_name="${5:-'**Summary**'}"
  local next_field="${6:-'**Description**'}"
  local session_id="${7:-}"
  if [ -z "$session_id" ]; then
    session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
  fi
  if [ -n "$artifact_path" ]; then
    # Step 1: Remove existing artifacts of same type (use "| not" pattern — Issue #1132 safe)
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == $atype | not)]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg atype "$artifact_type" \
      || echo "WARNING: state-write.sh failed removing same-type artifacts (non-blocking)" >&2
    # Step 2: Add new artifact entry
    "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg path "$artifact_path" \
      --arg type "$artifact_type" \
      --arg summary "$artifact_summary" \
      || echo "WARNING: state-write.sh failed adding artifact entry (non-blocking)" >&2
    # Regenerate TODO.md from state.json (replaces link-artifact-todo.sh call)
    bash "${SKILL_REPO_ROOT}/.claude/scripts/generate-todo.sh" || echo "WARNING: generate-todo.sh failed (non-fatal)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage 9/10: Cleanup temporary files
# Usage: skill_cleanup "$padded_num" "$project_name"
# Removes .postflight-pending, .postflight-loop-guard, .return-meta.json
# Note: Implementer also removes .continuation-loop-guard inline (after calling this)
skill_cleanup() {
  local padded_num="$1"
  local project_name="$2"
  local task_dir="specs/${padded_num}_${project_name}"
  rm -f "${task_dir}/.postflight-pending" \
        "${task_dir}/.postflight-loop-guard" \
        "${task_dir}/.return-meta.json" 2>/dev/null || true
}

# ───────────────────────────────────────────────────────────────────────────
# Completion-claim verification gate
# Usage: skill_gate_completion_claim "$task_number" "$phases_completed" \
#          "$phases_total" "$plan_markers_verified" "$log_prefix"
#
#   $1 = task_number            : task number, named in every log line
#   $2 = phases_completed       : integer from the handoff's TOP-LEVEL field (jq '// 0')
#   $3 = phases_total           : integer from the handoff's TOP-LEVEL field (jq '// 0')
#   $4 = plan_markers_verified  : "true" | "false" | "absent" (jq '// "absent"')
#   $5 = log_prefix             : "[orchestrate]" or "[hard-orchestrate]"
#
# Returns 0 = ALLOW the completed transition; 1 = REFUSE it. On a refuse the caller MUST skip
# skill_postflight_update entirely, leave the task at `implementing`, and let the surrounding
# cycle counter increment as usual, so the next cycle re-dispatches implement and the existing
# MAX_CYCLES / MAX_CYCLES_MT caps bound the retry.
#
# All evidence is read from fields the caller already parsed out of
# .orchestrator-handoff.json. This function never reads a plan file, report, or summary, and
# never invokes the Stage 5 phase-marker recovery grep — that exception is scoped to the
# missing/stale-handoff branch and this gate fires only when a handoff IS present and fresh.
#
# This unification is a deliberate behavior change from the two inline gates it replaces:
#   - base mode LOSES its `phases_total == 0` blind allow (it used to unconditionally allow
#     completion when phase accounting was absent; it now requires plan_markers_verified=true).
#   - hard mode LOSES its `phases_total == 0` blind refuse (it used to unconditionally refuse
#     when phase accounting was absent; it now allows on plan_markers_verified=true).
#   Both are replaced by the single corroborated Case 3 fallback below.
#
# This function is the ONLY place the three-case logic may live. Inlining a copy at a call site
# is the drift this refactor exists to prevent — call this function from every site instead.
skill_gate_completion_claim() {
  local task_number="$1"
  local phases_completed="$2"
  local phases_total="$3"
  local plan_markers_verified="$4"
  local log_prefix="$5"

  # Sanitize: a non-integer is missing evidence, not an arithmetic error. Coerce to 0 so it
  # always falls through to Case 3 (fail closed) rather than crashing `-ge`/`-gt` under `set -e`.
  [[ "$phases_completed" =~ ^[0-9]+$ ]] || phases_completed=0
  [[ "$phases_total" =~ ^[0-9]+$ ]] || phases_total=0

  if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
    # Case 2: phase accounting present and complete — the only unconditional allow.
    echo "${log_prefix} COMPLETION-CLAIM GATE case 2/3 (phase accounting present and complete) task ${task_number}: ${phases_completed}/${phases_total} — allowing completion." >&2
    return 0
  fi

  if [ "$phases_total" -gt 0 ]; then
    # Case 1: phase accounting present but incomplete — always refuse.
    echo "${log_prefix} COMPLETION-CLAIM GATE case 1/3 (phase accounting present, incomplete) task ${task_number}: ${phases_completed}/${phases_total} — refusing completion; task stays implementing." >&2
    return 1
  fi

  # Case 3: phases_total == 0, i.e. accounting absent or malformed. Fall back to the
  # corroborating plan_markers_verified signal.
  if [ "$plan_markers_verified" = "true" ]; then
    echo "${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=true) task ${task_number}: allowing completion on the corroborating marker signal." >&2
    return 0
  fi

  echo "${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=${plan_markers_verified}) task ${task_number}: refusing completion — handoff-writer defect suspected; task stays implementing." >&2
  return 1
}

# ───────────────────────────────────────────────────────────────────────────
# Shared plan-heading corroboration
# Usage: skill_corroborate_phase_counts "$task_number" "$plan_path" "$log_prefix" ["$handoff_path"]
#
#   $1 = task_number   : task number, named in every log line
#   $2 = plan_path     : path to the plan file to corroborate against (may be empty)
#   $3 = log_prefix    : "[orchestrate]" or "[hard-orchestrate]"
#   $4 = handoff_path  : OPTIONAL. When non-empty and the file exists, validate-handoff.sh is
#                        invoked against it as a log-only, non-gating producer-defect diagnostic
#                        (D5/B1 below). Its exit status never influences this function's own
#                        return value. Pass an EMPTY string on the recovery-path call sites
#                        (Phase 7 of the plan that introduced this function) — there is no
#                        handoff to validate on that path.
#
# Prints exactly one line on stdout, shell-assignable via `read` (callers MUST NOT `eval` it):
#   phases_completed=<int> phases_total=<int> plan_markers_verified=<true|absent>
#
# Returns 0 when corroborated (plan_markers_verified=true), 1 otherwise — including the
# non-conforming-heading case and the no-plan-file case. Both are "not corroborated", never a
# crash.
#
# This is a faithful lift of the three-way branch that used to live inline, once per engine, in
# the recovered=true branch of skill-orchestrate/SKILL.md Stage 5 (and its Stage MT-4 step 1 and
# skill-orchestrate-hard/SKILL.md Stage 5 mirrors) — this function changes WHERE the logic lives,
# never the branch outcomes. All three recovery-path call sites were migrated to call this
# function rather than keep their own copy; see each SKILL.md's Stage 5 / Stage MT-4 for the
# call sites, and the "Evidence corroboration" comment they each still carry.
#
# ── D3 (deliberate divergence): trigger precondition is `phases_total -eq 0` ALONE ──────────────
# This differs on purpose from the recovery path's `PHASES_ZERO_ON_SUCCESS` signature, which
# requires BOTH counts to be zero. This function's sole consumer is skill_gate_completion_claim's
# Case 3 above, whose own precondition is `phases_total == 0` and which ignores
# phases_completed entirely once that holds. Matching the consumer's precondition exactly means
# the trigger and the gate cannot drift apart; matching the recovery path's both-zero signature
# instead would leave a real gap — a handoff with phases_completed=7, phases_total=null would
# take Case 3, be refused, and never get a chance at corroboration. This function does not
# re-derive the `phases_total -eq 0` precondition internally: each caller gates on it BEFORE
# invoking this function (see the handoff-present branch of Stage 5 / Stage MT-4 in both
# SKILL.md files for the call-site precondition). This asymmetry is deliberate design, recorded
# here in the same "this is a DESIGN, not an undocumented assertion" style the multi-task
# `blocked`-row divergence in skill-orchestrate/SKILL.md uses.
#
# ── D4 (structural, not a promise): the completion gate is never weakened ────────────────────────
# This function writes only phases_completed / phases_total / plan_markers_verified, and only
# from an INDEPENDENT artifact (the plan file's own headings) — never from the handoff's own
# values. skill_gate_completion_claim's Case 1 (phase accounting present and incomplete -> always
# refuse) is UNREACHABLE from any caller of this function by construction: every caller only
# invokes this function when phases_total is already 0 (see D3 above), and Case 1 requires
# phases_total > 0. A corroborated correction therefore never overrides a refusal — it only
# supplies independent evidence where the handoff supplied none.
skill_corroborate_phase_counts() {
  local task_number="$1"
  local plan_path="$2"
  local log_prefix="$3"
  local handoff_path="${4:-}"

  # Deploy-tree-first / source-store-fallback candidate resolution, matching
  # scripts/tests/test-phase-heading-patterns.sh's own resolution so this function works both
  # post-deploy (.claude/scripts/lib/...) and in a source-store-only checkout
  # (agent-system/extensions/core/scripts/lib/...).
  local _cpc_lib_candidates=(
    ".claude/scripts/lib/phase-heading-patterns.sh"
    "$(dirname "${BASH_SOURCE[0]}")/lib/phase-heading-patterns.sh"
  )
  local _cpc_lib=""
  local _cpc_candidate
  for _cpc_candidate in "${_cpc_lib_candidates[@]}"; do
    if [ -f "$_cpc_candidate" ]; then
      _cpc_lib="$_cpc_candidate"
      break
    fi
  done
  if [ -z "$_cpc_lib" ]; then
    echo "${log_prefix} Evidence corroboration: phase-heading-patterns.sh not found at any candidate path for task ${task_number} — leaving plan_markers_verified=absent." >&2
    echo "phases_completed=0 phases_total=0 plan_markers_verified=absent"
    return 1
  fi
  # shellcheck disable=SC1090
  . "$_cpc_lib"

  # Never treat a missing/empty plan path as corroboration.
  if [ -z "$plan_path" ] || [ ! -f "$plan_path" ]; then
    echo "${log_prefix} Evidence corroboration: no plan file found to corroborate against for task ${task_number} — leaving plan_markers_verified=absent." >&2
    echo "phases_completed=0 phases_total=0 plan_markers_verified=absent"
    return 1
  fi

  # `x=$(grep -c ...) || x=0` idiom, never `$(grep -c ... || echo 0)` — the latter emits two
  # lines on zero matches.
  local _cpc_total _cpc_completed
  _cpc_total=$(grep -cE "$PHASE_HEADING_ERE" "$plan_path" 2>/dev/null) || _cpc_total=0
  _cpc_completed=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$plan_path" 2>/dev/null) || _cpc_completed=0

  local _cpc_rc=1
  local _cpc_out_completed=0
  local _cpc_out_total=0
  local _cpc_out_verified="absent"

  if has_nonconforming_phase_headings "$plan_path"; then
    warn_nonconforming "$plan_path" "corroborate-phase-counts" || true
    echo "${log_prefix} Evidence corroboration: non-conforming phase heading(s) in ${plan_path} — counts unreliable; leaving plan_markers_verified=absent." >&2
    _cpc_rc=1
  elif [ "$_cpc_total" -gt 0 ] && [ "$_cpc_completed" -eq "$_cpc_total" ]; then
    _cpc_out_completed="$_cpc_completed"
    _cpc_out_total="$_cpc_total"
    _cpc_out_verified="true"
    echo "[UNVERIFIED PHASES CORROBORATED] task ${task_number}: plan headings in ${plan_path} show ${_cpc_completed}/${_cpc_total} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS). Corroborated by an independent source — correcting phase counts and setting plan_markers_verified=true." >&2
    _cpc_rc=0
  else
    # False-positive guard: no contradiction to resolve (a plan with zero phase headings, or a
    # genuine partial-completion plan). Leave plan_markers_verified=absent and the counts at 0/0
    # — do not treat this as a second trigger.
    echo "${log_prefix} Evidence corroboration: non-corroborating (plan headings show ${_cpc_completed}/${_cpc_total} in ${plan_path}) — leaving plan_markers_verified=absent." >&2
    _cpc_rc=1
  fi

  if [ -n "$handoff_path" ] && [ -f "$handoff_path" ]; then
    # Log-only, non-gating producer-defect diagnostic (D5/B1). Never allowed to influence this
    # function's own return value — guarded with `|| true` because validate-handoff.sh runs under
    # `set -euo pipefail` and exits non-zero on any failed check.
    bash .claude/scripts/validate-handoff.sh "$handoff_path" >&2 || true
  fi

  echo "phases_completed=${_cpc_out_completed} phases_total=${_cpc_out_total} plan_markers_verified=${_cpc_out_verified}"
  return "$_cpc_rc"
}
