#!/usr/bin/env bash
# literature-briefing.sh - Generate a <literature-briefing> block from the per-repo sub-index
#
# Usage: literature-briefing.sh
#
# Reads specs/literature-index.json (per-repo sub-index) and resolves metadata from
# $LITERATURE_DIR/index.json to produce a compact briefing for agents.
#
# Exit 0 (empty stdout) when:
#   - specs/literature-index.json missing
#   - entries array is empty
#   - LITERATURE_DIR/index.json missing
#
# Exit 0 (briefing on stdout) when entries are found and resolved.
# Warnings about missing doc_ids go to stderr; they do not stop execution.
#
# NOTE: Interactive detection of a missing specs/literature-index.json (and the
# AskUserQuestion prompt offering setup options) is handled UPSTREAM in the Stage 4a
# block of each skill SKILL.md that supports --lit. This script retains its existing
# silent-exit behavior when the sub-index is missing; the upstream skills are
# responsible for offering the interactive setup flow before calling this script.
# See .claude/skills/skill-researcher/SKILL.md Stage 4a for the detection block.
#
# Environment:
#   LITERATURE_DIR  Path to global Literature/ repo (default: ~/Projects/Literature)

set -euo pipefail

# --- Resolve LITERATURE_DIR ---
LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SUB_INDEX="$PROJECT_ROOT/specs/literature-index.json"
GLOBAL_INDEX="$LIT_DIR/index.json"

# --- Bail early if sub-index missing or unreadable ---
if [ ! -f "$SUB_INDEX" ]; then
  exit 0
fi

# --- Bail early if global index missing ---
if [ ! -f "$GLOBAL_INDEX" ]; then
  echo "Warning: Global index not found at $GLOBAL_INDEX" >&2
  exit 0
fi

# --- Read entry count from sub-index ---
entry_count=$(jq '.entries | length' "$SUB_INDEX" 2>/dev/null || echo 0)
if [ "$entry_count" -eq 0 ]; then
  exit 0
fi

# --- Read doc_ids from sub-index ---
mapfile -t doc_ids < <(jq -r '.entries[].doc_id' "$SUB_INDEX" 2>/dev/null)
if [ "${#doc_ids[@]}" -eq 0 ]; then
  exit 0
fi

# --- Build briefing entries ---
briefing_lines=()
doc_num=0

for doc_id in "${doc_ids[@]}"; do
  # Find the parent entry (parent_doc == null and id starts with doc_id)
  parent_entry=$(jq -r --arg id "$doc_id" '
    .entries[]
    | select(.id == $id and (.parent_doc == null or .parent_doc == ""))
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

  if [ -z "$parent_entry" ]; then
    # Try without parent_doc filter (older entries may lack the field)
    parent_entry=$(jq -r --arg id "$doc_id" '
      .entries[] | select(.id == $id)
    ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
  fi

  if [ -z "$parent_entry" ]; then
    echo "Warning: doc_id '$doc_id' not found in global index — skipping" >&2
    continue
  fi

  # Extract parent metadata
  title=$(jq -r --arg id "$doc_id" '
    .entries[] | select(.id == $id) | .title // "Unknown Title"
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

  authors_raw=$(jq -r --arg id "$doc_id" '
    .entries[] | select(.id == $id) | (.authors // []) | join(", ")
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

  year=$(jq -r --arg id "$doc_id" '
    .entries[] | select(.id == $id) | (.year // "?") | tostring
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

  # Find all chunk entries (children: parent_doc == doc_id)
  chunk_count=$(jq --arg id "$doc_id" '
    [.entries[] | select(.parent_doc == $id)] | length
  ' "$GLOBAL_INDEX" 2>/dev/null || echo 0)

  # Sum tokens across all chunks (children); fall back to parent token_count if no chunks
  if [ "$chunk_count" -gt 0 ]; then
    total_tokens=$(jq --arg id "$doc_id" '
      [.entries[] | select(.parent_doc == $id) | .token_count // 0] | add // 0
    ' "$GLOBAL_INDEX" 2>/dev/null || echo 0)
    # Also include parent entry tokens if present
    parent_tokens=$(jq -r --arg id "$doc_id" '
      .entries[] | select(.id == $id) | .token_count // 0
    ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
    total_tokens=$(( total_tokens + parent_tokens ))
  else
    total_tokens=$(jq -r --arg id "$doc_id" '
      .entries[] | select(.id == $id) | .token_count // 0
    ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
    chunk_count=1
  fi

  # Resolve directory path (use parent entry's path directory)
  parent_path=$(jq -r --arg id "$doc_id" '
    .entries[] | select(.id == $id) | .path // ""
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

  if [ -n "$parent_path" ]; then
    # If path ends with /, it is already a directory path
    if [[ "$parent_path" == */ ]]; then
      doc_dir="$LIT_DIR/${parent_path%/}"
    else
      parent_dir="$(dirname "$parent_path")"
      if [ "$parent_dir" = "." ]; then
        doc_dir="$LIT_DIR/sources/$doc_id"
      else
        doc_dir="$LIT_DIR/$parent_dir"
      fi
    fi
  else
    doc_dir="$LIT_DIR/sources/$doc_id"
  fi

  # Get relevance note from sub-index if present
  relevance=$(jq -r --arg id "$doc_id" '
    .entries[] | select(.doc_id == $id) | .relevance // ""
  ' "$SUB_INDEX" 2>/dev/null | head -1)

  doc_num=$(( doc_num + 1 ))

  # Format authors (truncate if long)
  if [ ${#authors_raw} -gt 60 ]; then
    authors_display="${authors_raw:0:57}..."
  else
    authors_display="$authors_raw"
  fi

  # Build entry line
  entry="${doc_num}. **${title}** (${year})"
  if [ -n "$authors_display" ] && [ "$authors_display" != "," ]; then
    entry="${entry} — ${authors_display}"
  fi
  entry="${entry}
   ${chunk_count} chunk(s), ~${total_tokens} tokens | dir: ${doc_dir}"
  if [ -n "$relevance" ]; then
    entry="${entry}
   Relevance: ${relevance}"
  fi

  briefing_lines+=("$entry")
done

# --- If no entries resolved, exit silently ---
if [ "${#briefing_lines[@]}" -eq 0 ]; then
  exit 0
fi

# --- Output briefing block ---
cat <<'HEADER'
<literature-briefing>
HEADER

echo "## Available Literature (${#briefing_lines[@]} document(s))"
echo ""

for line in "${briefing_lines[@]}"; do
  echo "$line"
  echo ""
done

cat <<'FOOTER'
## How to Use

- **Read a chunk**: Use the Read tool with the absolute path to a chunk file under the
  document's directory listed above (e.g., Read(file_path="<dir>/ch01_intro.md"))
- **Search the corpus**: Run `bash .claude/scripts/literature-search.sh "<query>"`
  to search via FTS5 full-text index; returns JSON with ranked results and chunk paths
- **Browse TOC**: Pass `--toc` flag to literature-search.sh for a table-of-contents view
  of a specific document: `bash .claude/scripts/literature-search.sh --toc <doc_id>`
- **Read selectively**: Start with the most relevant chunks; do not read all chunks unless
  the task requires comprehensive coverage
</literature-briefing>
FOOTER
