---
next_project_number: 22
---

# TODO

## Task Order

*Updated 2026-08-10. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 5,11,12,14,16,17,18,19,20 | -- | agent-system, extensions, orchestration-concurrency |
| 2 | 6,9,13 | 5,17,18 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

5 [NOT STARTED] — /todo documents a producer/consumer contract for ROADMAP.md synch
  └─ 6 [NOT STARTED] — The artifact list in specs/state.json is append-only by intent bu
11 [NOT STARTED] — The system-defect vocabulary has a gap: defect classes exist for 
12 [PARTIAL] — tests/run-all.sh is red and has been treated as permanently-expec
14 [NOT STARTED] — Two dispatches in a single batch fanned out to phase sub-agents a
17 [NOT STARTED] — command-gate-out.sh's entire post-metadata body is structurally u
  └─ 13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
18 [NOT STARTED] — A repo can carry an arbitrarily stale .claude/ deploy with no sig
  └─ 9 [NOT STARTED] — Declared-vs-deployed parity for provides.* categories is one-dire
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th

### Extensions

19 [NOT STARTED] — Reloading extensions in a consuming repo emits roughly 60 lines o

### Orchestration Concurrency

16 [IMPLEMENTING] — Fix the register-bare/acquire-suffixed session-id pattern in the 

## Tasks

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

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
- **Dependencies**: None

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
- **Status**: [IMPLEMENTING]
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
- **Dependencies**: None

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
- **Status**: [PARTIAL]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md]
- **Plan**: [012_fix_test_suite_deployed_mode_failures/plans/01_run-all-deployed-mode-fixes.md]
- **Summary**: [012_fix_test_suite_deployed_mode_failures/summaries/01_run-all-deployed-mode-fixes-summary.md]

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

---

### 11. Expand defect class vocabulary
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

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
- **Dependencies**: Task 1015, Task 18

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 5

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
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 1004

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
