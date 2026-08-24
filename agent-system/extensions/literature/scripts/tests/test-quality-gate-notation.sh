#!/usr/bin/env bash
# test-quality-gate-notation.sh - Five-fixture regression harness for
# sentence_boundary_glue_count()'s binder-notation exemption.
#
# Locks the count sentence_boundary_glue_count() (literature_quality_gate.py)
# reports for five real corpus documents, concatenated from their
# already-indexed, already-chunked markdown under
# ~/Projects/Literature/sources/{doc}/chunk_*.md:
#
#   - goodman_2024_higher_order_logic_as_metaphysics  (FALSE POSITIVE)
#   - bacon_a_case_for_higher_order_metaphysics       (FALSE POSITIVE)
#   - bacon_dorr_2024_classicism                       (TRUE POSITIVE, currently 0
#     on the already-remediated fallback-tier copy on disk -- see the true-positive
#     verification note below)
#   - hott_book_2013_homotopy_type_theory_univalent_foundations (MIXED, must stay
#     rejected)
#   - ahrens_north_shulman_tsementzis_the_univalence_principle  (MIXED, must stay
#     rejected)
#
# Chunks are joined with a blank-line separator ("\n\n"), NEVER concatenated
# raw. Raw concatenation glues the last character of one chunk directly onto
# the first character of the next chunk, which can silently manufacture (or
# suppress) an `[a-z]\.[A-Z]` boundary match that has nothing to do with the
# document's real content. This was verified empirically while building this
# harness: naive concatenation reported bacon_a_case=25 and bacon_dorr_2024=7,
# while "\n\n"-joined concatenation reported the correct 10 and 0 -- an exact
# match to the values below.
#
# Does NOT verify the true-positive fixture's genuine corruption is still
# caught on a FRESH primary-tier (pymupdf4llm) conversion -- the on-disk
# bacon_dorr_2024_classicism markdown is already-remediated fallback-tier
# output (see literature_quality_gate.py's sentence_boundary_glue_count
# docstring and FIND_SOURCES.md's "Quality-gate overrides" log), so its
# count here is expected to read 0 both before and after this fix. That
# verification is a distinct, pipeline-level check (see the plan's Phase 4)
# and is intentionally out of this harness's scope.
#
# This suite NEVER writes to ~/Projects/Literature/ -- read-only throughout,
# matching test-literature-convert.sh's corpus-safety convention.
#
# Corpus-absent behavior: if ~/Projects/Literature/sources/ does not exist,
# SKIP with a visible warning and exit 0 -- never silently pass, never
# hard-fail the suite for an environment that simply lacks the corpus.
#
# Usage:
#   agent-system/extensions/literature/scripts/tests/test-quality-gate-notation.sh
#
# Exit codes: 0 - all fixtures matched expectations (or corpus absent, skipped);
#             1 - a fixture's count drifted from its expected value.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
CORPUS_ROOT="${LITERATURE_CORPUS_ROOT:-$HOME/Projects/Literature}"
SOURCES_DIR="$CORPUS_ROOT/sources"

if [ ! -d "$SOURCES_DIR" ]; then
  echo "[test-quality-gate-notation] SKIP: corpus not found at $SOURCES_DIR" >&2
  echo "[test-quality-gate-notation] set LITERATURE_CORPUS_ROOT to point at a" \
       "Literature/ checkout to run this suite" >&2
  exit 0
fi

LITERATURE_QG_SCRIPT_DIR="$SCRIPT_DIR" LITERATURE_QG_SOURCES_DIR="$SOURCES_DIR" python3 <<'PYEOF'
import glob
import os
import sys

sys.path.insert(0, os.environ["LITERATURE_QG_SCRIPT_DIR"])
from literature_quality_gate import sentence_boundary_glue_count

sources_dir = os.environ["LITERATURE_QG_SOURCES_DIR"]

# Pre-fix baseline (Phase 1 of the implementation plan, against the
# UNMODIFIED gate) -- reproduced here exactly matching the research report's
# figures once chunks are joined with "\n\n" rather than concatenated raw
# (see the module docstring above). Phase 2 updates these two false-positive
# expectations to 0 once the refined exemption lands; the other three stay
# fixed for the life of this harness as over-exemption tripwires.
FIXTURES = {
    "goodman_2024": (
        "goodman_2024_higher_order_logic_as_metaphysics",
        "FALSE POSITIVE",
        7,
    ),
    "bacon_a_case": (
        "bacon_a_case_for_higher_order_metaphysics",
        "FALSE POSITIVE",
        10,
    ),
    "bacon_dorr_2024": (
        "bacon_dorr_2024_classicism",
        "TRUE POSITIVE (fallback-tier copy on disk; see Phase 4 for the fresh-conversion check)",
        0,
    ),
    "hott_book_2013": (
        "hott_book_2013_homotopy_type_theory_univalent_foundations",
        "MIXED (must stay rejected)",
        11,
    ),
    "ahrens_north": (
        "ahrens_north_shulman_tsementzis_the_univalence_principle",
        "MIXED (must stay rejected)",
        21,
    ),
}

failures = []
for short_name, (doc_dir, kind, expected) in FIXTURES.items():
    doc_path = os.path.join(sources_dir, doc_dir)
    chunk_paths = sorted(glob.glob(os.path.join(doc_path, "chunk_*.md")))
    if not chunk_paths:
        failures.append(
            f"{short_name}: no chunk_*.md files found under {doc_path!r} "
            f"(fixture document missing or not yet chunked)"
        )
        continue
    chunk_texts = []
    for chunk_path in chunk_paths:
        with open(chunk_path, encoding="utf-8") as f:
            chunk_texts.append(f.read())
    text = "\n\n".join(chunk_texts)
    got = sentence_boundary_glue_count(text)
    status = "PASS" if got == expected else "FAIL"
    print(
        f"[test-quality-gate-notation] {status}: {short_name} ({kind}) "
        f"expected={expected} got={got} ({len(chunk_paths)} chunks)"
    )
    if got != expected:
        failures.append(
            f"{short_name}: expected {expected}, got {got} "
            f"({len(chunk_paths)} chunks, doc={doc_dir})"
        )

if failures:
    print("\n[test-quality-gate-notation] FAILURES:", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    print(f"\n[test-quality-gate-notation] {len(failures)} failure(s)", file=sys.stderr)
    sys.exit(1)

print("\n[test-quality-gate-notation] All fixtures passed.")
PYEOF
exit $?
