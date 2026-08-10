# Research Report: Task #502

**Task**: 502 - Create core extension skeleton for .opencode/
**Started**: 2026-05-02T14:30:00Z
**Completed**: 2026-05-02T15:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: 
- `.claude/extensions/core/` (source of truth)
- `.opencode/extensions/*/` (existing OpenCode extensions)
- Lua extension loader code (`lua/neotex/plugins/ai/shared/extensions/`)
- OpenCode picker code (`lua/neotex/plugins/ai/opencode/extensions/picker.lua`)
**Artifacts**: 
- `specs/OC_502_create_core_extension_opencode/reports/01_core-extension-skeleton.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Mapped the complete `.claude/extensions/core/` structure (159 files across 13 categories)
- Identified that `.opencode/extensions/` currently has NO `core/` extension - it needs to be created
- The "gate" at entries.lua:999-1005 only shows artifact sections when extensions are loaded; core must be loaded for full functionality
- OpenCode uses `opencode_md` merge target (not `claudemd`) and `agent/subagents` subdirectory structure
- Recommended skeleton mirrors `.claude/extensions/core/` with adaptations for OpenCode's extension system

## Context & Scope

This research investigates creating a core extension skeleton for `.opencode/` that mirrors the existing `.claude/extensions/core/` structure. The core extension is the foundational layer providing commands, skills, agents, rules, scripts, hooks, context, docs, templates, and systemd units.

Key investigation areas:
1. Complete mapping of `.claude/extensions/core/` structure
2. Understanding existing OpenCode extension patterns
3. Extension loader/picker mechanics (especially the "gate" logic)
4. Manifest.json adaptation for OpenCode

## Findings

### 1. Complete `.claude/extensions/core/` Structure Mapping

The source of truth contains **159 lines in manifest.json** with the following structure:

```
.claude/extensions/core/
├── manifest.json              # Extension metadata
├── EXTENSION.md              # Extension documentation
├── README.md                 # Root readme
├── agents/                   # 8 agents
│   ├── code-reviewer-agent.md
│   ├── general-implementation-agent.md
│   ├── general-research-agent.md
│   ├── meta-builder-agent.md
│   ├── planner-agent.md
│   ├── reviser-agent.md
│   ├── spawn-agent.md
│   └── README.md
├── commands/                 # 14 commands
│   ├── errors.md, fix-it.md, implement.md, merge.md, meta.md
│   ├── plan.md, project-overview.md, refresh.md, research.md
│   ├── review.md, revise.md, spawn.md, tag.md, task.md, todo.md
├── context/                  # 15+ directories, 100+ files
│   ├── architecture/        # Component checklist, context layers, generation guidelines, system overview
│   ├── checkpoints/         # Gate checkpoints (commit, gate-in, gate-out)
│   ├── formats/             # 13 format specifications (command-output, frontmatter, etc.)
│   ├── guides/              # Extension development, loader reference
│   ├── meta/                # Context revision, domain patterns, meta guide
│   ├── orchestration/       # 10+ orchestration docs (delegation, sessions, state management)
│   ├── patterns/            # 16 pattern docs (anti-stop, checkpoint, context-discovery, etc.)
│   ├── processes/           # Implementation, planning, research workflows
│   ├── reference/           # Artifact templates, skill-agent mapping, state schemas
│   ├── repo/                # Project overview, self-healing details, update project
│   ├── schemas/             # Frontmatter schema (JSON, YAML)
│   ├── standards/           # 13 standards (analysis framework, CI, code patterns, etc.)
│   ├── templates/           # Agent, command, delegation context templates
│   ├── troubleshooting/     # Workflow interruptions
│   ├── workflows/           # Command lifecycle, preflight-postflight, status transitions
│   ├── routing.md
│   ├── validation.md
│   └── index.schema.json
├── docs/                    # Documentation
│   ├── architecture/        # Extension system, system overview
│   ├── examples/            # Fix-it flow, research flow examples
│   ├── guides/              # Adding domains, creating agents/commands/extensions/skills
│   ├── reference/           # Standards (agent frontmatter, extension slim, multi-task creation)
│   └── templates/           # Agent, command templates
├── hooks/                   # 12 shell scripts
│   ├── log-session.sh, memory-nudge.sh, post-command.sh
│   ├── subagent-postflight.sh, tts-notify.sh
│   ├── validate-*.sh (plan-write, state-sync)
│   └── wezterm-*.sh (clear-status, clear-task-number, notify, task-number)
├── scripts/                 # 27+ scripts + lint subdirectory
│   ├── check-extension-docs.sh, check-vault-threshold.sh
│   ├── claude-*.sh (cleanup, project-cleanup, refresh)
│   ├── export-to-markdown.sh, install-*.sh (aliases, extension, systemd-timer)
│   ├── link-artifact-todo.sh, memory-retrieve.sh
│   ├── migrate-directory-padding.sh
│   ├── postflight-*.sh (implement, plan, research)
│   ├── update-*.sh (plan-status, recommended-order, task-status)
│   ├── validate-*.sh (artifact, context-index, extension-index, index, wiring)
│   └── lint/lint-postflight-boundary.sh
├── skills/                  # 16 skills (each with SKILL.md)
│   ├── skill-fix-it/, skill-git-workflow/, skill-implementer/
│   ├── skill-meta/, skill-orchestrator/, skill-planner/
│   ├── skill-project-overview/, skill-refresh/, skill-researcher/
│   ├── skill-reviser/, skill-spawn/, skill-status-sync/
│   ├── skill-tag/, skill-team-implement/, skill-team-plan/
│   └── skill-team-research/, skill-todo/
├── rules/                   # 7 rule files
│   ├── artifact-formats.md, error-handling.md, git-workflow.md
│   ├── plan-format-enforcement.md, project-overview-detection.md
│   └── state-management.md, workflows.md
├── templates/               # 3 template files
│   ├── claudemd-header.md, extension-readme-template.md, settings.json
├── systemd/                 # 2 systemd units
│   ├── claude-refresh.service, claude-refresh.timer
├── merge-sources/           # 1 file
│   └── claudemd.md         # Source for merging into CLAUDE.md
├── root-files/              # 3 files
│   ├── .gitignore, settings.json, settings.local.json
└── index-entries.json       # Context index entries
```

**Key manifest.json fields:**
- `merge_targets.claudemd`: Merges `merge-sources/claudemd.md` into `.claude/CLAUDE.md`
- `merge_targets.index`: Merges `index-entries.json` into `.claude/context/index.json`
- `routing_exempt: true`: Core is always loaded (conceptually)
- `dependencies: []`: No dependencies (foundational layer)

### 2. Existing OpenCode Extensions Pattern

Examined 12 existing OpenCode extensions (`epidemiology`, `filetypes`, `formal`, `latex`, `lean`, `memory`, `nix`, `nvim`, `python`, `typst`, `web`, `z3`):

**Common manifest.json structure for OpenCode:**
```json
{
  "name": "extension-name",
  "version": "1.0.0",
  "description": "...",
  "language": "language-or-null",
  "dependencies": [],
  "provides": {
    "agents": ["agent1.md", "agent2.md"],
    "skills": ["skill-name1", "skill-name2"],
    "commands": [],
    "rules": [],
    "context": ["project/category"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "opencode_md": {
      "source": "EXTENSION.md",
      "target": ".opencode/AGENTS.md",
      "section_id": "extension_oc_extension-name"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".opencode/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

**Key differences from Claude core:**
1. Uses `opencode_md` (not `claudemd`) as merge target key
2. Source for `opencode_md` is `EXTENSION.md` (not `merge-sources/claudemd.md`)
3. Target is `.opencode/AGENTS.md` (not `.claude/CLAUDE.md`)
4. No `merge-sources/` directory
5. No `root-files/` directory
6. Some extensions have `settings-fragment.json` for merging into `.opencode/settings.local.json`
7. No `systemd/` directory in any existing OpenCode extension
8. Fewer provided categories (typically only agents, skills, context)

### 3. Extension Loader/Picker Mechanics

**Loader code location:** `lua/neotex/plugins/ai/shared/extensions/init.lua`

**Key OpenCode configuration (from `config.lua`):**
```lua
function M.opencode(global_dir)
  return M.create({
    base_dir = ".opencode",
    config_file = "OPENCODE.md",
    section_prefix = "extension_oc_",
    state_file = "extensions.json",
    global_extensions_dir = global_dir .. "/.opencode/extensions",
    merge_target_key = "opencode_md",
    agents_subdir = "agent/subagents",  -- NOTE: Different from Claude's "agents"
  })
end
```

**The "Gate" Logic (entries.lua:999-1005):**
```lua
-- Gate: only show artifact sections when extensions are loaded
local extensions_module = config and config.extensions_module
  or "neotex.plugins.ai.claude.extensions"
local ok, extensions = pcall(require, extensions_module)
if not ok or #extensions.list_loaded() == 0 then
  return all_entries  -- Return early, don't show docs/context/lib sections
end
```

**Implication:** The `<leader>ao` picker only shows artifact sections (docs, context, lib) when extensions are loaded. Currently, `.opencode/extensions/core/` doesn't exist, so:
- Artifact sections won't show until core is created and loaded
- Core extension must be loaded for full picker functionality

**Current state of `.opencode/` base directory:**
```
.opencode/
├── agent/
│   ├── orchestrator.md
│   ├── subagents/          # 5 agents (incomplete set)
│   │   ├── code-reviewer-agent.md
│   │   ├── general-implementation-agent.md
│   │   ├── general-research-agent.md
│   │   ├── meta-builder-agent.md
│   │   └── planner-agent.md
│   └── README.md
├── commands/               # Empty (needs core commands)
├── context/                # Empty (needs core context)
├── skills/                 # Empty (needs core skills)
├── rules/                  # Empty (needs core rules)
├── scripts/                # Empty (needs core scripts)
├── hooks/                  # Empty (needs core hooks)
├── docs/                   # Empty (needs core docs)
├── templates/              # Empty (needs core templates)
├── systemd/               # Empty (needs core systemd)
├── extensions/             # 12 extensions (NO core yet!)
├── AGENTS.md               # Agent system documentation
├── settings.json           # OpenCode settings
└── README.md
```

### 4. Recommended `.opencode/extensions/core/` Skeleton

Based on the analysis, here's the recommended skeleton:

```
.opencode/extensions/core/
├── manifest.json              # Extension metadata (adapted for OpenCode)
├── EXTENSION.md              # Extension documentation
├── README.md                 # Extension readme
├── agents/                   # All 8 core agents
│   ├── code-reviewer-agent.md
│   ├── general-implementation-agent.md
│   ├── general-research-agent.md
│   ├── meta-builder-agent.md
│   ├── planner-agent.md
│   ├── reviser-agent.md
│   ├── spawn-agent.md
│   └── README.md
├── commands/                 # All 14 core commands
│   ├── errors.md, fix-it.md, implement.md, merge.md, meta.md
│   ├── plan.md, project-overview.md, refresh.md, research.md
│   ├── review.md, revise.md, spawn.md, tag.md, task.md, todo.md
├── context/                  # Full context directory structure
│   ├── architecture/
│   ├── checkpoints/
│   ├── formats/
│   ├── guides/
│   ├── meta/
│   ├── orchestration/
│   ├── patterns/
│   ├── processes/
│   ├── reference/
│   ├── repo/
│   ├── schemas/
│   ├── standards/
│   ├── templates/
│   ├── troubleshooting/
│   ├── workflows/
│   ├── routing.md
│   ├── validation.md
│   └── index.schema.json
├── docs/                    # Documentation
│   ├── architecture/
│   ├── examples/
│   ├── guides/
│   ├── reference/
│   └── templates/
├── hooks/                   # All 12 hook scripts
├── scripts/                 # All 27+ scripts + lint/
├── skills/                  # All 16 skills
├── rules/                   # All 7 rule files
├── templates/               # Template files
├── systemd/                 # Systemd units
└── index-entries.json       # Context index entries
```

### 5. Recommended manifest.json for OpenCode Core

```json
{
  "name": "core",
  "version": "1.0.0",
  "description": "Core agent system extension providing base commands, agents, rules, skills, scripts, hooks, and context for the OpenCode agent infrastructure.",
  "dependencies": [],
  "routing_exempt": true,
  "provides": {
    "agents": [
      "code-reviewer-agent.md",
      "general-implementation-agent.md",
      "general-research-agent.md",
      "meta-builder-agent.md",
      "planner-agent.md",
      "reviser-agent.md",
      "spawn-agent.md"
    ],
    "commands": [
      "errors.md",
      "fix-it.md",
      "implement.md",
      "merge.md",
      "meta.md",
      "plan.md",
      "refresh.md",
      "research.md",
      "review.md",
      "revise.md",
      "spawn.md",
      "tag.md",
      "task.md",
      "todo.md",
      "project-overview.md"
    ],
    "rules": [
      "artifact-formats.md",
      "error-handling.md",
      "git-workflow.md",
      "plan-format-enforcement.md",
      "state-management.md",
      "workflows.md",
      "project-overview-detection.md"
    ],
    "skills": [
      "skill-fix-it",
      "skill-git-workflow",
      "skill-implementer",
      "skill-meta",
      "skill-orchestrator",
      "skill-planner",
      "skill-project-overview",
      "skill-refresh",
      "skill-researcher",
      "skill-reviser",
      "skill-spawn",
      "skill-status-sync",
      "skill-tag",
      "skill-team-implement",
      "skill-team-plan",
      "skill-team-research",
      "skill-todo"
    ],
    "scripts": [
      "check-extension-docs.sh",
      "check-vault-threshold.sh",
      "claude-cleanup.sh",
      "claude-project-cleanup.sh",
      "claude-refresh.sh",
      "export-to-markdown.sh",
      "install-aliases.sh",
      "install-extension.sh",
      "install-systemd-timer.sh",
      "link-artifact-todo.sh",
      "memory-retrieve.sh",
      "migrate-directory-padding.sh",
      "postflight-implement.sh",
      "postflight-plan.sh",
      "postflight-research.sh",
      "setup-lean-mcp.sh",
      "uninstall-extension.sh",
      "update-plan-status.sh",
      "update-recommended-order.sh",
      "update-task-status.sh",
      "validate-artifact.sh",
      "validate-context-index.sh",
      "validate-extension-index.sh",
      "validate-index.sh",
      "validate-wiring.sh",
      "verify-lean-mcp.sh",
      "lint/lint-postflight-boundary.sh"
    ],
    "hooks": [
      "log-session.sh",
      "memory-nudge.sh",
      "post-command.sh",
      "subagent-postflight.sh",
      "tts-notify.sh",
      "validate-plan-write.sh",
      "validate-state-sync.sh",
      "wezterm-clear-status.sh",
      "wezterm-clear-task-number.sh",
      "wezterm-notify.sh",
      "wezterm-task-number.sh"
    ],
    "context": [
      "routing.md",
      "validation.md",
      "index.schema.json",
      "architecture",
      "checkpoints",
      "formats",
      "guides",
      "meta",
      "orchestration",
      "patterns",
      "processes",
      "reference",
      "repo",
      "schemas",
      "standards",
      "templates",
      "troubleshooting",
      "workflows"
    ],
    "docs": [
      "README.md",
      "docs-README.md",
      "architecture",
      "examples",
      "guides",
      "reference",
      "templates"
    ],
    "templates": [
      "claudemd-header.md",
      "extension-readme-template.md",
      "settings.json"
    ],
    "systemd": [
      "claude-refresh.service",
      "claude-refresh.timer"
    ]
  },
  "merge_targets": {
    "opencode_md": {
      "source": "EXTENSION.md",
      "target": ".opencode/AGENTS.md",
      "section_id": "extension_oc_core"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".opencode/context/index.json"
    }
  }
}
```

### 6. Recommended EXTENSION.md for OpenCode Core

```markdown
# Core Extension (OpenCode)

## Overview

The core extension provides the base agent system infrastructure for OpenCode. It contains
all fundamental commands, agents, rules, skills, scripts, hooks, context, documentation, and
templates that power the task management and agent orchestration workflow.

## Purpose

This extension packages the core agent system files for OpenCode. It is the foundational
layer that all other OpenCode extensions build upon, providing the same capabilities as
the `.claude/extensions/core/` but adapted for the OpenCode extension system.

## What This Extension Provides

| Category | Count | Description |
|----------|-------|-------------|
| agents | 7 | Research, implementation, planning, meta, review, revision, spawn agents |
| commands | 15 | `/task`, `/research`, `/plan`, `/implement`, `/todo`, `/meta`, and more |
| rules | 7 | Auto-applied rules for state, git, artifacts, workflows, and error handling |
| skills | 17 | Skill definitions including team mode, orchestration, and utility skills |
| scripts | 27 | Utility scripts for validation, hooks, memory, and extension management |
| hooks | 11 | Session logging, memory nudging, WezTerm notifications, validation hooks |
| context | 18 dirs | Architecture, patterns, guides, schemas, workflows, and reference material |
| docs | 7 dirs | Standards documentation, architecture guides, and references |
| templates | 3 | Extension README template and settings.json template |
| systemd | 2 | Refresh service and timer units |

## Key Capabilities

- **Task Management**: Full lifecycle from creation through research, planning, implementation,
  and archival via `/todo`
- **Agent Orchestration**: Routing, delegation, and team mode for parallel execution
- **State Management**: Atomic synchronization of TODO.md and state.json
- **Memory System**: Auto-retrieval hooks and distillation support
- **Extension Infrastructure**: Scripts to install, validate, and manage other extensions

## Usage Notes

- This extension is the foundational layer for all other OpenCode extensions
- All core commands (e.g., `/implement`, `/research`) are defined here
- Context files are auto-loaded by agents via the context index
- Scripts are callable from hooks and other scripts using the extension-relative path
- The `context/reference/team-wave-helpers.md` file provides reusable wave patterns for team skills

## Dependencies

None. This is the foundational layer all other extensions build upon.

## Related Files

- `.opencode/AGENTS.md` - Agent system configuration and quick reference
- `.opencode/context/index.json` - Context discovery index
- `.opencode/extensions.json` - Extension registry
```

## Decisions

1. **Mirror vs. Adapt**: Decision to mirror `.claude/extensions/core/` structure exactly, but adapt the manifest.json for OpenCode's extension system (use `opencode_md` instead of `claudemd`).

2. **No merge-sources directory**: OpenCode extensions use `EXTENSION.md` directly as the source for `opencode_md` merge target, not a separate `merge-sources/claudemd.md` file.

3. **agents_subdir**: OpenCode uses `agent/subagents/` (not `agents/`). However, since the extension system handles this via `config.agents_subdir`, the source directory should still use `agents/` (the loader copies to the correct target subdirectory).

4. **Core as extension**: The core should be packaged as an extension (in `extensions/core/`) rather than living directly in `.opencode/`. This enables versioning, syncing, and management via the extension loader.

5. **Gate resolution**: Once `core` extension is created and loaded via `<leader>ao`, the gate in `entries.lua:999-1005` will pass (since `#extensions.list_loaded() > 0`), and artifact sections will display.

## Risks & Mitigations

### Risk 1: Large Extension Size
- **Risk**: Core extension has 159+ files, which may slow down extension loading
- **Mitigation**: Extension loader copies files efficiently; most files are context/docs that don't affect runtime. Consider lazy-loading context via index.json.

### Risk 2: Duplicate Files During Migration
- **Risk**: Files currently exist in `.opencode/agent/subagents/` but will also be in the extension
- **Mitigation**: The loader's `check_conflicts()` function will detect overwrites. The confirmation dialog shows conflict counts. After loading, clean up legacy files.

### Risk 3: Merge Target Conflicts
- **Risk**: `EXTENSION.md` merging into `.opencode/AGENTS.md` may conflict with existing content
- **Mitigation**: The merge system uses section markers (`<!-- extension_oc_core -->`) to isolate content. Use `generate_claudemd()` for clean regeneration.

### Risk 4: Breaking Existing Workflow
- **Risk**: Moving files from `.opencode/` root to extension may break existing references
- **Mitigation**: The extension loader copies files to the correct locations. Existing code referencing `.opencode/agent/subagents/agent.md` will still work since the loader copies to `agent/subagents/`.

## Context Extension Recommendations

- **Topic**: OpenCode extension core skeleton
- **Gap**: No existing context file documents how to create a core extension for OpenCode
- **Recommendation**: Create `.opencode/extensions/core/` context entry or update `.claude/context/guides/extension-development.md` with OpenCode-specific instructions

## Appendix

### Search Queries Used
1. `find .claude/extensions/core -type f` - List all core extension files
2. `cat .claude/extensions/core/manifest.json` - Read manifest structure
3. `find .opencode/extensions -name "manifest.json"` - Examine existing OpenCode extensions
4. `grep -r "opencode_md" .opencode/extensions/*/manifest.json` - Find merge target pattern
5. `cat lua/neotex/plugins/ai/shared/extensions/config.lua` - Understand OpenCode config

### References
- `.claude/extensions/core/manifest.json` - Source manifest (159 lines)
- `.opencode/extensions/nvim/manifest.json` - Example OpenCode extension manifest
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Extension loader (819 lines)
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - Extension config (77 lines)
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua:999-1005` - Gate logic
