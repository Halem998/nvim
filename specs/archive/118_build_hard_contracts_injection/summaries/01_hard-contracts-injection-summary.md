# Implementation Summary: Task #118

- **Task**: 118 - Build hard_contracts manifest key and contract-text injection at dispatch-prep time
- **Status**: [COMPLETED]
- **Started**: 2026-08-31T00:00:00Z
- **Completed**: 2026-08-31T02:15:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: Task 117 (Stage 3.5 Dispatch Prep) — landed, confirmed by research
- **Artifacts**: plans/01_hard-contracts-injection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Centralized hard-mode contract text so a `--hard` orchestrate dispatch injects the ordered
`context/contracts/*.md` reference block into its sub-agent prompt from one place —
`skill-orchestrate/SKILL.md`'s Stage 3.5 Dispatch Prep — rather than from seven separate `-hard`
skill/agent files. All 6 plan phases (4 dependency waves: [1,4] -> [2,5] -> [3] -> [6]) are
complete; Phase 6 closed `[COMPLETED WITH EXCLUSIONS]` for two audit tasks that require a
redeploy the orchestrator dispatch explicitly reserved for itself.

## What Changed

- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — added
  `routing_lookup_flat(block, task_type)`, a sibling to `routing_lookup()` for one-level
  `{task_type: [...]}` manifest blocks (never a wrapper over the two-level ladder), plus a header
  usage line.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — derived `hard_mode` once at
  Stage 1 and Stage MT-1; added a "Hard-mode contract injection" subsection to Stage 3.5
  producing a 4th output, `hard_contracts_block` (fixed per-phase contract lists, extension
  override/additive resolution via `routing_lookup_flat`, `<hard-mode-contracts>` tag build);
  threaded `hard_contracts_block` through all 10 dispatch-site pointer lines (7 single-task, 3
  multi-task) as the 4th appended, empty-skipped output.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added a `warn()` helper (increments
  `CHECKS`, never `FAILURES`) and `gate16`, which warns (non-blocking) on any extension manifest
  still declaring `routing_hard`/`routing_agents_hard`, pointing at the migration path; updated
  the header gate-range comment to `gate0 through gate16`.
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` — renamed "The Four
  Blocks" to "The Five Blocks", added the `hard_contracts` block to the table, and added a new
  "The `hard_contracts` Block (One-Level Shape)" section documenting its shape, the `replace:`
  entry form, an example, and its consumer.
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — added one cross-reference
  line in Related Files pointing at the schema doc's `hard_contracts` coverage.

## Decisions

- Followed the plan's Decision 4 verbatim: the `verify-deploy.sh` warning uses "being replaced /
  migrate to `hard_contracts`" framing, never "no longer consulted" (confirmed absent via grep).
- Followed Decision 5: `routing_lookup_flat()` is implemented as a full sibling ladder (its own
  4-step precedence, its own doc comment explaining the one-level/two-level shape mismatch),
  never a wrapper over `routing_lookup()` with a fabricated `op` key.
- Followed Decision 6's grep-count correction: Phase 3's precondition gate re-ran the exact three
  greps and confirmed 10/7/3 before editing (the corrected counts, not the report's original
  10/10/10 claim).

## Plan Deviations

- **Phase 6, task (e)** ("Re-run the deploy verifier: exactly 3 `gate16` findings, exit code 0")
  skipped: requires redeploying the source store to `.claude/`, which the orchestrator dispatch
  explicitly prohibited ("Do NOT run deploy-headless.sh yourself — the orchestrator owns the
  redeploy checkpoint"). Verified `gate16`'s correctness by other means instead (see Verification
  below). Phase 6 closed `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned Exclusions record.
- **Phase 6, final task** ("Deploy the source store to `.claude/` and re-run the verifier")
  skipped for the same reason.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `lint-routing-wiring.sh` (323/323 checks) and `test-routing-resolution.sh`
  (19/19 asserts) both pass unmodified; `lint-agent-contracts.sh` (106/106),
  `lint-contract-compliance.sh` (24/24), and the deployed `check-task-references.sh` (0
  unexempted occurrences) all pass with 0 failures.
- Files verified: Yes — `git diff --stat` against the pre-implementation commit shows exactly
  the 5 files named across Phases 1-5 and nothing else; the 7 `-hard` skill/agent files are
  confirmed untouched.
- `routing_lookup_flat()`: verified via `bash -n`, a scratch 3-extension fixture (exact-match,
  compound-base, and core-exact resolution all hit correctly), and a miss against the current
  tree (`_ROUTE_LAST_VIA=miss`).
- Stage 3.5 hard-mode injection: the extracted bash logic was executed standalone for all three
  phases (`research`/`plan`/`implement`), producing exactly the documented ordered
  `<hard-mode-contracts>` block in each case; the `replace:`/additive extension-override logic
  was verified against a scratch manifest (basename substitution in place, additive append at
  the end); the `hard_mode=false` default path was confirmed to produce an empty
  `hard_contracts_block` with the other three outputs' order/skip-empty behavior unaffected.
- `gate16`: verified via an isolated 4-extension scratch fixture (core/cslib/lean declaring, one
  not) producing exactly 3 `[WARN]` lines with `CHECKS=3`/`FAILURES=0`, and via a live run of the
  edited `verify-deploy.sh` against the current (partially-deployed) `.claude/` tree, which
  produced 1 `gate16` WARN (for `core`, the only one of the 3 source-store declarers currently
  deployed) and confirmed `gate16` contributed 0 to `FAILURES` — the run's overall FAIL came from
  unrelated pre-existing findings (gate10 state-schema, gate3 lean index) and from this task's
  own not-yet-redeployed source/deploy drift (gate3/gate5), both expected until the orchestrator's
  own redeploy checkpoint runs.
- `EFFORT_FLAG` -> `hard_mode` trace: confirmed `EFFORT_FLAG` defaults `""` in
  `parse-command-args.sh`, is set to `"hard"` only by `--hard`, is threaded through
  `commands/orchestrate.md` to both single- and multi-task dispatch contexts, and `hard_mode`
  derives strictly from `effort_flag == "hard"` in Stage 1/MT-1.

## Impacts

- `--hard` orchestrate dispatches now carry a `<hard-mode-contracts>` block in their prompt,
  reducing the seven separate `-hard` skill/agent files' own duplicated contract-loading
  instructions to a single Stage 3.5 injection point (this task is additive only; those seven
  files are unchanged and still function independently until a later task removes the
  duplication).
- Any extension can now declare a `hard_contracts` manifest key to add or replace per-task-type
  contract entries; none does yet.
- `verify-deploy.sh` now non-blockingly flags any extension still declaring
  `routing_hard`/`routing_agents_hard`, steering future extension authors toward the new key
  without breaking existing behavior.

## Follow-ups

- Phase 6's two excluded audit tasks (deploy verifier re-run with exactly 3 `gate16` findings;
  deploying the source store) should be completed by the orchestrator's own redeploy checkpoint
  immediately following this dispatch — `gate16`'s correctness is already established by this
  task's own isolated verification, so this is confirmation, not new risk.
- The dependent follow-on task (referenced in this plan's Non-Goals) still needs to build the
  stateful hard-mode logic (churn/three-strikes counters, burnout circuit breaker, the
  single-blocking-phase-per-cycle implement dispatch limiter) that reads the `hard_mode` boolean
  this task introduced.
- Deleting the seven now-redundant `-hard` skill/agent files' own duplicated contract-loading
  instructions remains out of scope for this task (Non-Goals) and is a later link in the same
  chain.

## References

- `specs/118_build_hard_contracts_injection/plans/01_hard-contracts-injection.md`
- `specs/118_build_hard_contracts_injection/reports/01_hard-contracts-injection-design.md`
