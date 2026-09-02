# Implementation Summary: Task #105

- **Task**: 105 - Add an OCR tier for image-only and poor-vintage-OCR PDFs
- **Status**: [COMPLETED]
- **Started**: 2026-09-01
- **Completed**: 2026-09-02
- **Effort**: ~6 hours
- **Dependencies**: Task 102 (converter-tier characterization; COMPLETED)
- **Artifacts**: plans/01_add-ocr-tier-image-only-pdfs.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented all 5 phases of the plan against `agent-system/extensions/literature/`. Both
text-layer failure paths in `literature-convert.sh` now print a distinctive, actionable marker
and remedy command; `literature-ingest.sh` has a dedicated "needs OCR" summary bucket;
`LITERATURE_CONVERTER=ocr` exists as an explicit, never-auto-invoked mode built on `ocrmypdf`;
the messaging/bucketing/never-auto-invoked guarantees are locked in by regression tests; and the
new mode plus its dependency posture are documented. A pre-existing gap discovered mid-phase (the
mandatory fallback tier was silently "succeeding" on genuinely image-only PDFs with a useless
`[figure omitted]`-only output, never reaching the exit-2 path at all) was fixed as part of this
same work, since it directly blocked the task's real-world effect.

## What Changed

- `agent-system/extensions/literature/scripts/literature-convert.sh` — shared `ocr_remedy_command()`
  remedy-hint emitter (Phase 1, updated in Phase 3 to name `LITERATURE_CONVERTER=ocr`); distinctive
  `NO TEXT LAYER:` exit-2 marker; exit-3 remedy line naming the Class A/B split; updated header
  Exit codes / Environment / engine-tier-ladder comments; new `ocr` case arm and `try_ocr_explicit()`
  (guards on `command -v ocrmypdf`, defaults to `--skip-text`, opts into `--force-ocr` only via
  `LITERATURE_OCR_FORCE=1`, feeds the OCR'd temp PDF through `run_unified_engine(..., "fallback_only")`);
  new `ocr_explicit` main-dispatch branch handling 0/3/other explicitly; and a new
  `_is_placeholder_only()` check closing the fallback-tier placeholder gap (see Decisions).
- `agent-system/extensions/literature/scripts/literature-ingest.sh` — `OCR_NEEDED` counter/array,
  a marker-discriminated (`NO TEXT LAYER:`, colon required) dispatch branch before the generic
  hard-failure branch, a "Files needing OCR" summary block, and an updated all-failed aggregate
  message.
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` — `build_image_only_pdf()`
  fixture (render-to-pixmap-then-insert-as-image; asserts zero extractable text on itself) and its
  `image-only` CLI arm.
- `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` — 12 new assertions:
  `auto` exits 2 with the marker/remedy (primary tier forced unavailable via an unwritable
  `LITERATURE_PYENV_DIR` parent, for a deterministic result); `auto` never invokes `ocrmypdf`
  (PATH-shadowing stub); `LITERATURE_CONVERTER=ocr` with `ocrmypdf` absent (unconditional, masked
  PATH, no traceback); the real OCR round-trip (skips with a warning if `ocrmypdf` is absent);
  the exit-3 `QUALITY GATE FAILED` prefix + remedy line; and `literature-ingest.sh`'s needs-OCR
  vs. marker-free-hard-failure bucketing.
- `agent-system/extensions/literature/context/guides/literature-organization.md` — new "Class C:
  no text layer (absence)" treatment, updated Class B remedy cell, and an extended no-auto-selection
  paragraph covering the OCR mode.
- `agent-system/extensions/literature/context/project/literature/domain/extension-dependencies.md` —
  new "Optional External Binaries (Gracefully Detected, Never Provisioned)" section covering
  `pdftotext`/DJVU tools/`ocrmypdf`+`tesseract`, contrasted with the primary tier's pinned venv.
- `agent-system/extensions/literature/index-entries.json` — `line_count` refresh (verified against
  `wc -l`) and keyword/topic additions for both edited context files.
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` — diagnostic-hint
  heredoc updated to name the new in-pipeline OCR commands, found via Phase 5's mandated re-grep.

## Decisions

- Both Phase 1 failure-path messages route through one shared Python function
  (`ocr_remedy_command()`), so Phase 3 updated exactly one function body to switch from the manual
  `ocrmypdf` command to `LITERATURE_CONVERTER=ocr`/`LITERATURE_OCR_FORCE=1`, per the plan's stated
  mitigation for that risk.
- The `NO TEXT LAYER:` marker requires a trailing colon. Without it, the marker string
  false-matched the Phase 1 bash-level generic "All converters failed" line's own prose mention of
  the bare phrase, mis-bucketing the primary-tier-unavailable exit-2 case as needs-OCR in
  `literature-ingest.sh`. Caught and fixed during Phase 2 verification.
- **Fixed a pre-existing gap, not originally itemized in any phase's task list**: the mandatory
  fallback tier's `extract_blocks_mode()`/`extract_dict_mode()` emit a literal `[figure omitted]`
  placeholder for every image XObject block. A genuinely image-only PDF built the realistic way
  (an embedded scan image, not a vector-only drawing) therefore produced non-empty content and
  passed straight through the old `not content.strip()` check and the quality gate (page-coverage
  is bypassed when the source itself has 0 extractable words) — silently succeeding with a
  useless one-line `.md` instead of ever reaching the exit-2 `NO TEXT LAYER` path. This defeated
  Phases 1-3's purpose for the realistic case of an operator without a provisioned pymupdf4llm
  venv (the majority case, since the venv requires `uv` + network access to auto-provision).
  Added `_is_placeholder_only()` to `literature-convert.sh` to close it; verified via the full
  suite plus two targeted revert-and-confirm-failure checks (see phase-4-progress.json).
- `LITERATURE_CONVERTER=ocr`'s default runs `ocrmypdf --skip-text` explicitly rather than relying
  on ocrmypdf's own bare default, because `ocrmypdf --help` on the installed version (17.4.2)
  documents `default` mode as *erroring* if any text is found, not silently skipping — confirmed
  live before writing `try_ocr_explicit()`.
- The OCR'd temp PDF is fed through `run_unified_engine(..., "fallback_only")`, deliberately
  bypassing the primary tier (no venv dependency for the OCR path, and the fallback tier's plain
  `get_text()` reads `ocrmypdf`'s embedded invisible text layer directly).

## Plan Deviations

- **Task 4 (additional)**: extended Phase 1's exit-2 empty-output check with `_is_placeholder_only()`
  — not itemized in Phase 4's task list, but discovered while building/verifying Phase 4's fixture
  and directly required for Phases 1-3 to have any real-world effect via the fallback tier. See
  phase-4-progress.json's `deviations`/`findings` for the full account.
- **Task 5.6**: extended the mandated re-grep's edit set to `literature-ingest-online.sh` (not one
  of Phase 5's named "Files to modify") because it duplicates the same manual Class A/B remedy
  prose the guide already updates; left it consistent rather than stale.
- No other deviations — all five phases followed the plan as written.

## Verification

- Build: N/A (bash/Python scripts)
- Tests: Passed — `bash -n` clean on both scripts; `--self-test` passes; `test-literature-convert.sh`
  24/24 passing (12 pre-existing + 12 new); `test-quality-gate-notation.sh` and
  `test-literature-build-index.sh` unregressed; two targeted revert-and-confirm-failure checks
  confirmed the new tests actually bind to Phase 1's marker and Phase 2's bucket branch.
- Files verified: Yes — `jq empty index-entries.json` passes; both edited entries' `line_count`
  matches `wc -l`; `check-task-references.sh` reports 0 occurrences.

## Impacts

- An operator hitting either failure (no text layer, or a gate rejection) now sees the exact
  remedy command in stderr at the point of failure, without needing to consult a guide.
- `literature-ingest.sh` directory ingests now separate needs-OCR documents from hard failures in
  their own summary bucket and counter.
- A new, deliberately explicit-only `LITERATURE_CONVERTER=ocr` mode exists for operators to
  convert scanned/image-only or poor-vintage-OCR PDFs; it is structurally unreachable from `auto`
  (a separate case arm, never referenced by the `auto`/fallback chain).
- Fixing the fallback-tier placeholder gap means genuinely image-only PDFs converted via the
  common no-venv path now correctly surface as a hard, actionable failure instead of silently
  producing a near-empty, useless `.md` that would previously have been ingested successfully.

## Follow-ups

- `pymupdf4llm`'s own `force_text=True` default (pre-existing, unrelated to this task's `ocrmypdf`
  CLI) can silently recover text via its own internal Tesseract call when the primary tier's venv
  and system `tesseract` are both present — a different code path from `LITERATURE_CONVERTER=ocr`,
  but worth knowing: an image-only PDF's outcome under bare `auto` can vary by machine
  provisioning state. Not fixed here (out of this task's scope — see Non-Goals); recorded in
  `generate-test-fixtures.py`'s `build_image_only_pdf()` docstring and phase-3/4 progress files
  for any future work that touches the primary tier's OCR behavior.
- `~/Projects/Literature/_staging_gametheory/`'s existing hand-run `ocr/`, `ocr2/`, `ocr3/`,
  `sweep_*/` folders (cited in the plan's research integration) were not touched — corpus
  remediation using the new `LITERATURE_CONVERTER=ocr` mode remains separate operator work, as
  the plan's Non-Goals state.
- `skills/skill-literature/SKILL.md`'s own embedded conversion loop mirrors
  `literature-ingest.sh`'s exit-3 `QUALITY GATE FAILED` consumption but was not extended with an
  equivalent needs-OCR branch (out of scope: the plan named only `literature-ingest.sh` for
  Phase 2, and the `QUALITY GATE FAILED` prefix SKILL.md greps for was preserved verbatim, so it
  remains compatible as-is; a marker-free exit 2 there still falls into its generic
  `convert_failed_entries` bucket rather than a dedicated needs-OCR bucket).

## References

- `specs/105_add_ocr_tier_for_image_only_pdfs/plans/01_add-ocr-tier-image-only-pdfs.md`
- `specs/105_add_ocr_tier_for_image_only_pdfs/reports/01_add-ocr-tier-image-only-pdfs.md`
- `specs/105_add_ocr_tier_for_image_only_pdfs/progress/phase-{1..5}-progress.json`
