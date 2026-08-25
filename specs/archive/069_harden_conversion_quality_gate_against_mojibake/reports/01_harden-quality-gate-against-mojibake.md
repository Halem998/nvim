# Research Report

**Task**: 69 - Harden conversion quality gate against mojibake/control-character corruption
**Started**: 2026-08-18
**Completed**: 2026-08-18
**Effort**: Medium (self-contained Python heredoc changes + test fixtures)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` (primary target)
- `agent-system/extensions/literature/scripts/literature-ingest.sh` (secondary — orchestrator)
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` (related, out-of-scope post-hoc tool)
- `agent-system/extensions/literature/scripts/literature_combining_overlay.py` (precedent for shared-module test pattern)
- `agent-system/extensions/literature/scripts/tests/{test-literature-convert.sh,generate-test-fixtures.py}`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `run_quality_gate()` (embedded Python heredoc in `literature-convert.sh:705-733`) currently
  runs exactly four checks — column-interleaving glue, sentence-boundary-glue count,
  one-sided page-coverage floor (`< 0.40`), and ligature/dehyphenation residue — and **none of
  them inspect the raw character content for control characters, NUL bytes, or non-printable
  garbage**. This is a real, confirmed gap, not a hypothetical: forcing the mandatory fallback
  tier on a broken-font-encoding PDF produced 4824 literal NUL bytes and thousands of
  glyph-index/control-character tokens that sailed through all four existing checks and were
  ingested into the corpus and FTS index.
- The `word_ratio 2.761 vs pdftotext` figure quoted by the team lead is **not** an existing
  automated signal inside `literature-convert.sh`'s gate — the gate's own coverage check
  (`page-coverage`, line ~725) computes `out_words / src_words` where `src_words` comes from
  `doc.get_text()` on the **same** PyMuPDF-opened, same-broken-font document, so numerator and
  denominator are correlated and a one-sided-to-two-sided widening of *that specific* metric is
  not guaranteed to have caught this failure mode (see Risks below). The 2.761 figure was
  computed against `pdftotext` — an independent extractor — which is the actual reason it
  diverged sharply. `literature-fidelity-audit.sh` is a **separate, post-hoc, batch corpus
  auditor** (not part of the real-time ingest gate) that already computes a word-ratio against
  `pdftotext -layout` (`RATIO_THRESHOLD = 0.75`, line 215) but only as a one-sided *floor* for
  detecting truncated/summarized conversions — it has no upper bound either, and it runs after
  ingestion, not before.
- Recommended fix, in priority order:
  1. **Printable-character-ratio check** on `content` directly (no second extraction tool
     needed) — catches control chars, unassigned codepoints, and PUA/glyph-index garbage in one
     signal.
  2. **NUL-byte / control-character zero-tolerance check** on `content` directly, following the
     codebase's existing "any occurrence is a defect" pattern (same shape as the ligature-scan
     and dehyphenation-check already in `run_quality_gate()`).
  3. **Two-sided band on the existing internal `page-coverage` metric** (`coverage < 0.40` ->
     also flag `coverage > <calibrated-upper-bound>`), added for defense-in-depth per the team
     lead's explicit request, with the caveat above about its likely reduced sensitivity for
     *this specific* font-corruption failure mode compared to (1) and (2).
- (1) and (2) are the checks that would have deterministically caught the Gabbay/Kurucz case,
  because they inspect the fallback tier's own output directly and require no second extraction
  tool or corpus-relative comparison.
- The fallback tier itself (`try_pymupdf_fallback()`) must NOT be removed or gated out — it
  correctly rescued Goldblatt 2006 in the same session (word_ratio 0.979 against pdftotext,
  clean 98-page conversion). The fix is entirely inside `run_quality_gate()`; no tier-selection
  logic needs to change.

## Context & Scope

Task 69 is one of three meta tasks (69, 70, 71) spawned from a real `/literature` session that
manually discovered and worked around a corpus-corruption defect. This report covers task 69
only: hardening `run_quality_gate()` in `literature-convert.sh` so that an unextractable/
broken-font-encoding PDF fails the gate on **every** tier (including the mandatory PyMuPDF
fallback), rather than passing on the fallback tier while the primary tier correctly rejects it.

Scope is deliberately narrow per the delegation: `literature-convert.sh` (where the actual
`run_quality_gate()` function lives) is the primary edit target; `literature-ingest.sh` is
listed as a secondary file but, per the code read below, requires no logic changes — it already
correctly separates exit-3 (`GATE_FAILED`) from other failures and just needs the gate itself to
fire.

## Findings

### Codebase Patterns

**Where the gate actually lives.** All four existing quality-gate checks are defined in one
Python heredoc inside `run_unified_engine()` (`literature-convert.sh:230-793`), executed via
`"$py_bin" << 'PYEOF' ... PYEOF`. The gate itself is `run_quality_gate(content, doc)` at line
705:

```python
def run_quality_gate(content, doc):
    reasons = []
    flagged, frac = column_interleaving_flagged(content)      # 4+-space glue heuristic
    ...
    glue_count = sentence_boundary_glue_count(content)          # zero-space word fusion
    ...
    src_words = sum(len(page.get_text().split()) for page in doc)
    out_words = len(content.split())
    coverage = (out_words / src_words) if src_words else 1.0
    if src_words > 0 and coverage < 0.40:                       # ONE-SIDED FLOOR ONLY
        reasons.append(...)
    ligature_count = len(re.findall(r"[ﬀ-ﬆ]", content))
    if ligature_count > 0:                                       # "any occurrence" pattern
        reasons.append(...)
    dehyph_count = len(re.findall(r"[a-z]-\n[a-z]", content))
    if dehyph_count > 0:                                          # "any occurrence" pattern
        reasons.append(...)
    return reasons
```

Any non-empty `reasons` list causes exit 3, writes `content` to `{doc_id}.md.rejected`, and
**never** writes the final `.md` (`literature-convert.sh:771-779`). This loud-failure contract
is already correct and does not need to change — only the set of checks feeding into
`reasons` needs to grow.

**`content` is a single Python `str`** at the point `run_quality_gate()` is called (from either
`try_pymupdf4llm()` or `try_pymupdf_fallback()`, both already normalized through
`normalize_document()`/`normalize_unit()`). This means a printable-ratio check and a
control-character check need no additional PDF access — they operate on `content` alone, unlike
the column-interleaving and coverage checks which also need `doc` (the fitz Document).

**The "any occurrence is a defect" pattern already exists** in this exact function (ligature-scan,
dehyphenation-check both use `if count > 0`), which is the right shape to reuse for a
zero-tolerance NUL/control-character check — no new stylistic pattern needs to be introduced.

**`unicodedata` is already imported** at the top of the heredoc (line ~262,
`import unicodedata`) but is currently unused by the gate itself (only referenced inside
`compose_combining_overlays()` via the shared module). It is directly usable for a
category-based printable check (`unicodedata.category(c)` in `{"Cc","Cs","Co","Cn"}` — control,
surrogate, private-use, unassigned) without adding a new import.

**Threshold-calibration convention**: every existing threshold in this file (`0.15` frac,
`1.5x` baseline length, `>=3` glue-count, `0.40` coverage) is justified in its own docstring or
inline comment with a citation to the *specific real corpus document* that motivated it (Alur
SyGuS, Goldblatt/Hodkinson/Venema 2003, Pym-O'Hearn-Yang 2004, Ishtiaq-O'Hearn 2001), not chosen
arbitrarily. Any new thresholds (printable-ratio floor, coverage-band upper bound) should follow
the same convention: calibrate against a small sample of known-good corpus files (the
`sentence_boundary_glue_count` docstring's "0-1 occurrences across a random sample of 60 real
corpus markdown files" is the closest precedent for how to do this) and cite the calibration
data point in a comment, plus explicitly verify against the two real cases already in evidence:
Gabbay/Kurucz 2003 (must fail) and Goldblatt 2006 (must still pass, word_ratio 0.979).

**`literature-ingest.sh` needs no logic change.** It calls `literature-convert.sh` per file,
checks the exit code explicitly (0 / 2 / 3, `literature-ingest.sh:206-221`), and already tracks
gate rejections in a distinct `GATE_FAILED` counter separate from hard failures
(`literature-ingest.sh:339,408-410`). Once `run_quality_gate()` correctly flags the corrupted
output as exit 3, `literature-ingest.sh`'s existing exit-code handling routes it to
`{doc_id}.md.rejected` and the "Files quality-gate-failed" counter automatically — no new code
path is required there. The team lead's inclusion of this file as a "primary file" is best read
as "verify it still behaves correctly," not "it needs new logic."

**`literature-fidelity-audit.sh` is a related but out-of-scope tool.** It independently computes
`word_ratio = md_words_total / pdf_words_total` using `pdftotext -layout` as ground truth
(`literature-fidelity-audit.sh:144,398-399`), gated by `RATIO_THRESHOLD = 0.75` as a **one-sided
floor** (`ratio >= RATIO_THRESHOLD` -> high fidelity, line 401) used for a completely different
purpose (detecting truncated/summarized `.md` relative to its source PDF, not detecting
mojibake/garbage). It runs post-hoc across the whole corpus (`--dry-run`/`--write`), not at
ingest time, and has no upper bound today either. Adding a symmetric upper-bound check there
would be a reasonable follow-up but is not part of the delegated file list and is not needed to
close the corpus-corruption vector at ingest time — `literature-convert.sh`'s gate is the only
component that can prevent ingestion in the first place.

### External Resources

Not applicable — this is a self-contained internal-heuristic problem specific to this corpus
pipeline's PyMuPDF-family output; no external library/documentation research was needed or
consulted beyond what's already cited in the existing docstrings (Unicode category semantics,
which are standard library behavior).

### Recommendations

1. **Add `printable_ratio_flagged(text)`** next to the other check functions
   (`literature-convert.sh:625-702` region), computing the fraction of characters in `content`
   that are NOT in Unicode categories `Cc` (control), `Cs` (surrogate), `Co` (private-use), or
   `Cn` (unassigned) — explicitly exempting `\t`, `\n`, `\r` from the "non-printable" bucket
   first (these are legitimate structural whitespace and would otherwise dominate the count and
   make the ratio meaningless for any normal document). Flag when the ratio falls below a
   calibrated floor. This directly targets glyph-index-as-codepoint corruption, which commonly
   lands in the Private-Use-Area (`Co`) or unassigned (`Cn`) ranges when a font has no usable
   ToUnicode CMap — exactly the Gabbay/Kurucz failure mode.

2. **Add a zero-tolerance NUL/control-character check** — count occurrences of `\x00` plus any
   other `Cc`-category character outside `{\t, \n, \r}` in `content`, and fail on `count > 0`,
   using the same "any occurrence is a defect" shape as the existing ligature-scan and
   dehyphenation-check. NUL bytes in extracted text have no legitimate provenance in this
   pipeline (confirmed: none of the four existing checks or the normalization pass are expected
   to introduce or need to tolerate them), so zero tolerance is safe and matches the observed
   defect (4824 NUL bytes) precisely.

3. **Widen the existing `page-coverage` check to a two-sided band**: keep `coverage < 0.40` as
   the floor, add `coverage > <upper-bound>` as a ceiling (candidate starting point: somewhere
   in the 2.0-3.0x range, but this MUST be calibrated against real corpus samples before
   committing to a number — do not guess a value into the implementation without verification).
   Flag this as **defense-in-depth, not the primary fix** — document in a comment (matching this
   file's citation convention) that this specific metric's numerator and denominator are both
   derived from PyMuPDF extraction of the same document, so a font-encoding corruption that
   corrupts both `content` and `doc.get_text()` similarly may not move this ratio as sharply as
   it moved the independent `content`-vs-`pdftotext` comparison the team lead computed manually.
   Checks (1) and (2) are the primary, tool-independent defenses; this one is a secondary
   safety net for other corruption shapes (e.g., a fallback-tier bug that inflates output word
   count without producing non-printable characters at all).

4. **Testability recommendation**: extract the quality-gate check functions (existing four plus
   the two/three new ones) into a shared, directly-importable module analogous to
   `literature_combining_overlay.py` — e.g. `literature_quality_gate.py` — imported by both the
   live heredoc (mirroring the existing `sys.path.insert(...); from literature_combining_overlay
   import compose_combining_overlays` pattern at `literature-convert.sh:266-267`) and a test
   harness. This matters specifically for checks (1) and (2): unlike column-interleaving and
   page-coverage, they need only a plain Python string (no PDF, no `fitz.Document`) to exercise,
   so they can be given direct unit tests with a string literal containing embedded NUL bytes or
   PUA codepoints — much easier than synthesizing a broken-font-encoding PDF fixture with
   `generate-test-fixtures.py`. This is the same shared-module pattern this codebase already
   uses for `--self-test` (`literature-convert.sh:73-160`), so it introduces no new pattern, only
   reuses an established one.

5. **Test fixtures**: add at minimum one new POSITIVE fixture (a `content` string with embedded
   `\x00` / PUA characters, expected to fail the gate with the new reason(s)) and re-verify the
   two real-world reference cases already in evidence do not regress: Gabbay/Kurucz 2003 must
   still be rejected (now for the new reasons, not just relying on manual `LITERATURE_CONVERTER`
   forcing to demonstrate it), and Goldblatt 2006 must still pass cleanly (word_ratio 0.979,
   symbols/footnotes preserved) — this is the explicit "do not disable the fallback tier"
   constraint made concrete as a regression test.

## Decisions

- Scope confirmed as `literature-convert.sh`'s `run_quality_gate()` and its helper functions;
  `literature-ingest.sh` requires no logic changes (verification only).
- `literature-fidelity-audit.sh`'s separate `word_ratio`/`RATIO_THRESHOLD` mechanism is
  explicitly out of scope for this task (different tool, different purpose, different
  trigger point) — noted as a possible independent follow-up, not bundled in.
- Recommend prioritizing printable-ratio and NUL/control-char checks over the coverage-band
  widening, since the former two are the checks with a clear causal path to catching the
  documented failure; the coverage band is included because the team lead explicitly requested
  it, but its effectiveness for this exact failure mode should not be overstated.

## Risks & Mitigations

- **Risk**: A printable-ratio or NUL-byte check could false-positive on a legitimate document
  that uses genuine Private-Use-Area codepoints by design (rare but real for some specialty math
  fonts with custom PUA-mapped symbols that DO have correct rendering intent).
  **Mitigation**: calibrate the printable-ratio floor generously below what real, correctly-
  extracted corpus documents measure (verify against a sample, not a guess), and treat the
  NUL-byte check as the highest-confidence zero-tolerance signal (NUL bytes have no legitimate
  use case in this pipeline) while keeping the printable-ratio check as a ratio/threshold rather
  than also zero-tolerance, so a handful of legitimate PUA symbols in an otherwise-clean document
  do not trip it.
- **Risk**: The coverage-band widening (recommendation 3) could false-positive on legitimate
  short-source, richly-expanded output (e.g., a slide-deck PDF with sparse per-page text but a
  markdown conversion that reasonably expands abbreviations/OCR artifacts) or false-negative on
  the exact case that motivated it, as discussed above.
  **Mitigation**: implement as defense-in-depth with a generously wide band, not a tight one;
  do not treat it as the sole or primary fix; document the numerator/denominator-correlation
  caveat inline so a future maintainer does not mistake it for a complete fix.
- **Risk**: Regression against the Goldblatt 2006 case (the explicit "must still pass" fixture) —
  any new check that is too aggressive silently removes the fallback tier's usefulness even
  without literally deleting code.
  **Mitigation**: treat Goldblatt's real word_ratio (0.979) and clean 98-page conversion as a
  hard regression-test gate on the implementation, not just a research-time data point.

## Context Extension Recommendations

- **Topic**: Quality-gate check function testability.
- **Gap**: No existing context doc describes the shared-module extraction pattern
  (`literature_combining_overlay.py` + `--self-test`) as a reusable convention for adding new
  string-only gate checks; it currently exists only as an implicit pattern in code.
- **Recommendation**: if this pattern is adopted for the new checks (recommendation 4 above),
  consider a short addition to `context/project/literature/patterns/` documenting "shared-module
  extraction for unit-testable heuristics" as a named pattern, so future gate checks (e.g. for
  tasks 70/71's sibling defects) follow it by convention rather than rediscovery. Not blocking
  for this task; can be captured during implementation as a light doc note if the planner judges
  it worthwhile.

## Appendix

### Search queries / exploration used

- `grep -n "word_ratio|quality.gate|sentence.boundary|glue|threshold|reject|printable|control.char|NUL" literature-convert.sh`
- `awk 'NR==600,NR==800'` / `sed -n` reads of `run_quality_gate()` and its four existing checks
- `grep -rn "word_ratio|pdftotext|printable|control.char|NUL" literature-ingest.sh` (confirmed:
  no gate logic lives here, only exit-code routing)
- `grep -n "RATIO_THRESHOLD|def |gate" literature-fidelity-audit.sh` (confirmed: separate
  post-hoc tool, one-sided floor only, `pdftotext -layout` ground truth)
- `grep -rln "isprintable|printable_ratio|control_char" scripts/*.sh scripts/*.py` (confirmed:
  no existing printable/control-char check anywhere in the extension)
- Read of `literature_combining_overlay.py` header and the `--self-test` branch
  (`literature-convert.sh:73-160`) for the shared-module/unit-test precedent
- `wc -l`, `find` for file inventory and test-harness structure
  (`scripts/tests/{test-literature-convert.sh,generate-test-fixtures.py}`)

### Key line references

- `literature-convert.sh:623-733` — full `run_quality_gate()` and its four existing checks
- `literature-convert.sh:705-733` — `run_quality_gate()` itself
- `literature-convert.sh:725-730` — the one-sided `page-coverage` floor to be widened
- `literature-convert.sh:771-779` — loud-failure contract (exit 3, `.rejected` write)
- `literature-convert.sh:266-267` — precedent for importing a shared checks module
- `literature-convert.sh:73-160` — `--self-test` precedent for string-only fixture testing
- `literature-ingest.sh:206-221,339,408-410` — exit-code routing (no changes needed)
- `literature-fidelity-audit.sh:144,215,398-401` — related but out-of-scope post-hoc word-ratio
  tool
