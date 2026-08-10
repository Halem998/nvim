# Research Report: Task #174

**Task**: 174 - study_opencode_memory_extension
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .opencode/memory/, .claude/extensions/, .opencode/extensions/, Neovim extension loader
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- The .opencode/memory/ system consists of an Obsidian-compatible vault (4 directories, template, 3 memories), a `/learn` command, a `skill-learn` skill, memory setup/troubleshooting docs, and a `--remember` flag in `/research`
- The existing extension system is well-architected and parameterized for both claude and opencode, supporting agents, skills, commands, rules, context, scripts, and hooks categories
- A memory extension is feasible but requires TWO changes to the extension system: (1) adding a new `provides` category for "data" or "vault" directories, and (2) supporting additional merge targets beyond the standard claudemd/index/settings trio
- The memory extension is unique because it includes non-code data (the vault directory itself) that doesn't fit any existing `provides` category
- The /learn command in .opencode has diverged from .claude's /fix-it - they share a common ancestor but serve different purposes now

## Context & Scope

The goal is to move the .opencode/memory/ system and all related components into a loadable extension so it can be selectively enabled. This research examines:
1. What the memory system consists of
2. How the existing extension system works
3. What gaps exist between the two
4. What changes are needed

## Findings

### 1. Memory System Components

The .opencode/memory/ system consists of these components:

#### 1.1 Vault Directory Structure
```
.opencode/memory/
  .obsidian/            # Obsidian app config (gitignored)
    app.json
    appearance.json
    core-plugins.json
    plugins/obsidian-cli-rest/config.json
  00-Inbox/             # Quick capture inbox
    README.md
  10-Memories/          # Stored memory entries
    README.md
    MEM-2026-03-05-001-clean-break-command-renaming.md
    MEM-2026-03-05-002-metadata-delegation-pattern.md
    MEM-2026-03-05-003-memory-classification-taxonomy.md
  20-Indices/           # Navigation index
    README.md
    index.md
  30-Templates/         # Memory entry templates
    README.md
    memory-template.md
```

#### 1.2 Command: `/learn`
- **Path**: `.opencode/commands/learn.md`
- **Purpose**: Dual-mode command: (1) standard mode adds text/file as memory, (2) task mode (`--task OC_N`) reviews task artifacts and creates classified memories
- **Delegates to**: `skill-learn`
- **State reads**: specs/OC_{N}_*/, memory templates, existing memories
- **State writes**: memory files, index.md

#### 1.3 Skill: `skill-learn`
- **Path**: `.opencode/skills/skill-learn/SKILL.md`
- **Purpose**: Actually a TAG SCANNER (FIX:/NOTE:/TODO:/QUESTION:) in the current implementation, NOT a memory management skill
- **Note**: The SKILL.md content describes tag scanning functionality identical to `.claude/skills/skill-learn/SKILL.md` (which is the `/fix-it` command's backend). The memory management described in the command file appears to be implemented directly in the command, not in the skill.

#### 1.4 Research Integration: `--remember` flag
- **Path**: `.opencode/commands/research.md` (Step 5)
- **Purpose**: When `/research N --remember` is used, searches memory vault via MCP and includes relevant memories in research context
- **Graceful degradation**: If MCP unavailable, skips memory search and continues

#### 1.5 Documentation
- `.opencode/docs/guides/learn-usage.md` - Usage guide for /learn
- `.opencode/docs/guides/memory-setup.md` - MCP server setup for Obsidian
- `.opencode/docs/guides/memory-troubleshooting.md` - Troubleshooting guide
- `.opencode/docs/examples/knowledge-capture-usage.md` - Examples including task mode

#### 1.6 MCP Server Integration
- Uses Obsidian CLI REST plugin as MCP server
- Provides: search_notes, read_note, write_note, list_notes
- Configured via `settings.json` with API key and port

### 2. Existing Extension System Architecture

#### 2.1 Extension Structure
Every extension follows this structure:
```
extensions/{name}/
  manifest.json       # Name, version, provides, merge_targets
  EXTENSION.md        # Content injected into CLAUDE.md/AGENTS.md
  index-entries.json  # Context index entries to merge (optional)
  settings-fragment.json  # Settings to merge (optional)
  agents/             # Agent definition files (.md)
  skills/             # Skill directories with SKILL.md
  rules/              # Rule files (.md)
  context/            # Context files (project/* structure)
  commands/           # Command files (.md)
  scripts/            # Shell scripts
```

#### 2.2 manifest.json Schema
```json
{
  "name": "string",
  "version": "string",
  "description": "string",
  "language": "string|null",
  "dependencies": [],
  "provides": {
    "agents": ["filename.md"],
    "skills": ["skill-name"],
    "commands": ["filename.md"],
    "rules": ["filename.md"],
    "context": ["project/subpath"],
    "scripts": ["filename.sh"],
    "hooks": ["filename"]
  },
  "merge_targets": {
    "claudemd|opencode_md": { "source": "EXTENSION.md", "target": "...", "section_id": "..." },
    "index": { "source": "index-entries.json", "target": "..." },
    "settings": { "source": "settings-fragment.json", "target": "..." }
  },
  "mcp_servers": {}
}
```

#### 2.3 Loading Mechanism
The extension loader is parameterized via `config.lua` which creates configurations for both Claude and OpenCode:

- **Claude config**: `base_dir=".claude"`, `config_file="CLAUDE.md"`, `agents_subdir="agents"`, `merge_target_key="claudemd"`
- **OpenCode config**: `base_dir=".opencode"`, `config_file="OPENCODE.md"`, `agents_subdir="agent/subagents"`, `merge_target_key="opencode_md"`

Loading process (`init.lua`):
1. Read manifest from extension directory
2. Check for conflicts with existing files
3. Copy agents, commands, rules to target directories (flat files)
4. Copy skill directories (recursive)
5. Copy context directories (recursive, preserving structure)
6. Copy scripts
7. Process merge targets (inject EXTENSION.md section, merge settings, append index entries)
8. Run post-load verification
9. Save state to `extensions.json`

Unloading reverses all operations using tracked state.

#### 2.4 Valid `provides` Categories
From `manifest.lua`:
```lua
local VALID_PROVIDES = {
  "agents", "skills", "commands", "rules", "context", "scripts", "hooks"
}
```

### 3. Gap Analysis: Memory Extension Requirements

#### 3.1 Components That Fit Existing Categories

| Component | Category | Fits? | Notes |
|-----------|----------|-------|-------|
| `/learn` command | `commands` | Yes | Copy learn.md to commands/ |
| `skill-learn` skill | `skills` | Yes | Copy skill-learn/ to skills/ |
| Memory docs | `context` | Yes | Could go in context/project/memory/ |
| EXTENSION.md section | `merge_targets` | Yes | Standard claudemd/opencode_md injection |
| MCP settings | `merge_targets.settings` | Yes | Standard settings fragment merge |

#### 3.2 Components That Do NOT Fit

| Component | Issue | Details |
|-----------|-------|---------|
| Memory vault directory | No `provides` category | `.opencode/memory/` is a data directory, not agents/skills/context/etc. |
| `--remember` flag in /research | Cross-extension dependency | Modifies an existing core command's behavior |
| `.obsidian/` config | Special handling needed | Should be created but gitignored |

#### 3.3 Critical Gap: Data Directory Support

The memory vault (`.opencode/memory/`) is a **data directory** that doesn't fit any existing `provides` category:

- It's NOT `context` (context files are read-only reference docs loaded by agents)
- It's NOT `scripts` (scripts are executable tools)
- It's NOT `agents`, `skills`, `commands`, or `rules`

The vault is a **read-write data store** that grows over time. This is fundamentally different from the static file copies that extensions currently perform.

#### 3.4 The `--remember` Flag Problem

The `--remember` flag modifies the core `/research` command. Currently, extensions can:
- ADD new commands (via `provides.commands`)
- ADD new agents/skills (via `provides.agents/skills`)
- INJECT content into CLAUDE.md/AGENTS.md (via `merge_targets`)

But extensions CANNOT:
- MODIFY existing core commands
- Add flags/options to existing commands
- Hook into existing command workflows

### 4. Required Extension System Changes

#### 4.1 Option A: Add "data" Category (Recommended)

Add a new `provides` category called `"data"` that handles read-write data directories:

```json
{
  "provides": {
    "data": ["memory"]
  }
}
```

**Loader change**: In `loader.lua`, add a `copy_data_dirs` function similar to `copy_context_dirs` but that copies to the base directory root (e.g., `.opencode/memory/`) rather than to `context/`.

**manifest.lua change**: Add `"data"` to `VALID_PROVIDES`.

**Complexity**: Low - follows existing pattern of `copy_context_dirs`.

#### 4.2 Option B: Use "context" Category with Custom Target

Treat the vault as a special context directory and add mapping configuration:

```json
{
  "provides": {
    "context": ["memory"]
  },
  "custom_targets": {
    "memory": ".opencode/memory"
  }
}
```

**Problem**: This conflates read-only context with read-write data. Not recommended.

#### 4.3 Option C: Use "hooks" Category for Research Integration

For the `--remember` flag, add a hook mechanism:

```json
{
  "provides": {
    "hooks": ["research-pre-delegate.md"]
  }
}
```

Hooks could be step injections into existing commands. However, this is a significant architectural change.

**Alternative**: Simply document in the EXTENSION.md that the user should manually modify the research command to add `--remember` support after loading. Or, have the EXTENSION.md content include instructions for the `--remember` flag that agents can detect.

### 5. Proposed Extension Structure

```
extensions/memory/
  manifest.json
  EXTENSION.md           # Inject memory docs into AGENTS.md/CLAUDE.md
  index-entries.json     # Context index entries for memory docs
  settings-fragment.json # MCP server config for obsidian-memory
  commands/
    learn.md             # /learn command
  skills/
    skill-learn/
      SKILL.md           # Memory management skill (needs rewrite)
      README.md
  context/
    project/memory/
      learn-usage.md         # Usage guide
      memory-setup.md        # MCP setup guide
      memory-troubleshooting.md  # Troubleshooting
      knowledge-capture-usage.md # Examples
  data/                  # NEW: Data directories
    memory/
      00-Inbox/README.md
      10-Memories/README.md
      20-Indices/README.md
      20-Indices/index.md
      30-Templates/README.md
      30-Templates/memory-template.md
```

### 6. skill-learn Discrepancy

**Critical finding**: The `skill-learn/SKILL.md` in `.opencode` currently contains TAG SCANNING code (FIX:/NOTE:/TODO:), NOT memory management code. This is the same functionality as `.claude`'s `/fix-it` command backend. The actual memory management workflow described in `/learn` command appears to be implemented inline in the command file, not in the skill.

For the memory extension, the skill needs to be either:
1. **Rewritten** to be a proper memory management skill (create/search/update memories)
2. **Left as-is** with memory logic staying in the command file (simpler but less modular)

### 7. Dual-System Consideration

The extension system supports both `.claude` and `.opencode`. The memory extension should work for BOTH systems:
- For `.claude`: loads into `.claude/` with claude-specific merge targets
- For `.opencode`: loads into `.opencode/` with opencode-specific merge targets

The manifest can include both merge target keys:
```json
{
  "merge_targets": {
    "claudemd": { ... },
    "opencode_md": { ... }
  }
}
```

However, currently each extension lives in EITHER `.claude/extensions/` OR `.opencode/extensions/`. The shared extension loader picks up extensions from the configured `global_extensions_dir`. For a memory extension to work with both systems, it would need to exist in both directories (or a shared location).

## Decisions

1. **Option A (data category) is recommended** for handling the vault directory
2. **The skill-learn needs rewriting** to separate tag scanning from memory management
3. **The --remember flag** should be documented in EXTENSION.md rather than requiring hook system changes
4. **The extension should target .opencode first** since that's where the memory system currently lives

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Data loss during unload | Medium | High | Unload should NOT delete user-created memory files; only remove template/skeleton structure |
| skill-learn confusion | High | Medium | Clearly separate tag-scanning skill from memory-management skill with different names |
| --remember flag breaks | Low | Low | Graceful degradation already implemented; flag does nothing without MCP |
| Extension system changes break existing extensions | Low | High | New "data" category is additive; existing categories unchanged |

## Implementation Recommendations

### Phase 1: Extension System Enhancement
1. Add `"data"` to `VALID_PROVIDES` in `manifest.lua`
2. Add `copy_data_dirs()` to `loader.lua` (copies to base_dir root)
3. Update `check_conflicts()` to handle data directories
4. Add special unload behavior for data: only remove skeleton files, NOT user-created content

### Phase 2: Create Memory Extension
1. Create `extensions/memory/manifest.json`
2. Move `/learn` command to `extensions/memory/commands/`
3. Create proper memory-management skill (separate from tag scanning)
4. Move memory docs to `extensions/memory/context/project/memory/`
5. Create `extensions/memory/data/memory/` with vault skeleton
6. Create EXTENSION.md with memory system documentation
7. Create settings-fragment.json with MCP server config

### Phase 3: Clean Up Core
1. Remove `.opencode/memory/` from core (now in extension)
2. Remove `/learn` command from core
3. Remove memory docs from `.opencode/docs/guides/`
4. Document `--remember` flag as optional (extension-dependent)

### Phase 4: Unload Safety
1. Implement "data directory preservation" in the unloader
2. When unloading memory extension: remove command, skill, context, settings
3. Do NOT remove `.opencode/memory/10-Memories/*` (user data)
4. Optionally prompt user: "Remove memory vault data? This will delete all stored memories."

## Appendix

### Search Queries Used
- Glob patterns: `.opencode/memory/**/*`, `.claude/extensions/**/*`, `.opencode/extensions/**/*`
- Grep patterns: `memory|learn|skill-learn` across .opencode/, extension loader files
- File reads: manifest.json files, loader.lua, merge.lua, init.lua, config.lua, learn.md, SKILL.md

### Key File Paths Referenced
- `/home/benjamin/.config/nvim/.opencode/memory/` - Memory vault root
- `/home/benjamin/.config/nvim/.opencode/commands/learn.md` - Learn command
- `/home/benjamin/.config/nvim/.opencode/skills/skill-learn/SKILL.md` - Learn skill (tag scanner)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/` - Extension loader system
- `/home/benjamin/.config/nvim/.claude/extensions/` - Claude extensions directory
- `/home/benjamin/.config/nvim/.opencode/extensions/` - OpenCode extensions directory
