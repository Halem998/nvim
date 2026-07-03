---
name: skill-planner-hard
description: Create hard-mode implementation plans with phase sizing, postmortem constraints, and preserved-assets accounting. Invoke for --hard planning tasks.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
---

# Planner Hard Skill

Hard-mode wrapper that delegates plan creation to `planner-hard-agent` subagent.
Extends `skill-planner` with H8 plan requirements passed in delegation context.

**Relationship to base skill**: Structurally identical to `skill-planner` except it
dispatches to `planner-hard-agent` and passes H8 plan requirements.
Maintenance note: changes to `skill-planner` postflight should be mirrored here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/reference-grounding.md` - H3 contract (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns

## Trigger Conditions

This skill activates when:
- `/plan N --hard` is invoked and no extension hard variant exists
- Routed here by `command-route-skill.sh` with `effort_flag="hard"`

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
bash .claude/scripts/update-task-status.sh preflight "$task_number" plan "$session_id"
```

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-planner-hard",
  "task_number": ${task_number},
  "operation": "plan",
  "reason": "Hard-mode planning in progress: phase sizing, postmortem constraints, status update pending"
}
EOF
```

---

### Stage 3a: Read Artifact Number

```bash
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  artifact_number=1
fi
# Plans use (current - 1) to stay in the same round as research
plan_artifact_number=$(( artifact_number - 1 ))
[ "$plan_artifact_number" -lt 1 ] && plan_artifact_number=1
plan_padded=$(printf "%02d" "$plan_artifact_number")
```

---

### Stage 3b: Find Research Report and Prior Plan

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"

# Find latest research report
research_path=$(ls "${task_dir}/reports/"*.md 2>/dev/null | sort | tail -1)

# Find latest prior plan
prior_plan_path=$(ls "${task_dir}/plans/"*.md 2>/dev/null | sort | tail -1)
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

# lit_context will be empty string if:
# - lit_flag is not "true" (skipped)
# - specs/literature-index.json is empty or missing (after all detection/setup above)
# - literature-briefing.sh exited non-zero (wrapper already emitted a visible
#   "[lit] briefing generation failed (exit N)" notice to stderr above)
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

---

### Stage 4: Prepare Delegation Context

Pass H8 plan requirements explicitly in the delegation context:

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "plan", "skill-planner-hard"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{plan_artifact_number}",
  "research_path": "{research_path or null}",
  "prior_plan_path": "{prior_plan_path or null}",
  "effort_flag": "hard",
  "model_flag": "{model_flag from command, null if not set}",
  "roadmap_path": "specs/ROADMAP.md",
  "roadmap_flag": "{roadmap_flag from command}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "hard_mode_requirements": {
    "phase_sizing_constraint": "Each phase must be completable in one agent run (~100-500 lines output)",
    "postmortem_constraints_required": true,
    "preserved_assets_accounting": "Required when prior plan exists",
    "source_to_implementation_mapping": "Required for Tier 1/2 reference tasks",
    "wave_map_required": true
  }
}
```

---

### Stage 4b: Read Format Specification

```bash
format_content=$(cat .claude/context/formats/plan-format.md)
```

---

### Stage 5: Invoke Subagent

```
Tool: Agent
Parameters:
  - subagent_type: "planner-hard-agent"
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
  - description: "Create hard-mode implementation plan for task {N}"
```

If `lit_context` is non-empty, inject it as a `<literature-briefing>` block after the memory context and before the task-specific instructions.

---

### Stage 5b: Self-Execution Fallback

If Agent tool not used, write `.return-meta.json` with `status: "planned"` before postflight.

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
    postmortem_rules_count=$(jq -r '.postmortem_rules_count // 0' "$metadata_file")
    echo "[hard-mode] Postmortem rules added to plan: $postmortem_rules_count" >&2
else
    status="failed"
fi
```

---

### Stage 6a: Validate Artifact Content (non-blocking)

```bash
if [ "$status" = "planned" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    bash .claude/scripts/validate-artifact.sh "$artifact_path" plan --fix || true
fi
```

---

### Stage 6b: Skeleton Task Allocation (H8 escape valve)

Duplicate-with-modification of `skill-spawn/SKILL.md` Stages 7-11 (do NOT extract a shared
helper — this is a deliberate lower-risk, smaller-diff first cut; revisit only if a second
consumer appears). Structurally identical, EXCEPT the dependency direction is REVERSED (see
below) and the artifact consumed is `.skeleton-return.json` rather than `.spawn-return.json`.

Runs only when `planner-hard-agent` (Stage 4a of `planner-hard-agent.md`) declared a skeleton
plan. No-ops cleanly otherwise.

```bash
skeleton_file="specs/${padded_num}_${project_name}/.skeleton-return.json"

if [ -f "$skeleton_file" ] && jq empty "$skeleton_file" 2>/dev/null; then
  new_tasks=$(jq -r '.new_tasks' "$skeleton_file")
  task_count=$(jq '.new_tasks | length' "$skeleton_file")

  if [ "$task_count" -gt 0 ]; then
    dependency_order=$(jq -r '.dependency_order' "$skeleton_file")

    # Stage 6b-i: Get next task numbers (mirrors skill-spawn Stage 8)
    next_num=$(jq -r '.next_project_number' specs/state.json)

    # Stage 6b-ii: Apply topological sort (mirrors skill-spawn Stage 9)
    # dependency_order is already topologically sorted (foundational first).
    declare -A task_num_map
    order_idx=0
    for idx in $(echo "$dependency_order" | jq -r '.[]'); do
        task_num_map[$idx]=$((next_num + order_idx))
        order_idx=$((order_idx + 1))
    done

    # Stage 6b-iii: Create new task directories (mirrors skill-spawn Stage 10)
    for idx in $(echo "$dependency_order" | jq -r '.[]'); do
        new_task_num=${task_num_map[$idx]}
        new_padded=$(printf "%03d" "$new_task_num")
        task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$skeleton_file")
        task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')
        mkdir -p "specs/${new_padded}_${task_slug}/reports"
    done

    # Stage 6b-iv: Update state.json with new tasks (mirrors skill-spawn Stage 11), BUT with the
    # SETTLED REVERSED dependency direction: each follow-up task's `dependencies` includes the
    # SKELETON (current) task number, NOT sibling new_tasks that gate it the spawn-agent way.
    # This is the inverse of skill-spawn Stage 13 -- copying that step verbatim here would wire
    # dependencies backwards and leave the skeleton task perpetually [BLOCKED].
    for idx in $(echo "$dependency_order" | jq -r '.[]'); do
        new_task_num=${task_num_map[$idx]}
        task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$skeleton_file")
        task_desc=$(jq -r --argjson i "$idx" '.new_tasks[$i].description' "$skeleton_file")
        task_effort=$(jq -r --argjson i "$idx" '.new_tasks[$i].effort' "$skeleton_file")
        task_type_new=$(jq -r --argjson i "$idx" '.new_tasks[$i].task_type' "$skeleton_file")
        task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')

        # REVERSED: dependencies = [skeleton_task_number] (the current task), not the spawn-agent
        # sibling-index resolution. The skeleton task's own `dependencies` field is untouched --
        # there is no Stage 13-equivalent "update parent task dependencies" step here.
        resolved_deps="[$task_number]"

        jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           --argjson num "$new_task_num" \
           --arg name "$task_slug" \
           --arg desc "$task_desc" \
           --arg effort "$task_effort" \
           --arg lang "$task_type_new" \
           --argjson deps "$resolved_deps" \
           --argjson parent "$task_number" \
          '.active_projects += [{
            "project_number": $num,
            "project_name": $name,
            "status": "not_started",
            "task_type": $lang,
            "description": $desc,
            "effort": $effort,
            "parent_task": $parent,
            "dependencies": $deps,
            "created": $ts,
            "last_updated": $ts,
            "artifacts": []
          }]' \
          specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
    done

    # Update next_project_number
    jq --argjson next "$((next_num + task_count))" \
      '.next_project_number = $next' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Stage 6b-v: Record follow-up task numbers on the skeleton (current) task's plan_metadata
    # (skeleton: true, follow_up_tasks: [...]) per plan-format.md's schema (Phase 3).
    follow_up_task_nums="[]"
    for idx in $(echo "$dependency_order" | jq -r '.[]'); do
        follow_up_task_nums=$(echo "$follow_up_task_nums" | jq --argjson n "${task_num_map[$idx]}" '. + [$n]')
    done
    jq --argjson num "$task_number" --argjson follow_ups "$follow_up_task_nums" \
       '(.active_projects[] | select(.project_number == $num) | .plan_metadata) =
        ((.active_projects[] | select(.project_number == $num) | .plan_metadata) // {} +
         {"skeleton": true, "follow_up_tasks": $follow_ups})' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Stage 6b-vi: Regenerate TODO.md after state writes.
    bash .claude/scripts/generate-todo.sh
  fi
fi
```

---

### Stage 6c: Placeholder-Token Substitution Pass

Immediately after Stage 6b's allocation. Resolves every `{{FOLLOWUP:i}}` token written by
`planner-hard-agent` in the just-written plan file to the concrete allocated task number from
Stage 6b's `task_num_map`. This step has no `skill-spawn` equivalent (spawn-agent never emits
forward-reference tokens into a sibling artifact).

Guards to a clean no-op when `.skeleton-return.json` is absent (non-skeleton plans) — the plan
file is left completely untouched in that case.

```bash
if [ -f "$skeleton_file" ] && [ "$task_count" -gt 0 ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
  # Single text-substitution pass: replace {{FOLLOWUP:i}} with the real allocated task number.
  # Covers both the plan overview prose and the `## Planned Strategic Sorries` table's
  # `Follow-Up Task` column -- both are plain textual occurrences of the same token.
  for idx in $(echo "$dependency_order" | jq -r '.[]'); do
      token="{{FOLLOWUP:${idx}}}"
      real_num="${task_num_map[$idx]}"
      sed -i "s/${token//\//\\/}/${real_num}/g" "$artifact_path"
  done

  # Verify no unresolved tokens remain (defensive check, non-fatal)
  if grep -q '{{FOLLOWUP:' "$artifact_path" 2>/dev/null; then
    echo "[hard-mode] Warning: unresolved {{FOLLOWUP:i}} token(s) remain in $artifact_path after substitution pass" >&2
  fi

  echo "[hard-mode] Skeleton plan: allocated ${task_count} follow-up task(s), substituted placeholder tokens" >&2
fi
```

---

### Stage 7: Update Task Status (Postflight)

```bash
if [ "$status" = "planned" ]; then
  bash .claude/scripts/update-task-status.sh postflight "$task_number" plan "$session_id"
fi
```

---

### Stage 7a: Propagate Memory Candidates

Same as `skill-planner` Stage 7a pattern.

---

### Stage 8: Link Artifacts

Two-step jq pattern (Issue #1132 safety):
1. Filter out existing plan artifacts
2. Add new plan artifact

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
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```
