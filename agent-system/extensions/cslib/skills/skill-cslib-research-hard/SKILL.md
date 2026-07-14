---
name: skill-cslib-research-hard
description: Research CSLib formalization patterns with hard-mode contracts (H2 anti-analysis, H3 reference grounding with BibKey verification, H4 adversarial verification). Invoke for --hard cslib research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Research Hard Skill

Hard-mode wrapper that delegates CSLib research to `cslib-research-hard-agent` subagent.
Extends `skill-cslib-research` with hard-mode behavioral contracts (H2, H3, H4) and
postflight logging of adversarial verification status.

**Relationship to base skill**: This skill is structurally identical to `skill-cslib-research`
except it dispatches to `cslib-research-hard-agent` and logs `adversarial_verification_triggered`.
**Maintenance note**: changes to `skill-cslib-research` postflight should be mirrored here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/reference-grounding.md` - H3 contract (loaded by agent)
- Path: `.claude/extensions/cslib/context/project/cslib/standards/citation-conventions.md` - BibKey format (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol

## Trigger Conditions

This skill activates when:
- `/research N --hard` is invoked and task type is `cslib`
- Routed here by `command-route-skill.sh` with `effort_flag="hard"` and task type `cslib`
- Explicitly listed in `routing_hard.research.cslib` in the cslib extension manifest

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:

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

Emit one-time cost note on first hard-mode invocation:

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active (cslib research). Cost: ~3-5x standard." >&2
  touch "$session_flag_file"
fi
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent:

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-cslib-research-hard",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Hard-mode CSLib research in progress: adversarial verification, BibKey check, status update pending"
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
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi

# lit_context will be empty string if:
# - lit_flag is not "true" (skipped)
# - specs/literature/ sub-index is empty or missing
# - script exited with error
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

---

### Stage 4: Prepare Delegation Context

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-cslib-research-hard"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "cslib"
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
  - subagent_type: "cslib-research-hard-agent"
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context, focus]
  - description: "Execute hard-mode CSLib research for task {N}"
```

Include format specification, memory context, and literature briefing in prompt.

- If `memory_context` is non-empty, include it as a `<memory-context>` block after the format specification.
- If `lit_context` is non-empty, include it as a `<literature-briefing>` block after the memory context.
- Do NOT inject empty blocks when content is empty.

---

### Stage 5b: Self-Execution Fallback

If Agent tool was not used, write `.return-meta.json` with status `"researched"` before postflight.

---

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

Read metadata file and extract: status, artifact_path, artifact_type, artifact_summary,
memory_candidates, and `adversarial_verification_triggered`.

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
  bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"

  jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
      (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

---

### Stage 7a: Propagate Memory Candidates

Same as `skill-cslib-research` Stage 7a.

---

### Stage 8: Link Artifacts

Same as `skill-cslib-research` Stage 8 (two-step jq pattern for Issue #1132 safety).

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
