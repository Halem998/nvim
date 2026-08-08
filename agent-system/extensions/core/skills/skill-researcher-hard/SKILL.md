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
- Path: `.claude/context/contracts/adversarial-verification.md` - H4 contract: Claim Verification Bar, Confidence Level Taxonomy, Contradiction Resolution Protocol (MANDATORY, loaded by agent)
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

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-researcher-hard"
operation="research"
```

**Marker unification note**: this skill's marker previously dropped `created` and
`stop_hook_active` (Shape C) — a drift, not a hard-mode design decision. Routing through
`skill_create_postflight_marker` restores both fields as part of this conversion, matching every
other importer's Shape A schema.

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

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"researched"`.

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

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full for Stage 7 (postflight status
update), Stage 7a (memory-candidate propagation), Stage 8 (artifact linking), Stage 8a (TTS
notify), and Stage 9 (cleanup). Real imports replace the prior `Same as skill-researcher Stage 7a`
/ `Stage 8` prose cross-references — both targets were valid, so this is drift-proofing (a
cross-reference can silently go stale; an `@`-import cannot):

```bash
field_name='**Research**'
next_field='**Plan**'
```

This skill supplies the shared block's preconditions: `task_number`, `padded_num`,
`project_name`, `session_id`, `operation`, `status`, `artifact_path`, `artifact_type`,
`artifact_summary`, `memory_candidates`, `field_name`, `next_field`.

**Research-specific addition, NOT covered by the shared block**: increment `next_artifact_number`
immediately after the shared block's Stage 7 call, guarded the same way as `skill-researcher`:

```bash
if [ "$status" = "researched" ]; then
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
      (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
    --session-id "$session_id"
fi
```

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All research work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use MCP/WebSearch tools** - Research tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates (state.json + TODO.md)
- Incrementing `next_artifact_number` via jq
- Linking artifacts in state.json
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
