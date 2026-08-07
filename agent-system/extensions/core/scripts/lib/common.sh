#!/usr/bin/env bash
# common.sh - Single source of truth for the repo-root-resolution, session-ID, timestamp,
# logging, and test-helper boilerplate previously duplicated across dozens of core scripts.
#
# Sourced (never executed) by scripts at multiple directory depths under
# agent-system/extensions/core/scripts/ (scripts/ itself, scripts/lib/, scripts/tests/,
# scripts/lint/) -- see context/standards/shell-strict-mode.md and the per-file consumer list
# below, updated as each migration phase lands.
#
# CONTRACT (mirrors scripts/lib/manifest-routing-lib.sh's own contract verbatim):
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior. A consumer's own
#     `set -euo pipefail` (or lack thereof) is completely unaffected by sourcing this file.
#   - Every internal variable is prefixed `_common_` and is explicitly unset before each function
#     returns (on top of already being `local`), so sourcing this file never leaks state into the
#     calling shell's environment.
#   - A miss is signalled by empty stdout (or a safe/inert default), never by a non-zero exit
#     status -- every function below always returns 0.
#   - Never calls `exit` -- a faulty resolution at worst leaves the caller with an empty string
#     or a no-op; this library only ever returns 0.
#
# FORBID LOCAL REDEFINITION: a consumer that sources this file MUST NOT define its own copy of
# any function this library provides (common_repo_root, common_session_id,
# common_timestamp_iso/_epoch/_date, common_log_error/_warn/_info, common_test_pass/_fail/_info).
# A local redefinition silently shadows the shared implementation and defeats the single-source
# guarantee this library exists to provide.
#
# SCRIPT_DIR bootstrap stays inline at each consumer -- it is required to locate this file itself
# (`source "${SCRIPT_DIR}/lib/common.sh"`) and is NOT a duplication this library removes. What
# this library replaces is everything that follows that bootstrap line.
#
# NON-GOALS (deliberate, see the task's plan Non-Goals section):
#   - common_log_error/_warn/_info are plain, side-effect-free emitters. They do NOT replace
#     validate-artifact.sh's counter-incrementing log_error, lint-routing-wiring.sh's
#     verbose-gated log_error, or lint-agent-contracts.sh's colorized/counter-incrementing
#     variant -- those are semantically divergent by design and mass-migrating them is out of
#     scope. Only sites whose semantics exactly match the plain trio here may migrate,
#     opportunistically.
#   - common_test_pass/_fail/_info are core-local, matching
#     context/standards/shell-script-testing.md's documented PASSED/FAILED trio exactly. A
#     sibling extension's own `t_pass`/`t_fail` style remains valid there and is not superseded.
#   - common_repo_root does not replace lint-agent-contracts.sh's deliberately different
#     `git rev-parse --show-toplevel` + `REPO_ROOT` env-override strategy.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#   PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"     # scripts/ callers: 2 levels up
#   session_id="$(common_session_id)"
#   ts="$(common_timestamp_iso)"
#   common_log_info "starting up"
#   common_test_pass "case description"                    # increments caller's PASSED

# Consumers (updated as each migration phase lands):
#   Session-ID generation (common_session_id), migrated in Phase 3:
#     scripts/archive-task.sh, scripts/command-gate-in.sh, scripts/manage-topics.sh,
#     scripts/orchestrate-predispatch-review.sh, scripts/reconcile-artifacts.sh,
#     scripts/skill-base.sh (two call sites), scripts/vault-operation.sh.
#   command-gate-in.sh and skill-base.sh set no shell options at all (they are sourced into a
#   caller's shell); sourcing common.sh is confirmed not to change that (see
#   tests/test-common-lib.sh's $-/`set -o` assertions, exercised directly against both files).
#   Root-resolution (common_repo_root), migrated in Phase 4:
#     scripts/archive-task.sh, scripts/errors-append.sh, scripts/events-append.sh,
#     scripts/events-query.sh, scripts/export-to-markdown.sh, scripts/generate-task-order.sh,
#     scripts/generate-todo.sh, scripts/git-commit-scoped.sh, scripts/install-extension.sh,
#     scripts/lint/lint-contract-compliance.sh, scripts/lint/lint-postflight-boundary.sh,
#     scripts/literature-retrieve.sh, scripts/manage-topics.sh, scripts/memory-harvest.sh,
#     scripts/memory-retrieve.sh, scripts/orchestrate-batch-admit.sh,
#     scripts/orchestrate-dry-run-report.sh, scripts/orchestrate-predispatch-review.sh,
#     scripts/orchestrate-triage-classify.sh, scripts/reap-session-runtime-files.sh,
#     scripts/reconcile-artifacts.sh, scripts/reconcile-task-status.sh, scripts/roadmap-sync.sh,
#     scripts/state-write.sh, scripts/task-lock.sh, scripts/uninstall-extension.sh,
#     scripts/update-task-status.sh, scripts/validate-context-budgets.sh,
#     scripts/validate-wiring.sh, scripts/vault-operation.sh, and their test suites
#     (scripts/test-conflict-predicate.sh, scripts/test-four-tier-conflict.sh,
#     scripts/test-session-registry.sh, scripts/test-session-runtime-files.sh,
#     scripts/test-state-write-concurrency.sh, scripts/test-state-write-regen-timing.sh,
#     scripts/test-task-lock-reap.sh, scripts/tests/test-errors-append.sh,
#     scripts/tests/test-git-commit-scoped.sh, scripts/tests/test-orchestrate-triage-classify.sh).
#     Residual (not migrated, explicitly bounded per the phase's Scope Hypothesis): the
#     depth-2/3 cohort not listed above, and lint-agent-contracts.sh's deliberately different
#     `git rev-parse --show-toplevel` + REPO_ROOT-override strategy, left untouched by design.
#   UTC timestamp formatting (common_timestamp_iso / common_timestamp_epoch), migrated
#   opportunistically in Phase 4 within files already touched for root-resolution:
#     scripts/task-lock.sh (iso_now/now_epoch wrappers), scripts/update-task-status.sh (two
#     inline call sites). Parsing sites (BSD `date -u -j -f` / GNU `date -u -d`) are out of the
#     extracted set and left untouched, per the plan's Non-Goals.

# common_repo_root <script_dir> <levels> -- echoes the resolved repo root, walking <levels>
# directories up from <script_dir> and canonicalizing via `cd && pwd`. Serves scripts/ callers
# (levels=2), scripts/lib/, scripts/tests/, and scripts/lint/ callers (levels=3 each). Echoes
# empty string (never a non-zero exit) if <script_dir> is empty or the resolved path does not
# exist.
common_repo_root() {
  local _common_dir="${1:-}"
  local _common_levels="${2:-2}"
  local _common_path _common_i _common_result

  _common_result=""
  if [ -n "$_common_dir" ]; then
    _common_path="$_common_dir"
    _common_i=0
    while [ "$_common_i" -lt "$_common_levels" ]; do
      _common_path="${_common_path}/.."
      _common_i=$((_common_i + 1))
    done
    _common_result="$(cd "$_common_path" 2>/dev/null && pwd)"
  fi

  echo "$_common_result"
  unset _common_dir _common_levels _common_path _common_i _common_result
  return 0
}

# common_session_id -- echoes a new session ID of the form sess_<unix_epoch>_<6hex>. Uses the
# newline-stripping `tr -d ' \n'` form (strictly safer than, and a superset of, the plain
# `tr -d ' '` form used at most existing call sites) -- see plan Phase 3 for the migration that
# closes command-gate-in.sh's live trailing-newline divergence.
common_session_id() {
  local _common_rand

  _common_rand="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  echo "sess_$(date +%s)_${_common_rand}"
  unset _common_rand
  return 0
}

# common_timestamp_iso -- echoes the current UTC time as YYYY-MM-DDTHH:MM:SSZ (the 19-site
# dominant form across the codebase).
common_timestamp_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
  return 0
}

# common_timestamp_epoch -- echoes the current UTC time as a Unix epoch integer.
common_timestamp_epoch() {
  date -u +%s
  return 0
}

# common_timestamp_date -- echoes the current UTC date as YYYY-MM-DD.
common_timestamp_date() {
  date -u +%Y-%m-%d
  return 0
}

# common_log_error / common_log_warn / common_log_info -- plain, side-effect-free emitters.
# Errors and warnings go to stderr; info goes to stdout. No counters, no color, no verbose
# gating -- see the NON-GOALS note above for why the several counter-incrementing/verbose-gated
# variants elsewhere are deliberately NOT replaced by these.
common_log_error() {
  echo "ERROR: $1" >&2
  return 0
}

common_log_warn() {
  echo "WARNING: $1" >&2
  return 0
}

common_log_info() {
  echo "INFO: $1"
  return 0
}

# common_test_pass / common_test_fail / common_test_info -- the shell-script-testing.md trio,
# operating on the CALLER's PASSED/FAILED integer counters (these functions are sourced into the
# caller's shell, not run in a subshell, so incrementing an unprefixed global here reaches the
# caller directly -- the caller must declare `PASSED=0` / `FAILED=0` before use, matching every
# existing suite's own convention). common_test_info is diagnostic-only and does not count.
common_test_pass() {
  echo "[PASS] $1"
  PASSED=$((${PASSED:-0} + 1))
  return 0
}

common_test_fail() {
  echo "[FAIL] $1"
  FAILED=$((${FAILED:-0} + 1))
  return 0
}

common_test_info() {
  echo "[INFO] $1"
  return 0
}
