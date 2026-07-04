# Implementation Plan: Task #774

- **Task**: 774 - Hard-mode planning: smaller phases + skeleton plan with follow-up tasks
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 778 (COMPLETED — strategic-sorry skeleton policy in wrap-up.md / anti-analysis.md)
- **Research Inputs**: specs/774_hardmode_chunk_sizing_phase_subdivision/reports/01_skeleton_followup_phase_sizing.md
- **Artifacts**: plans/01_skeleton-followup-phase-sizing.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 774 is the PLANNING leg of the three-leg `--hard` model (research=777, planning=774,
implementation=772), built on task 778's already-merged strategic-sorry / relaxed zero-debt
policy. It revises `skill-planner-hard` / `planner-hard-agent` so that under `--hard`, plans
decompose into genuinely small bounded phases, and — when scope exceeds a few small phases —
produce a SKELETON plan (critical path with strategic sorries at division boundaries) plus
linked follow-up tasks, instead of inflating phase count or phase size. It also fixes two
pre-existing `skill-implementer-hard` Stage 3b defects so the smaller phases correctly drive
task 772's per-phase dispatch loop. Definition of done: the five in-scope files (all dual-copy)
are edited in lockstep to (a) tighten H8 with a bounded-unit primary criterion + phase-count
escape valve, (b) add a skeleton+follow-up decomposition mechanism with placeholder-token /
postflight-substitution task-number allocation, (c) add plan-time strategic-sorry schema to
`plan-format.md` reusing 778's exact field names, (d) fix the Stage 3b handoff path and
phase-selection bugs, and (e) settle the `follow_up_task` naming convention on plain integers.

### Research Integration

Integrated from `reports/01_skeleton_followup_phase_sizing.md`:
- **Finding 1** (H8 gap): current sizing uses a line-count ceiling (100-500 lines / 1-3 files)
  with no bounded-unit test and no phase-count escape valve → Phases 1, tightening approach.
- **Finding 2** (skeleton mechanism): `skill-spawn`/`spawn-agent` supply ~90% of the follow-up
  machinery but with the WRONG dependency direction (spawn makes the PARENT depend on new tasks;
  skeleton needs follow-ups to depend on the SKELETON) and lack the forward-reference /
  placeholder-substitution step → Phases 2, 4.1, 4.2. Decision recorded below: duplicate-with-
  modification inside `skill-planner-hard` postflight, NOT a shared helper (lower-risk first cut).
- **Finding 3** (schema reuse + naming inconsistency): reuse 778's `sorry_inventory` field names
  verbatim in a plan-time `## Planned Strategic Sorries` table; settle `follow_up_task` as a
  plain-integer task-number string → Phases 3, 2, 6.
- **Finding 4** (Stage 3b defects): un-scoped handoff path `specs/.orchestrator-handoff.json`
  (should be `${TASK_DIR}/...`) + integer-increment phase selection that cannot address N.1/N.2
  sub-phases or recognize skeleton exhaustion → Phase 5.
- **Finding 5 / Dual-copy notes**: all five files have deployed + `.claude/extensions/core/`
  copies requiring lockstep edits (mirror the pre-existing literature-script-name drift in the
  two SKILL.md files, do NOT "fix" it); `wrap-up.md` / `anti-analysis.md` are single-copy and
  OUT OF SCOPE → Phase 7 verification.

### Prior Plan Reference

No prior plan. This is the first plan for task 774.

### Preserved Assets

Task 778 (COMPLETED) is authoritative for the IMPLEMENT-TIME schema and MUST NOT regress or be
re-touched by this task:

| Component | File | Status | Verified |
|-----------|------|--------|----------|
| 5-condition strategic-sorry test | .claude/context/contracts/anti-analysis.md | [COMPLETED] | 778 |
| `skeleton` boolean + 7-field `sorry_inventory` schema `{file,line,statement,strategic,assumption,why_deferred,follow_up_task}` | .claude/context/contracts/wrap-up.md | [COMPLETED] | 778 |
| status/skeleton interaction table + `--hard`-only build-green exception | .claude/context/contracts/wrap-up.md | [COMPLETED] | 778 |

These two files are single-copy (no `extensions/core` dual) and are OUT OF SCOPE. Task 774's
schema work happens on the PLAN-TIME side in `plan-format.md` / `planner-hard-agent.md` only.

### Source-to-Implementation Mapping

| Source | Implementation target |
|--------|-----------------------|
| Research Finding 1 (H8 gap, lines 74-122) | Phase 1: planner-hard-agent.md H8 constraint + Stage 3 table |
| Research Finding 2 (skeleton mechanism, lines 124-205) | Phase 2 (agent-side emit) + Phases 4.1/4.2 (skill-side postflight) |
| Research Finding 3 (schema reuse, lines 207-253) | Phase 3 (plan-format.md) + Phase 6 (convention fix) |
| Research Finding 4 (Stage 3b defects, lines 255-307) | Phase 5: skill-implementer-hard Stage 3b |
| 778 `sorry_inventory` field names (wrap-up.md:12-63) | Phase 3 field-alignment (reuse verbatim, do not redefine) |

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (roadmap_flag not set). Task advances the `--hard`
regimented-chunking initiative (RC4 root cause; three-leg hard model 777/774/772).

## Postmortem Constraints

Binding rules for all implementation dispatches. Derived from the research report, task 778's
completed work, and the stated territory constraints.

**Do NOT**:
- Edit `wrap-up.md` or `anti-analysis.md` — 778 owns them; they are single-copy and the
  implement-time schema is final. 774's schema work is plan-time only.
- Edit `skill-orchestrate-hard` — that is task 772's territory (implementation leg). 774 only
  makes the skeleton/exhaustion condition *legible* to the orchestrator via Stage 3b output; it
  does not add orchestrator routing logic.
- Edit `skill-spawn` / `spawn-agent` — 774 mirrors their postflight pattern structurally
  (duplicate-with-modification) but does not modify them.
- Edit standard-mode `skill-planner` / `planner-agent.md` / `skill-implementer` /
  `general-implementation-agent.md` — scope is hard-mode only.
- Copy `skill-spawn` Stage 13 dependency wiring verbatim — that direction is BACKWARDS for the
  skeleton pattern (would make the skeleton task perpetually `[BLOCKED]`). Follow-up tasks must
  get `dependencies: [skeleton_task_number]`; the skeleton task's own dependencies are untouched.
- "Fix" the pre-existing literature-script-name drift between deployed and `extensions/core`
  SKILL.md copies — mirror it verbatim when editing.
- Redefine, rename, or re-touch the 778 `sorry_inventory` field names — reuse them exactly.
- Hard-cap H8 at a single line count (e.g. 100 lines) — the bounded-unit test is PRIMARY, line
  count is a secondary/advisory signal, per Research Risk 3.

**MUST preserve**:
- 778's `skeleton` boolean and `sorry_inventory` schema (see Preserved Assets).
- Byte-for-byte lockstep between each file's deployed copy and its `.claude/extensions/core/`
  copy (except the intentional pre-existing drift, which is mirrored, not removed).
- Existing working integer-increment behavior for dense `1,2,3` plans (the Stage 3b heading-scan
  replacement is a strict superset — identical output for dense plans).

**Design decisions are SETTLED** (do not re-open without concrete counterexample):
- **Dependency direction**: follow-up tasks depend on the skeleton task (inverse of skill-spawn).
- **Task-number allocation**: placeholder token `{{FOLLOWUP:i}}` written by the agent, resolved
  by a single `skill-planner-hard` postflight substitution pass (agent cannot allocate real
  `next_project_number`; only the skill postflight can, mirroring the spawn agent/skill split).
- **Postflight implementation**: duplicate-with-modification inside `skill-planner-hard`, NOT a
  shared `spawn-tasks-from-return.sh` helper (lower-risk, smaller diff; revisit only if a second
  consumer appears).
- **`follow_up_task` format**: plain-integer task-number string (e.g. `"781"`), never dotted
  `"774.2"`. The 778 worked example's dotted value is illustrative filler, corrected in Phase 6.
- **Schema home**: plan-time additions live in `plan-format.md` / `planner-hard-agent.md`, never
  in `wrap-up.md`.

## Goals & Non-Goals

**Goals**:
- Tighten H8 so a phase's PRIMARY sizing criterion is one bounded unit (one theorem / function /
  config-block / checklist item verifiable in isolation), with line count secondary and an
  explicit "exceeds N phases → produce a skeleton instead" escape valve.
- Add a skeleton+follow-up decomposition path to `planner-hard-agent` (emit skeleton phases +
  `new_tasks` array + placeholder tokens + `.skeleton-return.json`) and to `skill-planner-hard`
  postflight (allocate task numbers, reversed dependency direction, token substitution).
- Add plan-time schema to `plan-format.md`: `plan_metadata.skeleton` + `follow_up_tasks`, and a
  `## Planned Strategic Sorries` table reusing 778's exact `sorry_inventory` field names.
- Fix `skill-implementer-hard` Stage 3b handoff-path bug and replace integer-increment phase
  selection with heading-scan + skeleton-exhaustion detection.
- Settle and document the plain-integer `follow_up_task` convention.
- Keep every dual-copy file in lockstep.

**Non-Goals**:
- No edits to `wrap-up.md`, `anti-analysis.md`, `skill-orchestrate-hard`, `skill-spawn`,
  `spawn-agent`, standard-mode planner/implementer, or the lean/cslib anti-analysis overrides.
- No orchestrator-level follow-up-task routing logic (task 772's job).
- No shared bash helper extraction (explicitly deferred per settled decision).
- No new dotted sub-task ID system.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Circular sequencing: task numbers needed before plan file exists (or vice versa) | H | M | Placeholder-token + single postflight substitution pass (Phase 4.2): agent writes tokens once, skill patches once; no re-entrant dispatch |
| Copying skill-spawn Stage 13 verbatim wires deps backwards → skeleton perpetually [BLOCKED] | H | M | Phase 4.1 explicitly reverses direction; called out in Postmortem Constraints as SETTLED |
| Over-tightening H8 triggers over-splitting of legitimately-cohesive small changes | M | M | Bounded-unit test PRIMARY, line count advisory only (Phase 1); "one lemma / one checklist item / ~100-300 lines" as alternatives, not a strict AND |
| Stage 3b heading-scan regresses dense-integer plans | M | L | Heading-scan is a strict superset — identical result for `1,2,3`; only decimal/sparse numbering changes behavior (Phase 5 verification) |
| Dual-copy drift (edit one copy, forget the other) | M | M | Phase 7 diff-check of all five deployed vs extensions/core pairs; mirror pre-existing literature-script drift, do not remove it |
| Shared-file collision with task 779 (also edits skill-implementer-hard + general-implementation-hard-agent) | M | M | Note in Phase 5/6; serialize 774 and 779 implementation on these two files (do not run in parallel) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 5 | -- |
| 2 | 2 | 1 |
| 3 | 4.1, 6 | 2, 3 |
| 4 | 4.2 | 4.1 |
| 5 | 7 | 1, 2, 3, 4.1, 4.2, 5, 6 |

Phases within the same wave can execute in parallel. Note: Phases 1 and 2 both edit
`planner-hard-agent.md` and are therefore serialized (1 before 2) despite Phase 2's only hard
dependency being the escape-valve trigger introduced in Phase 1.

---

### Phase 1: Tighten H8 phase sizing in planner-hard-agent.md [COMPLETED]

- **Goal:** Make bounded-unit the PRIMARY sizing criterion, line count secondary, and add an
  explicit phase-count escape valve that triggers the skeleton path.
- **Tasks:**
  - [x] In `.claude/agents/planner-hard-agent.md` "Phase Sizing Constraint (H8)" (lines 33-46):
        replace the "~100-500 lines of output or 1-3 files" bullet with a bounded-unit primary
        criterion (one theorem / function / config-block / checklist sub-item, verifiable in
        isolation) and demote line count (~100-300 lines) to a secondary/advisory signal.
        *(completed)*
  - [x] Add a bounded-unit test independent of line count (targets the "single research-grade
        proof, small in lines but unbounded in attempts" failure mode from task 305). *(completed)*
  - [x] In the Stage 3 complexity table (lines 137-143): add an explicit phase-count ceiling
        (e.g. Complex capped at 6-8 phases) with "exceeds this ceiling → produce a SKELETON plan
        + follow-up tasks instead of inflating phase count or size" as the escape valve.
        *(completed)*
  - [x] Keep the existing N.1/N.2 per-phase splitting rule (it is orthogonal and still valid).
        *(completed)*
  - [x] Apply the identical edits to `.claude/extensions/core/agents/planner-hard-agent.md`
        (byte-identical dual copy). *(completed: verified via diff)*
- **Timing:** ~0.5 hours
- **Depends on:** none
- **Files to modify:**
  - `.claude/agents/planner-hard-agent.md` — H8 constraint + Stage 3 table
  - `.claude/extensions/core/agents/planner-hard-agent.md` — lockstep copy
- **Verification:** `diff` the two copies returns empty; grep confirms "bounded unit" primary
  language and an explicit phase-count escape-valve trigger are present.

---

### Phase 2: Add skeleton decomposition sub-stage + Context References + convention to planner-hard-agent.md [COMPLETED]

- **Goal:** Give `planner-hard-agent` the agent-side skeleton path: when Phase 1's escape valve
  fires, emit skeleton phases, a `new_tasks` array, placeholder tokens, and `.skeleton-return.json`.
- **Tasks:**
  - [x] Add a new Stage 4 sub-stage (Decompose into Phases): if scope exceeds the tightened H8
        ceiling, decompose into (a) a SKELETON set of phases covering the critical path ending in
        strategic-sorry division points, and (b) a `new_tasks` array reusing spawn-agent's exact
        0-based schema `{index, title, description, effort, task_type, dependencies}`. *(completed:
        added as Stage 4a)*
  - [x] Specify that the agent writes the plan file with placeholder tokens (`{{FOLLOWUP:i}}`) at
        each planned sorry deferral point and in the overview, and writes a `.skeleton-return.json`
        artifact declaring `new_tasks` + `dependency_order` (mirroring `.spawn-return.json`).
        *(completed)*
  - [x] Document the SETTLED reversed dependency direction (follow-ups depend on skeleton) so the
        agent populates `new_tasks[].dependencies` accordingly (skeleton task number substituted
        at postflight). *(completed)*
  - [x] Add `@.claude/context/contracts/wrap-up.md` and `@.claude/context/contracts/anti-analysis.md`
        to the agent's Context References list (currently absent) as the schema it must reuse.
        *(completed)*
  - [x] State the `follow_up_task` = plain-integer convention. *(completed)*
  - [x] Reference the new `## Planned Strategic Sorries` plan section (defined in Phase 3) in the
        "Required hard-mode additions to plan format" list (Stage 5), conditional on `skeleton: true`.
        *(completed)*
  - [x] Apply identical edits to `.claude/extensions/core/agents/planner-hard-agent.md`.
        *(completed: verified via diff)*
- **Timing:** ~0.75 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/agents/planner-hard-agent.md` — Stage 4 sub-stage, Context References, Stage 5 list
  - `.claude/extensions/core/agents/planner-hard-agent.md` — lockstep copy
- **Verification:** `diff` of the two copies empty; grep confirms `.skeleton-return.json`,
  `{{FOLLOWUP` token, `new_tasks` schema, and both contract files in Context References.

---

### Phase 3: Add plan-time strategic-sorry schema to plan-format.md [COMPLETED]

- **Goal:** Add the plan-time schema that reuses 778's field names, so plan-time pre-declaration
  is diffable against the implement-time `sorry_inventory`.
- **Tasks:**
  - [x] Extend the `plan_metadata` schema section (plan-format.md:27-47) with `skeleton` (bool)
        and `follow_up_tasks` (array of int), reusing the `skeleton` name from wrap-up.md.
        *(completed)*
  - [x] Add a new conditional plan section `## Planned Strategic Sorries` (present only when
        `skeleton: true`) with a table whose columns map field-for-field to the `sorry_inventory`
        schema: Division Point, Component (file/target — "TBD" if not yet created), Assumption,
        Why Deferred, Follow-Up Task. Note that `file`/`line`/`statement` are plan-time provisional
        ("to be confirmed by implementer") while `strategic: true` and `follow_up_task` are fixed.
        *(completed: "Component" implemented as a "File / Line / Statement" collapsed cell)*
  - [x] Note that an implementer-placed strategic sorry NOT on this table is a plan-unanticipated
        deviation (weaker claim under 5-condition test condition 1) and must be flagged, not
        silently accepted. *(completed)*
  - [x] Apply identical edits to `.claude/extensions/core/context/formats/plan-format.md`.
        *(completed: verified via diff)*
- **Timing:** ~0.5 hours
- **Depends on:** none
- **Files to modify:**
  - `.claude/context/formats/plan-format.md`
  - `.claude/extensions/core/context/formats/plan-format.md` — lockstep copy
- **Verification:** `diff` of the two copies empty; the five `## Planned Strategic Sorries`
  columns match the 778 `sorry_inventory` field names one-to-one.

---

### Phase 4.1: skill-planner-hard postflight — task allocation + reversed dependency wiring [COMPLETED]

- **Goal:** Add a postflight sub-stage that consumes `.skeleton-return.json` and creates real
  follow-up tasks with the CORRECT (reversed) dependency direction.
- **Tasks:**
  - [x] Add a new postflight sub-stage to `skill-planner-hard/SKILL.md` (after Stage 6, before
        Stage 7 status update) that: reads `.skeleton-return.json` if present; gets
        `next_project_number`; applies `dependency_order` (Kahn-sorted by the agent) to assign
        consecutive real task numbers; creates task directories; writes `state.json` entries —
        duplicating-with-modification `skill-spawn` Stages 7-11 (do NOT extract a shared helper).
        *(completed: added as Stage 6b, between existing Stage 6a and Stage 7)*
  - [x] Wire dependencies in the SETTLED reversed direction: each new follow-up task gets
        `dependencies: [skeleton_task_number]`; the skeleton (current) task's own `dependencies`
        are left untouched (the inverse of skill-spawn Stage 13). *(completed)*
  - [x] Record the resulting follow-up task numbers on the skeleton task's `plan_metadata`
        (`skeleton: true`, `follow_up_tasks: [...]`) per the Phase 3 schema. *(completed)*
  - [x] Regenerate TODO.md via `generate-todo.sh` after state writes. *(completed)*
  - [x] Mirror all edits to `.claude/extensions/core/skills/skill-planner-hard/SKILL.md`,
        preserving the pre-existing literature-script-name drift (do not "fix" it). *(completed:
        verified via diff — only the pre-existing drift lines differ)*
- **Timing:** ~0.75 hours
- **Depends on:** 2, 3
- **Files to modify:**
  - `.claude/skills/skill-planner-hard/SKILL.md`
  - `.claude/extensions/core/skills/skill-planner-hard/SKILL.md` — lockstep (mirror known drift)
- **Verification:** New sub-stage sets follow-up `dependencies: [skeleton_task_number]` (not the
  reverse); `diff` of the two copies shows ONLY the pre-existing literature-script-name drift.

---

### Phase 4.2: skill-planner-hard postflight — placeholder-token substitution pass [COMPLETED]

- **Goal:** Resolve `{{FOLLOWUP:i}}` tokens in the just-written plan file to real allocated task
  numbers (the step with no skill-spawn equivalent).
- **Tasks:**
  - [x] Add a postflight sub-stage (immediately after Phase 4.1's allocation) that performs a
        single text-substitution pass over the just-written plan file, replacing each
        `{{FOLLOWUP:i}}` token with the concrete allocated task number from Phase 4.1's mapping.
        *(completed: added as Stage 6c)*
  - [x] Ensure the substitution covers both the plan overview and the `## Planned Strategic
        Sorries` table `Follow-Up Task` column, so the plan (and the sorries the implementer later
        places from it) cite real, resolvable plain-integer task numbers. *(completed: plain
        text-substitution pass covers both locations since both use the same literal token)*
  - [x] Guard the pass to no-op cleanly when `.skeleton-return.json` is absent (non-skeleton plans).
        *(completed)*
  - [x] Mirror edits to `.claude/extensions/core/skills/skill-planner-hard/SKILL.md`.
        *(completed: verified via diff)*
- **Timing:** ~0.5 hours
- **Depends on:** 4.1
- **Files to modify:**
  - `.claude/skills/skill-planner-hard/SKILL.md`
  - `.claude/extensions/core/skills/skill-planner-hard/SKILL.md` — lockstep (mirror known drift)
- **Verification:** After a simulated skeleton return, no `{{FOLLOWUP:` token remains in the plan
  file; substituted values are plain integers; non-skeleton path leaves the plan untouched.

---

### Phase 5: Fix skill-implementer-hard Stage 3b defects [COMPLETED]

- **Goal:** Fix the un-scoped handoff path and replace integer-increment phase selection so the
  smaller / sub-phase / skeleton plans drive task 772's per-phase dispatch correctly.
- **Tasks:**
  - [x] Fix the handoff path in Stage 3b (`skill-implementer-hard/SKILL.md:129`) from
        `specs/.orchestrator-handoff.json` to `${TASK_DIR}/.orchestrator-handoff.json`, aligning
        with `skill-orchestrate-hard/SKILL.md:131`. *(completed)*
  - [x] Replace `next_phase=$((phases_completed + 1))` with a scan of the plan file's phase
        headings for the first `[NOT STARTED]`/`[PARTIAL]`/`[IN PROGRESS]` marker (mirroring the
        base agent's Stage 3 "Find Resume Point" pattern), so N.1/N.2 sub-phase headings and
        sparse numbering (`1, 2, 2.1, 2.2, 3`) are addressable. *(completed)*
  - [x] Add skeleton-exhaustion detection: when no incomplete phase is found AND the prior
        dispatch outcome was `skeleton == true`, emit an explicit
        `[hard-mode] Skeleton plan exhausted — N follow-up tasks pending: {list}` notice rather
        than looping on a nonexistent phase or silently no-op'ing. (Routing to follow-up tasks
        remains skill-orchestrate-hard's job — task 772 — out of scope here; Stage 3b only makes
        the condition legible.) *(completed)*
  - [x] Mirror edits to `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md`,
        preserving the pre-existing literature-script-name drift. *(completed: verified via diff)*
  - [x] NOTE for implementation sequencing: task 779 also edits this file — serialize 774 and 779
        on `skill-implementer-hard/SKILL.md` (do not edit concurrently). *(completed: no conflict
        observed at time of this dispatch)*
- **Timing:** ~0.5 hours
- **Depends on:** none
- **Files to modify:**
  - `.claude/skills/skill-implementer-hard/SKILL.md` — Stage 3b
  - `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md` — lockstep (mirror known drift)
- **Verification:** handoff path is `${TASK_DIR}/...`; phase selection is heading-scan based;
  exhaustion notice present; `diff` of the two copies shows ONLY the pre-existing drift.

---

### Phase 6: Settle follow_up_task convention in general-implementation-hard-agent.md [COMPLETED]

- **Goal:** Correct the dotted `"774.2"` worked-example value to a plain integer and note the
  convention (documentation-only; no schema change).
- **Tasks:**
  - [x] In `.claude/agents/general-implementation-hard-agent.md` line 238, change
        `"follow_up_task": "774.2"` to a plain-integer example (e.g. `"follow_up_task": "781"`).
        *(completed)*
  - [x] Add a one-line note that `follow_up_task` is a plain-integer task-number string (allocated
        via skill-planner-hard's placeholder-substitution mechanism), consistent with wrap-up.md's
        "owning follow-up task number or sub-phase" description — a documentation correction, not a
        schema change. *(completed)*
  - [x] Mirror edits to `.claude/extensions/core/agents/general-implementation-hard-agent.md`.
        *(completed: verified via diff)*
  - [x] NOTE for implementation sequencing: task 779 also edits this file — serialize with 779.
        *(completed: no conflict observed at time of this dispatch)*
- **Timing:** ~0.25 hours
- **Depends on:** 2
- **Files to modify:**
  - `.claude/agents/general-implementation-hard-agent.md`
  - `.claude/extensions/core/agents/general-implementation-hard-agent.md` — lockstep copy
- **Verification:** no dotted `"774.2"` remains; the example is a plain integer; `diff` of the two
  copies empty.

---

### Phase 7: Verification and dual-copy lockstep sync [COMPLETED]

- **Goal:** Confirm all in-scope edits are complete, dual copies are in lockstep, and no
  out-of-scope files were touched.
- **Tasks:**
  - [x] `diff` each deployed file against its `.claude/extensions/core/` copy:
        `planner-hard-agent.md`, `general-implementation-hard-agent.md`, `plan-format.md` must be
        byte-identical; the two SKILL.md pairs must differ ONLY by the pre-existing
        literature-script-name drift. *(completed: all three byte-identical; both SKILL.md pairs
        differ only by the 4 pre-existing literature-briefing-invoke.sh drift lines)*
  - [x] Confirm `git status` shows NO changes to `wrap-up.md`, `anti-analysis.md`,
        `skill-orchestrate-hard`, `skill-spawn`, `spawn-agent`, or any standard-mode planner/
        implementer file. *(completed: verified via git diff --stat across all task-774 commits —
        only the 5 in-scope dual-copy files + task-774 specs/ artifacts changed)*
  - [x] Run `bash .claude/scripts/check-extension-docs.sh` (doc-lint) and confirm it exits 0.
        *(deviation: doc-lint exits 1 overall due to a PRE-EXISTING, unrelated FAIL in the [lean]
        extension — `routing_hard` targets `skill-lean-research-hard`/`skill-lean-implementation-hard`
        declared but not deployed. Confirmed pre-existing via `git log --follow` on
        `.claude/extensions/lean/manifest.json` — the routing_hard block predates this task by 10+
        commits and the lean extension is untouched by task 774. The `[core]` extension entry
        (which covers all five in-scope files) reports `OK`.)*
  - [x] Grep-verify cross-references resolve: `## Planned Strategic Sorries` referenced from
        planner-hard-agent.md and defined in plan-format.md; both contract files present in the
        agent's Context References. *(completed)*
- **Timing:** ~0.25 hours
- **Depends on:** 1, 2, 3, 4.1, 4.2, 5, 6
- **Files to modify:** none (verification only)
- **Verification:** all diffs as expected; doc-lint exits 0; no out-of-scope files in `git status`.

## Testing & Validation

- [x] `diff .claude/agents/planner-hard-agent.md .claude/extensions/core/agents/planner-hard-agent.md` → empty.
- [x] `diff .claude/agents/general-implementation-hard-agent.md .claude/extensions/core/agents/general-implementation-hard-agent.md` → empty.
- [x] `diff .claude/context/formats/plan-format.md .claude/extensions/core/context/formats/plan-format.md` → empty.
- [x] `diff` of each SKILL.md pair shows ONLY the pre-existing literature-script-name drift.
- [x] Grep: bounded-unit primary criterion + phase-count escape valve present in H8 (Phase 1).
- [x] Grep: `.skeleton-return.json`, `{{FOLLOWUP`, `new_tasks` schema, and both contract files in
      planner-hard-agent Context References (Phase 2).
- [x] `## Planned Strategic Sorries` columns map 1:1 to 778 `sorry_inventory` field names (Phase 3).
- [x] skill-planner-hard postflight sets follow-up `dependencies: [skeleton_task_number]` and
      substitutes all `{{FOLLOWUP:i}}` tokens (Phases 4.1/4.2).
- [x] Stage 3b handoff path is `${TASK_DIR}/...`; phase selection is heading-scan; exhaustion
      notice present (Phase 5).
- [x] No dotted `"774.2"` remains anywhere (Phase 6).
- [x] `bash .claude/scripts/check-extension-docs.sh` exits 0 (Phase 7). *(deviation: exits 1
      overall due to a pre-existing, unrelated [lean] extension FAIL; the [core] entry covering
      all in-scope files reports OK — see Phase 7 notes)*
- [x] `git status` shows no out-of-scope files (Phase 7).

## Artifacts & Outputs

- `.claude/agents/planner-hard-agent.md` + extensions/core copy (Phases 1, 2)
- `.claude/context/formats/plan-format.md` + extensions/core copy (Phase 3)
- `.claude/skills/skill-planner-hard/SKILL.md` + extensions/core copy (Phases 4.1, 4.2)
- `.claude/skills/skill-implementer-hard/SKILL.md` + extensions/core copy (Phase 5)
- `.claude/agents/general-implementation-hard-agent.md` + extensions/core copy (Phase 6)
- specs/774_hardmode_chunk_sizing_phase_subdivision/summaries/01_skeleton-followup-phase-sizing-summary.md (on completion)

## Rollback/Contingency

All changes are markdown/skill-doc edits under `.claude/` and are fully revertible via
`git checkout -- <path>` per file, or `git revert` of the task commit. No runtime state,
migrations, or generated artifacts are produced by the edits themselves (follow-up task creation
only occurs when a real `--hard` plan later triggers the skeleton path). If dual-copy lockstep is
found broken post-merge, re-run the Phase 7 diffs and re-sync the offending pair. Because the two
SKILL.md files carry an intentional pre-existing drift, use the Phase 7 expected-drift baseline
(not "byte-identical") when validating those two pairs.
