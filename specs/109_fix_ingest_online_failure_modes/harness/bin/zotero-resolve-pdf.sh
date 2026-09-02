#!/usr/bin/env bash
# Harness stub for zotero-resolve-pdf.sh -- avoids any real call to the local Zotero HTTP API.
# Reads the {"doc_id":..., "record":...} envelope on stdin (matching the real script's piped
# usage from literature-ingest-online.sh) and emits a canned resolution, controlled via:
#   HARNESS_RESOLVE_TIER    default "matched-no-pdf"; set to "absent" to force
#                            ONLINE_INGEST_ZOTERO_RESOLVE_FAILED
#   HARNESS_RESOLVE_KEY     default "HARNESSEXISTKEY"
#   HARNESS_RESOLVE_PATH    default "" (no PDF already attached); set to a path to exercise the
#                            corrective "already has a PDF attached" edge case
#   HARNESS_RESOLVE_DOI     default "10.5555/harness.existing"
set -euo pipefail

INPUT="$(cat)"
DOC_ID="$(jq -r '.doc_id // empty' <<<"$INPUT")"

TIER="${HARNESS_RESOLVE_TIER:-matched-no-pdf}"
KEY="${HARNESS_RESOLVE_KEY:-HARNESSEXISTKEY}"
RESOLVED_PATH="${HARNESS_RESOLVE_PATH:-}"
DOI="${HARNESS_RESOLVE_DOI:-10.5555/harness.existing}"

if [ "$TIER" = "absent" ]; then
  jq -n --arg doc_id "$DOC_ID" '{doc_id: $doc_id, tier: "absent", zotero_key: null}'
  exit 0
fi

jq -n --arg doc_id "$DOC_ID" --arg tier "$TIER" --arg key "$KEY" \
      --arg path "$RESOLVED_PATH" --arg doi "$DOI" \
  '{doc_id: $doc_id, tier: $tier, zotero_key: $key,
    resolved_path: ($path | if length > 0 then . else null end),
    zotero_doi: $doi}'
exit 0
