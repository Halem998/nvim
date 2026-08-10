# Research Report: Task #103 (Supplement)

**Task**: 103 - Compare .opencode agent systems against .claude (Extensions Focus)
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T01:00:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (Glob, Read, Grep, Bash)
**Artifacts**: This report (supplements research-001.md)
**Standards**: report-format.md

## Executive Summary

- The `.claude/extensions/` system is a fully-featured package manager implemented in ~1,200 lines of Lua across 6 modules (init, loader, manifest, merge, state, picker), providing load/unload/reload operations with conflict detection, state tracking, and reversible merge operations
- Five extensions exist today: **lean**, **latex**, **typst**, **z3**, **python** -- each containing agents, skills, rules, context, and (optionally) commands, scripts, MCP servers, and settings fragments
- The `<leader>ae` keybinding opens a Telescope picker (`ClaudeExtensions` command) that shows all available extensions with status indicators (active/inactive/update-available), supports load/unload toggle on Enter, reload via Ctrl-r, and detailed file list via Ctrl-d
- The `<leader>ac` keybinding opens a separate `ClaudeCommands` picker for slash command browsing, while `<leader>ao` is currently unused and available for opencode extension management
- To create a parallel system under `<leader>ao` for opencode, the key components needed are: (1) an extensions directory structure under `.opencode/extensions/`, (2) a manifest/loader system adapted for opencode's agent frontmatter and settings.json format, (3) a Telescope picker module, (4) a `web/` extension as the first domain extension, and (5) which-key integration under `<leader>ao`

## Context and Scope

This supplementary report focuses specifically on the `.claude/extensions/` system architecture to inform the design of a parallel `.opencode/extensions/` system accessible via `<leader>ao`. It covers:

1. The complete extension architecture (manifest format, loader, merge strategies, state tracking)
2. The Neovim integration layer (Telescope picker, which-key bindings, vim commands)
3. What exists in `.opencode/` that would map to extensions
4. A roadmap for creating the parallel system

## Findings

### 1. Extension Architecture Deep Dive

The `.claude/extensions/` system consists of 6 Lua modules under `lua/neotex/plugins/ai/claude/extensions/`:

```
extensions/
  init.lua          -- Public API: load(), unload(), reload(), list_available(), get_details()
  manifest.lua      -- Manifest parsing, validation, extension discovery
  loader.lua        -- File copy engine (agents, skills, commands, rules, context, scripts)
  merge.lua         -- Reversible merge strategies for shared files
  state.lua         -- State tracking via extensions.json per project
  picker.lua        -- Telescope-based UI for extension management
```

#### 1.1 Manifest Format (manifest.json)

Each extension lives in `.claude/extensions/{name}/` and must contain a `manifest.json`:

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 theorem prover support with MCP integration",
  "language": "lean4",
  "dependencies": [],
  "provides": {
    "agents": ["lean-research-agent.md", "lean-implementation-agent.md"],
    "skills": ["skill-lean-research", "skill-lean-implementation", "skill-lake-repair", "skill-lean-version"],
    "commands": ["lake.md", "lean.md"],
    "rules": ["lean4.md"],
    "context": ["project/lean4"],
    "scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_lean"
    },
    "settings": {
      "source": "settings-fragment.json",
      "target": ".claude/settings.local.json"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {
    "lean-lsp": {
      "command": "npx",
      "args": ["-y", "lean-lsp-mcp@latest"]
    }
  }
}
```

**Valid provides categories**: agents, skills, commands, rules, context, scripts, hooks
**Valid merge target types**: claudemd, settings, index

#### 1.2 Extension Anatomy

Each extension contains a subset of these items:

| Item | Required | Description | Example |
|------|----------|-------------|---------|
| `manifest.json` | Yes | Package manifest with metadata and provides | See above |
| `EXTENSION.md` | No | Section injected into CLAUDE.md when loaded | Language routing, skill-agent mapping |
| `settings-fragment.json` | No | Merged into settings.local.json (MCP, permissions) | Lean MCP server + tool permissions |
| `index-entries.json` | No | Context discovery entries appended to index.json | Agent-to-context mappings |
| `agents/` | No | Agent definition files (.md) | lean-research-agent.md |
| `skills/` | No | Skill directories with SKILL.md | skill-lean-research/ |
| `commands/` | No | Slash command definitions (.md) | lake.md, lean.md |
| `rules/` | No | Rule files (.md) | lean4.md |
| `context/` | No | Context files (preserving subdirectory structure) | project/lean4/**/*.md |
| `scripts/` | No | Utility scripts (.sh) | setup-lean-mcp.sh |

**Counts by extension**:

| Extension | Agents | Skills | Commands | Rules | Context Files | Scripts | MCP Servers |
|-----------|--------|--------|----------|-------|---------------|---------|-------------|
| lean | 2 | 4 | 2 | 1 | 21 | 2 | 1 (lean-lsp) |
| latex | 2 | 2 | 0 | 1 | 3 | 0 | 0 |
| typst | 2 | 2 | 0 | 0 | 3 | 0 | 0 |
| z3 | 2 | 2 | 0 | 0 | 3 | 0 | 0 |
| python | 2 | 2 | 0 | 0 | 3 | 0 | 0 |

#### 1.3 Load/Unload Lifecycle

**Loading an extension** (`extensions.load(name)`):
1. Find extension in global directory (`~/.config/nvim/.claude/extensions/{name}/`)
2. Read and validate manifest
3. Check if already loaded (via `extensions.json` in target project)
4. Check for file conflicts in target `.claude/` directory
5. Present confirmation dialog (shows provides summary)
6. Copy files by category: agents -> commands -> rules -> skills -> context -> scripts
7. Process merge targets: inject CLAUDE.md section, merge settings, append index entries
8. Write state to `{project}/.claude/extensions.json`

**Unloading an extension** (`extensions.unload(name)`):
1. Verify extension is loaded (from extensions.json)
2. Get installed files and merged sections from state
3. Present confirmation dialog
4. Reverse merge operations (remove CLAUDE.md section, unmerge settings, remove index entries)
5. Delete installed files; remove empty directories (deepest first)
6. Update extensions.json

**Key design insight**: All operations are reversible. The state file tracks every file installed and every merge operation performed, enabling clean unload.

#### 1.4 Merge Strategies

Three merge strategies handle shared configuration files:

**CLAUDE.md Section Injection**:
- Uses HTML comment markers: `<!-- SECTION: extension_lean -->` ... `<!-- END_SECTION: extension_lean -->`
- Idempotent: updates existing section if markers found, appends if not
- Clean removal: strips section including markers and normalizes whitespace

**Settings Deep Merge** (settings.local.json):
- Arrays are appended (with deduplication)
- Objects are recursively merged
- Scalars are added only if key does not exist (no overwrite)
- Tracks every addition for clean reversal

**Index Entry Append** (index.json):
- Entries appended to `entries` array
- Deduplicated by `path` field
- Tracked paths stored for clean removal

All three strategies create `.backup` files before modification.

#### 1.5 State Tracking (extensions.json)

Located at `{project}/.claude/extensions.json`:

```json
{
  "version": "1.0.0",
  "extensions": {
    "lean": {
      "version": "1.0.0",
      "loaded_at": "2026-03-01T10:00:00Z",
      "source_dir": "/home/benjamin/.config/nvim/.claude/extensions/lean",
      "installed_files": ["/path/to/each/installed/file"],
      "installed_dirs": ["/path/to/each/created/dir"],
      "merged_sections": {
        "claudemd": { "section_id": "extension_lean" },
        "settings": { "mcpServers": { "type": "new_object", ... } },
        "index": { "paths": ["context/project/lean4/..."] }
      },
      "status": "active"
    }
  }
}
```

### 2. Neovim Integration Layer

#### 2.1 Command Registration

In `lua/neotex/plugins/ai/claude/init.lua`, during `M.setup()`:

```lua
vim.api.nvim_create_user_command("ClaudeExtensions", function()
  require("neotex.plugins.ai.claude.extensions.picker").show()
end, { desc = "Manage Claude extensions", nargs = 0 })
```

#### 2.2 Which-Key Binding

In `lua/neotex/plugins/editor/which-key.lua`:

```lua
{ "<leader>ae", "<cmd>ClaudeExtensions<CR>", desc = "claude extensions", icon = "..." },
```

The full `<leader>a` group currently has:
- `<leader>ac` -- ClaudeCommands (command picker)
- `<leader>ae` -- ClaudeExtensions (extension picker)
- `<leader>as` -- Claude sessions / opencode select (CONFLICT: shared key!)
- `<leader>ab` -- opencode buffer context
- `<leader>ad` -- opencode diagnostics
- `<leader>ah` -- opencode history
- `<leader>ay` -- yolo mode toggle

**Available keys under `<leader>ao`**: The `<leader>ao` prefix is referenced in keymaps.lua comments (`<leader>aoo`) but is not currently bound as a group. It is free for opencode extension management.

#### 2.3 Telescope Picker

The picker (`extensions/picker.lua`) provides:
- **Finder**: Lists all available extensions with status indicators (`[active]`, `[inactive]`, `[update]`)
- **Previewer**: Shows extension details (name, version, status, provides, MCP servers, installed files, loaded timestamp)
- **Actions**:
  - Enter: Toggle load/unload
  - Ctrl-r: Reload (unload + load)
  - Ctrl-d: Show detailed installed file list in floating window
  - Tab/S-Tab: Multi-select (prepared for batch operations)
  - Escape: Close

### 3. Current OpenCode State

#### 3.1 What .opencode Already Has

The nvim `.opencode/` at `~/.config/nvim/.opencode/` has:
- 12 commands (task, research, plan, implement, etc.)
- 12 agents (general-research, general-implementation, neovim-research, web-research, etc.)
- Context directories: core/, project/neovim/, project/web/, project/meta/, project/hooks/, project/repo/
- settings.json with permissions, hooks, and theme
- Node modules: `@opencode-ai/plugin`, `@opencode-ai/sdk`, `zod`

#### 3.2 What .opencode Does NOT Have

Compared to `.claude/extensions/`:
- **No extensions directory** -- all domains (neovim, web) are inline in `context/project/`
- **No manifest system** -- no manifest.json per domain, no version tracking
- **No load/unload mechanism** -- domains cannot be activated/deactivated per project
- **No merge strategies** -- no OPENCODE.md section injection, no settings merging
- **No state tracking** -- no extensions.json per project
- **No Telescope picker** -- no `<leader>ao` management UI

#### 3.3 Web Domain Content

The web domain in `.opencode/context/project/web/` contains:
- `astro-framework.md` -- Astro SSG integration
- `tailwind-v4.md` -- Tailwind CSS v4 migration guide
- `README.md` -- Overview
- `domain/` -- Domain-specific knowledge
- `patterns/` -- Component, layout, styling patterns
- `standards/` -- Code quality, testing
- `templates/` -- Component and page templates
- `tools/` -- Astro, Cloudflare, Tailwind tooling

Plus 2 dedicated agents: `web-research.md`, `web-implementation.md`

### 4. Roadmap for `<leader>ao` Extensions System

#### 4.1 Architecture Mapping (.claude -> .opencode)

| .claude Component | .opencode Equivalent | Notes |
|-------------------|---------------------|-------|
| `.claude/extensions/{name}/` | `.opencode/extensions/{name}/` | Same directory structure |
| `manifest.json` | `manifest.json` | Adapt for opencode frontmatter differences |
| `EXTENSION.md` | `EXTENSION.md` | Inject into OPENCODE.md (or main config) |
| `settings-fragment.json` | `settings-fragment.json` | Merge into `.opencode/settings.json` |
| `index-entries.json` | `index-entries.json` | If .opencode adopts JSON index |
| `extensions.json` (per-project state) | `extensions.json` (per-project state) | Same pattern |
| `ClaudeExtensions` command | `OpencodeExtensions` command | New vim command |
| `<leader>ae` picker | `<leader>ao` picker group | New which-key group |

#### 4.2 Implementation Phases

**Phase 1: Extension Directory and Manifest**
- Create `.opencode/extensions/` directory at `~/.config/nvim/.opencode/extensions/`
- Define manifest.json schema (same as .claude but with `opencode_frontmatter` support)
- Create the `web/` extension as the first extension:
  - Move `context/project/web/` to `extensions/web/context/project/web/`
  - Move `agents/web-research.md` and `agents/web-implementation.md` to `extensions/web/agents/`
  - Create `extensions/web/manifest.json`
  - Create `extensions/web/EXTENSION.md`

**Phase 2: Lua Extension System (Parallel to .claude)**
- Create `lua/neotex/plugins/ai/opencode/extensions/` module tree:
  - `manifest.lua` -- adapted from claude version, points to `.opencode/extensions/`
  - `loader.lua` -- file copy engine (nearly identical to claude version)
  - `merge.lua` -- adapted merge strategies (OPENCODE.md sections, settings.json merge)
  - `state.lua` -- extensions.json tracking (nearly identical)
  - `init.lua` -- public API: load/unload/reload/list
  - `picker.lua` -- Telescope picker

**Phase 3: Neovim Integration**
- Register `OpencodeExtensions` vim command
- Add `<leader>ao` which-key group:
  - `<leader>aoe` -- OpencodeExtensions picker (manage extensions)
  - `<leader>aoc` -- OpencodeCommands picker (if commands picker exists)
  - `<leader>aoo` -- Toggle opencode (currently referenced in keymaps.lua)
  - `<leader>aos` -- Opencode sessions
  - `<leader>aoh` -- Opencode history
- Wire into opencode plugin initialization (opencode.lua or a new init module)

**Phase 4: Port Remaining .claude Extensions**
- Create `.opencode/extensions/lean/` (adapt from .claude lean extension)
- Create `.opencode/extensions/latex/` (adapt from .claude latex extension)
- Create `.opencode/extensions/typst/` (adapt from .claude typst extension)
- Create `.opencode/extensions/z3/` (adapt from .claude z3 extension)
- Create `.opencode/extensions/python/` (adapt from .claude python extension)

**Phase 5: Web Extension (New, Eventually Port to .claude)**
- Build out `.opencode/extensions/web/` with full Astro/Tailwind/Cloudflare context
- Include web-specific agents, skills, and context
- After validation, create `.claude/extensions/web/` as a port

#### 4.3 Code Reuse Opportunities

The Lua modules for the opencode extension system can share significant code with the claude modules:

| Module | Reuse % | Notes |
|--------|---------|-------|
| `loader.lua` | ~95% | Nearly identical; change target dir from `.claude` to `.opencode` |
| `state.lua` | ~95% | Change state path from `.claude/extensions.json` to `.opencode/extensions.json` |
| `manifest.lua` | ~80% | Same validation; change global dir and provides categories |
| `merge.lua` | ~70% | Different config file names; section markers may differ |
| `picker.lua` | ~60% | Different branding; same Telescope patterns |
| `init.lua` | ~50% | Different module paths; same public API |

**Recommendation**: Create a shared `lua/neotex/plugins/ai/shared/extensions/` module with parameterized paths, then have both claude and opencode extensions wrap it with their specific configuration.

#### 4.4 Key Design Decisions

1. **Manifest compatibility**: Should `.opencode/extensions/` manifests use the same schema as `.claude/extensions/`? **Yes**, for portability. Extensions should be loadable by either system.

2. **Agent frontmatter**: `.opencode` agents use richer frontmatter (tools, permissions, temperature). The manifest should support an optional `opencode_frontmatter` section or the agents themselves carry their own frontmatter.

3. **Merge target for main config**: `.claude` injects into `CLAUDE.md`. `.opencode` should inject into `OPENCODE.md` (the Logos pattern) or a dedicated config file.

4. **Settings merge**: `.claude` merges into `settings.local.json`. `.opencode` would merge into `.opencode/settings.json` (single settings file, no local override concept yet).

5. **Context index**: `.claude` uses `index.json` for structured context discovery. `.opencode` currently has no structured index. The extension system could introduce one.

### 5. File-by-File Mapping for web/ Extension

If creating `.opencode/extensions/web/`:

```
.opencode/extensions/web/
  manifest.json
  EXTENSION.md
  agents/
    web-research.md          <- from .opencode/agents/web-research.md
    web-implementation.md    <- from .opencode/agents/web-implementation.md
  context/
    project/web/
      README.md              <- from .opencode/context/project/web/README.md
      astro-framework.md
      tailwind-v4.md
      domain/                <- entire directory
      patterns/              <- entire directory
      standards/             <- entire directory
      templates/             <- entire directory
      tools/                 <- entire directory
```

## Decisions

- research-002 supplements research-001 with deep-dive into the extension system architecture
- The parallel system should use the same manifest schema for cross-system portability
- Code reuse via a shared base module is strongly recommended to avoid maintaining two copies
- The `<leader>ao` prefix is confirmed available and suitable for opencode extension management

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Two separate extension Lua codebases diverge | High maintenance | Use shared base module with parameterized config |
| opencode.nvim plugin API changes break integration | Medium | Wrap opencode API calls in adapter layer |
| manifest.json incompatibility between systems | Medium | Define shared schema, validate with same logic |
| Telescope dependency for picker | Low | Already required by both claude and opencode integrations |
| Moving web/ content to extension breaks existing workflows | Medium | Keep inline copies as fallback during migration |

## Appendix

### Search Queries Used

- `Glob(**/*extensions*/**)` -- Found 50+ extension files
- `Grep(ClaudeExtensions)` -- Found command registration in init.lua and which-key
- `Grep(leader.*ac)` -- Found keybinding integration points
- `Grep(leader.*ao)` -- Confirmed `<leader>ao` availability
- `Read(extensions/*.lua)` -- Read all 6 extension system modules
- `Read(manifest.json)` -- Read all 5 extension manifests
- `Read(which-key.lua)` -- Mapped all `<leader>a` bindings
- `Read(keymaps.lua)` -- Found global AI toggles and opencode integration
- `Glob(.opencode/**)` -- Mapped existing opencode structure

### References

- `lua/neotex/plugins/ai/claude/extensions/init.lua` -- Extension public API (load/unload/reload)
- `lua/neotex/plugins/ai/claude/extensions/manifest.lua` -- Manifest validation and discovery
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` -- File copy engine
- `lua/neotex/plugins/ai/claude/extensions/merge.lua` -- Reversible merge strategies
- `lua/neotex/plugins/ai/claude/extensions/state.lua` -- Per-project state tracking
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` -- Telescope management UI
- `lua/neotex/plugins/ai/claude/init.lua` -- ClaudeExtensions command registration
- `lua/neotex/plugins/editor/which-key.lua` -- `<leader>ae` binding and AI group
- `lua/neotex/config/keymaps.lua` -- Global AI toggles (C-CR, C-g)
- `.claude/extensions/lean/manifest.json` -- Most complete extension manifest (with MCP)
- `.opencode/agents/` -- Existing opencode agents to potentially extract into extensions
- `.opencode/context/project/web/` -- Web domain content for first extension

## Next Steps

1. Create implementation plan at `specs/103_compare_opencode_agent_systems_against_claude/plans/implementation-001.md`
2. Phase 1 should create the `web/` extension manifest and directory structure
3. Phase 2 should implement the shared Lua extension base module
4. Phase 3 should wire up `<leader>ao` and the Telescope picker
