# Literature Index Schema

## Overview

The literature system uses a two-level index architecture:

1. **Global index** (`$LITERATURE_DIR/index.json`) — The single source of truth for all documents in the centralized Literature/ repository. Contains full metadata for every document and chunk.

2. **Per-repo sub-index** (`specs/literature-index.json`) — A lightweight reference index for each project. Contains only `doc_id` references pointing to entries in the global index. No cached metadata — all metadata is resolved at runtime from the global index.

## Global Index Schema (v2)

Location: `$LITERATURE_DIR/index.json` (default: `/home/benjamin/Projects/Literature/index.json`)

Each entry includes:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique doc_id (e.g., `blackburn_2002`) |
| `path` | string | Relative path from `$LITERATURE_DIR/` |
| `token_count` | integer | Estimated token count |
| `keywords` | string[] | Search keywords |
| `summary` | string | One-sentence description |
| `authors` | string[] | Author list |
| `title` | string | Full document title |
| `year` | integer\|null | Publication year |
| `doc_type` | string | `paper`, `book`, `chapter`, or `section` |
| `source_format` | string | `pdf`, `djvu`, or `manual` |
| `parent_doc` | string\|null | Parent doc_id for chunks |
| `page_range` | string\|null | Page range in source document |
| `bib_key` | string\|null | Better BibTeX citation key |
| `zotero_key` | string\|null | Zotero internal item key |
| `zotero_path` | string\|null | Absolute path to PDF in Zotero storage |
| `project_tags` | string[]\|null | Zotero collection names as project tags |

## Per-Repo Sub-Index Schema

Location: `specs/literature-index.json` (per-project)

```json
{
  "project": "project_slug",
  "literature_dir": null,
  "entries": [
    {
      "doc_id": "blackburn_2002",
      "relevance": "Core modal logic reference",
      "added": "2026-06-01",
      "source": "manual"
    }
  ]
}
```

### Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `doc_id` | string | Yes | Must match an `id` in the global index |
| `relevance` | string | No | Why this document matters for this project |
| `added` | string | No | ISO date when added to sub-index |
| `source` | string | No | How entry was added: `discover`, `manual`, or `import` |

### Design Principles

- **Reference-only**: Sub-index contains no cached metadata. All fields (title, authors, year, paths) are resolved at runtime from the global index.
- **Orphan detection**: If a `doc_id` is not found in the global index, the entry is reported as an orphan (warning logged, no crash).
- **Override support**: Optional `literature_dir` field overrides `$LITERATURE_DIR` for this project.

## Directory Structure

```
$LITERATURE_DIR/                    # Global Literature/ repository
├── index.json                     # Global index (v2 schema)
├── .literature.db                 # SQLite FTS5 database (full-text search)
├── sources/                       # All document directories
│   ├── blackburn_2002/
│   │   ├── Blackburn_2002_Modal_Logic.md
│   │   ├── section01_intro.md
│   │   └── section02_syntax.md
│   └── venema_2001/
│       └── Venema_2001_Survey.md
└── zotero-library.json            # Zotero Better BibTeX CSL-JSON export (optional)
```

## Search Interface

Use `literature-search.sh` to search the global corpus via FTS5:

```bash
bash .claude/scripts/literature-search.sh "modal logic semantics"
bash .claude/scripts/literature-search.sh "modal logic" --limit 5
bash .claude/scripts/literature-search.sh "modal logic" --doc_id blackburn_2002
bash .claude/scripts/literature-search.sh blackburn_2002 --by-doc
```

Returns JSON array of matching chunks with `doc_id`, `section_path`, `score`, and `snippet` fields.
