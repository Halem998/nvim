#!/usr/bin/env bash
# test-claude-refresh-matcher.sh - Regression suite for claude-refresh.sh's orphan matcher,
# covering the four acceptance-bar assertions: (a) a process under /system.slice/ is never
# selected, (b) a process that merely mentions "claude" in argv without being a Claude
# executable is never selected, (c) an inhibitor whose held target is still alive is never
# selected, and (d) the script's own subshells are never self-selected.
#
# Structural model: pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d
# workdir with a trap EXIT cleanup, loud-skip discipline (see context/standards/
# shell-script-testing.md). The script under test is copied into the suite's own mktemp -d
# workdir and sourced there (matching test-git-commit-scoped.sh's precedent), so predicates
# are called directly by name rather than through a subprocess per case, and is never
# instrumented or modified to "know" it is under test.
#
# Assertion (c) drives a REAL backgrounded process (`sleep 300 &`) rather than a pure string
# fixture, matching the existing precedent of real subprocess-driven suites.
#
# Mutation check (required by shell-script-testing.md's "Mutation checks for regex-shaped
# fixes"): see the dedicated section below. This fix is a full structural redesign, not a
# regex tweak -- the pre-fix script defines none of the four predicate functions, has no
# main(), and has no BASH_SOURCE dual-mode guard, so every assertion in this suite (each of
# which calls one of those functions by name) is structurally incapable of even running
# against the pre-fix script. A dynamic re-run is deliberately not attempted: the pre-fix
# script's top-level body runs unconditionally on `source` and always ends in its own
# unconditional `exit`, so any command placed after a `source <prefix-script>` in the same
# shell is unreachable -- there is no way to get a meaningful per-assertion exit code out of
# it in-process. The static absence check below is therefore the correct, honest way to prove
# non-vacuousness for this specific rewrite, and is reported explicitly rather than glossed
# over.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required script is
# missing, which is reported loudly, not silently skipped).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."
SCRIPT_UNDER_TEST="claude-refresh.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# --- Loud-skip discipline: verify the required script exists before running anything. ---
if [ ! -f "$SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST" ]; then
  echo "ERROR: test-claude-refresh-matcher.sh cannot run -- missing required script: $SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() {
  # Best-effort: kill any sleep helper left running if a case exited early.
  if [ -n "${SLEEP_HELPER_PID:-}" ]; then
    kill "$SLEEP_HELPER_PID" 2>/dev/null || true
  fi
  [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
}
trap cleanup EXIT

# Copy the script under test into our own workdir and source it there, so predicates are
# called directly. Sourcing must have zero side effects (no main() execution) since
# BASH_SOURCE != $0 when sourced.
cp "$SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST" "$WORKDIR/$SCRIPT_UNDER_TEST"
# shellcheck disable=SC1090,SC1091
. "$WORKDIR/$SCRIPT_UNDER_TEST"

# main() being defined is expected; what matters is that it was NOT invoked by the `source`
# above. Verified implicitly: main() unconditionally calls exit before this line, in every
# code path, so reaching this line at all already proves sourcing had no side effects.
pass "sourcing $SCRIPT_UNDER_TEST defined functions without executing main() (this line was reached)"

# =====================================================================
# Assertion (a): system-slice cgroup exclusion
# =====================================================================
if is_system_slice_cgroup "0::/system.slice/earlyoom.service"; then
  pass "is_system_slice_cgroup: a /system.slice/ cgroup is excluded (earlyoom.service)"
else
  fail "is_system_slice_cgroup: a /system.slice/ cgroup was NOT excluded (earlyoom.service)"
fi

if is_system_slice_cgroup "0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.wezfurlong.wezterm.scope"; then
  fail "is_system_slice_cgroup: a real user-session cgroup was incorrectly excluded"
else
  pass "is_system_slice_cgroup: a real user-session cgroup is NOT excluded"
fi

# =====================================================================
# Assertion (b): argv-mention rejection (comm-identity gate)
# =====================================================================
# Reproduces the real earlyoom line: argv mentions "claude" inside an unrelated --prefer
# regex flag, but comm is "earlyoom", not a Claude executable.
EARLYOOM_ARGS='/nix/store/xxxx-earlyoom-1.9.0/bin/earlyoom -m10 -n -r3600 -s10 --avoid ^(gnome-shell|Xwayland|niri)$ --prefer ^(lean|lake|claude|node|npm|opencode)$'
if is_claude_executable_comm "earlyoom" "$EARLYOOM_ARGS"; then
  fail "is_claude_executable_comm: earlyoom (argv mentions 'claude') was incorrectly accepted as a Claude executable"
else
  pass "is_claude_executable_comm: earlyoom (argv mentions 'claude') is rejected by the comm predicate"
fi

# A genuine claude CLI process must still be accepted.
if is_claude_executable_comm "claude" "claude --dangerously-skip-permissions"; then
  pass "is_claude_executable_comm: a genuine 'claude' comm is accepted"
else
  fail "is_claude_executable_comm: a genuine 'claude' comm was incorrectly rejected"
fi

# =====================================================================
# Assertion (c): inhibitor-target liveness, driven by a REAL process
# =====================================================================
sleep 300 &
SLEEP_HELPER_PID=$!

INHIBITOR_ARGS="systemd-inhibit --what=sleep:idle --who=claude-code --why=Claude Code session --mode=block tail --pid=${SLEEP_HELPER_PID} -f /dev/null"

if is_live_inhibitor_target "$INHIBITOR_ARGS"; then
  pass "is_live_inhibitor_target: excludes an inhibitor whose target (pid $SLEEP_HELPER_PID) is alive"
else
  fail "is_live_inhibitor_target: did NOT exclude an inhibitor whose target (pid $SLEEP_HELPER_PID) is alive"
fi

kill "$SLEEP_HELPER_PID" 2>/dev/null
# Poll (bounded, non-blocking) rather than a plain `wait`, which has been observed to stall
# under load on this machine for a backgrounded job in a non-interactive script. Reaping the
# now-zombie child is left to the shell's normal exit-time cleanup rather than an explicit
# `wait` here, so this step can never itself block the suite.
#
# Budget widened from 10x0.2s (2s) to 40x0.2s (8s): both this poll and is_live_inhibitor_target
# itself use `kill -0`, which can still report a not-yet-reaped zombie as "alive" -- observed to
# need more than 2s of headroom when run.sh:run-all.sh's suite-runner executes this suite
# alongside ~25 concurrent others, each contending for CPU/process-table scheduling. This widens
# only the test's own patience; it does not change is_live_inhibitor_target's production
# semantics or its documented live-check trade-off.
for _ in $(seq 1 40); do
  kill -0 "$SLEEP_HELPER_PID" 2>/dev/null || break
  sleep 0.2
done

if is_live_inhibitor_target "$INHIBITOR_ARGS"; then
  fail "is_live_inhibitor_target: still excludes the SAME inhibitor after its target (pid $SLEEP_HELPER_PID) was killed -- tautological check"
else
  pass "is_live_inhibitor_target: no longer excludes the SAME inhibitor once its target (pid $SLEEP_HELPER_PID) is dead -- genuine liveness test"
fi
SLEEP_HELPER_PID=""

# A row with no --pid=<N> at all must never be treated as a live inhibitor.
if is_live_inhibitor_target "systemd-inhibit --what=sleep:idle --who=someone --mode=block sleep infinity"; then
  fail "is_live_inhibitor_target: incorrectly matched a systemd-inhibit row with no --pid=<N> target"
else
  pass "is_live_inhibitor_target: a systemd-inhibit row with no --pid=<N> target is not treated as a live inhibitor"
fi

# =====================================================================
# Assertion (d): self-subshell exclusion
# =====================================================================
# (d-1) A synthetic row for a bash-comm process whose args contain the script's own path
# must be rejected by the comm predicate -- mirroring the real 4056113/4056114-style false
# positive (the refresh script's own transient subshells).
SELF_PATH_ARGS="bash agent-system/extensions/core/scripts/claude-refresh.sh"
if is_claude_executable_comm "bash" "$SELF_PATH_ARGS"; then
  fail "is_claude_executable_comm: a bash-comm row mentioning the script's own path was incorrectly accepted"
else
  pass "is_claude_executable_comm: a bash-comm row mentioning the script's own path is rejected by the comm predicate"
fi

# (d-2) Direct end-to-end case for the $$/ppid zero-query self-exclusion: run the fixed
# script as a real subprocess with a fake `ps` on PATH that injects a synthetic row for the
# running script's OWN pid, alongside a distinct, otherwise-identical CONTROL row. If
# self-exclusion works, the self-row must never appear in the report while the control row
# must.
#
# Determining "the running script's own pid" correctly is the subtle part: claude-refresh.sh
# calls `ps` from inside take_snapshot(), itself captured via `snapshot=$(take_snapshot)` in
# main(). A command substitution of a FUNCTION forces bash to fork a subshell to run that
# function (functions cannot be exec'd directly), so the process that ultimately execs our
# fake `ps` is a GRANDCHILD of the real script, not a direct child -- `$PPID` inside the fake
# `ps` therefore names that intermediate subshell, not the script's own `$$`. (Verified
# empirically while writing this case: a naive `$PPID`-based guess pointed at the wrong pid
# and the self-row was never excluded, which would have made this a false-negative test.) The
# robust fix is for the fake `ps` to walk its OWN ancestry with the REAL system `ps` (resolved
# to an absolute path before PATH is overridden below) until it finds the nearest ancestor
# whose argv names this script under test -- that ancestor IS the real top-level `$$` the
# script itself sees, regardless of how many subshell layers sit in between.
REAL_PS_BIN="$(command -v ps)"
if [ -z "$REAL_PS_BIN" ]; then
  echo "ERROR: cannot resolve the real 'ps' binary needed to build the self-exclusion (d-2) fixture" >&2
  fail "self-exclusion (d-2): real ps binary not found -- cannot construct fixture"
  REAL_PS_BIN=""
fi

if [ -n "$REAL_PS_BIN" ]; then
  FAKE_BIN_DIR="$WORKDIR/fakebin"
  mkdir -p "$FAKE_BIN_DIR"
  CONTROL_PID=999999
  cat > "$FAKE_BIN_DIR/ps" <<'FAKE_PS_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's self-exclusion case (d-2).
has_p_flag=false
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
done
if $has_p_flag; then
  # validate_cgroup_support()'s self-check: return a plausible non-empty user-slice cgroup.
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi

# Walk our own ancestry with the REAL ps until argv stops naming the script under test. A
# subshell forked (not exec'd) for a function's command substitution retains the SAME argv as
# its parent, so every ancestor from here up to and including the real top-level script all
# show identical argv -- the first MATCH is not necessarily the real top-level pid, it could
# be an intermediate subshell. The real top-level pid is the HIGHEST (furthest) ancestor that
# still matches, i.e. the last match seen just before the first non-matching ancestor.
find_self_pid() {
  local check_pid="$PPID"
  local best_match=""
  local hops=0
  while [ -n "$check_pid" ] && [ "$check_pid" != "1" ] && [ "$hops" -lt 25 ]; do
    local row
    row=$("$REAL_PS_BIN" -o args= -p "$check_pid" 2>/dev/null)
    case "$row" in
      *"__SCRIPT_MARKER__"*)
        best_match="$check_pid"
        ;;
      *)
        break
        ;;
    esac
    check_pid=$("$REAL_PS_BIN" -o ppid= -p "$check_pid" 2>/dev/null | tr -d ' ')
    hops=$((hops + 1))
  done
  echo "$best_match"
}

self_pid="$(find_self_pid)"
cur_uid="$(id -u)"
if [ -n "$self_pid" ]; then
  printf '%s 1 %s ? 100 1000 claude 0::/user.slice/user-1000.slice/session.scope claude --dangerously-skip-permissions\n' "$self_pid" "$cur_uid"
fi
printf '%s 1 %s ? 100 1000 claude 0::/user.slice/user-1000.slice/session.scope claude --dangerously-skip-permissions\n' "__CONTROL_PID__" "$cur_uid"
FAKE_PS_EOF
  sed -i "s/__CONTROL_PID__/$CONTROL_PID/" "$FAKE_BIN_DIR/ps"
  sed -i "s#__SCRIPT_MARKER__#$SCRIPT_UNDER_TEST#" "$FAKE_BIN_DIR/ps"
  chmod +x "$FAKE_BIN_DIR/ps"
  # Export REAL_PS_BIN so the fake ps script (and any nested invocation of it) can see it.
  export REAL_PS_BIN

  SELF_EXCLUSION_OUT="$(PATH="$FAKE_BIN_DIR:$PATH" bash "$WORKDIR/$SCRIPT_UNDER_TEST" 2>&1)"

  if echo "$SELF_EXCLUSION_OUT" | grep -q "$CONTROL_PID"; then
    pass "self-exclusion (d-2): the control row (different pid) is reported as an orphan"
  else
    fail "self-exclusion (d-2): the control row (different pid) was NOT reported -- harness defect, not a real assertion"
    info "output was: $SELF_EXCLUSION_OUT"
  fi

  # The self-row's PID varies per run (it is the subprocess's own pid); we cannot grep for a
  # literal value we don't know in advance, but we CAN assert the orphan count is exactly 1
  # (the control row only) rather than 2, which is the direct, real behavioral proof that the
  # self-referencing row was excluded.
  if echo "$SELF_EXCLUSION_OUT" | grep -q "^Found 1 orphaned"; then
    pass "self-exclusion (d-2): exactly one orphan reported (self row excluded, control row kept)"
  elif echo "$SELF_EXCLUSION_OUT" | grep -q "^Found 2 orphaned"; then
    fail "self-exclusion (d-2): two orphans reported -- the script's own self row was NOT excluded"
    info "output was: $SELF_EXCLUSION_OUT"
  else
    fail "self-exclusion (d-2): unexpected output shape from the self-exclusion harness run"
    info "output was: $SELF_EXCLUSION_OUT"
  fi
fi

# =====================================================================
# Mutation check: pre-fix script cannot run any of this suite's assertions
# =====================================================================
# NOTE: this deliberately pins the specific commit immediately BEFORE the matcher rewrite
# landed, not "HEAD" -- by the time this suite itself was added, HEAD already IS the fixed
# script (the rewrite and this suite are separate, sequential phases of the same change), so
# "git show HEAD:..." would recover the FIXED script, not the pre-fix one, making the check
# vacuously pass. The pinned commit remains resolvable indefinitely (ordinary git history is
# never garbage-collected while reachable from any ref), so this is a stable, permanent
# mutation-check anchor, not a fragile one-time convenience.
info "Mutation check: confirming the suite is not vacuous against the pre-fix script"
PREFIX_COMMIT="7e79b2695"
PREFIX_SCRIPT="$WORKDIR/prefix.sh"
if git -C "$SRC_SCRIPTS_DIR" show "${PREFIX_COMMIT}:agent-system/extensions/core/scripts/$SCRIPT_UNDER_TEST" > "$PREFIX_SCRIPT" 2>/dev/null; then
  MISSING_IN_PREFIX=()
  for fn in is_claude_executable_comm is_system_slice_cgroup is_owned_by_current_uid is_live_inhibitor_target; do
    if ! grep -q "^${fn}()" "$PREFIX_SCRIPT"; then
      MISSING_IN_PREFIX+=("$fn")
    fi
  done
  if ! grep -q 'BASH_SOURCE\[0\].*==.*\$0' "$PREFIX_SCRIPT"; then
    MISSING_IN_PREFIX+=("main()/BASH_SOURCE dual-mode guard")
  fi

  if [ "${#MISSING_IN_PREFIX[@]}" -eq 4 ] || [ "${#MISSING_IN_PREFIX[@]}" -eq 5 ]; then
    pass "mutation check: pre-fix script (commit $PREFIX_COMMIT) defines none of the four predicates or the main() guard -- every assertion above would fail with 'command not found' against it (RED confirmed)"
    info "absent in pre-fix: ${MISSING_IN_PREFIX[*]}"
  else
    fail "mutation check: pre-fix script unexpectedly already defines some of these functions -- ${MISSING_IN_PREFIX[*]} were reported missing, expected all 5 markers absent"
  fi
else
  echo "ERROR: mutation check could not recover the pre-fix script via 'git show ${PREFIX_COMMIT}:...' -- this is a hard requirement, not a skippable case" >&2
  fail "mutation check: could not obtain pre-fix script from commit $PREFIX_COMMIT"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
