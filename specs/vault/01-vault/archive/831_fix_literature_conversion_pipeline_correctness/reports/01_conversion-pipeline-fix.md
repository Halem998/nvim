# Research Report: Task #831

**Task**: 831 - Fix silent conversion-correctness bugs in `.claude/scripts/literature-convert.sh`
**Started**: 2026-07-09
**Completed**: 2026-07-09
**Effort**: Large (engine swap + 3 correctness bugs + new quality gate)
**Dependencies**: None (blocks #832 corpus reconversion, informs #833 retrieval hardening)
**Sources/Inputs**:
- `.claude/scripts/literature-convert.sh` (364 lines, read in full)
- `.claude/scripts/literature-chunk.sh` (423 lines, read in full)
- Empirical extraction tests against the real `alur_2013_syntax-guided-synthesis` source PDF (FMCAD'13 tutorial paper, downloaded from `cs.utexas.edu` — the exact paper cited as the known-bad corpus case), plus corpus artifacts (`chunk_0012.md`, `wdb.cariani.santorio/chunk_0010.md`)
- Live probing of this machine's installed toolchain (`fitz`/PyMuPDF 1.27.2.3, `pdftotext` 25.10.0/poppler, `torch` 2.11.0 already present, no `marker`/`marker_single`)
- `~/.dotfiles` flake/overlay/home-manager sources (`packages/pymupdf4llm.nix`, `overlays/python-packages.nix`, `modules/home/packages/python.nix`) — an existing, currently-disabled nix package for `pymupdf4llm`
- WebSearch/WebFetch on marker-pdf and docling PyPI metadata for dependency-footprint confirmation
**Artifacts**: This report — `specs/831_fix_literature_conversion_pipeline_correctness/reports/01_conversion-pipeline-fix.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Engine recommendation: `pymupdf4llm`, with a zero-dependency PyMuPDF blocks/reading-order function as the always-available fallback tier, and `pdftotext -layout` removed entirely.** Empirically verified against the real Alur SyGuS PDF: `pymupdf4llm` produces correct column order, resolves ligatures, and adds markdown structure (headings/bold/italic) — at ~100MB install cost, no `torch` requirement, ~0.2s/page.
- **Root cause of BUG 1 is even narrower than the task description assumed**: it isn't just that `marker_single` is missing — `pdftotext -layout` (the specific flag in `try_pdftotext()` and inside `try_pymupdf()`'s page-text source) is the direct cause of column-interleaving. Plain `pdftotext` (no `-layout`) and plain PyMuPDF `page.get_text()` (no `sort=True`) both already produce correct reading order on this same PDF. **`sort=True` on PyMuPDF is a trap**: it reproduces the identical row-major interleaving bug as `-layout` — do not use it as "the safe option."
- **A working, disabled nix package for `pymupdf4llm` already exists** at `~/.dotfiles/packages/pymupdf4llm.nix`, wired into `overlays/python-packages.nix`, but commented out in `modules/home/packages/python.nix` with the note "requires PyMuPDF 1.26.6, nixpkgs has 1.24.10." That blocker is now stale — this machine's `pymupdf` is 1.27.2.3. However the pinned nix package version (0.2.2) is far behind current PyPI (1.28.0, which now also pulls a new `pymupdf-layout` + `onnxruntime` dependency pair, not just `tabulate`). For #831's immediate unblock, recommend a **pinned local `uv` venv** invoked by `literature-convert.sh` (validated working in this session, including the NixOS `libstdc++.so.6` shim via `nix-ld`), with nix packaging as a slower-moving follow-up.
- BUG 2 (3-page TOC-section truncation) is a one-line deletion; confirmed at `literature-convert.sh:171`.
- BUG 3 (doubled breadcrumbs) root-caused by reading the actual `split_at_headings()` code in `literature-chunk.sh`: the current heading is pushed onto `section_stack` *before* being used to build that same chunk's `section_path`, so it appears twice. Fix and reproduction included below (verified with a standalone repro, not just static reading).
- BUG 4 (ligatures): **do not use blanket NFKC.** Empirically verified that NFKC normalization of a real math-heavy PDF's extracted text collapses distinct mathematical-alphanumeric Unicode symbols (𝑓, 𝑆, ℝ, ℕ from the "Mathematical Alphanumeric Symbols" / letterlike blocks) down to plain ASCII letters, which is exactly the kind of math-corrupting side effect the task asked me to check for. Use a **targeted ligature-only mapping** (U+FB00–FB06) instead.
- Design-input triage (pdf2sqlite ideas): per-page LLM gist and `sqlite-vec` embeddings belong to #833 (retrieval), not #831. `gmft` table extraction and figure cataloguing are conversion-time in principle but are net-new heavy dependencies and out of scope for the bug-fix task — flagged as future work, not implemented here.

## Context & Scope

Task #831 is scoped strictly to the conversion pipeline: `.claude/scripts/literature-convert.sh` and its immediate downstream consumer contract with `.claude/scripts/literature-chunk.sh`. Corpus reconversion (#832) and retrieval/FTS hardening (#833) are out of scope; this report flags interface points those tasks will depend on but does not design them.

Both scripts were read in full (364 and 423 lines respectively) before any recommendation was formed, per the task's constraint.

## Findings

### Environment Ground Truth (this machine)

| Tool | Status | Version | Notes |
|---|---|---|---|
| PyMuPDF (`fitz`) | Installed | 1.27.2.3 | System python3 (`~/.nix-profile/bin/python3`, 3.13.13) |
| `pdftotext` | Installed | 25.10.0 (poppler) | |
| `marker` / `marker_single` | **Not installed** | — | Confirms BUG 1's premise |
| `pymupdf4llm` | Not installed in system python | — | But installable in ~35s via `uv venv` + `uv pip install`, no compile step (ships wheels) |
| `docling`, `nougat` | Not installed | — | Not tested locally; assessed from PyPI metadata (below) |
| `torch` | **Already installed**, 2.11.0 | — | Present for unrelated packages (Jupyter/ML stack in `python.nix`); not a blocker for any candidate here since none of the recommended tiers need it |
| `uv` | Installed | — | `/run/current-system/sw/bin/uv` |
| nix-ld | **Enabled**, `NIX_LD_LIBRARY_PATH` set | — | Does not include `libstdc++` by default; pip-wheel binaries (PyMuPDF's compiled `_extra` module) need `stdenv.cc.cc.lib` added to `LD_LIBRARY_PATH` to run outside a nix-built Python — see "Packaging Reality" below |

### 1. Engine Evaluation

| Engine | Install cost | Torch/GPU? | Offline? | License | Multi-column | Math | Tables | Speed (this corpus) | NixOS packaging |
|---|---|---|---|---|---|---|---|---|---|
| `marker_single` | **Not installed here**; per PyPI/docs, "2GB+ install," requires PyTorch, uses Surya OCR/layout models | Yes — GPU strongly recommended, works CPU but slow | Yes (after model download, ~GBs) | Code GPL-3.0-or-later; **model weights under a modified OpenRAIL-M license** (free for research/personal/small-startup use, NOT unconditionally free) | Best-in-class (purpose-built layout model) | Best-in-class (dedicated equation OCR) | Best-in-class (table detection model) | Slow on CPU; ~122 pages/sec claimed on H100 GPU, unusable reference point for this machine | Not in nixpkgs; would need a from-scratch derivation for Surya's model weights — high maintenance risk |
| `pymupdf4llm` | **~100MB** (pymupdf, pymupdf-layout, onnxruntime, numpy, networkx — verified by actual `uv pip install`) | **No torch.** Uses `onnxruntime` (CPU) for its own small layout model | Yes, fully offline after install | **AGPL-3.0** (per the existing local nix package's `meta.license`) — note for any redistribution, not a blocker for local personal tooling | **Verified correct** on the real 2-column Alur PDF (see empirical test below) | Partial — inline math/boxed-equation regions rendered as vector art are **dropped**, not OCR'd (verified: a `φ₁` specification formula silently vanished from extracted text) | Not evaluated in depth; not the recommendation driver here | **~0.2s/page** (8-page PDF in 1.6s total, cold start included) | Already has a disabled nix package in this repo (`~/.dotfiles/packages/pymupdf4llm.nix`) — see Packaging Reality |
| `docling` (IBM) | Base install moderate; optional extras (`easyocr`, `onnxruntime`, `rapidocr`, `vlm`) suggest a heavier default pipeline than pymupdf4llm | Default pipeline typically pulls a layout/table model; torch not declared as a hard base dependency per PyPI metadata but commonly resolved transitively through the default backend | Yes, with pre-downloaded models | MIT (docling itself); bundled models vary | Good — has a dedicated layout model | Good — has formula/table understanding as first-class features | **Best of the CPU-friendly options** for structured tables | Not benchmarked locally (not installed) — heavier pipeline implies slower than pymupdf4llm | Not in nixpkgs; not evaluated further given pymupdf4llm's empirically-verified sufficiency |
| `nougat` | Transformer-based image-to-markdown OCR model; requires torch + a vision-transformer checkpoint | Yes, torch; GPU strongly recommended for reasonable speed | Yes after model download | MIT (code); Meta-released weights | Good (whole-page OCR sidesteps column-ordering entirely) | **Best for pure-math papers** (designed for it) | Weak (not its design target) | Very slow on CPU (full OCR per page) | Not evaluated; heaviest of all candidates for marginal gain over pymupdf4llm on this corpus (mostly non-math prose PDFs plus some math-heavy ones) |
| Raw PyMuPDF `get_text("blocks")` + custom reading-order sort | **Zero new dependencies** (PyMuPDF already installed) | No | Yes | Same as pymupdf's own license (AGPL/commercial dual) | **Verified correct** with a column-clustering algorithm (below); fragile on author-byline-style multi-sub-column blocks (see failure cases) | No markdown/bold structure; math regions extracted as raw glyphs same as PyMuPDF default (better than nothing, worse than pymupdf4llm's markdown) | No structural table support | Fast (bounded by PyMuPDF's own C-level extraction) | None needed — already present |

**Recommendation**: `pymupdf4llm` as the primary engine, PyMuPDF blocks/reading-order as the **mandatory fallback tier** (not an equal alternative — see "Engine Selection Contract" below), `marker`/`docling`/`nougat` **not adopted** for #831. `marker`'s multi-GB weight download plus OpenRAIL-licensed weights plus torch-on-CPU slowness makes it a bad fit for a corpus of ~4,000 files running unattended and offline on a laptop-class NixOS machine. `docling` and `nougat` were assessed from documentation/PyPI metadata only (not installed) per the "if a candidate can't be installed cheaply, say so explicitly" instruction — neither offered enough incremental correctness over the already-verified `pymupdf4llm` result to justify their heavier footprints for this task's scope.

### 2. Empirical Test — Alur SyGuS Paper (the known-bad case)

Downloaded the actual paper (`Tutorial-Syntax-Guided-Synthesis.pdf`, cs.utexas.edu FMCAD'13 mirror — the same Alur et al. 2013 paper already converted into the corpus at `~/Projects/Literature/sources/alur_2013_syntax-guided-synthesis/`) and ran five extraction methods on the same two-column body page.

**Corpus artifact — confirmed corrupted (current pipeline output)**, `~/Projects/Literature/sources/alur_2013_syntax-guided-synthesis/chunk_0012.md`:
```
In principle,        problem of optimal synthesis which requires the synthesis tool
adding support for problems with more than one unknown               to return the expression with the least cost among the correct
function is merely a matter of syntactic sugar.

For exam-            ones.
```
Left-column and right-column text glued onto the same line via the wide mid-line whitespace gap — this is `pdftotext -layout`'s literal visual-layout preservation, not reading order.

**Test 1 — `pdftotext -layout` (current pipeline behavior, reproduced directly against the source PDF)**: same interleaving bug, confirmed as the literal cause:
```
concrete parts of the partial program and the assertions into        to a first order formula in the background theory with all
the specification formula ', while the holes will be represented     its variables universally quantified, and (3) the universe of
```

**Test 2 — plain `pdftotext` (no `-layout`)**: correct reading order on the body page, ligatures already resolved as a side effect of poppler's default mode:
```
concrete parts of the partial program and the assertions into
the specification formula ', while the holes will be represented
with the unknown functions to be synthesized, and the space
```
But **fails on the title page's author-byline block** — a row of narrow name/affiliation columns got reordered incorrectly (`Rajeev Alur†` directly followed by `Sanjit A. Seshia‡`, skipping intervening authors). Also produced visibly garbled output on a table/algorithm-box-heavy page (page 7). This is evidence that plain `pdftotext` reading-order heuristics are not reliable enough as the sole fix, even though removing `-layout` is a large, nearly-free improvement.

**Test 3 — PyMuPDF `page.get_text()` default (no `sort=True`)**: correct column order on the same body page. **Reordering correctness here is content-stream-order luck**, not a guaranteed algorithm — it happens to work because this PDF (like most LaTeX/pdfLaTeX output) emits column content in visual order in its content stream. Not safe to rely on for arbitrary PDFs (e.g., those produced by tools that interleave columns in the stream).

**Test 4 — PyMuPDF `page.get_text(sort=True)`**: **reproduces the exact same interleaving bug as `pdftotext -layout`.** This is an important, non-obvious finding: `sort=True` sorts by y-coordinate row-major across the whole page width, which is precisely the wrong thing for multi-column layouts. Do not treat `sort=True` as "the fix" — it is not.

**Test 5 — Custom column-clustering + reading-order function** (implementation below, verified against both the two-column body page and the mixed full-width-title/two-column-abstract title page): correct on both.

**Test 6 — `pymupdf4llm.to_markdown()`** (installed via `uv venv` in ~35s, 100MB total): correct column order, ligatures resolved, markdown structure added (`##` headings, `**bold**`/`_italic_` for emphasized text), fast (1.6s for the whole 8-page PDF). Excerpt:
```markdown
## I. INTRODUCTION

In _program_ , we want to check if a program satisfies its logical specification.
...
concrete parts of the partial program and the assertions into the specification formula
_'_ , while the holes will be represented with the unknown functions to be synthesized,
```
**Known failure modes observed in this same output** (worth encoding in the quality gate / documenting as accepted limitations):
- A boxed correctness-specification formula (`φ₁ : f(x, y) = f(y, x) ∧ f(x, y) ≥ x`) rendered as vector art in the source PDF is **silently dropped** — the surrounding sentence reads "The free variables in the [MISSING] are assumed to be universally quantified" where "specification formula" should appear.
- Running headers/footers and page numbers (`**_viii_ ISBN 978-0-9835678-3-7/13...**`, stray `**1**`, `**2**`) leak into the body text mid-paragraph.
- A page containing an algorithm/table box produced fragmented, low-value output — matches the general table-handling weakness of text-layer-only extraction.

### 3. Reading-Order Algorithm (for the fallback tier)

Specify concretely, verified working against both a pure two-column body page and a mixed title-page layout (single-column title/byline/abstract header, e.g. spanning nearly the full page width):

1. Extract blocks via `page.get_text("blocks")` (not `"dict"` — blocks are sufficient and cheaper; use `"dict"` only if per-span font-size is also needed, as in heading detection, section 5).
2. Classify each block as **full-width** if `(x1 - x0) > 0.6 * page_width` (covers titles, section headers that span both columns, and — usefully — also often catches header/footer strips, though those need separate filtering, see quality gate). This threshold (0.6) was empirically sufficient for the tested PDF; should be tunable.
3. Sort all blocks by `y0` and sweep top-to-bottom, splitting into **segments** at each full-width block (a full-width block both closes the preceding multi-column segment and is emitted on its own).
4. Within each multi-column segment, cluster narrow blocks into left-to-right **column bands** using an x-axis occupancy histogram: mark 5pt-wide bins as "occupied" wherever any block's `[x0, x1]` span covers them, then take contiguous occupied-bin runs as column bands (this is the "gaps in the x-histogram" approach named in the task, verified over a fixed bin width rather than a fixed number of columns — handles docs that mix 1- and 2-column sections on different pages without hardcoding column count).
5. Assign each block to the band with maximum x-overlap; sort each band's blocks by `y0`; emit bands left-to-right, each band's blocks top-to-bottom.

**Known failure cases** (to document, not silently paper over):
- **Author-byline-style rows of many narrow sub-columns** (3+ short columns on one line, as seen on the Alur title page) can still misorder if the histogram bin width or full-width threshold doesn't cleanly separate them from body columns — this exact case was NOT triggered in my column-clustering test (it correctly reconstructed the byline) but plain `pdftotext` DID fail on it, which is itself useful evidence that engine choice matters even within "PyMuPDF-family" options.
- **Figures/tables spanning both columns without being detected as "full-width text blocks"** (because they're images, not text blocks, and `get_text("blocks")` only returns text blocks by default — image blocks need `page.get_text("dict")` or `page.get_images()` handled separately) will not be correctly interleaved; they should be treated as opaque markers (e.g., `[figure omitted]`) rather than silently dropped or misplaced.
- **Footnotes** at the bottom of a column often sit in their own narrow column-width block below the main columns — the algorithm above will place them in whichever column band they horizontally overlap, which is usually acceptable (footnote ends up appended to that column) but not guaranteed correct reading order relative to the main text.
- **Rotated pages** (landscape figures/tables inserted into a portrait document) — `get_text("blocks")` coordinates are pre-rotation; not handled by this algorithm and not tested here. Should be detected (via `page.rotation != 0`) and routed to a distinct, simpler "no columns assumed" path rather than run through the column clusterer.

### 4. Normalization Pass

**Do not apply blanket Unicode NFKC.** Empirically verified with the actual math-heavy corpus content (`logos_manual_ch1-2.pdf` extraction contains `𝑓, 𝑔: (𝖥𝗂𝗇ₙ→𝑆) →𝑆`):
```python
>>> unicodedata.normalize('NFKC', '𝑓 𝑔 ⨆ 𝑆  ℝ ℕ')
'f g ⨆ S  R N'
```
NFKC collapses the "Mathematical Alphanumeric Symbols" block (U+1D400–U+1D7FF, used for italic/bold/blackboard-bold math variables) down to plain ASCII/Latin letters. This is a real correctness risk for a formal-methods/math-heavy literature corpus: a math-italic `𝑓` (a specific bound variable in a proof) and the prose word `f` become indistinguishable after normalization, and blackboard-bold `ℝ`/`ℕ` (real/natural numbers) become plain `R`/`N`, which could collide with unrelated identifiers.

**Recommended approach**:
- **Targeted ligature mapping only**, covering exactly U+FB00–FB06 (`ﬀ ﬁ ﬂ ﬃ ﬄ ﬅ ﬆ` → `ff fi fl ffi ffl st st`), verified correct and side-effect-free on the sample ligature strings from the task (`swordﬁsh` → `swordfish`, `identiﬁ` → `identifi`).
- **Do not** run full NFKC over the whole document. If broader normalization is wanted for FTS purposes specifically (not the canonical stored markdown), do it at **index time** in #833 as a derived/searchable field, not destructively at conversion time in #831 — this preserves the ground-truth math text in the stored `.md`/chunk files while still letting FTS5 match on the folded form. This is exactly the kind of #831-vs-#833 boundary the task asked me to flag.
- **Dehyphenation across line breaks**: join `word-\nword` → `wordword` only when (a) the character before the hyphen is lowercase, (b) the hyphen is the last non-whitespace character on the line, and (c) the first character after the line break is lowercase — this heuristic avoids destroying legitimately hyphenated compounds that happen to fall at a line break (e.g. "well-\nknown" should still de-hyphenate to "well-known" in general use, so a stricter rule is: de-hyphenate to the SPACE-joined form `well known` only if the joined-without-hyphen form is not itself a plausible compound; practically, safest default is to de-hyphenate to the hyphen-preserving form `word-word` and let downstream FTS tokenization handle it, rather than guessing whether the hyphen was original punctuation). Recommend: **rejoin across the line break, keep the hyphen**, i.e. `word-\nword` → `word-word`, never guess-delete the hyphen. This is strictly safer (never destroys real compounds) at the minor cost of not fixing pure PDF-typesetting hyphenation (e.g. "synthe-\nsis" would remain "synthe-sis" rather than becoming "synthesis"). A stronger heuristic (dictionary-based: check if the dehyphenated joined form is a known word) is possible but adds a dependency (word-list lookup) — flag as an enhancement, not required for #831's bug-fix scope.
- **Soft-wrap rejoining**: join `word\nword` (no hyphen, mid-sentence) into `word word` only within a single extracted block's paragraph (never across a block/column boundary, since that's exactly the bug being fixed) — this is naturally satisfied if normalization runs on each column-clustered block's own text before concatenation, not on the final concatenated document.

### 5. Heading Derivation (BUG 3 root cause and fix)

Read `literature-chunk.sh`'s `split_at_headings()` (lines 168–218) directly. Root cause, confirmed by standalone repro (not just static reading):

```python
# lines 190-197 (current, buggy)
for line in lines:
    heading_match = re.match(r'^(#{1,4})\s+(.+)$', line)
    if heading_match:
        if current_lines or current_level == 0:
            section_path = build_section_path(section_stack, current_title)  # BUG: current_title is ALREADY the last entry in section_stack
            flush_chunk(current_level, current_title, section_path, current_lines)
        ...
        section_stack.append((heading_level, heading_title))  # <- this line, from the PRIOR heading iteration, already pushed current_title
```

When a new heading line is encountered, the code flushes the *previous* section's chunk. But `section_stack`'s last element is `(current_level, current_title)` — pushed at the end of the *previous* iteration that started this same section. `build_section_path(stack, title)` then does `[t for _, t in stack] + [title]`, appending `current_title` a second time, since it's already `stack[-1]`. Verified reproduction:
```
BUGGY:  section_path='Doc > Indeterminacy > Indeterminacy'
FIXED:  section_path='Doc > Indeterminacy'          # using section_stack[:-1] as the ancestor list
```
**Fix**: at both call sites (line ~196 inside the loop, and line ~215 in the final flush), pass `section_stack[:-1]` instead of `section_stack` as the ancestor list. Verified via standalone Python repro to produce non-doubled breadcrumbs for a synthetic 3-level heading document; the empty-stack (document-level, level-0) case is unaffected since `[][:-1] == []`.

**No-TOC heading fallback** (the `wdb.cariani.santorio/chunk_0010.md` case — `indeterminacy. > indeterminacy.`): this is a *conversion-time* problem, not a chunking-time one — `literature-convert.sh`'s no-TOC branch (lines 190–239) does font-size-based heading detection, but when a document has **no reliable large-font headings** (e.g. a scanned/OCR'd or uniformly-typeset document), the heuristic at line 208 (`body_size = max(size_counts.items(), key=lambda x: x[1])[0]`) can pick up a body-text line that happens to have a slightly-larger font (e.g. a drop-cap sentence opener, an emphasized run-in phrase) as a "heading," which then gets propagated as `current_title` into the chunker, producing a sentence-fragment section title, and then BUG 3 doubles it into the visible breadcrumb.

**Recommended fix** (conversion-time, not chunk-time): tighten heading detection using PyMuPDF `dict`-mode span metadata already partially used at line 197–228 — require a heading candidate line to satisfy **both** a font-size threshold (already present) **and** a font-weight/style signal (bold flag — `span['flags'] & 2**4` for bold in PyMuPDF's flags bitmask, or check `span['font']` name for "Bold"/"Black") **and** a position/length heuristic (line starts near the left margin of its column, is under ~80 characters, and is NOT a continuation of the previous line's sentence — i.e., the previous line ends with terminal punctuation or is blank). Additionally, **reject heading candidates that end in terminal punctuation** (`.`, `,`, `;`) since a genuine section heading essentially never ends mid-sentence — this single check alone would have prevented the `indeterminacy.` case. If no candidate survives these filters for a document, fall back to **no heading markers at all** (plain paragraphs, single top-level document title only) rather than promoting a low-confidence guess — this is strictly better for the chunker (it still works, just chunks by size/paragraph instead of by heading) and prevents propagating garbage into `section_path`/breadcrumbs that #833's retrieval will surface to users.

### 6. The Quality Gate

Concrete, cheap (no ML), testable detectors, to run as a post-conversion validation step in `literature-convert.sh` before the markdown is accepted:

1. **Column-interleaving heuristic**: for each line in the output, compute the count and total width of "mid-line whitespace runs" (regex `\S(\s{4,})\S` — 4+ consecutive spaces flanked by non-space, tuned to exceed normal word-spacing but catch layout-preserved column gaps). If more than a threshold fraction of non-blank lines (e.g. >15%) contain such a run, AND those lines' average length exceeds ~1.5x the document's median line length (glued lines are conspicuously long), flag as likely column-interleaved. This directly targets the `pdftotext -layout` failure signature observed in `chunk_0012.md` (`In principle,        problem of optimal synthesis...`).
2. **Page-coverage assertion**: after conversion, re-open the source PDF with PyMuPDF (`fitz.open(pdf_path)`) independent of whichever engine produced the markdown, and assert that the extracted markdown's total word count is not less than some fraction (e.g. 40%) of `sum(len(page.get_text().split()) for page in doc)`. A large shortfall indicates silent content loss (e.g. the BUG 2 3-page-per-section truncation, or an engine that dropped pages). Concretely wire `len(doc)` (page count) into the check as the task specifies: also assert the markdown mentions/covers content proportional to `len(doc)`, not just a word-count ratio, to catch the specific "N pages of TOC section silently truncated to 3" failure mode even when total word count looks superficially plausible for a shorter document.
3. **Ligature scan**: `grep -cP '[\x{FB00}-\x{FB06}]' output.md` (or the Python equivalent) — any match after conversion is a hard failure, since the normalization pass (section 4) should have eliminated all instances U+FB00–FB06 by construction. This is a strict post-condition check, not a heuristic.
4. **Dehyphenation sanity check**: count occurrences of the pattern `[a-z]-\n[a-z]` (a hyphen immediately followed by a line break, both sides lowercase) remaining in the raw pre-chunked markdown. Given the recommended safe dehyphenation policy (rejoin across the break, keep the hyphen — section 4), this count should be **zero** after the normalization pass runs (since `\n` inside a word context should have been rejoined to `-` with no line break); a nonzero count indicates the normalization pass didn't run or missed cases.

**Exit codes** (extending the current 0/1/2 scheme at the top of `literature-convert.sh`):
```
0 — success, quality gate passed
1 — input file missing or unsupported type (existing)
2 — all converters failed (existing)
3 — NEW: conversion succeeded but quality gate failed (column-interleaving, page-coverage, ligature, or dehyphenation check failed)
```
**"Loud" means**, per the task's explicit no-silent-degradation requirement:
- On exit 3, the script MUST print a `[convert] QUALITY GATE FAILED: <specific reason(s)>` line to stderr naming exactly which check(s) failed and their measured values (not just a boolean), and MUST NOT write the corrupted markdown to its final output path (write to a `.rejected` sibling file instead, or leave no output file, so a caller scanning the output directory can't mistake a failed conversion for a successful one).
- The calling script (whatever invokes `literature-convert.sh` per-file, in `skill-literature`/`/literature --convert`) must treat exit 3 distinctly from exit 0/2: log the specific file and reason to a visible summary (not buried in per-file stderr that scrolls past), and — given this is a ~4,000-file corpus — accumulate a final "N converted, M quality-gate-failed (see list)" summary rather than silently continuing. This is the direct fix for the original bug report's core complaint: the pipeline currently reports `[convert] Metrics: headings=... words=... math=...` unconditionally as if these were success signals, when they said nothing about correctness.

### 7. Design-Input Triage (`draperlaboratory/pdf2sqlite`)

| Idea | Belongs to | Reasoning |
|---|---|---|
| Per-page LLM "gist" | **Neither / #833 at most** | Requires an LLM call per page (~4,000 files × N pages = large, non-deterministic, costly, and orthogonal to fixing conversion correctness). If ever wanted, it's a retrieval-time enrichment (#833), not a deterministic conversion step. Do not implement in #831. |
| Structural table extraction (`gmft`) | **Future work / explicitly out of #831** | `gmft` is itself a torch-based table-structure-recognition model — another heavy dependency of exactly the kind BUG 1's fix is trying to avoid defaulting to. Genuinely conversion-time in principle (tables should be part of the markdown), but adding it now would repeat the mistake this task is fixing (silently degrading quality is bad; so is silently ballooning dependency footprint under time pressure). Recommend a dedicated follow-up task if table quality becomes a measured problem after the #831/#832 fix lands. |
| Figure cataloguing | **Future work / out of #831** | Lower cost than gmft (bounding boxes only, no captioning model needed — `page.get_images()` is free with PyMuPDF) but still scope creep against the bug-fix mandate. Note only. |
| `sqlite-vec` embeddings | **#833 (retrieval)**, unambiguously | This is a retrieval/index-time concern, not conversion. Explicitly out of #831. |

## Decisions

- **Adopt `pymupdf4llm` as the primary conversion engine**, with the PyMuPDF blocks/reading-order function (section 3) as the mandatory fallback when `pymupdf4llm` is unavailable (venv missing/broken) — never falling back further to `pdftotext -layout`.
- **Remove `pdftotext -layout` entirely** from `literature-convert.sh` (both `try_pdftotext()`'s own invocation and the `page_texts` source inside `try_pymupdf()`). If `pdftotext` is retained anywhere as a last-resort text source, it must be invoked **without** `-layout`.
- **Do not use PyMuPDF `sort=True`** as a fix for anything — verified to reproduce the exact bug it would appear to solve.
- **Fix BUG 2** by deleting the `min(end_page, start_page + 3)` truncation at `literature-convert.sh:171`, replacing with `range(start_page, end_page)`.
- **Fix BUG 3** by using `section_stack[:-1]` (not `section_stack`) as the ancestor list at both `build_section_path` call sites in `literature-chunk.sh`'s `split_at_headings()`.
- **Fix BUG 3's upstream no-TOC heading-fragment cause** at conversion time: require heading candidates to be bold/large-font AND not end in terminal punctuation; fall back to "no headings" (not a low-confidence guess) when no candidate survives.
- **Fix BUG 4** with a targeted U+FB00–FB06 ligature map, explicitly rejecting blanket NFKC due to its demonstrated math-corrupting side effects.
- **Add exit code 3** and a "loud failure" contract (reject-file-on-gate-failure + visible per-corpus summary) for the new quality gate.
- **Engine install path**: recommend a pinned `uv`-managed venv under the literature toolchain's own directory (e.g. `.claude/scripts/literature-pyenv/` or similar — exact location is an implementation-planning decision for #831's plan phase, not fixed here), invoked via its absolute `bin/python`, with the `nix-ld`/`stdenv.cc.cc.lib` `LD_LIBRARY_PATH` shim documented and (ideally) auto-detected/set by the calling script rather than assumed to be in the caller's environment. Updating `~/.dotfiles/packages/pymupdf4llm.nix` to the current 1.28.0 API (which now needs `pymupdf-layout` + `onnxruntime`, not just `tabulate`) and re-enabling it in `modules/home/packages/python.nix` is the more "correct" long-term NixOS-native path but requires a `home-manager switch` rebuild cycle outside this repo's control — flag as a recommended follow-up, not a blocking dependency for #831.

## Risks & Mitigations

- **Risk**: `pymupdf4llm`'s dropped-embedded-math-image behavior (silently vanishing boxed formulas) could itself look like a new silent-degradation bug if not caught. **Mitigation**: the page-coverage assertion (section 6, item 2) partially catches severe cases (large word-count shortfalls), but a formula rendered as a small vector graphic won't move the word count much. Recommend documenting this as an accepted, known limitation of text-layer extraction (not fixable without OCR/layout-model tooling this task explicitly avoids) rather than trying to close the gap within #831.
- **Risk**: The venv/shim approach for NixOS packaging is a maintenance seam separate from the rest of the repo's Nix-native tooling. **Mitigation**: explicitly documented as a known trade-off above, with the nix-native path named as a follow-up.
- **Risk**: Column-clustering fallback's 0.6 full-width threshold and 5pt histogram bin width are tuned against a single test PDF. **Mitigation**: the quality gate (section 6) is the safety net — if the fallback tier misfires on an untested layout, the column-interleaving heuristic should catch it and fail loudly (exit 3) rather than silently emit garbage, which is the entire point of this task.
- **Risk**: Backward compatibility — `literature-chunk.sh`'s heading regex (`^(#{1,4})\s+(.+)$`) and atomic-block regex (`^(?:\*{1,2})?(?:Theorem|Proof|...)`) must still match `pymupdf4llm`'s markdown output style (`##` headings, `**_Italic Bold_**` emphasis). **Verified**: `pymupdf4llm`'s heading output (`## I. INTRODUCTION`) matches the existing regex; its bold/italic runs (`**_Abstract_ —...**`) don't collide with the atomic-block-start regex since that regex anchors on specific keywords (Theorem/Proof/Definition/etc.), not generic bold markers. No chunk-format contract break identified. `literature-build-index.sh`/`literature-search.sh` (FTS5) consume plain text content only — unaffected by the markdown-structure change, though the ligature-fold fix (section 4's recommendation to fold at *index* time for FTS matching, not destructively at conversion time) is a new interface point #833 should pick up: FTS5's `unicode61` tokenizer needs the folded form to match on ligature-containing terms, so either #831 emits a fold at chunk time for the FTS-indexed copy specifically, or #833 does the fold during indexing. This report does not decide that placement — flagging it for #833's own research is the right boundary per the task's scope instruction.

## Context Extension Recommendations

- **Topic**: PDF/literature conversion engine choices and NixOS packaging patterns for Python ML-adjacent tooling.
- **Gap**: No existing `.claude/context/` or `.memory/` entry documents the `pymupdf4llm` nix package / `uv` venv + `nix-ld` shim pattern discovered in this research, despite it being directly reusable for any future PDF/document-tooling task on this machine.
- **Recommendation**: After #831 implementation lands, consider a `.memory/` entry (or `.claude/context/project/literature/` doc) capturing: (a) the `nix-ld` + `stdenv.cc.cc.lib` `LD_LIBRARY_PATH` shim needed to run pip-wheel binaries outside a nix-built Python on this machine, and (b) the now-stale version-gate note in `~/.dotfiles/packages/pymupdf4llm.nix`/`python.nix` so it doesn't get rediscovered from scratch next time.

## Appendix

### Search queries / commands used
- `nix eval nixpkgs#python3Packages.pymupdf.version` → confirmed 1.27.2.3 (satisfies pymupdf4llm's >=1.26.6 requirement, invalidating the "TEMPORARILY DISABLED" comment in `python.nix`)
- `uv venv testenv --python 3.13` + `uv pip install --python testenv/bin/python pymupdf4llm` → 11 packages, ~100MB, no torch, ~35s
- WebSearch: `marker-pdf vs docling vs pymupdf4llm 2026 install size torch dependency comparison`
- WebFetch: `https://pypi.org/project/docling/`, `https://pypi.org/project/marker-pdf/`
- WebSearch: `Alur 2013 "Syntax-Guided Synthesis" FMCAD pdf filetype:pdf` → located the exact source PDF at `https://www.cs.utexas.edu/~hunt/FMCAD/FMCAD13/papers/Tutorial-Syntax-Guided-Synthesis.pdf`

### Test scripts written (scratchpad, not part of any deliverable)
- Column-clustering reading-order prototype (`colreader2.py`) — the algorithm specified in section 3, empirically verified against the real Alur PDF's title page and a pure-2-column body page.
- Standalone `split_at_headings` breadcrumb-doubling repro confirming both the bug and the `section_stack[:-1]` fix.

### Files read in full (per task constraint)
- `.claude/scripts/literature-convert.sh` (364 lines)
- `.claude/scripts/literature-chunk.sh` (423 lines)

### Files referenced but not modified (research only)
- `~/.dotfiles/flake.nix`, `~/.dotfiles/overlays/python-packages.nix`, `~/.dotfiles/packages/pymupdf4llm.nix`, `~/.dotfiles/modules/home/packages/python.nix`
- `~/Projects/Literature/sources/alur_2013_syntax-guided-synthesis/chunk_0012.md`
- `~/Projects/Literature/wdb.cariani.santorio/chunk_0010.md`
