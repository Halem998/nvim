# Implementation Summary: Task #736

**Completed**: 2026-06-16
**Duration**: ~15 minutes

## Overview

Updated the literature extension to support the `sources/` subdirectory convention used by the centralized `LITERATURE_DIR` repository. Three files were modified to add transparent dual-layout support — centralized repos get `sources/` prefixed paths while per-project `specs/literature/` directories retain the flat layout.

## What Changed

- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Added `sources_prefix` variable after `lit_dir` assignment; updated 5 path construction sites in convert mode (2 `chunk_dir` assignments, 2 `output_files` entries for multi-chunk, 1 `output_files` entry for single-file)
- `.claude/extensions/core/scripts/literature-retrieve.sh` — Added `scan_dir` logic in the fallback `find` path to prefer `$LIT_DIR/sources` when it exists
- `.claude/extensions/literature/EXTENSION.md` — Added "sources/ Subdirectory Convention" paragraph after "Source file co-location" paragraph

## Decisions

- `sources_prefix` is set to `"sources/"` only when `LITERATURE_DIR` is set AND `lit_dir` equals `LITERATURE_DIR` — this correctly excludes the case where `LITERATURE_DIR` is set but the directory doesn't exist (fallback to `specs/literature/`)
- The fallback `find` in `literature-retrieve.sh` scans `$LIT_DIR/sources` only when that directory exists, preserving backward compatibility for flat layouts

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: N/A
- Files verified: Yes — all 3 modified files confirmed via Edit tool success responses

## Notes

The index-based retrieval path in `literature-retrieve.sh` is unaffected because it reads paths directly from `index.json` entries, which already carry the `sources/` prefix when populated by the convert mode.
