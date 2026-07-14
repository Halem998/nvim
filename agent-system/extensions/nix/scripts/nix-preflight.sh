#!/usr/bin/env bash
# nix-preflight.sh — Nix extension preflight validation hook
#
# Called by skill_preflight_update() in skill-base.sh after status update.
# Validates that nix tooling is available before research/implementation begins.
#
# Positional args (5 required):
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation

set -euo pipefail

TASK_NUMBER="${1:-}"
TASK_TYPE="${2:-}"
TASK_DIR="${3:-}"
SESSION_ID="${4:-}"
OPERATION="${5:-}"

warnings=0

# Check that nix is available (warn but do not fail)
if ! command -v nix &>/dev/null; then
  echo "[nix-preflight] WARNING: 'nix' command not found — nix tasks may be limited" >&2
  warnings=$((warnings + 1))
fi

# Check for flake.nix if this looks like a flake project (non-fatal)
if [ -d ".git" ] && [ ! -f "flake.nix" ]; then
  echo "[nix-preflight] NOTE: No flake.nix found in repository root"
fi

if [ "$warnings" -eq 0 ]; then
  echo "[nix-preflight] Preflight OK: nix tooling available"
fi

exit 0
