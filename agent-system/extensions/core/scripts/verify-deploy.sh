#!/bin/bash
# verify-deploy.sh - Check that a deployed .claude/ tree actually reflects its source store.
#
# This is the first of the two gates that any claim about deployed behavior has to clear. It
# answers "is the deploy tree current and are its hooks registered?" -- it does NOT answer "have
# events actually flowed?", which requires real command invocations over time. Do not report a
# passing run here as end-to-end verification.
#
# Restated precisely for this script's one automated consumer: this script's PASS claims only
# that the deploy tree matches its source store and that hooks are registered. It does NOT claim
# the redeployed machinery has been exercised -- that would require the second gate (real command
# invocations) described above, which this script cannot and does not perform.
#
# Callers: the inter-cycle redeploy checkpoint (`skill-orchestrate` Stage MT-3 step 7) is an
# automated consumer of this script's exit code AND, via --findings below, of its findings set.
# See context/patterns/batch-orchestration-guardrails.md's `### The Inter-Cycle Redeploy
# Checkpoint` subsection for the full contract this script is one half of (the other half being
# scripts/deploy-headless.sh).
#
# The checks are deliberately mechanical and independently reproducible; each prints the command
# it stands for, so a reader can re-run any single line by hand rather than trusting this script.
#
# Usage:
#   verify-deploy.sh [--quiet] [--findings] [TARGET_REPO]
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#   2  cannot run (target missing, or no deploy tree to inspect) -- an automated gate MUST treat
#      this the same as exit 1 (failure), never as a pass: a checkpoint that cannot establish the
#      redeploy landed is in the same position as one that established it did not.
#
# Findings mode (--findings, additive-only):
#   Emits a normalized, one-per-line, machine-diffable findings set across all eight gates (gate0
#   through gate7) plus a gate0 "could not run" sentinel, printed to stdout after the final
#   narrative PASS/FAIL line (including on a passing run, where an empty set is a valid,
#   meaningful result). Every finding line begins with the literal token `FINDING ` followed by a
#   gate label (`gate0`..`gate7`); the automated consumer is expected to invoke
#   `verify-deploy.sh --findings --quiet`, filter with `grep '^FINDING ' | sort -u`, and diff two
#   such captures rather than compare exit codes alone -- see the Checkpoint subsection above for
#   why exit-code-only comparison masks a newly-introduced finding hiding inside an
#   already-failing gate. This mode is purely additive: with --findings absent, default-mode
#   narrative output and exit codes are byte-for-byte unchanged.

set -uo pipefail

QUIET=false
FINDINGS=false
TARGET=""
FINDINGS_LIST=()

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    --findings) FINDINGS=true; shift ;;
    -h|--help)
      sed -n '2,43p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: unknown flag: $1"
      exit 2
      ;;
    *)
      TARGET="$1"; shift ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target is not a directory: $TARGET" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: target is not a directory: $TARGET"
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

CLAUDE_DIR="$TARGET/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "ERROR: no deploy tree at $CLAUDE_DIR -- nothing to verify." >&2
  echo "Run: bash deploy-headless.sh $TARGET" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: no deploy tree at $CLAUDE_DIR"
  exit 2
fi

FAILURES=0
CHECKS=0
CURRENT_GATE="gate0"

say() { [ "$QUIET" = "true" ] || echo "$@"; }

pass() {
  CHECKS=$((CHECKS + 1))
  say "  [PASS] $1"
}

# fail(): records a narrative failure (stderr, unchanged) AND, as a second consumer of the same
# single source, a findings-mode entry. The optional third argument overrides the finding text
# recorded for --findings (used where the narrative message embeds a numeric count that must not
# leak into the normalized finding, or where a caller extracts its own per-underlying-finding
# lines separately and passes "" here to suppress the default aggregate finding).
fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  echo "  [FAIL] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  if [ $# -ge 3 ]; then
    [ -n "$3" ] && FINDINGS_LIST+=("FINDING $CURRENT_GATE $3")
  else
    FINDINGS_LIST+=("FINDING $CURRENT_GATE $1")
  fi
  return 0
}

say "[verify-deploy] Target: $TARGET"
say ""

# ── 1. Core event-store and error-store files present ─────────────────────────
# Covers two store families: the passive-signal-capture stack (events.jsonl: append-only script,
# query script, both hooks, schema, format doc) and the error-tracking stack (errors.json:
# validated append/update writer, schema, format doc). A missing entry means the deploy predates
# that store's work or was a partial sync.
say "1. Event-store and error-store files (ls .claude/{scripts,hooks,context}/...)"
CURRENT_GATE="gate1"
for rel in \
  scripts/events-append.sh \
  scripts/events-query.sh \
  hooks/events-log-artifact.sh \
  hooks/events-log-lifecycle.sh \
  context/schemas/events-schema.json \
  context/formats/events-format.md \
  scripts/errors-append.sh \
  context/schemas/errors-schema.json \
  context/formats/errors-format.md
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
CURRENT_GATE="gate2"
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
CURRENT_GATE="gate3"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- doc-lint does not apply"
elif [ ! -x "$CLAUDE_DIR/scripts/check-extension-docs.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-extension-docs.sh" ]; then
  fail "check-extension-docs.sh not deployed"
else
  # Capture rather than discard: check-extension-docs.sh's `[ext_name]`/`[project-wide]` headers
  # and its `FAIL:` lines are unconditional echo (they survive that script's own --quiet), so a
  # single --quiet capture is enough to extract per-finding detail below. This generalizes the
  # STRICT_CORE_DEPLOY re-invocation precedent already used later in this same gate, rather than
  # introducing a new mechanism.
  doc_lint_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet 2>&1)
  doc_lint_exit=$?
  if [ "$doc_lint_exit" -eq 0 ]; then
    pass "doc-lint reports no failures"
  else
    # Third arg "" suppresses the default aggregate finding -- the per-underlying-FAIL: lines
    # extracted below are the findings-mode representation of this failure, not this message.
    fail "doc-lint reported failures" \
         "re-run without --quiet for detail: bash .claude/scripts/check-extension-docs.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      current_header="[unknown]"
      while IFS= read -r doc_lint_line; do
        case "$doc_lint_line" in
          "["*"]")
            current_header="$doc_lint_line"
            ;;
          "  FAIL: "*)
            # ADVISORY: lines are deliberately excluded (Decision 3) -- only this FAIL: case
            # matches; check-extension-docs.sh exits non-zero on FAIL only, never on ADVISORY.
            FINDINGS_LIST+=("FINDING gate3 ${current_header} ${doc_lint_line#  }")
            ;;
        esac
      done <<< "$doc_lint_output"
    fi
  fi

  strict_output=$(cd "$TARGET" && STRICT_CORE_DEPLOY=1 bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet 2>&1)
  strict_hits=$(printf '%s\n' "$strict_output" | grep -c 'events-')
  if [ "${strict_hits:-0}" -eq 0 ]; then
    pass "STRICT_CORE_DEPLOY reports no undeployed event files"
  else
    # Finding text (3rd arg) omits the numeric count (Decision 4) -- the condition is boolean
    # ("the deploy tree is behind the source store"); magnitude drift inside an already-failing
    # check must not manufacture a spurious "new" finding for the pre/post comparison.
    fail "STRICT_CORE_DEPLOY still reports $strict_hits event-file line(s)" \
         "the deploy tree is behind the source store" \
         "STRICT_CORE_DEPLOY reports undeployed event file(s): the deploy tree is behind the source store"
  fi
fi

say ""

# ── 4. Task-reference lint gate ───────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring the Doc-lint gate above -- a deploy
# consumer has no agent-system/extensions directory and the gate correctly skips there.
say "4. Task-reference lint (check-task-references.sh --quiet)"
CURRENT_GATE="gate4"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- task-reference lint does not apply"
elif [ ! -x "$CLAUDE_DIR/scripts/check-task-references.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-task-references.sh" ]; then
  fail "check-task-references.sh not deployed"
else
  # Leave this --quiet invocation verbatim (unlike gate 3, its per-finding `path:line:content`
  # detail is gated by that script's own info() and does NOT survive --quiet -- only the summary
  # counts and the final FAIL:/PASS: line do). Detail requires the WITHOUT-quiet re-invocation
  # below, done only when a finding-mode caller needs it and the gate already failed.
  if (cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" --quiet >/dev/null 2>&1); then
    pass "task-reference lint reports no findings"
  else
    fail "task-reference lint reported findings" \
         "re-run without --quiet for detail: bash .claude/scripts/check-task-references.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      task_ref_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" 2>&1)
      while IFS= read -r task_ref_line; do
        FINDINGS_LIST+=("FINDING gate4 ${task_ref_line#  }")
      done < <(printf '%s\n' "$task_ref_output" | grep -E '^  [^:]+:[0-9]+:')
    fi
  fi
fi

# ── 5. Manifest-driven category parity + content-hash equality (verify.lua) ──────
# Extends gates 1-4 (which check specific known files/registrations) to full declared-vs-
# deployed parity plus content-hash equality across every provides.* category the manifest
# declares, driven by neotex.plugins.ai.shared.extensions.verify's manager.verify_all -- the
# same check the extension loader itself runs after a load. Only meaningful in the source-store
# repo (a deploy consumer has no agent-system/extensions/core/ source directory to diff against),
# mirroring gates 3-4's SKIP-if-not-source-store precedent.
say "5. Manifest-driven category parity + content-hash equality (verify.lua)"
CURRENT_GATE="gate5"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- this gate compares against"
  say "         the source store and does not apply here"
elif ! command -v nvim >/dev/null 2>&1; then
  fail "nvim not found on PATH; cannot run the manifest-driven verification"
else
  verify_output=$(cd "$TARGET" && nvim --headless \
    -c "lua local ok1, ext_config = pcall(require, 'neotex.plugins.ai.shared.extensions.config'); local ok2, ext_init = pcall(require, 'neotex.plugins.ai.shared.extensions.init'); if not (ok1 and ok2) then print('VERIFY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, results = pcall(manager.verify_all, '${TARGET}'); if not pok then print('VERIFY_ERROR call: ' .. tostring(results)) else for _, v in ipairs(results) do if v.status ~= 'passed' then for _, err in ipairs(v.errors or {}) do print('VERIFY_FINDING ' .. v.extension .. ': ' .. err) end end end print('VERIFY_DONE count=' .. tostring(#results)) end end" \
    -c "qa!" 2>&1)

  if echo "$verify_output" | grep -q 'VERIFY_ERROR'; then
    verify_error_line=$(echo "$verify_output" | grep 'VERIFY_ERROR' | head -1)
    fail "manifest-driven verification could not run" "$verify_error_line" \
         "manifest-driven verification could not run: $verify_error_line"
  elif ! echo "$verify_output" | grep -q 'VERIFY_DONE'; then
    fail "manifest-driven verification produced no result" \
         "re-run: nvim --headless -c \"lua ...manager.verify_all(...)\"" \
         "manifest-driven verification produced no result"
  else
    # Unanchored (not '^VERIFY_FINDING '): nvim can prepend a terminal OSC7 cwd-reporting escape
    # sequence to its first stdout line with no newline separator, which would otherwise defeat a
    # start-of-line anchor. Mirrors deploy-headless.sh's own unanchored 'grep -o DEPLOY_COUNT=...'
    # extraction of the same headless-nvim-output family, for the same reason.
    verify_finding_count=$(echo "$verify_output" | grep -c 'VERIFY_FINDING ')
    if [ "$verify_finding_count" -eq 0 ]; then
      pass "declared-vs-deployed parity and content-hash equality (all loaded extensions)"
    else
      # Third arg "" suppresses the default aggregate finding -- the per-underlying-VERIFY_FINDING
      # lines extracted below are the findings-mode representation of this failure, mirroring
      # gate 3's doc-lint per-FAIL: line extraction.
      fail "manifest-driven verification reported $verify_finding_count finding(s)" \
           "re-run without --quiet for detail: bash .claude/scripts/verify-deploy.sh" ""
      if [ "$FINDINGS" = "true" ]; then
        # -o 'VERIFY_FINDING .*' extracts from the token onward regardless of what (if anything)
        # precedes it on the line -- same OSC7 robustness rationale as verify_finding_count above.
        # '#*VERIFY_FINDING ' (not '#VERIFY_FINDING ') strips everything up to and including the
        # token wherever it falls, not only at position 0.
        while IFS= read -r verify_finding_line; do
          FINDINGS_LIST+=("FINDING gate5 ${verify_finding_line#*VERIFY_FINDING }")
        done < <(echo "$verify_output" | grep -o 'VERIFY_FINDING .*')
      fi
    fi
  fi
fi

say ""

# ── 6. Agent contracts lint gate ──────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
say "6. Agent contracts lint (lint-agent-contracts.sh --verbose)"
CURRENT_GATE="gate6"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- agent contracts lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh" ]; then
  fail "lint-agent-contracts.sh not found in source store"
else
  agent_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh" --verbose 2>&1)
  agent_lint_status=$?
  if [ "$agent_lint_status" -eq 0 ]; then
    pass "agent contracts lint reports no failures"
  else
    fail "agent contracts lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r agent_lint_line; do
        FINDINGS_LIST+=("FINDING gate6 ${agent_lint_line#*FAIL\] }")
      done < <(printf '%s\n' "$agent_lint_output" | grep -F '[FAIL]')
    fi
  fi
fi

# ── 7. Routing wiring lint gate ───────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
say "7. Routing wiring lint (lint-routing-wiring.sh --verbose)"
CURRENT_GATE="gate7"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- routing wiring lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh" ]; then
  fail "lint-routing-wiring.sh not found in source store"
else
  routing_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh" --verbose 2>&1)
  routing_lint_status=$?
  if [ "$routing_lint_status" -eq 0 ]; then
    pass "routing wiring lint reports no failures"
  else
    fail "routing wiring lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r routing_lint_line; do
        FINDINGS_LIST+=("FINDING gate7 ${routing_lint_line#*FAIL\] }")
      done < <(printf '%s\n' "$routing_lint_output" | grep -F '[FAIL]')
    fi
  fi
fi

say ""
if [ "$FAILURES" -eq 0 ]; then
  echo "[verify-deploy] PASS -- $CHECKS check(s), 0 failure(s)"
  say ""
  say "NOTE: this verifies DEPLOYMENT only. Confirming that events actually flow requires real"
  say "command invocations afterwards -- inspect specs/events.jsonl for artifact_write,"
  say "subagent_stop, and session_stop lines postdating the deploy."
  if [ "$FINDINGS" = "true" ] && [ "${#FINDINGS_LIST[@]}" -gt 0 ]; then
    printf '%s\n' "${FINDINGS_LIST[@]}" | sort -u
  fi
  exit 0
fi

echo "[verify-deploy] FAIL -- $FAILURES of $CHECKS check(s) failed" >&2
if [ "$FINDINGS" = "true" ] && [ "${#FINDINGS_LIST[@]}" -gt 0 ]; then
  printf '%s\n' "${FINDINGS_LIST[@]}" | sort -u
fi
exit 1
