#!/usr/bin/env bash
# orchestrate-triage-classify.sh — Shared handoff-triage classifier for /orchestrate.
#
# Purpose: single-task Stage 4 (`skills/skill-orchestrate/SKILL.md`) and multi-task Stage MT-4
# each decide, independently, what a task's current `status` routes to next (research, plan,
# implement, a human-escalation, a skip, or a terminal no-op). Before this script, that rule
# existed as two separately-maintained descriptions — the Stage 4 `partial` handler's prose and
# Stage MT-4's phase-grouping table — which genuinely disagree on one row (see below). This
# script is the "one code path" both the live dispatch and the read-only dry-run report
# (`orchestrate-dry-run-report.sh`) call, so the rule cannot drift into two silently-diverging
# copies again.
#
# Two-engine rationale: `/orchestrate` selects between the single-task engine and the multi-task
# (Stage MT-4) engine purely by `len(TASK_NUMBERS)` — see `commands/orchestrate.md` STAGE 0
# (`== 1` falls through to single-task CHECKPOINT 1; `> 1` goes to MULTI-TASK DISPATCH). A
# dry-run's entire value is being a *prediction of what the live path will actually do*, so the
# classifier must branch on that SAME `len(task_numbers)` test — never assume one engine's
# semantics for the other's invocation shape. The engine tables below are unified on every row
# except `blocked` (see the justification adjacent to that row): both engines now route `partial`
# with neither a continuation nor blockers to `implement`, and the engine argument still exists
# only because the two engines are selected by that same `len(task_numbers)` test the live path
# uses — not because the two engines' verdicts still diverge on this row.
#
# Usage:
#   orchestrate-triage-classify.sh <engine> <task_number> [<task_number> ...]
#
# where <engine> is exactly "single" or "mt".
#
# Forbidden calls (this script is read-only; it must never be the mechanism by which a dry-run or
# a classification-only caller mutates anything):
#   - task-lock.sh acquire (or heartbeat/release) — this script does not touch task locks at all
#   - update-task-status.sh
#   - generate-todo.sh
#   - skill-base.sh write functions (skill_preflight_update, skill_postflight_update, etc.)
#   - reconcile-task-status.sh (without --dry-run)
#   - the Agent or Skill tool, or anything that dispatches one
# This script reads ONLY specs/state.json and, for `partial`-status candidates, that candidate's
# own specs/{NNN}_{SLUG}/.orchestrator-handoff.json — never a plan, report, or summary file
# (Context Flatness Constraint).
#
# Precedence for `partial` status (transcribed from the single-task Stage 4 handler's explicit
# reads, which both engines share):
#   1. a continuation pointer is present, in EITHER accepted form -- nested
#      continuation_context.handoff_path non-null, OR flat top-level continuation_path non-null
#      (dual-form acceptance, matching validate-handoff.sh's already-shipped precedent; see the
#      "One Write Form, Deprecated-But-Accepted Read Form" subsection of docs/architecture/handoff-schema.md)              -> `implement`
#   2. else blockers is non-empty                                  -> `needs_human`
#   3. else (neither)                                               -> `implement` (both engines)
#
# Engine tables (verbatim transcription; this table, Stage 4's single-task state handlers, and
# Stage MT-4's "Phase grouping" table in skills/skill-orchestrate/SKILL.md MUST be changed
# together, never independently — this script is the executable source of truth those sections
# point back to):
#
#   | status                                  | mt group    | single group  |
#   |------------------------------------------|-------------|---------------|
#   | not_started                               | research    | research      |
#   | researched                                 | plan        | plan          |
#   | planned, implementing                      | implement   | implement     |
#   | partial + continuation                     | implement   | implement     |
#   | partial + blockers, no continuation         | needs_human | needs_human   |
#   | partial, neither                            | implement   | implement     |
#   | blocked                                     | skip        | needs_human   |
#   | researching (NEW -- was skip, folded into the old "researching, planning, unknown" row) | research | research |
#   | planning (NEW -- was skip, folded into the old "researching, planning, unknown" row)    | plan     | plan     |
#   | unknown (unrecognized/garbage status)       | skip        | skip          |
#   | terminal (completed/abandoned/expanded)      | terminal    | terminal      |
#
# `researching`/`planning` no longer route to `skip`: eligibility is no longer status-gated (a
# task is admitted/deferred by locks, dependencies[], and file_scope overlap downstream, never by
# an in-flight status string), so a task stranded in `researching`/`planning` by a dead prior
# session's stale lock must actually classify to a real dispatch group, not fall into the same
# bucket as a genuinely unrecognized status string. `unknown` (any status string that is none of
# the above) keeps the old `skip` behavior unchanged — this row split is scoping-only, not a
# widening of what "unknown" means.
#
# `blocked` is the one row that still diverges, and it is intentional: this is a DESIGN, not an
# undocumented assertion, because both engines independently corroborate it in their own handlers
# rather than only in this shared table — Stage 4's `#### State: blocked` handler contains no
# engine conditional at all (it always escalates to a human), and Stage MT-4's table independently
# folds `blocked` into its generic `skip` group. Two handlers, written separately, already agree
# with the classifier. Semantically: a solo invocation has no sibling task to make progress on, so
# escalation is the only meaningful action; a batch invocation skips the blocked task so its
# siblings can proceed. Converging `single` to `skip` here would introduce a new defect (a solo
# `/orchestrate` on a blocked task would do nothing at all), not fix one. This is unlike the
# now-removed `partial`-with-neither divergence, which was asserted only by this script and one
# prose paragraph citing an untraceable historical decision — nothing else in the system
# independently implemented it. The discriminator for any future audit of a table row: does the
# OTHER engine's own handler implement the divergence in its own code, or does only this shared
# table assert it? Independent implementation by both sides = design (keep it, documented, as
# here); bare assertion by one shared table = defect (converge it, as was done for `partial`).
#
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order (duplicates
# preserved verbatim if given). Verdict schema (pinned as "orchestrate-triage-v1"; field order is
# stable):
#
#   $schema           string  Literal "orchestrate-triage-v1".
#   task_number        int    The candidate task number, echoed back.
#   engine             string "single" or "mt", echoed back from the invocation argument.
#   status              string|null  The candidate's raw state.json status, or null if unknown.
#   group               string  One of: research, plan, implement, needs_human, skip, terminal, and
#                                 exit_partial (RESERVED — defined but not currently emitted by any
#                                 row as of this schema version; retained for schema stability and
#                                 available to a future row or engine that wants a distinct
#                                 exit-without-dispatch verdict; see orchestrate-dry-run-report.sh's
#                                 defensive exclusion arm, which still treats it as an exclusion if
#                                 it is ever emitted).
#   handoff_state       string  "absent" (partial status, no readable handoff file), "continuation"
#                                 (a continuation pointer present in either accepted form: nested
#                                 continuation_context.handoff_path or flat continuation_path),
#                                 "blockers" (blockers present, no continuation), "empty" (partial,
#                                 handoff present, neither), or "not_applicable" (status is not
#                                 partial — no handoff was read).
#   blocker_count       int    Length of the handoff's blockers array (0 when not applicable).
#   handoff_age_min     int|null  Handoff file mtime age in minutes; null when no handoff was read.
#   reason              string  Machine-templated human-readable summary; never the sole carrier
#                                 of a fact already present as a structured field above.
#
# Exit codes:
#   0 - verdicts were emitted on stdout, regardless of group (verdicts are data, not errors —
#       mirrors orchestrate-batch-admit.sh's convention).
#   2 - usage error (unknown engine, zero task numbers, or a non-integer task number), or state
#       unavailable (jq missing, or STATE_FILE missing/unparseable). Nothing is printed on
#       stdout in either case; a single loud line naming the reason goes to stderr.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

engine="${1:-}"
shift || true

if [ "$engine" != "single" ] && [ "$engine" != "mt" ]; then
  echo "ERROR: orchestrate-triage-classify.sh: <engine> must be 'single' or 'mt' (got '${engine:-<empty>}')." >&2
  exit 2
fi

if [ "$#" -eq 0 ]; then
  echo "ERROR: orchestrate-triage-classify.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "$@"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-triage-classify.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-triage-classify.sh: jq is not available; cannot evaluate triage." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-triage-classify.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

now_epoch() { date -u +%s; }

# Build the candidates JSON array (preserves input order, including duplicates if given).
candidates_json="[$(printf '%s\n' "$@" | paste -sd, -)]"

# Single read of STATE_FILE to resolve each candidate's status/project_name — needed up front so
# we know, per candidate, whether (and where) to read a handoff file below.
if lookup_json=$(jq -n -c --argjson candidates "$candidates_json" --slurpfile state_arr "$STATE_FILE" '
  ($state_arr[0].active_projects // []) as $all |
  [ $candidates[] as $c |
    ([$all[] | select(.project_number == $c)] | first) as $entry |
    { task_number: $c, status: ($entry.status // null), project_name: ($entry.project_name // null) }
  ]
' 2>&1); then
  lookup_exit=0
else
  lookup_exit=$?
fi
if [ "$lookup_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-triage-classify.sh: failed to evaluate state lookup against $STATE_FILE (jq exit $lookup_exit): $lookup_json" >&2
  exit 2
fi

# Per-partial-candidate handoff read (Context Flatness Constraint: only for status == "partial",
# and only .orchestrator-handoff.json — never a plan, report, or summary).
handoff_info_json="{}"
lookup_count=$(echo "$lookup_json" | jq 'length')
idx=0
while [ "$idx" -lt "$lookup_count" ]; do
  row=$(echo "$lookup_json" | jq -c ".[$idx]")
  idx=$((idx + 1))

  row_status=$(echo "$row" | jq -r '.status // ""')
  [ "$row_status" = "partial" ] || continue

  row_task=$(echo "$row" | jq -r '.task_number')
  row_project=$(echo "$row" | jq -r '.project_name // ""')

  if [ -z "$row_project" ]; then
    handoff_info_json=$(echo "$handoff_info_json" | jq --argjson t "$row_task" \
      '. + {($t|tostring): {state: "absent", blocker_count: 0, continuation: false, age_min: null}}')
    continue
  fi

  padded=$(printf "%03d" "$row_task")
  handoff_path="$PROJECT_ROOT/specs/${padded}_${row_project}/.orchestrator-handoff.json"

  if [ ! -f "$handoff_path" ]; then
    handoff_info_json=$(echo "$handoff_info_json" | jq --argjson t "$row_task" \
      '. + {($t|tostring): {state: "absent", blocker_count: 0, continuation: false, age_min: null}}')
    continue
  fi

  blocker_count=$(jq -r '(.blockers // []) | length' "$handoff_path" 2>/dev/null) || true
  case "$blocker_count" in ''|*[!0-9]*) blocker_count=0 ;; esac

  # Dual-form acceptance (Option B): a continuation pointer is present when EITHER the nested
  # `continuation_context.handoff_path` is non-null OR the flat top-level `continuation_path` is
  # non-null. This codifies the precedent validate-handoff.sh already ships (it accepts
  # continuation_path OR continuation_context as two equally valid forms) rather than inventing a
  # new contract. The nested form now has NO writer -- it is retained on the read side only for
  # backward compatibility with handoffs written before the nested-form writer was deleted; the
  # flat continuation_path form is the one canonical, writable form every live writer emits. Do
  # not re-narrow this to one form without updating every reader in lockstep (see
  # docs/architecture/handoff-schema.md's "One Write Form, Deprecated-But-Accepted Read Form" subsection).
  continuation_ok=$(jq -r '
    ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
    (.continuation_path // null) as $flat |
    if ($nested != null) or ($flat != null) then "true" else "false" end
  ' "$handoff_path" 2>/dev/null) || true
  [ "$continuation_ok" = "true" ] || continuation_ok="false"

  mtime=$(stat -c %Y "$handoff_path" 2>/dev/null || stat -f %m "$handoff_path" 2>/dev/null || echo "")
  if [ -n "$mtime" ]; then
    age_min=$(( ($(now_epoch) - mtime) / 60 ))
  else
    age_min="null"
  fi

  handoff_info_json=$(echo "$handoff_info_json" | jq \
    --argjson t "$row_task" --argjson bc "$blocker_count" --argjson cont "$continuation_ok" --argjson age "$age_min" \
    '. + {($t|tostring): {state: "present", blocker_count: $bc, continuation: $cont, age_min: $age}}')
done

if verdicts=$(jq -n -c \
  --arg engine "$engine" \
  --argjson candidates "$candidates_json" \
  --argjson handoff_info "$handoff_info_json" \
  --slurpfile state_arr "$STATE_FILE" \
  '
  def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");

  ($state_arr[0].active_projects // []) as $all |
  $candidates[] as $c |
  ([$all[] | select(.project_number == $c)] | first) as $entry |
  ($handoff_info[($c|tostring)] // null) as $hinfo |

  if ($entry == null) then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:null, group:"skip",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " not found in state.json; treated as skip")}
  else
  ($entry.status // "") as $status |
  if ($status|is_terminal) then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"terminal",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is terminal (" + $status + ")")}
  elif $status == "not_started" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"research",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is not_started; routes to research")}
  elif $status == "researched" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"plan",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is researched; routes to plan")}
  elif ($status == "planned" or $status == "implementing") then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"implement",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is " + $status + "; routes to implement")}
  elif $status == "researching" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"research",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is researching (in-flight, possibly stranded by a dead prior session); routes to research")}
  elif $status == "planning" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"plan",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is planning (in-flight, possibly stranded by a dead prior session); routes to plan")}
  elif $status == "partial" then
    (($hinfo.state // "absent")) as $hstate |
    (($hinfo.blocker_count // 0)) as $bc |
    (($hinfo.continuation // false)) as $cont |
    (($hinfo.age_min // null)) as $age |
    if $cont then
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"implement",
       handoff_state:"continuation", blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is partial with a valid continuation pointer; routes to implement")}
    elif ($bc > 0) then
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"needs_human",
       handoff_state:"blockers", blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is partial with " + ($bc|tostring) + " unresolved blocker(s) and no continuation; needs human")}
    else
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"implement",
       handoff_state:(if $hstate == "absent" then "absent" else "empty" end), blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is partial with neither continuation nor blockers; routes to implement")}
    end
  elif $status == "blocked" then
    ((if $engine == "mt" then "skip" else "needs_human" end)) as $grp |
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:$grp,
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is blocked; " + (if $engine == "mt" then "mt skips" else "single needs human" end))}
  else
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"skip",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " status \"" + $status + "\" is transitional/unknown; skip")}
  end
  end
  ' 2>&1); then
  verdicts_exit=0
else
  verdicts_exit=$?
fi

if [ "$verdicts_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-triage-classify.sh: failed to evaluate triage against $STATE_FILE (jq exit $verdicts_exit): $verdicts" >&2
  exit 2
fi

printf '%s\n' "$verdicts"
exit 0
