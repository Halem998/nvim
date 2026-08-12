#!/usr/bin/env bash
# orchestrate-loop-guard-init.sh — Shared Stage 2 loop-guard initializer prologue for both
# orchestrate engines (dedup of the orchestrate-skill-body duplication). Covers ONLY the portion
# of Stage 2 that sits strictly BEFORE the `budget-continuation-override:begin` sentinel (locked,
# never touched — see specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md) and the small
# blocker-escalation counter pair that sits strictly AFTER the locked region's resume-read block.
# Nothing inside the locked region itself (budget-continuation-override:begin through each
# engine's resume anchor, per test-loop-guard-budget-override.sh) is touched by this script or
# its call sites.
#
# This is deliberately a SMALL extraction — most of Stage 2 is either genuinely per-engine
# (MAX_CYCLES value, the hard-only loop-guard-staleness detector, churn-state init,
# current_plan_version) or inside the locked region. A small measured byte count here is the
# correct outcome, not a shortfall (see the plan's Phase 6 Scope Hypothesis).
#
# Usage:
#   orchestrate-loop-guard-init.sh <task_dir> <handoff_path_abs>
#
# Side effect: `mkdir -p <task_dir>` (matching the pre-dedup inline `mkdir -p "$TASK_DIR"`).
#
# Output: a single-line compact JSON object on stdout. Fields:
#   loop_guard_file          string  "<task_dir>/.orchestrator-loop-guard"
#   handoff_file              string  echoes handoff_path_abs verbatim
#   max_infra_failures        int     3 (flat, not scaled with MAX_CYCLES — see
#                                       context/patterns/infra-failure-discrimination.md)
#   blocker_escalation_count  int     0 (reset each /orchestrate invocation)
#   max_blocker_escalations   int     2
#
# Exit codes: 0 on normal completion. 2 — usage error or jq unavailable.

set -uo pipefail

task_dir="${1:-}"
handoff_path_abs="${2:-}"

if [ -z "$task_dir" ] || [ "$#" -ne 2 ]; then
  echo "ERROR: orchestrate-loop-guard-init.sh: usage: orchestrate-loop-guard-init.sh <task_dir> <handoff_path_abs>" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-loop-guard-init.sh: jq is not available." >&2
  exit 2
fi

mkdir -p "$task_dir"

loop_guard_file="${task_dir}/.orchestrator-loop-guard"

jq -n -c \
  --arg loop_guard_file "$loop_guard_file" \
  --arg handoff_file "$handoff_path_abs" \
  --argjson max_infra_failures 3 \
  --argjson blocker_escalation_count 0 \
  --argjson max_blocker_escalations 2 \
  '{loop_guard_file: $loop_guard_file, handoff_file: $handoff_file,
    max_infra_failures: $max_infra_failures,
    blocker_escalation_count: $blocker_escalation_count,
    max_blocker_escalations: $max_blocker_escalations}'

exit 0
