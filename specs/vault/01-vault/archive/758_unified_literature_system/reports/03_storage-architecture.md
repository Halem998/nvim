# Storage Architecture for Unified Literature System

## 1. Current Storage Landscape

### 1.1 Global Literature Repository (Already Exists)

A centralized Literature repo is **already operational** at `~/Projects/Literature/`:

```
~/Projects/Literature/
├── index.json            # v2 schema, 222 entries, 47 unique documents
├── .literature.db        # SQLite FTS5 database (1.1 MB, 180 chunks)
├── .gitignore            # Excludes *.pdf, *.djvu, zotero-library.json
├── README.md             # Architecture documentation
├── FIND_SOURCES.md       # Source-finding guide
├── scripts/
│   └── migrate-from-repo.sh   # Import from per-project specs/literature/
├── sources/              # 48 subdirectories, one per document
│   ├── blackburn_2002/   # 37 .md chunks + co-located PDF (gitignored)
│   ├── burgess_1982/
│   └── ...
└── .claude/              # Has its own agent system (task management)
```

**Key facts**:
- **index.json**: 222 entries (180 with parent_doc, i.e., chapter/section chunks). 47 unique works.
- **SQLite .literature.db**: FTS5 database with `chunks_data`, `chunks_fts`, `chunk_relations`, and `document_metadata` tables. Currently has 180 chunks indexed but `document_metadata` has 0 rows (table defined but not populated).
- **Git tracking**: Markdown chunks are committed. PDFs/DJVUs and `zotero-library.json` are gitignored.
- **README documents a "two-tier fallback"**: `LITERATURE_DIR` env var → global repo; unset → per-project `specs/literature/`.

### 1.2 LITERATURE_DIR Configuration

`LITERATURE_DIR` is **not currently set** in `.claude/settings.json` `env` block. The settings file has:
```json
"env": {
  "SLASH_COMMAND_TOOL_CHAR_BUDGET": "50000"
}
```

The scripts default to `$HOME/Projects/Literature` when `LITERATURE_DIR` is unset:
```bash
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
```

This works by convention but should be made explicit in the unified system.

### 1.3 Per-Repo State

- **specs/literature/**: Does not exist in this nvim config repo.
- **specs/zotero-index.json**: Does not exist in this repo.
- Neither per-project literature tier is currently used for this project.

### 1.4 Dual Retrieval Scripts

Two parallel retrieval mechanisms exist:

| Script | Flag | Index Source | Output Tag | Budget |
|--------|------|-------------|------------|--------|
| `literature-retrieve.sh` | `--lit` | `specs/literature/index.json` | `<literature-context>` | 8000 tokens |
| `zotero-retrieve.sh` | `--zot` | `specs/zotero-index.json` | `<zotero-context>` | 8000 tokens |

Both use keyword overlap scoring (stop-word filtered) and greedy token-budget selection. The literature script falls back to recursive file scan when no index exists. The zotero script has richer scoring (title×4, tags×3, abstract×2, keywords×2, collections×1).

### 1.5 Newer Agent-Callable Scripts

Two newer scripts in `.claude/scripts/` already operate against the global Literature repo:

| Script | Purpose | Interface |
|--------|---------|-----------|
| `literature-search.sh` | FTS5 search against `.literature.db` | JSON output, 7 subcommands (search, --read, --toc, --refs, --next, --prev, --doc) |
| `literature-ingest.sh` | Full pipeline: PDF→markdown→chunk→index→SQLite | Supports `--zotero <key>`, `--local`/`--no-local` flags |

These scripts are **more capable** than the extension-based retrieval scripts and already implement the two-tier database pattern (local `.literature.db` + global `.literature.db`).

---

## 2. Global Literature/ Repo Design

### 2.1 Recommended Directory Structure

The existing structure is sound. Proposed refinements:

```
~/Projects/Literature/               # Global Literature repo
├── index.json                       # Primary JSON index (source of truth)
├── .literature.db                   # SQLite FTS5 cache (built from index.json + content)
├── .gitignore                       # *.pdf, *.djvu, zotero-library.json, .literature.db
├── README.md
├── sources/                         # All document content
│   ├── {author_year}/               # One directory per document
│   │   ├── {author_year}.pdf        # Co-located source (gitignored)
│   │   ├── ch01_introduction.md     # Section chunks (committed)
│   │   ├── ch02_semantics.md
│   │   └── ...
│   └── ...
├── pdfs/                            # Zotero PDF symlinks (gitignored)
│   └── {citation_key}.pdf -> /path/to/zotero/storage/...
├── zotero-library.json              # Better BibTeX auto-export (gitignored)
└── scripts/
    ├── migrate-from-repo.sh         # Import from per-project dirs
    └── rebuild-db.sh                # Rebuild .literature.db from index.json
```

**Changes from current**:
1. Add `.literature.db` to `.gitignore` (it's a derived artifact, rebuilt from index.json + source files)
2. Populate `document_metadata` table (currently empty — 0 rows despite having 180 chunks)
3. No structural changes needed; the existing layout works

### 2.2 Git Tracking Strategy

**Committed** (tracked):
- `index.json` — source of truth for all document metadata
- `sources/**/*.md` — markdown chunks (the primary content)
- `README.md`, `scripts/`, `.gitignore`

**Gitignored** (derived/binary):
- `*.pdf`, `*.djvu` — binary sources, re-obtainable from Zotero
- `zotero-library.json` — auto-exported by Better BibTeX
- `.literature.db` — rebuilt from index.json + content files

This strategy is already in place and correct. PDF storage in Zotero (with symlinks in `pdfs/`) avoids committing large binaries while maintaining access.

### 2.3 Index Format: JSON vs SQLite

**Current state**: Both exist in parallel:
- `index.json` (198 KB, 222 entries) — human-readable, git-diffable, source of truth
- `.literature.db` (1.1 MB, 180 chunks) — FTS5 search, BM25 ranking, cross-references

**Recommendation**: Keep the dual format.

| Aspect | index.json | .literature.db |
|--------|-----------|---------------|
| Role | Source of truth, metadata registry | Search cache, FTS5 index |
| Git tracked | Yes | No (derived) |
| Updated by | `/literature --convert`, `/literature --index`, ingestion pipeline | `literature-build-index.sh` (rebuild from sources) |
| Queried by | `literature-retrieve.sh` (keyword overlap) | `literature-search.sh` (FTS5 BM25) |
| Scale concern | ~500 entries threshold (per README) | No practical limit |

The SQLite database adds FTS5 full-text search with BM25 ranking, cross-reference traversal (`chunk_relations`), and sequential navigation (`prev_chunk_id`/`next_chunk_id`). These are exactly the capabilities a literature-agent needs for autonomous exploration. JSON cannot replace this.

**Migration action**: The `document_metadata` table has 0 rows despite the database having 180 chunks. This needs to be populated from `index.json` entries where `parent_doc == null` (the 47 top-level documents). The `literature-build-index.sh` script should handle this.

### 2.4 Zotero Integration

Current flow:
1. Better BibTeX auto-exports `zotero-library.json` to `~/Projects/Literature/`
2. `literature-ingest.sh --zotero <key>` looks up the key in that export
3. Finds the PDF path from Zotero storage, converts to markdown chunks
4. Stores chunks in `sources/{doc_id}/`
5. Updates `index.json` with `bib_key`, `zotero_key`, `zotero_path` fields
6. Rebuilds `.literature.db`

This flow already works end-to-end. The Zotero extension's per-repo `specs/zotero-index.json` is a separate, lighter-weight mechanism that should be folded into the per-repo sub-index concept.

---

## 3. Per-Repo Sub-Index Design

### 3.1 Purpose

A per-repo sub-index declares: "these documents from the global Literature are relevant to this project." It replaces both `specs/literature/index.json` (literature extension) and `specs/zotero-index.json` (zotero extension).

### 3.2 Recommended File: `specs/literature-index.json`

```json
{
  "version": 1,
  "literature_dir": null,
  "entries": [
    {
      "doc_id": "blackburn_2002_book",
      "relevance_note": "Core reference for Kripke semantics and frame theory",
      "added": "2026-06-15T12:00:00Z",
      "tags": ["kripke", "modal-logic", "frames"]
    },
    {
      "doc_id": "burgess_1982",
      "relevance_note": "Axioms for tense logic",
      "added": "2026-06-16T10:00:00Z",
      "tags": ["temporal", "axiomatization"]
    }
  ]
}
```

### 3.3 Design Decisions

| Question | Recommendation | Rationale |
|----------|---------------|-----------|
| References only, or cached metadata? | **References only** (doc_id + relevance note + tags) | Avoids staleness. The agent queries the global index/database for metadata at runtime. |
| How to declare relevance? | `doc_id` matches `index.json` entry IDs | Simple, unambiguous. Top-level doc_ids pull in all child chunks automatically. |
| Optional `literature_dir` override? | Yes, `null` means use `LITERATURE_DIR` env var | Allows per-project override if a project uses a different Literature repo |
| Tags field? | Yes, project-specific tags that augment global keywords | Helps the literature-agent prioritize within the project context |
| Chunk-level selection? | No — always reference whole documents | Agent decides which chunks are relevant during exploration. Chunk-level curation is too fine-grained for humans. |

### 3.4 Relationship to Global Index

```
Global Literature/index.json         Per-repo specs/literature-index.json
┌─────────────────────────┐          ┌──────────────────────────┐
│ 222 entries             │          │ ~5-20 doc_id references  │
│ Full metadata           │◄─────────│ Lightweight pointers     │
│ Chunk hierarchy         │  lookup  │ Project-specific tags    │
│ Zotero fields           │          │ Relevance notes          │
└─────────────────────────┘          └──────────────────────────┘
         │
         ▼
.literature.db (FTS5 search)
         │
         ▼
sources/{doc_id}/*.md (actual content)
```

The agent receives the sub-index, uses doc_ids to scope queries against the global database, and reads chunks from the global `sources/` directory.

---

## 4. Practical Considerations

### 4.1 Path Resolution

The scripts already handle this via `LITERATURE_DIR` with a default:
```bash
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
```

**Recommendation**: Set `LITERATURE_DIR` explicitly in `.claude/settings.json`:
```json
"env": {
  "LITERATURE_DIR": "/home/benjamin/Projects/Literature"
}
```

The literature-agent should receive `LITERATURE_DIR` as an environment variable, not as a hardcoded path. The sub-index's optional `literature_dir` field provides per-repo override.

### 4.2 Cross-Machine Portability

Current approach (`$HOME/Projects/Literature` default) works for single-user setups. For multi-machine:
- `LITERATURE_DIR` env var is the portable mechanism
- The global repo is a git repository — clone it on each machine
- PDFs are gitignored but can be re-obtained from Zotero (which syncs independently)
- `.literature.db` is derived — rebuild with `literature-build-index.sh` after clone

No changes needed; the current design handles this.

### 4.3 Zotero Database vs Literature/ Repo

| Zotero | Literature/ |
|--------|------------|
| Source of truth for PDF files and bibliographic metadata | Source of truth for markdown chunks and search index |
| SQLite database (zotero.sqlite) in Zotero data directory | JSON index + SQLite FTS5 cache |
| Syncs across devices via Zotero cloud | Syncs via git |
| Accessed via `zot` CLI or Better BibTeX export | Accessed via `literature-search.sh` / `literature-ingest.sh` |

**Flow**: Zotero → (export/ingest) → Literature/ → (sub-index) → per-repo agent context.

The Zotero database should remain the upstream source for bibliographic metadata and PDF storage. The Literature/ repo is a processed derivative optimized for agent consumption.

### 4.4 Migration Path

**Phase 1 — Consolidate extensions**:
- Merge `literature` and `zotero` extensions into a single `literature` extension
- The new extension provides: `/literature` command, `literature-agent`, `--lit` flag
- Remove `--zot` flag and `specs/zotero-index.json` concept
- Replace with `specs/literature-index.json` (sub-index)

**Phase 2 — Simplify retrieval**:
- Replace `literature-retrieve.sh` (keyword overlap) and `zotero-retrieve.sh` (weighted scoring) with a single agent-based approach
- The `literature-agent` receives the sub-index and calls `literature-search.sh` (FTS5) autonomously
- No more static context injection (`<literature-context>`, `<zotero-context>` blocks)

**Phase 3 — Clean up**:
- Remove `zotero-retrieve.sh`, `zotero-search-index.sh`, and other zotero-specific scripts
- Keep `literature-ingest.sh`, `literature-search.sh`, `literature-build-index.sh` (these already operate on the global repo)
- The `zot` CLI remains available for Zotero operations but is called by ingest, not by the retrieval path

### 4.5 What Already Works (Reusable)

| Component | Status | Reuse? |
|-----------|--------|--------|
| `~/Projects/Literature/` repo | Fully operational | Yes — becomes the canonical global repo |
| `index.json` (v2 schema) | 222 entries, 47 documents | Yes — source of truth |
| `.literature.db` (FTS5) | 180 chunks, schema complete | Yes — agent search backend |
| `literature-search.sh` | 7 subcommands, two-tier search | Yes — becomes agent's primary tool |
| `literature-ingest.sh` | Full pipeline, Zotero support | Yes — ingestion pipeline unchanged |
| `literature-build-index.sh` | Rebuilds SQLite from sources | Yes — derived DB maintenance |
| `migrate-from-repo.sh` | Import from per-project dirs | Yes — one-time migration aid |

### 4.6 What Needs Building

| Component | Description |
|-----------|-------------|
| `specs/literature-index.json` schema + tooling | Per-repo sub-index creation/management |
| Literature-agent definition | Agent that receives sub-index + explores autonomously |
| `--lit` flag rewiring | Instead of injecting content, spawn literature-agent |
| Extension consolidation | Merge zotero + literature manifests, commands, skills |
| `document_metadata` population | Fix the empty table in `.literature.db` |

---

## 5. Summary

The global Literature/ repo already exists and is well-designed. The main work is:

1. **Define the per-repo sub-index** (`specs/literature-index.json`) as a lightweight pointer file
2. **Replace static injection with agent exploration** — the literature-agent uses `literature-search.sh` (FTS5) to autonomously search within the scope defined by the sub-index
3. **Consolidate two extensions into one** — the zotero extension's Zotero-specific functionality (ingest from Zotero key) folds into the literature extension's ingestion pipeline (which already supports `--zotero`)
4. **Set LITERATURE_DIR** in `.claude/settings.json` to make the global repo path explicit
