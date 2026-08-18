#!/usr/bin/env bash
# test-deploy-freshness.sh - Fixture-driven regression suite for check-deploy-freshness.sh, the
# bash read side of the source_git_head staleness stamp (see state.lua's
# `resolve_source_git_head` for the write side this checker's comparison logic mirrors).
#
# Structural model: test-phase-heading-patterns.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, exit 0 on all-pass / exit 1 on any-fail) combined with
# test-deploy-propagation.sh's trap-based scratch WORKDIR pattern, since this suite -- like that
# one -- drives a real subprocess rather than sourcing a library.
#
# Fixture: a throwaway SOURCE git repo (standing in for the agent-system source store) holding a
# committed "ext" subdirectory, and one throwaway CONSUMER directory per case holding a
# fabricated .claude-extensions.json whose `source_dir` points at that subdirectory. The real
# check-deploy-freshness.sh is copied byte-for-byte into the fixture and invoked only against
# these throwaway consumers -- never against this repo's own .claude-extensions.json or specs/
# tree.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (checker script or git not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

CHECKER_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/check-deploy-freshness.sh"
  "$SCRIPT_DIR/../check-deploy-freshness.sh"
)
CHECKER=""
for candidate in "${CHECKER_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    CHECKER="$candidate"
    break
  fi
done
if [[ -z "$CHECKER" ]]; then
  echo "ERROR: check-deploy-freshness.sh not found at any of:" >&2
  for candidate in "${CHECKER_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

info "Using checker: $CHECKER"

# --- Fixture: throwaway source-store stand-in with a committed "ext" subdirectory ---
SOURCE_REPO="$WORKDIR/source-repo"
mkdir -p "$SOURCE_REPO/ext"
git init -q "$SOURCE_REPO"
git -C "$SOURCE_REPO" config user.email "test@example.com"
git -C "$SOURCE_REPO" config user.name "Test"
echo "v1" > "$SOURCE_REPO/ext/file.txt"
git -C "$SOURCE_REPO" add ext/file.txt
git -C "$SOURCE_REPO" commit -q -m "initial ext"
EXT_DIR="$SOURCE_REPO/ext"
HEAD_V1="$(git -C "$SOURCE_REPO" log -1 --format=%H -- "$EXT_DIR")"

# Real checker, copied byte-for-byte so the suite exercises exactly the deployed artifact.
mkdir -p "$WORKDIR/bin"
cp "$CHECKER" "$WORKDIR/bin/check-deploy-freshness.sh"
chmod +x "$WORKDIR/bin/check-deploy-freshness.sh"

run_checker() {
  bash "$WORKDIR/bin/check-deploy-freshness.sh" "$1"
}

# $1 consumer dir, $2 source_dir, $3 recorded head (ignored if $4 == true), $4 omit-head flag
write_state() {
  local consumer="$1" ext_dir="$2" head="$3" omit_head="${4:-false}"
  mkdir -p "$consumer"
  if [[ "$omit_head" == "true" ]]; then
    cat > "$consumer/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"ext":{"version":"1.0.0","source_dir":"${ext_dir}"}}}
EOF
  else
    cat > "$consumer/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"ext":{"version":"1.0.0","source_dir":"${ext_dir}","source_git_head":"${head}"}}}
EOF
  fi
}

# =====================================================================
# Case STALE: recorded source_git_head is an older/bogus commit
# =====================================================================
CONSUMER_STALE="$WORKDIR/consumer-stale"
write_state "$CONSUMER_STALE" "$EXT_DIR" "0000000000000000000000000000000000dead"
OUT_STALE="$(run_checker "$CONSUMER_STALE" 2>&1)"
RC_STALE=$?
WARN_COUNT_STALE=$(printf '%s\n' "$OUT_STALE" | grep -c '^WARN:')
if [[ "$RC_STALE" -eq 0 && "$WARN_COUNT_STALE" -eq 1 && "$OUT_STALE" == *"'ext'"* ]]; then
  pass "STALE: exactly one WARN naming the extension, exit 0"
else
  fail "STALE: expected exactly one WARN naming 'ext' and exit 0, got rc=$RC_STALE warn_count=$WARN_COUNT_STALE output=<<<$OUT_STALE>>>"
fi
if [[ "$OUT_STALE" == *"deploy-headless.sh"* ]]; then
  pass "STALE: WARN names the regeneration remedy"
else
  fail "STALE: WARN did not name deploy-headless.sh remedy: <<<$OUT_STALE>>>"
fi

# =====================================================================
# Case FRESH: recorded source_git_head equals the current revision
# =====================================================================
CONSUMER_FRESH="$WORKDIR/consumer-fresh"
write_state "$CONSUMER_FRESH" "$EXT_DIR" "$HEAD_V1"
OUT_FRESH="$(run_checker "$CONSUMER_FRESH" 2>&1)"
RC_FRESH=$?
if [[ "$RC_FRESH" -eq 0 && -z "$OUT_FRESH" ]]; then
  pass "FRESH: no output, exit 0"
else
  fail "FRESH: expected silence and exit 0, got rc=$RC_FRESH output=<<<$OUT_FRESH>>>"
fi

# =====================================================================
# Case MISSING FIELD: entry has source_dir but no source_git_head
# =====================================================================
CONSUMER_MISSING="$WORKDIR/consumer-missing-field"
write_state "$CONSUMER_MISSING" "$EXT_DIR" "" true
OUT_MISSING="$(run_checker "$CONSUMER_MISSING" 2>&1)"
RC_MISSING=$?
if [[ "$RC_MISSING" -eq 0 && -z "$OUT_MISSING" ]]; then
  pass "MISSING FIELD: no output, exit 0"
else
  fail "MISSING FIELD: expected silence and exit 0, got rc=$RC_MISSING output=<<<$OUT_MISSING>>>"
fi

# =====================================================================
# Case UNVERIFIABLE (variant A): source_dir exists but is not inside any git repository
# =====================================================================
CONSUMER_NONGIT="$WORKDIR/consumer-nongit"
NONGIT_DIR="$WORKDIR/not-a-git-dir"
mkdir -p "$NONGIT_DIR"
write_state "$CONSUMER_NONGIT" "$NONGIT_DIR" "deadbeef"
OUT_NONGIT="$(run_checker "$CONSUMER_NONGIT" 2>&1)"
RC_NONGIT=$?
if [[ "$RC_NONGIT" -eq 0 && -z "$OUT_NONGIT" ]]; then
  pass "UNVERIFIABLE (non-git source_dir): no output, exit 0"
else
  fail "UNVERIFIABLE (non-git source_dir): expected silence and exit 0, got rc=$RC_NONGIT output=<<<$OUT_NONGIT>>>"
fi

# =====================================================================
# Case UNVERIFIABLE (variant B): source_dir does not exist on disk
# =====================================================================
CONSUMER_NOPATH="$WORKDIR/consumer-nopath"
write_state "$CONSUMER_NOPATH" "$WORKDIR/does-not-exist-xyz" "deadbeef"
OUT_NOPATH="$(run_checker "$CONSUMER_NOPATH" 2>&1)"
RC_NOPATH=$?
if [[ "$RC_NOPATH" -eq 0 && -z "$OUT_NOPATH" ]]; then
  pass "UNVERIFIABLE (nonexistent source_dir): no output, exit 0"
else
  fail "UNVERIFIABLE (nonexistent source_dir): expected silence and exit 0, got rc=$RC_NOPATH output=<<<$OUT_NOPATH>>>"
fi

# =====================================================================
# Case SCOPING: commit a change elsewhere in the fixture source repo, outside ext/'s own
# subdirectory -- must produce no output (path-scoped comparison, not whole-repo HEAD)
# =====================================================================
echo "unrelated change" > "$SOURCE_REPO/outside.txt"
git -C "$SOURCE_REPO" add outside.txt
git -C "$SOURCE_REPO" commit -q -m "unrelated change outside ext/"
CONSUMER_SCOPING="$WORKDIR/consumer-scoping"
write_state "$CONSUMER_SCOPING" "$EXT_DIR" "$HEAD_V1"
OUT_SCOPING="$(run_checker "$CONSUMER_SCOPING" 2>&1)"
RC_SCOPING=$?
if [[ "$RC_SCOPING" -eq 0 && -z "$OUT_SCOPING" ]]; then
  pass "SCOPING: change outside ext/ subdirectory produces no output (path-scoped, not whole-repo HEAD)"
else
  fail "SCOPING: expected silence after unrelated commit, got rc=$RC_SCOPING output=<<<$OUT_SCOPING>>>"
fi

# =====================================================================
# Deliberate-break check (documented here, not run automatically): inverting the comparison
# (recomputed_head == recorded_head triggers WARN instead of !=) makes the FRESH case emit a
# WARN and the STALE case go silent -- proving these cases are load-bearing rather than vacuous.
# Verified manually during implementation; not re-run on every invocation since it requires
# mutating the checker script in place.
# =====================================================================

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
