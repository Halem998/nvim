# Research Report: Task #109

**Task**: 109 - Fix three distinct failure modes in the online-ingest bridge, each observed on a real record
**Started**: 2026-09-01T23:00:00Z
**Completed**: 2026-09-01T23:40:00Z
**Effort**: ~1 session
**Dependencies**: specs/102_characterize_converter_tiers_and_ocr_vintage (completed; consumed for defect (c))
**Sources/Inputs**: codebase (agent-system/extensions/literature/scripts/*), zot CLI Python source (~/.local/share/uv/tools/zotero-cli-cc v0.10.0), task 102 summary/report/plan
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **(a)** The real root cause is one layer below either bridge script: `zot add --pdf` (installed
  `zotero-cli-cc` v0.10.0, `commands/add.py::_add_from_pdf`) internally regex-extracts a DOI from
  the PDF's first two pages when no `--doi` override is passed, and **hard-fails (exit 3, no item
  created)** if it finds none — it does not degrade to a bare item as the existing pattern doc
  implies. arXiv 1009.2803 (a 2010 preprint with no printed DOI) hits exactly this. Fix: derive
  and pass `10.48550/arXiv.<arxiv_id>` (arXiv's own mechanical DataCite DOI) as `--doi` whenever a
  record has `arxiv_id` set and `doi` is null.
- **(b)** The task's pointed-to location (`.online-ingest-staging/` at literature-ingest-online.sh:274)
  already self-cleans on download failure. The actually-observed orphan directory
  (`sources/arxiv_1009_2803/`) comes from a different, pre-existing bug in `literature-ingest.sh`'s
  own per-file loop, which `mkdir -p`s the doc directory before conversion but never removes it on
  three separate no-cleanup `continue` branches.
- **(c)** Task 102's converter-tier characterization (Class A vs. Class B gate-rejection causes,
  responding oppositely to the fallback engine) forecloses any automatic retry. The only fix
  consistent with that finding is enriching the failure message with a manual, actionable
  diagnostic pointer — no new control flow.

## Context & Scope

Three independently observed failure modes in the online-discovery -> Zotero+PDF -> ingest bridge
(`literature-ingest-online.sh`, `zotero-write.sh`, and the downstream `literature-ingest.sh`
pipeline it delegates to), each triggered by a real record during a `/research --lit` run in
another repo on 2026-08-26. Source store is
`agent-system/extensions/literature/` (edit target; `.claude/` is a disposable deploy copy,
confirmed byte-identical at task creation).

## Findings

### (a) arXiv-only open_access record fails Zotero item creation

**Codebase Patterns / confirmed call chain**:
- `literature-ingest-online.sh:692-696` builds `zotero-write.sh item-add --pdf $STAGING_PATH`,
  appending `--doi $DOI_RAW` only when the record's `doi` field is non-null (it is null for this
  record — arXiv-only, no DOI ever resolved by discovery).
- `zotero-write.sh:285-320` (`item-add` case) requires `--pdf` or `--doi`; with only `--pdf` it
  runs `zot add --pdf "$PDF_PATH"` with no `--doi`. On failure it collapses `zot`'s real exit code
  to a generic exit 1 with a generic message — the real diagnostic text only survives in stderr,
  which `literature-ingest-online.sh:699-701` captures into `$ITEM_ADD_STDERR` and relays into the
  `ONLINE_INGEST_ZOTERO_CREATE_FAILED` directive_stop rationale (`literature-ingest-online.sh:704-706`).

**External resources / zot's own source (ground truth, not previously confirmed in-repo)**:
`zot` is installed at `/etc/profiles/per-user/benjamin/bin/zot`, backed by
`~/.local/share/uv/tools/zotero-cli-cc` (v0.10.0). Read `commands/add.py` in full:

```python
# _add_from_pdf(pdf_path, doi_override, ...):
doi = doi_override
if not doi:
    doi = extract_doi(pdf_path)     # core/pdf_extractor.py: regex 10\.\d{4,9}/\S+ over pages 1-2
if not doi:
    emit_error(
        "validation_error",
        "No DOI found in PDF",
        hint="Use --doi to specify the DOI manually: zot add --pdf paper.pdf --doi '10.1234/...'",
        context="add",
    )   # raises SystemExit(EXIT_VALIDATION=3) -- NO item is created, not even a bare one
```

`extract_doi`/`PdfiumExtractor.extract_doi`/`PyMuPdfExtractor.extract_doi` (all three converge on
the same behavior) scan only the first two pages of extracted text for `10\.\d{4,9}/[^\s]+`. arXiv
1009.2803 (Gehrke & Vosmaer, a 2010 preprint) has no DOI printed on the PDF itself — arXiv's
retroactive DataCite DOI minting (started ~Nov 2022) is a metadata-only assignment, never printed
on older preprints' PDF text — so the regex finds nothing, `_add_from_pdf` calls `emit_error`
before ever calling `writer.add_item`, and `zot add --pdf` exits 3 with **no Zotero item created
at all**. This fully explains the observed `ONLINE_INGEST_ZOTERO_CREATE_FAILED(3)`.

This is a genuinely different mechanism from the original (rejected) "hard-requires a DOI" framing:
the requirement doesn't live in either bridge script's own logic (confirmed clean at both layers —
`zotero-write.sh:287`'s check accepts `--pdf` OR `--doi`, and `literature-ingest-online.sh:692-696`
already omits `--doi` correctly when absent) — it lives one layer further down, inside `zot add
--pdf`'s own internal DOI-from-PDF-text fallback, which has no equivalent fallback for records
whose PDF simply never carries a printed DOI.

### Recommendations (a)

- In `literature-ingest-online.sh`, when `$DOI_RAW` is empty and `$ARXIV_ID_RAW` (or equivalent) is
  non-empty, derive `SYNTH_DOI="10.48550/arXiv.$ARXIV_ID_RAW"` and add `--doi "$SYNTH_DOI"` to
  `ZW_CMD` (same code path as the existing `if [ -n "$DOI_RAW" ]` branch at line ~693). This is a
  mechanical, universally-applicable derivation — no external lookup needed — and short-circuits
  `_add_from_pdf`'s `doi_override`, bypassing the fragile PDF-text regex entirely regardless of
  whether the PDF happens to carry a printed DOI.
- **Honest caveat to carry into the plan**: Crossref's `resolve_doi` (used only when `--doi`
  accompanies `--pdf`) will not resolve a DataCite DOI like `10.48550/arXiv.*` (Crossref only knows
  Crossref-registered DOIs) — `resolved_summary` will be `None` and the created Zotero item will be
  metadata-bare (DOI field only) on the Zotero side. This does not affect `patch_global_index`
  (literature's own index.json metadata patch), which sources title/authors/year from the
  discovery record directly, not from Zotero's resolved metadata — so the corpus-side metadata is
  unaffected either way.
- **Test-vehicle gotcha**: `zot add --dry-run` (`add.py`'s top-level `if dry_run:` branch) returns
  a static preview dict and returns immediately — it never calls `_add_from_pdf`, so it cannot
  exercise or reproduce this failure at all. Verifying the fix requires either a stub `zot`
  executable (already used for the create-item path per
  `context/project/literature/patterns/zotero-item-creation.md` §6) or a live, authorized call.
- **Documentation correction owed**: `context/project/literature/patterns/zotero-item-creation.md`
  §1 currently states a `--pdf`-only create "yields a barer item" than one with `--doi` — this
  should be corrected/extended to note it can also hard-fail outright (exit 3, no item at all) when
  no DOI is extractable from the PDF text and none is passed explicitly.

## (b) Orphan staging directory after a failure path

**Scope correction — the task's pointed-to file is not the actual leak**:
`literature-ingest-online.sh:274`'s `mkdir -p "$(dirname "$dest")"` creates
`$LITERATURE_DIR/.online-ingest-staging/` (a single shared flat directory, reused across every
ingest, not a per-document directory). `download_and_verify()` already runs `rm -f "$dest"` on
**both** the curl-failure branch and the magic-byte-mismatch branch (lines ~276, ~284) — so
`ONLINE_INGEST_DOWNLOAD_FAILED(2)` is already clean; no orphan file survives that path today.

**The real, narrower leak in `literature-ingest-online.sh`**: the staging **file**
(`$STAGING_DIR/${SANITIZED_DOC_ID}.pdf`) is left behind whenever a *later* step fails after a
successful download — specifically `ONLINE_INGEST_ZOTERO_CREATE_FAILED(3)`
(`literature-ingest-online.sh:704-706`) and `ONLINE_INGEST_ZOTERO_ATTACH_FAILED(5)`
(`literature-ingest-online.sh:~801-803`, the attach-to-existing-item path). This is exactly what
happened for the arXiv 1009.2803 record in defect (a): "the PDF downloaded and passed %PDF
magic-byte verification, then item-add failed" — the staging PDF file should still exist at
`$LITERATURE_DIR/.online-ingest-staging/arxiv_1009_2803.pdf` (or whatever `sanitize_doc_id`
produces for this doc_id) after that failure.

**The actually-observed orphan (`$LITERATURE_DIR/sources/arxiv_1009_2803/`, an empty directory
with no index entry) is a different bug in a different file**: `literature-ingest.sh`'s own
per-file loop (not touched by the online bridge's own logic, but invoked by it via
`run_ingest_pipeline()`):

- `literature-ingest.sh:193` and again `:266-267`: `DOC_DIR="$LITERATURE_DIR/sources/$BASE_DOC_ID"`
  (or `$DOC_ID` once known) followed by `mkdir -p "$DOC_DIR"`, executed **before** the conversion
  step even runs.
- On `CONVERT_EXIT -eq 3` (quality-gate rejection — this is defect (c)'s exact failure mode,
  `literature-ingest.sh:227-236`) the loop does `rm -rf "$TMP_MD_DIR"; rm -f
  "$CONVERT_STDERR_FILE"; continue` — **`$DOC_DIR` is never removed**.
- On `CONVERT_EXIT -ne 0` (hard conversion failure, `:237-242`) the same gap exists: `$TMP_MD_DIR`
  is cleaned, `$DOC_DIR` is not.
- On chunking failure (`CHUNK_COUNT -eq 0 || ! -f "$DOC_DIR/chunks.json"`, `:276-279`) the same
  gap exists again: `FAILED` is incremented and the loop `continue`s without touching `$DOC_DIR`.

This is a **pre-existing latent bug in `literature-ingest.sh` itself**, reachable from any caller
(local-file ingest, `--zotero` ingest, or the online bridge) — the online bridge simply exposes it
more often because it feeds freshly-downloaded, unvetted PDFs into the pipeline. It correlates with
the bridge's own `ONLINE_INGEST_PIPELINE_FAILED(6)` directive_stop
(`literature-ingest-online.sh:735-738`), **not** with `CREATE_FAILED`/`ATTACH_FAILED`/
`DOWNLOAD_FAILED` as originally framed — a record only reaches `run_ingest_pipeline()` (and hence
this bug) after item-add/attach has already succeeded.

**Constraint simplification worth flagging to the planner**: the task asked for a "guard on
we-created-it-this-run, not on it-looks-empty-now" to avoid ever deleting a pre-existing populated
`sources/` directory. This guard already exists structurally in `literature-ingest.sh` and does not
need to be re-invented: at `:203-210`, before the `mkdir -p "$DOC_DIR"` in question, the loop
already checks `index.json` for a pre-existing entry with this `doc_id` and, if found,
**unconditionally `rm -rf`s `$DOC_DIR` and recreates it** ("Re-ingesting ... deleting old
chunks"). By the time the loop reaches the conversion step, `$DOC_DIR` is therefore always either
brand-new or freshly wiped-and-recreated *this iteration* — an unconditional `rm -rf "$DOC_DIR"`
added to the three no-cleanup `continue` branches above is safe without any additional
"did-we-create-it" bookkeeping.

### Recommendations (b)

- **`literature-ingest-online.sh`**: add `rm -f "$STAGING_PATH"` (or equivalent) immediately before
  (or inside) the `directive_stop` calls for `ONLINE_INGEST_ZOTERO_CREATE_FAILED(3)` and
  `ONLINE_INGEST_ZOTERO_ATTACH_FAILED(5)` — the only two stops that fire after a successful
  download in each respective path.
- **`literature-ingest.sh`**: add `rm -rf "$DOC_DIR"` to the three `continue` branches identified
  above (quality-gate rejection, hard conversion failure, chunking failure). No additional
  existence/emptiness guard is required per the simplification above.
- `ONLINE_INGEST_DOWNLOAD_FAILED(2)` needs no change — already clean.

## (c) Pipeline failure with no fallback-engine attempt

**Dependency consumed**: `specs/102_characterize_converter_tiers_and_ocr_vintage/summaries/
01_correct-converter-tier-remedy-claim-summary.md` and the guide section it added
(`agent-system/extensions/literature/context/guides/literature-organization.md`, "## Converter
Tier Selection", ~line 346), both read in full.

**Key established facts (task 102, already completed)**:
- Two failure classes respond **oppositely** to the PyMuPDF column-clustering fallback engine:
  - **Class A** (primary-tier structuring artifact — e.g. `<sup>`/`<sub>` mis-wrapping, table
    misdetection): fallback tier fixes it. Confirmed: `savage_1972_foundations-of-statistics`
    (73 hits -> 3), `bacon_dorr_2024_classicism`.
  - **Class B** (text-layer/OCR defect, already present before either tier's structuring layer
    runs): fallback tier does nothing or adds noise. Confirmed:
    `joyce_1999_foundations-causal-decision-theory` (4 hits -> 5, i.e. *worse*).
- The discriminator (where the gate-rejection hits fall — structurally clustered near
  footnotes/back matter vs. scattered at clean sentence boundaries) is explicitly documented as
  **not computable a priori from document metadata** (page count, scan status, ingestion source).
  The guide states outright: **"No automatic tier selection exists or is intended."**
- An unconditional auto-retry-with-fallback on any `ONLINE_INGEST_PIPELINE_FAILED` would directly
  reintroduce the exact falsified universal-remedy claim task 102 was created to correct, and would
  actively regress Class B documents (like `joyce_1999`) by masking a real OCR defect.

**Existing diagnostic surface already available to relay**: `literature-convert.sh:902-903`
already writes the full rejected markdown to `$rejected_path` and prints
`[convert] QUALITY GATE FAILED (<engine>): <reasons>` to stderr before exiting 3.
`run_ingest_pipeline()` (`literature-ingest-online.sh:569-588`) already captures this stdout+stderr
verbatim (`stdout_capture=$("$ingest_script" ... 2>&1)`) and forwards it into the
`ONLINE_INGEST_PIPELINE_FAILED` directive_stop's rationale string at `:736-738` today — but the
message currently only names the doc_id and source path, not the rejected-file location or any
next-step guidance.

### Recommendations (c)

- Message-text-only change (no new control flow, consistent with "no automatic tier selection"):
  enrich the `ONLINE_INGEST_PIPELINE_FAILED` rationale at `literature-ingest-online.sh:736-738` to
  explicitly point at the preserved `$rejected_path` output and the "Converter Tier Selection"
  diagnostic procedure in `context/guides/literature-organization.md` — i.e. "inspect where the
  reported hits fall: clustered near structure/footnotes -> try
  `LITERATURE_CONVERTER=fallback` and reconvert (Class A); scattered at otherwise-clean sentence
  boundaries -> re-OCR the source first, e.g. `ocrmypdf --force-ocr` (Class B) — do not retry
  automatically."
- Do **not** implement any auto-retry, auto-select, or heuristic classifier for Class A vs. Class
  B — task 102 forecloses this explicitly, and no metadata-only discriminator exists.

## Test Vehicle Notes (all three defects)

- `literature-discover.sh` Tier 3 was HTTP-429-throttled during the original observed session and
  cannot be relied on for automated discovery during verification; construct record JSON by hand
  per the documented input schema (`literature-ingest-online.sh` header, lines ~20-38) to exercise
  each `directive_stop` path directly.
- `--dry-run` is **not sufficient** to exercise or verify defect (a) or defect (b): `zot
  add --dry-run` never reaches `_add_from_pdf` (so it cannot reproduce the DOI-extraction failure),
  and `literature-ingest-online.sh --dry-run` returns before any download or delegate call (so no
  staging file or `sources/` directory is ever created to clean up). Verifying (a) and (b) needs
  either a stubbed `zot`/`literature-convert.sh` executable (precedent: the create-item path stub
  used per `zotero-item-creation.md` §6) or a forced-failure real invocation.
- Defect (c)'s message-text change can be verified directly by forcing a quality-gate rejection
  (e.g. feeding a known Class-B-shaped fixture through the pipeline) and checking the resulting
  directive_stop rationale text for the new pointer.

## Risks & Mitigations

- Risk: synthesizing `10.48550/arXiv.<id>` DOIs could be mistaken for a "real" bibliographic DOI
  downstream. Mitigation: document it explicitly as a mechanical fallback identifier in code
  comments and in the plan/summary, distinct from a resolved published-venue DOI.
- Risk: `rm -rf "$DOC_DIR"` in `literature-ingest.sh` touches a file outside the online-ingest
  bridge's own script, technically modifying the "unmodified" downstream pipeline referenced in
  `zotero-item-creation.md`. Mitigation: this is a narrow, safety-preserving bug fix (confirmed
  safe per the existing re-ingestion `rm -rf` precedent at the same call site) applicable to every
  caller of `literature-ingest.sh`, not an online-ingest-specific behavior change — worth calling
  out explicitly in the plan so it isn't mistaken for scope creep.

## Context Extension Recommendations

- **Topic**: `zot add --pdf`'s internal DOI-requirement behavior.
  **Gap**: `context/project/literature/patterns/zotero-item-creation.md` §1 describes a `--pdf`-only
  create as merely "barer" than a `--doi`-accompanied one; it does not document that it can hard-fail
  (exit 3, no item at all) when no DOI is extractable from the PDF text and none is passed.
  **Recommendation**: extend §1 with the `_add_from_pdf`/`extract_doi` mechanism and the arXiv-DOI
  mitigation once implemented.

## Appendix

- Files read in full or in relevant part: `agent-system/extensions/literature/scripts/
  literature-ingest-online.sh`, `zotero-write.sh`, `literature-ingest.sh`; `~/.local/share/uv/tools/
  zotero-cli-cc/lib/python3.13/site-packages/zotero_cli_cc/{commands/add.py,core/pdf_extractor.py,
  core/writer.py,core/metadata_resolver.py,exit_codes.py}`; `agent-system/extensions/literature/
  context/project/literature/patterns/zotero-item-creation.md`; `agent-system/extensions/literature/
  context/guides/literature-organization.md` ("## Converter Tier Selection"); `specs/
  102_characterize_converter_tiers_and_ocr_vintage/summaries/
  01_correct-converter-tier-remedy-claim-summary.md`.
- Confirmed `zot` install location and version: `/etc/profiles/per-user/benjamin/bin/zot`,
  `zotero_cli_cc` v0.10.0 at `~/.local/share/uv/tools/zotero-cli-cc`.
