#!/usr/bin/env bash
# PreToolUse hook (Bash matcher): agent-side enforcement layer for the email wrapper contract.
# Allowlists ONLY the five agent wrapper binaries; denies raw mail-mutation commands.
#
# TWO-LAYER ENFORCEMENT MODEL (see context/project/email/domain/wrapper-contracts.md):
#   Layer 1 (this hook): gates the agent's OWN top-level Bash tool calls. It does NOT police
#     the wrappers' own subprocesses (himalaya, mbsync, notmuch invoked FROM INSIDE a wrapper
#     binary) — policing those would break the wrappers themselves.
#   Layer 2 (the nix-built wrapper source, ~/.dotfiles modules/home/email/agent-tools.nix): the
#     git-tracked wrapper source itself carries the real safety logic (hash check, staleness,
#     batch cap, state file), so safety holds even for a human invoking a wrapper directly
#     outside an agent session.
#
# This is the canonical copy of this hook for consuming repos; the arrays below are kept
# isolated and copy-liftable. Structural sibling: .claude/extensions/core/hooks/validate-meta-write.sh
# (same stdin-JSON parsing pattern).

set -euo pipefail

# --- isolated, copy-liftable data arrays ----------------------------------------------------

ALLOWED_BINARIES=(
  "email-census"
  "email-classify"
  "email-archive-confirmed"
  "email-delete-confirmed"
  "email-unsubscribe-extract"
)

# grep -E patterns, matched against the full command string. Deny takes precedence over allow
# (a raw himalaya call chained alongside an allowed binary, e.g. via &&, must still be denied).
DENY_PATTERNS=(
  'himalaya[[:space:]]+message[[:space:]]+delete'
  'himalaya[[:space:]]+message[[:space:]]+move'
  'himalaya[[:space:]]+message[[:space:]]+send'
  'himalaya[[:space:]]+template[[:space:]]+send'
  'himalaya[[:space:]]+folder[[:space:]]+expunge'
  '(^|[|;&[:space:]])msmtp([[:space:]]|$)'
  '(^|[|;&[:space:]])secret-tool([[:space:]]|$)'
  '(^|[|;&[:space:]])rm[[:space:]].*Mail'
)

AUDIT_LOG=".claude/tmp/mail-guard-audit.log"

# --- parse tool_input.command from stdin (PreToolUse hook input) ---------------------------

if [ -t 0 ]; then
  COMMAND=$(echo "${CLAUDE_TOOL_INPUT:-}" 2>/dev/null | jq -r '.command // empty' 2>/dev/null) || true
else
  INPUT=$(cat) || true
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true
  if [ -z "$COMMAND" ]; then
    COMMAND=$(echo "${CLAUDE_TOOL_INPUT:-}" 2>/dev/null | jq -r '.command // empty' 2>/dev/null) || true
  fi
fi

if [ -z "$COMMAND" ]; then
  echo '{}'
  exit 0
fi

audit() {
  local decision="$1"
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
  local manifest_hash
  manifest_hash=$(printf '%s' "$COMMAND" \
    | grep -oE -- '--confirm-manifest[[:space:]]+[a-f0-9]+' 2>/dev/null \
    | awk '{print $2}' | head -n1) || true
  printf '%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$decision" "${manifest_hash:-}" "$COMMAND" \
    >> "$AUDIT_LOG" 2>/dev/null || true
}

# --- deny check (first; takes precedence) ---------------------------------------------------

for pat in "${DENY_PATTERNS[@]}"; do
  if printf '%s' "$COMMAND" | grep -qE "$pat"; then
    audit "deny"
    printf '{"permissionDecision": "deny", "permissionDecisionReason": "mail-guard: raw mail-mutation command denied. Use one of the allowlisted wrappers: %s. See context/project/email/domain/wrapper-contracts.md (two-layer enforcement model)."}\n' \
      "$(IFS=,; echo "${ALLOWED_BINARIES[*]}")"
    exit 0
  fi
done

# --- allow check (the five wrapper binaries) -------------------------------------------------

for bin in "${ALLOWED_BINARIES[@]}"; do
  if [[ "$COMMAND" == *"$bin"* ]]; then
    audit "allow"
    echo '{"permissionDecision": "allow"}'
    exit 0
  fi
done

# --- pass-through: unrelated command, no decision -------------------------------------------

echo '{}'
exit 0
