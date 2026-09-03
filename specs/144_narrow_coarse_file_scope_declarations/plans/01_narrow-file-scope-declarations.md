# Implementation Plan: Task #144

- **Task**: 144 - Narrow the coarse whole-directory file_scope declarations that manufacture false collisions and needlessly serialize multi-task orchestration
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: `specs/144_narrow_coarse_file_scope_declarations/reports/01_narrow-coarse-file-scope.md`
- **Artifacts**: plans/01_narrow-file-scope-declarations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Coarse, directory-root `file_scope` entries in `specs/state.json` collide with every task that
touches anything beneath them, so `orchestrate-batch-admit.sh` defers tasks as
`file_scope_collision` even when their real footprints are disjoint. This plan fixes the
generator of those declarations first (the `multi-task-creation-standard.md` Component 4a
instruction to "bias toward over-declaring"), then builds the additive `proposed_file_scope` ->
`--file-scope-add` write-back mechanism that gives task creation a safe alternative to a
directory root when a footprint is genuinely unknown before research, and only then applies the
per-declaration narrowings. Done means: a live `validate-state.sh` run reports Check 8 clean (or
with explicitly justified survivors), Check 9 still green, the three genuine cross-task
collisions the coarse entries were masking are still present, and a full gate run is green.

### Research Integration

The research report supplies four load-bearing inputs this plan is built on:

1. **The task description's 3-item list is stale.** A live Check 8 re-run
   (`FILE_SCOPE_COARSE_MIN_OVERLAP=3`) found **11 (task, entry) findings across 10 projects**:
   44, 20, 88, 129, 142, 143, 147, 148, 149, 150. Two clusters dominate — a 7-way false
   collision on `agent-system/extensions/core/scripts/tests/` and a 3-way one on
   `agent-system/extensions/core/scripts/lint/`.
2. **Per-declaration narrowings with evidence.** Project 44's six `context/patterns/task-*.md`
   targets come verbatim from its own plan file (plus `index-entries.json`, a pre-existing
   under-declaration the old `context/` entry never covered either); projects 20/143/147/148/150
   resolve through the near-universal `test-<script-basename>.sh` convention; project 88's lint
   and test enumerations come from running the exact grep its own description prescribes.
3. **Three genuine collisions survive the narrowing** — 147/148/150 on
   `orchestrate-cycle-plan.sh` and 143/148/150 on `orchestrate-cycle-postflight.sh` (neither
   script exists on disk yet). This is the report's most load-bearing result: it proves narrowing
   separates real footprint overlap from directory-root false positives. A narrowing that erases
   these has introduced exactly the false negative the task forbids.
4. **Root cause + decided convention.** Component 4a step 1's over-declaring bias is the
   documented instruction that produces these declarations; the decided fix for the
   unknown-footprint case is declare-narrowest-at-creation plus an additive-only research
   postflight write-back.

Both addendum verification items were already clean at research time
(`general-implementation-hard-agent.md` survives only in terminal projects 81 and 121; project
88 has no `context/patterns/` entry), and are re-confirmed rather than re-fixed here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Rewrite `multi-task-creation-standard.md` Component 4a step 1 so task creation declares the
  narrowest currently-known files, with the no-false-negatives constraint preserved explicitly,
  and a directory root warranted only when the footprint genuinely spans most of that directory.
- Document the unknown-until-research convention in the same standard, so `/task`, `/fix-it`,
  `meta-builder-agent`, and `skill-spawn` converge on it instead of defaulting to a root.
- Add an optional `proposed_file_scope` field to the `.return-meta.json` schema and a
  `--file-scope-add` flag on `update-task-status.sh` that union-merges it into
  `active_projects[].file_scope` at research postflight — additive only, never subtractive.
- Wire the two live research-postflight consumers so the field is actually read.
- Apply the per-declaration narrowings from the research report to `specs/state.json`, re-derived
  from a fresh Check 8 run rather than trusted from either list.
- Verify Check 8 resolves, the three genuine collisions still serialize, and the full gate is
  green.

**Non-Goals**:
- Converting Check 8 from WARN-only into a blocking gate. It stays advisory.
- Changing the overlap predicate in `context/patterns/file-footprint-overlap.md`.
- Fixing the two pre-existing unrelated `validate-state.sh` FAILs (`abandon_reason` on 12
  projects, `blocks_note` on 3). Schema drift, out of scope, left alone.
- Narrowing project 88's `core/context/patterns/` entry (it does not exist in live state, and
  the addendum forbids touching it regardless).
- Creating a new standalone `context/patterns/file-scope-unknown-footprint-convention.md`. The
  convention is documented inside Component 4a, which is already the file task creation reads
  and is already in this task's declared scope; a second home would need `index-entries.json`
  registration and would create a drift surface against the standard it restates.
- Making the write-back mechanism subtractive or adding a shrink path for over-broad proposals.
  Additive-only is what makes it categorically safe; pruning stays a human/plan-phase decision.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A narrowing drops a path its task actually writes (false negative) | H | M | Every narrowing must trace to named evidence (the task's own plan file, its own description's prescribed grep, or the `test-<script-basename>.sh` convention against scripts that task already declares). No narrowing from inference alone; when evidence is absent, drop the entry only because the write-back convention now covers the case. |
| The narrowing erases the three genuine collisions (147/148/150 on `orchestrate-cycle-plan.sh`; 143/148/150 on `orchestrate-cycle-postflight.sh`) | H | M | Phase 6 asserts these specific pairs still overlap after the edit, as a named, explicit check — not as a side effect of Check 8 passing. |
| Live Check 8 findings differ from the report's 11 (state moved since research) | M | H | Phase 5 re-derives from a fresh run first and diffs against the report's table before editing; any new finding gets its own evidence trace, any vanished one is recorded as already-resolved. |
| `--file-scope-add` bypasses the mutex-guarded writer | H | L | The merge goes through `state-write.sh` inside `update-task-status.sh`'s existing single write, never a hand-rolled `jq > tmp && mv` (which `lint-state-writer-boundary.sh` would flag anyway). |
| Consumer wiring silently no-ops because `.claude/` is stale relative to the source store | M | M | Phase 6 deploys before verifying; `update-task-status.sh`'s own unconditional deploy gate on implement postflight also refuses a stale completion. |
| This task's declared `file_scope` omits files the wiring phase must edit | M | H | Confirmed already: `skill-base.sh`, `orchestrator-postflight.sh`, and `scripts/tests/test-update-task-status.sh` are all outside the declared five paths. Phase 4 extends this task's own `file_scope` additively — the first live exercise of the very convention being built. |
| Additive-only merge grows arrays unboundedly across repeated research rounds | L | L | Union semantics make repeats idempotent; only genuinely new paths accumulate. Noted, not solved here. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: the
operator's binding sequencing requires the generator fix (Phase 1) to land before the instances
(Phase 5), and each later phase consumes the contract the previous one defines.

---

### Phase 1: Rewrite Component 4a Guidance and Record the Unknown-Footprint Convention [COMPLETED]

**Goal**: Remove the documented instruction that generates coarse declarations, and put the
decided unknown-until-research convention in its place, so no task created after this change
reintroduces a directory root as a stand-in for "not known yet".

**Tasks**:
- [x] Read `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
      section `### 4a. File Footprint Capture and Overlap Detection (Automatic)`, step 1. *(completed)*
- [x] Replace the sentence "Bias toward over-declaring (broader prefixes): false positives here
      only cost parallelism, not correctness." with guidance that: declare the narrowest
      currently-known files; a directory root or extension-wide prefix is warranted ONLY when the
      task's real footprint is expected to span most of that directory, never as a stand-in for
      an unknown footprint. *(completed)*
- [x] In the same step, preserve the no-false-negatives constraint explicitly: under-declaring
      remains strictly worse than over-declaring, and a narrowing must never drop a path the task
      actually writes. *(completed)*
- [x] Add a new subsection under 4a documenting the unknown-until-research convention: (a) at
      creation time declare only the narrowest currently-known files and never a directory root
      as a placeholder; (b) at research postflight the research phase proposes additions via
      `proposed_file_scope` in `.return-meta.json`, union-merged into `file_scope` before the
      plan phase begins; (c) the merge is additive only, never subtractive. *(completed)*
- [x] Cross-reference `context/patterns/file-footprint-overlap.md` by path for the predicate
      itself (do not restate the rule — the existing step 2 convention). *(completed: retained the existing step 2 reference unchanged)*
- [x] Note in the subsection that Check 8 in `validate-state.sh` is the WARN-only detector for
      violations of this guidance, and remains advisory. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` -
  rewrite 4a step 1's bias sentence; add the unknown-footprint convention subsection.

**Verification**:
- `grep -n "over-declaring" agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
  returns no bias-toward-over-declaring instruction (an occurrence inside the retained
  no-false-negatives sentence is expected and correct).
- The new subsection names `proposed_file_scope`, `--file-scope-add`, and "additive"/"union".
- Diff read-through confirms every changed hunk is prose inside the standard.

---

### Phase 2: Add `proposed_file_scope` to the Return Metadata Schema [COMPLETED]

**Goal**: Define the field contract that Phase 3's flag consumes, so the producer side
(research agents) and consumer side (`update-task-status.sh`) are written against one spec.

**Tasks**:
- [x] Add `proposed_file_scope` to the `## Schema` JSON block in
      `agent-system/extensions/core/context/formats/return-metadata-file.md` as an optional
      array of repo-relative path strings. *(completed)*
- [x] Add a `### proposed_file_scope (optional)` field-specification section stating: research
      agents populate it when research discovers concrete file targets not already covered by
      the task's declared `file_scope`; it is a proposal of ADDITIONS only; the consumer
      union-merges and never removes; an absent, null, or empty value is a valid no-op. *(completed)*
- [x] State the consumer explicitly: `update-task-status.sh --file-scope-add` at research
      postflight, and cross-reference Component 4a's convention subsection from Phase 1. *(completed)*
- [x] State the producer-ownership rule consistent with the existing `### Multiple Sequential
      Writers` section: `proposed_file_scope` is producer-owned and must survive a later
      writer's merge untouched. *(completed)*
- [x] Add the field to the `### Research Success` example in the same file so the shape is
      copyable. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - schema block, new
  field section, Research Success example.

**Verification**:
- The `## Schema` JSON block still parses as JSON when the comment-free body is extracted.
- `grep -c "proposed_file_scope"` shows occurrences in the schema block, the field section, and
  the example.
- Diff read-through confirms prose/JSON-example edits only.

---

### Phase 3: Implement `--file-scope-add` in `update-task-status.sh` [COMPLETED]

**Goal**: Give `update-task-status.sh` a validated, additive-only `file_scope` merge that runs
inside its existing single mutex-guarded `state-write.sh` write.

**Tasks**:
- [x] Add `--file-scope-add=*` (and/or `--file-scope-add <json-array>`) to the flag loop
      alongside `--dry-run`, `--allow-pr-ready`, and `--phase-check=*`; keep it out of
      `POSITIONAL_ARGS`. *(completed)*
- [x] Validate the value: must parse as a JSON array of strings (`jq -e 'type == "array" and
      (all(.[]; type == "string"))'`). Follow the `--phase-check` precedent — a malformed value
      is a hard validation error with a named message and a non-zero exit, never a silent no-op,
      so a typo cannot quietly drop coverage. *(completed)*
- [x] Restrict the flag to `operation == postflight && target_status == research`. Any other
      combination is a validation error naming the restriction. *(completed)*
- [x] Merge as a set union onto the existing array inside the existing `state-write.sh`
      invocation's jq filter: `.file_scope = ((.file_scope // []) + $add | unique)` scoped to the
      matching `active_projects[]` entry. Never assign a replacement array; never add a second
      write. *(completed: also extended to the state_is_noop branch's own state-write.sh call, so a
      pending --file-scope-add still applies even when the status transition itself is a no-op)*
- [x] Make the empty/absent case a byte-for-byte no-op: no flag, an empty array, or an array
      whose members are all already present leaves `file_scope` unchanged. *(completed: gated the
      merge clause on a non-empty parsed array length so an empty array never runs jq `unique`
      over an already-identical array)*
- [x] Update the script header usage block and the `Usage:` error string to include the new flag. *(completed)*
- [x] Extend `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` with cases:
      (a) union adds only new paths; (b) re-running with the same array is idempotent; (c) an
      already-null `file_scope` becomes the added array; (d) no flag leaves `file_scope`
      untouched; (e) a malformed value exits non-zero without writing state; (f) the flag on a
      non-research or non-postflight call is rejected. *(completed: Case 11a-f, all 29 suite cases pass)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes `update-task-status.sh` performs exactly one
`state-write.sh` transform for the status transition, so the union can ride along in that filter
rather than needing a second write. Confirm at implementation time by reading the
`state-write.sh` call site in the script (around the status-write branch) and checking that no
second state write exists on the research-postflight path; if a second write is found, extend the
first rather than adding a third.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - flag parsing, validation,
  union-merge in the state-write filter, usage/header text.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - six new cases.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` passes, new cases
  included.
- `bash -n agent-system/extensions/core/scripts/update-task-status.sh` clean.
- `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` clean (no
  hand-rolled state write introduced).
- A `--dry-run` invocation with `--file-scope-add` reports the intended union without writing.

---

### Phase 4: Wire the Research-Postflight Consumers [COMPLETED]

**Goal**: Make the mechanism live on both real research-postflight paths, and extend this task's
own `file_scope` to cover the files this phase touches.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/skill-base.sh`, in `skill_postflight_update`'s
      `researched|planned|implemented` branch, read `proposed_file_scope` from
      `${_task_dir}/.return-meta.json` when `operation == research` and append
      `--file-scope-add=<json>` to the `update-task-status.sh` call. Derive it from the already
      resolved `_task_dir` rather than adding a new positional argument, so every existing
      4-arg/5-arg/6-arg/7-arg call site is unchanged. *(completed)*
- [x] Use the same empty-array-expansion pattern already used for `phase_check_args` so an
      absent or empty field passes no flag at all. *(completed)*
- [x] In `agent-system/extensions/core/scripts/orchestrator-postflight.sh` Stage 7, extract
      `proposed_file_scope` from the already-open `$metadata_file` and pass the same flag when
      `operation_type == research`. *(completed)*
- [x] Confirm both sites treat a missing file, missing field, `null`, or `[]` as a no-op with no
      warning. *(completed: verified via scratch .return-meta.json test, see progress file)*
- [x] Extend task 144's own `file_scope` in `specs/state.json` via `state-write.sh` to add
      `agent-system/extensions/core/scripts/skill-base.sh`,
      `agent-system/extensions/core/scripts/orchestrator-postflight.sh`, and
      `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — an additive
      union, never a replacement, matching the convention this task defines. *(completed: also
      added `agent-system/extensions/core/scripts/command-gate-out.sh`, a third live
      research-postflight call site found by the Scope Hypothesis's own grep — see deviation
      note)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly two live research-postflight call sites
(`skill_postflight_update` in `skill-base.sh`, and `orchestrator-postflight.sh` Stage 7). Confirm
at implementation time with `grep -rn "update-task-status.sh postflight" agent-system/extensions/`
and check each hit for a research path; extension skills that call the script directly for a
research transition must either be wired too or explicitly recorded as out of scope with a
reason.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - research branch of
  `skill_postflight_update`.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - Stage 7 research call.
- `specs/state.json` - additive extension of task 144's own `file_scope`.

**Verification**:
- `bash -n` clean on both scripts.
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` passes (if that
  harness covers `skill_postflight_update`; otherwise record which harness does).
- A scratch `.return-meta.json` carrying `proposed_file_scope` drives an observable union on a
  `--dry-run` research postflight; the same run with the field removed produces no flag.
- `jq '.active_projects[] | select(.project_number == 144) | .file_scope' specs/state.json` shows
  eight entries, with the original five intact. *(actual: nine entries — the plan's stated eight
  plus `agent-system/extensions/core/scripts/command-gate-out.sh`, the third live
  research-postflight call site this phase's own Scope Hypothesis grep surfaced; see the
  deviation note above. All five original entries are intact.)*

---

### Phase 5: Apply the Per-Declaration Narrowings to `specs/state.json` [COMPLETED]

**Goal**: Replace each coarse directory-root entry with the files its task genuinely writes,
re-derived from a live Check 8 run, without dropping any path a task actually modifies.

**Tasks**:
- [x] Re-run Check 8 live (`bash agent-system/extensions/core/scripts/validate-state.sh`, and the
      spliced jq program from the report's appendix for the unabridged list) and record the
      current finding set. *(completed: live run found 10 findings across 9 projects — see
      deviation note)*
- [x] Diff the live set against the report's 11-row table. For any finding not in the table,
      derive its own evidence before narrowing. For any table row no longer present, record it as
      already-resolved and take no action. *(completed: project 20's `scripts/tests/` finding has
      vanished — task 20 completed earlier in this same batch and is now a terminal state, so
      Check 8 no longer flags it; no non-terminal collision risk remains, no action taken. No new
      finding appeared beyond the report's 10 remaining rows.)*
- [x] Project 44: replace `agent-system/extensions/core/context/` with the six
      `context/patterns/task-*.md` files enumerated in
      `specs/044_slim_task_command_body/plans/01_task-command-mode-extraction.md`, plus
      `agent-system/extensions/core/index-entries.json` (Phase 7 of that plan mandates
      registration there, and the old `context/` prefix never covered it — closing a pre-existing
      under-declaration). Re-grep that plan to confirm the six filenames before writing. *(completed:
      re-grepped live, six files confirmed against the plan's own Artifacts & Outputs section)*
- [x] Project 20: replace `scripts/tests/` with
      `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh`. *(deviation: skipped
      — project 20 is now status=completed (terminal); Check 8 no longer flags it and a terminal
      task's file_scope has no bearing on collision scheduling, so narrowing it is a no-op left
      undone per the addendum's own terminal-exclusion precedent (81, 121))*
- [x] Projects 143, 147, 148, 150: replace `scripts/tests/` with the
      `test-<script-basename>.sh` companions of the implementation scripts each already declares,
      per the report's per-project table. Re-verify each mapping against that project's live
      `file_scope` rather than copying the table blind. *(completed: re-derived live from each
      project's current file_scope — 143: orchestrate-cycle-postflight.sh,
      orchestrate-recover-outcome.sh; 147: orchestrate-cycle-plan.sh, orchestrate-dry-run-report.sh;
      148: orchestrate-churn.sh, orchestrate-cycle-plan.sh, orchestrate-cycle-postflight.sh; 150:
      orchestrate-cycle-plan.sh, orchestrate-cycle-postflight.sh, orchestrate-triage-classify.sh)*
- [x] Project 88: replace `scripts/tests/` and `scripts/lint/` with the enumerations produced by
      re-running its own prescribed grep,
      `grep -rl "SKILL.md" agent-system/extensions/core/scripts/tests/ agent-system/extensions/core/scripts/lint/`.
      Do not touch any `context/patterns/` entry (none exists; the addendum forbids it anyway). *(completed:
      12 tests/ files + 7 lint/ files from a live grep run)*
- [x] Project 142: drop `scripts/lint/` with no replacement — no lint file is named anywhere in
      its description and no WORK item implies adding one; the write-back convention covers it if
      implementation later discovers otherwise. *(completed)*
- [x] Project 149: drop `scripts/tests/` with no replacement — team-mode tests were already
      deleted, and `parse-command-args.sh` has no companion test; genuinely unknown until its own
      research runs. *(completed)*
- [x] Project 129: drop `context/standards/` with no replacement (its guidance-note filename is
      not determinable before its audit concludes); leave its eight already file-precise entries
      untouched. *(completed)*
- [x] Apply every edit through `state-write.sh`, replacing only the named entries within each
      task's array. Never rewrite an unrelated array and never touch `artifacts`. *(completed: single
      state-write.sh call with a per-project-number jq filter; `artifacts` and every other field
      confirmed byte-identical via diff)*
- [x] Re-confirm the addendum items rather than re-fixing them: `general-implementation-hard-agent.md`
      appears only under terminal projects 81 and 121; no non-terminal task references it. *(completed:
      re-confirmed live, unchanged)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts 11 Check 8 findings across 10 projects (44, 20, 88, 129,
142, 143, 147, 148, 149, 150), of which 9 are narrowed in place and 3 entries are dropped in
favor of the write-back convention. The live re-run in this phase's first step is the
confirmation; the count is a hypothesis from the research snapshot, not a fact, and the live
result governs. *(actual: 10 findings across 9 projects — project 20 completed, terminal, and no
longer flagged; no new project appeared. 8 projects narrowed in place (44, 88, 143, 147, 148, 150
replaced with concrete files; note 44 and 88 both replace two-cluster coarse entries in one edit
each) and 3 entries dropped with no replacement (129, 142, 149), per the same evidence rules the
plan specified.)*

**Files to modify**:
- `specs/state.json` - `file_scope` arrays for the projects the live run flags.

**Verification**:
- `bash agent-system/extensions/core/scripts/validate-state.sh` parses cleanly and Check 9
  (duplicate entries) still passes.
- `jq empty specs/state.json` succeeds.
- Every narrowed entry traces to a named evidence source recorded in the phase's commit body.
- No project's `file_scope` lost a path it actually writes — confirmed per project by comparing
  the old and new arrays and naming what each removed prefix covered.

---

### Phase 6: Deploy, Verify Check 8, and Confirm the Genuine Collisions Survive [COMPLETED]

**Goal**: Prove the acceptance criteria: Check 8 clean or justified, the three real collisions
still serializing, and a green full gate.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repo's standard
      deploy path) so the `.claude/` deploy artifact carries the Phase 3-4 script changes.
      *(completed: deploy landed successfully; the deploy step itself is separate from
      verification below)*
- [x] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` and record the result.
      *(completed: FAIL — 3 of 30 checks failed. All 3 failing checks are pre-existing and
      predate this dispatch — see verification note below for the full breakdown.)*
- [x] Run `bash agent-system/extensions/core/scripts/validate-state.sh`; confirm Check 8 reports
      no coarse declarations, or record an explicit written justification for each survivor.
      *(completed: Check 8 — "No coarse (blast radius >= 3) file_scope declarations found" —
      PASS, no survivors)*
- [x] Confirm Check 8 remains WARN-only: the run's exit status must not have become failing
      because of Check 8, and no gate conversion was introduced. *(completed: Check 8 reports
      PASS in `validate-state.sh`'s output; the run's 2 FAILs are the pre-existing
      `abandon_reason`/`blocks_note` unknown-field findings, unrelated to Check 8)*
- [x] Assert the preserved collisions explicitly, not incidentally: 147, 148, and 150 all still
      declare `orchestrate-cycle-plan.sh` (or its test companion), and 143, 148, and 150 all
      still declare `orchestrate-cycle-postflight.sh` (or its test companion). Query
      `specs/state.json` directly for each of the six memberships. *(completed: queried
      `specs/state.json` directly via jq for project_numbers 143/147/148/150 — all six
      memberships confirmed present: 147, 148, 150 each declare
      `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (147/150 also declare its
      test companion, 148 declares both); 143, 148, 150 each declare
      `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (all three also
      declare its test companion))*
- [x] Confirm the two pre-existing unrelated FAILs (`abandon_reason`, `blocks_note`) are
      unchanged in count and membership — evidence that this pass touched nothing outside
      `file_scope`. *(completed: `abandon_reason` — 12 projects (141, 94, 53, 46, 31, 42, 64, 73,
      100, 115, 132, 138); `blocks_note` — 3 projects (106, 107, 109); matches the counts recorded
      before this dispatch)*
- [x] Confirm `context/patterns/file-footprint-overlap.md` is untouched
      (`git diff --stat` shows no change to it). *(completed: `git diff --stat` against both the
      `.claude/` deploy copy and the `agent-system/extensions/core/` source-store copy of
      `context/patterns/file-footprint-overlap.md` show no changes)*
- [x] Run the full gate set for the repository and record the outcome. *(completed: full gate set
      = `verify-deploy.sh`'s 30-check run per this repo's convention — FAIL, 3/30, all 3 failing
      checks pre-existing; see verification note below)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None (verification only; any defect found here is fixed in the owning phase's file).

**Verification**:
- `validate-state.sh` Check 8 line reads clean, or each survivor has a recorded justification.
  *(actual: clean, no coarse declarations, no survivors)*
- The six collision memberships each return a match. *(actual: confirmed, all six)*
- `verify-deploy.sh` green; full gate run green. *(actual: NOT green — FAIL, 3 of 30 checks
  failed. This bar cannot be met on this tree: all 3 failures are pre-existing findings that
  predate this dispatch and are unrelated to `file_scope`/Check 8 —
  (1) doc-lint: 4 `index-entries.json` `line_count` mismatches (`patterns/postflight-control.md`
  318/405, `reference/state-management-schema.md` 519/520, `schemas/state-schema.json` 267/271,
  `project/literature/patterns/zotero-item-creation.md` 208/234); (2) `validate-state.sh --deep`:
  the 2 unknown-entry-field findings (`abandon_reason` on 12 projects, `blocks_note` on 3
  projects); (3) state-writer boundary lint: 4 hand-rolled `state.json` write violations in
  `agent-system/extensions/core/scripts/tests/test-force-phases.sh` (lines 261, 307, 317, 327).
  None of these files were touched by this task's Phases 1-6, and none is a regression this pass
  introduced.)*
- `git diff --stat` shows no change to `file-footprint-overlap.md` and no change converting
  Check 8 into a gate. *(actual: confirmed on both counts)*

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` passes,
      including the six new `--file-scope-add` cases.
- [ ] `bash -n` clean on `update-task-status.sh`, `skill-base.sh`, `orchestrator-postflight.sh`.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` clean.
- [ ] `jq empty specs/state.json` succeeds after every state edit.
- [ ] `validate-state.sh`: Check 8 clean (or justified survivors), Check 9 green, the two
      pre-existing unrelated FAILs unchanged.
- [ ] The three genuine collisions (147/148/150 and 143/148/150) still present.
- [ ] `verify-deploy.sh` green; full gate run green.
- [ ] End-to-end smoke: a `.return-meta.json` carrying `proposed_file_scope` produces a union on a
      dry-run research postflight; removing the field produces no change.

## Artifacts & Outputs

- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` -
  rewritten Component 4a step 1 plus the unknown-footprint convention subsection.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - `proposed_file_scope`
  schema entry, field specification, and example.
- `agent-system/extensions/core/scripts/update-task-status.sh` - `--file-scope-add` flag with
  additive union merge.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - new coverage.
- `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - consumer wiring.
- `specs/state.json` - narrowed `file_scope` arrays plus task 144's own additive extension.
- `specs/144_narrow_coarse_file_scope_declarations/summaries/01_*-summary.md` - execution summary.

## Rollback/Contingency

Each phase commits separately, so any single phase reverts with `git revert` of its own commit
without disturbing the others. The doc phases (1, 2) are pure prose and revert cleanly. The
script phases (3, 4) are additive — the flag defaults to absent and both consumer sites no-op on
a missing field, so reverting them restores byte-for-byte prior behavior. The `specs/state.json`
narrowings (Phase 5) are the only semantically risky change: if a narrowing turns out to have
dropped a path a task writes, the fix is additive (re-add the path via `state-write.sh`, or the
new `--file-scope-add` path), never a wholesale array restore, since other tasks' entries may
have moved independently in the meantime. Take
`bash .claude/scripts/git-snapshot.sh 144` before any intentional rollback that would discard
uncommitted work.
