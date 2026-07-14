#!/usr/bin/env bash
# nix-context.sh — Nix extension context injection hook
#
# Called by skill_context_injection() in skill-base.sh before agent delegation.
# Outputs a brief summary of the Nix environment for agents.
#
# Positional args (5 required):
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation

set -euo pipefail

TASK_NUMBER="${1:-}"
TASK_TYPE="${2:-}"
TASK_DIR="${3:-}"
SESSION_ID="${4:-}"
OPERATION="${5:-}"

echo "[nix-context] Nix configuration context:"

# Report nix version if available
if command -v nix &>/dev/null; then
  nix_version=$(nix --version 2>/dev/null || echo "unknown")
  echo "[nix-context]   Nix: $nix_version"
fi

# Report flake inputs if lock file exists
if [ -f "flake.lock" ]; then
  input_count=$(jq '.nodes | keys | length' flake.lock 2>/dev/null || echo "unknown")
  echo "[nix-context]   Flake inputs (locked): $input_count"
fi

exit 0
