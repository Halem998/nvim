---
name: skill-planner
description: Create phased implementation plans from research findings. Invoke when a task needs an implementation plan.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
# Original context (now loaded by subagent):
#   - .claude/context/formats/plan-format.md
#   - .claude/context/workflows/task-breakdown.md
# Original tools (now used by subagent):
#   - Read, Write, Edit, Glob, Grep
---

# Planner Skill

Thin wrapper that delegates plan creation to `planner-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task status is any non-terminal state (not completed, not abandoned)
- /plan command is invoked
- Implementation approach needs to be formalized

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow planning

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Validate status (only block terminal states)
if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
  return error "Task is in terminal state [$status]"
fi
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-planner"
operation="plan"
```

This skill supplies the shared block's preconditions: `task_number`, `padded_num`,
`project_name`, `session_id`, `operation`, `skill_name`. Follow the shared block's ordering and
failure-semantics rules exactly — do not re-inline the `update-task-status.sh preflight` call or
the `.postflight-pending` heredoc here.

---

### Stage 3a: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since plan stays in the same round as research:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Plan uses (current - 1) to stay in the same round as research
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/plans/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
elif [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Reconciliation: scan all task subdirs for max artifact number on disk
# Handles legacy tasks where next_artifact_number may be behind actual files
padded_num=$(printf "%03d" "$task_number")
max_on_disk=$(find "specs/${padded_num}_${project_name}" -name "[0-9][0-9]_*.md" 2>/dev/null \
  | sed 's|.*/\([0-9][0-9]\)_.*|\1|' | sort -n | tail -1)
max_on_disk=${max_on_disk:-0}
# Strip leading zeros to avoid octal interpretation
max_on_disk=$((10#$max_on_disk))
if [ "$artifact_number" -le "$max_on_disk" ]; then
  artifact_number=$((max_on_disk + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")

# Collision check: ensure no existing file uses this prefix in plans/
while ls "specs/${padded_num}_${project_name}/plans/${artifact_padded}_"*.md 2>/dev/null | grep -q .; do
  artifact_number=$((artifact_number + 1))
  artifact_padded=$(printf "%02d" "$artifact_number")
done
```

**Note**: Plan does NOT increment `next_artifact_number` in state.json. Only research (and revision) advances the sequence. Plan uses `(current - 1)` to share the same round number as the preceding research.

---

### Stage 4a: Memory Retrieval (Auto)

Retrieve relevant memories from the memory system to inject into the delegation context.

**Skip if**: `clean_flag` is true in the delegation context (from `--clean` command flag).

```bash
# Check clean_flag
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi

# memory_context will be empty string if:
# - clean_flag is true (skipped)
# - memory-index.json missing or empty
# - no keywords matched any entries
# - script exited with error
```

If `memory_context` is non-empty, it will be injected into the Stage 5 prompt alongside the format specification from Stage 4b. If empty, no memory block is injected.

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

**Prior plan discovery**: Find the latest existing plan file (if any) to pass as reference context.

```bash
# Discover prior plan (if any)
padded_num=$(printf "%03d" "$task_number")
prior_plan_path=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
# prior_plan_path will be empty if no prior plans exist
```

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "plan", "skill-planner"],
  "timeout": 1800,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number from Stage 3a}",
  "effort_flag": "{effort_flag from command, null if not set}",
  "model_flag": "{model_flag from command, null if not set}",
  "roadmap_flag": "{roadmap_flag from command, false if not set}",
  "research_path": "{path to research report if exists}",
  "prior_plan_path": "{path to latest prior plan if exists}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Note**: The `artifact_number` field tells the agent which sequence number to use for artifact naming (e.g., `01`, `02`). Plan uses `(next_artifact_number - 1)` to share the same round as the preceding research.

**Model/Effort Flags**: If `model_flag` is set (haiku, sonnet, opus, fable), pass it as the `model` parameter on the Agent tool to override the agent's frontmatter default. If `effort_flag` is set (fast, hard), include it as prompt context for reasoning depth guidance.

---

### Stage 4b: Read and Inject Format Specification

Read the plan format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context, regardless of whether it reads the file itself.

```bash
format_content=$(cat .claude/context/formats/plan-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt (see below).

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "planner-agent"
  - prompt: [Include task_context, delegation_context, research_path, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute planning for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Plan Format Requirements

You MUST follow this format specification exactly when writing the plan artifact.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

Place this section AFTER the delegation context JSON and BEFORE any other instructions.

**Memory Context Injection**: If `memory_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

```
{memory_context from Stage 4a -- already wrapped in <memory-context> tags}
```

Place the memory context block AFTER the format specification and BEFORE the task-specific instructions. Do NOT inject an empty `<memory-context>` block when no memories were retrieved.

**Literature Briefing Injection**: If `lit_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

```
{lit_context from Stage 4a -- already wrapped in <literature-briefing> tags}
```

Place the literature briefing block AFTER the memory context block (if any) and BEFORE the task-specific instructions. Do NOT inject an empty `<literature-briefing>` block when no literature briefing was generated.

**DO NOT** use `Skill(planner-agent)` - this will FAIL.

The subagent will:
- Load planning context files
- Analyze task requirements and research
- Decompose into logical phases
- Identify risks and mitigations
- Create plan in `specs/{NNN}_{SLUG}/plans/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"planned"`.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent (Stage 5) or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return (Read Metadata File)

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
    memory_candidates="[]"
fi
```

**Note**: `memory_candidates` is read here so Stage 7a below can propagate it — this read did not
exist before this skill was converted onto the shared skeleton, closing a gap where
`planner-agent`-emitted candidates were silently discarded.

---

### Stage 6a: Validate Artifact Content

If subagent status is "planned" and `artifact_path` is non-empty, validate the plan artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "planned" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating plan artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" plan --fix; then
        echo "WARNING: Plan artifact has format issues (non-blocking). Review output above."
    fi
fi
```

**Note**: The `--fix` flag attempts auto-repair of missing metadata fields. Validation failures are logged but do not block status update or git commit.

---

### Stage 7: Update Task Status (Postflight)

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 7 (postflight status update):

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
```

**On partial/failed**: Keep status as "planning" for resume — `skill_postflight_update` already
no-ops on a non-success status.

---

### Stage 7a: Propagate Memory Candidates

**New for this skill** — see the Stage 6 note above: `skill-planner` had no Stage 7a before this
conversion, and `planner-agent`-emitted `memory_candidates` were silently discarded. Follow
`@.claude/context/patterns/skill-postflight-flow.md`'s Stage 7a:

```bash
skill_propagate_memory_candidates "$task_number" "$memory_candidates" "$session_id"
```

---

### Stage 8, 8a: Artifact Linking, Lifecycle Notify

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 8 (artifact linking) and
Stage 8a (TTS notify):

```bash
field_name='**Plan**'
next_field='**Description**'
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" \
  "$field_name" "$next_field" "$session_id"
skill_lifecycle_notify "$status"
```

**Not covered here**: the shared block's own Stage 9 (cleanup) is deliberately NOT invoked at
this point — this skill's numbering interleaves a Git Commit stage (below) between TTS notify and
cleanup, so cleanup is called explicitly at the existing **Stage 10: Cleanup** heading below
instead of through this import.

---

### Stage 9: Git Commit

Apply the `plan` scope from `.claude/context/standards/git-staging-scope.md` — targeted staging,
never a repo-wide add — then commit via `.claude/scripts/git-commit-scoped.sh`, the single
sanctioned implementation of path-scoped, mutex-serialized committing. This matters here
specifically because multi-task `/plan N,N,N` dispatches planner agents in one batch — a
genuinely concurrent site, not merely a defensive one:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: create implementation plan" \
  --session "${session_id}" \
  -- "specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json"
```

---

### Stage 10: Cleanup

Remove marker and metadata files via the shared function (see
`@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 for the full behavior — called
here rather than at that block's own import point because this skill's Stage 9 is Git Commit,
not cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Plan created for task {N}:
- {phase_count} phases defined, {estimated_hours} hours estimated
- Key phases: {phase names}
- Created plan at specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found or status invalid.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "planning"
2. Do not cleanup postflight marker
3. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### jq Parse Failure
If jq commands fail with INVALID_CHARACTER or syntax error (Issue #1132):
1. Log to errors.json via `errors-append.sh append` (the single validated, `flock`'d writer --
   see `context/formats/errors-format.md`):
```bash
.claude/scripts/errors-append.sh append \
  --type jq_parse_failure --severity medium \
  --message "jq parse error in postflight artifact linking" \
  --session "$session_id" --command /plan --task "$task_number" --checkpoint GATE_OUT \
  --suggested-action "Use two-step jq pattern from jq-escaping-workarounds.md" \
  --auto-recoverable true
```
2. Retry with two-step pattern (already implemented in Stage 8)

### Subagent Timeout
Return partial status if subagent times out (default 1800s).
Keep status as "planning" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All planning work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use research tools** - Web/codebase search is for agent use only
4. **Analyze task requirements** - Analysis is agent work
5. **Write plan files** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating status via `update-task-status.sh` (handles state.json + TODO.md atomically)
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Plan created for task {N}:
- 5 phases defined, 2.5 hours estimated
- Covers: agent structure, execution flow, error handling, examples, verification
- Created plan at specs/{NNN}_create_planner_agent/plans/MM_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session sess_1736700000_abc123
```

Example partial return:
```
Plan partially created for task {N}:
- 3 of 5 phases defined before timeout
- Partial plan saved at specs/{NNN}_create_planner_agent/plans/MM_{short-slug}.md
- Status remains [PLANNING] - run /plan {N} to complete
```
