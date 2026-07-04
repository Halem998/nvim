# Research Report: Task #787

**Task**: 787 - File-footprint-aware task dependency declaration (serialize same-file tasks)
**Started**: 2026-07-04T00:00:00Z
**Completed**: 2026-07-04T00:00:00Z
**Effort**: 3-5 hours
**Dependencies**: Task #786 (completed)
**Sources/Inputs**:
- Codebase: `.claude/rules/state-management.md`, `.claude/context/reference/state-management-schema.md`,
  `.claude/docs/reference/standards/multi-task-creation-standard.md`,
  `.claude/context/contracts/territory.md`, `.claude/agents/meta-builder-agent.md`,
  `.claude/agents/spawn-agent.md`, `.claude/skills/skill-fix-it/SKILL.md`,
  `.claude/skills/skill-spawn/SKILL.md`, `.claude/skills/skill-orchestrate/SKILL.md`,
  `.claude/skills/skill-team-implement/SKILL.md`, `.claude/commands/orchestrate.md`,
  `.claude/context/patterns/multi-task-operations.md`,
  `.claude/context/formats/return-metadata-file.md`, `.claude/context/standards/git-staging-scope.md`,
  `.claude/context/formats/plan-format.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root cause is confirmed exactly as described: `dependencies[]` on a task entry is a purely
  **logical/user-declared** edge (populated via AskUserQuestion interview in `/meta`, hardcoded
  NOTE-before-fix-it in `/fix-it`, and blocker-order in `/spawn`) — nowhere in task creation is a
  proposed task's **file footprint** captured or compared against sibling tasks in the same batch.
- File-based serialization already exists as a concept, but only in two narrower forms: (a) H7
  territory contracts (`.claude/context/contracts/territory.md`), which are **hard-mode-only**,
  **per-phase within a single task's plan**, and purely declarative (no automated overlap
  detection); and (b) `skill-team-implement.md` Stage 5's `infer_from_file_overlap(phase, phases)`
  fallback heuristic, which is a **named but never algorithmically defined** function for
  cross-phase (not cross-task) overlap — this is the closest existing precedent and shares the
  exact same "what is the overlap algorithm" gap that 787 must resolve.
- `/orchestrate`'s multi-task wave assignment (Kahn's algorithm, `orchestrate.md` Step 3) operates
  **purely over the `dependencies[]` array already in state.json**. It does not re-derive or
  cross-check file paths at dispatch time. This means the correct architectural fix is almost
  entirely a **task-creation-time** fix (Scope items 1-3): if file-footprint overlap is converted
  into a real `dependencies[]` edge when tasks are created, wave assignment enforces serialization
  for free, with no changes needed to `orchestrate.md`/`skill-orchestrate.md` wave logic itself.
  Scope item 4 is therefore primarily a **documentation cross-reference** plus one recommended
  defense-in-depth runtime check (see Risks & Mitigations) for tasks created in separate batches
  that still land in the same wave.
- `file_scope` (anticipated, prospective, task-creation-time) is a natural complement to — not a
  duplicate of — the `modified_files`/`files_touched` self-report already added by tasks 785/786
  (actual, retrospective, populated during/after implementation for git staging scope). They
  should be named distinctly and cross-referenced, not merged into one field.
- Dual-copy discipline: `meta-builder-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`,
  `skill-orchestrate/SKILL.md`, `orchestrate.md`, `state-management.md`,
  `state-management-schema.md`, and `multi-task-creation-standard.md` all have byte-identical
  deployed copies under `.claude/extensions/core/`. `territory.md` does **not** have a core-extension
  copy (edits there are single-file). Any implementation plan for 787 must update both copies of
  the eight paired files.

## Context & Scope

Task 787 asks for multi-task creation to declare dependencies based on **file footprint overlap**,
not just logical sequencing, so two tasks that will edit the same files are never dispatched in the
same wave/run concurrently. Four scoped sub-items:

1. Add an optional task-level `file_scope` field to the state.json task schema.
2. Extend Multi-Task Creation Standard Component 4 to auto-capture footprints and auto-add
   dependencies/conflict warnings on overlap.
3. Wire into `meta-builder-agent`, `skill-fix-it`, `skill-spawn`.
4. Document that `/orchestrate` and `--team` wave assignment must treat footprint overlap as a
   serialization edge.

This report investigates each item against the current, verified state of the referenced files
(no fabricated line numbers — all citations below were read directly).

## Findings

### Codebase Patterns

#### 1. state.json schema — where `file_scope` belongs

- **Behavioral rules**: `.claude/rules/state-management.md` — this file is almost entirely about
  TODO.md/state.json synchronization mechanics (State-First Update Pattern, status transitions). It
  does **not** enumerate field-by-field schema; it defers to the schema reference file at its
  bottom (`## Schema Reference` section, pointing to
  `.claude/context/reference/state-management-schema.md`). This means `file_scope`'s *behavioral*
  rule (e.g., "captured at creation time, never mutated by status-sync") belongs in
  `state-management.md`, but its *field definition* belongs in the schema file.
- **Field reference**: `.claude/context/reference/state-management-schema.md` has:
  - A `### Project Entry Fields` table (schema lines 58-71) listing `project_number`, `project_name`,
    `status`, `task_type`, `effort`, `created`, `last_updated`, `dependencies`, `artifacts`,
    `next_artifact_number` — this table is the natural home for a new `file_scope` row.
  - A dedicated `### Dependencies Field` subsection (schema lines 188-206) with its own validation
    rules and TODO.md format-conversion table — this is the precedent pattern to mirror for a new
    `### File Scope Field` subsection: type (`array of strings`), required (`No`), default (`[]`),
    description ("Anticipated repo-relative paths or path-prefixes this task expects to create or
    modify — used at task-creation time to detect same-file overlap with sibling tasks; promotes H7
    territory declarations from hard-mode-only/per-phase to a lightweight task-level default"),
    validation (paths need not exist yet; no cycle/self-reference checks apply — this is not itself
    a graph edge, it's an input used to *derive* `dependencies[]` edges).
  - **TODO.md rendering**: `file_scope` is a good candidate for the same treatment as
    `next_artifact_number` (schema lines 112-149) — a **state.json-only** field with **no TODO.md
    surface**, since it's an internal planning-time signal, not user-facing status. This avoids
    adding a new bracket-format line to every TODO.md entry template across the system (would touch
    `generate-todo.sh`, `artifact-linking-todo.md`, and every command's confirmation-summary table).
- **Dual copy**: `.claude/extensions/core/rules/state-management.md` and
  `.claude/extensions/core/context/reference/state-management-schema.md` are byte-identical to the
  project copies (`diff -q` empty). Both must be edited together.

#### 2. Multi-Task Creation Standard Component 4 — current dependency capture

`.claude/docs/reference/standards/multi-task-creation-standard.md` Component 4 ("Dependency
Declaration", lines 153-193) is **entirely logical/user-driven**:
- The only interview question is "Do any tasks depend on others?" with options `No dependencies` /
  `Linear chain` / `Custom` (lines 158-168), followed by free-text `Task {N}: depends on Task {M}`
  capture (lines 170-177).
- Validation (lines 189-193) covers self-reference, valid-index, circular-dependency, and external
  task-number existence — **no file-path validation of any kind**.
- Component 3 ("Topic Grouping", lines 86-151) already clusters tasks by `file_section` +
  `issue_type` or shared `key_terms` (clustering algorithm lines 95-121) — this is the *closest*
  existing signal to a footprint, but it clusters items **into** a single task (fewer tasks touching
  the same files, by design), it does not compare footprints **across** already-separated tasks.
- Component 5 (Kahn's-algorithm ordering, lines 195-224) and Component 6 (Visualization) already
  consume whatever `dependency_map` exists — they need no changes; they will automatically respect
  new edges added by an overlap check, exactly as they respect user-declared edges today.
- The reference-implementation table (lines 370-385) shows `/meta`'s Interview Stage 3.5
  (AnalyzeConsolidation) is already an *automatic, proactive* pre-processing stage that runs before
  the user is asked anything — this is the direct precedent pattern for where a new **automatic
  footprint-overlap pre-processing stage** should sit: after Stage 3 (task list capture) / Component
  3 (Topic Grouping), and before or folded into Component 4's dependency interview, so any
  auto-detected overlap is presented to the user as part of (not instead of) the existing
  "Custom" dependency question — never silently injected.
- **Compliance table** (lines 389-397) confirms only `/meta` has full dependency support today;
  `/fix-it` has "Internal only" (the NOTE-before-fix-it hardcoded pair, see below); `/review` and
  `/errors` have none. Any Component 4 extension for file-scope should be written generically enough
  that `/fix-it` and `/spawn` (Scope item 3) can adopt it without re-deriving the algorithm.

#### 3. Territory contract (H7) — the existing per-phase, hard-mode analog

`.claude/context/contracts/territory.md` (89 lines) defines `owned_files` / `read_only_files` /
`forbidden_files` per **agent dispatch** within **hard-mode parallel phase execution of a single
task's plan** — it is declarative (the orchestrator manually lists files in the dispatch context;
lines 12-20, 71-82) with **no automated overlap-detection algorithm**. It has no dual-copy under
`.claude/extensions/core/` (confirmed: `.claude/extensions/core/context/contracts/` does not exist)
— editing it is a single-file change, unlike the other seven files below.

This confirms 787's framing exactly: H7 territory is (a) hard-mode-only, (b) per-phase not
per-task, (c) declarative not automatically derived from overlap detection, and (d) scoped to one
task's internal plan rather than sibling tasks created together in a batch.

#### 4. The one real precedent for automated overlap detection: `skill-team-implement.md` Stage 5

`.claude/skills/skill-team-implement/SKILL.md` Stage 5 ("Analyze Phase Dependencies", lines 190-231)
already has a **fallback heuristic** for exactly this problem, one level down (phases within one
plan, not tasks within one batch):

```
if not has_explicit_deps:
  dependency_graph = {}
  for phase in phases:
    dependency_graph[phase.number] = {
      "status": phase.status,
      "depends_on": infer_from_file_overlap(phase, phases),
      "files": phase.files_modified
    }
```

Critically, `infer_from_file_overlap(phase, phases)` is **called but never defined** anywhere in
the skill file (confirmed via grep — the function name and `phase.files_modified` appear exactly
once, at this call site, with no algorithm body, no path-matching rule, no directory-vs-file
distinction). This is the exact same unresolved gap 787 needs to close, just one level up (tasks
instead of phases). **Recommendation**: define the overlap algorithm once, in a shared location,
and have both this call site and the new Component 4 logic consume it — see Recommendations below.

Also note: `plan-format.md` (the plan document schema) has a per-phase **`Depends on:`** field
(lines 70-78) but **no per-phase `Files:`/footprint field** — so `phase.files_modified` in
`skill-team-implement.md` is presumably parsed loosely from the "Tasks:" checklist bullets or
"Artifacts & Outputs" section, not a first-class structured field. If 787's file-footprint concept
is generalized well, it could also motivate adding a first-class `Files:` field to
`plan-format.md`'s per-phase format — flagged as an optional follow-up, out of the current task's
stated scope (state.json task schema, not plan-file phase schema).

#### 5. `meta-builder-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md` — current task-creation schemas have no file field

- **meta-builder-agent.md**: Interview Stage 3 (`IdentifyUseCases`, lines 244-383) captures
  `task_list[]` (free-text titles from the user) and `dependency_map{}` (index -> index, from the
  Question 5 interview). Neither `task_list` nor the `new_tasks` schema used at Stage 6
  (`CreateTasks`, lines 611-699) has any file-path or file-scope field — task descriptions are
  free text with no structured file association.
- **skill-fix-it/SKILL.md**: this is the *easiest* wiring target, because FIX:/NOTE:/TODO: tag
  discovery (Component 1, `grep -rn`) inherently produces a `file:line` for every item, and the
  clustering algorithm already groups by `file_section` (Component 3, lines 211-212 in the standard,
  mirrored in skill-fix-it's own topic-grouping logic). A task's `file_scope` can be derived nearly
  for free by unioning the source file paths of the tags assigned to that task's group. Section 8.2
  ("Dependency-Aware Task Creation Order", lines 255-303 of skill-fix-it/SKILL.md) only implements
  one hardcoded dependency pattern today (NOTE-tagged learn-it task before its paired fix-it task);
  it has no general cross-group file-overlap check.
- **skill-spawn/SKILL.md** + **spawn-agent.md**: `spawn-agent.md`'s `new_tasks[]` schema (agent file
  lines ~180-186) has `index`, `title`, `description`, `effort`, `task_type`, `dependencies` — no
  file field. `skill-spawn/SKILL.md`'s postflight (`dependency_order`-driven task creation, lines
  ~250-406) consumes `spawn-agent`'s `new_tasks[].dependencies` (internal indices) directly into
  state.json. Since `spawn-agent` already investigates the blocked task's plan/codebase to propose
  fixes, it is well-positioned to also report anticipated `file_scope` per proposed subtask — but
  this is the lowest-leverage wiring point of the three, because spawn-created tasks are usually
  already serialized behind the blocked parent task (the parent depends on all of them, and they
  often depend on each other in a chain already derived from the blocker's root-cause analysis).

#### 6. `/orchestrate` and `--team` wave assignment — where footprint overlap must land

- `orchestrate.md` Step 3 ("Topological Wave Assignment (Kahn's Algorithm)", lines 108-153) builds
  waves **exclusively from the `dependencies[]` values already present in state.json** for the
  batch of tasks being orchestrated (confirmed by reading the implementation, lines 111-149). It
  does not read file paths, plans, or artifacts to compute waves.
- `.claude/context/patterns/multi-task-operations.md` (lines 510-578) documents this design
  explicitly: "Only dependencies between tasks **within the current batch** affect wave assignment.
  External dependencies... are ignored for ordering purposes" (line 520) — i.e., the wave dispatcher
  trusts `dependencies[]` completely and has no independent file-safety check.
- **Consequence**: if Scope items 1-3 succeed (footprint overlap becomes a real `dependencies[]`
  edge at creation time), Scope item 4's wave-assignment enforcement is **already satisfied** by the
  existing Kahn's-algorithm code — no code change needed in `orchestrate.md`/`skill-orchestrate.md`,
  only a **documentation note** explaining *why* wave assignment is file-safe (it trusts a graph that
  is now footprint-aware at construction time).
- **Gap this does NOT cover**: tasks created in *separate* multi-task-creation batches (e.g., task
  787 created weeks after task 785, both edit `orchestrator-postflight.sh`) have no creation-time
  opportunity to compare footprints against each other, since Component 4's overlap check only runs
  within a single creation batch. If both later end up `not_started`/`researched` simultaneously and
  are orchestrated together via `/orchestrate 785,787`, today's wave assignment would still place
  them in the same wave if state.json's `dependencies[]` doesn't already encode the conflict. This is
  a real residual risk that a documentation-only fix does not close — see Risks & Mitigations for a
  proposed lightweight defense-in-depth check.
- `--team` mode: per `multi-task-operations.md` line 558, `/orchestrate` does not support `--team`
  (task-level team parallelism and wave dispatch are mutually exclusive by design). The `--team`
  angle that matters here is **within a single task**, at the `skill-team-implement.md` Stage 5
  phase level (finding #4 above), which is a separate (already-identified) gap from the
  cross-task, `/orchestrate`-level gap that 787's Scope items 1-3 target.

### External Resources

No web research was needed; this is a self-contained internal-tooling gap. All findings are
grounded in direct reads of the referenced files.

### Recommendations

1. **Schema addition** (Scope item 1): Add `file_scope` (array of strings, optional, default `[]`)
   to the Project Entry Fields table and a new `### File Scope Field` subsection in
   `state-management-schema.md` (+ core-extension dual copy), modeled directly on the existing
   `### Dependencies Field` subsection. No TODO.md rendering (mirrors `next_artifact_number`'s
   state.json-only precedent). Add one sentence to `state-management.md`'s prose noting `file_scope`
   is set at creation time and is descriptive/anticipated, not validated against the filesystem.

2. **Shared overlap-detection algorithm** (Scope items 2 and 4, and closes the
   `skill-team-implement.md` gap in finding #4 as a side effect): define ONE algorithm, once, in a
   new shared context file (e.g. `.claude/context/patterns/file-footprint-overlap.md`), used by both
   the new Component 4 logic and (opportunistically) `skill-team-implement.md`'s
   `infer_from_file_overlap`. Recommended rule: normalize each path (strip trailing slash); two
   entries overlap if `pathA == pathB`, or `pathA` is a directory-prefix ancestor of `pathB` (i.e.
   `pathB` starts with `pathA + "/"`), or vice versa. This directory-prefix rule is what lets a
   coarse footprint like `.claude/skills/skill-implementer/` correctly conflict with a fine-grained
   footprint like `.claude/skills/skill-implementer/SKILL.md`.

3. **Multi-Task Creation Standard Component 4 extension** (Scope item 2): add a sub-step —
   "4a. File Footprint Capture and Overlap Detection" — that runs automatically (same style as
   `/meta`'s Stage 3.5 AnalyzeConsolidation: proactive, before the user is asked) immediately after
   Component 3 (Topic Grouping): for each proposed task, populate `file_scope` from whatever
   structured signal the calling command already has (tag file:line for `/fix-it`; user-stated files
   or grep-derived heuristics for `/meta`; blocker research for `/spawn`); run the shared overlap
   algorithm pairwise across all proposed tasks in the batch; for every overlapping pair with no
   already-declared dependency, **auto-add** a dependency edge (later-created/lower-priority task
   depends on the other) rather than only warning — consistent with this system's established
   "never silent, but default to the safe/serializing choice" philosophy (mirrors the `--lit`
   `PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL` pattern of always doing *something* visible rather than
   silently doing nothing). Surface every auto-added edge in the existing Component 7 confirmation
   summary table (add a "(auto: file overlap)" annotation next to auto-derived dependency cells) so
   the user can override it via the existing "Custom"/"Revise" path — never a hidden decision.

4. **Wiring** (Scope item 3):
   - `skill-fix-it`: extend Section 8.2 to run the shared overlap check across `topic_groups[]`
     (which already carries file_section per item) in addition to the existing hardcoded
     NOTE-before-fix-it rule.
   - `meta-builder-agent`: extend Interview Stage 3 to optionally ask users which files each task
     touches (or infer from description text/keyword-to-path heuristics already used in the
     Mode-C-Suggest-Wrap topic auto-inference, skill-fix-it lines ~451-485, which already maps
     keywords to directories like `agent-system`/`neovim`/`nix-config` — the same mapping table is a
     reasonable starting heuristic for `file_scope` inference).
   - `skill-spawn`: add `new_tasks[].file_scope` to `spawn-agent.md`'s schema (populated from the
     agent's existing blocker/codebase research); run the same shared overlap check in
     `skill-spawn`'s postflight before finalizing `dependencies` merges. Lowest priority of the three
     wiring points since spawn-created tasks are typically already serialized via the parent-blocker
     relationship.

5. **`/orchestrate` documentation** (Scope item 4): add a note to `orchestrate.md` Step 3 and/or
   `multi-task-operations.md` explaining that wave-assignment file-safety is entirely a property of
   `dependencies[]` accuracy, which is now established at task-creation time via Component 4a. Then
   (defense-in-depth, recommend as an explicit **Decision** for the plan to accept or defer — see
   Risks & Mitigations) consider a lightweight **runtime** check: before dispatching a wave with 2+
   tasks, if any two tasks in that wave have a `file_scope` overlap per the shared algorithm and no
   `dependencies[]` edge between them, split the wave (defer the lower-priority task to the next
   wave) and log a visible warning — this closes the residual gap for tasks created in separate
   batches (finding #6) without requiring the wave algorithm to re-implement dependency semantics.

## Decisions

- `file_scope` is **state.json-only** (no TODO.md rendering) — treated the same as
  `next_artifact_number`.
- `file_scope` and `modified_files`/`files_touched` remain **separate, distinctly-named fields**:
  `file_scope` is anticipated/prospective (set at creation), `modified_files` is actual/retrospective
  (set during/after implementation, used for git-staging scope per 785/786). They are not merged.
- Overlap detection is **directory-prefix matching**, not glob/regex — simpler, sufficient for the
  stated goal, and matches how `owned_files`/territory paths are already written in
  `territory.md`'s examples.
- Auto-add dependency edges by default on detected overlap (not merely warn), consistent with the
  system's established "never silent, default to the safer/serializing outcome, but always visible
  and overridable" pattern used elsewhere (e.g., `--lit` flag resolution).
- The overlap algorithm should be defined **once**, in a shared location, and reused by both the new
  Component 4a logic and (opportunistically, as a bonus fix) `skill-team-implement.md`'s previously
  undefined `infer_from_file_overlap`.

## Risks & Mitigations

- **Risk**: Cross-batch conflicts (tasks created in separate `/meta`/`/fix-it`/`/spawn` runs, months
  apart, that happen to touch the same files) are invisible to a creation-time-only fix, since
  Component 4a only compares footprints within one creation batch.
  **Mitigation**: recommend the defense-in-depth runtime wave-split check in `orchestrate.md` Step 3
  (Recommendation 5) as an explicit scope decision for the implementation plan — cheap to add since
  it only needs to read `file_scope` (if present) for the small number of tasks already collected
  into `task_numbers` for that `/orchestrate` invocation, no repo-wide scan required.
- **Risk**: `file_scope` heuristic inference (from descriptions/keywords) will sometimes be wrong
  (too broad or too narrow), producing either false-positive serialization (harmless, just less
  parallelism) or false-negative misses (the exact bug 787 exists to prevent).
  **Mitigation**: bias the heuristic toward over-declaring footprint (broader directory prefixes)
  since false positives only cost parallelism, while false negatives reproduce the original bug;
  always surface auto-added dependencies for user override per Recommendation 3.
- **Risk**: Field/behavior drift between the eight dual-copied files if only the project copy is
  updated.
  **Mitigation**: any implementation plan phase touching one of the eight paired files
  (`meta-builder-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`,
  `skill-orchestrate/SKILL.md`, `orchestrate.md`, `state-management.md`,
  `state-management-schema.md`, `multi-task-creation-standard.md`) must update both
  `.claude/...` and `.claude/extensions/core/...` copies and `diff -q` them to confirm parity, per
  the pattern already established by tasks 785/786. `territory.md` has no dual copy and needs only
  the single edit.

## Context Extension Recommendations

- **Topic**: Shared file-overlap detection algorithm.
  **Gap**: No canonical, algorithmically-defined path-overlap check exists anywhere in `.claude/context/`
  today; `skill-team-implement.md` calls an undefined `infer_from_file_overlap` and 787 needs the
  same primitive at the task level.
  **Recommendation**: create `.claude/context/patterns/file-footprint-overlap.md` as the single
  source of truth (directory-prefix matching rule, pseudocode, and both consumers cross-referenced).

## Appendix

### Search queries / commands used
- `diff -q` pairwise checks between `.claude/...` and `.claude/extensions/core/...` for all eight
  referenced files, plus `territory.md` (confirmed absent from core extension).
- `grep -n "modified_files\|files_touched"` across `.claude/` to map the 785/786 self-report
  convention for cross-referencing against the proposed `file_scope`.
- `grep -n "infer_from_file_overlap\|files_modified"` in `skill-team-implement/SKILL.md` — confirmed
  the function is called once and never defined.
- Direct `Read` of `state-management.md`, `state-management-schema.md` (full), relevant sections of
  `multi-task-creation-standard.md` (full), `territory.md` (full), and targeted sections of
  `meta-builder-agent.md`, `skill-fix-it/SKILL.md`, `skill-spawn/SKILL.md`, `skill-orchestrate/SKILL.md`,
  `orchestrate.md`, `multi-task-operations.md`, `plan-format.md`.

### References
- `.claude/rules/state-management.md`
- `.claude/context/reference/state-management-schema.md` (Project Entry Fields table lines 58-71;
  Dependencies Field subsection lines 188-206; next_artifact_number precedent lines 112-149)
- `.claude/docs/reference/standards/multi-task-creation-standard.md` (Component 3 lines 86-151;
  Component 4 lines 153-193; Component 5 lines 195-224; compliance table lines 389-397)
- `.claude/context/contracts/territory.md` (full file, no core-extension dual copy)
- `.claude/agents/meta-builder-agent.md` (Interview Stage 3 lines 244-383)
- `.claude/agents/spawn-agent.md` (new_tasks schema)
- `.claude/skills/skill-fix-it/SKILL.md` (Section 8.2 lines 255-303, Mode C topic inference
  lines ~451-485)
- `.claude/skills/skill-spawn/SKILL.md` (postflight lines ~250-406)
- `.claude/skills/skill-orchestrate/SKILL.md` (Multi-Task Mode section)
- `.claude/skills/skill-team-implement/SKILL.md` (Stage 5 lines 190-231)
- `.claude/commands/orchestrate.md` (Step 3 lines 108-153)
- `.claude/context/patterns/multi-task-operations.md` (lines 510-578)
- `.claude/context/formats/return-metadata-file.md` (modified_files field, lines 160-188)
- `.claude/context/standards/git-staging-scope.md` (full file — modified_files provenance)
- `.claude/context/formats/plan-format.md` (per-phase Depends on field, lines 70-90)
