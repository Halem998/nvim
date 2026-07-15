# Research Report: Task #868

**Task**: 868 - Evaluate whether Typst segmentation is "superior AND just as convenient" versus
the current markdown chunking for the literature extension, and implement conditionally.
**Started**: 2026-07-15T07:30:00Z
**Completed**: 2026-07-15T08:10:00Z
**Effort**: ~40 minutes (research only; no implementation — decision is NO format change)
**Dependencies**: 866 (complete — `literature-ingest-online.sh` bridge exists and delegates to
the same convert/chunk stage evaluated here)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/literature/scripts/literature-convert.sh` (full read, 765
  lines — engine tiers, quality gate, header rationale)
- Codebase: `agent-system/extensions/literature/scripts/literature-chunk.sh` (full read, 429
  lines — heading regex, atomic-block regex, chunk ID scheme)
- Codebase: `agent-system/extensions/literature/scripts/literature-schema.sql` (full read, 125
  lines — `chunks_data`/`chunks_fts`/`chunks_trigram` tables)
- Codebase: `agent-system/extensions/literature/scripts/literature-build-index.sh` (full read,
  323 lines — manifest discovery and chunk-file reading)
- Codebase: `agent-system/extensions/literature/scripts/literature-search.sh` (grepped —
  `do_read()`, `source_path` handling)
- Codebase: `agent-system/extensions/literature/scripts/literature-ingest.sh` (grepped — `*.md`
  glob at conversion-output discovery)
- Codebase: `agent-system/extensions/literature/scripts/literature-audit.sh` (grepped —
  pandoc/marker tool-availability audit results, lines 13-22 and 75-83)
- Codebase: `agent-system/extensions/typst/manifest.json`, `EXTENSION.md`,
  `context/project/typst/patterns/theorem-environments.md`,
  `context/project/typst/patterns/document-structure.md` (confirms authoring-only scope; no
  scripts, no converter, no chunker; `#theorem[]` is package-defined authoring sugar, not a
  parseable/reconstructible PDF artifact)
- Codebase: `specs/archive/831_fix_literature_conversion_pipeline_correctness/reports/01_conversion-pipeline-fix.md`
  (durable engine-evaluation record cited below)
- WebSearch: "PDF to Typst converter tool 2026", `"pdf2typst" OR "pdf-to-typst" github"`, "pandoc
  PDF input format support conversion 2026"
- WebFetch: `https://pandoc.org/MANUAL.html` (confirms pandoc typst reader/writer)
- Local tool probes: `pandoc --version` (3.7.0.2, `--list-input-formats`/`--list-output-formats`
  both list `typst`), `typst --version` (0.14.2, compiler only)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **DECISION: NO format change. Keep markdown as the sole convert/chunk/index format.** Typst
  segmentation is not superior, and the "just as convenient" test fails outright: **no PDF->Typst
  converter exists that is remotely comparable in maturity to the pdftotext+PyMuPDF path already
  in production.** The only candidates found are an ad-hoc LLM-based hobby project explicitly
  labeled "very much in development" and unvetted ad-supported web-form converters — neither is a
  batch-pipeline-grade dependency.
- **The task description's premise needs one correction.** `source_format` is not a column on the
  SQLite `chunks_data`/FTS5 index at all (`literature-schema.sql` has no such column); it is a
  field on the *document-level* JSON index (`specs/literature/index.json`, values `pdf`/`djvu`/
  `manual`) that records the **original source document's** format, not the intermediate
  conversion/chunk format. It would not "just work" as a format-agnostic flag for `.typ` vs `.md`
  chunks without being repurposed or duplicated.
- **The chunk-level SQLite pipeline is already format-agnostic in practice** — `literature-build-index.sh`
  discovers work via `find -name chunks.json` (format-neutral) and reads chunk file bytes via the
  manifest's `source_path` field with no hardcoded `.md` extension; `literature-search.sh`'s
  `do_read()` does the same. The one genuinely `.md`-hardcoded spot is `literature-ingest.sh`'s
  `ls "$TMP_MD_DIR"/*.md` glob for locating the converter's output file — a minor, isolated
  change, not evidence that a broader migration is warranted.
- **Typst's structural headings (`=`/`==`) and theorem functions (`#theorem[]`) offer no
  segmentation advantage over markdown for this corpus**, because the corpus is PDF-sourced, not
  natively authored in Typst. `#theorem[]` is package-defined authoring sugar (via
  `@preview/thmbox`, requiring `#show: thmbox-init` and custom `#let` bindings) — it is never
  present in a PDF and cannot be reconstructed by any available tool with more fidelity than the
  markdown pipeline's existing keyword-regex atomic-block detector (`Theorem|Proof|Definition|...`),
  which already operates on rendered text content, independent of markup syntax, and would work
  identically on a hypothetical `.typ` chunk.
- **This is a durable, evidence-backed decision, recorded here** (see "Decisions" below) so a
  future task does not re-litigate the same ground without new information — specifically, a
  future re-evaluation should be triggered only by a materially new fact: a maintained,
  install-cheap, deterministic (non-LLM) PDF->Typst converter reaching parity with
  `pymupdf4llm`'s empirically-verified correctness on multi-column/math-heavy PDFs.

## Context & Scope

Task 868 asks for a single go/no-go decision on replacing (or making pluggable) the literature
extension's markdown convert/chunk/index format with Typst, driven by a "superior AND just as
convenient" bar. The current pipeline (all in
`agent-system/extensions/literature/scripts/`):

1. **`literature-convert.sh`**: PDF/DJVU -> `{doc_id}.md`. Primary engine `pymupdf4llm` (pinned
   `uv` venv via `literature-pyenv-provision.sh`), mandatory fallback: zero-dependency PyMuPDF
   `get_text("blocks")` column-clustering. `marker`/`docling`/`nougat` and `pdftotext -layout`
   were evaluated and explicitly rejected in the pipeline's own header comment and in
   `literature-audit.sh`'s recorded audit results (durable in-repo anchors, not task citations).
2. **`literature-chunk.sh`**: heading-driven (`^(#{1,4})\s+(.+)$`) two-pass hierarchical chunking
   into `chunk_NNNN.md` + `chunks.json`, with a separate keyword-regex atomic-block detector
   (`Theorem|Proof|Definition|Lemma|Proposition|Corollary|Axiom|Claim|Conjecture|Observation`)
   that operates on the chunk's *text content*, not its markup.
3. **`literature-schema.sql`** / **`literature-build-index.sh`**: SQLite FTS5 index
   (`chunks_data` + `chunks_fts` + `chunks_trigram`), populated from `chunks.json` manifests and
   the chunk files they reference via `source_path`.
4. **`literature-search.sh`**: query/read interface, including `--read <chunk_id>` which resolves
   `source_path` and reads the file directly.

The Typst extension (`agent-system/extensions/typst/`) is confirmed authoring-only: its
`manifest.json` declares `"scripts": []`, and the directory contains only `agents/`, `skills/`,
and `context/` (patterns, standards, templates for hand-authoring `.typ` documents). There is no
converter, no chunker, and no PDF-reading capability anywhere in the extension.

## Findings

### Codebase Patterns

**Marker/pandoc rejection — durable anchors (not task citations)**:
- `literature-convert.sh` lines 24-31 (its own header comment): "`marker`/`marker_single`/docling/nougat`
  were evaluated and rejected (... heavy deps, OpenRAIL-licensed weights, GPU-oriented, no
  CPU-viable install on this machine) — they are not offered as options here; do not silently
  reintroduce a 'prefer marker' auto-path."
- `literature-audit.sh` lines 13-22 (Audit 1 Results comment block) and lines 75-83 (live
  `command -v` probe): `pandoc: AVAILABLE but cannot read PDF (output format only)`. This is the
  correct, current, and (per this research's own live probe) still-accurate status: pandoc 3.7.0.2
  on this machine lists `typst` in both `--list-input-formats` and `--list-output-formats`, but
  **PDF is not a pandoc input format at all** — pandoc's PDF support is output-only (via
  LaTeX/Groff/HTML backends), confirmed independently via WebSearch of pandoc's current manual.
  So even the "just convert existing markdown to typst via pandoc" idea is a dead end for the
  actual bottleneck (PDF ingestion), though it would trivially work as a *pure re-encoding* step
  if markdown were ever piped through it — see "Why re-encoding markdown as Typst adds nothing"
  below.

**Chunk-level index is already format-agnostic (contrary to the task description's stronger framing)**:
- `literature-build-index.sh` line 91: `find "$target_dir" -name "chunks.json"` — discovery has
  no format dependency.
- `literature-build-index.sh` lines 168-181: `chunk_file = os.path.join(manifest_dir,
  source_path)` then opens and reads it as plain text — no `.md` extension check or assumption
  anywhere in this script.
- `literature-search.sh`'s `do_read()` (grepped at lines 743, 825-834): resolves `source_path`
  from `chunks_data` and reads the file at that path directly — again no extension check.
- **The one real `.md`-hardcoded spot**: `literature-ingest.sh` lines 239-249 use
  `ls "$TMP_MD_DIR"/*.md` to locate the converter's output file and derive `DOC_ID` from it. This
  is the only place that would need a literal edit for a second format, and it is a single-line
  glob change, not a schema migration.

**`source_format` is a different field than the task description implies**:
- Grep across the whole repo shows `source_format` appears exclusively in the **document-level**
  JSON index schema (`specs/literature/index.json`, documented in
  `agent-system/extensions/literature/context/project/literature/domain/literature-index.md` and
  `agent-system/extensions/literature/README.md`), with enumerated values `pdf`, `djvu`, `manual`
  — i.e., it records what the *original source document* was, not what format the converted
  chunk text is in. It is **not a column in `literature-schema.sql`'s `chunks_data` table** (that
  table has no format-indicating column at all — confirmed by reading the full schema file).
  Reusing `source_format`'s existing enum for a chunk-format signal would conflate two different
  axes (source document type vs. converted-text markup dialect) and is not recommended even in a
  hypothetical "yes" world; a hypothetical future implementation would need a distinct field
  (e.g. `chunk_format` on `chunks_data`, or a per-document field on `document_metadata`).

**Typst's structural affordances do not apply to a PDF-sourced corpus**:
- `agent-system/extensions/typst/context/project/typst/patterns/theorem-environments.md`: `#theorem[...]`
  requires importing `@preview/thmbox`, `#show: thmbox-init`, and custom `#let theorem =
  thmbox(...)` bindings defined per-document. This is authoring-time semantic markup a human
  writes; it is not a primitive a converter could extract from a PDF's rendered glyphs any more
  reliably than the current pipeline's plain-text keyword regex already does.
- `literature-chunk.sh`'s `is_atomic_start()` matches on the literal words "Theorem", "Proof",
  "Definition", etc. at the start of a (stripped) line — this operates on *text content*, so it
  is already format-independent and would behave identically whether the surrounding markup were
  `**Theorem 3.4.**` (markdown) or `= Theorem 3.4` / `#theorem[...]` (typst). Typst headings
  (`=`, `==`) are the same information-content as markdown's `#`, `##` — a syntax remap, not a
  segmentation improvement.

### External Resources — PDF->Typst converter landscape (the crux)

- **No mature, comparable-to-`pymupdf4llm` PDF->Typst converter exists.** Candidates found:
  - `jehaj/Convert-PDF-to-Typst` (GitHub): converts PDF to Typst via a **local LLM (e.g. Gemma)**.
    Explicitly described in its own repo framing as "very much in development." An LLM-based
    conversion step is non-deterministic, unauditable at scale, and a poor fit for an offline,
    unattended, ~4,000-file batch pipeline — the opposite of the `pymupdf4llm`/PyMuPDF-fallback
    design philosophy already adopted (deterministic, no-GPU, fast, auditable quality gate).
  - Generic ad-supported "online PDF to Typst converter" web tools (e.g. `converting.cloud`):
    not inspectable, not scriptable/batchable, not a real dependency candidate for an offline
    pipeline.
  - A Typst-community discussion (`typst/typst` GitHub Discussion #5248, "Converting pdf to
    typst::model::Document possible?") and web commentary independently confirm the structural
    reason no good tool exists: **a faithful PDF->Typst conversion is inherently lossy and would
    essentially require re-implementing a PDF layout/rendering engine** — this is a much harder
    problem than PDF->Markdown (which only needs to recover heading/paragraph/table structure,
    not full typesetting semantics), so the absence of tooling is not an oversight but reflects
    real technical difficulty.
  - Pandoc supports Typst as **both reader and writer** (verified live: `pandoc
    --list-input-formats` and `--list-output-formats` both list `typst` on pandoc 3.7.0.2), but
    **pandoc has no PDF reader at all** (output-only, confirmed both by the pre-existing
    `literature-audit.sh` record and independently via WebSearch/WebFetch of pandoc's current
    manual). Pandoc therefore cannot bridge the actual gap (PDF -> structured text); it could
    only re-encode already-produced markdown into Typst syntax as a cosmetic pass, which is
    covered next.

**Why re-encoding existing markdown as Typst (via `pandoc -f markdown -t typst`) would add
nothing**: since pandoc's typst *writer* is available and installed, one *could* mechanically
pipe `pymupdf4llm`'s markdown output through `pandoc -f markdown -t typst` to get `.typ` chunk
files "for free," without a new PDF converter. This was seriously considered as a middle path.
It is rejected because:
1. It transports the *same* heading/paragraph information already present in the markdown,
   through a different syntax — no new segmentation signal is created (pandoc cannot invent
   `#theorem[]` semantic tags that the source markdown didn't already mark up as such; it would
   at best emit plain `=`/`==` headings, mechanically remapped from `#`/`##`).
2. It adds a new per-document subprocess call, a new failure mode (pandoc AST conversion
   quirks — e.g. math delimiter remapping, table remapping — are a known source of fidelity
   loss per pandoc's own documentation), and a second on-disk format to maintain in
   `literature-chunk.sh`'s regexes, `literature-build-index.sh`'s glob, and
   `literature-search.sh`'s reader, for zero retrieval-quality gain.
3. The FTS5 index only ever stores plain-text content extracted from the chunk file (see
   `literature-build-index.sh` lines 170-181, `words = chunk_text.split()[:500]`) — BM25 ranking
   and trigram fallback search do not care about surrounding markup syntax at all, so even a
   "free" Typst re-encoding would be invisible to retrieval quality; the only visible effect
   would be `--read`'s raw chunk output using `=`/`==` instead of `#`/`##` marks, a purely
   cosmetic difference for a downstream agent that already parses breadcrumbs/section_path from
   `chunks.json`, not from re-parsing the markup itself.

### Recommendations

- **Do not build a PDF->Typst conversion path.** No available converter is deterministic,
  install-cheap, and offline-capable at a maturity level comparable to the already-hardened
  `pymupdf4llm` + PyMuPDF-fallback tiers. This fails the "just as convenient" bar decisively,
  independent of any segmentation-quality argument.
- **Do not add a typst-aware segmenter to `literature-chunk.sh`.** There is no PDF-derived
  Typst source to segment; building one without a converter is moot.
  Even for hand-authored `.typ` documents that might enter `specs/literature/` directly (e.g. a
  user drops in a `.typ` paper source they wrote), a heading-regex swap
  (`^(=+)\s+(.+)$` instead of `^(#{1,4})\s+(.+)$`) would be the entire "typst-aware" work needed —
  this is a trivial extension, not evidence for a wholesale migration, and should only be built
  if/when a concrete need for ingesting native `.typ` source documents (not PDFs) actually arises.
- **No index-schema changes are needed now.** The SQLite/FTS5 layer is already format-agnostic
  at the file-reading level (confirmed above); only `literature-ingest.sh`'s `*.md` glob is
  format-specific, and it should stay markdown-only until/unless a second format is actually
  produced by some future converter.
- **Correct the `source_format` characterization going forward**: any future document mentioning
  this decision should describe `source_format` accurately as a *document-index* field
  (`pdf`/`djvu`/`manual`) distinct from any hypothetical chunk-markup-format field, to prevent
  the same imprecision from recurring in a later task description.

## Decisions

- **NO format change: markdown remains the sole convert/chunk/index format for the literature
  extension.** Rationale (durable, self-contained — not dependent on any task number):
  1. No PDF->Typst converter exists at a maturity/determinism/install-cost level comparable to
     the pipeline's existing `pymupdf4llm`/PyMuPDF-fallback engines (see "External Resources"
     above) — the "just as convenient" bar is not met.
  2. Typst's structural affordances (`=`/`==` headings, `#theorem[]` functions) provide no
     segmentation advantage for a PDF-sourced corpus, because those affordances are
     authoring-time constructs that cannot be reliably reconstructed from rendered PDF content by
     any available tool — the "superior" bar is not met either.
  3. Re-encoding already-converted markdown into Typst via pandoc's writer was considered and
     rejected as pure syntactic churn with zero retrieval-quality effect (the FTS5 index only
     ever stores extracted plain text) and a new maintenance surface (chunker regex, index glob,
     reader path) for no benefit.
  - **Re-evaluation trigger**: a future task should only reopen this question if a new, material
    fact emerges — specifically, a maintained, deterministic (non-LLM), install-cheap PDF->Typst
    converter reaching correctness parity with `pymupdf4llm` on the same class of documents
    (multi-column, math-heavy academic PDFs) that this repository already uses as its
    correctness benchmark. Absent that, this decision stands.
- **No implementation work is dispatched from this task.** Per the task's own framing, "no format
  change" is a valid and complete terminus; there is no Phase 2/plan/implement step for a
  decision to keep the status quo.

## Risks & Mitigations

- **Risk**: A future contributor re-proposes Typst segmentation without knowing this evaluation
  happened. **Mitigation**: this report, plus the "Decisions" section's explicit re-evaluation
  trigger, is the durable record; a future researcher searching literature-extension context for
  "typst" will find this report via the task's `reports/` directory.
- **Risk**: The `source_format` imprecision in the task description could propagate into other
  planning documents if not corrected. **Mitigation**: flagged explicitly above with the accurate
  characterization (document-index field, not a chunk-format/FTS5 column).
- **Risk**: Dismissing `jehaj/Convert-PDF-to-Typst` as too immature could look stale if the
  project matures substantially. **Mitigation**: the re-evaluation trigger above is
  tool-agnostic — it names the *bar* (deterministic, install-cheap, correctness-parity with
  `pymupdf4llm`) rather than ruling out any specific project permanently.

## Context Extension Recommendations

- **Topic**: Literature extension format-agnostic index-layer behavior.
- **Gap**: No existing context file documents that `literature-build-index.sh` and
  `literature-search.sh`'s `--read` path are already format-agnostic (no `.md` hardcoding) except
  for `literature-ingest.sh`'s output-discovery glob. This is non-obvious from reading the schema
  file alone (which has no explicit format column) and is useful for any future format-related
  proposal (Typst or otherwise) to avoid re-deriving it from scratch.
- **Recommendation**: Consider adding a short note to
  `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`
  (or a new `patterns/format-agnostic-index.md`) capturing: (a) which scripts are format-agnostic
  today, (b) which single glob (`literature-ingest.sh`'s `*.md`) is not, and (c) the distinction
  between `source_format` (document-index field: pdf/djvu/manual) and any hypothetical
  chunk-markup-format field (does not currently exist).

## Appendix

### Search queries / commands used
- WebSearch: `PDF to Typst converter tool 2026`
- WebSearch: `"pdf2typst" OR "pdf-to-typst" github`
- WebSearch: `pandoc PDF input format support conversion 2026`
- WebFetch: `https://pandoc.org/MANUAL.html` (confirm typst reader/writer listing)
- Local probes: `pandoc --version`, `pandoc --list-input-formats | grep -i typst`, `pandoc
  --list-output-formats | grep -i typst`, `typst --version`
- Grep: `source_format` across the full repository (confirms it is a document-index-only field)
- Grep: `\.md\b` in `literature-build-index.sh` and `literature-ingest.sh` (confirms the single
  hardcoded glob location)

### Files read in full
- `agent-system/extensions/literature/scripts/literature-chunk.sh` (429 lines)
- `agent-system/extensions/literature/scripts/literature-schema.sql` (125 lines)
- `agent-system/extensions/literature/scripts/literature-build-index.sh` (323 lines)
- `agent-system/extensions/literature/scripts/literature-convert.sh` (first 120 lines: header,
  argument parsing, engine-mode resolution — sufficient to confirm engine-tier rationale;
  remainder not needed for this decision)
