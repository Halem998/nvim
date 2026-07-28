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
# A FOURTH, orthogonal dimension is layered on top of the cross-batch collision check above: the
# self-modification hazard check. Before the collision scan runs at all, this script tests
# whether the candidate's OWN file_scope names a file on a fixed, declared list of
# orchestrator-critical paths (context/reference/orchestrator-critical-paths.json). If it does,
# and this invocation carries more than one CO-DISPATCHED candidate (see the `--invocation-count`
# contract below), the candidate is deferred out of the CURRENT wave/cycle — converging the same
# way a `file_scope_collision` defer already does — so orchestrator-machinery work never actually
# runs concurrently with another candidate. See context/patterns/batch-orchestration-guardrails.md's
# "Self-Modification Hazard: The Fourth Admission Dimension" section for the two-test rationale
# (reachability + decision-relevance) behind the declared list, and
# docs/architecture/batch-admit-schema.md for the full verdict schema this check adds.
#
# Canonical predicate: this script transcribes, and never restates or forks, the directory-prefix
# overlap algorithm defined once in context/patterns/file-footprint-overlap.md. See that document
# for the normalization rule (rtrimstr("/")) and the three-way overlap test (exact match, or
# either path a directory-prefix ancestor of the other). This script is that document's fourth
# named consumer, alongside the task-level, phase-level, and lock-acquisition-level callers
# already listed there. The self-modification check above is a FURTHER APPLICATION of the same
# predicate — the candidate's own file_scope compared against a static declared list rather than
# against another task's file_scope — not a new matching rule.
#
# Usage:
#   orchestrate-batch-admit.sh [--invocation-count <N>] <task_number> [<task_number> ...]
#
# `--invocation-count <N>` (D3): the number of candidates being CO-DISPATCHED IN THE SAME
# wave/cycle as the positional <task_number> arguments — not the whole invocation's total
# candidate count. Callers that pass a wave/cycle subset (wave_tasks, eligible_tasks) MUST pass
# that subset's own size here, not the invocation's full validated-candidate count, or the
# self-modification defer trigger over-fires against candidates that never actually co-occur in a
# dispatch batch (see the file-top paragraph above and the Precedence (D4) block below for why a
# whole-invocation count is wrong). Defaults to the number of positional <task_number> arguments
# when omitted (backward-compatible: correct for any caller that already passes its own
# co-dispatch set in one call). A non-integer value is a usage error, same as a non-integer
# task_number.
#
# Flag name retained (not renamed): `--invocation-count` keeps its original name even though its
# documented semantics narrowed from "whole invocation" to "same-cycle co-dispatch count", because
# two out-of-scope report composers — scripts/orchestrate-dry-run-report.sh and
# scripts/orchestrate-predispatch-review.sh — pass this flag BY NAME. Renaming it would make an
# unrecognized `--invocation-count` fall through those callers' argument scans into positional
# validation, aborting with exit 2. A `--codispatch-count` alias was considered and rejected: it
# would add a second flag name to orchestrator-critical machinery for a naming-clarity improvement
# only, with no behavioral benefit over documenting the narrowed meaning under the existing name.
#
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order. Verdict
# schema (pinned as "orchestrate-batch-admit-v3"; field order is stable):
#
#   $schema                 string   Literal "orchestrate-batch-admit-v3".
#   task_number              int     The candidate task number, echoed back.
#   decision                 string  "admit" or "defer". Never "fail" — a candidate this script
#                                     cannot resolve (unknown task, terminal status, empty/null
#                                     file_scope) is admitted, not failed; only a usage error or
#                                     unavailable state.json aborts the whole invocation (exit 2,
#                                     no verdicts at all).
#   self_modifying            bool|null  Present on EVERY verdict, including "admit". `true` when
#                                     the candidate's own file_scope names a declared
#                                     orchestrator-critical path; `false` when it does not;
#                                     `null` when the critical-path data file is missing or
#                                     unparseable (degraded — see below). A solo admitted run of
#                                     a self-modifying candidate still carries `true` here, so
#                                     the hazard stays visible even when it is not deferred.
#   defer_reason              string  Present only when decision == "defer". Exactly one of
#                                     "self_modifying" or "file_scope_collision" — REQUIRED
#                                     discriminator (schema v3). Existing consumers MUST branch
#                                     on this field before falling into any pre-v2 default
#                                     handling. As of v3 both defer reasons are wave/cycle-scoped
#                                     (neither is a whole-invocation exclusion); the discriminator
#                                     exists to name the HAZARD behind the defer and select the
#                                     operator remedy (self_modifying's remedy is the
#                                     `--allow-self-modifying` override; file_scope_collision has
#                                     none — see the v3 schema doc).
#   critical_path              string Present only when defer_reason == "self_modifying". The
#                                     matched declared critical path (post scope-root expansion).
#   critical_label              string Present only when defer_reason == "self_modifying". The
#                                     matched entry's short label, from the critical-paths data
#                                     file.
#   colliding_task_number     int    Present only when defer_reason == "file_scope_collision".
#                                     The other task's project_number.
#   colliding_task_status     string Present only when defer_reason == "file_scope_collision".
#                                     The other task's status string, verbatim from state.json.
#   overlapping_path          string Present only when defer_reason == "file_scope_collision".
#                                     The first overlapping path, taken from the COLLIDING task's
#                                     declared file_scope (the "foreign" side), matching
#                                     scopes_overlap()'s convention in task-lock.sh — first match,
#                                     not an exhaustive list.
#   collision_scope            string Present only when defer_reason == "file_scope_collision".
#                                     "in_batch" (the colliding task is itself one of this
#                                     invocation's candidate arguments) or "cross_batch" (it is
#                                     not).
#   reason                    string Present only when decision == "defer". Machine-templated
#                                     human-readable summary; never the sole carrier of any fact
#                                     already present as a structured field above.
#
# Precedence (D4): the self-modification check runs FIRST, before the collision scan, and
# SHORT-CIRCUITS it — a self-modifying candidate never also runs the collision scan, regardless
# of whether it is deferred (co-dispatch count > 1) or admitted solo (co-dispatch count == 1).
# Rationale, corrected for v3: the "strictly larger consequence" reason from v2 no longer holds —
# both defer flavors now share the same wave/cycle scope of consequence, so that is not why
# self-mod goes first. The surviving reason is narrower: self-mod is a pure single-candidate
# predicate (tests the candidate's own file_scope against a static list) that is cheaper to
# evaluate than the collision scan's set comparison against every other non-terminal task, and
# first-match determinism matches this script's existing "first hit wins, no exhaustive
# collection" convention.
#
# A1 (dependency-edge exemption asymmetry) — explained, not remedied: the collision dimension
# excludes from its comparison set any task connected to the candidate by a dependencies[] edge in
# EITHER direction (see the "Comparison set for the collision scan" paragraph below). The
# self-modification dimension applies no equivalent exemption, and this is deliberate, not an
# oversight. Once `--invocation-count` is same-cycle-scoped (D3 above), an edge-connected pair can
# NEVER share that count in the first place — Stage MT-3 step 3's eligibility rule in
# skills/skill-orchestrate/SKILL.md makes it structurally impossible for a `dependencies[]`-edge
# predecessor/successor pair to occupy the same `eligible_tasks` batch, because the successor is
# never eligible until the predecessor leaves the non-terminal set. An explicit dependency-edge
# exemption in the self-mod branch would therefore be unreachable dead code: the condition it
# would guard against (an edge-connected pair sharing a co-dispatch count) cannot occur. The
# asymmetry between the two dimensions is real but load-bearing only on the collision side, whose
# comparison set spans every non-terminal task in state — including ones far outside the current
# wave/cycle — where an edge-connected pair CAN and does otherwise collide.
#
# Degradation (D5): a missing, unreadable, or unparseable critical-path data file does NOT exit
# non-zero and does NOT disable the rest of admission — it sets self_modifying: null on every
# verdict, prints one loud line to stderr, and falls through to the ordinary collision scan
# unaffected. Silent disablement (returning false as if no candidate were ever self-modifying) is
# the one behavior this script must never produce for a degraded data file.
#
# Degenerate candidates (self_modifying still computed per the rule above; decision always
# resolves to a plain "admit" verdict with no collision fields, exactly as in v1):
#   - task_number absent from active_projects (unknown task) — self_modifying: false (no
#     file_scope to test) unless degraded, then null.
#   - task_number's status is terminal (completed, abandoned, expanded — case-insensitive) — the
#     candidate's own file_scope is still tested against the critical-path list (so a terminal
#     candidate that WOULD be self-modifying is still visible in the verdict), but a terminal
#     candidate is never deferred by this script — it will not be dispatched regardless.
#   - task_number's file_scope is null, missing, or an empty array — self_modifying: false
#     (trivially no scope to match) unless degraded, then null.
#
# Comparison set for the collision scan (per candidate, only reached when self_modifying is not
# true): every entry in active_projects whose status is NOT one of {completed, abandoned,
# expanded} (case-insensitive, so "PR READY" / "Completed" etc. are all handled), excluding the
# candidate itself, per rules/state-management.md's terminal-state list (Terminal states:
# [COMPLETED], [ABANDONED], [EXPANDED]) — every other status (not_started, researching,
# researched, planning, planned, implementing, partial, pr_ready/"PR READY", blocked) is
# compared. Any task connected to the candidate by a dependencies[] edge in EITHER direction
# (candidate depends on it, or it depends on candidate) is excluded from the comparison set
# entirely — an explicit dependency edge already serializes that pair.
#
# Deferral-direction rule for file_scope_collision (this is the load-bearing semantic, read
# carefully):
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
# collection of all collisions is attempted or reported. The self-modification check is likewise
# first-match: the FIRST critical-path entry (in the data file's declared order, expanded across
# scope_roots) that overlaps any of the candidate's own file_scope entries wins.
#
# Why this check is blocking, not advisory: the criterion imported for the blocking-vs-advisory
# decision is "computable from on-disk state alone, and the harm of skipping it is silent and
# hard to detect later." A cross-batch file_scope collision satisfies both halves — it requires
# nothing but a read of specs/state.json, and if skipped, two sessions can concurrently edit the
# same files with no lock contention (the colliding task holds no lock; it simply is not running)
# and no visible symptom until a merge conflict or silently overwritten edit turns up much later.
# That is precisely the profile the imported criterion assigns to "blocking." The self-modifying
# check satisfies the same profile: it is computable from the candidate's own on-disk file_scope
# alone, and the harm of skipping it — an unverifiable orchestrator-machinery fix bundled into a
# multi-task batch commit — is silent and hard to attribute later. A later maintainer who reads
# the general literature on false positives from coarse directory-prefix scope declarations and
# is tempted to relax either check to advisory should re-derive the criterion above first — the
# false-positive cost here is a deferred task, not silent data loss, so the two are not comparable
# and the advisory relaxation is not warranted by that literature alone.
#
# Exit codes:
#   0 - verdicts were emitted successfully on stdout, REGARDLESS of how many are "defer".
#       Verdicts are data, not errors: this script never exits non-zero merely because a
#       candidate was deferred, and it never writes to state.json (pure predicate, read-only).
#   2 - usage error (zero <task_number> arguments, any argument that is not a non-negative
#       integer, or a non-integer --invocation-count value), or state unavailable (jq missing, or
#       STATE_FILE missing/unparseable). Nothing is printed on stdout in either case; a single
#       loud line naming the reason goes to stderr.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
CRITICAL_PATHS_FILE="$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json"

# --- argument parsing: --invocation-count <N> (D3) ahead of positional task_number validation ---
invocation_count_arg=""
task_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --invocation-count)
      invocation_count_arg="${2:-}"
      shift 2 2>/dev/null || shift
      ;;
    --invocation-count=*)
      invocation_count_arg="${1#--invocation-count=}"
      shift
      ;;
    *)
      task_args+=("$1")
      shift
      ;;
  esac
done

if [ -n "$invocation_count_arg" ]; then
  case "$invocation_count_arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-batch-admit.sh: '--invocation-count $invocation_count_arg' is not a non-negative integer." >&2
      exit 2
      ;;
  esac
fi

# --- usage validation: zero positional args, or any non-integer positional arg, is a usage error ---
if [ "${#task_args[@]}" -eq 0 ]; then
  echo "ERROR: orchestrate-batch-admit.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "${task_args[@]}"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-batch-admit.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if [ -z "$invocation_count_arg" ]; then
  invocation_count_arg=${#task_args[@]}
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-batch-admit.sh: jq is not available; cannot evaluate admission." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-batch-admit.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

# --- load and expand the critical-path data file (D5: degrade visibly, never silently) ---
degraded="false"
critical_expanded_json='[]'
if [ ! -f "$CRITICAL_PATHS_FILE" ]; then
  echo "WARNING: orchestrate-batch-admit.sh: critical-path data file not found at $CRITICAL_PATHS_FILE; self-modification check DEGRADED (self_modifying will be null on every verdict)." >&2
  degraded="true"
else
  critical_raw_json=$(jq -c '.' "$CRITICAL_PATHS_FILE" 2>/dev/null)
  if [ -z "$critical_raw_json" ] || [ "$critical_raw_json" = "null" ]; then
    echo "WARNING: orchestrate-batch-admit.sh: critical-path data file at $CRITICAL_PATHS_FILE is unparseable; self-modification check DEGRADED (self_modifying will be null on every verdict)." >&2
    degraded="true"
  else
    critical_expanded_json=$(jq -c '
      (.scope_roots // []) as $roots |
      (.critical_paths // []) as $paths |
      [ $roots[] as $r | $paths[] as $p | {path: ($r + "/" + $p.path), label: $p.label} ]
    ' <<<"$critical_raw_json" 2>/dev/null)
    if [ -z "$critical_expanded_json" ]; then
      echo "WARNING: orchestrate-batch-admit.sh: critical-path data file at $CRITICAL_PATHS_FILE failed to expand (unexpected shape); self-modification check DEGRADED (self_modifying will be null on every verdict)." >&2
      degraded="true"
      critical_expanded_json='[]'
    fi
  fi
fi

# Build the candidates JSON array (preserves input order, including duplicates if given).
candidates_json="[$(printf '%s\n' "${task_args[@]}" | paste -sd, -)]"

# Single read of STATE_FILE via --slurpfile, feeding one jq program that computes every
# candidate's verdict and prints NDJSON in input order. No second read, no wildcard expansion,
# and no repo-wide filesystem walk of any kind.
verdicts=$(jq -n -c \
  --argjson candidates "$candidates_json" \
  --slurpfile state_arr "$STATE_FILE" \
  --argjson critical_expanded "$critical_expanded_json" \
  --argjson degraded "$degraded" \
  --argjson invocation_count "$invocation_count_arg" \
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

  # def self_mod_match: further application of the SAME overlap predicate (D of
  # file-footprint-overlap.md) — candidate own file_scope vs. a static declared critical-path
  # list, rather than vs. another task file_scope. Returns the first matching {path, label}
  # entry, in the critical-path data file declared order.
  def self_mod_match($cscope; $crit):
    def norm: rtrimstr("/");
    ($cscope // []) as $sa |
    [ $sa[] as $pa | $crit[] as $ce |
      ($pa|norm) as $na | ($ce.path|norm) as $nb |
      select($na == $nb or ($na | startswith($nb + "/")) or ($nb | startswith($na + "/"))) |
      $ce
    ] | first;
    # NOTE: deliberately `first` (never `first // empty`) — unlike scopes_overlap_first below,
    # the result of this def is bound via `as $sm_hit |` OUTSIDE any array comprehension. An
    # `empty` result there would make the ENTIRE per-candidate pipeline produce zero output
    # (the `as` construct binds by iterating its generator; a generator that yields nothing
    # means the downstream pipe never runs at all), silently dropping that candidate verdict
    # from stdout. Returning `null` on no-match instead lets `$sm_hit != null` downstream
    # evaluate to `false` exactly once, as intended.

  def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");

  ($state_arr[0].active_projects // []) as $all |
  $candidates as $cands |
  $critical_expanded as $crit |
  $degraded as $is_degraded |
  $invocation_count as $inv_count |

  $cands[] as $c |
  ([$all[] | select(.project_number == $c)] | first) as $entry |

  if ($entry == null) then
    {"$schema": "orchestrate-batch-admit-v3", task_number: $c, decision: "admit",
     self_modifying: (if $is_degraded then null else false end)}
  elif (($entry.status // "") | is_terminal) then
    {"$schema": "orchestrate-batch-admit-v3", task_number: $c, decision: "admit",
     self_modifying: (if $is_degraded then null else (self_mod_match($entry.file_scope; $crit) != null) end)}
  elif (($entry.file_scope // []) | length) == 0 then
    {"$schema": "orchestrate-batch-admit-v3", task_number: $c, decision: "admit",
     self_modifying: (if $is_degraded then null else false end)}
  else
    ($entry.dependencies // []) as $c_deps |
    ($entry.file_scope) as $c_scope |
    (if $is_degraded then null else self_mod_match($c_scope; $crit) end) as $sm_hit |
    (if $is_degraded then null else ($sm_hit != null) end) as $sm_flag |
    if ($sm_flag == true) then
      if ($inv_count > 1) then
        {
          "$schema": "orchestrate-batch-admit-v3",
          task_number: $c,
          decision: "defer",
          self_modifying: true,
          defer_reason: "self_modifying",
          critical_path: $sm_hit.path,
          critical_label: $sm_hit.label,
          reason: ("candidate #" + ($c|tostring) + " file_scope names orchestrator-critical path \"" + $sm_hit.path + "\" (" + $sm_hit.label + "); deferred out of this wave/cycle because it is co-dispatched alongside another candidate this cycle — it becomes eligible again once that co-dispatch clears, or pass --allow-self-modifying to override")
        }
      else
        {
          "$schema": "orchestrate-batch-admit-v3",
          task_number: $c,
          decision: "admit",
          self_modifying: true
        }
      end
    else
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
        {"$schema": "orchestrate-batch-admit-v3", task_number: $c, decision: "admit", self_modifying: $sm_flag}
      else
        {
          "$schema": "orchestrate-batch-admit-v3",
          task_number: $c,
          decision: "defer",
          self_modifying: $sm_flag,
          defer_reason: "file_scope_collision",
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
  end
  ' 2>&1)
jq_exit=$?

if [ "$jq_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-batch-admit.sh: failed to evaluate admission against $STATE_FILE (jq exit $jq_exit)." >&2
  exit 2
fi

printf '%s\n' "$verdicts"
exit 0
