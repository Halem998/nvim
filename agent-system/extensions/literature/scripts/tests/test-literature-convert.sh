#!/usr/bin/env bash
# test-literature-convert.sh - Forced-fallback + two-column regression tests
# for literature-convert.sh.
#
# Proves the two things this task class exists to guarantee:
#   1. The mandatory PyMuPDF column-clustering fallback tier is ACTUALLY
#      exercised (not just written and never run — the exact bug class BUG 1
#      was: a preferred engine silently absent, nobody noticed for months).
#   2. Column reading order is correct on a real multi-column layout, locked
#      in as a regression fixture so it can never silently regress again.
#
# All test conversions write to a scratch temp directory ONLY. This suite
# NEVER reads from or writes to ~/Projects/Literature/ (the real corpus) —
# see this suite's explicit "do not mutate the corpus" constraint. The
# optional real-Alur-PDF check (see below) only READS a user-supplied path.
#
# Usage:
#   .claude/scripts/tests/test-literature-convert.sh
#
# Optional real-PDF stronger check:
#   LITERATURE_TEST_PDF=/path/to/alur.pdf .claude/scripts/tests/test-literature-convert.sh
#
#   The real Alur et al. 2013 "Syntax-Guided Synthesis" FMCAD'13 tutorial
#   paper (the exact known-bad corpus case this task fixes) can be obtained
#   from the cs.utexas.edu FMCAD'13 mirror:
#     https://www.cs.utexas.edu/~hunt/FMCAD/FMCAD13/papers/Tutorial-Syntax-Guided-Synthesis.pdf
#   Download it locally and point LITERATURE_TEST_PDF at it to additionally
#   assert the real known-bad body page now extracts in correct order. If
#   LITERATURE_TEST_PDF is unset, this check SKIPS WITH A VISIBLE WARNING —
#   it never fails the suite and never silently does nothing.
#
# Exit codes: 0 — all required tests passed; 1 — a required test failed.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
CONVERT_SH="$SCRIPT_DIR/literature-convert.sh"
FIXTURE_GEN="$TESTS_DIR/generate-test-fixtures.py"

PASS=0
FAIL=0

t_log() { echo "[test-convert] $*" >&2; }
t_pass() { PASS=$((PASS + 1)); t_log "PASS: $*"; }
t_fail() { FAIL=$((FAIL + 1)); t_log "FAIL: $*"; }

if [ ! -x "$CONVERT_SH" ]; then
  t_log "literature-convert.sh not found or not executable at $CONVERT_SH"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  t_log "python3 not available; cannot generate fixtures"
  exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# ============================================================
# Test 1: Forced-fallback — primary tier forced unavailable, assert the
# mandatory PyMuPDF column-clustering fallback tier is actually taken
# (logged) and either passes the interleaving heuristic (exit 0) or fails
# loudly (exit 3) — never a silent garbage success.
# ============================================================

FIXTURE1="$WORKDIR/two_column.pdf"
python3 "$FIXTURE_GEN" two-column "$FIXTURE1" >/dev/null

OUT1="$WORKDIR/out1"
mkdir -p "$OUT1"
STDERR1="$WORKDIR/stderr1.log"
LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" "$FIXTURE1" "$OUT1" >/dev/null 2>"$STDERR1"
EXIT1=$?

if grep -q "mandatory PyMuPDF column-clustering fallback tier" "$STDERR1" \
   && grep -qE 'Engine used: pymupdf-fallback-(toc|heuristic)' "$STDERR1"; then
  t_pass "forced-fallback: fallback tier was actually taken (logged)"
else
  t_fail "forced-fallback: no evidence the fallback tier ran — log:"
  cat "$STDERR1" >&2
fi

case "$EXIT1" in
  0)
    if [ -f "$OUT1/two_column.md" ]; then
      t_pass "forced-fallback: exit 0, output written"
    else
      t_fail "forced-fallback: exit 0 but no output file found"
    fi
    ;;
  3)
    if [ -f "$OUT1/two_column.md.rejected" ] && [ ! -f "$OUT1/two_column.md" ]; then
      t_pass "forced-fallback: exit 3 (loud quality-gate failure), .rejected written, no final .md — acceptable per contract (never silently wrong)"
    else
      t_fail "forced-fallback: exit 3 but loud-failure contract violated (missing .rejected or a final .md exists alongside it)"
    fi
    ;;
  *)
    t_fail "forced-fallback: unexpected exit code $EXIT1 (expected 0 or 3)"
    ;;
esac

# ============================================================
# Test 2: Two-column regression fixture — hermetic synthetic PDF, known
# left-column and right-column sentences, asserts LEFTCOL is never
# interleaved with RIGHTCOL on the same line and appears fully before
# RIGHTCOL in the output (correct reading order).
#
# Runs against the MANDATORY fallback tier specifically (the column-
# clustering algorithm this task built in Phase 3), not auto mode — this is
# a deterministic regression lock on OUR OWN algorithm. The primary tier
# (pymupdf4llm, a third-party library) is exercised separately in Test 2b
# below with the looser "correct OR loudly rejected" acceptance criteria,
# since its internal reading-order correctness is outside this task's
# control (not guaranteed on arbitrary layouts) — the
# quality gate, not this fixture, is pymupdf4llm's safety net.
# ============================================================

check_two_column_order() {
  local md_file="$1" label="$2"
  local ok=0

  if grep -qE 'LEFTCOL.*RIGHTCOL|RIGHTCOL.*LEFTCOL' "$md_file"; then
    t_fail "$label: LEFTCOL/RIGHTCOL text glued on the same line"
    ok=1
  else
    t_pass "$label: no LEFTCOL/RIGHTCOL glue on any single line"
  fi

  local last_left first_right
  last_left=$(grep -n "LEFTCOL sentence four" "$md_file" | head -1 | cut -d: -f1)
  first_right=$(grep -n "RIGHTCOL sentence one" "$md_file" | head -1 | cut -d: -f1)
  if [ -n "$last_left" ] && [ -n "$first_right" ]; then
    if [ "$last_left" -lt "$first_right" ]; then
      t_pass "$label: LEFTCOL fully precedes RIGHTCOL (correct reading order)"
    else
      t_fail "$label: RIGHTCOL text appeared before LEFTCOL completed (wrong reading order)"
      ok=1
    fi
  else
    t_fail "$label: could not locate both column markers in output (extraction dropped content)"
    ok=1
  fi
  return $ok
}

OUT2="$WORKDIR/out2"
mkdir -p "$OUT2"
STDERR2="$WORKDIR/stderr2.log"
LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" "$FIXTURE1" "$OUT2" >/dev/null 2>"$STDERR2"
EXIT2=$?

if [ "$EXIT2" -eq 0 ] && [ -f "$OUT2/two_column.md" ]; then
  check_two_column_order "$OUT2/two_column.md" "two-column regression (fallback tier)"
else
  t_fail "two-column regression (fallback tier): expected exit 0 with output; got exit $EXIT2"
  cat "$STDERR2" >&2
fi

# ============================================================
# Test 2b: same fixture through AUTO mode (whichever tier is actually
# available on this machine). Looser acceptance, matching Test 1's
# philosophy: EITHER correct order (exit 0) OR a loud quality-gate
# rejection (exit 3) — never a silent wrong answer. This test surfaced a
# real finding during Phase 6 verification: pymupdf4llm's own reading-order
# logic can misorder this specific synthetic layout (concatenating columns
# with no separator at all), which the quality gate now catches via the
# sentence-boundary-glue check.
# ============================================================

OUT2B="$WORKDIR/out2b"
mkdir -p "$OUT2B"
STDERR2B="$WORKDIR/stderr2b.log"
"$CONVERT_SH" "$FIXTURE1" "$OUT2B" >/dev/null 2>"$STDERR2B"
EXIT2B=$?

case "$EXIT2B" in
  0)
    if [ -f "$OUT2B/two_column.md" ]; then
      check_two_column_order "$OUT2B/two_column.md" "two-column regression (auto mode)"
    else
      t_fail "two-column regression (auto mode): exit 0 but no output file found"
    fi
    ;;
  3)
    if [ -f "$OUT2B/two_column.md.rejected" ] && [ ! -f "$OUT2B/two_column.md" ]; then
      t_pass "two-column regression (auto mode): exit 3 (loud quality-gate failure) — acceptable per contract (never silently wrong)"
    else
      t_fail "two-column regression (auto mode): exit 3 but loud-failure contract violated"
    fi
    ;;
  *)
    t_fail "two-column regression (auto mode): unexpected exit code $EXIT2B (expected 0 or 3)"
    ;;
esac

# ============================================================
# Test 3: sentence-boundary-glue exemptions (negative) — locks in that two
# benign, corpus-endemic patterns (Ph.D. bibliography entries and
# single-letter-variable quantifier/binder notation such as ∀x.P, ∃y.E,
# ∃x.Q) never trip the sentence-boundary-glue quality-gate check. Strict
# (exit 0 required), not exit-0-or-3 like Test 1/Test 2b, since locking in
# "these benign patterns never fail the gate" is precisely this test's
# purpose.
# ============================================================

FIXTURE_BQ="$WORKDIR/biblio_quantifier.pdf"
python3 "$FIXTURE_GEN" biblio-quantifier "$FIXTURE_BQ" >/dev/null

OUT_BQ="$WORKDIR/out_bq"
mkdir -p "$OUT_BQ"
STDERR_BQ="$WORKDIR/stderr_bq.log"
LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" "$FIXTURE_BQ" "$OUT_BQ" >/dev/null 2>"$STDERR_BQ"
EXIT_BQ=$?

if [ "$EXIT_BQ" -eq 0 ] && [ -f "$OUT_BQ/biblio_quantifier.md" ]; then
  t_pass "sentence-boundary-glue exemptions (negative): exit 0, final .md written"
else
  t_fail "sentence-boundary-glue exemptions (negative): expected exit 0 with output; got exit $EXIT_BQ — stderr:"
  cat "$STDERR_BQ" >&2
fi

# ============================================================
# Test 3b: genuine fused-word corruption still rejected (positive) — proves
# the exemptions added for Test 3 did not widen the check enough to also
# hide the real zero-space word/sentence-fusion defect signature this check
# exists to catch (mirrors Test 1's exit-3 branch assertions). Additionally
# asserts the rejection reason is specifically sentence-boundary-glue, so
# this test cannot pass for the wrong reason if another gate check starts
# firing instead.
# ============================================================

FIXTURE_FW="$WORKDIR/fused_word.pdf"
python3 "$FIXTURE_GEN" fused-word "$FIXTURE_FW" >/dev/null

OUT_FW="$WORKDIR/out_fw"
mkdir -p "$OUT_FW"
STDERR_FW="$WORKDIR/stderr_fw.log"
LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" "$FIXTURE_FW" "$OUT_FW" >/dev/null 2>"$STDERR_FW"
EXIT_FW=$?

if [ "$EXIT_FW" -eq 3 ] && [ -f "$OUT_FW/fused_word.md.rejected" ] && [ ! -f "$OUT_FW/fused_word.md" ]; then
  t_pass "genuine fused-word corruption still rejected (positive): exit 3, .rejected written, no final .md"
else
  t_fail "genuine fused-word corruption still rejected (positive): expected exit 3 with .rejected and no final .md; got exit $EXIT_FW — stderr:"
  cat "$STDERR_FW" >&2
fi

if grep -q "sentence-boundary-glue" "$STDERR_FW"; then
  t_pass "genuine fused-word corruption still rejected (positive): rejection reason is sentence-boundary-glue"
else
  t_fail "genuine fused-word corruption still rejected (positive): rejection reason was NOT sentence-boundary-glue — stderr:"
  cat "$STDERR_FW" >&2
fi

# ============================================================
# Supplementary: no-TOC heading tightening (BUG 3 upstream cause), locked in
# as a regression fixture. Not one of Phase 6's two required tests, but
# cheap and directly protects the Phase 3 fix beyond the ad-hoc verification
# done during implementation.
# ============================================================

FIXTURE3="$WORKDIR/bold_heading.pdf"
python3 "$FIXTURE_GEN" bold-heading "$FIXTURE3" >/dev/null
OUT3="$WORKDIR/out3"
mkdir -p "$OUT3"
LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" "$FIXTURE3" "$OUT3" >/dev/null 2>"$WORKDIR/stderr3.log"
EXIT3=$?
OUT3_MD="$OUT3/bold_heading.md"
[ "$EXIT3" -eq 3 ] && OUT3_MD="$OUT3/bold_heading.md.rejected"

if [ -f "$OUT3_MD" ]; then
  if grep -qE '^##[[:space:]]+indeterminacy\.' "$OUT3_MD"; then
    t_fail "no-TOC heading: sentence-fragment 'indeterminacy.' was promoted to a heading"
  else
    t_pass "no-TOC heading: sentence-fragment correctly rejected"
  fi
  if grep -qE '^##[[:space:]]+Introduction' "$OUT3_MD"; then
    t_pass "no-TOC heading: genuine short bold heading correctly accepted"
  else
    t_fail "no-TOC heading: genuine 'Introduction' heading was missed"
  fi
else
  t_fail "no-TOC heading: no output produced at all (exit $EXIT3)"
fi

# ============================================================
# Test 4: literature_quality_gate.py self-test fixtures, run as part of
# this suite via `literature-convert.sh --self-test` (the shared entry
# point that also exercises literature_combining_overlay.py's fixtures).
# ============================================================

STDERR_SELFTEST="$WORKDIR/stderr_selftest.log"
"$CONVERT_SH" --self-test >"$WORKDIR/stdout_selftest.log" 2>"$STDERR_SELFTEST"
EXIT_SELFTEST=$?
if [ "$EXIT_SELFTEST" -eq 0 ] && grep -q "All fixtures passed" "$WORKDIR/stdout_selftest.log"; then
  t_pass "literature-convert.sh --self-test: all fixtures passed (combining-overlay + quality-gate)"
else
  t_fail "literature-convert.sh --self-test: expected exit 0 with 'All fixtures passed'; got exit $EXIT_SELFTEST — stderr:"
  cat "$STDERR_SELFTEST" >&2
fi

# ============================================================
# Test 5: broken-font-encoding fixture (positive — must-fail regression).
# Simulates the glyph-index-as-codepoint corruption signature this task's
# checks exist to catch. Strict assertion on the MANDATORY fallback tier
# (LITERATURE_CONVERTER=pymupdf), where the fixture's literal NUL/control
# characters are confirmed to survive PyMuPDF's own text extraction intact
# (verified directly: page.get_text("dict") preserves them unchanged).
#
# The primary tier (pymupdf4llm) is NOT asserted against this specific
# synthetic fixture: pymupdf4llm's to_markdown() was found during Phase 5/6
# verification to apply its own heuristic character-substitution cleanup
# beyond raw MuPDF extraction (observed to turn "0"->"O", "1"->"l", and
# raw \x00-\x08 runs into stray printable substitute characters such as
# "¢") that happens to sanitize THIS insert_text()-constructed fixture
# before it reaches the gate — a limitation of this cheap synthetic
# reproduction technique, not evidence that genuinely broken embedded PDF
# fonts are safe on the primary tier. The "fails on every tier" guarantee
# for real corruption is a structural property instead: run_quality_gate()
# has exactly one call site in run_unified_engine(), applied unconditionally
# to whichever tier's `content` was produced — see literature-convert.sh's
# QUALITY GATE section comment. The already-ingested real corpus evidence
# (pym_ohearn_yang_2004_possible-worlds-resources-bi, 1352 real NUL bytes
# reaching final output — see calibration-notes.md) is the real-world proof
# that genuine font corruption does reach gate time; this fixture proves
# the new checks correctly reject it once there.
# ============================================================

FIXTURE_BROKEN="$WORKDIR/broken_font.pdf"
python3 "$FIXTURE_GEN" broken-font "$FIXTURE_BROKEN" >/dev/null

OUT_BROKEN="$WORKDIR/out_broken"
mkdir -p "$OUT_BROKEN"
STDERR_BROKEN="$WORKDIR/stderr_broken.log"
LITERATURE_CONVERTER=pymupdf "$CONVERT_SH" "$FIXTURE_BROKEN" "$OUT_BROKEN" >/dev/null 2>"$STDERR_BROKEN"
EXIT_BROKEN=$?

if [ "$EXIT_BROKEN" -eq 3 ] && [ -f "$OUT_BROKEN/broken_font.md.rejected" ] && [ ! -f "$OUT_BROKEN/broken_font.md" ]; then
  if grep -q "control-character" "$STDERR_BROKEN" && grep -q "printable-ratio" "$STDERR_BROKEN"; then
    t_pass "broken-font-encoding (fallback tier): exit 3, .rejected written, both control-character and printable-ratio reasons present"
  else
    t_fail "broken-font-encoding (fallback tier): exit 3 with .rejected but expected reasons not both present — stderr:"
    cat "$STDERR_BROKEN" >&2
  fi
else
  t_fail "broken-font-encoding (fallback tier): expected exit 3 with .rejected and no final .md; got exit $EXIT_BROKEN — stderr:"
  cat "$STDERR_BROKEN" >&2
fi

t_log "WARNING: broken-font-encoding fixture is NOT asserted against the primary (pymupdf4llm) tier — see this test's header comment for why (pymupdf4llm's own cleanup heuristics sanitize this specific synthetic construction). This is a documented limitation of the synthetic reproduction technique, never silently skipped without explanation."

# ============================================================
# Optional stronger check: real Alur SyGuS PDF, if available. Converts to a
# scratch dir ONLY — never touches ~/Projects/Literature/. Skips with a
# visible warning (never fails the suite) if LITERATURE_TEST_PDF is unset.
# ============================================================

if [ -n "${LITERATURE_TEST_PDF:-}" ] && [ -f "${LITERATURE_TEST_PDF:-}" ]; then
  OUT4="$WORKDIR/out4"
  mkdir -p "$OUT4"
  "$CONVERT_SH" "$LITERATURE_TEST_PDF" "$OUT4" >/dev/null 2>"$WORKDIR/stderr4.log"
  EXIT4=$?
  OUT4_MD=$(ls "$OUT4"/*.md 2>/dev/null | head -1)
  [ -z "$OUT4_MD" ] && OUT4_MD=$(ls "$OUT4"/*.md.rejected 2>/dev/null | head -1)
  if [ -n "$OUT4_MD" ] && [ -f "$OUT4_MD" ]; then
    GLUE_COUNT=$(grep -cP '\S\s{4,}\S' "$OUT4_MD" 2>/dev/null || echo 0)
    if [ "$GLUE_COUNT" -eq 0 ]; then
      t_pass "real Alur PDF: zero column-glue lines in output (exit $EXIT4)"
    else
      t_fail "real Alur PDF: $GLUE_COUNT column-glued line(s) remain in output"
    fi
  else
    t_fail "real Alur PDF: no output produced at all (exit $EXIT4)"
  fi
else
  t_log "WARNING: LITERATURE_TEST_PDF not set or file not found — skipping the optional real-Alur-PDF stronger check (never fails the suite). See this script's header comment for how to obtain the PDF."
fi

# ============================================================
# Summary
# ============================================================

t_log "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
