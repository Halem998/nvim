#!/usr/bin/env bash
# TTS notification hook for Claude Code events
# Announces WezTerm tab number via piper neural TTS for lifecycle transitions
# and interactive prompts requiring user input.
#
# Integration:
#   Notification hook (permission_prompt, elicitation_dialog): called with no args
#   Lifecycle transitions: called by update-task-status.sh postflight with --lifecycle STATUS
#
# Requirements: piper (neural TTS) + a voice model, paplay (pulseaudio-utils), wezterm
#
# Supported Modes:
#   Interactive (no args) - speaks "Tab N" for permission_prompt/elicitation_dialog
#   Lifecycle (--lifecycle STATUS) - speaks "Tab N STATUS" (e.g., "Tab 3 researched")
#
# Lifecycle status vocabulary (no artifact-type vocabulary):
#   researching, researched, planning, planned, implementing, completed, blocked
#
# Configuration:
#   TTS_ENABLED  - Set to "0" to disable (default: 1)
#   PIPER_VOICE  - Path to piper .onnx voice model
#                  (default: $HOME/.local/share/piper/en_US-lessac-medium.onnx)

set -euo pipefail

# Configuration with defaults
TTS_ENABLED="${TTS_ENABLED:-1}"
PIPER_VOICE="${PIPER_VOICE:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"

# Log file
LOG_FILE="specs/tmp/claude-tts-notify.log"

# --- Parse arguments ---
LIFECYCLE_STATUS=""
if [[ "${1:-}" == "--lifecycle" ]] && [[ -n "${2:-}" ]]; then
    LIFECYCLE_STATUS="$2"
fi

# Helper: log message
log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Helper: return success JSON for hook
exit_success() {
    echo '{}'
    exit 0
}

# Helper: get WezTerm tab prefix ("Tab N" or fallback "Tab")
get_tab_prefix() {
    local tab_prefix="Tab"
    if [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm &>/dev/null; then
        local all_panes current_tab_id unique_tab_ids tab_index position tab_num
        all_panes=$(wezterm cli list --format=json 2>/dev/null) || true
        current_tab_id=$(echo "$all_panes" | jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tab_id" 2>/dev/null || echo "")
        if [[ -n "$current_tab_id" ]] && ! [[ "$current_tab_id" == "null" ]]; then
            unique_tab_ids=$(echo "$all_panes" | jq -r '[.[].tab_id] | unique | .[]') || true
            tab_index=0
            position=0
            while IFS= read -r tab_id; do
                if [[ "$tab_id" == "$current_tab_id" ]]; then
                    position=$tab_index
                    break
                fi
                tab_index=$((tab_index + 1))
            done <<< "$unique_tab_ids"
            tab_num=$((position + 1))
            tab_prefix="Tab $tab_num"
        fi
    fi
    echo "$tab_prefix"
}

# Helper: speak a message via piper (neural TTS)
# Streams synthesized audio straight to paplay; no temp WAV needed.
speak() {
    local message="$1"
    if ! command -v paplay &>/dev/null; then
        log "No audio player found (paplay) - skipping TTS"
        return 1
    fi
    if [[ ! -f "$PIPER_VOICE" ]]; then
        log "Piper voice model not found at '$PIPER_VOICE' - skipping TTS"
        return 1
    fi
    (timeout 10s bash -c "printf '%s' '${message}' | piper --model '${PIPER_VOICE}' --output_file - --quiet 2>/dev/null | paplay 2>/dev/null" &) || true
    return 0
}

# Check if TTS is disabled
if [[ "$TTS_ENABLED" != "1" ]]; then
    exit_success
fi

# Check if piper is available
if ! command -v piper &>/dev/null; then
    log "piper command not found - skipping TTS notification"
    exit_success
fi

# ============================================================
# LIFECYCLE MODE: --lifecycle STATUS
# Speak "Tab N STATUS" for researched/planned/completed events
# ============================================================
if [[ -n "$LIFECYCLE_STATUS" ]]; then
    TAB_PREFIX=$(get_tab_prefix)
    MESSAGE="$TAB_PREFIX $LIFECYCLE_STATUS"
    speak "$MESSAGE"
    log "Lifecycle notification sent: $MESSAGE (status=$LIFECYCLE_STATUS)"
    exit_success
fi

# ============================================================
# INTERACTIVE MODE: no args (Notification hook)
# Speak "Tab N" for permission_prompt and elicitation_dialog
# ============================================================
TAB_PREFIX=$(get_tab_prefix)
MESSAGE="$TAB_PREFIX"
speak "$MESSAGE"
log "Interactive notification sent: $MESSAGE"
exit_success
