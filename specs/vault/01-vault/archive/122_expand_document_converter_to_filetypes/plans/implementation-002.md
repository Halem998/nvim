# Implementation Plan: Expand Document Converter to Filetypes Extension

- **Date**: 2026-03-03 (Revised)
- **Feature**: Expand document-converter extension to filetypes with specialized sub-agents for Excel and PowerPoint
- **Task**: 122 - Expand Document Converter to Filetypes Extension
- **Status**: [COMPLETED]
- **Estimated Hours**: 10-14 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Type**: meta

## Overview

Rename the existing `document-converter` extension to `filetypes` and expand it with specialized sub-agents for spreadsheet operations (Excel/CSV/ODS), presentation operations (PowerPoint/Beamer/Polylux/Touying), and general document operations (PDF/DOCX/Markdown). The architecture follows Option B (Specialized Sub-Agents) from research-001.md, adding a router agent that delegates to domain-specific agents. New `/table` and `/slides` commands provide targeted entry points for spreadsheet-to-table and presentation conversion workflows.

This revision addresses all 6 findings from research-002.md:
1. **OpenCode parity**: Both `.claude/` and `.opencode/` extensions are created in parallel
2. **Plan metadata**: Added Date, Feature, Standards File fields per the Plan Metadata Standard
3. **NixOS dependencies**: Phase 4 includes NixOS installation instructions
4. **Task 121 dependency**: Task 121 is now complete; no soft dependency required
5. **Future work tracking**: Added explicit Future Work section for typst/latex slide context
6. **Tool detection sequencing**: Option A - shared tool-detection.md created in Phase 1

### Research Integration

Key findings integrated from research-001.md and research-002.md:
- **Option B architecture**: Router agent + 3 specialized sub-agents (spreadsheet, presentation, document)
- **Tool ecosystems**: pandas/openpyxl for Excel, python-pptx for PowerPoint, pandoc for Beamer, Polylux/Touying for Typst slides
- **Dual extension systems**: Both `.claude/extensions/` and `.opencode/extensions/` require identical filetypes extension
- **Tool detection pattern**: Shared context file referenced by all agents (avoids retroactive updates)
- **NixOS-first dependencies**: Nix-shell, home-manager, and nix profile patterns alongside pip/apt

## Goals & Non-Goals

**Goals**:
- Rename `document-converter` extension to `filetypes` in BOTH `.claude/` and `.opencode/`
- Create router agent (`filetypes-router-agent`) that dispatches to specialized sub-agents
- Create `spreadsheet-agent` for Excel/CSV/ODS to LaTeX/Typst table conversion
- Create `presentation-agent` for PowerPoint to Beamer/Polylux/Touying conversion
- Preserve existing `document-agent` functionality (current document-converter-agent, renamed)
- Add `/table` and `/slides` commands for targeted conversion workflows
- Create shared tool detection context file for consistent cross-agent tool discovery
- Create context files documenting spreadsheet-table and presentation-slide conversion patterns
- Document all software dependencies with NixOS, Ubuntu/Debian, and macOS instructions

**Non-Goals**:
- Implementing round-trip (academic-to-office) conversions in this task (see Future Work)
- Creating MCP server wrappers (leverage existing MCP servers when available, CLI fallback)
- Modifying the LaTeX or Typst extensions themselves (see Future Work for slide context files)
- Supporting ODP (LibreOffice Impress) as a primary format
- Automated citation/bibliography handling during conversion

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Heavy Python dependencies (pandas, openpyxl, python-pptx) add installation complexity | Medium | High | Provide NixOS-first instructions; make each dependency group optional with clear error messages |
| Lossy PPTX to Beamer conversion loses layout fidelity | Medium | High | Set clear expectations in agent docs; focus on content preservation over layout |
| Typst slide packages (Polylux/Touying) have evolving APIs | Medium | Medium | Abstract slide generation behind agent layer; easy to update agent without changing skill/command |
| Renaming extension may break existing references | Low | Low | Grep for all `document-converter` references in BOTH systems and update atomically |
| Dual extension maintenance burden | Medium | Medium | Create `.opencode/` files via mechanical translation from `.claude/` counterparts |

## Implementation Phases

### Phase 1: Foundation - Router Architecture and Tool Detection [COMPLETED]

**Goal**: Rename `document-converter` to `filetypes` in both extension systems, create the router agent architecture, and establish the shared tool detection context file.

**Prerequisites**: Task 121 completed (extension-specific skills removed from core directories).

**Tasks**:

**1.1 Create Shared Tool Detection Context** (Option A from research-002.md):
- [ ] Create `context/project/filetypes/tools/tool-detection.md` with standard detection patterns:
  - `command -v` checks for CLI tools (pandoc, typst, pdflatex)
  - Python import checks for pip packages (pandas, openpyxl, python-pptx, markitdown)
  - Version detection patterns for compatibility checks
  - Platform-specific installation instructions (NixOS, apt, brew)
  - Error message templates with installation guidance
- [ ] Include tool fallback chain documentation (primary -> fallback -> basic fallback)

**1.2 Create `.claude/extensions/filetypes/` Directory Structure**:
- [ ] Create `manifest.json` with updated name, description, and expanded `provides` section
- [ ] Create `EXTENSION.md` with updated skill-agent mapping table and supported conversions
- [ ] Create `index-entries.json` with context file entries including tool-detection.md
- [ ] Create `filetypes-router-agent.md` with format detection and delegation logic
- [ ] Rename and adapt `document-converter-agent.md` to `document-agent.md`
- [ ] Create `skill-filetypes/SKILL.md` as the primary routing skill
- [ ] Update `/convert` command to delegate through the new skill-filetypes
- [ ] Remove old `.claude/extensions/document-converter/` directory

**1.3 Create `.opencode/extensions/filetypes/` Directory Structure** (parity):
- [ ] Mechanical translation of all Phase 1.2 files to `.opencode/` format
- [ ] Create `manifest.json` with OpenCode-compatible schema
- [ ] Create `EXTENSION.md` for OpenCode merge
- [ ] Create `index-entries.json` with OpenCode paths
- [ ] Create all agents, skills, commands matching `.claude/` structure
- [ ] Remove old `.opencode/extensions/document-converter/` directory

**1.4 Reference Cleanup**:
- [ ] `grep -r "document-converter" .claude/` - update all references
- [ ] `grep -r "document-converter" .opencode/` - update all references
- [ ] Verify no stale `skill-document-converter` references exist

**Timing**: 2.5-3 hours

**Files to create/modify**:
```
.claude/extensions/filetypes/
  manifest.json
  EXTENSION.md
  index-entries.json
  agents/filetypes-router-agent.md
  agents/document-agent.md
  skills/skill-filetypes/SKILL.md
  commands/convert.md
  context/project/filetypes/tools/tool-detection.md

.opencode/extensions/filetypes/
  [mirror of above structure]
```

**Verification**:
- Both extension directory structures match manifest declarations
- `/convert` command flow works in both systems
- Zero remaining references to `document-converter` in either codebase
- tool-detection.md contains patterns for all tools from research-001.md Section 7

---

### Phase 2: Spreadsheet Agent and /table Command [COMPLETED]

**Goal**: Add the spreadsheet-agent for Excel/CSV/ODS to LaTeX/Typst table conversion, along with the `/table` command and spreadsheet conversion context documentation.

**Tasks**:

**2.1 Create Spreadsheet Agent** (references tool-detection.md):
- [ ] Create `spreadsheet-agent.md` in `.claude/extensions/filetypes/agents/`:
  - Reference `@context/project/filetypes/tools/tool-detection.md` for tool availability
  - XLSX/CSV -> pandas DataFrame -> `to_latex(booktabs=True)` -> .tex
  - XLSX/CSV -> xlsx2csv/pandas -> CSV -> Typst `csv()` function -> .typ table
  - XLSX -> openpyxl (full feature access, preserves styles) -> DataFrame
  - Tool fallback chain: pandas (primary) -> xlsx2csv + csv2latex (fallback) -> markitdown (basic)
- [ ] Create `skill-spreadsheet/SKILL.md` with trigger conditions for spreadsheet operations
- [ ] Create `/table` command (`commands/table.md`):
  - Arguments: SOURCE_PATH [OUTPUT_PATH] [--format latex|typst|markdown]
  - Default: infer output format from extension or default to LaTeX
  - Support: XLSX, XLS, CSV, ODS input formats

**2.2 Create Spreadsheet Context Documentation**:
- [ ] Create `context/project/filetypes/patterns/spreadsheet-tables.md`:
  - pandas DataFrame.to_latex() booktabs patterns
  - Typst CSV import and tabut package usage
  - rexllent and spreet Typst package patterns
  - Multi-sheet workbook handling
  - Column formatting and alignment options

**2.3 Update Extension Metadata**:
- [ ] Update `manifest.json` to include spreadsheet-agent, skill-spreadsheet, /table command
- [ ] Update `EXTENSION.md` with spreadsheet conversion table
- [ ] Update `index-entries.json` with spreadsheet context entries
- [ ] Update router agent to dispatch spreadsheet formats to spreadsheet-agent

**2.4 OpenCode Parity**:
- [ ] Mechanical translation of all Phase 2.1-2.3 files to `.opencode/extensions/filetypes/`

**Timing**: 2-2.5 hours

**Files to create/modify**:
```
.claude/extensions/filetypes/
  agents/spreadsheet-agent.md
  skills/skill-spreadsheet/SKILL.md
  commands/table.md
  context/project/filetypes/patterns/spreadsheet-tables.md
  manifest.json (updated)
  EXTENSION.md (updated)
  index-entries.json (updated)
  agents/filetypes-router-agent.md (updated)

.opencode/extensions/filetypes/
  [mirror of above changes]
```

**Verification**:
- Spreadsheet agent references tool-detection.md (no embedded detection logic)
- Agent handles XLSX, CSV, ODS input formats with proper fallback chains
- `/table` command validates inputs and delegates through skill-spreadsheet
- Context file covers all recommended pipelines from research-001.md
- OpenCode extension matches Claude extension functionality

---

### Phase 3: Presentation Agent and /slides Command [COMPLETED]

**Goal**: Add the presentation-agent for PowerPoint extraction and Beamer/Polylux/Touying slide generation, along with the `/slides` command and presentation conversion context documentation.

**Tasks**:

**3.1 Create Presentation Agent** (references tool-detection.md):
- [ ] Create `presentation-agent.md` in `.claude/extensions/filetypes/agents/`:
  - Reference `@context/project/filetypes/tools/tool-detection.md` for tool availability
  - PPTX -> python-pptx/markitdown (extract text, images, speaker notes) -> Structured Markdown
  - Structured Markdown -> pandoc -t beamer -> .tex Beamer slides
  - Structured Markdown -> Agent-assisted Typst generation (Polylux or Touying format)
  - Markdown -> pandoc -> PPTX (for sharing with non-LaTeX colleagues)
  - Image extraction pipeline: python-pptx -> embedded images saved alongside content
  - Tool fallback chain: python-pptx (primary) -> markitdown (fallback)
- [ ] Create `skill-presentation/SKILL.md` with trigger conditions for presentation operations
- [ ] Create `/slides` command (`commands/slides.md`):
  - Arguments: SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying|pptx]
  - Default: infer output format from extension or default to Beamer
  - Support: PPTX input, Beamer/Polylux/Touying/PPTX output

**3.2 Create Presentation Context Documentation**:
- [ ] Create `context/project/filetypes/patterns/presentation-slides.md`:
  - python-pptx extraction patterns (text, images, notes, tables)
  - pandoc Beamer generation from Markdown
  - Polylux slide syntax and theme application
  - Touying slide syntax and theme application
  - Speaker notes handling across formats
  - Image extraction and cross-reference patterns

**3.3 Update Extension Metadata**:
- [ ] Update `manifest.json` to include presentation-agent, skill-presentation, /slides command
- [ ] Update `EXTENSION.md` with presentation conversion table
- [ ] Update `index-entries.json` with presentation context entries
- [ ] Update router agent to dispatch presentation formats to presentation-agent

**3.4 OpenCode Parity**:
- [ ] Mechanical translation of all Phase 3.1-3.3 files to `.opencode/extensions/filetypes/`

**Timing**: 2-2.5 hours

**Files to create/modify**:
```
.claude/extensions/filetypes/
  agents/presentation-agent.md
  skills/skill-presentation/SKILL.md
  commands/slides.md
  context/project/filetypes/patterns/presentation-slides.md
  manifest.json (updated)
  EXTENSION.md (updated)
  index-entries.json (updated)
  agents/filetypes-router-agent.md (updated)

.opencode/extensions/filetypes/
  [mirror of above changes]
```

**Verification**:
- Presentation agent references tool-detection.md (no embedded detection logic)
- Agent handles PPTX extraction with python-pptx and markitdown fallback
- Agent generates Beamer output via pandoc from structured Markdown
- Agent generates Polylux/Touying output via LLM-assisted Typst markup
- `/slides` command validates inputs and delegates through skill-presentation
- OpenCode extension matches Claude extension functionality

---

### Phase 4: Dependency Documentation with NixOS Support [COMPLETED]

**Goal**: Create comprehensive dependency documentation covering NixOS, Ubuntu/Debian, and macOS, plus MCP integration documentation and context README.

**Tasks**:

**4.1 Create Dependency Guide with NixOS-First Instructions**:
- [ ] Create `context/project/filetypes/tools/dependency-guide.md`:

  **NixOS (primary)**:
  ```bash
  # Nix shell (ephemeral)
  nix-shell -p python3Packages.markitdown
  nix-shell -p python3Packages.openpyxl python3Packages.pandas
  nix-shell -p python3Packages.python-pptx
  nix-shell -p pandoc texlive.combined.scheme-basic

  # Home-manager (persistent, declarative)
  home.packages = with pkgs; [
    pandoc
    (python3.withPackages (ps: with ps; [
      markitdown openpyxl pandas python-pptx xlsx2csv
    ]))
  ];

  # Nix profile (persistent, imperative)
  nix profile install nixpkgs#pandoc
  ```

  **Ubuntu/Debian**:
  ```bash
  pip install markitdown openpyxl pandas xlsx2csv python-pptx
  apt install pandoc texlive-base
  ```

  **macOS (Homebrew)**:
  ```bash
  pip install markitdown openpyxl pandas xlsx2csv python-pptx
  brew install pandoc mactex-no-gui
  ```

  **Note**: csv2latex is not in nixpkgs; use `pandas.DataFrame.to_latex()` instead (recommended approach).

**4.2 Create MCP Integration Documentation**:
- [ ] Create `context/project/filetypes/tools/mcp-integration.md`:
  - markitdown-mcp for Office -> Markdown
  - mcp-pandoc for universal format conversion
  - md-converter for Markdown -> DOCX/XLSX/PPTX
  - CLI fallback patterns when MCP unavailable

**4.3 Create Context README**:
- [ ] Create `context/project/filetypes/README.md`:
  - Overview of all conversion capabilities
  - Links to pattern files (spreadsheet-tables.md, presentation-slides.md)
  - Links to tool files (tool-detection.md, dependency-guide.md, mcp-integration.md)
  - Quick reference for common conversion tasks

**4.4 Final EXTENSION.md Update**:
- [ ] Complete conversion matrix covering all input/output combinations
- [ ] Full dependency table with installation links per platform
- [ ] Agent-skill-command mapping table

**4.5 OpenCode Parity**:
- [ ] Mechanical translation of all Phase 4 context files to `.opencode/extensions/filetypes/`

**Timing**: 1.5-2 hours

**Files to create/modify**:
```
.claude/extensions/filetypes/
  context/project/filetypes/README.md
  context/project/filetypes/tools/dependency-guide.md
  context/project/filetypes/tools/mcp-integration.md
  EXTENSION.md (final update)
  index-entries.json (final update)

.opencode/extensions/filetypes/
  [mirror of above]
```

**Verification**:
- Dependency guide covers all tools from research-001.md Section 7
- NixOS instructions are syntactically correct (nix-shell, home-manager, nix profile)
- Ubuntu/Debian and macOS instructions are syntactically correct
- MCP integration documentation covers all 4 MCP servers from research
- README provides clear navigation to all context files

---

### Phase 5: Integration Testing and Validation [COMPLETED]

**Goal**: Validate the complete filetypes extension structure in both systems, ensure all components are properly connected, and verify no orphaned references remain.

**Tasks**:

**5.1 Manifest Schema Validation** (both systems):
- [ ] All agents listed in `provides.agents` exist as files
- [ ] All skills listed in `provides.skills` have SKILL.md files
- [ ] All commands listed in `provides.commands` exist as files
- [ ] All context paths in `provides.context` exist as directories
- [ ] merge_targets reference correct section_id (`extension_filetypes`)

**5.2 Agent Cross-Reference Validation**:
- [ ] Router agent references correct sub-agent names
- [ ] Sub-agent names match file names (without .md extension)
- [ ] Skill SKILL.md files reference correct agent names
- [ ] Command files reference correct skill names
- [ ] All agents reference `@context/project/filetypes/tools/tool-detection.md`

**5.3 Context File Completeness**:
- [ ] All context files referenced in index-entries.json exist
- [ ] index-entries.json entries have valid paths, descriptions, and load_when conditions
- [ ] README.md links to all sibling context files

**5.4 Orphan Reference Cleanup** (BOTH systems):
- [ ] `grep -r "document-converter" .claude/` returns zero results
- [ ] `grep -r "document-converter" .opencode/` returns zero results
- [ ] `grep -r "skill-document-converter" .claude/` returns zero results
- [ ] `grep -r "skill-document-converter" .opencode/` returns zero results
- [ ] No stale merge targets referencing `extension_document_converter`

**5.5 Command Flow Validation** (structural, both systems):
- [ ] `/convert` -> skill-filetypes -> filetypes-router-agent -> document-agent (document formats)
- [ ] `/table` -> skill-spreadsheet -> spreadsheet-agent (spreadsheet formats)
- [ ] `/slides` -> skill-presentation -> presentation-agent (presentation formats)
- [ ] `/convert` -> skill-filetypes -> filetypes-router-agent -> spreadsheet-agent (XLSX detected)
- [ ] `/convert` -> skill-filetypes -> filetypes-router-agent -> presentation-agent (PPTX detected)

**5.6 Create Implementation Summary**:
- [ ] Document all files created/modified
- [ ] Document verification results
- [ ] Note any deviations from plan

**Timing**: 1-1.5 hours

**Verification**:
- Zero structural errors in both extension systems
- Zero orphaned references to old extension name
- All three command paths have valid delegation chains in both systems
- Both manifests accurately reflect all provided components

## Testing & Validation

- [ ] Manifest schema validation: all `provides` entries correspond to existing files (both systems)
- [ ] Agent reference validation: all agent names in skills and commands match agent file names
- [ ] Context link validation: all internal links in context files resolve correctly
- [ ] Old name cleanup: zero references to `document-converter` in both codebases
- [ ] Command delegation chain: each command -> skill -> agent path is structurally valid
- [ ] Dependency documentation: installation commands are syntactically correct for NixOS, apt, and brew
- [ ] EXTENSION.md completeness: all conversion paths from research Section 5 are documented
- [ ] OpenCode parity: `.opencode/extensions/filetypes/` mirrors `.claude/extensions/filetypes/`

## Artifacts & Outputs

- `plans/implementation-002.md` - This revised plan file
- `.claude/extensions/filetypes/` - Complete Claude extension directory
- `.opencode/extensions/filetypes/` - Complete OpenCode extension directory (parity)
- `summaries/implementation-summary-{DATE}.md` - Implementation summary upon completion

### Expected Extension Directory Structure (Both Systems)

```
.claude/extensions/filetypes/         .opencode/extensions/filetypes/
  manifest.json                         manifest.json
  EXTENSION.md                          EXTENSION.md
  index-entries.json                    index-entries.json
  agents/                               agents/
    filetypes-router-agent.md             filetypes-router-agent.md
    document-agent.md                     document-agent.md
    spreadsheet-agent.md                  spreadsheet-agent.md
    presentation-agent.md                 presentation-agent.md
  skills/                               skills/
    skill-filetypes/SKILL.md              skill-filetypes/SKILL.md
    skill-spreadsheet/SKILL.md            skill-spreadsheet/SKILL.md
    skill-presentation/SKILL.md           skill-presentation/SKILL.md
  commands/                             commands/
    convert.md                            convert.md
    table.md                              table.md
    slides.md                             slides.md
  context/                              context/
    project/filetypes/                    project/filetypes/
      README.md                             README.md
      patterns/                             patterns/
        spreadsheet-tables.md                 spreadsheet-tables.md
        presentation-slides.md                presentation-slides.md
      tools/                                tools/
        tool-detection.md                     tool-detection.md
        dependency-guide.md                   dependency-guide.md
        mcp-integration.md                    mcp-integration.md
```

## Future Work (Out of Scope for This Task)

These items are explicitly deferred per research findings and Non-Goals:

- **Typst slide deck context** (typst extension): Add `context/project/typst/patterns/slide-decks.md` to the typst extension covering Polylux and Touying syntax, theme selection, and overlay/animation patterns. Complements the `presentation-slides.md` context file created in Phase 3.

- **LaTeX slide deck context** (latex extension): Add `context/project/latex/patterns/beamer-slides.md` covering Beamer theme selection, overlay syntax, and academic presentation patterns.

- **Round-trip conversions** (research-001.md Section 5.2): LaTeX table -> XLSX via pandas reverse, Beamer -> PPTX via beamer2pptx, CSV/data file management utilities.

- **MCP server wrappers**: Creating dedicated MCP server wrappers if the existing markitdown-mcp, mcp-pandoc, and md-converter prove insufficient.

## Rollback/Contingency

If the renaming causes issues with existing workflows:
1. Both old `extensions/document-converter/` directories can be restored from git history
2. All new files are confined to `extensions/filetypes/` in both systems
3. No core `.claude/` or `.opencode/` files outside the extensions directories are modified
4. If sub-agents prove too granular, the router can be simplified to a single expanded agent by updating only the router agent definition
