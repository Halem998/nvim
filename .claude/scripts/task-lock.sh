#!/usr/bin/env bash
# task-lock.sh — Atomic per-task concurrency lock (task 788).
#
# Purpose: prevent two concurrent Claude Code sessions from working the SAME task
# directory at once (the 427 failure: an uncommitted in-progress task silently wiped
# by a second session). Provides acquire/heartbeat/release/check subcommands built on
# a genuinely atomic `mkdir` primitive — NOT the non-atomic `jq -n > file` pattern used
# elsewhere in this codebase for state.json writes.
#
# Canonical spec: .claude/context/patterns/task-lock.md (lockfile schema, full
# acquire/heartbeat/release/check contract, stale-threshold constant, override-and-warn
# behavior, refusal-message template). This script implements that spec; consumers
# should reference the spec doc, not restate the logic inline.
#
# Usage:
#   task-lock.sh acquire <task_number> <operation> <session_id> [command]
#   task-lock.sh heartbeat <task_number> <session_id>
#   task-lock.sh release <task_number> <session_id>
#   task-lock.sh check <task_number>
#
# Lockfile layout (per task):
#   specs/{NNN}_{SLUG}/.lock/            <- directory, created via `mkdir` (POSIX-atomic
#                                            exclusive create: mkdir fails if the dir
#                                            already exists, with no TOCTOU race)
#   specs/{NNN}_{SLUG}/.lock/holder.json <- { session_id, task_number, operation,
#                                              acquired_at, heartbeat_at, command }
#
# Stale threshold: TASK_LOCK_STALE_MIN env var, default 30 (minutes). This is
# DISTINCT from and much longer than git-snapshot.sh's unrelated 120-SECOND marker
# freshness window (that window gates one destructive-git exemption; this threshold
# gates whether a lock is still "fresh" for concurrency purposes).
#
# Exit codes:
#   acquire:
#     0 - lock acquired (fresh acquire, same-session re-entry, or stale override)
#     1 - refused: a DIFFERENT session holds a fresh (non-stale) lock
#     2 - usage/task-not-found error
#   heartbeat:
#     0 - heartbeat refreshed, OR no-op with a warning (lock missing / held by another
#         session — heartbeat never blocks the caller)
#     2 - usage/task-not-found error
#   release:
#     0 - always (idempotent; releasing an already-absent lock is success)
#     2 - usage/task-not-found error
#   check:
#     0 - free (no lock held)
#     1 - held, fresh
#     2 - held, stale (heartbeat older than the threshold)
#     3 - usage/task-not-found error
#
# Same-session re-entry (CRITICAL): a session re-acquiring its own lock (e.g.
# `/research 42` then `/plan 42` in one conversation) MUST NOT self-block. `acquire`
# checks holder.json's session_id BEFORE ever treating an existing lock as a refusal
# — matching session_id always succeeds and just refreshes the heartbeat.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# Stale threshold in minutes, overridable via env var. Default 30 (plan range: 30-60).
TASK_LOCK_STALE_MIN="${TASK_LOCK_STALE_MIN:-30}"

# --- resolve_task_dir: task_number -> specs/{NNN}_{SLUG} absolute path ---
# Prefers state.json's project_name (authoritative); falls back to a filesystem glob
# so the lock still works if state.json lookup fails for any reason.
resolve_task_dir() {
  local task_number="$1"
  local padded project_name dir

  padded=$(printf "%03d" "$task_number" 2>/dev/null) || return 1

  if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
    project_name=$(jq -r --argjson num "$task_number" \
      '.active_projects[]? | select(.project_number == $num) | .project_name // empty' \
      "$STATE_FILE" 2>/dev/null)
    if [ -n "$project_name" ]; then
      dir="$PROJECT_ROOT/specs/${padded}_${project_name}"
      if [ -d "$dir" ]; then
        echo "$dir"
        return 0
      fi
    fi
  fi

  dir=$(find "$PROJECT_ROOT/specs" -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1)
  if [ -n "$dir" ]; then
    echo "$dir"
    return 0
  fi

  return 1
}

# --- now_epoch: current UTC epoch seconds ---
now_epoch() {
  date -u +%s
}

# --- iso_now: current UTC ISO8601 timestamp ---
iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# --- write_holder: tmp-file-rename write of holder.json (atomic replace) ---
write_holder() {
  local lock_dir="$1" session_id="$2" task_number="$3" operation="$4" acquired_at="$5" heartbeat_at="$6" command="$7"
  local tmp_file="$lock_dir/holder.json.tmp"

  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$task_number" \
    --arg operation "$operation" \
    --arg acquired_at "$acquired_at" \
    --arg heartbeat_at "$heartbeat_at" \
    --arg command "$command" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $acquired_at, heartbeat_at: $heartbeat_at, command: $command}' \
    > "$tmp_file"

  if [ ! -s "$tmp_file" ]; then
    echo "ERROR: failed to write holder.json (jq produced empty output)" >&2
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$lock_dir/holder.json"
}

# --- read_holder_field: read a single field from holder.json ---
read_holder_field() {
  local lock_dir="$1" field="$2"
  jq -r --arg f "$field" '.[$f] // empty' "$lock_dir/holder.json" 2>/dev/null
}

# --- age_minutes: minutes elapsed since an ISO8601 timestamp ---
age_minutes() {
  local ts="$1" then_epoch now
  then_epoch=$(date -u -d "$ts" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null)
  if [ -z "$then_epoch" ]; then
    echo "999999"
    return 0
  fi
  now=$(now_epoch)
  echo $(( (now - then_epoch) / 60 ))
}

# =====================================================================
# acquire <task_number> <operation> <session_id> [command]
# =====================================================================
cmd_acquire() {
  local task_number="$1" operation="$2" session_id="$3" command="${4:-}"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 2
  }
  lock_dir="$task_dir/.lock"

  if mkdir "$lock_dir" 2>/dev/null; then
    # Fresh acquire: directory did not exist a moment ago (POSIX-atomic).
    write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$(iso_now)" "$(iso_now)" "$command" || return 2
    return 0
  fi

  # mkdir failed: lock directory already exists. Inspect the holder.
  if [ ! -f "$lock_dir/holder.json" ]; then
    # Directory exists but holder.json is missing/corrupt (e.g. interrupted acquire).
    # Treat as acquirable: overwrite in place (do not remove the dir, just the write).
    echo "WARN: lock directory for task $task_number exists without holder.json; treating as recoverable and overriding." >&2
    write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$(iso_now)" "$(iso_now)" "$command" || return 2
    return 0
  fi

  local holder_session holder_heartbeat age
  holder_session=$(read_holder_field "$lock_dir" "session_id")
  holder_heartbeat=$(read_holder_field "$lock_dir" "heartbeat_at")

  if [ "$holder_session" = "$session_id" ]; then
    # Same-session re-entry: MUST NOT self-block. Refresh heartbeat only.
    local acquired_at
    acquired_at=$(read_holder_field "$lock_dir" "acquired_at")
    write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "${acquired_at:-$(iso_now)}" "$(iso_now)" "$command" || return 2
    return 0
  fi

  age=$(age_minutes "$holder_heartbeat")

  if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then
    # Fresh lock held by a DIFFERENT session: refuse.
    echo "ABORT: Task $task_number is locked by session $holder_session (heartbeat ${age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min)." >&2
    echo "  Wait for the lock to go stale, or override manually: rm -rf \"$lock_dir\"" >&2
    return 1
  fi

  # Stale lock held by a different session: override-and-warn (never silent, never permanent).
  echo "WARN: Task $task_number's lock (session $holder_session, heartbeat ${age} min ago) is stale (> ${TASK_LOCK_STALE_MIN} min threshold); overriding and acquiring for $session_id." >&2
  write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$(iso_now)" "$(iso_now)" "$command" || return 2
  return 0
}

# =====================================================================
# heartbeat <task_number> <session_id>
# =====================================================================
cmd_heartbeat() {
  local task_number="$1" session_id="$2"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 2
  }
  lock_dir="$task_dir/.lock"

  if [ ! -d "$lock_dir" ] || [ ! -f "$lock_dir/holder.json" ]; then
    echo "WARN: heartbeat no-op — no lock held for task $task_number." >&2
    return 0
  fi

  local holder_session
  holder_session=$(read_holder_field "$lock_dir" "session_id")

  if [ "$holder_session" != "$session_id" ]; then
    echo "WARN: heartbeat no-op — task $task_number's lock is held by a different session ($holder_session), not $session_id." >&2
    return 0
  fi

  local operation acquired_at command
  operation=$(read_holder_field "$lock_dir" "operation")
  acquired_at=$(read_holder_field "$lock_dir" "acquired_at")
  command=$(read_holder_field "$lock_dir" "command")
  write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$acquired_at" "$(iso_now)" "$command" || return 2
  return 0
}

# =====================================================================
# release <task_number> <session_id>
# =====================================================================
cmd_release() {
  local task_number="$1"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 2
  }
  lock_dir="$task_dir/.lock"

  # Unconditional and idempotent: success/partial/failed all release; an already-absent
  # lock is not an error.
  rm -rf "$lock_dir" 2>/dev/null || true
  return 0
}

# =====================================================================
# check <task_number>
# =====================================================================
cmd_check() {
  local task_number="$1"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 3
  }
  lock_dir="$task_dir/.lock"

  if [ ! -d "$lock_dir" ] || [ ! -f "$lock_dir/holder.json" ]; then
    echo "free"
    return 0
  fi

  local holder_session holder_heartbeat age
  holder_session=$(read_holder_field "$lock_dir" "session_id")
  holder_heartbeat=$(read_holder_field "$lock_dir" "heartbeat_at")
  age=$(age_minutes "$holder_heartbeat")

  if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then
    echo "held-fresh session=$holder_session heartbeat_age_min=$age threshold_min=$TASK_LOCK_STALE_MIN"
    return 1
  else
    echo "held-stale session=$holder_session heartbeat_age_min=$age threshold_min=$TASK_LOCK_STALE_MIN"
    return 2
  fi
}

# =====================================================================
# Dispatch
# =====================================================================
SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  acquire)
    if [ "$#" -lt 3 ]; then
      echo "Usage: $0 acquire <task_number> <operation> <session_id> [command]" >&2
      exit 2
    fi
    cmd_acquire "$@"
    exit $?
    ;;
  heartbeat)
    if [ "$#" -lt 2 ]; then
      echo "Usage: $0 heartbeat <task_number> <session_id>" >&2
      exit 2
    fi
    cmd_heartbeat "$@"
    exit $?
    ;;
  release)
    if [ "$#" -lt 2 ]; then
      echo "Usage: $0 release <task_number> <session_id>" >&2
      exit 2
    fi
    cmd_release "$@"
    exit $?
    ;;
  check)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 check <task_number>" >&2
      exit 3
    fi
    cmd_check "$@"
    exit $?
    ;;
  *)
    echo "Usage: $0 {acquire|heartbeat|release|check} ..." >&2
    exit 2
    ;;
esac
