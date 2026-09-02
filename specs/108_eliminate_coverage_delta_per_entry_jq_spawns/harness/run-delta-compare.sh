#!/usr/bin/env bash
# run-delta-compare.sh - Task 108 equivalence harness
#
# Runs a given copy of literature-coverage-delta.sh (+ its sourced
# literature-term-match.sh) against the LIVE ~/Projects/Literature/index.json,
# with an isolated 2-entry fake sub-index (so delta_gap clears
# LITERATURE_COVERAGE_GAP_MIN), for a fixed set of queries, with --top-n 1000
# so the FULL unbounded candidate list is captured (not the bounded top-n
# default). Captures wall time, the stdout summary line, and the sorted
# candidate-id list per query into $OUT_DIR.
#
# Usage:
#   run-delta-compare.sh <script-copy-root> <output-dir>
#
# <script-copy-root> must contain fakeroot/scripts/literature-coverage-delta.sh
# (which sources literature-term-match.sh from the same directory) and
# specs/literature-index.json (the isolated fake sub-index) -- i.e. it is one
# of harness/before or harness/after.

set -uo pipefail

SCRIPT_ROOT="${1:?usage: run-delta-compare.sh <script-copy-root> <output-dir>}"
OUT_DIR="${2:?usage: run-delta-compare.sh <script-copy-root> <output-dir>}"
GUARD="$SCRIPT_ROOT/fakeroot/scripts/literature-coverage-delta.sh"

mkdir -p "$OUT_DIR"

if [ ! -f "$GUARD" ]; then
  echo "ERROR: guard script not found at $GUARD" >&2
  exit 1
fi

# Query set: 5 required queries from the research report (covering both
# MULTI_TERM_MATCH_THRESHOLD branches) plus 2 deliberately non-ASCII-title
# targeted queries for direct Phase 4 divergence coverage.
declare -A QUERIES=(
  [q1-modal-10term]="modal logic temporal completeness axiomatization graphs games monadic theory canonicity"
  [q2-erdos-graph]="erdos graph theory"
  [q3-since-until]="since until tense operator"
  [q4-quantum-field]="quantum field theory renormalization"
  [q5-fmt-ehrenfeucht]="finite model theory ehrenfeucht fraisse games composition"
  [q6-nonascii-buchi]="buchi automata"
  [q7-nonascii-erdos-title]="erdos renyi random"
)

SUMMARY="$OUT_DIR/SUMMARY.tsv"
echo -e "query_key\tquery_text\twall_seconds\tdelta_checked\tdelta_gap\tglobal_docs\tsubindex_docs\tdelta_candidates" > "$SUMMARY"

for key in "${!QUERIES[@]}"; do
  q="${QUERIES[$key]}"
  stdout_file="$OUT_DIR/${key}.stdout.txt"
  stderr_file="$OUT_DIR/${key}.stderr.txt"
  ids_file="$OUT_DIR/${key}.candidate-ids.sorted.txt"
  time_file="$OUT_DIR/${key}.time.txt"

  start_ns=$(date +%s%N)
  "$GUARD" --query "$q" --top-n 1000 >"$stdout_file" 2>"$stderr_file"
  end_ns=$(date +%s%N)
  wall_seconds=$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e - s) / 1000000000 }')
  echo "$wall_seconds" > "$time_file"

  line=$(cat "$stdout_file")
  # Parse the fixed-shape stdout line by whitespace-splitting into its first 6
  # space-free fields (candidate_titles, the 7th/last field, is the only field
  # that itself contains spaces -- a JSON array of title strings -- so it is
  # captured wholesale into $_rest and never needs parsing here). Deliberately
  # NOT done via `grep -oE 'candidates=[^ ]*'`: that pattern also matches the
  # embedded "candidates=107" substring inside "delta_candidates=107",
  # corrupting the id list with a spurious "107" entry.
  read -r _dc _dg _gd _sd _dcand _cand _rest <<< "$line"
  delta_checked="${_dc#delta_checked=}"
  delta_gap="${_dg#delta_gap=}"
  global_docs="${_gd#global_docs=}"
  subindex_docs="${_sd#subindex_docs=}"
  delta_candidates="${_dcand#delta_candidates=}"
  candidates="${_cand#candidates=}"

  # Sorted candidate-id list (order-independent comparison target; a separate
  # raw/unsorted capture is not needed since the loop is a single linear pass
  # over the same jq-ordered stream in both BEFORE and AFTER).
  if [ -n "$candidates" ]; then
    echo "$candidates" | tr ',' '\n' | sort > "$ids_file"
  else
    : > "$ids_file"
  fi

  echo -e "${key}\t${q}\t${wall_seconds}\t${delta_checked}\t${delta_gap}\t${global_docs}\t${subindex_docs}\t${delta_candidates}" >> "$SUMMARY"
done

echo "Harness run complete. Summary: $SUMMARY" >&2
cat "$SUMMARY" >&2
