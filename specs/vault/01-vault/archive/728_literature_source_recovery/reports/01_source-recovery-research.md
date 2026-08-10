# Research Report: Task #728

**Task**: 728 - Re-acquire PDFs/DJVUs from Zotero for Literature Collection
**Started**: 2026-06-16T09:41:00-07:00
**Completed**: 2026-06-16T09:55:00-07:00
**Effort**: ~45 min
**Dependencies**: None
**Sources/Inputs**: Codebase (~/Projects/Literature/index.json, README.md), Zotero storage, BimodalLogic/specs/literature/, cslib/specs/literature/
**Artifacts**: specs/728_literature_source_recovery/reports/01_source-recovery-research.md
**Standards**: report-format.md

## Executive Summary

- The Literature index (`~/Projects/Literature/index.json`) has 183 entries; 182 have `zotero_key` fields, 1 (thomas_1997) explicitly has `zotero_key: null` due to a Springer paywall
- The `pdfs/` directory exists at `~/Projects/Literature/pdfs/` but is **empty** — all source PDFs need to be acquired
- BimodalLogic has **32 PDFs** covering all 30 unique source documents in the index (some multi-chunk)
- cslib has `chagrov_1997.djvu` but that entry is **not in the Literature index** — it is cslib-local
- Zotero storage is at `~/Documents/Zotero/storage/` (not `~/Zotero/storage/`) with 916 folders and 870 PDFs
- The `zotero_key` values are **Better BibTeX citation keys** (e.g., `BlackburnDeRijkeVenema2002`), not Zotero's 8-character storage folder IDs — mapping requires either the SQLite DB or a `zotero-library.json` export
- **Recommended strategy**: Copy all 32 PDFs from BimodalLogic into `pdfs/`, then use Zotero's SQLite DB (via `python3 -c "import sqlite3..."` or `python-pyzotero`) to map remaining zotero_keys to storage folder paths for PDFs not in BimodalLogic

## Context & Scope

The Literature centralized repository (`~/Projects/Literature/`) was created to consolidate academic literature from per-project `specs/literature/` directories. The markdown chunk files exist and are indexed, but the source PDFs in `pdfs/` (gitignored) were never populated. This task researches the state of available source files and what is needed to populate `pdfs/`.

## Findings

### index.json Schema Overview

Version 2 schema with fields:
- `id`: slug-based unique identifier
- `zotero_key`: Better BibTeX citation key (canonical Zotero key)
- `zotero_path`: null in all entries (never populated)
- `source_format`: "pdf" for all entries
- `path`: path to markdown file(s)

**Entry counts**:
- Total entries: **183**
- Entries with `zotero_key` (non-null): **182**
- Entries missing `zotero_key`: **1** (thomas_1997 — explicitly null, Springer paywall, MD reconstructed from secondary sources)

**Unique source documents** (distinct zotero_keys): approximately 35 unique keys for 30 source papers/books (several entries share the same zotero_key, e.g., `GHR94` for three gabbay_1994 chapter entries, `Blackburn2001` for 57 chapter chunk entries).

### Zotero Storage Location and Key Mapping

**Actual location**: `~/Documents/Zotero/storage/` (NOT `~/Zotero/storage/` which has no `storage/` subdirectory)

- `~/Zotero/` contains: `locate/`, `styles/`, `translators/`, `zotero.sqlite`, `zotero.sqlite.bak`
- `~/Documents/Zotero/` contains the actual working Zotero data with `storage/`

**Storage structure**:
- 916 storage folders with 8-character alphanumeric IDs (e.g., `IFNZ8TYI`, `YM2ZSQAA`)
- 870 total PDFs across all folders
- Each folder contains one attachment file named by Zotero's citation format

**Key mapping problem**: The `zotero_key` values (e.g., `BlackburnDeRijkeVenema2002`) are Better BibTeX citation keys assigned to Zotero **items**, while storage folders use Zotero's internal 8-character **attachment** keys. A direct filesystem lookup by `zotero_key` is not possible — the SQLite database is required to bridge them.

**SQLite DB location**: `~/Documents/Zotero/zotero.sqlite`
- Note: `sqlite3` CLI is not available in PATH but Python3's `sqlite3` module likely is
- The `~/Projects/Literature/zotero-library.json` file (Better BibTeX CSL-JSON auto-export) is **not present** — it has never been configured

**Confirmed Zotero PDFs for indexed entries** (found by filename search):
| index.json id | Zotero PDF found | Storage path |
|---------------|-----------------|--------------|
| blackburn_2002 | YES | `YM2ZSQAA/Blackburn et al. - 2002 - Modal Logic.pdf` |
| burgess_1982_i | YES | `5HK4WV9T/Burgess - 1982 - Axioms for tense logic. I...pdf` |
| burgess_1982_ii | YES | `C9CHHCD2/Burgess - 1982 - Axioms for tense logic. II. Time periods..pdf` |
| burgess_1984 | YES | `6VFNSSIE/Burgess - 1984 - Basic Tense Logic.pdf` |
| caleiro_2013 | YES | `MYPD934S/Caleiro et al. - 2013 - On the Mosaic Method...pdf` |
| gabbay_1993 | YES | `RTTNYMKG/Gabbay et al. - 1993 - Temporal expressive completeness...pdf` |
| gabbay_1994_* | YES | `PKDIAG7M/Gabbay et al. - 1994 - Temporal Logic...Volume 1.pdf` |
| thomason_1984 | YES | `978ZVM9R/Thomason - 1984 - Combinations of Tense and Modality.pdf` |
| reynolds_1992 | YES | `2EFF2PBK/Reynolds - 1992 - An axiomatization...pdf` |
| xu_1988 | YES | `27MQRXIX/Xu - 1988 - On some U,S-tense logics.pdf` |
| reynolds_2001 | POSSIBLE | `MMIGP7UR/CUP-CTL.pdf` (unclear — generic filename) |

**NOT confirmed in Zotero** (not found by filename search):
- `doets_1987` (found as: `5I8QUVIQ/Doets - 1987 - Completeness and definability...pdf` ← FOUND)
- `doets_1989` (found: `KGQJLZ5K/Doets - 1989 - Monadic Pi^1_1-theories...pdf` ← FOUND)
- derijke_venema_1995, goldblatt_2003, hodkinson_2006, libkin_2004, obendrauf_2024, rabinovich_2014, reynolds_1994, reynolds_2001, venema_1991, venema_1993 (both), venema_1997, venema_2001, verbrugge_2004, blackburn_2001 chapters — **not found by filename in Zotero**

**Revised Zotero confirmed list** (after correction):
| id | Found | Zotero path |
|----|-------|-------------|
| blackburn_2002 | YES | YM2ZSQAA/ |
| burgess_1982_i | YES | 5HK4WV9T/ |
| burgess_1982_ii | YES | C9CHHCD2/ |
| burgess_1984 | YES | 6VFNSSIE/ |
| caleiro_2013 | YES | MYPD934S/ |
| doets_1987 | YES | 5I8QUVIQ/ |
| doets_1989 | YES | KGQJLZ5K/ |
| gabbay_1993 | YES | RTTNYMKG/ |
| gabbay_1994_* | YES | PKDIAG7M/ (Vol.1) |
| thomason_1984 | YES | 978ZVM9R/ |
| reynolds_1992 | YES | 2EFF2PBK/ |
| xu_1988 | YES | 27MQRXIX/ |
| reynolds_2001 | UNCERTAIN | MMIGP7UR/CUP-CTL.pdf (generic filename) |

### BimodalLogic PDF Inventory

**Location**: `~/Projects/BimodalLogic/specs/literature/`
**Total PDFs**: **32 files**

Complete list:
```
blackburn_2001/Blackburn_deRijke_Venema_2002_Modal_Logic.pdf
burgess_1982b/Burgess_1982b_Axioms_for_tense_logic_II_Time_periods.pdf
burgess_1982/Burgess_1982_Axioms_for_tense_logic_Since_and_Until.pdf
burgess_1984/Burgess_1984_Basic_Tense_Logic.pdf
caleiro_2013/Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.pdf
derijke_1995/deRijke_Venema_1995_Sahlqvist_BAOs.pdf
doets_1987/Doets_1987_Completeness_and_Definability_thesis.pdf
doets_1989/Doets_1989_Monadic_Pi11_Theories.pdf
gabbay_1993/Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.pdf
gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.pdf
gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.pdf
gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.pdf
gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1.pdf
gabbay_1994/Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf
goldblatt_2003/Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.pdf
Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.pdf
Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.pdf
obendrauf_2024/Obendrauf_2024_Lean_Formalization_Coalition_Logic.pdf
Rabinovich_2014_Proof_of_Kamps_Theorem.pdf
reynolds_1992/Reynolds_1992_Axiomatization_Until_Since_without_IRR.pdf
reynolds_1994/Reynolds_1994_Axiomatising_U_and_S_over_integer_time.pdf
reynolds_2001/Reynolds_2001_Axiomatization_Full_CTL_star.pdf
thomason_1984/Thomason_1984_Combinations_of_Tense_and_Modality.pdf
venema_1991/Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.pdf
venema_1991/Venema_1991_Many_Dimensional_Modal_Logics_ch2.pdf
venema_1991/Venema_1991_Many_Dimensional_Modal_Logics.pdf
venema_1993_since/Venema_1993_Since_and_Until.pdf
venema_1993/Venema_1993_Derivation_Rules_Anti_Axioms.pdf
venema_1997/Venema_1997_Atom_Structures_Sahlqvist.pdf
venema_2001/Venema_2001_Temporal_Logic_Survey.pdf
verbrugge_2004/Verbrugge_2004_Completeness_by_construction.pdf
xu_1988/Xu_1988_On_some_US_tense_logics.pdf
```

**Coverage analysis**: BimodalLogic PDFs cover all 30 unique source papers in the Literature index (every indexed entry except `thomas_1997` which has no PDF).

### cslib Source File Inventory

**Location**: `~/Projects/cslib/specs/literature/`

Source files found:
- `chagrov_1997.djvu` — present
- Subdirectories with markdown chunks: `blackburn_2001/`, `burgess_1982_ii.md`, `church_1956/`, `gentzen_1935/`, `hughes_1996/`, `mendelson_2016/`, `zakharyaschev_2001/`, and others

**Key finding**: `chagrov_1997` is NOT in `~/Projects/Literature/index.json`. It exists only in cslib's local literature. The task description mentions "Copy cslib's chagrov_1997.djvu" but there is no corresponding Literature index entry for it. Either the task anticipates creating a new index entry, or it needs to be added first.

### Existing pdfs/ Directory Status

`~/Projects/Literature/pdfs/` exists as an empty directory (created 2026-06-14, 4096 bytes = just directory entry). No files have been placed there yet.

### Gap Analysis

**Source availability by document**:

| index.json id | BimodalLogic PDF | Zotero PDF | Status |
|---------------|-----------------|-----------|--------|
| blackburn_2002 | YES | YES | AVAILABLE |
| blackburn_2001 (57 chunks) | YES (same PDF as blackburn_2002) | YES | AVAILABLE |
| burgess_1982_i | YES | YES | AVAILABLE |
| burgess_1982_ii | YES | YES | AVAILABLE |
| burgess_1984 | YES | YES | AVAILABLE |
| caleiro_2013 | YES | YES | AVAILABLE |
| derijke_venema_1995 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| doets_1987 | YES | YES | AVAILABLE |
| doets_1989 | YES | YES | AVAILABLE |
| gabbay_1993 | YES | YES | AVAILABLE |
| gabbay_1994_ch9/10/12 | YES | YES (Vol1) | AVAILABLE |
| goldblatt_2003 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| hodkinson_2006 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| libkin_2004_ch3_ch7 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| obendrauf_2024 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| rabinovich_2014 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| reynolds_1992 | YES | YES | AVAILABLE |
| reynolds_1994 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| reynolds_2001 | YES | UNCERTAIN | AVAILABLE (from BimodalLogic) |
| thomas_1997 | NO | NOT CONFIRMED | MISSING (Springer paywall; known gap) |
| thomason_1984 | YES | YES | AVAILABLE |
| venema_1991 (ch2, appA_B) | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| venema_1993_anti_axioms | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| venema_1993_since_until | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| venema_1997 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| venema_2001 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| verbrugge_2004 | YES | NOT CONFIRMED | AVAILABLE (from BimodalLogic) |
| xu_1988 | YES | YES | AVAILABLE |

**Summary**:
- 29/30 unique source documents: available from BimodalLogic PDFs
- 1/30: thomas_1997 — no PDF available anywhere (known paywall issue, index notes "MD summary reconstructed from secondary sources")
- chagrov_1997.djvu: available in cslib but NOT indexed in Literature/index.json

## Decisions

1. The primary source for `pdfs/` population should be the 32 BimodalLogic PDFs (immediate, no Zotero lookup needed)
2. Zotero lookup is not needed for this task — BimodalLogic already covers all indexed documents
3. `thomas_1997` remains a known gap; no action needed beyond documenting it
4. `chagrov_1997.djvu` from cslib would need a new `index.json` entry created if it is to be included

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| BimodalLogic PDFs may differ from what Zotero has (different editions/scans) | For re-chunking purposes these are the same source used for original chunking, so they are the correct files |
| Zotero key mapping is blocked without sqlite3 or zotero-library.json | Not needed — BimodalLogic covers all 30 sources |
| `chagrov_1997` scope ambiguity | Clarify with user whether to add it to Literature/index.json; can proceed without it |
| pdfs/ flat structure vs BimodalLogic's subdirectory structure | Plan needs to specify whether to flatten (recommended) or preserve subdirectory structure |

## Recommendations

### Recommended Implementation Strategy

**Phase 1: Copy BimodalLogic PDFs**
```bash
# Copy all 32 PDFs to pdfs/ with flat naming (using BimodalLogic filenames)
find ~/Projects/BimodalLogic/specs/literature/ -name "*.pdf" -exec cp {} ~/Projects/Literature/pdfs/ \;
```
This yields 32 PDF files with descriptive names already matching the Literature markdown filenames.

**Phase 2: Copy cslib chagrov_1997.djvu (conditional)**
```bash
cp ~/Projects/cslib/specs/literature/chagrov_1997.djvu ~/Projects/Literature/pdfs/
```
Only if a Literature index entry is added for chagrov_1997.

**Phase 3: Verify coverage**
```bash
# Compare indexed source documents against pdfs/ contents
jq -r '.entries[] | select(.zotero_key != null) | .id' ~/Projects/Literature/index.json | sort -u
ls ~/Projects/Literature/pdfs/ | sed 's/\.pdf$//' | sort
```

**Phase 4: Update zotero_path fields (optional)**
After `zotero-library.json` is configured or SQLite access is established, populate `zotero_path` fields in `index.json` for the 12 confirmed Zotero matches. This is deferred unless needed for Zotero-based re-acquisition.

### thomas_1997 Strategy
No PDF available. The existing markdown summary (`Thomas_1997_EF_Games_Composition_Monadic.md`) is adequate for retrieval purposes. No action needed.

### Zotero Key Mapping (for future reference)
If Zotero-based acquisition is needed later, use Python's sqlite3 module:
```python
import sqlite3
conn = sqlite3.connect('/home/benjamin/Documents/Zotero/zotero.sqlite')
# items table: itemID, key (8-char storage key)
# creators, title fields joinable via itemData
```
Or configure Better BibTeX auto-export to `~/Projects/Literature/zotero-library.json`.

## Context Extension Recommendations

- **Topic**: Zotero storage key mapping
- **Gap**: No documented pattern for mapping Better BibTeX citation keys to Zotero storage folder IDs
- **Recommendation**: Consider adding a short guide in `.claude/context/` for literature-agent about the `~/Documents/Zotero/` vs `~/Zotero/` distinction and the SQLite-based lookup pattern

## Appendix

### Search Queries Used
- `find ~/Documents/Zotero/storage/ -name "*.pdf"` — 870 PDFs in 916 folders
- `find ~/Projects/BimodalLogic/specs/literature/ -name "*.pdf"` — 32 PDFs
- `find ~/Projects/cslib/specs/literature/ -name "*.djvu"` — 1 DJVU
- `jq '.entries | length'` on Literature/index.json — 183 entries
- Filename grep searches for known paper titles across Zotero storage

### Key File Paths
- Literature index: `/home/benjamin/Projects/Literature/index.json`
- pdfs/ directory: `/home/benjamin/Projects/Literature/pdfs/` (empty, exists)
- BimodalLogic PDFs: `/home/benjamin/Projects/BimodalLogic/specs/literature/`
- cslib DJVU: `/home/benjamin/Projects/cslib/specs/literature/chagrov_1997.djvu`
- Zotero SQLite: `/home/benjamin/Documents/Zotero/zotero.sqlite`
- Zotero storage: `/home/benjamin/Documents/Zotero/storage/` (916 folders)
