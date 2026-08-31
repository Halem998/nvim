# Report: Backlog Operation Manifest

- **Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Phase**: 7 of 10 (plan: plans/01_orchestrate-centric-consolidation.md)

## Sequencing Tensions -- Resolved Directions

| Tension | Direction | Reasoning |
|---------|-----------|-----------|
| #48 (`propagate_scoped_commit_to_all_call_sites`) vs. A1's command deletions | **Sequence #48 AFTER the command-deletion successor task (NEW-8 below).** | #48's "65 call sites" set includes `research.md`/`plan.md`/`implement.md`; fixing files about to be deleted wastes the work. A dependency edge is added: #48 depends on NEW-8. |
| #90 (`adoption_lint_for_shared_task_lookup_helper`) vs. A1's command deletions | **Sequence #90 AFTER NEW-8**, same reasoning as #48 (its "111 files" baseline includes the same three commands). | Dependency edge: #90 depends on NEW-8. |
| #115 (`mirror_model_flag_into_hard_orchestrate`) vs. A4's deletion of `skill-orchestrate-hard` | **ABANDON #115.** Refined from Phase 5's "partially moot" into a firm verdict: once NEW-2/NEW-3 (A4's contract-injection + state-machine migration) and NEW-5 (deletion of `skill-orchestrate-hard`) land, model-flag support in `hard_mode` is already covered by #114's work landing in the single engine -- there is no separate file left to mirror into. | Citing A7 ledger row `skill-orchestrate-hard/SKILL.md` (report 03). |
| #88 (`mode_gate_skill_orchestrate_multi_task_section`) vs. the collapse's own edits to `skill-orchestrate/SKILL.md` | **Sequence #88 to land AFTER NEW-11** (the last collapse-related task touching that file), even though Phase 4's netting confirmed no line-count double-count. | Both #88 and the collapse edit the same file; landing #88 last avoids repeated merge friction across NEW-1/2/3/6/10/11, all of which touch `skill-orchestrate/SKILL.md`. Encoded as a dependency edge (not merely relying on the batch-admission file_scope-collision gate, since these are *sequential* tasks across different dispatches, not same-batch concurrent ones). |

## Finalized BLOCKING Set

| Task | What the collapse would inherit/entrench if this did not land first |
|------|------------------------------------------------------------------------|
| #68 `discriminate_blocked_on_in_batch_predecessor` | A live defect where a same-batch successor task never gets un-skipped once its predecessor completes. Once `/orchestrate` is the SOLE lifecycle entry point (A1), there is no per-task `/implement` fallback left to route around a stuck batch -- the defect's blast radius grows from "an annoying batch stall with a workaround" to "the only door is jammed." |
| #81 `mechanize_task_lock_and_session_heartbeat_refresh` | Task-lock/session-registry liveness is a named A6 PRESERVE asset -- but it is preserved-BROKEN today (frozen heartbeats). Carrying a broken liveness signal into the sole-entry-point collapse entrenches it at higher stakes: every dispatch under the collapsed engine (not just `/implement`) now relies on this signal for staleness-based recovery decisions. |

Both are added as dependencies of NEW-8 (the command-deletion task): NEW-8 depends on #68 AND #81.

## Successor Implementation Tasks (Phase C CREATE rows)

Sizing rule applied throughout: no task both deletes a file AND rewires that file's consumers;
deletion tasks depend on their own rewiring task. All `file_scope` entries are
`agent-system/extensions/**` paths only.

| ID | Title | Scope (one paragraph) | file_scope | Dependencies |
|----|-------|------------------------|------------|---------------|
| NEW-1 | Build the dispatch-prep stage in skill-orchestrate (memory retrieval, --lit, --clean, --fast) | Add a new stage to `skill-orchestrate/SKILL.md`, invoked once per dispatch (single-task and each multi-task wave member), that: calls `memory-retrieve.sh` gated by a newly-added `--clean` flag; calls the shared `lit-stage4a-flow.md` flow to resolve `lit_flag` into a `<literature-briefing>` block; adds a `--fast` flag to `orchestrate.md`'s Options table and threads it into dispatch-context construction. This is the A1 precondition -- purely additive, no deletions. | `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, `agent-system/extensions/core/commands/orchestrate.md`, `agent-system/extensions/core/scripts/parse-command-args.sh` | none |
| NEW-2 | Build hard_contracts manifest key and contract-text injection at dispatch-prep time | Add the `hard_contracts` manifest key (A4-ii, additive per-extension contract override/addition), and extend NEW-1's dispatch-prep stage to, when `hard_mode` is set, build and append the ordered `context/contracts/*.md` reference block to the dispatch prompt (replacing the 7 files' independent reference lists with one call site). Add the `verify-deploy.sh` deploy-time warning for extensions still declaring `routing_hard`/`routing_agents_hard` (A4-iii). | `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/context/guides/manifest-routing-schema.md` | NEW-1 |
| NEW-3 | Migrate hard-mode state-machine logic (H1 phase-per-cycle, H5/H6 churn/three-strikes, burnout breaker) into skill-orchestrate | Port the genuinely-stateful residue identified in report 03's A4 measurement (~279-line loop-guard/churn init, ~38-line burnout breaker, ~56-line churn detection, plus the H1 single-blocking-phase-per-cycle implement-dispatch limiter) into `skill-orchestrate/SKILL.md` as `if $hard_mode` conditional branches alongside NEW-2's injection stage. | `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` | NEW-1, NEW-2 |
| NEW-4 | Retarget the 7 hard-mode test/lint files to skill-orchestrate's hard_mode branch | Update `test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`, `test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`, `test-handoff-dispatch-identity.sh`, `test-resume-scan-nonconformance.sh`, and `lint-contract-compliance.sh` (Phase 1's enumerated set) to assert against `skill-orchestrate/SKILL.md`'s new `hard_mode` branch instead of `skill-orchestrate-hard/SKILL.md`, preserving coverage rather than dropping it. | `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh`, `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`, `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh`, `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh`, `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh`, `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh`, `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` | NEW-2, NEW-3 |
| NEW-5 | Delete skill-orchestrate-hard and the three -hard lifecycle skills and agent files | Delete `skill-orchestrate-hard/SKILL.md`, `skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`, `skill-implementer-hard/SKILL.md`, `general-research-hard-agent.md`, `planner-hard-agent.md`, `general-implementation-hard-agent.md` (A7 ledger rows), and remove `routing_hard`/`routing_agents_hard` blocks from core/cslib/lean manifests. Pure deletion -- all consumers already rewired by NEW-2/NEW-3/NEW-4. | `agent-system/extensions/core/skills/skill-orchestrate-hard/`, `agent-system/extensions/core/skills/skill-researcher-hard/`, `agent-system/extensions/core/skills/skill-planner-hard/`, `agent-system/extensions/core/skills/skill-implementer-hard/`, `agent-system/extensions/core/agents/general-research-hard-agent.md`, `agent-system/extensions/core/agents/planner-hard-agent.md`, `agent-system/extensions/core/agents/general-implementation-hard-agent.md`, `agent-system/extensions/core/manifest.json`, `agent-system/extensions/cslib/manifest.json`, `agent-system/extensions/lean/manifest.json` | NEW-2, NEW-3, NEW-4 |
| NEW-6 | Build the team-mode shared fan-out stage in skill-orchestrate (A5) | Add a phase-parameterized fan-out stage to `skill-orchestrate/SKILL.md` implementing per-teammate finding-file naming, territory contracts, and SubagentStop-postflight-to-owning-session correlation once, replacing the three team skills' independent copies. Add `--team`/`--team-size` flags to `orchestrate.md`, including the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`-unset graceful-degradation check (A5-v). `synthesis-agent` is unchanged and NOT touched by this task. | `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, `agent-system/extensions/core/commands/orchestrate.md` | NEW-1 |
| NEW-7 | Delete the three team-mode skills | Delete `skill-team-research/SKILL.md`, `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md` (A5-i, A7 ledger). Pure deletion -- fan-out logic already rehomed by NEW-6. | `agent-system/extensions/core/skills/skill-team-research/`, `agent-system/extensions/core/skills/skill-team-plan/`, `agent-system/extensions/core/skills/skill-team-implement/` | NEW-6 |
| NEW-8 | Delete /research, /plan, /implement commands and update the CLAUDE.md command reference | Delete `commands/research.md`, `commands/plan.md`, `commands/implement.md` (A1, A7 ledger); update `merge-sources/claudemd.md`'s Command Reference table to remove the three rows and document `/orchestrate NNN --research`/`--plan`/`--implement` as their replacement spelling (A2). `/revise` is explicitly NOT touched (A1 decision). | `agent-system/extensions/core/commands/research.md`, `agent-system/extensions/core/commands/plan.md`, `agent-system/extensions/core/commands/implement.md`, `agent-system/extensions/core/merge-sources/claudemd.md` | NEW-1 (A1 precondition), #68 (BLOCKING), #81 (BLOCKING) |
| NEW-9 | Delete the three base lifecycle skills | Delete `skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md` (A1 migration note, A7 ledger). Pure deletion -- their Stage 4a memory/`--lit` logic already rehomed by NEW-1, and their only callers (the three deleted commands) are already gone. | `agent-system/extensions/core/skills/skill-researcher/`, `agent-system/extensions/core/skills/skill-planner/`, `agent-system/extensions/core/skills/skill-implementer/` | NEW-1, NEW-8 |
| NEW-10 | Implement A2 phase-forcing flags on /orchestrate | Add `--research`/`--plan`/`--implement` flags to `orchestrate.md` and `skill-orchestrate`'s Stage 1b/2 phase-resolution logic (force_phases override, compose-as-stop-after-last-named semantics, monotonic-max status-write clamp); change `orchestrator-postflight.sh`'s Stage 7a increment condition from "phase == research" to "phase was force-invoked, any phase". | `agent-system/extensions/core/commands/orchestrate.md`, `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, `agent-system/extensions/core/scripts/orchestrator-postflight.sh`, `agent-system/extensions/core/scripts/skill-base.sh` | NEW-1 |
| NEW-11 | Collapse the routing ladder to routing_agents-only across all 19 extension manifests; retire command-route-skill.sh | Per A3: remove `routing`/`routing_hard` blocks from every manifest (retaining only `routing_agents`), retire `command-route-skill.sh` (no remaining caller once NEW-8 lands), and update `context/guides/manifest-routing-schema.md` to document the two-block (down from four) model. | `agent-system/extensions/*/manifest.json` (all 19), `agent-system/extensions/core/scripts/command-route-skill.sh`, `agent-system/extensions/core/context/guides/manifest-routing-schema.md` | NEW-8, NEW-5 |

## Operation Manifest

| Operation | Target | Change | Authorizing decision |
|-----------|--------|--------|------------------------|
| CREATE | NEW-1..NEW-11 | See table above | A1-A5 (report 03) |
| REVISE | #46 | Scope narrowed to the `routing_agents`-half of the colon-suffix defect only (drop the `routing`-half, moot under A1) | A3 (report 03); Phase 5 verdict |
| REVISE | #72 | Retarget from the three team-skill files to NEW-6's shared fan-out stage | A5-iv (report 03); Phase 5 verdict |
| REVISE | #73 | Retarget from the per-skill postflight marker convention to NEW-6's shared session-correlation logic | A5-iv (report 03); Phase 5 verdict |
| REVISE | #45 | Record the topic correction (scope is nvim Lua UI code, not `agent-system/extensions/**`) in the description text itself | Phase 1 evidence (report 02); Phase 6 verdict |
| ABANDON | #64 | Absorbed into NEW-2; reason cites A4(ii)'s `hard_contracts` mechanism superseding the standalone manifest-declaration approach | A4 (report 03); Phase 5 verdict |
| ABANDON | #115 | Superseded once NEW-2/NEW-3/NEW-5 land and #114 covers model-flag support in the single engine; reason cites A7 ledger row `skill-orchestrate-hard/SKILL.md` | A4/A7 (report 03); Phase 7 resolved direction |
| RETOPIC | #100 | `null` -> `core-agent-system` | Phase 1 admission (report 02) |
| RETOPIC | #45 | `core-agent-system` -> `neovim` | Phase 1 topic-anomaly finding (report 02); Phase 6 verdict |
| RETOPIC | #74, #75, #76 | `core-agent-system` (if any drifted) -> confirmed `extensions` | Task description's expected verdict, confirmed Phase 6 |
| BACKFILL | #46 | `file_scope` populated: `agent-system/extensions/present/manifest.json`, `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`, `agent-system/extensions/core/scripts/command-route-skill.sh`, `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` | Phase 1 DERIVED-FROM-DESCRIPTION evidence (report 02) |
| BACKFILL | #51 | `file_scope` populated: `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`, `agent-system/extensions/core/scripts/task-lock.sh`, `agent-system/extensions/core/skills/skill-todo/`, `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`, `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` | Phase 1 DERIVED-FROM-DESCRIPTION evidence (report 02) |
| BACKFILL | #45 | `file_scope` populated: `lua/neotex/plugins/ai/claude/commands/picker/`, `lua/neotex/plugins/ai/shared/extensions/` | Phase 1 DERIVED-FROM-DESCRIPTION evidence (report 02) |
| DEPEND | #48 | add dependency on NEW-8 | Sequencing tension, resolved above |
| DEPEND | #90 | add dependency on NEW-8 | Sequencing tension, resolved above |
| DEPEND | #88 | add dependency on NEW-11 | Sequencing tension, resolved above |
| DEPEND | #72 | add dependency on NEW-6 | REVISE row above -- fix target must exist |
| DEPEND | #73 | add dependency on NEW-6 | REVISE row above -- fix target must exist |
| DEPEND | NEW-8 | add dependencies on #68, #81 | Finalized BLOCKING set above |

**Allocation note**: `NEW-1`..`NEW-11` are placeholders. Actual `project_number` values are
allocated at Phase 8's apply time from `next_project_number`, incrementing per creation, and are
recorded back into this manifest (see Phase 8's own closeout) so the DEPEND rows above resolve to
real numbers before Phase 10 writes them into `state.json`.

CREATE operations are applied (Phase 8) before any DEPEND operation referencing a `NEW-n` id
(Phase 10), consistent with this ordering rule.

Every non-ON-PATH verdict from Phase 5/6 maps to a manifest row above: #46/#72/#73/#45 -> REVISE;
#64/#115 -> ABANDON; #100/#45/#74/#75/#76 -> RETOPIC (only where a topic actually changes: #74-76
are a confirmation, not a change, so no RETOPIC write is needed for them since their topic was
already `extensions`, not `core-agent-system` -- checked directly in Phase 1's roster, no action
required, no manifest row needed beyond the confirmation already recorded in report 04). ON-PATH
verdicts with no description/topic/dependency change need no manifest row (their only "operation"
is remaining in the backlog unchanged); ON-PATH verdicts WITH a new dependency edge (#48, #90,
#88, #114 implicitly via no new edge) are covered by the DEPEND rows above.
