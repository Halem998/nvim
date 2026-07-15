#!/usr/bin/env bash
# bootstrap-harvest.sh - Orchestrates the one-shot, read-only cold-start harvest of the Claude
# Code transcript corpus and the durable history.jsonl spine into a pointer-based dataset.
#
# READ-ONLY CONTRACT (binding, restated from the three passes this orchestrates): every read
# against the corpus goes through bootstrap-harvest-transcripts.sh, bootstrap-harvest-history.sh,
# and bootstrap-harvest-attribution.sh, each of which is read-only by construction (jq/find/cat/
# python3 raw_decode only -- no rm/mv/>/>>/truncate against the corpus). This orchestrator itself
# only writes to the two output paths passed as arguments (never back into the corpus).
#
# OUTCOME INFERENCE -- EXPLICIT MODELING DECISION, NOT AN EXTRACTION (binding): there is no
# session-level success/failure field anywhere in the source data. `inferred_outcome` is a label
# this harvest invents, computed as follows (every row also retains the raw numerator/
# denominator it was computed from, so a future consumer can re-label WITHOUT re-mining):
#
#   total_is_error   = is_error_count + subagent_is_error_count
#                       (a failing subagent is real, load-bearing failure signal for the
#                       session as a whole -- subagent failures roll up into the parent)
#   is_error_rate    = total_is_error / tool_result_count   (0 when tool_result_count == 0)
#   trivial          when message_count < 3    (too short to judge -- NOT a success claim)
#   clean            when total_is_error == 0 and message_count >= 3
#   mixed            when 0 < is_error_rate <= 0.10
#   high_error       when is_error_rate > 0.10
#
# The 0.10 threshold is a PROVISIONAL judgement call, chosen against the corpus-wide 2.9%
# `is_error` density established in the source inventory. It is stated here in plain text
# specifically so a future consumer can recompute a different threshold from the retained raw
# counts without re-mining the (perishable, 30-day-rolling) transcript corpus.
#
# Usage:
#   bootstrap-harvest.sh <sessions_out.jsonl> <history_spine_out.jsonl> <manifest_out.json> \
#     [projects_root] [history_jsonl_path]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SESSIONS_OUT="${1:?Usage: bootstrap-harvest.sh <sessions_out.jsonl> <history_spine_out.jsonl> <manifest_out.json> [projects_root] [history_jsonl_path]}"
HISTORY_OUT="${2:?missing history_spine_out.jsonl}"
MANIFEST_OUT="${3:?missing manifest_out.json}"
PROJECTS_ROOT="${4:-$HOME/.claude/projects}"
HISTORY_FILE="${5:-$HOME/.claude/history.jsonl}"

if [ -z "${CLAUDE_CODE_SESSION_ID:-}" ]; then
  echo "FATAL: CLAUDE_CODE_SESSION_ID is unset -- refusing to run without a self-exclusion key" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

harvest_start_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
harvest_start_epoch="$(date +%s)"

echo "[bootstrap-harvest] pass 1/3: transcripts ($PROJECTS_ROOT)" >&2
bash "$SCRIPT_DIR/bootstrap-harvest-transcripts.sh" "$PROJECTS_ROOT" \
  > "$TMP_DIR/transcripts.jsonl" 2> "$TMP_DIR/transcripts.stderr"
transcripts_stderr="$(cat "$TMP_DIR/transcripts.stderr")"
echo "$transcripts_stderr" >&2

echo "[bootstrap-harvest] pass 2/3: history.jsonl spine ($HISTORY_FILE)" >&2
bash "$SCRIPT_DIR/bootstrap-harvest-history.sh" "$HISTORY_FILE" \
  > "$HISTORY_OUT" 2> "$TMP_DIR/history.stderr"
history_stderr="$(cat "$TMP_DIR/history.stderr")"
echo "$history_stderr" >&2

echo "[bootstrap-harvest] pass 3/3: attribution join ($PROJECTS_ROOT)" >&2
bash "$SCRIPT_DIR/bootstrap-harvest-attribution.sh" "$PROJECTS_ROOT" \
  > "$TMP_DIR/attribution.jsonl" 2> "$TMP_DIR/attribution.stderr"
attribution_stderr="$(cat "$TMP_DIR/attribution.stderr")"
echo "$attribution_stderr" >&2

echo "[bootstrap-harvest] joining transcripts + attribution, computing inferred_outcome" >&2

jq -s '.' "$TMP_DIR/transcripts.jsonl" > "$TMP_DIR/transcripts_array.json" 2>/dev/null || echo '[]' > "$TMP_DIR/transcripts_array.json"
jq -s '.' "$TMP_DIR/attribution.jsonl" > "$TMP_DIR/attribution_array.json" 2>/dev/null || echo '[]' > "$TMP_DIR/attribution_array.json"

jq -c --slurpfile attribution "$TMP_DIR/attribution_array.json" '
  ($attribution[0] | map({key: .session_id, value: .}) | from_entries) as $attr_by_session
  | .[]
  | . as $t
  | ($attr_by_session[$t.session_id] // {task_numbers: [], agent_types: [], subagent_count: 0}) as $a
  | ($t.is_error_count // 0) as $own_err
  | ($t.subagent_is_error_count // 0) as $sub_err
  | ($own_err + $sub_err) as $total_is_error
  | ($t.tool_result_count // 0) as $tool_result_count
  | (if $tool_result_count > 0 then ($total_is_error / $tool_result_count) else 0 end) as $is_error_rate
  | (
      if ($t.message_count // 0) < 3 then "trivial"
      elif $total_is_error == 0 then "clean"
      elif $is_error_rate <= 0.10 then "mixed"
      else "high_error"
      end
    ) as $outcome
  | {
      session_id: $t.session_id,
      repo: $t.repo,
      first_timestamp: $t.first_timestamp,
      last_timestamp: $t.last_timestamp,
      message_count: $t.message_count,
      is_error_count: $own_err,
      subagent_is_error_count: $sub_err,
      total_is_error: $total_is_error,
      tool_result_count: $tool_result_count,
      is_error_rate: $is_error_rate,
      inferred_outcome: $outcome,
      task_numbers: ($a.task_numbers // []),
      agent_types: ($a.agent_types // []),
      subagent_count: ($a.subagent_count // 0),
      transcript_path: $t.transcript_path
    }
' "$TMP_DIR/transcripts_array.json" > "$SESSIONS_OUT"

harvest_end_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
harvest_end_epoch="$(date +%s)"
wall_clock_seconds=$((harvest_end_epoch - harvest_start_epoch))

sessions_row_count="$(wc -l < "$SESSIONS_OUT" | tr -d ' ')"
history_row_count="$(wc -l < "$HISTORY_OUT" | tr -d ' ')"

outcome_distribution="$(jq -s 'group_by(.inferred_outcome) | map({(.[0].inferred_outcome): length}) | add // {}' "$SESSIONS_OUT")"

# Parse stderr summary lines from each pass into structured manifest fields. Each sub-script's
# stderr may ALSO contain WARN lines (decode-failure notices) interleaved before its final
# "<script>.sh: k=v k2=v2 ..." summary line -- extract only the line matching that summary
# format (the LAST such line, in case a script ever emits more than one) rather than the whole
# multi-line stderr blob, so WARN-line content never corrupts the key=value parse.
parse_kv_line() {
  # $1 = raw (possibly multi-line) stderr content for one pass
  local summary_line
  summary_line="$(echo "$1" | grep -E '^[A-Za-z0-9_.-]+\.sh: ' | tail -1)"
  echo "$summary_line" | sed -E 's/^[^:]+: //' | tr ' ' '\n' | awk -F= '{printf "\"%s\":%s,", $1, $2}' | sed 's/,$//'
}

transcripts_kv="$(parse_kv_line "$transcripts_stderr")"
history_kv="$(parse_kv_line "$history_stderr")"
attribution_kv="$(parse_kv_line "$attribution_stderr")"

jq_tool_version="$(jq --version 2>/dev/null || echo unknown)"
python_version="$(python3 --version 2>&1 || echo unknown)"

cat > "$MANIFEST_OUT" <<MANIFESTEOF
{
  "harvest_timestamp_start": "$harvest_start_iso",
  "harvest_timestamp_end": "$harvest_end_iso",
  "wall_clock_seconds": $wall_clock_seconds,
  "excluded_self_session_id": "$CLAUDE_CODE_SESSION_ID",
  "projects_root": "$PROJECTS_ROOT",
  "history_jsonl_path": "$HISTORY_FILE",
  "sessions_jsonl_row_count": $sessions_row_count,
  "history_spine_jsonl_row_count": $history_row_count,
  "transcripts_pass": {${transcripts_kv:-}},
  "history_pass": {${history_kv:-}},
  "attribution_pass": {${attribution_kv:-}},
  "inferred_outcome_distribution": $outcome_distribution,
  "inferred_outcome_formula": {
    "total_is_error": "is_error_count + subagent_is_error_count",
    "is_error_rate": "total_is_error / tool_result_count (0 when denominator is 0)",
    "trivial": "message_count < 3",
    "clean": "total_is_error == 0 and message_count >= 3",
    "mixed": "0 < is_error_rate <= 0.10",
    "high_error": "is_error_rate > 0.10",
    "threshold_note": "0.10 is a provisional judgement call against the corpus-wide 2.9% is_error density established in the source inventory; raw numerator/denominator retained on every row so this can be recomputed without re-mining"
  },
  "phase1_strategy_decision": {
    "bulk_transcript_strategy": "jq-only per-file -s slurp pass",
    "oracle_role": "claude-code-log used as pilot-only correctness oracle on the nvim slice (109 files, 42.073s), not invoked at bulk/full-corpus scale",
    "history_jsonl_decode_strategy": "Python json.JSONDecoder().raw_decode skip-and-continue (bare jq whole-stream parsing aborts fatally at the first embedded-newline record rather than skipping it)"
  },
  "tool_versions": {
    "jq": "$jq_tool_version",
    "python3": "$python_version"
  }
}
MANIFESTEOF

echo "[bootstrap-harvest] done. sessions_jsonl_row_count=$sessions_row_count history_spine_jsonl_row_count=$history_row_count wall_clock_seconds=$wall_clock_seconds" >&2
