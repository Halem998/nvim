---
paths: .claude/**/*
---

# Error Handling Rules

## Error Categories

### Operational Errors
Errors during command execution:
- `delegation_hang` - Subagent not responding
- `timeout` - Operation exceeded time limit
- `validation_failed` - Input validation failure

### State Errors
Errors in state management:
- `status_sync_failure` - TODO.md/state.json desync
- `file_not_found` - Expected file missing
- `parse_error` - JSON/YAML parse failure

### External Errors
Errors from external systems:
- `git_commit_failure` - Git operation failed
- `build_error` - Build command failed
- `tool_unavailable` - MCP tool not responding
- `mcp_abort_error` - MCP tool aborted or timed out (error code -32001)
- `delegation_interrupted` - Agent interrupted before completion (metadata shows in_progress)
- `jq_parse_failure` - jq command parse error (often due to Issue #1132)

## Error Response Pattern

When an error occurs:

### 1. Log the Error
Record the error via `scripts/errors-append.sh append` (builds a schema-valid record, writes it
under `flock`). Formal schema: `context/schemas/errors-schema.json`; full CLI/field prose
contract: `context/formats/errors-format.md` (the two must stay in sync). See
`context/standards/error-recovery-strategies.md` for the full CLI invocation example, the
seven-field specification, and session-aware error aggregation.

### 2. Preserve Progress
- Never lose completed work
- Keep partial results
- Mark phases as [PARTIAL] not failed

### 3. Enable Resume
- Store resume point information
- Next invocation continues from failure point

### 4. Report Clearly
Return structured error:
```json
{
  "status": "failed|partial",
  "error": {
    "type": "error_type",
    "message": "What happened",
    "recovery": "How to fix"
  },
  "progress": {
    "completed": ["phase1", "phase2"],
    "failed_at": "phase3"
  }
}
```

## Severity Levels

| Severity | Description | Response |
|----------|-------------|----------|
| critical | System unusable | Stop, alert, require manual fix |
| high | Feature broken | Log, attempt recovery |
| medium | Degraded function | Log, continue with workaround |
| low | Minor issue | Log, ignore |

## Write-Gating Constraint: Never Discard Uncommitted Changes for a Build Fix

On a build error: fix forward — correct the source to resolve the error. **Never discard
uncommitted changes to reach a passing build** — see `.claude/context/contracts/recovery.md` for
the full recovery ladder (fix forward -> strategic-sorry skeleton -> snapshot-then-rollback) and
the "No Destructive Git on Uncommitted Work" rule in `git-workflow.md`.

See `context/standards/error-recovery-strategies.md` for the full per-error-type recovery
strategies (Timeout, State Sync, Build Error, jq Parse Failure, MCP Abort Error, Delegation
Interrupted).

## Non-Blocking Errors

These should not stop execution:
- Git commit failures
- Metric collection failures
- Non-critical logging failures

Log and continue, report at end.
