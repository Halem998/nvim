# Research Report: Task #204

**Task**: Create grant extension scaffold with manifest.json
**Date**: 2026-03-15
**Focus**: extension scaffold patterns, manifest.json structure, provides arrays

## Summary

Analyzed 11 existing extensions in `.claude/extensions/` to extract consistent patterns for the grant extension scaffold. Extensions follow a well-defined structure with manifest.json as the central configuration file, EXTENSION.md for CLAUDE.md injection, and index-entries.json for context discovery. The grant extension will be a domain-specific extension similar to the nvim, lean, and filetypes extensions.

## Findings

### Extension Directory Structure

All extensions follow this canonical structure:

```
extensions/{name}/
  manifest.json         # Required: Extension metadata and configuration
  EXTENSION.md          # Required: Content injected into CLAUDE.md when loaded
  index-entries.json    # Required: Context index entries for discovery
  opencode-agents.json  # Optional: OpenCode agent definitions (for cross-system support)
  settings-fragment.json # Optional: MCP server settings and permissions
  agents/               # Agent definition files (.md)
  skills/               # Skill directories with SKILL.md
    skill-{name}/
      SKILL.md
  commands/             # Command files (.md)
  rules/                # Rule files (.md)
  context/              # Context files (preserving project/* structure)
    project/{subdomain}/
      README.md
      domain/
      patterns/
      tools/
      standards/
      templates/
  scripts/              # Optional shell scripts
```

### manifest.json Structure

The manifest.json file contains all extension metadata and configuration.

#### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Extension identifier (lowercase, matches directory name) |
| `version` | string | Semantic version (e.g., "1.0.0") |
| `description` | string | Human-readable description |
| `language` | string or null | Primary language code for routing (null for utility extensions) |
| `dependencies` | array | List of required extensions (usually empty) |
| `provides` | object | Assets provided by extension |
| `merge_targets` | object | Configuration for merging extension content |
| `mcp_servers` | object | MCP server definitions (can be empty) |

#### provides Object

The `provides` object declares all assets the extension provides:

| Field | Type | Description |
|-------|------|-------------|
| `agents` | array of strings | Agent filenames (e.g., `["grant-agent.md"]`) |
| `skills` | array of strings | Skill directory names (e.g., `["skill-grant"]`) |
| `commands` | array of strings | Command filenames (e.g., `["grant.md"]`) |
| `rules` | array of strings | Rule filenames (e.g., `["grant-writing.md"]`) |
| `context` | array of strings | Context subdirectories (e.g., `["project/grant"]`) |
| `scripts` | array of strings | Script filenames |
| `hooks` | array of strings | Hook filenames (typically empty) |

#### merge_targets Object

The `merge_targets` object defines how extension content is merged into the core system:

| Target | Source | Target File | Description |
|--------|--------|-------------|-------------|
| `claudemd` | `EXTENSION.md` | `.claude/CLAUDE.md` | CLAUDE.md content injection |
| `index` | `index-entries.json` | `.claude/context/index.json` | Context index merging |
| `settings` | `settings-fragment.json` | `.claude/settings.local.json` | MCP settings (optional) |
| `opencode_json` | `opencode-agents.json` | `opencode.json` | OpenCode agents (optional) |

Each merge target follows this structure:
```json
{
  "source": "source_filename",
  "target": "relative/path/to/target",
  "section_id": "unique_identifier"  // For claudemd only
}
```

#### mcp_servers Object

For extensions requiring MCP servers (like lean with lean-lsp):
```json
{
  "mcp_servers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name@latest"]
    }
  }
}
```

For extensions without MCP requirements:
```json
{
  "mcp_servers": {}
}
```

### Complete manifest.json Examples

#### Simple Extension (nvim pattern)

```json
{
  "name": "nvim",
  "version": "1.0.0",
  "description": "Neovim configuration development with Lua patterns and plugin support",
  "language": "neovim",
  "dependencies": [],
  "provides": {
    "agents": ["neovim-research-agent.md", "neovim-implementation-agent.md"],
    "skills": ["skill-neovim-research", "skill-neovim-implementation"],
    "commands": [],
    "rules": ["neovim-lua.md"],
    "context": ["project/neovim"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_nvim"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    },
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
  },
  "mcp_servers": {}
}
```

#### Complex Extension with Commands and MCP (lean pattern)

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 theorem prover support with MCP integration for proof assistance",
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
    },
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
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

#### Utility Extension (filetypes pattern)

```json
{
  "name": "filetypes",
  "version": "2.0.0",
  "description": "File format conversion and manipulation",
  "language": null,
  "dependencies": [],
  "provides": {
    "agents": ["filetypes-router-agent.md", "document-agent.md"],
    "skills": ["skill-filetypes"],
    "commands": ["convert.md", "table.md"],
    "rules": [],
    "context": ["project/filetypes"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_filetypes"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    },
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
  },
  "mcp_servers": {}
}
```

### index-entries.json Format

The index-entries.json file contains context file metadata for discovery.

#### Entry Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Canonical path (e.g., `project/grant/README.md`) |
| `domain` | string | No | Domain category (typically `project`) |
| `subdomain` | string | No | Subdomain within domain |
| `topics` | array | No | Topic tags for discovery |
| `keywords` | array | No | Keyword tags for search |
| `summary` or `description` | string | No | Brief description of content |
| `line_count` | number | No | Line count for context budget calculation |
| `load_when` | object | Yes | Loading conditions |

#### load_when Object

| Field | Type | Description |
|-------|------|-------------|
| `languages` | array | Languages that should load this context |
| `agents` | array | Agents that should load this context |
| `commands` | array | Commands that should load this context |

**Path Format**: All paths use canonical format starting with `project/*` or `core/*`. DO NOT prefix with `.claude/context/`.

#### Example index-entries.json

```json
{
  "entries": [
    {
      "path": "project/grant/README.md",
      "domain": "project",
      "subdomain": "grant",
      "topics": ["grant", "proposal", "funding"],
      "keywords": ["grant", "proposal", "budget"],
      "summary": "Grant writing domain overview",
      "line_count": 100,
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/patterns/proposal-structure.md",
      "domain": "project",
      "subdomain": "grant",
      "topics": ["proposal", "structure", "sections"],
      "keywords": ["proposal", "narrative", "sections"],
      "summary": "Grant proposal structure and section guidelines",
      "line_count": 150,
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"],
        "commands": ["/grant"]
      }
    }
  ]
}
```

### EXTENSION.md Format

The EXTENSION.md file contains markdown content that is injected into CLAUDE.md when the extension is loaded.

#### Standard Sections

1. **Extension Header**: `## {Name} Extension`
2. **Language Routing Table**: Research/Implementation skill mapping
3. **Skill-Agent Mapping Table**: Skill to agent mappings with purposes
4. **MCP Integration** (if applicable): Server and tool descriptions
5. **Commands** (if applicable): Available commands
6. **Context Imports**: Context file references

#### Example EXTENSION.md Structure

```markdown
## Grant Extension

This project includes grant proposal writing support via the grant extension.

### Language Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `grant` | `skill-grant-research` | `skill-grant` | WebSearch, WebFetch, Read, Write, Edit |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-grant | grant-agent | Grant proposal research and writing |

### Context Imports

Domain knowledge (load as needed):
- @.claude/context/project/grant/patterns/proposal-structure.md
- @.claude/context/project/grant/templates/budget-template.md
```

### Extension Loading Process

When an extension is loaded via `<leader>ac`:

1. Agent files (.md) copied to `.claude/agents/`
2. Skill directories copied to `.claude/skills/`
3. Rule files copied to `.claude/rules/`
4. Command files copied to `.claude/commands/`
5. Context directories copied to `.claude/context/project/`
6. Index entries merged into `.claude/context/index.json`
7. EXTENSION.md content injected into `.claude/CLAUDE.md`
8. Settings fragment merged (if present)
9. Post-load verification runs

### Skill Directory Structure

Each skill follows the pattern:
```
skills/skill-{name}/
  SKILL.md        # Skill definition with frontmatter
```

Skill frontmatter:
```yaml
---
name: skill-{name}
description: Brief description. Invoke for {use case}.
allowed-tools: Task, Bash, Edit, Read, Write
---
```

### Agent File Structure

Agent files are markdown files with frontmatter:
```yaml
---
model: opus  # Optional: preferred model
skills: skill-name  # Optional: auto-loaded skills
---

# Agent Name

Agent description and instructions...
```

## Recommendations

### Recommended grant Extension Structure

```
extensions/grant/
  manifest.json
  EXTENSION.md
  index-entries.json
  opencode-agents.json
  agents/
    grant-agent.md
  skills/
    skill-grant/
      SKILL.md
  commands/
    grant.md
  context/
    project/grant/
      README.md
      patterns/
        proposal-structure.md
        funder-research.md
      templates/
        budget-template.md
        narrative-template.md
      tools/
        sff-guide.md
```

### Recommended manifest.json for grant Extension

```json
{
  "name": "grant",
  "version": "1.0.0",
  "description": "Grant proposal research and writing support with funder-specific templates",
  "language": "grant",
  "dependencies": [],
  "provides": {
    "agents": ["grant-agent.md"],
    "skills": ["skill-grant"],
    "commands": ["grant.md"],
    "rules": [],
    "context": ["project/grant"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_grant"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    },
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
  },
  "mcp_servers": {}
}
```

### Implementation Notes

1. **Language Code**: Use `"grant"` as the language code for routing consistency
2. **Section ID**: Use `"extension_grant"` for CLAUDE.md injection section
3. **Context Path**: Use `project/grant` in provides.context and index-entries.json paths
4. **Minimal Start**: Begin with one agent (grant-agent) and one skill (skill-grant)
5. **Progressive Context**: Context files can be added incrementally in Task #208

## Decisions

1. **Single Agent Pattern**: Grant extension will use a single grant-agent that handles both research and writing, similar to simpler extensions. Multi-agent patterns (research/implementation split) can be added later if needed.
2. **Language "grant"**: Using "grant" as the language code enables language-based routing from `/research` and `/implement` commands.
3. **No MCP Servers**: Initial version does not require MCP integration. WebSearch and WebFetch provide sufficient funder research capabilities.
4. **No Rules**: Grant writing does not require auto-applied rules. Style guidance will be in context files.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Context files too large | Agent context overflow | Use line_count tracking, progressive loading |
| Funder-specific templates | High maintenance burden | Use generic templates with funder-specific patterns |
| Extension not loading | Blocked development | Test with `<leader>ac` immediately after creation |

## Appendix

### Search Queries Used

1. `find .claude/extensions -name "manifest.json"` - Located all manifest files
2. `Glob .claude/extensions/**/*` - Mapped extension directory structures
3. `Read manifest.json` for nvim, lean, filetypes, nix, typst - Extracted patterns

### Key Files Referenced

- `/home/benjamin/.config/nvim/.claude/extensions/README.md` - Extension architecture documentation
- `/home/benjamin/.config/nvim/.claude/extensions/nvim/manifest.json` - Simple extension pattern
- `/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json` - Complex extension with MCP
- `/home/benjamin/.config/nvim/.claude/extensions/filetypes/manifest.json` - Utility extension pattern
- `/home/benjamin/.config/nvim/.claude/extensions/nvim/index-entries.json` - Complete index entries example
- `/home/benjamin/.config/nvim/specs/tmp/example-grant-app.md` - Domain context (SFF application)

## Next Steps

Run `/plan 204` to create implementation plan for the grant extension scaffold.
