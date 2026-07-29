#!/usr/bin/env bash
# test-phase-heading-patterns.sh - Fixture-driven regression suite for
# scripts/lib/phase-heading-patterns.sh, the single sourced anchor for the canonical
# `### Phase N: {name} [STATUS]` grammar, the closed status-marker enum, and non-conforming-
# heading detection (see context/formats/plan-format.md's "Canonical phase-heading shape"
# subsection for the policy this library implements).
#
# Structural model: scripts/tests/test-validate-no-task-references.sh (pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 on all-pass / exit 1 on any-fail). This suite
# sources the library directly rather than driving a subprocess, since the library exports shell
# functions and constants meant to be sourced, not a standalone executable.
#
# Library resolution mirrors the deploy-tree-first / source-store-fallback candidate list used by
# check-task-references.sh and the consumer scripts this library serves, so the suite runs
# correctly both post-deploy (.claude/scripts/lib/...) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/lib/...).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/phase-heading-patterns.sh"
  "$SCRIPT_DIR/../lib/phase-heading-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library phase-heading-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Positive fixtures: extract_phase_number succeeds; nonconforming_phase_headings reports nothing.
# One fixture per enum value, plus a decimal sub-phase case.
# =====================================================================
assert_extracts() {
  local label="$1" heading="$2" expected="$3" got code
  got="$(extract_phase_number "$heading")"
  code=$?
  if [[ "$code" -eq 0 && "$got" == "$expected" ]]; then
    pass "$label: extract_phase_number -> '$got'"
  else
    fail "$label: expected '$expected' (exit 0), got '$got' (exit $code)"
  fi
}

assert_extracts "positive: Phase 3 NOT STARTED"  "### Phase 3: Name [NOT STARTED]"  "3"
assert_extracts "positive: Phase 3.1 COMPLETED"  "### Phase 3.1: Name [COMPLETED]"  "3.1"
assert_extracts "positive: Phase 12 COMPLETED WITH EXCLUSIONS" \
  "### Phase 12: Name [COMPLETED WITH EXCLUSIONS]" "12"
assert_extracts "positive: Phase 4 IN PROGRESS"  "### Phase 4: Name [IN PROGRESS]"  "4"
assert_extracts "positive: Phase 5 PARTIAL"      "### Phase 5: Name [PARTIAL]"      "5"
assert_extracts "positive: Phase 6 BLOCKED"       "### Phase 6: Name [BLOCKED]"      "6"

# A file containing only the positive fixtures above must report zero non-conforming headings.
positive_file="$WORKDIR/positive.md"
cat > "$positive_file" <<'EOF'
### Phase 3: Name [NOT STARTED]
### Phase 3.1: Name [COMPLETED]
### Phase 12: Name [COMPLETED WITH EXCLUSIONS]
### Phase 4: Name [IN PROGRESS]
### Phase 5: Name [PARTIAL]
### Phase 6: Name [BLOCKED]
EOF
positive_findings="$(nonconforming_phase_headings "$positive_file")"
if [[ -z "$positive_findings" ]]; then
  pass "positive file: nonconforming_phase_headings reports nothing"
else
  fail "positive file: expected no findings, got: $positive_findings"
fi

# =====================================================================
# Negative number-token fixtures: must be reported by nonconforming_phase_headings AND must make
# extract_phase_number return empty with non-zero status -- never a truncated prefix.
# =====================================================================
assert_rejects() {
  local label="$1" heading="$2" got code
  got="$(extract_phase_number "$heading")"
  code=$?
  if [[ "$code" -ne 0 && -z "$got" ]]; then
    pass "$label: extract_phase_number rejects (empty, non-zero exit)"
  else
    fail "$label: expected empty + non-zero exit, got '$got' (exit $code) -- possible truncated-prefix regression"
  fi
}

assert_rejects "negative: Phase 3a"      "### Phase 3a: Name [NOT STARTED]"
assert_rejects "negative: Phase 3.1.2"   "### Phase 3.1.2: Name [NOT STARTED]"
assert_rejects "negative: Phase III"     "### Phase III: Name [NOT STARTED]"
assert_rejects "negative: Phase (empty)" "### Phase : Name [NOT STARTED]"

negative_number_file="$WORKDIR/negative-number.md"
cat > "$negative_number_file" <<'EOF'
### Phase 3a: Name [NOT STARTED]
### Phase 3.1.2: Name [NOT STARTED]
### Phase III: Name [NOT STARTED]
### Phase : Name [NOT STARTED]
EOF
negative_number_count="$(nonconforming_phase_headings "$negative_number_file" | wc -l | tr -d ' ')"
if [[ "$negative_number_count" -eq 4 ]]; then
  pass "negative-number file: all 4 headings reported non-conforming"
else
  fail "negative-number file: expected 4 findings, got $negative_number_count"
fi

# =====================================================================
# Negative marker fixtures: [DESCOPED] reported + warning names the [COMPLETED WITH EXCLUSIONS]
# replacement. An arbitrary-unknown-marker fixture proves the check is enum-driven, not a
# DESCOPED special case with no general rule behind it.
# =====================================================================
descoped_file="$WORKDIR/descoped.md"
cat > "$descoped_file" <<'EOF'
### Phase 3: Name [DESCOPED]
EOF
descoped_findings="$(nonconforming_phase_headings "$descoped_file")"
if [[ -n "$descoped_findings" ]]; then
  pass "DESCOPED heading: reported by nonconforming_phase_headings"
else
  fail "DESCOPED heading: expected a finding, got none"
fi

descoped_warning="$(warn_nonconforming "$descoped_file" "test" 2>&1 1>/dev/null)"
if echo "$descoped_warning" | grep -qF "COMPLETED WITH EXCLUSIONS"; then
  pass "DESCOPED warning: names [COMPLETED WITH EXCLUSIONS] as the replacement"
else
  fail "DESCOPED warning: replacement guidance missing. Got: $descoped_warning"
fi

arbitrary_file="$WORKDIR/arbitrary-marker.md"
cat > "$arbitrary_file" <<'EOF'
### Phase 3: Name [FROBNICATED]
EOF
arbitrary_findings="$(nonconforming_phase_headings "$arbitrary_file")"
if [[ -n "$arbitrary_findings" ]]; then
  pass "arbitrary-unknown-marker heading: reported (enum-driven, not a DESCOPED special case)"
else
  fail "arbitrary-unknown-marker heading: expected a finding, got none"
fi
arbitrary_warning="$(warn_nonconforming "$arbitrary_file" "test" 2>&1 1>/dev/null)"
if echo "$arbitrary_warning" | grep -qF "unrecognized status marker" && ! echo "$arbitrary_warning" | grep -qF "COMPLETED WITH EXCLUSIONS"; then
  pass "arbitrary-unknown-marker warning: generic unrecognized-marker reason, no DESCOPED-specific text"
else
  fail "arbitrary-unknown-marker warning: unexpected content: $arbitrary_warning"
fi

# =====================================================================
# Equivalence fixtures: the BRE compatibility alias and the ERE heading-match form must classify
# every fixture in this suite identically. A divergence here is exactly the drift this library
# exists to prevent.
# =====================================================================
all_fixture_headings=(
  "### Phase 3: Name [NOT STARTED]"
  "### Phase 3.1: Name [COMPLETED]"
  "### Phase 12: Name [COMPLETED WITH EXCLUSIONS]"
  "### Phase 4: Name [IN PROGRESS]"
  "### Phase 5: Name [PARTIAL]"
  "### Phase 6: Name [BLOCKED]"
  "### Phase 3a: Name [NOT STARTED]"
  "### Phase 3.1.2: Name [NOT STARTED]"
  "### Phase III: Name [NOT STARTED]"
  "### Phase : Name [NOT STARTED]"
  "### Phase 3: Name [DESCOPED]"
  "### Phase 3: Name [FROBNICATED]"
)
equivalence_ok=1
for heading in "${all_fixture_headings[@]}"; do
  ere_match=0
  bre_match=0
  grep -qE "$PHASE_HEADING_ERE" <<< "$heading" && ere_match=1
  grep -q  "$PHASE_HEADING_BRE" <<< "$heading" && bre_match=1
  if [[ "$ere_match" -ne "$bre_match" ]]; then
    equivalence_ok=0
    fail "equivalence: ERE/BRE diverge on '$heading' (ere=$ere_match bre=$bre_match)"
  fi
done
if [[ "$equivalence_ok" -eq 1 ]]; then
  pass "equivalence: ERE and BRE heading-match forms agree on all fixtures"
fi

# TOTAL-form equivalence (full-line conforming-heading-shape forms)
total_equivalence_ok=1
for heading in "${all_fixture_headings[@]}"; do
  ere_match=0
  bre_match=0
  grep -qE "$PHASE_HEADING_TOTAL_ERE" <<< "$heading" && ere_match=1
  grep -q  "$PHASE_HEADING_TOTAL_BRE" <<< "$heading" && bre_match=1
  if [[ "$ere_match" -ne "$bre_match" ]]; then
    total_equivalence_ok=0
    fail "TOTAL-form equivalence: ERE/BRE diverge on '$heading' (ere=$ere_match bre=$bre_match)"
  fi
done
if [[ "$total_equivalence_ok" -eq 1 ]]; then
  pass "equivalence: PHASE_HEADING_TOTAL_ERE and PHASE_HEADING_TOTAL_BRE agree on all fixtures"
fi

# DONE-form equivalence
done_equivalence_ok=1
for heading in "${all_fixture_headings[@]}"; do
  ere_match=0
  bre_match=0
  grep -qE "$PHASE_HEADING_DONE_ERE" <<< "$heading" && ere_match=1
  grep -q  "$PHASE_HEADING_DONE_BRE" <<< "$heading" && bre_match=1
  if [[ "$ere_match" -ne "$bre_match" ]]; then
    done_equivalence_ok=0
    fail "DONE-form equivalence: ERE/BRE diverge on '$heading' (ere=$ere_match bre=$bre_match)"
  fi
done
if [[ "$done_equivalence_ok" -eq 1 ]]; then
  pass "equivalence: PHASE_HEADING_DONE_ERE and PHASE_HEADING_DONE_BRE agree on all fixtures"
fi

# =====================================================================
# 3a/3b/3c case: three distinct non-conforming reports, not three identical "Phase 3" reports.
# =====================================================================
letter_suffix_file="$WORKDIR/letter-suffix.md"
cat > "$letter_suffix_file" <<'EOF'
### Phase 3a: First [NOT STARTED]
### Phase 3b: Second [NOT STARTED]
### Phase 3c: Third [NOT STARTED]
EOF
letter_suffix_findings="$(nonconforming_phase_headings "$letter_suffix_file")"
distinct_headings="$(echo "$letter_suffix_findings" | cut -d: -f3- | sort -u | wc -l | tr -d ' ')"
finding_count="$(echo "$letter_suffix_findings" | grep -c . || true)"
if [[ "$finding_count" -eq 3 && "$distinct_headings" -eq 3 ]]; then
  pass "3a/3b/3c: three distinct non-conforming reports (no collapse to a single 'Phase 3')"
else
  fail "3a/3b/3c: expected 3 distinct findings, got $finding_count findings / $distinct_headings distinct: $letter_suffix_findings"
fi
# Each must also fail extract_phase_number individually (never collapsing to a shared "3").
for h in "### Phase 3a: First [NOT STARTED]" "### Phase 3b: Second [NOT STARTED]" "### Phase 3c: Third [NOT STARTED]"; do
  r="$(extract_phase_number "$h")"
  c=$?
  if [[ "$c" -ne 0 && -z "$r" ]]; then
    pass "3a/3b/3c: '$h' individually rejected (no collapse to 'Phase 3')"
  else
    fail "3a/3b/3c: '$h' unexpectedly extracted '$r'"
  fi
done

# =====================================================================
# warn_nonconforming return-code contract: 0 when clean, 1 when findings exist.
# =====================================================================
clean_rc_out="$(warn_nonconforming "$positive_file" "test" 2>/dev/null)"
clean_rc=$?
if [[ "$clean_rc" -eq 0 ]]; then
  pass "warn_nonconforming: returns 0 on a clean file"
else
  fail "warn_nonconforming: expected 0 on clean file, got $clean_rc"
fi

dirty_rc_out="$(warn_nonconforming "$negative_number_file" "test" 2>/dev/null)"
dirty_rc=$?
if [[ "$dirty_rc" -eq 1 ]]; then
  pass "warn_nonconforming: returns 1 when non-conforming headings exist"
else
  fail "warn_nonconforming: expected 1 on file with findings, got $dirty_rc"
fi

# =====================================================================
# Deliberate-break check (documented here, not run automatically): flipping any exported
# constant, e.g. removing "COMPLETED WITH EXCLUSIONS" from PHASE_STATUS_ENUM, must make the
# suite above fail -- proving the assertions are live, not vacuous. Verified manually during
# implementation; not re-run on every invocation since it requires mutating the sourced library
# in place.
# =====================================================================

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
