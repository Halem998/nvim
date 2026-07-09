#!/usr/bin/env bash
# literature-briefing.sh - Generate a <literature-briefing> block for agents
#
# Usage:
#   literature-briefing.sh                              # per-repo sub-index mode
#   literature-briefing.sh --global "<query>" [--top-n N]  # global-corpus search mode
#
# Per-repo mode (no args):
#   Reads specs/literature-index.json (per-repo sub-index) and resolves metadata from
#   $LITERATURE_DIR/index.json to produce a compact briefing for agents.
#
#   Exit 0 (empty stdout) when:
#     - specs/literature-index.json missing
#     - entries array is empty
#     - LITERATURE_DIR/index.json missing
#
# Global mode (--global "<query>"):
#   Runs a live relevance search against the global Literature corpus via
#   literature-search.sh (project-scoped first; the search script itself retries
#   unfiltered if the project-scoped search yields zero results) and builds a
#   briefing from the top-N (default 8, override with --top-n) ranked chunks.
#   Always emits a footer-terminated <literature-briefing> block, even when zero
#   segments match (the block then states no segments were found). This mode is
#   never silent -- the caller (Stage 4a directive resolution) decides whether to
#   invoke it at all.
#
# Both modes share a single output section that always appends the "How to Use"
# footer before closing </literature-briefing>.
#
# NOTE: Interactive detection of a missing specs/literature-index.json (and the
# AskUserQuestion prompt offering setup options) is handled UPSTREAM in the Stage 4a
# block of each skill SKILL.md that supports --lit, via literature-lit-flag-resolve.sh.
# This script retains its existing silent-exit behavior in per-repo mode when the
# sub-index is missing; the upstream skills are responsible for offering the
# interactive setup flow (or the global-mode fallback) before calling this script.
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
SEARCH_SCRIPT="$SCRIPT_DIR/literature-search.sh"
GLOBAL_TOP_N_DEFAULT=8

# --- Argument parsing ---
mode="repo"
query=""
top_n="$GLOBAL_TOP_N_DEFAULT"

while [ $# -gt 0 ]; do
  case "$1" in
    --global)
      mode="global"
      query="${2:-}"
      if [ -z "$query" ]; then
        echo "Error: --global requires a query argument" >&2
        exit 1
      fi
      shift 2
      ;;
    --top-n)
      if [ -z "${2:-}" ]; then
        echo "Error: --top-n requires a numeric argument" >&2
        exit 1
      fi
      top_n="$2"
      shift 2
      ;;
    *)
      echo "Warning: unrecognized argument '$1' ignored" >&2
      shift
      ;;
  esac
done

# --- provenance_fidelity lookup (task #835) ---
# doc_id -> provenance_fidelity, mirroring the existing per-repo relevance/title/
# authors/year lookups below (all keyed by index.json's .id field -- specs/
# literature-index.json's doc_id values are curated in that same .id namespace, e.g.
# "rabinovich_2014", "blackburn_2002_book"). Fail-open: an absent field or entry
# resolves to "unverified_summary".
get_doc_fidelity() {
  local doc_id="$1"
  local val
  val=$(jq -r --arg id "$doc_id" '
    .entries[] | select(.id == $id) | .provenance_fidelity // empty
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
  echo "${val:-unverified_summary}"
}

# Only unverified_summary/unverified_no_baseline/absent get the loud marker --
# no_source_pdf (nothing to compare against) and not_yet_converted (nothing
# converted yet, already self-evident from a 0-token entry) are not fidelity
# failures in the same sense and are left unmarked here.
needs_fidelity_marker() {
  case "$1" in
    unverified_summary | unverified_no_baseline) return 0 ;;
    *) return 1 ;;
  esac
}

FIDELITY_MARKER_TEXT() {
  echo "[UNVERIFIED - provenance_fidelity: $1 - not confirmed faithful to its source PDF; verify before citing]"
}

briefing_lines=()
header=""

if [ "$mode" = "repo" ]; then
  # ============================================================
  # Per-repo sub-index mode (unchanged behavior)
  # ============================================================

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
      .entries[] | select(.id == $id) | (.authors // [] | if type == "array" then . else [.] end | join(", "))
    ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || authors_raw=""

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
      ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || parent_tokens=0
      [[ "$parent_tokens" =~ ^[0-9]+$ ]] || { echo "Warning: non-numeric parent token_count for '$doc_id', defaulting to 0" >&2; parent_tokens=0; }
      total_tokens=$(( total_tokens + parent_tokens ))
    else
      total_tokens=$(jq -r --arg id "$doc_id" '
        .entries[] | select(.id == $id) | .token_count // 0
      ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || { echo "Warning: could not read token_count for '$doc_id', defaulting to 0" >&2; total_tokens=0; }
      [[ "$total_tokens" =~ ^[0-9]+$ ]] || total_tokens=0
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

    # provenance_fidelity lookup (task #835) -- fail-open, see get_doc_fidelity above
    fidelity=$(get_doc_fidelity "$doc_id")

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

    if needs_fidelity_marker "$fidelity"; then
      entry="$(FIDELITY_MARKER_TEXT "$fidelity")
${entry}"
    fi

    briefing_lines+=("$entry")
  done

  # --- If no entries resolved, exit silently (regression-preserved) ---
  if [ "${#briefing_lines[@]}" -eq 0 ]; then
    exit 0
  fi

  header="## Available Literature (${#briefing_lines[@]} document(s))"

else
  # ============================================================
  # Global-corpus search mode (--global "<query>")
  # ============================================================
  repo_name="$(basename "$PROJECT_ROOT")"

  results_json=$(bash "$SEARCH_SCRIPT" --project "$repo_name" "$query" 2>/dev/null) || results_json="[]"

  # Guard against error objects or malformed output from the search script
  if ! echo "$results_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    results_json="[]"
  fi

  seg_count=$(echo "$results_json" | jq 'length' 2>/dev/null || echo 0)

  if [ "$seg_count" -gt "$top_n" ]; then
    results_json=$(echo "$results_json" | jq --argjson n "$top_n" '.[0:$n]')
  fi

  if [ "$seg_count" -gt 0 ]; then
    doc_num=0
    while IFS= read -r seg; do
      chunk_id=$(echo "$seg" | jq -r '.chunk_id // "unknown"')
      doc_id=$(echo "$seg" | jq -r '.doc_id // "unknown"')
      section_path=$(echo "$seg" | jq -r '.section_path // "?"')
      title=$(echo "$seg" | jq -r '.title // "Untitled"')
      summary=$(echo "$seg" | jq -r '.summary // ""')
      token_count=$(echo "$seg" | jq -r '.token_count // 0')
      # provenance_fidelity is already present on every do_search result object
      # (task #835, literature-search.sh) -- no separate lookup needed here.
      fidelity=$(echo "$seg" | jq -r '.provenance_fidelity // "unverified_summary"')

      doc_num=$(( doc_num + 1 ))

      entry="${doc_num}. **${title}** — ${section_path}"
      entry="${entry}
   doc: ${doc_id} | ~${token_count} tokens"
      if [ -n "$summary" ] && [ "$summary" != "null" ]; then
        entry="${entry}
   ${summary}"
      fi
      entry="${entry}
   Read: \`bash .claude/scripts/literature-search.sh --read ${chunk_id}\`"

      if needs_fidelity_marker "$fidelity"; then
        entry="$(FIDELITY_MARKER_TEXT "$fidelity")
${entry}"
      fi

      briefing_lines+=("$entry")
    done < <(echo "$results_json" | jq -c '.[]')
  fi

  header="## Available Literature — Global Corpus Search Results for: \"${query}\" (${#briefing_lines[@]} segment(s))"
fi

# ============================================================
# Single shared exit point: both modes emit the <literature-briefing>
# block through this one section, always terminated by the "How to Use"
# footer.
# ============================================================
cat <<'HEADER'
<literature-briefing>
HEADER

echo "$header"
echo ""

if [ "${#briefing_lines[@]}" -eq 0 ]; then
  echo "No matching literature segments found for this query."
  echo ""
fi

for line in "${briefing_lines[@]}"; do
  echo "$line"
  echo ""
done

cat <<'FOOTER'
## How to Use

- **Read a chunk**: Use the Read tool with the absolute path to a chunk file under the
  document's directory listed above (e.g., Read(file_path="<dir>/ch01_intro.md")), or run
  `bash .claude/scripts/literature-search.sh --read <chunk_id>` for global-search results
- **Search the corpus**: Run `bash .claude/scripts/literature-search.sh "<query>"`
  to search via FTS5 full-text index; returns JSON with ranked results and chunk paths
- **Browse TOC**: Pass `--toc` flag to literature-search.sh for a table-of-contents view
  of a specific document: `bash .claude/scripts/literature-search.sh --toc <doc_id>`
- **Read selectively**: Start with the most relevant chunks; do not read all chunks unless
  the task requires comprehensive coverage
- **UNVERIFIED entries**: Entries marked `[UNVERIFIED - provenance_fidelity: ...]` above are
  not confirmed faithful to their source PDF (hand-authored summary, or no PDF available to
  verify against); treat any claims, lemmas, or definitions from them as provisional and
  verify against the primary source PDF before citing in formal work
</literature-briefing>
FOOTER
