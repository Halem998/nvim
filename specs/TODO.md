---
next_project_number: 922
---

# TODO

## Task Order

*Updated 2026-07-27. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 873,885,914,915,917,918,919,920 | -- | agent-system |
| 2 | 887 | 873,885 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

873 [BLOCKED] — Make /meta create tasks in the GLOBAL agent-system root by defaul
  └─ 887 [BLOCKED] — RESEARCH-FIRST / HIGH PRIORITY. This is the design round. The use
885 [PARTIAL] — URGENT / HIGH PRIORITY. The 30-day transcript window is reaped da
  └─ 887 [BLOCKED] — RESEARCH-FIRST / HIGH PRIORITY. This is the design round. The use (see above)
914 [NOT STARTED] — SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is 
915 [NOT STARTED] — SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is 
917 [NOT STARTED] — SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is 
918 [NOT STARTED] — resolve_task_dir() in task-lock.sh hard-fails for a task whose di
919 [NOT STARTED] — Fifteen agent definitions instruct writing .return-meta.json but 
920 [NOT STARTED] — An off-schema dispatch_status read from .orchestrator-handoff.jso

## Tasks

### 920. Validate dispatch_status against the schema enum so an off-schema value fails loudly instead of silently no-opping
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: An off-schema dispatch_status read from .orchestrator-handoff.json silently no-ops the postflight, stranding a task that in fact completed successfully.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

MECHANISM (anchor on symbols and distinctive strings, NOT line numbers -- files in this tree were observed being edited concurrently during investigation; re-locate at implement time). In skill-orchestrate/SKILL.md's Stage 5, the handoff-present branch assigns `dispatch_status=$(echo "$handoff" | jq -r '.status')` with NO validation, then sets have_outcome=true unconditionally. The shared postflight tail's `case "$dispatch_status"` matches only researched, planned, and implemented. Any other value falls to the `*)` branch, which prints a BENIGN-SOUNDING line ('Dispatch status ... -- no postflight update needed') and performs no postflight update. The task stays in its in-flight status (researching/planning/implementing) even though the dispatch fully succeeded, and nothing warns.

SCHEMA: docs/architecture/handoff-schema.md defines the status enum as researched | planned | implemented | partial | failed | blocked. So partial, failed, and blocked are all IN the enum and all UNHANDLED at every site.

THREE SITES, one coherent change (deliberately NOT split into three tasks -- splitting invites exactly the drift the existing in-file comment about a duplicated `case "$dispatch_status"` already warns against):
  1. skill-orchestrate/SKILL.md -- Stage 5 handoff read and the shared postflight tail `*)` branch
  2. skill-orchestrate-hard/SKILL.md -- the mirrored Stage 5 read and `*)` branch
  3. skill-orchestrate/SKILL.md -- multi-task Stage MT-4 step 3, which has the same shape via its 'Other -> no postflight update' clause

FIX DIRECTION: validate dispatch_status against the schema enum and treat an unrecognized value as a LOUD failure -- the same visible-banner family as the existing [UNVERIFIED ...] and [SPARSE COVERAGE ...] banners -- rather than a benign log line. Give partial, failed, and blocked explicit handling at all three sites. Consider inferring the intended phase from the handoff's artifact type as a recovery path. Guiding principle: a dispatch that succeeded must NEVER be silently indistinguishable from one that produced nothing.

BINDING DESIGN CONSTRAINT: the validator MUST draw its allowed status set from the normative table in context/formats/return-metadata-file.md rather than restating the enum inline in SKILL.md. That table already declares itself normative for .return-meta.json, specs/.return-meta-multi.json, and .orchestrator-handoff.json's status field. Restating the enum inline would add a FOURTH drift site for the very vocabulary this work exists to unify.

REPRODUCTION PATH (record as reproduction, NOT as root cause): the observed silent no-op required a base-mode research dispatch to have written a handoff at all -- which happened because the orchestrating session hand-wrote handoff instructions into the dispatch prompt, causing lean-research-agent to write a handoff it was never supposed to write, carrying "status": "success". An agent writing a handoff it was never supposed to write is a real reachable scenario this validation should catch.

SCOPE NOTE -- the recovery path is ALREADY correctly guarded and needs no change: dispatch_status is assigned from recover_json only inside the `if [ "$recovered" = "true" ]` branch, and orchestrate-recover-outcome.sh sets recovered=true only for researched|planned|implemented, emitting STATUS_NOT_SUCCESS with exit 1 otherwise. A recovered dispatch_status is therefore always in-enum and can never reach `*)`. Do not 'fix' the recovery path; the defect is confined to the handoff-present path.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 919. Reference the normative status vocabulary in the 15 agents that write .return-meta.json without it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Fifteen agent definitions instruct writing .return-meta.json but never reference the normative status vocabulary, so they improvise off-schema status values that fail downstream.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ and the sibling extension source directories under agent-system/extensions/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

OBSERVED LIVE. During an autonomous orchestration run, lean-research-agent emitted "status": "success" -- a value absent from the schema. Research had completed successfully with a valid report artifact, but the task was left stranded in its in-flight status.

THE NORMATIVE SOURCE ALREADY EXISTS. context/formats/return-metadata-file.md declares itself the normative status vocabulary for .return-meta.json, specs/.return-meta-multi.json, and -- by reference -- .orchestrator-handoff.json's status field, stating that any writer of those files should draw its status value from that table rather than re-deriving or restating it elsewhere. The defect is not a missing contract; it is fifteen agents that never point at the existing one. lean-research-agent.md, for instance, instructs writing .return-meta.json with "status": "in_progress" at Stage 0 but contains ZERO references to return-metadata-file.md, so it never learns the final-status vocabulary.

SCOPE -- the 15 agent files that write .return-meta.json with zero references to return-metadata-file.md (re-derive this list at implement time rather than trusting it verbatim; the check is: writes `.return-meta.json` AND does not mention `return-metadata-file`):
  cslib/agents/cslib-implementation-agent.md
  cslib/agents/cslib-research-agent.md
  cslib/agents/pr-review-implementation-agent.md
  cslib/agents/pr-review-research-agent.md
  latex/agents/latex-implementation-agent.md
  latex/agents/latex-research-agent.md
  lean/agents/lean-research-agent.md
  python/agents/python-implementation-agent.md
  python/agents/python-research-agent.md
  typst/agents/typst-implementation-agent.md
  typst/agents/typst-research-agent.md
  web/agents/web-implementation-agent.md
  web/agents/web-research-agent.md
  z3/agents/z3-implementation-agent.md
  z3/agents/z3-research-agent.md

FIX DIRECTION: add an @-reference to context/formats/return-metadata-file.md in each, pointing specifically at the normative status table. Strongly prefer a single shared reference over copy-pasting the enum into fifteen files -- copy-paste is precisely how the vocabulary drifts out of sync with its normative source. Mirror how the agents that DO reference it (planner-agent, general-implementation-agent, lean-implementation-agent) already do so, rather than inventing a new convention.

CRITICAL SCOPE BOUNDARY -- DO NOT ADD HANDOFF CONTRACTS TO THESE AGENTS. An earlier framing of this defect proposed giving every orchestrator-dispatched agent an .orchestrator-handoff.json contract. That framing is INVERTED and was rejected after verification against the source:
  - docs/architecture/handoff-schema.md states handoffs are written by SKILLS when orchestrator_mode is true, not by agents.
  - general-research-agent.md explicitly instructs: do NOT use wrap-up.md's H9 schema or .orchestrator-handoff.json for research -- that schema and its consumer allowlist are implementation-agent-only.
  - skill-orchestrate/SKILL.md states base-mode research, plan, and implement dispatches never write a handoff BY CONTRACTUAL DESIGN, and that a missing handoff from one of those writers is the EXPECTED outcome, not a defect. Those dispatches are routed through a .return-meta.json recovery path instead.
Adding handoff writing to these agents would move base-mode dispatches OFF the guarded recovery path ONTO the unguarded handoff-read path, making the silent-no-op defect MORE reachable rather than less. Fix the vocabulary reference only.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 918. Create the task directory before lock acquire so GATE IN stops aborting on tasks whose directory does not exist
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: resolve_task_dir() in task-lock.sh hard-fails for a task whose directory does not exist yet, which aborts GATE IN entirely and blocks /orchestrate and every other command routing through command-gate-in.sh.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

OBSERVED LIVE, not hypothetical. /orchestrate 180 in a consuming repo failed at GATE IN with 'ERROR: could not resolve task directory for task 180'. Worked around manually with mkdir -p specs/180_<slug>/{reports,plans,summaries}, after which GATE IN passed unchanged. Task creation does not always create the directory, so this is reachable through normal use rather than an edge case.

MECHANISM (anchor on symbol names, NOT line numbers -- the file was observed being edited concurrently and line numbers shifted ~45 lines mid-investigation; re-locate at implement time): resolve_task_dir() resolves project_name from state.json, then guards the result with `if [ -d "$dir" ]` and only echoes the path when the directory ALREADY exists. The subsequent `find` fallback likewise matches only existing directories. Otherwise the function falls through to `return 1`. cmd_acquire() then prints 'ERROR: could not resolve task directory for task $task_number' and returns 1. command-gate-in.sh calls `task-lock.sh acquire` after its terminal-status guard, so a non-zero acquire aborts GATE IN.

FIX DIRECTION (do not presume; choose during research/planning): either have the gate create the task directory before acquiring the lock, or give resolve_task_dir a create-if-missing mode. Two directions, one outcome -- establish which layer should own directory creation before committing to either.

BINDING CONSTRAINTS on any fix:

1. CREATE-IF-MISSING MUST BE OPT-IN AT THE ACQUIRE CALL SITE ONLY, never a change to resolve_task_dir's shared default. resolve_task_dir has FOUR call sites: cmd_acquire, plus the check, heartbeat, and release paths (all three of which print the same 'could not resolve task directory' error). A lock check, heartbeat, or release MUST NEVER have filesystem side effects -- a read-only status query that silently creates directories is a worse defect than the one being fixed.

2. CREATION MUST ONLY FIRE WHEN project_name RESOLVED FROM state.json -- never from the `find` fallback branch. The find fallback exists to degrade gracefully when the state.json lookup fails; letting it create directories would allow a typo'd or nonexistent task number to create a stray directory.

3. Verify the created directory shape matches what downstream consumers expect (reports/, plans/, summaries/ subdirectories) rather than creating a bare directory.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 917. Converge single-task /orchestrate partial triage onto the mt engine
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

DIAGNOSED LIVE, NOT INFERRED. Running /orchestrate on a single task left [PARTIAL] by a base-mode run dispatched nothing, consumed 0 cycles, and exited immediately, telling the user to run /implement instead -- despite /orchestrate's entire stated purpose being autonomous lifecycle advancement from wherever the task currently sits. Every fact below was confirmed by reading the deployed files; the deployed copy of the classifier is byte-identical to the source copy.

ROOT CAUSE.

1. scripts/orchestrate-triage-classify.sh carries a two-engine verdict table. For the row `partial` with neither a continuation nor blockers it emits group="implement" when engine is `mt`, but group="exit_partial" when engine is `single`. The fork is a single jq expression:
     ((if $engine == "mt" then "implement" else "exit_partial" end)) as $grp |

2. Per docs/architecture/handoff-schema.md's "Handoff Writers" table, the ONLY active writer of .orchestrator-handoff.json is the hard-mode implementation agent's H9 wrap-up. The row for base-mode skill-researcher, skill-planner, skill-implementer reads verbatim: "Never writes a handoff, by design".

3. Combining (1) and (2): any task left [PARTIAL] by a base-mode run has NO handoff, always and necessarily. The exit_partial branch therefore fires on the NORMAL case, not an edge case. Single-task /orchestrate is structurally incapable of resuming base-mode partial tasks -- the single most common resume scenario in the system.

4. This contradicts two published contracts. commands/orchestrate.md CHECKPOINT 1: "All non-terminal states (not_started, researched, planned, implementing, partial, blocked) are valid entry points for the orchestrator" and "Permissive gate ... The state machine handles all lifecycle phases starting from wherever the task currently is." CLAUDE.md Status Markers: "[BLOCKED], [PARTIAL] - Exception states (non-terminal; any command can resume from these)."

5. The behavior is incoherent across batch size. A solo invocation strands the task; adding any second task number routes the same task to implement via the mt engine. Identical task, opposite behavior, determined solely by how many task numbers were typed -- commands/orchestrate.md STAGE 0 selects the engine purely by len(TASK_NUMBERS).

6. THE STRONGEST EVIDENCE, AND THE FRAMING FOR THIS WHOLE TASK: docs/architecture/orchestrate-state-machine.md line 29 already specifies the correct behavior. Its exit row is "partial (no handoff, cycle limit)" with the condition "cycle_count >= MAX_CYCLES" -- i.e. the documented contract is that a no-handoff partial task exits ONLY once the cycle budget is exhausted. But SKILL.md Stage 4's "Sub-state: no handoff, no blockers" branch and the classifier both fire exit_partial UNCONDITIONALLY, with no cycle-count test anywhere. The architecture doc is RIGHT and the implementation diverged from its own spec. This work is therefore convergence onto an already-documented contract, NOT a new design decision. Do not treat the doc and the code as two equal claims to be reconciled -- correct the code to the doc.

7. The recovery machinery to support this ALREADY EXISTS but is not wired into the entry triage. scripts/orchestrate-recover-outcome.sh normalizes .return-meta.json into an outcome shape precisely BECAUSE missing handoffs are the expected case. It is called from single-task Stage 5, hard-mode Stage 5, and multi-task Stage MT-4 step 1 -- i.e. only POST-dispatch. Stage 4's partial handler, the PRE-dispatch entry triage, never consults it. The entry gate thus rejects exactly the condition the post-dispatch path was purpose-built to tolerate.

8. The divergence was never actually decided. The classifier's own header comment says it "transcribes both engines verbatim rather than picking a winner", and Decision D1 in the originating plan deferred the choice. This task resolves it.

SCOPE OF WORK.

A. Remove the engine fork at scripts/orchestrate-triage-classify.sh so the `partial`-with-neither row routes to implement for BOTH engines, converging `single` onto `mt`.

B. Rewrite skills/skill-orchestrate/SKILL.md Stage 4's "Sub-state: no handoff, no blockers" branch to dispatch implement rather than exit, sourcing resume context from scripts/orchestrate-recover-outcome.sh against the prior dispatch's .return-meta.json in place of the handoff a base-mode run never writes. Delete the now-false cross-reference immediately above the sub-state block that asserts the two engines are "intentionally different" and "diverge by design".

C. Update the classifier's own header verdict table in the SAME commit as the code change. The header explicitly states the table and the script MUST be changed together, never independently -- that co-change rule is itself part of what is being enforced here.

D. Update the Stage MT-4 phase-grouping table in skills/skill-orchestrate/SKILL.md so the script header table, Stage 4, and Stage MT-4 all state the same routing. All three must agree at the end of this task.

E. LOCKSTEP EDIT, IN SCOPE: scripts/orchestrate-dry-run-report.sh hard-codes its own exit_partial exclusion arm with a bespoke explanatory string, plus a step-7 comment naming exit_partial. A dry-run's whole value is predicting what the live path does, so leaving that arm behind would reintroduce exactly the class of drift this task exists to eliminate. It must be edited alongside the classifier, not merely re-run against it.

F. Correct docs/architecture/orchestrate-state-machine.md so its state table reflects the new routing. Per finding 6 this is bringing the code up to the doc, so the doc's exit-on-cycle-limit semantics are the target; adjust only the wording needed to describe the now-reachable resume path.

G. Confirm the MAX_CYCLES loop guard still bounds the newly-reachable resume path. Resumption must not become unbounded -- MAX_CYCLES remains the mechanism that prevents a genuinely stuck task from looping forever, and after this change it becomes the ONLY such bound on this path, where previously the unconditional exit masked it.

H. Update commands/orchestrate.md entry-point contract language if the permissive-gate claim in CHECKPOINT 1 needs tightening to match actual behavior.

TWO DECISIONS THE TASK MUST MAKE EXPLICITLY (neither is pre-committed).

DECISION 1 -- the `blocked` row. One row below the `partial` row in the same verdict table, `blocked` routes to `skip` for mt but `needs_human` for single. This is the second instance of the same shape of defect and must not be left inconsistent while row one is fixed. LEADING HYPOTHESIS, worth recording but NOT pre-committed: this may be a JUSTIFIED divergence rather than a defect -- in a batch, skipping a blocked task lets siblings proceed, whereas solo there is no sibling, so escalation to a human is the only meaningful action. Scope this as: decide explicitly, then make the script header table, SKILL.md Stage 4's `blocked` handler, and the MT-4 table all state the same conclusion WITH the justification written down. An intentional divergence documented as intentional is a fine outcome. An undocumented one is not.

DECISION 2 -- the fate of the exit_partial schema value. exit_partial is part of the PUBLISHED orchestrate-triage-v1 output contract, enumerated in the classifier's documented `group` field values. If change (A) renders it unreachable, the task must choose between retaining it as an explicitly-reserved value and versioning the schema. Silently leaving a dead value in a pinned contract is not acceptable.

ACCEPTANCE CRITERION: /orchestrate N on a single task in `partial` state with no handoff and no blockers dispatches implement and makes forward progress, instead of exiting with a referral to /implement -- while MAX_CYCLES still terminates a task that cannot progress.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 916. Populate completion_summary from return metadata on every /orchestrate path
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 913
- **Research**: [916_fix_orchestrate_completion_summary_propagation/reports/01_completion-summary-propagation.md]
- **Plan**: [916_fix_orchestrate_completion_summary_propagation/plans/01_completion-summary-propagation.md]
- **Summary**: [916_fix_orchestrate_completion_summary_propagation/summaries/01_completion-summary-propagation-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

OBSERVED DIRECTLY, IN A LIVE RUN (not inferred). A multi-task /orchestrate invocation drove three tasks through research -> plan -> implement to a [COMPLETED] terminal status. All three implementation agents correctly wrote completion_data.completion_summary into their .return-meta.json files. All three state.json entries were nevertheless left with an EMPTY completion_summary, and the orchestrator reported full success. The summaries had to be copied into state.json by hand afterward.

WHY THIS MATTERS. state.json's own documented schema marks completion_summary as "Required when status=completed", and /todo consumes completion_summary (and roadmap_items) to annotate ROADMAP.md at archival time. So this silently produces schema-invalid completed records AND starves the downstream roadmap consumer -- the same end-user symptom as the implementer-side producer-contract gap repaired previously, but arising in the orchestrator's own postflight rather than in any implementer.

SITE. skill-orchestrate/SKILL.md Stage MT-4 (multi-task per-task postflight) reads dispatch_status, artifacts, and phase accounting from the handoff, and calls skill_postflight_update and skill_link_artifacts -- but never reads completion_data out of .return-meta.json and never writes completion_summary/roadmap_items to state.json. Note that commands/orchestrate.md DOES document a "Populate Completion Summary (if implemented)" step at its CHECKPOINT 2, but that checkpoint is on the SINGLE-task path only; multi-task mode returns via Stage MT-5 and consolidated output, bypassing it entirely.

ESTABLISH, THEN FIX:
1. Confirm the single-task path actually populates completion_summary in practice, or whether it has the same hole (commands/orchestrate.md documents the step, but verify the executed path -- do not infer from the presence of the text).
2. Check skill-orchestrate-hard/SKILL.md for the same gap in both its single-task and any multi-task path.
3. Fix so that a task reaching completed via ANY /orchestrate path carries a populated completion_summary, and roadmap_items when the implementer produced them.

DESIGN CONSTRAINT. Prefer ONE shared step that both the single-task and multi-task paths call, over adding a second independently-maintained copy to Stage MT-4 -- the divergence between an orchestrate.md-documented checkpoint and an MT-stage that silently lacks it is precisely the defect being repaired here. There is related prior art: an equivalent producer-side step exists in the implementer skills, and a standing recommendation to factor that one into a shared script. Consider whether both should converge on the same helper.

ACCEPTANCE CRITERION: a multi-task /orchestrate run that drives 2+ tasks to completed must leave every one of them with a non-empty completion_summary in state.json, with no manual intervention.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 915. Close the mirror-image completion_data propagation gap in nix, nvim, and epidemiology implementers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

ESTABLISHED CONTEXT (do not re-derive). A prior investigation mapped the roadmap_items producer/consumer contract across every implementer path and found it has TWO links per extension: (1) the dispatched AGENT file must generate completion_data.completion_summary/.roadmap_items into .return-meta.json, and (2) the implementer SKILL.md postflight must read that back out and write it to state.json. Both links must hold or the field is silently dropped.

That work repaired core, core-hard, lean, lean-hard, and web. It also identified -- but deliberately left out of scope -- a MIRROR-IMAGE break in three other extensions: nix, nvim/neovim, and epidemiology. In those three the agent side is CORRECT (their agent files do generate completion_data) but the SKILL.md side never propagates it to state.json. This is the exact inverse of the lean defect, and its symptom is identical: completion_summary and roadmap_items silently absent from state.json for every task routed through those extensions.

VERIFY BEFORE FIXING. The mirror-image characterization above came from a survey pass, not a line-by-line audit of the executed path. For each of the three extensions, confirm independently: does the agent file actually write completion_data, and does the SKILL.md postflight actually fail to read it? Report per-extension findings. A finding of "already correct" for any of the three is a valid outcome -- do not manufacture a fix.

SUSPECTED SITES:
  agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md
  agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md
  agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md
Corresponding agent files (read-only reference, expected already correct):
  agent-system/extensions/nix/agents/nix-implementation-agent.md
  agent-system/extensions/nvim/agents/neovim-implementation-agent.md

FIX SHAPE. The prior work established the preferred shape: the shared schema is already documented in context/formats/return-metadata-file.md, so the correct fix is a short postflight read-and-write step referencing that schema, matching how the already-correct core and web SKILL.md files do it -- NOT duplicating the schema into each file. Follow that precedent.

The prior work also recorded a standing recommendation to extract this postflight step into a single shared script that all implementers call, rather than maintaining N copies. Evaluate whether to do that here or to record it as its own follow-up; state your choice and rationale.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 914. Reconcile /todo's independent roadmap-annotation logic with roadmap-integration.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

ESTABLISHED CONTEXT (do not re-derive). A prior investigation into roadmap-integration.sh established, with the script's own consumers traced, that /review (commands/review.md) is the ONLY consumer that calls roadmap-integration.sh. /todo does NOT call it: skill-todo/SKILL.md reimplements roadmap matching and annotation independently, in prose, at its Stages 5 and 11. That prior work fixed roadmap-integration.sh (source-aware table-row annotation, plus an always-on roadmap-structure marker, unparseable/no-op banners, and additive JSON fields) and extended review.md to surface the new signal. None of that reaches /todo.

THE PROBLEM. There are now two independent implementations of roadmap annotation with divergent behavior. The script version can locate and rewrite a matched table row in place and loudly reports an unparseable or no-op roadmap; /todo's prose version has neither capability and can still silently annotate nothing while reporting success. Any future fix to one will keep missing the other.

INVESTIGATE FIRST, THEN DECIDE. Do not assume the answer is "make /todo call the script."
1. Read skill-todo/SKILL.md Stages 5 and 11 and commands/todo.md, and characterize precisely what /todo's annotation logic does and how it differs from the script's current behavior.
2. Determine whether /todo's matching requirements are actually the same as /review's. They may legitimately differ -- /todo annotates at archival time from completion_summary/roadmap_items, /review annotates from a codebase scan. If the requirements genuinely differ, converging them is wrong and the correct outcome may be to keep two implementations but give /todo the same silent-no-op detection.
3. Decide and justify ONE of: (a) replace /todo's prose logic with a call to roadmap-integration.sh; (b) keep both but port the structure-marker/banner/silent-noop signal into /todo so it cannot report false success; (c) extract the shared matching logic into one place both consume.

Whichever is chosen, the binding acceptance criterion is that a roadmap which parses to zero phases and contains zero checkboxes MUST NOT be reportable by /todo as a successful annotation pass.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 913. Fix Stage 5 treating a missing handoff after a research dispatch as an error
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [913_fix_stage5_missing_handoff_after_research_dispatch/reports/01_stage5-research-handoff-mismatch.md]
- **Plan**: [913_fix_stage5_missing_handoff_after_research_dispatch/plans/01_stage5-return-meta-fallback.md]
- **Summary**: [913_fix_stage5_missing_handoff_after_research_dispatch/summaries/01_stage5-return-meta-fallback-summary.md]

**Description**: Fix Stage 5 of skill-orchestrate treating a missing .orchestrator-handoff.json after a RESEARCH dispatch as an error condition, when for research dispatches a missing handoff is the contractually correct outcome.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

OBSERVED LIVE, not hypothetical. During an autonomous orchestration run, the research dispatch completed successfully (report written, .return-meta.json written with status=researched) but wrote no handoff. Stage 5 took its missing-handoff branch, which performs NO postflight status update. Left unattended this strands the task at status=researching; the next cycle then reads researching, classifies it as an in-flight state owned by another session, and exits with a warning. The run was only rescued by manually applying the postflight from .return-meta.json.

WHY THE HANDOFF IS LEGITIMATELY ABSENT: research agents are contractually forbidden from writing .orchestrator-handoff.json under ALL circumstances, independent of orchestrator_mode. This is an explicit standalone prohibition in the Stage 3.6 "Scoping Decision" of both general-research-agent.md and general-research-hard-agent.md, corroborated by the consumer allowlist in context/contracts/wrap-up.md (implementation-agent-only) and the Handoff Writers table in docs/architecture/handoff-schema.md (only general-implementation-hard-agent and its cslib/lean counterparts are active writers). So a research dispatch never producing a handoff is correct behavior, not a fault.

THE STRUCTURAL MISMATCH: Stage 5 is written as if every dispatch produces a handoff, and its missing-handoff branch assumes something went wrong (its diagnostics say "orchestrator_mode was not propagated correctly, or the handoff was written outside the task directory"). Both explanations are wrong for a research dispatch. The branch also runs the phase-marker recovery grep, which is meaningless for a research phase that has no plan yet, and charges the cycle against MAX_CYCLES.

SCOPE spans base and hard mode: skill-orchestrate/SKILL.md Stage 5, and skill-orchestrate-hard/SKILL.md, whose H4 adversarial-verification re-dispatch, H5 divergence-audit dispatch, and Stage 6 blocker-research dispatch are all $RESEARCH_AGENT dispatches followed by a Stage 5 handoff read — every one of them hits this branch on every invocation. Multi-task mode Stage MT-4 step 1 has the same shape and is worse: it marks the task into failed_tasks on a missing handoff.

DO NOT PRESUME THE FIX. Candidate directions, to be chosen by research rather than assumed: (a) make Stage 5 phase-aware, so a research-phase dispatch consults .return-meta.json (the channel command-gate-out.sh already reads) instead of expecting a handoff; (b) have research agents write a handoff after all, which would require amending the Stage 3.6 prohibition and the Handoff Writers table — a much larger contract change; (c) narrow the handoff expectation to implement dispatches only and give research/plan dispatches their own outcome-reading path. Establish first which components actually write which outcome file before choosing.

Also confirm whether the plan dispatch has the same problem or not: in the observed run the planner DID write a valid handoff, so planner-agent and research agents appear to differ here — verify rather than assume symmetry.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 912. Establish whether the roadmap_items producer contract actually runs outside the core implementer
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [912_verify_roadmap_items_producer_contract_across_implementers/reports/01_roadmap-items-producer-gap.md]
- **Plan**: [912_verify_roadmap_items_producer_contract_across_implementers/plans/01_roadmap-items-producer-fix.md]
- **Summary**: [912_verify_roadmap_items_producer_contract_across_implementers/summaries/01_roadmap-items-producer-fix-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ and agent-system/extensions/<ext>/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

THIS IS AN INVESTIGATION FIRST AND A FIX SECOND. Closing it with "no upstream defect exists, the downstream repo needs a re-sync" is a VALID and USEFUL outcome. Do not manufacture a fix for a defect that does not exist.

OBSERVED, WITH ITS CONFOUND STATED. Across 21 tasks archived from a downstream repository in a single /todo run, ZERO carried a `roadmap_items` field, and roadmap matching consequently found nothing to annotate. CLAUDE.md documents a producer/consumer contract: /implement is the producer that populates `completion_summary` and optional `roadmap_items`; /todo is the consumer that matches them against ROADMAP.md.

THE CONFOUND IS REAL AND MUST BE RESPECTED. That downstream repo's deployed skill-implementer is 28 lines behind upstream (deployed 726 lines vs upstream 754; upstream additionally carries a newer --phase-check=refuse backstop). The observed absence may therefore be an artifact of the stale deployment rather than an upstream defect. Unlike the roadmap-integration.sh and todo.md findings -- both byte-identical between upstream and deployment, hence genuine -- this one is NOT established as an upstream bug and must not be asserted as one.

ESTABLISH, IN THIS ORDER:

1. Does the upstream core skills/skill-implementer/SKILL.md actually populate `roadmap_items` when it runs? The step exists around line 484. READ THE CODE PATH -- confirm the step is reachable, that it writes the field, and under what conditions it is skipped. Do NOT infer from the mere presence of the string.

2. Do the per-extension implementers populate it, or silently skip it? This is the highest-value question. A preliminary grep across all 20 implementer skills in the source store found the literal `roadmap_items` in only THREE of them -- core/skill-implementer, lean/skill-lean-implementation, and lean/skill-lean-implementation-hard -- plus web/skill-web-implementation, and in core/skill-todo (the consumer side). Notably ABSENT is core/skill-implementer-hard, along with the cslib, email, epidemiology, founder, latex, nix, nvim, python, typst, and z3 implementers. Verify that grep independently; a string count is a starting point, not a finding. The downstream repo is lean4-dominated and routes to skill-lean-implementation rather than the core implementer, so if the lean implementer mentions the field but does not actually populate it on the executed path, that would explain the 0% rate AND would be a genuine upstream gap. Equally, a core-only-in-practice implementation with 16 extension implementers silently omitting the step is a genuine upstream gap regardless of the downstream evidence.

3. ONLY IF a real gap is confirmed by steps 1-2, propose the fix. Consider whether the right shape is duplicating the step into every extension implementer (high duplication, high drift risk) or factoring the producer step into a shared contract/context file that all implementers import -- the latter is more consistent with how this system already handles shared skill behavior.

COORDINATION NOTE: if the resolution turns out to require editing the CLAUDE.md producer/consumer contract text in agent-system/extensions/core/merge-sources/claudemd.md, that file is inside another active task's declared file_scope (the terminal-status-taxonomy work). Sequence behind it or coordinate rather than editing concurrently. As scoped here, this task's edits stay within skill definitions.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 911. Correct the terminal-status taxonomy so /todo can archive expanded tasks
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [911_correct_terminal_status_taxonomy_and_todo_archival/reports/01_terminal-status-taxonomy-todo-archival.md]
- **Plan**: [911_correct_terminal_status_taxonomy_and_todo_archival/plans/01_terminal-status-taxonomy-archival.md]
- **Summary**: [911_correct_terminal_status_taxonomy_and_todo_archival/summaries/01_terminal-status-taxonomy-archival-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

DEPLOYMENT-DRIFT CONTROL (already performed -- do not redo): this defect was observed while running the deployed copy in a downstream repository whose .claude/ tree is roughly a week behind upstream. That staleness does NOT confound this finding: commands/todo.md was compared and is BYTE-IDENTICAL between the upstream source store and the stale deployment. This is a genuine upstream bug.

OBSERVED. commands/todo.md line 175 filters `select(.status == "completed")`, and its documented scan (lines 28-29) covers only `completed` and `abandoned`. But the generated CLAUDE.md status table lists `[EXPANDED]` as a TERMINAL state, alongside `[BLOCKED]`, `[ABANDONED]`, and `[PARTIAL]`. Nothing in the archival path ever matches `expanded`.

MEASURED CONSEQUENCE. In the downstream repository, three tasks (161, 175, 321) carry status `expanded` and have never been archivable by any /todo run. A /todo invocation there archived 21 tasks and left all three behind. Their content was genuinely absorbed elsewhere -- 175 folded into 402 Part C, 161 into 402 Part A -- so this is finished work permanently inflating the active task list, and it will keep accumulating in every repo built on this system.

DO NOT BLINDLY ADD `expanded` TO THE FILTER. Two things must be settled first.

1. ARCHIVAL REACHABILITY. An expanded task's directory may hold reports, plans, or summaries that its CHILD tasks still reference. Moving that directory into specs/archive/ could break those references. Establish whether child tasks in practice link back to the parent's artifacts, and if so, whether archival needs to preserve reachability (leave a pointer, defer archival until all children are terminal, or relocate rather than bury).

2. THE TAXONOMY ITSELF MAY BE WRONG. `[PARTIAL]` and `[BLOCKED]` sit in the same terminal-state row of the CLAUDE.md status table but are clearly NOT terminal in practice -- a partial task resumes on the next /implement, and a blocked task unblocks. If the table is mislabeling which states are terminal, the correct fix is to repair the taxonomy (and any code that trusts it) rather than to widen one filter to match a wrong table. Investigate the actual lifecycle of each of the four states before changing anything.

FILES. commands/todo.md is the confirmed site. Check skills/skill-todo/SKILL.md for the same filter and fix both if it carries it. If the status table itself is what needs correcting, the edit target is the CLAUDE.md merge source under agent-system/extensions/core/merge-sources/, never a generated CLAUDE.md.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**. The downstream task numbers above are evidence cited within this specs/ description only.

---

### 910. Fix roadmap-integration.sh reporting success while annotating nothing
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [910_fix_roadmap_annotation_silent_noop/reports/01_roadmap-annotation-silent-noop.md]
- **Plan**: [910_fix_roadmap_annotation_silent_noop/plans/01_roadmap-annotation-signal.md]
- **Summary**: [910_fix_roadmap_annotation_silent_noop/summaries/01_roadmap-annotation-signal-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

DEPLOYMENT-DRIFT CONTROL (already performed -- do not redo): this defect was observed while running the deployed copy in a downstream repository whose .claude/ tree is roughly a week behind upstream (28 files differ, 6 absent). That staleness does NOT confound this finding: scripts/roadmap-integration.sh was compared and is BYTE-IDENTICAL between the upstream source store and the stale deployment (548 lines in both). This is therefore a genuine upstream bug, not an artifact of a stale sync.

OBSERVED BEHAVIOR. Run against a downstream 1,617-line specs/ROADMAP.md, the script exited 0 and emitted a success-shaped payload: {"annotations_made": 0, "items_skipped": 1, "skipped_reasons": ["line_not_found_exact"]} with phases: 0 and matches: 1. That ROADMAP.md contains ZERO checkboxes -- both `grep -c '^\s*- \[ \]'` and the `- [x]` equivalent return 0.

ROOT-CAUSE CANDIDATE (verify against the code; do NOT assume): line 133 hard-codes the phase-header regex `^## Phase (\d+): (.+?)(?:\s+\((\w+ Priority)\))?$`. The downstream roadmap uses headings of the form `## Overview`, `## BX Axiom System`, and `### Layer 1: Propositional (4)`. No `## Phase N:` heading exists anywhere in it, so zero phases parse.

CRITICAL NUANCE -- THIS IS NOT A MISSING-FEATURE TASK. The script ALREADY contains a fix attempt aimed at exactly this situation. Around lines 390-398 there is a table-row-based completion matcher whose own inline comment states that the current table format has zero checkboxes and that without the loop, annotations_made is always 0 regardless of how many completed items the table actually lists. That loop EXISTS and still produced 0 annotations, with 1 match recorded and then skipped as `line_not_found_exact`. So the work is NOT "add table support" -- it is "the existing table support finds a match and then fails to locate the line to annotate." Start the investigation from that skipped reason and trace what line lookup the matcher performs after a successful match.

THE DEEPER DEFECT IS BEHAVIORAL, NOT MERELY A PARSING BUG. The script returns exit 0 and a success-shaped JSON payload while doing nothing at all. Both /todo and /review consume that payload and duly report success to the user. A roadmap that parses to 0 phases AND contains 0 checkboxes is a condition the tool can detect cheaply and should surface loudly -- in the same family as the existing [SPARSE COVERAGE ...] and [UNVERIFIED ...] banners this system already uses elsewhere -- rather than passing silently as a no-op success.

DECIDE AND RECOMMEND ONE of the following (the implementation should justify its choice, not implement all three by default):
  (a) Fix the annotation line-lookup so the existing table matcher can actually annotate.
  (b) Emit a loud, machine-readable unparseable-roadmap warning when phases == 0 and checkbox count == 0, so downstream consumers cannot report false success.
  (c) Both.

Also confirm how /todo and /review consume the payload, so that whichever signal is chosen is actually surfaced to the user rather than swallowed by the caller.

SCOPE BOUNDARY: whether any individual downstream project's ROADMAP.md should be reformatted into the phase/checkbox shape is that project's own decision and is explicitly OUT OF SCOPE here. This task fixes the tool and its silence, not any particular roadmap document.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 909. Resolve the two hard-mode dispatch contexts that carry neither an absolute handoff anchor nor orchestrator_mode
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 898
- **Research**: [909_resolve_unanchored_hard_mode_dispatch_contexts/reports/01_handoff-gating-and-fix-branch.md]
- **Plan**: [909_resolve_unanchored_hard_mode_dispatch_contexts/plans/02_orchestrator-mode-anchor-invariant.md]
- **Summary**: [909_resolve_unanchored_hard_mode_dispatch_contexts/summaries/02_orchestrator-mode-anchor-invariant-summary.md]

**Description**: Residual gap surfaced by the implementation agent for the completed handoff-location task (891-series work on .orchestrator-handoff.json placement), which correctly flagged it rather than silently editing outside its plan's scope.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

VERIFIED STATE OF THE INVARIANT. In skills/skill-orchestrate/SKILL.md (base mode) the pattern is clean and evidently deliberate: every dispatch context carrying `orchestrator_mode: true` also carries `task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS`, and every dispatch that omits the anchor explicitly sets `orchestrator_mode: false` (the drift-inspection, drift-revision, blocker-research, and blocker-revision dispatches). The invariant "absolute anchor present if and only if orchestrator_mode is true" holds and is locally checkable.

THE GAP. In skills/skill-orchestrate-hard/SKILL.md three dispatch contexts carry both `orchestrator_mode: true` and the absolute anchor, but TWO carry neither the anchor NOR any orchestrator_mode key at all: the divergence-audit dispatch and the blocker-research dispatch, both of which dispatch $RESEARCH_AGENT. Because these two omit orchestrator_mode entirely rather than setting it to false, the invariant is not merely violated -- it is unverifiable at those sites. A reader cannot tell whether the missing anchor is correct-by-design or an oversight.

WHY THIS MATTERS: $RESEARCH_AGENT is on the verified list of handoff-writing components. If handoff writing is genuinely gated on orchestrator_mode being true, these two dispatches never write a handoff and the missing anchor is harmless -- but that should be made explicit rather than left implicit. If the gating is weaker than assumed, these are live instances of the exact defect the handoff-location work exists to prevent: a path-less write instruction that can land a handoff at the repo root.

REQUIRED FIRST STEP -- DO NOT PRESUME THE ANSWER: determine authoritatively whether an agent dispatched WITHOUT orchestrator_mode: true actually writes .orchestrator-handoff.json. Read the write instructions in context/contracts/wrap-up.md, agents/general-research-agent.md, agents/general-research-hard-agent.md, and scripts/skill-base.sh's skill_write_orchestrator_handoff to establish the real gating condition. Only then choose between the two fixes:
  (a) If these dispatches never write a handoff: add an explicit `orchestrator_mode: false` to both sites, matching base mode's convention, so the invariant becomes checkable rather than ambiguous.
  (b) If they can write a handoff: add `task_dir` and `handoff_path` to both sites, matching the three already-anchored hard-mode sites.

Whichever branch is taken, consider adding a short verification note near the dispatch sites (or a grep-based check) recording the invariant, so a future reader or reviewer can confirm it mechanically instead of re-deriving this analysis.

SCOPE: hard mode only. Base mode was verified consistent and needs no edit.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 908. Prevent git index contention between concurrently dispatched orchestrate agents
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 907
- **Research**: [908_prevent_git_index_contention_in_parallel_dispatch/reports/01_git-index-contention.md]
- **Plan**: [908_prevent_git_index_contention_in_parallel_dispatch/plans/01_git-index-contention.md]
- **Summary**: [908_prevent_git_index_contention_in_parallel_dispatch/reports/02_commit-site-inventory.md]

**Description**: Observed directly during a 4-task concurrent /orchestrate batch (tasks 892, 893, 894, 903 dispatched in one wave). Two separate implementation agents independently reported that their commits were swept into other agents' commits: one reported two of its own phase commits bundled under other agents' commit messages, another reported its phase-7 commit swept into a concurrent session's commit. Content survived intact in every observed case (independently re-verified), but commit attribution is now wrong in the history.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader. ALL edits MUST target agent-system/extensions/** and NEVER .claude/**.

ROOT CAUSE (mechanism, stated precisely): the git index is a single shared resource per working tree. `git add <paths>` followed by `git commit` is not atomic with respect to other processes in the same tree. When agent A stages its files and agent B then runs `git add` + `git commit`, B's commit captures A's staged-but-uncommitted paths too, because a bare `git commit` commits the whole index rather than only the paths the caller named.

WHY THE EXISTING GUARD CANNOT CATCH THIS -- this is the key point: the runtime wave-split check in commands/orchestrate.md and skills/skill-orchestrate/SKILL.md (Stage MT-3 step 4.5) compares tasks' file_scope using the directory-prefix overlap algorithm in context/patterns/file-footprint-overlap.md. In the observed batch that check passed correctly -- the four tasks' file_scope sets were genuinely disjoint and no agent edited another's files. The collision was not in the FILES, it was in the shared INDEX. A file-path-based overlap check is structurally incapable of detecting index contention, so this gap cannot be closed by tightening the existing check; it needs a different mechanism.

CANDIDATE MECHANISMS TO EVALUATE (research should compare, not assume):
  (a) Path-scoped commits: `git commit -- <paths>` / `git commit -o <paths>`, which commit only the named paths and ignore the rest of the index. Cheapest change; verify it composes with the targeted-staging convention already documented in context/standards/git-staging-scope.md.
  (b) A commit mutex. There is existing precedent in this codebase for exactly this shape -- acquire_state_mutex in scripts/update-task-status.sh, and scripts/task-lock.sh -- so a commit lock should follow one of those established patterns rather than inventing a new one.
  (c) Per-agent git worktrees, giving each concurrent agent its own index. Strongest isolation, highest cost; assess whether the agent-dispatch layer can support it.
  (d) Serializing commits through the orchestrator: agents write files and report modified paths, the orchestrator commits. Removes concurrency at the commit step entirely.

Evaluate whether the fix belongs in the git-staging-scope standard, in the orchestrate skill's multi-task dispatch stage, in a shared script, or some combination. Note that agents currently commit their own work per phase, so any fix must either keep that property or deliberately change it with justification.

SCOPE NOTE: single-task /orchestrate is unaffected (one agent at a time). This is specific to multi-task/parallel dispatch. Determine whether team-mode skills (skill-team-implement) share the same exposure.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 907. Establish an orchestrator runtime-file tracking policy so ephemeral loop guards are never committed
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 885, Task 902, Task 906, Task 909
- **Research**: [907_orchestrator_runtime_file_tracking_policy/reports/01_runtime-file-tracking-policy.md]
- **Plan**: [907_orchestrator_runtime_file_tracking_policy/plans/01_runtime-file-tracking-policy.md]
- **Summary**: [907_orchestrator_runtime_file_tracking_policy/summaries/01_runtime-file-tracking-policy-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

== DEFECT: orchestrator runtime scratch files have no tracking policy and are inconsistently committed ==

EVIDENCE (gathered in the DEPLOYED consumer repo /home/benjamin/.dotfiles, where .claude/ and specs/ ARE tracked -- unlike this repo, where .claude/ is gitignored): committed counts across specs/ were 45 `.return-meta.json`, 27 `.orchestrator-handoff.json`, 3 `.orchestrator-loop-guard`, plus 2 committed `.lock` entries, with ZERO .gitignore coverage for any of them.

PRIORITY WITHIN THIS TASK -- the committed `.orchestrator-loop-guard` files are an ACTIVE CORRECTNESS HAZARD, not mere repo noise:
- The guard carries cycle_count / max_cycles / current_state (see docs/architecture/orchestrate-state-machine.md line 102 and docs/architecture/architecture-spec.md line 268).
- skills/skill-orchestrate/SKILL.md Stage 2 (loop_guard_file defined at line 110) RESUMES from an existing guard rather than starting fresh; skills/skill-orchestrate-hard/SKILL.md does the same (line 198).
- Therefore a guard committed to git -- or restored by a checkout, clone, or branch switch -- makes a fresh /orchestrate believe it is already mid-run at a stale cycle count, silently consuming its cycle budget before doing any work.

ROOT CONTRADICTION (verified): commands/orchestrate.md stages the WHOLE task directory in both of its commit paths, sweeping runtime files in, while implementation agents treat those same files as uncommitted runtime state. The command and the agents actively contradict each other, which is precisely why tracking is inconsistent.
- commands/orchestrate.md CHECKPOINT 3 (section header line 417): `stage_paths=("specs/${PADDED_NUM}_${PROJECT_NAME}/" "specs/TODO.md" "specs/state.json")` then `git add "${stage_paths[@]}"` at line 428.
- commands/orchestrate.md Step 5 multi-task batch commit (section header line 253): appends `specs/${tpadded}_${tname}/` per task in the loop, then `git add "${stage_paths[@]}"` at line 291.
- context/standards/git-staging-scope.md endorses the whole-task-dir form at lines 25-27 and again at lines 88-90.

USEFUL PRECEDENT: context/standards/git-staging-scope.md lines 72-76 already shows a NARROWER research-variant staging form that lists `specs/{padded}_{slug}/reports/` and `specs/{padded}_{slug}/.return-meta.json` explicitly instead of the whole directory. That form is the model for the fix -- the narrow pattern already exists in the standard and simply is not applied to the orchestrate paths.

FOURTH RUNTIME FILE FOUND DURING VERIFICATION (not in the original evidence set): `.orchestrator-churn-state.json`, the hard-mode churn-detection state written by skills/skill-orchestrate-hard/SKILL.md Stage 2 (see context/patterns/task-lock.md lines 341 and 359, and scripts/task-lock.sh line 549, which groups it with .orchestrator-loop-guard under the same atomic-creation pattern). It is ephemeral runtime state of exactly the same character as the loop guard and MUST be covered by whatever policy this task establishes. Audit for any further runtime scratch files under specs/*/ before finalizing, rather than assuming this list is complete.

== SCOPE NOTE ==

This policy governs `specs/*/` runtime artifacts in ANY repo that consumes the agent system. It is NOT about the .claude/ deploy tree, which is already gitignored in this repo. The fix must be authored in the source store so every consumer repo inherits it -- that is the entire reason this task is routed here rather than patched in one consumer.

== USER-CHOSEN POLICY (already decided -- implement it, do not re-litigate) ==

GITIGNORE and UNTRACK (pure ephemeral runtime state; committed loop-guards are the actual hazard):
- specs/*/.orchestrator-loop-guard
- specs/*/.lock/
- specs/*/.orchestrator-churn-state.json (added per the verification finding above; same character, same hazard class)

KEEP TRACKED as durable provenance (the per-dispatch audit trail):
- specs/*/.orchestrator-handoff.json
- specs/*/.return-meta.json

Include guidance for consumer repos on untracking already-committed loop-guards via `git rm --cached` (which preserves them on disk so an in-flight orchestration is not disrupted), and state explicitly that handoff and return-meta files must NOT be untracked.

== MATERIAL CONSTRAINT DISCOVERED DURING VERIFICATION ==

root-files/.gitignore is NOT the right vehicle for these patterns as it currently stands. Its existing contents are `hooks/*.log`, `logs/`, `output/`, `*.tmp` -- all relative to the .claude/ directory it deploys INTO. A `specs/*/...` pattern placed there would be interpreted relative to .claude/ and would silently match nothing. Determine the correct mechanism before writing patterns: either the consumer repo's ROOT .gitignore (which requires a deploy/merge path that may not exist yet), or a `.claude/../.gitignore` contribution, or documented setup guidance that the consumer applies once. Investigate root-files/ and templates/ to establish which of these the source store can actually deliver, and if none can, say so and deliver documented guidance plus a check rather than a pattern file that does nothing. Do NOT ship a gitignore entry without demonstrating it actually matches the intended paths in a consumer repo.

== REQUIRED RECONCILIATION ==

All of the following must agree with each other and with the shipped gitignore guidance:
- the gitignore template / root-files the source store deploys (root-files/, templates/ -- subject to the constraint above)
- context/standards/git-staging-scope.md: must stop implying whole-task-dir adds are safe (lines 25-27 and 88-90), and should generalize the narrow form already present at lines 72-76
- commands/orchestrate.md CHECKPOINT 3 staging (line 428) AND the multi-task Step 5 batch-commit staging (line 291)
- skills/skill-orchestrate/SKILL.md: document the loop guard as ephemeral and never-committed, reinforcing the Stage 2 resume semantics (line 110) and Stage 8 cleanup. Mirror the same statement for .orchestrator-churn-state.json in the hard variant if that file's policy lands here.

== DEPENDENCY NOTE ==

The declared dependencies (885, 902, 906) are SERIALIZATION-FOR-FILE-OVERLAP edges, not logical prerequisites:
- 885 edits root-files/settings.json, inside this task's root-files/ scope.
- 902 sits at the tail of the 891 -> 895 -> 897 -> 898 -> 900 -> 901 -> 902 chain covering commands/orchestrate.md and skills/skill-orchestrate/SKILL.md.
- 906 edits skills/skill-orchestrate/SKILL.md (Stage 8 return-meta status vocabulary), overlapping this task's edits to the same file.
These edges exist solely to keep this task out of a shared dispatch wave with tasks editing the same files. Nothing here waits on those tasks' conclusions.

== VERIFICATION REQUIRED ==

Demonstrate, in a scratch consumer-repo checkout, that (a) the shipped ignore mechanism actually causes `git status` to ignore a newly created specs/NNN_slug/.orchestrator-loop-guard, (b) `git rm --cached` on an already-committed guard leaves the file on disk, and (c) an orchestrate commit after the staging fix does not stage any of the three ephemeral file classes while still staging the handoff and return-meta provenance files.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 906. Fix gate-out artifact-validation call arity and unify the .return-meta.json status vocabulary
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 885, Task 896, Task 901, Task 909
- **Research**: [906_fix_gate_out_validation_arity_and_status_vocabulary/reports/01_gate-out-arity-and-status-vocabulary.md]
- **Plan**: [906_fix_gate_out_validation_arity_and_status_vocabulary/plans/01_gate-out-arity-and-status-vocabulary.md]
- **Summary**: [906_fix_gate_out_validation_arity_and_status_vocabulary/summaries/01_gate-out-arity-and-status-vocabulary-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

All line numbers below were live-verified against the CANONICAL source at agent-system/extensions/core/, not the deployed copy.

== DEFECT 1: validate-artifact.sh call-arity bug in command-gate-out.sh (silent dead code) ==

VERIFIED:
- scripts/command-gate-out.sh line 101 calls: bash .claude/scripts/validate-artifact.sh "$task_dir" --fix 2>/dev/null || true
- scripts/validate-artifact.sh line 4 declares: Usage: validate-artifact.sh <artifact_path> <type> [--fix] [--strict], with type in {report, plan, summary}.
- Therefore "--fix" is consumed as the TYPE positional and a DIRECTORY is passed as artifact_path. Control reaches the `if [ ! -f "$artifact_path" ]` guard at scripts/validate-artifact.sh line 55, which prints `[FAIL] File not found: specs/NNN_slug` and exits 3.
- The `[FAIL]` line is written to STDOUT, so the caller's `2>/dev/null` does NOT suppress it. Users see a spurious FAIL on EVERY gate-out run of EVERY command, while `|| true` swallows the nonzero exit so nothing ever surfaces as an error.

CONSEQUENCE: the non-blocking artifact link-repair that gate-out claims to perform has NEVER run, for any command, for any task. Live-observed during an /orchestrate run.

UNIFORMITY EVIDENCE (command-gate-out.sh is the LONE deviant; every other caller uses the correct 3-token form `validate-artifact.sh "$artifact_path" "$artifact_kind" --fix`):
- scripts/skill-base.sh line 326
- scripts/orchestrator-postflight.sh line 270
- skills/skill-researcher/SKILL.md line 328 (report)
- skills/skill-planner/SKILL.md line 350 (plan)
- skills/skill-implementer/SKILL.md line 380 (summary)
- skills/skill-reviser/SKILL.md line 314 (plan)
- skills/skill-planner-hard/SKILL.md line 244 (plan)
- skills/skill-researcher-hard/SKILL.md line 233 (report)

REQUIRED APPROACH: do NOT simply inline a per-type loop at the call site. Extract ONE shared helper -- a "validate every artifact in a task directory with its correct per-file type" function -- and place it in scripts/skill-base.sh adjacent to the existing correct caller at line 326, so command-gate-out.sh and any future caller consume the same abstraction. The goal is that this convention cannot drift again. Verify the helper is reachable from command-gate-out.sh's execution context before committing to that location; if skill-base.sh is not sourceable there, choose a location that is and record why.

ALSO INVESTIGATE: commands/research.md line 424 already documents in prose that "the validate-artifact.sh --fix leg is dead code and cannot substitute for this check". Determine whether that observation has this same root cause. If so, fix uniformly and update the prose at that line, rather than leaving a doc that describes a bug this task has removed.

== DEFECT 2: .return-meta.json emits a FORBIDDEN status value, making gate-out's defensive correction unreachable ==

VERIFIED:
- skills/skill-orchestrate/SKILL.md Stage 8 writes .return-meta.json with `--arg status "completed"` at line 731 (clean exit) and `--arg status "partial"` at line 748 (partial exit).
- scripts/command-gate-out.sh lines 84-85 gate the defensive status-correction branch on skill_status being one of {implemented, researched, planned}. The `case "$operation"` block begins at line 75, and its `orchestrate)` arm at line 79 sets expected_status="completed" (a state.json status, a different vocabulary from the return-meta status).
- context/formats/return-metadata-file.md line 79 states VERBATIM: **Note**: Never use `"completed"` - it triggers Claude stop behavior. The documented vocabulary is enumerated at lines 72-75: researched | planned | implemented | partial | failed | blocked.

FIX DIRECTION (settled, do not invert): skill-orchestrate is the OFFENDER -- it emits a value the format spec explicitly forbids. command-gate-out.sh's accept-list at lines 84-85 is CORRECT. Do NOT "fix" gate-out by adding "completed" to its accept-list; that would enshrine a value the spec bans and risks the stop behavior the spec warns about. skill-orchestrate Stage 8 must emit `implemented` on clean exit instead. Before finalizing, verify the stop-behavior rationale behind the line-79 prohibition still holds; if it no longer does, say so explicitly in the summary and escalate rather than silently proceeding on a stale premise.

CONSEQUENCE TODAY: for /orchestrate the correction branch can never fire, so a desynced state.json is silently never repaired -- which is the entire stated purpose of that checkpoint. The inline comment block at scripts/command-gate-out.sh lines 65-74 reasons at length about this unreachable branch (it even says the orchestrate arm "would have failed update-task-status.sh's validation had this branch ever been exercised"); once the branch becomes live, that comment is misleading and must be corrected.

THIRD WRITER FOUND DURING VERIFICATION (not previously catalogued): skills/skill-orchestrate/SKILL.md Stage MT-5 writes specs/.return-meta-multi.json at line 1009 with `--arg status "$exit_status"`, where exit_status is set to the same forbidden "completed" (or "partial") at lines 1004-1006. This is a different file from .return-meta.json but the same vocabulary violation, and it must be brought under the unified vocabulary too.

AUDIT RESULTS ALREADY ESTABLISHED (narrow the search accordingly, but re-verify):
- skills/skill-orchestrate-hard/SKILL.md does NOT emit a status value -- it only READS .return-meta.json (line 696). It is not an offender for this defect, though it must be re-checked once the vocabulary is centralized.
- skill-researcher (line 289, "researched"), skill-planner (line 312, "planned"), skill-implementer (line 297, "implemented"), skill-implementer-hard (line 263, "implemented"), skill-planner-hard (line 214, "planned"), skill-researcher-hard (line 196), skill-spawn (line 223), and skill-reviser (line 275) all reference the correct vocabulary or defer to the format doc. No divergence found in these.
- CORRECTION TO A PRIOR ASSUMPTION: docs/architecture/handoff-schema.md is NOT a divergent third source. Its line 45 already declares `"status": "researched | planned | implemented | partial | failed | blocked"`, which AGREES with context/formats/return-metadata-file.md. Note that handoff-schema.md governs .orchestrator-handoff.json, a DIFFERENT file from .return-meta.json; part of this task is to make that separation-of-concerns explicit rather than to "reconcile a disagreement" that does not exist. Confirm the two vocabularies are intended to be identical, and if so state where that identity is enforced.

REQUIRED APPROACH: ONE documented status vocabulary shared by every writer and reader of .return-meta.json (and .return-meta-multi.json), enforced in ONE place rather than restated per skill. Make context/formats/return-metadata-file.md the single normative source, have docs/architecture/handoff-schema.md reference it rather than restate it, and ensure the accept-list in scripts/command-gate-out.sh is derived from or explicitly cross-referenced to that source so the two cannot drift.

== SCOPE AND COORDINATION ==

COORDINATE WITH TASK 896: 896 edits skill_link_artifacts in scripts/skill-base.sh (cwd-relative path resolution). This task adds a shared validation helper to the SAME file. The two are DIFFERENT defects -- 896 is about path resolution, this is about call arity -- but whichever lands second must not clobber the other's edits. Re-read the file before editing.

CROSS-REFERENCE TASK 898: 898 gates WHETHER an `implemented` completion claim is honest (phase evidence before postflight). This task governs WHICH STRING is emitted to signal that claim. Adjacent and complementary, not duplicate. Because 898 will make the orchestrator's implemented-branch behavior conditional, and this task changes what value reaches that branch, the two must agree on the final spelling. Whichever lands second must verify the other's gate still fires.

DEPENDENCY NOTE: the declared dependencies (885, 896, 901) are SERIALIZATION-FOR-FILE-OVERLAP edges, not logical prerequisites. 885 and 896 both edit scripts/skill-base.sh; 901 sits at the tail of the 891 -> 895 -> 897 -> 898 -> 900 -> 901 chain on skills/skill-orchestrate/SKILL.md (and 898 additionally on docs/architecture/handoff-schema.md). These edges exist solely to keep this task out of a shared dispatch wave with tasks editing the same files. Nothing here waits on those tasks' conclusions.

VERIFICATION REQUIRED: after the fix, demonstrate that (a) a gate-out run on a real task directory validates each artifact with its correct type and emits no spurious [FAIL], and (b) the defensive status-correction branch in command-gate-out.sh is actually reachable for operation=orchestrate by exercising it against a deliberately desynced state.json.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 905. Detect stale Zotero exports and fail loudly instead of returning clean zero results
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [905_zotero_export_freshness_end_to_end/reports/01_zotero-export-freshness-research.md]
- **Plan**: [905_zotero_export_freshness_end_to_end/plans/01_zotero-export-freshness-plan.md]
- **Summary**: [905_zotero_export_freshness_end_to_end/summaries/01_zotero-export-freshness-summary.md]

**Description**: Make Zotero export staleness a detected, propagated, and loudly-surfaced condition end-to-end. Two defects share one root cause -- freshness is never checked -- and are deliberately kept in ONE task so the user-visible symptom is not half-fixed at any commit boundary.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth for this extension is agent-system/extensions/literature/. The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the loader. ALL edits MUST target agent-system/extensions/literature/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

PRIMARY ACCEPTANCE CRITERION: a zero-result Zotero answer must never be silently indistinguishable from "the library was never consulted" or "the export predates the items." Every failure mode below produced a confident, clean, WRONG negative -- specifically the conclusion "these papers are not in your library" about papers that are in fact present. That is the thing being fixed; treat any implementation that still permits a silent clean zero-result as incomplete.

REPRODUCED SYMPTOM: $LITERATURE_DIR/zotero-library.json is a stale, incomplete export -- 400 records dated 2026-07-01, correct domain (Carnap, Kripke, Holliday, Kurucz) but containing NONE of 18 documents known to be in the corpus. The live sqlite is dated 2026-07-15 and DOES contain matching items, so regenerating the export would capture them.

DEFECT 3 -- scripts/zotero-export-status.sh treats file EXISTENCE as freshness. It emits ZOTERO_EXPORT_PRESENT at :143 on existence alone; verbatim output today reads "zotero-library.json already present ... no assisted-generation offer needed" for an export provably two weeks stale. The staleness machinery already exists and is simply unused for this decision: .zotero-library.meta.json (written by zotero-generate-export.sh) is present at $LITERATURE_DIR/.

DEFECT 4 -- scripts/zotero-search.sh, the primary consumer of zotero-library.json (drives /literature Mode A discovery and /cite), neither calls the resolver nor performs any staleness check. Grepping it for meta.json, stale, export-status, resolve-sqlite, or mtime returns nothing. Its documented exit code 2 ("No results matched the query") is therefore emitted identically for a fresh library that genuinely lacks the item and for an export that predates the item -- the caller cannot tell these apart.

SUGGESTED SEQUENCING (internal phases, not separate tasks -- the helper must land before its consumers, but the task is not complete until the search-side banner ships):
1. Add a shared freshness helper (e.g. scripts/zotero-export-freshness.sh) that compares the zotero-library.json mtime against the resolved zotero.sqlite mtime (via zotero-resolve-sqlite-path.sh) and against the .zotero-library.meta.json stamp. Design its output as a directive token in the same honest-token style already used by zotero-export-status.sh and literature-ingest-online.sh.
2. Add a fifth directive ZOTERO_EXPORT_STALE to zotero-export-status.sh, which currently emits exactly four (PRESENT / MISSING_RUNNING / MISSING_NOT_RUNNING / UNAVAILABLE). Keep PRESENT meaning "present AND fresh".
3. Update the /literature directive table in commands/literature.md. The PRESENT branch at :149 currently says "No offer. Proceed directly to step 1", so a stale export is today a dead end for the user as well as the script -- STALE must instead offer assisted regeneration, reusing the existing MISSING_RUNNING / MISSING_NOT_RUNNING offer machinery. Handle the orchestrator / non-interactive path too: it cannot prompt, so it must take a deterministic default and emit a visible notice, matching how the rest of this extension handles autonomous contexts.
4. Add the staleness guard to zotero-search.sh: consult the helper before searching and, on stale or absent input, emit a visible banner in the established family ([SPARSE COVERAGE ...] / [UNVERIFIED ...] / [DEGRADED RETRIEVAL ...]) -- suggested [STALE EXPORT ...]. Consider whether the exit-code contract needs a distinct code for "searched a degraded library and found nothing" versus the existing 2; if exit codes stay as documented, the banner must carry the distinction unambiguously.

NON-GOALS (verified; do not drift into these):
- Do NOT auto-regenerate the export without user consent. zotero-generate-export.sh is deliberately an ASSISTED generator; --force stays opt-in. Detecting staleness must not become silently repairing it.
- Do NOT rewrite scripts/zotero-resolve-sqlite-path.sh. It is correct -- it returns /home/benjamin/Documents/Zotero/zotero.sqlite and correctly ignores the stale ~/Zotero. Consume it, do not modify it.
- Do NOT delete or migrate ~/Zotero. User data, out of scope.

RELATIONSHIP TO THE SIBLING TASK: the resolver-bypass task (literature-audit.sh and zotero-setup.sh delegation) fixes the other root cause behind the same user-facing incident. The two file_scopes are disjoint and no dependency edge is declared; they can proceed in parallel.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 904. Delegate Zotero data-directory resolution to the shared resolver
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [904_zotero_resolver_delegation_audit_setup/reports/01_zotero-resolver-delegation.md]
- **Plan**: [904_zotero_resolver_delegation_audit_setup/plans/01_zotero-resolver-delegation.md]
- **Summary**: [904_zotero_resolver_delegation_audit_setup/summaries/01_zotero-resolver-delegation-summary.md]

**Description**: Eliminate the two remaining bypasses of the shared Zotero sqlite-path resolver. Both defects share one root cause: a second, independently-maintained data-directory resolution ladder that disagrees with the canonical one.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth for this extension is agent-system/extensions/literature/. The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the loader. ALL edits MUST target agent-system/extensions/literature/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

REPRODUCED SYMPTOM: a discovery pass concluded "no Zotero storage" and returned 0 hits for titles that ARE present in the library. The stale profile ~/Zotero (zotero.sqlite dated 2026-04-17) was read instead of the live one ~/Documents/Zotero (dated 2026-07-15).

DEFECT 1 -- scripts/literature-audit.sh:47. DEFAULT_SEARCH_PATHS hardcodes "$HOME/Zotero/storage", which on this machine is the stale April profile's storage directory. Fix: resolve the data directory from the canonical resolver -- dirname "$(zotero-resolve-sqlite-path.sh)" -- and append /storage, rather than assuming a location.

DEFECT 2 -- scripts/zotero-setup.sh:79 (and its diagnostic at :103). _detect_data_dir() step 3 walks its own candidate list in the order "$HOME/Zotero", "$HOME/Documents/Zotero", "${XDG_DATA_HOME:-$HOME/.local/share}/Zotero". Because ~/Zotero is probed FIRST and does contain a zotero.sqlite, the setup wizard selects the stale profile and then reports it as successfully configured. The stderr message at :103 confirms this ordering to the user. Fix: replace step 3 with delegation to the resolver. Keep steps 1 and 2 ($ZOT_DATA_DIR, then zotero-index.json's .zot_data_dir) ahead of the resolver as explicit user overrides -- they are intentional escape hatches, not duplicate detection. Update the :103 "Checked:" diagnostic to describe the delegated ladder truthfully rather than the now-removed hardcoded list.

WHY DELEGATION, NOT REORDERING: reordering zotero-setup.sh's candidate list would fix this machine and leave the design fault intact -- two ladders that can drift apart again on the next edit. The resolver already has four correct consumers (zotero-export-status.sh, zotero-generate-export.sh, zotero-resolve-pdf.sh, literature-ingest-online.sh); literature-audit.sh and zotero-setup.sh are the only two bypassing it, so this is a closed set and the fix makes the resolver the single ladder.

NON-GOALS (verified; do not drift into these):
- Do NOT rewrite or "fix" scripts/zotero-resolve-sqlite-path.sh. It is correct. Invoked directly it returns /home/benjamin/Documents/Zotero/zotero.sqlite; it parses ~/.zotero/zotero/pmqmra0p.default/prefs.js, honours extensions.zotero.useDataDir / dataDir, and correctly does NOT fall through to the historical ${HOME}/Zotero default. Its 3-tier ladder is sound.
- Do NOT auto-regenerate the zotero-library.json export without user consent. zotero-generate-export.sh is deliberately an ASSISTED generator; --force stays opt-in. This task should not touch the export at all, but the guard is recorded here so a resolver fix does not grow into one.
- Do NOT delete, migrate, or otherwise touch ~/Zotero. It is the user's data and out of scope.

VERIFICATION: on a machine with both ~/Zotero and a custom dataDir configured, `zotero-setup.sh --detect` must print the resolved custom data directory, and literature-audit.sh must probe the resolved storage directory. Both must agree with `zotero-resolve-sqlite-path.sh` output. Note that the resolver performs no existence check on its result, so both callers keep their own file/directory probes on the resolved path.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 903. Add an optional phase-accounting backstop to update-task-status.sh implement postflight
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [903_phase_accounting_backstop_in_update_task_status/reports/01_phase-accounting-backstop.md]
- **Plan**: [903_phase_accounting_backstop_in_update_task_status/plans/01_phase-accounting-backstop.md]
- **Summary**: [903_phase_accounting_backstop_in_update_task_status/summaries/01_phase-accounting-backstop-summary.md]

**Description**: Defense-in-depth backstop recommended by the research for the completed task that gated the /orchestrate implemented->completed transition on phase progress (task 891). That task deliberately scoped its fix to the SKILL layer only; this task is the script-layer follow-up it named.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader. ALL edits MUST target agent-system/extensions/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

DEFECT: scripts/update-task-status.sh maps `postflight <N> implement` straight to STATE_STATUS="completed" (around line 154) with no phase awareness whatsoever, and additionally stamps the plan file's own Status field to [COMPLETED] via update_plan_file(). The phase gate added by task 891 lives ONLY in the two orchestrate SKILL.md files. Any other caller -- a different skill, a hand-run command, a future code path -- that invokes `update-task-status.sh postflight N implement` still flips a half-finished multi-phase task to completed unconditionally. The guard is currently one layer deep.

MOTIVATING OBSERVATION (from the orchestrate run of task 895, worth reading before designing): the implementation agent wrote `phases_completed: null` and `phases_total: null` into .orchestrator-handoff.json even though its own .return-meta.json correctly recorded 6/6. Under the task-891 gate, null reads as 0, which takes the deliberate pass-through branch and completes the task. In that instance the work genuinely WAS complete so the outcome was correct, but it demonstrates that the skill-layer gate cannot protect against a handoff that simply omits the fields. A script-layer backstop that can consult evidence the handoff did not supply (e.g. the plan file's own checklist state) closes a gap the skill layer structurally cannot.

DESIGN CONSTRAINT (the hard part): update-task-status.sh has NO phase-accounting parameters today and is called from many places. Any change MUST be backward compatible -- the recommendation from the task-891 research was OPTIONAL ADDITIVE FLAGS that default to a NO-OP, so every existing call site keeps its current behavior byte-for-byte. Do not make phase accounting a required argument. Research should determine what evidence the script can consult on its own (the plan file at specs/{NNN}_{SLUG}/plans/ is readable from the script and carries per-phase checkboxes and Status markers) versus what must be passed in by the caller, and recommend which.

Decide explicitly whether the backstop REFUSES the transition (exit non-zero) or WARNS and proceeds. Refusing is stronger but risks breaking legitimate callers that have no phase accounting; warning is safe but may be ignored. Justify the choice rather than defaulting.

RELATIONSHIP TO OTHER TASKS: task 898 (gate the implemented completion claim on phase evidence before postflight) addresses the same failure from the SKILL side -- verifying the agent's claim before calling postflight. This task is the independent script-side layer beneath it. They touch different files and are not sequenced; if both land, the guard is three layers deep (agent claim -> skill gate -> script backstop). No dependencies[] edge is declared because no open task shares this task's file_scope.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 902. Flag tasks that modify orchestrator machinery and force them to run alone
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 901, Task 899
- **Research**: [902_self_modification_hazard_gate/reports/01_self-modification-hazard-gate.md]
- **Plan**: [902_self_modification_hazard_gate/plans/01_self-modification-hazard-gate.md]
- **Summary**: [902_self_modification_hazard_gate/summaries/01_self-modification-hazard-gate-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

MOTIVATION: batching a task that repairs the orchestrator alongside other tasks means a known-defective orchestrator supervises its own fix, and supervises unrelated work in the same pass. If the defect being fixed is in the dispatch or postflight path, every sibling task in that batch inherits it. This hazard is currently recognized only by human judgment at batch-selection time.

DESIRED BEHAVIOR: extend the admission analysis so that a candidate whose file_scope intersects a defined set of orchestrator-critical paths is flagged self-modifying and admitted ONLY as a solo batch -- never alongside siblings. The flag must be visible in the dry-run report with a plain-language reason.

DEFINING THE CRITICAL SET (the substance of this task -- get this wrong in either direction and the gate is useless):
- Too narrow and the hazard slips through. Too broad and nearly every meta task becomes solo-only, which destroys batching for exactly the category of work that most needs it, and the gate will be disabled within a week.
- Candidate members to evaluate on the merits, not adopt wholesale: skills/skill-orchestrate/SKILL.md, skills/skill-orchestrate-hard/SKILL.md, commands/orchestrate.md, scripts/skill-base.sh, the command gate scripts, scripts/task-lock.sh, scripts/update-task-status.sh, scripts/orchestrator-postflight.sh, and the new admission script itself.
- Argue each inclusion from what actually executes DURING a live orchestration run. A file that only affects future runs is a weaker case than one read or executed mid-dispatch.
- Determine and state whether the deploy-artifact model changes the analysis: .claude/ is regenerated from the source store and regeneration is manual, so a source-store edit may not affect the RUNNING session at all. See context/patterns/regeneration-is-manual-only.md. If that materially reduces the hazard for some paths, say so and narrow the set accordingly rather than defending a gate that guards nothing.

DESIGN CONSTRAINTS:
- The critical set must be declared in ONE place, as data rather than as a condition duplicated across call sites.
- Solo-only must degrade gracefully: a self-modifying task is deferred out of a multi-task batch, not failed, consistent with the defer-not-fail default used by the existing wave-split and lock-refusal paths.
- Record the rationale for the final set in the guardrails context pattern, so a future reader can tell whether a newly added file belongs in it.

RESEARCH DIRECTIVE: include web research current as of July 2026 on self-modifying and self-hosting automation -- the practice of not letting a system deploy its own repair unsupervised, bootstrap and staging patterns from CI/CD and package-manager self-upgrade, and how those disciplines translate (or fail to translate) to an agent system whose deploy artifact is regenerated manually.

DEPENDENCY NOTE: depends on 901 for the report surface that renders the flag and for the shared admission script and command file, and on 899 for the guardrails pattern where the rationale is recorded.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 901. Add an orchestrate dry-run that reports batch admission verdicts before dispatch
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 900
- **Research**: [901_orchestrate_dry_run_admission_report/reports/01_dry-run-admission-report.md]
- **Plan**: [901_orchestrate_dry_run_admission_report/plans/01_dry-run-admission-report.md]
- **Summary**: [901_orchestrate_dry_run_admission_report/summaries/01_dry-run-admission-report-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

MOTIVATION: deciding which tasks belong in a batch currently requires a human to read state.json, cross-check file_scope by eye, open each candidate's .orchestrator-handoff.json to see whether it is resumable, and mentally compute a wave split. That analysis is reproducible in principle but performed ad hoc in practice, and it is the step most likely to be skipped when a batch is large.

DESIRED BEHAVIOR: a --dry-run flag on /orchestrate that performs the full admission analysis and prints a report WITHOUT dispatching any agent or mutating any state. Report contents:
- The admitted set, with the computed wave assignment.
- Every excluded candidate with a specific reason: file_scope collision (naming the colliding task and the overlapping path), unmet predecessor, lock held by another session, or stale/unresumable handoff.
- A recommended split when the admitted set should not run as a single batch.

HANDOFF TRIAGE (the second half of this task): a task in partial status whose .orchestrator-handoff.json carries unresolved blockers and NO continuation_context routes to blocker escalation rather than productive work. Admitting such a task into a batch spends a dispatch cycle discovering something that was readable from the handoff beforehand. The admission analysis must classify this case as needs-human and exclude it, rather than admitting it and escalating mid-run.

VERIFY BEFORE DESIGNING: skills/skill-orchestrate/SKILL.md Stage MT-4 already has a phase-grouping table distinguishing partial-with-continuation (dispatch to implement) from partial-with-blockers (mark blocked) from partial-with-no-handoff (dispatch to implement). The triage classifier must agree with that table exactly. If the dry-run report predicts a different routing than MT-4 would actually take, the report is worse than useless -- it is confidently wrong. Treat exact agreement with the live table as an acceptance criterion, not a nice-to-have.

DESIGN CONSTRAINTS:
- Reading a handoff for triage is bounded and cheap (the file has a documented ~400 token budget). Reading plans, reports, or summaries is NOT permitted -- that would breach the Context Flatness Constraint the orchestrator depends on.
- --dry-run must be strictly read-only: no state.json writes, no TODO.md regeneration, no lock acquisition, no agent dispatch. Verify no invoked helper mutates state as a side effect; task-lock.sh in particular must not be called in acquire mode.
- Parse the flag through the established argument-parsing path rather than ad hoc string matching; check scripts/parse-command-args.sh for the existing convention.
- The same admission analysis must back both --dry-run and the live path, so the report cannot drift from real behavior. One code path, two consumers.

RESEARCH DIRECTIVE: include web research current as of July 2026 on plan-preview and dry-run affordances for autonomous agent systems -- what makes a preflight report trustworthy rather than a rubber stamp, and the documented failure mode where an approval surface that is always green trains its reviewer to stop reading it.

DEPENDENCY NOTE: depends on 900 for the admission verdict data this renders, and shares scripts/orchestrate-batch-admit.sh, commands/orchestrate.md, and skills/skill-orchestrate/SKILL.md with it.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 900. Detect file_scope collisions against all active tasks, not just batch members
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 898, Task 899
- **Research**: [900_cross_batch_file_scope_admission/reports/01_cross-batch-admission-control.md]
- **Plan**: [900_cross_batch_file_scope_admission/plans/01_cross-batch-admission-control.md]
- **Summary**: [900_cross_batch_file_scope_admission/summaries/01_cross-batch-admission-control-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

DEFECT: a task OUTSIDE the requested batch can share a file with a task INSIDE it, with no dependencies[] edge serializing them, and nothing in the system notices. Observed live: two active tasks share agent-system/extensions/core/scripts/skill-base.sh, only one was in the requested batch, and no edge connects them because they were created in separate /meta batches.

WHY ALL THREE EXISTING CHECKS MISS IT (verify each of these before designing the fix):
1. commands/orchestrate.md Step 3 runtime wave-split check compares pairs WITHIN a wave. Its own text scopes the read to the tasks in this invocation. Out-of-batch tasks are invisible by construction.
2. skills/skill-orchestrate/SKILL.md Stage MT-3 step 4.5 compares pairs within eligible_tasks, and states explicitly that file_scope is read only for tasks already in task_numbers for this invocation -- no repo-wide scan.
3. scripts/task-lock.sh performs a cross-task file_scope overlap check, but only against tasks that currently HOLD A LOCK. A non-terminal, unlocked, out-of-batch task is not examined.

So the gap is precisely: non-terminal, unlocked, out-of-batch tasks. Each individual check is correct within its own scope; the union of their scopes still has a hole.

DESIRED BEHAVIOR: a new script agent-system/extensions/core/scripts/orchestrate-batch-admit.sh that, given a set of candidate task numbers, reads specs/state.json once and compares each candidate's file_scope against the file_scope of EVERY non-terminal task in state.json -- in-batch and out-of-batch alike -- using the shared directory-prefix overlap algorithm in context/patterns/file-footprint-overlap.md (reference it by path; do NOT restate or fork the algorithm). It emits a machine-readable verdict per candidate: admit, or defer with the colliding task number and the specific overlapping path.

Wire the script into both existing call sites so they stop being independently-scoped: commands/orchestrate.md Step 3, and skills/skill-orchestrate/SKILL.md Stage MT-3 step 4.5.

DESIGN CONSTRAINTS:
- Preserve defer-not-fail. A collision defers the higher project_number to a later cycle; it never marks a task failed. Both existing checks already behave this way and that behavior must survive.
- Do NOT silently widen the blast radius: reading every non-terminal task's file_scope is a state.json read, not a filesystem scan. Keep it O(active tasks), single read, no globbing of the repo.
- Terminal statuses (completed, abandoned, expanded) are excluded from the comparison set. Confirm the exact terminal-status list against the state-management rule rather than assuming it.
- The verdict format must be consumable by a report renderer without reparsing prose, since a downstream task renders these verdicts for human review.
- An out-of-batch collision is NOT automatically the same severity as an in-batch one. An in-batch pair can be resolved by deferring within the run; an out-of-batch collision may mean the batch should never have included that task. Consider whether the verdict needs to distinguish them.

RESEARCH DIRECTIVE: include web research current as of July 2026 on admission control for concurrent agents over shared mutable files -- in particular conservative footprint-based serialization versus optimistic concurrency with conflict detection after the fact, and the false-positive cost of prefix-based footprint comparison.

DEPENDENCY NOTE: depends on 898 to serialize edits to skills/skill-orchestrate/SKILL.md, and on 899 for the written blocking-versus-advisory criterion this check must conform to.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 899. Author a batch-orchestration guardrails context pattern from current practice
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [899_batch_orchestration_guardrails_context/reports/01_batch-orchestration-guardrails.md]
- **Plan**: [899_batch_orchestration_guardrails_context/plans/01_batch-orchestration-guardrails.md]
- **Summary**: [899_batch_orchestration_guardrails_context/summaries/01_batch-orchestration-guardrails-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

MOTIVATION: batching several tasks into one /orchestrate invocation currently depends on a human reasoning, by hand and per invocation, about which tasks may safely share a batch -- file-footprint collisions, stale handoffs, tasks that modify the orchestrator itself. That reasoning is correct but unwritten, so it does not scale with batch size and is not reproducible across sessions. Before adding admission machinery, the design principles it should encode need to be written down and grounded.

DELIVERABLE: a new context pattern at agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md that states, for this agent system specifically:
- Which guardrails must be BLOCKING (refuse to dispatch) versus ADVISORY (warn and continue), and the criterion that decides which category a given guardrail belongs to.
- How that blocking/advisory split should change as batch size grows -- the central tension being that a guardrail cheap enough to be blocking at batch size 1 may stall an entire batch at size 8, while relaxing it to advisory at scale is precisely how quality regressions enter unnoticed.
- Admission control versus mid-flight interruption: which classes of problem are detectable BEFORE dispatch (file-footprint collision, stale handoff, held lock, unmet predecessor) and which are only detectable DURING a run (premature completion claim, churn, drift), and why each class belongs where it does.
- Defer-not-fail as the standing default for admission conflicts, consistent with the existing runtime wave-split check and the task-lock refusal path, both of which already defer a task to a later cycle rather than marking it failed.
- What must never be relaxed for throughput, stated as explicit non-negotiables.

RESEARCH DIRECTIVE: ground this in web research current as of July 2026 on multi-agent batch orchestration -- admission control and backpressure, concurrency control over shared mutable state, human-in-the-loop review at batch scale (batch approval versus per-item approval and the failure modes of each), and verification-gate design for autonomous agents. Cite durable sources. Distinguish clearly between what the external sources claim and what this repository's own observed behavior shows; where they conflict, say so rather than smoothing it over.

SCOPE DISCIPLINE: this task writes ONE new context file and changes NO existing behavior. It must not edit any skill, command, script, or agent. Its value is that the downstream admission-machinery tasks can consult a written rationale instead of re-deriving it. If research concludes that a proposed downstream guardrail is a bad idea, say that plainly in the deliverable -- a documented argument against a guardrail is a valid outcome.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 898. Gate the implemented completion claim on phase evidence before postflight
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 897
- **Research**: [898_completion_claim_verification_gate/reports/01_completion_claim_verification_gate.md]
- **Plan**: [898_completion_claim_verification_gate/plans/01_completion-claim-verification-gate.md]
- **Summary**: [898_completion_claim_verification_gate/summaries/01_completion-claim-verification-gate-summary.md]

**Description**: SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/. The .claude/ tree is a GITIGNORED, DISPOSABLE deploy artifact regenerated from the source store. ALL edits MUST target agent-system/extensions/core/** and NEVER .claude/**.

DEFECT (observed while batching a multi-task /orchestrate run): Stage MT-4 step 3 in skills/skill-orchestrate/SKILL.md maps dispatch_status="implemented" straight to skill_postflight_update <task> "implement" <session> implemented -- which drives the task to completed -- with NO check that the work actually finished. MT-4 never reads phases_completed, phases_total, or plan_markers_verified from the handoff at all.

VERIFIED CURRENT MECHANISM:
- skills/skill-orchestrate/SKILL.md Stage MT-4 step 3 contains the three-way case on dispatch_status (researched/planned/implemented) with no evidence check on the implemented branch.
- Single-task Stage 5 DOES read phases_completed and phases_total from the handoff and logs "Phase progress: N/M", but the only gate built on those fields is the drift-detection arithmetic gate, and that gate is guarded by [ "$dispatch_status" = "partial" ]. An "implemented" claim therefore bypasses every phase check in BOTH modes.
- docs/architecture/handoff-schema.md documents plan_markers_verified and states the required orchestrator behavior: when status="implemented" and plan_markers_verified is absent or false, the orchestrator logs a WARNING about possible stale markers. That documented behavior is NOT implemented in skill-orchestrate, skill-orchestrate-hard, or the multi-task path. The doc and the code disagree; reconcile them.

BLOCKING PREREQUISITE (new, verified live during a completed orchestration run in this repo): the two fields this task's gate is designed to read are not where the consumer looks for them.
- docs/architecture/handoff-schema.md places phases_completed and phases_total NESTED INSIDE the continuation_context object, alongside handoff_path.
- skills/skill-orchestrate/SKILL.md Stage 5 reads them at TOP LEVEL with a zero fallback: phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0') and the same for phases_total.
- Consequence: phases_total is ALWAYS 0 in practice. The very next line, the drift-detection arithmetic gate if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ], can therefore NEVER evaluate true. Drift detection and its invoke_drift_inspection path are dead code, and MAX_DRIFT_INSPECTIONS / DRIFT_COMPLETION_THRESHOLD / DRIFT_REVISION_THRESHOLD are dead constants.
- Live evidence: a real implement handoff written during an orchestration run in this repo had top-level has("phases_completed") == false and has("phases_total") == false, while continuation_context contained {"phases_completed": 3, "phases_total": 3}. The "[orchestrate] Phase progress: N/M" log line in Stage 5 is likewise gated on phases_total > 0 and so never prints.

WHY THIS BLOCKS THE PLANNED GATE: this task proposes to refuse postflight-to-completed when phases_completed < phases_total. Built on the current top-level read, that comparison would always see 0 < 0 (false) and the gate would never fire -- reproducing the existing dead-code bug in a second place while appearing to add a guardrail. Resolving the schema/consumer mismatch is therefore a PREREQUISITE step within this task, not a follow-up.

DECISION POINT (must be settled and recorded during implementation): choose between (a) moving phases_completed and phases_total to the TOP LEVEL of the handoff, updating handoff-schema.md plus every skill that writes a handoff; or (b) keeping them nested per the current schema and fixing the readers to use .continuation_context.phases_total / .continuation_context.phases_completed. Material trade-off: nesting them under continuation_context means a handoff with status="implemented" has no natural place for phase accounting at all, since continuation_context is documented as present only when status="partial". That asymmetry is the likely root cause of the mismatch and argues for option (a), but the implementation must first verify how many handoff writers exist before committing, and must state in the summary which option it chose and why.

DESIRED BEHAVIOR: a single shared completion-claim gate, applied on the implemented branch in ALL THREE paths (single-task Stage 5, multi-task Stage MT-4, and the hard variant), reading phase accounting from whichever field location the DECISION POINT resolves to. When dispatch_status="implemented" AND either (a) phase accounting is present with phases_completed < phases_total, or (b) plan_markers_verified is absent or false: do NOT run the postflight-to-completed update. Instead log a loud, greppable warning naming the task and the evidence, and treat the cycle as continuation-eligible so the next cycle re-dispatches implement rather than declaring the task done.

DESIGN CONSTRAINTS:
- Fail CLOSED on missing evidence, but distinguish THREE cases, not two. The live handoff cited above was a genuine, fully-complete implementation (3 of 3 phases, all plan headings [COMPLETED], deliverable verified on disk) that nonetheless carried NO top-level phase accounting; a naive fail-closed rule keyed on absent fields would have blocked a correct completion. The gate must therefore branch on: (1) phase accounting present and short -- refuse and re-dispatch; (2) phase accounting present and complete -- allow; (3) phase accounting absent entirely -- this is a handoff-writer defect, and the gate must fall back to the corroborating signal rather than either blindly allowing or blindly refusing. On that same live handoff, plan_markers_verified was present and true and was independently corroborated against the plan file, making it the field that carried real signal. The warning text must say which of the three cases fired.
- Reconcile doc and code for BOTH evidence fields. handoff-schema.md already documents a required orchestrator WARNING when status="implemented" and plan_markers_verified is absent or false, and that warning is implemented nowhere; the same reconciliation must now also cover the phase-accounting fields.
- Do NOT weaken the existing drift-detection gate or the partial/blocker routing; this gate is strictly additional. Note that fixing the field location will make the drift-detection gate live for the first time -- verify its behavior once it can actually evaluate true.
- Do NOT read plan files, reports, or summaries to verify the claim. The MUST NOT (Context Flatness Constraint) section of skill-orchestrate forbids it and the whole point of the handoff is that the orchestrator stays flat. All evidence must come from fields already in .orchestrator-handoff.json.
- Guard against an infinite re-dispatch loop: a task whose agent repeatedly claims implemented without phase evidence must eventually terminate against the existing cycle cap rather than spin. Verify the interaction with MAX_CYCLES / MAX_CYCLES_MT explicitly.

RESEARCH DIRECTIVE: include web research current as of July 2026 on verification gates for autonomous agent completion claims -- specifically self-reported completion versus independently-checkable evidence, and fail-open versus fail-closed gate design when the verifier cannot afford to re-read the work product.

DEPENDENCY NOTE: depends on task 897 purely to serialize edits to skills/skill-orchestrate/SKILL.md and skills/skill-orchestrate-hard/SKILL.md, which sit at the tail of the existing 891 -> 895 -> 897 chain on those same two files. This is a file-overlap serializer, not a logical prerequisite.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 897. Add narrow sanctioned phase-marker grep exception to orchestrate MUST NOT list
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 895
- **Research**: [897_sanctioned_phase_marker_grep_exception_for_orchestrate/reports/01_phase-marker-grep-exception.md]
- **Plan**: [897_sanctioned_phase_marker_grep_exception_for_orchestrate/plans/01_phase-marker-grep-recovery.md]
- **Summary**: [897_sanctioned_phase_marker_grep_exception_for_orchestrate/summaries/01_phase-marker-grep-recovery-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 892
- **Research**: [896_fix_cwd_relative_artifact_linking_in_skill_base/reports/01_cwd_relative_artifact_linking_fix.md]
- **Plan**: [896_fix_cwd_relative_artifact_linking_in_skill_base/plans/01_cwd-relative-artifact-linking-fix.md]
- **Summary**: [896_fix_cwd_relative_artifact_linking_in_skill_base/summaries/01_cwd-relative-artifact-linking-fix-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 891
- **Research**: [895_separate_infra_failure_from_orchestrate_work_cycles/reports/01_infra-failure-vs-work-cycle.md]
- **Plan**: [895_separate_infra_failure_from_orchestrate_work_cycles/plans/01_infra-failure-vs-work-cycle.md]
- **Summary**: [895_separate_infra_failure_from_orchestrate_work_cycles/summaries/01_infra-failure-vs-work-cycle-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [894_fix_git_snapshot_silent_revert_footgun/reports/01_git-snapshot-revert-footgun.md]
- **Plan**: [894_fix_git_snapshot_silent_revert_footgun/plans/01_git-snapshot-revert-footgun.md]
- **Summary**: [894_fix_git_snapshot_silent_revert_footgun/summaries/01_git-snapshot-revert-footgun-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [893_close_stranded_status_detection_gap_for_not_started/reports/01_stranded-status-detection-gap.md]
- **Plan**: [893_close_stranded_status_detection_gap_for_not_started/plans/01_stranded-status-detection-gap.md]
- **Summary**: [893_close_stranded_status_detection_gap_for_not_started/summaries/01_stranded-status-detection-gap-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [892_prevent_stale_and_misplaced_orchestrator_handoff_reads/reports/01_stale-misplaced-handoff-reads.md]
- **Plan**: [892_prevent_stale_and_misplaced_orchestrator_handoff_reads/plans/01_stale-misplaced-handoff-reads.md]
- **Summary**: [892_prevent_stale_and_misplaced_orchestrator_handoff_reads/summaries/01_stale-misplaced-handoff-reads-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [891_gate_orchestrate_completion_on_phase_progress/reports/01_gate-completion-on-phase-progress.md]
- **Plan**: [891_gate_orchestrate_completion_on_phase_progress/plans/01_gate-completion-on-phase-progress.md]
- **Summary**: [891_gate_orchestrate_completion_on_phase_progress/summaries/01_gate-completion-on-phase-progress-summary.md]

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
- **Status**: [BLOCKED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 873, Task 885
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
- **Dependencies**: Task 874, Task 916
- **Research**: [885_enable_and_verify_passive_signal_capture/reports/01_enable-verify-passive-signal-capture.md]
- **Plan**: [885_enable_and_verify_passive_signal_capture/plans/01_passive-signal-capture-deploy.md]
- **Summary**: [885_enable_and_verify_passive_signal_capture/summaries/01_passive-signal-capture-deploy-summary.md]

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
- **Status**: [BLOCKED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [873_global_default_target_resolution_for_meta/reports/01_global_default_target_resolution.md]
- **Plan**: [873_global_default_target_resolution_for_meta/plans/01_global_default_target_resolution.md]
- **Summary**: [873_global_default_target_resolution_for_meta/summaries/01_global-default-target-resolution-summary.md]

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
