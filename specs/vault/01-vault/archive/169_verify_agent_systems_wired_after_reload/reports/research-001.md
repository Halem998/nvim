# Research Report: Task #169

**Task**: 169 - verify_agent_systems_wired_after_reload
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T00:30:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (.claude/, .opencode/, context/index.json)
**Artifacts**: specs/169_verify_agent_systems_wired_after_reload/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- Both `.claude/` and `.opencode/` agent systems have complete and matching skill-to-agent wiring for all task types
- **Critical gap**: Neovim (nvim) and filetypes extension context entries are NOT merged into either system's main `index.json`, meaning context discovery via `jq` queries returns zero results for neovim-research-agent and filetypes-router-agent
- 76 context files referenced in `.claude/context/index.json` are missing from disk (mostly python, nix, web, logic, math, physics, z3 domains)
- 12 context files referenced in `.opencode/context/index.json` are missing from disk (z3, nix, python)
- `.opencode/` has 2 extra commands/skills (`/fix`, `/todo` skill) and 1 extra agent (`code-reviewer-agent`) compared to `.claude/`

## Context & Scope

This research verifies the full wiring chain:
1. Task type (language) -> Skill routing (in commands)
2. Skill -> Agent delegation
3. Agent -> Context loading (via index.json)

Both `.claude/` (Claude Code) and `.opencode/` (OpenCode) systems were examined.

## Findings

### 1. Language-Based Routing (Commands -> Skills)

Both systems have identical routing tables in their `/research` commands:

| Language | Skill | Status |
|----------|-------|--------|
| neovim | skill-neovim-research | OK |
| lean4 | skill-lean-research | OK |
| latex | skill-latex-research | OK |
| typst | skill-typst-research | OK |
| python | skill-python-research | OK |
| z3 | skill-z3-research | OK |
| nix | skill-nix-research | OK |
| web | skill-web-research | OK |
| epidemiology | skill-epidemiology-research | OK |
| formal, logic, math, physics | skill-formal-research | OK |
| general, meta, markdown | skill-researcher | OK |

Both systems also route implementation via parallel skill sets (skill-*-implementation).

**Verdict**: Routing tables are complete and consistent.

### 2. Skill -> Agent Delegation

All skills follow the thin-wrapper pattern, delegating to named agents via the Task tool.

**.claude/ skills** (38 skill directories):
- All research/implementation skills correctly reference their corresponding agents
- Core skills: skill-researcher -> general-research-agent, skill-planner -> planner-agent, skill-implementer -> general-implementation-agent, skill-meta -> meta-builder-agent

**.opencode/ skills** (40 skill directories):
- Has everything .claude has, plus: `skill-fix`, `skill-todo`
- All agent references match

**.claude/ agents** (31 agent files):
- Complete set covering all language domains

**.opencode/ agents** (33 agent files in subagents/):
- Has everything .claude has, plus: `code-reviewer-agent`, `README.md`

**Verdict**: Skill-to-agent wiring is correct and complete in both systems.

### 3. Context Index (index.json) - Agent Discovery

**.claude/context/index.json**: 97 entries
- Agents referenced: 25 unique agents
- Languages referenced: 15 unique languages (epidemiology, formal, general, latex, lean4, logic, math, meta, nix, physics, python, r, typst, web, z3)

**.opencode/context/index.json**: 32 entries
- Agents referenced: 23 unique agents (missing: formal-research-agent, physics-research-agent)
- Languages referenced: 10 unique languages (missing: formal, general, logic, math, physics)

**Verdict**: .opencode has significantly fewer index entries (32 vs 97). It is missing formal-research-agent and physics-research-agent from its index, even though both agent files exist in `.opencode/agent/subagents/`.

### 4. CRITICAL: Missing Neovim Context Index Entries

Neither system has neovim context entries in their main `index.json`:
- `.claude/context/index.json`: 0 entries for neovim-research-agent, 0 for language "neovim"
- `.opencode/context/index.json`: 0 entries for neovim-research-agent, 0 for language "neovim"

**However**, both have extension index files:
- `.claude/extensions/nvim/index-entries.json`: 16 entries for neovim agents
- `.opencode/extensions/nvim/index-entries.json`: exists (not counted separately)

The extension entries define `load_when.agents: ["neovim-research-agent", "neovim-implementation-agent"]` and `load_when.languages: ["neovim"]`, but these are NOT merged into the main index.

**Impact**: When neovim-research-agent runs this discovery query:
```bash
jq -r '.entries[] | select(.load_when.agents[]? == "neovim-research-agent") | .path' .claude/context/index.json
```
It returns ZERO results. The agent falls back to hardcoded @-references in the agent definition, but loses the benefit of dynamic context discovery.

**Same issue for filetypes extension**: filetypes-router-agent has 8 extension entries but 0 in main index.

### 5. Extensions with Merged vs Unmerged Entries

| Extension | Ext Entries | In Main Index? | Agent Coverage |
|-----------|------------|----------------|----------------|
| epidemiology | 2 | Partial (1) | OK |
| filetypes | 8 | NO (0) | BROKEN |
| formal | 37 | YES (20) | OK |
| latex | 9 | Partial (1) | Partial |
| lean | 22 | Partial (2) | Partial |
| nix | 11 | YES (11) | OK |
| nvim | 16 | NO (0) | BROKEN |
| python | 5 | YES (5) | OK |
| typst | 11 | Partial (1) | Partial |
| web | 20 | YES (18) | OK |
| z3 | 4 | Partial (2) | Partial |

### 6. Missing Context Files on Disk

**.claude/context/index.json** references 76 files that do not exist on disk:
- Python: 5 missing files (standards, patterns, domain)
- Nix: 11 missing files (all nix context)
- Web: 18 missing files (all web context, uses `.claude/context/` prefix instead of relative)
- Logic: 17 missing files (all logic context)
- Math: 15 missing files (all math context)
- Physics: 1 missing file (README)
- Z3: 4 missing files (domain, patterns)

**.opencode/context/index.json** references 12 files that do not exist on disk:
- Z3: 4 missing
- Nix: 5 missing
- Python: 3 missing

**Root cause analysis**: Many missing files use inconsistent path prefixes. Some entries use paths like `.claude/context/project/nix/README.md` (absolute from repo root) instead of `project/nix/README.md` (relative to context directory). The validation script resolves paths relative to the context directory, so prefixed paths fail to resolve.

### 7. Command Differences

**.opencode/ has these extra commands not in .claude/**:
- `/fix` command (with corresponding `skill-fix`)
- `README.md` in commands directory

**.claude/ has no commands missing from .opencode/** (all 18 .claude commands exist in .opencode).

## Decisions

- The routing table is authoritative and correct in both systems
- Extension index entries should be merged into main index.json for proper dynamic discovery
- Missing context files should be created or index entries removed

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Neovim agent gets no context from index.json | HIGH | Merge nvim extension entries into main index |
| Filetypes agent gets no context from index.json | MEDIUM | Merge filetypes extension entries into main index |
| 76 missing .claude context files cause agent errors | MEDIUM | Create placeholder files or remove dead index entries |
| .opencode index much smaller than .claude (32 vs 97) | LOW | Merge more extension entries into .opencode index |
| formal/physics agents missing from .opencode index | LOW | Add entries for completeness |

## Recommendations

1. **HIGH PRIORITY**: Merge nvim and filetypes extension index entries into both systems' main `index.json` files. This is blocking dynamic context discovery for neovim tasks.

2. **MEDIUM PRIORITY**: Audit and fix the 76 missing context file references in `.claude/context/index.json`. Many appear to be path prefix issues (absolute vs relative paths).

3. **LOW PRIORITY**: Sync `.opencode/context/index.json` to include formal-research-agent and physics-research-agent entries.

4. **LOW PRIORITY**: Evaluate whether .claude should also have `/fix` command and `skill-todo` skill that .opencode has.

## Appendix

### Search Queries Used
- `ls` on .claude/skills/, .claude/agents/, .opencode/skills/, .opencode/agent/subagents/
- `jq` queries on .claude/context/index.json and .opencode/context/index.json for agents, languages, subdomains
- `diff` comparisons of agent lists, skill lists, command lists
- Path existence validation of all index.json referenced files
- Extension index-entries.json examination for all 11 extensions

### Key File Locations
- `.claude/context/index.json` - Main context index (97 entries)
- `.opencode/context/index.json` - Main context index (32 entries)
- `.claude/extensions/nvim/index-entries.json` - Neovim extension entries (16, NOT merged)
- `.claude/extensions/filetypes/index-entries.json` - Filetypes extension entries (8, NOT merged)
- `.claude/commands/research.md` - Research command routing table
- `.opencode/commands/research.md` - Research command routing table
