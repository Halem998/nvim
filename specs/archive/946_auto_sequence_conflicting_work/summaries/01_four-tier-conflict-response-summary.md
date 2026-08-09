# Implementation Summary: Task #946

- **Task**: 946 - Auto-sequence conflicting work instead of aborting or skipping
- **Status**: [COMPLETED]
- **Started**: 2026-07-28
- **Completed**: 2026-07-28
- **Effort**: ~9 hours (matches plan estimate)
- **Dependencies**: 945 (converged conflict-detection predicate — landed)
- **Artifacts**: plans/01_four-tier-conflict-response.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Installed the four-tier conflict-response ladder (auto-sequence, bounded retry, warn, ask) in
strict priority order across `task-lock.sh`, `command-gate-in.sh`, the three plain multi-task
commands, and the durable context documentation. All 8 plan phases completed (Phase 8 closed
`[COMPLETED WITH EXCLUSIONS]` for two pre-existing/expected-by-design non-blockers, see below). A
new isolated-temp-root suite (`test-four-tier-conflict.sh`, 11 cases) proves all four tiers plus
non-convergence termination as `partial`, and the highest-impact regression risk — same-session
re-entry never self-blocking — was verified with a dedicated wall-clock-bound test case.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — new `cmd_acquire_retry()` / `acquire-retry`
  subcommand (Tier 2, bounded wait-and-retry wrapping the UNMODIFIED `cmd_acquire`), new
  `TASK_LOCK_RETRY_BUDGET_MS`/`TASK_LOCK_RETRY_POLL_MS` constants, extended contract comments.
- `agent-system/extensions/core/scripts/command-gate-in.sh` — single-task gate now calls
  `acquire-retry` instead of plain `acquire`.
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — new isolated-temp-root suite
  (11 cases): Tier 2 resolving, Tier 3 exhaustion (all three ABORT variants, byte-identical to
  plain `acquire`), same-session re-entry (zero retry iterations), budget-bound, Tier 1 pass 1/2
  (convergent), non-convergence (bounded, `partial`-flavored), observation-log, bounded-scan.
- `agent-system/extensions/core/manifest.json` — registered the new test script.
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md` — Step 3 wired to
  `acquire-retry`; new bounded two-pass structure (Step 2.5 split by `defer_reason`/
  `collision_scope`, new Step 3.5 Second Pass, `second_pass_ledger` append-only observation log,
  `partial`-status non-convergence reporting); Tier-4 ask-flow reference wired into each file's
  single-task GATE IN Failure section.
- `agent-system/extensions/core/context/patterns/task-lock.md` — new "Four-Tier Conflict Response"
  ladder section, new "Tier 4: The Ask Flow" shared block (with "Deliberately Not Wired"
  subsection for `/orchestrate`/`/revise`/`/task`), `acquire-retry` contract documentation,
  corrected "sourced by five" → six command files (named, grep-verifiable), "Consumers (Six
  Distinct Wiring Paths)" heading/list update.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — corrected a
  stale claim that plain multi-task commands "never call `orchestrate-batch-admit.sh` at all";
  documented the new two-pass structure and its exact one-extra-pass bound; recorded two
  deliberate non-changes (Kahn's-algorithm pseudocode stays illustrative; `file_scope` overlap not
  added as a pre-computed wave-assignment input) with their costs.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — new "5a. Batch
  Admission Pre-Check and Bounded Second Pass (Tier 1)" section.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — consumer note that
  `collision_scope == "in_batch"` now has a second consumer (schema itself unchanged).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md` — cross-reference-only pointers to the new ladder section at
  their existing Stage MT-3 step 4.5 (or transcribed equivalent) sites; no behavioral change.

## Decisions

- The retry loop lives OUTSIDE `cmd_acquire`, never inside it — `cmd_acquire` holds the
  process-global `specs/.scope-lock` mutex for its entire body; `acquire-retry` calls the full,
  unmodified `cmd_acquire` fresh per attempt, so the mutex is acquired/released once per attempt
  and all three same-session exclusions re-run every attempt. This overrides the research report's
  stated recommendation on evidence the report did not have.
- `orchestrate-batch-admit.sh`'s collision predicate is a `state.json` STATUS check, not a lock
  check (it deliberately carries no held-lock scan). Consequently the plain multi-task Tier-1
  second pass genuinely converges only once the pass-1 winner's status goes terminal — natural for
  `/implement` (success sets `status: completed`), not for `/research`/`/plan` (whose termini are
  non-terminal). This is not a defect; it is exactly the non-convergence case the plan's own Risks
  table anticipated, and Phase 5's test suite proves both outcomes explicitly.
- Tier 4 (ask) is gated on `orchestrator_mode`, following the `AUTONOMOUS_GLOBAL` precedent in
  `context/patterns/lit-stage4a-flow.md`, and is deliberately NOT wired into `/orchestrate`
  (zero synchronous confirmation gates by design), `/revise`, or `/task` (not conflict-response
  entry points) — recorded as a decision, not an omission.

## Plan Deviations

- **Phase 8** closed `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`: `verify-deploy.sh`
  and `check-extension-docs.sh` report non-zero exit due to (a) expected deploy-tree drift — this
  task's edits are source-store-only per the binding source-store rule, and regenerating the
  deployed `.claude/` tree is documented as manual-only, outside this agent's authority to force —
  and (b) two pre-existing, unrelated `.pyc` cache-file findings in the `literature` extension that
  this task never touched. Full reasoning and evidence recorded in the plan's Phase 8 `#### Reasoned
  Exclusions` table. The task-reference lint gate specifically (the sub-check this task's own
  constraints care about) passes cleanly (`check-task-references.sh` exits 0).

## Verification

- Build: N/A (documentation + bash scripts, no build step)
- Tests: Passed — `test-four-tier-conflict.sh` 11/11; non-regression suites
  `test-conflict-predicate.sh` 23/23, `test-session-registry.sh` 10/10, `test-task-lock-reap.sh`
  6/6, `test-state-write-concurrency.sh` 4/4, `test-session-runtime-files.sh` 6/6 — all exit 0.
- Files verified: Yes — every phase's Scope Hypothesis was confirmed against `git status --short`
  before committing; no unexpected file left the declared set.

## Impacts

- Every `task-lock.sh acquire` call site on the single-task gate and multi-task dispatch paths now
  gets a bounded, seconds-scale retry before falling through to the pre-existing ABORT/warn text —
  transparent to existing callers (identical exit-code contract).
- Plain multi-task `/research`, `/plan`, `/implement` no longer permanently drop an `in_batch`
  `file_scope_collision` into `skipped_tasks`; they get one bounded extra pass, converging for
  `/implement` in the common case and reporting `partial` with a named diagnostic when it cannot.
- A future single-task `/research`, `/plan`, or `/implement` invocation whose lock is refused after
  the bounded retry now offers an interactive wait/skip/override choice instead of an unconditional
  ABORT, gated safely off under `orchestrator_mode: true`.

## Follow-ups

- None required by this task. The deploy-tree sync (regenerating `.claude/` from the source store)
  is a user-triggered action outside this task's scope — see Phase 8's Reasoned Exclusions.
- The two pre-existing `literature` extension `.pyc` doc-lint findings are unrelated to this task
  and were not investigated further.

## References

- `specs/946_auto_sequence_conflicting_work/plans/01_four-tier-conflict-response.md`
- `specs/946_auto_sequence_conflicting_work/reports/01_four-tier-conflict-response.md`
- `agent-system/extensions/core/context/patterns/task-lock.md` ("Four-Tier Conflict Response",
  "Tier 4: The Ask Flow")
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`
