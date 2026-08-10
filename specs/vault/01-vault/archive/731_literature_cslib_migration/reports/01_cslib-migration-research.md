# Research Report: Task #731

**Task**: 731 - Migrate cslib's Literature Entries into Central Literature Repo
**Started**: 2026-06-16T10:00:00Z
**Completed**: 2026-06-16T10:30:00Z
**Effort**: ~2 hours research
**Dependencies**: Task 730 (semantic chunking standards)
**Sources/Inputs**: Codebase inspection of `/home/benjamin/Projects/cslib/specs/literature/` and `/home/benjamin/Projects/Literature/`
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- cslib's `specs/literature/` has **76 index entries** across 13 documents; **70 are unique** to cslib (not yet in Literature)
- The 6 ID overlaps are real but contain a critical mislabeling: cslib's `reynolds_1992` ID actually contains Reynolds (1994) content; Literature has that same paper indexed as `reynolds_1994`. So the IDs "collide" but point to **different papers** — this requires ID remapping, not deduplication
- For the 5 true content overlaps (burgess_1982_i/ii, burgess_1984, gabbay_1994_ch10, blackburn_2001_ch00), **Literature's versions are always fuller/larger** and should be kept; cslib entries need only `project_tags: ["cslib"]` added
- cslib's `chagrov_1997.djvu` (7.1 MB) exists on disk; the markdown conversion is already complete in the same repo at `chagrov_1997/` (6 files, ~1.4 MB of markdown)
- A migration script already exists at `/home/benjamin/Projects/Literature/scripts/migrate-from-repo.sh` that handles v1→v2 schema backfilling automatically

---

## Context & Scope

cslib (`~/Projects/cslib`) is a Lean 4 formalization project for classical and modal propositional logic. It maintains its own per-project `specs/literature/` directory with 76 indexed literature entries relevant to completeness proofs, canonical models, and modal logic foundations.

The goal is to migrate these entries into the centralized `~/Projects/Literature/` repository (v2 schema), eliminating the per-project copy while preserving cslib-specific metadata via `project_tags`.

---

## Findings

### cslib Index Schema (v1)

**Version**: 1
**Location**: `/home/benjamin/Projects/cslib/specs/literature/index.json`
**Entry count**: 76 entries
**Schema fields** (from `schema` key):
- `id` — Unique identifier (author_year[_section])
- `bib_key` — BibTeX key
- `title` — Full title
- `authors` — Author(s) as string (NOT array — differs from v2)
- `year` — Publication year (integer)
- `section` — Section or chapter description (null for whole-paper)
- `path` — Path relative to `specs/literature/`
- `page_range` — Page range within original source
- `token_count` — Estimated token count (words * 1.3)
- `keywords` — 6-10 keywords
- `summary` — One-sentence description

**Missing v2 fields**: `doc_type`, `source_format`, `zotero_key`, `zotero_path`, `project_tags`, `parent_doc`

### Literature Index Schema (v2)

**Version**: 2
**Location**: `/home/benjamin/Projects/Literature/index.json`
**Entry count**: 183 entries
**Additional v2 fields** (beyond v1):
- `doc_type` — One of: paper, book, chapter, section
- `source_format` — One of: pdf, djvu, manual
- `zotero_key` — Canonical Zotero/Better BibTeX key (may differ from bib_key)
- `zotero_path` — Path to PDF in Zotero storage (null in most cases)
- `project_tags` — Array of project names (e.g., `["BimodalLogic"]`)
- `parent_doc` — ID of parent document for chapters/sections (null for standalone papers)

**Note**: v2 `authors` field is an **array of strings**, while v1 uses a plain string. This requires transformation during migration.

### cslib Document Coverage (70 unique entries)

The 70 unique cslib entries span 13 documents:

| Document | Entry Count | Notes |
|----------|------------|-------|
| `blackburn_2001` (chapters ch01a–ch07e) | 35 | Full book chapters; files identical to Literature's `blackburn_2001/` directory |
| `chagrov_1997` (p00–p05) | 6 | Already converted from DJVU; ready to migrate |
| `church_1956` (ch00–ch05) | 6 | Church's Introduction to Mathematical Logic |
| `gentzen_1935` (sec00–sec05) | 5 | Gentzen's Investigations into Logical Deduction |
| `hughes_1996` (p00–p03) | 4 | Hughes & Cresswell modal logic textbook |
| `mendelson_2016` (ch00–ch05) | 6 | Mendelson's Introduction to Mathematical Logic |
| `zakharyaschev_2001` (sec00–sec03) | 4 | Advanced Modal Logic handbook chapter |
| `johansson_1937` | 1 | Der Minimalkalkül |
| `henkin_1949` | 1 | Completeness of First-Order Functional Calculus |
| `bentzen_2023` | 1 | Verified completeness in Henkin-style |
| `trufas_2024` | 1 | Intuitionistic Propositional Logic in Lean |
| `from_2022` | 1 | SeCaV sequent calculus verifier |
| `post_1921` | 1 | Post's Introduction to General Theory of Elementary Propositions |

### Overlap Analysis (6 Shared IDs)

The `comm` comparison found 6 IDs present in both indexes. Analysis reveals these fall into two categories:

#### True ID Collisions (same ID, same paper, same content)

| ID | cslib tokens | Literature tokens | cslib file size | Literature file size | Verdict |
|----|-------------|-------------------|-----------------|---------------------|---------|
| `burgess_1982_i` | 4,995 | 5,437 | 19,269 bytes | 24,125 bytes | Literature is fuller |
| `burgess_1982_ii` | 5,235 | 5,589 | 20,401 bytes | 27,433 bytes | Literature is fuller |
| `burgess_1984` | 2,152 | 22,784 | 9,405 bytes | 99,914 bytes | Literature is MUCH fuller |
| `gabbay_1994_ch10` | 2,279 | 10,764 | 11,203 bytes | 43,414 bytes | Literature is MUCH fuller |
| `blackburn_2001_ch00` | 5,801 | 5,801 | 37,366 bytes | 37,366 bytes | Identical (same file) |

For all 5 true overlaps, **the Literature version is equal or fuller**. Action: keep Literature versions, add `"cslib"` to their `project_tags`.

#### False ID Collision (same ID, different papers)

| ID | cslib content | Literature content |
|----|--------------|-------------------|
| `reynolds_1992` | Reynolds (1994) "Axiomatising First-Order Temporal Logic" (bib_key: Reynolds1994, 2,072 tokens) | Reynolds (1992) "Axiomatization for Until and Since over the Reals without IRR Rule" (bib_key: Reynolds1992, 15,636 tokens) |

**Critical finding**: cslib's `reynolds_1992` entry is **mislabeled** — it contains the 1994 Reynolds paper, not the 1992 paper. Literature correctly has the 1994 paper indexed as `reynolds_1994`. These two entries do NOT conflict in content; they just share an ID.

**Required action**: Rename cslib's `reynolds_1992` to `reynolds_1994` before migration (or skip it since Literature's `reynolds_1994` entry already covers the same paper with much higher quality: 10,015 tokens vs. 2,072 tokens).

#### Literature already has reynolds_1994 — comparison:

| | cslib `reynolds_1992` | Literature `reynolds_1994` |
|-|----------------------|---------------------------|
| Title | Axiomatising First-Order Temporal Logic | Axiomatising First-Order Temporal Logic |
| Year | 1994 | 1994 |
| Tokens | 2,072 | 10,015 |
| Verdict | Much smaller — skip/superseded |

### blackburn_2001 Chapter Handling

cslib has 35 blackburn_2001 chapter entries (ch01a–ch07e) plus the ch00 overlap. The Literature `blackburn_2001/` directory contains the **identical markdown files** (verified via diff). However, Literature's index uses different IDs for these chapters:

- cslib: `blackburn_2001_ch01a`, `blackburn_2001_ch01b`, etc.
- Literature: `blackburn_2001_ch01_sec01-02`, `blackburn_2001_ch01_sec03`, etc.

The files themselves are identical, but Literature has already re-indexed these files under its own section-based naming scheme. The cslib entries would create duplicate ID entries with different content pointers. Options:
1. Skip all blackburn_2001 chapters (Literature already has them, just with different IDs)
2. Update Library index to add `"cslib"` to `project_tags` on the Literature's equivalent section entries

**Recommended**: Skip the 35 cslib blackburn_2001 chapter entries since the actual markdown content is already present in Literature; just tag the existing Literature entries with `"cslib"`.

### chagrov_1997 DJVU Status

- **DJVU file**: `/home/benjamin/Projects/cslib/specs/literature/chagrov_1997.djvu` (7,152,341 bytes = 7.1 MB) — EXISTS
- **Markdown conversion**: Already complete at `/home/benjamin/Projects/cslib/specs/literature/chagrov_1997/` directory:
  - `p00_front-matter.md` (23,558 bytes)
  - `p01_introduction.md` (291,230 bytes)
  - `p02_kripke-semantics.md` (135,437 bytes)
  - `p03_adequate-semantics.md` (319,762 bytes)
  - `p04_properties-of-logics.md` (349,585 bytes)
  - `p05_algorithmic-problems.md` (262,800 bytes)
- **Sub-index**: `/home/benjamin/Projects/cslib/specs/literature/chagrov_1997/index.json` uses the "chapters" format with 6 entries (p00–p05)
- **Literature status**: No chagrov entries exist in `/home/benjamin/Projects/Literature/`

**Conclusion**: The DJVU conversion task mentioned in the task description is **already done**. No additional conversion needed. The 6 chagrov entries are ready to migrate as-is.

### Schema Transformation Requirements (v1 → v2)

For each cslib root entry being migrated:

| v1 Field | v2 Field | Transformation |
|----------|----------|----------------|
| `authors` (string) | `authors` (array) | Wrap in array: `["string value"]` |
| — | `doc_type` | Infer: standalone papers → `"paper"`, subdirectory chapters → `"chapter"` or `"section"` |
| — | `source_format` | Default to `"pdf"` (cslib literature is PDF-sourced) |
| — | `zotero_key` | Lookup from known bib_key → zotero_key map (script has this) |
| — | `zotero_path` | `null` for all |
| — | `project_tags` | `["cslib"]` |
| — | `parent_doc` | For chapters: set to parent book ID (e.g., `"chagrov_1997"`) |

The migration script at `/home/benjamin/Projects/Literature/scripts/migrate-from-repo.sh` handles all these transformations automatically. It also handles the bib_key → zotero_key divergences (e.g., `Burgess1982II` → `Burgess1982a`).

### Migration Script Assessment

The existing migration script (`migrate-from-repo.sh`) is designed exactly for this use case:
- Reads root entries from `index.json`
- Reads subdirectory `index.json` files (chapters format)
- Backfills all v2 schema fields
- Copies markdown files preserving directory structure
- Skips duplicates by ID (idempotent)
- Tags entries with the repo name

**Gap**: The script uses `REPO_NAME=$(basename "$REPO_PATH")` for `project_tags`, which would give `"cslib"` — correct for this task.

**Known issue**: The script will skip existing IDs. The false collision `reynolds_1992` will be skipped (Literature's `reynolds_1992` IRR paper will be preserved), but cslib's 1994 Reynolds content will be **silently dropped** rather than migrated as `reynolds_1994`. This needs manual handling.

---

## Decisions

1. **For all 5 true ID overlaps (burgess_1982_i/ii, burgess_1984, gabbay_1994_ch10, blackburn_2001_ch00)**: Keep Literature's fuller versions; add `"cslib"` to `project_tags` in Literature's entries
2. **For cslib `reynolds_1992` (mislabeled)**: Skip migration — Literature's `reynolds_1994` already covers the same paper with higher quality (10,015 vs. 2,072 tokens)
3. **For 35 blackburn_2001 chapter entries**: Skip migration — identical files already exist in Literature; add `"cslib"` to Literature's equivalent section entries' `project_tags`
4. **For chagrov_1997**: Migrate all 6 chapter entries; no additional DJVU conversion needed
5. **Migration order**: Use existing `migrate-from-repo.sh` script with manual fixes for edge cases

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `reynolds_1992` ID collision causes wrong paper to be silently dropped | HIGH | Manually confirm Literature's `reynolds_1992` is preserved; cslib's 1994 paper already covered by `reynolds_1994` |
| blackburn_2001 chapter re-chunking mismatch (cslib ch01a vs Literature sec01-02) | MEDIUM | Files are identical; update project_tags on existing Literature entries rather than re-importing |
| chagrov_1997 already exists as partial entries in cslib but not yet in Literature | LOW | Clean migration path; no conflicts |
| DJVU binary file should not be copied to Literature (gitignored) | LOW | Migration script only copies markdown files; source DJVU stays in cslib |
| authors field format mismatch (string vs array) | LOW | Migration script handles this transformation |

---

## Recommended Migration Strategy

### Phase 1: Prepare (Manual Pre-flight)
1. Verify the `reynolds_1992` collision status — confirm cslib's paper (Reynolds 1994) is already covered by Literature's `reynolds_1994` entry
2. List all 35 blackburn_2001 chapter entries in Literature and confirm file identity

### Phase 2: Run Migration Script
```bash
cd ~/Projects/Literature
./scripts/migrate-from-repo.sh ~/Projects/cslib
```
This will:
- Skip the 6 ID-overlapping entries (correct behavior for burgess/gabbay/blackburn_ch00)
- Import all 70 unique entries (chagrov, church, gentzen, hughes, mendelson, zakharyaschev, standalone papers)
- Wait — will also try to import blackburn ch01a-ch07e (35 entries) as NEW IDs since they don't exist in Literature's index by those names

### Phase 3: Manual Post-migration
1. **Tag overlap entries**: Add `"cslib"` to `project_tags` in Literature's entries for burgess_1982_i/ii, burgess_1984, gabbay_1994_ch10, blackburn_2001_ch00
2. **Tag blackburn chapters**: The 35 blackburn_2001 chapter entries imported by cslib IDs (ch01a-ch07e) will create duplicate references to the same files but with different IDs — this needs resolution. Options:
   - Remove the cslib chapter entries post-import and add `"cslib"` to existing Literature section entries
   - OR accept both ID schemes (messy but functional)
3. **Verify reynolds**: Confirm `reynolds_1994` in Literature covers cslib's `reynolds_1992` content

### Phase 4: Cleanup
1. Once migration is verified, update cslib to point to `LITERATURE_DIR` via environment variable
2. Optionally deprecate cslib's `specs/literature/` directory (or leave as per-project fallback)

---

## Context Extension Recommendations

- **Topic**: cslib-specific literature overlap handling
- **Gap**: No documented pattern for handling ID namespace collisions during cross-project migration
- **Recommendation**: Add a section to `specs/literature/README.md` documenting how ID collisions and mislabeled entries were resolved

---

## Appendix

### Entry Counts Summary
- cslib total entries: 76
- Literature total entries: 183
- Shared IDs (true content overlaps): 5 (burgess×3, gabbay, blackburn_ch00)
- False ID collision: 1 (reynolds_1992 → different papers)
- cslib-unique entries: 70 (including 35 blackburn chapters already present in Literature files)
- Net new content entries to add: ~35 (chagrov×6, church×6, gentzen×5, hughes×4, mendelson×6, zakharyaschev×4, standalone papers×5, minus the effectively-duplicate blackburn chapter entries)

### Key File Paths
- cslib literature: `/home/benjamin/Projects/cslib/specs/literature/`
- Central literature: `/home/benjamin/Projects/Literature/`
- Migration script: `/home/benjamin/Projects/Literature/scripts/migrate-from-repo.sh`
- chagrov DJVU: `/home/benjamin/Projects/cslib/specs/literature/chagrov_1997.djvu` (already converted)
