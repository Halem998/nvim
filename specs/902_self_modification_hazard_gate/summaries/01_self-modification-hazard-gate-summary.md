# Implementation Summary: Task #902

**Completed**: 2026-07-25
**Duration**: single session, 5 phases

## Overview

Extended `/orchestrate`'s admission analysis with a `self_modifying` dimension: a candidate whose
`file_scope` intersects a declared set of nine orchestrator-critical paths is flagged, and —
whenever the invocation carries more than one validated candidate — that candidate (never a
sibling) is deferred out of the WHOLE invocation, so orchestrator-machinery work only ever runs
solo. The critical set is declared once as JSON data, consumed live by
`orchestrate-batch-admit.sh` and surfaced by `orchestrate-dry-run-report.sh`. All 5 planned phases
completed; all edits target `agent-system/extensions/core/**` per the plan's binding SOURCE-STORE
RULE — nothing under `.claude/**` was touched, and nothing is live until a human redeploys via
"Load Core".

## What Changed

- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — new; single
  declaration of the 9 critical paths, 3 scope roots (source-store, `.claude`, `.opencode`).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  "Self-Modification Hazard: The Fourth Admission Dimension" section (two-test rationale,
  inclusion/exclusion tables, deploy-manual analysis and three surviving hazards), classification
  row, extended "Three Existing Admission Layers" framing.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` — consumers entry
  noting the self-mod check as a further application of the same overlap predicate.
- `agent-system/extensions/core/context/reference/README.md` — contents row for the new data file.
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — `--invocation-count` flag;
  loads/expands the critical-paths data file; emits `self_modifying` (true/false/null) on every
  verdict; `defer_reason` discriminator (`self_modifying` | `file_scope_collision`); schema bumped
  to `orchestrate-batch-admit-v2`.
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — passes
  `--invocation-count`; branches on `defer_reason` before `collision_scope`; solo-admit Note;
  `self-modification: ran | SKIPPED (degraded: ...)` Checks-run line.
- `agent-system/extensions/core/commands/orchestrate.md` — MULTI-TASK DISPATCH Step 3: passes
  `--invocation-count`, adds the `self_modifying` exclusion branch with a distinct warning.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 initializes
  `deferred_self_modifying: []`; Stage MT-3 step 3 excludes it from eligibility (the convergence
  mechanism); steps 2/4 recognize it as intentional (not "stuck"); step 4.5 passes
  `--invocation-count` and populates the set; Stage MT-5 reports it distinctly and folds it into
  `exit_status` (non-empty set → `"partial"`, never silently `"completed"`).
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — full rewrite to v2,
  including a Version History section explaining why this was a version bump, not an additive
  field.
- `specs/902_self_modification_hazard_gate/fixtures/state-self-mod.json` — new, 11 fixture
  candidates (950-960).
- `specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh` — new, 14
  assertions, all passing.
- `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` — updated to v2 schema;
  tests 1/2 re-documented (see Plan Deviations).

## Decisions

- Self-modification check runs FIRST and short-circuits the collision scan (D4) — verified via a
  dedicated precedence fixture pair (957/958).
- `--invocation-count` threads the whole invocation's candidate count explicitly, since both live
  callers dispatch wave/cycle-sized subsets; defaults to positional-arg count for
  backward-compatibility.
- `deferred_self_modifying` is an invocation-scoped set in `mt_state_file`, excluded from
  eligibility every cycle — the mechanism that makes the exclusion converge instead of re-firing
  every cycle forever.
- Degradation (missing/unparseable critical-paths file) is always visible: `self_modifying: null`
  on every verdict, a loud stderr line, and a `SKIPPED (degraded: ...)` report line — never a
  silent `false`.

## Plan Deviations

- **Phase 2/3**: two implementation bugs found and fixed during manual scratch-tree verification
  (both are jq gotchas, not scope changes): `self_mod_match`'s `first // empty` tail silently
  dropped every non-self-modifying verdict from stdout (fixed to plain `first`); the dry-run
  report's degraded-detection used `.self_modifying // "null"`, which misreads a valid
  `self_modifying: false` as degraded because jq's `//` treats `false` as falsy (fixed to
  `jq -c '.self_modifying'`, no `//` fallback).
- **Phase 4**: two necessary correctness additions beyond the literal task list, both required
  for the convergence property the plan itself demands: Stage MT-3 steps 2/4 now recognize
  `deferred_self_modifying` as an intentional exclusion (not a "stuck" task); Stage MT-5's
  `exit_status` determination now treats a non-empty `deferred_self_modifying` set as `"partial"`
  even with zero `failed_tasks` (previously would have silently reported `"completed"` despite one
  task never being dispatched).
- **Phase 5** (substantial): `test-batch-admit.sh`'s fixture candidates 900/902/906/907 are real
  orchestrator-lifecycle tasks whose `file_scope` legitimately names orchestrator-critical files,
  so under the v2 gate they are genuinely `self_modifying: true`. Per D4 precedence this changes
  tests 1 and 2 IN MEANING (not just string literals): candidate 900 alone now admits solo
  (`self_modifying: true`) instead of deferring via its real cross-batch collision; candidates
  900+902 together now both defer via `self_modifying` instead of demonstrating the in-batch
  collision-direction rule. This is the new, correct, intended behavior — verified by actually
  running the v2 script against the frozen fixture, not predicted. In-batch-direction coverage
  for non-self-modifying candidates was restored via a new assertion (test 13) in the 902 suite.
  The live smoke check was softened from pinned decision/`collision_scope` values to
  schema-shape-only, since the specific real task it pinned (900) has independently reached
  `completed` status since the suite was first written.

## Verification

- Build: N/A (bash/jq scripts + markdown docs)
- Tests: all four suites green — `test-self-modifying-gate.sh` 14/14 (new),
  `test-batch-admit.sh` 8/8 (updated), `test-triage-classify.sh` 6/6 (unaffected),
  `test-dry-run-report.sh` 14/14 (unaffected)
- Files verified: yes — all 9 critical paths exist, `bash -n` clean on both modified scripts,
  `check-extension-docs.sh` reports no new failures (5 pre-existing FAILs are `.claude/` deploy
  drift unrelated to this task's edits)
- Real repository `.claude/` tree and `specs/state.json`: confirmed untouched by every test run

## Notes

- Nothing in this task is live until a human redeploys the core extension from the source store
  via `<leader>al` ("Load Core"), per the plan's binding SOURCE-STORE RULE.
- Two pre-existing files this task edited (`commands/orchestrate.md`,
  `skills/skill-orchestrate/SKILL.md`) and one new file
  (`scripts/orchestrate-dry-run-report.sh`) carried uncommitted changes from an unrelated prior
  session (tasks 900/901) at the start of this session; those changes are now bundled into this
  task's phase commits since the files needed to be tracked for this task's diffs to be
  meaningful. This is a pre-existing repository-hygiene condition, not introduced by this task.
- The open scope limitation flagged in the plan (this gate is `/orchestrate`-only; plain
  multi-task `/implement`/`/research`/`/plan` never call `orchestrate-batch-admit.sh`) and the
  batch-commit staging gap (an implementation agent's `modified_files` are not staged per-task in
  a multi-task `/orchestrate` commit) remain open, exactly as the plan scoped them — both flagged
  for a possible follow-up, neither fixed here.
