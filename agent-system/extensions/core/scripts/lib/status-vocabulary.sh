#!/usr/bin/env bash
# status-vocabulary.sh - Single source of truth for the task-status enum (specs/state.json
# `.active_projects[].status`, i.e. the TASK-LEVEL vocabulary -- a different, wider enum than
# the phase-heading vocabulary phase-heading-patterns.sh anchors).
#
# This is the ONLY place the closed 12-value task-status enum and its state.json-value ->
# TODO.md-marker mapping are defined as executable data. context/schemas/state-schema.json's
# `definitions.taskStatus.enum` is the machine-readable twin of this array -- the two MUST stay
# byte-equal (see scripts/tests/test-status-vocabulary.sh's drift assertion, which extracts the
# schema's enum via jq and diffs it against $STATUS_VOCABULARY_ENUM below). Prose docs
# (context/standards/status-markers.md, context/reference/state-management-schema.md) are
# human-readable glosses over this pair, never independent sources.
#
# `revising`/`revised` are deliberately NOT members of this enum. Three independent pieces of
# evidence converged on treating them as dead vocabulary rather than reconciling them in:
# update-task-status.sh's map_status() has no `revise` case (unreachable through the one
# canonical status writer), state-management-schema.md never mentions them, and
# skill-reviser/SKILL.md explicitly documents skipping the intermediate status ("No intermediate
# 'revising' status is needed for revision... Skip preflight status update"). Do not reintroduce
# them without re-reading that decision.
#
# Modeled on scripts/lib/phase-heading-patterns.sh's "one sourced shared library, many consumers"
# shape. The current consumer list is found live via
# `grep -rl 'status-vocabulary.sh' agent-system/extensions` (the same self-verifying
# consumer-discovery mechanism phase-heading-patterns.sh and task-reference-patterns.sh use).
#
# Usage: `source` this file, then:
#   - Use $STATUS_VOCABULARY_ENUM (bash array) directly for iteration/membership loops.
#   - Call `status_vocabulary_is_valid <value>` to validate a candidate status string.
#   - Use $STATUS_VOCABULARY_TODO_MARKER_MAP (associative array) or call
#     `status_vocabulary_todo_marker <value>` for the state.json-value -> TODO.md-marker mapping
#     (uppercase, space-separated, no brackets -- callers wrap in `[...]` themselves).

# ─── Closed task-status enum (12 values) ───────────────────────────────────────────────────────
# Order matches context/schemas/state-schema.json's definitions.taskStatus.enum exactly -- the
# drift test compares both as sorted sets, but keeping the literal order aligned makes a manual
# diff between the two files trivial.
STATUS_VOCABULARY_ENUM=(
  "not_started"
  "researching"
  "researched"
  "planning"
  "planned"
  "implementing"
  "pr_ready"
  "completed"
  "blocked"
  "abandoned"
  "partial"
  "expanded"
)

# ─── state.json value -> TODO.md marker mapping ────────────────────────────────────────────────
# Bracket-free uppercase marker text; callers that render `[STATUS]` add the brackets themselves
# (matching generate-todo.sh's existing format_status() output contract).
declare -A STATUS_VOCABULARY_TODO_MARKER_MAP=(
  ["not_started"]="NOT STARTED"
  ["researching"]="RESEARCHING"
  ["researched"]="RESEARCHED"
  ["planning"]="PLANNING"
  ["planned"]="PLANNED"
  ["implementing"]="IMPLEMENTING"
  ["pr_ready"]="PR READY"
  ["completed"]="COMPLETED"
  ["blocked"]="BLOCKED"
  ["abandoned"]="ABANDONED"
  ["partial"]="PARTIAL"
  ["expanded"]="EXPANDED"
)

# ─── status_vocabulary_is_valid <value> ────────────────────────────────────────────────────────
# Returns 0 (true) iff <value> is exactly one of the twelve closed enum values, 1 (false)
# otherwise. Never partial-matches (e.g. "not_started_x" is rejected).
status_vocabulary_is_valid() {
  local candidate="$1" v
  for v in "${STATUS_VOCABULARY_ENUM[@]}"; do
    [[ "$candidate" == "$v" ]] && return 0
  done
  return 1
}

# ─── status_vocabulary_todo_marker <value> ─────────────────────────────────────────────────────
# Prints the bracket-free uppercase TODO.md marker text for <value> on stdout and returns 0 when
# <value> is a member of the closed enum. Prints nothing and returns 1 when it is not -- callers
# needing a loud failure on an off-schema value (e.g. generate-todo.sh's format_status()) should
# check the return code rather than trusting empty output alone.
status_vocabulary_todo_marker() {
  local candidate="$1"
  if ! status_vocabulary_is_valid "$candidate"; then
    return 1
  fi
  printf '%s\n' "${STATUS_VOCABULARY_TODO_MARKER_MAP[$candidate]}"
  return 0
}
