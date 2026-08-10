# Research Report: Task #99 (Supplementary - Claude Code Native Plugin System)

**Task**: 99 - review_agent_systems_core_extensions
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T03:00:00Z
**Effort**: 3-5 hours
**Dependencies**: research-001.md (initial comparison), research-002.md (direct integration architecture)
**Sources/Inputs**: Local plugin installation (`~/.claude/plugins/`), official Claude Code documentation (code.claude.com/docs/en/plugins, /plugins-reference, /discover-plugins, /plugin-marketplaces), official marketplace plugin examples (plugin-dev, feature-dev, hookify, example-plugin)
**Artifacts**: specs/099_review_agent_systems_core_extensions/reports/research-003.md
**Standards**: report-format.md

## Executive Summary

- Claude Code has a mature, well-documented native plugin system that supports commands, skills, agents, hooks, MCP servers, LSP servers, and default settings -- all discoverable from a `.claude-plugin/plugin.json` manifest
- The plugin system supports three loading mechanisms: marketplace installation (persistent), `--plugin-dir` (session-scoped), and project-scoped `enabledPlugins` in `.claude/settings.json`
- A "core + extension plugins" architecture is viable: the existing `.claude/` system becomes the core (always active), while domain-specific functionality (Lean, LaTeX, etc.) is packaged as native Claude Code plugins that can be enabled/disabled per-project
- The `<leader>ac` picker can be adapted to manage plugin enable/disable state by modifying `settings.json` or `settings.local.json`, avoiding the file-copying complexity of research-002
- This approach is strictly superior to the custom extension system proposed in research-002: it leverages native namespacing, discovery, marketplace infrastructure, `${CLAUDE_PLUGIN_ROOT}` for portable paths, and automatic caching/updates

## Context & Scope

This is the third research report for task 99. The user wants to explore whether Claude Code's native plugin system could replace or integrate with the custom extension system proposed in research-002.

**Key question**: Can we package domain-specific `.claude/` components (Lean commands, LaTeX agents, etc.) as native Claude Code plugins, and use `<leader>ac` to manage which plugins are active per-project?

## Findings

### 1. Plugin System Architecture

The native plugin system is a first-class feature of Claude Code with comprehensive capabilities.

#### 1.1 Plugin Directory Structure

A plugin is a self-contained directory with this layout:

```
my-plugin/
+-- .claude-plugin/           # Metadata (only plugin.json goes here)
|   +-- plugin.json           # Plugin manifest (optional but recommended)
+-- commands/                 # Slash commands (*.md files) [legacy name]
+-- skills/                   # Agent skills (skill-name/SKILL.md)
+-- agents/                   # Subagent definitions (*.md files)
+-- hooks/                    # Event handlers
|   +-- hooks.json            # Hook configuration
|   +-- scripts/              # Hook scripts
+-- .mcp.json                 # MCP server definitions
+-- .lsp.json                 # LSP server definitions
+-- settings.json             # Default settings (currently only "agent" key)
+-- scripts/                  # Utility scripts
+-- README.md                 # Documentation
+-- LICENSE                   # License file
```

#### 1.2 plugin.json Manifest Schema

The manifest is optional but recommended. Minimal example:

```json
{
  "name": "lean-extension"
}
```

Complete schema:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes (if manifest present) | Unique kebab-case identifier, used for namespacing |
| `version` | string | No | Semantic version (MAJOR.MINOR.PATCH) |
| `description` | string | No | Brief explanation (50-200 chars) |
| `author` | object | No | `{ name, email?, url? }` |
| `homepage` | string | No | Documentation URL |
| `repository` | string | No | Source code URL |
| `license` | string | No | SPDX identifier |
| `keywords` | array | No | Discovery tags |
| `commands` | string/array | No | Additional command paths (supplements `commands/`) |
| `agents` | string/array | No | Additional agent paths (supplements `agents/`) |
| `skills` | string/array | No | Additional skill paths (supplements `skills/`) |
| `hooks` | string/array/object | No | Hook config paths or inline config |
| `mcpServers` | string/array/object | No | MCP config paths or inline config |
| `lspServers` | string/array/object | No | LSP config paths or inline config |
| `outputStyles` | string/array | No | Output style files/directories |

All paths must be relative, start with `./`, and cannot use `../`.

#### 1.3 Component Capabilities

Plugins can define ALL the component types that exist in `.claude/`:

| Component | Plugin Location | Equivalent .claude/ Location |
|-----------|----------------|------------------------------|
| Commands/Skills | `commands/`, `skills/` | `.claude/commands/`, `.claude/skills/` |
| Agents | `agents/` | `.claude/agents/` |
| Hooks | `hooks/hooks.json` | `.claude/settings.json` hooks section |
| MCP servers | `.mcp.json` | `.claude/.mcp.json` |
| LSP servers | `.lsp.json` | N/A (new in plugin system) |
| Settings | `settings.json` | `.claude/settings.json` |
| Rules | Not directly supported | `.claude/rules/` |
| Context files | Not directly supported | `.claude/context/` |

**Gap**: The plugin system does NOT have native support for `rules/` or `context/` directories. These are `.claude/`-specific features. See Section 5 for how to handle this.

#### 1.4 Namespacing

Plugin components are namespaced by plugin name. For a plugin named `lean-tools`:
- Skills become `/lean-tools:lake`, `/lean-tools:lean`
- Agents appear as `lean-tools:lean-research-agent`
- This prevents conflicts between plugins

### 2. Plugin Loading Mechanisms

Three mechanisms for loading plugins, each with different persistence:

#### 2.1 Marketplace Installation (Persistent)

```bash
# Add marketplace
/plugin marketplace add owner/repo

# Install plugin
/plugin install lean-tools@my-marketplace

# Installation scopes
/plugin install lean-tools@my-marketplace --scope user     # ~/.claude/settings.json
/plugin install lean-tools@my-marketplace --scope project  # .claude/settings.json
/plugin install lean-tools@my-marketplace --scope local    # .claude/settings.local.json
```

Plugins are copied to `~/.claude/plugins/cache/` and loaded from there.

#### 2.2 `--plugin-dir` Flag (Session-Scoped)

```bash
# Load plugin directly for development/testing
claude --plugin-dir ./my-plugin

# Load multiple plugins
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two
```

Session-scoped only. No installation/caching.

#### 2.3 Project Settings (Per-Project, Persistent)

In `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "lean-tools@my-marketplace": true,
    "latex-tools@my-marketplace": false
  }
}
```

This is the mechanism most relevant for `<leader>ac` integration.

### 3. Plugin Discovery and Loading Order

#### 3.1 Discovery Sequence

When Claude Code starts:

1. Read enabled plugins from settings (user -> project -> local -> managed)
2. For each enabled plugin, scan default directories + custom paths
3. Parse YAML frontmatter and configurations
4. Register all components (commands, agents, skills, hooks)
5. Initialize MCP servers, register hooks

#### 3.2 Priority/Merge Behavior

- Plugin components from ALL locations load (no overwriting)
- Name conflicts cause errors (namespacing prevents most conflicts)
- Custom paths in manifest SUPPLEMENT default directories (not replace)
- `settings.json` from plugin takes priority over plugin.json `settings`

### 4. Environment Variables and Portability

#### 4.1 CLAUDE_PLUGIN_ROOT

The `${CLAUDE_PLUGIN_ROOT}` variable contains the absolute path to the plugin's installation directory. Essential for:

```json
{
  "hooks": {
    "PostToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh"
      }]
    }]
  }
}
```

This ensures scripts work regardless of where the plugin is installed (marketplace cache vs local development).

#### 4.2 Plugin Caching

Marketplace plugins are copied to `~/.claude/plugins/cache/`. This means:
- Plugins cannot reference files outside their directory
- Symlinks ARE followed during copying (workaround for shared files)
- `--plugin-dir` plugins are NOT cached (used in-place)

### 5. Mapping Existing Extension Concepts to Plugin System

Here is how each component from the research-002 custom extension system maps to the native plugin system:

#### 5.1 Direct Mappings (Native Support)

| Extension Component | Plugin Equivalent | Notes |
|---------------------|-------------------|-------|
| `commands/*.md` | `commands/` or `skills/` | Direct 1:1 mapping |
| `skills/skill-*/SKILL.md` | `skills/skill-*/SKILL.md` | Identical structure |
| `agents/*.md` | `agents/*.md` | Identical structure |
| `hooks/hooks.json` | `hooks/hooks.json` | Same format, plus `${CLAUDE_PLUGIN_ROOT}` |
| `scripts/*.sh` | `scripts/*.sh` | Used by hooks via `${CLAUDE_PLUGIN_ROOT}` |
| `settings_fragment` | `settings.json` (partial) | Only `agent` key supported currently |
| `.mcp.json` | `.mcp.json` | Direct support |

#### 5.2 Components Requiring Workarounds

| Extension Component | Challenge | Workaround |
|---------------------|-----------|------------|
| `rules/*.md` | No plugin `rules/` support | Embed rule content in agent system prompts, or use hooks to inject rules |
| `context/**` | No plugin `context/` support | Bundle context in skill reference subdirectories (`skills/*/references/`) |
| `index.json` entries | No plugin context index | Skills reference their own bundled files |
| `CLAUDE.md` sections | No plugin CLAUDE.md injection | Use plugin settings.json with `agent` key, or hooks |
| MCP permissions (`mcp__lean-lsp__*`) | Partial -- `settings.json` only supports `agent` | Must be added to project `.claude/settings.json` separately |

#### 5.3 Proposed Lean Extension as Plugin

```
lean-tools/
+-- .claude-plugin/
|   +-- plugin.json
+-- commands/                          # Was: extensions/lean/commands/
|   +-- lake.md                        # Becomes /lean-tools:lake
|   +-- lean.md                        # Becomes /lean-tools:lean
+-- skills/
|   +-- lean-research/
|   |   +-- SKILL.md
|   |   +-- references/               # Context files bundled with skill
|   |       +-- lean-api.md
|   |       +-- mathlib-patterns.md
|   +-- lean-implementation/
|   |   +-- SKILL.md
|   |   +-- references/
|   |       +-- proof-tactics.md
|   +-- lake-repair/
|   |   +-- SKILL.md
|   +-- lean-version/
|       +-- SKILL.md
+-- agents/
|   +-- lean-research-agent.md         # Embeds lean4.md rule content in prompt
|   +-- lean-implementation-agent.md
+-- hooks/
|   +-- hooks.json                     # MCP setup verification hooks
+-- scripts/
|   +-- setup-lean-mcp.sh
|   +-- verify-lean-mcp.sh
+-- .mcp.json                          # Lean LSP MCP server config
+-- README.md
```

`plugin.json`:
```json
{
  "name": "lean-tools",
  "version": "1.0.0",
  "description": "Lean 4 formal verification support for Claude Code",
  "author": { "name": "Benjamin" },
  "keywords": ["lean", "lean4", "mathlib", "formal-verification"]
}
```

### 6. `<leader>ac` Integration Strategy

The `<leader>ac` Neovim picker can be adapted to manage plugin state rather than copying files.

#### 6.1 Current `<leader>ac` Flow (research-002)

1. Scan global `.claude/` for artifacts
2. Show picker with checkboxes
3. On confirm: copy selected files to project `.claude/`
4. Track copied files in registry.json

#### 6.2 Proposed Plugin-Aware Flow

1. Scan available plugins from:
   - `~/.claude/plugins/cache/` (installed plugins)
   - Global `.claude/extensions/` (local development plugins)
   - Any `--plugin-dir` paths
2. Show picker with plugin-level checkboxes (not individual files)
3. On confirm: update `.claude/settings.local.json` `enabledPlugins` section
4. Session restart required for changes to take effect

```lua
-- Pseudocode for plugin management
local function toggle_plugin(plugin_name, marketplace, enabled)
  local settings_path = ".claude/settings.local.json"
  local settings = read_json(settings_path) or {}
  settings.enabledPlugins = settings.enabledPlugins or {}
  local key = plugin_name .. "@" .. marketplace
  settings.enabledPlugins[key] = enabled
  write_json(settings_path, settings)
end
```

#### 6.3 Advantages Over File-Copying

| Aspect | File Copy (research-002) | Plugin Enable/Disable |
|--------|--------------------------|----------------------|
| Mechanism | Copy files into .claude/ | Toggle in settings.json |
| Conflict risk | High (file collisions) | None (namespaced) |
| Cleanup | Must track and remove each file | Just disable in settings |
| Session impact | May work without restart | Requires session restart |
| State tracking | Custom registry.json | Native settings.json |
| Portability | Custom manifest format | Standard plugin.json |
| Updates | Manual re-copy | `/plugin update` |

#### 6.4 Hybrid Approach for Non-Plugin Components

Some components (rules, context files, CLAUDE.md sections) cannot be packaged as plugins. For these:

1. **Core `.claude/` system** always includes: rules, context, CLAUDE.md, lib, docs, tests
2. **Plugins** handle: commands, skills, agents, hooks, MCP servers, scripts
3. **`<leader>ac` picker** has two modes:
   - **Plugin mode**: Toggle `enabledPlugins` in settings.json
   - **Core sync mode**: Copy core system files (existing sync.lua behavior)

### 7. Marketplace Architecture for Personal Use

For a single user managing domain-specific extensions, the simplest approach:

#### 7.1 Local Marketplace

```
~/.config/nvim/extensions/                    # or wherever you want
+-- .claude-plugin/
|   +-- marketplace.json
+-- plugins/
|   +-- lean-tools/
|   |   +-- .claude-plugin/plugin.json
|   |   +-- commands/
|   |   +-- skills/
|   |   +-- agents/
|   |   +-- ...
|   +-- latex-tools/
|   |   +-- ...
|   +-- neovim-tools/
|       +-- ...
```

`marketplace.json`:
```json
{
  "name": "nvim-config-extensions",
  "owner": { "name": "Benjamin" },
  "plugins": [
    {
      "name": "lean-tools",
      "source": "./plugins/lean-tools",
      "description": "Lean 4 formal verification support"
    },
    {
      "name": "latex-tools",
      "source": "./plugins/latex-tools",
      "description": "LaTeX document tools"
    },
    {
      "name": "neovim-tools",
      "source": "./plugins/neovim-tools",
      "description": "Neovim configuration tools"
    }
  ]
}
```

Register once:
```
/plugin marketplace add /path/to/extensions
```

Then in any project:
```
/plugin install lean-tools@nvim-config-extensions --scope local
```

#### 7.2 GitHub-Hosted Marketplace

For version control and sharing across machines:

```
/plugin marketplace add username/nvim-claude-plugins
```

This enables auto-updates and git-based version tracking.

### 8. Comparison: Native Plugin System vs Custom Extension System

| Dimension | Native Plugin System | Custom Extension (research-002) |
|-----------|---------------------|--------------------------------|
| **Component support** | Commands, skills, agents, hooks, MCP, LSP | All .claude/ components including rules, context |
| **Discovery** | Auto-discovery by Claude Code | Requires custom registry + loader |
| **Namespacing** | Automatic (`plugin:command`) | Must be handled manually |
| **Updates** | `/plugin update`, auto-update | Manual re-sync |
| **Conflict resolution** | Native (namespace isolation) | Custom (checksums, manifests) |
| **Portability** | Standard format, any machine | Custom format, requires picker infra |
| **Development tools** | `--plugin-dir`, `--debug`, validate | None (must build) |
| **Session restart** | Required for changes | Some changes immediate |
| **Rules support** | Not supported | Full support |
| **Context files** | Via skill references (workaround) | Full support |
| **CLAUDE.md injection** | Not supported | Full support |
| **Community sharing** | Marketplace ecosystem | Not applicable |
| **Effort to implement** | Package existing files, minimal new code | Build loader, registry, conflict detection |
| **Neovim integration** | Toggle settings.json via `<leader>ac` | File copy/remove via `<leader>ac` |

### 9. Detailed Gap Analysis: What Plugins Cannot Do

#### 9.1 Rules

**Problem**: Claude Code's rule system (`.claude/rules/`) applies rules based on file path patterns. Plugins have no `rules/` directory support.

**Workarounds**:
1. **Embed in agent prompts**: Put rule content directly in agent `.md` system prompts. The agent always sees its rules.
2. **Use hooks**: A `SessionStart` hook could inject rule content into the conversation.
3. **Use CLAUDE.md**: If the rule applies project-wide, add it to `.claude/CLAUDE.md` (but this defeats per-extension toggle).

**Severity**: Medium. Agent-embedded rules work well for domain-specific agents (Lean agent has Lean rules). Project-wide rules should stay in core `.claude/rules/`.

#### 9.2 Context Files

**Problem**: The `.claude/context/` directory and `index.json` discovery system are project-specific infrastructure. Plugins cannot extend them.

**Workarounds**:
1. **Skill reference subdirectories**: Bundle context in `skills/my-skill/references/`. The skill SKILL.md can reference these files with `@references/file.md`.
2. **Agent `@`-references**: Agent prompts can use `@` to load files, but only from the project's `.claude/context/`.

**Severity**: Medium. The skill-references pattern is documented as best practice in the plugin-dev toolkit. It works but loses the centralized index.json discovery.

#### 9.3 CLAUDE.md Sections

**Problem**: Plugins cannot inject sections into the project's CLAUDE.md.

**Workarounds**:
1. **Plugin settings.json `agent` key**: Can activate a plugin agent as the main thread, but this is heavy-handed.
2. **SessionStart hook**: Could append plugin-specific instructions, but this is fragile.
3. **Manual**: Document which CLAUDE.md sections to add when enabling a plugin.

**Severity**: Low-Medium. The CLAUDE.md sections in the current system (language routing tables, skill-agent mapping) are informational for the orchestrator. If domain skills/agents are in a plugin, the orchestrator still discovers them via standard plugin mechanisms.

#### 9.4 Permission Fragments

**Problem**: Plugins can define `settings.json` but currently only the `agent` key is supported. Cannot add `permissions.allow` entries like `mcp__lean-lsp__*`.

**Workaround**: Add required permissions to project-scoped `.claude/settings.json` or user-scoped `~/.claude/settings.json`.

**Severity**: Low. Permission entries are typically a one-time setup.

## Recommendations

### Primary Recommendation: Hybrid Plugin + Core Architecture

1. **Core system** (`nvim/.claude/`): Contains rules, context files, CLAUDE.md, lib, docs, tests, state management, and general-purpose commands/skills/agents that apply across all projects. This is always active.

2. **Domain plugins** (separate directories): Package domain-specific components (Lean, LaTeX, Typst, etc.) as native Claude Code plugins with:
   - Commands/skills/agents in standard plugin directories
   - Context files bundled as skill references
   - Rules embedded in agent prompts
   - MCP configurations in `.mcp.json`
   - Hook scripts using `${CLAUDE_PLUGIN_ROOT}`

3. **`<leader>ac` adaptation**: Modify the picker to:
   - Show installed plugins with enable/disable toggles
   - Write to `.claude/settings.local.json` `enabledPlugins`
   - Keep existing core-sync mode for non-plugin components
   - Display notification that session restart is needed

4. **Local marketplace**: Create a personal marketplace in the global nvim config (or separate repo) containing all domain plugins.

### Migration Path

1. **Phase 1**: Create plugin structure for one domain (e.g., Lean) -- extract commands, skills, agents from `.claude/` into a plugin directory
2. **Phase 2**: Create local marketplace, test with `--plugin-dir` and `/plugin install`
3. **Phase 3**: Adapt `<leader>ac` to toggle `enabledPlugins` in settings
4. **Phase 4**: Migrate remaining domains (LaTeX, Typst, etc.)
5. **Phase 5**: Move context files into skill reference subdirectories
6. **Phase 6**: Evaluate whether to host marketplace on GitHub for multi-machine sync

### Why This Approach Over research-002

1. **Less custom code**: No registry.json, no file manifest tracking, no conflict detection, no load/unload workflow
2. **Native tooling**: `--plugin-dir` for testing, `/plugin validate` for validation, `--debug` for troubleshooting
3. **Namespacing**: Automatic conflict prevention via plugin name prefixes
4. **Updates**: `/plugin update` instead of manual re-copy
5. **Community standard**: Same format used by 9000+ plugins, documented by Anthropic
6. **Caching**: Automatic caching in `~/.claude/plugins/cache/` with version tracking

### What to Keep from research-002

1. **Core sync mode**: The existing `sync.lua` file-copying mechanism is still needed for syncing the core `.claude/` system (rules, context, docs, lib) from global to project
2. **Extension directory concept**: The idea of self-contained domain packs is correct -- just use native plugin format instead of custom manifest
3. **`<leader>ac` picker UI**: The telescope picker infrastructure works -- just change the backend from file operations to settings.json manipulation

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Session restart required after plugin changes | Moderate -- disrupts workflow | Display clear notification, investigate if hot-reload is possible |
| Rules not in plugin system | Low-Medium -- some rules may be missed | Embed in agent prompts, keep project-wide rules in core |
| Context index fragmentation | Medium -- lose centralized discovery | Bundle context with skills, maintain core index for shared context |
| Plugin namespace prefix in commands | Low -- `/lean-tools:lake` vs `/lake` | Use short plugin names, users learn quickly |
| Claude Code plugin system changes | Low -- API is stable | Pin marketplace versions, test updates |
| Permission management still manual | Low -- one-time setup per project | Document required permissions per plugin |

## References

- [Create plugins](https://code.claude.com/docs/en/plugins) -- Official plugin creation guide
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) -- Complete technical specifications
- [Discover and install plugins](https://code.claude.com/docs/en/discover-plugins) -- Installation and marketplace usage
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) -- Marketplace creation and distribution
- Official marketplace: `~/.claude/plugins/marketplaces/claude-plugins-official/`
- Plugin-dev toolkit: `plugins/plugin-dev/` in official marketplace (comprehensive skill/agent/hook development reference)
- Example plugin: `plugins/example-plugin/` in official marketplace (minimal reference implementation)

## Next Steps

1. Decide whether to proceed with native plugin architecture
2. If yes, create implementation plan for Phase 1 (Lean plugin extraction)
3. Design `<leader>ac` picker modifications for plugin management mode
