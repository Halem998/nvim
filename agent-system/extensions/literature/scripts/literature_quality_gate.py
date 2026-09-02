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

# --- sentence_boundary_glue_count() binder-notation exemption patterns ---
#
# Hoisted to module level (compiled once) rather than left inline in
# sentence_boundary_glue_count(): this function runs over whole-document
# content on every conversion, so per-call recompilation is avoidable cost.
#
# NOISE tolerates the markdown-emphasis (`_..._`) and bare-digit-subscript
# noise pymupdf4llm's extraction routinely interposes between a binder and
# its bound variable (see VAR's docstring note below and the real excerpts
# in the sentence_boundary_glue_count docstring).
_NOISE = r"[_\s]*"

# Bound-variable run. The `{0,12}?` bound is deliberate and load-bearing for
# performance, not correctness: an earlier unbounded `[a-z0-9_\s]*?` variant
# reached the same exemption counts on all five regression fixtures but ran
# ~19x slower on the largest fixture (hott_book_2013, 691 chunks) than the
# narrow single-character pattern it replaces -- almost entirely from
# _POSTFIX_HAT_TAIL below (see that pattern's docstring), not from this
# quantifier. The bound is kept here too as defense in depth: real
# bound-variable identifiers in this corpus (single letters, optionally
# subscripted, e.g. `x`, `x1`, `xn`) never approach 12 characters.
_VAR = rf"[a-z][a-z0-9_\s]{{0,12}}?{_NOISE}"

# Ellipsis-separated second variable, for multi-variable binder runs
# (`λx1 . . . xn.Rx1 . . . xn`) -- the triggering `[a-z]\.[A-Z]` match sits at
# the LAST variable of the list, not adjacent to the binder itself, so the
# exemption has to span the whole run.
_ELLIPSIS = rf"\.{_NOISE}\.{_NOISE}\.{_NOISE}"

# Prefix binder: `∀x.`, `∃y.`, `λx1 . . . xn.` -- optionally with the
# ellipsis-separated second variable above.
_PREFIX_BINDER_RE = re.compile(rf"[∀∃λ]{_NOISE}{_VAR}(?:{_ELLIPSIS}{_VAR})?\.")

# Prefix hat-abstraction: `ˆx.`. NOTE the glyph below is U+02C6 MODIFIER
# LETTER CIRCUMFLEX ACCENT (`ˆ`), NOT the ASCII caret U+005E (`^`) -- the
# corpus's hat-abstraction notation is typeset with the Unicode modifier
# letter, and an ASCII `^` in this position matches nothing in real
# converted text. Verify with `ord("ˆ")` == 0x2C6 if this file is ever
# round-tripped through an editor/encoding that could silently normalize it.
_PREFIX_HAT_RE = re.compile(rf"ˆ{_NOISE}{_VAR}\.")

# Postfix hat-abstraction tail: `x.Fx ˆ`. pymupdf4llm's circumflex-diacritic
# extraction order is inconsistent between prefix and postfix position, so
# this is a genuinely distinct shape from _PREFIX_HAT_RE above, not a
# reformulation of it -- a pure prefix pattern cannot catch it.
#
# This is matched via a hat-anchored scan (see _strip_postfix_hat below)
# rather than a single unanchored `{_VAR}\.[A-Za-z]+{_NOISE}ˆ` substitution.
# That more obvious formulation was tried first and reached the same
# exemption counts, but starts with `[a-z]` -- a character that occurs at
# nearly every position in real prose -- and only fails once it has scanned
# forward looking for the (rare) `ˆ` glyph, so an unanchored `re.sub` tries
# and fails this expensive path at almost every character offset in the
# document. That was the dominant cost behind the ~19x slowdown noted on
# _VAR above (isolated profiling: this one substitution alone accounted for
# ~0.25s of a ~0.52s total on the largest fixture, vs. ~0.001-0.007s for
# every other substitution in this module combined). Scanning outward from
# each (rare) `ˆ` occurrence instead reduces the search to a small bounded
# window per hat, restoring runtime to within ~10% of the original narrow
# pattern's.
_POSTFIX_HAT_TAIL_RE = re.compile(rf"{_VAR}\.[A-Za-z]{{1,20}}{_NOISE}\Z")
_POSTFIX_HAT_WINDOW = 100  # chars scanned backward from each 'ˆ'; generous
                            # relative to _VAR's 12-char bound plus a
                            # 20-char matrix-predicate name.


def _strip_postfix_hat(text):
    """Remove postfix hat-abstraction spans (`x.Fx ˆ`) from `text`.

    Scans forward from each 'ˆ' occurrence (rare) rather than running an
    unanchored regex substitution starting with `[a-z]` (extremely common)
    over the whole document -- see _POSTFIX_HAT_TAIL_RE's docstring for why
    that distinction is a ~19x-vs-~1.1x runtime difference, not a
    micro-optimization. Semantically equivalent to
    `_POSTFIX_HAT_TAIL_RE`-anchored substitution applied at every 'ˆ'."""
    pieces = []
    pos = 0
    for m in re.finditer("ˆ", text):
        hat_start = m.start()
        window_start = max(pos, hat_start - _POSTFIX_HAT_WINDOW)
        window = text[window_start:hat_start]
        tail_match = _POSTFIX_HAT_TAIL_RE.search(window)
        if tail_match:
            span_start = window_start + tail_match.start()
            pieces.append(text[pos:span_start])
            pos = m.end()
        # else: no postfix-hat tail immediately precedes this 'ˆ' -- leave
        # it and the preceding text untouched, keep scanning.
    pieces.append(text[pos:])
    return "".join(pieces)


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
      - Binder/quantifier and hat-abstraction notation, noise-tolerant of
        pymupdf4llm's markdown-emphasis (`_..._`) and bare-digit-subscript
        extraction artifacts (see the module-level `_VAR`/`_PREFIX_BINDER_RE`
        etc. docstrings above for the full three-pattern shape and the
        two real corpus excerpts that motivated it). Originally a much
        narrower single-character-adjacent form (`∀x.P`, `∃y.E`) — e.g.
        Ishtiaq-O'Hearn 2001 "BI as an Assertion Language", rejected at 7
        hits (5 quantifier notation, 2 Ph.D.) — later found to reject real
        higher-order-logic and lambda-notation papers wholesale (Goodman
        2024 "Higher-Order Logic as Metaphysics", Bacon "A Case for
        Higher-Order Metaphysics") because the notation's bound-variable
        runs are frequently multi-character, ellipsis-separated, and
        fragmented by extraction noise rather than a single bare lowercase
        letter immediately adjacent to the binder. Widened to the current
        three-pattern form once those two false positives were confirmed
        to reach zero hits without moving the true-positive fixture
        (Dorr-Bacon-style genuine `<sup>`-span fusion corruption) or either
        MIXED document's hit count (see "MIXED documents" note below).

    IMPORTANT — substitution self-interference: an earlier attempt at
    widening this exemption used a blanket global markdown-underscore strip
    as a preprocessing pass, ahead of a widened regex. That approach
    INCREASED false positives on one real MIXED-classification document
    from 11 to 26 hits — deleting matched spans glued previously
    non-adjacent characters into brand-new spurious `[a-z]\\.[A-Z]` matches.
    The three patterns below avoid this by matching noise-tolerant runs
    directly WITHIN the exemption regex itself; there is deliberately no
    separate global-strip pass anywhere in this function. Any future
    widening of this exemption should re-verify the two MIXED-document
    fixtures' hit counts are EXACTLY unchanged, not merely "not reduced" —
    an increase is the specific regression this note exists to prevent.

    MIXED documents: hott_book_2013 (HoTT book) and ahrens_north
    (Ahrens-North-Shulman-Tsementzis "The Univalence Principle") remain
    correctly rejected by this check (11 and 21 hits respectively,
    unaffected by the widening above) and are DELIBERATELY not targeted by
    it. Their residual hits are dominated by genuine `<sup>`-span fusion
    corruption (`isalsomodal.Thus`, `iscontractible.Since`, ...) plus a
    distinct parenthesized dependent-type binder shape (`∀(x : A).Px`,
    `Σ(a:A)B(a)`) this exemption does not cover — covering that shape would
    not change either document's pass/fail outcome, since the genuine
    corruption alone exceeds the threshold. Both documents' bibliographies
    also carry a handful of arXiv subject-class citation codes (`math.CT`,
    `math.AT`) that incidentally match the raw pattern; these are a known,
    deliberately unexempted secondary class, not corruption, and not
    blocking either document's correct rejection. Reconversion with
    `LITERATURE_CONVERTER=fallback` is NOT a universal remedy for a
    gate-rejected document — it fixes only defects the primary tier's
    own markdown-structuring heuristics introduce (table misdetection
    over dense back matter, as here and in
    savage_1972_foundations-of-statistics; `<sup>`/`<sub>` footnote-span
    space-dropping, as in bacon_dorr_2024_classicism). It does nothing
    for — and can even slightly worsen — a defect already baked into the
    source text layer (e.g. a poor-vintage OCR pass):
    joyce_1999_foundations-causal-decision-theory goes from 4 hits on
    the primary tier to 5 on the fallback tier, because both tiers read
    the same corrupted characters and the fallback tier's own
    column-clustering can add unrelated noise. See
    context/guides/literature-organization.md's Converter Tier
    Selection section for the full diagnostic guidance —
    never widening this exemption further, tuning the threshold-3 cutoff, or a manual override.

    Exemption is applied by stripping the exempted substrings first, THEN
    counting on what remains — not a negative lookbehind — since the
    exemption spans each fully contain the raw match span they exempt,
    making a strip-first pass exact and avoiding Python re's
    fixed-width-lookbehind constraint."""
    exempted = re.sub(r"Ph\.D\.?", "", text)
    exempted = _PREFIX_BINDER_RE.sub("", exempted)
    exempted = _PREFIX_HAT_RE.sub("", exempted)
    exempted = _strip_postfix_hat(exempted)
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
