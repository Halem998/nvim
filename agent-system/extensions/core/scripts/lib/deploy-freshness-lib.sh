#!/usr/bin/env bash
# deploy-freshness-lib.sh - Single home of the per-extension, path-scoped deploy-freshness
# comparison algorithm check-deploy-freshness.sh (advisory, CHECKPOINT 1) and
# update-task-status.sh's postflight backstop (blocking, exit 6) both need. Modelled
# structurally on scripts/lib/file-scope-overlap.sh: a header stating it is the single home of
# the algorithm, safe to source, sets no shell options a caller inherits, and exports nothing a
# caller must guess at.
#
# Algorithm (identical to check-deploy-freshness.sh's pre-extraction inline loop -- this file
# moves that loop's body here verbatim in spirit, changes nothing about what counts as stale):
# for a named extension entry in <repo_root>/.claude-extensions.json carrying BOTH `source_dir`
# and `source_git_head`, recompute the path-scoped source-store revision the same way the Lua
# write side does (state.lua's `resolve_source_git_head`: resolve the enclosing repo root via
# `git rev-parse --show-toplevel`, then `git log -1 --format=%H -- <source_dir>` against that
# toplevel) and compare against the recorded value.
#
# Exports TWO functions, for two different consumers:
#
#   (a) deploy_freshness_stale_names <repo_root> - prints one line per extension NAME whose
#       freshness is CONCLUSIVELY stale; prints nothing for a fresh or cannot-verify extension,
#       and nothing at all when the whole-file comparison cannot run. This is
#       check-deploy-freshness.sh's exact existing "stale -> WARN, everything else -> silence"
#       shape, factored out so the WARN line text/formatting stays owned by that script.
#
#   (b) deploy_freshness_status <repo_root> <extension_name> - prints exactly one of STALE,
#       FRESH, or CANNOTVERIFY for the ONE named extension. This is the three-way distinction
#       update-task-status.sh's blocking backstop needs and check-deploy-freshness.sh
#       deliberately collapses (fresh and cannot-verify both read as "no WARN" to that advisory
#       caller) -- the blocking caller must not make that same collapse, since "cannot verify"
#       and "verified fresh" take different conclusiveness branches there.
#
# Neither function ever aborts, exits non-zero, or raises: every failure mode -- missing or
# unparseable .claude-extensions.json, a missing jq/git binary, an entry missing source_dir or
# source_git_head, a nonexistent or non-git source_dir, or an empty recomputed revision -- is a
# silent per-extension (or whole-file) CANNOTVERIFY/no-emit, matching check-deploy-freshness.sh's
# own "unknown must never read as either confirmed-fresh or an alarm" contract. Callers that need
# a hard failure signal (there are none today) must check for that themselves; this library
# never provides one.

# ─── _deploy_freshness_status_one <json> <extension_name> ──────────────────────────────────────
# Internal helper, not part of the exported contract. Both public functions below funnel through
# this ONE comparison so the algorithm has exactly one home; do not call this directly from
# outside this file.
_deploy_freshness_status_one() {
  local json="$1" name="$2"
  local source_dir recorded_head

  source_dir="$(echo "$json" | jq -r --arg n "$name" '.extensions[$n].source_dir // empty' 2>/dev/null)"
  recorded_head="$(echo "$json" | jq -r --arg n "$name" '.extensions[$n].source_git_head // empty' 2>/dev/null)"

  [ -n "$source_dir" ] || { echo "CANNOTVERIFY"; return 0; }
  [ -n "$recorded_head" ] || { echo "CANNOTVERIFY"; return 0; }
  [ -d "$source_dir" ] || { echo "CANNOTVERIFY"; return 0; }

  local repo_toplevel
  repo_toplevel="$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null)" || { echo "CANNOTVERIFY"; return 0; }
  [ -n "$repo_toplevel" ] || { echo "CANNOTVERIFY"; return 0; }

  local recomputed_head
  recomputed_head="$(git -C "$repo_toplevel" log -1 --format=%H -- "$source_dir" 2>/dev/null)" || { echo "CANNOTVERIFY"; return 0; }
  [ -n "$recomputed_head" ] || { echo "CANNOTVERIFY"; return 0; }

  if [ "$recomputed_head" != "$recorded_head" ]; then
    echo "STALE"
  else
    echo "FRESH"
  fi
  return 0
}

# _deploy_freshness_load_json <repo_root>
# Internal helper. Prints the parsed-and-validated .claude-extensions.json content on success;
# prints nothing and returns 1 on any whole-file cannot-verify condition (missing file, missing
# jq/git, unreadable, empty, or invalid JSON).
_deploy_freshness_load_json() {
  local repo_root="$1"
  local state_file="${repo_root}/.claude-extensions.json"

  [ -f "$state_file" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  command -v git >/dev/null 2>&1 || return 1

  local json
  json="$(cat "$state_file" 2>/dev/null)" || return 1
  [ -n "$json" ] || return 1
  echo "$json" | jq -e . >/dev/null 2>&1 || return 1

  printf '%s' "$json"
  return 0
}

# deploy_freshness_stale_names <repo_root>
# Prints one extension name per line for every extension whose recorded source_git_head no
# longer matches its recomputed path-scoped revision. Silent (no output) when the whole-file
# comparison cannot run, and silent for any individual extension that is fresh or unverifiable.
# Always returns 0.
deploy_freshness_stale_names() {
  local repo_root="${1:?deploy_freshness_stale_names: repo_root required}"

  local json
  json="$(_deploy_freshness_load_json "$repo_root")" || return 0
  [ -n "$json" ] || return 0

  local names
  names="$(echo "$json" | jq -r '.extensions // {} | keys[]?' 2>/dev/null)" || return 0

  local name status
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    status="$(_deploy_freshness_status_one "$json" "$name")"
    [ "$status" = "STALE" ] && echo "$name"
  done <<< "$names"
  return 0
}

# deploy_freshness_status <repo_root> <extension_name>
# Prints exactly one of STALE, FRESH, or CANNOTVERIFY for the named extension. Always returns 0.
deploy_freshness_status() {
  local repo_root="${1:?deploy_freshness_status: repo_root required}"
  local ext_name="${2:?deploy_freshness_status: extension_name required}"

  local json
  json="$(_deploy_freshness_load_json "$repo_root")" || { echo "CANNOTVERIFY"; return 0; }
  [ -n "$json" ] || { echo "CANNOTVERIFY"; return 0; }

  _deploy_freshness_status_one "$json" "$ext_name"
  return 0
}
