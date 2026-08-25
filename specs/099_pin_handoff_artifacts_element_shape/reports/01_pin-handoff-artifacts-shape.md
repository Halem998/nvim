# Research Report: pin_handoff_artifacts_element_shape

**Task**: 099 - Make the `.orchestrator-handoff.json` `artifacts[]` element shape unambiguous
**Started**: 2026-08-24
**Completed**: 2026-08-24
**Effort**: small-medium (doc + ~5 agent-contract edits; two optional follow-ups outside declared
scope)
**Dependencies**: None
**Sources/Inputs**: codebase read of the 5 declared-scope files, plus `orchestrator-handoff-schema.json`,
`validate-handoff.sh`, `validate-return-meta.sh`, `skill-base.sh`, `wrap-up.md`,
`general-implementation-agent.md`, `general-implementation-hard-agent.md`,
`general-research-hard-agent.md`, `planner-agent.md`/`planner-hard-agent.md`,
`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **`.return-meta.json`'s `artifacts` shape is already correctly and strictly pinned** — in
  `return-metadata-file.md`, in `general-research-agent.md`, `lean-research-agent.md`, and
  `lean-research-hard-agent.md` (all three already carry the exact "never a bare-string array"
  prohibition and the canonical object template). This is NOT where the ambiguity lives; no
  change needed there for this task.
- **The real gap is `.orchestrator-handoff.json`'s `artifacts` shape**, which is asserted by
  example everywhere (`orchestrator-handoff-schema.json`, `wrap-up.md`, `handoff-schema.md`) but
  **never explicitly prohibits the bare-string alternative in prose**, unlike `.return-meta.json`'s
  parallel section. The JSON Schema structurally forbids it (`items.type: "object"`), but no
  validator actually enforces element-level shape (see below), so the structural prohibition is
  currently decorative.
- **`lean-research-agent.md` and `lean-research-hard-agent.md` have zero mention of
  `.orchestrator-handoff.json` at all** — no "Defensive case" note, unlike `general-research-agent.md`,
  `general-research-hard-agent.md`, and `general-implementation-agent.md`, which all already carry
  a "Defensive case, if written anyway" paragraph pointing at `dispatch_seq` echoing (but, in every
  existing instance, *not* at the artifacts shape). This is the literal, reproducing hole: when an
  orchestrating dispatcher hands a research agent a `handoff_path` + `dispatch_seq` and expects a
  write (contrary to the documented "hard-mode-implement-only" contract, but demonstrably
  happening — see below), the lean agents have no contract text at all to draw on.
- **`validate-handoff.sh` does not check element shape.** Its Check 2c reads
  `.artifacts[0].type`/`.artifacts[0].path` directly; against a bare-string element this either
  jq-errors or silently yields `"__MISSING__"`-adjacent behavior rather than naming the shape
  defect, and the script is wired **log-only, non-gating** regardless.
- **The two live consumer call sites that link a handoff's `artifacts[0]` into `state.json`
  (`skill-orchestrate/SKILL.md:1009-1011` and `skill-orchestrate-hard/SKILL.md:1386-1388`) have NO
  tolerant dual-shape handling and no `ARTIFACTS_SHAPE_MISMATCH` detection today** — that defect
  class's existing wiring only probes a *separate* file (`.return-meta.json`, via
  `orchestrate-recover-outcome.sh`) as an advisory signal on the handoff-present path; it never
  inspects the handoff's own `artifacts[0]`. The "orchestrator recovered by resolving BOTH shapes
  tolerantly at the call site" behavior described in the incident is not present in this source
  repo today — either it was an ad hoc, unlanded fix in the consumer repo, or it is aspirational.
  Recommend treating "add it here, once" as an open decision for planning (see Decisions below),
  not as already-done.
- **This exact task's own delegation context reproduces the anomaly live**: task 099 was
  dispatched to a base-mode research agent (`general-research-agent`, not hard, not implement)
  with `handoff_path` and `dispatch_seq: 3` supplied, and an explicit instruction to write
  `.orchestrator-handoff.json`. `handoff-schema.md`'s own "Handoff Writers" section states research
  agents "never write a handoff at all, in any mode." This live contradiction is direct evidence
  that the categorical "never" is not honored by whatever produced this dispatch, and is exactly
  the scenario the existing "Defensive case" paragraphs anticipate but don't fully cover.

## Context & Scope

Verifying the reproducing mechanism: three of seven `lean-research-agent.md` dispatches in a
lean4 batch (a separate consumer repo) wrote `.orchestrator-handoff.json` with `artifacts` as an
array of bare path strings, recorded as `ARTIFACTS_SHAPE_MISMATCH`. The remaining four wrote the
correct object form. Reading `lean-research-agent.md` and `lean-research-hard-agent.md` in full
(current source-store copies) confirms neither file mentions `.orchestrator-handoff.json` in any
form — they document only `.return-meta.json`, and that file's shape guidance is already correct
and strict. This means the 3/7 defect cannot be explained by anything written in the agent
contract as it stands; it happened despite (or rather, in the total absence of) any contract
guidance for the file that was actually written. The fix is therefore additive (give the agents
guidance they currently lack), not corrective (there is no wrong existing statement to overwrite
in these two files).

## Findings

### Codebase Patterns

**Already-correct pattern for `.return-meta.json`** (verified in all three checked research
agents plus `planner-agent.md`/`planner-hard-agent.md`):
- Explicit sentence: "`artifacts` is a **required array of objects** ... never an array of bare
  path strings"
- A copyable JSON template, sourced from the single canonical fragment
  `context/contracts/return-meta-artifacts-template.md`
- `return-metadata-file.md`'s `### artifacts (required)` section states the same prohibition with
  a four-layer enforcement table (normative doc / `validate-return-meta.sh` strict-fail /
  `skill_read_metadata` tolerant-normalize-plus-defect-record / agent-contract lint via
  `lint-agent-contracts.sh` Check F)

**Missing/weaker pattern for `.orchestrator-handoff.json`**:
- `orchestrator-handoff-schema.json` (the declared machine-checkable single source of truth)
  structurally requires `artifacts[].type` and `.path` (`required: ["type","path"]`) via
  `items.type: "object"`, so a JSON-Schema-validating consumer would already reject a bare string
  — but no validator in this repo actually runs full JSON-Schema validation against this file;
  `validate-handoff.sh` is hand-rolled jq/bash and only checks presence of `.artifacts[0].type`
  and `.artifacts[0].path`, not that `.artifacts[0]` itself is an object.
- `handoff-schema.md`'s `### artifacts (required)` prose section (lines ~202-210) states "Each
  entry requires `type` and `path`" but does not say a bare-string element is invalid — the
  prohibition is implicit-by-required-fields, not explicit-by-negative-statement.
- `wrap-up.md`'s H9 prose contract (the primary contract for the one active, correct writer,
  `general-implementation-hard-agent.md`) shows only the object form by worked example; it too has
  no explicit "never a bare string" sentence.
- `general-implementation-hard-agent.md` (the sole documented active writer) itself has no
  explicit "never bare string" sentence for the handoff's own `artifacts` — its one "never a bare
  path strings" sentence (line ~489) is about `.return-meta.json`, not the handoff.
- Three agent contracts (`general-research-agent.md`, `general-research-hard-agent.md`,
  `general-implementation-agent.md`) already carry a "Defensive case, if [a handoff is] written
  anyway" paragraph — the exact right place for this guidance — but all three currently pin only
  `dispatch_seq` echoing (and, for the implementation agent, `phases_completed`/`phases_total`
  top-level nesting), never the `artifacts` element shape.
- `lean-research-agent.md` and `lean-research-hard-agent.md` have **no such paragraph at all** —
  the acute gap that produced the observed defect.

### Consumer-Side Enforcement Gap (adjacent, not in declared file scope)

- `ARTIFACTS_SHAPE_MISMATCH` is already a defined, generic defect class
  (`system-defect-record.sh`'s enum) with existing detection arms — but every wired arm
  (`skill-base.sh`'s `skill_read_metadata`, `orchestrate-recover-outcome.sh`, and both
  orchestrate engines' Stage 5 "handoff-present probe") inspects **`.return-meta.json`**, never
  `.orchestrator-handoff.json`'s own `artifacts[0]`.
- The two direct handoff-artifact reads (`skill-orchestrate/SKILL.md:1009-1011`,
  `skill-orchestrate-hard/SKILL.md:1386-1388`) are raw `jq -r '.artifacts[0].path // ""'` with no
  error handling — against a bare-string element this either raises a jq runtime error (silently
  yielding empty output into the variable) or, if it doesn't error, still yields `""` for `.path`
  on non-object input. Either way the artifact silently fails to link, exactly as described.
- `validate-handoff.sh` is invoked as **log-only, non-gating** diagnostic per
  `skill_corroborate_phase_counts()`, so even a correct detection there would not block a
  malformed handoff today.

### Recommendations

1. **Decision (1) — element shape**: `.orchestrator-handoff.json`'s `artifacts[]` element is an
   **object** `{type, path[, summary]}` with `type` and `path` REQUIRED and `summary` OPTIONAL
   (matches the existing, singular `orchestrator-handoff-schema.json`; do not tighten `summary` to
   required — every reader already treats its absence as a graceful degradation, not an error). A
   bare string is **never** an accepted shorthand, stated explicitly rather than left implicit.
   This mirrors the decision already made for `.return-meta.json` and keeps the two schemas'
   toleration policy symmetric (they differ in which fields are required, which is fine and
   already documented — see `return-metadata-file.md`'s existing "nesting collision" cross-file
   caution for the established pattern of calling out a cross-file divergence explicitly rather
   than leaving it implicit).

2. **Decision (2) — one normative place**: no new document is needed.
   `context/schemas/orchestrator-handoff-schema.json` is already the correct single
   machine-checkable source (per `handoff-schema.md`'s own framing: "the single source of truth
   this document, `wrap-up.md`, and `validate-handoff.sh` all point at rather than restating
   independently"). The fix is:
   - Add one explicit negative-statement sentence to `handoff-schema.md`'s `### artifacts
     (required)` section: a bare-string element is never valid, in any context — closing the
     implicit-by-required-fields gap, mirroring `return-metadata-file.md`'s parallel sentence.
   - In `return-metadata-file.md`, add a short cross-reference sentence (in the spirit of its
     existing "Three distinct vocabularies" / "nesting collision" callouts) pointing at
     `handoff-schema.md`'s `### artifacts (required)` section and stating explicitly that the two
     files' `artifacts` object shapes are *parallel but not identical* (`.return-meta.json`
     requires `summary`; `.orchestrator-handoff.json` does not) — pre-empting exactly the kind of
     cross-file pattern-matching mistake this file already warns against for `phases_completed`/
     `phases_total`.
   - In `handoff-schema.md`'s "Handoff Writers" section, add one sentence cross-referencing the
     "Defensive case" paragraphs (see below) so the categorical "research agents never write a
     handoff, in any mode" claim and the defensive-case fallback guidance are visibly connected
     rather than living in unrelated files that could drift apart.
   - Reference, don't restate: every agent-contract fix below should point at
     `handoff-schema.md`'s `### artifacts (required)` section by reference, not copy the field
     list inline — consistent with how `return-meta-artifacts-template.md` already centralizes the
     `.return-meta.json` template as a single generated-copy source. (A parallel dedicated template
     fragment is not needed here — the handoff's artifacts template is only ~3 lines and already
     appears correctly, by example, in `wrap-up.md`; a reference to `handoff-schema.md` is
     sufficient and avoids adding a second near-duplicate fragment file.)

3. **Agent-contract fixes (declared file scope)**:
   - `lean-research-agent.md`: add a "Defensive case" section modeled on
     `general-implementation-agent.md`'s existing `### .orchestrator-handoff.json (base-mode
     implement is a non-writer by design)` pattern — state plainly that this agent does not write
     `.orchestrator-handoff.json` by contract (research agents never do, per
     `handoff-schema.md`), then cover the defensive case: if a delegation context nonetheless
     supplies `handoff_path` and an instruction to write one, echo `dispatch_seq` unchanged AND use
     only the object-shaped `artifacts` entries defined in `handoff-schema.md`'s `### artifacts
     (required)` section — never a bare path string.
   - `lean-research-hard-agent.md`: identical addition, placed near Stage 7 (Write Metadata File).
   - `general-research-agent.md`: extend the existing Stage 3.6 "Defensive case" paragraph
     (lines ~193-199) with one added sentence pinning the artifacts object shape by reference to
     `handoff-schema.md`'s `### artifacts (required)` section, alongside the existing
     `dispatch_seq` echoing instruction.
   - `handoff-schema.md`: the two prose additions described in Decision (2) above.
   - `return-metadata-file.md`: the one cross-reference sentence described in Decision (2) above.

4. **Recommended follow-up, outside this task's declared 5-file scope** (flag for planning to
   decide whether to fold in now or spin out separately — the acceptance criterion "every
   research/plan/implement agent contract that mentions artifacts conforms to it or references
   it" is broader than the 5 declared files):
   - `general-research-hard-agent.md` and `general-implementation-agent.md` already carry the same
     "Defensive case" pattern and have the identical artifacts-shape gap; they should get the same
     one-sentence fix for consistency, or a future reader will find the newly-fixed
     `general-research-agent.md` and the still-gapped sibling files diverging again.
   - `wrap-up.md`'s H9 field-semantics bullet for `artifacts` (the prose contract for the one
     *active* writer) should also get the explicit "never a bare string" sentence — it is
     currently implicit-by-example just like `handoff-schema.md` was.
   - `validate-handoff.sh` Check 2c should be hardened to explicitly test `(.artifacts[0] | type)
     == "object"` before touching `.type`/`.path`, and FAIL with a message naming the index and
     the observed type (mirroring `validate-return-meta.sh`'s existing `bare_count` check) rather
     than either jq-erroring or silently degrading.
   - The two live consumer call sites should get the same loud-normalize-and-record pattern
     `skill-base.sh`'s `skill_read_metadata` already implements for `.return-meta.json` (normalize
     a bare string in-memory to `{path: <string>, type: "", summary: ""}`, emit a stderr WARNING,
     and call `system-defect-record.sh --defect-class ARTIFACTS_SHAPE_MISMATCH`), ideally as one
     shared helper both `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` call,
     rather than two independently-maintained inline jq blocks. This resolves the acceptance
     criterion "the orchestrator's dual-shape tolerance is either removed... or deliberately
     retained with a recorded reason" — my recommendation is **retain, but implement it properly
     once** (today there is no working tolerance at all for this file, despite the incident
     description implying one exists somewhere).
   - Separately (out of scope for this task, noted for completeness): `handoff-schema.md`'s
     categorical claim that research agents never write `.orchestrator-handoff.json` "in any mode"
     is contradicted by this very task's own delegation context. Whatever produces delegation
     contexts for `/orchestrate`-style research dispatches and sometimes instructs a write should
     be reconciled with the documented one-channel-per-mode contract — either stop instructing
     research agents to write the file (restoring the documented invariant), or update
     `handoff-schema.md`'s "Handoff Writers" table to reflect an expanded, decided writer set. This
     is a decision for a human/maintainer, not something to silently resolve by picking one side.

## Decisions

- The bare-string element is rejected, not accepted as shorthand, for `.orchestrator-handoff.json`
  — consistent with `.return-meta.json`'s existing policy.
- `orchestrator-handoff-schema.json` remains the sole machine-checkable authority; no new schema
  or template fragment file is introduced. Agent contracts reference `handoff-schema.md`'s
  `### artifacts (required)` section rather than restating the shape.
- `lean-research-agent.md` and `lean-research-hard-agent.md` get a new "Defensive case" section
  (previously absent); `general-research-agent.md` gets one added sentence to its existing
  section; `handoff-schema.md` and `return-metadata-file.md` get small, targeted prose additions.
  No file's existing correct guidance for `.return-meta.json` is touched.

## Risks & Mitigations

- **Risk**: fixing only the 5 declared-scope files leaves `general-research-hard-agent.md` and
  `general-implementation-agent.md` (which share the identical gap) unfixed, so the pattern could
  reappear via those agents. **Mitigation**: flagged explicitly above as a recommended follow-up;
  planning should decide whether to fold them in now (small, mechanical, one sentence each) or
  track as a separate task.
- **Risk**: writer-side contract fixes alone do not satisfy the acceptance criterion "a dispatch
  that emits the non-conforming shape is ... caught with a clear message" — no consumer-side
  detection for this specific file exists today. **Mitigation**: flagged as a recommended
  follow-up (`validate-handoff.sh` hardening + consumer call-site normalization); this task's
  declared file scope does not include those files, so implementation should either request scope
  expansion or explicitly record the acceptance gap as deferred.
- **Risk**: reconciling the "hard-mode-implement-only" writer claim with observed practice (this
  task's own dispatch, and the lean incident) is out of scope but load-bearing — if left
  unaddressed, agent contracts will keep needing defensive-case patches for a scenario the primary
  contract claims cannot happen. **Mitigation**: recorded as a maintainer-level follow-up, not
  silently decided either way.

## Context Extension Recommendations

None — this is a meta task and the relevant context files are being directly extended by this
task's own recommendations.

## Appendix

Files read in full or substantially: `docs/architecture/handoff-schema.md`,
`context/formats/return-metadata-file.md`, `context/schemas/orchestrator-handoff-schema.json`,
`agents/lean-research-agent.md`, `agents/lean-research-hard-agent.md`,
`agents/general-research-agent.md`, `agents/general-research-hard-agent.md` (grep),
`agents/general-implementation-agent.md` (excerpt), `agents/general-implementation-hard-agent.md`
(grep + excerpt), `context/contracts/wrap-up.md` (excerpt),
`context/contracts/return-meta-artifacts-template.md`, `scripts/validate-handoff.sh`,
`scripts/skill-base.sh` (`skill_link_artifacts`, `skill_read_metadata` region),
`skills/skill-orchestrate/SKILL.md` and `skills/skill-orchestrate-hard/SKILL.md` (grep for
`artifacts[0]` / `handoff_artifact_*`), `agents/planner-agent.md` / `agents/planner-hard-agent.md`
(grep).
