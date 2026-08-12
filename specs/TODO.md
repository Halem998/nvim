---
next_project_number: 53
---

# TODO

## Task Order

*Updated 2026-08-12. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 14,18,20,22,27,28,31,34,37,39,41,43,45,46,48,51,52 | -- | agent-system, commit-scoping-concurrency, extensions, ... |
| 2 | 9,17,29,42,49,50 | 18,22,37,41,48 | agent-system, context-loading |
| 3 | 13,30,44 | 17,29,49 | agent-system, context-loading |
| 4 | 32 | 28,30,31 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

14 [NOT STARTED] — Two dispatches in a single batch fanned out to phase sub-agents a
18 [NOT STARTED] — A repo can carry an arbitrarily stale .claude/ deploy with no sig
  └─ 9 [NOT STARTED] — Declared-vs-deployed parity for provides.* categories is one-dire
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th
27 [NOT STARTED] — .opencode/scripts/execute-command.sh is a command router that can
28 [IMPLEMENTING] — Rewrite the canonical MCP ownership document, whose central premi
  └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta
31 [RESEARCHING] — Give the .opencode/extensions/ mirror a real generation path from
  └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta (see above)
34 [NOT STARTED] — Fix a false-positive class in the destructive-git PreToolUse guar
41 [NOT STARTED] — Create `measure-eager-context.sh` in the core extension's scripts
51 [NOT STARTED] — Move per-session state files cluttering the specs/ root (.orchest
13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
17 [NOT STARTED] — command-gate-out.sh's entire post-metadata body is structurally u
  └─ 13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and (see above)
29 [NOT STARTED] — Build the deploy-engine mechanism that lets an extension declare 
  └─ 30 [NOT STARTED] — Register the obsidian-memory MCP server through the new manifest-
    └─ 32 [NOT STARTED] — Deploy the accumulated source-store changes and remediate the sta (see above)
50 [NOT STARTED] — Make the verification surface trustworthy, and close the doc-trut

### Commit Scoping Concurrency

48 [NOT STARTED] — Propagate the scoped-commit fix to the 65 call sites it never rea

### Extensions

22 [RESEARCHING] — Silence and correct opencode-agents.json fragment validation spam
45 [NOT STARTED] — Implement <leader>al repo registration and 'Global Update' action
46 [NOT STARTED] — Fix present extension compound-skill routing so /implement resolv

### Literature

39 [PLANNED] — Upgrade the literature extension's Zotero integration beyond bare

### Orchestration Concurrency

37 [IMPLEMENTING] — Close the two residual gaps left by the territory/handoff work. T

### Context Loading

42 [NOT STARTED] — Add two context gates to the deploy verification pipeline. (a) Br
44 [NOT STARTED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/
49 [NOT STARTED] — Cut the measured context cost of the highest-traffic command path
  └─ 44 [NOT STARTED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/ (see above)

### Agent Contracts

52 [RESEARCHED] — The .return-meta.json `artifacts` field is normatively an array o

### Email

43 [NOT STARTED] — LIVE DEFECT, not an efficiency item: the email extension's five '

## Tasks

### 52. Return meta artifacts shape contract
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: agent-contracts
- **Dependencies**: None
- **Research**: [052_return_meta_artifacts_shape_contract/reports/01_return-meta-artifacts-shape.md]

**Description**: The .return-meta.json `artifacts` field is normatively an array of objects ({type, path, summary}), but nothing enforces that shape and roughly a quarter of dispatchable agents never show it inline. A python-implementation-agent dispatch wrote a bare-string array instead; the consumer could not resolve a path from it, so artifact linking silently produced nothing. The work was complete and correct -- only the machine-readable pointer to it was lost. Detected live during an autonomous /orchestrate run in a consumer repository, recorded as system defect evt_1786510331206_WBl5l1.

EVIDENCE (do not re-derive; full sweep in the research report):
- ~19 dispatchable agents contain no "artifacts" key at all, so they are given no inline shape to copy: all of python/, typst/, z3/, latex/; core/planner-agent, core/planner-hard-agent, core/code-reviewer-agent, core/general-research-hard-agent, core/spawn-agent, core/synthesis-agent; lean hard agents; cslib-research-hard-agent; email-implementation-agent; literature-agent.
- A further group has an "artifacts" key but no adjacent "type" field (cslib-vet-agent, filetypes-router-agent, the lean non-hard agents): shape unconfirmed, each needs reading in full.
- core/general-implementation-agent.md carries a correct inline template and is the model to copy.
- Behavior is NON-DETERMINISTIC: in the same observed run, python-research-agent and core/planner-agent (both template-less) emitted CORRECT arrays while python-implementation-agent did not. Sometimes-works is the worst profile for detection.
- There is NO validate-return-meta.sh. validate-handoff.sh, validate-artifact.sh, validate-state.sh, validate-index.sh, validate-wiring.sh all exist; the return-meta sibling does not.
- Detection is structurally partial: orchestrate-recover-outcome.sh computes ARTIFACTS_SHAPE_MISMATCH only on the RECOVERED path. skill-orchestrate/SKILL.md's own "Known residual gap" note states the handoff-present path never calls that script, so the signal is never computed there. A malformed array from a dispatch that DID write a handoff is invisible to every existing mechanism.

WORK (see the research report for full rationale and open questions):
1. Add validate-return-meta.sh, the missing sibling of validate-handoff.sh. Consider a --fix mode promoting a bare string to {path} with type inferred from the path segment (reports/ -> report, plans/ -> plan, summaries/ -> summary), which is an unambiguous repair.
2. Give every dispatchable agent an inline artifacts template, copied from core/general-implementation-agent.md. Mechanical; would have prevented the observed failure outright.
3. Close the handoff-present detection hole named in skill-orchestrate/SKILL.md's residual-gap note.
4. Consider a verify-deploy.sh lint gate in the lint-agent-contracts.sh family asserting every dispatchable agent declares a correctly-shaped template.

DECIDE EXPLICITLY: whether the consumer becomes tolerant of bare strings (accept and normalize) or the contract stays strict with the failure made loud. Tolerance risks entrenching the malformed shape; strictness risks losing artifacts until every agent is fixed. Normalizing at a single chokepoint paired with a loud notice may capture both.

NOT COVERED BY fix_return_meta_lifecycle_ordering, which concerns WHEN .return-meta.json is deleted relative to command-gate-out.sh consuming it. The two are independent: fixing the ordering would still consume a malformed array, and fixing the shape would still be defeated by premature deletion.

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
- **Topic**: agent-system
- **Dependencies**: Task 47, Task 48

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

### 49. Cut context cost orchestrate skills and eager rules
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: context-loading
- **Dependencies**: Task 33, Task 41, Task 48

**Description**: Cut the measured context cost of the highest-traffic command paths. Two independent levers, both remediation -- the measurement and gating work is owned by other tasks and must not be duplicated here.

MEASURED BASELINE (deployed tree, taken live). Tokens consumed before a command does any work, computed as eager session prefix + command body + skill body + agent body: /orchestrate 82.8k, /distill 44.8k, /todo 43.8k, /implement 41.3k, /meta 37.0k, /plan 34.1k, /research 33.4k. Session-start eager prefix alone is 74,136 B (~18.5k tokens).

LEVER 1 -- THE ORCHESTRATE SKILLS (largest per-invocation cost in the system). skill-orchestrate/SKILL.md is 175,303 B; skill-orchestrate-hard/SKILL.md is 107,121 B. A SKILL.md body is loaded IN FULL on every invocation -- confirmed, no include/partial/fragment/compose mechanism exists in install-extension.sh and deploy is a byte-for-byte copy. Structural measurement: 72.6% and 74.2% of those two files respectively is fenced bash, almost all of it in large multi-line blocks (17 blocks / 121,413 B in the standard skill; 17 blocks / 76,966 B in the hard one). At least 28,421 bytes across 427 substantive lines are byte-identical between the two files -- a floor, since near-duplicates differing only by a log prefix are not counted.

THE FILES DOCUMENT THIS THEMSELVES. skill-orchestrate-hard/SKILL.md around lines 956-964: "HARD-MODE TWIN of the append_detected_defect helper in skill-orchestrate/SKILL.md's Stage 5. The two MUST stay in sync -- this file pair is where a one-sided fix is a known recurring defect class, because hard mode's single-task stages are a structurally separate reimplementation rather than a thin wrapper." So this is simultaneously a token cost and an acknowledged correctness liability.

TWO EXTRACTION MECHANISMS, AND THE DIFFERENCE IS THE WHOLE POINT: moving reference PROSE into context/** saves tokens only on invocations that do not need it, because a backticked path is inert text the agent may still choose to Read. Moving procedural BASH into an executable script invoked by a one-line `bash .claude/scripts/foo.sh args` removes it from context entirely -- the script's source is never loaded. The second is far stronger and is already the established pattern here (roughly 20 orchestrate-*.sh scripts already exist; the residual large blocks are simply the logic that was never pushed out). Prefer it. Also extend skill-base.sh's proven skill_* shared-function pattern to cover the duplicated Stage 5 logic (staleness gate, stray-handoff sweep, append_detected_defect) and the structurally-identical postflight-merge blocks, so the duplication closes by construction rather than by discipline. Do NOT invent a new build-time include mechanism -- reuse infrastructure already exercised in production.

COORDINATION WARNING: the handoff staleness gate and the stray-handoff sweep are exactly the code another in-flight task is redesigning (the handoff single-slot-overwrite / loop-guard-deadlock work, which changes the handoff identity contract across both engines and the non-core extensions). Sequence against it or coordinate territory explicitly; extracting that logic into a shared function while its semantics are being rewritten will produce a painful merge. If that task has not landed, extract the postflight-merge and defect-append blocks first and leave the staleness gate for last.

LEVER 2 -- THE EAGER RULES BUDGET (cost paid by EVERY session, not per invocation). The completed context-loading audit predicted a post-deploy eager surface of 41,434 B, and that prediction is accurate for what it modelled: parent chain 3,815 + generated CLAUDE.md 33,624 + two deliberately-eager rules 4,235 = 41,674 B. But it counted every rule carrying `paths:` frontmatter as lazy. Six of them loaded anyway in a real session: git-workflow.md 11,147 B (paths: specs/**/* and .claude/**/*), error-handling.md 5,420 B (.claude/**/*), artifact-formats.md 5,360 B (specs/**/*), state-management.md 5,148 B (specs/**/*), pr-prohibition.md 4,628 B (paths: "**/*", unconditionally eager), workflows.md 759 B (.claude/**/*) -- 32,462 B total. Actual measured eager load is therefore 74,136 B, 78% above the model.

THE GENERALIZABLE LESSON: in a repository whose entire workflow lives under specs/** and .claude/**, gating a rule on those globs is nominal laziness, not real laziness. The rule fires every session. Treat the rules directory as a deliberate eager BUDGET with a stated ceiling, not as a set of individually-gated files.

WORK FOR LEVER 2: split the large rules into a short eager core plus a lazily-referenced companion under context/standards/ -- git-workflow.md (the largest at 11 KB) keeping only the commit-message convention and the forbidden-operations list, with the staging-scope and git-safety narrative moved out; the same treatment for error-handling.md and state-management.md. Slim pr-prohibition.md, whose 4.6 KB includes two CSLib /pr subsections that are inert in deploys without that extension. Preserve behavior: a rule's eager core must still carry everything an agent must know BEFORE acting, since a pointer read after the fact is useless for a pre-write constraint. Where a rule is deliberately kept eager, record the decision in-file as the source-store-deploy-boundary rule already does.

LEVER 3 -- COMMAND BODIES (smaller, cheap). commands/todo.md is 49,254 B; its ## Notes section (~7,851 B) is reference material extractable to context/patterns/. commands/orchestrate.md is 42,282 B; its ## Batch Orchestrate Results output template (~6,739 B) is needed only in batch mode.

BOUNDARIES -- DO NOT DUPLICATE EXISTING TASKS:
  - Do NOT build an eager-context measurement harness. That is the existing eager_context_measurement_harness task. Consume it if it has landed; otherwise measure ad hoc and hand the numbers over.
  - Do NOT build a broken-@-ref lint or a context-budget gate. Those are the existing verify_deploy_context_gates task.
  - Do NOT slim commands/task.md. That is the existing slim_task_command_body task -- but see the correction below before starting it.

TWO CORRECTIONS TO HAND TO THOSE TASKS (record them in the summary; do not silently act on another task's scope):
  (a) The measurement harness's stated model enumerates rules "lacking `paths:` frontmatter or carrying `paths: \"**/*\"`". That misses the actual dominant case measured above -- rules whose paths: glob is `.claude/**/*` or `specs/**/*`, which is where 32,462 B of the eager surface actually hides. The harness must model glob MATCH against a representative session's touched paths, not merely absent-or-universal frontmatter, or it will under-report by roughly the same 78%.
  (b) The task.md slimming target appears mis-chosen. Structural analysis found task.md to be procedural and mode-specific, already citing standards by pointer rather than restating them -- roughly 0-1 KB is extractable, against todo.md's ~7.9 KB and orchestrate.md's ~6.7 KB. Recommend re-pointing that task at todo.md/orchestrate.md, or dropping it.

ACCEPTANCE: report measured before/after bytes for every file touched, using the same eager-prefix + command + skill + agent accounting as the baseline table above -- an unquantified "slimmed" claim is not acceptable. The 28,421+ bytes of literal duplication between the two orchestrate skills exists in exactly one place afterward, and both skills call it by name. Existing orchestration tests pass unmodified. No command loses a behavior: every mode remains fully specified, inline or via an explicit pointer the executing agent is instructed to follow.

THIS TASK IS LARGE AND MAY WARRANT EXPANSION. Levers 1 and 2 are independent in territory (skills versus rules) and can proceed in parallel; if it is driven as one unit, treat them as separate phases with separate commits.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 48. Propagate scoped commit to all call sites
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: commit-scoping-concurrency
- **Dependencies**: Task 16, Task 47

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

### 47. Clear failing gates and reconcile ledgers
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [047_clear_failing_gates_and_reconcile_ledgers/reports/01_clear-failing-gates-and-reconcile-ledgers.md]
- **Plan**: [047_clear_failing_gates_and_reconcile_ledgers/plans/01_clear-gates-reconcile-ledgers.md]
- **Summary**: [047_clear_failing_gates_and_reconcile_ledgers/summaries/01_clear-gates-reconcile-ledgers-summary.md]

**Description**: Clear the two failing verification gates and reconcile the defect/review ledgers against reality. All three items are bookkeeping the validators have already caught; none require design work.

(1) DUPLICATE project_number 41 in specs/state.json. Two active tasks both carry 41: `eager_context_measurement_harness` (created 16:14:06Z, has directory specs/041_eager_context_measurement_harness/) and `move_session_state_files_out_of_specs_root` (created 16:17:10Z, NO directory). A concurrent-creation collision; git log shows next_project_number was already restored past the collision but the duplicate entry itself was never renumbered. This FAILs validate-state.sh --deep and, through it, verify-deploy.sh gate 10. FIX: renumber the directory-less entry (move_session_state_files_out_of_specs_root) to the next free number, advance next_project_number, regenerate TODO.md via generate-todo.sh. Route the write through scripts/state-write.sh -- never a hand-rolled jq read-modify-write.

(2) DOC-LINT FAILURES (verify-deploy.sh gate 3). Three index-entries.json line_count values are stale: context/architecture/context-layers.md (declared 134, actual 194), context/patterns/context-discovery.md (375 vs 379) in the core extension, and project/literature/domain/literature-index.md (117 vs 144) in the literature extension. generate-context-line-counts.sh --check confirms exactly 3 numeric mismatches out of 481 entries; --write corrects them mechanically. Separately, deployed context/standards/task-reference-exemptions.md has NO entry in context/index.json at all (Rule S failure) -- it was created by the context-loading audit but never enrolled in the source index-entries.json. Add the entry.

BOUNDARY (do not absorb adjacent work): this task does NOT decide the one-directional declared-vs-deployed parity question, and does NOT resolve the four orphan files present in the live tree but absent from a clean regenerate. That decision belongs to the existing resolve_deploy_orphan_file_parity task, which is blocked on the deploy-staleness diagnosis. The missing index entry here is the INVERSE case (a deployed file with no declaration) and is a one-line addition, not a parity design decision. Keep them separate.

(3) LEDGER DRIFT. specs/errors.json holds 11 entries, 10 marked unfixed, but at least three are demonstrably fixed in code: hook_regex_defect (hooks/validate-handoff-location.sh now reads [0-9]{3,}, so the 4-digit-directory blocking argument no longer holds), plus test_suite_deployed_mode_failures and test_suite_failure_undocumented (tests/run-all.sh now reports 36/36 when it completes). Verify each before closing -- do not mass-close on this description's say-so. Mark the confirmed ones fixed with their closing evidence. Separately, specs/reviews/state.json records 3 reviews and _last_updated 2026-07-04 while 4 review reports exist on disk; the 2026-07-29 and 2026-08-10 reports were never registered, and a fifth was added by the review that created this task. Register the missing entries and refresh the statistics block.

WHY THIS MATTERS BEYOND TIDINESS: the error-tracking layer was built to close a named root cause ("the error-tracking/self-healing layer is fiction"). It works -- it caught real defects -- but nothing closes entries when fixes land, so a ledger that only grows is as uninformative as no ledger. Consider whether ledger closure can be wired into the postflight path so this does not recur as a manual sweep. If it cannot be automated cheaply, say so and record the reasoning rather than leaving it implied.

ACCEPTANCE: verify-deploy.sh --findings reports 23/23; validate-state.sh --deep exits 0 with zero FAIL findings; specs/errors.json contains no entry marked unfixed whose defect is demonstrably fixed in the current tree, with per-entry closing evidence recorded; specs/reviews/state.json lists every review report present on disk.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**. Writes under specs/** are exempt and expected here.
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
- **Topic**: context-loading
- **Dependencies**: Task 49

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: email
- **Dependencies**: None

**Description**: LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

---

### 42. Add verify-deploy gates: broken-@-ref lint and warning-first context-budget gate
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: context-loading
- **Dependencies**: Task 41

**Description**: Add two context gates to the deploy verification pipeline. (a) Broken-@-ref lint: every `@path` token appearing in generated CLAUDE.md (and in the merge sources that produce it) must either RESOLVE relative to its containing file's directory or be explicitly marked citation-only; a ref that resolves to a nonexistent path is silently inert today (no error, no load) and must fail the gate loudly. The desired end-state for this repo is zero `@`-refs in merge sources (downward normalization to plain backticked paths is already applied), so the lint primarily guards against regression. (b) Warning-first context-budget gate: compute the predicted eager surface (reuse or invoke the measurement harness if it exists by then) and WARN when it exceeds a configured budget; escalate to a hard failure only after the warning tier has proven stable. Consider a per-extension `merge_targets.claudemd.max_bytes` manifest field — NOTE THE SEQUENCING DEPENDENCY: manifest-schema changes must coordinate with the in-flight manifest-schema work (correct-mcp-ownership / extension-manifest efforts); if that work is unsettled when this task starts, implement the budget with an external config and defer the manifest field. CONSTRAINTS: gates must read the source store and the freshly generated output, never trust the possibly-stale deployed .claude/** tree; volatile files (specs/TODO.md, state.json, errors.json) appearing in the eager set is always a FAILURE, not a warning; all edits target agent-system/extensions/**; no task-number references in deliverables outside specs/**.

---

### 41. Build eager-context measurement harness (measure-eager-context.sh)
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Create `measure-eager-context.sh` in the core extension's scripts: a harness that PREDICTS the session-start eager context set from the source store plus a fresh regenerate — never by measuring the live `.claude/` tree (stale-deploy concern; the deployed tree routinely lags the source store). The eager set to model: (1) the parent CLAUDE.md chain (e.g. ~/.config/CLAUDE.md, repo CLAUDE.md, generated .claude/CLAUDE.md); (2) the generated CLAUDE.md content assembled from core + loaded extensions' merge sources; (3) any RESOLVING `@`-imports found in that chain (directory-relative resolution — see context/architecture/context-layers.md 'Eager vs. Lazy Loading Channels'); (4) rules lacking `paths:` frontmatter or carrying `paths: "**/*"`. Emit bytes and estimated tokens (bytes/4) per contributing source plus a total, in a stable machine-parseable format. Provide a `--check`/`--write` split following the precedent of `generate-context-line-counts.sh` (`--check` reports, `--write` records a baseline snapshot for later drift comparison). The audit baseline to compare against: ~69.9 KB / ~17.5k tokens before downward normalization; predicted ~9.5k tokens after. CONSTRAINTS: no volatile files (specs/TODO.md, state.json, errors.json) may ever be counted as legitimately eager — flag any found; all edits target agent-system/extensions/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**.

---

### 40. Fix sentence-boundary-glue gate false positives on Ph.D. and quantifier notation
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [040_fix_convert_quality_gate_glue_false_positives/reports/01_glue-gate-false-positives.md]
- **Plan**: [040_fix_convert_quality_gate_glue_false_positives/plans/01_glue-gate-exemptions.md]
- **Summary**: [040_fix_convert_quality_gate_glue_false_positives/summaries/01_glue-gate-exemptions-summary.md]

**Description**: The `sentence_boundary_glue_count` quality-gate check in `agent-system/extensions/literature/scripts/literature-convert.sh` (function at line 655, called from `run_quality_gate` at line 690, threshold `>= 3`) rejects otherwise-clean conversions of logic and math papers. The regex `[a-z]\.[A-Z]` matches two benign patterns endemic to this corpus: (1) `Ph.D.` in bibliography entries — the `h.D` transition, extremely common in reference lists; (2) single-letter-variable quantifier/binder notation such as `∀x.P`, `∃x.P`, `∃y.E` — the `x.P` transition, standard in logic papers.

=== EMPIRICAL EVIDENCE ===

Observed during Logos/Theory corpus building on 2026-08-11 (session sess_1786462160_5922f5). Both cases are real corpus documents, not synthetic fixtures:

1. Pym–O'Hearn–Yang 2004 "Possible Worlds and Resources": rejected at exactly 4 hits, ALL of them `Ph.D.` in the bibliography.
2. Ishtiaq–O'Hearn 2001 "BI as an Assertion Language": rejected at 7 hits — 5 quantifier notation (`∀x.P` / `∃x.P` / `∃y.E`), 2 `Ph.D.`.

Both conversions were otherwise clean and were manually promoted from `rejected_path`. Any fix MUST keep these two cases passing.

=== HOW THE GATE BEHAVES TODAY ===

`run_quality_gate` collects reasons from five independent checks (column-interleaving, sentence-boundary-glue, page-coverage, ligature-scan, dehyphenation-check). If ANY reason is present, the converted output is written to `rejected_path`, the final `.md` is NOT written, and the script exits 3. So a single false-positive check silently blocks an otherwise-clean conversion from entering the corpus.

=== FIX DIRECTION ===

Exempt benign patterns BEFORE counting — strip `Ph.D.`/`Ph.D` occurrences and single-letter-variable binder patterns (`[∀∃λ]?[a-z]\.[A-Z]` where the left side is a single-letter variable preceded by a quantifier, binder, or math context) — or use a negative lookbehind so that `P` in `Ph.D` and single-letter variables do not count.

This extends reasoning ALREADY RECORDED in the function's own docstring, which documents why comma/semicolon variants were removed: they false-positived heavily on legitimate math tuple/list notation (`(x,Y)`, `a,B,c`). The period-only pattern was retained on a verified 0-1 baseline across a random sample of 60 real corpus markdown files — that sampling evidently under-covered bibliographies and logic notation, which is exactly the gap this task closes.

=== PRESERVE THE CHECK'S REAL PURPOSE ===

The check must still catch genuine zero-space word fusion of the kind found on Goldblatt/Hodkinson/Venema 2003, where pymupdf4llm dropped inter-word spaces around `<sup>`/`<sub>` markdown spans, producing fused runs like "Thesecondlinefollowsby" — a genuine, previously-undetected correctness defect this check caught. Do NOT raise the numeric threshold as a substitute for narrowing the pattern: that would trade one silent-corruption hazard for another, and would degrade detection on documents where real fusion is present but sparse.

=== REGRESSION FIXTURES ===

`scripts/tests/` currently has NO fixture exercising this check in either direction. `generate-test-fixtures.py` provides `build_two_column_pdf` and `build_bold_heading_pdf`; `test-literature-convert.sh` covers Test 1 (forced-fallback tier actually exercised) and Test 2/2b (two-column reading-order regression). Add BOTH polarities:

1. NEGATIVE fixture (must PASS the gate, exit 0): carries `Ph.D.` bibliography entries plus quantifier/binder notation at a density above the current threshold, mirroring the two real-world cases above.
2. POSITIVE fixture (must STILL FAIL, exit 3, output written to `rejected_path`): carries genuine fused-word corruption of the Goldblatt/Hodkinson/Venema signature.

Follow the suite's existing constraints: all test conversions write to a scratch temp directory ONLY; the suite NEVER reads from or writes to ~/Projects/Literature/ (the real corpus).

=== ACCEPTANCE CRITERIA ===

1. The two named real-world papers pass the gate.
2. Genuine fused-word corruption still fails with exit 3 and still writes to `rejected_path`.
3. Both-polarity fixtures exist, are generated by `generate-test-fixtures.py`, and are wired into `test-literature-convert.sh` as required (non-skipping) assertions.
4. The function docstring is updated to record the period-pattern exemptions and the empirical cases motivating them, matching the existing comma/semicolon precedent already documented there.
5. No other gate check (column-interleaving, page-coverage, ligature-scan, dehyphenation-check) is altered, and the numeric threshold `>= 3` is not raised.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree — it is gitignored, disposable, and regenerated from the source store.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

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

### 38. Activate and harden the Zotero write-back path in the literature extension
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [038_activate_zotero_write_back_path/reports/02_zotero-write-back-activation-research.md]
- **Plan**: [038_activate_zotero_write_back_path/plans/02_zotero-write-back-activation.md]
- **Summary**: [038_activate_zotero_write_back_path/summaries/02_zotero-write-back-activation-summary.md]

**Description**: Activate the literature extension's designed-but-inactive Zotero write-back path (create items + attach PDFs during online literature discovery) and harden it against the two correctness hazards found in review. All environment facts below were verified live on 2026-08-11 — do not re-derive them, but DO re-confirm before editing since the environment may have moved on. Full detail in the seed report.

=== VERIFIED FACTS THAT CHANGE THE PICTURE ===

1. THE API-KEY BLOCKER HAS SILENTLY RESOLVED. `ZOTERO_API_KEY` is now set in the environment (currently hardcoded in `~/.config/fish/conf.d/private.fish`; proper provisioning is the ~/.dotfiles repo's job) and was verified via `GET https://api.zotero.org/keys/current`: full `library + files + write` access. The README deployment-status table and `zotero-write.sh`'s header both still claim no key is configured — that documentation is now WRONG.
2. THE ONE REMAINING HARD BLOCKER is that `zot` (zotero-cli-cc) is not installed. The package is real and actively maintained: PyPI 0.10.0 (2026-07-15), summary "Zotero CLI for Claude Code — SQLite reads + Web API writes". Extension docs pin v0.7.0; re-verify flags and the `zot add` envelope against the current release. CROSS-REPO DEPENDENCY: installation is provisioned by the ~/.dotfiles repo (its task 129, Nix-managed, PATH-visible binary) — this task cannot fully complete its live-verification items until that lands.
3. STALE-EXPORT HAZARD IS LIVE: `zotero-library.json` was generated 2026-07-01 but the live database (at the correctly-resolved data dir `/home/benjamin/Documents/Zotero`; beware the decoy `~/Zotero`) was written 2026-08-05; `zotero-export-freshness.sh` correctly emits ZOTERO_EXPORT_STALE. Tier-2 classification reads this export, and the Web API has NO server-side dedup, so a stale export → misclassified-as-new → duplicate item creation. The guard exists but nothing on the write path consults it.
4. The `zot add --pdf` envelope field names remain an unconfirmed empirical unknown (documented in `context/project/literature/patterns/zotero-item-creation.md` section 2, with defensive multi-path probing as the standing mitigation).

=== WORK ITEMS ===

1. CORRECT STALE DOCS: README deployment-status table, `zotero-write.sh` header, tool-requirements version pin, and any remaining "no API key available" claims.
2. LIVE ENVELOPE CONFIRMATION (after `zot` lands): capture `jq '.data'` from one real `item-add` and one real `attach-file` call against the real library; record confirmed field paths in `zotero-item-creation.md`; then either simplify the multi-path probing or keep it with a stated reason. Use `--dry-run` first; the mandatory `%PDF` magic-byte gate and honest-surfacing invariants must be preserved unchanged.
3. DEPLOY the inactive scripts (`zotero-write.sh`, `zotero-read.sh`, `zotero-setup.sh`) through the normal extension deploy flow; update the deployment-status table accordingly.
4. WIRE THE FRESHNESS GATE INTO THE WRITE PATH: on ZOTERO_EXPORT_STALE, refuse item-add or re-verify classification against the live library before any write.
5. PRE-WRITE DEDUP: DOI-normalized lookup (lowercase, strip the `https://doi.org/` prefix) against the LIVE library (Web API search or local sqlite read), never the export snapshot, before any `item-add`.
6. PRESERVE THE CHOKE-POINT: `zotero-write.sh` remains the single write entry so a future backend swap (Zotero 10 local API — follow-on task) never touches callers.

=== ACCEPTANCE CRITERIA ===

1. No extension doc claims the API key is missing; the version pin matches the provisioned `zot`.
2. `zotero-item-creation.md` records live-confirmed envelope field paths (or documents exactly why confirmation is still pending, if the cross-repo provisioning has not landed).
3. The write path refuses or re-verifies on a stale export, and performs DOI-normalized live dedup before creating any item.
4. The magic-byte gate, DOI-only-fallback honest surfacing, and never-fabricate-keys invariants are demonstrably unchanged.
5. Deployed vs. source copies of the three activated scripts are byte-identical and the deployment-status table reflects reality.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree — it is gitignored, disposable, and regenerated from the source store.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 37. Replace the unsound no-concurrency premise with a wired, checkable territory contract for per-phase dispatch
- **Effort**: 3-6 hours
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: Task 33, Task 35
- **Research**: [037_wire_sound_territory_contract_for_per_phase_dispatch/reports/01_close-two-residual-gaps.md]
- **Plan**: [037_wire_sound_territory_contract_for_per_phase_dispatch/plans/01_close-residual-territory-gaps.md]

**Description**: Close the two residual gaps left by the territory/handoff work. This task was originally scoped as "wire a sound territory contract into per-phase dispatch." That wiring has since LANDED as part of the handoff-identity and loop-guard work, which folded this defect in as its DEFECT 5. Most of the original scope is therefore already satisfied. Two verified gaps remain, and they are the entire remaining deliverable.

=== READ THIS FIRST: WHAT IS ALREADY DONE -- DO NOT REDO IT ===

The hard engine's per-phase dispatch NOW SENDS A TERRITORY DECLARATION, and the shared root-cause model NOW EXISTS as a single canonical file. Any implementer who re-derives either will churn two orchestrator-critical files for nothing. Verify these, then move on:

VERIFY, DO NOT REDO (each was checked directly against the source store; re-verify cheaply with the grep given, do not re-implement):

- Sound territory declaration is wired into hard-mode single-phase dispatch.
  Check: `grep -n territory agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  Expect: a `"territory"` key inside the Stage 4 `dispatch_context` JSON (~line 814) carrying
  `owned_files` (derived by the agent from the phase's own "Files to modify" list),
  `read_only_files`, `forbidden_files`, and a `concurrency_note`. The original description's
  central finding -- "NO TERRITORY IS EVER SENT IN HARD MODE" -- IS NO LONGER TRUE. Do not act on it.

- No global no-concurrency assertion survives; STOP-and-report is contractual.
  The shipped `concurrency_note` asserts only which files THIS dispatch owns, explicitly disclaims
  exclusive access, and requires the agent to STOP and report on observing foreign commits, foreign
  uncommitted modifications, or a running build it did not start. `context/contracts/territory.md`
  lines 93-107 carry the same text in the Territory Declaration Template, plus an explicit
  anti-regression note forbidding reintroduction of "you have exclusive access" language.

- The agent-side territory check is no longer dead code -- but CONFIRM THIS.
  `general-implementation-hard-agent.md` Stage 3.6 is gated on "If `territory` parameters were
  provided in delegation context." The hard orchestrator now provides them, so the gate is live on
  that path. Confirm it actually fires as intended before assuming it; if Stage 3.6's steps need an
  explicit tie to the STOP-and-report duty (its four steps currently cover ownership and blockers,
  not the foreign-work observation), that is a small in-scope correction -- not a rewrite.

- Extension hard agents share the pattern. `lean/agents/lean-implementation-hard-agent.md` and
  `cslib/agents/cslib-implementation-hard-agent.md` both now reference
  `context/patterns/dispatch-report-not-termination.md`. No further extension fan-out is needed.

- The shared root cause is stated ONCE, canonically.
  `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` exists and is
  referenced from ~23 files across core, lean, and cslib. DO NOT create a second statement of this
  model anywhere. Reference that file with a one-line pointer, exactly as the existing fix sites do.

=== MOTIVATION (COMPRESSED -- WHY TEARDOWN STILL MATTERS) ===

Observed live as a near-miss during a real `/orchestrate --hard` run: a phase-19 agent WOKE during
a later phase's dispatch and correctly observed five commits it had not made, uncommitted
modifications in two Lean files, and a `lake build` it had not started. It declined to touch any of
it, did not kill the running build, and explicitly retracted its own stale verification numbers as
measured against an older commit. That correct outcome came from the agent reasoning PAST the
premise it had been given -- the premise pointed the other way. The territory work has since made
that STOP-and-report behavior contractual rather than fortunate.

What that work did NOT address: the same agent had to stop a redundant SELF-ARMED MONITOR by hand
across two separate wakes. The wake happened because the monitor was still armed when the agent
reported. Teardown is the PREVENTION half of this defect cluster; the sound territory contract is
the MITIGATION half, and it is done. An agent that tears down its own monitor before reporting
never produces the wake at all.

STANDING LIMITATION (recorded in the original scoping, still true): teardown cannot prevent a
RESUME-driven wake -- no teardown can. Teardown therefore COMPLEMENTS the sound territory contract;
it does not replace it, and shipping it does not make the territory contract redundant.

=== SHARED ROOT CAUSE (POINTER ONLY -- DO NOT RE-DERIVE) ===

Both this defect and the `.orchestrator-handoff.json` single-slot overwrite defect share one root
cause: the system treating "agent reported" as "agent terminated." That model is now stated once, in
`agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`, including a
"Tear Down Watchers/Monitors Before Reporting" section (lines 52-59) that already states the MUST.
Read that file; do not restate its argument in any new location.

=== REMAINING GAP 1: WATCHER/MONITOR TEARDOWN IN THE WRAP-UP CONTRACT ===

`agent-system/extensions/core/context/contracts/wrap-up.md` has ZERO coverage of watchers,
monitors, background jobs, or teardown of any kind. Verified: `grep -inE
'watch|monitor|background|teardown|run_in_background'` over that file returns nothing (194 lines,
sections: Handoff JSON Schema, Continuation Handoff Markdown, Incremental Commit Discipline,
Handoff-Before-Marker Ordering, Build-Green Invariant, Domain Specialization).

The gap is precise and narrower than "unstated anywhere": the teardown MUST already exists in the
pattern file, but wrap-up.md -- the contract an agent actually loads at wrap-up time, and the one
that enumerates what must happen "before terminating" -- never carries it. An agent following
wrap-up.md to the letter can report with a monitor still armed and violate nothing it was given.

Deliverable: add teardown to wrap-up.md as an obligation discharged BEFORE the terminal handoff
write, consistent with that file's existing "Ordering: Handoff Write Precedes Marker Promotion"
sequencing. State the obligation operationally in wrap-up.md; point at the pattern file for the WHY
rather than re-arguing it. Alternatively, record explicitly and visibly why it is out of scope --
but "already covered in the pattern file" is NOT an adequate reason, because the loading paths differ.

=== REMAINING GAP 2: BASE-MODE DECISION RECORD ===

`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` has ZERO territory mentions
(`grep -c territory` returns 0), while the hard engine now has seven. `context/contracts/territory.md`
still opens scoped to "file ownership and commit coordination when multiple agents are dispatched
simultaneously," with its Territory Declaration Template described as what "the orchestrator includes
in each parallel dispatch context" -- neither statement updated for the single-phase dispatch that
now actually consumes it.

This is not droppable, because base mode GENUINELY DISPATCHES MULTIPLE AGENTS CONCURRENTLY: Stage
MT-3's BATCHING RULE requires all Agent calls for a cycle to be issued in a SINGLE message
specifically so they run concurrently. A sound territory contract may therefore matter MORE in base
mode, not less.

Weigh honestly against what base mode already has: it defers tasks with overlapping `file_scope` and
no dependency edge, logging "Deferring #{Y} to a later cycle to avoid concurrent edits to the same
files" (in_batch and cross_batch variants, both recorded in `defer_ledger`). That mechanism is a real
mitigation for FILE conflicts between tasks the orchestrator itself dispatches -- and it is
structurally blind to the woken-predecessor case, which is this defect's actual subject. A decision
that cites file_scope deferral as sufficient must address that blindness explicitly.

Deliverable: an EXPLICIT, RECORDED decision -- either wire base mode too, or record why not, with
the file_scope-deferral limitation addressed either way. Plus: rescope territory.md's opening and
its Template preamble to match reality (it is consumed by single-phase dispatch today, not only by
parallel dispatch). An UNRECORDED ASYMMETRY between the two engines is the failure mode to avoid;
the two carry an explicit mutual co-maintenance contract, so a silent divergence is a contract
violation, not merely untidiness.

=== ACCEPTANCE CRITERIA ===

1. Watcher/monitor/background-job teardown before the terminal handoff write is either present in
   `context/contracts/wrap-up.md` as an operational obligation (with a pointer, not a re-derivation,
   for the rationale), or explicitly recorded as out of scope with a reason that engages with the
   differing loading paths of wrap-up.md and the pattern file.
2. A recorded decision exists on whether base mode gains a territory contract, addressing base
   mode's genuinely concurrent multi-task dispatch and the woken-predecessor blindness of its
   existing file_scope collision deferral. If base mode is wired, the co-maintenance contract
   between the two engines is honored; if not, the reason is written down where a future reader of
   either engine will find it.
3. `context/contracts/territory.md`'s opening scope and Template preamble accurately describe how
   the contract is consumed today (single-phase dispatch), not only parallel dispatch.
4. VERIFICATION ONLY (confirm, do not redo): the hard engine's `territory` dispatch key and its
   `concurrency_note` are present and sound; `dispatch-report-not-termination.md` remains the single
   statement of the shared root cause with no second copy introduced; the lean and cslib hard agents
   still reference it; and `general-implementation-hard-agent.md` Stage 3.6 is genuinely live on the
   hard dispatch path. Any correction here is a small targeted fix, never a rewrite.
5. No new statement of the "report != termination" model is created. Every new mention is a
   one-line pointer to the existing pattern file.

=== SEQUENCING ===

The handoff-identity/loop-guard work and the spurious-phase-advance work are both landed; the
dependency that motivated serialization of edits to `skill-orchestrate-hard/SKILL.md` is discharged.
The remaining work touches `context/contracts/wrap-up.md`, `context/contracts/territory.md`, and
possibly `skills/skill-orchestrate/SKILL.md` -- largely disjoint from the files those efforts churned.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/** (core, plus the lean and cslib extensions where named). NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 36. Audit context loading efficiency
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [036_audit_context_loading_efficiency/reports/01_team-research.md]
- **Plan**: [036_audit_context_loading_efficiency/plans/01_context-loading-optimization.md]
- **Summary**: [036_audit_context_loading_efficiency/summaries/01_context-loading-optimization-summary.md]

**Description**: Audit context-loading efficiency across the agent system and its extensions, then create optimization tasks. A single /task invocation eagerly loaded ~19k of context before doing any work (CLAUDE.md, README, topic-assignment-pattern.md, and unrelated literature/nix/present extension context plus four rules files). The sweep should determine which context is loaded eagerly vs lazily, which loads are unconditional regardless of task type or command, and where @-imports, rules path globs, and extension context indexes can be narrowed or deferred

---

### 35. Stop preflight from auto-advancing an undispatched plan phase to [IN PROGRESS]
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: Task 16, Task 33
- **Research**: [035_stop_preflight_spurious_phase_advance/reports/01_preflight-phase-advance-defect.md]
- **Plan**: [035_stop_preflight_spurious_phase_advance/plans/01_delete-preflight-phase-autoadvance.md]
- **Summary**: [035_stop_preflight_spurious_phase_advance/summaries/01_delete-preflight-phase-autoadvance-summary.md]

**Description**: Remove or correctly gate a one-time preflight side effect that marks a plan phase [IN PROGRESS] when no agent is dispatched for it. Observed live during a real `/orchestrate --hard` run (prior run, cycle 13).

=== OBSERVED FAILURE ===

Phase 19 was left marked [IN PROGRESS] with no dispatch behind it. That false marker then misled the phase-18 agent into reporting a nonexistent CONCURRENT DISPATCH -- a false territory-conflict signal. Correcting it required a /revise run. So the impact is not cosmetic: a bogus phase marker feeds directly into the territory-contract reasoning (H7) that hard mode relies on, and produces a fabricated conflict report.

=== THE REAL OWNER IS NOT skill-base.sh ===

This matters -- do not start from the wrong file. Investigation established:

  - `skill_preflight_update` in agent-system/extensions/core/scripts/skill-base.sh (lines 214-232) contains NO phase logic at all. It only shells out to update-task-status.sh, fires a hook, and appends an event.

  - THE ACTUAL OWNER is agent-system/extensions/core/scripts/update-task-status.sh, function `update_plan_file()`, block at lines 525-583. It is guarded by `if [[ "$operation" == "preflight" ]]` at line 526. It selects the highest-versioned plan file, runs `grep -m1 -E "${PHASE_HEADING_ERE}.*\[NOT STARTED\]"`, and calls `update-phase-status.sh "$task_number" "$project_name" "$first_phase" "IN_PROGRESS"` at line 578, with no check that any agent will actually be dispatched for that phase. The dry-run echo at line 501 confirms the documented intent.

  - IMPORTANT SCOPE WIDENING: the guard is keyed on the OPERATION SLOT `preflight`, NOT on `implement`. So this side effect fires for research and plan preflights too, not only implement preflights. Confirm the true breadth before choosing a fix.

  - Call sites are in skill-orchestrate-hard/SKILL.md Stage 4 (heading line 482): lines 489 (research), 578 (plan), 695 (implement), and 849 (implement, continuation-available sub-state, already annotated "Defense-in-depth: status is typically already 'implementing' here, so this is usually a no-op").

=== THE CODE ALREADY DOCUMENTS ITSELF AS REDUNDANT ===

Comments in update-task-status.sh lines 575-577 state the call is "Superseded by the base agent owning every per-phase transition directly; this call is a redundant convenience". If per-phase transitions are genuinely owned by the dispatched agent now, the strongest fix is to DELETE the convenience rather than gate it. Verify that claim against the current agents before acting on it -- if some path still depends on the auto-advance, deletion would silently regress it.

A PARTIAL GUARD ALREADY EXISTS: `has_nonconforming_phase_headings` (line 561) skips the convenience when phase headings do not conform. Nothing gates it on actual dispatch. That existing guard shows where a dispatch-awareness check would naturally slot in.

=== EXISTING TEST COVERAGE IS INSUFFICIENT ===

scripts/tests/test-skill-base-lifecycle.sh lines 251-271 exercise only the state.json transition, never the plan-file phase side effect. The regression that would have caught this defect does not exist yet.

=== ACCEPTANCE CRITERIA ===

1. A preflight that does not dispatch an agent for a given phase never marks that phase [IN PROGRESS].
2. The chosen fix is justified explicitly as either (a) deletion of a genuinely redundant convenience, having verified the dispatched agent owns every per-phase transition, or (b) a dispatch-awareness gate, having identified a path that still needs the auto-advance. Record which and why.
3. The behaviour is settled for ALL THREE operation slots the `operation == "preflight"` guard currently covers (research, plan, implement), not implement alone.
4. A regression test asserts the plan-file phase marker is untouched by a non-dispatching preflight, covering the side effect that test-skill-base-lifecycle.sh currently misses.
5. No phase marker is left [IN PROGRESS] without a corresponding dispatch, so the territory-conflict reasoning can no longer be fed a fabricated concurrent dispatch.

=== CO-MAINTENANCE ===

The two orchestrate SKILL.md files carry an explicit contract about each other (skill-orchestrate-hard/SKILL.md lines 956-961 and 1686-1688: "an edit to either copy REQUIRES the same edit to the other; the two MUST always agree"). If this fix changes anything at the Stage 4 preflight CALL SITES rather than solely inside update-task-status.sh, the corresponding change MUST be made in skill-orchestrate/SKILL.md as well. Verify base mode's preflight call sites for the same side effect regardless, since both engines call the same shared helper -- the defect is in shared code and is therefore very likely to affect base mode identically.

=== SEQUENCING ===

Depends on the handoff-identity and loop-guard task because both edit skill-orchestrate-hard/SKILL.md; the dependency serializes the overlapping edit territory. The root-cause file here (update-task-status.sh) is disjoint from that task.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 34. Anchor guard-destructive-git.sh destructive-pattern matching to argv, not commit-message prose
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

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

Reproduction hint for the implementer: the commit that eventually succeeded was `f2679860a` ("meta: create 3 tasks for hard-mode orchestrator defect remediation"). Compare against whatever earlier message was rejected — the delta identifies the trigger substring. Per the task body above, the `git add`/`git commit` over-staging detectors already quote-strip via `seg_scan`; it is the destructive chain (lines 116-184) that greps raw, and that is where both firings originate.

---

### 33. Give .orchestrator-handoff.json per-dispatch identity and fix the exhausted-loop-guard resume deadlock
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [033_fix_handoff_identity_and_loop_guard_resume_deadlock/reports/01_handoff-identity-and-loop-guard-resume.md]
- **Plan**: [033_fix_handoff_identity_and_loop_guard_resume_deadlock/plans/01_handoff-identity-loop-guard-fix.md]
- **Summary**: [033_fix_handoff_identity_and_loop_guard_resume_deadlock/summaries/01_handoff-identity-loop-guard-fix-summary.md]

**Description**: Fix two coupled, high-severity run-state-integrity defects in the orchestrator engines. Both were observed live during a real `/orchestrate --hard` run in a separate repository; both are recorded system-defect observations with concrete evidence, not speculation. They are combined into one task because they live in the same two files, share the same co-maintenance contract, and overlap heavily on edit territory.

=== DEFECT A: HANDOFF_SINGLE_SLOT_OVERWRITE (observed twice: prior run cycle 13, and again cycle 2 of the following run) ===

PROBLEM: `.orchestrator-handoff.json` is a single fixed path per task, shared by every per-phase dispatch. Path construction carries no phase number, cycle number, dispatch id, or agent name:
  - skill-orchestrate-hard/SKILL.md line 142: HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
  - skill-orchestrate/SKILL.md line 66: the same literal expression.
Hard mode dispatches one phase per cycle, so successive phases all write the same slot (hard-mode Stage 4 handlers at lines ~495, 546, 582, 699, 849 all write/overwrite it).

OBSERVED FAILURE: a subagent that stops and is later resumed writes the slot AGAIN, after the orchestrator has already dispatched the NEXT phase. Concretely: the phase-19 agent's late write landed at mtime 1786458768, while the phase-20 dispatch window had opened at 1786458762 -- the late write is 6 seconds INSIDE the successor's window.

WHY THE EXISTING GATE CANNOT CATCH IT: Stage 5's staleness gate is purely mtime-based. Hard mode lines 1000-1006, base mode lines 581-620 (byte-identical apart from the notice prefix) compute `handoff_mtime` via stat and mark the handoff stale only when `handoff_mtime -lt dispatch_start_ts`. A late predecessor write has a NEWER mtime than the successor's dispatch start, so it passes the gate and is read as the successor's own result. The orchestrator would then apply the WRONG phase's `phases_completed`, `status`, and `blockers`.

NO CONTENT-SIDE IDENTITY EXISTS TODAY: the handoff-present read block (hard lines 1267-1345 and base equivalents) reads `.status`, `.summary`, `.next_action_hint`, `.phases_completed`, `.phases_total`, `.skeleton`, `.plan_markers_verified`, `.artifacts[0].*`, `.blockers[0].*`, and `.continuation_context.handoff_path // .continuation_path` -- never any phase or dispatch identifier. The schema at context/schemas/orchestrator-handoff-schema.json DOES define a `phase` property, but (i) it is NOT in the `required` array, (ii) docs/architecture/handoff-schema.md lines 148-149 label it "optional, informational", and (iii) its enum is the LIFECYCLE phase [research, plan, implement, revise], so it cannot discriminate plan phase 19 from plan phase 20 -- both are "implement". The nominally-present identity field is therefore useless for this purpose as it stands.

THE STANDARD'S OWN RATIONALE IS UNDERMINED: context/standards/orchestrator-runtime-files.md classifies the handoff as "Durable provenance (tracked)" and justifies tracking it on the grounds that "a documented freshness gate already protects against exactly that 'restored from an old commit' scenario". That rationale only ever considered the git-restoration hazard (an OLD mtime, which the gate does catch). It never considered the late-writer hazard (a NEW mtime from a predecessor agent), which the gate structurally cannot catch. docs/architecture/handoff-schema.md line 49 already states "A handoff at the correct path is not necessarily *this dispatch's* handoff" and then offers only mtime as the mitigation. base SKILL.md line 1204 separately acknowledges "a stale handoff from an unrelated prior hard-mode dispatch happens to sit at that path".

WHY THE PRIOR RUN SURVIVED: the prior run's own recorded note said "read-before-overwrite held this run, so no data was lost in practice". That ordering is luck. It is not enforced anywhere.

SUGGESTED DIRECTION (evaluate during research/plan, do NOT blindly adopt): give the handoff a per-dispatch identity. Candidate approaches include phase-scoped filenames plus a pointer file, or embedding a dispatch-id and/or numeric plan-phase in the handoff CONTENT which the orchestrator verifies against the phase it actually dispatched. The goal is content-based discrimination rather than timestamp-based. Weigh this against the file's current "Durable provenance (tracked)" classification and the stray-handoff sweep, both of which assume a static filename.

BLAST RADIUS (verified by grep across the source store): the handoff is referenced by core agents (general-implementation-agent, general-implementation-hard-agent, general-research-agent, general-research-hard-agent), core skills (skill-orchestrate, skill-orchestrate-hard, skill-implementer-hard, skill-team-implement), the schema, validate-handoff.sh, hooks/validate-handoff-location.sh, skill-base.sh, orchestrate-triage-classify.sh, orchestrate-recover-outcome.sh, orchestrate-dry-run-report.sh, reconcile-task-status.sh, several context patterns and contracts, AND non-core extensions: cslib (cslib-implementation-agent, cslib-implementation-hard-agent, cslib-research-agent, skill-cslib-implementation-hard, skill-cslib-research) and lean (lean-implementation-hard-agent, skill-lean-implementation-hard, context/contracts/anti-analysis.md). Any change to the identity contract MUST sweep the non-core extensions too, not just core.

=== DEFECT B: EXHAUSTED_LOOP_GUARD_RESUME_DEADLOCK (hit at the start of the following run) ===

PROBLEM: when a run terminates at MAX_CYCLES, Stage 7 prints a resume instruction, but the loop guard persists `cycle_count` across invocations and Stage 2's resume branch reads it back with no invocation discrimination. The very next invocation therefore reads cycle_count == MAX_CYCLES, the `while` loop condition is immediately false, nothing is dispatched, and the run exits at Stage 7 printing the same instruction again. The documented resume path is a guaranteed no-op.

HARD MODE EVIDENCE (skill-orchestrate-hard/SKILL.md):
  - MAX_CYCLES=13 (line 225); loop_guard_file at line 231
  - unconditional resume read at lines 317-327: cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  - loop condition line 414: while [ "$cycle_count" -lt "$MAX_CYCLES" ]
  - Stage 7 (heading line 1563), lines 1576-1581: prints "Run /orchestrate $task_number --hard to resume, or /implement $task_number --hard for manual phase dispatch."
  - Stage 8 cleanup lines 1663-1666: `rm -f "$loop_guard_file"` runs ONLY on successful completion -- "Leave loop guard and churn state on partial for resume."
So on partial exit the guard is preserved carrying cycle_count == 13 == MAX_CYCLES, and the next invocation deadlocks.

THE STALENESS DETECTOR DOES NOT CATCH THIS: the hard-mode `loop-guard-staleness` detector (sentinel-delimited, lines 247-315) has exactly three OR-combined signals -- max_cycles drift (263-266), plan_version drift (271-276), and mtime age (280-289, threshold ORCHESTRATOR_LOOP_GUARD_STALE_DAYS default 7 days). On a genuine same-plan resume none of them fire: max_cycles is unchanged, plan_version is unchanged, and the guard was just written so its mtime is fresh. A budget-exhausted-but-current guard is invisible to all three. Hard mode therefore self-heals only after the 7-day mtime backstop.

BASE MODE IS STRICTLY WORSE (skill-orchestrate/SKILL.md): MAX_CYCLES=5 (line 99), resume read at lines 112-130, and there is NO staleness detector at all (`grep -c loop-guard-staleness` returns 0). The file documents the absence as deliberate at lines 91-96: the guard is "per-cycle runtime state with no freshness check on read ... any syntactically valid guard file at this path is trusted, with no session_id or mtime comparison". Line 113 repeats "Resume: read existing guard. No session_id or mtime check". Exhaustion messages at lines 1263-1266 and 1298 both say "Run /orchestrate $task_number to continue." Guard rm -f only on clean exit (line 1286). Base mode therefore deadlocks PERMANENTLY with no self-healing path whatsoever.

OPERATIONAL IMPACT: the operator has no sanctioned way to resume an exhausted run. The observed run only proceeded because the exhausted guard was archived by hand.

CRITICAL EXISTING CONSTRAINT THE FIX MUST RESPECT: the loop guard already carries a `guard_session_id`, and scripts/test-session-runtime-files.sh Case 3 asserts that loop-guard and churn-state session_id mismatch handling MUST be a log line and MUST NEVER be a gate. Its stated rationale: "Guards the top risk: a future 'make it consistent' edit that hard-fails these files would break legitimate conversational-turn resume." The test fails if the mismatch block contains hard-fail/abort/exit/return 1, and fails if it does not log an INFO line. So the naive fix -- resetting cycle_count whenever session_id differs -- is explicitly forbidden by an existing regression test protecting a real behaviour. Any solution must distinguish a NEW OPERATOR-INITIATED INVOCATION from a CONVERSATIONAL-TURN RESUME WITHIN the same invocation. Do not weaken or delete Case 3 without a recorded justification.

SUGGESTED DIRECTION (evaluate, do not blindly adopt): a new operator-initiated invocation should receive a fresh work-cycle budget while preserving the cross-invocation history the guard carries. Decide EXPLICITLY whether cycle_count is per-invocation or per-task, then make Stage 2, Stage 7, Stage 8 cleanup, and the resume message all agree on that answer. Consider whether budget exhaustion should become a fourth staleness signal, or whether it needs a different mechanism entirely given that an exhausted guard is current rather than stale.

=== CO-MAINTENANCE (BINDING ACCEPTANCE CRITERION, NOT AN AFTERTHOUGHT) ===

skill-orchestrate/SKILL.md and skill-orchestrate-hard/SKILL.md carry an explicit co-maintenance contract about each other. skill-orchestrate-hard/SKILL.md lines 956-961: "The two MUST stay in sync: this file pair is where a one-sided fix is a known recurring defect class, because hard mode's single-task stages are a structurally separate reimplementation rather than a thin wrapper." And lines 1686-1688: "CO-MAINTENANCE: an edit to either copy REQUIRES the same edit to the other; the two MUST always agree." Supporting rationale at lines 60-64.

Apply it per defect, noting they differ in shape:
  - Defect A: the Stage 5 gate is a VERBATIM TWIN (hard 985-1030 / base 581-620). A one-sided fix here reproduces exactly the named recurring defect class. Both copies MUST be fixed together.
  - Defect B: ASYMMETRIC. The 3-signal detector exists only in hard mode; base mode documents its absence as deliberate. The base-mode fix is therefore NET-NEW code, not a mirror edit. Do not mechanically copy the hard-mode block into base without first deciding whether base mode should gain a detector at all, or whether budget exhaustion should be handled by a mechanism that suits both. Record the decision either way. Related precedent: base line 1518 records a similar asymmetry as "Hard-mode finding, recorded, not acted on".

=== ACCEPTANCE CRITERIA ===

1. A predecessor phase's late handoff write can no longer be mistaken for the successor phase's result, demonstrated by a regression test that reproduces the observed timing (late write with mtime INSIDE the successor's dispatch window) and asserts the orchestrator rejects it.
2. Whatever identity mechanism is chosen is reflected consistently in: the JSON schema, validate-handoff.sh, docs/architecture/handoff-schema.md, context/standards/orchestrator-runtime-files.md (including its now-incomplete tracking rationale), every core writer/reader listed above, and the cslib and lean extension writers.
3. An operator invoking the documented resume command on a task whose previous run exhausted MAX_CYCLES actually dispatches work, in BOTH base and hard mode. Covered by a regression test.
4. Stage 2, Stage 7, Stage 8 cleanup, and the printed resume message agree on a single explicit answer to "is cycle_count per-invocation or per-task", and that answer is documented in the source store.
5. scripts/test-session-runtime-files.sh Case 3 still passes unmodified, or its modification carries a recorded justification.
6. Both SKILL.md files are updated in lockstep for Defect A; for Defect B the asymmetry decision is recorded in both files.
7. Existing suites still pass: test-validate-handoff.sh, test-handoff-reader-parity.sh, test-loop-guard-staleness.sh, test-reconcile-handoff-status.sh, test-validate-handoff-location.sh, test-session-runtime-files.sh.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target /home/benjamin/.config/nvim/agent-system/extensions/** (core, plus the cslib and lean extensions where named). NEVER edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.
=== SHARED ROOT CAUSE WITH THE TERRITORY-ASSERTION DEFECT (ADDED AFTER A FIFTH LIVE OBSERVATION) ===

Defect A above and the unsound-territory-assertion defect (tracked separately, and dependent on
this task) share ONE root cause: THE SYSTEM TREATS "AGENT REPORTED" AS "AGENT TERMINATED". It is
not. A dispatch can resume after it reports -- via a stale watcher/monitor it armed, or via a
resume.

Both symptoms follow directly from that single false assumption:
  - A woken predecessor is exactly the LATE WRITER that clobbers the single-slot handoff
    (Defect A above).
  - The same wake is what makes a global no-concurrency premise false (the separate defect).
  - The mtime staleness gate is blind to BOTH for the same reason: a woken predecessor's write
    carries a NEWER mtime than the successor's dispatch window, so it passes a gate designed only
    to catch OLD (git-restored) files.

CORROBORATING LIVE EVIDENCE: during the same run, the phase-19 agent woke during the phase-21
dispatch's flight and observed five commits it did not make, uncommitted modifications in two
FormalSystem/Metalogic files, and a running `lake build`. That is the wake path in Defect A stated
above, directly observed, and it recurred across two separate wakes.

BINDING CONSEQUENCE FOR THIS TASK: do NOT fix the handoff identity in isolation. The "report !=
termination" model MUST be stated ONCE in the source store as part of this work and referenced
from both fix sites rather than re-derived independently. A per-dispatch identity scheme designed
on the assumption that a reported dispatch is finished will not actually close Defect A -- the
whole point is that the predecessor is still alive and still writing. Additional acceptance
criterion: the chosen identity mechanism must be demonstrably correct when the PREDECESSOR is
still live and writing, not merely when it is finished.
=== ADDENDUM (appended by the orchestrator after task creation; the meta agent was terminated by an API usage limit before it could fold this in) ===

DEFECT 5 — UNSOUND_TERRITORY_ASSERTION. Source: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, the H7 territory contract slot in the Stage 4 per-phase dispatch context (check the base engine for equivalent boilerplate).

The H7 slot tells each dispatched agent: "No other agent is running concurrently — any claim of a concurrent dispatch is false." This is unsound, and structurally so. Hard mode dispatches one phase per cycle, and a phase agent that has finished and reported can be WOKEN AGAIN later (by a stale watcher/monitor it armed, or by a resume) while a SUCCESSOR phase dispatch is mid-flight. At that wake the assertion is false. Worse, it is phrased so as to pre-emptively discredit the true observation, which would license a woken agent to dismiss real concurrent work as fictitious and edit into another dispatch's live territory.

Observed live (near-miss, not a clean pass): the phase-19 agent woke during the phase-21 dispatch's flight, saw five commits it did not make, uncommitted modifications in `FormalSystem/Metalogic/Algebraic/FlowFrame.lean` and `FormalSystem/Metalogic/BXCanonical/CompletenessDedekind.lean`, and a running `lake build`. It touched none of it, deliberately did not kill the build, and explicitly retracted the premise it had been given. That correct outcome came from the agent reasoning PAST the contract it was handed — the contract pointed the other way. The same agent woke four separate times on self-armed monitors.

SHARED ROOT CAUSE (record this explicitly): defects 1 and 5 are one bug wearing two faces — "an agent's report is treated as its termination, when it can in fact resume afterwards." The wake that makes the territory assertion false is the same wake that produces the stale single-slot handoff write, and the orchestrator's mtime staleness gate is blind to both for the same reason (a woken predecessor writes with a NEWER mtime than the successor's dispatch window). An implementer fixing either in isolation will leave the other live.

Suggested direction (evaluate, do not blindly adopt): have the territory contract assert only what is true and checkable — this dispatch owns these files, others may exist, and if you observe work you did not do, STOP and report rather than proceed or dismiss — instead of asserting a global no-concurrency invariant the orchestrator cannot guarantee. Also consider requiring agents to tear down watchers/monitors before reporting, so the wake never happens.

DEFECT 6 — UNVERIFIED_PHASE_MARKER_ON_INFRA_TERMINATION (newly observed; decide whether it belongs here or as its own task). The phase-21 agent wrote `[COMPLETED]` into the plan's phase heading BEFORE writing its handoff, then died to an API limit. Result: the plan marker claimed 21/23 complete while the handoff still reported 20, with no phase-completion commit and only one sub-step commit on disk. Because the next-phase heading scan trusts the plan marker, an interrupted dispatch can cause the SUCCESSOR phase to be dispatched over unconfirmed work. The orchestrator downgraded the marker to `[PARTIAL]` by hand. Consider ordering the wrap-up so the handoff is written before any plan-marker promotion, or making the scan cross-check the marker against the handoff.

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
- **Dependencies**: Task 19, Task 22

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

### 26. Migrate slidev deck verification from standalone npm Playwright script to MCP server
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 24
- **Research**: [026_migrate_slidev_verification_to_playwright_mcp/reports/01_slidev-verification-mcp-migration.md]
- **Plan**: [026_migrate_slidev_verification_to_playwright_mcp/plans/01_slidev-verification-mcp-plan.md]
- **Summary**: [026_migrate_slidev_verification_to_playwright_mcp/summaries/01_slidev-verification-mcp-plan-summary.md]

**Description**: Migrate slidev deck screenshot verification from the standalone npm Playwright script to the live Playwright MCP server, removing the duplicate Playwright install path.

PROBLEM: the present and founder extensions carry their own Playwright usage that predates the MCP server and duplicates its capability. agent-system/extensions/present/context/project/present/talk/templates/playwright-verify.mjs is a standalone Node script requiring a separate npm Playwright install and its own browser binaries. Related references appear in present/context/project/present/talk/patterns/slidev-pitfalls.md, present/context/project/present/domain/talk-modes-and-library.md, present/context/project/present/talk/templates/slidev-project/README.md, present/index-entries.json, present/context/project/present/talk/index.json, founder/agents/deck-builder-agent.md, and founder/context/project/founder/patterns/slidev-deck-template.md.

WORK: replace the standalone-script verification path with the MCP server (browser_navigate plus browser_snapshot / browser_take_screenshot), so the system has ONE browser automation mechanism rather than two independent Playwright installs. Update the referencing context files, agent docs, and index entries consistently so nothing points at a removed path.

CAUTION -- VERIFY PARITY BEFORE DELETING: confirm the .mjs script's full capability is genuinely covered by the MCP tool set before removing it. A standalone script can do things a permissioned MCP surface cannot: custom in-page evaluation loops, batch or offline runs with no agent in the loop, and deterministic CI invocation. Note specifically that browser_evaluate and browser_run_code_unsafe are deliberately NOT allowlisted and will prompt, so any verification logic depending on in-page evaluation may not migrate cleanly. If full parity is not achievable, DOCUMENT THE RESIDUAL GAP and keep the script for that narrow case rather than forcing the migration and silently losing coverage.

DEPENDS ON the permission work: this migration is only viable once the safe browser tools run without prompting.

ACCEPTANCE: deck screenshot verification runs through the MCP server; the duplicate npm Playwright install path is removed, or its continued existence is explicitly justified in writing; all referencing docs and index entries are consistent with the outcome.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/present/** and /home/benjamin/.config/nvim/agent-system/extensions/founder/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 25. Activate parked Playwright MCP integration in web extension and reconcile drifted tool list
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 23, Task 24
- **Research**: [025_activate_playwright_mcp_in_web_extension/reports/01_activate-playwright-mcp.md]
- **Plan**: [025_activate_playwright_mcp_in_web_extension/plans/01_activate-playwright-mcp.md]
- **Summary**: [025_activate_playwright_mcp_in_web_extension/summaries/01_activate-playwright-mcp-summary.md]

**Description**: Activate the already-designed but parked Playwright MCP integration in the web extension, and reconcile its drifted tool list against the live server.

THIS IS AN ACTIVATION TASK, NOT A GREENFIELD BUILD. A complete design already exists in agent-system/extensions/web/agents/web-implementation-agent.md (approximately lines 50-63) under the heading '**Playwright MCP** (deferred -- not yet active)' with '**Status**: Deferred pending browser binary installation'. That precondition is now satisfied: the server is registered at user scope, connected and healthy, exposing 24 browser_* tools.

DO NOT REMOVE THE web-research-agent BLOCK. agent-system/extensions/web/agents/web-research-agent.md line 4 carries 'disallowedTools: mcp__playwright__*'. This is DELIBERATE ROLE-SCOPING, not an obstacle to clear: web-implementation-agent symmetrically blocks mcp__context7__* instead. Each agent blocks the MCP server that is not its job -- research reads docs, implementation drives browsers. Leave BOTH blocks in place.

WORK:
(1) Flip the deferred status to active in web-implementation-agent.md.
(2) PRESERVE the usage conditions already written there: prefer accessibility snapshots over screenshots (lower token cost, more useful); do NOT use Playwright for tasks verifiable with 'pnpm build' alone; only use when the implementation plan includes visual verification steps.
(3) RECONCILE THE DRIFTED SPEC. The parked section lists browser_verify_text_visible, which does NOT exist among the server's actual tools. Map the deferred spec's INTENT onto real tools -- for example, text-visibility assertions map onto browser_find and/or browser_wait_for. The real 24-tool set is: browser_navigate, browser_navigate_back, browser_snapshot, browser_take_screenshot, browser_click, browser_type, browser_fill_form, browser_find, browser_hover, browser_drag, browser_drop, browser_select_option, browser_press_key, browser_wait_for, browser_resize, browser_tabs, browser_close, browser_handle_dialog, browser_console_messages, browser_network_request, browser_network_requests, browser_evaluate, browser_file_upload, browser_run_code_unsafe.
(4) Teach WHEN to drive a browser, not merely how: screenshot and visual verification of a running app, console and network inspection for debugging, end-to-end UI checks. Add a context file under agent-system/extensions/web/context/ and register it in web/index-entries.json if a new file is created.
(5) Keep guidance consistent with the permission split from the prerequisite task: guidance must NOT instruct agents to rely on tools that still prompt (browser_run_code_unsafe, browser_evaluate, browser_file_upload), since that would reintroduce the autonomous-run stall.

ACCEPTANCE: web-implementation-agent documents an active, accurate Playwright MCP capability naming only tools that actually exist; web-research-agent's disallowedTools line is unchanged; no guidance depends on a tool that still prompts.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/web/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 24. Scope Playwright MCP permission allowlist to safe browser tools, solving install-once propagation
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: Task 23
- **Research**: [024_scope_playwright_mcp_permission_allowlist/reports/01_scoped-playwright-permission-allowlist.md]
- **Plan**: [024_scope_playwright_mcp_permission_allowlist/plans/01_scoped-playwright-permission-allowlist.md]
- **Summary**: [024_scope_playwright_mcp_permission_allowlist/summaries/01_scoped-playwright-permission-allowlist-summary.md]

**Description**: Add a deliberately scoped Playwright MCP permission allowlist so autonomous runs stop stalling, without blanket-allowing arbitrary execution.

PROBLEM: mcp__playwright__* is absent from every settings allowlist while mcp__lean-lsp__* is present, so every browser call raises a permission prompt. Under /orchestrate there is no human available to answer, so autonomous runs stall.

DESIGN (fixed by user decision, not open for redesign): allowlist ONLY the safe navigation and inspection tools -- browser_navigate, browser_snapshot, browser_take_screenshot, browser_console_messages, browser_network_requests, browser_click, browser_type, browser_find, browser_wait_for. Deliberately OMIT browser_run_code_unsafe, browser_evaluate, and browser_file_upload: these are arbitrary-execution/upload tools and MUST continue to prompt.

GRANULARITY IS ALREADY PROVEN EXPRESSIBLE -- DO NOT RE-RESEARCH THIS. nix/settings-fragment.json allowlists mcp__nixos__nix and mcp__nixos__nix_versions individually; lean/settings-fragment.json enumerates 21 individual mcp__lean-lsp__lean_* entries; founder's fragment likewise enumerates individual tool names. Per-tool MCP permission entries work.

'KEEP PROMPTING' NEEDS NO ask/deny RULE: omission from permissions.allow already yields a prompt. The existing permissions.deny list is Bash-only (rm -rf /, rm -rf ~, sudo *, chmod 777 *) and there is no ask key in use anywhere. Do not invent one.

THE REAL HAZARD -- INSTALL-ONCE PROPAGATION: core/root-files/settings.json deploys to .claude/settings.json under install-once semantics (loader.lua's copy_category('root_files'), gated by CATEGORY_DESCRIPTORS.root_files.install_once; manager.unload also excludes these files via loader_mod.INSTALL_ONCE_ROOT_FILES). Once a project has its own .claude/settings.json, reloading or re-loading the providing extension NEVER overwrites it. Therefore simply editing core/root-files/settings.json will NOT reach any existing project. This task must establish how the new grants actually propagate -- for example via an extension settings-fragment.json (which targets .claude/settings.local.json and is not install-once), via user-scope settings, or via a documented migration step -- consistent with the ownership boundary decided in the prerequisite task.

ACCEPTANCE: in a project that ALREADY has a .claude/settings.json, the 9 safe browser tools run without prompting, and browser_run_code_unsafe, browser_evaluate, and browser_file_upload still prompt. Verify against a pre-existing settings file, not a freshly generated one -- a fresh project would mask the install-once defect.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 23. Document MCP registration vs permission ownership boundary; reconcile lean-lsp three-way duplication
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: mcp-integration
- **Dependencies**: None
- **Research**: [023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md]
- **Plan**: [023_document_mcp_registration_ownership_boundary/plans/01_mcp-ownership-boundary.md]
- **Summary**: [023_document_mcp_registration_ownership_boundary/summaries/01_mcp-ownership-boundary-summary.md]

**Description**: Define and document the ownership boundary between the four competing MCP registration/permission mechanisms, and reconcile the existing lean-lsp three-way duplication.

PROBLEM: the agent system now has FOUR mechanisms that can register an MCP server or grant its permissions, with no documented boundary between them:
(1) A home-manager activation block writing to ~/.claude.json (user scope). This is how the playwright MCP server was registered; it is connected and healthy, exposing 24 browser_* tools.
(2) Per-extension settings-fragment.json, deployed via the manifest's settings section ({"source": "settings-fragment.json", "target": ".claude/settings.local.json"}). Used by nix (mcp-nixos plus 2 enumerated tool permissions) and lean (lean-lsp plus 21 enumerated tool permissions).
(3) core/root-files/settings.json, deployed to .claude/settings.json as INSTALL-ONCE. Currently carries a mcp__lean-lsp__* WILDCARD in permissions.allow.
(4) core/scripts/setup-lean-mcp.sh, which registers lean-lsp directly into user scope ~/.claude.json.

EVIDENCE THE PROBLEM IS REAL AND ALREADY BITING: lean-lsp is currently registered or permitted by THREE of these simultaneously (mechanisms 2, 3, and 4), and mechanisms 2 and 3 disagree about form -- the extension fragment enumerates 21 individual tools while core grants a blanket wildcard. This is precisely the duplication the playwright integration must avoid repeating.

KEY ARCHITECTURAL CONSTRAINT (already recorded in core/scripts/setup-lean-mcp.sh's own header): custom subagents CANNOT access project-scoped MCP servers (.mcp.json); user scope (~/.claude.json) is required for subagent access. Since agents are the consumers of browser tools, this argues that REGISTRATION belongs in user scope (home-manager or a setup script), while PERMISSION GRANTS must live in the settings files the host app reads. Confirm or refute this split rather than assuming it.

DELIVERABLE: a decision recorded in the source store stating which mechanism owns MCP server REGISTRATION, which owns PERMISSION grants, why, and how the two compose. Update permission-configuration.md and/or extension-system.md, adding a context pattern if warranted. Reconcile the lean-lsp wildcard-vs-enumeration split, or explicitly justify keeping it.

ACCEPTANCE: a future extension author can read one document and know where to declare a new MCP server and its permissions without creating a fifth duplicate path.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/**. Never edit any deployed .claude/** tree -- those are gitignored, disposable, and regenerated from the source store, so hand-edits there are silently wiped.
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

### 21. Vault transition comment is wiped by TODO.md regeneration, corrupts frontmatter where it runs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [021_resolve_vault_transition_comment_nondurable/reports/01_resolve-vault-transition-comment.md]
- **Plan**: [021_resolve_vault_transition_comment_nondurable/plans/01_resolve-vault-transition-comment.md]
- **Summary**: [021_resolve_vault_transition_comment_nondurable/summaries/01_resolve-vault-transition-comment-summary.md]

**Description**: /todo and skill-todo both instruct the vault path to hand-insert an HTML transition comment into specs/TODO.md, but generate-todo.sh regenerates that file wholesale, so the comment is wiped by the next regeneration. The instruction is also actively harmful where it does run: as written it corrupts the YAML frontmatter and duplicates itself. Decide the correct resolution and apply it consistently.

THE DECISION IS ALREADY ON RECORD -- this is a re-regression, not a new finding. The archived summary at
    specs/vault/01-vault/archive/653_update_task_creation_commands_state_first/summaries/01_task-creation-migration-summary.md
states under Decisions:
    "Vault transition comment: Removed the Python script that inserted HTML comments into TODO.md frontmatter. Since generate-todo.sh regenerates the entire file, vault transition info is preserved in state.json's vault_history array instead."
That earlier work removed the SCRIPT but left the PROSE INSTRUCTION in place, so the behavior was re-specified in the two live documents that callers actually follow. Treat that recorded decision as strong prior art; if the resolution chosen here differs from it, say why explicitly rather than silently diverging a second time.

MEASURED EVIDENCE (live, this investigation -- do not re-derive):

(1) The comment does not survive. A vault run inserted the documented comment after TODO.md's frontmatter; the very next state-write with --regen-todo removed it. generate-todo.sh treats TODO_FILE purely as an output target -- it is referenced only as a default path, an argument, an mktemp sibling, and the destination of `mv "$TEMP_FILE" "$TODO_FILE"`. There is no read of the existing file anywhere, so nothing hand-written into TODO.md can persist by construction.

(2) The skill's insertion corrupts the frontmatter AND double-inserts. Running skill-todo's exact sed against a real 3-line frontmatter (---, next_project_number: N, ---) produced:
    ---
    next_project_number: 20
    <!-- Vault transition: ... -->
    ---

    <!-- Vault transition: ... -->
    # TODO
The range /^---$/,/^---$/ matches the closing delimiter as well as the opening one, so `a` fires twice: once after the line following the opening --- (placing an HTML comment INSIDE the YAML block, which is not valid YAML) and once after the closing ---. Any consumer that parses TODO.md frontmatter strictly would see a malformed block.

(3) The computed task range is wrong. skill-todo derives the range as $((next_num - renumber_count - 1)). With this run's real values (next_num 1020, renumber_count 11) that yields 1008, so the comment would have claimed "tasks numbered 1 through 1008 archived" -- but the vault actually contains everything through 1015, and 1008 is not the renumbering boundary either. The number describes nothing.

LIVE SITES (both in the source store, both currently instructing the broken behavior):
  agent-system/extensions/core/commands/todo.md:893-898  (Step 5.8.9)
  agent-system/extensions/core/skills/skill-todo/SKILL.md:877-890  (the sed block)

DURABLE RECORDS THAT ALREADY EXIST (the reason deletion is viable):
  specs/state.json .vault_history[] -- {vault_number, vault_dir, created_at}
  specs/vault/{NN}-vault/meta.json -- {vault_number, created_at, archived_count, final_task_number}
Both were written correctly by the vault run that exposed this, so no information is lost today if the comment goes away.

PRECEDENT FOR THE RESOLUTION SHAPE: commands/todo.md Step 5.6.2 already documents this same overwrite property as the reason repository_health lives in state.json only and is deliberately NOT mirrored into TODO.md frontmatter. Whatever is decided here should be consistent with that existing, already-reasoned stance.

WORK -- evaluate these and pick one, recording the reasoning:
  (a) Delete the step from both live sites and rely on vault_history + meta.json. Matches the recorded decision, removes machinery, loses the at-a-glance signal in TODO.md.
  (b) Render the transition line from state.json .vault_history inside generate-todo.sh, so it is generated rather than hand-inserted and therefore survives every regeneration. Keeps a user-visible signal; costs a new rendering branch and a test.
  (c) Make generate-todo.sh preserve hand-authored comments across regeneration. Note that this contradicts the deliberate full-overwrite, atomic mktemp+mv design and would reintroduce read-modify-write; if rejected, say so rather than leaving it unconsidered.
Whichever is chosen, no live document may be left instructing a caller to hand-edit TODO.md for vault transitions.

ALSO IN SCOPE (adjacent, cheap, same section): commands/todo.md's vault section is headed "5.7. Vault Operation" while all nine of its substeps are numbered 5.8.1 through 5.8.9. Reconcile the numbering so a reader following a cross-reference to "Step 5.7" finds substeps that match.

SCOPE DECISIONS REQUIRED (state each explicitly, do not silently skip):
  - agent-system/extensions/core/scripts/deprecated/vault-operation.sh:242 carries the same comment logic but is quarantined under deprecated/. Confirm it stays untouched rather than "fixed".
  - Five .opencode/** copies carry the same instruction (.opencode/commands/todo.md, .opencode/extensions/core/commands/todo.md, .opencode/skills/skill-todo/SKILL.md, .opencode/extensions/core/skills/skill-todo/SKILL.md, .opencode/scripts/vault-operation.sh). .opencode/ has no agent-system source and is separately tracked, and separate work already covers opencode drift. Decide whether these are updated here or deferred there, and record which -- leaving five unlabeled copies of a known-broken instruction is not an acceptable outcome.

ACCEPTANCE: a vault operation followed immediately by a TODO.md regeneration leaves the file in the intended end state -- either no transition comment at all with the durable records present, or a comment that regeneration reproduces identically. specs/TODO.md's frontmatter must still parse as a closed, valid YAML block afterward; demonstrate this by parsing it, not by eyeballing. Grep the live (non-deprecated) source store for the transition-comment string and report the surviving count with justification for each survivor.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

FILE OVERLAP: separately-tracked work on the repository-metrics sync ordering also edits agent-system/extensions/core/commands/todo.md. Neither task depends on the other, but they touch the same file and should not run concurrently without re-reading it.

---

### 20. Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

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

---

### 19. Fix opencode agent-fragment path resolution and validator fail-fast
- **Effort**: 3h
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [019_fix_opencode_agent_fragment_paths/reports/01_opencode-fragment-path-fix.md]
- **Plan**: [019_fix_opencode_agent_fragment_paths/plans/01_opencode-fragment-path-fix.md]
- **Summary**: [019_fix_opencode_agent_fragment_paths/summaries/01_opencode-fragment-path-fix-summary.md]

**Description**: Reloading extensions in a consuming repo emits roughly 60 lines of "Extension '<name>' opencode-agents.json validation failed: Agent '<agent>' references missing file: <path>. Skipping fragment." The resync otherwise succeeds and the Claude Code deploy is correct and complete, so nothing the user relies on today is broken. .opencode/ is NOT currently in use, though the user intends to return to it. Priority is therefore low: the present cost is misleading reload noise, and the real cost is latent, namely that whenever OpenCode is picked back up, 18 agents will be silently missing behind noise that has already been trained into background.

MEASURED EVIDENCE (do not re-derive). In a repo with 12 active extensions, the generated opencode.json contains 15 agents and 18 are dropped: lean 2, python 2, nix 2, filetypes 7, present 5. lua/neotex/plugins/ai/shared/extensions/merge.lua:886 validate_opencode_fragment resolves each agent's {file:PATH} prompt against project_dir and returns false on the FIRST unreadable path, so generate_opencode_json discards the ENTIRE fragment.

ROOT CAUSE 1 - the referenced directory is deployed by nothing. Ten of twelve fragments use {file:.opencode/agent/subagents/<agent>.md}. A grep of the whole lua/ tree for "opencode/agent" returns exactly one hit and it is a test fixture (commands/picker/operations/sync_spec.lua:100). No deploy, install, or resync path populates .opencode/agent/subagents/ at all. The 16 files present in the consuming repo are unmaintained legacy artifacts predating the current manifest-driven engine. latex (2/2), typst (2/2), and formal (4/4) validate only by accident because their agent files happen to be among those 16 leftovers; python, nix, filetypes, and present reference correctly-named files that were simply never deployed.

ROOT CAUSE 2 - lean uses a third convention, also wrong. agent-system/extensions/lean/opencode-agents.json uses {file:.claude/extensions/lean/agents/<agent>.md}, a directory that does not exist in the deployed tree. Those files are present both at the standard .opencode/agent/subagents/ path and at .claude/agents/. Pure path bug.

ROOT CAUSE 3 - present references an agent that exists nowhere. agent-system/extensions/present/opencode-agents.json declares an agent keyed "slides" pointing at slides-agent.md. No slides-agent.md exists anywhere under agent-system/extensions/; the real file is agent-system/extensions/present/agents/slides-research-agent.md. Stale name after a rename. timeline-agent.md in the same fragment DOES exist in source - do not flag it.

AMPLIFIER. Fail-fast-on-first-miss silently discards a whole fragment for one bad reference, which is why present loses all 5 agents. Lua pairs() ordering is nondeterministic, so each validation pass names a different arbitrary agent, making the reload output look inconsistent and repetitive across passes while never revealing the true count. The task must decide whether the validator changes to report ALL missing references per fragment.

DECISION REQUIRED - evaluate explicitly, do not treat any as pre-chosen: (a) repoint every fragment's {file:...} at .claude/agents/<agent>.md; (b) add a deploy step that populates .opencode/agent/subagents/; (c) gate opencode fragment processing off entirely while .opencode/ is dormant, so the noise stops without committing to a path convention that may be revisited when OpenCode returns; (d) some combination. Option (a) is the scouted recommendation but is not a fait accompli: .claude/agents/ IS deployed and maintained by the current engine and contains all 48 agents including every one currently reported missing (verified individually for python-implementation, nix-research, filetypes-router, funds, lean-implementation, slides-research, timeline), so repointing fixes all three root causes with no new deploy step and no duplicated copies. Option (c) is live precisely because .opencode/ is dormant. Whatever is chosen must handle the present/slides stale name and must state a verdict on the validator's fail-fast behavior.

CONSTRAINT. Do NOT delete .opencode/ or its fragments - the user intends to return to OpenCode.

ACCEPTANCE. A reload in a consuming repo with 12 active extensions produces no opencode fragment validation errors; the chosen approach is stated with its rationale against the rejected alternatives; the present/slides stale reference is resolved; and the validator's fail-fast-vs-report-all behavior has an explicit recorded decision.

SOURCE-STORE RULE (binding): edit agent-system/extensions/** and lua/**, never .claude/** or .opencode/**, which are disposable deploy artifacts.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 18. Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Effort**: 5h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 16, Task 35, Task 37

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

### 16. Fix command register acquire session id parity
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestration-concurrency
- **Dependencies**: None
- **Research**: [016_fix_command_register_acquire_session_id_parity/reports/01_register-acquire-session-id-parity.md]
- **Plan**: [016_fix_command_register_acquire_session_id_parity/plans/01_register-acquire-parity-fix.md]
- **Summary**: [016_fix_command_register_acquire_session_id_parity/summaries/01_register-acquire-parity-fix-summary.md]

**Description**: Fix the register-bare/acquire-suffixed session-id pattern in the research.md, plan.md, and implement.md command files.

TARGET: agent-system/extensions/core/commands/research.md, agent-system/extensions/core/commands/plan.md, agent-system/extensions/core/commands/implement.md.

CONTEXT: skill-orchestrate/SKILL.md carried a defect where the in-flight session registry was registered under the bare session_id but the per-task lock was acquired and released under a task-suffixed variant. Because the session-contention self-exclusion is an exact string match, the batch never recognized its own registration and every acquire aborted deterministically. That defect was fixed in skill-orchestrate, and the fix recorded that these three multi-task command files exhibit the structurally identical register-bare/acquire-suffixed pattern and are likely to carry the same latent bug.

WORK: verify whether each of the three command files actually reproduces the defect (the registration site, the acquire/release sites, and any dispatch context whose session_id feeds a downstream task-lock heartbeat call). Unify the session-id used across register/acquire/release/heartbeat in each file that is affected. Extend the existing register/acquire parity regression coverage to cover these consumers rather than adding a parallel test harness.

REFERENCE: the parity invariant is stated in agent-system/extensions/core/context/patterns/task-lock.md (Consumers section); the existing regression group lives in agent-system/extensions/core/scripts/test-conflict-predicate.sh.

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

### 12. Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and 6 further suites
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md]
- **Plan**: [012_fix_test_suite_deployed_mode_failures/plans/02_gate8-and-verify-deploy-closeout.md]
- **Summary**: [012_fix_test_suite_deployed_mode_failures/summaries/02_gate8-and-verify-deploy-closeout-summary.md]

**Description**: tests/run-all.sh is red and has been treated as permanently-expected background noise, which is how a real regression would hide. This task makes it green or documents each residual failure.

MEASURED EVIDENCE (live run, not inherited): 25 passed, 8 FAILED, 0 skipped, 33 total. Earlier reports of a 5-suite REPO_ROOT count were NOT confirmed and should be treated as superseded by this measurement. Recorded as err_1786368358319_8jwcdo.

CONFIRMED ROOT CAUSE (2 of 8): test-skill-base-lifecycle.sh and test-update-task-status.sh both abort with
    ERROR: deployed scripts tree not found at /home/benjamin/.claude/scripts
proving REPO_ROOT resolved to $HOME instead of the repo root. Both derive it as:
    REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
Five levels up is correct from the SOURCE-STORE location agent-system/extensions/core/scripts/tests/, but wrong from the DEPLOYED location .claude/scripts/tests/, which is only three levels below the repo root. The same 5-level literal appears in at least test-corroborate-phase-counts.sh, test-errors-append.sh, test-handoff-reader-parity.sh, and test-index-entries-schema.sh, so the defect class is wider than the two suites that happen to fail loudly.

PROVEN-GOOD PATTERN ALREADY IN-TREE: test-deploy-propagation.sh derives it depth-independently:
    REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
    [ -z "$REPO_ROOT" ] && REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
Adopt this shape rather than inventing a new one.

UNCONFIRMED (6 of 8) - triage each individually, do NOT assume a shared cause:
  test-common-lib.sh (1 failure; overlaps the separately-tracked opencode session-id duplication finding)
  test-index-entries-schema.sh (8 passed, 1 failed)
  test-lint-state-writer-boundary.sh (7 passed, 1 failed)
  test-loop-guard-staleness.sh
  test-reconcile-handoff-status.sh
  test-resume-scan-nonconformance.sh

NOTABLE: test-lint-state-writer-boundary.sh is the suite added by the state-writer conversion work, which reported 8/8 green in source-store context but is 7/8 in deployed mode. Determine whether this is the same depth defect or a genuine gap in the new lint.

ACCEPTANCE: run-all.sh reports 0 failures, OR every residual failure has a written, evidenced justification. Report the count honestly; never an unqualified green.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
=== SCOPE EXTENSION (folded in after gate-8 diagnosis; user-approved) ===

The Phase 6 residual is now diagnosed with captured evidence, and TWO items are folded into
this task rather than spawned separately.

(A) GATE-8 FLAKE -- ROOT CAUSE CONFIRMED, not a hypothesis. Measured 4/20 (20%) failures inside
verify-deploy.sh gate 8; 13/30 (43%) standalone on an idle machine; 25/30 (83%) in a mirror
copy. All four captured gate-8 failures are byte-identical apart from PID:
  [FAIL] is_live_inhibitor_target: still excludes the SAME inhibitor after its target
  (pid NNNNNNN) was killed -- tautological check
in agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh (assertion (c)).
Mechanism proven directly: kill -0 returns success for a killed-but-unreaped child; wait reaps
in 2ms. Failing runs averaged 141.5s vs 131.0s passing -- a 10.5s delta against the 8.0s poll
budget, i.e. every failure burns the full 40 x 0.2s loop.
  RULED OUT: task-lock.sh / holder.json TOCTOU. Zero occurrences across all 20 runs.
  CORRECTED ASSUMPTIONS: the flake is NOT load-sensitive (43% on an idle machine; CPU burners
  did not reproduce it). Widening the poll budget is DISPROVEN as a fix -- no finite budget
  helps a 43-83% failure, and the helper sometimes genuinely survives the kill, so widening
  only makes each failure slower. Two real-process repairs also failed under test: naive wait
  hung ~300s (the suite leaks a `sleep 300` helper inheriting stdout/stderr, so any reader
  using command substitution blocks for the full 300s -- one run measured 300022ms), and
  kill -9 + wait + detached streams killed the test script itself (RC=137, 20/20).
  REQUIRED FIX (injectable predicate, not budget widening): extract the bare
  kill -0 "$target_pid" in agent-system/extensions/core/scripts/claude-refresh.sh's
  is_live_inhibitor_target (lines ~138-149) into an overridable seam (e.g. _pid_is_alive), and
  replace lines ~112-145 of test-claude-refresh-matcher.sh (helper at 112, kill at 123, poll
  loop at 135-138, failing assertion at 140-144) with a scripted probe. Keep the "alive"
  direction as-is (deterministic; no reaping involved). This preserves the argv-parsing
  coverage the assertion exists to protect. NOTE: it does weaken the file's documented
  "driven by a REAL process" intent (line ~15) -- record that trade-off in the replacement
  comment rather than leaving it silent.

(B) STANDING VERIFY-DEPLOY FAILURES -- verify-deploy.sh exited non-zero on 20/20 runs
INDEPENDENT of gate 8, so fixing gate 8 alone will NOT turn it green. Phase 6's acceptance
criterion cannot be met without these:
  - Deploy drift (gates 3 and 5): agent-system/extensions/core/scripts/system-defect-record.sh
    (source 354 lines / deployed 352) and
    agent-system/extensions/core/context/patterns/system-defect-discrimination.md
    (source 397 / deployed 382). Source is AHEAD of deploy; a deploy-headless.sh run resolves
    both.
  - line_count mismatch (gate 3, Rule R): agent-system/extensions/core/index-entries.json
    (~line 1034) declares line_count 382 for patterns/system-defect-discrimination.md; the
    actual file is 397 lines. generate-context-line-counts.sh --write is the sanctioned fixer.
  - Dangling dependency (gate 10): specs/state.json task 9 carries dependencies [1015, 18].
    1015 exists in NEITHER active_projects NOR the archive, and neither does 15 -- it is a
    vault-renumbering leftover (renumbering subtracted 1000 from project_number values but did
    not rewrite dependencies arrays). Removing the dead 1015 entry is the honest fix; do not
    invent a replacement target.

ACCEPTANCE (revised): verify-deploy.sh reports 0 findings across a repeated sample (not a
single lucky run -- the flake was 20% inside gate 8, so a single green run is not evidence),
OR every residual failure carries a written, evidenced justification. Report counts honestly;
never an unqualified green.

---

### 11. Expand defect class vocabulary
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [011_expand_defect_class_vocabulary/reports/01_defect-class-vocabulary-gap.md]
- **Plan**: [011_expand_defect_class_vocabulary/plans/01_defect-class-vocabulary-expansion.md]
- **Summary**: [011_expand_defect_class_vocabulary/summaries/01_defect-class-vocabulary-expansion-summary.md]

**Description**: The system-defect vocabulary has a gap: defect classes exist for a narrow set of shapes, but at least three concrete instances from this batch do not fit cleanly into any existing defect_class value. Recorded as err_1786349061588_fqHbUZ, severity medium. Three concrete instances now ground the gap, confirmed by the capstone acceptance gate dispatch: lock/session contention (err_1786349061524_pY97cE, MT-1/MT-4 session-id mismatch), hook-regex/path-depth boundary defects (err_1786349061492_XpY38x, the 3-digit handoff-location regex), and deploy orphan-file drift (err_1786349061556_LuKGif / err_1786350581273_TAWj0I).

TARGET: wherever defect_class is enumerated for system-defect-record.sh (search the source store for its schema/enum definition) and any consumer that switches on defect_class value.

WORK: read the current defect_class enum, confirm the three instances above genuinely lack a fitting class (do not add classes for shapes that already have one), and add the minimum set of new classes needed to name them precisely -- for example a session/lock-contention class, a regex/path-boundary class, and an orphan-drift class. Update any documentation enumerating the vocabulary. Do not rename or remove existing classes as part of this task.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

---

### 9. Resolve deploy orphan file parity
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 18

**Description**: Declared-vs-deployed parity for provides.* categories is one-directional by design, and the live .claude/ tree carries 4 orphan files absent from a clean scratch regenerate: context/orchestration/orchestration-validation.md, context/orchestration/subagent-validation.md, docs/architecture/architecture-spec.md, docs/README.md. Two of these (docs/architecture/architecture-spec.md, docs/README.md) were not covered by the pre-existing err_1786349061556_LuKGif (deploy_ghost_index_entries), which only named the other two -- confirmed and extended by err_1786350581273_TAWj0I (deploy_orphan_files_undercounted). This task covers BOTH error ids with one decision; do not split it.

MECHANICAL REASON (already diagnosed, do not re-derive): verify.lua's result shape has no extra/orphan field and only ever iterates the declared side; install-extension.sh's merge_index_entries() is purely additive with no stale-removal step. Parity is therefore verified only in the declared-to-deployed direction, never the reverse.

TARGET: agent-system/extensions/core/scripts/verify-deploy.sh (or the shared verify.lua module it calls), and/or docs/architecture/architecture-spec.md if the decision is to document one-directional parity as intended rather than build detection.

WORK: decide ONE of two directions and implement it -- (a) add a subtractive/orphan-detection pass to verify.lua or verify-deploy.sh that flags live files present in .claude/ but absent from a clean regenerate of every provides.* category, so future orphan drift is caught mechanically; or (b) explicitly document in docs/architecture/architecture-spec.md that provides.* parity is one-directional by design (additive only, no stale-removal), so a future reader does not mistake the current behavior for an oversight. Resolve the 4 currently-orphaned files as part of whichever direction is chosen: either they get removed/reconciled (direction a) or explicitly enumerated as accepted legacy orphans in the documentation (direction b).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

CONSTRAINT: do not drive this task with multi-task /orchestrate until err_1786349061524_pY97cE (the MT-1/MT-4 session-id mismatch, spawned as a sibling task) is fixed -- multi-task orchestration is documented-broken until that lands. Use single-task /orchestrate or /implement.

STALENESS CAVEAT (added after the deploy-staleness finding): the orphan-file measurement above (4 files present in .claude/ but absent from a clean scratch regenerate) was taken against a deploy tree since shown to be badly stale -- its task-lock.sh was 676 lines against a 1660-line source. That measurement may therefore be an artifact of the staleness rather than evidence of a one-directional parity gap. Re-take the measurement against a freshly regenerated tree before treating it as evidence, and revise the direction (a)/(b) decision if the orphan set changes. Depends on task 18, which diagnoses the staleness root cause.

---

### 6. Nothing prevents an agent from rewriting state.json .artifacts wholesale, silently discarding prior artifacts
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 5
- **Research**: [006_guard_against_nonadditive_artifact_rewrites/reports/01_guard-nonadditive-artifact-rewrites.md]
- **Plan**: [006_guard_against_nonadditive_artifact_rewrites/plans/01_guard-nonadditive-artifact-rewrites.md]
- **Summary**: [006_guard_against_nonadditive_artifact_rewrites/summaries/01_guard-nonadditive-artifact-rewrites-summary.md]

**Description**: The artifact list in specs/state.json is append-only by intent but not by enforcement. Every
sanctioned write path is additive, yet an agent that writes state.json directly can replace the
whole array, and nothing detects the loss.

SANCTIONED PATHS ARE ALREADY CORRECT (do not change them):
  - agent-system/extensions/core/scripts/orchestrator-postflight.sh:432 uses `.artifacts += [...]`
  - agent-system/extensions/core/scripts/reconcile-task-status.sh:172 (link_artifact) likewise
  - skill_link_artifacts in skill-base.sh routes through state-write.sh

THE GAP: these are helpers an agent MAY use, not a constraint it MUST satisfy. An implementation
agent updating state.json with its own jq assignment (`.artifacts = [...]`) bypasses all of them.
Nothing validates that the post-write artifact set is a superset of the pre-write set.

OBSERVED, WITH LOSS: during a real implementation dispatch, an agent updated its task's state.json
entry and the artifact list went from 11 entries to 8 -- five previously-recorded phase summaries
were dropped while two new entries were added. The summary FILES were still on disk; only the
links were destroyed, so nothing failed and no warning was emitted. The loss was caught only by a
manual count during postflight review and repaired by hand. Had it not been noticed, the task
would have archived with five phase summaries permanently unreferenced.

RELATIONSHIP TO THE STATE-WRITE CONVERSION TASK (adjacent, NOT duplicate -- read before starting):
the existing state-write conversion work targets hand-rolled read-modify-write sequences in the
SOURCE STORE, and its verification bar is a grep for `mv` onto state.json across source files.
That bar cannot catch this defect: the offending write came from an AGENT at runtime composing jq
inline, not from any checked-in script. Converting every source-store writer to state-write.sh
leaves this hole exactly as open. If the two are worked together, the deliverable here is the
superset-invariant, not another writer conversion.

WORK:
  1. Add a machine-checkable invariant: for any write touching .artifacts, the resulting set must
     contain every path present beforehand. Removal must require an explicit, named opt-in
     (legitimate cases exist -- a genuinely deleted artifact -- and must remain expressible).
  2. Enforce it where writes actually funnel. state-write.sh is the natural choke point; decide
     whether the invariant lives there (catches everything routed through it) or in
     validate-state.sh (catches drift regardless of writer, including direct jq). Prefer the
     option that ALSO catches a direct jq write, since that is the observed failure mode --
     enforcing only inside state-write.sh would miss the exact case that motivated this task.
  3. State the append-only rule explicitly in rules/state-management.md, which currently
     describes artifact linking formats without ever saying the list is append-only.
  4. Add a MUST NOT to the implementation agents that write state.json directly: never assign
     .artifacts wholesale; append, or call the helper.

VERIFICATION BAR:
  - A fixture write that drops an existing artifact path is REJECTED (or loudly flagged by the
    validator), and the same write with the opt-in flag is accepted. Both directions executed.
  - A normal additive link still succeeds unchanged; existing link_artifact / skill_link_artifacts
    call sites are unaffected.
  - The check triggers on a direct jq-composed write, not only on state-write.sh traffic.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 5. roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [005_implement_roadmap_items_producer/reports/01_roadmap-items-producer.md]
- **Plan**: [005_implement_roadmap_items_producer/plans/01_roadmap-items-producer.md]
- **Summary**: [005_implement_roadmap_items_producer/summaries/01_roadmap-items-producer-summary.md]

**Description**: /todo documents a producer/consumer contract for ROADMAP.md synchronisation in which /implement
is the producer. The consumer half is fully built; the producer half computes nothing, so the
feature has never functioned.

WHAT EXISTS (the consumer and the write path -- both fine, do not rebuild):
  - agent-system/extensions/core/commands/todo.md:1122 states the contract explicitly:
    "/implement is the **producer**: populates completion_summary and optional roadmap_items".
  - todo.md's Step 3.5 matcher implements a three-priority strategy: (1) explicit roadmap_items,
    (2) exact `(Task N)` references in ROADMAP.md, (3) summary-based search.
  - skill_propagate_completion_summary (agent-system/extensions/core/scripts/skill-base.sh:526-551)
    WRITES roadmap_items to state.json correctly when handed a non-empty value, routed through
    state-write.sh, correctly skipping task_type == "meta" and empty/`[]` values.

WHAT IS MISSING: nothing anywhere DERIVES the value passed as that third argument. Grep of the
full source store finds write sites and schema references but no derivation logic. So the helper
is called with an empty value and the write is skipped every time.

CONSEQUENCE, MEASURED: on a real archival run, 24 consecutive completed tasks were archived and
produced ZERO roadmap annotations, while 8 unchecked items sat in ROADMAP.md -- several plainly
related to the work just completed. All three matcher priorities missed:
  - Priority 1 found no task carrying a roadmap_items field (none has ever been populated).
  - Priority 2 found no `(Task N)` references, because ROADMAP.md contains none -- and per the
    repo's own no-task-references-in-deliverables rule, ROADMAP.md arguably should not contain
    them, which makes Priority 2 structurally unreliable rather than merely unused.
  - Priority 3 is an explicit unimplemented placeholder in todo.md ("not currently implemented").
So the roadmap silently drifts from reality, and the drift is invisible: /todo reports success
with "0 roadmap items updated" and no warning that its only functioning matcher found nothing.

WORK:
  1. Decide where derivation belongs and state why. Candidates: the implementation agent proposes
     roadmap_items in its return metadata (agent judgement, no new matching machinery); or a
     script matches completion_summary against ROADMAP.md text at postflight (deterministic,
     testable, but needs a matching heuristic that Priority 3 was never given).
     Prefer the option that does not invent a fuzzy matcher -- an agent naming which roadmap
     items its work closed is both cheaper and more accurate than post-hoc string similarity.
  2. Implement derivation on the chosen path and thread it into the EXISTING
     skill_propagate_completion_summary call sites. Do not add a second write path.
  3. Make an empty result visible rather than silent: when /todo archives non-meta tasks and
     matches zero roadmap items, it must say so distinctly from "there was nothing to match".
     A silent 0 is what allowed this to go unnoticed across 24 tasks.
  4. Either implement Priority 3 or delete it. A documented placeholder that reads as a working
     tier is worse than an honest two-tier matcher.
  5. Reconcile Priority 2 with the no-task-references-in-deliverables rule. If `(Task N)` markers
     are not permitted in ROADMAP.md, say so in todo.md and stop presenting Priority 2 as a
     general mechanism.

VERIFICATION BAR:
  - A completed non-meta task with a roadmap-related completion_summary produces a populated
    roadmap_items in state.json, and a subsequent /todo run annotates the matching ROADMAP.md
    item. Demonstrated end to end on a fixture, not argued.
  - A task whose work matches no roadmap item produces an explicit "no match" report.
  - task_type == "meta" still writes no roadmap_items (existing behaviour preserved).

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
