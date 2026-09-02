# Implementation Plan: Task #104

- **Task**: 104 - Resolve glue-check false-positive class on math-heavy OCR'd scans
- **Status**: [COMPLETED]
- **Effort**: 4.5 hours
- **Dependencies**: Task 102 (completed)
- **Research Inputs**: specs/104_resolve_glue_check_false_positive_class/reports/01_glue-check-false-positive-class.md
- **Artifacts**: plans/01_glue-check-false-positive-class.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research selected **route (a)**: fix the input, not the gate. `joyce_1999_foundations-causal-decision-theory`'s
4 `sentence_boundary_glue_count()` hits decompose into 2 genuine text-layer defects (a poor-vintage
2019 archive.org OCR pass) plus 2 inline math-notation false hits. Targeted re-OCR of only the
defective pages eliminates the 2 genuine defects and adds no new hits, dropping the count to 2 —
below the `>=3` reject threshold — with **zero change** to `sentence_boundary_glue_count()`, its
exemption regexes, or the threshold. This plan executes that bounded input-layer fix, then
reconciles the gate module's docstring **additively** (the existing prohibition is satisfied, not
narrowed), mirrors a one-line pointer into the converter-tier guide, and re-gates the stale corpus
copy. Definition of done: a fresh `literature-convert.sh` run over the re-OCR'd PDF reports 2 hits
and passes the gate; both pinned MIXED tripwires and the inline self-test harness are unchanged.

**Routes (b) and (c) are settled and MUST NOT be relitigated.** Route (b) (a math-notation regex
exemption) was rejected: the two false-positive strings (`"^s.P(S\A)u(0[A S])"`, `"f.I+i p*( YHr"`)
are garbled OCR artifacts sharing no generalizable structural shape with the existing
binder/hat exemption family, and the module's own history records a widening attempt that *raised*
a MIXED document from 11 to 26 hits via substitution self-interference. Route (c) (a distinct
scanned/OCR calibration class) was rejected: task 102 falsified "scanned vs. born-digital" as the
discriminator, and both MIXED documents are themselves scanned math texts that must stay correctly
rejected. If implementation hits friction, the response is to re-examine the *input*, never to
reopen (b) or (c).

**Source-store boundary**: every code/doc edit in this plan targets
`agent-system/extensions/literature/**`. The `.claude/` tree is a disposable deploy artifact —
edits there are silently wiped by the next regeneration (see
`.claude/rules/source-store-deploy-boundary.md`).

**No task-number references in the deliverables.** The docstring and guide edits land outside
`specs/**` and MUST NOT cite "task 104" or any task number
(`.claude/rules/no-task-references-in-deliverables.md`). Cite durable anchors: the document id,
the file/section name, the measured counts.

### Research Integration

Integrated from `reports/01_glue-check-false-positive-class.md`:
- The decisive arithmetic (4 = 2 genuine + 2 notation; fixing the 2 genuine yields 2 < 3) drives
  the whole plan — the notation hits are never exempted, matched, or otherwise touched.
- `ocrmypdf` is already installed system-wide (`/run/current-system/sw/bin/ocrmypdf`); no
  provisioning work.
- Full-document re-OCR is explicitly recommended *against* (unproven at 284-page scale, could
  introduce artifacts on currently-clean pages). The fix stays page-targeted.
- Docstring reconciliation is additive: append a closing note before the prohibition clause,
  naming the two residual notation hits as a deliberately unexempted non-blocking class parallel
  to the arXiv subject-code precedent already documented in the same paragraph. The prohibition
  clause itself stays byte-identical.
- Adjacent-scope flag (existing 396-chunk ungated corpus copy) is resolved by this plan — see
  "Adjacent-scope decision" below.
- Ownership split preserved: this task executes the one-off bounded fix; task 105 owns building
  reusable/general OCR-tier tooling. This task does **not** block on 105 and must not drift into
  building general tooling.

**Verified beyond the report (plan-time environment checks):**
- The source PDF is at `/home/benjamin/Projects/Logos/Theory/specs/literature/joyce_1999_foundations-causal-decision-theory.pdf`
  — **outside this repository**, in a sibling project. It is not covered by this repo's git, so
  file-level backup (not git) is the rollback mechanism for it.
- `pdfinfo` reports **284 pages**, not the 296 the task description cites. The "pages 119 and 217"
  claim is therefore ambiguous between printed book-page numbers and PDF page indices, and is
  carried as a Scope Hypothesis on Phase 1 rather than trusted.
- `pdftk` is available as a splice fallback if `ocrmypdf --pages` proves unsuitable.

### Prior Plan Reference

No prior plan for this task. Effort calibration draws on task 102's converter-tier
characterization work, which established the Class A/B framing this plan builds on.

### Adjacent-scope decision (research recommendation 5)

**Decision: re-gate and refresh, bounded.** `~/Projects/Literature/index.json` carries a
`joyce_1999_foundations-causal-decision-theory` entry (396 chunks, `metadata_status: "unresolved"`,
`provenance_fidelity: "no_source_pdf"`) whose chunks were ingested via the pre-gating ungated
`/literature <path>` path. Leaving a stale, never-gated copy of the *uncorrected* OCR on disk after
fixing its source would leave the corpus knowingly worse than the fix allows, so Phase 7 measures
the existing copy's gate count and refreshes it from the corrected conversion, with a full backup
first. **Bound**: if the refresh needs anything beyond a mechanical chunk-and-index replacement,
Phase 7 records the finding and stops — building repeatable machinery is task 105's territory.

### Roadmap Alignment

No `specs/ROADMAP.md` found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Bring `joyce_1999_foundations-causal-decision-theory` from 4 to 2 `sentence_boundary_glue_count()`
  hits via targeted page-level re-OCR of its source PDF, and confirm it now passes the gate.
- Append an additive closing note to `literature_quality_gate.py`'s MIXED-documents paragraph
  recording the resolution and naming the two residual math-notation hits as a deliberately
  unexempted, non-blocking class.
- Add a one-line resolved-example pointer to `literature-organization.md`'s
  `## Converter Tier Selection` section.
- Preserve the pinned tripwires (`hott_book_2013` EXACTLY 11, `ahrens_north` EXACTLY 21) and the
  inline `gate_check()` self-test harness, both unchanged.
- Re-gate and refresh the stale ungated corpus copy of the document.

**Non-Goals**:
- Any change to `sentence_boundary_glue_count()`'s body, its exemption regexes
  (`_PREFIX_BINDER_RE`, `_PREFIX_HAT_RE`, `_strip_postfix_hat`/`_POSTFIX_HAT_TAIL_RE`), or the
  `>=3` threshold.
- Any narrowing, qualifying, or rewording of the prohibition clause at the end of the
  MIXED-documents paragraph ("never widening this exemption further, tuning the threshold-3
  cutoff, or a manual override").
- Full-document re-OCR of the 284-page PDF.
- Reusable/general OCR-tier tooling, a productionized page-level re-OCR-and-splice mechanism, or
  any change to the converter tier-selection logic — all owned by task 105.
- Re-litigating routes (b) or (c).
- Any edit under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| "Pages 119/217" are printed book pages, not PDF indices (PDF is 284pp vs. the cited 296pp) | H | M | Phase 1 localizes each of the 4 hits in the converted markdown and maps it to an actual PDF page before any OCR runs; the cited numbers are a hypothesis to confirm, not an input |
| Re-OCR of the targeted pages introduces *new* `[a-z]\.[A-Z]` hits elsewhere on those pages | M | L | Phase 3 recounts over the whole document and compares the full hit list against Phase 1's baseline, not just the total |
| Re-OCR alters non-targeted pages (whole-file re-render) | M | L | Phase 2 verifies page count is unchanged and that extracted text on a sample of non-target pages is byte-identical to the backup |
| Source PDF lives outside this repo and is not git-tracked; a bad write is unrecoverable | H | L | Phase 2 takes a file-level backup copy before any write, and never writes in place (writes a new file, swaps only after verification) |
| Docstring edit accidentally crosses the triple-quoted string boundary or breaks the module | H | L | Phase 4 verification imports the module and runs `literature-convert.sh --self-test`; `prose` tier's named blind spot is exactly this |
| Corpus refresh clobbers the existing 396-chunk entry irrecoverably | M | L | Phase 7 backs up the sources dir and the index entry before touching either; rollback is a directory restore |
| Scope drift into building general OCR tooling (task 105's territory) | M | M | Explicit non-goal above; Phase 7's stated bound; every OCR step is a literal one-off command on one document |
| Reconversion of a 284-page, 20MB book is slow enough to look hung | L | M | Phases 1 and 3 budget for it and convert into a scratch directory, never over the live corpus |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |
| 6 | 7 | 3, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline capture and defect localization [COMPLETED WITH EXCLUSIONS]

**Goal**: Reproduce today's 4-hit gate rejection from the current source PDF, and identify which
actual PDF pages carry the 2 genuine defects — replacing the unverified "pages 119 and 217" claim
with a measured mapping.

**Tasks**:
- [x] Confirm the source PDF path and page count:
      `/home/benjamin/Projects/Logos/Theory/specs/literature/joyce_1999_foundations-causal-decision-theory.pdf`
      (`pdfinfo` reported 284 pages at plan time; re-confirm). *(completed: pdfinfo re-confirms 284 pages)*
- [x] Convert into a scratch directory (never over the live corpus) with
      `agent-system/extensions/literature/scripts/literature-convert.sh <pdf> <scratch_dir>` and
      capture the gate output verbatim, including the reported hit count.
      *(completed: gate reports "Quality gate: PASSED" — see baseline-measurement.md)*
- [x] Enumerate all `[a-z]\.[A-Z]` hits the gate counts, with ~80 characters of surrounding
      context each, by calling `sentence_boundary_glue_count()` directly on the joined markdown
      (join chunks with `"\n\n"`, never raw concatenation — raw concatenation manufactures or
      suppresses boundary matches, as `test-quality-gate-notation.sh`'s header documents).
      *(completed: 2 hits total, both raw and exempted-count identical — see
      baseline-measurement.md)*
- [x] Classify each hit as genuine missing-space vs. math notation. The expected notation pair is
      `"^s.P(S\A)u(0[A S])"` (Stalnaker's Equation fragment) and `"f.I+i p*( YHr"` (garbled
      matrix-predicate fragment). *(completed: both of the 2 measured hits ARE exactly this
      notation pair; zero genuine hits found)*
- [ ] For each **genuine** hit, locate its text on the actual PDF page (e.g. `pdftotext -f N -l N`
      sweeping candidate pages, or matching against the converted markdown's page structure) and
      record the confirmed **PDF page index**. *(deviation: skipped — no genuine hit exists to
      locate; measured genuine-defect count is 0, not 2)*
- [x] Record the baseline in the task directory: total count, the full classified hit list with
      context, and the confirmed PDF page indices of the genuine defects.
      *(completed: see baseline-measurement.md; no genuine-defect page indices to record since
      none exist)*

**STOPPED per Scope Hypothesis below — see `baseline-measurement.md` for the full measurement and
implication analysis.** Measured total is 2 (not 4); measured genuine-defect count is 0 (not 2).
Phases 2-3 were subsequently excluded (see their own `#### Reasoned Exclusions` records) and
Phases 4-7 were retargeted to the verified narrative, per requester direction after this halt was
reported.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Locate each genuine hit's PDF page and record its index (Task 1.5) | No genuine hit exists in the current document state to locate. Three independent measurements (fresh reconversion, existing 396-chunk corpus copy, raw unexempted regex scan) all report exactly 2 hits, both the known math-notation false positives, zero genuine defects — falsifying the plan's asserted 2-genuine/2-notation split before any page-localization work could be meaningful. | `specs/104_resolve_glue_check_false_positive_class/baseline-measurement.md` |

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The report asserts (i) exactly 4 hits, (ii) a 2-genuine/2-notation split, and
(iii) that the genuine defects are on "pages 119 and 217" of a "296pp" document. Plan-time
`pdfinfo` reports **284** pages, so (iii) is unconfirmed and may be printed book-page numbering
with an offset. Confirm all three at implementation time by measuring: the hit count comes from the
gate run, the split from the enumerated context strings, and the page indices from locating each
genuine hit's text in the PDF. **If the measured genuine-defect count is not 2, or the total is not
4, stop and report** — the plan's threshold arithmetic (4 -> 2) depends on it, and a different
split changes which route is viable.

**Files to modify**:
- None (read-only measurement). Baseline artifacts are written under
  `specs/104_resolve_glue_check_false_positive_class/` only.

**Verification**:
- Gate run reproduces a rejection with the recorded hit count.
- Every counted hit appears in the classified list with context; classification totals sum to the
  gate's reported count.
- Each genuine defect has a confirmed PDF page index, and the corrupted string is visible in that
  page's own `pdftotext` output.

---

### Phase 2: Targeted re-OCR of the confirmed defective pages [COMPLETED WITH EXCLUSIONS]

**Goal**: Produce a corrected PDF in which only the confirmed defective pages have been re-OCR'd,
leaving every other page untouched.

**Tasks**:
- [ ] Back up the source PDF to a timestamped copy alongside it (file-level; this PDF is outside
      this repo and not git-tracked, so git is not a rollback path for it). *(deviation: skipped — no defective pages exist to fix; see Reasoned Exclusions)*
- [ ] Re-OCR only the confirmed pages into a **new output file**, never in place. Preferred form:
      `ocrmypdf --force-ocr --output-type pdf -l eng --pages <p1>,<p2> <input.pdf> <output.pdf>`
      (unselected pages pass through unmodified). *(deviation: skipped — see Reasoned Exclusions)*
- [ ] If `--pages` is unavailable or misbehaves in this `ocrmypdf` build, fall back to the
      explicit splice: extract each target page with `pdftk`, run
      `ocrmypdf --force-ocr --output-type pdf -l eng` on the single-page extract, and reassemble
      with `pdftk` in original page order. *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Verify the output PDF's page count equals the input's. *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Verify non-target pages are unchanged: compare `pdftotext` output for a sample of at least
      5 non-target pages (including the immediate neighbours of each target page) between backup
      and output — they must be identical. *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Verify each target page's `pdftotext` output no longer contains its recorded corrupted
      string, and spot-check that the re-OCR recovered rather than degraded the text (the report
      cites a dropped closing curly quote and an accented "Reyni" as expected recoveries).
      *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Swap the corrected PDF into the canonical source path only after the checks above pass,
      keeping the backup. *(deviation: skipped — see Reasoned Exclusions)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- None. No re-OCR was performed and the source PDF was not touched — see Reasoned Exclusions.

**Verification**:
- N/A — phase excluded in full.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Entire phase (backup, re-OCR, splice, verification, swap) | Phase 1's measurement falsified the premise this phase depends on: the source PDF already converts and passes the gate at 2 hits (both known math-notation false positives), with zero genuine text-layer defects present. Re-OCRing pages that carry no defects would be work performed to make a narrative true rather than to fix anything, and risks the plan's own documented risk of introducing new hits on currently-clean pages. Directed by the requester after Phase 1's halt was reported. | `specs/104_resolve_glue_check_false_positive_class/baseline-measurement.md`; `handoffs/phase-1-handoff-20260902T063833Z.md` |

---

### Phase 3: Reconvert and confirm the gate now passes at 2 hits [COMPLETED WITH EXCLUSIONS]

**Goal**: Establish, by measurement, that the corrected PDF converts to 2 hits — below the `>=3`
reject threshold — with the 2 remaining hits being exactly the 2 known math-notation strings and
no new hits anywhere.

**Tasks**:
- [x] Reconvert the corrected PDF into a **fresh** scratch directory via `literature-convert.sh`
      (default converter; do **not** set `LITERATURE_CONVERTER=fallback` — the fallback tier is
      documented to make this document worse, 4 -> 5).
      *(completed: already performed as part of Phase 1's baseline measurement, since there was no
      separate "corrected" PDF to reconvert — see Reasoned Exclusions)*
- [x] Capture the gate output verbatim; confirm the document is no longer rejected.
      *(completed: gate reports PASSED; the document was never rejected under the current source
      PDF — see baseline-measurement.md)*
- [x] Re-enumerate all hits with context using the same joined-chunk method as Phase 1.
      *(completed: this IS Phase 1's enumeration — 2 hits, both math-notation)*
- [ ] Diff the post-fix hit list against Phase 1's baseline list: the 2 genuine defects must be
      gone, the 2 notation hits must be present and unchanged, and there must be **zero** new
      hits. *(deviation: skipped — there is no distinct pre-fix/post-fix pair to diff; Phase 1's
      baseline measurement IS the only measurement, see Reasoned Exclusions)*
- [x] Record the confirmed post-fix count and the surviving hit strings in the task directory —
      these are the exact figures Phases 4 and 5 will cite.
      *(completed: 2 hits, `^s.P(S\A)u(0[A S])` and `f.I+i p*( YHr` — recorded in
      baseline-measurement.md and cited by Phases 4-5 below)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The plan asserts the post-fix count will be exactly **2**, and that the gate
will therefore pass. Confirm by running the gate, not by inference from Phase 2's page-level
checks. **If the count is 3 or higher, stop and report** rather than reaching for a gate change —
routes (b) and (c) are closed, and the correct next move is re-examining the input (which pages,
which OCR settings). *(Resolved: the count IS 2, confirmed by Phase 1's measurement; the "if >= 3"
branch never applies.)*

**Files to modify**:
- None (read-only measurement into a scratch directory).

**Verification**:
- Gate reports a passing result for the document. **(met — Phase 1 measurement)**
- Post-fix hit count is 2. **(met — Phase 1 measurement)**
- The 2 surviving hits are exactly the math-notation pair; the baseline diff shows no new hits.
  **(met — there is only one measurement, not a diff of two; both hits ARE the notation pair)**

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Diff against a distinct pre-fix Phase 1 baseline (Task 3.4) | Phase 2 performed no re-OCR (see its own Reasoned Exclusions), so there is no separate "corrected PDF" for this phase to reconvert and diff against Phase 1's baseline. Phase 1's own measurement already IS the sole, current measurement of the document, at 2 hits — the exact figure this phase exists to confirm. A diff against itself would be vacuous. | `specs/104_resolve_glue_check_false_positive_class/baseline-measurement.md` |

**Verification**:
- Gate reports a passing result for the document.
- Post-fix hit count is 2.
- The 2 surviving hits are exactly the math-notation pair; the baseline diff shows no new hits.

---

### Phase 4: Additive docstring reconciliation in the gate module [COMPLETED]

**Goal**: Record the resolution in `sentence_boundary_glue_count()`'s docstring by **appending** to
the existing MIXED-documents paragraph, leaving the prohibition clause byte-identical.

**Tasks**:
- [x] In `agent-system/extensions/literature/scripts/literature_quality_gate.py`, locate the
      MIXED-documents paragraph — the one ending in "...never widening this exemption further,
      tuning the threshold-3 cutoff, or a manual override." — and insert the new note **after**
      the existing `joyce_1999` 4-hits-to-5-on-fallback sentence and **before** the prohibition
      clause. *(completed)*
- [x] The note must record: (a) that the document's two genuine hits were an artifact of the
      original 2019 archive.org OCR text layer, and that targeted re-OCR of the two specific
      defective pages eliminates them, bringing the document to the Phase-3-confirmed count,
      safely under threshold, **with no gate change**; and (b) the two residual math-notation hits
      named as a second **deliberately unexempted, non-blocking class**, explicitly parallel to the
      arXiv subject-code precedent (`math.CT`, `math.AT`) already documented earlier in the same
      paragraph — accepted rather than pattern-matched away.
      *(deviation: altered — per requester direction after Phase 1's halt, the note records the
      VERIFIED narrative instead: the document already converts to 2 hits with zero genuine
      defects present, confirmed by both an exempted and a raw unexempted scan; no re-OCR was
      performed or claimed. The arXiv-parallel framing for the 2 residual notation hits (b) is
      unchanged from the plan.)*
- [x] Cite the concrete count from Phase 3's record. Do not restate a number the plan predicted;
      use the number that was measured. *(completed: cites 2, the number Phase 1/3 measured, and
      names both exact strings)*
- [x] Leave the prohibition clause textually untouched — route (a) widens no exemption, tunes no
      threshold, and applies no manual override, so the prohibition is *satisfied*, not narrowed.
      *(completed: `git diff` confirms the prohibition line is byte-identical)*
- [x] No task-number reference anywhere in the added text (this file is outside `specs/**`).
      *(completed: verified via check-task-references.sh, 0 occurrences)*
- [x] Match the surrounding docstring's line width and prose voice. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — append a closing note
  to the `sentence_boundary_glue_count()` MIXED-documents docstring paragraph.

**Verification**:
- Diff read-through confirms every changed hunk lies inside the triple-quoted docstring.
- `git diff` shows the prohibition clause line unchanged.
- `python3 -c "import literature_quality_gate"` (with the script dir on `sys.path`) succeeds.
- `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` passes.
- No task-number pattern in the added lines.

---

### Phase 5: Guide pointer in the Converter Tier Selection section [COMPLETED]

**Goal**: Cite the resolved example in the guide section that already documents re-OCR as the
Class B remedy but carries no confirmed post-fix result.

**Tasks**:
- [x] In `agent-system/extensions/literature/context/guides/literature-organization.md`, inside
      the existing `## Converter Tier Selection` section, add one sentence naming
      `joyce_1999_foundations-causal-decision-theory` as a resolved Class B example with its
      measured before/after counts (4 -> the Phase-3-confirmed count) achieved by targeted
      page-level re-OCR, with no gate change.
      *(deviation: altered — per requester direction after Phase 1's halt, the added sentence
      states the verified narrative instead: the document already converts cleanly and passes at
      2 hits with zero genuine defects present, with no re-OCR having been performed. No "4 ->
      2 via re-OCR" claim is made.)*
- [x] Place it after the **Diagnostic procedure** bullets (which already prescribe
      `ocrmypdf --force-ocr` on the affected pages) and before the
      "**No automatic tier selection exists or is intended.**" paragraph. *(completed)*
- [x] Keep the existing Class A/Class B table's `joyce_1999` cells intact — the 4 -> 5 fallback
      figure there remains true and is the reason the tier switch is not the remedy.
      *(completed: table untouched, confirmed via git diff)*
- [x] No task-number reference (this file is outside `specs/**`). *(completed: verified via
      check-task-references.sh, 0 occurrences)*

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/context/guides/literature-organization.md` — one sentence
  added to `## Converter Tier Selection`.

**Verification**:
- Diff read-through confirms the change is a single added sentence in the intended section, with
  the surrounding table and paragraphs unchanged.
- The cited count matches Phase 3's recorded figure and Phase 4's docstring note exactly.
- No task-number pattern in the added line.

---

### Phase 6: Regression gates and tripwire preservation [COMPLETED]

**Goal**: Prove nothing about the gate's behavior moved — the whole point of route (a).

**Tasks**:
- [x] Run `agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh` and
      confirm all five fixtures match: `goodman_2024`=0, `bacon_a_case`=0, `bacon_dorr_2024`=0,
      and the two pinned over-exemption tripwires `hott_book_2013`=**exactly 11** and
      `ahrens_north`=**exactly 21** (these must neither fall nor rise). *(completed: all five pass;
      hott_book_2013=11, ahrens_north=21)*
- [x] Run `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` and
      confirm every inline `gate_check()` fixture passes. *(completed: all fixtures pass)*
- [x] Confirm via `git diff` that no line inside `sentence_boundary_glue_count()`'s *body*, its
      exemption regex definitions, or the threshold constant changed — the only diff in the
      module is docstring prose. *(completed: diff confined to docstring lines)*
- [x] Confirm no file under `.claude/**` was modified. *(completed: `git status --porcelain .claude/`
      is empty)*

**Timing**: 0.5 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:
- None (verification only).

**Verification**:
- `test-quality-gate-notation.sh` exits 0 with all five fixtures matching (or SKIPs visibly if the
  corpus is absent — a skip is not a pass; note it explicitly if it occurs).
- `literature-convert.sh --self-test` exits 0.
- `git diff` over the gate module touches docstring lines only.
- `git status` shows no `.claude/**` modifications.

---

### Phase 7: Re-gate and refresh the stale corpus copy [COMPLETED WITH EXCLUSIONS]

**Goal**: Resolve the adjacent-scope finding — measure the existing ungated 396-chunk corpus copy
against the gate, then replace it with the corrected conversion so the corpus no longer holds the
uncorrected OCR.

**Tasks**:
- [x] Back up `~/Projects/Literature/sources/joyce_1999_foundations-causal-decision-theory/` (all
      chunks, `chunks.json`, `metadata.json`) and the document's `~/Projects/Literature/index.json`
      entry before touching either. *(completed:
      `~/Projects/Literature/backups/joyce_1999_foundations-causal-decision-theory_20260902T064713Z/`)*
- [x] Run `sentence_boundary_glue_count()` against the **existing on-disk** chunks (joined with
      `"\n\n"`) and record the measured count — this establishes whether the pre-gating ungated
      ingest actually carried the uncorrected defects, per the "no gate rejection becomes a silent
      skip" criterion. *(completed: ran the FULL gate, not just the glue check — 2 hits, PASS on
      every check; see phase7-corpus-regate.md)*
- [ ] Refresh the corpus copy from Phase 3's corrected conversion: replace the chunk set and
      update the index entry's `chunk_count` (and any count-derived field that mechanically
      follows) to match. *(deviation: skipped — see Reasoned Exclusions)*
- [ ] Re-run the gate against the refreshed on-disk copy and confirm it reports the Phase-3
      count and passes. *(deviation: skipped — no refresh was performed; the existing copy already
      measures 2 and passes, see phase7-corpus-regate.md)*
- [x] Re-run `test-quality-gate-notation.sh` after the corpus write — it reads from this same
      corpus tree, and the two pinned tripwires must still read exactly 11 and 21. *(completed: no
      corpus write occurred, but re-ran anyway for reconfirmation — hott_book_2013=11,
      ahrens_north=21, unchanged)*
- [x] Record in the task directory: the pre-refresh measured count, the post-refresh count, and
      the backup location. *(completed: `phase7-corpus-regate.md`)*

**Bound**: if the refresh requires anything beyond a mechanical chunk-and-index replacement (e.g.
re-deriving metadata, resolving `metadata_status: "unresolved"`, or building any reusable
ingest/OCR machinery), **stop, restore from backup if mid-write, and record the finding** — that
work belongs to task 105, not here.

**Timing**: 1 hour

**Depends on**: 3, 6

**Verification Tier**: full

**Scope Hypothesis**: The plan assumes the existing corpus copy has **396** chunks and that
refreshing it is a mechanical chunk-and-index replacement. Confirm the chunk count on disk before
writing, and confirm the index entry has no fields beyond count-derived ones that the replacement
would invalidate. If either assumption fails, apply the Bound above.

**Files to modify**:
- `~/Projects/Literature/sources/joyce_1999_foundations-causal-decision-theory/` — chunk set
  replaced from the corrected conversion (backed up first).
- `~/Projects/Literature/index.json` — the document's `chunk_count` and count-derived fields
  updated (backed up first).

**Verification**:
- Backup exists and is complete before any write. **(met)**
- Post-refresh gate run over the on-disk copy reports the Phase 3 count and passes. **(N/A — no
  refresh performed; the existing, unmodified copy already measures 2 and passes the full gate)**
- `test-quality-gate-notation.sh` still reports `hott_book_2013`=11 and `ahrens_north`=21 exactly.
  **(met)**
- `index.json` remains valid JSON (`jq . index.json` succeeds) and the entry's `chunk_count`
  matches the on-disk chunk file count. **(met — unchanged, since no write occurred: 396 == 396)**

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Replace the chunk set from "Phase 3's corrected conversion" and update `chunk_count` (Task 7.3); re-run the gate against a refreshed copy (Task 7.4) | Phases 2-3 performed no re-OCR and produced no distinct "corrected conversion" to swap in — the existing on-disk copy already measures 2 hits and PASSES the full gate (column-interleaving, glue, page-coverage, ligature, dehyphenation, NUL, printable-ratio all clean), so a literal swap would replace passing content with near-identical passing content: churn with no quality benefit. Separately, the ingest pipeline this swap would invoke (`literature-ingest.sh`, `literature-convert.sh`) was under active, uncommitted modification by a concurrently-running sibling task at measurement time (later committed as "task 105 phase 2: distinct needs-OCR bucket in literature-ingest.sh"), so invoking it now would not be a deterministic "mechanical" step — it risks absorbing unrelated in-flight behavior this task has no basis to evaluate. Either reason alone triggers the Bound above ("anything beyond a mechanical chunk-and-index replacement stops and hands off"). | `specs/104_resolve_glue_check_false_positive_class/phase7-corpus-regate.md` |

---

## Testing & Validation

- [x] Fresh `literature-convert.sh` run over the (unmodified) source PDF passes the quality gate
      at 2 hits. *(altered: no re-OCR was performed — see Phase 1's baseline-measurement.md — but
      the fresh-conversion check itself was run and passes)*
- [x] The 2 surviving hits are exactly the 2 known math-notation strings; zero new hits versus the
      Phase 1 baseline. *(there is only one baseline measurement, not a before/after pair; both
      hits ARE the notation pair)*
- [x] `test-quality-gate-notation.sh`: all five fixtures match, with `hott_book_2013`=11 and
      `ahrens_north`=21 exactly (neither falling nor rising) — run both before Phase 7's corpus
      write and after it. *(no corpus write occurred; ran three times total across Phases 6-7, all
      identical: 11/21)*
- [x] `literature-convert.sh --self-test`: all inline `gate_check()` fixtures pass.
- [x] `git diff` confirms `literature_quality_gate.py`'s only change is docstring prose — no change
      to the function body, the exemption regexes, or the threshold.
- [x] The prohibition clause ("never widening this exemption further, tuning the threshold-3
      cutoff, or a manual override") is byte-identical to its pre-task text.
- [x] No file under `.claude/**` is modified.
- [x] No task-number reference appears in any file changed outside `specs/**`.

## Artifacts & Outputs

*(Actual outputs, per the exclusions recorded above — no re-OCR or corpus write occurred.)*

- Source PDF at
  `/home/benjamin/Projects/Logos/Theory/specs/literature/joyce_1999_foundations-causal-decision-theory.pdf`
  — **unmodified**; no re-OCR was performed (see Phases 1-2's Reasoned Exclusions).
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — additive docstring
  closing note recording the VERIFIED narrative (document already passes at 2 hits, zero genuine
  defects, no re-OCR performed).
- `agent-system/extensions/literature/context/guides/literature-organization.md` — one-sentence
  resolved-example pointer in `## Converter Tier Selection`, same verified narrative.
- `specs/104_resolve_glue_check_false_positive_class/baseline-measurement.md` — Phase 1's full
  measurement and Scope Hypothesis falsification record.
- `specs/104_resolve_glue_check_false_positive_class/phase7-corpus-regate.md` — Phase 7's full-gate
  measurement of the existing corpus copy, backup record, and exclusion rationale.
- `~/Projects/Literature/backups/joyce_1999_foundations-causal-decision-theory_20260902T064713Z/`
  — Phase 7 backup of the (unmodified) corpus sources dir and index entries.
- `specs/104_resolve_glue_check_false_positive_class/summaries/01_*-summary.md` — execution
  summary recording the falsified premise, the verified narrative, and the Phase 7 measurement.

## Rollback/Contingency

- **Docstring and guide edits** (Phases 4, 5): `git` revert of the two files under
  `agent-system/extensions/literature/`. Both are additive prose; reverting restores the exact
  pre-task text.
- **Source PDF** (Phase 2): restore from the timestamped backup taken before any write. This file
  is outside this repo and not git-tracked, so the backup is the only rollback path — take it
  first, verify it, and do not delete it as part of this task.
- **Corpus copy** (Phase 7): restore the backed-up sources directory and the backed-up `index.json`
  entry. Re-run `test-quality-gate-notation.sh` after any restore to confirm the pinned tripwires
  still read 11 and 21.
- **If Phase 1 or Phase 3 falsifies its Scope Hypothesis** (count is not 4, split is not 2+2, or
  post-fix count is >= 3): stop, revert any partial change, and report. Do not reach for a gate,
  exemption, or threshold change — routes (b) and (c) are closed decisions, and the correct next
  move is re-examining which pages need re-OCR and with what settings.
