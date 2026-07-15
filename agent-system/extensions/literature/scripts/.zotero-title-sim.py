#!/usr/bin/env python3
"""Normalized title similarity helper for zotero-resolve-pdf.sh.

Prints a single float in [0, 1] (difflib.SequenceMatcher ratio over lowercased,
punctuation-stripped titles). Not a standalone tool -- invoked by the resolver script only.
"""
import re
import sys
from difflib import SequenceMatcher


def normalize(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def main() -> None:
    if len(sys.argv) != 3:
        print("0.0")
        return
    a, b = normalize(sys.argv[1]), normalize(sys.argv[2])
    if not a or not b:
        print("0.0")
        return
    print(round(SequenceMatcher(None, a, b).ratio(), 4))


if __name__ == "__main__":
    main()
