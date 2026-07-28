#!/usr/bin/env bash
# email-preference-harvest.sh - Deterministic normalization/tally/dedup helper for the
# skill-email-cleanup Stage 7 harvest.
#
# Implements the deterministic, testable logic from the authoritative design at
# .claude/extensions/email/context/project/email/design/email-to-memory-preferences.md:
#   - identity-key normalization (design §2.2)
#   - local-part redaction (design §3.3)
#   - per-action tally CREATE/EXTEND/UPDATE arithmetic (design §3.2, §4.3)
#   - exact-key dedup lookup against .memory/memory-index.json (design §4.1)
#   - evidentiary threshold evaluation (design §1.4)
#
# Structured as pure, side-effect-free subcommands (each reads only its explicit
# arguments/files and prints JSON or a scalar to stdout) so it is unit-testable from
# .claude/tests/test-email-preference-harvest.sh without touching the live vault.
#
# Usage:
#   email-preference-harvest.sh normalize "<sender>"
#   email-preference-harvest.sh freemail "<domain>"
#   email-preference-harvest.sh identity "<sender>" [--rollup]
#   email-preference-harvest.sh dedup "<memory-index.json path>" "<topic key>"
#   email-preference-harvest.sh tally-op "<existing tally JSON | null>" "<action>" "<count>" "<date>"
#   email-preference-harvest.sh dominant "<tally JSON>"
#   email-preference-harvest.sh threshold "<tally JSON>" "<uniform: true|false>"
#
# Exit codes: 0 on success, 1 on usage/argument error, 2 on internal jq failure.

set -euo pipefail

# --- Freemail / shared-domain carve-out (design §2.2 step 5, §2.3) ---
# Never rolled up to a domain-only key: each full address is its own identity.
FREEMAIL_DOMAINS=(
  "gmail.com" "yahoo.com" "outlook.com" "hotmail.com" "live.com" "icloud.com"
  "aol.com" "proton.me" "protonmail.com"
)

usage() {
  echo "Usage: $0 {normalize|freemail|identity|dedup|tally-op|dominant|threshold} [args...]" >&2
  exit 1
}

# --- normalize: extract + lowercase + plus-strip the bare address from a raw sender string ---
# Handles "Display Name <addr>" and bare "addr" forms, including DMARC "via" relay
# rewrites (design §2.3/§2.4) since only the bracketed/bare address token is extracted.
cmd_normalize() {
  local sender="${1:-}"
  [ -z "$sender" ] && { echo "normalize: missing <sender> argument" >&2; exit 1; }

  # Extract the first bare-address-shaped token (handles both "Name <addr>" and bare "addr").
  local bare_address
  bare_address=$(echo "$sender" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+' | head -1 || true)
  if [ -z "$bare_address" ]; then
    echo "normalize: no email address found in sender string: $sender" >&2
    exit 1
  fi

  # Lowercase the entire address.
  bare_address=$(echo "$bare_address" | tr '[:upper:]' '[:lower:]')

  local domain local_part
  domain="${bare_address##*@}"
  local_part="${bare_address%@*}"

  # Strip a plus-addressing tag from the local-part: "local+tag" -> "local".
  local_part="${local_part%%+*}"

  jq -n --arg bare "$bare_address" --arg local "$local_part" --arg domain "$domain" \
    '{bare_address: $bare, local_part: $local, domain: $domain}'
}

# --- freemail: is a domain in the never-roll-up carve-out list? ---
cmd_freemail() {
  local domain="${1:-}"
  [ -z "$domain" ] && { echo "freemail: missing <domain> argument" >&2; exit 1; }
  domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
  local d
  for d in "${FREEMAIL_DOMAINS[@]}"; do
    if [ "$domain" = "$d" ]; then
      echo "true"
      return 0
    fi
  done
  echo "false"
}

# --- identity: normalize + redact + (optionally) roll up to the final stored key ---
# design §3.3: domain stays plaintext; local-part -> sha256(local-part)[:12]. Domain-rollup
# keys (non-freemail only, --rollup) carry no local-part and need no hash.
cmd_identity() {
  local sender="${1:-}"
  local rollup="false"
  if [ "${2:-}" = "--rollup" ]; then
    rollup="true"
  fi
  [ -z "$sender" ] && { echo "identity: missing <sender> argument" >&2; exit 1; }

  local norm
  norm=$(cmd_normalize "$sender")
  local local_part domain bare_address
  local_part=$(echo "$norm" | jq -r '.local_part')
  domain=$(echo "$norm" | jq -r '.domain')
  bare_address=$(echo "$norm" | jq -r '.bare_address')

  local is_freemail
  is_freemail=$(cmd_freemail "$domain")

  local rolled_up="false"
  local hash="null"
  local key

  if [ "$rollup" = "true" ] && [ "$is_freemail" = "false" ]; then
    rolled_up="true"
    key="$domain"
    jq -n --arg bare "$bare_address" --arg local "$local_part" --arg domain "$domain" \
      --argjson freemail "$is_freemail" --argjson rolled_up "$rolled_up" \
      --arg key "$key" \
      '{bare_address: $bare, local_part: $local, domain: $domain, freemail: $freemail,
        rolled_up: $rolled_up, hash: null, key: $key}'
  else
    hash=$(printf '%s' "$local_part" | sha256sum | cut -c1-12)
    key="${hash}@${domain}"
    jq -n --arg bare "$bare_address" --arg local "$local_part" --arg domain "$domain" \
      --argjson freemail "$is_freemail" --argjson rolled_up "$rolled_up" \
      --arg hash "$hash" --arg key "$key" \
      '{bare_address: $bare, local_part: $local, domain: $domain, freemail: $freemail,
        rolled_up: $rolled_up, hash: $hash, key: $key}'
  fi
}

# --- dedup: exact topic-key lookup against memory-index.json (design §4.1) ---
# Prints the matched entry object, or "null" on a miss (never errors on a miss).
cmd_dedup() {
  local index_file="${1:-}"
  local topic_key="${2:-}"
  [ -z "$index_file" ] && { echo "dedup: missing <memory-index.json path> argument" >&2; exit 1; }
  [ -z "$topic_key" ] && { echo "dedup: missing <topic key> argument" >&2; exit 1; }

  if [ ! -f "$index_file" ]; then
    echo "null"
    return 0
  fi

  jq --arg k "$topic_key" '[.entries[]? | select(.topic == $k)] | first // null' "$index_file"
}

# --- dominant: argmax(delete_count, archive_count, keep_count), ties broken by more
# recent per-action last_seen (design §3.2) ---
cmd_dominant() {
  local tally_json="${1:-}"
  [ -z "$tally_json" ] && { echo "dominant: missing <tally JSON> argument" >&2; exit 1; }

  echo "$tally_json" | jq -r '
    [
      {action: "delete", count: (.delete_count // 0), last_seen: (.delete_last_seen // "")},
      {action: "archive", count: (.archive_count // 0), last_seen: (.archive_last_seen // "")},
      {action: "keep", count: (.keep_count // 0), last_seen: (.keep_last_seen // "")}
    ]
    | max_by([.count, .last_seen])
    | .action
  '
}

# --- tally-op: apply one round of confirmed actions to an existing (or absent) tally,
# returning the operation (CREATE/EXTEND/UPDATE) and the updated tally (design §4.3) ---
# The tally arithmetic is identical for EXTEND and UPDATE (bump the round action's counter,
# update its last_seen, never touch the other two); only the label — and the memory-body
# History/superseded handling a caller layers on top — differs.
cmd_tally_op() {
  local existing="${1:-}"
  local round_action="${2:-}"
  local round_count="${3:-}"
  local today="${4:-}"

  [ -z "$round_action" ] && { echo "tally-op: missing <action> argument" >&2; exit 1; }
  [ -z "$round_count" ] && { echo "tally-op: missing <count> argument" >&2; exit 1; }
  [ -z "$today" ] && { echo "tally-op: missing <date> argument" >&2; exit 1; }

  case "$round_action" in
    delete|archive|keep) ;;
    *) echo "tally-op: invalid action '$round_action' (expected delete|archive|keep)" >&2; exit 1 ;;
  esac

  local operation="CREATE"
  local base_tally='{"delete_count":0,"delete_last_seen":null,"archive_count":0,"archive_last_seen":null,"keep_count":0,"keep_last_seen":null}'

  if [ -n "$existing" ] && [ "$existing" != "null" ] && [ "$existing" != "" ]; then
    local stored_dominant
    stored_dominant=$(cmd_dominant "$existing")
    if [ "$round_action" = "$stored_dominant" ]; then
      operation="EXTEND"
    else
      operation="UPDATE"
    fi
    base_tally="$existing"
  fi

  local updated_tally
  updated_tally=$(echo "$base_tally" | jq \
    --arg action "$round_action" --argjson count "$round_count" --arg today "$today" '
    .["\($action)_count"] = ((.["\($action)_count"] // 0) + $count) |
    .["\($action)_last_seen"] = $today
  ')

  jq -n --arg op "$operation" --argjson tally "$updated_tally" '{operation: $op, tally: $tally}'
}

# --- threshold: evidentiary threshold per design §1.4 ---
# Uniform-batch (this pass) OR rolling N>=3 confirms at >=80% consistency, evaluated
# against the STORED (post-increment) tally passed in by the caller.
cmd_threshold() {
  local tally_json="${1:-}"
  local uniform="${2:-false}"
  [ -z "$tally_json" ] && { echo "threshold: missing <tally JSON> argument" >&2; exit 1; }

  if [ "$uniform" = "true" ]; then
    echo "true"
    return 0
  fi

  echo "$tally_json" | jq -r '
    (.delete_count // 0) as $d | (.archive_count // 0) as $a | (.keep_count // 0) as $k |
    ($d + $a + $k) as $total |
    ([$d, $a, $k] | max) as $dominant_count |
    if $total == 0 then false
    else ($dominant_count >= 3) and (($dominant_count / $total) >= 0.8)
    end
  '
}

# --- Dispatch ---
[ $# -ge 1 ] || usage
subcommand="$1"
shift

case "$subcommand" in
  normalize) cmd_normalize "$@" ;;
  freemail) cmd_freemail "$@" ;;
  identity) cmd_identity "$@" ;;
  dedup) cmd_dedup "$@" ;;
  tally-op) cmd_tally_op "$@" ;;
  dominant) cmd_dominant "$@" ;;
  threshold) cmd_threshold "$@" ;;
  *) usage ;;
esac
