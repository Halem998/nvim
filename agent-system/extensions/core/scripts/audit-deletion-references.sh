#!/usr/bin/env bash
# audit-deletion-references.sh - On-demand deletion-reference detector.
#
# WHY THIS EXISTS: a literal-name grep for a deleted artifact's own name structurally cannot
# find a reference that names it through a GLOB or PATH PATTERN instead (e.g. a "Related Files"
# section pointing a now-deleted skill family's directory glob at a now-empty pattern), or prose
# that describes the deleted mechanism without ever spelling its literal name. This script runs
# three passes -- literal-name grep, wildcard-expanded grep, and delegated reachability -- and
# prints a triage checklist. It is the reusable form of the method that found the orphans left
# behind by the orchestrate-engine consolidation's team-mode-skill-family deletion: reachability
# analysis and glob/pattern-prose auditing catch DISJOINT defect classes (a file can be
# perfectly reachable -- valid index row, live load_when binding -- while its content is
# entirely dead), so hits from either pass require reading, not a pass/fail verdict.
#
# NOTE ON THIS SCRIPT'S OWN EXAMPLES: the usage/comments below deliberately use a generic
# placeholder (`old-artifact-a`, etc.) rather than any specific deleted name, so this script
# does not become a permanent self-referential hit against whichever deletion it is next used
# to audit.
#
# NOT A STANDING LINT: the glob/pattern-prose axis needs judgment -- a file legitimately
# discussing a deleted artifact's name in an unrelated sense is a false positive, and an
# auto-fail gate on that axis would be too noisy to run unattended. Invoke this deliberately
# from the task that performs a deletion, not from the standing lint suite.
#
# Usage:
#   bash audit-deletion-references.sh <deleted-artifact-name> [<deleted-artifact-name> ...]
#   REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/audit-deletion-references.sh <name>...
#       (source-store invocation override -- required because
#       .claude/scripts/audit-deletion-references.sh does not exist until a deploy runs; same
#       convention as check-extension-docs.sh / check-task-references.sh)
#
# Exit codes:
#   0 - ran to completion. Hits from any pass are CANDIDATES for triage, not failures -- a
#       nonzero count of hits does not change the exit code.
#   1 - usage error (no arguments) or a missing dependency (grep, or a delegated script absent).

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <deleted-artifact-name> [<deleted-artifact-name> ...]" >&2
  echo "  e.g. $0 old-artifact-a old-artifact-b old-artifact-c" >&2
  exit 1
fi
NAMES=("$@")

if ! command -v grep >/dev/null 2>&1; then
  echo "ERROR: grep is required and is not on PATH" >&2
  exit 1
fi

# ── REPO_ROOT resolution ─────────────────────────────────────────────────────────────────────
# Same convention as check-extension-docs.sh / check-task-references.sh: the computed default
# (SCRIPT_DIR/../..) is valid only in a deploy tree (.claude/scripts/ or .opencode/scripts/); a
# deliberate source-store invocation MUST pass REPO_ROOT=$(pwd) explicitly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "${REPO_ROOT:-}" ]] || . "$SCRIPT_DIR/deploy-root-guard.sh" || exit 1
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
EXT_DIR="$REPO_ROOT/agent-system/extensions"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: extension tree not found at $EXT_DIR" >&2
  exit 1
fi

TOTAL_HITS=0

echo "==================================================================================="
echo "audit-deletion-references.sh: triage checklist for ${#NAMES[@]} deleted artifact name(s)"
echo "  Names: ${NAMES[*]}"
echo "  Scope: $EXT_DIR"
echo "==================================================================================="

# ── Pass 1: literal-name grep ────────────────────────────────────────────────────────────────
# Each supplied name, verbatim, across the whole extension tree, no file-type restriction --
# this is the pass a normal "did I miss a rename" check already performs.
echo ""
echo "--- Pass 1: literal-name grep ---"
PATTERN1="$(IFS='|'; echo "${NAMES[*]}")"
PASS1_HITS=0
if hits="$(grep -rn -- "$PATTERN1" "$EXT_DIR" 2>/dev/null)"; then
  echo "$hits"
  PASS1_HITS=$(printf '%s\n' "$hits" | grep -c '.')
else
  echo "(no hits)"
fi
echo "Pass 1 hit count: $PASS1_HITS"
TOTAL_HITS=$((TOTAL_HITS + PASS1_HITS))

# ── Pass 2: wildcard-expanded grep ───────────────────────────────────────────────────────────
# For each name, derive stem variants and search them case-insensitively, restricted to the
# prose/config file types where a glob or path-pattern reference actually lives (*.md, *.sh,
# *.json). This is the pass a literal-name grep structurally cannot perform: it catches a file
# naming the deleted artifact through `{name}-*`, `*-{name}`, or its common-prefix stem (e.g.
# `old-artifact` from `old-artifact-a`) without ever spelling the full literal name.
echo ""
echo "--- Pass 2: wildcard-expanded grep (stem variants) ---"
PASS2_HITS=0
declare -A SEEN_PATTERNS=()
for name in "${NAMES[@]}"; do
  stem="${name%-*}"
  variants=("${name}-" "-${name}")
  if [[ "$stem" != "$name" ]]; then
    variants+=("$stem")
  fi
  for v in "${variants[@]}"; do
    # De-duplicate identical patterns across names sharing a stem (e.g. multiple deleted
    # per-mode siblings that all derive the same common-prefix stem).
    [[ -n "${SEEN_PATTERNS[$v]:-}" ]] && continue
    SEEN_PATTERNS[$v]=1
    if hits="$(grep -rniE --include="*.md" --include="*.sh" --include="*.json" -- "$v" "$EXT_DIR" 2>/dev/null)"; then
      echo "[variant: $v]"
      echo "$hits"
      count=$(printf '%s\n' "$hits" | grep -c '.')
      PASS2_HITS=$((PASS2_HITS + count))
    fi
  done
done
if [[ "$PASS2_HITS" -eq 0 ]]; then
  echo "(no hits)"
fi
echo "Pass 2 hit count: $PASS2_HITS"
TOTAL_HITS=$((TOTAL_HITS + PASS2_HITS))

# ── Pass 3: reachability delegation ──────────────────────────────────────────────────────────
# Delegates to the existing reachability tooling rather than reimplementing it: dangling
# index-entries.json rows, undeclared files, and line_count drift (check-extension-docs.sh),
# plus line_count-specific drift (generate-context-line-counts.sh --check). Findings are
# surfaced under this script's own heading; a nonzero exit from either delegate is reported,
# not treated as this script's own failure -- reachability findings may be pre-existing and
# unrelated to the deletion being audited.
echo ""
echo "--- Pass 3: reachability delegation ---"
CHECK_DOCS="$SCRIPT_DIR/check-extension-docs.sh"
LINE_COUNTS="$SCRIPT_DIR/generate-context-line-counts.sh"
DELEGATE_MISSING=0

if [[ -x "$CHECK_DOCS" || -f "$CHECK_DOCS" ]]; then
  echo "[check-extension-docs.sh]"
  REPO_ROOT="$REPO_ROOT" bash "$CHECK_DOCS" 2>&1 || true
else
  echo "ERROR: missing dependency: $CHECK_DOCS" >&2
  DELEGATE_MISSING=1
fi

if [[ -x "$LINE_COUNTS" || -f "$LINE_COUNTS" ]]; then
  echo ""
  echo "[generate-context-line-counts.sh --check]"
  (cd "$REPO_ROOT" && bash "$LINE_COUNTS" --check) 2>&1 || true
else
  echo "ERROR: missing dependency: $LINE_COUNTS" >&2
  DELEGATE_MISSING=1
fi

if [[ "$DELEGATE_MISSING" -eq 1 ]]; then
  echo "" >&2
  echo "ERROR: one or more delegated scripts are missing; cannot complete Pass 3" >&2
  exit 1
fi

echo ""
echo "==================================================================================="
echo "Triage summary: Pass 1 = $PASS1_HITS literal hit(s), Pass 2 = $PASS2_HITS wildcard hit(s)."
echo ""
echo "Reachability (Pass 3) and pattern-prose auditing (Passes 1-2) catch DISJOINT defect"
echo "classes: a file can be perfectly reachable (valid index row, live load_when binding)"
echo "while its content is entirely dead. Every hit above is a CANDIDATE requiring a human or"
echo "agent to read it and judge intent -- this script prints a checklist, not a verdict, and"
echo "always exits 0 on hits. Only a usage error or a missing dependency exits non-zero."
echo "==================================================================================="

exit 0
