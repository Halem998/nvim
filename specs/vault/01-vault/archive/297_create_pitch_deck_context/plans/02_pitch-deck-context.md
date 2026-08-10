# Implementation Plan: Task #297

**Task**: Remove duplicate pitch-deck index entries
**Date**: 2026-03-26
**Version**: 1

## Summary

Remove 2 duplicate index.json entries that reference non-existent files in the `filetypes` subdomain. The correct entries already exist in the `present` subdomain.

## Phase 1: Remove duplicate entries [NOT STARTED]

### Steps

1. Edit `/home/benjamin/Projects/Logos/Website/.claude/context/index.json`
2. Remove the entry for `project/filetypes/patterns/pitch-deck-structure.md` (lines 448-462)
3. Remove the entry for `project/filetypes/patterns/touying-pitch-deck-template.md` (lines 463-477)

### Verification

- Confirm `project/present/patterns/pitch-deck-structure.md` entry still exists in index
- Confirm `project/present/patterns/touying-pitch-deck-template.md` entry still exists in index
- Validate JSON syntax with `jq`

## Risk Assessment

- **Low risk**: Only removing entries that point to non-existent files
- **No functional impact**: The present subdomain entries have richer metadata and are the ones actually used
