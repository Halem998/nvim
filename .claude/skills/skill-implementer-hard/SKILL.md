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
    # skill-orchestrate-hard's job (task 772) -- out of scope here.
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

```bash
# Literature sub-index detection (interactive setup when sub-index is missing)
lit_context=""
if [ "$lit_flag" = "true" ] && [ ! -f "specs/literature-index.json" ]; then
  LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
  GLOBAL_INDEX="$LIT_DIR/index.json"
  if [ ! -f "$GLOBAL_INDEX" ]; then
    # Global index missing -- inform user and continue without literature context
    echo "Note: --lit flag used but no global Literature index found at $GLOBAL_INDEX. Continuing without literature context." >&2
    # lit_context remains ""
  else
    # Global index exists but sub-index is missing -- present interactive setup options
    # (AskUserQuestion must be called inline here; cannot be delegated to a shell script)
    #
    # Present AskUserQuestion with 3 options:
    # 1. Skip: Continue without literature context
    # 2. Create setup task: Create task and continue without literature context now
    # 3. Create task and run now: Create task, populate sub-index inline, then use it
    #
    # Pseudocode (executed by Claude as the skill runs):
    #   user_choice = AskUserQuestion(
    #     "The --lit flag was used but specs/literature-index.json does not exist for this repo.\n\n" +
    #     "A global Literature index was found at $GLOBAL_INDEX.\n\n" +
    #     "How would you like to proceed?",
    #     options=[
    #       "Skip: Continue without literature context (--lit is ignored this time)",
    #       "Create setup task: Create a task to populate the sub-index, then continue without literature context",
    #       "Create task and run now: Create the task AND populate specs/literature-index.json inline before proceeding"
    #     ]
    #   )
    #
    # After user_choice:
    #   if "Skip":
    #     lit_context=""  (already set, no action needed)
    #
    #   if "Create setup task":
    #     new_task_num=$(bash .claude/scripts/literature-create-setup-task.sh)
    #     echo "Created task $new_task_num to populate specs/literature-index.json. Run /orchestrate $new_task_num to populate before using --lit."
    #     lit_context=""  (continue without literature context)
    #
    #   if "Create task and run now":
    #     new_task_num=$(bash .claude/scripts/literature-create-setup-task.sh)
    #     echo "Created task $new_task_num. Populating specs/literature-index.json inline via fork agent..."
    #     # Fork dispatch: inline population of sub-index (see Stage 4a-fork below)
    #     # After fork completes and sub-index exists:
    #     lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh) || lit_context=""
    :
  fi
fi
```

**Stage 4a-fork: Inline population (option "Create task and run now")**

When the user selects "Create task and run now", after calling `literature-create-setup-task.sh`:

1. Invoke the Agent tool with `subagent_type: "fork"` and a prompt instructing the fork to:
   - Read `~/Projects/Literature/index.json` (or `$LITERATURE_DIR/index.json`)
   - Read `specs/state.json` to understand this repo's task descriptions and domain
   - Analyze keyword/topic overlap between global index `keywords`, `project_tags`, and `summary` fields and the repo's task descriptions
   - Write matched entries to `specs/literature-index.json` with this schema:
     ```json
     {
       "entries": [
         {"doc_id": "<id>", "relevance": "<one-sentence note>", "source": "discover"}
       ]
     }
     ```
   - Update the newly created task (number from step above) to `completed` status in `specs/state.json`
   - Call `bash .claude/scripts/generate-todo.sh` after updating state.json

2. After the fork returns, check if `specs/literature-index.json` was created:
   - If yes: run `lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh) || lit_context=""`
   - If no (fork failed or timed out): log a warning, report the task number, suggest `/orchestrate N`, set `lit_context=""`

```bash
# Literature briefing injection (runs if sub-index already exists OR was just created by fork)
if [ "$lit_flag" = "true" ] && [ -f "specs/literature-index.json" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh) || lit_context=""
fi
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

---

### Stage 4: Prepare Delegation Context

Pass anti-analysis contract reference and territory params (when applicable):

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
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
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
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
fi
# On partial: keep status as "implementing" for resume
# NOTE: A skeleton dispatch (skeleton=true) already reports status="implemented" per the
# anti-analysis.md strategic-sorry policy, so it flows through the existing "implemented"
# postflight path above with no additional branching required.
```

---

### Stage 7a: Propagate Memory Candidates and Completion Summary

Same as `skill-implementer` Stage 7a + completion summary propagation.

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
