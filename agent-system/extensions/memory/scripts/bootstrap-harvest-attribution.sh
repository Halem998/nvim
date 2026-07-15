#!/usr/bin/env bash
# bootstrap-harvest-attribution.sh - One-shot, read-only join of .meta.json subagent sidecars to
# their parent session, extracting a best-effort task number per sidecar description and rolling
# results up to one row per parent session.
#
# READ-ONLY CONTRACT (binding): this script only reads .meta.json sidecars and parent transcripts
# under the given projects root (default ~/.claude/projects/). It never writes, deletes, moves,
# or truncates anything there. Output is JSONL on stdout; diagnostics go to stderr.
#
# ID-SPACE CONTRACT (binding): this join stays entirely inside Claude Code's own UUID session-id
# space (transcript directory structure + toolUseId content-block ids). It never touches or
# constructs an agent-system-minted orchestrator session identifier (the "sess" + timestamp +
# random suffix format used elsewhere in this codebase for command dispatch) -- that id space is
# a dead end for this join and must not appear anywhere in this script.
#
# JOIN MECHANISM (no content parsing beyond the description regex below):
#   1. A subagent sidecar lives at <parent-sessionId>/subagents/agent-*.meta.json; the directory
#      structure gives the parent sessionId directly (one level up from subagents/).
#   2. The sidecar's `toolUseId` is the id of a `Task`-type `tool_use` content block inside the
#      PARENT session's own transcript (the session that spawned the subagent) -- matching it
#      confirms the link is real, not just a directory-structure guess.
#   3. `description` is regex-scanned for a task number. A sidecar whose description has no
#      task-number match gets `task_number: null` -- NEVER a guess. The established ~63%
#      resolution ceiling is not to be chased by widening this regex; a wrong attribution is
#      worse than an honest null.
#
# Usage:
#   bootstrap-harvest-attribution.sh [projects_root]
#
# Emits one JSONL row per PARENT session that has at least one subagent sidecar:
#   session_id, task_numbers (array, nulls excluded), agent_types (array), subagent_count

set -uo pipefail

PROJECTS_ROOT="${1:-$HOME/.claude/projects}"

if [ ! -d "$PROJECTS_ROOT" ]; then
  echo "FATAL: projects root not found: $PROJECTS_ROOT" >&2
  exit 1
fi

sidecars_scanned=0
resolved_task_number=0
unresolved_task_number=0
toolUseId_confirmed=0
toolUseId_unconfirmed=0
rows_emitted=0
sidecars_decode_failed=0

# Task-number regex: case-insensitive "task(s) <number>", optionally prefixed with #.
# Deliberately narrow -- do not widen to chase the ~63% ceiling (see header).
TASK_REGEX='[Tt]asks?[[:space:]]+#?([0-9]{1,5})'

for project_dir in "$PROJECTS_ROOT"/*/; do
  [ -d "$project_dir" ] || continue
  project_dir="${project_dir%/}"

  while IFS= read -r -d '' parent_transcript; do
    parent_session_id="$(basename "$parent_transcript" .jsonl)"
    subagents_dir="$project_dir/$parent_session_id/subagents"
    [ -d "$subagents_dir" ] || continue

    task_numbers_json="[]"
    agent_types_json="[]"
    subagent_count=0

    while IFS= read -r -d '' meta_file; do
      sidecars_scanned=$((sidecars_scanned + 1))
      subagent_count=$((subagent_count + 1))

      if ! jq -e . "$meta_file" >/dev/null 2>&1; then
        sidecars_decode_failed=$((sidecars_decode_failed + 1))
        echo "WARN: decode failure, skipping (not silently dropped): $meta_file" >&2
        continue
      fi

      description="$(jq -r '.description // empty' "$meta_file" 2>/dev/null)"
      agent_type="$(jq -r '.agentType // empty' "$meta_file" 2>/dev/null)"
      tool_use_id="$(jq -r '.toolUseId // empty' "$meta_file" 2>/dev/null)"

      if [ -n "$agent_type" ]; then
        agent_types_json="$(echo "$agent_types_json" | jq -c --arg t "$agent_type" '. + [$t]')"
      fi

      # toolUseId confirmation: match against a Task-type tool_use block in the PARENT
      # transcript. Never touches the orchestrator session-id space -- this is a lookup purely
      # within Claude Code's own transcript content (assistant message tool_use blocks), keyed
      # by "toolu_"-prefixed ids.
      if [ -n "$tool_use_id" ]; then
        confirmed="$(jq -c --arg tid "$tool_use_id" '
          select(.type == "assistant") | .message.content[]?
          | select(.type == "tool_use" and .id == $tid)
        ' "$parent_transcript" 2>/dev/null | head -1)"
        if [ -n "$confirmed" ]; then
          toolUseId_confirmed=$((toolUseId_confirmed + 1))
        else
          toolUseId_unconfirmed=$((toolUseId_unconfirmed + 1))
        fi
      else
        toolUseId_unconfirmed=$((toolUseId_unconfirmed + 1))
      fi

      task_number=""
      if [ -n "$description" ] && [[ "$description" =~ $TASK_REGEX ]]; then
        task_number="${BASH_REMATCH[1]}"
      fi

      if [ -n "$task_number" ]; then
        resolved_task_number=$((resolved_task_number + 1))
        task_numbers_json="$(echo "$task_numbers_json" | jq -c --argjson n "$task_number" '. + [$n]')"
      else
        unresolved_task_number=$((unresolved_task_number + 1))
      fi
    done < <(find -L "$subagents_dir" -maxdepth 1 -name 'agent-*.meta.json' -type f -print0 2>/dev/null)

    if [ "$subagent_count" -gt 0 ]; then
      row_json="$(jq -nc \
        --arg session_id "$parent_session_id" \
        --argjson task_numbers "$task_numbers_json" \
        --argjson agent_types "$agent_types_json" \
        --argjson subagent_count "$subagent_count" \
        '{
          session_id: $session_id,
          task_numbers: ($task_numbers | unique),
          agent_types: ($agent_types | unique),
          subagent_count: $subagent_count
        }')"
      echo "$row_json"
      rows_emitted=$((rows_emitted + 1))
    fi
  done < <(find -L "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null)
done

{
  echo "bootstrap-harvest-attribution.sh: sidecars_scanned=$sidecars_scanned rows_emitted=$rows_emitted resolved_task_number=$resolved_task_number unresolved_task_number=$unresolved_task_number toolUseId_confirmed=$toolUseId_confirmed toolUseId_unconfirmed=$toolUseId_unconfirmed sidecars_decode_failed=$sidecars_decode_failed"
} >&2
