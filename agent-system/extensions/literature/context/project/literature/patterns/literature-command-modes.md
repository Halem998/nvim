# Two-Mode `/literature` Command

The `/literature` command has two modes, selected by argument shape.

## Mode Detection

| Argument shape | Mode |
|----------------|------|
| Path-like (`~/paper.pdf`, `~/dir/`) | Mode B (Integrate) |
| Numeric or free text (`7`, `"modal logic"`) | Mode A (Discover) |
| No arguments | Mode B (status) |

## Mode A — Discover

Runs a three-tier discovery pipeline via `literature-discover.sh`:

1. **Tier 1 (offline)**: search `$LITERATURE_DIR/index.json`
2. **Tier 2 (local)**: search the Zotero library (`zotero-library.json`)
3. **Tier 3 (online)**: ordered provider fallback chain — Semantic Scholar API -> OpenAlex ->
   Crossref, advancing only on genuine provider failure — plus Unpaywall DOI lookup and arXiv
   direct PDF resolution

Results are shown interactively. For each selected `open_access` / `paywall` /
`in_zotero_no_pdf` entry, the user is offered:

- **"Ingest into Literature now"** — via `literature-ingest-online.sh`. Ingested items are
  registered in `specs/literature-index.json`.
- **"Just record in SOURCES.md"** — the default/fallback, and the only outcome when no PDF is
  discoverable. Unresolved items are appended to `specs/literature/SOURCES.md`.

## Mode B — Integrate

Runs the ingestion pipeline via `literature-ingest.sh`: converts PDFs/DJVUs, indexes the
resulting chunks in FTS5, and updates `specs/literature-index.json`. With no arguments it
reports status and index health instead of ingesting.

## Related

- `domain/literature-index.md` — the global index and per-repo sub-index schemas Mode B writes
- `tools/zotero-scripts.md` — the scripts behind Tier 2 and the online-ingest bridge
- `patterns/agent-exploration.md` — how agents consume the corpus once ingested
