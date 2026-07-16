#!/usr/bin/env bash
# events-query.sh - Shared reader/filter/aggregate helper for the unified specs/events.jsonl store
#
# Usage:
#   events-query.sh [--session ID] [--task N] [--category CAT] [--event-type TYPE] \
#     [--checkpoint NAME] [--since ISO8601] [--until ISO8601] [--repo NAME] \
#     [--format jsonl|json-array|summary-counts]
#
# "repo" (scope 5) is NEVER a stored field -- it is derived at query time from the nullable
# `cwd` field as basename(cwd) (e.g. cwd "/home/user/.config/nvim" -> repo "nvim"). This is a
# deliberate simplification of "basename of the git toplevel for that cwd": a per-row git
# invocation would be inconsistent with this script's native-jq streaming-filter design, and in
# practice the cwd captured by the events hooks is already the invoking repo root. Rows with
# cwd: null (pre-scope-5 rows, or call sites with no reliable cwd source) derive repo: null and
# are tolerated everywhere, never erroring.
#
# Filters the specs/events.jsonl stream using native jq (jq parses a stream of concatenated
# JSON documents directly -- no --slurp is used for the line-filtering step itself; --slurp is
# used only afterward, to collect the already-filtered lines for json-array/summary-counts
# output). Tolerates an absent specs/events.jsonl: returns an empty result set and exits 0
# (never an error).
#
# See context/formats/events-format.md for the full field contract and
# context/schemas/events-schema.json for the formal JSON Schema.
#
# Exit codes:
#   0 - Success (even when the result set is empty or the store does not exist)
#   1 - Error (invalid arguments)
#
# Outputs:
#   stdout: matching events in the requested --format
#   stderr: diagnostic/error messages

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: events-query.sh [--session ID] [--task N] [--category CAT] [--event-type TYPE] \
  [--checkpoint NAME] [--since ISO8601] [--until ISO8601] [--repo NAME] \
  [--format jsonl|json-array|summary-counts]

Filters:
  --session ID        Match session_id exactly
  --task N            Match task (bare integer)
  --category CAT      Match category (deviation|blocker|milestone|success)
  --event-type TYPE   Match event_type exactly
  --checkpoint NAME   Match checkpoint exactly
  --since ISO8601     Only events with timestamp >= this value (lexicographic ISO 8601 compare)
  --until ISO8601     Only events with timestamp <= this value (lexicographic ISO 8601 compare)
  --repo NAME         Match the DERIVED repo (basename of cwd) exactly; rows with cwd: null
                       never match a non-empty --repo filter

Output:
  --format jsonl          One compact JSON object per line (default), each augmented with a
                           derived "repo" field (see above; never stored, always computed)
  --format json-array     A single JSON array of matching events, same "repo" augmentation
  --format summary-counts Aggregate counts grouped by category, event_type, and repo
USAGE
  exit 1
}

# --- Argument parsing ---
f_session=""
f_task=""
f_category=""
f_event_type=""
f_checkpoint=""
f_since=""
f_until=""
f_repo=""
format="jsonl"

while [ $# -gt 0 ]; do
  case "$1" in
    --session) f_session="${2:-}"; shift 2 ;;
    --task) f_task="${2:-}"; shift 2 ;;
    --category) f_category="${2:-}"; shift 2 ;;
    --event-type) f_event_type="${2:-}"; shift 2 ;;
    --checkpoint) f_checkpoint="${2:-}"; shift 2 ;;
    --since) f_since="${2:-}"; shift 2 ;;
    --until) f_until="${2:-}"; shift 2 ;;
    --repo) f_repo="${2:-}"; shift 2 ;;
    --format) format="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

case "$format" in
  jsonl|json-array|summary-counts) ;;
  *)
    echo "error: invalid --format '$format' (must be one of: jsonl|json-array|summary-counts)" >&2
    exit 1
    ;;
esac

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
EVENTS_FILE="$PROJECT_ROOT/specs/events.jsonl"

# --- Tolerate an absent store: empty result set, exit 0 ---
if [ ! -f "$EVENTS_FILE" ]; then
  case "$format" in
    jsonl) : ;; # no output
    json-array) echo "[]" ;;
    summary-counts) jq -c -n '{total_events: 0, by_category: {}, by_event_type: {}}' ;;
  esac
  exit 0
fi

# --- Filter the JSONL stream natively (no --slurp for this step) ---
# "repo" is derived here (basename of cwd; null when cwd is null) BEFORE filtering, so --repo
# can select on it and every downstream output format carries the same computed field.
filtered=$(jq -c \
  --arg session "$f_session" \
  --arg task "$f_task" \
  --arg category "$f_category" \
  --arg event_type "$f_event_type" \
  --arg checkpoint "$f_checkpoint" \
  --arg since "$f_since" \
  --arg until_ "$f_until" \
  --arg repo "$f_repo" \
  '. + {repo: (if (.cwd // null) == null then null else (.cwd | rtrimstr("/") | split("/") | last) end)}
  | select(
    ($session == "" or .session_id == $session) and
    ($task == "" or ((.task // "" ) | tostring) == $task) and
    ($category == "" or .category == $category) and
    ($event_type == "" or .event_type == $event_type) and
    ($checkpoint == "" or .checkpoint == $checkpoint) and
    ($since == "" or ((.timestamp // "") >= $since)) and
    ($until_ == "" or ((.timestamp // "") <= $until_)) and
    ($repo == "" or .repo == $repo)
  )' "$EVENTS_FILE")

# --- Emit in the requested format ---
case "$format" in
  jsonl)
    if [ -n "$filtered" ]; then
      printf '%s\n' "$filtered"
    fi
    ;;
  json-array)
    if [ -n "$filtered" ]; then
      printf '%s\n' "$filtered" | jq -s -c '.'
    else
      echo "[]"
    fi
    ;;
  summary-counts)
    if [ -n "$filtered" ]; then
      printf '%s\n' "$filtered" | jq -s -c '
        {
          total_events: length,
          by_category: ((group_by(.category) | map({(.[0].category): length}) | add) // {}),
          by_event_type: ((group_by(.event_type) | map({(.[0].event_type): length}) | add) // {}),
          by_repo: ((group_by(.repo // "null") | map({(.[0].repo // "null"): length}) | add) // {})
        }
      '
    else
      jq -c -n '{total_events: 0, by_category: {}, by_event_type: {}, by_repo: {}}'
    fi
    ;;
esac

exit 0
