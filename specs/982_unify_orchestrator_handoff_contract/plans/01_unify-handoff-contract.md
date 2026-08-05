# Implementation Plan: Task #982

- **Task**: 982 - One handoff schema, one writer, one validator
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 974 (completed)
- **Research Inputs**: specs/982_unify_orchestrator_handoff_contract/reports/01_unify-handoff-contract.md
- **Artifacts**: plans/01_unify-handoff-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four disagreeing descriptions of `.orchestrator-handoff.json` coexist (schema doc, wrap-up
contract, bash validator, readers' union), and the only live writer omits two fields both
orchestrate engines read unconditionally. This plan establishes ONE machine-checkable JSON Schema
file as the single source of truth, rewrites `validate-handoff.sh` to enforce exactly that schema
with bidirectional test fixtures, deletes the zero-caller `skill_write_orchestrator_handoff`
(which simultaneously retires the second continuation form), aligns the live writer prose to the
schema, and closes with a redeploy-and-verify pass because the edit set includes
orchestrator-critical paths. Done means: the schema file exists, the validator accepts a
conformant handoff and rejects a non-conformant one in tests, both engines extract identical
fields from one shared fixture, no reader jq path names a field absent from the schema, and the
live deployed tree is verified after redeploy.

### Research Integration

The research report is honored in full. Its five decisions are adopted verbatim as this plan's
binding decisions (see Goals below): canonical blocker shape = the wrap-up/hard shape; canonical
continuation form = flat `continuation_path`; `.orchestrator-handoff.json` is formally
hard-mode-implement-only; `skill_write_orchestrator_handoff` is deleted rather than wired up;
`validate-handoff.sh` gains the full 6-value status vocabulary plus an `artifacts` check. Two
research findings drive specific phases: the newly-verified **artifact-linking defect** (the live
hard-mode writer emits no `artifacts` field, so `handoff_artifact_path=""` and
`skill_link_artifacts` is silently skipped) is fixed in Phase 4; the finding that the two engines'
readers are **already reconciled** means Phase 6 is a verification-and-lock-in phase, not a
reconciliation phase.

Three grounding facts were verified directly against the source store while planning, and the
plan's sequencing depends on them:

- `validate-handoff.sh` IS wired — `skill-base.sh`'s `skill_corroborate_phase_counts` invokes it
  as a **non-gating** diagnostic (`... || true`). Tightening it therefore cannot break a live
  dispatch, which is why Phase 2 can precede the redeploy safely.
- `context/schemas/` is declared as a **directory** in `manifest.json`, so a new schema file
  inside it is copied automatically. `scripts/tests/*` are enumerated **individually**, so each
  new test script requires an explicit `manifest.json` entry.
- Deleting `skill_write_orchestrator_handoff` requires touching cross-reference comments in files
  beyond the declared `file_scope` (see Scope Boundary below).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (none provided in delegation context).

### Scope Boundary

The task's declared `file_scope` is authoritative for the substantive edits. Implementation
additionally requires these files, all of which are mechanically entailed by the declared scope
rather than being scope creep — each is named here so the implementer does not have to
re-litigate the boundary mid-phase:

| Additional file | Why entailed | Nature of edit |
|-----------------|--------------|----------------|
| `core/scripts/tests/test-validate-handoff.sh` (new) | The verification bar demands bidirectional validator tests | New file |
| `core/scripts/tests/test-handoff-reader-parity.sh` (new) | The verification bar demands identical-fixture engine extraction | New file |
| `core/manifest.json` | New `scripts/tests/*` entries are enumerated individually, not by directory | Two array entries |
| `core/scripts/orchestrate-triage-classify.sh` | Carries a comment naming the deleted function | Comment only |
| `core/hooks/validate-handoff-location.sh` | Carries a comment naming the deleted function | Comment only |

**Deliberately OUT of scope** (do not edit; record as follow-up in the summary):

- All cslib agent files — excluded by the task description; the downstream cslib
  terminal-metadata task propagates this task's decisions to them.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — the research report
  recommends fixing its Stage 5 template (missing `artifacts`, redundant
  `continuation_context: null`). It is NOT in the declared `file_scope`, and it sits in a
  different extension. Treat it identically to the cslib exclusion: leave it alone, and name it
  explicitly in the implementation summary as an unlanded, known-needed follow-up. Silently
  editing it would collide with the same extension-propagation boundary the cslib exclusion
  exists to protect.

## Goals & Non-Goals

**Goals**:

- One machine-checkable JSON Schema file at
  `core/context/schemas/orchestrator-handoff-schema.json` is the single source of truth; every
  prose document points at it rather than restating it.
- `validate-handoff.sh` enforces exactly that schema: 6-value status vocabulary
  (`researched|planned|implemented|partial|failed|blocked`), an `artifacts` presence/shape check
  (non-empty required only when status is `researched`/`planned`/`implemented`), the existing
  `{phase, target}` blocker check retained, all existing skeleton/sorry_inventory checks retained
  byte-for-byte in behavior.
- Exactly one writer channel per mode: `.orchestrator-handoff.json` is hard-mode-implement-only;
  `.return-meta.json` + `orchestrate-recover-outcome.sh` is the base-mode channel.
  `skill_write_orchestrator_handoff` is deleted.
- The live hard-mode writer template emits `summary` and `artifacts`, closing the silent
  artifact-linking defect.
- Bidirectional validator tests and a two-engine reader-parity test exist and pass.
- The live `.claude/` tree is redeployed and verified at the end.

**Non-Goals**:

- Re-litigating the research-phase writer question. It is already settled (research agents never
  write a handoff; `general-research-hard-agent.md`'s Stage 3.6 Scoping Decision already says so).
  This task only makes the schema doc's writer table agree with it in one place.
- Absorbing the handoff-present corroboration gate work (separate task) or the malformed-status
  recovery work in `reconcile-task-status.sh` (separate task, already completed — this task
  reduces its trigger frequency, it does not replace it).
- Ripping the nested-`continuation_context` **reader** branch out of either engine or out of
  `orchestrate-triage-classify.sh`. See the decision below.
- Redesigning the base engine's blocker-escalation flow. Phase 6 makes its handoff read safe and
  documented; it does not rearchitect it.
- Editing cslib or lean extension agent files.

### Binding decision: one WRITE form, deprecated-but-accepted READ form

WORK item 1 requires "one continuation form". This is satisfied at the **writer** level: after
`skill_write_orchestrator_handoff` is deleted, no writer anywhere emits nested
`continuation_context`, so the flat top-level `continuation_path` is the one canonical form and
the only form the schema documents as writable.

The **reader-side** dual-form resolution in both engines and in
`orchestrate-triage-classify.sh` is deliberately RETAINED as inert backward-compatibility. Two
reasons: (a) `test-orchestrate-triage-classify.sh` asserts the dual-form `continuation_ok`
predicate, so removing it turns a documentation cleanup into a test-breaking behavior change on
an orchestrator-critical path; (b) an in-flight handoff written by a pre-change dispatch could
still carry the nested form. The schema marks `continuation_context` as deprecated and
read-only-accepted; `additionalProperties: true` keeps such a document schema-valid. Do not
narrow the readers in this task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tightening `validate-handoff.sh` newly fails legitimate in-flight `partial`/`blocked` handoffs that have no artifact yet | H | H | Make the `artifacts`-non-empty requirement conditional on `status ∈ {researched, planned, implemented}`; `partial`/`blocked`/`failed` may carry `[]`. Verified-required by the research report's risk section |
| Tightening `validate-handoff.sh` breaks a live dispatch | H | L | Verified at plan time: its only caller (`skill_corroborate_phase_counts` in `skill-base.sh`) invokes it with `\|\| true` as a non-gating diagnostic. Phase 2 must re-confirm this before landing, not assume it |
| `test-corroborate-phase-counts.sh` Fixture H asserts `validate-handoff.sh` exits non-zero on a null-count handoff | M | M | That assertion is a *sanity precondition* that stays true under a stricter validator. Phase 2 must run this existing test, not just the new one |
| Deleting the function while doc cross-references still name it leaves dangling references | M | H | Phase 3 deletes the function and its two comment-only cross-references; Phase 5 clears the seven references in `handoff-schema.md` and the three in the two SKILL.md files. Phase 7 greps for zero remaining live references |
| Editing the hard-mode writer template silently drops the existing `skeleton`/`sorry_inventory`/`git_checkpoint` machinery | H | M | Phase 4 is additive-only. Re-read the full Stage 5 section (including the `git_checkpoint` sub-section) before editing; never rewrite the template from the plan's excerpt |
| New test scripts never reach `.claude/scripts/tests/` because the headless sync skips already-loaded extensions' `copy_scripts` | M | H | Known, documented deploy gap. Phase 7 explicitly verifies propagation of both new test files into the deploy tree and applies the loader's copy primitives directly if the sync did not carry them |
| Redeploy overwrites in-flight orchestrator state mid-task | M | L | Phase 7 is last, is its own phase, and runs only after every source-store edit is committed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5, 6 | 2, 3, 4 |
| 4 | 7 | 5, 6 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch disjoint file sets
(validator+tests+manifest / `skill-base.sh` / writer prose) and may be dispatched in parallel with
explicit file ownership.

---

### Phase 1: Author the canonical JSON Schema file [COMPLETED]

**Goal**: Create the single machine-checkable source of truth every later phase references.

**Tasks**:
- [x] Read `core/context/schemas/events-schema.json` to match its draft-07 style, key ordering, and
      `title`/`description` conventions. *(completed)*
- [x] Create `core/context/schemas/orchestrator-handoff-schema.json` with
      `"title": "Orchestrator Handoff JSON Schema (orchestrator-handoff-v1)"`, matching the shape
      recommended in the research report's Recommendation 1. *(completed)*
- [x] Required: `status`, `summary`, `artifacts`, `phases_completed`, `phases_total`, `blockers`. *(completed)*
- [x] `status` enum: `researched`, `planned`, `implemented`, `partial`, `failed`, `blocked`. *(completed)*
- [x] `artifacts` items: `required: [type, path]`, with an optional `summary` string — this is the
      first time `artifacts[].summary` is documented anywhere despite every reader site reading it. *(completed)*
- [x] `blockers` items: the canonical hard/wrap-up shape `{phase, target, verbatim_goal,
      what_was_tried, why_it_failed}` with `required: [phase, target]`. Do NOT include
      `description` or `severity` — both are verified dead (read by neither engine). *(completed)*
- [x] Optional properties: `phase`, `plan_markers_verified`, `skeleton`, `sorry_inventory`,
      `continuation_path`, `next_action_hint`, `git_checkpoint`. *(completed)*
- [x] Include `continuation_context` with a `deprecated: true` annotation and a `description`
      stating it is accepted on read for backward compatibility and MUST NOT be written. *(completed)*
- [x] Set `"additionalProperties": true`. *(completed)*
- [x] Add a top-of-file `description` recording the three binding decisions: hard-mode-implement
      only; flat continuation form is the only writable form; the blocker shape is the wrap-up
      shape. *(completed)*
- [x] Verify: `jq empty` parses the file, and every `required` name appears in `properties`. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` (new) - the
  canonical schema

**Verification**:
- `jq empty` on the new file exits 0.
- `jq -r '.required[]' <file>` prints exactly the six required names.
- `jq -r '.properties.blockers.items.properties | keys[]' <file>` contains no `description` and
  no `severity`.
- No `manifest.json` change needed — `context/schemas` is declared as a directory. Confirm this by
  reading the manifest's `provides.context` array rather than assuming it.

---

### Phase 2: Rewrite validate-handoff.sh and add bidirectional tests [NOT STARTED]

**Goal**: Make the validator enforce exactly the Phase 1 schema, proven in both directions by
tests.

**Tasks**:
- [ ] Re-confirm the caller contract before editing: `grep -n 'validate-handoff.sh'
      core/scripts/skill-base.sh` and verify the invocation is still non-gating (`|| true`).
      Record the confirmation in the phase notes. If it is NOT non-gating, STOP and re-scope.
- [ ] Expand `valid_statuses` from `("implemented" "partial" "blocked")` to the full six-value
      vocabulary. Update the `--help` text's status line to match.
- [ ] Add `artifacts` to the required-field logic with the conditional rule: the field must be
      present and be a JSON array in all cases; it must additionally be non-empty when `status` is
      `researched`, `planned`, or `implemented`. An empty array is legal for `partial`, `blocked`,
      and `failed`.
- [ ] Add `summary` as a required, non-empty string field (both engines read
      `.summary` unconditionally).
- [ ] When `artifacts` is non-empty, check entry 0 has `type` and `path`; warn (do not fail) when
      `summary` is absent from an entry, since it is optional in the schema.
- [ ] Keep Check 7's `{phase, target}` blocker validation unchanged — the research verified it is
      already aligned with the canonical shape.
- [ ] Keep all skeleton / `sorry_inventory` logic (Check 3) behaviorally unchanged.
- [ ] Update the `--help` block's "Required fields" / "Optional fields" lines and the
      "Contract reference" header comment to name
      `context/schemas/orchestrator-handoff-schema.json` as the authority alongside `wrap-up.md`.
- [ ] Create `core/scripts/tests/test-validate-handoff.sh` following the structure and
      pass/fail/info helpers used by `test-corroborate-phase-counts.sh`.
- [ ] ACCEPT fixtures (validator must exit 0): a conformant hard-mode `implemented` handoff with
      `summary` + non-empty `artifacts`; a `partial` handoff with `artifacts: []` and a non-null
      `continuation_path`; a `researched`-status handoff with a report artifact (this last one
      would have FAILED the pre-change validator — it is the regression the fix exists to close).
- [ ] REJECT fixtures (validator must exit non-zero): a handoff missing `artifacts` entirely; a
      handoff missing `summary`; an `implemented` handoff with `artifacts: []`; a handoff with an
      off-vocabulary status such as `"done"`.
- [ ] Register `tests/test-validate-handoff.sh` in `core/manifest.json`'s scripts array,
      preserving the array's existing ordering convention.
- [ ] Run the new test and the existing `test-corroborate-phase-counts.sh` (whose Fixture H
      asserts validator behavior) — both must pass.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that `validate-handoff.sh` has exactly one caller
(`skill_corroborate_phase_counts` in `skill-base.sh`) and that the call is non-gating; and that
`test-corroborate-phase-counts.sh` is the only existing test whose assertions depend on this
validator's exit code. Confirm at implementation time by
`grep -rn 'validate-handoff.sh' agent-system/extensions/` before making any edit, and by running
the full `core/scripts/tests/` suite rather than only the two named tests. If a third dependent
surfaces, widen this phase's task list rather than proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-handoff.sh` - status enum, `artifacts` and
  `summary` checks, `--help` and header text
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` (new) - bidirectional
  fixtures
- `agent-system/extensions/core/manifest.json` - register the new test script

**Verification**:
- `bash core/scripts/tests/test-validate-handoff.sh` exits 0 with all accept and reject fixtures
  asserted.
- `bash core/scripts/tests/test-corroborate-phase-counts.sh` still exits 0.
- The whole `core/scripts/tests/` suite still passes.
- `jq -r '.provides.scripts[]' core/manifest.json | grep test-validate-handoff` returns the entry.

---

### Phase 3: Delete skill_write_orchestrator_handoff [NOT STARTED]

**Goal**: Collapse to one writer channel by removing the zero-caller function, its env-var
scaffolding, and the two comment-only cross-references outside the docs.

**Tasks**:
- [ ] Re-confirm zero callers immediately before deleting:
      `grep -rn 'skill_write_orchestrator_handoff' agent-system/extensions/` — every hit must be a
      comment or documentation reference, never an invocation. If an invocation exists, STOP.
- [ ] Delete the `skill_write_orchestrator_handoff()` function body from `skill-base.sh`.
- [ ] Delete its usage header block and DISPOSITION comment, including the three
      `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` / `ORCHESTRATOR_HANDOFF_PHASES_COMPLETED` /
      `ORCHESTRATOR_HANDOFF_PHASES_TOTAL` "Optional (set before calling)" documentation lines.
      These env vars are read nowhere else — confirm with a fresh grep before removing.
- [ ] Update the `skill-base.sh` orchestrator-mode overview comment that currently says skills
      "call `skill_write_orchestrator_handoff()` when `orchestrator_mode=true`" to state the
      decided contract instead: base-mode research/plan/implement return via `.return-meta.json`
      (recovered by `orchestrate-recover-outcome.sh`); only the hard-mode implementation agent
      writes `.orchestrator-handoff.json`, via the Write tool.
- [ ] Update the comment in `core/scripts/orchestrate-triage-classify.sh` that names the function
      as the nested-form writer: state that the nested form now has NO writer and is retained on
      the read side for backward compatibility only. Do not change the predicate's logic.
- [ ] Update the comment in `core/hooks/validate-handoff-location.sh` that cites the function as
      the Bash-redirection write path example: the hook's structural blindness to Bash-redirect
      writes is still true and still worth stating, but the example writer no longer exists —
      reword to describe the class, not the deleted function.
- [ ] Verify `skill-base.sh` still sources cleanly and every remaining function is intact.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that the three `ORCHESTRATOR_HANDOFF_*` environment
variables are referenced only inside the deleted function and its own header comment, and that
exactly two non-documentation files (`orchestrate-triage-classify.sh`,
`validate-handoff-location.sh`) carry comment references needing rewording. Confirm by
`grep -rn 'ORCHESTRATOR_HANDOFF_' agent-system/extensions/` and
`grep -rn 'skill_write_orchestrator_handoff' agent-system/extensions/` at implementation time.
The documentation references in `handoff-schema.md` and the two orchestrate SKILL.md files are
deliberately deferred to Phase 5 and are NOT part of this hypothesis.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - delete function, header, env-var docs;
  correct the orchestrator-mode overview comment
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - comment only
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` - comment only

**Verification**:
- `bash -n core/scripts/skill-base.sh` exits 0.
- `bash -c 'source core/scripts/skill-base.sh; declare -F' | grep -c skill_write_orchestrator_handoff`
  returns 0.
- Every other `skill_*` function previously declared by the file is still declared (compare the
  `declare -F` output before and after).
- `grep -rn 'ORCHESTRATOR_HANDOFF_' agent-system/extensions/` returns nothing.
- The full `core/scripts/tests/` suite still passes.

---

### Phase 4: Align the live writer contracts to the schema [NOT STARTED]

**Goal**: Fix the artifact-linking defect by making the two live writer-facing documents emit
`summary` and `artifacts`.

**Tasks**:
- [ ] Read `core/context/contracts/wrap-up.md`'s "Orchestrator Handoff JSON Schema" section in
      full before editing.
- [ ] Add `"summary"` (required, string) and `"artifacts"` (required array, may be `[]`) to
      wrap-up.md's "Required fields" JSON block, with `artifacts` entries showing
      `{type, path, summary}`.
- [ ] Add field-semantics bullets for both: `summary` is what the orchestrator surfaces as the
      dispatch summary; `artifacts` is what `skill_link_artifacts` consumes — an absent or empty
      `artifacts` on an `implemented` handoff silently prevents the summary artifact from being
      linked into `state.json`.
- [ ] Add a one-line note that `phase` is optional and informational.
- [ ] Add a pointer to `context/schemas/orchestrator-handoff-schema.json` as the machine-checkable
      authority, keeping wrap-up.md as the H9 prose contract.
- [ ] Read `core/agents/general-implementation-hard-agent.md` Stage 5 in full, INCLUDING the
      `git_checkpoint` checkpoint sub-section and the skeleton example block, before editing.
- [ ] Add `"summary"` and `"artifacts"` to the Stage 5 Step 1 base handoff template. This is the
      fix for the verified defect, not a documentation nicety.
- [ ] Add the same two fields to the skeleton example block so the two templates do not diverge.
- [ ] Add a one-sentence instruction that `artifacts` must name the implementation summary file
      the dispatch produced, with `type: "summary"`, and that omitting it silently breaks
      artifact linking.
- [ ] Confirm additive-only: `skeleton`, `sorry_inventory`, `blockers`, `continuation_path`, and
      the `git_checkpoint` field are all still present and unchanged after the edit.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/wrap-up.md` - add `summary` and `artifacts` to
  the required-fields block plus semantics bullets and a schema pointer
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - add `summary` and
  `artifacts` to both Stage 5 handoff templates

**Verification**:
- Every JSON block edited in both files parses: extract each fenced block and run `jq empty`.
- The templates, when instantiated with plausible values, pass the Phase 2 validator — construct
  one instantiated fixture per template and run `validate-handoff.sh` against it.
- Diff review confirms no pre-existing field was removed from either file.

---

### Phase 5: Rewrite handoff-schema.md and align hard-agent cross-references [NOT STARTED]

**Goal**: Make the authoritative prose document agree with the schema file, retire the dead
shapes, and correct every reference to the deleted writer.

**Tasks**:
- [ ] Replace the "Complete JSON Schema" section's hand-maintained block with a pointer to
      `context/schemas/orchestrator-handoff-schema.json` plus a short illustrative example,
      mirroring how other schemas in `context/schemas/` are referenced from their owning docs.
      The prose doc must stop being a second, independently-driftable schema.
- [ ] Fold the previously-undocumented fields into the Field Definitions section: `skeleton`,
      `sorry_inventory`, `git_checkpoint`, and `artifacts[].summary`.
- [ ] Retire the `{description, phase, severity}` blocker shape from the `blockers` field
      definition; replace it with the canonical `{phase, target, verbatim_goal, what_was_tried,
      why_it_failed}` shape, and state explicitly that `description` and `severity` were read by
      no engine and are removed.
- [ ] Rewrite the "Two Accepted Forms" section as one WRITE form with a deprecated READ-accepted
      form, per this plan's binding decision. Keep the reader-side dual-form resolution
      documentation accurate — it still exists in both engines.
- [ ] Update the "Handoff Writers" table: remove the `skill_write_orchestrator_handoff` row
      entirely (the function no longer exists), and make the table state the settled writer
      decision in one place — hard-mode implementation agent writes the handoff; research agents
      never do (preserving the existing Stage 3.6 Scoping Decision, not re-deciding it); base-mode
      research/plan/implement return via `.return-meta.json`.
- [ ] Rewrite or delete the "Partial with Continuation (nested form)" example, which is captioned
      as the deleted function's shape.
- [ ] Clear the remaining references to the deleted function throughout the document (research
      counted seven sites; re-derive the live count by grep rather than trusting that number).
- [ ] Update the "Outcome Channels" section to state the decided one-channel-per-mode contract.
- [ ] Update the three comment references to the deleted function in
      `core/skills/skill-orchestrate/SKILL.md` and `core/skills/skill-orchestrate-hard/SKILL.md`.
      These are comments inside bash blocks explaining WHY dual-form resolution exists and why the
      location hook cannot see Bash-redirect writes — reword to describe the class of writer, not
      the deleted function. Do not change any jq or logic in this phase.
- [ ] Verify `core/agents/general-research-hard-agent.md`'s Stage 3.6 Scoping Decision still reads
      correctly against the new schema doc (it should need no change; if its cross-reference names
      a section that was renamed, fix the reference only).
- [ ] Verify `core/agents/planner-hard-agent.md`'s single `wrap-up.md` cross-reference (for the
      `skeleton` boolean and `sorry_inventory` schema) is still accurate after Phase 4's edits;
      add a pointer to the schema file if the reference is bare.

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that `handoff-schema.md` contains seven references to
the deleted function and that the two orchestrate SKILL.md files contain three between them.
Confirm at implementation time with `grep -c 'skill_write_orchestrator_handoff'` per file before
starting and again after finishing (the after-count must be zero across the whole tree). Treat
the numbers above as a hypothesis; if the live counts differ, the live counts govern.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - schema pointer, field
  definitions, blocker shape, continuation forms, writers table, examples
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - comments only
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - comments only
- `agent-system/extensions/core/agents/general-research-hard-agent.md` - cross-reference check
- `agent-system/extensions/core/agents/planner-hard-agent.md` - cross-reference check

**Verification**:
- `grep -rn 'skill_write_orchestrator_handoff' agent-system/extensions/` returns nothing.
- `grep -rn 'severity' core/docs/architecture/handoff-schema.md` returns no blocker-shape usage.
- Every fenced JSON example remaining in `handoff-schema.md` parses under `jq empty` AND passes
  `validate-handoff.sh` (any example that cannot pass the validator is either wrong or must be
  explicitly captioned as a rejection example).
- No jq expression or bash logic changed in either SKILL.md — confirm with a diff review showing
  only comment lines altered.

---

### Phase 6: Reader grep-audit and two-engine parity test [NOT STARTED]

**Goal**: Prove and lock in the verification bar's two reader-side conditions.

**Tasks**:
- [ ] Grep-audit every handoff jq path in both engines: `.status`, `.summary`, `.artifacts[0].*`,
      `.blockers*`, `.phases_completed`, `.phases_total`, `.plan_markers_verified`, `.skeleton`,
      `.sorry_inventory`, `.next_action_hint`, `.continuation_path`, `.continuation_context.*`.
- [ ] For each distinct field name found, assert it appears in the Phase 1 schema's `properties`.
      Any path naming a field absent from the schema is either a reader bug or a schema gap —
      resolve it, do not paper over it.
- [ ] Create `core/scripts/tests/test-handoff-reader-parity.sh`. It builds ONE shared handoff
      fixture, extracts the reader jq expressions from both SKILL.md files, evaluates each against
      the fixture, and asserts the two engines produce identical values for every field both
      read. The hard engine additionally reading `.skeleton`, `.sorry_inventory`,
      `.blockers[0].target`, and `.blockers[0].verbatim_goal` is an expected, allowlisted
      hard-only difference, not a parity failure — encode the allowlist explicitly so a future
      unlisted divergence fails the test.
- [ ] Assert the fixture used by the parity test passes `validate-handoff.sh` — the same fixture
      must satisfy both the validator and both readers, which is what "one schema" means
      operationally.
- [ ] Register `tests/test-handoff-reader-parity.sh` in `core/manifest.json`.
- [ ] Address the base engine's blocker-escalation handoff read: Step 3 of the escalation flow in
      `skill-orchestrate/SKILL.md` reads `.summary` and `.artifacts[0].path` from `$handoff_file`
      after dispatching a `fork` with `orchestrator_mode: false` — a dispatch that by contract
      writes no handoff, so the read silently yields empty findings. Minimal fix only: make the
      read explicitly defensive and add a comment stating that a `orchestrator_mode: false`
      dispatch produces no handoff and the fork's returned text is the real findings channel.
      Do NOT rearchitect the escalation flow.
- [ ] Run the full `core/scripts/tests/` suite.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that the two engines already read identical jq paths at
every shared content site, with the hard engine's four extra reads as the only difference — the
research report's grep-audit finding. Confirm by running the grep-audit as the phase's first step,
before writing the parity test. If the engines are NOT already reconciled, the divergence must be
resolved (aligning the base engine to the hard engine's shape) and this phase's effort estimate
revised upward rather than the test being written around the divergence.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` (new) - shared-fixture
  parity assertions
- `agent-system/extensions/core/manifest.json` - register the new test script
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - defensive read plus comment
  in the blocker-escalation findings step

**Verification**:
- `bash core/scripts/tests/test-handoff-reader-parity.sh` exits 0.
- The grep-audit output shows zero reader jq paths naming a field absent from the schema; record
  the audit output in the phase notes as evidence.
- The full `core/scripts/tests/` suite passes.

---

### Phase 7: Redeploy the live system and verify end to end [NOT STARTED]

**Goal**: Make the changed orchestrator-critical machinery live and prove the deployed tree is
correct — deliberately last, because this phase touches `skill-base.sh` and both orchestrate
engines in the running system.

**Tasks**:
- [ ] Confirm every source-store edit from Phases 1-6 is committed before redeploying.
- [ ] Redeploy the core extension via the sanctioned path
      (`.claude/scripts/deploy-headless.sh`, or the loader's "Load Core" sync).
- [ ] Verify the new schema file reached `.claude/context/schemas/orchestrator-handoff-schema.json`.
- [ ] Verify BOTH new test scripts reached `.claude/scripts/tests/`. This is the documented
      deploy gap: the headless sync does not re-run `copy_scripts` for an already-loaded
      extension, so brand-new `scripts/<subdir>/*.sh` files can silently fail to propagate. If
      either file is missing, invoke the loader's copy primitives directly and re-verify.
- [ ] Verify the deployed `.claude/scripts/skill-base.sh` no longer defines
      `skill_write_orchestrator_handoff`.
- [ ] Verify the deployed `.claude/scripts/validate-handoff.sh` carries the six-value status enum.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and require a PASS. Its gate 4 (task-reference
      lint) is the mechanical check for the DELIVERABLE RULE across everything written in this
      task.
- [ ] Run the full deployed test suite from `.claude/scripts/tests/`.
- [ ] Run `bash .claude/scripts/validate-handoff.sh --help` and confirm the help text describes
      the new contract.
- [ ] End-to-end confirmation of the third verification-bar condition. The research report
      established this is a *confirm*, not a *build*: base-mode `/orchestrate` already produces no
      handoff and no recovery-bridge warnings. Confirm against the most recent base-mode
      orchestrator run available (this task's own `/orchestrate` cycle qualifies) by checking that
      no `.orchestrator-handoff.json` was written for it and that
      `orchestrate-recover-outcome.sh` recovered its outcome without warnings. A live scratch-task
      cycle is preferable if one can be run cheaply; if not, record which evidence was used and
      why, rather than claiming an unrun cycle.

**Timing**: 1 hour

**Depends on**: 5, 6

**Verification Tier**: full

**Files to modify**:
- None in the source store. This phase writes only to the disposable `.claude/` deploy artifact
  via the sanctioned deploy process, which is explicitly exempt from the source-store rule.

**Verification**:
- `verify-deploy.sh` exits 0.
- Both new test files exist under `.claude/scripts/tests/` and pass when run from there.
- `grep -c skill_write_orchestrator_handoff .claude/scripts/skill-base.sh` returns 0.
- `grep -rn 'skill_write_orchestrator_handoff' .claude/ agent-system/` returns nothing.

---

## Testing & Validation

- [ ] `test-validate-handoff.sh` passes: three accept fixtures and four reject fixtures, both
      directions asserted.
- [ ] `test-handoff-reader-parity.sh` passes: one shared fixture, identical extraction across both
      engines, hard-only fields explicitly allowlisted.
- [ ] `test-corroborate-phase-counts.sh` still passes (its Fixture H depends on validator exit
      behavior).
- [ ] `test-orchestrate-triage-classify.sh` still passes (its `continuation_ok` predicate depends
      on retained dual-form reader acceptance).
- [ ] The full `core/scripts/tests/` suite passes in the source store and again from the deploy
      tree.
- [ ] Grep-audit evidence recorded: zero reader jq paths reference a field absent from the schema.
- [ ] `grep -rn 'skill_write_orchestrator_handoff'` returns nothing across both trees.
- [ ] `verify-deploy.sh` PASSes, including gate 4's task-reference lint over every file written.
- [ ] Every fenced JSON example in `wrap-up.md`, `handoff-schema.md`, and
      `general-implementation-hard-agent.md` parses and (unless captioned as a rejection example)
      passes `validate-handoff.sh`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` (new)
- Modified: `scripts/validate-handoff.sh`, `scripts/skill-base.sh`,
  `scripts/orchestrate-triage-classify.sh`, `hooks/validate-handoff-location.sh`,
  `context/contracts/wrap-up.md`, `docs/architecture/handoff-schema.md`,
  `agents/general-implementation-hard-agent.md`, `agents/general-research-hard-agent.md`,
  `agents/planner-hard-agent.md`, `skills/skill-orchestrate/SKILL.md`,
  `skills/skill-orchestrate-hard/SKILL.md`, `manifest.json` (all under
  `agent-system/extensions/core/`)
- `specs/982_unify_orchestrator_handoff_contract/summaries/01_unify-handoff-contract-summary.md`
- Summary must name the two deliberate exclusions (cslib agents, lean hard implementation agent)
  as unlanded follow-ups.

## Rollback/Contingency

Every phase is a set of source-store file edits under git with per-substep commits, so rollback is
`git revert` of the phase's commits followed by a redeploy. Three ordering properties make partial
rollback safe:

- Phase 1 is purely additive (a new file nothing yet references) and can be left in place under
  any partial rollback.
- Phase 2's validator tightening is non-gating at its only call site, so reverting it degrades a
  diagnostic rather than breaking a dispatch.
- Phase 3 is the only irreversible-feeling change (deleting a function). It is safe because the
  function has zero callers; if a rollback is ever needed, the deleted body is recoverable from
  git history.

If Phase 7's redeploy leaves the live tree inconsistent, re-run the full "Load Core" sync from a
clean source-store checkout — `.claude/` is a disposable deploy artifact regenerated from
`agent-system/extensions/**`, so a full regeneration is always a valid recovery path.
