# Format Decision: Markdown Retained for Convert/Chunk/Index

## Decision

Markdown remains the sole convert/chunk/index format for the literature extension. No
typst-based (or other markup-based) conversion, segmentation, or index-schema path is adopted.
This is a deliberate NO-GO, not an oversight: typst segmentation was evaluated against the
production markdown pipeline (`literature-convert.sh` -> `literature-chunk.sh` ->
`literature-build-index.sh` / `literature-schema.sql`) and did not clear either of the two bars
required to justify a format change.

## Rationale

A format change must be both **superior** (measurably better segmentation or retrieval quality)
and **just as convenient** (comparable install/maintenance cost to the existing path). Typst
fails both bars for this pipeline's actual workload — PDF/DJVU-sourced academic literature, not
natively-authored typst documents:

1. **No mature PDF-to-Typst converter exists ("just as convenient" bar fails).** The production
   markdown path runs a two-tier engine: PRIMARY `pymupdf4llm.to_markdown()` (via a pinned,
   auto-provisioned uv venv), FALLBACK zero-dependency PyMuPDF `page.get_text("blocks")`
   column-clustering with reading-order reconstruction — see the engine-tier header comment in
   `literature-convert.sh`. No comparable PDF-to-Typst converter exists at that maturity level.
   The candidates surveyed were an LLM-based hobby project still "very much in development" and
   unvetted ad-supported web tools — neither is a deterministic, install-cheap, maintained tool.
   `pandoc` has a typst *writer* but, per the audit-results block in `literature-audit.sh`
   ("pandoc: AVAILABLE ... NOTE: cannot read from PDF, output-only"), no PDF *reader* at all, so
   it cannot bridge PDF input to any structured output, typst or otherwise. Re-encoding an
   already-produced markdown file to typst via pandoc's writer would only add a syntactic
   translation step with no informational gain.

2. **No segmentation advantage for PDF-sourced, not-natively-authored content ("superior" bar
   fails).** Typst's structural affordances — `=`/`==` heading syntax and the `#theorem[]`-style
   function sugar provided by packages such as `@preview/thmbox` — carry no more segmentation
   information than markdown's `#`/`##` headings when the source material is a PDF whose
   structure was never authored in typst to begin with. `#theorem[]` in particular is
   authoring-time package sugar: it cannot be reconstructed from rendered PDF glyphs any more
   reliably than the existing plain-text keyword-regex atomic-block detector already used by
   `literature-chunk.sh`. There is no PDF-to-typst path that would recover richer structure than
   the current PDF-to-markdown path already does.

3. **The chunk-level index only ever sees extracted plain text, so markup syntax is
   irrelevant to retrieval.** `literature-schema.sql`'s `chunks_data` table (the canonical
   metadata table backing the `chunks_fts` FTS5 virtual table) stores `title`, `keywords`,
   `summary`, and `content` as plain `TEXT` columns — there is no chunk-format or
   markup-dialect column of any kind. Retrieval quality depends only on the extracted text
   content, never on whether that text happened to be wrapped in markdown or typst syntax.
   Changing the authoring markup would be pure syntactic churn with zero retrieval-side effect.

Background analysis and the full evidence trail for the prior conversion-engine work referenced
above live in `01_conversion-pipeline-fix.md` (research) and
`01_conversion-pipeline-fix-summary.md` (implementation summary), which established the
pymupdf4llm/PyMuPDF two-tier engine and explicitly evaluated and rejected `marker`, `docling`,
and `nougat` on dependency-weight and licensing grounds.

## Format-Agnostic Index Layer (Fact, Not a Change to Make)

The index/search layer is already almost entirely format-agnostic:

- `literature-build-index.sh` discovers chunks via `find -name chunks.json` and reads chunk
  content via each manifest entry's `source_path` field — neither is markdown-specific.
- `literature-search.sh`'s `do_read()` reads whatever file `source_path` points to — also not
  markdown-specific.

**The one format-hardcoded spot in the whole pipeline** is `literature-ingest.sh`'s
output-discovery glob, `ls "$TMP_MD_DIR"/*.md`, used to locate the converter's output file and
derive `DOC_ID` from its basename. This is recorded here as a **fact about the current
codebase**, not as a change to make — the NO-GO decision means this glob stays exactly as it is.
No script under `agent-system/extensions/literature/scripts/` is modified as part of this
decision record.

## `source_format` Clarification

`source_format` is a **document-level field in `specs/literature/index.json`** (and the global
`$LITERATURE_DIR/index.json`), with values `pdf`, `djvu`, or `manual`. It records what kind of
source document a given entry was originally derived from (e.g., "this doc_id came from a
scanned PDF" vs. "this was hand-written"). It is:

- **NOT** a column on `literature-schema.sql`'s `chunks_data` table or the `chunks_fts` FTS5
  virtual table.
- **NOT** a chunk-markup-dialect signal — it says nothing about whether a chunk's on-disk
  representation is markdown, typst, or anything else.

Any future proposal that treats `source_format` as if it already tracked chunk-markup dialect is
based on a misreading of the schema; document provenance and chunk markup dialect are two
entirely separate concerns, and today only the former is tracked anywhere in the index.

## Re-Evaluation Trigger

This decision should be reopened only if a **maintained, deterministic (non-LLM), install-cheap
PDF-to-Typst converter** reaches `pymupdf4llm`-level correctness parity on multi-column,
math-heavy academic PDFs — i.e., a tool comparable in maturity and installability to the current
PRIMARY engine tier, not an LLM-based or web-only tool. Until such a converter exists, the "just
as convenient" bar cannot be cleared, and the format-agnostic index layer described above means
there is nothing to gain from a segmentation standpoint even if it did.
