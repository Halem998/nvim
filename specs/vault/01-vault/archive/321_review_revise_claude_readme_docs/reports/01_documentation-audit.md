# Research Report: Task #321

**Task**: 321 - review_revise_claude_readme_docs
**Started**: 2026-03-28T00:00:00Z
**Completed**: 2026-03-28T00:30:00Z
**Effort**: 2-3 hours estimated for revision
**Dependencies**: None
**Sources/Inputs**: Codebase exploration, file structure analysis
**Artifacts**: specs/321_review_revise_claude_readme_docs/reports/01_documentation-audit.md
**Standards**: report-format.md

---

## Executive Summary

- The main .claude/README.md is **comprehensive but outdated** (Version 2.2, updated 2026-01-28)
- **Missing files referenced**: QUICK-START.md, TESTING.md, context/system/ directory, agents/specialists/ directory
- **Outdated references**: Several paths point to non-existent files (subagent-delegation-guide.md, subagent-return-format.md in standards/)
- **ProofChecker references** appear in 19 files but this is a Neovim configuration project, not ProofChecker
- **Extension system** is well-documented but not prominently featured in README.md
- **Recommended approach**: Restructure README.md as a navigational hub linking to detailed docs/ subdirectory

---

## Context & Scope

This research audits the .claude/README.md and all subsequent documentation to assess completeness, accuracy, and currency. The goal is to provide a clear and concise introduction to the core agent system, its architecture, and the extensions available with the Neovim loader.

---

## Findings

### 1. Current Documentation Structure

**Top-Level .claude/ Files**:
```
.claude/
  CLAUDE.md          # 15KB - Quick reference (well-maintained)
  README.md          # 36KB - Detailed architecture (outdated)
```

**Documentation Directories**:
```
.claude/docs/
  README.md          # Hub document
  architecture/      # system-overview.md, extension-system.md
  guides/            # 14 how-to guides
  examples/          # 2 flow examples
  templates/         # Command/agent templates

.claude/context/
  README.md          # Context organization guide
  (17 subdirectories with context files)

.claude/extensions/
  README.md          # Extension system overview
  (14 extension directories)
```

### 2. Issues in .claude/README.md

#### 2.1 Missing Referenced Files

The README.md references these non-existent files:

| Reference | Location in README | Status |
|-----------|-------------------|--------|
| `.claude/QUICK-START.md` | Line 1062 | **MISSING** |
| `.claude/TESTING.md` | Line 1063 | **MISSING** |
| `.claude/context/system/context-loading-strategy.md` | Line 165 | **MISSING** (dir doesn't exist) |
| `.claude/context/workflows/subagent-delegation-guide.md` | Line 70 | **MISSING** |
| `.claude/context/standards/subagent-return-format.md` | Line 100 | **MISSING** (exists in formats/) |
| `.claude/agents/specialists/` | Line 285 | **MISSING** (dir doesn't exist) |

#### 2.2 Outdated Agent References

README lists these agents that no longer exist or have different names:

| Old Name in README | Current Status |
|-------------------|----------------|
| `atomic-task-numberer` | Not found in agents/ |
| `status-sync-manager` | Not found in agents/ |
| `researcher` (generic) | Now `general-research-agent` |
| `implementer` (generic) | Now `general-implementation-agent` |
| `task-executor` | Not found in agents/ |

**Current agents in .claude/agents/**:
- general-research-agent.md
- general-implementation-agent.md
- planner-agent.md
- meta-builder-agent.md
- code-reviewer-agent.md
- spawn-agent.md

#### 2.3 ProofChecker References (Wrong Project)

19 files reference "ProofChecker" but this is a Neovim configuration project:
- .claude/docs/README.md links to "ProofChecker README"
- .claude/docs/guides/user-installation.md mentions "ProofChecker"
- Multiple context files reference ProofChecker

### 3. Well-Documented Components

#### 3.1 CLAUDE.md (Excellent)
The .claude/CLAUDE.md file is well-maintained and accurately reflects:
- Project structure
- Task management (status markers, artifact paths)
- Language-based routing tables
- Command reference
- Skill-to-agent mapping
- State synchronization
- Git commit conventions

#### 3.2 docs/README.md (Good)
Clear documentation map with:
- Getting started guides
- Component development guides
- Domain extension guides
- Templates and examples

#### 3.3 Extension System (Good)
Both .claude/extensions/README.md and .claude/docs/architecture/extension-system.md provide comprehensive coverage of:
- Extension architecture
- Loading/unloading process
- manifest.json format
- index-entries.json format
- Available extensions (14 listed)

### 4. Documentation Gaps

#### 4.1 README.md Scope Issues

The README.md (36KB, 1069 lines) tries to be both:
1. A user-facing introduction
2. A complete technical reference

**Problem**: It's too long for introduction, too shallow for reference.

#### 4.2 Missing Topics in README.md

| Topic | Current Coverage | Should Be |
|-------|-----------------|-----------|
| Extension system | Minimal mention | Prominent feature |
| Team mode (--team flag) | Not mentioned | Should be documented |
| /spawn command | Not mentioned | Should be documented |
| Vault operation | Not mentioned | Documented in CLAUDE.md only |
| Memory layers | Not mentioned | Partially in context/README.md |

#### 4.3 Duplicated Content

Content appears in multiple places:
- State management: README.md, CLAUDE.md, context/orchestration/state-management.md
- Language routing: README.md, CLAUDE.md, context/routing.md
- Git workflow: README.md, rules/git-workflow.md

---

## Recommendations

### 1. Restructure README.md as Navigation Hub

**Proposed structure** (~200-300 lines):

```markdown
# Claude Code System Architecture

## Overview
Brief 2-paragraph introduction

## Quick Start
- Link to docs/guides/user-installation.md
- Key commands table (task, research, plan, implement)

## Architecture
- Three-layer diagram (command -> skill -> agent)
- Link to docs/architecture/system-overview.md

## Core Components
### Commands, Skills, Agents
- Brief tables with links to component directories

## Extensions
- Prominent section about extension system
- Available extensions table
- Link to extensions/README.md

## Documentation
- Link map to docs/ subdirectory

## Related Files
- CLAUDE.md (quick reference)
- docs/README.md (documentation hub)
```

### 2. Remove or Create Missing Files

| File | Action |
|------|--------|
| QUICK-START.md | Create or remove reference |
| TESTING.md | Create or remove reference |
| context/system/ | Remove references (context flattened) |
| agents/specialists/ | Remove references (not implemented) |

### 3. Fix Path References

Update all references to use current paths:
- `context/standards/subagent-return-format.md` -> `context/formats/subagent-return.md`
- `context/workflows/subagent-delegation-guide.md` -> `context/orchestration/delegation.md`

### 4. Fix ProofChecker References

Replace "ProofChecker" with "Neovim Configuration" in:
- .claude/docs/README.md
- .claude/docs/guides/user-installation.md
- Other affected files

### 5. Move Detailed Content

Move detailed technical content from README.md to appropriate locations:

| Content Section | Move To |
|-----------------|---------|
| Delegation Flow details | context/orchestration/delegation.md |
| State Management details | context/orchestration/state-management.md |
| Error Handling details | context/standards/error-handling.md |
| Git Workflow details | rules/git-workflow.md |
| Meta System Builder | context/meta/meta-guide.md |
| Forked Subagent Pattern | context/patterns/ (new file) |
| Session Maintenance | Keep (user-facing) |
| MCP Server Configuration | Keep (user-facing) |

---

## Decisions

1. **README.md should be a navigational hub** - Not a comprehensive reference
2. **CLAUDE.md remains the quick reference** - Already well-maintained
3. **docs/ is the detailed documentation location** - Preserve this structure
4. **Extension system deserves prominence** - Key feature of the system

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing links | Document all link changes in revision |
| Losing important content | Move to appropriate locations, don't delete |
| User confusion during transition | Clear navigation links |

---

## Implementation Phases (Suggested)

1. **Phase 1**: Create missing files or remove references
2. **Phase 2**: Fix ProofChecker references
3. **Phase 3**: Fix broken path references
4. **Phase 4**: Restructure README.md as navigation hub
5. **Phase 5**: Move detailed content to appropriate locations
6. **Phase 6**: Verify all links work

---

## Appendix

### Files Audited

1. .claude/README.md (main target)
2. .claude/CLAUDE.md
3. .claude/docs/README.md
4. .claude/docs/architecture/system-overview.md
5. .claude/docs/architecture/extension-system.md
6. .claude/extensions/README.md
7. .claude/context/README.md
8. .claude/agents/README.md
9. All component directories (commands, skills, agents, rules)
10. Sample extension (nvim)

### Statistics

| Component | Count |
|-----------|-------|
| Commands | 16 files |
| Skills | 17 directories |
| Agents | 7 files (including README) |
| Rules | 5 files |
| Extensions | 14 available |
| Documentation guides | 14 files |
| Context directories | 17 subdirectories |
