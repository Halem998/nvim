# Implementation Plan: System-Defect Discrimination Predicate

- **Task**: 951 - Define the system-defect discrimination predicate and detection-point registry
- **Status**: [IMPLEMENTING]
- **Effort**: 2.0 hours
- **Dependencies**: None
- **Research Inputs**: None (no research report was produced; the research phase wrote the
  deliverables directly into the source store — see "Unusual starting state" below)
- **Artifacts**: plans/01_system-defect-discrimination.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Both files in the declared `file_scope` already exist, are committed, and satisfy the large
majority of the task description's acceptance criteria. This plan is therefore a
verification-and-gap-closure plan, not a build plan: it records the verification already performed
against every declared criterion, and closes the three genuine gaps that verification surfaced.
One of those gaps is substantive (Signal A's instance list provably excludes a live-observed
violation class), two are precision/completeness gaps in the same document. No new files are
created, the JSON needs no change, and the scope boundary the task itself declares (contract and
registry only — no recorder, no wiring, no command change) is preserved unchanged.

### Unusual starting state

The research phase produced no report under `specs/951_*/reports/`. Instead it wrote both
`file_scope` deliverables directly into the source store and reported `status: "researched"`. Both
files are committed and clean. Consequences for this plan:

- There is no research report to integrate; the deliverables themselves are the research output.
- The plan's job is to audit the delivered artifacts against the task description's own
  acceptance criteria — which this planning pass did — and to plan only what is genuinely missing.
- The three memory candidates recorded in the task's prior `.return-meta.json` are preserved
  observations from that phase and need no re-derivation.

### Verification performed during planning (all mechanical, all re-runnable)

Every line citation in the delivered document was checked against current file text, and every
cross-referenced file was checked for existence. Results:

| Claim in the delivered doc | Verdict |
|---|---|
| `orchestrate-recover-outcome.sh:205` sets `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` | ACCURATE |
| Five `evidence_reason` consumer sites at `skill-orchestrate/SKILL.md:682,826,1870,2316` and `skill-orchestrate-hard/SKILL.md:888` | ACCURATE — all five gate on `PHASES_ZERO_ON_SUCCESS` only; the dead-signal finding holds |
| Class (a) sites at `skill-orchestrate/SKILL.md:977`, `skill-orchestrate-hard/SKILL.md:1186`, `skill-orchestrate/SKILL.md:2028-2038`, `:590-591`, `:606-612`, `scripts/skill-base.sh:729` | ACCURATE (all six) |
| `return-metadata-file.md` lines 88-94 carry the seven-value status vocabulary | ACCURATE |
| All five Class (c) hooks exist in `hooks/` | ACCURATE (5/5) |
| Every file named in "Related documentation" exists | ACCURATE (8/8, incl. `file-footprint-overlap.md`, `scripts/lib/file-scope-overlap.sh`, `docs/architecture/batch-admit-schema.md`) |
| The three new `critical_paths` entries are present and the JSON parses | ACCURATE (13 entries, valid) |
| `index-entries.json` registers both files with correct `line_count` | ACCURATE (285 / 62, matching `wc -l`) |
| No task-number citations outside `specs/**` | ACCURATE — `check-task-references.sh` exits 0, 0 occurrences across all four deliverable trees |
| Deliverables 1, 1a (named section + Lean example), 2 (three classes), 3 (extend-not-sibling + degraded behaviour), 4 (identity key + read-from location) present | ACCURATE — all present |
| Scope boundary honored (no recorder, no wiring, no command change) | ACCURATE |

The JSON deliverable requires **no further work**. All remaining work is in the markdown
document.

### Gaps found

**Gap A (substantive — Signal A is incomplete against a live-observed violation).** Signal A
defines `ARTIFACTS_SHAPE_MISMATCH` as *"an artifacts array that is non-empty but yields no
`.path`"*. A `null` or absent `artifacts` field on a success status is a distinct violation of a
schema the agent system owns — `handoff-schema.md` marks `artifacts` **required**, and
`return-metadata-file.md:117` likewise (`### artifacts (required)`) — and the wording above
excludes it. Verified empirically against the live detector: with `artifacts: null`,
`(.artifacts // []) | length` evaluates to `0` and `.artifacts[0].path // ""` returns `""` with
exit 0, so **neither arm of the detector fires** and the outcome is emitted as
`evidence_suspect=false, evidence_reason="NONE"`. (By contrast the bare-string-array case fires
via the `jq_artifact_failure` arm at exit 5, not the length arm the doc's quoted header comment
describes.) This is not hypothetical: a planner handoff in this very orchestration run emitted
`artifacts: null` with `status: "planned"` and the artifact row had to be reconstructed by hand.
The document owns the Signal A list, so recording this case is this task's decision to make —
leaving it out means the predicate, as written, classifies a real system defect as task work.

**Gap B (registry completeness — an undetected path presented as covered).** Class (b) states the
five consumer sites "already read `evidence_reason`", which is true, but every one of them sits on
the **recovered** (`.return-meta.json`) path. The handoff-present branch performs no artifacts
shape check at all — verified by inspection of `skill-orchestrate/SKILL.md:800-840`, which reads
`blockers`, `continuation`, `next_action_hint`, and the phase counts, and never validates
`artifacts`. So the live `artifacts: null` handoff defect had **zero** detection, not a discarded
one. The registry enumerates class (a)/(b)/(c) — detected-and-unactioned, detected-and-discarded,
detected-and-ephemeral — and currently has no way to say "not detected anywhere". Stating this
hole explicitly is what keeps a downstream implementer from adding a consumer arm and believing
the surface is covered.

**Gap C (citation precision).** Line 41 cites the in-file comment as `lines 92-95`; the quoted
sentence spans lines 92-93, while 94-95 are a separate sentence about jq-failure handling. Minor,
but the document's own stated discipline is that citations must be re-verified rather than
trusted, so an off-by-two range in its sharpest piece of evidence is worth correcting.

**Gap D (recursion-guard registry consideration left silent).** Two orchestrator-load-bearing
scripts are absent from `critical_paths`: `scripts/reconcile-task-status.sh` (runs at every
`/orchestrate` entry) and `scripts/check-extension-docs.sh` (feeds `verify-deploy.sh`, which is
already an entry). The document has a "Considered and excluded" paragraph that reasons explicitly
about `return-metadata-file.md` and the five hooks, but says nothing about these two. Because the
document takes on responsibility for the shared list's contents — and explicitly accepts the
self-modification-hazard side effect of extending it — silence here is a real omission. The
honest resolution is documentation-only and stays inside `file_scope`: the recursion guard's own
stated scope is "files that implement the discrimination/recording pipeline itself", and neither
script is part of that pipeline, so the guard supplies no reason to add them; whether they belong
for the *other* consumer (the self-modification hazard check) is a separate question this task's
scope boundary excludes. Name them, give that reasoning, and flag the follow-on. **Do not edit the
JSON.**

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; `ROADMAP.md` was not consulted and is
not modified.

## Goals & Non-Goals

**Goals**:
- Close Gap A: make Signal A's instance list cover the missing-artifacts-on-success violation
  class, with the empirical detector evidence recorded.
- Close Gap B: state the handoff-present branch's absence of any artifacts shape check as an
  explicit, named detection hole in the registry.
- Close Gap C: correct the `lines 92-95` citation range.
- Close Gap D: record the two absent orchestrator scripts under "Considered and excluded" with the
  guard-scope reasoning and an explicit follow-on flag.
- Leave the verification record above in the task's artifacts so the accuracy of every citation is
  auditable without re-deriving it.

**Non-Goals**:
- Writing `scripts/system-defect-record.sh` or any recorder — the document's own forward reference
  binds that to downstream work, and the task's scope boundary excludes it.
- Wiring any detection site, adding any consumer arm to the five `evidence_reason` sites, or
  changing any command.
- Adding `reconcile-task-status.sh` or `check-extension-docs.sh` to `critical_paths` (deliberately
  excluded — see Gap D).
- Any edit to `orchestrator-critical-paths.json`, which verification found complete and correct.
- Any write under `.claude/**` (gitignored, disposable deploy artifact).
- Extending Signal A beyond the one live-evidenced case in Gap A. The list is declared closed and
  extensible-by-decision; this plan makes exactly one evidenced extension, not a speculative sweep.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Adding a Signal A instance with no detector reads as licensing a new detector, breaching the scope boundary | M | M | Phase 2 must state in the document that the new instance has no current detector and that building one is downstream work — the instance defines *what counts*, not *what fires* |
| An implementer widens Signal A past the one evidenced case, re-inflating the noise surface the predicate exists to suppress | H | L | Non-Goals names this explicitly; Phase 2's verification requires the instance count to be exactly five |
| Editing `.claude/**` instead of the source store, silently wiping the work on next redeploy | H | L | Binding rule stated in every phase; Phase 4 greps the diff for `.claude/` paths |
| The three phases all edit one file; parallel execution would conflict | M | L | All phases are strictly sequential (one wave each); no parallelism is declared |
| A task-number citation leaks into the document (it is outside `specs/**`) | M | L | `check-task-references.sh` is a gate in every phase that edits the document |
| Gap A's correction contradicts the "schema-conformant failure is always task work" invariant | H | L | It does not — a missing required field is a schema *violation*, not a conformant failure; Phase 2 verification re-reads that section to confirm no tension was introduced |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

All four phases edit or gate on the same single file, so no two phases may run in parallel.

---

### Phase 1: Re-verify citations and correct the citation range [COMPLETED]

**Goal**: Independently reproduce the verification table above (do not trust it), then correct the
`lines 92-95` range at line 41 of the document.

**Tasks**:
- [x] Re-run each mechanical check in the "Verification performed during planning" table against
      current file text. Any row that now disagrees is a citation that drifted since planning and
      must be corrected in the document in this phase. *(completed: all rows re-confirmed accurate,
      no drift since planning)*
- [x] Inspect `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` lines 90-96 and
      determine the exact line range spanned by the sentence the document quotes ("A non-empty
      array yielding no path is proof of a shape mismatch..."). *(completed: sentence spans lines
      92-93; lines 94-95 are the separate jq-failure sentence)*
- [x] Edit `system-defect-discrimination.md` line 41's parenthetical to that exact range.
      *(completed: "lines 92-95" -> "lines 92-93")*
- [x] Do not change the quoted text itself — it was verified accurate. *(completed: quote
      unchanged)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the
  citation range at line 41 only

**Verification**:
- `sed -n '39,48p'` on the document shows the corrected range and the unchanged quote.
- The cited range, extracted with `sed -n` from `orchestrate-recover-outcome.sh`, contains the
  quoted sentence and no unrelated sentence.
- `bash .claude/scripts/check-task-references.sh` exits 0.

---

### Phase 2: Complete Signal A for the missing-artifacts violation class [NOT STARTED]

**Goal**: Add the one evidenced Signal A instance covering a `null`/absent `artifacts` field on a
success status, with the empirical evidence that no current detector fires on it.

**Tasks**:
- [ ] Reproduce the detector evidence before writing anything:
      `echo '{"status":"planned","artifacts":null}' | jq -r '(.artifacts // []) | length'` and
      `... | jq -r '.artifacts[0].path // ""'; echo $?` — confirm `0` and empty-with-exit-0, so
      neither arm of the `evidence_reason` computation fires. Contrast with the bare-string-array
      form, which exits 5 and therefore does fire via `jq_artifact_failure`.
- [ ] Confirm `artifacts` is a required field in both schemas:
      `return-metadata-file.md:117` (`### artifacts (required)`) and `handoff-schema.md`'s
      `### artifacts (required)` section.
- [ ] Add a fifth row to the Signal A instance table naming the class (a name of the
      `ARTIFACTS_MISSING_ON_SUCCESS` shape, consistent with the existing four SCREAMING_SNAKE
      names), defining it as a `null`, absent, or empty `artifacts` field accompanying a success
      status where both owning schemas mark the field required.
- [ ] In the "Where it is already computed" column for that row, state plainly that it is **not**
      currently computed anywhere, and cross-reference the new Gap B text (Phase 3) rather than
      naming a site that does not check it.
- [ ] Add a short paragraph beneath the table recording the empirical finding: the existing
      detector's two arms are `artifacts_length > 0 && empty path` and `jq_artifact_failure`, and a
      `null` field satisfies neither. Cite `scripts/orchestrate-recover-outcome.sh` by the line
      range verified in this phase, not by the range asserted here.
- [ ] State explicitly that this instance defines what counts as a violation and that building a
      detector for it is downstream work, so the scope boundary is not widened.
- [ ] Re-read the "A schema-conformant failure is always task work" section and confirm no tension:
      a missing required field is a schema violation, not a conformant failure. If any sentence
      there now reads ambiguously, adjust that sentence — do not weaken the invariant.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts the Signal A table currently holds exactly four instances
and will hold exactly five after the edit, and that `handoff-schema.md` marks `artifacts` required.
Confirm all three by reading the files before editing — the instance count by counting table rows,
the required-field claim by locating the heading in each schema file. If `handoff-schema.md` does
not in fact mark it required, narrow the new row's wording to the schema that does and say so.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the Signal A
  instance table plus one explanatory paragraph, and the invariant section only if a sentence there
  reads ambiguously after the addition

**Verification**:
- The Signal A instance table has exactly five rows; the new row's name matches the existing
  SCREAMING_SNAKE convention.
- The `jq` commands in the first task, re-run, produce the outputs the new paragraph claims.
- The document still contains the "system defect iff A AND B" classification sentence and the
  "schema-conformant failure is always task work" section heading, unmodified in force.
- No recorder script, no consumer arm, and no command change appears anywhere in the diff.
- `bash .claude/scripts/check-task-references.sh` exits 0.

---

### Phase 3: Record the handoff-branch detection hole and the excluded registry entries [NOT STARTED]

**Goal**: Close Gap B (an undetected path currently presented as a covered one) and Gap D (two
orchestrator scripts neither added to nor excluded from the registry, with reasoning).

**Tasks**:
- [ ] Verify Gap B by inspection: read `skill-orchestrate/SKILL.md` around lines 800-840 and
      confirm the handoff-present branch reads `blockers`, the continuation forms,
      `next_action_hint`, and the phase counts, and performs no `artifacts` shape check. Record the
      line range you actually observe.
- [ ] In the Class (b) section, add a clearly-marked note that all five `evidence_reason` consumer
      sites sit on the **recovered** (`.return-meta.json`) path, and that the handoff-present branch
      performs no artifacts shape check at all — so the missing-artifacts class from Phase 2 is
      **undetected**, not detected-and-discarded. Name it as a detection hole, distinct from the
      three existing classes, and state that a downstream implementer adding a consumer arm to the
      five sites will not cover this surface.
- [ ] In the "Considered and excluded" paragraph of the recursion-guard section, add
      `scripts/reconcile-task-status.sh` and `scripts/check-extension-docs.sh` with the guard-scope
      reasoning: the guard's scope is limited to files implementing the discrimination/recording
      pipeline, neither script is part of that pipeline, and so the recursion guard supplies no
      reason to add them — while noting that whether they belong for the self-modification-hazard
      consumer is a separate question outside this contract's scope, left as a named follow-on.
- [ ] Confirm both script paths exist in the source store before naming them, and state their
      orchestrator roles accurately (`reconcile-task-status.sh` at `/orchestrate` entry;
      `check-extension-docs.sh` feeding `verify-deploy.sh`, which is already a `critical_paths`
      entry).
- [ ] Check whether the adjacent point-fix work has any durable anchor to cross-reference under
      "Related documentation" — the task description asks for a cross-reference without
      duplication, but a task number is prohibited here. `commands/errors.md` exists; a
      `command-structure.md` at `context/reference/` does not, and no file yet uses the phrase
      "source-store lane". If no durable anchor exists for a given item, add nothing for it and
      leave the motivating-case narrative as the worked example — record that conclusion in the
      phase's completion note rather than inventing a link.
- [ ] Make no edit to `orchestrator-critical-paths.json`.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the Class (b)
  section and the recursion guard's "Considered and excluded" paragraph; optionally "Related
  documentation" if and only if a durable anchor was found

**Verification**:
- `git diff --stat` shows `system-defect-discrimination.md` as the only changed file; specifically,
  `orchestrator-critical-paths.json` is absent from the diff.
- `jq -r '.critical_paths | length'` on the JSON still returns 13.
- Both newly-named script paths resolve to existing files under
  `agent-system/extensions/core/scripts/`.
- The Class (b) note names the detection hole and is cross-referenced from the Phase 2 Signal A row.
- `bash .claude/scripts/check-task-references.sh` exits 0.

---

### Phase 4: Final gate and consistency pass [NOT STARTED]

**Goal**: Run the full gate set over the finished document and confirm the scope boundary and
source-store boundary both held across all edits.

**Tasks**:
- [ ] Read the complete document top to bottom and confirm internal consistency: the Signal A
      table, the Class (b) detection-hole note, and the invariant section tell one coherent story
      with no contradiction introduced by the incremental edits.
- [ ] Update `line_count` for `patterns/system-defect-discrimination.md` in
      `agent-system/extensions/core/index-entries.json` to match `wc -l` on the edited file. Verify
      with `bash .claude/scripts/generate-context-line-counts.sh --check` if that script is
      available; correct with `--write` if it reports a mismatch.
- [ ] Grep the full task diff for any `.claude/` write target; there must be none.
- [ ] Confirm the diff contains no recorder script, no new consumer arm at any of the five
      `evidence_reason` sites, no hook change, and no command change.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm exit 0.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it does not regress; if it
      reports a pre-existing unrelated failure, record that rather than fixing it here.

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` — the `line_count` field for the edited
  document only

**Verification**:
- `wc -l` on the document equals the `line_count` in `index-entries.json`.
- `jq -e . agent-system/extensions/core/index-entries.json` parses.
- `git diff --name-only` for the task lists only
  `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` and
  `agent-system/extensions/core/index-entries.json`.
- `check-task-references.sh` exits 0; `check-extension-docs.sh` shows no new failure.

---

## Testing & Validation

- [ ] Every line citation in the final document resolves to text supporting the claim made about it.
- [ ] The Signal A instance table has five rows, each named in the established convention, and the
      fifth is marked as having no current detector.
- [ ] The "system defect iff A AND B" classification and the "a schema-conformant failure is always
      task work" invariant are intact and unweakened.
- [ ] The Class (b) section distinguishes detected-and-discarded from undetected.
- [ ] `orchestrator-critical-paths.json` is byte-identical to its committed state (13 entries).
- [ ] No file under `.claude/**` was written.
- [ ] No recorder script, detection wiring, or command change exists in the diff.
- [ ] `check-task-references.sh` exits 0.
- [ ] `index-entries.json` `line_count` matches `wc -l`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — edited: Signal A
  instance table extended by one evidenced class, corrected citation range, Class (b) detection-hole
  note, recursion-guard exclusions extended with two named scripts and their reasoning
- `agent-system/extensions/core/index-entries.json` — edited: `line_count` refreshed
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — unchanged;
  verified complete and correct as delivered

## Rollback/Contingency

Every change is an additive or corrective edit to one markdown document plus one integer in a JSON
index, all within a single committed baseline. `git checkout HEAD -- <path>` on either file restores
the verified-good delivered state; nothing else in the repository depends on the edits. If Phase 2's
scope hypothesis fails — for instance if `handoff-schema.md` does not mark `artifacts` required —
narrow the new instance's wording to the schema that does and record the narrowing, rather than
dropping the phase: the empirical detector finding stands on its own regardless of how many schemas
declare the field required.
