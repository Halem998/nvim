# Implementation Plan: Harden conversion quality gate against mojibake/control-character corruption

- **Task**: 69 - Harden literature conversion quality gate against mojibake and unextractable-PDF output
- **Status**: [NOT STARTED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: `specs/069_harden_conversion_quality_gate_against_mojibake/reports/01_harden-quality-gate-against-mojibake.md`
- **Artifacts**: plans/01_harden-quality-gate-against-mojibake.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`run_quality_gate()` in `agent-system/extensions/literature/scripts/literature-convert.sh` runs
four checks (column-interleaving, sentence-boundary glue, a one-sided page-coverage floor, and
ligature/dehyphenation residue), none of which inspects the raw character content. A PDF with a
broken/custom font encoding converted through the mandatory PyMuPDF fallback tier therefore
produced 4824 NUL bytes and thousands of glyph-index tokens, PASSED the gate, and entered the
global corpus and FTS index. This plan adds two content-inspecting checks (printable-character
ratio; zero-tolerance NUL/control-character count) plus a two-sided band on the existing
page-coverage metric, extracts the string-only gate checks into an importable module so the new
checks get real unit tests, and locks the behavior in with regression fixtures. Definition of
done: an unextractable PDF fails the gate on **every** tier, while Goldblatt 2006 (the case the
fallback tier legitimately rescued) still converts cleanly and every existing corpus document
still passes the new checks.

### Research Integration

Key findings carried into this plan:

- The gate lives entirely inside one Python heredoc in `run_unified_engine()`
  (`literature-convert.sh:230-793`); `run_quality_gate(content, doc)` is at `:705-733`. Only the
  set of checks feeding `reasons` needs to grow — the loud-failure contract (exit 3, write
  `{doc_id}.md.rejected`, never write the final `.md`, `:771-779`) is already correct.
- `content` is a plain Python `str` at gate time, so a printable-ratio check and a
  control-character check need no PDF access and no second extraction tool — they are directly
  unit-testable on string literals.
- `unicodedata` is already imported in the heredoc; category-based classification (`Cc`, `Cs`,
  `Co`, `Cn`) needs no new import.
- The `word_ratio 2.761` figure in the task description was computed against **pdftotext**, an
  independent extractor. It is NOT the gate's internal `page-coverage` metric, whose numerator
  and denominator both come from PyMuPDF extraction of the same broken-font document. Widening
  that internal metric to a two-sided band is therefore **defense-in-depth, not the primary
  fix**, and must be documented as such inline.
- The "any occurrence is a defect" shape (`if count > 0`) already exists in this function
  (ligature-scan, dehyphenation-check) and is the right shape to reuse for NUL/control chars.
- Every existing threshold in this file cites the specific real corpus document that motivated
  it. New thresholds must be calibrated against real corpus samples and cite their calibration
  data, never guessed.
- `literature-ingest.sh` needs **no logic change**: it already routes exit 3 to the distinct
  `GATE_FAILED` counter (`:206-221,339,408-410`). It is a verification target, not an edit
  target.
- `literature-fidelity-audit.sh`'s separate `RATIO_THRESHOLD` word-ratio mechanism is a
  post-hoc, whole-corpus tool and is explicitly out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` in the delegation context).

## Goals & Non-Goals

**Goals**:

- An unextractable/broken-font-encoding PDF fails `run_quality_gate()` on **every** engine tier,
  including the mandatory PyMuPDF fallback, and is written to `.md.rejected` rather than
  ingested.
- Add a printable-character-ratio check with a threshold calibrated against real corpus data.
- Add a zero-tolerance NUL/control-character check (`\x00` plus any other `Cc` outside
  `\t \n \r`).
- Convert the one-sided `page-coverage` floor into a two-sided band with a calibrated,
  generously wide upper bound, carrying an inline caveat about its correlated
  numerator/denominator.
- Make the string-only gate checks importable and unit-testable, reusing the existing
  `literature_combining_overlay.py` + `--self-test` shared-module pattern.
- Zero false positives across the existing corpus: all 40 documents currently under
  `~/Projects/Literature/` still pass the widened gate.

**Non-Goals**:

- Removing, disabling, or conditionally gating out the PyMuPDF fallback tier. Tier-selection
  logic in `try_pymupdf4llm()` / `try_pymupdf_fallback()` and the `LITERATURE_CONVERTER` mode
  handling are untouched.
- Any change to `literature-ingest.sh` logic (verification only).
- Adding an upper bound to `literature-fidelity-audit.sh`'s `RATIO_THRESHOLD` (separate tool,
  separate trigger point, possible independent follow-up).
- Re-converting or repairing already-ingested corpus documents.
- Introducing a second extraction tool (`pdftotext`) into the real-time ingest gate.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Printable-ratio check false-positives on a document with legitimate PUA-mapped math glyphs | H | M | Calibrate the floor generously below the measured minimum across all 40 real corpus documents (Phase 1); keep it a ratio threshold, never zero-tolerance; Phase 6 runs the check over the whole corpus and requires zero hits |
| Coverage-band ceiling false-positives on sparse-source/expanded output (slide decks, short pages) | M | M | Calibrate from the measured maximum across real corpus samples with generous headroom; implement as defense-in-depth with the correlation caveat documented inline; treat any Phase 6 corpus hit as a signal to widen, not to keep |
| Regression against Goldblatt 2006 — an over-aggressive check silently removes the fallback tier's usefulness without deleting any code | H | M | Goldblatt 2006 is a hard regression gate in Phase 6, not a research-time data point: it must convert cleanly on the fallback tier with symbols and footnotes preserved |
| The Gabbay/Kurucz 2003 source PDF is not locatable (it is not present under `~/Projects/Literature/`) so the must-fail case cannot be reproduced end-to-end | M | M | Phase 1 attempts to locate the source PDF and any surviving `.md.rejected`; if neither is available, Phase 5's synthetic NUL/PUA string fixture plus a generated broken-font PDF fixture becomes the must-fail evidence, and the substitution is recorded explicitly in the summary rather than passed off as the real case |
| Extracting checks into a module changes gate behavior inadvertently | H | L | Phase 2 is a pure move with no logic change; its verification is byte-identical gate output on a real conversion before and after |
| New module is not deployed because it is missing from the extension manifest | M | M | Manifest registration is an explicit Phase 2 task, verified by grepping `provides.scripts` |
| Edits land in `.claude/**` and are wiped by the next regeneration | H | L | All edits target `agent-system/extensions/literature/**` per `.claude/rules/source-store-deploy-boundary.md`; scripts are invoked from the source-store path directly for verification |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Calibrate thresholds against real corpus data [NOT STARTED]

**Goal**: Produce measured, citable numbers for the printable-character-ratio floor and the
page-coverage upper bound, so no threshold enters the implementation as a guess. This phase
writes no production code.

**Tasks**:
- [ ] Write a throwaway measurement script under the scratchpad (not under
      `agent-system/**`) that, for each document directory under `~/Projects/Literature/`,
      concatenates its `chunk_*.md` files and computes: total chars, count of `\x00`, count of
      `Cc` characters outside `{\t,\n,\r}`, count of `Cs`/`Co`/`Cn` characters, and the
      resulting printable ratio.
- [ ] Run it over all corpus documents; record the distribution (min, median, max printable
      ratio) and confirm the expected result that clean documents sit at or extremely near 1.0.
- [ ] Record the observed non-printable counts for `Cs`/`Co`/`Cn` separately from `Cc`, so the
      Phase 3 threshold can be set knowing whether any legitimate corpus document uses PUA
      codepoints at all.
- [ ] Measure the internal `page-coverage` ratio distribution: for a sample of at least 6 corpus
      documents whose source PDFs are still available, compute `out_words / src_words` using the
      same formulation as the existing check (`sum(len(page.get_text().split()) for page in
      doc)` vs `len(content.split())` on the converted markdown) and record min/max.
- [ ] Attempt to locate the Gabbay/Kurucz 2003 source PDF and any surviving `{doc_id}.md.rejected`
      (search `~/Projects/`, `~/Downloads/`, and Zotero storage). Record the outcome either way.
- [ ] If the Gabbay/Kurucz artifact is found, run the same measurement over it and record its
      printable ratio, NUL count, and coverage ratio — these are the must-FAIL data points.
- [ ] Measure the same metrics for Goldblatt 2006 (present at
      `~/Projects/Literature/goldblatt_-_mathematical_modal_logic_a_view_of_its_evolution/`) —
      these are the must-PASS data points.
- [ ] Write the measurements to
      `specs/069_harden_conversion_quality_gate_against_mojibake/calibration-notes.md` with the
      exact numbers, so Phases 3 and 4 can cite them in code comments.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes ~40 document directories under `~/Projects/Literature/`
and that Goldblatt 2006 is present while Gabbay/Kurucz 2003 is not. Confirm by listing the
corpus directory at implementation time; if the counts or presence differ, use the actual
inventory and record the discrepancy in the calibration notes rather than proceeding on the
assumed figures.

**Files to modify**:
- `specs/069_harden_conversion_quality_gate_against_mojibake/calibration-notes.md` - new;
  measured distributions and the must-pass/must-fail data points
- (scratchpad measurement script — not committed to `agent-system/**`)

**Verification**:
- `calibration-notes.md` exists and contains concrete numbers (not placeholders) for: printable-
  ratio min/median/max across the corpus, `Cs`/`Co`/`Cn` counts, page-coverage min/max, and the
  Goldblatt data points.
- A stated, justified candidate value for both new thresholds appears in the notes, each with
  explicit headroom below (printable-ratio floor) or above (coverage ceiling) the measured
  extreme.

---

### Phase 2: Extract string-only gate checks into an importable module [NOT STARTED]

**Goal**: Create `literature_quality_gate.py` alongside `literature_combining_overlay.py` and
move the existing string-only check functions into it, imported by the live heredoc. Pure
refactor: gate behavior must be identical before and after.

**Tasks**:
- [ ] Create `agent-system/extensions/literature/scripts/literature_quality_gate.py` with a
      module docstring following `literature_combining_overlay.py`'s convention (state that it is
      imported, never duplicated, by both the live pipeline and its self-test).
- [ ] Move `column_interleaving_flagged()` and `sentence_boundary_glue_count()` into the module
      verbatim, docstrings and threshold-justification comments intact.
- [ ] Add `ligature_residue_count(text)` and `dehyphenation_residue_count(text)` wrapping the two
      inline regexes currently in `run_quality_gate()`, so all string-only checks live in one
      place.
- [ ] In the heredoc, extend the existing import line pattern
      (`sys.path.insert(0, os.environ["LITERATURE_CONVERT_SCRIPT_DIR"])`) with
      `from literature_quality_gate import ...` and delete the moved definitions.
- [ ] Rewrite `run_quality_gate()` to call the imported functions; the `doc`-dependent
      page-coverage computation stays inline in the heredoc.
- [ ] Register `literature_quality_gate.py` in `provides.scripts` in
      `agent-system/extensions/literature/manifest.json`.
- [ ] Confirm no code comment introduced in this phase references a task number (per
      `.claude/rules/no-task-references-in-deliverables.md`); cite document names and
      filenames instead.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts the moved surface is exactly four functions
(`column_interleaving_flagged`, `sentence_boundary_glue_count`, and the two newly wrapped
residue counters) and that only `literature-convert.sh` imports them. Confirm at implementation
time with `grep -rn "column_interleaving_flagged\|sentence_boundary_glue_count"
agent-system/extensions/literature/`; if another consumer exists, update it in this phase and
report the wider scope.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` - new shared module
- `agent-system/extensions/literature/scripts/literature-convert.sh` - import the module; delete
  moved definitions; `run_quality_gate()` calls imported functions
- `agent-system/extensions/literature/manifest.json` - add the new script to `provides.scripts`

**Verification**:
- `python3 -c "import literature_quality_gate"` from the scripts directory succeeds.
- A real PDF conversion run through `agent-system/extensions/literature/scripts/literature-convert.sh`
  produces identical gate output (same PASS/FAIL, same reason strings, same metrics line) before
  and after the move — capture the stderr from a pre-refactor run for comparison.
- `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` still
  passes (existing combining-overlay fixtures unaffected).
- `grep -n literature_quality_gate agent-system/extensions/literature/manifest.json` matches.

---

### Phase 3: Add printable-ratio and NUL/control-character checks [NOT STARTED]

**Goal**: Implement the two primary, tool-independent defenses in
`literature_quality_gate.py` and wire them into `run_quality_gate()` using the Phase 1
calibrated threshold.

**Tasks**:
- [ ] Add `control_char_count(text)` to the module: count `\x00` plus every other
      `unicodedata.category(c) == "Cc"` character excluding `\t`, `\n`, `\r`. Docstring states
      that NUL bytes have no legitimate provenance in this pipeline, making zero tolerance safe.
- [ ] Add `printable_ratio(text)` to the module: exempt `\t`, `\n`, `\r` first, then compute the
      fraction of remaining characters NOT in categories `{"Cc","Cs","Co","Cn"}`. Return the
      ratio (and the non-printable count, for use in the reason string).
- [ ] Guard the empty/whitespace-only input case explicitly (return a ratio of 1.0 rather than
      dividing by zero) — the gate already rejects empty content upstream, but the module must
      be safe to unit-test with any string.
- [ ] Wire into `run_quality_gate()`: `control_char_count(content) > 0` appends a
      `control-character` reason naming the count; `printable_ratio(content)` below the
      calibrated floor appends a `printable-ratio` reason naming the ratio, the non-printable
      count, and the threshold. Match the existing reason-string style.
- [ ] Add a threshold-justification comment citing the Phase 1 calibration numbers by corpus
      document name (matching the file's existing citation convention: name the document, not a
      task number).
- [ ] State in the docstring/comment that these two checks target glyph-index-as-codepoint
      corruption, which lands in `Co` (PUA) or `Cn` (unassigned) when a font has no usable
      ToUnicode CMap.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` - add
  `control_char_count()` and `printable_ratio()`
- `agent-system/extensions/literature/scripts/literature-convert.sh` - call both from
  `run_quality_gate()`; add the calibrated constant and its justification comment

**Verification**:
- Ad-hoc Python check: a string containing `\x00` yields a non-zero `control_char_count`; a
  clean corpus document's concatenated markdown yields `control_char_count == 0` and a
  `printable_ratio` above the chosen floor.
- A clean real-PDF conversion still reports `Quality gate: PASSED`.
- A string built from PUA codepoints scores below the floor.

---

### Phase 4: Widen page-coverage into a two-sided band [NOT STARTED]

**Goal**: Add a calibrated upper bound to the existing coverage check as defense-in-depth, with
the correlation caveat documented inline so no future maintainer mistakes it for the primary
fix.

**Tasks**:
- [ ] Keep the existing `coverage < 0.40` floor untouched.
- [ ] Add `coverage > {calibrated_ceiling}` from Phase 1, generously above the measured corpus
      maximum. Append a distinct reason string naming the ratio, both bound values, and the word
      counts.
- [ ] Add an inline comment recording that the numerator (`content`) and denominator
      (`doc.get_text()`) are both PyMuPDF extractions of the same document, so a font-encoding
      corruption that corrupts both similarly may not move this ratio as sharply as the
      independent `content`-vs-`pdftotext` comparison did — this check is a secondary safety net
      for other corruption shapes, not the primary defense.
- [ ] Cite the calibration sample (by corpus document names) for the ceiling value, matching the
      file's convention.

**Timing**: 30 minutes

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes a single ceiling value suffices for the whole corpus
(no per-document-class banding). Confirm against the Phase 1 measured coverage distribution; if
the spread is wide enough that one generous ceiling would be vacuous, record that finding and
implement the widest defensible value rather than a tight one, noting the reduced sensitivity in
the inline comment.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` - two-sided coverage band
  in `run_quality_gate()` plus caveat comment

**Verification**:
- A clean real conversion still passes (coverage inside the band).
- A synthetic check confirms the ceiling branch fires when `out_words / src_words` exceeds it.
- The caveat comment is present and names the correlated-numerator/denominator limitation
  explicitly.

---

### Phase 5: Unit-test fixtures for the new checks [NOT STARTED]

**Goal**: Give the new string-only checks direct, hermetic unit tests using the established
`--self-test` pattern, plus a positive PDF-level fixture where feasible.

**Tasks**:
- [ ] Extend `literature-convert.sh`'s `--self-test` branch (or add a parallel
      `--gate-self-test` branch following the same shape) that imports
      `literature_quality_gate` and exercises the new functions on string literals.
- [ ] Add fixtures: embedded `\x00` (must be flagged, count > 0); other `Cc` control characters
      (flagged); `\t`/`\n`/`\r` only (must NOT be flagged); a PUA-heavy string (printable ratio
      below floor); a clean prose+math string (ratio at or near 1.0, passes); an empty string
      (no crash).
- [ ] Add fixtures for the moved functions confirming the Phase 2 refactor preserved behavior
      (at minimum one known-flagging and one known-clean input for
      `sentence_boundary_glue_count`, including its `Ph.D.` and binder exemptions).
- [ ] Wire the new self-test invocation into
      `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` so it runs
      as part of the suite, following that file's `t_pass`/`t_fail` conventions.
- [ ] If a broken-font PDF fixture is cheaply constructible with PyMuPDF, add a
      `broken-font-encoding` generator to `tests/generate-test-fixtures.py` and assert the gate
      rejects it (exit 3) on **both** `LITERATURE_CONVERTER=pymupdf4llm` and
      `LITERATURE_CONVERTER=pymupdf`. If it is not cheaply constructible, skip it with a visible
      warning (matching the existing `LITERATURE_TEST_PDF` skip convention) and say so in the
      summary — do not silently omit it.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` - self-test fixtures for the
  new checks
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` - invoke the new
  self-test
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` - optional
  broken-font fixture generator

**Verification**:
- `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` exits 0
  with all fixtures reported PASS.
- `bash agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` exits 0;
  any skipped optional check prints a visible warning rather than passing silently.

---

### Phase 6: Regression and end-to-end verification [NOT STARTED]

**Goal**: Prove the two hard constraints — garbage fails on every tier, and the fallback tier
still rescues what it legitimately rescued — and confirm `literature-ingest.sh` needs no change.

**Tasks**:
- [ ] Run the new checks over every document under `~/Projects/Literature/` (reusing the Phase 1
      measurement harness against the final thresholds). Require **zero** false positives; if any
      document trips a check, determine whether it is a real latent corruption or a
      miscalibration, and record the determination.
- [ ] Goldblatt 2006 must-pass regression: reconvert its source PDF (to a scratch directory
      only — never into the corpus) forcing `LITERATURE_CONVERTER=pymupdf`, and confirm the gate
      PASSES with symbols and footnotes preserved. If the source PDF is unavailable, run the
      checks against the existing corpus markdown and record that the end-to-end reconversion
      could not be performed.
- [ ] Must-fail regression: using the Gabbay/Kurucz artifact if Phase 1 located it, otherwise the
      Phase 5 synthetic fixture, confirm the gate FAILS with the new reasons under
      `LITERATURE_CONVERTER=pymupdf4llm`, `LITERATURE_CONVERTER=pymupdf`, and the default `auto`
      mode — i.e. on every tier.
- [ ] Confirm the failure path writes `{doc_id}.md.rejected` and does NOT write the final `.md`.
- [ ] Verify `literature-ingest.sh` requires no change: read its exit-code routing
      (`:206-221`) and `GATE_FAILED` accounting (`:339,408-410`), then run an ingest over a
      scratch directory containing one known-bad file and confirm the run reports
      "Files quality-gate-failed: 1" and does not add the document to the index.
- [ ] Confirm the fallback tier itself is untouched: `git diff` on `literature-convert.sh` shows
      no change inside `try_pymupdf_fallback()`, `try_pymupdf4llm()`, or the tier-selection
      block.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts zero false positives across the corpus at the chosen
thresholds. That is a hypothesis, not a fact — it is confirmed by actually running the sweep. A
non-zero result is a finding to investigate and report, not a reason to loosen the threshold
reflexively.

**Files to modify**:
- None expected; threshold adjustments in
  `agent-system/extensions/literature/scripts/literature-convert.sh` only if the corpus sweep
  surfaces a justified miscalibration

**Verification**:
- Corpus sweep output showing 0 flagged documents (or a recorded, reasoned exception).
- Recorded gate output for the must-pass case (PASSED) and the must-fail case (exit 3 with the
  new reasons) under all three converter modes.
- Ingest run showing "Files quality-gate-failed: 1" and no index entry for the bad file.
- `git diff` confirming the fallback-tier functions are unmodified.

---

### Phase 7: Document the shared-module check pattern [NOT STARTED]

**Goal**: Capture the shared-module extraction convention so future gate checks follow it by
convention rather than rediscovery.

**Tasks**:
- [ ] Add a short pattern note under
      `agent-system/extensions/literature/context/project/literature/patterns/` describing
      "shared-module extraction for unit-testable gate heuristics": when a check needs only a
      string, put it in an importable module and give it `--self-test` fixtures; when it needs a
      `fitz.Document`, it stays inline in the heredoc.
- [ ] Reference both `literature_combining_overlay.py` and `literature_quality_gate.py` as the
      two live instances of the pattern.
- [ ] Register the new context file in the extension manifest if that directory's files are
      manifest-listed (check `provides.context` before assuming).
- [ ] Confirm the note cites durable anchors (filenames, function names) and no task numbers.

**Timing**: 30 minutes

**Depends on**: 6

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/patterns/{new-note}.md` - new
- `agent-system/extensions/literature/manifest.json` - context registration if required by that
  manifest's convention

**Verification**:
- The note exists, is under 100 lines, and names both live instances of the pattern.
- `bash .claude/scripts/check-task-references.sh` (or equivalent lint) reports no task-number
  reference in the new file.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/literature/scripts/literature-convert.sh --self-test` exits 0
      (existing combining-overlay fixtures plus new gate fixtures).
- [ ] `bash agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` exits 0.
- [ ] A clean real-PDF conversion reports `Quality gate: PASSED` and produces the expected
      metrics line.
- [ ] The must-fail case exits 3 under `auto`, `pymupdf4llm`, and `pymupdf` converter modes, and
      writes only `.md.rejected`.
- [ ] Corpus sweep over all documents under `~/Projects/Literature/` flags zero documents.
- [ ] Goldblatt 2006 still passes the gate on the fallback tier.
- [ ] `literature-ingest.sh` reports the rejection in its `GATE_FAILED` counter with no code
      change.
- [ ] No file under `.claude/**` was edited (`git status` shows changes only under
      `agent-system/extensions/literature/**` and `specs/**`).

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature_quality_gate.py` (new shared module)
- Modified `agent-system/extensions/literature/scripts/literature-convert.sh` (new checks,
  two-sided coverage band, self-test fixtures)
- Modified `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh`
- Possibly modified `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py`
- Modified `agent-system/extensions/literature/manifest.json` (script and possibly context
  registration)
- New pattern note under
  `agent-system/extensions/literature/context/project/literature/patterns/`
- `specs/069_harden_conversion_quality_gate_against_mojibake/calibration-notes.md`
- `specs/069_harden_conversion_quality_gate_against_mojibake/summaries/01_*-summary.md`

## Rollback/Contingency

- All changes are confined to `agent-system/extensions/literature/**`; reverting is a
  `git revert` of the task's phase commits. `.claude/**` is a regenerated deploy artifact and
  holds no hand-authored state to unwind.
- If a threshold proves too aggressive after landing (a legitimate document rejected in real
  use), the rejected output is preserved at `{doc_id}.md.rejected` — no data is lost, and the
  fix is a threshold widening in one constant plus an updated calibration citation, not a
  revert.
- If the Phase 2 refactor is implicated in any behavior change, Phases 3-4 can be re-applied on
  top of the pre-refactor inline structure (the checks themselves do not depend on the module
  extraction); only testability is lost.
- The fallback tier is never modified, so no rollback path involves restoring conversion
  capability.
