# Zotero Integration

Full Zotero library management is part of the literature extension (absorbed from the former
standalone zotero extension — there is no separate zotero extension to load).

## How the Library Is Reached

Two access paths, used for different jobs:

- **Better BibTeX CSL-JSON auto-export** — the search path. A single JSON file the extension
  reads directly, so search works with Zotero closed and requires no running client.
- **The `zot` CLI** — the optional direct-library path, used for reading item metadata/PDFs and
  for creating or attaching items during online ingest.

## Setup

In Zotero: **File > Export Library > Better CSL JSON**, check **"Keep updated"**, and save to:

```
~/Projects/Literature/zotero-library.json
```

(or `$LITERATURE_DIR/zotero-library.json` if `LITERATURE_DIR` is overridden — see
`tools/literature-dir-config.md`).

"Keep updated" is what makes the export a live mirror rather than a one-time snapshot; without
it, the search tier silently ages out as the library grows.

## Where It Is Used

| Consumer | Role of Zotero |
|----------|----------------|
| `/literature` Mode A, Tier 2 | Local library search before any online lookup |
| `/literature` online ingest | Item creation and PDF attachment via `zot` |
| `/cite` | Match-and-score source, and the basis for `--gaps` (in-library, no local PDF) |

## Related

- `tools/zotero-scripts.md` — the script inventory and argument gotcha
- `patterns/zotero-item-creation.md` — item creation and the `%PDF` magic-byte gate
- `patterns/zotero-pdf-resolution.md` — resolving an index entry to its Zotero PDF
