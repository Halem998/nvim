# Implementation Plan: Task #714

- **Task**: 714 - Enhance /literature command with Zotero search and import
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 711 (zotero-search.sh), Task 710 (LITERATURE_DIR, centralized repo)
- **Research Inputs**: specs/714_enhance_literature_command_zotero/reports/01_literature-zotero-research.md
- **Artifacts**: plans/01_literature-zotero-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add Zotero search and import capabilities to the /literature command. This involves adding two new sub-modes (`--search "query"` and `--task N`) to the command dispatcher, implementing a search handler that calls zotero-search.sh and cross-references the Literature/ index, presenting interactive multi-select results via AskUserQuestion, and executing an import pipeline that symlinks PDFs, runs the existing convert flow with pre-populated metadata, and commits to the Literature/ repo. All changes target three existing files (command, skill, agent) in both their extension source and installed core locations.

### Research Integration

The research report identified:
- The existing 5-mode dispatch structure in commands/literature.md and SKILL.md
- zotero-search.sh (task 711) returns JSON with citation_key, title, authors, year, score, pdf_paths, abstract_snippet
- The index v2 schema supports bib_key, zotero_key, zotero_path, project_tags fields
- Query passing via `mode=search query={raw text}` is simplest since Claude handles parsing
- Extension source files and core installed files are identical and both need updating
- zotero-library.json does not yet exist; graceful exit-code-1 handling is required

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Extends the "Literature centralization" roadmap item (Phase 2, completed via task 710) by adding search/import capabilities that leverage the centralized Literature/ repo and Zotero integration infrastructure.

## Goals & Non-Goals

**Goals**:
- Add `--search "query"` mode that searches both Zotero library and Literature/ index
- Add `--task N` mode that extracts task description as search query
- Present interactive multi-select results with availability status tags
- Import pipeline: symlink PDF, run convert with pre-populated Zotero metadata, update index with Zotero fields, commit to Literature/ repo
- Graceful degradation when zotero-library.json is not configured
- Update all three files in both extension and core locations

**Non-Goals**:
- Automatic Zotero library export configuration (user must set up Better BibTeX)
- Full-text search within already-converted markdown files
- Batch import without interactive confirmation
- Changes to zotero-search.sh itself (task 711 scope)
- Changes to the existing 5 modes (status, scan, convert, validate, index)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| zotero-library.json not configured | M | H | Graceful exit-1 handling; show setup instructions from zotero-search.sh stderr; fall back to index-only search |
| Query with spaces breaks arg parsing | H | M | Skill reads everything after `query=` as raw text; Claude handles string parsing naturally |
| Duplicate import of same paper | M | M | Check index for existing bib_key/zotero_key match before importing; show [IMPORTED] tag |
| Extension/core file sync drift | M | L | Update extension source files first, then copy to core location in same phase |
| Broken PDF symlinks after Zotero storage reorganization | L | L | Validate mode can detect broken symlinks; non-blocking for initial implementation |
| Very long task descriptions via --task N | L | M | zotero-search.sh handles stop-word filtering and term scoring internally |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Command Dispatcher -- Add --search and --task N sub-modes [COMPLETED]

**Goal**: Extend the /literature command file to parse the two new flags and delegate to the skill with appropriate arguments.

**Tasks**:
- [x] Update frontmatter `argument-hint` to include `--search "QUERY"` and `--task N` *(completed)*
- [x] Add `--search` and `--task` to the sub-mode dispatch table (items 6 and 7) *(completed)*
- [x] Implement `--search` parsing: extract query text (everything after `--search`) *(completed)*
- [x] Implement `--task N` parsing: extract task number, read description from specs/state.json via jq, use description as query *(completed)*
- [x] Add validation: `--search` without query text produces error; `--task` without N produces error; `--task N` where task not found produces error *(completed)*
- [x] Pass to skill as `mode=search query={query text}` for both modes *(completed)*
- [x] Add `--search` and `--task N` to the error-handling unknown-flag message *(completed)*
- [x] Add state management reads: `specs/state.json` (for --task N), `zotero-library.json` (via zotero-search.sh) *(completed)*
- [x] Update BOTH files: `.claude/extensions/literature/commands/literature.md` (source) and `.claude/commands/literature.md` (installed) *(completed: symlink auto-syncs)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/commands/literature.md` - Add --search and --task N sub-modes (extension source)
- `.claude/commands/literature.md` - Mirror identical changes (installed copy)

**Verification**:
- Read both files and confirm sub-mode dispatch table has 7 entries (status, scan, convert, validate, index, search, task)
- Confirm error handling covers --search without query and --task without N
- Confirm both extension and core files are identical

---

### Phase 2: Skill Search Handler -- Implement search mode with Zotero and index lookup [COMPLETED]

**Goal**: Add the full search handler to SKILL.md: invoke zotero-search.sh, cross-reference the Literature/ index, merge/deduplicate results, and present interactive multi-select via AskUserQuestion.

**Tasks**:
- [x] Extend Step 1 arg parsing to extract `query` field (everything after `query=` in ARGUMENTS) *(completed)*
- [x] Add `search` case to Step 4 dispatch *(completed)*
- [x] Implement Search Step 1: Resolve zotero-search.sh path (relative to `.claude/extensions/literature/scripts/`) *(completed)*
- [x] Implement Search Step 2: Run zotero-search.sh with `--format=json --limit=20 $query_terms`; handle exit codes 0 (success), 1 (library not found -- show setup instructions), 2 (no results) *(completed)*
- [x] Implement Search Step 3: For each Zotero result, check Literature/ index.json for existing entry (match on bib_key == citation_key OR zotero_key == citation_key); classify as "already_converted", "pdf_available", or "pdf_not_available" *(completed)*
- [x] Implement Search Step 4: Also search Literature/ index.json directly by keyword overlap with query terms (like literature-retrieve.sh scoring); mark index-only matches as "already_converted" *(completed)*
- [x] Implement Search Step 5: Merge Zotero + index-only results, deduplicate by citation_key/bib_key, sort by score descending *(completed)*
- [x] Implement Search Step 6: Present results via AskUserQuestion with multiSelect=true; each option shows `[IMPORTED]`, `[PDF AVAILABLE]`, or `[NO PDF]` tag with title, authors, year, score; include "Done -- no import" escape option *(completed)*
- [x] Implement Search Step 7: Route selected entries -- already_converted shows path info, pdf_available triggers import pipeline (Phase 3), pdf_not_available shows message *(completed)*
- [x] Handle edge case: if both Zotero search fails (exit 1) and index has entries, show index-only results *(completed)*
- [x] Update BOTH files: `.claude/extensions/literature/skills/skill-literature/SKILL.md` (source) and `.claude/skills/skill-literature/SKILL.md` (installed) *(completed: hardlink auto-syncs)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - Add search mode handler (extension source)
- `.claude/skills/skill-literature/SKILL.md` - Mirror identical changes (installed copy)

**Verification**:
- Confirm SKILL.md dispatch case includes `search)` handler
- Confirm all 7 search steps are documented with expected behavior for each zotero-search.sh exit code
- Confirm AskUserQuestion multi-select format matches the pattern from the research report
- Confirm both extension and core files are identical

---

### Phase 3: Import Pipeline -- Symlink, convert, index update, git commit [COMPLETED]

**Goal**: Add the import pipeline triggered from search selection for PDF-available entries: symlink PDF to Literature/ repo, run convert flow with pre-populated Zotero metadata, update index with Zotero-specific fields, and commit to Literature/ repo.

**Tasks**:
- [x] Implement Import Step 8: Optional confirmation AskUserQuestion per entry (or batch confirm for multiple) *(completed)*
- [x] Implement Import Step 9: Create symlink from Zotero PDF path to `$LITERATURE_DIR/pdfs/{citation_key}.pdf`; skip if symlink already exists *(completed)*
- [x] Implement Import Step 10: Call existing handle_convert() with symlinked file path; pre-populate metadata from Zotero data (title, authors, year, doc_type=paper, source_format=pdf) to reduce user prompts *(completed)*
- [x] Implement Import Step 11: After convert writes index entry, patch it with Zotero-specific fields via jq: zotero_key, zotero_path, bib_key, project_tags *(completed)*
- [x] Implement Import Step 12: Git commit in $LITERATURE_DIR with message "import: {title} ({year})"; non-blocking on git failure *(completed)*
- [x] Document that import processes entries sequentially (one at a time for interactive convert prompts) *(completed)*
- [x] Update BOTH SKILL.md files (extension source and installed copy) *(completed: hardlink auto-syncs)*

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - Add import pipeline steps 8-12 (extension source)
- `.claude/skills/skill-literature/SKILL.md` - Mirror identical changes (installed copy)

**Verification**:
- Confirm import pipeline steps 8-12 are present after search steps
- Confirm symlink creation uses `$LITERATURE_DIR/pdfs/{citation_key}.pdf` path
- Confirm Zotero metadata pre-population is documented (title, authors, year, doc_type, source_format)
- Confirm index.json patch adds zotero_key, zotero_path, bib_key, project_tags
- Confirm git commit is non-blocking on failure
- Confirm both extension and core files are identical

---

### Phase 4: Agent Documentation and Manifest Update [COMPLETED]

**Goal**: Update the literature-agent.md documentation to reflect the new search/import modes, and update manifest.json if needed.

**Tasks**:
- [x] Update literature-agent.md execution pattern diagram to include --search and --task N modes *(completed)*
- [x] Add search and import flow branches to the architecture diagram *(completed)*
- [x] Update Tool Usage table: note that Bash now also invokes zotero-search.sh and creates symlinks *(completed)*
- [x] Add new section "Zotero Integration" documenting: search-to-import pipeline overview, availability states (IMPORTED/PDF AVAILABLE/NO PDF), zotero-library.json dependency, graceful degradation *(completed)*
- [x] Update Related Files section to include zotero-search.sh reference *(completed)*
- [x] Update both agent files: `.claude/extensions/literature/agents/literature-agent.md` (source) and `.claude/agents/literature-agent.md` (installed) *(completed: symlink auto-syncs)*
- [x] Update manifest.json `description` field if needed to mention Zotero search *(completed)*
- [x] Verify all 6 modified files (2 commands, 2 skills, 2 agents) are in sync between extension and core *(completed: all IDENTICAL)*

**Timing**: 0.25 hours

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/literature/agents/literature-agent.md` - Update documentation (extension source)
- `.claude/agents/literature-agent.md` - Mirror identical changes (installed copy)
- `.claude/extensions/literature/manifest.json` - Update description if needed

**Verification**:
- Confirm agent documentation mentions --search and --task N modes
- Confirm Zotero Integration section exists with pipeline overview
- Confirm all extension source files match their installed core copies
- Run `diff .claude/extensions/literature/commands/literature.md .claude/commands/literature.md` to verify sync
- Run `diff .claude/extensions/literature/skills/skill-literature/SKILL.md .claude/skills/skill-literature/SKILL.md` to verify sync
- Run `diff .claude/extensions/literature/agents/literature-agent.md .claude/agents/literature-agent.md` to verify sync

## Testing & Validation

- [ ] Read all 6 modified files and confirm consistent content between extension source and core installed copies
- [ ] Verify command dispatcher handles: bare `/literature`, `--search "modal logic"`, `--task 714`, `--search` (no query error), `--task` (no N error)
- [ ] Verify SKILL.md search handler documents all 3 zotero-search.sh exit codes (0, 1, 2)
- [ ] Verify AskUserQuestion multi-select format with availability tags
- [ ] Verify import pipeline documents symlink creation, metadata pre-population, index patching, and git commit
- [ ] Verify agent documentation reflects all 7 modes (status, scan, convert, validate, index, search, task-search)

## Artifacts & Outputs

- `specs/714_enhance_literature_command_zotero/plans/01_literature-zotero-plan.md` (this file)
- Modified files (6 total):
  - `.claude/extensions/literature/commands/literature.md` (extension source)
  - `.claude/commands/literature.md` (installed copy)
  - `.claude/extensions/literature/skills/skill-literature/SKILL.md` (extension source)
  - `.claude/skills/skill-literature/SKILL.md` (installed copy)
  - `.claude/extensions/literature/agents/literature-agent.md` (extension source)
  - `.claude/agents/literature-agent.md` (installed copy)
  - `.claude/extensions/literature/manifest.json` (optional description update)

## Rollback/Contingency

All changes are to markdown instruction files and one JSON manifest. Reverting is straightforward via `git checkout` on the 6-7 files. No runtime code, no database migrations, no state.json schema changes. The existing 5 modes remain completely unmodified, so rollback has zero impact on current functionality.
