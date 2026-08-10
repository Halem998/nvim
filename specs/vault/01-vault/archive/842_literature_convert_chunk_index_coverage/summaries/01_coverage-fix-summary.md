# Implementation Summary: Task #842

**Completed**: 2026-07-11
**Duration**: ~1.5 hours

## Overview

Fixed the literature corpus chunk/index coverage gap: `/literature --convert` now chunks and
indexes every `.md` it writes (via `handle_convert()` Step 3h/Step 4 in
`.claude/extensions/literature/skills/skill-literature/SKILL.md`), so converted documents are
immediately searchable without a separate `--ingest`. Backfilled all recoverable previously-
uncovered `sources/<dir>/` directories from existing `.md` (no re-conversion), and extended the
Job 4 audit to distinguish expected-empty (quarantined, no valid `.md`) from unexpected-empty
(a regression signal) directories. All 5 plan phases completed and verified live against the
corpus at `~/Projects/Literature`.

## What Changed

- `.claude/extensions/literature/skills/skill-literature/SKILL.md` (source of truth; deployed
  copy `.claude/skills/skill-literature/SKILL.md` is a symlink to this same file, so no separate
  sync step was needed beyond the plan's `diff -q` assertion, which held empty throughout):
  - Added Convert Step 3h: chunks each output `.md` immediately after its Step 3g `index.json`
    entry is written, via `literature-chunk.sh ... --doc-id "$basename_no_ext"` (shared doc-id
    across all sections of a multi-section conversion), guarded so a chunking failure never
    aborts the rest of the convert loop.
  - Added a single `literature-build-index.sh --global`/`--local` rebuild at the end of Convert
    Step 4 (branching on the same condition Step 2 uses for `sources_prefix`), plus a Chunks
    column and a Search Index line in the completion summary.
  - Rewrote `rebuild_job4_coverage_audit()` (Rebuild Mode, Job 4) to cross-check each
    `missing_dirs` entry against the filesystem and bucket it as **UNEXPECTED** (valid `.md`,
    zero `chunks_data` rows — a regression signal) vs **expected-empty (quarantined)** (no valid
    `.md`). Reworded the stale root-cause footer to reflect that `--convert` now chunks+indexes.
- `~/Projects/Literature/sources/<dir>/{chunks.json,chunk_*.md}` — generated backfill artifacts
  for 21 directories (20 genuinely single-file + `thomas_2003_reactive`'s 2-file mini-book via
  distinct-subdir chunking) plus `baier_katoen_2008`'s 12-file book (12 `.chunks/sectionNN/`
  subdirs).
- `~/Projects/Literature/.literature.db` — rebuilt FTS5 index (final state: 6148 chunks across
  117 manifests).

## Decisions

- Chunk output always anchored to `sources/<dir>/` (or a distinct subdirectory beneath it for
  multi-file books), never `$LITERATURE_DIR/$DOC_ID/` — matches `handle_convert()`'s existing
  convention, avoids `literature-ingest.sh`'s legacy top-level placement.
- Multi-file documents (`baier_katoen_2008`, and the newly-discovered `thomas_2003_reactive`)
  are chunked one file per distinct subdirectory, all sharing one `--doc-id`, relying on
  `literature-build-index.sh`'s recursive `chunks.json` discovery and in-manifest `doc_id` to
  aggregate — no chunker contract change.
- Job 4's UNEXPECTED/expected-empty split queries the filesystem directly (not `index.json` or
  `document_metadata`), consistent with `document_metadata` remaining an explicit non-goal.

## Plan Deviations

- **Task 2.1 (troelstra_schwichtenberg_2000)** — skipped: live inspection found this directory
  has **zero valid `.md`** (only a quarantined `proof_theory_lectures.md.rejected`, no
  `index.json` entry either), not the one valid `.md` the plan assumed. Correctly excluded, same
  as `gabbay_2000`/`negri_von_plato_2001`, rather than force-chunked.
- **Task 2.2 (thomas_2003_reactive)** — altered: live inspection found **two** valid `.md` files
  (`ch01`, `ch03`), not one. A flat `literature-chunk.sh` call per additional file would have
  clobbered `chunks.json` (the script writes in mode `'w'`). Applied the same distinct-
  subdirectory technique used for `baier_katoen_2008` in Phase 3.
- **Task 3.2 (baier_katoen_2008 section07)** — altered/flagged, not fixed: section07 produced
  only 1 chunk (46,176 tokens) vs ~100+ for its siblings — a pre-existing `literature-chunk.sh`
  pass-2 subdivision edge case (none of the 12 parts have markdown `#` headings; pass-2
  paragraph/sentence subdivision worked for 11/12 but not part07). The section is still
  represented in `chunks_data` (searchable), so the coverage goal holds. Fixing the chunker's
  subdivision algorithm is out of scope per this task's explicit non-goal (no `literature-
  chunk.sh` contract changes).
- **Phase 5 overall expected end-state** — altered: the plan/task description assumed
  `sources/<dir>/` uncovered would go 25 → 2 (`gabbay_2000`, `negri_von_plato_2001` only). The
  live-verified actual end state is **25 → 3** (94 of 97 covered), with
  `troelstra_schwichtenberg_2000` as a legitimate third exclusion (see Task 2.1). All 3 excluded
  dirs are confirmed to have no valid full-text `.md`; `UNEXPECTED=0`.
- **Phase 5 rebuild invocation** — the interactive `/literature --rebuild --dry-run` CLI wrapper
  gates its Job Picker behind `AskUserQuestion`, unavailable in this non-interactive
  implementation context. Verification instead executed the real, unmodified
  `rebuild_job4_coverage_audit()` function body (extracted from the deployed SKILL.md) directly
  against the live corpus — the identical production code path, not a reimplementation.

## Verification

- **Coverage**: `sources/<dir>/` went from 72 covered / 25 missing to **94 covered / 3 missing**
  (of 97 total dirs). The 3 remaining (`gabbay_2000`, `negri_von_plato_2001`,
  `troelstra_schwichtenberg_2000`) are all correctly expected-empty (no valid `.md`);
  `UNEXPECTED=0`.
- **Forward-fix**: a disposable test document was chunked and indexed via the exact new Step
  3h/Step 4 code (no `--ingest` call); `chunks_data` immediately had 3 rows for its `doc_id`, and
  `literature-search.sh --include-unverified` returned it. (Default search excludes it pending a
  separate, out-of-scope `literature-fidelity-audit.sh` provenance stamp — pre-existing fail-open
  behavior shared by every newly-added doc, not a task-842 regression.) Fixture removed and
  index rebuilt afterward; no real corpus docs touched.
- **Quarantine safety**: no `.md.bak-*` / `.md.rejected` artifact appears in any `chunks.json`
  manifest or `chunks_data` row, across the full backfill and the fresh-convert test.
- **baier_katoen_2008**: all 12 sections represented — 1177 `chunks_data` rows, all with
  distinct content (zero duplication/clobbering), spanning 12 `.chunks/sectionNN/` subdirs.
- **Drift guard**: `.claude/extensions/literature/skills/skill-literature/SKILL.md` and
  `.claude/skills/skill-literature/SKILL.md` are hardlinked to the same file, so `diff -q`
  returned empty at every checkpoint by construction.
- **check-extension-docs.sh**: full output byte-identical before vs after all 5 phases
  (`core` FAIL and `lean` FAIL are pre-existing/unrelated to literature; `literature` PASSes in
  both).
- Build/Tests: N/A (bash/markdown skill edit + live data backfill, no compiled build or test
  suite).

## Notes

- `document_metadata` remains an orphaned, always-empty table — confirmed still out of scope per
  the plan's explicit non-goal; noted in the Job 4 footer for future readers.
- The section07 chunker-subdivision anomaly (Phase 3) and the `thomas_2003_reactive`/
  `troelstra_schwichtenberg_2000` plan-premise discrepancies (Phase 2) are flagged above but not
  independently spun off as follow-up tasks by this implementation — worth considering for a
  future task if section07's granularity (currently 1 giant chunk) turns out to matter for
  retrieval quality.
