#!/usr/bin/env bash
# literature-briefing-invoke.sh - Failure-surfacing wrapper around literature-briefing.sh
#
# Purpose:
#   literature-briefing.sh callers historically ran
#   `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""`,
#   which discards stderr and collapses a script crash into the exact same empty value a
#   legitimately-empty briefing produces. This wrapper surfaces that distinction: it invokes
#   literature-briefing.sh unchanged, lets stderr flow through, and on non-zero exit emits a
#   visible `[lit] briefing generation failed (exit N)` notice to stderr while still exiting 0
#   so callers' `|| lit_context=""` fallback semantics remain valid.
#
# Usage (identical to literature-briefing.sh, args are passed through unchanged):
#   literature-briefing-invoke.sh                              # per-repo sub-index mode
#   literature-briefing-invoke.sh --global "<query>" [--top-n N]  # global-corpus search mode
#
# IMPORTANT: Callers must NOT redirect this wrapper's stderr to /dev/null. Doing so defeats
# the entire purpose of this script (making literature-briefing.sh failures visible).
#
# On success (exit 0 from literature-briefing.sh): prints the underlying script's stdout
# unchanged and exits 0.
#
# On failure (non-zero exit from literature-briefing.sh): prints nothing to stdout, emits
# `[lit] briefing generation failed (exit N)` to stderr (N = the underlying script's exit
# code), and exits 0 itself (so `|| lit_context=""` at call sites still triggers correctly
# on the empty stdout, while the failure is now visible to the operator).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

output="$(bash "$SCRIPT_DIR/literature-briefing.sh" "$@")"
exit_code=$?

if [ "$exit_code" -ne 0 ]; then
    echo "[lit] briefing generation failed (exit $exit_code)" >&2
    exit 0
fi

printf '%s' "$output"
exit 0
