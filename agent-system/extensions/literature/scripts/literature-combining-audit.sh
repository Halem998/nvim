#!/usr/bin/env bash
# literature-combining-audit.sh - Read-only PDF-vs-markdown combining-mark (U+0338)
# fidelity detector for the ~/Projects/Literature corpus.
#
# Rationale: the dangerous defect class this detects is a SILENT DROP -- the PDF's
# combining overlay mark (U+0338 COMBINING LONG SOLIDUS OVERLAY, used by TeX-descended
# PDFs to render negated relations such as "\not=") is missing entirely from the
# converted markdown, leaving a plain, readable, semantically-INVERTED equality/
# membership/etc. A bare-survivor grep for U+0338 in markdown can only ever find the
# benign case (mark present but uncomposed); it is structurally blind to a silent drop.
# The only way to detect the dangerous case is to compare PDF ground truth (raw
# PyMuPDF `page.get_text("text")` extraction -- NOT `pdftotext`, which itself
# substitutes a literal digit "6" for the overlay mark) against the converted markdown.
#
# Usage:
#   literature-combining-audit.sh [--dir NAME] [--json] [-h|--help]
#
#   --dir NAME  Scope to a single sources/<NAME>/ directory (default: whole corpus).
#   --json      Emit per-occurrence JSON records (base character, signature, PDF
#               character offset, context window, and -- when uniquely anchored --
#               the exact markdown file/gap-span) instead of the TSV summary. This
#               is the input contract for `literature-repair-combining.sh`.
#   -h, --help  Show this help.
#
# Output (default, TSV, one row per directory, columns):
#   dir  pdf_occurrences  corrupted_count  accounted_count  precomposed  bare_pair
#   latex_macro  control_char  glyph_six  absent  unanchored
#
#   "accounted" (no action needed): precomposed | bare_pair | latex_macro
#   "corrupted" (actionable):       control_char | glyph_six | absent | unanchored
#   (unanchored is a detector-limitation bucket -- the occurrence could not be
#   confidently located in the markdown at all, either because zero or more than one
#   candidate anchor matched. It is counted as corrupted/actionable conservatively,
#   and is exactly the class the plan's residual ledger exists to record.)
#
# Directory selection: a sources/<dir>/ is scanned only if it has at least one
# `*.pdf` AND at least one non-`chunk_*.md` `*.md`. Directories missing either are
# silently skipped in corpus-wide mode (this is the documented, permanent scope
# boundary: PDF-less directories cannot be checked by this methodology at all).
# In --dir mode, a directory with a PDF but no convertible markdown is reported with
# an explicit "no converted markdown found" notice instead of a silent empty result.
#
# This script NEVER writes to the corpus or to index.json -- read-only by
# construction. Detection/anchoring logic lives in literature_combining_detect.py
# (imported, not duplicated) so this script and literature-repair-combining.sh
# always locate and classify occurrences identically.
#
# Environment:
#   LITERATURE_DIR  Path to the global Literature/ repo (default: ~/Projects/Literature)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
DIR_FILTER=""
JSON_MODE="0"

usage() {
  cat <<'EOF'
Usage: literature-combining-audit.sh [--dir NAME] [--json] [-h|--help]

  --dir NAME  Scope to a single sources/<NAME>/ directory (default: whole corpus).
  --json      Emit per-occurrence JSON records instead of the TSV summary.
  -h, --help  Show this help.

Read-only: never writes to the corpus or to index.json.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      DIR_FILTER="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE="1"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ ! -d "$LITERATURE_DIR" ]; then
  echo "Error: LITERATURE_DIR not found: $LITERATURE_DIR" >&2
  exit 1
fi

SOURCES_DIR="$LITERATURE_DIR/sources"
if [ ! -d "$SOURCES_DIR" ]; then
  echo "Error: sources/ not found under LITERATURE_DIR: $SOURCES_DIR" >&2
  exit 1
fi

LITERATURE_DIR="$LITERATURE_DIR" \
SOURCES_DIR="$SOURCES_DIR" \
DIR_FILTER="$DIR_FILTER" \
JSON_MODE="$JSON_MODE" \
LITERATURE_SCRIPT_DIR="$SCRIPT_DIR" \
python3 <<'PYEOF'
import datetime
import json
import os
import sys

sys.path.insert(0, os.environ["LITERATURE_SCRIPT_DIR"])
try:
    import fitz  # noqa: F401  -- checked eagerly so the error is unambiguous
except ImportError as e:
    print(f"[combining-audit] PyMuPDF (fitz) not available: {e}", file=sys.stderr)
    sys.exit(2)

from literature_combining_detect import scan_directory  # noqa: E402

SOURCES_DIR = os.environ["SOURCES_DIR"]
DIR_FILTER = os.environ.get("DIR_FILTER", "")
JSON_MODE = os.environ.get("JSON_MODE", "0") == "1"


def no_markdown_notice(dirname):
    if DIR_FILTER:
        print(f"[combining-audit] {dirname}: has PDF but no converted markdown "
              f"(non-chunk *.md) -- no converted markdown found; skipping.",
              file=sys.stderr)


def main():
    if DIR_FILTER:
        dirnames = [DIR_FILTER]
    else:
        dirnames = sorted(
            d for d in os.listdir(SOURCES_DIR)
            if os.path.isdir(os.path.join(SOURCES_DIR, d))
        )

    results = []
    for dirname in dirnames:
        dirpath = os.path.join(SOURCES_DIR, dirname)
        if not os.path.isdir(dirpath):
            if DIR_FILTER:
                print(f"Error: directory not found: {dirpath}", file=sys.stderr)
                sys.exit(1)
            continue
        r = scan_directory(dirpath, dirname, on_no_markdown=no_markdown_notice)
        if r is not None:
            results.append(r)

    if JSON_MODE:
        out = {
            "generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "directories": results,
        }
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return

    header = ["dir", "pdf_occurrences", "corrupted_count", "accounted_count",
              "precomposed", "bare_pair", "latex_macro", "control_char",
              "glyph_six", "absent", "unanchored"]
    print("\t".join(header))
    for r in results:
        sc = r["signature_counts"]
        row = [
            r["dir"], str(r["pdf_occurrences"]), str(r["corrupted_count"]), str(r["accounted_count"]),
            str(sc["precomposed"]), str(sc["bare_pair"]), str(sc["latex_macro"]),
            str(sc["control_char"]), str(sc["glyph_six"]), str(sc["absent"]), str(sc["unanchored"]),
        ]
        print("\t".join(row))


main()
PYEOF
