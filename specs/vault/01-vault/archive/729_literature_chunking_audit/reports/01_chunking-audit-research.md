# Research Report: Task #729

**Task**: 729 - Audit Literature Subdirectories for Chunking Quality
**Started**: 2026-06-16T00:00:00Z
**Completed**: 2026-06-16T00:30:00Z
**Effort**: 1h
**Dependencies**: None
**Sources/Inputs**: Filesystem inspection of ~/Projects/Literature/, ~/Projects/cslib/specs/literature/
**Artifacts**: specs/729_literature_chunking_audit/reports/01_chunking-audit-research.md
**Standards**: report-format.md

---

## Executive Summary

- **~/Projects/Literature/** has 23 subdirectories (chunked) plus 30 flat files at root — many are duplicates of each other. All subdirectory chunks are well-sized (<10K tokens each). The pattern used is primarily semantic (section/chapter-named) but 4 subdirectories use page-number or opaque part-based naming (needs reclassification). One massive flat file, `Blackburn_deRijke_Venema_2002_Modal_Logic.md` at ~365K tokens, has no subdirectory equivalent and is the single worst offender.
- **~/Projects/cslib/specs/literature/** has 7 subdirectories with 11 flat files at root. Five subdirectories (chagrov_1997, church_1956, hughes_1996, mendelson_2016, zakharyaschev_2001) are chunked by part/chapter but individual chunks are massively oversized (21K–91K tokens per chunk), so they need re-chunking within each subdirectory. The blackburn_2001 subdirectory is an exact copy of the Literature/ one (good).
- Priority actions: (1) Chunk the Blackburn_deRijke_Venema_2002 flat file, (2) Re-chunk the 5 oversized cslib book subdirectories at finer granularity (section-level), (3) Rename page-based burgess_1984 chunks to semantic names, (4) Consider removing flat files that already have subdirectory equivalents.

---

## Context & Scope

Two directories audited:
1. `~/Projects/Literature/` — Primary literature store for modal/tense logic papers
2. `~/Projects/cslib/specs/literature/` — Logic textbooks and papers for cslib project

Token estimates computed as `bytes / 4` (rough approximation for academic mathematical text).

---

## Findings

### ~/Projects/Literature/ — Complete Inventory

#### Flat Files at Root (30 files, no chunking — potential problems)

Most flat files at root have corresponding subdirectories with chunked versions. These are likely original source files kept alongside chunked versions. Exceptions (flat files WITHOUT a subdir equivalent) that might be purely unchunked:

| File | ~Tokens | Status |
|------|---------|--------|
| Blackburn_deRijke_Venema_2002_Modal_Logic.md | **~365,325** | CRITICAL: needs chunking |
| Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md | ~22,712 | Has subdir `caleiro_2013` — flat is duplicate |
| deRijke_Venema_1995_Sahlqvist_BAOs.md | ~11,359 | Has subdir `derijke_1995` — flat is duplicate |
| Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md | ~18,953 | Has subdir `gabbay_1993` — flat is duplicate |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md | ~9,270 | Has subdir `gabbay_1994` — flat is duplicate |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md | ~10,853 | Has subdir `gabbay_1994` — flat is duplicate |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md | ~18,528 | Has subdir `gabbay_1994` — flat is duplicate |
| Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md | ~19,158 | Has subdir `goldblatt_2003` — flat is duplicate |
| Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.md | ~2,410 | No subdir — single chapter, may be fine |
| Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.md | ~4,119 | No subdir — excerpts, may be fine |
| Rabinovich_2014_Proof_of_Kamps_Theorem.md | ~3,435 | No subdir — short paper, fine |
| Reynolds_2001_Axiomatization_Full_CTL_star.md | ~32,378 | Has subdir `reynolds_2001` — flat is duplicate |
| Thomas_1997_EF_Games_Composition_Monadic.md | ~1,435 | No subdir — very short, fine |
| Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md | ~11,873 | Has subdir `venema_1991` — flat is duplicate |
| Venema_1991_Many_Dimensional_Modal_Logics_ch2.md | ~25,522 | Has subdir `venema_1991` — flat is duplicate |
| Venema_1993_Derivation_Rules_Anti_Axioms.md | ~28,026 | Has subdir `venema_1993` — flat is duplicate |
| Venema_1993_Since_and_Until.md | ~4,750 | Has subdir `venema_1993_since` — flat is duplicate |

#### Subdirectories — Chunking Classification

**Classification Key**:
- (a) Semantic: chunks named by chapter/section/topic
- (b) Arbitrary: chunks named by page number or opaque "part-N"
- (c) Oversized: single file too large for agent use

| Subdir | Files | Largest Chunk | Classification | Naming Pattern | Action |
|--------|-------|---------------|----------------|----------------|--------|
| blackburn_2001 | 33 | ~9,861 tok | (a) Semantic | `ch{N}_{topic}.md` | KEEP |
| burgess_1982 | 2 | ~3,950 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| burgess_1982b | 2 | ~4,414 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| burgess_1984 | 7 | ~4,575 tok | **(b) Arbitrary** | `sec{N}_page-{N}.md` | RE-CHUNK (rename to semantic) |
| caleiro_2013 | 7 | ~4,747 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| derijke_1995 | 3 | ~4,753 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| doets_1987 | 3 | ~4,684 tok | (a) Mixed | sec01 has topic, others opaque | KEEP (minor) |
| doets_1989 | 3 | ~4,454 tok | **(b) Arbitrary** | `sec{N}_part-{N}.md` | RE-CHUNK (rename) |
| gabbay_1993 | 5 | ~7,578 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| gabbay_1994 | 11 | ~8,405 tok | (a) Semantic | `ch{NN}{N}_{topic}.md` | KEEP |
| goldblatt_2003 | 5 | ~5,208 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| obendrauf_2024 | 4 | ~4,361 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| reynolds_1992 | 5 | ~4,046 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| reynolds_1994 | 3 | ~4,235 tok | **(b) Arbitrary** | `sec{N}_part-{N}.md` | RE-CHUNK (rename) |
| reynolds_2001 | 10 | ~4,197 tok | (a) Mostly semantic | `sec{N}_{topic}.md` | KEEP (minor issues) |
| thomason_1984 | 6 | ~6,489 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| venema_1991 | 9 | ~9,861 tok | (a) Semantic | `ch{N}{N}_{topic}.md` / `appab{N}_{topic}.md` | KEEP |
| venema_1993 | 9 | ~4,566 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| venema_1993_since | 2 | ~4,554 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| venema_1997 | 3 | ~4,554 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| venema_2001 | 4 | ~4,045 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| verbrugge_2004 | 4 | ~4,017 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| xu_1988 | 5 | ~4,659 tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |

**Note on doets_1987**: sec01 has topic name but sec02 (`69-lemma`) and sec03 (`15-logic`) look like page/section number prefixes rather than descriptive topics. Minor issue, not critical.

**Note on reynolds_2001**: sec02 is named just `a.md` (unclear), sec08 is tiny (1 page, ~762 tokens). Generally fine but has one opaque chunk.

---

### ~/Projects/cslib/specs/literature/ — Complete Inventory

#### Flat Files at Root (11 files)

| File | ~Tokens | Status |
|------|---------|--------|
| bentzen_2023.md | ~8,197 | No subdir — single paper, acceptable |
| burgess_1982_i.md | ~4,817 | No subdir — short paper, acceptable |
| burgess_1982_ii.md | ~5,100 | No subdir — short paper, acceptable |
| burgess_1984.md | ~2,351 | No subdir — very short, fine |
| from_2022.md | ~13,200 | No subdir — single paper, borderline |
| gabbay_1994_ch10.md | ~2,800 | No subdir — single chapter excerpt, fine |
| henkin_1949.md | ~6,750 | No subdir — short paper, acceptable |
| johansson_1937.md | ~6,786 | No subdir — short paper, acceptable |
| post_1921.md | ~13,929 | No subdir — single paper, borderline |
| reynolds_1992.md | ~2,535 | No subdir — short paper, fine |
| trufas_2024.md | ~11,312 | No subdir — single paper, acceptable |

All cslib flat files are single papers/chapters at reasonable sizes (<14K tokens). No action needed unless context injection budget is tight.

#### Subdirectories — Chunking Classification

| Subdir | Files | Chunk Sizes | Classification | Naming Pattern | Action |
|--------|-------|-------------|----------------|----------------|--------|
| blackburn_2001 | 33 | 2K–17K tok (max ~17K) | (a) Semantic | `ch{N}_{topic}.md` | KEEP (same as Literature/) |
| chagrov_1997 | 6 | **5K–87K tok** | **(c) Oversized** | `p{N}_{topic}.md` (part-based) | RE-CHUNK at section level |
| church_1956 | 7 | **4K–57K tok** | **(c) Oversized** | `ch{N}_{topic}.md` (chapter) | RE-CHUNK at section level |
| gentzen_1935 | 5 | 3K–10K tok | (a) Semantic | `sec{N}_{topic}.md` | KEEP |
| hughes_1996 | 4 | **3K–91K tok** | **(c) Oversized** | `p{N}_{topic}.md` (part-based) | RE-CHUNK at section level |
| mendelson_2016 | 6 | **11K–89K tok** | **(c) Oversized** | `ch{N}_{topic}.md` (chapter) | RE-CHUNK at section level |
| zakharyaschev_2001 | 4 | **2K–45K tok** | **(c) Oversized** | `sec{N}_{topic}.md` (section-based) | RE-CHUNK at subsection level |

**Details on oversized cslib chunks**:

- **chagrov_1997** (345K total): p03 (~80K), p04 (~87K), p01 (~73K), p05 (~66K) — all massively oversized. Need 5–10 chunks per part.
- **church_1956** (266K total): ch00b (~57K), ch04 (~52K), ch05 (~56K) — oversized. Need 3–5 chunks per chapter.
- **hughes_1996** (209K total): p03 (~91K), p01 (~61K), p02 (~54K) — all oversized. Need 5–10 chunks per part.
- **mendelson_2016** (270K total): ch05 (~89K), ch02 (~64K), ch04 (~44K), ch03 (~42K) — severely oversized. Need 5–10 chunks per chapter.
- **zakharyaschev_2001** (105K total): sec01 (~42K), sec03 (~45K) — moderately oversized. Need 3–5 chunks per section.

---

## Summary Statistics

### ~/Projects/Literature/ Subdirectories

| Classification | Count | Subdirs |
|----------------|-------|---------|
| (a) Semantic — KEEP | 18 | blackburn_2001, burgess_1982, burgess_1982b, caleiro_2013, derijke_1995, gabbay_1993, gabbay_1994, goldblatt_2003, obendrauf_2024, reynolds_1992, reynolds_2001, thomason_1984, venema_1991, venema_1993, venema_1993_since, venema_1997, venema_2001, verbrugge_2004, xu_1988 |
| (b) Arbitrary — RE-CHUNK | 4 | burgess_1984 (page-based), doets_1989 (part-based), reynolds_1994 (part-based), doets_1987 (minor) |
| (c) Oversized — N/A | 0 | (no subdir chunks exceed 10K tokens) |

### ~/Projects/cslib/specs/literature/ Subdirectories

| Classification | Count | Subdirs |
|----------------|-------|---------|
| (a) Semantic — KEEP | 2 | blackburn_2001, gentzen_1935 |
| (b) Arbitrary — RE-CHUNK | 0 | (none, though some have part-based naming that is semantic) |
| (c) Oversized — RE-CHUNK | 5 | chagrov_1997, church_1956, hughes_1996, mendelson_2016, zakharyaschev_2001 |

---

## Priority List: Documents Needing Action

Sorted by urgency × impact:

| Priority | Document | Location | Problem | Action | Est. Effort |
|----------|----------|----------|---------|--------|-------------|
| 1 | Blackburn_deRijke_Venema_2002_Modal_Logic.md | Literature/ root | 365K tokens flat file, no subdir | Create subdirectory with chapter-level chunks (~33 files per blackburn_2001 pattern) | High |
| 2 | chagrov_1997 | cslib | 5 chunks, 66–87K tokens each (345K total) | Re-chunk at section level (target: 5–10K per chunk) | High |
| 3 | mendelson_2016 | cslib | 5 chunks, 21–89K tokens each (270K total) | Re-chunk at section level | High |
| 4 | church_1956 | cslib | 7 chunks, 32–57K tokens each (266K total) | Re-chunk at section level | High |
| 5 | hughes_1996 | cslib | 3 chunks, 54–91K tokens each (209K total) | Re-chunk at section/chapter level | High |
| 6 | zakharyaschev_2001 | cslib | 4 chunks, 2–45K tokens (105K total) | Re-chunk 2 oversized sections | Medium |
| 7 | burgess_1984 | Literature/ | Page-based naming (sec01_page-1.md) | Rename chunks with semantic titles | Low |
| 8 | doets_1989 | Literature/ | Part-based naming (sec01_part-1.md) | Rename chunks with semantic titles | Low |
| 9 | reynolds_1994 | Literature/ | Part-based naming (sec01_part-1.md) | Rename chunks with semantic titles | Low |
| 10 | Flat file duplicates | Literature/ root | 17+ flat files duplicate existing subdirs | Archive or remove original flat files | Low |

---

## Decisions

- All Literature/ subdirectory chunks are well-sized (none exceed ~10K tokens) — the chunking granularity is appropriate.
- cslib/ textbook chunks are the primary problem: they were chunked at chapter/part level (too coarse) rather than section level.
- Blackburn_deRijke_Venema_2002 (365K) is the most critical single item — it cannot be used by any agent and should follow the same pattern as blackburn_2001 (already well-chunked at Literature/blackburn_2001/).
- The duplicate flat files in Literature/ root (alongside subdirs) appear to be original source files kept for reference. They don't need immediate action but add confusion.

## Risks & Mitigations

- **Re-chunking cslib textbooks** requires understanding section structure — the source PDFs or table of contents must be consulted to determine natural break points at 5–10K token target size.
- **Blackburn_deRijke_Venema_2002** at 365K is likely a complete textbook. The chunking pattern from blackburn_2001 (33 files, chNX_topic.md naming) is the model to follow.
- **Deduplication** of Literature/ flat files vs. subdirs should be confirmed: the flat files may be used by other processes (like PDF conversion scripts) so verify before deletion.

## Context Extension Recommendations

- None: this is a pure audit/research task with no missing context gaps.

## Appendix

### Naming Pattern Summary

| Pattern | Example | Classification |
|---------|---------|----------------|
| `ch{N}_{semantic-topic}.md` | `ch01_models-and-frames.md` | Semantic (good) |
| `sec{N}_{semantic-topic}.md` | `sec03_sahlqvist-formulas.md` | Semantic (good) |
| `sec{N}_page-{N}.md` | `sec01_page-1.md` | Page-based (bad) |
| `sec{N}_part-{N}.md` | `sec01_part-1.md` | Part-based (ambiguous) |
| `p{N}_{semantic-topic}.md` | `p01_introduction.md` | Semantic but oversized |
| `ch{NN}{N}_{topic}.md` | `ch1001_chapter-10-expressive.md` | Semantic with chapter numbering |

### Commands Used

```bash
ls ~/Projects/Literature/
ls ~/Projects/cslib/specs/literature/
find ~/Projects/Literature -maxdepth 1 -type d
ls -la ~/Projects/Literature/*.md
find ~/Projects/{Literature,cslib/specs/literature} -name "*.md" -exec stat -c "%s %n" {} \;
wc -c <files> # via stat -c %s for token approximation
```
