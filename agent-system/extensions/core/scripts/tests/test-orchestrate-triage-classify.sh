#!/usr/bin/env bash
# test-orchestrate-triage-classify.sh - Fixture-driven regression suite for
# orchestrate-triage-classify.sh's `partial`-status continuation-pointer predicate.
#
# THE DEFECT UNDER TEST: the sole active .orchestrator-handoff.json writer (H9 hard-mode
# wrap-up) emits a FLAT top-level `continuation_path` string. Before the fix, the classifier's
# `continuation_ok` jq expression checks ONLY the NESTED `continuation_context.handoff_path` — a
# key the active writer never produces. A real, actionable continuation therefore classifies as
# handoff_state "empty" instead of "continuation", stranding the task. This suite locks in the
# fix: accept EITHER form, per context/standards/shell-script-testing.md's mutation-check
# discipline (a suite that passes unchanged pre- and post-fix proves nothing).
#
# Sandbox shape: the classifier sources deploy-root-guard.sh, which hard-requires the script's
# parent directory to match `*/.claude` or `*/.opencode` and derives
# PROJECT_ROOT="$SCRIPT_DIR/../..". This suite copies both scripts into a synthetic
# $WORKDIR/.claude/scripts/ so PROJECT_ROOT resolves to $WORKDIR, with a sibling $WORKDIR/specs/
# holding a synthetic state.json and per-fixture .orchestrator-handoff.json files — no STATE_FILE
# override is needed (empirically confirmed at implementation time).
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup, inline heredoc fixtures (no committed fixture tree), exit 0 iff FAILED == 0.
#
# Exit codes: 0 -- all cases PASS; 1 (or the last failing `bash` invocation's non-zero status,
# treated as a fixture failure) -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../orchestrate-triage-classify.sh"
GUARD_SRC="$SCRIPT_DIR/../deploy-root-guard.sh"
COMMON_SRC="$SCRIPT_DIR/../lib/common.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected orchestrate-triage-classify.sh at $TOOL_SRC" >&2
  exit 1
fi

if [ ! -f "$GUARD_SRC" ]; then
  echo "ERROR: expected deploy-root-guard.sh at $GUARD_SRC" >&2
  exit 1
fi

if [ ! -f "$COMMON_SRC" ]; then
  echo "ERROR: expected lib/common.sh at $COMMON_SRC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required by orchestrate-triage-classify.sh and this suite, and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs"
cp "$TOOL_SRC" "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
cp "$GUARD_SRC" "$WORKDIR/.claude/scripts/deploy-root-guard.sh"
cp "$COMMON_SRC" "$WORKDIR/.claude/scripts/lib/common.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
TOOL="$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"

# =====================================================================
# Scope Hypothesis (a): confirm the sandbox shape satisfies deploy-root-guard.sh and yields
# PROJECT_ROOT == $WORKDIR with no source change to the tool, before any fixture is built on
# top of it.
# =====================================================================

cat > "$WORKDIR/specs/state.json" <<'EOF'
{"active_projects":[{"project_number":999,"project_name":"sandbox_probe","status":"not_started"}]}
EOF

probe_out="$(bash "$TOOL" single 999 2>&1)"
probe_exit=$?
probe_group="$(echo "$probe_out" | jq -r '.group' 2>/dev/null)"

if [ "$probe_exit" -eq 0 ] && [ "$probe_group" = "research" ]; then
  pass "sandbox shape: \$WORKDIR/.claude/scripts/ satisfies deploy-root-guard.sh, PROJECT_ROOT == \$WORKDIR (no STATE_FILE override needed)"
else
  fail "sandbox shape: expected exit 0 and group=research for the not_started probe task, got exit=$probe_exit output=$probe_out"
  echo ""
  echo "Results: ${PASSED} passed, ${FAILED} failed"
  echo "ERROR: sandbox probe failed; aborting before building fixtures (per Rollback/Contingency: escalate rather than route around the friction)." >&2
  exit 1
fi

# =====================================================================
# Fixtures A-D: all four live as sibling `partial`-status projects in one shared state.json, so
# a single classifier invocation per engine covers all four in one pass.
# =====================================================================

mkdir -p "$WORKDIR/specs/101_fixture_a" "$WORKDIR/specs/102_fixture_b" \
         "$WORKDIR/specs/103_fixture_c" "$WORKDIR/specs/104_fixture_d"

cat > "$WORKDIR/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 101, "project_name": "fixture_a", "status": "partial"},
    {"project_number": 102, "project_name": "fixture_b", "status": "partial"},
    {"project_number": 103, "project_name": "fixture_c", "status": "partial"},
    {"project_number": 104, "project_name": "fixture_d", "status": "partial"}
  ]
}
EOF

# Fixture A (the mutation-check fixture, load-bearing): flat top-level continuation_path only,
# continuation_context explicitly null -- the exact shape the sole active H9 writer emits.
cat > "$WORKDIR/specs/101_fixture_a/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": null,
  "continuation_path": "specs/101_fixture_a/handoffs/phase-2-handoff-TS.md",
  "blockers": []
}
EOF

# Fixture B (no-regression on the nested form): nested continuation_context.handoff_path
# populated, no top-level continuation_path key at all.
cat > "$WORKDIR/specs/102_fixture_b/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": {"handoff_path": "specs/102_fixture_b/handoffs/phase-1-handoff-TS.md", "orchestrator_mode": true},
  "blockers": []
}
EOF

# Fixture C (anti-over-relaxation guard): both forms null, no blockers -- must stay "empty".
cat > "$WORKDIR/specs/103_fixture_c/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": null,
  "continuation_path": null,
  "blockers": []
}
EOF

# Fixture D (blockers precedence preserved): continuation_path populated AND blockers non-empty
# -- continuation must still outrank blockers.
cat > "$WORKDIR/specs/104_fixture_d/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": null,
  "continuation_path": "specs/104_fixture_d/handoffs/phase-3-handoff-TS.md",
  "blockers": ["some unresolved blocker"]
}
EOF

check_fixture() {
  # check_fixture <engine> <task_number> <expected_handoff_state> <expected_group> <label>
  local engine="$1" task="$2" expected_state="$3" expected_group="$4" label="$5"
  local out
  out="$(bash "$TOOL" "$engine" "$task" 2>&1)"
  local got_state got_group
  got_state="$(echo "$out" | jq -r '.handoff_state' 2>/dev/null)"
  got_group="$(echo "$out" | jq -r '.group' 2>/dev/null)"
  if [ "$got_state" = "$expected_state" ] && [ "$got_group" = "$expected_group" ]; then
    pass "$label (engine=$engine): handoff_state=$got_state group=$got_group"
  else
    fail "$label (engine=$engine): expected handoff_state=$expected_state group=$expected_group, got handoff_state=$got_state group=$got_group (raw: $out)"
  fi
}

# --- Fixture A: single engine (this is the mutation-check assertion) ---
check_fixture "single" 101 "continuation" "implement" \
  "Fixture A (flat continuation_path only, the H9 writer's real shape)"

# --- Fixture A: mt engine, to confirm both engines agree on the converged 'partial + continuation' row ---
check_fixture "mt" 101 "continuation" "implement" \
  "Fixture A (flat continuation_path only) cross-engine agreement"

# --- Fixture B: nested form, no regression ---
check_fixture "single" 102 "continuation" "implement" \
  "Fixture B (nested continuation_context.handoff_path, pre-existing behavior)"
check_fixture "mt" 102 "continuation" "implement" \
  "Fixture B (nested continuation_context.handoff_path) cross-engine agreement"

# --- Fixture C: both forms null, still empty ---
check_fixture "single" 103 "empty" "implement" \
  "Fixture C (both forms null, anti-over-relaxation guard)"
check_fixture "mt" 103 "empty" "implement" \
  "Fixture C (both forms null) cross-engine agreement"

# --- Fixture D: continuation outranks blockers ---
check_fixture "single" 104 "continuation" "implement" \
  "Fixture D (continuation_path populated AND blockers non-empty; continuation must outrank blockers)"
check_fixture "mt" 104 "continuation" "implement" \
  "Fixture D (continuation outranks blockers) cross-engine agreement"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
