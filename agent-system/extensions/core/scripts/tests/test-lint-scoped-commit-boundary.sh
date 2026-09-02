#!/usr/bin/env bash
# test-lint-scoped-commit-boundary.sh - Both-polarity fixture test for
# scripts/lint/lint-scoped-commit-boundary.sh.
#
# The lint's job is to fail when a hand-rolled narrow `git add` + BARE `git commit -m` (no
# trailing pathspec) reappears anywhere in the source store, and to stay silent when the same
# commit is routed through scripts/git-commit-scoped.sh. This test asserts both polarities
# against synthetic fixtures written to a scratch directory, so it never depends on the live tree
# being clean (that is a separate, whole-tree assertion) and never mutates the repository.
#
# Structural model: test-lint-state-writer-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

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

LINT_SCRIPT="$(resolve_candidate "lint-scoped-commit-boundary.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-scoped-commit-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-scoped-commit-boundary.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (negative polarity): hand-rolled bare commit -> lint must fail (non-zero)
# =====================================================================
info "=== negative case: hand-rolled bare git commit -m ==="

DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
DIRTY_FIXTURE="$DIRTY_DIR/synthetic-dirty-command.md"
cat > "$DIRTY_FIXTURE" << 'EOF'
# Synthetic Dirty Fixture

Commit the change:

```bash
git add specs/state.json specs/TODO.md
git commit -m "task {N}: create {title}"
```
EOF

if bash "$LINT_SCRIPT" "$DIRTY_DIR" >"$WORKDIR/dirty-out.txt" 2>&1; then
  fail "lint exited 0 for a hand-rolled bare git-commit call site (expected non-zero)"
else
  pass "lint exited non-zero for a hand-rolled bare git-commit call site"
fi

if grep -q "synthetic-dirty-command.md:7" "$WORKDIR/dirty-out.txt"; then
  pass "lint reports the violation with file:line"
else
  fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/dirty-out.txt")"
fi

# =====================================================================
# Case 2 (positive polarity): equivalent git-commit-scoped.sh call -> lint must pass (exit 0)
# =====================================================================
info "=== positive case: routed through git-commit-scoped.sh ==="

CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
CLEAN_FIXTURE="$CLEAN_DIR/synthetic-clean-command.md"
cat > "$CLEAN_FIXTURE" << 'EOF'
# Synthetic Clean Fixture

Commit the change:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: create {title}" \
  --session "${session_id}" \
  -- specs/state.json specs/TODO.md
```
EOF

if bash "$LINT_SCRIPT" "$CLEAN_DIR" >"$WORKDIR/clean-out.txt" 2>&1; then
  pass "lint exited 0 for a commit routed through git-commit-scoped.sh"
else
  fail "lint exited non-zero for a git-commit-scoped.sh call (unexpected):
$(cat "$WORKDIR/clean-out.txt")"
fi

# =====================================================================
# Case 3 (structural control): a single-line invocation ending in a trailing `-- <pathspec>`
# is exempt by shape alone, even outside the file-level allowlist -- this is the sanctioned
# script's own internal invocation shape.
# =====================================================================
info "=== control case: trailing -- <pathspec> is exempt by shape ==="

SHAPE_DIR="$WORKDIR/shape"
mkdir -p "$SHAPE_DIR"
cat > "$SHAPE_DIR/synthetic-shape.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic shape fixture: a single-line commit ending in a trailing pathspec.
git commit -m "$full_message" -- "${pathspecs[@]}"
EOF

if bash "$LINT_SCRIPT" "$SHAPE_DIR" >"$WORKDIR/shape-out.txt" 2>&1; then
  pass "lint exited 0 for a commit ending in a trailing -- <pathspec> (exempt by shape)"
else
  fail "lint flagged a commit ending in a trailing -- <pathspec> (should be exempt by shape):
$(cat "$WORKDIR/shape-out.txt")"
fi

# =====================================================================
# Case 4 (file-level allowlist control): a file-level allowlisted path is exempt even though
# its content is the raw anti-pattern shape with no trailing pathspec.
# =====================================================================
info "=== control case: file-level allowlist entry exempt regardless of shape ==="

ALLOWLIST_DIR="$WORKDIR/allowlisted/agent-system/extensions/core/scripts"
mkdir -p "$ALLOWLIST_DIR"
cat > "$ALLOWLIST_DIR/git-commit-scoped.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic stand-in for the sanctioned script's own path, to exercise the allowlist
# independent of the real script's own content-based exemption.
git commit -m "placeholder"
EOF

if bash "$LINT_SCRIPT" "$WORKDIR/allowlisted" >"$WORKDIR/allowlist-out.txt" 2>&1; then
  pass "lint exited 0 for a file-level allowlisted path (git-commit-scoped.sh) regardless of shape"
else
  fail "lint flagged a file-level allowlisted path (should be exempt regardless of shape):
$(cat "$WORKDIR/allowlist-out.txt")"
fi

# =====================================================================
# Case 5: --verbose reports exempt candidate lines, tagged as exempt
# =====================================================================
info "=== verbose case: exempt lines are reported and tagged ==="

if bash "$LINT_SCRIPT" --verbose "$SHAPE_DIR" 2>&1 | grep -q "\[EXEMPT\]"; then
  pass "--verbose tags exempt candidate lines"
else
  fail "--verbose did not report the exempt candidate line"
fi

# =====================================================================
# Case 6: --quiet suppresses the all-clear summary but still prints violations
# =====================================================================
info "=== quiet case: silent when clean, loud when dirty ==="

quiet_clean_out="$(bash "$LINT_SCRIPT" --quiet "$CLEAN_DIR" 2>&1)"
if [[ -z "$quiet_clean_out" ]]; then
  pass "--quiet produces no output on a clean scan"
else
  fail "--quiet produced output on a clean scan:
$quiet_clean_out"
fi

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$DIRTY_DIR" 2>&1 || true)"
if grep -q "VIOLATION" <<< "$quiet_dirty_out"; then
  pass "--quiet still prints violations on a dirty scan"
else
  fail "--quiet suppressed a violation:
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
