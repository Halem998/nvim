#!/usr/bin/env bash
# orchestrate-batch-admit.sh — Cross-batch file_scope admission predicate for /orchestrate.
#
# Purpose: the three existing file_scope overlap checks (task-creation-time pairwise
# comparison, phase-level parallel-dispatch comparison, and task-lock.sh's currently-held-lock
# comparison) each scope their comparison to a fixed, already-collected set — a creation batch,
# a task's phase list, or the locks presently held. None of them compares a candidate task
# against every OTHER non-terminal task sitting idle in specs/state.json outside the current
# invocation's batch and outside any held lock. This script closes that gap: it is a read-only,
# blocking (defer-not-fail) predicate that, for each candidate task number, checks its declared
# file_scope against every non-terminal task in specs/state.json — not just the tasks in this
# invocation, and not just the tasks currently holding a lock.
#
# Canonical predicate: this script transcribes, and never restates or forks, the directory-prefix
# overlap algorithm defined once in context/patterns/file-footprint-overlap.md. See that document
# for the normalization rule (rtrimstr("/")) and the three-way overlap test (exact match, or
# either path a directory-prefix ancestor of the other). This script is that document's fourth
# named consumer, alongside the task-level, phase-level, and lock-acquisition-level callers
# already listed there.
#
# Usage:
#   orchestrate-batch-admit.sh <task_number> [<task_number> ...]
#
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order. Verdict
# schema (pinned as "orchestrate-batch-admit-v1"; field order is stable):
#
#   $schema                 string   Literal "orchestrate-batch-admit-v1".
#   task_number              int     The candidate task number, echoed back.
#   decision                 string  "admit" or "defer". Never "fail" — a candidate this script
#                                     cannot resolve (unknown task, terminal status, empty/null
#                                     file_scope) is admitted, not failed; only a usage error or
#                                     unavailable state.json aborts the whole invocation (exit 2,
#                                     no verdicts at all).
#   colliding_task_number     int    Present only when decision == "defer". The other task's
#                                     project_number.
#   colliding_task_status     string Present only when decision == "defer". The other task's
#                                     status string, verbatim from state.json.
#   overlapping_path          string Present only when decision == "defer". The first overlapping
#                                     path, taken from the COLLIDING task's declared file_scope
#                                     (the "foreign" side), matching scopes_overlap()'s convention
#                                     in task-lock.sh — first match, not an exhaustive list.
#   collision_scope           string Present only when decision == "defer". "in_batch" (the
#                                     colliding task is itself one of this invocation's candidate
#                                     arguments) or "cross_batch" (it is not).
#   reason                    string Present only when decision == "defer". Machine-templated
#                                     human-readable summary; never the sole carrier of any fact
#                                     already present as a structured field above.
#
# Degenerate candidates (all resolve to a plain "admit" verdict, no collision fields):
#   - task_number absent from active_projects (unknown task)
#   - task_number's status is terminal (completed, abandoned, expanded — case-insensitive)
#   - task_number's file_scope is null, missing, or an empty array
#
# Comparison set (per candidate): every entry in active_projects whose status is NOT one of
# {completed, abandoned, expanded} (case-insensitive, so "PR READY" / "Completed" etc. are all
# handled), excluding the candidate itself, per rules/state-management.md's terminal-state list
# (Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]) — every other status (not_started,
# researching, researched, planning, planned, implementing, partial, pr_ready/"PR READY",
# blocked) is compared. Any task connected to the candidate by a dependencies[] edge in EITHER
# direction (candidate depends on it, or it depends on candidate) is excluded from the comparison
# set entirely — an explicit dependency edge already serializes that pair.
#
# Deferral-direction rule (this is the load-bearing semantic, read carefully):
#   - in_batch (the colliding task is itself one of this invocation's <task_number> arguments):
#     the candidate defers ONLY against a task with a LOWER project_number. A higher-numbered
#     in-batch task is the one that defers instead (it will see this candidate as its own
#     lower-numbered collision when ITS verdict is computed). This preserves the pre-existing
#     wave-split deferral direction bit-for-bit — nothing about in-batch behavior changes.
#   - cross_batch (the colliding task is NOT one of this invocation's arguments): the candidate
#     defers UNCONDITIONALLY, regardless of project_number ordering, because an out-of-batch task
#     cannot itself be deferred by an invocation it is not part of — there is no symmetric
#     "the other one defers instead" outcome available.
#
# Determinism: among the surviving comparison set (terminal-excluded, edge-excluded, and — for
# in_batch pairs only — direction-filtered), tasks are visited in ASCENDING project_number order;
# the FIRST task with an overlapping file_scope wins and its verdict is emitted. No exhaustive
# collection of all collisions is attempted or reported.
#
# Why this check is blocking, not advisory: the criterion imported for the blocking-vs-advisory
# decision is "computable from on-disk state alone, and the harm of skipping it is silent and
# hard to detect later." A cross-batch file_scope collision satisfies both halves — it requires
# nothing but a read of specs/state.json, and if skipped, two sessions can concurrently edit the
# same files with no lock contention (the colliding task holds no lock; it simply is not running)
# and no visible symptom until a merge conflict or silently overwritten edit turns up much later.
# That is precisely the profile the imported criterion assigns to "blocking." A later maintainer
# who reads the general literature on false positives from coarse directory-prefix scope
# declarations and is tempted to relax this check to advisory should re-derive the criterion
# above first — the false-positive cost here is a deferred task, not silent data loss, so the two
# are not comparable and the advisory relaxation is not warranted by that literature alone.
#
# Exit codes:
#   0 - verdicts were emitted successfully on stdout, REGARDLESS of how many are "defer".
#       Verdicts are data, not errors: this script never exits non-zero merely because a
#       candidate was deferred, and it never writes to state.json (pure predicate, read-only).
#   2 - usage error (zero arguments, or any argument that is not a non-negative integer), or
#       state unavailable (jq missing, or STATE_FILE missing/unparseable). Nothing is printed on
#       stdout in either case; a single loud line naming the reason goes to stderr.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- usage validation: zero args, or any non-integer arg, is a usage error ---
if [ "$#" -eq 0 ]; then
  echo "ERROR: orchestrate-batch-admit.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "$@"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-batch-admit.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-batch-admit.sh: jq is not available; cannot evaluate admission." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-batch-admit.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

# Build the candidates JSON array (preserves input order, including duplicates if given).
candidates_json="[$(printf '%s\n' "$@" | paste -sd, -)]"

# Single read of STATE_FILE via --slurpfile, feeding one jq program that computes every
# candidate's verdict and prints NDJSON in input order. No second read, no wildcard expansion,
# and no repo-wide filesystem walk of any kind.
verdicts=$(jq -n -c \
  --argjson candidates "$candidates_json" \
  --slurpfile state_arr "$STATE_FILE" \
  '
  # def scopes_overlap_first: jq transcription of file-footprint-overlap.md, mirroring
  # task-lock.sh scopes_overlap() exactly — rtrimstr("/") normalization, exact match or
  # either-side "+/" prefix containment. Returns the first overlapping path FROM the foreign
  # (own_scope vs. other_scope) side, per that existing convention.
  def scopes_overlap_first(own_scope; other_scope):
    def norm: rtrimstr("/");
    (own_scope // []) as $sa | (other_scope // []) as $sb |
    [ $sa[] as $pa | $sb[] as $pb |
      ($pa|norm) as $na | ($pb|norm) as $nb |
      select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/"))) |
      $pb
    ] | first // empty;

  def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");

  ($state_arr[0].active_projects // []) as $all |
  $candidates as $cands |

  $cands[] as $c |
  ([$all[] | select(.project_number == $c)] | first) as $entry |

  if ($entry == null) then
    {"$schema": "orchestrate-batch-admit-v1", task_number: $c, decision: "admit"}
  elif (($entry.status // "") | is_terminal) then
    {"$schema": "orchestrate-batch-admit-v1", task_number: $c, decision: "admit"}
  elif (($entry.file_scope // []) | length) == 0 then
    {"$schema": "orchestrate-batch-admit-v1", task_number: $c, decision: "admit"}
  else
    ($entry.dependencies // []) as $c_deps |
    ($entry.file_scope) as $c_scope |
    (
      [
        $all[] | . as $t | select(
          ($t.project_number != $c) and
          ((($t.status // "") | is_terminal) | not) and
          (($c_deps | index($t.project_number)) == null) and
          ((($t.dependencies // []) | index($c)) == null)
        )
      ] | sort_by(.project_number)
    ) as $comparison_set |
    (
      [
        $comparison_set[] as $other |
        ($other.project_number) as $other_num |
        ($cands | index($other_num)) as $in_batch_idx |
        (if $in_batch_idx == null then "cross_batch" else "in_batch" end) as $scope_kind |
        select($scope_kind == "cross_batch" or $other_num < $c) |
        scopes_overlap_first($c_scope; ($other.file_scope // [])) as $ov_path |
        select($ov_path != null and $ov_path != "") |
        {
          other_num: $other_num,
          other_status: ($other.status // ""),
          ov_path: $ov_path,
          scope_kind: $scope_kind
        }
      ] | first
    ) as $hit |
    if $hit == null then
      {"$schema": "orchestrate-batch-admit-v1", task_number: $c, decision: "admit"}
    else
      {
        "$schema": "orchestrate-batch-admit-v1",
        task_number: $c,
        decision: "defer",
        colliding_task_number: $hit.other_num,
        colliding_task_status: $hit.other_status,
        overlapping_path: $hit.ov_path,
        collision_scope: $hit.scope_kind,
        reason: ("file_scope overlap with non-terminal task #" + ($hit.other_num | tostring) +
                 " (" + (if $hit.scope_kind == "in_batch" then "in this batch" else "not in this batch" end) +
                 ") at " + $hit.ov_path + "; no dependencies[] edge between them")
      }
    end
  end
  ' 2>&1)
jq_exit=$?

if [ "$jq_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-batch-admit.sh: failed to evaluate admission against $STATE_FILE (jq exit $jq_exit)." >&2
  exit 2
fi

printf '%s\n' "$verdicts"
exit 0
