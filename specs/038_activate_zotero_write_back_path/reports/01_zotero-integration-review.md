# Zotero Integration Review: Write-Back Path Activation

- **Task**: 38
- **Date**: 2026-08-11
- **Type**: Seed research report (findings gathered during interactive review; verified live, not inferred)
- **Scope**: Current state of the literature extension's Zotero integration; environment verification; what blocks the write-back path and what has silently unblocked

## Summary

The extension's bidirectional Zotero design (read via Better BibTeX export; write via
`zotero-write.sh` wrapping the `zot` CLI) is architecturally sound and already implemented in the
source store, but the write path is inactive. Live verification on 2026-08-11 shows the extension's
own documentation is now WRONG about why: the Zotero API key blocker has resolved (a key with full
write + file access is present in the environment), leaving exactly one hard blocker (the `zot`
binary is not installed — provisioning belongs to the ~/.dotfiles repo) and two correctness hazards
(stale Better BibTeX export driving Tier-2 classification; unconfirmed `zot add` envelope field
names).

## Verified environment facts (2026-08-11, all checked live)

1. **API key present and fully privileged.** `ZOTERO_API_KEY` is set in the environment (sourced
   from `~/.config/fish/conf.d/private.fish`, outside any managed dotfile). Verified against
   `GET https://api.zotero.org/keys/current`: userID `2622830`, username `benbrastmckie`,
   `access.user = {library: true, files: true, write: true}`. This contradicts the README's
   deployment-status table and `zotero-write.sh`'s header, both of which state no configured API
   key is available. Those docs are stale and must be corrected.

2. **`zot` CLI still not installed.** `command -v zot` fails. This is the one remaining hard
   blocker. The package `zotero-cli-cc` is real and actively maintained: PyPI current version
   **0.10.0, released 2026-07-15**, summary "Zotero CLI for Claude Code — SQLite reads + Web API
   writes". Extension docs pin v0.7.0 (2026-05-29); flags/envelope must be re-verified against
   the current release after install. Provisioning (Nix-managed, PATH-visible) is a ~/.dotfiles
   task (task 129 in that repo's tracker), not an edit in this repo.

3. **Active Zotero data dir is `/home/benjamin/Documents/Zotero`.**
   `zotero-resolve-sqlite-path.sh` resolves it correctly. It contains `storage/` with **948**
   attachment subdirectories, an installed Better BibTeX (`better-bibtex.sqlite`), and
   `prefs.js` sets `extensions.zotero.dataDir=/home/benjamin/Documents/Zotero` and
   `extensions.zotero.httpServer.localAPI.enabled=true`. A decoy `~/Zotero` directory also exists
   (sqlite last touched 2026-04-17, no `storage/`) — nothing should ever read it, but it invites
   confusion during debugging.

4. **Better BibTeX export is stale.** `$LITERATURE_DIR/zotero-library.json` was last generated
   2026-07-01T19:07:47Z; the live `zotero.sqlite` mtime is 2026-08-05. The extension's own
   `zotero-export-freshness.sh` correctly emits `ZOTERO_EXPORT_STALE` with a full rationale.
   Root cause: BBT "Keep updated" only fires while Zotero is running, and Zotero is not currently
   running (local API at `127.0.0.1:23119` did not respond; `/connector/ping` connection refused).

5. **Staleness is a WRITE-path hazard, not just a search-quality issue.** `/literature` Mode A
   Tier-2 classification (`in_zotero` / `in_zotero_no_pdf` / new) reads the CSL-JSON export. A
   stale export misclassifies recently-added items as "new", and the Web API performs **no
   server-side dedup** — `item-add` on a misclassified record silently creates a duplicate item.
   The freshness guard exists but is not currently consulted by the write path.

## Current write-path implementation (source-store review)

- `zotero-write.sh` — operations `note-add`, `tag-add`, `tag-remove`, `attach-file`,
  `item-add --pdf [--doi]`; passes `zot` stdout through unparsed; `--dry-run` and
  `--idempotency-key` plumbing already present. Listed **inactive/undeployed** in the README
  deployment-status table.
- `literature-ingest-online.sh` (657 lines, deployed-declared) — the online-discovery →
  Zotero+PDF → ingest bridge. Calls `zotero-write.sh item-add` (create) and `attach-file`
  (existing item without PDF). Its safety design is good and must be preserved:
  - `%PDF` magic-byte gate after every download, before ANY Zotero write.
  - Honest surfacing of the DOI-only fallback ("no PDF attached", never a fabricated success).
  - Defensive multi-path envelope parsing (`extract_envelope_field()` probes `.data.key`,
    `.data.item.key`, `.data.itemKey`, etc.) because the real `zot add --pdf` envelope field
    names are an **unconfirmed empirical unknown** — no live call has ever been made
    (`context/project/literature/patterns/zotero-item-creation.md` section 2 records the required
    live-confirmation follow-up).
  - Attach-to-existing resolves the real item key via `zotero-resolve-pdf.sh` search; a
    `tier == "absent"` result is a full stop, keys are never invented.
- Read path (live, keep as-is): `zotero-search.sh` over the CSL-JSON export; FTS5 corpus search;
  briefing+tools pattern for `--lit`.

## External context that bounds the design (verified via web research, 2026-08)

- Stable Zotero is 9.0.6 (2026-07-07). The **local API at :23119 remains read-only on stable**;
  native local writes (items + file upload, consent via `POST /api/local/authorize`) ship in
  **Zotero 10, currently beta**. The extension's "local API is read-only" finding still holds.
- The **Web API v3 is the correct write path today**: item create via POST (idempotency via
  `Zotero-Write-Token` — this is what `--idempotency-key` should map to), PDF attachment via the
  4-step upload flow, which `zot` wraps. Rate-limit contract: honor `Backoff:` and
  `429`/`Retry-After`.
- **Storage quota**: stored-file uploads count against the zotero.org 300 MB free tier. With 948
  existing attachments the account is either already on paid storage/WebDAV or file sync is off —
  confirm before enabling auto-attach at scale (checked further in the follow-on metadata task).
- Duplicate detection is client-UI-only; agent-side dedup must be DOI-normalized (lowercase,
  strip `https://doi.org/` prefix) lookups against the live library, not the export snapshot.

## Recommended work items (basis for the plan)

1. Correct the stale documentation: README deployment-status table, `zotero-write.sh` header,
   tool-requirements version pin, and `zotero-item-creation.md` where it asserts no key exists.
2. After `zot` is provisioned (cross-repo dependency): perform the live envelope confirmation
   follow-up (capture `jq '.data'` from one real `item-add` and one real `attach-file`; record
   confirmed field paths in `zotero-item-creation.md`; simplify or keep the multi-path probing
   with justification).
3. Deploy the inactive scripts (`zotero-write.sh`, `zotero-read.sh`, `zotero-setup.sh`) through
   the normal extension deploy flow and update the deployment-status table.
4. Wire `zotero-export-freshness.sh` as a gate on the write path: on `ZOTERO_EXPORT_STALE`,
   either refuse item-add or re-verify classification against the live library before writing.
5. Add DOI-normalized pre-write dedup lookup (live library, not the export).
6. Keep `zotero-write.sh` as the single write choke-point so the backend can later swap from
   `zot`/Web-API to the Zotero 10 local API without touching callers.

## Out of scope here (tracked separately)

- Tool provisioning (`zot`, translation-server service, managed `ZOTERO_API_KEY`): ~/.dotfiles
  repo, its task 129.
- translation-server metadata resolution, zotero-mcp adoption decision, storage-quota
  verification, Zotero 10 backend swap: follow-on task 39 in this repo.
