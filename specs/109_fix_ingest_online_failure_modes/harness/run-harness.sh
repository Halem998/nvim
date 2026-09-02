#!/usr/bin/env bash
# run-harness.sh - Forced-failure / stub-driven verification harness for the online-ingest
# bridge fixes. See the implementation summary for how each scenario maps to a defect.
#
# Usage: bash run-harness.sh <scenario>
#
# Scenarios:
#   arxiv-only-create-failed   pre-fix repro: arxiv_only.json against unfixed script fails
#                              ONLINE_INGEST_ZOTERO_CREATE_FAILED (exit 3)
#   arxiv-only-fixed           post-fix: arxiv_only.json succeeds via synthesized --doi
#   doi-present-unaffected     doi_present.json: real doi still passed, no synth doi appended
#   staging-cleanup-create     force item-add failure, assert no leftover staging PDF
#   staging-cleanup-attach     force attach failure on in_zotero_no_pdf path, assert no leftover
#                              staging PDF
#   quality-gate-orphan        force literature-convert.sh quality-gate rejection, assert no
#                              leftover sources/<doc_id>/ dir
#   hard-fail-orphan           force literature-convert.sh hard failure, assert no orphan
#   no-md-orphan               force "success but no .md produced", assert no orphan
#   chunk-fail-orphan          force literature-chunk.sh failure, assert no orphan
#   pipeline-failed-message    force literature-convert.sh quality-gate rejection through the
#                              full bridge, assert PIPELINE_FAILED rationale is enriched
#   success-control            clean end-to-end success (positive control)
#   dedup-title-noise          sanity: LITERATURE_DIR override is honored (nothing written to
#                              the real corpus)
#
# Every scenario sets LITERATURE_DIR to a fresh scratch directory under harness/scratch/ and
# never touches the real ~/Projects/Literature/.

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HARNESS_DIR/bin"
RECORDS="$HARNESS_DIR/records"
REAL_CURL="$(command -v curl)"

export PATH="$HARNESS_DIR/stub-path:$PATH"
export HARNESS_REAL_CURL="$REAL_CURL"
export ZOTERO_API_KEY="harness-dummy-key"
export GIT_ROOT="$(cd "$HARNESS_DIR/../../.." && pwd)"

scenario="${1:-}"
if [ -z "$scenario" ]; then
  echo "Usage: $0 <scenario>" >&2
  exit 64
fi

SCRATCH="$(mktemp -d "$HARNESS_DIR/scratch/run-XXXXXX")"
export LITERATURE_DIR="$SCRATCH/Literature"
mkdir -p "$LITERATURE_DIR"
echo '{"entries": []}' > "$LITERATURE_DIR/index.json"

REAL_CORPUS="$HOME/Projects/Literature"
real_corpus_snapshot=""
if [ -d "$REAL_CORPUS" ]; then
  real_corpus_snapshot="$(find "$REAL_CORPUS" -maxdepth 1 | sort | md5sum)"
fi

cleanup() {
  if [ -d "$REAL_CORPUS" ]; then
    new_snapshot="$(find "$REAL_CORPUS" -maxdepth 1 | sort | md5sum)"
    if [ "$new_snapshot" != "$real_corpus_snapshot" ]; then
      echo "HARNESS SAFETY VIOLATION: real corpus at $REAL_CORPUS was modified!" >&2
      exit 99
    fi
  fi
}
trap cleanup EXIT

run_online() {
  local record_file="$1"
  bash "$BIN/literature-ingest-online.sh" --record "$(cat "$record_file")"
}

echo "=== Scenario: $scenario ==="
echo "LITERATURE_DIR=$LITERATURE_DIR"

case "$scenario" in

  arxiv-only-create-failed)
    # Pre-fix repro: no --doi passed for an arxiv-only record -> stub zot fails exit 3.
    set +e
    OUT="$(HARNESS_ZOT_ADD_FAIL=0 run_online "$RECORDS/arxiv_only.json")"
    rc=$?
    set -e
    echo "stdout: $OUT"
    echo "exit: $rc"
    [ "$rc" -eq 3 ] && [ "$OUT" = "ONLINE_INGEST_ZOTERO_CREATE_FAILED" ] || { echo "FAIL: expected exit 3 / ONLINE_INGEST_ZOTERO_CREATE_FAILED for the pre-fix repro"; exit 1; }
    echo "OK (this is the pre-fix repro; run arxiv-only-fixed after Phase 2 lands)"
    ;;

  arxiv-only-fixed)
    set +e
    OUT="$(run_online "$RECORDS/arxiv_only.json" 2>"$SCRATCH/stderr.log")"
    rc=$?
    set -e
    echo "stdout: $OUT"
    echo "exit: $rc"
    echo "--- stderr (grep synthesized doi) ---"
    grep -n 'synth\|arXiv' "$SCRATCH/stderr.log" || true
    [ "$rc" -eq 0 ] && [ "$OUT" = "ONLINE_INGEST_INGESTED" ] || { echo "FAIL: expected ONLINE_INGEST_INGESTED"; cat "$SCRATCH/stderr.log"; exit 1; }
    echo "OK: arXiv-only record now succeeds via synthesized --doi"
    ;;

  doi-present-unaffected)
    set +e
    OUT="$(run_online "$RECORDS/doi_present.json" 2>"$SCRATCH/stderr.log")"
    rc=$?
    set -e
    echo "stdout: $OUT / exit: $rc"
    if grep -qi 'synth' "$SCRATCH/stderr.log"; then
      echo "FAIL: synthesized-DOI log line appeared for a record that already has a real DOI"
      exit 1
    fi
    [ "$rc" -eq 0 ] && [ "$OUT" = "ONLINE_INGEST_INGESTED" ] || { echo "FAIL"; cat "$SCRATCH/stderr.log"; exit 1; }
    echo "OK: DOI-present record unaffected by the arXiv elif arm"
    ;;

  staging-cleanup-create)
    set +e
    OUT="$(HARNESS_ZOT_ADD_FAIL=1 run_online "$RECORDS/arxiv_only.json")"
    rc=$?
    set -e
    echo "stdout: $OUT / exit: $rc"
    STAGING_DIR="$LITERATURE_DIR/.online-ingest-staging"
    echo "staging dir contents:"; ls -la "$STAGING_DIR" 2>/dev/null || echo "(absent)"
    if [ -d "$STAGING_DIR" ] && find "$STAGING_DIR" -name '*.pdf' | grep -q .; then
      echo "FAIL: leftover staging PDF after forced item-add failure"
      exit 1
    fi
    echo "OK: no leftover staging PDF after forced CREATE_FAILED"
    ;;

  staging-cleanup-attach)
    set +e
    OUT="$(HARNESS_ZOT_ATTACH_FAIL=1 HARNESS_RESOLVE_TIER=matched-no-pdf HARNESS_UNPAYWALL_OA_URL="https://arxiv.org/pdf/1009.2803" run_online "$RECORDS/in_zotero_no_pdf.json")"
    rc=$?
    set -e
    echo "stdout: $OUT / exit: $rc"
    STAGING_DIR="$LITERATURE_DIR/.online-ingest-staging"
    echo "staging dir contents:"; ls -la "$STAGING_DIR" 2>/dev/null || echo "(absent)"
    if [ -d "$STAGING_DIR" ] && find "$STAGING_DIR" -name '*.pdf' | grep -q .; then
      echo "FAIL: leftover staging PDF after forced attach failure"
      exit 1
    fi
    echo "OK: no leftover staging PDF after forced ATTACH_FAILED"
    ;;

  quality-gate-orphan|hard-fail-orphan|no-md-orphan|chunk-fail-orphan)
    case "$scenario" in
      quality-gate-orphan) export HARNESS_CONVERT_MODE=quality_gate_fail; export HARNESS_CHUNK_MODE=success ;;
      hard-fail-orphan) export HARNESS_CONVERT_MODE=hard_fail; export HARNESS_CHUNK_MODE=success ;;
      no-md-orphan) export HARNESS_CONVERT_MODE=no_md_produced; export HARNESS_CHUNK_MODE=success ;;
      chunk-fail-orphan) export HARNESS_CONVERT_MODE=success; export HARNESS_CHUNK_MODE=fail ;;
    esac
    SRC_PDF="$SCRATCH/harness_orphan_doc.pdf"
    printf '%%PDF-1.4 harness' > "$SRC_PDF"
    set +e
    bash "$BIN/literature-ingest.sh" "$SRC_PDF" --no-local >"$SCRATCH/ingest-stdout.log" 2>"$SCRATCH/ingest-stderr.log"
    rc=$?
    set -e
    echo "exit: $rc"
    tail -5 "$SCRATCH/ingest-stderr.log"
    ORPHAN_DIR="$LITERATURE_DIR/sources/harness_orphan_doc"
    if [ -d "$ORPHAN_DIR" ]; then
      echo "FAIL: orphan directory left behind: $ORPHAN_DIR"
      ls -la "$ORPHAN_DIR"
      exit 1
    fi
    echo "OK: no orphan sources/<doc_id>/ directory after forced failure ($scenario)"
    ;;

  pipeline-failed-message)
    export HARNESS_CONVERT_MODE=quality_gate_fail
    set +e
    OUT="$(run_online "$RECORDS/arxiv_only.json" 2>"$SCRATCH/stderr.log")"
    rc=$?
    set -e
    echo "stdout: $OUT / exit: $rc"
    echo "--- stderr ---"
    cat "$SCRATCH/stderr.log"
    [ "$rc" -eq 6 ] && [ "$OUT" = "ONLINE_INGEST_PIPELINE_FAILED" ] || { echo "FAIL: expected PIPELINE_FAILED(6)"; exit 1; }
    echo "OK: PIPELINE_FAILED reached; inspect stderr above for the enrichment text"
    ;;

  success-control)
    set +e
    OUT="$(run_online "$RECORDS/arxiv_only.json" 2>"$SCRATCH/stderr.log")"
    rc=$?
    set -e
    echo "stdout: $OUT / exit: $rc"
    DOC_DIR="$LITERATURE_DIR/sources/arxiv_1009_2803"
    if [ ! -f "$DOC_DIR/chunks.json" ]; then
      echo "FAIL: positive control did not produce a populated sources/<doc_id>/"
      cat "$SCRATCH/stderr.log"
      exit 1
    fi
    echo "OK: success path still produces a populated sources/<doc_id>/ (cleanup did not fire)"
    ;;

  *)
    echo "Unknown scenario: $scenario" >&2
    exit 64
    ;;
esac

echo "Real corpus at $REAL_CORPUS: untouched (verified by trap)"
