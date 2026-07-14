#!/usr/bin/env python3
"""literature-decode-font-offset.py - Reusable font-offset mojibake decoder.

Decodes markdown text extracted from a PDF where a fixed per-character byte
offset was applied during extraction (a font-substitution artifact), plus a
punctuation-normalization pass for a comma/period collision pattern first
documented for the Kamp 1968 corpus entry (task #849, research report
specs/849_recover_kamp_1968_mojibake/reports/01_kamp-1968-font-offset-recovery.md).

Cipher (Kamp 1968 validated defaults, used unless --band overrides are given):
  encoded byte in [62,87]  -> +3  (encoded uppercase band -> A-Z)
  encoded byte in [93,118] -> +4  (encoded lowercase band -> a-z)
  encoded byte in [44,53]  -> +4  (encoded digit band -> 0-9)
  everything else passes through unchanged

Only ASCII codepoints (<128) participate in the shift bands. Bytes/codepoints
>127 (multi-byte UTF-8 sequences already decoded to Unicode codepoints by the
text-mode file read) pass through untouched, since no validated band covers
above 118 -- this preserves any pre-existing UTF-8 content (correct or itself
already mojibake) without corrupting multi-byte sequences.

Punctuation normalization (documented root cause: the source PDF's literal
'.' period glyphs were extracted as raw byte 0x2c, the same raw byte used for
genuine encoded digit '0'; genuine commas were extracted as raw byte 0x2a,
which sits below all shift bands and passes through unshifted):

  1. Blind replace '*' -> ',' (unambiguous comma collision, no exceptions
     found in ~1780 occurrences in the Kamp corpus sample).
  2. Four-tier '0' rule (period / genuine-digit-zero ambiguity), in priority
     order:
       a. 0{3,} runs = TOC dot-leaders; collapse, keep any immediately
          trailing non-zero-led digit run as the genuine page number.
       b. '0' letter-adjacent (within 1 char, space-tolerant on either side)
          -> '.' (period).
       c. '0' touching another digit only (not letter-adjacent) -> leave in
          place as a genuine digit.
       d. isolated unclassified '0' (neither letter- nor digit-adjacent)
          -> leave in place AND emit to --flag-report for manual review.

Usage:
  literature-decode-font-offset.py --in FILE --out FILE [--flag-report FILE]
      [--band lo,hi,off ...] [--quarantine] [--dry-run]

Exit codes:
  0 - success
  1 - bad arguments / input file not found
  2 - quarantine backup failed cmp -s verification
"""
import argparse
import datetime
import re
import shutil
import subprocess
import sys
from pathlib import Path

DEFAULT_BANDS = [(62, 87, 3), (93, 118, 4), (44, 53, 4)]

_LETTER = re.compile(r"[A-Za-z]")
_DIGIT = re.compile(r"[0-9]")


def parse_band(s):
    parts = s.split(",")
    if len(parts) != 3:
        raise argparse.ArgumentTypeError(f"--band must be 'lo,hi,off', got: {s!r}")
    try:
        lo, hi, off = (int(p) for p in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"--band values must be integers: {s!r}") from exc
    return (lo, hi, off)


def decode_text(text, bands):
    """Apply the band-shift cipher to a decoded Unicode string.

    Only codepoints < 128 (ASCII) participate in the shift bands; all other
    characters (multi-byte UTF-8 sequences already decoded to codepoints
    >127 by the text-mode file read) pass through untouched.
    """
    out = []
    for ch in text:
        o = ord(ch)
        if o > 127:
            out.append(ch)
            continue
        shifted = o
        for lo, hi, off in bands:
            if lo <= o <= hi:
                shifted = o + off
                break
        out.append(chr(shifted))
    return "".join(out)


def normalize_comma(text):
    """Blind global replace: encoded '*' is an unambiguous genuine comma."""
    return text.replace("*", ",")


def normalize_zero(text):
    """Four-tier '0' normalization (period / genuine-digit-zero ambiguity).

    Returns (normalized_text, flagged) where flagged is a list of
    (offset, context_snippet) tuples for rule-4 residual manual review.
    """
    # Tier 1: long runs (3+) of '0' = TOC dot-leaders; collapse, keeping any
    # immediately trailing non-zero-led digit run as the genuine page number.
    def _collapse_toc(m):
        return m.group(1) or ""

    text = re.sub(r"0{3,}([1-9]\d*)?", _collapse_toc, text)

    chars = list(text)
    flagged = []
    i = 0
    n = len(chars)
    while i < n:
        if chars[i] != "0":
            i += 1
            continue

        left1 = chars[i - 1] if i - 1 >= 0 else ""
        right1 = chars[i + 1] if i + 1 < n else ""
        left2 = chars[i - 2] if i - 2 >= 0 else ""
        right2 = chars[i + 2] if i + 2 < n else ""

        letter_adjacent = (
            bool(_LETTER.match(left1))
            or bool(_LETTER.match(right1))
            or (left1 == " " and bool(_LETTER.match(left2)))
            or (right1 == " " and bool(_LETTER.match(right2)))
        )
        digit_adjacent = bool(_DIGIT.match(left1)) or bool(_DIGIT.match(right1))

        if letter_adjacent:
            # Tier 2: period.
            chars[i] = "."
        elif digit_adjacent:
            # Tier 3: genuine digit, leave in place.
            pass
        else:
            # Tier 4: isolated unclassified '0' - leave, flag for review.
            start = max(0, i - 20)
            end = min(n, i + 20)
            context = "".join(chars[start:end]).replace("\n", "\\n")
            flagged.append((i, context))
        i += 1

    return "".join(chars), flagged


def decode_and_normalize(text, bands):
    decoded = decode_text(text, bands)
    decoded = normalize_comma(decoded)
    decoded, flagged = normalize_zero(decoded)
    return decoded, flagged


def quarantine_backup(path: Path):
    """cp path -> path.bak-<UTC>, then cmp -s verify.

    Returns the backup Path. Raises SystemExit(2) if cmp verification fails.
    """
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = path.with_name(path.name + f".bak-{ts}")
    shutil.copy2(path, backup)
    result = subprocess.run(["cmp", "-s", str(path), str(backup)])
    if result.returncode != 0:
        print(f"ERROR: backup verification failed for {path} -> {backup}", file=sys.stderr)
        raise SystemExit(2)
    print(f"Quarantine backup verified: {backup}")
    return backup


def main():
    ap = argparse.ArgumentParser(
        description="Decode font-offset mojibake and normalize comma/period collisions.",
    )
    ap.add_argument("--in", dest="infile", required=True, help="input file path")
    ap.add_argument("--out", dest="outfile", required=True, help="output file path")
    ap.add_argument(
        "--flag-report",
        dest="flag_report",
        default=None,
        help="path to write the rule-4 ambiguous-'0' manual-review list",
    )
    ap.add_argument(
        "--band",
        dest="bands",
        action="append",
        type=parse_band,
        default=None,
        help="repeatable 'lo,hi,off' band; defaults to the validated Kamp 1968 "
        "bands ([62,87]+3, [93,118]+4, [44,53]+4) if omitted",
    )
    ap.add_argument(
        "--quarantine",
        action="store_true",
        help="back up --in (and --out, if it already exists and is a different "
        "path) as a .bak-<UTC> sibling, cmp -s verified, before writing",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="run the decode/normalize pass and report stats without writing --out",
    )
    args = ap.parse_args()

    bands = args.bands if args.bands else DEFAULT_BANDS

    infile = Path(args.infile)
    if not infile.is_file():
        print(f"ERROR: input file not found: {infile}", file=sys.stderr)
        sys.exit(1)

    if args.quarantine:
        quarantine_backup(infile)
        outfile_preexisting = Path(args.outfile)
        if outfile_preexisting.exists() and outfile_preexisting.resolve() != infile.resolve():
            quarantine_backup(outfile_preexisting)

    text = infile.read_text(encoding="utf-8")
    decoded, flagged = decode_and_normalize(text, bands)

    if args.flag_report:
        with open(args.flag_report, "w", encoding="utf-8") as f:
            if not flagged:
                f.write("# No rule-4 ambiguous '0' occurrences found.\n")
            else:
                f.write(
                    f"# {len(flagged)} rule-4 ambiguous '0' occurrence(s) for manual review\n"
                )
                for offset, context in flagged:
                    f.write(f"offset={offset}\tcontext=...{context}...\n")

    print(f"Decoded {len(text)} chars -> {len(decoded)} chars.")
    print(f"Rule-4 ambiguous '0' occurrences flagged: {len(flagged)}")

    if args.dry_run:
        print("(dry-run: --out not written)")
        return

    outfile = Path(args.outfile)
    outfile.write_text(decoded, encoding="utf-8")
    print(f"Wrote decoded output to {outfile}")


if __name__ == "__main__":
    main()
