# Implementation Plan: Task #92

- **Task**: 92 - quality_gate_false_positive_on_logic_notation
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: 32 (completed)
- **Research Inputs**: `specs/092_quality_gate_false_positive_on_logic_notation/reports/01_quality-gate-binder-exemption.md`
- **Artifacts**: plans/01_gate-binder-exemption-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`sentence_boundary_glue_count()` in `literature_quality_gate.py` exempts only a binder glyph
immediately followed by exactly one lowercase letter, so real higher-order-logic and
lambda-notation conversions are rejected as extraction corruption. The fix replaces that single
narrow `re.sub` with a noise-tolerant, three-pattern exemption sequence (prefix binder run with
optional ellipsis-separated second variable, prefix hat, postfix hat — using the corpus's actual
U+02C6 hat glyph, not ASCII `^`), validated by the research against all five on-disk regression
fixtures.

The work is sequenced so that a reproducible fixture harness exists **before** the regex changes,
because the research identified a substitution hazard where a naive fix *increased* false
positives on one fixture (11 -> 26). "Did new matches appear on the MIXED fixtures" is therefore a
first-class, pre-baselined check, not an afterthought. A dedicated phase closes the research's
stated verification gap by running the real conversion pipeline against the true-positive
fixture's PDF, which research-agent tooling could not do.

### Research Integration

Key findings carried into this plan:

- The addendum's suggested shape `[∀∃λ^][a-z][A-Za-z0-9]*\.` was tested literally and **does not**
  reach zero on either false positive (residuals 6/7 and 10/10). It is not the implementation
  target; the report's refined pattern is (Phase 2).
- Two root causes the addendum missed: the corpus hat glyph is **U+02C6 `ˆ`**, not ASCII `^`, and
  it occurs in **both prefix and postfix** position; and pymupdf4llm's markdown-emphasis wrapping
  (`_..._`) plus bare-digit subscript extraction fragments binder-to-variable adjacency, so the
  triggering match sits at the *last* variable of an ellipsis list, not adjacent to the binder.
- Substitution self-interference: a blanket global underscore strip before a widened regex raised
  `hott_book_2013` from 11 to 26 hits. Noise tolerance must live **inside** the exemption regex,
  never in a separate global-strip pass (Phase 2 constraint, Phase 3 test).
- Measured baselines to reproduce and hold: goodman_2024 7 -> 0, bacon_a_case 10 -> 0,
  bacon_dorr_2024 0 -> 0, hott_book_2013 11 -> 11, ahrens_north 21 -> 21.
- The three existing `literature-convert.sh` self-test fixtures must keep passing unchanged.
- MIXED documents stay rejected by design; the remedy is `LITERATURE_CONVERTER=fallback`
  reconversion, not exemption widening, threshold tuning, or a manual override.

### Prior Plan Reference

No prior plan. `plans/` was empty at planning time.

### Roadmap Alignment

No roadmap path was supplied in the delegation context; no roadmap consultation was performed and
no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- `sentence_boundary_glue_count()` returns **0** for both false-positive fixtures.
- The true-positive fixture still trips the gate, verified against a **freshly reconverted**
  primary-tier (pymupdf4llm) output, not the already-remediated on-disk fallback copy.
- Both MIXED fixtures' counts are **unchanged** (11 and 21) — neither reduced below threshold nor
  inflated by substitution self-interference.
- A reusable, corpus-optional regression harness locks all five fixture counts so this cannot
  silently regress.
- The three existing `literature-convert.sh` self-test fixtures still pass, plus new inline
  fixtures covering both hat positions and the fragmented multi-variable run.
- The MIXED-document decision and the pymupdf4llm-fragmentation lesson are recorded where the next
  implementer will find them.

**Non-Goals**:
- Exempting the parenthesized dependent-type binder shape (`∀(x : A).Px`, `Σ(a:A)B(a)`) that
  dominates `ahrens_north`'s residuals — explicitly out of scope; the fix was never meant to cover
  it and covering it would not change that document's pass/fail outcome.
- Exempting arXiv subject-class citation codes (`math.CT`, `math.AT`) in bibliographies — reported
  as a non-blocking secondary observation, left for a possible follow-up.
- Switching the check to a density-normalized signal or tuning the threshold-3 cutoff.
- Making the MIXED documents pass, by any means.
- Re-ingesting, re-indexing, or otherwise mutating `~/Projects/Literature/` corpus state.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Exemption substitution glues previously non-adjacent characters into NEW `[a-z]\.[A-Z]` matches (observed: 11 -> 26 on hott_book_2013) | H | M | Baseline harness built in Phase 1 *before* any regex edit; Phase 2 acceptance requires MIXED counts exactly unchanged, not merely "false positives reached 0"; Phase 3 adds an explicit self-interference fixture. Never use a separate global-strip pass. |
| Primary-tier (pymupdf4llm) conversion cannot be provisioned in the implementation environment, leaving the true-positive gap open | H | M | Phase 4 uses `literature-convert.sh`'s own auto-provisioning venv path (`literature-pyenv-provision.sh`) with `LITERATURE_CONVERTER=pymupdf4llm`, which refuses to silently substitute the fallback engine. If provisioning genuinely fails, Phase 4 closes as `[BLOCKED]` with the captured error — never as passed-by-assumption. |
| Over-exemption silently suppresses genuine corruption (the check's whole purpose) | H | M | The true-positive fixture and both MIXED fixtures act as over-exemption tripwires (counts must not fall); Phase 3 adds inline negative fixtures using real corruption shapes (`isalsomodal.Thus`-style fusion). |
| Regex backtracking cost on multi-MB documents (the gate runs over full document content; the refined pattern adds a lazy quantifier plus an optional group) | M | M | Phase 2 measures wall-clock runtime on the largest fixture and compares against the current implementation; a materially worse figure forces a pattern simplification before the phase closes. |
| Edits land in `.claude/**` (disposable deploy artifact) and are wiped by the next regeneration | H | L | All edits target `agent-system/extensions/literature/**`; Phase 6 handles deploy explicitly and re-verifies source/deploy parity with `diff`. |
| Harness depends on `~/Projects/Literature/` which may be absent on another machine | M | M | Follow the existing suite's convention: skip with a **visible warning**, never silently pass and never hard-fail the suite. |
| Corpus mutation during testing | H | L | All conversions write to scratch temp directories only; the corpus is read-only throughout, matching `test-literature-convert.sh`'s stated constraint. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fixture Baseline Harness [COMPLETED]

**Goal**: A runnable harness that reports `sentence_boundary_glue_count()` for all five regression
fixtures, and a recorded pre-change baseline to diff every later change against.

**Tasks**:
- [x] Create `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh`
      (plus a small Python helper if cleaner) that imports `sentence_boundary_glue_count` from the
      **source-store** `literature_quality_gate.py`, not the deploy copy. *(completed)*
- [x] For each of the five fixtures, concatenate `~/Projects/Literature/sources/{doc}/chunk_*.md`
      in lexicographic order and report the count. *(completed: uses "\n\n".join, not raw
      concatenation — see deviation note below)*
- [x] Encode expected counts as assertions with an explicit `BEFORE`/`AFTER` mode (or a single
      expectations table updated in Phase 2) so the suite fails loudly on any drift, in either
      direction, on any fixture. *(completed: single expectations table, updated in Phase 2)*
- [x] If `~/Projects/Literature/sources/` is missing, skip with a visible warning and exit 0 —
      mirror the `LITERATURE_TEST_PDF` skip convention already used in
      `tests/test-literature-convert.sh`. Never silently do nothing. *(completed)*
- [x] Run the harness against the **unmodified** gate and record the observed baseline. *(completed:
      7/10/0/11/21)*
- [x] Reconcile the observed baseline against the research's figures (7 / 10 / 0 / 11 / 21). If any
      number differs, record the actual number as the authoritative baseline and note the delta —
      do not edit the harness to match the report.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research asserts baseline counts of goodman_2024=7, bacon_a_case=10,
bacon_dorr_2024=0, hott_book_2013=11, ahrens_north=21 over the already-chunked markdown. Confirm by
running the new harness against the unmodified gate and comparing; the harness's recorded output,
not the report, is the baseline every later phase is measured against.

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh` - new harness
- `agent-system/extensions/literature/scripts/tests/` - optional Python helper if the shell
  harness would otherwise embed a large heredoc

**Verification**:
- Harness runs clean against the unmodified gate and prints five counts.
- Deliberately corrupting one expected value makes the harness fail loudly (proves assertions are
  live, not decorative).
- Corpus-absent path exercised (e.g. by pointing the corpus root at an empty dir) and produces a
  visible skip warning with exit 0.
- No file under `~/Projects/Literature/` is modified (`git`-untracked corpus: confirm by mtime or
  a checksum spot-check).

---

### Phase 2: Refined Exemption in `literature_quality_gate.py` [COMPLETED]

**Goal**: `sentence_boundary_glue_count()` implements the noise-tolerant three-pattern exemption
and hits the target counts on all five fixtures.

**Tasks**:
- [x] Replace the single `re.sub(r"[∀∃λ][a-z]\.[A-Z]", "", exempted)` with the refined sequence,
      using the report's shape as the validated starting point:
      `NOISE = r"[_\s]*"`, `VAR`, `ELLIPSIS`, then `PREFIX`, `PREFIX_HAT`, `POSTFIX_HAT`. *(completed:
      `_PREFIX_BINDER_RE`/`_PREFIX_HAT_RE` applied via `re.sub`; `POSTFIX_HAT` applied via a
      hat-anchored scan, `_strip_postfix_hat()` — see the deviation note below)*
- [x] Use the literal U+02C6 `ˆ` glyph (MODIFIER LETTER CIRCUMFLEX ACCENT), not ASCII `^`. Add an
      inline comment naming the codepoint so it survives a future editor round-trip. *(completed)*
- [x] Hoist the patterns to module-level `re.compile` constants (the gate runs over whole-document
      content; recompilation per call is avoidable cost). *(completed)*
- [x] Keep the `Ph.D.` strip and the final `findall` unchanged. *(completed)*
- [x] **Constraint**: no global preprocessing strip of markdown/whitespace. All noise tolerance
      lives inside the exemption patterns themselves. *(completed)*
- [x] Update the function docstring: what each of the three patterns covers, why the hat is
      U+02C6, why prefix and postfix hats are separate patterns, and the substitution-hazard
      warning. Cite the fixture document names, never a task number. *(completed)*
- [x] Run the Phase 1 harness. Required outcome: goodman_2024 = 0, bacon_a_case = 0,
      bacon_dorr_2024 unchanged, hott_book_2013 unchanged, ahrens_north unchanged. *(completed:
      0/0/0/11/21)*
- [x] Measure wall-clock runtime of `sentence_boundary_glue_count()` on the largest fixture before
      and after. If the new pattern is materially slower (order-of-magnitude), simplify — e.g.
      bound the lazy quantifier — and re-verify all five counts before closing the phase. *(completed:
      see deviation note below — the first working version WAS ~19x slower and required
      simplification beyond bounding the lazy quantifier alone)*
- [x] Update the Phase 1 harness expectations to the post-fix values. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The research asserts the refined pattern reaches 0/0 on the false positives
with the true-positive and both MIXED counts unaffected, and that every attempted simplification
regressed one false positive. Confirm by running the Phase 1 harness; if a simplification is
attempted for the performance reason above, re-run the full five-fixture harness after each
variant rather than assuming the report's claim transfers.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` - refined exemption
  patterns, module-level compiled constants, expanded docstring

**Verification**:
- Phase 1 harness passes with post-fix expectations.
- MIXED counts are **exactly** unchanged — an increase is a failure, not a partial success.
- `python3 -c "import literature_quality_gate"` from the source-store scripts dir succeeds
  (module still importable in isolation; both `literature-convert.sh` heredocs import it).
- `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` passes with
  its three pre-existing sentence-boundary fixtures unchanged.
- Runtime measurement recorded.

---

### Phase 3: Extend In-Script Self-Test Fixtures [NOT STARTED]

**Goal**: `literature-convert.sh --self-test` covers the notation shapes the old exemption missed
and guards against over-exemption and substitution self-interference.

**Tasks**:
- [ ] Add `gate_check` fixtures alongside the existing three (near
      `literature-convert.sh:220-227`):
  - [ ] Prefix hat with U+02C6: exemption expected.
  - [ ] Postfix hat (`_x.Fx_ ˆ` shape, drawn from the real `bacon_a_case` excerpt): exemption
        expected.
  - [ ] Markdown-emphasis + subscript-digit fragmented multi-variable run
        (`( _λx_ 1 _. . . xn.Rx_ 1 _. . . xn_ )`, the real `goodman_2024` excerpt): exemption
        expected.
  - [ ] **Negative / over-exemption guard**: genuine fusion shapes (`isalsomodal.Thus`,
        `iscontractible.Since`) still counted, >= 3 still flags.
  - [ ] **Self-interference guard**: text where an exemption span sits between two fragments that
        would form a spurious `[a-z]\.[A-Z]` if the span were naively deleted — assert the count
        does not *increase* relative to the same text with the notation removed by hand.
- [ ] Keep the three existing fixtures byte-identical; do not renumber or reword them.
- [ ] Verify each new fixture fails against the *pre-fix* gate (temporarily, via git stash or a
      local copy) so none is a tautology that would have passed all along.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` - new `gate_check` fixtures in
  the `--self-test` block

**Verification**:
- `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` exits 0 and
  prints PASS for every fixture, old and new.
- Each new fixture demonstrated to fail against the pre-fix gate (evidence captured in the phase
  notes).

---

### Phase 4: Close the True-Positive Verification Gap [NOT STARTED]

**Goal**: Prove the fixed gate still rejects genuine corruption, using a freshly reconverted
primary-tier output rather than the already-remediated on-disk fallback copy.

**Tasks**:
- [ ] Create a scratch output directory outside `~/Projects/Literature/` (never write into the
      corpus).
- [ ] Run `LITERATURE_CONVERTER=pymupdf4llm bash
      agent-system/extensions/literature/scripts/literature-convert.sh
      ~/Projects/Literature/_staging_hoi/bacon_dorr_2024_classicism.pdf <scratch-dir>`. Forcing
      `pymupdf4llm` is deliberate: that mode refuses to silently substitute the fallback engine, so
      an unavailable primary tier surfaces as a loud failure instead of a false green.
- [ ] Let the script's own `literature-pyenv-provision.sh` path provision the venv. Do not
      hand-invoke the untracked `literature-pyenv/` venv directly — the research showed it fails to
      import outside its intended wrapper (`libstdc++.so.6` ImportError).
- [ ] Capture the gate outcome: expect rejection with a `sentence-boundary-glue: N ... (threshold
      3)` reason, `N >= 3`, under the **fixed** exemption.
- [ ] Also run `sentence_boundary_glue_count()` on the reconverted content directly and record the
      number, so the result is a measured count rather than only a pass/fail.
- [ ] Re-run the same conversion with the exemption temporarily reverted, and confirm the count
      does not drop materially — establishing that the fix did not partially suppress this
      document's genuine corruption.
- [ ] Record the reconverted output's path and the counts in the phase notes.
- [ ] **If the primary tier cannot be provisioned**: capture the exact error, mark this phase
      `[BLOCKED]` with that evidence, and do not mark the acceptance criterion satisfied. All other
      phases proceed; Phase 6 records the gap as open.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: The research could not reproduce this document's genuine corruption
(pymupdf4llm not importable outside the nix-shell-wrapped environment) and its on-disk copy is
already-remediated fallback output showing 0 hits. This phase's entire purpose is to confirm or
refute the assumption that a fresh primary-tier conversion still trips the gate — a 0-or-low count
on fresh primary-tier output is a real finding to record, not a phase failure to paper over.

**Files to modify**:
- None in the repository. Output is a scratch conversion plus phase notes recorded in the
  implementation summary.

**Verification**:
- Engine line in the conversion log reads `pymupdf4llm` (not a fallback tier).
- Gate rejects with a sentence-boundary-glue reason and a recorded count.
- `~/Projects/Literature/` unmodified (checksum or mtime spot-check on the fixture's source dir).

---

### Phase 5: Record the MIXED-Document Decision and the Fragmentation Lesson [NOT STARTED]

**Goal**: The deliberate decisions and the hard-won pymupdf4llm lesson are written where the next
implementer looks, so neither is rediscovered or accidentally reversed.

**Tasks**:
- [ ] In `literature_quality_gate.py`'s docstring (or an adjacent comment block), record that
      `hott_book_2013_homotopy_type_theory_univalent_foundations` and
      `ahrens_north_shulman_tsementzis_the_univalence_principle` remain **correctly rejected**: their
      residual counts are dominated by genuine `<sup>`-span fusion corruption plus a distinct
      parenthesized dependent-type binder shape (`∀(x : A).Px`) this exemption deliberately does not
      cover. State the remedy: reconvert with `LITERATURE_CONVERTER=fallback` — not exemption
      widening, threshold tuning, or a manual override.
- [ ] Note the arXiv subject-class residual (`math.CT`, `math.AT`, `LIPIcs.TYPES`) as a known,
      deliberately unexempted secondary class.
- [ ] Add a short domain-context note under
      `agent-system/extensions/literature/context/project/literature/domain/` (path to confirm
      against the extension's actual context layout) documenting pymupdf4llm's markdown-emphasis
      (`_..._`) and bare-digit subscript extraction, with the two real excerpts from the research
      report, and the rule: build noise tolerance into the pattern, never via a global strip pass —
      including the measured 11 -> 26 regression as the concrete cost of getting it wrong.
- [ ] Register the new context file wherever the extension indexes its context
      (`index-entries.json` / `manifest.json`) if that layout requires it.
- [ ] **No task-number references** in any of this content (it lives outside `specs/**`). Cite
      document names, filenames, and section headings.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` - docstring/comment
  decision record
- `agent-system/extensions/literature/context/project/literature/domain/` - new fragmentation note
- `agent-system/extensions/literature/index-entries.json` and/or `manifest.json` - registration, if
  the extension's context layout requires it

**Verification**:
- Diff read-through confirms every changed hunk in the `.py` file lies inside a docstring/comment
  region (no code touched in this phase).
- `bash .claude/scripts/check-task-references.sh` (or equivalent repo lint) reports no new
  task-number references outside `specs/**`.
- New context file is discoverable by whatever mechanism the extension uses (grep the index for
  the filename).

---

### Phase 6: Deploy, Full Gate, and Regression Sweep [NOT STARTED]

**Goal**: Source and deploy copies are in sync, every suite passes, and the outcome — including any
open gap from Phase 4 — is recorded.

**Tasks**:
- [ ] Deploy the source store to `.claude/` via the project's deploy path
      (`.claude/scripts/deploy-headless.sh` or the extension picker's reload).
- [ ] `diff` the deployed `.claude/scripts/literature_quality_gate.py` against the source-store copy
      and confirm byte-identical parity (this parity was clean before the change and must remain so).
- [ ] Run the full suite set:
  - [ ] `literature-convert.sh --self-test`
  - [ ] `tests/test-quality-gate-notation.sh` (Phase 1 harness, post-fix expectations)
  - [ ] `tests/test-literature-convert.sh` (pre-existing fallback/two-column regression suite)
- [ ] Re-run the five-fixture count table one final time against the **deployed** copy and confirm
      it matches the source-store results.
- [ ] Record in the implementation summary: the before/after count table, the Phase 4 reconversion
      result (or the captured provisioning failure if it blocked), the runtime measurement, and the
      MIXED-document decision.
- [ ] Commit with `task 92: complete implementation` conventions; stage only the files this task
      touched (never `git add -A`).

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `.claude/**` (deploy output only, produced by the deploy tooling — never hand-authored)

**Verification**:
- All three suites exit 0.
- Source/deploy `diff` clean for every touched script.
- Five-fixture table identical between source-store and deployed copies.
- `git status --short` shows only intended files; `git diff --staged` reviewed before commit.

---

## Testing & Validation

- [ ] `goodman_2024_higher_order_logic_as_metaphysics` count = 0.
- [ ] `bacon_a_case_for_higher_order_metaphysics` count = 0.
- [ ] `bacon_dorr_2024_classicism` still trips the gate on a **freshly reconverted primary-tier**
      output (or the failure is recorded as an open, evidenced gap).
- [ ] `hott_book_2013_...` count unchanged (no decrease, **no increase**).
- [ ] `ahrens_north_...` count unchanged (no decrease, **no increase**).
- [ ] Three pre-existing `--self-test` sentence-boundary fixtures still pass, byte-identical.
- [ ] New self-test fixtures (prefix hat, postfix hat, fragmented multi-variable run,
      over-exemption guard, self-interference guard) all pass, and each was shown to fail pre-fix.
- [ ] `tests/test-literature-convert.sh` still passes.
- [ ] Gate runtime on the largest fixture is not materially worse than before.
- [ ] `~/Projects/Literature/` corpus unmodified throughout.
- [ ] No task-number references introduced outside `specs/**`.

## Artifacts & Outputs

- Modified `agent-system/extensions/literature/scripts/literature_quality_gate.py`
- Modified `agent-system/extensions/literature/scripts/literature-convert.sh` (self-test fixtures)
- New `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh`
- New pymupdf4llm-fragmentation domain-context note under the literature extension's context tree
- Redeployed `.claude/scripts/` copies (deploy output)
- Implementation summary at
  `specs/092_quality_gate_false_positive_on_logic_notation/summaries/01_*-summary.md`

## Rollback/Contingency

- Every phase is independently revertible; the regex change is confined to one function in one
  module. `git revert` of the Phase 2 commit restores the current narrow exemption, and the Phase 1
  harness (committed first, independently) immediately reports the restored baseline — so a revert
  is self-verifying.
- If the refined pattern proves unacceptably slow or cannot be made both fast and correct, fall
  back to the narrow exemption and record the finding; the research's noted alternative
  (density-normalized signal for documents with detected logic notation) becomes a follow-up task
  rather than an in-scope pivot.
- If Phase 4's primary-tier conversion cannot be provisioned, ship Phases 1-3 and 5-6 with the
  verification gap recorded as explicitly open in the summary. Do not close the task's acceptance
  criterion on the strength of the already-remediated on-disk copy.
- No corpus or index mutation occurs in any phase, so no data-level rollback is needed.
