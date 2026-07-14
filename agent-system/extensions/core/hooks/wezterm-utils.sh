#!/bin/bash
# Shared WezTerm utility functions for Claude Code hooks
#
# Usage: source this file in WezTerm hooks to get shared TTY discovery and OSC write functions
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/wezterm-utils.sh"
#
# Provides:
#   get_pane_tty()    - Returns the TTY path for the current WezTerm pane
#   set_user_var()    - Sets a WezTerm user variable via OSC 1337
#
# See: task 601 (simplify_notification_pipeline_merge_vocabulary)

# get_pane_tty: Returns the TTY path for the current WezTerm pane
# Returns empty string and exits 1 if no WezTerm pane or TTY not writable
get_pane_tty() {
    if [[ -z "${WEZTERM_PANE:-}" ]]; then
        echo ""
        return 1
    fi
    local tty
    tty=$(wezterm cli list --format=json 2>/dev/null | \
        jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" 2>/dev/null || echo "")
    if [[ -z "$tty" ]] || [[ ! -w "$tty" ]]; then
        echo ""
        return 1
    fi
    echo "$tty"
}

# set_user_var: Sets a WezTerm user variable via OSC 1337
# Arguments:
#   $1 - Variable name (e.g., CLAUDE_STATUS)
#   $2 - Value to set (empty string to clear)
#   $3 - TTY path (optional; if omitted, calls get_pane_tty())
# Returns 0 on success, 0 on no-op (no TTY available)
set_user_var() {
    local name="$1"
    local value="${2:-}"
    local tty="${3:-}"
    if [[ -z "$tty" ]]; then
        tty=$(get_pane_tty) || return 0
    fi
    local encoded
    encoded=$(echo -n "$value" | base64 | tr -d '\n')
    printf '\033]1337;SetUserVar=%s=%s\007' "$name" "$encoded" > "$tty"
}
