# Supplementary Research Report: Task #116

**Task**: 116 - Verify OpenCode & Implement Extension Parity
**Started**: 2026-03-02
**Completed**: 2026-03-02
**Effort**: 2-3 hours (implementation using templates)
**Dependencies**: research-001.md
**Sources/Inputs**: Codebase exploration of /home/benjamin/Projects/Logos/Theory/.opencode/, /home/benjamin/Projects/ProofChecker/.opencode/, /home/benjamin/.dotfiles/.opencode/, and /home/benjamin/.config/nvim/.claude/extensions/
**Artifacts**: specs/116_verify_opencode_implement_extension_parity/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- Three other .opencode/ systems were explored: Logos/Theory (lean-focused), ProofChecker (lean-focused), and dotfiles (meta/system-builder-focused)
- **None of the other systems use the extensions/ directory pattern** -- they all embed agents, skills, and context directly in the core .opencode/ tree
- The extension pattern is unique to the nvim repository and was retrofitted from the .claude/ extension system
- Logos/Theory is the closest match to nvim's needs, sharing 14 agents and 20 skills (latex, typst, lean, logic, math, document-converter)
- ProofChecker has a more specialized subagent hierarchy (20 subagents including meta/system-builder decomposition)
- dotfiles uses a fundamentally different architecture (XML-structured agents, system-builder subagent tree, no task management skills)
- **7 extensions must be created from scratch** for .opencode/: document-converter, latex, nix, python, typst, web, z3
- The .claude/ extension files can be directly adapted (manifest.json rekey, agent frontmatter conversion, path prefix change from `.claude` to `.opencode`)

## Context & Scope

This supplementary research examines three external .opencode/ installations to identify:
1. Reusable agent/skill/context components for populating nvim .opencode/ extensions
2. Architectural patterns and conventions across .opencode/ implementations
3. Whether the extension pattern exists elsewhere or is nvim-specific
4. Which components from .claude/ extensions can be mechanically translated vs. requiring manual adaptation

## Findings

### 1. Logos/Theory .opencode/ System

**Location**: `/home/benjamin/Projects/Logos/Theory/.opencode/`

**Architecture**: Full task management system with lean-focused orchestration.

**Agents** (14 subagents):
- document-converter-agent, general-implementation-agent, general-research-agent
- latex-implementation-agent, latex-research-agent
- lean-implementation-agent, lean-research-agent
- logic-research-agent, math-research-agent
- meta-builder-agent, planner-agent
- typst-implementation-agent, typst-research-agent

**Skills** (20):
- skill-document-converter, skill-git-workflow, skill-implementer
- skill-lake-repair, skill-latex-implementation, skill-latex-research
- skill-lean-implementation, skill-lean-research, skill-lean-version
- skill-learn, skill-logic-research, skill-math-research
- skill-meta, skill-orchestrator, skill-planner
- skill-refresh, skill-researcher, skill-status-sync
- skill-typst-implementation, skill-typst-research

**Context**: latex, lean4, logic, math, meta, physics, processes, repo, typst

**Key Pattern**: No extensions/ directory. All agents, skills, and context reside directly in the core .opencode/ tree. The `OC_` prefix on task numbers (e.g., `OC_017`) is unique to this project.

**Reusable for nvim**: Agent file patterns, skill SKILL.md patterns, and context structure for latex, typst, logic, and math are directly reusable as templates.

### 2. ProofChecker .opencode/ System

**Location**: `/home/benjamin/Projects/ProofChecker/.opencode/`

**Architecture**: Most mature system with extensive subagent hierarchy and specialized meta subsystem.

**Top-Level Agents** (10):
- document-converter-agent, general-implementation-agent, general-research-agent
- latex-implementation-agent, lean-implementation-agent, lean-research-agent
- meta-builder-agent, orchestrator, planner-agent, skill-orchestrator

**Subagents** (20, organized hierarchically):
- Core workflow: implementer, researcher, planner, reviewer, task-creator, task-divider, task-executor, task-reviser, todo-manager
- Lean-specific: lean-implementation-agent, lean-planner, lean-research-agent
- Meta/System-builder: agent-generator, command-creator, context-organizer, domain-analyzer, workflow-designer
- Utility: atomic-task-numberer, description-clarifier, error-diagnostics-agent, git-workflow-manager, status-sync-manager

**Skills** (13):
- skill-document-converter, skill-git-workflow, skill-implementer
- skill-latex-implementation, skill-lean-implementation, skill-lean-research
- skill-learn, skill-meta, skill-orchestrator
- skill-planner, skill-refresh, skill-researcher, skill-status-sync

**Key Pattern**: Uses `command/` (singular) instead of `commands/` (plural). The orchestrator is a pure router that delegates to command files. Has `AGENTS.md` at root level for agent-wide rules (no emoji policy). Most mature task management with 50+ task directories.

**Reusable for nvim**: The orchestrator pattern (pure router), AGENTS.md convention, and meta subagent decomposition (agent-generator, command-creator, context-organizer, domain-analyzer, workflow-designer) could enrich the meta extension.

### 3. Dotfiles .opencode/ System

**Location**: `/home/benjamin/.dotfiles/.opencode/`

**Architecture**: Fundamentally different - XML-structured agents with system-builder focus, no task management workflow.

**Top-Level Agents** (5):
- AGENT.md (universal primary agent)
- coder.md, general.md, meta.md, repository.md

**Subagents** (organized by category):
- code/: build-agent, codebase-pattern-analyst, coder-agent, reviewer, tester
- core/: documentation, task-manager
- system-builder/: agent-generator, command-creator, context-organizer, domain-analyzer, workflow-designer
- utils/: image-specialist

**Key Differences from nvim**:
- Uses XML structured prompts (`<context>`, `<role>`, `<task>`, `<workflow_execution>`) following Stanford/Anthropic research patterns
- Uses frontmatter with `mode: primary` / `mode: subagent` designation
- Has `tool/` directory (custom tools), `plugin/` directory (plugin system), `prompts/` directory
- Has `command/openagents/` for system generation commands
- Uses `command/` (singular) directory naming
- No task management skills (no /research, /plan, /implement workflow)
- No extensions/ system

**Reusable for nvim**: The system-builder subagent hierarchy (same 5 agents as ProofChecker meta/). The XML-structured agent pattern could be adapted for .opencode agent files, though the current nvim .opencode agents use the markdown-with-frontmatter pattern from .claude/.

### 4. Extension Architecture Comparison

| Feature | nvim .claude/ | nvim .opencode/ | Logos/Theory | ProofChecker | dotfiles |
|---------|--------------|-----------------|--------------|--------------|----------|
| Extensions dir | Yes (9) | Yes (2) | No | No | No |
| Extension manifest.json | Yes | Yes | N/A | N/A | N/A |
| Extension EXTENSION.md | Yes | Yes | N/A | N/A | N/A |
| index-entries.json | Yes | Yes (empty) | N/A | N/A | N/A |
| Context in core | Yes | Yes | Yes | Yes | Yes |
| Agents in core | Yes | Yes | Yes | Yes | Yes |
| Skills in core | Yes | Yes | Yes | Yes | No |

**Key Finding**: The extension pattern (with manifest.json, EXTENSION.md, merge_targets) is unique to the nvim repository. Other .opencode/ systems embed all components directly in the core tree. This means there are no pre-built .opencode/ extension packages to copy -- all 7 missing extensions must be created by adapting the .claude/ counterparts.

### 5. Gap Analysis: Missing .opencode/ Extensions

| Extension | .claude/ Status | .opencode/ Status | Agents Needed | Skills Needed | Context Files | Rules |
|-----------|----------------|-------------------|---------------|---------------|---------------|-------|
| document-converter | Complete | Missing entirely | 1 | 1 | 0 | 0 |
| latex | Complete | Core has agents/skills/context, no extension | 2 (in core) | 2 (in core) | 7+ (in core) | 1 (in core) |
| nix | Complete | Missing entirely | 2 | 2 | 11 context files | 1 |
| python | Complete | Missing entirely | 2 | 2 | 6 context files | 0 |
| typst | Complete | Core has agents/skills/context, no extension | 2 (in core) | 2 (in core) | 13+ (in core) | 0 |
| web | Complete | Core has context, missing agents/skills | 2 | 2 | 15+ context files | 1 |
| z3 | Complete | Missing entirely | 2 | 2 | 4 context files | 0 |

### 6. Extension Creation Strategy

Three categories of work:

**Category A - Already in core, needs extension packaging** (latex, typst):
- Agents and skills already exist in .opencode/agent/subagents/ and .opencode/skills/
- Context already exists in .opencode/context/project/
- Need: manifest.json, EXTENSION.md, index-entries.json, directory structure
- Effort: 15-20 minutes each (copy manifest pattern, create EXTENSION.md)

**Category B - Partial in core, needs extension + completion** (web):
- Context exists in .opencode/context/project/web/
- Missing: web-research-agent, web-implementation-agent, skill-web-research, skill-web-implementation
- Need: Full extension package + agents/skills adapted from .claude/ counterparts
- Effort: 30-45 minutes

**Category C - Missing entirely, needs full creation from .claude/** (document-converter, nix, python, z3):
- No .opencode/ components exist
- Need: Adapt all files from .claude/extensions/{name}/ to .opencode/ format
- Key adaptations:
  - manifest.json: Change `claudemd` to `opencode_md`, change `.claude/CLAUDE.md` to `.opencode/OPENCODE.md`
  - Agent frontmatter: Add `mode: subagent`, `temperature: 0.2`, `tools:` block, `permissions:` block
  - SKILL.md: Change `@.claude/` paths to `@.opencode/` paths
  - Context paths: Change `.claude/extensions/` to `.opencode/extensions/`
  - Rules: Change `.claude/rules/` references to `.opencode/rules/`
  - index-entries.json: Change all path prefixes from `.claude/extensions/` to `.opencode/extensions/`
- Effort: 30-45 minutes each

### 7. Adaptation Pattern: .claude/ to .opencode/ Translation

**manifest.json changes**:
```json
// .claude/ version
"merge_targets": {
  "claudemd": {
    "source": "EXTENSION.md",
    "target": ".claude/CLAUDE.md",
    "section_id": "extension_nix"
  }
}

// .opencode/ version
"merge_targets": {
  "opencode_md": {
    "source": "EXTENSION.md",
    "target": ".opencode/OPENCODE.md",
    "section_id": "extension_oc_nix"
  }
}
```

**Agent frontmatter additions** (for .opencode/ agents):
```yaml
---
name: nix-research-agent
description: Research NixOS and Home Manager configuration tasks
mode: subagent
temperature: 0.2
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
    "ls": "allow"
    "cat": "allow"
    "pwd": "allow"
    "jq": "allow"
    "rm -rf": "deny"
    "sudo": "deny"
---
```

**Path prefix substitution** (global):
- `.claude/` -> `.opencode/`
- `@.claude/` -> `@.opencode/`
- `CLAUDE.md` -> `OPENCODE.md` (in merge_targets only)

### 8. Reusable Components from Other Systems

**From Logos/Theory** (most relevant):
- Agent file structure pattern for latex-research-agent, typst-research-agent
- Skill SKILL.md pattern (identical structure to nvim .opencode/ existing skills)
- Context README.md structure for domain knowledge indices
- OPENCODE.md section format for extension registration

**From ProofChecker**:
- Meta subagent decomposition (5 specialized agents: agent-generator, command-creator, context-organizer, domain-analyzer, workflow-designer) -- useful if implementing a meta extension
- AGENTS.md root-level agent rules file pattern
- Pure router orchestrator pattern (v7.0) with minimal context loading

**From dotfiles**:
- System-builder subagent hierarchy (same 5 as ProofChecker meta/)
- XML-structured agent prompts with `<context>`, `<role>`, `<task>` tags
- Prompt engineering patterns following Stanford/Anthropic research

### 9. Components NOT Reusable

- ProofChecker's 50+ task directories and specs (project-specific)
- dotfiles' plugin/ and tool/ directories (custom infrastructure not applicable)
- dotfiles' prompts/ directory (system generation prompts, not needed)
- ProofChecker's python scripts in scripts/__pycache__/ (project-specific)
- Logos/Theory's plans/ and logs/ directories (ephemeral data)

## Recommendations

### Implementation Approach

1. **Start with Category A** (latex, typst): Create extension packages for components already in core. This validates the extension structure pattern before tackling harder categories.

2. **Then Category C** (document-converter, nix, python, z3): Adapt .claude/ extension files with mechanical translation (path prefix changes + frontmatter additions).

3. **Finally Category B** (web): Complete the extension by creating missing agents/skills and packaging.

### Mechanical Translation Script

A batch translation could use sed/awk to:
1. Copy .claude/extensions/{name}/ to .opencode/extensions/{name}/
2. Apply path prefix changes (.claude/ -> .opencode/)
3. Rekey manifest.json merge_targets (claudemd -> opencode_md)
4. Add .opencode-specific frontmatter to agent files
5. Update index-entries.json paths

### Consistency with Existing Extensions

All new extensions should follow the pattern established by the existing formal/ and lean/ extensions:
- manifest.json with `merge_targets.opencode_md` pointing to `.opencode/OPENCODE.md`
- EXTENSION.md with Language Routing and Skill-Agent Mapping tables
- index-entries.json (can start empty, populated as needed)
- Agent files with mode/temperature/tools/permissions frontmatter blocks

## Decisions

1. Extensions will be created by adapting .claude/ counterparts, not copying from other .opencode/ systems (none have extension support)
2. Context files already in .opencode/context/project/ will be referenced but not duplicated in extension directories
3. Agent frontmatter will follow the lean extension pattern (mode: subagent, temperature: 0.2, explicit tool/permission blocks)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Path mismatch after translation | Broken @-references in agents/skills | Validate all @-references resolve after translation |
| Missing nix MCP server config | nix-research-agent cannot use mcp-nixos | Include settings-fragment.json with mcp server config |
| Context duplication (core vs extension) | Confusion about canonical location | Reference core context via relative paths, do not duplicate |
| Empty index-entries.json | Context discovery does not find extension files | Populate index-entries.json with actual context file entries |

## Appendix

### Systems Explored

| System | Path | Primary Language | Extensions | Agents | Skills |
|--------|------|-----------------|------------|--------|--------|
| Logos/Theory | /home/benjamin/Projects/Logos/Theory/.opencode/ | lean | None | 14 | 20 |
| ProofChecker | /home/benjamin/Projects/ProofChecker/.opencode/ | lean | None | 10+20 | 13 |
| dotfiles | /home/benjamin/.dotfiles/.opencode/ | nix (meta) | None | 5+13 | 0 |
| nvim (target) | /home/benjamin/.config/nvim/.opencode/ | neovim | 2 (formal, lean) | 17 | 22 |

### Directory Naming Convention

| System | Command Dir | Agents Dir |
|--------|------------|------------|
| Logos/Theory | commands/ (plural) | agent/subagents/ |
| ProofChecker | command/ (singular) | agent/ + agent/subagents/ |
| dotfiles | command/ (singular) | agent/ + agent/subagents/ |
| nvim .opencode | commands/ (plural) | agent/subagents/ |

### Search Queries Used

- File system exploration: `find {path}/.opencode/ -type f | sort`
- Directory structure: `find {path}/.opencode/ -maxdepth 2 -type d | sort`
- Extension search: `find {path}/.opencode/ -path "*/extensions/*" -type f`
- Component search: `find {path}/.opencode/ -name "*nix*" -o -name "*python*" -o -name "*z3*" -o -name "*web*"`

## Next Steps

Run /plan 116 to create an implementation plan that covers creating the 7 missing .opencode/ extensions with the mechanical translation approach documented above.
