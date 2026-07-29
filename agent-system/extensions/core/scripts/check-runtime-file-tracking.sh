#!/usr/bin/env bash
# check-runtime-file-tracking.sh - Verify a repo's git-tracking of orchestrator runtime files
# matches the policy in context/standards/orchestrator-runtime-files.md.
#
# Runs three checks from the repo root of any consumer repo:
#   A - Ignore coverage: every ephemeral-class pattern actually ignores a representative path
#       (tested via `git check-ignore -q`, not by grepping .gitignore text, so inherited or
#       differently-worded patterns are still detected).
#   B - Tracked ephemeral files: no file of an ephemeral class is currently tracked by git. Any
#       hit prints the exact `git rm --cached` (or `git rm -r --cached`) remediation command and
#       notes that the file stays on disk.
#   C - Provenance not over-ignored: `.orchestrator-handoff.json` and `.return-meta.json` are
#       NOT ignored. A repo that ignores them fails this check with the offending .gitignore
#       line named via `git check-ignore -v`.
#
# Exit code: 0 if all checks pass, 1 if any check fails.
#
# Usage: bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh
#        (or the deployed copy: bash .claude/scripts/check-runtime-file-tracking.sh)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0
PROBE_DIR="specs/000_probe"

# Ephemeral-class representative paths (Check A / Check B). Directory classes (.lock/) are
# probed with a file inside them, since git-ignore patterns for a directory only match paths
# under it.
declare -a EPHEMERAL_PROBES=(
  "${PROBE_DIR}/.orchestrator-loop-guard"
  "${PROBE_DIR}/.orchestrator-churn-state.json"
  "${PROBE_DIR}/.drift-inspection.json"
  "${PROBE_DIR}/.lock/holder.json"
  "${PROBE_DIR}/.continuation-loop-guard"
  "${PROBE_DIR}/.postflight-loop-guard"
  "specs/.orchestrator-multi-state-sess_0000000000_probe.json"
  "specs/.return-meta-multi-sess_0000000000_probe.json"
  "${PROBE_DIR}/.return-meta-orchestrate.json"
  "specs/.events.lock"
  "specs/.sessions/sess_0000000000_probe.json"
)

# Durable-provenance paths (Check C) — MUST NOT be ignored.
declare -a DURABLE_PROBES=(
  "${PROBE_DIR}/.orchestrator-handoff.json"
  "${PROBE_DIR}/.return-meta.json"
)

echo "check-runtime-file-tracking: verifying against context/standards/orchestrator-runtime-files.md"
echo "================================================================================"

# ── Check A: ignore coverage ──────────────────────────────────────────────────
echo ""
echo "Check A - ephemeral-class ignore coverage:"
a_failed=0
for probe in "${EPHEMERAL_PROBES[@]}"; do
  if git check-ignore -q "$probe" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC}   $probe is ignored"
  else
    echo -e "  ${RED}FAIL${NC} $probe is NOT ignored (ephemeral class must be gitignored)"
    a_failed=1
  fi
done
if [ "$a_failed" -eq 1 ]; then
  FAILURES=1
  echo -e "${RED}Check A FAILED${NC} — add the missing pattern(s) to the repo root .gitignore. See"
  echo "  context/standards/orchestrator-runtime-files.md 'Consumer Repo Setup' for the exact block."
else
  echo -e "${GREEN}Check A passed${NC}"
fi

# ── Check B: tracked ephemeral files ──────────────────────────────────────────
echo ""
echo "Check B - no ephemeral-class file is currently tracked:"
b_failed=0
b_patterns=(
  '\.orchestrator-loop-guard$'
  '\.orchestrator-churn-state\.json$'
  '\.drift-inspection\.json$'
  '/\.lock/'
  '\.continuation-loop-guard$'
  '\.postflight-loop-guard$'
  '\.orchestrator-multi-state(-[^/]+)?\.json$'
  '\.return-meta-[^/]*\.json$'
  '\.events\.lock$'
  '/\.sessions/[^/]+\.json$'
)
tracked_files=$(git ls-files 2>/dev/null)
for pattern in "${b_patterns[@]}"; do
  hits=$(echo "$tracked_files" | grep -E "$pattern" || true)
  if [ -n "$hits" ]; then
    b_failed=1
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      echo -e "  ${RED}FAIL${NC} tracked ephemeral file: $hit"
      if [[ "$hit" == *"/.lock/"* ]]; then
        lock_dir="${hit%/.lock/*}/.lock"
        echo "        remediation: git rm -r --cached \"$lock_dir\"  (file stays on disk)"
      else
        echo "        remediation: git rm --cached \"$hit\"  (file stays on disk)"
      fi
    done <<< "$hits"
  fi
done
if [ "$b_failed" -eq 1 ]; then
  FAILURES=1
  echo -e "${RED}Check B FAILED${NC} — run the remediation command(s) above to untrack without deleting."
else
  echo -e "${GREEN}Check B passed${NC} — no ephemeral-class file is tracked"
fi

# ── Check C: provenance not over-ignored ──────────────────────────────────────
echo ""
echo "Check C - durable provenance (.orchestrator-handoff.json / .return-meta.json) is NOT ignored:"
c_failed=0
for probe in "${DURABLE_PROBES[@]}"; do
  if git check-ignore -q "$probe" 2>/dev/null; then
    c_failed=1
    offending_line=$(git check-ignore -v "$probe" 2>/dev/null)
    echo -e "  ${RED}FAIL${NC} $probe is ignored (must be tracked): $offending_line"
    echo "        remediation: remove the offending .gitignore line. Never run git rm --cached on this file."
  else
    echo -e "  ${GREEN}OK${NC}   $probe is not ignored"
  fi
done
if [ "$c_failed" -eq 1 ]; then
  FAILURES=1
  echo -e "${RED}Check C FAILED${NC} — durable provenance must never be gitignored or untracked."
else
  echo -e "${GREEN}Check C passed${NC}"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "================================================================================"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}PASS${NC} — all three checks passed."
  exit 0
else
  echo -e "${RED}FAIL${NC} — one or more checks failed. See context/standards/orchestrator-runtime-files.md."
  exit 1
fi
