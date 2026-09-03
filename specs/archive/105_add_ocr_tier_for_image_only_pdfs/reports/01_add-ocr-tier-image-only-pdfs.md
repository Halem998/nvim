# Research Report: Task #105

**Task**: 105 - Add an OCR tier for image-only and poor-vintage-OCR PDFs
**Started**: 2026-09-01T23:12:00Z
**Completed**: 2026-09-01T23:45:00Z
**Effort**: research
**Dependencies**: Task 102 (converter-tier characterization; COMPLETED)
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/literature-convert.sh` (full engine ladder, quality gate call site)
- `agent-system/extensions/literature/scripts/literature_quality_gate.py` (gate checks, `sentence_boundary_glue_count` docstring)
- `agent-system/extensions/literature/scripts/literature-pyenv-provision.sh` (graceful-detection/provisioning precedent)
- `agent-system/extensions/literature/scripts/literature-ingest.sh` (exit-code bucketing, operator-facing summary)
- `agent-system/extensions/literature/context/guides/literature-organization.md` ("Converter Tier Selection" section, added by Task 102)
- `agent-system/extensions/literature/context/project/literature/domain/extension-dependencies.md`
- `specs/102_characterize_converter_tiers_and_ocr_vintage/reports/01_converter-tier-characterization.md` and its `summaries/01_...md`
- `specs/vault/01-vault/archive/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`
- Live corpus inspection: `~/Projects/Literature/sources/gabbay_2000/` (a real, currently gate-rejected document), `~/Projects/Literature/_staging_gametheory/` (an operator-built manual OCR workflow)
- System check: `ocrmypdf --version`, `tesseract --version`, `command -v`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The gap is confirmed exactly as described**: `literature-convert.sh` has three tiers
  (pymupdf4llm primary, mandatory PyMuPDF column-clustering fallback, manual-only `pdftotext`)
  and none can recover text from a PDF with no text layer. When both auto-mode tiers produce
  empty output, the script exits 2 with a generic `"All engine tiers produced empty output"`
  message; `literature-ingest.sh` buckets this into its plain **"Files failed"** counter — the
  same bucket as a missing input file or a crashed interpreter — with no mention of OCR at all.
- **`ocrmypdf` and `tesseract` are already installed system-wide** (`ocrmypdf 17.4.2`,
  `tesseract 5.5.2`, both resolving to `/run/current-system/sw/bin/` via the machine's NixOS
  system profile) — a CLI tool with **no venv/provisioning complexity**, unlike the primary
  tier's pinned `uv` venv (which exists specifically to work around a compiled-wheel/nix-ld
  problem that does not apply to a plain CLI binary). This is a materially different, much
  cheaper dependency shape than the precedent in `literature-pyenv-provision.sh`, but it is still
  an **external, ungoverned dependency** this repo does not provision or guarantee — it must be
  treated with the same graceful-detection posture already used for `uv`/`nix-build`, never
  assumed present.
- **Both problem classes named in the task have live, present-day corpus evidence — this is not
  a hypothetical:**
  - **Class B (poor-vintage OCR, not absence)**: `~/Projects/Literature/sources/gabbay_2000/`
    contains a real, currently-un-ingested `.rejected` sibling (`gabbay_reynolds_2000_temporal_
    logic_foundations_vol2.md.rejected`, 614-page scanned book, 252,819 words). Re-running the
    actual gate checks against it in this session shows it fails **solely** on
    `sentence_boundary_glue_count() == 10` (threshold 3) — coverage is 100.1%, ligature/dehyphenation/
    control-char/printable-ratio all clean. Sampling the extracted text shows classic archaic-OCR
    corruption (`"Nemporal Loge"` for "Temporal Logic", garbled title-page glyphs) sitting on
    otherwise-readable body prose — the exact Class-B signature Task 102 documented for
    `joyce_1999`, at a larger scale (10 hits vs. 4).
  - **Absence class + repeated manual toil**: `~/Projects/Literature/_staging_gametheory/`
    contains operator-built staging folders literally named `ocr/`, `ocr2/`, `ocr3/`,
    `sweep_default/`, `sweep_fallback/`, `sweep_lastresort/`, `retry/` — the same PDFs
    (`vonneumann_morgenstern_1944_theory-of-games.pdf`, `bonanno_2017/2024`, `herzig_lorini_2010`,
    `vanbenthem_pacuit_2014`) recur across `sweep_default` -> `sweep_fallback` ->
    `sweep_lastresort`, and one (`vonneumann_morgenstern_1944`, a 143MB scan) lands in `ocr3`. This
    is direct evidence of a real, already-existing, entirely manual per-document tier-escalation
    workflow an operator built by hand — precisely what this task should fold into the pipeline
    rather than leave ad hoc.
- **Recommendation**: a two-part fix, both scoped to `agent-system/extensions/literature/`
  (never `.claude/`):
  1. **Mandatory, cheap, safe**: turn today's opaque failures into actionable ones by naming the
     exact remedy command at the point of CLI failure, for both failure shapes (exit-2 empty
     output and exit-3 gate rejection), rather than requiring the operator to already know to
     consult the guide.
  2. **Recommended, bounded-scope**: add an explicit, operator-invoked `LITERATURE_CONVERTER=ocr`
     mode that shells out to `ocrmypdf` (skip-text default) into a temp file and feeds the result
     through the *existing* fallback tier + normalization + quality gate unchanged — formalizing
     the `_staging_gametheory/ocr*` workflow into one command, gracefully degrading (clear log,
     non-fatal) if `ocrmypdf` is absent, and **never** entering `auto`'s silent chain.
  Do **not** add OCR as a silent, automatic 4th `auto`-mode tier, and do not make `--force-ocr`
  (the Class-B remedy) a default anywhere — both are actively harmful on documents that don't
  need them, and the corpus evidence above (a 614-page and a 143MB scan) confirms these are
  expensive, document-scale operations an operator should consciously invoke, exactly the
  "no silent fallthrough" principle already stated in the script's own header comment.

## Context & Scope

Task 105 depends on Task 102 (COMPLETED), which established the Class A (primary-tier
structuring artifact, fixed by `LITERATURE_CONVERTER=fallback`) / Class B (text-layer defect,
needs re-OCR, a tier switch does nothing) framing and documented it in
`context/guides/literature-organization.md`'s new "Converter Tier Selection" section. That prior
work explicitly left two things undone, which are exactly this task's scope: (1) the
"absence of any text layer at all" case is a *third*, distinct failure mode Task 102 never
addressed (its docstring/guide table covers only post-conversion glue-defect classification, not
the pre-gate "all engine tiers produced empty output" exit-2 path); (2) even for the already-
documented Class B case, the remedy (`ocrmypdf --force-ocr`) lives only in a guide an operator has
to already know to open — it is not surfaced at the point of CLI failure at all.

This research does not re-litigate Task 102's Class A/B mechanism or its explicit "no
auto-selection" prohibition (Class A vs. B discrimination is diagnostic/inspection-based, not a
cheap a-priori predicate — that finding stands and is not challenged here). It focuses narrowly on
the gap this task names: the complete absence of any OCR path, and the disconnect between a
gate failure and an actionable remedy.

## Findings

### Codebase Patterns

**The exact three-tier ladder and where OCR would need to slot in**
(`literature-convert.sh:876-889`, `run_unified_engine()`'s `MAIN` section):

```python
content = None
engine_used = None
if mode != "fallback_only":
    content = try_pymupdf4llm()
    ...
if content is None:
    content, engine_used = try_pymupdf_fallback()
if not content or not content.strip():
    print("[convert] All engine tiers produced empty output", file=sys.stderr)
    sys.exit(2)
```

For a genuinely image-only PDF, `page.get_text()` (used by both `pymupdf4llm.to_markdown()` and
the fallback's `page.get_text("blocks")`) returns nothing on every page, so `content` is empty
through both tiers and the script exits 2 **before `run_quality_gate()` is ever called** — the
`fitz.Document` used by the gate (`gate_doc = fitz.open(pdf_path)` at line ~882) is opened only
after this empty-output check passes. This means a *fully* image-only PDF never technically fails
"the quality gate" in the exit-3 sense; it fails earlier, at exit 2, with a message that says
nothing about OCR. A *partially* scanned PDF (nonzero but sparse text) can still reach the gate
and fail its `page-coverage < 40%` check (exit 3) with an equally unhelpful message.

**How this surfaces to an operator today** (`literature-ingest.sh:219-243`): exit 3 (quality-gate
rejection) is already given its own distinct counter/list (`GATE_FAILED_ENTRIES`, printed in a
`"quality-gate-rejected files"` block in the final summary — this is the precedent pattern this
task's exit-2 improvement should mirror). Exit 2 and every other nonzero code fall into the
generic `elif [ "$CONVERT_EXIT" -ne 0 ]` branch, which prints `"ERROR: Conversion failed for
$BASENAME (exit $CONVERT_EXIT)"` plus the raw stderr, and increments the same `FAILED` counter as
a missing-input or crashed-interpreter error. There is currently no code path, anywhere in the
pipeline, that ever prints the word "OCR" or "ocrmypdf" to an operator.

**Existing graceful-degradation precedent to follow** (`literature-pyenv-provision.sh:12-28`):
the established contract for an optional external tool is "graceful detection only... functions
report unavailability cleanly (return non-zero, print nothing to stdout) so callers can fall back
... — never crash the caller," plus a self-repairing, idempotent provisioning path. `ocrmypdf`
being a plain CLI binary (not a compiled Python wheel) means an OCR tier needs only the
"detect absence and log + fall back" half of this contract (`command -v ocrmypdf`), not the venv/
`uv`/nix-ld-shim provisioning half — there is nothing to provision. This is a genuinely simpler
dependency shape than the primary tier's, which somewhat weakens the "provisioning cost" argument
against Option (i) that the task description raised as a factor to weigh.

**`pdftotext`'s existing "explicit escape hatch" pattern is the right template for an OCR
mode**, not the "mandatory tier" template: the header comment already establishes a precedent for
a tier that is real, useful, and yet deliberately excluded from `auto`'s silent chain —
`'pdftotext' (explicit, best-effort last resort: ... manual escape hatch only, not used by
'auto')`. An OCR tier should follow this exact shape (`LITERATURE_CONVERTER=ocr`, resolved
identically to how `pdftotext` is resolved into `ENGINE_MODE`), not the primary/fallback template
(which participates in `auto`'s automatic chain).

### Live Corpus Evidence (not hypothetical — both failure classes are present today)

**Class B, at scale — `gabbay_2000` (Gabbay & Reynolds, *Temporal Logic: Mathematical
Foundations and Computational Aspects, Vol. 2*, Oxford Logic Guides 40, 614 pages)**. This
document has sat as a `.md.rejected` sibling since at least 2026-07-09 with **no** `index.json`
entry (i.e., never successfully ingested). Re-running the actual `literature_quality_gate.py`
check functions against its on-disk `.rejected` content and source PDF in this session gives:

| Check | Result |
|---|---|
| `column_interleaving_flagged` | `False` (0.0%) |
| `sentence_boundary_glue_count` | **10** (threshold 3 — the sole failing check) |
| page-coverage | 252,458 src words / 252,819 out words = **100.1%** (well within band) |
| `ligature_residue_count` | 0 |
| `dehyphenation_residue_count` | 0 |
| `control_char_count` | 0 |
| `printable_ratio` | 1.0 (0 non-printable) |

Sampling the extracted text (page 0: `"Nemporal Loge"`, `"UXFORID LOTIC GUIDES"`, garbled title-
glyph runs; pages 50/200/400/600: largely readable prose/proofs with scattered word-level OCR
corruption) confirms this is a textbook Class B case — an old, low-quality baked-in OCR text
layer, not a structural artifact of the primary converter tier (the primary tier was never even
implicated: the `.rejected` content here is 252,819 words, i.e. it already reflects a real,
substantial conversion, not an empty/near-empty one). This is a larger, more clear-cut instance of
exactly the phenomenon Task 102 characterized once (`joyce_1999`, 4 hits) and is independent
confirmation that Class B is a recurring, not one-off, corpus condition.

**Absence class + confirmed manual operator workaround — `_staging_gametheory/`**. This directory
(outside any task's dependency chain, evidently operator-maintained ad hoc) contains subfolders
named `ocr/`, `ocr2/`, `ocr3/`, `sweep_default/`, `sweep_fallback/`, `sweep_lastresort/`, `retry/`,
`stit_retry/`, `stit_missing/`. The same PDFs recur across `sweep_default` -> `sweep_fallback` ->
`sweep_lastresort` (e.g. `bonanno_2017_decision-making.pdf`, `bonanno_2024_game-theory-open-
textbook.pdf`, `herzig_lorini_2010_dynamic-logic-agency-1-stit.pdf`,
`vanbenthem_pacuit_2014_connecting-logics-choice-change.pdf`), with filesystem mtimes showing
`sweep_default` populated first, `sweep_fallback` ~20 minutes later, `sweep_lastresort` ~5 minutes
after that — i.e., literally a manual re-run of `LITERATURE_CONVERTER=auto` then `=fallback` then
`=pdftotext` against the same failing documents, one env-var change at a time.
`vonneumann_morgenstern_1944_theory-of-games.pdf` (a 143MB scan) additionally appears in `ocr3/`,
naming it as a document that needed a third, OCR-specific remediation pass no existing tier could
provide. This is direct, concrete evidence that the exact workflow this task should formalize is
already being performed by hand, tier-by-tier, once per document, with no pipeline support.

### External Resources

`ocrmypdf` (17.4.2, installed) is a mature, actively maintained OCR-adding CLI wrapper around
Tesseract (5.5.2, installed) that specifically targets "add a text layer to a scanned PDF" as its
primary use case, with two directly relevant modes:
- **Default (`skip-text` implicit behavior)**: OCRs only pages that have no existing text layer,
  leaving pages that already have one untouched — the correct, non-destructive default for the
  *absence* case (a PDF with zero or partial text layers).
- **`--force-ocr`**: rasterizes every page and replaces any existing text layer unconditionally —
  the correct but destructive tool for the *poor-vintage* case (Class B), and never a safe
  default, since it will happily discard a perfectly good primary-tier-extractable text layer on
  documents that don't need it. Task 102's own `joyce_1999` remediation used this flag scoped to
  two specific pages (119, 217), not the whole document — reinforcing that this is a targeted,
  operator-directed tool, not a document-wide default even when it is the right remedy.

No further external research was needed beyond confirming installed-version behavior; this is
otherwise a codebase-internal/corpus-internal characterization task, consistent with Task 102's
research approach.

## Decisions

- Treated the task's own framing (absence vs. vintage are two distinct failure conditions needing
  two distinct responses) as correct and load-bearing, and sought — and found — independent,
  present-day corpus evidence for both rather than relying only on the task-supplied narrative.
- Did not attempt to re-open or re-litigate Task 102's Class A/B discrimination mechanism or its
  "no automatic tier selection" finding; that finding is about a different, harder problem
  (classifying an *already-produced* defect) than the "did any tier produce nonzero text at all"
  signal this task can act on, which is already computed today (`src_words` in
  `run_quality_gate`) but only used as a page-coverage-ceiling bypass (`if src_words else 1.0`),
  never surfaced as its own actionable signal.
- Verified the `ocrmypdf`/`tesseract` availability and version numbers directly on this machine
  rather than assuming from the task description, and noted explicitly that this presence is an
  OS-level (NixOS system profile) fact this repo does not control or provision — an implementer
  must treat it exactly as optional/gracefully-detected, never as a guaranteed dependency, no
  matter how convenient its presence is in this environment.
- Selected `gabbay_2000` and `_staging_gametheory` as evidentiary anchors because they were found
  through direct corpus inspection (not supplied in the delegation context), giving genuinely new,
  independent corroboration beyond the two lines of evidence the task description already named.

## Risks & Mitigations

- **Risk**: recommending an explicit `LITERATURE_CONVERTER=ocr` mode could be read as inviting a
  future "just make it the auto default" widening, defeating the safety rationale.
  **Mitigation**: the recommendation explicitly follows the `pdftotext` precedent (already-proven
  in this codebase to stay a manual-only escape hatch under `auto`'s silent-chain discipline for
  years) and should carry an equally explicit code comment/prohibition when implemented.
- **Risk**: `ocrmypdf`'s absence on a different operator's machine would make the new mode
  silently unavailable. **Mitigation**: this is precisely the existing `literature-pyenv-
  provision.sh` graceful-detection contract already established for `uv`; the new mode should
  `command -v ocrmypdf` up front and fail with a clear, actionable stderr message (mirroring the
  `LITERATURE_CONVERTER=pymupdf4llm`-but-venv-missing exit-2 message pattern at
  `literature-convert.sh` around the primary-tier-unavailable branch) rather than crash
  uninformatively.
- **Risk**: a full-book `ocrmypdf` run (614 pages for `gabbay_2000`, 143MB for
  `vonneumann_morgenstern_1944`) is slow — potentially many minutes — and doing this inside
  `literature-ingest.sh`'s directory-mode batch loop without operator awareness could silently
  balloon a batch ingest's wall-clock time. **Mitigation**: exactly why this must stay an explicit,
  single-document, operator-invoked mode (matching how the `pdftotext` escape hatch and the
  `_staging_gametheory` manual workflow are both already used one document at a time), not folded
  into `auto`'s batch-safe default path.
- **Risk**: the exit-2 "empty output" message improvement and the exit-3 gate-message improvement
  are two separate code changes in two different files (`literature-convert.sh`'s main flow for
  the former, `run_quality_gate()`'s reason strings or the `.rejected` stderr banner for the
  latter) — a planner could under-scope by doing only one. **Mitigation**: both are named as a
  single "mandatory" deliverable in the Executive Summary and Recommendations precisely so neither
  is dropped; they share one underlying goal (never leave an operator without a next action).

## Context Extension Recommendations

- **Topic**: OCR remedy discoverability at the point of failure.
- **Gap**: `context/guides/literature-organization.md`'s "Converter Tier Selection" section (added
  by Task 102) documents the Class B `ocrmypdf --force-ocr` remedy in prose, but nothing in the
  actual CLI output of `literature-convert.sh` or `literature-ingest.sh` ever points a live
  operator to that section, or mentions OCR/`ocrmypdf` at all — not even for the exit-2
  "no text layer" case the guide doesn't cover yet either.
- **Recommendation**: whichever plan implements this task should (a) add a `## No Text Layer
  (Class C / Absence)` subsection to the same guide, parallel to the existing Class A/B table,
  documenting the new `LITERATURE_CONVERTER=ocr` mode once it exists; and (b) have both the
  exit-2 and exit-3 CLI failure paths print a one-line pointer to that guide section, not just a
  bare diagnostic, closing the "documented but not discoverable at the failure site" gap this
  research identified.

## Appendix

- Search/inspection commands used: `grep -n` across `literature-convert.sh`,
  `literature_quality_gate.py`, `literature-ingest.sh`, `literature-pyenv-provision.sh` for tier
  logic, exit codes, and OCR/dependency mentions; `command -v ocrmypdf tesseract` + `--version`;
  a direct Python re-execution of `literature_quality_gate`'s check functions against
  `gabbay_2000`'s on-disk `.rejected` file and source PDF (no reconversion performed — the
  existing `.rejected` output and PDF were sufficient); `find`/`ls`/mtime inspection of
  `~/Projects/Literature/_staging_gametheory/` and `_staging_hoi/`.
- Key file references: `agent-system/extensions/literature/scripts/literature-convert.sh:15-45`
  (tier ladder doc comment), `:876-889` (empty-output exit-2 path), `:355-378`/header (`pdftotext`
  explicit-escape-hatch precedent); `literature_quality_gate.py:779-806` (`src_words`/coverage
  computation, the already-available zero-text-layer signal); `literature-pyenv-provision.sh:12-
  28` (graceful-detection contract to mirror for `ocrmypdf`); `literature-ingest.sh:219-243`
  (exit-3-gets-its-own-bucket precedent to mirror for a new exit-2 OCR-needed bucket);
  `context/guides/literature-organization.md`'s "Converter Tier Selection" section (Task 102's
  Class A/B table and diagnostic procedure, the anchor for this task's Class C addition).
- Live corpus paths inspected: `~/Projects/Literature/sources/gabbay_2000/
  gabbay_reynolds_2000_temporal_logic_foundations_vol2.md.rejected` and its source PDF;
  `~/Projects/Literature/_staging_gametheory/{ocr,ocr2,ocr3,sweep_default,sweep_fallback,
  sweep_lastresort,retry,stit_retry,stit_missing}/`.
