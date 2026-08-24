# Postflight Control Pattern

## Overview

This pattern enables uninterrupted workflow execution by using a marker file to signal when postflight operations are pending. The SubagentStop hook checks for this marker and blocks premature termination.

## Purpose

Claude Code skill returns can bypass the invoking skill and return directly to the main session (GitHub Issue #17351). This pattern uses a marker file to ensure postflight operations execute after subagent return.

## Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  SKILL EXECUTION FLOW                                       │
│                                                             │
│  1. Skill creates postflight marker                         │
│  2. Skill invokes subagent via Agent tool                    │
│  3. Subagent executes and returns                          │
│  4. SubagentStop hook detects marker → blocks stop          │
│  5. Skill continues with postflight operations              │
│  6. Skill removes marker                                    │
│  7. Normal stop allowed                                     │
└─────────────────────────────────────────────────────────────┘
```

## Unconditional Postflight Execution

Postflight stages (status update, artifact linking, git commit, cleanup) MUST execute after Stage 5 regardless of whether work was done by a subagent or inline. This is enforced through:

1. **Stage 5b fallback**: If the skill executor performed work inline without the Agent tool, it writes `.return-meta.json` manually before postflight begins.
2. **"ALWAYS EXECUTE" header**: Postflight stages are marked with `## Postflight (ALWAYS EXECUTE)` to make the unconditional requirement visually prominent.
3. **Marker file**: Created before Stage 5 and cleaned up at Stage 10 regardless of execution path. The SubagentStop hook is a complementary safety net that prevents premature termination, but it is NOT the primary trigger for postflight -- the skill's instruction flow is.

**Key invariant**: After any work is completed (Stage 5 or Stage 5b), a valid `.return-meta.json` file exists, and postflight stages can proceed identically regardless of how the work was done.

## Marker File Protocol

### Location

```
specs/{NNN}_{SLUG}/.postflight-pending
```

Where `{N}` is the task number and `{SLUG}` is the project name (e.g., `specs/259_prove_completeness/.postflight-pending`).

This task-scoped location enables safe concurrent agent execution on different tasks while maintaining single-agent-per-task guarantees.

### Format

```json
{
  "session_id": "sess_1736700000_abc123",
  "skill": "skill-lean-research",
  "task_number": 259,
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "2026-01-18T10:00:00Z",
  "stop_hook_active": false
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `session_id` | Yes | Current session identifier |
| `skill` | Yes | Name of skill that created marker |
| `task_number` | Yes | Task being processed |
| `operation` | Yes | Operation type (research, plan, implement) |
| `reason` | Yes | Human-readable description of pending work |
| `created` | Yes | ISO 8601 timestamp |
| `stop_hook_active` | No | Set to true to bypass hook (prevents loops) |

## Skill Integration

### Creating the Marker (Before Subagent Invocation)

```bash
# Ensure task directory exists
mkdir -p "specs/${padded_num}_${project_name}"

# Create postflight marker in task directory
cat > "specs/${padded_num}_${project_name}/.postflight-pending" << 'EOF'
{
  "session_id": "$session_id",
  "skill": "skill-lean-research",
  "task_number": $task_number,
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

### Removing the Marker (After Postflight Complete)

```bash
# Remove marker after postflight is complete
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
```

### Emergency Bypass (If Stuck in Loop)

```bash
# Set stop_hook_active to force stop on next iteration
marker_file=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)
if [ -n "$marker_file" ]; then
    jq '.stop_hook_active = true' "$marker_file" > specs/tmp/marker.json && \
      mv specs/tmp/marker.json "$marker_file"
fi
```

## SubagentStop Hook Behavior

The hook at `.claude/hooks/subagent-postflight.sh`:

1. **Searches for marker file**: Uses `find specs -maxdepth 3 -name ".postflight-pending"` to locate task-scoped markers
2. **Falls back to global marker**: For backward compatibility, checks `specs/.postflight-pending` if no task-scoped marker found
3. **If marker exists**:
   - Checks `stop_hook_active` flag (bypass if true)
   - Checks loop guard counter (max 3 continuations)
   - Returns `{"decision": "block", "reason": "..."}` to continue execution. The reason is the
     marker's own `.reason` field when present, `"Postflight operations pending"` when the
     marker parses but has no `.reason`, or a diagnostic naming the marker path and jq's parse
     error when the marker fails to parse as JSON at all (see "The `jq //` Parse-Error Hazard"
     below) -- the three cases are textually distinguishable from each other.
4. **If no marker**: Returns `{}` to allow normal stop

### Loop Guard

To prevent infinite loops, the hook maintains a counter in the task directory:
- Location: `specs/{NNN}_{SLUG}/.postflight-loop-guard` (same directory as marker)
- Incremented on each blocked stop
- After 3 continuations, cleanup and allow stop
- Reset when marker is removed normally

### The `jq //` Parse-Error Hazard

jq's `//` alternative operator (`.field // default`) only fires when the left-hand field is
**absent or `null`** -- it never fires on a JSON *parse* error. A pipeline such as
`jq -r '.reason // "some default"' "$FILE" 2>/dev/null` therefore collapses two different
situations into the same default string: "the file parsed but had no `.reason`" and "the file
did not parse as JSON at all" (with `2>/dev/null` additionally swallowing jq's own diagnostic in
the latter case). The rule this codebase follows: **`// "non-empty default"` is only safe when
preceded by an explicit `jq empty "$FILE"` parse-validity check** that branches the parse-failure
case separately; `// empty` (or `// ""` in a caller that already treats empty as a no-op) is safe
**unguarded**, because the absent-field and parse-error cases collapse to the identical caller
behavior (empty string) either way, so there is nothing to distinguish.

**Survey outcome** (core hook files, `agent-system/extensions/core/hooks/*.sh`, re-counted at
implementation time): 52 occurrences of the `jq -r '... // ...'` idiom across 13 files. Of these,
49 use `// empty` (including 2 field-name fallback chains that terminate in `// empty`, in
`validate-no-task-references.sh`), and 2 use `// ""` in callers (`wezterm-preflight-status.sh`,
`wezterm-task-number.sh`) that already treat an empty prompt as a no-op. All 51 are
tolerant-by-design under the rule above and were deliberately left unchanged. Exactly **one**
site had a non-empty, semantically load-bearing default with no preceding parse-validity guard:
`subagent-postflight.sh`'s block-reason extraction -- the fixed site, now guarded by `jq empty`
per the pattern above.

### Consistency Between the Two Hooks on a Malformed Marker

Both `subagent-postflight.sh` and `events-log-lifecycle.sh`'s SubagentStop branch detect a
malformed (non-parsing) `.postflight-pending` marker the same way, via `jq empty "$MARKER_FILE"`.
They diverge in what they do with the detection, intentionally: `subagent-postflight.sh` is a
**control channel** and blocks the stop with a diagnostic reason naming the marker path and jq's
parse error, so the subagent sees why it was blocked. `events-log-lifecycle.sh` is a
**telemetry** channel that must never block, so it instead logs exactly one
`malformed_postflight_marker` / `deviation` event to `specs/events.jsonl` (recovering the task
number from the marker's parent directory name and the session_id from that task's
`specs/state.json` entry) and always echoes `{}`. One remaining silent case is shared by both:
if no `session_id` can be resolved for the task (e.g. the task has since been archived or
vaulted), `events-log-lifecycle.sh` exits cleanly with no event -- `session_id` is
schema-required and pattern-constrained, so there is no placeholder value to substitute. This is
a narrowing of the previously-silent window, not its elimination.

## Complete Skill Example

```markdown
## Skill Execution Flow

### Stage 1: Create Postflight Marker

Before invoking the subagent, create the marker file:

\`\`\`bash
# Ensure task directory exists
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-lean-research",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
\`\`\`

### Stage 2: Invoke Subagent

Invoke the subagent via Agent tool as normal.

### Stage 3: Subagent Returns

Subagent writes metadata to `.return-meta.json` and returns brief summary.

### Stage 4: Execute Postflight (Hook Ensures We Reach Here)

1. Read `.return-meta.json`
2. Update state.json status
3. Update TODO.md status
4. Link artifacts
5. Git commit changes

### Stage 5: Cleanup

\`\`\`bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
\`\`\`

### Stage 6: Return Brief Summary

Return a brief 3-6 bullet summary (NO JSON).
```

## Debugging

### View Hook Logs

```bash
cat .agent-logs/subagent-postflight.log
```

### Check Marker State

```bash
# Find and display current marker
marker=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)
if [ -n "$marker" ]; then
    echo "Marker found at: $marker"
    cat "$marker" | jq .
else
    echo "No postflight marker found"
fi
```

### Check Loop Guard

```bash
# Find and display loop guard
guard=$(find specs -maxdepth 3 -name ".postflight-loop-guard" -type f | head -1)
if [ -n "$guard" ]; then
    echo "Loop guard at: $guard"
    cat "$guard"
else
    echo "No loop guard found"
fi
```

### Manual Cleanup (Emergency)

```bash
# Clean specific task
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"

# Clean all orphaned markers (across all tasks)
find specs -maxdepth 3 -name ".postflight-pending" -delete
find specs -maxdepth 3 -name ".postflight-loop-guard" -delete
```

## Error Scenarios

### Scenario 1: Hook Never Fires

**Symptom**: "Continue" prompts still appear

**Check**:
1. Verify SubagentStop hook is in settings.json
2. Verify hook script is executable
3. Verify marker file is being created

### Scenario 2: Infinite Loop

**Symptom**: Execution loops endlessly

**Solution**:
1. Press Ctrl+C to interrupt
2. Run: `find specs -maxdepth 3 -name ".postflight-pending" -delete && find specs -maxdepth 3 -name ".postflight-loop-guard" -delete`
3. Restart session

**Prevention**: Loop guard limits to 3 continuations

### Scenario 3: Marker Not Cleaned Up

**Symptom**: All commands trigger hook

**Solution**:
```bash
# Find and remove orphaned marker
find specs -maxdepth 3 -name ".postflight-pending" -delete
find specs -maxdepth 3 -name ".postflight-loop-guard" -delete
```

## Related Documentation

- `.claude/hooks/subagent-postflight.sh` - Hook script implementation
- `.claude/settings.json` - Hook configuration
- `.claude/context/patterns/file-metadata-exchange.md` - Metadata file protocol
- `.claude/context/troubleshooting/workflow-interruptions.md` - Full troubleshooting guide
