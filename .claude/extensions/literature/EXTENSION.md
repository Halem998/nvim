## Literature Extension

Unified extension for managing the global Literature/ repository (`~/Projects/Literature/`) and
per-repo sub-indices (`specs/literature-index.json`). Handles source discovery, PDF/DJVU
conversion, FTS5-backed search, and agent context briefing. Absorbs the former zotero extension.

### Global Repository and Per-Repo Sub-Index

The global Literature/ repo is the single source of truth for all converted literature:
- `$LITERATURE_DIR/index.json` — Enriched v2 metadata (222+ entries)
- `$LITERATURE_DIR/sources/` — Converted markdown organized by document
- `$LITERATURE_DIR/.literature.db` — SQLite FTS5 full-text search database
- `$LITERATURE_DIR/zotero-library.json` — Better BibTeX CSL-JSON auto-export

Each project maintains a lightweight reference index at `specs/literature-index.json` listing
which global documents are relevant. Entries are reference-only (`doc_id` pointers); no metadata
is cached locally. This index is read by `literature-briefing.sh` at skill preflight time.

### Briefing+Tools Agent Pattern

The `--lit` flag injects a compact `<literature-briefing>` block (~300-500 tokens) into agent
prompts instead of full content. Agents use existing tools for on-demand access:
- **Read specific chunks**: `Read` tool with absolute paths from the briefing
- **Search full corpus**: `bash .claude/scripts/literature-search.sh "query"`
- **Browse TOC**: `bash .claude/scripts/literature-search.sh --toc doc_id`

**Cost**: ~300 tokens briefing (vs 4,000-8,000 tokens for full injection). Total session cost
depends on how many searches/reads the agent performs, but selectivity is always better than
blind injection.

**No `--zot` flag**: The former `--zot` flag was never wired and has been removed. All Zotero
functionality is accessed via Mode A discovery or the `zotero-search.sh` script directly.

### Two-Mode /literature Command

**Mode A (Discover)**: When called with a task number or search query, runs a three-tier
discovery pipeline via `literature-discover.sh`:
1. Tier 1 (offline): Search `$LITERATURE_DIR/index.json`
2. Tier 2 (local): Search Zotero library (`zotero-library.json`)
3. Tier 3 (online): Semantic Scholar API, Unpaywall DOI lookup, arXiv

Results are shown interactively. Selected items are added to `specs/literature-index.json`.
Unresolved items are appended to `specs/literature/SOURCES.md`.

**Mode B (Integrate)**: When called with a file path or bare (no args), runs the ingestion
pipeline via `literature-ingest.sh`. Converts PDFs/DJVUs, indexes in FTS5, and updates
`specs/literature-index.json`.

Detection: path-like args -> Mode B; numeric/text args -> Mode A; no args -> Mode B (status).

### Centralized Repository

`LITERATURE_DIR` defaults to `~/Projects/Literature` (via `$HOME`;
`literature-discover.sh:36`: `LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"`).
It is an optional override env var / settings key: set `LITERATURE_DIR=/path/to/repo` in
`.claude/settings.json` if you want to point at a different centralized repository. The `--lit`
flag and `/literature` commands operate on whichever directory `LITERATURE_DIR` resolves to.
When `LITERATURE_DIR` is set, content directories use a `sources/` subdirectory prefix.

**Two-tier fallback**: If `LITERATURE_DIR` is set but the directory does not exist, the system
falls back to per-project `specs/literature/`. If `LITERATURE_DIR` is unset, per-project
directories are used directly.

### Zotero Integration (Unified)

Full Zotero library management is part of this extension (absorbed from former zotero extension).
Uses Better BibTeX CSL-JSON auto-export for search, and optionally the `zot` CLI for direct
library access.

**Setup**: File > Export Library in Zotero > Better CSL JSON > "Keep updated" >
save to `~/Projects/Literature/zotero-library.json`.

| Script | Purpose |
|--------|---------|
| `zotero-search.sh` | Search CSL-JSON export by keyword (used by Mode A) |
| `zotero-read.sh` | Read item metadata and PDFs via `zot` CLI |
| `zotero-write.sh` | Write/attach files to Zotero items |
| `zotero-setup.sh` | Setup wizard: detect data dir, validate, configure |
| `zotero-chunk.sh` | Extract PDF text and chunk into sections |
| `zotero-attach-chunks.sh` | Upload chunks as Zotero child attachments |
| `zotero-index-add.sh` | Add item to per-repo `specs/literature-index.json` |
| `zotero-index-remove.sh` | Remove item from per-repo index |
| `cite-extract.sh` | Extract citation patterns from markdown artifacts |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-literature | (direct execution) | Scan, convert, validate, index, discover, and integrate literature |
| skill-cite | (direct execution) | Verify citation claims against Literature/ and Zotero |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/literature` | `/literature` | Show status and index health (Mode B) |
| `/literature` | `/literature N` | Discover sources relevant to task N (Mode A) |
| `/literature` | `/literature "query"` | Discover sources matching query (Mode A) |
| `/literature` | `/literature ~/path/to/file.pdf` | Ingest specific PDF/DJVU (Mode B) |
| `/literature` | `/literature ~/dir/` | Ingest all PDFs in directory (Mode B) |
| `/literature` | `/literature --validate` | Validate sub-index against global index |

### /cite Command

Verify citation claims in task artifacts against the Literature/ index and Zotero library.
Extracts citations, scores each against available sources, and creates research tasks for claims
that cannot be verified.

| Command | Usage | Description |
|---------|-------|-------------|
| `/cite` | `/cite N` | Verify all citations in task N artifacts |
| `/cite` | `/cite N --gaps` | Also flag citations found in Zotero but lacking a PDF |

**Workflow**: Extract citation patterns from task markdown -> Match against index.json and
zotero-library.json -> Score by confidence (confirmed/partial/unconfirmed/gap) -> Interactive
selection -> Create research tasks for unverified claims.

**Dependencies**: `cite-extract.sh` (pattern extraction), `zotero-search.sh` (Zotero search,
optional). Both degrade gracefully when sources are unavailable.
