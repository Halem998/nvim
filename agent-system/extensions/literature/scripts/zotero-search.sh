#!/usr/bin/env bash
# zotero-search.sh — Search a Better BibTeX CSL-JSON export by keyword
#
# USAGE:
#   zotero-search.sh [OPTIONS] QUERY [QUERY...]
#
# DESCRIPTION:
#   Searches a Zotero Better BibTeX CSL-JSON library by keyword using
#   weighted multi-field matching in a single jq pass, then verifies
#   PDF paths via bash post-processing.
#
#   Scoring is additive with OR semantics across query terms:
#     title    +3 per matching term
#     keyword  +2 per matching term
#     abstract +1 per matching term
#     author   +1 per matching term
#
# OPTIONS:
#   --limit=N       Maximum results to return (default: 10)
#   --format=MODE   Output format: json (default) or pretty
#   -h, --help      Show this help message
#
# ENVIRONMENT:
#   ZOTERO_LIBRARY  Path to CSL-JSON library file
#                   Falls back to $LITERATURE_DIR/zotero-library.json
#                   then ~/Projects/Literature/zotero-library.json
#
# EXIT CODES:
#   0  Results found and returned
#   1  Library file not found (setup instructions printed)
#   2  No results matched the query

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

LIMIT=10
FORMAT="json"
QUERY_TERMS=()

show_usage() {
  local fd="${1:-2}"
  cat >&"$fd" << 'USAGE'
USAGE:
  zotero-search.sh [OPTIONS] QUERY [QUERY...]

DESCRIPTION:
  Searches a Zotero Better BibTeX CSL-JSON library by keyword using
  weighted multi-field matching in a single jq pass, then verifies
  PDF paths via bash post-processing.

  Scoring is additive with OR semantics across query terms:
    title    +3 per matching term
    keyword  +2 per matching term
    abstract +1 per matching term
    author   +1 per matching term

OPTIONS:
  --limit=N       Maximum results to return (default: 10)
  --format=MODE   Output format: json (default) or pretty
  -h, --help      Show this help message

ENVIRONMENT:
  ZOTERO_LIBRARY  Path to CSL-JSON library file
                  Falls back to $LITERATURE_DIR/zotero-library.json
                  then ~/Projects/Literature/zotero-library.json

EXIT CODES:
  0  Results found and returned
  1  Library file not found (setup instructions printed)
  2  No results matched the query
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --limit=*)
      LIMIT="${arg#--limit=}"
      if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [[ "$LIMIT" -lt 1 ]]; then
        echo "Error: --limit must be a positive integer" >&2
        exit 1
      fi
      ;;
    --format=*)
      FORMAT="${arg#--format=}"
      if [[ "$FORMAT" != "json" && "$FORMAT" != "pretty" ]]; then
        echo "Error: --format must be 'json' or 'pretty'" >&2
        exit 1
      fi
      ;;
    -h|--help)
      show_usage 1
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $arg" >&2
      show_usage
      exit 1
      ;;
    *)
      QUERY_TERMS+=("$arg")
      ;;
  esac
done

# Require at least one query term
if [[ ${#QUERY_TERMS[@]} -eq 0 ]]; then
  echo "Error: No query terms provided" >&2
  echo "" >&2
  show_usage
  exit 1
fi

# ---------------------------------------------------------------------------
# Library path resolution (3-tier fallback chain)
# ---------------------------------------------------------------------------

resolve_library_path() {
  # Tier 1: ZOTERO_LIBRARY env var
  if [[ -n "${ZOTERO_LIBRARY:-}" ]]; then
    echo "$ZOTERO_LIBRARY"
    return
  fi

  # Tier 2: $LITERATURE_DIR/zotero-library.json
  if [[ -n "${LITERATURE_DIR:-}" ]]; then
    echo "${LITERATURE_DIR}/zotero-library.json"
    return
  fi

  # Tier 3: ~/Projects/Literature/zotero-library.json
  echo "${HOME}/Projects/Literature/zotero-library.json"
}

LIBRARY_PATH="$(resolve_library_path)"

# ---------------------------------------------------------------------------
# Library file existence check
# ---------------------------------------------------------------------------

if [[ ! -f "$LIBRARY_PATH" ]]; then
  cat >&2 << SETUP_INSTRUCTIONS

Error: Zotero library not found at: $LIBRARY_PATH

To set up Zotero CSL-JSON export:

1. Install the Better BibTeX plugin for Zotero:
   https://retorque.re/zotero-better-bibtex/

2. In Zotero, go to:
   File -> Export Library...

3. Choose format: "Better CSL JSON"
   Check "Keep updated" for automatic re-export.

4. Save to one of:
   - The path in \$ZOTERO_LIBRARY environment variable
   - \${LITERATURE_DIR}/zotero-library.json (if \$LITERATURE_DIR is set)
   - ~/Projects/Literature/zotero-library.json (default)

Or set the ZOTERO_LIBRARY environment variable to your export path:
   export ZOTERO_LIBRARY=/path/to/your/library.json

SETUP_INSTRUCTIONS
  exit 1
fi

# ---------------------------------------------------------------------------
# Query term preprocessing
# ---------------------------------------------------------------------------

# Lowercase all terms, filter stop words and short terms
STOP_WORDS="a an the in on at of to and or for by with from"

filter_terms() {
  local terms=()
  for raw_term in "$@"; do
    local term
    term="$(echo "$raw_term" | tr '[:upper:]' '[:lower:]')"
    # Skip terms shorter than 3 characters
    if [[ ${#term} -lt 3 ]]; then
      continue
    fi
    # Skip stop words
    local is_stop=false
    for stop in $STOP_WORDS; do
      if [[ "$term" == "$stop" ]]; then
        is_stop=true
        break
      fi
    done
    if [[ "$is_stop" == "false" ]]; then
      terms+=("$term")
    fi
  done
  printf '%s\n' "${terms[@]}"
}

mapfile -t FILTERED_TERMS < <(filter_terms "${QUERY_TERMS[@]}")

if [[ ${#FILTERED_TERMS[@]} -eq 0 ]]; then
  echo "Error: No meaningful query terms after filtering stop words and short terms" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Escape regex special characters in query terms
# ---------------------------------------------------------------------------

escape_for_jq_regex() {
  # Escape characters that are special in jq's PCRE regex: . * + ? ^ $ { } [ ] | ( ) \
  echo "$1" | sed 's/[.+?^${}[\]|()\\]/\\&/g'
}

# Build jq array of escaped terms
build_jq_terms_array() {
  local jq_array='['
  local first=true
  for term in "${FILTERED_TERMS[@]}"; do
    local escaped
    escaped="$(escape_for_jq_regex "$term")"
    if [[ "$first" == "true" ]]; then
      jq_array+="\"${escaped}\""
      first=false
    else
      jq_array+=",\"${escaped}\""
    fi
  done
  jq_array+=']'
  echo "$jq_array"
}

TERMS_ARRAY="$(build_jq_terms_array)"

# ---------------------------------------------------------------------------
# Single-pass jq scoring and output
# ---------------------------------------------------------------------------
# CSL-JSON structure:
#   citation-key          string
#   title                 string
#   author                [{family, given}]
#   issued.date-parts     [[year, month, day]]
#   keyword               string (comma-separated tags)
#   abstract              string
#   attachments           [{path, ...}] (Better BibTeX attachment info)
#   attachment            string (alternate single attachment field)
#   PDF                   string (alternate PDF field)

JQ_PROGRAM='
def score_field(text; weight; terms):
  if text == null or text == "" then 0
  else
    (text | ascii_downcase) as $ltext |
    reduce terms[] as $term (
      0;
      if ($ltext | test($term; "i")) then . + weight else . end
    )
  end;

def author_string(authors):
  if authors == null then ""
  else
    [ authors[] | (.family // "") + (if .given then ", " + .given else "" end) ] | join("; ")
  end;

def year_of(entry):
  entry.issued["date-parts"][0][0] // null;

def abstract_snippet(abstract):
  if abstract == null or abstract == "" then ""
  elif (abstract | length) <= 200 then abstract
  else (abstract[0:200]) + "..."
  end;

def pdf_candidates(entry):
  [
    (entry.attachments // [] | .[] | .path // empty),
    (entry.attachment // empty),
    (entry.PDF // empty)
  ];

$terms as $t |
.[] |
  (score_field(.title; 3; $t) +
   score_field(.keyword; 2; $t) +
   score_field(.abstract; 1; $t) +
   score_field(author_string(.author); 1; $t)) as $score |
  select($score > 0) |
  {
    citation_key: .["citation-key"],
    title: (.title // ""),
    authors: author_string(.author),
    year: year_of(.),
    score: $score,
    pdf_paths: pdf_candidates(.),
    abstract_snippet: abstract_snippet(.abstract)
  }
'

# Run jq scoring pass
JQ_RESULTS="$(jq --argjson terms "$TERMS_ARRAY" "$JQ_PROGRAM" "$LIBRARY_PATH" 2>&1)"

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to parse library file: $JQ_RESULTS" >&2
  exit 1
fi

# Sort by score descending and apply limit
SORTED_RESULTS="$(echo "$JQ_RESULTS" | jq -s "sort_by(-.score) | .[:${LIMIT}]")"

# ---------------------------------------------------------------------------
# PDF path verification post-pass
# ---------------------------------------------------------------------------

verify_pdf_paths() {
  local results="$1"
  local count
  count="$(echo "$results" | jq 'length')"

  local verified='[]'
  for i in $(seq 0 $((count - 1))); do
    local entry
    entry="$(echo "$results" | jq ".[$i]")"

    # Extract pdf_paths array
    local raw_paths
    mapfile -t raw_paths < <(echo "$entry" | jq -r '.pdf_paths[]? // empty')

    # Verify each path exists
    local valid_paths='[]'
    for path in "${raw_paths[@]}"; do
      if [[ -n "$path" && -f "$path" ]]; then
        valid_paths="$(echo "$valid_paths" | jq --arg p "$path" '. + [$p]')"
      fi
    done

    # Inject verified paths back
    entry="$(echo "$entry" | jq --argjson vp "$valid_paths" '.pdf_paths = $vp')"
    verified="$(echo "$verified" | jq --argjson e "$entry" '. + [$e]')"
  done

  echo "$verified"
}

FINAL_RESULTS="$(verify_pdf_paths "$SORTED_RESULTS")"

# ---------------------------------------------------------------------------
# Check for no results
# ---------------------------------------------------------------------------

RESULT_COUNT="$(echo "$FINAL_RESULTS" | jq 'length')"
if [[ "$RESULT_COUNT" -eq 0 ]]; then
  if [[ "$FORMAT" == "pretty" ]]; then
    echo "No results found for: ${QUERY_TERMS[*]}"
  else
    echo "[]"
  fi
  exit 2
fi

# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

if [[ "$FORMAT" == "json" ]]; then
  echo "$FINAL_RESULTS" | jq '.'
  exit 0
fi

# Pretty format: human-readable table
if [[ "$FORMAT" == "pretty" ]]; then
  echo ""
  printf "%-6s  %-50s  %-30s  %-6s  %-5s\n" "SCORE" "TITLE" "AUTHORS" "YEAR" "PDFS"
  printf "%s\n" "$(printf '%0.s-' {1..110})"

  RESULT_COUNT="$(echo "$FINAL_RESULTS" | jq 'length')"
  for i in $(seq 0 $((RESULT_COUNT - 1))); do
    local_score="$(echo "$FINAL_RESULTS" | jq -r ".[$i].score")"
    local_title="$(echo "$FINAL_RESULTS" | jq -r ".[$i].title")"
    local_authors="$(echo "$FINAL_RESULTS" | jq -r ".[$i].authors")"
    local_year="$(echo "$FINAL_RESULTS" | jq -r ".[$i].year // \"N/A\"")"
    local_pdfs="$(echo "$FINAL_RESULTS" | jq -r ".[$i].pdf_paths | length")"
    local_key="$(echo "$FINAL_RESULTS" | jq -r ".[$i].citation_key")"
    local_snippet="$(echo "$FINAL_RESULTS" | jq -r ".[$i].abstract_snippet")"

    # Truncate long strings
    if [[ ${#local_title} -gt 50 ]]; then
      local_title="${local_title:0:47}..."
    fi
    if [[ ${#local_authors} -gt 30 ]]; then
      local_authors="${local_authors:0:27}..."
    fi

    printf "%-6s  %-50s  %-30s  %-6s  %-5s\n" \
      "$local_score" "$local_title" "$local_authors" "$local_year" "$local_pdfs"
    printf "       [%s]\n" "$local_key"
    if [[ -n "$local_snippet" ]]; then
      printf "       %s\n" "${local_snippet:0:100}"
    fi
    printf "\n"
  done

  printf "Found %d result(s) for: %s\n" "$RESULT_COUNT" "${QUERY_TERMS[*]}"
  exit 0
fi
