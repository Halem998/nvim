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

## Sub-Index Rebuild (`--rebuild`)

`/literature --rebuild [--dry-run]` brings a repo's per-repo sub-index into conformance with the
global corpus via four selectable jobs (dangling-ref lint, schema conformance, coverage refresh,
chunk/search-index coverage audit). See `.claude/skills/skill-literature/SKILL.md` "Mode:
Rebuild" for the full job implementations.

**Live sub-index schemas diverge from the nominal shape documented above** (task #840 finding):
some sub-indexes omit `source` entirely; others use `reason` instead of `relevance` plus
additional load-bearing curation fields (e.g. `hazard`, `citation_rule`, `known_corrections`,
`audits` documenting a citation-fidelity issue). Job 2's schema-conformance check therefore
validates only the **structural minimum** — non-empty `doc_id` plus either `relevance` or
`reason` — and never flags or strips extra fields. Treat the "Per-Repo Sub-Index Schema" example
above as the *nominal* shape new entries default to, not a rigid contract every entry must match.

**`document_metadata` is currently empty (0 rows)** in the live `.literature.db` despite being
declared in the schema as a one-row-per-document table. Job 4's coverage audit queries
`chunks_data` exclusively for this reason. Whether `document_metadata` is vestigial or should be
populated is an open question outside `--rebuild`'s scope (task #840 research flagged it but did
not resolve it).

## Tooling Ownership Boundary

One-time/re-runnable migration tooling for importing a project's `specs/literature/` into the
central corpus lives in `~/Projects/Literature/scripts/migrate-from-repo.sh` — a script in the
**separate Literature repo** (`$LITERATURE_DIR`), not in this config repo's `.claude/scripts/`.
The central `index.json` is likewise owned and versioned by that separate repo; this repo's
tooling only reads it (e.g. `literature-search.sh`, `literature-briefing.sh`) or, where explicitly
documented, offers advisory normalization the user applies and commits there themselves.

This distinction matters because it is easy to mis-scope an audit of "index-writing scripts" to
only `.claude/scripts/` and miss the actual write path. Task 801 found and fixed exactly this: the
malformed `authors` field shape (string-typed or unsplit comma-joined one-element arrays) in the
live global index was traced to `migrate-from-repo.sh`'s two authors-handling sites, not to any
script in `.claude/scripts/`.

Two in-repo maintenance tools exist for this specific `authors` schema, and should stay in sync
with each other (same comma-joined heuristic) whenever either is modified:

- `/literature --validate` (per-repo index) — flags `authors:not-array`, `authors:non-string-element`,
  and `authors:possibly-comma-joined` warnings. See `.claude/skills/skill-literature/SKILL.md`
  Validate Step 2/4.
- `.claude/scripts/literature-normalize-authors.sh` — a reusable, dry-run-by-default script that
  fixes the shape for any given `index.json` (global or per-repo). Requires an explicit `--apply`/
  `--write` flag to persist changes; safe to run repeatedly (idempotent).

Fixing the external `migrate-from-repo.sh` source and normalizing the live global index are both
user-applied actions outside this repo — see `specs/801_literature_index_authors_schema_normalization/`
for the prepared patch, dry-run diff, and apply-guide.
