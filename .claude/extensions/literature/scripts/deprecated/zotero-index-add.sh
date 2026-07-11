#!/usr/bin/env bash
# zotero-index-add.sh - Add a Zotero item to the per-repo index
#
# Category C: Index Management (implemented in task 751)
#
# Usage:
#   zotero-index-add.sh <zotero_key> [--chunk]
#
# Arguments:
#   <zotero_key>  - 8-char Zotero item key (required)
#   --chunk       - After adding to index, automatically run zotero-chunk.sh if item has PDF
#
# Pipeline steps:
#   1. zotero-read.sh item KEY -> full item metadata JSON
#   2. Extract: title, authors, year, item_type, abstract (300 chars), keywords, tags, collections
#   3. Resolve PDF path from data.attachments
#   4. Extract relevance_keywords (stop-word filtered, length > 3)
#   5. Optionally fetch notes_summary (first 200 chars of first note)
#   6. Build 20-field entry JSON
#   7. Update or append to specs/zotero-index.json
#   8. If --chunk and has_pdf: zotero-chunk.sh KEY
#
# Exit codes:
#   0 - Item added or updated successfully
#   1 - Metadata fetch failed; JSON parse error; index write error
#   2 - zot not installed; specs/zotero-index.json not found (run /zotero --setup first)
#
# Dependencies: zotero-read.sh, jq
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
CHUNK_FLAG=false

if [[ -z "$KEY" ]]; then
  echo "zotero-index-add.sh: zotero_key required" >&2
  echo "Usage: zotero-index-add.sh <zotero_key> [--chunk]" >&2
  exit 1
fi

shift
for arg in "$@"; do
  case "$arg" in
    --chunk) CHUNK_FLAG=true ;;
    *) echo "zotero-index-add.sh: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Precondition checks
# ---------------------------------------------------------------------------

if [[ ! -f "$ZOTERO_INDEX" ]]; then
  echo "zotero-index-add.sh: specs/zotero-index.json not found" >&2
  echo "Run /zotero --setup to initialize the per-repo index." >&2
  exit 2
fi

if ! command -v jq &>/dev/null; then
  echo "zotero-index-add.sh: jq not installed" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Fetch item metadata
# ---------------------------------------------------------------------------

echo "Fetching metadata for $KEY..." >&2
if ! item_json="$(bash "$SCRIPT_DIR/zotero-read.sh" item "$KEY" 2>/dev/null)"; then
  echo "zotero-index-add.sh: failed to fetch metadata for key $KEY" >&2
  echo "Check that the key exists in the Zotero library." >&2
  exit 1
fi

if [[ -z "$item_json" ]]; then
  echo "zotero-index-add.sh: empty metadata response for key $KEY" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Extract core fields
# ---------------------------------------------------------------------------

# Title
title="$(echo "$item_json" | jq -r '.title // ""')"

# Year: scan for 4-digit year in .date field
year_raw="$(echo "$item_json" | jq -r '
  .date // "" |
  if . == "" then "null"
  elif test("[0-9]{4}")
    then match("[0-9]{4}").string
  else "null"
  end
' 2>/dev/null || echo "null")"

if [[ "$year_raw" == "null" ]]; then
  year_json="null"
else
  year_json="$year_raw"
fi

# Item type
item_type="$(echo "$item_json" | jq -r '.itemType // "unknown"')"

# Abstract snippet (first 300 chars)
abstract_snippet="$(echo "$item_json" | jq -r '
  .abstractNote // "" |
  if (. | length) <= 300 then .
  else .[0:300]
  end
')"

# Citation key: try .citationKey, then .citekey
citation_key="$(echo "$item_json" | jq -r '.citationKey // .citekey // ""')"
if [[ -z "$citation_key" || "$citation_key" == "null" ]]; then
  # Construct a basic citation key: first author last name + year
  first_author="$(echo "$item_json" | jq -r '
    [.creators[]? | select(.creatorType == "author") | .lastName // ""] | first // "unknown"
  ' | tr '[:upper:]' '[:lower:]' | tr -cd '[:alpha:]')"
  if [[ -z "$first_author" ]]; then
    first_author="unknown"
  fi
  yr="${year_raw:-0000}"
  [[ "$yr" == "null" ]] && yr="0000"
  citation_key="${first_author}${yr}"
fi

# Authors: iterate .creators where creatorType == "author", format as "Last, First"
authors_json="$(echo "$item_json" | jq '
  [.creators[]? |
   select(.creatorType == "author") |
   ((.lastName // "") + (if (.firstName // "") != "" then ", " + .firstName else "" end))
  ]
')"

# Tags: extract from .tags[].tag
tags_json="$(echo "$item_json" | jq '[.tags[]?.tag // empty]')"

# Keywords: same as tags for Zotero native format
keywords_json="$tags_json"

# Collections: collection keys from .collections array
collections_json="$(echo "$item_json" | jq '[.collections[]? // empty]')"

# ---------------------------------------------------------------------------
# PDF path resolution
# ---------------------------------------------------------------------------

pdf_path="$(echo "$item_json" | jq -r '
  [.attachments[]? |
   select((.contentType // .mimeType // "") | test("pdf"; "i")) |
   .path // ""
  ] | first // ""
' 2>/dev/null || echo "")"

if [[ -n "$pdf_path" && "$pdf_path" != "null" && -f "$pdf_path" ]]; then
  has_pdf="true"
  pdf_path_json="\"$pdf_path\""
else
  has_pdf="false"
  pdf_path_json="null"
fi

# ---------------------------------------------------------------------------
# Relevance keyword extraction
# ---------------------------------------------------------------------------

STOP_WORDS="a an the in on at of to for is are was were be been being have has had do does did will would shall should may might can could and or but not with from by as if that this these those it its"

extract_relevance_keywords() {
  local text="$1"
  echo "$text" | tr '[:upper:]' '[:lower:]' | tr -s '[:punct:][:space:]' '\n' | \
  while IFS= read -r token; do
    [[ "${#token}" -le 3 ]] && continue
    [[ "$token" =~ ^[a-z]+$ ]] || continue
    local is_stop=false
    for stop in $STOP_WORDS; do
      if [[ "$token" == "$stop" ]]; then
        is_stop=true
        break
      fi
    done
    [[ "$is_stop" == "true" ]] && continue
    echo "$token"
  done | sort -u
}

tags_text="$(echo "$tags_json" | jq -r '.[]' 2>/dev/null | tr '\n' ' ')"
relevance_raw="$(extract_relevance_keywords "$title $tags_text")"
relevance_keywords_json="$(echo "$relevance_raw" | jq -R . | jq -s '.')"

# ---------------------------------------------------------------------------
# Notes summary (optional)
# ---------------------------------------------------------------------------

notes_summary_json="null"
if notes_json="$(bash "$SCRIPT_DIR/zotero-read.sh" note "$KEY" 2>/dev/null)"; then
  if [[ -n "$notes_json" ]]; then
    notes_text="$(echo "$notes_json" | jq -r '
      if type == "array" then
        (.[0].note // .[0] // "") |
        if type == "string" then . else "" end
      elif type == "string" then .
      else ""
      end
    ' 2>/dev/null || echo "")"
    if [[ -n "$notes_text" ]]; then
      notes_summary_json="$(echo "${notes_text:0:200}" | jq -R '.')"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Preserve chunk fields from existing entry (if updating)
# ---------------------------------------------------------------------------

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

existing_entry="$(jq -r --arg k "$KEY" \
  '.entries[] | select(.zotero_key == $k)' \
  "$ZOTERO_INDEX" 2>/dev/null || echo "")"

if [[ -n "$existing_entry" ]]; then
  existing_added_at="$(echo "$existing_entry" | jq -r '.added_at // ""')"
  existing_last_retrieved="$(echo "$existing_entry" | jq -r '.last_retrieved')"
  existing_has_chunks="$(echo "$existing_entry" | jq -r '.has_chunks // false')"
  existing_chunk_dir="$(echo "$existing_entry" | jq -c '.chunk_dir')"
  existing_chunk_count="$(echo "$existing_entry" | jq -r '.chunk_count // 0')"
  existing_token_count="$(echo "$existing_entry" | jq -r '.token_count // 0')"
else
  existing_added_at=""
  existing_last_retrieved="null"
  existing_has_chunks="false"
  existing_chunk_dir="null"
  existing_chunk_count="0"
  existing_token_count="0"
fi

added_at="${existing_added_at:-$now}"

# ---------------------------------------------------------------------------
# Build 20-field entry JSON
# ---------------------------------------------------------------------------

new_entry="$(jq -n \
  --arg zotero_key "$KEY" \
  --arg citation_key "$citation_key" \
  --arg title "$title" \
  --argjson authors "$authors_json" \
  --argjson year "$year_json" \
  --arg item_type "$item_type" \
  --arg abstract_snippet "$abstract_snippet" \
  --argjson keywords "$keywords_json" \
  --argjson tags "$tags_json" \
  --argjson collections "$collections_json" \
  --argjson has_pdf "$has_pdf" \
  --argjson pdf_path "$pdf_path_json" \
  --argjson has_chunks "$existing_has_chunks" \
  --argjson chunk_dir "$existing_chunk_dir" \
  --argjson chunk_count "$existing_chunk_count" \
  --argjson token_count "$existing_token_count" \
  --argjson relevance_keywords "$relevance_keywords_json" \
  --argjson notes_summary "$notes_summary_json" \
  --arg added_at "$added_at" \
  --argjson last_retrieved "$existing_last_retrieved" \
  '{
    zotero_key: $zotero_key,
    citation_key: $citation_key,
    title: $title,
    authors: $authors,
    year: $year,
    item_type: $item_type,
    abstract_snippet: (if $abstract_snippet == "" then null else $abstract_snippet end),
    keywords: $keywords,
    tags: $tags,
    collections: $collections,
    has_pdf: $has_pdf,
    pdf_path: $pdf_path,
    has_chunks: $has_chunks,
    chunk_dir: $chunk_dir,
    chunk_count: $chunk_count,
    token_count: $token_count,
    relevance_keywords: $relevance_keywords,
    notes_summary: $notes_summary,
    added_at: $added_at,
    last_retrieved: $last_retrieved
  }')"

# ---------------------------------------------------------------------------
# Upsert: update existing entry or append new one
# ---------------------------------------------------------------------------

exists_count="$(jq --arg k "$KEY" '[.entries[] | select(.zotero_key == $k)] | length' "$ZOTERO_INDEX")"

if [[ "$exists_count" -gt 0 ]]; then
  updated_json="$(jq \
    --arg k "$KEY" \
    --argjson entry "$new_entry" \
    --arg ts "$now" \
    '.last_updated = $ts |
     .entries = [.entries[] | if .zotero_key == $k then $entry else . end]' \
    "$ZOTERO_INDEX")"
  action="updated"
else
  updated_json="$(jq \
    --argjson entry "$new_entry" \
    --arg ts "$now" \
    '.last_updated = $ts | .entries += [$entry]' \
    "$ZOTERO_INDEX")"
  action="added"
fi

echo "$updated_json" > "$ZOTERO_INDEX"

# ---------------------------------------------------------------------------
# Report result
# ---------------------------------------------------------------------------

echo "$action: $citation_key"
echo "  title: $title"
echo "  year: $year_json  type: $item_type  has_pdf: $has_pdf"

# ---------------------------------------------------------------------------
# Optional: chunk PDF
# ---------------------------------------------------------------------------

if [[ "$CHUNK_FLAG" == "true" ]]; then
  if [[ "$has_pdf" == "true" ]]; then
    chunk_script="$SCRIPT_DIR/zotero-chunk.sh"
    if [[ -f "$chunk_script" ]]; then
      echo "Running zotero-chunk.sh for $KEY..." >&2
      bash "$chunk_script" "$KEY" || {
        exit_code=$?
        if [[ "$exit_code" -eq 2 ]]; then
          echo "Note: zotero-chunk.sh not yet implemented (task 752); skipping chunk step." >&2
        else
          echo "Warning: zotero-chunk.sh failed (exit $exit_code); index entry was still saved." >&2
        fi
      }
    else
      echo "Note: zotero-chunk.sh not found; skipping chunk step." >&2
    fi
  else
    echo "Note: Item $KEY has no PDF; --chunk flag ignored." >&2
  fi
fi
