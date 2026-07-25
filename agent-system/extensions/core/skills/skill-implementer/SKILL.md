---
name: skill-implementer
description: Execute general implementation tasks following a plan. Invoke for general implementation work.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
---

# Implementer Skill

Thin wrapper that delegates general implementation to `general-implementation-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/subagent-continuation-loop.md` - Continuation loop pattern
- Path: `.claude/context/patterns/context-exhaustion-detection.md` - Context exhaustion heuristics
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task type is "general", "meta", or "markdown"
- /implement command is invoked
- Plan exists and task is ready for implementation

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)

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

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

Run the centralized status update script, which atomically updates state.json, TODO.md (task entry + Task Order), and the plan file:

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

**Note**: The script handles all three updates (state.json status/timestamps/session_id, TODO.md `[PLANNED]` -> `[IMPLEMENTING]` in both task entry and Task Order, and plan file status -> `[IMPLEMENTING]`) in a single call. No additional Edit or jq operations are needed.

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
# Ensure task directory exists
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-implementer",
  "task_number": ${task_number},
  "operation": "implement",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since summary stays in the same round as research/plan:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Implement uses (current - 1) to stay in the same round as research/plan
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks: count existing summary artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/summaries/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

**Note**: Implement does NOT increment `next_artifact_number`. Only research advances the sequence.

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

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-implementer"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number from Stage 3a}",
  "effort_flag": "{effort_flag from command, null if not set}",
  "model_flag": "{model_flag from command, null if not set}",
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Note**: The `artifact_number` field tells the agent which sequence number to use for artifact naming (e.g., `01`, `02`). Summary uses the same round number as the research and plan that preceded it.

**Model/Effort Flags**: If `model_flag` is set (haiku, sonnet, opus, fable), pass it as the `model` parameter on the Agent tool to override the agent's frontmatter default. If `effort_flag` is set (fast, hard), include it as prompt context for reasoning depth guidance.

> **CRITICAL: No Source Reading Before Delegation** -- Between preparing the delegation context (Stage 4) and spawning the sub-agent (Stage 5), the lead skill MUST NOT read, grep, glob, or analyze source files. The plan file and state.json are the only files the lead reads. All codebase exploration (reading source files, grepping for patterns, using MCP tools) is the exclusive responsibility of the sub-agent after it is spawned.

---

### Stage 4b: Read and Inject Format Specification

Read the summary format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context, regardless of whether it reads the file itself.

```bash
format_content=$(cat .claude/context/formats/summary-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt (see below).

---

### Stage 5: Invoke Subagent

**Task-lock heartbeat note**: this skill is a thin wrapper that delegates the entire phase loop
to `general-implementation-agent` in a single Agent tool call — it has no per-phase-transition
point of its own to hook a `task-lock.sh heartbeat` call into. The heartbeat refresh lives inside
`general-implementation-agent.md`'s Stage 4D ("Mark Phase Complete"), which fires once per phase
as the subagent progresses through the plan. See `.claude/context/patterns/task-lock.md` for the
full contract.

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "general-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute implementation for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Summary Format Requirements

You MUST follow this format specification exactly when writing the implementation summary.
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

**DO NOT** use `Skill(general-implementation-agent)` - this will FAIL.

The subagent will:
- Load implementation context files
- Parse plan and find resume point
- Execute phases sequentially
- Create/modify files as needed
- Create implementation summary
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5a: Validate Subagent Return Format

If the subagent's text return parses as valid JSON, log a warning (v1 pattern instead of v2 file-based pattern). Non-blocking -- continue to read metadata file regardless.

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value `"implemented"` and the appropriate artifact information.

If you DID use the Agent tool (Stage 5), skip this stage -- the subagent already wrote the metadata.

---

### Stage 5c: Continuation Loop Init

Initialize continuation tracking before entering the postflight loop:

```bash
continuation_count=0
max_continuations=3

# Create loop-guard file to track count across potential interruptions
task_dir="specs/${padded_num}_${project_name}"
cat > "${task_dir}/.continuation-loop-guard" << EOF
{
  "session_id": "${session_id}",
  "continuation_count": 0,
  "max_continuations": 3,
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

**Note**: The loop guard ensures that even if the skill is interrupted between iterations, the next invocation can read the count and enforce the limit.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent (Stage 5) or inline (Stage 5b). Do NOT skip these stages for any reason.

### Continuation Loop

The postflight stages below run inside a loop. Each iteration processes the return from one
subagent execution. If the subagent returns `partial` with a `handoff_path`, a successor
subagent is spawned and the loop continues (up to `max_continuations`).

```
while true; do
```

#### Stage 6: Parse Subagent Return (Read Metadata File)

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")

    # Extract completion_data fields (if present)
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")

    # Extract handoff_path for continuation loop (if present)
    handoff_path=$(jq -r '.partial_progress.handoff_path // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6a: Validate Artifact Content

If subagent status indicates success ("implemented" or "partial") and `artifact_path` is non-empty, validate the summary artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "implemented" ] || [ "$status" = "partial" ]; then
    if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
        echo "Validating summary artifact..."
        if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" summary --fix; then
            echo "WARNING: Summary artifact has format issues (non-blocking). Review output above."
        fi
    fi
fi
```

**Note**: The `--fix` flag attempts auto-repair of missing metadata fields. Validation failures are logged but do not block status update or git commit.

---

#### Stage 6b: Commit Phase Progress (Inside Loop)

After each subagent completes (whether implemented, partial, or failed), commit the work using
targeted, work-scoped staging — never stage the entire working tree. See
`.claude/context/standards/git-staging-scope.md` for the full commit-scope contract.

**Composes with, does not duplicate, per-objective green commits**: `general-implementation-agent`
already commits at every verified-green objective during its own execution (see that agent's
Stage 4B-iii and `.claude/rules/git-workflow.md`'s Commit-Per-Green-Substep Mandate). This
subagent-return-level commit is coarser-grained (fires once per iteration, not per objective) and
is expected to often find nothing new to stage — `git commit` failing with "nothing to commit" is
non-blocking and normal here, not a sign the mandate was skipped.

```bash
task_dir="specs/${padded_num}_${project_name}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")

# Include the plan file explicitly (already covered by task_dir/ above; staged
# explicitly too per the contract)
plan_file=$(ls "${task_dir}"/plans/*.md 2>/dev/null | head -1)
[ -n "$plan_file" ] && stage_paths+=("$plan_file")

# Agent self-reported modified_files (accumulated files_touched from this iteration's subagent)
modified_files_count=0
while IFS= read -r f; do
  if [ -n "$f" ]; then
    stage_paths+=("$f")
    modified_files_count=$((modified_files_count + 1))
  fi
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)

if [ "$modified_files_count" -eq 0 ]; then
  echo "WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually."
fi

git add "${stage_paths[@]}"
git commit -m "task ${task_number} phase ${phases_completed}: implementation progress

Session: ${session_id}
" || echo "Note: Nothing to commit or commit failed (non-blocking)"
```

This ensures each subagent's progress is checkpointed in git before proceeding, without staging
unrelated concurrent-session changes.

---

#### Stage 7: Update Task Status (Postflight)

**If status is "implemented"**:

**Step 1**: Run the centralized status update script to update state.json (status -> "completed", timestamps), TODO.md (`[IMPLEMENTING]` -> `[COMPLETED]` in task entry + Task Order), and plan file (status -> `[COMPLETED]`).

`--phase-check=refuse` engages the script-side phase-accounting backstop. This skill previously
had no phase gate at all: `phases_completed`/`phases_total` are read from the agent's
`.return-meta.json` one stage earlier for the commit message, but were never consulted before
this call. The backstop is deliberately independent of those values — the script resolves the
task's own plan file and counts its `### Phase N: ... [STATUS]` headings itself, exiting 4
without writing anything if any phase is not `[COMPLETED]`:
```bash
postflight_rc=0
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=refuse || postflight_rc=$?
```

**Step 1a (refusal branch)**: If `postflight_rc` is 4 the backstop refused — no state.json write
and no plan-file stamp occurred. Treat this exactly like the `status == "partial"` branch below:
keep the task at `implementing`, record a resume point, and let the next `/implement` invocation
resume from the first incomplete phase. Do NOT retry without the flag, and do NOT hand-edit
state.json to `completed`. Skip Steps 2-3 (completion_summary and roadmap_items are completion
metadata and the task is not complete); Step 4's memory-candidate propagation may still run.
```bash
if [ "$postflight_rc" -eq 4 ]; then
    echo "[implementer] Phase-accounting backstop refused completion for task $task_number: the plan file shows incomplete phases. Task stays [IMPLEMENTING]; re-run /implement to resume." >&2
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson phase "$phases_completed" \
      '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
        last_updated: $ts,
        resume_phase: ($phase + 1)
      }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
elif [ "$postflight_rc" -ne 0 ]; then
    echo "WARNING: update-task-status.sh exited $postflight_rc — manual correction may be needed" >&2
fi
```

**Step 2**: Add completion_summary to state.json (implementer-specific, not covered by centralized script):
```bash
if [ -n "$completion_summary" ]; then
    jq --arg summary "$completion_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).completion_summary = $summary' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Step 3**: Add roadmap_items for non-meta tasks (implementer-specific):
```bash
# For non-meta tasks: add roadmap_items (if present and non-empty)
if [ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    jq --argjson items "$roadmap_items" \
      '(.active_projects[] | select(.project_number == '$task_number')).roadmap_items = $items' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Step 4**: Propagate memory candidates (if any) with append semantics:
```bash
if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
    # Append new candidates to existing array (append semantics, not overwrite)
    jq --argjson new_candidates "$memory_candidates" \
      '(.active_projects[] | select(.project_number == '$task_number')).memory_candidates =
        ((.active_projects[] | select(.project_number == '$task_number')).memory_candidates // []) + $new_candidates' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Note**: Uses `// []` fallback and `+` append so research candidates (from skill-researcher) and implementation candidates coexist on the same task entry.

**Break loop** — proceed to Stage 8 (Link Artifacts).

---

**If status is "partial"**:

Keep status as "implementing" but update resume point. This path remains inline because the centralized `update-task-status.sh` maps `postflight:implement` to "completed" only -- it has no "partial" mapping.

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson phase "$phases_completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase + 1)
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

TODO.md stays as `[IMPLEMENTING]`.

**Update plan file** (if exists): Update the Status field to `[PARTIAL]`:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$project_name" "PARTIAL"
```

**Continuation decision**:

```bash
if [ -n "$handoff_path" ] && [ -f "$handoff_path" ] && [ "$continuation_count" -lt "$max_continuations" ]; then
    # Increment counter and update loop guard
    continuation_count=$((continuation_count + 1))
    jq --argjson count "$continuation_count" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.continuation_count = $count | .last_updated = $ts' \
      "${task_dir}/.continuation-loop-guard" > "${task_dir}/.continuation-loop-guard.tmp" \
      && mv "${task_dir}/.continuation-loop-guard.tmp" "${task_dir}/.continuation-loop-guard"

    # Log handoff for visibility
    echo "Spawning successor subagent (continuation $continuation_count/$max_continuations)"
    echo "Handoff: $handoff_path"

    # Prepare successor delegation context (see Stage 5 for base context)
    # Injected fields:
    # - delegation_depth: incremented by 1
    # - continuation_context: { is_successor: true, continuation_number: N, handoff_path: ..., progress_path: ..., previous_phases_completed: N }

    # Spawn successor subagent via Agent tool with updated context
    # (Same as Stage 5, but with continuation_context injected into delegation context JSON)

    # Continue loop — next iteration reads successor's metadata
    continue
else
    if [ -z "$handoff_path" ]; then
        echo "Partial return with no handoff_path. User must re-run /implement to resume."
    else
        echo "Max continuations ($max_continuations) reached. Returning partial."
    fi
    # Break loop — proceed to Stage 8
    break
fi
```

**If no handoff_path**: Break loop, report partial (user must resume).
**If continuation_count >= max_continuations**: Break loop, report partial (max reached).

---

**If status is "failed"**:

Keep status as "implementing" for retry. Do not update plan file (leave as `[IMPLEMENTING]` for retry).

**Break loop** — proceed to Stage 8.

```
done  # End Continuation Loop
```

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing summary artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new summary artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md** (if implemented): Regenerate from state.json (state.json artifact update was done in the previous step):

```bash
bash .claude/scripts/generate-todo.sh || echo "WARNING: generate-todo.sh failed (non-fatal)" >&2
```

If the script exits non-zero, log a warning but continue (regeneration errors are non-blocking).

---

### Stage 8a: Lifecycle TTS Notification

Fire TTS and WezTerm tab coloring after artifact linking is complete:

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
    bash "$lifecycle_script" "$STATE_STATUS" &
fi
```

Non-blocking: called in background after artifacts are linked. Speaks "Tab N STATUS"
(e.g., "Tab 3 completed") to announce the lifecycle transition.

---

### Stage 9: Git Commit

Commit changes with session ID, using targeted staging (never stage the entire working tree)
per `.claude/context/standards/git-staging-scope.md`:

```bash
task_dir="specs/${padded_num}_${project_name}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")

# Include the plan file explicitly (already covered by task_dir/ above)
plan_file=$(ls "${task_dir}"/plans/*.md 2>/dev/null | head -1)
[ -n "$plan_file" ] && stage_paths+=("$plan_file")

# Agent self-reported modified_files
modified_files_count=0
while IFS= read -r f; do
  if [ -n "$f" ]; then
    stage_paths+=("$f")
    modified_files_count=$((modified_files_count + 1))
  fi
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)

if [ "$modified_files_count" -eq 0 ]; then
  echo "WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually."
fi

git add "${stage_paths[@]}"
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}
"
```

**Note**: This inline commit and `orchestrator-postflight.sh` Stage 9 both exist in the
pipeline (this skill runs its own postflight inline rather than delegating to the shared
script); both now follow the same targeted-staging contract in
`.claude/context/standards/git-staging-scope.md`, so their descriptions no longer diverge.

---

### Stage 10: Cleanup

Cleanup runs **after** the continuation loop exits. The `.postflight-pending` marker persists across loop iterations to ensure the SubagentStop hook fires correctly.

Remove marker, metadata, and loop-guard files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.continuation-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Implementation completed for task {N}:
- All {phases_total} phases executed successfully
- Key changes: {summary of changes}
- Created summary at specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed
```

---

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **Input validation errors**: Return immediately with error message
- **Metadata file missing**: Keep status as "implementing", do not cleanup marker, report to user
- **Git commit failure**: Non-blocking (log and continue)
- **Subagent timeout**: Return partial status, keep "implementing" for resume

## Pre-Delegation Boundary

Before spawning the implementation sub-agent, this skill MUST NOT:

1. **Read source files** - Source files are read by the sub-agent, not the lead
2. **Grep or glob the codebase** - Codebase exploration is sub-agent work
3. **Use MCP tools** - Domain tools (LSP, build, etc.) are for sub-agent use only
4. **Analyze source code** - Code analysis belongs to the implementation agent
5. **Run build or test commands** - Verification is done by the sub-agent

The pre-delegation phase is LIMITED TO:
- Reading the plan file to locate phases and extract the plan path
- Reading state.json and TODO.md for status updates
- Preparing the delegation context JSON
- Reading the summary format file for injection (Stage 4b)
- Spawning the sub-agent with the Agent tool

## MUST NOT (Postflight Boundary)

After the agent returns -- whether with status implemented, partial, or failed -- this skill MUST proceed immediately to Stage 6 (read metadata file). The skill MUST NOT:

1. **Read source files** - Source files were the subagent's responsibility
2. **Edit source files** - All implementation work is done by the subagent
3. **Run build/test commands** - Verification is done by the subagent
4. **Use MCP tools** - Domain tools are for subagent use only
5. **Grep or glob the codebase** - Analysis is subagent work
6. **Write summary/reports** - Artifact creation is done by the subagent

> **Continuation Policy**: If the subagent returned `partial` status **WITH** a `handoff_path` in its metadata, the lead skill **MAY** spawn a successor subagent to continue the work automatically (see Continuation Loop in Postflight). This is the preferred path for context exhaustion recovery.
>
> If the subagent returned `partial` status **WITHOUT** a `handoff_path`, the lead skill MUST report partial and let the user re-run `/implement` to resume.
>
> If the subagent returned `failed` status, the lead skill MUST NOT attempt to continue or "fill in" the subagent's work. Report the failure and let the user investigate.

The postflight phase is LIMITED TO:
- Reading agent metadata file (.return-meta.json)
- Updating state.json via jq
- Updating TODO.md status marker via Edit or script
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
