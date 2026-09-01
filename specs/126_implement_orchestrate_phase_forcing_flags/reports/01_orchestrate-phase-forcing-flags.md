# Research Report: Implement orchestrate phase forcing flags

- **Task**: 126 - Implement orchestrate phase forcing flags
- **Started**: 2026-09-01T13:03:00Z
- **Completed**: 2026-09-01T13:15:00Z
- **Effort**: ~1 hour
- **Dependencies**: Task 117, Task 122 (both `completed`, verified before dispatch)
- **Sources/Inputs**:
  - Codebase: `agent-system/extensions/core/commands/orchestrate.md`
  - Codebase: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  - Codebase: `agent-system/extensions/core/scripts/orchestrator-postflight.sh`
  - Codebase: `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh`
  - Codebase: `agent-system/extensions/core/scripts/skill-base.sh`
  - Codebase: `agent-system/extensions/core/scripts/parse-command-args.sh`
  - Codebase: `agent-system/extensions/core/scripts/update-task-status.sh`
  - Codebase: `agent-system/extensions/core/context/standards/status-markers.md`
  - Codebase: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  - Design reference: `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A2, full section)
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md, status-markers.md

## Executive Summary

- **Major correction to the task premise**: `orchestrator-postflight.sh` — named in the task
  description and its `SOURCE STORE IS THE EDIT TARGET` list as the site for WORK item (3) — has
  **zero call sites in `skill-orchestrate/SKILL.md`**, in either single-task or multi-task mode.
  It is called only by the plain `/implement` command's `skill-implementer/SKILL.md`. Editing it
  alone would have no effect on `/orchestrate`'s behavior.
- `/orchestrate`'s real status-transition/artifact-linking path is `orchestrate-stage5-postflight.sh`
  (single-task, called from Stage 5) and the equivalent Stage MT-4 block (multi-task) —
  both converge on `skill_postflight_update` in `skill-base.sh`.
- Neither of those real sites, nor `update-task-status.sh` underneath them, contains any
  `next_artifact_number` logic today. **`/orchestrate` currently never increments
  `next_artifact_number` for any phase, including research** — contradicting the task
  description's implicit premise that research's increment "already works" under `/orchestrate`
  and merely needs generalizing to plan/implement.
- WORK items (1) (flag surface) and (2) (phase-resolution override) map cleanly onto existing,
  identifiable code: `parse-command-args.sh`'s boolean-flag pattern, and `skill-orchestrate`'s
  Stage 1 delegation-context parsing plus its prose-based `#### State: ...` handler sections in
  Stage 4 (there is no literal `case` statement — handler selection is a semantic match on
  `current_status`, executed by the agent reading the skill file).
- WORK item (4) (monotonic-max clamp) has no existing status-rank/regression-guard mechanism to
  reuse — `update-task-status.sh`'s `map_status()` unconditionally maps `operation:target` pairs
  to a fixed resting status with no comparison against the task's current status.
- Recommendation: treat WORK items (3) and (4) as one combined design (both touch the same
  `skill_postflight_update` / `orchestrate-stage5-postflight.sh` call chain), and have the plan
  phase explicitly decide whether fixing "`/orchestrate` never increments `next_artifact_number`
  at all" is in-scope for this task or a separately filed defect.

## Context & Scope

This task implements design-report decision A2 (Phase-Forcing Flags): a `--research`/`--plan`/
`--implement` flag surface on `/orchestrate` that lets an operator force a lifecycle phase to
re-run even when the task has already progressed past it, using the existing `MM_` round-numbering
convention for the new artifact and a monotonic-max status write so a forced earlier phase can
never regress a task's status.

Scope is limited to the four WORK items in the task description and their four named files. This
report evaluates each WORK item against the current source-store implementation and identifies
where the described target files/mechanisms diverge from what actually exists.

## Findings

### WORK item (1): Flag surface — confirmed, straightforward

- `orchestrate.md`'s `## Options` table already documents boolean-style flags following one
  consistent pattern: parsed by `parse-command-args.sh`, exported as a `*_FLAG` variable, threaded
  through `orchestrate.md`'s `### STAGE 0: PARSE AND DISPATCH` comment block, and passed into both
  the multi-task delegation-context JSON (`### MULTI-TASK DISPATCH`, `#### Step 4: Wave Execution`)
  and the single-task delegation-context JSON (`### STAGE 2: DELEGATE`). `--dry-run`,
  `--allow-self-modifying`, `--allow-scope-collision`, `--continue-budget`, `--clean` are all
  precedent for this pattern.
- `parse-command-args.sh` implements each flag as: a `TASK_NUMBERS`-independent regex match against
  `remaining` (e.g. `if [[ "$remaining" =~ --continue-budget ]]; then CONTINUE_BUDGET_FLAG="true"; fi`),
  a default-false initialization in "Step 4: Scan for flags," a strip from `FOCUS_PROMPT` in "Step
  5," and inclusion in the trailing `export` statement.
- **Divergence from precedent**: every existing flag in this file is a single boolean or single
  string value. `--research`/`--plan`/`--implement` are **composable** (per design report A2(iii),
  "`--research --plan` forces a fresh research round AND then plans, then STOPS") — this needs a
  *list*-shaped export, not three independent booleans consumed identically to the existing
  pattern's single-value flags. Two viable shapes: (a) three booleans (`FORCE_RESEARCH_FLAG`,
  `FORCE_PLAN_FLAG`, `FORCE_IMPLEMENT_FLAG`) that the command layer folds into an ordered
  `force_phases` JSON array before the Skill call (mirroring how `orchestrate.md` already folds
  `TEAM_MODE`/`TEAM_SIZE`/`TEAM_SIZE_EXPLICIT` into a derived `team_size_eff` before delegating);
  or (b) a single `FORCE_PHASES_FLAG` string (e.g. `"research,plan"`) built directly in the parser.
  Either way, the design report's example shape (`force_phases: ["research","plan"]`, ordered)
  must be threaded into both the single-task (`orchestrate.md` `### STAGE 2: DELEGATE`) and
  multi-task (`### MULTI-TASK DISPATCH` `#### Step 4: Wave Execution`) delegation-context JSON
  blocks — both exist today and both need the new field.

### WORK item (2): Phase-resolution override — mechanism identified, "Stage 1b/2" phrasing in the task description does not match a literal subsection

- `skill-orchestrate/SKILL.md` has **no bash `case` statement** mapping `current_status` to a
  handler. Handler selection is semantic: **Stage 4 ("State Handlers")** is organized as a
  sequence of prose sections headed `#### State: \`not_started\` or \`not started\``,
  `` `researching` ``, `` `researched` ``, `` `planning` ``, `` `planned` or `implementing` ``,
  `` `partial` ``, `` `blocked` ``, `` `completed` `` — the agent executing the skill picks the
  section whose heading matches the `current_status` value read fresh each loop iteration at
  **Stage 3, sub-step "3a. Read current task status"**.
- **"Stage 1b" in the task/design-report text does not refer to phase selection.** The file's
  actual "Stage 1b: Resolve Task-Type Routing" section is agent *routing* (mapping `task_type` to
  `$RESEARCH_AGENT`/`$PLANNER_AGENT`/`$IMPLEMENT_AGENT` via `command-route-agent.sh`), unrelated to
  which lifecycle phase runs. The functionally relevant sections are **Stage 1 ("Input
  Validation")**, where `continue_budget`/`clean_flag`/`effort_flag`/`team_mode` are already parsed
  from the delegation context (this is the natural place to also parse `force_phases`), and
  **Stage 3 ("State Machine Loop")**, whose per-cycle status read at 3a is what currently drives
  handler selection. This is worth flagging explicitly to the planner rather than silently
  resolving: the design report's own citation of "Stage 1b/2" may be a loose pointer rather than a
  precise section reference, and the plan should verify against the design report author's intent
  where practical, while treating the functional requirement (a `force_phases`-first override
  ahead of the state-machine loop) as unambiguous regardless of exact stage numbering.
- Implementing "check `force_phases` FIRST... run exactly the composed sequence... stop after the
  last named phase" (A2(iii)) requires new state tracking distinct from the existing
  `current_status`-driven default: an ordered list of not-yet-run forced phases, consumed one per
  loop cycle in place of (not in addition to) the status-derived handler selection, until the list
  is exhausted — at which point control must revert to the unforced default (status-derived) for
  any remaining forced-and-then-natural continuation, or simply terminate if `--implement` was the
  last named phase and it just completed. The design report's composability example (`--research
  --plan` on an `[IMPLEMENTED]` task "leaving the existing implementation artifact alone") confirms
  the loop must **stop**, not fall through to the implement handler once the forced list is
  exhausted.
- The **team_mode fork** and **hard_mode fork** patterns already present in every Stage 4 handler
  (`if [ "${team_mode:-false}" = "true" ]; then ... else ... fi`) are a directly reusable
  precedent for how a `force_phases`-driven branch could be layered onto the existing handler
  bodies without duplicating each handler's dispatch logic — worth the planner's attention as a
  low-duplication implementation strategy.

### WORK item (3): Postflight increment — the named target file is not in `/orchestrate`'s call path

This is the most significant finding of this research pass.

**What the task description asserts**: `orchestrator-postflight.sh`'s Stage 7a
(`# Stage 7a: Increment next_artifact_number (research only)`) increments `next_artifact_number`
only when `operation_type=research`, gated by a `do_artifact_increment` variable set inside the
`case "$operation_type" in ... esac` block near the top of the script (`research` →
`do_artifact_increment="true"`; `plan`/`implement` → `do_artifact_increment="false"`). **This part
is accurate as a description of the script's own internal logic.**

**What is not accurate**: that this script is part of `/orchestrate`'s live execution.

- A repo-wide grep for `orchestrator-postflight.sh` across every `SKILL.md` file shows exactly two
  hits: `skill-implementer/SKILL.md` (the plain `/implement` command's postflight) and
  `skill-git-workflow/SKILL.md` (which explicitly documents itself as "the documentation front...
  not literally invoked as a runtime script from bash," pointing back at
  `orchestrator-postflight.sh` Stage 9 as the real execution site for `/implement`'s commits only).
  **`skill-orchestrate/SKILL.md` has zero references to `orchestrator-postflight.sh`.**
- This is independently corroborated by an existing comment already in the source store:
  `context/patterns/batch-orchestration-guardrails.md`'s own reference table states, verbatim,
  regarding `scripts/orchestrator-postflight.sh`: *"Zero references anywhere in
  `skills/skill-orchestrate/SKILL.md` (confirmed by grep at authoring time) — this script belongs
  to a different command's postflight, not MT dispatch."*
- Tracing `/orchestrate`'s **actual** status/artifact postflight path:
  - **Single-task mode**: Stage 5 ("Handoff Reading"), in its "Shared postflight tail" subsection,
    calls `orchestrate-stage5-postflight.sh`, a *different* script from the one named in the task.
    That script's own `case "$dispatch_status" in researched|planned|implemented|...)` block calls
    `skill_postflight_update` (defined in `skill-base.sh`) for the status transition, and separately
    calls `skill_link_artifacts` (also in `skill-base.sh`) for artifact linking.
  - **Multi-task mode**: Stage MT-4 ("Phase-Aware Dispatch and Per-Task Postflight") calls the same
    two functions, `skill_postflight_update` and `skill_link_artifacts`, directly (its own
    documented per-task postflight sequence: "Call `skill_postflight_update`... Call
    `skill_link_artifacts` if artifact path is present").
  - **Neither `skill_postflight_update`, nor the `update-task-status.sh` script it calls, nor
    `skill_link_artifacts` contains any reference to `next_artifact_number`** — confirmed by
    exhaustive grep of all three. `update-task-status.sh`'s status-mapping function
    (`map_status()`) only ever sets a `STATE_STATUS`/`TODO_STATUS` pair from the
    `operation:target_status` combination; it never touches artifact numbering.
- **Net conclusion**: `/orchestrate` today never increments `next_artifact_number` for *any*
  phase, including research — not just plan/implement, as the task description's framing implies.
  This is corroborated by a second, independent piece of evidence: in single-task (non-team) mode,
  Stage 4's dispatch `context` tables for the research and plan handlers (`{ task_number,
  task_type, session_id, orchestrator_mode: true, lit_flag, task_dir, handoff_path, dispatch_seq
  }`) never include an `artifact_number` field at all — that field appears *only* in the Stage 3.6
  Team Fan-Out context shape (`{ teammate_letter, artifact_number, ... }`). `general-research-agent.md`
  documents reading `artifact_number` "from delegation context" with no described fallback for the
  case where it is absent — which it always is, in single-agent, non-team `/orchestrate` dispatch.
  (By contrast, `skill-researcher/SKILL.md`, the plain-`/research` base skill `/orchestrate`
  bypasses entirely, *does* increment `next_artifact_number` inline itself, independent of
  `orchestrator-postflight.sh`; that is a third, separate mechanism, only reachable via the plain
  `/research` command, not `/orchestrate`.)
- **Implication for the plan phase**: editing `orchestrator-postflight.sh`'s Stage 7a condition, as
  the task description literally directs, would change behavior for the plain `/implement`
  command's postflight (its only real caller) but would have **no effect whatsoever** on
  `/orchestrate --research`/`--plan`/`--implement`'s actual round-numbering, because that script is
  not in `/orchestrate`'s call graph. The functional target that would actually affect
  `/orchestrate` is `orchestrate-stage5-postflight.sh` (single-task) and the Stage MT-4 block
  (multi-task) — most naturally converged by adding the increment logic to the one function both
  paths already share, `skill_postflight_update` in `skill-base.sh`, gated on a new
  "this dispatch was force-invoked" signal threaded down from `force_phases`. This is a materially
  larger change than the design report's framing ("a single conditional change at one call site")
  — it also requires closing the pre-existing gap that `/orchestrate` never increments
  `next_artifact_number` today at all, and that the non-team dispatch context tables in Stage 4
  never even pass an `artifact_number` to the agent.
- **Open scope decision, deliberately not resolved by this research pass**: should the plan phase
  (a) treat "`/orchestrate` never increments `next_artifact_number` for any phase" as an in-scope
  prerequisite fix folded into this task (since the forced-phase increment cannot be built without
  a base increment mechanism to extend), or (b) scope this task strictly to the forced-phase case
  and file the base gap as a separate defect task, implementing WORK item (3) as new machinery
  gated only on `force_phases` without changing today's (currently nonexistent) unforced-research
  increment behavior? Both are defensible; the design report's own premise assumed (a) was already
  true, so this is a genuine judgment call for planning, not something this research pass should
  settle unilaterally.

### WORK item (4): Monotonic-max clamp — no existing mechanism to reuse; new logic needed

- `update-task-status.sh`'s `map_status()` function unconditionally resolves a `STATE_STATUS`/
  `TODO_STATUS` pair from the `operation:target_status` combination (e.g. `postflight:research` →
  always `"researched"`) with **no comparison against the task's current status** — confirmed by
  reading the full function body and confirming no `next_artifact_number`-adjacent regression-guard
  logic exists anywhere in the file (only one loosely related precedent: `postflight:pr_ready`
  always resolves to `"completed"` regardless of task type, documented in
  `context/standards/status-markers.md`'s "Target Arguments vs. Resting States" section as a
  request-vs-resting-state distinction — related in spirit, but not a regression guard).
- `context/standards/status-markers.md`'s "Valid Transition Diagram" section gives the natural rank
  order to encode for the clamp:
  `not_started(0) < researching(1) < researched(2) < planning(3) < planned(4) < implementing(5) <
  completed(6)`, with `partial`/`blocked` living outside this linear rank as non-terminal exception
  states per `rules/state-management.md`'s permissive model (any non-terminal status can transition
  anywhere; the design report's clamp only concerns the ordinary lifecycle-progress axis).
- **No status-rank table or comparison utility exists anywhere in the source store today** — this
  is new logic, not a wiring change. Two viable implementation sites: (a) a new opt-in flag on
  `update-task-status.sh` itself (parallel to the existing `--phase-check=warn|refuse` pattern
  already used for the implement-postflight phase-accounting backstop), which the forced-phase
  caller passes to request monotonic-max behavior instead of the script's default unconditional
  set; or (b) a pre-check in `skill_postflight_update` (or `orchestrate-stage5-postflight.sh`
  immediately before calling it) that reads the task's current status, compares rank against the
  target, and skips the call to `update-task-status.sh` entirely (while still running the
  artifact-linking half) when the transition would regress. Because WORK items (3) and (4) both
  touch this same call chain, the plan should design them together rather than as independent
  patches — e.g. a single new "forced postflight" code path in `skill_postflight_update` that
  applies both the artifact-number increment and the monotonic-max clamp under one `force_phases`-
  derived condition, rather than two separately threaded flags through the same functions.

### `skill-base.sh`'s `"prev"`-mode read — confirmed unaffected, as the design report states

- `skill_read_artifact_number` (in `skill-base.sh`) implements exactly the `"current"` vs `"prev"`
  modes the design report describes: `"current"` uses `next_artifact_number` as-is (research);
  `"prev"` uses `next_artifact_number - 1` (plan/implement, to land in the round research just
  opened). This function's logic requires no change for A2 — once WORK item (3)'s increment fires
  correctly for a forced phase (wherever it is actually wired), `"prev"`-mode callers continue to
  resolve into that same newly opened round unchanged, exactly as the design report specifies. This
  is confirmed, not merely assumed.

## Decisions

- None made by this research pass — WORK items (3)'s target-file substitution and the (a)/(b) scope
  question for the pre-existing increment gap are both left open for the plan phase, per this
  task's instruction not to silently resolve them.

## Recommendations

1. **Do not literally edit `orchestrator-postflight.sh`'s Stage 7a condition as the sole fulfillment
   of WORK item (3)** — it would be a correct-looking, ineffective change for `/orchestrate`. Target
   `orchestrate-stage5-postflight.sh` and the Stage MT-4 block instead, most likely by extending
   `skill_postflight_update` (the one function both single-task and multi-task postflight already
   share) to accept a force-invoked signal and perform the increment there.
2. **Design WORK items (3) and (4) together**, not as independent patches, since both modify the
   same postflight call chain and both are gated on the same "was this dispatch force-invoked"
   condition.
3. **Have the plan phase make an explicit (a)/(b) scope call** on whether fixing "`/orchestrate`
   never increments `next_artifact_number` for any phase, forced or not" is a prerequisite folded
   into this task, or a separately filed defect — and record that decision explicitly in the plan
   rather than letting it default silently either way.
4. **Verify the "Stage 1b/2" phrasing against the design report author's intent** where practical;
   treat Stage 1 (delegation-context parsing) and Stage 3 (the state-machine loop's per-cycle status
   read) as the two functionally relevant sites for `force_phases`, regardless of exact stage
   numbering used in the final plan.
5. **Use a JSON array for `force_phases`**, ordered as named on the command line, threaded through
   both the single-task and multi-task delegation-context JSON blocks in `orchestrate.md` — not
   three independently-consumed booleans at the skill layer — so Stage 1's parsing and Stage 3's
   loop-override logic have one canonical value to check "FIRST," per A2(ii).

## Risks & Mitigations

- **Risk**: implementing WORK item (3) narrowly against `orchestrator-postflight.sh` (per the
  task description's literal text) would pass a superficial code review (the named file did
  change, in the way described) while leaving `/orchestrate --plan`/`--implement`'s actual
  round-numbering completely unaffected. **Mitigation**: this report's dead-code finding, with its
  supporting evidence (zero grep hits, corroborating comment in
  `batch-orchestration-guardrails.md`), should be carried into the plan verbatim so the plan
  targets the real call path.
- **Risk**: folding the pre-existing "`/orchestrate` never increments `next_artifact_number`" gap
  into this task silently widens its scope well beyond "add three flags." **Mitigation**: the
  (a)/(b) decision above should be made explicitly and stated in the plan, not defaulted.
- **Risk**: a monotonic-max clamp implemented only in `update-task-status.sh` (site (a) above)
  could unintentionally affect unforced callers if the new flag's default is wrong. **Mitigation**:
  the clamp must be strictly opt-in, exercised only by the forced-phase postflight path, leaving
  every existing unforced caller (`skill-researcher`, `skill-planner`, `skill-implementer`, plain
  `/orchestrate` cycles) byte-for-byte unchanged.

## Appendix

- Task description's `SOURCE STORE IS THE EDIT TARGET` list: `agent-system/extensions/core/commands/orchestrate.md`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/scripts/orchestrator-postflight.sh`,
  `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/parse-command-args.sh`. Based on this report's findings,
  the plan should also consider `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh`
  and `agent-system/extensions/core/scripts/update-task-status.sh` as likely additional edit
  targets, or confirm via `git blame`/PR history whether `orchestrator-postflight.sh` was
  originally intended as a shared script that `skill-orchestrate` was meant to call but never was
  wired up.
- Design reference consulted in full: `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`,
  section "A2 -- Phase-Forcing Flags" (all four sub-questions (i)-(iv) plus the "Two consumption
  points" closing paragraph). Sections A3/A4 were also read for cross-reference; A2 does not depend
  on either landing first.
- Dependencies (Task 117, Task 122) confirmed `completed` prior to this research pass; not
  independently re-verified against their own artifacts in this report, per team-lead confirmation.
