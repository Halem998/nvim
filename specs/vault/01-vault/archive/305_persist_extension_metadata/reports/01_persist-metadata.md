# Research Report: Persist Metadata in Extension Source index-entries.json Files

**Task**: 305
**Date**: 2026-03-26
**Status**: Complete

## Problem

Tasks 298 and 300 added domain/subdomain and summary metadata to entries in the Website OUTPUT `index.json`. However, the extension loader rebuilds `index.json` from each extension's SOURCE `index-entries.json` files on every reload, discarding the improvements. The fix is to add the metadata to the SOURCE files so it persists across reloads.

## Extension Source Files

All 14 extension source files at `.claude/extensions/*/index-entries.json`:

| Extension | Total Entries | Missing domain | Missing subdomain | Missing summary |
|-----------|--------------|----------------|-------------------|-----------------|
| epidemiology | 4 | 0 | 0 | 0 |
| filetypes | 7 | 7 | 7 | 7 |
| formal | 45 | 45 | 45 | 0 |
| founder | 22 | 22 | 22 | 0 |
| latex | 10 | 10 | 10 | 10 |
| lean | 26 | 26 | 26 | 26 |
| memory | 5 | 5 | 5 | 5 |
| nix | 11 | 11 | 11 | 11 |
| nvim | 21 | 0 | 0 | 0 |
| present | 21 | 0 | 0 | 0 |
| python | 6 | 6 | 6 | 6 |
| typst | 26 | 26 | 26 | 26 |
| web | 23 | 23 | 23 | 23 |
| z3 | 5 | 5 | 5 | 5 |
| **Total** | **232** | **186** | **186** | **119** |

Three extensions already have complete metadata: epidemiology, nvim, present.
Eleven extensions need domain/subdomain. Of those, some (formal, founder) already have summaries via a `description` field but lack the `summary` field specifically.

## Metadata Conventions

### domain/subdomain (from task 298)

- `domain` = `"project"` for all extension entries
- `subdomain` = second path component of the entry's `path` field
  - e.g., `project/typst/` -> subdomain `"typst"`
  - e.g., `project/web/` -> subdomain `"web"`
  - **Exception**: `project/lean4/` -> subdomain `"lean"` (existing convention)

### summary (from task 300)

- 27-112 characters
- Noun-phrase style (e.g., "Z3 Python API reference and examples")
- No trailing period
- Some extensions already have a `description` field that could serve as the summary value if it meets the conventions

## Proposed Approach

### Phase 1: Add domain/subdomain (mechanical)

For each of the 11 extensions missing domain/subdomain:
1. Read `index-entries.json`
2. For each entry, add `"domain": "project"` and derive `"subdomain"` from the second path component
3. Write back the updated file

This is fully mechanical -- no file reading needed. Affects 186 entries across 11 extensions.

### Phase 2: Add summaries (requires reading referenced files)

For each of the 119 entries missing summaries across 11 extensions:
1. Check if the entry has an existing `description` field that meets summary conventions
2. If yes, copy `description` to `summary`
3. If no, read the first 10-20 lines of the referenced context file to generate an appropriate noun-phrase summary
4. Validate summary length (27-112 chars) and style (noun-phrase, no trailing period)

This is the slower part -- each of the ~119 entries needs its referenced file read for summary generation.

### Note on existing `description` fields

Several extensions (formal, founder, z3, and others) already have a `description` field on entries. These descriptions are often suitable as summaries (correct length, noun-phrase style). The implementation should check each description against the summary conventions before copying.

## Counts Summary

- **186 entries** need domain/subdomain added (mechanical, fast)
- **119 entries** need summary added (requires reading files, slower)
- **232 total entries** across 14 extensions
- **3 extensions** already complete (epidemiology, nvim, present)
- **11 extensions** need updates

## Dependencies

- **Task 303** should be completed first (remove duplicates from filetypes source before adding metadata to it)
- This task supersedes the approach of tasks 298/300 (which fixed the output index.json rather than the source files)

## Effort Estimate

2-3 hours total:
- Phase 1 (domain/subdomain): ~15 minutes (mechanical jq/script work)
- Phase 2 (summaries): ~2 hours (reading 119 files and generating summaries)
- Validation: ~15 minutes
