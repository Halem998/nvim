#!/usr/bin/env bash
# literature-normalize-authors.sh - Normalize the `authors` field shape in a Literature index.json
#
# Task 801 (defense-in-depth): fixes the malformed `authors` schema left behind by
# ~/Projects/Literature/scripts/migrate-from-repo.sh (a separate, external-repo script; see
# .claude/context/project/literature/domain/literature-index.md for the tooling ownership
# boundary). Canonical representation is an array of individual author strings, e.g.
# ["Patrick Blackburn", "Maarten de Rijke", "Yde Venema"] -- modeled on the correct pattern
# already used by .claude/extensions/literature/scripts/zotero-index-add.sh:142-148.
#
# Usage:
#   literature-normalize-authors.sh <index.json> [--apply|--write]
#
# By default this script runs in DRY-RUN mode: it prints a per-entry before/after diff and a
# summary count, and makes NO filesystem writes. Pass --apply (or --write) to persist changes
# in place. Re-running against an already-normalized index reports zero changes (idempotent).
#
# Normalization rules:
#   1. authors is a string                        -> normalize to an array (split on ", " only
#                                                      when the string looks like multiple joined
#                                                      full names; otherwise wrap as a single-
#                                                      element array, preserving a legitimate
#                                                      "Last, First" single-author name).
#   2. authors is a one-element array whose single
#      string looks comma-joined                   -> split that element into multiple array
#                                                      elements.
#   3. anything else (already-correct arrays,
#      multi-element arrays, null)                 -> left unchanged.
#
# The "looks comma-joined" heuristic mirrors the authors-shape check added to
# .claude/skills/skill-literature/SKILL.md Validate Step 2 (task 801) so validate and normalize
# stay consistent: flag only when a string contains 2+ ", " occurrences, or exactly one ", "
# followed by 2+ non-initial capitalized name-like tokens (2+ letters each) in the remainder.
# This avoids mis-splitting legitimate single-author "Last, First" or "Last, First M." formatting
# (e.g. "Gabbay, Dov M." or "Reynolds, Mark A.", both found correctly-shaped in the live corpus).

set -euo pipefail

usage() {
  echo "Usage: $0 <index.json> [--apply|--write]"
  echo ""
  echo "  <index.json>       Path to a Literature index.json (global or per-repo)."
  echo "  --apply, --write   Persist changes in place. Default: dry-run (no writes)."
  exit 1
}

if [ -z "${1:-}" ]; then
  usage
fi

index_file="$1"
shift || true

apply=false
for arg in "$@"; do
  case "$arg" in
    --apply|--write) apply=true ;;
    *) echo "Unknown argument: $arg" >&2; usage ;;
  esac
done

if [ ! -f "$index_file" ]; then
  echo "Error: index file not found: $index_file" >&2
  exit 1
fi

# Shared jq function definitions (single-quoted: no bash interpolation of $ inside).
defs='
def is_comma_joined:
  ( [scan(", ")] | length ) as $n
  | if $n >= 2 then true
    elif $n == 1 then
      ( (split(", ")[1]) | ([scan("[A-Z][a-zA-Z]+")] | length) ) >= 2
    else false
    end;

def normalize_string_authors:
  if is_comma_joined then split(", ") else [.] end;

def normalize_authors:
  if type == "string" then
    normalize_string_authors
  elif type == "array" and length == 1 and (.[0] | type) == "string" and (.[0] | is_comma_joined) then
    [.[0] | split(", ")[]]
  else
    .
  end;
'

diff_filter="$defs"'
.entries[] |
select(.authors != null) |
{ id: .id, before: .authors, after: (.authors | normalize_authors) } |
select(.before != .after)
'

apply_filter="$defs"'
.entries |= map(if .authors != null then .authors = (.authors | normalize_authors) else . end)
'

changes_json="$(jq -c "$diff_filter" "$index_file")"

if [ -z "$changes_json" ]; then
  echo "No authors-shape changes needed. Index is already normalized: $index_file"
  exit 0
fi

change_count="$(echo "$changes_json" | wc -l | tr -d ' ')"

if [ "$apply" = true ]; then
  mode_label="APPLY"
else
  mode_label="DRY RUN"
fi

echo "## Literature authors normalization ($mode_label)"
echo ""
echo "Index: $index_file"
echo "Entries that would change: $change_count"
echo ""
while IFS= read -r change; do
  id="$(echo "$change" | jq -r '.id')"
  before="$(echo "$change" | jq -c '.before')"
  after="$(echo "$change" | jq -c '.after')"
  echo "- $id:"
  echo "    before: $before"
  echo "    after:  $after"
done <<< "$changes_json"

if [ "$apply" = false ]; then
  echo ""
  echo "Dry run only -- no changes written. Re-run with --apply (or --write) to persist."
  exit 0
fi

echo ""
echo "Applying $change_count change(s) to $index_file ..."

tmp="$(mktemp)"
jq "$apply_filter" "$index_file" > "$tmp" && mv "$tmp" "$index_file"

echo "Done. $change_count entries normalized."
