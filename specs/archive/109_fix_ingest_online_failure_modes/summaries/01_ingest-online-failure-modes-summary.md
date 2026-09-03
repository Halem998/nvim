# Implementation Summary: Task #109

- **Task**: 109 - Fix three distinct failure modes in the online-ingest bridge
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T23:35:00Z
- **Completed**: 2026-09-02T00:50:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: specs/102_characterize_converter_tiers_and_ocr_vintage (completed; consumed for defect (c))
- **Artifacts**: plans/01_ingest-online-failure-modes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed three independently-observed failure modes in the online-discovery -> Zotero+PDF -> ingest
bridge, each at the layer where it actually originates: (a) `zot add --pdf` hard-failing on
arXiv-only records with no real DOI, (b) two separate orphan-leak defects (a staging PDF file, and
`sources/<doc_id>/` directories), and (c) an unhelpful `ONLINE_INGEST_PIPELINE_FAILED` rationale
on quality-gate rejections. All edits landed in the source store
(`agent-system/extensions/literature/`); a reusable forced-failure/stub harness was built first
since `--dry-run` cannot reach any of these three defects' code paths.

## What Changed

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` — added an
  `elif [ -n "$ARXIV_ID_RAW" ]` arm deriving `10.48550/arXiv.<id>` as a `--doi` fallback for
  arXiv-only records (defect a); added `rm -f "$STAGING_PATH"` before both post-download
  `directive_stop` sites (`ONLINE_INGEST_ZOTERO_CREATE_FAILED`, `ONLINE_INGEST_ZOTERO_ATTACH_FAILED`)
  (defect b, part 1); added a shared `pipeline_failed_diagnostic_hint()` helper and wired it into
  both `ONLINE_INGEST_PIPELINE_FAILED` sites, message-text only (defect c).
- `agent-system/extensions/literature/scripts/literature-ingest.sh` — added `rm -rf "$DOC_DIR"` to
  all five no-cleanup `continue` branches in the per-file loop (defect b, part 2); added an
  optional `rmdir` safety sub-step for when the converter-derived `DOC_ID` differs from
  `BASE_DOC_ID`; fixed a pre-existing `set -e`/`pipefail` bug that made the "no `.md` produced"
  branch unreachable (see Decisions).
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  — corrected §1's "yields a barer item" understatement to document the real hard-fail mechanism
  (`_add_from_pdf` -> `extract_doi()` -> `SystemExit(3)`) and the implemented arXiv-DOI mitigation
  with its Crossref/DataCite caveat; extended §6 with a `--dry-run` limitation note.
- `specs/109_fix_ingest_online_failure_modes/harness/` — new task-local forced-failure/stub
  verification harness (synthetic records, six stub executables, `run-harness.sh` driver with a
  real-corpus safety trap, `README.md` with verbatim reproduction commands). Not part of the
  deployed fix; scratch run output is gitignored.

## Decisions

- **Phase 1 harness stub count widened from 2 to 6.** The `existing_no_pdf`/attach path needed
  stubs for `zotero-resolve-pdf.sh` (avoids a real call to the local Zotero HTTP API) and
  `zotero-read.sh` (the dedup `search` op), a `curl` stub (intercepting only `api.unpaywall.org`,
  passing every other URL — including the real arXiv PDF downloads — straight through to the real
  binary), and a `literature-chunk.sh` stub (deterministic chunking-failure control), beyond the
  originally-hypothesized `zot` and `literature-convert.sh` stubs.
- **Phase 4's "preserved rejected markdown" claim was corrected.** `literature-convert.sh`'s
  `.rejected` sibling is written into `literature-ingest.sh`'s own `mktemp -d` `TMP_MD_DIR`, which
  is `rm -rf`'d on the quality-gate `continue` branch before the online-ingest bridge's
  `run_ingest_pipeline()` ever returns — it does not actually survive through this delegation
  path. The enrichment message was corrected to point at manually re-running
  `literature-convert.sh` against the still-durable resolved PDF path instead of naming a file
  that no longer exists by the time the rationale is read.
- **Phase 5's branch count rose from 4 to 5, and one branch was found unreachable.** A concurrent,
  independently-committed change (an unrelated OCR-needed bucketing feature) landed a fifth
  no-cleanup `continue` branch in `literature-ingest.sh` while this task was in flight; it leaks
  identically and was fixed alongside the original four. Separately, the "conversion reported
  success but no `.md` file found" branch was found to be **dead code**: under this script's
  `set -eo pipefail`, `DOC_ID=$(ls "$TMP_MD_DIR"/*.md 2>/dev/null | head -1 | xargs ...)` crashes
  the entire script with a bare, unexplained exit when no `.md` exists (the unmatched glob makes
  `ls` fail, and `pipefail` propagates that failure through the pipeline into the assignment's own
  exit status, which `set -e` then treats as fatal) — control never reaches the `if [ -z "$DOC_ID" ]`
  check the intended cleanup lives in. This was found empirically via the harness's `no-md-orphan`
  scenario (added proactively, beyond Phase 5's own stated verification bullets) and confirmed
  with a minimal standalone reproduction. Fixed with a one-line, non-scope-creeping `|| true` guard
  on the assignment; without it, the `rm -rf "$DOC_DIR"` this phase adds to that branch would never
  execute.
- **`literature-ingest.sh` modified despite the bridge header calling it the "UNMODIFIED
  literature-ingest.sh pipeline."** This is a narrow, safety-preserving cleanup fix that benefits
  every caller of `literature-ingest.sh` (not just the online-ingest bridge), not a
  bridge-specific behavior change. No pipeline semantics, stdout contract, exit codes, or
  `GATE_FAILED`/`FAILED` counter behavior changed — verified via the harness's positive-control
  scenario and by direct diff read-through.
- **Accepted, not worked around**: the synthesized `10.48550/arXiv.<id>` DataCite DOI will not
  resolve via Crossref, so the resulting Zotero item is metadata-bare (DOI field only, no
  Crossref-enriched title/author/journal/date). This beats the pre-fix outcome of no item at all
  and is documented explicitly in `zotero-item-creation.md`.
- **Defect (c) is message-text only, as required.** No automatic retry, tier selection, or
  classifier was added anywhere — `pipeline_failed_diagnostic_hint()` only enriches stderr text
  with a manual Class A / Class B diagnostic procedure; stdout, exit codes, and directive tokens
  are unchanged.
- **`DOWNLOAD_FAILED(2)` untouched**, per the research's finding that it already self-cleans on
  both `download_and_verify()` failure branches.

## Plan Deviations

- **Phase 1**: stub count widened from the hypothesized 2 (`zot`, `literature-convert.sh`) to 6
  (`zot`, `curl`, `literature-convert.sh`, `literature-chunk.sh`, `zotero-resolve-pdf.sh`,
  `zotero-read.sh`) — see Decisions.
- **Phase 4**: the "preserved rejected-markdown path" enrichment task was altered to be honest
  about non-preservation through this delegation path — see Decisions.
- **Phase 5**: branch count altered from the plan's asserted 4 to 5 (a concurrent unrelated task
  added a fifth); additionally required a one-line fix to an unrelated pre-existing `set -e`/
  `pipefail` bug to make one of the four originally-planned branches reachable at all — see
  Decisions. Both are recorded in the plan file's Phase 5 Correction note and in
  `progress/phase-5-progress.json`'s `deviations` array.

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `bash -n` clean on both modified scripts; 10/10 harness scenarios passed
  (arxiv-only-fixed, doi-present-unaffected, staging-cleanup-create, staging-cleanup-attach,
  quality-gate-orphan, hard-fail-orphan, no-md-orphan, chunk-fail-orphan, pipeline-failed-message,
  success-control)
- Files verified: Yes

### Before/after evidence

**Defect (a)** — arXiv-only record, forced through a stub `zot`:
- Before: `zot add --pdf <staging.pdf>` (no `--doi`) → stderr `No DOI found in PDF`, script stops
  at `ONLINE_INGEST_ZOTERO_CREATE_FAILED` (exit 3).
- After: `zot add --pdf <staging.pdf> --doi 10.48550/arXiv.1009.2803` → succeeds, script proceeds
  to `ONLINE_INGEST_INGESTED` (exit 0). `doi_present.json`'s real DOI path unaffected (no
  synthesized-DOI log line appears). Corpus `index.json`'s `.doi` field for the arXiv-only record
  confirmed still `null` (no leak).

**Defect (b), part 1** — staging PDF leak, forced item-add/attach failure:
- Before: `.online-ingest-staging/<doc_id>.pdf` remains on disk after `ONLINE_INGEST_ZOTERO_CREATE_FAILED`.
- After: directory contains only `.`/`..` after the same forced failure, on both the create-item
  and existing-item/attach paths. The shared `.online-ingest-staging/` directory itself is left
  in place.

**Defect (b), part 2** — orphaned `sources/<doc_id>/`, forced conversion/chunking failures:
- Before: an empty, unindexed `sources/<doc_id>/` directory remains after a quality-gate
  rejection, hard conversion failure, "no `.md` produced," or chunking failure.
- After: no `sources/<doc_id>/` directory remains in any of the four (now five, including the
  concurrently-added OCR-needed branch) forced-failure scenarios. Positive control confirms a
  successful ingest still produces a populated `sources/<doc_id>/` with `chunks.json` (cleanup
  does not fire on the success path).

**Defect (c)** — `ONLINE_INGEST_PIPELINE_FAILED` enrichment, forced quality-gate rejection through
the full bridge:
- Before: stderr rationale was a single line: `literature-ingest.sh delegate failed for
  doc_id=... (source: ...)`.
- After: same stdout contract (exactly `ONLINE_INGEST_PIPELINE_FAILED`, exit 6) plus a
  multi-line stderr block naming the manual re-run command, the exact guide-section name
  ("Converter Tier Selection", verified spelled identically via `grep -c` against
  `context/guides/literature-organization.md`), and both Class A / Class B remedies, explicitly
  framed as manual-only.

## Impacts

- arXiv-only `open_access` discovery records can now be ingested via the online bridge instead of
  hard-failing at item creation.
- No more orphaned staging PDFs or empty `sources/<doc_id>/` directories accumulate from bridge
  failures.
- Quality-gate rejections during bridge-delegated ingestion now give the operator an actionable
  manual next step instead of a bare failure line.
- The unrelated `set -e`/`pipefail` fix in `literature-ingest.sh` also benefits any other caller
  of the script that hits a "conversion succeeded but produced no markdown" case — previously a
  confusing, unexplained crash; now a clean, logged per-file failure.
- `zotero-item-creation.md` no longer understates a real hard-failure mode.

## Follow-ups

- None required by this task's scope. Not fixed (explicit non-goal): the separate success-path
  orphan possibility already covered by Phase 5's optional `rmdir` sub-step is bounded to a safe,
  non-destructive cleanup and does not need further work.
- Worth noting for a future task (not acted on here): the OCR-needed bucketing feature landed by a
  concurrent, independently-committed task in `literature-ingest.sh` while this task was in
  flight — its new `continue` branch received the same orphan-directory cleanup as the other four
  branches, but that concurrent task's own author should confirm this integration reads correctly
  against their intent.

## References

- `specs/109_fix_ingest_online_failure_modes/plans/01_ingest-online-failure-modes.md`
- `specs/109_fix_ingest_online_failure_modes/harness/README.md`
- `specs/109_fix_ingest_online_failure_modes/progress/phase-{1..6}-progress.json`
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
- `agent-system/extensions/literature/context/guides/literature-organization.md` ("Converter Tier
  Selection" section)
