# Implementation Summary: Task #831

**Completed**: 2026-07-09
**Duration**: ~1 session (7 phases)

## Overview

Replaced the silently-corrupting conversion path in `.claude/scripts/literature-convert.sh`
(which fell back to `pdftotext -layout` for every corpus document because `marker`/`marker_single`
was never installed, gluing two-column academic text onto single lines) with an explicit, logged
engine tier system: `pymupdf4llm` (primary, via a pinned auto-provisioned `uv` venv) and a
zero-dependency PyMuPDF column-clustering algorithm (mandatory fallback). Fixed three downstream
correctness bugs (BUG 2: 3-page-per-TOC-section truncation; BUG 3: doubled breadcrumbs and
sentence-fragment headings; BUG 4: unresolved ligatures, hyphenation, soft-wrap) and added a
loud-failing quality gate (new exit code 3) so the pipeline can never again emit corrupt markdown
while reporting success. Wired the caller `literature-ingest.sh` to treat exit 3 distinctly from
hard failures. Built a test harness proving the fallback tier is actually exercised and that
column reading order is correct, and along the way, discovered and fixed a real calibration gap
and a real previously-undetected defect in the primary engine's own output.

## What Changed

- `.claude/scripts/literature-chunk.sh` — BUG 3 fix: `section_stack[:-1]` at both
  `build_section_path` call sites in `split_at_headings()`, eliminating doubled breadcrumbs
  (`Doc > Indeterminacy > Indeterminacy` → `Doc > Indeterminacy`).
- `.claude/scripts/literature-pyenv-provision.sh` — New. Idempotent `uv` venv provisioning for a
  pinned `pymupdf4llm==1.28.0`, with the `nix-ld` + `stdenv.cc.cc.lib` `LD_LIBRARY_PATH` shim
  (cached), graceful unavailability detection (never crashes the caller).
- `.claude/scripts/literature-convert.sh` — Rewritten engine tiers: `pymupdf4llm` primary
  (`try_pymupdf4llm()`), mandatory PyMuPDF column-clustering fallback (`order_blocks_by_column()`,
  `derive_toc_markdown()`, `derive_heuristic_markdown()`). Deleted `marker`/`marker_single`
  entirely (Non-Goals rejection). Deleted `pdftotext -layout` and PyMuPDF `sort=True` from every
  code path (kept a NEVER-`-layout` plain-pdftotext explicit override only, not in `auto`). Fixed
  BUG 2 (full `range(start_page, end_page)`, no 3-page cap). Fixed BUG 3's upstream cause
  (tightened no-TOC heading heuristic: bold + large-font + no terminal punctuation + short + not a
  sentence continuation; no candidate survives → no headings, not a low-confidence guess). Added
  BUG 4 normalization (`fold_ligatures()`, `dehyphenate()`, `rejoin_soft_wraps()`, applied
  per-block/per-paragraph in both tiers, math-safe — no blanket NFKC). Added the quality gate
  (`run_quality_gate()`, five detectors — see below) with exit code 3 and a loud-failure contract
  (`.rejected` sibling written, final `.md` never written on gate failure).
- `.claude/scripts/literature-ingest.sh` — Per-file exit code captured explicitly (was previously
  swallowed by a `| tail -1` pipe under `set -e`, which would have aborted the whole ingest run on
  any single file's non-zero exit). Exit 3 tracked in a distinct `GATE_FAILED` counter with a
  per-file reason list, separate from hard failures, surfaced in the final summary.
- `.claude/scripts/tests/test-literature-convert.sh` — New. Forced-fallback test, two-column
  regression fixture (strict against the fallback tier, loose "correct or loudly rejected" against
  auto mode), no-TOC heading regression, optional real-Alur-PDF stronger check via
  `LITERATURE_TEST_PDF` (skip-with-warning when absent).
- `.claude/scripts/tests/generate-test-fixtures.py` — New. Hermetic synthetic PDF generation
  (two-column layout, bold-heading-vs-fragment layout) via PyMuPDF, no network, no committed
  binary.
- `.gitignore` — Excludes the auto-provisioned venv (`.claude/scripts/literature-pyenv/`) and
  Python bytecode caches.

## Decisions

- **Removed `marker`/`marker_single` entirely** rather than demoting it to an explicit-only
  override, since research Non-Goals explicitly rejected its adoption and an untested/unverified
  code path is worse than no path.
- **Engine selection is unified in a single Python process** per conversion attempt: the script
  tries `import pymupdf4llm` at runtime and internally falls back if unavailable, rather than bash
  orchestrating separate attempts. This means the SAME normalization and quality-gate code runs
  regardless of which tier produced the content, and bash's job reduces to picking which Python
  interpreter (venv+shim vs system) to invoke.
- **Column-interleaving detector baseline changed from whole-document median to non-glued-lines
  median** (deviation from the literal research spec): verified the literal formula fails to flag
  the task's own motivating example (the real corrupted Alur SyGuS document) because when gluing
  affects the majority of a document, glued lines dominate and inflate the whole-document median
  itself.
- **Added a fifth quality-gate detector** (`sentence_boundary_glue_count`, period-only pattern)
  beyond the four named in Phase 5's plan, after discovering a genuine, previously-undetected
  `pymupdf4llm` defect on a real corpus document during Phase 6 test-harness construction (see
  Findings below).

## Plan Deviations

- **Task 3.5** (neutralize marker auto-preference) altered: removed `marker`/`marker_single`
  entirely rather than merely demoting it out of the auto chain.
- **Task 5.1** (column-interleaving detector formula) altered: baseline changed from
  whole-document median to non-glued-lines median; re-verified against the real Alur document and
  all of this task's own successful conversions (no false positives).
- **Task 6.6** (quality-gate scope) extended: added a fifth detector (`sentence_boundary_glue_count`)
  beyond Phase 5's four, discovered while building the Phase 6 test harness.
- **File scope note**: the delegation context listed `literature-convert.sh` and
  `literature-chunk.sh` as the file scope, but the plan (created with fuller research context)
  required `literature-ingest.sh` (Phase 5's caller wiring) and new test files under
  `.claude/scripts/tests/` (Phase 6) as well. Followed the plan's file list, since it reflects the
  fuller research/planning pass; no files outside the plan's own "Files to modify" lists were
  touched.

## Verification

- Build: N/A (bash + Python scripts)
- Tests: `.claude/scripts/tests/test-literature-convert.sh` — 8/8 passing
- Files verified: Yes — every phase verified against real corpus PDFs (Zielonka 1998, Goldblatt/
  Hodkinson/Venema 2003, Rabinovich 2014, and read-only string-level checks against known-bad
  content from the Alur SyGuS document and a real ligature-containing chunk file) in addition to
  synthetic PyMuPDF-generated fixtures. All test conversions wrote to `mktemp -d` scratch
  directories only; `~/Projects/Literature/` was never mutated (confirmed: the repo's pre-existing
  uncommitted changes all carry mtimes from 2026-07-06, three days before this session).

### Key verification evidence

- **BUG 1 root cause**: reproduced exactly — `marker_single` absent, and the removed
  `pdftotext -layout` path was the literal corruption cause (confirmed via the nix-ld shim
  failure/success round-trip and real two-column PDF conversions showing zero column-glue lines).
- **BUG 2**: `rabinovich_2014`'s 5-page TOC section (pages 7-11) extracted 2069/2065 source words
  (~100% coverage) via the fallback tier's TOC path, vs. the ~3-page cap the old code would have
  imposed.
- **BUG 3**: breadcrumb doubling eliminated (`command grep -rE '^(.+) > \1$'` returns zero matches
  on a synthetic repro of the exact original bug scenario). No-TOC heading tightening verified via
  a synthetic PDF reproducing the exact `indeterminacy.` corpus defect — correctly rejected, while
  a genuine `Introduction` heading was correctly accepted.
- **BUG 4**: exact regression matches for `swordﬁsh`→`swordfish`, `identiﬁ`→`identifi`,
  `synthe-\nsis`→`synthe-sis` (keep-hyphen), math Unicode (`𝑓 𝑔 ⨆ 𝑆 ℝ ℕ`) preserved byte-identical
  (no NFKC), and a real (read-only) corpus case `Flip-ﬂops`→`Flip-flops`.
- **Quality gate**: end-to-end exit 3 + `.rejected` write + no final `.md` + specific stderr
  reasons with measured values, verified against the real known-bad Alur document content
  (column-interleaving 79.0%, page-coverage 26.9%, dehyphenation-check 24 unresolved).
- **Caller wiring**: a stubbed mixed batch (1 good + 1 gate-failed source) through
  `literature-ingest.sh` correctly reports `Files quality-gate-failed: 1` distinct from
  `Files failed: 0`, names the offending file and reason, and still ingests the good file (no
  `set -e` abort from the previously-unhandled exit code).

## Interface Contracts (Phase 7 — for #832 and #833)

### Exit-code contract (`literature-convert.sh`)

| Code | Meaning |
|---|---|
| `0` | Success, quality gate passed |
| `1` | Input file missing or unsupported type |
| `2` | All converter tiers failed (no usable output produced) |
| `3` | **NEW**: conversion succeeded but the quality gate FAILED — output written to a `.rejected` sibling, final `.md` NOT written |

**#832 (corpus reconversion) MUST treat exit 3 as "skip + log,"** not as a generic failure —
accumulate a distinct gate-failed count/list, exactly as `literature-ingest.sh`'s Phase 5 wiring
now does. **#833 (retrieval/FTS hardening) is unaffected by exit codes** — it operates on already-
ingested chunk files, which by construction never came from a gate-rejected conversion.

### Output-format contract

- Markdown headings remain `## ...` (levels 1-4, `#` through `####`) — matches
  `literature-chunk.sh`'s `^(#{1,4})\s+(.+)$` regex, verified non-breaking against both engine
  tiers' output.
- `pymupdf4llm`'s bold/italic emphasis markup (`**_text_**`) does not collide with the atomic-block
  keyword regex (`^(?:\*{1,2})?(?:Theorem|Proof|Definition|...)`), since that regex anchors on
  specific keywords, not generic bold markers.
- Chunk files remain `chunk_NNNN.md` + `chunks.json` manifest — schema unchanged by this task.
- The fallback tier emits `[figure omitted]` markers for image blocks rather than silently
  dropping them (both tiers may still miss vector-art content — see limitations below).

### Breadcrumb-format contract

- `A > B > C`, now non-doubled after Phase 1's fix.
- No-TOC documents may legitimately have only a single top-level title with NO deeper heading
  markers at all (Phase 3's tightened heuristic rejects low-confidence heading candidates rather
  than promoting sentence fragments). **#833's retrieval logic must not assume every chunk has a
  deep `section_path`** — a shallow/absent breadcrumb is an expected, correct outcome for
  low-structure source documents, not a defect.

### Ligature-folding boundary

- **#831 stores ground-truth math text with targeted U+FB00–FB06 ligature folding only** (no
  blanket NFKC — verified to corrupt math-italic/blackboard-bold Unicode such as
  U+1D400–U+1D7FF, ℝ, ℕ).
- **#833 must perform its own FTS-time folding** for `unicode61` tokenizer matching (broader
  normalization for search purposes, applied at index time, not destructively at conversion time).
  This is a #833 dependency, not implemented here.

### Known limitations (accepted, for #832/#833 awareness)

- **`pymupdf4llm` drops vector-art math formulas** silently (boxed/rendered equations that are
  images in the source PDF, not text-layer content) — a text-layer-extraction limitation, not
  fixable within this task's scope. The page-coverage quality-gate check catches only severe
  (multi-page-scale) losses, not a single dropped formula.
- **`pymupdf4llm` can drop inter-word spaces around `<sup>`/`<sub>` markdown spans** — newly
  discovered during Phase 6 test-harness construction, on a real corpus document (Goldblatt/
  Hodkinson/Venema 2003; only read via a fresh in-process conversion, the corpus file itself was
  never touched). Now caught by the fifth quality-gate detector (`sentence_boundary_glue_count`,
  threshold 3). **#832 will need to route this specific source through
  `LITERATURE_CONVERTER=pymupdf` (forced fallback tier)** or accept the defect, since the primary
  tier's own output for this document correctly fails the gate.

### Nix unblock (documented prerequisite — NOT applied by this task)

`~/.dotfiles/packages/pymupdf4llm.nix` lives in a **different git repo** and was **not edited or
committed** as part of task 831 (`~/.dotfiles` was read for research context only, per the prior
research report, never touched by this implementation). For a future user-run rebuild:

- The existing "requires PyMuPDF 1.26.6, nixpkgs has 1.24.10" gate comment in
  `modules/home/packages/python.nix` is now **stale** — this machine's installed `pymupdf` is
  1.27.2.3, satisfying `>=1.26.6`.
- The pinned nix package version (0.2.2) lags current PyPI (1.28.0, the version this task pins in
  the `uv` venv), which now also needs `pymupdf-layout` + `onnxruntime` as dependencies, not just
  `tabulate`.
- Re-enabling requires a user-run `home-manager switch` in the `~/.dotfiles` repo.
- **The runtime built by this task does NOT depend on the nix package** — the `uv` venv
  (`.claude/scripts/literature-pyenv-provision.sh`) is the chosen, working path. Nix packaging is a
  non-blocking follow-up for the user, not a prerequisite for anything in #831/#832/#833.

## Notes

- The `uv`-venv + `nix-ld` shim pattern (`.claude/scripts/literature-pyenv-provision.sh`) is
  directly reusable for any future PDF/document-tooling task on this machine that needs a
  pip-wheel-compiled-extension Python package outside a nix-built interpreter. Worth a
  `.memory/` entry (see memory candidates in the metadata file).
- Test the pipeline against real corpus PDFs (read-only) whenever possible rather than relying
  solely on synthetic fixtures — this session's synthetic two-column fixture had an unrealistic
  first version (unwrapped text spanning both columns) that would have gone undetected without
  cross-checking against real documents; conversely, the real corpus checks caught a genuine
  `pymupdf4llm` defect that no synthetic fixture surfaced.
