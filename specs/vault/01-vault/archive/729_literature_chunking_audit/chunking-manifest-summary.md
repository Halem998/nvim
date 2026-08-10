# Chunking Quality Manifest Summary

**Generated**: 2026-06-16
**Task**: 729 — Audit Literature Subdirectories for Chunking Quality

## Overview

Audited `~/Projects/Literature/` for 23 subdirectories and 30 flat files. cslib has no `specs/literature/` directory; cslib scanning was skipped.

### Totals

| Category | Count |
|----------|-------|
| Literature/ subdirectories | 23 |
| Subdirectories: good (keep) | 20 |
| Subdirectories: rename needed | 3 |
| Literature/ flat files total | 30 |
| Flat files: duplicate of subdir | 25 |
| Flat files: unique (no subdir) | 5 |
| Flat files: critically oversized | 1 |
| cslib literature subdirs | 0 (dir not found) |

---

## Literature/ Subdirectories

### Status: GOOD (keep as-is)

| Directory | Files | Max Chunk Tokens | Pattern |
|-----------|-------|------------------|---------|
| blackburn_2001 | 33 | 16,944 | semantic (ch/appab) |
| burgess_1982 | 2 | 3,950 | semantic |
| burgess_1982b | 2 | 4,414 | semantic |
| caleiro_2013 | 7 | 4,747 | semantic |
| derijke_1995 | 3 | 4,753 | semantic |
| doets_1987 | 3 | 4,684 | semantic |
| gabbay_1993 | 5 | 7,578 | semantic |
| gabbay_1994 | 11 | 8,405 | semantic |
| goldblatt_2003 | 5 | 5,208 | semantic |
| obendrauf_2024 | 4 | 4,361 | semantic |
| reynolds_1992 | 5 | 4,046 | semantic |
| reynolds_2001 | 10 | 4,197 | semantic |
| thomason_1984 | 6 | 6,489 | semantic |
| venema_1991 | 9 | 5,069 | semantic |
| venema_1993 | 9 | 4,532 | semantic |
| venema_1993_since | 2 | 4,554 | semantic |
| venema_1997 | 3 | 4,554 | semantic |
| venema_2001 | 4 | 4,045 | semantic |
| verbrugge_2004 | 4 | 4,018 | semantic |
| xu_1988 | 5 | 4,659 | semantic |

### Status: RENAME NEEDED (arbitrary chunk names)

These 3 directories have chunks named by page number or part number rather than semantic topic. Phase 2 renames these files.

| Directory | Files | Current Pattern | Proposed Pattern |
|-----------|-------|-----------------|-----------------|
| burgess_1984 | 7 | `sec{N}_page-{N}.md` | `sec{N}_{topic}.md` |
| doets_1989 | 3 | `sec{N}_part-{N}.md` | `sec{N}_{topic}.md` |
| reynolds_1994 | 3 | `sec{N}_part-{N}.md` | `sec{N}_{topic}.md` |

#### burgess_1984 — Proposed Renames

| Old Name | New Name | Content |
|----------|----------|---------|
| sec01_page-1.md | sec01_basic-modal-logic-ultraproducts.md | Basic Modal Logic §24: Two Further Results (ultraproducts) |
| sec02_page-8.md | sec02_basic-modal-logic-bibliography.md | References/bibliography section |
| sec03_page-16.md | sec03_basic-tense-logic-motivation.md | Basic Tense Logic §0.5: Motivation |
| sec04_page-23.md | sec04_basic-tense-logic-killing-lemma.md | §1.11 Killing Lemma and completeness |
| sec05_page-30.md | sec05_basic-tense-logic-continuity.md | §2.7 Continuity |
| sec06_page-37.md | sec06_basic-tense-logic-decidability.md | §3.2 Theorem: Ly is decidable |
| sec07_page-45.md | sec07_basic-tense-logic-time-periods.md | §5 Time Periods |

#### doets_1989 — Proposed Renames

| Old Name | New Name | Content |
|----------|----------|---------|
| sec01_part-1.md | sec01_monadic-pi11-axiomatizations-introduction.md | Introduction and main axiomatization theorems |
| sec02_part-2.md | sec02_monadic-pi11-scattered-orderings-proof.md | Scattered orderings proofs using EF-games |
| sec03_part-3.md | sec03_monadic-pi11-well-founded-trees.md | Well-founded trees and substitution lemma |

#### reynolds_1994 — Proposed Renames

| Old Name | New Name | Content |
|----------|----------|---------|
| sec01_part-1.md | sec01_axiomatization-US-integer-time-introduction.md | Introduction and axiom system presentation |
| sec02_part-2.md | sec02_axiomatization-US-prior-structures-completeness.md | Prior structures and expressive completeness |
| sec03_part-3.md | sec03_axiomatization-US-contemporaneity.md | §8 Contemporaneity on the integers |

---

## Literature/ Flat Files

### Critically Oversized (chunk-new)

| File | Approx Tokens | Action |
|------|---------------|--------|
| Blackburn_deRijke_Venema_2002_Modal_Logic.md | 365,325 | Create dedicated chunking task (task 730) |

**Note**: The blackburn_2001 subdirectory is a *different* resource (2001 textbook edition). The flat file is the 2002 Cambridge edition with no subdirectory equivalent.

### Unique Flat Files (keep as-is)

| File | Approx Tokens | Notes |
|------|---------------|-------|
| Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.md | 2,410 | Small; acceptable |
| Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.md | 4,119 | Acceptable size |
| Rabinovich_2014_Proof_of_Kamps_Theorem.md | 3,435 | Acceptable size |
| Thomas_1997_EF_Games_Composition_Monadic.md | 1,435 | Very small |

**Note**: README.md excluded (not a literature source).

### Duplicate Flat Files (review-for-removal)

These 25 files have chunked equivalents in subdirectories. User should review for deletion.

| File | Subdir Equivalent | Approx Tokens |
|------|-------------------|---------------|
| Burgess_1982_Axioms_for_tense_logic_Since_and_Until.md | burgess_1982/ | 6,031 |
| Burgess_1982b_Axioms_for_tense_logic_II_Time_periods.md | burgess_1982b/ | 6,858 |
| Burgess_1984_Basic_Tense_Logic.md | burgess_1984/ | 24,978 |
| Caleiro_Vigano_Volpe_2013_Mosaic_Method_Tense_Modal.md | caleiro_2013/ | 22,712 |
| Doets_1987_Completeness_and_Definability_thesis.md | doets_1987/ | 10,791 |
| Doets_1989_Monadic_Pi11_Theories.md | doets_1989/ | 12,013 |
| Gabbay_Hodkinson_Reynolds_1993_Temporal_expressive_completeness_gaps.md | gabbay_1993/ | 18,953 |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch10.md | gabbay_1994/ | 10,853 |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch12.md | gabbay_1994/ | 18,528 |
| Gabbay_Hodkinson_Reynolds_1994_Temporal_Logic_Foundations_Vol1_ch9.md | gabbay_1994/ | 9,270 |
| Goldblatt_Hodkinson_Venema_2003_BAOs_Modal_Logic.md | goldblatt_2003/ | 19,158 |
| Obendrauf_2024_Lean_Formalization_Coalition_Logic.md | obendrauf_2024/ | 16,179 |
| Reynolds_1992_Axiomatization_Until_Since_without_IRR.md | reynolds_1992/ | 16,858 |
| Reynolds_1994_Axiomatising_U_and_S_over_integer_time.md | reynolds_1994/ | 10,665 |
| Reynolds_2001_Axiomatization_Full_CTL_star.md | reynolds_2001/ | 32,378 |
| Thomason_1984_Combinations_of_Tense_and_Modality.md | thomason_1984/ | 18,948 |
| Venema_1991_Many_Dimensional_Modal_Logics_app_A_B.md | venema_1991/ | 11,873 |
| Venema_1991_Many_Dimensional_Modal_Logics_ch2.md | venema_1991/ | 25,522 |
| Venema_1993_Derivation_Rules_Anti_Axioms.md | venema_1993/ | 28,026 |
| Venema_1993_Since_and_Until.md | venema_1993_since/ | 4,750 |
| Venema_1997_Atom_Structures_Sahlqvist.md | venema_1997/ | 10,779 |
| Venema_2001_Temporal_Logic_Survey.md | venema_2001/ | 15,851 |
| Verbrugge_2004_Completeness_by_construction.md | verbrugge_2004/ | 10,765 |
| Xu_1988_On_some_US_tense_logics.md | xu_1988/ | 12,025 |
| deRijke_Venema_1995_Sahlqvist_BAOs.md | derijke_1995/ | 11,359 |

---

## cslib Literature Status

`~/Projects/cslib/specs/` exists but contains only task management artifacts (no `literature/` subdirectory). The research report's findings about cslib oversized entries (chagrov_1997, church_1956, etc.) may refer to a different location or a past state. No cslib literature scanning was performed.

---

## index.json Impact

The `~/Projects/Literature/index.json` contains 183 entries. Of these, **13 entries reference old page/part-based filenames** that will be changed in Phase 2:

- `burgess_1984/sec01_page-1.md` through `sec07_page-45.md` (7 entries)
- `doets_1989/sec01_part-1.md` through `sec03_part-3.md` (3 entries)
- `reynolds_1994/sec01_part-1.md` through `sec03_part-3.md` (3 entries)

These 13 entries will be updated when Phase 2 renames are executed.

---

## Follow-Up Action Summary

| Priority | Action | Target | Effort |
|----------|--------|--------|--------|
| 1 | Create chunking task | Blackburn_deRijke_Venema_2002_Modal_Logic.md (365K tokens) | High — separate task recommended |
| 2 | User review/delete | 25 duplicate flat files | Low — user decision required |

---

## Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Generate Manifest | COMPLETED | JSON manifest and this summary created |
| Phase 2: Rename Arbitrary Chunks | COMPLETED | 13 files renamed across 3 dirs; index.json updated (0 broken refs) |
| Phase 3: Document Oversized cslib | SKIPPED (deviation) | cslib has no specs/literature/ directory |
| Phase 4: Final Validation | COMPLETED | JSON valid, 23 subdirs, 30 flat files, 0 missing files in index |

## Validation Results

- Manifest JSON: valid
- Subdirectory entries: 23 (matches Literature/ dirs)
- Flat file entries: 30 (matches Literature/ root .md files excl. README)
- Renamed files accessible: yes (all 13)
- index.json broken references: 0
