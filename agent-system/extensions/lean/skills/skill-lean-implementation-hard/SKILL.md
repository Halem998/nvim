---
name: skill-lean-implementation-hard
description: Implement Lean 4 proofs using hard-mode behavioral contracts with per-phase dispatch and sorry inventory tracking. Invoke for Lean-language implementation tasks when hard-mode is requested.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Lean Implementation Hard Skill

Thin wrapper that delegates Lean 4 hard-mode proof implementation to
`lean-implementation-hard-agent` subagent with per-phase dispatch context.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent
returns, this skill handles all postflight operations (status update, artifact linking,
sorry_inventory propagation, git commit) before returning.

Hard mode activates H2 (anti-analysis with formal proof line bar) and H9 (sorry inventory
tracking with orchestrator handoff JSON at every dispatch). Cost is approximately 3-5x
standard lean4 implementation.

## Trigger Conditions

This skill activates when:
- Task type is "lean4" or "lean" (either accepted)
- `/implement N --hard` is invoked for a lean4 task
- Dispatched from `skill-orchestrate-hard` via per-phase dispatch mode
- Routed by `command-route-skill.sh` via `routing_hard.implement.lean4`

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)
- Task type must be lean4/lean

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

# Validate task_type (accept both "lean" and "lean4")
if [ "$task_type" != "lean" ] && [ "$task_type" != "lean4" ]; then
  return error "Task $task_number is not a Lean task (got: $task_type)"
fi

# Check terminal states
if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
  return error "Task $task_number is in terminal state: $status"
fi
```

---

### Stage 1.5: Hard-Mode Cost Note

Before proceeding, emit the cost note for session tracking:

```
[hard-mode] skill-lean-implementation-hard activated (session flag: hard)
Cost multiplier: ~3-5x standard lean4 implementation
Behavioral contracts: H2 (formal proof line bar), H9 (sorry inventory tracking)
Per-phase dispatch: each agent invocation handles exactly one plan phase
```

---

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

---

### Stage 3: Plan Resolution and Phase Identification

Find the latest plan file and identify the next incomplete phase for per-phase dispatch:

```bash
# Find latest plan
padded_num=$(printf "%03d" "$task_number")
plan_file=$(ls "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)

if [ -z "$plan_file" ]; then
  return error "No plan file found for task $task_number"
fi

# Read plan to find next incomplete phase
# Look for first [NOT STARTED] or [IN PROGRESS] or [PARTIAL] phase heading
next_phase=$(grep -n "### Phase [0-9]*:.*\[NOT STARTED\]\|### Phase [0-9]*:.*\[IN PROGRESS\]\|### Phase [0-9]*:.*\[PARTIAL\]" \
  "$plan_file" | head -1)

# Extract phase number
phase_number=$(echo "$next_phase" | grep -oP "Phase \K[0-9]+")

# Read handoff for per-phase dispatch context (territory, continuation_context)
handoff_file=$(ls "specs/${padded_num}_${project_name}/.orchestrator-handoff.json" 2>/dev/null | head -1)
territory=null
continuation_context=null

if [ -f "$handoff_file" ] && jq empty "$handoff_file" 2>/dev/null; then
  territory=$(jq -c '.territory // null' "$handoff_file")
  continuation_context=$(jq -c '.continuation_context // null' "$handoff_file")
  # Import sorry_inventory from previous handoff for propagation
  prev_sorry_inventory=$(jq -c '.sorry_inventory // []' "$handoff_file")
fi
```

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent with per-phase dispatch parameters:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-lean-implementation-hard"],
  "timeout": 7200,
  "effort_flag": "hard",
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "lean4"
  },
  "plan_path": "specs/{N}_{SLUG}/plans/MM_{short-slug}.md",
  "phase_number": {N_or_null},
  "territory": {territory_or_null},
  "continuation_context": {continuation_context_or_null},
  "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "lean-implementation-hard-agent"
  - model: "opus"
  - prompt: [Include task_context, delegation_context, plan_path, phase_number,
             territory, continuation_context, metadata_file_path]
  - description: "Execute hard-mode Lean implementation for task {N} phase {P}"
```

**DO NOT** use `Skill(lean-implementation-hard-agent)` - this will FAIL.

The subagent will:
- Apply H2 anti-analysis contract (formal proof line bar within 30% of tool calls)
- Apply H9 wrap-up discipline (sorry_inventory in every dispatch end)
- Implement ONLY the specified phase (per-phase focus)
- Use lean_goal before and after each tactic application
- Use lean_multi_attempt before applying edits
- Run final verification (sorry check, axiom check, lake build)
- Write `.orchestrator-handoff.json` with sorry_inventory
- Create implementation summary
- Write metadata to `specs/{N}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool, you MUST write a
`.return-meta.json` file now before proceeding to postflight.

If you DID use the Agent tool, skip this stage.

---

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")

    # Read verification results (agent is responsible for verification)
    verification_passed=$(jq -r '.verification.verification_passed // false' "$metadata_file")
    sorry_count=$(jq -r '.verification.sorry_count // 0' "$metadata_file")

    # Read sorry_inventory from agent output
    sorry_inventory=$(jq -c '.sorry_inventory // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
    verification_passed="false"
    sorry_inventory="[]"
fi
```

---

### Stage 6a: Plan Compliance Check (Read from Metadata)

**This stage only runs if status from metadata is "implemented".**

Read the agent-reported compliance result from metadata:

```bash
if [ "$status" = "implemented" ]; then
    compliance_check=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file" 2>/dev/null)

    case "$compliance_check" in
        "failed")
            echo "Stage 6a: Plan compliance check FAILED (agent reported)"
            status="partial"
            ;;
        "passed")
            echo "Stage 6a: Plan compliance check PASSED"
            ;;
        "skipped"|*)
            echo "Stage 6a: INFO — compliance_check absent or skipped; proceeding"
            ;;
    esac
fi
```

---

### Stage 6b: Sorry Inventory Propagation

After agent returns, propagate sorry_inventory to `.orchestrator-handoff.json`:

```bash
handoff_file="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"

if [ -f "$handoff_file" ] && jq empty "$handoff_file" 2>/dev/null; then
    # Merge with previous sorry_inventory (prev + new — resolved)
    # The agent writes the authoritative sorry_inventory to the handoff JSON
    echo "Stage 6b: sorry_inventory propagated via agent handoff JSON"
    echo "  Current sorry count: $(echo "$sorry_inventory" | jq 'length')"
else
    echo "Stage 6b: WARNING — no .orchestrator-handoff.json found"
    echo "  Agent should have written this file. Check agent output."
fi
```

---

### Stage 7: Update Task Status (Postflight)

**If status is "implemented" AND verification_passed is true AND sorry_count is 0**:

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
```

Then add completion_data to state.json:
```bash
completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")

if [ -n "$completion_summary" ]; then
    jq --arg summary "$completion_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).completion_summary = $summary' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**If status is "partial"**:
Keep status as "implementing" but note sorry_inventory and phase progress.
TODO.md stays as `[IMPLEMENTING]`.

**If verification_passed is false**:
Keep status as "implementing" for resume.

---

### Stage 8: Link Artifacts

Add summary artifact to state.json. Update TODO.md per
`@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`,
`next_field=**Description**`.

```bash
summary_artifact_path=$(jq -r '.artifacts[] | select(.type == "summary") | .path' "$metadata_file" 2>/dev/null | head -1)
summary_artifact_summary=$(jq -r '.artifacts[] | select(.type == "summary") | .summary' "$metadata_file" 2>/dev/null | head -1)

if [ -n "$summary_artifact_path" ]; then
    jq --arg path "$summary_artifact_path" \
       --arg summary "$summary_artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": "summary", "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

---

### Stage 9: Git Commit

```bash
git add \
  "Theories/" \
  "specs/${padded_num}_${project_name}/summaries/" \
  "specs/${padded_num}_${project_name}/plans/" \
  "specs/${padded_num}_${project_name}/.orchestrator-handoff.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}"
```

---

### Stage 10: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Hard-mode Lean implementation completed for task {N}:
- Phase {P} implemented with H2 and H9 contracts enforced
- Proofs: {theorem names} all sorry-free
- Sorry inventory: {count} entries / {count} resolved this dispatch
- Lake build: Success
- Created summary at specs/{N}_{SLUG}/summaries/MM_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found, wrong language, or terminal state.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "implementing"
2. Report error to user

### Sorry Inventory Mismatch
If agent wrote sorry_inventory but metadata doesn't contain it:
1. Read `.orchestrator-handoff.json` directly for sorry_inventory
2. Log warning: "sorry_inventory read from handoff file, not metadata"

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 7200s).
Keep status as "implementing" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All Lean proof work is done by agent
2. **Run lake build** - Build verification is done by agent
3. **Use MCP tools** - lean-lsp tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work
6. **Re-run sorry inventory scan** - Agent populates sorry_inventory
7. **Resolve sorry entries** - That is agent implementation work

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT
> attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed
> status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Reading agent handoff JSON for sorry_inventory
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the
file and processed internally.
