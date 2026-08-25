# Implementation Summary: Task #69

- **Task**: 69 - Harden literature conversion quality gate against mojibake and unextractable-PDF output
- **Status**: [COMPLETED]
- **Started**: 2026-08-18
- **Completed**: 2026-08-18
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_harden-quality-gate-against-mojibake.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Hardened `run_quality_gate()` in `literature-convert.sh` with two new content-inspecting checks
(a zero-tolerance NUL-byte check and a calibrated printable-character-ratio floor) plus a
two-sided band on the existing page-coverage metric, and extracted every string-only gate check
into a new importable module (`literature_quality_gate.py`) with `--self-test` unit fixtures.
Every threshold is calibrated against a real measurement sweep of the live 40-document corpus at
`~/Projects/Literature/` (recorded in `calibration-notes.md`), not guessed. The PyMuPDF fallback
tier is completely untouched (verified via `git diff`), and Goldblatt 2006 — the document that
tier legitimately rescued — still converts cleanly and passes every new check.

## What Changed

- `agent-system/extensions/literature/scripts/literature_quality_gate.py` — new shared module.
  Houses every string-only gate check: `column_interleaving_flagged` and
  `sentence_boundary_glue_count` (moved verbatim from the heredoc, pure refactor, verified
  byte-identical gate output before/after), `ligature_residue_count` and
  `dehyphenation_residue_count` (new wrappers around the two regexes that used to be inline),
  and the two new checks `control_char_count` (NUL-byte zero-tolerance) and `printable_ratio`
  (calibrated-floor ratio over `Cc`/`Cs`/`Co`/`Cn` non-printable categories).
- `agent-system/extensions/literature/scripts/literature-convert.sh` — imports the new module in
  both the live `run_unified_engine()` heredoc and the `--self-test` heredoc; `run_quality_gate()`
  now also runs the NUL check (any occurrence fails), the printable-ratio check (floor 0.85), and
  a page-coverage ceiling (2.5) alongside the existing floor (0.40), with an inline caveat
  documenting that the coverage ceiling is defense-in-depth, not the primary fix (numerator and
  denominator are correlated PyMuPDF extractions of the same document). Extended `--self-test`
  with 12 new gate fixtures.
- `agent-system/extensions/literature/manifest.json` — registered `literature_quality_gate.py` in
  `provides.scripts`.
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` — added
  `build_broken_font_pdf()` (a `broken-font` fixture kind simulating glyph-index-as-codepoint
  corruption via literal control characters that survive PyMuPDF's own text extraction intact).
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` — wired
  `literature-convert.sh --self-test` into the suite (Test 4) and added the broken-font-encoding
  must-fail regression on the fallback tier (Test 5), with a documented, visible warning for the
  primary-tier limitation (see Plan Deviations).
- `agent-system/extensions/literature/context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`
  — new pattern note documenting the shared-module convention and the calibration lesson from
  this task (measure the real corpus before finalizing a threshold's shape, not just its value).
- `specs/069_harden_conversion_quality_gate_against_mojibake/calibration-notes.md` — new; the
  full real-corpus measurement (printable-ratio distribution, NUL/Cc/Cs/Co/Cn counts,
  page-coverage data points, Goldblatt must-pass evidence, Gabbay/Kurucz location attempt and
  substitution).

## Decisions

- **NUL (`\x00`) is zero-tolerance; the broader `Cc` control range is not** — see Plan
  Deviations below. This is the single most consequential decision in this task: the plan's
  literal Phase 3 wording ("`\x00` plus any other `Cc`") would have failed roughly half the real
  corpus if implemented as written.
- **printable_ratio floor: 0.85** — ~8.1 points of headroom below the real measured corpus
  minimum (0.931404, `reynolds_2002_axioms_for_branching_time`).
- **page-coverage ceiling: 2.5** — over 6x further from 1.0 than either real measured data point
  (0.99986 and 1.00143).
- Used the real already-ingested `pym_ohearn_yang_2004_possible-worlds-resources-bi` document
  (1352 real NUL bytes, discovered via a full-corpus NUL sweep during Phase 1) as the primary
  must-flag evidence, since the task's originally-cited Gabbay/Kurucz 2003 source PDF was not
  locatable. This is real, already-in-the-live-corpus evidence rather than a purely synthetic
  substitute, and it directly validates the new NUL check: `control_char_count()` correctly
  flags it (1352), while it stays above the printable-ratio floor (0.944) — confirming the two
  checks target genuinely different corruption shapes, as designed.

## Plan Deviations

- **Task 1.4** (page-coverage sample size): altered — only 2 of ~40 corpus documents had
  locatable source PDFs within the task's time budget (target was ≥6); used the 2 available real
  data points instead of fabricating more.
- **Task 1.5/1.6** (locate Gabbay/Kurucz 2003): skipped — not locatable; substituted the real
  already-ingested `pym_ohearn_yang_2004_possible-worlds-resources-bi` NUL-corrupted document as
  must-flag evidence instead (see calibration-notes.md).
- **Task 3.1** (`control_char_count` scope): altered — counts `\x00` only, not every non-NUL
  `Cc`. Real-corpus calibration found 19 of 38 measured documents legitimately use low-range
  `Cc` codepoints (up to 17299 occurrences) as a benign glyph-substitute convention for math
  symbols under this corpus's PDF toolchain; a blanket zero-tolerance `Cc` check would have
  failed roughly half the existing corpus, directly violating this plan's own goal that all 40
  corpus documents keep passing. The broader non-printable-category count is folded into
  `printable_ratio()`'s calibrated-floor check instead. Full justification and evidence in
  calibration-notes.md's "Calibration-driven deviation" section.
- **Task 5.4 / 6.3 / Testing checklist** (must-fail on every tier): altered — the synthetic
  `broken-font` fixture fails reliably on the fallback tier (`LITERATURE_CONVERTER=pymupdf`) but
  PASSES under `pymupdf4llm` and `auto` (which selects `pymupdf4llm` on this machine).
  `pymupdf4llm.to_markdown()` was found to apply its own heuristic character-substitution cleanup
  (digit swaps, stray substitute glyphs) that sanitizes this specific `insert_text()`-constructed
  fixture before it reaches the gate — confirmed NOT to be an extraction-level difference
  (`page.get_text("dict")` preserves the literal control characters intact; the divergence is in
  `to_markdown()`'s own post-processing). The "fails on every tier" property for GENUINE
  corruption remains a structural guarantee: `run_quality_gate()` has exactly one call site in
  `run_unified_engine()`, applied unconditionally to whichever tier's `content` was produced —
  any content containing a real NUL byte or falling below the printable-ratio floor fails
  regardless of which tier produced it. This is anchored by real evidence, not just code
  inspection: the already-ingested `pym_ohearn` document's 1352 real NUL bytes reached final
  gate-time content in the live pipeline (whichever tier actually processed it, pre-hardening),
  and the new checks correctly flag that real text when applied directly. The primary-tier gap
  is a limitation of this cheap synthetic-fixture reproduction technique, not of the gate logic,
  and is documented with a visible warning in `test-literature-convert.sh` rather than silently
  omitted, per the plan's own escape hatch for this exact scenario.
- **Corpus sweep "zero documents flagged"**: altered — 1 of 34 documents with chunk content
  flags (the `pym_ohearn` document above), correctly so per its real corruption, not a
  miscalibration. Zero false positives among the other 33.

## Verification

- Build: N/A (bash/Python scripts, no build step)
- Tests: Passed — `literature-convert.sh --self-test` (26 fixtures, exit 0);
  `tests/test-literature-convert.sh` (13 passed, 0 failed, exit 0)
- Files verified: Yes — module imports cleanly, manifest is valid JSON, `check-task-references.sh`
  reports 0 unexempted occurrences across all touched trees

Additional verification performed:
- Goldblatt 2006 forced-fallback-tier reconversion: `Quality gate: PASSED`, words=49168, output
  byte-identical to the pre-Phase-2-refactor baseline.
- Corpus sweep (34 documents with chunk content): 1 flagged (real defect), 0 false positives.
- End-to-end `literature-ingest.sh` run over a scratch `LITERATURE_DIR` with one bad + one good
  fixture: `Files quality-gate-failed: 1`, `index.json` contains only the good document, zero
  code changes to `literature-ingest.sh`.
- `git diff` on `literature-convert.sh`: no changes inside `try_pymupdf_fallback()`,
  `try_pymupdf4llm()`, `derive_toc_markdown()`, `derive_heuristic_markdown()`,
  `order_blocks_by_column()`, or the tier-selection block.

## Impacts

- Any future PDF that produces NUL bytes or falls below the printable-character floor on ANY
  engine tier will now be rejected (exit 3, `.rejected` sibling written) rather than silently
  entering the corpus and FTS index.
- The already-ingested `pym_ohearn_yang_2004_possible-worlds-resources-bi` document remains in
  the live corpus with its 1352 real NUL bytes — re-converting/repairing it was an explicit
  Non-Goal of this plan. It would now be caught if re-ingested.
- `literature-fidelity-audit.sh`'s separate `RATIO_THRESHOLD` mechanism is untouched, as scoped.

## Follow-ups

- Consider re-ingesting `pym_ohearn_yang_2004_possible-worlds-resources-bi` through the hardened
  gate (would now be rejected) and either sourcing a clean reconversion or manually repairing the
  NUL markers — out of scope for this task per its Non-Goals, flagged here for a possible
  follow-up.
- The `pymupdf4llm`-tier gap in the synthetic `broken-font` fixture (see Plan Deviations) means
  this specific fixture cannot regression-lock the primary tier's behavior against genuine
  control-character corruption; if a real broken-font-encoding source PDF is ever located (e.g.
  the original Gabbay/Kurucz 2003 case), it should replace or supplement this fixture for a
  stronger primary-tier regression lock.
- Other agents were observed concurrently modifying
  `agent-system/extensions/literature/commands/literature.md`,
  `specs/070_fix_discover_tier_starvation_and_silent_tier3_failure/plans/01_fix-discover-tier-starvation.md`,
  and `specs/events.jsonl` during this task's execution (visible in `git status` at completion
  time) — unrelated to this task's scope, not touched or staged by this implementation, noted
  here per the observation-duty contract.

## References

- `specs/069_harden_conversion_quality_gate_against_mojibake/plans/01_harden-quality-gate-against-mojibake.md`
- `specs/069_harden_conversion_quality_gate_against_mojibake/reports/01_harden-quality-gate-against-mojibake.md`
- `specs/069_harden_conversion_quality_gate_against_mojibake/calibration-notes.md`
