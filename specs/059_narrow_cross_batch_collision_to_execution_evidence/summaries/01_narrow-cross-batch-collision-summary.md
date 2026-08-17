# Implementation Summary: Task #59

- **Task**: 59 - Gate cross-batch file_scope collisions on execution evidence, not non-terminal status
- **Status**: [COMPLETED]
- **Started**: 2026-08-17
- **Completed**: 2026-08-17
- **Effort**: ~4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_narrow-cross-batch-collision.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

`orchestrate-batch-admit.sh`'s cross-batch `file_scope_collision` dimension used to defer a
candidate against ANY non-terminal task whose `file_scope` overlapped it, regardless of whether
that colliding task was actually running. This made a broad-scope `not_started` task a permanent,
never-self-clearing blocker. This implementation narrows the `cross_batch` disjunct to require
execution evidence (status in `{researching, planning, implementing}`), converts a provably-idle
overlap into an `admit` verdict carrying a loud, always-present `idle_overlap_advisory` field,
bumps the verdict schema to `orchestrate-batch-admit-v5` across all pinning files, corrects a
self-refuting blocking rationale, adds the missing `cross_batch` row to the guardrails
Classification Table, closes the test-coverage gap for the idle-collider case with a negative
control proving the new tests actually exercise the fix, and — after a successful deploy — removes
the four workaround `dependencies[]` edges (tasks 53, 14, 17, 44) that existed solely to work
around this defect.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — added `is_in_flight` jq def;
  restructured the single-pass `$hit` comprehension into a materialized `$overlaps` list plus two
  derived selections (`$hit` for blocking, `$idle_overlap` for the suppressed idle case); appended
  a conditional `idle_overlap_advisory` fragment to all three post-scan verdicts (plain admit,
  `session_active` defer, `file_scope_collision` defer); bumped all 10 `$schema` literals (8 emit
  sites + 2 header-prose mentions) to `orchestrate-batch-admit-v5`; documented the new field in the
  header; rewrote the `cross_batch` deferral-direction bullet and the blocking-rationale paragraph
  to the evidence-gated argument.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — Version bumped to 5;
  all example verdicts and the `$schema` field row updated to v5 (including fixing a now-stale
  `not_started` cross_batch defer example to `implementing`); added the `idle_overlap_advisory`
  field row and a dedicated example verdict; retitled and rewrote "Why This Check Is Blocking, Not
  Advisory" to "Why This Check Is Evidence-Gated Between Blocking and Advisory"; narrowed the
  `cross_batch` prose in the Deferral-Direction Rule section; added a full `**v4 to v5**` Version
  History entry recording the discriminator-change accepted-behavior note and the consumers-not-
  updated residual.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — split the
  single File-scope overlap Classification Table row into an `in_batch` row (unchanged, still
  unconditionally BLOCKING) and a new `cross_batch` row (BLOCKING when in-flight, ADVISORY when
  idle); added a clarifying paragraph to "Batch-Size Scaling" distinguishing evidence-gating from
  batch-size-gating.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` — added a short
  consumer-facing clarification noting the comparison set and predicate are unchanged by v5; the
  algorithm/pseudocode sections are byte-identical.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — added cases 2.5 (idle admit
  + advisory), 2.6 (advisory-absent companion), 2.7 (in-flight status boundary loop over
  researching/planning/implementing); new fixture pair #842/#843 in a fresh `g25/` namespace;
  updated the case 3 schema-literal assertion to v5.
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — added case 12 (idle-collider
  convergence, mirroring case 9's two-pass shape with the pass-1 winner idle instead of
  in-flight) and case 13 (explicit `in_batch` bit-for-bit guard across cases 7/9/12); new fixture
  pair #605/#606 in a fresh `case_i/` namespace; corrected case 9's now-stale "defers
  unconditionally" comment.
- `specs/state.json` — removed the `dependencies[]` entries naming 59/60/61 from tasks 53, 14, 17,
  and 44 (the workaround edges); tasks 48 and 50 left untouched (their edges accompany a
  repo-wide `agent-system/extensions/` scope and are a legitimate final-integration dependency).
- `specs/TODO.md` — regenerated from the edited `state.json`.

## Decisions

- Implemented exactly per the plan's pre-settled design forks: nested `idle_overlap_advisory`
  object (not a flat triad), materialized `$overlaps` list with `$hit`/`$idle_overlap` both
  derived from it (no second overlap scan), and the guardrails Classification Table row carrying
  the corrected rationale.
- Factored the advisory-construction into a single `$idle_advisory_frag` variable appended via `+`
  to all three verdicts, rather than repeating the `if/else` three times — same output, less
  duplication.
- Phase 1's baseline grep found 8 emit-site literals in the script, not the 5 the plan's Scope
  Hypothesis guessed; Phase 3's verification was already dynamically grep-count-based so this
  required no phase-text change, only a corrected count in the progress notes.
- Chose the "add a clarification" path (not a Reasoned Exclusions record) for
  `file-footprint-overlap.md`, adding one bullet-scoped note to the batch-admission-level consumer
  description while leaving the algorithm/pseudocode sections byte-identical.

## Plan Deviations

- None (implementation followed plan). The only "deviation" was a scope-hypothesis count
  correction in Phase 1 (8 emit sites vs. the guessed 5), which the plan itself anticipated and
  which required no downstream phase-text change.

## Verification

- Build: N/A (bash/jq scripts, markdown docs)
- Tests: Passed — `test-conflict-predicate.sh` 35/0 (baseline 32/0, +3 new cases), 
  `test-four-tier-conflict.sh` 13/0 (baseline 11/0, +2 new cases)
- Negative control: the four new idle-collider positive cases (predicate 2.5, four-tier 12) were
  confirmed to FAIL against the pre-Phase-2 predicate (verified via a scratch-backed temporary
  swap of the working file to the pre-fix git blob, never a destructive git reset), then restored
  and re-verified green
- Files verified: Yes — `bash -n` clean on all three scripts; every example verdict in
  `batch-admit-schema.md` valid JSON; deployed `.claude/scripts/orchestrate-batch-admit.sh`
  confirmed emitting v5 after `deploy-headless.sh`; live smoke check against real
  `specs/state.json` for task 59 returned a v5-shaped verdict
- Full diff scope: confirmed via the union of all 7 task-59 commits' file lists — exactly the six
  declared `file_scope` files plus `specs/059_.../` artifacts, `specs/TODO.md`, and
  `specs/state.json`; no `.claude/**` path; none of the explicitly out-of-scope consumer files
  (`orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`, `skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md`, `scripts/lib/file-scope-overlap.sh`) were touched

## Impacts

- A candidate whose `file_scope` overlaps a genuinely idle (no execution evidence) out-of-batch
  task now admits instead of deferring forever, with the suppressed overlap surfaced loudly via
  `idle_overlap_advisory` rather than silently.
- `in_batch` collision behavior is completely unaffected — confirmed bit-for-bit via dedicated
  regression guards in both suites.
- Any `defer_reason`-branching consumer (`orchestrate-dry-run-report.sh`,
  `orchestrate-predispatch-review.sh`, `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`)
  is unaffected by this change — none was touched — but none of them yet surfaces
  `idle_overlap_advisory` to a human or a report either; this is a recorded residual, not a silent
  gap, and is explicitly out of this task's scope.

## Follow-ups

- Thread the `idle_overlap_advisory` field through the `defer_reason`-branching consumers named
  above so a human reviewing a batch dispatch or dry-run report actually sees the suppressed idle
  overlap. This is a separate, sibling task's declared scope (not created or renumbered by this
  implementation).
- An unrelated, pre-existing `specs/state.json` validation warning (an unrecognized `priority`
  field on task 53) was observed during Phase 7's final validation pass; confirmed present before
  this task's own edit via a backup diff, so it is out of this task's scope and left unaddressed.
- A foreign, unrelated commit (`bafefeb83`, "literature: make pyenv provisioning self-repairing")
  from a concurrent session landed in the shared repository history between this task's Phase 5
  and Phase 6 commits. Confirmed via `git log` and per-commit file-list inspection that it touches
  only `agent-system/extensions/literature/scripts/literature-pyenv-provision.sh` and is absent
  from every task-59 commit's own scoped file list — it does not affect this task's diff scope,
  and is reported here per the observation-duty contract rather than silently dismissed.

## References

- `specs/059_narrow_cross_batch_collision_to_execution_evidence/plans/01_narrow-cross-batch-collision.md`
- `specs/059_narrow_cross_batch_collision_to_execution_evidence/reports/01_narrow-cross-batch-collision.md`
- `specs/059_narrow_cross_batch_collision_to_execution_evidence/progress/phase-{1..7}-progress.json`
