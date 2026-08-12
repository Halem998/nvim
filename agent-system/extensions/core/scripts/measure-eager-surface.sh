#!/usr/bin/env bash
# measure-eager-surface.sh - Reproducible byte-accounting harness for the session-start eager
# context prefix, and for the source-store `claudemd` merge sources that compose the deployed
# `.claude/CLAUDE.md`.
#
# WHY THIS EXISTS: a "slimmed the eager surface" claim is unverifiable without a fixed,
# reproducible composition to measure before and after. This script encodes exactly that
# composition so every phase of a cut measures the SAME nine-file eager-prefix set (apples to
# apples), rather than each phase inventing its own ad hoc `wc -c` invocation.
#
# THE NINE-FILE EAGER PREFIX (a `specs/**`-touching session loads all nine unconditionally):
#   1. The parent config CLAUDE.md, one directory above the repo root (this repo is nested under
#      a broader `~/.config/` project; the parent file is a Claude Code standards-discovery
#      import, not part of this repo's own tracked tree). If this repo is not nested under a
#      parent CLAUDE.md, this file is reported as absent (0 B) rather than erroring -- the
#      accounting is specific to this deployment's directory layout and is not assumed portable.
#   2. This repo's own root CLAUDE.md.
#   3. The deployed `.claude/CLAUDE.md` (the assembled merge target this whole task cuts).
#   4-9. Six core rules whose `paths:` frontmatter glob matches any `specs/**` touch:
#        artifact-formats.md, git-workflow.md, no-task-references-in-deliverables.md,
#        pr-prohibition.md, source-store-deploy-boundary.md, state-management.md.
#
# SEPARATELY (not part of the eager-prefix total, but reported alongside it): the assembled
# `.claude/CLAUDE.md` size on its own, and the byte size of every source-store `claudemd` merge
# source -- shape-(a) `merge-sources/claudemd.md` (currently `core`, `literature`) and shape-(b)
# `EXTENSION.md` (every other loaded extension), resolved manifest-authoritatively via
# `.merge_targets.claudemd.source`, mirroring `check-extension-docs.sh`'s `claudemd_source_for`.
#
# Usage:
#   bash measure-eager-surface.sh                     Print the table + totals to stdout.
#   bash measure-eager-surface.sh --baseline <path>    Also write a JSON snapshot to <path>.
#   bash measure-eager-surface.sh --compare <path>     Re-measure now, diff against the JSON
#                                                       snapshot at <path>, print a before/after
#                                                       delta table (one row per file present in
#                                                       either measurement).
#
# --baseline and --compare are mutually exclusive; passing neither just prints the current
# measurement. Exit code is always 0 (this is a reporting tool, not a lint gate); Phase 1's own
# acceptance check compares the printed total against the expected 70,160 B by hand/CI, not via
# this script's exit code.

set -uo pipefail

[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"

MODE=""
SNAPSHOT_PATH=""
case "${1:-}" in
  --baseline)
    MODE="baseline"
    SNAPSHOT_PATH="${2:-}"
    [[ -n "$SNAPSHOT_PATH" ]] || { echo "ERROR: --baseline requires a path argument" >&2; exit 1; }
    ;;
  --compare)
    MODE="compare"
    SNAPSHOT_PATH="${2:-}"
    [[ -n "$SNAPSHOT_PATH" ]] || { echo "ERROR: --compare requires a path argument" >&2; exit 1; }
    [[ -f "$SNAPSHOT_PATH" ]] || { echo "ERROR: snapshot file not found: $SNAPSHOT_PATH" >&2; exit 1; }
    ;;
  "") ;;
  *)
    echo "ERROR: unrecognized argument '${1:-}' (expected --baseline <path> or --compare <path>)" >&2
    exit 1
    ;;
esac

bytes_of() {
  # Prints 0 (not an error) for a missing file -- absence is reported, not fatal.
  local f="$1"
  if [[ -f "$f" ]]; then
    wc -c < "$f" | tr -d ' '
  else
    echo 0
  fi
}

# --- 1. Eager-prefix set (nine files) ---------------------------------------------------------

PARENT_CLAUDE_MD="$(dirname "$REPO_ROOT")/CLAUDE.md"
ROOT_CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
ASSEMBLED_CLAUDE_MD="$REPO_ROOT/.claude/CLAUDE.md"

RULE_NAMES=(
  artifact-formats.md
  git-workflow.md
  no-task-references-in-deliverables.md
  pr-prohibition.md
  source-store-deploy-boundary.md
  state-management.md
)

declare -a EAGER_PATHS=("$PARENT_CLAUDE_MD" "$ROOT_CLAUDE_MD" "$ASSEMBLED_CLAUDE_MD")
declare -a EAGER_LABELS=("parent CLAUDE.md" "repo CLAUDE.md" ".claude/CLAUDE.md (assembled)")
for r in "${RULE_NAMES[@]}"; do
  EAGER_PATHS+=("$REPO_ROOT/.claude/rules/$r")
  EAGER_LABELS+=(".claude/rules/$r")
done

EAGER_TOTAL=0
declare -a EAGER_BYTES=()
for p in "${EAGER_PATHS[@]}"; do
  b=$(bytes_of "$p")
  EAGER_BYTES+=("$b")
  EAGER_TOTAL=$((EAGER_TOTAL + b))
done

# --- 2. Assembled .claude/CLAUDE.md on its own -------------------------------------------------

ASSEMBLED_BYTES=$(bytes_of "$ASSEMBLED_CLAUDE_MD")

# --- 3. Per-extension source-store claudemd merge source ---------------------------------------

declare -a MS_NAMES=()
declare -a MS_PATHS=()
declare -a MS_BYTES=()

if [[ -d "$EXT_DIR" ]]; then
  for ext_path in "$EXT_DIR"/*/; do
    ext_name=$(basename "$ext_path")
    manifest="$ext_path/manifest.json"
    [[ -f "$manifest" ]] || continue
    jq empty "$manifest" 2>/dev/null || continue
    source_rel=$(jq -r '.merge_targets.claudemd.source // empty' "$manifest" 2>/dev/null)
    [[ -n "$source_rel" ]] || continue
    source_abs="$ext_path/$source_rel"
    MS_NAMES+=("$ext_name")
    MS_PATHS+=("agent-system/extensions/$ext_name/$source_rel")
    MS_BYTES+=("$(bytes_of "$source_abs")")
  done
fi

# --- Output --------------------------------------------------------------------------------

print_table() {
  echo "Eager-prefix set (nine files, loaded unconditionally on any specs/**-touching session):"
  local i
  for ((i = 0; i < ${#EAGER_PATHS[@]}; i++)); do
    printf "  %-45s %8s B\n" "${EAGER_LABELS[$i]}" "${EAGER_BYTES[$i]}"
  done
  printf "  %-45s %8s B\n" "TOTAL (eager prefix)" "$EAGER_TOTAL"
  echo
  echo "Assembled .claude/CLAUDE.md (subset of the above, reported standalone):"
  printf "  %-45s %8s B\n" ".claude/CLAUDE.md" "$ASSEMBLED_BYTES"
  echo
  echo "Source-store claudemd merge sources (per loaded/available extension):"
  local j
  for ((j = 0; j < ${#MS_NAMES[@]}; j++)); do
    printf "  %-20s %-45s %8s B\n" "${MS_NAMES[$j]}" "${MS_PATHS[$j]}" "${MS_BYTES[$j]}"
  done
}

write_json() {
  local out="$1"
  {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"eager_prefix\": {"
    echo "    \"files\": ["
    local i
    for ((i = 0; i < ${#EAGER_PATHS[@]}; i++)); do
      local rel="${EAGER_PATHS[$i]#"$REPO_ROOT"/}"
      printf '      {"label": %s, "path": %s, "bytes": %s}%s\n' \
        "$(jq -Rn --arg s "${EAGER_LABELS[$i]}" '$s')" \
        "$(jq -Rn --arg s "$rel" '$s')" \
        "${EAGER_BYTES[$i]}" \
        "$([[ $i -lt $((${#EAGER_PATHS[@]} - 1)) ]] && echo ,)"
    done
    echo "    ],"
    echo "    \"total_bytes\": $EAGER_TOTAL"
    echo "  },"
    echo "  \"assembled_claude_md_bytes\": $ASSEMBLED_BYTES,"
    echo "  \"merge_sources\": {"
    local j
    for ((j = 0; j < ${#MS_NAMES[@]}; j++)); do
      printf '    %s: {"path": %s, "bytes": %s}%s\n' \
        "$(jq -Rn --arg s "${MS_NAMES[$j]}" '$s')" \
        "$(jq -Rn --arg s "${MS_PATHS[$j]}" '$s')" \
        "${MS_BYTES[$j]}" \
        "$([[ $j -lt $((${#MS_NAMES[@]} - 1)) ]] && echo ,)"
    done
    echo "  }"
    echo "}"
  } > "$out"
}

print_compare() {
  local snapshot="$1"
  echo "Before/after delta (baseline: $snapshot)"
  echo
  printf "  %-45s %10s %10s %10s\n" "FILE" "BEFORE" "AFTER" "DELTA"
  local i
  for ((i = 0; i < ${#EAGER_PATHS[@]}; i++)); do
    local rel="${EAGER_PATHS[$i]#"$REPO_ROOT"/}"
    local before after delta
    before=$(jq -r --arg p "$rel" '.eager_prefix.files[] | select(.path == $p) | .bytes' "$snapshot" 2>/dev/null)
    [[ -n "$before" ]] || before=0
    after="${EAGER_BYTES[$i]}"
    delta=$((after - before))
    printf "  %-45s %10s %10s %10s\n" "${EAGER_LABELS[$i]}" "$before" "$after" "$delta"
  done
  local before_total after_total delta_total
  before_total=$(jq -r '.eager_prefix.total_bytes' "$snapshot" 2>/dev/null)
  [[ -n "$before_total" && "$before_total" != "null" ]] || before_total=0
  after_total="$EAGER_TOTAL"
  delta_total=$((after_total - before_total))
  printf "  %-45s %10s %10s %10s\n" "TOTAL (eager prefix)" "$before_total" "$after_total" "$delta_total"
  echo
  local assembled_before assembled_after assembled_delta
  assembled_before=$(jq -r '.assembled_claude_md_bytes' "$snapshot" 2>/dev/null)
  [[ -n "$assembled_before" && "$assembled_before" != "null" ]] || assembled_before=0
  assembled_after="$ASSEMBLED_BYTES"
  assembled_delta=$((assembled_after - assembled_before))
  printf "  %-45s %10s %10s %10s\n" ".claude/CLAUDE.md (assembled)" "$assembled_before" "$assembled_after" "$assembled_delta"
  echo
  echo "Merge sources:"
  local j
  for ((j = 0; j < ${#MS_NAMES[@]}; j++)); do
    local ms_before ms_after ms_delta
    ms_before=$(jq -r --arg n "${MS_NAMES[$j]}" '.merge_sources[$n].bytes // empty' "$snapshot" 2>/dev/null)
    [[ -n "$ms_before" ]] || ms_before=0
    ms_after="${MS_BYTES[$j]}"
    ms_delta=$((ms_after - ms_before))
    printf "  %-45s %10s %10s %10s\n" "${MS_NAMES[$j]}" "$ms_before" "$ms_after" "$ms_delta"
  done
}

case "$MODE" in
  baseline)
    print_table
    write_json "$SNAPSHOT_PATH"
    echo
    echo "Baseline snapshot written to: $SNAPSHOT_PATH"
    ;;
  compare)
    print_compare "$SNAPSHOT_PATH"
    ;;
  *)
    print_table
    ;;
esac
