---
name: skill-implementer-hard
description: Execute hard-mode implementation with anti-analysis contracts, per-phase dispatch, and territory-aware execution. Invoke for --hard implementation tasks.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
---

# Implementer Hard Skill

Hard-mode wrapper that delegates implementation to `general-implementation-hard-agent` subagent.
Extends `skill-implementer` with:

- Single-phase dispatch context (H1): reads handoff JSON to identify next incomplete phase
- Territory parameters (H7): includes territory contract when dispatched from orchestrate-hard
- Anti-analysis contract (H2): passed in delegation context for agent enforcement

**Relationship to base skill**: Structurally follows `skill-implementer` postflight pattern.
Key difference: when `orchestrator_mode=true`, uses per-phase dispatch (H1) rather than
whole-plan dispatch. Maintenance: mirror postflight changes to this skill.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/wrap-up.md` - H9 contract (loaded by agent)
- Path: `.claude/context/contracts/territory.md` - H7 contract (when territory params present)
- Path: `.claude/context/contracts/recovery.md` - recovery/fix-forward ladder (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/subagent-continuation-loop.md` - Continuation loop pattern

## Trigger Conditions

This skill activates when:
- `/implement N --hard` is invoked and no extension hard variant exists
- Routed here by `command-route-skill.sh` with `effort_flag="hard"`
- `skill-orchestrate-hard` dispatches an implementation phase

---

## Execution Flow

### Stage 1: Input Validation

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
  return error "Task is in terminal state [$status]"
fi
```

---

### Stage 1.5: Hard-Mode Cost Note

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active. Cost: ~3-5x standard. Use --hard for deflection-prone or formally complex tasks." >&2
  touch "$session_flag_file"
fi
```

---

### Stage 2: Preflight Status Update

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-implementer-hard",
  "task_number": ${task_number},
  "operation": "implement",
  "reason": "Hard-mode implementation in progress: per-phase dispatch, anti-analysis contract, status update pending"
}
EOF
```

---

### Stage 3a: Calculate Artifact Number

```bash
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

---

### Stage 3b: Single-Phase Dispatch Context (H1)

When `orchestrator_mode=true`, determine the specific phase to dispatch rather than
dispatching the whole plan:

```bash
if [ "$orchestrator_mode" = "true" ]; then
  task_dir="specs/${padded_num}_${project_name}"
  # Absolute anchor handed to the dispatched agent so it never has to resolve a bare filename
  # against the ambient working directory. SKILL_REPO_ROOT is exported by skill-base.sh when
  # sourced; $(pwd) is a last-resort fallback for direct invocation.
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/${padded_num}_${project_name}"
  handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"
  # Fixed: was the un-scoped "specs/.orchestrator-handoff.json" (collided across tasks and
  # didn't match skill-orchestrate-hard's own TASK_DIR-scoped path). Now scoped per task,
  # matching skill-orchestrate-hard/SKILL.md:131 (`${TASK_DIR}/.orchestrator-handoff.json`).
  handoff_file="${task_dir}/.orchestrator-handoff.json"
  plan_path=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1)

  # Fixed: integer-increment phase selection (`next_phase=$((phases_completed + 1))`) could not
  # address N.1/N.2 sub-phase headings or sparse numbering (1, 2, 2.1, 2.2, 3), and had no
  # skeleton-exhaustion signal. Replaced with a heading-scan of the plan file itself, mirroring
  # the base agent's Stage 3 "Find Resume Point" pattern. This is a strict superset: dense
  # integer plans (1, 2, 3, ...) resolve identically to the old increment behavior.
  next_phase=""
  if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
    # Scan phase headings top-to-bottom; first NOT STARTED / PARTIAL / IN PROGRESS wins.
    # Heading form: "### Phase {N or N.1}: {name} [STATUS]"
    next_phase=$(grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path" \
      | head -1 \
      | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?):.*/\1/')
  fi

  if [ -n "$next_phase" ]; then
    echo "[hard-mode] Per-phase dispatch: targeting phase ${next_phase} (heading-scan)" >&2
  elif [ -f "$handoff_file" ] && [ "$(jq -r '.skeleton // false' "$handoff_file" 2>/dev/null)" = "true" ]; then
    # Skeleton-exhaustion detection: no incomplete phase heading remains AND the prior dispatch
    # outcome declared skeleton=true. Make the condition legible rather than looping on a
    # nonexistent phase or silently no-op'ing. Routing to the follow-up tasks themselves remains
    # skill-orchestrate-hard's job (see its skeleton-exhaustion routing stage) -- out of scope here.
    follow_up_tasks=$(jq -r '.follow_up_tasks // [] | join(", ")' "$handoff_file" 2>/dev/null)
    follow_up_count=$(jq -r '.follow_up_tasks // [] | length' "$handoff_file" 2>/dev/null)
    echo "[hard-mode] Skeleton plan exhausted -- ${follow_up_count} follow-up tasks pending: {${follow_up_tasks}}" >&2
    next_phase=""
  else
    next_phase=1
    echo "[hard-mode] No incomplete phase heading found and no handoff, dispatching phase 1" >&2
  fi
  # phase_number will be passed in delegation context
fi
```

---

### Stage 4a: Memory Retrieval (Auto)

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

**Literature Detection and Injection (Stage 4a, shared block)**

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`: call `literature-lit-flag-resolve.sh`, branch on all six directives
(`LIT_DISABLED`, `SUBINDEX_PRESENT`, `GLOBAL_MISSING`, `PROMPT_NEEDED`, `AUTONOMOUS_GLOBAL`,
`SPARSE_PROMPT_NEEDED`), issue the real four-option `AskUserQuestion` for the two interactive
directives (including the "Search online to ingest" option wired to the STABLE-CONTRACT
`literature-ingest-online.sh` bridge), apply the two-checkpoint sparse re-prompt after "Use
global corpus now", and take the deterministic `[lit:auto]` autonomous fallback when
`orchestrator_mode == "true"` (never calling `AskUserQuestion` in that case). This skill
supplies the shared block's preconditions: `lit_flag`, `description`, and `orchestrator_mode`
(read from the delegation context; default `"false"` when unset).

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

---

### Stage 4: Prepare Delegation Context

Pass anti-analysis contract reference, recovery contract reference (see
`.claude/context/contracts/recovery.md` — fix-forward disambiguation and the 3-rung Recovery
Ladder), and territory params (when applicable):

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-implementer-hard"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number}",
  "effort_flag": "hard",
  "model_flag": "{model_flag from command}",
  "plan_path": "{plan_path}",
  "phase_number": "{next_phase when orchestrator_mode=true, null otherwise}",
  "territory": "{territory params from orchestrate-hard dispatch, null if not provided}",
  "orchestrator_mode": "{orchestrator_mode}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "task_dir": "{task_dir_abs — ABSOLUTE path to the task directory}",
  "handoff_path": "{handoff_path_abs — ABSOLUTE path the agent MUST write its handoff to}"
}
```

> **CRITICAL**: No source reading before delegation. The subagent handles all codebase exploration.

---

### Stage 4b: Read Format Specification

```bash
format_content=$(cat .claude/context/formats/summary-format.md)
```

---

### Stage 5: Invoke Subagent

```
Tool: Agent
Parameters:
  - subagent_type: "general-implementation-hard-agent"
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
  - description: "Execute hard-mode implementation for task {N} phase {next_phase}"
```

The prompt MUST state the handoff destination explicitly, not leave it to the agent to infer:
"Write your orchestrator handoff to the ABSOLUTE path `{handoff_path_abs}`. Never write a bare
`.orchestrator-handoff.json` filename."

If `lit_context` is non-empty, inject it as a `<literature-briefing>` block after the memory context and before the task-specific instructions.

Include territory parameters in prompt when `territory` is non-null:
```
<territory-contract>
This is a hard-mode parallel dispatch. Territory rules are mandatory:
- Owned files: {territory.owned_files}
- Read-only references: {territory.read_only_files}
- See .claude/context/contracts/territory.md for full protocol
</territory-contract>
```

---

### Stage 5b: Self-Execution Fallback

If Agent tool not used, write `.return-meta.json` with `status: "implemented"` before postflight.

---

### Stage 5c: Continuation Loop Init

```bash
continuation_count=0
max_continuations=3
task_dir="specs/${padded_num}_${project_name}"
cat > "${task_dir}/.continuation-loop-guard" << EOF
{
  "session_id": "${session_id}",
  "continuation_count": 0,
  "max_continuations": 3
}
EOF
```

---

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
    phases_completed=$(jq -r '.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.phases_total // 0' "$metadata_file")
    # H9 strategic-sorry skeleton fields (see .claude/context/contracts/wrap-up.md):
    # optional, default false / [] when absent.
    skeleton=$(jq -r '.skeleton // false' "$metadata_file")
    sorry_inventory=$(jq -c '.sorry_inventory // []' "$metadata_file")
else
    status="failed"
    skeleton="false"
    sorry_inventory="[]"
fi

if [ "$skeleton" = "true" ]; then
  follow_up_tasks=$(echo "$sorry_inventory" | jq -r '[.[] | .follow_up_task] | join(", ")')
  sorry_count=$(echo "$sorry_inventory" | jq -r 'length')
  echo "[hard-mode] Skeleton dispatch: ${sorry_count} strategic sorries -> follow-up tasks {${follow_up_tasks}}" >&2
fi
```

---

### Stage 7: Update Task Status (Postflight)

```bash
if [ "$status" = "implemented" ]; then
  postflight_rc=0
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=refuse || postflight_rc=$?
  if [ "$postflight_rc" -eq 4 ]; then
    # The backstop read the plan file's own `### Phase N: ... [STATUS]` headings and found
    # incomplete phases. Nothing was written. Degrade to the partial path -- keep status
    # "implementing" for resume -- rather than retrying without the flag.
    echo "[hard-mode] Phase-accounting backstop refused completion for task $task_number; keeping status=implementing for resume." >&2
    status="partial"
  elif [ "$postflight_rc" -ne 0 ]; then
    echo "WARNING: update-task-status.sh exited $postflight_rc — manual correction may be needed" >&2
  fi
fi
# On partial: keep status as "implementing" for resume
# NOTE: A skeleton dispatch (skeleton=true) already reports status="implemented" per the
# anti-analysis.md strategic-sorry policy, so it flows through the existing "implemented"
# postflight path above with no additional branching required.
```

---

### Stage 7a: Propagate Completion Summary, Roadmap Items, and Memory Candidates

Equivalent to `skill-implementer` Stage 7, Steps 2-4 (completion_summary write, guarded
roadmap_items write, memory_candidates append). Only runs when Stage 7 did not refuse
completion (see Step 1a there — on refusal, completion_summary/roadmap_items are skipped since
the task is not yet complete):

```bash
# Steps 2-3: completion_summary + roadmap_items, via the shared writer (one of six converged
# call sites — see skill_propagate_completion_summary's header comment in skill-base.sh)
source .claude/scripts/skill-base.sh
skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"

# Step 4: memory_candidates (append semantics)
if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
    jq --argjson new_candidates "$memory_candidates" \
      '(.active_projects[] | select(.project_number == '$task_number')).memory_candidates =
        ((.active_projects[] | select(.project_number == '$task_number')).memory_candidates // []) + $new_candidates' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

---

### Stage 8: Link Artifacts

Two-step jq pattern (Issue #1132 safety):
1. Filter out existing summary artifacts
2. Add new summary artifact

Regenerate TODO.md after linking.

---

### Stage 8a: Lifecycle TTS Notification

```bash
if [ -f ".claude/scripts/lifecycle-notify.sh" ]; then
  bash .claude/scripts/lifecycle-notify.sh "$STATE_STATUS" &
fi
```

---

### Stage 9: Cleanup

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.continuation-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```
