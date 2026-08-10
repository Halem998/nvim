# Research Report: Refactor cslib specs/literature/ to sources/ Structure

## Task 737

## Current Structure

~/Projects/cslib/specs/literature/ contains:

### Loose Markdown Files (11)
- bentzen_2023.md, burgess_1982_i.md, burgess_1982_ii.md, burgess_1984.md
- from_2022.md, gabbay_1994_ch10.md, henkin_1949.md, johansson_1937.md
- post_1921.md, reynolds_1992.md, trufas_2024.md

### Content Subdirectories (7)
- blackburn_2001/ (TO BE REMOVED)
- chagrov_1997/, church_1956/, gentzen_1935/, hughes_1996/, mendelson_2016/, zakharyaschev_2001/

### Source Files (1)
- chagrov_1997.djvu (loose, should co-locate with sources/chagrov_1997/)

### Index
- index.json: 76 entries with flat paths

## blackburn_2001 Analysis

The blackburn_2001/ directory contains chunked chapter files. Need to count how many index.json entries reference it and remove all of them.

## Migration Plan

1. Create `sources/` subdirectory
2. Move 6 content subdirectories (excluding blackburn_2001) into `sources/`
3. Create individual `sources/{id}/` directories for 11 loose markdown files
4. Move chagrov_1997.djvu into `sources/chagrov_1997/`
5. Delete `blackburn_2001/` entirely
6. Update index.json: prefix all remaining paths with `sources/`, remove blackburn_2001 entries
7. Update README.md path references

## Findings

- The cslib literature directory follows the same flat pattern as BimodalLogic pre-refactor
- blackburn_2001/ removal aligns with Literature/ repo (ghost entries there)
- index.json uses flat paths — all need `sources/` prefix after migration
- chagrov_1997.djvu is the only source file needing relocation
