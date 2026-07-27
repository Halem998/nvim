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
#   task-lock.sh init-marker <file_path>    (stdin = JSON content; task 808)
#   task-lock.sh scope-acquire <session_id> [stale_sec]
#   task-lock.sh scope-release <token>
#   task-lock.sh commit-acquire <session_id> [stale_sec]
#   task-lock.sh commit-release <token>
#
# scope-acquire/scope-release expose the specs/.scope-lock/ global mutex (defined below as
# acquire_scope_mutex/release_scope_mutex, originally introduced for cmd_acquire's cross-task
# overlap scan) as a standalone CLI primitive for callers that need to bracket a critical section
# spanning MULTIPLE process invocations (e.g. a shell script wrapping several other scripts' state
# writes) rather than a single function's lifetime. commit-acquire/commit-release expose a SIBLING
# mutex, specs/.commit-lock/, serializing the git add + git commit pair around scoped commits (see
# scripts/git-commit-scoped.sh) -- a DISTINCT directory from .scope-lock, guarded by a DISTINCT
# reentrancy flag (COMMIT_MUTEX_HELD, never SCOPE_MUTEX_HELD). Two independent critical sections
# need two independent held-flags: reusing .scope-lock for commits would either silently defeat
# serialization (a commit running inside a window where SCOPE_MUTEX_HELD is already exported would
# wrongly treat an outer holder's scope-mutex ownership as covering the unrelated commit mutex too)
# or attempt a nested acquire on a documented non-reentrant primitive. See
# .claude/context/patterns/task-lock.md for the full contract: neither mutex is reentrant
# (SCOPE_MUTEX_HELD / COMMIT_MUTEX_HELD is the sanctioned way for a callee to detect its OWN outer
# holder and skip nested acquire/release), staleness is holder-declared (the acquiring process's
# chosen stale_sec is written into the mutex directory so every waiter honors the SAME window, not
# its own default), and release is owner-token-verified (an unconditional rm -rf on release would
# be unsafe once acquire and release are separate processes -- a stale-reclaimed holder's release
# must never delete a successor's mutex).
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
#   init-marker (task 808 — generic atomic-on-creation marker-file primitive,
#   file-granularity, independent of and unrelated to the acquire/heartbeat/
#   release/check task-number `.lock/` mechanism above):
#     0 - created (fresh; caller treats this as a fresh start)
#     1 - already exists (valid JSON found); caller resumes from the existing file
#     2 - usage/write-error, or an orphaned claim persisted after one self-heal retry
#   scope-acquire (specs/.scope-lock/ global mutex, exposed as a standalone CLI subcommand —
#   see the top-of-file usage comment):
#     0 - acquired; owner token printed on stdout
#     2 - timed out waiting for the mutex (fail closed; current holder named on stderr)
#   scope-release:
#     0 - always (best-effort; a token mismatch or absent mutex is a loud WARNING on stderr,
#         never a failure — release must never fail a caller's cleanup path)
#   commit-acquire (specs/.commit-lock/ sibling mutex serializing scoped git commits; see the
#   top-of-file usage comment and scripts/git-commit-scoped.sh, the sole intended caller):
#     0 - acquired; owner token printed on stdout
#     2 - timed out waiting for the mutex (15s acquire budget, sized for MAX_TASKS=8 concurrent
#         holders; callers are expected to fail OPEN with a loud warning on this timeout rather
#         than abort, since a fail-open commit is still path-scoped -- see git-commit-scoped.sh)
#   commit-release:
#     0 - always (best-effort; a token mismatch or absent mutex is a loud WARNING on stderr,
#         never a failure — release must never fail a caller's cleanup path)
#
# Same-session re-entry (CRITICAL): a session re-acquiring its own lock (e.g.
# `/research 42` then `/plan 42` in one conversation) MUST NOT self-block. `acquire`
# checks holder.json's session_id BEFORE ever treating an existing lock as a refusal
# — matching session_id always succeeds and just refreshes the heartbeat.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
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

# --- get_file_scope: task_number -> compact JSON file_scope array (task 809) ---
# Graceful degradation mirrors resolve_task_dir: any lookup failure (missing state
# file, no jq, unknown task, absent/null field) resolves to "[]", never a non-zero
# exit or stderr noise that could break the acquire caller.
get_file_scope() {
  local task_number="$1" result
  if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
    result=$(jq -c --argjson num "$task_number" \
      '(.active_projects[]? | select(.project_number == $num) | .file_scope) // empty' \
      "$STATE_FILE" 2>/dev/null)
    if [ -n "$result" ] && [ "$result" != "null" ]; then
      echo "$result"
      return 0
    fi
  fi
  echo "[]"
}

# --- scopes_overlap: jq transcription of file-footprint-overlap.md (lines 43-59) ---
# scope_a_json / scope_b_json are compact JSON arrays of path strings. Prints the
# first overlapping path FROM scope_b (the "foreign" side, per cmd_acquire's call
# convention scopes_overlap "$own_scope" "$other_scope") on stdout when an overlap
# is found; prints nothing otherwise. Callers use `[ -n "$out" ]` as the boolean
# test and reuse the printed path in ABORT/WARN messages. Mirrors the canonical
# rtrimstr("/") normalization and exact-match-or-either-side-prefix rule exactly;
# does not restate or fork the algorithm.
scopes_overlap() {
  local scope_a="$1" scope_b="$2"
  jq -n -r --argjson a "$scope_a" --argjson b "$scope_b" '
    def norm: rtrimstr("/");
    ($a // []) as $sa | ($b // []) as $sb |
    [ $sa[] as $pa | $sb[] as $pb |
      ($pa|norm) as $na | ($pb|norm) as $nb |
      select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/"))) |
      $pb
    ] | first // empty
  ' 2>/dev/null
}

# --- find_held_locks: list foreign .lock dirs under specs/, excluding one dir ---
# Skips any lock dir whose holder.json is missing or unreadable/invalid (never lets
# a corrupt foreign holder abort the caller's own acquire).
find_held_locks() {
  local exclude_dir="$1" dir
  find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 2 -type d -name ".lock" 2>/dev/null |
    while IFS= read -r dir; do
      [ "$dir" = "$exclude_dir" ] && continue
      [ -f "$dir/holder.json" ] || continue
      jq -e . "$dir/holder.json" >/dev/null 2>&1 || continue
      echo "$dir"
    done
}

# --- Named-mutex primitives (generalized from this file's original specs/.scope-lock/-only
# implementation, so a second, independent mutex directory -- specs/.commit-lock/, added below
# for scoped-commit serialization -- can reuse the exact same mkdir/staleness/wait-budget logic
# without a second hand-copied implementation to drift out of sync). ---

# acquire_named_mutex <mutex_dirname> <requested_stale> <default_stale_sec> <wait_budget_ms>
#
# <mutex_dirname> is a bare directory name resolved under specs/ (e.g. ".scope-lock",
# ".commit-lock") -- each caller's wrapper below fixes its own directory, default staleness, and
# wait budget, so this function itself has no knowledge of which mutex it is serving.
#
# Staleness is holder-declared, not waiter-declared: the successful acquirer writes its own
# tolerated window into $mutex_dir/stale_sec alongside claimed_at, and every waiter (including
# waiters with a different default) reads THAT file when deciding whether to reclaim. This lets a
# long-running critical section (e.g. scope-acquire called with a generous stale_sec) declare a
# window all concurrent waiters honor, instead of a short-window waiter reclaiming the mutex out
# from under a still-live, longer-running holder.
acquire_named_mutex() {
  local mutex_dirname="$1" requested_stale="${2:-}" default_stale_sec="$3" wait_budget_ms="$4"
  local stale_sec
  if [[ "$requested_stale" =~ ^[0-9]+$ ]]; then
    stale_sec="$requested_stale"
  else
    stale_sec="$default_stale_sec"
  fi

  local mutex_dir="$PROJECT_ROOT/specs/${mutex_dirname}"
  local waited_ms=0 claimed_at now age holder_stale_sec
  while true; do
    if mkdir "$mutex_dir" 2>/dev/null; then
      now_epoch > "$mutex_dir/claimed_at" 2>/dev/null || true
      echo "$stale_sec" > "$mutex_dir/stale_sec" 2>/dev/null || true
      return 0
    fi

    claimed_at=$(cat "$mutex_dir/claimed_at" 2>/dev/null)
    now=$(now_epoch)
    holder_stale_sec=$(cat "$mutex_dir/stale_sec" 2>/dev/null)
    if ! [[ "$holder_stale_sec" =~ ^[0-9]+$ ]]; then
      holder_stale_sec="$default_stale_sec"
    fi
    if [ -n "$claimed_at" ]; then
      age=$(( now - claimed_at ))
      if [ "$age" -gt "$holder_stale_sec" ]; then
        echo "WARN: reclaiming stale specs/${mutex_dirname} mutex (age ${age}s > holder-declared ${holder_stale_sec}s)." >&2
        rm -rf "$mutex_dir" 2>/dev/null || true
        continue
      fi
    fi

    if [ "$waited_ms" -ge "$wait_budget_ms" ]; then
      return 1
    fi
    sleep 0.05
    waited_ms=$(( waited_ms + 50 ))
  done
}

release_named_mutex() {
  local mutex_dirname="$1"
  rm -rf "$PROJECT_ROOT/specs/${mutex_dirname}" 2>/dev/null || true
}

# --- specs/.scope-lock/ global mutex (task 809) ---
# Closes the scan-then-mkdir TOCTOU race around cmd_acquire's cross-task overlap
# scan. Distinct staleness window from TASK_LOCK_STALE_MIN: a stuck mutex is a bug,
# not ordinary contention, so this window is short and acquire_scope_mutex fails
# CLOSED (non-zero) on timeout rather than ever failing open.
SCOPE_MUTEX_STALE_SEC=10
SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000

# acquire_scope_mutex [stale_sec]
#
# Thin wrapper over acquire_named_mutex, preserving this function's original signature and
# behavior byte-for-byte (same directory, same 10s default staleness, same 5000ms wait budget)
# for cmd_acquire's pre-existing no-argument call site and every other existing caller.
acquire_scope_mutex() {
  local requested_stale="${1:-}"
  acquire_named_mutex ".scope-lock" "$requested_stale" "$SCOPE_MUTEX_STALE_SEC" "$SCOPE_MUTEX_ACQUIRE_BUDGET_MS"
}

release_scope_mutex() {
  release_named_mutex ".scope-lock"
}

# --- specs/.commit-lock/ sibling mutex (serializes the git add + git commit pair around scoped
# commits; see scripts/git-commit-scoped.sh, the sole intended caller) ---
# A DISTINCT mutex directory and a DISTINCT reentrancy flag (COMMIT_MUTEX_HELD, never
# SCOPE_MUTEX_HELD) from .scope-lock above -- see the top-of-file usage comment for why reusing
# .scope-lock here would be unsafe. Larger acquire budget than .scope-lock (15s vs 5s) because it
# is sized for MAX_TASKS=8 concurrent committers rather than a single fast scan-then-mkdir
# sequence; correspondingly longer holder-declared staleness (30s vs 10s), generous against
# measured sub-second commits but short enough to reclaim a genuinely stuck holder.
COMMIT_MUTEX_STALE_SEC=30
COMMIT_MUTEX_ACQUIRE_BUDGET_MS=15000

# acquire_commit_mutex [stale_sec]
acquire_commit_mutex() {
  local requested_stale="${1:-}"
  acquire_named_mutex ".commit-lock" "$requested_stale" "$COMMIT_MUTEX_STALE_SEC" "$COMMIT_MUTEX_ACQUIRE_BUDGET_MS"
}

release_commit_mutex() {
  release_named_mutex ".commit-lock"
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

  # --- task 809: cross-task file_scope overlap check, mutex-guarded ---
  # Wraps the scan-and-decide below AND the pre-existing own-task mkdir/holder logic in
  # the global specs/.scope-lock/ mutex, closing the scan-then-mkdir TOCTOU race. Fails
  # CLOSED (return 2) on mutex timeout — a stuck mutex is a bug, never silently bypassed.
  if ! acquire_scope_mutex; then
    echo "ERROR: timed out waiting for specs/.scope-lock mutex during task $task_number's acquire; another acquire may be stuck." >&2
    return 2
  fi
  trap 'release_scope_mutex' RETURN

  local own_scope
  own_scope=$(get_file_scope "$task_number")
  if [ -n "$own_scope" ] && [ "$own_scope" != "[]" ]; then
    local held_dir other_task other_session other_scope overlap_path other_heartbeat other_age
    while IFS= read -r held_dir; do
      [ -n "$held_dir" ] || continue
      other_task=$(read_holder_field "$held_dir" "task_number")
      other_session=$(read_holder_field "$held_dir" "session_id")
      # Skip: unreadable holder, defensive self-match, or same-session bypass (report
      # Decisions — a session's own concurrent work never blocks itself).
      [ -n "$other_task" ] || continue
      [ "$other_task" = "$task_number" ] && continue
      [ "$other_session" = "$session_id" ] && continue

      other_scope=$(get_file_scope "$other_task")
      overlap_path=$(scopes_overlap "$own_scope" "$other_scope")
      if [ -n "$overlap_path" ]; then
        other_heartbeat=$(read_holder_field "$held_dir" "heartbeat_at")
        other_age=$(age_minutes "$other_heartbeat")
        if [ "$other_age" -le "$TASK_LOCK_STALE_MIN" ]; then
          # Fresh overlapping foreign lock: refuse. The foreign lock is only ever read
          # here, never mutated.
          echo "ABORT: Task $task_number's file_scope overlaps task $other_task's file_scope at \"$overlap_path\" and task $other_task is locked by session $other_session (heartbeat ${other_age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min)." >&2
          echo "  Wait for task $other_task's lock to go stale, or coordinate with that session before retrying." >&2
          return 1
        fi
        # Stale overlapping foreign lock: warn and proceed. Never touch the foreign lock.
        echo "WARN: task $other_task's file_scope overlaps this acquire at \"$overlap_path\", but task $other_task's lock (session $other_session, heartbeat ${other_age} min ago) is stale (> ${TASK_LOCK_STALE_MIN} min); proceeding without modifying it." >&2
      fi
    done < <(find_held_locks "$lock_dir")
  fi
  # --- end task 809 cross-task check ---

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
# scope-acquire <session_id> [stale_sec]
# =====================================================================
# Standalone CLI exposure of acquire_scope_mutex for cross-process critical sections (see the
# top-of-file usage comment and .claude/context/patterns/task-lock.md for the full contract).
# Deliberately does NOT install a `trap ... RETURN` -- unlike cmd_acquire's task-scoped lock
# (which lives and dies within one function call), this mutex is meant to outlive this process:
# the caller holds the printed token across other commands and releases it explicitly (or via its
# own EXIT trap) with a separate `scope-release` invocation.
cmd_scope_acquire() {
  local session_id="$1" stale_sec="${2:-}"
  local mutex_dir="$PROJECT_ROOT/specs/.scope-lock"

  if ! acquire_scope_mutex "$stale_sec"; then
    local holder_session holder_pid
    holder_session=$(jq -r '.session_id // empty' "$mutex_dir/owner" 2>/dev/null)
    holder_pid=$(jq -r '.pid // empty' "$mutex_dir/owner" 2>/dev/null)
    echo "ERROR: timed out waiting for specs/.scope-lock mutex (session=$session_id); current holder: session=${holder_session:-unknown} pid=${holder_pid:-unknown}." >&2
    return 2
  fi

  local pid claimed_epoch token
  pid=$$
  claimed_epoch=$(now_epoch)
  token="${session_id}:${pid}:${claimed_epoch}"

  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --argjson claimed_epoch "$claimed_epoch" \
    --arg token "$token" \
    '{session_id: $session_id, pid: $pid, claimed_epoch: $claimed_epoch, token: $token}' \
    > "$mutex_dir/owner" 2>/dev/null

  echo "$token"
  return 0
}

# =====================================================================
# scope-release <token>
# =====================================================================
# Owner-token-verified release: because acquire and release are separate processes here (unlike
# acquire_scope_mutex's task 809 in-function usage), an unconditional rm -rf would be unsafe if
# this holder was stale-reclaimed and a successor already re-acquired -- this release would then
# delete the SUCCESSOR's mutex. A token mismatch is therefore a loud, non-silent WARNING (it means
# the critical section overran its declared stale_sec and a concurrent writer may have
# interleaved), never a forced removal. Release is best-effort and always exits 0 -- it must never
# fail a caller's cleanup path.
cmd_scope_release() {
  local token="$1"
  local mutex_dir="$PROJECT_ROOT/specs/.scope-lock"

  if [ ! -d "$mutex_dir" ]; then
    echo "WARN: scope-release (token=$token) found no specs/.scope-lock mutex -- already released or never held." >&2
    return 0
  fi

  local owner_token
  owner_token=$(jq -r '.token // empty' "$mutex_dir/owner" 2>/dev/null)

  if [ "$owner_token" != "$token" ]; then
    echo "WARN: scope-release token mismatch (given=$token current-holder=${owner_token:-unknown}); NOT releasing. This means the critical section overran its declared staleness window and a concurrent writer may have reclaimed the mutex -- investigate rather than ignore." >&2
    return 0
  fi

  release_scope_mutex
  return 0
}

# =====================================================================
# commit-acquire <session_id> [stale_sec]
# =====================================================================
# Standalone CLI exposure of acquire_commit_mutex, mirroring cmd_scope_acquire exactly (same
# owner-token format, same owner-file write, same no-trap-of-its-own contract -- the caller is
# responsible for release on every exit path, per .claude/context/patterns/task-lock.md). Serves
# a DISTINCT mutex (specs/.commit-lock/) from cmd_scope_acquire's specs/.scope-lock/.
cmd_commit_acquire() {
  local session_id="$1" stale_sec="${2:-}"
  local mutex_dir="$PROJECT_ROOT/specs/.commit-lock"

  if ! acquire_commit_mutex "$stale_sec"; then
    local holder_session holder_pid
    holder_session=$(jq -r '.session_id // empty' "$mutex_dir/owner" 2>/dev/null)
    holder_pid=$(jq -r '.pid // empty' "$mutex_dir/owner" 2>/dev/null)
    echo "ERROR: timed out waiting for specs/.commit-lock mutex (session=$session_id); current holder: session=${holder_session:-unknown} pid=${holder_pid:-unknown}." >&2
    return 2
  fi

  local pid claimed_epoch token
  pid=$$
  claimed_epoch=$(now_epoch)
  token="${session_id}:${pid}:${claimed_epoch}"

  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --argjson claimed_epoch "$claimed_epoch" \
    --arg token "$token" \
    '{session_id: $session_id, pid: $pid, claimed_epoch: $claimed_epoch, token: $token}' \
    > "$mutex_dir/owner" 2>/dev/null

  echo "$token"
  return 0
}

# =====================================================================
# commit-release <token>
# =====================================================================
# Owner-token-verified release, mirroring cmd_scope_release exactly. See that function's comment
# for the full rationale (a stale-reclaimed holder's release must never delete a successor's
# mutex). Always exits 0 -- release is best-effort and must never fail a caller's cleanup path.
cmd_commit_release() {
  local token="$1"
  local mutex_dir="$PROJECT_ROOT/specs/.commit-lock"

  if [ ! -d "$mutex_dir" ]; then
    echo "WARN: commit-release (token=$token) found no specs/.commit-lock mutex -- already released or never held." >&2
    return 0
  fi

  local owner_token
  owner_token=$(jq -r '.token // empty' "$mutex_dir/owner" 2>/dev/null)

  if [ "$owner_token" != "$token" ]; then
    echo "WARN: commit-release token mismatch (given=$token current-holder=${owner_token:-unknown}); NOT releasing. This means the critical section overran its declared staleness window and a concurrent writer may have reclaimed the mutex -- investigate rather than ignore." >&2
    return 0
  fi

  release_commit_mutex
  return 0
}

# =====================================================================
# init-marker <file_path>   (task 808)
# =====================================================================
# Generic atomic-on-creation primitive for marker/state files that were using a
# TOCTOU-prone "check-then-create" `if [ -f X ]; then resume; else jq -n ... > X; fi`
# pattern (e.g. .orchestrator-loop-guard, .orchestrator-churn-state.json). Reuses
# this script's existing exclusivity idiom — an atomic `mkdir` gate plus a
# tmp-file-`mv` payload write, mirroring `write_holder` above — but claims a
# `${file_path}.init` directory, which is entirely distinct from the task-number
# `.lock/` directory used by acquire/heartbeat/release/check. init-marker is
# file-granularity and composes independently of the task-number lock: it does
# not read, call, or modify cmd_acquire, write_holder, or `.lock/` in any way.
cmd_init_marker() {
  local file_path="$1"
  local init_dir="${file_path}.init"
  local tmp_file="${file_path}.tmp"
  local attempt recheck

  for attempt in 1 2; do
    if mkdir "$init_dir" 2>/dev/null; then
      # Won the exclusivity claim: write stdin payload via tmp-file + mv
      # (atomic replace), then release the claim directory.
      cat > "$tmp_file"
      if [ ! -s "$tmp_file" ]; then
        echo "ERROR: init-marker failed to write $file_path (stdin produced empty output)" >&2
        rm -f "$tmp_file"
        rmdir "$init_dir" 2>/dev/null || true
        return 2
      fi
      mv "$tmp_file" "$file_path"
      rmdir "$init_dir" 2>/dev/null || true
      return 0
    fi

    # mkdir failed: another process holds (or held) the init claim. Before
    # concluding the claim is orphaned, do a bounded recheck (poll briefly)
    # for the winner's payload to appear — this distinguishes "actively being
    # written by a live racer" (expected under concurrency) from "abandoned by
    # a crashed initializer" (the only case that should trigger self-heal).
    for recheck in 1 2 3 4 5 6 7 8 9 10; do
      if [ -f "$file_path" ] && jq empty "$file_path" >/dev/null 2>&1; then
        return 1
      fi
      [ -d "$init_dir" ] || break
      sleep 0.05
    done

    if [ -f "$file_path" ] && jq empty "$file_path" >/dev/null 2>&1; then
      return 1
    fi

    if [ "$attempt" -eq 1 ]; then
      # Still absent/corrupt after the bounded recheck: a crashed initializer
      # left an orphaned claim. Self-heal (never silent, never permanent):
      # warn, remove the stale claim, retry the mkdir once.
      echo "WARN: init-marker found a stale claim ($init_dir) with no valid $file_path after recheck; self-healing and retrying." >&2
      rmdir "$init_dir" 2>/dev/null || true
      continue
    fi
  done

  echo "ERROR: init-marker failed to create $file_path after retry" >&2
  return 2
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
  init-marker)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 init-marker <file_path>" >&2
      exit 2
    fi
    cmd_init_marker "$@"
    exit $?
    ;;
  scope-acquire)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 scope-acquire <session_id> [stale_sec]" >&2
      exit 2
    fi
    cmd_scope_acquire "$@"
    exit $?
    ;;
  scope-release)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 scope-release <token>" >&2
      exit 2
    fi
    cmd_scope_release "$@"
    exit $?
    ;;
  commit-acquire)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 commit-acquire <session_id> [stale_sec]" >&2
      exit 2
    fi
    cmd_commit_acquire "$@"
    exit $?
    ;;
  commit-release)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 commit-release <token>" >&2
      exit 2
    fi
    cmd_commit_release "$@"
    exit $?
    ;;
  *)
    echo "Usage: $0 {acquire|heartbeat|release|check|init-marker|scope-acquire|scope-release|commit-acquire|commit-release} ..." >&2
    exit 2
    ;;
esac
