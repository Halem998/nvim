---
next_project_number: 68
---

# TODO

## Task Order

*Updated 2026-08-18. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 14,17,18,20,22,27,28,31,39,43,45,46,51,62,65,66 | -- | agent-system, extensions, literature, ... |
| 2 | 13,42,44 | 17,18,28,31 | agent-system, essential-refactor |
| 3 | 9,29,53,64 | 18,22,42,44 | agent-system, orchestration-concurrency, essential-refactor |
| 4 | 30,48 | 22,29,39,43,44,64 | agent-system, essential-refactor |
| 5 | 32,50 | 30,31,48 | agent-system, essential-refactor |

**Grouped by Topic** (indented = depends on parent):

### Agent System

14 [NOT STARTED] — Two dispatches in a single batch fanned out to phase sub-agents a
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th
27 [NOT STARTED] — .opencode/scripts/execute-command.sh is a command router that can
28 [IMPLEMENTING] — Rewrite the canonical MCP ownership document, whose central premi
31 [RESEARCHING] — Give the .opencode/extensions/ mirror a real generation path from
  └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta
51 [NOT STARTED] — Move per-session state files cluttering the specs/ root (.orchest
9 [NOT STARTED] — Declared-vs-deployed parity for provides.* categories is one-dire
13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
29 [NOT STARTED] — Build the deploy-engine mechanism that lets an extension declare 
  └─ 30 [NOT STARTED] — Register the obsidian-memory MCP server through the new manifest-
    └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta (see above)

### Extensions

22 [RESEARCHING] — Silence and correct opencode-agents.json fragment validation spam
45 [NOT STARTED] — Implement <leader>al repo registration and 'Global Update' action
46 [NOT STARTED] — Fix present extension compound-skill routing so /implement resolv
62 [NOT STARTED] — Restrict typst and latex task types to formatting-only concerns. 
66 [NOT STARTED] — Mandate detached (run_in_background) invocation for Lean full bui

### Literature

39 [PLANNED] — Upgrade the literature extension's Zotero integration beyond bare

### Orchestration Concurrency

53 [NOT STARTED] — Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect w

### Essential Refactor

17 [PLANNING] — command-gate-out.sh's entire post-metadata body is structurally u
  └─ 44 [NOT STARTED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/
    └─ 48 [NOT STARTED] — Propagate the scoped-commit fix to the 65 call sites it never rea
      └─ 50 [NOT STARTED] — Make the verification surface trustworthy, and close the doc-trut
18 [PLANNING] — A repo can carry an arbitrarily stale .claude/ deploy with no sig
  └─ 42 [NOT STARTED] — Add two context gates to the deploy verification pipeline. (a) Br
    └─ 64 [NOT STARTED] — Decide and implement how --hard behavioral contracts reach agents
      └─ 48 [NOT STARTED] — Propagate the scoped-commit fix to the 65 call sites it never rea (see above)
43 [NOT STARTED] — LIVE DEFECT, not an efficiency item: the email extension's five '
  └─ 48 [NOT STARTED] — Propagate the scoped-commit fix to the 65 call sites it never rea (see above)
65 [PLANNED] — Fix skill_orchestrate_mint_dispatch_seq to increment from the per

## Tasks

### 67. Make /orchestrate admission gates ordering constraints, not exclusions: unstrand in-flight tasks and end solo-only self-modifying dispatch
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [067_orchestrate_eligibility_not_status_gated/reports/01_admission-predicate-eligibility-and-self-mod-tiebreak.md]
- **Plan**: [067_orchestrate_eligibility_not_status_gated/plans/01_admission-gates-as-ordering-constraints.md]
- **Summary**: [067_orchestrate_eligibility_not_status_gated/summaries/01_admission-gates-as-ordering-constraints-summary.md]

**Description**: Repair two coupled defects in /orchestrate's multi-task admission predicate so that every admission gate degrades to an ORDERING CONSTRAINT and never to a PERMANENT EXCLUSION. Work stream A: make eligibility depend on locks, dependencies[], and file_scope overlap rather than on an in-flight status string, so tasks stranded in researching/planning by a dead prior session are no longer silently skipped forever. Work stream B: give the self-modification gate a deterministic tie-breaker and make it phase-aware, so N self-modifying tasks in one batch run in sequence instead of deadlocking, and so the operator is never told to "run it solo". Both work streams edit the same predicate file (scripts/orchestrate-batch-admit.sh) and the same co-maintenance set, and B supplies the replacement convergence exit condition that A removes -- see COUPLING below for why splitting them is not viable.

=== WORK STREAM A: ELIGIBILITY MUST NOT BE STATUS-GATED ===

OBSERVED DEFECT. Stage MT-3 step 3 of skills/skill-orchestrate/SKILL.md (lines 1449-1460) builds eligible_tasks with the condition "Status is NOT {researching, planning} (in-flight from prior cycle)". Stage MT-4's phase-grouping table (lines 1877-1885) folds "blocked, researching, planning, unknown" into the skip group. scripts/orchestrate-triage-classify.sh encodes the same rule executably: researching and planning are not named anywhere in its jq at all, so they fall into the final else arm and are emitted as group "skip" with reason "transitional/unknown". A task stranded in either status is therefore absent from every cycle, produces no warning, and never surfaces to the operator.

LIVE EVIDENCE, MEASURED AT TASK-CREATION TIME, WITH ONE PREMISE CORRECTION. Tasks 22 (researching), 28 (implementing) and 31 (researching) are stranded. IMPORTANT CORRECTION TO THE ORIGINATING REPORT: the originating report asserted these tasks have "no lock holder". That is FALSE and must not be carried into research. All three DO hold lock directories, all three held by the same dead session sess_1786459614_0c9ada, with heartbeat_at frozen at 2026-08-11. Measured directly via the deployed task-lock.sh check: each returns "held-stale ... heartbeat_age_min=9073 (or 9086) threshold_min=30", exit code 2. So the correct diagnosis is STALE FOREIGN LOCK, not ABSENT LOCK. This matters because it changes what the fix must prove: the question is not "is a lock-free in-flight status safe to dispatch" but "does acquire's stale-override path actually reclaim these". Re-measure before relying on any of this; the stranded set will have changed.

THE LOCK LAYER ALREADY BEHAVES CORRECTLY, AND THIS IS THE CORE FINDING. scripts/task-lock.sh keys locks on task number alone (operation/phase is recorded in holder.json but never compared when granting or refusing). TASK_LOCK_STALE_MIN defaults to 30 minutes. cmd_acquire refuses (exit 1) on exactly three branches: a cross-task file_scope overlap against a FRESH foreign lock; a session-registry contention hit; and its own task's lock being held FRESH by a different session. Same-session re-entry never blocks and only refreshes heartbeat_at. A stale foreign lock is override-and-warn, never refusal, and the .lock directory is not removed, holder.json is simply overwritten. Critically, cmd_acquire never reads .status at all. So the status string is doing no concurrency work whatsoever, and the lock is already the real mutex. That is the substantive support for the user's stated requirement.

RECONCILE IS INERT ON THIS CASE, MEASURED. scripts/reconcile-task-status.sh was run live against the stranded researching task: it produced no output, exited 0, and did not mutate state.json. The blocking condition is its artifact-presence check. Its researching branch reads report_file=$(find_latest_artifact reports) and then "if [[ -z "$report_file" ]] ... exit 0" under the comment "# No artifact -- genuine in-progress, no-op". planning and implementing have byte-identical shapes. The script contains only promotion rules; there is no demotion rule anywhere in it (researching -> not_started does not exist). It never consults task-lock.sh, never reads holder.json, never references a .lock path, so its "genuine in-progress" assertion rests on no evidence. Note reconcile-task-status.sh is deliberately ABSENT from context/reference/orchestrator-critical-paths.json, and that absence is a recorded non-decision, see context/patterns/system-defect-discrimination.md lines 326-336, which explicitly leaves "whether they belong in critical_paths for the self-modification-hazard check" as an undecided follow-on.

DECIDE, DO NOT PRESUPPOSE. The user's stated requirement is that in-flight status alone must not be an eligibility exclusion, and that concurrency safety be enforced only by the admission gate's file_scope overlap check and by dependencies[] edges. Research must still choose and record HOW, weighing at minimum: (a) remove the status exclusion from eligibility and map researching -> research group and planning -> plan group in the classifier, letting acquire's stale-override reclaim the lock; (b) leave eligibility alone and instead make reconcile-task-status.sh lock-aware, demoting an in-flight status with no artifact and no fresh lock back to its predecessor status, so the task re-enters eligibility through the existing path; (c) both, with (a) as the mechanism and (b) as defence in depth plus operator visibility. Weigh (b) seriously rather than dismissing it: it repairs the state rather than routing around it, it fixes the same stranding for the single-task engine and for every other consumer of status at once, and it does not disturb the safety arguments enumerated below. Weigh against it that a demotion rule is a new class of write for that script and that a task genuinely in flight under a FRESH lock must never be demoted.

CO-MAINTENANCE SET IS LARGER THAN THE THREE ARTIFACTS THE ORIGINATING REPORT NAMED. The self-declared triple (skill-orchestrate SKILL.md's MT-4 table, skill-orchestrate-hard SKILL.md, and orchestrate-triage-classify.sh's header verdict table) governs the PHASE-GROUPING TABLE only. The ELIGIBILITY rule has a further set of dependents that a naive edit would silently falsify, several of which are load-bearing SAFETY ARGUMENTS asserting a hazard is "structurally impossible BECAUSE of" the exclusion:
  - scripts/orchestrate-batch-admit.sh lines 189-194: the A1 dead-code justification, which argues an explicit dependency-edge exemption in the self-mod branch "would therefore be unreachable dead code" because "Stage MT-3 step 3's eligibility rule makes it structurally impossible for a dependencies[]-edge predecessor/successor pair to occupy the same eligible_tasks batch".
  - context/patterns/batch-orchestration-guardrails.md, four sites (around lines 200-206, 238-241, 254-259, 276-278), which RETIRE hazards on exactly that premise.
  - commands/orchestrate.md lines 262-265, and docs/architecture/batch-admit-schema.md at three sites (around 155-157, 264-267, 286-289), restating the same claim.
  - docs/architecture/orchestrate-state-machine.md, four sites (ASCII diagram around 331-337, prose around 379-382, worked example around 437) restating the eligibility rule directly.
  - The in_batch defer CONVERGENCE argument, present in BOTH skills (base around 1552-1570, hard around 1583-1586), which states a deferred task "becomes eligible again on a later cycle, once the colliding in-batch task leaves eligible_tasks (entering researching/planning, terminating, or failing)" and is explicitly labelled "load-bearing for the convergence argument elsewhere in this file". If in-flight statuses no longer remove a task from eligible_tasks, this convergence argument loses one of its three exit conditions and MUST be re-derived, not merely reworded. This is the single highest-risk consequence of direction (a) and is the strongest argument for weighing (b). NOTE: work stream B's deterministic tie-breaker supplies a replacement exit condition that does not depend on status transitions at all -- re-derive the convergence argument against BOTH work streams' post-change exit conditions, not against work stream A alone.
Every one of these must be re-derived or corrected in the same change. A fix that lands the mechanism while leaving these asserting a now-false premise is not acceptable.

HARD-MODE FILE DIVERGES FROM THE ORIGINATING REPORT'S ASSUMPTION. skill-orchestrate-hard/SKILL.md is NOT a full transcription twin for these items. It has NO eligible_tasks construction, NO phase-grouping table, NO circuit breaker, NO entry reconcile and NO Decision 1 -- its Multi-Task Mode section (from line 1539) is a bare "Same as base" pointer that deliberately transcribed only two mechanisms (the admission gate and the redeploy checkpoint). It DOES carry compressed Stage 4 researching/planning handlers (lines 599-601 and 689-691) that say only "In-flight. Exit with warning ... Same as base skill", having dropped the base file's verbatim operator message and its EXIT (partial) code entirely. So the hard-file work is smaller and different in kind from what was assumed: update the handlers and the transcribed in_batch convergence text, and decide explicitly whether the eligibility rule now needs transcribing there given its own stated rationale (lines 1544-1551) that bare pointers demonstrably fail to carry mechanisms forward. Note that the hard file DID transcribe the admission gate, so work stream B's predicate change lands in it too.

SINGLE-TASK ENGINE, DECIDE AND RECORD EITHER WAY. Base Stage 4's researching handler (lines 359-367) and planning handler (lines 408-410) EXIT the whole invocation with "is currently being researched in another session" and EXIT (partial), whereas implementing dispatches normally. Decide whether these converge with the multi-task change or deliberately diverge, and record the reasoning explicitly. Precedent for a documented intentional divergence exists on the blocked row (Decision 1, base lines 597-602: single-task escalates to needs_human because it has no siblings, multi-task skips so siblings proceed), so divergence is acceptable IF justified and written down, never accidental. Note the asymmetry that motivates convergence: the single-task engine's message asserts another session owns the task, which in the measured evidence is false -- the owning session is dead and its lock is stale.

BLOCKED AND UNKNOWN ROWS: EXPLICIT SCOPE DECISION REQUIRED, DEFAULT IS LEAVE ALONE. Do not silently widen scope. The default position is that blocked keeps its documented Decision 1 divergence and unknown keeps routing to skip, since neither is implicated in the stranding defect. If research concludes either should change, that must be argued separately and called out, not folded in.

NO TEST COVERAGE EXISTS FOR THE RULE BEING CHANGED. scripts/tests/test-orchestrate-triage-classify.sh covers ONLY the partial-status continuation-pointer predicate. No fixture anywhere exercises researching/planning -> skip, the blocked engine divergence, or the terminal rows, so the triple's co-maintenance is currently enforced by prose comments alone. Add fixtures covering the status-to-group rows for both engines, and observe the mutation-check discipline in context/standards/shell-script-testing.md: a suite that passes unchanged both before and after the fix proves nothing.

=== WORK STREAM B: SELF-MODIFICATION GATE MUST NOT REQUIRE SOLO DISPATCH ===

USER REQUIREMENT, STATED VERBATIM: "why do I ever have to run tasks solo? I don't like that restriction... worst case tasks will run in sequence." Sequencing is acceptable; exclusion and operator-instructed solo runs are not.

MEASURED MECHANISM (scripts/orchestrate-batch-admit.sh lines 476-495, verified by direct read; re-measure before relying on line numbers). The rule is exactly:
    if ($sm_flag == true) then
      if ($inv_count > 1) then  -> decision "defer", defer_reason "self_modifying"
      else                      -> decision "admit"
where $inv_count is --invocation-count, passed by skill-orchestrate Stage MT-3 step 4.5 as ${#eligible_tasks[@]}, i.e. this cycle's co-dispatch count. There is NO tie-breaker: EVERY self-modifying candidate defers whenever more than one task is eligible that cycle.

CONSEQUENCE A -- WORKS, BUT WASTEFUL. One self-modifying task among N ordinary tasks defers every cycle until it is the LAST eligible task, then admits. Observed live in a two-task batch: the self-modifying task deferred cycles 1-3 while its sibling ran research/plan/implement, then dispatched at cycle 4 and completed. It self-sequenced correctly. Cost was three wasted cycles, not exclusion.

CONSEQUENCE B -- THE REAL FAILURE. TWO OR MORE self-modifying tasks in one batch deadlock permanently. Once they are the only eligible candidates, $inv_count is 2, so BOTH defer; neither can ever become the sole candidate. The batch spins until skill-orchestrate's consecutive_no_dispatch_cycles convergence guard trips at 3 and ends the invocation "partial". The guard's own diagnostic (skill-orchestrate/SKILL.md around line 1668) already names this failure mode: "likely a mutually-colliding self-modifying set; re-run affected tasks solo or pass --allow-self-modifying". The system therefore already knows about the deadlock and its only remedy today is exactly the solo workaround the user is rejecting. Verified independently: a dry-run over three orchestrator-critical candidates admitted only one and excluded BOTH others with "re-run it alone (orchestrator-critical work runs solo only, never alongside sibling tasks)".

CONSEQUENCE C -- PHASE-BLINDNESS, LIKELY THE LARGEST FALSE-POSITIVE SOURCE. The gate keys on the task's DECLARED file_scope regardless of WHICH PHASE is being dispatched. But file_scope is the IMPLEMENTATION footprint. A research dispatch writes only to the task's own reports/ subdirectory; a plan dispatch writes only to plans/; both additionally write only .return-meta.json and .orchestrator-handoff.json inside their own task_dir. Neither can touch orchestrator machinery. Deferring a self-modifying task's research or plan dispatch is therefore a pure false positive. Applied to the observed session: that task's research and plan dispatches could have run concurrently with its sibling, and only its implement dispatch needed serialization -- three cycles saved at identical safety.

DIRECTIONS TO EVALUATE. Do not pre-commit; research must choose among these and record the reasoning, including any rejections.
  (1) TIE-BREAKER. Change the predicate from "defer if inv_count > 1" to "defer if inv_count > 1 AND this candidate is not the designated self-modifying candidate for this cycle". Selection must be deterministic -- lowest task number, or most live dependents; decide and record which. N self-modifying tasks then run in strict sequence rather than deadlocking. This is the minimal change that delivers the user's stated "worst case is sequence" requirement, and it is the change that supplies work stream A's replacement convergence exit condition.
  (2) PHASE-AWARE GATING. Apply the self-modification gate only to implement dispatches, not to research or plan dispatches. This requires the admission call site to know which phase each eligible task would dispatch to. Note that skill-orchestrate Stage MT-4 already computes exactly this via scripts/orchestrate-triage-classify.sh, but the admission call at Stage MT-3 step 4.5 runs BEFORE that classification, so either the ordering must change or the classifier must be called earlier. VERIFY THIS ORDERING CLAIM DIRECTLY before relying on it; a naive reordering may break other MT-3 invariants.
  (3) REDEPLOY-BOUNDARY SERIALIZATION (larger; may belong in a follow-up -- decide explicitly). The actual hazard is not concurrent editing: it is the inter-cycle redeploy checkpoint (Stage MT-3 step 7) rewriting the running orchestrator's own definition while sibling dispatches are in flight. That is a quiesce-before-redeploy problem, not a refuse-to-dispatch problem. Direction: let everything dispatch, and when a cycle's modified_files overlap critical paths, HOLD the redeploy until in-flight siblings reach a cycle boundary. This yields strictly more parallelism than (2) but materially more design work. If research concludes it belongs in a separate follow-up task, SAY SO and recommend the split explicitly rather than silently deferring it.

=== THE GENERAL PRINCIPLE TO RECORD (TIES BOTH WORK STREAMS TOGETHER) ===

Every admission gate should degrade to an ORDERING CONSTRAINT, never a PERMANENT EXCLUSION. Measured current state of the five gates:
  - file_scope_collision / in_batch      -> defers to a later cycle             = ordering (correct)
  - session_active                       -> defers                              = ordering (correct)
  - self_modifying                       -> defers, but deadlocks at 2+         = exclusion in practice (defect, work stream B)
  - file_scope_collision / cross_batch   -> excluded from the run               = exclusion (defect)
  - deploy_checkpoint                    -> excluded for the whole invocation   = exclusion (defect)
Three of five already satisfy the principle. The per-invocation override flags (--allow-self-modifying, and --allow-scope-collision added by the recently-completed consumer-threading work; both parsed in scripts/parse-command-args.sh around lines 141-144 and stripped around 168-169) are escape hatches bolted onto the exclusion cases -- evidence that the underlying shape is wrong, since a correctly-shaped gate would not need a bypass in order to make progress. Research should decide (i) whether to state this principle NORMATIVELY in context/patterns/batch-orchestration-guardrails.md, and (ii) whether the cross_batch and deploy_checkpoint gates are in scope here or are a recommended follow-up. Either answer is acceptable; silence is not.

=== COUPLING: WHY BOTH WORK STREAMS BELONG IN ONE TASK ===

These two defects are COUPLED, not merely adjacent:
  - Work stream A's single highest-risk consequence (named above) is that removing the in-flight status exclusion breaks the in_batch defer CONVERGENCE ARGUMENT, which currently relies on a task leaving eligible_tasks by "entering researching/planning, terminating, or failing". Work stream B's deterministic tie-breaker (direction 1) SUPPLIES a replacement exit condition that does not depend on status transitions at all. The second work stream therefore repairs what the first work stream breaks.
  - Both edit the same predicate file (scripts/orchestrate-batch-admit.sh) and the same co-maintenance set already enumerated under work stream A.
  - Splitting them would create two self-modifying work items with heavily overlapping file_scope, which -- under the very defect being fixed -- would mutually deadlock (CONSEQUENCE B). This is a concrete, not rhetorical, argument for keeping them together.

=== ACCEPTANCE ===

A stranded in-flight task with a stale lock is dispatched (or repaired then dispatched) rather than skipped, demonstrated against the real stranded set after re-measuring it. A task genuinely in flight under a FRESH foreign lock is still not concurrently dispatched, and the mechanism that prevents it is named. All co-maintained copies agree, verified by grep, and every safety argument listed above is either re-derived or corrected. New classifier fixtures cover the status-to-group rows for both engines and fail against the pre-fix classifier. The single-task engine's behaviour is either converged or divergent-by-record. Additionally:
  - N self-modifying tasks submitted in one batch ALL complete, dispatched in a deterministic sequence, with zero deadlock and no operator instruction to "run it solo".
  - A research or plan dispatch of a self-modifying task is NOT deferred merely because the task's IMPLEMENTATION footprint names a critical path -- if direction (2) is adopted; if it is rejected, record why.
  - The in_batch defer convergence argument is re-derived against whatever exit conditions actually exist AFTER both work streams land, and does not cite an exit condition that no longer holds.
  - No admission gate in the changed set produces a permanent exclusion where an ordering constraint would suffice; any remaining exclusion is named and justified.
  - The convergence guard's "re-run affected tasks solo" diagnostic is updated or removed, since it should no longer be reachable for a mutually-colliding self-modifying set.

SCOPE RULES (binding). Edit only agent-system/extensions/core/**, never the deployed .claude/** tree, per .claude/rules/source-store-deploy-boundary.md; verify via a deploy after the change rather than editing the deploy tree. No task-number references in any deliverable outside specs/**, per .claude/rules/no-task-references-in-deliverables.md -- cite filenames and section headings instead. context/patterns/multi-task-operations.md and context/patterns/task-lock.md were both checked and deliberately EXCLUDED from file_scope: neither asserts that in-flight status implies a held lock and neither restates the eligibility rule (task-lock.md's Tier-1 row only points at Stage MT-3 step 4.5 by reference, and multi-task-operations.md's status table is a per-command admission whitelist that actually admits implementing). scripts/parse-command-args.sh and context/reference/orchestrator-critical-paths.json HAVE been added to file_scope for work stream B: the former because a new selection or override behaviour may need a flag or a changed strip list, the latter because phase-aware gating may need per-path phase metadata. If either turns out not to need editing, leave it untouched rather than inventing a change. If implementation finds any other file genuinely needs editing, widen file_scope deliberately via state-write.sh, naming each file exactly -- no bare directory roots, no duplicate entries.

SELF-MODIFYING TASK. skills/skill-orchestrate/SKILL.md, skills/skill-orchestrate-hard/SKILL.md, scripts/orchestrate-triage-classify.sh, scripts/orchestrate-batch-admit.sh and scripts/task-lock.sh are all registered in context/reference/orchestrator-critical-paths.json, so orchestrate-batch-admit.sh will classify this task as self_modifying and defer it out of any cycle where it is co-dispatched. Under the CURRENT (pre-fix) predicate that means it will self-sequence into the last eligible slot, costing cycles but still completing -- CONSEQUENCE A, not CONSEQUENCE B, so long as it is the only self-modifying task in the batch. Do NOT run it solo: solo dispatch is the workaround this work exists to eliminate, and using it here would suppress the very evidence the fix needs. If it is co-dispatched with another self-modifying task and the batch stalls, that stall is the reproduction case for CONSEQUENCE B -- record it rather than working around it.

---

### 66. Mandate run_in_background for Lean builds and add long-builds anchor
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Mandate detached (run_in_background) invocation for Lean full builds across the lean extension's agent and skill contracts, and add a canonical anchor file documenting the foreground-cap livelock and the passive progress checks that do not disturb a running build.

PROBLEM (livelock, not slowdown). The Lean implementation contracts instruct agents to run a full `lake build` for final verification with no guidance on HOW to invoke it, so agents run it as a plain foreground Bash call. The Bash tool kills foreground calls at a 10-minute cap. Lean caches compilation per module, and a cap-killed build writes no .olean for the module it was working on, so NO progress is cached and the next attempt restarts at the identical module. The agent retries indefinitely and can never converge.

MEASUREMENT (illustrative, from one large Lean repo -- MUST NOT be hardcoded as an assumption in the contract text): a single module required ~11 minutes to elaborate (15 MB .olean, ~21 cores engaged, 8.2 GB peak RSS). Three consecutive agent attempts were each killed at the 10-minute cap. The same build run detached and uncapped completed in 11m56s (2457 jobs, exit 0); the blocking module alone accounted for ~11 minutes. The NORMATIVE statement in the contract must be the generic one: "any single module may exceed the foreground cap." The source store deploys to roughly ten repositories and must not assume this one repo's profile.

TRIGGER IS ORDINARY. Lean hashes whole files, so even a comment- or docstring-only edit to an upstream module invalidates every downstream .olean and forces the heavy cluster to rebuild. Any docstring pass re-arms the trap. The contract should say this explicitly so the failure is not read as exotic.

MECHANISM ALREADY EXISTS. Bash(run_in_background: true) runs detached, survives across turns, and re-invokes the agent on completion. This task adds no new machinery; it is contract text making that invocation mandatory. VERIFIED: `grep -rn run_in_background` across the entire lean extension returns zero hits today, so the guidance is absent, not merely weak.

DELIVERABLE 1 -- NEW CANONICAL ANCHOR (~40 lines):
  agent-system/extensions/lean/context/project/lean4/operations/long-builds.md
Follows the extension's single-anchor convention: one authoritative file referenced by path, prose never duplicated at the call sites. The operations/ directory already exists (currently holds multi-instance-optimization.md), so this is a sibling addition. Content: the 10-minute foreground cap; Lean's per-module caching; why a cap-killed build caches nothing and therefore livelocks rather than merely slowing down; the mandate to run builds via run_in_background; and the set of PASSIVE progress checks that do not disturb a running build -- fresh .olean files by mtime, the live `lean` PID's /proc/PID/cmdline (which module it is on), accumulated CPU time via `ps -o times` or /proc/PID/stat (the tiebreaker during a long single module, when the olean list looks frozen), and VmRSS trend (also an OOM early-warning). Include the honest caveat that these prove LIVENESS, not TERMINATION.
No manifest.json change required: this lands under the already-declared provides.context entry "project/lean4" (verified present in manifest.json alongside "contracts").

DELIVERABLE 2 -- POINT THE INSTRUCTION SITES AT THE ANCHOR. 19 files in the extension mention `lake build`; only the following actually instruct an agent to run one. Scope edits to these and no others. Line numbers verified at task-creation time and may drift:

  agents/lean-implementation-agent.md
    - line 165: verification step is currently a bare fenced ```lake build 2>&1``` block
    - line 424, MUST DO item 8, currently: "Always run full `lake build` before returning implemented status (final verification only)"
      becomes: "...(final verification only). Run it via `Bash(run_in_background: true)`, never as a plain foreground call -- see `context/project/lean4/operations/long-builds.md`."
    - add a NEW MUST NOT item: "**Run a full `lake build` as a foreground Bash call.** The 10-minute cap kills it mid-module; a killed build caches no .olean, so retries restart at the same module and livelock indefinitely."
      Placing the prohibition in MUST NOT is DELIBERATE and must not be softened into advisory prose mid-file: MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is exactly what gets skipped, which is how this defect survived.
  agents/lean-implementation-hard-agent.md -- engine twin. Note the twin is NOT line-symmetric with the base file: its MUST DO item is number 7 at line 515 (not item 8), it has an additional site at line 223 (`lake build ModuleName 2>&1`), a full-build fence at line 373, and line 356 describes a stripper that "runs its own `lake build`". Locate by content, not by line number.
  agents/lean-research-agent.md -- lighter touch (line 52 tool description, line 183 "verify with `lake build`")
  agents/lean-research-hard-agent.md -- lighter touch (line 59 tool description)
  skills/skill-lean-implementation/SKILL.md -- build-verification stage (lines 108, 302)
  skills/skill-lean-implementation-hard/SKILL.md -- build-verification stage (lines 223, 444)
  skills/skill-lake-repair/SKILL.md -- see the ARCHITECTURAL EXCEPTION below
  rules/lean4.md -- pointer to the anchor. NOTE: the prompt estimated a one-line pointer, but this file carries a whole build-command reference block (lines 47-48, 58, 61-62) presenting scoped-vs-full choice as purely a speed tradeoff. Expect more than one line.

ARCHITECTURAL EXCEPTION -- skill-lake-repair/SKILL.md IS THE HIGHEST-RISK EDIT, DO NOT TREAT IT AS A POINTER EDIT. Its repair loop captures build output synchronously via command substitution: `build_output=$(lake build "$module" 2>&1)` and `build_output=$(lake build 2>&1)` at lines 69 and 71. Command substitution is fundamentally incompatible with run_in_background, which does not return stdout to a shell variable. Honoring the mandate here requires restructuring the loop to redirect build output to a file and poll that file, not appending a pointer. Decide and record whether the repair loop is (a) restructured to file-and-poll, or (b) explicitly carved out of the mandate with its cap-vulnerability documented in the anchor. Do not silently leave it as-is while claiming the mandate is enforced extension-wide.

DECISION TO MAKE -- SCOPED BUILDS ARE ALSO CAP-VULNERABLE. Currently lean-implementation-agent.md MUST DO item 7 (line 423) says to "prefer `lake build Module.Name` for phase-end verification (scoped, faster)" and MUST NOT item 3 (line 436) explicitly exempts scoped builds from the full-build mandate; rules/lean4.md lines 47/58/61 repeat this framing. But the measurement above is that a SINGLE MODULE took ~11 minutes, which exceeds the cap on its own -- so the scoped build these lines recommend as the safe fast path is itself cap-vulnerable, and an agent following the contract can livelock at phase-end verification without ever reaching a full build. Recommended resolution: extend the anchor and the mandate to cover any build that may touch an uncached heavy module, full or scoped, and revise item 7 / MUST NOT item 3 / the rules/lean4.md block so scoped-vs-full is no longer presented as the safety boundary. If instead the narrower full-builds-only scope is chosen, record why and leave the scoped-build vulnerability explicitly noted rather than unmentioned. This decision was flagged at task creation and was NOT confirmed by the user -- the interactive confirmation gate was unavailable in the creating context -- so treat it as an open recommendation to validate during research, not a settled requirement.

TWIN-FILE DISCIPLINE (binding). The base and -hard variants must be edited together in this task. The extension treats a one-sided edit between engine twins as a known recurring defect class, and the two files are not line-symmetric (see above), so a mechanical copy of one diff onto the other will not work -- locate each site by content.
VERIFIED NON-SURFACE: opencode-agents.json contains zero `lake build` occurrences, so it does not mirror this contract prose and needs no edit. There is no third drift surface.

SOURCE-STORE RULE (binding): all edits target agent-system/extensions/lean/**. Never edit a deployed .claude/** tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes. NOTE: the originating prompt gave the file_scope paths rooted at `extensions/lean/...`; the actual source store at this repo root is rooted at `agent-system/`, so the correct paths are `agent-system/extensions/lean/...` as recorded in file_scope.
DELIVERABLE RULE (binding): no task-number references in the contract text. These files are deliverables outside specs/, governed by the no-task-references-in-deliverables rule. Cite the anchor filename and the mechanism, never a task number.

ADJACENT TASK, NO FILE OVERLAP: an in-progress task holds agent-system/extensions/lean/opencode-agents.json in its file_scope. That file is not in this task's scope and carries none of this contract prose, so no serialization is required.

ACCEPTANCE: long-builds.md exists at the stated path with the cap, the per-module-caching livelock explanation, the run_in_background mandate, and the four passive progress checks with the liveness-not-termination caveat; every instruction site above points at the anchor rather than restating its prose; lean-implementation-agent.md carries the new MUST NOT item verbatim in intent; the -hard twin carries equivalent changes located by content; the skill-lake-repair command-substitution incompatibility is resolved or explicitly carved out with a recorded reason; the scoped-build decision is recorded either way; the normative text says "any single module may exceed the foreground cap" with the ~11-minute figure present only as an illustrative note; no .claude/** file is modified; no task numbers appear in any edited file.

---

### 65. Fix mint dispatch seq persisted counter
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [065_fix_mint_dispatch_seq_persisted_counter/reports/01_mint-dispatch-seq-fresh-shell-fix.md]
- **Plan**: [065_fix_mint_dispatch_seq_persisted_counter/plans/01_mint-dispatch-seq-persisted-counter-fix.md]

**Description**: Fix skill_orchestrate_mint_dispatch_seq to increment from the persisted counter. The helper in scripts/skill-base.sh computes dispatch_seq_counter=$((dispatch_seq_counter + 1)) from an ambient shell variable rather than from the value it reads back out of the loop guard file, then persists that result. Any caller that does not hold a single long-lived shell across the whole orchestration loop therefore re-mints the same value on every dispatch: in a fresh shell the variable is unset, so it evaluates to 0 + 1 = 1 every time. Observed during an /orchestrate run where each Bash tool call ran in its own shell -- the second dispatch re-returned dispatch_seq=1 despite the loop guard already carrying dispatch_seq_counter=1. Impact: dispatch_seq is the content-based discriminator the Stage 5 identity gate relies on to tell a legitimate current-dispatch handoff apart from a still-live predecessor's late write (mtime alone is structurally insufficient -- see context/patterns/dispatch-report-not-termination.md). A repeated value defeats that gate in both directions: a stale predecessor handoff carrying seq=1 would pass as the current dispatch's own report, and the mismatch branch could fire against a legitimate handoff. Likely fix: read the counter from the loop guard file inside the function (jq -r '(.dispatch_seq_counter // 0) + 1') rather than from the ambient variable, matching the read-modify-write idiom the multi-task engine already uses at Stage MT-4. Check whether skill-orchestrate-hard/SKILL.md's Stage 2 shares the same helper and is affected identically, and whether test-handoff-dispatch-identity.sh covers the fresh-shell case. SECOND INDEPENDENT CONFIRMATION (Philosophy/Papers/PossibleWorlds repo, base-mode /orchestrate of a formal task, 3 cycles): reproduced exactly as described above, in a different repository and a different task type. Cycle 1 (research) minted dispatch_seq=1 correctly; cycle 2 (plan) re-minted dispatch_seq=1 from a fresh shell while the loop guard already carried dispatch_seq_counter=1. The orchestrator worked around it by seeding dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file") immediately before each skill_orchestrate_mint_dispatch_seq call, which produced correct seqs 2 and 3 for the remaining cycles; both later handoffs then passed the Stage 5 identity gate cleanly. This confirms the defect is not environment-specific and that it fires for ANY orchestrator driving its cycles through separate Bash tool invocations rather than one long-lived shell -- which is the normal execution shape for the base-mode engine, not an edge case. The caller-side seeding above is a workaround only and was NOT committed anywhere; the durable fix remains the read-inside-the-function change described above.

---

### 64. Decide and implement how --hard behavioral contracts reach agents system-wide
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 31, Task 42, Task 63

**Description**: Decide and implement how --hard behavioral contracts reach agents system-wide. Only core, cslib, and lean declare routing_hard/routing_agents_hard. For every other extension that declares routing, --hard resolves via=hard-miss-standard-fallback and the H2-H5 behavioral contracts never reach the agent, even though CLAUDE.md advertises --hard as composable with extension routing at a 3-5x cost multiplier. In the originating session the H2/H3/H4/H5 contracts had to be hand-injected into the delegation prompt by the orchestrator for --hard to mean anything at all, which is neither reproducible nor something a user should have to do.

CORRECTED COUNT - VERIFIED INVENTORY, USE THIS NOT THE 16 FIGURE. The delegating description said 16 extensions and listed literature and slidev among them. A direct inventory of all 19 manifests under agent-system/extensions/*/manifest.json shows the real figure is 14. literature and slidev declare routing_exempt: true and declare NO routing blocks whatsoever - they are legitimately exempt, not gaps, and must not be counted, rolled out to, or failed by any lint.
The 14 that declare routing (and routing_agents) but no routing_hard/routing_agents_hard are: email, epidemiology, filetypes, formal, founder, latex, memory, nix, nvim, present, python, typst, web, z3.
For completeness: core declares routing_agents + routing_hard + routing_agents_hard but no plain routing block; cslib and lean declare all four.
CONSEQUENCE FOR LINT DESIGN: any check must skip routing_exempt: true manifests, or it emits 2 false failures on literature and slidev.

DECIDE, DO NOT PRESUPPOSE:
  (a) Declare hard variants across the remaining 14 manifests.
  (b) Make the fallback inherit standard extension routing while delivering hard contracts from a single shared contract block rather than per-skill '-hard' files.
  (c) Both, plus a lint check flagging any extension that declares routing but no routing_hard.
Weigh (b) seriously. The shared ladder lives in exactly one place - agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh, consumed by both command-route-skill.sh and command-route-agent.sh - so a resolver-side fix is a single change point covering all extensions, whereas (a) is 14 manifest edits that can drift. The fact that only 3 of 19 extensions have hard variants is itself evidence that the per-extension '-hard' file approach does not scale, and that evidence bears directly on the choice.

DEPENDS ON THE AGENT-SIDE ROUTING-DOWNGRADE FIX IN THIS BATCH, AND THAT FIX MATERIALLY DE-SCOPES THIS ONE. Once the agent side inherits standard extension routing on a hard miss, most of the 14 resolve to their correct domain agent with ZERO manifest edits. What remains is then the narrower and different question of how the H2-H5 CONTRACTS reach the agent, which is the shared-contract-block idea in option (b). Do not price a 14-manifest rollout before that fix has landed - it would be costing work the fix largely obviates. Re-run the resolver inventory after the dependency completes and report what actually still misroutes.

LINT COORDINATION (binding, read before proposing lint scope). The existing not_started task fix_present_extension_compound_skill_routing already proposes extending lint-routing-wiring.sh, which currently validates declared AGENT names but not SKILL names. Read that task's description in specs/state.json first. The checks are genuinely additive rather than duplicative, and the current coverage matters: lint-routing-wiring.sh already has Check A (routing.{op} keys have routing_agents.{op} counterparts), Check B (routing_agents/routing_agents_hard values name existing agent files), Check C (routing_hard.{op} keys have routing_agents_hard.{op} counterparts), and Check D (report-only general-* declarations). Check C therefore ALREADY covers the within-manifest hard counterpart requirement. What is missing is a new check for 'declares routing but no routing_hard at all' - additive to that task's Check B skill-name extension. Both edit the same file, so declare a dependency or otherwise serialize with it rather than duplicating its work or racing it.

ACCEPTANCE: a single documented decision among (a)/(b)/(c) with its reasoning recorded; --hard delivers the H2-H5 contracts to agents for every non-exempt extension without requiring per-invocation hand-injection by the orchestrator; any lint check added skips routing_exempt manifests and does not duplicate the sibling task's skill-name validation; CLAUDE.md's claim that --hard is composable with extension routing is either made true or corrected to match reality.

RELATED BUT DISTINCT - DO NOT ABSORB. The typst/latex task-type restriction task in this repo concerns which task type a task is ASSIGNED from keywords, not which agent or contracts a type resolves to. No file overlap with this task's resolver and lint scope, though note that if option (a) is chosen it would edit the typst and latex manifests, which that task also touches (different keys: keyword_overrides/aliases there, routing_hard/routing_agents_hard here) - coordinate if (a) is selected.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 63. Fix the agent-side hard-mode routing downgrade that discards declared domain agents
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [063_fix_hard_mode_agent_routing_downgrade/reports/01_agent-routing-hard-mode-parity.md]
- **Plan**: [063_fix_hard_mode_agent_routing_downgrade/plans/01_fix-hard-mode-agent-routing.md]
- **Summary**: [063_fix_hard_mode_agent_routing_downgrade/summaries/01_fix-hard-mode-agent-routing-summary.md]

**Description**: Fix the agent-side hard-mode routing downgrade. command-route-agent.sh, given effort_flag=hard and a task_type whose extension declares no routing_agents_hard, falls through to the caller-supplied default_agent and DISCARDS the extension's declared standard agent. So --hard routes strictly worse than no flag, losing the domain agent entirely.

VERIFIED EVIDENCE (reproduced independently against the source store with ROUTE_MANIFEST_ROOT=agent-system; do not re-derive). Originally observed in a live /research --fable --lit --hard invocation in the Logos/Theory repo:
  op=research task_type=formal:logic effort=hard resolved=general-research-agent via=default
  op=research task_type=formal:logic effort=     resolved=logic-research-agent   via=noncore-exact
The defect is NOT compound-key-specific. The same downgrade reproduces on a simple task_type:
  op=research task_type=typst        effort=hard resolved=general-research-agent via=default
  op=research task_type=typst        effort=     resolved=typst-research-agent   via=noncore-exact
It therefore affects every extension that declares routing_agents but no routing_agents_hard (14 extensions; see the companion contract-delivery task in this batch for the verified inventory).

THE DECISIVE FINDING - THIS IS A PARITY DEFECT, NOT A DEBATABLE FALLBACK. The two resolvers that were consolidated onto the shared ladder kept DIVERGENT fallback policies, and the skill-side resolver already implements the correct never-worse-than-standard behavior:
  - command-route-skill.sh (lines ~57-65) resolves the standard SKILL_NAME FIRST, then on hard mode only UPGRADES it: a routing_hard hit wins; else a '-hard'-appended candidate is used only if its SKILL.md exists on disk (via=hard-append-fallback); else it KEEPS the standard skill and emits via=hard-miss-standard-fallback. Standard resolution is never discarded.
  - command-route-agent.sh (lines ~62-68) computes ONLY the hard block, then unconditionally overwrites with AGENT_NAME="$_route_default_agent"; _route_via="default". The extension's declared standard agent is never consulted at all.
So the fix is to bring the agent side to parity with the already-correct skill side, not to invent new policy. Note also that the agent script's own header justifies the fall-through as "matching the behavior of the case tables this script replaces" - i.e. it was a conservative do-no-harm choice made during a consolidation refactor, NOT a considered design decision that domain agents should be discarded. That is the evidence bearing on whether the documented intent or its consequence is the thing that is wrong. Establish that explicitly, then fix accordingly.

LIKELY CORRECT LADDER: routing_agents_hard -> the extension's routing_agents -> default_agent. This preserves the documented intent (a caller's own hard-mode default such as general-research-hard-agent is still honored on a genuine total miss where no extension declares anything) while no longer discarding a declared domain agent.

BINDING CONSTRAINT - AN EXISTING TEST PINS THE CURRENT BEHAVIOR AS CORRECT AND MUST BE AMENDED. agent-system/extensions/core/scripts/tests/test-routing-resolution.sh Assert 3 (semantic) iterates `for tt in neovim nix` and asserts hard-mode research resolves to the caller default, failing with "expected fall-through to caller default"; its header frames standard-block reuse as "a precedence-direction / fallback-source regression". The fix necessarily amends that assertion. Keep Assert 3's lean4 half intact - it still validly proves hard mode reads a DISTINCT block (lean4 standard resolves lean-research-agent, hard resolves lean-research-hard-agent). Also note `nix` is itself one of the 14 extensions lacking hard blocks, so if the companion task later declares hard blocks for nix, that fixture's meaning shifts again; leave a comment in the test recording this coupling.

SCOPE (source store only, never .claude/**): agent-system/extensions/core/scripts/command-route-agent.sh (the primary change), agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh (the shared ladder, only if the fix genuinely belongs there rather than in the consumer), and agent-system/extensions/core/scripts/tests/test-routing-resolution.sh. Consider adding the via=hard-miss-standard-fallback vocabulary to the agent-side trace so the agent and skill resolvers report the same diagnostic shape.

ACCEPTANCE: --hard never resolves to a less specific agent than the same call without --hard, for all 19 extensions; the caller-supplied hard default is still honored where no extension declares anything for that (op, task_type); lean4 still resolves lean-research-hard-agent under --hard; the routing test suite is green with Assert 3 amended to pin the corrected contract rather than the defect.

RELATED BUT DISTINCT - DO NOT ABSORB. The typst/latex task-type restriction task in this repo governs WHICH task type gets assigned from keywords (manifest keyword_overrides/aliases, /task's keyword table, meta-keyword precedence). This task governs WHICH AGENT a given task type resolves to under --hard. No file overlap. They compound, though, and that is worth knowing: a content-bearing task misfiled as typst AND run with --hard currently loses both the correct domain agent and the hard contracts.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 62. Restrict typst latex task types to formatting only
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Restrict typst and latex task types to formatting-only concerns. Identify what in the agent extension system needs revision so that the 'typst' and 'latex' task types are assigned ONLY when a task is concerned purely with formatting/typesetting issues, not with the intellectual content of what is being formatted. Investigation should cover: keyword_overrides and aliases in the typst/latex extension manifests, the hardcoded keyword table in /task step 4d ('latex', 'tex', 'document', 'typeset' -> latex; 'typst' -> typst), the interaction with the meta-keyword precedence rule in step 4a, alias remapping in step 4e, and any routing or documentation that assumes content-bearing work routes to these types. Produce the concrete revisions needed (manifest edits, keyword table changes, precedence adjustments, docs) so content-focused tasks route to a substantive task type instead.

---

### 61. Surface coarse and duplicate file_scope declarations at task-creation time
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 59
- **Research**: [061_surface_coarse_file_scope_declarations_at_creation/reports/01_coarse-file-scope-detection.md]
- **Plan**: [061_surface_coarse_file_scope_declarations_at_creation/plans/01_coarse-file-scope-advisory.md]
- **Summary**: [061_surface_coarse_file_scope_declarations_at_creation/summaries/01_coarse-file-scope-advisory-summary.md]

**Description**: Treat whole-directory-root file_scope declarations as a declaration-quality problem caught at task creation, rather than as a runtime blocker discovered only when /orchestrate silently excludes a candidate.

MOTIVATING EXAMPLE (real, from the live incident): a BimodalLogic documentation task named update_readme_and_module_docstrings declares ["README.md", "ROADMAP.md", "FormalSystem/", "FormalSystem/", "docs/"]. Note that FormalSystem/ appears TWICE. That single declaration exhibits both defects at once - a whole-directory root that swallows essentially every Lean task in the repo, and an exact duplicate entry. This repo has the same pattern: one idle task declares the bare directories commands/ and skills/, and another declares the bare directory context/.

WORK:
1. Flag whole-directory-root declarations (a bare top-level or near-top-level directory) at task creation and in state validation, with a warning that names the concrete blast radius - how many existing non-terminal tasks the declaration would overlap - rather than a generic caution.
2. Detect and de-duplicate exact duplicate file_scope entries.
3. Keep this advisory at creation time, not blocking. The point is to fix declaration quality upstream, not to add a second runtime gate.

Relationship to the predicate task in this batch: that task stops coarse declarations from silently blocking dispatch; this task stops them from being written in the first place. Both are needed - the predicate fix alone leaves declaration quality unaddressed, and this task alone does nothing about the declarations already sitting in state.

COLLISION WORKAROUND: this task's declared scope overlaps two idle tasks in this repo - one declaring commands/task.md exactly, and one declaring the bare directory commands/. Workaround dependencies[] edges have been written onto those two colliding tasks pointing AT this task - deliberately that direction, because writing them onto this task instead would block it until both completed, which is backwards.

WORKAROUND EDGES (remove once the admission-gate predicate fix is deployed): the dependencies[] edges added to the colliding tasks named above are artifacts of the very defect this batch fixes, not genuine ordering constraints. They exist only to dissolve the cross_batch file_scope collision that would otherwise permanently exclude this task from /orchestrate. Once the predicate fix is implemented and deployed, the collision no longer fires against idle tasks and every one of these edges must be removed.

---

### 60. Thread the evidence-gated verdict and --allow-scope-collision through admission consumers
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 59
- **Research**: [060_thread_evidence_gated_verdict_through_admission_consumers/reports/01_thread-evidence-gated-verdict.md]
- **Plan**: [060_thread_evidence_gated_verdict_through_admission_consumers/plans/01_thread-evidence-gated-verdict.md]
- **Summary**: [060_thread_evidence_gated_verdict_through_admission_consumers/summaries/01_thread-evidence-gated-verdict-summary.md]

**Description**: Consumer-side half of the batch-admission gate redesign. The predicate task in this batch changes the admission predicate and bumps the verdict schema to v5; this task updates every consumer that branches on it.

WORK:
1. Render the new advisory field emitted for provably-idle overlaps in the dispatch-path warning and in the batch results surface. The advisory must be loud - advisory never means unlogged or silent.
2. Add an --allow-scope-collision per-invocation override, symmetric with the existing --allow-self-modifying. Thread it parser -> command -> both orchestrate skills. It must NEVER be passed to orchestrate-batch-admit.sh, which always computes and emits the honest verdict regardless; the override is a consumer decision not to ACT on an emitted verdict, with a loud bypass notice logged either way. Defaults off, per-invocation only. No override for file_scope_collision was ever considered and rejected in the corpus - this is a genuinely open addition, not a reversal of a recorded decision.
3. Fold orchestrate-predispatch-review.sh's EXISTING Class D dependencies[]-edge suggestion into the dispatch-path warning. Class D already emits a suggestion to add the predecessor as a dependencies[] entry; the gap is only that it lives in a separate review surface rather than where the exclusion is actually reported. Do not build a new suggestion mechanism.
4. Correct the false self-clearing claims. skill-orchestrate/SKILL.md claims BOTH collision branches become eligible again on a later cycle, which is false for cross_batch. The corpus is three-way contradictory here: the schema doc instead says the out-of-batch task is idle and will not advance on its own so a human resolves batch composition, while commands/orchestrate.md says the candidate is excluded from this run. Make all three agree with the post-fix behavior.
5. Fix the stale schema-v3 prose in the two consumer files that still say v3 while emitting v4 (v5 after this batch).

Co-maintenance: skill-orchestrate and skill-orchestrate-hard are transcription twins - every consumer change must land in both.

This task declares orchestrator-critical paths and is therefore self_modifying, requiring solo dispatch. Expected and accepted.

COLLISION WORKAROUND: this task's declared scope overlaps four idle tasks in this repo - two that declare skills/skill-orchestrate/SKILL.md, one that declares the bare directories commands/ and skills/ (which swallow this scope entirely), and one that declares the bare directory context/. Under the current gate this task would be permanently excluded from /orchestrate by the very defect it fixes. Workaround dependencies[] edges have been written onto those four colliding tasks pointing AT this task - deliberately that direction, because writing them onto this task instead would block it until all four completed, which is backwards and defeats the purpose.

WORKAROUND EDGES (remove once the admission-gate predicate fix is deployed): the dependencies[] edges added to the colliding tasks named above are artifacts of the very defect this batch fixes, not genuine ordering constraints. They exist only to dissolve the cross_batch file_scope collision that would otherwise permanently exclude this task from /orchestrate. Once the predicate fix is implemented and deployed, the collision no longer fires against idle tasks and every one of these edges must be removed.

---

### 59. Gate cross-batch file_scope collisions on execution evidence, not non-terminal status
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [059_narrow_cross_batch_collision_to_execution_evidence/reports/01_narrow-cross-batch-collision.md]
- **Plan**: [059_narrow_cross_batch_collision_to_execution_evidence/plans/01_narrow-cross-batch-collision.md]
- **Summary**: [059_narrow_cross_batch_collision_to_execution_evidence/summaries/01_narrow-cross-batch-collision-summary.md]

**Description**: The /orchestrate batch-admission gate's specs/state.json collision dimension defers a candidate against ANY non-terminal task whose file_scope overlaps it with no dependencies[] edge. Because a cross_batch defer can never self-clear (an idle task's status cannot change without a dispatch), any broad-scoped not_started task becomes a permanent blanket blocker. Observed in the BimodalLogic repo: an /orchestrate invocation permanently excluded a candidate on every cycle because an idle documentation task declaring the whole FormalSystem/ directory overlapped it. That colliding task held no lock, had no live session-registry entry, and could not have been editing anything; corroborated_by named non_terminal_status as the sole basis for the defer.

ROOT CAUSE (verified during investigation): the dimension conflates ORDERING (both tasks will eventually touch these files, so one should land before the other) with CONCURRENCY (two agents are writing these files right now). Ordering belongs in dependencies[]; concurrency is already handled correctly by task-lock.sh and the v4 session_active dimension, whose session_contention() def in scripts/lib/file-scope-overlap.sh already gates on liveness via pid-alive / heartbeat staleness. Decisive evidence that this is an undeclared-ordering check rather than a genuine conflict check: adding a dependencies[] edge dissolves the collision entirely, which no real concurrent-write hazard could permit.

Two further findings confirm the strictness was never actually derived. First, the blocking rationale in batch-admit-schema.md is self-refuting within a single sentence: it justifies the block as 'two sessions can concurrently edit the same files with no lock contention' while parenthetically conceding 'the colliding task holds no lock; it simply is not running'. Second, batch-orchestration-guardrails.md's Blocking-vs-Advisory decision table has NO cross_batch row at all - its file-scope row covers only the creation-time and runtime wave/cycle-split (in_batch) case. The verification-gap hazard does not defend this dimension either: the guardrails explicitly state it is 'UNAFFECTED BY THE SCOPE CHOICE IN EITHER DIRECTION' and scope it to self-modification.

SCOPE OF FIX (deliberately narrow): narrow the state.json dimension's defer condition to actual execution evidence - an in-flight status in {researching, planning, implementing}. Live-session coverage stays session_active's job and must not be duplicated here. A provably-idle overlap becomes an admit verdict carrying a loud advisory field rather than a defer; the advisory must never be silent. in_batch behavior stays blocking and unchanged bit-for-bit, because both candidates there are genuinely about to be dispatched, which does satisfy the Blocking-vs-Advisory criterion. Bump the verdict schema to orchestrate-batch-admit-v5, correct the self-refuting rationale, and add the missing cross_batch row to the Blocking-vs-Advisory table.

This narrowing is evidence-gating, not batch-size-gating, so it does not conflict with the guardrails' standing rejection of relaxing a blocking check as batch size grows. The shared overlap predicate is NOT changed: file-footprint-overlap.md explicitly disclaims any opinion on scan scope, so this is a comparison-set filter change only. Only three files pin the schema version string, so the version bump has a narrow blast radius, but consumers branching on defer_reason are updated separately by the consumer-side task in this batch.

This task declares orchestrator-critical paths and is therefore self_modifying, requiring solo dispatch. Expected and accepted.

CLOSING STEP: after this task is implemented AND deployed, remove the workaround dependencies[] edges recorded on the four colliding tasks in this repo's state (the ones pointing at this batch's three task numbers). Those edges exist only to work around the defect this task fixes and must not outlive it.

WORKAROUND EDGES (remove once the admission-gate predicate fix is deployed): the dependencies[] edges added to the colliding tasks named above are artifacts of the very defect this batch fixes, not genuine ordering constraints. They exist only to dissolve the cross_batch file_scope collision that would otherwise permanently exclude this task from /orchestrate. Once the predicate fix is implemented and deployed, the collision no longer fires against idle tasks and every one of these edges must be removed.

---

### 53. Suppress expected handoff absence defect
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: Task 17, Task 44

**Description**: Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect when a contractual non-writer leaves no fresh handoff. Observed live on a clean, fully-successful base-mode /orchestrate run (recorded as evt_1786550950625_o2KoSv; the class already has 3 occurrences in specs/events.jsonl).

OBSERVED MECHANISM (verified, do not re-derive). In a base-mode /orchestrate run of a task that entered at [RESEARCHED], the plan dispatch wrote .orchestrator-handoff.json carrying dispatch_seq=1. The implement dispatch that followed wrote no handoff, correctly: docs/architecture/handoff-schema.md's "Handoff Writers" table settles that .orchestrator-handoff.json is hard-mode-implement-only, and general-implementation-agent.md states "base-mode implement is a non-writer by design". Nothing clears the prior cycle's handoff, so the planner's file was still sitting at the path when Stage 5 ran. Both freshness gates fired on it exactly as designed -- mtime predated the dispatch window, and dispatch_seq=1 did not match the minted dispatch_seq=2 -- and the dispatch_seq gate recorded a HANDOFF_STALE_OR_ABSENT system defect. The run then proceeded correctly: orchestrate-recover-outcome.sh recovered status=implemented, 7/7 phases, from .return-meta.json, and the task completed.

THE DEFECT IS ORDERING, NOT DETECTION. The gates are right and must not be weakened -- they are the identity mechanism delivered by the handoff-identity work, and they are the reason a genuine late-writer clobber would be caught. The bug is that the recording happens BEFORE the system consults whether the absence was expected. skill-orchestrate/SKILL.md's own recovery branch prints "no handoff written for this dispatch -- expected outcome for this phase's writer (base-mode research/plan/implement never write one)". The knowledge that this is expected already exists in the file; it just arrives one step too late to suppress the defect record. The recorder therefore fires on a run in which nothing went wrong.

WHY THIS MATTERS BEYOND NOISE. A defect class that fires on ordinary success carries no information, and a real stale-handoff incident becomes indistinguishable from routine base-mode operation. This is the same failure shape as the gate-out warning that cannot separate silent failure from ordinary success, tracked separately. It also directly bears on the open question of whether "zero defect events on a clean run" is a sound acceptance bar, tracked in the verification-trust bundle: that item assumes the recorder only fires on genuine agent-compliance slips. This observation falsifies that assumption and should be folded in as evidence when that decision is made.

SECOND, INDEPENDENT QUESTION -- DECIDE EXPLICITLY. Base-mode dispatch contexts pass handoff_path to every dispatch (research, plan, and implement alike), which invites a contractual non-writer to write a handoff at all. That is how the planner came to write one in the observed run. Decide whether base mode should stop passing handoff_path except where a writer is contractually expected, or whether passing it uniformly is deliberate and the leftover file should instead be cleared or rotated at dispatch start. Either resolution is acceptable; the current arrangement, where a non-writer is handed a write target and its output then trips the successor's freshness gates, is not.

CANDIDATE DIRECTIONS (evaluate, do not blindly adopt): (a) consult the writer contract before recording -- if the dispatched writer is contractually a non-writer for this mode and phase, treat a stale-or-absent handoff as the expected outcome and log it without recording a defect; (b) clear or rotate any pre-existing handoff at dispatch start so the gates only ever fire on a genuine late write from a live predecessor; (c) narrow handoff_path propagation to contractual writers. Note that (b) alone must not blind the gates to the live-predecessor late-write case, which is the hazard they exist to catch.

CO-MAINTENANCE (binding). skill-orchestrate/SKILL.md and skill-orchestrate-hard/SKILL.md carry an explicit co-maintenance contract, and the Stage 5 staleness/dispatch_seq gate is a verbatim twin across the two. A one-sided fix here reproduces a named recurring defect class. Both copies must be changed together, or the asymmetry recorded in both.

ACCEPTANCE: a clean base-mode /orchestrate run that transitions plan to implement records no system defect; a genuine stale or late-written handoff still trips the gates and still records one; and both engines agree. Demonstrate both directions -- a detector that can only ever stay silent is not a fix.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 51. Move session state files out of specs root
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Move per-session state files cluttering the specs/ root (.orchestrator-multi-state-sess_* and .return-meta-*.json files) into a dot-prefixed directory, or handle otherwise as most appropriate

---

### 50. Restore verification trust and close hygiene residue
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 17, Task 18, Task 22, Task 28, Task 31, Task 34, Task 39, Task 41, Task 42, Task 43, Task 44, Task 47, Task 48, Task 59, Task 60, Task 61, Task 63, Task 64

**Description**: Make the verification surface trustworthy, and close the doc-truth and duplication residue. Grouped because each item individually is too small to dispatch, and all of them undermine confidence in the same gate suite.

(1) THE SHELL TEST SUITE IS NON-DETERMINISTIC (highest value item here). Measured across five consecutive runs of scripts/tests/run-all.sh: exit 1, 0, 1, 0, 0 -- roughly a 2-in-5 failure rate, with passing runs reporting a clean 36/36. During the same review, verify-deploy.sh gate 8 passed while a standalone run failed minutes later. A gate that passes 60% of the time is not evidence of health in either direction. It is also actively harmful to the refactor's own acceptance gate: the capstone attributed a real failure to "a flaky lock-contention test attributable to concurrent sibling sessions, not a deploy defect" WITHOUT being able to confirm that, precisely because the suite cannot distinguish the two. Diagnose the contention (the suite runs concurrently with other live sessions holding the same locks), then either isolate the affected tests from shared global state or make them wait deterministically. A test that is merely retried is not fixed. ACCEPTANCE: 10 consecutive runs, executed while at least one other session is active, all report the same result.

(2) THE DEPLOY NON-DETERMINISM FINDING HAS NO OWNER. The capstone's defect ledger dispositions err_1786350581240_JyztWt (deploy_nondeterministic_merge) as "folds into" the orphan-file parity task, and leaves err_1786350581208_23mAsn (deploy_merge_content_loss, observed once, then 0-of-3 on re-check) as entry-only. The parity task's actual text discusses only the four orphan files -- it never mentions ordering or content loss. The fold was recorded but never performed, so capstone DEPLOY sub-item ii ("running the deploy twice is byte-identical") is failing with nobody assigned. A fold recorded but not performed is exactly the failure mode a defect ledger exists to prevent; note that as a process finding, not only a technical one. WORK: run the scratch wipe-pair procedure, establish whether context/index.json and settings.json still differ by object-key/array-element ordering beyond the expected generated timestamp, re-check the settings.local.json content-loss observation, and either fix the ordering non-determinism or record an explicit decision that semantic equality under `jq -S` is the standard and byte-identity is not required. Either resolution is acceptable; the current silent ambiguity is not.

(3) RE-SCOPE OR SATISFY THE LIVE-CYCLE DEFECT CRITERION. The capstone requires that a clean orchestration cycle emit no system_defect event and that the deferred-defect surface render empty. specs/events.jsonl now holds 5 such events (3 from 2026-08-08 plus 2 newer: OFF_SCHEMA_STATUS and META_MISSING_AFTER_NARRATION). Both new events are correctly-firing detectors catching real agent-compliance slips -- the recorder working as designed, not noise. DO NOT FIX THOSE TWO DEFECTS HERE: the OFF_SCHEMA_STATUS handoff-key problem belongs to the in-flight handoff identity-contract task, and META_MISSING_AFTER_NARRATION belongs to the in-flight nonterminal-fanout task. Both should have the observation appended to them. What is unowned, and what belongs HERE, is the criterion itself: decide whether "zero defect events on a clean run" is the right acceptance bar given a recorder that will legitimately fire whenever any agent slips, or whether it should be re-scoped to "no NEW defect classes" -- the same precedent the capstone already set for its unverifiable gate-out criterion. Record the decision where the acceptance criteria live.

(4) DUPLICATION WITH AN AVAILABLE SHARED MECHANISM. (a) The literal one-liner `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` appears 43 times across 35 command and skill files, while common_session_id() exists in scripts/lib/common.sh and is already wired into command-gate-in.sh. (b) The jq Issue #1132 safety block appears in 34 source files against a canonical home in context/patterns/jq-escaping-workarounds.md and a CLAUDE.md section -- roughly 8 KB of duplication, and 8 of those copies sit inside present/ skills where they are per-invocation cost. Replace both with calls/pointers. Note that some sites may not be convertible where sourcing common.sh a second time is genuinely awkward; name any residual rather than forcing it.

(5) DEAD AND UNDOCUMENTED MACHINERY. (a) scripts/literature-retrieve.sh (7.9 KB) is deprecated by its own header ("superseded by literature-briefing.sh ... Do not add new usages"), has zero automated callers, yet is still declared in the core manifest's provides.scripts and therefore deploys every time. This repository already runs a rigorous quarantine-never-delete convention -- scripts/deprecated/ holds 11 such scripts, removed from provides so they never deploy -- and this one file simply missed the process. Put it through the same process. (b) /zulip and skill-zulip are live and deployed but have zero mentions in the generated CLAUDE.md: no Command Reference row, no extension section. (c) scripts/check-runtime-file-tracking.sh is legitimately operator-invoked-only, like its five documented siblings, but is missing from CLAUDE.md's Utility Scripts table, so a future dead-code sweep will flag it as an orphan. (d) Six `@.claude/docs/...` references remain in meta-builder-agent.md, context/architecture/system-overview.md, context/architecture/component-checklist.md and context/patterns/thin-wrapper-skill.md; they carry no runtime cost, but they model the exact syntax the context-loading audit spent a phase normalizing away.

(6) TAXONOMY AND ROADMAP DRIFT. specs/state.json's active_topics omits `context-loading` and `email`, both live topics on existing tasks, so generate-task-order.sh renders them through its append-extras path with a stderr warning instead of in curated order; meanwhile seven declared topics now have zero tasks. Separately, specs/ROADMAP.md no longer describes the work in flight -- its Phase 1 is documentation-infrastructure items that appear nowhere in the active task set, and its Success Metrics cite a task number and an extension count from a previous era. Because /review's roadmap-integration step annotates against this file, a stale roadmap makes that step a guaranteed no-op. Reconcile the topics and rewrite the roadmap to describe the actual workstreams.

NEGATIVE FINDINGS -- DO NOT RE-INVESTIGATE THESE. A caller analysis across all 138 scripts and hooks found only literature-retrieve.sh dead; the rest have live callers, including ones reachable only through skill-base.sh's dynamic hooks[$hook_name] manifest lookup and run-all.sh's glob discovery. All 193 files under context/ have live references and are enrolled in context/index.json, a real dynamic-discovery layer -- there are no orphans there and no bytes to recover. docs/ (455 KB) costs zero runtime tokens: CLAUDE.md references it only by backticked path, never @-import. Recording these so they are not re-derived.

THIS TASK IS A BUNDLE AND IS A REASONABLE CANDIDATE FOR EXPANSION -- items 1-3 are verification trustworthiness, items 4-6 are hygiene. If driven as one unit, commit them as separate phases.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 48. Propagate scoped commit to all call sites
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 16, Task 17, Task 18, Task 22, Task 28, Task 31, Task 34, Task 39, Task 41, Task 42, Task 43, Task 44, Task 47, Task 59, Task 60, Task 61, Task 63, Task 64

**Description**: Propagate the scoped-commit fix to the 65 call sites it never reached. This is a correctness/safety task, not a cleanup task.

THE MECHANISM ALREADY EXISTS AND IS CORRECT. scripts/git-commit-scoped.sh describes itself as "the single sanctioned implementation of the scoped-commit contract". It was built to close a documented concurrency defect: a bare `git commit` sweeping in a file that another concurrently-running agent had staged but not yet committed. The fix is sound. Adoption simply stopped.

MEASURED STATE: 85 occurrences of raw `git commit -m` across 70 command/skill files in the source store. Only 5 files call git-commit-scoped.sh -- skill-implementer, skill-planner, skill-team-implement, skill-orchestrate, and commands/orchestrate.md. The remaining 65 files still hand-roll the vulnerable raw form, including the highest-traffic core commands: research.md, plan.md, implement.md, todo.md, task.md, errors.md, review.md.

WHY THIS IS NOT THEORETICAL: the review that produced this task ran with eight concurrent Claude sessions active on the same machine, several in this same repository. Under that load every /research, /plan, /task, /todo, /errors and /review commit is currently capable of capturing another session's staged work. Concurrent multi-session operation is the normal working mode here, not an edge case.

THIS IS ALSO THE SHARPEST LIVE INSTANCE of the "duplicated mechanism instead of shared mechanism" root cause named in the opening refactor review. Unlike most instances of that pattern, the shared mechanism here is already written, already tested, and already proven at 5 sites -- so the work is propagation and verification, not design.

WORK: migrate call sites to git-commit-scoped.sh, highest-traffic first. Suggested ordering: (a) core commands research.md, plan.md, implement.md, todo.md, task.md, errors.md, review.md; (b) remaining core skills; (c) non-core extension commands and skills (founder, present, filetypes, lean, web, epidemiology, literature, memory, cslib).

DO NOT MECHANICALLY REWRITE ALL 85 SITES. Some call sites may legitimately differ -- a commit whose staging scope is genuinely not task-scoped, or a test fixture that must exercise the raw form. Inspect each; where a site should NOT be migrated, record why in the summary rather than silently skipping it. A migration that converts 85 of 85 without noting a single exception is more likely to be careless than thorough.

ALSO SETTLE: whether the raw form should be blocked mechanically once migration lands (a lint in the verify-deploy gate list, in the same family as lint-state-writer-boundary.sh, which already polices the analogous state.json write boundary). Without such a gate the pattern regrows on the next new command. If a lint is added, it must exempt git-commit-scoped.sh itself and its tests.

ACCEPTANCE: `grep -rl 'git commit -m' agent-system/extensions/` returns only git-commit-scoped.sh and its test files, or returns additional files each of which is named in the summary with a stated reason for exemption. Existing test suites still pass. At least one migrated command is exercised end-to-end (a real commit through the converted path) rather than only inspected statically.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 46. Fix present extension compound skill routing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Fix present extension compound-skill routing so /implement resolves to a real skill. The present manifest's routing.implement declares "present:grant" -> "skill-grant:assemble" and "present:slides" -> "skill-slides:assemble", but the shared routing resolver (scripts/lib/manifest-routing-lib.sh, consumed via command-route-skill.sh) returns those values verbatim with no colon splitting, and no skill directories named skill-grant:assemble or skill-slides:assemble exist -- only skill-grant and skill-slides do. Running /implement on a present:grant or present:slides task therefore resolves SKILL_NAME to a nonexistent skill (verified: resolver returned skill-grant:assemble via noncore-exact). skill-grant/SKILL.md documents "assemble" as a workflow_type value, not part of the skill name, so the manifest is encoding skill + workflow_type in one field that no consumer ever splits. Decide whether the fix belongs in the manifest (drop the :suffix and carry workflow_type another way) or in the resolver (split on the first colon and expose the suffix as a workflow_type/sub-mode variable), implement it, and add a lint check so any routing or routing_hard value naming a nonexistent skill fails verify-deploy -- lint-routing-wiring.sh currently validates declared agent names but not skill names. Scope is exactly 2 occurrences, both in agent-system/extensions/present/manifest.json under routing.implement; present declares no routing_hard, and no other extension uses colon-bearing routing values. Found during a deploy-integrity audit of the Logos/Theory repo.

---

### 45. Global update extension repo registry
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: extensions
- **Dependencies**: None

**Description**: Implement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 17, Task 28, Task 41, Task 49

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None

**Description**: LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

---

### 42. Add verify-deploy gates: broken-@-ref lint and warning-first context-budget gate
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 18, Task 31, Task 41

**Description**: Add two context gates to the deploy verification pipeline. (a) Broken-@-ref lint: every `@path` token appearing in generated CLAUDE.md (and in the merge sources that produce it) must either RESOLVE relative to its containing file's directory or be explicitly marked citation-only; a ref that resolves to a nonexistent path is silently inert today (no error, no load) and must fail the gate loudly. The desired end-state for this repo is zero `@`-refs in merge sources (downward normalization to plain backticked paths is already applied), so the lint primarily guards against regression. (b) Warning-first context-budget gate: compute the predicted eager surface (reuse or invoke the measurement harness if it exists by then) and WARN when it exceeds a configured budget; escalate to a hard failure only after the warning tier has proven stable. Consider a per-extension `merge_targets.claudemd.max_bytes` manifest field — NOTE THE SEQUENCING DEPENDENCY: manifest-schema changes must coordinate with the in-flight manifest-schema work (correct-mcp-ownership / extension-manifest efforts); if that work is unsettled when this task starts, implement the budget with an external config and defer the manifest field. CONSTRAINTS: gates must read the source store and the freshly generated output, never trust the possibly-stale deployed .claude/** tree; volatile files (specs/TODO.md, state.json, errors.json) appearing in the eager set is always a FAILURE, not a warning; all edits target agent-system/extensions/**; no task-number references in deliverables outside specs/**.

---

### 41. Build eager-context measurement harness (measure-eager-context.sh)
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [041_eager_context_measurement_harness/reports/01_eager-context-measurement-harness.md]
- **Plan**: [041_eager_context_measurement_harness/plans/01_eager-context-measurement-harness.md]
- **Summary**: [041_eager_context_measurement_harness/summaries/01_eager-context-measurement-harness-summary.md]

**Description**: Create `measure-eager-context.sh` in the core extension's scripts: a harness that PREDICTS the session-start eager context set from the source store plus a fresh regenerate — never by measuring the live `.claude/` tree (stale-deploy concern; the deployed tree routinely lags the source store). The eager set to model: (1) the parent CLAUDE.md chain (e.g. ~/.config/CLAUDE.md, repo CLAUDE.md, generated .claude/CLAUDE.md); (2) the generated CLAUDE.md content assembled from core + loaded extensions' merge sources; (3) any RESOLVING `@`-imports found in that chain (directory-relative resolution — see context/architecture/context-layers.md 'Eager vs. Lazy Loading Channels'); (4) rules lacking `paths:` frontmatter or carrying `paths: "**/*"`. Emit bytes and estimated tokens (bytes/4) per contributing source plus a total, in a stable machine-parseable format. Provide a `--check`/`--write` split following the precedent of `generate-context-line-counts.sh` (`--check` reports, `--write` records a baseline snapshot for later drift comparison). The audit baseline to compare against: ~69.9 KB / ~17.5k tokens before downward normalization; predicted ~9.5k tokens after. CONSTRAINTS: no volatile files (specs/TODO.md, state.json, errors.json) may ever be counted as legitimately eager — flag any found; all edits target agent-system/extensions/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**.

---

### 39. Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 38
- **Research**: [039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md]
- **Plan**: [039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md]

**Description**: Upgrade the literature extension's Zotero integration beyond bare write-path activation: add a real metadata-resolution step for web-discovered sources, decide the MCP question, gate auto-attach on storage quota, and record the Zotero 10 backend-swap plan. Grounded in verified Aug-2026 tooling research — see the seed report before re-deriving any landscape claim.

=== WORK ITEMS ===

1. TRANSLATION-SERVER INTEGRATION (the pipeline's thinnest point today). The online ingest bridge currently relies on `zot add --pdf`'s DOI-from-PDF extraction for metadata, which fails on books, preprints without embedded DOIs, and scans. Integrate the official `zotero/translation-server` (HTTP, port 1969; service provisioning is the ~/.dotfiles repo's job — its task 129): call `POST /search` (DOI/ISBN/arXiv ID, preferred when Tier-3 discovery already has an identifier) or `POST /web` (URL fallback) to resolve full Zotero JSON BEFORE item creation, and pass that metadata through the create path. Degrade gracefully (current behavior) when the service is down, and surface which resolution path produced the record.

2. ZOTERO-MCP ADOPTION DECISION. Evaluate adding 54yyyu/zotero-mcp (de-facto standard, ~4.6k stars, hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN, OA-PDF cascade) as an INTERACTIVE complement for `/research --lit` sessions. The deterministic scripts remain the pipeline of record — community practice in 2026 is exactly this split. Deliverable is a recorded decision (adopt/defer with reasons); if adopted, registration scope and permission grants follow the grant-at-registration-scope principle already established for MCP servers in the ~/.dotfiles Claude configuration, and the registration itself lands there, not here.

3. STORAGE-QUOTA GATE. Stored-file uploads via the Web API count against the zotero.org 300 MB free tier (948 attachments already exist locally; the account's plan/usage is unverified). Verify quota state and encode an explicit auto-attach policy in the ingest bridge rather than discovering the ceiling by failure. Note the upload flow's `{"exists": 1}` content-hash dedup for PDF bytes.

4. ZOTERO 10 BACKEND-SWAP PLAN (plan, do NOT implement while 10 is beta). Zotero 10 ships native local writes (items + file upload) at `localhost:23119/api/` with consent-based local API keys via `POST /api/local/authorize` — eliminating cloud round-trips and the storage quota for attached files. Record the swap plan against the single write choke-point (`zotero-write.sh`) so callers never change; explicitly reject `/connector/saveItems` as a write contract (undocumented internal protocol).

=== ACCEPTANCE CRITERIA ===

1. Web-discovered sources get translation-server-resolved metadata when an identifier or URL is available, with honest surfacing of which resolution path was used and graceful degradation when the service is unreachable.
2. The MCP decision is recorded with reasons; no MCP registration or grants are hand-edited in this repo either way.
3. Auto-attach policy is explicit and quota-aware; no silent quota-exhaustion failure mode remains.
4. The Zotero 10 swap plan exists in the extension's context docs, names the choke-point, and states what stays constant for callers.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 34. Anchor guard-destructive-git.sh destructive-pattern matching to argv, not commit-message prose
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [034_anchor_git_guard_matching_to_argv/reports/01_anchor-guard-matching.md]
- **Plan**: [034_anchor_git_guard_matching_to_argv/plans/01_anchor-guard-matching.md]
- **Summary**: [034_anchor_git_guard_matching_to_argv/summaries/01_anchor-guard-matching-summary.md]

**Description**: Fix a false-positive class in the destructive-git PreToolUse guard, observed live during a real `/orchestrate --hard` run: a legitimate, entirely non-destructive `git commit` was BLOCKED purely because its message text contained wording resembling a destructive pattern. It succeeded only after the message was reworded. A guard that can be tripped by prose is both a false-positive source and, more importantly, evidence that the matching is not anchored where it should be.

FILE: agent-system/extensions/core/hooks/guard-destructive-git.sh (222 lines). Registered as a PreToolUse Bash hook at agent-system/extensions/core/root-files/settings.json line 51.

=== THE CLAIM IS PARTIALLY ACCURATE -- SCOPE IT CORRECTLY ===

The guard reads the raw top-level Bash command string at line 54 (`COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')`) and every detector then greps that string, or `[^;&|]`-delimited segments of it. But the detectors are NOT uniform, and the fix must only touch the broken half:

ALREADY SAFE (do not regress these): the `git add` over-staging detector (lines 76-89) and the `git commit` over-staging detector (lines 95-104) ALREADY strip quoted spans before flag-scanning, building `seg_scan=$(echo "$seg" | sed -e 's/\"[^\"]*\"/\"\"/g' -e "s/'[^']*'/''/g")`. Their rationale is stated at lines 70-72: "Quoted spans are stripped before flag-scanning so free-text commit messages (e.g. -m \"fix -a bug\") never false-positive." This is the correct pattern and the fix should extend it, not reinvent it.

VULNERABLE (the actual defect): the entire destructive-command MATCHED chain at lines 116-184 greps the raw string/segments with NO seg_scan quote-stripping:
  - line 120, `git reset --hard`: regex '(^|[;&|][[:space:]]*)git[[:space:]]+reset[^;&|]*--hard\b'
  - line 126, `git checkout -- <path>`: matches a bare ` -- ` anywhere after `git checkout` in the segment
  - lines 133-142, `git restore`: matches any `git restore ...` segment lacking the literal `--staged`; conversely a message containing `--staged` would FALSELY EXEMPT the command
  - lines 148-162, `git clean`: HAS_F / HAS_D scan the RAW segment, so a message such as `git clean -n -m "remove -d dirs and -f files"` sets both flags
  - lines 173-183, forced checkout/switch: '(^|[^-])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|--force' on raw segment text, so `git switch -c foo -m "hotfix -f rollout"` trips it

HIGHEST-RISK PRACTICAL CASE (matches the live observation): a single git command whose own -m / -c message argument contains flag-like or command-like prose. Example: `git commit -m "revert the git clean -fd fallout"` contains the literal substring `git clean` and `-fd`, so the line-148 detector matches on the raw command and blocks an ordinary commit.

SECONDARY DEFECT FOUND WHILE INVESTIGATING: the `git commit` segment regex at line 95 uses `[^;&|]*`, so a commit message containing a literal `|`, `;`, or `&` truncates the segment mid-message and can leak the message tail into the next scan. Segment splitting on shell metacharacters is not quote-aware anywhere in the file. Decide whether to fix this as part of the same change or record it explicitly as out of scope.

=== NO TEST COVERAGE EXISTS ===

Verified: `grep -rn guard-destructive` across the extension returns only root-files/settings.json line 51, the script's own header, and two "modeled on / mirrors" references in hooks/validate-no-task-references.sh (lines 8 and 50). scripts/tests/ contains 30 suites and none covers this hook; there is no hooks test directory at all. This task must CREATE the first test suite for it, following the house conventions used by the sibling suites in scripts/tests/ and wiring it into run-all.sh.

=== ACCEPTANCE CRITERIA ===

1. Destructive-pattern matching is anchored to argv flags and subcommands, not to free-text message content. A commit whose message merely mentions destructive wording is never blocked.
2. Genuine destructive commands are STILL blocked. Every currently-detected destructive form must remain detected -- this fix must not open a bypass in which an attacker or an agent hides a real `git clean -fd` behind quoting. Explicitly test both directions.
3. The false-exemption inverse is also closed: a quoted `--staged` in a message must not exempt a real `git restore` (lines 133-142).
4. A new regression suite at scripts/tests/test-guard-destructive-git.sh covers, at minimum: the observed false positive; each of the five vulnerable detectors at lines 116-184; a true-positive case per detector; and the already-safe `git add` / `git commit` over-staging detectors to prevent regression.
5. The new suite is wired into scripts/tests/run-all.sh and passes in both source-store and deployed modes.
6. The header comment at lines 41-47, which currently frames "the whole tool_input.command string" as the sole observation boundary, is updated to describe the actual post-fix matching contract.

NOTE ON INDEPENDENCE: this task shares no files with the orchestrator run-state work and can proceed in parallel with it.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.=== ADDENDUM: LIVE REPRODUCTION (appended by the orchestrator; the meta agent hit this itself and was terminated by an API usage limit before it could record the trigger) ===

While committing the very tasks that describe this defect, the meta agent's own `git commit` was BLOCKED by `guard-destructive-git.sh` — on a command line containing no `-a`, no `-am`, and no `--all`. Its last words before termination: "The guard just blocked a commit that contains no `-a`, `-am`, or `--all` — a live reproduction of Defect 4. Let me identify the exact trigger to record as evidence." It did not get to identify the trigger.

This is a second, independent live firing (the first was during a `/orchestrate 414 --hard` run in the BimodalLogic repository, where a legitimate commit was blocked until its message was reworded). Both firings share a shape: the blocked command was non-destructive, and the only plausible trigger was TEXT — a commit message describing destructive git operations, in a task about destructive git operations.

Note the self-referential hazard this creates and treat it as an acceptance criterion: any commit message, task description, plan, or test fixture that DISCUSSES destructive git commands can trip a prose-matching guard. Work on this very task is therefore likely to trip it repeatedly. The fix must make it safe to write about `git reset --hard` without being unable to commit that writing.

Reproduction hint for the implementer: the commit that eventually succeeded was `f2679860a` ("meta: create 3 tasks for hard-mode orchestrator defect remediation"). Compare against whatever earlier message was rejected — the delta identifies the trigger substring. Per the task body above, the `git add`/`git commit` over-staging detectors already quote-strip via `seg_scan`; it is the destructive chain (lines 116-184) that greps raw, and that is where both firings originate.=== ADDENDUM: THIRD LIVE FIRING, WITH THE TRIGGER ISOLATED (recorded during batch scoping) ===

The trigger the two earlier firings could not identify has now been isolated by bisection against
the deployed hook. Both root causes are in the git commit over-staging detector (the one the task
body above lists as ALREADY SAFE -- that assessment is WRONG for multi-line messages and must be
corrected).

CAUSE 1 -- THE QUOTE-STRIP IS LINE-BASED AND FAILS ON MULTI-LINE MESSAGES. The detector builds
seg_scan via `echo "$seg" | sed -e 's/"[^"]*"/""/g'`. sed processes input line by line. A -m
message spanning multiple lines leaves the opening quote unclosed on its own line, so no complete
quoted span exists on any single line and NOTHING is stripped. Every line of the message is then
flag-scanned as if it were argv. The identical command with a single-line message passes, because
there the quoted span closes and is stripped correctly. Demonstrated: same header text, PASS as
one line, BLOCK as the first line of a multi-line message.

CAUSE 2 -- THE FLAG REGEX MATCHES ORDINARY HYPHENATED PROSE. The pattern is
    (^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)
which matches ANY hyphenated word whose post-hyphen part contains an 'a' and is followed by
whitespace. The concrete blocked token was the batch topic name itself: in `essential-refactor `,
the `l` satisfies [^-], `-refactor` satisfies -[a-zA-Z]*a[a-zA-Z]*, and the trailing space closes
the match. Neutral words like `un-edged` and `repo-wide` do NOT match (no 'a' after the hyphen),
which is why the failure looked nondeterministic across earlier attempts.

WHY BOTH MATTER. Cause 2 alone is harmless while the strip works; cause 1 alone is harmless while
no line contains a matching token. The false positive requires both, which is why it presented as
intermittent and message-dependent. A fix addressing only one leaves the other live.

CORRECTION TO THE TASK BODY: the claim that the `git add` and `git commit` over-staging detectors
"ALREADY strip quoted spans before flag-scanning" and are the correct pattern to extend is only
true for single-line commands. Extending that pattern to the destructive chain without first
making the strip multi-line-aware would propagate this defect rather than contain it. Fix the
strip first, then extend.

ADDITIONAL ACCEPTANCE CRITERIA:
  - A multi-line -m message is quote-stripped as a single logical span, not per line.
  - A commit whose message contains an ordinary hyphenated word with an 'a' after the hyphen
    (essential-refactor, auto-repair, multi-task) is never blocked, single- or multi-line.
  - A genuine `git commit -am "msg"` and a genuine `git commit -a` are still blocked, including
    when the message spans multiple lines.
  - The regression suite required by this task covers the multi-line case explicitly; a
    single-line-only suite would have passed against this defect.

---

### 32. Redeploy and remediate install once settings
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 28, Task 29, Task 30, Task 31

**Description**: Deploy the accumulated source-store changes and remediate the stale grant that the install-once mechanism structurally cannot fix.

WHY THIS IS LAST: a substantial body of MCP work now exists in the source store and has NEVER been deployed -- context/patterns/mcp-server-ownership.md does not exist in the deployed tree at all, and every correction from the preceding tasks is likewise source-only. Deploying once at the end, after the source store is settled, avoids redeploying a document that is about to be rewritten.

THE INSTALL-ONCE TRAP -- THE WHOLE POINT OF THIS TASK: the deployed .claude/settings.json still contains a mcp__lean-lsp__* wildcard that was already removed from core/root-files/settings.json in the source store. A redeploy WILL NOT fix this. That file deploys under install-once semantics (loader.lua's copy_category('root_files') gated by CATEGORY_DESCRIPTORS.root_files.install_once, with manager.unload excluding it via INSTALL_ONCE_ROOT_FILES), so once a project has its own copy it is never overwritten. The stale wildcard is ALSO a leftover from a deploy cycle when the lean extension was loaded, and an additive deep-merge never retracts. It must be removed by hand from the deployed file. Anyone who runs a deploy and assumes the grant is gone will be wrong.

EXPECTED HOOK WARNING: hand-editing .claude/settings.json will trip the source-store-boundary advisory hook. That warning is expected and correct in general but does not apply here: an install-once file is effectively user state, not a regenerable deploy artifact. Record that reasoning rather than silently ignoring the warning, and do not 'fix' it by editing the source copy instead -- the source copy is already correct.

WORK: run `bash .claude/scripts/deploy-headless.sh`; then remove the stale mcp__lean-lsp__* entry from the deployed .claude/settings.json; then run `bash .claude/scripts/verify-deploy.sh` and compare its findings against a baseline captured BEFORE the deploy, so pre-existing failures are not misread as newly introduced ones.

ALSO SETTLE, OR EXPLICITLY DEFER WITH A REASON: (a) lean-lsp is registered at user scope pointing at a DIFFERENT repository (/home/benjamin/Projects/BimodalLogic), because user-scope registration is global while that server needs a per-project path -- moving it to the new project-scoped mechanism would fix this class of bug; (b) the nine playwright grants duplicated in the web and present settings fragments become redundant once those tools are granted at machine scope in the NixOS configuration, under the grant-at-registration-scope rule. Item (b) is harmless duplication, not a fault -- treat it as cleanup and do not break working grants chasing tidiness.

VERIFICATION: mcp-server-ownership.md exists in the deployed tree; the deployed .claude/settings.json contains no mcp__lean-lsp__* entry; verify-deploy.sh reports no findings that were absent from the pre-deploy baseline; a FRESH Claude Code session (not the current one, which cannot observe registration changes) shows the expected servers. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 31. Opencode extensions sync mechanism
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 19

**Description**: Give the .opencode/extensions/ mirror a real generation path from the source store, so it stops silently drifting, and fix the live defect that drift has already produced.

SCALE -- MEASURE BEFORE PLANNING: .opencode/extensions/ is 804 git-tracked files mirroring 17 extensions (core, epidemiology, filetypes, formal, founder, latex, lean, memory, nix, nvim, present, python, slidev, typst, web, z3). An earlier estimate of '34 files' was wrong by more than an order of magnitude, so size the work against a fresh count, not against that figure. There is currently NO deploy or sync mechanism for this tree at all -- it is maintained by periodic manual 'mirror' commits, which is why the drift is structural rather than incidental.

THE LIVE DEFECT: .opencode/extensions/web/agents/web-implementation-agent.md (around line 57) still teaches `browser_verify_text_visible` as a real Playwright MCP tool. That tool does not exist. The source store at the corresponding path already retracts it explicitly. Any agent reading the .opencode copy is being taught to call a nonexistent tool. Note carefully: the source store deliberately RETAINS two mentions of that string as corrections that teach the name is fake -- a sync mechanism or cleanup pass must not mistake those for defects and 'fix' them into nonsense.

WORK: decide and implement how this tree is generated or verified. At minimum produce a drift-detection check that fails loudly when .opencode/extensions/ diverges from agent-system/extensions/**; a full generator is preferable if the two trees are genuinely meant to be identical. FIRST establish whether they ARE meant to be identical -- the trees use a different @-reference convention, so a naive byte-for-byte generator may be wrong. If a full sync is not appropriate, a drift-detection gate plus documented divergence rules is an acceptable and honest outcome; say which was chosen and why.

SCOPE BOUNDARY: another task already owns .opencode/scripts/* (dead command-router removal). Stay out of that subtree to avoid a conflicting edit.

VERIFICATION: the fake tool name no longer appears as usable guidance anywhere in .opencode/extensions/; the drift check runs clean, or reports exactly the divergences the chosen policy permits; the check is wired somewhere it will actually run rather than existing as an uninvoked script. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 30. Register obsidian memory mcp server
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 29

**Description**: Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 29. Generate mcp json from extension manifests
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 19, Task 22, Task 44

**Description**: Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 28. Correct mcp ownership model and purge dead declarations
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [028_correct_mcp_ownership_model_and_purge_dead_declarations/reports/01_mcp-ownership-rewrite-and-purge-spec.md]
- **Plan**: [028_correct_mcp_ownership_model_and_purge_dead_declarations/plans/01_mcp-ownership-hybrid-rewrite.md]

**Description**: Rewrite the canonical MCP ownership document, whose central premise has been empirically DISPROVEN, and purge the dead server declarations it catalogues.

ITEM 1 -- THE REFUTED PREMISE. context/patterns/mcp-server-ownership.md states that MCP server REGISTRATION belongs exclusively to user scope (~/.claude.json) BECAUSE custom subagents cannot access project-scoped .mcp.json servers. That justification is false. Direct experiment: a .mcp.json-registered stdio server exposing a sentinel tool WAS reached by a filesystem-based subagent, confirmed twice, including via the general-research-agent class this system actually dispatches, with the permission pre-granted so permission was not a confound. The original belief came from a confounded observation -- an ALREADY-RUNNING session cannot see a server added to .mcp.json after that session started, and this affects the MAIN session identically. It is a session-start tool-registry snapshot effect, unrelated to subagents or to scope. Anyone re-testing this MUST start a fresh session (or use `claude -p`) or they will reproduce the same false negative.

ITEM 2 -- THE REPLACEMENT MODEL (decided, not open for redesign). Adopt a HYBRID surface. Registration: project-scoped .mcp.json for extension-owned, repo-local servers; user scope (~/.claude.json, via home-manager or a setup script) reserved for servers that are genuine machine capabilities or need per-project computed arguments -- playwright (Nix-built wrapper binary plus a machine-level browser cache) and lean-lsp (needs a computed per-project path) are the two current user-scope cases. Add this governing rule, which the current doc lacks entirely and which is the actionable core of the whole model: GRANT PERMISSIONS AT THE SAME SCOPE WHERE THE SERVER IS REGISTERED. User-scope registration implies user-scope grants; project-scope registration implies extension settings-fragment grants. The live playwright defect is exactly this asymmetry -- registered machine-wide but granted only inside two extension fragments, so every call prompts, and DENIES outright in headless runs.

ITEM 3 -- FIX A FACTUAL ERROR IN THE DOC. Its Known-gaps table attributes 'sec-edgar, rmcp' to the epidemiology extension. Verified false: epidemiology declares only rmcp; sec-edgar is in founder alongside firecrawl. The count of five affected extensions is right; that row's attribution is wrong.

ITEM 4 -- PURGE DEAD DECLARATIONS. `mcpServers` keys inside a settings-fragment.json have never been a registration surface and register nothing. Delete these dead blocks entirely: epidemiology (rmcp), filetypes (openpyxl, superdoc), founder (firecrawl, sec-edgar). Also delete founder's five orphaned mcp__firecrawl__* / mcp__sec-edgar__* permission grants, which point at servers that do not exist. These five servers belong to extensions not loaded in this repository and are being retired rather than wired up -- that is a deliberate decision, so record it in the doc's Known-gaps section rather than silently dropping them.

ITEM 5 -- NIX IS THE EXCEPTION, HANDLE IT PRECISELY. Delete nix/settings-fragment.json's dead mcpServers block too, BUT KEEP its two permission grants (mcp__nixos__nix and mcp__nixos__nix_versions) exactly as they are. Registration for that server is moving to home-manager in the NixOS configuration repository, under the server name 'nixos' -- which is precisely what makes the existing mcp__nixos__* grants correct. VERIFIED by running the server and requesting tools/list: it exposes exactly two tools, `nix` and `nix_versions`, matching those grants and matching context/project/nix/tools/mcp-nixos-integration.md. Note the naming trap that caused this: the dead block declared the server as 'mcp-nixos', which would have produced mcp__mcp-nixos__* and broken every existing grant and doc reference.

SCOPE NOTE: file_scope names mcp-server-ownership.md as an exact FILE, deliberately not the enclosing context/patterns/ directory, because a directory-prefix declaration there overlaps an orchestrator-critical path and trips the self-modification admission gate as a false positive.

VERIFICATION: `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh` passes for every touched extension; `jq empty` on each edited fragment; grep confirms zero surviving mcpServers keys in any settings-fragment.json; grep confirms founder's orphaned grants are gone and nix's two grants remain; the doc contains no surviving claim that subagents cannot reach project scope. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 27. Remove the dead .opencode command router and its self-referential test scripts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: .opencode/scripts/execute-command.sh is a command router that cannot execute anything and is called by nothing but its own tests. Delete it and the three test scripts that exist only to exercise it.

SCOPE NOTE -- THIS IS NOT THE SYNTAX-ERROR TASK. A duplicated case pattern in this file was already fixed in this repo; the file parses cleanly under `bash -n` today, and separately-tracked metrics-sync work already records that fix as done. Do not re-open it. The work here is deletion of a file that is dead for reasons unrelated to that syntax defect. If someone arrives expecting a one-line syntax repair, that repair has already landed.

MEASURED EVIDENCE (live, this repo, do not re-derive):

(1) Its runtime dependency has never existed. Both live branches of its case statement emit a heredoc that runs
        source "$OPENCODE_ROOT/context/core/patterns/command-integration.sh"
        execute_lean_command "$command_name" "$arguments"
    .opencode/context/core/patterns/command-integration.sh is absent. A repo-wide grep for `execute_lean_command` across all *.sh returns matches ONLY inside execute-command.sh's own two echo strings -- the function is defined nowhere. So every successful dispatch path terminates in a missing source file followed by an undefined function. The router has no working branch; the only reachable non-error outcome is the `*)` unknown-command arm that exits 1.

(2) Nothing invokes it. Files referencing execute-command.sh outside specs/**:
        .opencode/scripts/execute-command.sh    (itself: shebang comment + usage string)
        .opencode/scripts/test-execution-system.sh   (3 references)
        .opencode/scripts/test-execution.sh          (1 reference)
        .opencode/scripts/test-command.sh            (1 reference)
        .opencode/scripts/test-results.md            (prose describing those tests)
    opencode.json contains no reference to it. No file under lua/ references it or .opencode/scripts at all. There is no other live execution path wired to this router -- it is not the mechanism by which .opencode commands actually run.

(3) The three test scripts test nothing else. They are 49, 16, and 10 lines; every reference each one makes is to execute-command.sh. Deleting the router without them would leave three scripts whose entire purpose is invoking a file that no longer exists.

(4) It is stale. Last commit touching .opencode/scripts predates this task by roughly five months.

WORK:
  1. Delete .opencode/scripts/execute-command.sh.
  2. Delete .opencode/scripts/test-execution-system.sh, test-execution.sh, and test-command.sh.
  3. Resolve .opencode/scripts/test-results.md -- it documents results for the deleted tests. Decide explicitly between deleting it and reducing it to a note recording that the router was removed; do not leave it describing tests that no longer exist.
  4. Confirm .opencode/scripts/README.md needs no edit. A grep for execute-command / test-execution / test-command / test-results against it currently returns nothing, so the expected outcome is no change -- but state that you re-checked rather than assuming, since the README is the natural place for a stale pointer to survive.

EDIT TARGET (binding): edit .opencode/** directly. A find across agent-system/ for execute-command.sh and test-execution*.sh returns nothing -- .opencode/ has no source-store counterpart in this repo and is separately git-tracked, so the source-store/deploy-boundary rule that governs .claude/** does not apply here. Do NOT attempt to locate or edit an agent-system source for these files; there is none.

DOWNSTREAM PROPAGATION (in scope to decide, not necessarily to perform): four other repos carry copies of this same router -- Logos/Theory, protocol, ModelChecker, and OpenCode. All four still contain the duplicated case pattern and therefore FAIL `bash -n`, and all four are likewise missing command-integration.sh. This repo is the reload source, so the intended mechanism is that deleting here propagates on the next reload. Verify whether reload actually removes downstream files or only adds and overwrites them -- a reload that never deletes would leave four broken copies in place indefinitely, which is a materially different outcome. Record the finding either way; if propagation does not delete, say so plainly and note what a follow-up would need to cover rather than silently assuming the copies are handled.

ACCEPTANCE: after the change, a repo-wide grep for `execute-command.sh` outside specs/** returns zero hits (or only hits inside a deliberately-retained note from item 3, accounted for individually). `bash -n` passes across every remaining .opencode/scripts/*.sh -- it already does for all thirteen non-router scripts, so this must not regress. assess-repo-health.sh reports build_errors unchanged or lower, and specifically not higher, than its pre-change value; report both numbers rather than asserting improvement.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Silence opencode fragment validation spam
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 19

**Description**: Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 20. Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 34, Task 63

**Description**: /todo's repository-metrics sync runs before its git commit, so the health probe measures a tree whose git index still points at pre-move paths. Every archived-away file is counted as a structural failure, inflating build_errors and flipping status to "critical" on a healthy tree.

MEASURED EVIDENCE (live /todo run archiving 20 tasks, this is not inherited): Step 5.6 reported
    {"todo_count":44,"fixme_count":2,"build_errors":89,"status":"critical"}
Re-running the identical probe after the commit reported build_errors: 1. Of the 89, 88 were phantom and exactly 1 was real (a duplicated case pattern in .opencode/scripts/execute-command.sh, fixed separately; the probe then reported build_errors: 0, status "healthy"). So the reported figure was wrong by 88 and the derived status was wrong outright.

CONFIRMED ROOT CAUSE (two independent contributing defects, both must be addressed):

(1) The probe counts paths that no longer exist. assess-repo-health.sh's enumerate_by_glob builds candidates from `git ls-files -z -- "$glob"` and emits "$ROOT/$rel" with no existence check. Both structural loops then guard only emptiness, not existence:
        for f in "${SH_FILES[@]}"; do
          [ -n "$f" ] || continue
          if ! bash -n "$f" >/dev/null 2>&1; then errors=$((errors + 1)); fi
A path present in the index but absent on disk fails `bash -n` / `jq empty` for the trivial reason that there is no file to parse, and is scored as a structural error. This is caller-independent: any uncommitted rename, delete, or move produces the same inflation, so the probe is wrong on its own terms and not merely mis-sequenced. total_candidates is also inflated by the same phantom paths, which perturbs the degenerate zero-candidate branch that emits build_errors: null.

(2) /todo sequences the probe against exactly the tree state that triggers (1). commands/todo.md places Step 5.6 (Sync Repository Metrics, calling assess-repo-health.sh at the documented line) after Step 5D's directory moves and Step 5.7's vault operation, but before Step 6's `git add specs/` + commit. The one caller most likely to have just moved hundreds of files measures before recording them.

WORK:
  1. Make the probe existence-safe: skip candidates that are not present on disk, and exclude them from total_candidates so the null/"unknown" branch stays meaningful. Decide explicitly whether a phantom path should be silently skipped or surfaced as a separate diagnostic field (an index/worktree divergence is itself a signal worth reporting); state the decision and its reasoning.
  2. Re-sequence /todo so the metrics sync reflects the tree it actually commits. Either move Step 5.6 after Step 6, or have Step 6 re-sync afterward. Do not rely on fix 1 alone to paper over the ordering: fix 1 stops the false inflation, but a pre-commit measurement still describes a tree that is about to change.
  3. Check for other callers of assess-repo-health.sh with the same pre-commit exposure and note whether each is affected.

ACCEPTANCE: a /todo run that archives at least one task with a directory reports the same build_errors and status as an identical probe run immediately after its commit, and both match the true count for the tree. Demonstrate both directions -- a genuinely broken file must still be counted (a probe that can only ever report zero is not a fix), and a large batch of moved-but-uncommitted files must contribute zero. Report the measured before/after counts explicitly; never an unqualified green.

REGRESSION LOCK: add a test that stages nothing, moves a tracked *.sh or *.json to a new path, runs the probe, and asserts the moved file contributes no error. Without this the defect silently returns on the next refactor of enumerate_by_glob.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
=== ADDENDUM: SECOND LIVE REPRODUCTION, STRONGER THAN THE ORIGINAL (recorded during a real /todo run) ===

A /todo run archiving 25 tasks and moving 25 directories reproduced the defect with a cleaner
signal than the original measurement. Step 5.6, run at its documented position (after the
directory moves, before the Step 6 commit), reported:
    {"todo_count":44,"fixme_count":2,"build_errors":184,"status":"critical"}
The identical probe re-run immediately after the commit reported:
    {"todo_count":44,"fixme_count":2,"build_errors":0,"status":"healthy"}

ALL 184 WERE PHANTOM. The original measurement had 88 phantom of 89, leaving 1 real error that
slightly muddied the signal. This run has a true count of exactly 0, so the inflation is total
and the derived status is wrong in both fields with no residue to explain away. Use this as the
regression fixture: it is a cleaner before/after pair than the original.

The run also confirms the ordering half of the root cause independently of the existence-check
half. Nothing about the tree changed between the two probes except `git add specs/` plus a
commit, which converted 298 rename entries from index-vs-worktree divergence into recorded
state. No file content was edited between the two measurements.

WORKAROUND APPLIED DURING THAT RUN (not a fix, and it must not be mistaken for one): the operator
inverted Steps 5.6 and 6 by hand, committing first and then probing, so state.json recorded the
true value rather than the phantom one. That inversion is item 2 of this task's WORK list. It was
applied ad hoc to avoid persisting a known-false "critical" into repository_health; the durable
fix, including the existence-safety of item 1 and the regression lock, is still outstanding.

=== SECOND, INDEPENDENT DEFECT IN THE SAME FILE -- STEP 5A EXCEEDS MAX_ARG_STRLEN AT SCALE ===

Found in the same run, and in scope here because it is the same file and the same command. Step
5A ("Update archive/state.json") passes the ENTIRE archivable task set as one shell argument:
    --argjson tasks "$archivable_tasks_json"
Linux caps a SINGLE argument at MAX_ARG_STRLEN (128 KB, 32 pages), independent of the much larger
total ARG_MAX. Archiving 25 tasks produced a 175 KB value and the call died with:
    bash: /run/current-system/sw/bin/bash: Argument list too long
This is a hard failure of the archive insert, not a warning. It fired BEFORE any state was
written, so nothing was lost; had it fired between the archive insert and the Step 5B deletion,
the archivable set would have been removed from active_projects without ever landing in the
archive. The blast radius is therefore data loss, not merely an aborted run.

The trigger is total description bytes, not task count: these task descriptions routinely run
5-10 KB each, so the ceiling arrives at roughly 15-25 tasks. Any repository that lets completed
tasks accumulate will hit it, and it gets worse the longer /todo goes unrun -- the command
becomes unrunnable exactly when it is most needed.

state-write.sh offers no file-based input flag; it supports only --arg and --argjson, both
command-line. So the fix belongs in one of:
  (a) batch the Step 5A insert into chunks that stay under the per-argument ceiling (the ad hoc
      workaround used during this run: five batches of five tasks, 28-50 KB each, all succeeded);
  (b) add a file-based input flag to state-write.sh (jq --slurpfile / --rawfile) and have Step 5A
      use it, which fixes the whole class rather than this one call site;
  (c) have the Step 5A filter read the source tasks itself rather than receiving them as an
      argument.
Direction (b) is worth weighing beyond this call site: any other caller passing a large --argjson
payload through state-write.sh has the same latent ceiling.

ACCEPTANCE FOR THIS SECOND DEFECT: a /todo run archiving at least 30 tasks with realistic
multi-kilobyte descriptions completes its archive insert without an argument-length failure, and
the archive insert and the active_projects deletion cannot end up on opposite sides of a partial
failure.

---

### 18. Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Effort**: 5h
- **Status**: [PLANNING]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: None
- **Research**: [018_detect_stale_claude_deploy_trees/reports/01_stale-deploy-detection.md]

**Description**: A repo can carry an arbitrarily stale .claude/ deploy with no signal, so a user hits a bug fixed upstream long ago with no indication that regeneration is the remedy. Discovered when /revise failed at GATE IN in a consuming repo on a task that had never produced an artifact.

WHAT IS NOT THE DEFECT (ruled out, do not re-litigate): resolve_task_dir is not broken in source. agent-system/extensions/core/scripts/task-lock.sh's resolve_task_dir (line 249) takes a create_mode parameter and mkdir -p's when it is "create"; cmd_acquire (line 607) passes "create". The failure exists only in the deployed copy.

MEASURED STALENESS EVIDENCE (live, this investigation): the consuming repo's .claude/scripts/task-lock.sh is 676 lines against a 1660-line source, with a deployed resolve_task_dir at line 98 taking no create_mode. Its .claude/scripts/ holds 94 scripts against core's 72 in source. Neither verify-deploy.sh nor deploy-headless.sh is present in the deployed tree at all. This is despite a large sync commit landing recently.

BOOTSTRAP HYPOTHESIS RULED OUT: deploy-headless.sh's header documents a failure mode where a repo deployed by the retired glob-based engine has no "core" entry in .claude-extensions.json, so manager.resync_all silently deploys nothing. That is NOT this case. The repo's .claude-extensions.json lists core with status "active" and 294 recorded installed_files, including .claude/scripts/task-lock.sh. The loader believes it owns and has installed the very file that is stale. Root cause is unknown and is a genuine investigation, not a known-issue application.

WORK, in order. (1) Determine WHY the deploy is stale despite core being active and the file being listed in installed_files. Hypotheses to test, not assume: the copy step skips existing destination files instead of overwriting; installed_files is treated as authoritative and short-circuits re-copy; resync only re-copies files whose manifest entry changed; or a later partial operation reverted the tree. If the cause is a loader defect, report and fix it as such. (2) Then design and implement staleness DETECTION on a path users actually hit. Note that verify-deploy.sh already performs source-vs-deploy comparison but is not itself deployed and is invoked only from skill-orchestrate's inter-cycle redeploy checkpoint, so no ordinary command surfaces its result. Directions to evaluate, do NOT pre-commit: stamp a source revision or content hash into the deployed tree at load time and have command gate scripts compare against the source store, warning on drift; extend /refresh or a doctor check to diff deployed script versions against source; or have the loader record a per-file hash manifest a preflight can validate cheaply. Whatever is chosen must be cheap enough for a normal command preflight.

INTERACTION WITH SIBLING TASK 9: 9's evidence (4 orphan files present in .claude/ but absent from a clean scratch regenerate) was measured against this same stale deploy tree, so it may be an artifact of the staleness rather than a genuine one-directional-parity gap. 9 is sequenced after this task and must re-measure against a freshly regenerated tree. Both tasks also edit verify-deploy.sh.

ACCEPTANCE: the root cause is identified and stated, with the loader defect fixed if that is the cause; a user running an ordinary command against a stale deploy receives an actionable warning naming regeneration as the remedy; demonstrated in both directions, where a stale tree warns and a fresh tree does not.

SOURCE-STORE RULE (binding): edit agent-system/extensions/** and lua/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 17. Fix .return-meta.json lifecycle ordering that makes the gate-out body unreachable
- **Effort**: 4h
- **Status**: [PLANNING]
- **Task Type**: meta
- **Topic**: essential-refactor
- **Dependencies**: Task 16, Task 35, Task 37
- **Research**: [017_fix_return_meta_lifecycle_ordering/reports/01_return-meta-lifecycle-ordering.md]

**Description**: command-gate-out.sh's entire post-metadata body is structurally unreachable on all five commands that call it, because the skill-internal postflight always deletes the metadata first. The misleading warning is the visible symptom; the dead defensive status correction and the dead artifact validation are the actual damage.

VERIFIED MECHANISM (do not re-derive): skill-base.sh's skill_cleanup (lines 618-625) rm -f's .postflight-pending, .postflight-loop-guard, AND .return-meta.json. It is the single shared implementation invoked from Stage 9 of context/patterns/skill-postflight-flow.md, used by NINE skills: skill-implementer, skill-implementer-hard, skill-planner, skill-planner-hard, skill-reviser, skill-spawn, skill-team-implement, skill-team-plan, skill-team-research. command-gate-out.sh lines 69-73 then read "${task_dir}/.return-meta.json"; on absence it prints "WARNING: .return-meta.json not found ... skill may have failed silently" and exit 0. FIVE commands run it: implement.md, orchestrate.md, plan.md, research.md, revise.md.

BLAST RADIUS IS LARGER THAN THE WARNING (measured, not inherited): the exit 0 at line 73 sits ABOVE everything else in the 134-line script. Code rendered unreachable in practice includes (a) the defensive status correction that repairs state.json when a skill reported completion but state is stale, and (b) the skill_validate_task_artifacts call at line 133, the last line, which is the artifact validation and --fix auto-repair path. One missing file disables both correctness mechanisms on all five commands. A real silent failure and an ordinary success emit the identical warning, so the signal carries no information.

CONSEQUENCE FOR SIBLING TASK 13: 13's acceptance criterion (a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count) cannot be demonstrated until this ordering defect is fixed, because the path it instruments never executes. 13 is sequenced after this task; both also edit the same two files.

WORK: decide ONE direction and implement it. (a) run the command-level gate-out before skill cleanup; (b) have skill_cleanup preserve .return-meta.json and make gate-out delete it after consuming it; (c) have skill_cleanup archive the metadata to a location gate-out knows about; (d) if the skill-internal postflight genuinely subsumes both defensive correction and artifact validation, delete the dead reads and replace the warning with a truthful statement. Required regardless of direction: explicitly decide whether defensive status correction is still needed given skill-internal postflight and record the reasoning; and fix the warning text so a genuine silent failure is distinguishable from ordinary success.

UNIFORMITY REQUIREMENT: whatever is chosen must hold across all nine skills and all five commands. A fix that repairs skill-reviser and /revise alone is not acceptable.

ACCEPTANCE: a normal successful run of each of the five commands emits no false silent-failure warning; a genuinely failed skill run emits a distinguishable warning; and the defensive-correction path is demonstrated to execute, or is documented as deliberately removed with stated reasoning.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 33

**Description**: Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 13. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 17

**Description**: The acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" is unverifiable as written, because no reporting surface exists. Recorded as err_1786350581339_Q4VnFy.

TRACED PATH: command-gate-out.sh (134 lines) has no counter, aggregate, or exit-code surface for auto-repairs; its only related line is a comment. The real repair path is
    command-gate-out.sh -> skill_validate_task_artifacts (skill-base.sh) -> validate-artifact.sh "$f" "$type" --fix 2>/dev/null
validate-artifact.sh DOES emit a terminal line of the form "[FIXED] N field(s) auto-repaired, E error(s), W warning(s) remaining" and exits 2. But skill_validate_task_artifacts discards stderr, collapses every non-zero exit into a single generic non-blocking WARNING carrying no numeric detail, and always returns 0. command-gate-out.sh therefore receives no signal at all.

PRIMARY HAZARD (the reason this is not merely cosmetic): --fix MUTATES THE ARTIFACT IN PLACE. A repair both happens and goes uncounted, so an artifact can be silently rewritten with nothing anywhere recording that it was. The instrumentation gap and the silent-mutation hazard are the same defect seen from two ends.

WORK:
  1. Propagate validate-artifact.sh fix/error/warning counts through skill_validate_task_artifacts instead of discarding them.
  2. Give command-gate-out.sh a reportable surface for those counts.
  3. Decide explicitly whether --fix should remain in-place-mutating on the gate-out path, or whether a repair should be reported and left for a human. State the decision and its reasoning.

ACCEPTANCE: a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count, and a task needing none reports zero. Both directions must be demonstrated - a report that can only ever say zero is not instrumentation.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 9. Resolve deploy orphan file parity
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 18, Task 44

**Description**: Declared-vs-deployed parity for provides.* categories is one-directional by design, and the live .claude/ tree carries 4 orphan files absent from a clean scratch regenerate: context/orchestration/orchestration-validation.md, context/orchestration/subagent-validation.md, docs/architecture/architecture-spec.md, docs/README.md. Two of these (docs/architecture/architecture-spec.md, docs/README.md) were not covered by the pre-existing err_1786349061556_LuKGif (deploy_ghost_index_entries), which only named the other two -- confirmed and extended by err_1786350581273_TAWj0I (deploy_orphan_files_undercounted). This task covers BOTH error ids with one decision; do not split it.

MECHANICAL REASON (already diagnosed, do not re-derive): verify.lua's result shape has no extra/orphan field and only ever iterates the declared side; install-extension.sh's merge_index_entries() is purely additive with no stale-removal step. Parity is therefore verified only in the declared-to-deployed direction, never the reverse.

TARGET: agent-system/extensions/core/scripts/verify-deploy.sh (or the shared verify.lua module it calls), and/or docs/architecture/architecture-spec.md if the decision is to document one-directional parity as intended rather than build detection.

WORK: decide ONE of two directions and implement it -- (a) add a subtractive/orphan-detection pass to verify.lua or verify-deploy.sh that flags live files present in .claude/ but absent from a clean regenerate of every provides.* category, so future orphan drift is caught mechanically; or (b) explicitly document in docs/architecture/architecture-spec.md that provides.* parity is one-directional by design (additive only, no stale-removal), so a future reader does not mistake the current behavior for an oversight. Resolve the 4 currently-orphaned files as part of whichever direction is chosen: either they get removed/reconciled (direction a) or explicitly enumerated as accepted legacy orphans in the documentation (direction b).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

STALENESS CAVEAT (added after the deploy-staleness finding): the orphan-file measurement above (4 files present in .claude/ but absent from a clean scratch regenerate) was taken against a deploy tree since shown to be badly stale -- its task-lock.sh was 676 lines against a 1660-line source. That measurement may therefore be an artifact of the staleness rather than evidence of a one-directional parity gap. Re-take the measurement against a freshly regenerated tree before treating it as evidence, and revise the direction (a)/(b) decision if the orphan set changes. Depends on task 18, which diagnoses the staleness root cause.
