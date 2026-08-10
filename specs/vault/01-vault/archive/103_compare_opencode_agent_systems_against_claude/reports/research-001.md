# Research Report: Task #103

**Task**: 103 - Compare .opencode agent systems against .claude
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (Glob, Read, Bash)
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- The **.claude system** at `/home/benjamin/.config/nvim/.claude/` is the most mature and feature-rich, with 284 files, a unique extensions system (5 domain extensions), structured JSON context indexing, model enforcement via agent frontmatter, and comprehensive documentation (21 docs)
- The **Logos Theory .opencode** at `/home/benjamin/Projects/Logos/Theory/.opencode/` has achieved functional parity with .claude for its domain (Lean 4, logic, math, physics), with 277 files, 14 agents, 20 skills, and the richest domain context (163 context files including logic/math/physics domains). It has its own parity-summary.md confirming equivalence
- The **nvim .opencode** at `/home/benjamin/.config/nvim/.opencode/` is a hybrid system with 209 files that adds web development support (Astro, Tailwind, Cloudflare) not found in .claude or Logos, but lacks domain depth in several areas and has some deprecated/inconsistent agents
- **Recommendation**: Prefer the Logos Theory .opencode as the template to consolidate toward, since it is the most recently updated and has structured agent frontmatter with tool/permission controls. Merge the nvim .opencode web domain into it, and port back missing .claude features (extensions system, JSON context index, model enforcement)

## Context and Scope

This research compares three parallel agent management systems that share a common architecture but have diverged across three repositories:

1. `.claude/` at `~/.config/nvim/.claude/` -- the original "North Star" reference system
2. `.opencode/` at `~/Projects/Logos/Theory/.opencode/` -- Lean 4 theorem proving adaptation
3. `.opencode/` at `~/.config/nvim/.opencode/` -- Neovim + web development adaptation

All three implement the same checkpoint-based execution model (GATE IN -> DELEGATE -> GATE OUT -> COMMIT) with skills, agents, commands, context, and rules.

## Findings

### 1. Structural Comparison

#### Component Counts

| Component | .claude (nvim) | Logos .opencode | nvim .opencode |
|-----------|---------------|-----------------|----------------|
| Commands | 12 | 15 | 12 |
| Core Agents | 9 | 15 (incl orchestrator) | 11 + 1 (agent/) |
| Extension Agents | 12 | N/A | N/A |
| **Total Agents** | **21** | **15** | **12** |
| Skills | 14 | 20 | 14 |
| Extension Skills | 12 | N/A | N/A |
| **Total Skills** | **26** | **20** | **14** |
| Rules | 7 | 7 | 7 |
| Core Context Files | 117 | 163 | 121 |
| Extension Context | 35 | N/A | N/A |
| **Total Context** | **152** | **163** | **121** |
| Hooks | 9 | 9 | 9 |
| Scripts | 11 | 15 | 9 |
| Docs | 21 | 11 | 19 |
| Extensions | 5 dirs | N/A | N/A |
| **Total Files** | **284** | **277** | **209** |

#### Directory Layout Differences

| Feature | .claude | Logos .opencode | nvim .opencode |
|---------|---------|-----------------|----------------|
| Agent directory | `agents/` (plural) | `agent/subagents/` | `agents/` (plural) + `agent/` |
| Main config file | `CLAUDE.md` | `OPENCODE.md` | None (uses commands CLAUDE.md) |
| Context index format | `index.json` (structured) | `index.md` (markdown) | None |
| Extensions system | Yes (5 extensions) | No | No |
| Plugin system | No | Yes (`@opencode-ai/plugin` v1.2.9) | Yes (`@opencode-ai/plugin` v1.1.47) |
| Output transcripts | `output/implementation-001.md` | `output/*.md` (implement, learn, research, todo) | None |
| Model enforcement | `model:` in agent frontmatter | None | None |
| Settings model | `"model": "sonnet"` | `"model": "sonnet"` | `"theme": "gruvbox"` (no model) |

### 2. Agent Frontmatter Comparison

The three systems use different levels of detail in their agent frontmatter:

**.claude agents** (minimal but with model enforcement):
```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: opus
---
```

**Logos .opencode agents** (most detailed -- tools, permissions, temperature):
```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
mode: subagent
temperature: 0.3
tools:
  read: true
  write: true
  edit: true
  glob: true
  grep: true
  bash: true
  task: false
permissions:
  read:
    "**/*": "allow"
  write:
    "specs/**/*": "allow"
    "**/*.md": "allow"
  bash:
    "rg": "allow"
    "find": "allow"
    # ...
---
```

**nvim .opencode agents** (mixed -- some minimal, some with tools):
```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
---
```
vs.
```yaml
---
description: Implement Neovim Lua configuration with validation
mode: subagent
temperature: 0.2
tools:
  read: true
  write: true
  # ...
---
```

**Analysis**: The Logos .opencode has the most rigorous agent frontmatter with explicit tool grants and permission scoping. This is more secure and explicit. The .claude system compensates with model enforcement (`model: opus` for research agents). The nvim .opencode is inconsistent -- some agents have detailed frontmatter, others are minimal.

### 3. Domain Coverage Comparison

| Domain | .claude (core + ext) | Logos .opencode | nvim .opencode |
|--------|---------------------|-----------------|----------------|
| Neovim/Lua | Core (14 files) | -- | Core (14 files) |
| LaTeX | Core + Extension | Core (7 files) | -- |
| Lean 4 | Extension only | Core (16 files) | -- |
| Typst | Core + Extension | Core (17 files) | -- |
| Python | Extension only | -- | -- |
| Z3 | Extension only | -- | -- |
| Logic | -- | Core (14 files) | -- |
| Math | -- | Core (11 files) | -- |
| Physics | -- | Core (1 file) | -- |
| Web (Astro/Tailwind) | -- | -- | Core (17 files) |
| Meta/System | Core (6 files) | Core (6 files) | Core (6 files) |
| Hooks/WezTerm | Core (1 file) | -- | Core (1 file) |

**Key observations**:
- The .claude system uses extensions to add domains (lean, python, z3, latex, typst), keeping the core focused on neovim
- The Logos .opencode integrates everything inline (no extension system), which makes all domain knowledge available without loading extensions but at the cost of a larger base system
- The nvim .opencode uniquely includes web development (Astro, Tailwind CSS v4, Cloudflare) context that neither .claude nor Logos has
- The .claude system has the broadest total coverage when extensions are included (neovim + latex + lean + typst + python + z3)

### 4. Extensions System (Unique to .claude)

The .claude system has a modular extensions architecture with 5 extensions:

```
.claude/extensions/
  latex/    - LaTeX document support
  lean/    - Lean 4 theorem prover with MCP
  python/  - Python development
  typst/   - Typst document support
  z3/      - Z3 SMT solver
```

Each extension provides a `manifest.json` with:
- Agents, skills, commands, rules, context
- Merge targets (CLAUDEMD section, settings fragments, index entries)
- MCP server configuration
- Version tracking

Neither .opencode system has an equivalent extension mechanism. The Logos .opencode includes all domain knowledge directly in the base system, and the nvim .opencode does the same for web.

### 5. Context Discovery Differences

**.claude** uses a structured JSON index (`index.json`):
```json
{
  "path": "core/checkpoints/README.md",
  "domain": "core",
  "subdomain": "checkpoints",
  "topics": ["checkpoint-model", "gate-in", "gate-out"],
  "keywords": ["checkpoint", "validation", "workflow"],
  "summary": "Checkpoint-based execution model overview",
  "line_count": 100,
  "load_when": {
    "agents": ["general-implementation-agent"],
    "commands": ["/implement"]
  }
}
```

This enables programmatic context discovery via `jq` queries.

**Logos .opencode** uses a markdown index (`index.md`):
- Manual human-readable reference
- Approximate token counts
- Grouped by category
- No programmatic query capability

**nvim .opencode** has no context index at all. Agents rely on hardcoded `@-references` in their instructions.

### 6. Skill Structure Comparison

**.claude skills** (thin wrapper pattern):
```yaml
---
name: skill-researcher
description: Conduct general research...
allowed-tools: Task, Bash, Edit, Read, Write
---
```
- Detailed inline execution flow with bash code blocks
- Explicit stage numbering (Stage 1-7)
- Postflight operations embedded in skill

**Logos .opencode skills** (XML-structured thin wrapper):
```yaml
---
name: skill-researcher
description: Conduct general research...
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-research-agent
---
```
- Has `context: fork` and `agent:` fields for explicit routing
- Uses XML tags (`<context>`, `<role>`, `<task>`, `<execution>`, `<validation>`)
- Briefer execution flow

**nvim .opencode skills**: Similar to .claude pattern. No `context:` or `agent:` fields.

### 7. Unique Features Per System

#### .claude only:
- Extensions system (5 domain extensions with manifest.json)
- Structured JSON context index with `load_when` routing
- Model enforcement (`model: opus` in agent frontmatter)
- `settings.local.json` for extension settings merging
- `index.schema.json` for context index validation
- Agent frontmatter standard documentation
- Template files for commands, agents

#### Logos .opencode only:
- `context: fork` and `agent:` fields in skill frontmatter
- Detailed agent frontmatter (tools, permissions, temperature, mode)
- Shell scripts for command execution patterns (`command-execution.sh`, `lean-command-execution.sh`)
- Blocked MCP tools documentation
- MCP tool recovery patterns
- Output transcript files (implement, learn, research, todo)
- Plans directory with reports subdirectory
- `QUICK-START.md` for onboarding
- Feature parity summary document
- Plugin system (`@opencode-ai/plugin`)
- Additional Lean-specific commands (`/lake`, `/lean`)
- `OC_` prefix for task numbers
- Extra domain context (logic, math, physics)
- `hybrid-adapter.md` in orchestration context

#### nvim .opencode only:
- Web development domain (Astro, Tailwind CSS v4, Cloudflare Pages)
- Web agents (web-research, web-implementation)
- Web skills (skill-web-research, skill-web-implementation)
- Additional MCP servers (astro-docs, context7, playwright)
- `code-reviewer.md` agent
- `system-testing-guide.md` documentation
- `mcp-server-setup.md` guide
- `implementation-patterns.md` reference
- `security-permissions.md` reference
- `build-prompt.txt` agent helper

### 8. Consistency and Staleness Assessment

**.claude system**: Most consistent. Agents use uniform frontmatter. Extensions follow a standard manifest pattern. Documentation is comprehensive. Active development (task 102 in progress).

**Logos .opencode**: Recently updated (task 167 parity work, Feb 2026). Consistent agent frontmatter with rich tool/permission declarations. Has its own parity summary confirming equivalence. Includes some unique patterns (shell scripts for command execution) that are not in .claude.

**nvim .opencode**: Shows signs of mixed evolution. The `agent/` directory has a single deprecated `website-orchestrator.md`, while `agents/` has 11 active agents. Some agents have rich frontmatter (neovim-implementation, web-research), others are minimal (general-research, general-implementation). The plugin version (1.1.47) is older than Logos (1.2.9). No context index exists. Web domain context appears to be from a separate project that was merged.

## Recommendations

### 1. Prefer the Logos Theory .opencode as the consolidation base

Rationale:
- Most recently updated and verified for parity
- Most detailed agent frontmatter (tools, permissions, temperature)
- Richest domain context (163 files)
- Includes features unique to .opencode (plugin system, fork context)
- Has documented parity with .claude

### 2. Port .claude-unique features to the consolidated system

Priority features to port:
1. **Extensions system**: Modular domain packaging is the single most valuable .claude feature. It allows clean domain separation and manifest-driven loading
2. **JSON context index**: Enables programmatic context discovery and budget calculation. The markdown index in Logos is human-readable but not queryable
3. **Model enforcement**: Agent `model:` frontmatter field for controlling which model runs research vs implementation agents

### 3. Merge nvim .opencode web domain into the consolidated system

The nvim .opencode uniquely provides:
- Web development context (Astro, Tailwind, Cloudflare)
- Web agents and skills
- MCP server integrations (astro-docs, context7, playwright)

These should be preserved either as inline domain context or as a web extension.

### 4. Standardize agent frontmatter

Adopt the Logos .opencode detailed frontmatter as the standard:
- `mode:` (primary / subagent)
- `temperature:` (0.1-0.3)
- `tools:` (explicit tool grants)
- `permissions:` (file path access control)
- Plus .claude's `model:` field

### 5. Resolve nvim .opencode inconsistencies

Before consolidation:
- Remove deprecated `agent/website-orchestrator.md`
- Update all agents to use consistent frontmatter
- Add context index (JSON preferred)
- Update plugin version to match Logos (1.2.9)
- Standardize on either `agents/` or `agent/subagents/` directory naming

## Decisions

- The Logos Theory .opencode is recommended as the preferred base due to its recent parity work, rich agent frontmatter, and domain depth
- The .claude extensions system is the single most valuable feature to port forward
- The nvim .opencode web domain is unique and must be preserved in any consolidation
- Agent frontmatter should combine .opencode's tool/permission fields with .claude's model field

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Extensions system is .claude-specific (Claude Code feature) | May not port to opencode | Design opencode-native extension mechanism inspired by .claude's manifest pattern |
| Agent frontmatter fields may not be honored by opencode runtime | Tool/permission controls may be advisory only | Test which frontmatter fields opencode actually enforces vs ignores |
| Context index format difference | JSON vs markdown affects tooling | Standardize on JSON with markdown generation for readability |
| Plugin version skew | Older nvim .opencode plugin may lack features | Update both to same version |
| Web domain may be orphaned | nvim .opencode web content may become stale | Evaluate if web development is still active; archive if not |

## Appendix

### Search Queries Used

- `find` on all three system directories for file counts and structure
- `diff` on pattern files across systems
- Direct file reads of: OPENCODE.md, CLAUDE.md, settings.json, agent frontmatter, skill frontmatter, manifest.json, parity-summary.md, context index files

### File Count Summary

| System | Total Files | Notes |
|--------|-------------|-------|
| .claude (nvim) | 284 | Including 5 extensions with 79 files |
| Logos Theory .opencode | 277 | Excluding node_modules |
| nvim .opencode | 209 | Including web domain |

### Agent Name Cross-Reference

| Agent | .claude | Logos .opencode | nvim .opencode |
|-------|---------|-----------------|----------------|
| general-research | Yes | Yes | Yes |
| general-implementation | Yes | Yes | Yes |
| neovim-research | Yes | -- | Yes |
| neovim-implementation | Yes | -- | Yes |
| lean-research | Ext | Yes | -- |
| lean-implementation | Ext | Yes | -- |
| latex-research | Ext | Yes | -- |
| latex-implementation | Yes+Ext | Yes | -- |
| typst-research | Ext | Yes | -- |
| typst-implementation | Yes+Ext | Yes | -- |
| python-research | Ext | -- | -- |
| python-implementation | Ext | -- | -- |
| z3-research | Ext | -- | -- |
| z3-implementation | Ext | -- | -- |
| logic-research | -- | Yes | -- |
| math-research | -- | Yes | -- |
| meta-builder | Yes | Yes | Yes |
| planner | Yes | Yes | Yes (task-planner) |
| document-converter | Yes | Yes | Yes |
| web-research | -- | -- | Yes |
| web-implementation | -- | -- | Yes |
| code-reviewer | -- | -- | Yes |
| orchestrator | -- | Yes (primary) | Yes (deprecated) |
