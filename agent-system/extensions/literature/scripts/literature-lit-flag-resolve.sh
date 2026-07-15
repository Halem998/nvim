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
#   SPARSE_PROMPT_NEEDED specs/literature-index.json exists but resolves to < threshold entries
#                        (including 0) -- interactive context only (autonomous sparse coverage
#                        still takes the deterministic global-corpus path via AUTONOMOUS_GLOBAL
#                        upstream of this check never applying here, since the sub-index DOES
#                        exist; an autonomous run with a sparse sub-index proceeds with
#                        SUBINDEX_PRESENT-equivalent behavior -- see note below). The skill
#                        issues AskUserQuestion with the SAME four options as PROMPT_NEEDED,
#                        now including "Search online to ingest".
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
  echo "Rationale: per-repo sub-index found at $SUB_INDEX with $entry_count entries (>= threshold $LITERATURE_SPARSE_THRESHOLD); using per-repo briefing mode." >&2
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
