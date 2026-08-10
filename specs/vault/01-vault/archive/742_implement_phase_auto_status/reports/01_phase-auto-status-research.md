# Research Report: Task #742

**Task**: 742 - Auto-update plan phase status on implement preflight
**Started**: 2026-06-17T00:00:00Z
**Completed**: 2026-06-17T00:05:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (update-task-status.sh, update-phase-status.sh, skill-implementer/SKILL.md, update-plan-status.sh, skill-base.sh)
**Artifacts**: specs/742_implement_phase_auto_status/reports/01_phase-auto-status-research.md
**Standards**: report-format.md

## Executive Summary

- `update-phase-status.sh` exists and is fully functional but is never called by any script in the pipeline
- The integration point is `update_plan_file()` in `update-task-status.sh` (lines 198-237), which already handles the `preflight:implement` operation
- The call must find the first `[NOT STARTED]` phase in the plan file by scanning phase headings, then call `update-phase-status.sh` with phase number 1 (or the discovered phase number) and status `IN_PROGRESS`
- The call must be non-fatal (matching the existing `update-plan-status.sh` pattern) and guarded against tasks with no plan file

## Context & Scope

Task 742 asks to extend `update_plan_file()` in `.claude/scripts/update-task-status.sh` so that when `operation == preflight` and `target_status == implement`, the first `[NOT STARTED]` phase in the plan file is automatically marked `[IN PROGRESS]` via `update-phase-status.sh`.

## Findings

### Codebase Patterns

#### update-task-status.sh — `update_plan_file()` (lines 198-237)

The function signature and structure:

```bash
update_plan_file() {
  # Guard: only runs for implement operations
  if [[ "$target_status" != "implement" ]]; then
    return 0
  fi

  local plan_status
  case "$operation" in
    preflight)  plan_status="IMPLEMENTING" ;;
    postflight) plan_status="COMPLETED" ;;
  esac

  # Look up project_name from state.json (already-updated file)
  local project_name
  project_name=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
    "$STATE_FILE")

  # ... null-guard ...

  local plan_script="$SCRIPT_DIR/update-plan-status.sh"
  # ... executable-guard ...

  # Non-fatal call
  cd "$PROJECT_ROOT"
  "$plan_script" "$task_number" "$project_name" "$plan_status" 2>/dev/null || {
    echo "Warning: plan file update failed (non-fatal)" >&2
  }
}
```

Key observations:
1. `$target_status`, `$operation`, `$task_number`, `$SCRIPT_DIR`, `$PROJECT_ROOT`, and `$STATE_FILE` are all in scope as script-level variables
2. `$project_name` is resolved inside the function from `$STATE_FILE` — this is available for reuse
3. The `preflight` branch already sets `plan_status="IMPLEMENTING"` — this is exactly when phase 1 should become `[IN PROGRESS]`
4. The existing call to `update-plan-status.sh` happens at the bottom of the function — the phase update should be added **after** the plan-level status update (same non-fatal pattern)

#### update-phase-status.sh — Signature

```bash
# Usage: .claude/scripts/update-phase-status.sh TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS
# NEW_STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, PARTIAL, BLOCKED
```

The script:
- Resolves the plan directory itself (padded + unpadded fallback) — does **not** need the caller to pass a plan path
- Finds the latest plan file with `ls -t "$plan_dir"/*.md | head -1`
- Finds `### Phase N:` headings by grep
- Is idempotent: exits 0 silently if already at target status
- Returns exit code 1 if phase not found, plan dir not found, etc. — **must be called with `|| true` or `2>/dev/null ||`**
- Logs transitions to `.claude/logs/phase-transitions.log`
- Outputs the updated plan file path on stdout (or empty on failure)
- Lives at `$SCRIPT_DIR/update-phase-status.sh` (same directory as `update-task-status.sh`)

**Calling convention**:
```bash
"$SCRIPT_DIR/update-phase-status.sh" "$task_number" "$project_name" "1" "IN_PROGRESS"
```

#### Phase Heading Format

From examination of plan files:
```
### Phase 1: Copy artifacts into extension directory [NOT STARTED]
### Phase 2: Update manifest and EXTENSION.md [NOT STARTED]
```

The script finds phase N via: `grep -n "^### Phase ${phase_number}:" "$plan_file"`

#### "First NOT STARTED Phase" Detection

The task description says "first NOT STARTED phase". Since `update-phase-status.sh` takes an explicit phase number, the caller must detect which phase to advance. Two approaches:

**Option A — Always use Phase 1** (simplest): On preflight implement, always call with phase number `1`. The script is idempotent if Phase 1 is already `IN PROGRESS` or `COMPLETED`. This works for initial implementation starts.

**Option B — Discover first NOT STARTED phase**: Scan the plan file for the first phase heading containing `[NOT STARTED]` and extract its phase number. This works correctly for resumption scenarios where Phase 1 is already `COMPLETED` and Phase 2 should be started.

**Recommendation**: Option B is more correct for the "resume from partial" case. The detection is a simple grep + sed pipeline:

```bash
# Find the first NOT STARTED phase number in the plan file
plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)
first_not_started_phase=$(grep -n "^### Phase [0-9]*:.*\[NOT STARTED\]" "$plan_file" 2>/dev/null \
  | head -1 \
  | sed 's/.*^### Phase \([0-9]*\):.*/\1/' 2>/dev/null || echo "")
```

However, this requires finding the plan file path before calling the script. Since `update-phase-status.sh` already resolves the plan file internally, the simplest approach that avoids code duplication is to add this logic inline in `update_plan_file()` right before calling the phase script.

**Plan file path resolution** (must match update-phase-status.sh's own logic):
```bash
padded_num=$(printf "%03d" "$task_number")
plan_dir="$PROJECT_ROOT/specs/${padded_num}_${project_name}/plans"
if [[ ! -d "$plan_dir" ]]; then
  plan_dir="$PROJECT_ROOT/specs/${task_number}_${project_name}/plans"
fi
plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)
```

### The Exact Integration Point

The addition goes inside `update_plan_file()` in the `preflight` branch, **after** the existing `update-plan-status.sh` call. Specifically, after line 236 (the closing `}` of the `|| { ... }` block).

Pseudocode for the addition:

```bash
# Only auto-advance phase on preflight (not postflight)
if [[ "$operation" == "preflight" ]]; then
  local phase_script="$SCRIPT_DIR/update-phase-status.sh"
  if [[ -x "$phase_script" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Phase status: first NOT STARTED phase -> [IN PROGRESS] (via update-phase-status.sh)"
    else
      # Find the first NOT STARTED phase
      local padded_num
      padded_num=$(printf "%03d" "$task_number")
      local plan_dir="$PROJECT_ROOT/specs/${padded_num}_${project_name}/plans"
      if [[ ! -d "$plan_dir" ]]; then
        plan_dir="$PROJECT_ROOT/specs/${task_number}_${project_name}/plans"
      fi
      local plan_file
      plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)
      if [[ -n "$plan_file" ]]; then
        local first_phase
        first_phase=$(grep -oP "(?<=^### Phase )\d+" "$plan_file" | while read -r pn; do
          status_line=$(grep "^### Phase ${pn}:" "$plan_file" | head -1)
          if echo "$status_line" | grep -q "\[NOT STARTED\]"; then
            echo "$pn"
            break
          fi
        done 2>/dev/null || echo "")
        if [[ -n "$first_phase" ]]; then
          "$phase_script" "$task_number" "$project_name" "$first_phase" "IN_PROGRESS" 2>/dev/null || {
            echo "Warning: phase status update failed (non-fatal)" >&2
          }
        fi
      fi
    fi
  fi
fi
```

**Simpler alternative** (using grep with Perl regex, more portable):

```bash
first_phase=$(grep -m1 "^### Phase [0-9]*:.*\[NOT STARTED\]" "$plan_file" \
  | grep -oP "(?<=### Phase )\d+" 2>/dev/null || echo "")
```

Or without Perl regex (POSIX-safe):

```bash
first_phase=$(grep -m1 "^### Phase [0-9]*:.*\[NOT STARTED\]" "$plan_file" \
  | sed 's/^### Phase \([0-9]*\):.*/\1/' 2>/dev/null || echo "")
```

### Existing Usage of update-phase-status.sh

`update-phase-status.sh` is listed in the core extension `manifest.json` under `provides.scripts`, confirming it is a distributed artifact. However, searching all scripts for calls to `update-phase-status` reveals:
- Only `.claude/extensions.json` and `.claude/extensions/core/manifest.json` reference it (as a filename entry)
- No script currently calls it — it is entirely unused in the automated pipeline

### Where the Call Lives in the Pipeline

The call chain for `/implement N` is:

```
/implement command
  -> command-gate-in.sh (preflight)
  -> skill-implementer/SKILL.md Stage 2:
       bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
         -> update_state_json()         # state.json: planned -> implementing
         -> regenerate_todo()           # TODO.md: [PLANNED] -> [IMPLEMENTING]
         -> update_plan_file()          # plan file: [NOT STARTED] -> [IMPLEMENTING]
                                        #   + NEW: first phase [NOT STARTED] -> [IN PROGRESS]
  -> skill-implementer/SKILL.md Stage 5:
       Agent(general-implementation-agent, ...)
```

The phase status update happens in the same atomic call as all other preflight updates.

### Dry-run Support

`update-task-status.sh` has a `--dry-run` flag. The new code must respect `$DRY_RUN == "true"` and emit a dry-run message instead of executing (consistent with the surrounding pattern).

## Decisions

1. Use Option B (discover first NOT STARTED phase) rather than hardcoding phase 1, to correctly handle resumption scenarios
2. Use POSIX-safe `sed` for phase number extraction (no Perl regex dependency)
3. Place the call after the existing `update-plan-status.sh` call — plan-level status updates first, then phase-level
4. Make the call non-fatal (matching the existing pattern for plan file updates)
5. Guard with `[[ -x "$phase_script" ]]` before calling (matching existing guard for `update-plan-status.sh`)
6. Skip if no plan file found (inner guard with `[[ -n "$plan_file" ]]`)
7. Skip if no NOT STARTED phase found — silently do nothing (no warning needed, task may be resuming with all phases already advanced)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Plan file has no `[NOT STARTED]` phases (all completed or in different state) | Guard: only call if `$first_phase` is non-empty |
| Plan file uses non-standard phase heading format | Non-fatal: `|| { echo "Warning..." }` pattern |
| grep returns multiple matches | `head -1` takes only the first match |
| Phase number extraction fails | Guarded by `|| echo ""` fallback; empty check before calling script |
| `update-phase-status.sh` not executable | Guard: `[[ -x "$phase_script" ]]` before calling |
| Dry-run mode should not write files | `$DRY_RUN == "true"` check with echo instead of call |
| `padded_num` already declared in outer scope | Declare `local padded_num` inside function to avoid shadow |

## Context Extension Recommendations

None — this is a meta task and the integration is straightforward.
