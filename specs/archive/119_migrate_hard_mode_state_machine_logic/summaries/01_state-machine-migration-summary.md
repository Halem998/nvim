# Implementation Summary: Task #119

- **Task**: 119 - Migrate hard-mode state-machine logic (H1 phase-per-cycle, H5/H6 churn/three-strikes, burnout breaker) into skill-orchestrate
- **Status**: [COMPLETED]
- **Started**: 2026-08-31T23:01:00Z
- **Completed**: 2026-08-31T23:45:00Z
- **Effort**: ~5 hours
- **Dependencies**: Task 117 (completed), Task 118 (completed)
- **Artifacts**: plans/01_state-machine-migration.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Ported the four genuinely stateful hard-mode residues from
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` into
`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` as `if [ "$hard_mode" = "true" ]`
conditional branches: the Stage 2 conditional cycle budget and unified loop-guard schema, the
`loop-guard-staleness` detector and churn-state init, the Stage 3 burnout circuit-breaker gate
(new sub-step `3b-hard`), the Stage 4 H1 single-blocking-phase-per-cycle implement dispatch fork,
and the new Stage 5b churn detection (H6) / three-strikes divergence-audit dispatch (H5), with
Stage 5a Drift Inspection gated to base-mode-only as its mutually-exclusive counterpart. The
`-hard` engine is confirmed byte-identical to its pre-task state; the full test suite and all 7
downstream-scope tests/lints pass.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added Stage 1 H4-residue
  note; conditional `MAX_CYCLES` (13 vs 5) and unified loop-guard JSON schema (`hard_mode`,
  `burnout_signals_this_session`, `plan_version`, D3); hard-mode-gated `loop-guard-staleness`
  3-signal detector and `.orchestrator-churn-state.json` init/resume (Stage 2); burnout
  circuit-breaker gate as sub-step `3b-hard` (Stage 3, D2); the whole `#### State: planned or
  implementing` handler forked on `$hard_mode` (D5) into an H1 per-phase-dispatch branch and the
  unchanged base whole-plan branch; a trimmed `build_hard_mode_phase_mission()` helper (D6); new
  `### Stage 5b: Churn Detection (H6) and Three-Strikes Audit Dispatch (H5)` after Stage 5a and
  before Stage 6, defining `phases_completed_before`/`phases_completed_after` for the first time
  in either engine (D7) and gating Stage 5a plus its Stage 2 drift constants to base-mode-only;
  an acceptance-checklist note mapping each migrated behavior to its implementing stage.
- `.gitignore` — added coverage for `.stale-loop-guard-*.json`, `.stale-churn-state-*.json`, and
  `.exhausted-loop-guard-*.json` archive files (a pre-existing gap affecting both engines, closed
  per Phase 3's task list).

## Decisions

- D1: H4 adversarial verification gate is explicitly out of scope; recorded in-file as the one
  still-unmigrated residue.
- D2: No renumbering of Stage 3's `3a.`/`3b.`/`3c.` sub-steps; the burnout gate is inserted as
  `3b-hard.`.
- D3: One loop-guard JSON schema serves both modes, with forward-compatible `// false`/`// 0`/
  `// "none"` reads.
- D4: `loop-guard-staleness` stays strictly `$hard_mode`-gated; whether base mode should gain it
  unconditionally remains a separate, undecided question.
- D5: The whole `planned`/`implementing` handler body is forked, not threaded internally.
- D6: `build_hard_mode_phase_mission()` carries only the non-duplicated residue of the source
  engine's prompt-context helper; Stage 3.5's `hard_contracts_block` supplies the rest.
- D7: `phases_completed_before`/`phases_completed_after` are defined for the first time (neither
  engine set them before this migration); Stage 5b runs strictly after Stage 5's own
  `phases_completed` assignment to fix the source engine's stage-ordering gap.

## Plan Deviations

- Phase 5: the pre-dispatch marker/handoff crosscheck sentinel was named
  `marker-handoff-crosscheck-predispatch:begin`/`:end` rather than reusing the exact
  `marker-handoff-crosscheck:begin`/`:end` name already used by base Stage 5's own post-dispatch
  crosscheck, to avoid two same-named sentinel regions in one file. No test enforces a specific
  name; behavior is unaffected.
- Phase 6: the three-strikes audit-dispatch branch does NOT increment `cycle_count` a second time
  (unlike the source engine's own prose, which says "Increment cycle_count" there). Stage 5b runs
  strictly after Stage 5's own tail-end increment, which already charges the cycle exactly once;
  a second increment would double-charge the work-cycle budget. This is a direct consequence of
  D7's ordering fix.

## Verification

- Build: N/A (markdown/skill file)
- Tests: `run-all.sh` 57/57 on clean runs (one transient failure in a pre-existing,
  timing-sensitive lean build-guard mutation test did not reproduce — unrelated to this
  migration); all 7 downstream-scope tests/lints pass
  (`test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`,
  `test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`,
  `test-handoff-dispatch-identity.sh`, `test-resume-scan-nonconformance.sh`,
  `lint/lint-contract-compliance.sh`)
- Files verified: Yes — `skill-orchestrate-hard/SKILL.md` diffs to zero against the pre-task
  commit; task-reference lint reports 0 occurrences across 4 trees; no hand-edited file under
  `.claude/**` (sanctioned `deploy-headless.sh` used to refresh the deploy tree)

## Impacts

- `skill-orchestrate/SKILL.md` now serves both `/orchestrate` and `/orchestrate --hard` for every
  behavior except the H4 adversarial-verification gate, which downstream deletion work on the
  `-hard` file must still account for separately.
- `.orchestrator-churn-state.json` and its stale/exhausted archive variants now have gitignore
  coverage, closing a pre-existing gap.
- Downstream deletion of `skill-orchestrate-hard/SKILL.md` and retargeting of the 7
  downstream-scope tests/lints remain separate, not-yet-started work — this task only reproduces
  the behavior in the base engine and leaves the source file and its dedicated tests untouched.

## Follow-ups

- Downstream: retarget the 7 tests/lints currently asserting against `skill-orchestrate-hard/
  SKILL.md`, then delete that file — out of scope for this task.
- Downstream: migrate the H4 adversarial-verification gate (the `researched`-state handler and
  its `adversarial_verified` variable) if/when that residue is scoped as its own task.
- Pre-existing, unrelated to this migration (found during Phase 7 verification, not fixed here):
  `check-extension-docs.sh` flags two core scripts (`test-state-write-large-payload.sh`,
  `tests/test-roadmap-argv-ceiling.sh`) missing from `provides.scripts`, and a lean4 doc line-count
  drift; `validate-state.sh --deep` flags unknown `abandon_reason`/`blocks_note` fields on
  unrelated task numbers (64, 106, 107, 109, 115).

## References

- `specs/119_migrate_hard_mode_state_machine_logic/plans/01_state-machine-migration.md`
- `specs/119_migrate_hard_mode_state_machine_logic/reports/01_state-machine-migration-design.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (read-only source)
