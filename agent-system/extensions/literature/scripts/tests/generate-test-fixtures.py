#!/usr/bin/env python3
"""generate-test-fixtures.py - Build hermetic synthetic PDF fixtures for
test-literature-convert.sh.

No network access, no committed binary: fixtures are generated at test time
via PyMuPDF, the same library the conversion pipeline itself already depends
on (a hard prerequisite of this whole pipeline, so no new dependency here).

Usage:
    generate-test-fixtures.py two-column <output.pdf>
    generate-test-fixtures.py bold-heading <output.pdf>
    generate-test-fixtures.py biblio-quantifier <output.pdf>
    generate-test-fixtures.py fused-word <output.pdf>
    generate-test-fixtures.py broken-font <output.pdf>
    generate-test-fixtures.py image-only <output.pdf>
"""
import sys

import fitz


LEFT_TEXT = (
    "LEFTCOL sentence one about the left column of this synthetic page. "
    "LEFTCOL sentence two continues the left column discussion here. "
    "LEFTCOL sentence three still belongs to the left column only. "
    "LEFTCOL sentence four wraps up the left column's body text."
)

RIGHT_TEXT = (
    "RIGHTCOL sentence one about the right column of this synthetic page. "
    "RIGHTCOL sentence two continues the right column discussion here. "
    "RIGHTCOL sentence three still belongs to the right column only. "
    "RIGHTCOL sentence four wraps up the right column's body text."
)


def build_two_column_pdf(out_path):
    """A single-page, two-column layout with a full-width title above both
    columns. Known-good reading order: title, then ALL of LEFTCOL top-to-
    bottom, then ALL of RIGHTCOL top-to-bottom — never interleaved.

    Uses insert_textbox() with a column-width-constrained rectangle (NOT
    insert_text(), which draws an unwrapped single line) so each column's
    text actually wraps within its own x-range, the way a real multi-column
    PDF's text genuinely does. An earlier version of this fixture used
    insert_text() for whole, long, un-wrapped sentences; those single lines
    were wide enough to overlap BOTH columns' x-ranges (e.g. a left-column
    line spanning x=[72, 375] on a page where the right column starts at
    x=320), which defeated column-band clustering entirely — not a
    representative test of real two-column layouts, where individual lines
    are always confined to their own column's width."""
    doc = fitz.open()
    page = doc.new_page(width=612, height=792)  # US letter

    page.insert_text((72, 72), "Synthetic Two-Column Regression Fixture", fontsize=14, fontname="hebo")

    left_rect = fitz.Rect(72, 110, 290, 400)
    right_rect = fitz.Rect(322, 110, 540, 400)
    page.insert_textbox(left_rect, LEFT_TEXT, fontsize=10)
    page.insert_textbox(right_rect, RIGHT_TEXT, fontsize=10)

    doc.save(out_path)
    doc.close()


def build_image_only_pdf(out_path):
    """A single-page document simulating a genuinely image-only (scanned,
    no-text-layer) PDF: real, legible words are rendered on an intermediate
    page via ordinary insert_text(), rasterized to a pixmap, and that pixmap
    is inserted as a full-page IMAGE into a fresh output page — so the final
    PDF has visible, human-readable content but zero extractable text via
    plain fitz text extraction (page.get_text()), exactly the property this
    task's exit-2 NO TEXT LAYER path and LITERATURE_CONVERTER=ocr mode exist
    to handle. Asserts this property on itself before returning, per this
    phase's Scope Hypothesis, rather than assuming the pixmap round-trip
    strips all text.

    NOTE for any caller composing this fixture with LITERATURE_CONVERTER=auto
    on a machine where the primary tier's venv is provisioned AND system
    `tesseract` is on PATH: pymupdf4llm.to_markdown()'s force_text=True
    default (a pre-existing, out-of-scope PyMuPDF/pymupdf4llm behavior,
    unrelated to the `ocrmypdf` CLI this task adds) can silently recover real
    text from this exact fixture shape via its own internal Tesseract call,
    which would make `auto` exit 0 instead of the expected exit 2. Callers
    asserting the exit-2 contract deterministically should force the primary
    tier unavailable (e.g. LITERATURE_PYENV_DIR pointed at a scratch/
    nonexistent directory) so `auto` degrades to the mandatory fallback tier,
    which has no such internal OCR trigger — see this task's implementation
    summary for the full finding."""
    text_doc = fitz.open()
    text_page = text_doc.new_page(width=612, height=792)
    text_page.insert_text((72, 100), "Introduction", fontsize=20, fontname="hebo")
    text_page.insert_text((72, 150), "This is a scanned page with real words on it.", fontsize=14)
    text_page.insert_text((72, 180), "Optical character recognition should read this text.", fontsize=14)
    pix = text_page.get_pixmap(dpi=150)
    text_doc.close()

    doc = fitz.open()
    page = doc.new_page(width=612, height=792)
    page.insert_image(page.rect, pixmap=pix)
    doc.save(out_path)
    doc.close()

    check_doc = fitz.open(out_path)
    extracted = check_doc[0].get_text()
    check_doc.close()
    assert not extracted.strip(), (
        f"build_image_only_pdf: fixture unexpectedly has an extractable text "
        f"layer ({extracted!r}) -- the pixmap-insert-as-image round-trip did "
        f"not strip all text as required by this fixture's whole purpose"
    )


def build_bold_heading_pdf(out_path):
    """A single-page, single-column document with one genuine bold heading
    and one sentence-fragment 'heading' (large font, ends in a period) — the
    exact real-corpus BUG 3 upstream defect shape. Enough body text to give
    the font-size histogram a real majority (the no-TOC
    heading heuristic needs this to not be a coin-flip tie)."""
    doc = fitz.open()
    page = doc.new_page(width=612, height=792)

    y = 72
    page.insert_text((72, y), "Introduction", fontsize=16, fontname="hebo")
    y += 24
    for i in range(14):
        page.insert_text((72, y), f"This is body text line number {i} continuing the discussion in a normal font.", fontsize=10)
        y += 14
    y += 16
    page.insert_text((72, y), "indeterminacy.", fontsize=16, fontname="hebo")
    y += 24
    for i in range(8):
        page.insert_text((72, y), f"More body text line {i} continues here after the sentence fragment case.", fontsize=10)
        y += 14

    doc.save(out_path)
    doc.close()


def build_biblio_quantifier_pdf(out_path):
    """A single-page, single-column document mirroring the two real-corpus
    false-positive cases for `sentence_boundary_glue_count`
    (literature-convert.sh): a References block heavy with `Ph.D. thesis,`
    entries (the Pym-O'Hearn-Yang 2004 case) and a body line carrying
    single-letter-variable quantifier/binder notation (the Ishtiaq-O'Hearn
    2001 case). This is the NEGATIVE fixture: it must PASS the quality gate
    (exit 0) once the two-exemption strip-then-count fix is in place.

    The binder line uses fitz.TextWriter + fitz.Font("helv") rather than
    insert_text() with a base-14 font: insert_text() silently substitutes
    U+00B7 (middle dot) for U+2200/U+2203 under 'helv', and drops them
    entirely under the built-in CJK font 'china-ss' — neither failure
    raises, so the binder characters would silently vanish from the
    extracted text with insert_text(). TextWriter's round-trip through
    get_text() was verified to preserve `∀x.P`, `∃y.E`, `∃x.Q` exactly.
    Confirmed during the red-baseline spike (never against
    ~/Projects/Literature/): raw `[a-z]\\.[A-Z]` count 7 (4 `Ph.D`, 3
    binder-adjacent), exit 3 pre-fix with sentence-boundary-glue as the sole
    gate reason, residue 0 after the two exemption `re.sub` passes."""
    doc = fitz.open()
    page = doc.new_page(width=612, height=792)

    y = 72
    page.insert_text((72, y), "Assumptions and Notation", fontsize=14, fontname="hebo")
    y += 28
    body_lines = [
        "This section fixes notation used throughout the development below.",
        "We work in a first-order setting with the usual connectives and quantifiers.",
        "Resource composition is written using the separating conjunction symbol.",
        "The semantics is given relative to a Kripke resource monoid structure.",
    ]
    for line in body_lines:
        page.insert_text((72, y), line, fontsize=10)
        y += 16

    y += 12
    tw = fitz.TextWriter(page.rect)
    tw.append(
        (72, y),
        "Formally we require ∀x.P and ∃y.E and ∃x.Q hold in the model.",
        font=fitz.Font("helv"),
        fontsize=11,
    )
    tw.write_text(page)
    y += 30

    page.insert_text((72, y), "References", fontsize=14, fontname="hebo")
    y += 24
    biblio = [
        "A. Author. A Study of Resource Semantics. Ph.D. thesis, University of Nowhere, 2001.",
        "B. Writer. Bunched Logics and Their Models. Ph.D. thesis, University of Elsewhere, 2003.",
        "C. Scholar. Assertions for Pointer Programs. Ph.D. thesis, University of Someplace, 2005.",
        "D. Researcher. Separation and Sharing. Ph.D. thesis, University of Anywhere, 2007.",
    ]
    for line in biblio:
        page.insert_text((72, y), line, fontsize=10)
        y += 16

    doc.save(out_path)
    doc.close()


def build_fused_word_pdf(out_path):
    """A single-page, single-column document carrying the genuine
    Goldblatt/Hodkinson/Venema fused-sentence-boundary defect signature
    (a lowercase letter, period, uppercase letter with no intervening
    space — pymupdf4llm was observed to drop the space in this exact shape
    around `<sup>`/`<sub>` markdown spans on that real corpus document).
    Contains zero `Ph.D` and zero `∀∃λ` binder characters,
    so it is structurally immune to the two new exemptions and stays
    unaffected by the fix. This is the POSITIVE fixture: it must STILL FAIL
    the quality gate (exit 3, output diverted to `rejected_path`) after the
    fix lands, proving the check's real purpose survives the narrowing.

    Each fused-boundary line is deliberately kept under ~70 characters:
    insert_text() does not wrap, and a single line wider than the page's
    usable width is silently truncated mid-word rather than wrapped or
    rejected — discovered during the red-baseline spike when a longer line
    clipped the intended fusion boundary entirely. Confirmed during that
    spike (never against ~/Projects/Literature/): raw count 3 (exactly at
    threshold), exit 3 with sentence-boundary-glue as the sole gate reason,
    residue still 3 after the exemption strip (unaffected, as intended)."""
    doc = fitz.open()
    page = doc.new_page(width=612, height=792)

    y = 72
    page.insert_text((72, y), "Introduction", fontsize=14, fontname="hebo")
    y += 28
    lines = [
        "We begin by recalling the basic definitions used below in this note.",
        "The proof proceeds by induction.The base case is trivial to check.",
        "Another sentence fuses here.A third fusion occurs at this point.",
        "This step follows directly.The next line completes the argument.",
        "This concludes the informal overview of the argument given above.",
    ]
    for line in lines:
        page.insert_text((72, y), line, fontsize=10)
        y += 16

    doc.save(out_path)
    doc.close()


def build_broken_font_pdf(out_path):
    """A single-page, single-column document simulating the exact
    glyph-index-as-codepoint corruption signature this task's checks exist
    to catch: a broken/custom PDF font encoding with no usable ToUnicode
    CMap, where extracted 'text' is really raw low-range control codes
    (landing in Unicode category Cc) rather than the intended characters.

    Verified cheaply constructible with plain fitz.Page.insert_text(): a
    string containing literal U+0000-U+0008 control characters round-trips
    through PyMuPDF's own get_text() unchanged (confirmed directly against
    a throwaway PDF during this phase — insert_text() does not require its
    argument to be printable; ToUnicode/content-stream text extraction
    returns exactly what was inserted). This means the SAME corrupted
    content is visible to both engine tiers, since pymupdf4llm's own text
    extraction is layered on the same underlying MuPDF extraction as the
    fallback tier's raw fitz calls -- exactly the "fails on every tier"
    property this task requires.

    Roughly 45% of body characters are NUL or other low-range control
    codes, well past both the zero-tolerance NUL check and the 0.85
    printable-ratio floor (see calibration-notes.md), while overall word
    count stays close to a plausible page so the page-coverage check is NOT
    what fires here -- this fixture isolates the two new checks."""
    doc = fitz.open()
    page = doc.new_page(width=612, height=792)

    CONTROL_RUN = "\x00\x01\x02\x03\x04\x05\x06\x07\x08"

    y = 72
    page.insert_text((72, y), "Introduction", fontsize=14, fontname="hebo")
    y += 28
    for i in range(16):
        line = f"word{i}a {CONTROL_RUN} word{i}b {CONTROL_RUN} word{i}c normal text tail"
        page.insert_text((72, y), line, fontsize=10)
        y += 16

    doc.save(out_path)
    doc.close()


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    kind, out_path = sys.argv[1], sys.argv[2]
    if kind == "two-column":
        build_two_column_pdf(out_path)
    elif kind == "bold-heading":
        build_bold_heading_pdf(out_path)
    elif kind == "biblio-quantifier":
        build_biblio_quantifier_pdf(out_path)
    elif kind == "fused-word":
        build_fused_word_pdf(out_path)
    elif kind == "broken-font":
        build_broken_font_pdf(out_path)
    elif kind == "image-only":
        build_image_only_pdf(out_path)
    else:
        print(f"Unknown fixture kind: {kind}", file=sys.stderr)
        sys.exit(1)
    print(out_path)


if __name__ == "__main__":
    main()
