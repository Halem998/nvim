# Research Report: Task #99

**Task**: 99 - review_agent_systems_core_extensions
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T01:00:00Z
**Effort**: 2-4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of nvim/.claude/, ProofChecker/.claude/, Theory/.claude/
**Artifacts**: specs/099_review_agent_systems_core_extensions/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- ProofChecker and Theory have evolved 17 core context files, 3 team skills, 2 domain commands, and several utility scripts beyond what nvim has
- General-purpose additions fall into three categories: team orchestration (multi-agent), improved reference/recovery docs, and MCP tool resilience patterns
- Domain-specific additions (Lean, Logic, Math, Physics) represent extension modules that should be independently loadable
- Recommended architecture: core system (managed via `<leader>ac`) + extension registry (domain packs loaded on demand)

## Context & Scope

Compared three `.claude/` agent systems to identify what ProofChecker and Theory have evolved beyond the nvim baseline. Focus was on general-purpose infrastructure vs domain-specific content.

### Systems Compared

| System | Location | Purpose |
|--------|----------|---------|
| nvim (baseline) | `~/.config/nvim/.claude/` | Neovim configuration management |
| ProofChecker | `~/Projects/ProofChecker/.claude/` | Lean 4 formal verification |
| Theory | `~/Projects/Logos/Theory/.claude/` | Mathematical logic + Lean 4 |

## Findings

### 1. Component Inventory

#### Commands

| Command | nvim | ProofChecker | Theory | Category |
|---------|------|-------------|--------|----------|
| `/task` | Y | Y | Y | Core |
| `/research` | Y | Y | Y | Core |
| `/plan` | Y | Y | Y | Core |
| `/implement` | Y | Y | Y | Core |
| `/revise` | Y | Y | Y | Core |
| `/review` | Y | Y | Y | Core |
| `/todo` | Y | Y | Y | Core |
| `/errors` | Y | Y | Y | Core |
| `/meta` | Y | Y | Y | Core |
| `/learn` | Y | Y | Y | Core |
| `/refresh` | Y | Y | Y | Core |
| `/convert` | Y | Y | Y | Core |
| `/lake` | - | Y | Y | **Extension (Lean)** |
| `/lean` | - | Y | Y | **Extension (Lean)** |
| `/merge` | - | - | Y | **Extension (GitLab)** |

**Missing from nvim (general-purpose)**: None. All core commands are present.

**Missing from nvim (domain-specific)**: `/lake` (Lean build with auto-repair), `/lean` (toolchain version management), `/merge` (GitLab MR creation).

#### Skills

| Category | nvim | ProofChecker | Theory |
|----------|------|-------------|--------|
| Core orchestration | 6 | 6 | 6 |
| Core implementation | 5 | 5 | 5 |
| Domain-specific research | 1 (neovim) | 4 (lean, logic, math, latex) | 5 (+ typst) |
| Domain-specific implementation | 3 (neovim, latex, typst) | 3 (lean, latex, typst) | 3 (lean, latex, typst) |
| Domain-specific utilities | 0 | 2 (lake-repair, lean-version) | 2 (lake-repair, lean-version) |
| **Team orchestration** | **0** | **3** (team-implement, team-plan, team-research) | **0** |

**Key finding**: ProofChecker has 3 team orchestration skills (`skill-team-implement`, `skill-team-plan`, `skill-team-research`) that enable multi-agent parallel execution. These are general-purpose infrastructure, not Lean-specific.

#### Agents

| Category | nvim | ProofChecker | Theory |
|----------|------|-------------|--------|
| Core | 5 | 5 | 5 |
| Domain research | 1 (neovim) | 4 (lean, logic, math, latex) | 5 (+ typst) |
| Domain implementation | 3 (neovim, latex, typst) | 2 (lean, latex) | 2 (lean, latex) |

#### Rules

| Rule | nvim | ProofChecker | Theory | Category |
|------|------|-------------|--------|----------|
| artifact-formats.md | Y | Y | Y | Core |
| error-handling.md | Y | Y | Y | Core |
| git-workflow.md | Y | Y | Y | Core |
| state-management.md | Y | Y | Y | Core |
| workflows.md | Y | Y | Y | Core |
| neovim-lua.md | Y | - | - | Extension (Neovim) |
| latex.md | Y | Y | Y | Extension (LaTeX) |
| lean4.md | - | Y | Y | Extension (Lean) |

#### Scripts

| Script | nvim | ProofChecker | Theory | Category |
|--------|------|-------------|--------|----------|
| claude-cleanup.sh | Y | Y | Y | Core |
| claude-project-cleanup.sh | Y | Y | Y | Core |
| claude-refresh.sh | Y | Y | Y | Core |
| export-to-markdown.sh | Y | Y | Y | Core |
| install-aliases.sh | Y | Y | Y | Core |
| install-systemd-timer.sh | Y | Y | Y | Core |
| postflight-implement.sh | Y | Y | Y | Core |
| postflight-plan.sh | Y | Y | Y | Core |
| postflight-research.sh | Y | Y | Y | Core |
| validate-context-index.sh | Y | Y | - | Core |
| migrate-directory-padding.sh | Y | - | - | nvim-specific |
| generate-context-index.sh | - | Y | - | **General-purpose** |
| update-plan-status.sh | - | Y | - | **General-purpose** |
| setup-lean-mcp.sh | - | Y | Y | Extension (Lean) |
| verify-lean-mcp.sh | - | Y | Y | Extension (Lean) |

### 2. Core Context Files Missing from nvim

These are general-purpose context files present in ProofChecker and/or Theory but absent from nvim:

#### High Priority (General-Purpose Infrastructure)

| File | Location | Description |
|------|----------|-------------|
| `formats/metadata-quick-ref.md` | ProofChecker | Condensed metadata schema reference (131 lines vs 250+ in full schema) |
| `formats/debug-report-format.md` | ProofChecker | Debug report schema for hypothesis-analysis-resolution cycles |
| `formats/handoff-artifact.md` | ProofChecker | Context exhaustion recovery via structured handoff documents |
| `formats/progress-file.md` | ProofChecker | Incremental progress tracking within implementation phases |
| `formats/changelog-format.md` | ProofChecker | CHANGE_LOG.md structure for permanent work history |
| `formats/team-metadata-extension.md` | ProofChecker | Team result schema for multi-agent coordination |
| `patterns/team-orchestration.md` | ProofChecker | Wave-based multi-agent coordination patterns |
| `standards/git-staging-scope.md` | ProofChecker | Per-agent git staging scopes to prevent race conditions |
| `reference/command-reference.md` | ProofChecker | Full command reference with all flags and modes |
| `reference/state-json-schema.md` | ProofChecker | Complete state.json schema documentation |
| `reference/error-recovery-procedures.md` | ProofChecker | Detailed recovery procedures for all error types |
| `reference/skill-agent-mapping.md` | ProofChecker | Skill-to-agent mapping quick reference |
| `reference/artifact-templates.md` | ProofChecker | Template collection for all artifact types |
| `utils/index-query.md` | ProofChecker, Theory | Programmatic index.json query patterns with jq |
| `templates/context-knowledge-template.md` | Theory | Knowledge extraction template for research agents |

#### Medium Priority (MCP/Tool Resilience)

| File | Location | Description |
|------|----------|-------------|
| `patterns/blocked-mcp-tools.md` | ProofChecker, Theory | Reference for blocked MCP tools with alternatives |
| `patterns/mcp-tool-recovery.md` | ProofChecker, Theory | Defensive patterns for MCP tool failure recovery |

#### Lower Priority (Domain Patterns Generalized)

| File | Location | Description |
|------|----------|-------------|
| `patterns/roadmap-reflection-pattern.md` | ProofChecker | Prevents recommending documented dead ends |

### 3. Categorization of All Differences

#### Category A: Core Infrastructure (Should Be in Base System)

These are general-purpose features that benefit ANY project:

1. **Team Orchestration Skills** (ProofChecker)
   - `skill-team-research` - Parallel multi-agent research
   - `skill-team-plan` - Parallel multi-agent planning
   - `skill-team-implement` - Parallel multi-agent implementation with debug cycles
   - Pattern: `formats/team-metadata-extension.md`, `patterns/team-orchestration.md`

2. **Reference Documentation** (ProofChecker)
   - `reference/command-reference.md` - Full command reference
   - `reference/state-json-schema.md` - Complete state.json schema
   - `reference/error-recovery-procedures.md` - Recovery procedures
   - `reference/skill-agent-mapping.md` - Skill-to-agent mapping
   - `reference/artifact-templates.md` - Artifact template collection
   - `formats/metadata-quick-ref.md` - Condensed metadata reference

3. **Progress/Recovery Infrastructure** (ProofChecker)
   - `formats/progress-file.md` - Phase-level progress tracking
   - `formats/handoff-artifact.md` - Context exhaustion recovery
   - `formats/debug-report-format.md` - Debug cycle tracking
   - `formats/changelog-format.md` - Permanent work history

4. **Git Safety** (ProofChecker)
   - `standards/git-staging-scope.md` - Per-agent staging scopes

5. **Index Utilities** (ProofChecker, Theory)
   - `utils/index-query.md` - jq query patterns for index.json
   - `scripts/generate-context-index.sh` - Index generation script
   - `scripts/update-plan-status.sh` - Plan file status sync

6. **MCP Resilience** (ProofChecker, Theory)
   - `patterns/mcp-tool-recovery.md` - General MCP failure patterns
   - `patterns/blocked-mcp-tools.md` - Blocked tool reference template

7. **Research Enhancement** (Theory)
   - `templates/context-knowledge-template.md` - Knowledge extraction

#### Category B: Domain Extensions (Loadable Modules)

These are domain-specific components that should be optional:

**Lean Extension Pack:**
- Commands: `/lake`, `/lean`
- Skills: `skill-lean-research`, `skill-lean-implementation`, `skill-lake-repair`, `skill-lean-version`
- Agents: `lean-research-agent`, `lean-implementation-agent`
- Rules: `lean4.md` (path trigger: `**/*.lean`)
- Context: `context/project/lean4/**` (15+ files)
- Scripts: `setup-lean-mcp.sh`, `verify-lean-mcp.sh`

**Logic Extension Pack:**
- Skills: `skill-logic-research`
- Agents: `logic-research-agent`
- Context: `context/project/logic/**` (10+ files)

**Math Extension Pack:**
- Skills: `skill-math-research`
- Agents: `math-research-agent`
- Context: `context/project/math/**` (5+ files)

**LaTeX Extension Pack (partial - already in nvim):**
- Skills: `skill-latex-research` (missing from nvim)
- Agents: `latex-research-agent` (missing from nvim)
- Rules: `latex.md` (already in nvim)
- Context: `context/project/latex/**` (already in nvim)

**Typst Extension Pack (partial - already in nvim):**
- Skills: `skill-typst-research` (missing from nvim, in Theory)
- Agents: `typst-research-agent` (missing from nvim, in Theory)
- Context: `context/project/typst/**` (already in nvim)

**GitLab Extension Pack:**
- Commands: `/merge`

#### Category C: Project-Specific (Not Portable)

- `context/project/logic/domain/bilateral-semantics.md` (Logos-specific)
- `context/project/logic/domain/task-semantics.md` (Logos task semantics)
- `context/project/lean4/standards/proof-conventions-lean.md` (project conventions)
- `context/project/opencode/opencode-conventions.md` (Theory-specific editor)
- `docs/guides/tts-stt-integration.md` (local setup specific)
- `docs/guides/wezterm-integration.md` (local setup specific)

### 4. Architecture Design Recommendations

#### Core + Extensions Model

```
.claude/                          # Core system (managed by <leader>ac)
├── commands/                     # Core commands (12 base commands)
├── skills/                       # Core skills (orchestration, git, meta, etc.)
├── agents/                       # Core agents (general-*, planner, meta-builder)
├── rules/                        # Core rules (5 base rules)
├── context/
│   ├── core/                     # Core context (all general-purpose)
│   └── project/
│       ├── meta/                 # Always present (meta-building context)
│       ├── repo/                 # Always present (project overview)
│       └── processes/            # Always present (workflow processes)
├── extensions/                   # Extension registry (NEW)
│   ├── registry.json             # Available and active extensions
│   ├── neovim/                   # Neovim extension pack
│   │   ├── manifest.json         # Extension metadata and dependencies
│   │   ├── commands/             # Domain commands
│   │   ├── skills/               # Domain skills
│   │   ├── agents/               # Domain agents
│   │   ├── rules/                # Domain rules
│   │   └── context/              # Domain context files
│   ├── lean/                     # Lean extension pack
│   ├── latex/                    # LaTeX extension pack
│   ├── typst/                    # Typst extension pack
│   ├── logic/                    # Logic extension pack
│   ├── math/                     # Math extension pack
│   └── gitlab/                   # GitLab extension pack
├── scripts/
├── docs/
└── tests/
```

#### Extension Manifest Schema

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 formal verification support",
  "dependencies": ["math"],
  "provides": {
    "commands": ["/lake", "/lean"],
    "skills": ["skill-lean-research", "skill-lean-implementation", "skill-lake-repair", "skill-lean-version"],
    "agents": ["lean-research-agent", "lean-implementation-agent"],
    "rules": ["lean4.md"],
    "context_paths": ["project/lean4/"],
    "scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"],
    "languages": ["lean"]
  },
  "mcp_servers": {
    "lean-lsp": {
      "required": true,
      "setup_script": "setup-lean-mcp.sh",
      "verify_script": "verify-lean-mcp.sh"
    }
  }
}
```

#### Extension Loading Mechanism

The `<leader>ac` keybinding opens a Telescope picker (or similar UI) that:

1. **Lists available extensions** from `extensions/registry.json`
2. **Shows active/inactive status** for each extension
3. **Enables toggling extensions** on/off
4. **Handles dependencies** (activating Lean automatically activates Math)
5. **Manages symlinks** or includes to wire extensions into the active system

When an extension is activated:
- Its commands are symlinked into `commands/`
- Its skills are symlinked into `skills/`
- Its agents are symlinked into `agents/`
- Its rules are symlinked into `rules/`
- Its context is added to `context/project/`
- The `index.json` is regenerated

When deactivated:
- Symlinks are removed
- Index is regenerated
- Active projects using that language are flagged

#### Extension Registry Schema

```json
{
  "extensions": {
    "neovim": {
      "active": true,
      "path": "extensions/neovim/",
      "manifest": "extensions/neovim/manifest.json"
    },
    "lean": {
      "active": false,
      "path": "extensions/lean/",
      "manifest": "extensions/lean/manifest.json"
    }
  },
  "auto_detect": true
}
```

#### Relationship to ProofChecker

With this architecture:
```
ProofChecker/.claude/ = core system + lean extension + logic extension + math extension
Theory/.claude/       = core system + lean extension + logic extension + math extension + typst research extension
nvim/.claude/         = core system + neovim extension + latex extension + typst extension
```

### 5. Items Missing from nvim Core That Should Be Added

#### Priority 1: Reference Documentation

These are pure documentation additions that improve agent effectiveness:

1. `context/core/reference/command-reference.md` - Full command reference
2. `context/core/reference/state-json-schema.md` - Complete state.json schema
3. `context/core/reference/error-recovery-procedures.md` - Recovery procedures
4. `context/core/reference/skill-agent-mapping.md` - Skill-to-agent mapping
5. `context/core/reference/artifact-templates.md` - Template collection
6. `context/core/formats/metadata-quick-ref.md` - Condensed metadata reference

#### Priority 2: Progress/Recovery Infrastructure

7. `context/core/formats/progress-file.md` - Phase progress tracking
8. `context/core/formats/handoff-artifact.md` - Context exhaustion recovery
9. `context/core/formats/debug-report-format.md` - Debug cycle tracking
10. `context/core/formats/changelog-format.md` - CHANGE_LOG.md format

#### Priority 3: Team Orchestration

11. `skills/skill-team-research/` - Parallel research
12. `skills/skill-team-plan/` - Parallel planning
13. `skills/skill-team-implement/` - Parallel implementation
14. `context/core/patterns/team-orchestration.md` - Wave patterns
15. `context/core/formats/team-metadata-extension.md` - Team metadata

#### Priority 4: Utility Improvements

16. `context/core/utils/index-query.md` - Index query patterns
17. `context/core/standards/git-staging-scope.md` - Safe git staging
18. `scripts/generate-context-index.sh` - Index generation
19. `scripts/update-plan-status.sh` - Plan status sync
20. `context/core/templates/context-knowledge-template.md` - Knowledge extraction

#### Priority 5: MCP Resilience (for when MCP tools are used)

21. `context/core/patterns/mcp-tool-recovery.md` - MCP failure patterns
22. `context/core/patterns/blocked-mcp-tools.md` - Blocked tool reference

## Decisions

- Classified domain-specific research agents (latex-research, typst-research) as extension content rather than core, because the general-research-agent already handles cross-domain web research
- Classified team orchestration as core infrastructure because it benefits any project type, not just Lean
- Classified MCP resilience patterns as core even though currently only Lean uses MCP tools, because any future MCP integration would benefit
- The roadmap-reflection-pattern is classified as lower priority because it depends on a well-maintained ROAD_MAP.md which not all projects have

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Extension symlink complexity | High - broken symlinks cause tool failures | Use a script to validate all symlinks on activation |
| Extension dependency cycles | Medium - circular deps block activation | Enforce DAG ordering in registry, validate at activation time |
| Core system bloat from adding all missing items | Medium - increased context consumption | Phase additions: reference docs first, team orchestration second |
| Extension switching breaks active tasks | High - tasks reference removed language | Warn when deactivating extension with active tasks |
| index.json staleness after extension toggle | High - agents load wrong context | Auto-regenerate index.json on every extension activation/deactivation |

## Appendix

### Search Methodology

1. Used `ls`, `find`, and `comm` to enumerate and compare components across all three systems
2. Read unique files in ProofChecker and Theory to assess portability
3. Classified each difference as core infrastructure, domain extension, or project-specific
4. Cross-referenced CLAUDE.md configurations for feature parity

### Component Counts Summary

| Component | nvim | ProofChecker | Theory |
|-----------|------|-------------|--------|
| Commands | 12 | 14 | 15 |
| Skills | 14 | 21 | 20 |
| Agents | 9 | 12 | 12 |
| Rules | 7 | 7 | 7 |
| Core context files | 59 | 76 | 67 |
| Project context files | 32 | 42 | 58 |
| Scripts | 11 | 14 | 11 |
| Doc guides | 10 | 8 | 12 |

### Files Only in nvim (Not in Others)

| Component | File | Notes |
|-----------|------|-------|
| Agent | neovim-implementation-agent.md | nvim domain-specific |
| Agent | neovim-research-agent.md | nvim domain-specific |
| Skill | skill-neovim-implementation | nvim domain-specific |
| Skill | skill-neovim-research | nvim domain-specific |
| Rule | neovim-lua.md | nvim domain-specific |
| Script | migrate-directory-padding.sh | One-time migration |
| Doc | guides/adding-domains.md | Important for extension architecture |
| Doc | reference/standards/agent-frontmatter-standard.md | nvim evolved this |
| Doc | reference/standards/multi-task-creation-standard.md | nvim evolved this |
| Context | core/orchestration/delegation.md | nvim has more orchestration docs |
| Context | core/orchestration/orchestrator.md | nvim has more orchestration docs |
| Context | core/orchestration/routing.md | nvim has more orchestration docs |
| Context | core/orchestration/sessions.md | nvim has more orchestration docs |
| Context | core/patterns/context-discovery.md | nvim has this, others use index-query.md |
