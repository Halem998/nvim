# Orchestration Handoff

Written at the close of a multi-task `/orchestrate` batch so the loose ends survive a context clear.
Delete this file once the items below are resolved or refiled.

## Batch outcome

All four tasks completed: `fix_h4_adversarial_gate_matcher`,
`retarget_hard_mode_tests_to_engine_branch`, `fix_orchestrate_deploy_pending_annotation`,
`remove_refactor_orphans`. No failures, no deferrals, forward progress intact.

## Open follow-ups carried out of this batch

1. ~~Deployed-tree orphan~~ **RESOLVED.** `.claude/context/reference/team-wave-helpers.md`
   persisted in the deployed tree after its source was deleted (a non-destructive resync never
   removes deleted files). Cleared by `deploy-headless.sh --wipe`; both `gate13` findings are
   gone and that gate now passes.

2. **`test-force-phases.sh` hygiene**, deferred by the orphan sweep's own plan-time Decisions
   table: undeclared in `manifest.json` `provides.scripts`, plus 4
   `lint-state-writer-boundary.sh` violations (hand-rolled `jq > tmp && mv` on `specs/state.json`
   at lines 261, 307, 317, 327). Not orphans; code work with its own verification profile.

3. **`context/patterns/multi-task-operations.md:662`** states "`/orchestrate` does not support the
   `--team` flag" without the "multi-task" qualifier that line 636 carries. Reads as false now
   that single-task `/orchestrate --team` is sanctioned. Sits inside the byte-identity-preserved
   range the sweep protected, so it was recorded rather than edited.

4. **Consumer repos are stale.** `deploy-headless.sh` never redeploys into a consumer. Run
   `bash .claude/scripts/deploy-headless.sh` from inside each. Counts are artifacts behind, as of
   the post-wipe run:
   - `~/Philosophy/Papers/PossibleWorlds` — core 135, literature 27, lean 10, typst 4, latex 2,
     filetypes 1, present 1
   - `~/Projects/Logos/Theory` — core 88
   - `~/Projects/ModelChecker` — core 88
   - Reported CANNOTVERIFY (check directly): `~/.dotfiles` (core, memory, nix, nvim, python),
     `~/Projects/cslib`, `~/Projects/Logos/Hardware`, `~/Projects/PersonalWebsite`

## Standing verify-deploy baseline

**10 findings, 3 of 26 checks failing**, all pre-existing and unrelated to the batch. Measured
after `deploy-headless.sh --wipe`. Three redeploys ran across the session (30 -> 11, 17 -> 12,
12 -> 10); **zero new findings introduced** by any of them. The residual set is exactly:

- 2x `gate10` unknown entry fields in `specs/state.json` (`abandon_reason` on 7 tasks,
  `blocks_note` on 3) — surfaces as the `validate-state.sh --deep` check
- 4x `gate12` hand-rolled state.json writes in `test-force-phases.sh` (item 2 above)
- 3x `gate3` scripts on disk not declared in `provides.scripts`
  (`test-state-write-large-payload.sh`, `tests/test-force-phases.sh`,
  `tests/test-roadmap-argv-ceiling.sh`)
- 1x `gate16` WARN: core still declares `routing_hard`/`routing_agents_hard` — this is precisely
  what `collapse_routing_ladder_to_routing_agents` retires, so it clears with that task

A doc-lint failure also shows in the check summary but emits no FINDING line; re-run
`bash .claude/scripts/check-extension-docs.sh` for detail.

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
