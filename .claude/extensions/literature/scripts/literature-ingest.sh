#!/usr/bin/env bash
# literature-ingest.sh - Main ingestion entry point for the literature pipeline
#
# Usage:
#   literature-ingest.sh <path>                  # Ingest PDF/DJVU file or directory
#   literature-ingest.sh --zotero <key>           # Ingest from Zotero key lookup
#   literature-ingest.sh <path> --no-local        # Skip local-loading prompt
#   literature-ingest.sh <path> --local           # Auto-accept local loading
#
# Pipeline:
#   1. Resolve source (file / directory / zotero key)
#   2. For each PDF/DJVU: convert to markdown (literature-convert.sh)
#   3. For each markdown: chunk (literature-chunk.sh)
#   4. Update global index.json
#   5. Rebuild global .literature.db (literature-build-index.sh --global)
#   6. Offer local loading (copy to specs/literature/, rebuild local index)
#
# Environment:
#   LITERATURE_DIR  — Global library path (default: ~/Projects/Literature)
#   ZOTERO_LIBRARY_PATH — Path to zotero-library.json (default: ~/Projects/Literature/zotero-library.json)
#
# Exit codes:
#   0 — success
#   1 — argument error
#   2 — no source files found
#   3 — all conversions failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
ZOTERO_LIBRARY_PATH="${ZOTERO_LIBRARY_PATH:-$LITERATURE_DIR/zotero-library.json}"

log() { echo "[ingest] $*" >&2; }
log_out() { echo "[ingest] $*"; }

# --- Check required scripts ---
for script in literature-convert.sh literature-chunk.sh literature-build-index.sh; do
  if [ ! -x "$SCRIPT_DIR/$script" ]; then
    echo "[ingest] Required script not found or not executable: $SCRIPT_DIR/$script" >&2
    exit 1
  fi
done

# --- Argument parsing ---
SOURCE=""
ZOTERO_KEY=""
NO_LOCAL=0
AUTO_LOCAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zotero) ZOTERO_KEY="${2:-}"; shift 2 ;;
    --no-local) NO_LOCAL=1; shift ;;
    --local) AUTO_LOCAL=1; shift ;;
    -*) echo "[ingest] Unknown flag: $1" >&2; exit 1 ;;
    *) SOURCE="$1"; shift ;;
  esac
done

# --- Resolve source files ---
declare -a SOURCE_FILES=()

if [ -n "$ZOTERO_KEY" ]; then
  # Zotero key resolution
  if [ ! -f "$ZOTERO_LIBRARY_PATH" ]; then
    echo "[ingest] Zotero library not found: $ZOTERO_LIBRARY_PATH" >&2
    exit 1
  fi

  log "Looking up Zotero key: $ZOTERO_KEY"
  PDF_PATH=$(python3 << PYEOF
import json
import sys

zotero_path = "$ZOTERO_LIBRARY_PATH"
key = "$ZOTERO_KEY"

try:
    with open(zotero_path) as f:
        library = json.load(f)
except Exception as e:
    print(f"[ingest] Error reading Zotero library: {e}", file=sys.stderr)
    sys.exit(1)

# Search for key in library entries
entries = library if isinstance(library, list) else library.get('entries', library.get('items', []))

for entry in entries:
    entry_key = entry.get('key', '') or entry.get('zotero_key', '') or entry.get('id', '')
    if entry_key == key or key.lower() in str(entry_key).lower():
        # Look for PDF path
        pdf = entry.get('pdf_path') or entry.get('file', '') or entry.get('attachment', '')
        if pdf and (pdf.endswith('.pdf') or pdf.endswith('.djvu')):
            print(pdf)
            sys.exit(0)
        attachments = entry.get('attachments', [])
        for att in attachments:
            att_path = att.get('path', '') if isinstance(att, dict) else str(att)
            if att_path.endswith('.pdf') or att_path.endswith('.djvu'):
                print(att_path)
                sys.exit(0)

print(f"[ingest] No PDF found for Zotero key: {key}", file=sys.stderr)
sys.exit(1)
PYEOF
)
  if [ -n "$PDF_PATH" ] && [ -f "$PDF_PATH" ]; then
    SOURCE_FILES+=("$PDF_PATH")
  else
    echo "[ingest] Could not resolve Zotero key to PDF: $ZOTERO_KEY" >&2
    exit 2
  fi

elif [ -n "$SOURCE" ]; then
  if [ -f "$SOURCE" ]; then
    # Single file
    EXT="${SOURCE##*.}"
    EXT="${EXT,,}"
    if [[ "$EXT" == "pdf" || "$EXT" == "djvu" ]]; then
      SOURCE_FILES+=("$SOURCE")
    else
      echo "[ingest] Unsupported file type: $EXT (supported: pdf, djvu)" >&2
      exit 1
    fi
  elif [ -d "$SOURCE" ]; then
    # Directory: collect all PDFs and DJVUs
    while IFS= read -r f; do
      SOURCE_FILES+=("$f")
    done < <(find "$SOURCE" -maxdepth 2 \( -name "*.pdf" -o -name "*.djvu" \) | sort)

    if [ ${#SOURCE_FILES[@]} -eq 0 ]; then
      echo "[ingest] No PDF or DJVU files found in: $SOURCE" >&2
      exit 2
    fi
  else
    echo "[ingest] Source not found: $SOURCE" >&2
    exit 1
  fi
else
  echo "[ingest] Usage: $0 <path|--zotero key> [--no-local|--local]" >&2
  exit 1
fi

log "Found ${#SOURCE_FILES[@]} source file(s) to ingest"

# --- Ensure global library directory exists ---
mkdir -p "$LITERATURE_DIR"

# --- Process each source file ---
PROCESSED=0
FAILED=0
declare -a INGESTED_DOC_IDS=()

for source_file in "${SOURCE_FILES[@]}"; do
  log "Processing: $source_file"

  # Derive base doc_id from filename
  BASENAME=$(basename "$source_file")
  BASE_DOC_ID="${BASENAME%.*}"
  BASE_DOC_ID=$(echo "$BASE_DOC_ID" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cs '[:alnum:]_.-' '_')
  BASE_DOC_ID="${BASE_DOC_ID%_}"

  # Output directory for this document
  DOC_DIR="$LITERATURE_DIR/$BASE_DOC_ID"

  # Check for re-ingestion: warn if doc_id already exists
  GLOBAL_INDEX="$LITERATURE_DIR/index.json"
  if [ -f "$GLOBAL_INDEX" ]; then
    EXISTING=$(python3 -c "
import json
with open('$GLOBAL_INDEX') as f:
    idx = json.load(f)
entries = idx if isinstance(idx, list) else idx.get('entries', [])
existing = next((e for e in entries if e.get('doc_id','') == '$BASE_DOC_ID'), None)
print('yes' if existing else 'no')
" 2>/dev/null || echo "no")
    if [ "$EXISTING" == "yes" ]; then
      log "WARNING: Re-ingesting '$BASE_DOC_ID' — deleting old chunks"
      rm -rf "$DOC_DIR"
    fi
  fi

  mkdir -p "$DOC_DIR"

  # Step 1: Convert to markdown
  TMP_MD_DIR=$(mktemp -d)
  log "Converting: $BASENAME"
  DOC_ID=$("$SCRIPT_DIR/literature-convert.sh" "$source_file" "$TMP_MD_DIR" 2>&1 | tail -1)
  # The last line of stdout is the doc_id
  DOC_ID=$(cat "$TMP_MD_DIR"/*.md 2>/dev/null | head -0; ls "$TMP_MD_DIR"/*.md 2>/dev/null | head -1 | xargs -I{} basename {} .md)

  if [ -z "$DOC_ID" ] || ! ls "$TMP_MD_DIR"/*.md >/dev/null 2>&1; then
    log "ERROR: Conversion failed for $BASENAME"
    rm -rf "$TMP_MD_DIR"
    FAILED=$((FAILED + 1))
    continue
  fi

  MD_FILE=$(ls "$TMP_MD_DIR"/*.md | head -1)
  DOC_ID=$(basename "$MD_FILE" .md)

  # Update DOC_DIR to use the actual doc_id
  DOC_DIR="$LITERATURE_DIR/$DOC_ID"
  mkdir -p "$DOC_DIR"

  log "doc_id: $DOC_ID"

  # Step 2: Chunk the markdown
  log "Chunking: $MD_FILE"
  CHUNK_COUNT=$("$SCRIPT_DIR/literature-chunk.sh" "$MD_FILE" "$DOC_DIR" --doc-id "$DOC_ID" 2>/dev/null || echo "0")
  rm -rf "$TMP_MD_DIR"

  if [ "$CHUNK_COUNT" -eq 0 ] || [ ! -f "$DOC_DIR/chunks.json" ]; then
    log "ERROR: Chunking failed for $DOC_ID"
    FAILED=$((FAILED + 1))
    continue
  fi

  log "Created $CHUNK_COUNT chunks in $DOC_DIR"

  # Step 3: Write document metadata
  INGESTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$DOC_DIR/metadata.json" << METAEOF
{
  "doc_id": "$DOC_ID",
  "title": "$DOC_ID",
  "authors": [],
  "year": null,
  "source_path": "$source_file",
  "chunks_dir": "$DOC_DIR",
  "chunk_count": $CHUNK_COUNT,
  "ingested_at": "$INGESTED_AT"
}
METAEOF

  # Step 4: Update global index.json
  python3 << PYEOF
import json
import os

index_path = "$GLOBAL_INDEX" if "$GLOBAL_INDEX" else "$LITERATURE_DIR/index.json"
index_path = "$LITERATURE_DIR/index.json"

# Read or create index
if os.path.isfile(index_path):
    try:
        with open(index_path) as f:
            idx = json.load(f)
    except Exception:
        idx = {"entries": []}
else:
    idx = {"entries": []}

# Normalize to entries list
entries = idx if isinstance(idx, list) else idx.get('entries', [])
if isinstance(idx, dict) and 'entries' not in idx:
    idx = {"entries": entries}
elif isinstance(idx, list):
    idx = {"entries": idx}

# Remove old entry for this doc_id
idx['entries'] = [e for e in idx['entries'] if e.get('doc_id', '') != '$DOC_ID']

# Add new entry
new_entry = {
    "doc_id": "$DOC_ID",
    "title": "$DOC_ID",
    "authors": [],
    "year": None,
    "source_path": "$source_file",
    "chunks_dir": "$DOC_DIR",
    "chunk_count": $CHUNK_COUNT,
    "ingested_at": "$INGESTED_AT"
}
idx['entries'].append(new_entry)

with open(index_path, 'w') as f:
    json.dump(idx, f, indent=2)

print(f"Updated index.json: {len(idx['entries'])} total entries", file=__import__('sys').stderr)
PYEOF

  INGESTED_DOC_IDS+=("$DOC_ID")
  PROCESSED=$((PROCESSED + 1))
  log_out "Ingested: $DOC_ID ($CHUNK_COUNT chunks)"
done

if [ "$PROCESSED" -eq 0 ]; then
  log "All files failed to process"
  exit 3
fi

# Step 5: Rebuild global database
log "Rebuilding global literature database..."
"$SCRIPT_DIR/literature-build-index.sh" --global 2>&1 | sed 's/^/[ingest] /' >&2

# Step 6: Offer local loading
if [ "$NO_LOCAL" -eq 1 ]; then
  log "Local loading skipped (--no-local)"
elif [ "$AUTO_LOCAL" -eq 1 ]; then
  log "Auto-accepting local loading (--local)"
  do_local_loading=1
else
  # Interactive prompt
  echo ""
  echo "Ingested: ${INGESTED_DOC_IDS[*]}"
  echo "Load into specs/literature/ in current repo? [y/N]"
  read -r -t 30 REPLY || REPLY="N"
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    do_local_loading=1
  else
    do_local_loading=0
  fi
fi

if [ "${do_local_loading:-0}" -eq 1 ]; then
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  LOCAL_LIT_DIR="$GIT_ROOT/specs/literature"
  mkdir -p "$LOCAL_LIT_DIR"

  for doc_id in "${INGESTED_DOC_IDS[@]}"; do
    DOC_SRC="$LITERATURE_DIR/$doc_id"
    DOC_DST="$LOCAL_LIT_DIR/$doc_id"

    if [ -d "$DOC_SRC" ]; then
      log "Copying $doc_id to local specs/literature/"
      mkdir -p "$DOC_DST"
      cp -r "$DOC_SRC"/* "$DOC_DST/"

      # Add global_id field to local chunk metadata
      if [ -f "$DOC_DST/chunks.json" ]; then
        python3 << PYEOF
import json
with open("$DOC_DST/chunks.json") as f:
    chunks = json.load(f)
for chunk in chunks:
    chunk['global_id'] = chunk.get('doc_id', '')
with open("$DOC_DST/chunks.json", 'w') as f:
    json.dump(chunks, f, indent=2)
PYEOF
      fi
    fi
  done

  log "Rebuilding local literature database..."
  "$SCRIPT_DIR/literature-build-index.sh" --local 2>&1 | sed 's/^/[ingest] /' >&2
  log "Local loading complete"
fi

# --- Summary ---
echo ""
echo "=== Ingestion Summary ==="
echo "Files processed: $PROCESSED"
echo "Files failed: $FAILED"
echo "Documents ingested: ${INGESTED_DOC_IDS[*]}"
echo "Global library: $LITERATURE_DIR"
if [ -f "$LITERATURE_DIR/.literature.db" ]; then
  DB_SIZE=$(du -sh "$LITERATURE_DIR/.literature.db" 2>/dev/null | cut -f1)
  echo "Global database: $LITERATURE_DIR/.literature.db ($DB_SIZE)"
fi
echo ""
echo "To search: literature-search.sh \"your query\""
