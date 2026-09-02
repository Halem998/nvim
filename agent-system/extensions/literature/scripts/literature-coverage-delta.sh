#!/usr/bin/env bash
# literature-coverage-delta.sh - Topic-scoped coverage-delta guard
#
# Usage:
#   literature-coverage-delta.sh --query "<task description>" [--top-n N]
#
# Purpose:
#   Computes whether the global Literature/ corpus holds topic-relevant documents that the
#   per-repo sub-index (specs/literature-index.json) never references, even though the
#   sub-index itself clears the absolute sparsity floor (LITERATURE_SPARSE_THRESHOLD). This is
#   a distinct failure mode from the existing sparse-coverage mechanism: a sub-index can be
#   internally healthy (enough entries, all resolving) while topically relevant global sources
#   remain invisible because they were never added to it in the first place.
#
#   The firing condition is COMPOUND and topic-scoped (never a bare ratio, which would fire on
#   nearly every repo and become noise):
#     1. Cheap pre-filter: global_docs - subindex_docs >= LITERATURE_COVERAGE_GAP_MIN. Its only
#        job is to skip the (more expensive) keyword pass when the global corpus is small or the
#        sub-index is already comprehensive.
#     2. Actionable trigger: at least one global top-level document matches the query's filtered
#        terms (same Tier 1 matcher literature-discover.sh uses, via literature-term-match.sh)
#        and is absent from the sub-index's doc-key set.
#   This script always reports the true computed counts; callers (literature-lit-flag-resolve.sh,
#   literature-briefing.sh) apply their own comparison against LITERATURE_COVERAGE_DELTA_THRESHOLD
#   to decide whether to act.
#
# Output (stdout, exactly one line, always printed, never fatal):
#   delta_checked=true|false delta_gap=N global_docs=G subindex_docs=S delta_candidates=M
#   candidates=id1,id2,... candidate_titles=["Title A","Title B",...]
#
#   - candidates is a comma-joined list of doc keys, bounded to --top-n (default 5). The
#     UNTRUNCATED total match count is always delta_candidates.
#   - candidate_titles is a compact JSON array (title strings are JSON-encoded, not raw, since
#     titles may contain spaces/commas that would break a flat delimited field) in the same
#     order and bound as candidates.
#   - delta_checked=false means the compound condition was never evaluated at all (missing
#     index files, unreadable JSON, no --query, empty filtered-term list) -- it is NOT the same
#     as "checked and found zero". A caller must never treat delta_checked=false as a verified
#     absence of a gap (see the implementation plan's Decision D6). When delta_checked=false,
#     every numeric field is reported as 0 and candidates/candidate_titles are empty -- this is
#     a placeholder shape, not a real measurement.
#
# Chunk-inflation note (the single most load-bearing implementation detail in this script): the
# global index's `.entries` array mixes top-level documents (parent_doc == null) with their
# chunk children (parent_doc == "<id>") in one flat array. global_docs and every candidate
# considered by the keyword pass below are filtered to `select(.parent_doc == null or
# .parent_doc == "")` -- raw `.entries | length` would overstate the gap by roughly 2x (measured
# in this environment: 414 total entries, 204 top-level documents).
#
# Environment:
#   LITERATURE_DIR                       Global Literature/ repo root
#                                         (default: ~/Projects/Literature).
#   LITERATURE_COVERAGE_GAP_MIN          Minimum global_docs - subindex_docs gap before the
#                                         keyword pass runs at all (default: 25). Cheap
#                                         pre-filter only -- never fires the guard on its own.
#   LITERATURE_COVERAGE_DELTA_THRESHOLD  Minimum delta_candidates callers treat as actionable
#                                         (default: 1). Not applied inside this script -- it
#                                         always reports the true count; callers compare.
#
# Fail-open contract: this script NEVER exits non-zero and NEVER aborts a --lit run. Any failure
# mode (missing --query, missing global index, missing sub-index, unreadable JSON, empty
# filtered-term list) degrades to `delta_checked=false ...` on stdout plus a stderr rationale,
# exit 0 in every case.

set -uo pipefail
# Deliberately NOT `set -e` -- see the fail-open contract above. Every potentially-failing
# command below is checked explicitly rather than allowed to abort the script.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
SUB_INDEX="$PROJECT_ROOT/specs/literature-index.json"
GLOBAL_INDEX="$LIT_DIR/index.json"
LITERATURE_COVERAGE_GAP_MIN="${LITERATURE_COVERAGE_GAP_MIN:-25}"
LITERATURE_COVERAGE_DELTA_THRESHOLD="${LITERATURE_COVERAGE_DELTA_THRESHOLD:-1}"

query=""
top_n=5

while [ $# -gt 0 ]; do
  case "$1" in
    --query)
      query="${2:-}"
      shift 2
      ;;
    --top-n)
      top_n="${2:-5}"
      shift 2
      ;;
    *)
      echo "Warning: unrecognized argument '$1' ignored" >&2
      shift
      ;;
  esac
done

# --- fail_open: print the not-computed placeholder line and exit 0 ---
fail_open() {
  local reason="$1"
  echo "Rationale: coverage-delta not computed -- ${reason}" >&2
  echo "delta_checked=false delta_gap=0 global_docs=0 subindex_docs=0 delta_candidates=0 candidates= candidate_titles=[]"
  exit 0
}

if [ -z "$query" ]; then
  fail_open "no --query provided"
fi

if [ ! -f "$GLOBAL_INDEX" ]; then
  fail_open "global index not found at $GLOBAL_INDEX"
fi

if [ ! -f "$SUB_INDEX" ]; then
  fail_open "sub-index not found at $SUB_INDEX"
fi

# --- Count global top-level documents only (never raw `.entries | length` -- see chunk-
# inflation note above) ---
global_docs=$(jq '[.entries[] | select(.parent_doc == null or .parent_doc == "")] | length' "$GLOBAL_INDEX" 2>/dev/null) || global_docs=""
if [ -z "$global_docs" ] || ! [[ "$global_docs" =~ ^[0-9]+$ ]]; then
  fail_open "global index at $GLOBAL_INDEX is unreadable or malformed"
fi

# --- Sub-index entry count ---
subindex_docs=$(jq '.entries | length' "$SUB_INDEX" 2>/dev/null) || subindex_docs=""
if [ -z "$subindex_docs" ] || ! [[ "$subindex_docs" =~ ^[0-9]+$ ]]; then
  fail_open "sub-index at $SUB_INDEX is unreadable or malformed"
fi

# --- D1 half 1: cheap pre-filter ---
delta_gap=$(( global_docs - subindex_docs ))
if [ "$delta_gap" -lt 0 ]; then
  delta_gap=0
fi

if [ "$delta_gap" -lt "$LITERATURE_COVERAGE_GAP_MIN" ]; then
  echo "Rationale: delta_gap=${delta_gap} below LITERATURE_COVERAGE_GAP_MIN=${LITERATURE_COVERAGE_GAP_MIN}; skipping the keyword pass (cheap pre-filter -- the global corpus is not materially larger than the sub-index, or the sub-index is already comprehensive)." >&2
  echo "delta_checked=true delta_gap=${delta_gap} global_docs=${global_docs} subindex_docs=${subindex_docs} delta_candidates=0 candidates= candidate_titles=[]"
  exit 0
fi

# --- D1 half 2: keyword-matched actionable trigger ---
# shellcheck source=literature-term-match.sh
source "$SCRIPT_DIR/literature-term-match.sh"

mapfile -t FILTERED_TERMS < <(filter_terms "$query")
FILTERED_TERM_COUNT="${#FILTERED_TERMS[@]}"

if [ "$FILTERED_TERM_COUNT" -eq 0 ]; then
  fail_open "no meaningful search terms after filtering stop words from --query '${query}'"
fi

# Sub-index doc-key set. The sub-index's own entries are already keyed by .doc_id verbatim
# (mirrors literature-lit-flag-resolve.sh / literature-briefing.sh's identical
# `.entries[].doc_id` reads) -- no .id//.doc_id tolerance needed on this side.
declare -A SUB_KEYS=()
while IFS= read -r key; do
  [ -n "$key" ] && SUB_KEYS["$key"]=1
done < <(jq -r '.entries[].doc_id // empty' "$SUB_INDEX" 2>/dev/null)

candidate_ids=()
candidate_titles=()
delta_candidates=0

# Caveat (display-fidelity only, matching does not change): jq's @tsv escapes a literal tab,
# backslash, or newline *within* a field as \t / \\ / \n so `IFS=$'\t' read` below always splits
# correctly, but this means `title` (and therefore a stdout `candidate_titles` entry) shows the
# jq-escaped form rather than the raw character for such a title -- cosmetic only, since
# term_matches() does substring comparison on this same string either way, so selection cannot be
# affected. Zero top-level titles/keywords in the live corpus contain such a character today.
# Optional future refinement (not implemented here): re-fetch raw titles only for the bounded
# top-n output rows via a second, cheap per-row jq call, rather than for the full unbounded pass.
while IFS=$'\t' read -r doc_id title keywords; do
  # A blank line (all three fields empty -- the only way an all-empty record can surface from the
  # @tsv feeder below) falls through to the existing empty-doc_id skip immediately below; no
  # separate "$entry = null" guard is reachable or needed with this record shape.
  if [ -z "$doc_id" ]; then
    continue
  fi
  if [ -n "${SUB_KEYS[$doc_id]:-}" ]; then
    continue  # already referenced by the sub-index -- not a coverage gap
  fi

  # Same match rule as literature-discover.sh's Tier 1 (title/keywords, >= 2 distinct hits when
  # the filtered term count exceeds MULTI_TERM_MATCH_THRESHOLD, accept-on-first-hit otherwise).
  matched=false
  if [ "$FILTERED_TERM_COUNT" -gt "$MULTI_TERM_MATCH_THRESHOLD" ]; then
    hit_count=0
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
    delta_candidates=$(( delta_candidates + 1 ))
    if [ "${#candidate_ids[@]}" -lt "$top_n" ]; then
      candidate_ids+=("$doc_id")
      candidate_titles+=("$title")
    fi
  fi
done < <(jq -r '.entries[] | select(.parent_doc == null or .parent_doc == "") | [(.id // .doc_id // ""), (.title // ""), ((.keywords // []) | join(" "))] | @tsv' "$GLOBAL_INDEX" 2>/dev/null)

candidates_csv=$(IFS=,; echo "${candidate_ids[*]:-}")

if [ "${#candidate_titles[@]}" -eq 0 ]; then
  candidate_titles_json="[]"
else
  candidate_titles_json=$(printf '%s\n' "${candidate_titles[@]}" | jq -R . | jq -s -c . 2>/dev/null) || candidate_titles_json="[]"
fi

echo "Rationale: delta_gap=${delta_gap} (>= LITERATURE_COVERAGE_GAP_MIN=${LITERATURE_COVERAGE_GAP_MIN}); keyword pass found ${delta_candidates} topic-matched candidate(s) absent from the sub-index (top ${top_n} bounded in output; LITERATURE_COVERAGE_DELTA_THRESHOLD=${LITERATURE_COVERAGE_DELTA_THRESHOLD})." >&2
echo "delta_checked=true delta_gap=${delta_gap} global_docs=${global_docs} subindex_docs=${subindex_docs} delta_candidates=${delta_candidates} candidates=${candidates_csv} candidate_titles=${candidate_titles_json}"
exit 0
