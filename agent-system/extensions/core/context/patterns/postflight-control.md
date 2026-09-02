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
  "cc_session_id": "38b5b06d-0db7-4d01-9263-982e26d6bf80",
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
| `cc_session_id` | Yes | Claude Code's own native session UUID, sourced from `${CLAUDE_CODE_SESSION_ID:-}` at write time (empty string when unset -- the key is always present). This is the correlation key both `subagent-postflight.sh` and `events-log-lifecycle.sh` match against hook stdin's top-level `.session_id` to select only the marker owned by the stopping session; it is a **distinct id space** from the agent-system `session_id` field below. |
| `session_id` | Yes | Current session identifier (agent-system `sess_{timestamp}_{random}` id -- distinct from `cc_session_id` above) |
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
  "cc_session_id": "$CLAUDE_CODE_SESSION_ID",
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

**Deliberate operator override of correlation**: the hooks themselves never pick an arbitrary
marker with `head -1` (see "SubagentStop Hook Behavior" below) -- they act only on the one whose
`cc_session_id` matches the stopping session, or on none at all. The snippet below is a manual,
human-driven diagnostic step, not something either hook does; it intentionally reproduces the
old any-marker selection because an operator debugging a stuck loop needs to see (and can choose
to touch) every marker on disk, not just one session's own.

```bash
# Set stop_hook_active to force stop on next iteration
marker_file=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)
if [ -n "$marker_file" ]; then
    jq '.stop_hook_active = true' "$marker_file" > specs/tmp/marker.json && \
      mv specs/tmp/marker.json "$marker_file"
fi
```

## SubagentStop Hook Behavior

The hook at `.claude/hooks/subagent-postflight.sh` reads hook stdin (bounded by a `read -t 0.1`
drain, defaulting to `{}` -- this never blocks even when stdin is empty or absent) and extracts
`CC_SESSION_ID` from its top-level `.session_id`. This is the correlation key used throughout:

1. **Enumerates every marker**: Walks `find specs -maxdepth 3 -name ".postflight-pending"` (not
   `head -1`) and, for each, checks `jq empty` (a marker that fails to parse cannot be
   correlated -- it is skipped, never selected) then compares its `cc_session_id` field against
   `CC_SESSION_ID`. Selects only an exact, non-empty match.
2. **Falls back to a correlated global marker**: For backward compatibility, applies the
   identical correlation check to `specs/.postflight-pending` if no task-scoped marker matched.
3. **Fail-safe -- no match means no marker selected**: `CC_SESSION_ID` empty, no marker's
   `cc_session_id` matching, or a matching value that is itself empty, all leave
   `MARKER_FILE` unset. This holds for a legacy marker with no `cc_session_id` key at all and for
   a marker owned by a different concurrent session -- neither is ever selected, mutated, or
   deleted. A `log_debug` line records how many markers were enumerated and the stopping
   `CC_SESSION_ID` whenever nothing correlates, so a stuck legacy marker is diagnosable from the
   log (see "Debugging" below) rather than silent.
4. **If a correlated marker was selected**:
   - Checks `stop_hook_active` flag (bypass if true) -- deletion logged as `STOP-HOOK-ACTIVE DELETE:`
   - Checks loop guard counter (max 3 continuations) -- cap-reached deletion logged as `CAP-REACHED DELETE:`
     (see "Deletion Provenance" below; both labels name the marker path, task number, the
     marker's own `session_id`, and the correlated `cc_session_id`, and are textually distinct
     from each other so a log reader cannot confuse the two removal paths)
   - Returns `{"decision": "block", "reason": "..."}` to continue execution. The reason is the
     correlated marker's own `.reason` field when present, or `"Postflight operations pending"`
     when the marker parses but has no `.reason` (see "The `jq //` Parse-Error Hazard" below for
     why this extraction is guarded). Because a marker only ever reaches this point after already
     passing `jq empty` in the enumeration step above, the historical third case -- a diagnostic
     naming the marker path and jq's parse error for a malformed selected marker -- can no longer
     occur in practice; that code path remains as defensive redundancy only.
5. **If no correlated marker**: Returns `{}` to allow normal stop.

**Known, accepted limitation**: within a single Claude Code session holding two markers
simultaneously, `cc_session_id` does not disambiguate which of that session's own markers
belongs to the subagent that just stopped -- hook stdin carries no Task-tool-call-scoped
identifier the writer could use in advance. Correlation is scoped to markers from unrelated
concurrent sessions/tasks, which it resolves fully.

`events-log-lifecycle.sh`'s SubagentStop branch is a deliberate mirror of this same
enumerate-and-match selection (see that file's own header comment), applied to its own separate
`MARKER_FILE` lookup for `specs/events.jsonl` telemetry rather than the block decision.

### Loop Guard

To prevent infinite loops, the hook maintains a counter in the task directory:
- Location: `specs/{NNN}_{SLUG}/.postflight-loop-guard` (same directory as marker)
- Incremented on each blocked stop
- After 3 continuations, cleanup and allow stop (logged as `CAP-REACHED DELETE:`)
- Reset when marker is removed normally

### Deletion Provenance

Three paths can remove a `.postflight-pending` marker (and, for the first two, its paired
`.postflight-loop-guard`), and only two of them log:

| Path | Log label | Where |
|------|-----------|-------|
| Loop guard cap reached (`MAX_CONTINUATIONS`) | `CAP-REACHED DELETE:` | `check_loop_guard()` in `subagent-postflight.sh` |
| `stop_hook_active` flag set on the correlated marker | `STOP-HOOK-ACTIVE DELETE:` | `main()`'s `stop_hook_active` branch in `subagent-postflight.sh` |
| Normal postflight completion | *(none -- silent)* | `skill_cleanup` in `scripts/skill-base.sh`'s plain `rm -f` |

The two labelled lines are textually distinct (neither is a substring of the other), so a
`grep` for one never matches the other; `skill_cleanup`'s removal is identified by the *absence*
of any labelled line for that marker path.

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
per the pattern above. Since the marker-correlation fix, this guard is defensive redundancy in
practice: `find_marker()`'s own `jq empty` check (see "SubagentStop Hook Behavior" above) already
excludes a malformed marker from ever being selected as `MARKER_FILE`, so the guard here would
only fire if a selected, previously well-formed marker were corrupted between selection and this
extraction.

### Consistency Between the Two Hooks on a Malformed Marker

Both `subagent-postflight.sh` and `events-log-lifecycle.sh`'s SubagentStop branch detect a
malformed (non-parsing) `.postflight-pending` marker the same way, via `jq empty "$MARKER_FILE"`,
during their own enumerate-and-match selection loop -- and both treat it identically at the
correlation layer: a malformed marker's `cc_session_id` is unreadable, so it can never be
correlated and is skipped without being selected, exactly like any other non-matching marker.

Past that point the two hooks diverge, intentionally, in what they do with the detection:
`subagent-postflight.sh` is a **control channel**; because a malformed marker is never selected,
it simply continues enumerating and, on no correlated match, returns `{}` (see "SubagentStop Hook
Behavior" above) -- it no longer surfaces a diagnostic block reason naming the marker path and
jq's parse error the way the pre-correlation version of this hook did. `events-log-lifecycle.sh`
is a **telemetry** channel that must never block and does not need a marker to be *its own* to log
about it usefully, so for each malformed marker the enumeration reaches it still emits exactly one
`malformed_postflight_marker` / `deviation` event to `specs/events.jsonl` per marker (recovering
the task number from the marker's parent directory name and the session_id from that task's
`specs/state.json` entry) and always echoes `{}`. This asymmetry is deliberate: malformed-marker
*observability* now lives solely in the telemetry channel, while the control channel's fail-safe
(never act on what cannot be correlated) takes priority over surfacing a parse diagnostic to the
subagent. One remaining silent case is shared by both: if no `session_id` can be resolved for the
task (e.g. the task has since been archived or vaulted), `events-log-lifecycle.sh` exits cleanly
with no event for that marker -- `session_id` is schema-required and pattern-constrained, so
there is no placeholder value to substitute. This is a narrowing of the previously-silent window,
not its elimination.

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

**Deliberate operator override of correlation** (see "Emergency Bypass" above): shows the first
marker found on disk regardless of session ownership, for manual inspection -- the hooks
themselves never do this.

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

To inspect every marker on disk together with its `cc_session_id` (useful when several
concurrent sessions each hold one), drop the `head -1`:

```bash
find specs -maxdepth 3 -name ".postflight-pending" -type f -exec sh -c \
  'echo "$1:"; jq "{cc_session_id, session_id, task_number}" "$1"' _ {} \;
```

### Check Loop Guard

**Deliberate operator override of correlation** (see "Emergency Bypass" above): shows the first
loop guard found on disk regardless of session ownership.

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

The task-scoped removal below is always safe. The bulk sweep is another **deliberate operator
override of correlation**: it removes every marker across every task/session, not just the
stopping session's own -- appropriate for an operator, never something either hook does on its
own.

```bash
# Clean specific task
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"

# Clean all orphaned markers (across all tasks and sessions)
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
