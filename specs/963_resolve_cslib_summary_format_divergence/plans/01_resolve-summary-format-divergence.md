# Implementation Plan: Task #963

- **Task**: 963 - Resolve the cslib implementation-summary format divergence from the core standard
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: 972, 974
- **Research Inputs**: specs/963_resolve_cslib_summary_format_divergence/reports/01_summary-format-divergence.md
- **Artifacts**: plans/01_resolve-summary-format-divergence.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

cslib implementation summaries trip non-blocking gate-out format errors because
`cslib-implementation-agent.md` never loads `summary-format.md` and therefore improvises both the
metadata block and the section headings. This plan implements the research report's recommended
resolution — Option (ii): formally admit `## Plan Deviations` into `summary-format.md` as a
recognized optional section, and make the standard state explicitly that its required-section list
is a **minimum**, not an exhaustive whitelist (which is what `validate-artifact.sh` has always
actually enforced). It then wires both cslib agents to that amended standard, giving the base
agent a full, verbatim-copyable summary skeleton it currently lacks entirely. Done means: a cslib
implementation summary validates with zero errors and zero auto-repaired fields, both cslib agents
carry a direct `summary-format.md` reference, and no agent is instructed to emit a section the
standard forbids or omit one it requires.

### Research Integration

Key findings from `reports/01_summary-format-divergence.md` that shape this plan:

- **The validator never rejects extra headings.** `validate-artifact.sh` only `log_error`s on a
  *missing* required field or section; it never enumerates the document's headings against a
  whitelist. So `## Plan Deviations` has never caused a single error. The real gate-out failures
  come from heading *replacement* (`## What Was Done` in place of `## What Changed`) plus missing
  metadata bullets — this is why the observed symptom was "4 errors, 4 fields auto-repaired"
  (`--fix` mode repairs metadata fields only, never sections).
- **`## Plan Deviations` is the dominant ecosystem convention, not a cslib idiosyncrasy.** 11 of
  16 implementation-terminus agents use or mandate it. It binds a distinct structured concern —
  the skipped/altered/deferred deviation taxonomy tied to plan checklist items — that
  `## Decisions` and `## Follow-ups` do not structurally capture. This is the evidence base for
  choosing Option (ii) over Option (i), which would have required rewriting 8+ already-converged
  agents for no validator benefit.
- **The hard agent's "contradiction" dissolves under Option (ii).** It already carries a direct
  `summary-format.md` reference; once the standard names `## Plan Deviations`, its Stage 6
  mandate and its loaded standard agree by construction. It needs alignment polish, not a fix.
- **The base agent has no summary-creation stage at all.** Its stage list runs
  Stage 0 -> Write-First Metadata Pattern -> Final Verification Stage -> CI Pipeline; there is no
  "Create Implementation Summary" stage and no skeleton anywhere in the file. The only structural
  instruction is MUST-DO #16. A bare context reference is therefore insufficient — the metadata
  block must be spelled out inline or the auto-repair symptom will persist.
- **The task's premise that `web` already conforms is false.** `web-implementation-agent.md` has
  zero `summary-format.md` references and is missing 5 of 6 required metadata fields and 3 of 6
  required sections. `lean-implementation-agent.md` (base), `epi-implement-agent.md`, and
  `founder-implement-agent.md` share the same failure mode. All of these sit outside this task's
  declared `file_scope` and are routed to follow-up, not folded in.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:

- Record the Option (ii) decision in `summary-format.md`: `## Plan Deviations` becomes a named,
  recognized optional section with a canonical position and a canonical empty-value convention.
- Make `summary-format.md` state its required-section semantics explicitly — the list is a
  minimum that additional sections may supplement, matching what the validator enforces.
- Bring `validate-artifact.sh`'s comments and arrays into documented parity with the amended
  standard **without changing any validation outcome**.
- Give `cslib-implementation-agent.md` a direct `summary-format.md` context reference and a
  complete, copyable summary skeleton (metadata block + all six required sections + the sanctioned
  optional sections) so it stops improvising.
- Align `cslib-implementation-hard-agent.md`'s Stage 6 with the amended standard.
- Empirically confirm the verification bar: a cslib-shaped summary validates with zero errors and
  zero auto-repaired fields.

**Non-Goals**:

- Fixing the other non-conforming implementation agents (`web`, `lean` base, `epi`, `founder`) or
  tightening the soft-pointer group (`latex`, `python`, `typst`, `z3`). Real gaps, outside
  `file_scope`, routed to a follow-up recommendation in the summary.
- Adding the missing `deviations` array to `progress-file.md`'s documented schema. Separate
  pre-existing documentation gap, outside `file_scope`.
- Changing what `validate-artifact.sh` accepts or rejects. Enforcement behavior is frozen; only
  documentation parity changes.
- Formally specifying `## Verification` as its own named optional section. The
  minimum-not-whitelist semantics added in Phase 1 already make it legitimate; naming it
  individually is a separate decision this task was not asked to make.
- Deploying to `.claude/**`. All edits target the source store only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Amending a shared core standard reads as scope creep beyond cslib | M | M | The change is additive-only (one optional section + a semantics clarification), justified by 11-of-16 existing adoption. It formalizes practice rather than introducing it. `file_scope` names `summary-format.md` explicitly, so this is sanctioned scope. |
| A `validate-artifact.sh` edit accidentally changes enforcement outcomes | H | L | Phase 2 adds a documentation-only array plus comments; the new array is never wired into the `required_sections` selection. Phase 2 verification diffs validator output on a fixture before and after the edit and requires it to be byte-identical. |
| Adding a skeleton to the base agent that drifts from the validator's arrays | H | M | Phase 3 and Phase 4 carry `interface` verification tier: every heading and metadata bullet name emitted by the agents is checked by name against `SUMMARY_METADATA` and `SUMMARY_SECTIONS` in `validate-artifact.sh` before the phase closes. |
| Edits land in `.claude/**` and are wiped by the next regeneration | H | L | Every phase's task list names the `agent-system/extensions/**` target path explicitly; Phase 5 greps the diff to confirm zero `.claude/**` paths were touched. |
| Task-number citations leak into deliverables outside `specs/**` | M | M | All four target files are deliverables. Phase 5 runs `check-task-references.sh` (or equivalent grep) over the changed files; the write-time hook is a second layer. |
| Fixing only cslib leaves 4 other extensions failing identically | M | H | Accepted and explicit: recorded as a Non-Goal and carried into the implementation summary's `## Follow-ups` as a named recommendation, so the gap is tracked rather than silently absorbed. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Amend summary-format.md to admit `## Plan Deviations` [COMPLETED]

**Goal**: Record the Option (ii) decision in the shared core standard, making `## Plan Deviations`
a recognized optional section and making the required-section list's minimum-not-whitelist
semantics explicit.

**Tasks**:

- [x] Read `agent-system/extensions/core/context/formats/summary-format.md` in full (59 lines). *(completed)*
- [x] Under `## Structure`, keep the existing numbered list of six required sections unchanged, and
      add a short paragraph directly beneath it stating that the six entries are the **required
      minimum**: a summary MUST contain all six, and MAY contain additional sections. State
      plainly that additional sections have never been rejected by the gate-out validator and are
      not an error. *(completed)*
- [x] Add a new `### Optional Sections` subsection under `## Structure` naming `## Plan Deviations`
      as a recognized optional section, specifying: canonical position (after `## Decisions`,
      before `## Impacts`), purpose (records plan-checklist deviations under a
      skipped/altered/deferred taxonomy that `## Decisions` and `## Follow-ups` do not
      structurally capture), and the canonical empty value
      `- None (implementation followed plan)`. *(completed: rationale note folded into same subsection)*
- [x] Add a one-sentence rationale note recording *why* the section is admitted rather than folded
      away: it is the dominant convention across implementation agents and carries a distinct
      structured concern. Cite the durable anchor (the section name and the agents' Stage 6
      convention), never a task number. *(completed)*
- [x] Update the `## Example Skeleton` block to show `## Plan Deviations` in its canonical position
      with the `- None (implementation followed plan)` placeholder, so the skeleton and the prose
      cannot drift. *(completed)*
- [x] Confirm no task-number citation was introduced anywhere in the file. *(completed: grep returned no matches)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the current standard declares exactly six required
sections (`Overview`, `What Changed`, `Decisions`, `Impacts`, `Follow-ups`, `References`) and that
this list is identical to `SUMMARY_SECTIONS` in `validate-artifact.sh`. Confirm at implementation
time by reading both `summary-format.md`'s `## Structure` list and line 32 of
`agent-system/extensions/core/scripts/validate-artifact.sh` and comparing the two sets element by
element before editing. If they differ, stop and reconcile before proceeding — the divergence
would invalidate Phases 2-4.

**Files to modify**:

- `agent-system/extensions/core/context/formats/summary-format.md` - add minimum-not-whitelist
  semantics paragraph, `### Optional Sections` subsection naming `## Plan Deviations`, and update
  the example skeleton.

**Verification**:

- Diff read-through confirming every changed hunk is prose/markdown with no executable surface.
- The six required section names are unchanged in both name and order.
- `## Plan Deviations` appears in both the new prose subsection and the example skeleton, in the
  same canonical position in both.
- `grep -nE '[Tt]asks? [0-9]+' agent-system/extensions/core/context/formats/summary-format.md`
  returns no new matches.

---

### Phase 2: Sync validate-artifact.sh comments to the amended standard [COMPLETED]

**Goal**: Make the validator's source self-documenting about sanctioned optional sections, so a
future maintainer does not assume extra headings are unsafe — with zero change to validation
outcomes.

**Tasks**:

- [x] Read the array-definition block of
      `agent-system/extensions/core/scripts/validate-artifact.sh` (the `SUMMARY_METADATA` /
      `SUMMARY_SECTIONS` region and the explanatory `NOTE:` comment style already used for
      `PLAN_METADATA`). *(completed)*
- [x] Add a `SUMMARY_SECTIONS_OPTIONAL=("Plan Deviations")` array immediately after
      `SUMMARY_SECTIONS`, with a comment stating it is **documentation-only**: it is deliberately
      not wired into `required_sections` and has no effect on validation, existing solely to keep
      the script and `summary-format.md` from drifting. *(completed)*
- [x] Add a comment above `SUMMARY_SECTIONS` recording the enforcement semantics explicitly — the
      array is a required *minimum*; the check loop only reports missing entries and never
      enumerates document headings against a whitelist, so additional sections are accepted by
      design, not by oversight. *(completed)*
- [x] Confirm the `case "$artifact_type" in ... summary)` branch is untouched and still assigns
      only `SUMMARY_METADATA` and `SUMMARY_SECTIONS`. *(completed: verified via git diff --stat, additions only)*
- [x] Confirm no task-number citation was introduced. *(completed: grep returned no matches)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the edit touches only comment lines plus one new,
never-read array assignment, and that no control-flow or loop body changes. Confirm at
implementation time with `git diff --stat` (expect a single file, additions only) and by reading
the full diff to check every added line is either a comment or the new unreferenced array.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-artifact.sh` - add
  `SUMMARY_SECTIONS_OPTIONAL` array and enforcement-semantics comments near the summary arrays.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/validate-artifact.sh` exits 0.
- `shellcheck` on the file (if available) reports no new findings versus the pre-edit run.
- Behavior-freeze check: run the validator against an existing summary artifact under `specs/`
  **before** and **after** the edit and confirm the output is byte-identical, including the error
  and fix counts. Capture both outputs and diff them.
- `grep -n 'SUMMARY_SECTIONS_OPTIONAL' <file>` shows exactly one occurrence (the definition) —
  proving it is never read.

---

### Phase 3: Wire cslib-implementation-agent.md to the standard [COMPLETED]

**Goal**: Give the base cslib agent a direct `summary-format.md` reference and a complete,
copyable summary skeleton so it stops improvising both the metadata block and the headings.

**Tasks**:

- [x] Add `- `@.claude/context/formats/summary-format.md` - Summary structure (when creating
      summary)` to the `## Context References` section of
      `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`, matching the wording
      already used in `cslib-implementation-hard-agent.md`. *(completed)*
- [x] Add a `## Create Implementation Summary` stage to the file. Place it after the
      `## Final Verification Stage (MANDATORY)` section and before the metadata write, so it sits
      where the agent actually needs it in the run order. State the output path
      `specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md`. *(completed)*
- [x] Inside that stage, embed a complete fenced skeleton modeled on the one in
      `agent-system/extensions/core/agents/general-implementation-agent.md`'s summary stage. It
      MUST include the full metadata bullet block (`Task`, `Status`, `Started`, `Completed`,
      `Effort`, `Dependencies`, `Artifacts`, `Standards`), then `## Overview`, `## What Changed`,
      `## Decisions`, `## Plan Deviations`, `## Verification`, `## Impacts`, `## Follow-ups`,
      `## References`. *(completed)*
- [x] Add the same non-abbreviation warning the general agent carries: the metadata header is
      mandatory and MUST NOT be abbreviated, reordered, or partially omitted, because every
      bullet is a field the validator checks by name. *(completed)*
- [x] Adapt the `## Verification` block's contents to CSLib reality (build/lint/sorry/axiom
      results from the CI pipeline) rather than copying the generic Build/Tests wording verbatim. *(completed)*
- [x] Amend MUST-DO #16 so it points at the new stage and the standard instead of standing alone
      as the file's only structural instruction — e.g. write the summary per `summary-format.md`,
      including the `## Plan Deviations` section, using `- None (implementation followed plan)`
      when there were no deviations. *(completed)*
- [x] Confirm no task-number citation and no `.claude/**` write target was introduced. *(completed: grep clean; git diff --stat shows only the agent-system source-store path)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the base agent currently contains **zero** occurrences of
`summary-format.md` and **no** summary-creation stage or skeleton anywhere in its 566 lines.
Confirm at implementation time with `grep -c 'summary-format' <file>` (expect 0) and
`grep -n '^## \|^### ' <file>` to enumerate every stage heading and check none is a
summary-creation stage, **before** adding one — if a stage already exists, amend it in place
rather than adding a duplicate.

**Files to modify**:

- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` - add context reference,
  add summary-creation stage with full skeleton, amend MUST-DO #16.

**Verification**:

- Enumerated-dependent check (the `interface` obligation): extract every metadata bullet name and
  every `##` heading from the new skeleton and confirm each required one appears by exact name in
  `SUMMARY_METADATA` / `SUMMARY_SECTIONS` in
  `agent-system/extensions/core/scripts/validate-artifact.sh`. All six required sections and all
  six required metadata fields must be present with exact spelling — including the ampersand-free
  `Follow-ups` and the exact `What Changed`.
- `## Plan Deviations` appears in the canonical position defined in Phase 1 (after
  `## Decisions`).
- `grep -c 'summary-format' <file>` returns at least 1.
- `grep -nE '[Tt]asks? [0-9]+' <file>` returns no new matches.

---

### Phase 4: Align cslib-implementation-hard-agent.md Stage 6 [COMPLETED]

**Goal**: Make the hard agent's Stage 6 explicitly consistent with the amended standard, removing
the ambiguity of mandating a section the standard previously did not document.

**Tasks**:

- [x] Read Stage 6 (`### Stage 6: Create Implementation Summary`) of
      `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`. *(completed)*
- [x] Rewrite Stage 6's body to state that the summary follows `summary-format.md` — all six
      required sections and the full required metadata block — and that `## Plan Deviations` is
      included as the standard's recognized optional section, positioned after `## Decisions`,
      using `- None (implementation followed plan)` when there were no deviations. *(completed)*
- [x] Keep the stage terse, matching the hard agent's existing compressed style. Do **not** paste
      the full skeleton here; point at the loaded standard and, where useful, at the base agent's
      stage. The hard agent already carries the `summary-format.md` context reference, so no
      change to `## Context References` is needed — verify this rather than assuming. *(completed: confirmed via grep, no edit made there)*
- [x] Confirm no task-number citation and no `.claude/**` write target was introduced. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the hard agent already has a direct
`@.claude/context/formats/summary-format.md` entry in `## Context References` and therefore needs
no addition there. Confirm at implementation time with
`grep -n 'summary-format' <file>` before editing; if the reference is absent, add it as part of
this phase rather than assuming the research finding still holds.

**Files to modify**:

- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - rewrite Stage 6 body
  to reference the standard explicitly and name `## Plan Deviations` as its sanctioned optional
  section.

**Verification**:

- Stage 6 names `summary-format.md` explicitly and no longer mandates `## Plan Deviations` as a
  bare unexplained requirement.
- Any section name written into Stage 6 matches `SUMMARY_SECTIONS` in `validate-artifact.sh` by
  exact spelling.
- `grep -nE '[Tt]asks? [0-9]+' <file>` returns no new matches.

---

### Phase 5: Verify the bar and record follow-ups [COMPLETED]

**Goal**: Empirically confirm the task's verification bar — zero gate-out format errors and zero
auto-repaired fields on a cslib-shaped summary — and confirm both binding constraints held.

**Tasks**:

- [x] Construct a representative cslib implementation summary by filling in the Phase 3 skeleton
      with plausible content, and write it to a scratch path (not into a task's `summaries/`
      directory, to avoid polluting task artifacts). *(completed: wrote to verification-scratch/ under the task dir, since specs/** is the required exemption for the write-time task-reference guard)*
- [x] Run `bash agent-system/extensions/core/scripts/validate-artifact.sh <scratch> summary` and
      confirm the output reports zero errors. *(completed: 0 errors, exit 0)*
- [x] Run the same command with `--fix` and confirm zero fields were auto-repaired (exit code 0,
      not 2; no `[FIXED]` lines). *(completed: exit 0, no [FIXED] lines)*
- [x] Run with `--strict` and record any warnings; warnings do not fail the bar but should be
      reported in the summary if present. *(completed: 0 warnings)*
- [x] Confirm the source-store rule held: `git status --short` and the phase diffs contain zero
      paths under `.claude/`. Every changed path must be under `agent-system/extensions/`. *(completed: verified)*
- [x] Confirm the deliverable rule held: run `bash .claude/scripts/check-task-references.sh` if
      present, otherwise grep each of the four changed files for task-number citation patterns.
      All four are deliverables outside `specs/**`. *(completed: repo-wide scan passed, 0 occurrences across all 4 deliverable trees)*
- [x] Confirm both cslib agents now reference `summary-format.md`:
      `grep -l 'summary-format' agent-system/extensions/cslib/agents/cslib-implementation*.md`
      lists both files. *(completed: both files listed)*
- [x] Record in the implementation summary's `## Follow-ups` the out-of-scope gaps the research
      surfaced: `web`, `lean` base, `epi`, and `founder` implementation agents have the same
      no-reference failure mode; `latex`, `python`, `typst`, `z3` use an indirect pointer instead
      of a direct reference; and `progress-file.md`'s documented schema lacks the `deviations`
      array its consumers reference. *(completed: recorded in the implementation summary)*
- [x] Delete the scratch summary file. *(completed: verification-scratch/ removed)*

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the verification bar is reachable — that a summary built
from the Phase 3 skeleton produces exactly zero errors and zero auto-repaired fields. Confirm by
running the validator and reading its actual counts; do not infer success from the absence of a
crash. If any error or fix appears, treat the named missing field or section as a Phase 3/4 defect
and fix it there before closing this phase.

**Files to modify**:

- None. This phase is verification and reporting only; its output lands in the implementation
  summary.

**Verification**:

- Validator run on the representative summary: 0 errors, 0 fixes, exit code 0.
- Zero changed paths under `.claude/`.
- Zero task-number citations in the four changed files.
- Both cslib agent files match a `summary-format` grep.
- Scratch file removed; `git status --short` shows only the four intended source-store files plus
  this task's `specs/` artifacts.

## Testing & Validation

- [ ] `bash -n` passes on `validate-artifact.sh`.
- [ ] Validator output on a pre-existing summary artifact is byte-identical before and after the
      Phase 2 edit (enforcement freeze).
- [ ] A summary built from the new cslib skeleton validates with 0 errors and 0 auto-repaired
      fields.
- [ ] Every required metadata field name and section name in the new skeleton matches
      `SUMMARY_METADATA` / `SUMMARY_SECTIONS` by exact spelling.
- [ ] `## Plan Deviations` is documented in `summary-format.md` and positioned identically in the
      standard's example skeleton and the base agent's skeleton.
- [ ] All four changed files are under `agent-system/extensions/`; none under `.claude/`.
- [ ] No task-number citations in any changed file outside `specs/`.

## Artifacts & Outputs

- `specs/963_resolve_cslib_summary_format_divergence/plans/01_resolve-summary-format-divergence.md`
  (this file)
- `specs/963_resolve_cslib_summary_format_divergence/summaries/01_{short-slug}-summary.md`
- Modified: `agent-system/extensions/core/context/formats/summary-format.md`
- Modified: `agent-system/extensions/core/scripts/validate-artifact.sh`
- Modified: `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
- Modified: `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`

## Rollback/Contingency

All five phases are additive markdown and comment edits to four tracked files in the source store;
no generated or deployed state is mutated. Each phase commits separately per the
commit-per-green-substep mandate, so any single phase can be reverted with `git revert` on its
commit without disturbing the others.

Phase-specific contingencies:

- If the Phase 2 behavior-freeze check shows any output difference, revert the
  `validate-artifact.sh` edit immediately and re-apply as comments only. Phase 2 is
  documentation parity; it is never worth an enforcement change.
- If the Phase 5 validator run reports errors or fixes, do **not** relax the bar or amend the
  validator to pass. Treat it as a Phase 3/4 skeleton defect, fix the named field or section
  there, and re-run.
- If Phase 1's Scope Hypothesis check finds `summary-format.md` and `validate-artifact.sh`
  already disagree on the required-section set, stop and mark the task `[BLOCKED]` with that
  divergence recorded — Phases 2-4 all assume the two are in sync, and proceeding would encode
  the wrong set into the cslib skeleton.
