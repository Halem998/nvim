# Research Report: Task #169 (Supplemental)

**Task**: 169 - verify_agent_systems_wired_after_reload
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T01:00:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (Vision/.claude/, Vision/.claude_ext/, Vision/.opencode/, Vision/.opencode_ext/, nvim extension loader code)
**Artifacts**: specs/169_verify_agent_systems_wired_after_reload/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The extension loading architecture is well-designed with a shared parameterized engine (shared/extensions/) that serves both Claude and OpenCode systems via thin wrapper modules
- **Core problem**: The Vision "core" system already contains ALL extension-provided files (agents, skills, rules, context) -- the extension loader copies files that already exist, making it a no-op for file installation
- The loader's primary value is in merge operations: injecting CLAUDE.md/OPENCODE.md sections, merging settings.json, and appending index.json entries
- index.json in the core Vision system has inconsistent path prefixes (some entries use `.claude/context/project/...`, some use `context/project/...`, some use `project/...`) -- the merge module has a normalize function to handle this but it creates fragility
- Recommended approach: True core/extension separation where core contains ONLY core elements, and the loader adds all extension-specific content

## Context & Scope

This supplemental report focuses on extension loading architecture design, building on research-001 which identified that neovim/filetypes context entries were not merged into index.json and 76 context files were missing from disk.

## Findings

### 1. Core vs Extended Systems Comparison

#### File Structure Comparison (.claude/)

The core Vision `.claude/` and extended `.claude_ext/` systems have **identical file trees** for agents, skills, rules, and context directories. The only differences are:

| Element | Core (.claude/) | Extended (.claude_ext/) |
|---------|----------------|----------------------|
| agents/ | 31 agents (identical) | 31 agents (identical) |
| skills/ | 38 skills (identical) | 38 skills (identical) |
| rules/ | 10 rules (identical) | 10 rules (identical) |
| context/ files | Identical | Identical |
| CLAUDE.md | 236 lines | 885 lines (+649 lines from extension sections) |
| context/index.json | 97 entries | 236 entries (+139 from extensions) |
| extensions.json | Does not exist | Exists (tracks loaded extensions) |
| settings.local.json | Exists | Exists + .backup |

**Key insight**: Extension loading does NOT install any new files to agents/, skills/, rules/, or context/ because they already exist in core. The loader's file copy operations find identical files already in place (conflicts detected but harmless).

#### What Extension Loading Actually Changes

The loader's effective operations are limited to three merge targets:

1. **CLAUDE.md section injection**: Adds 11 extension sections (649 lines) with `<!-- SECTION: extension_* -->` markers
2. **index.json entry appending**: Adds 139 context entries from extension index-entries.json files
3. **settings.json merging**: Adds MCP server configurations (lean-lsp, mcp-nixos) and permission entries

The `.opencode/` system shows the same pattern -- identical file trees with merge-only changes.

### 2. Elements That Should Be Extension-Only (Not in Core)

All 11 extension-provided domains have their full content committed to the core system. Elements that should be removed from core and provided only via extensions:

#### Agents (to remove from core)
- `neovim-implementation-agent.md` (nvim extension)
- `neovim-research-agent.md` (nvim extension)
- `filetypes-router-agent.md` (filetypes extension)
- `document-agent.md` (filetypes extension)
- `spreadsheet-agent.md` (filetypes extension)
- `presentation-agent.md` (filetypes extension)
- `deck-agent.md` (filetypes extension)
- `epidemiology-implementation-agent.md` (epidemiology extension)
- `epidemiology-research-agent.md` (epidemiology extension)
- `formal-research-agent.md` (formal extension)
- `logic-research-agent.md` (formal extension)
- `math-research-agent.md` (formal extension)
- `physics-research-agent.md` (formal extension)
- `latex-implementation-agent.md` (latex extension)
- `latex-research-agent.md` (latex extension)
- `lean-implementation-agent.md` (lean extension)
- `lean-research-agent.md` (lean extension)
- `nix-implementation-agent.md` (nix extension)
- `nix-research-agent.md` (nix extension)
- `python-implementation-agent.md` (python extension)
- `python-research-agent.md` (python extension)
- `typst-implementation-agent.md` (typst extension)
- `typst-research-agent.md` (typst extension)
- `web-implementation-agent.md` (web extension)
- `web-research-agent.md` (web extension)
- `z3-implementation-agent.md` (z3 extension)
- `z3-research-agent.md` (z3 extension)

**Core agents to keep** (5 total):
- `general-implementation-agent.md`
- `general-research-agent.md`
- `meta-builder-agent.md`
- `planner-agent.md`
- (code-reviewer-agent.md -- opencode only)

#### Skills (to remove from core)
All `skill-*-implementation` and `skill-*-research` for: neovim, lean, latex, typst, python, nix, web, epidemiology, z3
Plus: `skill-formal-research`, `skill-logic-research`, `skill-math-research`, `skill-physics-research`
Plus: `skill-filetypes`, `skill-spreadsheet`, `skill-presentation`, `skill-deck`
Plus: `skill-lake-repair`, `skill-lean-version`

**Core skills to keep** (~10):
- `skill-implementer`, `skill-researcher`, `skill-planner`, `skill-meta`
- `skill-status-sync`, `skill-refresh`, `skill-orchestrator`
- `skill-git-workflow`, `skill-learn`, `skill-tag`

#### Rules (to remove from core)
- `neovim-lua.md` (nvim extension)
- `latex.md` (latex extension)
- `lean4.md` (lean extension)
- `nix.md` (nix extension)
- `web-astro.md` (web extension)

**Core rules to keep** (5):
- `artifact-formats.md`
- `error-handling.md`
- `git-workflow.md`
- `state-management.md`
- `workflows.md`

#### Context Directories (to remove from core)
All `context/project/*` directories except `meta/`, `repo/`, `hooks/`, and `processes/`:
- `context/project/neovim/` (nvim extension)
- `context/project/filetypes/` (filetypes extension)
- `context/project/epidemiology/` (epidemiology extension)
- `context/project/latex/` (latex extension)
- `context/project/lean4/` (lean extension)
- `context/project/logic/` (formal extension)
- `context/project/math/` (formal extension)
- `context/project/physics/` (formal extension)
- `context/project/nix/` (nix extension)
- `context/project/python/` (python extension)
- `context/project/typst/` (typst extension)
- `context/project/web/` (web extension)
- `context/project/z3/` (z3 extension)

#### CLAUDE.md References to Remove
The core CLAUDE.md should NOT contain:
- Language-specific routing entries (neovim, lean, latex, etc. rows)
- Extension skill-to-agent mappings
- Extension context import references
- Notes referencing extension-provided elements

Instead, these should appear only when extensions inject their `<!-- SECTION: extension_* -->` blocks.

### 3. index.json Architecture Design

#### Current State

The core index.json has 97 entries with **three different path prefix conventions**:

| Prefix Pattern | Count | Example | Status |
|----------------|-------|---------|--------|
| `project/*` or `core/*` | ~57 | `project/lean4/README.md` | Correct |
| `context/project/*` | ~5 | `context/project/python/standards/code-style.md` | Bad prefix |
| `.claude/context/project/*` | ~35 | `.claude/context/project/nix/README.md` | Bad prefix |

The `normalize_index_path()` function in `merge.lua` strips these bad prefixes, but this is a defensive workaround rather than a fix at the source.

#### Recommended index.json Update Mechanism

**Goal**: index.json should be a clean union of:
1. Core entries (always present, ~9 entries for core/*)
2. Extension entries (added/removed by loader)

**Design**:

```
Core index.json (committed to git):
{
  "entries": [
    // Only core/* entries (~9)
    {"path": "README.md", ...},
    {"path": "core/routing.md", ...},
    {"path": "core/checkpoints/checkpoint-gate-in.md", ...},
    ...
  ]
}

Extension loading appends entries with normalized paths.
Extension unloading removes them by tracked paths.
```

**Path normalization should happen at the source** (in index-entries.json files) rather than at merge time. Each extension's `index-entries.json` should use canonical `project/*` paths.

#### Current Extension index-entries.json Issues

Some extensions use inconsistent path formats in their index-entries.json files, leading to the bad prefixes in core. The normalize function catches this but it should be fixed upstream in the extension source files.

### 4. CLAUDE.md Adaptive Reference Pattern

#### Current Design

The core CLAUDE.md contains hardcoded references to ALL extension-provided elements (routing tables, skill mappings, context imports). This means the core CLAUDE.md must be updated whenever extensions change.

#### Recommended Adaptive Pattern

CLAUDE.md should reference index.json as the single source of truth for extension-provided capabilities. The core CLAUDE.md should contain:

1. **Core routing table**: Only general, meta, markdown languages
2. **Core skill-to-agent mapping**: Only 5 core agents
3. **Core rules references**: Only 5 core rules
4. **Adaptive discovery directive**: Tell agents to query index.json for domain-specific context

Extensions inject their own sections via `<!-- SECTION: extension_* -->` markers, which add:
- Language routing entries
- Skill-to-agent mappings
- Context import references
- Domain-specific instructions

This is already the design -- it just needs the core CLAUDE.md to be trimmed to contain ONLY core content.

### 5. Loader Architecture Analysis

#### Module Structure

```
neotex/plugins/ai/
  shared/extensions/
    init.lua       -- Public API factory (M.create(config) -> manager)
    config.lua     -- System configuration presets (claude/opencode)
    manifest.lua   -- Extension manifest parsing/validation
    loader.lua     -- File copy engine
    merge.lua      -- Merge strategies (section injection, settings, index)
    state.lua      -- Extension state tracking (extensions.json)
  claude/extensions/
    config.lua     -- Claude config wrapper
    loader.lua     -- Delegates to shared loader
    state.lua      -- Claude state wrapper
    picker.lua     -- Telescope picker UI
    init.lua       -- Claude extension manager instance
  opencode/extensions/
    (mirrors claude/ with opencode config)
```

#### Strengths
- Clean parameterized design supporting both Claude and OpenCode
- Atomic rollback on load failure (pcall + cleanup)
- File-level backup before merge operations
- Idempotent section injection (updates if exists, appends if not)
- Deduplication in index.json appending
- Conflict detection before loading

#### Identified Improvements

1. **No verification after load**: The loader copies files and merges content but does not verify the result is valid (e.g., that CLAUDE.md still parses correctly, that index.json has valid JSON, that all referenced context files exist on disk)

2. **Path normalization in wrong layer**: `normalize_index_path()` is a defensive workaround in merge.lua. The canonical fix is to ensure extension index-entries.json files use correct paths at source.

3. **No batch load/unload**: Loading 11 extensions requires 11 confirmation dialogs. A "load all" or "load profile" capability would improve UX.

4. **extensions.json tracks absolute paths**: `installed_files` contains absolute paths like `/home/benjamin/Projects/Logos/Vision/.claude/agents/neovim-research-agent.md`. This breaks portability if the project moves.

5. **No validation of loaded state**: After reload, no check that all expected files are present and match expected content. A verification pass would catch missing or corrupted files.

6. **settings.local.json backup accumulation**: Each load creates a `.backup` file that is never cleaned up.

### 6. Extension Detection and Discovery

Extensions are discovered from a global directory (`~/.config/nvim/.claude/extensions/`). Each extension has:

```
extensions/{name}/
  manifest.json       -- Name, version, provides, merge_targets
  EXTENSION.md        -- CLAUDE.md section content
  index-entries.json  -- Context index entries to merge
  agents/             -- Agent definitions
  skills/             -- Skill directories
  rules/              -- Rule files
  context/            -- Context files (preserving project/* structure)
  scripts/            -- Shell scripts
```

This is a clean, well-organized structure.

## Decisions

1. **Core should contain only core elements**: The current state where ALL extension files are committed to the core Vision system defeats the purpose of extensions. Core should have ~5 agents, ~10 skills, ~5 rules, and only core context.

2. **index.json path format should be canonical**: All paths should use `project/*` or `core/*` format without any `.claude/context/` or `context/` prefix.

3. **CLAUDE.md should be adaptive**: Core CLAUDE.md should contain only core references. Extension-provided content appears only via injected sections.

4. **Loader improvements should focus on**: Batch loading, path normalization at source, post-load verification, and relative path tracking.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Removing extension files from core breaks projects without extension loading | High | Run extension loader immediately after checkout; add setup script |
| Path normalization changes break existing index.json queries | Medium | Normalize all paths in a single migration, update all index-entries.json |
| Large CLAUDE.md from 11 extensions causes context window issues | Medium | Extension sections are injected at end; Claude reads top-down with priority |
| Backup files (.backup) accumulate on disk | Low | Add cleanup to /refresh command |

## Appendix

### Files Examined

- `/home/benjamin/Projects/Logos/Vision/.claude/` (core system)
- `/home/benjamin/Projects/Logos/Vision/.claude_ext/` (extended system)
- `/home/benjamin/Projects/Logos/Vision/.opencode/` (core opencode)
- `/home/benjamin/Projects/Logos/Vision/.opencode_ext/` (extended opencode)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/` (loader engine)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/extensions/` (claude wrappers)
- `/home/benjamin/.config/nvim/.claude/extensions/*/manifest.json` (extension manifests)

### Core Elements Inventory (Post-Cleanup)

After removing extension-provided content, the core system should contain:

| Category | Count | Elements |
|----------|-------|----------|
| Agents | 4 | general-research, general-implementation, planner, meta-builder |
| Skills | ~10 | implementer, researcher, planner, meta, status-sync, refresh, orchestrator, git-workflow, learn, tag |
| Rules | 5 | artifact-formats, error-handling, git-workflow, state-management, workflows |
| Context (core/) | ~9 | routing, checkpoints, formats, patterns |
| Context (project/) | ~4 | meta/, repo/, hooks/, processes/ |
| Commands | All core commands | task, research, plan, implement, revise, review, todo, errors, meta, learn, refresh |
