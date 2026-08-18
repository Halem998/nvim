#!/usr/bin/env bash
# check-deploy-freshness.sh — Non-blocking, always-exit-0 check for whether a repo's deployed
# .claude/ tree still matches the source store it was regenerated from.
#
# ALWAYS EXITS 0. This is not a preflight gate: it never changes an admission decision, never
# aborts, retries, or auto-redeploys anything. Its only sanctioned caller is
# command-gate-in.sh's CHECKPOINT 1, which invokes it as
# `bash .claude/scripts/check-deploy-freshness.sh ... 2>&1 || true` for exactly that reason.
# MUST be run with `bash`, never sourced — it sets no shell options safe to inherit into a
# caller's shell, and exports nothing a caller could rely on.
#
# Reads <repo_root>/.claude-extensions.json (default repo_root: current directory). For each
# extension entry recording BOTH `source_dir` and `source_git_head`, recomputes the path-scoped
# source-store revision the same way the Lua write side does (state.lua's
# `resolve_source_git_head`: resolve the enclosing repo root via `git rev-parse --show-toplevel`,
# then `git log -1 --format=%H -- <source_dir>`). A mismatch between the recorded and recomputed
# revision prints one WARN line to stderr naming the extension and the regeneration remedy.
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
STATE_FILE="${REPO_ROOT}/.claude-extensions.json"

[ -f "$STATE_FILE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

JSON="$(cat "$STATE_FILE" 2>/dev/null)" || exit 0
[ -n "$JSON" ] || exit 0

echo "$JSON" | jq -e . >/dev/null 2>&1 || exit 0

NAMES="$(echo "$JSON" | jq -r '.extensions // {} | keys[]?' 2>/dev/null)" || exit 0

while IFS= read -r name; do
  [ -n "$name" ] || continue

  source_dir="$(echo "$JSON" | jq -r --arg n "$name" '.extensions[$n].source_dir // empty' 2>/dev/null)"
  recorded_head="$(echo "$JSON" | jq -r --arg n "$name" '.extensions[$n].source_git_head // empty' 2>/dev/null)"

  [ -n "$source_dir" ] || continue
  [ -n "$recorded_head" ] || continue
  [ -d "$source_dir" ] || continue

  repo_toplevel="$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null)" || continue
  [ -n "$repo_toplevel" ] || continue

  recomputed_head="$(git -C "$repo_toplevel" log -1 --format=%H -- "$source_dir" 2>/dev/null)" || continue
  [ -n "$recomputed_head" ] || continue

  if [ "$recomputed_head" != "$recorded_head" ]; then
    echo "WARN: deployed extension '${name}' is stale — its .claude/ tree no longer matches the source store." >&2
    echo "  Remedy: bash .claude/scripts/deploy-headless.sh (or the picker's [Reload All] / 'Regenerate')." >&2
    echo "  For per-file detail: bash .claude/scripts/verify-deploy.sh --findings" >&2
  fi
done <<< "$NAMES"

exit 0
