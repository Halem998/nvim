#!/usr/bin/env bash
# zotero-export-status.sh - Classify whether $LITERATURE_DIR/zotero-library.json is present,
# and if not, whether assisted generation (zotero-generate-export.sh) is possible.
#
# Usage:
#   zotero-export-status.sh [--output <path>] [--orchestrator-mode true|false]
#
# Purpose:
#   AskUserQuestion cannot be issued from inside a shell script, so this classifier (modeled
#   directly on literature-lit-flag-resolve.sh) owns only the deterministic state
#   classification. It prints exactly one directive token on stdout; the calling command
#   (/literature Mode A discover, Phase 3 wiring) branches on that token and is responsible
#   for issuing AskUserQuestion when interactive, or taking the visible logged default when
#   `--orchestrator-mode true`. Human-readable rationale is written to stderr on every branch
#   so the caller can surface a visible notice without polluting the stdout directive.
#
#   Freshness of an EXISTING export is delegated entirely to the shared
#   zotero-export-freshness.sh helper -- this script never re-derives the sqlite-vs-export
#   timestamp comparison itself. That helper's four-token vocabulary (FRESH / STALE /
#   FRESHNESS_UNKNOWN / FRESHNESS_ABSENT) folds into just two outcomes here: FRESH becomes
#   ZOTERO_EXPORT_PRESENT, and everything else about an existing export (STALE,
#   FRESHNESS_UNKNOWN, or the helper failing/producing nothing recognized) becomes
#   ZOTERO_EXPORT_STALE. This narrows ZOTERO_EXPORT_PRESENT's meaning to "present AND
#   confirmed fresh" -- it is never emitted on a helper failure.
#
# Directives (stdout, exactly one line, no other output on stdout):
#   ZOTERO_EXPORT_PRESENT           A zotero-library.json export exists at the resolved path
#                                   AND is confirmed fresh (see zotero-export-freshness.sh) --
#                                   freshness is delegated to that shared helper, never
#                                   re-derived here. No offer needed; proceed to the main
#                                   discover pass as today.
#   ZOTERO_EXPORT_STALE             An export exists at the resolved path, but
#                                   zotero-export-freshness.sh reports it is either STALE or
#                                   FRESHNESS_UNKNOWN (no sqlite to compare against), or the
#                                   helper itself failed/produced no recognized token. All
#                                   three cases fold into this single directive -- covers
#                                   everything about an EXISTING export other than confirmed
#                                   freshness. Never silently PRESENT.
#   ZOTERO_EXPORT_MISSING_RUNNING   Export is missing, but the Zotero local API is reachable
#                                   (Zotero is running) -- Path 1 (and possibly Path 2, if
#                                   Better BibTeX is also installed) of
#                                   zotero-generate-export.sh are viable.
#   ZOTERO_EXPORT_MISSING_NOT_RUNNING
#                                   Export is missing, the Zotero local API is NOT reachable,
#                                   but the resolved Zotero sqlite file (see ZOTERO_SQLITE_PATH
#                                   below) is present -- Path 3 (sqlite reconstruction, Zotero
#                                   closed) is viable. The caller's offer text should also note
#                                   the user may open Zotero instead for the richer API path.
#   ZOTERO_EXPORT_UNAVAILABLE       Export is missing and no local Zotero data source was
#                                   found at all (API unreachable AND no zotero.sqlite). No
#                                   offer; the caller should surface the zotero-search.sh
#                                   manual-steps text instead.
#
# Inputs:
#   --output <path>                   Resolved output/library path to check. If omitted, the
#                                      same resolve_library_path() order used by
#                                      zotero-search.sh and zotero-generate-export.sh applies:
#                                        1. $ZOTERO_LIBRARY
#                                        2. $LITERATURE_DIR/zotero-library.json
#                                        3. ~/Projects/Literature/zotero-library.json
#   --orchestrator-mode <true|false>  Value of the orchestrator_mode delegation-context field.
#                                      Does NOT change which of the five directives is
#                                      emitted (classification is purely about data-source
#                                      state) -- it is echoed into the stderr rationale only,
#                                      so the caller's downstream branch (interactive prompt
#                                      vs. visible autonomous default) can be logged
#                                      consistently with the --lit precedent.
#   LITERATURE_DIR (env)               Path to the global Literature/ repo
#                                      (default: ~/Projects/Literature).
#   ZOTERO_LIBRARY (env)               Explicit library path override (tier 1 above).
#   ZOTERO_SQLITE_PATH (env)           Override for the Path 3 sqlite probe, mirroring
#                                      zotero-generate-export.sh. If unset, the sqlite path is
#                                      resolved by zotero-resolve-sqlite-path.sh: (1) this env
#                                      override; (2) <dataDir>/zotero.sqlite auto-detected from
#                                      the default Zotero profile's prefs.js when
#                                      extensions.zotero.useDataDir=true; (3)
#                                      ~/Zotero/zotero.sqlite default.
#
# NOTE (latent inconsistency, not fixed here): literature-discover.sh's tier2_search() only
# ever checks `$LITERATURE_DIR/zotero-library.json`, not the full resolve_library_path()
# chain that zotero-search.sh (and this classifier, and the generator) honor. This classifier
# deliberately uses the FULL resolve_library_path() chain so the offer and the generator
# agree with zotero-search.sh; it does not attempt to fix literature-discover.sh's narrower
# check, per the task-797 plan's explicit non-goal.
#
# AskUserQuestion is NEVER issued by this script -- that remains the caller's responsibility.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH" >&2
  exit 1
fi

API_BASE="http://127.0.0.1:23119/api/users/0/items"
ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"

# --- Argument parsing ---
output_path=""
orchestrator_mode="false"

show_usage() {
  cat >&2 << 'USAGE'
USAGE:
  zotero-export-status.sh [--output <path>] [--orchestrator-mode true|false]

Prints exactly one directive token to stdout: ZOTERO_EXPORT_PRESENT, ZOTERO_EXPORT_STALE,
ZOTERO_EXPORT_MISSING_RUNNING, ZOTERO_EXPORT_MISSING_NOT_RUNNING, or
ZOTERO_EXPORT_UNAVAILABLE. Rationale is written to stderr. Never calls AskUserQuestion.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --output)
      output_path="${2:-}"
      shift 2
      ;;
    --orchestrator-mode)
      orchestrator_mode="${2:-false}"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo "Warning: unrecognized argument '$1' ignored" >&2
      shift
      ;;
  esac
done

if [ "$orchestrator_mode" != "true" ] && [ "$orchestrator_mode" != "false" ]; then
  echo "Error: --orchestrator-mode must be 'true' or 'false', got: $orchestrator_mode" >&2
  exit 2
fi

# --- Resolve library path (same order as zotero-search.sh / zotero-generate-export.sh) ---
resolve_library_path() {
  if [ -n "${ZOTERO_LIBRARY:-}" ]; then
    echo "$ZOTERO_LIBRARY"
    return
  fi
  if [ -n "${LITERATURE_DIR:-}" ]; then
    echo "${LITERATURE_DIR}/zotero-library.json"
    return
  fi
  echo "${HOME}/Projects/Literature/zotero-library.json"
}

if [ -z "$output_path" ]; then
  output_path="$(resolve_library_path)"
fi

# --- Classification ---
if [ -f "$output_path" ]; then
  # Freshness is delegated entirely to the shared helper. Capture-guarded against
  # `set -e`: a non-zero exit or empty/unrecognized output from the helper must never abort
  # this script, and must never be silently treated as PRESENT/fresh.
  freshness_stderr="$(mktemp)"
  freshness_token="$("$SCRIPT_DIR/zotero-export-freshness.sh" --library "$output_path" 2>"$freshness_stderr")" || freshness_token=""
  freshness_rationale="$(cat "$freshness_stderr")"
  rm -f "$freshness_stderr"

  case "$freshness_token" in
    ZOTERO_EXPORT_FRESH)
      echo "Rationale: zotero-library.json present at $output_path and confirmed fresh by zotero-export-freshness.sh (orchestrator-mode=$orchestrator_mode). ${freshness_rationale}" >&2
      echo "ZOTERO_EXPORT_PRESENT"
      exit 0
      ;;
    ZOTERO_EXPORT_STALE|ZOTERO_EXPORT_FRESHNESS_UNKNOWN)
      echo "Rationale: zotero-library.json present at $output_path but NOT confirmed fresh (zotero-export-freshness.sh reported $freshness_token; orchestrator-mode=$orchestrator_mode). ${freshness_rationale}" >&2
      echo "ZOTERO_EXPORT_STALE"
      exit 0
      ;;
    *)
      echo "Rationale: zotero-library.json present at $output_path, but zotero-export-freshness.sh failed or returned an unrecognized token ('${freshness_token}'); treating as not-confirmed-fresh rather than silently PRESENT (orchestrator-mode=$orchestrator_mode). Helper stderr: ${freshness_rationale}" >&2
      echo "ZOTERO_EXPORT_STALE"
      exit 0
      ;;
  esac
fi

probe_zotero_api() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 \
    "${API_BASE}?format=csljson&limit=1" 2>/dev/null)" || code=""
  if [ -z "$code" ]; then
    code="000"
  fi
  echo "$code"
}

api_code="$(probe_zotero_api)"

if [ "$api_code" = "200" ]; then
  echo "Rationale: no export at $output_path, but the Zotero local API responded ($api_code) at $API_BASE (orchestrator-mode=$orchestrator_mode); Path 1 (and Path 2 if Better BibTeX is installed) of zotero-generate-export.sh are viable now." >&2
  echo "ZOTERO_EXPORT_MISSING_RUNNING"
  exit 0
fi

if [ -f "$ZOTERO_SQLITE" ]; then
  echo "Rationale: no export at $output_path and the Zotero local API is not reachable (probe returned $api_code), but $ZOTERO_SQLITE is present (orchestrator-mode=$orchestrator_mode); Path 3 (sqlite reconstruction, Zotero closed) of zotero-generate-export.sh is viable. The user may alternatively start Zotero for the richer live API path." >&2
  echo "ZOTERO_EXPORT_MISSING_NOT_RUNNING"
  exit 0
fi

echo "Rationale: no export at $output_path, the Zotero local API is not reachable (probe returned $api_code), and no zotero.sqlite was found at $ZOTERO_SQLITE (orchestrator-mode=$orchestrator_mode); no local Zotero data source is available at all, so assisted generation cannot be offered." >&2
echo "ZOTERO_EXPORT_UNAVAILABLE"
exit 0
