# Implementation Summary: Task #107

- **Task**: 107 - Add an OCR-misrecognition detector to the literature quality gate
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T00:00:00Z
- **Completed**: 2026-09-02T01:50:00Z
- **Effort**: ~2 hours
- **Dependencies**: Task 102 (converter-tier characterization, COMPLETED), Task 104 (glue-check false-positive class, COMPLETED), Task 105 (OCR tier, COMPLETED)
- **Artifacts**: plans/01_ocr-misrecognition-detector.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

**The content-based OCR-misrecognition detector this task is titled after was not built — this
is a measured negative result, not a shortfall.** Research measured four progressively refined
content-based signal families (whole-document out-of-vocabulary rate, whole-document
mixed-alphanumeric-symbol density, prose-line-restricted anomaly rate, embedded-corruption-token
rate) against 11 known scan-pipeline corpus documents and 6 born-digital dense-math negative
controls. None separated the two groups at any threshold: a genuine Acrobat Image Conversion scan
(`blackburn_2002`) scored 15.69 hits/10k words while born-digital controls scored 153.95/10k
(`venema_2007`) and 306.22/10k (`ahrens_north`) — negative controls repeatedly outscored the real
positive by an order of magnitude. At the narrowest refinement round, `blackburn_2002` still
scored only 2.70/10k against `ahrens_north`'s 84.55/10k. Each refinement round closed exactly one
false-positive class (proper nouns; then typographic quotes; then citation-year author codes,
combining-mark diacritics, and LaTeX macro leakage; then em/en-dash and slash compounds and inline
HTML sub/superscript leakage) and exposed a different one.

Instead, this task implemented the provenance-only fallback the research recommended: a shared,
importable `scan_pipeline_provenance(creator, producer)` function in `literature_quality_gate.py`,
consumed by both `literature-fidelity-audit.sh` (replacing its own duplicated regex) and a new
non-blocking advisory in `literature-convert.sh`'s per-conversion quality gate. The negative
result and its full measured record are now written into repository documentation
(`literature-organization.md`), not left to live only in the task's own research report.

## What Changed

- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — added the module-level
  `_SCAN_PIPELINE_SIGNATURE_RE` constant and the `scan_pipeline_provenance(creator, producer)`
  function (byte-identical regex to the prior inline check), plus module-docstring paragraphs
  explaining its scope and the negative-result context. `sentence_boundary_glue_count()` was left
  byte-identical (confirmed via `git diff`).
- `agent-system/extensions/literature/scripts/literature-convert.sh` — added
  `scan_pipeline_provenance` to both the self-test and live heredoc import lists; added 9
  `gate_check` self-test fixtures (4 positive, 4 negative, 1 NUL-byte regression lock); added a
  non-blocking `ADVISORY:` stderr line to `run_quality_gate()` that reads `doc.metadata`
  defensively, never touches `reasons`, and names the existing `ocr_remedy_command()` remedy.
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — replaced the inline
  `SCAN_SOURCE_SIGNATURE_RE` constant and `scan_source_check()`'s duplicated logic with a plain,
  unguarded import of the shared function; updated the header docstring's signal-2 description to
  record the measured negative result instead of framing content-based detection as
  not-yet-built.
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` — added a
  `scan-metadata` fixture arm (`build_scan_metadata_pdf`): a clean text-layer PDF with
  scan-pipeline Creator/Producer metadata, isolating the advisory from every other gate check.
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` — added Test 7 (6
  assertions): the advisory fires with exit 0 and no `.rejected` on the scan-metadata fixture,
  stays silent on a born-digital fixture, and `literature-ingest.sh` bucketing is undisturbed.
  Confirmed the assertions are live (fail when the Phase 4 print statement is temporarily
  removed).
- `agent-system/extensions/literature/context/guides/literature-organization.md` — added a
  "Content-Based OCR-Misrecognition Detection: A Measured Negative Result" subsection recording
  the four signal families, the decisive numbers, and the false-positive class each round exposed.
- `agent-system/extensions/literature/context/project/literature/patterns/provenance-fidelity.md`
  — updated the scan-source-gate signal description to point at the shared function and summarize
  the negative result.
- `agent-system/extensions/literature/index-entries.json` — refreshed `line_count` for both edited
  context files (465, 136; verified against `wc -l`) and added keywords
  (`scan_pipeline_provenance`, `ocr-misrecognition`, `provenance-advisory`).

## Decisions

- The advisory is a `print(..., file=sys.stderr)` only — never appended to `reasons` — so it can
  never trip the exit-3 `QUALITY GATE FAILED` path, matching the plan's non-negotiable
  non-blocking requirement.
- The regex moved byte-identical (no widening beyond `capture|finereader|image conversion`); a
  wider match is a separate, unvalidated change deliberately kept out of scope.
- `literature-fidelity-audit.sh` imports `scan_pipeline_provenance` unguarded (not the
  try/except graceful-degrade pattern used for `literature_combining_detect`), because a silent
  import failure here would turn off the scan-source gate entirely and let scan-pipeline documents
  fall through to the certifying ratio branch — the wrong failure direction to make silent.
- A residual comment in `literature_quality_gate.py` (added in Phase 1) that literally named the
  old `SCAN_SOURCE_SIGNATURE_RE` symbol was rephrased in Phase 6 so the plan's literal
  `grep -rn 'SCAN_SOURCE_SIGNATURE_RE' agent-system/` verification check returns zero hits, not
  just "no functional duplicate."

## Plan Deviations

- None (implementation followed plan). The Phase 6 comment rephrasing above is a same-phase
  cleanup to satisfy the plan's own stated verification command, not a deviation from scope.

## Verification

- Build: N/A (bash/Python scripts, no build step)
- Tests: Passed — `literature-convert.sh --self-test` (all fixtures, including 9 new
  `gate/scan-pipeline-provenance-*` fixtures), `test-literature-convert.sh` (30/30, including 6
  new Test 7 advisory assertions, confirmed live), `test-quality-gate-notation.sh` (5/5),
  `test-literature-build-index.sh` (9/9)
- Files verified: Yes
- `literature-fidelity-audit.sh --dry-run` `unverified_scan_source` verdict count: 11 (matches the
  Phase 3 pre-edit baseline exactly — the move was behavior-preserving)
- `grep -rn 'SCAN_SOURCE_SIGNATURE_RE' agent-system/` returns zero hits
- `check-task-references.sh agent-system/extensions/literature/context` reports 0 unexempted
  occurrences
- `git status --short` carries no `.claude/**` paths

## Impacts

- Every future scan-pipeline conversion (11 of 74 corpus documents observed) now prints a
  distinctly-labeled `ADVISORY:` line recommending manual spot-check, without affecting exit
  code, `.rejected` output, or converter-tier selection.
- `literature-fidelity-audit.sh`'s scan-source gate now has exactly one implementation of its
  Creator/Producer signature, shared with the conversion pipeline, instead of two independently
  drifting copies.
- The negative result is now discoverable from repository documentation
  (`literature-organization.md`, `provenance-fidelity.md`) without needing to read this task's own
  research report, preventing a future contributor from re-deriving the same dead end.

## Follow-ups

- The one untried avenue — comparing the existing text layer against a fresh `ocrmypdf`/Tesseract
  pass on the same page images, which would sidestep the blind spot both existing engine tiers
  share (they read the same already-degraded `fitz`-extracted text layer) — remains unbuilt,
  deliberately, for cost reasons (a document-scale, minutes-long operation unsuited to the
  automatic per-conversion gate). If pursued, it belongs in an on-demand audit command, not this
  gate.

## References

- `specs/107_add_ocr_misrecognition_detector_to_quality_gate/plans/01_ocr-misrecognition-detector.md`
- `specs/107_add_ocr_misrecognition_detector_to_quality_gate/reports/01_ocr-misrecognition-detector.md`
- `agent-system/extensions/literature/context/guides/literature-organization.md` ("Content-Based
  OCR-Misrecognition Detection: A Measured Negative Result" subsection)
