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
# See .claude/context/patterns/lit-stage4a-flow.md for the shared detection block.
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
#   <!-- lit-coverage mode=repo|global seg_count=N sparse=true|false threshold=T
#        requested=R resolved=N skipped=S skip_rate=P -->
# A caller (e.g. the shared Stage 4a block) can `grep` this line without scraping the
# human-readable header to decide whether to offer a second, sparse-coverage prompt.
# requested=/resolved=/skipped=/skip_rate= are appended strictly after the original four
# fields, which stay byte-for-byte adjacent and in their original order for backward
# compatibility with existing `.*`-tolerant greps. sparse=true fires on EITHER the
# original absolute-count rule OR skip_rate >= LITERATURE_SKIP_RATE_THRESHOLD (repo mode
# only; skipped=0/skip_rate=0 always in global mode). See
# context/project/literature/domain/sparse-coverage.md for the full policy.

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
# Minimum resolved-document/segment count before coverage is sparse (absolute-count rule,
# unchanged). LITERATURE_SKIP_RATE_THRESHOLD is a second, independent rule that also sets
# sparse=true: a resolution-failure rate (skip_count / requested_count, as an integer
# percentage) at or above this threshold (>=, unlike the absolute-count rule's strict <)
# makes the briefing untrustworthy even when enough documents nominally resolved. See
# context/project/literature/domain/sparse-coverage.md for the full policy rationale.
LITERATURE_SKIP_RATE_THRESHOLD="${LITERATURE_SKIP_RATE_THRESHOLD:-50}"
# Minimum topic-matched missing-candidate count (delta_candidates, from
# literature-coverage-delta.sh) before the [COVERAGE DELTA ...] banner fires below. Not forwarded
# to the delta script -- the threshold comparison happens here, mirroring
# literature-lit-flag-resolve.sh's identical pattern.
export LITERATURE_COVERAGE_GAP_MIN="${LITERATURE_COVERAGE_GAP_MIN:-25}"
LITERATURE_COVERAGE_DELTA_THRESHOLD="${LITERATURE_COVERAGE_DELTA_THRESHOLD:-1}"
# Global-mode search fan-out bound: --global forwards the filtered-term set (see
# literature-term-match.sh's filter_terms()) as one literature-search.sh --multi call
# rather than the raw query as a single AND-all-terms search (FTS5's bareword MATCH ANDs
# every term together, a condition no real document satisfies once a query reaches
# 15-30+ words). This caps how many per-term MATCH executions that one call performs --
# the fan-out happens inside literature-search.sh's single already-open connection, so
# this bound controls query cost, not process count. Longest-first truncation (see the
# global-mode branch below) keeps the most discriminating terms when the cap is hit.
LITERATURE_GLOBAL_MAX_TERMS="${LITERATURE_GLOBAL_MAX_TERMS:-12}"

# --- Argument parsing ---
mode="repo"
query=""
top_n="$GLOBAL_TOP_N_DEFAULT"
# query_error is referenced at the shared exit point regardless of mode; default
# it here so repo mode (which never sets it) doesn't trip `set -u` on an unbound variable.
query_error="null"
# skip_count/requested_count/skipped_doc_ids are referenced at the shared exit point
# regardless of mode; default them here (same rationale as query_error above) so
# global mode -- which never populates skipped_doc_ids and only sets requested_count
# later -- doesn't trip `set -u` on an unbound variable.
skip_count=0
requested_count=0
skipped_doc_ids=()
# --query (repo mode only) -- the task description text the topic-scoped coverage-delta guard
# matches against. delta_* defaults below are the D6 "not computed" shape: they stay at these
# values (delta_checked=false) whenever --query is absent (repo mode) or in --global mode (the
# guard is a repo-mode/sub-index-present concern by definition -- see the plan's Non-Goals), so
# a caller can never misread an uncomputed delta as a verified zero.
repo_query=""
delta_checked="false"
delta_gap=0
delta_candidates=0
delta_candidate_ids=""
delta_candidate_titles_json="[]"

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
    --query)
      repo_query="${2:-}"
      shift 2
      ;;
    *)
      echo "Warning: unrecognized argument '$1' ignored" >&2
      shift
      ;;
  esac
done

if [ "$mode" = "global" ] && [ -n "$repo_query" ]; then
  echo "Warning: --query is ignored in --global mode (global mode already has its own query argument)." >&2
  repo_query=""
fi

# --- provenance_fidelity lookup ---
# doc_id -> provenance_fidelity, mirroring the existing per-repo relevance/title/
# authors/year lookups below. The real contract: lookups here prefer index.json's
# curated `.id` field but tolerate a stub-shaped entry keyed only by `.doc_id`
# (`.id // .doc_id`), mirroring the pattern literature-discover.sh's Tier 1 lookup
# already uses (`.id // .doc_id // ""`). `.id` and `.doc_id` are NOT the same
# namespace as the FTS `chunks_data.doc_id` key: the FTS key is always derived from
# an entry's `sources/`-prefixed `.path` (see literature-doc-key.sh), never from `.id`
# or `.doc_id` directly -- this script never touches that derivation. Fail-open: an
# absent field or entry resolves to "unverified_summary".
get_doc_fidelity() {
  local doc_id="$1"
  local val
  val=$(jq -r --arg id "$doc_id" '
    .entries[] | select((.id // .doc_id) == $id) | .provenance_fidelity // empty
  ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
  echo "${val:-unverified_summary}"
}

# Only unverified_summary/unverified_no_baseline/unadjudicated/unverified_scan_source/absent
# get the loud marker -- no_source_pdf (nothing to compare against) and not_yet_converted
# (nothing converted yet, already self-evident from a 0-token entry) are not fidelity
# failures in the same sense and are left unmarked here. "unadjudicated"
# is a fidelity failure (the proof-completeness signal could not fire on a low-ratio,
# undisclosed doc) and must be marked -- omitting it here would silently repeat the
# same fail-open bug a prior fix closed, one script downstream. "unverified_scan_source"
# is a fidelity failure too (a scan/OCR-pipeline PDF whose word ratio is self-referential
# by construction and cannot certify) and must be marked for the same reason.
needs_fidelity_marker() {
  case "$1" in
    unverified_summary | unverified_no_baseline | unadjudicated | unverified_scan_source) return 0 ;;
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
  requested_count="${#doc_ids[@]}"
  if [ "${#doc_ids[@]}" -eq 0 ]; then
    exit 0
  fi

  # --- Build briefing entries ---
  doc_num=0

  for doc_id in "${doc_ids[@]}"; do
    # Find the parent entry (parent_doc == null and (id // doc_id) matches doc_id).
    # Tolerates a stub-shaped entry keyed only by .doc_id (no .id field) -- see
    # get_doc_fidelity's header comment above for the full contract.
    parent_entry=$(jq -c --arg id "$doc_id" '
      first(.entries[] | select((.id // .doc_id) == $id and (.parent_doc == null or .parent_doc == "")))
    ' "$GLOBAL_INDEX" 2>/dev/null)

    if [ -z "$parent_entry" ]; then
      # Try without parent_doc filter (older entries may lack the field)
      parent_entry=$(jq -c --arg id "$doc_id" '
        first(.entries[] | select((.id // .doc_id) == $id))
      ' "$GLOBAL_INDEX" 2>/dev/null)
    fi

    if [ -z "$parent_entry" ]; then
      echo "Warning: doc_id '$doc_id' not found in global index — skipping" >&2
      skip_count=$(( skip_count + 1 ))
      skipped_doc_ids+=("$doc_id")
      continue
    fi

    # Extract parent metadata. Tolerates a .doc_id-only stub entry (see
    # get_doc_fidelity's header comment above) so a resolved-by-doc_id entry does not
    # degrade to "Unknown Title" / empty authors / "?" year after the lookup succeeds.
    title=$(jq -r --arg id "$doc_id" '
      .entries[] | select((.id // .doc_id) == $id) | .title // "Unknown Title"
    ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

    authors_raw=$(jq -r --arg id "$doc_id" '
      .entries[] | select((.id // .doc_id) == $id) | (.authors // [] | if type == "array" then . else [.] end | join(", "))
    ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || authors_raw=""

    year=$(jq -r --arg id "$doc_id" '
      .entries[] | select((.id // .doc_id) == $id) | (.year // "?") | tostring
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
      # Also include parent entry tokens if present. (.id // .doc_id) tolerance
      # mirrors the other extraction sites above.
      parent_tokens=$(jq -r --arg id "$doc_id" '
        .entries[] | select((.id // .doc_id) == $id) | .token_count // 0
      ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || parent_tokens=0
      [[ "$parent_tokens" =~ ^[0-9]+$ ]] || { echo "Warning: non-numeric parent token_count for '$doc_id', defaulting to 0" >&2; parent_tokens=0; }
      total_tokens=$(( total_tokens + parent_tokens ))
    else
      total_tokens=$(jq -r --arg id "$doc_id" '
        .entries[] | select((.id // .doc_id) == $id) | .token_count // 0
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

    # provenance_fidelity lookup -- fail-open, see get_doc_fidelity above
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

  # --- If no entries resolved, exit silently ONLY when this was a structurally
  # empty/absent sub-index (skip_count -eq 0) -- the entry_count/doc_ids-empty/
  # missing-file guards above already cover that case. When skip_count -gt 0, every
  # requested doc_id failed to resolve: fall through to the shared marker/banner block
  # instead of exiting silently, so the failure produces a coverage marker rather than
  # empty stdout indistinguishable from a genuinely empty sub-index. ---
  if [ "${#briefing_lines[@]}" -eq 0 ] && [ "$skip_count" -eq 0 ]; then
    exit 0
  fi

  header="## Available Literature (${#briefing_lines[@]} document(s))"
  coverage_mode="repo"
  coverage_count="${#briefing_lines[@]}"
  # Repo mode has no per-term corroboration concept (it resolves specific doc_ids, it
  # never runs the --multi filtered-term search) -- sparse determination always uses
  # the plain coverage_count here, matching pre-existing behavior exactly.
  sparse_eval_count="$coverage_count"

  # --- Topic-scoped coverage-delta guard (repo mode only, --query present) ---
  # Reaches the consuming agent's prompt via the in-band marker/banner below even in
  # orchestrator_mode=true, where AskUserQuestion is forbidden and stderr never arrives.
  # Guarded so a delta-script failure or absence degrades to delta_checked=false with a visible
  # stderr notice -- never a crash, never a silent skip. Does NOT set sparse=true (D5).
  if [ -n "$repo_query" ]; then
    delta_script="$SCRIPT_DIR/literature-coverage-delta.sh"
    delta_line=""
    if [ -x "$delta_script" ]; then
      delta_line=$(bash "$delta_script" --query "$repo_query" 2>/dev/null) || delta_line=""
    else
      echo "Warning: literature-coverage-delta.sh not found or not executable at $delta_script; coverage-delta guard reports delta_checked=false." >&2
    fi

    if [ -n "$delta_line" ]; then
      delta_checked=$(echo "$delta_line" | grep -oE 'delta_checked=[a-z]+' | cut -d= -f2) || delta_checked="false"
      delta_gap=$(echo "$delta_line" | grep -oE 'delta_gap=[0-9]+' | cut -d= -f2) || delta_gap=0
      delta_candidates=$(echo "$delta_line" | grep -oE 'delta_candidates=[0-9]+' | cut -d= -f2) || delta_candidates=0
      # Anchored to a preceding space/start-of-string so this does not also match the
      # "delta_candidates=" field above (a bare "candidates=" substring search would).
      delta_candidate_ids=$(echo "$delta_line" | grep -oE '(^| )candidates=[^ ]*' | cut -d= -f2-) || delta_candidate_ids=""
      delta_candidate_titles_json=$(echo "$delta_line" | grep -oE 'candidate_titles=\[.*\]$') || delta_candidate_titles_json=""
      delta_candidate_titles_json="${delta_candidate_titles_json#candidate_titles=}"
      delta_checked="${delta_checked:-false}"
      delta_gap="${delta_gap:-0}"
      delta_candidates="${delta_candidates:-0}"
      [ -z "$delta_candidate_titles_json" ] && delta_candidate_titles_json="[]"
    fi
  fi

else
  # ============================================================
  # Global-corpus search mode (--global "<query>")
  # ============================================================
  repo_name="$(basename "$PROJECT_ROOT")"

  # --- Filtered-term multi-query search ---
  # FTS5's bareword MATCH ANDs every term together, a condition no real document
  # satisfies once the forwarded query reaches full task-description length (15-30+
  # words) -- the AND-all-terms recall defect this mode exists to fix. Replace the
  # single whole-query search with the filtered-term set (literature-coverage-delta.sh's
  # established reuse template -- copied verbatim, not a second stop-word filter),
  # forwarded as one literature-search.sh --multi call so the per-term fan-out costs one
  # process, not N.
  # shellcheck source=literature-term-match.sh
  source "$SCRIPT_DIR/literature-term-match.sh"
  mapfile -t FILTERED_TERMS < <(filter_terms "$query")

  # filter_terms() prints exactly one blank line when every term was filtered out
  # (a `printf '%s\n' "${terms[@]:-}"` quirk on a zero-element array), so a fully
  # stop-word query yields a 1-element array holding "" rather than a 0-element
  # array -- strip blank entries before sizing FILTERED_TERMS, or the empty-filtered
  # -terms fallback below never triggers.
  _nonblank_terms=()
  for _t in "${FILTERED_TERMS[@]}"; do
    [ -n "$_t" ] && _nonblank_terms+=("$_t")
  done
  FILTERED_TERMS=("${_nonblank_terms[@]}")
  unset _nonblank_terms _t

  # Longest-first cap: keeps the most discriminating terms when filter_terms()
  # returns more than LITERATURE_GLOBAL_MAX_TERMS.
  if [ "${#FILTERED_TERMS[@]}" -gt "$LITERATURE_GLOBAL_MAX_TERMS" ]; then
    mapfile -t FILTERED_TERMS < <(
      printf '%s\n' "${FILTERED_TERMS[@]}" \
        | awk '{ print length, $0 }' \
        | sort -rn \
        | head -n "$LITERATURE_GLOBAL_MAX_TERMS" \
        | cut -d' ' -f2-
    )
  fi

  # Capture stderr instead of discarding it so a real search-script
  # failure can be surfaced below rather than silently coerced to "no results".
  search_err_file="$(mktemp)"
  if [ "${#FILTERED_TERMS[@]}" -eq 0 ]; then
    # Empty-filtered-terms fallback (e.g. a query that is entirely stop words):
    # never search nothing silently -- fall back to the original single
    # raw-query call and log a visible notice.
    echo "Warning: no meaningful search terms survived stop-word filtering for --global query '${query}'; falling back to a single raw-query search." >&2
    results_json=$(bash "$SEARCH_SCRIPT" --project "$repo_name" "$query" 2>"$search_err_file") || results_json="[]"
  else
    results_json=$(printf '%s\n' "${FILTERED_TERMS[@]}" | bash "$SEARCH_SCRIPT" --project "$repo_name" --multi 2>"$search_err_file") || results_json="[]"
  fi
  search_stderr="$(cat "$search_err_file" 2>/dev/null || true)"
  rm -f "$search_err_file"

  # --- Shape-aware parsing ---
  # Accepts the legacy bare-array shape (pre-#833: degraded=false, fallback_tier=bm25,
  # query_error=null), the single-query envelope object {results, degraded, fallback_tier,
  # query_error} literature-search.sh emitted before this task, and the multi-query
  # envelope (adds total_matched) this task's --multi mode emits. An unparseable payload
  # remains a hard [] fallback, but now logs a visible notice -- this task exists to
  # remove exactly the kind of silent swallow the old unconditional coercion performed.
  degraded="false"
  fallback_tier="bm25"
  query_error="null"
  total_matched=""
  corroborated_count=""

  if echo "$results_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    : # legacy bare-array shape; results_json already holds the array, defaults above stand
  elif echo "$results_json" | jq -e 'type == "object" and has("results")' >/dev/null 2>&1; then
    degraded=$(echo "$results_json" | jq -r '.degraded // false')
    fallback_tier=$(echo "$results_json" | jq -r '.fallback_tier // "bm25"')
    query_error=$(echo "$results_json" | jq -r 'if .query_error == null then "null" else .query_error end')
    total_matched=$(echo "$results_json" | jq -r 'if has("total_matched") and (.total_matched != null) then (.total_matched|tostring) else "" end')
    corroborated_count=$(echo "$results_json" | jq -r 'if has("corroborated_count") and (.corroborated_count != null) then (.corroborated_count|tostring) else "" end')
    results_json=$(echo "$results_json" | jq -c '.results // []')
  else
    echo "Warning: literature-search.sh returned an unparseable payload for --global query '${query}'; treating as zero results. stderr: ${search_stderr:-<empty>}" >&2
    results_json="[]"
  fi

  # seg_count is the de-duplicated, post-merge, PRE-top_n-slice total-match count (this
  # is what coverage_count below is pinned to, so the sparse=true marker stays honest).
  # Prefer the multi-query envelope's own total_matched (the true dedup total across all
  # filtered terms) when present; fall back to `results | length` for the legacy
  # bare-array/single-query-object shapes that never had this field -- for those shapes
  # `results | length` IS the pre-slice total, matching the field's original semantics.
  if [ -n "$total_matched" ]; then
    seg_count="$total_matched"
  else
    seg_count=$(echo "$results_json" | jq 'length' 2>/dev/null || echo 0)
  fi

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
      # (already computed in literature-search.sh) -- no separate lookup needed here.
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
  requested_count="$seg_count"

  # --- Sparse-determination input, corroboration-tightened for long queries ---
  # seg_count/coverage_count above stay the honest, unchanged, de-duplicated total --
  # the DISPLAYED result set never shrinks because of this. But once the filtered
  # term count exceeds MULTI_TERM_MATCH_THRESHOLD, total_matched alone stops being a
  # reliable sparse-vs-rich signal: verified empirically against the real global
  # corpus that a query with NO real topical overlap with the corpus can still post a
  # large total_matched purely from coincidental single-term hits spread across
  # unrelated documents once enough short, individually-common English words are
  # OR-merged, which would silently defeat the sparse=true re-prompt this marker
  # exists to drive. Use corroborated_count (matched_terms >= 2) as the sparse
  # boolean's input instead, in that regime only -- mirroring the same >=2-distinct
  # -hits asymmetry literature-coverage-delta.sh/literature-discover.sh already apply
  # for exactly this class of long, generic-word-heavy query.
  sparse_eval_count="$coverage_count"
  if [ "${#FILTERED_TERMS[@]}" -gt "$MULTI_TERM_MATCH_THRESHOLD" ] && [ -n "$corroborated_count" ]; then
    sparse_eval_count="$corroborated_count"
  fi

  # --- Degraded-tier banner ---
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
# skip_rate is an integer percentage of requested doc_ids that failed to resolve
# (repo mode only; always 0 in global mode, where no per-item resolution can fail).
# Guarded against division by zero -- reachable in global mode with zero results.
if [ "$requested_count" -eq 0 ]; then
  skip_rate=0
else
  skip_rate=$(( skip_count * 100 / requested_count ))
fi

sparse="false"
if [ "$sparse_eval_count" -lt "$LITERATURE_SPARSE_THRESHOLD" ]; then
  sparse="true"
elif [ "$skip_count" -gt 0 ] && [ "$skip_rate" -ge "$LITERATURE_SKIP_RATE_THRESHOLD" ]; then
  sparse="true"
fi
# delta_checked=/delta_gap=/delta_candidates= are appended strictly AFTER the original eight
# fields above (mode=/seg_count=/sparse=/threshold=/requested=/resolved=/skipped=/skip_rate=),
# which stay byte-for-byte adjacent and in their original order for backward compatibility with
# existing `.*`-tolerant greps (e.g. lit-stage4a-flow.md's `lit-coverage mode=global .*sparse=true`).
# delta_checked=false is ALWAYS emitted (never omitted) when the guard did not run -- D6: a
# not-computed delta must never be misread as a verified zero. The delta deliberately does NOT
# set sparse=true above (D5) -- see context/project/literature/domain/sparse-coverage.md.
echo "<!-- lit-coverage mode=${coverage_mode} seg_count=${coverage_count} sparse=${sparse} threshold=${LITERATURE_SPARSE_THRESHOLD} requested=${requested_count} resolved=${coverage_count} skipped=${skip_count} skip_rate=${skip_rate} delta_checked=${delta_checked} delta_gap=${delta_gap} delta_candidates=${delta_candidates} -->"
echo ""

if [ "$sparse" = "true" ]; then
  echo "[SPARSE COVERAGE - ${coverage_count} segment(s), threshold ${LITERATURE_SPARSE_THRESHOLD}] This briefing resolved fewer relevant segments than the configured sparsity threshold; consider searching online for additional sources (see the Stage 4a \"Search online to ingest\" option) or broadening the query."
  echo ""
fi

# --- Skipped-sources banner (never silent; independent of whether the rate crossed
# the sparse threshold -- a low but nonzero skip rate is still worth surfacing) ---
if [ "$skip_count" -gt 0 ]; then
  echo "[SKIPPED SOURCES - ${skip_count} of ${requested_count} requested document(s) could not be resolved (${skip_rate}%); see \"Unresolved Documents\" below]"
  echo ""
fi

# --- Coverage-delta banner (never silent when the guard fired; mandatory in-band channel --
# this is what reaches orchestrator_mode=true runs, where AskUserQuestion is forbidden and
# stderr never enters the agent's prompt). Fires only when the guard actually ran AND found a
# candidate count meeting LITERATURE_COVERAGE_DELTA_THRESHOLD -- a delta_checked=false or
# delta_candidates=0 result stays silent here (no alarm fatigue on an ordinary curated
# sub-index). Does NOT set sparse=true (D5) -- see the marker comment above. ---
if [ "$delta_checked" = "true" ] && [ "$delta_candidates" -ge "$LITERATURE_COVERAGE_DELTA_THRESHOLD" ]; then
  echo "[COVERAGE DELTA - ${delta_candidates} topic-relevant document(s) in the global corpus are absent from this repo's sub-index]"
  _delta_id_arr=()
  if [ -n "$delta_candidate_ids" ]; then
    IFS=',' read -ra _delta_id_arr <<< "$delta_candidate_ids"
    _delta_title_list=$(echo "$delta_candidate_titles_json" | jq -r '.[]?' 2>/dev/null) || _delta_title_list=""
    mapfile -t _delta_title_arr <<< "$_delta_title_list"
    for _i in "${!_delta_id_arr[@]}"; do
      _delta_title="${_delta_title_arr[$_i]:-Unknown Title}"
      echo "  - ${_delta_title} (${_delta_id_arr[$_i]})"
    done
  fi
  echo "  (${delta_candidates} total; see above for the top ${#_delta_id_arr[@]} bounded here)"
  echo ""
fi

if [ "${#briefing_lines[@]}" -eq 0 ]; then
  # Honest zero-result messaging: a genuine zero-result (query_error null,
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

if [ "${#skipped_doc_ids[@]}" -gt 0 ]; then
  echo "## Unresolved Documents"
  echo ""
  for skipped_id in "${skipped_doc_ids[@]}"; do
    echo "- ${skipped_id}"
  done
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
