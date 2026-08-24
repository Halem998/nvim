# pymupdf4llm Extraction Fragmentation and Regex Design

`pymupdf4llm.to_markdown()` (the primary conversion tier — see `literature-convert.sh`'s
docstring) routinely breaks character-adjacency assumptions a naive regex writes against "clean"
notation examples. Any future quality-gate check written against notation-adjacent patterns
(binder/quantifier notation, subscripted variables, hat/circumflex diacritics, and similar) should
design against this from the start rather than rediscover it per-task — this cost significant
iteration when `sentence_boundary_glue_count()`'s binder exemption
(`literature_quality_gate.py`) was widened to stop false-positiving on higher-order-logic and
lambda-notation papers.

## Two concrete fragmentation patterns

**Markdown-emphasis wrapping.** Italicized PDF spans are rendered as markdown emphasis
(`_..._`), which interposes underscore/whitespace noise between characters that are visually
adjacent in the source PDF.

**Bare-digit subscript extraction.** Subscripted variable indices (x₁, xₙ) are rendered as bare
digits with surrounding whitespace, not as actual subscript markup — again interposing noise
between characters that read as adjacent to a human.

Both interrupt the immediate character-adjacency a simple `[binder][a-z]\.` -style pattern
assumes. Real excerpt from `goodman_2024_higher_order_logic_as_metaphysics`
(λx₁...xₙ.Rx₁...xₙ):

```
( _λx_ 1 _. . . xn.Rx_ 1 _. . . xn_ )
```

The triggering `[a-z]\.[A-Z]`-style match sits at the **last** bound variable in a multi-variable
ellipsis list (`n.R`), not adjacent to the binder `λ` at all — the binder is several tokens to
the left, before `x`. No amount of widening the character class at the binder position fixes
this; the exemption has to span the whole ellipsis-separated variable list, tolerating the
intervening markdown/whitespace/digit noise.

A second, distinct real excerpt, from `bacon_a_case_for_higher_order_metaphysics` (hat-abstraction
notation, `x.Fx` under a circumflex): pymupdf4llm's circumflex-diacritic extraction order is
inconsistent between prefix and postfix position, and the glyph used is **U+02C6 `ˆ` (MODIFIER
LETTER CIRCUMFLEX ACCENT), not the ASCII caret U+005E (`^`)**:

```
'nt. For instance, when a property term, _x.Fx_ ˆ , appe'
```

## The self-interference hazard: fix noise tolerance INSIDE the pattern, never via a global strip

A regex-based "exemption" check typically works by deleting matched spans before a final count
(`re.sub`-then-`findall`). Deleting a span can glue previously non-adjacent characters into a
**new** spurious match that wasn't there before the deletion — this is a real, measured hazard,
not a theoretical one.

**Concrete measurement**: an early attempt at widening `sentence_boundary_glue_count()`'s
exemption used a blanket global markdown-underscore strip as a preprocessing pass, ahead of the
widened regex. That approach **increased** the false-positive count on
`hott_book_2013_homotopy_type_theory_univalent_foundations` — a real corpus document, correctly
classified MIXED (genuine corruption + notation) and expected to stay rejected — from **11 to 26**
hits.

**The rule this establishes**: noise tolerance must live *inside* the exemption regex itself
(e.g. a `[_\s]*` noise-class woven into the pattern between a binder and its bound-variable run),
never in a separate global-strip pass applied ahead of matching. `literature_quality_gate.py`'s
`sentence_boundary_glue_count()` follows this rule — see its module-level `_NOISE`/`_VAR`
constants and the function's own docstring for the applied pattern.

**Verification implication**: when validating a regex-based exemption fix against a corpus of
real documents, "did the target false positive reach zero" is not a sufficient acceptance
criterion on its own. A document expected to stay rejected (a MIXED or true-positive fixture)
must be checked for an *increase* in its hit count too, not merely "did it stay above threshold" —
an increase is evidence of exactly this self-interference hazard, even if the document still
correctly fails the gate overall.

## Performance implication: an unanchored generic-start pattern is expensive at document scale

A pattern that begins with a character class matching nearly every position in real prose (e.g.
`[a-z]`) and only fails after scanning forward for a rare terminating glyph (e.g. the `ˆ` hat
above) is expensive under Python's backtracking `re` engine when run unanchored via `re.sub` over
a whole document: the engine attempts and fails the expensive match at almost every character
offset. Measured on the largest regression fixture (`hott_book_2013`, ~1.28MB of concatenated
markdown), a straightforward postfix-hat pattern of this shape added roughly 19x wall-clock
runtime versus the narrow exemption it replaced — bounding the pattern's internal lazy quantifier
alone did not meaningfully help (still ~10-15x). The fix that restored runtime to within ~10% of
baseline was algorithmic, not a quantifier tweak: scan forward from each occurrence of the rare
terminating glyph instead, and check only a small bounded window immediately preceding it. See
`_strip_postfix_hat()` in `literature_quality_gate.py` for the applied technique.
