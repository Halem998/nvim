# Implementation Plan: Task #116

- **Task**: 116 - Verify OpenCode & Implement Extension Parity
- **Status**: [NOT STARTED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The .opencode extension system currently has 2 extensions (formal, lean) that are incomplete copies of their .claude counterparts, and 7 .claude extensions (document-converter, latex, nix, python, typst, web, z3) with no .opencode equivalent at all. The .opencode base system already has many domain-specific components baked in (skills, rules, commands, context) from before the extension architecture was implemented, creating overlap. This plan addresses all gaps in 6 phases: first completing the existing formal and lean extensions, then creating the 7 missing extensions, and finally verifying the ModelChecker deployment. Each new extension requires adapting the .claude version by changing merge targets from `claudemd` to `opencode_md` and adjusting paths from `.claude/` to `.opencode/`.

### Research Integration

Research report research-001.md identified:
- Formal extension missing 3 agents, 3 skills, 41 context files, and index entries
- Lean extension missing 2 skills, 2 commands, 27 context files, scripts, and settings-fragment
- 7 .claude extensions with no .opencode equivalent (document-converter, latex, nix, python, typst, web, z3)
- Several baked-in components in .opencode base that overlap with extension content (latex, typst, lean, logic, math, document-converter)
- Architecture differences: .opencode uses `opencode_md` merge target vs `claudemd`

## Goals & Non-Goals

**Goals**:
- Complete the .opencode formal extension to match .claude formal extension (4 agents, 4 skills, 41 context files, index entries)
- Complete the .opencode lean extension to match .claude lean extension (2 additional skills, context files, scripts, settings-fragment)
- Create 7 new .opencode extensions matching .claude counterparts (document-converter, latex, nix, python, typst, web, z3)
- Adapt all paths and merge targets for .opencode architecture
- Verify ModelChecker deployment receives updated extensions

**Non-Goals**:
- Removing baked-in content from .opencode base (separate refactoring task)
- Creating new content not in .claude extensions (only porting existing content)
- Modifying the .claude extensions themselves
- Implementing OpenCode-specific features not in Claude Code

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Content divergence between baked-in .opencode base and extension content | M | H | Extensions should be authoritative; document overlap for future cleanup task |
| Agent format differences between .claude and .opencode | M | M | Compare existing .opencode extension agents to .claude agents to identify format differences before bulk porting |
| MCP server references (nix, lean) may not work in OpenCode | L | M | Include MCP server config in settings-fragment.json but mark as optional |
| Large number of context files (100+) increases error risk | M | M | Verify each extension with file count checks after creation |

## Implementation Phases

### Phase 1: Complete Formal Extension [NOT STARTED]

**Goal**: Bring .opencode/extensions/formal/ to full parity with .claude/extensions/formal/ (48 files total).

**Tasks**:
- [ ] Add 3 missing agents: logic-research-agent.md, math-research-agent.md, physics-research-agent.md (adapt from .claude versions, adjust paths)
- [ ] Add 3 missing skills: skill-logic-research/, skill-math-research/, skill-physics-research/ (adapt SKILL.md from .claude versions)
- [ ] Create full context directory structure: context/project/logic/ (18 files), context/project/math/ (14 files), context/project/physics/ (2 files)
- [ ] Copy and adapt all 41 context files from .claude/extensions/formal/context/
- [ ] Populate index-entries.json with all 30+ entries from .claude version (adjust paths from .claude/ to .opencode/)
- [ ] Update manifest.json to list all 4 agents, 4 skills, and 3 context directories
- [ ] Update EXTENSION.md to include all components

**Timing**: 1.5 hours

**Files to create/modify**:
- `.opencode/extensions/formal/agents/logic-research-agent.md` - new
- `.opencode/extensions/formal/agents/math-research-agent.md` - new
- `.opencode/extensions/formal/agents/physics-research-agent.md` - new
- `.opencode/extensions/formal/skills/skill-logic-research/SKILL.md` - new
- `.opencode/extensions/formal/skills/skill-math-research/SKILL.md` - new
- `.opencode/extensions/formal/skills/skill-physics-research/SKILL.md` - new
- `.opencode/extensions/formal/context/project/logic/**` - 18 new files
- `.opencode/extensions/formal/context/project/math/**` - 14 new files
- `.opencode/extensions/formal/context/project/physics/**` - 2 new files
- `.opencode/extensions/formal/manifest.json` - update
- `.opencode/extensions/formal/index-entries.json` - update
- `.opencode/extensions/formal/EXTENSION.md` - update

**Verification**:
- File count matches .claude/extensions/formal/ (48 files)
- manifest.json lists all 4 agents, 4 skills
- index-entries.json has 30+ entries with .opencode/ paths
- All context file paths are valid

---

### Phase 2: Complete Lean Extension [NOT STARTED]

**Goal**: Bring .opencode/extensions/lean/ to full parity with .claude/extensions/lean/ (38 files total).

**Tasks**:
- [ ] Add 2 missing skills: skill-lake-repair/SKILL.md, skill-lean-version/SKILL.md (adapt from .claude versions)
- [ ] Determine command handling: lake.md and lean.md already exist in .opencode/commands/ base; add to extension for completeness or document that they live in base
- [ ] Create context directory: context/project/lean4/ with all 27 files (adapt from .claude version)
- [ ] Add scripts: scripts/setup-lean-mcp.sh, scripts/verify-lean-mcp.sh (adapt for OpenCode paths)
- [ ] Add settings-fragment.json for lean-lsp MCP server configuration
- [ ] Populate index-entries.json with all entries from .claude version (adjust paths)
- [ ] Update manifest.json to list all 4 skills, context, scripts, settings
- [ ] Update EXTENSION.md to include all components

**Timing**: 1.5 hours

**Files to create/modify**:
- `.opencode/extensions/lean/skills/skill-lake-repair/SKILL.md` - new
- `.opencode/extensions/lean/skills/skill-lean-version/SKILL.md` - new
- `.opencode/extensions/lean/commands/lake.md` - new (or document base location)
- `.opencode/extensions/lean/commands/lean.md` - new (or document base location)
- `.opencode/extensions/lean/context/project/lean4/**` - 27 new files
- `.opencode/extensions/lean/scripts/setup-lean-mcp.sh` - new
- `.opencode/extensions/lean/scripts/verify-lean-mcp.sh` - new
- `.opencode/extensions/lean/settings-fragment.json` - new
- `.opencode/extensions/lean/manifest.json` - update
- `.opencode/extensions/lean/index-entries.json` - update
- `.opencode/extensions/lean/EXTENSION.md` - update

**Verification**:
- File count matches .claude/extensions/lean/ (38 files)
- manifest.json lists all 4 skills, 2 agents, commands, scripts, settings
- index-entries.json has entries with .opencode/ paths
- Scripts reference .opencode/ paths not .claude/ paths

---

### Phase 3: Create Standalone Extensions (document-converter, python, z3) [NOT STARTED]

**Goal**: Create 3 new .opencode extensions for domains that have minimal overlap with .opencode base content.

**Tasks**:
- [ ] **document-converter** (6 files): Create extension with agent, skill, command, EXTENSION.md, manifest.json, index-entries.json. Note: agent/skill/command already baked into .opencode base; extension provides modular packaging.
  - Adapt merge targets: `opencode_md` instead of `claudemd`
  - Adapt all internal paths from `.claude/` to `.opencode/`
- [ ] **python** (13 files): Create extension with 2 agents, 2 skills, 6 context files, EXTENSION.md, manifest.json, index-entries.json
  - New language for .opencode (no baked-in content)
  - Add language routing entry for `python`
- [ ] **z3** (12 files): Create extension with 2 agents, 2 skills, 5 context files, EXTENSION.md, manifest.json, index-entries.json
  - New language for .opencode (no baked-in content)
  - Add language routing entry for `z3`

**Timing**: 1.5 hours

**Files to create**:
- `.opencode/extensions/document-converter/` - 6 files
- `.opencode/extensions/python/` - 13 files
- `.opencode/extensions/z3/` - 12 files

**Verification**:
- Each extension has valid manifest.json with `opencode_md` merge target
- Each extension has valid EXTENSION.md with `section_id` markers
- File counts match .claude counterparts
- Agent and skill files reference .opencode/ paths

---

### Phase 4: Create Content-Heavy Extensions (latex, typst, web) [NOT STARTED]

**Goal**: Create 3 new .opencode extensions for domains that have significant context file content and some overlap with .opencode base content.

**Tasks**:
- [ ] **latex** (18 files): Create extension with 2 agents, 2 skills, 1 rule, 10 context files, EXTENSION.md, manifest.json, index-entries.json
  - Note: agents, skills, rule, and context already baked into .opencode base
  - Extension provides authoritative versions with self-contained packaging
  - Adapt all paths and merge targets
- [ ] **typst** (19 files): Create extension with 2 agents, 2 skills, 12 context files, EXTENSION.md, manifest.json, index-entries.json
  - Note: agents, skills, and context already baked into .opencode base
  - Extension provides authoritative versions
  - Adapt all paths and merge targets
- [ ] **web** (28 files): Create extension with 2 agents, 2 skills, 1 rule, 20 context files, EXTENSION.md, manifest.json, index-entries.json
  - Note: context already baked into .opencode base; agents/skills are new
  - Extension provides complete package
  - Adapt all paths and merge targets

**Timing**: 2 hours

**Files to create**:
- `.opencode/extensions/latex/` - 18 files
- `.opencode/extensions/typst/` - 19 files
- `.opencode/extensions/web/` - 28 files

**Verification**:
- Each extension has valid manifest.json with `opencode_md` merge target
- latex extension has rule in rules/ directory
- web extension has rule in rules/ directory
- Context file directory structures match .claude counterparts
- File counts match .claude counterparts

---

### Phase 5: Create Nix Extension [NOT STARTED]

**Goal**: Create the nix .opencode extension, which requires special handling due to MCP server configuration.

**Tasks**:
- [ ] **nix** (20 files): Create extension with 2 agents, 2 skills, 1 rule, 12 context files, settings-fragment.json, EXTENSION.md, manifest.json, index-entries.json
  - New language for .opencode (no baked-in content)
  - Include MCP server configuration for mcp-nixos in manifest.json `mcp_servers` section
  - Create settings-fragment.json with MCP server definition
  - Adapt all paths and merge targets

**Timing**: 0.5 hours

**Files to create**:
- `.opencode/extensions/nix/` - 20 files

**Verification**:
- manifest.json has `mcp_servers` section for mcp-nixos
- settings-fragment.json has valid MCP server configuration
- All 12 context files present under context/project/nix/
- Rule file present at rules/nix.md
- File count matches .claude counterpart (20 files)

---

### Phase 6: Verification and Validation [NOT STARTED]

**Goal**: Validate all extensions are correct, compare file counts, and verify extension loading readiness.

**Tasks**:
- [ ] Run file count comparison: for each of the 9 extensions, count files in .opencode/extensions/{ext}/ and compare to .claude/extensions/{ext}/
- [ ] Validate all manifest.json files parse correctly and reference existing files
- [ ] Validate all index-entries.json files parse correctly and use .opencode/ paths (not .claude/)
- [ ] Validate no EXTENSION.md files reference .claude/ paths (should all use .opencode/)
- [ ] Verify no agent/skill files contain .claude/ path references
- [ ] Create summary of overlap between extensions and baked-in .opencode base content (for future cleanup task)
- [ ] Verify extension loading would work by checking section_id uniqueness across all EXTENSION.md files

**Timing**: 0.5 hours

**Verification**:
- All 9 extensions have matching file counts vs .claude counterparts
- Zero references to `.claude/` in .opencode extension files
- All JSON files parse without errors
- Summary document created listing baked-in vs extension overlap

## Testing & Validation

- [ ] Each extension directory has exactly the same number of files as its .claude counterpart
- [ ] All manifest.json files are valid JSON with correct `opencode_md` merge target
- [ ] All index-entries.json files are valid JSON with .opencode/ paths
- [ ] All EXTENSION.md files use `section_id` format `extension_oc_{name}`
- [ ] No .opencode extension file contains a `.claude/` path reference
- [ ] All agent and skill files exist at paths declared in manifest.json
- [ ] All context files exist at paths referenced in index-entries.json

## Artifacts & Outputs

- `specs/116_verify_opencode_implement_extension_parity/plans/implementation-001.md` (this file)
- `.opencode/extensions/formal/` - completed (48 files)
- `.opencode/extensions/lean/` - completed (38 files)
- `.opencode/extensions/document-converter/` - new (6 files)
- `.opencode/extensions/latex/` - new (18 files)
- `.opencode/extensions/nix/` - new (20 files)
- `.opencode/extensions/python/` - new (13 files)
- `.opencode/extensions/typst/` - new (19 files)
- `.opencode/extensions/web/` - new (28 files)
- `.opencode/extensions/z3/` - new (12 files)
- Total: ~202 files across 9 extensions (matching .claude/extensions/ total)

## Rollback/Contingency

- All changes are additive (new files/directories) with no deletions
- Existing .opencode/extensions/formal/ and .opencode/extensions/lean/ files are modified but can be restored from git
- If any extension causes issues, it can be removed independently since extensions are self-contained packages
- The .opencode base baked-in content remains untouched; cleanup is deferred to a separate task
