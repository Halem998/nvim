"""literature_combining_overlay.py - shared combining-overlay composition logic.

TeX-descended PDFs encode negated relations (e.g. "\\not=") as a base glyph plus a
combining overlay mark (U+0338 COMBINING LONG SOLIDUS OVERLAY, and occasionally a
sibling from the same Unicode block) rather than a precomposed codepoint. Raw
PyMuPDF extraction from this corpus has been observed to emit the mark in either
order relative to its base, and -- critically -- sometimes with intervening
horizontal whitespace between the two (e.g. "TS(PG1 ||| PG2)" + MARK + " " + "="
extracts as mark, space, "="). Plain NFC composition alone cannot recover the
intended precomposed character in either of those cases: NFC only composes an
immediately-adjacent, canonically-ordered (base, then combining mark) pair.

This module is imported (never duplicated) by both `literature-convert.sh` (the
live conversion pipeline) and its own fixture self-test, so a change to the reorder
regex or the base whitelist can never silently drift between the two.

Restricted to a base-character WHITELIST (`_OVERLAY_BASES`) so ordinary letter
diacritics (e.g. "e" + U+0301 -> "e" + COMBINING ACUTE ACCENT -> NFC-composes to
"é") are never touched by the reorder step -- only relation-like symbols this
corpus is known to use as combining-overlay bases are eligible for reordering.
"""

import re
import unicodedata

# Base characters this corpus has been observed using under a combining overlay
# mark. `=<>...` etc. were the original whitelist; `⊢≺→|` plus the remainder were
# added after a corpus-wide combining-mark audit (see
# baseline-combining-audit.json's base-character tally) surfaced real, in-the-wild
# base characters beyond the original set. Kept as a closed whitelist, not opened
# to arbitrary characters -- widening this to "any symbol" would risk reordering
# unrelated combining-mark usage this corpus doesn't actually have.
_OVERLAY_BASES = r"=<>∈∋≡∼≈≤≥⊂⊆⊃⊇∃∀⊢≺→|⪯⊩≜⊴↣⊑≃"

# Match a combining mark (any codepoint in the "Combining Diacritical Marks"
# block, U+0300-U+036F -- U+0338 is the one confirmed relevant so far, but the
# same font/toolchain convention could in principle use a sibling mark)
# immediately followed by an optional short run of HORIZONTAL whitespace only
# (never a newline -- a mark and its base are only ever tolerated on the same
# line) and then one of the whitelisted base characters. Capped at 2 intervening
# whitespace characters: wider gaps are not a reorder case this fix targets (see
# the repair engine's own wider-window anchoring for those).
_OVERLAY_REORDER_RE = re.compile(r"([̀-ͯ])[ \t]{0,2}([" + _OVERLAY_BASES + r"])")

# Unicode's canonical decomposition of a negated relation does not always use
# the ASCII/keyboard base character as its base component -- verified: U+2224
# "DOES NOT DIVIDE" decomposes to U+2223 (the dedicated MATH "divides" symbol)
# + U+0338, NOT U+007C (ASCII vertical bar) + U+0338, even though this corpus's
# PDFs render "divides" using the plain ASCII pipe. Map any such base to its
# true NFC-composable canonical equivalent before/while reordering, so
# unicodedata.normalize("NFC", ...) can actually fire. All other whitelisted
# bases already equal their own canonical base and pass through unchanged.
_CANONICAL_BASE_OVERRIDE = {
    "|": "∣",  # ASCII vertical bar -> MATH "DIVIDES" (canonical base of ∤)
}


def _reorder_sub(m):
    mark, base = m.group(1), m.group(2)
    return _CANONICAL_BASE_OVERRIDE.get(base, base) + mark


def compose_combining_overlays(text):
    """Reorder any combining mark found immediately (optionally separated by up
    to 2 horizontal-whitespace characters) before a whitelisted relation base
    character, dropping the intervening whitespace and mapping the base to its
    true NFC-canonical equivalent where the two differ (see
    `_CANONICAL_BASE_OVERRIDE`), then run NFC to compose the reordered pair into
    its precomposed codepoint (e.g. "=" + U+0338 -> U+2260 "≠"). Idempotent:
    running this twice on already-composed or already-correct text is a no-op
    relative to running it once."""
    text = _OVERLAY_REORDER_RE.sub(_reorder_sub, text)
    return unicodedata.normalize("NFC", text)
