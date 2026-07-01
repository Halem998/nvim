#!/usr/bin/env bash
# literature-build-index.sh - Build or rebuild SQLite FTS5 database from chunk files
#
# Usage:
#   literature-build-index.sh --global              # rebuild ~/Projects/Literature/.literature.db
#   literature-build-index.sh --local               # rebuild specs/literature/.literature.db
#   literature-build-index.sh --global --local      # rebuild both
#   literature-build-index.sh --dir /custom/path    # rebuild specific directory
#
# The database is ephemeral — rebuilt from chunk files on disk.
# Uses atomic rename: builds .literature.db.tmp then renames to .literature.db
#
# Environment:
#   LITERATURE_DIR  — Override global library path (default: ~/Projects/Literature)
#
# Exit codes:
#   0 — success
#   1 — no chunk manifests found
#   2 — sqlite3 not available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/literature-schema.sql"

log() { echo "[build-index] $*" >&2; }

# Check required tools
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "[build-index] sqlite3 not found — required for index building" >&2
  exit 2
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "[build-index] Schema file not found: $SCHEMA_FILE" >&2
  exit 2
fi

# --- Argument parsing ---
BUILD_GLOBAL=0
BUILD_LOCAL=0
CUSTOM_DIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) BUILD_GLOBAL=1; shift ;;
    --local)  BUILD_LOCAL=1;  shift ;;
    --dir)    CUSTOM_DIRS+=("$2"); shift 2 ;;
    *) shift ;;
  esac
done

# Default: at least one of --global or --local
if [ "$BUILD_GLOBAL" -eq 0 ] && [ "$BUILD_LOCAL" -eq 0 ] && [ ${#CUSTOM_DIRS[@]} -eq 0 ]; then
  echo "[build-index] Usage: $0 --global | --local | --dir <path>" >&2
  echo "[build-index] Use --global --local to rebuild both databases" >&2
  exit 1
fi

# --- Build target list ---
declare -a TARGET_DIRS=()

if [ "$BUILD_GLOBAL" -eq 1 ]; then
  GLOBAL_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
  TARGET_DIRS+=("$GLOBAL_DIR")
fi

if [ "$BUILD_LOCAL" -eq 1 ]; then
  # Find git root for local specs/literature/
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  LOCAL_DIR="$GIT_ROOT/specs/literature"
  TARGET_DIRS+=("$LOCAL_DIR")
fi

for d in "${CUSTOM_DIRS[@]}"; do
  TARGET_DIRS+=("$d")
done

# --- Build function ---
build_index_for_dir() {
  local target_dir="$1"
  local db_path="$target_dir/.literature.db"
  local db_tmp="$target_dir/.literature.db.tmp"

  if [ ! -d "$target_dir" ]; then
    log "Directory not found, skipping: $target_dir"
    return 0
  fi

  # Find all chunks.json manifests
  mapfile -t manifests < <(find "$target_dir" -name "chunks.json" | sort)

  if [ ${#manifests[@]} -eq 0 ]; then
    log "No chunk manifests found in: $target_dir"
    log "Run 'literature-ingest.sh' to add literature before indexing"
    return 0
  fi

  log "Found ${#manifests[@]} manifests in $target_dir"
  log "Building index at $db_tmp..."

  # Remove old tmp file if exists
  rm -f "$db_tmp"

  # Initialize schema
  sqlite3 "$db_tmp" < "$SCHEMA_FILE"

  # Build index via Python (handles JSON parsing and content reading)
  python3 << PYEOF
import sqlite3
import json
import os
import sys
import re

db_path = "$db_tmp"
target_dir = "$target_dir"

conn = sqlite3.connect(db_path)
conn.execute("PRAGMA journal_mode=WAL")
conn.execute("PRAGMA synchronous=NORMAL")

manifest_paths = """$(printf '%s\n' "${manifests[@]}")""".strip().split('\n')

total_chunks = 0
total_relations = 0
total_crossrefs = 0
errors = 0

# We'll insert into chunks_data, then rebuild FTS at the end
all_chunk_ids = {}  # chunk_id -> doc_id (for cross-ref resolution)

for manifest_path in manifest_paths:
    if not manifest_path.strip():
        continue

    try:
        with open(manifest_path) as f:
            chunks = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"[build-index] Error reading {manifest_path}: {e}", file=sys.stderr)
        errors += 1
        continue

    manifest_dir = os.path.dirname(manifest_path)

    # Build lookup for cross-ref resolution within doc
    doc_chunks_by_label = {}  # label string -> chunk_id

    for chunk in chunks:
        chunk_id = chunk.get('chunk_id', '')
        doc_id = chunk.get('doc_id', '')
        all_chunk_ids[chunk_id] = doc_id

        # Index by title and section_path for cross-ref resolution
        title = chunk.get('title', '')
        section_path = chunk.get('section_path', '')
        if title:
            doc_chunks_by_label.setdefault(doc_id, {})[title] = chunk_id
            # Also try short form (last part of section_path)
            for part in section_path.split(' > '):
                doc_chunks_by_label.setdefault(doc_id, {})[part.strip()] = chunk_id

    # Insert chunks into chunks_data
    for chunk in chunks:
        chunk_id = chunk.get('chunk_id', '')
        doc_id = chunk.get('doc_id', '')
        source_path = chunk.get('source_path', '')

        # Read first ~500 words from the chunk file for FTS content field
        chunk_file = os.path.join(manifest_dir, source_path)
        content_preview = ''
        if os.path.isfile(chunk_file):
            try:
                with open(chunk_file, encoding='utf-8', errors='replace') as cf:
                    chunk_text = cf.read()
                # First 500 words (approximate)
                words = chunk_text.split()[:500]
                content_preview = ' '.join(words)
            except IOError:
                content_preview = ''

        # Convert cross_refs list to JSON string if needed
        cross_refs = chunk.get('cross_refs', [])
        if isinstance(cross_refs, list):
            cross_refs_json = json.dumps(cross_refs)
        else:
            cross_refs_json = str(cross_refs)

        try:
            conn.execute("""
                INSERT OR REPLACE INTO chunks_data
                (chunk_id, doc_id, parent_chunk_id, level, section_path, title,
                 keywords, summary, token_count, source_path, prev_chunk_id,
                 next_chunk_id, cross_refs)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                chunk_id,
                doc_id,
                chunk.get('parent_chunk_id'),
                chunk.get('level', 1),
                chunk.get('section_path', ''),
                chunk.get('title', ''),
                chunk.get('keywords', ''),
                chunk.get('summary', ''),
                chunk.get('token_count', 0),
                source_path,
                chunk.get('prev_chunk_id'),
                chunk.get('next_chunk_id'),
                cross_refs_json,
            ))

            # Store content_preview separately for FTS - we need to add a content column
            # to chunks_data for FTS5 content table linking
            # First check if content column exists and add it
            try:
                conn.execute("SELECT content FROM chunks_data LIMIT 0")
            except sqlite3.OperationalError:
                conn.execute("ALTER TABLE chunks_data ADD COLUMN content TEXT DEFAULT ''")

            conn.execute("UPDATE chunks_data SET content=? WHERE chunk_id=?",
                        (content_preview, chunk_id))

            total_chunks += 1
        except sqlite3.Error as e:
            print(f"[build-index] Error inserting chunk {chunk_id}: {e}", file=sys.stderr)
            errors += 1
            continue

conn.commit()

# Rebuild FTS index after all inserts
print(f"[build-index] Rebuilding FTS index for {total_chunks} chunks...", file=sys.stderr)
conn.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
conn.commit()

# Resolve cross-references and insert chunk_relations
print(f"[build-index] Resolving cross-references...", file=sys.stderr)

cursor = conn.execute("SELECT chunk_id, doc_id, cross_refs, parent_chunk_id FROM chunks_data")
rows = cursor.fetchall()

for chunk_id, doc_id, cross_refs_json, parent_chunk_id in rows:
    if not cross_refs_json or cross_refs_json == '[]':
        continue

    try:
        cross_refs = json.loads(cross_refs_json)
    except (json.JSONDecodeError, TypeError):
        continue

    doc_labels = doc_chunks_by_label.get(doc_id, {})

    for ref_label in cross_refs:
        ref_label_clean = re.sub(r'\s+', ' ', ref_label).strip()
        target_chunk_id = doc_labels.get(ref_label_clean)

        if target_chunk_id and target_chunk_id != chunk_id:
            try:
                conn.execute("""
                    INSERT OR IGNORE INTO chunk_relations (from_chunk_id, to_chunk_id, relation_type, weight)
                    VALUES (?, ?, 'cross_ref', 1.0)
                """, (chunk_id, target_chunk_id))
                total_crossrefs += 1
            except sqlite3.Error:
                pass

    # Structural parent/child relation
    if parent_chunk_id:
        try:
            conn.execute("""
                INSERT OR IGNORE INTO chunk_relations (from_chunk_id, to_chunk_id, relation_type, weight)
                VALUES (?, ?, 'child', 1.0)
            """, (parent_chunk_id, chunk_id))
            conn.execute("""
                INSERT OR IGNORE INTO chunk_relations (from_chunk_id, to_chunk_id, relation_type, weight)
                VALUES (?, ?, 'parent', 1.0)
            """, (chunk_id, parent_chunk_id))
            total_relations += 2
        except sqlite3.Error:
            pass

conn.commit()
total_relations += total_crossrefs

# Report stats
db_size = os.path.getsize(db_path) // 1024
print(f"[build-index] Indexed: {total_chunks} chunks, {total_crossrefs} cross-refs resolved, {total_relations} total relations, {db_size}KB database", file=sys.stderr)

if errors > 0:
    print(f"[build-index] WARNING: {errors} errors during indexing", file=sys.stderr)

conn.close()
PYEOF

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    log "Index build failed (exit $exit_code)"
    rm -f "$db_tmp"
    return 1
  fi

  # Atomic rename
  mv "$db_tmp" "$db_path"
  log "Database ready: $db_path"
  return 0
}

# --- Run builds ---
ALL_OK=1
for target in "${TARGET_DIRS[@]}"; do
  if ! build_index_for_dir "$target"; then
    ALL_OK=0
  fi
done

if [ "$ALL_OK" -eq 1 ]; then
  log "All indexes built successfully"
  exit 0
else
  log "Some indexes failed to build"
  exit 1
fi
