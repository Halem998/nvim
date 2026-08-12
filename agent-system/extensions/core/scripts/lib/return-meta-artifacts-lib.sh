#!/usr/bin/env bash
# return-meta-artifacts-lib.sh - Single source of truth for .return-meta.json artifacts-array
# path-to-type inference and bare-string normalization.
#
# Exports two functions consumed by BOTH validate-return-meta.sh (--fix mode) and the shared
# consumer chokepoint skill_read_metadata (scripts/skill-base.sh), so the two never independently
# re-derive the inference mapping and risk drifting apart:
#
#   infer_artifact_type <path>        - path-segment -> type inference (see table below)
#   normalize_artifacts_array <json>  - promotes bare-string elements to {type, path, summary}
#
# The mapping implemented here is prose-documented in one place:
# context/contracts/return-meta-artifacts-template.md's "Path-Segment Type-Inference Table"
# section. That fragment and this file must never drift independently of each other.
#
# Follows the house conventions of scripts/lib/phase-heading-patterns.sh and
# scripts/lib/task-reference-patterns.sh: source-able from either the deployed
# (.claude/scripts/lib/) or source-store (agent-system/extensions/core/scripts/lib/) copy, no
# side effects on source (defines functions/variables only; does not execute anything at source
# time).
#
# Usage: `source` this file, then call `infer_artifact_type <path>` (prints inferred type or
# empty string on stdout) or `normalize_artifacts_array <json>` (prints the normalized JSON array
# on stdout; reports on stderr whether any element was promoted, via the exported
# RETURN_META_ARTIFACTS_PROMOTED flag: "true" or "false").

# ─── Path-segment type-inference table ─────────────────────────────────────────────────────────
# Ordered: first matching segment wins. A path matching none of these segments infers no type --
# the inference never guesses.
infer_artifact_type() {
  local path="$1"
  case "$path" in
    */reports/*|reports/*)
      echo "report"
      ;;
    */plans/*|plans/*)
      echo "plan"
      ;;
    */summaries/*|summaries/*)
      echo "summary"
      ;;
    */handoffs/*|handoffs/*)
      echo "handoff"
      ;;
    *)
      echo ""
      ;;
  esac
}

# ─── Bare-string normalization ─────────────────────────────────────────────────────────────────
# Promotes each bare-string element of a JSON `artifacts` array to the object shape
# {type: <inferred>, path: <string>, summary: ""}, leaving well-formed objects untouched. Emits
# the normalized array on stdout. Sets RETURN_META_ARTIFACTS_PROMOTED to "true" if any element
# was promoted, "false" otherwise, and reports the same on stderr for a human/log reader.
#
# Requires: jq. Argument is the raw `artifacts` array as a JSON string (e.g. `jq -c '.artifacts'
# file.json`), not the whole `.return-meta.json` document.
normalize_artifacts_array() {
  local artifacts_json="$1"
  RETURN_META_ARTIFACTS_PROMOTED="false"

  if [[ -z "$artifacts_json" ]] || [[ "$artifacts_json" == "null" ]]; then
    echo "[]"
    export RETURN_META_ARTIFACTS_PROMOTED
    return 0
  fi

  local promoted_count
  promoted_count=$(echo "$artifacts_json" | jq '[.[] | select(type == "string")] | length' 2>/dev/null || echo 0)

  if [[ "$promoted_count" -gt 0 ]]; then
    RETURN_META_ARTIFACTS_PROMOTED="true"
    echo "[normalize_artifacts_array] promoted ${promoted_count} bare-string element(s) to object shape" >&2
  fi

  # For each element: if it's a string, infer the type from its path segment (bash-side, so the
  # single inference mapping above is reused rather than re-derived in jq) and build the object;
  # if it's already an object, pass through unchanged.
  local out="[]"
  local i len el el_type
  len=$(echo "$artifacts_json" | jq 'length')
  for ((i = 0; i < len; i++)); do
    el=$(echo "$artifacts_json" | jq -c ".[$i]")
    if echo "$el" | jq -e 'type == "string"' >/dev/null 2>&1; then
      local raw_path
      raw_path=$(echo "$el" | jq -r '.')
      el_type=$(infer_artifact_type "$raw_path")
      el=$(jq -cn --arg type "$el_type" --arg path "$raw_path" \
        --arg summary "(auto-repaired: type inferred from path segment; original element was a bare string)" \
        '{type: $type, path: $path, summary: $summary}')
    fi
    out=$(echo "$out" | jq -c --argjson el "$el" '. + [$el]')
  done

  echo "$out"
  export RETURN_META_ARTIFACTS_PROMOTED
}
