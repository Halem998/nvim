# Implementation Plan: Task #99

- **Task**: 99 - review_agent_systems_core_extensions
- **Status**: [NOT STARTED]
- **Effort**: 14-18 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md), [research-003.md](../reports/research-003.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Design and implement a core + extensions architecture for the .claude/ agent system using a hybrid approach: direct file integration for core additions combined with Claude Code native plugins for domain-specific extensions. Research-001 identified 22 general-purpose features missing from nvim. Research-002 designed a file-copying extension loader with `<leader>ae` picker. Research-003 discovered that Claude Code's native plugin system handles commands, skills, agents, hooks, and MCP servers natively, reducing custom infrastructure needs. This plan synthesizes all three: core gaps are filled directly, domain extensions use native plugins where possible and file-copying for components plugins cannot handle (rules, context files), and `<leader>ae` manages both modes.

### Research Integration

Three research reports inform this plan:

- **research-001.md** (v1): Compared three .claude/ systems, identified 22 missing core features in categories: reference docs (6), progress/recovery (4), team orchestration (5), utilities (5), MCP resilience (2). Categorized all differences into core (A), domain extensions (B), and project-specific (C).

- **research-002.md** (v2): Designed file-copying extension mechanism with manifest-based tracking. Analyzed existing sync.lua/parser.lua/scan.lua infrastructure. Recommended `<leader>ae` submenu under existing `<leader>a` group. Designed registry.json for installed-file tracking, settings fragment merging, and CLAUDE.md section markers.

- **research-003.md** (v3): Analyzed Claude Code native plugin system. Found plugins support commands, skills, agents, hooks, MCP, LSP natively but NOT rules or context files. Recommended hybrid: native plugins for discoverable components, file-copying for rules/context. Identified local marketplace as personal extension distribution mechanism.

## Goals & Non-Goals

**Goals**:
- Add all 22 identified missing core context files to nvim/.claude/
- Create native Claude Code plugin packages for domain extensions (Lean, LaTeX, Typst)
- Create a local marketplace structure for personal plugin distribution
- Implement file-copying integration for components plugins cannot handle (rules, context)
- Build `<leader>ae` Telescope picker for extension management (plugin toggles + context sync)
- Update CLAUDE.md and index.json to reflect the expanded core system
- Maintain full backward compatibility with existing workflows

**Non-Goals**:
- Migrating ProofChecker or Theory to use the new architecture (separate tasks)
- Publishing plugins to public marketplaces
- Building a full plugin development toolkit
- Implementing hot-reload for plugin changes (session restart is acceptable)
- Creating every possible domain plugin (focus on Lean as reference implementation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plugin namespace prefix changes command names (`/lean-ext:lake` vs `/lake`) | Medium | High | Use short plugin names; document namespaced invocation; users can also use `--plugin-dir` for non-namespaced loading |
| Session restart required after plugin enable/disable | Medium | Certain | Display clear notification in picker; investigate if `--plugin-dir` can avoid restart for development |
| Rules and context cannot be plugin-packaged natively | Medium | Certain | Hybrid approach: embed rules in agent prompts, bundle context as skill references, file-copy remaining items |
| Adding 22 core context files bloats agent context loading | Medium | Medium | Register in index.json with proper load_when filters; agents only load relevant files |
| Plugin system API changes in future Claude Code versions | Low | Low | Pin marketplace versions; plugin.json schema is stable; test updates |
| File-copy sync divergence from source | Medium | Medium | Track checksums in registry; warn on overwrite of locally modified files |
| Team orchestration skills conflict with existing workflows | Medium | Low | Phase 3 is additive only; skills are invoked explicitly, never automatically |

## Implementation Phases

### Phase 1: Core Reference Documentation [NOT STARTED]

**Goal**: Add the 6 high-priority reference documentation files identified as missing from nvim core context. Pure additions that improve agent effectiveness with zero risk to existing behavior.

**Tasks**:
- [ ] Create `context/core/reference/command-reference.md` -- full command reference with all flags and modes (adapt from ProofChecker)
- [ ] Create `context/core/reference/state-json-schema.md` -- complete state.json schema documentation
- [ ] Create `context/core/reference/error-recovery-procedures.md` -- detailed recovery procedures for all error types
- [ ] Create `context/core/reference/skill-agent-mapping.md` -- skill-to-agent mapping quick reference
- [ ] Create `context/core/reference/artifact-templates.md` -- template collection for all artifact types
- [ ] Create `context/core/formats/metadata-quick-ref.md` -- condensed metadata schema reference (131 lines vs 250+ in full schema)
- [ ] Update `context/index.json` with entries for all 6 new files (with appropriate load_when conditions)

**Timing**: 2 hours

**Files to create/modify**:
- `.claude/context/core/reference/command-reference.md` -- new
- `.claude/context/core/reference/state-json-schema.md` -- new
- `.claude/context/core/reference/error-recovery-procedures.md` -- new
- `.claude/context/core/reference/skill-agent-mapping.md` -- new
- `.claude/context/core/reference/artifact-templates.md` -- new
- `.claude/context/core/formats/metadata-quick-ref.md` -- new
- `.claude/context/index.json` -- update

**Verification**:
- All 6 files exist with substantive content adapted from ProofChecker
- Each file registered in index.json with appropriate load_when conditions
- `validate-context-index.sh` passes
- Existing agent behavior unchanged

---

### Phase 2: Progress, Recovery, and Utility Infrastructure [NOT STARTED]

**Goal**: Add the remaining 12 core context files covering progress tracking, recovery infrastructure, utility improvements, and MCP resilience patterns. Also port 2 utility scripts from ProofChecker.

**Tasks**:
- [ ] Create `context/core/formats/progress-file.md` -- phase-level incremental progress tracking
- [ ] Create `context/core/formats/handoff-artifact.md` -- context exhaustion recovery via structured handoff documents
- [ ] Create `context/core/formats/debug-report-format.md` -- debug hypothesis-analysis-resolution cycle format
- [ ] Create `context/core/formats/changelog-format.md` -- CHANGE_LOG.md structure for permanent work history
- [ ] Create `context/core/utils/index-query.md` -- programmatic index.json query patterns with jq
- [ ] Create `context/core/standards/git-staging-scope.md` -- per-agent git staging scopes to prevent race conditions
- [ ] Create `context/core/templates/context-knowledge-template.md` -- knowledge extraction template for research agents
- [ ] Create `context/core/patterns/mcp-tool-recovery.md` -- defensive patterns for MCP tool failure recovery
- [ ] Create `context/core/patterns/blocked-mcp-tools.md` -- blocked MCP tool reference template
- [ ] Create `context/core/patterns/roadmap-reflection-pattern.md` -- prevents recommending documented dead ends
- [ ] Port `scripts/generate-context-index.sh` from ProofChecker (adapt paths for nvim project)
- [ ] Port `scripts/update-plan-status.sh` from ProofChecker (adapt paths for nvim project)
- [ ] Update `context/index.json` with entries for all 10 new context files

**Timing**: 2-3 hours

**Files to create/modify**:
- `.claude/context/core/formats/progress-file.md` -- new
- `.claude/context/core/formats/handoff-artifact.md` -- new
- `.claude/context/core/formats/debug-report-format.md` -- new
- `.claude/context/core/formats/changelog-format.md` -- new
- `.claude/context/core/utils/index-query.md` -- new
- `.claude/context/core/standards/git-staging-scope.md` -- new
- `.claude/context/core/templates/context-knowledge-template.md` -- new
- `.claude/context/core/patterns/mcp-tool-recovery.md` -- new
- `.claude/context/core/patterns/blocked-mcp-tools.md` -- new
- `.claude/context/core/patterns/roadmap-reflection-pattern.md` -- new
- `.claude/scripts/generate-context-index.sh` -- new (ported)
- `.claude/scripts/update-plan-status.sh` -- new (ported)
- `.claude/context/index.json` -- update

**Verification**:
- All 10 context files exist with substantive content
- Both scripts are executable (`chmod +x`) and produce correct output
- index.json validates with `validate-context-index.sh`
- No regressions in existing agent workflows

---

### Phase 3: Team Orchestration Skills [NOT STARTED]

**Goal**: Port the 3 team orchestration skills from ProofChecker and their supporting context files. These enable multi-agent parallel execution and are general-purpose infrastructure that benefits any project type.

**Tasks**:
- [ ] Create `skills/skill-team-research/SKILL.md` -- parallel multi-agent research orchestration
- [ ] Create `skills/skill-team-plan/SKILL.md` -- parallel multi-agent planning orchestration
- [ ] Create `skills/skill-team-implement/SKILL.md` -- parallel multi-agent implementation with debug cycles
- [ ] Create `context/core/formats/team-metadata-extension.md` -- team result schema for multi-agent coordination
- [ ] Create `context/core/patterns/team-orchestration.md` -- wave-based multi-agent coordination patterns
- [ ] Update `context/index.json` with team context file entries
- [ ] Update `.claude/CLAUDE.md` Skill-to-Agent Mapping table with team skills

**Timing**: 2 hours

**Files to create/modify**:
- `.claude/skills/skill-team-research/SKILL.md` -- new
- `.claude/skills/skill-team-plan/SKILL.md` -- new
- `.claude/skills/skill-team-implement/SKILL.md` -- new
- `.claude/context/core/formats/team-metadata-extension.md` -- new
- `.claude/context/core/patterns/team-orchestration.md` -- new
- `.claude/context/index.json` -- update
- `.claude/CLAUDE.md` -- update Skill-to-Agent Mapping table

**Verification**:
- All 3 skill directories exist with valid SKILL.md files following established frontmatter format
- Both context files contain substantive patterns
- CLAUDE.md Skill-to-Agent Mapping table includes team skills
- Skills reference correct agent types and tools

---

### Phase 4: Extension Directory and Plugin Packaging [NOT STARTED]

**Goal**: Create the extension directory structure and package the Lean domain as a native Claude Code plugin. This is the reference implementation that demonstrates the hybrid architecture: native plugin for commands/skills/agents/hooks/MCP, plus a supplementary context pack for rules and context files.

**Tasks**:
- [ ] Create `.claude/extensions/` directory with README.md documenting the architecture
- [ ] Create `.claude/extensions/lean/` as a native Claude Code plugin:
  - [ ] `.claude/extensions/lean/.claude-plugin/plugin.json` -- plugin manifest
  - [ ] `.claude/extensions/lean/commands/lake.md` -- lake build command
  - [ ] `.claude/extensions/lean/commands/lean.md` -- lean toolchain management
  - [ ] `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` -- lean research skill (embed context as skill references)
  - [ ] `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` -- lean implementation skill
  - [ ] `.claude/extensions/lean/skills/skill-lake-repair/SKILL.md` -- lake auto-repair skill
  - [ ] `.claude/extensions/lean/skills/skill-lean-version/SKILL.md` -- lean version management skill
  - [ ] `.claude/extensions/lean/agents/lean-research-agent.md` -- embed lean4.md rule content in agent prompt
  - [ ] `.claude/extensions/lean/agents/lean-implementation-agent.md` -- embed lean4.md rule content in agent prompt
  - [ ] `.claude/extensions/lean/scripts/setup-lean-mcp.sh` -- MCP setup
  - [ ] `.claude/extensions/lean/scripts/verify-lean-mcp.sh` -- MCP verification
  - [ ] `.claude/extensions/lean/.mcp.json` -- lean-lsp MCP server config
- [ ] Create `.claude/extensions/lean/context/` supplementary pack:
  - [ ] Copy lean4 context files for file-copy integration (rules, domain knowledge)
  - [ ] Create `manifest.json` describing supplementary components
- [ ] Test plugin with `claude --plugin-dir .claude/extensions/lean` in a scratch project

**Timing**: 2-3 hours

**Files to create/modify**:
- `.claude/extensions/README.md` -- new (architecture documentation)
- `.claude/extensions/lean/.claude-plugin/plugin.json` -- new
- `.claude/extensions/lean/commands/lake.md` -- new (adapted from ProofChecker)
- `.claude/extensions/lean/commands/lean.md` -- new (adapted from ProofChecker)
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` -- new
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` -- new
- `.claude/extensions/lean/skills/skill-lake-repair/SKILL.md` -- new
- `.claude/extensions/lean/skills/skill-lean-version/SKILL.md` -- new
- `.claude/extensions/lean/agents/lean-research-agent.md` -- new
- `.claude/extensions/lean/agents/lean-implementation-agent.md` -- new
- `.claude/extensions/lean/scripts/setup-lean-mcp.sh` -- new
- `.claude/extensions/lean/scripts/verify-lean-mcp.sh` -- new
- `.claude/extensions/lean/.mcp.json` -- new
- `.claude/extensions/lean/context/manifest.json` -- new
- `.claude/extensions/lean/context/` -- context files (new)

**Verification**:
- `claude --plugin-dir .claude/extensions/lean` loads without errors
- Plugin commands appear as `/lean-ext:lake` and `/lean-ext:lean` (or whatever name chosen)
- Skills and agents are discoverable by Claude Code
- Context supplementary pack has valid manifest listing all files
- README.md documents the hybrid architecture clearly

---

### Phase 5: Extension Loader and Registry [NOT STARTED]

**Goal**: Build the Lua-based extension loader that handles the hybrid approach: toggling `enabledPlugins` in settings.json for native plugin components, and file-copying for supplementary context/rules. Create the registry system that tracks what is installed.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/loader.lua` -- core extension loading engine:
  - Read extension manifest (both plugin.json and context/manifest.json)
  - Toggle `enabledPlugins` in `.claude/settings.local.json` for plugin components
  - Copy/remove context files and rules for supplementary components
  - Track installed supplementary files in registry
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/registry.lua` -- extension state tracking:
  - Read/write `.claude/extensions/registry.json`
  - Track active/inactive extensions
  - Track installed supplementary files (paths + checksums)
  - Detect modified files before overwrite
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/scanner.lua` -- extension discovery:
  - Scan `.claude/extensions/` for available extensions
  - Read plugin.json and context/manifest.json
  - Report extension status (active/inactive, dependencies)
- [ ] Create `.claude/extensions/registry.json` -- initial registry state
- [ ] Create index.json integration: function to append/remove extension context entries

**Timing**: 2-3 hours

**Files to create/modify**:
- `lua/neotex/plugins/ai/claude/extensions/loader.lua` -- new
- `lua/neotex/plugins/ai/claude/extensions/registry.lua` -- new
- `lua/neotex/plugins/ai/claude/extensions/scanner.lua` -- new
- `.claude/extensions/registry.json` -- new (initial state)

**Verification**:
- `require("neotex.plugins.ai.claude.extensions.loader")` loads without errors in nvim
- Loader can activate lean extension: settings.local.json updated, context files copied
- Loader can deactivate lean extension: settings.local.json updated, context files removed
- Registry tracks state correctly across activate/deactivate cycles
- Activate-deactivate-activate cycle leaves system in correct state (idempotent)
- Modified supplementary files trigger warning before overwrite

---

### Phase 6: Extension Picker UI [NOT STARTED]

**Goal**: Create the `<leader>ae` Telescope picker for extension management. This provides the user-facing interface for browsing, activating, and deactivating extensions.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/claude/extensions/picker.lua` -- Telescope picker:
  - List available extensions from scanner
  - Show active/inactive status with visual indicators
  - Display extension description and language tag
  - Show dependency information in preview pane
  - Actions: Enter (toggle), Ctrl-i (details), Ctrl-r (reload)
- [ ] Register `<leader>ae` keybinding in which-key under `<leader>a` (ai) group
- [ ] Display notification when session restart is needed after plugin toggle
- [ ] Add fallback to `vim.ui.select` when Telescope is not available

**Timing**: 1.5-2 hours

**Files to create/modify**:
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` -- new
- `lua/neotex/plugins/ai/claude/commands/init.lua` or keymap registration file -- update
- Which-key configuration -- update (add `<leader>ae` entry)

**Verification**:
- `<leader>ae` opens Telescope picker showing available extensions
- Toggling an extension updates both settings.local.json and context files
- Status indicators accurately reflect active/inactive state
- Notification appears when session restart is needed
- Picker displays dependency warnings when deactivating an extension with dependents
- Existing `<leader>ac` behavior is completely unchanged

---

### Phase 7: Additional Extension Packs and Documentation [NOT STARTED]

**Goal**: Create extension manifests for LaTeX, Typst, and Neovim domains. Update CLAUDE.md documentation to describe the new architecture. Create the local marketplace structure.

**Tasks**:
- [ ] Create `.claude/extensions/neovim/` plugin pack:
  - `.claude-plugin/plugin.json` -- Neovim extension manifest
  - Skills: skill-neovim-research, skill-neovim-implementation
  - Agents: neovim-research-agent, neovim-implementation-agent
  - Context supplementary: neovim rules, context files
  - Mark as active by default in registry for nvim project
- [ ] Create `.claude/extensions/latex/` plugin pack:
  - `.claude-plugin/plugin.json` -- LaTeX extension manifest
  - Skills: skill-latex-research (missing from nvim, in ProofChecker)
  - Agents: latex-research-agent (missing from nvim)
  - Context supplementary: latex rules, context files
- [ ] Create `.claude/extensions/typst/` plugin pack:
  - `.claude-plugin/plugin.json` -- Typst extension manifest
  - Skills: skill-typst-research (missing from nvim, in Theory)
  - Agents: typst-research-agent (missing from nvim)
  - Context supplementary: typst rules, context files
- [ ] Create local marketplace structure:
  - `.claude/extensions/.claude-plugin/marketplace.json` -- marketplace manifest
  - Document marketplace registration: `/plugin marketplace add <path>`
- [ ] Update `.claude/CLAUDE.md`:
  - Add Extension Architecture section with directory structure
  - Add Extension Management subsection documenting `<leader>ae`
  - Update Project Structure to show extensions/
  - Update Skill-to-Agent Mapping for new domain skills
- [ ] Create `.claude/docs/guides/extension-management.md` -- comprehensive user guide
- [ ] Update root `CLAUDE.md` with extension architecture overview

**Timing**: 2-3 hours

**Files to create/modify**:
- `.claude/extensions/neovim/.claude-plugin/plugin.json` -- new
- `.claude/extensions/neovim/skills/` -- new (move existing)
- `.claude/extensions/neovim/agents/` -- new (move existing)
- `.claude/extensions/neovim/context/` -- new (supplementary)
- `.claude/extensions/latex/.claude-plugin/plugin.json` -- new
- `.claude/extensions/latex/skills/` -- new
- `.claude/extensions/latex/agents/` -- new
- `.claude/extensions/typst/.claude-plugin/plugin.json` -- new
- `.claude/extensions/typst/skills/` -- new
- `.claude/extensions/typst/agents/` -- new
- `.claude/extensions/.claude-plugin/marketplace.json` -- new
- `.claude/CLAUDE.md` -- update
- `.claude/docs/guides/extension-management.md` -- new
- `CLAUDE.md` (root) -- update

**Verification**:
- All 3 additional plugin packs have valid plugin.json manifests
- Neovim extension is marked active by default in registry
- `<leader>ae` picker shows all 4 extensions (lean, neovim, latex, typst)
- Local marketplace structure is valid (tested with `--plugin-dir` if possible)
- CLAUDE.md accurately documents the new architecture
- Extension management guide covers: activation, deactivation, creating new extensions, troubleshooting
- All existing commands and workflows continue to function

## Testing & Validation

- [ ] All 22 missing core context files exist and contain substantive content
- [ ] index.json passes validation with all new entries (`validate-context-index.sh`)
- [ ] Team orchestration skills follow established SKILL.md frontmatter format
- [ ] Lean plugin loads successfully with `claude --plugin-dir .claude/extensions/lean`
- [ ] Extension loader activate/deactivate cycle is idempotent
- [ ] `<leader>ae` picker renders correctly in Neovim with Telescope
- [ ] `<leader>ae` fallback works with vim.ui.select when Telescope unavailable
- [ ] settings.local.json is updated correctly on plugin toggle
- [ ] Supplementary context files are copied/removed cleanly on toggle
- [ ] Registry tracks all installed files accurately
- [ ] No regressions in existing `<leader>ac` picker behavior
- [ ] No regressions in existing command workflows (/task, /research, /plan, /implement)
- [ ] ProofChecker system can be expressed as "core + lean extension" (design validation)

## Artifacts & Outputs

- 22 new core context files in `.claude/context/core/`
- 3 team orchestration skills in `.claude/skills/`
- 2 ported utility scripts in `.claude/scripts/`
- 4 extension plugin packs (lean, neovim, latex, typst) in `.claude/extensions/`
- 1 local marketplace manifest in `.claude/extensions/.claude-plugin/`
- 3 Neovim Lua modules (loader, registry, scanner) in `lua/neotex/plugins/ai/claude/extensions/`
- 1 Telescope picker module in `lua/neotex/plugins/ai/claude/extensions/`
- 1 extension management guide in `.claude/docs/guides/`
- Updated CLAUDE.md documentation (both root and .claude/)
- Implementation summary at `specs/099_review_agent_systems_core_extensions/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

**Phases 1-3** are purely additive (new files only). Rollback by deleting new files and reverting index.json/CLAUDE.md changes. Zero risk to existing behavior.

**Phase 4** creates a new directory structure (`.claude/extensions/`). Rollback by removing the directory. No existing files are modified.

**Phase 5** adds new Lua modules. Rollback by removing the `lua/neotex/plugins/ai/claude/extensions/` directory. No existing Lua modules are modified.

**Phase 6** adds a new keybinding and picker. Rollback by removing the picker module and keybinding registration. Existing `<leader>ac` is never modified.

**Phase 7** modifies CLAUDE.md and adds documentation. Rollback uses `git checkout` on modified files and removal of new extension packs.

If the native plugin approach proves problematic (API changes, namespace friction), the fallback is to use the file-copying-only approach from research-002 for all components, which is fully self-contained and has no external dependencies.
