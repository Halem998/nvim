# Research Report: Task #116

**Task**: 116 - Verify OpenCode & Implement Extension Parity
**Started**: 2026-03-02
**Completed**: 2026-03-02
**Effort**: 3-5 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of .claude/extensions/, .opencode/extensions/, and /home/benjamin/Projects/ModelChecker/.opencode/
**Artifacts**: specs/116_verify_opencode_implement_extension_parity/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The ModelChecker/.opencode/ directory copy is **largely complete** for the core agent system, but has significant gaps in extension parity
- The formal/ and lean/ extensions were installed to ModelChecker but are **incomplete versions** compared to their .claude counterparts
- There are **7 extensions in .claude/ that have no .opencode/extensions/ equivalent**: document-converter, latex, nix, python, typst, web, z3
- The .opencode formal extension is missing 3 specialized agents (logic, math, physics), 3 skills, and all context files (41 files)
- The .opencode lean extension is missing commands, scripts, settings-fragment, 2 skills, and all context files (27 files)

## Context & Scope

This research investigates:
1. Whether /home/benjamin/Projects/ModelChecker/.opencode/ has all files from the source ~/.config/nvim/.opencode/
2. Whether formal/ and lean/ extensions were properly copied
3. What extensions exist in .claude/ that need .opencode/ equivalents
4. Gaps and recommendations for achieving full feature parity

## Findings

### 1. ModelChecker .opencode/ Base Directory Completeness

The base copy from source .opencode/ to ModelChecker/.opencode/ is **mostly complete** with the following differences:

**Files in source but not in target (expected omissions)**:
- `bun.lock` - Package manager lockfile (not needed in target)
- `package.json` - Package config (not needed in target)
- `context/core/checkpoints/.placeholder` - Empty placeholder
- `scripts/.gitkeep` - Git keepfile
- `scripts/test-results.md` - Test output (ephemeral)
- `specs/state.json` - Task state (project-specific)
- `specs/TODO.md` - Task list (project-specific)
- `templates/settings.json` - Template file

**Files in source but not in target (potentially missing)**:
- `context/core/patterns/command-execution.sh` - Shell script patterns
- `context/core/patterns/command-integration.sh` - Shell script patterns
- `context/core/patterns/core-command-execution.sh` - Shell script patterns
- `context/core/patterns/lean-command-execution.sh` - Lean-specific patterns
- `context/project/repo/project-overview.md` - Project-specific (needs target regeneration)
- `context/project/repo/self-healing-implementation-details.md` - Project-specific

**Files in target but not in source (installed by extensions)**:
- `agents/formal-research-agent.md` - Installed by formal extension
- `agents/lean-implementation-agent.md` - Installed by lean extension
- `agents/lean-research-agent.md` - Installed by lean extension
- `skills/skill-formal-research/SKILL.md` - Installed by formal extension
- `context/index.json.backup` - Backup from extension installation
- `extensions.json` - Extension tracking metadata
- `OPENCODE.md.backup` - Backup from extension installation

The extra files in the target are correct - they were installed by the formal and lean extension loading process.

### 2. Formal Extension Parity Analysis

#### .claude/extensions/formal/ (source of truth)
- **4 agents**: formal-research-agent, logic-research-agent, math-research-agent, physics-research-agent
- **4 skills**: skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research
- **41 context files**: Covering logic/, math/, and physics/ domains
- **Index entries**: 30+ entries with load_when metadata

#### .opencode/extensions/formal/ (current state)
- **1 agent**: formal-research-agent only
- **1 skill**: skill-formal-research only
- **0 context files**: Empty context directory (not included in extension)
- **Index entries**: Empty `{"entries": []}`

#### Gap Analysis
| Component | .claude | .opencode | Missing |
|-----------|---------|-----------|---------|
| Agents | 4 | 1 | logic-research, math-research, physics-research |
| Skills | 4 | 1 | skill-logic-research, skill-math-research, skill-physics-research |
| Context files | 41 | 0 | All logic/, math/, physics/ context |
| Index entries | 30+ | 0 | All entries |

**Note**: The .opencode base system already has logic and math context files baked into `context/project/logic/` and `context/project/math/` (pre-extension era). However, these are **older versions** that diverge from the .claude extension versions. The .claude formal extension has additional files:
- `logic/domain/lattice-theory-concepts.md` (not in .opencode base)
- `logic/domain/mereology-foundations.md` (not in .opencode base)
- `logic/domain/spatial-domain.md` (not in .opencode base)
- `logic/domain/topological-foundations-domain.md` (not in .opencode base)
- `math/category-theory/basics.md` vs `category-basics.md` (different files)
- `math/category-theory/cauchy-completion.md` (not in .opencode base)
- `math/category-theory/enriched-categories.md` (not in .opencode base)
- `math/category-theory/lawvere-metric-spaces.md` (not in .opencode base)
- `math/category-theory/profunctors.md` (not in .opencode base)
- `math/foundations/dependent-type-theory.md` vs `set-theory-foundations.md` (different files)
- `math/lattice-theory/bilattice-theory.md` (not in .opencode base)
- `math/order-theory/monoidal-posets.md` (not in .opencode base)
- `math/topology/scott-topology.md` (not in .opencode base)
- Entire `physics/` directory (not in .opencode base)

### 3. Lean Extension Parity Analysis

#### .claude/extensions/lean/ (source of truth)
- **2 agents**: lean-research-agent, lean-implementation-agent
- **4 skills**: skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version
- **2 commands**: lake.md, lean.md
- **1 rule**: lean4.md
- **27 context files**: Full lean4/ domain knowledge
- **2 scripts**: setup-lean-mcp.sh, verify-lean-mcp.sh
- **1 settings fragment**: settings-fragment.json

#### .opencode/extensions/lean/ (current state)
- **2 agents**: lean-research-agent, lean-implementation-agent (present)
- **2 skills**: skill-lean-research, skill-lean-implementation
- **0 commands**: Missing lake.md, lean.md
- **1 rule**: lean4.md (present)
- **0 context files**: Not included in extension
- **0 scripts**: Missing setup/verify scripts
- **0 settings fragments**: Missing

#### Gap Analysis
| Component | .claude | .opencode | Missing |
|-----------|---------|-----------|---------|
| Agents | 2 | 2 | None |
| Skills | 4 | 2 | skill-lake-repair, skill-lean-version |
| Commands | 2 | 0 | lake.md, lean.md |
| Rules | 1 | 1 | None |
| Context files | 27 | 0 | All lean4/ context |
| Scripts | 2 | 0 | setup-lean-mcp.sh, verify-lean-mcp.sh |
| Settings | 1 | 0 | settings-fragment.json |

**Note**: The .opencode base system already has lean4 context baked into `context/project/lean4/` but the .claude extension has an additional file: `operations/multi-instance-optimization.md`. The lean commands (lake.md, lean.md) are already baked into the .opencode base commands/ but NOT into the extension itself.

### 4. Extensions Missing from .opencode Entirely

These .claude extensions have **no .opencode equivalent** at all:

| Extension | Agents | Skills | Commands | Rules | Context Files | MCP Servers |
|-----------|--------|--------|----------|-------|---------------|-------------|
| document-converter | 1 | 1 | 1 (convert.md) | 0 | 0 | 0 |
| latex | 2 | 2 | 0 | 1 | 10 | 0 |
| nix | 2 | 2 | 0 | 1 | 12 | 1 (mcp-nixos) |
| python | 2 | 2 | 0 | 0 | 6 | 0 |
| typst | 2 | 2 | 0 | 0 | 12 | 0 |
| web | 2 | 2 | 0 | 1 | 20 | 0 |
| z3 | 2 | 2 | 0 | 0 | 5 | 0 |

**Important nuance**: Several of these extension capabilities are already **baked into the .opencode base system** as core features rather than extensions:

- **document-converter**: Agent, skill, and command already in base .opencode
- **latex**: Agents, skills, rule, and context already in base .opencode
- **typst**: Agents, skills, and context already in base .opencode (with different files than .claude version)
- **web**: Context already in base .opencode (agents/skills NOT in base)

These were baked in before the extension architecture was fully implemented in .opencode.

### 5. Architecture Differences

#### Extension Loading Mechanism
- **.claude**: Extensions provide EXTENSION.md that merges into CLAUDE.md via section markers. Each extension has a manifest.json with structured `provides` and `merge_targets`.
- **.opencode**: Same architecture exists but with `opencode_md` merge target instead of `claudemd`. The extension loading to ModelChecker created `extensions.json` tracking installed files.

#### Context Organization
- **.claude**: Core agents/skills in base, domain context lives ONLY in extensions (clean separation)
- **.opencode**: Domain context (logic, math, lean4, latex, typst, web, neovim) baked into base `context/project/`, PLUS some in extensions. This creates **overlap** where the same domain has context both in the base and potentially in extensions.

#### Extension Content Distribution
- **.claude**: Each extension bundles its own context files, leading to self-contained packages
- **.opencode**: Extensions contain mainly agents/skills/rules but delegate context to the base system (incomplete approach)

## Decisions

1. The .opencode extension system needs to adopt the .claude pattern where extensions bundle their own context files
2. Missing extensions should be created as proper .opencode/extensions/ packages with full content
3. The baked-in content in .opencode base for latex, typst, web, and document-converter creates a migration challenge - the extension should supersede the baked-in content

## Risks & Mitigations

1. **Context file divergence**: The .opencode base logic/ and math/ context files are older versions that differ from the .claude formal extension. Risk: Conflicting information when extension is loaded.
   - Mitigation: Extension context should replace base context files, or base context should be removed for extension-managed domains.

2. **MCP server configuration**: The nix and lean extensions reference MCP servers (mcp-nixos, lean-lsp) that may not be available in OpenCode.
   - Mitigation: Make MCP server entries optional or provide alternative tool access patterns.

3. **Baked-in vs extension overlap**: Several domains exist both as baked-in base content and as potential extensions.
   - Mitigation: Choose one canonical location (prefer extensions for modularity), deprecate baked-in copies.

## Implementation Recommendations

### Priority 1: Fix Existing Extensions (formal, lean)

**Formal extension updates needed**:
1. Add 3 missing agents (logic-research, math-research, physics-research)
2. Add 3 missing skills (skill-logic-research, skill-math-research, skill-physics-research)
3. Add all context files from .claude formal extension (adapt paths from `.claude/` to `.opencode/`)
4. Populate index-entries.json with load_when metadata
5. Update manifest.json to reflect full content

**Lean extension updates needed**:
1. Add 2 missing skills (skill-lake-repair, skill-lean-version)
2. Add context files (or verify base lean4/ context is sufficient)
3. Add scripts (setup-lean-mcp.sh, verify-lean-mcp.sh) adapted for OpenCode
4. Add settings-fragment.json for MCP configuration
5. Add commands to extension (lake.md, lean.md) if not keeping them in base

### Priority 2: Create Missing Extensions

Create new .opencode extensions for:
1. **nix** - New to OpenCode (agents, skills, rules, context, MCP server)
2. **python** - New to OpenCode (agents, skills, context)
3. **z3** - New to OpenCode (agents, skills, context)
4. **web** - Partially new (context exists in base, but needs extension with agents/skills/rules)

### Priority 3: Refactor Baked-In Content

For domains already baked into .opencode base:
1. **document-converter** - Already complete in base, just create extension wrapper pointing to base content
2. **latex** - Create extension from existing base content, update to match .claude version
3. **typst** - Create extension from existing base content, update to match .claude version

### Priority 4: ModelChecker Re-deployment

After updating the source .opencode/extensions/:
1. Re-run extension installation to ModelChecker
2. Verify all files are properly installed
3. Generate project-specific repo/project-overview.md for ModelChecker

## Appendix

### Search Methods Used
- `find` to enumerate all files in both .opencode/ and .claude/extensions/ directories
- `comm` to compute set differences between file lists
- `diff` to compare directory structures
- Direct file reading of manifest.json, extensions.json, index-entries.json, OPENCODE.md

### File Counts Summary

| Location | File Count |
|----------|-----------|
| Source .opencode/ (all) | ~230 |
| Target ModelChecker .opencode/ (all) | ~235 |
| .claude/extensions/ (all) | ~180 |
| .opencode/extensions/ (all) | 13 |

### Complete Missing Extensions Inventory

Extensions in .claude/ with no .opencode/ equivalent:
- `document-converter/` - 6 files (agent, skill, command, EXTENSION.md, manifest, index-entries)
- `latex/` - 16 files (2 agents, 2 skills, 1 rule, 10 context, EXTENSION.md, manifest, index-entries)
- `nix/` - 17 files (2 agents, 2 skills, 1 rule, 12 context, EXTENSION.md, manifest, index-entries, settings-fragment)
- `python/` - 12 files (2 agents, 2 skills, 6 context, EXTENSION.md, manifest, index-entries)
- `typst/` - 18 files (2 agents, 2 skills, 12 context, EXTENSION.md, manifest, index-entries)
- `web/` - 27 files (2 agents, 2 skills, 1 rule, 20 context, EXTENSION.md, manifest, index-entries)
- `z3/` - 11 files (2 agents, 2 skills, 5 context, EXTENSION.md, manifest, index-entries)
