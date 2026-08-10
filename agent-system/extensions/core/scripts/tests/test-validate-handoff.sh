#!/usr/bin/env bash
# test-validate-handoff.sh - Bidirectional fixture suite for validate-handoff.sh, asserting it
# enforces exactly the schema at context/schemas/orchestrator-handoff-schema.json: the full
# six-value status vocabulary, the conditional artifacts-non-empty rule, and the required
# summary field.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh /
# test-corroborate-phase-counts.sh (mktemp -d workdir with an EXIT-trap cleanup, deploy-tree-first
# / source-store-fallback candidate resolution, pass()/fail()/info() helpers with integer
# counters, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# validator script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Source-store-first (not deploy-first, unlike test-corroborate-phase-counts.sh's SKILL_BASE
# resolution): this suite validates the validator's own logic under active development, which
# lives in the source store before a Phase 7 redeploy copies it to the deploy tree. After
# redeploy the two are identical, so either order then yields the same result.
VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-handoff.sh"
  "$REPO_ROOT/.claude/scripts/validate-handoff.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-handoff.sh not found at any of:" >&2
  for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── assert_accept <name> <json-content> ───────────────────────────────────────────────────────
# Writes the fixture, runs the validator, asserts exit 0.
assert_accept() {
  local name="$1" content="$2"
  local f="$WORKDIR/${name}.json"
  printf '%s' "$content" > "$f"
  if bash "$VALIDATOR" "$f" >"$WORKDIR/${name}.out" 2>&1; then
    pass "$name: validator exits 0 (accept)"
  else
    fail "$name: validator exited non-zero (expected accept) -- see $WORKDIR/${name}.out"
  fi
}

# ─── assert_reject <name> <json-content> ───────────────────────────────────────────────────────
# Writes the fixture, runs the validator, asserts non-zero exit.
assert_reject() {
  local name="$1" content="$2"
  local f="$WORKDIR/${name}.json"
  printf '%s' "$content" > "$f"
  if bash "$VALIDATOR" "$f" >"$WORKDIR/${name}.out" 2>&1; then
    fail "$name: validator exited 0 (expected reject) -- see $WORKDIR/${name}.out"
  else
    pass "$name: validator exits non-zero (reject)"
  fi
}

# =====================================================================
# ACCEPT fixtures
# =====================================================================

# Accept 1: conformant hard-mode implemented handoff, summary + non-empty artifacts.
assert_accept "accept-implemented" '{
  "status": "implemented",
  "summary": "Implemented all phases and verified the deploy tree.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md", "summary": "Implementation summary"}
  ],
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": [],
  "continuation_path": null
}'

# Accept 2: partial handoff with artifacts: [] and a non-null continuation_path.
assert_accept "accept-partial" '{
  "status": "partial",
  "summary": "Stopped after phase 2 due to context pressure.",
  "artifacts": [],
  "phases_completed": 2,
  "phases_total": 5,
  "blockers": [],
  "continuation_path": "specs/000_x/handoffs/phase-2-handoff-20260101T000000Z.md"
}'

# Accept 3: researched-status handoff with a report artifact. This is the regression the fix
# exists to close -- the pre-change validator's 3-value status enum would have REJECTED it.
assert_accept "accept-researched" '{
  "status": "researched",
  "summary": "Completed research for the task.",
  "artifacts": [
    {"type": "report", "path": "specs/000_x/reports/01_x.md"}
  ],
  "phases_completed": 0,
  "phases_total": 0,
  "blockers": []
}'

# =====================================================================
# REJECT fixtures
# =====================================================================

# Reject 1: handoff missing artifacts entirely.
assert_reject "reject-no-artifacts" '{
  "status": "implemented",
  "summary": "Missing the artifacts field.",
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 2: handoff missing summary.
assert_reject "reject-no-summary" '{
  "status": "implemented",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 3: implemented handoff with artifacts: [] (non-empty required for implemented).
assert_reject "reject-implemented-empty-artifacts" '{
  "status": "implemented",
  "summary": "Claims implemented but has no artifacts.",
  "artifacts": [],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 4: off-vocabulary status.
assert_reject "reject-off-vocab-status" '{
  "status": "done",
  "summary": "Off-vocabulary status value.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# =====================================================================
# Summary
# =====================================================================
info "Validator resolved to: $VALIDATOR"
echo ""
echo "========================================"
echo "test-validate-handoff.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
