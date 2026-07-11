# Implementation Plan: Task #842

- **Task**: 842 - Fix the literature corpus chunk/index coverage gap (convert never chunks/indexes)
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: #840 (Job 4 audit that surfaced the gap), #841 (extension/deployed drift reconciliation — still holding)
- **Research Inputs**: specs/842_literature_convert_chunk_index_coverage/reports/01_coverage-gap-research.md
- **Artifacts**: plans/01_coverage-fix-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/literature --convert` writes a `.md` plus an `index.json` entry via `handle_convert()` in
`.claude/extensions/literature/skills/skill-literature/SKILL.md`, but never invokes
`literature-chunk.sh` or `literature-build-index.sh`, so converted documents are invisible to
`literature-search.sh`. This plan (1) wires the chunk+index step into `handle_convert()` so the
forward path self-heals, (2) backfills the 23 existing uncovered-but-recoverable `sources/<dir>/`
directories (22 single-file + the 12-file book `baier_katoen_2008`), (3) extends the Job 4 audit to
distinguish expected-empty (quarantined) from unexpected-empty directories, and (4) verifies the
whole thing end-to-end. Definition of done: `/literature --rebuild --dry-run` Job 4 reports the
23 formerly-missing dirs as covered, `gabbay_2000` and `negri_von_plato_2001` remain correctly
excluded (no valid `.md`), and a freshly `--convert`ed test doc is searchable without a separate
`--ingest`.

### Research Integration

Root cause and approach are taken directly from `reports/01_coverage-gap-research.md`:
- The fix belongs in `handle_convert()` (SKILL.md, Mode: Convert), **not** in `literature-convert.sh`
  — the latter is never called by `--convert` and is convert-only by design.
- `literature-build-index.sh --global` discovers **all** `chunks.json` recursively and keys each
  chunk's `doc_id` from inside the manifest (`chunk.get('doc_id')`), confirmed by reading the
  script (`find "$target_dir" -name "chunks.json"`, lines 90-91; `doc_id = chunk.get('doc_id')`,
  line 152). This is why the multi-file book needs no manifest-merge — distinct subdirs with a
  shared `--doc-id` aggregate naturally.
- `document_metadata` is an orphaned, always-empty table (zero writers anywhere) and is an
  explicit **non-goal** here (see Goals & Non-Goals).
- Hazard (a): chunk only **explicit known-good `.md` paths**, never directory globs, so quarantine
  artifacts (`.md.bak-*`, `.md.rejected`) can never be chunked.
- Hazard (b): both the wiring fix and backfill must target `sources/<dir>/`, following
  `handle_convert()`'s existing `sources_prefix` convention — never replicate
  `literature-ingest.sh`'s legacy top-level `$LITERATURE_DIR/$DOC_ID/` placement.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (meta task; `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- Forward fix: `handle_convert()` chunks and indexes every `.md` it writes, using the existing
  `literature-chunk.sh` / `literature-build-index.sh` scripts (no duplicated chunk/FTS logic).
- Backfill the 23 recoverable uncovered directories from their existing `.md` files (no
  re-conversion), including `baier_katoen_2008`'s 12 section files under one `doc_id`.
- Extend Job 4 so future regressions are self-diagnosing (expected-empty vs unexpected-empty).
- Keep the extension source (`.claude/extensions/literature/`) and deployed copy
  (`.claude/skills/skill-literature/SKILL.md`) byte-identical so the #841 drift guard stays green.

**Non-Goals**:
- Do **not** populate or fix the orphaned `document_metadata` table (separate pre-existing
  dead-table bug; out of scope, flagged only). If desired, spin off a follow-up task.
- Do **not** touch `literature-convert.sh` (not on the `--convert` path).
- Do **not** re-convert any PDF/DJVU; backfill uses existing `.md` only.
- Do **not** chunk `gabbay_2000` or `negri_von_plato_2001` — both are correctly quarantined with no
  valid full-text `.md` and must stay excluded.
- Do **not** mutate `index.json` entries beyond what the existing `handle_convert()` Step 3g write
  already does (add coverage only; no field-logic changes).
- Do **not** modify `literature-chunk.sh`'s contract (no append mode); the multi-file case is
  solved by directory layout + recursive index discovery instead.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Naive per-section chunking of `baier_katoen_2008` into one dir clobbers `chunks.json`/`chunk_*.md`, leaving only the last section (Phase 3) | H | H | Chunk each section into a **distinct subdirectory** under `sources/baier_katoen_2008/`, all passing `--doc-id baier_katoen_2008`; rely on `build-index`'s recursive discovery + in-manifest doc_id to aggregate. Verify all 12 files represented. |
| Copy-pasting `literature-ingest.sh`'s `DOC_DIR=$LITERATURE_DIR/$DOC_ID` placement reintroduces chunks outside `sources/` | H | M | Anchor every chunk output dir to `sources/<dir>/` (Phase 1 uses `dirname "$output_md"`; Phases 2-3 derive from `sources/<dir>/`). |
| Quarantine artifact gets chunked via an unfiltered glob | M | L | Pass explicit `.md` paths only; backfill derives valid `.md` via `find sources/<dir> -maxdepth 1 -name '*.md' -not -name 'chunk_*.md'` with quarantine suffixes excluded by construction. |
| Extension edit lands but deployed copy drifts, tripping #841 guard | M | M | After every SKILL.md edit, `cp` to the deployed path and assert `diff -q` is empty (Phases 1 and 4). |
| Parallel `build-index --global` runs race on the SQLite DB | M | M | Sequence DB-writing phases: Phase 3 depends on Phase 2; each runs exactly one `--global` rebuild at its end. |
| Conflating `document_metadata` into the diff bloats review | L | L | Explicit non-goal; note it in the SKILL.md comment left by Phase 4, mirroring Job 4's existing precedent. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 2 (P3), 1 (P4) |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phase 1 and Phase 4 both edit SKILL.md, so
Phase 4 depends on Phase 1 to avoid a concurrent edit of the same file. Phase 3 depends on Phase 2
so the two backfill phases do not race on the global SQLite database.

### Phase 1: Wire handle_convert() to chunk + index [COMPLETED]

**Goal**: `handle_convert()` chunks each `.md` it writes and rebuilds the search index once per
invocation, so converted documents are immediately searchable.

**Tasks**:
- [x] In `.claude/extensions/literature/skills/skill-literature/SKILL.md`, locate the
      `handle_convert()` per-output-file loop, immediately after Convert Step 3g (once `output_md`
      and its `index.json` entry both exist). *(completed: added new "3h: Chunk and Index" subsection)*
- [x] Add a call: `literature-chunk.sh "$output_md" "$(dirname "$output_md")" --doc-id "$basename_no_ext"`
      (use the shared, per-document `basename_no_ext` as `--doc-id` for every output file — for
      multi-section conversions this ensures all sections land under one `doc_id`, matching Job 4's
      `doc_id = <sources/dir basename>` check; do NOT reuse Step 3g's per-section `entry_id`).
      Resolve the script via the same `SCRIPT_DIR`/scripts path convention other calls in SKILL.md
      already use; capture non-zero exit without aborting the whole convert (mirror
      `literature-ingest.sh`'s guarded-assignment pattern). *(completed)*
- [x] At the end of Convert Step 4 (once per invocation, after all output files processed) add a
      single rebuild: `literature-build-index.sh --global` when `lit_dir` resolved to
      `$LITERATURE_DIR`, else `literature-build-index.sh --local` when it resolved to
      `specs/literature` — branch on the **same** condition Step 2 already uses to set
      `sources_prefix`. *(completed)*
- [x] Confirm the chunk output dir is `sources/<dir>/` by construction (`dirname "$output_md"`
      already yields the `sources/`-prefixed dir); do not introduce any `$LITERATURE_DIR/$DOC_ID/`
      top-level path. *(completed: verified by construction, no new path introduced)*
- [x] Update the Convert Step 4 summary text to mention chunk count / that the doc is now indexed
      (optional, keep minimal). *(completed: added Chunks column + Search Index line)*
- [x] Sync the deployed copy: `cp .claude/extensions/literature/skills/skill-literature/SKILL.md
      .claude/skills/skill-literature/SKILL.md` and assert `diff -q` between the two is empty.
      *(completed: discovered the two paths are hardlinked to the same inode, so edits are
      automatically identical; diff -q confirmed empty)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — add chunk + index calls in `handle_convert()`
- `.claude/skills/skill-literature/SKILL.md` — deployed mirror, kept byte-identical via `cp`

**Verification**:
- `diff -q` between extension source and deployed SKILL.md returns nothing.
- `grep -n "literature-chunk.sh\|literature-build-index.sh" .claude/extensions/literature/skills/skill-literature/SKILL.md`
  now shows the two new invocations inside the Convert mode section.
- Deferred functional check happens in Phase 5 (fresh `--convert` of a test doc).

---

### Phase 2: Backfill the 22 single-file uncovered directories [COMPLETED]

**Goal**: Every single-file uncovered `sources/<dir>/` gains a `chunks.json` + `chunk_*.md` and
`chunks_data` rows, from its existing `.md` with no re-conversion.

**Tasks**:
- [x] Enumerate the 22 target dirs (all 25 uncovered minus `baier_katoen_2008`, `gabbay_2000`,
      `negri_von_plato_2001`): `burgess_1982_i`, `burgess_1982_ii`, `courcoubetis_1992`,
      `gerth_1995`, `girard_1989`, `hodkinson_2006`, `kupferman_vardi_2001`, `libkin_2004_ch3_ch7`,
      `piterman_2007`, `rabinovich_2014`, `schewe_2009`, `schwoon_esparza_2005`, `tarjan_1972`,
      `thomas_1997`, `thomas_1997_languages`, `thomas_2003_reactive`,
      `troelstra_schwichtenberg_2000`, `van_doorn_2015`, `vardi_1996`, `vardi_wolper_1986`,
      `yan_2008`, `zielonka_1998`. *(completed)*
- [x] For each dir, resolve the single valid `.md` explicitly:
      `find "$LITERATURE_DIR/sources/<dir>" -maxdepth 1 -name '*.md' -not -name 'chunk_*.md'` and
      confirm exactly one result whose name does not end in `.md.bak-*` / `.md.rejected` (skip and
      report any dir that fails this check rather than force-chunking).
      *(deviation: altered — enumeration found 2 of the 22 did not have exactly one valid .md:
      `troelstra_schwichtenberg_2000` has zero (only `.md.rejected`, no index.json entry) and was
      skipped/excluded per this task's own instruction; `thomas_2003_reactive` has two (ch01,
      ch03) and was handled with distinct-subdirectory chunking instead of a single flat call —
      see task 2b below)*
- [x] Run `literature-chunk.sh "<that.md>" "$LITERATURE_DIR/sources/<dir>" --doc-id "<dir>"` for
      each (idempotent; only reads the `.md`, writes `chunk_*.md` + `chunks.json` alongside it).
      *(completed: ran for the 20 genuinely single-file dirs)*
- [x] **Task 2b** (not in original plan): `thomas_2003_reactive`'s 2 files chunked into distinct
      `sources/thomas_2003_reactive/.chunks/<name>/` subdirs, both passing `--doc-id
      thomas_2003_reactive`, mirroring Phase 3's baier_katoen_2008 technique.
      *(completed: deviation, see progress file)*
- [x] After all chunk calls, run a single `literature-build-index.sh --global` rebuild. *(completed:
      105 manifests, 4970 chunks indexed)*
- [x] Spot-check `sqlite3 "$LITERATURE_DIR/.literature.db" "SELECT count(*) FROM chunks_data WHERE doc_id='<dir>';"`
      returns > 0 for a sample of the 22. *(completed: verified all 21 covered dirs — the 20
      single-file dirs plus thomas_2003_reactive — return > 0; troelstra_schwichtenberg_2000
      correctly remains 0/excluded)*

**Timing**: 0.75 hour

**Depends on**: none

**Files to modify**:
- `$LITERATURE_DIR/sources/<dir>/chunks.json` and `chunk_*.md` (22 dirs) — generated artifacts
- `$LITERATURE_DIR/.literature.db` — rebuilt FTS5 index

**Verification**:
- All 22 target dirs return `chunks_data` count > 0.
- No `chunks.json` in any of the 22 references a `.md.bak-*` / `.md.rejected` path
  (`grep -LE '\.md\.(bak-|rejected)'`).

---

### Phase 3: Backfill baier_katoen_2008 (12-file book) [COMPLETED]

**Goal**: All 12 section `.md` files of `baier_katoen_2008` are represented in `chunks_data` under a
single `doc_id=baier_katoen_2008`, with no section clobbering another.

**Tasks**:
- [x] Enumerate the 12 section files:
      `find "$LITERATURE_DIR/sources/baier_katoen_2008" -maxdepth 1 -name '*.md' -not -name 'chunk_*.md'`
      (expect 12; confirm none is a quarantine artifact). *(completed: confirmed exactly 12, no
      quarantine artifacts)*
- [x] For each section file, chunk into a **distinct subdirectory** to avoid `chunks.json` /
      `chunk_*.md` clobbering, e.g.
      `literature-chunk.sh "<sectionNN.md>" "$LITERATURE_DIR/sources/baier_katoen_2008/.chunks/sectionNN" --doc-id "baier_katoen_2008"`.
      Pass the shared `--doc-id baier_katoen_2008` on every call so all sections' chunks carry the
      same in-manifest `doc_id`. *(completed: 12 manifests written, chunk counts
      128,111,106,99,110,101,1,112,107,111,113,79 — deviation: section07 produced only 1 chunk,
      see below)*
- [x] Run one `literature-build-index.sh --global` rebuild; it recursively discovers all 12
      per-section `chunks.json` and aggregates every chunk under `doc_id=baier_katoen_2008` (no
      manifest merge or chunker change needed — confirmed against `literature-build-index.sh` lines
      90-91 and 152). *(completed: 117 manifests found, 6148 chunks indexed)*
- [x] Confirm the subdir layout keeps `chunk_*.md` name-detectable (so the whole-document
      double-count exclusion in `chunk-file-conventions.md`, which filters by `-iname 'chunk_*.md'`
      regardless of depth, still holds). *(completed)*
- [x] **Deviation**: section07's chunk manifest has only 1 chunk (46176 tokens) instead of ~100+
      like its siblings — a pre-existing `literature-chunk.sh` pass-2 subdivision edge case (none
      of the 12 parts contain markdown `#` headings; pass-1 heading detection found none in any
      part, and pass-2 paragraph/sentence subdivision worked for 11/12 but not part07). The
      section IS represented in `chunks_data` (nonzero, searchable) so the coverage goal holds;
      fixing the chunker's subdivision algorithm is out of scope per this task's explicit non-goal
      (no `literature-chunk.sh` contract changes). Flagged, not fixed.
      *(deviation: altered — see progress file for full detail)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `$LITERATURE_DIR/sources/baier_katoen_2008/.chunks/sectionNN/{chunks.json,chunk_*.md}` (12 subdirs) — generated
- `$LITERATURE_DIR/.literature.db` — rebuilt FTS5 index

**Verification**:
- `sqlite3 "$LITERATURE_DIR/.literature.db" "SELECT count(*) FROM chunks_data WHERE doc_id='baier_katoen_2008';"`
  returns a chunk count consistent with all 12 sections (materially larger than any single
  section's chunk count — i.e. not clobbered to just the last file).
- `literature-search.sh` returns `baier_katoen_2008` results drawn from more than one section.

---

### Phase 4: Extend Job 4 to distinguish expected vs unexpected empty [COMPLETED]

**Goal**: Job 4 self-diagnoses future regressions: a `missing_dirs` entry that has a valid `.md`
but zero `chunks_data` rows is flagged as **unexpected** (wiring regressed / new convert path),
while a dir with no valid `.md` (e.g. `gabbay_2000`, `negri_von_plato_2001`) is reported as
**expected-empty (quarantined)**.

**Tasks**:
- [x] In `rebuild_job4_coverage_audit()`, for each `missing_dirs`
      entry cross-check `find "$dirpath" -maxdepth 1 -name '*.md' -not -name 'chunk_*.md'`
      (excluding `.md.bak-*` / `.md.rejected`): if a valid `.md` exists → classify **UNEXPECTED**;
      else → **expected-empty (quarantined)**. *(completed)*
- [x] Emit the two buckets separately in the report output so a non-empty UNEXPECTED bucket is an
      obvious regression signal. *(completed)*
- [x] Update the now-stale root-cause footer which currently states
      `/literature --convert never invokes the chunker/indexer`: reword to note that `--convert`
      now chunks+indexes (as of task #842) and that a non-empty UNEXPECTED bucket indicates a
      regression or a new un-wired convert path. Keep the `document_metadata` non-goal note.
      *(completed)*
- [x] Keep Job 4 read-only and idempotent (no writes; Job 3 remains the only writer). *(completed:
      verified — only reads via sqlite3 SELECT/find/grep)*
- [x] Sync the deployed copy (`cp` + assert `diff -q` empty), as in Phase 1. *(completed: hardlinked
      path, diff -q confirmed empty)*

**Live verification**: ran the extracted function against the live corpus after Phases 1-3 —
`covered=94 missing=3, UNEXPECTED=0, expected-empty=3` (`gabbay_2000`, `negri_von_plato_2001`,
`troelstra_schwichtenberg_2000`). This confirms the actual final excluded-dir count is **3, not
the 2 assumed by the original task description/plan** — see Phase 2's deviation entry for
`troelstra_schwichtenberg_2000`.

**Timing**: 0.75 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Job 4 body + footer
- `.claude/skills/skill-literature/SKILL.md` — deployed mirror kept byte-identical

**Verification**:
- `diff -q` between extension source and deployed SKILL.md returns nothing.
- Running `/literature --rebuild --dry-run` after backfill reports `gabbay_2000` and
  `negri_von_plato_2001` in the expected-empty bucket and an empty UNEXPECTED bucket.

---

### Phase 5: End-to-end verification [NOT STARTED]

**Goal**: Confirm forward fix, backfill, and guard all hold against the live corpus.

**Tasks**:
- [ ] Run `/literature --rebuild --dry-run` and confirm Job 4 reports the 23 backfilled dirs as
      covered; `missing`/UNEXPECTED for `sources/<dir>/` reduces to 0, with exactly
      `gabbay_2000` and `negri_von_plato_2001` remaining in the expected-empty bucket.
- [ ] Convert a fresh test document via `/literature --convert <test.pdf>` (or a small fixture) and
      confirm, without any separate `--ingest`, that `chunks_data` has rows for its `doc_id` and
      `literature-search.sh` returns it.
- [ ] Assert no quarantine artifact appears in any `chunks_data` row / `chunks.json` manifest
      (`grep -rLE '\.md\.(bak-|rejected)'` across touched `chunks.json`; Job 4's quarantine warning
      stays silent).
- [ ] Re-confirm `baier_katoen_2008` chunk count reflects all 12 sections (Phase 3 check re-run).
- [ ] Clean up the fresh test document's artifacts if it was a throwaway fixture (leave real corpus
      docs in place).
- [ ] `diff -q` extension vs deployed SKILL.md one final time.

**Timing**: 0.5 hour

**Depends on**: 1, 2, 3, 4

**Files to modify**: none (verification only; test fixture cleanup)

**Verification**:
- Expected end state stated explicitly: `sources/<dir>/` uncovered count goes 25 → 2, and those 2
  (`gabbay_2000`, `negri_von_plato_2001`) are the correctly-excluded-by-design quarantined dirs
  (reported as expected-empty, not as failures).

## Testing & Validation

- [ ] `/literature --rebuild --dry-run` Job 4: 0 unexpected-empty `sources/<dir>/` dirs; exactly 2
      expected-empty (`gabbay_2000`, `negri_von_plato_2001`).
- [ ] Fresh `--convert`ed doc has `chunks_data` rows and is returned by `literature-search.sh`
      without a separate `--ingest`.
- [ ] No quarantine artifact (`.md.bak-*`, `.md.rejected`) appears in any `chunks.json` / `chunks_data`.
- [ ] `baier_katoen_2008`'s 12 files are all represented in its chunks (not clobbered to the last file).
- [ ] Extension source and deployed SKILL.md are byte-identical (`diff -q` empty).

## Artifacts & Outputs

- `plans/01_coverage-fix-plan.md` (this file)
- Edited `.claude/extensions/literature/skills/skill-literature/SKILL.md` + synced deployed copy
- Regenerated `chunks.json` / `chunk_*.md` for 23 directories under `$LITERATURE_DIR/sources/`
- Rebuilt `$LITERATURE_DIR/.literature.db` (FTS5 chunk index)
- `summaries/01_coverage-fix-summary.md` (produced at implementation time)

## Rollback/Contingency

- SKILL.md changes are revertable via `git checkout` of both the extension and deployed paths
  (both tracked); re-run `diff -q` to confirm parity after revert.
- Backfill is additive and idempotent: generated `chunks.json` / `chunk_*.md` can be deleted and
  `literature-build-index.sh --global` re-run to return `chunks_data` to its prior state (the
  original canonical `.md` files are never modified by chunking, so no source content is at risk).
- The live SQLite DB is fully reproducible from `chunks.json` manifests via
  `literature-build-index.sh --global`; no manual DB surgery is needed to roll back.
- Quarantine-never-delete is preserved throughout: no phase deletes `.md.bak-*` / `.md.rejected`.
