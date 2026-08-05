#!/usr/bin/env bash
# command-route-skill.sh — Resolve task_type to skill_name via extension manifest lookup
#
# USAGE:
#   source .claude/scripts/command-route-skill.sh "$operation" "$TASK_TYPE" "$default_skill" "${effort_flag:-}"
#   echo "$SKILL_NAME"  # resolved skill name
#
# PARAMETERS:
#   $1 = operation      : "research" | "plan" | "implement"
#   $2 = task_type      : TASK_TYPE exported by command-gate-in.sh
#                         May be simple ("neovim") or compound ("founder:deck")
#   $3 = default_skill  : fallback if no extension routing found
#                         e.g., "skill-researcher", "skill-planner", "skill-implementer"
#   $4 = effort_flag    : (optional) "hard" | "fast" | "" | unset
#                         When "hard", hard-mode resolution runs against routing_hard.
#
# EXPORTS:
#   SKILL_NAME          : resolved skill name (from extension, default, or hard variant)
#
# EDGE CASES:
#   - No extensions loaded: SKILL_NAME = $default_skill (or hard variant thereof)
#   - Missing manifest files: skipped silently
#   - Empty routing section: falls back to default
#   - Compound keys (e.g., "founder:deck"): tries exact key first, then base type
#   - Hard mode with no hard variant: emits stderr note, uses standard skill
#
# NOTE: This script uses source semantics. It must be sourced (not executed) to
#       export SKILL_NAME to the calling shell environment. It must NEVER call
#       exit — a faulty resolution at worst leaves SKILL_NAME at the standard
#       skill, which is the safe default.
#
# Precedence (first match wins, non-core scanned before core), implemented by the shared
# five-step ladder in manifest-routing-lib.sh's routing_lookup(): the CORE manifest is now
# identified by .name == "core" (see that library's header for why this replaced the
# routing_exempt:true field, which is not unique to core).

SCRIPT_DIR_ROUTE_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/manifest-routing-lib.sh
source "${SCRIPT_DIR_ROUTE_SKILL}/lib/manifest-routing-lib.sh"

_route_operation="$1"
_route_task_type="$2"
_route_default_skill="$3"
_effort_flag="${4:-}"

# Steps 1-3 (standard resolution): the ladder's exact-then-compound-then-default shape
# subsumes the prior three-step loop. No manifest declares a plain `routing` entry on the core
# manifest today, so non-core-first ordering is behavior-identical to the old flat
# alphabetical-glob scan; see manifest-routing-lib.sh's header for why.
#
# routing_lookup is called directly (never `$(routing_lookup ...)`) -- command substitution
# would subshell it and strand its $_ROUTE_LAST_VALUE/$_ROUTE_LAST_VIA outputs; see the
# library's own Usage note.
routing_lookup "routing" "$_route_operation" "$_route_task_type"
_route_via="$_ROUTE_LAST_VIA"
if [ -n "$_ROUTE_LAST_VALUE" ]; then
  SKILL_NAME="$_ROUTE_LAST_VALUE"
else
  SKILL_NAME="$_route_default_skill"
  _route_via="default"
fi

# Step 4: Hard-mode resolution (only when effort_flag="hard")
#
#   4a-4d. routing_lookup against "routing_hard" — non-core exact, non-core compound,
#          core exact, core compound (first match wins).
#   4e.    Append -hard to the resolved standard SKILL_NAME; use only if
#          .claude/skills/${candidate}-hard/SKILL.md exists on disk.
#          Otherwise: emit a stderr note and leave SKILL_NAME unchanged (safe default).

if [ "$_effort_flag" = "hard" ]; then
  routing_lookup "routing_hard" "$_route_operation" "$_route_task_type"
  _hard_skill="$_ROUTE_LAST_VALUE"
  _route_via="$_ROUTE_LAST_VIA"

  # Step 4e — -hard append fallback: only if SKILL.md exists (safety gate)
  # This guarantees the fallback NEVER resolves to an undeployed agent.
  if [ -n "$_hard_skill" ]; then
    SKILL_NAME="$_hard_skill"
  else
    _candidate_hard="${SKILL_NAME}-hard"
    if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then
      SKILL_NAME="$_candidate_hard"
      _route_via="hard-append-fallback"
    else
      echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
      _route_via="hard-miss-standard-fallback"
    fi
  fi
fi

routing_trace "$_route_operation" "$_route_task_type" "$_effort_flag" "$SKILL_NAME" "$_route_via"

# Clean up local variables to avoid polluting caller's environment
unset _route_operation _route_task_type _route_default_skill _effort_flag _hard_skill _candidate_hard _route_via SCRIPT_DIR_ROUTE_SKILL

export SKILL_NAME
