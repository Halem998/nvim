#!/usr/bin/env bash
# literature-lit-flag-resolve.sh - Classify the --lit Stage 4a decision into one directive
#
# Usage:
#   literature-lit-flag-resolve.sh --lit-flag <true|false> --orchestrator-mode <true|false> \
#     --query "<task description>"
#
# Purpose:
#   AskUserQuestion must be issued inline by the calling skill (it cannot run inside a shell
#   script), so this helper owns only the deterministic classification part of the Stage 4a
#   decision. It prints exactly one directive token on stdout; the calling skill (SKILL.md
#   Stage 4a) branches on that token and is responsible for issuing AskUserQuestion when (and
#   only when) the directive is PROMPT_NEEDED. Human-readable rationale is written to stderr
#   so the caller can surface a visible notice without polluting the stdout directive.
#
# Directives (stdout, exactly one line, no other output on stdout):
#   LIT_DISABLED         --lit-flag is not "true"; the skill injects nothing (existing behavior).
#   SUBINDEX_PRESENT     specs/literature-index.json exists AND resolves to >= threshold
#                        entries; the skill calls literature-briefing.sh with no arguments
#                        (per-repo mode).
#                        SPARSE_PROMPT_NEEDED now has a SECOND, independent cause in addition to
#                        the absolute-count one below: a sub-index that clears the count floor
#                        can still be downgraded from SUBINDEX_PRESENT to SPARSE_PROMPT_NEEDED
#                        when the topic-scoped coverage-delta guard (literature-coverage-delta.sh)
#                        finds global top-level documents matching this task's own filtered
#                        search terms that the sub-index never references. The token, option set,
#                        and autonomy contract are UNCHANGED -- only the rationale text
#                        distinguishes the two causes. See the SPARSE_PROMPT_NEEDED entry below.
#   GLOBAL_MISSING       sub-index absent AND the global Literature index is also absent; the
#                        skill emits a visible "no literature available" notice and continues
#                        empty. This is the one acceptable empty branch, and it is explicitly
#                        announced by the caller, never silent.
#   PROMPT_NEEDED        sub-index absent, global index present, interactive context
#                        (--orchestrator-mode != "true"); the skill issues AskUserQuestion with
#                        four options: "Use global corpus now", "Create curation task",
#                        "Search online to ingest", "Skip this run" (see the shared Stage 4a
#                        block for the exact wording).
#   AUTONOMOUS_GLOBAL    sub-index absent, global index present, autonomous context
#                        (--orchestrator-mode == "true"); the skill MUST NOT call
#                        AskUserQuestion. It takes the deterministic default "Use global corpus
#                        now": run `literature-briefing.sh --global "<query>"` and emit a visible
#                        [lit:auto] notice explaining why the choice was made autonomously.
#   SPARSE_PROMPT_NEEDED specs/literature-index.json exists but EITHER (a) resolves to < threshold
#                        entries (including 0), OR (b) resolves to >= threshold entries but the
#                        topic-scoped coverage-delta guard found global top-level documents
#                        matching this task's filtered search terms that are absent from the
#                        sub-index (see literature-coverage-delta.sh; controlled by
#                        LITERATURE_COVERAGE_GAP_MIN and LITERATURE_COVERAGE_DELTA_THRESHOLD) --
#                        interactive context only (autonomous sparse coverage/delta-miss coverage
#                        still takes the deterministic global-corpus path via AUTONOMOUS_GLOBAL
#                        upstream of this check never applying here, since the sub-index DOES
#                        exist; an autonomous run with a sparse or delta-flagged sub-index
#                        proceeds with SUBINDEX_PRESENT-equivalent behavior -- see note below).
#                        The skill issues AskUserQuestion with the SAME four options as
#                        PROMPT_NEEDED, now including "Search online to ingest". Cause (a) and
#                        cause (b) are distinguished only in the stderr rationale text, never in
#                        the stdout token, the option set, or the autonomy contract.
#                        This directive is reachable from a SECOND call site/timing that this
#                        script does NOT implement directly (it is single-shot): after a global
#                        search already ran (e.g. from PROMPT_NEEDED's "Use global corpus now"
#                        option) and literature-briefing.sh's `<!-- lit-coverage ... -->` marker
#                        (see that script) reports `sparse=true`, the calling shared Stage 4a
#                        block re-prompts with the same SPARSE_PROMPT_NEEDED option set WITHOUT
#                        re-invoking this resolver -- the two-checkpoint shape lives in the
#                        skill/shared block, not here (Decision 3 of the sparse-literature-
#                        detection design).
#
# NOTE on autonomous + sparse sub-index: today this script only emits SPARSE_PROMPT_NEEDED from
# the SUBINDEX_PRESENT branch, which does not itself distinguish orchestrator_mode (a sparse-but-
# present sub-index in an autonomous run still returns SPARSE_PROMPT_NEEDED; the calling shared
# Stage 4a block is responsible for treating SPARSE_PROMPT_NEEDED like AUTONOMOUS_GLOBAL --
# proceed with the deterministic default, emit [lit:auto], never call AskUserQuestion -- when
# orchestrator_mode is true).
#
# Inputs:
#   --lit-flag <true|false>          Value of the --lit command flag for this invocation.
#   --orchestrator-mode <true|false> Value of the orchestrator_mode delegation-context field.
#   --query "<text>"                 Task description text (used only for logging/rationale
#                                     here; the caller passes it again to literature-briefing.sh
#                                     --global when acting on PROMPT_NEEDED/AUTONOMOUS_GLOBAL/
#                                     SPARSE_PROMPT_NEEDED).
#   LITERATURE_DIR (env)              Path to the global Literature/ repo
#                                     (default: ~/Projects/Literature).
#   LITERATURE_SPARSE_THRESHOLD (env) Minimum sub-index entry count before SUBINDEX_PRESENT is
#                                     downgraded to SPARSE_PROMPT_NEEDED (default: 3; same
#                                     default and `< threshold` boundary semantics as
#                                     literature-briefing.sh's coverage marker).
#   LITERATURE_COVERAGE_GAP_MIN (env) Forwarded to literature-coverage-delta.sh -- the minimum
#                                     global-docs-minus-subindex-docs gap before the topic-scoped
#                                     keyword pass runs at all (default: 25).
#   LITERATURE_COVERAGE_DELTA_THRESHOLD (env) Minimum topic-matched missing-candidate count
#                                     (delta_candidates) before a sub-index that already clears
#                                     LITERATURE_SPARSE_THRESHOLD is still downgraded to
#                                     SPARSE_PROMPT_NEEDED (default: 1).
#
# AskUserQuestion is NEVER issued by this script -- that remains the caller's responsibility.

set -euo pipefail

# --- Resolve LITERATURE_DIR ---
LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SUB_INDEX="$PROJECT_ROOT/specs/literature-index.json"
GLOBAL_INDEX="$LIT_DIR/index.json"
LITERATURE_SPARSE_THRESHOLD="${LITERATURE_SPARSE_THRESHOLD:-3}"
# Forwarded to literature-coverage-delta.sh (LITERATURE_COVERAGE_GAP_MIN, exported explicitly so
# an operator override reaches the child process regardless of whether the invoking shell already
# exported it) and compared against its delta_candidates output (LITERATURE_COVERAGE_DELTA_THRESHOLD,
# not forwarded -- the threshold comparison happens in THIS script, not inside the delta script).
export LITERATURE_COVERAGE_GAP_MIN="${LITERATURE_COVERAGE_GAP_MIN:-25}"
LITERATURE_COVERAGE_DELTA_THRESHOLD="${LITERATURE_COVERAGE_DELTA_THRESHOLD:-1}"

# --- Argument parsing ---
lit_flag=""
orchestrator_mode=""
query=""

while [ $# -gt 0 ]; do
  case "$1" in
    --lit-flag)
      lit_flag="${2:-}"
      shift 2
      ;;
    --orchestrator-mode)
      orchestrator_mode="${2:-}"
      shift 2
      ;;
    --query)
      query="${2:-}"
      shift 2
      ;;
    *)
      echo "Warning: unrecognized argument '$1' ignored" >&2
      shift
      ;;
  esac
done

# --- Classification ---
if [ "$lit_flag" != "true" ]; then
  echo "Rationale: --lit-flag is '${lit_flag:-<unset>}' (not 'true'); literature injection stays off." >&2
  echo "LIT_DISABLED"
  exit 0
fi

if [ -f "$SUB_INDEX" ]; then
  # Reuse the same lightweight `.entries | length` count literature-briefing.sh's own
  # resolution loop is keyed on -- do not re-implement its full doc_id/GLOBAL_INDEX
  # cross-reference here (Risk 4: counting duplication).
  entry_count=$(jq '.entries | length' "$SUB_INDEX" 2>/dev/null || echo 0)
  if [ "$entry_count" -lt "$LITERATURE_SPARSE_THRESHOLD" ]; then
    echo "Rationale: per-repo sub-index found at $SUB_INDEX but only $entry_count entries (< threshold $LITERATURE_SPARSE_THRESHOLD); coverage is sparse -- offering the sparse-prompt option set (same four options as PROMPT_NEEDED, including 'Search online to ingest')." >&2
    echo "SPARSE_PROMPT_NEEDED"
    exit 0
  fi

  # Sub-index clears the absolute count floor -- now run the topic-scoped coverage-delta guard
  # (D1/D2/D3 of the coverage-delta-guard design) before short-circuiting as healthy. Guarded so
  # a delta-script failure or absence degrades to today's SUBINDEX_PRESENT behavior with a
  # visible stderr notice -- never a crash, never a silent skip.
  delta_script="$SCRIPT_DIR/literature-coverage-delta.sh"
  delta_line=""
  if [ -x "$delta_script" ]; then
    delta_line=$(bash "$delta_script" --query "$query" 2>/dev/null) || delta_line=""
  else
    echo "Rationale: literature-coverage-delta.sh not found or not executable at $delta_script; skipping the coverage-delta guard and falling back to today's SUBINDEX_PRESENT behavior." >&2
  fi

  delta_checked="false"
  delta_candidates=0
  delta_gap=0
  delta_candidate_ids=""
  if [ -n "$delta_line" ]; then
    # `|| true` on each extraction: under `set -euo pipefail`, a non-matching grep in a pipeline
    # would otherwise abort this script -- these fields are expected present per
    # literature-coverage-delta.sh's contract, but a future format drift must degrade to the
    # "false"/0/"" defaults above, never crash the resolver.
    delta_checked=$(echo "$delta_line" | grep -oE 'delta_checked=[a-z]+' | cut -d= -f2) || delta_checked="false"
    delta_candidates=$(echo "$delta_line" | grep -oE 'delta_candidates=[0-9]+' | cut -d= -f2) || delta_candidates=0
    delta_gap=$(echo "$delta_line" | grep -oE 'delta_gap=[0-9]+' | cut -d= -f2) || delta_gap=0
    # Anchored to a preceding space/start-of-string so this does not also match the
    # "delta_candidates=" field above (a bare "candidates=" substring search would).
    delta_candidate_ids=$(echo "$delta_line" | grep -oE '(^| )candidates=[^ ]*' | cut -d= -f2-) || delta_candidate_ids=""
    delta_checked="${delta_checked:-false}"
    delta_candidates="${delta_candidates:-0}"
    delta_gap="${delta_gap:-0}"
  fi

  if [ "$delta_checked" = "true" ] && [ "$delta_candidates" -ge "$LITERATURE_COVERAGE_DELTA_THRESHOLD" ]; then
    echo "Rationale: per-repo sub-index found at $SUB_INDEX with $entry_count entries (>= threshold $LITERATURE_SPARSE_THRESHOLD) -- clears the absolute-count floor, but the topic-scoped coverage-delta guard found $delta_candidates global document(s) (gap=$delta_gap) matching this task's search terms that are absent from the sub-index: ${delta_candidate_ids:-<none listed>}. This is a DIFFERENT cause from the absolute-count sparse rule above -- offering the same sparse-prompt option set." >&2
    echo "SPARSE_PROMPT_NEEDED"
    exit 0
  fi

  echo "Rationale: per-repo sub-index found at $SUB_INDEX with $entry_count entries (>= threshold $LITERATURE_SPARSE_THRESHOLD); using per-repo briefing mode. Coverage-delta guard: delta_checked=$delta_checked delta_candidates=$delta_candidates delta_gap=$delta_gap (non-firing)." >&2
  echo "SUBINDEX_PRESENT"
  exit 0
fi

if [ ! -f "$GLOBAL_INDEX" ]; then
  echo "Rationale: no per-repo sub-index at $SUB_INDEX and no global Literature index at $GLOBAL_INDEX; no literature is available this run." >&2
  echo "GLOBAL_MISSING"
  exit 0
fi

# Sub-index absent, global index present -- decision depends on autonomy.
if [ "$orchestrator_mode" = "true" ]; then
  echo "Rationale: no per-repo sub-index; global index present at $GLOBAL_INDEX; autonomous context (orchestrator_mode=true) -- no human available to prompt, so the deterministic default 'Use global corpus now' applies for query: ${query:-<empty>}." >&2
  echo "AUTONOMOUS_GLOBAL"
  exit 0
fi

echo "Rationale: no per-repo sub-index; global index present at $GLOBAL_INDEX; interactive context -- prompting the user to choose between global-corpus search, curation task creation, or skipping this run." >&2
echo "PROMPT_NEEDED"
exit 0
