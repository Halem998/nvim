#!/usr/bin/env bash
# state-write.sh - The single mutex-guarded writer for specs/state.json.
#
# Every specs/state.json read-modify-write in this codebase is meant to go through this one
# helper instead of hand-rolling its own `jq ... > tmp && mv tmp state.json` sequence. Before
# this script existed, nine scripts plus two inline command-file write blocks each rolled their
# own sequence, only two of which acquired the specs/.scope-lock mutex at all -- and both of
# those failed OPEN on acquire timeout, so serialization silently stopped applying under exactly
# the contention it exists for. A second, independent corruption channel ran alongside: several
# scripts staged through fixed, shared temp paths with unconditional `rm -f` EXIT traps, so one
# process's normal exit could delete another's in-flight staging file regardless of any mutex
# work. This script closes both channels: fail-closed mutex acquisition, a private per-process
# `mktemp` staging path, and a single acquire -> stage -> transform -> validate -> mv -> release
# sequence that every writer shares.
#
# Usage:
#   state-write.sh <jq-filter> --session-id SID [--arg NAME VALUE]... [--argjson NAME VALUE]...
#                  [--regen-todo] [--dry-run]
#
# Arguments:
#   <jq-filter>     Required. An arbitrary jq filter applied against specs/state.json. Must be
#                   the first positional argument.
#   --session-id    Required. The caller's session_id, used to attribute mutex ownership.
#   --arg NAME VAL      Optional, repeatable. Forwarded to jq as `--arg NAME VAL`.
#   --argjson NAME VAL  Optional, repeatable. Forwarded to jq as `--argjson NAME VAL`.
#   --regen-todo    Optional. When passed, `generate-todo.sh` runs AFTER the mutex is released (in
#                   owned-here mode) so regeneration's wall time is never charged against the
#                   specs/.scope-lock critical section; in guest mode (SCOPE_MUTEX_HELD=1
#                   inherited) it still runs inside the outer caller's own bracket, unchanged. This
#                   means TODO.md itself is last-writer-wins under concurrent --regen-todo calls --
#                   an accepted trade-off, since it is a generated view and its own write is already
#                   atomic (tempfile + mv). A regen failure is a loud warning, not a hard failure --
#                   the state.json write already succeeded, matching update-task-status.sh's
#                   existing posture.
#   --dry-run       Optional. Serializes nothing because it writes nothing: no mutex acquire, no
#                   staging, no transform. Matches update-task-status.sh's existing dry-run
#                   posture. The filter and bindings are still validated for syntax.
#
# Exit codes:
#   0 - success (write applied, or --dry-run preview)
#   1 - usage error (missing filter, missing --session-id, malformed --arg/--argjson)
#   2 - mutex acquire failed: FAIL CLOSED. An ABORT-prefixed message on stderr names the current
#       holder. specs/state.json is untouched.
#   3 - jq transform failed. specs/state.json is left untouched.
#   4 - jq empty validation failed on the transformed output (invalid JSON). specs/state.json is
#       left untouched.
#
# Mutex posture: fail-closed, not fail-open. Honors SCOPE_MUTEX_HELD=1 as guest mode exactly as
# update-task-status.sh's acquire_state_mutex does today -- when an outer holder (e.g.
# orchestrator-postflight.sh) already owns the specs/.scope-lock mutex, this script skips its own
# acquire/release entirely and runs as a guest inside the outer critical section, so nested calls
# from within an outer bracket never self-deadlock. When no outer holder exists and acquisition
# times out, this is a hard failure (ABORT, exit 2) -- the accepted trade-off replacing the old
# fail-open-on-timeout posture. See context/patterns/task-lock.md for the full mutex contract.
#
# Staging: a private `mktemp` file under specs/tmp/ (directory created if absent), never a fixed
# shared path. The EXIT trap is scoped to THIS process's own mktemp path plus mutex release, so
# one process's exit can never delete another's in-flight staging file.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
TMP_DIR="$PROJECT_ROOT/specs/tmp"

# --- Argument parsing ---
JQ_FILTER=""
SESSION_ID=""
REGEN_TODO=false
DRY_RUN=false
JQ_ARGS=()

usage() {
  echo "Usage: $0 <jq-filter> --session-id SID [--arg NAME VALUE]... [--argjson NAME VALUE]... [--regen-todo] [--dry-run]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session-id)
      SESSION_ID="${2:-}"
      shift 2
      ;;
    --arg)
      if [ "$#" -lt 3 ]; then
        echo "Error: --arg requires NAME and VALUE" >&2
        usage
        exit 1
      fi
      JQ_ARGS+=(--arg "$2" "$3")
      shift 3
      ;;
    --argjson)
      if [ "$#" -lt 3 ]; then
        echo "Error: --argjson requires NAME and VALUE" >&2
        usage
        exit 1
      fi
      JQ_ARGS+=(--argjson "$2" "$3")
      shift 3
      ;;
    --regen-todo)
      REGEN_TODO=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -*)
      echo "Error: unknown flag '$1'" >&2
      usage
      exit 1
      ;;
    *)
      if [ -n "$JQ_FILTER" ]; then
        echo "Error: unexpected extra positional argument '$1' (jq filter already given)" >&2
        usage
        exit 1
      fi
      JQ_FILTER="$1"
      shift
      ;;
  esac
done

if [ -z "$JQ_FILTER" ]; then
  echo "Error: missing required jq filter argument" >&2
  usage
  exit 1
fi

if [ -z "$SESSION_ID" ]; then
  echo "Error: missing required --session-id" >&2
  usage
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Dry run: validate filter syntax only, write nothing, acquire nothing ---
if [ "$DRY_RUN" = true ]; then
  dryrun_err=$(jq "${JQ_ARGS[@]}" "$JQ_FILTER" "$STATE_FILE" 2>&1 > /dev/null)
  dryrun_status=$?
  if [ "$dryrun_status" -ne 0 ]; then
    echo "Error: [dry-run] jq filter failed syntax/apply check:" >&2
    [ -n "$dryrun_err" ] && echo "$dryrun_err" >&2
    exit 3
  fi
  echo "[dry-run] filter applies cleanly; no write performed, no mutex acquired."
  exit 0
fi

# --- Mutex acquire (fail-closed; guest mode honored) ---
MUTEX_TOKEN=""
MUTEX_OWNED_HERE=false
STAGE_FILE=""

acquire_mutex() {
  if [ -n "${SCOPE_MUTEX_HELD:-}" ]; then
    echo "Note: an outer holder already owns the specs/.scope-lock mutex (SCOPE_MUTEX_HELD=1 inherited); running as guest, no nested acquire." >&2
    return 0
  fi
  local token
  if ! token=$("$SCRIPT_DIR/task-lock.sh" scope-acquire "$SESSION_ID"); then
    echo "ABORT: timed out waiting for specs/.scope-lock mutex (session=$SESSION_ID); specs/state.json was NOT modified." >&2
    return 1
  fi
  MUTEX_TOKEN="$token"
  MUTEX_OWNED_HERE=true
  export SCOPE_MUTEX_HELD=1
  return 0
}

release_mutex() {
  if [ "$MUTEX_OWNED_HERE" = true ]; then
    "$SCRIPT_DIR/task-lock.sh" scope-release "$MUTEX_TOKEN" >&2 || true
    MUTEX_OWNED_HERE=false
    unset SCOPE_MUTEX_HELD
  fi
}

# EXIT trap scoped to THIS process's own staging file plus mutex release. Idempotent: safe to
# fire even if release_mutex/staging cleanup already ran on an earlier explicit path.
cleanup() {
  [ -n "$STAGE_FILE" ] && rm -f "$STAGE_FILE" 2>/dev/null || true
  release_mutex
}
trap cleanup EXIT

if ! acquire_mutex; then
  exit 2
fi

# --- Staging: private mktemp under specs/tmp/, never a fixed shared path ---
mkdir -p "$TMP_DIR"
STAGE_FILE=$(mktemp "$TMP_DIR/state-write.XXXXXX") || {
  echo "Error: failed to create private staging file under $TMP_DIR" >&2
  exit 3
}

# --- Apply the caller's jq filter with forwarded bindings ---
transform_err=$(jq "${JQ_ARGS[@]}" "$JQ_FILTER" "$STATE_FILE" 2>&1 > "$STAGE_FILE")
transform_status=$?
if [ "$transform_status" -ne 0 ]; then
  echo "Error: jq transform failed; specs/state.json left untouched." >&2
  [ -n "$transform_err" ] && echo "$transform_err" >&2
  exit 3
fi

# --- Validate before mv ---
if ! jq empty "$STAGE_FILE" 2>/dev/null; then
  echo "Error: jq produced invalid JSON; specs/state.json left untouched." >&2
  exit 4
fi

# --- Atomic replace ---
mv "$STAGE_FILE" "$STATE_FILE"
STAGE_FILE=""

# Release the mutex BEFORE regeneration, not after. generate-todo.sh's wall time can exceed both
# SCOPE_MUTEX_ACQUIRE_BUDGET_MS (the waiter timeout) and half of SCOPE_MUTEX_STALE_SEC (the
# staleness reclaim window) against a large state.json, which risks a live holder's mutex being
# reclaimed as stale out from under it. The state.json write is already durable at this point
# (the `mv` above already landed), so releasing early only changes when TODO.md regeneration is
# allowed to run, not the correctness of the state.json write itself. release_mutex() is a no-op
# in guest mode (MUTEX_OWNED_HERE stays false there), so this call has no effect when running
# nested under an outer holder's bracket -- see acquire_mutex()'s guest-mode branch above.
release_mutex

# --- Optional TODO.md regen (outside the critical section in owned-here mode; still inside the
# outer caller's bracket in guest mode, since release_mutex() above was a no-op there) ---
if [ "$REGEN_TODO" = true ]; then
  "$SCRIPT_DIR/generate-todo.sh" || {
    echo "Warning: generate-todo.sh failed (state.json was updated successfully)" >&2
  }
fi

exit 0
