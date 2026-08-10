# Research Report: Task #715

**Task**: 715 - Update literature extension documentation to reflect Zotero search and import capabilities
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:10:00Z
**Effort**: ~1 hour
**Dependencies**: Tasks 710 (centralized architecture), 711 (zotero-search.sh), 714 (import pipeline)
**Sources/Inputs**: Codebase (all affected files read directly)
**Artifacts**: - specs/715_update_literature_extension_docs/reports/01_docs-update-research.md
**Standards**: report-format.md

---

## Executive Summary

- The implementation files (skill-literature/SKILL.md, commands/literature.md) are already fully updated with Zotero search and import capabilities
- The documentation files (manifest.json, EXTENSION.md, README.md) are partially updated — manifest already has the correct description and zotero-search.sh registered; EXTENSION.md has the Zotero integration note but missing the Commands table entries for --search and --task; README.md is still missing all Zotero documentation
- The core merge-source (claudemd.md) is missing --search and --task rows in the /literature command table, and the skill-literature description needs updating
- No Literature Extension section exists in CLAUDE.md (not merged yet, or generated from EXTENSION.md)
- The lean and formal extensions do NOT reference `specs/literature/` paths — they use "literature" conceptually for proof sources only; no cross-extension updates needed there

---

## Context & Scope

This research examined the current state of documentation for the Zotero search and import capabilities added by tasks 711 (zotero-search.sh script) and 714 (search + import pipeline in skill-literature and literature command). The goal is to determine which documentation files still need updating and what specific changes are required.

---

## Findings

### 1. manifest.json — Already Updated

**File**: `.claude/extensions/literature/manifest.json`

**Current state**: Already correct.
- `"description"` on line 4 already reads: `"Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json, and search/import from Zotero"`
- `"scripts": ["scripts/zotero-search.sh"]` is already present in `provides` (line 21)

**Status**: No changes needed.

---

### 2. EXTENSION.md — Partially Updated

**File**: `.claude/extensions/literature/EXTENSION.md`

**Current state**:
- The top description (lines 1-4) mentions scanning, converting, validating but does NOT mention Zotero search/import
- Lines 43-45 contain a `**Zotero integration**` note about Better BibTeX CSL-JSON auto-export — this is good
- The Commands table (lines 54-61) lists only 5 modes: bare status, --scan, --convert, --validate, --index
- Missing: `--search "QUERY"` and `--task N` rows

**Needed changes**:

1. **Line 1-2 description update**: Change from:
   ```
   Manage literature directories: scan for unprocessed PDFs/DJVUs, convert them to markdown with
   content-aware chunking, maintain `index.json`, and validate filesystem consistency.
   ```
   To:
   ```
   Manage literature directories: scan for unprocessed PDFs/DJVUs, convert them to markdown with
   content-aware chunking, maintain `index.json`, validate filesystem consistency, and search
   and import from Zotero via Better BibTeX CSL-JSON export.
   ```

2. **Commands table**: Add 2 new rows after `--index FILE`:
   ```
   | `/literature` | `/literature --search "QUERY"` | Search Zotero library and Literature/ index by keyword |
   | `/literature` | `/literature --task N` | Extract task N description as Zotero search query |
   ```

3. **Optional**: Add a `### Zotero Search and Import` subsection between the Zotero integration note and the Skill-Agent Mapping table, documenting the full search/import workflow:
   - zotero-search.sh script, 3-tier library path fallback
   - Weighted multi-field scoring (title +3, keyword +2, abstract +1, author +1)
   - Interactive multi-select results with [IMPORTED]/[PDF AVAILABLE]/[NO PDF] tags
   - Import pipeline: symlink PDF -> convert with PREFILL_* -> patch index with Zotero fields -> git commit

---

### 3. README.md — Needs Significant Updates

**File**: `.claude/extensions/literature/README.md`

**Current state** (110 lines):
- Section "Loading the Extension": OK
- Section "Commands": Lists only 5 modes (no --search, --task)
- Section "Directory Convention": OK but describes only local `specs/literature/` layout; does NOT mention centralized `LITERATURE_DIR` architecture or `pdfs/` symlink directory for imports
- Section "Content-Aware Chunking": OK
- Section "Index Schema": Lists 10 fields but missing 4 enriched v2 fields: `bib_key`, `zotero_key`, `zotero_path`, `project_tags`
- Section "Integration with --lit Flag": OK
- Section "Tool Requirements": OK
- Section "Provided Artifacts": OK but missing `scripts/zotero-search.sh` entry

**Needed changes**:

1. **Commands table**: Add --search and --task rows
2. **Directory Convention**: Add `pdfs/` subdirectory to layout example, mention `LITERATURE_DIR` centralized repo
3. **Index Schema table**: Add 4 missing fields:
   - `bib_key` | string\|null | Original BibTeX/Better BibTeX citation key
   - `zotero_key` | string\|null | Zotero canonical key (Better BibTeX)
   - `zotero_path` | string\|null | Path to PDF in Zotero storage
   - `project_tags` | string[] | Originating Zotero collection tags
4. **New section "Zotero Search and Import"**: Document:
   - Setup: Install Better BibTeX, export CSL-JSON with "Keep updated", set path via ZOTERO_LIBRARY or $LITERATURE_DIR
   - Usage: `/literature --search "modal logic"` and `/literature --task 714`
   - Scoring: weighted multi-field (title/keyword/abstract/author)
   - Results: interactive multi-select with [IMPORTED]/[PDF AVAILABLE]/[NO PDF] status tags
   - Import pipeline: symlink PDF to pdfs/, convert to markdown, patch index entry with bib_key/zotero_key/zotero_path/project_tags, git commit
   - Graceful degradation: falls back to index-only search if zotero-library.json not found
5. **Provided Artifacts table**: Add scripts/zotero-search.sh entry

---

### 4. Core merge-source claudemd.md — /literature command table needs updating

**File**: `.claude/extensions/core/merge-sources/claudemd.md`

**Current state** (lines 107-111):
```
| `/literature` | `/literature` | Show specs/literature/ status and index health |
| `/literature` | `/literature --scan` | Scan for unprocessed PDFs/DJVUs |
| `/literature` | `/literature --convert [FILE]` | Convert PDF/DJVU to markdown with chunking |
| `/literature` | `/literature --validate` | Validate index.json against filesystem |
| `/literature` | `/literature --index FILE` | Add/update index entry for existing markdown file |
```

Missing 2 rows for --search and --task.

**Line 203** also needs updating:
```
| skill-literature | (direct execution) | - | Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json |
```
Should become:
```
| skill-literature | (direct execution) | - | Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json, search/import from Zotero |
```

**Needed changes**:

1. After line 111, add:
   ```
   | `/literature` | `/literature --search "QUERY"` | Search Zotero library and Literature/ index by keyword |
   | `/literature` | `/literature --task N` | Extract task N description as search query |
   ```

2. Update line 203 skill-literature description.

---

### 5. CLAUDE.md — Needs regeneration

**File**: `.claude/CLAUDE.md`

**Current state**: Generated file. The `/literature` command table (lines 116-120) shows the same 5 rows as the core merge-source — the --search and --task rows are missing. No "## Literature Extension" section exists (the literature extension's EXTENSION.md section_id is `extension_literature` which merges into CLAUDE.md, but the section is missing from the current CLAUDE.md).

**How to regenerate**: Run `bash .claude/scripts/merge-claudemd.sh` (or equivalent regeneration command) after updating the merge source. Since CLAUDE.md is auto-generated, after updating `core/merge-sources/claudemd.md` and `extensions/literature/EXTENSION.md`, regeneration will produce the correct CLAUDE.md.

**Needed changes**: Update `core/merge-sources/claudemd.md` (as described in item 4), then regenerate CLAUDE.md.

---

### 6. Cross-Extension References — Lean and Formal

**Checked**: `.claude/extensions/lean/` and `.claude/extensions/formal/`

**Finding**: Neither extension contains any `specs/literature/` path references. They use "literature" conceptually (to mean academic papers/proofs used as source material for formal proof construction). This is a completely different meaning from the `specs/literature/` directory system.

**Status**: No changes needed to lean or formal extension documentation.

---

### 7. Implementation files — Already Fully Updated

**Files that are already correct**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Complete Mode: Search (Steps 1-7) and Mode: Import Pipeline (Steps 8-12) implementations
- `.claude/extensions/literature/commands/literature.md` — --search and --task argument parsing, validation, delegation, and result presentation already documented
- `.claude/extensions/literature/scripts/zotero-search.sh` — Script fully implemented with weighted scoring, 3-tier library path fallback, JSON and pretty output formats
- `.claude/extensions/literature/agents/literature-agent.md` — Description already includes "search/import from Zotero"; execution pattern lists all 7 modes

---

## Decisions

- Lean and formal extensions do NOT need updates — they use "literature" for a different purpose (proof sources, not the `specs/literature/` system)
- The implementation files (SKILL.md, literature.md command, literature-agent.md) are already complete — no re-implementation needed
- The CLAUDE.md "## Literature Extension" section absence may be intentional if the literature extension's EXTENSION.md merge is done at runtime or via the extension picker; the merge target is configured as `section_id: extension_literature` into `.claude/CLAUDE.md`
- CLAUDE.md regeneration approach: update the merge source `claudemd.md` first, then run the merge script

---

## Risks & Mitigations

- **Risk**: Regenerating CLAUDE.md may lose other extension section content if merge script is not idempotent
  - **Mitigation**: Check if merge-claudemd.sh exists before running; if not, update CLAUDE.md directly using the same content as the core merge-source's /literature table
- **Risk**: README.md update may be large and require careful ordering of sections
  - **Mitigation**: Add new "Zotero Search and Import" section after existing "Content-Aware Chunking" section for logical flow

---

## Context Extension Recommendations

This is a meta task — none.

---

## Appendix

### Files Examined

| File | Status |
|------|--------|
| `.claude/extensions/literature/manifest.json` | Already correct (no changes needed) |
| `.claude/extensions/literature/EXTENSION.md` | Partially updated — needs description + 2 command rows + optional workflow section |
| `.claude/extensions/literature/README.md` | Not updated — needs commands, index schema, new Zotero section, artifacts table |
| `.claude/extensions/core/merge-sources/claudemd.md` | Missing 2 command rows + skill-literature description |
| `.claude/CLAUDE.md` | Generated — needs regeneration after claudemd.md update |
| `.claude/extensions/literature/skills/skill-literature/SKILL.md` | Already complete |
| `.claude/extensions/literature/commands/literature.md` | Already complete |
| `.claude/extensions/literature/scripts/zotero-search.sh` | Already complete |
| `.claude/extensions/literature/agents/literature-agent.md` | Already complete |
| `.claude/extensions/lean/` | No changes needed |
| `.claude/extensions/formal/` | No changes needed |

### Change Summary by File

| File | Changes Required | Effort |
|------|-----------------|--------|
| `EXTENSION.md` | Description update, 2 command rows, optional workflow section | Small |
| `README.md` | 2 command rows, Directory Convention update, Index Schema 4 new fields, new Zotero section, Artifacts table update | Medium |
| `core/merge-sources/claudemd.md` | 2 command rows + skill-literature description update | Small |
| `CLAUDE.md` | Regenerate after claudemd.md update (or direct edit 2 command rows + description) | Small |
