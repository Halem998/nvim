#!/usr/bin/env bash
# Harness stub for literature-chunk.sh -- usage:
#   literature-chunk.sh <md_file> <doc_dir> --doc-id <id>
# Behavior controlled by HARNESS_CHUNK_MODE:
#   success  (default) write <doc_dir>/chunks.json with one minimal chunk, print "1" to stdout
#   fail     print "0" to stdout, write no chunks.json (exercises the chunking-failure
#            continue branch)
set -euo pipefail

MD_FILE="${1:-}"
DOC_DIR="${2:-}"
DOC_ID=""
shift 2 || true
while [ $# -gt 0 ]; do
  case "$1" in
    --doc-id) DOC_ID="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

MODE="${HARNESS_CHUNK_MODE:-success}"

if [ "$MODE" = "fail" ]; then
  echo "0"
  exit 1
fi

mkdir -p "$DOC_DIR"
cat > "$DOC_DIR/chunks.json" <<JSON
[
  {
    "chunk_id": "harness0000000001",
    "doc_id": "$DOC_ID",
    "parent_chunk_id": null,
    "title": "Harness Chunk",
    "keywords": "harness stub",
    "summary": "Harness-generated chunk for verification purposes.",
    "token_count": 42,
    "source_path": "chunk_0001.md",
    "prev_chunk_id": null,
    "next_chunk_id": null
  }
]
JSON
echo "1"
exit 0
