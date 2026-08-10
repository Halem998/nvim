#!/usr/bin/env bash
# test-lean-sorry-census.sh -- regression suite for lean-sorry-census.sh's warn.sorry
# double-count defect: `\bsorry\b` fires at the `.`/`s` boundary inside dotted-qualified
# names such as `warn.sorry` or `foo.sorry`, so an own-line `set_option warn.sorry false in`
# suppression annotation is counted as a phantom sorry on top of the real sorry it suppresses.
#
# This is the first regression fixture this script has ever had. Per the task's falsifiability
# gate, this suite MUST be run once against the UNFIXED script (before the regex at line 144 is
# touched) and is expected to show Fixtures A, D, and E FAIL while B and C PASS -- proving the
# fixture actually discriminates the buggy behavior from the intended one, rather than being a
# vacuous suite that would pass either way.
#
# Anti-vacuous-test guard: Fixtures A and D additionally assert that the naive `\bsorry\b`
# per-line count DIFFERS from the tool's reported count on the same fixture text, so a fixture
# both implementations would agree on can never masquerade as coverage (per
# context/standards/shell-script-testing.md's mutation-check discipline).
#
# Follows the core shell-test convention (see
# agent-system/extensions/core/scripts/tests/test-census-count.sh): pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on
# all-pass and exit 1 on any-fail. All fixtures are synthetic heredocs; this suite never reads or
# asserts against the real repository tree.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-sorry-census.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-sorry-census.sh at $TOOL_SRC" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required by lean-sorry-census.sh and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

get_count() {
  # get_count <output> -- extracts the integer from "sorry_count: N".
  echo "$1" | grep -oE '^sorry_count: [0-9]+' | grep -oE '[0-9]+'
}

naive_count() {
  # naive_count <file> -- per-line naive \bsorry\b count over the raw fixture text, using the
  # SAME per-line "does this line match" semantic as the tool (not occurrence counting), so the
  # comparison isolates the regex change and nothing else.
  python3 -c '
import re, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    lines = fh.read().split("\n")
naive_re = re.compile(r"\bsorry\b")
print(sum(1 for l in lines if naive_re.search(l)))
' "$1"
}

# =====================================================================
# Fixture A: own-line annotation
#   set_option warn.sorry false in
#   theorem foo : P := sorry
# Expect exactly 1 (the real sorry only). The buggy regex matches "sorry" inside "warn.sorry"
# on the annotation's own line too, yielding 2.
# =====================================================================

cat > "$WORKDIR/fixture_a.lean" <<'EOF'
set_option warn.sorry false in
theorem foo : P := sorry
EOF

OUT_A="$(bash "$TOOL_SRC" "$WORKDIR/fixture_a.lean")"
COUNT_A="$(get_count "$OUT_A")"
if [ "$COUNT_A" = "1" ]; then
  pass "Fixture A (own-line annotation): count == 1"
else
  fail "Fixture A (own-line annotation): expected count 1, got '$COUNT_A'"
fi

NAIVE_A="$(naive_count "$WORKDIR/fixture_a.lean")"
if [ "$NAIVE_A" != "$COUNT_A" ]; then
  pass "Fixture A anti-vacuous: naive per-line count ($NAIVE_A) differs from tool count ($COUNT_A)"
else
  fail "Fixture A anti-vacuous: naive count ($NAIVE_A) equals tool count ($COUNT_A) -- fixture cannot discriminate"
fi

if echo "$OUT_A" | grep -q "theorem foo : P := sorry" && ! echo "$OUT_A" | grep -q "set_option warn.sorry false in$"; then
  pass "Fixture A inventory: contains 'theorem foo' line, excludes 'set_option' line"
else
  fail "Fixture A inventory: expected 'theorem foo' present and 'set_option' absent; got:
$OUT_A"
fi

# =====================================================================
# Fixture B: same-line annotation (non-regression guard)
#   set_option warn.sorry false in theorem bar : Q := sorry
# Expect exactly 1 -- not 0 (a line-skip anti-pattern that would silently drop a real
# same-line sorry) and not 2 (the per-line "search" semantic only counts a match once per
# line, regardless of how many sorry-shaped substrings appear on it).
# =====================================================================

cat > "$WORKDIR/fixture_b.lean" <<'EOF'
set_option warn.sorry false in theorem bar : Q := sorry
EOF

OUT_B="$(bash "$TOOL_SRC" "$WORKDIR/fixture_b.lean")"
COUNT_B="$(get_count "$OUT_B")"
if [ "$COUNT_B" = "1" ]; then
  pass "Fixture B (same-line annotation): count == 1"
else
  fail "Fixture B (same-line annotation): expected count 1, got '$COUNT_B'"
fi

# =====================================================================
# Fixture C: stripper guard -- one `--` line-commented sorry, one sorry inside a nested
# `/- ... /- ... -/ ... -/` block comment, and one sorry inside a `"..."` string literal.
# Each contributes 0; this exercises strip_lean_comments(), which is unrelated to the regex
# fix and must remain byte-identical throughout.
# =====================================================================

cat > "$WORKDIR/fixture_c.lean" <<'EOF'
-- line comment mentions sorry here
/- outer /- inner sorry -/ still outer -/
def baz : String := "a string containing sorry as text"
EOF

OUT_C="$(bash "$TOOL_SRC" "$WORKDIR/fixture_c.lean")"
COUNT_C="$(get_count "$OUT_C")"
if [ "$COUNT_C" = "0" ]; then
  pass "Fixture C (stripper guard): line comment, nested block comment, and string literal each contribute 0"
else
  fail "Fixture C (stripper guard): expected count 0, got '$COUNT_C'"
fi

# =====================================================================
# Fixture D: dotted-name generality -- a line containing `foo.sorry` with no bare sorry.
# Expect 0. The buggy regex fires at the `.`/`s` boundary just as it does for `warn.sorry`.
# =====================================================================

cat > "$WORKDIR/fixture_d.lean" <<'EOF'
def useProof : Bool := foo.sorry
EOF

OUT_D="$(bash "$TOOL_SRC" "$WORKDIR/fixture_d.lean")"
COUNT_D="$(get_count "$OUT_D")"
if [ "$COUNT_D" = "0" ]; then
  pass "Fixture D (dotted-name generality): count == 0"
else
  fail "Fixture D (dotted-name generality): expected count 0, got '$COUNT_D'"
fi

NAIVE_D="$(naive_count "$WORKDIR/fixture_d.lean")"
if [ "$NAIVE_D" != "$COUNT_D" ]; then
  pass "Fixture D anti-vacuous: naive per-line count ($NAIVE_D) differs from tool count ($COUNT_D)"
else
  fail "Fixture D anti-vacuous: naive count ($NAIVE_D) equals tool count ($COUNT_D) -- fixture cannot discriminate"
fi

# =====================================================================
# Fixture E: aggregate -- N=3 own-line annotations, M=2 real sorries. Expect the reported
# total to be M (2), not M + N (5).
# =====================================================================

cat > "$WORKDIR/fixture_e.lean" <<'EOF'
set_option warn.sorry false in
theorem t1 : P1 := trivial
set_option warn.sorry false in
theorem t2 : P2 := sorry
set_option warn.sorry false in
theorem t3 : P3 := trivial
theorem t4 : P4 := sorry
EOF

OUT_E="$(bash "$TOOL_SRC" "$WORKDIR/fixture_e.lean")"
COUNT_E="$(get_count "$OUT_E")"
if [ "$COUNT_E" = "2" ]; then
  pass "Fixture E (aggregate N=3 annotations, M=2 real sorries): count == M == 2"
else
  fail "Fixture E (aggregate N=3 annotations, M=2 real sorries): expected count 2, got '$COUNT_E'"
fi

# =====================================================================
# Summary
# =====================================================================

info "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
