# Implementation Plan: Task #751

- **Task**: 751 - Implement Zotero search and local index management
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: Task 749 (skeleton, completed), Task 750 (CLI wrappers, completed)
- **Research Inputs**: specs/751_implement_zotero_search_local_index/reports/01_search-index-research.md
- **Artifacts**: plans/01_search-index-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement the three Category C index management scripts (`zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-search-index.sh`) and wire the `--task N` mode into the `/zotero` command and SKILL.md. These scripts operate on `specs/zotero-index.json` to add, remove, and search items in the per-repo relevance index. The scoring algorithm from the architecture design (Section 6) drives the search implementation. All three scripts depend on the existing `zotero-read.sh` (task 750) for Zotero library access and follow the established path resolution and exit code conventions.

### Research Integration

Key findings from the research report (01_search-index-research.md):
- SKILL.md dispatch is already wired for add/remove/search/sync/validate modes; the `if [ ! -x "$script" ]` guards will pass once scripts are made executable
- The `zotero-read.sh` wrapper strips the `{ok, data, meta}` envelope and emits `.data` directly, so downstream scripts receive clean item JSON
- The scoring algorithm jq pseudocode from Section 6 of the arch design is directly implementable
- The `--task N` mode is the only gap requiring additions to both `zotero.md` (command file) and SKILL.md (skill file)
- Stop word list and relevance keyword extraction logic are fully specified in the arch design
- Zotero uses `.creators` array with `{creatorType, firstName, lastName}` format (not `{family, given}`)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly reference this task. This task is part of the Zotero extension chain (749 -> 750 -> 751 -> 752 -> 753) and advances the overall Zotero integration infrastructure.

## Goals & Non-Goals

**Goals**:
- Implement `zotero-index-add.sh` with full 20-field entry construction via metadata extraction from `zotero-read.sh`
- Implement `zotero-index-remove.sh` with key lookup, entry deletion, and optional chunk directory cleanup
- Implement `zotero-search-index.sh` with multi-field weighted scoring, stop-word filtering, availability tags, and Zotero library fallback
- Wire `--task N` mode into command file and SKILL.md for task-description-as-search-query
- Follow established exit code discipline (0=success, 1=runtime error, 2=not configured)

**Non-Goals**:
- Implementing `zotero-chunk.sh` (task 752) -- the `--chunk` flag in add script will call it but gracefully handle exit 2
- Implementing `zotero-retrieve.sh` (task 753) -- the scoring algorithm is shared but retrieve has its own threshold and token budget logic
- Modifying `zotero-read.sh` or `zotero-setup.sh` (task 750, already completed)
- Interactive `AskUserQuestion` flow for search mode add-to-index prompting (SKILL.md already scaffolds this; full interactive wiring is deferred)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `zot --json read KEY` field names differ from assumptions | M | M | Use `// empty` and `// []` jq fallbacks; document actual structure on first empirical run |
| Zotero creator format not `{firstName, lastName}` | M | L | Use flexible jq extraction with `try` patterns; handle both CSL and Zotero native formats |
| jq `!=` escaping issue (Claude Code #1132) | M | M | Use `select(.x == "y" \| not)` pattern exclusively; never use `!=` |
| `--task N` mode: state.json has no `description` field for some tasks | L | M | Fall back to `project_name` slug converted to space-separated words |
| Large jq scoring expression fails on edge cases | L | L | Test with empty entries array, null fields, and single-entry index |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement zotero-index-add.sh [NOT STARTED]

**Goal**: Replace the stub with a fully functional script that extracts metadata from Zotero via `zotero-read.sh item KEY`, constructs a 20-field JSON entry, and upserts it into `specs/zotero-index.json`.

**Tasks**:
- [ ] Add path resolution boilerplate (`SCRIPT_DIR`, `PROJECT_ROOT`, `ZOTERO_INDEX`)
- [ ] Add argument parsing for `<zotero_key>` and `--chunk` flag
- [ ] Add precondition checks: `specs/zotero-index.json` exists (exit 2 if not), jq available
- [ ] Call `bash "$SCRIPT_DIR/zotero-read.sh" item "$KEY"` and capture item JSON
- [ ] Extract core fields: `title`, `year` (scan for 4-digit year), `item_type`, `abstract_snippet` (first 300 chars), `citation_key` (from `.citationKey` or `.citekey` with fallback to constructed key)
- [ ] Extract `authors` array: iterate `.creators[]` where `creatorType == "author"`, format as `"lastName, firstName"`
- [ ] Extract `keywords` and `tags` from `.tags[]` array (split by convention or use same source)
- [ ] Extract `collections` array from item metadata
- [ ] Resolve PDF: check `.attachments[]` for `contentType == "application/pdf"`, extract `path`, set `has_pdf` boolean
- [ ] Build `relevance_keywords` from title + keywords (tokenize, lowercase, stop-word filter, length > 3)
- [ ] Optionally fetch notes: call `zotero-read.sh note "$KEY"`, extract first 200 chars as `notes_summary`
- [ ] Build complete 20-field entry JSON using `jq -n` with `--arg` / `--argjson` for each field
- [ ] Implement upsert logic: check if `zotero_key` exists in index, update-in-place or append
- [ ] Update `last_updated` timestamp in index top-level fields
- [ ] Handle `--chunk` flag: if passed and `has_pdf=true`, call `zotero-chunk.sh "$KEY"` (graceful exit 2 handling)
- [ ] Make script executable (`chmod +x`)
- [ ] Verify with `bash -n` syntax check

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-index-add.sh` - Replace stub with full implementation

**Verification**:
- `bash -n .claude/extensions/zotero/scripts/zotero-index-add.sh` passes with no syntax errors
- Script is executable (`-x` test passes)
- Script exits 2 when `specs/zotero-index.json` is missing
- Script handles all 20 index entry fields with safe jq fallbacks

---

### Phase 2: Implement zotero-index-remove.sh [NOT STARTED]

**Goal**: Replace the stub with a functional script that removes entries from `specs/zotero-index.json` by zotero_key and optionally deletes associated chunk directories.

**Tasks**:
- [ ] Add path resolution boilerplate (`SCRIPT_DIR`, `PROJECT_ROOT`, `ZOTERO_INDEX`)
- [ ] Add argument parsing for `<zotero_key>` and `--delete-chunks` flag
- [ ] Add precondition checks: `specs/zotero-index.json` exists (exit 2 if not)
- [ ] Look up entry by `zotero_key` using jq; exit 1 if not found
- [ ] If `--delete-chunks` and entry has non-null `chunk_dir`: `rm -rf "$PROJECT_ROOT/$chunk_dir"`
- [ ] Remove entry from `.entries` array using `jq --arg k "$KEY" 'del(.entries[] | select(.zotero_key == $k))'`
- [ ] Update `last_updated` timestamp
- [ ] Write updated JSON atomically (read-transform-write pattern)
- [ ] Print confirmation message with citation key and title
- [ ] Make script executable (`chmod +x`)
- [ ] Verify with `bash -n` syntax check

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-index-remove.sh` - Replace stub with full implementation

**Verification**:
- `bash -n .claude/extensions/zotero/scripts/zotero-index-remove.sh` passes with no syntax errors
- Script is executable
- Script exits 1 for key not found, exits 2 for missing index file

---

### Phase 3: Implement zotero-search-index.sh [NOT STARTED]

**Goal**: Replace the stub with a search script that scores per-repo index entries using the multi-field weighted algorithm from Section 6 of the architecture design, with pretty-print output including availability tags and a fallback to full Zotero library search.

**Tasks**:
- [ ] Add path resolution boilerplate (`SCRIPT_DIR`, `PROJECT_ROOT`, `ZOTERO_INDEX`)
- [ ] Add argument parsing for `"query string"`, `--limit N` (default 10), `--format json|pretty` (default pretty)
- [ ] Validate query is non-empty (exit 1 if empty)
- [ ] Implement query term extraction: tokenize on whitespace/punctuation, lowercase, filter stop words (full list from arch design Section 6), filter length <= 3
- [ ] Build JSON array of query terms for jq processing
- [ ] Implement scoring jq expression from arch design pseudocode:
  - `title_score * 4` (count unique terms appearing in title, case-insensitive)
  - `tag_score * 3` (per tag, partial/full match against any query term)
  - `abstract_score * 2` (unique terms in abstract_snippet)
  - `keyword_score * 2` (per keyword entry matching)
  - `collection_score * 1` (binary per collection containing term)
  - `notes_score * 1` (unique terms in notes_summary)
- [ ] Filter results by `total_score >= 1` threshold
- [ ] Sort by score descending, limit to N results
- [ ] Implement `--format json` output: JSON array of scored entries with `_score` field
- [ ] Implement `--format pretty` output: formatted table with columns `SCORE | KEY | TITLE | YEAR | STATUS`
- [ ] Implement availability tag column: `[HAS MARKDOWN]` (has_chunks=true), `[PDF ONLY]` (has_pdf=true, no chunks), `[NO PDF]`
- [ ] Implement fallback path: if index missing or has no entries, call `bash "$SCRIPT_DIR/zotero-read.sh" search "$QUERY"` and format results with notice
- [ ] Handle edge cases: empty index, all scores below threshold, query with only stop words
- [ ] Make script executable (`chmod +x`)
- [ ] Verify with `bash -n` syntax check

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-search-index.sh` - Replace stub with full implementation

**Verification**:
- `bash -n .claude/extensions/zotero/scripts/zotero-search-index.sh` passes with no syntax errors
- Script is executable
- Script handles empty index gracefully (fallback path)
- Script exits 1 for empty query, exits 2 when both index and zot unavailable
- Pretty output includes availability tags

---

### Phase 4: Wire --task N mode in command and skill files [NOT STARTED]

**Goal**: Add `--task N` argument parsing to `zotero.md` and a `task_search` mode handler to SKILL.md that extracts a task description from `specs/state.json` and passes it as a search query to `zotero-search-index.sh`.

**Tasks**:
- [ ] Add `--task` to the argument parsing block in `zotero.md`:
  - Add `elif "--task" in $ARGUMENTS` branch
  - Set `sub_mode = "task_search"`
  - Extract task number from argument following `--task`
- [ ] Add `--task N` to the argument-hint in the zotero.md frontmatter
- [ ] Add `--task N` entry to the Sub-Mode Dispatch table in zotero.md
- [ ] Add `--task N` to the Validate Sub-Mode table (N required)
- [ ] Add `task_search` case to the SKILL.md dispatch switch
- [ ] Implement `handle_task_search` in SKILL.md:
  - Validate task number is provided
  - Extract task description from `specs/state.json` using jq (`.active_projects[] | select(.project_number == ($n | tonumber)) | .description // .title // ""`)
  - Fall back to `project_name` converted to spaces if no description
  - Pass description as query to `zotero-search-index.sh "$desc" --format pretty`
- [ ] Add `task_num` extraction to SKILL.md argument parsing section
- [ ] Add error messages for missing task number and task not found

**Timing**: 45 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/zotero/commands/zotero.md` - Add --task N argument parsing
- `.claude/extensions/zotero/skills/skill-zotero/SKILL.md` - Add task_search mode handler and dispatch case

**Verification**:
- `zotero.md` argument parsing includes `--task` branch
- SKILL.md dispatch includes `task_search` case
- Handler extracts description from state.json and delegates to search script
- Error handling for missing task number and task not found in state.json

---

## Testing & Validation

- [ ] All three scripts pass `bash -n` syntax validation
- [ ] All three scripts are executable (`chmod +x` applied)
- [ ] `zotero-index-add.sh` exits 2 when `specs/zotero-index.json` is missing
- [ ] `zotero-index-remove.sh` exits 1 when key not found in index
- [ ] `zotero-search-index.sh` handles empty query (exit 1) and empty index (fallback path)
- [ ] `zotero-search-index.sh` produces both `--format json` and `--format pretty` output
- [ ] SKILL.md dispatch now includes `task_search` mode
- [ ] `zotero.md` argument parsing includes `--task N` branch
- [ ] All jq expressions avoid `!=` operator (use `| not` pattern per jq safety rules)
- [ ] Atomic write pattern used in all scripts that modify `specs/zotero-index.json`

## Artifacts & Outputs

- `.claude/extensions/zotero/scripts/zotero-index-add.sh` - Full implementation replacing stub
- `.claude/extensions/zotero/scripts/zotero-index-remove.sh` - Full implementation replacing stub
- `.claude/extensions/zotero/scripts/zotero-search-index.sh` - Full implementation replacing stub
- `.claude/extensions/zotero/commands/zotero.md` - Updated with --task N argument parsing
- `.claude/extensions/zotero/skills/skill-zotero/SKILL.md` - Updated with task_search mode handler

## Rollback/Contingency

All three scripts currently exist as stubs (echo + exit 2). If implementation fails:
1. Restore stubs from git: `git checkout -- .claude/extensions/zotero/scripts/zotero-index-{add,remove}.sh .claude/extensions/zotero/scripts/zotero-search-index.sh`
2. Revert command/skill changes: `git checkout -- .claude/extensions/zotero/commands/zotero.md .claude/extensions/zotero/skills/skill-zotero/SKILL.md`
3. Task status remains at current state; no state.json corruption risk since scripts do not modify task state
