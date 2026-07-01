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
#   LITERATURE_DIR   — Global library root (default: ~/Projects/Literature)
#   DISCOVER_LIMIT   — Maximum results to return (default: 10)
#
# SOURCES.md format (created at specs/literature/SOURCES.md):
#   Markdown table: Title | Authors | Year | DOI | Status | Notes
#   Status values: [PENDING], [IN_ZOTERO], [PAYWALL], [FOUND], [RESOLVED]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
DISCOVER_LIMIT="${DISCOVER_LIMIT:-10}"
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

# Resolve task description if --task given
if [ -n "$TASK_NUM" ]; then
  # Try to get task name from state.json
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  state_file="$git_root/specs/state.json"

  if [ -f "$state_file" ]; then
    task_name=$(jq -r --arg n "$TASK_NUM" '
      .active_projects[] | select(.project_number == ($n | tonumber)) | .project_name
    ' "$state_file" 2>/dev/null || echo "")

    if [ -n "$task_name" ] && [ "$task_name" != "null" ]; then
      # Convert slug to search terms (replace underscores/hyphens with spaces)
      task_terms=$(echo "$task_name" | tr '_-' '  ')
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
# Helper: lowercase for case-insensitive matching
# ---------------------------------------------------------------------------
to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------------------
# Helper: check if term appears in string (case-insensitive)
# ---------------------------------------------------------------------------
term_matches() {
  local haystack
  haystack=$(to_lower "$1")
  local needle
  needle=$(to_lower "$2")
  echo "$haystack" | grep -qF "$needle"
}

# ---------------------------------------------------------------------------
# Split SEARCH_TERMS into array, filter stop words and short terms
# ---------------------------------------------------------------------------
STOP_WORDS="a an the in on at of to and or for by with from is are was were"

filter_terms() {
  local input="$1"
  local terms=()
  IFS=' ' read -ra raw_terms <<< "$input"
  for raw in "${raw_terms[@]}"; do
    term=$(to_lower "$raw")
    # Skip short terms
    if [ "${#term}" -lt 3 ]; then
      continue
    fi
    # Skip stop words
    is_stop=false
    for stop in $STOP_WORDS; do
      if [ "$term" = "$stop" ]; then
        is_stop=true
        break
      fi
    done
    if [ "$is_stop" = "false" ]; then
      terms+=("$term")
    fi
  done
  printf '%s\n' "${terms[@]:-}"
}

mapfile -t FILTERED_TERMS < <(filter_terms "$SEARCH_TERMS")

if [ "${#FILTERED_TERMS[@]}" -eq 0 ]; then
  echo "Error: No meaningful search terms after filtering stop words" >&2
  exit 2
fi

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

    # Match: title or keywords must contain at least one search term
    local matched=false
    for term in "${FILTERED_TERMS[@]}"; do
      if term_matches "$title" "$term" || term_matches "$keywords" "$term"; then
        matched=true
        break
      fi
    done

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

      if [ "$count" -ge "$DISCOVER_LIMIT" ]; then
        break
      fi
    fi
  done < <(jq -c '.entries[] | select(.parent_doc == null or .parent_doc == "")' "$index_file" 2>/dev/null)
}

# ---------------------------------------------------------------------------
# TIER 2: Search Zotero via zotero-search.sh (local, fast)
# ---------------------------------------------------------------------------
tier2_search() {
  local zotero_library="$LITERATURE_DIR/zotero-library.json"

  if [ ! -f "$zotero_library" ]; then
    return 0
  fi

  # Find zotero-search.sh
  local zotero_script=""
  for candidate in \
    "$SCRIPT_DIR/../extensions/literature/scripts/zotero-search.sh" \
    ".claude/extensions/literature/scripts/zotero-search.sh"; do
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

  zotero_results=$("$zotero_script" --format=json --limit="$DISCOVER_LIMIT" \
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
")
    elif [ -n "$authors" ]; then
      authors_arr=$(python3 -c "import json, sys; print(json.dumps([sys.argv[1]]))" "$authors")
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

    if [ "$count" -ge "$DISCOVER_LIMIT" ]; then
      break
    fi
  done < <(echo "$zotero_results" | jq -c '.[]' 2>/dev/null)
}

# ---------------------------------------------------------------------------
# TIER 3: Search Semantic Scholar + Unpaywall/arXiv (online, slower)
# ---------------------------------------------------------------------------
tier3_search() {
  # Check if we already have enough results
  local current_count
  current_count=$(echo "$RESULTS" | jq 'length' 2>/dev/null || echo "0")
  if [ "$current_count" -ge "$DISCOVER_LIMIT" ]; then
    return 0
  fi

  local remaining=$(( DISCOVER_LIMIT - current_count ))

  # Build query string (join filtered terms with spaces)
  local query_string="${FILTERED_TERMS[*]}"
  local encoded_query
  encoded_query=$(urlencode "$query_string")

  local ss_url="https://api.semanticscholar.org/graph/v1/paper/search?query=${encoded_query}&fields=title,authors,year,openAccessPdf,externalIds&limit=10"

  local ss_results=""
  local curl_exit=0

  ss_results=$(curl -s --max-time 15 "$ss_url" 2>/dev/null) || curl_exit=$?

  if [ "$curl_exit" -ne 0 ] || [ -z "$ss_results" ]; then
    return 0
  fi

  # Check for API error
  local error_msg
  error_msg=$(echo "$ss_results" | jq -r '.error // ""' 2>/dev/null)
  if [ -n "$error_msg" ] && [ "$error_msg" != "null" ]; then
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
# Execute tiers (each fails independently)
# ---------------------------------------------------------------------------

# Tier 1: offline index
tier1_search 2>/dev/null || true

# Tier 2: Zotero
tier2_search 2>/dev/null || true

# Tier 3: Online APIs (only if we have fewer than limit results)
tier3_search 2>/dev/null || true

# ---------------------------------------------------------------------------
# Output results
# ---------------------------------------------------------------------------
final_count=$(echo "$RESULTS" | jq 'length' 2>/dev/null || echo "0")

if [ "$final_count" -eq 0 ]; then
  echo '[]'
  exit 1
fi

# Truncate to limit and output
echo "$RESULTS" | jq --argjson limit "$DISCOVER_LIMIT" '.[0:$limit]'
exit 0
