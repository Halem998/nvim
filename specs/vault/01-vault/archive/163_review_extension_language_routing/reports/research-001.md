# Research Report: Task #163

**Task**: 163 - review_extension_language_routing
**Started**: 2026-03-09T22:49:11Z
**Completed**: 2026-03-09T22:55:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of commands, skills, agents, extensions, and context index
**Artifacts**: specs/163_review_extension_language_routing/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The extension system has significant gaps in language routing: 8 of 10 extension languages are either partially or completely missing from command routing tables
- The /task command's language detection only recognizes "neovim", "meta", and "general" -- all extension languages require manual `--language` flag
- The /research command routes latex and typst to `skill-researcher` (general-research-agent) instead of their dedicated extension skills
- The /implement command only routes neovim, general, meta, and markdown -- all extension languages fall through with no handler
- Context index.json is missing entries for z3, python, nix, web, and formal extensions (their index-entries.json files have not been merged)
- No automated extension installation/activation mechanism exists -- EXTENSION.md merge_targets are declarative but there is no script to execute the merges

## Context & Scope

This research examines the full chain from extension definition through language routing to agent dispatch and context loading. The system under review consists of:

1. **Extension definitions** in `.claude/extensions/{name}/manifest.json`
2. **Language routing tables** in commands (`/research`, `/plan`, `/implement`)
3. **Skill dispatch** from commands to skills
4. **Agent delegation** from skills to specialist agents
5. **Context discovery** via `.claude/context/index.json`

### Extensions Inventory

| Extension | Language(s) | Has Manifest | Has Skills | Has Agents | Has Context | Index Merged |
|-----------|-------------|-------------|------------|------------|-------------|--------------|
| lean | lean4 | Yes | Yes (4) | Yes (2) | Yes | Yes |
| latex | latex | Yes | Yes (2) | Yes (2) | Yes | Yes |
| typst | typst | Yes | Yes (2) | Yes (2) | Yes | Yes |
| python | python | Yes | Yes (2) | Yes (2) | Yes | NO |
| z3 | z3 | Yes | Yes (2) | Yes (2) | Yes | NO |
| nix | nix | Yes | Yes (2) | Yes (2) | Yes | NO |
| web | web | Yes | Yes (2) | Yes (2) | Yes | NO |
| formal | formal, logic, math, physics | Yes | Yes (4) | Yes (4) | Yes | NO |
| epidemiology | epidemiology, r | Yes | Yes (2) | Yes (2) | Yes | Partial (index merged, but references .opencode/ paths) |
| filetypes | null (command-based) | Yes | Yes (4) | Yes (5) | Yes | Unknown |

## Findings

### Finding 1: /task Command Language Detection is Incomplete

**Location**: `.claude/commands/task.md`, lines 111-114

The `/task` command's auto-detection only recognizes three languages:

```
"neovim", "plugin", "nvim", "lua" -> neovim
"meta", "agent", "command", "skill" -> meta
Otherwise -> general
```

All extension languages (lean4, latex, typst, python, z3, nix, web, formal, logic, math, physics, epidemiology, r) require users to manually specify `--language`. There is no mechanism to discover or load extension language keywords.

**Impact**: Tasks for extension languages default to "general" unless users know to use `--language`. This is a usability gap but not a functional failure since `--language` exists.

### Finding 2: /research Command Routes Extension Languages Incorrectly

**Location**: `.claude/commands/research.md`, lines 49-53

The routing table is:

| Language | Skill to Invoke |
|----------|-----------------|
| `neovim` | `skill-neovim-research` |
| `general`, `meta`, `markdown`, `latex`, `typst` | `skill-researcher` |

**Issues identified**:

1. **latex and typst are routed to `skill-researcher`** (which delegates to `general-research-agent`), NOT to their dedicated `skill-latex-research` or `skill-typst-research`. The extension skills and agents exist but are never invoked by the /research command.

2. **lean4, python, z3, nix, web, formal, logic, math, physics, epidemiology** are completely absent from the routing table. Tasks with these languages have no explicit route and likely fall through to the general case or produce an error.

3. The command has a "Note" mentioning extensions are available but provides no mechanism to use them.

### Finding 3: /implement Command Routes Even Fewer Languages

**Location**: `.claude/commands/implement.md`, lines 64-68

The routing table is:

| Language | Skill to Invoke |
|----------|-----------------|
| `neovim` | `skill-neovim-implementation` |
| `general`, `meta`, `markdown` | `skill-implementer` |

**Issues identified**:

1. **latex and typst are NOT in this routing table at all** (unlike /research which at least routes them to general). This means `/implement` for latex/typst tasks has no defined behavior.

2. Same 10+ extension languages missing as in /research.

3. A comment says "Additional languages (latex, typst) are available via extensions" but provides no mechanism for loading or using them.

### Finding 4: /plan Command Has No Language Routing

**Location**: `.claude/commands/plan.md`

The /plan command always delegates to `skill-planner` regardless of language. This is a simpler design since planning is more language-agnostic, but the planner-agent may not have access to language-specific context for extension languages.

### Finding 5: Context Index Missing 5 Extension Languages

**Location**: `.claude/context/index.json`

Languages present in index.json: `epidemiology`, `general`, `latex`, `lean4`, `meta`, `neovim`, `r`, `typst`

Languages MISSING from index.json despite having index-entries.json in their extensions: `z3`, `python`, `nix`, `web`, `formal` (also sub-languages `logic`, `math`, `physics`)

Each of these extensions has an `index-entries.json` file with proper entries that reference their language, but these entries have never been merged into the main `index.json`. This means:

- Agents querying `index.json` for language-based context discovery will find nothing for these 5 languages
- The `load_when.agents` references to agents like `z3-research-agent`, `python-implementation-agent`, `nix-research-agent`, `web-research-agent`, `formal-research-agent`, etc. are not discoverable

### Finding 6: No Extension Installation/Activation Script

**Location**: `.claude/scripts/` (searched, no extension-related scripts found)

Each extension's `manifest.json` declares `merge_targets` that specify:
- Where EXTENSION.md content should be merged into CLAUDE.md
- Where index-entries.json should be merged into index.json
- Where settings fragments should be merged

However, there is NO script or command that executes these merges. The system relies on manual integration. Evidence:

- CLAUDE.md contains no extension section markers (no `extension_lean`, `extension_latex`, etc. section IDs)
- Only "Note" comments reference extensions
- index.json is missing entries from 5 extensions

### Finding 7: Inconsistent Extension Format Schemas

The index-entries.json files use two different schemas:

**Schema A** (lean, nix, web, epidemiology): Flat array format
```json
[
  { "path": "...", "load_when": { "languages": [...], "agents": [...] } }
]
```

**Schema B** (z3, python, latex, typst, formal): Object with entries key
```json
{
  "entries": [
    { "path": "...", "load_when": { "languages": [...], "agents": [...] } }
  ]
}
```

Any merge script would need to handle both formats, or the extensions should be standardized.

### Finding 8: Epidemiology Extension References Wrong Path

**Location**: `.claude/extensions/epidemiology/EXTENSION.md`, line 33

Context import references use `.opencode/extensions/` paths instead of `.claude/extensions/`:
```
@.opencode/extensions/epidemiology/context/project/epidemiology/README.md
```

This suggests the extension was created for a different project/system and not fully adapted.

### Finding 9: Extension Skill Location Not on Discovery Path

Extension skills live in `.claude/extensions/{name}/skills/` but the core skills live in `.claude/skills/`. Claude Code discovers skills by scanning `.claude/skills/` (based on the Claude Code configuration). Extension skills would need to be:

1. Symlinked into `.claude/skills/`, or
2. Referenced by the routing tables in commands, or
3. Loaded through some extension activation mechanism

Currently, they rely on routing tables that don't reference them (Finding 2 and 3), and there is no activation mechanism (Finding 6).

### Finding 10: Agent Discovery for Extensions

Extension agents live in `.claude/extensions/{name}/agents/` but core agents are in `.claude/agents/`. When skills use the Task tool to spawn agents, they reference agent names like `latex-research-agent`. The Task tool's agent discovery mechanism needs to find these agents at their extension paths. If discovery only looks in `.claude/agents/`, extension agents would not be found.

### Finding 11: lean4 vs lean Language Naming Inconsistency

The lean extension's manifest declares `"language": "lean4"`, the index.json entries use `"lean4"`, and the skill trigger condition says `"lean"`. The lean research skill says:

```
This skill activates when:
- Task language is "lean"
```

But a task would be created with language "lean4" (matching the manifest). This naming mismatch could cause routing failures.

## Decisions

None made -- this is a research-only phase.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Extension language tasks route to wrong agent | High | Update routing tables in /research and /implement |
| Missing context for 5 extension languages | Medium | Merge index-entries.json into main index.json |
| No extension activation mechanism | Medium | Create install/activate script or merge into commands |
| Inconsistent index-entries.json schemas | Low | Standardize to one format |
| lean4/lean naming mismatch | Medium | Standardize to one name |
| Epidemiology path references .opencode/ | Low | Update to .claude/ paths |

## Recommendations

### Priority 1: Update Command Routing Tables (Critical)

Update `/research` and `/implement` commands to route all extension languages to their dedicated skills:

**research.md routing table should be**:
| Language | Skill |
|----------|-------|
| `neovim` | `skill-neovim-research` |
| `lean4` | `skill-lean-research` |
| `latex` | `skill-latex-research` |
| `typst` | `skill-typst-research` |
| `python` | `skill-python-research` |
| `z3` | `skill-z3-research` |
| `nix` | `skill-nix-research` |
| `web` | `skill-web-research` |
| `formal`, `logic` | `skill-formal-research` / `skill-logic-research` |
| `math` | `skill-math-research` |
| `physics` | `skill-physics-research` |
| `epidemiology`, `r` | `skill-epidemiology-research` |
| `general`, `meta`, `markdown` | `skill-researcher` |

Similar expansion for implement.md.

### Priority 2: Merge Extension Index Entries

Merge z3, python, nix, web, and formal `index-entries.json` files into the main `.claude/context/index.json`. This enables context discovery for these languages.

### Priority 3: Extension Activation Script

Create `.claude/scripts/install-extension.sh` that:
1. Reads manifest.json
2. Merges EXTENSION.md into CLAUDE.md at the specified section_id
3. Merges index-entries.json into index.json
4. Merges settings fragments
5. Creates symlinks or updates discovery paths for skills and agents

### Priority 4: Update /task Language Detection

Add extension language keywords to the /task command's auto-detection:
- "lean", "theorem", "proof", "mathlib" -> lean4
- "latex", "tex", "document", "paper" -> latex
- "typst" -> typst
- "python", "pytest", "pip" -> python
- "z3", "smt", "solver", "constraint" -> z3
- "nix", "nixos", "flake", "home-manager" -> nix
- "web", "astro", "tailwind", "cloudflare" -> web
- "logic", "modal", "kripke" -> logic/formal
- "epidemiology", "sir", "epiestim" -> epidemiology

### Priority 5: Standardize Extension Schemas

Standardize all index-entries.json files to use the same schema format (recommend the `{ "entries": [...] }` format for consistency with the main index.json).

## Appendix

### Search Queries Used
- Glob: `.claude/extensions/**/*` - Full extension file inventory
- Glob: `.claude/skills/**/*`, `.claude/agents/**/*` - Core skill/agent inventory
- Read: All 10 manifest.json files
- Read: research.md, plan.md, implement.md commands
- Read: skill-researcher, skill-neovim-research, skill-implementer, skill-planner SKILL.md files
- Read: Extension SKILL.md files (latex, typst, lean)
- Read: Extension EXTENSION.md files (lean, nix, web, formal, epidemiology, filetypes)
- jq: index.json language and agent queries
- Grep: CLAUDE.md for extension section markers

### Key File Paths

- Commands: `.claude/commands/{research,plan,implement}.md`
- Core skills: `.claude/skills/skill-{researcher,neovim-research,implementer,planner}/SKILL.md`
- Extension skills: `.claude/extensions/{name}/skills/skill-{name}-{research,implementation}/SKILL.md`
- Extension agents: `.claude/extensions/{name}/agents/{name}-{research,implementation}-agent.md`
- Extension manifests: `.claude/extensions/{name}/manifest.json`
- Extension index entries: `.claude/extensions/{name}/index-entries.json`
- Main context index: `.claude/context/index.json`
- Extension CLAUDE.md fragments: `.claude/extensions/{name}/EXTENSION.md`
