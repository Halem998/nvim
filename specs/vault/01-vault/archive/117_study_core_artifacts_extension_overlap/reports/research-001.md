# Research Report: Task #117

**Task**: 117 - study_core_artifacts_extension_overlap
**Date**: 2026-03-03
**Focus**: Identify overlaps between core .claude/ artifacts and extensions

## Summary

The core `.claude/` directory and the `.claude/extensions/` system have a well-defined separation following task 110's cleanup, but several residual overlaps and architectural inconsistencies remain. The core retains neovim-specific artifacts (2 agents, 2 skills, 1 rule, 16 context files) that follow the same pattern as extension-housed domains. The parent `.config/CLAUDE.md` was not updated during task 110's cleanup and still lists removed extension skills (latex, typst, document-converter). The `adding-domains.md` guide instructs users to place new domains directly in core, contradicting the extension system approach. No extension auto-loading mechanism exists at the Claude Code runtime level -- extensions must be manually loaded via the Neovim picker, and when loaded they copy files into the core directory structure.

## Findings

### Core .claude/ Structure (Post Task 110 Cleanup)

The core contains 6 functional categories after the task 110 separation:

| Category | Count | Items |
|----------|-------|-------|
| Agents | 6 | general-implementation, general-research, meta-builder, neovim-implementation, neovim-research, planner |
| Skills | 11 | git-workflow, implementer, learn, meta, neovim-implementation, neovim-research, orchestrator, planner, refresh, researcher, status-sync |
| Rules | 6 | artifact-formats, error-handling, git-workflow, neovim-lua, state-management, workflows |
| Commands | 11 | errors, implement, learn, meta, plan, refresh, research, review, revise, task, todo |
| Context (core/) | 62 entries | Orchestration, patterns, formats, standards, templates, workflows, troubleshooting |
| Context (project/) | 29 entries | neovim (16), meta (6), processes (3), hooks (1), repo (3) |

### Extension System Structure

10 extensions exist under `.claude/extensions/`:

| Extension | Agents | Skills | Rules | Commands | Context Files | Scripts |
|-----------|--------|--------|-------|----------|--------------|---------|
| document-converter | 1 | 1 | 0 | 1 | 0 | 0 |
| formal | 4 | 4 | 0 | 0 | ~30 | 0 |
| latex | 2 | 2 | 1 | 0 | ~9 | 0 |
| lean | 2 | 4 | 1 | 2 | ~20 | 2 |
| nix | 2 | 2 | 1 | 0 | ~11 | 0 |
| python | 2 | 2 | 0 | 0 | ~6 | 0 |
| typst | 2 | 2 | 0 | 0 | ~12 | 0 |
| web | 2 | 2 | 1 | 0 | ~16 | 0 |
| z3 | 2 | 2 | 0 | 0 | ~4 | 0 |

**Total**: 19 agents, 21 skills, 4 rules, 3 commands, ~108 context files, 2 scripts

### Overlap Analysis

#### 1. Neovim Artifacts in Core (Candidate for Extension)

The following neovim-specific artifacts remain in core, not in an extension:

**Agents (2)**:
- `agents/neovim-implementation-agent.md`
- `agents/neovim-research-agent.md`

**Skills (2)**:
- `skills/skill-neovim-implementation/SKILL.md`
- `skills/skill-neovim-research/SKILL.md`

**Rules (1)**:
- `rules/neovim-lua.md`

**Context (16 files)**:
- `context/project/neovim/` -- entire directory tree with domain, patterns, standards, templates, tools subdirectories

This follows the exact same pattern as other domains (latex, lean, nix, etc.) that are housed as extensions. Task 109 explicitly noted this as a future consideration: "the neovim agents/skills/rules/context remain in core for now."

**Assessment**: These could be moved to a `neovim` extension. However, since this is the primary project domain (a Neovim configuration repository), keeping neovim in core is defensible. The tradeoff is portability vs. convenience.

#### 2. Parent .config/CLAUDE.md Stale References

The parent `.config/CLAUDE.md` (at `/home/benjamin/.config/.claude/CLAUDE.md`) was NOT updated during task 110's cleanup. It still contains:

- `latex` and `typst` in the Language-Based Routing table (lines 52-53)
- `skill-latex-implementation`, `skill-typst-implementation`, `skill-document-converter` in the Skill-to-Agent Mapping table (lines 129-132)

The child `.config/nvim/.claude/CLAUDE.md` was properly cleaned up with "Note" references pointing to extensions. The parent file is a stale copy that predates the separation work.

#### 3. adding-domains.md Guide vs. Extension System

The guide at `.claude/docs/guides/adding-domains.md` instructs users to:
- Create context in `.claude/context/project/your-domain/`
- Create agents in `.claude/agents/`
- Create skills in `.claude/skills/`
- Create rules in `.claude/rules/`
- Update the orchestrator routing table
- Update CLAUDE.md

This approach places everything directly in core -- the same pattern that task 110 explicitly reversed for latex/typst/document-converter. The guide makes **zero mention** of the extension system.

**Assessment**: The guide needs to be updated to recommend the extension approach for new domains, with the core approach reserved for the project's primary domain only.

#### 4. No Runtime Extension Loading by Claude Code

The extension system operates exclusively through Neovim picker-triggered file copying:
1. User selects extension via `<leader>ac` picker
2. Neovim code (loader.lua, merge.lua) copies files from `extensions/{name}/` into the core `.claude/` directory
3. Claude Code sees the files in their standard locations (agents/, skills/, etc.)
4. Unloading removes the copied files

**Key insight**: Claude Code itself has no awareness of the extension system. It only sees files in `.claude/agents/`, `.claude/skills/`, etc. The extension loading is a file-copy operation managed by Neovim. Currently, **no extensions are loaded** (no `extensions.json` state file exists).

This means:
- Extension agents/skills are NOT available to Claude Code unless manually loaded
- The routing table in the orchestrator only routes to core agents/skills
- Extension routing entries (e.g., `language: latex -> skill-latex-research`) only work after loading

#### 5. Index.json Does Not Include Extension Entries

The main `context/index.json` contains 91 entries, all from core (62 core domain, 29 project domain). No extension context entries are present. Extension `index-entries.json` files exist but are separate and only get merged into the main index when an extension is loaded via the merge.lua mechanism.

#### 6. No Sync Between Existing Core Context and Extensions

When extension files were moved out of core in task 110, the files were deleted from core locations. However:
- The extensions contain their own copies of these files
- No mechanism ensures content stays in sync between the extension source and what gets loaded
- Version numbers in manifests are all "1.0.0" with no update tracking

### Sync Mechanism Analysis

The extension system uses a 4-step load/unload process:

**Loading**:
1. `loader.copy_simple_files()` -- copies agents, commands, rules
2. `loader.copy_skill_dirs()` -- copies skill directories recursively
3. `loader.copy_context_dirs()` -- copies context directories preserving structure
4. `merge.inject_section()` -- injects EXTENSION.md content into CLAUDE.md
5. `merge.append_index_entries()` -- appends context entries to index.json
6. `merge.merge_settings()` -- merges settings fragments (e.g., MCP server configs)
7. `state.mark_loaded()` -- records installed files/dirs in extensions.json

**Unloading**:
1. `loader.remove_installed_files()` -- removes copied files/dirs
2. `merge.remove_section()` -- removes injected CLAUDE.md section
3. `merge.remove_index_entries_tracked()` -- removes appended index entries
4. `merge.unmerge_settings()` -- removes merged settings
5. `state.mark_unloaded()` -- clears state

**Conflict detection**: Before loading, `loader.check_conflicts()` checks if target files already exist in core. This prevents overwriting core files with extension files.

### Category-Level Overlap Summary

| Category | Core Only | Extension Only | Overlapping |
|----------|-----------|---------------|-------------|
| Agents | 4 (general-*, meta-builder, planner) | 19 extension agents | neovim-* (2 in core, could be extension) |
| Skills | 7 (git-workflow, implementer, learn, meta, orchestrator, planner, refresh, researcher, status-sync) | 21 extension skills | neovim-* (2 in core, could be extension) |
| Rules | 5 (artifact-formats, error-handling, git-workflow, state-management, workflows) | 4 extension rules | neovim-lua (1 in core, could be extension) |
| Commands | 11 (all) | 3 extension commands | None |
| Context core/ | 62 entries | 0 | None |
| Context project/ | neovim(16), meta(6), processes(3), hooks(1), repo(3) | ~108 files | neovim context (16 in core, could be extension) |

## Recommendations

### 1. Update Parent .config/CLAUDE.md (Priority: High)

Remove stale latex/typst/document-converter references from the parent CLAUDE.md at `/home/benjamin/.config/.claude/CLAUDE.md`. Align it with the child `.config/nvim/.claude/CLAUDE.md` which was properly updated in task 110.

### 2. Update adding-domains.md Guide (Priority: High)

Rewrite the guide to recommend the extension approach as the primary method for adding new domains. Keep the core approach only as a special case for the repository's primary domain. Add documentation for:
- Extension manifest format
- EXTENSION.md merge content
- index-entries.json format
- The load/unload mechanism

### 3. Consider Neovim Extension (Priority: Low)

Evaluate moving neovim-specific artifacts to a `neovim` extension for full portability. This would make the core completely generic, but adds friction for the primary use case. The tradeoff may not be worth it since:
- This IS a Neovim configuration repository
- Neovim context is frequently needed
- The loading step adds unnecessary friction

### 4. Create Extension System Documentation (Priority: Medium)

No dedicated extension system guide exists. The system is documented only in code (loader.lua, merge.lua, state.lua, config.lua). Create:
- `.claude/docs/guides/creating-extensions.md` -- how to create extensions
- `.claude/docs/architecture/extension-system.md` -- how the system works
- Update `.claude/docs/README.md` to reference extension docs

### 5. No Immediate Deduplication Needed

The task 110 cleanup successfully eliminated all content duplication between core and extensions for latex/typst/document-converter. The remaining "overlap" (neovim) is intentional. No cleanup is needed.

## Context Extension Recommendations

None -- this is a meta task about the system itself.

## References

- Task 109 (generic_agent_system_portability) -- made CLAUDE.md generic
- Task 110 (separate_extension_files_from_core_agent_system) -- removed 25 extension files from core
- Task 113 (review_proofchecker_opencode_virtues) -- implemented extension system
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/` -- extension system code
- `.claude/docs/guides/adding-domains.md` -- current (outdated) domain addition guide
- `.claude/extensions/*/manifest.json` -- extension manifests

## Next Steps

Run `/plan 117` to create an implementation plan addressing the recommendations above, prioritizing the stale parent CLAUDE.md cleanup and guide updates.
