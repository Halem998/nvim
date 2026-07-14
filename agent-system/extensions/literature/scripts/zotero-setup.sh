#!/usr/bin/env bash
# zotero-setup.sh - Setup wizard, validation, and status reporting for the zotero extension
#
# Category A: CLI Wrapper (implemented in task 750)
#
# Usage:
#   zotero-setup.sh [--detect|--configure|--validate|--status]
#
# Sub-commands:
#   --detect      - Auto-detect Zotero data directory
#   --configure   - Detect dir, create specs/zotero-index.json template
#   --validate    - Check: zot installed, ZOT_DATA_DIR valid, SQLite readable
#   --status      - Print configuration summary and library stats
#
# Exit codes:
#   0 - Success (detection found path; validation passed; status retrieved)
#   1 - Detection failed; validation failed; status unavailable
#   2 - zot not installed (only for --validate, --status; --detect exempt)
#
# Dependencies: zot (zotero-cli-cc), jq

set -euo pipefail

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ZOTERO_INDEX="$PROJECT_ROOT/specs/zotero-index.json"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

show_usage() {
  cat >&2 << 'USAGE'
Usage: zotero-setup.sh [--detect|--configure|--validate|--status]

Sub-commands:
  --detect      Auto-detect Zotero data directory; print path to stdout
  --configure   Detect data dir, create specs/zotero-index.json
  --validate    Check: zot installed, ZOT_DATA_DIR valid, SQLite readable
  --status      Print configuration summary and library stats

Exit codes:
  0 - Success
  1 - Failure (detection failed, validation errors, status unavailable)
  2 - zot not installed (--validate, --status only)
USAGE
}

# ---------------------------------------------------------------------------
# Data directory detection
# ---------------------------------------------------------------------------

_detect_data_dir() {
  # Step 1: env var
  if [[ -n "${ZOT_DATA_DIR:-}" ]]; then
    if [[ -d "$ZOT_DATA_DIR" && -f "$ZOT_DATA_DIR/zotero.sqlite" ]]; then
      echo "$ZOT_DATA_DIR"
      return 0
    fi
  fi

  # Step 2: zotero-index.json
  if [[ -f "$ZOTERO_INDEX" ]]; then
    local _dir
    _dir="$(jq -r '.zot_data_dir // empty' "$ZOTERO_INDEX" 2>/dev/null)"
    if [[ -n "$_dir" && -d "$_dir" && -f "$_dir/zotero.sqlite" ]]; then
      echo "$_dir"
      return 0
    fi
  fi

  # Step 3: common locations
  local _candidate
  for _candidate in \
    "$HOME/Zotero" \
    "$HOME/Documents/Zotero" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/Zotero"
  do
    if [[ -d "$_candidate" && -f "$_candidate/zotero.sqlite" ]]; then
      echo "$_candidate"
      return 0
    fi
  done

  return 1
}

# ---------------------------------------------------------------------------
# Sub-command: --detect
# ---------------------------------------------------------------------------

cmd_detect() {
  local _dir
  if _dir="$(_detect_data_dir)"; then
    echo "$_dir"
    exit 0
  else
    echo "zotero-setup.sh: Zotero data directory not found" >&2
    echo "Checked: \$ZOT_DATA_DIR, $ZOTERO_INDEX, ~/Zotero, ~/Documents/Zotero, \$XDG_DATA_HOME/Zotero" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Sub-command: --configure
# ---------------------------------------------------------------------------

cmd_configure() {
  local _dir
  if ! _dir="$(_detect_data_dir)"; then
    echo "zotero-setup.sh --configure: Cannot detect Zotero data directory" >&2
    echo "Set ZOT_DATA_DIR environment variable and retry, or run:" >&2
    echo "  export ZOT_DATA_DIR=/path/to/Zotero" >&2
    exit 1
  fi

  echo "Detected Zotero data directory: $_dir" >&2

  local _now
  _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ -f "$ZOTERO_INDEX" ]]; then
    # Update existing index: set zot_data_dir and last_updated
    local _updated
    _updated="$(jq \
      --arg dir "$_dir" \
      --arg ts "$_now" \
      '.zot_data_dir = $dir | .last_updated = $ts' \
      "$ZOTERO_INDEX")"
    echo "$_updated" > "$ZOTERO_INDEX"
    echo "Updated $ZOTERO_INDEX (zot_data_dir set)" >&2
  else
    # Create new index with template
    mkdir -p "$(dirname "$ZOTERO_INDEX")"
    cat > "$ZOTERO_INDEX" << EOF
{
  "version": "1.0",
  "created": "$_now",
  "last_updated": "$_now",
  "token_budget": 8000,
  "zot_data_dir": "$_dir",
  "entries": []
}
EOF
    echo "Created $ZOTERO_INDEX" >&2
  fi

  echo "" >&2
  echo "Configuration complete." >&2
  echo "" >&2
  echo "If you need Zotero Web API access (for write operations), also run:" >&2
  echo "  zot config init" >&2
  echo "This will prompt for your Zotero user ID and API key." >&2

  exit 0
}

# ---------------------------------------------------------------------------
# Sub-command: --validate
# ---------------------------------------------------------------------------

cmd_validate() {
  local _all_pass=true

  # Check 1: zot installed
  if command -v zot &>/dev/null; then
    echo "[PASS] zot installed: $(command -v zot)"
  else
    echo "[FAIL] zot not installed; install via: uv tool install zotero-cli-cc"
    _all_pass=false
  fi

  # Check 2: ZOT_DATA_DIR resolves to dir with zotero.sqlite
  local _dir
  if _dir="$(_detect_data_dir)" 2>/dev/null; then
    if [[ -f "$_dir/zotero.sqlite" ]]; then
      echo "[PASS] ZOT_DATA_DIR: $_dir (zotero.sqlite found)"
    else
      echo "[FAIL] ZOT_DATA_DIR: $_dir (zotero.sqlite not found)"
      _all_pass=false
    fi
  else
    echo "[FAIL] ZOT_DATA_DIR: cannot detect Zotero data directory"
    _all_pass=false
  fi

  # Check 3: zot --json stats succeeds (SQLite readable)
  if command -v zot &>/dev/null; then
    if [[ -n "${_dir:-}" ]]; then
      export ZOT_DATA_DIR="$_dir"
    fi
    local _stats_result
    if _stats_result="$(zot --json stats 2>/dev/null)"; then
      if [[ "$(echo "$_stats_result" | jq -r '.ok // "false"' 2>/dev/null)" == "true" ]]; then
        local _count
        _count="$(echo "$_stats_result" | jq -r '.data.item_count // .data.items // "?"' 2>/dev/null)"
        echo "[PASS] zot stats: SQLite readable (items: $_count)"
      else
        local _err
        _err="$(echo "$_stats_result" | jq -r '.error // "unknown error"' 2>/dev/null)"
        echo "[FAIL] zot stats: $_err"
        _all_pass=false
      fi
    else
      echo "[FAIL] zot stats: command failed (SQLite may be locked or unreadable)"
      _all_pass=false
    fi
  else
    echo "[SKIP] zot stats: skipped (zot not installed)"
    _all_pass=false
  fi

  if [[ "$_all_pass" == "true" ]]; then
    exit 0
  else
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Sub-command: --status
# ---------------------------------------------------------------------------

cmd_status() {
  # Resolve data dir
  local _dir
  if ! _dir="$(_detect_data_dir)" 2>/dev/null; then
    _dir="(not configured)"
  fi

  # Library item count
  local _item_count="(unavailable)"
  if command -v zot &>/dev/null && [[ "$_dir" != "(not configured)" ]]; then
    export ZOT_DATA_DIR="$_dir"
    local _stats_result
    if _stats_result="$(zot --json stats 2>/dev/null)"; then
      if [[ "$(echo "$_stats_result" | jq -r '.ok // "false"' 2>/dev/null)" == "true" ]]; then
        _item_count="$(echo "$_stats_result" | jq -r '.data.item_count // .data.items // "?"' 2>/dev/null)"
      fi
    fi
  fi

  # Per-repo index item count
  local _index_count="(no index)"
  if [[ -f "$ZOTERO_INDEX" ]]; then
    _index_count="$(jq '.entries | length' "$ZOTERO_INDEX" 2>/dev/null || echo "?")"
  fi

  # API key status
  local _api_key_status="unset"
  if [[ -n "${ZOTERO_API_KEY:-}" ]]; then
    _api_key_status="set"
  fi

  printf "%-22s %s\n" "ZOT_DATA_DIR:"   "$_dir"
  printf "%-22s %s\n" "Library items:"  "$_item_count"
  printf "%-22s %s\n" "Index entries:"  "$_index_count"
  printf "%-22s %s\n" "ZOTERO_API_KEY:" "$_api_key_status"

  exit 0
}

# ---------------------------------------------------------------------------
# Argument dispatch
# ---------------------------------------------------------------------------

SUBCMD="${1:-}"

case "$SUBCMD" in
  --detect)
    cmd_detect
    ;;
  --configure)
    cmd_configure
    ;;
  --validate)
    if ! command -v zot &>/dev/null; then
      echo "zotero-setup.sh: zot not installed; install via: uv tool install zotero-cli-cc" >&2
      exit 2
    fi
    cmd_validate
    ;;
  --status)
    cmd_status
    ;;
  -h|--help|"")
    show_usage
    exit 0
    ;;
  *)
    echo "zotero-setup.sh: unknown sub-command: $SUBCMD" >&2
    show_usage
    exit 1
    ;;
esac
