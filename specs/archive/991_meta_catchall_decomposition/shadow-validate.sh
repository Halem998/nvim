#!/usr/bin/env bash
# shadow-validate.sh -- redeploy-free harness for running the SOURCE-STORE copy of
# validate-context-budgets.sh against a reconstruction of the merged context index.
#
# Why this exists:
#   `bash .claude/scripts/validate-context-budgets.sh` reads the DEPLOYED index and runs the
#   DEPLOYED validator; neither reflects a source-store edit until a redeploy runs. Running the
#   source-store copy directly is refused by deploy-root-guard.sh by design, and regenerating the
#   deploy tree is a manual/operator action (see context/patterns/regeneration-is-manual-only.md),
#   with exactly one sanctioned automated caller that this harness is not.
#
# What it does:
#   1. Reads the ACTIVE extension list live from .claude-extensions.json (never hardcoded).
#   2. Concatenates those extensions' agent-system/extensions/<ext>/index-entries.json entries
#      into a shadow merged index. This is equivalent to merge.lua's append_index_entries (an
#      upsert by `path`) ONLY while no two active extensions declare the same path -- so the
#      harness asserts zero duplicate paths and aborts loudly otherwise.
#   3. Assembles a shadow deploy tree whose scripts/ parent basename is `.claude`, which is what
#      deploy-root-guard.sh structurally requires, and drops the SOURCE-STORE validator into it.
#   4. Runs the validator with --index pointed at the shadow index, preserving its exit code.
#
# Usage: bash specs/991_meta_catchall_decomposition/shadow-validate.sh [--verbose]
#        [--check-identity]   also diff the reconstructed path set against the deployed index
#
# Exit code: the validator's own exit code (or 2 on a harness precondition failure).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${REPO_ROOT}/agent-system/extensions"
DEPLOYED_INDEX="${REPO_ROOT}/.claude/context/index.json"

VERBOSE_ARGS=()
CHECK_IDENTITY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE_ARGS+=(--verbose); shift ;;
    --check-identity) CHECK_IDENTITY=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/shadow-validate.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# --- 1. active extensions, read live -----------------------------------------------------------
mapfile -t ACTIVE < <(jq -r '.extensions | to_entries[] | select(.value.status == "active") | .key' \
  "${REPO_ROOT}/.claude-extensions.json")
if [[ ${#ACTIVE[@]} -eq 0 ]]; then
  echo "HARNESS ERROR: no active extensions found in .claude-extensions.json" >&2
  exit 2
fi
echo "Active extensions: ${ACTIVE[*]}" >&2

SOURCES=()
for ext in "${ACTIVE[@]}"; do
  f="${SRC}/${ext}/index-entries.json"
  if [[ -f "$f" ]]; then
    SOURCES+=("$f")
  else
    echo "HARNESS NOTE: active extension '${ext}' has no index-entries.json (skipped)" >&2
  fi
done

# --- 2. reconstruct the merged index -----------------------------------------------------------
SHADOW_INDEX="${WORK}/index.json"
jq -s '{version: "1.0.0", generated: "shadow", entries: [.[].entries[]]}' "${SOURCES[@]}" \
  > "$SHADOW_INDEX" || { echo "HARNESS ERROR: reconstruction failed" >&2; exit 2; }

# --- 2a. duplicate-path assertion --------------------------------------------------------------
dupes=$(jq -r '[.entries[].path] | group_by(.) | map(select(length > 1)) | .[][0]' "$SHADOW_INDEX")
if [[ -n "$dupes" ]]; then
  echo "HARNESS ERROR: duplicate paths in the reconstruction -- concatenation is no longer" >&2
  echo "               equivalent to the loader's upsert-by-path merge:" >&2
  echo "$dupes" | sed 's/^/  /' >&2
  exit 2
fi
shadow_count=$(jq '.entries | length' "$SHADOW_INDEX")
echo "Reconstructed entries: ${shadow_count} (0 duplicate paths)" >&2

# --- 2b. optional path-set identity gate against the deployed index ----------------------------
if [[ "$CHECK_IDENTITY" == "true" ]]; then
  if [[ ! -f "$DEPLOYED_INDEX" ]]; then
    echo "HARNESS ERROR: deployed index not found at $DEPLOYED_INDEX" >&2
    exit 2
  fi
  if diff <(jq -r '.entries[].path' "$SHADOW_INDEX" | sort) \
          <(jq -r '.entries[].path' "$DEPLOYED_INDEX" | sort) > "${WORK}/pathdiff"; then
    echo "Path-set identity vs deployed index: OK" >&2
  else
    echo "HARNESS ERROR: reconstructed path set differs from the deployed index:" >&2
    sed 's/^/  /' "${WORK}/pathdiff" >&2
    exit 2
  fi
fi

# --- 3. shadow deploy tree ---------------------------------------------------------------------
# deploy-root-guard.sh requires the scripts/ parent directory to be named `.claude`.
SHADOW_SCRIPTS="${WORK}/tree/.claude/scripts"
mkdir -p "${SHADOW_SCRIPTS}/lib"
cp "${SRC}/core/scripts/deploy-root-guard.sh" "${SHADOW_SCRIPTS}/"
cp "${SRC}/core/scripts/lib/common.sh" "${SHADOW_SCRIPTS}/lib/"
cp "${SRC}/core/scripts/validate-context-budgets.sh" "${SHADOW_SCRIPTS}/"

# --- 4. run ------------------------------------------------------------------------------------
bash "${SHADOW_SCRIPTS}/validate-context-budgets.sh" --index "$SHADOW_INDEX" "${VERBOSE_ARGS[@]}"
exit $?
