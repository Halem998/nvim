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
#   LITERATURE_DIR              Path to global Literature/ repo (default: ~/Projects/Literature)
#   LITERATURE_SPARSE_THRESHOLD Minimum resolved segment/document count before coverage is
#                                considered sparse (default: 3). Below this count (< threshold,
#                                never <=), both modes emit a machine-readable
#                                `<!-- lit-coverage ... sparse=true ... -->` marker line and a
#                                loud `[SPARSE COVERAGE ...]` banner, in the same family as the
#                                existing `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]`
#                                banners below -- never silent. See
#                                literature-lit-flag-resolve.sh for the companion
#                                SPARSE_PROMPT_NEEDED directive (sub-index-sparse checkpoint);
#                                this script's marker/banner is the post-global-search checkpoint.
#
# Machine-readable coverage marker (both modes, emitted right after the header line):
#   <!-- lit-coverage mode=repo|global seg_count=N sparse=true|false threshold=T -->
# A caller (e.g. the shared Stage 4a block) can `grep` this line without scraping the
# human-readable header to decide whether to offer a second, sparse-coverage prompt.

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
LITERATURE_SPARSE_THRESHOLD="${LITERATURE_SPARSE_THRESHOLD:-3}"

# --- Argument parsing ---
mode="repo"
query=""
top_n="$GLOBAL_TOP_N_DEFAULT"
# query_error is referenced at the shared exit point (task #833) regardless of mode; default
# it here so repo mode (which never sets it) doesn't trip `set -u` on an unbound variable.
query_error="null"

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

# Only unverified_summary/unverified_no_baseline/unadjudicated/absent get the loud
# marker -- no_source_pdf (nothing to compare against) and not_yet_converted (nothing
# converted yet, already self-evident from a 0-token entry) are not fidelity
# failures in the same sense and are left unmarked here. "unadjudicated" (task #839)
# is a fidelity failure (the proof-completeness signal could not fire on a low-ratio,
# undisclosed doc) and must be marked -- omitting it here would silently repeat the
# same fail-open bug #839 fixes, one script downstream.
needs_fidelity_marker() {
  case "$1" in
    unverified_summary | unverified_no_baseline | unadjudicated) return 0 ;;
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
  coverage_mode="repo"
  coverage_count="${#briefing_lines[@]}"

else
  # ============================================================
  # Global-corpus search mode (--global "<query>")
  # ============================================================
  repo_name="$(basename "$PROJECT_ROOT")"

  # Capture stderr instead of discarding it (task #833) so a real search-script
  # failure can be surfaced below rather than silently coerced to "no results".
  search_err_file="$(mktemp)"
  results_json=$(bash "$SEARCH_SCRIPT" --project "$repo_name" "$query" 2>"$search_err_file") || results_json="[]"
  search_stderr="$(cat "$search_err_file" 2>/dev/null || true)"
  rm -f "$search_err_file"

  # --- Shape-aware parsing (task #833) ---
  # Accepts both the legacy bare-array shape (pre-#833: degraded=false, fallback_tier=bm25,
  # query_error=null) and the new envelope object {results, degraded, fallback_tier,
  # query_error} literature-search.sh now emits. An unparseable payload remains a hard []
  # fallback, but now logs a visible notice -- this task exists to remove exactly the kind
  # of silent swallow the old unconditional coercion performed.
  degraded="false"
  fallback_tier="bm25"
  query_error="null"

  if echo "$results_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    : # legacy bare-array shape; results_json already holds the array, defaults above stand
  elif echo "$results_json" | jq -e 'type == "object" and has("results")' >/dev/null 2>&1; then
    degraded=$(echo "$results_json" | jq -r '.degraded // false')
    fallback_tier=$(echo "$results_json" | jq -r '.fallback_tier // "bm25"')
    query_error=$(echo "$results_json" | jq -r 'if .query_error == null then "null" else .query_error end')
    results_json=$(echo "$results_json" | jq -c '.results // []')
  else
    echo "Warning: literature-search.sh returned an unparseable payload for --global query '${query}'; treating as zero results. stderr: ${search_stderr:-<empty>}" >&2
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
  coverage_mode="global"
  coverage_count="$seg_count"

  # --- Degraded-tier banner (task #833) ---
  # When results exist but the primary bm25 tier did not answer, prefix the segment list
  # with a visible, tier-specific notice -- following the existing FIDELITY_MARKER_TEXT
  # "loud, never silent" precedent (#835) rather than inventing a new convention. Inserted
  # AFTER the header's segment count is computed so the banner itself is never counted as
  # a segment.
  if [ "$degraded" = "true" ] && [ "${#briefing_lines[@]}" -gt 0 ]; then
    case "$fallback_tier" in
      trigram)
        degraded_banner="[DEGRADED RETRIEVAL - fallback_tier: trigram] The primary full-text ranking found nothing for this query; these results come from a SUBSTRING (trigram) fallback match, not full-text ranking -- lower precision, verify relevance yourself."
        ;;
      phrase_retry)
        degraded_banner="[DEGRADED RETRIEVAL - fallback_tier: phrase_retry] The original query triggered an FTS5 syntax error; these results come from a whole-query phrase retry, not the primary ranked search -- verify relevance yourself."
        ;;
      *)
        degraded_banner="[DEGRADED RETRIEVAL - fallback_tier: ${fallback_tier}] The primary full-text ranking did not answer this query -- verify relevance yourself."
        ;;
    esac
    briefing_lines=("$degraded_banner" "${briefing_lines[@]}")
  fi
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

# --- Machine-readable coverage marker + loud sparse banner (never silent) ---
# coverage_mode/coverage_count are set in each mode's branch above (repo: resolved document
# count; global: seg_count, the pre-top_n-slice total match count). sparse = count < threshold
# (never <=; the boundary is exercised by the Testing & Validation fixtures).
sparse="false"
if [ "$coverage_count" -lt "$LITERATURE_SPARSE_THRESHOLD" ]; then
  sparse="true"
fi
echo "<!-- lit-coverage mode=${coverage_mode} seg_count=${coverage_count} sparse=${sparse} threshold=${LITERATURE_SPARSE_THRESHOLD} -->"
echo ""

if [ "$sparse" = "true" ]; then
  echo "[SPARSE COVERAGE - ${coverage_count} segment(s), threshold ${LITERATURE_SPARSE_THRESHOLD}] This briefing resolved fewer relevant segments than the configured sparsity threshold; consider searching online for additional sources (see the Stage 4a \"Search online to ingest\" option) or broadening the query."
  echo ""
fi

if [ "${#briefing_lines[@]}" -eq 0 ]; then
  # Honest zero-result messaging (task #833): a genuine zero-result (query_error null,
  # per-repo mode always, or global mode with a syntactically valid query that matched
  # nothing) keeps the original wording unchanged. A global-mode query that triggered an
  # FTS5 syntax error (query_error non-null) gets a distinguishable message naming the
  # failure and a concrete next action, instead of the same bare line -- this is the
  # actual "usable next action" gap this task exists to close (per-repo mode never sets
  # query_error, so its behavior here is untouched).
  if [ "$mode" = "global" ] && [ "$query_error" != "null" ] && [ -n "$query_error" ]; then
    echo "No matching literature segments found for \"${query}\" query."
    echo ""
    echo "Note: the original query triggered an FTS5 syntax error (${query_error}); a"
    echo "punctuation-tolerant phrase retry and a trigram substring fallback both ran and"
    echo "also found nothing. Try a shorter, plainer-language query, or browse the table of"
    echo "contents: \`bash .claude/scripts/literature-search.sh --toc <doc_id>\`"
    echo ""
  else
    echo "No matching literature segments found for this query."
    echo ""
  fi
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
