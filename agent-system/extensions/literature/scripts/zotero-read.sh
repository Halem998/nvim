#!/usr/bin/env bash
# zotero-read.sh - Read-only operations against Zotero via zot CLI
#
# Category A: CLI Wrapper (implemented in task 750)
#
# Usage:
#   zotero-read.sh <operation> [key] [options...]
#
# Operations:
#   search "query string"   - Search Zotero library items
#   item KEY                - Get full metadata for item KEY
#   pdf KEY [--pages N-M]   - Extract PDF text for item KEY
#   outline KEY             - Get document outline for item KEY
#   annotations KEY         - Get PDF annotations for item KEY
#   note KEY                - Get notes for item KEY
#   tags KEY                - Get tags for item KEY
#   collections             - List collection hierarchy
#   stats                   - Get library statistics
#
# Exit codes:
#   0 - Success
#   1 - Runtime error (key not found, zot error, parse failure)
#   2 - Not configured (zot not installed, ZOT_DATA_DIR not set)
#
# Environment variables:
#   ZOT_DATA_DIR - Path to Zotero data directory (required)

set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

if ! command -v zot &>/dev/null; then
  echo "zotero-read.sh: zot not installed; install via: uv tool install zotero-cli-cc" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"

# ---------------------------------------------------------------------------
# ZOT_DATA_DIR resolution
# ---------------------------------------------------------------------------

if [[ -z "${ZOT_DATA_DIR:-}" ]] && [[ -f "$ZOTERO_INDEX" ]]; then
  _dir="$(jq -r '.zot_data_dir // empty' "$ZOTERO_INDEX" 2>/dev/null)"
  if [[ -n "$_dir" && -d "$_dir" ]]; then
    export ZOT_DATA_DIR="$_dir"
  fi
fi

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  cat >&2 << 'USAGE'
Usage: zotero-read.sh <operation> [key] [options...]

Operations:
  search "query"      Search Zotero library items
  item KEY            Get full metadata for item KEY
  pdf KEY [--pages N-M]  Extract PDF text (plain text output)
  outline KEY         Get document outline for item KEY
  annotations KEY     Get PDF annotations for item KEY
  note KEY            Get notes for item KEY
  tags KEY            Get tags for item KEY
  collections         List collection hierarchy
  stats               Get library statistics

Exit codes:
  0 - Success
  1 - Runtime error (key not found, zot error, parse failure)
  2 - Not configured (zot not installed)
USAGE
}

# ---------------------------------------------------------------------------
# JSON envelope helper
# Parse output from zot --json commands; print .data or error and exit
# ---------------------------------------------------------------------------

_parse_json_result() {
  local _result="$1"
  local _ok
  _ok="$(echo "$_result" | jq -r '.ok // "false"' 2>/dev/null)"
  if [[ "$_ok" != "true" ]]; then
    local _err
    _err="$(echo "$_result" | jq -r '.error // "unknown error"' 2>/dev/null)"
    echo "zot error: $_err" >&2
    exit 1
  fi
  echo "$_result" | jq '.data'
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPERATION="${1:-}"
if [[ -z "$OPERATION" ]]; then
  echo "zotero-read.sh: operation required" >&2
  show_usage
  exit 1
fi

shift
KEY="${1:-}"
if [[ "$#" -gt 0 ]]; then shift; fi
EXTRA_ARGS=("$@")

# ---------------------------------------------------------------------------
# Operation dispatch
# ---------------------------------------------------------------------------

case "$OPERATION" in

  search)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: search requires a query string" >&2
      exit 1
    fi
    _result="$(zot --json search "$KEY" 2>/dev/null)"
    _parse_json_result "$_result"
    ;;

  item)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: item requires a KEY argument" >&2
      exit 1
    fi
    _result="$(zot --json read "$KEY" 2>/dev/null)"
    _parse_json_result "$_result"
    ;;

  pdf)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: pdf requires a KEY argument" >&2
      exit 1
    fi
    # Plain text output; --pages N-M passed through via EXTRA_ARGS
    zot pdf "$KEY" "${EXTRA_ARGS[@]}"
    ;;

  outline)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: outline requires a KEY argument" >&2
      exit 1
    fi
    # Plain text output
    zot pdf "$KEY" --outline
    ;;

  annotations)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: annotations requires a KEY argument" >&2
      exit 1
    fi
    # Plain text output
    zot pdf "$KEY" --annotations
    ;;

  note)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: note requires a KEY argument" >&2
      exit 1
    fi
    _result="$(zot --json note "$KEY" 2>/dev/null)"
    _parse_json_result "$_result"
    ;;

  tags)
    if [[ -z "$KEY" ]]; then
      echo "zotero-read.sh: tags requires a KEY argument" >&2
      exit 1
    fi
    _result="$(zot --json tag "$KEY" 2>/dev/null)"
    _parse_json_result "$_result"
    ;;

  collections)
    # No KEY argument needed
    zot collection list
    ;;

  stats)
    # No KEY argument needed
    _result="$(zot --json stats 2>/dev/null)"
    _parse_json_result "$_result"
    ;;

  -h|--help)
    show_usage
    exit 0
    ;;

  *)
    echo "zotero-read.sh: unknown operation: $OPERATION" >&2
    show_usage
    exit 1
    ;;

esac
