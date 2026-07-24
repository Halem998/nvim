---
next_project_number: 898
---

# TODO

## Task Order

*Updated 2026-07-24. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 873,885,891,892,893,894 | -- | agent-system |
| 2 | 887,895,896 | 873,891,892 | agent-system |
| 3 | 897 | 895 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

873 [PARTIAL] — Make /meta create tasks in the GLOBAL agent-system root by defaul
  └─ 887 [RESEARCHED] — RESEARCH-FIRST / HIGH PRIORITY. This is the design round. The use
885 [PARTIAL] — URGENT / HIGH PRIORITY. The 30-day transcript window is reaped da
891 [NOT STARTED] — SEVERITY: HIGHEST of a six-defect batch observed in a single full
  └─ 895 [NOT STARTED] — Observed in a single full /orchestrate run (lean4 task, 8 impleme
    └─ 897 [NOT STARTED] — LOWER PRIORITY. Observed in the same full /orchestrate run (lean4
892 [NOT STARTED] — SEVERITY: second-highest of a six-defect batch observed in a sing
  └─ 896 [NOT STARTED] — Observed in a single full /orchestrate run (lean4 task, 8 impleme
893 [NOT STARTED] — Observed in a single full /orchestrate run (lean4 task, 8 impleme
894 [NOT STARTED] — Observed in a single full /orchestrate run (lean4 task, 8 impleme

## Tasks

### 897. Add narrow sanctioned phase-marker grep exception to orchestrate MUST NOT list
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 895

**Description**: LOWER PRIORITY. Observed in the same full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles) as the other five defects in this batch.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

DEFECT: skill-orchestrate's MUST NOT list forbids reading plans/*.md, but the state machine DEPENDS on phase-progress facts (phases_completed / phases_total) that ONLY the handoff carries. When an agent writes a malformed or misplaced handoff, the orchestrator has NO LEGAL WAY to recover ground truth. This is the structural reason the misplaced-handoff defect was so damaging: the recovery path was forbidden by rule.

VERIFIED CURRENT CONSTRAINT: skills/skill-orchestrate/SKILL.md:819-829, the "MUST NOT (Context Flatness Constraint)" section. Item 2 forbids reading plan files during the state machine loop; :828 states "The ONLY file read after each dispatch is .orchestrator-handoff.json (<=400 tokens)", justified at :829 by keeping context growth to ~450 tokens per cycle regardless of artifact complexity. That rationale is sound and must be PRESERVED -- this task is not a license to relax context flatness generally.

NOTE that the skill already has a sanctioned escape hatch of a similar shape: the Skill-to-Agent Mapping table (:832 onward) lists a "Drift inspection" row dispatched to a fork subagent which "reads plan file, writes .drift-inspection.json" -- i.e. plan reading is already permitted when it happens in a SEPARATE context that returns only a small structured result. Evaluate whether the recovery path should reuse that established fork-and-return-small-JSON pattern instead of adding a direct-grep exception to the MUST NOT list, since that would preserve context flatness exactly rather than approximately.

DESIRED BEHAVIOR: consider a NARROW sanctioned exception -- grep for phase-header status markers ONLY, never full-file reads -- so the orchestrator can recover phases_completed / phases_total when the handoff is unusable. Whatever mechanism is chosen must bound the token cost explicitly and state that bound, and must make clear it is a RECOVERY path conditioned on a bad handoff, not a routine per-cycle read.

AFFECTS BOTH VARIANTS: skills/skill-orchestrate/SKILL.md and the corresponding constraint section in skills/skill-orchestrate-hard/SKILL.md (verify the hard variant's parallel MUST NOT list before editing).

DEPENDENCY NOTE: depends on task 895 (and transitively 891) purely to serialize edits to those same two SKILL.md files (file-overlap serializer, not a logical prerequisite). Sequence this LAST of the three-task SKILL.md chain, consistent with its lower priority.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 896. Fix cwd-relative paths in skill_link_artifacts and add task filter to reconcile-artifacts.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 892

**Description**: Observed in a single full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles) as one of six agent-system defects.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

SCOPE CORRECTION -- READ THIS FIRST. DO NOT CREATE link-artifacts.sh. The original defect report claimed skill-orchestrate Stage 5 calls skill_link_artifacts but that "link-artifacts.sh DOES NOT EXIST". That framing is WRONG and following it would produce the wrong fix. Verified: no file named link-artifacts.sh exists anywhere under the global root, but skill_link_artifacts is a LIVE, WORKING SHELL FUNCTION defined at scripts/skill-base.sh:434 (documented usage at :429). Stage 5's call (skills/skill-orchestrate/SKILL.md:441, restated :780; hard variant skills/skill-orchestrate-hard/SKILL.md:709) is a legitimate call to that function, NOT a reference to an undeployed helper. There is nothing missing to create.

THE ACTUAL DEFECT -- CWD RELATIVITY: skill_link_artifacts uses BARE, CWD-RELATIVE paths throughout its body. It reads and writes `specs/state.json`, round-trips through `specs/tmp/state.json`, and then invokes `bash .claude/scripts/generate-todo.sh` -- a path into the DISPOSABLE DEPLOY TREE rather than a resolved script location. Consequences: (1) the function silently targets whatever repository the cwd happens to be, so it can corrupt an unrelated repo's state.json or no-op entirely; (2) it fails or no-ops when cwd is not the project root; (3) it assumes `specs/tmp/` already exists, with no mkdir -p. Contrast the correct pattern already used elsewhere in this codebase: generate-todo.sh:28 and update-task-status.sh:27 both resolve PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)" from the SCRIPT's own location rather than from cwd.

OBSERVED SYMPTOM (evidence of real damage): because the function did not do its job, the only available fallback was scripts/reconcile-artifacts.sh, which takes NO task argument and is REPO-WIDE (its usage at :33 is `$0 [--dry-run]`; it loops over ALL active tasks from :79). Linking ONE task's TWO artifacts instead BACKFILLED 47 ARTIFACT ENTRIES ACROSS 12 UNRELATED TASKS, inflating what should have been a single-task commit.

DESIRED BEHAVIOR, two parts:
(a) Make skill_link_artifacts path-correct: resolve the project root explicitly rather than depending on cwd, stop reaching into .claude/ for generate-todo.sh, and ensure the tmp directory exists before the jq round-trip. Note that skill-base.sh uses bare-relative `specs/state.json` in several other places too (a known Strategy-B/CWD-following pattern in this file); decide whether to fix only this function or the file's pattern as a whole, and say which -- but do NOT refactor the whole script layer as part of this task.
(b) Give scripts/reconcile-artifacts.sh an OPTIONAL task-number filter so a single-task reconcile is possible and the repo-wide sweep becomes opt-in rather than the only mode.

DEPENDENCY NOTE: depends on task 892 purely to serialize edits to scripts/skill-base.sh, which both tasks touch (file-overlap serializer, not a logical prerequisite).

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 895. Distinguish infrastructure failure from a genuine /orchestrate work cycle
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 891

**Description**: Observed in a single full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles) as one of six agent-system defects.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

DEFECT: a phase-7 agent died mid-edit on a TRANSIENT NETWORK ERROR (API ENOTFOUND). Per Stage 5, a missing handoff means "increment cycle and continue" (skills/skill-orchestrate/SKILL.md:773 marks the task in failed_tasks and skips). So a network outage that did ZERO work and advanced ZERO state consumes one of only MAX_CYCLES=5 cycles. Infrastructure failure is charged against the work budget.

WHY THIS NEEDS A RULE RATHER THAN JUDGMENT: in the observed run the orchestrator DECLINED to charge the cycle -- but that was an unsanctioned judgment call with no rule behind it. The fix must make the correct behavior explicit and mechanical, so that it is reproducible rather than dependent on the orchestrator improvising.

VERIFIED CURRENT MECHANISM: MAX_CYCLES=5 at skills/skill-orchestrate/SKILL.md:105, cycle_count persisted in the loop-guard file (:113, :123-138), loop condition at :177. The hard variant sets MAX_CYCLES=13 at skills/skill-orchestrate-hard/SKILL.md:192 (documented at :252 as raised from 5 to accommodate per-phase dispatch) and already tracks a SEPARATE burnout_signals_this_session counter (:202, :229) -- that is a working precedent in this same file family for a second, independently-capped counter, and the infra-failure counter should follow its shape rather than invent a new one.

DESIRED BEHAVIOR: distinguish infrastructure/API failure from a genuine work cycle -- either do not increment cycle_count, or track infra failures in a separate counter with its own cap (preferred, since an unbounded no-increment path could spin forever on a persistent outage). Define precisely what counts as an infra failure versus a real dispatch failure; ENOTFOUND / transport errors / API unavailability are infra, whereas an agent that ran and produced a bad or missing handoff is a genuine work cycle and must still be charged. Getting this discrimination wrong in the permissive direction turns the cycle cap into no cap at all.

AFFECTS BOTH VARIANTS: skills/skill-orchestrate/SKILL.md and skills/skill-orchestrate-hard/SKILL.md.

DEPENDENCY NOTE: depends on task 891 purely to serialize edits to those same two SKILL.md files (file-overlap serializer, not a logical prerequisite). Task 897 depends on this one for the same reason.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 894. Fix git-snapshot.sh silent-revert footgun and unhelpful missing-argument failure
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Observed in a single full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles) as one of six agent-system defects. This one BIT THREE SEPARATE AGENTS in that one session and caused REAL DATA LOSS TWICE.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

DEFECT, two parts:
(a) scripts/git-snapshot.sh requires an explicit task-number argument and fails unhelpfully when invoked bare. Two different phase agents hit this in one session.
(b) Its `git stash` step SILENTLY REVERTS THE WORKING TREE, flatly contradicting what the name "snapshot" implies. A reader reasonably expects a snapshot to be non-destructive and read-only with respect to the tree.

OBSERVED DAMAGE (twice in one session): a phase-4 agent found its OWN partial edits gone and had to re-apply stash@{0} to recover; separately, the orchestrator's uncommitted state.json status edit was reverted, so state.json read "not started" again at the END of the run -- which then interacted with the stranded-status detection gap tracked in task 893, compounding both defects.

VERIFIED CURRENT BEHAVIOR: the revert is `git stash push -u` (untracked-inclusive, without drop) at :162, with STASH_REF captured at :167 and echoed at :189. The header comment at :43 documents this, and the script does write a patch to PATCH_PATH first, so recovery is possible -- but nothing at the call site or in the name warns the caller that the tree is about to be reset. Arg/validation failures exit 1 at :114, :136, :148, :153, :157.

IMPORTANT -- DO NOT PREJUDGE A NEW FLAG: a `--branch` mode ALREADY EXISTS at :38 and, per its own documentation, creates a WIP commit INSTEAD of the default stash-based snapshot -- i.e. it already avoids the revert. EVALUATE SURFACING / DOCUMENTING / DEFAULTING TO `--branch` FIRST. Only if that proves insufficient should a `--no-revert` mode be added. Adding a third mode that duplicates what `--branch` already does would be the wrong fix.

DESIRED OUTCOMES: (1) document the revert behavior prominently -- at minimum in the usage block, ideally in the script's own success output; (2) make the missing-argument failure self-explanatory (print usage, name the missing argument, and state what a valid invocation looks like); (3) either surface `--branch` as the recommended non-destructive path or add a loud post-run warning that the tree was reset and how to recover via the printed STASH_REF and PATCH_PATH. Consider whether the name itself should change, since the name is the root of the false expectation.

This task is independent of the other five in the batch: no file_scope overlap, so it can run in parallel with them.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 893. Close stranded-status detection gap for not_started tasks with existing artifacts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Observed in a single full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles) as one of six agent-system defects.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

DEFECT: the task sat at status="not started" in state.json while a plan ALREADY EXISTED and THREE PHASES were already committed to git. skill-orchestrate's entry reconcile ran scripts/reconcile-task-status.sh, which reported "no stranded status found" -- it missed an unambiguously stranded task.

VERIFIED ROOT CAUSE: scripts/reconcile-task-status.sh:386 places not_started in an explicit skip list alongside researched, planned, completed, blocked, abandoned, and expanded ("All other statuses ... it does not track"). The script's own header at :19-21 documents the promotion signals it DOES use (plans/*.md -> planning phase, partial state -> check handoff for continuation_context), so the artifact-presence signal is already understood by the script; not_started simply never reaches it.

DESIRED BEHAVIOR: treat both of the following as stranded and promote to the correct state --
  (a) status=not_started but plans/*.md exists -> promote to planned;
  (b) status=not_started but handoffs/ is non-empty OR phase commits exist -> promote to implementing (or partial, whichever the existing state vocabulary makes correct).
Reuse the existing handoff_permits_promotion helper (:163-171) and handoff_status_value (:175-178) rather than inventing a parallel mechanism -- the header comment at :159-162 already describes the intended generalization of that contract. Preserve the existing conservative default: promotion must not fire on an empty task directory, and a genuinely new task at not_started with no artifacts must remain not_started.

Decide explicitly whether "phase commits exist" is worth detecting at all, given it requires a git query rather than a filesystem check, and whether the plans/*.md signal alone is sufficient to have caught the observed case (it would have been -- a plan existed).

This task is independent of the other five in the batch: no file_scope overlap, so it can run in parallel with them.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 892. Prevent stale/misplaced .orchestrator-handoff.json reads
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: SEVERITY: second-highest of a six-defect batch observed in a single full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles). Silent stale-handoff read: the orchestrator advanced its state machine on phase-6 facts after phase 7 had already finished.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ (and agent-system/extensions/lean/ for the lean components below). The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

DEFECT: a phase-7 lean-implementation-agent wrote .orchestrator-handoff.json to the REPO ROOT instead of specs/{NNN}_{SLUG}/.orchestrator-handoff.json. The orchestrator reads only the task-dir path (skills/skill-orchestrate/SKILL.md:107 sets handoff_file="${TASK_DIR}/.orchestrator-handoff.json"), so it silently read a STALE phase-6 handoff reporting phases_completed=6 after phase 7 had completed. There was no error and no warning; the stale read was caught only by an explicit manual check for a root stray. A stale handoff is strictly worse than a missing one, because the missing case is at least handled (:773 marks the task failed and skips).

DESIRED BEHAVIOR, two complementary fixes:
(a) Instruct every handoff-writing agent with the ABSOLUTE task-dir path so a bare relative write cannot land at the repo root. The shared writer is skill_write_orchestrator_handoff in scripts/skill-base.sh -- check whether it resolves the task dir cwd-relatively, which would make the misplacement a script-layer bug rather than purely an agent-instruction bug. (Note: a closely related cwd-relativity bug in the sibling skill_link_artifacts function in this same file is the subject of task 896, which is why that task is serialized after this one.)
(b) Add a validation step or PostToolUse hook that FAILS LOUDLY if .orchestrator-handoff.json appears anywhere outside a task directory. New hook would live at hooks/validate-handoff-location.sh alongside the existing validate-state-sync.sh / validate-plan-write.sh / validate-meta-write.sh family; registration goes through the merge-sources settings. Study validate-meta-write.sh first: its documented weakness is that a PostToolUse hook sees only a file_path argument, which limits what it can truly enforce -- confirm a location check is actually enforceable from PostToolUse before committing to that mechanism, and consider an orchestrator-side stray-file check as the fallback or complement.

VERIFIED HANDOFF-WRITING COMPONENTS (all confirmed to reference orchestrator-handoff): core/scripts/skill-base.sh, core/agents/general-implementation-hard-agent.md, core/agents/general-research-agent.md, core/agents/general-research-hard-agent.md, core/skills/skill-implementer-hard/SKILL.md, lean/agents/lean-implementation-hard-agent.md, lean/skills/skill-lean-implementation-hard/SKILL.md, lean/context/contracts/anti-analysis.md. The agent that actually misplaced the file in the observed run was a lean implementation agent, so the lean extension components are in scope, not optional.

Consider also whether the orchestrator should staleness-check the handoff it reads (e.g. compare mtime or an embedded phase counter against the last dispatch) so that a stale-but-correctly-located handoff is also caught.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 891. Gate /orchestrate completed transition on phases_completed >= phases_total
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: SEVERITY: HIGHEST of a six-defect batch observed in a single full /orchestrate run (lean4 task, 8 implementation phases, 5 cycles, ~1.6M subagent tokens). Silent premature completion: an 8-phase task would have been marked COMPLETED at phase 4, silently abandoning half the work.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader. ALL edits MUST target agent-system/extensions/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

DEFECT: skill-orchestrate Stage 5 maps dispatch_status="implemented" directly to skill_postflight_update ... implement, which update-task-status.sh maps to status=completed, with NO guard on phases_completed vs phases_total. In the observed run the phase-4 handoff reported status="implemented" with phases_completed=4, phases_total=8. Following Stage 5 literally would have completed the task at phase 4. The orchestrator had to notice and skip the postflight manually on four consecutive cycles.

VERIFIED EVIDENCE OF ASYMMETRY (the key finding): skills/skill-orchestrate/SKILL.md:386-397 ALREADY reads phases_completed and phases_total from the handoff and computes a completion_ratio via awk -- but only under `if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]` at :392. The `implemented)` branch of the same case statement at :410-412 has NO guard at all. The machinery to fix this already exists a few lines above the defect; it is simply not applied to the implemented path.

DESIRED BEHAVIOR: gate the completed transition on phases_completed >= phases_total (and/or continuation_context == null), and treat "implemented but phases remain" as continue-implementing rather than a terminus. Preserve the existing behavior when phases_total is 0 or absent (handoffs that carry no phase accounting must not regress into never completing).

AFFECTS BOTH VARIANTS: skills/skill-orchestrate/SKILL.md (case branch :410-412 plus the Stage 5 restatement at :778) and skills/skill-orchestrate-hard/SKILL.md (:669-673). Confirm whether scripts/update-task-status.sh should also refuse an implement->completed postflight when phase accounting contradicts it, as a defense-in-depth backstop, or whether the guard belongs only in the skill layer.

DEPENDENCY NOTE: tasks 895 and 897 also edit both orchestrate SKILL.md files. This task is the wave-1 root of that chain; 895 depends on it and 897 depends on 895, purely to serialize edits to the same two files.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 887. Research: telemetry source architecture and /distill redesign
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 873
- **Research**: [887_research_telemetry_source_architecture_and_distill_redesign/reports/01_telemetry-source-architecture.md]

**Description**: RESEARCH-FIRST / HIGH PRIORITY. This is the design round. The user will /revise this and then /expand it into implementation tasks. Do NOT jump to implementation.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ (and agent-system/extensions/memory/ for /distill and /learn). The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader, which invokes agent-system/extensions/core/scripts/install-extension.sh from lua/neotex/plugins/ai/shared/extensions/loader.lua. Nothing under .claude/ is hand-authored; every deployed file has a source, enforced by the check-extension-docs.sh hard gate. ALL file edits MUST target agent-system/extensions/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

SETTLED USER DECISION -- SIGNAL SOURCE: "OTel for outcomes + events.jsonl for semantics". Claude Code's OTel stream owns did-it-fail-and-why; events.jsonl owns ONLY what OTel cannot know (task numbers, phase boundaries, plan deviations, reflections, repo tag). Join on session_id + cwd. Research must settle this seam PRECISELY: which fields each owns, the exact join, and whether to borrow gen_ai.* names.

DESIGN THE FOUR-TIER SOURCE MODEL:
1. Claude Code OTel = outcome signal. Official opt-in stream: CLAUDE_CODE_ENABLE_TELEMETRY=1. Events include tool_result carrying {success, error_type, duration_ms, decision_source}, plus api_request/api_error/api_refusal/tool_decision/permission_mode_changed/mcp_server_connection/internal_error/hook_registered/hook_execution_start/hook_execution_complete/compaction/feedback_survey/user_prompt/assistant_response. Metrics: claude_code.session.count, .token.usage, .cost.usage, .code_edit_tool.decision, .active_time.total. Beta traces via CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1. Prompt content redacted by default unless OTEL_LOG_TOOL_DETAILS=1. Docs: code.claude.com/docs/en/monitoring-usage.
2. events.jsonl = agent-system semantics + repo tag.
3. history.jsonl = durable global prompt spine (23,758 prompts, 7 months, 33 projects; outlives transcripts).
4. transcripts/.meta.json = 30-day replay + bootstrap.

DEFINE THE SOURCE CONTRACT FOR EACH OF THE FIVE NEW FLAGS. SETTLED USER DECISION -- KEEP ALL FIVE DISTINCT (--meta, --review, --revise, --dream, --learn) alongside the existing seven (report/purge/merge/compress/refine/gc/auto) = 12 sub-modes. Overlap is resolved by REDEFINITION, not deletion: task 872's --dream currently emits BOTH memory revisions AND improvement proposals; that content migrates to --revise (revisions) and --meta (proposals), leaving --dream for speculative "new directions" only.
- --meta: cross-repo agent-system improvement. Creates tasks in the global agent-system root, checks which of the 20 extensions to contribute to, confirms via AskUserQuestion after basic investigation, and lets the user select/modify proposed tasks.
- --review: read-only inquiry over vault + sources.
- --revise: memory refactoring, inheriting 872's corroborated/contradicted/gap correlation machinery.
- --dream: speculative new directions ONLY (redefined).
- --learn: retroactive/batch harvest across already-completed tasks. Distinct from per-task /learn --task N and from /todo's archive-time harvest.

CRITICAL -- DO NOT REDESIGN CROSS-REPO RESOLUTION: task 873 ALREADY establishes GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}", the `cd "$GLOBAL_ROOT"` mechanism, and the --local opt-out, mirroring the LITERATURE_DIR pattern. /distill --meta MUST CONSUME that mechanism, not invent a parallel one. Likewise --meta MUST delegate task creation to the existing 1,429-line meta-builder-agent (whose global-mode semantics task 875 is teaching) rather than reimplementing it.

UNDERLYING CONSTRAINT THAT MOTIVATED 873: memory-retrieve.sh, memory-harvest.sh, and events-query.sh all resolve PROJECT_ROOT from their OWN deployed location (SCRIPT_DIR/../..), so a copy deployed in nvim/.claude/scripts/ can only ever see nvim's vault. Research MUST confirm whether 873's cd mechanism fully resolves this for the memory/event scripts or whether they need separate treatment.

ALSO DESIGN THE RESTRUCTURE (settled user decision -- YES): split skill-memory/SKILL.md (2,941 lines, carrying BOTH /learn and /distill; /distill occupies lines 1063-2941) into separate skill-learn and skill-distill. Factor the repeated per-sub-mode skeleton (Edge Case Checks -> Candidate Identification -> Dry-Run -> Interactive Selection MANDATORY STOP -> Execution -> Batch Index Regeneration -> Log Entry) into ONE shared section instead of six near-duplicate copies. Sub-modes are currently non-contiguous: purge sits ~1,170 lines after the dispatch table that lists it second, and gc is separated from purge, its logical pair.

ENCODE AS EXPLICIT DESIGN CONSTRAINTS (research-backed; cite these):
- ~70% v1 MISS-RATE EXPECTATION: the closest documented precedent (productowner.ro, "Building an AI Self-Improvement Loop from Claude Code Session History") self-reports keyword-based friction detection catching only ~20-30% of real friction, and "Claude speculates instead of querying actual data" in 6 of 10 analyzed groups. Design for iteration, not a one-shot heuristic.
- EVALUATOR OUTSIDE THE LOOP; PROPOSE-THEN-HUMAN-REVIEW, NEVER AUTO-APPLY. Per Lilian Weng, "Harness Engineering for Self-Improvement" (2026-07-04): file-based persistent memory is production-proven; six failure modes serve as a design checklist (stale-default bias, implementation drift toward simpler solutions under pressure, memory degradation absent persistent artifacts, over-optimism/declaring success on noisy signals, weak domain knowledge, poor scientific taste). HARD RULE: the evaluator must sit OUTSIDE the loop being evolved. "Humans should move up the stack, not be removed from the loop." Documented 2026 anti-pattern: an agent ran 220+ autonomous loops and began FABRICATING METRICS once its own optimistic summaries became the next loop's input. See also OpenReview, "Reward Hacking in Self-Improving Code Agents".
- NO NEW HYGIENE AUTOMATION BELOW ~100 VAULT ENTRIES. Every 2026 source ties scoring/decay/dedup automation to high volume, concurrent writers, or genuinely time-sensitive facts -- none describe this vault (19 memories, 2,616 tokens, single operator, static facts). "Add decay only when you have temporal claims worth decaying; if your agent does not track state changes, exponential decay just throws away stable facts" (Hindsight/Vectorize, 2026-05-21). Vendor benchmarks actively disputed (Zep vs Mem0 on LOCOMO) -- no canonical formula. Leave existing --purge/--merge/--compress/--refine/--gc/--auto behavior UNCHANGED.
- BORROW OTel GenAI FIELD NAMES ONLY, DO NOT REBUILD AS A SPAN/TRACE SYSTEM. Semconv maturity is MIXED: gen_ai.client spans stable (early 2026); gen_ai.agent spans EXPERIMENTAL; the canonical spec migrated to open-telemetry/semantic-conventions-genai with NO tagged releases (126 open issues / 40 open PRs). Borrow names (gen_ai.operation.name, gen_ai.provider.name, gen_ai.request.model, gen_ai.usage.input_tokens/output_tokens, error.type). A structurally OTel-compliant span/trace system with collector infra is disproportionate for a single-maintainer system across ~14 repos.
- HOOKS ARE THE SANCTIONED EXTENSION POINT: 30 documented hook event types; every hook receives session_id, prompt_id (v2.1.196+), transcript_path, cwd, permission_mode, hook_event_name. Stop/SubagentStop carry last_assistant_message explicitly BECAUSE transcript_path is written asynchronously and may lag. Docs: code.claude.com/docs/en/hooks.
- THE sess_{ts}_{rand} JOIN IS A DEAD END -- do not revive it. 1,800 distinct sess_* ids appear across 4,334 transcript files, but the top hits are documentation placeholders (sess_1736700000_abc123 appears 5,032x, decoding to Dec 2023 -- pulled in from CLAUDE.md/skill examples). ~1,109 are real but INCIDENTAL: they arrive as state.json content read INTO context, so the relation is many-to-many ("this session read a file mentioning sess_X", not "is sess_X"). The agent system mints ids at GATE IN that Claude Code never sees. NO structural link exists. Claude Code sessionId is UUIDv4, a different id space; a `session_id` (snake_case) field also coexists on some records and is a DIFFERENT UUID -- do not conflate.
- NO OSS TOOL DOES THE FULL MINE->PROPOSE LOOP. ccusage and claude-code-log parse transcripts and are actively maintained; reuse their parser rather than writing one. Neither extracts success/failure signal.

DEPENDS ON 873 (consumes the GLOBAL_ROOT/cd cross-repo mechanism).

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 885. Enable and verify passive signal capture
- **Status**: [PARTIAL]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 874
- **Research**: [885_enable_and_verify_passive_signal_capture/reports/01_enable-verify-passive-signal-capture.md]
- **Plan**: [885_enable_and_verify_passive_signal_capture/plans/01_passive-signal-capture-deploy.md]

**Description**: URGENT / HIGH PRIORITY. The 30-day transcript window is reaped daily, so every day without capture is permanently lost data.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ (and agent-system/extensions/memory/ for /distill and /learn). The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader, which invokes agent-system/extensions/core/scripts/install-extension.sh from lua/neotex/plugins/ai/shared/extensions/loader.lua. Nothing under .claude/ is hand-authored; every deployed file has a source, enforced by the check-extension-docs.sh hard gate. ALL file edits MUST target agent-system/extensions/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

THE GAP AND ITS ACTUAL ROOT CAUSE (verified; do not re-derive): tasks 869/870/871/872 wrote a complete event/reflection store into agent-system/extensions/core/ but it was NEVER deployed. nvim's .claude/ last synced Jul 14 18:13, before the events work landed (Jul 15 01:19-08:10). The root cause is NOT a forgotten command -- it is the stale self-sync guard (the subject of task 874): nvim cannot regenerate its OWN deploy tree because load_all_globally() early-returns when project_dir == global_dir. Hence the dependency on 874; until that guard is removed nvim's .claude/ cannot be regenerated at all.

VERIFIED ABSENT from nvim's deployed .claude/: events-append.sh, events-query.sh, hooks/events-log-artifact.sh, hooks/events-log-lifecycle.sh, context/formats/events-format.md, context/schemas/events-schema.json. Live .claude/settings.json has 0 hook registrations (3 exist in source root-files/settings.json). Deployed skill-base.sh and orchestrator-postflight.sh have 0 event call sites.

WHY IT FAILS INVISIBLY: every call site is `bash .claude/scripts/events-append.sh ... || true` against a nonexistent path, so it fails SILENTLY. Consequences: specs/events.jsonl exists in NO repo; zero events ever recorded; zero tasks have a `reflection` or `memory_candidates` field; .memory/distill-log.json has operations: []; /distill has never completed a run; task 872's --dream is spec-only (deployed skill-memory/SKILL.md has zero `dream` matches).

SCOPE:
1. Get the events stack actually deployed and flowing; verify end-to-end AFTER regeneration, in nvim AND in at least one other repo.
2. Replace the `|| true` silent-fail idiom with something observable, so a missing helper can never again fail invisibly. This is the defect that hid the gap for a full day.
3. Enable CLAUDE_CODE_ENABLE_TELEMETRY=1 and wire an OTel exporter. NOTE: the env block in ~/.claude/settings.json is Home-Manager-managed from ~/.dotfiles/config/claude/settings.json, so that change likely belongs in the dotfiles repo, not here -- research must confirm the correct home before editing.
4. Raise cleanupPeriodDays to widen the 30-day transcript window. NEVER set 0: per anthropics/claude-code issue #23710, cleanupPeriodDays:0 silently DISABLES persistence entirely, contradicting the docs. Setting 0 would destroy the very data this task exists to preserve.
5. Add a `repo` field to the event schema, events-append.sh, and events-schema.json for cross-repo federation, or resolve it from cwd.
6. Add a deploy-drift check (source vs deployed) so this silent divergence cannot recur; consider extending the existing check-extension-docs.sh doc-lint hard gate rather than adding a new script.

DEPENDS ON 874 (self-sync guard removal). Reference: Claude Code OTel docs at code.claude.com/docs/en/monitoring-usage.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 873. Add global-default target resolution and --local flag to /meta
- **Status**: [PARTIAL]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [873_global_default_target_resolution_for_meta/reports/01_global_default_target_resolution.md]
- **Plan**: [873_global_default_target_resolution_for_meta/plans/01_global_default_target_resolution.md]

**Description**: Make /meta create tasks in the GLOBAL agent-system root by default, with `--local` as the only opt-out. There is NO interactive prompt.

DESIRED BEHAVIOR: /meta run from any repo other than ~/.config/nvim defaults to GLOBAL mode, creating tasks in ~/.config/nvim/specs/. `--local` creates tasks in the current repo's specs/ instead. /meta run from within ~/.config/nvim is already global, so the resolution must be a NO-OP there rather than a special-cased branch. The user regenerates each repo's local .claude/ agent system via the <leader>al loader as needed.

CANONICAL SOURCE vs DEPLOY TREE (critical): the agent-system SOURCE of truth is agent-system/extensions/core/. The nvim repo's .claude/ tree is a GITIGNORED, UNTRACKED deploy artifact (see the /.claude/ entry in .gitignore: the deploy tree is a disposable build artifact regenerated from the source store in agent-system/extensions/, selection pinned by the project-root .claude-extensions.json; nothing under it is hand-authored, every deployed file has a source, enforced by the check-extension-docs.sh hard gate). ALL file edits in this task MUST target agent-system/extensions/core/**, NEVER .claude/**. A change written to .claude/ would be silently wiped by the next <leader>al regeneration. Verified: core/commands/meta.md, core/skills/skill-meta/SKILL.md and core/agents/meta-builder-agent.md are currently byte-identical to their deployed .claude/ copies.

PATH-RESOLUTION MECHANISM (chosen; do NOT redesign): two strategies coexist in the script layer. Strategy A (script-location-relative): generate-todo.sh:28 and update-task-status.sh:27 use PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)", resolving from the SCRIPT's own location. Strategy B (bare relative, CWD-following): skill-base.sh (specs/state.json at :119, :302, :358), command-gate-in.sh:47, command-gate-out.sh:34, and all hooks in settings.json (invoked as `bash .claude/hooks/<name>.sh`). A `cd "$GLOBAL_ROOT"` at the start of the global-mode /meta flow makes BOTH strategies resolve to nvim consistently: Strategy B follows the new CWD, and Strategy A is reached via the CWD-relative `bash .claude/scripts/generate-todo.sh` invocation so it picks up nvim's own script. This cd is the chosen mechanism.

CONSTRAINTS: Do NOT refactor the ~49 scripts. Do NOT introduce CLAUDE_PROJECT_DIR -- it was proposed once in an archived hook research report and deliberately never adopted; it appears nowhere in live code.

GLOBAL ROOT RESOLUTION (user-confirmed): GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}". This mirrors the established LITERATURE_DIR pattern LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}" found at skill-researcher/SKILL.md:171, skill-planner/SKILL.md:182, skill-implementer/SKILL.md:164 and the three -hard variants. The env block in ~/.claude/settings.json is Home-Manager-managed from ~/.dotfiles/config/claude/settings.json.

FLAG PATTERN: parse-command-args.sh already has an established convention -- regex match (`[[ "$remaining" =~ --clean ]]` at :103, `--force` at :106) plus sed-strip (:129-130). Follow it verbatim for --local.

EDIT TARGETS (all under agent-system/extensions/core/):
  - commands/meta.md -- document --local in Arguments, update the argument-hint frontmatter, document the global-default semantics and the source-store-vs-deploy-tree distinction.
  - skills/skill-meta/SKILL.md -- resolve GLOBAL_ROOT, cd into it for global mode, thread the resolved mode/root through to the agent invocation.
  - scripts/parse-command-args.sh -- add --local following the --clean pattern (regex match + sed strip).

RESEARCH MUST SETTLE:
  (a) Whether Claude Code's permission/sandbox model lets a session launched in another repo (e.g. ~/Projects/cslib) write to ~/.config/nvim/specs/ without prohibitive permission friction. This is the single biggest feasibility risk for the whole approach.
  (b) How shell-side CLAUDE_AGENT_GLOBAL_ROOT should relate to the Lua-side global_source_dir option (lua/neotex/plugins/ai/claude/config.lua:40-41, with a hardcoded ~/.config/nvim fallback at picker/utils/scan.lua:8-17) without creating two silently drifting sources of truth.
  (c) Whether the git postflight commit in skill-meta lands in the correct repo after the cd.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.
