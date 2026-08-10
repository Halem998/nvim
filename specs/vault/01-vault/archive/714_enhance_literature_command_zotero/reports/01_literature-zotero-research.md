# Research Report: Task #714

**Task**: 714 - enhance_literature_command_zotero
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:30:00Z
**Effort**: 1 hour
**Dependencies**: Task 711 (zotero-search.sh), Task 710 (LITERATURE_DIR, centralized repo)
**Sources/Inputs**: Codebase exploration of existing command/skill/agent files, zotero-search.sh, literature-retrieve.sh, Literature/ repo index
**Artifacts**: specs/714_enhance_literature_command_zotero/reports/01_literature-zotero-research.md
**Standards**: report-format.md

## Executive Summary

- The current `/literature` command has 5 modes (status, scan, convert, validate, index) defined across `commands/literature.md`, `skills/skill-literature/SKILL.md`, and `agents/literature-agent.md`
- Task 710 has fully implemented `LITERATURE_DIR` env var support and the centralized `~/Projects/Literature/` repo (183 entries, v2 schema with `zotero_key`/`zotero_path`/`project_tags` fields)
- Task 711 has created `zotero-search.sh` which takes query terms, searches `zotero-library.json`, and returns JSON with `citation_key`, `title`, `authors`, `year`, `score`, `pdf_paths`, `abstract_snippet` per result
- The zotero-library.json file does not yet exist at `~/Projects/Literature/` (user needs to configure Better BibTeX export)
- Three new modes need to be added: `--search "query"`, `--task N` (delegating to search), and the import pipeline triggered by interactive selection after search
- The 3 files to update are: `.claude/commands/literature.md`, `.claude/skills/skill-literature/SKILL.md`, `.claude/agents/literature-agent.md`

## Context & Scope

### What was researched

1. **Current command architecture**: `commands/literature.md` handles argument parsing and delegates to `skill-literature`. It currently supports 5 sub-modes dispatched by flag (`--scan`, `--convert`, `--validate`, `--index`, bare).

2. **Current skill implementation**: `skills/skill-literature/SKILL.md` is the full direct-execution implementation. It reads `LITERATURE_DIR` (two-tier fallback), dispatches to mode handlers, and uses `AskUserQuestion` for interactive confirmation.

3. **Zotero search script (task 711)**: `extensions/literature/scripts/zotero-search.sh` accepts query terms as positional args plus `--limit=N` and `--format=json|pretty`. It:
   - Resolves library path via `ZOTERO_LIBRARY` > `$LITERATURE_DIR/zotero-library.json` > `~/Projects/Literature/zotero-library.json`
   - Scores entries by multi-field match (title +3, keyword +2, abstract +1, author +1)
   - Verifies PDF paths exist on disk via a post-pass
   - Returns JSON array with fields: `citation_key`, `title`, `authors`, `year`, `score`, `pdf_paths` (verified), `abstract_snippet`
   - Exits 0 (results), 1 (library not found), 2 (no results)

4. **Centralized repo state**: `~/Projects/Literature/` exists with 183 entries, v2 schema. `zotero_path` is null for all 183 entries (no Zotero paths yet — the zotero-library.json hasn't been configured). The `pdfs/` symlinks directory exists but is empty.

5. **Index schema (v2)**: Each entry has `id`, `bib_key`, `zotero_key`, `zotero_path`, `project_tags`, plus the standard fields. `parent_doc` is present but the field name `parent_doc` is used.

### Key constraint

The `zotero-library.json` does not exist yet (user must configure Better BibTeX export in Zotero), so `zotero-search.sh` will return exit code 1 with setup instructions. The `--search` mode must handle this gracefully, showing the setup instructions to the user.

## Findings

### Codebase Patterns

**Current mode dispatch in `commands/literature.md`** (lines 22-48):
```
Sub-mode dispatch: first match wins
1. No args   -> status
2. --scan    -> scan
3. --convert -> convert + optional FILE
4. --validate -> validate
5. --index   -> index + required FILE
```
Args are passed as `mode={sub_mode} file={file}` to the skill.

**Current skill step 1 arg parsing** (SKILL.md lines 26-43):
```bash
mode=$(echo "$ARGUMENTS" | grep -oP 'mode=\K\S+' | head -1)
file=$(echo "$ARGUMENTS" | grep -oP 'file=\K\S+' | head -1)
```
The arg parsing uses grep `-oP` with `\K` lookbehind. For `--search "multi word query"`, a single `query=` field won't work because the query may have spaces. Need to use a different encoding — e.g., URL-encode the query or pass it as a separate argument with a delimiter.

**Query encoding recommendation**: Pass as `query={base64-encoded-string}` or use `query_raw=` with a known delimiter. The simplest approach that avoids shell quoting issues is to base64-encode the query before passing and decode in the skill. Alternatively, the command can export a temp env variable and the skill reads it. Since both run in the same process, the cleanest approach is to pass `query_b64=$(base64 <<< "query text")` and decode in the skill.

**Alternative simpler approach**: Since the command file and skill are both Claude-executed (not actual shell scripts — they're instruction documents for Claude), the "args" are just text passed to the AI model. Claude can parse `mode=search query=modal logic completeness` directly by treating everything after `query=` as the raw query string. This is more practical.

**Skill step 4 dispatch case statement** (SKILL.md lines 72-84):
```bash
case "$mode" in
  status)   handle_status ;;
  scan)     handle_scan ;;
  convert)  handle_convert ;;
  validate) handle_validate ;;
  index)    handle_index ;;
  *)
    echo "Error: Unknown mode '$mode'..."
    exit 1
    ;;
esac
```
Two new cases needed: `search` and (implicitly `task` which resolves to `search` with a different query source).

**zotero-search.sh output format** (per the script):
```json
[
  {
    "citation_key": "smith2023_proplogic",
    "title": "Propositional Logic: A Modern Introduction",
    "authors": "Smith, Alice",
    "year": 2023,
    "score": 9,
    "pdf_paths": ["/home/benjamin/Zotero/storage/ABCD1234/smith2023.pdf"],
    "abstract_snippet": "This paper introduces..."
  }
]
```

**Literature index entries** (for cross-referencing availability):
Each index entry has `id`, `bib_key` (which maps to `citation_key` in CSL-JSON), `zotero_key`. The lookup to determine "already converted" status is: find any index entry where `bib_key == citation_key` or `zotero_key == citation_key`.

### Proposed Changes for --search Mode Integration

#### 1. `commands/literature.md` Changes

Add two new sub-modes to the dispatch table (before the error fallthrough):
- `--search "QUERY"` -> search mode; query = everything after `--search`
- `--task N` -> task-number mode; read task description from `state.json`, use as query

Updated Sub-Mode Dispatch:
```
1. No arguments          -> status
2. --scan                -> scan
3. --convert [FILE]      -> convert + optional FILE
4. --validate            -> validate
5. --index FILE          -> index + required FILE
6. --search "QUERY"      -> search; query extracted from args
7. --task N              -> task-number mode; N = task number
```

For `--search`: extract the query by removing `--search` from ARGUMENTS and trimming the remaining string.
For `--task N`: extract the integer N, then fetch `description` from `state.json` for task N (using `jq`), and use that as the query.

Pass to skill as: `mode=search query={query text}` (the skill reads everything after `query=` as the raw query).

Add to error handling section:
- Unknown flag -> updated error message listing `--search "QUERY"` and `--task N`
- `--search` without QUERY -> error message
- `--task` without N -> error message
- `--task N` where task N not found -> error message

Add to state management section:
- **Reads**: `specs/state.json` (for --task N query extraction)
- **Reads**: `~/Projects/Literature/zotero-library.json` or `$ZOTERO_LIBRARY` (via zotero-search.sh)

#### 2. `skills/skill-literature/SKILL.md` Changes

**Step 1 arg parsing**: Extend to extract `query` field:
```bash
mode=$(echo "$ARGUMENTS" | grep -oP 'mode=\K\S+' | head -1)
file=$(echo "$ARGUMENTS" | grep -oP 'file=\K\S+' | head -1)
# Extract query: everything after "query=" on the arg string
query=$(echo "$ARGUMENTS" | sed 's/.*query=//')
```

**Step 4 dispatch**: Add `search` case:
```bash
case "$mode" in
  status)   handle_status ;;
  scan)     handle_scan ;;
  convert)  handle_convert ;;
  validate) handle_validate ;;
  index)    handle_index ;;
  search)   handle_search ;;
  *)        echo "Error: Unknown mode"; exit 1 ;;
esac
```

**New Mode: Search** — full handler specification:

```
### Mode: Search

Search Zotero library and existing Literature/ index for entries matching query.

#### Search Step 1: Resolve Zotero script path
Find zotero-search.sh in .claude/extensions/literature/scripts/zotero-search.sh
(or the equivalent installed path — use __dirname-relative lookup).

#### Search Step 2: Run zotero-search.sh
  bash <script_path> --format=json --limit=20 $query_terms
  Capture exit code:
  - Exit 1: library not found -> print setup instructions, exit
  - Exit 2: no results -> inform user, suggest broader terms
  - Exit 0: parse JSON results

#### Search Step 3: Check existing Literature/ index for already-imported entries
  For each Zotero result, check index.json:
    - Is there an entry where bib_key == citation_key OR zotero_key == citation_key?
    - If yes: availability = "already_converted" + path to the markdown
    - If no: check if zotero_path (from pdf_paths) points to an existing file
      - If pdf_paths non-empty: availability = "pdf_available" (can import)
      - If pdf_paths empty: availability = "pdf_not_available"

#### Search Step 4: Also search Literature/ index directly
  Extract keywords from query (same logic as literature-retrieve.sh)
  Search index.json entries by keyword overlap (like scored_entries in literature-retrieve.sh)
  Mark these as "already_converted" with local path info

#### Search Step 5: Build merged, deduplicated result list
  - Merge Zotero results + index-only results
  - Deduplicate by citation_key/bib_key
  - Sort by score descending (Zotero score for Zotero results, keyword score for index-only)

#### Search Step 6: AskUserQuestion — interactive selection
  Present the ranked results with:
    - Index (1, 2, 3...) for multi-select
    - Title (truncated to ~60 chars)
    - Authors (truncated)
    - Year
    - Availability tag: [IMPORTED], [PDF AVAILABLE], [NO PDF]
    - Relevance score
  
  AskUserQuestion with multiSelect=true:
    Options: one per result entry (up to 20), plus "Done - no import" option

#### Search Step 7: Handle selected entries
  For each selected entry:
  - If availability == "already_converted": show "Already imported at {path}, no action needed"
  - If availability == "pdf_available": run import pipeline (Search Steps 8-12)
  - If availability == "pdf_not_available": show "PDF not available — cannot import"

#### Search Steps 8-12: Import Pipeline (for PDF-available entries)
  (See Import Pipeline section below)
```

**New Mode: Import Pipeline** — triggered from search selection:

```
#### Import Step 8: Confirm import for each selected entry
  AskUserQuestion (single-select per entry or batch confirm):
  "Import '{title}' ({year}) by {authors}?"
  Options: ["Yes, import", "Skip this entry"]

#### Import Step 9: Symlink PDF to Literature/ repo
  pdf_src = first valid path from entry.pdf_paths
  lit_dir = $LITERATURE_DIR (or ~/Projects/Literature)
  target_name = "{citation_key}.pdf" (normalized)
  symlink_path = "$lit_dir/pdfs/{target_name}"
  
  Create symlink: ln -s "$pdf_src" "$symlink_path"
  (If symlink already exists, skip with message)

#### Import Step 10: Run convert flow
  Call handle_convert() with file="$symlink_path" (or the resolved path)
  This runs the existing PDF-to-markdown pipeline:
    - pdftotext extraction
    - Content-aware chunking
    - AskUserQuestion for chunk confirmation
    - AskUserQuestion for metadata confirmation
  
  Note: Pre-populate metadata from Zotero data to reduce prompts:
    - authors from entry.authors
    - title from entry.title
    - year from entry.year
    - doc_type = "paper" (default, user can override)
    - source_format = "pdf"

#### Import Step 11: Update index.json with Zotero fields
  After convert writes the entry, update it to add Zotero-specific fields:
    - zotero_key = citation_key
    - zotero_path = original pdf_src path (Zotero storage location)
    - project_tags = [current project name or "nvim"]
    - bib_key = citation_key

#### Import Step 12: Commit to Literature/ repo
  If Literature/ is a git repo:
    cd $LITERATURE_DIR
    git add -A
    git commit -m "import: {title} ({year})"
  
  On git failure: non-blocking, log warning
```

#### 3. `agents/literature-agent.md` Changes

Update the documentation to reflect new modes:

1. **Execution Pattern section**: Add `--search "QUERY"` and `--task N` to the execution flow diagram
2. **Tool Usage table**: Add note that `Bash` now also invokes `zotero-search.sh`
3. **Related Files section**: Add `zotero-search.sh` reference
4. **New section: Zotero Integration**: Document the search-to-import pipeline, availability states, and the zotero-library.json dependency

### AskUserQuestion Interactive Flow Design

The search result selection uses `multiSelect: true` to allow selecting multiple entries for batch import. The option structure should be:

```json
{
  "question": "Found {N} results for '{query}'. Select entries to import (PDF-available) or view (already imported):",
  "header": "Zotero Search Results",
  "multiSelect": true,
  "options": [
    {
      "label": "[IMPORTED] {title} ({year})",
      "description": "Authors: {authors} | Score: {score} | Path: {local_path}"
    },
    {
      "label": "[PDF AVAILABLE] {title} ({year})",
      "description": "Authors: {authors} | Score: {score} | Key: {citation_key}"
    },
    {
      "label": "[NO PDF] {title} ({year})",
      "description": "Authors: {authors} | Score: {score} | PDF not found in Zotero storage"
    },
    {
      "label": "Done - no import",
      "description": "Exit search without importing"
    }
  ]
}
```

After selection, for PDF-available entries not yet imported, trigger the import pipeline sequentially (one entry at a time to handle interactive prompts per convert step).

### Import Pipeline Steps

The import pipeline for a selected Zotero entry:

1. **Resolve PDF path**: Use first valid path from `pdf_paths` (already verified by zotero-search.sh)
2. **Symlink to Literature/pdfs/**: `ln -sf {zotero_pdf_path} $LITERATURE_DIR/pdfs/{citation_key}.pdf`
3. **Pre-populate metadata**: Set `metadata_hint` struct with Zotero-sourced fields (title, authors, year) to skip manual prompts for known fields
4. **Run convert handler**: Call the existing `handle_convert` logic with the PDF path, passing pre-populated metadata to skip those AskUserQuestion prompts
5. **Update index entry**: After convert writes the entry, patch it with `zotero_key`, `zotero_path`, `bib_key`, `project_tags` fields using `jq`
6. **Git commit**: In `$LITERATURE_DIR`, `git add -A && git commit -m "import: {title} ({year})"`

The key insight: the existing `convert` mode already handles PDF-to-markdown conversion with chunking and metadata prompts. For Zotero imports, we pre-populate what we know from Zotero (title, authors, year, doc_type=paper, source_format=pdf) to reduce user prompts to only chunk boundary confirmation and keyword/summary review.

### --task N Mode Implementation

This mode reads the task description from `specs/state.json` and uses it as the search query:

In `commands/literature.md`:
```bash
# --task N mode
if "--task" in $ARGUMENTS:
  sub_mode = "search"
  task_number = extract_arg_after("--task", $ARGUMENTS)
  if not task_number:
    Print error: "--task requires a task number N"
    Exit
  # Read task description from state.json
  task_description = bash: jq -r '.active_projects[] | select(.project_number == {task_number}) | .description' specs/state.json
  if not task_description or task_description == "null":
    Print error: "Task {task_number} not found in state.json"
    Exit
  query = task_description  # Pass full description as query
```

Pass to skill as `mode=search query={task_description}` (skill uses the description directly as query terms for zotero-search.sh).

This is the simplest implementation — the full task description serves as a rich multi-keyword query. zotero-search.sh already handles stop-word filtering and term scoring, so passing the full description works well.

### Integration with zotero-search.sh Output Format

The skill must handle three exit codes from zotero-search.sh:
- **Exit 1** (library not found): Display the setup instructions from stderr. Suggest configuring Better BibTeX export. Offer to show index-only search results as fallback.
- **Exit 2** (no results): Inform user "No Zotero results found for '{query}'". Then proceed to search the local Literature/ index directly (always done in parallel with Zotero search).
- **Exit 0** (success): Parse JSON array. Each element has the fields documented above.

The `pdf_paths` field is already verified (existing files only), so no additional path validation is needed before creating symlinks.

## Decisions

1. **Query passing format**: Pass `mode=search query={raw query text}` to skill; skill parses by taking everything after `query=` as the raw query string. This avoids base64 encoding complexity since Claude handles the "parsing" conceptually.

2. **Search always includes index**: The `--search` mode always searches both Zotero (if available) and the local Literature/index.json. Results are merged and deduplicated. This ensures users see all available materials, not just Zotero entries.

3. **Import pre-populates metadata**: When importing from Zotero, use Zotero metadata to pre-fill convert step metadata prompts. Users still see chunk boundary confirmation and can review/edit keywords/summary.

4. **Git commit in Literature/ repo**: Import commits are atomic per-entry ("import: {title} ({year})"). This keeps the Literature/ repo history clean.

5. **Extension files vs core files**: The `commands/literature.md`, `skills/skill-literature/SKILL.md`, and `agents/literature-agent.md` exist in TWO locations: the core `.claude/` directory and the extension `.claude/extensions/literature/` directory. The extension versions are the authoritative source that gets installed. Implementation must update the extension versions, and then verify that the core copies are also updated (or document the sync mechanism).

6. **Symlink location**: PDFs are symlinked to `$LITERATURE_DIR/pdfs/{citation_key}.pdf` (not a copy). This avoids duplicating large files and follows the design from task 710's Phase 3.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| zotero-library.json not configured | Graceful exit 1 handling in skill; show setup instructions from zotero-search.sh stderr |
| Query with spaces in mode=search args | Skill reads everything after `query=` as raw text; Claude handles string parsing naturally |
| Import PDF path becomes stale (Zotero reorganizes storage) | Symlink breaks silently; validate step can detect broken symlinks |
| Duplicate entry if same paper imported twice | Check index for existing bib_key/zotero_key before importing; show "already imported" status |
| Extension vs core file sync | Task should update both extension source files and verify the installed core files are in sync |
| Literature/ not a git repo | Non-blocking git failure in import; skill logs warning and continues |
| Very long task descriptions (--task N) for query | zotero-search.sh filters stop words and uses top-N terms; long descriptions work fine |

## Context Extension Recommendations

- none (meta task)

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/commands/literature.md` (167 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-literature/SKILL.md` (1052 lines)
- `/home/benjamin/.config/nvim/.claude/agents/literature-agent.md` (131 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/zotero-search.sh` (409 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/literature/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/literature/EXTENSION.md`
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` (235 lines)
- `/home/benjamin/.config/nvim/specs/710_research_centralized_literature_zotero/plans/02_centralized-literature-plan.md`

### Current State of Literature Repo
- Location: `/home/benjamin/Projects/Literature/`
- Entries: 183 (v2 schema)
- zotero_path: null for all entries (no Zotero paths yet)
- pdfs/ directory: empty (no symlinks yet)
- zotero-library.json: does not exist yet

### Key Architecture Insight
The skill-literature SKILL.md files exist in two places:
- Core: `.claude/skills/skill-literature/SKILL.md` (the installed/active version)
- Extension: `.claude/extensions/literature/skills/skill-literature/SKILL.md` (the source/template version)

Similarly for `commands/literature.md` and `agents/literature-agent.md`. The implementation plan should update the extension source files, then sync them to the core location (or update both simultaneously).
