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
- **`--lit` threading through the three team skills**: a matching task DOES exist (task #94,
  "Wire the --lit flag through the three team skills so literature m..."), but it carries the
  `literature` topic and is therefore explicitly OUT OF SCOPE for this task's audit authority
  ("OUT OF SCOPE: all 15 literature-topic tasks" -- the task description's own AUDIT SCOPE
  section). Correction to an earlier draft of this finding, which stated no such task was found at
  all -- the accurate statement is that #94 exists but sits outside this task's re-topic/verdict
  authority. **No verdict assigned here, by design of the audit-scope boundary, not because the
  task does not exist.** #94's own eventual handler will need A5's fold (report 03) as context
  when it is worked: once task 122 (build_team_mode_fanout_stage) lands, `--lit` threading through
  team mode becomes a single dispatch-prep-stage concern (already covered by task 117's rehome),
  making #94 MOOT in its current form -- but that determination belongs to whichever
  literature-topic-authorized process handles #94, not to this task.
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

---

## Remainder Cluster (15 tasks)

A task in this cluster is ON-PATH only on a stated, positive finding of independence from A1-A5 --
not by default for being unexamined.

| # | Task | Verdict | Reasoning |
|---|------|---------|-----------|
| 20 | `fix_todo_metrics_sync_precommit_phantom_paths` | **ON-PATH** | `/todo`'s own metrics-sync/precommit ordering defect, independent of any lifecycle command/skill/agent/routing/team mechanism A1-A5 touch. Sequence: independent, any time. |
| 22 | `silence_opencode_fragment_validation_spam` | **ON-PATH** | OpenCode `opencode-agents.json` fragment path-reference design question (per-repo-deploy-dependent `{file:}` refs) -- entirely outside the core `.claude/` lifecycle surface A1-A5 collapse. Independent. |
| 27 | `remove_dead_opencode_command_router` | **ON-PATH** | Deletes a dead, already-unreachable OpenCode router script; unrelated to `/orchestrate`/lifecycle-skill collapse (a different command system entirely). Independent. |
| 29 | `generate_mcp_json_from_extension_manifests` | **ON-PATH** | Builds an MCP-server manifest-merge mechanism (`merge_targets.mcp`), a DIFFERENT manifest concern from `routing`/`routing_agents`/`hard_contracts` (A3/A4's routing blocks). No overlap with the routing ladder A3 carries forward. Independent. |
| 30 | `register_obsidian_memory_mcp_server` | **ON-PATH** | Depends on #29's new MCP-registration mechanism; unrelated to the lifecycle collapse. Sequenced after #29 (pre-existing dependency, unaffected by A1-A5). |
| 31 | `opencode_extensions_sync_mechanism` | **ON-PATH** | OpenCode mirror drift-detection/generation-path question; the `.opencode/` tree is a separate deploy target from `.claude/`'s lifecycle commands. Independent. |
| 42 | `verify_deploy_context_gates` | **ON-PATH** | Wires `measure-eager-context.sh` into `verify-deploy.sh`'s gate suite with a byte-count threshold -- a deploy-integrity gate orthogonal to A1-A5's routing/dispatch decisions. (Note: A4(iii) separately proposes ONE new `verify-deploy.sh` check of its own -- the `routing_hard` migration warning -- a small, non-conflicting addition to the same script; no territory collision since both are additive gate registrations.) Independent. |
| 43 | `email_safety_context_loading_decision` | **ON-PATH** | Email-extension safety-context-loading defect; extension-internal per the audit scope's own exclusion of extension internals from this task's authority. Independent. |
| 45 | `global_update_extension_repo_registry` | **RESCOPE** (topic anomaly) | Phase 1 evidenced its real scope is `lua/neotex/plugins/ai/claude/commands/picker/**` and `lua/neotex/plugins/ai/shared/extensions/**` -- nvim-config Lua UI code, NOT `agent-system/extensions/**` at all, despite carrying the `core-agent-system` topic. Revise: re-topic OFF `core-agent-system` (this task's re-topic authority is for SURVIVORS of the core-agent-system audit; a task never substantively about the core agent system should not have carried this topic). Recommend `neovim` topic in Phase 9's re-topic pass, with a note in the revised description recording the topic correction and its evidence. |
| 50 | `restore_verification_trust_and_close_hygiene_residue` | **ON-PATH** (already RESCOPEd/split 2026-08-24) | Session-ID and scoped-commit-gate hygiene residue; touches the SAME scoped-commit gate family as #48/#90 but as a gate-coverage fix (the gate only greps `*.sh`, missing `*.md`), not a call-site migration -- complementary to, not overlapping with, #48/#90's call-site propagation. Sequence: independent of A1-A5, but should land in the same general window as #48/#90 since all three touch scoped-commit hygiene (advisory note only, not a hard dependency). |
| 51 | `move_session_state_files_out_of_specs_root` | **ON-PATH** | Runtime-file location/reaper-coverage/auto-invocation fix (`specs/` root litter). Touches `orchestrator-runtime-files.md` and the reaper script, both orthogonal to A1-A5's lifecycle-collapse decisions -- these files' NAMES and cleanup cadence are unaffected by which command/skill dispatches them. Independent. |
| 74 | `latex_build_conflict_guard_script` | **ON-PATH -- returned to `extensions` topic** | Confirms the task description's expected verdict for latex build-guard work. Scope is the shared guard script itself (`agent-system/extensions/core/scripts/latex-build-guard.sh`) plus a `core/manifest.json` registration entry -- a new, self-contained utility, not a modification to any lifecycle command/skill/agent/routing block A1-A5 touch. **CONFIRMED** as extension-internal-adjacent (it lands in `core/scripts/` but is a standalone tool with no coupling to the collapse). |
| 75 | `wire_build_guard_into_latex_lifecycle` | **ON-PATH -- returned to `extensions` topic** | Scope is entirely `agent-system/extensions/latex/**` (manifest, scripts, agents, rules, context) -- purely extension-internal, using the EXISTING `skill_run_extension_hook()` mechanism unchanged. **CONFIRMED** as expected. |
| 76 | `cover_non_latex_typed_tex_builders` | **ON-PATH -- returned to `extensions` topic, WITH a confirmed caveat** | **CONTRADICTS the "purely extension-internal" framing, exactly as the task description anticipated** ("one of the three touches a core agent file"): its `file_scope` names `general-implementation-agent.md`, `general-implementation-hard-agent.md`, AND `skill-base.sh` directly -- all three are core lifecycle files A1/A4 also touch. This is a genuine file-territory overlap requiring sequencing awareness (both this task and A4's dispatch-prep-stage work edit `general-implementation-agent.md`), but the CONTENT is disjoint (a LaTeX-build-guard call vs. contract-injection text) so it does not change the verdict to design-coupled/RESCOPE -- it remains ON-PATH, returned to `extensions` topic, with an explicit Phase 7 sequencing note: do not run this task concurrently with any A4 successor task that edits the same two agent files. |
| 89 | `mode_gate_literature_and_distill_skills` | **ON-PATH** | Third mode-gating-family application (alongside #87 convention, #44 and #88's applications), targeting `skill-literature`/`skill-distill` -- outside the orchestrate engine and outside A1-A5's touched files entirely, so classified in the remainder cluster per this report's Method section (refines, does not contradict, the task description's framing of it as part of the "same chain"). Sequenced after #87 lands (pre-existing dependency), independent of A1-A5. |

### `topic: null` task accounting

Task 100 was admitted to the audit scope in Phase 1 (report 02) and assigned its verdict in the
design-coupled cluster (ON-PATH, re-topic to `core-agent-system`) -- no further action needed here;
this subsection exists per the plan's own instruction to restate the accounting so the roster
closes with an explicit disposition for every non-literature task, including the one with no
topic at all.

### Coverage line

Roster size (Phase 1, report 02): **33** (32 topic-matched + task 100, admitted). Verdicts
assigned: design-coupled cluster **18** (Phase 5) + remainder cluster **15** (this phase) =
**33**. **33 = 33 -- every roster row carries exactly one verdict.** Every MOOT-adjacent verdict
(#46's `routing`-half mootness, #115's mootness) names its Phase 4 (report 03) A7 ledger citation
in its own row above; no roster row was assigned a bare "MOOT" without a ledger citation, and no
row was left unassigned.

## Phase 9 Closeout

No verdict in this report was recorded as provisional -- Phase 1 (report 02) resolved all three
null-`file_scope` tasks (#45, #46, #51) to DERIVED-FROM-DESCRIPTION rather than EVIDENCE-GAP, so
no BACKFILL-then-finalize step was needed for a provisional verdict. The three BACKFILL operations
applied in Phase 9 (populating `file_scope` for #45, #46, #51 from that same evidence) are
therefore data-quality completions, not verdict finalizations -- their verdicts (#45 RESCOPE, #46
RESCOPE, #51 ON-PATH) were already final when written in Phases 5-6.

Applied in Phase 9: REVISE (#45, #46, #72, #73), ABANDON (#64, #115), RETOPIC (#45 -> `neovim`,
#100 -> `core-agent-system`), BACKFILL (#45, #46, #51 `file_scope`), DEPEND (#48, #90 -> +124;
#88 -> +127; #72, #73 -> +122). All writes round-tripped intact; `.active_projects` count held at
59 throughout (abandonment applied in place as a status transition, not a removal, per this
task's own binding invariant); no touched record lost a field.
