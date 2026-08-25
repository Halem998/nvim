#!/usr/bin/env bash
# literature-discover.sh — Three-tier source discovery pipeline
#
# USAGE:
#   literature-discover.sh "search terms"           # Discover by keywords
#   literature-discover.sh --task N                  # Discover from task description
#   literature-discover.sh --task N "extra terms"    # Task description + extra terms
#
# DESCRIPTION:
#   Searches for academic sources across three tiers:
#     Tier 1 (offline, fast)  — Global LITERATURE_DIR/index.json by title/keyword
#     Tier 2 (local, fast)    — Zotero library via zotero-search.sh
#     Tier 3 (online, slower) — Semantic Scholar + Unpaywall/arXiv fallback
#
# OUTPUT:
#   JSON array to stdout. Each element has:
#     title, authors, year, doc_id, status, tier, path|doi|pdf_url|arxiv_id
#   Status values: available, in_zotero, in_zotero_no_pdf, open_access, paywall
#
# EXIT CODES:
#   0 — sources found (JSON array on stdout)
#   1 — no sources found
#   2 — argument error
#
# ENVIRONMENT:
#   LITERATURE_DIR         — Global library root (default: ~/Projects/Literature)
#   DISCOVER_LIMIT         — Maximum results to return (default: 10)
#   DISCOVER_DESC_WORD_CAP — Max words taken from a --task description when building the search
#                            query (default: 30). Task titles are short and curated, so they are
#                            never capped and are always treated as primary terms; a task
#                            description can run to several paragraphs, so only its first
#                            DISCOVER_DESC_WORD_CAP words are used, as supplementary terms, to
#                            keep Tiers 1/2's substring matcher from picking up incidental,
#                            unrelated shared words buried later in a long description.
#
# SOURCES.md format (created at specs/literature/SOURCES.md):
#   Markdown table: Title | Authors | Year | DOI | Status | Notes
#   Status values: [PENDING], [IN_ZOTERO], [PAYWALL], [FOUND], [RESOLVED]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
DISCOVER_LIMIT="${DISCOVER_LIMIT:-10}"
DISCOVER_DESC_WORD_CAP="${DISCOVER_DESC_WORD_CAP:-30}"
USER_EMAIL="${USER_EMAIL:-benbrastmckie@gmail.com}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

TASK_NUM=""
SEARCH_TERMS=""

show_usage() {
  cat >&2 << 'USAGE'
USAGE:
  literature-discover.sh "search terms"
  literature-discover.sh --task N
  literature-discover.sh --task N "extra terms"

DESCRIPTION:
  Searches for academic sources via three-tier pipeline:
    Tier 1: LITERATURE_DIR/index.json (offline, instant)
    Tier 2: Zotero library via zotero-search.sh (local, fast)
    Tier 3: Semantic Scholar + Unpaywall/arXiv (online, network required)

EXIT CODES:
  0  Sources found (JSON array on stdout)
  1  No sources found
  2  Argument error
USAGE
}

# Parse arguments
i=1
while [ "$i" -le "$#" ]; do
  arg="${!i}"
  case "$arg" in
    --task)
      i=$(( i + 1 ))
      if [ "$i" -gt "$#" ]; then
        echo "Error: --task requires a task number argument" >&2
        show_usage
        exit 2
      fi
      TASK_NUM="${!i}"
      if ! [[ "$TASK_NUM" =~ ^[0-9]+$ ]]; then
        echo "Error: --task argument must be a positive integer, got: $TASK_NUM" >&2
        exit 2
      fi
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $arg" >&2
      show_usage
      exit 2
      ;;
    *)
      if [ -n "$SEARCH_TERMS" ]; then
        SEARCH_TERMS="$SEARCH_TERMS $arg"
      else
        SEARCH_TERMS="$arg"
      fi
      ;;
  esac
  i=$(( i + 1 ))
done

# ---------------------------------------------------------------------------
# Helper: cap a string to its first N whitespace-separated words. Used to
# bound how much of a --task description feeds the query -- see
# DISCOVER_DESC_WORD_CAP above.
# ---------------------------------------------------------------------------
cap_words() {
  local text="$1"
  local max_words="$2"
  # Flatten embedded newlines (task descriptions are frequently
  # multi-paragraph) to a single line first -- awk's NF/loop-index resets
  # per input record, so applying the cap without this would truncate each
  # line to max_words independently instead of the string as a whole.
  echo "$text" | tr '\n' ' ' | awk -v n="$max_words" \
    '{ for (i = 1; i <= NF && i <= n; i++) { printf "%s%s", (i > 1 ? " " : ""), $i } }'
}

# Resolve task description if --task given
if [ -n "$TASK_NUM" ]; then
  # Try to get task description/title from state.json
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  state_file="$git_root/specs/state.json"

  if [ -f "$state_file" ]; then
    task_found=$(jq -r --arg n "$TASK_NUM" \
      '[.active_projects[] | select(.project_number == ($n|tonumber))] | length' \
      "$state_file" 2>/dev/null || echo "0")

    if [ "$task_found" -gt 0 ]; then
      task_description=$(jq -r --arg n "$TASK_NUM" \
        '.active_projects[] | select(.project_number == ($n|tonumber)) | .description // ""' \
        "$state_file" 2>/dev/null)
      task_title=$(jq -r --arg n "$TASK_NUM" \
        '.active_projects[] | select(.project_number == ($n|tonumber)) | .title // ""' \
        "$state_file" 2>/dev/null)

      # Title terms are primary and always fully included -- titles are short
      # and curated. Description terms are supplementary and capped to the
      # first DISCOVER_DESC_WORD_CAP words: a task description can run to
      # several paragraphs, and feeding the whole field to Tiers 1/2's
      # substring matcher lets one incidental shared word buried later in the
      # text surface an unrelated paper. Title is placed first so it is never
      # at risk from any future truncation of this string.
      task_desc_capped=""
      if [ -n "$task_description" ] && [ "$task_description" != "null" ]; then
        task_desc_capped=$(cap_words "$task_description" "$DISCOVER_DESC_WORD_CAP")
      fi

      task_terms=""
      [ -n "$task_title" ] && [ "$task_title" != "null" ] && task_terms="$task_title"
      [ -n "$task_desc_capped" ] && task_terms="$task_terms $task_desc_capped"
      task_terms=$(echo "$task_terms" | sed -E 's/^ +| +$//g')

      if [ -z "$task_terms" ]; then
        echo "Error: Task $TASK_NUM has no description or title in specs/state.json to build a search query from" >&2
        exit 2
      fi

      if [ -n "$SEARCH_TERMS" ]; then
        SEARCH_TERMS="$task_terms $SEARCH_TERMS"
      else
        SEARCH_TERMS="$task_terms"
      fi
    else
      echo "Error: Task $TASK_NUM not found in specs/state.json" >&2
      exit 2
    fi
  else
    echo "Error: specs/state.json not found" >&2
    exit 2
  fi
fi

# Require at least one search term
if [ -z "$SEARCH_TERMS" ]; then
  echo "Error: No search terms provided" >&2
  show_usage
  exit 2
fi

# ---------------------------------------------------------------------------
# Helper: URL-encode a string
# ---------------------------------------------------------------------------
urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# ---------------------------------------------------------------------------
# Shared Tier 1 keyword-matching helper (to_lower, term_matches, STOP_WORDS,
# filter_terms, MULTI_TERM_MATCH_THRESHOLD). Extracted so literature-coverage-delta.sh
# can reuse the exact same matcher rather than reimplementing it -- see that file's
# header for the second call site. Definitions below are unchanged from before the
# extraction; only their location moved.
# ---------------------------------------------------------------------------
source "$SCRIPT_DIR/literature-term-match.sh"

# SEARCH_TERMS already has title-primary/description-capped-supplementary
# ordering applied above for --task invocations (a plain positional query has
# no such split -- it is a deliberate, hand-typed string and is filtered as
# a whole, unchanged from before). filter_terms() has no cross-token state
# (each raw token is filtered independently), so filtering this single
# combined string is equivalent to filtering the title and capped
# description separately and concatenating the results.
mapfile -t FILTERED_TERMS < <(filter_terms "$SEARCH_TERMS")

if [ "${#FILTERED_TERMS[@]}" -eq 0 ]; then
  echo "Error: No meaningful search terms after filtering stop words" >&2
  exit 2
fi

# Match-strength threshold trigger: Tiers 1/2's substring matcher requires
# >= 2 distinct filtered-term hits per candidate only when the filtered term
# count is large (a long --task description, even capped, can still produce
# more than a handful of terms); at or below this count, single-term-match
# behavior is preserved exactly so short, deliberate queries are unaffected.
# MULTI_TERM_MATCH_THRESHOLD itself now comes from the sourced literature-term-match.sh.
FILTERED_TERM_COUNT="${#FILTERED_TERMS[@]}"

# ---------------------------------------------------------------------------
# Result accumulation
# ---------------------------------------------------------------------------
# We build results as a JSON array string, appending entries from each tier.
# doc_ids and titles already seen are tracked to avoid duplicates.
RESULTS='[]'
SEEN_DOC_IDS=()
SEEN_TITLES=()

add_seen() {
  local id="$1"
  local title="$2"
  SEEN_DOC_IDS+=("$id")
  SEEN_TITLES+=("$(to_lower "$title")")
}

is_seen_doc_id() {
  local id="$1"
  for seen in "${SEEN_DOC_IDS[@]:-}"; do
    if [ "$seen" = "$id" ]; then
      return 0
    fi
  done
  return 1
}

is_seen_title() {
  local title
  title=$(to_lower "$1")
  for seen in "${SEEN_TITLES[@]:-}"; do
    if [ "$seen" = "$title" ]; then
      return 0
    fi
  done
  return 1
}

append_result() {
  local entry="$1"
  RESULTS=$(echo "$RESULTS" | jq --argjson e "$entry" '. + [$e]' 2>/dev/null || echo "$RESULTS")
}

# ---------------------------------------------------------------------------
# TIER 1: Search LITERATURE_DIR/index.json (offline, fast)
# ---------------------------------------------------------------------------
tier1_search() {
  local index_file="$LITERATURE_DIR/index.json"

  if [ ! -f "$index_file" ]; then
    return 0
  fi

  # Read top-level entries (parent_doc is null) and match against terms
  local count=0

  while IFS= read -r entry; do
    if [ -z "$entry" ] || [ "$entry" = "null" ]; then
      continue
    fi

    local doc_id title authors year path keywords
    doc_id=$(echo "$entry" | jq -r '.id // .doc_id // ""' 2>/dev/null)
    title=$(echo "$entry" | jq -r '.title // ""' 2>/dev/null)
    authors=$(echo "$entry" | jq -r '.authors // [] | if type == "array" then . else [.] end | join(", ")' 2>/dev/null)
    year=$(echo "$entry" | jq -r '.year // null' 2>/dev/null)
    path=$(echo "$entry" | jq -r '.path // ""' 2>/dev/null)
    keywords=$(echo "$entry" | jq -r '(.keywords // []) | join(" ")' 2>/dev/null)

    if [ -z "$title" ] || [ -z "$doc_id" ]; then
      continue
    fi

    # Check if already seen
    if is_seen_doc_id "$doc_id" || is_seen_title "$title"; then
      continue
    fi

    # Match: title or keywords must contain at least one search term. When
    # the filtered term list is long (> MULTI_TERM_MATCH_THRESHOLD, e.g. a
    # capped task description contributing many supplementary terms), a
    # single incidental shared word is not enough -- require >= 2 distinct
    # term hits. At or below the threshold, preserve the original
    # accept-on-first-hit behavior exactly (short, deliberate queries are
    # unaffected).
    local matched=false
    if [ "$FILTERED_TERM_COUNT" -gt "$MULTI_TERM_MATCH_THRESHOLD" ]; then
      local hit_count=0
      for term in "${FILTERED_TERMS[@]}"; do
        if term_matches "$title" "$term" || term_matches "$keywords" "$term"; then
          hit_count=$(( hit_count + 1 ))
          if [ "$hit_count" -ge 2 ]; then
            matched=true
            break
          fi
        fi
      done
    else
      for term in "${FILTERED_TERMS[@]}"; do
        if term_matches "$title" "$term" || term_matches "$keywords" "$term"; then
          matched=true
          break
        fi
      done
    fi

    if [ "$matched" = "true" ]; then
      # Resolve full path
      local full_path=""
      if [ -n "$path" ]; then
        if [[ "$path" == /* ]]; then
          full_path="$path"
        else
          full_path="$LITERATURE_DIR/$path"
        fi
      fi

      local result
      result=$(jq -n \
        --arg title "$title" \
        --arg authors "$authors" \
        --arg year "$year" \
        --arg doc_id "$doc_id" \
        --arg path "$full_path" \
        '{
          title: $title,
          authors: ([$authors] | if . == [""] then [] else . end),
          year: (if $year == "null" or $year == "" then null else ($year | tonumber? // null) end),
          doc_id: $doc_id,
          status: "available",
          tier: 1,
          path: (if $path == "" then null else $path end)
        }' 2>/dev/null) || continue

      append_result "$result"
      add_seen "$doc_id" "$title"
      count=$(( count + 1 ))

      if [ "$count" -ge "$TIER1_QUOTA" ]; then
        break
      fi
    fi
  done < <(jq -c '.entries[] | select(.parent_doc == null or .parent_doc == "")' "$index_file" 2>/dev/null)
}

# ---------------------------------------------------------------------------
# TIER 2: Search Zotero via zotero-search.sh (local, fast)
#
# NOTE on the query-noise fix: unlike tier1_search()'s inline term_matches()
# loop, this tier has no accept-on-first-hit call site of its own to add a
# multi-term threshold to -- it forwards FILTERED_TERMS as positional args
# to zotero-search.sh, which already does its own weighted multi-field
# scoring in a single jq pass (see that script's header). The noise
# reduction that reaches this tier is the shared, capped FILTERED_TERMS
# array built above (title-primary, description-supplementary-and-capped);
# no separate threshold logic is needed or added here.
# ---------------------------------------------------------------------------
tier2_search() {
  local zotero_library="$LITERATURE_DIR/zotero-library.json"

  if [ ! -f "$zotero_library" ]; then
    echo "Tier 2 (Zotero) skipped: no export found at $zotero_library" >&2
    echo "  To enable: in Zotero, File -> Export Library -> format \"Better CSL JSON\", check \"Keep updated\", save to $zotero_library" >&2
    echo "  Or let /literature generate it for you: it offers assisted generation via zotero-export-status.sh + zotero-generate-export.sh before this discovery pass runs (see /literature discover mode)." >&2
    return 0
  fi

  # Find zotero-search.sh. provides.scripts deploys flat into {base_dir}/scripts/ in every
  # consuming repo (never into {base_dir}/extensions/{name}/scripts/, which only ever holds a
  # copied manifest.json — see .claude/context/guides/extension-development.md), so the flat
  # sibling path is the primary candidate. The nested path is kept only as a defensive fallback
  # for running directly from the extension source tree pre-deployment.
  local zotero_script=""
  for candidate in \
    "$SCRIPT_DIR/zotero-search.sh" \
    "$SCRIPT_DIR/../extensions/literature/scripts/zotero-search.sh"; do
    if [ -f "$candidate" ]; then
      zotero_script="$candidate"
      break
    fi
  done

  if [ -z "$zotero_script" ] || [ ! -x "$zotero_script" ]; then
    return 0
  fi

  local zotero_results=""
  local exit_code=0

  zotero_results=$("$zotero_script" --format=json --limit="$TIER2_QUOTA" \
    "${FILTERED_TERMS[@]}" 2>/dev/null) || exit_code=$?

  # Exit code 1 = library not found, 2 = no results — both are non-fatal
  if [ "$exit_code" -ne 0 ] || [ -z "$zotero_results" ]; then
    return 0
  fi

  local count=0

  while IFS= read -r entry; do
    if [ -z "$entry" ] || [ "$entry" = "null" ]; then
      continue
    fi

    local citation_key title authors year pdf_paths_json
    citation_key=$(echo "$entry" | jq -r '.citation_key // ""' 2>/dev/null)
    title=$(echo "$entry" | jq -r '.title // ""' 2>/dev/null)
    authors=$(echo "$entry" | jq -r '.authors // ""' 2>/dev/null)
    year=$(echo "$entry" | jq -r '.year // null' 2>/dev/null)
    pdf_paths_json=$(echo "$entry" | jq -r '.pdf_paths // []' 2>/dev/null)

    if [ -z "$title" ]; then
      continue
    fi

    # Skip already-found entries
    if is_seen_doc_id "$citation_key" || is_seen_title "$title"; then
      continue
    fi

    # Determine status based on PDF availability
    local status="in_zotero_no_pdf"
    local pdf_count
    pdf_count=$(echo "$pdf_paths_json" | jq 'length' 2>/dev/null || echo "0")

    if [ "$pdf_count" -gt 0 ]; then
      status="in_zotero"
    fi

    # Build authors array
    local authors_arr
    if echo "$authors" | grep -q ';'; then
      authors_arr=$(echo "$authors" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
parts = [p.strip() for p in raw.split(';') if p.strip()]
print(json.dumps(parts))
" 2>/dev/null)
    elif [ -n "$authors" ]; then
      authors_arr=$(python3 -c "import json, sys; print(json.dumps([sys.argv[1]]))" "$authors" 2>/dev/null)
    else
      authors_arr='[]'
    fi

    local result
    result=$(jq -n \
      --arg title "$title" \
      --argjson authors "$authors_arr" \
      --arg year "$year" \
      --arg doc_id "$citation_key" \
      --arg status "$status" \
      '{
        title: $title,
        authors: $authors,
        year: (if $year == "null" or $year == "" then null else ($year | tonumber? // null) end),
        doc_id: $doc_id,
        status: $status,
        tier: 2
      }' 2>/dev/null) || continue

    append_result "$result"
    add_seen "$citation_key" "$title"
    count=$(( count + 1 ))

    if [ "$count" -ge "$TIER2_QUOTA" ]; then
      break
    fi
  done < <(echo "$zotero_results" | jq -c '.[]' 2>/dev/null)
}

# ---------------------------------------------------------------------------
# TIER 3: Search Semantic Scholar + Unpaywall/arXiv (online, slower)
#
# TIER3_STATUS stderr contract: on any non-success outcome (curl failure,
# non-200 HTTP response, or a JSON `.error` body), this function writes
# exactly one line to its own stderr of the shape
# `TIER3_STATUS: FAILED reason=<curl_exit|http|api_error> http_code=<code|n/a> (<human text>)`
# before returning 0 (Tier 3 stays non-fatal). Nothing is written on a
# genuine 200 with zero matches — absence of the line means "Tier 3 ran and
# found nothing", not "Tier 3 could not run". This mirrors the
# directive/rationale idiom `zotero-export-status.sh` uses for its own
# stderr rationale, minus the stdout directive token (Tier 3 has no separate
# classifier call site). The consumer is `commands/literature.md`'s discover
# step 1, which captures this script's stderr (no longer `2>/dev/null`) and
# greps it for `TIER3_STATUS: FAILED` to surface a visible incompleteness
# notice. The JSON-array stdout contract is untouched by any of this.
# ---------------------------------------------------------------------------
tier3_search() {
  # Tier 3's budget is TIER3_QUOTA -- its own reserved share of DISCOVER_LIMIT
  # plus any unused share rolled forward from Tiers 1/2 (see the tier-dispatch
  # block below for the quota computation and rollover). A quota of 0 is a
  # genuine "no budget left" skip, not a failure: it MUST NOT emit a
  # TIER3_STATUS line -- a skipped Tier 3 is not a failed Tier 3.
  if [ "$TIER3_QUOTA" -le 0 ]; then
    return 0
  fi

  local remaining="$TIER3_QUOTA"

  # Build query string (join filtered terms with spaces). Deliberately loose/
  # wide, unlike tier1_search()'s multi-term match-strength threshold above:
  # Semantic Scholar is a genuine full-text search API with its own
  # relevance ranking and tolerates a longer free-text query, so all of
  # FILTERED_TERMS is sent as-is with no extra threshold applied here.
  local query_string="${FILTERED_TERMS[*]}"
  local encoded_query
  encoded_query=$(urlencode "$query_string")

  local ss_url="https://api.semanticscholar.org/graph/v1/paper/search?query=${encoded_query}&fields=title,authors,year,openAccessPdf,externalIds&limit=10"

  # Capture the HTTP status alongside the body so a rate-limited/failed
  # response is distinguishable from a genuine 200-with-zero-matches. The
  # status code is appended as its own trailing line (-w '\n%{http_code}');
  # splitting it back off leaves `ss_results` byte-identical to the raw JSON
  # body the rest of this function (and downstream jq) already expects.
  local ss_raw=""
  local curl_exit=0

  ss_raw=$(curl -s -w '\n%{http_code}' --max-time 15 "$ss_url" 2>/dev/null) || curl_exit=$?

  if [ "$curl_exit" -ne 0 ]; then
    echo "TIER3_STATUS: FAILED reason=curl_exit http_code=n/a (Semantic Scholar unreachable or timed out)" >&2
    return 0
  fi

  local http_code ss_results
  http_code=$(echo "$ss_raw" | tail -n1)
  ss_results=$(echo "$ss_raw" | sed '$d')

  if [ "$http_code" != "200" ] || [ -z "$ss_results" ]; then
    echo "TIER3_STATUS: FAILED reason=http http_code=${http_code:-n/a} (Semantic Scholar rate-limited or unreachable)" >&2
    return 0
  fi

  # Check for API error
  local error_msg
  error_msg=$(echo "$ss_results" | jq -r '.error // ""' 2>/dev/null)
  if [ -n "$error_msg" ] && [ "$error_msg" != "null" ]; then
    echo "TIER3_STATUS: FAILED reason=api_error http_code=${http_code} (${error_msg})" >&2
    return 0
  fi

  local count=0

  while IFS= read -r paper; do
    if [ -z "$paper" ] || [ "$paper" = "null" ]; then
      continue
    fi

    local title authors_arr year doi arxiv_id open_access_url paper_id
    title=$(echo "$paper" | jq -r '.title // ""' 2>/dev/null)
    year=$(echo "$paper" | jq -r '.year // null' 2>/dev/null)
    doi=$(echo "$paper" | jq -r '.externalIds.DOI // ""' 2>/dev/null)
    arxiv_id=$(echo "$paper" | jq -r '.externalIds.ArXiv // ""' 2>/dev/null)
    open_access_url=$(echo "$paper" | jq -r '.openAccessPdf.url // ""' 2>/dev/null)
    paper_id=$(echo "$paper" | jq -r '.paperId // ""' 2>/dev/null)

    if [ -z "$title" ]; then
      continue
    fi

    # Skip already-seen titles
    if is_seen_title "$title"; then
      continue
    fi

    # Build authors array
    authors_arr=$(echo "$paper" | jq -r '
      .authors // [] |
      map(.name // "") |
      map(select(. != "")) |
      @json
    ' 2>/dev/null || echo '[]')

    # Determine doc_id (prefer DOI slug, then arXiv, then paper_id)
    local doc_id=""
    if [ -n "$doi" ] && [ "$doi" != "null" ]; then
      doc_id=$(echo "$doi" | tr '/' '_' | tr '.' '_')
    elif [ -n "$arxiv_id" ] && [ "$arxiv_id" != "null" ]; then
      doc_id="arxiv_${arxiv_id//./_}"
    elif [ -n "$paper_id" ]; then
      doc_id="ss_$paper_id"
    else
      doc_id="unknown_$(echo "$title" | tr '[:upper:] ' '[:lower:]_' | tr -cs 'a-z0-9_' '_' | cut -c1-40)"
    fi

    # Skip already-seen doc_ids
    if is_seen_doc_id "$doc_id"; then
      continue
    fi

    # Determine status and PDF URL
    local status="paywall"
    local pdf_url=""

    if [ -n "$open_access_url" ] && [ "$open_access_url" != "null" ]; then
      status="open_access"
      pdf_url="$open_access_url"
    elif [ -n "$arxiv_id" ] && [ "$arxiv_id" != "null" ]; then
      # arXiv PDFs are always freely available
      status="open_access"
      pdf_url="https://arxiv.org/pdf/$arxiv_id"
    elif [ -n "$doi" ] && [ "$doi" != "null" ]; then
      # Try Unpaywall for DOI lookup
      local uw_url="https://api.unpaywall.org/v2/${doi}?email=${USER_EMAIL}"
      local uw_result=""
      local uw_exit=0

      uw_result=$(curl -s --max-time 10 "$uw_url" 2>/dev/null) || uw_exit=$?

      if [ "$uw_exit" -eq 0 ] && [ -n "$uw_result" ]; then
        local oa_url
        oa_url=$(echo "$uw_result" | jq -r '.best_oa_location.url // ""' 2>/dev/null)
        if [ -n "$oa_url" ] && [ "$oa_url" != "null" ]; then
          status="open_access"
          pdf_url="$oa_url"
        fi
      fi
    fi

    local result
    result=$(jq -n \
      --arg title "$title" \
      --argjson authors "$authors_arr" \
      --arg year "$year" \
      --arg doc_id "$doc_id" \
      --arg status "$status" \
      --arg doi "$doi" \
      --arg arxiv_id "$arxiv_id" \
      --arg pdf_url "$pdf_url" \
      '{
        title: $title,
        authors: $authors,
        year: (if $year == "null" or $year == "" then null else ($year | tonumber? // null) end),
        doc_id: $doc_id,
        status: $status,
        tier: 3,
        doi: (if $doi == "" or $doi == "null" then null else $doi end),
        arxiv_id: (if $arxiv_id == "" or $arxiv_id == "null" then null else $arxiv_id end),
        pdf_url: (if $pdf_url == "" then null else $pdf_url end)
      }' 2>/dev/null) || continue

    append_result "$result"
    add_seen "$doc_id" "$title"
    count=$(( count + 1 ))

    if [ "$count" -ge "$remaining" ]; then
      break
    fi
  done < <(echo "$ss_results" | jq -c '.data[]? // empty' 2>/dev/null)
}

# ---------------------------------------------------------------------------
# Per-tier quotas with rollover
#
# Each tier gets a reserved, even-with-remainder share of DISCOVER_LIMIT so
# an early tier (typically Tier 1, offline and fast) cannot single-handedly
# consume the whole budget and starve later tiers, or have its own real hits
# discarded by the final head-of-array truncation below. Unused quota rolls
# forward: a tier that finds fewer results than its reserved share hands the
# shortfall to the next tier, so a sparse corpus never wastes slots. Actual
# counts are derived from the shared RESULTS array length (not a per-tier
# local counter) so rollover is correct even when dedup skips entries.
# ---------------------------------------------------------------------------
TIER1_QUOTA=$(( (DISCOVER_LIMIT + 2) / 3 ))
TIER2_QUOTA=$(( (DISCOVER_LIMIT + 1) / 3 ))
TIER3_QUOTA=$(( DISCOVER_LIMIT - TIER1_QUOTA - TIER2_QUOTA ))

# ---------------------------------------------------------------------------
# Execute tiers (each fails independently)
# ---------------------------------------------------------------------------

# Tier 1: offline index
tier1_search 2>/dev/null || true

tier1_actual=$(echo "$RESULTS" | jq 'length' 2>/dev/null || echo "0")
TIER2_QUOTA=$(( TIER2_QUOTA + TIER1_QUOTA - tier1_actual ))

# Tier 2: Zotero
tier2_search || true

tier1_and_2_actual=$(echo "$RESULTS" | jq 'length' 2>/dev/null || echo "0")
tier2_actual=$(( tier1_and_2_actual - tier1_actual ))
TIER3_QUOTA=$(( TIER3_QUOTA + TIER2_QUOTA - tier2_actual ))

# Tier 3: Online APIs (only runs while TIER3_QUOTA, including any rolled-
# forward shortfall from Tiers 1/2, is still positive)
tier3_search || true

# ---------------------------------------------------------------------------
# Output results
# ---------------------------------------------------------------------------
final_count=$(echo "$RESULTS" | jq 'length' 2>/dev/null || echo "0")

if [ "$final_count" -eq 0 ]; then
  echo '[]'
  exit 1
fi

# Truncate to limit and output. With per-tier quotas above, RESULTS should
# never meaningfully exceed DISCOVER_LIMIT by construction -- this slice is
# now a safety net, not the selection mechanism.
echo "$RESULTS" | jq --argjson limit "$DISCOVER_LIMIT" '.[0:$limit]'
exit 0
