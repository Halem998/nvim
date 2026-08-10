# Research Report: Task #663

**Task**: 663 - Create cslib extension scaffold
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:10:00Z
**Effort**: ~45 minutes implementation
**Dependencies**: None (foundational task; 664, 665, 666 depend on this)
**Sources/Inputs**:
- `.claude/extensions/lean/manifest.json` - lean manifest schema reference
- `.claude/extensions/lean/EXTENSION.md` - EXTENSION.md format reference
- `.claude/extensions/lean/README.md` - README format reference
- `.claude/extensions/lean/index-entries.json` - context discovery schema reference
- `.claude/extensions/lean/agents/lean-research-agent.md` - agent format reference
- `.claude/extensions/lean/settings-fragment.json` - settings fragment reference
- `.claude/extensions/core/docs/guides/creating-extensions.md` - extension guide
- `specs/state.json` - task descriptions for 663-666 with precise requirements
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md` - CSLib project context
**Artifacts**:
- `specs/663_create_cslib_extension_scaffold/reports/01_extension-scaffold-research.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- CSLib is a Lean 4 computer science library project at `/home/benjamin/Projects/cslib/`; its extension is a specialized overlay on the lean extension
- The scaffold requires NO `mcp_servers` block (lean-lsp inherited via `dependencies: ["core", "lean"]`) and NO `settings-fragment.json`
- Key distinction from lean extension: `task_type: "cslib"`, two custom skills (skill-cslib-research, skill-cslib-implementation), two custom agents, one rule file, and a `project/cslib/` context tree
- The `merge_targets.claudemd.section_id` must be `"extension_cslib"` (unique per extension)
- `index-entries.json` paths use `"project/cslib/..."` (relative to extensions/cslib/context/ after merge)

---

## Context & Scope

This task creates the directory structure and all scaffold files for a new `cslib` extension. The extension builds on top of the lean extension by declaring `["core", "lean"]` as dependencies, which auto-loads lean (including lean-lsp MCP) when cslib is loaded. The scaffold itself is just the container — agents (#664), skills (#665), and context/rules (#666) are populated by downstream tasks.

CSLib is a Lean 4 formalization library for computer science (algorithms, data structures, programming languages, semantics). It uses `lake` as its build tool and has a CI pipeline with specialized tools (`checkInitImports`, `lint-style`, `lake shake`).

---

## Findings

### Extension Schema (from lean reference)

The complete manifest.json fields used by the system:
- `name` - matches directory name exactly
- `version` - semantic version string
- `description` - displayed in extension picker UI
- `task_type` - string used for orchestrator routing (bare value like `"cslib"`)
- `dependencies` - array of extension names to auto-load first
- `provides` - object with arrays: `agents`, `skills`, `commands`, `rules`, `context`, `scripts`, `hooks`
- `routing` - nested object: `{research: {task_type: skill}, plan: {task_type: skill}, implement: {task_type: skill}}`
- `merge_targets` - object with `claudemd`, `settings` (optional), `index`, `opencode_json` (optional)
- `mcp_servers` - can be omitted or set to `{}` when no servers needed
- `hooks` - top-level `{}` for no lifecycle hooks

**Key finding**: The lean extension has `settings-fragment.json` because it registers lean-lsp MCP permissions. Since cslib inherits lean-lsp via dependency, it does NOT need a `settings-fragment.json`. The `merge_targets.settings` entry should be omitted.

**Key finding**: The lean extension has `opencode-agents.json` for OpenCode integration. The cslib extension can include this as a placeholder or omit from merge_targets. Given the cslib project uses the same claude system, include it as empty `{}` or omit entirely.

### EXTENSION.md Format

The EXTENSION.md is a markdown fragment (no frontmatter, no H1) that gets embedded in `.claude/CLAUDE.md` as a section. It starts with `## {Extension Name} Extension` and includes:
- Language Routing table
- Skill-Agent Mapping table
- Any MCP integration notes (for cslib: inherited from lean, mention briefly)
- Quick Reference or Commands section if applicable

### index-entries.json Schema

Each entry has these fields:
- `path` - relative path within the extension's context directory (e.g., `"project/cslib/domain/contributing-standards.md"`)
- `description` - human-readable description
- `tags` - array of lowercase strings
- `load_when` - object with `languages` (array) and `agents` (array)
- `domain` - always `"project"` for domain knowledge
- `subdomain` - short identifier like `"cslib"`
- `summary` - same as description (redundant but present in lean schema)

**Note on `load_when`**: The lean entries use `"languages"` not `"task_types"` at the entry level. This appears to be a field name used in the context index — both `languages` and `task_types` may be checked. Using `"languages": ["cslib"]` matches the lean convention exactly.

### Dependency Inheritance Behavior

From the creating-extensions guide: "Dependencies are auto-loaded silently when the parent extension is loaded, with circular detection and a depth limit of 5." Loading cslib will first load core (already loaded) then lean (including its lean-lsp MCP server config). This means:
- lean-lsp MCP tools are available to cslib agents without declaring them in cslib/manifest.json
- The lean extension's settings-fragment.json permissions are merged
- No duplicate MCP server declaration needed in cslib

### Directory Structure

The scaffold needs these directories and placeholder files:

```
.claude/extensions/cslib/
├── manifest.json              # Extension configuration (COMPLETE at scaffold time)
├── EXTENSION.md               # CLAUDE.md merge content (COMPLETE at scaffold time)
├── README.md                  # Extension documentation (COMPLETE at scaffold time)
├── index-entries.json         # Context discovery entries (COMPLETE at scaffold time)
│
├── agents/                    # Populated by task #664
│   ├── cslib-research-agent.md      # (placeholder stub)
│   └── cslib-implementation-agent.md # (placeholder stub)
│
├── skills/                    # Populated by task #665
│   ├── skill-cslib-research/        # (directory, SKILL.md stub)
│   └── skill-cslib-implementation/  # (directory, SKILL.md stub)
│
├── commands/                  # Empty (cslib uses standard /research, /plan, /implement)
│
├── rules/                     # Populated by task #666
│   └── cslib.md               # (placeholder stub)
│
└── context/
    └── project/
        └── cslib/
            ├── domain/        # Populated by task #666
            ├── patterns/      # Populated by task #666
            ├── standards/     # Populated by task #666
            └── tools/         # Populated by task #666
```

**Decision**: At scaffold time, create agent stubs and skill stubs with minimal content to satisfy the `provides` arrays in manifest.json. This prevents errors if the extension is loaded before tasks 664-666 complete.

---

## Ready-to-Use Artifacts

### manifest.json (Complete)

```json
{
  "name": "cslib",
  "version": "1.0.0",
  "description": "CSLib Lean 4 computer science library formalization support",
  "task_type": "cslib",
  "dependencies": [
    "core",
    "lean"
  ],
  "provides": {
    "agents": [
      "cslib-research-agent.md",
      "cslib-implementation-agent.md"
    ],
    "skills": [
      "skill-cslib-research",
      "skill-cslib-implementation"
    ],
    "commands": [],
    "rules": [
      "cslib.md"
    ],
    "context": [
      "project/cslib"
    ],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": {
      "cslib": "skill-cslib-research"
    },
    "plan": {
      "cslib": "skill-planner"
    },
    "implement": {
      "cslib": "skill-cslib-implementation"
    }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_cslib"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {},
  "hooks": {}
}
```

### EXTENSION.md (Complete)

```markdown
## CSLib Extension

This project includes CSLib Lean 4 computer science library support via the cslib extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `cslib` | WebSearch, WebFetch, Read, lean-lsp MCP (inherited) | Read, Write, Edit, Bash (lake build, lake test, lake lint, lake exe checkInitImports, lake exe lint-style, lake shake) |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-cslib-research | cslib-research-agent | opus | CSLib formalization research with lean-lsp MCP |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | CSLib proof implementation with CI verification |

### MCP Integration

The `lean-lsp` MCP server is inherited from the lean extension dependency and provides:
- Goal state inspection (`lean_goal`)
- Proof search (`lean_state_search`, `lean_hammer_premise`)
- Mathlib/CSLib lookup (`lean_loogle`, `lean_leansearch`, `lean_leanfinder`)

### CI Verification Pipeline

CSLib implementations must pass:
- `lake test` - Run CslibTests suite
- `lake exe checkInitImports` - Verify Cslib.Init imports
- `lake exe lint-style` - Style linting
- `lake shake --add-public --keep-implied --keep-prefix` - Dependency analysis
```

### README.md (Complete)

The README follows the lean extension's structure since cslib is a complex extension (inherits MCP, has agents, uses CI pipeline). Full content:

```markdown
# CSLib Extension

CSLib Lean 4 computer science library formalization support. Provides research and implementation agents for CSLib contributions, inheriting `lean-lsp` MCP tools from the lean extension for live goal inspection, proof search, and Mathlib/CSLib lookup.

## Overview

| Task Type | Research | Plan | Implementation |
|-----------|----------|------|----------------|
| `cslib` | skill-cslib-research | skill-planner | skill-cslib-implementation |

The extension routes `cslib` task types through dedicated agents that enforce CSLib coding conventions, use the CI verification pipeline, and follow the project's reuse-first and proof-readability principles from CONTRIBUTING.md.

## Installation

Loaded via the extension picker. Once loaded, `cslib` becomes a recognized task type. The lean extension is auto-loaded as a dependency, providing `lean-lsp` MCP access.

## Architecture

```
cslib/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── agents/
│   ├── cslib-research-agent.md       # CSLib formalization research
│   └── cslib-implementation-agent.md # CSLib proof implementation
│
├── skills/
│   ├── skill-cslib-research/   # Research skill wrapper
│   └── skill-cslib-implementation/ # Implementation skill wrapper
│
├── commands/                  # (none — uses standard /research, /plan, /implement)
│
├── rules/
│   └── cslib.md               # CSLib coding conventions (auto-applied to *.lean)
│
└── context/
    └── project/
        └── cslib/
            ├── domain/        # CSLib architecture, CONTRIBUTING standards, notation
            ├── patterns/      # Proof structure, module organization, reuse-first
            ├── standards/     # CI pipeline, PR conventions, mathlib style
            └── tools/         # lake commands, linters, checkInitImports, mk_all
```

## Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-cslib-research | cslib-research-agent | opus | CSLib/Mathlib research with lean-lsp MCP |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | CSLib proof implementation with CI verification |

## Language Routing

| Task Type | Research Skill | Implementation Skill | Tools |
|-----------|----------------|---------------------|-------|
| `cslib` | skill-cslib-research | skill-cslib-implementation | WebSearch, WebFetch, Read, Write, Edit, Bash(lake), lean-lsp MCP |

## CI Verification Pipeline

CSLib implementation agent runs the full CI suite after edits:

```bash
lake test                                             # Run CslibTests suite
lake exe checkInitImports                             # Verify Cslib.Init imports
lake exe lint-style                                   # Style linting
lake shake --add-public --keep-implied --keep-prefix  # Dependency analysis
```

## References

- [CSLib Repository](https://github.com/leanprover-community/cslib) (or local: `/home/benjamin/Projects/cslib/`)
- [CSLib CONTRIBUTING.md](../../../../../../../Projects/cslib/CONTRIBUTING.md)
- [Lean 4 Documentation](https://leanprover.github.io/lean4/doc/)
- [Mathlib](https://leanprover-community.github.io/mathlib4_docs/)
```

### index-entries.json (Scaffold with Placeholders)

This contains entries for files that task #666 will create. The scaffold provides the discovery metadata structure so agents can reference it:

```json
{
  "entries": [
    {
      "path": "project/cslib/domain/contributing-standards.md",
      "description": "CSLib CONTRIBUTING.md key standards: variable names, proof style, notation, CI",
      "tags": ["cslib", "contributing", "standards"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-research-agent", "cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib CONTRIBUTING.md key standards: variable names, proof style, notation, CI"
    },
    {
      "path": "project/cslib/domain/notation-conventions.md",
      "description": "CSLib-specific notation: alpha equivalence, LTS transitions, reduction arrows",
      "tags": ["cslib", "notation", "conventions"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-research-agent", "cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib-specific notation: alpha equivalence, LTS transitions, reduction arrows"
    },
    {
      "path": "project/cslib/domain/project-organization.md",
      "description": "CSLib project structure: pillars, working groups, module layout",
      "tags": ["cslib", "project", "organization"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-research-agent", "cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib project structure: pillars, working groups, module layout"
    },
    {
      "path": "project/cslib/patterns/proof-structure.md",
      "description": "CSLib proof structure patterns and module organization",
      "tags": ["cslib", "proofs", "patterns"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib proof structure patterns and module organization"
    },
    {
      "path": "project/cslib/patterns/reuse-first.md",
      "description": "CSLib reuse-first philosophy: prefer existing Mathlib/CSLib abstractions",
      "tags": ["cslib", "reuse", "mathlib"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-research-agent", "cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib reuse-first philosophy: prefer existing Mathlib/CSLib abstractions"
    },
    {
      "path": "project/cslib/standards/ci-pipeline.md",
      "description": "CSLib CI pipeline: lake test, checkInitImports, lint-style, lake shake commands",
      "tags": ["cslib", "ci", "pipeline", "lake"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib CI pipeline: lake test, checkInitImports, lint-style, lake shake commands"
    },
    {
      "path": "project/cslib/standards/pr-conventions.md",
      "description": "CSLib PR title conventions, conventional commits, review process",
      "tags": ["cslib", "pr", "git", "commits"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib PR title conventions, conventional commits, review process"
    },
    {
      "path": "project/cslib/standards/mathlib-style.md",
      "description": "Mathlib-style Lean coding standards applied to CSLib",
      "tags": ["cslib", "mathlib", "style"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "Mathlib-style Lean coding standards applied to CSLib"
    },
    {
      "path": "project/cslib/tools/lake-commands.md",
      "description": "Lake commands for CSLib: build, test, exe targets, shake",
      "tags": ["cslib", "lake", "tools", "build"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-research-agent", "cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "Lake commands for CSLib: build, test, exe targets, shake"
    },
    {
      "path": "project/cslib/tools/linters.md",
      "description": "CSLib linting tools: checkInitImports, lint-style, lake shake",
      "tags": ["cslib", "linters", "checkInitImports", "lint-style"],
      "load_when": {
        "languages": ["cslib"],
        "agents": ["cslib-implementation-agent"]
      },
      "domain": "project",
      "subdomain": "cslib",
      "summary": "CSLib linting tools: checkInitImports, lint-style, lake shake"
    }
  ]
}
```

---

## Stub Files for Scaffold

The scaffold should include minimal stub files to make the extension loadable before tasks 664-666 complete.

### agents/cslib-research-agent.md (Stub)

```markdown
---
name: cslib-research-agent
description: Research CSLib formalization patterns and Mathlib API for CSLib contributions
model: opus
---

# CSLib Research Agent

Stub — full content created by task #664.
```

### agents/cslib-implementation-agent.md (Stub)

```markdown
---
name: cslib-implementation-agent
description: Implement CSLib proofs following Lean 4 and CSLib contribution standards
model: sonnet
---

# CSLib Implementation Agent

Stub — full content created by task #664.
```

### skills/skill-cslib-research/SKILL.md (Stub)

```markdown
# skill-cslib-research

Stub — full content created by task #665.
```

### skills/skill-cslib-implementation/SKILL.md (Stub)

```markdown
# skill-cslib-implementation

Stub — full content created by task #665.
```

### rules/cslib.md (Stub)

```markdown
---
paths: "**/*.lean"
---

# CSLib Development Rules

Stub — full content created by task #666.
```

---

## Decisions

1. **No settings-fragment.json**: The lean extension's settings-fragment.json already registers lean-lsp MCP permissions. Since cslib depends on lean, those permissions are already active. Adding a duplicate cslib settings-fragment.json would either be a no-op or cause conflicts.

2. **No commands directory files**: CSLib uses the standard `/research`, `/plan`, `/implement` workflow. Unlike lean which has custom `/lake` and `/lean` commands, cslib needs no custom commands at scaffold time.

3. **No opencode-agents.json**: The lean extension has this for OpenCode integration, but cslib is a child project that likely uses the same OpenCode config. Omitting it keeps the scaffold minimal. Can be added later if needed.

4. **skill-planner for plan routing**: The manifest routing `plan.cslib: "skill-planner"` uses the shared planner (opus model) rather than a cslib-specific plan skill. This matches the lean extension pattern and is appropriate since planning is domain-agnostic.

5. **Both `core` and `lean` in dependencies**: Including `"core"` explicitly is belt-and-suspenders — lean already depends on core, so cslib would get core transitively. Explicit declaration makes the intent clear.

6. **Stub files are minimal but valid**: Agent stubs include required frontmatter (name, description, model) so the extension loader can process them. Skill stubs include just a heading. This keeps them loadable while clearly indicating they are placeholders.

7. **index-entries.json uses `"languages"` not `"task_types"`**: The lean extension uses `"languages"` in load_when entries. Following this convention ensures consistent behavior with the existing loader.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Extension loaded before tasks 664-666 complete | Stub files satisfy `provides` arrays; agents will see empty stubs but not crash |
| `dependencies: ["lean"]` already includes core transitively | Explicit `"core"` in dependencies array is harmless and defensive |
| `index-entries.json` references files not yet created | The context discovery system loads entries lazily; missing files produce warnings, not errors |
| Routing `plan.cslib: "skill-planner"` vs custom skill | If a custom plan skill is needed later, the routing entry can be updated by task #665 |

---

## Context Extension Recommendations

- none (this is a meta task creating extension infrastructure, not discovering new project patterns)

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/EXTENSION.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/README.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/index-entries.json`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/rules/lean4.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/settings-fragment.json`
- `/home/benjamin/.config/nvim/.claude/extensions/core/docs/guides/creating-extensions.md`
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md`
- `/home/benjamin/.config/nvim/specs/state.json` (tasks 663-666 descriptions)

### Key References

- Extension system guide: `.claude/extensions/core/docs/guides/creating-extensions.md`
- Lean extension as canonical complex-extension reference: `.claude/extensions/lean/`
- CSLib project: `/home/benjamin/Projects/cslib/`
