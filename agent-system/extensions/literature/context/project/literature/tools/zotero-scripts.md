# Zotero Script Inventory

The scripts below ship with the literature extension under `scripts/` and are deployed to
`.claude/scripts/`.

| Script | Purpose |
|--------|---------|
| `zotero-search.sh` | Search the CSL-JSON export by keyword (used by `/literature` Mode A) |
| `zotero-read.sh` | Read item metadata and PDFs via the `zot` CLI |
| `zotero-write.sh` | Write/attach files to Zotero items; create new items with a PDF attachment (`item-add`, wrapping `zot add --pdf`) |
| `zotero-setup.sh` | Setup wizard: detect the data dir, validate, configure |
| `zotero-chunk.sh` | Extract PDF text and chunk it into sections |
| `zotero-attach-chunks.sh` | Upload chunks as Zotero child attachments |
| `cite-extract.sh` | Extract citation patterns from markdown artifacts |
| `literature-ingest-online.sh` | Online-discovery -> Zotero+PDF -> ingest bridge: classifies a discovery record, downloads and magic-byte-verifies the PDF, creates/attaches the Zotero item, delegates to `literature-ingest.sh`, and patches index/sub-index metadata |

## Argument Gotcha

`zotero-search.sh` scores query terms independently and OR-combines them, so each search word
must be passed as a SEPARATE argument. A single quoted multi-word phrase is treated as one term
and matches nothing. See `patterns/agent-exploration.md` ("Two Search Tools") for the full
comparison against `literature-search.sh`.

## Related

- `domain/zotero-integration.md` — export setup and the `zot` CLI
- `patterns/zotero-item-creation.md` — how `literature-ingest-online.sh` creates items
- `patterns/zotero-pdf-resolution.md` — resolving a `doc_id` to its Zotero PDF
- `patterns/cite-workflow.md` — where `cite-extract.sh` is used
