# Implementation Plan: return_meta_artifacts_shape_contract

- **Task**: 52 - return_meta_artifacts_shape_contract
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: specs/052_return_meta_artifacts_shape_contract/reports/01_return-meta-artifacts-shape.md
- **Artifacts**: plans/01_return-meta-artifacts-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`.return-meta.json`'s `artifacts` field is normatively an array of `{type, path, summary}`
objects, but nothing enforces that shape and roughly a quarter of dispatchable agents are given
no inline example to copy. A bare-string array survives every existing check and silently
resolves to an empty `artifact_path`, so artifact linking becomes a no-op without saying so.
This plan closes the gap on four fronts: it records the contract posture as a single canonical
fragment, adds the missing `validate-return-meta.sh` sibling validator, backfills an inline
template into every template-less agent, normalizes at the one shared consumer chokepoint with a
loud notice, closes the handoff-present detection hole, and converts the whole class into a
deploy-time lint failure.

### The Explicit Decision (required by the task description)

**The contract stays STRICT; the consumer normalizes at a single chokepoint and shouts.**

Neither pure tolerance nor pure strictness is adopted. Concretely:

| Layer | Posture |
|-------|---------|
| Normative doc (`return-metadata-file.md`) | Strict. A bare-string array is never valid, in any context. |
| `validate-return-meta.sh` | Strict. Bare strings FAIL (exit 1). `--fix` performs the unambiguous repair on request, never implicitly. |
| Consumer chokepoint (`skill_read_metadata`) | Normalizes so the artifact link is not lost, but emits a loud stderr notice AND records an `ARTIFACTS_SHAPE_MISMATCH` system defect. |
| Agent contracts | Strict. Every dispatchable agent carries a correct inline template; the lint fails the deploy if one does not. |

Rationale: tolerance-without-noise entrenches the malformed shape (the failure becomes free);
strictness-without-recovery loses completed work over a metadata typo. Normalization paired with
a loud, recorded notice recovers the artifact while keeping the defect count visible and rising
until the producing agent is fixed. This matches the hypothesis the research report itself
proposed as most likely to capture both properties.

**Load-bearing ordering constraint**: normalization MUST NOT run before, or upstream of, the
`ARTIFACTS_SHAPE_MISMATCH` computation in `orchestrate-recover-outcome.sh`. That script is an
independent reader that does not source `skill-base.sh`; it must keep seeing the raw on-disk
shape, or the detector goes blind precisely when it is needed. See Risks.

### Research Integration

Findings carried directly into phases:

- The template-less agent set (~19 files) and the "has key, no object shape" set were re-verified
  live against the source store during planning, not taken on trust. The sweep also surfaced a
  **third tier the report did not separate**: `planner-agent`, `planner-hard-agent`,
  `general-research-hard-agent`, and `general-implementation-hard-agent` already carry the *prose*
  warning about `.artifacts[0].path` but still have **no inline JSON template**. Prose alone
  demonstrably did not prevent the observed failure; these agents need the template too.
- `core/general-implementation-agent.md` is confirmed as the model to copy.
- `orchestrate-recover-outcome.sh` computes the signal only on the recovered path;
  `skill-orchestrate/SKILL.md`'s own residual-gap note (Stage 5, branch 3) names the hole.
- `lint-agent-contracts.sh` already carries a **documented insertion point** for further checks
  that explicitly instructs reuse of `enumerate_dispatchable_agents`/`is_dispatchable_agent`.
  Check D and Check E names are already reserved there for other deferred work, so the new check
  is **Check F**. It runs inside `verify-deploy.sh` gate 6 — no new gate is needed.
- `core/context/contracts/no-task-references-bullet.md` is the established shape for a canonical
  copied-fragment plus a lint that reads the expected text from the fragment at runtime. The new
  artifacts-template fragment follows it exactly.
- `scripts/lib/` already holds sourced-anchor libraries (`phase-heading-patterns.sh`,
  `task-reference-patterns.sh`). The path-to-type inference belongs there so the validator and
  the consumer chokepoint cannot drift.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no `roadmap_flag` was set, so no
roadmap phases are included. For information only: `specs/ROADMAP.md` carries an open **Agent
frontmatter validation** item in the same lint family that Check F extends. This plan does not
claim or close that item.

## Goals & Non-Goals

**Goals**:
- Record the strict-contract-plus-normalizing-chokepoint decision in one canonical place.
- Ship `validate-return-meta.sh` with a `--fix` mode, as the missing sibling of
  `validate-handoff.sh`.
- Give every dispatchable agent a correct inline `artifacts` object template.
- Recover, rather than silently discard, a malformed array at the shared consumer chokepoint,
  while making the defect loud and recorded.
- Close the handoff-present detection hole named in `skill-orchestrate/SKILL.md`.
- Make a missing or malformed agent template a deploy-time failure via `lint-agent-contracts.sh`
  Check F.

**Non-Goals**:
- The `.return-meta.json` deletion-ordering defect (`fix_return_meta_lifecycle_ordering`). Named
  as independent by the task description and untouched here.
- Widening the normative schema to admit bare strings.
- Implementing the reserved Check D / Check E in `lint-agent-contracts.sh`.
- Any write to `.claude/**`. All edits target `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Normalization placed upstream of the detector blinds `ARTIFACTS_SHAPE_MISMATCH` | H | M | Phase 5 confines normalization to `skill_read_metadata` only. `orchestrate-recover-outcome.sh` is explicitly left reading raw. Phase 5 verification asserts the detector still fires on a bare-string fixture. |
| Check F lands before the backfill, breaking `verify-deploy.sh` gate 6 for everyone | H | M | Phase 7 depends on both backfill phases (3 and 4). Phase 7's first step re-runs the enumeration and refuses to proceed if any agent still lacks a template. |
| Backfilled template text drifts from the fragment | M | H | Check F reads expected text from the fragment at runtime, never hardcoded — the same mechanism Check C uses for the no-task-references bullet. |
| Type inference diverges between validator and chokepoint | M | M | Both source one `scripts/lib/return-meta-artifacts-lib.sh` anchor created in Phase 2. Neither re-derives the mapping inline. |
| `--fix` silently rewrites a file an agent is still writing | M | L | `--fix` is opt-in only, never implicit; it refuses on unparseable JSON and writes atomically via a temp file plus rename. |
| The asserted agent counts (19 template-less, 4 empty-array-only) are stale by implementation time | M | M | Both backfill phases carry a Scope Hypothesis requiring re-enumeration before editing. |
| Editing 23 agent files exhausts context mid-phase | M | M | Backfill split across two phases by extension group; each phase is a declared atomic batch with a single batch-level verification. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 6 | 1 |
| 3 | 5, 7 | 2; 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Record the Contract Posture and Create the Canonical Template Fragment [COMPLETED]

**Goal**: Establish one authoritative place stating the strict-plus-normalize decision and
holding the exact inline template text that every agent copies and Check F compares against.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md`,
      modeled structurally on `no-task-references-bullet.md` in the same directory. It must contain:
  - A "Generated-Copy Source, Not an `@`-Import" section stating the same constraint that
    fragment records (agent bodies carry a literal copy; the lint keeps copies in sync).
  - The canonical inline template text in a fenced JSON block, copied from
    `core/agents/general-implementation-agent.md`'s worked example, reduced to the `artifacts`
    array itself so research, plan, and implementation agents can all carry it verbatim.
  - A **classification rule** naming which agents MUST carry it: every dispatchable agent that
    writes `.return-meta.json`, i.e. every file matched by
    `lint-agent-contracts.sh`'s `is_dispatchable_agent` detector. State this as a decision, not
    an omission, and name any deliberate exclusion explicitly.
  - The path-segment type-inference table (`reports/` -> `report`, `plans/` -> `plan`,
    `summaries/` -> `summary`) as the single prose statement of the mapping Phase 2 implements.
  *(completed)*
- [x] Update `agent-system/extensions/core/context/formats/return-metadata-file.md`'s
      `### artifacts (required)` section to (a) state that a bare-string array is never valid in
      any context, (b) record the four-layer posture table from this plan's Overview, and (c)
      point to the new fragment as the canonical template source. *(completed)*
- [x] Add a short cross-reference from the fragment back to `return-metadata-file.md` as the
      normative schema, so neither file is readable as the sole authority. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md` - new fragment
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - record the decision, link the fragment

**Verification**:
- Both files exist and are non-empty; the fragment contains exactly one fenced JSON block holding
  the canonical template.
- `grep` confirms `return-metadata-file.md` names the fragment path and states the bare-string
  prohibition.
- Diff read-through confirms every changed hunk is prose or a fenced example, with no executable
  surface touched.

---

### Phase 2: Add validate-return-meta.sh and the Shared Inference Library [COMPLETED]

**Goal**: Ship the missing sibling validator, with the path-to-type inference factored into a
sourced anchor that Phase 5 reuses rather than re-deriving.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/return-meta-artifacts-lib.sh` exporting:
  - `infer_artifact_type <path>` implementing the Phase 1 mapping, returning empty for an
    unrecognized segment (never guessing).
  - `normalize_artifacts_array <json>` promoting each bare-string element to
    `{type: <inferred>, path: <string>, summary: ""}` and leaving well-formed objects untouched;
    emits on stdout, reports on stderr whether any element was promoted.
  - Follow the house conventions of `phase-heading-patterns.sh` and `task-reference-patterns.sh`:
    source-able from either the deployed or source-store copy, no side effects on source.
  *(completed: summary placeholder uses a non-empty "(auto-repaired...)" string rather than "" so
  --fix's own output independently re-validates as passing)*
- [x] Create `agent-system/extensions/core/scripts/validate-return-meta.sh`, modeled on
      `validate-handoff.sh` (same `--help` block shape, same colored output, same exit-code
      contract: `0` valid, `1` invalid, `3` file not found). Validation rules:
  - JSON parses.
  - `status` is drawn from the normative vocabulary in `return-metadata-file.md`; `completed` is
    rejected explicitly.
  - `artifacts` is present and is a JSON array.
  - Every element is an **object** carrying non-empty `type`, `path`, and `summary`. A bare
    string element is a FAIL naming the offending index and the exact repair.
  - `type` is drawn from `report|plan|summary|implementation|handoff`.
  - Each `path` resolves on disk; a non-resolving path is a FAIL.
  - Empty `artifacts` is legal for `in_progress`, `partial`, `failed`, and `blocked`; required
    non-empty for `researched`, `planned`, and `implemented` (mirroring `validate-handoff.sh`).
  - `metadata.session_id`, `metadata.agent_type`, `metadata.delegation_depth`, and
    `metadata.delegation_path` are present.
  *(completed)*
- [x] Implement `--fix`: opt-in only. Sources the lib, promotes bare strings, writes atomically
      (temp file plus rename), prints a per-element diff of what it changed, and refuses on
      unparseable JSON. Never invoked implicitly by any other script in this plan. *(completed)*
- [x] Add `validate-return-meta.sh` to the utility-script inventory in the core merge-source that
      generates CLAUDE.md's `### Utility Scripts` list, describing it as the `.return-meta.json`
      sibling of `validate-handoff.sh`. *(completed)*
- [x] Add `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` following the
      conventions of the neighbouring tests, covering at minimum: a well-formed file (exit 0), a
      bare-string array (exit 1), a missing file (exit 3), an object missing `summary` (exit 1), a
      non-resolving path (exit 1), and a `--fix` round-trip that turns a failing file into a
      passing one. *(completed: 14 cases total)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `validate-handoff.sh` (342 lines) is a faithful
structural model and that no existing `validate-return-meta.sh` is present anywhere in the source
store. Confirm at implementation time by re-running
`ls agent-system/extensions/core/scripts/validate-*.sh` before creating the file; if a
`validate-return-meta.sh` already exists, extend it rather than overwriting.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/return-meta-artifacts-lib.sh` - new shared anchor
- `agent-system/extensions/core/scripts/validate-return-meta.sh` - new validator
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` - new test
- core merge-source generating CLAUDE.md's `### Utility Scripts` list - inventory entry

**Verification**:
- `bash -n` clean on all three new scripts.
- `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` passes.
- The validator run against this task's own `.return-meta.json` exits 0.
- `--help` output documents the rules and exit codes, matching the `validate-handoff.sh` shape.

---

### Phase 3: Backfill Templates -- Core Extension and Shape-Unconfirmed Agents [COMPLETED]

**Goal**: Give every core-extension agent and every "has the key but only ever shows `[]`" agent
a correct inline object template.

**Tasks**:
- [x] Re-enumerate the target set before editing (see Scope Hypothesis). Expected targets:
  - No `artifacts` key at all: `core/agents/code-reviewer-agent.md`,
    `core/agents/general-research-hard-agent.md`, `core/agents/planner-agent.md`,
    `core/agents/planner-hard-agent.md`, `core/agents/spawn-agent.md`,
    `core/agents/synthesis-agent.md`.
  - Key present but only ever as an empty array, never showing the object shape:
    `cslib/agents/cslib-vet-agent.md`, `filetypes/agents/filetypes-router-agent.md`,
    `lean/agents/lean-implementation-agent.md`, `lean/agents/lean-research-agent.md`.
  *(completed: the live re-enumeration matched this hypothesis exactly -- 19 no-key files
  system-wide, split 6 core + 13 remaining-extension, plus 4 shape-unconfirmed, totaling the 10
  files this phase asserts. DEVIATION found during editing, not during enumeration: reading
  `code-reviewer-agent.md` and `synthesis-agent.md` in full showed neither agent writes
  `.return-meta.json` at all -- `code-reviewer-agent.md`'s `## Return Format` section returns a
  console-only bullet summary with no file-based metadata exchange, and `synthesis-agent.md`'s
  `## Output Contract` explicitly states "The lead does NOT read the unified report. The lead
  uses only this compact summary for postflight metadata." Per Phase 1's classification rule
  ("every dispatchable agent that writes `.return-meta.json`"), both are OUT of scope and are
  recorded here as deliberate exclusions -- mirroring the `literature-agent` precedent named in
  Phase 4 -- rather than having a template added they would never use. Actual edit target: 8
  files, not 10.)*
- [x] For each, insert the Phase 1 fragment's template verbatim into the agent's terminal-metadata
      section, adjacent to wherever that agent already describes writing `.return-meta.json`.
      Adapt only the illustrative `type` value and `path` to the agent's own artifact kind; the
      key set and object shape must remain byte-identical to the fragment. *(completed for the 8
      confirmed in-scope files)*
- [x] For the four empty-array agents, keep the existing `"artifacts": []` early-metadata example
      intact — it is correct for `in_progress` — and add the populated object example alongside it
      so both the empty and populated shapes are visible. *(completed)*
- [x] Where an agent already carries only the prose `.artifacts[0].path` warning (notably
      `planner-agent` and `planner-hard-agent`), keep the prose and add the template. Prose alone
      is the configuration that already failed in production; it is not a substitute. *(completed;
      also applied to `general-research-hard-agent.md`, the third such agent per Phase 1's
      Research Integration note)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts 10 target files in two named groups. Confirm before editing by
re-running the two enumerations over `agent-system/extensions/*/agents/*.md`: (a) files with no
`"artifacts"` occurrence, (b) files whose only `"artifacts"` occurrences are followed by `[]`.
Reconcile any difference against this list and record additions or removals in the phase notes
rather than silently editing a different set. `core/agents/README.md` is not a dispatchable agent
and must be excluded (it has no frontmatter `name:` key).

**Files to modify**:
- `agent-system/extensions/core/agents/{code-reviewer,general-research-hard,planner,planner-hard,spawn,synthesis}-agent.md` - add inline template
- `agent-system/extensions/cslib/agents/cslib-vet-agent.md` - add populated object example
- `agent-system/extensions/filetypes/agents/filetypes-router-agent.md` - add populated object example
- `agent-system/extensions/lean/agents/lean-{implementation,research}-agent.md` - add populated object example

**Verification**:
- Every file in the confirmed target set contains an `"artifacts"` array whose first element is an
  object with `type`, `path`, and `summary` keys.
- Diff read-through confirms every changed hunk is inside a fenced example or prose region.
- No file outside the confirmed set was modified.

---

### Phase 4: Backfill Templates -- Remaining Extension Agents [NOT STARTED]

**Goal**: Complete the backfill across the extensions the research named as entirely
template-less.

**Tasks**:
- [ ] Re-enumerate before editing (see Scope Hypothesis). Expected targets:
      `python/agents/python-{implementation,research}-agent.md`,
      `typst/agents/typst-{implementation,research}-agent.md`,
      `z3/agents/z3-{implementation,research}-agent.md`,
      `latex/agents/latex-{implementation,research}-agent.md`,
      `lean/agents/lean-{implementation,research}-hard-agent.md`,
      `cslib/agents/cslib-research-hard-agent.md`,
      `email/agents/email-implementation-agent.md`,
      `literature/agents/literature-agent.md`.
- [ ] Insert the Phase 1 fragment's template verbatim into each, using the same placement rule as
      Phase 3.
- [ ] For `email-implementation-agent`, keep the existing wrapper-only posture intact: its
      `modified_files: []` behavior is documented as correct, and the artifacts template addition
      must not imply it should start writing repo files.
- [ ] For `literature-agent`, confirm it writes `.return-meta.json` at all before adding the
      template; if it does not, record that finding rather than adding a template it will never
      use, and note it as a deliberate exclusion for Phase 7's classification rule.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts 13 target files. Confirm before editing by re-running the
no-`"artifacts"`-occurrence enumeration over `agent-system/extensions/*/agents/*.md` and
subtracting the Phase 3 set. The `literature-agent` entry is additionally hypothesized to be a
`.return-meta.json` writer; that specific assumption is confirmed or refuted by reading the file's
terminal-metadata section before editing.

**Files to modify**:
- `agent-system/extensions/python/agents/*.md` - add inline template
- `agent-system/extensions/typst/agents/*.md` - add inline template
- `agent-system/extensions/z3/agents/*.md` - add inline template
- `agent-system/extensions/latex/agents/*.md` - add inline template
- `agent-system/extensions/lean/agents/lean-*-hard-agent.md` - add inline template
- `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md` - add inline template
- `agent-system/extensions/email/agents/email-implementation-agent.md` - add inline template
- `agent-system/extensions/literature/agents/literature-agent.md` - add template or record exclusion

**Verification**:
- Every file in the confirmed target set contains an object-shaped `artifacts` first element, or
  is recorded as a reasoned exclusion with evidence.
- Combined with Phase 3, no dispatchable agent remains without a template (this is the precondition
  Phase 7 re-checks).
- Diff read-through confirms prose-and-fenced-example edits only.

---

### Phase 5: Normalize at the Consumer Chokepoint with a Loud, Recorded Notice [NOT STARTED]

**Goal**: Stop losing artifact links to a malformed array, without making the defect free or
invisible.

**Tasks**:
- [ ] Modify `skill_read_metadata` in `agent-system/extensions/core/scripts/skill-base.sh` to
      source `return-meta-artifacts-lib.sh` and run `normalize_artifacts_array` on the in-memory
      JSON before resolving `ARTIFACT_PATH`/`ARTIFACT_TYPE`/`ARTIFACT_SUMMARY`. Normalization is
      **read-side only** — it must not rewrite the on-disk file.
- [ ] When any element was promoted, emit a loud stderr notice in the established banner family
      (same shape as the existing `[postflight] WARNING:` and `[hard-orchestrate] EVIDENCE:`
      lines), naming the file, the offending index, and the inferred type.
- [ ] Record the occurrence via `system-defect-record.sh --defect-class ARTIFACTS_SHAPE_MISMATCH`,
      which already accepts that class. Failure to record must be non-blocking and must not
      suppress the stderr notice.
- [ ] Apply the same treatment to `orchestrator-postflight.sh`'s direct `.artifacts[0].*` reads,
      which bypass `skill_read_metadata` even though that script already sources `skill-base.sh`.
      Prefer routing those reads through the shared function over duplicating the jq expressions.
- [ ] **Leave `orchestrate-recover-outcome.sh` reading raw.** Add an inline comment at its
      artifact-resolution block stating that it deliberately does not normalize, because its
      `ARTIFACTS_SHAPE_MISMATCH` computation depends on observing the unrepaired shape. Name the
      chokepoint that does normalize so a future reader does not "fix" the apparent inconsistency.

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - normalize in `skill_read_metadata`, emit notice, record defect
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - route artifact reads through the shared function
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` - comment only, documenting the deliberate non-normalization

**Verification**:
- `bash -n` clean on all three scripts.
- Against a bare-string fixture: `skill_read_metadata` yields a non-empty `ARTIFACT_PATH`, emits
  the notice on stderr, and the on-disk file is byte-identical afterwards.
- Against the same fixture: `orchestrate-recover-outcome.sh` still reports
  `evidence_reason=ARTIFACTS_SHAPE_MISMATCH`. This is the phase's load-bearing regression check —
  if the detector goes quiet, normalization has been placed wrongly.
- Against a well-formed fixture: no notice, no defect record, unchanged resolved values.
- Existing tests that exercise these scripts still pass, including
  `test-skill-base-lifecycle.sh` and `test-handoff-reader-parity.sh`.

---

### Phase 6: Close the Handoff-Present Detection Hole [NOT STARTED]

**Goal**: Make `ARTIFACTS_SHAPE_MISMATCH` computable on both orchestrator paths, not only after
recovery, and retire the residual-gap note that currently records the opposite.

**Tasks**:
- [ ] In `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, extend Stage 5's
      handoff-present branch (branch 3, the `else` arm) to invoke
      `orchestrate-recover-outcome.sh` as an **advisory evidence probe only**: read
      `evidence_suspect`/`evidence_reason` and ignore every other field.
- [ ] State explicitly, at the call site, that the probe never overrides the handoff-derived
      outcome, never changes `dispatch_status`, and never drives a status transition. Its sole
      effect is the loud notice plus the `system-defect-record.sh` call that branch 2 already
      performs for the same class.
- [ ] Handle the probe's exit codes correctly: exit 1 and exit 2 must both be treated as "no
      signal available" and must not be escalated, since a handoff-present dispatch legitimately
      may have no recoverable `.return-meta.json`.
- [ ] Rewrite the "Known residual gap (recorded, not fixed here)" note so it describes what is now
      true. Do not delete it — replace it with a statement that the hole is closed and by what
      mechanism, so the history stays legible.
- [ ] Determine whether `skill-orchestrate-hard/SKILL.md` has the same structural hole on its own
      handoff-present branch. If it does, apply the same probe. If it does not, record that
      finding at the corresponding site so the two engines visibly agree.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts that the hole exists in `skill-orchestrate` only, and that
`skill-orchestrate-hard` already computes the signal (it calls `orchestrate-recover-outcome.sh`
and consumes `ARTIFACTS_SHAPE_MISMATCH` at two sites). Confirm at implementation time by reading
the hard engine's handoff-present branch in full before concluding either way; the presence of
the call elsewhere in the file does not establish that this specific branch reaches it.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - add advisory probe, rewrite residual-gap note
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - same probe, or a recorded finding that it is unnecessary

**Verification**:
- The residual-gap note no longer claims the signal is uncomputed on the handoff-present path.
- The probe's documented contract at the call site states advisory-only, non-overriding, and
  exit-1/exit-2-tolerant.
- A trace read of both branches confirms no path can now reach a completion claim with a
  non-empty artifacts array and an unresolvable path without emitting the notice.
- Both engines carry a consistent statement about this branch.

---

### Phase 7: Add lint-agent-contracts.sh Check F and Verify the Deploy Gate [NOT STARTED]

**Goal**: Convert a missing or malformed agent artifacts template from a silent, recurring
production defect into a deploy-time failure.

**Tasks**:
- [ ] **Precondition gate**: re-run the template enumeration across all dispatchable agents. If any
      agent still lacks a template and is not a recorded exclusion, stop and complete the backfill
      before proceeding. Landing a failing gate is worse than landing it a phase later.
- [ ] Implement `check_f_artifacts_template()` in
      `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`, placed at the
      documented insertion point. It must:
  - Reuse `enumerate_dispatchable_agents` and `is_dispatchable_agent` rather than re-deriving the
    frontmatter-gated detector, exactly as the insertion-point comment instructs.
  - Read the expected template shape from
    `core/context/contracts/return-meta-artifacts-template.md` at runtime, never hardcoded — the
    same mechanism Check C uses for the no-task-references bullet.
  - FAIL any in-scope agent whose file contains no `"artifacts"` array with an object first
    element carrying `type`, `path`, and `summary`.
  - Honour the fragment's classification rule, including any exclusion recorded in Phase 4.
- [ ] Name it **Check F**. Leave the reserved Check D and Check E comments intact and untouched —
      those name different deferred work.
- [ ] Register the call in `main()` alongside `check_a_*`, `check_b_*`, and `check_c_*`, and extend
      the script's header comment block to document Check F in the same style as A through C.
- [ ] Extend `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` with
      Check F cases: a conforming agent passes, a template-less agent fails, and an agent with a
      bare-string array fails.
- [ ] Update the `### Utility Scripts` description of `lint-agent-contracts.sh` in the core
      merge-source to mention the artifacts-template check.

**Timing**: 2 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: Asserts that no new `verify-deploy.sh` gate is required because
`lint-agent-contracts.sh` already runs as gate 6. Confirm by reading gate 6's invocation in
`verify-deploy.sh` before deciding; only add a gate if that assumption fails.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - add Check F, register in main, document in header
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - Check F test cases
- core merge-source `### Utility Scripts` entry for `lint-agent-contracts.sh` - describe Check F

**Verification**:
- `bash -n` clean.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0 with
  Check F reporting a pass for every dispatchable agent.
- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` passes.
- Deliberately reverting one agent's template locally makes Check F FAIL with a message naming
  that file; restore it afterwards.
- The complete repository gate set runs clean: `verify-deploy.sh` in full, not gate 6 alone.

---

## Testing & Validation

- [ ] `bash -n` clean on every new or modified `.sh` file.
- [ ] `test-validate-return-meta.sh` passes (new).
- [ ] `test-lint-agent-contracts.sh` passes, including the new Check F cases.
- [ ] `test-skill-base-lifecycle.sh` and `test-handoff-reader-parity.sh` still pass after the
      Phase 5 chokepoint change.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes.
- [ ] `validate-return-meta.sh` exits 0 against this task's own `.return-meta.json`.
- [ ] Bare-string fixture regression: `skill_read_metadata` recovers the path AND
      `orchestrate-recover-outcome.sh` still reports `ARTIFACTS_SHAPE_MISMATCH`.
- [ ] `check-extension-docs.sh` exits 0 (new context/contracts file must be documented and
      cross-referenced).
- [ ] `verify-deploy.sh` passes in full.
- [ ] `check-task-references.sh` clean — no task numbers introduced outside `specs/**`.
- [ ] Confirm nothing under `.claude/**` was hand-edited: every change lands in
      `agent-system/extensions/**`.

## Artifacts & Outputs

- `specs/052_return_meta_artifacts_shape_contract/plans/01_return-meta-artifacts-contract.md` (this file)
- `specs/052_return_meta_artifacts_shape_contract/summaries/01_return-meta-artifacts-contract-summary.md`
- `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md` (new)
- `agent-system/extensions/core/scripts/validate-return-meta.sh` (new)
- `agent-system/extensions/core/scripts/lib/return-meta-artifacts-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` (new)
- Modified: `return-metadata-file.md`, `skill-base.sh`, `orchestrator-postflight.sh`,
  `orchestrate-recover-outcome.sh` (comment only), `skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md`, `lint-agent-contracts.sh`,
  `test-lint-agent-contracts.sh`, core merge-source utility-script inventory, and ~23 agent files

## Rollback/Contingency

Every phase is independently revertible and the work is additive up to Phase 7.

- **Phases 1-4** add prose, a fenced template, and two new scripts. Reverting the commits restores
  the prior state with no behavioral residue; no existing code path reads the new files until
  Phase 5 and Phase 7 wire them in.
- **Phase 5** is the only phase that changes live consumer behavior. If normalization causes
  trouble, revert `skill-base.sh` and `orchestrator-postflight.sh` alone: the validator, the
  fragment, and the agent templates all remain useful without it, and the system returns to its
  current silent-loss behavior rather than to a broken state.
- **Phase 6** is advisory-only by construction; reverting removes a notice and nothing else.
- **Phase 7** is the only phase that can block a deploy. If Check F proves too strict or produces
  false positives, downgrade it from `log_fail` to `log_warn` — the lint already supports
  warnings-with-exit-0 — rather than removing the check. That preserves the visibility while
  unblocking the gate, and the strictness can be restored once the false positives are understood.

Use `bash .claude/scripts/git-snapshot.sh 52` before any intentional rollback that would discard
uncommitted work.
