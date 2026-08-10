# Research Report: Task #732

**Task**: 732 - Unify Index Schema to v2 and Clean Up Deprecated Collections
**Started**: 2026-06-16T00:00:00Z
**Completed**: 2026-06-16T00:30:00Z
**Effort**: 0.5 hours
**Dependencies**: Tasks 728, 729, 730, 731 (completed)
**Sources/Inputs**: ~/Projects/Literature/index.json, ~/Projects/cslib/specs/literature/index.json, filesystem analysis
**Artifacts**: specs/732_literature_schema_unification/reports/01_schema-unification-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The **root Literature index.json is already fully v2** (183 entries, all with doc_type, source_format, zotero_key, project_tags). No v1 entries exist there.
- **cslib's specs/literature/index.json is entirely v1** (76 entries, all missing the 4 v2 fields), and the directory has significant overlap with Literature/ that a DEPRECATED.md should address.
- **BimodalLogic flat+chunked structure**: 8 directory-level entries exist alongside corresponding flat file entries in the root index, representing true dual-representation redundancy. These are the deduplication targets.
- **No true orphans** exist in either direction: all 23 subdirectories in Literature/ have their sections indexed; all index paths resolve to existing files/dirs.
- The 15 "orphaned-looking" subdirectories are not orphans — they have section-level entries in the index but lack a directory-level summary entry (this is a design choice, not an error).

---

## Context & Scope

Analyzed the centralized literature repository at ~/Projects/Literature/ and the per-project replica at ~/Projects/cslib/specs/literature/ to determine the exact schema state, identify BimodalLogic deduplication candidates, and prepare for the DEPRECATED.md addition to cslib.

---

## Findings

### 1. v1 vs v2 Schema Analysis

**v2 fields** (from task 730 prior research):
- `doc_type` — paper, book, thesis, chapter, etc.
- `source_format` — pdf, djvu, html, etc.
- `zotero_key` — key in Zotero library (may differ from bib_key)
- `project_tags` — array of project names using this entry

**Root Literature/index.json** (`~/Projects/Literature/index.json`):
- Version: 2
- Total entries: 183
- **v2 complete: 183 (100%)**
- v1 (missing any v2 field): 0
- Partial: 0

**cslib/specs/literature/index.json** (`~/Projects/cslib/specs/literature/index.json`):
- Version: 1
- Total entries: 76
- **v1 complete (all 4 v2 fields missing): 76 (100%)**
- v2 complete: 0

The root index has already been fully upgraded. The cslib index is entirely v1 and needs either upgrading or deprecation.

### 2. Literature/ Index Structure

The root index contains three entry types:

| Type | Count | Description |
|------|-------|-------------|
| Root flat file entries | 175 | Path is a .md file in Literature/ root |
| Directory-level entries | 8 | Path is `subdir/`, token_count=0 |
| Section entries | 145 | Path is `subdir/sec_NN_name.md` |

Note: entries can fall in multiple categories — the 8 directory entries have 145 corresponding section entries also indexed. The 175 flat file count includes both root .md files AND section paths.

**Subdirectory count**: 23 total subdirectories, all indexed via section entries. 8 of the 23 also have a directory-level summary entry.

### 3. BimodalLogic Flat+Chunked Duplicates

These 8 directory-level entries represent the flat+chunked redundancy. Each has:
- A corresponding flat .md file(s) with full content and correct token_count
- A directory-level entry with token_count=0
- Section chunk entries for the directory

| Dir Entry ID | Flat Entry ID(s) | Flat Tokens | Dir Chunks |
|---|---|---|---|
| `burgess_1982` | `burgess_1982_i` | 5,437 | 2 |
| `burgess_1982b` | `burgess_1982_ii` | 5,589 | 2 |
| `venema_1991` | `venema_1991_app`, `venema_1991_ch2` | 9,404 + 20,006 | 9 |
| `venema_1993` | `venema_1993_anti_axioms` | 22,333 | 9 |
| `derijke_1995` | `derijke_venema_1995` | 9,064 | 3 |
| `venema_1993_since` | `venema_1993_since_until` | 3,927 | 2 |
| `blackburn_2001` | `blackburn_2002` (2002 Cambridge ed) | 365,868 | 33 |
| `gabbay_1994` | `gabbay_1994_ch9`, `gabbay_1994_ch10`, `gabbay_1994_ch12` | varies | 11 |

**Deduplication recommendation**: Remove the 8 directory-level summary entries (token_count=0 entries with path=`subdir/`). These add no retrievable content — literature-retrieve.sh cannot return directory paths, only files. The section entries are the valuable content; the flat files provide the full-document fallback. The directory-level entries are vestigial from an intermediate migration state.

**Special case — blackburn_2001 vs blackburn_2002**: The dir entry `blackburn_2001` (bib_key=Blackburn2001, 2001 Cambridge Tracts edition) is different from flat entry `blackburn_2002` (bib_key=BlackburnDeRijkeVenema2002, 2002 Cambridge edition). These are NOT duplicates — they are distinct editions. The directory `blackburn_2001/` contains 33 chapter sections of the 2001 edition; the flat file `Blackburn_deRijke_Venema_2002_Modal_Logic.md` is the full 2002 edition (365k tokens).

**Revised deduplication targets** (true redundancies only):

| Dir Entry to Remove | Reason |
|---|---|
| `burgess_1982` (dir) | Flat `burgess_1982_i` covers same content; section entries remain |
| `burgess_1982b` (dir) | Flat `burgess_1982_ii` covers same content; section entries remain |
| `venema_1991` (dir) | Flat `venema_1991_app` + `venema_1991_ch2` cover content; section entries remain |
| `venema_1993` (dir) | Flat `venema_1993_anti_axioms` covers content; section entries remain |
| `derijke_1995` (dir) | Flat `derijke_venema_1995` covers content; section entries remain |
| `venema_1993_since` (dir) | Flat `venema_1993_since_until` covers content; section entries remain |

Do NOT remove `blackburn_2001` (dir) — distinct edition from flat `blackburn_2002`. Do NOT remove `gabbay_1994` (dir) — covers full volume, flat entries are per-chapter sections.

**Net reduction**: Remove 6 directory-level entries with token_count=0. Leave 2 (blackburn_2001, gabbay_1994) which serve distinct purposes.

### 4. Per-Directory index.json Consistency

**Finding**: There are NO per-directory index.json files in Literature/ subdirectories. The root index.json is the single source of truth. All section entries use relative paths like `burgess_1982/sec01_axioms-for-tense-logic.md`.

This is the correct centralized architecture — no consistency issues between parent and child index files.

### 5. cslib's specs/literature/ — DEPRECATED.md Requirements

**Current state** of cslib/specs/literature/:
- Has its own index.json (v1, 76 entries)
- Has its own README.md (comprehensive, well-maintained)
- Contains markdown files for: johansson, henkin, bentzen, trufas, from, post, gentzen, hughes, mendelson, chagrov, church, zakharyaschev (cslib-unique)
- Contains copies of BimodalLogic papers: burgess_1982_i, burgess_1982_ii, burgess_1984, gabbay_1994_ch10, reynolds_1992, blackburn_2001 sections (duplicated in Literature/)

**Overlap analysis**:
- ID overlaps: 6 entries (`burgess_1982_ii`, `burgess_1982_i`, `blackburn_2001_ch00`, `reynolds_1992`, `gabbay_1994_ch10`, `burgess_1984`)
- bib_key overlaps: Burgess1982I, Burgess1982II, Burgess1984, GHR94, Reynolds1994, Blackburn2001
- cslib-unique entries (not in Literature/): johansson, gentzen, chagrov, church, mendelson, zakharyaschev, hughes, henkin, bentzen, trufas, from, post — these are propositional/proof-theory papers specific to cslib

**DEPRECATED.md content requirements**:
1. State that cslib/specs/literature/ is deprecated in favor of ~/Projects/Literature/
2. Explain LITERATURE_DIR environment variable points to the centralized repo
3. List which cslib entries have been migrated to Literature/ (the 6 overlap entries)
4. List which cslib entries are cslib-specific and NOT yet in Literature/ (the ~57 unique entries)
5. Provide migration instructions: set LITERATURE_DIR, use --lit flag which reads from LITERATURE_DIR
6. Note that the cslib index.json remains as reference but is no longer the active retrieval target

### 6. Orphan Detection

**Index entries with no filesystem path** (orphaned entries): **0**
All 183 entries in Literature/index.json resolve to existing filesystem paths.

**Filesystem content not in index** (unindexed files):
- README.md — intentionally excluded (not literature content)
- pdfs/ directory — raw PDFs, not indexed (correct: index tracks .md conversions)
- scripts/ directory — tooling, not indexed (correct)

**Conclusion**: The Literature/ repository is fully consistent with zero orphans in either direction.

**cslib orphan status**: Not checked for file-level orphans (not required by task scope), but the index.json itself has 76 entries covering all observed files.

---

## Decisions

1. **Root index is already v2** — no schema upgrade needed for ~/Projects/Literature/index.json
2. **cslib index needs deprecation, not upgrade** — adding v2 fields to 76 entries is unnecessary work when the goal is to point cslib at the centralized repo
3. **6 directory-level entries should be removed** as true redundancies; 2 (blackburn_2001, gabbay_1994) should be kept
4. **token_count=0 on directory entries is a separate bug** from the deduplication issue — even the kept entries need token_count corrected
5. **No per-directory index.json files exist** to synchronize — the centralized design already achieved this

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Removing dir entries breaks agents referencing them by id | Medium | Check if any BimodalLogic prompts reference these ids directly before deleting |
| cslib DEPRECATED.md sends users to Literature/ before unique entries are migrated | Medium | List cslib-unique entries explicitly in DEPRECATED.md so users know what's still local |
| token_count=0 on kept directory entries | Low | Update token_count for blackburn_2001 and gabbay_1994 dir entries using actual chunk sizes |
| bib_key inconsistency (burgess_1982_i vs burgess_1982) | Low | Document the id mapping in DEPRECATED.md |

---

## Schema Upgrade Field Mapping (for cslib)

If cslib's index.json is upgraded (alternative to deprecation):

| Field | Default | Inference rule |
|-------|---------|----------------|
| `doc_type` | `"paper"` | `"book"` for mendelson, church, chagrov, zakharyaschev, hughes; `"chapter"` for section entries of books |
| `source_format` | `"pdf"` | Check cslib/specs/literature/ for .djvu files (chagrov_1997.djvu is present) |
| `zotero_key` | same as `bib_key` | Verify against Zotero library; bib_key=null -> null |
| `project_tags` | `["cslib"]` | All entries are cslib-specific; overlap entries add `"BimodalLogic"` |

---

## Recommended Implementation Approach

**Phase 1** — Remove 6 redundant directory-level entries from Literature/index.json:
- Remove: burgess_1982, burgess_1982b, venema_1991, venema_1993, derijke_1995, venema_1993_since
- Verify section entries for these docs remain intact

**Phase 2** — Fix token_count for kept directory entries:
- Update blackburn_2001 dir entry: estimated 319,612 tokens (from chunk analysis)
- Update gabbay_1994 dir entry: estimated 35,647 tokens (from chunk analysis)

**Phase 3** — Create cslib/specs/literature/DEPRECATED.md:
- Point to ~/Projects/Literature/ as canonical source
- List overlap and cslib-unique entries
- Provide LITERATURE_DIR setup instructions

**Phase 4** — cslib index disposition:
- Keep cslib/specs/literature/index.json as-is (v1) for historical reference
- Do NOT add v2 fields — effort not justified since cslib is being pointed to centralized repo
- Optionally: add `"deprecated": true` flag at the version level

---

## Appendix

### Search Queries Used
- `find /home/benjamin/Projects/Literature -name "index.json"`
- Python3 analysis of Literature/index.json (183 entries, schema field presence)
- Python3 analysis of cslib/specs/literature/index.json (76 entries, schema field presence)
- Directory listing analysis to identify orphaned files and directories

### Key File Paths
- `~/Projects/Literature/index.json` — root index, v2, 183 entries, fully populated
- `~/Projects/cslib/specs/literature/index.json` — v1, 76 entries, all missing v2 fields
- `~/Projects/cslib/specs/literature/README.md` — comprehensive reference guide
- `~/Projects/Literature/scripts/migrate-from-repo.sh` — migration tooling (from task 731)

### Entry Count Summary (Literature/)
- 175 flat file entries (root .md and section .md paths)
- 8 directory-level entries (6 to remove, 2 to keep with fixed token_count)
- 23 subdirectories, all with section entries indexed
- 0 orphaned entries in either direction
