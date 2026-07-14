#!/usr/bin/env bash
# zotero-index-remove.sh - Remove an item from the per-repo index
#
# Category C: Index Management (implemented in task 751)
#
# Usage:
#   zotero-index-remove.sh <zotero_key> [--delete-chunks]
#
# Arguments:
#   <zotero_key>      - 8-char Zotero item key (required)
#   --delete-chunks   - Also delete the chunk directory at the item's chunk_dir path
#
# Steps:
#   1. Find entry in specs/zotero-index.json by zotero_key; exit 1 if not found
#   2. If --delete-chunks and chunk_dir is non-null: rm -rf specs/literature/{citation_key}/
#   3. Remove entry from entries array using jq del filter
#   4. Write updated specs/zotero-index.json
#
# Exit codes:
#   0 - Entry removed successfully
#   1 - Key not found in index; file write error
#   2 - specs/zotero-index.json not found
#
# Dependencies: jq
# Implementation: task 751

set -euo pipefail

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

KEY="${1:-}"
DELETE_CHUNKS=false

if [[ -z "$KEY" ]]; then
  echo "zotero-index-remove.sh: zotero_key required" >&2
  echo "Usage: zotero-index-remove.sh <zotero_key> [--delete-chunks]" >&2
  exit 1
fi

shift
for arg in "$@"; do
  case "$arg" in
    --delete-chunks) DELETE_CHUNKS=true ;;
    *) echo "zotero-index-remove.sh: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Precondition checks
# ---------------------------------------------------------------------------

if [[ ! -f "$ZOTERO_INDEX" ]]; then
  echo "zotero-index-remove.sh: specs/zotero-index.json not found" >&2
  echo "Run /zotero --setup to initialize the per-repo index." >&2
  exit 2
fi

if ! command -v jq &>/dev/null; then
  echo "zotero-index-remove.sh: jq not installed" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Look up entry
# ---------------------------------------------------------------------------

entry="$(jq -c --arg k "$KEY" '.entries[] | select(.zotero_key == $k)' "$ZOTERO_INDEX" 2>/dev/null || echo "")"

if [[ -z "$entry" ]]; then
  echo "zotero-index-remove.sh: key $KEY not found in specs/zotero-index.json" >&2
  exit 1
fi

citation_key="$(echo "$entry" | jq -r '.citation_key // ""')"
title="$(echo "$entry" | jq -r '.title // ""')"
chunk_dir="$(echo "$entry" | jq -r '.chunk_dir // ""')"
has_chunks="$(echo "$entry" | jq -r '.has_chunks // false')"

# ---------------------------------------------------------------------------
# Optional: delete chunk directory
# ---------------------------------------------------------------------------

if [[ "$DELETE_CHUNKS" == "true" ]]; then
  if [[ "$has_chunks" == "true" && -n "$chunk_dir" && "$chunk_dir" != "null" ]]; then
    full_chunk_dir="$PROJECT_ROOT/$chunk_dir"
    if [[ -d "$full_chunk_dir" ]]; then
      rm -rf "$full_chunk_dir"
      echo "Deleted chunk directory: $chunk_dir" >&2
    else
      echo "Note: chunk directory not found on disk: $chunk_dir" >&2
    fi
  else
    echo "Note: item $KEY has no chunks to delete." >&2
  fi
fi

# ---------------------------------------------------------------------------
# Remove entry from index
# ---------------------------------------------------------------------------

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

updated_json="$(jq \
  --arg k "$KEY" \
  --arg ts "$now" \
  '.last_updated = $ts |
   .entries = [.entries[] | select(.zotero_key == $k | not)]' \
  "$ZOTERO_INDEX")"

echo "$updated_json" > "$ZOTERO_INDEX"

# ---------------------------------------------------------------------------
# Report result
# ---------------------------------------------------------------------------

echo "removed: $citation_key"
echo "  title: $title"
if [[ "$DELETE_CHUNKS" == "true" && "$has_chunks" == "true" ]]; then
  echo "  chunk directory deleted: $chunk_dir"
fi
