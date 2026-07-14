#!/usr/bin/env bash
# nvim-context.sh — Neovim extension context injection hook
#
# Called by skill_context_injection() in skill-base.sh before agent delegation.
# Outputs a brief summary of the Neovim configuration environment for agents.
#
# Positional args (5 required):
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation

set -euo pipefail

TASK_NUMBER="${1:-}"
TASK_TYPE="${2:-}"
TASK_DIR="${3:-}"
SESSION_ID="${4:-}"
OPERATION="${5:-}"

# Output context summary to stdout (captured by skill-base.sh)
echo "[nvim-context] Neovim configuration context:"

# Report lazy.nvim plugin count if available
if [ -f "lazy-lock.json" ]; then
  plugin_count=$(jq 'keys | length' lazy-lock.json 2>/dev/null || echo "unknown")
  echo "[nvim-context]   Plugins locked: $plugin_count"
fi

# Report neovim version if available
if command -v nvim &>/dev/null; then
  nvim_version=$(nvim --version 2>/dev/null | head -1 || echo "unknown")
  echo "[nvim-context]   Neovim: $nvim_version"
fi

exit 0
