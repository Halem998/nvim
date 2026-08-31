# Implementation Summary: Task #68

- **Task**: 68 - Make the /orchestrate blocked verdict discriminating: dispatch a task blocked on an in-batch predecessor instead of skipping it forever
- **Status**: [COMPLETED]
- **Started**: 2026-08-31T00:00:00Z
- **Completed**: 2026-08-31T03:35:00Z
- **Effort**: ~3.5 hours (agent time)
- **Dependencies**: None
- **Artifacts**: plans/01_discriminating-blocked-classifier-row.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Replaced the multi-task `/orchestrate` classifier's unconditional `blocked` -> `skip` (mt) /
`needs_human` (single) verdict with a six-branch discriminating arm, so a task blocked purely on
an in-batch predecessor that the same batch will complete becomes dispatchable instead of being
re-skipped every cycle until `MAX_CYCLES_MT` is exhausted. Discharge (dependencies all
`"completed"`, no handoff blockers) routes both engines via the candidate's `previous_status`
through the classifier's existing status-routing logic; every non-discharged sub-case preserves
today's `skip`/`needs_human` divergence with a specific, named reason. Propagated the changed
premise through every co-maintained table, justification paragraph, fixture suite, and
architecture doc across 8 phases.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — replaced the
  unconditional `blocked` jq arm with a 6-branch discriminating form (empty deps / dependency
  abandoned-or-expanded / dependency outstanding / handoff blockers / previous_status missing or
  unrecognized / discharged); widened the per-candidate handoff-read gate from `partial`-only to
  also cover `blocked`; emits real `handoff_state`/`blocker_count` for blocked candidates instead
  of hardcoded values; rewrote the header verdict table (5 discriminated rows), justification
  paragraph, and `handoff_state` schema field docs.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` — replaced the
  retired `fixture_blocked` divergence pair and its "do NOT fix this" comment with six
  discriminated sub-case fixtures (12 assertions), each asserting both `group` and
  `handoff_state`; the discharged fixture's dependency is deliberately never passed as a
  classifier argument, proving the state.json-lookup mechanism rather than candidate-list
  membership.
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — threads the classifier's
  own `.reason` field into `t_skip_reason` for `blocked`-status candidates, replacing the generic
  templated form for that status only.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4's phase-grouping
  table split into discriminated rows; its justification paragraph rewritten to state the
  narrowed divergence; single-task Stage 4's `#### State: blocked` handler now invokes the
  classifier directly and dispatches a discharged verdict identically to the corresponding phase
  handler; the `partial` handler's cross-reference sentence and Stage 6's opening sentence
  updated to match.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — single-task `blocked`
  handler updated with the same discriminating read; explicit checked determination recorded that
  the Multi-Task Mode "Same as base" pointer needs no further edit.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — `blocked` state
  row split into discharged/not-discharged; adjacent prose swept and confirmed unaffected.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — three new
  Gate Catalogue rows (blocked discharged, blocked not-discharged, and the folded-in pre-existing
  "Unmet predecessor" omission).
- `agent-system/extensions/core/index-entries.json` — `line_count` correction for
  `batch-orchestration-guardrails.md` (919 -> 922) after Phase 6's additions.

## Decisions

- Dependency status is resolved via a second `select(.project_number == $d)` against the
  already-slurped `$all` array, bound through `. as $d`, never via candidate-list (`$candidates`)
  membership — the CRITICAL DESIGN GUARD the plan states three times, verified by a fixture whose
  dependency is deliberately absent from the classifier's argument list.
- Empty `dependencies[]` is checked FIRST, before the all-completed test, so a vacuous `all` over
  an empty list never discharges by accident.
- Discharge requires literal `"completed"`, never the broader `is_terminal` set — a dependency
  stuck at `abandoned`/`expanded` gets its own loud `needs_human` branch instead of silently
  promoting a dependent whose precondition can never be met.
- No status-rewrite component was added: the stale `blocked` string is overwritten by the
  dispatched skill's own `skill_preflight_update`, the identical mechanism the shipped
  `researching`/`planning` convergence already relies on.

## Plan Deviations

- **Phase 3 Scope Hypothesis** (5 sub-cases / 10 assertions) altered to 6 sub-cases / 12
  assertions: the Testing & Validation section explicitly requires a sixth "discharged but
  previous_status missing" case beyond the plan's own five-sub-case estimate.
- **Phase 4** found and fixed a sixth co-maintenance site beyond the five named ones: Stage 6
  Blocker Escalation's opening "Called when" sentence also asserted the stale unconditional
  premise, per that phase's own Scope Hypothesis contingency for handling any additional hit
  found by its post-edit grep sweep.
- **Phase 8** found and fixed an eighth file beyond the plan's seven: a `line_count` drift in
  `index-entries.json` caused by Phase 6's table additions, surfaced by `check-extension-docs.sh`
  during deploy verification; `file_scope` was widened deliberately via `state-write.sh`.

## Verification

- Build: N/A (bash/jq scripts and markdown)
- Tests: Passed — `test-orchestrate-triage-classify.sh` reports 36 passed, 0 failed (12 new
  discriminated-blocked assertions, all confirmed RED against the pre-fix classifier per
  mutation-check discipline)
- Files verified: Yes — `bash -n` clean on all changed scripts; deployed `.claude/scripts/`
  copies confirmed byte-identical to source and execute correctly (deploy-root-guard.sh /
  PROJECT_ROOT resolution hold)

## Impacts

- A dependency chain submitted as one multi-task `/orchestrate` batch now runs end-to-end without
  any hand-edited statuses — demonstrated with a synthetic 4-task chain mirroring the original
  live reproduction's shape.
- The dry-run report (`orchestrate-dry-run-report.sh`) now correctly predicts a discharged
  successor's admission (with its wave number) and surfaces the classifier's specific
  per-dependency reason for a still-skipped candidate, instead of a generic templated message.
- Two other repo-health gates (`specs/state.json` schema drift on unrelated tasks,
  `test-state-write-large-payload.sh`/`test-roadmap-argv-ceiling.sh` manifest-registration gaps)
  remain flagged by `verify-deploy.sh`; both confirmed pre-existing and out of this task's scope
  via `git log`.

## Follow-ups

- None required for this task's acceptance criteria. The two pre-existing, unrelated
  `verify-deploy.sh` failures noted above are candidates for a separate maintenance task.

## References

- Plan: `specs/068_discriminate_blocked_on_in_batch_predecessor/plans/01_discriminating-blocked-classifier-row.md`
- Research report: `specs/068_discriminate_blocked_on_in_batch_predecessor/reports/01_discriminate-blocked-classifier-row.md`
- Progress files: `specs/068_discriminate_blocked_on_in_batch_predecessor/progress/phase-{1..8}-progress.json`
