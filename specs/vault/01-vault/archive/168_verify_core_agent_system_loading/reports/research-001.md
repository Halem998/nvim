# Research Report: Task #168

**Task**: 168 - Verify core agent system loading without extensions
**Started**: 2026-03-10T12:00:00Z
**Completed**: 2026-03-10T12:30:00Z
**Effort**: 0.5-1 hours
**Dependencies**: Task 167 (move extension artifacts into core directories)
**Sources/Inputs**: Codebase exploration of source (nvim/.claude/) and target (/home/benjamin/Projects/Logos/Vision/.claude/ and .opencode/)
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

The core agent systems in `/home/benjamin/Projects/Logos/Vision/` (.claude/ and .opencode/) contain **all extension artifacts merged into core** rather than being core-only systems. This is the expected outcome of Task 167 (which moved extension artifacts into core directories). However, there are several issues that need correction:

1. **CRITICAL: index.json has broken paths** - 77 of 97 entries in .claude/context/index.json use incorrect path prefixes and fail to resolve. Similarly, 12 of 32 entries in .opencode/context/index.json are broken.
2. **The routing table in core/routing.md still references "neovim" as a core language** when the CLAUDE.md routing table lists all languages (which is correct post-merge).
3. **project-overview.md is missing** - Referenced in CLAUDE.md but does not exist (only update-project.md is present in repo/ directory).
4. **Minor .opencode/.claude parity gaps** - .opencode has 2 extra agents, 2 extra skills, 2 extra commands, and 1 extra rule compared to .claude.

## Context and Scope

Task 167 moved extension artifacts from `.claude/extensions/{ext}/` into core directories. The goal of this research is to verify that the merged system is complete and correctly wired. The question "core-only without extensions" is reframed: since Task 167 merged everything into core, the system should include ALL languages but should NOT reference extension paths (since extensions no longer exist as separate directories).

## Findings

### 1. File Completeness: Source vs Target

**Source** (nvim/.claude/): 388 files
**Target** (Vision/.claude/): 356 files

Files present in source but missing from target (expected omissions):
- `extensions/` directory (11 extension directories with manifests) - correctly removed since artifacts were merged into core
- `context/project/repo/project-overview.md` - project-specific, not part of core system
- `context/project/repo/self-healing-implementation-details.md` - project-specific
- `logs/` and `output/` directories - runtime artifacts

No files exist in target that are absent from source. The target is a strict subset.

### 2. index.json Path Resolution (CRITICAL)

Both .claude and .opencode index.json files have entries with three different path prefix styles, but only one style resolves correctly. All paths are relative to the `context/` directory.

**.claude/context/index.json** (97 entries total):

| Path Prefix | Count | Resolves? | Example |
|-------------|-------|-----------|---------|
| `core/...` | 8 | Yes | `core/routing.md` |
| `project/...` | 11 | Yes | `project/lean4/README.md` |
| `README.md` | 1 | Yes | `README.md` |
| `.claude/context/project/...` | 68 | **NO** | `.claude/context/project/nix/README.md` |
| `context/project/...` | 9 | **NO** | `context/project/python/standards/code-style.md` |

The 77 broken entries use paths that include the `.claude/context/` prefix (or partial `context/` prefix) which does not resolve when the working directory is already inside `.claude/context/`.

**.opencode/context/index.json** (32 entries total):

| Path Prefix | Count | Resolves? |
|-------------|-------|-----------|
| `core/...` | 8 | Yes |
| `project/...` | 11 | Yes |
| `README.md` | 1 | Yes |
| `.opencode/extensions/...` | 12 | **NO** |

The 12 broken entries reference old extension paths (`.opencode/extensions/z3/context/...`, `.opencode/extensions/nix/context/...`, etc.) that no longer exist since Task 167 merged them.

### 3. CLAUDE.md Language Routing Tables

The `.claude/CLAUDE.md` routing table lists ALL languages:

```
lean4, latex, typst, python, nix, web, epidemiology, formal/logic/math/physics, general, meta
```

This is **correct** for the post-merge system. All language skills and agents are present in the core directories.

However, `core/routing.md` (a smaller routing reference) only lists: neovim, general, meta, markdown. This is **inconsistent** - it should either list all languages (matching CLAUDE.md) or be removed in favor of CLAUDE.md as the authoritative routing reference.

### 4. Agent Inventory

**.claude/agents/**: 31 agents
**.opencode/agent/subagents/**: 33 agents (includes code-reviewer-agent.md and README.md)

All expected agents are present for all languages. Core agents:
- general-research-agent.md, general-implementation-agent.md
- meta-builder-agent.md, planner-agent.md

Extension agents (now in core): neovim, lean, latex, typst, python, nix, web, epidemiology, formal, logic, math, physics, z3, deck, document, filetypes-router, presentation, spreadsheet

### 5. Skill Inventory

**.claude/skills/**: 38 skills
**.opencode/skills/**: 40 skills (includes README.md, skill-fix, skill-todo)

All expected skills are present. The .opencode system has 2 additional skills (skill-fix, skill-todo) that do not exist in .claude.

### 6. Command Inventory

**.claude/commands/**: 18 commands
**.opencode/commands/**: 20 commands (includes README.md, fix.md)

The .opencode system has 1 additional command (fix.md) beyond the shared set.

### 7. Rules Inventory

**.claude/rules/**: 10 rules
**.opencode/rules/**: 11 rules

Both systems have the core rules (artifact-formats, error-handling, git-workflow, state-management, workflows). Extension rules present in both: latex, lean4, neovim-lua, nix, web-astro.

### 8. Missing project-overview.md

The `.claude/CLAUDE.md` references `@.claude/context/project/repo/project-overview.md` in three places:
- As a link for project-specific structure
- As a context import
- With a fallback note about `update-project.md`

The file does NOT exist. Only `update-project.md` is present in `context/project/repo/`. This is expected for a fresh deployment (the file is project-specific and should be generated per-repository), but the reference should be validated or the generation should be triggered.

### 9. Context File Coverage

The actual context files in `.claude/context/project/` cover all domains:
- Core: meta, processes, repo
- Extensions (now in core): lean4, latex, typst, python, nix, web, epidemiology, filetypes, hooks, logic, math, neovim, physics, z3

Total: 261 context files in .claude, 277 in .opencode.

## Decisions

1. The system is a "merged core" (all extensions folded in), not a "core-only" system. This is the correct outcome of Task 167.
2. The primary issue to fix is the index.json path resolution - this is a functional bug that prevents context discovery.

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Broken index.json paths prevent agent context loading | HIGH | Fix all paths to use correct relative format |
| core/routing.md inconsistent with CLAUDE.md | MEDIUM | Update or remove core/routing.md |
| Missing project-overview.md causes agent confusion | LOW | Expected for fresh deployment; update-project.md documents the generation process |
| .opencode/.claude parity gaps | LOW | Decide whether extra .opencode items should be added to .claude or vice versa |

## Recommendations

### Priority 1: Fix index.json Path Prefixes (Both Systems)

For `.claude/context/index.json`:
- Replace `.claude/context/project/` prefix with `project/` (68 entries)
- Replace `context/project/` prefix with `project/` (9 entries)
- Keep `core/`, `project/`, and root paths as-is (20 entries, already correct)

For `.opencode/context/index.json`:
- Replace `.opencode/extensions/{ext}/context/project/` prefix with `project/` (12 entries)
- Keep existing correct paths as-is (20 entries)

### Priority 2: Update core/routing.md

Either:
- (a) Update to list all languages (matching CLAUDE.md), or
- (b) Remove the neovim-specific reference and note that full routing is in CLAUDE.md

### Priority 3: Resolve .opencode/.claude Parity

Decide whether:
- .opencode extra items (code-reviewer-agent, skill-fix, skill-todo, fix.md command) should be added to .claude
- Or they are intentionally .opencode-only features

### Priority 4: Generate project-overview.md

Run the project overview generation process documented in `update-project.md` to create a Vision-specific `project-overview.md`.

## Appendix

### File Counts Summary

| Component | .claude | .opencode | Delta |
|-----------|---------|-----------|-------|
| Context files | 261 | 277 | +16 |
| Agents | 31 | 33 | +2 |
| Skills | 38 | 40 | +2 |
| Commands | 18 | 20 | +2 |
| Rules | 10 | 11 | +1 |

### Broken index.json Entry Categories (.claude)

**`.claude/context/project/` prefix (68 entries)**: nix (11), web (19), logic (15), math (15), physics (2), z3 (4), python (2 overlap)

**`context/project/` prefix (9 entries)**: python (5), z3 (4)

### Search Methodology

1. Generated full file listings of source and target using `find`
2. Performed diff analysis to identify missing/extra files
3. Validated index.json entries by checking file existence from context/ directory
4. Compared agents, skills, commands, and rules inventories
5. Examined CLAUDE.md routing tables for consistency
