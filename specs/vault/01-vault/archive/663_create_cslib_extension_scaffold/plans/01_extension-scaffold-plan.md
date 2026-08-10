# Implementation Plan: Task #663

- **Task**: 663 - Create cslib extension scaffold
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None (foundational task; 664, 665, 666 depend on this)
- **Research Inputs**: specs/663_create_cslib_extension_scaffold/reports/01_extension-scaffold-research.md
- **Artifacts**: plans/01_extension-scaffold-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Create the complete cslib extension scaffold at `.claude/extensions/cslib/` modeled after the lean extension. The scaffold establishes directory structure, manifest configuration, documentation files, context discovery entries, and minimal stub files for agents/skills/rules so the extension is loadable immediately. Downstream tasks (664, 665, 666) populate the stubs with full content.

### Research Integration

Research report provides ready-to-copy content for all scaffold files. Key findings integrated:
- No `settings-fragment.json` needed (lean-lsp permissions inherited via dependency chain)
- No `mcp_servers` block needed (lean-lsp inherited from lean dependency)
- `merge_targets.claudemd.section_id` must be `"extension_cslib"` (unique per extension)
- Stub files include minimal frontmatter to satisfy extension loader validation
- `index-entries.json` uses `"languages"` (not `"task_types"`) in `load_when` entries

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create complete directory structure for cslib extension
- Write manifest.json with correct routing, dependencies, and merge targets
- Write EXTENSION.md content for CLAUDE.md merge
- Write README.md documenting the extension
- Write index-entries.json for context discovery
- Create valid stub files for agents, skills, and rules
- Extension must be loadable by the extension picker without errors

**Non-Goals**:
- Full agent definitions (task 664)
- Full skill definitions (task 665)
- Full context files and rule content (task 666)
- Integration testing with the lean extension loader
- Writing actual CSLib domain knowledge content

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension loaded before downstream tasks complete | L | M | Stub files satisfy provides arrays; empty stubs produce no errors |
| index-entries.json references missing context files | L | H | Context discovery loads lazily; missing files produce warnings, not errors |
| Dependency chain (core -> lean) not loading correctly | M | L | Explicit ["core", "lean"] is defensive; lean already depends on core |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 1 |
| 4 | 7 | 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create directory structure [COMPLETED]

**Goal**: Establish all directories needed by the cslib extension.

**Tasks**:
- [ ] Create `.claude/extensions/cslib/`
- [ ] Create `.claude/extensions/cslib/agents/`
- [ ] Create `.claude/extensions/cslib/skills/skill-cslib-research/`
- [ ] Create `.claude/extensions/cslib/skills/skill-cslib-implementation/`
- [ ] Create `.claude/extensions/cslib/commands/`
- [ ] Create `.claude/extensions/cslib/rules/`
- [ ] Create `.claude/extensions/cslib/context/project/cslib/domain/`
- [ ] Create `.claude/extensions/cslib/context/project/cslib/patterns/`
- [ ] Create `.claude/extensions/cslib/context/project/cslib/standards/`
- [ ] Create `.claude/extensions/cslib/context/project/cslib/tools/`

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- Directories only (no files yet)

**Verification**:
- `find .claude/extensions/cslib -type d` shows all 10+ directories

---

### Phase 2: Create manifest.json [COMPLETED]

**Goal**: Write the extension manifest with task_type routing, dependencies, and merge targets.

**Tasks**:
- [ ] Write `.claude/extensions/cslib/manifest.json` with complete configuration

**Content**:
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

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - create with full content above

**Verification**:
- `jq . .claude/extensions/cslib/manifest.json` parses without errors
- `jq '.task_type' .claude/extensions/cslib/manifest.json` returns `"cslib"`
- `jq '.dependencies' .claude/extensions/cslib/manifest.json` returns `["core", "lean"]`

---

### Phase 3: Create EXTENSION.md [COMPLETED]

**Goal**: Write the CLAUDE.md merge content for the cslib extension section.

**Tasks**:
- [ ] Write `.claude/extensions/cslib/EXTENSION.md` with routing tables and MCP notes

**Content**:
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

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/EXTENSION.md` - create with full content above

**Verification**:
- File starts with `## CSLib Extension` (no H1, no frontmatter)
- Contains Language Routing and Skill-Agent Mapping tables

---

### Phase 4: Create README.md [COMPLETED]

**Goal**: Write extension documentation following lean extension README structure.

**Tasks**:
- [ ] Write `.claude/extensions/cslib/README.md` with full documentation

**Content**:
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

    cslib/
    +-- manifest.json              # Extension configuration
    +-- EXTENSION.md               # CLAUDE.md merge content
    +-- index-entries.json         # Context discovery entries
    +-- README.md                  # This file
    |
    +-- agents/
    |   +-- cslib-research-agent.md       # CSLib formalization research
    |   +-- cslib-implementation-agent.md  # CSLib proof implementation
    |
    +-- skills/
    |   +-- skill-cslib-research/   # Research skill wrapper
    |   +-- skill-cslib-implementation/ # Implementation skill wrapper
    |
    +-- commands/                  # (none -- uses standard /research, /plan, /implement)
    |
    +-- rules/
    |   +-- cslib.md               # CSLib coding conventions (auto-applied to *.lean)
    |
    +-- context/
        +-- project/
            +-- cslib/
                +-- domain/        # CSLib architecture, CONTRIBUTING standards, notation
                +-- patterns/      # Proof structure, module organization, reuse-first
                +-- standards/     # CI pipeline, PR conventions, mathlib style
                +-- tools/         # lake commands, linters, checkInitImports, mk_all

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

    lake test                                             # Run CslibTests suite
    lake exe checkInitImports                             # Verify Cslib.Init imports
    lake exe lint-style                                   # Style linting
    lake shake --add-public --keep-implied --keep-prefix  # Dependency analysis

## References

- [CSLib Repository](https://github.com/leanprover-community/cslib) (or local: `/home/benjamin/Projects/cslib/`)
- [CSLib CONTRIBUTING.md](../../../../../../../Projects/cslib/CONTRIBUTING.md)
- [Lean 4 Documentation](https://leanprover.github.io/lean4/doc/)
- [Mathlib](https://leanprover-community.github.io/mathlib4_docs/)
```

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/README.md` - create with full content above

**Verification**:
- File starts with `# CSLib Extension` (H1 heading)
- Contains Overview, Installation, Architecture, Skill-Agent Mapping sections

---

### Phase 5: Create index-entries.json [COMPLETED]

**Goal**: Write context discovery entries for all planned context files.

**Tasks**:
- [ ] Write `.claude/extensions/cslib/index-entries.json` with 10 context entries

**Content**:
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

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/index-entries.json` - create with full content above

**Verification**:
- `jq '.entries | length' .claude/extensions/cslib/index-entries.json` returns `10`
- `jq '.entries[0].load_when.languages[0]' .claude/extensions/cslib/index-entries.json` returns `"cslib"`

---

### Phase 6: Create stub files [COMPLETED]

**Goal**: Create minimal agent, skill, and rule stubs so the extension is loadable before tasks 664-666 complete.

**Tasks**:
- [ ] Write `.claude/extensions/cslib/agents/cslib-research-agent.md` (stub with frontmatter)
- [ ] Write `.claude/extensions/cslib/agents/cslib-implementation-agent.md` (stub with frontmatter)
- [ ] Write `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` (stub)
- [ ] Write `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` (stub)
- [ ] Write `.claude/extensions/cslib/rules/cslib.md` (stub with paths frontmatter)

**Agent stub content** (`agents/cslib-research-agent.md`):
```markdown
---
name: cslib-research-agent
description: Research CSLib formalization patterns and Mathlib API for CSLib contributions
model: opus
---

# CSLib Research Agent

Stub -- full content created by task #664.
```

**Agent stub content** (`agents/cslib-implementation-agent.md`):
```markdown
---
name: cslib-implementation-agent
description: Implement CSLib proofs following Lean 4 and CSLib contribution standards
model: sonnet
---

# CSLib Implementation Agent

Stub -- full content created by task #664.
```

**Skill stub content** (`skills/skill-cslib-research/SKILL.md`):
```markdown
# skill-cslib-research

Stub -- full content created by task #665.
```

**Skill stub content** (`skills/skill-cslib-implementation/SKILL.md`):
```markdown
# skill-cslib-implementation

Stub -- full content created by task #665.
```

**Rule stub content** (`rules/cslib.md`):
```markdown
---
paths: "**/*.lean"
---

# CSLib Development Rules

Stub -- full content created by task #666.
```

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-research-agent.md` - create
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - create
- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` - create
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - create
- `.claude/extensions/cslib/rules/cslib.md` - create

**Verification**:
- All 5 stub files exist and are non-empty
- Agent stubs contain valid YAML frontmatter (name, description, model fields)
- Rule stub has `paths:` frontmatter

---

### Phase 7: Verification [COMPLETED]

**Goal**: Validate all JSON files parse correctly and the extension structure matches the manifest.

**Tasks**:
- [ ] Validate `manifest.json` parses as valid JSON
- [ ] Validate `index-entries.json` parses as valid JSON
- [ ] Verify all files listed in `provides.agents` exist in `agents/`
- [ ] Verify all directories listed in `provides.skills` exist in `skills/`
- [ ] Verify all files listed in `provides.rules` exist in `rules/`
- [ ] Verify `provides.context` directories exist in `context/`
- [ ] Verify `EXTENSION.md` exists (merge_targets.claudemd.source)
- [ ] Run `find .claude/extensions/cslib -type f` to confirm complete file list

**Timing**: 5 minutes

**Depends on**: 2, 3, 4, 5, 6

**Files to modify**:
- None (read-only verification)

**Verification**:
- All JSON files parse without errors
- All `provides` references resolve to existing files/directories
- Extension structure matches the directory tree documented in README.md

---

## Testing & Validation

- [ ] `jq . .claude/extensions/cslib/manifest.json` exits 0
- [ ] `jq . .claude/extensions/cslib/index-entries.json` exits 0
- [ ] `jq '.provides.agents[]' .claude/extensions/cslib/manifest.json` lists 2 agents
- [ ] `jq '.provides.skills[]' .claude/extensions/cslib/manifest.json` lists 2 skills
- [ ] All files referenced by `provides` arrays exist on disk
- [ ] `EXTENSION.md` starts with `## CSLib Extension` (valid merge fragment)
- [ ] No orphan directories (every leaf dir has at least one file or is expected empty)

## Artifacts & Outputs

- `.claude/extensions/cslib/manifest.json` - Extension configuration
- `.claude/extensions/cslib/EXTENSION.md` - CLAUDE.md merge content
- `.claude/extensions/cslib/README.md` - Extension documentation
- `.claude/extensions/cslib/index-entries.json` - Context discovery entries
- `.claude/extensions/cslib/agents/cslib-research-agent.md` - Agent stub
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Agent stub
- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` - Skill stub
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Skill stub
- `.claude/extensions/cslib/rules/cslib.md` - Rule stub

## Rollback/Contingency

Remove the entire extension directory:
```bash
rm -rf .claude/extensions/cslib/
```

No other files are modified by this task -- the extension is self-contained until explicitly loaded via the extension picker.
