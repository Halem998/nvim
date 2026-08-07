#!/usr/bin/env bash
# Validate state.json and TODO.md are synchronized
# Called after writes to specs/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DEFECT_RECORD="$SCRIPT_DIR/../scripts/system-defect-record.sh"

# .cwd capture only (mirroring hooks/events-log-lifecycle.sh's pattern) -- this script performed
# no stdin parsing before this addition and none of its relative-path STATE_FILE/TODO_FILE
# assumptions change; --cwd is provenance-only for the Deliverable 2(c) recorder call below.
INPUT=$(cat 2>/dev/null) || true
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || CWD=""
CC_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || CC_SESSION_ID=""

STATE_FILE="specs/state.json"
TODO_FILE="specs/TODO.md"

# Check both files exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"additionalContext": "Warning: state.json not found"}'
    exit 0
fi

if [[ ! -f "$TODO_FILE" ]]; then
    echo '{"additionalContext": "Warning: TODO.md not found"}'
    exit 0
fi

# Quick validation: check state.json is valid JSON
if ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo '{"additionalContext": "Error: state.json is not valid JSON"}'
    # Deliverable 2(c): record this detection. Per D4, expected log-only (specs/state.json; no
    # writer identity is available at this PostToolUse hook) — that is correct behavior, not a
    # bug.
    bash "$SYSTEM_DEFECT_RECORD" \
      --defect-class STATE_SYNC_DIVERGENCE \
      --detecting-site "hooks/validate-state-sync.sh" \
      --message "state.json is not valid JSON" \
      --attributed-path "unresolved:hooks/validate-state-sync.sh" \
      ${CC_SESSION_ID:+--cc-session-id "$CC_SESSION_ID"} \
      ${CWD:+--cwd "$CWD"} \
      >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
    exit 1
fi

# Success - PostToolUse hooks don't use "decision" field
echo '{}'
exit 0
