# Implementation Plan: Expand Document Converter to Filetypes Extension

- **Task**: 122 - Expand Document Converter to Filetypes Extension
- **Status**: [NOT STARTED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Rename the existing `document-converter` extension to `filetypes` and expand it with specialized sub-agents for spreadsheet operations (Excel/CSV/ODS), presentation operations (PowerPoint/Beamer/Polylux/Touying), and general document operations (PDF/DOCX/Markdown). The architecture follows Option B (Specialized Sub-Agents) from the research report, adding a router agent that delegates to domain-specific agents. New `/table` and `/slides` commands provide targeted entry points for spreadsheet-to-table and presentation conversion workflows. Context files document conversion pipelines and tool dependencies for each filetype domain.

### Research Integration

Key findings from research-001.md integrated into this plan:
- **Option B architecture**: Router agent + 3 specialized sub-agents (spreadsheet, presentation, document)
- **Tool ecosystems**: pandas/openpyxl for Excel, python-pptx for PowerPoint, pandoc for Beamer, Polylux/Touying for Typst slides
- **Phased conversion priorities**: Core extraction (Phase 1) -> Academic slides (Phase 2) -> Round-trip (Phase 3)
- **MCP server availability**: markitdown-mcp, mcp-pandoc, md-converter for environments with MCP support
- **Bidirectional flows**: Office-to-academic and academic-to-office pipelines

## Goals & Non-Goals

**Goals**:
- Rename `document-converter` extension to `filetypes` with updated manifest and merge targets
- Create router agent (`filetypes-router-agent`) that dispatches to specialized sub-agents
- Create `spreadsheet-agent` for Excel/CSV/ODS to LaTeX/Typst table conversion
- Create `presentation-agent` for PowerPoint to Beamer/Polylux/Touying conversion
- Preserve existing `document-agent` functionality (current document-converter-agent, renamed)
- Add `/table` and `/slides` commands for targeted conversion workflows
- Create context files documenting spreadsheet-table and presentation-slide conversion patterns
- Document all software dependencies with installation instructions
- Integrate with existing LaTeX and Typst extensions as a bridge

**Non-Goals**:
- Implementing round-trip (academic-to-office) conversions in this task (future Phase 3 work)
- Creating MCP server wrappers (leverage existing MCP servers when available, CLI fallback)
- Modifying the LaTeX or Typst extensions themselves (this extension complements them)
- Supporting ODP (LibreOffice Impress) as a primary format
- Automated citation/bibliography handling during conversion

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Heavy Python dependencies (pandas, openpyxl, python-pptx) add installation complexity | Medium | High | Make each dependency group optional with clear error messages; use pip extras groups |
| Lossy PPTX to Beamer conversion loses layout fidelity | Medium | High | Set clear expectations in agent docs; focus on content preservation over layout |
| Typst slide packages (Polylux/Touying) have evolving APIs | Medium | Medium | Abstract slide generation behind agent layer; easy to update agent without changing skill/command |
| Renaming extension may break existing references | Low | Low | Grep for all `document-converter` references and update atomically in Phase 1 |
| Router agent adds dispatch latency | Low | Low | Router is thin (format detection + delegation); negligible overhead |

## Implementation Phases

### Phase 1: Rename Extension and Create Router Architecture [NOT STARTED]

**Goal:** Rename `document-converter` to `filetypes`, update all references, and create the router agent that dispatches to specialized sub-agents.

**Tasks:**
- [ ] Create new `extensions/filetypes/` directory structure mirroring the extension layout
- [ ] Create `manifest.json` with updated name, description, and expanded `provides` section
- [ ] Create `EXTENSION.md` with updated skill-agent mapping table and supported conversions
- [ ] Create `index-entries.json` with context file entries for the filetypes extension
- [ ] Create `filetypes-router-agent.md` with format detection and delegation logic
- [ ] Rename and adapt `document-converter-agent.md` to `document-agent.md` (preserve existing PDF/DOCX/Markdown/HTML/Image conversion)
- [ ] Create `skill-filetypes/SKILL.md` as the primary routing skill (replaces skill-document-converter)
- [ ] Update `/convert` command to delegate through the new skill-filetypes
- [ ] Remove old `extensions/document-converter/` directory
- [ ] Grep codebase for remaining `document-converter` references and update

**Timing:** 1.5-2 hours

**Files to create/modify:**
- `.claude/extensions/filetypes/manifest.json` - New extension manifest
- `.claude/extensions/filetypes/EXTENSION.md` - Extension documentation for CLAUDE.md merge
- `.claude/extensions/filetypes/index-entries.json` - Context index entries
- `.claude/extensions/filetypes/agents/filetypes-router-agent.md` - Router agent definition
- `.claude/extensions/filetypes/agents/document-agent.md` - Renamed from document-converter-agent.md
- `.claude/extensions/filetypes/skills/skill-filetypes/SKILL.md` - Primary routing skill
- `.claude/extensions/filetypes/commands/convert.md` - Updated /convert command

**Verification:**
- Extension directory structure matches manifest declarations
- `/convert` command flow works: command -> skill-filetypes -> filetypes-router-agent -> document-agent
- No remaining references to `document-converter` in the codebase
- Manifest `merge_targets` use `extension_filetypes` section_id

---

### Phase 2: Create Spreadsheet Agent and /table Command [NOT STARTED]

**Goal:** Add the spreadsheet-agent for Excel/CSV/ODS to LaTeX/Typst table conversion, along with the `/table` command and spreadsheet conversion context documentation.

**Tasks:**
- [ ] Create `spreadsheet-agent.md` with conversion pipelines:
  - XLSX/CSV -> pandas DataFrame -> `to_latex(booktabs=True)` -> .tex
  - XLSX/CSV -> xlsx2csv/pandas -> CSV -> Typst `csv()` function -> .typ table
  - XLSX -> openpyxl (full feature access, preserves styles) -> DataFrame
  - Tool fallback chain: pandas (primary) -> xlsx2csv + csv2latex (fallback) -> markitdown (basic fallback)
- [ ] Create `skill-spreadsheet/SKILL.md` with trigger conditions for spreadsheet operations
- [ ] Create `/table` command (`commands/table.md`) with checkpoint-based execution:
  - Arguments: SOURCE_PATH [OUTPUT_PATH] [--format latex|typst|markdown]
  - Default: infer output format from extension or default to LaTeX
  - Support: XLSX, XLS, CSV, ODS input formats
- [ ] Create context file `context/project/filetypes/patterns/spreadsheet-tables.md` documenting:
  - pandas DataFrame.to_latex() booktabs patterns
  - Typst CSV import and tabut package usage
  - rexllent and spreet Typst package patterns
  - Multi-sheet workbook handling
  - Column formatting and alignment options
- [ ] Update `manifest.json` to include spreadsheet-agent, skill-spreadsheet, and /table command
- [ ] Update `EXTENSION.md` with spreadsheet conversion table
- [ ] Update `index-entries.json` with spreadsheet context entries
- [ ] Update router agent to dispatch spreadsheet formats to spreadsheet-agent

**Timing:** 1.5-2 hours

**Files to create/modify:**
- `.claude/extensions/filetypes/agents/spreadsheet-agent.md` - Spreadsheet conversion agent
- `.claude/extensions/filetypes/skills/skill-spreadsheet/SKILL.md` - Spreadsheet routing skill
- `.claude/extensions/filetypes/commands/table.md` - /table command
- `.claude/extensions/filetypes/context/project/filetypes/patterns/spreadsheet-tables.md` - Conversion patterns
- `.claude/extensions/filetypes/manifest.json` - Updated with new components
- `.claude/extensions/filetypes/EXTENSION.md` - Updated documentation
- `.claude/extensions/filetypes/index-entries.json` - Updated index entries
- `.claude/extensions/filetypes/agents/filetypes-router-agent.md` - Updated dispatch rules

**Verification:**
- Spreadsheet agent handles XLSX, CSV, ODS input formats
- Agent detects installed tools (pandas, openpyxl, xlsx2csv) and uses best available
- `/table` command validates inputs and delegates through skill-spreadsheet
- Context file covers all recommended pipelines from research
- Router agent correctly dispatches spreadsheet extensions to spreadsheet-agent

---

### Phase 3: Create Presentation Agent and /slides Command [NOT STARTED]

**Goal:** Add the presentation-agent for PowerPoint extraction and Beamer/Polylux/Touying slide generation, along with the `/slides` command and presentation conversion context documentation.

**Tasks:**
- [ ] Create `presentation-agent.md` with conversion pipelines:
  - PPTX -> python-pptx/markitdown (extract text, images, speaker notes) -> Structured Markdown
  - Structured Markdown -> pandoc -t beamer -> .tex Beamer slides
  - Structured Markdown -> Agent-assisted Typst generation (Polylux or Touying format)
  - Markdown -> pandoc -> PPTX (for sharing with non-LaTeX colleagues)
  - Image extraction pipeline: python-pptx -> embedded images saved alongside content
  - Tool fallback chain: python-pptx (primary) -> markitdown (fallback) for extraction
- [ ] Create `skill-presentation/SKILL.md` with trigger conditions for presentation operations
- [ ] Create `/slides` command (`commands/slides.md`) with checkpoint-based execution:
  - Arguments: SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying|pptx]
  - Default: infer output format from extension or default to Beamer
  - Support: PPTX input, Beamer/Polylux/Touying/PPTX output
- [ ] Create context file `context/project/filetypes/patterns/presentation-slides.md` documenting:
  - python-pptx extraction patterns (text, images, notes, tables)
  - pandoc Beamer generation from Markdown
  - Polylux slide syntax and theme application
  - Touying slide syntax and theme application
  - Speaker notes handling across formats
  - Image extraction and cross-reference patterns
- [ ] Update `manifest.json` to include presentation-agent, skill-presentation, and /slides command
- [ ] Update `EXTENSION.md` with presentation conversion table
- [ ] Update `index-entries.json` with presentation context entries
- [ ] Update router agent to dispatch presentation formats to presentation-agent

**Timing:** 1.5-2 hours

**Files to create/modify:**
- `.claude/extensions/filetypes/agents/presentation-agent.md` - Presentation conversion agent
- `.claude/extensions/filetypes/skills/skill-presentation/SKILL.md` - Presentation routing skill
- `.claude/extensions/filetypes/commands/slides.md` - /slides command
- `.claude/extensions/filetypes/context/project/filetypes/patterns/presentation-slides.md` - Conversion patterns
- `.claude/extensions/filetypes/manifest.json` - Updated with new components
- `.claude/extensions/filetypes/EXTENSION.md` - Updated documentation
- `.claude/extensions/filetypes/index-entries.json` - Updated index entries
- `.claude/extensions/filetypes/agents/filetypes-router-agent.md` - Updated dispatch rules

**Verification:**
- Presentation agent handles PPTX extraction with python-pptx and markitdown fallback
- Agent generates Beamer output via pandoc from structured Markdown
- Agent generates Polylux/Touying output via LLM-assisted Typst markup
- `/slides` command validates inputs and delegates through skill-presentation
- Context file covers extraction patterns, slide generation, and image handling
- Router agent correctly dispatches PPTX and slide-related requests to presentation-agent

---

### Phase 4: Dependency Documentation and Tool Detection Framework [NOT STARTED]

**Goal:** Create comprehensive dependency documentation, a unified tool detection utility, and a context README that ties all filetypes capabilities together.

**Tasks:**
- [ ] Create `context/project/filetypes/README.md` as the filetypes context index:
  - Overview of all conversion capabilities
  - Links to pattern files (spreadsheet-tables.md, presentation-slides.md)
  - Dependency installation matrix by use case
  - MCP server integration notes
- [ ] Create `context/project/filetypes/tools/dependency-guide.md` documenting all software dependencies:
  - Core: markitdown (`pip install markitdown`)
  - Spreadsheet: openpyxl, pandas, xlsx2csv (`pip install openpyxl pandas xlsx2csv`), csv2latex (`apt install csv2latex`)
  - Presentation: python-pptx (`pip install python-pptx`), markitdown[pptx] (`pip install markitdown[pptx]`)
  - LaTeX/Typst: pandoc (`apt install pandoc`), texlive-base (`apt install texlive-base`), typst (assumed via typst extension)
  - Optional: markitdown[all], beamer2pptx, gnumeric/ssconvert
  - Installation commands for NixOS, Ubuntu/Debian, macOS (Homebrew)
  - Pip extras groups for selective installation
- [ ] Create `context/project/filetypes/tools/mcp-integration.md` documenting MCP server usage:
  - markitdown-mcp for Office -> Markdown
  - mcp-pandoc for universal format conversion
  - md-converter for Markdown -> DOCX/XLSX/PPTX
  - CLI fallback patterns when MCP unavailable
- [ ] Add tool detection helper patterns to each agent (or a shared section in router agent):
  - `command -v` checks for CLI tools
  - Python import checks for pip packages
  - Version detection for compatibility
  - Clear error messages with installation instructions per platform
- [ ] Update all three specialized agents with consistent tool detection sections
- [ ] Final update to `EXTENSION.md` with complete conversion matrix and dependency table

**Timing:** 1-1.5 hours

**Files to create/modify:**
- `.claude/extensions/filetypes/context/project/filetypes/README.md` - Context index
- `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md` - Dependency documentation
- `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` - MCP server documentation
- `.claude/extensions/filetypes/agents/spreadsheet-agent.md` - Updated tool detection
- `.claude/extensions/filetypes/agents/presentation-agent.md` - Updated tool detection
- `.claude/extensions/filetypes/agents/document-agent.md` - Updated tool detection
- `.claude/extensions/filetypes/agents/filetypes-router-agent.md` - Shared detection patterns
- `.claude/extensions/filetypes/EXTENSION.md` - Final comprehensive documentation

**Verification:**
- Dependency guide covers all tools from research report Section 7
- Installation commands are correct for NixOS, Ubuntu/Debian, and macOS
- MCP integration documentation covers all 4 MCP servers identified in research
- Tool detection patterns are consistent across all agents
- README links to all context files and provides clear navigation
- EXTENSION.md contains complete conversion matrix matching research Section 5

---

### Phase 5: Integration Testing and Validation [NOT STARTED]

**Goal:** Validate the complete filetypes extension structure, ensure all components are properly connected, and verify the extension can be loaded without errors.

**Tasks:**
- [ ] Validate manifest.json schema:
  - All agents listed in `provides.agents` exist as files
  - All skills listed in `provides.skills` have SKILL.md files
  - All commands listed in `provides.commands` exist as files
  - All context paths in `provides.context` exist as directories
  - merge_targets reference correct section_id
- [ ] Validate agent cross-references:
  - Router agent references correct sub-agent names
  - Sub-agent names match file names (without .md extension)
  - Skill SKILL.md files reference correct agent names
  - Command files reference correct skill names
- [ ] Validate context file completeness:
  - All context files referenced in index-entries.json exist
  - index-entries.json entries have valid paths, descriptions, and load_when conditions
  - README.md links to all sibling context files
- [ ] Validate no orphaned references to old extension:
  - `grep -r "document-converter" .claude/` returns zero results
  - `grep -r "skill-document-converter" .claude/` returns zero results
  - No stale merge targets referencing `extension_document_converter`
- [ ] Validate command flow end-to-end (structural):
  - `/convert` -> skill-filetypes -> filetypes-router-agent -> document-agent (document formats)
  - `/table` -> skill-spreadsheet -> spreadsheet-agent (spreadsheet formats)
  - `/slides` -> skill-presentation -> presentation-agent (presentation formats)
  - `/convert` -> skill-filetypes -> filetypes-router-agent -> spreadsheet-agent (XLSX detected)
  - `/convert` -> skill-filetypes -> filetypes-router-agent -> presentation-agent (PPTX detected)
- [ ] Create implementation summary

**Timing:** 0.5-1 hour

**Files to verify:**
- All files created in Phases 1-4
- `.claude/extensions/filetypes/manifest.json` - Final schema validation
- All agent, skill, command, and context files for internal consistency

**Verification:**
- Zero structural errors (all references resolve to existing files)
- Zero orphaned references to old extension name
- All three command paths (convert, table, slides) have valid delegation chains
- Manifest accurately reflects all provided components
- Extension is self-contained and ready for activation

## Testing & Validation

- [ ] Manifest schema validation: all `provides` entries correspond to existing files
- [ ] Agent reference validation: all agent names in skills and commands match agent file names
- [ ] Context link validation: all internal links in context files resolve correctly
- [ ] Old name cleanup: zero references to `document-converter` in the codebase
- [ ] Command delegation chain: each command -> skill -> agent path is structurally valid
- [ ] Dependency documentation: installation commands are syntactically correct for all platforms
- [ ] EXTENSION.md completeness: all conversion paths from research Section 5 are documented

## Artifacts & Outputs

- `plans/implementation-001.md` - This plan file
- `.claude/extensions/filetypes/` - Complete extension directory (agents, skills, commands, context)
- `summaries/implementation-summary-20260303.md` - Implementation summary upon completion

### Expected Extension Directory Structure

```
.claude/extensions/filetypes/
  manifest.json
  EXTENSION.md
  index-entries.json
  agents/
    filetypes-router-agent.md
    document-agent.md
    spreadsheet-agent.md
    presentation-agent.md
  skills/
    skill-filetypes/SKILL.md
    skill-spreadsheet/SKILL.md
    skill-presentation/SKILL.md
  commands/
    convert.md
    table.md
    slides.md
  context/
    project/filetypes/
      README.md
      patterns/
        spreadsheet-tables.md
        presentation-slides.md
      tools/
        dependency-guide.md
        mcp-integration.md
```

## Rollback/Contingency

If the renaming causes issues with existing workflows:
1. The old `extensions/document-converter/` directory can be restored from git history
2. All new files are confined to `extensions/filetypes/` -- removing this directory reverts to pre-task state
3. No core `.claude/` files outside the extensions directory are modified by this task
4. If individual sub-agents prove too granular, the router can be simplified to dispatch to a single expanded agent (Option A fallback) by updating only the router agent definition
