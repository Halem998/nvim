# Research Report: Task #721 (Round 2) — Global-Local Literature Workflow Design

**Task**: 721 - Design targeted literature retrieval
**Started**: 2026-06-15
**Completed**: 2026-06-15
**Focus**: Literature/ as global markdown repo with local specs/literature/ copies
**Sources**: Codebase analysis, existing implementation review

## Executive Summary

- Literature/ at `~/Projects/Literature/` already functions as a 183-entry global markdown repo with v2 schema, git tracking, and `LITERATURE_DIR` env var support
- BimodalLogic has been fully migrated; cslib has 76 local entries (70 not yet in global) and `LITERATURE_DIR` is NOT configured there
- The current system lacks ergonomic commands for the key workflows: pulling entries from global to local, pushing locally-created entries to global, and creating new entries directly in global
- The `--lit` flag currently reads from ONE tier (global if `LITERATURE_DIR` set, local fallback) but NOT both merged, which means a project using local-only entries misses global content
- Proposed 5 new `/literature` sub-modes and 2 scripts to close the workflow gaps

## Current State Analysis

### What Exists Today

**Global tier** (`~/Projects/Literature/`):
- 183 entries in index.json (v2 schema)
- Rich metadata: bib_key, zotero_key, project_tags, doc_type, etc.
- Git-tracked repo with `.gitignore` for PDFs/DJVUs
- `pdfs/` directory for symlinks to Zotero storage
- `scripts/migrate-from-repo.sh` for one-time bulk migration
- `zotero-library.json` (Zotero Better BibTeX CSL-JSON auto-export, gitignored)

**Per-project tier** (`specs/literature/`):
- BimodalLogic: 30 entries, fully migrated, `DEPRECATED.md` present, `LITERATURE_DIR` NOT set in project settings
- cslib: 76 entries (70 not yet in global!), `LITERATURE_DIR` NOT set
- nvim (this repo): No `specs/literature/` directory exists

**literature-retrieve.sh** (the `--lit` implementation):
- Two-tier fallback: uses `LITERATURE_DIR` if set and exists, else falls back to per-project `specs/literature/`
- Reads from exactly ONE tier (not both merged)
- Keyword scoring from index.json entries[] with summary bonus
- 8,000-token budget, max 10 files, min score 1

**skill-literature** (SKILL.md):
- 6 modes: status, scan, convert, validate, index, search
- Two-tier directory resolution via `LITERATURE_DIR` env var
- Search mode integrates zotero-search.sh with Literature/ index cross-reference
- Import pipeline: symlink PDF, convert, patch index with Zotero fields, git commit

**zotero-search.sh**:
- 3-tier library path resolution: `ZOTERO_LIBRARY` > `$LITERATURE_DIR/zotero-library.json` > `~/Projects/Literature/zotero-library.json`
- Weighted scoring: title (+3), keyword (+2), abstract (+1), author (+1)
- JSON and pretty output formats, PDF path verification

### Critical Gaps

1. **No global-to-local copy workflow**: No command to pull entries from Literature/ into a project's `specs/literature/`
2. **No local-to-global push workflow**: If a researcher creates a literature summary during task work, there is no way to promote it to Literature/
3. **No "create new entry in global" workflow**: Adding a new manually-written summary to Literature/ requires manual file creation + `/literature --index`
4. **`--lit` reads one tier only**: A project with `LITERATURE_DIR` set never sees its own local-only entries; a project without it never sees global entries
5. **cslib has 70 unmigrated entries**: The `migrate-from-repo.sh` script exists but has not been run for cslib
6. **`LITERATURE_DIR` not configured in BimodalLogic/cslib**: These projects fall back to local-only, missing global entries
7. **No way to list available entries interactively**: `/literature --search` requires Zotero, no simple catalog browse

## Proposed Two-Tier Architecture

### Design Principles

1. **Literature/ = complete global library** (all markdown sources, full index, git-tracked)
2. **specs/literature/ = project-local working set** (subset of global + project-specific notes, committed with project)
3. **Hard copies, not symlinks**: Local copies are independent files (symlinks break across machines, git doesn't track them)
4. **Index referencing**: Local index entries include `global_id` field to track provenance from global
5. **`--lit` merges both tiers**: Deduplicate by id, local entries take precedence (may have project-specific annotations)

### Tier Resolution for `--lit`

Current behavior (literature-retrieve.sh):
```
if LITERATURE_DIR set and exists -> use it (ignore local)
else -> use specs/literature/ (ignore global)
```

Proposed behavior:
```
merged_pool = []
if specs/literature/index.json exists -> add local entries
if LITERATURE_DIR set and exists -> add global entries (skip duplicates by id)
score merged_pool against task description
inject within token budget
```

This means:
- A project with both tiers gets the union (local-first dedup)
- A project with only global gets global entries
- A project with only local gets local entries (backward compatible)
- Local entries can override global (e.g., annotated version of a paper)

## Proposed Commands and Workflows

### New Command: `/literature --pull "query"`

**Purpose**: Copy matching entries from Literature/ (global) into specs/literature/ (local).

**Workflow**:
1. Search global Literature/index.json using query terms (keyword scoring)
2. Also search via zotero-search.sh if available (cross-reference to global index)
3. Present multi-select results with AskUserQuestion showing:
   - `[LOCAL]` entries already in specs/literature/
   - `[GLOBAL]` entries available to pull
   - Title, authors, year, token_count for each
4. For selected entries:
   a. Copy markdown file(s) from `$LITERATURE_DIR/{path}` to `specs/literature/{path}`
   b. Copy subdirectory if entry is a chapter (preserve structure)
   c. Add/update entry in local `specs/literature/index.json` with `global_id` field
   d. Create `specs/literature/index.json` if it does not exist
5. Display summary of pulled entries

**Script**: `.claude/extensions/literature/scripts/literature-pull.sh`

**Command syntax**:
```
/literature --pull "modal logic correspondence"
/literature --pull --project BimodalLogic   # pull all entries tagged for a project
/literature --pull --all                    # pull everything (full local mirror)
```

### New Command: `/literature --push [FILE]`

**Purpose**: Promote locally-created entries from specs/literature/ to Literature/ (global).

**Workflow**:
1. If FILE specified: push that single file
2. If no FILE: scan specs/literature/ for entries not present in global (entries without `global_id` or with `global_id: null`)
3. Present multi-select of pushable entries
4. For each selected entry:
   a. Copy markdown file to `$LITERATURE_DIR/{path}`
   b. Copy subdirectory if chunked
   c. Add entry to global `$LITERATURE_DIR/index.json`
   d. Add `project_tags` to global entry (current project name)
   e. Update local entry with `global_id` to mark as synced
   f. Git commit in `$LITERATURE_DIR` (non-blocking)
5. Display summary

**Script**: `.claude/extensions/literature/scripts/literature-push.sh`

### New Command: `/literature --new "Title"`

**Purpose**: Create a new literature entry interactively (in global Literature/ by default, or local with `--local` flag).

**Workflow**:
1. Parse title from arguments
2. Prompt for metadata via AskUserQuestion sequence:
   - Authors (comma-separated)
   - Year
   - Document type (paper/book/chapter/section/notes)
   - Keywords (comma-separated)
   - Summary (one sentence)
   - Optionally: bib_key for Zotero cross-reference
3. Create markdown file with frontmatter header:
   ```markdown
   # {Title}
   
   **Authors**: {authors}
   **Year**: {year}
   
   ## Summary
   
   {user writes content here}
   ```
4. Open in editor context (or write stub for user to fill in)
5. Update index.json in target directory
6. Git commit if global (non-blocking)

**Flags**:
```
/literature --new "Sahlqvist Correspondence"              # creates in global
/literature --new --local "Project-Specific Notes"         # creates in specs/literature/
```

### New Command: `/literature --sync`

**Purpose**: Reconcile local and global indexes bidirectionally.

**Workflow**:
1. Read both indexes (local specs/literature/index.json and global $LITERATURE_DIR/index.json)
2. Identify:
   - Local entries not in global (candidates for push)
   - Global entries not in local (available for pull)
   - Entries in both but with different metadata (candidates for update)
   - Entries in both with matching metadata (in sync)
3. Present status report:
   ```
   ## Literature Sync Status
   
   **Local**: specs/literature/ (30 entries)
   **Global**: ~/Projects/Literature/ (183 entries)
   
   ### In Sync: 28 entries
   ### Push Candidates: 2 entries (local-only)
   - my_local_notes.md (5,200 tokens)
   - project_summary.md (3,100 tokens)
   
   ### Pull Available: 153 entries (global-only)
   ### Metadata Drift: 1 entry
   - burgess_1982: local keywords differ from global
   ```
4. Offer interactive actions: pull all, push all, selective pull/push

### New Command: `/literature --catalog [query]`

**Purpose**: Browse the full catalog of available entries (global + local merged) without requiring Zotero.

**Workflow**:
1. Merge global and local index entries (deduplicate by id)
2. If query provided: filter by keyword overlap
3. If no query: show paginated list sorted by year (most recent first)
4. Display format:
   ```
   ## Literature Catalog (183 global + 2 local-only = 185 total)
   
   | # | ID | Title | Authors | Year | Tokens | Location |
   |---|-----|-------|---------|------|--------|----------|
   | 1 | burgess_1982_i | Axioms for Tense Logic I | Burgess | 1982 | 5,437 | global+local |
   | 2 | my_notes | Project Notes | - | 2026 | 3,100 | local-only |
   ...
   ```
5. Optionally: select entries to pull locally or view details

### Updated Existing Commands

**`/literature` (bare, status mode)**: Add global tier info to health report:
```
## Literature Status

**Global**: ~/Projects/Literature/ (183 entries, 1.3M total tokens)
**Local**: specs/literature/ (30 entries, 245K total tokens)
**Sync**: 28 in-sync, 2 local-only, 153 global-only

**Token Budget**: 8,000 tokens per injection
```

**`/literature --search "query"`**: Already searches both Zotero and local index. Should also search global index when `LITERATURE_DIR` is set. Currently the search mode in SKILL.md resolves `lit_dir` to ONE directory; it should search both.

**`/literature --convert [FILE]`**: After conversion, prompt user: "Also push to global Literature/?" If yes, run push workflow for the converted entry.

**`/literature --index FILE`**: After indexing, prompt: "Also push to global Literature/?" if the file is in `specs/literature/`.

## Integration with `--lit` Injection

### Merged Retrieval (literature-retrieve.sh changes)

The key change to `literature-retrieve.sh` is merging both tiers:

```bash
# Current: resolve to ONE directory
LIT_DIR="$LITERATURE_DIR or $DEFAULT_LIT_DIR"

# Proposed: collect entries from BOTH directories
local_entries=[]
global_entries=[]

if [ -f "$DEFAULT_LIT_DIR/index.json" ]; then
  local_entries = read local index
fi

if [ -n "$LITERATURE_DIR" ] && [ -d "$LITERATURE_DIR" ] && [ -f "$LITERATURE_DIR/index.json" ]; then
  global_entries = read global index
fi

# Merge: local entries take precedence (by id dedup)
all_entries = merge(local_entries, global_entries, dedup_by=id, priority=local)

# Score and select within budget as before
```

For file content resolution, each entry needs to know which directory it came from:
- Local entries: read from `specs/literature/{path}`
- Global entries: read from `$LITERATURE_DIR/{path}`

### Token Budget Considerations

The current 8,000-token budget is extremely tight (round 1 finding: only 1-2 entries fit). With merged tiers, the budget stays the same but the candidate pool is larger, which means better scoring leads to better top-K selection. This is a net positive without budget changes.

### Task-Type Filtering

Round 1 identified that a "neovim" task with "modal" in its description will match modal logic papers. The merged retrieval should add task-type awareness:
- If `task_type` is `neovim`, `nix`, `web`, etc.: suppress Literature/ injection entirely (these task types never need academic literature)
- If `task_type` is `lean4`, `general`, `meta`: allow Literature/ injection
- Could use `project_tags` to prefer entries tagged for the current project

## Integration with Zotero

### Existing Integration

zotero-search.sh provides rich metadata (878 entries with abstracts) but no markdown content. The `/literature --search` command already cross-references Zotero results with Literature/ index entries and supports importing (symlink PDF, convert, index).

### Proposed Enhancement

The `--pull` command can optionally accept a Zotero citation key:
```
/literature --pull --zotero "Burgess1982I"
```

This would:
1. Look up the citation key in global Literature/index.json via `bib_key` field
2. If found: pull the markdown entry to local
3. If not found in Literature/ but found in Zotero: offer to import (existing import pipeline)

This creates a seamless flow: Zotero -> global Literature/ -> local specs/literature/.

## Recommended Implementation Approach

### Phase 1: Merged Retrieval (Highest impact, moderate effort)

**Files to modify**:
- `.claude/scripts/literature-retrieve.sh` — merge both tiers instead of fallback

**Estimated effort**: 4-6 hours

**Impact**: Immediately improves `--lit` for all projects. Projects with `LITERATURE_DIR` set now see both global and local entries.

### Phase 2: Pull Command (Highest ergonomic value)

**Files to create**:
- `.claude/extensions/literature/scripts/literature-pull.sh`

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` — add pull mode handler
- `.claude/commands/literature.md` — add `--pull` to argument parsing

**Estimated effort**: 6-8 hours

**Impact**: Enables the primary workflow: "I need paper X for this project, let me grab it from Literature/."

### Phase 3: Push Command + New Entry

**Files to create**:
- `.claude/extensions/literature/scripts/literature-push.sh`

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` — add push and new mode handlers
- `.claude/commands/literature.md` — add `--push` and `--new` to argument parsing

**Estimated effort**: 8-10 hours

**Impact**: Closes the bidirectional workflow. Locally-created literature can be promoted to global.

### Phase 4: Sync and Catalog

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` — add sync and catalog mode handlers
- `.claude/commands/literature.md` — add `--sync` and `--catalog`

**Estimated effort**: 4-6 hours

**Impact**: Quality-of-life: status visibility and browsing.

### Phase 5: Cross-Project LITERATURE_DIR Propagation

**Files to modify** (in other projects):
- `~/Projects/BimodalLogic/.claude/settings.json` — add `LITERATURE_DIR`
- `~/Projects/cslib/.claude/settings.json` — add `LITERATURE_DIR`

**Additional**: Run `migrate-from-repo.sh` for cslib (70 entries need migration).

**Estimated effort**: 1-2 hours

**Impact**: Unblocks merged retrieval for all active projects.

## Design Decisions

1. **Hard copies over symlinks**: Symlinks break across machines, are not tracked by git, and create confusion when the global repo is unavailable. Hard copies are more robust and allow local annotation.

2. **`global_id` provenance field**: Local index entries gain a `global_id` field pointing to the corresponding global entry's `id`. This enables sync detection without path comparison.

3. **Local-first dedup in merged retrieval**: When both tiers have an entry with the same id, the local copy wins. This allows projects to maintain annotated or customized versions.

4. **No automatic sync**: Push and pull are explicit user actions. Automatic sync risks overwriting local annotations or flooding global with project-specific notes.

5. **Global is the canonical source**: New entries should default to global. Local-only entries are for project-specific content that doesn't belong in the shared library.

6. **Backward compatibility**: Projects without `LITERATURE_DIR` continue to work exactly as before (local-only). The merged retrieval only adds global entries when the env var is set.

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Duplicate files wasting disk space | Hard copies are necessary for portability; token counts are metadata-only overhead |
| Index drift between local and global | `--sync` command provides visibility; `global_id` enables drift detection |
| cslib's 70 unmigrated entries | Run `migrate-from-repo.sh` before implementing merged retrieval |
| Token budget still too small | This design doesn't change the budget; the round 1 recommendations (Tier 0-3) address scoring improvements |
| Zotero dependency for import | All pull/push/new commands work without Zotero; Zotero only enhances search |

## Appendix

### Search Queries Used
- Codebase exploration: `literature-retrieve.sh`, `SKILL.md`, `zotero-search.sh`, `literature.md`, `manifest.json`
- Cross-project comparison: BimodalLogic and cslib `specs/literature/` directories
- Global Literature/ structure: `index.json`, `README.md`, `migrate-from-repo.sh`

### File Inventory

| File | Purpose | Lines |
|------|---------|-------|
| `.claude/scripts/literature-retrieve.sh` | `--lit` injection engine | 234 |
| `.claude/skills/skill-literature/SKILL.md` | Literature skill (6 modes) | 1490 |
| `.claude/commands/literature.md` | Command argument parser | 211 |
| `.claude/extensions/literature/scripts/zotero-search.sh` | Zotero CSL-JSON search | 409 |
| `.claude/extensions/literature/manifest.json` | Extension manifest | 32 |
| `~/Projects/Literature/scripts/migrate-from-repo.sh` | Bulk migration script | 343 |
| `~/Projects/Literature/index.json` | Global index (183 entries) | ~5000 |
| `~/Projects/Literature/README.md` | Architecture docs | 80 |
