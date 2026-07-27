#!/bin/bash
# verify-deploy.sh - Check that a deployed .claude/ tree actually reflects its source store.
#
# This is the first of the two gates that any claim about deployed behavior has to clear. It
# answers "is the deploy tree current and are its hooks registered?" -- it does NOT answer "have
# events actually flowed?", which requires real command invocations over time. Do not report a
# passing run here as end-to-end verification.
#
# The checks are deliberately mechanical and independently reproducible; each prints the command
# it stands for, so a reader can re-run any single line by hand rather than trusting this script.
#
# Usage:
#   verify-deploy.sh [--quiet] [TARGET_REPO]
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#   2  cannot run (target missing, or no deploy tree to inspect)

set -uo pipefail

QUIET=false
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      TARGET="$1"; shift ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target is not a directory: $TARGET" >&2
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

CLAUDE_DIR="$TARGET/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "ERROR: no deploy tree at $CLAUDE_DIR -- nothing to verify." >&2
  echo "Run: bash deploy-headless.sh $TARGET" >&2
  exit 2
fi

FAILURES=0
CHECKS=0

say() { [ "$QUIET" = "true" ] || echo "$@"; }

pass() {
  CHECKS=$((CHECKS + 1))
  say "  [PASS] $1"
}

fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  echo "  [FAIL] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  return 0
}

say "[verify-deploy] Target: $TARGET"
say ""

# ── 1. Core event-store files present ────────────────────────────────────────
# These six are the passive-signal-capture stack. A missing one means the deploy predates that
# work or was a partial sync.
say "1. Event-store files (ls .claude/{scripts,hooks,context}/...)"
for rel in \
  scripts/events-append.sh \
  scripts/events-query.sh \
  hooks/events-log-artifact.sh \
  hooks/events-log-lifecycle.sh \
  context/schemas/events-schema.json \
  context/formats/events-format.md
do
  if [ -e "$CLAUDE_DIR/$rel" ]; then
    pass "$rel"
  else
    fail "$rel is missing" "run deploy-headless.sh to regenerate"
  fi
done
say ""

# ── 2. Hook registrations in the deployed settings.json ──────────────────────
# The single most failure-prone part of a deploy: settings.json is install-once, so additions
# reach an existing repo only through merge-sources/settings-hooks.json. A tree can have every
# hook SCRIPT present and still register none of them.
say "2. Hook registrations (jq '.hooks' .claude/settings.json)"
SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  fail "settings.json is missing"
elif ! command -v jq >/dev/null 2>&1; then
  fail "jq unavailable; cannot inspect hook registrations"
elif ! jq empty "$SETTINGS" 2>/dev/null; then
  fail "settings.json is not valid JSON"
else
  for pair in "PostToolUse:events-log-artifact.sh" \
              "Stop:events-log-lifecycle.sh" \
              "SubagentStop:events-log-lifecycle.sh"
  do
    event="${pair%%:*}"
    script="${pair##*:}"
    n=$(jq --arg e "$event" --arg s "$script" \
      '[.hooks[$e][]?.hooks[]? | select(.command | test($s))] | length' "$SETTINGS" 2>/dev/null)
    n="${n:-0}"
    if [ "$n" -ge 1 ]; then
      pass "$event -> $script registered"
    else
      fail "$event -> $script NOT registered" \
           "add it to merge-sources/settings-hooks.json, not root-files/settings.json"
    fi
  done

  # Duplicate detection. Reported as a warning, never a failure: the merge is add-only and
  # cannot remove a pre-existing entry, so a duplicate is a manual-cleanup item rather than
  # something a regeneration could ever fix. Failing on it would make this script permanently
  # red on any tree that has ever accumulated one.
  dupes=$(jq -r '
    [.hooks | to_entries[] | .key as $e | .value[]?.hooks[]?.command
     | select(. != null) | "\($e)\t\(.)"]
    | group_by(.) | map(select(length > 1) | {cmd: .[0], n: length}) | .[]
    | "\(.cmd) x\(.n)"' "$SETTINGS" 2>/dev/null)
  if [ -n "$dupes" ]; then
    say ""
    say "  [WARN] duplicate hook command registrations (manual cleanup; no merge can remove these):"
    while IFS= read -r line; do
      [ -n "$line" ] && say "         $line"
    done <<< "$dupes"
  fi
fi
say ""

# ── 3. Doc-lint gate ─────────────────────────────────────────────────────────
# Only meaningful in the source-store repo. A deploy consumer has no agent-system/extensions
# directory, and the gate correctly errors there -- that is not a deploy failure.
say "3. Doc-lint (check-extension-docs.sh --quiet)"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- doc-lint does not apply"
elif [ ! -x "$CLAUDE_DIR/scripts/check-extension-docs.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-extension-docs.sh" ]; then
  fail "check-extension-docs.sh not deployed"
else
  if (cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet >/dev/null 2>&1); then
    pass "doc-lint reports no failures"
  else
    fail "doc-lint reported failures" \
         "re-run without --quiet for detail: bash .claude/scripts/check-extension-docs.sh"
  fi

  strict_hits=$( (cd "$TARGET" && STRICT_CORE_DEPLOY=1 bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet 2>&1) | grep -c 'events-' )
  if [ "${strict_hits:-0}" -eq 0 ]; then
    pass "STRICT_CORE_DEPLOY reports no undeployed event files"
  else
    fail "STRICT_CORE_DEPLOY still reports $strict_hits event-file line(s)" \
         "the deploy tree is behind the source store"
  fi
fi

say ""
if [ "$FAILURES" -eq 0 ]; then
  echo "[verify-deploy] PASS -- $CHECKS check(s), 0 failure(s)"
  say ""
  say "NOTE: this verifies DEPLOYMENT only. Confirming that events actually flow requires real"
  say "command invocations afterwards -- inspect specs/events.jsonl for artifact_write,"
  say "subagent_stop, and session_stop lines postdating the deploy."
  exit 0
fi

echo "[verify-deploy] FAIL -- $FAILURES of $CHECKS check(s) failed" >&2
exit 1
