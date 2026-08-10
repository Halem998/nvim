# Architecture Design: Zotero Extension

**Task**: 748 — Design Zotero Extension Architecture
**Date**: 2026-06-19
**Status**: Design complete — drives tasks 749–753

---

## Table of Contents

1. [Overview and Design Principles](#1-overview-and-design-principles)
2. [Extension Manifest Schema](#2-extension-manifest-schema)
3. [Directory Layout](#3-directory-layout)
4. [Per-Repo Index Schema](#4-per-repo-index-schema)
5. [Script Architecture](#5-script-architecture)
6. [Retrieval Scoring Algorithm](#6-retrieval-scoring-algorithm)
7. [Command Surface: /zotero](#7-command-surface-zotero)
8. [Flag Integration: --zot](#8-flag-integration---zot)
9. [Coexistence Strategy: --zot and --lit](#9-coexistence-strategy---zot-and---lit)
10. [Downstream Task Map](#10-downstream-task-map)
11. [Configuration and Setup](#11-configuration-and-setup)

---

## 1. Overview and Design Principles

### Two-Tier Data Model

The zotero extension uses a **two-tier data model** that separates global library access from per-project relevance:

| Tier | Location | Purpose |
|------|----------|---------|
| **Tier 1 (Global)** | Zotero SQLite database (`~/Documents/Zotero/zotero.sqlite`) | Full library: all items, metadata, PDFs |
| **Tier 2 (Per-repo)** | `specs/zotero-index.json` | Relevance filter: which items matter to this project |

This model means:
- The full Zotero library (880+ items in the reference case) is never scanned wholesale for relevance. Agents work from the per-repo index.
- Per-repo index entries are added explicitly by the user via `/zotero --add KEY`, not auto-discovered.
- Retrieval scoring operates on cached metadata in the per-repo index — Zotero itself is not queried during `--zot` context injection.
- The per-repo index is small (dozens to low hundreds of items), enabling fast jq-based scoring.

### Design Goals

1. **Offline-first reads**: All context injection and retrieval scoring operates on local data (SQLite or cached per-repo index). No network calls during agent invocation.
2. **Parallel to `--lit`**: The `--zot` flag mirrors the `--lit` flag in interface and injection order. Users switch seamlessly between the two.
3. **Infrastructure extension**: Like the literature extension, zotero is `routing_exempt: true`. It does not define a task type; it provides infrastructure (the `/zotero` command and `--zot` flag).
4. **Reuse existing scripts**: The extension depends on the literature extension and reuses `literature-chunk.sh`, `literature-build-index.sh`, and `literature-search.sh`. No duplication.
5. **Graceful degradation**: When `zot` is not installed, `ZOT_DATA_DIR` is not set, or the per-repo index is empty, all operations degrade gracefully (empty output, not errors that block agent execution).
6. **No mutual exclusion**: `--zot` and `--lit` can be active simultaneously. Both inject their respective context blocks, each within its own token budget.

### Relationship to the Literature Extension

The literature extension (`/literature`, `--lit`, `specs/literature/`) operates on a flat directory of markdown files that the user has manually converted. The zotero extension replaces the manual step with a structured pipeline: Zotero item key → `zot pdf` text extraction → `literature-chunk.sh` splitting → `specs/literature/{citation_key}/` storage.

The zotero extension depends on `literature` in its manifest. The chunk storage location (`specs/literature/{citation_key}/`) is intentionally shared with the literature extension's storage convention so that `--lit` and `--zot` can retrieve the same chunk files using different selection mechanisms.

---

## 2. Extension Manifest Schema

File path: `.claude/extensions/zotero/manifest.json`

```json
{
  "name": "zotero",
  "version": "1.0.0",
  "description": "Zotero library integration via zot (zotero-cli-cc v0.7.0). Two-tier model: Zotero SQLite as global source, per-repo specs/zotero-index.json as relevance filter. Provides /zotero command and --zot context injection flag.",
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
    "citation": "meta"
  },
  "hooks": {}
}
```

### Field Documentation

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Extension identifier; used in loader and dependency resolution |
| `version` | string | SemVer; bump when breaking changes to scripts or index schema |
| `description` | string | Human-readable summary injected into extension picker UI |
| `dependencies` | array | `"core"` for base infrastructure; `"literature"` for reuse of chunk/index scripts. Auto-loaded in dependency order. |
| `routing_exempt` | boolean | `true` — zotero is infrastructure, not a task type. No routing table entries are added. |
| `provides.agents` | array | Agent definition files installed into `.claude/agents/` |
| `provides.commands` | array | Command files installed into `.claude/commands/` |
| `provides.skills` | array | Skill directories installed into `.claude/skills/` |
| `provides.scripts` | array | Shell scripts copied to `.claude/scripts/`. Must match scripts documented in Section 5. |
| `provides.context` | array | Context directory trees. `"project/zotero"` installs to `.claude/context/project/zotero/` |
| `provides.rules` | array | Empty — no auto-applied Lua rules |
| `provides.hooks` | array | Empty — lifecycle hooks declared in top-level `hooks` object if needed |
| `merge_targets.claudemd` | object | Merges `EXTENSION.md` into `.claude/CLAUDE.md` under section ID `extension_zotero` |
| `merge_targets.index` | object | Merges `index-entries.json` into `.claude/context/index.json` for agent context discovery |
| `keyword_overrides` | object | Keywords in task descriptions that resolve to `meta` task type instead of triggering keyword table lookup |
| `hooks` | object | Empty; lifecycle hook scripts (preflight, postflight) added here if needed in future |

### Manifest Constraint: provides.scripts Alignment

The `provides.scripts` array must exactly match the 9 scripts documented in Section 5. When adding or removing a script, both the manifest and Section 5 of this document must be updated atomically.

---

## 3. Directory Layout

```
.claude/extensions/zotero/
├── manifest.json                       # Extension metadata (Section 2)
├── EXTENSION.md                        # Content merged into .claude/CLAUDE.md
├── README.md                           # Human-facing setup and usage guide
├── index-entries.json                  # Context entries merged into .claude/context/index.json
├── agents/
│   └── zotero-agent.md                # Direct execution agent for /zotero command
├── commands/
│   └── zotero.md                      # /zotero command (10 sub-modes, Section 7)
├── skills/
│   └── skill-zotero/
│       └── SKILL.md                   # Direct execution skill
├── scripts/
│   ├── zotero-read.sh                 # Category A: CLI Wrappers (Section 5)
│   ├── zotero-write.sh
│   ├── zotero-setup.sh
│   ├── zotero-chunk.sh                # Category B: Chunk Management
│   ├── zotero-attach-chunks.sh
│   ├── zotero-index-add.sh            # Category C: Index Management
│   ├── zotero-index-remove.sh
│   ├── zotero-search-index.sh
│   └── zotero-retrieve.sh             # Category D: Context Injection
└── context/
    └── project/
        └── zotero/
            ├── domain/
            │   └── zotero-index.md    # Index schema + workflow for agents
            └── patterns/
                └── retrieval-flags.md # When to use --zot vs --lit
```

**Per-repo artifacts** (not part of extension directory; created at project level):

```
{project-root}/
└── specs/
    └── zotero-index.json              # Per-repo relevance filter (Section 4)
```

---

## 4. Per-Repo Index Schema

File path: `specs/zotero-index.json` (at project root, committed to repo)

### Top-Level Fields

| Field | Type | Required | Purpose | Default | Example |
|-------|------|----------|---------|---------|---------|
| `version` | string | yes | Schema version for migration | — | `"1.0"` |
| `created` | string (ISO8601) | yes | When index was first created | — | `"2026-06-19T00:00:00Z"` |
| `last_updated` | string (ISO8601) | yes | When index was last modified | — | `"2026-06-19T12:34:56Z"` |
| `token_budget` | integer | yes | Default token budget for retrieval | `8000` | `8000` |
| `zot_data_dir` | string | yes | Absolute path to Zotero data directory | detected at setup | `"/home/user/Documents/Zotero"` |
| `entries` | array | yes | Array of index entry objects | `[]` | — |

### Entry-Level Fields (18 fields)

| Field | Type | Required | Purpose | Default | Example |
|-------|------|----------|---------|---------|---------|
| `zotero_key` | string | yes | 8-char Zotero item key. Primary lookup for `zot` commands. | — | `"Z7T6Q25X"` |
| `citation_key` | string | yes | Better BibTeX key for cross-reference with CSL-JSON library and chunk directory naming | — | `"blackburn2001"` |
| `title` | string | yes | Item title for retrieval scoring (title_score weight=4) | — | `"Modal Logic"` |
| `authors` | array[string] | yes | Author list in "Last, First" format. Not scored; used for display. | — | `["Blackburn, Patrick"]` |
| `year` | integer | yes | Publication year. Not scored; used for display and citation formatting. | — | `2001` |
| `item_type` | string | yes | Zotero item type. Values: `book`, `journalArticle`, `conferencePaper`, `thesis`, etc. | — | `"book"` |
| `abstract_snippet` | string | no | First 300 chars of abstract. Used for abstract_score (weight=2). Null if no abstract. | `null` | `"An introduction to modal logic..."` |
| `keywords` | array[string] | no | Author-supplied keywords from Zotero item metadata. Used for keyword_score (weight=2). | `[]` | `["modal logic", "Kripke semantics"]` |
| `tags` | array[string] | no | User's Zotero tags. High-signal: expert classification applied by the user. Used for tag_score (weight=3). | `[]` | `["read", "reference", "logic"]` |
| `collections` | array[string] | no | Collection names the item belongs to. User-curated groupings. Used for collection_score (weight=1). | `[]` | `["Formal Tools", "Modal Logic"]` |
| `has_pdf` | boolean | yes | Whether a local PDF is available in Zotero storage. | `false` | `true` |
| `pdf_path` | string | no | Absolute path to PDF in Zotero storage. Null if `has_pdf` is false. | `null` | `"/home/user/Zotero/storage/Z7T6Q25X/paper.pdf"` |
| `has_chunks` | boolean | yes | Whether markdown chunks exist for this item at `chunk_dir`. | `false` | `true` |
| `chunk_dir` | string | no | Relative path (from project root) to chunk directory. Null if `has_chunks` is false. | `null` | `"specs/literature/blackburn2001/"` |
| `chunk_count` | integer | yes | Number of chunk files. 0 if no chunks. Used for budget pre-estimation. | `0` | `18` |
| `token_count` | integer | yes | Total estimated tokens across all chunks. 0 if no chunks. Used for budget pre-estimation. | `0` | `42000` |
| `relevance_keywords` | array[string] | no | Pre-extracted topic keywords for fast scoring. Set at index-add time, not updated per-query. | `[]` | `["modal", "logic", "kripke", "frame"]` |
| `notes_summary` | string | no | First 200 chars of first user note on the item. Used for notes_score (weight=1). Null if no notes. | `null` | `"Key reference for Kripke semantics..."` |
| `added_at` | string (ISO8601) | yes | When item was added to this index. | — | `"2026-06-19T00:00:00Z"` |
| `last_retrieved` | string (ISO8601) | no | When item was last included in context injection output. Null if never retrieved. | `null` | `"2026-06-19T12:00:00Z"` |

**Note**: The entry schema has 20 fields including `added_at` and `last_retrieved`. The "18 entry fields" figure from the research report refers to the 18 metadata fields (excluding the two timestamp management fields). Both counts are correct depending on inclusion scope.

### Full Schema Example

```json
{
  "version": "1.0",
  "created": "2026-06-19T00:00:00Z",
  "last_updated": "2026-06-19T00:00:00Z",
  "token_budget": 8000,
  "zot_data_dir": "/home/benjamin/Documents/Zotero",
  "entries": [
    {
      "zotero_key": "Z7T6Q25X",
      "citation_key": "blackburn2001",
      "title": "Modal Logic",
      "authors": ["Blackburn, Patrick", "de Rijke, Maarten", "Venema, Yde"],
      "year": 2001,
      "item_type": "book",
      "abstract_snippet": "Blackburn, de Rijke and Venema explore the theoretical background of modal logic including the basic model theory...",
      "keywords": ["modal logic", "Kripke semantics", "frame definability"],
      "tags": ["read", "reference", "logic"],
      "collections": ["Formal Tools", "Modal Logic"],
      "has_pdf": true,
      "pdf_path": "/home/benjamin/Documents/Zotero/storage/Z7T6Q25X/Blackburn2001_ModalLogic.pdf",
      "has_chunks": true,
      "chunk_dir": "specs/literature/blackburn2001/",
      "chunk_count": 18,
      "token_count": 42000,
      "relevance_keywords": ["modal", "logic", "kripke", "frame", "completeness", "bisimulation"],
      "notes_summary": "Essential reference for modal completeness and canonical model construction.",
      "added_at": "2026-06-19T00:00:00Z",
      "last_retrieved": null
    }
  ]
}
```

### Schema Versioning

When the schema changes (new fields, removed fields, type changes), increment `version` and update `zotero-index-add.sh` to handle migration. Backward compatibility: `zotero-retrieve.sh` must tolerate missing optional fields (treat as null/empty array).

---

## 5. Script Architecture

All 9 scripts reside in `.claude/extensions/zotero/scripts/` and are installed to `.claude/scripts/` by the extension loader. They follow the shared script conventions: bash shebang, `set -euo pipefail`, exit codes 0/1/2, stderr for diagnostics, stdout for output.

### Exit Code Convention

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Runtime error (file not found, parse failure, API error) |
| `2` | Not configured (zot not installed, ZOT_DATA_DIR not set, index not found) |

### Environment Variables

| Variable | Used by | Purpose |
|----------|---------|---------|
| `ZOT_DATA_DIR` | All scripts | Path to Zotero data directory. Set from `specs/zotero-index.json` top-level field or environment. |
| `ZOTERO_API_KEY` | zotero-write.sh | Web API key for write operations. Optional for read-only workflows. |
| `LITERATURE_DIR` | zotero-chunk.sh | Override for chunk storage directory. Defaults to `specs/literature/`. |
| `TOKEN_BUDGET` | zotero-retrieve.sh | Override default token budget. Defaults to index `token_budget` field or 8000. |

---

### Category A: CLI Wrappers (3 scripts)

These scripts wrap `zot` commands and handle `ZOT_DATA_DIR` configuration. They are the only scripts that call `zot` directly.

---

#### `zotero-read.sh`

**Synopsis**: Read-only operations against Zotero via `zot` (offline; reads SQLite directly).

**Usage**:
```
zotero-read.sh <operation> [key] [options...]
```

**Operations**:

| Operation | Arguments | Output |
|-----------|-----------|--------|
| `search` | `"query string"` | JSON array of matching items from `zot --json search` |
| `item` | `KEY` | Full item metadata JSON from `zot --json read KEY` |
| `pdf` | `KEY [--pages N-M]` | Plain text from `zot pdf KEY` (or page-restricted via `--pages`) |
| `outline` | `KEY` | Document outline from `zot pdf KEY --outline` |
| `annotations` | `KEY` | PDF annotations from `zot pdf KEY --annotations` |
| `note` | `KEY` | Notes for item from `zot --json note KEY` |
| `tags` | `KEY` | Tags for item from `zot --json tag KEY` |
| `collections` | — | Collection hierarchy from `zot collection list` |
| `stats` | — | Library stats from `zot --json stats` |

**Environment variables consumed**:
- `ZOT_DATA_DIR` — set before any `zot` call via `export ZOT_DATA_DIR="..."` if not already in environment

**stdout**: Raw `zot` output (JSON or plain text depending on operation)

**stderr**: Error messages, including `zot` stderr pass-through

**Exit codes**:
- `0` — Success
- `1` — `zot` returned non-zero; key not found; JSON parse error
- `2` — `zot` not installed (`command -v zot` fails) or `ZOT_DATA_DIR` not set and not detectable

**Dependencies**: `zot` (zotero-cli-cc), `ZOT_DATA_DIR`

**Called by**: `zotero-chunk.sh`, `zotero-index-add.sh`, `zotero-search-index.sh` (fallback)

---

#### `zotero-write.sh`

**Synopsis**: Write operations via Zotero Web API through `zot` (requires network and API key).

**Usage**:
```
zotero-write.sh <operation> <key> [options...]
```

**Operations**:

| Operation | Arguments | Description |
|-----------|-----------|-------------|
| `note-add` | `KEY "text"` | Add note to item via `zot note KEY --add "text"` |
| `tag-add` | `KEY TAG` | Add tag to item |
| `tag-remove` | `KEY TAG` | Remove tag from item |
| `attach-file` | `KEY FILEPATH` | Upload file as child attachment via `zot attach KEY --file FILEPATH` |

**Options**:
- `--dry-run` — Preview operation; do not execute write. Passes `--dry-run` to `zot`.
- `--idempotency-key KEY` — Idempotency key for the write operation. Required for `attach-file`. Format: `"chunk-{ZOTERO_KEY}-{N}"`.

**Environment variables consumed**:
- `ZOTERO_API_KEY` — Web API key. If unset, script exits 2 with message: "ZOTERO_API_KEY not set; run /zotero --setup".
- `ZOT_DATA_DIR` — Set before call (same as zotero-read.sh).

**stdout**: Operation result JSON from `zot`

**stderr**: Error messages, API errors, dry-run preview output

**Exit codes**:
- `0` — Success (or dry-run preview completed)
- `1` — API error; attachment upload failed; key not found
- `2` — `ZOTERO_API_KEY` not set; `zot` not installed

**Dependencies**: `zot` (zotero-cli-cc), `ZOTERO_API_KEY`, network access

**Called by**: `zotero-attach-chunks.sh`

---

#### `zotero-setup.sh`

**Synopsis**: One-time setup wizard, validation, and status reporting for the zotero extension.

**Usage**:
```
zotero-setup.sh [--detect|--configure|--validate|--status]
```

**Sub-commands**:

| Sub-command | Description |
|-------------|-------------|
| `--detect` | Auto-detect Zotero data directory. Checks in order: `$ZOT_DATA_DIR`, `~/Zotero/`, `~/Documents/Zotero/`, `$XDG_DATA_HOME/Zotero/`. Prints detected path to stdout or exits 1. |
| `--configure` | Interactive: run `zot config init`, persist detected `ZOT_DATA_DIR` to `specs/zotero-index.json` top-level field. Creates `specs/zotero-index.json` if it does not exist with empty `entries`. |
| `--validate` | Check: (1) `zot` is installed, (2) `ZOT_DATA_DIR` resolves to a directory containing `zotero.sqlite`, (3) SQLite is readable (`zot stats` succeeds). Exits 0 if all pass; exits 1 with failure details on stderr. |
| `--status` | Print human-readable configuration summary: `ZOT_DATA_DIR`, library item count, index item count, Web API key status (set/unset, not the key value). |

**stdout**: Detected path (for `--detect`), summary table (for `--status`), validation pass/fail lines (for `--validate`)

**stderr**: Error details

**Exit codes**:
- `0` — Success (detection found path; validation passed; status retrieved)
- `1` — Detection failed; validation failed; status unavailable
- `2` — `zot` not installed

**Dependencies**: `zot` (zotero-cli-cc), `jq`

**Called by**: `/zotero --setup` command, `/zotero` bare (for status check)

---

### Category B: Chunk Management Pipeline (3 scripts)

These scripts implement the PDF-to-chunks pipeline and Zotero attachment upload. They depend on Category A (CLI Wrappers) and on the literature extension's `literature-chunk.sh` and `literature-build-index.sh`.

---

#### `zotero-chunk.sh`

**Synopsis**: Extract full text from a Zotero item's PDF, chunk it into logical sections, and update the per-repo index.

**Usage**:
```
zotero-chunk.sh <zotero_key> [--output-dir DIR] [--pages N-M]
```

**Arguments**:
- `<zotero_key>` — 8-char Zotero item key (required)
- `--output-dir DIR` — Override chunk storage directory. Default: `specs/literature/{citation_key}/`
- `--pages N-M` — Restrict extraction to page range (passes `--pages` to `zot pdf`)

**Pipeline steps**:
1. Call `zotero-read.sh item KEY` → extract `citation_key`, `title`, `authors`, `year`
2. Call `zotero-read.sh pdf KEY [--pages N-M]` → full text to temp file
3. Call `literature-chunk.sh` (existing reused script) → split text into logical sections
4. Save chunks to `specs/literature/{citation_key}/` with filename ordering: `section01_intro.md`, `section02_methods.md`, etc.
5. Count chunks and estimate total tokens (line count × 4 as approximation)
6. Update `specs/zotero-index.json`: set `has_chunks=true`, `chunk_dir`, `chunk_count`, `token_count`
7. Call `literature-build-index.sh --local` to rebuild FTS5 search database

**stdout**: Progress messages (one per step)

**stderr**: Error details

**Exit codes**:
- `0` — All steps succeeded; index updated
- `1` — PDF extraction failed; chunking failed; index update failed
- `2` — Item not in `specs/zotero-index.json` (must `--add` first); `zot` not installed

**Dependencies**: `zotero-read.sh`, `literature-chunk.sh` (from literature extension), `literature-build-index.sh` (from literature extension), `jq`

**Called by**: `/zotero --convert KEY` command

---

#### `zotero-attach-chunks.sh`

**Synopsis**: Upload existing local markdown chunks as Zotero child attachments for cross-device sync.

**Usage**:
```
zotero-attach-chunks.sh <zotero_key> [--dry-run]
```

**Arguments**:
- `<zotero_key>` — 8-char Zotero item key (required)
- `--dry-run` — Preview uploads without executing; passed through to `zotero-write.sh`

**Pipeline steps**:
1. Read `chunk_dir` from `specs/zotero-index.json` for the given key
2. Exit 1 if `has_chunks` is false or `chunk_dir` is null (no chunks to attach)
3. For each `.md` file in `chunk_dir` (sorted lexicographically):
   - Call `zotero-write.sh attach-file KEY chunk.md --idempotency-key "chunk-{KEY}-{N}"`
   - Report success or failure per chunk to stdout
4. Print summary: N succeeded, M failed

**stdout**: Per-chunk upload result lines; final summary

**stderr**: API errors

**Exit codes**:
- `0` — All chunks uploaded (or dry-run completed)
- `1` — One or more chunk uploads failed
- `2` — `ZOTERO_API_KEY` not set; item not in index; `has_chunks` is false

**Dependencies**: `zotero-write.sh`, `jq`

**Called by**: `/zotero --attach KEY` command

---

#### `zotero-index-add.sh`

**Synopsis**: Add a Zotero item to the per-repo index by fetching its metadata from Zotero.

**Usage**:
```
zotero-index-add.sh <zotero_key> [--chunk]
```

**Arguments**:
- `<zotero_key>` — 8-char Zotero item key (required)
- `--chunk` — After adding to index, automatically run `zotero-chunk.sh` if item has a PDF

**Pipeline steps**:
1. Call `zotero-read.sh item KEY` → full item metadata JSON in `{ok, data, meta}` envelope
2. Extract fields from `data`: title, authors, year, item_type, abstract (first 300 chars), keywords, tags, collections
3. Resolve PDF path: check `data.attachments` for file attachments in Zotero storage directory
4. Extract `relevance_keywords` from title + keywords (stop-word filtered, length > 3)
5. Optionally fetch first note: `zotero-read.sh note KEY` → extract first 200 chars as `notes_summary`
6. Build entry JSON with all 20 fields (with `has_chunks=false`, `chunk_count=0`, `token_count=0` initially)
7. Check if entry already exists in `specs/zotero-index.json` (by `zotero_key`); update if found, append if not
8. Write updated `specs/zotero-index.json`
9. If `--chunk` passed and `has_pdf=true`: call `zotero-chunk.sh KEY`

**stdout**: Confirmation message with item title and citation key

**stderr**: Error details

**Exit codes**:
- `0` — Item added or updated successfully
- `1` — Metadata fetch failed; JSON parse error; index write error
- `2` — `zot` not installed; `specs/zotero-index.json` not found (run `/zotero --setup` first)

**Dependencies**: `zotero-read.sh`, `jq`

**Called by**: `/zotero --add KEY` command

---

### Category C: Index Management (2 scripts)

---

#### `zotero-index-remove.sh`

**Synopsis**: Remove an item from the per-repo index, optionally deleting its associated chunk files.

**Usage**:
```
zotero-index-remove.sh <zotero_key> [--delete-chunks]
```

**Arguments**:
- `<zotero_key>` — 8-char Zotero item key (required)
- `--delete-chunks` — If set, also delete the chunk directory at the item's `chunk_dir` path

**Steps**:
1. Find entry in `specs/zotero-index.json` by `zotero_key`; exit 1 if not found
2. If `--delete-chunks` and `chunk_dir` is non-null: `rm -rf specs/literature/{citation_key}/`
3. Remove entry from `entries` array using jq `del` filter
4. Write updated `specs/zotero-index.json`

**stdout**: Confirmation message

**stderr**: Error details

**Exit codes**:
- `0` — Entry removed successfully
- `1` — Key not found in index; file write error
- `2` — `specs/zotero-index.json` not found

**Dependencies**: `jq`

**Called by**: `/zotero --remove KEY` command

---

#### `zotero-search-index.sh`

**Synopsis**: Search the per-repo index using the multi-field scoring algorithm; falls back to full Zotero library search if index is empty.

**Usage**:
```
zotero-search-index.sh "query string" [--limit N] [--format json|pretty]
```

**Arguments**:
- `"query string"` — Search query (required)
- `--limit N` — Return at most N results. Default: 10.
- `--format json|pretty` — Output format. `json` = JSON array of scored entries; `pretty` = human-readable table. Default: `pretty`.

**Algorithm** (same as zotero-retrieve.sh scoring; see Section 6):
1. Extract query terms from query string (stop-word filtered, length > 3)
2. Score each `specs/zotero-index.json` entry using multi-field weighted formula
3. Filter: `total_score >= 1` (looser than retrieval's 4 to show more candidates)
4. Sort by score descending
5. Return top N results

**Fallback path**: If `specs/zotero-index.json` is empty or does not exist:
- Call `zotero-read.sh search "query"` to search full Zotero library
- Format results as JSON or pretty table
- Print notice: "Index is empty; showing results from full Zotero library. Use /zotero --add KEY to add items."

**stdout**: Scored results (JSON array or table)

**stderr**: Error details

**Exit codes**:
- `0` — Results returned (may be empty array)
- `1` — JSON parse error; query string empty
- `2` — `specs/zotero-index.json` not found and `zot` not installed (both paths unavailable)

**Dependencies**: `jq`, `zotero-read.sh` (for fallback)

**Called by**: `/zotero --search QUERY` command; agents using MCP-style search

---

### Category D: Context Injection (1 script)

---

#### `zotero-retrieve.sh`

**Synopsis**: Context injection script for the `--zot` flag. Parallel to `literature-retrieve.sh`. Emits a `<zotero-context>` block on stdout, empty on graceful failure.

**Usage**:
```
zotero-retrieve.sh <description> <task_type>
```

**Arguments**:
- `<description>` — Task description string (passed from skill preflight)
- `<task_type>` — Task type string (e.g., `meta`, `neovim`, `lean4`)

**Full algorithm**:

```
Input: description, task_type
Output: <zotero-context> block or empty string

1. Check preconditions:
   - specs/zotero-index.json exists → else exit 0 (silent empty)
   - entries array non-empty → else exit 0 (silent empty)

2. Extract query terms from description:
   - Tokenize on whitespace and punctuation
   - Filter: length > 3, not in stop-word list
   - Lowercase
   - Deduplicate

3. Score each entry using multi-field weighted formula (Section 6)

4. Filter: total_score >= 4

5. Sort by score descending

6. Greedy-select within TOKEN_BUDGET (default: index.token_budget or 8000):
   - For each candidate (highest score first):
     a. If has_chunks and chunk_dir exists:
        - Call literature-search.sh "query" --dir chunk_dir → most relevant chunk files
        - Add chunks until budget exhausted
     b. Elif has_pdf (no chunks yet):
        - Add metadata block: title, authors, year, abstract_snippet
        - Append note: "PDF available; run /zotero --convert KEY to generate chunks"
     c. Else (metadata only):
        - Add metadata block with available fields

7. Update last_retrieved timestamp for included entries (best-effort; non-blocking)

8. Emit:
   <zotero-context>
   The following Zotero library items were selected as relevant to this task.

   {content blocks from step 6}
   </zotero-context>
```

**stdout**: `<zotero-context>` block or empty string

**stderr**: Diagnostic messages only (not surfaced to agent)

**Exit codes**:
- `0` — Context emitted or gracefully empty (no entries, index missing, no matches)
- `1` — Fatal error (JSON parse failure in index; should not occur in normal operation)

**Dependencies**: `jq`, `literature-search.sh` (from literature extension; used for chunk retrieval)

**Called by**: `command-route-skill.sh` when `--zot` flag is present (same invocation pattern as `literature-retrieve.sh` with `--lit`)

---

## 6. Retrieval Scoring Algorithm

### Weighted Multi-Field Formula

```
score(item, query_terms) =
    title_score    * 4   # highest signal: query term in title
  + tag_score      * 3   # user's curated tags: expert classification
  + abstract_score * 2   # author-provided description
  + keyword_score  * 2   # author-supplied keywords
  + collection_score * 1 # collection membership (broad signal)
  + notes_score    * 1   # user's own notes on the item
```

### Per-Field Scoring Rules

| Field | Score Rule | Notes |
|-------|-----------|-------|
| `title` | +1 per unique query term that appears (case-insensitive substring match) | Capped at number of unique query terms |
| `tags` | +1 per tag that partially or fully matches any query term | Each tag scored independently |
| `abstract_snippet` | +1 per unique query term that appears in abstract (case-insensitive) | Same substring matching as title |
| `keywords` | +1 per keyword entry that partially or fully matches any query term | Author-supplied keywords |
| `collections` | +1 if any collection name contains a query term | Binary per collection |
| `notes_summary` | +1 per unique query term that appears in notes (case-insensitive) | Null notes contribute 0 |

### Minimum Threshold

`total_score >= 4` for inclusion in retrieval output.

This is significantly higher than `--lit`'s threshold of `>= 1`. Rationale: the per-repo index contains items the user has explicitly curated as project-relevant. A threshold of 4 means at least one strong signal (e.g., title match worth 4) or multiple weaker signals. Single-term matches on one low-weight field are excluded.

### Query Term Extraction

Stop words (filtered out): `a, an, the, in, on, at, of, to, for, is, are, was, were, be, been, being, have, has, had, do, does, did, will, would, shall, should, may, might, can, could, and, or, but, not, with, from, by, as, if, that, this, these, those, it, its`

Length filter: Only terms with `length > 3` after stop-word filtering.

### Domain-Term Boosting (Optional)

For formal/mathematical task descriptions, detected domain terms receive a 1.5× score multiplier. Detection heuristic: term length > 8 OR term appears in a configurable `DOMAIN_TERMS` list (e.g., `semantics, completeness, bisimulation, derivation`). This is best-effort and disabled if no domain terms list is configured.

### Pseudocode (jq)

```bash
# zotero-retrieve.sh scoring core
score_entry() {
  local entry="$1"
  local terms_json="$2"  # jq array of lowercase query terms

  jq --argjson terms "$terms_json" '
    # Score a single text field: count unique terms that appear
    def score_field(text; weight):
      if (text == null or text == "") then 0
      else
        (text | ascii_downcase) as $t |
        reduce $terms[] as $term (0;
          if ($t | test($term; "i")) then . + weight else . end
        )
      end;

    # Score an array field: sum scores for each array element
    def score_array(arr; weight):
      if (arr == null or (arr | length) == 0) then 0
      else
        reduce arr[] as $el (0;
          score_field($el; weight)
        )
      end;

    # Compute total score
    (score_field(.title; 4) +
     score_array(.tags; 3) +
     score_field(.abstract_snippet; 2) +
     score_array(.keywords; 2) +
     score_array(.collections; 1) +
     score_field(.notes_summary; 1)) as $total |

    # Apply threshold
    if $total >= 4 then
      . + {"_score": $total}
    else
      empty
    end
  ' <<< "$entry"
}
```

### Token Budget Management

- Default: `TOKEN_BUDGET=8000` (from index top-level field or environment)
- Per-entry token cost: use `token_count` from index if `has_chunks=true`; else estimate 500 tokens for metadata block
- Greedy selection: iterate candidates by descending score; include until budget would be exceeded
- Chunk-level granularity: when `has_chunks=true`, `literature-search.sh` returns scored chunks rather than all chunks, enabling fine-grained sub-budget selection

---

## 7. Command Surface: /zotero

The `/zotero` command is the single user-facing entry point, parallel to `/literature`. It dispatches to the appropriate script based on the sub-mode argument.

### Sub-Mode Dispatch Table

| Sub-mode | Usage | Script Dispatch | Description |
|----------|-------|-----------------|-------------|
| (bare) | `/zotero` | `zotero-setup.sh --status` + index summary | Show library connectivity, index item count, budget |
| `--setup` | `/zotero --setup` | `zotero-setup.sh --configure` | Run setup wizard: detect data dir, validate, optionally set Web API key |
| `--add KEY` | `/zotero --add Z7T6Q25X` | `zotero-index-add.sh KEY` | Fetch item metadata from Zotero and add to per-repo index |
| `--add KEY --chunk` | `/zotero --add Z7T6Q25X --chunk` | `zotero-index-add.sh KEY --chunk` | Add to index and immediately chunk PDF |
| `--remove KEY` | `/zotero --remove Z7T6Q25X` | `zotero-index-remove.sh KEY` | Remove item from index |
| `--remove KEY --delete-chunks` | `/zotero --remove Z7T6Q25X --delete-chunks` | `zotero-index-remove.sh KEY --delete-chunks` | Remove from index and delete chunk files |
| `--convert KEY` | `/zotero --convert Z7T6Q25X` | `zotero-chunk.sh KEY` | Extract PDF, chunk, update index |
| `--attach KEY` | `/zotero --attach Z7T6Q25X` | `zotero-attach-chunks.sh KEY` | Upload chunks as Zotero child attachments |
| `--search QUERY` | `/zotero --search "modal logic"` | `zotero-search-index.sh "QUERY" --format pretty` | Search per-repo index (with Zotero fallback); display results; offer to add selected items |
| `--sync` | `/zotero --sync` | Loop: `zotero-index-add.sh KEY` for each entry | Re-fetch metadata for all index entries from current Zotero state |
| `--validate` | `/zotero --validate` | `zotero-setup.sh --validate` + per-entry path checks | Validate index entries: PDF paths exist, chunk dirs non-empty |
| `--status` | `/zotero --status` | `zotero-setup.sh --status` (verbose) | Full library stats and index health report |

### Argument Parsing Rules

- The command file (`zotero.md`) parses the first argument after `/zotero` as the sub-mode flag
- `KEY` arguments are 8-character alphanumeric Zotero item keys
- Unknown sub-modes: print usage summary and exit without error
- Missing required arguments (KEY when required): print usage for that sub-mode and exit

### Error Handling per Sub-Mode

| Sub-mode | Error condition | Behavior |
|----------|----------------|---------|
| `--add KEY` | Key not found in Zotero | Print "Item KEY not found in Zotero library"; suggest `/zotero --search` |
| `--convert KEY` | Item not in per-repo index | Print "Add item first: /zotero --add KEY"; exit 2 |
| `--convert KEY` | Item has no PDF | Print "No PDF for KEY; metadata-only entry added" |
| `--attach KEY` | `ZOTERO_API_KEY` not set | Print "Set ZOTERO_API_KEY or run /zotero --setup"; exit 2 |
| `--sync` | Partial failure | Report per-entry success/failure; continue remaining entries |
| (bare) | `zot` not installed | Print setup instructions; suggest `/zotero --setup` |

### Interactive --search Mode

`/zotero --search QUERY` is designed for interactive human use:
1. Display scored results from `zotero-search-index.sh` (per-repo index first; Zotero library fallback if empty)
2. If results include items not in the per-repo index: offer prompt "Add item Z7T6Q25X to project index? (y/n)"
3. Agent selects via AskUserQuestion (multiSelect pattern from CLAUDE.md multi-task standards)
4. Add selected items via `zotero-index-add.sh`

---

## 8. Flag Integration: --zot

### Parsing Location

`--zot` is parsed in `command-route-skill.sh` alongside `--lit`, `--clean`, `--team`, `--hard`, and model flags. The parsing logic mirrors `--lit` exactly, replacing `literature-retrieve.sh` with `zotero-retrieve.sh` and `<literature-context>` with `<zotero-context>`.

### Injection Mechanism

When `--zot` is passed to `/research`, `/plan`, or `/implement`:

1. Preflight stage calls: `zotero-retrieve.sh "$description" "$task_type"`
2. Captured output is stored as `ZOTERO_CONTEXT`
3. If non-empty, `ZOTERO_CONTEXT` is injected into the agent prompt after `<memory-context>` and `<literature-context>`

**Context injection order** (when all flags active simultaneously):
```
<memory-context>       ← from memory-retrieve.sh (suppressed by --clean)
<literature-context>   ← from literature-retrieve.sh (only when --lit)
<zotero-context>       ← from zotero-retrieve.sh (only when --zot)
[agent prompt]
```

### Flag Interaction Matrix

| Flags | Memory retrieval | Literature injection | Zotero injection |
|-------|-----------------|---------------------|-----------------|
| (none) | active | inactive | inactive |
| `--clean` | suppressed | inactive | inactive |
| `--lit` | active | active | inactive |
| `--zot` | active | inactive | active |
| `--lit --zot` | active | active | active |
| `--clean --lit` | suppressed | active | inactive |
| `--clean --zot` | suppressed | inactive | active |
| `--clean --lit --zot` | suppressed | active | active |
| `--hard` | active | inactive | inactive (unless --zot also passed) |
| `--team` | active | inactive | inactive (unless --zot also passed) |

**Key rules**:
- `--clean` suppresses memory only; it does not affect `--lit` or `--zot`
- `--zot` and `--lit` are independent; either, neither, or both may be passed
- `--hard` and `--team` compose with `--zot` freely; they control effort/parallelism, not context injection

### command-route-skill.sh Change

The required change is minimal: add `--zot` to the flag parsing switch and add a `ZOTERO_CONTEXT` capture block alongside the existing `LITERATURE_CONTEXT` block:

```bash
# In command-route-skill.sh flag parsing loop:
--zot)
  ZOT_FLAG=true
  ;;

# In preflight context injection block:
if [ "${ZOT_FLAG:-false}" = "true" ]; then
  ZOTERO_CONTEXT=$(bash "${SCRIPTS_DIR}/zotero-retrieve.sh" "$DESCRIPTION" "$TASK_TYPE" 2>/dev/null || true)
fi
```

The injection into the prompt template follows the same pattern as `LITERATURE_CONTEXT`.

### Skill-Base Hook Alternative

If `command-route-skill.sh` is not the right injection point (e.g., for extension-provided skills), the `--zot` context injection can alternatively be implemented as a preflight lifecycle hook declared in `manifest.json`'s `hooks` object. The hook script calls `zotero-retrieve.sh` and writes the result to a temp file that the skill-base.sh framework includes in the prompt. This is the fallback mechanism if direct `command-route-skill.sh` modification is undesirable.

---

## 9. Coexistence Strategy: --zot and --lit

### No Mutual Exclusion

`--zot` and `--lit` are fully compatible and can be active simultaneously. There is no flag precedence between them. When both are active:
- `literature-retrieve.sh` runs and produces `<literature-context>`
- `zotero-retrieve.sh` runs and produces `<zotero-context>`
- Both are injected into the agent prompt (in the order specified in Section 8)
- Each uses its own `TOKEN_BUDGET` independently (default: 8000 tokens each)

**Combined token impact**: `--lit --zot` may inject up to 16,000 tokens of context. Agents should be aware that this reduces the effective context window for their own generation. Users with large indices or many relevant items should set lower `token_budget` values in their respective index files.

### Chunk Storage Overlap

Both `--lit` and `--zot` retrieve markdown chunks from `specs/literature/{citation_key}/`. This is intentional shared storage:
- Items chunked via `/zotero --convert KEY` are stored in `specs/literature/{citation_key}/` and are also discoverable by `--lit` (if they appear in `specs/literature/index.json`)
- Items chunked via `/literature --convert FILE` are stored in `specs/literature/` and are also discoverable by `--zot` if the item is in `specs/zotero-index.json` with `has_chunks=true` and the correct `chunk_dir`

This design means the two systems share chunk data without requiring separate copies.

### When to Use Which

**Use `--lit`** when:
- Working with documents that are not in Zotero (conference proceedings, web-sourced PDFs, internal documents)
- The literature directory was built manually before the zotero extension was installed
- The task type does not involve academic papers (e.g., code documentation)

**Use `--zot`** when:
- The project has a curated `specs/zotero-index.json` with relevant items
- Task descriptions involve papers, theorems, or methods that are tracked in Zotero
- Retrieval precision matters (the higher threshold and weighted scoring reduce noise)

**Use both (`--lit --zot`)** when:
- The project mixes Zotero-tracked papers with locally-managed documents
- Maximizing recall is more important than token budget

**Use neither** (default) when:
- The task does not require literature context
- Memory alone is sufficient
- Token budget is constrained

### Relationship to `--clean`

`--clean` suppresses only memory retrieval. It has no effect on `--lit` or `--zot`. To suppress all context injection, omit both `--lit` and `--zot` flags (and optionally add `--clean` to also suppress memory).

---

## 10. Downstream Task Map

The sections of this document drive five implementation tasks. Dependency ordering follows the extension's internal layering: CLI wrappers before chunk management before retrieval.

### Task 749: Create Zotero Extension Skeleton

**Drives from**: Section 2 (manifest), Section 3 (directory layout)

**Scope**:
- Create `.claude/extensions/zotero/` directory tree
- Write `manifest.json` from Section 2 specification
- Write `EXTENSION.md` stub (Zotero section for CLAUDE.md injection)
- Write `README.md` with setup and usage guide
- Write `index-entries.json` with context entries for agent discovery
- Create empty `agents/`, `commands/`, `skills/skill-zotero/`, `scripts/`, `context/project/zotero/` directories
- Write `zotero-agent.md` stub and `SKILL.md` stub

**Deliverable**: Complete extension directory structure that loads without errors in the extension picker

**Dependencies**: none

---

### Task 750: Implement Zotero CLI Wrapper Scripts

**Drives from**: Section 5 Category A (zotero-read.sh, zotero-write.sh, zotero-setup.sh), Section 11 (configuration)

**Scope**:
- Implement `zotero-read.sh` with all 9 operations
- Implement `zotero-write.sh` with all 4 write operations and idempotency key support
- Implement `zotero-setup.sh` with all 4 sub-commands (`--detect`, `--configure`, `--validate`, `--status`)
- Implement `/zotero --setup` and `/zotero --status` sub-modes in `zotero.md`

**Deliverable**: All read/write/setup operations working; `/zotero` bare and `--status` show correct output

**Dependencies**: Task 749

---

### Task 751: Implement Zotero Search and Index Management

**Drives from**: Section 5 Category C (zotero-index-add.sh, zotero-index-remove.sh, zotero-search-index.sh), Section 4 (per-repo index schema), Section 6 (scoring algorithm for search)

**Scope**:
- Implement `zotero-index-add.sh` with full metadata extraction pipeline
- Implement `zotero-index-remove.sh`
- Implement `zotero-search-index.sh` with scoring algorithm and Zotero fallback
- Implement `/zotero --add`, `--remove`, `--search`, `--validate`, `--sync` sub-modes
- Create and validate `specs/zotero-index.json` schema

**Deliverable**: Per-repo index lifecycle complete; items can be added, searched, synced, and removed

**Dependencies**: Task 750

---

### Task 752: Implement On-Demand PDF Markdown Conversion

**Drives from**: Section 5 Category B (zotero-chunk.sh, zotero-attach-chunks.sh), Section 5 zotero-index-add.sh (step 9 for `--chunk` flag)

**Scope**:
- Implement `zotero-chunk.sh` with full 7-step pipeline including literature-chunk.sh reuse
- Implement `zotero-attach-chunks.sh` with idempotency-keyed upload
- Implement `/zotero --convert` and `--attach` sub-modes
- Wire `--chunk` flag to `zotero-index-add.sh`

**Deliverable**: Full PDF-to-chunks pipeline working; chunks stored in `specs/literature/{citation_key}/`; index updated correctly

**Dependencies**: Task 751 (requires `zotero-index-add.sh` to be complete for index updates)

---

### Task 753: Implement Zotero Context Injection

**Drives from**: Section 5 Category D (zotero-retrieve.sh), Section 6 (full scoring algorithm with pseudocode), Section 8 (flag integration and command-route-skill.sh change)

**Scope**:
- Implement `zotero-retrieve.sh` with full 8-step algorithm
- Add `--zot` flag parsing to `command-route-skill.sh`
- Add `ZOTERO_CONTEXT` injection into prompt template (after `LITERATURE_CONTEXT`)
- Wire `/research`, `/plan`, `/implement` to accept and thread `--zot` flag
- Implement chunk-level retrieval via `literature-search.sh`

**Deliverable**: `--zot` flag functional on all three commands; context injection verified with test task

**Dependencies**: Task 752 (requires chunks to exist for chunk-retrieval path); Task 750 (requires `zotero-retrieve.sh` to call `zotero-read.sh` for graceful degradation)

---

### Dependency Chain Summary

```
749 (skeleton)
  └── 750 (CLI wrappers: read/write/setup)
        └── 751 (index management: add/remove/search)
              └── 752 (chunk pipeline: convert/attach)
                    └── 753 (context injection: --zot flag)
```

Each task is blocked by the previous one. No parallelism is possible within this chain.

---

## 11. Configuration and Setup

### ZOT_DATA_DIR Detection

The `zotero-setup.sh --detect` sub-command checks paths in the following order:

1. `$ZOT_DATA_DIR` environment variable (if set and directory exists → use it)
2. `~/Zotero/` (default Zotero path on Linux/macOS)
3. `~/Documents/Zotero/` (common alternative; NixOS users often use this)
4. `$XDG_DATA_HOME/Zotero/` (XDG-compliant path)
5. Windows registry (not applicable in current Linux/NixOS target)

Detection success criterion: the resolved path contains `zotero.sqlite`.

### Persisting ZOT_DATA_DIR

After detection, `zotero-setup.sh --configure` persists the resolved path to `specs/zotero-index.json` as the `zot_data_dir` top-level field. On every `zotero-read.sh` call, the script reads this field and exports `ZOT_DATA_DIR` before invoking `zot`.

This approach avoids requiring the user to set `ZOT_DATA_DIR` in their shell environment and ensures the path is committed to the repo (useful for teams where all members have Zotero at the same path).

### zot Installation Check

Every script in Category A, B, C, and D begins with:
```bash
if ! command -v zot &>/dev/null; then
  echo "zot not installed. Install via: pip install zotero-cli-cc" >&2
  exit 2
fi
```

This ensures graceful degradation (exit 2, not exit 1) so callers like `zotero-retrieve.sh` can interpret exit 2 as "not configured" and emit empty context rather than error.

### Web API Key Handling

The Zotero Web API key is required only for write operations (`zotero-write.sh`). Read operations use SQLite directly and require no auth.

**Storage**: The API key should be stored in the shell environment as `ZOTERO_API_KEY`. It should NOT be committed to `specs/zotero-index.json` or any tracked file.

**Setup flow in `/zotero --setup`**:
1. Detect and configure `ZOT_DATA_DIR`
2. Run `zotero-setup.sh --validate` to confirm read access
3. Optionally prompt for Web API key: "Enter Zotero Web API key (leave blank to skip; required only for /zotero --attach):"
4. If provided, print instructions to add to shell profile: `export ZOTERO_API_KEY="..."`
5. The key is not saved to any file; user manages it via their shell profile

### Graceful Degradation Matrix

| Condition | Behavior |
|-----------|---------|
| `zot` not installed | Exit 2; print install instructions |
| `ZOT_DATA_DIR` not set and not detectable | Exit 2; suggest `/zotero --setup` |
| `specs/zotero-index.json` does not exist | Exit 2; suggest `/zotero --setup` |
| `specs/zotero-index.json` is empty | Exit 0 with empty context (not an error) |
| No index entries score above threshold | Exit 0 with empty context |
| PDF missing from resolved `pdf_path` | Skip PDF extraction; use metadata block only |
| `ZOTERO_API_KEY` not set (write attempt) | Exit 2; describe what key is needed for |

### AGPL-3.0 Note

`zotero-cli-cc` is licensed under AGPL-3.0. Shell scripts that call `zot` as an external process (via `subprocess` or shell) are not "linked" to the library in the copyleft sense. This extension's scripts are not subject to AGPL copyleft as long as they invoke `zot` as a separate executable. If the extension is distributed externally (beyond this personal configuration), consult the license terms.
