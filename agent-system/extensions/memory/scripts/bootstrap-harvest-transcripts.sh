#!/usr/bin/env bash
# bootstrap-harvest-transcripts.sh - One-shot, read-only mine of the Claude Code transcript
# corpus into a pointer-based JSONL row per top-level session.
#
# READ-ONLY CONTRACT (binding): this script only reads under the given projects root
# (default ~/.claude/projects/). It never writes, deletes, moves, or truncates anything there.
# All output is JSONL on stdout; diagnostics (skip/decode-failure counts) go to stderr. The
# corpus this script mines is scarce and irreplaceable (a 30-day rolling retention window with
# no backup), so every read verb used below is one of jq/find/stat/wc/cat -- never rm/mv/>/>>
# /truncate against the projects root.
#
# OUTCOME SIGNAL (binding): `is_error` is the ONLY failure signal this script counts. The string
# `FAILED` is deliberately NEVER used as an outcome predicate -- it is overwhelmingly *content*
# (e.g. Lean/test output rendered inside an exit-0, successful Bash tool result), not a session
# outcome. Grepping for `FAILED` as a failure signal would badly over-report.
#
# Usage:
#   bootstrap-harvest-transcripts.sh [projects_root]
#
# Requires: $CLAUDE_CODE_SESSION_ID set in the environment (self-exclusion key). Snapshotted
# once at start and never re-derived mid-run, per the self-observation hazard: a long-running
# harvest's own transcript keeps growing during the run, and re-deriving "current session"
# mid-run would still count some of its own early activity.
#
# Emits one JSONL row per top-level session (excluding the self-excluded session and its
# subagents/ children):
#   session_id, repo, first_timestamp, last_timestamp, message_count, is_error_count,
#   subagent_is_error_count, tool_result_count, transcript_path
#
# repo resolution order (fixed, never the encoded dirname):
#   1. sessions-index.json.entries[].projectPath for this project directory
#   2. the session's own first non-null `cwd` field
#   3. null, with a loud warning on stderr (never a dirname guess)

set -uo pipefail

PROJECTS_ROOT="${1:-$HOME/.claude/projects}"

if [ -z "${CLAUDE_CODE_SESSION_ID:-}" ]; then
  echo "FATAL: CLAUDE_CODE_SESSION_ID is unset -- refusing to run without a self-exclusion key" >&2
  echo "       (running without it would let the miner count its own is_error events)" >&2
  exit 1
fi

SELF_SESSION_ID="$CLAUDE_CODE_SESSION_ID"

if [ ! -d "$PROJECTS_ROOT" ]; then
  echo "FATAL: projects root not found: $PROJECTS_ROOT" >&2
  exit 1
fi

files_scanned=0
files_skipped_self=0
files_decode_failed=0
rows_emitted=0
repo_unresolved=0

for project_dir in "$PROJECTS_ROOT"/*/; do
  [ -d "$project_dir" ] || continue
  project_dir="${project_dir%/}"

  sessions_index="$project_dir/sessions-index.json"
  has_index=0
  if [ -f "$sessions_index" ]; then
    if jq -e . "$sessions_index" >/dev/null 2>&1; then
      has_index=1
    fi
  fi

  # Top-level session transcripts only (maxdepth 1 *.jsonl); subagents/ sidecars are excluded
  # here and rolled up separately below -- this is the "832 top-level of 5,447 total" split
  # from the source inventory.
  while IFS= read -r -d '' transcript; do
    session_id="$(basename "$transcript" .jsonl)"
    files_scanned=$((files_scanned + 1))

    if [ "$session_id" = "$SELF_SESSION_ID" ]; then
      files_skipped_self=$((files_skipped_self + 1))
      continue
    fi

    # Single jq -s (slurp) pass over the whole file: without -s, jq's filter runs once PER
    # top-level JSON value in the .jsonl (once per line) rather than once for the whole file,
    # silently producing many tiny per-record results instead of one file-level aggregate.
    row_json="$(jq -s -c --arg session_id "$session_id" --arg transcript_path "$transcript" '
      ([.[] | .. | objects | select(has("is_error"))]) as $err_objs
      | {
          session_id: $session_id,
          repo: ([.[] | select(.cwd != null) | .cwd] | first),
          first_timestamp: ([.[] | select(.timestamp != null) | .timestamp] | sort | first),
          last_timestamp: ([.[] | select(.timestamp != null) | .timestamp] | sort | last),
          message_count: ([.[] | select(.type == "user" or .type == "assistant")] | length),
          is_error_count: ([$err_objs[] | select(.is_error == true)] | length),
          tool_result_count: ($err_objs | length),
          transcript_path: $transcript_path
        }
    ' "$transcript" 2>/dev/null)"

    if [ -z "$row_json" ] || ! echo "$row_json" | jq -e . >/dev/null 2>&1; then
      files_decode_failed=$((files_decode_failed + 1))
      echo "WARN: decode failure, skipping (not silently dropped): $transcript" >&2
      continue
    fi

    # repo resolution: prefer sessions-index.json.entries[].projectPath over the record cwd,
    # per the fixed resolution order. Never the encoded dirname in either branch.
    repo=""
    if [ "$has_index" -eq 1 ]; then
      repo="$(jq -r --arg sid "$session_id" '.entries[]? | select(.sessionId == $sid) | .projectPath // empty' "$sessions_index" 2>/dev/null | head -1)"
    fi
    if [ -z "$repo" ]; then
      repo="$(echo "$row_json" | jq -r '.repo // empty')"
    fi
    if [ -z "$repo" ]; then
      repo_unresolved=$((repo_unresolved + 1))
      echo "WARN: repo unresolved for session $session_id (no sessions-index.json match, no record cwd) -- emitting repo:null, never a dirname guess" >&2
      repo="null"
      row_json="$(echo "$row_json" | jq -c '.repo = null')"
    else
      row_json="$(echo "$row_json" | jq -c --arg repo "$repo" '.repo = $repo')"
    fi

    # Subagent is_error rollup: a failing subagent is real, load-bearing failure signal for
    # the session as a whole (binding modeling decision, see bootstrap-harvest.sh Phase 5).
    subagents_dir="$project_dir/$session_id/subagents"
    subagent_is_error_count=0
    if [ -d "$subagents_dir" ]; then
      while IFS= read -r -d '' agent_file; do
        agent_err="$(jq -s '[.[] | .. | objects | select(has("is_error") and .is_error == true)] | length' "$agent_file" 2>/dev/null)"
        if [ -n "$agent_err" ] && [ "$agent_err" -eq "$agent_err" ] 2>/dev/null; then
          subagent_is_error_count=$((subagent_is_error_count + agent_err))
        fi
      done < <(find -L "$subagents_dir" -maxdepth 1 -name 'agent-*.jsonl' -type f -print0 2>/dev/null)
    fi

    row_json="$(echo "$row_json" | jq -c --argjson sae "$subagent_is_error_count" '.subagent_is_error_count = $sae')"
    echo "$row_json"
    rows_emitted=$((rows_emitted + 1))
  done < <(find -L "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null)
done

{
  echo "bootstrap-harvest-transcripts.sh: files_scanned=$files_scanned files_skipped_self=$files_skipped_self files_decode_failed=$files_decode_failed rows_emitted=$rows_emitted repo_unresolved=$repo_unresolved"
} >&2
