#!/usr/bin/env bash
# Harness stub for zotero-read.sh -- only the `search` operation used by
# check_live_doi_duplicate() is implemented. Controlled via:
#   HARNESS_DEDUP_MATCH_DOI   if set and equal to the query, returns one matching item.
set -euo pipefail

op="${1:-}"
shift || true

case "$op" in
  search)
    query="${1:-}"
    if [ -n "${HARNESS_DEDUP_MATCH_DOI:-}" ] && [ "$query" = "$HARNESS_DEDUP_MATCH_DOI" ]; then
      printf '[{"key": "HARNESSDUP1", "doi": "%s"}]\n' "$query"
    else
      echo '[]'
    fi
    exit 0
    ;;
  *)
    echo "harness stub zotero-read.sh: unhandled operation: $op" >&2
    exit 1
    ;;
esac
