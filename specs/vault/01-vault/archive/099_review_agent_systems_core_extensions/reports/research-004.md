# Research Report: Task #99 (Supplementary - Simplified Extension Architecture)

**Task**: 99 - review_agent_systems_core_extensions
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T04:00:00Z
**Effort**: 4-6 hours
**Dependencies**: research-001.md (initial comparison), research-002.md (direct integration), research-003.md (native plugin system)
**Sources/Inputs**: Codebase exploration (picker system, sync module, scan module, keymaps, which-key, config module), previous research reports
**Artifacts**: specs/099_review_agent_systems_core_extensions/reports/research-004.md
**Standards**: report-format.md

## Executive Summary

- The existing `<leader>ac` picker system (`sync.lua`, `scan.lua`, `edit.lua`) already implements a complete global-to-local artifact sync engine that copies files by category with merge/replace strategies, permission preservation, and user confirmation -- this is the direct foundation for extension loading
- The user has decided AGAINST the Claude Code native plugin system (research-003) due to maintenance overhead of managing separate plugins; the architecture should use simple file copying from extension directories into the target `.claude/`
- Extensions should live at `.claude/extensions/{name}/` in the global source directory (`~/.config/nvim/.claude/extensions/`), each containing a `manifest.json` and standard `.claude/` subdirectories (agents/, skills/, commands/, rules/, context/, scripts/)
- The `<leader>ac` picker should be enhanced with an `[Extensions]` section showing available extensions with active/inactive status, plus a dedicated `<leader>ae` keybinding for focused extension management
- File merge strategies vary by file type: simple copy for agents/skills/commands/rules/scripts, JSON deep-merge for `settings.json` fragments, section-marker insertion for CLAUDE.md, and entry append for `index.json`
- Extension state tracking via `.claude/extensions.json` in the target repo records which extensions are loaded and which files were installed, enabling clean unloading

## Context & Scope

This is the FOURTH research report, synthesizing findings from the previous three reports into a simplified, user-approved architecture. The user explicitly rejected:
- Symlink-based extensions (research-001 plan)
- Claude Code native plugin system (research-003) -- too much maintenance overhead

The approved architecture is:
1. Core system in `nvim/.claude/` -- copied to any repo via `<leader>ac` Load All
2. Extensions in `nvim/.claude/extensions/` -- optional domain-specific packs
3. Extension loading via enhanced `<leader>ac` picker -- file copying into target `.claude/`

## Findings

### A. Current `<leader>ac` Implementation

#### Keymap Wiring

The `<leader>ac` keymap is defined in `lua/neotex/plugins/editor/which-key.lua` (line 242):

```lua
-- Normal mode: opens ClaudeCommands picker
{ "<leader>ac", "<cmd>ClaudeCommands<CR>", desc = "claude commands", icon = "..." },

-- Visual mode: sends selection to Claude with prompt
{ "<leader>ac",
  function() require("neotex.plugins.ai.claude.core.visual").send_visual_to_claude_with_prompt() end,
  desc = "send selection to claude with prompt",
  mode = { "v" },
```

#### Picker Architecture

The picker is a modular Telescope-based system:

```
which-key.lua ("<leader>ac")
  -> :ClaudeCommands user command
    -> claude/init.lua:show_commands_picker()
      -> commands/picker.lua:show_commands_picker() [facade]
        -> commands/picker/init.lua:show_commands_picker() [implementation]
```

**Module breakdown**:

| Module | Path | Purpose |
|--------|------|---------|
| `init.lua` | `commands/picker/init.lua` | Main Telescope picker orchestration, keybinding dispatch |
| `entries.lua` | `commands/picker/display/entries.lua` | Creates categorized picker entries with tree formatting |
| `previewer.lua` | `commands/picker/display/previewer.lua` | Preview pane content for selected artifacts |
| `sync.lua` | `commands/picker/operations/sync.lua` | Load All Artifacts and per-artifact sync operations |
| `edit.lua` | `commands/picker/operations/edit.lua` | File editing, save-to-global, load-locally operations |
| `terminal.lua` | `commands/picker/operations/terminal.lua` | Command execution in terminal |
| `scan.lua` | `commands/picker/utils/scan.lua` | Directory scanning, artifact merging, global dir lookup |
| `helpers.lua` | `commands/picker/utils/helpers.lua` | File I/O, permissions, notifications, formatting |
| `metadata.lua` | `commands/picker/artifacts/metadata.lua` | Parse artifact descriptions from file headers |
| `registry.lua` | `commands/picker/artifacts/registry.lua` | Artifact type definitions and categorization |
| `parser.lua` | `commands/parser.lua` | Full `.claude/` structure discovery (commands, skills, agents, hooks, root files) |

#### Current Picker Actions

| Key | Action | Description |
|-----|--------|-------------|
| Enter | Context-aware | Execute command, edit file, or trigger special action |
| Ctrl-l | Load locally | Copy global artifact to project `.claude/` (with dependencies) |
| Ctrl-u | Update from global | Replace local artifact with latest global version |
| Ctrl-s | Save to global | Copy local artifact to global directory |
| Ctrl-e | Edit file | Open artifact in editor |
| Ctrl-n | New command | Create new command file |
| Ctrl-r | Run script | Execute script with argument prompt |
| Ctrl-t | Run test | Execute test file |

#### Current Entry Categories (in display order, top to bottom)

1. `[Commands]` -- Slash commands with dependent sub-commands
2. `[Root Files]` -- CLAUDE.md, settings.json, .gitignore
3. `[Agents]` -- AI agent definitions
4. `[Skills]` -- Model-invoked capabilities
5. `[Hook Events]` -- Event-triggered scripts
6. `[Tests]` -- Test suites
7. `[Scripts]` -- Standalone CLI tools
8. `[Templates]` -- Workflow templates
9. `[Lib]` -- Utility libraries
10. `[Docs]` -- Integration guides
11. `[Load All Artifacts]` -- Sync all from global
12. `[Keyboard Shortcuts]` -- Help

#### Global Source Directory

Configured in `claude/config.lua`:

```lua
M.defaults = {
  global_source_dir = vim.fn.expand("~/.config/nvim"),
}
```

This means `scan.get_global_dir()` returns `~/.config/nvim`, and all sync operations use `~/.config/nvim/.claude/` as the source.

#### Sync Engine (sync.lua)

The `load_all_globally()` function is the closest existing analog to extension loading. It:

1. Gets `project_dir` (cwd) and `global_dir` (~/.config/nvim)
2. Calls `scan_all_artifacts()` which scans 15 artifact categories:
   - commands, hooks, templates, lib, docs, scripts, tests, skills, agents, rules, context, output, systemd, settings, root_files
3. For each category, `scan.scan_directory_for_sync()` compares source and target, marking each file as "copy" (new) or "replace" (exists)
4. Presents user with dialog: "Sync all (replace existing)" vs "Add new only" vs "Cancel"
5. Calls `execute_sync()` which copies files preserving directory structure and permissions
6. Reports detailed counts per category

**Key insight**: This sync engine already handles recursive subdirectory scanning, permission preservation for shell scripts, merge-only mode, and user confirmation. It IS essentially an extension loader -- the only adaptation needed is changing the source from `global_dir/.claude/` to `global_dir/.claude/extensions/{name}/`.

### B. Extension Picker Enhancement Design

#### Recommended Approach: Dual Integration

1. **Add `[Extensions]` section to existing `<leader>ac` picker** -- for quick visibility of extension status alongside other artifacts
2. **Add `<leader>ae` for dedicated extension management** -- for toggle, details, and configuration operations

#### `<leader>ac` Enhancement

Add a new `create_extensions_entries()` function in `entries.lua` following the established pattern. Entries would show:

```
[Extensions]                        Extension packs
  lean       [active]               Lean 4 formal verification
  neovim     [active]               Neovim development
  latex      [inactive]             LaTeX document authoring
```

Enter on an extension entry would navigate to `<leader>ae` focused on that extension. This provides visibility without cluttering the picker with management operations.

#### `<leader>ae` Dedicated Picker

A new Telescope picker specifically for extension management:

```lua
-- In which-key.lua, under the <leader>a group:
{ "<leader>ae", function() require("neotex.plugins.ai.claude.extensions.picker").show() end,
  desc = "claude extensions", icon = "..." },
```

Actions:
- Enter: Toggle extension active/inactive (runs load/unload)
- Ctrl-i: Show manifest details in preview
- Ctrl-d: Show installed files list
- Ctrl-r: Reload extension (unload + load)

#### Multi-select for Initial Setup

For the first-time loading scenario where a user copies `.claude/` to a new repo and wants to enable multiple extensions, the picker should support multi-select (Tab to select, Enter to apply). This matches Telescope's built-in `actions.toggle_selection` pattern.

#### Order of Operations

When loading core + extensions to a new project:

1. User presses `<leader>ac`, selects `[Load All Artifacts]` -- copies core system
2. User presses `<leader>ae` -- sees available extensions
3. User multi-selects desired extensions (Tab on each, Enter to apply)
4. Extension loader processes each selected extension:
   a. Read manifest.json
   b. Check/resolve dependencies (load required extensions first)
   c. Copy files to target `.claude/`
   d. Merge settings fragment
   e. Append index.json entries
   f. Insert CLAUDE.md sections
   g. Update extensions.json tracking

### C. Extension Manifest Format

#### Directory Structure

```
.claude/extensions/
  lean/
    manifest.json           # Extension metadata and file declarations
    agents/                 # Lean-specific agents
      lean-research-agent.md
      lean-implementation-agent.md
    skills/                 # Lean-specific skills
      skill-lean-research/
        SKILL.md
      skill-lean-implementation/
        SKILL.md
      skill-lake-repair/
        SKILL.md
      skill-lean-version/
        SKILL.md
    commands/               # Lean-specific commands
      lake.md
      lean.md
    rules/                  # Lean-specific rules
      lean4.md
    context/                # Lean-specific context (preserves subdirectory structure)
      project/
        lean4/
          domain/
            lean-tactics.md
            lean-mathlib.md
          patterns/
            proof-patterns.md
          standards/
            lean-style-guide.md
          tools/
            lake-guide.md
    scripts/                # Lean-specific scripts
      setup-lean-mcp.sh
      verify-lean-mcp.sh
    hooks/                  # Lean-specific hooks
      hooks.json
      scripts/
        lean-post-tool.sh
    claudemd-section.md     # CLAUDE.md section to inject
    settings-fragment.json  # Settings to merge
    index-entries.json      # Context index entries to append
```

#### manifest.json Schema

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 formal verification support",
  "language": "lean",
  "dependencies": [],
  "provides": {
    "agents": [
      "lean-research-agent.md",
      "lean-implementation-agent.md"
    ],
    "skills": [
      "skill-lean-research",
      "skill-lean-implementation",
      "skill-lake-repair",
      "skill-lean-version"
    ],
    "commands": [
      "lake.md",
      "lean.md"
    ],
    "rules": [
      "lean4.md"
    ],
    "context_dirs": [
      "project/lean4/"
    ],
    "scripts": [
      "setup-lean-mcp.sh",
      "verify-lean-mcp.sh"
    ],
    "hooks": true
  },
  "merge_targets": {
    "claudemd_section": "claudemd-section.md",
    "settings_fragment": "settings-fragment.json",
    "index_entries": "index-entries.json"
  },
  "mcp_servers": {
    "lean-lsp": {
      "required": true,
      "setup_script": "scripts/setup-lean-mcp.sh",
      "verify_script": "scripts/verify-lean-mcp.sh"
    }
  }
}
```

**Field descriptions**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique extension identifier (kebab-case) |
| `version` | string | Yes | Semantic version for tracking updates |
| `description` | string | Yes | Brief description shown in picker |
| `language` | string | No | Primary language this extension supports |
| `dependencies` | array | No | Other extension names that must be loaded first |
| `provides` | object | Yes | Declares all files/directories to copy |
| `provides.agents` | array | No | Agent .md files in agents/ directory |
| `provides.skills` | array | No | Skill directory names in skills/ directory |
| `provides.commands` | array | No | Command .md files in commands/ directory |
| `provides.rules` | array | No | Rule .md files in rules/ directory |
| `provides.context_dirs` | array | No | Context subdirectory paths (copied recursively) |
| `provides.scripts` | array | No | Script .sh files in scripts/ directory |
| `provides.hooks` | boolean | No | Whether hooks/hooks.json and hook scripts exist |
| `merge_targets` | object | No | Files that require merge operations (not simple copy) |
| `merge_targets.claudemd_section` | string | No | Path to CLAUDE.md section file to inject |
| `merge_targets.settings_fragment` | string | No | Path to settings fragment to deep-merge |
| `merge_targets.index_entries` | string | No | Path to index.json entries to append |
| `mcp_servers` | object | No | MCP server setup/verification metadata |

### D. File Merge Strategies

Different file types require different merge approaches when loading extensions.

#### Strategy Matrix

| Target | Strategy | Details |
|--------|----------|---------|
| `.claude/agents/*.md` | Simple copy | New file; skip if exists with warning |
| `.claude/skills/skill-*/` | Directory copy | Copy entire skill directory |
| `.claude/commands/*.md` | Simple copy | New file; skip if exists with warning |
| `.claude/rules/*.md` | Simple copy | New file; skip if exists with warning |
| `.claude/context/**` | Recursive copy | Preserve subdirectory structure |
| `.claude/scripts/*.sh` | Copy + permissions | Preserve execute permissions |
| `.claude/hooks/` | Hook merge | Merge hooks.json arrays, copy scripts |
| `CLAUDE.md` | Section injection | Insert between markers |
| `.claude/settings.json` | Deep merge | Additive merge of specific keys |
| `.claude/context/index.json` | Entry append | Append entries array |
| `.claude/settings.local.json` | Deep merge | MCP servers, local overrides |

#### Simple Copy (agents, skills, commands, rules, scripts)

Uses the existing `sync_files()` pattern from `sync.lua`:

1. Check if target file exists
2. If not: copy from extension directory
3. If exists: warn user, offer skip/overwrite
4. For .sh files: preserve execute permissions via `helpers.copy_file_permissions()`

#### CLAUDE.md Section Injection

Extensions provide a `claudemd-section.md` file containing a complete section with markers:

```markdown
<!-- SECTION: extension_lean -->
## Lean Extension

### Language Routing
| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `lean` | WebSearch, WebFetch, Read, mcp__lean-lsp__* | Read, Write, Edit, Bash, mcp__lean-lsp__* |

### Skill-to-Agent Mapping
| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-lean-research | lean-research-agent | Lean/Mathlib research |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |
<!-- END_SECTION: extension_lean -->
```

**Load operation**:
1. Read target CLAUDE.md
2. Check if section marker already exists (idempotent)
3. If not: find insertion point (before `## Important Notes` or at end)
4. Insert section content
5. Write updated CLAUDE.md

**Unload operation**:
1. Read target CLAUDE.md
2. Find `<!-- SECTION: extension_{name} -->` and `<!-- END_SECTION: extension_{name} -->`
3. Remove everything between and including markers
4. Write updated CLAUDE.md

#### Settings Fragment Merge

The `settings-fragment.json` contains keys to deep-merge into `settings.json` and/or `settings.local.json`:

```json
{
  "target": "settings.local.json",
  "merge": {
    "permissions": {
      "allow": [
        "mcp__lean-lsp__*"
      ]
    },
    "mcpServers": {
      "lean-lsp": {
        "command": "npx",
        "args": ["-y", "lean4-mcp-server", "--project-path", "."],
        "disabled": false
      }
    }
  }
}
```

**Merge algorithm**:
1. Read target settings file
2. For arrays (e.g., `permissions.allow`): append new entries, deduplicate
3. For objects (e.g., `mcpServers`): add new keys, do not overwrite existing
4. Write merged result

**Unload**: Remove only keys/entries that came from the extension. This requires tracking which entries were added, stored in `extensions.json`.

#### Index.json Entry Append

The `index-entries.json` contains pre-built entries matching the `index.schema.json` format:

```json
{
  "entries": [
    {
      "path": "project/lean4/domain/lean-tactics.md",
      "domain": "project",
      "subdomain": "lean4",
      "topics": ["lean", "tactics", "mathlib"],
      "keywords": ["tactic", "proof", "simp", "omega"],
      "summary": "Lean 4 tactic reference and usage patterns",
      "line_count": 200,
      "load_when": {
        "agents": ["lean-research-agent", "lean-implementation-agent"],
        "languages": ["lean"]
      }
    }
  ]
}
```

**Load**: Append entries to `index.json`'s `entries` array (dedup by path).
**Unload**: Remove entries where path starts with the extension's context prefix.

#### Hook Merge

Hooks require special handling because `hooks.json` is a JSON object with event-based arrays:

1. Read extension's `hooks/hooks.json`
2. Read target's `.claude/settings.json` (hooks section) or `.claude/hooks/` directory
3. For each hook event: append extension's hooks to the event array
4. Copy hook scripts to target hooks directory
5. Track added hooks for clean unloading

### E. Extension State Tracking

#### Target-Repo Tracking File: `.claude/extensions.json`

When extensions are loaded into a target repo, create/update `.claude/extensions.json`:

```json
{
  "schema_version": "1.0.0",
  "source_dir": "~/.config/nvim",
  "loaded_at": "2026-03-01T12:00:00Z",
  "extensions": {
    "lean": {
      "version": "1.0.0",
      "active": true,
      "loaded_at": "2026-03-01T12:00:00Z",
      "source_path": ".claude/extensions/lean",
      "installed_files": [
        ".claude/agents/lean-research-agent.md",
        ".claude/agents/lean-implementation-agent.md",
        ".claude/skills/skill-lean-research/SKILL.md",
        ".claude/skills/skill-lean-implementation/SKILL.md",
        ".claude/skills/skill-lake-repair/SKILL.md",
        ".claude/skills/skill-lean-version/SKILL.md",
        ".claude/commands/lake.md",
        ".claude/commands/lean.md",
        ".claude/rules/lean4.md",
        ".claude/scripts/setup-lean-mcp.sh",
        ".claude/scripts/verify-lean-mcp.sh"
      ],
      "installed_dirs": [
        ".claude/context/project/lean4/"
      ],
      "merged_sections": {
        "claudemd": "extension_lean",
        "settings_entries": [
          "permissions.allow:mcp__lean-lsp__*",
          "mcpServers:lean-lsp"
        ],
        "index_paths": [
          "project/lean4/domain/lean-tactics.md",
          "project/lean4/domain/lean-mathlib.md"
        ]
      }
    }
  }
}
```

**Purpose of each tracking field**:

| Field | Purpose |
|-------|---------|
| `version` | Detect when global extension has been updated |
| `active` | Current active/inactive state |
| `loaded_at` | When extension was last loaded |
| `source_path` | Where the extension came from (for updates) |
| `installed_files` | Exact files copied, for clean removal |
| `installed_dirs` | Directories created, for clean removal |
| `merged_sections` | What was merged into shared files, for clean unmerging |

#### Update Detection

When the user opens `<leader>ae`, the picker compares:
- `extensions.json` version vs `manifest.json` version
- If manifest version is newer: show "[update available]" indicator
- User can Ctrl-r to reload (unload old, load new)

#### Gitignore Considerations

In the target repo, `extensions.json` should typically be gitignored since it tracks local extension state. Add to `.claude/.gitignore`:

```
extensions.json
```

However, for projects where the team wants consistent extension sets, it could be committed. This is a per-project decision.

### F. Practical Extension Mapping

#### What Belongs in Core vs Extensions

Based on analysis of the existing `.claude/` system:

**Core (always copied via Load All)**:

| Category | Files | Rationale |
|----------|-------|-----------|
| Commands | /task, /research, /plan, /implement, /revise, /review, /todo, /errors, /meta, /learn, /refresh | Universal workflow commands |
| Skills | skill-researcher, skill-planner, skill-implementer, skill-meta, skill-status-sync, skill-refresh, skill-git-workflow, skill-orchestrator, skill-learn, skill-document-converter | Language-agnostic capabilities |
| Agents | general-research-agent, general-implementation-agent, planner-agent, meta-builder-agent, document-converter-agent | Core agents |
| Rules | state-management, git-workflow, error-handling, artifact-formats, workflows | System rules |
| Context | core/*, project/repo/*, project/meta/* | Core patterns and project structure |
| Lib | All library files | Infrastructure |
| Docs | All documentation | System documentation |
| Scripts | All scripts | Utilities |
| Tests | All tests | Validation |

**Extension: lean/**:

| Category | Files | Source |
|----------|-------|-------|
| Commands | /lake, /lean | ProofChecker-specific |
| Skills | skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version | ProofChecker-specific |
| Agents | lean-research-agent, lean-implementation-agent | ProofChecker-specific |
| Rules | lean4.md | Lean coding conventions |
| Context | project/lean4/** | Lean domain knowledge |
| Scripts | setup-lean-mcp.sh, verify-lean-mcp.sh | MCP setup |
| Settings | mcpServers.lean-lsp, permissions for mcp__lean-lsp__* | MCP configuration |

**Extension: neovim/**:

| Category | Files | Source |
|----------|-------|-------|
| Skills | skill-neovim-research, skill-neovim-implementation | Neovim-specific |
| Agents | neovim-research-agent, neovim-implementation-agent | Neovim-specific |
| Rules | neovim-lua.md | Lua coding conventions |
| Context | project/neovim/** | Neovim domain knowledge (API, plugins, keymaps) |
| Settings | (none) | No special MCP servers needed |

**Extension: latex/**:

| Category | Files | Source |
|----------|-------|-------|
| Skills | skill-latex-implementation | Already in core |
| Agents | latex-implementation-agent | Already in core |
| Rules | latex.md | LaTeX conventions |
| Context | project/latex/** | LaTeX domain knowledge |
| Settings | (none) | No special MCP servers |

**Extension: typst/**:

| Category | Files | Source |
|----------|-------|-------|
| Skills | skill-typst-implementation | Already in core |
| Agents | typst-implementation-agent | Already in core |
| Context | project/typst/** | Typst domain knowledge |
| Settings | (none) | No special MCP servers |

**Decision point**: LaTeX and Typst agents/skills are currently in the core system. They should be migrated to extensions since they are domain-specific. This is a cleanup task separate from the extension system implementation.

#### Migration Path

Moving existing domain-specific files to extensions:

1. Create `extensions/lean/` with manifest, move Lean files from ProofChecker's `.claude/`
2. Create `extensions/neovim/` with manifest, identify neovim-specific files from current core
3. Create `extensions/latex/` with manifest, extract latex-specific files from current core
4. Create `extensions/typst/` with manifest, extract typst-specific files from current core
5. Update core to remove domain-specific files that are now in extensions
6. Verify Load All still works (only copies core)
7. Verify extension loading works (adds domain files)

## Decisions

1. **File copying (not plugins, not symlinks)** -- User requirement; simplest approach, proven by sync.lua
2. **Extensions inside `.claude/extensions/`** -- Self-contained, travels with the core system
3. **Dual picker integration** -- `[Extensions]` section in `<leader>ac` for visibility, `<leader>ae` for management
4. **Manifest.json per extension** -- Declares files to copy and merge targets
5. **`extensions.json` in target repo** -- Tracks loaded state for clean unloading and update detection
6. **Section markers for CLAUDE.md** -- Clean insertion/removal, already a pattern in the project
7. **Pre-built index entries** -- Avoids expensive index regeneration on every toggle
8. **Settings fragment deep-merge** -- Additive only, tracked for clean unmerging
9. **Multi-select in extension picker** -- Enables loading multiple extensions at once during initial setup

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| File conflicts between extensions | High -- two extensions provide same agent name | Manifest validation on load, prefix convention per extension |
| CLAUDE.md section markers get corrupted by manual editing | Medium -- extension unload fails to clean up | Validate marker pairs before operations, fall back to manual cleanup instructions |
| Settings merge creates invalid JSON | High -- Claude Code fails to start | Validate JSON after merge, backup original before merge |
| Extension files modified locally, then overwritten on update | Medium -- user loses customizations | Checksum comparison on update, warn before overwriting modified files |
| Large extensions slow picker startup | Low -- one-time manifest read | Cache manifest data in memory |
| Core/extension boundary is unclear | Medium -- files in wrong place | Document the boundary criteria clearly, provide migration script |
| Circular dependencies between extensions | Low -- unlikely with domain-specific extensions | Validate dependency graph on load, reject cycles |

## Recommendations

### Implementation Priority

**Phase 1: Extension Infrastructure** (foundation)
- Create `.claude/extensions/` directory in global source
- Define manifest.json schema (as documented above)
- Create `extensions.lua` module with load/unload engine (adapt sync.lua patterns)
- Create `extensions.json` tracking format

**Phase 2: Build First Extensions** (validation)
- Create `extensions/lean/` from ProofChecker's Lean-specific files
- Create `extensions/neovim/` from nvim-specific files
- Write manifest.json for each
- Create claudemd-section.md, settings-fragment.json, index-entries.json for each

**Phase 3: Picker Integration** (user interface)
- Add `create_extensions_entries()` to entries.lua
- Create `extensions/picker.lua` for dedicated `<leader>ae` picker
- Register `<leader>ae` in which-key.lua
- Implement multi-select toggle behavior

**Phase 4: Merge Engine** (advanced operations)
- Implement CLAUDE.md section injection/removal
- Implement settings.json deep-merge/unmerge
- Implement index.json entry append/remove
- Implement hooks merge

**Phase 5: Core Cleanup** (optimization)
- Migrate domain-specific files from core to extensions
- Update Load All to only copy core files
- Update documentation

### Key Technical Decisions for Implementation

1. **New Lua module location**: `lua/neotex/plugins/ai/claude/extensions/` with init.lua, loader.lua, picker.lua, manifest.lua
2. **Reuse sync.lua patterns**: The file copying logic in sync.lua should be extracted into shared helpers or the extension loader should call scan/sync functions directly
3. **Extension source**: `scan.get_global_dir() .. "/.claude/extensions/"` -- uses same config as existing sync
4. **Picker entry format**: Follow the `format_display()` pattern from helpers.lua with `[active]`/`[inactive]` status indicators

## Appendix

### Search Methodology

1. Read `<leader>ac` keymap chain: which-key.lua -> ClaudeCommands -> init.lua -> picker modules
2. Analyzed complete sync.lua, scan.lua, edit.lua, helpers.lua for reusable patterns
3. Read config.lua for global_source_dir configuration
4. Read entries.lua for picker entry creation patterns (all 12 categories)
5. Read previous research reports (001, 002, 003) for context and decisions
6. Examined existing repos (Training, TODO) for .claude/ structure patterns
7. Read context/index.json for entry format
8. Examined which-key.lua for keybinding registration patterns

### Key Files Examined

| File | Path | Relevance |
|------|------|-----------|
| `init.lua` | `commands/picker/init.lua` | Picker orchestration, keybinding template |
| `entries.lua` | `commands/picker/display/entries.lua` | Entry creation pattern for new [Extensions] section |
| `sync.lua` | `commands/picker/operations/sync.lua` | Load All engine -- direct foundation for extension loading |
| `edit.lua` | `commands/picker/operations/edit.lua` | Per-artifact load/save -- dependency resolution pattern |
| `scan.lua` | `commands/picker/utils/scan.lua` | Directory scanning, merge artifacts -- reusable for extensions |
| `helpers.lua` | `commands/picker/utils/helpers.lua` | File I/O, permissions, notifications -- shared utilities |
| `config.lua` | `claude/config.lua` | Global source dir config, extension config point |
| `which-key.lua` | `plugins/editor/which-key.lua` | Keybinding registration for `<leader>ae` |
| `index.json` | `.claude/context/index.json` | Entry format for extension context integration |
| `research-002.md` | `specs/099_*/reports/` | Previous extension architecture (manifest schema baseline) |
| `research-003.md` | `specs/099_*/reports/` | Plugin system analysis (rejected, but informs manifest design) |
