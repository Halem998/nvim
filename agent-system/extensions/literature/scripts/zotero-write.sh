#!/usr/bin/env bash
# zotero-write.sh - Write operations via Zotero Web API through zot
#
# Category A: CLI Wrapper (implemented in task 750)
#
# Usage:
#   zotero-write.sh <operation> <key> [options...]
#
# Operations:
#   note-add KEY "text"          - Add note to item
#   tag-add KEY TAG              - Add tag to item
#   tag-remove KEY TAG           - Remove tag from item
#   attach-file KEY FILEPATH     - Upload file as child attachment
#
# Options:
#   --dry-run                    - Preview operation; do not execute
#   --idempotency-key KEY        - Idempotency key for attach-file
#
# Exit codes:
#   0 - Success (or dry-run preview completed)
#   1 - API error; attachment upload failed; key not found; file not found
#   2 - ZOTERO_API_KEY not set; zot not installed
#
# Environment variables:
#   ZOTERO_API_KEY - Web API key (required for all write operations)
#   ZOT_DATA_DIR   - Path to Zotero data directory

set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

if ! command -v zot &>/dev/null; then
  echo "zotero-write.sh: zot not installed; install via: uv tool install zotero-cli-cc" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# API key check
# ---------------------------------------------------------------------------

if [[ -z "${ZOTERO_API_KEY:-}" ]]; then
  echo "zotero-write.sh: ZOTERO_API_KEY not set; run /zotero --setup or: zot config init" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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
Usage: zotero-write.sh <operation> <key> [options...]

Operations:
  note-add KEY "text"          Add note to item KEY
  tag-add KEY TAG              Add tag TAG to item KEY
  tag-remove KEY TAG           Remove tag TAG from item KEY
  attach-file KEY FILEPATH     Upload FILEPATH as child attachment of item KEY

Options:
  --dry-run                    Preview operation without executing
  --idempotency-key VALUE      Idempotency key for attach-file (e.g. chunk-KEY-1)

Exit codes:
  0 - Success (or dry-run preview completed)
  1 - API error; file not found; key not found
  2 - ZOTERO_API_KEY not set; zot not installed
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPERATION="${1:-}"
if [[ -z "$OPERATION" ]]; then
  echo "zotero-write.sh: operation required" >&2
  show_usage
  exit 1
fi
shift

KEY="${1:-}"
if [[ -z "$KEY" ]] && [[ "$OPERATION" != "-h" ]] && [[ "$OPERATION" != "--help" ]]; then
  echo "zotero-write.sh: KEY argument required for operation: $OPERATION" >&2
  show_usage
  exit 1
fi
if [[ "$#" -gt 0 ]]; then shift; fi

# Parse remaining args: extract --dry-run, --idempotency-key VALUE, and positional args
DRY_RUN=false
IDEM_KEY=""
POSITIONAL_ARGS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --idempotency-key)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --idempotency-key requires a VALUE argument" >&2
        exit 1
      fi
      IDEM_KEY="$2"
      shift 2
      ;;
    --idempotency-key=*)
      IDEM_KEY="${1#--idempotency-key=}"
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Operation dispatch
# ---------------------------------------------------------------------------

case "$OPERATION" in

  note-add)
    TEXT="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$TEXT" ]]; then
      echo "zotero-write.sh: note-add requires a text argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: zot note $KEY --add \"$TEXT\""
      exit 0
    fi
    if ! zot note "$KEY" --add "$TEXT"; then
      echo "zotero-write.sh: note-add failed for key: $KEY" >&2
      exit 1
    fi
    ;;

  tag-add)
    TAG="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$TAG" ]]; then
      echo "zotero-write.sh: tag-add requires a TAG argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: zot tag $KEY --add \"$TAG\""
      exit 0
    fi
    if ! zot tag "$KEY" --add "$TAG"; then
      echo "zotero-write.sh: tag-add failed for key: $KEY, tag: $TAG" >&2
      exit 1
    fi
    ;;

  tag-remove)
    TAG="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$TAG" ]]; then
      echo "zotero-write.sh: tag-remove requires a TAG argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: zot tag $KEY --remove \"$TAG\""
      exit 0
    fi
    if ! zot tag "$KEY" --remove "$TAG"; then
      echo "zotero-write.sh: tag-remove failed for key: $KEY, tag: $TAG" >&2
      exit 1
    fi
    ;;

  attach-file)
    FILEPATH="${POSITIONAL_ARGS[0]:-}"
    if [[ -z "$FILEPATH" ]]; then
      echo "zotero-write.sh: attach-file requires a FILEPATH argument" >&2
      exit 1
    fi
    if [[ "$DRY_RUN" == "false" ]] && [[ ! -f "$FILEPATH" ]]; then
      echo "zotero-write.sh: file not found: $FILEPATH" >&2
      exit 1
    fi

    # Build command
    ZOT_CMD=(zot attach "$KEY" --file "$FILEPATH")
    if [[ "$DRY_RUN" == "true" ]]; then
      ZOT_CMD+=(--dry-run)
    fi
    if [[ -n "$IDEM_KEY" ]]; then
      ZOT_CMD+=(--idempotency-key "$IDEM_KEY")
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: ${ZOT_CMD[*]}"
      # Still execute to get dry-run preview from zot itself
    fi

    if ! "${ZOT_CMD[@]}"; then
      echo "zotero-write.sh: attach-file failed for key: $KEY, file: $FILEPATH" >&2
      exit 1
    fi
    ;;

  -h|--help)
    show_usage
    exit 0
    ;;

  *)
    echo "zotero-write.sh: unknown operation: $OPERATION" >&2
    show_usage
    exit 1
    ;;

esac
