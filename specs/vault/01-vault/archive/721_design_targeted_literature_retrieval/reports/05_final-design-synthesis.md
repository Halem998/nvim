# Final Design Report: Task #721 — Agent-Driven Literature Search

**Task**: 721 - Design targeted literature retrieval
**Date**: 2026-06-15
**Rounds synthesized**: 1-4
**Design status**: User-confirmed, ready for planning

---

## Design Summary

- The `--lit` flag will make `literature-search.sh` available as a callable bash tool to the agent, not inject content into the prompt. The agent formulates its own queries, browses results, reads what it needs, and decides when to stop.
- A two-script pipeline: `literature-build-index.sh` builds `.literature.db` from `index.json` (runs once, auto-rebuilds when stale); `literature-search.sh` is the agent-callable FTS5 search tool.
- The SQLite backend uses a 3-table schema (documents, doc_metadata, literature_fts) with BM25 column weights (title 10x, keywords 5x, abstract 3x, summary 2x, content 1x) and Porter stemming for cross-vocabulary recall.
- `index.json` remains the human-editable source of truth; `.literature.db` is derived, gitignored, and ephemeral — rebuilt in under 1 second for the current 183-entry corpus.
- `sqlite3` is now system-installed, eliminating the `nix-shell` wrapper overhead identified as a concern in prior rounds. The Lectic interactive layer is out of scope for this task — the user confirmed agent-only automation is the design intent.

---

## Problem Statement

The current `--lit` implementation in `literature-retrieve.sh` (234 lines, keyword-overlap scoring) suffers from a fundamental architectural mismatch. The corpus totals ~1.3M tokens across 183 entries, with a median entry of 3,500-4,000 tokens and 36 entries individually exceeding the 8,000-token injection budget. At most 1-2 entries can be injected per invocation no matter how good the scoring gets. More precisely: improving keyword overlap to BM25 changes *which* entry fills slot 1, but slot 1 is nearly all you get. Beyond the geometry problem, keyword scoring fails structurally for formal verification work — a task about "bimodal frame definability" needs the Sahlqvist correspondence paper, but neither "Sahlqvist" nor "correspondence" appears in the task description (Round 1, Finding 3, confirmed by LeanSearch v2 arxiv 2605.13137). The industry has moved to on-demand agent retrieval: Anthropic's own guidance favors JIT loading, Continue.dev deprecated bulk injection in favor of MCP-based on-demand retrieval, and the Rango paper (ICSE 2025) showed adaptive retrieval outperforms static injection by 47%.

---

## Architecture

The confirmed design is agent-driven autonomous search: when `--lit` is passed, the agent gains access to `literature-search.sh` as a callable bash tool instead of receiving injected content. The agent formulates its own queries based on the task prompt, browses ranked results with snippets, reads specific files as needed, and decides what is relevant and when to stop. No human-in-the-loop, no preflight scoring, no token-budget injection.

### System Diagram

```
  index.json                         Global source of truth
  (JSON, git-tracked)                (human-editable)
       |
       | literature-build-index.sh
       | (runs on demand; auto-rebuilds when index.json newer than .db)
       v
  .literature.db                     Derived FTS5 index
  (SQLite + FTS5, gitignored)        (~500KB-1MB for 183 entries)
       |
       | literature-search.sh "query" [--limit N] [--doc-type TYPE]
       | (agent-callable bash tool; ~5-10ms query time)
       v
  Agent receives                     Ranked results: id, title, authors,
  search results                     year, doc_type, token_count, path, snippet
       |
       | Agent decides: read more? drill into hierarchy? stop?
       v
  cat "$LITERATURE_DIR/path/file.md" Direct file read for selected documents
```

### Two-Tier Resolution

The global tier (`~/Projects/Literature/`) is the canonical source with 183 entries, rich metadata, git tracking, and `LITERATURE_DIR` env var support. The local tier (`specs/literature/`) holds per-project working sets — hard copies (not symlinks) of specifically-needed entries, possibly with project-specific annotations.

For agent search, the primary path is the global tier via `LITERATURE_DIR`. When both tiers exist, the agent can search both `.db` files independently (global and local each have their own `.db` built from their own `index.json`). Local entries take precedence when an id appears in both (local may have project annotations). The merger strategy from Round 2 remains valid: local-first dedup, global-only entries added after.

The global index v2 schema (confirmed from `~/Projects/Literature/index.json`) includes: `id`, `bib_key`, `title`, `authors`, `year`, `path`, `token_count`, `keywords` (array), `summary`, `doc_type`, `source_format`, `zotero_key`, `project_tags`.

---

## SQLite FTS5 Schema

The 3-table schema from Round 3, presented verbatim — this is the definitive schema for implementation:

```sql
-- Core document metadata (books, papers, chapters, sections)
CREATE TABLE documents (
    id TEXT PRIMARY KEY,          -- e.g., "blackburn_2001_ch02_sec01"
    parent_id TEXT,               -- e.g., "blackburn_2001" (for hierarchical navigation)
    title TEXT NOT NULL,
    authors TEXT,
    year INTEGER,
    doc_type TEXT NOT NULL,       -- "book", "paper", "chapter", "section"
    depth INTEGER DEFAULT 0,     -- 0=standalone, 1=book, 2=chapter, 3=section
    path TEXT NOT NULL,           -- relative path in Literature/ directory
    page_range TEXT,
    token_count INTEGER DEFAULT 0,
    bib_key TEXT,
    zotero_key TEXT,
    source_format TEXT,           -- "pdf", "djvu", "md"
    FOREIGN KEY (parent_id) REFERENCES documents(id)
);

-- Rich text metadata for search (separate for FTS external content)
CREATE TABLE doc_metadata (
    doc_id TEXT PRIMARY KEY,
    keywords TEXT,                -- space-separated for FTS tokenization
    summary TEXT,
    abstract TEXT,                -- from Zotero when available
    project_tags TEXT,            -- space-separated project tags
    FOREIGN KEY (doc_id) REFERENCES documents(id)
);

-- FTS5 virtual table with external content (does not duplicate data)
CREATE VIRTUAL TABLE literature_fts USING fts5(
    title,                        -- column 0: highest weight
    keywords,                     -- column 1: high weight
    abstract,                     -- column 2: medium-high weight
    summary,                      -- column 3: medium weight
    content,                      -- column 4: low weight (first ~500 words of doc)
    content='doc_search_view',    -- external content from a view
    content_rowid='rowid',
    tokenize='porter unicode61 remove_diacritics 2'
);

-- View that joins documents + metadata for FTS external content
CREATE VIEW doc_search_view AS
SELECT
    d.rowid,
    d.title,
    COALESCE(m.keywords, '') AS keywords,
    COALESCE(m.abstract, '') AS abstract,
    COALESCE(m.summary, '') AS summary,
    '' AS content                 -- populated during rebuild from file content
FROM documents d
LEFT JOIN doc_metadata m ON m.doc_id = d.id;

-- Set default BM25 column weights: title(10), keywords(5), abstract(3), summary(2), content(1)
INSERT INTO literature_fts(literature_fts, rank) VALUES('rank', 'bm25(10.0, 5.0, 3.0, 2.0, 1.0)');

-- Sync triggers for external content
CREATE TRIGGER docs_ai AFTER INSERT ON documents BEGIN
    INSERT INTO literature_fts(rowid, title, keywords, abstract, summary, content)
    SELECT new.rowid, new.title,
           COALESCE(m.keywords, ''), COALESCE(m.abstract, ''),
           COALESCE(m.summary, ''), ''
    FROM doc_metadata m WHERE m.doc_id = new.id
    UNION ALL
    SELECT new.rowid, new.title, '', '', '', ''
    WHERE NOT EXISTS (SELECT 1 FROM doc_metadata WHERE doc_id = new.id);
END;

CREATE TRIGGER docs_ad AFTER DELETE ON documents BEGIN
    INSERT INTO literature_fts(literature_fts, rowid, title, keywords, abstract, summary, content)
    VALUES('delete', old.rowid, old.title, '', '', '', '');
END;
```

### Column Weight Rationale

| Column | Weight | Rationale |
|--------|--------|-----------|
| title | 10.0 | Most specific identifier; a title match is almost always relevant |
| keywords | 5.0 | Curated terms from index.json; high precision |
| abstract | 3.0 | Dense summary from Zotero when available; good for cross-vocabulary matching |
| summary | 2.0 | Author-written summary in index.json; lower precision than abstract |
| content | 1.0 | First ~500 words of document; catches terms not in metadata |

### Tokenizer

`porter unicode61 remove_diacritics 2` provides Porter stemming ("correspondence" matches "corresponding", "definability" matches "definable"), Unicode61 for accented author names (Goranko, Venema), and diacritic-insensitive matching.

### Index Size Estimates

For the current 183-entry corpus: documents table ~90 KB, doc_metadata ~180 KB, FTS5 index ~200 KB. Total `.db` size: 500 KB-1 MB. Rebuild time: under 1 second.

---

## Scripts to Implement

### literature-build-index.sh

**Purpose**: Build (or rebuild) `.literature.db` from `index.json`. Run once on first use; auto-triggered by `literature-search.sh` when `index.json` is newer than `.db`.

**Inputs**:
- `$1` (optional): DB path, default `${LITERATURE_DIR:-$HOME/Projects/Literature}/.literature.db`
- `$2` (optional): Index path, default `${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json`

**Outputs**: `.literature.db` file at the specified path. Exits 0 on success, non-zero on failure.

**Rebuild strategy**: Always removes the stale `.db` before rebuilding (atomic: no partial state). Reads `index.json` with `jq`, transforms each entry into INSERT statements, executes schema creation + population in a single `sqlite3` session.

**Population logic**:
1. For each entry in `index.json` `.entries[]`: INSERT into `documents` (using `id`, `path`, `title`, `authors`, `year`, `doc_type`, `token_count`, `bib_key`, `zotero_key`)
2. INSERT into `doc_metadata` (using `id` as `doc_id`, joining `keywords` array as space-separated string, `summary`, `abstract` if present)
3. FTS5 is populated via the `docs_ai` trigger on each document insert

**Note**: `sqlite3` is now system-installed — no `nix-shell` wrapper needed.

**Example invocation**:
```bash
# Build for global tier
bash literature-build-index.sh

# Build for local tier
bash literature-build-index.sh "$PROJECT_ROOT/specs/literature/.literature.db" \
                                "$PROJECT_ROOT/specs/literature/index.json"
```

**Script location**: `.claude/scripts/literature-build-index.sh`

---

### literature-search.sh

**Purpose**: Agent-callable FTS5 search tool. This is the primary interface agents use when `--lit` is active. Returns ranked results with snippets and file paths the agent can then read.

**CLI interface**:
```bash
literature-search.sh "query terms" [--limit N] [--doc-type TYPE] [--tier global|local|both]
```

**Arguments**:
- `$1` (required): FTS5 MATCH query string (e.g., `"modal logic correspondence"`)
- `--limit N` (optional): Max results, default 10
- `--doc-type TYPE` (optional): Filter by doc_type — `paper`, `book`, `chapter`, `section`
- `--tier` (optional): `global` (default), `local` (specs/literature/), or `both`

**Output format** (tab-separated, one result per line):
```
id<TAB>title<TAB>authors<TAB>year<TAB>doc_type<TAB>token_count<TAB>path<TAB>context_snippet
```

Or structured output for readability (default when called interactively):
```
[1] blackburn_2001_ch03 — "Frame Definability and Correspondence" (Blackburn et al., 2002)
    Type: chapter  Tokens: 12,450  Path: Blackburn_deRijke_Venema_2002/ch03_frame-definability.md
    Context: "...the Sahlqvist >>>correspondence<<< theorem states that every Sahlqvist formula
              has a first-order <<<frame>>> condition..."

[2] ...
```

**Rebuild check**: Before executing the query, checks if `index.json` is newer than `.literature.db`. If stale, calls `literature-build-index.sh` automatically.

**SQL query executed**:
```sql
SELECT d.id, d.title, d.authors, d.year, d.doc_type, d.token_count, d.path,
       snippet(literature_fts, 3, '>>>', '<<<', '...', 32) AS context
FROM literature_fts
JOIN documents d ON d.rowid = literature_fts.rowid
WHERE literature_fts MATCH ?
ORDER BY rank
LIMIT ?;
```

**Example invocations**:
```bash
# Basic search
literature-search.sh "Sahlqvist correspondence"

# Targeted search with type filter
literature-search.sh "frame definability" --doc-type chapter --limit 5

# Boolean and phrase queries (FTS5 syntax)
literature-search.sh '"modal logic" AND correspondence'

# Cross-vocabulary: find related concepts
literature-search.sh "frame canonical model completeness"

# Search both tiers
literature-search.sh "tense logic Until" --tier both
```

**Script location**: `.claude/scripts/literature-search.sh`

**gitignore**: Add `.literature.db` to `~/Projects/Literature/.gitignore` and `specs/literature/.gitignore`.

---

## Agent Integration

### How `--lit` Changes

**Current behavior** (preflight injection via `literature-retrieve.sh`):
1. `skill-base.sh` preflight calls `literature-retrieve.sh <description> <task_type>`
2. Script extracts keywords from task description, scores `index.json` entries by keyword overlap
3. Top-scoring entries injected into agent prompt as `<literature-context>...</literature-context>` block
4. Agent receives content passively — it cannot query further or discover other entries
5. Budget-constrained to 8,000 tokens: typically 1-2 entries, determined before agent starts

**New behavior** (agent-driven search via `literature-search.sh`):
1. `skill-base.sh` preflight detects `--lit` flag
2. Instead of calling `literature-retrieve.sh`, it injects a `<literature-tool>` instructions block into the agent prompt (see Agent Prompt Instructions below)
3. Agent receives no content upfront — it receives the search capability
4. Agent formulates queries based on the task, calls `literature-search.sh "query"` via bash
5. Agent reads specific files via `cat "$LITERATURE_DIR/path/to/file.md"` when needed
6. Agent decides what is relevant, how deep to go, when to stop

**What changes in the dispatch chain**:
- `skill-base.sh` (or equivalent preflight hook): Replace `literature-retrieve.sh` call with tool-availability instructions injection
- `literature-retrieve.sh`: Unchanged — continues to exist for backward compatibility and legacy invocations
- `literature-build-index.sh`: New script, called lazily by `literature-search.sh`
- `literature-search.sh`: New script, the agent-callable tool

The `--lit` flag parsing in `skill-base.sh` already exists. The change is in what that flag triggers: from "call retrieve script and inject output" to "inject tool instructions".

### Agent Prompt Instructions

When `--lit` is active, the following block is injected into the agent's context before task-specific instructions:

```
<literature-tool>
You have access to a literature search tool for this task. Use it to find relevant
academic papers, books, and chapters from the indexed literature library.

To search: Run `literature-search.sh "your query terms"` in bash.
To read a document: Run `cat "$LITERATURE_DIR/path/from/search/results.md"` in bash.
To browse a book's chapters: Run `literature-search.sh "title" --doc-type chapter`

The search tool uses BM25 full-text search with Porter stemming. This means:
- "correspondence" matches "corresponding", "definability" matches "definable"
- Use natural vocabulary from the task; cross-vocabulary matching is handled
- Phrase queries use quotes: `literature-search.sh '"modal logic"'`
- Boolean queries: `literature-search.sh '"Sahlqvist" AND "first-order"'`

Search results show: id, title, authors, year, type, token_count, path, and a context
snippet. Check token_count before reading large documents — prefer chapter-level entries
(smaller) over full books (often 100K+ tokens).

Search when you need to:
- Verify a specific theorem or result
- Find the source of a concept or definition
- Confirm a proof technique or approach
- Retrieve specific sections of a known work

You do not need to search exhaustively. Search for what the task actually requires.
</literature-tool>
```

### Progressive Disclosure Pattern

The 4-level pattern from Round 3, as the intended agent workflow:

**Level 1 — Catalog Browse** (agent wants to know what's available, minimal cost):
```bash
# List recent papers without a specific query
literature-search.sh "modal logic" --limit 20
```
Returns: id, title, authors, year, type, token_count — agent can estimate relevance without reading.

**Level 2 — Targeted Search** (agent has a specific concept to find):
```bash
literature-search.sh "Sahlqvist correspondence frame definability"
```
Returns: ranked results with BM25 scores + context snippets — agent sees the most relevant passage before committing to a full read.

**Level 3 — Hierarchical Drill-Down** (agent found a relevant book, needs specific chapter):
```bash
# Find chapters of a known book
literature-search.sh "frame definability" --doc-type chapter
# Or search within a book using FTS column filters
literature-search.sh "blackburn_2001 correspondence"  # path prefix matching
```
Returns: chapter-level entries with their own token_counts — agent can pick the right chapter without reading the whole book.

**Level 4 — Content Retrieval** (agent has identified the exact document to read):
```bash
# Read the file directly using the path from search results
cat "$LITERATURE_DIR/Blackburn_deRijke_Venema_2002/ch03_frame-definability.md"
```
Agent reads the actual content at this point. Token cost is predictable from the `token_count` field seen in Level 2.

**Key agent decision signals**:
- `token_count`: Visible in search results. A 365K-token book entry signals "drill into chapters". A 5K-token paper entry signals "read directly".
- `doc_type`: `book` means drill deeper; `chapter` or `paper` means read if relevant.
- BM25 rank + snippet: Relevance signal before full read. If the snippet doesn't connect to the task, skip that result.

---

## Migration Path

The migration is non-destructive. `index.json` remains the source of truth at every step. The `.db` file is a derived, ephemeral artifact.

**Phase 0 (Immediate, no functional change)**:
1. Add `.literature.db` to `~/Projects/Literature/.gitignore` and `specs/literature/.gitignore` (if `specs/literature/` exists)
2. No changes to `literature-retrieve.sh` — it continues to function for existing invocations
3. No changes to `--lit` flag behavior — existing workflows unchanged

**Phase 1 (New scripts)**:
1. Write `literature-build-index.sh` — builds `.db` from `index.json`
2. Write `literature-search.sh` — agent-callable search tool
3. Test manually: `literature-search.sh "modal logic correspondence"` returns ranked results
4. Test rebuild: modify `index.json`, verify `literature-search.sh` triggers rebuild automatically

**Phase 2 (Agent integration — the design change)**:
1. Modify `skill-base.sh` (or the preflight hook for `--lit`): when `--lit` flag is detected, inject `<literature-tool>` instructions block instead of calling `literature-retrieve.sh`
2. Test: run `/research N --lit` on a task and verify the agent searches autonomously
3. `literature-retrieve.sh` continues to exist but is no longer called by `--lit`

**Backwards compatibility**:
- `literature-retrieve.sh` is preserved and still works if called directly
- The `--lit` flag changes behavior but no existing content is lost
- `index.json` is untouched
- All other skills and commands that read `specs/literature/` continue unchanged

---

## What's Relevant from Prior Research

### Round 1 (Team Research) — Relevant Findings

- **Carries forward**: The geometry problem (183 entries, ~1.3M tokens, 8K budget = 1-2 entries max) — this is the core motivation for the entire design change. The numbers justify the architectural shift.
- **Carries forward**: Cross-vocabulary failure documented precisely (LeanSearch v2 arxiv 2605.13137). A task about "bimodal frame definability" needs Sahlqvist — zero keyword overlap.
- **Carries forward**: BM25 wins at this scale (183 entries) vs. vector search. R@1=0.80 for BM25 vs. R@1=0.62 for semantic baseline. This justifies FTS5 over embeddings.
- **Carries forward**: Industry direction toward on-demand retrieval (Anthropic JIT guidance, Continue.dev deprecation, Rango +47% improvement). These are the theoretical backing for the design.
- **Carries forward**: SQLite FTS5 is the right backend — zero new dependencies, < 1s rebuild, BM25 built-in.
- **Superseded**: Tier 0 (Zotero bridge as a stop-gap) — the user confirmed we're going straight to agent-driven search, not improving the preflight scoring first.
- **Superseded**: The /cite vs --lit bifurcation framing — this task is specifically about the --lit flag; /cite is a separate concern.

### Round 2 (Global-Local Workflow) — Relevant Findings

- **Carries forward**: The two-tier architecture (global `~/Projects/Literature/` + local `specs/literature/`) is confirmed. Both tiers get their own `.db` files.
- **Carries forward**: Hard copies over symlinks for local tier. Symlinks break across machines.
- **Carries forward**: Local-first dedup when merging tiers (local copies may have project annotations).
- **Carries forward**: `LITERATURE_DIR` env var is the mechanism for global tier access.
- **Carries forward**: The v2 schema structure of global `index.json` confirmed from actual file read.
- **Partially superseded**: The pull/push/sync/catalog command proposals (Round 2's main contribution) are orthogonal to this task. They remain valid proposals but are out of scope for task 721 — this task is specifically about the `--lit` flag redesign.
- **Partially superseded**: The merged retrieval proposal for `literature-retrieve.sh` — the new design bypasses `literature-retrieve.sh` entirely when `--lit` is active, making the merge logic moot for agent retrieval (agents query both tiers themselves via the search tool).

### Round 3 (SQLite/Lectic Indexing) — Relevant Findings

Most of Round 3 carries forward directly. This is the most technically dense prior round.

- **Carries forward**: The 3-table schema (documents, doc_metadata, literature_fts) verbatim — this is the implementation spec.
- **Carries forward**: Column weights (10, 5, 3, 2, 1) and rationale.
- **Carries forward**: Tokenizer choice: `porter unicode61 remove_diacritics 2`.
- **Carries forward**: Hierarchical depth fields (parent_id, depth) for book-chapter navigation.
- **Carries forward**: The progressive disclosure 4-level pattern (browse → search → drill-down → read).
- **Carries forward**: External content table design — `.db` stores only tokens, content stays in `~/Projects/Literature/` files.
- **Carries forward**: Index size estimates (500 KB-1 MB for 183 entries) and rebuild timing (< 1 second).
- **Carries forward**: The split architecture diagram — two independent `.db` files (global + local).
- **Updated**: The `nix-shell -p sqlite` wrapper in the example scripts — this is no longer needed. sqlite3 is system-installed. All script examples should call `sqlite3` directly.
- **Superseded**: The Lectic SQLite tool analysis (Section 1 of Round 3) — the Lectic interactive layer is out of scope for this task per user confirmation. The patterns (schema auto-introspection, YAML output, size limits) informed the design but Lectic itself is not part of this implementation.
- **Superseded**: Phase 2 "Dual-Mode Operation" (both retrieve.sh and search.sh active simultaneously) — the confirmed design changes `--lit` to the new behavior in Phase 2, not keeping both active.

### Round 4 (Lectic Direct vs Custom) — Relevant Findings

- **Carries forward**: The core verdict: Lectic's SQLite tool is architecturally ideal for interactive human use but cannot be used by Claude Code agents directly without adding LLM latency and API cost to every search. This is the definitive rejection of Lectic-as-agent-tool.
- **Carries forward**: The performance numbers — `sqlite3` CLI direct: ~5-10ms; `nix-shell -p sqlite` wrapper: ~200ms; Lectic conversation startup: 800-1500ms. These justify the bash-not-Lectic choice.
- **Carries forward**: The `sqlite3` PATH optimization — check if `sqlite3` is in PATH before trying `nix-shell`. Now moot given user's system-wide sqlite3 installation.
- **Superseded**: Option C (hybrid) recommendation — the user confirmed the Lectic layer is orthogonal to this task. The Neovim Lectic integration (`.lec` template file, `LecticOpenLitSearch` command, keymap) is a separate concern and not part of task 721's scope.
- **Superseded**: The `vim.g.lectic_model` fix, LSP activation concerns, and Lectic plugin configuration analysis — these are Neovim configuration concerns for a separate task.

---

## Open Questions for Planning

The following decisions remain for the planner to address:

1. **Skill-base.sh modification scope**: Which file exactly controls the `--lit` preflight behavior? The injection currently happens in `skill-base.sh` or a preflight hook. The planner needs to identify the exact file and line range where the `literature-retrieve.sh` call is made and where the `<literature-tool>` instructions block should be injected instead.

2. **Content field population**: Should `literature-build-index.sh` read the first ~500 words of each markdown file to populate the FTS5 `content` column? This improves cross-vocabulary recall (Round 3, Section 6) but increases build time and index size. Round 3 recommendation: start without it, add if metadata-only search proves insufficient. The planner should decide: implement the content field in Phase 1, or leave it empty and treat it as a Phase 2 enhancement.

3. **Abstract field coverage**: How many of the 183 global entries have `zotero_key` values that cross-reference to `zotero-library.json` with abstracts? The `abstract` column in `doc_metadata` is currently empty for most entries (index.json does not have an `abstract` field). Populating abstracts from Zotero would significantly improve cross-vocabulary recall. This may be a Phase 2 enhancement separate from the core build script.

4. **FTS5 query safety**: The agent writes query strings that are passed to `sqlite3` via bash. If the query contains single quotes or SQL injection characters, the bash command could fail or behave unexpectedly. The planner should decide: (a) sanitize/escape the query in the bash script before passing to `sqlite3`, or (b) use `sqlite3`'s `-cmd` mode with proper quoting, or (c) use a here-doc approach to pass the SQL safely. Read-only database mode provides a safety floor but sanitization is still good practice.

5. **Skill-base.sh `--lit` flag detection**: The planner should verify whether `--lit` is already parsed in `skill-base.sh` or in individual skill SKILL.md files, and confirm the exact location where the injection logic needs to change. This determines whether the change is in one central file or needs to be propagated to multiple skill files.

6. **Agent tool access mechanism**: The `<literature-tool>` instructions tell the agent to run `literature-search.sh` in bash. This requires `literature-search.sh` to be in the agent's PATH or referenced by absolute path. The planner should decide: (a) install to `/home/benjamin/.config/nvim/.claude/scripts/` (already in PATH for nvim project), or (b) reference by absolute path in the instructions. Option (a) is cleaner.

---

## Sources

Consolidated from all 4 rounds:

**Architecture and Agent Retrieval**:
1. [Anthropic: Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — JIT loading over preflight injection
2. [JetBrains NeurIPS 2025: Efficient Context Management](https://blog.jetbrains.com/research/2025/12/efficient-context-management/) — 25% tokens = 95% accuracy
3. [Rango: Adaptive Retrieval-Augmented Proving (ICSE 2025)](https://arxiv.org/html/2412.14063) — adaptive retrieval outperforms static injection by 47%
4. [Is Grep All You Need? (arxiv 2605.15184)](https://arxiv.org/abs/2605.15184) — agentic grep 68% vs. vector search 60%
5. [How Building AI Agents Has Changed in 2026 (Pulumi)](https://www.pulumi.com/blog/how-building-ai-agents-has-changed/) — CLI-based tool calls vs MCP overhead

**Formal Verification Retrieval**:
6. [LeanSearch v2 (arxiv 2605.13137)](https://arxiv.org/abs/2605.13137) — keyword failure for cross-vocabulary queries documented
7. [Embeddings Aren't Magic (Towards Data Science)](https://towardsdatascience.com/embeddings-arent-magic-the-predictable-failure-modes-of-rag-retrieval-enterprise-document-intelligence-vol-1-2/) — structural RAG failure modes

**SQLite FTS5**:
8. [SQLite FTS5 Official Documentation](https://sqlite.org/fts5.html) — external content tables, BM25, tokenizers, snippet/highlight
9. [Full-Text Search in SQLite: A Practical Guide](https://medium.com/@johnidouglasmarangon/full-text-search-in-sqlite-a-practical-guide-80a69c3f42a4) — external content, BM25 tuning
10. [memweave: Zero-Infra AI Agent Memory with Markdown and SQLite](https://towardsdatascience.com/memweave-zero-infra-ai-agent-memory-with-markdown-and-sqlite-no-vector-database-required/) — hybrid BM25, markdown as source of truth
11. [Datasette Full-Text Search](https://docs.datasette.io/en/stable/full_text_search.html) — FTS5 integration patterns

**Progressive Disclosure**:
12. [Progressive Disclosure for Knowledge Discovery in Agentic Workflows](https://medium.com/@prakashkop054/s01-mcp03-progressive-disclosure-for-knowledge-discovery-in-agentic-workflows-8fc0b2840d01) — 5-level MCP retrieval cascade

**Lectic (patterns extracted, not used directly)**:
13. [Lectic SQLite Tool Documentation](https://github.com/gleachkr/Lectic/tree/main/doc/tools/03_sqlite.qmd) — schema auto-introspection, YAML output, size limits patterns
14. [Lectic Memory Cookbook](https://github.com/gleachkr/Lectic/tree/main/doc/cookbook/04_memory.qmd) — push vs. pull memory model distinction

**Obsidian and Reference Tool Architecture**:
15. [Obsidian Index Service](https://github.com/pmmvr/obsidian-index-service) — SQLite indexing of markdown vault, SHA-256 change detection

**Prior Research Artifacts**:
16. `specs/721_design_targeted_literature_retrieval/reports/01_team-research.md` — Round 1: geometry problem, BM25 benchmarks, industry trends
17. `specs/721_design_targeted_literature_retrieval/reports/02_global-local-workflow-research.md` — Round 2: two-tier architecture, merge strategy, workflow gaps
18. `specs/721_design_targeted_literature_retrieval/reports/03_sqlite-lectic-indexing.md` — Round 3: FTS5 schema, Lectic patterns, progressive disclosure design
19. `specs/721_design_targeted_literature_retrieval/reports/04_lectic-direct-vs-custom.md` — Round 4: architecture comparison, Lectic verdict, performance analysis
