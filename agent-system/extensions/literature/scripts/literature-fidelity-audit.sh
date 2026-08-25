#!/usr/bin/env bash
# literature-fidelity-audit.sh - Re-runnable provenance/fidelity detector and stamper
# for the ~/Projects/Literature corpus.
#
# Usage:
#   literature-fidelity-audit.sh [--dry-run]   # report-only (default): classify every
#                                               # sources/<dir>/ and print a TSV/JSON
#                                               # report to stdout. index.json is never
#                                               # touched.
#   literature-fidelity-audit.sh --write       # backup index.json, then idempotently
#                                               # stamp .provenance_fidelity and
#                                               # .word_ratio onto every parent entry
#                                               # (see "Target entry resolution" below).
#
# What this computes (see report 01_provenance-fidelity-audit.md for full rationale):
#   For each sources/<dir>/ directory, classify into one of five provenance_fidelity
#   values using a conservative three-signal detector:
#     1. Whole-DOCUMENT word-ratio (md_words summed over ALL .md in the dir, divided by
#        pdf_words summed over ALL *.pdf/*.djvu in the dir via `pdftotext -layout`).
#        NEVER sampled from a single file — single-file sampling is a known false-
#        discriminator (see report "Correction to Pre-Verified Evidence").
#     2. Disclosure check (only when ratio < 0.75): does the .md content or the
#        matching index.json summary text admit to being a selective/partial
#        conversion? If so -> verified_conversion (disclosed partial).
#     3. Proof/body-completeness check (only when ratio < 0.75 and undisclosed): for
#        headings matching Definition/Lemma/Theorem/Proposition/Corollary N[.N...],
#        Lemma/Theorem/Proposition/Corollary headings are adequate only if an explicit
#        "Proof" marker follows in their body (a claim without a proof is not proved,
#        regardless of how many lines it spans); Definition headings are adequate if
#        they carry real defining content (>=2 non-blank lines or >=15 words). If the
#        fraction of adequate numbered statements is below 0.6 -> unverified_summary.
#
#   `chunk_*.md` filename presence/absence and a standalone leading "## Overview"
#   heading are deliberately NOT used as signals (both are false discriminators in
#   this corpus — see report). This is intentional; do not add them back without
#   re-reading the report's "Detector Design" section.
#
# Six-value enum: verified_conversion, unverified_summary, no_source_pdf,
# not_yet_converted, unverified_no_baseline, unadjudicated.
#
# Target entry resolution (which index.json entries get stamped):
#   A directory's entries are all index.json entries whose `.path` starts with
#   "sources/<dir>/" (robust to id-naming drift — some directories host multiple
#   independent top-level docs, e.g. thomas_2003_reactive -> thomas_2003_ch01 +
#   thomas_2003_ch03, each stamped independently with the SAME directory-aggregated
#   ratio). Among matched entries:
#     - If any matched entry has no `parent_doc` (a true root), stamp only those root
#       entries. This is the common case and matches the plan's "parent entries only"
#       design exactly.
#     - If NO matched entry is a root (a pre-existing, orthogonal corpus data gap: some
#       directories' children carry a `parent_doc` value with no corresponding
#       top-level `id` row at all — e.g. doets_1987, venema_1991, thomason_1984 in the
#       current corpus), fall back to stamping every matched child entry directly. This
#       is a deliberate, documented deviation from a strict "parent-only" reading,
#       necessary so that literature-search.sh's per-chunk doc_id lookup (which will
#       return one of these child rows) resolves the correct fidelity value instead of
#       fail-open-defaulting an entire legitimate disclosed-partial document to
#       unverified. See the implementation summary for the full directory list this
#       applies to.
#     - If no entry's path matches the directory at all, nothing is stamped (the
#       directory has no index.json presence yet); this is reported, not treated as an
#       error.
#   Only entries under sources/<dir>/ are ever touched. Entries using the unrelated
#   legacy `doc_id`/`chunks_dir` schema (no `path`/`id` fields, from a different
#   ingestion pipeline, live outside sources/) are never matched or written. This
#   exclusion no longer covers new ingests as of literature-ingest.sh's sources/<id>/
#   placement fix: every document written by the current ingest pipeline lands inside
#   sources/ and is eligible for fidelity stamping. The exclusion remains real for any
#   pre-existing entry that still predates that fix and was never migrated. See
#   context/project/literature/domain/literature-index.md's "FTS Namespace and the
#   Never-Rename Invariant" section for the full sources/-placement rationale.
#
# Idempotency: re-running --write on an already-stamped corpus is a no-op relative to
# the first --write's output (same values, stable key order, no diff). The FIRST
# --write will reformat the whole file (json.dump normalizes indentation/unicode
# escaping across all 280 entries, not just the ~100 stamped ones) since a full
# parse/re-serialize is required to add fields; this is a one-time, backed-up,
# content-preserving formatting normalization, not a data change.
#
# Safety:
#   - Backup-first: index.json is copied to index.json.bak.<UTC timestamp> and the
#     copy is verified byte-identical before any write proceeds.
#   - Atomic: writes go to a temp file in the same directory, then `mv` over
#     index.json.
#   - Fail-open is a RETRIEVAL-side property (literature-search.sh / literature-
#     briefing.sh treat an absent field as unverified). This script's own job is only
#     to compute and stamp; it does not implement fail-open itself.
#   - Never touches anything under sources/ (read-only pdftotext/wc access only).
#   - Never deletes any entry, PDF, or markdown file. Quarantine is a retrieval-time
#     concern handled entirely by the two retrieval scripts.
#
# Environment:
#   LITERATURE_DIR  Path to the global Literature/ repo (default: ~/Projects/Literature)

set -euo pipefail

LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
MODE="report"

usage() {
  cat <<'EOF'
Usage: literature-fidelity-audit.sh [--dry-run|--write] [-h|--help]

  --dry-run   Report-only (default). Classify every sources/<dir>/ and print a
              per-directory report to stdout. index.json is never modified.
  --write     Backup index.json, then idempotently stamp provenance_fidelity and
              word_ratio onto the resolved target entries for every directory.
  -h, --help  Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --write)
      MODE="write"
      ;;
    --dry-run | --report)
      MODE="report"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
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

INDEX_FILE="$LITERATURE_DIR/index.json"
if [ ! -f "$INDEX_FILE" ]; then
  echo "Error: index.json not found: $INDEX_FILE" >&2
  exit 1
fi

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "Error: pdftotext not found on PATH (required for word-ratio computation)" >&2
  exit 1
fi

BACKUP_FILE=""
if [ "$MODE" = "write" ]; then
  ts="$(date -u +%Y%m%d-%H%M%S)"
  BACKUP_FILE="$INDEX_FILE.bak.$ts"
  cp -p "$INDEX_FILE" "$BACKUP_FILE"
  if ! cmp -s "$INDEX_FILE" "$BACKUP_FILE"; then
    echo "Error: backup verification failed ($BACKUP_FILE does not match $INDEX_FILE); aborting, no write performed" >&2
    exit 1
  fi
  echo "[fidelity-audit] Backup created and verified: $BACKUP_FILE" >&2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LITERATURE_DIR="$LITERATURE_DIR" \
SOURCES_DIR="$SOURCES_DIR" \
INDEX_FILE="$INDEX_FILE" \
MODE="$MODE" \
LITERATURE_SCRIPT_DIR="$SCRIPT_DIR" \
python3 <<'PYEOF'
import json
import os
import re
import subprocess
import sys
from collections import Counter

LITERATURE_DIR = os.environ["LITERATURE_DIR"]
SOURCES_DIR = os.environ["SOURCES_DIR"]
INDEX_FILE = os.environ["INDEX_FILE"]
MODE = os.environ["MODE"]

# Additive combining-mark (U+0338) signal (kept DISTINCT from pdf_word_count()'s
# pdftotext -layout call below -- pdftotext itself substitutes a literal digit
# "6" for the overlay mark and cannot serve as ground truth for this check; see
# literature-combining-audit.sh's header for the full rationale). Reuses the
# same PyMuPDF-based detection/anchoring module the standalone detector and
# repair engine use, so this script's combining-mark numbers are never a
# second, independently-drifting implementation.
sys.path.insert(0, os.environ["LITERATURE_SCRIPT_DIR"])
try:
    from literature_combining_detect import scan_directory as _combining_scan_directory
    _COMBINING_CHECK_AVAILABLE = True
except ImportError as e:
    print(f"[warn] literature_combining_detect not importable, combining-mark "
          f"check disabled for this run: {e}", file=sys.stderr)
    _COMBINING_CHECK_AVAILABLE = False


def combining_mark_check(dirpath, dirname):
    """Returns (checked: bool, dropped: bool|None, missing: int|None). Only
    meaningful when the directory has both a PDF and non-chunk markdown (the
    same precondition the standalone detector requires); otherwise
    checked=False and the other two fields are None (not 0 -- "not checked" is
    a distinct, undisclosed state from "checked, zero dropped")."""
    if not _COMBINING_CHECK_AVAILABLE:
        return False, None, None
    try:
        result = _combining_scan_directory(dirpath, dirname, on_no_markdown=None)
    except Exception as e:
        print(f"[warn] combining-mark check failed for {dirname}: {e}", file=sys.stderr)
        return False, None, None
    if result is None:
        return False, None, None
    missing = result["corrupted_count"]
    return True, missing > 0, missing

RATIO_THRESHOLD = 0.75
PROOF_ADEQUACY_THRESHOLD = 0.6

DISCLOSURE_RE = re.compile(
    r"selective conversion|extracted:?\s*chapter|truncated|excerpt|chapters?\s+\d+\s+and\s+\d+",
    re.IGNORECASE,
)
HEADING_RE = re.compile(
    r"^(#+)\s*(Definition|Lemma|Theorem|Proposition|Corollary)\s+([\d.]+)", re.IGNORECASE
)
PROOF_MARKER_RE = re.compile(r"\bProof\b", re.IGNORECASE)


def word_count_text(text):
    return len(text.split())


def pdf_word_count(pdf_path):
    if pdf_path.lower().endswith(".djvu"):
        # No djvutxt dependency assumed available; no .djvu files exist in the
        # current corpus. Best-effort: skip (contributes 0 words) rather than
        # crash, with a warning so a future .djvu addition is visible.
        print(f"[warn] .djvu extraction not implemented, skipping: {pdf_path}", file=sys.stderr)
        return 0
    try:
        out = subprocess.run(
            ["pdftotext", "-layout", pdf_path, "-"],
            capture_output=True, text=True, timeout=180,
        )
        return word_count_text(out.stdout)
    except Exception as e:
        print(f"[warn] pdftotext failed for {pdf_path}: {e}", file=sys.stderr)
        return 0


def disclosure_check(md_texts, index_summaries):
    combined = "\n".join(md_texts) + "\n" + "\n".join(index_summaries)
    return bool(DISCLOSURE_RE.search(combined))


def proof_completeness_fraction(md_texts):
    """Fraction of numbered Definition/Lemma/Theorem/Proposition/Corollary headings
    (across all .md files of the document) that have an adequate body before the
    next equal-or-higher-level heading.

    Lemma/Theorem/Proposition/Corollary are *claims*: adequate only if an explicit
    'Proof' marker appears directly in the body. A list of unproved clauses with no
    'Proof' text is NOT adequate no matter how many lines it spans -- this is the
    decisive discriminator for a hand-authored paraphrase that states results
    without proving them (see report exemplar: Lemma 3.2 in rabinovich_2014, three
    bare unproved clauses).

    Definition headings are not claims and carry no proof; adequate if the body has
    real defining content (>=2 non-blank lines or >=15 words), not a one-line gloss.
    """
    total = 0
    adequate = 0
    for text in md_texts:
        lines = text.splitlines()
        i, n = 0, len(lines)
        while i < n:
            m = HEADING_RE.match(lines[i])
            if m:
                level = len(m.group(1))
                heading_type = m.group(2).lower()
                total += 1
                j = i + 1
                body_lines = []
                while j < n:
                    hm = re.match(r"^(#+)\s", lines[j])
                    if hm and len(hm.group(1)) <= level:
                        break
                    body_lines.append(lines[j])
                    j += 1
                body_text = "\n".join(body_lines)
                nonblank = [ln for ln in body_lines if ln.strip()]
                has_proof_marker = bool(PROOF_MARKER_RE.search(body_text))

                if heading_type == "definition":
                    is_adequate = len(nonblank) >= 2 or word_count_text(body_text) >= 15
                else:
                    is_adequate = has_proof_marker

                if is_adequate:
                    adequate += 1
                i = j
            else:
                i += 1
    if total == 0:
        return None, 0, 0
    return adequate / total, adequate, total


def load_index_entries():
    with open(INDEX_FILE, encoding="utf-8") as f:
        idx = json.load(f)
    return idx


def summaries_for_dir(idx, dirname):
    prefix = f"sources/{dirname}/"
    out = []
    for e in idx.get("entries", []):
        p = e.get("path")
        if isinstance(p, str) and p.startswith(prefix) and e.get("summary"):
            out.append(e["summary"])
    return out


def classify_dir(dirname, idx):
    dirpath = os.path.join(SOURCES_DIR, dirname)
    try:
        entries_on_disk = os.listdir(dirpath)
    except OSError as e:
        print(f"[warn] cannot list {dirpath}: {e}", file=sys.stderr)
        entries_on_disk = []

    pdfs = sorted(
        os.path.join(dirpath, e) for e in entries_on_disk
        if e.lower().endswith((".pdf", ".djvu"))
    )
    mds = sorted(
        os.path.join(dirpath, e) for e in entries_on_disk
        if e.lower().endswith(".md")
        and not re.match(r"^chunk_\d+\.md$", e, re.IGNORECASE)
    )

    has_pdf = len(pdfs) > 0
    has_md = len(mds) > 0

    # Additive signal, computed once regardless of which provenance_fidelity
    # branch below fires -- reported ALONGSIDE provenance_fidelity, never
    # folded into the ratio>=RATIO_THRESHOLD gate or the six-value enum.
    combining_checked, combining_dropped, combining_missing = combining_mark_check(dirpath, dirname)

    result = {
        "dir": dirname,
        "has_pdf": has_pdf,
        "has_md": has_md,
        "pdf_words": None,
        "md_words": None,
        "word_ratio": None,
        "proof_fraction": None,
        "disclosed": None,
        "provenance_fidelity": None,
        "combining_mark_checked": combining_checked,
        "combining_mark_dropped": combining_dropped,
        "combining_marks_missing": combining_missing,
    }

    if not has_pdf and has_md:
        result["provenance_fidelity"] = "no_source_pdf"
        return result
    if has_pdf and not has_md:
        result["provenance_fidelity"] = "not_yet_converted"
        return result
    if not has_pdf and not has_md:
        # Anomalous (empty or non-pdf/md-only directory). Fail open: never
        # silently "verified".
        result["provenance_fidelity"] = "unverified_no_baseline"
        return result

    md_texts = []
    md_words_total = 0
    for md in mds:
        t = ""
        try:
            with open(md, encoding="utf-8", errors="replace") as f:
                t = f.read()
        except OSError as e:
            print(f"[warn] read failed for {md}: {e}", file=sys.stderr)
        md_texts.append(t)
        md_words_total += word_count_text(t)

    pdf_words_total = sum(pdf_word_count(p) for p in pdfs)

    result["md_words"] = md_words_total
    result["pdf_words"] = pdf_words_total

    if pdf_words_total == 0:
        result["provenance_fidelity"] = "unverified_no_baseline"
        return result

    ratio = md_words_total / pdf_words_total
    result["word_ratio"] = round(ratio, 4)

    if ratio >= RATIO_THRESHOLD:
        result["provenance_fidelity"] = "verified_conversion"
        return result

    index_summaries = summaries_for_dir(idx, dirname)
    disclosed = disclosure_check(md_texts, index_summaries)
    result["disclosed"] = disclosed
    if disclosed:
        result["provenance_fidelity"] = "verified_conversion"
        return result

    frac, adequate, total = proof_completeness_fraction(md_texts)
    result["proof_fraction"] = frac
    if frac is None:
        # No numbered statements to check at all: the proof-completeness signal
        # cannot fire. This is the ABSENCE of a signal, not a positive finding --
        # a low-ratio, undisclosed document with no numbered statements to check
        # has not been adjudicated by any of the three signals. Fail CLOSED:
        # stamp "unadjudicated" rather than reading silence as a pass. (Task
        # #839 fix -- previously fell through to verified_conversion here, which
        # was a fail-open misclassification; see report 01_provenance-fidelity-audit.md
        # and specs/839_fix_fidelity_audit_fail_open/ for the realized-risk record.)
        result["provenance_fidelity"] = "unadjudicated"
        return result

    if frac < PROOF_ADEQUACY_THRESHOLD:
        result["provenance_fidelity"] = "unverified_summary"
    else:
        result["provenance_fidelity"] = "verified_conversion"
    return result


def resolve_targets(idx, dirname):
    """Return (target_entries, resolution_kind) for a directory. See the script
    header's "Target entry resolution" section for the full rationale."""
    prefix = f"sources/{dirname}/"
    matched = [
        e for e in idx.get("entries", [])
        if isinstance(e.get("path"), str) and e["path"].startswith(prefix) and "id" in e
    ]
    if not matched:
        return [], "no_match"
    roots = [e for e in matched if not e.get("parent_doc")]
    if roots:
        return roots, "root"
    return matched, "phantom_parent_fallback"


def main():
    idx = load_index_entries()

    dirs = sorted(
        d for d in os.listdir(SOURCES_DIR)
        if os.path.isdir(os.path.join(SOURCES_DIR, d))
    )

    results = []
    for d in dirs:
        r = classify_dir(d, idx)
        results.append(r)

    counts = Counter(r["provenance_fidelity"] for r in results)

    print("dir\tprovenance_fidelity\tword_ratio\tmd_words\tpdf_words\tdisclosed\tproof_fraction"
          "\tcombining_mark_checked\tcombining_mark_dropped\tcombining_marks_missing")
    for r in results:
        print(
            f"{r['dir']}\t{r['provenance_fidelity']}\t{r['word_ratio']}\t"
            f"{r['md_words']}\t{r['pdf_words']}\t{r['disclosed']}\t{r['proof_fraction']}\t"
            f"{r['combining_mark_checked']}\t{r['combining_mark_dropped']}\t{r['combining_marks_missing']}"
        )

    print("\n--- Population summary ---", file=sys.stderr)
    for k in ("verified_conversion", "unverified_summary", "no_source_pdf",
              "not_yet_converted", "unverified_no_baseline", "unadjudicated"):
        print(f"{k}: {counts.get(k, 0)}", file=sys.stderr)
    print(f"Total directories: {len(results)}", file=sys.stderr)

    combining_checked_n = sum(1 for r in results if r["combining_mark_checked"])
    combining_dropped_n = sum(1 for r in results if r["combining_mark_dropped"])
    print(f"\n--- Combining-mark signal (additive, informational) ---", file=sys.stderr)
    print(f"directories checked: {combining_checked_n}", file=sys.stderr)
    print(f"directories with dropped marks: {combining_dropped_n}", file=sys.stderr)

    if MODE != "write":
        return

    stamped = 0
    changed = 0
    unchanged = 0
    no_match_dirs = []
    phantom_fallback_dirs = []

    for r in results:
        targets, kind = resolve_targets(idx, r["dir"])
        if kind == "no_match":
            no_match_dirs.append(r["dir"])
            continue
        if kind == "phantom_parent_fallback":
            phantom_fallback_dirs.append((r["dir"], len(targets)))
        for e in targets:
            prev_fidelity = e.get("provenance_fidelity")
            prev_ratio = e.get("word_ratio")
            prev_combining_checked = e.get("combining_mark_checked")
            prev_combining_dropped = e.get("combining_mark_dropped")
            prev_combining_missing = e.get("combining_marks_missing")
            new_fidelity = r["provenance_fidelity"]
            new_ratio = r["word_ratio"]
            new_combining_checked = r["combining_mark_checked"]
            new_combining_dropped = r["combining_mark_dropped"]
            new_combining_missing = r["combining_marks_missing"]
            if (prev_fidelity == new_fidelity and prev_ratio == new_ratio
                    and prev_combining_checked == new_combining_checked
                    and prev_combining_dropped == new_combining_dropped
                    and prev_combining_missing == new_combining_missing):
                unchanged += 1
            else:
                changed += 1
            e["provenance_fidelity"] = new_fidelity
            e["word_ratio"] = new_ratio
            e["combining_mark_checked"] = new_combining_checked
            e["combining_mark_dropped"] = new_combining_dropped
            e["combining_marks_missing"] = new_combining_missing
            stamped += 1

    tmp_path = INDEX_FILE + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(idx, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_path, INDEX_FILE)

    print("\n--- Write summary ---", file=sys.stderr)
    print(f"Entries stamped (total writes): {stamped}", file=sys.stderr)
    print(f"  changed:   {changed}", file=sys.stderr)
    print(f"  unchanged: {unchanged}", file=sys.stderr)
    print(f"Directories with no matching index entry (skipped, nothing to stamp): {len(no_match_dirs)}", file=sys.stderr)
    for d in no_match_dirs:
        print(f"  {d}", file=sys.stderr)
    print(f"Directories using phantom-parent fallback (stamped onto child entries directly): {len(phantom_fallback_dirs)}", file=sys.stderr)
    for d, n in phantom_fallback_dirs:
        print(f"  {d} ({n} entries)", file=sys.stderr)


if __name__ == "__main__":
    main()
PYEOF
