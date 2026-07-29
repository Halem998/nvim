#!/usr/bin/env bash
# file-scope-overlap.sh - Single source of truth for the directory-prefix file_scope overlap
# predicate.
#
# Canonical prose definition: context/patterns/file-footprint-overlap.md. This file transcribes
# that document's algorithm EXACTLY ONCE and is the only place the algorithm's logic is written
# down as code -- every consumer sources this file (or, for the jq-embedded consumer, splices
# $FILE_SCOPE_OVERLAP_JQ_DEFS into its own jq -n program) rather than re-deriving or restating the
# rule locally.
#
# Exports TWO things, for two different consumption shapes:
#
#   (a) scopes_overlap() - a callable bash function, for a caller (scripts/task-lock.sh) that
#       shells out to jq once per pairwise comparison.
#   (b) FILE_SCOPE_OVERLAP_JQ_DEFS - a variable holding raw jq `def` source text, for a caller
#       (scripts/orchestrate-batch-admit.sh) that embeds the algorithm inside one larger,
#       single-pass `jq -n --slurpfile` program and cannot shell out per comparison.
#
# FILE_SCOPE_OVERLAP_JQ_DEFS is assigned via a QUOTED heredoc (`<<'JQDEFS'`) so bash performs NO
# parameter/command expansion on its body -- the jq source (full of literal `"`, `+`, and `|`
# characters) is stored verbatim, with zero escaping cost to either this file or its splicing
# callers. See the plan's D1 decision record for why this `.sh`-lib-with-embedded-jq-defs shape
# was chosen over a standalone `.jq` file.

# ─── norm / scopes_overlap_first / self_mod_match (jq) ─────────────────────────────────────────
# Consumed by BOTH scopes_overlap() below (spliced directly into its own jq -n program) and by
# orchestrate-batch-admit.sh (splices this text into its larger program). Do not edit either
# consumer's copy of this logic -- there is no other copy; edit only here.
read -r -d '' FILE_SCOPE_OVERLAP_JQ_DEFS <<'JQDEFS'
# --- norm: path normalization per file-footprint-overlap.md's "Path Normalization" section ---
def norm: rtrimstr("/");

# --- scopes_overlap_first: the overlap predicate itself, per file-footprint-overlap.md's
# "Overlap Rule" section (exact match, or either side a directory-prefix ancestor of the other).
# Returns the first overlapping path FROM other_scope (the "foreign" side, matching
# task-lock.sh's historical scopes_overlap() call convention scopes_overlap "$own" "$other") on
# a hit, or jq `empty` (not `null`) when no pair overlaps -- callers that bind this via `as`
# inside an array comprehension rely on `empty` to contribute zero elements, not one null one.
def scopes_overlap_first(own_scope; other_scope):
  (own_scope // []) as $sa | (other_scope // []) as $sb |
  [ $sa[] as $pa | $sb[] as $pb |
    ($pa|norm) as $na | ($pb|norm) as $nb |
    select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/"))) |
    $pb
  ] | first // empty;

# --- self_mod_match: a further application of the SAME overlap predicate above -- the
# candidate's own file_scope compared against a static declared list of orchestrator-critical
# paths, rather than against another task's file_scope. Not a new matching rule; only what the
# candidate is compared against differs. Returns the first matching {path, label} entry, in the
# critical-path data file's declared order.
def self_mod_match($cscope; $crit):
  ($cscope // []) as $sa |
  [ $sa[] as $pa | $crit[] as $ce |
    ($pa|norm) as $na | ($ce.path|norm) as $nb |
    select($na == $nb or ($na | startswith($nb + "/")) or ($nb | startswith($na + "/"))) |
    $ce
  ] | first;
  # NOTE: deliberately `first` (never `first // empty`) -- unlike scopes_overlap_first above,
  # the result of this def is bound via `as $sm_hit |` OUTSIDE any array comprehension in every
  # known caller. An `empty` result there would make the ENTIRE per-candidate pipeline produce
  # zero output (the `as` construct binds by iterating its generator; a generator that yields
  # nothing means the downstream pipe never runs at all), silently dropping that candidate's
  # verdict from stdout. Returning `null` on no-match instead lets `$sm_hit != null` downstream
  # evaluate to `false` exactly once, as intended.
JQDEFS

# ─── scopes_overlap: bash-callable wrapper, today's exact signature and return convention ──────
# Usage: scopes_overlap "$scope_a_json" "$scope_b_json"
# scope_a_json / scope_b_json are compact JSON arrays of path strings. Prints the first
# overlapping path FROM scope_b (the "foreign" side, per cmd_acquire's call convention
# scopes_overlap "$own_scope" "$other_scope") on stdout when an overlap is found; prints nothing
# otherwise. Callers use `[ -n "$out" ]` as the boolean test and reuse the printed path in
# ABORT/WARN messages. Implemented by splicing FILE_SCOPE_OVERLAP_JQ_DEFS into a `jq -n` program
# rather than restating the algorithm -- this function is a thin bash-calling-convention shim
# over scopes_overlap_first(), nothing more.
scopes_overlap() {
  local scope_a="$1" scope_b="$2"
  local prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
scopes_overlap_first(\$a; \$b)"
  jq -n -r --argjson a "$scope_a" --argjson b "$scope_b" "$prog" 2>/dev/null
}
