# Implementation Summary: Task #832

**Completed**: 2026-07-10
**Duration**: ~1.5 hours (wall clock; OCR jobs ran in parallel to compress runtime)

## Overview

Executed all 9 phases of the reconvert-and-validate plan against the live
`~/Projects/Literature` corpus. 9 of the 13 actionable directories were fully promoted to
`verified_conversion` (or resolved via truthful disclosure); 1 was explicitly deferred by design
(Decision B); 2 hit genuine, honestly-reported converter quality-gate failures after exhausting
the allowed retry; and 1 (`gabbay_1994`) surfaced a new, previously-unknown partial-conversion
discovery as a side effect of establishing its OCR baseline. The final verification contract
(Phase 9) passed on every explicit assertion. Overall task status is **partial**, not complete,
because named cohort members remain genuinely incomplete — reported honestly per the "partial
completion is acceptable, false completion is not" directive.

## What Changed

**Directory-level population** (`literature-fidelity-audit.sh --dry-run`, 97 total dirs):

| Class | Before | After |
|---|---|---|
| verified_conversion | 39 | 48 |
| unverified_summary | 1 | 0 |
| no_source_pdf | 45 | 45 (unchanged) |
| not_yet_converted | 5 | 3 |
| unverified_no_baseline | 4 | 0 |
| unadjudicated | 3 | 1 |

**Per-directory changes** (exactly 9 dirs changed; all other 88 byte-identical before/after,
confirmed via full diff):

- `~/Projects/Literature/sources/girard_1989/proofs_and_types.md` — new conversion (net-new .md
  written directly into `sources/girard_1989/`, since `literature-convert.sh`/`ingest.sh` alone
  writes elsewhere — see Deviations). 51,572 words. `not_yet_converted` -> `verified_conversion`
  (0.855). Auto tier hit exit 3 (sentence-boundary-glue); `LITERATURE_CONVERTER=pymupdf` retry
  succeeded.
- `~/Projects/Literature/sources/van_doorn_2015/van_doorn_2015_propositional_calculus_coq.md` —
  new conversion, 4,946 words, auto tier succeeded first try. `not_yet_converted` ->
  `verified_conversion` (0.9765).
- `~/Projects/Literature/sources/fine_2012_guide-to-ground/fine_2012_guide-to-ground.md` —
  reconverted from PDF (backed up to `.md.bak-20260709T235817Z`, 333 words). New: 20,008 words.
  `unadjudicated` (0.0161) -> `verified_conversion` (0.9665).
- `~/Projects/Literature/sources/fine_2012_counterfactuals-without-possible-worlds/fine_2012_counterfactuals-without-possible-worlds.md`
  — reconverted (backup 1,457 words). New: 11,637 words. `unadjudicated` (0.1209) ->
  `verified_conversion` (0.9652).
- `~/Projects/Literature/sources/rabinovich_2014/Rabinovich_2014_Proof_of_Kamps_Theorem.md` —
  reconverted (backup 2,093 words). New: 6,986 words. `unverified_summary` (0.2381) ->
  `verified_conversion` (0.7949).
- `~/Projects/Literature/index.json` — 9 `venema_1991` entries received an additive, truthful
  disclosure banner in their `summary` field ("Selective conversion: only Chapter 2 and Appendices
  A/B (approx. 59 of the book's 184 pages)..."). `venema_1991`: `unadjudicated` (0.3737,
  disclosed=False) -> `verified_conversion` (0.3737, disclosed=True) — ratio deliberately
  unchanged, per Decision A.
- `~/Projects/Literature/sources/burgess_1984/Burgess_1984_Basic_Tense_Logic.pdf` — replaced
  in-place with an OCR'd (searchable) version (backup preserved). `.md` untouched.
  `unverified_no_baseline` -> `verified_conversion` (1.0041).
- `~/Projects/Literature/sources/thomason_1984/Thomason_1984_Combinations_of_Tense_and_Modality.pdf`
  — same treatment. `unverified_no_baseline` -> `verified_conversion` (1.0049).
- `~/Projects/Literature/sources/vardi_wolper_1986/` — PDF OCR'd and replaced in-place; stub `.md`
  (151 words, self-disclosing placeholder) backed up and replaced with a real first-time
  conversion (7,474 words, via `LITERATURE_CONVERTER=pymupdf` after an auto-tier exit-3). 
  `unverified_no_baseline` -> `verified_conversion` (1.0044).
- `~/Projects/Literature/sources/gabbay_1994/` — all 4 PDFs (3 chapter splits + the full 668pp
  book) OCR'd and replaced in-place (backups preserved). `unverified_no_baseline` ->
  `unadjudicated` (0.11) — see "New Discovery" below; NOT promoted to `verified_conversion`.
- `~/Projects/Literature/sources/gabbay_2000/Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf`
  — full 614-page OCR completed (backup preserved), 252,253 words now extractable (was 0). `.md`
  conversion attempted twice, both exit 3 — remains `not_yet_converted`. See "Incomplete Members"
  below.
- `~/Projects/Literature/.literature.db` — rebuilt (Phase 8), 83 manifests, 4,002 chunks indexed.
- `~/Projects/Literature/index.json` — re-stamped via `--write` (155 entries stamped: 27 changed,
  128 unchanged on the corrective second pass); self-backed-up to
  `index.json.bak.20260710-002927`. Confirmed idempotent (byte-identical md5 on a third run).

## Decisions

- **Decision A (venema_1991)**: resolved via truthful disclosure banner, not reconversion, exactly
  as the plan specified. `disclosure_check()` now returns True; ratio intentionally unchanged.
- **Decision B (negri_von_plato_2001)**: made NO write. Its only PDF is a confirmed 4-page
  table-of-contents-only scan — converting it would stamp a ~500-word TOC stub as though it were
  the book. Recommend a `/spawn` follow-up task to source a real full-text PDF; not auto-spawned.
- **Decision C (gabbay_2000)**: executed the full 614-page OCR (not sampled), which succeeded
  completely. The subsequent markdown-conversion attempt failed the quality gate twice (exit 3
  both times, OCR-noise-driven sentence-boundary-glue, e.g. "Compuitationall"), so per the
  exit-code contract this was honestly reported incomplete rather than forced through.

## Plan Deviations

- **Task 2.1** (altered): `literature-ingest.sh`/`literature-convert.sh <pdf> <tmpdir>` write
  output to `$LITERATURE_DIR/<doc_id>/`, not `sources/<dir>/` — but
  `literature-fidelity-audit.sh`'s `classify_dir()` only reads non-`chunk_NNNN.md`-named `.md`
  files found *directly* in `sources/<dir>/`. Used `literature-convert.sh <pdf> sources/<dir>/`
  directly (matching the established convention already used by every prior converted dir, e.g.
  `doets_1987`/`burgess_1984`) so the directory-level audit would pick up the conversion, then
  additionally ran `literature-ingest.sh` for the 2 successful conversions to also create
  index.json entries + chunks for search.
- **Task 3.2** (altered): `literature-convert.sh` derives its output filename from the PDF's own
  basename, not the pre-existing `.md`'s filename, so reconversions initially landed as
  differently-named sibling files. `mv`'d each new file onto the canonical `.md` filename
  (backup already taken first — no `rm`, prior content fully preserved).
- **Task 6.2 / Phase 7** (altered): ran gabbay_1994's 668-page full-book OCR and gabbay_2000's
  614-page OCR as parallel background jobs (rather than strictly sequential per the wave
  dependency) to compress wall-clock time; both completed fully without needing to sample or
  defer.
- **Task 9.3** (altered): the first `--write` pass reported 4 dirs with "no matching index entry",
  including `girard_1989`/`van_doorn_2015` — traced to `literature-ingest.sh` creating index
  entries in a *different* schema (`doc_id`/`source_path`, no `id`/`path` fields) than
  `resolve_targets()` requires (`id` + `path` prefixed `sources/<dir>/...`). Fixed by adding
  `id`/`path` fields to those 2 entries (additive, matching every other entry's existing schema),
  then re-ran `--write`, which correctly stamped both. `literature-fidelity-audit.sh` itself was
  never modified — only index.json's *data* was corrected, consistent with the script being out
  of file_scope (owned by #839).
- **New discovery, not a plan deviation but worth flagging**: `gabbay_1994`'s OCR baseline
  (Phase 6's literal goal) succeeded, but the resulting computable ratio (0.11, 27,421 md_words
  vs 249,327 pdf_words) reveals its existing `.md` is itself only a partial conversion of the
  668-page book — landing it in `unadjudicated` rather than `verified_conversion`. This is a
  **new** unadjudicated case outside the plan's 3 named ones (the 2 Fine papers + venema_1991,
  already resolved above). It was NOT remediated in this task (reconverting/expanding
  `gabbay_1994`'s `.md` was out of Phase 6's baseline-only scope) and should be considered for a
  follow-up task.

## Incomplete / Deferred Members (honest accounting)

| Dir | Status | Reason |
|---|---|---|
| `troelstra_schwichtenberg_2000` | Incomplete | Converter exit 3 twice (auto: 69 sentence-boundary-glue transitions; pymupdf retry: 89 transitions) on a genuinely two-column-laid-out PDF. Both attempts exhausted per contract; remains `not_yet_converted`. |
| `negri_von_plato_2001` | Deferred by design | Decision B — only PDF is a 4-page TOC-only scan, wrong asset. No write made. Recommend `/spawn` for real-source acquisition. |
| `gabbay_2000` | Partially complete | OCR baseline FULLY achieved (614/614 pages, 252,253 words, was 0). Markdown conversion attempted twice, both exit 3. Remains `not_yet_converted` at directory level despite the OCR groundwork being real and reusable. |
| `gabbay_1994` | New discovery, not remediated | OCR baseline goal achieved (0.11 computable ratio, was `unverified_no_baseline`) but reveals the existing `.md` covers only a fraction of the real 668-page book. Lands in `unadjudicated`, outside this task's named decisions. Flagged for follow-up. |

## Verification

- **Build**: N/A (no code build; script-driven corpus operations)
- **Tests**: N/A (no automated test suite for this corpus; verification is the fidelity-audit
  contract below)
- **Files verified**: Yes — every `.md`/`.pdf` overwrite backed up first (`.bak-<UTC>` siblings
  confirmed present and word-count-matched against pre-change baseline); `index.json` self-backed
  up by `--write`; `.literature.db` rebuilt and atomic.
- **Verification contract** (Phase 9, run against the live corpus, not asserted blind):
  - 2 `fine_2012_*` dirs promoted out of `unadjudicated`: **PASS** (0.0161->0.9665, 0.1209->0.9652)
  - `venema_1991` resolved via `disclosed==True`, NOT a ratio rise: **PASS** (ratio unchanged 0.3737)
  - `rabinovich_2014` promoted out of `unverified_summary`: **PASS** (0.2381->0.7949)
  - OCR cohort attempted members have computable `word_ratio`: **PASS** (0 remain
    `unverified_no_baseline`; burgess_1984/thomason_1984/vardi_wolper_1986 all `verified_conversion`
    ~1.0; gabbay_1994 computable at 0.11 but `unadjudicated`, see New Discovery)
  - `doets_1987`, `libkin_2004_ch3_ch7`, `thomas_2003_reactive` UNCHANGED: **PASS** (byte-identical
    diff)
  - No dir silently regressed class: **PASS** (full 97-dir diff shows exactly the 9 intended
    changes, nothing else)
  - `--write` idempotent: **PASS** (md5sum identical across a 3rd consecutive run; changed:0,
    unchanged:155)

## Notes

- This task writes to real, irreplaceable data outside the repo
  (`~/Projects/Literature/sources/`). Every overwritten `.md`/`.pdf` has a `.bak-<UTC>` sibling;
  nothing was `rm`'d. Full list of backups is recoverable via `find ~/Projects/Literature/sources
  -name "*.bak-*"`.
- Two `.rejected` diagnostic siblings remain on disk (examined, not deleted):
  `sources/troelstra_schwichtenberg_2000/proof_theory_lectures.md.rejected` and
  `sources/gabbay_2000/gabbay_reynolds_2000_temporal_logic_foundations_vol2.md.rejected`.
- `literature-fidelity-audit.sh` was never modified, consistent with it being owned by #839 and
  out of this task's file_scope.
- Recommended follow-ups (not performed here, left to the user/orchestrator):
  - `/spawn` a task to source a real full-text PDF for `negri_von_plato_2001`.
  - Consider a follow-up task to investigate/reconvert `gabbay_1994`'s partial `.md` now that its
    full 668-page OCR baseline exists (249,327 extractable words vs the current 27,421 md_words).
  - Consider a follow-up attempt at `gabbay_2000`'s markdown conversion using a different engine
    or manual OCR-noise cleanup, now that its OCR text layer is real and complete.
  - Consider a follow-up attempt at `troelstra_schwichtenberg_2000` using a different engine
    (both `pymupdf4llm` and the forced `pymupdf` fallback hit the same sentence-boundary-glue
    defect class on this two-column PDF).
