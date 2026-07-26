#!/usr/bin/env bash
# zotero-export-freshness.sh - Classify whether $LITERATURE_DIR/zotero-library.json is fresh
# relative to the user's live Zotero sqlite database, or whether that comparison cannot be made.
#
# Usage:
#   zotero-export-freshness.sh [--library <path>]
#
# Purpose:
#   A stale Better CSL-JSON export (generated once, never auto-refreshing -- see
#   zotero-generate-export.sh's "Keep updated" note) currently produces a confident, clean,
#   wrong "not in your library" negative: nothing anywhere compares the export's age against
#   the live Zotero database it was snapshotted from. This classifier is the single shared
#   freshness helper consumed identically by zotero-export-status.sh (which folds its two
#   non-fresh tokens below into one narrower ZOTERO_EXPORT_STALE directive of its own four-token
#   vocabulary) and zotero-search.sh (which treats anything but a clean FRESH result as
#   "not confirmed fresh" and banners accordingly). It prints exactly one directive token on
#   stdout; all rationale (both compared epochs, both human-readable dates, and which
#   reference-timestamp source was used) goes to stderr.
#
# Directives (stdout, exactly one line, no other output on stdout, exit 0 for all four):
#   ZOTERO_EXPORT_FRESH               The resolved reference timestamp (see below) is >= the
#                                      resolved Zotero sqlite file's mtime -- the export was
#                                      generated at or after the live database's last write.
#   ZOTERO_EXPORT_STALE               The reference timestamp is < the resolved sqlite file's
#                                      mtime -- the live database has been written to since the
#                                      export was generated.
#   ZOTERO_EXPORT_FRESHNESS_UNKNOWN    The export file is present, but no sqlite file was found
#                                      at the resolved path to compare against, so freshness
#                                      cannot be determined either way. Never reported as FRESH.
#   ZOTERO_EXPORT_FRESHNESS_ABSENT     No export file exists at the resolved library path at
#                                      all -- there is nothing to classify the freshness of.
#
# NOTE on token spelling: zotero-export-status.sh's own directive vocabulary also spells one of
# its tokens "ZOTERO_EXPORT_STALE". This is intentional, not an accidental collision to be
# renamed -- that classifier folds this script's STALE and FRESHNESS_UNKNOWN results into its
# single narrower STALE token (both mean "not confirmed fresh, offer regeneration"), and the two
# scripts are never compared against each other's raw stdout in the same conditional.
#
# Reference timestamp resolution (first match wins):
#   1. <dirname of resolved library>/.zotero-library.meta.json's "._generated" field, if the
#      file exists and jq can extract a non-empty value that `date -d` can also parse.
#   2. The resolved library file's own mtime (`stat -c %Y`), used whenever the meta stamp is
#      absent, empty, or unparseable. Which source was used is always named on stderr.
#
# Inputs:
#   --library <path>   Resolved library path to check. If omitted, the same resolve_library_path()
#                       three-tier order used by zotero-search.sh applies:
#                         1. $ZOTERO_LIBRARY
#                         2. $LITERATURE_DIR/zotero-library.json
#                         3. ~/Projects/Literature/zotero-library.json
#   LITERATURE_DIR (env)     Path to the global Literature/ repo (default: ~/Projects/Literature).
#   ZOTERO_LIBRARY (env)     Explicit library path override (tier 1 above).
#   ZOTERO_SQLITE_PATH (env) Override consumed by zotero-resolve-sqlite-path.sh (unmodified,
#                             not duplicated here) when resolving the sqlite file to compare
#                             against.
#
# Non-zero exits are reserved for usage/dependency errors ONLY (missing jq, bad argument) --
# mirroring zotero-export-status.sh's exit 1/2 convention. All four classification outcomes
# above exit 0. AskUserQuestion is NEVER issued by this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH" >&2
  exit 1
fi

# --- Argument parsing ---
library_path=""

show_usage() {
  cat >&2 << 'USAGE'
USAGE:
  zotero-export-freshness.sh [--library <path>]

Prints exactly one directive token to stdout: ZOTERO_EXPORT_FRESH, ZOTERO_EXPORT_STALE,
ZOTERO_EXPORT_FRESHNESS_UNKNOWN, or ZOTERO_EXPORT_FRESHNESS_ABSENT. Rationale (compared
timestamps and their source) is written to stderr. Never calls AskUserQuestion.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --library)
      library_path="${2:-}"
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

# --- Resolve library path (verbatim copy of zotero-search.sh's resolve_library_path();
# deliberate duplication, consistent with the existing copies in zotero-export-status.sh and
# zotero-generate-export.sh -- not factored out) ---
resolve_library_path() {
  # Tier 1: ZOTERO_LIBRARY env var
  if [[ -n "${ZOTERO_LIBRARY:-}" ]]; then
    echo "$ZOTERO_LIBRARY"
    return
  fi

  # Tier 2: $LITERATURE_DIR/zotero-library.json
  if [[ -n "${LITERATURE_DIR:-}" ]]; then
    echo "${LITERATURE_DIR}/zotero-library.json"
    return
  fi

  # Tier 3: ~/Projects/Literature/zotero-library.json
  echo "${HOME}/Projects/Literature/zotero-library.json"
}

if [ -z "$library_path" ]; then
  library_path="$(resolve_library_path)"
fi

# --- Classification ---

if [ ! -f "$library_path" ]; then
  echo "Rationale: no export file at $library_path; nothing to classify the freshness of." >&2
  echo "ZOTERO_EXPORT_FRESHNESS_ABSENT"
  exit 0
fi

# Reference timestamp resolution is computed unconditionally (it never depends on the sqlite
# file being present) so that even the FRESHNESS_UNKNOWN branch below can name the export's own
# date in its rationale -- callers that want to render a "[... - export: DATE, sqlite: ...]"
# style banner should never have to re-derive this themselves.
meta_path="$(dirname "$library_path")/.zotero-library.meta.json"
reference_epoch=""
reference_source=""

if [ -f "$meta_path" ]; then
  generated_raw="$(jq -r '._generated // empty' "$meta_path" 2>/dev/null)" || generated_raw=""
  if [ -n "$generated_raw" ]; then
    generated_epoch="$(date -d "$generated_raw" +%s 2>/dev/null)" || generated_epoch=""
    if [ -n "$generated_epoch" ]; then
      reference_epoch="$generated_epoch"
      reference_source="meta stamp _generated=$generated_raw ($meta_path)"
    else
      echo "Rationale: $meta_path's _generated value '$generated_raw' could not be parsed by date -d; falling back to the export file's own mtime." >&2
    fi
  fi
fi

if [ -z "$reference_epoch" ]; then
  reference_epoch="$(stat -c %Y "$library_path")"
  if [ -z "$reference_source" ]; then
    reference_source="export file mtime (no usable meta stamp at $meta_path)"
  fi
fi

reference_human="$(date -d "@$reference_epoch" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "epoch $reference_epoch")"
reference_date="$(date -d "@$reference_epoch" '+%Y-%m-%d' 2>/dev/null || echo "unknown")"

ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"

if [ ! -f "$ZOTERO_SQLITE" ]; then
  echo "Rationale: export present at $library_path with reference timestamp $reference_human (epoch $reference_epoch, source: $reference_source; export_date=$reference_date), but no Zotero sqlite file was found at the resolved path $ZOTERO_SQLITE to compare against; freshness cannot be determined." >&2
  echo "ZOTERO_EXPORT_FRESHNESS_UNKNOWN"
  exit 0
fi

sqlite_epoch="$(stat -c %Y "$ZOTERO_SQLITE")"
sqlite_human="$(date -d "@$sqlite_epoch" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "epoch $sqlite_epoch")"
sqlite_date="$(date -d "@$sqlite_epoch" '+%Y-%m-%d' 2>/dev/null || echo "unknown")"

if [ "$reference_epoch" -ge "$sqlite_epoch" ]; then
  echo "Rationale: reference timestamp $reference_human (epoch $reference_epoch, source: $reference_source; export_date=$reference_date) >= sqlite mtime $sqlite_human (epoch $sqlite_epoch, $ZOTERO_SQLITE; sqlite_date=$sqlite_date); export is fresh." >&2
  echo "ZOTERO_EXPORT_FRESH"
  exit 0
fi

echo "Rationale: reference timestamp $reference_human (epoch $reference_epoch, source: $reference_source; export_date=$reference_date) < sqlite mtime $sqlite_human (epoch $sqlite_epoch, $ZOTERO_SQLITE; sqlite_date=$sqlite_date); the live Zotero database has been written to since the export was generated." >&2
echo "ZOTERO_EXPORT_STALE"
exit 0
