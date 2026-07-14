---
name: skill-pr-review-research
description: Fetch GitHub PR and Zulip thread data for pr-type review tasks. Invoke for pr research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# PR Review Research Skill

Thin wrapper that validates inputs, extracts the `sources` array from state.json,
and delegates to `pr-review-research-agent` to fetch GitHub and Zulip data.

## Trigger Conditions

This skill activates when:
- Task type is "pr"
- `/research` command targets a pr-type review task
- The task was created by `/pr --review` and has a `sources` array in state.json

## Execution Flow

### Stage 1: Input Validation

Validate that:
1. `task_number` exists and resolves to an active project in state.json
2. `task_type` is `"pr"`
3. The task has a `sources` array with at least one entry

```bash
# Check task exists and get task_type
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type' \
  specs/state.json)

if [ "$task_type" != "pr" ]; then
  echo "Error: Task $task_number has type '$task_type', not 'pr'. skill-pr-review-research only handles pr tasks."
  exit 1
fi

# Check sources array is present and non-empty
sources_count=$(jq --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .sources // [] | length' \
  specs/state.json)

if [ "$sources_count" -eq 0 ]; then
  echo "Error: Task $task_number has no sources. Tasks created by /pr --review populate sources in state.json."
  exit 1
fi
```

### Stage 2: Preflight Status Update

Update status to "researching" BEFORE invoking subagent:

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

### Stage 3: Create Postflight Marker

```bash
touch "specs/{NNN}_{SLUG}/.postflight-pending"
```

### Stage 3a: Read Artifact Number

Read `next_artifact_number` from state.json with reconciliation pattern. Use this for
naming the report file (zero-padded to 2 digits, e.g., `01`).

```bash
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)
artifact_number_padded=$(printf "%02d" "$artifact_number")
```

### Stage 4: Prepare Delegation Context

Build the delegation JSON with PR-specific fields:

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-pr-review-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "pr"
  },
  "sources": [
    {
      "type": "github_pr",
      "url": "https://github.com/owner/repo/pull/123",
      "parsed": {
        "owner": "owner",
        "repo": "repo",
        "pr_number": 123
      }
    }
  ],
  "artifact_number": "01",
  "focus_prompt": "{optional focus, or null}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

Extract `sources` from state.json:

```bash
sources=$(jq -c --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .sources // []' \
  specs/state.json)
```

Note: Use `jq -c` (compact output) for inline JSON in delegation context.
Use the safe `select(.project_number == $num)` pattern (not `!=`) per jq-escaping-workarounds.md.

### Stage 4a: Memory Retrieval (Optional)

If `--clean` flag is NOT set, retrieve relevant memories:

```bash
memory_context=$(bash .claude/scripts/memory-retrieve.sh "pr review github zulip research" 2>/dev/null || echo "")
```

Include `memory_context` in the delegation context if non-empty.

### Stage 5: Invoke Subagent

Use the Agent tool with:
- `subagent_type: "pr-review-research-agent"`
- Prompt: the prepared delegation JSON

The subagent will:
1. Write early metadata to `.return-meta.json`
2. Fetch GitHub PR data (4 endpoints)
3. Optionally fetch Zulip thread data
4. Write research report to `specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md`
5. Write final metadata to `.return-meta.json`
6. Return brief text summary

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with `status: "researched"` and include the report artifact.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return

Read the metadata file:

```bash
cat "specs/{NNN}_{SLUG}/.return-meta.json"
```

Check `status` field:
- `"researched"` -> success, proceed normally
- `"partial"` -> partial success, note in status update
- `"failed"` -> failure, update status accordingly

### Stage 6a: Validate Artifact Content (Non-Blocking)

```bash
report_path="specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md"
if [ -f "$report_path" ] && [ -s "$report_path" ]; then
  echo "Report artifact validated: $report_path"
else
  echo "Warning: Report artifact missing or empty at $report_path"
fi
```

### Stage 7: Update Task Status (Postflight)

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
```

### Stage 7a: Propagate Memory Candidates

If `.return-meta.json` contains `memory_candidates` array with entries, pass them to the
memory vault:

```bash
# Extract and process memory candidates from subagent metadata
memory_candidates=$(jq -c '.memory_candidates // []' "specs/{NNN}_{SLUG}/.return-meta.json")
if [ "$memory_candidates" != "[]" ]; then
  # Log candidates for /learn --task N to harvest later
  echo "Memory candidates available: $memory_candidates"
fi
```

### Stage 8: Link Artifacts in state.json

Add the research report artifact to state.json and regenerate TODO.md:

```bash
# Link report artifact
report_path="specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md"
report_summary=$(jq -r '.artifacts[0].summary // "PR review research report"' \
  "specs/{NNN}_{SLUG}/.return-meta.json")

# Update state.json with artifact
jq --argjson num "$task_number" \
   --arg path "$report_path" \
   --arg summary "$report_summary" \
  '.active_projects |= map(if .project_number == $num then
    . + {"artifacts": ((.artifacts // []) + [{"type": "report", "path": $path, "summary": $summary}]),
         "next_artifact_number": ((.next_artifact_number // 1) + 1)}
    else . end)' \
  specs/state.json > /tmp/state.tmp && mv /tmp/state.tmp specs/state.json

# Regenerate TODO.md
bash .claude/scripts/generate-todo.sh
```

### Stage 8a: TTS Lifecycle Notification

```bash
bash .claude/scripts/lifecycle-notify.sh "research" "$task_number" "researched" 2>/dev/null || true
```

### Stage 9: Cleanup Marker Files

```bash
rm -f "specs/{NNN}_{SLUG}/.postflight-pending"
rm -f "specs/{NNN}_{SLUG}/.return-meta.json"
```

### Stage 10: Return Brief Text Summary

Return 3-6 bullet points summarizing:
- Sources fetched (GitHub PR: N reviews, N comments)
- Zulip status (fetched N messages / skipped: unconfigured)
- Report artifact path
- Key findings (open questions count, requested changes count)

Do NOT return JSON.

## Return Format

Brief text summary (NOT JSON).
