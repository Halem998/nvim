#!/usr/bin/env bash
# check-deploy-freshness.sh — Non-blocking, always-exit-0 check for whether a repo's deployed
# .claude/ tree still matches the source store it was regenerated from.
#
# ALWAYS EXITS 0. This is not a preflight gate: it never changes an admission decision, never
# aborts, retries, or auto-redeploys anything. Its two sanctioned consumers: (1)
# command-gate-in.sh's CHECKPOINT 1, which invokes it as
# `bash .claude/scripts/check-deploy-freshness.sh ... 2>&1 || true` for exactly that reason, and
# (2) scripts/lib/deploy-freshness-lib.sh, the shared comparison library this script sources
# below — its own second exported function (`deploy_freshness_status`) is the blocking companion
# tier described in `context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're
# Stale" section (tier 2: `update-task-status.sh`'s postflight backstop). This script itself
# remains tier 1: silent, advisory, CHECKPOINT-1-only, never a gate.
# MUST be run with `bash`, never sourced — it sets no shell options safe to inherit into a
# caller's shell, and exports nothing a caller could rely on.
#
# Reads <repo_root>/.claude-extensions.json (default repo_root: current directory). For each
# extension entry recording BOTH `source_dir` and `source_git_head`, recomputes the path-scoped
# source-store revision the same way the Lua write side does (state.lua's
# `resolve_source_git_head`: resolve the enclosing repo root via `git rev-parse --show-toplevel`,
# then `git log -1 --format=%H -- <source_dir>`). A mismatch between the recorded and recomputed
# revision prints one WARN line to stderr naming the extension and the regeneration remedy. The
# actual per-extension comparison is delegated to scripts/lib/deploy-freshness-lib.sh
# (`deploy_freshness_stale_names`) — this script owns only the WARN line text/formatting and its
# always-exit-0 contract; it does not re-derive the comparison algorithm inline.
#
# Deliberately SILENT (no output at all, not even a summary line) in every "cannot verify" case
# — "unknown" must not read as either "confirmed fresh" or an alarm:
#   - missing or unparseable .claude-extensions.json
#   - an entry missing `source_dir` or `source_git_head` (every pre-fix deploy)
#   - `source_dir` does not exist on disk
#   - `source_dir` is not inside a git repository
#   - `git` or `jq` is unavailable
#   - the recomputed revision is empty
#
# This is the shallow, preflight-cheap companion to verify-deploy.sh (11 content-diffing gates,
# deliberately NOT preflight-cheap): one path-scoped `git log -1` per extension, safe to run on
# every ordinary command.
#
# Usage: bash check-deploy-freshness.sh [repo_root]
# Exit code: always 0.

set -uo pipefail  # deliberately NOT -e: every step degrades to a silent skip, never an abort

REPO_ROOT="${1:-$(pwd)}"

# --- Shared freshness comparison library ---
# Sibling lookup off this script's OWN location (not off REPO_ROOT, which names the repo being
# CHECKED — a different, unrelated directory from the one this script itself is deployed or
# source-stored in). This resolves correctly whether this script is running from the deployed
# tree (.claude/scripts/check-deploy-freshness.sh, lib sibling at
# .claude/scripts/lib/deploy-freshness-lib.sh) or the source store
# (agent-system/extensions/core/scripts/check-deploy-freshness.sh, lib sibling at
# agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh) with no root-computation
# needed at all — unlike update-task-status.sh's PROJECT_ROOT-anchored candidate list, this
# script does not use deploy-root-guard.sh and has no independent notion of "project root" to
# anchor against. A missing library degrades to this script's own existing silent-no-op
# contract (never a loud environment error) — "always exit 0, never alarm" already covers this
# case, so there is no new failure mode to introduce.
_CDF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
FRESHNESS_LIB="${_CDF_SCRIPT_DIR:-}/lib/deploy-freshness-lib.sh"

[ -n "${_CDF_SCRIPT_DIR:-}" ] || exit 0
[ -f "$FRESHNESS_LIB" ] || exit 0
# shellcheck disable=SC1090
. "$FRESHNESS_LIB"

STALE_NAMES="$(deploy_freshness_stale_names "$REPO_ROOT")"

while IFS= read -r name; do
  [ -n "$name" ] || continue
  echo "WARN: deployed extension '${name}' is stale — its .claude/ tree no longer matches the source store." >&2
  echo "  Remedy: bash .claude/scripts/deploy-headless.sh (or the picker's [Reload All] / 'Regenerate')." >&2
  echo "  For per-file detail: bash .claude/scripts/verify-deploy.sh --findings" >&2
done <<< "$STALE_NAMES"

exit 0
