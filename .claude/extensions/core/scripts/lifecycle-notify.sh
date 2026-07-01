#!/bin/bash
# lifecycle-notify.sh - Bridge script for orchestrator phase transition notifications
#
# Usage:
#   lifecycle-notify.sh STATUS           # Normal mode: tab color + TTS
#   lifecycle-notify.sh STATUS --quiet   # Quiet mode: tab color only (no TTS)
#   lifecycle-notify.sh ""               # Empty status: no-op, exits 0
#
# Called by orchestrator-postflight.sh Stage 8b for lifecycle phase transitions.
#
# Arguments:
#   $1  STATUS   - Lifecycle status string (e.g., "researched", "planned", "implemented")
#   $2  --quiet  - Optional flag to suppress TTS announcement
#
# Behavior:
#   Always calls wezterm-notify.sh STATUS for tab color update
#   In normal mode (no --quiet): also calls tts-notify.sh --lifecycle STATUS
#
# orchestrate-active marker:
#   When .claude/tmp/orchestrate-active exists, TTS is automatically suppressed (tab color
#   still updates) to implement the UX decision table:
#     - standalone /research N completes: no orchestrate-active -> TTS fires
#     - mid-orchestrate research completes: orchestrate-active exists -> TTS suppressed, tab color only
#     - orchestrate final completion: orchestrate-active cleared by Stage 8 -> subsequent Stop hook
#       fires TTS (via task 680 tts-notify.sh integration)
#     - orchestrate paused/blocked: orchestrate-active cleared by Stage 8 partial -> Stop hook fires TTS

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"

# Parse arguments
STATUS="${1:-}"
QUIET="${2:-}"

# No-op if status is empty
if [[ -z "$STATUS" ]]; then
    exit 0
fi

# Auto-suppress TTS when running mid-orchestrate (orchestrate-active marker exists)
# Tab color still updates; only TTS is suppressed.
if [[ -f "$SCRIPT_DIR/../tmp/orchestrate-active" ]]; then
    QUIET="--quiet"
fi

# Always update WezTerm tab color via wezterm-notify.sh
if [[ -f "$HOOKS_DIR/wezterm-notify.sh" ]]; then
    bash "$HOOKS_DIR/wezterm-notify.sh" "$STATUS" 2>/dev/null || true
fi

# In normal mode (not --quiet): also announce via TTS
if [[ "$QUIET" != "--quiet" ]]; then
    if [[ -f "$HOOKS_DIR/tts-notify.sh" ]]; then
        bash "$HOOKS_DIR/tts-notify.sh" --lifecycle "$STATUS" 2>/dev/null || true
    fi
fi

exit 0
