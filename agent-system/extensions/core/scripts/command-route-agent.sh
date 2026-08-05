#!/usr/bin/env bash
# command-route-agent.sh — Resolve task_type to AGENT_NAME via extension manifest lookup
#
# The agent-level counterpart to command-route-skill.sh: both source the same
# manifest-routing-lib.sh ladder, against routing_agents/routing_agents_hard instead of
# routing/routing_hard. This is the resolver both skill-orchestrate and skill-orchestrate-hard
# now call, replacing their prior independent case tables, directory probes, sed derivations,
# and (for skill-orchestrate-hard) no-break last-match-wins manifest loop.
#
# USAGE:
#   source .claude/scripts/command-route-agent.sh "$op" "$TASK_TYPE" "$default_agent" "${effort_flag:-}"
#   echo "$AGENT_NAME"  # resolved agent name (no .md suffix)
#
# PARAMETERS:
#   $1 = op             : "research" | "plan" | "implement"
#   $2 = task_type      : TASK_TYPE resolved by the caller (may be simple or compound, e.g.
#                         "founder:deck")
#   $3 = default_agent  : fallback agent name if no manifest declares a routing_agents entry
#                         e.g., "general-research-agent", "planner-agent",
#                         "general-implementation-agent" (standard mode), or
#                         "general-research-hard-agent" etc. (hard mode)
#   $4 = effort_flag    : (optional) "hard" | "fast" | "" | unset
#                         When "hard", resolution runs against routing_agents_hard instead of
#                         routing_agents.
#
# EXPORTS:
#   AGENT_NAME          : resolved agent name (from extension declaration or default)
#
# EDGE CASES:
#   - No extensions declare a routing_agents entry for this (op, task_type): AGENT_NAME =
#     $default_agent.
#   - Hard mode with no routing_agents_hard entry: falls through to $default_agent directly —
#     deliberately NOT to the standard (non-hard) routing_agents block, so a caller's own
#     hard-mode default (e.g. "general-research-hard-agent") is preserved exactly, matching the
#     behavior of the case tables this script replaces.
#
# NOTE: This script uses source semantics. It must be sourced (not executed) to export
#       AGENT_NAME to the calling shell environment. It must NEVER call exit — a faulty
#       resolution at worst leaves AGENT_NAME at the caller-supplied default, which is the safe
#       default.

SCRIPT_DIR_ROUTE_AGENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/manifest-routing-lib.sh
source "${SCRIPT_DIR_ROUTE_AGENT}/lib/manifest-routing-lib.sh"

_route_op="$1"
_route_task_type="$2"
_route_default_agent="$3"
_route_effort_flag="${4:-}"

if [ "$_route_effort_flag" = "hard" ]; then
  _route_block="routing_agents_hard"
else
  _route_block="routing_agents"
fi

routing_lookup "$_route_block" "$_route_op" "$_route_task_type"
_route_via="$_ROUTE_LAST_VIA"

if [ -n "$_ROUTE_LAST_VALUE" ]; then
  AGENT_NAME="$_ROUTE_LAST_VALUE"
else
  AGENT_NAME="$_route_default_agent"
  _route_via="default"
fi

routing_trace "$_route_op" "$_route_task_type" "$_route_effort_flag" "$AGENT_NAME" "$_route_via" "route-agent"

unset _route_op _route_task_type _route_default_agent _route_effort_flag _route_block _route_via SCRIPT_DIR_ROUTE_AGENT

export AGENT_NAME
