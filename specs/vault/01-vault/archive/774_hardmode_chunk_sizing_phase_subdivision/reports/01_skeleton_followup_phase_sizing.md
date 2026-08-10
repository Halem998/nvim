# Research Report: Task #774

**Task**: 774 - Hard-mode planning: smaller phases + skeleton plan with follow-up tasks
**Started**: 2026-07-03T15:00:00Z
**Completed**: 2026-07-03T15:26:00Z
**Effort**: 3-6 hours
**Dependencies**: Task 778 (COMPLETED — strategic-sorry skeleton policy)
**Sources/Inputs**: Codebase (`.claude/skills/skill-planner-hard`, `.claude/agents/planner-hard-agent.md`,
  `.claude/skills/skill-implementer-hard`, `.claude/agents/general-implementation-hard-agent.md`,
  `.claude/skills/skill-spawn`, `.claude/agents/spawn-agent.md`, `.claude/context/contracts/wrap-up.md`,
  `.claude/context/contracts/anti-analysis.md`, `.claude/docs/reference/standards/multi-task-creation-standard.md`,
  `.claude/context/formats/plan-format.md`, `.claude/context/workflows/task-breakdown.md`, `specs/state.json`,
  `specs/TODO.md`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- H8 phase sizing today (`planner-hard-agent.md` lines 33-46) caps phases at "~100-500 lines /
  1-3 files", not per-lemma/per-checklist-item granularity, and its complexity table (Stage 3)
  tops out at "4-8 phases (Complex)" with no escape valve for objectives that genuinely need
  more than 8 phases — this is exactly the gap that produced the oversized "Phase 1 strike 3:
  prove merge_forward_succ" failure on task 305. Tightening H8 (smaller ceiling, e.g.
  ~100-300 lines, one-lemma/one-checklist-item unit rule) plus adding an explicit "exceeds a
  bounded skeleton" trigger closes this gap.
- `skill-spawn` + `spawn-agent` already implement essentially the entire "spawn linked follow-up
  tasks" mechanism task 774 needs (task definitions, Kahn's-algorithm task numbering,
  `dependencies` wiring, atomic state.json + TODO.md updates, git commit) — but for the WRONG
  dependency direction: spawn's blocker pattern makes the PARENT depend on the new tasks. Task
  774's skeleton pattern needs the OPPOSITE: follow-up tasks must depend on the (already-viable,
  shippable) skeleton task. This is a load-bearing correction the plan must make explicit, not a
  simple copy-paste reuse.
- The 778-established `sorry_inventory` schema (`{file, line, statement, strategic, assumption,
  why_deferred, follow_up_task}` in `wrap-up.md`) is implementer-side (post-hoc, filled in after
  a sorry is placed during implementation). Task 774 needs a planning-side counterpart that
  pre-declares the SAME fields before implementation starts, so each sorry's deferral comment
  can name a real follow-up task number when the implementer places it. This requires follow-up
  task numbers to be known/allocated at PLAN-WRITE time, which creates a sequencing problem:
  `planner-hard-agent` (the subagent) cannot allocate real state.json task numbers itself under
  the current architecture — `skill-planner-hard`'s **postflight** owns state.json writes. A
  placeholder-token + postflight-substitution pattern (detailed below) resolves this cleanly by
  mirroring `skill-spawn`'s existing Stage 7-16 postflight machinery.
- `skill-implementer-hard` Stage 3b (`SKILL.md:121-140`) has a genuine pre-existing bug
  (`handoff_file="specs/.orchestrator-handoff.json"` — missing the `${TASK_DIR}/` prefix that
  `skill-orchestrate-hard` correctly uses at `SKILL.md:131`) and a phase-selection strategy
  (`next_phase = phases_completed + 1`) that is purely integer arithmetic — it cannot address
  `N.1`/`N.2` sub-phases (already a documented H8 splitting convention in
  `planner-hard-agent.md:42`) or recognize when a skeleton plan's local phases are exhausted and
  the true next unit of work lives in a spawned follow-up task instead. Both must be fixed for
  the smaller-phase plans task 774 produces to actually drive task 772's per-phase dispatch loop.
- Dual-copy drift check: `skill-planner-hard/SKILL.md` and `skill-implementer-hard/SKILL.md`
  have a **pre-existing, unrelated** one-line drift between `.claude/skills/...` and
  `.claude/extensions/core/skills/...` (a literature-script invocation wrapper name change,
  `literature-briefing-invoke.sh` vs `literature-briefing.sh`) that predates task 774 and should
  be preserved/ported verbatim when editing, not "fixed" as part of this task's diff.
  `planner-hard-agent.md`, `general-implementation-hard-agent.md`, `plan-format.md`, and
  `task-breakdown.md` all have byte-identical dual copies today.

## Context & Scope

Task 774 is the PLANNING leg of a three-leg `--hard` model: research (task 777), planning (this
task), implementation (task 772) — all built on task 778's relaxed zero-debt / strategic-sorry
policy, which is **already implemented and merged**. This research does not re-derive 778's
policy; it reads the two contract files 778 extended (`wrap-up.md`, `anti-analysis.md`) as
already-final and asks how the planning leg should produce output that plugs into that schema,
and how the resulting smaller phases should flow into task 772's per-phase implementation loop.

Scope is hard-mode only: `skill-planner-hard` / `planner-hard-agent.md`, and the consuming side
in `skill-implementer-hard` Stage 3b / `general-implementation-hard-agent.md`. Standard-mode
`skill-planner` / `planner-agent.md` are out of scope and must not be touched.

## Findings

### 1. Current H8 Phase Sizing (exact language and gap)

`planner-hard-agent.md` "Phase Sizing Constraint (H8)" (lines 33-46):

```
- Completable in one agent run: ~100-500 lines of output or 1-3 files per phase
- Self-contained: Phase N does not depend on decisions to be made during phase N+1
- Verifiable: Clear done-criterion that can be checked without running the full system

Splitting rule: If a phase would require more than 500 lines of output or more than 4 hours,
split it into sub-phases. Sub-phases are numbered N.1, N.2, N.3.

Forbidden phase descriptions: Vague phase titles like "Implement core functionality",
"Write remaining code", or "Complete implementation" are not acceptable.
```

`planner-hard-agent.md` Stage 3 complexity table (lines 133-143):

```
| Complexity | Phase Count | Lines/Phase |
| Simple  | 1-2 phases | 50-200 lines |
| Medium  | 2-4 phases | 100-400 lines |
| Complex | 4-8 phases | 100-500 lines (split if larger) |

Sub-phase trigger: Any phase estimated to require >500 lines or >4 hours MUST be split.
```

**Gap**: the sizing constraint already knows about `N.1`/`N.2` sub-phase splitting for
oversized phases, but (a) the ceiling (500 lines / 4 hours) is generous enough that a phase
like "prove merge_forward_succ" (a single but research-grade lemma) fits under the ceiling by
line count while being unbounded in effort/uncertainty — line count is the wrong sole metric for
proof-shaped or research-grade work; and (b) there is no upper bound on total phase count or an
explicit trigger for "this objective needs more than N phases, stop inflating phases and split
the task itself." The Complex row caps at "4-8 phases (split if larger)" but does not say what
"split" means at the *phase-count* level — only at the *individual-phase-size* level. This is
precisely where task 774's skeleton-plus-follow-up mechanism must attach: item (2) of the task
description explicitly frames this as "when the objective exceeds a few small phases," i.e. a
NEW trigger orthogonal to the existing per-phase splitting rule.

**Recommended tightening** (for the plan to encode as literal SKILL.md/agent.md edits):
- Lower the ceiling for hard mode: "one lemma / one checklist sub-item / ~100-300 lines" per the
  task description, replacing "100-500 lines... 1-3 files."
- Add a bounded-unit test independent of line count: a phase is single-unit if it corresponds to
  exactly one theorem/function/config-block/checklist item that can be verified in isolation —
  not "line count under threshold." This directly targets the "Phase 1 strike 3" failure mode
  (a single research-grade proof that is small in line count but unbounded in attempt count).
- Add an explicit phase-count ceiling (e.g. Complex row capped at 6-8 phases FIRST, with
  "exceeds this — produce a skeleton + follow-up tasks instead of inflating phase count or
  phase size" as the escape valve), which is the trigger condition for Finding 2 below.

### 2. Skeleton-Plus-Follow-Up Decomposition Mechanism

**The reusable template already exists**: `skill-spawn` + `spawn-agent` implement Item Discovery
→ task definitions → Kahn's-algorithm ordering → atomic `state.json`/TODO.md task creation →
parent dependency linkage → git commit, exactly the "SPAWNS follow-up tasks (via task-spawn /
multi-task-creation)" mechanism item (2) calls for. Key artifacts:

- `spawn-agent.md` Stage 5 writes `.spawn-return.json` with schema:
  `{new_tasks: [{index, title, description, effort, task_type, dependencies}], dependency_order,
  parent_task_number, analysis_summary, report_path}` — 0-based internal indices, resolved to
  real task numbers only in the **skill's** postflight, not by the agent.
- `skill-spawn/SKILL.md` Stages 7-16 (postflight, `SKILL.md:231-469`) do the actual state work:
  read `.spawn-return.json` → get `next_project_number` → apply `dependency_order` (already
  topologically sorted) to assign consecutive real task numbers, foundational-first → create
  task directories → write `state.json` entries → **update parent's `dependencies` to include
  the new task numbers** (Stage 13) → regenerate TODO.md → git commit → cleanup.
- `multi-task-creation-standard.md` documents this as the general 8-component pattern (Item
  Discovery, Interactive Selection, Topic Grouping, Dependency Declaration, Task Ordering,
  Visualization, User Confirmation, State Updates) with `spawn-agent`/`skill-spawn` as one
  reference-adjacent implementation (alongside `meta-builder-agent` as the fullest reference).

**The one semantic bug in naive reuse — dependency direction**: `skill-spawn` is a
*blocker-driven* pattern: the PARENT task is stuck/blocked, so the parent's own
`state.json.dependencies` gets the new task numbers appended (Stage 13), meaning the parent
cannot resume until the spawned tasks complete. Task 774's skeleton pattern is the OPPOSITE
topology: the skeleton task is NOT blocked — per task 778's policy, a build-green
strategic-sorry skeleton is a valid, shippable `status: "implemented", skeleton: true` outcome
in its own right (it can go to `[PR READY]`/`[COMPLETED]` on its own). The follow-up tasks are
new tasks that depend on the skeleton landing first (they build on/discharge its strategic
sorries). So the correct dependency wiring is: **new follow-up task's own
`dependencies: [skeleton_task_number]`**, and the skeleton task's dependencies are left
untouched. This is a straightforward "External Dependencies" declaration per
`multi-task-creation-standard.md` §4, but it is the reverse of what `skill-spawn` Stage 13
does today, so a literal copy of that stage would wire the graph backwards and make the
skeleton task perpetually `[BLOCKED]` on work that hasn't started yet.

**The one missing piece — forward-reference from plan to not-yet-created task numbers**:
`spawn-agent` runs AFTER a blocker already exists (task creation is purely reactive/postflight;
the analysis report never needs to *cite* a new task's number inside a pre-existing artifact).
Task 774 is different: item (3) requires the SKELETON PLAN's own phase/sorry text (and the
sorries the implementer later places, per the `why_deferred`/`follow_up_task` comment
convention already established by 778) to **name** the follow-up task that will discharge each
division point. That means the follow-up task numbers must be known before or during plan-file
writing, but only `skill-planner-hard`'s postflight (not the `planner-hard-agent` subagent) is
positioned to allocate real `next_project_number` values and write `state.json` atomically
(mirroring the architectural separation `skill-spawn`/`spawn-agent` already use, and consistent
with `multi-task-creation-standard.md`'s "Foreground Requirement" — task creation/state writes
happen in the skill layer, not inside a delegated agent).

**Recommended mechanism** (for the plan to specify precisely):
1. `planner-hard-agent` Stage 4 (Decompose into Phases) gains a new sub-stage: if scope exceeds
   the tightened H8 ceiling (Finding 1), decompose into (a) a SKELETON set of phases covering
   the critical path, ending in one or more strategic-sorry division points, and (b) a
   `new_tasks` array using the *exact same 0-based-index schema* `spawn-agent.md` already uses
   (`index, title, description, effort, task_type, dependencies`) for each deferred part.
2. The agent writes the plan file with placeholder tokens in place of real task numbers at each
   sorry's planned deferral point and in the plan's overview (e.g. `{{FOLLOWUP:0}}`), plus a new
   `.skeleton-return.json` artifact (same directory pattern as `.spawn-return.json`) declaring
   `new_tasks` + `dependency_order`, so `skill-planner-hard`'s postflight can process it exactly
   as `skill-spawn` Stages 7-11 do (get next number, Kahn's order, create task dirs, write
   `state.json` entries) — with Stage 13's direction corrected per the finding above (new task
   `dependencies: [skeleton_task_number]`, not the reverse).
3. A new postflight sub-stage (no equivalent exists in `skill-spawn`, since spawn never needs to
   retroactively edit an artifact it already produced) performs a single text-substitution pass
   over the just-written plan file, replacing each `{{FOLLOWUP:i}}` token with the concrete
   allocated task number, so the plan (and, by the naming convention in item 3, the sorries the
   implementer later places from it) can cite real, resolvable task numbers.
4. The skeleton task's own `state.json` entry should record the resulting follow-up task numbers
   (recommend extending the existing `plan_metadata` object in `plan-format.md` — which already
   carries `phases`, `dependency_waves`, etc. — with `skeleton: bool` and
   `follow_up_tasks: [int]`, reusing the `skeleton` boolean name from `wrap-up.md` for
   terminology consistency between the plan-time and implement-time schemas).

This keeps `skill-spawn`/`spawn-agent` completely untouched (task 774 is explicitly scoped to
the planning leg) while reusing ~90% of its already-proven postflight machinery via structural
mirroring rather than direct code sharing (the two skills have different trigger conditions,
different dependency directions, and only `skill-planner-hard` needs the token-substitution
step) — the plan should decide whether to literally extract a shared bash helper (e.g.
`.claude/scripts/spawn-tasks-from-return.sh` parameterized by dependency direction) or keep the
postflight logic duplicated-with-modification inside `skill-planner-hard`. Given the direction
difference and the extra substitution step, a parameterized shared helper is the cleaner
long-term design but is itself extra scope the plan should size explicitly rather than assume.

### 3. Strategic-Sorry-to-Task Mapping — Reusing 778's Schema

778 already finalized, in `wrap-up.md` (lines 42-63) and `anti-analysis.md` (lines 59-83):
- The canonical 7-field `sorry_inventory` entry: `{file, line, statement, strategic, assumption,
  why_deferred, follow_up_task}`.
- The five-condition strategic-sorry test (deliberate division boundary from a **hard-mode
  plan's phase/part breakdown** — condition 1 explicitly anchors strategic-ness to planning
  output, condition 3 requires the comment to state "the owning follow-up task or sub-phase that
  will discharge it," condition 4 requires `follow_up_task` to be non-null and tracked).
- The `status`/`skeleton` interaction table and the `--hard`-only build-green exception.

This schema is implementer-side and post-hoc by construction (it records what a sorry *was*
after the fact). Task 774 must not redefine any of these fields — it must produce, on the
PLANNING side, the pre-declaration that makes conditions 1 and 3 satisfiable when the
implementer later places the sorry: for the plan to legitimately claim "this division point was
planned as part of a skeleton" and for the deferral comment to legitimately "name the follow-up
task," the plan artifact itself needs a table using the same field names, populated ahead of
time with `strategic: true` and a real `follow_up_task` number (resolved via the Finding 2
mechanism), leaving only `file`/`line`/`statement` as "planned, to be confirmed by implementer"
until the phase is actually implemented.

**Recommended addition to `plan-format.md`'s hard-mode section** (currently
`planner-hard-agent.md` Stage 5 lists 5 "Required hard-mode additions to plan format" —
Postmortem Constraints, per-phase output/done-criterion, Dependency Analysis wave table,
Preserved Assets, source-to-implementation mapping): add a 6th, conditional on
`skeleton: true` — a `## Planned Strategic Sorries` table with columns
`{Division Point, Component (file/target — TBD if not yet created), Assumption, Why Deferred,
Follow-Up Task}`, directly traceable field-for-field to the `sorry_inventory` schema in
`wrap-up.md` so that `skill-implementer-hard` (or a future validation script) can cross-check
that every sorry the implementer actually places was pre-declared in the plan (or explicitly
flag a new, plan-unanticipated strategic sorry as a deviation requiring the same 5-condition
test, since condition 1 requires the boundary to have been "planned as part of a skeleton" —
an ad hoc mid-implementation strategic sorry not on this table is a materially weaker claim and
should be called out, not silently accepted).

**Open naming inconsistency found**: `general-implementation-hard-agent.md`'s worked example
(added by 778, line 238) uses `"follow_up_task": "774.2"` — a dotted `{task}.{part}` string.
But every other task-numbering convention in the codebase (`multi-task-creation-standard.md`,
`spawn-agent.md`'s `new_tasks[].index` → real task number resolution, `state.json`'s
`project_number`) uses **plain integers** for real task numbers; there is no dotted sub-task ID
system anywhere else in the repo. This value is illustrative filler from 778, not a defined
convention. Task 774's plan should explicitly settle `follow_up_task`'s canonical format as a
plain integer task number string (e.g. `"781"`) once the Finding 2 mechanism resolves real
numbers — and should note this as a (non-breaking) documentation-only follow-up correction to
the existing worked example in `general-implementation-hard-agent.md`, not a schema change,
since `wrap-up.md`'s field description ("the owning follow-up task number **or sub-phase**")
already permits either.

### 4. Feeding Task 772's Implementation Leg — `skill-implementer-hard` Stage 3b

Current Stage 3b (`skill-implementer-hard/SKILL.md:121-140`, "Single-Phase Dispatch Context
(H1)"):

```bash
if [ "$orchestrator_mode" = "true" ]; then
  handoff_file="specs/.orchestrator-handoff.json"
  if [ -f "$handoff_file" ]; then
    phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file")
    next_phase=$((phases_completed + 1))
  else
    next_phase=1
  fi
fi
```

Two concrete defects, both directly relevant to task 774's smaller phases:

1. **Wrong/missing task-scoping in the handoff path.** `skill-orchestrate-hard/SKILL.md:131`
   correctly scopes the handoff to the task directory:
   `handoff_file="${TASK_DIR}/.orchestrator-handoff.json"`. `skill-implementer-hard` Stage 3b
   instead reads a single un-scoped `specs/.orchestrator-handoff.json` — a path that, taken
   literally, is shared across every task in the repo and would read stale/wrong data as soon as
   more than one hard-mode implementation round has ever run. This is a pre-existing bug,
   independent of task 774, but item (4)/(5) of the task explicitly calls for editing Stage 3b,
   so the plan should fix it in the same pass (align to `${TASK_DIR}/.orchestrator-handoff.json`).
2. **Pure integer-increment phase selection cannot address sub-phases or skeleton exhaustion.**
   `next_phase = phases_completed + 1` assumes a flat integer phase sequence. It cannot target
   `N.1`/`N.2` sub-phases (already a legal H8 output per `planner-hard-agent.md:42`, and MORE
   likely to occur now that H8 is tightened per Finding 1). It also has no way to recognize when
   a skeleton plan's own local phases are exhausted (`phases_completed == phases_total` with
   `skeleton == true`) versus genuinely unfinished — in the skeleton case, "next work" is not a
   local phase at all, it lives in a follow-up task's own plan (a different `task_number`,
   different `TASK_DIR`), which is an orchestrator-level (`skill-orchestrate-hard`) routing
   decision, not something Stage 3b can or should resolve on its own.

**Recommended Stage 3b changes**:
- Fix the handoff path to `${TASK_DIR}/.orchestrator-handoff.json` (bug fix, bundled since the
  stage is already being touched).
- Replace pure arithmetic phase selection with a scan of the plan file's phase headings for the
  first `[NOT STARTED]`/`[PARTIAL]`/`[IN PROGRESS]` marker (mirroring the base agent's own
  Stage 3 "Find Resume Point" pattern in `general-implementation-hard-agent.md:106-111`), which
  naturally handles `N.1`/`N.2` headings since it reads the literal heading text rather than
  incrementing an integer. This also makes Stage 3b robust to a plan whose numbering is
  `1, 2, 2.1, 2.2, 3` rather than a dense `1, 2, 3, 4, 5` sequence.
- When `phases_completed == phases_total` (or the scan finds no incomplete phase) AND
  `skeleton == true` was the prior dispatch's outcome, Stage 3b should recognize the LOCAL plan
  is exhausted and surface that explicitly (e.g. an `[hard-mode] Skeleton plan exhausted — N
  follow-up tasks pending: {list}` notice) rather than either looping on a nonexistent "phase
  N+1" or silently no-op'ing — the actual routing to follow-up tasks belongs to
  `skill-orchestrate-hard`'s dispatch-cycle logic (out of Stage 3b's scope, but Stage 3b's output
  needs to make the exhausted/skeleton condition legible to whatever reads it next).

### 5. Handoff Schema Extension — What's Genuinely New vs. Already Covered

778 already added everything task 774 needs on the **implement-time** (post-hoc) side of
`wrap-up.md`: the `skeleton` boolean, the 7-field `sorry_inventory`, the status/skeleton
interaction table, and the `--hard`-only build-green exception. Task 774 does not need to
re-touch those. What task 774 DOES need to add, per the findings above, is confined to the
**plan-time** side, and belongs in `plan-format.md` / `planner-hard-agent.md` rather than
`wrap-up.md` itself (consistent with `wrap-up.md`'s own scope note: "loaded exclusively by
hard-mode **dispatch** paths" — implementer/orchestrator, not the planner):
- `plan_metadata.skeleton: bool` and `plan_metadata.follow_up_tasks: [int]` (extends the
  existing `plan_metadata` object documented in `plan-format.md`).
- The `## Planned Strategic Sorries` plan section (Finding 3), field-aligned to
  `sorry_inventory` but explicitly plan-time/provisional.
- Explicit reference from `planner-hard-agent.md`'s Context References to
  `wrap-up.md`/`anti-analysis.md` for the schema it reuses (currently
  `planner-hard-agent.md`'s Context References list does not include either file — it lists
  `reference-grounding.md` but not `wrap-up.md` or `anti-analysis.md` — so the agent has no
  standing pointer to the schema it must reuse; this should be added).

### Dual-Copy / Deployment Notes

Confirmed via `diff`:
- `.claude/agents/planner-hard-agent.md` == `.claude/extensions/core/agents/planner-hard-agent.md`
  (byte-identical).
- `.claude/agents/general-implementation-hard-agent.md` ==
  `.claude/extensions/core/agents/general-implementation-hard-agent.md` (byte-identical).
- `.claude/context/formats/plan-format.md` == `.claude/extensions/core/context/formats/plan-format.md`
  (byte-identical).
- `.claude/context/workflows/task-breakdown.md` ==
  `.claude/extensions/core/context/workflows/task-breakdown.md` (byte-identical).
- `.claude/skills/skill-planner-hard/SKILL.md` vs.
  `.claude/extensions/core/skills/skill-planner-hard/SKILL.md`: differ ONLY in a literature
  script invocation name (`literature-briefing-invoke.sh` deployed vs. `literature-briefing.sh
  2>/dev/null` in extensions/core) — pre-existing, unrelated to task 774.
- `.claude/skills/skill-implementer-hard/SKILL.md` vs. the extensions/core copy: same
  pre-existing literature-script-name drift, also unrelated.
- `.claude/context/contracts/wrap-up.md` and `.claude/context/contracts/anti-analysis.md` have
  **no** `extensions/core` dual copy — they are deployed-only, single-source files (unlike
  formats/workflows, which are dual-copied). No sync concern for these two.
- `.claude/extensions/lean/context/contracts/anti-analysis.md` is a Lean4 override of the core
  contract and does **not** yet contain a strategic-sorry section (only a "Sub-Sorry Policy for
  Leaf Sorries" heading, no five-condition test) — confirming 778's own completion-summary note
  that "lean/cslib hard-mode overrides contradict the new core policy, flagged for a follow-up
  task via 772." This is out of scope for task 774 (planner-hard is domain-agnostic; the
  contradiction lives in the lean anti-analysis override) but is a useful pointer for whichever
  task eventually reconciles it.

**Conclusion for the plan**: every file task 774 needs to touch (`skill-planner-hard/SKILL.md`,
`planner-hard-agent.md`, `skill-implementer-hard/SKILL.md`,
`general-implementation-hard-agent.md`, `plan-format.md`) has a dual deployed/extensions-core
copy that must be updated in lockstep (mirroring the exact pre-existing drift where it exists,
not "fixing" it). `wrap-up.md`/`anti-analysis.md` are single-copy and any (minor,
Context-References-only) touches there do not need dual-copy propagation.

## Decisions

- Scope confirmed hard-mode only: no edits to `skill-planner`/`planner-agent.md`,
  `skill-implementer`/`general-implementation-agent.md`, or `skill-spawn`/`spawn-agent.md`
  themselves (774 mirrors/reuses their patterns structurally, it does not modify them).
- `follow_up_task` dependency direction: new follow-up tasks depend on the skeleton task
  (`dependencies: [skeleton_task_number]`), which is the inverse of `skill-spawn`'s
  blocker-driven Stage 13 pattern — this must be an explicit, named divergence in the plan, not
  an assumed copy-paste.
- Plan-time strategic-sorry pre-declaration reuses 778's field names exactly
  (`file/line/statement/strategic/assumption/why_deferred/follow_up_task`) rather than inventing
  a parallel plan-side vocabulary, to keep the plan-time table and implement-time
  `sorry_inventory` diffable.
- `wrap-up.md` and `anti-analysis.md` (778's files) are treated as closed/authoritative for the
  implement-time schema; task 774's schema work happens in `plan-format.md` /
  `planner-hard-agent.md` instead, per that file's own "hard-mode dispatch paths only" scope
  note.

## Risks & Mitigations

- **Risk**: Allocating real task numbers before the plan file exists (or vice versa) creates a
  circular sequencing dependency. **Mitigation**: placeholder-token + single postflight
  substitution pass (Finding 2, step 3) — the plan file is written once by the agent with
  tokens, then patched once by the skill postflight; no re-entrant agent dispatch needed.
- **Risk**: A parameterized shared helper extracted from `skill-spawn`'s postflight (Stages
  7-16) could itself become a multi-phase mini-task inside 774's own plan, inflating scope.
  **Mitigation**: the 774 plan should explicitly decide (as a phase-0 decision, not deferred)
  whether to extract a shared script or duplicate-with-modification inside
  `skill-planner-hard`'s postflight; duplication is lower-risk/smaller-diff for a first cut and
  is consistent with the existing "Maintenance note: changes to skill-planner postflight should
  be mirrored here" pattern already present in `skill-planner-hard/SKILL.md:14`.
- **Risk**: Tightening H8's ceiling too aggressively (e.g. hard-capping at 100 lines) could
  itself trigger analysis-paralysis-adjacent over-splitting for tasks that are legitimately one
  small cohesive change spanning slightly more than the cap. **Mitigation**: use the bounded-unit
  test (one theorem/function/checklist item) as the PRIMARY criterion and line count as a
  secondary/advisory signal, not a hard gate, consistent with the task description's phrasing
  "one lemma / one checklist sub-item / ~100-300 lines" (three alternative framings, not a
  strict AND).
- **Risk**: Stage 3b's plan-heading scan (replacing arithmetic increment) could regress the
  existing, working integer-increment behavior for plans that do NOT use skeleton/sub-phase
  numbering. **Mitigation**: the scan approach is a strict superset of behavior — for a dense
  `1,2,3...` plan, "first incomplete heading" and "phases_completed + 1" produce identical
  results; only decimal/sparse numbering benefits from the change.

## Context Extension Recommendations

- **Topic**: Lean4 hard-mode anti-analysis override lacks the strategic-sorry five-condition
  test present in the core `anti-analysis.md`.
- **Gap**: `.claude/extensions/lean/context/contracts/anti-analysis.md` overrides the core
  Sub-Sorry Policy but was not updated when 778 added the strategic-sorry skeleton section to
  core — confirmed by grep (`Sub-Sorry Policy for Leaf Sorries` heading only, no `strategic`
  keyword in the file at all).
- **Recommendation**: not task 774's scope (774 is domain-agnostic planning), but task 772
  (already flagged by 778's own completion summary as the intended home for this reconciliation)
  should port/adapt the five-condition test into the lean override before lean/cslib hard-mode
  implementation dispatches can legitimately claim skeleton outcomes.

## Appendix

### Search queries / investigation steps used
- `jq` lookups of task 774/778 in `specs/state.json` and `specs/TODO.md`.
- `find`/`diff` across `.claude/skills/`, `.claude/agents/`, `.claude/context/contracts/`,
  `.claude/context/formats/`, `.claude/context/workflows/`, and their `.claude/extensions/core/`
  and `.claude/extensions/lean/` counterparts, to establish dual-copy status.
- Full reads of `wrap-up.md`, `anti-analysis.md`, `planner-hard-agent.md`,
  `skill-planner-hard/SKILL.md`, `general-implementation-hard-agent.md`,
  `skill-implementer-hard/SKILL.md` (Stages 3b, 6), `skill-spawn/SKILL.md` (full), `spawn-agent.md`
  (full), `multi-task-creation-standard.md` (full), `task-breakdown.md`, `plan-format.md`.
- Targeted `grep` for `follow_up_task`, `N.1`/`N.2` sub-phase language, and
  `.orchestrator-handoff.json` path usages across skills/agents to locate the Stage 3b path bug.

### Key file references
- `.claude/agents/planner-hard-agent.md` (H8 constraint: lines 33-46; Stage 3 table: 133-143;
  Stage 5 plan-format additions: 181-189; Context References: 24-31)
- `.claude/skills/skill-planner-hard/SKILL.md` (Stage 4 delegation context: 228-260)
- `.claude/skills/skill-implementer-hard/SKILL.md` (Stage 3b: 121-140; Stage 6: 325-354)
- `.claude/agents/general-implementation-hard-agent.md` (Stage 5 worked skeleton example: 200-247)
- `.claude/context/contracts/wrap-up.md` (schema: 12-63; build-green invariant: 103-119)
- `.claude/context/contracts/anti-analysis.md` (strategic sorries: 59-83)
- `.claude/skills/skill-spawn/SKILL.md` (postflight Stages 7-16: 226-469)
- `.claude/agents/spawn-agent.md` (`.spawn-return.json` schema: 145-192)
- `.claude/docs/reference/standards/multi-task-creation-standard.md` (8-component pattern; §4
  External Dependencies; §8 state.json entry schema)
- `.claude/context/formats/plan-format.md` (`plan_metadata` schema)
