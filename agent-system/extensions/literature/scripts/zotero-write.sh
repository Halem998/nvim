#!/usr/bin/env bash
# zotero-write.sh - Write operations via Zotero Web API through zot
#
# Category A: CLI Wrapper (implemented in task 750)
#
# Usage:
#   zotero-write.sh <operation> <key> [options...]
#
# Operations:
#   note-add KEY "text"                     - Add note to item
#   tag-add KEY TAG                         - Add tag to item
#   tag-remove KEY TAG                      - Remove tag from item
#   attach-file KEY FILEPATH                - Upload file as child attachment
#   item-add --pdf PATH [--doi DOI]         - Create a NEW Zotero item (+ PDF attachment via
#                                              `zot add --pdf`, single atomic call). Unlike every
#                                              other operation above, item-add takes NO existing
#                                              KEY argument -- it creates one. `--doi DOI` is an
#                                              optional companion to `--pdf` (passed through to
#                                              `zot add` alongside `--pdf`); when `--pdf` is
#                                              omitted entirely, `--doi DOI` alone falls back to
#                                              a DOI-only item create with NO attachment -- the
#                                              caller MUST treat that as "no PDF attached" and
#                                              surface it honestly, never as a full success.
#
# Options:
#   --dry-run                    - Preview operation; do not execute
#   --idempotency-key KEY        - Idempotency key for attach-file and item-add
#
# Exit codes:
#   0 - Success (or dry-run preview completed)
#   1 - API error; attachment upload failed; key not found; file not found
#   2 - ZOTERO_API_KEY not set; zot not installed
#
# item-add empirical note: `zot add --pdf`'s exact `data.*` envelope field names (item key,
# attachment key, storage-path) are NOT independently confirmed in this repository -- no `zot`
# binary or configured Zotero account is available in this development environment to make a
# live call. `zotero-write.sh` itself does not need to parse the envelope (it passes `zot`'s
# stdout straight through, same as every other operation here); the caller
# (`literature-ingest-online.sh`) is the one that inspects `.data.*` and does so defensively
# across several plausible field-name candidates. See
# `context/project/literature/patterns/zotero-item-creation.md` for the full note and the
# required live-confirmation follow-up.
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
       zotero-write.sh item-add --pdf PATH [--doi DOI] [options...]

Operations:
  note-add KEY "text"          Add note to item KEY
  tag-add KEY TAG              Add tag TAG to item KEY
  tag-remove KEY TAG           Remove tag TAG from item KEY
  attach-file KEY FILEPATH     Upload FILEPATH as child attachment of item KEY
  item-add --pdf PATH          Create a NEW item + PDF attachment (no existing KEY; wraps
                                `zot add --pdf`). Optional `--doi DOI` alongside `--pdf`.
                                `--doi DOI` with no `--pdf` creates a DOI-only item with NO
                                attachment -- honest "no PDF attached" surfacing is the
                                caller's responsibility.

Options:
  --dry-run                    Preview operation without executing
  --idempotency-key VALUE      Idempotency key for attach-file/item-add (e.g. chunk-KEY-1)

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

# item-add is a CREATE-item operation -- it has no existing KEY to require/consume (its first
# remaining argument is a flag, --pdf or --doi). -h/--help likewise take no KEY. Every other
# operation keeps the original mandatory-KEY-positional behavior unchanged.
KEY=""
if [[ "$OPERATION" != "-h" ]] && [[ "$OPERATION" != "--help" ]] && [[ "$OPERATION" != "item-add" ]]; then
  KEY="${1:-}"
  if [[ -z "$KEY" ]]; then
    echo "zotero-write.sh: KEY argument required for operation: $OPERATION" >&2
    show_usage
    exit 1
  fi
  shift
fi

# Parse remaining args: extract --dry-run, --idempotency-key VALUE, --pdf/--doi (item-add), and
# positional args
DRY_RUN=false
IDEM_KEY=""
PDF_PATH=""
DOI_VAL=""
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
    --pdf)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --pdf requires a PATH argument" >&2
        exit 1
      fi
      PDF_PATH="$2"
      shift 2
      ;;
    --pdf=*)
      PDF_PATH="${1#--pdf=}"
      shift
      ;;
    --doi)
      if [[ "$#" -lt 2 ]]; then
        echo "zotero-write.sh: --doi requires a DOI argument" >&2
        exit 1
      fi
      DOI_VAL="$2"
      shift 2
      ;;
    --doi=*)
      DOI_VAL="${1#--doi=}"
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

  item-add)
    if [[ -z "$PDF_PATH" ]] && [[ -z "$DOI_VAL" ]]; then
      echo "zotero-write.sh: item-add requires --pdf PATH or --doi DOI" >&2
      exit 1
    fi

    if [[ "$DRY_RUN" == "false" ]] && [[ -n "$PDF_PATH" ]] && [[ ! -f "$PDF_PATH" ]]; then
      echo "zotero-write.sh: file not found: $PDF_PATH" >&2
      exit 1
    fi

    # Build command: --pdf is preferred (single atomic create+attach call); a --doi passed
    # alongside --pdf is forwarded too (zot uses it to corroborate/skip its own DOI-from-PDF
    # extraction). --doi with no --pdf is the item-only fallback (no attachment).
    ZOT_CMD=(zot add)
    if [[ -n "$PDF_PATH" ]]; then
      ZOT_CMD+=(--pdf "$PDF_PATH")
    fi
    if [[ -n "$DOI_VAL" ]]; then
      ZOT_CMD+=(--doi "$DOI_VAL")
    fi
    if [[ -n "$IDEM_KEY" ]]; then
      ZOT_CMD+=(--idempotency-key "$IDEM_KEY")
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
      ZOT_CMD+=(--dry-run)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] Would run: ${ZOT_CMD[*]}"
      # Still execute to get dry-run preview from zot itself
    fi

    if ! "${ZOT_CMD[@]}"; then
      echo "zotero-write.sh: item-add failed (pdf: ${PDF_PATH:-none}, doi: ${DOI_VAL:-none})" >&2
      exit 1
    fi

    if [[ -z "$PDF_PATH" ]] && [[ "$DRY_RUN" == "false" ]]; then
      echo "zotero-write.sh: item-add created item via --doi only -- NO PDF attached (honest surfacing, not a failure)" >&2
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
