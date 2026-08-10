# Implementation Plan: Task #730

- **Task**: 730 - Re-chunk Literature Files at Semantic Boundaries
- **Status**: [COMPLETED]
- **Effort**: 10 hours
- **Dependencies**: Task 728 (source recovery), Task 729 (chunking audit)
- **Research Inputs**: specs/730_literature_semantic_rechunking/reports/01_semantic-rechunking-research.md
- **Artifacts**: plans/01_semantic-rechunking-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Re-chunk all arbitrarily split literature files at semantic boundaries using document-specific Python splitting scripts. The work spans two literature stores (`~/Projects/Literature/` and `~/Projects/cslib/specs/literature/`) and covers: (1) creating `blackburn_2002/` from a 365K-token flat file, (2) renaming 13 arbitrary-named chunk files in 3 Literature/ subdirectories, (3) re-chunking 5 oversized cslib textbook subdirectories at subsection boundaries, (4) removing 13 redundant flat files, and (5) updating all affected index.json entries.

### Research Integration

The research report identified that `literature-chunk.sh` cannot be used because it splits at `## Page N` markers (OCR artifacts) rather than semantic headings embedded in prose. Document-specific regex patterns were catalogued for all target files. The `blackburn_2001/` directory (33 chunks) serves as the naming template for `blackburn_2002/`. Missing section detections in the Blackburn regex were flagged and will be addressed using the TOC as ground truth.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Split the 365K-token Blackburn 2002 flat file into ~33 chapter/section chunks at semantic boundaries
- Rename 13 existing chunk files in burgess_1984/, doets_1989/, reynolds_1994/ to semantic names
- Re-chunk 5 oversized cslib textbook subdirectories (chagrov_1997, church_1956, hughes_1996, mendelson_2016, zakharyaschev_2001) at subsection boundaries
- Remove 13 redundant flat files in Literature/ that have chunked subdirectory equivalents
- Update index.json entries for every affected document with correct paths, token counts, and section metadata

**Non-Goals**:
- Modifying `literature-chunk.sh` to handle non-markdown headings
- Creating new index.json entries for documents not already indexed
- Re-chunking documents that are already properly sized and named
- Processing any documents outside the two identified literature stores

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing section boundaries in Blackburn 2002 regex (16 sections undetected) | M | H | Use TOC from research report as ground truth; broaden regex to catch all N.N patterns |
| Control characters in cslib files interfere with heading detection | M | M | Strip \x0c and \x1f before regex matching in Python scripts |
| Index.json schema inconsistency after bulk updates | H | M | Validate with jq after each phase; run `literature --validate` at end |
| Flat file removal before chunk verification | H | L | Only remove flat files in final phase after all chunks confirmed to exist |
| Chunk size variance (some sections <1K tokens, others >15K) | M | H | Group adjacent small sections; split long sections at paragraph boundaries targeting 5-10K per chunk |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 2, 3 |
| 4 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create Python Semantic Splitter Utility [COMPLETED]

**Goal**: Build a reusable Python script that detects semantic boundaries in literature markdown files and splits them into named chunks.

**Tasks**:
- [ ] Create `specs/730_literature_semantic_rechunking/semantic_split.py` with the following capabilities:
  - Read a markdown file and detect `## Page N` markers for page tracking
  - Accept a document-specific config (heading regex pattern, min/max token targets, output directory, naming template)
  - Detect chapter and section boundaries using configurable regex patterns
  - Group adjacent small sections (<2K tokens) into combined chunks
  - Split oversized sections (>12K tokens) at paragraph boundaries
  - Write named output files using semantic heading slugs
  - Report page ranges, token counts, and section coverage for each output chunk
- [ ] Include pre-built config profiles for each document type:
  - `blackburn_2002`: Chapter pattern `^(\d+)\s+(Basic Concepts|Models|Frames|...)$`, section pattern `^(\d+)\.(\d+)\s+([A-Z].+)$`
  - `chagrov_1997`: Tab-delimited `^(\d+\.\d+)\t(.+)$`
  - `church_1956`: Section marker `^§\s*(\d+)\.\s*(.+)$` or `^(\d+)\.\s+([A-Z].+)$`
  - `hughes_1996`: Numbered sections similar to chagrov
  - `mendelson_2016`: Em-space delimited `^(\d+\.\d+)\s+(.+)$` (Unicode em-space)
  - `zakharyaschev_2001`: Numbered subsections within existing chunks
- [ ] Add `--dry-run` mode that reports boundaries and projected chunk sizes without writing files
- [ ] Strip control characters (`\x0c`, `\x1f`, `\x00-\x1f`) from lines before pattern matching

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `specs/730_literature_semantic_rechunking/semantic_split.py` - New file

**Verification**:
- `python3 semantic_split.py --dry-run --profile blackburn_2002 /path/to/flat/file` produces boundary list with token estimates
- All 6 document profiles parse without error on dry-run

---

### Phase 2: Split Blackburn 2002 and Rename Literature/ Subdirectories [COMPLETED]

**Goal**: Create `blackburn_2002/` subdirectory from the 365K-token flat file and rename files in 3 existing subdirectories.

**Tasks**:
- [ ] Run `semantic_split.py` with `blackburn_2002` profile against `~/Projects/Literature/Blackburn_deRijke_Venema_2002_Modal_Logic.md`
  - Output to `~/Projects/Literature/blackburn_2002/`
  - Use `ch{N}_{topic}.md` naming matching blackburn_2001/ convention
  - Verify all 7 chapters + appendices are covered (~33 files)
  - Verify each chunk is 4-10K tokens (grouping adjacent small sections)
- [ ] Cross-check against blackburn_2001/ structure: same chapter numbering, similar section groupings
- [ ] Fill in missing sections (2.5, 2.6, 3.1-3.3, 3.5, 4.6, 4.7, 5.3, 6.1, 6.4, 6.6, 7.5-7.7, Appendices) by broadening regex or using TOC line ranges
- [ ] Rename burgess_1984/ files (7 files):
  - `sec01_page-1.md` -> `sec01_frame-axiomatics.md`
  - `sec02_page-10.md` -> `sec02_bibliography.md`
  - `sec03_page-13.md` -> `sec03_introduction.md`
  - `sec04_page-19.md` -> `sec04_completeness-chronicles.md`
  - `sec05_page-28.md` -> `sec05_completeness-discrete.md`
  - `sec06_page-37.md` -> `sec06_decidability.md`
  - `sec07_page-45.md` -> `sec07_expressive-completeness.md`
- [ ] Rename doets_1989/ files (3 files):
  - `sec01_part-1.md` -> `sec01_introduction-scattered.md`
  - `sec02_part-2.md` -> `sec02_well-orderings.md`
  - `sec03_part-3.md` -> `sec03_well-founded-trees.md`
- [ ] Rename reynolds_1994/ files (3 files):
  - `sec01_part-1.md` -> `sec01_introduction-expressive.md`
  - `sec02_part-2.md` -> `sec02_no-gaps.md`
  - `sec03_part-3.md` -> `sec03_contemporaneity.md`
- [ ] Inspect doets_1987/ sec02 and sec03 content to determine proper semantic names; rename if content is clear

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `~/Projects/Literature/blackburn_2002/` - New directory (~33 files)
- `~/Projects/Literature/burgess_1984/*.md` - 7 files renamed
- `~/Projects/Literature/doets_1989/*.md` - 3 files renamed
- `~/Projects/Literature/reynolds_1994/*.md` - 3 files renamed
- `~/Projects/Literature/doets_1987/*.md` - 2 files possibly renamed

**Verification**:
- `ls ~/Projects/Literature/blackburn_2002/ | wc -l` yields ~33
- `wc -c ~/Projects/Literature/blackburn_2002/*.md` shows individual files in 15K-40K byte range (4-10K tokens)
- All renamed files exist; no orphaned page-based names remain in burgess_1984/, doets_1989/, reynolds_1994/

---

### Phase 3: Re-chunk cslib Oversized Subdirectories [COMPLETED]

**Goal**: Split the 5 oversized cslib textbook subdirectories at subsection boundaries.

**Tasks**:
- [ ] Re-chunk chagrov_1997/ (5 chunks -> ~75 chunks):
  - Run `semantic_split.py` with `chagrov_1997` profile on each of the 5 existing part files
  - Output to `~/Projects/cslib/specs/literature/chagrov_1997/` (replace existing files)
  - Use `ch{NN}_{topic}.md` naming with section-level granularity
  - Back up existing files before overwriting
- [ ] Re-chunk church_1956/ (7 chunks -> ~40 chunks):
  - Run with `church_1956` profile on each chapter file
  - Use `ch{NN}_sec{NN}_{topic}.md` or equivalent naming
- [ ] Re-chunk hughes_1996/ (4 chunks -> ~40 chunks):
  - Run with `hughes_1996` profile on each part file
  - Use chapter-based naming
- [ ] Re-chunk mendelson_2016/ (6 chunks -> ~50 chunks):
  - Run with `mendelson_2016` profile on each chapter file
  - Special handling for em-space delimiter
- [ ] Re-chunk zakharyaschev_2001/ (2 oversized chunks -> ~15 chunks):
  - Only split sec01_unimodal-logics.md (42K tokens) and sec03_superintuitionistic-logics.md (45K tokens)
  - Keep sec02 and sec04 as-is if already within target range
- [ ] For each book: verify all source content is preserved (diff byte counts before/after)

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `~/Projects/cslib/specs/literature/chagrov_1997/*.md` - Replace 5 files with ~75
- `~/Projects/cslib/specs/literature/church_1956/*.md` - Replace 7 files with ~40
- `~/Projects/cslib/specs/literature/hughes_1996/*.md` - Replace 4 files with ~40
- `~/Projects/cslib/specs/literature/mendelson_2016/*.md` - Replace 6 files with ~50
- `~/Projects/cslib/specs/literature/zakharyaschev_2001/*.md` - Split 2 files into ~15

**Verification**:
- Total byte count of each subdirectory matches original (within 5% due to heading adjustments)
- No chunk exceeds 12K tokens (~48K bytes)
- No chunk is smaller than 1K tokens (~4K bytes) unless it is a legitimate short appendix
- `ls <subdir> | wc -l` matches target chunk counts approximately

---

### Phase 4: Update Literature/ index.json [COMPLETED]

**Goal**: Update `~/Projects/Literature/index.json` entries for all Phase 2 changes.

**Tasks**:
- [ ] Create parent book entry for blackburn_2002 (`doc_type: "book"`, no `path` field or path to directory)
- [ ] Create ~33 chapter entries for blackburn_2002/ with:
  - `id`: `blackburn_2002_ch{N}_sec{NN-NN}` pattern
  - `path`: `blackburn_2002/ch{N}_{topic}.md`
  - `title`: `Chapter N: Section Title(s)` with actual section names
  - `token_count`: Calculated from file size (bytes / 4)
  - `doc_type`: `chapter`
  - `parent_doc`: `blackburn_2002`
  - `page_range`: From page markers in content
  - Inherit `authors`, `bib_key`, `year`, `source_format`, `zotero_key`, `project_tags` from flat file entry
- [ ] Remove or replace the flat file entry for `Blackburn_deRijke_Venema_2002_Modal_Logic.md`
- [ ] Update `path` fields for all renamed files in burgess_1984/, doets_1989/, reynolds_1994/:
  - 13 entries need path changes (old filename -> new filename)
  - Verify `id` fields still make sense with new paths
- [ ] Validate index.json with `jq '.' ~/Projects/Literature/index.json` (valid JSON)
- [ ] Verify no duplicate `id` fields exist

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `~/Projects/Literature/index.json` - Update ~50 entries (remove 1 flat, add ~33 chapter, update 13 renames)

**Verification**:
- `jq '.' ~/Projects/Literature/index.json > /dev/null` exits 0
- `jq '[.[] | .id] | unique | length' ~/Projects/Literature/index.json` equals total entry count (no duplicates)
- Every `path` value resolves to an existing file: `jq -r '.[].path' index.json | while read p; do test -f "$p" || echo "MISSING: $p"; done`

---

### Phase 5: Update cslib index.json Files [COMPLETED]

**Goal**: Update index.json files in cslib for all Phase 3 re-chunked subdirectories.

**Tasks**:
- [ ] For each of the 5 re-chunked cslib books, update their index.json:
  - Remove old chunk entries
  - Add new chunk entries with correct paths, token counts, section titles, page ranges
  - Preserve parent book entries
  - Use consistent id pattern: `{author}_{year}_ch{N}_sec{NN}` or similar
- [ ] Handle chagrov_1997/index.json (~75 new entries)
- [ ] Handle church_1956/index.json (~40 new entries)
- [ ] Handle hughes_1996/index.json (~40 new entries)
- [ ] Handle mendelson_2016/index.json (~50 new entries)
- [ ] Handle zakharyaschev_2001/index.json (~15 new entries)
- [ ] Validate each index.json with jq
- [ ] Cross-reference: every chunk file has an index entry, every index path resolves to a file

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:
- `~/Projects/cslib/specs/literature/chagrov_1997/index.json`
- `~/Projects/cslib/specs/literature/church_1956/index.json`
- `~/Projects/cslib/specs/literature/hughes_1996/index.json`
- `~/Projects/cslib/specs/literature/mendelson_2016/index.json`
- `~/Projects/cslib/specs/literature/zakharyaschev_2001/index.json`

**Verification**:
- All 5 index.json files pass `jq '.' <file> > /dev/null`
- No duplicate ids within any single index.json
- `jq -r '.[].path' <index> | while read p; do test -f "$(dirname <index>)/$p" || echo "MISSING: $p"; done` finds no missing files

---

### Phase 6: Remove Redundant Flat Files and Final Validation [COMPLETED]

**Goal**: Remove 13 redundant flat files and perform end-to-end validation across both literature stores.

**Tasks**:
- [ ] Verify each flat file has a corresponding subdirectory with complete content:
  - `Blackburn_deRijke_Venema_2002_Modal_Logic.md` -> `blackburn_2002/`
  - `Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md` -> `caleiro_2013/`
  - `deRijke_Venema_1995_Sahlqvist_BAOs.md` -> `derijke_1995/`
  - `Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md` -> `gabbay_1993/`
  - `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md` -> `gabbay_1994/`
  - `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md` -> `gabbay_1994/`
  - `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md` -> `gabbay_1994/`
  - `Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md` -> `goldblatt_2003/`
  - `Reynolds_2001_Axiomatization_Full_CTL_star.md` -> `reynolds_2001/`
  - `Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md` -> `venema_1991/`
  - `Venema_1991_Many_Dimensional_Modal_Logics_ch2.md` -> `venema_1991/`
  - `Venema_1993_Derivation_Rules_Anti_Axioms.md` -> `venema_1993/`
  - `Venema_1993_Since_and_Until.md` -> `venema_1993_since/`
- [ ] For each flat file, confirm subdirectory index.json entries exist before removal
- [ ] Remove the 13 flat files from `~/Projects/Literature/`
- [ ] Update index.json to remove any entries pointing to deleted flat files (if not already handled in Phase 4)
- [ ] Run comprehensive validation:
  - All index.json path references resolve to existing files
  - No orphaned chunk files without index entries
  - No flat files remain that have subdirectory equivalents
  - Token count spot-checks (5 random files: actual bytes/4 vs recorded token_count)
- [ ] Clean up: remove `specs/730_literature_semantic_rechunking/semantic_split.py` or move to `.claude/scripts/` if reusable

**Timing**: 1 hour

**Depends on**: 4, 5

**Files to modify**:
- `~/Projects/Literature/*.md` - Remove 13 flat files
- `~/Projects/Literature/index.json` - Remove stale entries (if any remain)

**Verification**:
- `find ~/Projects/Literature -maxdepth 1 -name "*.md" | wc -l` shows reduction of 13 files
- `jq -r '.[].path' ~/Projects/Literature/index.json | while read p; do test -f ~/Projects/Literature/"$p" || echo "MISSING: $p"; done` finds 0 missing
- No flat file listed in the removal table exists in `~/Projects/Literature/`

## Testing & Validation

- [ ] All index.json files (Literature/ + 5 cslib) are valid JSON
- [ ] No duplicate ids in any index.json
- [ ] Every index.json path resolves to an existing file
- [ ] No orphaned files exist without index entries
- [ ] Blackburn 2002 has ~33 chunks, all 4-10K tokens
- [ ] Each cslib book total byte count matches pre-rechunking total (within 5%)
- [ ] No chunk exceeds 12K tokens; no chunk is below 1K tokens (except legitimate appendices)
- [ ] All 13 redundant flat files have been removed
- [ ] File renames in burgess_1984/, doets_1989/, reynolds_1994/ reflect semantic content

## Artifacts & Outputs

- `specs/730_literature_semantic_rechunking/plans/01_semantic-rechunking-plan.md` (this file)
- `specs/730_literature_semantic_rechunking/semantic_split.py` (temporary utility)
- `~/Projects/Literature/blackburn_2002/` (~33 new chunk files)
- `~/Projects/Literature/index.json` (updated)
- `~/Projects/cslib/specs/literature/{chagrov_1997,church_1956,hughes_1996,mendelson_2016,zakharyaschev_2001}/` (re-chunked)
- `~/Projects/cslib/specs/literature/*/index.json` (updated for each re-chunked book)

## Rollback/Contingency

- Before re-chunking any cslib subdirectory, back up existing files to a `_backup/` directory within the task spec folder
- Git history preserves all original Literature/ files; `git checkout -- <file>` restores any incorrectly removed flat file
- Index.json changes can be reverted via git if validation fails
- The `--dry-run` mode in the splitter script allows previewing all splits before committing to writes
