# Research Report: Task #748 — Design Zotero Extension Architecture

**Task**: 748 - Design the architecture for a new 'zotero' extension using a two-tier model
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T01:00:00Z
**Effort**: ~1.5 hours
**Dependencies**: Task 747 (Evaluate Zotero CLI Tools — completed)
**Sources/Inputs**: Codebase analysis (literature extension, core scripts, manifest schema), task 747 research report, task 747 recommendation document
**Artifacts**: specs/748_design_zotero_extension_architecture/reports/01_zotero-extension-arch.md
**Standards**: report-format.md

---

## Executive Summary

- The zotero extension should mirror the literature extension's structural pattern (manifest.json, routing, EXTENSION.md, agents, skills, scripts, commands, context) but with a distinct two-tier data model: Zotero's SQLite database as global literature source and per-repo `specs/zotero-index.json` as a relevance filter.
- Primary backend is `zot` (zotero-cli-cc v0.7.0) via shell wrappers. All reads are offline via SQLite; all writes route through the Zotero Web API using idempotency keys.
- The `--zot` flag on `/research`, `/plan`, and `/implement` provides context injection parallel to `--lit`, but driven by the per-repo index rather than a flat file directory.
- A six-field retrieval scoring algorithm (title, abstract, keywords, tags, collections, notes) with minimum-match thresholds and domain-term weighting replaces the current naive keyword overlap used by `--lit`.
- Markdown chunks can be stored as Zotero child attachments under parent item keys via `zot attach KEY --file chunk.md --idempotency-key`.
- The extension requires five script categories: CLI wrappers (3 scripts), chunk management pipeline (3 scripts), retrieval pipeline (2 scripts), index management (2 scripts), and context injection (1 script, paralleling `literature-retrieve.sh`).

---

## Context & Scope

Task 747 evaluated and selected `zotero-cli-cc` (Agents365-ai) as the primary shell backend for Zotero integration. This task designs the complete extension architecture: how the extension is structured, what scripts it needs, how context injection works, and what the per-repo index schema should look like.

Key constraints:
- Must integrate cleanly as a standard extension (manifest.json + loader pattern)
- Must not break the existing literature extension or `--lit` flag
- The `--zot` flag must parallel `--lit` in interface but differ in retrieval strategy
- Must degrade gracefully when `zot` is not installed or Zotero is not configured

---

## Findings

### 1. Existing Literature Extension Architecture (Template)

The literature extension (`/home/benjamin/.config/nvim/.claude/extensions/literature/`) provides the complete structural template. Its anatomy:

```
.claude/extensions/literature/
├── manifest.json           # Extension metadata + routing + merge_targets
├── EXTENSION.md            # Content injected into .claude/CLAUDE.md
├── README.md               # Human-facing documentation
├── agents/
│   └── literature-agent.md # Agent for /literature command (direct execution pattern)
├── commands/
│   ├── literature.md       # /literature command
│   └── cite.md             # /cite command
├── skills/
│   ├── skill-literature/   # Direct execution skill for /literature
│   │   └── SKILL.md
│   └── skill-cite/         # Direct execution skill for /cite
│       └── SKILL.md
└── scripts/
    ├── zotero-search.sh    # CSL-JSON library search (existing, repurposed)
    └── cite-extract.sh     # Citation pattern extraction from artifacts
```

Key patterns from the literature manifest:
- `"routing_exempt": true` — the literature extension does not register routing entries because it provides infrastructure (the `/literature` command), not a task type.
- `"dependencies": ["core", "filetypes"]` — depends on core + filetypes for conversion tools.
- `"provides": { "scripts": [...] }` — cross-repo scripts declared in provides.scripts.
- The `merge_targets.claudemd` pattern injects EXTENSION.md content into `.claude/CLAUDE.md`.

The zotero extension should use `"routing_exempt": true` as well — it is infrastructure (the `/zotero` command + `--zot` flag), not a task type.

### 2. Task 747 Results: Chosen CLI Tool

**Selected primary tool**: `zotero-cli-cc` (Agents365-ai), `zot` command, v0.7.0.

**Key capabilities confirmed via live testing**:
- `zot search "query"` — SQLite keyword search, offline, 880-item library tested at 922ms
- `zot --json read KEY` — full item metadata JSON, stable `{ok, data, meta}` envelope
- `zot pdf KEY --pages N-M` — page-granular text extraction from filesystem
- `zot pdf KEY --outline` — document outline (headings) extraction
- `zot pdf KEY --annotations` — PDF annotation/highlight extraction
- `zot note KEY --add "text" --dry-run` — note writeback preview, Web API path
- `zot attach KEY --file chunk.md --dry-run` — child attachment preview, confirmed working
- `zot --json stats` — library overview (880 items, 870 PDFs, 13 collections)
- `zot collection list` — collection hierarchy with nested children

**Configuration requirement**: `ZOT_DATA_DIR` env var must be set when Zotero is not at `~/Zotero/` (NixOS users frequently use `~/Documents/Zotero/`). Extension setup must detect and persist this.

**Write-back strategies confirmed**:
1. Notes: `zot note KEY --add "text"` — stored as HTML in Zotero, markdown content preserved
2. Child attachments: `zot attach KEY --file chunk.md` — raw markdown stored as sibling to PDF under same item key

### 3. Current `--lit` Implementation Analysis

The `literature-retrieve.sh` script (205 lines) implements:

**Index-driven path** (when `specs/literature/index.json` exists):
1. Extract keywords from task description (stop-word filtered, length > 3)
2. Build keyword list as jq JSON array
3. Score each index entry: `kw_score` (keyword overlap) + `summary_bonus` (1 if any keyword matches summary text)
4. Filter: `score >= 1` (MIN_SCORE)
5. Greedy-select within TOKEN_BUDGET=8000, MAX_FILES=10
6. Emit `<literature-context>` block with file content

**Fallback path** (no index, no keywords, no matches):
- Recursive file scan, token-estimate-based greedy selection

**Weaknesses of current scoring for Zotero use**:
- Binary per-keyword overlap (1/0) with no weighting across fields
- No title scoring (title matches are worth more than abstract matches)
- No tag-based relevance (Zotero's tags are high-signal domain markers)
- No collection-based relevance (Zotero collections encode user-curated groupings)
- Minimum score = 1 is too permissive (single keyword overlap triggers inclusion)

**What `--zot` retrieval should improve**:
- Multi-field weighted scoring (title > tags > abstract > keywords > collections > notes)
- Minimum match threshold of 2+ (avoid single-term false positives)
- Collection membership as a relevance signal (items in same collection as previously retrieved items score higher)
- Tag-based domain weighting (user's own tags are expert classification)

### 4. Per-Repo Local Index Schema: `specs/zotero-index.json`

The per-repo index serves as a relevance filter: it records which Zotero items are relevant to this project and caches the metadata needed for retrieval scoring without requiring Zotero to be running.

**Proposed schema**:

```json
{
  "version": "1.0",
  "created": "2026-06-19T00:00:00Z",
  "last_updated": "2026-06-19T00:00:00Z",
  "token_budget": 8000,
  "zot_data_dir": "/home/USERNAME/Documents/Zotero",
  "entries": [
    {
      "zotero_key": "Z7T6Q25X",
      "citation_key": "blackburn2001",
      "title": "Modal Logic",
      "authors": ["Blackburn, Patrick", "de Rijke, Maarten", "Venema, Yde"],
      "year": 2001,
      "item_type": "book",
      "abstract_snippet": "First 300 chars of abstract for scoring...",
      "keywords": ["modal logic", "Kripke semantics", "frame definability"],
      "tags": ["read", "reference", "logic"],
      "collections": ["Formal Tools", "Modal Logic"],
      "has_pdf": true,
      "pdf_path": "/home/USERNAME/Documents/Zotero/storage/Z7T6Q25X/Blackburn2001_ModalLogic.pdf",
      "has_chunks": true,
      "chunk_dir": "specs/literature/blackburn2001/",
      "chunk_count": 18,
      "token_count": 42000,
      "relevance_score": 0,
      "relevance_keywords": ["modal", "logic", "kripke", "frame", "completeness"],
      "added_at": "2026-06-19T00:00:00Z",
      "last_retrieved": null,
      "notes_summary": "Optional: first 200 chars of first note if available"
    }
  ]
}
```

**Field rationale**:

| Field | Purpose |
|-------|---------|
| `zotero_key` | Primary lookup key for `zot` commands (8-char alphanumeric) |
| `citation_key` | Better BibTeX citation key for cross-reference with CSL-JSON library |
| `abstract_snippet` | 300-char excerpt for retrieval scoring without reading full abstract from Zotero |
| `keywords` | Author-supplied keywords from Zotero item metadata |
| `tags` | User's Zotero tags (high-signal domain markers) |
| `collections` | Collection membership (curated groupings) |
| `has_pdf` / `pdf_path` | Whether a local PDF is available for on-demand chunking |
| `has_chunks` / `chunk_dir` | Whether markdown chunks exist for direct retrieval |
| `chunk_count` / `token_count` | For budget calculations during retrieval |
| `relevance_score` | Cached per-task score (updated at retrieval time, reset to 0) |
| `relevance_keywords` | Pre-extracted keywords for fast scoring without full re-extraction |
| `notes_summary` | Optional cached summary of Zotero notes for scoring |

**Index management**: The index is created/updated by a `zotero-index-add.sh` script that calls `zot --json read KEY` to populate metadata. Items are added explicitly by the user (not auto-discovered from the full library). The index is small (dozens to low hundreds of items per repo, not the full 880-item library).

### 5. Chunk Storage in Zotero

**Verified approach**: `zot attach KEY --file chunk.md --idempotency-key "chunk-{KEY}-{N}"` creates a child attachment under parent item key.

**Storage model for chunks**:
- Source PDFs are stored in Zotero's storage directory (`~/Documents/Zotero/storage/KEY/`)
- Markdown chunks are stored locally in `specs/literature/{doc_slug}/` (per-project) or `~/Projects/Literature/{doc_slug}/` (global)
- Optionally, markdown chunks can also be uploaded as Zotero child attachments for cross-device access
- The per-repo `specs/zotero-index.json` tracks which items have chunks and their local paths

**Chunk pipeline integration with Zotero**:
1. User runs `/zotero --convert KEY` (new command analogous to `/literature --convert`)
2. Extension calls `zot pdf KEY` to extract full text via filesystem
3. `literature-chunk.sh` (existing script, reused) splits into logical sections
4. Chunks saved to `specs/literature/{citation_key}/`
5. Per-repo `specs/zotero-index.json` updated with `has_chunks=true`, `chunk_dir`, `chunk_count`, `token_count`
6. Optional: upload chunks as Zotero child attachments via `zot attach KEY --file chunk.md`
7. `literature-build-index.sh --local` rebuilds the SQLite FTS5 database

**Ordering metadata in Zotero child attachments**: `zot attach` stores the file as-is; ordering metadata should be embedded in the filenames (`section01_intro.md`, `section02_syntax.md`) rather than in Zotero attachment tags (fragile and unreliable across Zotero versions).

### 6. Retrieval Scoring Algorithm

The `--zot` retrieval algorithm should use weighted multi-field scoring from the per-repo index:

```
score(item, query_terms) =
    title_score    * 4   # highest signal: query term appears in title
  + tag_score      * 3   # user's curated tags: expert classification
  + abstract_score * 2   # author-provided description
  + keyword_score  * 2   # author-supplied keywords
  + collection_score * 1 # collection membership (broad signal)
  + notes_score    * 1   # user's own notes on the item
```

**Per-field scoring**:
- Title: +1 per unique query term that appears (case-insensitive, substring or word match)
- Tags: +1 per tag that partially or fully matches a query term
- Abstract snippet: +1 per unique query term that appears in abstract
- Keywords: +1 per keyword that partially or fully matches a query term
- Collections: +1 if any collection name contains a query term
- Notes summary: +1 if any query term appears in notes summary

**Minimum threshold**: `total_score >= 4` (compared to `>= 1` in `--lit`). This prevents single-term false positives.

**Domain-term weighting**: The query extraction step should use domain-term boosting. For task descriptions that contain mathematical/scientific terms (detected via a configurable domain-terms list or simple heuristic based on term length and rarity), those terms get multiplied by 1.5 in scoring.

**Relevance signals not in `--lit`**:
- Collection membership means a user has explicitly curated this item into a topic area
- User tags are expert-applied classification signals that proxy for relevance
- Notes summary captures what the user found important about the item

**Token budget**: Use TOKEN_BUDGET=8000 (same as `--lit`). When chunks exist, prefer individual section chunks over full-document retrieval. When no chunks exist but PDF is available, emit a metadata-only context block with abstract and a note about how to convert.

### 7. Extension Manifest and Routing

**Proposed `manifest.json`**:

```json
{
  "name": "zotero",
  "version": "1.0.0",
  "description": "Zotero library integration via zot (zotero-cli-cc). Two-tier model: Zotero as global source, per-repo index as relevance filter. Provides /zotero command and --zot context injection flag.",
  "dependencies": ["core", "literature"],
  "routing_exempt": true,
  "provides": {
    "agents": [
      "zotero-agent.md"
    ],
    "commands": [
      "zotero.md"
    ],
    "skills": [
      "skill-zotero"
    ],
    "scripts": [
      "scripts/zotero-read.sh",
      "scripts/zotero-write.sh",
      "scripts/zotero-setup.sh",
      "scripts/zotero-chunk.sh",
      "scripts/zotero-attach-chunks.sh",
      "scripts/zotero-index-add.sh",
      "scripts/zotero-index-remove.sh",
      "scripts/zotero-retrieve.sh",
      "scripts/zotero-search-index.sh"
    ],
    "context": [
      "project/zotero"
    ],
    "rules": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_zotero"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "keyword_overrides": {
    "zotero": "meta",
    "bibliography": "meta",
    "citation": "meta",
    "literature": "meta"
  },
  "hooks": {}
}
```

**Dependency on `literature`**: The zotero extension depends on the literature extension because it reuses `literature-chunk.sh`, `literature-build-index.sh`, `literature-search.sh`, and `literature-ingest.sh` for the chunk management pipeline. It should not duplicate these.

**`routing_exempt: true`**: Like literature, zotero is an infrastructure extension, not a task type. Tasks don't have `task_type: "zotero"`.

**`keyword_overrides`**: When a task description contains "Zotero", "bibliography", or "citation", the task type should resolve to `meta` (since this extension produces meta-type work: managing the agent infrastructure). This prevents routing to nonexistent zotero-specific research/implementation skills.

### 8. Script Architecture

The nine scripts divide into five categories:

#### Category A: CLI Wrappers (3 scripts)

**`zotero-read.sh`** — Read operations via `zot` (offline, no auth):
```
Usage: zotero-read.sh <operation> <key> [options]
Operations: search, item, pdf, note, tag, collection, stats
Output: JSON from zot's {ok, data, meta} envelope parsed to stdout
Sets ZOT_DATA_DIR from config before any call
```

**`zotero-write.sh`** — Write operations via `zot` Web API (requires auth):
```
Usage: zotero-write.sh <operation> <key> [options]
Operations: note-add, tag-add, tag-remove, attach-file
Requires: ZOT_API_KEY in config or ZOTERO_API_KEY env var
Uses --idempotency-key for all write operations
Uses --dry-run for preview mode
```

**`zotero-setup.sh`** — One-time setup and validation:
```
Usage: zotero-setup.sh [--detect|--configure|--validate|--status]
--detect: Find Zotero data directory (checks ~/Zotero, ~/Documents/Zotero, XDG_DATA_HOME, registry)
--configure: Run zot config init and persist ZOT_DATA_DIR
--validate: Check zot is installed, ZOT_DATA_DIR is valid, SQLite is readable
--status: Show current configuration and library stats
```

#### Category B: Chunk Management Pipeline (3 scripts)

**`zotero-chunk.sh`** — Extract and chunk PDF via `zot`:
```
Usage: zotero-chunk.sh <zotero_key> [--output-dir DIR] [--pages N-M]
Step 1: zotero-read.sh item KEY -> get citation_key, title, authors, year
Step 2: zot pdf KEY -> full text (or --pages for page-granular)
Step 3: literature-chunk.sh (existing) -> split into logical sections
Step 4: Save to specs/literature/{citation_key}/ or LITERATURE_DIR/{citation_key}/
Step 5: Update specs/zotero-index.json (has_chunks=true, chunk_dir, chunk_count, token_count)
Step 6: literature-build-index.sh --local (rebuild FTS5 database)
```

**`zotero-attach-chunks.sh`** — Upload markdown chunks as Zotero child attachments:
```
Usage: zotero-attach-chunks.sh <zotero_key> [--dry-run]
Reads chunk_dir from specs/zotero-index.json for the given key
For each chunk file: zotero-write.sh attach-file KEY chunk.md --idempotency-key "chunk-KEY-N"
Reports success/failure per chunk
```

**`zotero-index-add.sh`** — Add an item to the per-repo index:
```
Usage: zotero-index-add.sh <zotero_key> [--tags TAG1,TAG2]
Step 1: zotero-read.sh item KEY -> full metadata
Step 2: Extract: title, authors, year, abstract (first 300 chars), keywords, tags, collections
Step 3: Resolve PDF path via SQLite attachment query
Step 4: Add/update entry in specs/zotero-index.json
Step 5: Optionally auto-chunk if --chunk flag passed
```

#### Category C: Index Management (2 scripts)

**`zotero-index-remove.sh`** — Remove an item from the per-repo index:
```
Usage: zotero-index-remove.sh <zotero_key> [--delete-chunks]
Remove entry from specs/zotero-index.json
Optional: delete associated chunk files from specs/literature/{citation_key}/
```

**`zotero-search-index.sh`** — Search the per-repo index (for agent and human use):
```
Usage: zotero-search-index.sh "query" [--limit N] [--format json|pretty]
Implements the multi-field scoring algorithm against specs/zotero-index.json
Falls back to full Zotero search via zotero-read.sh if index is empty
Returns scored, ranked list of matching items
```

#### Category D: Context Injection (1 script)

**`zotero-retrieve.sh`** — The `--zot` flag context injection script (parallel to `literature-retrieve.sh`):
```
Usage: zotero-retrieve.sh <description> <task_type>
Output: <zotero-context> block on stdout, empty on failure

Algorithm:
1. Load specs/zotero-index.json
2. Extract query keywords from description (stop-word filtered)
3. Score each index entry using multi-field weighted scoring
4. Filter: total_score >= 4
5. Sort by score descending
6. Greedy-select within TOKEN_BUDGET=8000, MAX_FILES=8:
   - If entry has_chunks: include relevant chunk(s) via literature-search.sh
   - If entry no_chunks but has_pdf: include metadata block + abstract
   - If no_pdf: include metadata block only
7. Emit <zotero-context> block
```

The `--zot` flag integration requires the skill-base.sh or preflight hook mechanism to call `zotero-retrieve.sh` the same way `--lit` calls `literature-retrieve.sh`. The flag should be parsed by `command-route-skill.sh` and threaded through skill dispatch.

### 9. Command Surface: `/zotero`

The `/zotero` command provides a single entry point for all operations, parallel to `/literature`:

| Sub-command | Usage | Description |
|-------------|-------|-------------|
| (bare) | `/zotero` | Status: index health, item count, library connectivity |
| `--setup` | `/zotero --setup` | Run setup wizard: detect data dir, validate, init Web API key |
| `--add KEY` | `/zotero --add Z7T6Q25X` | Add item to per-repo index |
| `--remove KEY` | `/zotero --remove Z7T6Q25X` | Remove item from per-repo index |
| `--convert KEY` | `/zotero --convert Z7T6Q25X` | Extract PDF, chunk, update index |
| `--attach KEY` | `/zotero --attach Z7T6Q25X` | Upload chunks as Zotero child attachments |
| `--search QUERY` | `/zotero --search "modal logic"` | Search library, add results to index interactively |
| `--sync` | `/zotero --sync` | Refresh index metadata from current Zotero state |
| `--validate` | `/zotero --validate` | Validate index entries (PDF paths, chunk counts) |
| `--status` | `/zotero --status` | Full library stats and index health |

### 10. Context Injection Hook Integration

The `--zot` flag must integrate into the existing hook/preflight system. The skill-base.sh pattern calls `memory-retrieve.sh` and `literature-retrieve.sh` based on presence of `--clean` and `--lit` flags.

**Required change**: Add `--zot` flag parsing in `command-route-skill.sh` (or equivalent) that calls `zotero-retrieve.sh <description> <task_type>` and injects the result as `<zotero-context>` after `<memory-context>` and `<literature-context>`.

**Flag precedence order** (in injected context):
1. `<memory-context>` — from memory-retrieve.sh
2. `<literature-context>` — from literature-retrieve.sh (when `--lit`)
3. `<zotero-context>` — from zotero-retrieve.sh (when `--zot`)

**Interaction with `--clean`**: `--clean` suppresses memory retrieval. It should NOT suppress `--zot` context (the same way `--clean --lit` works: clean suppresses memory but not literature). The user must explicitly omit `--zot` to suppress Zotero context.

---

## Decisions

- **Selected tool**: `zot` (zotero-cli-cc v0.7.0) as sole primary backend. No dependency on zotero-mcp.
- **Per-repo index schema**: `specs/zotero-index.json` with the 18-field schema defined above.
- **Chunk storage**: Local-first (specs/literature/ or LITERATURE_DIR). Zotero child attachment upload is optional, not required.
- **Retrieval scoring**: Multi-field weighted scoring (title*4, tags*3, abstract*2, keywords*2, collections*1, notes*1) with minimum threshold of 4.
- **Script count**: 9 scripts in 4 categories. No script duplication with existing literature scripts.
- **Command surface**: `/zotero` with 8 sub-modes, parallel to `/literature`.
- **Extension dependency**: `literature` (for reuse of chunk and index-building scripts).
- **Routing**: `routing_exempt: true` — zotero is infrastructure, not a task type.
- **`--zot` flag**: Parallels `--lit`; calls `zotero-retrieve.sh`; not suppressed by `--clean`.
- **ZOT_DATA_DIR handling**: Extension setup must detect and persist the data directory. Should be stored in `.claude/settings.json` or `specs/zotero-index.json` top-level field.
- **Ordering metadata in chunks**: Use filename-based ordering (`section01_intro.md`) not Zotero attachment tags.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `zot` not installed on agent invocation | Medium | `zotero-retrieve.sh` checks for `zot` with `command -v zot`; exits 1 with empty output if not found (graceful degradation) |
| ZOT_DATA_DIR not set or wrong path | Medium | `zotero-setup.sh --validate` provides diagnostic. Extension status mode warns if not configured. |
| Per-repo index empty (no items added) | Low | `zotero-retrieve.sh` emits empty context if index is empty; no error |
| AGPL-3.0 copyleft (zotero-cli-cc) | Medium | Shell scripts wrapping CLI are not linked to the library; review licensing if extension is distributed externally |
| Web API key missing for write operations | Low | Read operations (which `--zot` uses) require no auth. Write ops in `/zotero --attach` warn if no key. |
| Zotero data dir auto-detection on NixOS | Low | `zotero-setup.sh --detect` checks multiple paths; extension docs note common NixOS path |
| Token budget overrun | Low | Same TOKEN_BUDGET=8000 as `--lit`; chunk-level retrieval enables fine-grained selection |
| Chunk FTS5 database stale | Low | `zotero-chunk.sh` always rebuilds FTS5 index after chunking |
| Literature extension version drift | Low | Only reuse stable scripts (chunk, build-index); document dependency contract in extension README |

---

## Context Extension Recommendations

- **Topic**: Per-repo Zotero index conventions for Claude Code projects
- **Gap**: Once built, agents need to know how to add items, when to use `--zot`, and the index schema
- **Recommendation**: Add `.claude/extensions/zotero/context/project/zotero/domain/zotero-index.md` documenting the schema and workflow

- **Topic**: `--zot` flag usage guide for agents
- **Gap**: Agents need to know when to suggest `--zot` vs `--lit` to users
- **Recommendation**: Add `.claude/extensions/zotero/context/project/zotero/patterns/retrieval-flags.md` documenting when each flag is appropriate

---

## Appendix

### Extension Directory Layout

```
.claude/extensions/zotero/
├── manifest.json
├── EXTENSION.md
├── README.md
├── index-entries.json
├── agents/
│   └── zotero-agent.md           # Direct execution documentation agent
├── commands/
│   └── zotero.md                 # /zotero command (8 sub-modes)
├── skills/
│   └── skill-zotero/
│       └── SKILL.md              # Direct execution skill
├── scripts/
│   ├── zotero-read.sh            # CLI wrapper: reads via SQLite
│   ├── zotero-write.sh           # CLI wrapper: writes via Web API
│   ├── zotero-setup.sh           # Setup wizard and validation
│   ├── zotero-chunk.sh           # PDF -> chunks pipeline
│   ├── zotero-attach-chunks.sh   # Upload chunks as Zotero attachments
│   ├── zotero-index-add.sh       # Add item to per-repo index
│   ├── zotero-index-remove.sh    # Remove item from per-repo index
│   ├── zotero-retrieve.sh        # --zot flag context injection
│   └── zotero-search-index.sh    # Search per-repo index
└── context/
    └── project/
        └── zotero/
            ├── domain/
            │   └── zotero-index.md     # Index schema + workflow reference
            └── patterns/
                └── retrieval-flags.md  # When to use --zot vs --lit
```

### Per-Repo Index: Full JSON Schema

```json
{
  "$schema": "specs/zotero-index.schema.json",
  "version": "1.0",
  "created": "ISO8601",
  "last_updated": "ISO8601",
  "zot_data_dir": "/path/to/Zotero/data",
  "token_budget": 8000,
  "entries": [
    {
      "zotero_key": "Z7T6Q25X",
      "citation_key": "blackburn2001",
      "title": "Modal Logic",
      "authors": ["Blackburn, Patrick", "de Rijke, Maarten"],
      "year": 2001,
      "item_type": "book",
      "abstract_snippet": "First 300 chars...",
      "keywords": ["modal logic", "completeness"],
      "tags": ["read", "reference"],
      "collections": ["Formal Tools"],
      "has_pdf": true,
      "pdf_path": "/path/to/storage/Z7T6Q25X/paper.pdf",
      "has_chunks": false,
      "chunk_dir": null,
      "chunk_count": 0,
      "token_count": 0,
      "relevance_keywords": ["modal", "kripke", "frame"],
      "notes_summary": null,
      "added_at": "2026-06-19T00:00:00Z",
      "last_retrieved": null
    }
  ]
}
```

### Retrieval Scoring Algorithm (Pseudocode)

```bash
# zotero-retrieve.sh scoring logic
score_item() {
  local item="$1"
  local terms="$2"  # jq array

  jq --argjson terms "$terms" '
    def score_field(text; weight):
      if text == null or text == "" then 0
      else
        (text | ascii_downcase) as $t |
        reduce $terms[] as $term (0;
          if ($t | test($term; "i")) then . + weight else . end
        )
      end;

    def array_score(arr; weight):
      if arr == null then 0
      else
        reduce arr[] as $item (0;
          score_field($item; weight)
        )
      end;

    (score_field(.title; 4) +
     array_score(.tags; 3) +
     score_field(.abstract_snippet; 2) +
     array_score(.keywords; 2) +
     array_score(.collections; 1) +
     score_field(.notes_summary; 1)) as $total |
    select($total >= 4) |
    . + {score: $total}
  ' <<< "$item"
}
```

### Downstream Tasks (748's output drives)

- Task 749: Create zotero extension skeleton (manifest, directory structure)
- Task 750: Implement zotero CLI wrapper scripts (zotero-read.sh, zotero-write.sh, zotero-setup.sh)
- Task 751: Implement zotero search local index (zotero-index-add.sh, zotero-index-remove.sh, zotero-search-index.sh)
- Task 752: Implement on-demand PDF markdown conversion (zotero-chunk.sh, zotero-attach-chunks.sh)
- Task 753: Implement zotero context injection (zotero-retrieve.sh, --zot flag integration)

### Key Script References (Existing, Reusable)

- `/home/benjamin/.config/nvim/.claude/scripts/literature-chunk.sh` — Reuse for step 3 of zotero-chunk.sh
- `/home/benjamin/.config/nvim/.claude/scripts/literature-build-index.sh` — Reuse for FTS5 rebuild
- `/home/benjamin/.config/nvim/.claude/scripts/literature-search.sh` — Reuse for chunk retrieval in zotero-retrieve.sh
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` — Pattern template for zotero-retrieve.sh
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/zotero-search.sh` — CSL-JSON search (existing, can coexist)
