#!/usr/bin/env bash
# validate-context-budgets.sh
# Validates agent context budgets against tier caps for index.json
#
# Usage: validate-context-budgets.sh [--verbose] [--index PATH]
#
# Exit codes:
#   0 - All agents within budget (or documented exceptions only)
#   1 - One or more agents exceed budget cap without documented exception

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
REPO_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
INDEX_FILE="${REPO_ROOT}/.claude/context/index.json"
VERBOSE=false
VIOLATIONS=0
# WARNINGS is the total count of non-fatal findings across every check.
# EXCEPTIONS_APPLIED counts only the subset that are documented per-agent budget exceptions
# (the OK* rows). The two were the same counter until the Double-Loading Check was restated as a
# warning; keeping them separate is what stops a double-loading warning from being narrated as a
# "documented exception" in the summary.
WARNINGS=0
EXCEPTIONS_APPLIED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --index) INDEX_FILE="$2"; shift 2 ;;
    --help)
      echo "Usage: $0 [--verbose] [--index PATH]"
      echo ""
      echo "Validates agent context budgets against tier caps."
      echo "Reads index.json and computes per-agent token totals."
      echo ""
      echo "Options:"
      echo "  --verbose    List all entries per agent"
      echo "  --index PATH Path to index.json (default: .claude/context/index.json)"
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "ERROR: index.json not found at $INDEX_FILE" >&2
  exit 1
fi

# Verify JSON validity
if ! jq empty "$INDEX_FILE" 2>/dev/null; then
  echo "ERROR: index.json is not valid JSON" >&2
  exit 1
fi

# --- Tier derivation -------------------------------------------------------------------------
# Tier is DERIVED from load_when shape, never read from an authored `tier` field. The entry
# schema (context/index.schema.json) deliberately omits `tier` and records in its $comment that
# the value "is meant to be derived algorithmically from load_when shape rather than
# hand-authored, since no entry in practice ever populated it accurately" -- and, with
# `additionalProperties: false` on the entry shape, an authored `tier` is not even schema-legal.
# This function is the single definition of that derivation; it is prepended to every jq program
# below that needs a tier, so there is exactly one rule table in this file.
#
#   Rule table (first match wins, total over all entries):
#     load_when.always == true                        -> Tier 1  (always loaded)
#     load_when.agents non-empty                      -> Tier 2  (agent-scoped)
#     load_when.commands or task_types non-empty      -> Tier 3  (command/task-type-scoped)
#     every hook empty                                -> Tier 4  (on-demand / grep-only)
#
# Because case 4 is a fallthrough on emptiness, "all hooks empty" now DERIVES to Tier 4 rather
# than being an authored claim. That is what makes the old Dead Entry Check ("not Tier 4 but
# never loaded") a tautology, and why that check is keyed on the explicit `on_demand` marker
# instead -- see the Dead Entry Check section below.
DERIVED_TIER='
def derived_tier:
  if (.load_when.always == true) then 1
  elif ((.load_when.agents // []) | length) > 0 then 2
  elif (((.load_when.commands // []) | length) > 0
        or ((.load_when.task_types // []) | length) > 0) then 3
  else 4
  end;
'

echo "=== Context Budget Validation ==="
echo "Index: $INDEX_FILE"
echo ""

# Budget caps per agent class (tokens)
declare -A CAPS=(
  ["meta-builder-agent"]=15000
  ["planner-agent"]=15000
  ["general-implementation-agent"]=8000
  ["general-research-agent"]=8000
  ["neovim-implementation-agent"]=8000
  ["neovim-research-agent"]=8000
  ["nix-implementation-agent"]=8000
  ["nix-research-agent"]=8000
  ["code-reviewer-agent"]=8000
  ["spawn-agent"]=8000
)

# Documented exceptions (agents that cannot meet strict cap with minimum essential context)
# Format: agent=actual_realistic_cap (with justification)
declare -A EXCEPTIONS=(
  ["general-implementation-agent"]="8048:return-metadata-file(4016)+checkpoint-execution(2032)+progress-file(2000) is minimum irreducible set"
)

echo "--- Agent Budget Check ---"
printf "%-35s %8s %8s %12s\n" "Agent" "Tokens" "Cap" "Status"
printf "%s\n" "$(printf '%.0s-' {1..67})"

for agent in "${!CAPS[@]}"; do
  cap="${CAPS[$agent]}"

  # Compute total tokens for this agent
  total=$(jq --arg agent "$agent" \
    '[.entries[] | select(any(.load_when.agents[]?; . == $agent)) | .line_count] | add // 0' \
    "$INDEX_FILE")
  total_tokens=$((total * 8))

  # Check for documented exception
  exception=""
  if [[ -v "EXCEPTIONS[$agent]" ]]; then
    exception_data="${EXCEPTIONS[$agent]}"
    exception_cap="${exception_data%%:*}"
    exception_reason="${exception_data#*:}"
    exception="(exception: $exception_reason)"
  fi

  if [[ $total_tokens -le $cap ]]; then
    status="OK"
    printf "%-35s %8s %8s %12s\n" "$agent" "$total_tokens" "$cap" "OK"
  elif [[ -n "$exception" && $total_tokens -le "${exception_cap:-0}" ]]; then
    status="OK (exception)"
    printf "%-35s %8s %8s %12s\n" "$agent" "$total_tokens" "$cap" "OK*"
    WARNINGS=$((WARNINGS + 1))
    EXCEPTIONS_APPLIED=$((EXCEPTIONS_APPLIED + 1))
    if [[ "$VERBOSE" == "true" ]]; then
      echo "    * Documented exception: $exception_reason"
    fi
  else
    status="OVER by $((total_tokens - cap))"
    printf "%-35s %8s %8s %12s\n" "$agent" "$total_tokens" "$cap" "OVER:$((total_tokens - cap))"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    echo "  Entries for $agent:"
    jq -r --arg agent "$agent" "${DERIVED_TIER}"'
      .entries[] | select(any(.load_when.agents[]?; . == $agent)) | "    Tier \(derived_tier) \(.line_count * 8) tok  \(.path)"' \
      "$INDEX_FILE" | sort -t' ' -k3 -rn
    echo ""
  fi
done

echo ""

# Tier 1 check
echo "--- Tier 1 Check ---"
tier1_lines=$(jq '[.entries[] | select(.load_when.always == true) | .line_count] | add // 0' "$INDEX_FILE")
tier1_count=$(jq '[.entries[] | select(.load_when.always == true)] | length' "$INDEX_FILE")
tier1_target=500
echo "Always-loaded entries: $tier1_count (target: 2)"
echo "Always-loaded total lines: $tier1_lines (target: ≤$tier1_target)"
if [[ $tier1_lines -le $tier1_target ]]; then
  echo "Status: OK"
else
  echo "Status: OVER by $((tier1_lines - tier1_target)) lines"
  VIOLATIONS=$((VIOLATIONS + 1))
fi
if [[ "$VERBOSE" == "true" ]]; then
  echo "Tier 1 entries:"
  jq -r '.entries[] | select(.load_when.always == true) | "  \(.line_count)L  \(.path)"' "$INDEX_FILE"
fi
echo ""

# Every entry classifies under the derived tier rule table
# `derived_tier` is a total function over the four load_when cases, so an entry can never fail to
# classify. The check therefore reports the resulting distribution (which is real, diffable
# signal about index shape) rather than counting a never-populated authored field.
echo "--- Tier Classification Check ---"
total_entries=$(jq '.entries | length' "$INDEX_FILE")
unclassified=$(jq "${DERIVED_TIER}"'[.entries[] | select((derived_tier | IN(1,2,3,4)) | not)] | length' "$INDEX_FILE")
tier_dist=$(jq -r "${DERIVED_TIER}"'
  [.entries[] | derived_tier] | group_by(.) | map("Tier \(.[0]): \(length)") | join(", ")' "$INDEX_FILE")
echo "Total entries: $total_entries"
echo "Derived tier distribution: $tier_dist"
if [[ $unclassified -eq 0 ]]; then
  echo "Status: OK (all entries classify via derived_tier)"
else
  echo "Status: FAIL ($unclassified entries fail to classify)"
  VIOLATIONS=$((VIOLATIONS + 1))
  if [[ "$VERBOSE" == "true" ]]; then
    echo "Unclassified:"
    jq -r "${DERIVED_TIER}"'.entries[] | select((derived_tier | IN(1,2,3,4)) | not) | "  \(.path)"' "$INDEX_FILE"
  fi
fi
echo ""

# No dead entries (never auto-loaded and not explicitly marked on-demand)
# Dead = every load_when hook empty AND no explicit `on_demand: true` marker.
#
# This check was formerly keyed on the authored tier field being other than 4 ("not Tier 4 but
# never loaded"). Under algorithmic derivation an all-hooks-empty
# entry ALWAYS derives to Tier 4, so that predicate is unsatisfiable and the check would silently
# become a tautology that can never fire. Emptiness alone therefore no longer exempts an entry:
# the exemption must be stated explicitly by the entry author via `on_demand: true` (declared as
# a property in context/index.schema.json). That keeps "deliberately grep-only" distinguishable
# from "someone forgot to hook this up", which is the only signal this check ever carried.
DEAD_PRED='
  select(
    (((.on_demand // false) == true) | not) and
    ((.load_when.always == true) | not) and
    ((.load_when.agents // []) | length) == 0 and
    ((.load_when.commands // []) | length) == 0 and
    ((.load_when.task_types // []) | length) == 0 and
    ((.load_when.skills // []) | length) == 0 and
    ((.load_when.languages // []) | length) == 0
  )
'
echo "--- Dead Entry Check ---"
dead_count=$(jq "[.entries[] | ${DEAD_PRED}] | length" "$INDEX_FILE")
if [[ $dead_count -eq 0 ]]; then
  echo "Dead entries (all hooks empty, not marked on_demand): 0 -- OK"
else
  echo "Dead entries found: $dead_count"
  VIOLATIONS=$((VIOLATIONS + 1))
  jq -r "${DERIVED_TIER}"'.entries[] | '"${DEAD_PRED}"' | "  \(.path) (Tier \(derived_tier))"' "$INDEX_FILE"
fi
echo ""

# Entries reachable through both an agent hook and a command hook
#
# Formerly required the authored tier field to equal 3 alongside `agents > 0 and commands > 0`.
# That conjunction is unsatisfiable under
# derivation -- any entry with a non-empty `agents` array derives to Tier 2, never 3 -- so keeping
# the tier term would make this check structurally dead rather than merely accidentally so. It is
# restated on the load_when shape alone, which is what "double-loaded" always meant.
#
# Reported as a WARNING, not a violation, and deliberately so: the restatement surfaces a large
# set of pre-existing matches in one go (49 of 187 entries at the time of the restatement).
# Triaging them is real work with per-entry judgement calls, separate from making the check
# honest. Counting them as violations would fail every run from day one and the signal would be
# turned off rather than acted on. The count prints unconditionally so the number stays visible.
echo "--- Double-Loading Check ---"
double_loaded=$(jq '[.entries[] | select(((.load_when.agents // []) | length) > 0 and ((.load_when.commands // []) | length) > 0)] | length' "$INDEX_FILE")
if [[ $double_loaded -eq 0 ]]; then
  echo "Entries with both agents and commands hooks: 0 -- OK"
else
  echo "Entries with both agents and commands hooks: $double_loaded (WARNING -- pending triage)"
  WARNINGS=$((WARNINGS + 1))
  if [[ "$VERBOSE" == "true" ]]; then
    jq -r '.entries[] | select(((.load_when.agents // []) | length) > 0 and ((.load_when.commands // []) | length) > 0) | "  \(.path)"' "$INDEX_FILE"
  fi
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Violations: $VIOLATIONS"
if [[ $WARNINGS -gt 0 ]]; then
  echo "Warnings: $WARNINGS"
fi
if [[ $EXCEPTIONS_APPLIED -gt 0 ]]; then
  echo "Documented exceptions: $EXCEPTIONS_APPLIED (OK* entries)"
  echo "  * general-implementation-agent: 8,048 tokens vs 8,000 cap"
  echo "    Minimum essential set cannot be reduced below this value:"
  echo "    - formats/return-metadata-file.md (4,016 tok) -- critical for all subagents"
  echo "    - patterns/checkpoint-execution.md (2,032 tok) -- critical for phase tracking"
  echo "    - formats/progress-file.md (2,000 tok) -- critical for resumable execution"
fi

if [[ $VIOLATIONS -eq 0 ]]; then
  echo ""
  echo "All checks passed!"
  exit 0
else
  echo ""
  echo "FAIL: $VIOLATIONS violation(s) found"
  exit 1
fi
