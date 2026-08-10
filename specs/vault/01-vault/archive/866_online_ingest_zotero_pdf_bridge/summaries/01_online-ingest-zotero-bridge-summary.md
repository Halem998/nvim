# Implementation Summary: Task #866

**Completed**: 2026-07-15
**Duration**: ~2.5 hours

## Overview

Built the online-discovery -> Zotero+PDF -> ingest bridge for the literature extension across all
7 planned phases. Added a new `item-add` operation to `zotero-write.sh` (wrapping `zot add --pdf`)
and a new `literature-ingest-online.sh` entry point that classifies a single discovery record via
directive tokens, downloads and magic-byte-verifies the PDF, creates or attaches the Zotero item,
delegates to the unmodified `literature-ingest.sh` pipeline, and patches the resulting metadata
into both the global `index.json` and the per-repo `specs/literature-index.json` sub-index. Wired
the new bridge into `commands/literature.md` Mode A as an opt-in offer, kept `EXTENSION.md`/
`README.md`/`manifest.json`/`index-entries.json` in sync, and added a new pattern doc.

## What Changed

- `agent-system/extensions/literature/scripts/zotero-write.sh` — added the `item-add` operation
  (create-item-with-PDF, no existing KEY required, unlike every other operation) wrapping
  `zot add --pdf`/`zot add --doi`; reused the existing dependency checks, exit-code contract, and
  `--dry-run`/`--idempotency-key` passthrough pattern. Existing operations (`note-add`, `tag-add`,
  `tag-remove`, `attach-file`) are unchanged (regression-tested).
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` — new entry point
  (~470 lines). Documents a STABLE CONTRACT header (input schema, 8 directive tokens, exit codes
  0/1/2/3/4/5/6/64) since tasks building on top of this bridge depend on it. Implements: directive-
  token classification keyed off `(status, arxiv_id, pdf_url)`; `curl` download + mandatory `%PDF`
  magic-byte gate; an optional non-blocking title-similarity duplicate check; the create-item path
  (`zotero-write.sh item-add` -> defensive multi-path envelope field extraction -> storage
  re-pointing -> delegate to the unmodified `literature-ingest.sh` -> `index.json` metadata patch
  -> `specs/literature-index.json` sub-index upsert); and the `in_zotero_no_pdf` attach-to-existing
  path (resolve the real Zotero key via the unmodified `zotero-resolve-pdf.sh` over stdin, discover
  a PDF URL via an Unpaywall DOI lookup, `zotero-write.sh attach-file`, then reuse the same
  ingest/patch/register machinery).
- `agent-system/extensions/literature/commands/literature.md` — new step "3.5" in Mode A's
  discover workflow: offers "Ingest into Literature now" vs. "Just record in SOURCES.md" for
  `open_access`/`paywall`/`in_zotero_no_pdf` selections, branches on every directive token, and
  falls back to today's SOURCES.md/sub-index behavior honestly on any non-success token. Steps 4
  and 5 updated to add a `[RESOLVED]` SOURCES.md row and skip redundant sub-index writes for
  already-ingested entries.
- `agent-system/extensions/literature/EXTENSION.md`, `README.md` — script table rows for
  `literature-ingest-online.sh`; updated `zotero-write.sh` row/description; Mode A prose describes
  the new ingest offer; README's Deployment Status section notes `zotero-write.sh` now has a
  live source-tree caller (still blocked at runtime by the `zot` CLI being uninstalled here).
- `agent-system/extensions/literature/manifest.json` — added `literature-ingest-online.sh` to
  `provides.scripts`.
- `agent-system/extensions/literature/index-entries.json` — registered the new pattern doc.
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  (new) — documents the `item-add`/`zot add --pdf` capability, the unconfirmed-envelope-fields
  empirical unknown and its defensive multi-path mitigation, the mandatory `%PDF` gate, storage
  re-pointing, the `in_zotero_no_pdf` attach-to-existing sub-path, and this development machine's
  verification-scope limitation (see Decisions below).

## Decisions

- **No real `zot` CLI or Zotero account is available in this development environment.** Rather
  than skip empirical verification silently, Phase 1 verified `zotero-write.sh item-add`'s command
  construction, `--dry-run` echo, and argument passthrough against a stub `zot` executable
  returning a synthetic JSON envelope. The real `zot add --pdf` `data.*` field names remain an
  unconfirmed empirical unknown, documented explicitly (not fabricated) in the new pattern doc, and
  mitigated in code via a defensive multi-jq-path field extraction rather than assuming one shape.
- **A real, already-running Zotero instance was discovered bound to `127.0.0.1:23119` on this
  machine** while building a mock server to test the `in_zotero_no_pdf`/live-API resolution path
  (a failed bind attempt returned real library data). To avoid any risk of touching the user's real
  Zotero library, further live-API mocking for Phase 6 was abandoned. The honest `tier=absent`
  stop was verified safely (read-only, GET-only) against the real API with a fabricated,
  guaranteed-non-matching title; the full resolved-and-attached success sub-path relies on
  helpers (`download_and_verify`, `resolve_storage_path_from_envelope`, `run_ingest_pipeline`,
  `patch_global_index`, `upsert_subindex`) already fully verified end-to-end by the create-item
  path test, plus the `attach-file` command construction verified in Phase 1's stub-`zot` test.
- **A hand-built minimal valid PDF (raw PDF byte structure with a text-drawing content stream) and
  a stub `zot` executable** were used to exercise the full create-item path end-to-end for real,
  including the actual (unmodified) `literature-convert.sh`/`literature-chunk.sh`/
  `literature-build-index.sh` via PyMuPDF and `pdftotext` (both available in this environment).
- **Numbered the new Mode A command branch "3.5"**, not "3b", to avoid colliding with the
  unrelated pre-existing top-level `<step_3b>` XML tag (rebuild mode) in the same file.

## Plan Deviations

- **Task 1.4** (empirical `zot add --pdf` envelope verification) altered: verified via a stub `zot`
  executable instead of a genuine live call, since no `zot` binary or configured Zotero API key is
  available in this sandboxed environment. Real field names are a documented follow-up.
- **Task 6 verification scope** altered: the full live-API attach-path end-to-end run was narrowed
  to avoid touching the real, already-running Zotero instance discovered on this machine; see the
  Phase 6 verification-scope note in the plan and Decisions above.
- **Task 7.1 numbering** altered: the new Mode A ingest-offer branch is numbered "3.5" rather than
  "3b" to avoid colliding with an unrelated existing `<step_3b>` XML tag.
- A real bug was found and fixed during Phase 4 end-to-end testing (not itself a plan deviation,
  but worth flagging): `literature-ingest.sh`'s `log_out()` prefixes stdout lines with `[ingest] `,
  so the original `^Ingested: ` extraction regex never matched, silently falling back to the wrong
  doc_id and making the Phase 5 metadata patch a no-op. Fixed to match
  `^\[ingest\] Ingested: ` with a `^Documents ingested: ` fallback.

## Verification

- Build: N/A (bash/jq scripts; `bash -n` passed on both modified/new scripts)
- Tests: Passed — classification (all statuses), download+magic-byte gate (valid PDF, HTML landing
  page, nonexistent path), duplicate-title warning, full end-to-end create-item path (item-add via
  stub, storage re-point, real unmodified `literature-ingest.sh` conversion/chunk/index, metadata
  patch, sub-index upsert, idempotency on re-run), `in_zotero_no_pdf` honest-stop path (real,
  read-only live-API call), regression on `zotero-write.sh`'s pre-existing operations, and
  `bash .claude/scripts/check-extension-docs.sh` (PASS for literature and all other extensions).
- Files verified: Yes — `git diff --stat` confirms `literature-ingest.sh`, `literature-convert.sh`,
  `literature-chunk.sh`, `literature-build-index.sh` are byte-for-byte unmodified.

## Notes

- Follow-up recorded in `zotero-item-creation.md`: the first time this bridge runs against a real
  `zot` installation and configured Zotero library, capture `jq '.data'` on a real `item-add` and
  `attach-file` envelope and update the pattern doc with the confirmed field names.
- Tasks building on this interface should treat the `literature-ingest-online.sh` header comment
  block (input schema, 8 directive tokens, exit codes) as the stable, load-bearing contract.
