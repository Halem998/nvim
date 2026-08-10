# Research Report: PyMuPDF4LLM vs MarkItDown -- PDF Conversion Quality Comparison

- **Task**: 384 - Improve /convert command-skill-agent
- **Started**: 2026-04-13T20:00:00Z
- **Completed**: 2026-04-13T20:15:00Z
- **Effort**: small
- **Dependencies**: None
- **Sources/Inputs**:
  - DEV Community: Evaluating Document Parsers for Air-Gapped RAG Systems (ashokan)
  - DEV Community: PyMuPDF4LLM Evaluation (m_sea_bass)
  - Systenics AI: PDF to Markdown Conversion Tools Deep Dive (2025)
  - TheMenunLab: Best Open-Source PDF-to-Markdown Tools in 2026
  - Jimmy Song: Best Open Source PDF to Markdown Tools (2026)
  - GitHub: MarkItDown Issues #164, #1117, #1276
  - GitHub: Tools in Data Science -- PDF to Markdown Comparison
  - Artifex: RAG/LLM and PDF Conversion with PyMuPDF
  - Medium: Benchmarking PDF to Markdown Document Converters
- **Artifacts**: `specs/384_improve_convert_command_skill_agent/reports/03_pymupdf-vs-markitdown.md`
- **Standards**: report-format.md, artifact-management.md

## Executive Summary

- PyMuPDF4LLM is substantially better than MarkItDown for PDF-to-markdown conversion across all quality dimensions (structure, tables, formatting, images, OCR).
- MarkItDown's PDF handling is widely acknowledged as its weakest capability; one benchmark rated PDF success at 25%. GitHub issue #164 ("PDF to markdown is not good") confirms community dissatisfaction.
- MarkItDown's strength is multi-format support (DOCX, PPTX, XLSX, HTML) -- it should remain the primary tool for those formats.
- Neither tool is best-in-class for complex PDFs; Docling (IBM) and Marker outperform both for academic papers and complex table layouts.
- This confirms the task 384 plan: pymupdf should be primary for PDFs, markitdown should be fallback for non-PDF document formats.

## Context & Scope

Web research comparing the two tools on PDF-to-markdown conversion quality, using published benchmarks, community discussions, and real-world evaluations. The goal is to validate whether pymupdf should replace markitdown as the primary PDF extraction tool in the filetypes extension's document-agent.

## Findings

### 1. Element-by-Element Quality Comparison

| Feature | PyMuPDF4LLM | MarkItDown |
|---------|-------------|------------|
| Headings | Correctly mapped to markdown levels | Lost -- plain text output |
| Bold/italic | Properly preserved | Lost |
| Tables | Partial (GFM tables; fails on borderless) | Catastrophic -- extracts one column at a time, "jumbled list of text" |
| Multi-column layouts | Preserves reading order | No layout analysis |
| Images | Optional extraction (`write_images=True`) | No support |
| URLs/hyperlinks | Extracted (scope sometimes too broad) | Not preserved |
| OCR (scanned PDFs) | Auto-detects and applies when needed | Not supported |
| Lists | Top-level ordered lists work; nested/unordered fail | Lost |
| Code blocks | Converted but language specifier lost | Lost |
| Headers/footers | Detected and separated | Not distinguished from body text |

### 2. MarkItDown's Known PDF Deficiencies

- GitHub issue #164 ("PDF to markdown is not good") -- 7 upvotes, marked duplicate of #131 ("Create advanced PDF convertor")
- GitHub issue #1117 -- "Not converting as expected"
- GitHub issue #1276 -- PDFMiner backend performance complaints
- Systenics AI benchmark: rated "Failed" for table handling and structure preservation
- Users report `(cid:NNN)` encoding garbling on certain character mappings
- PDFMiner backend is synchronous and slow on large files

### 3. PyMuPDF4LLM's Known Limitations

- Borderless tables treated as plain text (no ML-based table detection)
- Nested and unordered lists not accurately converted
- Link scope sometimes too broad (entire line becomes a link)
- Code block language specifiers lost
- No mathematical formula recognition
- Layout analysis less sophisticated than ML-based tools (Marker, Docling, MinerU)

### 4. Published Benchmark Results

- **Systenics AI (2025)**: Tested MarkItDown against Docling and Mistral. MarkItDown rated "Failed" for both table handling and structure preservation.
- **DEV Community (ashokan)**: Tested 8 tools across 10 criteria. PyMuPDF4LLM scored better than MarkItDown on structure preservation and markdown output quality.
- **DEV Community (m_sea_bass)**: Detailed element-by-element testing of PyMuPDF4LLM confirms headers and basic formatting work well.
- **TheMenunLab (2026)**: Ranked PyMuPDF4LLM as fastest option for native PDFs with no ML overhead. Recommended as a "try first" tool.

### 5. Best-in-Class Alternatives (for reference)

For complex PDFs where even PyMuPDF4LLM falls short:

| Tool | Strengths | Trade-offs |
|------|-----------|------------|
| Marker | Best general-purpose; ML-based layout detection | Requires GPU for speed; heavier dependency |
| Docling (IBM) | Best for RAG pipelines with tables | Slower; more complex setup |
| MinerU | Best for CJK and complex layouts | Heaviest resource requirements |

### 6. Format-Specific Tool Strengths

| Format | Best Tool | Notes |
|--------|-----------|-------|
| PDF | PyMuPDF4LLM | Structure, tables, OCR |
| DOCX | MarkItDown | Native support, good quality |
| PPTX | MarkItDown | Slide-aware extraction |
| XLSX | MarkItDown | Tabular data preserved |
| HTML | MarkItDown or Pandoc | Both capable |
| EPUB | Pandoc | Best native support |
| Images (OCR) | PyMuPDF4LLM | Auto-detects need for OCR |

## Decisions

- PyMuPDF4LLM confirmed as the correct choice for primary PDF extraction tool in the document-agent.
- MarkItDown should be retained as a secondary/fallback for PDFs and as primary for non-PDF document formats (DOCX, PPTX, XLSX).
- No need to invest in Marker or Docling integration at this time -- PyMuPDF4LLM is sufficient for the use cases in this project.
- pymupdf4llm should be installed (`pip install pymupdf4llm`) to get the LLM-optimized markdown output layer.

## Recommendations

1. **Primary action**: Proceed with task 384 plan -- make pymupdf the primary PDF tool in document-agent
2. **Format-aware routing**: Document-agent should select tools by input format:
   - PDF -> pymupdf4llm (primary), markitdown CLI (fallback)
   - DOCX/PPTX/XLSX -> markitdown (primary), pandoc (fallback)
   - HTML -> markitdown or pandoc
3. **Install pymupdf4llm**: Add to project dependencies for LLM-optimized markdown output
4. **Future consideration**: If complex PDF quality becomes insufficient, evaluate Marker as an upgrade path

## Risks & Mitigations

- **Risk**: pymupdf4llm is not currently installed
  - **Mitigation**: `pip install pymupdf4llm` or add to Nix configuration; pymupdf (base) is already installed and functional
- **Risk**: PyMuPDF4LLM still fails on borderless tables
  - **Mitigation**: Acceptable for current use cases; Marker/Docling available as future upgrade if needed

## Appendix

### Sources

- DEV Community: Evaluating Document Parsers for Air-Gapped RAG Systems -- https://dev.to/ashokan/from-pdfs-to-markdown-evaluating-document-parsers-for-air-gapped-rag-systems-58eh
- DEV Community: PyMuPDF4LLM Evaluation -- https://dev.to/m_sea_bass/how-to-convert-pdfs-to-markdown-using-pymupdf4llm-and-its-evaluation-kg6
- Systenics AI: PDF to Markdown Conversion Tools -- https://systenics.ai/blog/2025-07-28-pdf-to-markdown-conversion-tools/
- TheMenunLab: Best Open-Source PDF-to-Markdown Tools 2026 -- https://themenonlab.blog/blog/best-open-source-pdf-to-markdown-tools-2026
- Jimmy Song: PDF to Markdown Deep Dive -- https://jimmysong.io/blog/pdf-to-markdown-open-source-deep-dive/
- GitHub MarkItDown Issue #164 -- https://github.com/microsoft/markitdown/issues/164
- Artifex: RAG/LLM and PDF Conversion -- https://artifex.com/blog/rag-llm-and-pdf-conversion-to-markdown-text-with-pymupdf
