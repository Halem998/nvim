# Implementation Summary: Task #968

- **Task**: 968 - corroborate_phase_counts_on_handoff_present_path
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T00:00:00Z
- **Completed**: 2026-07-29T00:00:00Z
- **Effort**: ~8 hours
- **Dependencies**: None
- **Artifacts**: plans/01_corroborate-phase-counts-handoff-present.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Extended the orchestrator's plan-heading corroboration mechanism — previously reachable only on
the missing/stale-handoff recovery path — to the handoff-present path, so a handoff reporting
`implemented` with omitted/null `phases_completed`/`phases_total` can still complete when an
independent artifact (the plan file's own phase headings) corroborates full closure. The
corroboration logic was extracted into one shared, directly-tested function,
`skill_corroborate_phase_counts()` in `scripts/skill-base.sh`, and wired into all three
orchestration engines (base single-task, base multi-task, hard single-task), replacing the three
pre-existing hand-copied recovery-path corroboration blocks with calls to the same function. The
completion-claim gate (`skill_gate_completion_claim`) was not modified.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — added `skill_corroborate_phase_counts()`
  immediately after `skill_gate_completion_claim()`: three-way branch (non-conforming headings /
  fully-closed / non-corroborating), deploy-tree-first/source-store-fallback library resolution,
  a log-only non-gating `validate-handoff.sh` diagnostic on an optional 4th `handoff_path`
  argument, and single-line `key=value` stdout output parsed via `read` (never `eval`).
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` — new file, 8
  fixtures (A-H) covering the three verification-bar scenarios plus the DONE-alternation,
  single-bad-heading, D4-guard, missing-plan, and non-gating-diagnostic edge cases; 21 assertions,
  modeled on `test-phase-heading-patterns.sh`.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5's handoff-present
  `else` branch gained the new corroboration call (`dispatch_status = "implemented"` AND
  `phases_total -eq 0` trigger); Stage MT-4 step 2 gained the identical per-task mirror; the
  recovery-path blocks in Stage 5 and Stage MT-4 step 1 were migrated to call the shared function
  instead of the inline three-way branch; `## MUST NOT (Context Flatness Constraint)` now
  documents three reachable branches instead of two, and the previously-false "they do not relax
  item 2 anywhere else" closing sentence was rewritten to name all three.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical Stage 5
  wiring and recovery-path migration; `## Tool Constraints (Pure Dispatcher)` Read allowlist item
  3(c) widened to name all three bounded uses and the shared-function anchor.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — new
  `.orchestrator-handoff.json` section stating base-mode implement is a non-writer by design, with
  a defensive-case contract (real Stage-5a-derived integers, top-level placement, never `null`) if
  a handoff is ever written anyway.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — Handoff Writers section
  gained a note that `validate-handoff.sh` is now invoked as a log-only diagnostic from
  `skill_corroborate_phase_counts()`.
- `agent-system/extensions/core/manifest.json` — registered the new
  `tests/test-corroborate-phase-counts.sh` file under `provides.scripts` (discovered missing
  during Phase 8's scratch-deploy audit; without this entry the new test file could never reach a
  deployed `.claude/` tree).

## Decisions

- D1-D5 from the plan were followed as stated: Option A (handoff-present corroboration) plus C
  (mirror across all three engines) as the core fix; Option B re-scoped to a log-only
  `validate-handoff.sh` diagnostic and a producer-side agent-contract section.
- D2: the function lives in `scripts/skill-base.sh` (not a new script file), avoiding the
  documented deploy-mechanism gap for already-loaded extensions.
- D3: the new trigger is `phases_total -eq 0` alone (not the recovery path's both-zero
  `PHASES_ZERO_ON_SUCCESS` signature), matching the gate's own Case 3 precondition exactly.
- D4: structurally verified — every caller of `skill_corroborate_phase_counts` only invokes it
  when `phases_total` is already 0, so `skill_gate_completion_claim`'s Case 1 (accounting present
  and incomplete) stays unreachable from any corroboration call site.
- Banner-shape convergence (deliberate, recorded in-file at each migrated call site): the
  pre-migration recovery-path banners differed subtly per engine (hard mode appended
  `[hard-orchestrate]` directly onto the banner; multi-task capitalized `Task #`). The shared
  function emits one banner shape everywhere; the bare `UNVERIFIED PHASES CORROBORATED` token
  still greps identically, and per-engine identity is still visible on every other log line via
  the `log_prefix` argument.

## Plan Deviations

- None (implementation followed plan). One in-scope addendum was made during Phase 8's audit: the
  new test file was registered in `manifest.json`'s `provides.scripts` array — an omission from
  Phase 3 that Phase 8's scratch-deploy verification caught before it could reach a real deploy.

## Verification

- Build: N/A (bash/markdown; `bash -n` used instead)
- Tests: Passed — `test-corroborate-phase-counts.sh` (21/21), `test-phase-heading-patterns.sh`
  (35/35), `test-orchestrate-triage-classify.sh` (9/9), all exiting 0 in a scratch-deployed tree.
- Files verified: Yes

### Verification-bar evidence

1. Handoff `implemented`, null phase counts, plan fully closed -> ALLOWED with
   `[UNVERIFIED PHASES CORROBORATED]` banner: Fixture A in the new test suite; also confirmed via
   manual `skill_corroborate_phase_counts` + `skill_gate_completion_claim` invocation (rc=0,
   banner present in stderr).
2. Same, but plan partially closed -> REFUSED: Fixture B (rc=1, gate refuses).
3. Plan has zero conforming phase headings -> REFUSED, non-conforming warning emitted: Fixture C
   (`NON-CONFORMING PHASE HEADING` present in stderr, gate refuses).
4. `phases_total > 0` and incomplete -> REFUSED regardless of `plan_markers_verified`: Fixture F
   (D4 guard), gate refuses even when passed `plan_markers_verified="true"` directly.
5. `bash -n`: every fenced bash block in both `SKILL.md` files was extracted and checked, both in
   the source store and in a freshly-deployed scratch git worktree — 78 blocks total (52 in
   `skill-orchestrate`, 26 in `skill-orchestrate-hard`). 9 blocks (1 in `skill-orchestrate`, 8 in
   `skill-orchestrate-hard`) fail `bash -n` because they contain pre-existing, non-bash
   "EXIT (partial)"/"EXIT (success...)" pseudocode-diagram lines embedded in otherwise-bash
   fences; confirmed byte-identical in failure signature against the pre-task HEAD (only line
   numbers shifted by this task's insertions), so none were introduced here. Every block this
   task added or edited was additionally isolated and checked standalone: clean in every case.
6. Engine agreement: `grep -rn "skill_corroborate_phase_counts"` across all three engines shows 6
   call sites (2 per engine: recovery-path with no 4th argument, handoff-present with the current
   handoff path as the 4th argument), each gated by the same precondition shape within its own
   category (recovery-path: `evidence_suspect=true && evidence_reason=PHASES_ZERO_ON_SUCCESS &&
   dispatch_status=implemented`; handoff-present: `dispatch_status=implemented &&
   phases_total -eq 0`). No undocumented divergence remains; the only differences are the
   `log_prefix` argument and each engine's own established variable names
   (`$task_number`/`$TASK_DIR` vs `$task_num`/`$task_dir`).

## Impacts

- A handoff writer that omits `phases_completed`/`phases_total` on an `implemented` claim (the
  originally observed defect) can now have that claim corroborated against the plan file instead
  of being unconditionally refused, provided the plan is genuinely fully closed.
- `validate-handoff.sh` (previously dead code) now runs as a log-only diagnostic whenever
  corroboration is attempted against a handoff, surfacing producer-side schema defects without
  gating completion on them.
- The three orchestration engines now share exactly one implementation of this logic, closing the
  drift surface the plan's D2 decision targeted.

## Follow-ups

- Neither `neovim-implementation-agent`, `nix-implementation-agent`, nor
  `email-implementation-agent` carry the `.orchestrator-handoff.json` non-writer contract added to
  `general-implementation-agent.md` here — a pre-existing, separately-scoped gap, not addressed by
  this task.
- Discovered during Phase 8 (out of scope for this task, recorded for a future task): a
  fresh/first-time headless deploy of the `core` extension via `deploy-headless.sh` does not
  populate `scripts/lib/*.sh` or `scripts/tests/*.sh` in a single pass, and separately drops a
  further ~90 already-declared `provides.scripts` entries (mostly `literature-*` scripts) even
  though they are correctly registered in `manifest.json`. Reproduced identically against the
  pre-task HEAD commit in an isolated control worktree, confirming this is pre-existing and
  unrelated to this task's changes. Worked around for this task's own Phase 8 verification by
  manually supplementing the scratch-deployed tree with the missing subdirectory files sourced
  directly from the (already-correct) source store.

## References

- Plan: `specs/968_corroborate_phase_counts_on_handoff_present_path/plans/01_corroborate-phase-counts-handoff-present.md`
- Research: `specs/968_corroborate_phase_counts_on_handoff_present_path/reports/01_corroborate_phase_counts_handoff_present.md`
