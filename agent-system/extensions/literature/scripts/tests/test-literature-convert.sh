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
# Test 6: image-only (no-text-layer) fixture — locks in the exit-2 NO TEXT
# LAYER: messaging contract, the never-auto-invoked guarantee for
# LITERATURE_CONVERTER=ocr, the graceful ocrmypdf-absence path, and the
# real OCR round-trip when ocrmypdf is actually available.
# ============================================================

FIXTURE_IMG="$WORKDIR/image_only.pdf"
python3 "$FIXTURE_GEN" image-only "$FIXTURE_IMG" >/dev/null

# --- 6a: auto exits 2 with the marker and the named remedy ---
#
# The primary tier's venv is forced unavailable here so this assertion is
# deterministic: see generate-test-fixtures.py's build_image_only_pdf()
# docstring — pymupdf4llm's own force_text=True default (pre-existing,
# unrelated to this task's ocrmypdf-based mode) can otherwise silently
# recover real text from this exact fixture shape via its own internal
# Tesseract call whenever the primary tier's venv AND system tesseract are
# both present, which would mask the exit-2 contract this test locks in.
# `auto` degrading to the mandatory fallback tier (no such internal OCR
# trigger) is exactly what happens on any machine without a provisioned
# venv, so this is a representative, not a contrived, scenario.

# A nonexistent-but-writable LITERATURE_PYENV_DIR is NOT sufficient to force
# unavailability -- literature-pyenv-provision.sh happily auto-provisions a
# fresh venv there if `uv` and network access are available, which silently
# restores the very primary tier this test needs unavailable. An unwritable
# parent directory makes `uv venv` fail deterministically instead.
UNWRITABLE_PYENV_PARENT="$WORKDIR/unwritable_pyenv_parent"
mkdir -p "$UNWRITABLE_PYENV_PARENT"
chmod 000 "$UNWRITABLE_PYENV_PARENT"

OUT_IMG_AUTO="$WORKDIR/out_img_auto"
mkdir -p "$OUT_IMG_AUTO"
STDERR_IMG_AUTO="$WORKDIR/stderr_img_auto.log"
LITERATURE_PYENV_DIR="$UNWRITABLE_PYENV_PARENT/venv" \
  "$CONVERT_SH" "$FIXTURE_IMG" "$OUT_IMG_AUTO" >/dev/null 2>"$STDERR_IMG_AUTO"
EXIT_IMG_AUTO=$?
chmod 755 "$UNWRITABLE_PYENV_PARENT"

if [ "$EXIT_IMG_AUTO" -eq 2 ]; then
  t_pass "image-only fixture (auto, primary tier forced unavailable): exit 2"
else
  t_fail "image-only fixture (auto, primary tier forced unavailable): expected exit 2, got $EXIT_IMG_AUTO — stderr:"
  cat "$STDERR_IMG_AUTO" >&2
fi

if grep -q 'NO TEXT LAYER:' "$STDERR_IMG_AUTO"; then
  t_pass "image-only fixture: NO TEXT LAYER: marker present in stderr"
else
  t_fail "image-only fixture: NO TEXT LAYER: marker missing from stderr"
fi

if grep -q 'LITERATURE_CONVERTER=ocr' "$STDERR_IMG_AUTO"; then
  t_pass "image-only fixture: stderr names the LITERATURE_CONVERTER=ocr remedy"
else
  t_fail "image-only fixture: stderr does not name the LITERATURE_CONVERTER=ocr remedy"
fi

# --- 6b: auto never invokes ocrmypdf ---
#
# A PATH-shadowing stub records invocation via a marker file; prepended
# ahead of the real ocrmypdf (if any), it intercepts any call the script
# makes. Run WITHOUT forcing the primary tier unavailable this time — the
# assertion (ocrmypdf, the external CLI, is never invoked) holds regardless
# of which tier `auto` actually uses.
OCR_STUB_DIR="$WORKDIR/ocr_stub_bin"
mkdir -p "$OCR_STUB_DIR"
OCR_INVOKED_MARKER="$WORKDIR/ocr_invoked_marker"
cat > "$OCR_STUB_DIR/ocrmypdf" << STUBEOF
#!/usr/bin/env bash
touch "$OCR_INVOKED_MARKER"
exit 1
STUBEOF
chmod +x "$OCR_STUB_DIR/ocrmypdf"

OUT_IMG_AUTO2="$WORKDIR/out_img_auto2"
mkdir -p "$OUT_IMG_AUTO2"
rm -f "$OCR_INVOKED_MARKER"
PATH="$OCR_STUB_DIR:$PATH" "$CONVERT_SH" "$FIXTURE_IMG" "$OUT_IMG_AUTO2" >/dev/null 2>"$WORKDIR/stderr_img_auto2.log"

if [ ! -f "$OCR_INVOKED_MARKER" ]; then
  t_pass "image-only fixture: auto mode never invokes ocrmypdf (stub not triggered)"
else
  t_fail "image-only fixture: auto mode invoked ocrmypdf (stub WAS triggered) — auto must never reach the ocr_explicit branch"
fi

# --- 6c: LITERATURE_CONVERTER=ocr with ocrmypdf absent from PATH ---
#
# Runs UNCONDITIONALLY (does not require ocrmypdf to be installed). Masks
# ocrmypdf (and tesseract) off PATH by symlinking every OTHER entry of
# ocrmypdf's real bin directory into a scratch dir — a plain PATH override
# excluding that whole directory breaks bash's own shebang resolution on a
# single-bin-dir system (e.g. NixOS, where bash/python3/ocrmypdf all live
# side by side) — then invokes the script via `bash "$CONVERT_SH"` directly
# so the calling shell (not the masked PATH) resolves `bash` itself.
mask_ocrmypdf_path() {
  local real_ocrmypdf real_dir scratch_bin f base
  real_ocrmypdf=$(command -v ocrmypdf 2>/dev/null || true)
  scratch_bin=$(mktemp -d)
  if [ -z "$real_ocrmypdf" ]; then
    echo "$scratch_bin"
    return
  fi
  real_dir=$(dirname "$real_ocrmypdf")
  for f in "$real_dir"/*; do
    base=$(basename "$f")
    case "$base" in
      ocrmypdf|tesseract) continue ;;
    esac
    ln -s "$f" "$scratch_bin/$base" 2>/dev/null
  done
  echo "$scratch_bin"
}

MASKED_BIN=$(mask_ocrmypdf_path)
OUT_IMG_NOOCR="$WORKDIR/out_img_noocr"
mkdir -p "$OUT_IMG_NOOCR"
STDERR_IMG_NOOCR="$WORKDIR/stderr_img_noocr.log"
PATH="$MASKED_BIN" LITERATURE_CONVERTER=ocr bash "$CONVERT_SH" "$FIXTURE_IMG" "$OUT_IMG_NOOCR" >/dev/null 2>"$STDERR_IMG_NOOCR"
EXIT_IMG_NOOCR=$?

if [ "$EXIT_IMG_NOOCR" -ne 0 ] && grep -qi "ocrmypdf: not available" "$STDERR_IMG_NOOCR" && ! grep -qi "traceback" "$STDERR_IMG_NOOCR"; then
  t_pass "LITERATURE_CONVERTER=ocr with ocrmypdf absent: clean non-zero exit, graceful-detection message, no traceback"
else
  t_fail "LITERATURE_CONVERTER=ocr with ocrmypdf absent: expected a clean non-zero exit with a graceful-detection message and no traceback; got exit $EXIT_IMG_NOOCR — stderr:"
  cat "$STDERR_IMG_NOOCR" >&2
fi

# --- 6d: real OCR round-trip (ocrmypdf-dependent; SKIPS WITH A VISIBLE
# WARNING when ocrmypdf is absent — never silently passes, never fails the
# suite, following the existing LITERATURE_TEST_PDF skip idiom) ---
if command -v ocrmypdf >/dev/null 2>&1; then
  OUT_IMG_OCR="$WORKDIR/out_img_ocr"
  mkdir -p "$OUT_IMG_OCR"
  STDERR_IMG_OCR="$WORKDIR/stderr_img_ocr.log"
  LITERATURE_CONVERTER=ocr "$CONVERT_SH" "$FIXTURE_IMG" "$OUT_IMG_OCR" >/dev/null 2>"$STDERR_IMG_OCR"
  EXIT_IMG_OCR=$?
  if [ "$EXIT_IMG_OCR" -eq 0 ] && [ -s "$OUT_IMG_OCR/image_only.md" ]; then
    t_pass "LITERATURE_CONVERTER=ocr on image-only fixture: exit 0, non-empty .md written"
  else
    t_fail "LITERATURE_CONVERTER=ocr on image-only fixture: expected exit 0 with non-empty output; got exit $EXIT_IMG_OCR — stderr:"
    cat "$STDERR_IMG_OCR" >&2
  fi
else
  t_log "WARNING: ocrmypdf not available on PATH — skipping the real-OCR-path test for LITERATURE_CONVERTER=ocr (never fails the suite). Install ocrmypdf (and tesseract) to exercise this path."
fi

# --- 6e: exit-3 gate-rejection stderr still starts with the unmodified
# QUALITY GATE FAILED prefix, and now also carries the remedy line. Reuses
# Test 3b's fused-word fixture/stderr capture rather than reconverting. ---
if grep -q '^\[convert\] QUALITY GATE FAILED' "$STDERR_FW"; then
  t_pass "gate-rejection stderr: QUALITY GATE FAILED prefix unmodified"
else
  t_fail "gate-rejection stderr: QUALITY GATE FAILED prefix missing or modified — stderr:"
  cat "$STDERR_FW" >&2
fi

if grep -q 'Remedy:' "$STDERR_FW"; then
  t_pass "gate-rejection stderr: carries the new remedy line"
else
  t_fail "gate-rejection stderr: missing the new remedy line — stderr:"
  cat "$STDERR_FW" >&2
fi

# --- 6f: literature-ingest.sh bucketing coverage — an image-only file lands
# in "Files needing OCR", and a marker-free exit-2 (primary tier forced but
# unavailable) still lands in "Files failed". Scratch directories only;
# never touches ~/Projects/Literature/. ---
INGEST_SH="$SCRIPT_DIR/literature-ingest.sh"
if [ -x "$INGEST_SH" ]; then
  INGEST_SCRATCH_LIT="$WORKDIR/ingest_scratch_lit"
  INGEST_SRC_DIR="$WORKDIR/ingest_src"
  mkdir -p "$INGEST_SCRATCH_LIT" "$INGEST_SRC_DIR"
  cp "$FIXTURE1" "$INGEST_SRC_DIR/good_doc.pdf"
  cp "$FIXTURE_IMG" "$INGEST_SRC_DIR/image_only.pdf"

  STDOUT_INGEST="$WORKDIR/stdout_ingest.log"
  LITERATURE_DIR="$INGEST_SCRATCH_LIT" LITERATURE_CONVERTER=pymupdf \
    "$INGEST_SH" "$INGEST_SRC_DIR" --no-local >"$STDOUT_INGEST" 2>"$WORKDIR/stderr_ingest.log"

  if grep -q "Files needing OCR: 1" "$STDOUT_INGEST" && grep -q "image_only.pdf" "$STDOUT_INGEST"; then
    t_pass "literature-ingest.sh: image-only file lands in the needs-OCR bucket"
  else
    t_fail "literature-ingest.sh: image-only file did not land in the needs-OCR bucket — stdout:"
    cat "$STDOUT_INGEST" >&2
  fi

  if grep -q "Files failed: 0" "$STDOUT_INGEST"; then
    t_pass "literature-ingest.sh: Files failed stayed 0 (image-only file correctly bucketed as needs-OCR, not a hard failure)"
  else
    t_fail "literature-ingest.sh: expected Files failed: 0 — stdout:"
    cat "$STDOUT_INGEST" >&2
  fi

  INGEST_SCRATCH_LIT2="$WORKDIR/ingest_scratch_lit2"
  INGEST_SRC_DIR2="$WORKDIR/ingest_src2"
  mkdir -p "$INGEST_SCRATCH_LIT2" "$INGEST_SRC_DIR2"
  cp "$FIXTURE1" "$INGEST_SRC_DIR2/good_doc.pdf"

  UNWRITABLE_PYENV_PARENT2="$WORKDIR/unwritable_pyenv_parent2"
  mkdir -p "$UNWRITABLE_PYENV_PARENT2"
  chmod 000 "$UNWRITABLE_PYENV_PARENT2"

  STDOUT_INGEST2="$WORKDIR/stdout_ingest2.log"
  STDERR_INGEST2="$WORKDIR/stderr_ingest2.log"
  # LITERATURE_CONVERTER applies to the whole run (there is no per-file
  # override), so the sole source file here fails via the marker-free
  # exit-2 path and PROCESSED stays 0 -- literature-ingest.sh takes its
  # early "all files failed" branch and exits 3 BEFORE ever reaching the
  # "=== Ingestion Summary ===" block (that block is unreachable when
  # PROCESSED==0), so this asserts against the early-exit aggregate log
  # line instead (the Phase 2 task bullet that added the needs-OCR count to
  # that exact message).
  LITERATURE_DIR="$INGEST_SCRATCH_LIT2" LITERATURE_CONVERTER=pymupdf4llm \
    LITERATURE_PYENV_DIR="$UNWRITABLE_PYENV_PARENT2/venv" \
    "$INGEST_SH" "$INGEST_SRC_DIR2" --no-local >"$STDOUT_INGEST2" 2>"$STDERR_INGEST2"
  chmod 755 "$UNWRITABLE_PYENV_PARENT2"

  # GATE_FAILED and OCR_NEEDED are both 0 in this pure-hard-failure scenario,
  # so literature-ingest.sh takes the plain "All files failed to process"
  # branch (the parenthesized breakdown only appears when at least one of
  # those two counters is nonzero) -- assert the plain line, and NOT the
  # needs-OCR breakdown, so this stays a real regression lock rather than a
  # match against a string that never actually appears in this scenario.
  if grep -q "All files failed to process" "$STDERR_INGEST2" && ! grep -q "needing OCR" "$STDERR_INGEST2"; then
    t_pass "literature-ingest.sh: marker-free exit-2 (primary tier unavailable) reported as a plain hard failure, not needs-OCR"
  else
    t_fail "literature-ingest.sh: marker-free exit-2 mis-bucketed — stderr:"
    cat "$STDERR_INGEST2" >&2
  fi
else
  t_fail "literature-ingest.sh not found or not executable at $INGEST_SH"
fi

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
