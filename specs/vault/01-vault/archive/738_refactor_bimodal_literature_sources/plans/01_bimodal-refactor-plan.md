# Implementation Plan: Refactor BimodalLogic specs/literature/ to sources/ structure

- **Task**: 738 - Refactor BimodalLogic specs/literature/ to sources/ structure and remove blackburn_2001
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/738_refactor_bimodal_literature_sources/reports/ (filesystem survey)
- **Artifacts**: plans/01_bimodal-refactor-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Restructure `~/Projects/BimodalLogic/specs/literature/` to use a `sources/` subdirectory matching the centralized Literature/ repository convention. This involves: (1) creating `sources/` and moving 22 existing subdirectories into it, (2) creating 5 new `sources/{id}/` directories for loose files without existing directories, (3) moving 30 loose markdown files into their corresponding `sources/{id}/` directories, (4) co-locating 3 loose PDFs with their markdown counterparts, (5) removing `blackburn_2001/` entirely, (6) updating `index.json` paths with `sources/` prefix, and (7) updating `.gitignore` PDF patterns.

### Research Integration

Filesystem survey confirmed: 23 subdirectories (including blackburn_2001 to remove), 30 loose markdown files, 3 loose PDFs, root index.json with 30 entries (none referencing blackburn_2001), and blackburn_2001 has its own sub-index.json with 33 chapter entries.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- All source content lives under `specs/literature/sources/{id}/`
- Each source directory contains its markdown file(s), chunk files, and PDF
- Root `index.json` paths updated to `sources/{id}/{filename}`
- `blackburn_2001/` completely removed
- `.gitignore` covers `sources/**/*.pdf` pattern
- `README.md` and `DEPRECATED.md` remain at `specs/literature/` root

**Non-Goals**:
- Modifying content of any markdown or chunk files
- Changing index.json entry IDs, metadata, or structure beyond path prefix
- Updating any code that references literature paths (outside this directory)
- Restructuring blackburn_2001 content into blackburn_2002 (separate concern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Git treats moves as delete+add for large files | L | M | Use `git mv` for tracked files to preserve history |
| Broken cross-references in README.md | M | L | Grep README.md for path references and update |
| PDFs not tracked by git (gitignored) | L | H | Use plain `mv` for PDFs; update .gitignore pattern |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create sources/ directory and move existing subdirectories [COMPLETED]

**Goal**: Create `sources/` and relocate all 22 existing subdirectories (excluding blackburn_2001) into it.

**Tasks**:
- [ ] Create `specs/literature/sources/` directory
- [ ] Move 22 existing subdirectories into `sources/` using `git mv`
- [ ] Remove `blackburn_2001/` entirely using `rm -rf`
- [ ] Create 5 new directories for sources that only have loose files

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `specs/literature/sources/` - create directory
- Move these 22 directories into `sources/`:
  - `burgess_1982`, `burgess_1982b`, `burgess_1984`
  - `caleiro_2013`, `derijke_1995`
  - `doets_1987`, `doets_1989`
  - `gabbay_1993`, `gabbay_1994`
  - `goldblatt_2003`
  - `obendrauf_2024`
  - `reynolds_1992`, `reynolds_1994`, `reynolds_2001`
  - `thomason_1984`
  - `venema_1991`, `venema_1993`, `venema_1993_since`, `venema_1997`, `venema_2001`
  - `verbrugge_2004`, `xu_1988`
- Delete: `blackburn_2001/`
- Create new empty directories:
  - `sources/blackburn_2002/`
  - `sources/hodkinson_2006/`
  - `sources/libkin_2004_ch3_ch7/`
  - `sources/rabinovich_2014/`
  - `sources/thomas_1997/`

**Shell commands**:
```bash
cd ~/Projects/BimodalLogic/specs/literature

# Create sources directory
mkdir -p sources

# Move 22 existing subdirectories (git mv for tracked files)
for dir in burgess_1982 burgess_1982b burgess_1984 caleiro_2013 derijke_1995 \
           doets_1987 doets_1989 gabbay_1993 gabbay_1994 goldblatt_2003 \
           obendrauf_2024 reynolds_1992 reynolds_1994 reynolds_2001 \
           thomason_1984 venema_1991 venema_1993 venema_1993_since \
           venema_1997 venema_2001 verbrugge_2004 xu_1988; do
  git mv "$dir" "sources/$dir"
done

# Remove blackburn_2001 entirely
rm -rf blackburn_2001

# Create 5 new directories for sources without existing dirs
mkdir -p sources/blackburn_2002
mkdir -p sources/hodkinson_2006
mkdir -p sources/libkin_2004_ch3_ch7
mkdir -p sources/rabinovich_2014
mkdir -p sources/thomas_1997
```

**Verification**:
- `ls sources/` shows 27 directories (22 moved + 5 new)
- `ls -d blackburn_2001` fails (deleted)
- No directories remain at root level except `sources/`

---

### Phase 2: Move loose markdown files and PDFs into source directories [COMPLETED]

**Goal**: Relocate all 30 loose markdown files and 3 loose PDFs into their corresponding `sources/{id}/` directories.

**Tasks**:
- [ ] Move 25 markdown files into existing (now relocated) source directories
- [ ] Move 5 markdown files into newly created source directories
- [ ] Move 3 loose PDFs into their corresponding source directories
- [ ] Leave `README.md` and `DEPRECATED.md` at root

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- 30 loose markdown files moved to `sources/{id}/`
- 3 loose PDFs moved to `sources/{id}/`

**Shell commands**:
```bash
cd ~/Projects/BimodalLogic/specs/literature

# Files going into EXISTING source directories (git mv for tracked .md)
git mv Burgess_1982_Axioms_for_tense_logic_Since_and_Until.md sources/burgess_1982/
git mv Burgess_1982b_Axioms_for_tense_logic_II_Time_periods.md sources/burgess_1982b/
git mv Burgess_1984_Basic_Tense_Logic.md sources/burgess_1984/
git mv Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md sources/caleiro_2013/
git mv deRijke_Venema_1995_Sahlqvist_BAOs.md sources/derijke_1995/
git mv Doets_1987_Completeness_and_Definability_thesis.md sources/doets_1987/
git mv Doets_1989_Monadic_Pi11_Theories.md sources/doets_1989/
git mv Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md sources/gabbay_1993/
git mv Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md sources/gabbay_1994/
git mv Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md sources/gabbay_1994/
git mv Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md sources/gabbay_1994/
git mv Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md sources/goldblatt_2003/
git mv Obendrauf_2024_Lean_Formalization_Coalition_Logic.md sources/obendrauf_2024/
git mv Reynolds_1992_Axiomatization_Until_Since_without_IRR.md sources/reynolds_1992/
git mv Reynolds_1994_Axiomatising_U_and_S_over_integer_time.md sources/reynolds_1994/
git mv Reynolds_2001_Axiomatization_Full_CTL_star.md sources/reynolds_2001/
git mv Thomason_1984_Combinations_of_Tense_and_Modality.md sources/thomason_1984/
git mv Venema_1991_Many_Dimensional_Modal_Logics_ch2.md sources/venema_1991/
git mv Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md sources/venema_1991/
git mv Venema_1993_Derivation_Rules_Anti_Axioms.md sources/venema_1993/
git mv Venema_1993_Since_and_Until.md sources/venema_1993_since/
git mv Venema_1997_Atom_Structures_Sahlqvist.md sources/venema_1997/
git mv Venema_2001_Temporal_Logic_Survey.md sources/venema_2001/
git mv Verbrugge_2004_Completeness_by_construction.md sources/verbrugge_2004/
git mv Xu_1988_On_some_US_tense_logics.md sources/xu_1988/

# Files going into NEW source directories
git mv Blackburn_deRijke_Venema_2002_Modal_Logic.md sources/blackburn_2002/
git mv Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.md sources/hodkinson_2006/
git mv Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.md sources/libkin_2004_ch3_ch7/
git mv Rabinovich_2014_Proof_of_Kamps_Theorem.md sources/rabinovich_2014/
git mv Thomas_1997_EF_Games_Composition_Monadic.md sources/thomas_1997/

# Move 3 loose PDFs (gitignored, use plain mv)
mv Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.pdf sources/hodkinson_2006/
mv Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.pdf sources/libkin_2004_ch3_ch7/
mv Rabinovich_2014_Proof_of_Kamps_Theorem.pdf sources/rabinovich_2014/
```

**Verification**:
- `ls *.md` shows only `README.md` and `DEPRECATED.md`
- `ls *.pdf` returns empty (no loose PDFs)
- Each `sources/{id}/` contains its markdown file

---

### Phase 3: Update index.json paths [COMPLETED]

**Goal**: Prefix all 30 `path` values in `index.json` with `sources/{id}/` to reflect new locations.

**Tasks**:
- [ ] Update all 30 entry paths in `index.json` to include `sources/` prefix matching their target directory
- [ ] Validate JSON syntax after edit

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `specs/literature/index.json` - update all 30 `path` fields

**Path mapping** (complete):

| index id | Old path | New path |
|----------|----------|----------|
| blackburn_2002 | `Blackburn_deRijke_Venema_2002_Modal_Logic.md` | `sources/blackburn_2002/Blackburn_deRijke_Venema_2002_Modal_Logic.md` |
| burgess_1982_i | `Burgess_1982_Axioms_for_tense_logic_Since_and_Until.md` | `sources/burgess_1982/Burgess_1982_Axioms_for_tense_logic_Since_and_Until.md` |
| burgess_1982_ii | `Burgess_1982b_Axioms_for_tense_logic_II_Time_periods.md` | `sources/burgess_1982b/Burgess_1982b_Axioms_for_tense_logic_II_Time_periods.md` |
| burgess_1984 | `Burgess_1984_Basic_Tense_Logic.md` | `sources/burgess_1984/Burgess_1984_Basic_Tense_Logic.md` |
| caleiro_2013 | `Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md` | `sources/caleiro_2013/Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md` |
| derijke_venema_1995 | `deRijke_Venema_1995_Sahlqvist_BAOs.md` | `sources/derijke_1995/deRijke_Venema_1995_Sahlqvist_BAOs.md` |
| doets_1987 | `Doets_1987_Completeness_and_Definability_thesis.md` | `sources/doets_1987/Doets_1987_Completeness_and_Definability_thesis.md` |
| doets_1989 | `Doets_1989_Monadic_Pi11_Theories.md` | `sources/doets_1989/Doets_1989_Monadic_Pi11_Theories.md` |
| gabbay_1993 | `Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md` | `sources/gabbay_1993/Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md` |
| gabbay_1994_ch9 | `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md` | `sources/gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md` |
| gabbay_1994_ch10 | `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md` | `sources/gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md` |
| gabbay_1994_ch12 | `Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md` | `sources/gabbay_1994/Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md` |
| goldblatt_2003 | `Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md` | `sources/goldblatt_2003/Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md` |
| hodkinson_2006 | `Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.md` | `sources/hodkinson_2006/Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.md` |
| libkin_2004_ch3_ch7 | `Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.md` | `sources/libkin_2004_ch3_ch7/Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.md` |
| obendrauf_2024 | `Obendrauf_2024_Lean_Formalization_Coalition_Logic.md` | `sources/obendrauf_2024/Obendrauf_2024_Lean_Formalization_Coalition_Logic.md` |
| rabinovich_2014 | `Rabinovich_2014_Proof_of_Kamps_Theorem.md` | `sources/rabinovich_2014/Rabinovich_2014_Proof_of_Kamps_Theorem.md` |
| reynolds_1992 | `Reynolds_1992_Axiomatization_Until_Since_without_IRR.md` | `sources/reynolds_1992/Reynolds_1992_Axiomatization_Until_Since_without_IRR.md` |
| reynolds_1994 | `Reynolds_1994_Axiomatising_U_and_S_over_integer_time.md` | `sources/reynolds_1994/Reynolds_1994_Axiomatising_U_and_S_over_integer_time.md` |
| reynolds_2001 | `Reynolds_2001_Axiomatization_Full_CTL_star.md` | `sources/reynolds_2001/Reynolds_2001_Axiomatization_Full_CTL_star.md` |
| thomas_1997 | `Thomas_1997_EF_Games_Composition_Monadic.md` | `sources/thomas_1997/Thomas_1997_EF_Games_Composition_Monadic.md` |
| thomason_1984 | `Thomason_1984_Combinations_of_Tense_and_Modality.md` | `sources/thomason_1984/Thomason_1984_Combinations_of_Tense_and_Modality.md` |
| venema_1991_ch2 | `Venema_1991_Many_Dimensional_Modal_Logics_ch2.md` | `sources/venema_1991/Venema_1991_Many_Dimensional_Modal_Logics_ch2.md` |
| venema_1991_app | `Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md` | `sources/venema_1991/Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md` |
| venema_1993_anti_axioms | `Venema_1993_Derivation_Rules_Anti_Axioms.md` | `sources/venema_1993/Venema_1993_Derivation_Rules_Anti_Axioms.md` |
| venema_1993_since_until | `Venema_1993_Since_and_Until.md` | `sources/venema_1993_since/Venema_1993_Since_and_Until.md` |
| venema_1997 | `Venema_1997_Atom_Structures_Sahlqvist.md` | `sources/venema_1997/Venema_1997_Atom_Structures_Sahlqvist.md` |
| venema_2001 | `Venema_2001_Temporal_Logic_Survey.md` | `sources/venema_2001/Venema_2001_Temporal_Logic_Survey.md` |
| verbrugge_2004 | `Verbrugge_2004_Completeness_by_construction.md` | `sources/verbrugge_2004/Verbrugge_2004_Completeness_by_construction.md` |
| xu_1988 | `Xu_1988_On_some_US_tense_logics.md` | `sources/xu_1988/Xu_1988_On_some_US_tense_logics.md` |

**Approach**: Use Python to load index.json, build a mapping from entry id to target directory, update all paths, and write back.

```python
import json

ID_TO_DIR = {
    "blackburn_2002": "blackburn_2002",
    "burgess_1982_i": "burgess_1982",
    "burgess_1982_ii": "burgess_1982b",
    "burgess_1984": "burgess_1984",
    "caleiro_2013": "caleiro_2013",
    "derijke_venema_1995": "derijke_1995",
    "doets_1987": "doets_1987",
    "doets_1989": "doets_1989",
    "gabbay_1993": "gabbay_1993",
    "gabbay_1994_ch9": "gabbay_1994",
    "gabbay_1994_ch10": "gabbay_1994",
    "gabbay_1994_ch12": "gabbay_1994",
    "goldblatt_2003": "goldblatt_2003",
    "hodkinson_2006": "hodkinson_2006",
    "libkin_2004_ch3_ch7": "libkin_2004_ch3_ch7",
    "obendrauf_2024": "obendrauf_2024",
    "rabinovich_2014": "rabinovich_2014",
    "reynolds_1992": "reynolds_1992",
    "reynolds_1994": "reynolds_1994",
    "reynolds_2001": "reynolds_2001",
    "thomas_1997": "thomas_1997",
    "thomason_1984": "thomason_1984",
    "venema_1991_ch2": "venema_1991",
    "venema_1991_app": "venema_1991",
    "venema_1993_anti_axioms": "venema_1993",
    "venema_1993_since_until": "venema_1993_since",
    "venema_1997": "venema_1997",
    "venema_2001": "venema_2001",
    "verbrugge_2004": "verbrugge_2004",
    "xu_1988": "xu_1988",
}

with open("specs/literature/index.json") as f:
    data = json.load(f)

for entry in data["entries"]:
    eid = entry["id"]
    if eid in ID_TO_DIR:
        filename = entry["path"].split("/")[-1]
        entry["path"] = f"sources/{ID_TO_DIR[eid]}/{filename}"

with open("specs/literature/index.json", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
```

**Verification**:
- `python3 -c "import json; d=json.load(open('specs/literature/index.json')); print(all(e['path'].startswith('sources/') for e in d['entries']))"`  returns `True`
- `python3 -m json.tool specs/literature/index.json > /dev/null` exits 0

---

### Phase 4: Update .gitignore and README.md [COMPLETED]

**Goal**: Update `.gitignore` PDF pattern to cover `sources/**/*.pdf` and update any path references in `README.md`.

**Tasks**:
- [ ] Update `.gitignore` pattern from `specs/literature/*.pdf` to `specs/literature/sources/**/*.pdf`
- [ ] Keep `literature/*.pdf` pattern if it exists (covers root Literature/ repo)
- [ ] Grep `README.md` for any path references that need `sources/` prefix
- [ ] Update `DEPRECATED.md` if it contains path references
- [ ] Verify final structure

**Timing**: 10 minutes

**Depends on**: 3

**Files to modify**:
- `.gitignore` - update PDF glob pattern
- `specs/literature/README.md` - update path references if any

**Shell commands**:
```bash
cd ~/Projects/BimodalLogic

# Update .gitignore: replace specs/literature/*.pdf with sources pattern
sed -i 's|specs/literature/\*.pdf|specs/literature/sources/**/*.pdf|' .gitignore

# Check README.md for path references needing update
grep -n 'specs/literature/' specs/literature/README.md || echo "No cross-refs found"
```

**Verification**:
- `grep 'sources/\*\*/\*.pdf' .gitignore` finds the new pattern
- `ls specs/literature/` shows only: `README.md`, `DEPRECATED.md`, `index.json`, `sources/`
- `ls specs/literature/sources/` shows 27 directories
- No loose `.md` files at root (except README.md, DEPRECATED.md)
- No loose `.pdf` files at root

## Testing & Validation

- [ ] `ls specs/literature/sources/ | wc -l` returns 27 (22 moved + 5 new)
- [ ] `ls specs/literature/*.md` returns only `README.md` and `DEPRECATED.md`
- [ ] `ls specs/literature/*.pdf 2>/dev/null` returns empty
- [ ] `test -d specs/literature/blackburn_2001` returns false (exit 1)
- [ ] `python3 -c "import json; d=json.load(open('specs/literature/index.json')); assert all(e['path'].startswith('sources/') for e in d['entries']); print('OK')"` prints OK
- [ ] `python3 -m json.tool specs/literature/index.json > /dev/null` exits 0
- [ ] Each of the 30 paths in index.json resolves to an existing file
- [ ] `.gitignore` contains `specs/literature/sources/**/*.pdf` pattern

## Artifacts & Outputs

- `plans/01_bimodal-refactor-plan.md` (this file)
- Restructured `~/Projects/BimodalLogic/specs/literature/sources/` with 27 source directories
- Updated `~/Projects/BimodalLogic/specs/literature/index.json` with `sources/` prefixed paths
- Updated `~/Projects/BimodalLogic/.gitignore` with new PDF pattern

## Rollback/Contingency

All operations are reversible via `git checkout` for tracked files. The blackburn_2001 deletion is the only destructive operation; if needed, recover from git history with `git checkout HEAD -- specs/literature/blackburn_2001/`. PDFs (gitignored) would need manual restoration from backups if moved incorrectly, but they are only being relocated, not deleted.
