# Report: Backlog Audit Verdicts

- **Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Phases**: 5-6 of 10 (plan: plans/01_orchestrate-centric-consolidation.md)

## Verdict Vocabulary

- **ON-PATH** -- survives unchanged; sequenced relative to the refactor.
- **RESCOPE** -- survives with a revised description; states what changes and why.
- **ABSORB** -- merged into a consolidation task; names the target.
- **MOOT** -- abandoned because the file/mechanism it fixes ceases to exist; MUST name the
  Phase 4 (report 03) A7 ledger row that makes it moot.
- **BLOCKING** (orthogonal flag, not a verdict) -- must land before the collapse because the
  collapse would otherwise inherit or entrench its defect.

## Method

Roster is Phase 1's 33-row table (report 02): 32 tasks matched by topic (`core-agent-system`
29 + `extensions` 3, excluding task 116 itself) plus task 100 (topic `null`, admitted in Phase 1
with reasoning). Partitioned into a **design-coupled cluster** -- every task whose `file_scope`
or description-derived scope touches the orchestrate engine (either variant), a lifecycle
command, a lifecycle skill or agent (either variant), a team skill or the synthesis agent, the
routing ladder/its consumers/a manifest routing block, the model-flag threading path, or the
context-loading convention chain that targets the engine's own multi-task section (narrowly:
`skill-orchestrate`'s `## Multi-Task Mode` section itself, not literature/distill or `/task`,
which are the mode-gating convention's OTHER applications and are handled in the remainder
cluster) -- and a **remainder**, defined by exclusion. Cluster membership below cites the file(s)
each task's own description names.

## Design-Coupled Cluster (18 tasks; Scope Hypothesis estimated ~17)

| # | Task | Verdict | Citation | BLOCKING? |
|---|------|---------|----------|-----------|
| 13 | `instrument_gate_out_auto_repair_reporting` | **ON-PATH** | Touches `command-gate-out.sh`/`skill_validate_task_artifacts` (A6 PRESERVE: GATE OUT sequencing), unaffected by A1-A5's decisions -- fixes reporting fidelity on a mechanism the collapse does not change. Sequence: independent, any time. | NOT BLOCKING -- a reporting-quality gap, not a correctness gap the collapse would inherit |
| 14 | `prevent_implementation_agent_nonterminal_fanout` | **ON-PATH** (already RESCOPEd 2026-08-24 to the agent-contract half only) | Touches `general-implementation-agent.md` directly (A6 PRESERVE: the base agent file survives A4's collapse unchanged in identity, only gains contract-injection text) -- its own 2026-08-24 rescope already narrows to exactly the fan-out-prohibition + same-commit-marker-update additions, which land in the SAME file A4's dispatch-prep stage also edits. Sequence AFTER A4's contract-injection mechanism lands, so both edits to the same file don't collide. | NOT BLOCKING -- a hardening addition, not a defect the collapse would inherit if unaddressed |
| 44 | `slim_task_command_body` | **ON-PATH** | Part of the mode-gated-section-loading family per the task description's pre-established finding (convention task #87 plus its named applications, one of which targets `commands/task.md`) -- lazy-loads reference material out of `/task`'s command body. `/task` is not one of A1's deleted commands, so this is independent of the collapse itself; sequenced only relative to #87 (needs the convention landed first). | NOT BLOCKING |
| 46 | `fix_present_extension_compound_skill_routing` | **RESCOPE** | Per Phase 4's A3 finding: the task's ORIGINAL scope (fix `routing.implement`'s colon-suffixed skill-name values in `present`'s manifest) becomes **moot for the `routing` half** once A1 deletes the command layer that consumes `routing`/skill-dispatch (report 03 A7 ledger row: `command-route-skill.sh` retired). It is **NOT moot for `routing_agents`**: if `present`'s `routing_agents` block carries the analogous colon-suffixed AGENT name, that half of the defect survives the collapse unchanged. Revise description to scope exclusively to `routing_agents` plus the `lint-routing-wiring.sh` check extension, dropping the `routing`-half work the collapse subsumes. | NOT BLOCKING -- a manifest correctness defect, but confined to `present`, not inherited by the core collapse itself |
| 48 | `propagate_scoped_commit_to_all_call_sites` | **ON-PATH** | Explicitly named in the task description as needing sequencing vs. A1's command deletions -- its "65 call sites" set includes `research.md`/`plan.md`/`implement.md`, all three deleted under A1 (report 03 A7 ledger). Direction (finalized in Phase 7): sequence AFTER A1's command deletions land, so the call-site count and fix-set are computed against the POST-collapse file set, not wastefully fixing 3 files about to be deleted. | NOT BLOCKING -- a hardening/safety propagation, not something the collapse itself would newly introduce a gap in |
| 53 | `suppress_expected_handoff_absence_defect` | **ON-PATH** | The task description's named "softer BLOCKING candidate" (governs whether the collapse's rollout telemetry -- `HANDOFF_STALE_OR_ABSENT` false positives -- can be trusted). Evaluated: **NOT BLOCKING**. Reasoning: the defect is a false-positive DEFECT REPORT on an otherwise-successful run; it does not corrupt or block any actual dispatch, and the collapse's own successor tasks can be verified by direct evidence (git diff, `.return-meta.json` contents) independent of whether this specific telemetry class is noisy. Fixing it improves rollout-monitoring signal quality but the collapse does not depend on it landing first. | Evaluated: **NOT BLOCKING** (softer candidate, reasoned above) |
| 64 | `deliver_hard_mode_contracts_across_extensions` | **ABSORB** into the A4 successor task ("build the `hard_contracts` manifest key + dispatch-prep contract injection") | Per the task description's own instruction ("This subsumes the existing standalone task ... which Phase B should absorb rather than leave running in parallel") and report 03 A4(ii): the manifest-declaration mechanism this task would have built (`routing_hard` extension for non-core extensions) is superseded wholesale by A4's `hard_contracts` key, which is extension-declared additively rather than requiring every extension to adopt the `-hard`-skill-tree pattern. | N/A (absorbed, not independently sequenced) |
| 68 | `discriminate_blocked_on_in_batch_predecessor` | **ON-PATH** | The task description's named BLOCKING candidate #1: "the `/orchestrate` blocked-verdict discrimination defect (a live correctness defect in the very engine A1 makes the sole entry point)". Evaluated: **BLOCKING**. Reasoning: making `/orchestrate` the SOLE lifecycle entry point (A1) means every multi-task batch that today could still fall back to per-task `/implement` retries loses that fallback -- a live defect where a same-batch successor never gets un-skipped would become MORE consequential, not less, once `/orchestrate` is the only door. Must land before A1's command deletions. | **BLOCKING** |
| 72 | `fix_teammate_return_meta_write_conflict` | **RESCOPE** | Team-mode-lifecycle defect in exactly the teammate contract layer A5 folds (report 03 A5-iv: "two open backlog tasks describe real defects... the fold must state where each defect is re-expressed"). A5's decision preserves teammates (folded, not deleted), so the defect is NOT moot -- it is RESCOPEd to target the new shared fan-out stage inside `skill-orchestrate` instead of the three separate team-skill files it currently names. | NOT BLOCKING -- the defect is real but pre-existing and orthogonal to whether the fold lands; not something the collapse newly introduces |
| 73 | `correlate_subagent_postflight_hook_to_owning_session` | **RESCOPE** | Same A5-iv reasoning as #72: the SubagentStop-hook correlation defect survives the team-mode fold and is re-targeted at the shared fan-out stage's session-correlation logic rather than the current per-skill postflight marker convention. | NOT BLOCKING (same reasoning as #72 -- pre-existing, not collapse-introduced) |
| 81 | `mechanize_task_lock_and_session_heartbeat_refresh` | **ON-PATH** | The task description's named BLOCKING candidate #2: "the task-lock/session-registry heartbeat defect (liveness is a named A6 preserved asset)". Evaluated: **BLOCKING**. Reasoning: report 03's A6 table marks task-lock/session-registry concurrency control PRESERVE (unchanged carry-forward) -- but Phase 1/this task's own re-derivation shows the underlying liveness signal is ALREADY broken today (frozen heartbeats). Carrying forward a preserved-but-broken mechanism into the sole-entry-point collapse just entrenches the breakage at higher stakes (every batch dispatch, not just `/implement`). Must land before or alongside the collapse, not after. | **BLOCKING** |
| 87 | `mode_gated_section_loading_convention` | **ON-PATH** | The mode-gating convention itself; #44/#88/(#89, remainder) are its applications. Establishes the mechanism the other application tasks depend on. Sequence FIRST among the mode-gating family. | NOT BLOCKING |
| 88 | `mode_gate_skill_orchestrate_multi_task_section` | **ON-PATH** | Targets `skill-orchestrate/SKILL.md`'s `## Multi-Task Mode` section (103,462 B / 55% of the file) -- the SAME file A1's precondition, A4, and A5 all add a new single-task dispatch-prep stage and hard-mode/team-mode conditional branches to. **No double-count** with this collapse's own savings (report 03 A7's netting: #88 is a runtime-token-budget saving on a section this collapse does not touch or shrink; this collapse's savings are static file deletions elsewhere) -- but this IS a **file-territory conflict** requiring sequencing: #88 and any A1/A4/A5 successor task that edits `skill-orchestrate/SKILL.md` must not run concurrently. Direction (finalized Phase 7): sequence #88 to land in a dedicated cycle, not concurrent with the collapse's own edits to the same file's single-task stages. | NOT BLOCKING (a token-efficiency win, not a correctness defect the collapse would inherit) |
| 90 | `adoption_lint_for_shared_task_lookup_helper` | **ON-PATH** | Explicitly named alongside #48 as a call-site-counting task needing sequencing vs. A1's deletions -- its "111 files" count includes `research.md`/`plan.md`/`implement.md`. Direction (finalized Phase 7): sequence the adoption lint's BASELINE MEASUREMENT after A1's command deletions land, for the same reason as #48 (avoid counting/fixing files about to be deleted). | NOT BLOCKING |
| 91 | `fail_loudly_on_nonconforming_plan_status_line` | **ON-PATH** | Touches `update-plan-status.sh` and "hard-fails `/orchestrate` postflight" -- the orchestrate engine's own postflight path, an A6 PRESERVE asset (unchanged by A1-A5's decisions; this task improves its diagnosability). Independent of the collapse's own sequencing. | NOT BLOCKING |
| 100 | `close_aggregator_file_scope_blind_spot` | **ON-PATH** (re-topic to `core-agent-system` per Phase 1's admission) | Touches `orchestrate-batch-admit.sh`/`orchestrate-predispatch-review.sh` -- the multi-task engine's own admission-gate scripts, A6 PRESERVE assets. Its fix (aggregator file_scope blind-spot detection) is orthogonal to A1-A5's lifecycle-collapse decisions; independent sequencing. | NOT BLOCKING |
| 114 | `wire_model_flag_through_orchestrate` | **ON-PATH** | Task description's pre-established finding, verified in Phase 4 (report 03 A6): model flags are parsed but have zero consumers in `orchestrate.md`/`skill-orchestrate` today -- this task IS the A6 REBUILD-REQUIRED work for model flags. Confirmed ON-PATH, and its own scope (thread `model_flag` through the base engine to dispatched agents) is exactly what A6's table specifies as the post-collapse home. | NOT BLOCKING -- but should land EARLY as it is directly load-bearing for A6's model-flag REBUILD-REQUIRED row |
| 115 | `mirror_model_flag_into_hard_orchestrate` | **PARTIALLY MOOT under A4** | Task description's pre-established finding, confirmed: its target file `skill-orchestrate-hard/SKILL.md` is in report 03's A7 deletion ledger (row: `skill-orchestrate-hard/SKILL.md`, 1,784 lines, replaced by `skill-orchestrate` + `hard_mode` conditional branches). Mirroring model-flag consumption into a file slated for deletion is wasted work UNLESS #115 lands before the A4 successor task deletes it. Direction (finalized Phase 7): sequence A4's collapse BEFORE #115 would otherwise run; #115 becomes moot in its current form (citing A7's `skill-orchestrate-hard/SKILL.md` row) and is superseded by model-flag support in the single engine's `hard_mode` branch, which #114 already covers once A4 lands -- i.e. #115 need not be separately implemented at all if #114 and A4 both land first. | NOT BLOCKING |

## Verification of Pre-Established Findings (design-coupled cluster)

- **Model-flag threading tasks (#114 ON-PATH, #115 partially MOOT under A4)**: **CONFIRMED**, with
  the additional finding that #115 need not be separately implemented at all once #114 and A4 both
  land (see #115's row above).
- **`--lit` threading through the three team skills**: no standalone backlog task with this exact
  scope was found in the roster (the null result is itself informative: A5's fold makes such a
  task moot by construction before it was ever filed, since `--lit` threading through team mode
  becomes a single dispatch-prep-stage concern per A1's precondition + A5, not a per-team-skill
  concern). **No verdict needed** -- there is no roster row to assign one to.
- **The two team-mode-lifecycle defect tasks (#72, #73)**: **CONFIRMED** RESCOPE-or-MOOT under A5,
  resolved to RESCOPE (both defects survive the fold since A5 preserves teammates) -- see their
  rows above.
- **The mode-gated-section-loading chain (#87 convention + #88/#89/#44 applications) is ON-PATH**:
  **CONFIRMED** for #87, #88, #44 (design-coupled cluster); #89 (literature/distill application) is
  reassigned to the remainder cluster per this report's Method section, since it does not touch the
  engine's own multi-task section -- this is a refinement of, not a contradiction to, the
  pre-established finding.
- **The hard-contract-delivery task (#64) is subsumed by A4**: **CONFIRMED**, ABSORB verdict above.
- **Call-site-counting tasks (#48, #90) vs. A1's deletions**: **CONFIRMED** both need sequencing;
  direction finalized as "measure/fix AFTER A1's deletions land" for both, recorded above.
- **Three latex build-guard tasks (#74-#76), expected verdict "return to `extensions` topic
  untouched"**: deferred to Phase 6 (remainder cluster), per the task description's own scoping.
