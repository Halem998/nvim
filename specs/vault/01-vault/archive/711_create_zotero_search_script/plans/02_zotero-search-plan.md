# Implementation Plan: Task #711

- **Task**: 711 - create_zotero_search_script
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 710 (completed -- centralized Literature repo and LITERATURE_DIR established)
- **Research Inputs**: specs/711_create_zotero_search_script/reports/01_zotero-search-research.md
- **Artifacts**: plans/02_zotero-search-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a `zotero-search.sh` script in the literature extension that searches a Better BibTeX CSL-JSON export by keyword using weighted multi-field matching in a single jq pass, then verifies PDF paths via bash post-processing. Register the script in the extension manifest. The script uses OR semantics across query terms with relevance scoring (title 3x, keywords 2x, abstract 1x, author 1x) and outputs sorted JSON results.

### Research Integration

Key findings from report 01:
- CSL-JSON is a top-level array with `citation-key`, `author` as `[{family, given}]`, `issued["date-parts"][0][0]` for year, and `keyword` (comma-separated string) for tags
- PDF attachment paths come from `attachments[].path`, `attachment`, or `PDF` fields (varies by Better BibTeX version)
- `zotero-library.json` does not yet exist -- script must handle absence gracefully with setup instructions
- Pure jq single-pass approach handles 1000+ entries efficiently; PDF verification requires bash post-pass
- Library path fallback chain: `ZOTERO_LIBRARY` env var > `$LITERATURE_DIR/zotero-library.json` > `~/Projects/Literature/zotero-library.json`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the completed "Literature centralization" roadmap item (Phase 2) by providing search capability on top of the centralized `~/Projects/Literature/` repository and its Zotero CSL-JSON integration. It directly builds on task 710's `LITERATURE_DIR` and `zotero-library.json` conventions.

## Goals & Non-Goals

**Goals**:
- Create a working `zotero-search.sh` script with weighted multi-field keyword search
- Support configurable library path via environment variable with sensible fallback chain
- Output valid JSON array with citation key, title, authors, year, score, pdf paths, and abstract snippet
- Verify PDF paths exist on disk before including them in results
- Register the script in the literature extension manifest
- Handle missing library file gracefully with clear setup instructions

**Non-Goals**:
- BibTeX parsing (only CSL-JSON is supported)
- Full-text PDF search (only searches bibliographic metadata)
- Interactive TUI or fuzzy-finder integration (CLI JSON output only)
- Automatic Zotero export configuration (user must set up Better BibTeX auto-export manually)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| CSL-JSON attachment field name varies across Better BibTeX versions | M | M | Check `attachments[].path`, `attachment`, and `PDF` fields; use first non-null |
| `keyword` field may be absent in many entries (Zotero tags not exported) | L | M | Treat missing field as empty string; scoring still works via title/abstract/author |
| jq `test()` with special regex chars in query terms | M | L | Escape regex special chars in query terms before passing to jq |
| Large library (2000+ entries) could be slow | L | L | Single jq pass is efficient; no concern below 5000 entries |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create script directory and write zotero-search.sh [COMPLETED]

**Goal**: Create the complete search script with argument parsing, library resolution, jq-based scoring, and PDF verification

**Tasks**:
- [ ] Create `.claude/extensions/literature/scripts/` directory
- [ ] Write `zotero-search.sh` with shebang and header documentation (usage, env vars, exit codes)
- [ ] Implement argument parsing: `--limit=N` (default 10), `--format=json|pretty`, positional query
- [ ] Implement library path resolution with 3-tier fallback chain
- [ ] Implement graceful error handling for missing library file (exit 1 with setup instructions)
- [ ] Implement query term extraction: lowercase, split on whitespace, filter stop words, filter terms < 3 chars
- [ ] Implement single-pass jq scoring: title (3x), keyword (2x), abstract (1x), author (1x) with OR semantics
- [ ] Implement jq output formatting: `{citation_key, title, authors, year, score, pdf_paths:[], abstract_snippet}`
- [ ] Implement bash PDF path verification post-pass: extract paths from jq output, check `[ -f ]`, inject back
- [ ] Implement `--format=pretty` output mode (human-readable table)
- [ ] Set exit codes: 0 (results found), 1 (no library file), 2 (no results)
- [ ] Make script executable (`chmod +x`)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/scripts/zotero-search.sh` - Create new script (full implementation)

**Verification**:
- Script is executable and passes `bash -n` syntax check
- Running with no arguments prints usage and exits non-zero
- Running with `ZOTERO_LIBRARY=/nonexistent` prints setup instructions and exits 1

---

### Phase 2: Update literature extension manifest [COMPLETED]

**Goal**: Register the new script in the manifest so it is deployed with the extension

**Tasks**:
- [ ] Add `"scripts": ["scripts/zotero-search.sh"]` to the `provides` object in `manifest.json`
- [ ] Verify JSON validity of updated manifest with `jq . manifest.json`

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/manifest.json` - Add `provides.scripts` array

**Verification**:
- `jq '.provides.scripts' .claude/extensions/literature/manifest.json` outputs `["scripts/zotero-search.sh"]`
- `jq . .claude/extensions/literature/manifest.json` succeeds (valid JSON)

---

### Phase 3: Integration testing and edge case validation [COMPLETED]

**Goal**: Verify the script handles all edge cases correctly and produces valid output

**Tasks**:
- [ ] Test with `bash -n` for syntax validation
- [ ] Test library path fallback chain (unset all env vars, verify correct default path message)
- [ ] Test with empty query string (should print usage)
- [ ] Test with `ZOTERO_LIBRARY` pointing to a non-existent file (exit 1 with setup instructions)
- [ ] Create a minimal test CSL-JSON file (3-5 entries) and verify search produces correct ranked output
- [ ] Verify JSON output validity with `jq .` on script output
- [ ] Verify `--format=pretty` produces readable output
- [ ] Test regex special character handling in query terms (e.g., "C++" should not crash jq)

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/literature/scripts/zotero-search.sh` - Bug fixes from testing (if any)

**Verification**:
- All test scenarios pass without errors
- Output is always valid JSON (even on edge cases)
- Exit codes match specification (0, 1, 2)

## Testing & Validation

- [ ] `bash -n .claude/extensions/literature/scripts/zotero-search.sh` passes (no syntax errors)
- [ ] Script with no args prints usage and exits non-zero
- [ ] Script with `ZOTERO_LIBRARY=/nonexistent` exits 1 with setup instructions
- [ ] Script against a test CSL-JSON file returns correctly scored and sorted results
- [ ] JSON output passes `jq .` validation
- [ ] PDF paths in output all exist on disk (tested with known paths)
- [ ] `jq '.provides.scripts' .claude/extensions/literature/manifest.json` returns the script path
- [ ] `--limit=N` correctly caps output size
- [ ] Query with regex special chars does not crash

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/zotero-search.sh` - The search script (new)
- `.claude/extensions/literature/manifest.json` - Updated manifest with `provides.scripts`
- `specs/711_create_zotero_search_script/plans/02_zotero-search-plan.md` - This plan

## Rollback/Contingency

Rollback is straightforward:
- Delete `.claude/extensions/literature/scripts/` directory
- Revert `manifest.json` to remove the `provides.scripts` entry
- No other files are modified; the script is a new standalone utility with no integration points that would break if removed
