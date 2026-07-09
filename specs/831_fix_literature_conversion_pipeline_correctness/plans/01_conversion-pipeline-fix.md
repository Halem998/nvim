# Implementation Plan: Task #831

- **Task**: 831 - Fix literature conversion pipeline correctness (BUGS 1-4) + loud-failing quality gate
- **Status**: [NOT STARTED]
- **Effort**: 10 hours
- **Dependencies**: None (blocks #832 corpus reconversion; informs #833 retrieval hardening)
- **Research Inputs**: specs/831_fix_literature_conversion_pipeline_correctness/reports/01_conversion-pipeline-fix.md
- **Artifacts**: plans/01_conversion-pipeline-fix.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; plan-format-enforcement.md; artifact-formats.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the silently-corrupting conversion path in `.claude/scripts/literature-convert.sh` with an empirically-verified engine (`pymupdf4llm` primary, zero-dependency PyMuPDF column-clustering fallback), fix three downstream correctness bugs (page truncation, doubled breadcrumbs, ligature/hyphenation), and add a loud-failing conversion-quality gate (new exit code 3) so the pipeline can never again emit corrupt markdown while reporting success. Scope is the conversion pipeline only: `literature-convert.sh`, the BUG-3 region of `literature-chunk.sh`, the loud-failure wiring in the caller `literature-ingest.sh`, and new test/fixture files. Corpus reconversion (#832) and retrieval/FTS hardening (#833) are out of scope, but every output-format and exit-code interface those tasks depend on is recorded in Phase 7. Definition of done: converter produces correct reading order on a two-column PDF, rejects corrupt output loudly, and both a forced-fallback test and an Alur-SyGuS regression fixture pass.

### Research Integration

All engine and bug-fix conclusions are taken as settled from `reports/01_conversion-pipeline-fix.md` and are not re-litigated here. Key load-bearing conclusions this plan executes:
- **Engine**: `pymupdf4llm` primary, PyMuPDF `get_text("blocks")` column-clustering fallback. `pdftotext -layout` removed entirely (the literal cause of column-gluing). PyMuPDF `sort=True` explicitly forbidden (empirically reproduces the identical bug).
- **BUG 2**: one-line deletion of the `min(end_page, start_page + 3)` truncation at `literature-convert.sh:171`.
- **BUG 3**: `section_stack[:-1]` at both `build_section_path` call sites in `literature-chunk.sh` (lines ~196 and ~215); plus a conversion-time no-TOC heading-derivation tightening that rejects sentence-fragment "headings."
- **BUG 4**: targeted U+FB00–FB06 ligature map (NOT blanket NFKC, which corrupts math Unicode), plus keep-hyphen dehyphenation and per-block soft-wrap rejoining.
- **Quality gate**: column-interleaving heuristic, page-coverage assertion vs `len(doc)`, ligature scan, dehyphenation sanity check; exit code 3 + reject-to-`.rejected` + visible per-corpus summary.
- **Engine install path**: pinned `uv`-managed venv invoked by absolute `bin/python`, with the `nix-ld` + `stdenv.cc.cc.lib` `LD_LIBRARY_PATH` shim. Re-enabling `~/.dotfiles/packages/pymupdf4llm.nix` is a documented follow-up, not a runtime dependency.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this meta task.

## Goals & Non-Goals

**Goals**:
- Remove every silently-column-corrupting code path (`pdftotext -layout`, `sort=True`) from `literature-convert.sh`.
- Make `pymupdf4llm` the primary engine and a column-aware PyMuPDF function the mandatory, tested fallback.
- Fix BUG 2 (page truncation), BUG 3 (doubled breadcrumbs + fragment headings), BUG 4 (ligatures/hyphenation).
- Add a loud-failing quality gate with new exit code 3 that refuses to write corrupt markdown to the final path.
- Prove the fallback tier works with the primary engine forced-unavailable.
- Add a regression fixture asserting correct two-column reading order.
- Record the exact chunk-format / breadcrumb-format / exit-code interface that #832 and #833 will depend on.

**Non-Goals**:
- Corpus reconversion of `~/Projects/Literature/` (that is #832; this task must not mutate the corpus).
- Retrieval / FTS5 / index-time ligature folding (that is #833; recorded as an interface note only).
- OCR / layout-model engines (marker, docling, nougat) — evaluated and rejected in research.
- Table extraction (`gmft`), figure cataloguing, per-page LLM gist — flagged as future work in research.
- Editing `~/.dotfiles/` (a different git repo) — nix unblock is a documented user prerequisite only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A half-migrated converter silently emits corrupt output between phases | H | M | Phase 3 removes `-layout`/`sort=True` in the SAME phase it introduces the correct tiers; the eliminated path is the silent-corruption source, so intermediates fail loudly (or are correct), never silently-wrong. |
| Column-clustering fallback's 0.6 full-width / 5pt-bin thresholds are tuned to one PDF and misfire on an untested layout | M | M | The quality gate (Phase 5) is the safety net: column-interleaving heuristic fails loudly (exit 3) rather than emitting garbage. Thresholds exposed as tunable constants. |
| Fallback path is written but never exercised (the exact bug class being fixed: preferred engine absent, nobody noticed) | H | M | Phase 6 forces the primary engine unavailable and asserts the fallback either produces correct output or fails loudly. |
| `pymupdf4llm` silently drops vector-art math formulas | M | M | Documented as an accepted known limitation of text-layer extraction; page-coverage assertion catches severe (multi-page) losses only. Recorded for #833. |
| Caller `literature-ingest.sh` swallows exit 3 via `2>&1 | tail -1` and treats a rejected file as a generic failure | M | H | Phase 5 rewrites the caller's per-file invocation to check the exit code explicitly and accumulate a visible "N converted, M gate-failed" summary. |
| uv venv / nix-ld shim is a maintenance seam outside nix-native tooling | L | H | Documented trade-off; venv is gitignored and auto-provisioned; nix-native path recorded as follow-up (Phase 7). |
| Regression fixture PDF cannot be committed (size/licence) | M | M | Phase 6 generates a hermetic synthetic two-column PDF via PyMuPDF at test time (no network, no committed binary); the real Alur PDF is an optional stronger check, skip-with-warning when absent. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix BUG 3 breadcrumb doubling in literature-chunk.sh [COMPLETED]

**Goal**: Eliminate the `A > A` doubled-breadcrumb defect (2,351 affected corpus chunks) at its source in `split_at_headings()`, independent of any engine change.

**Tasks**:
- [x] In `literature-chunk.sh`, at the in-loop flush call site (line ~196) pass `section_stack[:-1]` instead of `section_stack` to `build_section_path`. *(completed)*
- [x] At the final-flush call site (line ~215) apply the same `section_stack[:-1]` change. *(completed)*
- [x] Confirm the level-0 / empty-stack document case is unaffected (`[][:-1] == []`). *(completed: verified via standalone repro)*
- [x] Do NOT touch the no-TOC fragment-heading cause here (that is conversion-time, Phase 3) — this phase only removes the doubling. *(completed: untouched)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-chunk.sh` — two-call-site fix in `split_at_headings()`.

**Verification**:
- Standalone repro: run the `split_at_headings` logic on a synthetic 3-level heading document; assert produced `section_path` is `Doc > Indeterminacy` not `Doc > Indeterminacy > Indeterminacy`.
- Run `literature-chunk.sh` on a small hand-written multi-heading `.md` in a temp dir; `grep -E '^(.+) > \1$'` over generated `chunk_*.md` breadcrumb lines returns zero matches.

---

### Phase 2: Provision pinned engine environment (uv venv + nix-ld shim) [COMPLETED]

**Goal**: Establish an auto-provisioned, gitignored `uv` venv containing `pymupdf4llm`, invoked by absolute `bin/python`, with the `nix-ld` + `stdenv.cc.cc.lib` `LD_LIBRARY_PATH` shim, without yet changing any pipeline behavior.

**Tasks**:
- [x] Choose and document the venv location (e.g. `.claude/scripts/literature-pyenv/`); add it to `.gitignore` (do NOT commit the venv). *(completed: `.claude/scripts/literature-pyenv/`)*
- [x] Write a provisioning helper (a function in `literature-convert.sh` or a small `literature-pyenv-provision.sh`) that: creates the venv via `uv venv` if absent, installs a pinned `pymupdf4llm` version, and is idempotent/cached. *(completed: new `literature-pyenv-provision.sh`, pinned `pymupdf4llm==1.28.0`)*
- [x] Implement the `LD_LIBRARY_PATH` shim: prepend `$(nix-build '<nixpkgs>' -A stdenv.cc.cc.lib --no-out-link)/lib` (cached) to `$NIX_LD_LIBRARY_PATH` when invoking the venv python, so the compiled `_extra` wheel loads. Detect/set this in the calling script; never assume the caller's env has it. *(completed: cached in `.claude/scripts/literature-pyenv/.cclib_path`)*
- [x] Add graceful detection: if `uv` is unavailable or provisioning fails, the helper must report unavailability cleanly (so Phase 3's tier logic can fall back), never crash. *(completed: `set -uo pipefail`, no `-e`, all failure paths return non-zero + stderr log)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-convert.sh` (or new `.claude/scripts/literature-pyenv-provision.sh`) — provisioning + shim helper.
- `.gitignore` — exclude the venv directory.

**Verification**:
- Run the provisioning helper; then `"<venv>/bin/python" -c "import pymupdf4llm; print(pymupdf4llm.__version__)"` succeeds with the shim applied.
- Force the shim off and confirm the failure mode is the known `libstdc++.so.6` error, then confirm the shim resolves it (proves the shim is load-bearing and working).
- Convert a real PDF to a temp dir with `pymupdf4llm.to_markdown()` via the venv python; eyeball correct column order on a two-column page.

---

### Phase 3: Rewrite engine tier + delete BUG 2 + tighten no-TOC headings in literature-convert.sh [COMPLETED]

**Goal**: Make `pymupdf4llm` the primary engine and a column-clustering PyMuPDF function the mandatory fallback; remove every silently-corrupting path; delete the BUG 2 truncation; and stop propagating sentence-fragment headings — all in one phase so no silently-wrong intermediate exists.

**Tasks**:
- [x] Add a primary tier that calls `pymupdf4llm.to_markdown()` via the Phase 2 venv python. *(completed: `try_pymupdf4llm()` in the unified engine)*
- [x] Add the fallback tier: PyMuPDF `page.get_text("blocks")` column-clustering + reading-order function per research section 3 (full-width threshold 0.6·page_width, 5pt x-histogram bins, segment split at full-width blocks, bands left-to-right, blocks top-to-bottom). Expose thresholds as named constants. Handle `page.rotation != 0` via a "no columns assumed" path. Emit `[figure omitted]` markers rather than dropping image blocks. *(completed: `order_blocks_by_column()`, `FULL_WIDTH_THRESHOLD`/`HIST_BIN_WIDTH` constants; verified zero column-glue on real two-column corpus PDFs Zielonka 1998 and Goldblatt/Hodkinson/Venema 2003)*
- [x] Remove `pdftotext` layout-preserving-flag path entirely: deleted from both the plain-pdftotext path and the old hybrid's page-text source. If retained as an explicit last resort, invoked WITHOUT the layout flag. *(completed: `try_pdftotext_explicit()`, explicit-override only, not in `auto`)*
- [x] Ensure PyMuPDF's row-major whole-page-sort option is NOT used anywhere (comment marks it as a forbidden trap). *(completed)*
- [x] Neutralize the `marker`/`marker_single` auto-preference: never silently fall through to a layout-destroying engine; make engine selection explicit and logged. *(completed: `marker` removed entirely per research Non-Goals rejection; every engine choice is logged via `log "Engine used: ..."`)*
- [x] Delete the BUG 2 truncation: TOC-section page range is now the full `range(start_page, end_page)`. *(completed; verified: rabinovich_2014 5-page section extracted 2069/2065 source words, ~100% coverage, vs. the ~3-page-capped ~60% the old code produced)*
- [x] Tighten no-TOC heading derivation (BUG 3 upstream cause): require a heading candidate to be bold/large-font AND not end in terminal punctuation (`. , ;`) AND be under ~80 chars AND not a sentence continuation; if no candidate survives, emit NO heading markers rather than promoting a low-confidence guess. *(completed: `is_heading_candidate()`; verified via synthetic PDF reproducing the exact `indeterminacy.` corpus defect — fragment correctly rejected, genuine `Introduction` heading correctly accepted)*
- [x] Update the `LITERATURE_CONVERTER` override doc-comment and the exit-code header comment (exit 3 added in Phase 5). *(completed)*

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/literature-convert.sh` — engine tiers, removal of `-layout`/`sort`/marker-preference, BUG 2 deletion, no-TOC heading tightening.

**Verification**:
- `grep -nE 'sort=True|-layout' .claude/scripts/literature-convert.sh` returns zero matches.
- `grep -n 'start_page + 3' .claude/scripts/literature-convert.sh` returns zero matches.
- Run `literature-convert.sh <two-column.pdf> <tmpdir>` on a real PDF; assert the column-glue signature `grep -P '\S\s{4,}\S' <output>.md` is below threshold (no left/right column text glued on one line).
- Convert a multi-page-section document; assert output word count is proportional to page count (BUG 2 no longer truncates sections to 3 pages).
- Feed a no-reliable-heading document; assert no sentence-fragment `##` headings appear in output.

---

### Phase 4: BUG 4 normalization pass (ligatures, dehyphenation, soft-wrap) [COMPLETED]

**Goal**: Add a targeted, math-safe normalization pass to `literature-convert.sh` output, run per column-clustered block before concatenation.

**Tasks**:
- [x] Implement a targeted ligature map covering exactly U+FB00–FB06 (`ﬀﬁﬂﬃﬄﬅﬆ` → `ff fi fl ffi ffl st st`). Do NOT run blanket NFKC. *(completed: `fold_ligatures()`; verified regressions `swordﬁsh`→`swordfish`, `identiﬁ`→`identifi`, plus a real (read-only) corpus case `Flip-ﬂops`→`Flip-flops`)*
- [x] Implement keep-hyphen dehyphenation: `word-\nword` → `word-word`. *(completed: `dehyphenate()`; verified `synthe-\nsis` → `synthe-sis`)*
- [x] Implement soft-wrap rejoining within a single block's paragraph only. *(completed: `rejoin_soft_wraps()`, splits on blank-line paragraph breaks first)*
- [x] Run normalization on each block's own text before concatenation so soft-wrap rejoining cannot cross columns. *(completed: fallback tier calls `normalize_unit()` per PyMuPDF block; primary tier calls `normalize_document()` per markdown paragraph)*
- [x] Confirm math-heavy sample text (`𝑓 𝑔 ⨆ 𝑆 ℝ ℕ`) passes through unchanged (no NFKC collapse). *(completed: verified byte-identical after fold+dehyphenate)*

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:
- `.claude/scripts/literature-convert.sh` — normalization function applied in both engine tiers.

**Verification**:
- Convert a ligature-containing PDF; `grep -cP '[\x{FB00}-\x{FB06}]' <output>.md` == 0.
- `grep -cP '[a-z]-\n[a-z]' <output>.md` == 0 (no lowercase hyphen-linebreak survivors).
- Convert a math-heavy PDF; assert blackboard-bold / math-italic Unicode (ℝ, ℕ, 𝑓) is preserved verbatim in the output (not folded to R, N, f).
- Regression: `swordﬁsh` → `swordfish`, `identiﬁ` → `identifi`.

---

### Phase 5: Quality gate, exit code 3, and loud-failure contract [COMPLETED]

**Goal**: Add a post-conversion validation step that refuses to emit corrupt markdown, introduce exit code 3, and wire the caller to surface gate failures visibly across the corpus.

**Tasks**:
- [x] Implement the four detectors per research section 6. *(completed: `run_quality_gate()`. Deviation on detector 1's threshold formula — see below.)*
- [x] Add exit code 3 (conversion succeeded but quality gate failed), extending the current 0/1/2 scheme; update the script header comment. *(completed)*
- [x] Loud-failure contract: on gate failure, print `[convert] QUALITY GATE FAILED: <specific reason(s) with measured values>` to stderr AND write output to a `.rejected` sibling so no caller can mistake a failed conversion for a success. *(completed; verified end-to-end: exit 3, `.rejected` written, final `.md` NOT written, stderr names each failed check with measured values)*
- [x] Wire the caller `literature-ingest.sh`: capture and check the exit code explicitly (no longer swallowed by a `| tail -1` pipe under `set -e`); on exit 3 log the specific file + reason and increment a distinct `GATE_FAILED` counter; emit a final summary with a distinct `Files quality-gate-failed` count and per-file reason list. *(completed; verified via a stubbed mixed batch: 1 good + 1 gate-failed file, summary correctly reports both counts and names the offending file)*
- [x] Ensure the existing unconditional `[convert] Metrics: headings=... words=... math=...` line is no longer presented as a success signal. *(completed: metrics line is now explicitly documented as "informational only — NOT a correctness signal"; also fixed a pre-existing cosmetic bug where a zero count printed as a duplicated `0` line)*

**Deviation**: The column-interleaving detector's "avg glued line length > 1.5x median" check used the WHOLE DOCUMENT's median line length per the research spec. Empirically verified against the actual known-bad Alur SyGuS corpus document (the task's own motivating example): this formulation **failed to flag it** (79% of lines glued, but the glued lines themselves dominate and inflate the document-wide median, so the ratio check never fires). Fixed by comparing against the median length of the NON-glued lines specifically (falling back to the whole-document median only when literally every line is glued). Re-verified: now correctly flags the real Alur document, still does not false-positive on well-formed synthetic/real content, and does not false-positive on any of this task's own successful conversions (Zielonka 1998, Goldblatt/Hodkinson/Venema 2003, Rabinovich 2014, both engine tiers).

**Timing**: 2 hours

**Depends on**: 3, 4

**Files to modify**:
- `.claude/scripts/literature-convert.sh` — quality gate + exit 3 + reject behavior.
- `.claude/scripts/literature-ingest.sh` — exit-code-aware per-file handling + corpus-level gate-failed summary.

**Verification**:
- Feed a deliberately column-interleaved / low-coverage input; assert converter exits 3, prints a `QUALITY GATE FAILED: <reason=measured value>` line, writes a `.rejected` file, and writes NO final `.md`.
- Convert a known-good PDF; assert exit 0 and gate passes.
- Run `literature-ingest.sh` over a small set containing one good and one gate-failing source; assert the final summary reports the gate-failed count and names the offending file.

---

### Phase 6: Fallback-forced test + Alur SyGuS regression fixture [NOT STARTED]

**Goal**: Prove the fallback tier is actually exercised and correct (the whole point of this task class), and lock in a two-column reading-order regression.

**Tasks**:
- [ ] Create a test harness under `.claude/scripts/tests/` (e.g. `test-literature-convert.sh` + a Python helper); create the directory.
- [ ] **Forced-fallback test**: invoke the converter with the primary engine forced unavailable (e.g. hide/rename the venv or set an override), assert the PyMuPDF column-clustering fallback path is taken (logged), and assert it EITHER produces correct column order (interleaving heuristic passes) OR fails loudly with exit 3 — never silently emits corrupt output.
- [ ] **Regression fixture**: generate a hermetic synthetic two-column PDF at test time via PyMuPDF (known left-column and right-column sentences, no network, no committed binary); run the full converter; assert reading order is left-column-complete-then-right-column (column text never interleaved on one line).
- [ ] **Optional stronger check**: if a real Alur SyGuS PDF is present (via `LITERATURE_TEST_PDF` env or a cached fixture path), additionally assert its known-bad body page now extracts in correct order; if the PDF is absent, SKIP WITH WARNING (never fail). Convert to a temp/scratch dir only — never touch `~/Projects/Literature/`.
- [ ] Document how to obtain the real Alur PDF (research located it at the cs.utexas.edu FMCAD'13 mirror) for anyone wanting the stronger check.

**Timing**: 1.5 hours

**Depends on**: 5

**Files to modify**:
- `.claude/scripts/tests/test-literature-convert.sh` (new) — forced-fallback + regression tests.
- `.claude/scripts/tests/` supporting Python helper (new).

**Verification**:
- Run the forced-fallback test; assert it reports the fallback tier was used and the output passed the interleaving heuristic (or exited 3).
- Run the regression fixture test; assert correct two-column order on the synthetic PDF.
- Run with `LITERATURE_TEST_PDF` unset; assert the real-PDF check skips with a visible warning and the suite still passes.

---

### Phase 7: Cross-task interface contracts (#832/#833) + nix unblock prerequisite [NOT STARTED]

**Goal**: Write down the exact interface commitments #832 and #833 depend on, and document the `~/.dotfiles` nix unblock as a user prerequisite (not an agent edit).

**Tasks**:
- [ ] Record the **exit-code contract**: `0` success+gate pass, `1` input missing/unsupported, `2` all converters failed, `3` NEW gate failed (do-not-ingest). State that #832 reconversion MUST treat exit 3 as "skip + log," and #833 is unaffected by exit codes.
- [ ] Record the **output-format contract**: markdown headings as `## ...` (matches `literature-chunk.sh`'s `^(#{1,4})\s+(.+)$` regex — verified non-breaking); bold/italic emphasis does not collide with the atomic-block keyword regex; chunk files remain `chunk_NNNN.md` + `chunks.json` manifest (schema unchanged).
- [ ] Record the **breadcrumb-format contract**: `A > B > C`, now non-doubled after Phase 1; no-TOC docs may legitimately have only a single top-level title (no fragment headings) — #833 retrieval must not assume a deep `section_path` on every chunk.
- [ ] Record the **ligature-folding boundary**: #831 stores ground-truth math text with targeted ligature folding only (no NFKC); #833 must perform FTS-time folding for `unicode61` search matching. This is a #833 dependency, not implemented here.
- [ ] Record `pymupdf4llm`'s dropped-vector-math limitation as an accepted known limitation for #833 awareness.
- [ ] **Nix unblock (documented prerequisite, no repo edits)**: `~/.dotfiles/packages/pymupdf4llm.nix` is in a DIFFERENT git repo and MUST NOT be committed as part of task 831. Document: (a) the stale "requires PyMuPDF 1.26.6" gate comment in `modules/home/packages/python.nix` (machine now has 1.27.2.3, satisfying ≥1.26.6); (b) the pinned 0.2.2 lags PyPI 1.28.0, which now also needs `pymupdf-layout` + `onnxruntime`; (c) re-enabling requires a user-run `home-manager switch`. State clearly the runtime does NOT depend on the nix package (the uv venv from Phase 2 is the chosen path), so this is a non-blocking follow-up for the user.
- [ ] Capture these contracts in the implementation summary (and, if warranted, a short note file within the task directory).

**Timing**: 1 hour

**Depends on**: 6

**Files to modify**:
- Implementation summary (written at `/implement` time) and/or a note file under `specs/831_fix_literature_conversion_pipeline_correctness/`.

**Verification**:
- Read back the recorded contracts; confirm each of exit-codes, chunk format, breadcrumb format, and ligature-folding placement is stated explicitly with the #832 vs #833 owner named.
- Confirm the nix section explicitly marks `~/.dotfiles` as out-of-repo and the change as a user action, not an agent action.

---

## Testing & Validation

- [ ] `grep -nE 'sort=True|-layout' .claude/scripts/literature-convert.sh` returns zero matches (silent-corruption paths removed).
- [ ] `grep -n 'start_page + 3' .claude/scripts/literature-convert.sh` returns zero matches (BUG 2 gone).
- [ ] Breadcrumb doubling: zero `^(.+) > \1$` matches in freshly generated chunks (BUG 3).
- [ ] Ligature scan: zero U+FB00–FB06 in fresh output; math Unicode preserved (BUG 4).
- [ ] Column-order correct on a synthetic two-column PDF (regression fixture).
- [ ] Forced-fallback test: fallback tier exercised, output correct or exit 3 (never silently wrong).
- [ ] Quality gate: deliberately-corrupt input yields exit 3, `.rejected` file, stderr reason with measured values, and no final `.md`.
- [ ] Caller summary: `literature-ingest.sh` reports a distinct gate-failed count over a mixed batch.
- [ ] No mutation of `~/Projects/Literature/` at any point (all test conversions write to temp/scratch dirs).

## Artifacts & Outputs

- `.claude/scripts/literature-convert.sh` (modified) — new engine tiers, removed `-layout`/`sort`, BUG 2 fix, no-TOC heading tightening, normalization pass, quality gate + exit 3.
- `.claude/scripts/literature-chunk.sh` (modified) — BUG 3 breadcrumb fix.
- `.claude/scripts/literature-ingest.sh` (modified) — exit-3-aware handling + corpus gate-failed summary.
- `.claude/scripts/literature-pyenv-provision.sh` or in-script helper (new/modified) — uv venv + nix-ld shim.
- `.claude/scripts/tests/test-literature-convert.sh` (+ Python helper) (new) — forced-fallback + regression fixture.
- `.gitignore` (modified) — exclude the venv directory.
- `specs/831_fix_literature_conversion_pipeline_correctness/summaries/01_conversion-pipeline-fix-summary.md` — implementation summary incl. #832/#833 interface contracts and nix prerequisite.

## Rollback/Contingency

- All changes are confined to `.claude/scripts/` (a git-tracked config repo) plus a gitignored venv; revert via `git checkout .claude/scripts/literature-convert.sh .claude/scripts/literature-chunk.sh .claude/scripts/literature-ingest.sh .gitignore` and delete the venv + `.claude/scripts/tests/` additions.
- Phases are ordered so each leaves the repo working; if a later phase must be abandoned, earlier phases (BUG 3 fix, engine swap, normalization) stand alone and remain valuable.
- No corpus data is touched, so no data rollback is ever required. The nix change is never applied by this task, so there is nothing to roll back in `~/.dotfiles`.
