# Implementation Plan: Task #116 (Revised v3)

- **Task**: 116 - Verify OpenCode & Implement Extension Parity
- **Status**: [COMPLETED]
- **Version**: 003
- **Revised**: 2026-03-03
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan creates 9 complete .opencode/ extensions by adapting their .claude/ counterparts using mechanical translation. **All extensions require full creation** - there are no pre-existing components in .opencode core to package.

**Correction from v002**: latex and typst are NOT in .opencode core. All 9 extensions (formal, lean, document-converter, latex, nix, python, typst, web, z3) require full creation from .claude/ counterparts.

### Research Integration

**From research-001.md**:
- Formal extension incomplete: missing 3 agents, 3 skills, 41 context files
- Lean extension incomplete: missing 2 skills, 27 context files, scripts, settings-fragment
- 7 .claude extensions with no .opencode equivalent

**From research-002.md**:
- Extension pattern is unique to nvim - must adapt from .claude/
- Mechanical translation: path prefixes (.claude/ -> .opencode/), manifest rekey (claudemd -> opencode_md), frontmatter additions
- Agent frontmatter needs: mode, temperature, tools, permissions blocks

**User Clarification**:
- latex and typst are NOT in .opencode core - require full creation

## Goals & Non-Goals

**Goals**:
- Complete formal extension (4 agents, 4 skills, 41 context files)
- Complete lean extension (2 agents, 4 skills, 27 context files, scripts, settings)
- Create 7 new .opencode extensions from .claude/ counterparts (document-converter, latex, nix, python, typst, web, z3)
- All 9 extensions use opencode_md merge target and .opencode/ paths

**Non-Goals**:
- Removing any baked-in content from .opencode base (separate task)
- Creating content not in .claude extensions
- Modifying .claude extensions themselves

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path mismatch after translation | M | M | Grep for .claude/ references after each extension |
| Agent frontmatter incomplete | M | L | Use existing lean extension agents as template |
| MCP server configs may not work | L | M | Mark as optional, include settings-fragment.json |
| Large file count increases error risk | M | M | Verify file counts after each phase |

## Implementation Phases

### Phase 1: Complete Formal Extension [COMPLETED]

**Goal**: Complete .opencode/extensions/formal/ to match .claude/extensions/formal/ (48 files).

**Tasks**:
- [ ] Add 3 missing agents: logic-research-agent.md, math-research-agent.md, physics-research-agent.md
- [ ] Add 3 missing skills: skill-logic-research/, skill-math-research/, skill-physics-research/
- [ ] Create context directories: logic/ (18 files), math/ (14 files), physics/ (2 files)
- [ ] Populate index-entries.json with all entries
- [ ] Update manifest.json and EXTENSION.md

**Translation Pattern**:
```bash
# Copy from .claude/extensions/formal/, apply:
sed -i 's|\.claude/|.opencode/|g' *.md
sed -i 's|@\.claude/|@.opencode/|g' *.md
# Verify frontmatter has mode/temperature/tools/permissions
```

**Timing**: 1.5 hours

**Verification**:
- File count: 48 files
- Zero .claude/ path references
- All @-references resolve

---

### Phase 2: Complete Lean Extension [COMPLETED]

**Goal**: Complete .opencode/extensions/lean/ to match .claude/extensions/lean/ (38 files).

**Tasks**:
- [ ] Add 2 missing skills: skill-lake-repair/, skill-lean-version/
- [ ] Create context/project/lean4/ with all 27 files
- [ ] Add scripts: setup-lean-mcp.sh, verify-lean-mcp.sh
- [ ] Add settings-fragment.json for lean-lsp MCP server
- [ ] Populate index-entries.json
- [ ] Update manifest.json and EXTENSION.md

**Timing**: 1 hour

**Verification**:
- File count: 38 files
- Scripts reference .opencode/ paths
- settings-fragment.json has valid MCP config

---

### Phase 3: Create Simple Extensions (document-converter, python, z3) [COMPLETED]

**Goal**: Create 3 smaller extensions (6-13 files each) using mechanical translation.

**Tasks**:

**document-converter** (6 files):
- [ ] Create .opencode/extensions/document-converter/ from .claude/ counterpart
- [ ] Translate all paths, rekey manifest.json
- [ ] Verify agent frontmatter

**python** (13 files):
- [ ] Create .opencode/extensions/python/ from .claude/ counterpart
- [ ] 2 agents, 2 skills, 6 context files
- [ ] Translate all paths, rekey manifest.json

**z3** (12 files):
- [ ] Create .opencode/extensions/z3/ from .claude/ counterpart
- [ ] 2 agents, 2 skills, 4 context files
- [ ] Translate all paths, rekey manifest.json

**Mechanical Translation** (apply to each):
```bash
# 1. Copy extension
cp -r .claude/extensions/{name}/ .opencode/extensions/{name}/

# 2. Path substitution
find .opencode/extensions/{name}/ -type f -exec sed -i 's|\.claude/|.opencode/|g' {} \;
find .opencode/extensions/{name}/ -type f -exec sed -i 's|@\.claude/|@.opencode/|g' {} \;

# 3. Rekey manifest.json (use jq or manual edit)
# Change "claudemd" to "opencode_md"
# Change ".claude/CLAUDE.md" to ".opencode/OPENCODE.md"
# Change section_id to "extension_oc_{name}"
```

**Timing**: 1.5 hours (30 min each)

**Verification**:
- File counts match .claude/ counterparts
- All manifest.json use opencode_md merge target
- Zero .claude/ references

---

### Phase 4: Create Content-Heavy Extensions (latex, typst, web) [COMPLETED]

**Goal**: Create 3 larger extensions (18-28 files each) with significant context content.

**Tasks**:

**latex** (18 files):
- [ ] Create .opencode/extensions/latex/ from .claude/ counterpart
- [ ] 2 agents, 2 skills, 1 rule, 10 context files
- [ ] Translate all paths, rekey manifest.json
- [ ] Verify rule file at rules/latex.md

**typst** (19 files):
- [ ] Create .opencode/extensions/typst/ from .claude/ counterpart
- [ ] 2 agents, 2 skills, 12 context files
- [ ] Translate all paths, rekey manifest.json

**web** (28 files):
- [ ] Create .opencode/extensions/web/ from .claude/ counterpart
- [ ] 2 agents, 2 skills, 1 rule, 20 context files
- [ ] Translate all paths, rekey manifest.json
- [ ] Verify rule file at rules/web.md

**Timing**: 2 hours (40 min each)

**Verification**:
- File counts match .claude/ counterparts
- latex and web have rule files
- All agents have proper frontmatter
- Zero .claude/ references

---

### Phase 5: Create Nix Extension [COMPLETED]

**Goal**: Create nix extension with MCP server configuration.

**Tasks**:
- [ ] Create .opencode/extensions/nix/ from .claude/ counterpart (20 files)
- [ ] 2 agents, 2 skills, 1 rule, 11 context files
- [ ] Include settings-fragment.json with mcp-nixos server config
- [ ] Translate all paths, rekey manifest.json
- [ ] Verify MCP server configuration format

**Timing**: 30 minutes

**Verification**:
- File count: 20 files
- manifest.json has mcp_servers section
- settings-fragment.json has valid MCP config
- Rule file at rules/nix.md
- Zero .claude/ references

---

### Phase 6: Verification and Validation [COMPLETED]

**Goal**: Validate all 9 extensions are correct and consistent.

**Tasks**:
- [ ] File count comparison for all 9 extensions vs .claude/ counterparts
- [ ] Grep all extensions for .claude/ references: `grep -r "\.claude/" .opencode/extensions/`
- [ ] Validate all manifest.json files parse and have opencode_md target
- [ ] Validate all index-entries.json files use .opencode/ paths
- [ ] Verify all EXTENSION.md section_ids use extension_oc_{name} format
- [ ] Verify all agents have mode/temperature/tools/permissions frontmatter
- [ ] Test at least one @-reference resolution per extension

**Timing**: 30 minutes

**Verification**:
- All 9 extensions pass file count check
- Zero .claude/ references found
- All JSON files parse without errors

## Testing & Validation

- [ ] Each extension has matching file count vs .claude/ counterpart
- [ ] All manifest.json files have opencode_md merge target
- [ ] All index-entries.json files use .opencode/ paths
- [ ] All EXTENSION.md files use section_id format extension_oc_{name}
- [ ] No .opencode extension file contains .claude/ path reference
- [ ] All agent files have mode/temperature/tools/permissions frontmatter
- [ ] All @-references in SKILL.md and agent files resolve

## Artifacts & Outputs

| Extension | File Count | Agents | Skills | Context | Rules |
|-----------|-----------|--------|--------|---------|-------|
| formal | 48 | 4 | 4 | 34 | 0 |
| lean | 38 | 2 | 4 | 27 | 0 |
| document-converter | 6 | 1 | 1 | 0 | 0 |
| latex | 18 | 2 | 2 | 10 | 1 |
| nix | 20 | 2 | 2 | 11 | 1 |
| python | 13 | 2 | 2 | 6 | 0 |
| typst | 19 | 2 | 2 | 12 | 0 |
| web | 28 | 2 | 2 | 20 | 1 |
| z3 | 12 | 2 | 2 | 4 | 0 |
| **Total** | **~202** | **19** | **21** | **124** | **3** |

## Rollback/Contingency

- All changes are additive (new files/directories)
- Each extension is self-contained and can be removed independently
- Git history preserves all states for rollback

## Key Changes from v002

1. **latex/typst are NOT in core**: Both require full creation from .claude/, moved to Phase 4 (content-heavy)
2. **Removed Category A**: No "packaging only" category - all extensions need full creation
3. **Adjusted time estimate**: 6-8 hours (up from 5-7) due to latex/typst full creation
4. **Reorganized phases**: Simple (3) -> Content-heavy (4) -> MCP-dependent (5)
