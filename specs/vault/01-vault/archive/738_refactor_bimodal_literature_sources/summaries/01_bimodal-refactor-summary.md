# Implementation Summary: Task #738

**Completed**: 2026-06-16
**Duration**: ~15 minutes

## Overview

Restructured `~/Projects/BimodalLogic/specs/literature/` to use a `sources/` subdirectory,
matching the centralized Literature/ repository convention. All 22 existing source subdirectories
were moved into `sources/`, 5 new directories were created for sources that only had loose files,
30 loose markdown files and 3 PDFs were co-located into their corresponding `sources/{id}/`
directories, `blackburn_2001/` was removed, index.json paths were updated, and `.gitignore`
was extended to cover the new path pattern.

## What Changed

- `~/Projects/BimodalLogic/specs/literature/sources/` — Created; now contains 27 subdirectories
- `~/Projects/BimodalLogic/specs/literature/blackburn_2001/` — Removed (37 chapter chunks + index)
- `~/Projects/BimodalLogic/specs/literature/index.json` — Updated all 30 entry paths with `sources/` prefix
- `~/Projects/BimodalLogic/.gitignore` — Added `specs/literature/sources/**/*.pdf` pattern

## Decisions

- Used `git mv` for all tracked markdown files to preserve rename history
- Used plain `mv` for the 3 gitignored PDFs (Hodkinson 2006, Libkin 2004, Rabinovich 2014)
- Used `rm -rf` (not `git rm`) for `blackburn_2001/` since the directory was already staged for deletion and its tracked files needed removal
- README.md required no path updates (uses bare filenames in backtick references, not full paths)
- DEPRECATED.md required no updates

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: N/A
- Files verified: Yes — all 30 index.json paths resolve to existing files; `sources/` contains 27 dirs; no loose .md or .pdf at root except README.md and DEPRECATED.md; blackburn_2001 absent

## Notes

The centralized `~/Projects/Literature/` repository (from task 710) already uses the `sources/`
subdirectory convention. This refactoring brings the BimodalLogic per-project literature directory
into alignment with that convention.
