#!/usr/bin/env python3
"""generate-test-fixtures.py - Build hermetic synthetic PDF fixtures for
test-literature-convert.sh.

No network access, no committed binary: fixtures are generated at test time
via PyMuPDF, the same library the conversion pipeline itself already depends
on (a hard prerequisite of this whole pipeline, so no new dependency here).

Usage:
    generate-test-fixtures.py two-column <output.pdf>
    generate-test-fixtures.py bold-heading <output.pdf>
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


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    kind, out_path = sys.argv[1], sys.argv[2]
    if kind == "two-column":
        build_two_column_pdf(out_path)
    elif kind == "bold-heading":
        build_bold_heading_pdf(out_path)
    else:
        print(f"Unknown fixture kind: {kind}", file=sys.stderr)
        sys.exit(1)
    print(out_path)


if __name__ == "__main__":
    main()
