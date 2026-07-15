# Zotero Item Creation Pattern

How the online-discovery -> Zotero+PDF -> ingest bridge (`literature-ingest-online.sh`) creates a
brand-new Zotero item with an attached PDF, re-points at the durable storage copy, and hands off
to the unmodified `literature-ingest.sh` pipeline. Companion to `zotero-pdf-resolution.md`, which
covers resolving an *existing* doc_id to its Zotero PDF; this document covers the complementary
*create-item* direction.

## 1. The capability is `zot add --pdf`, wrapped by `zotero-write.sh item-add`

Every other `zotero-write.sh` operation (`note-add`, `tag-add`, `tag-remove`, `attach-file`)
mutates an item that already exists — each takes a mandatory `KEY` argument. `item-add` is the one
operation that does **not**: it creates a brand-new bibliographic item (optionally with a PDF
attachment) via a single atomic `zot add --pdf <path>` call, which the `zotero-cli-cc` (`zot`)
CLI documents as: "extracts DOI from the PDF, creates the item, and attaches the file." A
companion `--doi <doi>` flag may be passed alongside `--pdf` (forwarded to `zot` to
corroborate/skip its own DOI-from-PDF extraction), or used alone as an item-only fallback with
**no** attachment — callers must treat that fallback as "no PDF attached" and surface it honestly,
never as a full success.

The local HTTP API at `127.0.0.1:23119` is confirmed read-only (every endpoint is a GET); it
cannot create items. All writes — including `item-add` — go through the Web API via `zot`, using
the same `$ZOTERO_API_KEY` dependency `zotero-write.sh` already requires for its other operations.

## 2. The `zot add --pdf` envelope's exact `data.*` field names are an unconfirmed empirical unknown

No `zot` binary, and no configured Zotero API key/account, is present in every development
environment this bridge has been built and tested in so far. This means the item key, attachment
key, and storage-path field names inside the JSON envelope `zot add --pdf` returns
(`{"ok": bool, "data": {...}, "meta": {...}}` per `zotero-cli-cc`'s documented shape) have **not**
been independently confirmed against a real call.

**Mitigation applied**: `literature-ingest-online.sh`'s `extract_envelope_field()` and
`resolve_storage_path_from_envelope()` helpers probe several plausible jq field paths in order
(e.g. `.data.key`, `.data.item.key`, `.data.itemKey` for the item key; `.data.attachment.key`,
`.data.attachmentKey`, `.data.attachment_key`, `.data.attachments[0].key` for the attachment key)
rather than assuming one shape. If none resolve, the script does not fail hard — it falls back to
the original staging download path for `source_path`/`zotero_path`, logs a visible (non-silent)
warning, and continues. `zotero-write.sh` itself does not parse the envelope at all; like every
other operation, it passes `zot`'s stdout straight through unmodified, so the parsing
responsibility (and the defensive multi-path lookup) lives entirely in the caller.

**Required follow-up**: the first time this bridge is exercised against a real `zot` installation
and a real, configured Zotero library, capture `jq '.data'` on the raw envelope from both a real
`item-add` call and a real `attach-file` call, and update this document with the confirmed field
paths. Until then, treat the multi-path probing above as the load-bearing mechanism, not a
placeholder.

## 3. The mandatory `%PDF` magic-byte gate runs before ANY Zotero write

`pdf_url` values sourced from Semantic Scholar / Unpaywall / arXiv can resolve to a cookie-wall or
landing-page HTML document served with a 200 status rather than actual PDF bytes. Silently
creating a Zotero item and attachment from such a file would fabricate a download the honest-
surfacing invariant explicitly prohibits.

```bash
curl -sL --fail --max-time 30 -o "$dest" "$url"
magic="$(head -c4 "$dest")"
if [ "$magic" != "%PDF" ]; then
  # ONLINE_INGEST_DOWNLOAD_FAILED -- never fall through to item creation
fi
```

This check runs immediately after every download, in both the create-item path (Phase 3/4) and
the attach-to-existing path (Phase 6, where the PDF URL itself first has to be discovered via an
Unpaywall DOI lookup against the resolved item's DOI, since Tier-2 `in_zotero_no_pdf` discovery
records carry no `pdf_url` of their own). Any curl failure or magic-byte mismatch is a full stop
— no Zotero write of any kind is attempted afterward.

## 4. Storage re-pointing reuses the derived-storage-root rule from `zotero-pdf-resolution.md`

Once an item (and, ideally, its attachment) exists, Zotero copies the uploaded file into its own
managed `storage/<attachmentKey>/<filename>` tree. The bridge re-points the file it hands to
`literature-ingest.sh` at that durable copy — not the ephemeral staging download — so
`source_path`/`zotero_path` in the resulting `index.json` entry reference a permanent location.
The storage root itself is **always derived**, never hardcoded, exactly as `zotero-resolve-pdf.sh`
already does:

```bash
ZOTERO_SQLITE="$(bash zotero-resolve-sqlite-path.sh)"
ZOTERO_DATA_DIR="$(dirname "$ZOTERO_SQLITE")"
ZOTERO_STORAGE_ROOT="$ZOTERO_DATA_DIR/storage"
```

If the resolved storage path does not exist (unconfirmed field names above, or the copy has not
landed yet), the bridge falls back to the original staging path and logs this honestly as a
follow-up rather than claiming a false success.

## 5. `in_zotero_no_pdf` is an attach-to-existing problem, not a create-item problem

A Tier-2 discovery record with `status == "in_zotero_no_pdf"` refers to an item that **already
exists** in Zotero but lacks a PDF attachment. This case reuses `zotero-write.sh attach-file`
(pre-existing capability) against the *resolved* real Zotero item key — never `item-add`. The
citation_key a Tier-2 record carries is not guaranteed to be the literal 8-character Zotero API
key (see `zotero-pdf-resolution.md` finding #5), so the real key must be resolved via
`zotero-resolve-pdf.sh`'s existing title/author search logic (piped a synthesized
`{doc_id, record}` object over stdin) before any attach call — never assumed or invented. A
`tier == "absent"` result from that resolver is a full, honest stop; the bridge never fabricates a
key.

A corrective edge case worth knowing: if the resolver's `resolved_path` field is non-empty despite
the record's own `in_zotero_no_pdf` classification, the underlying Zotero item actually already has
a PDF attached (the classification came from a stale `zotero-library.json` CSL-JSON snapshot — see
`zotero-pdf-resolution.md` finding #4 on staleness). The bridge detects this and skips the
attach-file call entirely, using the already-existing PDF directly.

## 6. Verification scope limitation on this development machine

A real, already-configured Zotero instance was found running and bound to `127.0.0.1:23119` on the
machine this bridge was developed and tested on (discovered via a failed attempt to bind a mock
server to that port for testing purposes). To avoid any risk of touching a real user's Zotero
library, live-API mocking was abandoned mid-testing. What was verified instead: the honest
`tier == "absent"` stop path (a safe, read-only real-API call with a fabricated, guaranteed-
non-matching title), full end-to-end exercise of the create-item path using a stub `zot`
executable (never the real CLI, which is not installed in this environment either), and code-level
reuse confirmation that the attach-to-existing path shares every downstream helper
(`download_and_verify`, `resolve_storage_path_from_envelope`, the `literature-ingest.sh` delegate,
the metadata patch, and the sub-index upsert) with the already-fully-tested create-item path.

## Reference implementation

`literature-ingest-online.sh` — see its header comment block for the full STABLE CONTRACT (input
schema, directive tokens, exit codes) that downstream tooling built on top of this bridge depends
on.
