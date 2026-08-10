# `/cite` Citation Verification Workflow

`/cite` verifies citation claims in task artifacts against the Literature/ index and the Zotero
library. It extracts citations, scores each against available sources, and creates research tasks
for claims that cannot be verified.

## Workflow

1. **Extract** citation patterns from the task's markdown artifacts (`cite-extract.sh`).
2. **Match** each extracted citation against `index.json` and `zotero-library.json`.
3. **Score** by confidence: `confirmed`, `partial`, `unconfirmed`, or `gap`.
4. **Select** interactively which unverified claims warrant follow-up.
5. **Create** research tasks for the selected unverified claims.

## Invocations

| Usage | Behavior |
|-------|----------|
| `/cite N` | Verify all citations in the artifacts of task N |
| `/cite N --gaps` | Also flag citations found in Zotero but lacking a local PDF |

## Script Dependencies

- `cite-extract.sh` — citation pattern extraction (required)
- `zotero-search.sh` — Zotero library search (optional)

Both degrade gracefully when their sources are unavailable: a missing Zotero export downgrades
matches to index-only scoring rather than failing the run.

## Related

- `tools/zotero-scripts.md` — full script inventory
- `domain/zotero-integration.md` — Zotero export setup, which `--gaps` depends on
