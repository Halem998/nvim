---
next_project_number: 885
---

# TODO

## Task Order

*Updated 2026-07-15. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 873,874,876,877,880,882,883,884 | -- | agent-system, commit-scoping-concurrency, extensions, ... |
| 2 | 875,878,881 | 873,877,880 | agent-system, commit-scoping-concurrency, status-marker-lifecycle |
| 3 | 879 | 876,878 | status-marker-lifecycle |

**Grouped by Topic** (indented = depends on parent):

### Agent System

873 [NOT STARTED] — Make /meta create tasks in the GLOBAL agent-system root by defaul
  └─ 875 [NOT STARTED] — Update meta-builder-agent so it operates correctly at a resolved 

### Commit Scoping Concurrency

880 [NOT STARTED] — The whole targeted-staging contract - the mechanism that makes th
  └─ 881 [NOT STARTED] — Four of five implementation agents never report what they touched
882 [NOT STARTED] — RESEARCH-FIRST BY EXPLICIT USER DECISION. This task must NOT lock
883 [NOT STARTED] — The staging contract written to avoid committing unrelated state 
884 [NOT STARTED] — The staging prohibition is prose-only. Three documents forbid `gi

### Extensions

874 [NOT STARTED] — Remove or rework the stale self-sync guard that prevents the nvim

### Status Marker Lifecycle

876 [NOT STARTED] — HIGHEST-VALUE FIX for the reported symptom 'tasks say PLANNED whe
  └─ 879 [NOT STARTED] — A purpose-built self-healing script for EXACTLY the reported fail
877 [NOT STARTED] — The status-writing script and the plan format spec disagree on MO
  └─ 878 [NOT STARTED] — Addresses the 'plan says NOT STARTED while it is being worked on 
    └─ 879 [NOT STARTED] — A purpose-built self-healing script for EXACTLY the reported fail (see above)

## Tasks

### 884. Extend the existing git guard hook to block over-staging
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: commit-scoping-concurrency
- **Dependencies**: None

**Description**: The staging prohibition is prose-only. Three documents forbid `git add -A` but nothing enforces it, so the rule holds only as long as every agent chooses to read and obey it.

VERIFIED EVIDENCE:
- The POLICY is already good and needs no rewrite: context/standards/git-staging-scope.md is canonical, mandates per-operation scope, states the fail-safe direction 'Under-stage, never over-stage' (:50), and forbids `git add -A` / `git add .` / `git commit -am` (:110-112). Echoed at rules/git-workflow.md:117-121 and skill-git-workflow/SKILL.md:140-142.
- The two-layer enforcement pattern ALREADY EXISTS AND IS PROVEN IN THIS REPO: guard-destructive-git.sh is registered as a PreToolUse hook in settings.json and successfully blocks destructive git (reset --hard etc.). This is the same shape as the email extension's mail-guard.sh.
- THE GAP: nothing blocks over-staging. The one enforcement mechanism that exists guards destruction but not scope.

REQUIRED: extend the EXISTING guard-destructive-git.sh rather than adding a new hook (the user explicitly asked for 'not too many' scripts, and a second git-guarding PreToolUse hook would be the third place git policy lives). Block `git add -A`, `git add .`, and `git commit -am` at the tool boundary.

MANDATORY EXEMPTION - do not break this: git-snapshot.sh:150 contains the ONLY `git add -A` in executable code and it is DEFENSIBLE. It runs only in --branch mode against a throwaway `wip-snapshot-${TS}` scratch branch, never the working branch. Verified. Do NOT remove it; the guard MUST exempt this sanctioned path. Research must determine how the hook can distinguish it (the hook sees the tool call, not the caller, so this is the genuinely hard part of the task and may constrain the design).

ALSO IN SCOPE - two prose contradictions to reconcile so the docs stop teaching the thing the hook will now block:
- skills/skill-project-overview/SKILL.md:435 prescribes `git add specs/ .claude/`, the widest non-`-A` prescription in the system.
- context/orchestration/postflight-pattern.md:228 and :247 advise 'Manual fix: git add . && git commit', directly contradicting git-staging-scope.md:110-112.

CONSTRAINT: extend the existing hook; do not create a new one.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 883. Stop committing ephemeral lock and session state
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: commit-scoping-concurrency
- **Dependencies**: None

**Description**: The staging contract written to avoid committing unrelated state is itself committing session-scoped mutex state. Small, self-contained, no dependencies.

VERIFIED EVIDENCE:
- .gitignore covers `**/.return-meta.json` (:1) and `**/.git-snapshot-marker` (:19), but NOT `.lock/` and NOT `.orchestrator-multi-state.json`.
- Because orchestrator-postflight.sh:335 stages the task directory WHOLESALE (`"${task_dir}/"`), it necessarily sweeps in ${task_dir}/.lock/holder.json. The wholesale directory stage is the reason ephemeral state gets committed; note this when deciding the fix.
- Already tracked in git RIGHT NOW (verified `git ls-files`): specs/860_enforce_plan_compliance_rule/.lock/holder.json and specs/archive/856_scrub_task_number_leaks_from_wrapper_contracts/.lock/holder.json - the latter was ARCHIVED WHILE STILL HELD, which is a lock that can never be released.
- The .gitignore pattern `**/.return-meta.json` does NOT match `.return-meta-multi.json`. Verified: specs/.return-meta-multi.json IS tracked today. Also in scope.

LIVE EMPIRICAL PROOF - commit b42aa5aec ('orchestrate tasks 869-872: complete orchestration'): a single commit spanning FOUR distinct tasks that committed the DELETION of three ephemeral lock files (specs/869_unified_event_reflection_store/.lock/holder.json, specs/871_completion_time_reflective_harvest/.lock/holder.json, specs/872_distill_review_revise_dream_mode/.lock/holder.json) plus specs/.return-meta-multi.json and specs/state.json. Verified via `git show --stat b42aa5aec`. This is no longer hypothetical.

REQUIRED: add .gitignore entries covering .lock/ directories, .orchestrator-multi-state.json, and the .return-meta-multi.json / .return-meta-*.json family; then `git rm --cached` the already-tracked instances. Research should enumerate the full set of ephemeral session artifacts under specs/ rather than fixing only the four named here - .orchestrator-handoff.json is a candidate to evaluate (it may be a deliberate durable handoff rather than ephemeral, so do not blanket-ignore it without deciding).

CONSTRAINT: no new scripts.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 882. Decide whether shared-index commits need serialization (research-first)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: commit-scoping-concurrency
- **Dependencies**: None

**Description**: RESEARCH-FIRST BY EXPLICIT USER DECISION. This task must NOT lock in an approach before research settles the open question below. Do not treat serialization as the foregone conclusion.

THE MECHANISM (verified) - this is precisely how a concurrent session's work 'rides along' in another session's push:
- Task-scoped staging structurally CANNOT isolate the two SHARED GLOBAL files that every task's postflight stages: specs/TODO.md and specs/state.json (orchestrator-postflight.sh:335 sets stage_paths=(task_dir/ specs/TODO.md specs/state.json)).
- generate-todo.sh regenerates TODO.md WHOLESALE from all active_projects (atomic mktemp+mv, :421-423) and reads ONLY state.json.
- Therefore if session A updates state.json for its task and session B then runs generate-todo.sh + `git add specs/TODO.md specs/state.json`, session B's commit NECESSARILY contains session A's rows. That is the reported 'rode along' exactly.
- task-lock.sh CANNOT prevent this: it is PER-TASK (specs/{NNN}_{SLUG}/.lock/), so two sessions on DIFFERENT tasks never exclude each other; and task-lock.md:262 explicitly states a lock holder 'still checkpoints/commits exactly as before - the lock only adds' mutual exclusion. It does not gate commits.

OPEN QUESTION - RESEARCH MUST SETTLE, DO NOT PRE-RESOLVE:
Is cross-session mixing of TODO.md/state.json actually a defect worth serializing, or is it benign? The case that it is BENIGN: both are DERIVED INDEX files. TODO.md is regenerated wholesale from state.json every time, so a 'mixed' TODO.md is not corrupt - it is simply current. state.json rows for other tasks are also current, not wrong. On this reading only SOURCE and ARTIFACT isolation matter, the observed commits are cosmetically noisy but semantically correct, and adding a mutex to the commit path is unnecessary complexity on a hot path. The case that it is a DEFECT: it makes commits non-atomic w.r.t. review, makes `git log -- <task dir>` misleading about who did what, and means a revert of one task's commit silently reverts another task's index rows.
Research must decide, and must weigh a THIRD option: leave commits mixed but make them HONEST (e.g. accurate commit messages naming all tasks whose rows are included), rather than serializing.

IF AND ONLY IF research concludes serialization is warranted: a reusable primitive ALREADY EXISTS and must be reused rather than reinvented - task-lock.sh:215-245 acquire_scope_mutex/release_scope_mutex, a POSIX-atomic mkdir-based global mutex at specs/.scope-lock, SCOPE_MUTEX_STALE_SEC=10, 5s timeout, fails closed. Note it is currently an INTERNAL function with no CLI surface (task-lock.sh dispatches only acquire/heartbeat/release/check/init-marker), so exposing it is part of the work. The window to serialize is read-state -> regenerate-TODO -> stage -> commit.

LIVE EVIDENCE THAT THE COLLISION IS REAL AND ONGOING: while these very tasks were being created, a concurrent /meta session claimed task numbers 873-875 (commit aeef5a4a7) from specs/state.json, forcing this batch to renumber to 876-884. The shared-index race is not hypothetical; it fired during the creation of its own fix.

CONSTRAINT: strongly prefer reusing acquire_scope_mutex over any new script.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 881. Make the four silent implementation agents emit modified_files
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: commit-scoping-concurrency
- **Dependencies**: Task 880

**Description**: Four of five implementation agents never report what they touched, so targeted staging has nothing to stage and their source changes are silently never committed. This is a direct cause of 'the system did not commit the work it actually did'.

VERIFIED EVIDENCE:
- EMITS (the only one): general-implementation-agent.md. It has a complete working chain worth copying: objectives[].files_touched (:141, :156) -> Stage 6 dedup (:390-399) -> .return-meta.json.
- MISSING (all four): email-implementation-agent.md, general-implementation-hard-agent.md, neovim-implementation-agent.md, nix-implementation-agent.md. Verified: `grep -rl modified_files .claude/agents/` returns general-implementation-agent.md and nothing else.
- CONSEQUENCE: for those four, modified_files is always empty -> orchestrator-postflight.sh:354 warns 'staged 0 files' -> the fallback path fires -> real source edits are never committed. Note general-implementation-hard-agent is among the silent four, so HARD MODE - the mode reached for on the most complex, highest-stakes work - is currently the least likely to commit its own output.

REQUIRED: replicate the working emit chain into all four agents, conforming to the schema defined by the schema-documentation task (this task's dependency). Prefer factoring the shared contract into context rather than copy-pasting the same prose into five agent files - the copy-paste is what let four of five drift in the first place; research should evaluate whether a shared @-referenced context fragment is the better carrier.

VERIFICATION: the acceptance test is behavioral, not textual - a run of each agent must produce a non-empty modified_files that orchestrator-postflight.sh actually stages. Do not accept 'the prose was added' as done.

DEPENDS ON the schema-documentation task: conform to a written schema, do not invent a second one.

CONSTRAINT: no new scripts.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 880. Document the modified_files/files_touched schema that targeted staging depends on
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: commit-scoping-concurrency
- **Dependencies**: None

**Description**: The whole targeted-staging contract - the mechanism that makes the system 'commit the work it has actually done, instead of committing all' - rests on a field that is documented NOWHERE. This is a dangling reference and it must be closed before any agent is asked to emit the field.

VERIFIED EVIDENCE:
- `grep -c modified_files .claude/context/formats/return-metadata-file.md` -> 0
- `grep -c files_touched .claude/context/formats/progress-file.md` -> 0
- Yet FOUR documents cite exactly those two files as the schema authority: git-staging-scope.md:133-134, skill-git-workflow/SKILL.md:106 and :115, general-implementation-agent.md:394.
- CONSEQUENCE: an agent that dutifully reads the cited schema doc to learn the format will never learn to emit modified_files, and will silently trigger the under-stage warning path (orchestrator-postflight.sh:354) on every single run. Its source changes are then never committed.

REQUIRED: document `modified_files` in return-metadata-file.md and `files_touched` in progress-file.md - type, semantics, path form (absolute vs repo-relative - orchestrator-postflight.sh:348 consumes them via `jq -r '.modified_files[]? // empty'` and passes them to `git add`, so the path convention is load-bearing and must be stated, not implied), whether directories are permitted, and behavior on empty.

CRITICAL DISTINCTION TO DOCUMENT: these fields are RETROSPECTIVE (what an agent actually touched) and must not be confused with `file_scope` in state.json, which is PROSPECTIVE (what a task is declared to touch, used for lock overlap detection). The two are already contrasted at context/reference/state-management-schema.md:220-223; make that contrast explicit in the schema docs so future agents do not conflate them.

ALSO IN SCOPE - unrelated dangling-doc-link fix, folded in here because it is the same class of defect (a doc citing a path that does not exist): .claude/context/project/neovim/guides/neovim-integration.md lines 333-334 link to `../../../../../../.claude/docs/guides/permission-configuration.md` and `../../../../../../.claude/docs/guides/user-guide.md`. That six-level-up path no longer resolves. This repo has its OWN copies of both targets at .claude/docs/guides/ (both verified present). Repoint the two links inward.

BLOCKS the agent-emitter task: the schema must exist before four agents are told to conform to it.

CONSTRAINT: no new scripts; documentation only.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 879. Wire reconcile-task-status.sh, which was built for this failure and never called
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: Task 876, Task 878

**Description**: A purpose-built self-healing script for EXACTLY the reported failure mode already exists and has zero callers. Wiring it is the durable safety net for when the preflight/phase-marker fixes are bypassed by some future path.

VERIFIED EVIDENCE:
- reconcile-task-status.sh's own header states it is 'Self-healing reconciliation for stuck tasks... detects tasks stuck in in-flight states when artifacts already exist, then replays the missed postflight.' That is a precise description of the user's complaint.
- It has ZERO callers. Verified: the only non-self reference anywhere under .claude/ is extensions/core/manifest.json:122, which is a DEPLOY MANIFEST LISTING (it copies the file into place), not an invocation. The script is deployed and dead.

REQUIRED: give it a caller. Research must choose the trigger point and justify it. Candidates: /orchestrate entry (self-heal a task stranded by a previous crashed run before deciding the next state), skill-todo preflight (reconcile before archiving, so desynced tasks are not archived stale - note an archived-while-still-held lock has already been observed), and/or an explicit /task --sync path. Evaluate whether reconciliation should be automatic or report-only-then-confirm; silent auto-repair of state is itself a visibility risk and the user is explicitly asking for MORE visibility, not more silent mutation.

ALSO EVALUATE: whether the reconcile pass should compare plan-file markers against state.json. generate-todo.sh reads ONLY state.json and never plan files, so plan-vs-state divergence currently has no detector anywhere in the system. This script is the natural home for that check.

DEPENDS ON the preflight-wiring and status-hardening tasks: this is the net that catches what they miss, so it should be specified against their post-fix behavior rather than today's. Shares skill-orchestrate/SKILL.md with the preflight-wiring task (file overlap -> serialized).

CONSTRAINT: no new scripts; wire the one that exists.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 878. Harden the status scripts and give phase markers a real owner
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: Task 877

**Description**: Addresses the 'plan says NOT STARTED while it is being worked on or even after it is completed' half of the report. Four defects in three existing scripts, plus one never-wired script. NO NEW SCRIPTS.

DEFECT A - PHASE MARKERS HAVE NO OWNING MECHANISM:
- Every plan is BORN with all phases [NOT STARTED] (plan-format.md:173,180), so markers are only ever correct if something actively advances them.
- update-task-status.sh:260-287 advances ONLY THE FIRST [NOT STARTED] phase (`grep -m1` at :277). Phases 2..N are never touched by any script. This is the exact signature of the observed 'first phase COMPLETED, rest NOT STARTED' desync class.
- The base agent (general-implementation-agent.md:123-126, 228-231) instructs the LLM to HAND-EDIT the heading via the Edit tool. That is a prompt instruction, not code: it fails silently when the model skips it or the string does not match.
- Only general-implementation-hard-agent.md (:155,171,233) calls update-phase-status.sh. The base agent has ZERO references to it.
- HARD PROOF IT HAS NEVER RUN: update-phase-status.sh:116 logs every transition to .agent-logs/phase-transitions.log. That directory is live and actively written (generate-todo.log, sessions.log, subagent-postflight.log all written today) but phase-transitions.log DOES NOT EXIST. The script has never completed a single transition in this working tree.
=> Wire update-phase-status.sh into the base implementation agent so phase advancement is mechanical, and make the advance cover all phases rather than only the first.

DEFECT B - EVERY FAILURE IS SILENT:
- update-task-status.sh:256-258,280-283 swallow plan/phase errors as warnings; :209-211 treats TODO.md regeneration failure as a warning.
- update-plan-status.sh:58 uses sed against a `^- \*\*Status\*\*:` anchor and silently no-ops when the anchor is missing.
- Net effect: state.json marches to completed while the plan records nothing. generate-todo.sh reads ONLY state.json, never plan files, so NO user-visible surface ever reveals the divergence. Decide (research) which failures should be fatal vs. loudly warned; a plan-write failure during implement is a strong fatal candidate.

DEFECT C - PLAN SELECTION IS MTIME-ORDERED, NOT VERSION-ORDERED:
- update-plan-status.sh:44 and update-phase-status.sh:63 both select the plan via `ls -t "$plan_dir"/*.md | head -1`. Merely EDITING an older plan re-targets both scripts at the wrong file. Select by version/sequence instead.

DEFECT D - IDEMPOTENCY SHORT-CIRCUIT SKIPS THE PLAN UPDATE:
- update-task-status.sh:133-144 exits 0 early when state.json already equals the target status, which ALSO skips the plan-file update. If state.json reached `implementing` by any other path, a later correct preflight becomes a silent no-op and the plan never updates. Make the early-exit cover state.json only, not the plan/phase side effects.

DEPENDS ON the vocabulary task: the marker set must be settled before wiring a writer to it, or this task hardcodes a contested vocabulary. Shares update-plan-status.sh with that task (file overlap -> serialized).

CONSTRAINT: no new scripts; fix and wire the three that exist.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 877. Settle the plan-level status marker vocabulary (script vs spec)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: None

**Description**: The status-writing script and the plan format spec disagree on MOST of the vocabulary. This must be settled before any writer is wired to it, otherwise a correctly-wired writer emits spec-violating markers.

VERIFIED EVIDENCE: update-plan-status.sh:21-27 accepts exactly {IMPLEMENTING, COMPLETED, PARTIAL, NOT STARTED}. plan-format.md:6 documents exactly {NOT STARTED, IN PROGRESS, BLOCKED, ABANDONED, COMPLETED}. They agree on only 2 of 5:
  - NOT STARTED  -> accepted + documented (agree)
  - COMPLETED    -> accepted + documented (agree)
  - IMPLEMENTING -> script WRITES it; absent from plan-level spec
  - PARTIAL      -> script WRITES it; absent from plan-level spec (it is a PHASE-level marker)
  - IN PROGRESS  -> documented; script REJECTS it (unreachable)
  - BLOCKED      -> documented; script REJECTS it (unreachable)
  - ABANDONED    -> documented; script REJECTS it (unreachable)
So three documented markers are unwritable and two written markers are undocumented.

OPEN QUESTION FOR RESEARCH - DO NOT PRE-RESOLVE. Two candidate resolutions, both defensible:
  (a) Conform the script to the spec: make update-plan-status.sh write the already-documented [IN PROGRESS] instead of [IMPLEMENTING]. Smaller spec surface; but [IN PROGRESS] then means something different at plan level than the task-level [IMPLEMENTING] that TODO.md shows, which may itself confuse the visibility the user wants.
  (b) Extend the spec to admit [IMPLEMENTING] (and possibly [PARTIAL]) at plan level. Keeps plan-level and task-level markers lexically aligned; but widens the vocabulary and must not collide with phase-level semantics.
Research must also settle the BROADER DIVERGENCE now in scope: plan-level admits [ABANDONED] but not [PARTIAL], while phase-level is the reverse (per artifact-formats.md:83-90 / plan-format-enforcement.md). Determine whether that asymmetry is intentional and document the rationale, or unify.

OUT OF SCOPE: do not fix the fail-silent / plan-selection / phase-advance defects here; those follow in the status-script hardening task that depends on this one.

CONSTRAINT: no new scripts.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 876. Wire status preflight into both /orchestrate paths
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: status-marker-lifecycle
- **Dependencies**: None

**Description**: HIGHEST-VALUE FIX for the reported symptom 'tasks say PLANNED when they are being worked on'. The capability already exists and is correct; nothing calls it on the /orchestrate path.

VERIFIED EVIDENCE:
- update-task-status.sh:92 already implements `preflight:implement` -> state=implementing + TODO=IMPLEMENTING. This IS the missing PLANNED->IMPLEMENTING transition. No new script is needed.
- skill-orchestrate/SKILL.md contains ZERO occurrences of `preflight` or `update-task-status` (verified grep count = 0).
- skill-orchestrate-hard/SKILL.md has only 2 occurrences, both POSTflight (:448, :451). No preflight on either path.
- ROOT CAUSE: skill-orchestrate/SKILL.md Stage 4 State Handlers (:193-330, e.g. :246-251) dispatch the Agent tool DIRECTLY by subagent_type ($IMPLEMENT_AGENT), bypassing skill-implementer. The preflight call lives INSIDE skill-implementer (:76) and skill-implementer-hard (:80), so direct Agent dispatch never reaches it.
- CONFIRMS the defect is confined to the orchestrate path: /implement is correct today; /orchestrate is not. The user's own report was about `/orchestrate on task 373`.
- Zero agents in .claude/agents/ reference update-task-status.sh, so nothing compensates downstream.

CONSEQUENCE: under /orchestrate a task goes planned -> (work happens) -> completed, never passing through implementing. Status markers give no visibility during the entire work window.

REQUIRED: Ensure both skill-orchestrate and skill-orchestrate-hard invoke the implement preflight before dispatching implementation work. Research should decide between (a) routing Stage 4 handlers through skill-implementer/skill-implementer-hard so the existing preflight is inherited, versus (b) calling update-task-status.sh preflight directly from the orchestrate state handlers. Option (a) removes the duplication that caused this bug class; option (b) is a smaller diff. Evaluate whether research/plan phases have the same gap, not just implement.

ALSO IN SCOPE: skill-orchestrate/SKILL.md:100 heading 'Stage 2: Preflight - Loop Guard' is misleadingly named. It is a loop guard, NOT a status update; the name plausibly masked this defect. Rename it.

CONSTRAINT: no new scripts. Wire the existing update-task-status.sh.

DELIVERABLE RULE: honor no-task-references-in-deliverables; cite durable anchors (file/section), never task numbers, in any file outside specs/**.

---

### 875. Teach meta-builder-agent global-mode semantics
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 873

**Description**: Update meta-builder-agent so it operates correctly at a resolved global root and so the tasks it CREATES name source-store paths rather than deploy-tree paths.

DEPENDS ON the global-default target resolution and --local flag work, which establishes GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}", the `cd "$GLOBAL_ROOT"` mechanism, and the resolved mode/root threaded through to the agent invocation. This task consumes that resolved root; it does not define it.

EDIT TARGET: agent-system/extensions/core/agents/meta-builder-agent.md ONLY.

CANONICAL SOURCE vs DEPLOY TREE (critical): the agent-system SOURCE of truth is agent-system/extensions/core/. The nvim repo's .claude/ tree is a GITIGNORED, UNTRACKED deploy artifact regenerated from the source store in agent-system/extensions/ (selection pinned by the project-root .claude-extensions.json); nothing under it is hand-authored, every deployed file has a source, enforced by the check-extension-docs.sh hard gate. The edit MUST target agent-system/extensions/core/agents/meta-builder-agent.md, NEVER the deployed .claude/ copy. Verified: the two are currently byte-identical.

REQUIRED CHANGES:
  - Stage 0 inventory at :158-162 currently uses bare CWD-relative paths (`ls .claude/commands/*.md`, `find .claude/skills -name SKILL.md`, `ls .claude/agents/*.md`, `ls .claude/rules/*.md`, `jq '.active_projects | length' specs/state.json`) and must operate at the resolved root.
  - Tasks this agent CREATES must name agent-system/extensions/core/** paths as edit targets rather than .claude/** paths, because .claude/ is a disposable deploy tree -- a task that edits .claude/ directly would have its work silently wiped by the next <leader>al regeneration.
  - The SCOPE BOUNDARY at :26 ("This agent MUST NOT write to .claude/ paths...") and the surrounding anti-bypass language need reframing in terms of the source store vs deploy tree distinction. The current wording predates the relocation and conflates "don't implement changes here" with "don't touch the deploy tree" -- two different rules that now have different correct answers.
  - The return-schema examples at :138-143 and the task-dir renderings at :821, :1032-1034, :1071-1074 and :1118-1119 use bare relative specs/ paths; confirm they remain correct under the cd mechanism (they likely are, since the cd makes CWD-relative paths resolve at the global root, but this must be checked rather than assumed).

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 874. Fix stale self-sync guard blocking nvim deploy-tree regeneration
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Remove or rework the stale self-sync guard that prevents the nvim repo from regenerating its OWN .claude/ deploy tree via the <leader>al picker.

CURRENT BEHAVIOR: load_all_globally() early-returns with helpers.notify("Already in the global directory", "INFO") when project_dir == global_dir. The guard lives at lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua:1141-1148.

WHY IT IS STALE: that guard predates the source-store relocation (commit 7e79b2695 "task 863 phase 1: relocate store and repoint canonical default"). It made sense when .claude/ WAS the source store and self-loading was a degenerate copy-onto-itself. Now that the source is agent-system/extensions/core/ and .claude/ is a gitignored, disposable deploy tree, the guard blocks exactly what .gitignore promises: "Wipe and regenerate from the <leader>al picker at any time."

USER-VISIBLE CONSEQUENCE: a global /meta change reaches other repos via <leader>al, but the nvim repo cannot regenerate its own .claude/ deploy tree, so nvim's own /meta stays stale. This directly undercuts the global-default /meta work once that lands.

RESEARCH NOTES:
  - sync.lua:1065-1066 sets use_core_source=false for the lib/ and tests/ categories, which still read from {global_dir}/.claude/ rather than the core store. Verify a self-load does not become a degenerate copy-onto-itself for those two categories specifically, and handle or exclude them if so. This is the main correctness risk in removing the guard.
  - Verify against the read/write split at sync.lua:913-923 (core_source_base derivation).
  - Verify against the root_file_names={} / CLAUDE.md exclusions at :1084 and :1126-1128.

TESTING CONSTRAINT: all destructive loader testing happens in the scratchpad against fake project dirs, NEVER against the real ~/.config/nvim/.claude tree (this loader had a live data-loss bug recently).

This task is independent of the global-default /meta target-resolution work and can proceed in parallel, but it must land for that work to be observable from within nvim itself.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

---

### 873. Add global-default target resolution and --local flag to /meta
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

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

---

### 872. /distill review/revise (dream) mode
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: Task 869, Task 870, Task 871
- **Research**: [872_distill_review_revise_dream_mode/reports/01_dream_mode_research.md]
- **Plan**: [872_distill_review_revise_dream_mode/plans/01_distill-dream-mode.md]
- **Summary**: [872_distill_review_revise_dream_mode/summaries/01_distill-dream-mode-summary.md]

**Description**: Add a new review/revise (dream) mode to the existing /distill command (NOT a separate /dream command) that ingests the unified store, re-reviews and revises ALL memories in light of the captured logs, and synthesizes concrete agent-system improvement proposals (which may become tasks or documentation edits). Reuse /distill's existing score/merge/compress/refine/purge/gc primitives internally and the skill-memory distill sub_mode dispatch; this is the loop-closing consumer. Depends on the store plus both capture layers so it operates over real captured data. Keep the memory EXTENSION.md, manifest.json, index-entries.json, and distill-usage context in sync (CLAUDE.md is auto-generated).

---

### 871. Completion-time reflective harvest (/todo + /learn)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: Task 869, Task 870
- **Research**: [871_completion_time_reflective_harvest/reports/01_completion_time_reflective_harvest.md]
- **Plan**: [871_completion_time_reflective_harvest/plans/01_reflective-harvest.md]
- **Summary**: [871_completion_time_reflective_harvest/summaries/01_reflective-harvest-summary.md]

**Description**: Add a structured reflective capture at task completion (what worked / what was hard / what was missed / successes) by extending the existing skill-todo Stage 7/9 harvest and the /learn --task flow rather than replacing them. Persist the reflection as a new field alongside memory_candidates/completion_summary in the task's state.json entry, written at the orchestrator-postflight.sh completion seam, and surface it via the existing AskUserQuestion interactive prompt; the reflection also lands in the unified store for distillation. Depends on the store contract. This task shares orchestrator-postflight.sh and the core EXTENSION.md/manifest.json surfaces with the hook-logging task, so it is intentionally serialized after it (user chose the serialized/safe ordering). Keep the memory and core EXTENSION.md / manifest / index-entries in sync (CLAUDE.md is auto-generated).

---

### 870. Automatic hook-based lifecycle event logging
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: Task 869
- **Research**: [870_automatic_hook_event_logging/reports/01_automatic-hook-event-logging.md]
- **Plan**: [870_automatic_hook_event_logging/plans/01_hook-event-instrumentation.md]
- **Summary**: [870_automatic_hook_event_logging/summaries/01_hook-event-instrumentation-summary.md]

**Description**: Emit structured events into the unified store automatically: instrument the four skill-base.sh lifecycle stage functions (preflight/context_injection/verification/postflight) for timings and success milestones, and add a PostToolUse plus Stop/SubagentStop logger hook capturing command/agent lifecycle events, deviations, and blockers, cross-linked with errors.json via the shared session_id/task keys. Reuse the existing provides.hooks + settings.json wiring convention; note there is currently no live functioning top-level lifecycle hook, so this also establishes that pattern for real. Handle the lazy absence of errors.json gracefully (do not assume it exists). Depends on the store contract for its append helper. Keep the core EXTENSION.md, manifest.json, and index-entries.json in sync (CLAUDE.md is auto-generated).

---

### 869. Unified event/reflection JSONL store + schema + reader API
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: None
- **Research**: [869_unified_event_reflection_store/reports/01_event-store-schema-design.md]
- **Plan**: [869_unified_event_reflection_store/plans/01_event-store-plumbing.md]
- **Summary**: [869_unified_event_reflection_store/plans/01_event-store-plumbing.md]

**Description**: Define the append-only JSONL store (proposed specs/events.jsonl, created lazily like errors.json) that both capture layers write and the memory distillation reads. Specify the event schema (event_type, timestamp, duration, session_id, task, checkpoint, category for deviation/blocker/milestone/success, and cross-link to errors.json), and ship a shared append helper plus a query/reader helper so no subsystem hand-rolls jq. This is the foundational contract and is sequenced first (build inversion of the runtime data flow) so the producer layers have a validated write target and the distillation consumer has a stable reader; it implements only the store plumbing and its documented format, no agent-behavioral capture itself. Reuse the errors.json entry-schema conventions and the shared session_id/task cross-link keys. Keep the core EXTENSION.md, manifest.json, and index-entries.json in sync (CLAUDE.md is auto-generated, never hand-edited).

---

### 868. Typst segmentation evaluation
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 866
- **Research**: [868_typst_segmentation_evaluation/reports/01_typst-segmentation-decision.md]
- **Plan**: [868_typst_segmentation_evaluation/plans/01_markdown-retention-decision.md]
- **Summary**: [868_typst_segmentation_evaluation/summaries/01_markdown-retention-decision-summary.md]

**Description**: Evaluate whether Typst segmentation is "superior AND just as convenient" versus the current markdown chunking, and implement conditionally. Current pipeline is markdown-only: literature-convert.sh emits {doc_id}.md (pdftotext + PyMuPDF; marker/pandoc explicitly evaluated and rejected), literature-chunk.sh does markdown-heading-driven ('# ## ###') two-pass hierarchical chunking into chunk_NNNN.md + chunks.json, indexed via literature-schema.sql / literature-build-index.sh (SQLite FTS5). The typst extension is authoring-only (no scripts, no converter, no chunker). The FTS5 index is largely format-agnostic (a source_format column already exists; .typ chunks are feasible with minor chunk-file glob and --read path changes), but a PDF->typst converter and a typst-aware segmenter (typst '=' / '==' headings and #heading[] / #theorem[] functions) would be NEW greenfield work. Deliverables: (a) a clear decision -- is typst superior and just-as-convenient for segmentation? If NO, record a durable decision (referencing durable anchors, no task-number citations) to keep markdown, with rationale; (b) if YES, implement a typst conversion/segmentation path and make the ingest pipeline (especially the task 866 bridge plus literature-convert.sh / literature-chunk.sh) format-configurable, with minimal index-schema changes. A "no format change" outcome is valid and expected if convenience parity is not met. Depends on task 866 (modifies the same convert/chunk stage the bridge uses).

---

### 867. Sparse lit detection stage4a
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 866
- **Research**: [867_sparse_lit_detection_stage4a/reports/01_sparse-lit-detection-design.md]
- **Plan**: [867_sparse_lit_detection_stage4a/plans/01_sparse-lit-stage4a-wiring.md]
- **Summary**: [867_sparse_lit_detection_stage4a/summaries/01_sparse-lit-stage4a-wiring-summary.md]

**Description**: Add sparse-literature detection to --lit and reconcile the drifted Stage 4a flow so that when a run "does not find much" literature it offers to search online and ingest (via the task 866 bridge). Current gaps: literature-lit-flag-resolve.sh classifies purely on file existence (5 directives: LIT_DISABLED / SUBINDEX_PRESENT / GLOBAL_MISSING / PROMPT_NEEDED / AUTONOMOUS_GLOBAL) with NO count or threshold; literature-briefing.sh computes an internal seg_count but never surfaces it to callers; and the deployed skills' Stage 4a is DRIFTED -- skill-researcher and its peers do not actually call literature-lit-flag-resolve.sh and never offer the designed "Use global corpus now" option. This task: (1) surface a machine-readable coverage/segment count and a `sparse` signal from literature-briefing.sh, following the established loud-banner precedent (never silent); (2) add a configurable sparsity threshold with a sensible default; (3) introduce a new directive (e.g. SPARSE_PROMPT_NEEDED) that fires on sparse-OR-absent coverage on BOTH the SUBINDEX_PRESENT path (sub-index exists but returns few relevant chunks) AND the global-search path; (4) reconcile and complete the Stage 4a wiring across ALL SIX --lit skills (skill-researcher / skill-planner / skill-implementer and their -hard variants) so they call the resolver and present a new interactive option "Search online to ingest" that invokes the task 866 bridge; (5) preserve the autonomous/orchestrator contract with a deterministic, visible [lit:auto] fallback -- never a silent no-op. Keep EXTENSION.md / merge-source docs in sync (CLAUDE.md is auto-generated). Depends on task 866 (the "search online" option must invoke the ingest bridge).

---

### 866. Online ingest zotero pdf bridge
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [866_online_ingest_zotero_pdf_bridge/reports/01_online-ingest-zotero-bridge.md]
- **Plan**: [866_online_ingest_zotero_pdf_bridge/plans/01_online-ingest-zotero-bridge.md]
- **Summary**: [866_online_ingest_zotero_pdf_bridge/summaries/01_online-ingest-zotero-bridge-summary.md]

**Description**: Build the online-discovery -> Zotero+PDF -> ingest bridge for the literature extension so a --lit run can ingest a newly found online source end-to-end. Wire literature-discover.sh Tier-3 online results (Semantic Scholar / Unpaywall / arXiv; statuses open_access / paywall / arxiv / in_zotero_no_pdf) into the existing ingest pipeline. For a user-selected discovered source: (1) resolve and download the PDF for open-access/arXiv hits; (2) add the source to Zotero WITH the PDF attached -- this requires a NEW create-item capability (Zotero Web API POST /items via the `zot` CLI, or the local API at 127.0.0.1:23119), since zotero-write.sh today supports ONLY note-add / tag-add / tag-remove / attach-file against an EXISTING item and has no create-item path; (3) run the existing convert -> chunk -> build-index pipeline (literature-ingest.sh, literature-convert.sh, literature-chunk.sh, literature-build-index.sh) and register the new doc in the global index and, when appropriate, the per-repo sub-index (specs/literature-index.json). Paywalled/no-PDF sources MUST be surfaced honestly with no fabricated downloads, mirroring the existing assisted-export UX (zotero-export-status.sh directives) in commands/literature.md. Preferred shape: a new entry point (e.g. literature-ingest-online.sh) or an extension of literature-ingest.sh that accepts a discovery record. This is the foundation task; tasks 867 and 868 build on it. Keep the literature EXTENSION.md / merge-source docs in sync (CLAUDE.md is auto-generated).

---

### 865. Make .claude/ wipe lossless and one-keystroke regenerable
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: extensions
- **Dependencies**: Task 863
- **Research**: [865_make_claude_wipe_lossless_and_regenerable/reports/01_wipe-lossless-regenerable-research.md]
- **Plan**: [865_make_claude_wipe_lossless_and_regenerable/plans/01_wipe-lossless-regenerable.md]
- **Summary**: [865_make_claude_wipe_lossless_and_regenerable/summaries/01_wipe-lossless-regenerable-summary.md]

**Description**: Make a .claude/ wipe lossless and one-keystroke regenerable by lifting all wipe-surviving state OUT of .claude/. Depends on the store-relocation task (the deploy/target model); can land in parallel with or after the drift-check-hardening task.

CONTEXT: Selection/state is currently written INSIDE the deployed tree, so a wipe destroys it. get_state_path = project_dir .. "/" .. config.base_dir .. "/" .. config.state_file = $CWD/.claude/extensions.json (state.lua:71). settings.json and logs/ also currently live under .claude/ but are input/runtime, not build output. specs/ is already correctly at project root and is the model to follow.

REQUIRED: (1) Move the selection manifest extensions.json from $CWD/.claude/extensions.json to a project-root location that survives a wipe (candidate: $CWD/.agent-extensions.json; research to confirm the name) so regenerate can skip re-picking, and so a project can optionally commit the file to pin its extension set. (2) Move settings.json and logs/ out of .claude/ (they are input/runtime, not output). (3) Update state.lua get_state_path and ALL readers/writers of the moved state. (4) Include a headless-nvim verification that constructs a FAKE project dir in the scratchpad, deploys, deletes .claude/, and regenerates identically from the surviving selection.

TESTING SAFETY (mandatory): NEVER run destructive testing against the real ~/.config/nvim/.claude tree. This loader had a live data-loss bug recently; ALL destructive testing is scratch-only, against fake project dirs constructed in the scratchpad.

CROSS-CUTTING CONSTRAINTS: Copy-deploy only, no symlink farm. Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**. Build on (do not recreate) the already-landed check_deployed_rule_drift and the symlink-safe remove path in loader.lua. DESIRED END STATE: after a .claude/ wipe, nothing hand-authored or stateful is lost; regenerate from the surviving selection reproduces .claude/ identically, upholding `.claude/ == deploy(store, selection)`.

---

### 864. Enforce every deployed file has a source (hard drift gate)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 863
- **Research**: [864_enforce_every_deployed_file_has_a_source/reports/01_enforce-every-deployed-file-source.md]
- **Plan**: [864_enforce_every_deployed_file_has_a_source/plans/01_deployed-file-source-hard-gate.md]
- **Summary**: [864_enforce_every_deployed_file_has_a_source/summaries/01_deployed-file-source-hard-gate-summary.md]

**Description**: Enforce the invariant "every deployed file has a source" by extending the deployed-vs-source drift check into a hard gate, and by giving every deployed-only orphan a real source home in the core extension. Order this AFTER the store-relocation task (the check compares deployed output against the relocated store).

CONTEXT: The existing rule-drift check (check_deployed_rule_drift in .claude/scripts/check-extension-docs.sh) currently covers only provides.rules. Deployed-only ORPHANS with no source exist today and would vanish on a clean rebuild: .claude/rules/no-task-references-in-deliverables.md (declared in core manifest but no source file under core/rules/), .claude/commands/README.md, and ~4 standalone scripts under .claude/scripts/.

REQUIRED: (1) Extend the deployed-vs-source drift check in .claude/scripts/check-extension-docs.sh beyond provides.rules to ALL provides categories (agents, commands, context, scripts), following the per-category convention divergences already documented: agents needs an agents_subdir parameter; context needs recursive directory comparison. (2) Give the deployed-only orphans a source home in the core extension so nothing deployed is unsourced: no-task-references-in-deliverables.md, commands/README.md, and the ~4 standalone scripts. (3) Make the check a HARD gate (exit non-zero on any unsourced deployed file), proving the disposable-output invariant holds.

DUAL-WRITE HAZARD (mandatory): check-extension-docs.sh has a dual copy at .claude/extensions/core/scripts/check-extension-docs.sh and the script lints itself. Every edit must land BYTE-IDENTICAL in both .claude/scripts/check-extension-docs.sh and .claude/extensions/core/scripts/check-extension-docs.sh.

CROSS-CUTTING CONSTRAINTS: Copy-deploy only, no symlink farm. All destructive loader testing in the scratchpad against fake project dirs, never against the real .claude tree. Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**. Build on (do not recreate) the already-landed check_deployed_rule_drift and the symlink-safe remove path in loader.lua.

---

### 863. Relocate extension source store out of .claude/
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [863_relocate_extension_source_store_out_of_claude/reports/01_relocate-extension-source-store.md]
- **Plan**: [863_relocate_extension_source_store_out_of_claude/plans/01_relocate-extension-store.md]
- **Summary**: [863_relocate_extension_source_store_out_of_claude/summaries/01_relocate-extension-store-summary.md]

**Description**: Relocate the extension source store OUT of any deployed .claude/ tree so that .claude/ can become a pure, disposable copy-deploy build artifact regenerable from the <leader>al picker after deletion. This is the UNLOCKING change and must land FIRST.

CONTEXT: The loader already deploys into the current working directory (lua/neotex/plugins/ai/shared/extensions/init.lua:238 `local project_dir = opts.project_dir or vim.fn.getcwd()`; deploy target = project_dir .. "/" .. config.base_dir = $CWD/.claude, init.lua:79). Sources are read from a GLOBAL root `global_extensions_dir` defaulting to ~/.config/nvim/.claude/extensions (config.lua:55 in the M.claude preset; global_dir defaults to vim.fn.expand("~/.config/nvim")). The picker `list_extensions` reads from config.global_extensions_dir and returns empty if that dir is absent (manifest.lua:171-178). The ONLY reason ~/.config/nvim cannot self-rebuild today is that its source store (.claude/extensions/) physically lives INSIDE its own deploy target; every OTHER working directory can already delete-and-regenerate because source and target are different trees.

REQUIRED: Physically move .claude/extensions/ to a sibling location NOT under any deployed .claude/ (candidate: ~/.config/nvim/agent-system/extensions/, or another non-.claude path the research phase should evaluate). Repoint global_extensions_dir in config.lua:55 (M.claude preset) to the new store. Adjust how manifest.lua and init.lua resolve the store ONLY if needed. Verify: (1) the picker lists extensions from the new location; (2) deploying into an arbitrary $CWD/.claude still works; (3) ~/.config/nvim itself now rebuilds like any other project (its .claude/ is a disposable deploy target with no source inside it).

FILE SCOPE centers on lua/neotex/plugins/ai/shared/extensions/config.lua plus the physical relocation of the store; touches manifest.lua/init.lua store-resolution only if required.

CROSS-CUTTING CONSTRAINTS: Copy-deploy only, NO symlink farm (the user explicitly rejected symlinks; absolute source paths would also leak across arbitrary project directories). All destructive loader testing happens in the scratchpad against fake project dirs, NEVER against the real ~/.config/nvim/.claude tree (this loader had a live data-loss bug recently). Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

DESIRED END STATE (shared across this sequence): .claude/ in any CWD is 100% disposable build output (nothing hand-authored, no source, no state, no orphans); one global source store lives OUTSIDE any .claude/; the invariant `.claude/ == deploy(store, selection)` holds. Foundation already landed and MUST be built on, not recreated: a deployed-vs-source rule drift check (check_deployed_rule_drift) and a symlink-safe remove path in loader.lua.

---

### 862. Fix loader symlink delete data loss
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [862_fix_loader_symlink_delete_data_loss/reports/01_loader-symlink-delete-data-loss.md]
- **Plan**: [862_fix_loader_symlink_delete_data_loss/plans/01_loader-symlink-delete-data-loss.md]
- **Summary**: [862_fix_loader_symlink_delete_data_loss/summaries/01_loader-symlink-delete-data-loss-summary.md]

**Description**: Fix data loss in the extension loader: remove_installed_files() deletes through symlinks, destroying tracked extension-source files.

OBSERVED DATA LOSS: an extension reload deleted .claude/extensions/literature/skills/skill-literature/SKILL.md (2265 lines, git-tracked). Evidence: a check-extension-docs.sh run immediately before the reload recorded "literature PASS"; immediately after, "literature FAIL: manifest skill entry missing on disk: skills/skill-literature/SKILL.md". The extension-source directory mtime matched the reload timestamp to the second. The file was recovered from git HEAD; /literature was broken until then.

ROOT CAUSE: deployed skills are symlinks into extension sources, e.g. .claude/skills/skill-literature -> ../extensions/literature/skills/skill-literature. The unload step in lua/neotex/plugins/ai/shared/extensions/loader.lua (remove_installed_files, approx lines 755-784) iterates installed_files and calls vim.fn.delete(filepath) on the DEPLOYED path. Because the deployed path resolves through the symlink, the delete lands on the real extension-source file. The subsequent copy step then has nothing to copy and leaves an empty directory. Deployed and source are the same inode, so "remove the deployed copy" means "destroy the source".

STILL LIVE: the symlink is unchanged, so another reload destroys the file again. Nine other deployed skills are symlinks into extension sources and are exposed whenever their extension unloads: skill-cslib-implementation, skill-cslib-implementation-hard, skill-cslib-research, skill-cslib-research-hard, skill-cslib-vet, skill-pr-implementation, skill-pr-review-implementation, skill-pr-review-research, skill-zotero.

SECOND GAP: remove_installed_files() takes no protected_paths argument, so .syncprotect does not guard the delete path at all. copy_file() honors protected_paths; the removal path does not. A user who lists a file in .syncprotect is protected on sync but not on unload.

THIRD SYMPTOM (same interaction, lower severity): the reload replaced .claude/agents/literature-agent.md and .claude/commands/literature.md, which are mode 120000 (symlinks) in HEAD, with regular files. Content was preserved but the symlink setup was silently flattened; these show as typechanges (T) in git status.

REQUIRED: make the removal path symlink-aware so it never deletes through a symlink into an extension source -- e.g. skip paths where the deployed entry is a symlink (or resolves outside the deployed tree), or unlink the symlink itself rather than its target. Decide and document whether the symlink deploy mode is supported: if supported, both copy and remove must handle it; if not, the loader should refuse to install over a symlink rather than silently destroying it. Also thread protected_paths/.syncprotect through remove_installed_files() so protection is symmetric across copy and remove. Verify with nvim --headless: reload an extension whose deployed skill is a symlink and assert the source file survives.

---

### 861. Add rule drift check to extension lint
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [861_add_rule_drift_check_to_extension_lint/reports/01_rule-drift-check-lint.md]
- **Plan**: [861_add_rule_drift_check_to_extension_lint/plans/01_rule-drift-check-lint.md]
- **Summary**: [861_add_rule_drift_check_to_extension_lint/summaries/01_rule-drift-check-lint-summary.md]

**Description**: Add a deployed-vs-source content drift check for extension rules in check-extension-docs.sh. The script's check_deployed_script_drift covers manifest.provides.scripts only, comparing the deployed .claude/scripts/<name> against the extension source <ext>/scripts/<name>. There is no equivalent check for provides.rules, so a rule file whose deployed .claude/rules/<name>.md has diverged from its extension source is invisible to lint.

This is not hypothetical. core/rules/pr-prohibition.md had silently accumulated 35 lines in its deployed copy (the "/pr --review Workflow" section) that were absent from the extension source. The divergence survived precisely because the rule was unregistered in provides.rules, so the loader never overwrote the deployed copy. Once registered, the loader's byte-for-byte copy_file() overwrite would have destroyed that content -- the reconciliation had to be performed by hand first. A drift check would have surfaced this years earlier.

Implement check_deployed_rule_drift mirroring check_deployed_script_drift: for each manifest.provides.rules entry where BOTH the deployed .claude/rules/<name> and the extension source <ext>/rules/<name> exist, fail on content mismatch; skip with an info note (never fail) when the deployed copy is absent, since an extension's rules are not deployed in every consuming repo.

Also evaluate whether the same deployed-vs-source asymmetry applies to provides.agents, provides.commands, and provides.context, and whether a single drift helper parameterized by category is warranted rather than adding a fourth near-duplicate function.

Note: check-extension-docs.sh is itself declared in core's provides.scripts, so any edit must be written to BOTH .claude/scripts/ and .claude/extensions/core/scripts/ or the drift check will flag the change itself.

---

### 860. Enforce plan compliance rule
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [860_enforce_plan_compliance_rule/reports/01_plan-compliance-rule.md]
- **Plan**: [860_enforce_plan_compliance_rule/plans/01_plan-compliance-rule.md]
- **Summary**: [860_enforce_plan_compliance_rule/summaries/01_plan-compliance-rule-summary.md]

**Description**: Add a .claude/rules/ rule enforcing strict plan compliance for lean-implementation-agent and other formal implementation agents. The rule should: (1) Prohibit agents from "assessing what's truly minimal" or inventing alternative approaches when a plan exists. (2) Require agents to follow the plan's exact task sequence step-by-step, in order. (3) Explicitly ban common divergence patterns: skipping intermediate theorems, inlining proofs instead of following the plan's decomposition, routing through different helper lemmas than specified, and "cleaner approach" rationalizations. (4) Be auto-applied via glob pattern to formal proof files (e.g. Theories/**, **/*.lean); the glob must generalize across consuming repos rather than hard-coding one project's layout. (5) Reference the repeated failures in BimodalLogic task 157 (8 plan versions, agents diverging every time) as motivation. The rule should be concise but firm -- agents must treat the plan as a contract, not a suggestion.

Provenance: relocated from BimodalLogic task 162 (2026-07-14). Authored here in the agent-system source of truth so the rule syncs out to consuming repos, rather than living only in BimodalLogic/.claude/.

---

### 859. Fix generate-task-order.sh: dependency tree renders flat for non-lowercase topic strings (topic-key case mismatch)
- **Effort**: low
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [859_fix_task_order_topic_case_indentation/reports/01_topic-standardization.md]
- **Plan**: [859_fix_task_order_topic_case_indentation/plans/01_topic-normalization.md]
- **Summary**: [859_fix_task_order_topic_case_indentation/summaries/01_topic-normalization-summary.md]

**Description**: generate-task-order.sh renders the Grouped-by-Topic dependency tree FLAT (no indented '└─' children) for any topic whose raw string is not already all-lowercase. ROOT CAUSE: topic sections are grouped under a LOWERCASED key (`_current_section_topic` = the lowercased topic, set from the grouping key at generate_grouped_section), but the two guards that decide child recursion / cross-topic annotation compare that lowercased key against the RAW topic string from state.json. In .claude/extensions/core/scripts/generate-task-order.sh: line 578 `"$dep_topic" != "$_current_section_topic"` (successor-skip in _print_topic_node) and line 553 `"$task_topic_val" != "$_current_section_topic"` (cross-topic 'see above' annotation). For a task with topic 'Modal Logic', dep_topic='Modal Logic' but _current_section_topic='modal logic', so the strings never match, every successor is skipped, and the tree collapses to a flat list. Only all-lowercase topics (e.g. 'modal-logic') ever showed the tree; Title-Case topics ('Modal Logic', 'Code Hygiene', etc.) always rendered flat. FIX (already validated live in the deployed Projects/cslib copy): lowercase both sides of both comparisons — line 578 -> `"${dep_topic,,}" != "$_current_section_topic"` and line 553 -> `"${task_topic_val,,}" != "$_current_section_topic"`. After the fix the 491->495->496->484 chain indents correctly under a single Modal Logic heading. APPLY TO: (1) source-of-truth .claude/extensions/core/scripts/generate-task-order.sh (lines 553, 578); (2) mirror the same two-line change to .opencode/scripts/generate-task-order.sh (lines 481, 506) for OpenCode parity. The deployed .claude/scripts/generate-task-order.sh is regenerated from the core extension on load, so editing the core source is what persists; do not rely on the standalone .claude/scripts copy. VERIFY: after editing, run `bash .claude/scripts/generate-todo.sh` (or a fixture) on a state.json containing a Title-Case topic with an intra-topic dependency chain and confirm the '└─' indentation appears. RELATED REFINEMENT (optional, same file): the topic grouping key lowercases but does NOT normalize separators, so 'Modal Logic' and 'modal-logic' hash to different keys ('modal logic' vs 'modal-logic') and produce TWO identical-looking '### Modal Logic' headings. Consider normalizing hyphen<->space (and maybe collapsing whitespace) in the grouping key so case- and separator-variant topic strings collapse into one section, preventing duplicate headings. CONTEXT: discovered in Projects/cslib while normalizing kebab-case topic values to Title-Case, which merged two duplicate Modal Logic sections but exposed this latent case-sensitivity bug.

---

### 858. Fast, responsive, non-failing <leader>me aerc launch
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**:
  - [858_mail_launch_gate_performance/reports/01_launch-gate-performance-diagnosis.md]
  - [858_mail_launch_gate_performance/reports/02_hard-research-fast-responsive-launch.md]
- **Plan**: [858_mail_launch_gate_performance/plans/02_fast-responsive-aerc-launch.md]
- **Summary**: [858_mail_launch_gate_performance/summaries/02_fast-responsive-aerc-launch-summary.md]

**Description**: The <leader>me aerc launch workflow in lua/neotex/plugins/tools/mail.lua has become slow and now permanently refuses to open aerc. A single press triggers THREE overlapping sync layers -- (1) a himalaya-plugin inbox sync, (2) mail.lua sync_all_mail running the forbidden all-channels `mbsync -a` (which syncs Gmail All_Mail ~64k messages and fails code 1 on a pre-existing duplicate-UID collision), and (3) run_notmuch_new calling hook-ful `notmuch new`, whose preNew hook is now `mail-sync both` (dotfiles task 109), recursively driving a full serialized gmail+logos mbsync -- plus two email-census scans. All of it runs synchronously on the launch-blocking critical path, so the user waits for the slowest full sync before anything appears. The gate then refuses to open aerc because it conflates "mbsync succeeded" with "index is safe to read": the primary barrier requires mbsync -a + notmuch new to exit 0 (impossible while the duplicate-UID persists -- a manual data repair, not a sync fix), and the census fallback honestly reports [STALE]. Net effect: a sync-independent data fault permanently denies the mail client even though, after notmuch new reconciles the index, opening aerc would be safe. GOAL: redesign <leader>me for fast, responsive, non-failing launch -- open aerc promptly on a cheaply-reconciled index (notmuch new --no-hooks) with mbsync deferred/backgrounded and never on the launch-blocking path; decouple launch from mbsync exit code (warn, do not block); eliminate the redundant sync layers (route through the single mail-sync wrapper, use --no-hooks to avoid recursive re-sync, reconcile/suppress the himalaya double-sync); never use mbsync -a; keep the full explicit sync on <leader>mN. Must remain safe against opening onto a genuinely stale/mid-write Xapian index (no return of "could not get MessageInfo" races). Non-goal: the one-time duplicate-UID-15 maildir data repair, but the fix must make <leader>me usable despite an unrepaired collision. See reports/01_launch-gate-performance-diagnosis.md for the seed diagnosis; deep study to be produced by a fable --hard researcher.

---

### 857. Reindex-on-failure for the aerc launch gate
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**: [857_mail_reindex_on_failure_gate/reports/01_reindex-on-failure-gate.md]
- **Plan**: [857_mail_reindex_on_failure_gate/plans/01_reindex-on-failure-gate.md]
- **Summary**: [857_mail_reindex_on_failure_gate/summaries/01_reindex-on-failure-gate-summary.md]

**Description**: Harden the <leader>me aerc launch gate in lua/neotex/plugins/tools/mail.lua so a failed `mbsync -a` no longer leaves notmuch stale before the freshness decision, providing a minimal, durable fix without unnecessary complexity.

CURRENT BEHAVIOR (verified in mail.lua): sync_all_mail() runs `notmuch new` ONLY when `mbsync -a` exits 0; on mbsync failure it notifies the error and returns via on_done(false) WITHOUT reindexing. The gate itself already refuses-and-reports rather than failing open -- it opens aerc only on a clean sync+reindex, or when census_freshness_ok() reads [ok] on BOTH accounts, otherwise it refuses with remediation guidance. That refuse-and-report barrier is sound and must be preserved.

GAP TO FIX (the real durable change): on the mbsync-failure path, run `notmuch new` BEFORE the freshness decision, so maildir files that already landed on disk -- or mailboxes that synced before an abort such as a duplicate-UID collision -- get reconciled into the index. Then let the existing authoritative barrier make the launch decision against a freshly reindexed state instead of a stale one.

SCOPE CONSTRAINTS:
- Keep the change minimal and cohesive (one function/gate); do not duplicate freshness logic that belongs in the external census wrapper.
- Preserve the existing refuse-and-report barrier and its remediation messaging.
- The fallback signal census_freshness_ok() reads the "INBOX freshness ... [ok]" line, a count-with-tolerance proxy that cannot detect flag-renames or phantom drift -- this is what produced the false green. Making that signal authoritative is an EXTERNAL follow-up in ~/.dotfiles modules/home/email/agent-tools/census.nix (rename/deletion-aware freshness) and is intentionally OUT OF SCOPE here. Document the dependency in the gate's comment so a future reader knows the barrier's trustworthiness rests on that external signal.

OUT OF SCOPE (context only, no repo change, no commit): one-time ~/Mail data repair for the duplicate UID 15 collision in Gmail/.All_Mail, and the one-time `notmuch new` index reconciliation of the ~38-file INBOX phantom drift. These are manual mail-data operations, not code.
