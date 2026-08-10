#!/usr/bin/env bash
# generate-context-line-counts.sh - Recompute `line_count` from `wc -l` for every entry in
# every extension's SOURCE `index-entries.json`.
#
# WHY THE SOURCE STORE, NEVER THE DEPLOYED INDEX: `.claude/context/index.json` is a disposable
# deploy artifact regenerated from `agent-system/extensions/*/index-entries.json` on every
# redeploy (see .claude/rules/source-store-deploy-boundary.md). A `line_count` fix
# written only to the deployed copy would be silently discarded on the next redeploy. This
# script therefore reads and (in --write mode) rewrites ONLY the source
# `agent-system/extensions/<ext>/index-entries.json` files, resolving each entry's source file
# as `agent-system/extensions/<ext>/context/<entry.path>` -- the same layout
# check-extension-docs.sh's Rule T (`check_index_entries_schema`) already assumes.
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
# NOTE on the "null" class: for six extensions (cslib, latex, lean, python, typst, z3) the
# `line_count` KEY is entirely absent from every entry, not merely set to a JSON `null` value --
# `jq -r '.line_count'` reports the text "null" for both cases indistinguishably, and this
# script's --check-mode census (and the research it is grounded in) reports both under the same
# "null" count for that reason. --write mode distinguishes the two internally: a present-but-
# wrong value is corrected by replacing that line; an absent key is corrected by INSERTING a new
# `"line_count": N,` line immediately after the entry's `"path"` line (which is always present
# and always the first field of every entry in every extension observed in this codebase).
#
# Every field other than `line_count` is left untouched. --write mode deliberately does NOT
# round-trip the file through `jq`'s pretty-printer: extension index-entries.json files use
# inconsistent array-formatting conventions (some compact single-line arrays, some one-element-
# per-line), and re-serializing the whole document through jq would silently reformat every
# array in the file, not just the changed line_count values -- a whitespace-only churn that
# would defeat "only line_count values changed" diff review. Instead, --write performs a
# surgical, line-oriented text substitution with awk, tracking the entry's `"path"` line (unique
# per entry within a file) to know which entry a given line_count replacement or insertion
# belongs to.

set -euo pipefail

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

  # Two TSVs of path<TAB>corrected-value: one for entries that already have a line_count key
  # (replace that line's value), one for entries where the key is entirely absent (insert a new
  # line after the entry's "path" line). Consumed by the awk pass below in --write mode; unused
  # in --check mode.
  replace_tsv="$(mktemp)"
  insert_tsv="$(mktemp)"

  for ((i = 0; i < entry_count; i++)); do
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + 1))
    path=$(jq -r ".entries[$i].path" "$index_file")
    has_key=$(jq -r ".entries[$i] | has(\"line_count\")" "$index_file")
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
      if [[ "$has_key" == "true" ]]; then
        info "$ext_name: '$path' line_count is null, actual $actual"
      else
        info "$ext_name: '$path' line_count key absent, actual $actual"
      fi
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
      if [[ "$has_key" == "true" ]]; then
        printf '%s\t%s\n' "$path" "$actual" >> "$replace_tsv"
      else
        printf '%s\t%s\n' "$path" "$actual" >> "$insert_tsv"
      fi
      ext_changed=$((ext_changed + 1))
      TOTAL_CHANGED=$((TOTAL_CHANGED + 1))
    fi
  done

  if [[ "$MODE" == "write" && "$ext_changed" -gt 0 ]]; then
    tmp_out="$(mktemp)"
    awk -v replace_file="$replace_tsv" -v insert_file="$insert_tsv" '
      BEGIN {
        while ((getline line < replace_file) > 0) {
          split(line, a, "\t")
          rep[a[1]] = a[2]
        }
        close(replace_file)
        while ((getline line < insert_file) > 0) {
          split(line, a, "\t")
          ins[a[1]] = a[2]
        }
        close(insert_file)
      }
      {
        line = $0
        if (match(line, /"path": *"/)) {
          tmp = line
          sub(/^.*"path": *"/, "", tmp)
          sub(/".*$/, "", tmp)
          curpath = tmp
          print line
          if (curpath in ins) {
            indent = line
            sub(/[^ ].*$/, "", indent)
            print indent "\"line_count\": " ins[curpath] ","
          }
          next
        }
        if ((curpath in rep) && match(line, /"line_count": *(null|[0-9]+)/)) {
          prefix = substr(line, 1, RSTART - 1)
          rest = substr(line, RSTART + RLENGTH)
          line = prefix "\"line_count\": " rep[curpath] rest
        }
        print line
      }
    ' "$index_file" > "$tmp_out"
    mv "$tmp_out" "$index_file"
  fi
  rm -f "$replace_tsv" "$insert_tsv"

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
