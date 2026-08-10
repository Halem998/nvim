# Research Report: Task #106

**Task**: 106 - Review dotfiles .claude/ agent system for NixOS to add nix/ extension
**Started**: 2026-03-02T12:00:00Z
**Completed**: 2026-03-02T12:45:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: Task #102 (extensions populated), Task #105 (web extension created)
**Sources/Inputs**: Dotfiles .claude/ system, nvim config extensions, task 102/105 artifacts
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- The dotfiles `.claude/` at `/home/benjamin/.dotfiles/.claude/` contains a mature Nix development support system with 2 agents, 2 skills, 1 rule, and 14 context files
- The nvim config's extension architecture (established in tasks 102/105) uses a standardized structure: manifest.json, EXTENSION.md, index-entries.json, agents/, skills/, rules/, context/
- Creating a nix/ extension requires extracting the dotfiles Nix components and adapting them to the extension format, following the exact patterns used by lean/ and web/ extensions
- The nix extension should include MCP-NixOS integration support (settings-fragment.json) and orchestrator routing updates

## Context & Scope

This research reviews the NixOS agent system in `/home/benjamin/.dotfiles/.claude/` to determine what is needed for a `nix/` extension in `.claude/extensions/nix/` of the nvim config. The extension system was established by tasks 102 and 105, with lean/ being the first extension (with MCP support) and web/ being the most recent (task 105).

## Findings

### 1. Dotfiles Nix Agent System Components

The dotfiles `.claude/` system contains these Nix-specific components:

#### Agents (2 files)

| File | Size | Description |
|------|------|-------------|
| `agents/nix-research-agent.md` | 16,821 bytes (510 lines) | Research agent with MCP-NixOS integration, graceful degradation, search priority trees |
| `agents/nix-implementation-agent.md` | 23,637 bytes (857 lines) | Implementation agent with MCP validation, NixOS/HM module patterns, verification commands |

**Key Features**:
- Both agents support MCP-NixOS tools (`mcp__nixos__nix`, `mcp__nixos__nix_versions`) with graceful degradation when unavailable
- Research agent has a detailed search strategy decision tree (MCP-first, fallback to WebSearch/CLI)
- Implementation agent includes NixOS module, Home Manager module, overlay, and flake patterns
- Both use the standard metadata file return pattern (not console JSON)

#### Skills (2 directories)

| Skill | File | Size | Description |
|-------|------|------|-------------|
| `skill-nix-research` | SKILL.md | 5,418 bytes (221 lines) | Thin wrapper delegating to nix-research-agent |
| `skill-nix-implementation` | SKILL.md | 13,597 bytes (381 lines) | Thin wrapper delegating to nix-implementation-agent |

**Key Features**:
- Both implement skill-internal postflight pattern
- Both include preflight status updates (state.json + TODO.md)
- Both include postflight marker file creation
- Implementation skill handles completion_data propagation (completion_summary, roadmap_items)

#### Rules (1 file)

| File | Size | Description |
|------|------|-------------|
| `rules/nix.md` | ~230 lines | Nix development rules with path pattern `**/*.nix` |

**Coverage**: Formatting (2-space indent, 100-char line limit), module patterns (NixOS/HM), flake conventions, naming conventions, overlay patterns (`final`/`prev`), testing/verification commands, and anti-patterns.

#### Context Files (14 files in project/nix/)

```
project/nix/
  README.md                      (94 lines) - Overview and loading strategy
  domain/
    nix-language.md              (~100 lines) - Nix expression syntax
    flakes.md                    (~130 lines) - Flake structure, inputs, follows
    nixos-modules.md             (~130 lines) - Module system, options, config
    home-manager.md              (~130 lines) - User-level configuration
  patterns/
    module-patterns.md           (~120 lines) - Module definition patterns
    overlay-patterns.md          (~120 lines) - Overlay customization
    derivation-patterns.md       (~150 lines) - Package building
  standards/
    nix-style-guide.md           (~130 lines) - Formatting and naming
  tools/
    nixos-rebuild-guide.md       (~100 lines) - System rebuild workflows
    home-manager-guide.md        (~110 lines) - Home Manager workflows
```

#### Orchestrator Routing

The dotfiles orchestrator routes `nix` language to:
- Research: `skill-nix-research`
- Implementation: `skill-nix-implementation`

The nvim config's orchestrator currently does NOT have nix routing.

#### CLAUDE.md Integration

The dotfiles CLAUDE.md includes:
- `nix` in the Language-Based Routing table with MCP-NixOS tools
- `skill-nix-research` and `skill-nix-implementation` in the Skill-to-Agent Mapping
- `rules/nix.md` in the Rules References
- Nix context imports listed under Context Imports

### 2. Extension Architecture (from Tasks 102/105)

The established extension pattern consists of:

#### Required Files

| File | Purpose |
|------|---------|
| `manifest.json` | Extension metadata: name, version, description, language, provides, merge_targets, mcp_servers |
| `EXTENSION.md` | CLAUDE.md section content: language routing, skill-agent mapping, key technologies |
| `index-entries.json` | Context discovery entries for index.json merge |

#### Directory Structure

```
extensions/{name}/
  manifest.json
  EXTENSION.md
  index-entries.json
  agents/                     # Agent definition files
  skills/                     # Skill directories with SKILL.md
  rules/                      # Rule files with path matchers
  context/project/{name}/     # Domain context files
  scripts/                    # Optional setup/verification scripts
  hooks/                      # Optional hook scripts
  commands/                   # Optional slash command files
  settings-fragment.json      # Optional MCP/permissions fragment
```

#### Key Pattern: Lean Extension with MCP

The lean/ extension provides the closest precedent for the nix/ extension because it also has:
- MCP server integration (`lean-lsp` in manifest.json `mcp_servers` and settings-fragment.json)
- 2 agents, 4+ skills
- Commands, scripts
- Rich context hierarchy

#### Key Pattern: Web Extension (Task 105)

The web/ extension provides the cleanest template because it was the most recently created:
- manifest.json with `merge_targets` for claudemd, index (no settings)
- 2 agents, 2 skills, 1 rule, 20 context files
- All content generalized (no project-specific references)

### 3. Required Components for nix/ Extension

Based on analysis of both the dotfiles source and extension architecture:

#### Agents (2 files)

1. `agents/nix-research-agent.md` - Adapted from dotfiles, with MCP-NixOS integration
2. `agents/nix-implementation-agent.md` - Adapted from dotfiles, with MCP validation patterns

**Adaptations needed**:
- Context reference paths must point to `.claude/extensions/nix/context/project/nix/` instead of `.claude/context/project/nix/`
- Rules references must point to `.claude/extensions/nix/rules/nix.md`
- Remove any dotfiles-specific references (host names, flake paths)

#### Skills (2 directories)

1. `skills/skill-nix-research/SKILL.md` - Thin wrapper for nix-research-agent
2. `skills/skill-nix-implementation/SKILL.md` - Thin wrapper for nix-implementation-agent

**Adaptations needed**:
- Context references updated to extension paths
- Trigger conditions specify language "nix"

#### Rules (1 file)

1. `rules/nix.md` - Nix development rules (path pattern `**/*.nix`)

**Adaptations needed**:
- Remove dotfiles-specific examples if any
- Context references updated to extension paths

#### Context Files (11 files)

```
context/project/nix/
  README.md
  domain/
    nix-language.md
    flakes.md
    nixos-modules.md
    home-manager.md
  patterns/
    module-patterns.md
    overlay-patterns.md
    derivation-patterns.md
  standards/
    nix-style-guide.md
  tools/
    nixos-rebuild-guide.md
    home-manager-guide.md
```

**Adaptations needed**:
- Remove dotfiles-specific host names and configuration paths
- Generalize examples to be project-agnostic

#### Metadata Files (3-4 files)

1. `manifest.json` - Extension manifest
2. `EXTENSION.md` - CLAUDE.md section for nix language routing
3. `index-entries.json` - Context discovery entries for all 11 context files
4. `settings-fragment.json` - MCP-NixOS server configuration (optional - only if MCP desired)

### 4. MCP-NixOS Integration Decision

The dotfiles system references `mcp__nixos__nix` and `mcp__nixos__nix_versions` MCP tools. Two approaches:

**Option A: Include MCP support** (recommended, matching lean/ pattern)
- Add `settings-fragment.json` with MCP-NixOS server configuration
- Add `mcp_servers` section in manifest.json
- Agents already have graceful degradation (work without MCP)

**Option B: Exclude MCP support**
- Simpler extension, no settings-fragment.json
- MCP tools referenced in agents would just degrade gracefully
- Can be added later

Recommendation: **Option A** - include MCP support since the agents are already designed for it, the lean/ extension sets the precedent for MCP in extensions, and graceful degradation means it works either way.

### 5. Orchestrator Routing Update

The nvim config's orchestrator (`skill-orchestrator/SKILL.md`) needs a new routing entry:

```
| nix | skill-nix-research | skill-nix-implementation |
```

This is part of the EXTENSION.md merge target but may also need manual orchestrator update.

### 6. CLAUDE.md Integration

The EXTENSION.md file should contain a section that can be merged into CLAUDE.md:
- Language routing table row for `nix`
- Skill-to-agent mapping entries
- Key technologies list
- Build verification commands

## Decisions

1. **Follow web/ extension as primary template** - It is the most recent and cleanest pattern
2. **Include MCP-NixOS support** - Agents already support it with graceful degradation
3. **Include settings-fragment.json** - Following lean/ extension pattern for MCP servers
4. **11 context files** (not 14) - The context/project/nix/ directory in dotfiles has 11 substantive files (README + 4 domain + 3 patterns + 1 standards + 2 tools)
5. **No commands or scripts needed** - Unlike lean/ (which has /lake and /lean), nix tasks use the standard /research, /plan, /implement workflow
6. **Generalize all dotfiles-specific content** - Remove host names (garuda, nandi, hamsa), user-specific paths, and dotfiles-specific flake references

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| MCP-NixOS server not available in all environments | Low | Agents have built-in graceful degradation |
| Dotfiles agents are very large (510/857 lines) | Medium | Extract cleanly, remove project-specific sections |
| Orchestrator update missed | High | Include as explicit phase in implementation plan |
| Context paths not updated after extraction | High | Systematic find-and-replace, verification grep |

## Appendix

### File Inventory Summary

| Component | Source (dotfiles) | Target (extension) | Count |
|-----------|-------------------|-------------------|-------|
| Agents | `.claude/agents/nix-*.md` | `extensions/nix/agents/` | 2 |
| Skills | `.claude/skills/skill-nix-*/SKILL.md` | `extensions/nix/skills/` | 2 |
| Rules | `.claude/rules/nix.md` | `extensions/nix/rules/` | 1 |
| Context | `.claude/context/project/nix/**` | `extensions/nix/context/project/nix/` | 11 |
| Metadata | (new) | `extensions/nix/` | 3-4 |
| **Total** | | | **19-20 files** |

### Search Queries Used

- Glob exploration of `/home/benjamin/.dotfiles/.claude/` structure
- Read of all nix-specific agents, skills, rules, and context files
- Comparison with lean/ and web/ extension structures
- Review of task 102 and 105 implementation summaries
- Analysis of orchestrator routing tables (both dotfiles and nvim config)

### Key File References

- Dotfiles nix-research-agent: `/home/benjamin/.dotfiles/.claude/agents/nix-research-agent.md`
- Dotfiles nix-implementation-agent: `/home/benjamin/.dotfiles/.claude/agents/nix-implementation-agent.md`
- Dotfiles nix rules: `/home/benjamin/.dotfiles/.claude/rules/nix.md`
- Dotfiles nix context: `/home/benjamin/.dotfiles/.claude/context/project/nix/`
- Dotfiles nix research skill: `/home/benjamin/.dotfiles/.claude/skills/skill-nix-research/SKILL.md`
- Dotfiles nix implementation skill: `/home/benjamin/.dotfiles/.claude/skills/skill-nix-implementation/SKILL.md`
- Lean extension (MCP precedent): `/home/benjamin/.config/nvim/.claude/extensions/lean/`
- Web extension (template): `/home/benjamin/.config/nvim/.claude/extensions/web/`
- Nvim orchestrator: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrator/SKILL.md`
