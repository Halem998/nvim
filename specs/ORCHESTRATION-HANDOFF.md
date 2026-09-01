# Orchestration Handoff

Written at the close of a multi-task `/orchestrate` batch so the loose ends survive a context clear.
Delete this file once the items below are resolved or refiled.

## Batch outcome

All four tasks completed: `fix_h4_adversarial_gate_matcher`,
`retarget_hard_mode_tests_to_engine_branch`, `fix_orchestrate_deploy_pending_annotation`,
`remove_refactor_orphans`. No failures, no deferrals, forward progress intact.

## Open follow-ups carried out of this batch

1. **Deployed-tree orphan (verified, actionable).**
   `.claude/context/reference/team-wave-helpers.md` still exists in the deployed tree although its
   source under `agent-system/extensions/core/` was deleted. A non-destructive
   `deploy-headless.sh` resync never deletes removed files, so it persists. This is the sole cause
   of two standing `verify-deploy.sh` gate13 findings (`ghost index row` + `orphan file`).
   Fix: `bash .claude/scripts/deploy-headless.sh --wipe` (destructive: snapshot -> rm -rf
   .claude -> regenerate -> restore `.syncprotect` paths). Deliberately NOT run automatically —
   `context/patterns/regeneration-is-manual-only.md` requires `--wipe` be invoked explicitly.

2. **`test-force-phases.sh` hygiene**, deferred by the orphan sweep's own plan-time Decisions
   table: undeclared in `manifest.json` `provides.scripts`, plus 4
   `lint-state-writer-boundary.sh` violations (hand-rolled `jq > tmp && mv` on `specs/state.json`
   at lines 261, 307, 317, 327). Not orphans; code work with its own verification profile.

3. **`context/patterns/multi-task-operations.md:662`** states "`/orchestrate` does not support the
   `--team` flag" without the "multi-task" qualifier that line 636 carries. Reads as false now
   that single-task `/orchestrate --team` is sanctioned. Sits inside the byte-identity-preserved
   range the sweep protected, so it was recorded rather than edited.

4. **Consumer repos are stale.** `deploy-headless.sh` never redeploys into a consumer. Each needs
   its own run: `Logos/Theory` (core, 82 artifacts), `Philosophy/Papers/PossibleWorlds`
   (core 129, filetypes 1, latex 2, lean 10, literature 27, present 1, typst 4). `cslib`,
   `Logos/Hardware`, and `PersonalWebsite` reported CANNOTVERIFY.

## Standing verify-deploy baseline

12 findings, all pre-existing and unrelated to this batch. Two redeploys ran during it
(30 -> 11, then 17 -> 12); **zero new findings introduced** by either. Residual set: two
`gate10` unknown-entry-field rows (`abandon_reason`, `blocks_note` on unrelated tasks), the four
`gate12` violations from item 2, the two `gate13` rows from item 1, `gate16` core still declaring
`routing_hard`/`routing_agents_hard`, and three `gate3` undeclared scripts.

## Recommended next orchestration

Critical path of the orchestrate-engine consolidation, in order:

- `delete_hard_mode_lifecycle_files` — now unblocked; the terminus the consolidation was built
  toward. Run the sweep's new `audit-deletion-references.sh` detector afterward, which exists
  precisely for this deletion's blast radius.
- `delete_lifecycle_commands_and_update_reference` — sits at `blocked` with all five dependencies
  completed and an empty `blockers` field. Stale block; confirm it is not silently skipped.
- Then `delete_base_lifecycle_skills` and `collapse_routing_ladder_to_routing_agents`, then
  `mode_gate_skill_orchestrate_multi_task_section`.

Direct follow-ons from this batch: `suppress_expected_handoff_absence_defect` (see Known defect
below), `audit_word_boundary_regex_portability` (the companion audit the H4 matcher fix names),
`orchestrate_multitask_phase_forcing_gap`, `fix_teammate_return_meta_write_conflict`.

## Known defect observed live this batch

A base-mode implement dispatch correctly writes no `.orchestrator-handoff.json`, and
`orchestrate-recover-outcome.sh` returns `recovered=false` for a `partial` status. A literal
reading of `skill-orchestrate`'s Stage MT-4 step 1 then charges that to `failed_tasks`, which
cascades dependents to `blocked`. It happened here and was overridden by hand: the dispatch was
conclusive (`.return-meta.json` reported `partial` with real work committed), so "failed" would
have been a false report. `suppress_expected_handoff_absence_defect` is the task that fixes this.
