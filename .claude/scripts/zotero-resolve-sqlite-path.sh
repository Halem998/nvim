#!/usr/bin/env bash
# zotero-resolve-sqlite-path.sh - Resolve the local Zotero sqlite database path, shared by
# zotero-export-status.sh and zotero-generate-export.sh so the two callers cannot drift.
#
# Usage:
#   zotero-resolve-sqlite-path.sh
#
# Purpose:
#   Both callers previously hardcoded `${ZOTERO_SQLITE_PATH:-${HOME}/Zotero/zotero.sqlite}`,
#   which silently misclassifies/misreads a stale empty default profile on any machine where
#   the user has configured a custom Zotero data directory (Zotero Settings -> Advanced ->
#   Files and Folders -> "Data Directory Location: Custom"). This resolver auto-detects that
#   custom dataDir from the default profile's prefs.js before falling back to the historical
#   default, so both callers resolve identically.
#
# Resolution order (first match wins):
#   1. $ZOTERO_SQLITE_PATH   Explicit override. If set (non-empty), echoed as-is and exit 0.
#   2. <dataDir>/zotero.sqlite   When the default profile's prefs.js has
#      extensions.zotero.useDataDir=true AND extensions.zotero.dataDir="<path>", echoes
#      "<path>/zotero.sqlite".
#   3. ${HOME}/Zotero/zotero.sqlite   Historical default, used when no override is set and no
#      custom dataDir was found (including when prefs.js/profiles.ini are absent or
#      unparseable -- this script never errors on a missing profile, it just falls through).
#
# Profile discovery:
#   Candidate profile base directories (both are probed; a missing one is skipped silently,
#   never an error):
#     ~/.zotero/zotero
#     ~/.mozilla/zotero
#   For each existing base dir, profiles.ini is parsed to find the default profile section
#   (the one with Default=1 under its own [ProfileN] block; falls back to the first
#   [ProfileN] section found if no Default=1 line exists). Its Path= value is resolved
#   relative to the base dir (profiles.ini almost always uses IsRelative=1) and searched for
#   prefs.js. Resolution stops at the first prefs.js that yields a usable dataDir.
#
# Dependency note: value extraction uses `grep -oP` (PCRE). This mirrors the codebase's
# existing GNU/Linux tooling assumptions (e.g. GNU `date -u` in zotero-generate-export.sh).
# If `grep -P` is unavailable, the extraction simply yields nothing and this script falls
# through to the ${HOME}/Zotero default -- it never crashes.
#
# Output:
#   stdout: exactly one path line, nothing else on the happy path (safe for command
#           substitution: ZOTERO_SQLITE="$(zotero-resolve-sqlite-path.sh)").
#   This script performs NO existence check on the resolved path -- callers keep their own
#   `[ -f "$ZOTERO_SQLITE" ]` probes.

set -euo pipefail

# --- Tier 1: explicit override ---
if [ -n "${ZOTERO_SQLITE_PATH:-}" ]; then
  echo "$ZOTERO_SQLITE_PATH"
  exit 0
fi

# --- Tier 2: auto-detect a custom dataDir from the default profile's prefs.js ---
find_default_profile_path() {
  local base_dir="$1"
  local profiles_ini="${base_dir}/profiles.ini"

  if [ ! -d "$base_dir" ] || [ ! -f "$profiles_ini" ]; then
    return 1
  fi

  # Parse profiles.ini: find the [ProfileN] section with Default=1 in its block; fall back
  # to the first [ProfileN] section if none is marked default.
  local default_path=""
  local first_path=""
  local in_profile_section="false"
  local current_path=""
  local current_is_default="false"

  while IFS= read -r line; do
    if [[ "$line" =~ ^\[Profile[0-9]+\] ]]; then
      # Flush the previous section before starting a new one.
      if [ "$in_profile_section" = "true" ] && [ -n "$current_path" ]; then
        if [ -z "$first_path" ]; then
          first_path="$current_path"
        fi
        if [ "$current_is_default" = "true" ] && [ -z "$default_path" ]; then
          default_path="$current_path"
        fi
      fi
      in_profile_section="true"
      current_path=""
      current_is_default="false"
      continue
    fi
    if [[ "$line" =~ ^\[.*\] ]]; then
      # Any other section header ends the current [ProfileN] block.
      if [ "$in_profile_section" = "true" ] && [ -n "$current_path" ]; then
        if [ -z "$first_path" ]; then
          first_path="$current_path"
        fi
        if [ "$current_is_default" = "true" ] && [ -z "$default_path" ]; then
          default_path="$current_path"
        fi
      fi
      in_profile_section="false"
      continue
    fi
    if [ "$in_profile_section" = "true" ]; then
      if [[ "$line" =~ ^Path=(.*)$ ]]; then
        current_path="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^Default=1[[:space:]]*$ ]]; then
        current_is_default="true"
      fi
    fi
  done < "$profiles_ini"

  # Flush a trailing section (file may not end with a blank line or new section header).
  if [ "$in_profile_section" = "true" ] && [ -n "$current_path" ]; then
    if [ -z "$first_path" ]; then
      first_path="$current_path"
    fi
    if [ "$current_is_default" = "true" ] && [ -z "$default_path" ]; then
      default_path="$current_path"
    fi
  fi

  local chosen_path="${default_path:-$first_path}"
  if [ -z "$chosen_path" ]; then
    return 1
  fi

  # Path= is almost always relative (IsRelative=1); resolve relative to base_dir.
  case "$chosen_path" in
    /*) echo "$chosen_path" ;;
    *) echo "${base_dir}/${chosen_path}" ;;
  esac
  return 0
}

extract_datadir_from_prefs() {
  local prefs_js="$1"

  if [ ! -f "$prefs_js" ]; then
    return 1
  fi

  local use_data_dir
  use_data_dir="$(grep -oP 'user_pref\("extensions\.zotero\.useDataDir",\s*\K(true|false)' "$prefs_js" 2>/dev/null | tail -n1)" || use_data_dir=""

  if [ "$use_data_dir" != "true" ]; then
    return 1
  fi

  local data_dir
  data_dir="$(grep -oP 'user_pref\("extensions\.zotero\.dataDir",\s*"\K[^"]+' "$prefs_js" 2>/dev/null | tail -n1)" || data_dir=""

  if [ -z "$data_dir" ]; then
    return 1
  fi

  echo "$data_dir"
  return 0
}

for base_dir in "${HOME}/.zotero/zotero" "${HOME}/.mozilla/zotero"; do
  if [ ! -d "$base_dir" ]; then
    continue
  fi

  profile_dir="$(find_default_profile_path "$base_dir")" || continue
  if [ -z "$profile_dir" ]; then
    continue
  fi

  prefs_js="${profile_dir}/prefs.js"
  data_dir="$(extract_datadir_from_prefs "$prefs_js")" || continue
  if [ -n "$data_dir" ]; then
    echo "${data_dir}/zotero.sqlite"
    exit 0
  fi
done

# --- Tier 3: historical default ---
echo "${HOME}/Zotero/zotero.sqlite"
exit 0
