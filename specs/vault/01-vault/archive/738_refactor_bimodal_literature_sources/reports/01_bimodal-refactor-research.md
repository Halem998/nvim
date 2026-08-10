# Research Report: Refactor BimodalLogic specs/literature/ to sources/ Structure

## Task 738

## Current Structure

~/Projects/BimodalLogic/specs/literature/ contains:

### Loose Markdown Files (30)
Full list of loose .md files including Blackburn_deRijke_Venema_2002_Modal_Logic.md, various Burgess/Venema/Reynolds papers, etc.

### Content Subdirectories (23)
blackburn_2001 (TO BE REMOVED), burgess_1982, burgess_1982b, burgess_1984, caleiro_2013, derijke_1995, doets_1987, doets_1989, gabbay_1993, gabbay_1994, goldblatt_2003, obendrauf_2024, reynolds_1992, reynolds_1994, reynolds_2001, thomason_1984, venema_1991, venema_1993, venema_1993_since, venema_1997, venema_2001, verbrugge_2004, xu_1988

### Loose PDFs (3)
- Hodkinson_Reynolds_2006_Temporal_Logic_Handbook_Ch11.pdf
- Libkin_2004_Elements_Finite_Model_Theory_ch3_ch7.pdf
- Rabinovich_2014_Proof_of_Kamps_Theorem.pdf

### Index
- Root index.json: 30 entries, none reference blackburn_2001 (only blackburn_2002)
- blackburn_2001/index.json: 33 chapter entries in chapters[] format (separate sub-index)

## Key Findings

1. Root index.json has 30 entries; zero reference blackburn_2001
2. blackburn_2001/ has its own sub-index.json with 33 chapter entries — these are NOT in root index
3. 22 existing subdirectories move into sources/ (blackburn_2001 deleted, not moved)
4. 5 new sources/{id}/ directories needed for sources with only loose files: blackburn_2002, hodkinson_2006, libkin_2004_ch3_ch7, rabinovich_2014, thomas_1997
5. 30 loose MDs distribute into respective sources/{id}/ dirs
6. 3 loose PDFs co-locate with their MDs in new dirs
7. Root index.json needs all 30 path values prefixed with sources/{dir}/
8. .gitignore pattern `specs/literature/*.pdf` needs `specs/literature/sources/**/*.pdf` added
9. README.md uses bare filenames (not paths) — minimal path updates needed
