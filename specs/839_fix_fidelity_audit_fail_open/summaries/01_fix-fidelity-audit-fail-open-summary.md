# Implementation Summary: Task #839

**Completed**: 2026-07-10T00:06:00Z
**Duration**: ~45 minutes

## Overview

Fixed the fail-open classification bug in `classify_dir()` (`.claude/scripts/literature-fidelity-audit.sh`): when the proof-completeness signal cannot fire (`frac is None`) on a low-ratio, undisclosed document, the script previously stamped `verified_conversion` — reading the absence of a signal as a pass. Introduced a sixth enum value, `unadjudicated`, assigned by that branch instead (fail closed), widened the two real downstream consumers so the new value is not silently trusted one script over, fixed a `chunk_*.md` double-counting defect in the word-ratio computation, explicitly resolved a 4th live victim (`thomas_2003_reactive`) via a truthful disclosure banner, re-stamped the live corpus, and corrected two stale records in task #835's report.

## What Changed

- `.claude/scripts/literature-fidelity-audit.sh` — the `frac is None` branch now assigns `"unadjudicated"` instead of `"verified_conversion"`; header enum contract updated to six values; `main()`'s population-summary tuple includes `unadjudicated`; the `mds` glob (word-ratio computation) now excludes `chunk_NNNN.md` re-split files, fixing a word-count double-count that produced spurious `word_ratio > 1` values.
- `.claude/scripts/literature-search.sh` — `QUARANTINED_FIDELITY_VALUES` widened to include `unadjudicated` (line 51), so unadjudicated docs are excluded from default search ranking like the other unverified values.
- `.claude/scripts/literature-briefing.sh` — `needs_fidelity_marker()`'s allowlist widened to include `unadjudicated` (line 112), so `--lit` briefings show the warning banner for unadjudicated docs instead of silently omitting it (this was the same class of fail-open bug, one script downstream, not previously flagged by the task description).
- `~/Projects/Literature/index.json` (outside the repo, not git-tracked) — `.summary` fields for `thomas_2003_ch01` and `thomas_2003_ch03` gained a truthful scope-disclosure banner ("Selective conversion: chapters 1 and 3 of the lecture notes only; some ligature/OCR garbling from the source PDF...") so `thomas_2003_reactive` resolves via the legitimate disclosure branch. Backed up before edit (byte-verified) and again before each `--write`. Re-stamped via `--write` (idempotent, confirmed via a second `--write` run producing a byte-identical file).
- `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md` — the "residual risk" bullet (line 118) now records that the gap was realized (not merely theoretical), naming the 3 victim directories plus the disclosure-detection miss on `venema_1991`, and cross-references task #839. The `thomas_2003_reactive` cohort-table row (line 71) now records the recommendation as IMPLEMENTED via the Option A banner.
- `.claude/context/project/literature/patterns/chunk-file-conventions.md` — new pattern file documenting that `chunk_NNNN.md` files are index-only re-splits and must be excluded from whole-document word/content computations, to prevent this defect class from recurring.

## Decisions

- **`thomas_2003_reactive` resolved via Option A** (add a factually accurate disclosure banner), per the plan's named decision. The banner text is grounded in task #835's own prior adjudication of this directory as a legitimate partial conversion with real, proved theorem content. Verified live: `--dry-run` shows `verified_conversion`, `disclosed=True`. No Option-B fallback was needed.
- **The `chunk_*.md` double-count was fixed at the root** (excluded from the `mds` glob) rather than by adding an arbitrary upper-bound ratio threshold, per the plan's explicit Non-Goal. A full 97-directory `--dry-run` diff before/after the glob change showed exactly 5 rows changed, all expected (3 ratio>1 dirs collapsed to ~0.96–1.07; 2 already-`unadjudicated` low-ratio dirs got lower, more honest ratios with no classification change); no unexpected classification flips anywhere in the cohort.
- **`literature-build-index.sh` was confirmed out of scope** (zero references to `provenance_fidelity`) and left untouched, per the plan's constraint.
- **Cross-reference to task #832**: #832 (`reconvert_and_validate_literature_corpus`) runs immediately after this task and its cohort logic reads `provenance_fidelity` from the live `index.json`. No code change was required in #832's artifacts (they do not hard-code the enum string set), but the corrected `unadjudicated` value is now live and correctly stamped in `~/Projects/Literature/index.json` before #832 runs, resolving the ordering dependency the plan flagged.

## Plan Deviations

- **Phase 7, optional item (partial)**: the plan's optional Phase 7 step asked to "update the one prose reference to the enum in `zotero-pdf-resolution.md` from five to six values." On inspection, that file's one `provenance_fidelity` reference (line 5) is a generic cross-reference with no enumerated value count in it — there was nothing stale to correct, so no edit was made there. The other half of that optional step (the chunk-convention pattern note) was completed as `.claude/context/project/literature/patterns/chunk-file-conventions.md`.

No other deviations — all 7 phases and all named verification invariants were completed and confirmed exactly as planned.

## Verification

- Build: N/A (bash/Python scripts, no build step)
- Tests: N/A (no test suite for these scripts; verification performed via live `--dry-run`/`--write` runs against the corpus, per the plan's verification contract)
- Files verified: Yes
- Full invariant contract (Phase 6), all confirmed via live `--dry-run`:
  - `fine_2012_guide-to-ground`, `fine_2012_counterfactuals-without-possible-worlds`, `venema_1991` -> `unadjudicated`
  - `doets_1987` (ratio 0.2378), `libkin_2004_ch3_ch7` (ratio 0.0187) -> `verified_conversion`, `disclosed=True`
  - `rabinovich_2014` -> `unverified_summary`, `proof_fraction=0.5454...`
  - `fine_2010_some-puzzles-of-ground` (1.0741), `fine_2012_pure-logic-of-ground` (0.9962), `bacon_2018_broadest-necessity` (1.0) -> `verified_conversion`
  - `thomas_2003_reactive` -> `verified_conversion`, `disclosed=True`
- `--write` re-stamped the live corpus (153 entries stamped: 14 changed, 139 unchanged on the first honest re-stamp) and was confirmed idempotent (second `--write`: 0 changed, 153 unchanged; byte-for-byte identical `index.json` diff).
- Population summary after re-stamp: `verified_conversion: 39, unverified_summary: 1, no_source_pdf: 45, not_yet_converted: 5, unverified_no_baseline: 4, unadjudicated: 3` (total 97 directories).

## Notes

- `~/Projects/Literature/index.json` lives outside this git repository and is not tracked by git; it was backed up (byte-verified) before the disclosure-banner edit and again automatically by the script before each `--write` (`index.json.bak.20260709-232631`, `index.json.bak.20260709-232736`).
- Task #832 (`reconvert_and_validate_literature_corpus`), which runs immediately after this task, reads `provenance_fidelity` from the now-corrected live `index.json`. No code change was needed in #832's artifacts; the ordering dependency the plan flagged is satisfied.
- A pre-existing, unrelated corpus quirk was encountered during verification: some `index.json` entries have a `null` `.id` or `.path` field, which causes `jq`'s `test()` regex function to error (exit code 5) when applied directly without a null-coalescing guard (e.g. `select(.id|test(...))`). This is orthogonal to task #839 and was worked around during verification with `select((.id // "")|test(...))`; not fixed as it is out of this task's scope.
