# Report: Baseline Verification and Audit-Scope Evidence Roster

- **Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Phase**: 1 of 10 (plan: plans/01_orchestrate-centric-consolidation.md)
- **Date**: 2026-08-31

## Measurement

Re-measured against the MOTIVATION baseline recorded in the task description (`find` + `wc -l`
over `agent-system/extensions/core/`; SKILL.md-only for skills, matching the baseline's own
measurement method):

| Category | Baseline files | Measured files | Baseline lines | Measured lines | Delta |
|----------|----------------|-----------------|------------------|-------------------|-------|
| commands | 18 | 18 | 7,707 | 7,707 | none |
| skills (SKILL.md only) | 22 | 22 | 14,981 | 14,981 | none |
| agents | 12 | 12 | 5,073 | 5,073 | none |
| rules | 10 | 10 | -- | -- | none |
| scripts | 145 | 146 | 48,204 | 48,308 | +1 file / +104 lines |
| context | 137 | 147 | 37,959 | 39,224 | +10 files / +1,265 lines |
| docs | 28 | 28 | -- | -- | none |

Commands/skills/agents/rules/docs are unchanged since the baseline was recorded. Scripts and
context grew modestly (new tests/context files landed from other in-flight tasks between the
baseline snapshot and this measurement) -- the measured values above are authoritative for A7's
projected-reduction accounting in Phase 4; the description's baseline is retained in this table
for traceability.

## Verified Findings

### 1. Dispatch-bypass finding (re-verified)

Commands run:
```
grep -c -- "memory-retrieve" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md   # 0
grep -c -- "clean_flag" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md         # 0
grep -c -- "lit-stage4a" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md        # 0
grep -c -- "literature-briefing" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md # 0
grep -c -- "lit_flag" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md            # 13
```
Same four terms (excluding `lit_flag`) against `general-research-agent.md`, `planner-agent.md`,
`general-implementation-agent.md`: **0 occurrences in all three, for all four terms.**

Dispatch sites: `grep -n "subagent_type" skill-orchestrate/SKILL.md` returns **16** matches --
single-task research/plan/implement handler sites (6), a `"fork"` synthesis dispatch (2),
`reviser-agent` sites (2), a further single-task implement site (1), multi-task research/plan/
implement dispatch lines (3), and one table-row reference in prose (1). Confirms the finding
exactly as carried into the plan: **REPRODUCED**.

### 2. `skill-orchestrate-hard` unreachability (re-verified)

`/orchestrate`'s own Anti-Bypass Constraint (commands/orchestrate.md:40-42) states all lifecycle
phases delegate to `skill-orchestrate` via the Skill tool, unconditionally -- `--hard` is passed
into that same skill as a flag, never routed to a separate skill dispatch. No command file or
script issues a Skill/Agent-tool dispatch naming `skill-orchestrate-hard` as the target; every
repo-wide reference to it outside its own SKILL.md is either prose/documentation (context/docs
files, `orchestrate.md`'s own explanatory text) or shared-infrastructure code that treats it as
one of two symmetric log-prefix/case-table branches (`skill-base.sh`, `command-route-agent.sh`).
**REPRODUCED: `skill-orchestrate-hard` (1,784 lines per the research report) is unreachable from
any command.**

Test/lint files enumerated (7, not "10+" -- the research figure over-counted; confirmed set):
- `scripts/tests/test-loop-guard-budget-override.sh`
- `scripts/tests/test-routing-resolution.sh`
- `scripts/tests/test-handoff-reader-parity.sh`
- `scripts/tests/test-loop-guard-staleness.sh`
- `scripts/tests/test-handoff-dispatch-identity.sh`
- `scripts/tests/test-resume-scan-nonconformance.sh`
- `scripts/lint/lint-contract-compliance.sh`

### 3. Artifact-numbering asymmetry (re-verified)

- Research-only increment: `orchestrator-postflight.sh` Stage 7a (`# Stage 7a: Increment
  next_artifact_number (research only)`), writing
  `.next_artifact_number = (.next_artifact_number // 1) + 1` via `state-write.sh`.
- `"prev"` mode read: `skill-base.sh`'s artifact-number resolution function, mode `"prev"`
  ("planner/implementer share the same round as preceding research"), reading
  `next_artifact_number - 1`.

**REPRODUCED** exactly as the plan records it: no increment path exists today for a forced
re-plan or re-implement.

### 4. Manifest `routing_hard`/`routing_agents_hard` footprint (re-verified)

Queried every `agent-system/extensions/*/manifest.json` for the four routing block keys.
**3 of 19 extensions** declare `routing_hard`/`routing_agents_hard`: **core, cslib, lean**.
16 declare plain `routing`/`routing_agents` only (or neither, for literature/slidev, which
declare no lifecycle routing at all). This is the exact manifest footprint A4's migration path
must address.

## Audit-Scope Roster

### Reconciliation arithmetic

The task description names six topics (`agent-system`, `essential-refactor`,
`orchestration-concurrency`, `team-mode-lifecycle`, `status-marker-lifecycle`, `extensions`).
Querying live `state.json` today, **none** of the first five topic values exist on any task record
any longer -- every task that would have carried one of them now carries `topic: "core-agent-system"`
(a consolidation that evidently happened as ordinary backlog housekeeping in the period between the
task description being written and this implementation dispatch, unrelated to this task's own
Phase C, which has not yet run). This is recorded as an observed discrepancy, not silently
reconciled:

- `topic == "core-agent-system"`, excluding task 116 itself: **29**
- `topic == "extensions"`: **3**
- Subtotal: **32** -- matches the audit scope's stated count exactly.
- `topic == null`: **1** (task 100, `close_aggregator_file_scope_blind_spot`).

**Task 100 disposition**: its `file_scope` is 100% `agent-system/extensions/core` paths centered
on `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`, and
`file-footprint-overlap.md` -- the batch admission gate machinery, a named A6 preserved-asset
category. It is plainly core-agent-system-relevant work with an unset topic (an oversight at
creation time), not a task that belongs in `literature` or elsewhere. **Admitted to the audit
scope** with this reasoning; re-topic to `core-agent-system` in Phase 9. This makes the effective
working roster **33** tasks, one more than the description's stated 32 -- the extra unit is task
100, and the discrepancy is fully accounted for by this admission decision rather than a counting
error.

### Null-`file_scope` tasks (three, not two)

Confirmed exactly three audit-scope tasks carry a null/empty `file_scope`: **#45, #46, #51**. All
three evidence a concrete scope from their description prose (DERIVED-FROM-DESCRIPTION, not
EVIDENCE-GAP):

- **#45** `global_update_extension_repo_registry`: names `<leader>al`, the extension-loading
  picker, and a "Global Update" action. Grepped the repo for the picker implementation: it is the
  nvim Lua extension picker at `lua/neotex/plugins/ai/claude/commands/picker/**` and
  `lua/neotex/plugins/ai/shared/extensions/**` -- **not** under `agent-system/extensions/**` at
  all. This is a **topic anomaly**: a `core-agent-system`-topic task whose real scope is nvim-config
  Lua UI code, unrelated to the orchestrate-engine collapse. Flagged for Phase 6.
- **#46** `fix_present_extension_compound_skill_routing`: names
  `agent-system/extensions/present/manifest.json` (`routing.implement`),
  `scripts/lib/manifest-routing-lib.sh`, `command-route-skill.sh`, and `lint-routing-wiring.sh`
  explicitly.
- **#51** `move_session_state_files_out_of_specs_root`: names
  `scripts/reap-session-runtime-files.sh`, `task-lock.sh`, `skill-todo`,
  `context/standards/orchestrator-runtime-files.md`, and `check-runtime-file-tracking.sh`
  explicitly.

### Roster table (33 rows: 32 topic-matched + task 100)

| # | Task | Status | Type | Deps | Scope Tier | Scope Summary |
|---|------|--------|------|------|-----------|----------------|
| 13 | `instrument_gate_out_auto_repair_reporting` | not_started | meta | 0 | file_scope (2 paths) | The acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" is unverifiable as written, because no reporting surface exists. Re |
| 14 | `prevent_implementation_agent_nonterminal_fanout` | not_started | meta | 0 | file_scope (4 paths) | Rescope (2026-08-24): agent-contract side only -- add fan-out prohibition and same-commit marker-update requirement to general-implementation-agent.md; status-vocabulary half already landed. |
| 20 | `fix_todo_metrics_sync_precommit_phantom_paths` | not_started | meta | 0 | file_scope (3 paths) | /todo's repository-metrics sync runs before its git commit, so the health probe measures a tree whose git index still points at pre-move paths. Every archived-a |
| 22 | `silence_opencode_fragment_validation_spam` | researching | meta | 0 | file_scope (2 paths) | Rescope (2026-08-24): reframe around whether opencode-agents.json fragments should reference a per-project deploy tree at all; defect class 3 fixed, class 2 moved, class 1 worse (30/34 broken refs). |
| 27 | `remove_dead_opencode_command_router` | not_started | meta | 0 | file_scope (6 paths) | .opencode/scripts/execute-command.sh is a command router that cannot execute anything and is called by nothing but its own tests. Delete it and the three test s |
| 29 | `generate_mcp_json_from_extension_manifests` | not_started | meta | 0 | file_scope (4 paths) | Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json. |
| 30 | `register_obsidian_memory_mcp_server` | not_started | meta | 1 | file_scope (2 paths) | Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope. |
| 31 | `opencode_extensions_sync_mechanism` | researching | meta | 0 | file_scope (2 paths) | Rescope (2026-08-24): narrow to (1) fix one fake-tool teaching line, (2) add a drift-detection gate, (3) document the .opencode/ mirror's maintenance policy. |
| 42 | `verify_deploy_context_gates` | not_started | meta | 0 | file_scope (2 paths) | Rescope (2026-08-24): item (a), a broken-@-ref lint, is already achieved (regression guard only); item (b), wiring measure-eager-context.sh into the gate suite with a threshold, is the real remaining content. |
| 43 | `email_safety_context_loading_decision` | not_started | meta | 0 | file_scope (3 paths) | LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-arch |
| 44 | `slim_task_command_body` | planned | meta | 2 | file_scope (2 paths) | LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k to |
| 45 | `global_update_extension_repo_registry` | not_started | general | 0 | DERIVED-FROM-DESCRIPTION (2 paths) | Implement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded exte |
| 46 | `fix_present_extension_compound_skill_routing` | not_started | meta | 0 | DERIVED-FROM-DESCRIPTION (4 paths) | Fix present extension compound-skill routing so /implement resolves to a real skill. The present manifest's routing.implement declares "present:grant" -> "skill |
| 48 | `propagate_scoped_commit_to_all_call_sites` | not_started | meta | 1 | file_scope (1 paths) | Propagate the scoped-commit fix to the 65 call sites it never reached. This is a correctness/safety task, not a cleanup task. |
| 50 | `restore_verification_trust_and_close_hygiene_residue` | not_started | meta | 1 | file_scope (9 paths) | Rescope (2026-08-24): split -- the non-deterministic shell-test-suite item was extracted to its own task; what remains is hygiene residue (degraded session-ID/scoped-commit migration counts) plus closing verification-trust gaps. |
| 51 | `move_session_state_files_out_of_specs_root` | not_started | meta | 0 | DERIVED-FROM-DESCRIPTION (5 paths) | Stop session-scoped orchestration runtime files from accumulating at the specs/ root, and make the existing reap path actually run. Originally scoped as "move t |
| 53 | `suppress_expected_handoff_absence_defect` | not_started | meta | 0 | file_scope (5 paths) | Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect when a contractual non-writer leaves no fresh handoff. Observed live on a clean, fully-successfu |
| 64 | `deliver_hard_mode_contracts_across_extensions` | not_started | meta | 1 | file_scope (2 paths) | Decide and implement how --hard behavioral contracts reach agents system-wide. Only core, cslib, and lean declare routing_hard/routing_agents_hard. For every ot |
| 68 | `discriminate_blocked_on_in_batch_predecessor` | not_started | meta | 0 | file_scope (11 paths) | Make the multi-task /orchestrate classifier's `blocked` row DISCRIMINATING rather than unconditional, so a task blocked on a predecessor the same batch is going |
| 72 | `fix_teammate_return_meta_write_conflict` | not_started | meta | 0 | file_scope (7 paths) | Teammate agents spawned by team-mode skills write the skill-level .return-meta.json, clobbering the record the team skill is supposed to own. The surviving reco |
| 73 | `correlate_subagent_postflight_hook_to_owning_session` | not_started | meta | 0 | file_scope (7 paths) | The SubagentStop postflight hook picks an arbitrary .postflight-pending marker with no correlation to the session that owns it. In a team run, teammate stops bu |
| 74 | `latex_build_conflict_guard_script` | not_started | meta | 0 | file_scope (2 paths) | Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plug |
| 75 | `wire_build_guard_into_latex_lifecycle` | not_started | meta | 1 | file_scope (6 paths) | Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and,  |
| 76 | `cover_non_latex_typed_tex_builders` | not_started | meta | 1 | file_scope (3 paths) | Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build- |
| 81 | `mechanize_task_lock_and_session_heartbeat_refresh` | not_started | meta | 0 | file_scope (9 paths) | Task-lock and session-registry heartbeats never fire during a real single-task /implement run. Both liveness timestamps stay frozen at their acquire-time value  |
| 87 | `mode_gated_section_loading_convention` | not_started | meta | 1 | file_scope (3 paths) | Establish the convention that fixes the single largest token lever in the system: MUTUALLY-EXCLUSIVE BRANCH SECTIONS LOADED UNCONDITIONALLY. A skill's SKILL.md  |
| 88 | `mode_gate_skill_orchestrate_multi_task_section` | not_started | meta | 1 | file_scope (2 paths) | Apply the mode-gated section convention to the largest single instance in the system. skill-orchestrate/SKILL.md is 188,284 B; its `## Multi-Task Mode` section  |
| 89 | `mode_gate_literature_and_distill_skills` | not_started | meta | 2 | file_scope (2 paths) | Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it. |
| 90 | `adoption_lint_for_shared_task_lookup_helper` | not_started | meta | 2 | file_scope (2 paths) | The largest duplication class in the repo, and it has never been named in any review: the inline task-lookup jq block. 111 files carry a hand-rolled `jq --argjs |
| 91 | `fail_loudly_on_nonconforming_plan_status_line` | not_started | meta | 1 | file_scope (3 paths) | update-plan-status.sh reports every non-conforming plan Status line with one generic, undiagnosable message, and hard-fails /orchestrate postflight on a plan sh |
| 114 | `wire_model_flag_through_orchestrate` | not_started | meta | 0 | file_scope (2 paths) | Wire model-flag support into /orchestrate: thread model_flag from the command through the base skill-orchestrate engine so a model override actually reaches dis |
| 115 | `mirror_model_flag_into_hard_orchestrate` | not_started | meta | 1 | file_scope (2 paths) | Mirror model-flag consumption into skill-orchestrate-hard, and reconcile the documentation that currently claims /orchestrate --hard composes with model flags w |
| 100 | `close_aggregator_file_scope_blind_spot` | not_started | meta | 0 | file_scope (4 paths) | Close the file_scope blind spot for AGGREGATOR/REGISTRATION files (admitted from topic:null; see disposition above). |

## Coverage Check

33 roster rows total (29 core-agent-system + 3 extensions + 1 admitted topic-null), each with a
non-empty scope cell labelled `file_scope`, `DERIVED-FROM-DESCRIPTION`, or (none observed)
`EVIDENCE-GAP`. `git status --porcelain` confirmed to show changes only under `specs/` (see
below).

## Files Read (evidence trail)

- `specs/state.json` (roster query)
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/agents/{general-research-agent,planner-agent,general-implementation-agent}.md`
- `agent-system/extensions/core/scripts/{orchestrator-postflight.sh,skill-base.sh,command-route-agent.sh}`
- `agent-system/extensions/*/manifest.json` (all 19)
- `lua/neotex/plugins/ai/claude/commands/picker/**`, `lua/neotex/plugins/ai/shared/extensions/**`
