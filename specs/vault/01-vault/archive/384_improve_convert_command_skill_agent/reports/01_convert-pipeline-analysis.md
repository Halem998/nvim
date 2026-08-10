# Research Report: Task #384

**Task**: 384 - Improve /convert command-skill-agent
**Started**: 2026-04-09T12:00:00Z
**Completed**: 2026-04-09T12:30:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration (filetypes extension files)
- System tool availability checks (markitdown, pymupdf, pandoc)
- .claude/ architecture patterns (command-skill-agent chains)
- Agent frontmatter standard documentation
**Artifacts**:
- `specs/384_improve_convert_command_skill_agent/reports/01_convert-pipeline-analysis.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The markitdown CLI is broken due to a stale Python venv pointing to a garbage-collected Nix store path (Python 3.12.12 -> 3.12.13 upgrade); neither the CLI nor the Python import works
- PyMuPDF (v1.27.1) is installed and fully functional for PDF text extraction, table detection, and annotation scraping; it should become the primary PDF extraction backend
- PyMuPDF cannot handle Office formats (.docx, .xlsx, .pptx, .html); pandoc (v3.7.0.2) is available and should serve as fallback for those formats
- The document-agent currently lists markitdown as primary tool for all conversions; this needs restructuring into format-specific tool chains
- The scrape-agent already uses PyMuPDF as primary tool and follows good patterns; document-agent should be aligned to match
- Tool detection, conversion tables, and dependency guide all need updates to add pymupdf and restructure the fallback chains

## Context & Scope

This research examines the /convert command pipeline in the filetypes extension to understand the current architecture, identify the broken markitdown integration, and recommend how to refactor using pymupdf as the primary PDF extraction backend while maintaining support for non-PDF formats.

### Scope boundaries
- /convert command, skill-filetypes, filetypes-router-agent, document-agent
- Tool detection patterns and conversion tables
- Does NOT cover /table, /slides, or /scrape (those work independently)
- Does NOT implement fixes (that is the plan/implement phase)

## Findings

### Current Architecture

The /convert pipeline follows a 4-layer command-skill-agent chain:

```
/convert (command) -> skill-filetypes (skill) -> filetypes-router-agent (agent) -> document-agent (agent)
```

**Files involved**:
- Command: `.claude/extensions/filetypes/commands/convert.md`
- Skill: `.claude/extensions/filetypes/skills/skill-filetypes/SKILL.md`
- Router: `.claude/extensions/filetypes/agents/filetypes-router-agent.md`
- Document agent: `.claude/extensions/filetypes/agents/document-agent.md`
- Tool detection: `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md`
- Conversion tables: `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md`
- Dependency guide: `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md`
- MCP integration: `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md`
- Index entries: `.claude/extensions/filetypes/index-entries.json`
- Manifest: `.claude/extensions/filetypes/manifest.json`
- Extension CLAUDE.md section: `.claude/extensions/filetypes/EXTENSION.md`

### Broken Markitdown Analysis

**Root cause**: The markitdown wrapper script at `/home/benjamin/.nix-profile/bin/markitdown` creates a Python venv at `~/.local/share/markitdown-venv/`. The venv's Python symlink points to a garbage-collected Nix store path:

```
~/.local/share/markitdown-venv/bin/python ->
  /nix/store/m01y682x250mxwplhra4cgd66v889gf4-python3-3.12.12-env/bin/python  [DEAD]
```

The wrapper script itself references a newer path:
```
/nix/store/fgw5v87z96qmbqa7sgpkkd8p0dfawwjy-python3-3.12.13-env/bin/python  [EXISTS]
```

**Impact**: Both `markitdown` CLI and `import markitdown` fail. The tool is completely non-functional.

**Fix**: Delete the stale venv directory (`rm -rf ~/.local/share/markitdown-venv`), then re-run `markitdown` which will recreate it with the current Python. However, this is a NixOS-specific fragility issue that will recur on every Python version bump.

### PyMuPDF Capabilities (v1.27.1)

PyMuPDF is installed and working. Key capabilities for document conversion:

**Text extraction** (PDF primary use case):
- `page.get_text("text")` - Plain text extraction
- `page.get_text("dict")` - Structured dict with layout/font info
- `page.get_text("html")` - HTML output with formatting
- `page.get_text("blocks")` - Text blocks with positions
- `page.get_text("words")` - Word-level extraction with positions

**Table detection**:
- `page.find_tables()` - Automatic table detection (v1.23+, available)

**Image extraction**:
- `page.get_images()` - List embedded images
- `doc.extract_image(xref)` - Extract image data

**OCR support**:
- `page.get_textpage_ocr()` - OCR via Tesseract (if installed)

**Supported input formats**: PDF, EPUB, XPS, CBZ, FB2, MOBI, SVG

**NOT supported**: .docx, .xlsx, .pptx, .html (Office/web formats)

### Available System Tools

| Tool | Status | Version | Path |
|------|--------|---------|------|
| markitdown CLI | BROKEN (bad interpreter) | N/A | `~/.nix-profile/bin/markitdown` |
| markitdown Python | BROKEN (not importable) | N/A | N/A |
| pymupdf | Working | 1.27.1 | Python package |
| pymupdf4llm | Not installed | N/A | N/A |
| pandoc | Working | 3.7.0.2 | `/run/current-system/sw/bin/pandoc` |
| typst | Likely working | (not checked) | Nix |

### Scrape Agent as Reference Pattern

The scrape-agent (`.claude/extensions/filetypes/agents/scrape-agent.md`) already uses PyMuPDF as its primary tool and follows good patterns:

- PyMuPDF is listed as primary, with pypdf and pdfannots as fallbacks
- Tool detection uses `python3 -c "import fitz"` pattern
- Structured JSON return format
- Clear error handling for each failure mode
- The annotation extraction code is well-structured and tested

The document-agent should be refactored to follow the same pattern for PDF text extraction.

### Document Agent Issues

Current document-agent problems:
1. Lists markitdown as primary tool for ALL conversions (PDF, DOCX, HTML, images)
2. No mention of pymupdf at all
3. Fallback to pandoc only - but pandoc has limited PDF text extraction
4. Tool detection only checks `command -v markitdown` (CLI), not Python import
5. No table detection capability
6. No structured text extraction (just raw markitdown pipe)

### Conversion Table Analysis

Current conversion-tables.md lists:

| Source | Primary | Fallback |
|--------|---------|----------|
| PDF -> Markdown | markitdown | pandoc |
| DOCX -> Markdown | markitdown | pandoc |
| HTML -> Markdown | markitdown | pandoc |
| Images -> Markdown | markitdown | - |
| Markdown -> PDF | pandoc | typst |

**Recommended new table**:

| Source | Primary | Fallback 1 | Fallback 2 |
|--------|---------|-----------|-----------|
| PDF -> Markdown | pymupdf | pandoc | markitdown (if fixed) |
| DOCX -> Markdown | pandoc | markitdown (if fixed) | - |
| HTML -> Markdown | pandoc | markitdown (if fixed) | - |
| Images -> Markdown | pymupdf (OCR) | markitdown (if fixed) | - |
| Markdown -> PDF | pandoc | typst | - |
| EPUB -> Markdown | pymupdf | pandoc | - |

### Architecture Conformance

Comparing the /convert chain against the /scrape chain (which was more recently implemented and better aligned):

| Aspect | /scrape (reference) | /convert (current) | Gap |
|--------|--------------------|--------------------|-----|
| Agent frontmatter | Has name, description | Has name, description | OK |
| Model field | Not specified | Not specified | OK (implementation agents) |
| Tool detection ref | References tool-detection.md | References tool-detection.md | OK |
| PyMuPDF usage | Primary tool | Not mentioned | CRITICAL |
| Fallback chain | pymupdf -> pypdf -> pdfannots | markitdown -> pandoc | Needs update |
| Python extraction code | Inline Python via Bash | markitdown CLI pipe | Needs restructure |
| Return format | Matches subagent-return.md | Matches subagent-return.md | OK |
| Error handling | Comprehensive (5 error types) | Comprehensive (4 error types) | OK |

### Context Files Needing Updates

1. **tool-detection.md** - No pymupdf detection for text extraction (only checked for /scrape annotations). Need to add:
   - `has_pymupdf` in CLI/Python detection
   - Document conversion fallback chain update
   - pymupdf4llm as optional enhancement

2. **conversion-tables.md** - All document conversion rows list markitdown as primary. Need complete restructuring.

3. **dependency-guide.md** - pymupdf not listed as a document conversion dependency. Only listed for /scrape.

4. **mcp-integration.md** - Mentions markitdown-mcp but not pymupdf. May need update if pymupdf MCP server exists.

5. **index-entries.json** - No changes needed (agents already listed for /convert context files).

## Decisions

- PyMuPDF should be the primary tool for PDF -> Markdown extraction
- Pandoc should be the primary tool for DOCX/HTML -> Markdown (since pymupdf cannot handle these)
- Markitdown should be demoted to a fallback option, not removed entirely (it may be fixed in the future)
- The broken markitdown venv issue should be documented as a known NixOS fragility, with a fix recommendation (delete and recreate venv)
- pymupdf4llm (not currently installed) could be recommended as an optional enhancement for better markdown output from PDFs
- The document-agent needs a format-aware tool selection tree (not a single primary tool for all formats)

## Recommendations

### Priority 1: Restructure document-agent tool selection (Critical)

Implement format-aware tool selection in document-agent:

```
PDF -> Markdown:
  1. pymupdf (python3 -c "import fitz")
  2. pandoc (command -v pandoc)
  3. markitdown (if available)

DOCX -> Markdown:
  1. pandoc
  2. markitdown (if available)

HTML -> Markdown:
  1. pandoc
  2. markitdown (if available)

Images -> Markdown:
  1. pymupdf with OCR (if tesseract available)
  2. markitdown (if available)

Markdown -> PDF:
  1. pandoc
  2. typst
```

### Priority 2: Add pymupdf text extraction code to document-agent

Add inline Python extraction similar to scrape-agent's pattern:

```python
import fitz, sys
doc = fitz.open(sys.argv[1])
for page in doc:
    text = page.get_text("text")
    # or use get_text("dict") for structured output
    print(text)
doc.close()
```

For better markdown output, consider table detection:
```python
tables = page.find_tables()
for table in tables:
    # Format as markdown table
```

### Priority 3: Update tool-detection.md

Add pymupdf to the document conversion tool detection section (currently only in annotation extraction context).

### Priority 4: Update conversion-tables.md

Restructure to reflect new tool priorities with pymupdf as primary for PDF.

### Priority 5: Update dependency-guide.md

Add pymupdf to the document conversion dependencies section.

### Priority 6: Fix markitdown venv (separate concern)

Document the fix: `rm -rf ~/.local/share/markitdown-venv && markitdown --version` to recreate with current Python. This is a NixOS maintenance issue, not a /convert architecture issue.

### Optional: Install pymupdf4llm

`pip install pymupdf4llm` provides `pymupdf4llm.to_markdown()` which produces higher quality markdown output from PDFs than raw text extraction. Could be added as an optional enhancement.

## Risks & Mitigations

- **Risk**: pymupdf4llm not installed, so PDF-to-markdown quality may be lower than markitdown was
  - **Mitigation**: pymupdf's `get_text("text")` with `find_tables()` can produce good markdown; recommend pymupdf4llm installation as optional enhancement

- **Risk**: Removing markitdown as primary breaks any workflows expecting markitdown-specific output format
  - **Mitigation**: markitdown is currently broken anyway; no workflows depend on it right now

- **Risk**: DOCX conversion quality may vary between pandoc and markitdown
  - **Mitigation**: pandoc is a mature, well-maintained tool; it handles DOCX well

- **Risk**: NixOS venv fragility will recur for any Python-based tool using venvs
  - **Mitigation**: Document the pattern; consider using `nix-shell` wrappers instead of venvs for Nix-managed Python

## Appendix

### Files examined
- `.claude/extensions/filetypes/commands/convert.md` (259 lines)
- `.claude/extensions/filetypes/skills/skill-filetypes/SKILL.md` (189 lines)
- `.claude/extensions/filetypes/agents/filetypes-router-agent.md` (239 lines)
- `.claude/extensions/filetypes/agents/document-agent.md` (341 lines)
- `.claude/extensions/filetypes/agents/scrape-agent.md` (519 lines) - reference pattern
- `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md` (166 lines)
- `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` (118 lines)
- `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md` (298 lines)
- `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` (213 lines)
- `.claude/extensions/filetypes/manifest.json` (50 lines)
- `.claude/extensions/filetypes/EXTENSION.md` (23 lines)
- `.claude/extensions/filetypes/index-entries.json` (185 lines)
- `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md` (203 lines)
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` (60 lines)

### Tool availability verification
```
markitdown CLI: BROKEN (bad interpreter - stale venv)
markitdown Python: BROKEN (not importable)
pymupdf: v1.27.1 (working)
pymupdf4llm: NOT INSTALLED
pandoc: v3.7.0.2 (working)
python3: 3.12.13 (working)
```

### Broken markitdown diagnosis
```
Wrapper: /home/benjamin/.nix-profile/bin/markitdown
Venv: ~/.local/share/markitdown-venv/
Dead symlink: bin/python -> /nix/store/m01y682x250mxwplhra4cgd66v889gf4-python3-3.12.12-env/bin/python
Current Python: /nix/store/fgw5v87z96qmbqa7sgpkkd8p0dfawwjy-python3-3.12.13-env/bin/python
Fix: rm -rf ~/.local/share/markitdown-venv && markitdown --version
```
