# Research Report: Task #122

**Task**: 122 - Build the team-mode shared fan-out stage in skill-orchestrate
**Started**: 2026-08-31T00:00:00Z
**Completed**: 2026-08-31T00:00:00Z
**Effort**: standard
**Dependencies**: 117 (build_orchestrate_dispatch_prep_stage, completed), 119 (migrate_hard_mode_state_machine_logic, completed)
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, orchestrate.md, the three skill-team-*/SKILL.md files, synthesis-agent.md, context/contracts/territory.md, parse-command-args.sh), specs/116 design report and backlog manifest, specs/state.json
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The three team skills do **not** share one fan-out shape today. `skill-team-research` and
  `skill-team-plan` spawn a small, **fixed set of named roles** (Primary/Alternatives/Critic
  [/Horizons] for research; Version-A/Version-B/[Risk-Analysis] for plan), each writing a
  letter-suffixed artifact file under `specs/{NNN}_{SLUG}/{reports,plans}/`. `skill-team-implement`
  spawns a **dynamic, plan-driven set of phase implementers** (one per parallelizable plan phase,
  wave-scheduled by a dependency graph), with no letter convention, a debugger-teammate error-
  recovery role, and REAL file-ownership (source files, not artifact files) as its actual
  "territory" concern. The new shared stage must parameterize over this real difference, not just
  swap a `{phase}` string into one template.
- `context/contracts/territory.md` (H7) already defines the exact JSON shape
  (`owned_files`/`read_only_files`/`forbidden_files`, STOP-and-report duty on foreign work, commit
  protocol) for parallel-agent file ownership, is already wired into `skill-orchestrate`'s hard-mode
  implement handler (currently for a single dispatched agent), and its own header states it "remains
  fully applicable to multiple agents dispatched simultaneously... should parallel dispatch be
  re-enabled." Team-mode implement fan-out is exactly that re-enabling; reuse this contract's shape
  rather than inventing a second one.
- `synthesis-agent` is currently **orphaned**: its own file says it is "dispatched by
  `skill-team-research` (and in future by `skill-team-plan`)", but neither that skill nor any other
  file in the repo actually invokes it — `skill-team-research`'s Stage 8/9 synthesize inline in the
  lead's own context today. Task 122's delegation context states synthesis-agent "already runs as a
  fresh-context, phase-agnostic reader/writer and is not touched" — that framing describes what the
  agent is *built* to do, not what currently happens. The new fan-out stage should be the point where
  synthesis-agent actually goes live (dispatched for the research/plan synthesis step), which
  fulfills the design intent without editing the agent file itself.
- `parse-command-args.sh` already exports `TEAM_MODE`/`TEAM_SIZE` (consumed today by
  research.md/plan.md/implement.md), but it hardcodes `TEAM_SIZE=2` as the pre-flag default with no
  way to tell "user typed `--team-size 2`" apart from "no flag given, defaulted to 2". Task 122 asks
  for a **different** default policy (3 / 2-under-fast / 4-under-hard, per CLAUDE.md's documented
  cost table) than any of the three existing commands implement (each hardcodes a flat default of 2
  with a different clamp range: research 2-4, plan 2-3, implement 2-4). Implementing the requested
  table correctly requires either touching `parse-command-args.sh` (outside task 122's declared
  `file_scope`) or accepting an ambiguity where an explicit `--team-size 2` cannot be distinguished
  from the fast-mode default. This is flagged as a decision point for the plan phase, not resolved
  here.
- The "SubagentStop-postflight-to-owning-session correlation" piece named in the task description
  is a **live, previously-filed defect** (task 73, `correlate_subagent_postflight_hook_to_owning_session`,
  status `blocked`, explicitly RESCOPE-noted to retarget to this task) with a fully diagnosed root
  cause and four candidate fixes already written down (see Findings below) — this task does not need
  to re-derive the mechanism, only decide which of the four candidate fixes (or which combination)
  the new shared stage adopts.
- `--team` composes with `--hard`: the fan-out stage should invoke Stage 3.5 (Dispatch Prep) per
  teammate dispatch exactly as single-dispatch paths already do, which gets hard-mode contract
  injection and memory/`--lit` for free with no separate team-specific logic.

## Context & Scope

Task 122 (NEW-6 in the specs/116 backlog-operation-manifest) asks for one phase-parameterized
fan-out stage inside `skill-orchestrate/SKILL.md`, replacing the independently-duplicated fan-out
logic in `skill-team-research`, `skill-team-plan`, and `skill-team-implement` (which are deleted by
a separate, dependent successor task, NEW-7 / task 123 — not this task's job). `--team` and
`--team-size` flags must be added to `orchestrate.md`, whose Constraints section currently states
flatly `` `--team` flag not supported``. `synthesis-agent` is explicitly out of scope (unchanged).
The edit targets are exactly two files: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
and `agent-system/extensions/core/commands/orchestrate.md` — never `.claude/**`.

This research maps the concrete current-state shape of the three team skills, cross-references the
already-completed prerequisite work (`skill-orchestrate`'s Stage 3.5 Dispatch Prep and the hard-mode
H1/H5/H6 state-machine fork, tasks 117/118/119, all `completed`), and surfaces the exact points where
the "one shared stage, parameterized by phase" framing in the task description undersells real
structural differences between the three team skills' fan-out shapes.

## Findings

### Codebase Patterns

**`skill-orchestrate/SKILL.md`'s existing stage numbering and fork conventions** (3,679 lines
total; all of tasks 117-119 already landed):
- Stage 0: Multi-Task Mode Detection; Stage 1: Input Validation; Stage 1b: Task-Type Routing;
  Stage 2: Loop Guard Init; Stage 3: State Machine Loop; **Stage 3.5: Dispatch Prep** (line 576,
  the direct precedent for this task's new stage — see below); Stage 4: State Handlers (per-status
  bash blocks: `not_started`, `researching`, `researched`, `planning`, `planned`/`implementing`,
  `partial`, `blocked`, `completed`, `abandoned`/`expanded`, unknown); Stage 5: Handoff Reading;
  Stage 5a: Drift Inspection; Stage 5b: Churn Detection (H6, hard-only); Stage 6: Blocker
  Escalation; Stage 7: Loop Guard Update; Stage 8: Postflight. A parallel `## Multi-Task Mode`
  section (line 2084) repeats an analogous Stage MT-1..MT-5 shape for batches.
- **Stage 3.5 (Dispatch Prep) is the direct precedent to follow structurally**: it is invoked "once
  per dispatch (single-task and each multi-task wave member)" and every dispatch site references it
  with "a short pointer line rather than inlining a second copy" — its own text says "**Never
  duplicate this procedure at a dispatch site.**" (`skill-orchestrate/SKILL.md:576-585`). The new
  team fan-out stage should be built and referenced the same way: one canonical stage block, pointed
  to from every phase's dispatch site, parameterized by an input table exactly like Stage 3.5's own
  Inputs table (`phase`, `description`, `task_type`, `clean_flag`, `effort_flag`, `lit_flag`,
  `hard_mode`, `territory`, etc. at lines 586-598).
- **`hard_mode` fork precedent** (`skill-orchestrate/SKILL.md:908-919`, the `planned`/`implementing`
  handler): "D5 — the whole handler body is forked on `$hard_mode`." — `if [ "${hard_mode:-false}" =
  "true" ]; then <H1 per-phase dispatch> else <pre-existing whole-plan dispatch, byte-identical to
  before> fi`. This is the exact shape a `team_mode` fork should take at each of the three dispatch
  sites (`not_started`/`researching` for research, `researched`/`planning` for plan,
  `planned`/`implementing` for implement): `if [ "${team_mode:-false}" = "true" ]; then <call shared
  fan-out stage> else <existing single-agent Agent-tool dispatch, unchanged> fi`. `team_mode` and
  `hard_mode` are independent booleans (CLAUDE.md documents `--hard --team` as composable), so the
  fan-out stage's own per-teammate dispatch must itself call Stage 3.5 per teammate (passing
  `hard_mode` through) rather than bypassing it — this is how hard-mode contract injection reaches
  team members "for free," matching CLAUDE.md's claim that "`--hard` works with `--team`: team
  skills inject hard-mode contracts into each teammate."

**Three team skills, NOT one uniform shape** (this is the report's central finding):

| Aspect | `skill-team-research` | `skill-team-plan` | `skill-team-implement` |
|---|---|---|---|
| Teammate determination | **Fixed roles**: A=Primary, B=Alternatives, C=Critic (always), D=Horizons (always) — Stage 1 literally hardcodes `team_size=4` regardless of the `team_size` input parameter (`skill-team-research/SKILL.md:72-74`), a pre-existing internal inconsistency with its own declared `team_size` input | **Fixed roles**, count-gated: A=Incremental-Delivery, B=Alternative-Boundaries, C=Risk/Dependency-Analysis "if team_size >= 3" (`skill-team-plan/SKILL.md:212-297`) | **Dynamic, plan-driven**: one teammate per parallelizable *plan phase* in a dependency-wave schedule (Stage 5 dependency analysis, Stage 6 wave computation, Stage 8 wave-execution loop with trunk/branch detection), teammate count = `min(len(wave.phases), team_size)`, not a fixed role list at all |
| Output artifact naming | `{NN}_teammate-{letter}-findings.md` in `reports/` | `{NN}_candidate-{letter}.md` for A/B, but a *differently-named* `{NN}_risk-analysis.md` for C — not the same suffix convention as A/B | `phases/{RR}_phase-{P}-results.md` — keyed by **phase number**, not by teammate letter; no letter convention at all |
| Synthesis artifact | `{NN}_team-research.md` | `{NN}_{slug}.md` (implementation-plan-shaped) | No single synthesis artifact — Stage 11 "Create Implementation Summary" aggregates wave/phase outcomes, a different shape from a synthesized single research/plan document |
| File-collision risk | None (all teammates write to distinct artifact files under `specs/**`; no source-code files touched) | None (same as research) | **Real**: teammates edit actual source files per their assigned phase; this is the genuine "territory" concern — collision is on the *codebase*, not on `specs/**` artifact filenames |
| Extra roles | none | none | **Debugger teammate** (Stage 9), spawned ad hoc on a phase implementer's reported error, not part of the initial wave headcount |
| Wave count | Always 1 (no Wave 2 in v1, noted as "not implemented") | Always 1 | N sequential waves, computed from the plan's phase dependency graph, with "Y-shaped" trunk/branch special-casing |

**Consequence for the "phase-parameterized" design**: a single stage that takes `phase` as its only
axis of variation (as Stage 3.5 does for memory/lit/hard-contracts, which genuinely are uniform
across phases) will not correctly cover implement's dynamic wave/phase-driven teammate assignment,
debugger role, or real file-territory concern. The shared stage should factor into (a) a genuinely
shared "spawn N teammates, wait, collect, correlate session/postflight" skeleton — this part *is*
uniform across all three and is the actual duplication worth collapsing — and (b) a per-phase
**teammate-plan builder** sub-step that produces the list of (role-or-phase label, prompt, output
path, territory-or-none) tuples research/plan (fixed roles) vs. implement (dynamic wave/phase) each
supply differently. This is consistent with how Stage 4's per-status handlers already differ in
their *dispatch content* while sharing Stage 3.5 as a common sub-call — the same relationship should
hold between the new fan-out skeleton and each phase's teammate-plan builder.

**Reusable existing mechanisms, not currently used by the team skills**:
- `context/contracts/territory.md` (H7) already specifies the JSON shape
  (`owned_files`/`read_only_files`/`forbidden_files`), the STOP-and-report duty on foreign work, the
  commit protocol (verify-build-before-commit, rebase-not-force-push, incremental per-sub-task
  commits), and a Handoff Merge Rule for concurrent `.orchestrator-handoff.json` writes — all
  authored generically enough to apply to team-implement's per-phase teammates directly. Its own
  text: "the contract remains fully applicable to multiple agents dispatched simultaneously to work
  on different phases of the same plan should parallel dispatch be re-enabled" — team-implement fan-
  out is precisely that scenario. Reuse this file (already referenced from Stage 3.5's
  `hard_contracts_block` construction when `territory` is non-empty) rather than writing new
  file-ownership prose in the fan-out stage.
- `synthesis-agent.md` already implements a complete "read N teammate finding files in a fresh
  context, detect/resolve conflicts, gap-analyze, write one unified artifact" flow
  (`agents/synthesis-agent.md`, Stages 1-5+), explicitly scoped to be invoked by team skills. It is
  currently **dead code from the calling side**: `grep -rln "synthesis-agent"` across
  `agent-system/extensions/core/` matches only `manifest.json`, `lint-agent-contracts.sh`,
  `claudemd.md`, `index-entries.json`, and the agent file itself — no skill file dispatches it.
  `skill-team-research`'s own Stage 8/9 do synthesis inline in the lead's context instead. The new
  fan-out stage's research/plan synthesis step is a natural place to finally dispatch
  `synthesis-agent` via the Agent tool (fresh-context reader/writer, matching its own design) rather
  than perpetuating the inline-synthesis pattern — this makes task 122's "synthesis-agent... not
  touched" framing literally true (the agent file itself is unchanged) while also making the agent
  actually load-bearing for the first time. `skill-team-implement` has no analog (its Stage 11 is
  phase/wave aggregation, not multi-angle synthesis), so this only applies to the research/plan
  teammate-plan builders, not implement's.

**Command-flag plumbing already in place**: `parse-command-args.sh` already parses and exports
`TEAM_MODE` ("true"/"false") and `TEAM_SIZE` (integer), consumed today by
`research.md`/`plan.md`/`implement.md`. `orchestrate.md`'s own STAGE 0 already sources
`parse-command-args.sh` and threads several of its other exports (`CLEAN_FLAG`, `EFFORT_FLAG`, etc.)
into the Skill delegation context — the same pattern extends directly to `TEAM_MODE`/`TEAM_SIZE`
with no new parser flags needed, only new *consumption* in `orchestrate.md` and
`skill-orchestrate/SKILL.md`.

**Default-team-size mismatch (needs a plan-phase decision)**: `parse-command-args.sh` hardcodes
`TEAM_SIZE=2` as the pre-flag default (`scripts/parse-command-args.sh:79-80`), with no exported
signal distinguishing "explicitly typed `--team-size 2`" from "no flag given, defaulted". CLAUDE.md's
documented cost table (and task 122's own description) wants a *different*, effort-aware default:
3 baseline, 2 under `--fast`, 4 under `--hard`. None of the three existing commands implement that
table today — each hardcodes a flat default of 2 with its own clamp range (research 2-4, plan 2-3,
implement 2-4; `commands/research.md`, `commands/plan.md:433-442`, `commands/implement.md:22`). To
correctly implement the requested table, the new stage needs to know whether `TEAM_SIZE` was
user-supplied; today it cannot tell. Candidate resolutions (decide at plan time, not here):
(a) extend task 122's `file_scope` to include `scripts/parse-command-args.sh`, changing its default
export to empty/unset when `--team-size` is not given (a small, additive change — every existing
consumer already does its own `team_size=${team_size:-2}`-style fallback, so an empty export does
not silently break research.md/plan.md/implement.md before they are deleted by NEW-7/NEW-9); or
(b) accept the imprecision and only apply the 3/2/4 table when `TEAM_SIZE` equals the parser's own
default of 2, silently overriding an explicit `--team-size 2 --hard` request. (a) is the correct
fix; (b) is a documented compromise if `file_scope` cannot be widened.

**Existing, already-diagnosed defect this task must decide how to resolve** (task 73,
`correlate_subagent_postflight_hook_to_owning_session`, current status `blocked`, RESCOPE-noted in
its own description to retarget to task 122 once it lands — this is the
"SubagentStop-postflight-to-owning-session correlation" language in task 122's delegation context):
`hooks/subagent-postflight.sh`'s `find_marker()` runs `find specs -maxdepth 3 -name
".postflight-pending" -type f | head -1` — the FIRST marker anywhere under `specs/`, with **no**
correlation to which session/agent is actually stopping, even though the marker JSON already
carries a `session_id` field (written by `skill_create_postflight_marker` in `skill-base.sh`) that
the hook never reads. Because this hook is registered for the `SubagentStop` matcher, it fires on
**every** subagent stop, including a team-mode teammate that has no postflight obligation of its
own. Each such teammate stop increments the loop-guard counter in
`$TASK_DIR/.postflight-loop-guard` (cap `MAX_CONTINUATIONS=3`); with team_size=4, teammate stops
alone can reach the cap and cause the hook to `rm -f` the **orchestrator's own** `.postflight-pending`
marker, silently removing the premature-termination guard before the orchestrator's real postflight
has run — observed live in a `skill-team-research` 4-teammate run (task 73's description records the
exact incident). A later amendment to task 73 additionally requires demonstrating the fix corrects
downstream event misattribution in `specs/events.jsonl` (foreign subagent stops logged under the
marker-owning session's `session_id`). Task 73's description already enumerates four candidate
fixes to choose from: (a) read `session_id` out of the marker JSON and compare against the stopping
subagent's session before counting/deleting; (b) have the new fan-out stage suppress or scope this
hook for teammate subagents; (c) make the loop guard per-session rather than per-task-directory; (d)
make cap-reached vs. postflight-done distinguishable in the log. The plan phase should pick one (or
a combination) as part of building the new stage's session-correlation piece — this research does
not pre-commit to one, per task 73's own "evaluate, do not pre-commit" framing.

**Graceful-degradation precedent, already uniform across all three team skills**: each of
`skill-team-research`/`skill-team-plan`/`skill-team-implement` independently checks
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS != "1"` at its own "Stage 4: Check Team Mode Availability" and
falls through to a **direct Agent-tool dispatch of the single-agent subagent** (not a re-invocation
of the whole single-agent skill, to avoid double-running preflight/postflight) — see
`skill-team-research/SKILL.md:108-165` (Stage 4/4a/4c) for the fullest-documented version of this
pattern, including the explicit "do NOT invoke the whole skill-researcher skill" warning and the
`.degraded-fallback-note.json` side-channel for `degraded_to_single: true`. This is the exact check
task 122's description asks to preserve "as an early check in the same stage" — the new shared stage
should perform this check once, before any teammate spawn logic, mirroring this pattern rather than
inventing a new one.

### External Resources

Not applicable — this is a codebase-internal consolidation task with no external library or API
surface; no web research was needed or performed.

### Recommendations

1. **Stage placement and naming**: add a new stage immediately after Stage 3.5 (Dispatch Prep) —
   e.g. "Stage 3.6: Team Fan-Out" — invoked from each of the three dispatch-site handlers exactly the
   way Stage 3.5 already is, guarded by `team_mode` at the same `if/else` granularity the existing
   `hard_mode` fork (D5, `planned`/`implementing` handler) uses. Reference it with a pointer line at
   each call site; never duplicate the fan-out body inline (same discipline Stage 3.5's own text
   already mandates for itself).
2. **Factor into a shared skeleton + per-phase teammate-plan builder**, per the Findings-section
   table above: the shared skeleton owns team-availability check/fallback, teammate spawning via the
   Agent tool (with `model` parameter enforcement), wave-wait/timeout, result collection, the
   postflight session-correlation fix, targeted git staging, and cleanup — genuinely identical
   across phases. A per-phase builder function/branch (`case "$phase" in research|plan) <fixed
   roles>; implement) <dynamic wave/phase teammates + debugger> ;; esac`) supplies the actual
   teammate list, prompts, and output paths, since those are NOT uniform (see table above).
3. **Reuse `context/contracts/territory.md` verbatim** for implement's per-teammate file ownership,
   rather than writing new territory prose — pass a `territory` object per implement teammate the
   same shape Stage 3.5's existing (currently single-agent) hard-mode `territory` input already uses,
   generalized to N concurrent teammates.
4. **Wire `synthesis-agent` live** for the research/plan synthesis step (Agent-tool dispatch, passing
   teammate finding-file paths), replacing the current inline-lead-synthesis pattern in
   `skill-team-research`/`skill-team-plan` — this is additive to the agent file (no edit to
   `synthesis-agent.md` itself, satisfying "not touched") and resolves its current dead-code status.
   `skill-team-implement` has no synthesis step to convert (its Stage 11 is aggregation, not
   multi-angle synthesis).
5. **Call Stage 3.5 per teammate dispatch**, passing `hard_mode` through unchanged, so hard-mode
   contract injection and memory/`--lit` reach every teammate without new team-specific logic —
   this is what makes `--hard --team` composability (already documented in CLAUDE.md) work for free.
6. **`--team`/`--team-size` on `orchestrate.md`**: add both to the Options table (removing the
   "`--team` flag not supported" line from Constraints), threading `TEAM_MODE`/`TEAM_SIZE` from the
   already-sourced `parse-command-args.sh` into the Skill delegation context the same way
   `CLEAN_FLAG`/`EFFORT_FLAG` are already threaded (STAGE 0). Apply the 3/2-fast/4-hard default table
   inside `skill-orchestrate`'s own fan-out stage (not inside `parse-command-args.sh`'s clamp logic,
   which is shared with the soon-to-be-deleted commands) — see the default-mismatch finding above for
   the `file_scope` decision this requires.
7. **Session correlation**: adopt one of task 73's four candidate fixes as part of this stage's
   build (reading the marker's own `session_id` field before counting/deleting, per candidate (a), is
   the most directly evidenced minimal fix given the hook already writes but never reads that field)
   and verify the `events.jsonl` misattribution amendment task 73 records.

## Decisions

- None made unilaterally here — this is a research report; the factoring choice (shared skeleton vs.
  per-phase builder), the `parse-command-args.sh` file_scope question, and the specific
  session-correlation fix are flagged as plan-phase decisions with concrete options laid out above,
  not resolved by this report.

## Risks & Mitigations

- **Risk**: treating "phase-parameterized" too literally (one template, `{phase}` substituted) will
  silently break implement's dynamic wave/phase teammate model and its debugger role, which have no
  fixed-role analog. **Mitigation**: the shared-skeleton/per-phase-builder split above.
- **Risk**: the default-team-size ambiguity ships incorrectly (e.g., `--team-size 2 --hard` silently
  behaving like the fast-mode default). **Mitigation**: surfaced explicitly for a plan-time decision;
  do not silently pick option (b) without recording it as a known compromise if `file_scope` is not
  widened.
- **Risk**: reusing `context/contracts/territory.md` without checking whether the multi-task H7
  `territory` dispatch-key convention (single dispatched agent today) and the team-mode multi-
  teammate case can share one schema without collision in field meaning. **Mitigation**: the
  contract file's own JSON shape is already generic (`owned_files`/`read_only_files`/
  `forbidden_files` per agent); the plan phase should verify Stage 3.5's existing `territory` input
  row (currently documented as set only by the hard-mode single-phase H1 branch) can accept a
  per-teammate territory object without disturbing that existing caller.
- **Risk**: task 73's `events.jsonl` misattribution amendment is easy to treat as "someone else's
  problem" since it lives in a different task record. **Mitigation**: task 73 is explicitly
  RESCOPE-retargeted to land inside this task's own session-correlation piece — its acceptance
  criteria (foreign subagent stops no longer misattributed) should be treated as part of this task's
  own verification, not deferred again.

## Context Extension Recommendations

- **Topic**: Team-mode fan-out shape divergence.
  **Gap**: `context/patterns/team-orchestration.md` documents the wave-execution model and
  coordination responsibilities at a level generic enough to read as if all three team skills share
  one shape; it does not call out the fixed-role vs. dynamic-phase divergence this report found.
  **Recommendation**: once the new shared stage lands, update `team-orchestration.md` (or retire it
  in favor of inline documentation in the new stage, since the three separate skill files it
  describes will themselves be deleted by task 123) to describe the shared-skeleton /
  per-phase-builder split rather than a single uniform wave model.

## Appendix

**Files read in full or in substantial part**: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
(stage headers, Stage 3.5 in full, Stage 4 research/plan/implement dispatch sites, D5 hard-mode
fork), `agent-system/extensions/core/commands/orchestrate.md` (Constraints, Options, STAGE 0 flag
threading), `agent-system/extensions/core/skills/skill-team-research/SKILL.md` (in full),
`agent-system/extensions/core/skills/skill-team-plan/SKILL.md` (Stages 5-9),
`agent-system/extensions/core/skills/skill-team-implement/SKILL.md` (Stages 1-11),
`agent-system/extensions/core/agents/synthesis-agent.md` (header + Stages 1-2),
`agent-system/extensions/core/context/contracts/territory.md` (in full),
`agent-system/extensions/core/context/patterns/team-orchestration.md` (in full),
`agent-system/extensions/core/scripts/parse-command-args.sh` (TEAM_MODE/TEAM_SIZE parsing),
`specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A5, A6, A7),
`specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` (NEW-6/NEW-7
rows), `specs/state.json` (tasks 72, 73, 117-124 records).

**Searches/greps used**: `grep -rn "SubagentStop\|correlat"` across `agent-system/extensions/core/`;
`grep -rln "synthesis-agent"` across the same tree; `grep -n "territory\|SubagentStop\|correlat"`
across the three team skill files; `grep -n "team\|--team"` across `research.md`/`plan.md`/
`implement.md`/`parse-command-args.sh`; `python3`-driven `jq`-equivalent scans of `specs/state.json`
for tasks 117-124 status/dependencies and for the dispatch-prep task's title.
