# Research Report: Task #721 (Round 3) -- SQLite/Lectic Literature Indexing Design

**Task**: 721 - Design targeted literature retrieval
**Started**: 2026-06-15
**Completed**: 2026-06-15
**Focus**: SQLite FTS5 indexing with Lectic-inspired agent-crawlable search
**Sources**: Lectic project (GitHub), SQLite FTS5 official docs, MCP progressive disclosure patterns, memweave architecture, Datasette FTS integration, prior rounds 1-2 findings

## Executive Summary

- **Lectic's key insight is not SQLite-as-database but SQLite-as-tool**: Lectic exposes SQLite databases directly to LLMs via a tool interface with auto-introspected schemas, YAML result formatting, size limits, and atomic transactions. The agent writes SQL queries, not the harness. This is the exact "agent-crawlable" pattern the user wants.
- **FTS5 external content tables solve the local-index/global-content problem**: The FTS5 index stores only tokens + rowids, while actual content lives in a separate table (or on the filesystem via paths). This means the `.db` index file can be local and ephemeral (~200KB for 183 entries) while content lives in `~/Projects/Literature/`.
- **A 3-table schema (documents, sections, literature_fts) with hierarchical depth levels** enables progressive disclosure: agents search metadata first (title, keywords, summary), then drill into sections, then read full content -- all through SQL queries against a single `.db` file.
- **The migration from JSON to SQLite is non-destructive**: `index.json` remains the source of truth; the `.db` file is rebuilt from it on demand (< 1 second for 183 entries). The JSON index, bash retrieve script, and `--lit` flag all continue to work unchanged during transition.
- **BM25 column weighting is the critical tuning lever**: With weights of title(10x), keywords(5x), abstract(3x), summary(2x), content(1x), FTS5 BM25 dramatically outperforms the current keyword-overlap scoring, especially for cross-vocabulary queries that Round 1 identified as the primary failure mode.

## 1. Lectic Project Analysis

### What Lectic Is

Lectic is a Unix-philosophy LLM client (TypeScript/Bun, 92.3% TS) where each conversation is a plain-text CommonMark markdown file (`.lec` extension). It supports multiple LLM providers (Anthropic, Gemini, OpenAI, OpenRouter) and emphasizes composability through directives, macros, hooks, and tools.

### Architecture and Design Patterns

**File-first**: Conversations are human-readable markdown with YAML frontmatter. No proprietary database -- everything is greppable, diffable, version-controllable. This aligns with the existing Literature/ design (markdown files + JSON index).

**Tool system**: Lectic defines six tool types:

| Tool | Config Key | Purpose |
|------|-----------|---------|
| `exec` | `exec: rg --json` | Run shell commands |
| `sqlite` | `sqlite: ./data.db` | Query SQLite databases |
| `mcp` | `mcp_command: npx ...` | Connect to MCP servers |
| `agent` | `agent: OtherName` | Multi-LLM delegation |
| `a2a` | `a2a: http://...` | Remote agent calls |
| `native` | `native: search` | Provider built-ins |

**Tool kits**: Reusable tool sets can be named and shared across interlocutors:
```yaml
kits:
  - name: research_tools
    tools:
      - sqlite: ./literature.db
        name: lit_search
        readonly: true
      - exec: cat
        name: read_file
```

### How Lectic Uses SQLite

Lectic's SQLite integration is the most relevant pattern for this task. Key features:

1. **Schema auto-introspection**: When a SQLite database is attached as a tool, Lectic reads `sqlite_master` and includes the full schema in the tool description sent to the LLM. The agent sees what tables and columns exist without manual documentation.

2. **YAML result formatting**: Query results are returned as YAML (not raw SQL output), which LLMs parse more reliably. This is a deliberate design choice.

3. **Size limiting**: The `limit` parameter caps serialized response size in bytes. If a result exceeds the cap, the tool raises an error prompting the LLM to write a more selective query. This naturally encourages progressive disclosure.

4. **Atomic transactions**: Each tool call runs in a transaction with automatic rollback on failure.

5. **Read-only mode**: `readonly: true` prevents writes -- appropriate for a literature index.

6. **Extension loading**: SQLite extensions (like FTS5, sqlite-vec) can be loaded via the `extensions` config array.

7. **Init SQL**: Missing databases can be auto-initialized from a SQL schema script.

Example configuration:
```yaml
tools:
  - sqlite: ./literature.db
    name: lit_search
    readonly: true
    limit: 10000
    details: >
      Contains indexed academic literature with full-text search.
      Use FTS5 MATCH queries on the literature_fts table for
      relevance-ranked search. Join with documents table for metadata.
```

The LLM then writes SQL directly:
```sql
SELECT d.title, d.authors, d.year, snippet(f, 4, '<mark>', '</mark>', '...', 32)
FROM literature_fts f
JOIN documents d ON d.id = f.rowid
WHERE literature_fts MATCH 'modal logic correspondence'
ORDER BY bm25(literature_fts, 10.0, 5.0, 3.0, 2.0, 1.0)
LIMIT 5;
```

### Lectic Memory Pattern (Highly Relevant)

Lectic's cookbook includes a "Conversation Memory" recipe that demonstrates two SQLite-backed memory architectures:

**Approach 1 -- Memory as a Tool (Pull Model)**: Messages are recorded automatically via hooks into a SQLite database. The assistant explicitly searches with a `search_memory` tool that runs `SELECT ... WHERE content LIKE '%${QUERY}%'`. The prompt stays lean.

**Approach 2 -- Automatic Context Injection (Push Model)**: The assistant has a `remember` tool to store things. Memories are injected into the prompt via `exec:` in the YAML frontmatter -- a shell script that queries the database and formats results.

This maps directly to the `--lit` (push) vs. `/cite` (pull) distinction from Round 1.

### Applicable Design Patterns for Literature System

1. **Agent-written SQL**: Instead of a bash script scoring entries, the agent formulates its own queries. This is the core architectural shift.
2. **Schema as documentation**: Auto-introspected schema means the agent knows what it can query without external docs.
3. **Size-limited results**: Force progressive disclosure through byte limits on query results.
4. **Read-only database tool**: Safety guarantee for a reference database.
5. **Init from schema**: Rebuild database from index.json using an init script when the .db file is missing.
6. **Tool kits for reuse**: Package the literature search tool for use across projects.

## 2. SQLite FTS5 Schema Design

### Proposed Schema for Literature Index

The schema uses three main tables plus an FTS5 virtual table with external content:

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
| abstract | 3.0 | Dense summary from Zotero; good for cross-vocabulary matching |
| summary | 2.0 | Author-written summary in index.json; lower precision than abstract |
| content | 1.0 | First ~500 words of document; catches terms not in metadata |

### Tokenizer Choice

`porter unicode61 remove_diacritics 2` provides:
- **Porter stemming**: "correspondence" matches "corresponding", "definability" matches "definable"
- **Unicode61**: Handles accented author names (Goranko, Venema) and mathematical notation
- **remove_diacritics 2**: Removes diacritics only for ASCII equivalents (accent-insensitive matching)

### Hierarchical Document Structure

The `parent_id` and `depth` fields enable hierarchical navigation:

```
depth 0: standalone papers (e.g., "burgess_1982_i")
depth 1: books (e.g., "blackburn_2001", token_count=0, serves as grouping node)
depth 2: chapters (e.g., "blackburn_2001_ch02_sec01")
depth 3: sections (e.g., future finer-grained splits)
```

Agent queries for hierarchical browsing:
```sql
-- Find all chapters of a book
SELECT id, title, token_count FROM documents
WHERE parent_id = 'blackburn_2001' ORDER BY id;

-- Find the book a chapter belongs to
SELECT d.title, d.authors FROM documents d
JOIN documents c ON c.parent_id = d.id
WHERE c.id = 'blackburn_2001_ch02_sec01';
```

### Index Size Estimates

For the current 183-entry corpus:
- Documents table: ~183 rows x ~500 bytes = ~90 KB
- Doc_metadata table: ~183 rows x ~1 KB = ~180 KB
- FTS5 index: ~183 entries, ~500 tokens avg = ~200 KB
- **Total estimated .db size: 500 KB - 1 MB** (trivially small, trivially fast)
- **Rebuild time: < 1 second** (confirmed by Round 1 research)

## 3. Agent-Crawlable Search Architecture

### Progressive Disclosure via SQL

The core innovation is replacing the bash scoring script with agent-driven SQL queries. The agent starts broad and narrows based on what it finds:

**Level 1 -- Catalog Browse** (metadata only, minimal tokens):
```sql
SELECT id, title, authors, year, doc_type, token_count
FROM documents
WHERE doc_type IN ('paper', 'chapter')
ORDER BY year DESC
LIMIT 20;
```

**Level 2 -- Keyword Search** (FTS5, ranked results with snippets):
```sql
SELECT d.id, d.title, d.authors, d.year, d.token_count, d.path,
       snippet(literature_fts, 3, '>>>', '<<<', '...', 32) AS context
FROM literature_fts
JOIN documents d ON d.rowid = literature_fts.rowid
WHERE literature_fts MATCH 'Sahlqvist correspondence frame'
ORDER BY rank
LIMIT 10;
```

**Level 3 -- Section Drill-Down** (navigate hierarchy):
```sql
-- Agent found relevant book, now wants specific chapters
SELECT d.id, d.title, d.token_count,
       snippet(literature_fts, 3, '>>>', '<<<', '...', 32) AS summary_snippet
FROM documents d
JOIN literature_fts ON d.rowid = literature_fts.rowid
WHERE d.parent_id = 'blackburn_2001'
  AND literature_fts MATCH 'correspondence theory'
ORDER BY rank;
```

**Level 4 -- Content Retrieval** (agent reads the actual file):
```sql
-- Agent identified the exact document, now reads its path
SELECT path, token_count FROM documents WHERE id = 'blackburn_2001_ch03_sec01';
-- Agent then uses: cat ~/Projects/Literature/blackburn_2001/ch03_frame-definability.md
```

### How the Agent Decides What to Read Next

The schema surfaces three key signals that help the agent make decisions:

1. **token_count**: The agent can estimate context cost before reading. A 365K-token book is clearly too large; a 5K-token chapter is manageable.
2. **doc_type + depth**: Tells the agent whether it is looking at a book (drill deeper) or a paper (read directly).
3. **BM25 rank + snippets**: The relevance score and snippet preview let the agent judge quality without reading the full document.

### Tool Configuration for Claude Code

The literature search could be exposed as a bash tool (since Claude Code uses bash, not Lectic):

```bash
#!/usr/bin/env bash
# literature-search.sh -- Agent-callable FTS5 search tool
# Usage: literature-search.sh "query terms" [--limit N] [--doc-type TYPE]
set -euo pipefail

QUERY="$1"
LIMIT="${2:-10}"
DB="${LITERATURE_DIR:-$HOME/Projects/Literature}/.literature.db"

# Rebuild if stale (index.json newer than .db)
INDEX="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"
if [ ! -f "$DB" ] || [ "$INDEX" -nt "$DB" ]; then
    literature-rebuild-index.sh "$DB" "$INDEX"
fi

nix-shell -p sqlite --run "sqlite3 '$DB' <<SQL
SELECT d.id, d.title, d.authors, d.year, d.doc_type, d.token_count, d.path,
       snippet(literature_fts, 3, '>>>', '<<<', '...', 32) AS context
FROM literature_fts
JOIN documents d ON d.rowid = literature_fts.rowid
WHERE literature_fts MATCH '${QUERY}'
ORDER BY rank
LIMIT ${LIMIT};
SQL"
```

### MCP-Based Progressive Disclosure Pattern

Following the industry-standard pattern identified in the research, the literature system should expose these tool functions:

| Tool Function | Returns | Token Cost |
|---------------|---------|------------|
| `lit_search(query)` | Ranked list: id, title, authors, year, snippet | ~100 tokens/result |
| `lit_browse(parent_id)` | Children: id, title, doc_type, token_count | ~50 tokens/result |
| `lit_metadata(doc_id)` | Full metadata: all fields from documents + doc_metadata | ~200 tokens |
| `lit_read(doc_id)` | Full content of the referenced file | Variable (avg 7K tokens) |

This maps to the 5-level progressive disclosure pattern:
1. Search -> ranked list with snippets
2. Browse -> hierarchical navigation
3. Metadata -> full structured metadata
4. Read -> full document content

## 4. Local Index to Global Content Architecture

### The Split Architecture

```
~/Projects/Literature/              # Global content store
  index.json                        # Source of truth (JSON, git-tracked)
  .literature.db                    # Ephemeral FTS5 index (gitignored)
  blackburn_2001/                   # Content directories
    ch01_general-frames.md
    ...
  Burgess_1982_*.md                 # Standalone papers

~/.config/nvim/specs/literature/    # Per-project local tier
  index.json                        # Local entries (may reference global IDs)
  .literature.db                    # Local FTS5 index (gitignored)
  project-specific-note.md          # Local-only content
```

### How Split Index/Content Works with SQLite

The `documents.path` field stores a **relative path** within the Literature/ directory. The `.db` file contains only the index (metadata + FTS5 tokens), not the actual markdown content. This means:

1. **The .db is portable**: It can be rebuilt from `index.json` on any machine.
2. **The .db is small**: ~500KB for 183 entries (vs. ~50MB of markdown content).
3. **Content is read on demand**: The agent gets a `path` from a query, then reads the file only when needed.
4. **Global and local .db files are independent**: Each tier has its own `.db` built from its own `index.json`.

### Content Synchronization Strategies

Based on analysis of how Calibre, Zotero, Thunderbird, and Obsidian handle this:

| Strategy | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Symlinks** | Zero disk cost, always current | Break across machines, git ignores targets | No -- Round 2 rejected this |
| **Hard copies** | Git-trackable, cross-machine | Disk duplication, stale risk | Yes -- for local working sets |
| **On-demand read** | Zero local copies needed | Requires `LITERATURE_DIR` to be set | Yes -- for global tier |
| **Cached reads** | Fast repeated access | Cache invalidation complexity | No -- premature optimization |

**Recommended approach** (confirmed from Round 2):
- **Global tier**: Agent reads files directly from `~/Projects/Literature/` via path from `.db` query. No copies needed. Requires `LITERATURE_DIR` env var.
- **Local tier** (`specs/literature/`): Hard copies of specifically-needed entries. Pulled via `/literature --pull`. Small working set.
- **Merged search**: Agent queries both `.db` files (or a merged in-memory view). Local entries take precedence (may have annotations).

### How Other Tools Handle This

**Zotero**: Stores metadata in `zotero.sqlite` (local), with attachments as separate files in `storage/` directories. The database maps to file paths via `filePath` column. Attachments can be synced via WebDAV or Zotero cloud, but the SQLite database is always local.

**Calibre**: Stores metadata in `metadata.db` (SQLite) with books as separate files in author/title directories. The database maps to file paths. Libraries can be on network drives.

**Thunderbird Gloda**: Global index in `global-messages-db.sqlite` that indexes messages stored across multiple mailbox files. The index is ephemeral and can be rebuilt from the source files.

**Obsidian Index Service**: Monitors a vault directory and indexes markdown files into SQLite. Uses SHA-256 for change detection. The index can be used by external tools (including MCP servers) for search.

All four follow the same pattern: **SQLite index (local, ephemeral, rebuildable) + content files (separate, authoritative)**. This is exactly what we propose.

## 5. Migration Path from JSON

### Phase 0: Non-Destructive Foundation

**Principle**: `index.json` remains the source of truth. The `.db` file is derived and ephemeral.

```
index.json (authoritative) --[rebuild script]--> .literature.db (derived, gitignored)
```

**Steps**:
1. Add `.literature.db` to `.gitignore` in Literature/ directory
2. Create `literature-build-index.sh` that reads `index.json` and creates the SQLite database
3. Existing `literature-retrieve.sh` continues to work unchanged (reads JSON)
4. New `literature-search.sh` queries the `.db` file (used by agents)

### Phase 1: Build Script

```bash
#!/usr/bin/env bash
# literature-build-index.sh -- Build FTS5 index from index.json
# Usage: literature-build-index.sh [DB_PATH] [INDEX_PATH]
set -euo pipefail

DB="${1:-${LITERATURE_DIR:-$HOME/Projects/Literature}/.literature.db}"
INDEX="${2:-${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json}"

# Remove stale database
rm -f "$DB"

# Create schema and populate from index.json
# (uses jq to transform JSON entries into SQL INSERT statements)
nix-shell -p sqlite --run "sqlite3 '$DB'" <<'SCHEMA'
CREATE TABLE documents ( ... );  -- full schema from Section 2
CREATE TABLE doc_metadata ( ... );
CREATE VIRTUAL TABLE literature_fts USING fts5( ... );
-- triggers
SCHEMA

# Populate from index.json
jq -r '.entries[] | ...' "$INDEX" | while IFS=$'\t' read -r id title ...; do
    nix-shell -p sqlite --run "sqlite3 '$DB' \"INSERT INTO documents ...\""
done
```

### Phase 2: Dual-Mode Operation

During transition, both paths work:
- `--lit` flag: Still uses `literature-retrieve.sh` (JSON-based scoring, preflight injection)
- Agent tools: Use `literature-search.sh` (SQLite FTS5, on-demand queries)

No existing workflow breaks. The SQLite path is additive.

### Phase 3: Agent Integration

Add literature search as an available tool in agent configurations:
- The agent can call `literature-search.sh "query"` to search
- The agent can call `cat "$LITERATURE_DIR/path/to/file.md"` to read content
- The `--lit` flag can optionally switch to using FTS5 for scoring (replacing JSON keyword overlap)

### Phase 4: Optional JSON Deprecation (Future)

If/when SQLite proves sufficient:
- `index.json` could become a generated view of the database (reverse of current direction)
- Or remain as human-editable source of truth that feeds the database
- Decision deferred -- both directions are viable

### Backwards Compatibility

**sqlite3 unavailable**: The system must degrade gracefully. Since `sqlite3` is not in the default PATH on this NixOS system (requires `nix-shell -p sqlite`), the build script should:
1. Check for `sqlite3` in PATH
2. If not found, try `nix-shell -p sqlite --run "sqlite3 ..."`
3. If neither works, fall back to JSON-based scoring (current behavior)
4. Log a warning: "SQLite not available, using JSON fallback"

## 6. Comparison: JSON vs. SQLite FTS5

### What FTS5 Gives That JSON Cannot

| Capability | JSON + bash (current) | SQLite FTS5 (proposed) |
|-----------|----------------------|----------------------|
| **Scoring algorithm** | Keyword set overlap (1 point per match) | BM25 with TF-IDF (rare terms score higher) |
| **Column weighting** | None (keywords and summary weighted equally) | Per-column: title(10x), keywords(5x), abstract(3x), summary(2x) |
| **Stemming** | None ("correspondence" misses "corresponding") | Porter stemmer built-in |
| **Phrase queries** | Not possible | `"modal logic"` matches exact phrase |
| **Proximity search** | Not possible | `NEAR("frame" "definability", 5)` |
| **Boolean operators** | Not possible | `AND`, `OR`, `NOT`, column filters |
| **Snippet extraction** | Not possible | `snippet()` returns relevant passage with highlighting |
| **Cross-vocabulary matching** | Very poor (Round 1: primary failure mode) | Stemming + abstracts + content field improve recall |
| **Agent-driven search** | Not possible (script runs at preflight) | Agent writes SQL queries iteratively |
| **Rebuild time** | N/A (no build step) | < 1s for 183 entries |
| **Dependencies** | `jq`, `bash` (always available) | `sqlite3` (available via nix, not in base PATH) |
| **File size** | `index.json` at 5,351 lines (~200KB) | `.literature.db` at ~500KB-1MB |

### The Key Improvement: Cross-Vocabulary Matching

Round 1 identified that the primary failure mode is cross-vocabulary matching: a task about "bimodal frame definability" needs the Sahlqvist correspondence paper, but "Sahlqvist" does not appear in the task description. FTS5 addresses this through:

1. **Abstract field**: Zotero abstracts often describe results in multiple vocabularies. A paper's abstract might mention both "Sahlqvist" and "frame definability".
2. **Content field**: The first 500 words of each document capture introductory material that often states the connection between concepts.
3. **Porter stemming**: "definable" matches "definability", "corresponding" matches "correspondence".
4. **BM25 IDF weighting**: Rare terms (like author names or specific theorem names) get higher scores than common terms.

## 7. Recommended Design

### Architecture Summary

Building on all three rounds of research, the recommended design is:

```
                     +-------------------+
                     |   index.json      |  Source of truth (human-editable)
                     |   (JSON, git)     |
                     +--------+----------+
                              |
                     [literature-build-index.sh]
                              |
                     +--------v----------+
                     |  .literature.db   |  Derived index (gitignored, ephemeral)
                     |  (SQLite + FTS5)  |
                     +--------+----------+
                              |
              +---------------+---------------+
              |                               |
     +--------v----------+        +-----------v---------+
     | literature-search |        | literature-retrieve |
     | (agent-callable)  |        | (preflight --lit)   |
     | SQL queries       |        | JSON scoring        |
     +-------------------+        +---------------------+
              |                               |
     Agent-driven pull             Script-driven push
     (progressive disclosure)      (legacy compatibility)
```

### Implementation Priorities

**Tier 1 (Immediate Value -- ~4-6 hours)**:
1. Write `literature-build-index.sh` that creates `.literature.db` from `index.json`
2. Write `literature-search.sh` as an agent-callable bash tool
3. Add `.literature.db` to `.gitignore`
4. Test with current 183-entry corpus

**Tier 2 (Agent Integration -- ~6-8 hours)**:
1. Create `literature-browse.sh` for hierarchical navigation
2. Create `literature-read.sh` for content retrieval with token budget
3. Integrate as available tools in agent skill definitions
4. Add abstract field migration from Zotero (one-time `zotero-library.json` cross-reference)

**Tier 3 (Merge and Replace -- ~4-6 hours)**:
1. Implement two-tier merged search (global + local .db files)
2. Optionally upgrade `--lit` to use FTS5 scoring instead of JSON keyword overlap
3. Add `literature-build-index.sh` to `--lit` preflight (auto-rebuild when stale)

**Tier 4 (Progressive Disclosure -- Future)**:
1. Full MCP-style tool interface (search/browse/metadata/read)
2. Agent-initiated content chunking for large documents
3. Conversation-scoped result caching

### Key Design Decisions

1. **JSON stays as source of truth**: The `.db` is derived. Users edit `index.json` (or use `/literature --index`). The build script transforms it.
2. **Ephemeral .db**: Gitignored, rebuilt on demand. No sync issues.
3. **nix-shell fallback**: Since `sqlite3` is not in the base NixOS PATH, all commands use `nix-shell -p sqlite --run "sqlite3 ..."` with graceful fallback.
4. **Two tiers remain independent**: Global `.db` and local `.db` are separate files. Merged search queries both.
5. **Agent writes SQL**: The agent formulates queries, not a scoring script. This is the fundamental architectural shift from push (injection) to pull (on-demand retrieval).

## Open Questions

1. **Content field population**: Should the FTS5 index include the first N words of each markdown file? This improves recall but increases build time and index size. Recommendation: start without it, add if metadata-only search proves insufficient.

2. **nix-shell overhead**: Each `nix-shell -p sqlite --run "sqlite3 ..."` invocation has startup overhead (~200ms). Should we add `sqlite` to the NixOS system packages instead? Or use a long-running sqlite3 process?

3. **Query sanitization**: If the agent writes SQL and queries are passed through bash, SQL injection is a concern. Lectic handles this with a SQL parser that blocks dangerous statements (ATTACH, DETACH, PRAGMA, VACUUM). A simpler approach for read-only databases: always open with `readonly: true` and use prepared statements.

4. **Abstract coverage**: How many of the 183 Literature/ entries have matching Zotero records with abstracts? The cross-reference via `bib_key`/`zotero_key` needs to be tested.

5. **FTS5 query formulation**: How reliably can agents write FTS5 MATCH queries? The syntax is specialized (quoted phrases, column filters, NEAR). May need a simplified wrapper or query builder.

6. **Per-project vs. global database**: Should each project build its own `.db` (including only relevant entries via `project_tags`)? Or always query the full global database?

## Sources

1. [Lectic -- An LLM client where each conversation is a markdown file](https://github.com/gleachkr/Lectic) -- GitHub repository, source code, and documentation
2. [Lectic SQLite Tool Documentation](https://github.com/gleachkr/Lectic/tree/main/doc/tools/03_sqlite.qmd) -- Configuration, schema introspection, YAML results, size limits
3. [Lectic Memory Cookbook](https://github.com/gleachkr/Lectic/tree/main/doc/cookbook/04_memory.qmd) -- SQLite-backed push and pull memory patterns
4. [Lectic External Content Documentation](https://github.com/gleachkr/Lectic/tree/main/doc/context_management/01_external_content.qmd) -- URI schemes, content references, cmd/attach directives
5. [SQLite FTS5 Extension -- Official Documentation](https://sqlite.org/fts5.html) -- External content tables, BM25 ranking, column weights, tokenizers, snippet/highlight functions
6. [Progressive Disclosure for Knowledge Discovery in Agentic Workflows](https://medium.com/@prakashkop054/s01-mcp03-progressive-disclosure-for-knowledge-discovery-in-agentic-workflows-8fc0b2840d01) -- 5-level MCP retrieval cascade, metadata architecture
7. [memweave: Zero-Infra AI Agent Memory with Markdown and SQLite](https://towardsdatascience.com/memweave-zero-infra-ai-agent-memory-with-markdown-and-sqlite-no-vector-database-required/) -- Hybrid BM25 + vector search, markdown files as source of truth, SHA-256 change detection
8. [Full-Text Search in SQLite: A Practical Guide](https://medium.com/@johnidouglasmarangon/full-text-search-in-sqlite-a-practical-guide-80a69c3f42a4) -- External content tables, BM25 tuning, tokenizer configuration
9. [simonw/llm-tools-sqlite](https://github.com/simonw/llm-tools-sqlite) -- LLM tools for running queries against SQLite
10. [Datasette Full-Text Search](https://docs.datasette.io/en/stable/full_text_search.html) -- FTS5 integration in production data tools
11. [Obsidian Index Service](https://github.com/pmmvr/obsidian-index-service) -- SQLite indexing of markdown vault with MCP server exposure
12. [SQLite FTS5 Structure -- Fedor Indutny](https://darksi.de/13.sqlite-fts5-structure/) -- Internal index architecture, segment structure
13. [How Building AI Agents Has Changed in 2026](https://www.pulumi.com/blog/how-building-ai-agents-has-changed/) -- CLI-based tool calls vs MCP overhead, progressive disclosure as default
14. Prior research: `specs/721_design_targeted_literature_retrieval/reports/01_team-research.md` -- Round 1 team findings
15. Prior research: `specs/721_design_targeted_literature_retrieval/reports/02_global-local-workflow-research.md` -- Round 2 global-local workflow
