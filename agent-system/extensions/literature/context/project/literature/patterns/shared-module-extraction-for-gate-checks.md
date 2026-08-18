# Shared-Module Extraction for Unit-Testable Gate Heuristics

`literature-convert.sh` runs its conversion and quality-gate logic inside a single Python
heredoc per invocation (`run_unified_engine()`). A heredoc body cannot be `import`ed or unit
tested directly, so any check or transform living only inside it can only be exercised by
running an actual PDF conversion — expensive, and blind to the check's own edge cases.

## The pattern

When a check or transform needs only a plain string (no `fitz.Document`/PDF access), extract it
into its own importable module alongside `literature-convert.sh`, following this shape:

1. Give the function(s) a clear docstring stating WHY the check/transform exists, citing the
   real corpus document(s) or corpus-wide measurement that motivated it — never a guessed
   threshold. See `literature_quality_gate.py`'s `printable_ratio`/`control_char_count`
   docstrings for the convention: state the calibration data, not just the formula.
2. Import the module from the live heredoc via the existing
   `sys.path.insert(0, os.environ["LITERATURE_CONVERT_SCRIPT_DIR"])` pattern, so the live
   pipeline and its self-test share exactly one definition — never two hand-maintained copies
   that could drift.
3. Add fixtures to `literature-convert.sh --self-test` (the shared fixture-based entry point)
   importing the module directly and asserting on known-flagging and known-clean inputs, plus
   any documented edge case (e.g. the empty-string case).
4. Register the new module in `manifest.json`'s `provides.scripts` list so it deploys alongside
   `literature-convert.sh`.

When a check DOES need the source `fitz.Document` (e.g. the page-coverage check, which computes
`sum(len(page.get_text().split()) for page in doc)`), it stays inline in the heredoc — the
pattern is for string-only logic specifically, not a mandate to extract everything.

## Live instances of this pattern

- `literature_combining_overlay.py` — `compose_combining_overlays()`, the combining-mark
  reorder/composition logic (imported by both the live normalization path and its own
  `--self-test` fixtures).
- `literature_quality_gate.py` — the quality-gate's string-only checks:
  `column_interleaving_flagged`, `sentence_boundary_glue_count`, `ligature_residue_count`,
  `dehyphenation_residue_count`, `control_char_count`, `printable_ratio`. The first two were
  moved here verbatim from an earlier in-heredoc definition (a pure refactor, verified
  byte-identical gate output before/after); the last two are new checks added to catch
  glyph-index-as-codepoint corruption (broken/custom PDF font encodings) that reaches the gate
  as NUL bytes or other non-printable Unicode categories.

## A worked calibration lesson from `literature_quality_gate.py`

The original task text proposing `control_char_count` specified a single zero-tolerance check
covering NUL plus every other `Cc` character outside `\t`/`\n`/`\r`. Real-corpus measurement
(concatenating every document's `chunk_*.md` files and classifying every character by
`unicodedata.category()`) found that roughly half the live corpus legitimately uses low-range
`Cc` codepoints as a systemic glyph-substitute for math symbols under a partial/broken
`ToUnicode` CMap — manually spot-checked clean, not corruption. A blanket zero-tolerance version
of the check would have failed roughly half the existing corpus.

The fix: split the check by real evidence, not the literal originally-proposed wording. NUL
specifically stayed zero-tolerance (verified safe: zero occurrences across the corpus except one
already-known, already-ingested defect). The broader non-printable-category count was folded
into a ratio-based check (`printable_ratio`) with a floor calibrated well below the real
corpus's measured minimum instead. **Any new gate threshold should be calibrated the same
way**: measure the real corpus first, and let the measurement — not the first draft of the
check's wording — decide the final shape of the threshold.
