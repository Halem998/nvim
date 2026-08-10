# Research Report: Task #127

**Task**: OC_127 - Migrate OPENCODE.md to README.md and rename QUICK-START.md to INSTALLATION.md
**Date**: 2026-03-03
**Language**: meta
**Focus**: Documentation consolidation and reorganization

## Summary

The .opencode/ directory contains a comprehensive agent orchestration system with multiple layers of documentation. Research reveals that OPENCODE.md (188 lines) serves as the primary quick reference containing task management, command syntax, state management, and workflow documentation. The current README.md is minimal (25 lines) and provides only basic directory structure overview. QUICK-START.md (116 lines) contains system status, basic commands, and architecture overview - it should be renamed to INSTALLATION.md and focus on dependency installation. The new README.md should consolidate OPENCODE.md content with cross-links to 20+ scattered README files across subdirectories.

## Findings

### 1. Current Documentation Structure

**Three Primary Documentation Files:**
- **OPENCODE.md** (188 lines) - Main quick reference with command syntax, task management, state management, rules references, and skill-to-agent mapping
- **README.md** (25 lines) - Minimal overview only covering Logos/Theory system basics  
- **QUICK-START.md** (116 lines) - System status, basic usage examples, and architecture overview

### 2. Scattered README Files Across Subdirectories

**Found 20+ README.md files requiring cross-links:**

**Commands (1 file):**
- `.opencode/commands/README.md` - 20 commands documented

**Agents (1 file):**
- `.opencode/agent/subagents/README.md` - 11 subagents categorized by type

**Documentation (2 files):**
- `.opencode/docs/README.md` - Documentation hub with guides and architecture
- `.opencode/docs/architecture/system-overview.md` - Three-layer architecture

**Context (2 files):**
- `.opencode/context/README.md` - Context organization
- `.opencode/context/index.md` - Context discovery

**Extensions (9 files across 9 extensions):**
- `extensions/lean/context/project/lean4/README.md`
- `extensions/typst/context/project/typst/README.md`
- `extensions/latex/context/project/latex/README.md`
- `extensions/formal/context/project/logic/README.md`
- `extensions/formal/context/project/math/README.md`
- `extensions/formal/context/project/physics/README.md`
- `extensions/python/context/project/python/README.md`
- `extensions/nix/context/project/nix/README.md`
- `extensions/web/context/project/web/README.md`
- `extensions/filetypes/context/project/filetypes/README.md`
- `extensions/z3/context/project/z3/README.md`

**Core Context (1 file):**
- `.opencode/context/core/checkpoints/README.md`

**Project Context (1 file):**
- `.opencode/context/project/neovim/README.md`

### 3. Core System Components

**Commands (20 total):**
- Task Management: `/task`, `/todo`
- Research: `/research`, `/review`, `/revise`
- Planning: `/plan`
- Implementation: `/implement`, `/meta`
- Utilities: `/convert`, `/errors`, `/lake`, `/lean`, `/learn`, `/refresh`

**Skills (11 total):**
- `skill-neovim-research` - Neovim plugin research
- `skill-neovim-implementation` - Neovim configuration implementation
- `skill-lean-research` - Lean 4/Mathlib research
- `skill-lean-implementation` - Lean proof implementation
- `skill-researcher` - General web/codebase research
- `skill-planner` - Implementation plan creation
- `skill-implementer` - General file implementation
- `skill-latex-research` - LaTeX documentation research
- `skill-latex-implementation` - LaTeX document implementation
- `skill-typst-implementation` - Typst document implementation
- `skill-typst-research` - Typst documentation research
- `skill-meta` - System builder
- `skill-learn` - Scan for FIX:/NOTE:/TODO: tags
- `skill-refresh` - Process and file cleanup
- `skill-orchestrator` - Route commands to workflows
- `skill-status-sync` - Atomic status updates
- `skill-git-workflow` - Scoped git commits

**Extensions (9 total):**
1. **lean** - Lean 4 theorem proving with Lake build system
2. **typst** - Modern document typesetting
3. **latex** - Traditional document typesetting
4. **formal** - Formal verification (logic, math, physics)
5. **python** - Python development
6. **nix** - Nix package management
7. **web** - Web development
8. **filetypes** - File format conversion
9. **z3** - Z3 theorem prover

**Rules (6 total):**
- `state-management.md` - Task state patterns
- `git-workflow.md` - Commit conventions
- `neovim-lua.md` - Neovim Lua development
- `error-handling.md` - Error recovery
- `artifact-formats.md` - Report/plan formats
- `workflows.md` - Command lifecycle

### 4. State Management System

**Key Files:**
- `specs/TODO.md` - Human-readable task list
- `specs/state.json` - Machine-readable task state
- `specs/errors.json` - Error tracking

**Status Flow:**
```
[NOT STARTED] -> [RESEARCHING] -> [RESEARCHED] -> [PLANNING] -> [PLANNED] -> [IMPLEMENTING] -> [COMPLETED]
```

### 5. Documentation Content Analysis

**OPENCODE.md Contents:**
- System overview and quick reference
- Project structure diagram
- Task management with status markers
- Language-based routing table (neovim, lean, latex, typst, general, meta)
- Command reference with usage syntax
- State synchronization requirements
- Git commit conventions
- Skill-to-Agent mapping table (17 entries)
- Rules references with auto-application paths
- Context imports for domain knowledge
- Error handling patterns
- jq command safety notes

**QUICK-START.md Contents:**
- System status declaration ("FULLY FUNCTIONAL")
- Key improvements (poetry removal)
- Basic command usage examples
- System architecture diagrams
- Key components list
- Success indicators
- Documentation references
- Production readiness statement

## Recommendations

### 1. New README.md Structure

The consolidated README.md should include:

**Section 1: System Overview**
- Brief description of .opencode/ agent system
- Purpose: Task management and agent orchestration for development workflows

**Section 2: Quick Start**
- Essential commands only: `/task`, `/research`, `/plan`, `/implement`
- Reference to INSTALLATION.md for full setup

**Section 3: Core Features**
- Task lifecycle management
- Language-based routing (neovim, lean, typst, latex, meta)
- Checkpoint-based execution (GATE IN -> DELEGATE -> GATE OUT -> COMMIT)
- State synchronization between TODO.md and state.json

**Section 4: Command Reference (Summary)**
- Table format: Command | Purpose | Key Flags
- Link to `commands/README.md` for detailed syntax

**Section 5: Extensions Overview**
- List of 9 available extensions with one-line descriptions
- Links to each extension's README.md

**Section 6: Directory Structure**
- Maintain current structure diagram
- Cross-links to subdirectory README files:
  - `commands/README.md` - Command definitions
  - `agent/subagents/README.md` - Agent documentation
  - `docs/README.md` - User guides and architecture
  - `context/README.md` - Context organization
  - `skills/` - Skill definitions
  - `extensions/<name>/` - Extension-specific documentation

**Section 7: Task Management**
- Status markers explanation
- Artifact paths convention
- Language routing table

**Section 8: Rules and Conventions**
- Brief mention of auto-applied rules
- Link to `rules/` directory

### 2. INSTALLATION.md (renamed from QUICK-START.md)

**Section 1: Prerequisites**
- Neovim installation
- Git configuration
- Required dependencies

**Section 2: System Installation**
- Clone/setup instructions
- Dependency installation steps
- Verification commands

**Section 3: Quick Commands**
- First commands to try: `/task --help`, `/research --help`

**Section 4: Troubleshooting**
- Common setup issues
- Verification steps

### 3. Migration Strategy

**Step 1: Create INSTALLATION.md**
- Rename QUICK-START.md -> INSTALLATION.md
- Remove system status content (move to README.md or remove)
- Focus on dependencies and installation
- Keep basic command examples

**Step 2: Create New README.md**
- Start with OPENCODE.md content as base
- Add directory structure with cross-links
- Add extensions section
- Update quick reference to reference INSTALLATION.md
- Keep all tables (commands, languages, skills, rules)

**Step 3: Cross-Link Integration**
- Add navigation footer to all README files
- Standard format: `[← Parent](../README.md) | [Subdirectory →](subdir/README.md)`

**Step 4: Remove OPENCODE.md**
- After README.md is complete and validated
- Update any references to point to README.md

## Risks & Considerations

- **Navigation Disruption**: Users familiar with OPENCODE.md may need time to adjust
- **Broken Links**: Must verify all internal cross-links work correctly
- **Duplication Risk**: Avoid duplicating content between README.md and subdirectory files
- **Maintenance Overhead**: Consolidated README will need updates when subdirectories change

## Next Steps

Run `/plan OC_127` to create an implementation plan covering:
1. INSTALLATION.md creation from QUICK-START.md
2. README.md consolidation with cross-links
3. Navigation footer standardization across all README files
4. OPENCODE.md removal and reference updates
5. Validation and testing of all cross-links
