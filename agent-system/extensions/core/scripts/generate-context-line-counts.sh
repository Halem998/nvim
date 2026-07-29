#!/usr/bin/env bash
# generate-context-line-counts.sh - Recompute `line_count` from `wc -l` for every entry in
# every extension's SOURCE `index-entries.json`.
#
# WHY THE SOURCE STORE, NEVER THE DEPLOYED INDEX: `.claude/context/index.json` is a disposable
# deploy artifact regenerated from `agent-system/extensions/*/index-entries.json` on every
# "Load Core"/redeploy (see .claude/rules/source-store-deploy-boundary.md). A `line_count` fix
# written only to the deployed copy would be silently discarded on the next redeploy. This
# script therefore reads and (in --write mode) rewrites ONLY the source
# `agent-system/extensions/<ext>/index-entries.json` files, resolving each entry's source file
# as `agent-system/extensions/<ext>/context/<entry.path>` -- the same layout
# validate-extension-index.sh's `--check-resolution` mode already assumes.
#
# Usage:
#   bash generate-context-line-counts.sh [--check]   (default) report only, write nothing,
#                                                     exit nonzero if any entry is wrong
#   bash generate-context-line-counts.sh --write      rewrite each index-entries.json in place
#                                                     with corrected line_count values
#
# `line_count: null` and a numeric mismatch are treated identically: both recompute from
# `wc -l`. A missing source file is always reported as a problem, never silently skipped and
# never written as null.
#
# Every field other than `line_count` is left untouched; jq's `.[$i].line_count = $n` in-place
# update preserves key order and all other values exactly.

set -uo pipefail

# Same REPO_ROOT-bypass pattern as check-extension-docs.sh: the deploy-root-guard only fires
# when REPO_ROOT is unset, so a deliberate source-store invocation
# (REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh)
# works without tripping the guard.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: $EXT_DIR does not exist" >&2
  exit 1
fi

MODE="check"
case "${1:-}" in
  --write) MODE="write" ;;
  --check|"") MODE="check" ;;
  *)
    echo "Usage: $(basename "$0") [--check|--write]" >&2
    exit 2
    ;;
esac

info() { echo "  $*"; }
fail() { echo "  FAIL: $*"; }

TOTAL_ENTRIES=0
TOTAL_MISMATCH=0
TOTAL_NULL=0
TOTAL_MISSING=0
TOTAL_EXACT=0
TOTAL_CHANGED=0

for index_file in "$EXT_DIR"/*/index-entries.json; do
  [[ -f "$index_file" ]] || continue
  ext_dir="$(dirname "$index_file")"
  ext_name="$(basename "$ext_dir")"
  context_dir="$ext_dir/context"

  if ! jq -e '.entries' "$index_file" > /dev/null 2>&1; then
    fail "$ext_name: $index_file missing .entries -- skipped"
    continue
  fi

  entry_count=$(jq '.entries | length' "$index_file")
  ext_mismatch=0
  ext_null=0
  ext_missing=0
  ext_exact=0
  ext_changed=0

  # Working copy of the file's entries, updated in place across the loop when --write is active.
  updated_json="$(cat "$index_file")"

  for ((i = 0; i < entry_count; i++)); do
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + 1))
    path=$(jq -r ".entries[$i].path" "$index_file")
    declared=$(jq -r ".entries[$i].line_count" "$index_file")
    full_path="$context_dir/$path"

    if [[ ! -f "$full_path" ]]; then
      ext_missing=$((ext_missing + 1))
      TOTAL_MISSING=$((TOTAL_MISSING + 1))
      fail "$ext_name: source file missing for '$path' (expected $full_path)"
      continue
    fi

    actual=$(wc -l < "$full_path")
    actual=${actual// /}

    if [[ "$declared" == "null" ]]; then
      ext_null=$((ext_null + 1))
      TOTAL_NULL=$((TOTAL_NULL + 1))
      info "$ext_name: '$path' line_count is null, actual $actual"
    elif [[ "$declared" != "$actual" ]]; then
      ext_mismatch=$((ext_mismatch + 1))
      TOTAL_MISMATCH=$((TOTAL_MISMATCH + 1))
      info "$ext_name: '$path' mismatch: declared $declared, actual $actual"
    else
      ext_exact=$((ext_exact + 1))
      TOTAL_EXACT=$((TOTAL_EXACT + 1))
      continue
    fi

    if [[ "$MODE" == "write" ]]; then
      updated_json=$(jq --argjson i "$i" --argjson n "$actual" '.entries[$i].line_count = $n' <<< "$updated_json")
      ext_changed=$((ext_changed + 1))
      TOTAL_CHANGED=$((TOTAL_CHANGED + 1))
    fi
  done

  if [[ "$MODE" == "write" && "$ext_changed" -gt 0 ]]; then
    printf '%s\n' "$updated_json" > "$index_file"
  fi

  echo "$ext_name: $entry_count entries, $ext_exact exact, $ext_mismatch mismatch, $ext_null null, $ext_missing missing source$( [[ "$MODE" == "write" ]] && echo ", $ext_changed changed" )"
done

echo ""
echo "=== Summary ($MODE mode) ==="
echo "Total entries checked: $TOTAL_ENTRIES"
echo "Exact match: $TOTAL_EXACT"
echo "Numeric mismatch: $TOTAL_MISMATCH"
echo "Null line_count: $TOTAL_NULL"
echo "Missing source file: $TOTAL_MISSING"
if [[ "$MODE" == "write" ]]; then
  echo "Changed: $TOTAL_CHANGED"
fi

if [[ "$MODE" == "check" ]]; then
  if [[ $((TOTAL_MISMATCH + TOTAL_NULL + TOTAL_MISSING)) -gt 0 ]]; then
    echo ""
    echo "CHECK FAILED: line_count corrections needed (run with --write to apply)"
    exit 1
  else
    echo ""
    echo "CHECK PASSED: all line_count values are exact"
    exit 0
  fi
else
  if [[ $TOTAL_MISSING -gt 0 ]]; then
    echo ""
    echo "WRITE completed with $TOTAL_MISSING missing-source problem(s) that could not be fixed"
    exit 1
  fi
  exit 0
fi
