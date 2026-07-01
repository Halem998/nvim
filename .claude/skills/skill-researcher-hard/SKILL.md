---
name: skill-researcher-hard
description: Conduct hard-mode research with adversarial verification, reference grounding, and anti-analysis contracts. Invoke for --hard research tasks.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
---

# Researcher Hard Skill

Hard-mode wrapper that delegates research to `general-research-hard-agent` subagent.
Extends `skill-researcher` with hard-mode behavioral contracts (H2, H3, H4) and
postflight logging of adversarial verification status.

**Relationship to base skill**: This skill is structurally identical to `skill-researcher`
except it dispatches to `general-research-hard-agent` and logs `adversarial_verification_triggered`.
Maintenance note: changes to `skill-researcher` postflight should be mirrored here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/reference-grounding.md` - H3 contract (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns

## Trigger Conditions

This skill activates when:
- `/research N --hard` is invoked and no extension hard variant exists
- Routed here by `command-route-skill.sh` with `effort_flag="hard"`

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json

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
```

---

### Stage 1.5: Hard-Mode Cost Note

Emit one-time cost note (via session flag) on first hard-mode invocation:

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active. Cost: ~3-5x standard. Use --hard for deflection-prone or formally complex tasks." >&2
  touch "$session_flag_file"
fi
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

```bash
.claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

---

### Stage 3: Create Postflight Marker

Create marker file:

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-researcher-hard",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Hard-mode research in progress: adversarial verification, status update, git commit pending"
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
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

---

### Stage 4a: Memory Retrieval (Auto)

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
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

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-researcher-hard"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number}",
  "focus_prompt": "{optional focus}",
  "effort_flag": "hard",
  "model_flag": "{model_flag from command, null if not set}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 4b: Read Format Specification

```bash
format_content=$(cat .claude/context/formats/report-format.md)
```

---

### Stage 5: Invoke Subagent

```
Tool: Agent
Parameters:
  - subagent_type: "general-research-hard-agent"
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context, focus]
  - description: "Execute hard-mode research for task {N}"
```

Include format specification, memory context, and literature briefing in prompt as per `skill-researcher` pattern. If `lit_context` is non-empty, inject it as a `<literature-briefing>` block after the memory context and before the task-specific instructions.

---

### Stage 5b: Self-Execution Fallback

If Agent tool was not used (inline execution path), write `.return-meta.json` with status
`"researched"` before proceeding to postflight.

---

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

Read metadata file and extract: status, artifact_path, artifact_type, artifact_summary,
memory_candidates, and additionally `adversarial_verification_triggered`.

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
    adversarial_triggered=$(jq -r '.adversarial_verification_triggered // false' "$metadata_file")
else
    status="failed"
    adversarial_triggered="false"
fi

# Log adversarial verification status
echo "[hard-mode] Adversarial verification triggered: $adversarial_triggered" >&2
```

---

### Stage 6a: Validate Artifact Content (non-blocking)

```bash
if [ "$status" = "researched" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    bash .claude/scripts/validate-artifact.sh "$artifact_path" report --fix || true
fi
```

---

### Stage 7: Update Task Status (Postflight)

```bash
if [ "$status" = "researched" ]; then
  .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"

  jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
      (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

---

### Stage 7a: Propagate Memory Candidates

Same as `skill-researcher` Stage 7a.

---

### Stage 8: Link Artifacts

Same as `skill-researcher` Stage 8 (two-step jq pattern for Issue #1132 safety).

---

### Stage 8a: Lifecycle TTS Notification

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then bash "$lifecycle_script" "$STATE_STATUS" & fi
```

---

### Stage 9: Cleanup

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```
