#!/usr/bin/env bash
#
# lake-build-guard.sh - Serialize concurrent `lake build` invocations against one Lean package,
# let a waiting session consume an already-completed build's result instead of launching a
# redundant one, and optionally bound the build in a systemd user scope so a runaway elaboration
# cannot drive the machine into swap.
#
# WHAT THIS GUARDS: N agent sessions (or shells) invoking `lake build` concurrently against the
# SAME Lean package. Without serialization each session launches its own full Lake build,
# multiplying elaboration cost and, in the worst case, driving the machine into swap when several
# heavyweight `lean` processes run at once.
#
# WHAT THIS DELIBERATELY DOES NOT DO (non-goals, recorded so a future reader does not treat them
# as omissions):
#   - It does not wire itself into any call site. lean-sorry-census.sh, skill-lake-repair, or any
#     other consumer must opt in explicitly by invoking `lake-build-guard.sh build ...` -- that
#     wiring is separate, dependent work.
#   - It does not touch LEAN_NUM_THREADS (see "Recorded dead ends" below).
#   - It does not coordinate across machines, run as a daemon, or persist any state beyond the
#     lock/result/log/capture files under the resolved project's own .lake/ directory.
#
# FAMILY CONVENTIONS (for a future latex-build-guard.sh or similar sibling): this script sets,
# but does not itself instantiate, a shared shape for a family of build guards --
#   - subcommand shape: `status` (detect only) / `preflight` (resource check only) / `build`
#     (the guarded wrapper) -- three separable modes so a caller can adopt detection before
#     committing to the wrapper.
#   - exit-code shape: `build` mode passes the wrapped command's own exit code through untouched
#     in the normal case; guard-specific failures live in a small reserved band (75-79 here).
#   - silent-when-no-conflict: the guard emits zero bytes of its own output on the clean/
#     no-conflict path in every mode, so it composes safely inside a `$(... 2>&1)` call site.
#   - degrade audibly, never silently: a missing optional dependency (flock, systemd-run, PSI)
#     produces a visible stderr notice and a fallback behavior, never a crash and never silence.
#
# RECORDED DEAD ENDS (do not re-attempt these as a "quick fix" for build concurrency):
#   - Lake 5.0.0 exposes no `-j`/`--jobs` flag (confirmed against a live `lake build --help`).
#   - `lean`'s own `-j, --threads` flag is not forwarded by Lake; Lake exposes no lean-level
#     thread override at all.
#   - LEAN_NUM_THREADS was experimentally FALSIFIED as a build-concurrency lever, not merely
#     unverified: a controlled A/B against a real Lean project held the module graph constant
#     and varied only this variable; the maximum concurrent descendant `lean` process count was
#     1 in BOTH arms. The variable sizes a single `lean` process's OWN internal elaboration
#     thread pool, not Lake's job scheduler. This script MUST NOT read, set, export, or document
#     LEAN_NUM_THREADS as a concurrency lever -- every other appearance of the string in this
#     file is documentation of that fact, never an assignment.
#
# USAGE:
#   lake-build-guard.sh status    [--dir DIR] [--verbose]
#   lake-build-guard.sh preflight [--dir DIR] [--memory-high VAL] [--memory-max VAL] [--verbose]
#   lake-build-guard.sh build     [--dir DIR] [--timeout SECS] [--memory-bound]
#                                 [--memory-high VAL] [--memory-max VAL] [--defer-on-pressure]
#                                 [--no-share] [--verbose] [--] [LAKE ARGS...]
#   lake-build-guard.sh --help
#
# EXIT CODES:
#   build mode:     0 and any code the underlying `lake` returns are passed through untouched.
#                   Guard-specific failures use the reserved band 75-79:
#                     75  lock-wait timeout (no build launched, no result shared)
#                     76  deferred on memory pressure with --defer-on-pressure (build not launched)
#                     77  usage error (bad flags/subcommand)
#                     78  no Lean project found (no lakefile.lean/lakefile.toml above --dir)
#                     79  a required capability was missing (e.g. no `lake` on PATH)
#                   NOTE (reserved-band collision, documented honestly): `lake` itself could in
#                   principle also exit in the 75-79 range. A caller that needs to distinguish
#                   "the guard refused" from "lake itself returned 75-79" should call
#                   `status`/`preflight` separately rather than relying on the numeric code alone.
#   status mode:    0   no in-flight guarded build (no output)
#                   10  an in-flight guarded build was detected (one-line report on stdout)
#   preflight mode: 0   no memory pressure detected (no output)
#                   11  memory pressure detected (report on stderr)
#
# STALENESS POLICY (result sharing -- see compute_fingerprint()/decide_sharing() below for the
# implementation; this is the authoritative statement of the policy itself):
#   A waiting session that acquires the lock after a build completed may REPLAY that build's
#   result (stdout, stderr, exit status) instead of running its own, but only when ALL of the
#   following hold -- failing ANY one falls through to running a real build, which is always
#   safe:
#     1. state == complete.  An `in_flight` record with no matching `complete` state means its
#        holder died before finishing -- an ABANDONED LOCK. `flock` releases automatically on
#        process exit, so the lock itself becomes acquirable with no PID bookkeeping required;
#        the tell is the record's own unterminated state, and such a record is NEVER shared.
#     2. The record's POST-build fingerprint equals the WAITER's CURRENT fingerprint -- i.e. the
#        tree has not moved since that build finished. This is the "result predates the waiter's
#        own edits" guard.
#     3. The record is younger than a configurable max age (default 900s / 15 minutes).
#     4. --no-share was not passed.
#   Fingerprint asymmetry is deliberate and conservative in only one direction: the check must
#   NEVER report "unchanged" when content actually changed (a real content write always moves
#   mtime, so default `stat` mode never misses a real change except the narrow edge noted below);
#   it MAY spuriously report "changed" after a bare `touch` (which Lake's own staleness tracking
#   ignores, since Lake hashes content, not mtime) -- that costs only a fallback to a real
#   `lake build`, which Lake then no-ops on its own. The residual edge in default `stat` mode is
#   a restore that reproduces an identical size AND mtime; a caller that cannot accept that edge
#   should set LAKE_BUILD_GUARD_FINGERPRINT=hash to hash file contents instead of stat metadata.
#
# TEST SEAMS (overridable via environment, `:-`-defaulted, following claude-refresh.sh's
# `_pid_is_alive` precedent -- production behavior is unchanged unless a variable is exported):
#   LAKE_BUILD_GUARD_LAKE_BIN     - the `lake` binary to invoke. Default: resolved via PATH.
#                                   MUST be resolved via PATH (never a hardcoded absolute path)
#                                   so a test suite can substitute a fake `lake`.
#   LAKE_BUILD_GUARD_PSI_PATH     - path to the PSI memory-pressure file.
#                                   Default: /proc/pressure/memory
#   LAKE_BUILD_GUARD_MEMINFO_PATH - path to the meminfo file. Default: /proc/meminfo
#   LAKE_BUILD_GUARD_FINGERPRINT  - fingerprint mode, "stat" (default) or "hash".
#   LAKE_BUILD_GUARD_MEMORY_BOUND - "1" is equivalent to passing --memory-bound.
#
set -euo pipefail

# --- Test seams (see header) ---
LAKE_BUILD_GUARD_LAKE_BIN="${LAKE_BUILD_GUARD_LAKE_BIN:-}"
LAKE_BUILD_GUARD_PSI_PATH="${LAKE_BUILD_GUARD_PSI_PATH:-/proc/pressure/memory}"
LAKE_BUILD_GUARD_MEMINFO_PATH="${LAKE_BUILD_GUARD_MEMINFO_PATH:-/proc/meminfo}"
LAKE_BUILD_GUARD_FINGERPRINT="${LAKE_BUILD_GUARD_FINGERPRINT:-stat}"
LAKE_BUILD_GUARD_MEMORY_BOUND="${LAKE_BUILD_GUARD_MEMORY_BOUND:-0}"

# --- Internal defaults (never hardcoded byte/GB constants -- ratios and percentages only) ---
DEFAULT_LOCK_TIMEOUT=600      # seconds a waiter blocks before giving up (exit 75)
DEFAULT_SHARE_MAX_AGE=900     # seconds a completed result stays eligible for sharing
DEFAULT_MEMORY_HIGH="60%"     # systemd MemoryHigh=, a fraction of MemTotal, never a byte literal
DEFAULT_MEMORY_MAX="80%"      # systemd MemoryMax=, a fraction of MemTotal, never a byte literal
PSI_SOME_AVG10_THRESHOLD="10.0"
PSI_FULL_AVG10_THRESHOLD="5.0"
MEM_AVAILABLE_RATIO_THRESHOLD=10   # percent of MemTotal; below this is "pressure"
SWAP_USED_RATIO_THRESHOLD=50       # percent of SwapTotal in use; above this is "pressure"

print_help() {
  cat <<'EOF'
lake-build-guard.sh - serialize concurrent `lake build` invocations, share results with waiters,
and optionally bound builds in a systemd user memory scope.

Usage:
  lake-build-guard.sh status    [--dir DIR] [--verbose]
  lake-build-guard.sh preflight [--dir DIR] [--memory-high VAL] [--memory-max VAL] [--verbose]
  lake-build-guard.sh build     [--dir DIR] [--timeout SECS] [--memory-bound]
                                [--memory-high VAL] [--memory-max VAL] [--defer-on-pressure]
                                [--no-share] [--verbose] [--] [LAKE ARGS...]
  lake-build-guard.sh --help

Global options:
  --dir DIR, -d DIR      Directory to resolve the Lean project from (default: $PWD).
  --timeout SECS         (build only) Seconds to wait for the lock before giving up. Default 600.
  --memory-bound         (build only) Wrap the build in `systemd-run --user --scope` with a
                          memory ceiling. Equivalent to LAKE_BUILD_GUARD_MEMORY_BOUND=1.
  --memory-high VAL      MemoryHigh= value passed to systemd-run (default 60%).
  --memory-max VAL       MemoryMax= value passed to systemd-run (default 80%).
  --defer-on-pressure    (build only) Exit 76 without launching if memory pressure is detected,
                          instead of the default warn-and-proceed behavior.
  --no-share             (build only) Never replay a prior result; always run a real build.
  --verbose              Emit diagnostic detail on stderr.
  --help, -h             Show this message.

Exit codes:
  build mode:     0 / lake's own code on success; 75 lock-wait timeout; 76 deferred on pressure;
                   77 usage error; 78 no Lean project found; 79 required capability missing.
  status mode:    0 no in-flight build (no output); 10 in-flight build detected (report on stdout).
  preflight mode: 0 no pressure (no output); 11 pressure detected (report on stderr).

See the header comment in this file for the full staleness policy, dead-end record, and test-seam
documentation.
EOF
}

# --- Project-root / path resolution -----------------------------------------------------------

# Walk up from $1 (a directory) looking for the NEAREST lakefile.lean or lakefile.toml. MUST NOT
# use `git rev-parse --show-toplevel` -- a Lean package is frequently a subdirectory of a larger
# repo (confirmed multi-package-per-repo layouts exist), and a git-root lock would
# over-serialize unrelated sibling packages.
resolve_project_root() {
  local dir="$1"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 1
  while :; do
    if [ -f "$dir/lakefile.lean" ] || [ -f "$dir/lakefile.toml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [ "$dir" = "/" ]; then
      return 1
    fi
    dir="$(dirname "$dir")"
  done
}

# Resolve the `lake` binary via PATH only (never an absolute hardcoded path), so a test suite can
# substitute a fake `lake` on PATH ahead of the real one.
resolve_lake_bin() {
  if [ -n "$LAKE_BUILD_GUARD_LAKE_BIN" ]; then
    printf '%s\n' "$LAKE_BUILD_GUARD_LAKE_BIN"
    return 0
  fi
  command -v lake 2>/dev/null
}

# Derive and create the guard's paths under <root>/.lake/. No absolute path outside <root> is
# ever hardcoded here.
init_guard_paths() {
  local root="$1"
  GUARD_LAKE_DIR="$root/.lake"
  LOCK_PATH="$GUARD_LAKE_DIR/build-guard.lock"
  RESULT_PATH="$GUARD_LAKE_DIR/build-guard.result"
  LOG_PATH="$GUARD_LAKE_DIR/build-guard.log"
  STDOUT_CAPTURE_PATH="$GUARD_LAKE_DIR/build-guard.stdout"
  STDERR_CAPTURE_PATH="$GUARD_LAKE_DIR/build-guard.stderr"
  mkdir -p "$GUARD_LAKE_DIR"
}

# --- flock availability (probed once at startup; degrade audibly, never silently) --------------

have_flock() {
  command -v flock >/dev/null 2>&1
}

# --- Fingerprinting -----------------------------------------------------------------------------

# List the files that participate in the tree fingerprint: every *.lean source under the
# project root (excluding .lake/), plus the package manifest files. .lake/ is excluded because
# it holds build OUTPUT, not source.
collect_fingerprint_files() {
  local root="$1"
  find "$root" -type f -name '*.lean' -not -path "$root/.lake/*" 2>/dev/null
  local f
  for f in lakefile.lean lakefile.toml lake-manifest.json lean-toolchain; do
    if [ -f "$root/$f" ]; then
      printf '%s\n' "$root/$f"
    fi
  done
}

# Compute a fingerprint of the project tree. Two modes:
#   stat (default): hashes a sorted `path size mtime` triple list -- cheap, and never misses a
#     real content change (a content write always moves mtime), though a restore that reproduces
#     an identical size AND mtime is a known, documented edge (see the staleness policy above).
#   hash (opt-in via LAKE_BUILD_GUARD_FINGERPRINT=hash): hashes file contents directly, closing
#     that edge at the cost of reading every file.
# Run in a subshell with pipefail disabled locally so a transient `find`/`stat` warning (e.g. a
# permission-denied subdirectory) cannot abort the whole script under the outer set -eo pipefail.
compute_fingerprint() {
  local root="$1"
  local mode="${LAKE_BUILD_GUARD_FINGERPRINT:-stat}"
  (
    set +o pipefail
    collect_fingerprint_files "$root" | sort | while IFS= read -r f; do
      [ -f "$f" ] || continue
      if [ "$mode" = "hash" ]; then
        sha256sum "$f" 2>/dev/null
      else
        stat -c '%n %s %Y' "$f" 2>/dev/null
      fi
    done | sha256sum | awk '{print $1}'
  )
}

# --- Result record I/O ---------------------------------------------------------------------------
# Flat key=value record, one key per line. Read via grep (never sourced), so record content is
# never executed as shell.

get_record_field() {
  local field="$1" file="$2"
  [ -f "$file" ] || return 1
  grep "^${field}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2-
}

write_inflight_record() {
  local pre_fp="$1"
  {
    echo "state=in_flight"
    echo "holder_pid=$$"
    echo "start_epoch=$(date +%s)"
    echo "end_epoch="
    echo "pre_fingerprint=$pre_fp"
    echo "post_fingerprint="
    echo "lake_bin=$LAKE_BIN"
    echo "exit_status="
    echo "log_path=$LOG_PATH"
  } > "$RESULT_PATH"
}

finalize_record() {
  local exit_status="$1" post_fp="$2"
  local start_epoch pre_fp
  start_epoch="$(get_record_field start_epoch "$RESULT_PATH" || true)"
  pre_fp="$(get_record_field pre_fingerprint "$RESULT_PATH" || true)"
  {
    echo "state=complete"
    echo "holder_pid=$$"
    echo "start_epoch=$start_epoch"
    echo "end_epoch=$(date +%s)"
    echo "pre_fingerprint=$pre_fp"
    echo "post_fingerprint=$post_fp"
    echo "lake_bin=$LAKE_BIN"
    echo "exit_status=$exit_status"
    echo "log_path=$LOG_PATH"
  } > "$RESULT_PATH"
}

# --- Sharing decision (waiter path) --------------------------------------------------------------
# Every one of the four conditions in the header's staleness policy must pass, or this falls
# through to a real build -- see the header comment for the full rationale.
decide_sharing() {
  local waiter_fp="$1"
  local max_age="${LAKE_BUILD_GUARD_SHARE_MAX_AGE:-$DEFAULT_SHARE_MAX_AGE}"

  [ -f "$RESULT_PATH" ] || return 1

  local state
  state="$(get_record_field state "$RESULT_PATH" || true)"
  [ "$state" = "complete" ] || return 1

  local post_fp
  post_fp="$(get_record_field post_fingerprint "$RESULT_PATH" || true)"
  [ -n "$post_fp" ] && [ "$post_fp" = "$waiter_fp" ] || return 1

  local end_epoch
  end_epoch="$(get_record_field end_epoch "$RESULT_PATH" || true)"
  [ -n "$end_epoch" ] || return 1

  local now age
  now="$(date +%s)"
  age=$(( now - end_epoch ))
  [ "$age" -ge 0 ] && [ "$age" -lt "$max_age" ] || return 1

  return 0
}

# Replay a shared result's captured stdout/stderr bytes verbatim -- no guard-emitted bytes are
# added on this path either.
replay_shared_result() {
  cat "$STDOUT_CAPTURE_PATH" 2>/dev/null || true
  cat "$STDERR_CAPTURE_PATH" 1>&2 2>/dev/null || true
}

# --- systemd-run / cgroup bounding (opt-in) -------------------------------------------------------

# Presence of the binary does not imply the user session has cgroup delegation, so probe with one
# cheap real invocation in addition to `command -v`.
have_systemd_run() {
  command -v systemd-run >/dev/null 2>&1 || return 1
  systemd-run --user --scope --quiet --collect -- true >/dev/null 2>&1
}

# --- Memory pressure (PSI + swap-in-use; never bare MemAvailable alone) --------------------------
# Bare availability is insufficient: a machine can report ample-looking MemAvailable while tens
# of gigabytes of swap are in use and the machine is thrash-bound rather than crash-bound -- that
# failure presents as "everything is slow", not as an OOM, which is why it goes undiagnosed by a
# MemAvailable-only check.
PRESSURE_REASONS=()

check_memory_pressure() {
  PRESSURE_REASONS=()

  if [ -r "$LAKE_BUILD_GUARD_PSI_PATH" ]; then
    local some_line full_line some_avg10 full_avg10
    some_line="$(grep '^some' "$LAKE_BUILD_GUARD_PSI_PATH" 2>/dev/null || true)"
    if [ -n "$some_line" ]; then
      some_avg10="$(printf '%s\n' "$some_line" | grep -oE 'avg10=[0-9.]+' | cut -d= -f2)"
      if [ -n "$some_avg10" ] && awk -v v="$some_avg10" -v t="$PSI_SOME_AVG10_THRESHOLD" 'BEGIN{exit !(v+0>t+0)}'; then
        PRESSURE_REASONS+=("PSI 'some' avg10=${some_avg10} exceeds threshold ${PSI_SOME_AVG10_THRESHOLD}")
      fi
    fi
    full_line="$(grep '^full' "$LAKE_BUILD_GUARD_PSI_PATH" 2>/dev/null || true)"
    if [ -n "$full_line" ]; then
      full_avg10="$(printf '%s\n' "$full_line" | grep -oE 'avg10=[0-9.]+' | cut -d= -f2)"
      if [ -n "$full_avg10" ] && awk -v v="$full_avg10" -v t="$PSI_FULL_AVG10_THRESHOLD" 'BEGIN{exit !(v+0>t+0)}'; then
        PRESSURE_REASONS+=("PSI 'full' avg10=${full_avg10} exceeds threshold ${PSI_FULL_AVG10_THRESHOLD}")
      fi
    fi
  else
    if [ "${VERBOSE:-false}" = "true" ]; then
      echo "lake-build-guard: --verbose: PSI path unavailable ($LAKE_BUILD_GUARD_PSI_PATH); falling back to the meminfo-only signal" >&2
    fi
  fi

  if [ -r "$LAKE_BUILD_GUARD_MEMINFO_PATH" ]; then
    local mem_total mem_avail swap_total swap_free
    mem_total="$(awk '/^MemTotal:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"
    mem_avail="$(awk '/^MemAvailable:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"
    swap_total="$(awk '/^SwapTotal:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"
    swap_free="$(awk '/^SwapFree:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"

    if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ] 2>/dev/null; then
      local avail_ratio=$(( mem_avail * 100 / mem_total ))
      if [ "$avail_ratio" -lt "$MEM_AVAILABLE_RATIO_THRESHOLD" ]; then
        PRESSURE_REASONS+=("MemAvailable/MemTotal = ${avail_ratio}% is below threshold ${MEM_AVAILABLE_RATIO_THRESHOLD}%")
      fi
    fi
    if [ -n "$swap_total" ] && [ "$swap_total" -gt 0 ] 2>/dev/null && [ -n "$swap_free" ]; then
      local swap_used_ratio=$(( (swap_total - swap_free) * 100 / swap_total ))
      if [ "$swap_used_ratio" -gt "$SWAP_USED_RATIO_THRESHOLD" ]; then
        PRESSURE_REASONS+=("swap-in-use = ${swap_used_ratio}% of SwapTotal exceeds threshold ${SWAP_USED_RATIO_THRESHOLD}%")
      fi
    fi
  fi

  [ "${#PRESSURE_REASONS[@]}" -gt 0 ]
}

# --- status mode: lock-holder-state detection, never a naive process match ----------------------
# Primary check is race-free: attempt a non-blocking flock on the lock file. Lock free -> no
# guarded build in flight. Lock held -> exit 10 with a one-line report. This is deliberately
# NEVER driven by `pgrep lean` or `pgrep -f 'lake build'`: during research, four long-lived
# `lean --worker`/`lean --server` LSP processes were observed live in the same project directory,
# and a naive argv/comm match would have reported a build that did not exist. Because detection
# here is anchored purely on lock-holder state (not on scanning ambient processes at all), a
# caller's own argv mentioning "lake build", or an ambient `lean`-comm LSP worker, can never
# cause a false positive -- there is no process table scan on this path at all.

cmd_status() {
  if ! have_flock; then
    echo "lake-build-guard: flock not found on PATH; cannot determine lock state" >&2
    exit 0
  fi

  local fd
  exec {fd}<>"$LOCK_PATH"

  if flock -n "$fd"; then
    exit 0
  fi

  local holder_pid
  holder_pid="$(get_record_field holder_pid "$RESULT_PATH" 2>/dev/null || true)"
  echo "lake-build-guard: in-flight guarded build detected (holder pid ${holder_pid:-unknown})"

  if [ "${VERBOSE:-false}" = "true" ]; then
    report_verbose_descendants "${holder_pid:-}"
  fi

  exit 10
}

# --- Supplementary --verbose diagnostics: descendants of the recorded holder PID only -----------
# Single atomic `ps` snapshot per invocation (the claude-refresh.sh discipline) -- every decision
# below reads that one snapshot; no candidate PID is ever re-queried. Matches on `comm`
# (executable identity), never on an argv substring. Refuses loudly (exit 79) rather than
# falling back to an unsafe argv match if this platform's `ps` cannot produce the required
# columns.

take_ps_snapshot() {
  local out
  if ! out=$(ps -eo pid,ppid,comm,args --no-headers 2>&1); then
    echo "ERROR: 'ps -eo pid,ppid,comm,args' failed:" >&2
    echo "$out" >&2
    exit 79
  fi
  printf '%s\n' "$out"
}

# Zero-query self-exclusion: pid or ppid equal to this script's own $$/$PPID (both known at parse
# time) is excluded before any further predicate runs.
is_self_row() {
  local pid="$1" ppid="$2"
  [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]
}

# True when candidate pid is holder_pid itself or a descendant of it, walking the ppid chain
# through the already-captured snapshot (no re-query).
is_descendant_of_holder() {
  local snapshot="$1" holder_pid="$2" candidate_pid="$3"
  local pid="$candidate_pid" hops=0
  while [ -n "$pid" ] && [ "$pid" != "1" ] && [ "$hops" -lt 50 ]; do
    if [ "$pid" = "$holder_pid" ]; then
      return 0
    fi
    pid="$(printf '%s\n' "$snapshot" | awk -v p="$pid" '$1==p{print $2; exit}')"
    hops=$((hops + 1))
  done
  return 1
}

report_verbose_descendants() {
  local holder_pid="$1"
  if [ -z "$holder_pid" ]; then
    echo "lake-build-guard: --verbose: no holder pid recorded in $RESULT_PATH" >&2
    return
  fi
  local snapshot
  snapshot="$(take_ps_snapshot)"
  echo "lake-build-guard: --verbose: process descendants of holder pid $holder_pid:" >&2
  local pid ppid comm args
  while read -r pid ppid comm args; do
    [ -z "$pid" ] && continue
    if is_self_row "$pid" "$ppid"; then
      continue
    fi
    if [ "$pid" = "$holder_pid" ] || is_descendant_of_holder "$snapshot" "$holder_pid" "$pid"; then
      printf '  pid=%s ppid=%s comm=%s\n' "$pid" "$ppid" "$comm" >&2
    fi
  done <<< "$snapshot"
}

# --- preflight mode -------------------------------------------------------------------------------

cmd_preflight() {
  if check_memory_pressure; then
    echo "lake-build-guard: memory pressure detected:" >&2
    local r
    for r in "${PRESSURE_REASONS[@]}"; do
      printf '  - %s\n' "$r" >&2
    done
    exit 11
  fi
  exit 0
}

# --- build mode ------------------------------------------------------------------------------------

# Run `"$LAKE_BIN" "$@"` (optionally wrapped in a systemd-run memory scope) in the FOREGROUND,
# tee-ing stdout and stderr each to their own capture file (for later replay) while still writing
# stdout to stdout and stderr to stderr unchanged -- no `&` anywhere on this invocation, no
# consumption of the caller's stdin. `--quiet --collect` on systemd-run is MANDATORY, not
# cosmetic: without it, systemd-run's own status chatter on stderr corrupts every
# `BUILD_OUTPUT="$(lake build 2>&1)"` call site this guard is meant to be droppable into.
run_lake_foreground() {
  local -a cmd
  if [ "${MEMORY_BOUND:-false}" = "true" ]; then
    if have_systemd_run; then
      cmd=(systemd-run --user --scope --quiet --collect \
        -p "MemoryHigh=${MEMORY_HIGH}" -p "MemoryMax=${MEMORY_MAX}" -- "$LAKE_BIN" "$@")
    else
      echo "lake-build-guard: systemd-run unavailable or lacks user-scope cgroup delegation; running build unbounded" >&2
      cmd=("$LAKE_BIN" "$@")
    fi
  else
    cmd=("$LAKE_BIN" "$@")
  fi

  : > "$STDOUT_CAPTURE_PATH"
  : > "$STDERR_CAPTURE_PATH"

  set +e
  "${cmd[@]}" \
    > >(tee "$STDOUT_CAPTURE_PATH") \
    2> >(tee "$STDERR_CAPTURE_PATH" >&2)
  local rc=$?
  wait
  set -e

  {
    echo "=== stdout ==="
    cat "$STDOUT_CAPTURE_PATH" 2>/dev/null || true
    echo "=== stderr ==="
    cat "$STDERR_CAPTURE_PATH" 2>/dev/null || true
  } > "$LOG_PATH"

  return "$rc"
}

run_as_holder() {
  local pre_fp
  pre_fp="$(compute_fingerprint "$ROOT")"
  write_inflight_record "$pre_fp"

  set +e
  run_lake_foreground "$@"
  local rc=$?
  set -e

  local post_fp
  post_fp="$(compute_fingerprint "$ROOT")"
  finalize_record "$rc" "$post_fp"
  return "$rc"
}

cmd_build() {
  local timeout="$1"
  shift
  local -a args=("$@")

  # Preflight: default is warn-and-proceed; --defer-on-pressure exits 76 without launching.
  if check_memory_pressure; then
    if [ "${DEFER_ON_PRESSURE:-false}" = "true" ]; then
      echo "lake-build-guard: deferring build due to memory pressure (--defer-on-pressure):" >&2
      local r
      for r in "${PRESSURE_REASONS[@]}"; do
        printf '  - %s\n' "$r" >&2
      done
      exit 76
    else
      echo "lake-build-guard: memory pressure detected; proceeding anyway (pass --defer-on-pressure to defer instead)" >&2
    fi
  fi

  LAKE_BIN="$(resolve_lake_bin)"
  if [ -z "$LAKE_BIN" ]; then
    echo "lake-build-guard: 'lake' not found on PATH (and LAKE_BUILD_GUARD_LAKE_BIN not set)" >&2
    exit 79
  fi

  if ! have_flock; then
    echo "lake-build-guard: flock not found on PATH; running unserialized" >&2
    set +e
    run_lake_foreground "${args[@]}"
    local rc=$?
    set -e
    exit "$rc"
  fi

  local lock_fd
  exec {lock_fd}<>"$LOCK_PATH"

  if flock -n "$lock_fd"; then
    set +e
    run_as_holder "${args[@]}"
    local rc=$?
    set -e
    exit "$rc"
  fi

  # Waiter path: compute our own fingerprint BEFORE blocking, so it reflects the tree state at
  # the moment we asked to build (not whatever it drifts to while we wait).
  local waiter_fp
  waiter_fp="$(compute_fingerprint "$ROOT")"

  if ! flock -w "$timeout" "$lock_fd"; then
    echo "lake-build-guard: timed out after ${timeout}s waiting for the build lock" >&2
    exit 75
  fi

  if [ "${NO_SHARE:-false}" != "true" ] && decide_sharing "$waiter_fp"; then
    replay_shared_result
    local shared_rc
    shared_rc="$(get_record_field exit_status "$RESULT_PATH" 2>/dev/null || true)"
    exit "${shared_rc:-1}"
  fi

  set +e
  run_as_holder "${args[@]}"
  local rc=$?
  set -e
  exit "$rc"
}

# --- Argument parsing / dispatch --------------------------------------------------------------------

main() {
  if [ $# -eq 0 ]; then
    print_help
    exit 77
  fi

  local mode=""
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    status|preflight|build)
      mode="$1"
      shift
      ;;
    *)
      echo "lake-build-guard: unknown subcommand: $1" >&2
      print_help >&2
      exit 77
      ;;
  esac

  local dir="$PWD"
  local timeout="$DEFAULT_LOCK_TIMEOUT"
  MEMORY_BOUND=false
  if [ "$LAKE_BUILD_GUARD_MEMORY_BOUND" = "1" ]; then
    MEMORY_BOUND=true
  fi
  MEMORY_HIGH="$DEFAULT_MEMORY_HIGH"
  MEMORY_MAX="$DEFAULT_MEMORY_MAX"
  DEFER_ON_PRESSURE=false
  NO_SHARE=false
  VERBOSE=false
  local -a lake_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --dir|-d)
        dir="$2"; shift 2 ;;
      --timeout)
        timeout="$2"; shift 2 ;;
      --memory-bound)
        MEMORY_BOUND=true; shift ;;
      --memory-high)
        MEMORY_HIGH="$2"; shift 2 ;;
      --memory-max)
        MEMORY_MAX="$2"; shift 2 ;;
      --defer-on-pressure)
        DEFER_ON_PRESSURE=true; shift ;;
      --no-share)
        NO_SHARE=true; shift ;;
      --verbose)
        VERBOSE=true; shift ;;
      --help|-h)
        print_help
        exit 0
        ;;
      --)
        shift
        lake_args+=("$@")
        break
        ;;
      --*)
        echo "lake-build-guard: unknown option: $1" >&2
        exit 77
        ;;
      *)
        lake_args+=("$1")
        shift
        ;;
    esac
  done

  if ! ROOT="$(resolve_project_root "$dir")"; then
    echo "lake-build-guard: no lakefile.lean or lakefile.toml found above '$dir'" >&2
    exit 78
  fi
  init_guard_paths "$ROOT"

  if [ "$VERBOSE" = "true" ]; then
    echo "lake-build-guard: --verbose: resolved project root: $ROOT" >&2
    echo "lake-build-guard: --verbose: lock path: $LOCK_PATH" >&2
  fi

  case "$mode" in
    status)
      cmd_status
      ;;
    preflight)
      cmd_preflight
      ;;
    build)
      cmd_build "$timeout" "${lake_args[@]}"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
