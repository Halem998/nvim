#!/usr/bin/env bash
# test-assess-repo-health.sh - Fixture-driven regression suite for assess-repo-health.sh, proving
# the probe fails in its failing direction using executed tests -- the exact property the
# original markdown-embedded probe (`if cmd_a || cmd_b || true; then ... fi`) lacked, since that
# shape made its failure branch structurally unreachable and no test could have caught it.
#
# Cases:
#   Clean fixture (control) -- a valid *.sh and *.json. Asserts build_errors == 0 and
#     status == "healthy". Without this control, Bar 1 below could pass from a probe that always
#     reports failure regardless of input.
#   Bar 1 (failing fixture) -- a *.sh with a deliberate syntax error (unmatched quote) and a
#     malformed *.json. Asserts build_errors > 0, status != "healthy", and status is a member of
#     the schema's declared enum.
#   Bar 2 (no-probe fixture) -- only unrecognised file types (.txt, .lua). Asserts build_errors is
#     JSON null -- explicitly asserted to be neither 0 nor 1 -- and status == "unknown".
#   Enum-conformance -- every status value observed across the cases above is checked against
#     context/schemas/state-schema.json's `repository_health.status.enum`, read live via jq (an
#     anti-drift check modelled on test-status-vocabulary.sh).
#
# Non-git-fixture note: every fixture above is built under a `mktemp -d` workdir, which is never a
# git work tree. Every case therefore exercises assess-repo-health.sh's `find`-based enumeration
# fallback, not its `git ls-files` path -- Bars 1-2 and the clean control all passing IS the proof
# that fallback works, not an incidental detail. See the info() line emitted at suite start.
#
# Negative-control demonstration (manual, not automated in this file -- see
# context/standards/shell-script-testing.md's "Mutation checks for regex-shaped fixes"): before
# trusting this suite, its cases were confirmed to go [FAIL] when assess-repo-health.sh's failure
# counter was deliberately inverted (`errors=$(( ...==0 ? 1 : 0 ))`-style flip), then reverted.
# See the phase's implementation summary for the transcript of that run.
#
# Structural model: scripts/tests/test-status-vocabulary.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, deploy-tree-first/source-store-fallback resolution for both the
# script under test and the schema, exit 0 on all-pass / exit 1 on any-fail).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (assess-repo-health.sh or state-schema.json not found at any candidate path, or jq unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the source-store
# copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/assess-repo-health.sh"
  "$SCRIPT_DIR/../assess-repo-health.sh"
)
TOOL=""
for candidate in "${SCRIPT_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TOOL="$candidate"
    break
  fi
done
if [[ -z "$TOOL" ]]; then
  echo "ERROR: assess-repo-health.sh not found at any of:" >&2
  for candidate in "${SCRIPT_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

SCHEMA_CANDIDATES=(
  "$REPO_ROOT/.claude/context/schemas/state-schema.json"
  "$SCRIPT_DIR/../../context/schemas/state-schema.json"
)
SCHEMA=""
for candidate in "${SCHEMA_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCHEMA="$candidate"
    break
  fi
done
if [[ -z "$SCHEMA" ]]; then
  echo "ERROR: state-schema.json not found at any of:" >&2
  for candidate in "${SCHEMA_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot exercise assess-repo-health.sh or the enum check" >&2
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

STATUS_ENUM_JSON="$(jq -c '.properties.repository_health.properties.status.enum' "$SCHEMA")"

assert_status_in_enum() {
  local status="$1" label="$2"
  if printf '%s' "$STATUS_ENUM_JSON" | jq -e --arg s "$status" 'index($s) != null' >/dev/null 2>&1; then
    pass "$label: status '$status' is a member of the declared enum"
  else
    fail "$label: status '$status' is NOT a member of the declared enum ($STATUS_ENUM_JSON)"
  fi
}

info "Fixture workdirs below are created via mktemp -d, which are never git work trees -- every case passing is itself the proof assess-repo-health.sh's non-git find fallback works, not just its git ls-files path."

# =====================================================================
# Clean fixture (control): a valid *.sh and *.json.
# =====================================================================
CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
cat > "$CLEAN_DIR/good.sh" <<'EOF'
#!/usr/bin/env bash
echo "hello"
EOF
cat > "$CLEAN_DIR/good.json" <<'EOF'
{"a": 1}
EOF

if CLEAN_OUT="$(bash "$TOOL" --root "$CLEAN_DIR" 2>"$WORKDIR/clean_stderr")"; then
  if echo "$CLEAN_OUT" | jq -e '.build_errors == 0' >/dev/null 2>&1; then
    pass "clean fixture (control): build_errors == 0"
  else
    fail "clean fixture (control): build_errors != 0 (got: $(echo "$CLEAN_OUT" | jq -c '.build_errors'))"
  fi
  clean_status="$(echo "$CLEAN_OUT" | jq -r '.status')"
  if [ "$clean_status" = "healthy" ]; then
    pass "clean fixture (control): status == healthy"
  else
    fail "clean fixture (control): status != healthy (got: $clean_status)"
  fi
  assert_status_in_enum "$clean_status" "clean fixture"
else
  fail "clean fixture (control): assess-repo-health.sh exited non-zero; stderr: $(cat "$WORKDIR/clean_stderr")"
fi

# =====================================================================
# Bar 1: failing fixture -- a *.sh with a deliberate syntax error (unmatched quote) and a
# malformed *.json.
# =====================================================================
BAR1_DIR="$WORKDIR/bar1"
mkdir -p "$BAR1_DIR"
cat > "$BAR1_DIR/bad.sh" <<'EOF'
#!/usr/bin/env bash
echo "unterminated
EOF
cat > "$BAR1_DIR/bad.json" <<'EOF'
{ this is not valid json
EOF

if BAR1_OUT="$(bash "$TOOL" --root "$BAR1_DIR" 2>"$WORKDIR/bar1_stderr")"; then
  if echo "$BAR1_OUT" | jq -e '.build_errors > 0' >/dev/null 2>&1; then
    pass "Bar 1 (failing fixture): build_errors > 0"
  else
    fail "Bar 1 (failing fixture): build_errors NOT > 0 (got: $(echo "$BAR1_OUT" | jq -c '.build_errors'))"
  fi
  bar1_status="$(echo "$BAR1_OUT" | jq -r '.status')"
  if [ "$bar1_status" != "healthy" ]; then
    pass "Bar 1 (failing fixture): status != healthy (got: $bar1_status)"
  else
    fail "Bar 1 (failing fixture): status == healthy despite deliberate syntax errors"
  fi
  assert_status_in_enum "$bar1_status" "Bar 1"
else
  fail "Bar 1 (failing fixture): assess-repo-health.sh exited non-zero; stderr: $(cat "$WORKDIR/bar1_stderr")"
fi

# =====================================================================
# Bar 2: no-probe fixture -- only unrecognised file types (.txt, .lua). No *.sh/*.json exist.
# =====================================================================
BAR2_DIR="$WORKDIR/bar2"
mkdir -p "$BAR2_DIR"
cat > "$BAR2_DIR/notes.txt" <<'EOF'
just some prose, not a probe target
EOF
cat > "$BAR2_DIR/foo.lua" <<'EOF'
local x = 1
EOF

if BAR2_OUT="$(bash "$TOOL" --root "$BAR2_DIR" 2>"$WORKDIR/bar2_stderr")"; then
  if echo "$BAR2_OUT" | jq -e '.build_errors == null' >/dev/null 2>&1; then
    pass "Bar 2 (no-probe fixture): build_errors is JSON null"
  else
    fail "Bar 2 (no-probe fixture): build_errors is not JSON null (got: $(echo "$BAR2_OUT" | jq -c '.build_errors'))"
  fi
  if echo "$BAR2_OUT" | jq -e '.build_errors != 0 and .build_errors != 1' >/dev/null 2>&1; then
    pass "Bar 2 (no-probe fixture): build_errors is explicitly neither 0 nor 1"
  else
    fail "Bar 2 (no-probe fixture): build_errors equals 0 or 1 (should be null/not-measured)"
  fi
  bar2_status="$(echo "$BAR2_OUT" | jq -r '.status')"
  if [ "$bar2_status" = "unknown" ]; then
    pass "Bar 2 (no-probe fixture): status == unknown"
  else
    fail "Bar 2 (no-probe fixture): status != unknown (got: $bar2_status)"
  fi
  assert_status_in_enum "$bar2_status" "Bar 2"
else
  fail "Bar 2 (no-probe fixture): assess-repo-health.sh exited non-zero; stderr: $(cat "$WORKDIR/bar2_stderr")"
fi

echo ""
echo "$PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
