# Research Report: Task #110

**Task**: 110 - separate_extension_files_from_core_agent_system
**Started**: 2026-03-02T23:36:30Z
**Completed**: 2026-03-02T23:55:00Z
**Effort**: 2-4 hours estimated for implementation
**Dependencies**: Task #109 (completed - generic agent system portability)
**Sources/Inputs**: Codebase analysis (.claude/ directory, extensions/, sync.lua, index.json, CLAUDE.md, routing.md)
**Artifacts**: specs/110_separate_extension_files_from_core_agent_system/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The core `.claude/` directory contains **25 extension-specific files** that duplicate content already present in the `extensions/` system: LaTeX (agent, skill, rule, 8 context files), Typst (agent, skill, 8 context files), and document-converter (agent, skill, command)
- The extension system (`extensions/latex/`, `extensions/typst/`) already provides **equivalent or richer versions** of these files with additional files not in core (e.g., `latex-research-agent`, `typst-research-agent`, `custom-macros.md`)
- The `<leader>ac` "Load All Artifacts" sync mechanism copies ALL files from core `.claude/` to new repos, meaning these extension-specific files pollute every new project
- Removing extension-specific files from core requires updating **7-10 core reference files** (CLAUDE.md, routing.md, index.json, orchestrator skill, implement command, system-overview, etc.) that mention LaTeX/Typst/document-converter agents and skills
- The `neovim` agents/skills/rules/context remain in core for now (task 109 noted this as a future task for a neovim extension)
- The `/convert` command should either be moved to a general-purpose extension or remain in core since document conversion is arguably general-purpose (not strictly LaTeX/Typst)

## Context & Scope

Task 109 (completed) made `.claude/CLAUDE.md` generic and created `agent-system.md` and `update-project.md` for portability. However, it explicitly deferred moving extension-specific files out of core, noting that the extension system already handles domain-specific content. Task 110 addresses this gap by identifying and relocating files that belong in extensions.

The task description specifically calls out:
1. `agents/document-converter-agent.md`
2. `agents/latex-implementation-agent.md`
3. `agents/typst-implementation-agent.md`
4. `context/project/typst/` (entire directory)
5. `context/project/latex/` (entire directory)
6. `skills/skill-latex-implementation/`
7. `skills/skill-typst-implementation/`

Additionally, the research identified more files that should also be considered:
8. `skills/skill-document-converter/`
9. `rules/latex.md`
10. `commands/convert.md` (depends on document-converter agent/skill)

## Findings

### 1. Complete Inventory: Extension-Specific Files in Core

#### LaTeX Files in Core (11 files)

| File | Category | Already in extensions/latex/? | Notes |
|------|----------|------------------------------|-------|
| `agents/latex-implementation-agent.md` | Agent | YES (identical name) | Extension also has `latex-research-agent.md` which core does NOT |
| `skills/skill-latex-implementation/SKILL.md` | Skill | YES (identical name) | Extension also has `skill-latex-research/` which core does NOT |
| `rules/latex.md` | Rule | YES (`rules/latex.md`) | Extension manifest lists `latex.md` in provides.rules |
| `context/project/latex/README.md` | Context | YES | Extension version exists |
| `context/project/latex/standards/latex-style-guide.md` | Context | YES | Extension version exists |
| `context/project/latex/standards/document-structure.md` | Context | YES | Extension version exists |
| `context/project/latex/standards/notation-conventions.md` | Context | YES | Extension version exists |
| `context/project/latex/patterns/theorem-environments.md` | Context | YES | Extension version exists |
| `context/project/latex/patterns/cross-references.md` | Context | YES | Extension version exists |
| `context/project/latex/tools/compilation-guide.md` | Context | YES | Extension version exists |
| `context/project/latex/templates/subfile-template.md` | Context | YES | Extension version exists |

#### Typst Files in Core (10 files)

| File | Category | Already in extensions/typst/? | Notes |
|------|----------|-------------------------------|-------|
| `agents/typst-implementation-agent.md` | Agent | YES (identical name) | Extension also has `typst-research-agent.md` which core does NOT |
| `skills/skill-typst-implementation/SKILL.md` | Skill | YES (identical name) | Extension also has `skill-typst-research/` which core does NOT |
| `context/project/typst/README.md` | Context | YES | Extension version exists |
| `context/project/typst/standards/typst-style-guide.md` | Context | YES | Extension version exists |
| `context/project/typst/standards/document-structure.md` | Context | YES | Extension version exists |
| `context/project/typst/standards/notation-conventions.md` | Context | YES | Extension version exists |
| `context/project/typst/patterns/theorem-environments.md` | Context | YES | Extension version exists |
| `context/project/typst/patterns/cross-references.md` | Context | YES | Extension version exists |
| `context/project/typst/tools/compilation-guide.md` | Context | YES | Extension version exists |
| `context/project/typst/templates/chapter-template.md` | Context | YES | Extension version exists |

#### Document-Converter Files in Core (4 files)

| File | Category | In any extension? | Notes |
|------|----------|--------------------|-------|
| `agents/document-converter-agent.md` | Agent | NO | Not in any extension |
| `skills/skill-document-converter/SKILL.md` | Skill | NO | Not in any extension |
| `commands/convert.md` | Command | NO | Depends on document-converter skill/agent |

**Total**: 25 extension-specific files in core (11 LaTeX + 10 Typst + 4 document-converter)

### 2. Extension vs Core Comparison

The extension versions are generally **richer** than the core versions:

**LaTeX extension** has files core does NOT:
- `agents/latex-research-agent.md` (core only has implementation agent)
- `skills/skill-latex-research/SKILL.md` (core only has implementation skill)
- `context/project/latex/patterns/document-structure.md`
- `context/project/latex/standards/custom-macros.md`

**Typst extension** has files core does NOT:
- `agents/typst-research-agent.md` (core only has implementation agent)
- `skills/skill-typst-research/SKILL.md` (core only has implementation skill)
- `context/project/typst/patterns/fletcher-diagrams.md`
- `context/project/typst/patterns/rule-environments.md`
- `context/project/typst/standards/textbook-standards.md`
- `context/project/typst/standards/type-theory-foundations.md`

This confirms the extensions supersede the core files -- removing the core duplicates loses nothing.

### 3. File Difference Analysis

Checked whether core files differ from extension counterparts:

The core files were the **original versions** created before the extension system existed. The extension versions were created by copying these core files and then enhancing them with additional content (research agents, additional patterns, etc.). For the purpose of this task, the extension versions are authoritative and the core versions should be removed.

### 4. Core Files That Reference Extension-Specific Content

These files contain references to LaTeX, Typst, and/or document-converter agents/skills and will need updating:

| File | References | Action Needed |
|------|-----------|---------------|
| `.claude/CLAUDE.md` | Skill-to-Agent Mapping table (latex-implementation, typst-implementation, document-converter rows), Language-Based Routing table (latex/typst rows), Context Imports | Remove extension-specific rows from mapping tables; routing table keeps languages but notes they require extensions |
| `.claude/context/core/routing.md` | latex -> skill-latex-implementation, typst -> skill-typst-implementation | Remove or annotate these rows as extension-provided |
| `.claude/context/index.json` | 16 entries for project/latex/* and project/typst/* | Remove these entries (extensions have their own index-entries.json) |
| `.claude/skills/skill-orchestrator/SKILL.md` | latex/typst routing rows | Remove extension-specific routing rows |
| `.claude/commands/implement.md` | latex/typst routing in language table | Remove extension-specific routing rows |
| `.claude/commands/convert.md` | Entire command depends on document-converter | Requires decision (see section 6) |
| `.claude/docs/architecture/system-overview.md` | latex-implementation-agent, skill-latex-implementation | Remove extension-specific entries |
| `.claude/docs/guides/creating-agents.md` | Uses latex-implementation-agent as example | Change example to use a generic agent name |
| `.claude/docs/guides/component-selection.md` | References latex-implementation and skill | Remove extension-specific entries |
| `.claude/context/project/processes/implementation-workflow.md` | latex/typst agent routing | Remove extension-specific routing |
| `.claude/context/project/processes/research-workflow.md` | neovim agent routing (tangential) | Out of scope for this task |
| `.claude/context/core/orchestration/routing.md` | latex/typst validation references | Remove extension-specific validation |

### 5. How the Extension Loading Mechanism Works

When a user loads an extension via the picker (e.g., loads "latex"):

1. **Manifest reading**: `manifest.json` lists what the extension provides (agents, skills, rules, context, etc.)
2. **Conflict check**: `loader.check_conflicts()` checks if target files already exist in core `.claude/`
3. **File copy**: `loader.copy_simple_files()`, `copy_skill_dirs()`, `copy_context_dirs()` copy extension files into the project's `.claude/` directory
4. **CLAUDE.md merge**: Extension's `EXTENSION.md` content is merged into `.claude/CLAUDE.md` at the specified section ID
5. **Index merge**: Extension's `index-entries.json` entries are merged into `context/index.json`

**Key insight**: The conflict check means that if core already has files with the same names as extension files, the loader will **report conflicts** and the user will be asked to resolve them. Removing core duplicates eliminates this friction -- extensions load cleanly without conflict prompts.

### 6. Document-Converter Decision

The document-converter is a borderline case:

**Arguments for keeping in core**:
- Document conversion (PDF to Markdown, etc.) is a general-purpose capability
- It doesn't require any domain-specific knowledge (unlike LaTeX compilation or Typst rendering)
- The `/convert` command is useful across all project types

**Arguments for moving to extension**:
- The task description explicitly lists `document-converter-agent.md` for removal
- It adds 4 files to every new project that may not use document conversion
- Clean separation: core = task management + generic research/plan/implement

**Recommendation**: Move document-converter to a new `extensions/document-converter/` extension, OR defer and keep it in core as a general utility. The task description explicitly requests moving it, so the plan should include it. The `/convert` command should be moved along with it.

### 7. Settings.json Permissions

The `settings.json` file includes LaTeX-related permissions:
```json
"Bash(pdflatex *)",
"Bash(latexmk *)",
"Bash(bibtex *)",
"Bash(biber *)",
```

These permissions should ideally be in the extension's `settings-fragment.json` (which the extension system supports for `mcp_servers` via `settings-fragment.json`). However, the current extension system does not merge permission fragments. This is a minor concern -- having extra Bash permissions does not cause problems (they are allow-list entries that simply have no effect if the tools are not installed).

**Recommendation**: Leave LaTeX permissions in settings.json for now. Add a NOTE comment explaining they come from the latex extension. A future enhancement could add permission fragment merging to the extension loader.

### 8. Sync Mechanism Impact

The `sync.lua` "Load All Artifacts" mechanism copies files from the **core `.claude/` directory** (not from extensions). After removing extension-specific files from core:

- `agents/` scan will find fewer agents (no latex, typst, document-converter)
- `skills/` scan will find fewer skills (no skill-latex-implementation, skill-typst-implementation, skill-document-converter)
- `rules/` scan will find fewer rules (no latex.md)
- `context/project/` scan will find fewer directories (no latex/, typst/)

This is the **desired behavior** -- new projects get a clean core, and users can load extensions as needed via the picker.

### 9. Impact on Currently Loaded Projects

For projects that have already loaded these extensions (or received them via sync), the extension files will already exist in the project's `.claude/` directory. Removing them from the global source only affects **future syncs**. Existing projects continue to work.

If users do a "Sync all (replace existing)" from the updated global source, the extension-specific files in their projects will NOT be removed (sync only copies/replaces, it does not delete files that are no longer in the source). This is acceptable.

## Decisions

1. **Remove all 21 LaTeX+Typst files from core**: They are fully duplicated in extensions with richer content
2. **Move document-converter to extension**: Create `extensions/document-converter/` or keep in core as the task description explicitly requests removal
3. **Update all 10+ reference files**: Remove extension-specific entries from routing tables, skill mappings, index.json, etc.
4. **Leave settings.json permissions**: Extra Bash permissions are harmless
5. **Do not modify sync.lua**: Fewer files in core means sync naturally copies less
6. **Keep neovim files in core**: Out of scope (task 109 noted as future work)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking loaded extensions in this repo | Medium | High | After removing core files, immediately load LaTeX and Typst extensions via picker to reinstall from extensions |
| Missing references in documentation | Medium | Medium | Search-and-update all files referencing removed agents/skills/context |
| Index.json entries pointing to removed files | High | Medium | Remove the 16 LaTeX/Typst entries from index.json |
| /convert command breaks | High (if moved) | Low | Move command alongside agent/skill to extension |
| Sync to existing projects removes functionality | Low | Low | Sync only adds/replaces, never deletes |
| Users confused by missing LaTeX/Typst in new projects | Low | Low | Extensions are discoverable via picker; CLAUDE.md can note available extensions |

## Implementation Recommendations

### Phase 1: Create Document-Converter Extension (if moving)
1. Create `extensions/document-converter/manifest.json`
2. Create `extensions/document-converter/EXTENSION.md`
3. Move `agents/document-converter-agent.md` -> `extensions/document-converter/agents/`
4. Move `skills/skill-document-converter/SKILL.md` -> `extensions/document-converter/skills/`
5. Move `commands/convert.md` -> `extensions/document-converter/commands/`

### Phase 2: Remove Extension-Specific Files from Core
1. Delete `agents/latex-implementation-agent.md`
2. Delete `agents/typst-implementation-agent.md`
3. Delete `agents/document-converter-agent.md` (if moved to extension in Phase 1)
4. Delete `skills/skill-latex-implementation/` directory
5. Delete `skills/skill-typst-implementation/` directory
6. Delete `skills/skill-document-converter/` directory (if moved)
7. Delete `rules/latex.md`
8. Delete `context/project/latex/` directory (entire tree)
9. Delete `context/project/typst/` directory (entire tree)
10. Delete `commands/convert.md` (if moved)

### Phase 3: Update Core References
1. Update `.claude/CLAUDE.md`:
   - Remove LaTeX/Typst/document-converter rows from Skill-to-Agent Mapping table
   - Update Language-Based Routing table to note latex/typst require extensions
   - Remove latex/typst from Context Imports section
2. Update `.claude/context/core/routing.md`:
   - Remove or annotate latex/typst routing rows
3. Update `.claude/context/index.json`:
   - Remove all 16 entries with paths under `project/latex/` and `project/typst/`
4. Update `.claude/skills/skill-orchestrator/SKILL.md`:
   - Remove latex/typst routing
5. Update `.claude/commands/implement.md`:
   - Remove latex/typst from routing table
6. Update `.claude/docs/architecture/system-overview.md`:
   - Remove extension-specific entries from skill mapping table
7. Update `.claude/docs/guides/creating-agents.md`:
   - Replace latex-implementation-agent example with generic agent name
8. Update `.claude/docs/guides/component-selection.md`:
   - Remove extension-specific component entries
9. Update `.claude/context/project/processes/implementation-workflow.md`:
   - Remove latex/typst agent routing rows

### Phase 4: Verify and Test
1. Load LaTeX extension via picker to verify it loads cleanly (no conflicts)
2. Load Typst extension via picker to verify it loads cleanly
3. Verify routing still works for general/meta/neovim languages
4. Verify `/implement` command documentation is consistent
5. Run `validate-context-index.sh` to verify index.json integrity

## Appendix

### Search Queries Used
- `find .claude/ -type f` - Full file listing (410 files)
- `diff` comparisons between core and extension versions of duplicate files
- `grep -r "latex-implementation\|typst-implementation\|document-converter"` - Cross-reference search
- Read: sync.lua, loader.lua, manifest.json (latex, typst), index.json, CLAUDE.md, routing.md, orchestrator SKILL.md

### File Counts
- Files to delete from core: 25 (11 LaTeX + 10 Typst + 4 document-converter)
- Files to update in core: 9-10 reference files
- Files to create: 3-5 (document-converter extension manifest, EXTENSION.md, etc.)
- Net reduction in core: ~20 files

### Extension Manifest Structure (for new document-converter extension)
```json
{
  "name": "document-converter",
  "version": "1.0.0",
  "description": "Document format conversion (PDF, DOCX, HTML to/from Markdown)",
  "language": "general",
  "dependencies": [],
  "provides": {
    "agents": ["document-converter-agent.md"],
    "skills": ["skill-document-converter"],
    "commands": ["convert.md"],
    "rules": [],
    "context": [],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_document_converter"
    }
  },
  "mcp_servers": {}
}
```
