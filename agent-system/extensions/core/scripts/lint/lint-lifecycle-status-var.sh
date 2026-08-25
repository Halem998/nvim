#!/usr/bin/env bash
# lint-lifecycle-status-var.sh - Narrow regression guard for the $STATE_STATUS -> $status
# lifecycle-notify variable-name defect.
#
# Background: every lifecycle skill's Stage 8a is supposed to invoke the shared TTS/tab-color
# notifier with the operation's real status value, held in a variable named `$status` (per
# `context/patterns/skill-postflight-flow.md`'s own documented Preconditions). A previously-real
# defect passed the undefined `$STATE_STATUS` instead across 12 call sites; bash silently expands
# an unset variable to an empty string, and `lifecycle-notify.sh` treats an empty status as a
# silent no-op -- so the defect produced zero observable symptom for six-plus weeks and survived a
# full unification refactor. This script exists to make that exact regression impossible to
# reintroduce without a gate failing.
#
# Scope (deliberately narrow -- see the parent plan's Decision 2; this is NOT a general
# undefined-variable linter, which would require modelling the @-import graph and is far more
# false-positive-prone):
#   Scans every `SKILL.md` under `agent-system/extensions/*/skills/` and every file under
#   `agent-system/extensions/*/context/patterns/`, and FAILS if any line both (a) references
#   `$STATE_STATUS` and (b) also names the lifecycle-notify call surface on that same line
#   (`skill_lifecycle_notify`, `lifecycle-notify.sh`, or a `lifecycle_script` variable reference --
#   the three call shapes actually observed at the fixed defect sites: the shared-function call,
#   the literal-path direct invocation, and the variable-held-path direct invocation).
#
#   This line-co-occurrence heuristic is deliberately narrow: it does NOT flag a bare
#   `$STATE_STATUS` prose mention (e.g. `update-task-status.sh`'s own internal mapping, or prose
#   describing that script's behavior) because such mentions do not co-occur on the same line with
#   any of the three lifecycle-notify call tokens above. It MUST NOT be widened into a general
#   undefined-variable analyzer -- see Decision 2 in the parent plan for why that is out of scope.
#
# Root resolution: uses `git rev-parse --show-toplevel` (falling back to a `REPO_ROOT` env
# override, then to a script-relative default), matching lint-agent-contracts.sh's and
# lint-routing-wiring.sh's convention -- this script lives at the same scripts/lint/ depth and is
# designed to run identically from either the deployed .claude/scripts/lint/ copy or the
# agent-system/extensions/core/scripts/lint/ source-store copy.
#
# Usage: lint-lifecycle-status-var.sh [--verbose] [--help] [path...]
#   With no path arguments, scans the default corpus described above. Path arguments (used by
#   this script's own test suite to exercise a synthetic fixture) replace the default corpus
#   entirely rather than adding to it.
#
# Exit codes:
#   0 - no violations found
#   1 - one or more violations found
#   2 - environment/usage error (scan root not found, unknown argument)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VERBOSE=false
EXPLICIT_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: lint-lifecycle-status-var.sh [--verbose] [--help] [path...]"
      echo ""
      echo "Fails if any SKILL.md under agent-system/extensions/*/skills/, or any file under"
      echo "agent-system/extensions/*/context/patterns/, passes \$STATE_STATUS as the argument to"
      echo "skill_lifecycle_notify or lifecycle-notify.sh. The correct variable is \$status,"
      echo "documented in context/patterns/skill-postflight-flow.md's Preconditions section --"
      echo "passing the wrong name causes lifecycle TTS/tab-color notifications to silently no-op."
      echo ""
      echo "Exit codes: 0 = no violations, 1 = violations found, 2 = environment/usage error"
      exit 0
      ;;
    *)
      EXPLICIT_PATHS+=("$1")
      shift
      ;;
  esac
done

# ── Root resolution ──────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

EXTENSIONS_ROOT="$REPO_ROOT/agent-system/extensions"

VIOLATIONS=0
FILES_SCANNED=0

log_info() { $VERBOSE && echo "[INFO] $1" || true; }

# The three call-shape tokens observed at every previously-fixed defect site: the shared-function
# call, the literal `lifecycle-notify.sh` path in a direct invocation, and a `lifecycle_script`
# variable holding that path in a direct invocation.
CALL_TOKEN_ERE='skill_lifecycle_notify|lifecycle-notify\.sh|lifecycle_script'

scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  FILES_SCANNED=$((FILES_SCANNED + 1))
  local matches
  matches=$(grep -nE "\\\$STATE_STATUS" "$file" 2>/dev/null | grep -E "$CALL_TOKEN_ERE" || true)
  if [[ -n "$matches" ]]; then
    while IFS= read -r match_line; do
      [[ -z "$match_line" ]] && continue
      local lineno="${match_line%%:*}"
      echo -e "${RED}[VIOLATION]${NC} $file:$lineno"
      echo "  Passes \$STATE_STATUS to the lifecycle notifier. \$STATE_STATUS is never assigned"
      echo "  at this call site -- bash silently expands it to an empty string, and"
      echo "  lifecycle-notify.sh's empty-status branch is a no-op, so the lifecycle TTS/tab-color"
      echo "  announcement silently disappears. Use \$status instead -- the variable documented in"
      echo "  context/patterns/skill-postflight-flow.md's Preconditions section and already read"
      echo "  from .return-meta.json at that skill's own Stage 6."
      VIOLATIONS=$((VIOLATIONS + 1))
    done <<< "$matches"
  else
    log_info "OK: $file"
  fi
}

if [[ ${#EXPLICIT_PATHS[@]} -gt 0 ]]; then
  for p in "${EXPLICIT_PATHS[@]}"; do
    scan_file "$p"
  done
else
  if [[ ! -d "$EXTENSIONS_ROOT" ]]; then
    echo "ERROR: extensions root not found at $EXTENSIONS_ROOT" >&2
    exit 2
  fi
  while IFS= read -r f; do
    scan_file "$f"
  done < <(find "$EXTENSIONS_ROOT" -path '*/skills/*/SKILL.md' -type f 2>/dev/null | sort)
  while IFS= read -r f; do
    scan_file "$f"
  done < <(find "$EXTENSIONS_ROOT" -path '*/context/patterns/*' -type f -name '*.md' 2>/dev/null | sort)
fi

echo ""
if [[ "$VIOLATIONS" -eq 0 ]]; then
  echo -e "${GREEN}[PASS]${NC} lint-lifecycle-status-var: 0 violation(s) across $FILES_SCANNED file(s)"
  exit 0
else
  echo -e "${RED}[FAIL]${NC} lint-lifecycle-status-var: $VIOLATIONS violation(s) across $FILES_SCANNED file(s)"
  exit 1
fi
