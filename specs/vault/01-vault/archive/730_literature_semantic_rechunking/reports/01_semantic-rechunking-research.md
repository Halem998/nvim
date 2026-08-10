# Research Report: Task #730

**Task**: 730 - Re-chunk Literature Files at Semantic Boundaries
**Started**: 2026-06-16T00:00:00Z
**Completed**: 2026-06-16T01:00:00Z
**Effort**: 1.5h
**Dependencies**: Task 728 (source recovery), Task 729 (chunking audit)
**Sources/Inputs**: Filesystem inspection of ~/Projects/Literature/, ~/Projects/cslib/specs/literature/, literature-chunk.sh
**Artifacts**: specs/730_literature_semantic_rechunking/reports/01_semantic-rechunking-research.md
**Standards**: report-format.md

---

## Executive Summary

- The existing `literature-chunk.sh` uses markdown heading splits (`#`, `##`, `###`) with a 512-token target — it cannot be applied to these files because the PDF-converted source documents use **page-marker headings** (`## Page N`) rather than semantic headings, making the script blind to actual document structure.
- The **Blackburn 2002** (365K tokens) flat file (`~/Projects/Literature/Blackburn_deRijke_Venema_2002_Modal_Logic.md`) has chapter and section headings embedded as bare lines in the text (e.g., `1 Basic Concepts`, `1.1 Relational Structures`), not as markdown headings — chapter 1 starts at page 22 (line 809). The existing `blackburn_2001/` directory (33 chunks) is a ready-made semantic template.
- **5 cslib oversized subdirectories** (chagrov_1997, church_1956, hughes_1996, mendelson_2016, zakharyaschev_2001) range from 105K–1.38M total bytes. They use subsection-level headings embeddable via regex: numbered subsections in the form `N.N\t<Title>` (chagrov), `N.N <Title>` (mendelson), or `N.N <Title>` patterns, all parseable.
- **4 arbitrary-chunked Literature/ subdirectories** (burgess_1984, doets_1989, reynolds_1994, and doets_1987 minor) already have correct-sized chunks — they only need file renames to semantic names (the semantic content is already identified in index.json titles).
- **Recommended strategy**: (1) Create `blackburn_2002/` subdirectory manually by splitting the flat file at chapter+section boundaries; (2) Rename the 4 arbitrary Literature/ subdirectory files to match their index.json semantic titles; (3) For cslib: split each oversized chunk at subsection boundaries using the N.N heading pattern; (4) Update index.json entries for every affected document; (5) Remove flat files that have chunked equivalents.

---

## Context & Scope

Two literature stores were investigated for this task:

1. `~/Projects/Literature/` — Primary modal/tense logic paper collection
2. `~/Projects/cslib/specs/literature/` — Logic textbooks for cslib project

The task is to re-chunk arbitrarily split files at semantic boundaries and update index.json entries. Source PDFs are available but the primary data for chunking is the existing markdown files.

---

## Findings

### Chunking Script Analysis

**File**: `/home/benjamin/.config/nvim/.claude/scripts/literature-chunk.sh`

The script uses a two-pass algorithm:
1. **Pass 1**: Split at markdown heading boundaries (`#`, `##`, `###`, `####`), building section_path breadcrumbs
2. **Pass 2**: Subdivide chunks >512 tokens at paragraph then sentence breaks; atomic blocks (Theorem/Proof/Definition) up to 1024-token cap

**Critical limitation**: All PDF-converted files in this collection use `## Page N` as the only heading structure (one heading per source PDF page). The literature-chunk.sh script therefore produces one chunk per source page with paragraph-level subdivision — this is the **token-target approach** that produced the existing arbitrary chunks. It has no knowledge of chapter/section structure embedded in the prose.

**Why it fails**: When applied to `Blackburn_deRijke_Venema_2002_Modal_Logic.md`, the script would split at `## Page N` boundaries (569 pages → up to 569 chunks), not at `1.1 Relational Structures` boundaries. The semantic headings are invisible to it because they are not formatted as markdown headings.

### Blackburn 2002 Flat File Analysis

**File**: `/home/benjamin/Projects/Literature/Blackburn_deRijke_Venema_2002_Modal_Logic.md`
- **Size**: 1,461,302 bytes (~365K tokens), 90,176 lines
- **Structure**: 569 `## Page N` markers, content in running prose
- **Chapter headings**: Embedded as bare lines `N <Title>` (e.g., `1 Basic Concepts`)
- **Section headings**: Embedded as bare lines `N.N <Title>` (e.g., `1.1 Relational Structures`)

**Detected section map** (via regex `^(\d+)\.(\d+)\s+([A-Z][A-Za-z ]{3,50})$` after page 22):

| Ch | Section | Title | Page | Line |
|----|---------|-------|------|------|
| 1 | – | Basic Concepts | 22 | 809 |
| 1 | 1.1 | Relational Structures | 22 | 834 |
| 1 | 1.2 | Modal Languages | 29 | 1731 |
| 1 | 1.3 | Models and Frames | 36 | 2851 |
| 1 | 1.4 | General Frames | 47 | 5051 |
| 1 | 1.5 | Modal Consequence Relations | 51 | 5919 |
| 1 | 1.6 | Normal Modal Logics | 53 | 6191 |
| 1 | 1.7 | Historical Overview | 58 | 6806 |
| 2 | – | Models | 72 | 7538 |
| 2 | 2.1 | Invariance Results | 71 | 7492 |
| 2 | 2.2 | Bisimulations | 84 | 10156 |
| 2 | 2.3 | Finite Models | 93 | 11897 |
| 2 | 2.4 | Standard Translation | 103 | 13744 |
| 2 | 2.7 | Simulation and Safety | 130 | 19415 |
| 3 | – | Frames | 146 | 22043 |
| 3 | 3.4 | Finite Frames | 164 | 25557 |
| 3 | 3.6 | Sahlqvist Formulas | 177 | 27447 |
| 3 | 3.7 | More about Sahlqvist Formulas | 188 | 30338 |
| 3 | 3.8 | Advanced Frame Theory | 200 | 33208 |
| 4 | – | Completeness | 212 | 34632 |
| 4 | 4.1 | Preliminaries | 211 | 34559 |
| 4 | 4.2 | Canonical Models | 218 | 35589 |
| 4 | 4.3 | Applications | 223 | 36441 |
| 4 | 4.4 | Limitative Results | 233 | 38088 |
| 4 | 4.5 | Transforming the Canonical Model | 239 | 39010 |
| 4 | 4.8 | Finitary Methods I | 261 | 42684 |
| 4 | 4.9 | Finitary Methods II | 268 | 44363 |
| 5 | – | Algebras and General Frames | 284 (approx) | – |
| 5 | 5.1 | Logic as Algebra | 284 | 46694 |
| 5 | 5.2 | Algebraizing Modal Logic | 296 | 48173 |
| 5 | 5.4 | Duality Theory | 316 | 52103 |
| 5 | 5.5 | General Frames | 325 | 54263 |
| 5 | 5.6 | Persistence | 339 | 57366 |
| 6 | – | Computability and Complexity | 334 (approx) | – |
| 6 | 6.2 | Decidability via Finite Models | 360 | 60343 |
| 6 | 6.3 | Decidability via Interpretations | 369 | 61191 |
| 6 | 6.5 | Undecidability via Tiling | 386 | 64565 |
| 6 | 6.7 | PSPACE | 403 | 67093 |
| 6 | 6.8 | EXPTIME | 415 | 69085 |
| 7 | – | Extended Modal Logic | 436 | 71645 |
| 7 | 7.1 | Logical Modalities | 436 | 71663 |
| 7 | 7.2 | Since and Until | 448 | 73430 |
| 7 | 7.3 | Hybrid Logic | 456 | 74813 |
| 7 | 7.4 | The Guarded Fragment | 468 | 76840 |

**Note**: Some sections were not detected by the regex (2.5, 2.6, 3.1, 3.2, 3.3, 3.5, 4.6, 4.7, 5.3, 6.1, 6.4, 6.6, 7.5, 7.6, 7.7, Appendices). These exist in the TOC and the corresponding content should be detectable with a more permissive pattern or manual boundary search.

**Reference template**: The existing `blackburn_2001/` directory has 33 chunks with `ch{N}_{topic}.md` naming. The 2002 edition has the same chapter structure and slightly different section groupings. The implementation should create `blackburn_2002/` using the same naming convention, grouping adjacent small sections together to stay within ~8K token target.

### 4 Arbitrary-Chunked Literature/ Subdirectories

These all have chunks at correct size (~4K tokens each). They only need renaming.

#### burgess_1984 (7 chunks, page-based naming)
Current filenames: `sec01_page-1.md` through `sec07_page-45.md`
Semantic content per index.json:
- sec01: §24-25 Frame Axiomatics, Goldblatt-Thomason → `sec01_frame-axiomatics.md`
- sec02: Bibliography (pp. 86-88) → `sec02_bibliography.md`
- sec03: §0 Introduction: Correspondence and Motivation → `sec03_introduction.md`
- sec04: §1 Completeness for Basic Tense Logic: Chronicles → `sec04_completeness-chronicles.md`
- sec05: §2 Completeness for Discrete and Dedekind-Complete Time → `sec05_completeness-discrete.md`
- sec06: §3 Decidability via Standard Translation → `sec06_decidability.md`
- sec07: §4 Expressive Completeness and Kamp's Theorem → `sec07_expressive-completeness.md`

#### doets_1989 (3 chunks, part-based naming)
Current: `sec01_part-1.md`, `sec02_part-2.md`, `sec03_part-3.md`
Semantic content per index.json:
- sec01: Part 1: Introduction and Scattered Orderings → `sec01_introduction-scattered.md`
- sec02: Part 2: Well-Orderings and Complete Orderings → `sec02_well-orderings.md`
- sec03: Part 3: Well-Founded Trees and Substitution Lemmas → `sec03_well-founded-trees.md`

#### reynolds_1994 (3 chunks, part-based naming)
Current: `sec01_part-1.md`, `sec02_part-2.md`, `sec03_part-3.md`
Semantic content per index.json:
- sec01: §1-6. Introduction through Expressive Completeness → `sec01_introduction-expressive.md`
- sec02: §7. No Gaps between Equivalence Classes → `sec02_no-gaps.md`
- sec03: §8. Using Contemporaneity on the Integers → `sec03_contemporaneity.md`

#### doets_1987 (minor — sec02, sec03 have opaque names)
Current: `sec01` has topic, `sec02` is `69-lemma`, `sec03` is `15-logic`
Low priority; these appear to be page artifact names. Check content to determine proper names.

### 5 Oversized cslib Subdirectories

#### chagrov_1997 (total: 1.38MB, ~345K tokens)
5 content chunks, all massively oversized (65K–88K tokens each):
- **Heading pattern**: Numbered sections like `7.1\tAlgebraic preliminaries` (tab-delimited)
- **Structure**: 10+ subsections per part
- p01_introduction.md: Chapters 1-4 (Introduction, Classical Logic, Intuitionistic Logic, Modal Logics)
- p02_kripke-semantics.md: Chapters 5-6 (Kripke Semantics, Normal Modal Logics)
- p03_adequate-semantics.md: Chapters 7-8 (Algebraic Semantics, Adequate Semantics), detected sections: §7.1-7.10, §8.1-8.9
- p04_properties-of-logics.md: Chapters 9-10 (Adequate Semantics continued, Properties)
- p05_algorithmic-problems.md: Chapter 11 (Algorithmic Problems)
- **Target**: ~15 chunks per part → 75 total chunks for chagrov

#### church_1956 (total: 1.07MB, ~267K tokens)
6 content chunks, all oversized (32K–57K tokens each):
- **Structure**: Numbered sections within chapters
- ch00b_introduction.md: 229K bytes (~57K tokens) — largest
- Each chapter chapter has numbered sections (e.g., §1, §2, ... §39 in introduction)
- **Target**: ~5-10 chunks per chapter → 30-50 total chunks for church

#### hughes_1996 (total: 837K bytes, ~209K tokens)
4 content chunks, all oversized (54K–91K tokens each):
- **Structure**: Chapters with numbered sections
- p01-p03 each at 54K-91K tokens
- **Target**: ~10-15 chunks per part → 30-45 total chunks for hughes

#### mendelson_2016 (total: 1.08MB, ~270K tokens)
6 content chunks, most oversized (up to 89K tokens):
- **Heading pattern**: `N.N <Title>` (em-space after section number)
- ch02_first-order-logic.md: 63K tokens, sections 2.1-2.16 at lines 7, 1335, 4154... → 16 subsections
- ch05_computability.md: 89K tokens (worst)
- **Detected sections in ch02**: 2.1 Quantifiers, 2.2 First-Order Languages, 2.3 First-Order Theories, 2.4 Properties, 2.5 Additional Metatheorems, 2.6 Rule C, 2.7 Completeness, 2.8 First-Order Theories with Equality, 2.9 Definitions of New Function Letters, 2.10 Prenex Normal Forms, 2.11 Isomorphism, 2.12 Generalized First-Order Theories, 2.13 Elementary Equivalence, 2.14 Ultrapowers, 2.15 Semantic Trees, 2.16 Quantification Theory Allowing Empty Domains
- **Target**: ~3-5 subsections per file → 40-60 total chunks for mendelson

#### zakharyaschev_2001 (total: 432K bytes, ~108K tokens)
4 chunks, 2 oversized:
- sec01_unimodal-logics.md: 168K bytes (~42K tokens)
- sec03_superintuitionistic-logics.md: 181K bytes (~45K tokens)
- **Structure**: Subsections within each section
- **Target**: 4-6 chunks per oversized section → 12-16 total chunks for zakharyaschev

### Index.json Schema Analysis

The index.json uses schema version 2 with these relevant fields per entry:

```json
{
  "id": "blackburn_2002_ch01_sec01-02",
  "path": "blackburn_2002/ch01_relational-structures.md",
  "title": "Chapter 1: §1.1 Relational Structures, §1.2 Modal Languages",
  "authors": "Patrick Blackburn, Maarten de Rijke, Yde Venema",
  "bib_key": "BlackburnDeRijkeVenema2002",
  "year": 2002,
  "doc_type": "chapter",
  "source_format": "pdf",
  "token_count": 6500,
  "keywords": [...],
  "summary": "...",
  "parent_doc": "blackburn_2002",
  "page_range": "1-28",
  "zotero_key": "BlackburnDeRijkeVenema2002",
  "zotero_path": null,
  "project_tags": ["BimodalLogic"]
}
```

**Fields that must update for re-chunked entries**:
- `id`: New unique ID based on subdirectory + section
- `path`: New path within subdirectory
- `title`: Semantic title reflecting actual sections covered
- `token_count`: Recalculated from actual file size
- `doc_type`: Change from "paper" to "chapter" for subdirectory entries
- `parent_doc`: Set to the parent book entry id (e.g., "blackburn_2002")
- `page_range`: The page range covered by this chunk (from source page markers)

**Fields that can be inherited from parent entry**: `authors`, `bib_key`, `year`, `source_format`, `zotero_key`, `zotero_path`, `project_tags`

**When removing flat file entry**: Keep the entry but update its `path` to the subdirectory path (or remove and replace with parent + chapter entries). The flat file entry for blackburn_2002 should be replaced by a parent book entry plus individual chapter entries, following the blackburn_2001 pattern.

### Semantic Boundary Detection Strategy

The key insight is that these files use **non-markdown structural markers** that require document-specific parsing:

| Document | Heading Pattern | Detection Method |
|----------|----------------|-----------------|
| Blackburn 2002 | `N Basic Concepts` / `N.N Title` | Regex on bare lines after page 22 |
| Chagrov 1997 | `N.N\tTitle` (tab-delimited) | Tab character after section number |
| Church 1956 | Section numbers in prose | Manual inspection + numbered `§N.` patterns |
| Hughes 1996 | Similar to chagrov | Part headers + numbered sections |
| Mendelson 2016 | `N.N Title` (em-space) | Unicode em-space ` ` after section number |
| Zakharyaschev 2001 | Similar numbered sections | Subsection markers within sec01/sec03 |
| burgess_1984 | Already chunked semantically | Only needs file rename |
| doets_1989 | Already chunked semantically | Only needs file rename |
| reynolds_1994 | Already chunked semantically | Only needs file rename |

**Recommended file-splitting approach** (not literature-chunk.sh):
1. Use Python to scan the source file line by line
2. Detect heading boundaries using document-specific patterns
3. Accumulate content between boundaries, tracking token count (~bytes/4)
4. When a boundary is hit: if current chunk >2K tokens, start new file; if <2K, merge with next
5. Write named files using semantic headings as filenames
6. Track page ranges from `## Page N` markers encountered in content

### Duplicate Flat Files to Remove

The following flat files in `~/Projects/Literature/` should be removed after subdirectory chunks exist:

| Flat File | Subdirectory Equivalent |
|-----------|------------------------|
| Blackburn_deRijke_Venema_2002_Modal_Logic.md | (to create: blackburn_2002/) |
| Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md | caleiro_2013/ |
| deRijke_Venema_1995_Sahlqvist_BAOs.md | derijke_1995/ |
| Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md | gabbay_1993/ |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md | gabbay_1994/ |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md | gabbay_1994/ |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md | gabbay_1994/ |
| Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md | goldblatt_2003/ |
| Reynolds_2001_Axiomatization_Full_CTL_star.md | reynolds_2001/ |
| Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md | venema_1991/ |
| Venema_1991_Many_Dimensional_Modal_Logics_ch2.md | venema_1991/ |
| Venema_1993_Derivation_Rules_Anti_Axioms.md | venema_1993/ |
| Venema_1993_Since_and_Until.md | venema_1993_since/ |

Before removing, verify index.json entries exist for all subdirectory chunks.

---

## Summary Statistics

### Work Required by Category

| Category | Documents | Effort |
|----------|-----------|--------|
| Create from scratch (flat → subdir) | 1 (Blackburn 2002, ~33 files) | High |
| Re-chunk at finer granularity (cslib) | 5 books (~200 new chunks) | Very High |
| Rename files (keep content) | 3 subdirs (13 files renamed) | Low |
| Remove flat file duplicates | 13 flat files | Low |
| Update index.json entries | ~250 entries | Medium |

### Total Estimated New Chunks

| Document | Current Chunks | Target Chunks |
|----------|---------------|--------------|
| blackburn_2002 | 1 (flat) | ~33 |
| chagrov_1997 | 5 | ~75 |
| church_1956 | 7 | ~40 |
| hughes_1996 | 4 | ~40 |
| mendelson_2016 | 6 | ~50 |
| zakharyaschev_2001 | 4 | ~15 |
| burgess_1984 | 7 (renamed) | 7 (same) |
| doets_1989 | 3 (renamed) | 3 (same) |
| reynolds_1994 | 3 (renamed) | 3 (same) |

---

## Decisions

- **Do not use literature-chunk.sh** for re-chunking. It splits at `## Page N` markers which are OCR artifacts, not semantic boundaries. Manual Python splitting at prose-embedded headings is required.
- **blackburn_2002/** should follow the `blackburn_2001/` naming pattern exactly (same chapter structure, same `ch{N}_{topic}.md` format).
- **File renames for burgess_1984/doets_1989/reynolds_1994** are low-effort and do not require content changes — only filename changes + index.json path updates.
- **cslib textbooks** require the most work (5 large books) and represent a full day's implementation effort if done carefully.
- **Index.json entries for removed flat files** should be replaced by a parent book entry (`doc_type: "book"`) plus individual chapter entries (`doc_type: "chapter"`), matching the established pattern.
- **Priority order**: (1) blackburn_2002/ creation, (2) file renames, (3) cslib re-chunking.

---

## Risks & Mitigations

- **Missing sections in Blackburn 2002 regex**: The detection script missed sections 2.5, 2.6, 3.1-3.3, 3.5, 4.6, 4.7, 5.3, 6.1, 6.4, 6.6, 7.5-7.7. These need a broader detection pass or manual inspection. Use blackburn_2001 structure as ground truth — it defines the complete section list.
- **cslib control characters**: The chagrov_1997 and mendelson_2016 files contain `\x0c` (form feed) and `\x1f` (unit separator) characters from PDF conversion. Python reading with `errors='replace'` handles this, but the control characters may interfere with heading detection; strip them before matching.
- **Index.json consistency**: Both `~/Projects/Literature/index.json` and `~/Projects/cslib/specs/literature/*/index.json` need updating. The cslib subdirectories have their own `index.json` per book. Changes to Literature/ index.json must also be reflected in any project-specific index that references these entries.
- **Chunk size variance**: Some sections in these mathematical texts are very short (1-2 pages) and some are very long (10+ pages). Group adjacent short sections to stay within 5-10K token target; split long sections at natural paragraph boundaries.
- **Deduplication**: blackburn_2001/ (Literature/) and blackburn_2001/ (cslib/) are identical. Do not create blackburn_2002/ in cslib — only in Literature/. cslib agents should reference Literature/ via the LITERATURE_DIR env var.

## Context Extension Recommendations

- None: this is a domain-specific task audit with no gaps in agent system context.

---

## Appendix

### Key File Paths

| Path | Description |
|------|-------------|
| `/home/benjamin/Projects/Literature/` | Primary literature store |
| `/home/benjamin/Projects/Literature/index.json` | Central index (v2 schema) |
| `/home/benjamin/Projects/Literature/Blackburn_deRijke_Venema_2002_Modal_Logic.md` | 365K token flat file (priority 1) |
| `/home/benjamin/Projects/Literature/blackburn_2001/` | Reference template (33 chunks) |
| `/home/benjamin/Projects/cslib/specs/literature/` | cslib literature store |
| `/home/benjamin/.config/nvim/.claude/scripts/literature-chunk.sh` | Existing chunking script (not applicable here) |

### Blackburn 2002 Chapter Map (from TOC on pages 6-8)

| Chapter | Title | Pages | Sections |
|---------|-------|-------|---------|
| 1 | Basic Concepts | 1-49 | §1.1-1.8 |
| 2 | Models | 50-123 | §2.1-2.8 |
| 3 | Frames | 124-189 | §3.1-3.9 |
| 4 | Completeness | 190-263 | §4.1-4.10 |
| 5 | Algebras and General Frames | 263-333 | §5.1-5.7 |
| 6 | Computability and Complexity | 334-412 | §6.1-6.7 |
| 7 | Extended Modal Logic | 413-487 | §7.1-7.7 |
| App A | A Logical Toolkit | 488-499 | – |
| App B | An Algebraic Toolkit | 500-506 | – |
| App C | A Computational Toolkit | 507-518 | – |
| App D | A Guide to the Literature | 519-526 | – |

### Implementation Script Outline

```python
# For Blackburn 2002 semantic splitting:
import re

def detect_section_boundaries(filepath):
    with open(filepath, encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    
    boundaries = []
    current_page = 0
    in_main_content = False
    
    section_pat = re.compile(r'^(\d+)\.(\d+)\s+([A-Z][A-Za-z ,\-]+)$')
    chapter_pat = re.compile(r'^(\d+)\s+(Basic Concepts|Models|Frames|Completeness|Algebras|Computability|Extended Modal Logic)$')
    page_pat = re.compile(r'^## Page (\d+)$')
    
    for i, line in enumerate(lines):
        line = line.rstrip()
        pm = page_pat.match(line)
        if pm:
            current_page = int(pm.group(1))
            if current_page >= 22:  # Chapter 1 starts at page 22
                in_main_content = True
        
        if not in_main_content:
            continue
        
        if chapter_pat.match(line) or section_pat.match(line):
            boundaries.append((i, current_page, line.strip()))
    
    return boundaries
```

### Chagrov 1997 Section Detection

```python
# For Chagrov 1997 section detection:
import re

def detect_chagrov_sections(filepath):
    with open(filepath, encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    
    boundaries = []
    section_pat = re.compile(r'^(\d+\.\d+)\s+([A-Z][A-Za-z ,\-]+)$')
    
    for i, line in enumerate(lines):
        # Strip control characters
        clean = re.sub(r'[\x00-\x1f\x7f]', ' ', line).strip()
        m = section_pat.match(clean)
        if m:
            boundaries.append((i, m.group(1), m.group(2)))
    
    return boundaries
```

### Search Commands Used

```bash
find /home/benjamin/Projects/Literature -maxdepth 1 -name "*.md" -exec wc -c {} \;
ls /home/benjamin/Projects/Literature/blackburn_2001/
wc -c /home/benjamin/Projects/cslib/specs/literature/chagrov_1997/*.md
head -200 /home/benjamin/Projects/Literature/Blackburn_deRijke_Venema_2002_Modal_Logic.md
awk '/^## /{print NR, $0}' Blackburn_deRijke_Venema_2002_Modal_Logic.md
grep -n "^[0-9]\+\." mendelson_2016/ch02_first-order-logic.md
```
