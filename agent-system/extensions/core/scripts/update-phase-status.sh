#!/usr/bin/env bash
# update-phase-status.sh - Update a single phase heading status in a plan file
# Usage: .claude/scripts/update-phase-status.sh TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS
#
# NEW_STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED
# (this case statement's six values are kept in exact correspondence with
# scripts/lib/phase-heading-patterns.sh's PHASE_STATUS_ENUM array -- see the sourcing block below;
# if the two ever disagree, the library's enum is authoritative and this case statement is wrong)
# Outputs: Updated plan file path on success, empty on failure/no-op
#
# Phase heading format: ### Phase N: {name} [STATUS] -- see context/formats/plan-format.md's
# "Canonical phase-heading shape" subsection for the full grammar. This script is the ONE
# deliberately parameter-driven consumer of that grammar: unlike every other consumer (which
# scans a whole plan file for headings), this script is handed a specific phase_number by its
# caller and must therefore validate that argument itself before building a lookup, rather than
# discovering non-conformance by scanning.
#
# Exit codes: 0 - success or idempotent no-op; 1 - validation error (bad arguments, phase not
# found, non-conforming phase_number argument, replacement verification failure); 5 - environment
# error (scripts/lib/phase-heading-patterns.sh could not be found).
#
# Logs transitions to: .agent-logs/phase-transitions.log

set -euo pipefail

task_number="${1:-}"
project_name="${2:-}"
phase_number="${3:-}"
new_status="${4:-}"

# Validate inputs
if [[ -z "$task_number" || -z "$project_name" || -z "$phase_number" || -z "$new_status" ]]; then
    echo "Usage: $0 TASK_NUMBER PROJECT_NAME PHASE_NUMBER STATUS" >&2
    echo "  STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED" >&2
    exit 1
fi

# Normalize NEW_STATUS: case-insensitive input to canonical display form (with spaces)
case "$new_status" in
    IN_PROGRESS|in_progress|IN\ PROGRESS|in\ progress)
        new_status_display="IN PROGRESS" ;;
    NOT_STARTED|not_started|NOT\ STARTED|not\ started)
        new_status_display="NOT STARTED" ;;
    COMPLETED|completed)
        new_status_display="COMPLETED" ;;
    COMPLETED_WITH_EXCLUSIONS|completed_with_exclusions|COMPLETED\ WITH\ EXCLUSIONS|completed\ with\ exclusions)
        new_status_display="COMPLETED WITH EXCLUSIONS" ;;
    PARTIAL|partial)
        new_status_display="PARTIAL" ;;
    BLOCKED|blocked)
        new_status_display="BLOCKED" ;;
    *)
        echo "Unknown status: $new_status" >&2
        echo "Valid values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED" >&2
        exit 1 ;;
esac

# Determine the script's working directory — find repo root by locating .claude/
# Script may be called from any working directory, so resolve relative to this script's location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
. "${script_dir}/deploy-root-guard.sh" || exit 1

# --- Shared phase-heading pattern library ---
# Deploy-tree-first / source-store-fallback candidate list, matching every other consumer's
# resolution of this library. Never falls through to a locally-composed pattern: a missing
# library is a loud environment error (exit 5), not a silent degradation.
phase_lib_candidates=(
    "${repo_root}/.claude/scripts/lib/phase-heading-patterns.sh"
    "${repo_root}/agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh"
)
phase_lib=""
for _candidate in "${phase_lib_candidates[@]}"; do
    if [[ -f "$_candidate" ]]; then
        phase_lib="$_candidate"
        break
    fi
done
if [[ -z "$phase_lib" ]]; then
    echo "Error: shared library phase-heading-patterns.sh not found at any of:" >&2
    for _candidate in "${phase_lib_candidates[@]}"; do
        echo "  $_candidate" >&2
    done
    exit 5
fi
# shellcheck disable=SC1090
. "$phase_lib"

# Validate the caller-supplied phase_number argument against the library's canonical bare-token
# grammar BEFORE building any lookup pattern from it. A non-conforming argument (e.g. "3a") must
# fail loudly with a named reason here, rather than silently falling through to a lookup grep
# that matches nothing and is reported merely as "phase not found" -- which would be
# indistinguishable from a genuinely absent phase number.
if ! grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$phase_number"; then
    echo "Error: phase_number argument '${phase_number}' is not a conforming phase-number token." >&2
    echo "       Expected an integer with at most one optional decimal sub-level (e.g. '3', '3.1')." >&2
    echo "       See context/formats/plan-format.md's 'Canonical phase-heading shape' subsection." >&2
    exit 1
fi

# Find plan directory (padded task number with fallback to unpadded)
padded_num=$(printf "%03d" "$task_number")
plan_dir="${repo_root}/specs/${padded_num}_${project_name}/plans"

if [[ ! -d "$plan_dir" ]]; then
    # Try unpadded (legacy)
    plan_dir="${repo_root}/specs/${task_number}_${project_name}/plans"
fi

if [[ ! -d "$plan_dir" ]]; then
    echo "Plan directory not found for task $task_number (tried padded and unpadded)" >&2
    exit 1
fi

# Get latest plan file, version-ordered (not mtime-ordered).
# Prefer the MM_{short-slug}.md convention (artifact-formats.md); highest sequence wins.
# Fall back to a plain name sort only when no conforming file exists, so legacy-named
# plans never outrank a conforming one (a plain sort would rank "implementation-001.md"
# above "02_revised.md" because "i" sorts after "0").
plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || true)
if [[ -z "$plan_file" ]]; then
    plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || true)
fi
if [[ -z "$plan_file" ]]; then
    echo "No plan file found in $plan_dir" >&2
    exit 1
fi

plan_basename=$(basename "$plan_file")

# Find the exact line number of the phase heading. Built from the library's exported
# PHASE_HEADING_PREFIX ('^### Phase ') parameterized on the validated phase_number, rather than
# from a locally-composed "^### Phase " string.
# Use || true to prevent set -e from aborting when grep finds no match (exit code 1)
line_number=$(grep -n "${PHASE_HEADING_PREFIX}${phase_number}:" "$plan_file" 2>/dev/null | head -1 | cut -d: -f1 || true)

if [[ -z "$line_number" ]]; then
    echo "Phase ${phase_number} not found in $plan_file" >&2
    exit 1
fi

# Extract current status from that line using sed capture
current_status=$(sed -n "${line_number}s/.*\[\(.*\)\]$/\1/p" "$plan_file")

if [[ -z "$current_status" ]]; then
    echo "Could not extract status from phase ${phase_number} heading in $plan_file" >&2
    echo "Line ${line_number}: $(sed -n "${line_number}p" "$plan_file")" >&2
    exit 1
fi

# Idempotency check: if current status equals target status, exit 0 silently (no-op)
if [[ "$current_status" == "$new_status_display" ]]; then
    # Already at target status, no-op
    exit 0
fi

# Replace status on the specific line (line-specific replacement to avoid touching plan-level header)
sed -i "${line_number}s/\[.*\]/[${new_status_display}]/" "$plan_file"

# Verify the replacement succeeded
updated_line=$(sed -n "${line_number}p" "$plan_file")
updated_status=$(echo "$updated_line" | sed 's/.*\[\(.*\)\]$/\1/')

if [[ "$updated_status" != "$new_status_display" ]]; then
    echo "Failed to update phase ${phase_number} status in $plan_file" >&2
    echo "Wanted '${new_status_display}', got '${updated_status}'" >&2
    exit 1
fi

# Ensure log directory exists
log_dir="${repo_root}/.agent-logs"
mkdir -p "$log_dir"
log_file="${log_dir}/phase-transitions.log"

# Append log entry: [ISO8601] task N filename.md phase P: OLD_STATUS -> NEW_STATUS
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[${timestamp}] task ${task_number} ${plan_basename} phase ${phase_number}: ${current_status} -> ${new_status_display}" >> "$log_file"

# Output the updated plan file path on success
echo "$plan_file"
