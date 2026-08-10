# Research Report: Task #121

**Task**: 121 - clean_up_core_skills_directories
**Started**: 2026-03-03
**Completed**: 2026-03-03
**Effort**: 1-2 hours
**Dependencies**: Task 118 (extension exclusion filtering) - already completed
**Sources/Inputs**: Codebase analysis (sync.lua, manifest.lua, config.lua, loader.lua, init.lua), directory listings, extension manifests, git history
**Artifacts**: specs/121_clean_up_core_skills_directories/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- Extension-specific artifacts contaminate three directories: `.opencode/skills/` (11 extra), `~/.config/.claude/skills/` (3 extra), and multiple other artifact categories (agents, commands, rules) in both `.opencode/` and `~/.config/.claude/`
- The contamination originated from syncs performed before task 118 implemented manifest-based exclusion filtering (Feb 1, Feb 5, Feb 27 syncs vs Mar 3 exclusion code)
- The scope is broader than just skills: agents, commands, and rules are also contaminated across both `.opencode/` and `~/.config/.claude/` directories
- Recommended approach: a cleanup operation (manual or scripted) that removes extension-owned artifacts from core directories, guided by extension manifests as the source of truth

## Context and Scope

The project uses a core/extension architecture where:
- **Core system**: 11 skills, 6 agents, 11 commands, 6 rules (defined in `.claude/`)
- **Extensions**: 9 extension modules (document-converter, formal, latex, lean, nix, python, typst, web, z3) that provide additional skills, agents, commands, rules, and context
- **Sync operation**: "Load Core Agent System" copies artifacts from the global directory (`~/.config/nvim/.claude/` or `.opencode/`) to target project directories
- **Extension loading**: "Load Extension" copies extension-specific artifacts from `extensions/{name}/` to the target project's `.claude/` or `.opencode/` directory

The contamination occurred because the sync operation lacked extension filtering prior to task 118.

## Findings

### 1. Contamination Inventory

#### `.opencode/skills/` (22 present, 11 expected)

11 extension-owned skills are present that should only exist in their extension directories:

| Skill | Extension Owner | Contaminated? |
|-------|----------------|---------------|
| skill-document-converter | document-converter | Yes |
| skill-lake-repair | lean | Yes |
| skill-latex-implementation | latex | Yes |
| skill-latex-research | latex | Yes |
| skill-lean-implementation | lean | Yes |
| skill-lean-research | lean | Yes |
| skill-lean-version | lean | Yes |
| skill-logic-research | formal | Yes |
| skill-math-research | formal | Yes |
| skill-typst-implementation | typst | Yes |
| skill-typst-research | typst | Yes |

Note: Not all extension skills are present. Formal's skill-formal-research and skill-physics-research are absent, and nix/python/web/z3 skills are absent. This means the contamination happened at a specific point when only some extensions existed.

#### `~/.config/.claude/skills/` (14 present, 11 expected)

3 extension-owned skills:
- skill-document-converter (from document-converter extension)
- skill-latex-implementation (from latex extension)
- skill-typst-implementation (from typst extension)

#### `.opencode/agent/subagents/` - extension agents present

9 extension-owned agents contaminate the core agents directory:
- document-converter-agent.md, latex-implementation-agent.md, latex-research-agent.md
- lean-implementation-agent.md, lean-research-agent.md
- logic-research-agent.md, math-research-agent.md
- typst-implementation-agent.md, typst-research-agent.md

#### `~/.config/.claude/agents/` - extension agents present

3 extension-owned agents:
- document-converter-agent.md, latex-implementation-agent.md, typst-implementation-agent.md

#### `.opencode/commands/` - extension commands present

3 extension-owned commands:
- convert.md (document-converter), lake.md (lean), lean.md (lean)

#### `~/.config/.claude/commands/` - extension command present

1 extension-owned command:
- convert.md (document-converter)

#### `.opencode/rules/` - extension rules present

2 extension-owned rules:
- latex.md (latex extension), lean4.md (lean extension)

#### `~/.config/.claude/rules/` - extension rule present

1 extension-owned rule:
- latex.md (latex extension)

### 2. Root Cause Analysis

**Timeline**:
- Feb 1, 2026: First sync to `~/.config/.claude/` (captured document-converter, latex, typst artifacts)
- Feb 5, 2026: Second sync to `~/.config/.claude/` (captured latex-implementation, typst-implementation skills)
- Feb 27, 2026: Sync to `.opencode/` (captured all then-existing extension skills at 17:41 and 19:02)
- Mar 3, 2026: Task 118 implemented `build_extension_exclusions()` and `filter_extension_skills()` in sync.lua

The exclusion mechanism was not yet implemented when these syncs occurred. The sync operation at the time copied ALL files from the global `.claude/skills/` or `.opencode/skills/` directory without filtering out extension-owned artifacts.

### 3. How the Exclusion Mechanism Works (Post-Task 118)

The sync.lua module now has a three-layer filtering approach:

1. **`build_extension_exclusions(global_dir, config)`**: Reads all extension manifests from `{global_dir}/.{base_dir}/extensions/*/manifest.json` and builds exclusion sets per category (agents, commands, rules, scripts, hooks, skills, context)

2. **`filter_extension_files(files, exclude_set)`**: Filters simple file artifacts (agents, commands, rules) by checking filename against the exclusion set

3. **`filter_extension_skills(files, skill_dirs_exclude)`**: Filters skill directory artifacts by checking if the file path contains an excluded skill directory name pattern

4. **`filter_extension_context(files, context_prefixes, base_dir)`**: Filters context files by checking relative path prefix

This mechanism correctly prevents future syncs from copying extension artifacts into core directories. However, it does NOT retroactively clean up previously contaminated directories.

### 4. Extension Loading Architecture

When loading an extension via "Load Extension":
- `loader.copy_skill_dirs()`: Copies skills from `extensions/{name}/skills/{skill-name}/` to `{target}/.{base_dir}/skills/{skill-name}/`
- `loader.copy_simple_files()`: Copies agents, commands, rules from extension source to target
- `loader.copy_context_dirs()`: Copies context directories preserving structure
- State tracking via `extensions.json` records installed files/dirs for clean unload

**Critical finding**: No `extensions.json` state file exists in any of the contaminated directories, meaning the contamination was never tracked by the extension system. The artifacts were placed there by the core sync operation, not by extension loading.

### 5. Scope Beyond Skills

The task description focuses on skills, but the contamination is broader. A uniform cleanup approach should address ALL artifact categories, not just skills. The extension manifests provide the authoritative list of what belongs to each extension.

### 6. Uniform Cleanup Approach

**Source of truth**: Extension manifests (`manifest.json`) define exactly which artifacts belong to each extension via the `provides` field.

**Cleanup algorithm for each target directory**:
```
For each extension manifest:
  For each category in provides (skills, agents, commands, rules, scripts, hooks):
    For each artifact name in the category:
      If artifact exists in target/{base_dir}/{category}/{artifact}:
        Remove it (file or directory)
```

**Three target directories** need cleanup:
1. `~/.config/nvim/.opencode/` - uses `.opencode/extensions/*/manifest.json`
2. `~/.config/.claude/` - uses `~/.config/nvim/.claude/extensions/*/manifest.json`
3. (Potentially any other project directories that were synced before task 118)

**Uniform approach characteristics**:
- Manifest-driven: Uses the same manifests that the sync exclusion filter uses
- Idempotent: Can be run multiple times safely
- Category-agnostic: Handles all artifact types uniformly
- Verifiable: Can do a dry-run that lists what would be removed

### 7. Other Artifact Types with Similar Issues

| Category | .opencode contaminated | ~/.config/.claude contaminated |
|----------|----------------------|-------------------------------|
| Skills | 11 extra | 3 extra |
| Agents | 9 extra | 3 extra |
| Commands | 3 extra | 1 extra |
| Rules | 2 extra | 1 extra |
| Scripts | 0 (clean) | 0 (clean) |
| Hooks | 0 (clean) | 0 (clean) |
| Context | Not checked (complex) | Not checked (complex) |

Scripts and hooks are clean because no extensions were providing those at the time of the contaminating syncs (lean extension provides scripts but was likely created after the relevant sync).

## Decisions

1. **All artifact categories should be cleaned**, not just skills. The manifests provide the authoritative list.
2. **The cleanup should be manifest-driven** rather than using a hardcoded list of files to remove.
3. **The cleanup should handle the three distinct target directories** with their respective configurations.
4. **Context directory contamination should be investigated** as part of the cleanup, using the same `provides.context` prefix matching that `filter_extension_context` uses.
5. **No changes to sync.lua are needed** since task 118 already implemented the exclusion filtering for future syncs.

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Removing an artifact that is actively being used by a loaded extension in a project | Check extensions.json state before removal; if extension is loaded, the artifact should be present (loaded by extension loader, not core sync) |
| Accidentally removing a core artifact that happens to share a name with an extension artifact | Manifest-driven approach only removes artifacts explicitly listed in extension manifests |
| Context directory cleanup more complex than file removal | Use the same prefix-matching logic from filter_extension_context |
| Live ~/.config/.claude changes could affect active Claude Code sessions | Recommend restarting Claude Code after cleanup |

## Appendix

### Core Skills Reference (11 skills)

1. skill-git-workflow
2. skill-implementer
3. skill-learn
4. skill-meta
5. skill-neovim-implementation
6. skill-neovim-research
7. skill-orchestrator
8. skill-planner
9. skill-refresh
10. skill-researcher
11. skill-status-sync

### Extension Skills by Extension (21 skills across 9 extensions)

- **document-converter** (1): skill-document-converter
- **formal** (4): skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research
- **latex** (2): skill-latex-implementation, skill-latex-research
- **lean** (4): skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version
- **nix** (2): skill-nix-research, skill-nix-implementation
- **python** (2): skill-python-research, skill-python-implementation
- **typst** (2): skill-typst-research, skill-typst-implementation
- **web** (2): skill-web-implementation, skill-web-research
- **z3** (2): skill-z3-research, skill-z3-implementation

### Key Files Examined

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Core sync operation with exclusion filtering
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Manifest reading and validation
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/config.lua` - Extension configuration (claude vs opencode)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua` - File copy engine for load/unload
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua` - Extension manager API
- All 9 extension manifest.json files in `.opencode/extensions/` and `.claude/extensions/`
