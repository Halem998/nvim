#!/usr/bin/env bash
# assess-repo-health.sh - Standalone, portable, fixture-testable probe for /todo's
# "Sync Repository Metrics" stage. Emits the whole `repository_health` object as one JSON
# document on stdout; never writes state.json or any other file itself (the caller pipes the
# output into `state-write.sh --argjson health ...`, see commands/todo.md Step 5.6).
#
# Why this exists as a script rather than markdown-embedded bash/jq (the prior shape): logic
# embedded in a command file's prose is executed by an agent but never compiled, so defects
# accumulate invisibly and cannot be regression-tested. The defect this script replaces was a
# build_errors probe of the shape `if cmd_a || cmd_b || true; then ... fi` -- the trailing
# `|| true` made the `if` unconditionally true, so `build_errors` was structurally always 0 and
# the `else` branch was dead code no reader noticed. See
# context/decisions (task history) for the full defect writeup; this header states the
# architectural conclusion only.
#
# Structural-soundness reading (deliberate scope decision): `build_errors` answers "is the tree
# structurally sound" (parseable/syntax-valid), NOT "does this project's own build/lint/test
# command pass". A project-specific check (make/npm/lake/nix/pytest/...) has no single portable
# command across the heterogeneous set of trees this agent-system deploys into (Lua, Python,
# Lean, Nix, LaTeX, Z3, web), and several of those checks are too slow to run on every /todo
# invocation. Structural soundness is checked instead, cheaply and portably, using tooling this
# agent-system already hard-depends on everywhere: `bash -n` (syntax-check only, never executes
# the file) on every tracked `*.sh`, and `jq empty` (parse-only) on every tracked `*.json`.
#
# `manageable` and `concerning` (declared members of the `repository_health.status` enum in
# context/schemas/state-schema.json) are deliberately never emitted by this script's derivation.
# They remain reserved for a future graded metric (e.g. a thresholded `todo_count`) -- this is
# intentional, not dead vocabulary the author forgot to wire up.
#
# Enumeration: `git ls-files` when --root is inside a git work tree (fast, respects .gitignore,
# matches how this repo's other census-style scripts enumerate -- see census-count.sh); a `find`
# fallback (excluding `.git/`) otherwise, so a non-git fixture directory (e.g. a test's
# `mktemp -d` workdir) is still enumerated correctly rather than silently reporting zero
# candidates. This fallback is load-bearing: a fixture-driven test suite for this script cannot
# demonstrate a failing probe without it, because `mktemp -d` directories are never git work
# trees.
#
# Degenerate case: when zero `*.sh` AND zero `*.json` candidates are found under --root,
# `build_errors` is emitted as JSON `null` (not the string "null", not 0, not 1) meaning
# "no applicable structural probe found -- not measured". This is the same nullable-field pattern
# already used by `memory_health.last_distilled` in state-schema.json.
#
# This script never `source`s, `eval`s, or executes any candidate file -- `bash -n` and `jq empty`
# are both parse-only.
#
# Usage:
#   assess-repo-health.sh [--root PATH] [-h|--help]
#
# Options:
#   --root PATH   Directory to assess. Default: the current git work tree's root
#                 (`git rev-parse --show-toplevel`, resolved from the caller's CWD), falling back
#                 to a script-relative guess (deployed `.claude/scripts/` or source-store
#                 `agent-system/extensions/core/scripts/` depth) when the CWD is not inside a git
#                 work tree at all. Fixtures/tests should always pass --root explicitly rather
#                 than relying on the default.
#   -h, --help    Print this usage block and exit 0.
#
# Output (stdout): one JSON object with exactly these keys:
#   last_assessed   string, ISO8601 UTC timestamp (`date -u +%Y-%m-%dT%H:%M:%SZ`).
#   todo_count      integer, count of matching lines across enumerated `*.lua *.py *.js *.ts
#                   *.tex` files containing the literal marker `TODO`.
#   fixme_count     integer, same enumeration, literal marker `FIXME`.
#   build_errors    integer, or JSON null in the degenerate zero-candidate case. Count of
#                   `*.sh` files failing `bash -n` plus `*.json` files failing `jq empty`.
#   status          string, one of the schema's declared enum members, derived solely from
#                   build_errors: null -> "unknown", 0 -> "healthy", >0 -> "critical".
#
# Exit codes:
#   0 - success, JSON emitted to stdout.
#   1 - usage error (unknown flag, --root missing its argument, or --root does not exist).
#   2 - required tool missing (jq, or bash itself somehow not on PATH for -n checks -- jq is the
#       realistic case, since jq is already a hard dependency across this agent-system).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,58p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      if [ -z "$ROOT" ]; then
        echo "ERROR: --root requires a PATH argument" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and not on PATH" >&2
  exit 2
fi

# ── Resolve default --root when not given explicitly ──────────────────────────────────────────
if [ -z "$ROOT" ]; then
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$git_root" ]; then
    ROOT="$git_root"
  else
    # Script-relative fallback: try both known deploy depths (deployed .claude/scripts/, and
    # source-store agent-system/extensions/core/scripts/), preferring whichever candidate looks
    # like a real repo root (has .git or specs/). Last resort: CWD.
    candidate_deployed="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || true)"
    candidate_source_store="$(cd "$SCRIPT_DIR/../../../.." 2>/dev/null && pwd || true)"
    ROOT=""
    for c in "$candidate_deployed" "$candidate_source_store"; do
      if [ -n "$c" ] && { [ -d "$c/.git" ] || [ -d "$c/specs" ]; }; then
        ROOT="$c"
        break
      fi
    done
    if [ -z "$ROOT" ]; then
      ROOT="$(pwd)"
    fi
  fi
fi

if [ ! -d "$ROOT" ]; then
  echo "ERROR: --root path does not exist or is not a directory: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

# ── Enumeration ─────────────────────────────────────────────────────────────────────────────────
# enumerate_by_glob GLOB -- prints NUL-delimited absolute paths under $ROOT matching GLOB
# (e.g. "*.sh"), via git ls-files when $ROOT is a git work tree, else via find (excluding .git/).
enumerate_by_glob() {
  local glob="$1"
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" ls-files -z -- "$glob" 2>/dev/null | while IFS= read -r -d '' rel; do
      printf '%s/%s\0' "$ROOT" "$rel"
    done
  else
    find "$ROOT" -type f -name "$glob" -not -path '*/.git/*' -print0 2>/dev/null
  fi
}

mapfile -d '' -t SH_FILES < <(enumerate_by_glob '*.sh')
mapfile -d '' -t JSON_FILES < <(enumerate_by_glob '*.json')

# ── Structural probe: bash -n / jq empty, never source/eval/execute a candidate ─────────────────
errors=0
for f in "${SH_FILES[@]}"; do
  [ -n "$f" ] || continue
  if ! bash -n "$f" >/dev/null 2>&1; then
    errors=$((errors + 1))
  fi
done
for f in "${JSON_FILES[@]}"; do
  [ -n "$f" ] || continue
  if ! jq empty "$f" >/dev/null 2>&1; then
    errors=$((errors + 1))
  fi
done

total_candidates=$(( ${#SH_FILES[@]} + ${#JSON_FILES[@]} ))
if [ "$total_candidates" -eq 0 ]; then
  build_errors_json="null"
  status="unknown"
elif [ "$errors" -eq 0 ]; then
  build_errors_json="$errors"
  status="healthy"
else
  build_errors_json="$errors"
  status="critical"
fi

# ── TODO/FIXME counts, over the same enumeration mechanism, scoped to the historical
#    source-file extension filter (*.lua *.py *.js *.ts *.tex) ──────────────────────────────────
count_marker() {
  local marker="$1"
  local total=0
  local f c
  for ext in lua py js ts tex; do
    while IFS= read -r -d '' f; do
      c=$(grep -c -- "$marker" "$f" 2>/dev/null || true)
      c="${c:-0}"
      total=$((total + c))
    done < <(enumerate_by_glob "*.${ext}")
  done
  printf '%s\n' "$total"
}

todo_count="$(count_marker "TODO")"
fixme_count="$(count_marker "FIXME")"

last_assessed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg last_assessed "$last_assessed" \
  --argjson todo_count "$todo_count" \
  --argjson fixme_count "$fixme_count" \
  --argjson build_errors "$build_errors_json" \
  --arg status "$status" \
  '{
    last_assessed: $last_assessed,
    todo_count: $todo_count,
    fixme_count: $fixme_count,
    build_errors: $build_errors,
    status: $status
  }'
