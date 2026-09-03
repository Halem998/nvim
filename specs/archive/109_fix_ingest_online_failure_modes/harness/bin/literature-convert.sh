#!/usr/bin/env bash
# Harness stub for literature-convert.sh -- usage: literature-convert.sh <source_file> <out_dir>
# Behavior controlled by HARNESS_CONVERT_MODE:
#   success            (default) write <out_dir>/<sanitized-basename>.md, exit 0
#   quality_gate_fail  print the real quality-gate stderr line, exit 3
#   hard_fail          print a generic error, exit 2
#   no_md_produced     exit 0 but write no .md file (exercises the "conversion reported
#                      success but no .md file found" branch)
set -euo pipefail

SOURCE_FILE="${1:-}"
OUT_DIR="${2:-}"
MODE="${HARNESS_CONVERT_MODE:-success}"

case "$MODE" in
  quality_gate_fail)
    echo "[convert] QUALITY GATE FAILED (harness-stub): simulated sentence_boundary_glue_count() rejection" >&2
    exit 3
    ;;
  hard_fail)
    echo "[convert] ERROR: simulated hard conversion failure" >&2
    exit 2
    ;;
  no_md_produced)
    exit 0
    ;;
  success|*)
    mkdir -p "$OUT_DIR"
    base="$(basename "$SOURCE_FILE")"
    doc_id="$(echo "${base%.*}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cs '[:alnum:]_.-' '_' | sed -E 's/_+$//')"
    cat > "$OUT_DIR/${doc_id}.md" <<MD
# Harness Document

This is a harness-generated markdown body with enough sentences to chunk. It exists purely to
drive literature-ingest.sh through a controlled success path. Sentence two. Sentence three.
MD
    exit 0
    ;;
esac
