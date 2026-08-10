# Research Report: Task #111

**Task**: 111 - compare_opencode_agent_systems
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T01:00:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Direct file system exploration of both .opencode/ directories
**Artifacts**: specs/111_compare_opencode_agent_systems/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The **nvim .opencode/** system (291 files, 115 directories) is a newer, more refined architecture with an extension system, three-layer delegation (Commands -> Skills -> Agents), deprecated the centralized orchestrator in favor of direct skill invocation, and includes WezTerm/TTS integration hooks
- The **ProofChecker .opencode/** system (950 files, 700 directories) is a more mature but older architecture with deep XML-structured agents, rich domain knowledge (logic, math, physics), comprehensive ADR documentation, a formal subagent hierarchy (Level 0-3), and detailed frontmatter-based delegation with explicit tool/permission declarations
- **Recommendation**: The nvim system has the superior architecture (extension system, simplified routing, better hooks), while the ProofChecker system has superior domain knowledge depth and documentation rigor. The ideal approach would be to port ProofChecker's domain context into the nvim system's extension framework

## Context and Scope

This research compares two .opencode/ agent systems deployed in different repositories:

1. `/home/benjamin/.config/nvim/.opencode/` - Agent system for Neovim configuration management
2. `/home/benjamin/Projects/ProofChecker/.opencode/` - Agent system for Lean 4 theorem proving

Both systems share a common ancestry (the .opencode task management framework) but have diverged significantly in architecture and specialization.

## Findings

### 1. Scale and Complexity

| Metric | nvim | ProofChecker |
|--------|------|-------------|
| Files (excl. node_modules) | 291 | 950 |
| Directories | 115 | 700 |
| Top-level agents | 11 | 10 + 21 subagents |
| Commands | 12 | 13 |
| Skills | 14 | 13 |
| Rules files | 7 | 7 |
| Context directories | 37 | ~50 |
| Extensions | 6 (latex, lean, python, typst, web, z3) | 0 |
| Hook scripts | 9 | 4 |
| Utility scripts | 9 | 22 |
| Task spec directories | N/A (uses main specs/) | 65+ |
| Documentation files (docs/) | 19 | 15 |

The ProofChecker system is roughly 3x larger by file count. However, a significant portion (roughly 600 directories) comes from deeply nested spec directories and domain context trees. The nvim system is leaner but covers more language domains via extensions.

### 2. Architectural Patterns

#### nvim: Three-Layer + Extensions

The nvim system uses a three-layer architecture:

```
Layer 1: Commands (.opencode/commands/*.md)
    - Parse arguments, route by language
    - Minimal logic, checkpoint-based (GATE IN -> DELEGATE -> GATE OUT)

Layer 2: Skills (.opencode/skills/skill-*/SKILL.md)
    - Validate inputs, prepare context
    - Invoke agents via Task tool
    - Handle preflight/postflight status updates

Layer 3: Agents (.opencode/agents/*.md)
    - Full execution with file operations
    - Create artifacts and return metadata files
    - Write .return-meta.json for skill postflight
```

Key innovation: The **skill-orchestrator is deprecated** (as of 2026-02-06). Commands now directly invoke skills, which internally route to subagents. This eliminates a layer of indirection.

Key innovation: The **extension system** (`extensions/{name}/manifest.json`) allows modular language support. Each extension provides agents, rules, context, and MCP server configurations. This makes the system portable across projects -- you add/remove extensions rather than rewriting core files.

#### ProofChecker: Orchestrator-Centric + Subagent Hierarchy

The ProofChecker uses a traditional orchestrator pattern:

```
Level 0: Orchestrator (.opencode/agent/orchestrator.md)
    - Pure router (v7.0): loads command file, delegates with $ARGUMENTS
    - Delegation registry management, cycle detection, depth enforcement

Level 1: Commands (.opencode/command/*.md)
    - Full workflow_execution stages with XML structure
    - Argument parsing, validation, language extraction
    - Direct delegation to subagents

Level 2: Subagents (.opencode/agent/subagents/*.md)
    - Core: task-executor, researcher, planner, implementer
    - Lean-specific: lean-implementation-agent, lean-research-agent, lean-planner
    - Support: status-sync-manager, git-workflow-manager, error-diagnostics-agent
    - Meta builder: domain-analyzer, agent-generator, context-organizer, workflow-designer, command-creator

Level 3: Specialists (planned, not yet implemented)
```

Key design: The orchestrator stays extremely lightweight (<5% context window, ~50 lines after migration) and acts as a pure router. All workflow logic lives in command files and subagents.

**Virtue comparison**:

| Aspect | nvim | ProofChecker |
|--------|------|-------------|
| Routing simplicity | Commands invoke skills directly (no orchestrator) | Orchestrator routes to commands which route to subagents |
| Depth of delegation | 2 layers (skill -> agent) | 3 layers (orchestrator -> command -> subagent) |
| Context window efficiency | Good (lazy loading) | Excellent (explicit budgets: <10% orchestrator, 60-80% agents) |
| Portability | Excellent (extension system) | Poor (domain context embedded in core) |

### 3. Agent Definition Quality

#### ProofChecker: XML-Structured, Frontmatter-Rich

ProofChecker agents use detailed YAML frontmatter with explicit declarations:

```yaml
---
name: "task-executor"
version: "1.0.0"
description: "Multi-phase task execution with resume support"
mode: subagent
agent_type: execution
temperature: 0.2
max_tokens: 4000
timeout: 7200
tools:
  read: true
  write: true
  bash: true
permissions:
  allow:
    - read: [".opencode/**/*"]
    - write: [".opencode/specs/**/*"]
  deny:
    - bash: ["rm -rf", "sudo", "chmod +x", "dd"]
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/orchestration/delegation.md"
  max_context_size: 50000
delegation:
  max_depth: 3
  can_delegate_to: ["implementer", "lean-implementation-agent"]
  timeout_default: 7200
lifecycle:
  stage: 4
  command: "/implement"
  return_format: "subagent-return-format.md"
---
```

And XML-structured body with typed parameters:

```xml
<context>
  <specialist_domain>...</specialist_domain>
  <task_scope>...</task_scope>
</context>
<inputs_required>
  <parameter name="task_number" type="integer">...</parameter>
</inputs_required>
<workflow_execution>
  <stage id="1" name="LoadPlan">...</stage>
</workflow_execution>
```

**Virtues**: Extremely explicit, machine-parseable frontmatter; clear permission boundaries; version tracking; lifecycle metadata; delegation safety built into every agent definition.

**Drawbacks**: Verbose; much of the frontmatter is aspirational (OpenCode/Claude Code does not actually enforce temperature, max_tokens, or permissions from frontmatter at runtime); the XML structure is readable but adds overhead.

#### nvim: Markdown-Native, Minimal Frontmatter

nvim agents use lightweight Claude Code native frontmatter:

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
---
```

The body uses standard markdown with @-reference context loading:

```markdown
## Context References
Load these on-demand using @-references:
- `@.opencode/context/core/formats/return-metadata-file.md`

## Execution Flow
### Stage 0: Initialize Early Metadata
### Stage 1: Parse Delegation Context
...
```

**Virtues**: Simpler; avoids over-specifying what the runtime cannot enforce; markdown is more readable; context loading via @-references is the native Claude Code pattern.

**Drawbacks**: Less explicit about permissions, tool access, and delegation boundaries; relies more on convention than declaration.

### 4. Domain Knowledge Depth

The ProofChecker has significantly richer domain context:

**ProofChecker domain context**:
- `lean4/` - 22 files covering syntax, Mathlib, tactics, proof workflows, style guides, tool integration (LeanSearch, Loogle, LSP, Aesop)
- `logic/` - 12 files covering Kripke semantics, proof theory, metalogic, modal/temporal proof strategies, naming conventions
- `math/` - 5 files covering algebra (groups, monoids, rings, fields), lattice theory, order theory, topology
- `physics/` - 1 file covering dynamical systems
- `latex/` - Standard LaTeX patterns and standards
- `meta/` - Architecture principles, interview patterns, domain patterns
- `repo/` - Repository-specific knowledge

**nvim domain context**:
- `neovim/` - 13 files covering LSP, Lua patterns, API, plugin ecosystem, keymaps, ftplugins, lazy.nvim, telescope, treesitter
- `web/` - 14 files covering Astro framework, Cloudflare Pages, Tailwind v4, TypeScript, accessibility, component patterns
- `meta/` - 6 files covering architecture principles, interview patterns, domain patterns, standards checklist
- `hooks/` - 1 file covering WezTerm integration
- `repo/` - Project-specific knowledge

**Extensions add**:
- `lean/` - 3 files (mathlib overview, style guide, tactic patterns)
- `latex/` - 7 files
- `python/` - 6 files
- `typst/` - 7 files
- `web/` - 14 files (mirrors core web context)
- `z3/` - Domain and pattern files

The ProofChecker's domain knowledge is deeper and more specialized (covering actual mathematical concepts), while the nvim system is broader but shallower (covering more language ecosystems at a tool-integration level).

### 5. Documentation Quality

| Aspect | nvim | ProofChecker |
|--------|------|-------------|
| Top-level docs | No README, no ARCHITECTURE | AGENTS.md, ARCHITECTURE.md, QUICK-START.md, README.md, TESTING.md |
| Architecture doc | system-overview.md (in docs/) | 853-line ARCHITECTURE.md with full flow diagrams |
| Testing guide | system-testing-guide.md | 300+ line TESTING.md with specific test cases |
| ADRs | None | 3 ADRs + migration lessons learned |
| Standards quick ref | None | STANDARDS_QUICK_REF.md (490 lines) |
| Migration docs | None | Full migration README with metrics |
| Guides | 11 guides (adding domains, creating agents, commands, skills, MCP setup, etc.) | 3 guides (context loading, creating commands, permissions) |
| Examples | 2 (learn flow, research flow) | None in docs (examples embedded in commands) |

The ProofChecker has superior top-level documentation (ARCHITECTURE.md is exceptionally thorough), ADRs documenting key decisions, and a comprehensive standards quick reference. The nvim system has more "how to extend" guides but lacks the architectural overview documentation.

### 6. Hook and Integration Quality

**nvim hooks** (9 files):
- `log-session.sh` - Session logging
- `post-command.sh` - Post-command cleanup
- `subagent-postflight.sh` - Prevents premature workflow termination
- `tts-notify.sh` - Text-to-speech notification on completion
- `validate-state-sync.sh` - State file validation
- `wezterm-clear-status.sh` - Clear WezTerm terminal status
- `wezterm-clear-task-number.sh` - Clear task number display
- `wezterm-notify.sh` - WezTerm notification
- `wezterm-task-number.sh` - Display task number in terminal

Additional settings.json hooks:
- `UserPromptSubmit` handler for task tracking in terminal
- `claude-ready-signal.sh` for session start

**ProofChecker hooks** (4 files):
- `log-session.sh` - Session logging
- `post-command.sh` - Post-command cleanup
- `subagent-postflight.sh` - Prevents premature workflow termination (identical logic)
- `validate-state-sync.sh` - State file validation

The nvim system has significantly richer user experience integration with WezTerm terminal notifications and TTS support. These are quality-of-life features that make the workflow more ergonomic. The ProofChecker's hooks are functional but minimal.

### 7. Extension System (nvim-only)

The nvim system's extension architecture is a significant differentiator:

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 theorem prover support",
  "language": "lean4",
  "provides": {
    "agents": ["lean-research.md", "lean-implementation.md"],
    "skills": [],
    "commands": [],
    "rules": ["lean4.md"],
    "context": ["project/lean4"],
    "scripts": [],
    "hooks": []
  },
  "mcp_servers": {
    "lean-lsp": {
      "command": "npx",
      "args": ["-y", "lean-lsp-mcp@latest"]
    }
  }
}
```

Each extension is self-contained with:
- Its own agents
- Its own rules
- Its own context tree
- MCP server configuration
- Merge targets for main configuration

This means the core system can be deployed to any project and you simply activate the relevant extensions. The ProofChecker has no equivalent mechanism -- all its domain knowledge is baked into the core `context/project/` directory.

### 8. Script and Tooling Quality

**ProofChecker** has richer validation and testing scripts:
- `validate-context-refs.sh` - Validate all context file references
- `validate_frontmatter.py` - Python-based frontmatter validation
- `validate_state_sync.py` - Python-based state sync validation
- `validate-system.sh` - Full system validation
- `measure-context-usage.sh` - Measure context window consumption
- `test-command.sh`, `test-execution.sh`, `test-stage7-reliability.sh` - Test harnesses
- `execute-command.sh` - Main command router

**nvim** has utility-focused scripts:
- `export-to-markdown.sh` - Export system to markdown
- `install-aliases.sh` - Install shell aliases
- `install-systemd-timer.sh` - Install refresh timer
- `opencode-cleanup.sh`, `opencode-project-cleanup.sh` - Cleanup scripts
- `opencode-refresh.sh` - System refresh
- `postflight-*.sh` - Postflight handlers for research, plan, implement

The ProofChecker has more validation and testing infrastructure, while the nvim system has more deployment and maintenance tooling.

### 9. State Management

Both systems use `specs/state.json` + `specs/TODO.md` dual tracking, but with different schema emphasis:

**ProofChecker state.json** includes:
- `active_projects`, `completed_projects`, `archived_projects` (separate arrays)
- Per-task: `phase`, `status`, `priority`, `language`, `dependencies`, `artifacts`, `estimated_hours`, `research_summary`
- Rich artifact arrays with paths

**nvim state.json** includes:
- `active_projects` array (with `next_project_number`)
- Per-task: `project_number`, `project_name`, `status`, `language`, `completion_summary`, `roadmap_items`
- `repository_health` object

The ProofChecker tracks more metadata per task (dependencies, estimated hours, research summaries, phase tracking), which supports more sophisticated project management.

### 10. Unique Features

**nvim-only features**:
- Extension system with manifest.json
- WezTerm terminal integration (task number display, notifications)
- TTS notification on completion
- UserPromptSubmit hook for real-time task tracking
- claude-ready-signal.sh for session start
- Deprecated orchestrator (simpler routing)
- JSON context index (vs markdown)

**ProofChecker-only features**:
- Deep subagent hierarchy (21 specialized subagents)
- Meta system builder with 5 specialized sub-builders (domain-analyzer, agent-generator, context-organizer, workflow-designer, command-creator)
- Formal XML workflow stages in agent definitions
- Rich mathematical domain context (logic, algebra, topology, physics)
- ADR (Architecture Decision Records) documentation
- Migration documentation with metrics
- Python validation scripts
- Context measurement tooling
- Systemd service files (for refresh automation)
- TESTING.md with specific test cases per command
- STANDARDS_QUICK_REF.md

## Decisions

Based on the analysis:

1. **Architecture winner**: nvim -- the extension system and simplified routing (no orchestrator) are structurally superior
2. **Documentation winner**: ProofChecker -- ARCHITECTURE.md, ADRs, TESTING.md, and STANDARDS_QUICK_REF.md are excellent
3. **Domain knowledge winner**: ProofChecker -- deeper and more specialized context, especially for formal methods
4. **Developer experience winner**: nvim -- WezTerm hooks, TTS notifications, and extension portability
5. **Validation/testing winner**: ProofChecker -- more comprehensive validation scripts and test harnesses
6. **Agent definition winner**: Mixed -- ProofChecker is more explicit but over-specifies unenforceable properties; nvim is simpler but relies on convention

## Recommendations

### Which system to prefer

**Use the nvim system as the base architecture** for these reasons:
1. The extension system enables portability across projects
2. Simplified routing (direct command -> skill -> agent) reduces context window usage
3. WezTerm/TTS hooks improve developer experience
4. Leaner core makes maintenance easier

### What to adopt from ProofChecker

1. **Port domain context as extensions**: The ProofChecker's rich lean4, logic, math, and physics context should be packaged as extensions
2. **Add architectural documentation**: Create ARCHITECTURE.md and STANDARDS_QUICK_REF.md for the nvim system
3. **Add ADR practice**: Document key architectural decisions formally
4. **Add validation scripts**: Port validate-context-refs.sh and measure-context-usage.sh
5. **Add TESTING.md**: Create comprehensive test cases per command
6. **Consider subagent specialization**: The ProofChecker's task-executor, status-sync-manager, and git-workflow-manager are well-designed specializations worth adapting

### What to let go from ProofChecker

1. **XML workflow structure**: The XML tags (context, role, task, workflow_execution, validation) add verbosity without runtime benefit
2. **Aspirational frontmatter fields**: temperature, max_tokens, and granular permissions are not enforced by Claude Code
3. **Centralized orchestrator**: The nvim system correctly identified this as unnecessary overhead
4. **Monolithic domain context**: Should be extension-ized rather than embedded in core

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Porting domain context loses nuance | Medium | Medium | Careful review during extension creation |
| Extension system adds complexity for single-project use | Low | Low | Extensions are optional; core works standalone |
| ProofChecker's validation tooling may be Python-dependent | Medium | Low | Rewrite critical validators in bash |
| Loss of XML structure may reduce agent clarity | Low | Low | Markdown structure with clear headers is sufficient |

## Appendix

### Search Queries Used

1. `find` commands to enumerate all files and directories in both .opencode/ directories
2. Direct `Read` of: ARCHITECTURE.md, AGENTS.md, README.md, QUICK-START.md, TESTING.md, STANDARDS_QUICK_REF.md, settings.json, state.json, orchestrator.md, general-research-agent.md (both), lean-research-agent.md, task-executor.md, meta.md (subagent), skill-orchestrator (both), context indexes, subagent-postflight.sh, extension manifests
3. Directory structure analysis of: agents/, commands/, context/project/, skills/, hooks/, scripts/, docs/, extensions/, rules/

### File Count Methodology

Counts exclude `node_modules/` directories. Both systems have bun.lock and package.json files indicating Node.js tooling dependencies (primarily zod for schema validation).
