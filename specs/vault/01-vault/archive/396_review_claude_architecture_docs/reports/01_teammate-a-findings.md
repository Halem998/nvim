# Research Report: Task #396 — Teammate A Findings

**Task**: 396 - Review .claude/ agent system architecture documentation
**Focus**: Implementation approaches and patterns for the documentation audit
**Teammate**: A (Primary Angle)
**Started**: 2026-04-10
**Completed**: 2026-04-10
**Effort**: ~2 hours
**Sources/Inputs**: Codebase analysis (extensions, manifests, READMEs, Lua picker code)
**Artifacts**: This report

---

## Key Findings

1. **Only 3 of 14 extensions have README.md files**: `present`, `founder`, `memory`. The remaining 11 lack user-facing documentation.

2. **`filetypes` is the highest-priority gap**: It has 5 commands, 6 agents, 5 skills, 2 MCP servers, and substantial context — but no README.md.

3. **`present/README.md` is a minimal stub**: It covers commands with examples but omits skill-agent mapping, language routing, architecture tree, workflow diagram, and output artifacts — all present in `founder/README.md`. The present README explicitly delegates to EXTENSION.md for skill-agent mappings (a design inconsistency vs founder's self-contained README).

4. **`founder/README.md` is the actual reference model**: It is significantly more complete than `present/README.md` — covering architecture, workflow, output artifacts, key patterns, MCP setup, and references.

5. **lean manifest lists scripts that do not exist**: `manifest.json` declares `['setup-lean-mcp.sh', 'verify-lean-mcp.sh']` but there is no `scripts/` directory in the lean extension.

6. **`formal` extension has no implementation agents/skills**: Research-only pattern (4 research agents, no implementation), but this is intentional and not documented anywhere in EXTENSION.md.

7. **The extensions/README.md is accurate**: The available extensions table matches actual directories. No stale or missing entries.

8. **Routing tables in EXTENSION.md files are accurate**: All verified skill-agent mappings match actual files on disk for filetypes, formal, lean, and latex.

---

## Reference Model Analysis

### present/README.md Structure (Current — Minimal)

```
# Present Extension
## Table of Contents
## Overview               (feature table: command -> purpose)
## Commands               (5 sections with bash examples)
  ### /grant
  ### /budget
  ### /timeline
  ### /funds
  ### /talk
## Related Files          (3 links to EXTENSION.md and context/)
```

**What `present/README.md` covers**:
- Commands with bash usage examples and mode lists
- Feature overview table
- Links to EXTENSION.md for "full documentation"

**What `present/README.md` omits** (delegated to EXTENSION.md):
- Skill-agent mapping table
- Language routing table (5 sub-types: present:grant, present:budget, etc.)
- Architecture/directory tree
- Workflow diagram (research -> plan -> implement lifecycle)
- Output artifacts section (where files land)
- Talk modes table (CONFERENCE, SEMINAR, DEFENSE, etc.)

**Assessment**: `present/README.md` is a lightweight user-facing entry point. It is intentionally thin — it refers users to `EXTENSION.md` for technical detail. This creates a two-document pattern (README for users, EXTENSION.md for system integration).

### founder/README.md Structure (More Complete)

```
# Founder Extension (v3.0)
## What's New in v3.0         (version changelog)
## Overview                   (command summary table)
## Installation               (how to load via <leader>ac)
## MCP Tool Setup             (SEC EDGAR, Firecrawl with setup steps)
## Commands                   (8 sections: market, analyze, strategy, legal, project, deck, finance, sheet)
  ### /market ... /sheet      (syntax, modes, examples for each)
## Architecture               (directory tree)
## Workflow
  ### Standard Phased Workflow (ASCII diagram)
  ### Per-Type Research Agents (routing table)
  ### Legacy Workflow (--quick) (diagram)
## Key Patterns               (forcing questions, modes, decision frameworks)
## Output Artifacts
  ### Task Mode               (artifact paths per command)
  ### Legacy Mode             (--quick paths)
## References                 (external sources: gstack, YC Library, BMC)
```

**Assessment**: `founder/README.md` is self-contained and comprehensive. It does not delegate to EXTENSION.md for technical detail. It is the better reference model for a complete README.

### memory/README.md Structure (Also Strong)

```
# Memory Extension
## Loading the Extension      (single line: <leader>ac -> select "memory")
## The Two Commands           (write/read summary table)
## Writing Memories
  ### Input Modes, What Happens, Three Write Operations
## Reading Memories
  ### During Research, Manual Access
## Storage Details
  ### Vault Location, Memory File Format, Naming Convention, Frontmatter, Index
## Configuration
  ### MCP Server Setup (two options), Graceful Degradation
## Troubleshooting            (4 common issues)
## Best Practices             (when to write/read, effective writing, vault size)
## Subdirectories             (links to commands/, skills/, context/)
## Navigation                 (link to parent)
```

**Assessment**: `memory/README.md` is excellent for a capability-oriented extension. Strong on: user mental model, troubleshooting, best practices, storage details. Weaker on: architecture tree, routing (N/A — no task type).

---

## Extension Inventory

### Status Per Extension

| Extension | README? | Quality | Key Gaps |
|-----------|---------|---------|----------|
| present | YES | Minimal | Skill-agent mapping, routing, architecture, workflow, artifacts |
| founder | YES | Comprehensive | None significant |
| memory | YES | Strong | No architecture tree (minor) |
| filetypes | NO | Missing | Entire README needed |
| nvim | NO | Missing | 2 agents, 2 skills, 1 rule — needs README |
| lean | NO | Missing | 2+ commands (/lake, /lean), MCP setup, scripts inconsistency |
| latex | NO | Missing | Simple extension — 1 rule, 2 agents; README straightforward |
| typst | NO | Missing | Simple extension — 2 agents, 2 skills; README straightforward |
| python | NO | Missing | Simple extension — 2 agents, 2 skills; README straightforward |
| nix | NO | Missing | MCP server (mcp-nixos) setup needs documentation |
| web | NO | Missing | /tag command (user-only), MCP absent, rules |
| z3 | NO | Missing | Simple extension — 2 agents, 2 skills; README straightforward |
| epidemiology | NO | Missing | R tooling context needed |
| formal | NO | Missing | Multi-language routing (formal/logic/math/physics), research-only pattern |

### Priority Ordering for README Creation

**High Priority** (complex + user-facing commands):
1. `filetypes` — 5 commands, 6 agents, 2 MCP servers, no README
2. `lean` — 2 commands (/lake, /lean), MCP (lean-lsp), scripts manifest inconsistency
3. `formal` — 4 languages, complex domain routing, research-only pattern undocumented

**Medium Priority** (have MCP or rules that need documentation):
4. `nix` — MCP server (mcp-nixos), 1 rule, no commands
5. `nvim` — Core extension for this repo, 1 rule, no commands
6. `web` — /tag command (user-only), 1 rule, 3 skills

**Lower Priority** (simple, research/implement only):
7. `latex` — 1 rule, 2 agents
8. `epidemiology` — 2 agents, R tooling
9. `python` — 2 agents, standard pattern
10. `typst` — 2 agents, standard pattern
11. `z3` — 2 agents, standard pattern

### Detailed: filetypes Extension

The `filetypes` extension has no README but is one of the most complex:

**Directory structure**:
```
filetypes/
├── manifest.json         (v2.2.0, 6 agents, 5 skills, 5 commands, 2 MCP servers)
├── EXTENSION.md          (skill-agent mapping + commands table)
├── index-entries.json    (context entries)
├── opencode-agents.json
├── agents/               (6: filetypes-router-agent, document-agent, spreadsheet-agent,
│                          presentation-agent, scrape-agent, docx-edit-agent)
├── skills/               (5: skill-filetypes, skill-spreadsheet, skill-presentation,
│                          skill-scrape, skill-docx-edit)
├── commands/             (5: convert.md, table.md, slides.md, scrape.md, edit.md)
└── context/project/filetypes/
    ├── README.md         (context overview — NOT the extension README)
    ├── domain/           (conversion-tables.md, office-edit-patterns.md,
    │                      pitch-deck-structure.md, presentation-slides.md,
    │                      spreadsheet-tables.md, touying-pitch-deck-template.md)
    ├── patterns/         (same files as domain — appears to be duplicate structure)
    └── tools/            (dependency-guide.md, mcp-integration.md,
                           superdoc-integration.md, tool-detection.md)
```

**MCP servers**: `superdoc` (npx @superdoc-dev/mcp) and `openpyxl` (npx @jonemo/openpyxl-mcp)

A README for filetypes must cover:
- 5 commands with usage examples (/convert, /table, /slides, /scrape, /edit)
- MCP setup for superdoc and openpyxl-mcp
- Routing: filetypes-router-agent dispatches to specialized agents
- Tool dependencies (markitdown, pandoc, python-pptx, etc.)
- The `skill-filetypes` is listed twice in EXTENSION.md (for both filetypes-router-agent AND document-agent) — same skill routes to two agents

### Detected Inconsistency: lean Scripts

**File**: `/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json`

```json
"scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"]
```

**Reality**: No `scripts/` directory exists in the lean extension. The loader (`shared/extensions/loader.lua`) reads `manifest.provides.scripts` to copy files — if they don't exist, the copy silently fails. This is a manifest inconsistency.

**Impact**: When loading the lean extension, the loader silently skips the non-existent scripts. Users who expect MCP setup scripts are missing them.

### Detected Pattern: formal Research-Only Extension

The `formal` extension has 4 research agents and 4 research skills, but no implementation agents or skills. This is an intentional design (formal reasoning tasks use the general implementation agent for code/proof writing), but it is not documented anywhere:
- `EXTENSION.md` has no note about implementation routing
- `manifest.json` has no routing section
- No README explains this deviation from the standard 2-agent pattern

---

## Routing Table Accuracy

| Extension | EXTENSION.md accurate? | Notes |
|-----------|------------------------|-------|
| filetypes | YES | 6 agents and 5 skills match EXTENSION.md and manifest.json |
| formal | YES | 4 agents and 4 skills match |
| lean | YES (agents/skills) | Scripts listed in manifest don't exist — loader silently fails |
| latex | YES | 2 agents, 2 skills, 1 rule |
| nix | YES | 2 agents, 2 skills, 1 rule; MCP documented in EXTENSION.md |
| nvim | YES | 2 agents, 2 skills, 1 rule |
| epidemiology | YES | 2 agents, 2 skills |
| present | YES | 5 agents match EXTENSION.md |
| founder | YES | 14 agents, 14 skills — dense but consistent |
| memory | YES | skill-memory (direct execution) is correctly noted in EXTENSION.md |
| python | YES | 2 agents, 2 skills |
| typst | YES | 2 agents, 2 skills |
| web | YES | 2 agents, 3 skills (/tag is direct execution) |
| z3 | YES | 2 agents, 2 skills |

---

## Recommended README Template

Derived from `founder/README.md` as the reference model, with optional sections based on extension complexity.

```markdown
# {Extension Name} Extension [({version})]

{One sentence description of what this extension provides.}

## Overview

{Brief paragraph + capability table:}

| Feature | Command | Purpose |
|---------|---------|---------|
| Feature Name | `/command` | Short purpose |

## Installation

This extension is automatically available when loaded via `<leader>ac` in Neovim.

## [MCP Tool Setup]

{Required only if extension uses MCP servers.}

### {MCP Server Name} ({pricing tier})

{Description, setup steps, what it enables, graceful degradation.}

## Commands

{One section per command:}

### /{command} - {Short Title}

{One line description.}

**Syntax**:
\`\`\`bash
/{command} "description"      # Create task
/{command} N                  # Resume/run on existing task
\`\`\`

**Modes**: MODE_A, MODE_B, MODE_C

## Architecture

\`\`\`
{extension}/
├── manifest.json             # Extension configuration (v{version})
├── EXTENSION.md              # CLAUDE.md merge content
├── index-entries.json        # Context discovery entries
├── README.md                 # This file
│
├── agents/                   # Agent definitions
│   ├── {name}-agent.md
│   └── ...
│
├── skills/                   # Skill wrappers
│   ├── skill-{name}/
│   │   └── SKILL.md
│   └── ...
│
├── commands/                 # Slash commands
│   └── {cmd}.md
│
[├── rules/                   # Optional: language-specific rules
│   └── {rule}.md]
│
└── context/                  # Domain knowledge
    └── project/{extension}/
        ├── README.md
        ├── domain/
        └── patterns/
\`\`\`

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-{name} | {name}-agent | {purpose} |

## Language Routing

| Task Type | Research Skill | Implementation Skill |
|-----------|----------------|---------------------|
| `{type}` | `skill-{name}-research` | `skill-{name}-implementation` |

## Workflow

{Diagram showing /research -> /plan -> /implement lifecycle, or command-specific flow.}

\`\`\`
/{command} "description"
    |
    v
[1] {Step 1 description}
    ...
\`\`\`

## Output Artifacts

| Command | Output Path |
|---------|------------|
| /{cmd} | `{dir}/{output-pattern}` |

## [Key Patterns / Notes]

{Optional section for important behavioral notes, design patterns, anti-patterns.}

## References

{Optional links to external documentation, libraries, frameworks.}
```

### Section Applicability Matrix

| Section | Simple extension | Complex extension | Utility extension |
|---------|-----------------|-------------------|-------------------|
| Overview | Required | Required | Required |
| Installation | Required | Required | Required |
| MCP Tool Setup | Omit | If needed | If needed |
| Commands | Omit (if none) | Required | Required |
| Architecture | Optional | Required | Required |
| Skill-Agent Mapping | Required | Required | N/A (if direct) |
| Language Routing | Required | Required | Omit |
| Workflow | Optional | Required | Required |
| Output Artifacts | Omit | Required | Optional |
| Key Patterns | Optional | Required | Optional |
| References | Optional | Optional | Optional |

"Simple extension": epidemiology, python, typst, z3 (2 agents, 2 skills, no commands)
"Complex extension": filetypes, founder, present, lean, formal (5+ agents or commands)
"Utility extension": memory, filetypes (command-driven, no task type routing)

---

## Evidence/Examples

### Evidence 1: present/README.md defers to EXTENSION.md

At `/home/benjamin/.config/nvim/.claude/extensions/present/README.md`, line 87:
```
- [EXTENSION.md](EXTENSION.md) - Full extension documentation with skill-agent mappings
```

The README explicitly says EXTENSION.md is the "full documentation." This two-file split is inconsistent with founder/README.md which is self-contained.

### Evidence 2: lean scripts missing from filesystem

`/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json`:
```json
"scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"]
```

But `ls /home/benjamin/.config/nvim/.claude/extensions/lean/` shows no `scripts/` directory. The MCP setup presumably requires manual configuration.

### Evidence 3: filetypes has a context/README.md but no extension README.md

`/home/benjamin/.config/nvim/.claude/extensions/filetypes/context/project/filetypes/README.md` exists (context documentation for agents), but `/home/benjamin/.config/nvim/.claude/extensions/filetypes/README.md` does not exist. These serve different purposes — the context README is for agents loading domain knowledge; the extension README is for users loading the extension.

### Evidence 4: formal has research-only agents — undocumented

```
/home/benjamin/.config/nvim/.claude/extensions/formal/agents/
  formal-research-agent.md
  logic-research-agent.md
  math-research-agent.md
  physics-research-agent.md

/home/benjamin/.config/nvim/.claude/extensions/formal/skills/
  skill-formal-research
  skill-logic-research
  skill-math-research
  skill-physics-research
```

No implementation agents. No note in EXTENSION.md explaining what happens when a user runs `/implement` on a formal task. The general-implementation-agent handles it by default, but this is opaque.

### Evidence 5: extensions/README.md table is accurate

All 14 extensions in the table match all 14 actual directories. No stale or missing entries.

### Evidence 6: picker loads from global extensions directory

`/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/config.lua`, line 56:
```lua
global_extensions_dir = global_dir .. "/.claude/extensions",
```

The picker at `<leader>ac` scans `~/.config/nvim/.claude/extensions/` for all directories containing `manifest.json`. The `description` field from manifest.json populates the picker preview.

---

## Confidence Level

**High confidence**:
- Extension inventory (directly observed from filesystem)
- Routing accuracy (cross-checked manifest vs EXTENSION.md vs actual files)
- lean scripts inconsistency (manifest claim vs filesystem reality)
- present README minimal coverage (directly read and analyzed)
- founder README as better reference model (directly read and compared)

**Medium confidence**:
- Priority ordering for README creation (based on complexity analysis, but user workflow priorities not assessed)
- present's two-file split being a design inconsistency vs intentional pattern

**Lower confidence**:
- Whether the lean scripts were intentionally removed or accidentally omitted
- Whether the formal research-only pattern causes any user confusion in practice
