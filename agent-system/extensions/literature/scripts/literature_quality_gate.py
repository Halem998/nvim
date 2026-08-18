"""literature_quality_gate.py - shared, string-only quality-gate check functions.

Every check in this module operates on a plain Python `str` and needs no PDF
access (`fitz.Document`) at all -- the page-coverage check in
`run_quality_gate()` (`literature-convert.sh`) is the one gate check that DOES
need the source `fitz.Document` and stays inline in that heredoc for that
reason. This module is imported (never duplicated) by both `literature-convert.sh`
(the live conversion pipeline) and its own fixture self-test
(`--self-test`/`--gate-self-test`), following the same shared-module pattern as
`literature_combining_overlay.py`, so a change to a threshold or regex can
never silently drift between the live path and its test.

Two functions (`column_interleaving_flagged`, `sentence_boundary_glue_count`)
were moved here verbatim from `literature-convert.sh` as a pure refactor with
no behavior change. `ligature_residue_count` and `dehyphenation_residue_count`
wrap the two inline regexes that previously lived directly in
`run_quality_gate()`, so every string-only check now lives in one place.
`control_char_count` and `printable_ratio` are new checks added to catch
glyph-index-as-codepoint corruption (broken/custom PDF font encodings) that
reaches the gate as NUL bytes or other non-printable Unicode categories --
see `printable_ratio`'s docstring for why the general non-printable count is
NOT zero-tolerance the way NUL is, despite the plan text this module was
originally scoped against literally proposing that shape. That deviation, and
the corpus measurements behind it, are recorded in this task's
calibration-notes.md artifact rather than only here.
"""

import re
import unicodedata

# Categories folded into `printable_ratio()`'s non-printable count: Cc
# (control, excluding the three exempted whitespace characters), Cs
# (surrogate -- never valid in well-formed text), Co (private-use area --
# a legitimate glyph-index fallback IN SMALL DOSES, see the module docstring
# above and the module-level NOTE below), Cn (unassigned codepoint).
_NONPRINTABLE_CATEGORIES = {"Cc", "Cs", "Co", "Cn"}

# Characters exempted from both the control-character and printable-ratio
# checks: normal text-structure whitespace, not corruption.
_EXEMPT_WHITESPACE = "\t\n\r"


def column_interleaving_flagged(text):
    lines = [l for l in text.split("\n") if l.strip()]
    if not lines:
        return False, 0.0
    glue_re = re.compile(r"\S\s{4,}\S")
    glued = [l for l in lines if glue_re.search(l)]
    non_glued = [l for l in lines if not glue_re.search(l)]
    frac = len(glued) / len(lines)
    avg_glued_len = (sum(len(l) for l in glued) / len(glued)) if glued else 0

    # Baseline for "conspicuously long": the median length of the NON-glued
    # lines specifically, not all lines. Comparing against the whole
    # document's median fails on the exact worst-case (and most important)
    # scenario this check exists to catch: when column-gluing affects the
    # MAJORITY of a document, glued lines themselves dominate the overall
    # median, so "avg glued length > 1.5x overall median" can never fire —
    # empirically verified against the real corrupted Alur SyGuS corpus
    # document, which the document-wide-median formulation
    # failed to flag (79% of lines glued, yet ratio stayed ~1.0x). Falling
    # back to the whole-document median only when every line is glued (no
    # non-glued baseline exists at all).
    baseline_lengths = non_glued if non_glued else lines
    baseline_sorted = sorted(len(l) for l in baseline_lengths)
    baseline_len = baseline_sorted[len(baseline_sorted) // 2] if baseline_sorted else 0

    long_enough = baseline_len > 0 and avg_glued_len > 1.5 * baseline_len
    return (frac > 0.15 and long_enough), frac


def sentence_boundary_glue_count(text):
    """Secondary word-fusion signal, added during test-harness verification.
    Deliberately period-ONLY (`[a-z]\\.[A-Z]`),
    NOT comma/semicolon: an earlier comma/semicolon-inclusive version was
    empirically found to false-positive heavily on legitimate math tuple/
    list notation (`(x,Y)`, `a,B,c` are extremely common in this math-heavy
    corpus and are not defects).

    Found via a REAL corpus PDF, not a synthetic fixture (a synthetic
    two-column fixture also seemed to trigger this during early Phase 6
    testing, but that turned out to be an artifact of an unrealistic first
    version of the fixture — see generate-test-fixtures.py's docstring —
    and no longer reproduces once the fixture uses column-width-constrained
    wrapped text like a real PDF): pymupdf4llm was observed to drop
    inter-word spaces entirely around some `<sup>`/`<sub>` markdown spans on
    Goldblatt/Hodkinson/Venema 2003 (a real corpus document, read via a
    fresh in-process conversion, never by reading/reconverting the corpus
    itself), producing fused runs like "Thesecondlinefollowsby" — a
    genuine, previously-undetected correctness defect this check catches.
    Verified at 0-1 occurrences across a random sample of 60 real corpus
    markdown files (read-only, not reconverted) with the period-only
    pattern; the threshold below (>=3) sits well above that baseline.

    Two further benign patterns are exempted BEFORE counting, both found via
    real corpus PDFs during Logos/Theory corpus building:
      - `Ph.D.` / `Ph.D` in bibliography entries (the `h.D` transition) —
        e.g. Pym-O'Hearn-Yang 2004 "Possible Worlds and Resources", rejected
        at exactly 4 hits, all `Ph.D.` in the bibliography.
      - Single-letter-variable quantifier/binder notation such as `∀x.P`,
        `∃x.P`, `∃y.E` (the `{var}.{Upper}` transition immediately preceded
        by a `∀`/`∃`/`λ` binder) — e.g. Ishtiaq-O'Hearn 2001 "BI as an
        Assertion Language", rejected at 7 hits (5 quantifier notation, 2
        Ph.D.). Both conversions were otherwise clean and were manually
        promoted from rejected_path before this fix.

    Exemption is applied by stripping the exempted substrings first, THEN
    counting on what remains — not a negative lookbehind — since the
    exemption spans (`Ph.D`, `{binder}{var}.{Upper}`) each fully contain the
    raw 3-character match span they exempt, making a strip-first pass exact
    and avoiding Python re's fixed-width-lookbehind constraint.

    The binder class is deliberately narrow — the binder character must be
    immediately adjacent to a single lowercase variable — so a bare
    single-letter-then-period-then-capital transition with no binder prefix
    is still counted."""
    exempted = re.sub(r"Ph\.D\.?", "", text)
    exempted = re.sub(r"[∀∃λ][a-z]\.[A-Z]", "", exempted)
    return len(re.findall(r"[a-z]\.[A-Z]", exempted))


def ligature_residue_count(text):
    """Count unresolved U+FB00-FB06 Latin ligature codepoints. Wraps the
    regex previously inline in `run_quality_gate()`; `normalize_unit()`'s
    `fold_ligatures()` step (in `literature-convert.sh`) is expected to have
    already folded these on the primary tier, so any survivor here means
    normalization never ran over that span (e.g. the fallback tier's
    heuristic path) or the LIGATURE_MAP is missing an entry."""
    return len(re.findall(r"[ﬀ-ﬆ]", text))


def dehyphenation_residue_count(text):
    """Count unresolved `word-\\nword` hyphen-linebreak pairs. Wraps the
    regex previously inline in `run_quality_gate()`; `normalize_unit()`'s
    `dehyphenate()` step is expected to have already rejoined these."""
    return len(re.findall(r"[a-z]-\n[a-z]", text))


def control_char_count(text):
    """Count NUL bytes specifically. NUL (`\\x00`) has no legitimate
    provenance anywhere in this pipeline -- unlike the broader `Cc` control
    range (see `printable_ratio` below), which real-corpus calibration
    (see this task's calibration-notes.md) showed is used pervasively and
    legitimately by ~half the live corpus as a glyph-index substitute for
    math symbols under a partial/broken `ToUnicode` CMap. NUL itself was
    found in exactly one real corpus document
    (`pym_ohearn_yang_2004_possible-worlds-resources-bi`, 1352 occurrences,
    a genuine already-ingested defect -- not touched by this task per its
    Non-Goals, but real evidence that zero tolerance on NUL specifically is
    both safe (0 occurrences in the other 37 measured documents) and
    correctly discriminating (correctly fails the one document that has
    it). Returns a plain int, matching the "any occurrence is a defect"
    shape already used by `ligature_residue_count`/
    `dehyphenation_residue_count`."""
    return text.count("\x00")


def printable_ratio(text):
    """Fraction of `text` (excluding `\\t`/`\\n`/`\\r`, which are exempted
    from both the numerator and the denominator as ordinary text structure,
    not corruption) that is NOT classified into one of `Cc` (control,
    already NUL-checked separately above but also folded in here since a
    document could carry many *non-NUL* control codepoints), `Cs`
    (surrogate), `Co` (private-use area), or `Cn` (unassigned) --
    the four Unicode general categories a broken/custom PDF font encoding's
    glyph indices land in when a ToUnicode CMap is missing or wrong.

    Deliberately a RATIO threshold, not zero-tolerance: real-corpus
    calibration found 19 of 38 measured corpus documents (up to 17299
    non-printable characters in the single largest case) legitimately use
    low-range `Cc` codepoints (`0x01`-`0x1F`) as a systemic, benign
    glyph-substitution convention for math symbols -- manually spot-checked
    clean on the two highest-count documents. A zero-tolerance version of
    this check would fail roughly half the existing corpus, directly
    violating this task's explicit goal that all 40 corpus documents keep
    passing. See calibration-notes.md for the full measured distribution
    (real minimum: 0.931404) and the chosen floor's headroom below it.

    Returns `(ratio, nonprintable_count)` -- the count is exposed so the
    caller's reason string can name both the ratio and the raw count,
    matching this file's other reason-string conventions.

    Safe for the empty/whitespace-only case: returns `(1.0, 0)` rather than
    dividing by zero, even though the live gate already rejects empty
    content upstream of this function -- the module itself must be safe to
    unit-test with any string, per this phase's own task list."""
    exempt = sum(1 for c in text if c in _EXEMPT_WHITESPACE)
    remaining_total = len(text) - exempt
    if remaining_total <= 0:
        return 1.0, 0
    nonprintable = sum(
        1
        for c in text
        if c not in _EXEMPT_WHITESPACE
        and unicodedata.category(c) in _NONPRINTABLE_CATEGORIES
    )
    return 1 - (nonprintable / remaining_total), nonprintable
