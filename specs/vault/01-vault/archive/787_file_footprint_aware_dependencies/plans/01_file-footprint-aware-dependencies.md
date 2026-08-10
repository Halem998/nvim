# Implementation Plan: Task #787 - File-footprint-aware task dependency declaration

- **Task**: 787 - File-footprint-aware task dependency declaration (serialize same-file tasks)
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task #786 (completed)
- **Research Inputs**: specs/787_file_footprint_aware_dependencies/reports/01_file-footprint-aware-dependencies.md
- **Artifacts**: plans/01_file-footprint-aware-dependencies.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Multi-task creation currently populates a task's `dependencies[]` only from logical/user-declared
ordering; no code path compares the *file footprints* of sibling tasks, so two tasks that will edit
the same files can be placed in the same `/orchestrate` wave and dispatched concurrently. This plan
closes that gap at task-creation time: add an optional prospective `file_scope` field to the
state.json task schema, define a single shared directory-prefix overlap algorithm, extend
Multi-Task Creation Standard Component 4 to capture footprints and auto-add a serializing
dependency (visibly, overridably) on overlap, wire this into the three task-creating consumers
(`meta-builder-agent`, `skill-fix-it`, `skill-spawn`), and document that wave assignment is
file-safe because `dependencies[]` is now footprint-aware — plus an explicitly-adopted
defense-in-depth runtime wave-split check that closes the cross-batch residual gap. Definition of
done: `file_scope` is schema-documented (state.json-only, no TODO.md rendering), the overlap
algorithm exists in exactly one canonical location consumed by all callers, every touched dual-copy
file passes `diff -q` against its `extensions/core/` twin, and the separate-batch open decision is
resolved in writing.

### Research Integration

Integrates report `01_file-footprint-aware-dependencies.md`:
- `dependencies[]` is purely logical today; `/orchestrate` Step 3 (Kahn's) reads only
  `dependencies[]` and never re-derives file paths, so Scope items 1-3 make same-batch wave
  dispatch file-safe "for free" (no wave-algorithm code change required).
- `skill-team-implement.md` Stage 5 calls `infer_from_file_overlap(phase, phases)` but never
  defines it — the same primitive this task needs, one level down. The algorithm is therefore
  defined ONCE in a shared pattern doc and reused by both the new Component 4a logic and this
  pre-existing caller.
- H7 territory (`context/contracts/territory.md`) is hard-mode-only, per-phase, declarative, and
  has NO `extensions/core/` dual copy; `file_scope` promotes that concept to a lightweight
  task-level default. `territory.md` is not touched by this plan.
- `file_scope` (anticipated, creation-time) stays DISTINCT from `modified_files`/`files_touched`
  (actual, retrospective, from tasks 785/786) — complementary, never merged.
- Eight files are byte-identical dual copies under `.claude/extensions/core/`; the new pattern doc,
  `spawn-agent.md`, `skill-team-implement/SKILL.md`, and `multi-task-operations.md` were verified to
  also have core twins. Every edited file must update both copies and be `diff -q` clean.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Add optional `file_scope` (array of path/prefix strings, default `[]`) to the state.json task
  schema in both `state-management-schema.md` (field definition) and `state-management.md`
  (behavioral rule), state.json-only with no TODO.md rendering (mirrors `next_artifact_number`).
- Define one canonical directory-prefix overlap algorithm in a new shared pattern doc.
- Extend Multi-Task Creation Standard Component 4 with an automatic "4a" footprint-capture +
  overlap-detection sub-step that auto-adds a serializing dependency on overlap and surfaces it in
  the Component 7 confirmation summary (never silent, always overridable).
- Wire footprint capture + the shared overlap check into `meta-builder-agent`, `skill-fix-it`,
  `skill-spawn` (+ `spawn-agent.md` schema), and retro-fit `skill-team-implement.md`'s undefined
  `infer_from_file_overlap` to consume the shared algorithm.
- Document that `/orchestrate` and `--team` wave assignment treats footprint overlap as a
  serialization edge, and adopt a lightweight runtime wave-split check for the cross-batch case.
- Keep every dual-copy pair in sync (edit both, `diff -q`).

**Non-Goals**:
- No change to `modified_files`/`files_touched` semantics or to git-staging-scope behavior (785/786).
- No new first-class per-phase `Files:` field in `plan-format.md` (flagged as optional follow-up in
  research; out of scope here).
- No edits to `territory.md` (single-file, hard-mode H7 concept left intact).
- No glob/regex overlap matching — directory-prefix only, per research Decision.
- No repo-wide footprint scan; the runtime check reads `file_scope` only for the tasks already
  collected into a single `/orchestrate` invocation.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dual-copy drift (only project copy edited) | M | M | Every phase touching a paired file edits both copies and runs `diff -q` in Verification; Phase 5's runtime check and Phase 4's wiring both re-assert parity |
| Cross-batch conflicts invisible to creation-time-only fix | H | M | Phase 5 adopts the defense-in-depth runtime wave-split check (explicit Decision below) so `/orchestrate N,M` splits a wave when two in-wave tasks overlap with no edge |
| Heuristic `file_scope` inference wrong (too broad/narrow) | M | H | Bias inference toward over-declaring (broader prefixes) — false positives cost only parallelism; always surface auto-added edges for user override |
| Algorithm defined in more than one place (re-derivation) | M | M | Phase 2 creates ONE canonical doc; Phases 3-5 reference it by path, never restate the rule |
| `file_scope` confused/merged with `modified_files` | M | L | Schema subsection (Phase 1) explicitly cross-references and contrasts prospective vs retrospective |

### Explicit Decision: Cross-batch residual-risk defense-in-depth check — ADOPTED

The research flags an OPEN DECISION (Recommendation 5 / Risks): tasks created in *separate* batches
that touch the same files get no creation-time overlap comparison, so `/orchestrate 785,787` could
still co-schedule them if `dependencies[]` doesn't already encode the conflict. **This plan adopts
the lightweight runtime wave-split check** rather than deferring it. Rationale: task 787 exists
specifically to guarantee same-file tasks never dispatch concurrently; a creation-time-only fix
leaves a known hole for exactly the multi-batch orchestration case that motivated the task. The
check is cheap (reads `file_scope` only for the small `task_numbers` set already collected for that
invocation, reuses the Phase 2 algorithm, no repo-wide scan) and is a behavioral instruction the
orchestrating model executes, sized within one agent run. It is implemented in Phase 5 as a
documented step in `orchestrate.md` Step 3 and `skill-orchestrate/SKILL.md`: before dispatching any
wave with 2+ tasks, if two in-wave tasks have overlapping `file_scope` and no `dependencies[]` edge,
defer the lower-priority task to the next wave and log a visible warning.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 5 | 3 |

Phases within the same wave can execute in parallel. Phase 1 and Phase 2 touch disjoint files;
Phase 4 and Phase 5 touch disjoint files (this plan's own waves honor the file-footprint
non-overlap rule it implements).

### Phase 1: Add `file_scope` field to state.json schema [COMPLETED]

- **Goal:** Document the optional prospective `file_scope` task-schema field in both schema
  reference and behavioral-rule files (all dual copies), state.json-only, no TODO.md rendering.
- **Tasks:**
  - [x] In `.claude/context/reference/state-management-schema.md`: add a `file_scope` row to the
    `### Project Entry Fields` table (type `array of strings`, required `No`, default `[]`). *(completed)*
  - [x] Add a new `### File Scope Field` subsection modeled on the existing `### Dependencies Field`
    subsection: type, required=No, default `[]`, description ("Anticipated repo-relative paths or
    directory-prefixes this task expects to create or modify; used at task-creation time to detect
    same-file overlap with sibling tasks and derive serializing `dependencies[]` edges"),
    validation (paths need not exist; not a graph edge, so no cycle/self-reference checks), and an
    explicit contrast with `modified_files`/`files_touched` (prospective/creation-time vs
    actual/retrospective — NOT merged). *(completed)*
  - [x] State `file_scope` is state.json-only with no TODO.md surface (cite the
    `next_artifact_number` precedent) so no `generate-todo.sh`/rendering changes are needed. *(completed)*
  - [x] In `.claude/rules/state-management.md`: add one prose sentence noting `file_scope` is set at
    creation time, is descriptive/anticipated (not filesystem-validated), and is never mutated by
    status-sync. *(completed)*
  - [x] Mirror every edit into `.claude/extensions/core/context/reference/state-management-schema.md`
    and `.claude/extensions/core/rules/state-management.md`. *(completed: via cp + diff -q verified)*
- **Timing:** ~50 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/context/reference/state-management-schema.md` (+ `extensions/core/` twin)
  - `.claude/rules/state-management.md` (+ `extensions/core/` twin)
- **Verification:**
  - `diff -q` clean for both pairs.
  - `grep -n "file_scope" state-management-schema.md` shows the table row + the new subsection.
  - No TODO.md template or `generate-todo.sh` change introduced.

### Phase 2: Define shared file-footprint overlap algorithm [COMPLETED]

- **Goal:** Create the single canonical directory-prefix overlap algorithm doc that all consumers
  reference.
- **Tasks:**
  - [x] Create `.claude/context/patterns/file-footprint-overlap.md` defining: path normalization
    (strip trailing slash); the overlap rule (two entries overlap if `pathA == pathB`, or `pathA` is
    a directory-prefix ancestor of `pathB` i.e. `pathB` starts with `pathA + "/"`, or vice versa);
    pairwise-over-a-set pseudocode; a directory-vs-file example
    (`.claude/skills/skill-implementer/` conflicts with `.claude/skills/skill-implementer/SKILL.md`);
    and an explicit "Consumers" section naming the task-level caller (Component 4a) and the
    phase-level caller (`skill-team-implement.md` `infer_from_file_overlap`). *(completed)*
  - [x] State it is directory-prefix matching only (no glob/regex), per the research Decision. *(completed)*
  - [x] Create the `.claude/extensions/core/context/patterns/file-footprint-overlap.md` twin. *(completed)*
- **Timing:** ~40 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/context/patterns/file-footprint-overlap.md` (new; + `extensions/core/` twin)
- **Verification:**
  - `diff -q` clean for the new pair.
  - Doc contains the normalization rule, the bidirectional prefix rule, pseudocode, and a
    directory-vs-file worked example.

### Phase 3: Extend Multi-Task Creation Standard Component 4 [COMPLETED]

- **Goal:** Add automatic footprint-capture + overlap-detection sub-step "4a" that auto-adds
  serializing dependencies on overlap and surfaces them visibly.
- **Tasks:**
  - [x] In `.claude/docs/reference/standards/multi-task-creation-standard.md`, add sub-step
    **"4a. File Footprint Capture and Overlap Detection"** to Component 4, running automatically
    after Component 3 (Topic Grouping) — mirroring `/meta` Stage 3.5 (proactive, before the user is
    asked): populate each proposed task's `file_scope` from whatever structured signal the calling
    command has; run the shared algorithm (reference `file-footprint-overlap.md` by path, do not
    restate the rule) pairwise across the batch; for every overlapping pair with no existing edge,
    **auto-add** a dependency (later/lower-priority task depends on the other). *(completed)*
  - [x] Update Component 7 (confirmation summary) guidance to annotate auto-derived dependency cells
    with "(auto: file overlap)" so the user can override via the existing Custom/Revise path — never
    silent. *(completed)*
  - [x] Note that Components 5 (Kahn ordering) and 6 (Visualization) need no change — they consume
    the augmented `dependency_map` automatically. *(completed)*
  - [x] Update the compliance table if its columns imply footprint support status. *(completed: added Footprint Overlap (4a) column + optional-components checklist item)*
  - [x] Mirror into `.claude/extensions/core/docs/reference/standards/multi-task-creation-standard.md`. *(completed: via cp + diff -q verified)*
- **Timing:** ~50 min
- **Depends on:** 1, 2
- **Files to modify:**
  - `.claude/docs/reference/standards/multi-task-creation-standard.md` (+ `extensions/core/` twin)
- **Verification:**
  - `diff -q` clean for the pair.
  - Component 4a references `file-footprint-overlap.md` by path and `file_scope` by name.
  - Auto-add-with-visible-annotation behavior (not warn-only) is documented.

### Phase 4: Wire footprint capture into task-creating consumers [COMPLETED]

- **Goal:** Adopt Component 4a in the three creators (+ spawn-agent schema) and retro-fit the
  existing phase-level caller to the shared algorithm.
- **Tasks:**
  - [x] `.claude/skills/skill-fix-it/SKILL.md`: extend Section 8.2 to run the shared overlap check
    across `topic_groups[]` (each carries `file_section`), deriving `file_scope` per group by
    unioning tag `file:line` paths — in addition to the existing hardcoded NOTE-before-fix-it rule.
    *(completed: added Step 8.2c)*
  - [x] `.claude/agents/meta-builder-agent.md`: extend Interview Stage 3 to capture/infer each task's
    `file_scope` (user-stated files or the existing keyword-to-directory heuristic), then apply
    Component 4a before finalizing `dependency_map`. *(completed)*
  - [x] `.claude/agents/spawn-agent.md`: add `new_tasks[].file_scope` to the schema (populated from
    the agent's blocker/codebase research); `.claude/skills/skill-spawn/SKILL.md`: run the shared
    overlap check in postflight before finalizing `dependencies` merges. *(completed: added Stage 9.5)*
  - [x] `.claude/skills/skill-team-implement/SKILL.md`: point Stage 5's previously-undefined
    `infer_from_file_overlap(phase, phases)` at `file-footprint-overlap.md` (bonus fix — closes the
    named-but-undefined gap using the same primitive). *(completed)*
  - [x] Mirror every edit into the corresponding `.claude/extensions/core/` twin
    (`agents/meta-builder-agent.md`, `agents/spawn-agent.md`, `skills/skill-fix-it/SKILL.md`,
    `skills/skill-spawn/SKILL.md`, `skills/skill-team-implement/SKILL.md`). *(completed: via cp + diff -q verified for all 5 pairs)*
- **Timing:** ~60 min
- **Depends on:** 3
- **Files to modify:**
  - `.claude/skills/skill-fix-it/SKILL.md` (+ twin)
  - `.claude/agents/meta-builder-agent.md` (+ twin)
  - `.claude/agents/spawn-agent.md` (+ twin)
  - `.claude/skills/skill-spawn/SKILL.md` (+ twin)
  - `.claude/skills/skill-team-implement/SKILL.md` (+ twin)
- **Verification:**
  - `diff -q` clean for all five pairs.
  - Each consumer references `file-footprint-overlap.md` and `file_scope` (no re-derived algorithm).
  - `grep -n "infer_from_file_overlap" skill-team-implement/SKILL.md` now resolves to the shared doc.

### Phase 5: Document wave-assignment file-safety + adopt runtime wave-split [COMPLETED]

- **Goal:** Document why wave assignment is file-safe when `dependencies[]` is footprint-aware, and
  implement the adopted defense-in-depth runtime check for cross-batch tasks.
- **Tasks:**
  - [x] `.claude/commands/orchestrate.md` Step 3: add a note that wave-assignment file-safety is a
    property of `dependencies[]` accuracy (now established at creation time via Component 4a), so no
    change to the Kahn's-algorithm ordering itself is required for same-batch tasks. *(completed)*
  - [x] `.claude/commands/orchestrate.md` Step 3: add the adopted runtime wave-split check — before
    dispatching a wave with 2+ tasks, if two in-wave tasks have overlapping `file_scope` (shared
    algorithm) and no `dependencies[]` edge, defer the lower-priority task to the next wave and log a
    visible warning. Cite `file-footprint-overlap.md`. *(completed)*
  - [x] `.claude/skills/skill-orchestrate/SKILL.md`: mirror the same runtime-check behavior in the
    Multi-Task Mode section. *(completed: added step 4.5 in Stage MT-3)*
  - [x] `.claude/context/patterns/multi-task-operations.md`: add a note that footprint overlap is a
    serialization edge and clarify the same-batch vs cross-batch coverage (cross-batch handled by the
    runtime split). Note `/orchestrate` does not support `--team`; the `--team` footprint concern is
    the within-task phase-level path handled in Phase 4 (`skill-team-implement`). *(completed)*
  - [x] Mirror every edit into the corresponding `.claude/extensions/core/` twin. *(completed: via cp + diff -q verified for all 3 pairs)*
- **Timing:** ~50 min
- **Depends on:** 3
- **Files to modify:**
  - `.claude/commands/orchestrate.md` (+ twin)
  - `.claude/skills/skill-orchestrate/SKILL.md` (+ twin)
  - `.claude/context/patterns/multi-task-operations.md` (+ twin)
- **Verification:**
  - `diff -q` clean for all three pairs.
  - `orchestrate.md` Step 3 documents both the "file-safe for free" property and the runtime
    wave-split check, referencing `file_scope` and `file-footprint-overlap.md`.
  - `multi-task-operations.md` distinguishes same-batch vs cross-batch coverage.

## Testing & Validation

- [x] All dual-copy pairs pass `diff -q` (Phases 1-5):
      `state-management-schema.md`, `state-management.md`, `file-footprint-overlap.md`,
      `multi-task-creation-standard.md`, `meta-builder-agent.md`, `spawn-agent.md`,
      `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`, `skill-team-implement/SKILL.md`,
      `orchestrate.md`, `skill-orchestrate/SKILL.md`, `multi-task-operations.md`. *(verified: all 12 pairs diff -q clean)*
- [x] `file-footprint-overlap.md` exists in both trees and is referenced (not restated) by every
      consumer: `grep -rl "file-footprint-overlap" .claude/` lists Component 4a, all Phase 4
      consumers, and Phase 5 orchestrate docs. *(verified)*
- [x] `file_scope` documented as state.json-only: no new bracket-line added to TODO.md templates or
      `generate-todo.sh`. *(verified: no changes to generate-todo.sh)*
- [x] `file_scope` and `modified_files`/`files_touched` are described as distinct fields (grep the
      schema subsection for the contrast). *(verified)*
- [x] The cross-batch open decision is resolved in writing (this plan's Explicit Decision + Phase 5
      runtime check). *(verified)*
- [x] Optional smoke check: run `.claude/scripts/check-extension-docs.sh` if present; confirm no new
      broken cross-references. *(ran: pre-existing FAILs in [core] and [lean] extensions confirmed present on master before this task via git stash comparison; no new failures introduced)*

## Artifacts & Outputs

- `specs/787_file_footprint_aware_dependencies/plans/01_file-footprint-aware-dependencies.md` (this plan)
- New: `.claude/context/patterns/file-footprint-overlap.md` (+ `extensions/core/` twin)
- Edited (project + `extensions/core/` twin each): `state-management-schema.md`,
  `state-management.md`, `multi-task-creation-standard.md`, `meta-builder-agent.md`,
  `spawn-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`,
  `skill-team-implement/SKILL.md`, `orchestrate.md`, `skill-orchestrate/SKILL.md`,
  `multi-task-operations.md`
- `specs/787_file_footprint_aware_dependencies/summaries/01_*-summary.md` (at implementation)

## Rollback/Contingency

All changes are documentation/behavioral-contract edits to Markdown files under version control; no
executable code or state.json data is mutated. To revert, `git checkout` the touched files (both
project and `extensions/core/` copies) and delete the new `file-footprint-overlap.md` pair. Because
`file_scope` is an optional additive field defaulting to `[]`, partial completion is safe: existing
tasks and creators ignore an absent `file_scope`, so a stopped implementation degrades to current
behavior with no broken state. If the Phase 5 runtime check proves too aggressive (over-splitting
waves), it can be relaxed to warn-only by editing the two orchestrate files without touching
Phases 1-4.
