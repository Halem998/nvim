#!/usr/bin/env bash
# test-lint-task-lookup-adoption.sh - Fixture-driven regression test for
# scripts/lint/lint-task-lookup-adoption.sh.
#
# Pins the lint's behaviour against the specific defects that made an earlier single-source gate
# worthless (environment-dependent scan root, .sh-only file-type scope), and proves the task's
# stated acceptance criterion: a newly introduced offender on an executable surface is rejected.
# All fixtures are synthetic, written to a scratch directory; this suite never depends on the live
# tree being clean (that is a separate, whole-tree assertion covered by verify-deploy.sh gate 18)
# and never mutates the repository.
#
# Structural model: test-lint-state-writer-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

LINT_SCRIPT="$(resolve_candidate "lint-task-lookup-adoption.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-task-lookup-adoption.sh" \
  "$SCRIPT_DIR/../lint/lint-task-lookup-adoption.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (acceptance criterion): a NEW offender on an executable surface -> lint fails, named
# =====================================================================
info "=== acceptance criterion: new offender on an executable surface ==="

NEWOFF_DIR="$WORKDIR/newoffender"
mkdir -p "$NEWOFF_DIR/skills/skill-x"
NEWOFF_FIXTURE="$NEWOFF_DIR/skills/skill-x/SKILL.md"
cat > "$NEWOFF_FIXTURE" << 'EOF'
# Synthetic Fresh Offender

```bash
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)
```
EOF

if bash "$LINT_SCRIPT" "$NEWOFF_DIR" >"$WORKDIR/newoffender-out.txt" 2>&1; then
  fail "lint exited 0 for a fresh narrow-pattern offender not on the allowlist (expected non-zero)"
else
  pass "lint exited non-zero for a fresh narrow-pattern offender not on the allowlist"
fi

if grep -q "SKILL.md:5" "$WORKDIR/newoffender-out.txt"; then
  pass "lint names the violating file:line"
else
  fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/newoffender-out.txt")"
fi

# =====================================================================
# Case 2 (prose-exclusion boundary): a planted offender under context/ is not flagged
# =====================================================================
info "=== control case: context/ prose is out of scope by construction ==="

PROSE_DIR="$WORKDIR/prose"
mkdir -p "$PROSE_DIR/context"
cat > "$PROSE_DIR/context/illustrative.md" << 'EOF'
# Illustrative prose

An example of the anti-pattern, for discussion only:

```bash
'.active_projects[] | select(.project_number == $num)' \
```
EOF

if bash "$LINT_SCRIPT" "$PROSE_DIR" >"$WORKDIR/prose-out.txt" 2>&1; then
  pass "lint exited 0 for a planted offender under context/ (out of scope by construction)"
else
  fail "lint flagged a context/ prose file (should be out of scope, not merely exempt):
$(cat "$WORKDIR/prose-out.txt")"
fi

if grep -q "Files checked: 0" "$WORKDIR/prose-out.txt"; then
  pass "context/ is excluded by scan scope, not by a growing exclusion list (0 files checked)"
else
  fail "expected 0 files checked scanning a context/-only root:
$(cat "$WORKDIR/prose-out.txt")"
fi

# =====================================================================
# Case 3 (deployed-mode .md detection): commands/skills/agents directly under the root
# =====================================================================
info "=== deployed-mode detection: flat commands/skills/agents layout ==="

DEPLOY_DIR="$WORKDIR/deployshape"
mkdir -p "$DEPLOY_DIR/commands"
cat > "$DEPLOY_DIR/commands/deployed-offender.md" << 'EOF'
```bash
'.active_projects[] | select(.project_number == $num)' \
```
EOF

if bash "$LINT_SCRIPT" "$DEPLOY_DIR" >"$WORKDIR/deployshape-out.txt" 2>&1; then
  fail "lint silently skipped a deployed-layout commands/ offender (expected non-zero)"
else
  pass "lint detects a deployed-layout (flat commands/skills/agents) .md offender, not silently skipped"
fi

if grep -q "deployed-offender.md" "$WORKDIR/deployshape-out.txt"; then
  pass "deployed-mode violation names the offending file"
else
  fail "deployed-mode violation output missing the file name:
$(cat "$WORKDIR/deployshape-out.txt")"
fi

# =====================================================================
# Case 4 (mode probe, both layouts): source-store nesting is scanned one level deeper
# =====================================================================
info "=== mode probe: source-store fixture (core/manifest.json present) ==="

SRCSTORE_DIR="$WORKDIR/srcstore"
mkdir -p "$SRCSTORE_DIR/core/skills/skill-y"
echo '{}' > "$SRCSTORE_DIR/core/manifest.json"
cat > "$SRCSTORE_DIR/core/skills/skill-y/SKILL.md" << 'EOF'
```bash
'.active_projects[] | select(.project_number == $num)' \
```
EOF

if bash "$LINT_SCRIPT" "$SRCSTORE_DIR" >"$WORKDIR/srcstore-out.txt" 2>&1; then
  fail "lint did not detect a source-store-nested (core/skills/...) offender (expected non-zero)"
else
  pass "mode probe: source-store fixture (core/manifest.json present) resolves to source-store and scans nested extension dirs"
fi

if grep -q "skill-y" "$WORKDIR/srcstore-out.txt"; then
  pass "source-store nested offender is named in output"
else
  fail "source-store nested offender not named:
$(cat "$WORKDIR/srcstore-out.txt")"
fi

info "=== mode probe: deployed fixture (no manifest.json) ==="

if bash "$LINT_SCRIPT" "$DEPLOY_DIR" --verbose >"$WORKDIR/deployshape-verbose-out.txt" 2>&1; then
  :
fi
if grep -q "Files checked: 1" "$WORKDIR/deployshape-verbose-out.txt"; then
  pass "mode probe: deployed fixture (no manifest.json) resolves to deployed and scans the flat layout directly (not nested one level deeper)"
else
  fail "deployed-mode file count unexpected:
$(cat "$WORKDIR/deployshape-verbose-out.txt")"
fi

# =====================================================================
# Case 5: each of the four legitimate jq shapes is exempted, one assertion per shape
# =====================================================================
info "=== the four legitimate shapes are exempted, not flagged ==="

SHAPES_DIR="$WORKDIR/shapes"
mkdir -p "$SHAPES_DIR/scripts"
cat > "$SHAPES_DIR/scripts/shapes.sh" << 'EOF'
#!/usr/bin/env bash
# mutation
jq '(.active_projects[] | select(.project_number == $num)) |= . + {topic: $t}' specs/state.json
# deletion
jq 'del(.active_projects[] | select(.project_number == $num))' specs/state.json
# existence/length check
jq '[.active_projects[] | select(.project_number == $num)] | length' specs/state.json
# single-field read
jq '.active_projects[] | select(.project_number == $num) | .project_name' specs/state.json
EOF

shapes_out="$(bash "$LINT_SCRIPT" --verbose "$SHAPES_DIR" 2>&1)"
shapes_status=$?

if [[ $shapes_status -eq 0 ]]; then
  pass "the four legitimate shapes together produce exit 0 (no violations)"
else
  fail "one or more legitimate shapes were misclassified as violations:
$shapes_out"
fi

if grep -q "mutation" <<< "$shapes_out"; then
  pass "in-place mutation shape (|= . + {...}) is exempted with a mutation reason"
else
  fail "mutation shape was not exempted with a mutation-specific reason:
$shapes_out"
fi

if grep -q "deletion" <<< "$shapes_out"; then
  pass "deletion shape (del(...)) is exempted with a deletion reason"
else
  fail "deletion shape was not exempted with a deletion-specific reason:
$shapes_out"
fi

if grep -q "existence/length" <<< "$shapes_out"; then
  pass "existence/length check shape ([...] | length) is exempted with a length-specific reason"
else
  fail "existence/length shape was not exempted with a length-specific reason:
$shapes_out"
fi

if grep -q "single-field" <<< "$shapes_out"; then
  pass "single-field read shape (| .field) is exempted with a field-read-specific reason"
else
  fail "single-field read shape was not exempted with a field-read-specific reason:
$shapes_out"
fi

# =====================================================================
# Case 6: skill-base.sh and command-gate-in.sh fixtures are never flagged
# =====================================================================
info "=== canonical implementations are never flagged (allowlisted by definition) ==="

CANON_DIR="$WORKDIR/canon"
mkdir -p "$CANON_DIR/core/scripts"
echo '{}' > "$CANON_DIR/core/manifest.json"
cat > "$CANON_DIR/core/scripts/skill-base.sh" << 'EOF'
#!/usr/bin/env bash
skill_validate_input() {
  TASK_DATA=$(jq -r --arg num "$1" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)
}
EOF
cat > "$CANON_DIR/core/scripts/command-gate-in.sh" << 'EOF'
#!/usr/bin/env bash
gate_in() {
  TASK_DATA=$(jq -r --arg num "$1" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)
}
EOF

if bash "$LINT_SCRIPT" "$CANON_DIR" >"$WORKDIR/canon-out.txt" 2>&1; then
  pass "skill-base.sh and command-gate-in.sh fixtures are never flagged (allowlisted by definition)"
else
  fail "canonical implementation fixtures were flagged as violations (should be allowlist-exempt):
$(cat "$WORKDIR/canon-out.txt")"
fi

# =====================================================================
# Case 7: --quiet suppresses the all-clear summary but still prints violations
# =====================================================================
info "=== quiet case: silent when clean, loud when dirty ==="

quiet_clean_out="$(bash "$LINT_SCRIPT" --quiet "$CANON_DIR" 2>&1)"
if [[ -z "$quiet_clean_out" ]]; then
  pass "--quiet produces no output on a clean scan"
else
  fail "--quiet produced output on a clean scan:
$quiet_clean_out"
fi

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$NEWOFF_DIR" 2>&1 || true)"
if grep -q "VIOLATION" <<< "$quiet_dirty_out"; then
  pass "--quiet still prints violations on a dirty scan"
else
  fail "--quiet suppressed a violation:
$quiet_dirty_out"
fi

if grep -q "hand-rolled task-lookup shape" <<< "$quiet_dirty_out"; then
  pass "--quiet still prints the failing summary"
else
  fail "--quiet suppressed the failing summary:
$quiet_dirty_out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
