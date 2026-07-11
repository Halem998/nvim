#!/usr/bin/env bash
# cite-extract.sh — Extract citation claims from text for verification
#
# USAGE:
#   cite-extract.sh [OPTIONS] [FILE]
#   echo "text" | cite-extract.sh [OPTIONS]
#
# DESCRIPTION:
#   Detects citation patterns in text and outputs a JSON array of extracted
#   claims. Supports nine pattern families:
#
#     1. author_year       — Smith 2020, Smith and Jones 2020, Smith et al. 2020
#     2. author_paren_year — Smith (2020), Blackburn (2002), Jones et al. (2019)
#     3. parenthetical     — (Smith, 2020), (Smith & Jones, 2020), (Smith et al., 2020)
#     4. phrase_attribution— "according to X", "as shown by X", "X demonstrated"
#     5. theorem_attr      — "Theorem 3.2 (Author)", "by Lemma 2.1", "By Lemma 2.1"
#     6. direct_quote      — "quote" (Author, Year), "quote" — Author
#     7. numeric_bracket   — [42] (excludes markdown link syntax [text](url))
#     8. alpha_num_bracket — [Smith20], [ABC2023]
#     9. latex_cite        — \cite{key}, \cite[page]{key}
#
#   Confidence is hard-coded per pattern family (0.5–0.9).
#   Results are deduplicated by (line_number, source_text).
#
# OPTIONS:
#   --format=MODE         Output format: json (default) or pretty
#   --min-confidence=N    Minimum confidence threshold (default: 0.5, range: 0.0–1.0)
#   -h, --help            Show this help message
#
# EXIT CODES:
#   0  Results found and returned
#   1  Setup or validation error
#   2  No results matched

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

FORMAT="json"
MIN_CONF="0.5"
INPUT_FILE=""

show_usage() {
  local fd="${1:-2}"
  cat >&"$fd" << 'USAGE'
USAGE:
  cite-extract.sh [OPTIONS] [FILE]
  echo "text" | cite-extract.sh [OPTIONS]

DESCRIPTION:
  Detects citation patterns in text and outputs a JSON array of extracted
  claims. Supports nine pattern families:

    1. author_year       — Smith 2020, Smith and Jones 2020, Smith et al. 2020
    2. author_paren_year — Smith (2020), Blackburn (2002), Jones et al. (2019)
    3. parenthetical     — (Smith, 2020), (Smith & Jones, 2020)
    4. phrase_attribution— "according to X", "as shown by X"
    5. theorem_attr      — Theorem 3.2 (Author), by Lemma 2.1, By Lemma 2.1
    6. direct_quote      — "quote" (Author, Year)
    7. numeric_bracket   — [42] (excludes markdown links)
    8. alpha_num_bracket — [Smith20], [ABC2023]
    9. latex_cite        — \cite{key}, \cite[page]{key}

OPTIONS:
  --format=MODE         Output format: json (default) or pretty
  --min-confidence=N    Minimum confidence threshold (default: 0.5)
  -h, --help            Show this help message

EXIT CODES:
  0  Results found and returned
  1  Setup or validation error
  2  No results matched
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --format=*)
      FORMAT="${arg#--format=}"
      if [[ "$FORMAT" != "json" && "$FORMAT" != "pretty" ]]; then
        echo "Error: --format must be 'json' or 'pretty'" >&2
        exit 1
      fi
      ;;
    --min-confidence=*)
      MIN_CONF="${arg#--min-confidence=}"
      if ! echo "$MIN_CONF" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        echo "Error: --min-confidence must be a number in [0.0, 1.0]" >&2
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
      if [[ -n "$INPUT_FILE" ]]; then
        echo "Error: Multiple file arguments provided" >&2
        exit 1
      fi
      INPUT_FILE="$arg"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed. Install with your package manager." >&2
  exit 1
fi

if ! echo "test" | grep -qP 'test' 2>/dev/null; then
  echo "Error: grep with PCRE support (-P flag) is required." >&2
  echo "       Install GNU grep or ugrep with PCRE2 support." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Input resolution
# ---------------------------------------------------------------------------

TMPFILE=""
cleanup() {
  if [[ -n "$TMPFILE" && -f "$TMPFILE" ]]; then
    rm -f "$TMPFILE"
  fi
}
trap cleanup EXIT

if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
  fi
  WORK_FILE="$INPUT_FILE"
else
  TMPFILE="$(mktemp)"
  cat - > "$TMPFILE"
  WORK_FILE="$TMPFILE"
fi

# ---------------------------------------------------------------------------
# Pattern definitions
# ---------------------------------------------------------------------------
# Each entry: PATTERN_NAME|CONFIDENCE|GREP_FLAGS|REGEX
# grep flags: E=extended, P=PCRE, i=case-insensitive (combined as needed)

declare -a PATTERNS=(
  # author_year: Smith 2020, Smith and Jones 2020, Smith et al. 2020
  "author_year|0.9|P|[A-Z][a-z]+(( and | & )[A-Z][a-z]+|,? et al\.?)?,? (19|20)[0-9]{2}[a-z]?"

  # author_paren_year: Smith (2020), Blackburn (2002), Jones et al. (2019)
  "author_paren_year|0.9|P|[A-Z][a-z]+(( and | & )[A-Z][a-z]+|,? et al\.?)? \((19|20)[0-9]{2}[a-z]?\)"

  # parenthetical: (Smith, 2020), (Smith & Jones, 2020), (Smith et al., 2020)
  "parenthetical|0.9|P|\([A-Z][a-z]+(,? (and|&) [A-Z][a-z]+|,? et al\.?)?,? (19|20)[0-9]{2}[a-z]?(, p\.? ?[0-9]+)?\)"

  # phrase attribution (case-insensitive)
  "phrase_attribution|0.7|Pi|(according to|as (shown|argued|noted|claimed|demonstrated|stated|discussed|reported|suggested|proposed|described) (by|in))[^,\.;]{3,60}"

  # theorem/lemma with bracketed attribution: Theorem 3.2 (Author) or Lemma 2.1
  "theorem_attr_bracket|0.9|P|(Theorem|Lemma|Proposition|Corollary|Definition|Remark|Conjecture) [0-9]+(\.[0-9]+)* \([A-Z][a-z]"

  # theorem/lemma eponymous: by Lemma 2.1, By Theorem 3 (case-insensitive for sentence-initial)
  "theorem_attr_ref|0.7|Pi|(by|from|using|applying|via) (the )?(Theorem|Lemma|Proposition|Corollary|Remark) [0-9]+(\.[0-9]+)*"

  # direct quote with year citation: "quote" (Author, Year)
  "direct_quote_bracket|0.85|P|\"[^\"]{5,150}\" \([A-Z][a-z]+(,? (and|&) [A-Z][a-z]+|,? et al\.?)?,? (19|20)[0-9]{2}\)"

  # direct quote with em-dash attribution: "quote" — Author
  "direct_quote_dash|0.6|P|\"[^\"]{5,150}\" [—–] [A-Z][a-z]"

  # numeric bracket: [42] but not [42](url) (markdown link)
  "numeric_bracket|0.5|P|\[[0-9]{1,3}\](?!\()"

  # alpha-numeric bracket: [Smith20], [ABC2023]
  "alpha_num_bracket|0.7|P|\[[A-Z][a-zA-Z]{2,8}[0-9]{2,4}\]"

  # LaTeX \cite{key} and \cite[page]{key}
  "latex_cite|0.9|P|\\\\cite(\[[^\]]*\])?\{[^}]+\}"
)

# ---------------------------------------------------------------------------
# Extraction loop
# ---------------------------------------------------------------------------

ALL_RESULTS='[]'

for pattern_entry in "${PATTERNS[@]}"; do
  IFS='|' read -r pat_name confidence grep_flags regex <<< "$pattern_entry"

  # Build grep flags string
  grep_cmd_flags="-n"
  if [[ "$grep_flags" == *"P"* ]]; then
    grep_cmd_flags="${grep_cmd_flags}P"
  else
    grep_cmd_flags="${grep_cmd_flags}E"
  fi
  if [[ "$grep_flags" == *"i"* ]]; then
    grep_cmd_flags="${grep_cmd_flags}i"
  fi

  # Run grep, capturing line_number:matched_line pairs
  # grep returns exit code 1 when no matches — treat as empty, not error
  grep_output=""
  if grep_output="$(grep ${grep_cmd_flags} -- "$regex" "$WORK_FILE" 2>/dev/null)"; then
    :
  fi

  if [[ -z "$grep_output" ]]; then
    continue
  fi

  # Process each matched line
  while IFS= read -r match_line; do
    # Extract line number and content
    line_num="${match_line%%:*}"
    line_content="${match_line#*:}"

    # Skip if line number is not numeric
    if ! [[ "$line_num" =~ ^[0-9]+$ ]]; then
      continue
    fi

    # Extract the matched source_text by re-running grep -oP on the line
    source_text=""
    if [[ "$grep_flags" == *"i"* ]]; then
      source_text="$(echo "$line_content" | grep -oiP -- "$regex" 2>/dev/null | head -1 || true)"
    else
      source_text="$(echo "$line_content" | grep -oP -- "$regex" 2>/dev/null | head -1 || true)"
    fi

    if [[ -z "$source_text" ]]; then
      continue
    fi

    # Truncate claim to 200 chars
    claim="${line_content:0:200}"

    # Build JSON object and append to results
    result_obj="$(jq -n \
      --arg claim "$claim" \
      --arg source_text "$source_text" \
      --argjson line_number "$line_num" \
      --argjson confidence "$confidence" \
      --arg pattern_type "$pat_name" \
      '{claim: $claim, source_text: $source_text, line_number: $line_number, confidence: $confidence, pattern_type: $pattern_type}')"

    ALL_RESULTS="$(echo "$ALL_RESULTS" | jq --argjson obj "$result_obj" '. + [$obj]')"

  done <<< "$grep_output"
done

# ---------------------------------------------------------------------------
# Deduplication, confidence filtering, and sorting
# ---------------------------------------------------------------------------

FINAL_RESULTS="$(echo "$ALL_RESULTS" | jq \
  --argjson min_conf "$MIN_CONF" \
  '[.[] | select(.confidence >= $min_conf)] | sort_by(.line_number) | unique_by([.line_number, .source_text])')"

# ---------------------------------------------------------------------------
# Check for no results
# ---------------------------------------------------------------------------

RESULT_COUNT="$(echo "$FINAL_RESULTS" | jq 'length')"

if [[ "$RESULT_COUNT" -eq 0 ]]; then
  if [[ "$FORMAT" == "pretty" ]]; then
    echo "No citation patterns found."
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

if [[ "$FORMAT" == "pretty" ]]; then
  echo ""
  printf "%-6s  %-5s  %-20s  %-40s  %s\n" "LINE" "CONF" "TYPE" "SOURCE" "CLAIM"
  printf "%s\n" "$(printf '%0.s-' {1..120})"

  for i in $(seq 0 $((RESULT_COUNT - 1))); do
    local_line="$(echo "$FINAL_RESULTS" | jq -r ".[$i].line_number")"
    local_conf="$(echo "$FINAL_RESULTS" | jq -r ".[$i].confidence")"
    local_type="$(echo "$FINAL_RESULTS" | jq -r ".[$i].pattern_type")"
    local_source="$(echo "$FINAL_RESULTS" | jq -r ".[$i].source_text")"
    local_claim="$(echo "$FINAL_RESULTS" | jq -r ".[$i].claim")"

    if [[ ${#local_type} -gt 20 ]]; then
      local_type="${local_type:0:17}..."
    fi
    if [[ ${#local_source} -gt 40 ]]; then
      local_source="${local_source:0:37}..."
    fi
    if [[ ${#local_claim} -gt 60 ]]; then
      local_claim="${local_claim:0:57}..."
    fi

    printf "%-6s  %-5s  %-20s  %-40s  %s\n" \
      "$local_line" "$local_conf" "$local_type" "$local_source" "$local_claim"
  done

  printf "\nFound %d citation(s).\n" "$RESULT_COUNT"
  exit 0
fi
