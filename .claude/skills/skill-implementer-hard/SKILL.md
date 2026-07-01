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
  # Read handoff JSON to find next incomplete phase
  handoff_file="specs/.orchestrator-handoff.json"
  if [ -f "$handoff_file" ]; then
    phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file")
    next_phase=$((phases_completed + 1))
    echo "[hard-mode] Per-phase dispatch: targeting phase ${next_phase}" >&2
  else
    next_phase=1
    echo "[hard-mode] No handoff found, dispatching phase 1" >&2
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
# Literature Stage 4a: resolve the --lit directive via the shared helper. The helper
# classifies the situation deterministically and prints exactly one directive token; this
# skill acts on it. No branch below sets lit_context="" without either a visible logged
# notice or an explicit user choice -- there is no silent empty fallback.
lit_context=""
lit_rationale_file="$(mktemp)"
directive=$(bash .claude/scripts/literature-lit-flag-resolve.sh \
  --lit-flag "$lit_flag" --orchestrator-mode "${orchestrator_mode:-false}" \
  --query "$description" 2>"$lit_rationale_file") || directive="GLOBAL_MISSING"
lit_rationale="$(cat "$lit_rationale_file" 2>/dev/null)"; rm -f "$lit_rationale_file"

case "$directive" in
  LIT_DISABLED)
    # --lit was not requested this invocation; nothing to announce.
    lit_context=""
    ;;

  SUBINDEX_PRESENT)
    lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
    ;;

  GLOBAL_MISSING)
    # The one acceptable empty branch -- explicitly announced, never silent.
    echo "[lit] No literature available: no per-repo sub-index and no global Literature index found. Continuing without literature context." >&2
    lit_context=""
    ;;

  PROMPT_NEEDED)
    # AskUserQuestion must be issued inline here (cannot be delegated to a shell script).
    # Present exactly three options -- two live outcomes plus one explicit, non-silent skip:
    #   1. "Use global corpus now" (recommended default, listed first): run
    #      literature-briefing.sh --global "$description" and inject the result this run
    #      only. No setup, no file writes.
    #   2. "Create curation task": run literature-create-setup-task.sh to create the
    #      populate_literature_sub_index task, then attempt the Stage 4a-fork inline
    #      population below so this run also benefits; inject via no-arg
    #      literature-briefing.sh once the sub-index exists.
    #   3. "Skip this run": explicit user choice; log "[lit] Skipped by user choice" and
    #      continue empty -- non-silent because it is an explicit, logged choice.
    #
    # Pseudocode (executed by Claude as the skill runs):
    #   user_choice = AskUserQuestion(
    #     "The --lit flag was used but specs/literature-index.json does not exist for this repo.\n\n" +
    #     "A global Literature index was found. How would you like to proceed?",
    #     options=[
    #       "Use global corpus now: search the global Literature corpus for this task and use the results this run (no setup, no file writes)",
    #       "Create curation task: create a task to curate a per-repo sub-index for future runs, and try to populate it now so this run benefits too",
    #       "Skip this run: continue without literature context (explicit, logged choice)"
    #     ]
    #   )
    #
    # After user_choice:
    #   if "Use global corpus now":
    #     lit_context=$(bash .claude/scripts/literature-briefing.sh --global "$description" 2>/dev/null) || lit_context=""
    #
    #   if "Create curation task":
    #     new_task_num=$(bash .claude/scripts/literature-create-setup-task.sh)
    #     echo "Created task $new_task_num to populate specs/literature-index.json."
    #     # Attempt inline fork population (see Stage 4a-fork below).
    #     # After the fork completes:
    #     #   if specs/literature-index.json now exists:
    #     #     lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
    #     #   else:
    #     #     echo "[lit] Task $new_task_num created; sub-index not yet populated this run. Continuing without literature context. Run /orchestrate $new_task_num to populate." >&2
    #     #     lit_context=""
    #
    #   if "Skip this run":
    #     echo "[lit] Skipped by user choice" >&2
    #     lit_context=""
    :
    ;;

  AUTONOMOUS_GLOBAL)
    # orchestrator_mode=true: AskUserQuestion cannot prompt. Take the deterministic D3
    # default "Use global corpus now" and announce it visibly -- never a silent no-op.
    echo "[lit:auto] No per-repo sub-index and no human available to prompt (orchestrator_mode=true); auto-selecting 'Use global corpus now' for this run. $lit_rationale" >&2
    lit_context=$(bash .claude/scripts/literature-briefing.sh --global "$description" 2>/dev/null) || lit_context=""
    ;;

  *)
    echo "Warning: unrecognized --lit directive '$directive'; continuing without literature context." >&2
    lit_context=""
    ;;
esac
```

**Stage 4a-fork: Inline population (option "Create curation task")**

When the user selects "Create curation task", after calling `literature-create-setup-task.sh`:

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
   - If yes: run `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""`
   - If no (fork failed or timed out): emit a visible notice (`[lit] Task $new_task_num created; sub-index not yet populated this run.`), report the task number, suggest `/orchestrate N`, set `lit_context=""` -- non-silent because the notice is logged.

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`. `orchestrator_mode` is read directly from the delegation context (no extraction step needed) to select the `AUTONOMOUS_GLOBAL` vs `PROMPT_NEEDED` branch.

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
else
    status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

```bash
if [ "$status" = "implemented" ]; then
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
fi
# On partial: keep status as "implementing" for resume
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
