# Implementation Plan: Task #109

- **Task**: 109 - Make agent system portable for new repos
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false

**Version**: 001
**Created**: 2026-03-02
**Language**: meta

## Overview

Separate neovim-specific content from the generic agent system in `.claude/` to enable portability when copying the directory to new repositories via `<leader>ac` "Load All Artifacts". The approach creates two new files (`agent-system.md` for generic system documentation, `update-project.md` for project-specific generation guidance), restructures `.claude/CLAUDE.md` to be project-agnostic, and preserves `project-overview.md` as neovim-specific content that stays in this repo. No changes to the sync mechanism (`sync.lua`) are needed -- portability is achieved by making the files themselves generic.

### Research Integration

The research report identified:
- 16 neovim-specific files, ~380 generic files, 14 mixed files in `.claude/`
- 13 neovim-specific references in `.claude/CLAUDE.md` across 7 sections
- The sync mechanism copies everything with no filtering -- so files themselves must be portable
- `update-project.md` does not yet exist and must be created
- The extension system already handles domain portability for other languages; neovim support in the core directory is the anomaly

## Goals & Non-Goals

**Goals**:
- Make `.claude/CLAUDE.md` generic so it reads correctly in any repository
- Create `agent-system.md` as a portable agent system overview document
- Create `update-project.md` as a guide for generating project-specific documentation in new repos
- Preserve all neovim-specific functionality in this repository (no breakage)
- Enable a clean experience when `<leader>ac` copies `.claude/` to a non-neovim project

**Non-Goals**:
- Moving neovim agents/skills/rules into a `extensions/neovim/` extension (separate future task)
- Modifying the sync mechanism in `sync.lua` (portability achieved via file content, not filtering)
- Making the mixed context files (routing.md, research-workflow.md, implementation-workflow.md) fully generic (low impact, separate task)
- Changing the root `CLAUDE.md` (in `nvim/CLAUDE.md`) -- that stays neovim-specific

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| CLAUDE.md changes break existing agent workflows | High | Medium | Keep all functional references intact; only change presentation and move project-specific content to clearly linked file |
| Neovim agents/skills still copied to non-neovim repos | Low | Certain | Acceptable -- they are only invoked when language="neovim", which non-neovim tasks will not use |
| project-overview.md not regenerated in new repos | Medium | Medium | `update-project.md` provides clear guidance; CLAUDE.md includes a note directing users there |
| CLAUDE.md becomes too sparse without project context | Medium | Low | Include a well-structured "Project Configuration" section that links to project-overview.md and explains how to generate it |

## Implementation Phases

### Phase 1: Create New Files [NOT STARTED]

**Goal**: Create the two new documentation files that form the portable agent system's project-generation infrastructure.

**Tasks**:
- [ ] Create `.claude/context/core/architecture/agent-system.md` with generic agent system overview
- [ ] Create `.claude/context/project/repo/update-project.md` with project-overview generation guidance

**Timing**: 1 hour

**Files to create**:
- `.claude/context/core/architecture/agent-system.md` - Generic agent system overview document, covering: what the agent system is, how commands/skills/agents work together, the task management lifecycle, language-based routing (generic description), extension system, and how to customize for a specific project. This file is always copied to new repos and provides the foundational understanding of the system.
- `.claude/context/project/repo/update-project.md` - A guide/template that instructs Claude how to analyze a new repository and generate an appropriate `project-overview.md`. Should include: what information to gather (tech stack, project structure, development workflow, verification commands), the expected output format matching the existing `project-overview.md` structure, and prompts/questions to ask or investigate.

**Steps**:
1. Create `agent-system.md`:
   - Write a title and purpose section explaining this is the portable agent system documentation
   - Document the three-layer architecture (Commands -> Skills -> Agents) in generic terms, referencing `system-overview.md` for detailed architecture
   - Describe the task management lifecycle (status markers, artifact paths, state synchronization) -- content currently in CLAUDE.md but generic
   - Describe language-based routing as a concept (table of built-in languages without project-specific emphasis)
   - Describe the extension system for adding domain-specific support
   - Include a "Customizing for Your Project" section pointing to `update-project.md` and `project-overview.md`
   - Keep this concise (target ~100-150 lines) -- it is an overview, not a comprehensive reference

2. Create `update-project.md`:
   - Write a title explaining this is a guide for generating project-specific documentation
   - Include a "When to Use" section: when `project-overview.md` does not exist in a newly synced repo
   - Define the expected output: a `project-overview.md` file at `.claude/context/project/repo/project-overview.md`
   - Provide a template with required sections: Project Overview, Technology Stack, Project Structure, Core Configuration, Development Workflow, Common Tasks, Verification Commands, Related Documentation
   - Include instructions for Claude to analyze the repository: scan directory structure, identify language/framework, find entry points, check for build systems, identify testing patterns
   - Keep this as a practical guide (target ~80-120 lines)

**Verification**:
- Both files exist and are well-formed markdown
- `agent-system.md` contains no neovim-specific references (grep for "neovim", "nvim", "neotex", "lua" should return zero hits except in generic context like "Lua" as a language name in routing tables)
- `update-project.md` contains no neovim-specific content (it is a generic template)
- Both files follow the documentation standards in `.claude/docs/reference/standards/documentation-standards.md`

---

### Phase 2: Restructure CLAUDE.md [NOT STARTED]

**Goal**: Transform `.claude/CLAUDE.md` from neovim-specific to project-agnostic while preserving all functional references and linking to project-specific content.

**Tasks**:
- [ ] Make title and header description generic
- [ ] Replace Project Structure section with project-overview.md link and generation note
- [ ] Generalize Language-Based Routing table
- [ ] Split Skill-to-Agent Mapping into generic core vs project-specific
- [ ] Split Rules References into generic core vs project-specific
- [ ] Make Context Discovery examples use generic agent names
- [ ] Replace Context Imports with project-overview.md link and update-project.md guidance
- [ ] Add Project Configuration section with conditional linking pattern

**Timing**: 1 hour

**Files to modify**:
- `.claude/CLAUDE.md` - Complete restructuring (13 neovim-specific references to remove/generalize)

**Steps**:
1. **Title and header** (lines 1-3):
   - Change "Neovim Configuration Management System" to "Agent System Configuration"
   - Change subtitle from "Task management and agent orchestration for Neovim configuration maintenance" to "Task management and agent orchestration for project development"
   - Keep the @.claude/README.md reference

2. **Quick Reference** (lines 5-10):
   - Keep as-is (these are generic: TODO.md, state.json, errors.json, README.md)

3. **Project Structure** (lines 12-27):
   - Replace the entire neovim-specific tree with a generic structure showing only the `.claude/` and `specs/` directories (which exist in every repo)
   - Add a note: "For project-specific structure, see `.claude/context/project/repo/project-overview.md`"
   - Add a note: "If `project-overview.md` does not exist, see `.claude/context/project/repo/update-project.md` for guidance on generating one"

4. **Language-Based Routing** (lines 49-57):
   - Keep the table but add a note above it: "Built-in language routes. Projects may add domain-specific routes via extensions."
   - Remove emphasis on `neovim` as the primary language -- it is just one row among equals
   - This table is actually generic (it lists all supported languages), so it mostly stays as-is

5. **Skill-to-Agent Mapping** (lines 122-138):
   - Split into two sub-sections:
     - "Core Skills" (generic: skill-researcher, skill-planner, skill-implementer, skill-meta, skill-document-converter, skill-status-sync, skill-refresh, skill-latex-implementation, skill-typst-implementation)
     - "Project-Specific Skills" with a note: "See `.claude/context/project/repo/project-overview.md` for project-specific skill mappings, if any"
   - Move skill-neovim-research and skill-neovim-implementation rows to the project-specific note
   - Keep Model Enforcement paragraph as-is (generic)

6. **Rules References** (lines 140-148):
   - Split into two groups:
     - "Core Rules" (generic: state-management, git-workflow, error-handling, artifact-formats, workflows)
     - "Project-Specific Rules" with note: "Additional rules may be defined for project-specific languages (e.g., neovim-lua.md for Neovim projects)"
   - Remove the direct @.claude/rules/neovim-lua.md reference from the core list

7. **Context Discovery** (lines 150-165):
   - Change example from `neovim-research-agent` to a generic agent name like `general-research-agent`
   - Change example from `"neovim"` language to a generic placeholder like `"general"`
   - Keep the planner-agent example (already generic)

8. **Context Imports** (lines 167-173):
   - Replace the neovim-specific import list with:
     - A link to `project-overview.md` for project-specific context
     - A note about `update-project.md` for generating project context in new repos
     - A reference to `agent-system.md` for the generic system overview
   - Format: "Domain knowledge is project-specific. See `.claude/context/project/repo/project-overview.md` for available context imports."

9. **Add Project Configuration section** (new section, after Context Imports):
   - Add a section explaining the generic vs project-specific split
   - Include the conditional linking pattern:
     ```
     ## Project Configuration

     This agent system is project-agnostic. Project-specific configuration is stored in:
     - `.claude/context/project/repo/project-overview.md` - Project structure, tech stack, workflows

     If `project-overview.md` does not exist (e.g., in a newly synced repository), see
     `.claude/context/project/repo/update-project.md` for guidance on generating one.

     For a generic overview of the agent system, see:
     - `.claude/context/core/architecture/agent-system.md`
     ```

**Verification**:
- Grep `.claude/CLAUDE.md` for "neovim" (case-insensitive) -- should return zero hits except potentially in Language-Based Routing table row (which is generic infrastructure, not project-specific emphasis)
- Grep for "nvim" -- should return zero hits
- Grep for "neotex" -- should return zero hits
- Grep for "init.lua" -- should return zero hits (moved to project-overview.md reference)
- All command references still present and accurate
- All generic sections preserved verbatim (Task Management, Command Reference, State Synchronization, Git Commit Conventions, Multi-Task Creation, Error Handling, jq Safety, Important Notes)
- The file reads coherently as a standalone document without neovim context

---

### Phase 3: Verification and Consistency [NOT STARTED]

**Goal**: Verify the changes work correctly, that existing neovim workflows are unaffected, and that the agent system is portable.

**Tasks**:
- [ ] Verify CLAUDE.md has no neovim-specific content (automated grep)
- [ ] Verify all referenced files exist
- [ ] Verify project-overview.md still contains neovim-specific content (unchanged)
- [ ] Verify agent-system.md is fully generic
- [ ] Verify update-project.md is fully generic
- [ ] Cross-reference: ensure no broken internal links in CLAUDE.md
- [ ] Verify the file would read correctly in a non-neovim repository context

**Timing**: 30 minutes

**Files to verify**:
- `.claude/CLAUDE.md` - No neovim-specific content
- `.claude/context/core/architecture/agent-system.md` - Exists, well-formed, generic
- `.claude/context/project/repo/update-project.md` - Exists, well-formed, generic
- `.claude/context/project/repo/project-overview.md` - Unchanged, still neovim-specific

**Steps**:
1. Run grep checks on `.claude/CLAUDE.md`:
   - `grep -i "neovim" .claude/CLAUDE.md` should only match the Language-Based Routing table row
   - `grep -i "nvim\|neotex\|init\.lua\|ftplugin\|lazy\.nvim" .claude/CLAUDE.md` should return zero hits
   - `grep "neovim-research-agent\|neovim-implementation-agent" .claude/CLAUDE.md` should return zero hits

2. Verify all file references in CLAUDE.md resolve:
   - Check each `@` reference and path reference exists on disk
   - Specifically verify: `agent-system.md`, `update-project.md`, `project-overview.md`

3. Verify `project-overview.md` is unchanged:
   - Compare with the version read during planning (145 lines, neovim-specific content)
   - Ensure no accidental modifications

4. Verify `agent-system.md` content:
   - Grep for "neovim", "nvim", "neotex" -- should return zero hits
   - Verify it references the three-layer architecture
   - Verify it describes task management lifecycle
   - Verify it points to `update-project.md` for project customization

5. Verify `update-project.md` content:
   - Grep for "neovim", "nvim", "neotex" -- should return zero hits
   - Verify it contains a template/guide structure
   - Verify it describes what sections to generate

6. Read `.claude/CLAUDE.md` end-to-end to verify coherence:
   - All sections flow logically
   - No dangling references to removed content
   - A reader without neovim knowledge can understand the document

**Verification**:
- All grep checks pass (zero neovim-specific content in generic files)
- All file references resolve to existing files
- `project-overview.md` unchanged
- CLAUDE.md reads coherently as a standalone generic document

## Testing & Validation

- [ ] `.claude/CLAUDE.md` contains zero neovim-specific references outside Language-Based Routing table
- [ ] `.claude/context/core/architecture/agent-system.md` exists and is fully generic
- [ ] `.claude/context/project/repo/update-project.md` exists and is fully generic
- [ ] `.claude/context/project/repo/project-overview.md` is unchanged
- [ ] All internal `@` references and path links in CLAUDE.md resolve to existing files
- [ ] CLAUDE.md reads coherently without neovim context
- [ ] All command references in CLAUDE.md are complete and accurate
- [ ] No broken cross-references between the three files (agent-system.md, update-project.md, CLAUDE.md)

## Artifacts & Outputs

- `.claude/CLAUDE.md` (modified) - Generic agent system configuration reference
- `.claude/context/core/architecture/agent-system.md` (new) - Portable agent system overview
- `.claude/context/project/repo/update-project.md` (new) - Project-overview generation guide
- `.claude/context/project/repo/project-overview.md` (unchanged) - Neovim-specific project documentation

## Rollback/Contingency

If the restructured CLAUDE.md causes issues with existing workflows:
1. Revert `.claude/CLAUDE.md` via `git checkout .claude/CLAUDE.md`
2. The new files (`agent-system.md`, `update-project.md`) can remain as they are additive and cause no conflicts
3. Re-evaluate which sections need to remain neovim-specific and adjust the approach
