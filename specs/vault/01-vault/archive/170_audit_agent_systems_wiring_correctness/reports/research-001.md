# Research Report: Task #170

**Task**: 170 - Audit Agent Systems for Complete Wiring Correctness
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T01:00:00Z
**Effort**: 1-2 hours
**Dependencies**: Tasks 163-169 (prerequisite fixes)
**Sources/Inputs**: Direct filesystem analysis of 4 agent systems in /home/benjamin/Projects/Logos/Vision/
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- The `.claude` extended system is **correctly wired** -- all core + extension components present, validate-wiring.sh passes 35/35
- The `.opencode` extended system is **severely broken** -- missing ALL core agents, skills, rules, commands, and scripts (13 validation failures)
- Both core systems (`.claude_core`, `.opencode_core`) are clean with no extension contamination
- Extension sources have perfect parity between `.claude/extensions/` and `.opencode/extensions/` in the nvim config
- Several extensions have unindexed context files (typst has 15, formal has 8)
- One broken `@`-reference: `project/repo/project-overview.md` does not exist
- Loader mechanics (verify.lua, config.lua) use configurable section_prefix and agents_subdir correctly

## Context & Scope

Audited 4 directories in `/home/benjamin/Projects/Logos/Vision/`:
- `.claude_core/` -- Core-only .claude system (baseline)
- `.opencode_core/` -- Core-only .opencode system (baseline)
- `.claude/` -- Core + all 11 extensions loaded
- `.opencode/` -- Core + all 11 extensions loaded (BROKEN)

Extensions audited: epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3

## Findings

### Area 1: Core System Completeness

#### .claude_core (PASS)

| Component | Count | Expected | Status |
|-----------|-------|----------|--------|
| Agents | 4 | 4 | PASS |
| Skills | 10 | ~10 | PASS |
| Rules | 5 | 5 | PASS |
| Context index entries | 10 | 10 | PASS |
| Extension contamination | 0 | 0 | PASS |

Agents: general-implementation-agent, general-research-agent, meta-builder-agent, planner-agent

#### .opencode_core (PASS with notes)

| Component | Count | Expected | Status |
|-----------|-------|----------|--------|
| Agents | 5 (+ README) | 4-5 | PASS |
| Skills | 12 (+ README) | ~10 | PASS |
| Rules | 5 (+ README) | 5 | PASS |
| Context index entries | 10 | 10 | PASS |
| Extension contamination | 0 | 0 | PASS |

**Cross-system delta (opencode_core has but claude_core does not)**:
- Agent: `code-reviewer-agent.md` (extra in opencode)
- Skills: `skill-fix`, `skill-todo` (extra in opencode)
- Note: `.opencode_core` has README.md in agents/, skills/, rules/ dirs; `.claude_core` does not
- Note: `.opencode_core` lacks `OPENCODE.md` (only has `README.md`)

### Area 2: Extension Source Completeness

All 11 extensions in both `.claude/extensions/` and `.opencode/extensions/` (nvim config) have:
- manifest.json files present
- Matching agent/skill/rule/context counts between claude and opencode variants

**Extension source inventory**:

| Extension | Agents | Skills | Rules | Context Files | Index Entries | Unindexed |
|-----------|--------|--------|-------|---------------|---------------|-----------|
| epidemiology | 2 | 2 | 0 | 4 | 2 | 2 |
| filetypes | 5 | 4 | 0 | 8 | 8 | 0 |
| formal | 4 | 4 | 0 | 45 | 37 | **8** |
| latex | 2 | 2 | 1 | 10 | 9 | 1 |
| lean | 2 | 4 | 1 | 24 | 22 | **2** |
| nix | 2 | 2 | 1 | 11 | 11 | 0 |
| nvim | 2 | 2 | 1 | 16 | 16 | 0 |
| python | 2 | 2 | 0 | 6 | 5 | 1 |
| typst | 2 | 2 | 0 | 26 | 11 | **15** |
| web | 2 | 3 | 1 | 22 | 20 | 2 |
| z3 | 2 | 2 | 0 | 5 | 4 | 1 |

**Unindexed context files** (exist on disk but not in index-entries.json):

typst (15 unindexed):
- All patterns/ except cross-references, fletcher-diagrams, rule-environments, theorem-environments
- All standards/ except document-structure, notation-conventions, textbook-standards, type-theory-foundations, typst-style-guide
- All templates/ except chapter-template
- README.md, typst-overview.md, typst-packages.md, typst-vs-latex.md

formal (8 unindexed):
- project/logic/domain/modal-logic-extensions.md
- project/logic/domain/proof-theory-basics.md
- project/logic/domain/temporal-logic-patterns.md
- project/math/category-theory/adjunctions.md
- project/math/category-theory/category-basics.md
- project/math/category-theory/functors-natural-transformations.md
- project/math/category-theory/limits-colimits.md
- project/math/foundations/set-theory-foundations.md

lean (2 unindexed):
- project/lean4/README.md
- project/lean4/standards/proof-conventions.md

### Area 3: Extension Loading Correctness

#### .claude extended (PASS)

| Check | Status | Details |
|-------|--------|---------|
| Core agents present | PASS | All 4 core agents + 27 extension agents = 31 |
| Core skills present | PASS | All 10 core skills + 28 extension skills = 38 (skill-tag overlap) |
| Core rules present | PASS | All 5 core rules + 5 extension rules = 10 |
| Core commands present | PASS | All 18 commands present |
| Core scripts present | PASS | All 18 scripts present |
| Context index merged | PASS | 155 entries (10 core + 145 extension) |
| Section injection | PASS | All 11 extension sections injected |
| validate-wiring.sh | PASS | 35/35 passed, 0 warnings, 0 failures |

#### .opencode extended (CRITICAL FAILURE)

| Check | Status | Details |
|-------|--------|---------|
| Core agents present | **FAIL** | 0 of 5 core agents present (only 27 extension agents) |
| Core skills present | **FAIL** | 0 of 12 core skills present (only extension skills) |
| Core rules present | **FAIL** | 0 of 5 core rules present (only 5 extension rules) |
| Core commands present | **FAIL** | 0 of 20 commands present (empty directory) |
| Core scripts present | **FAIL** | 0 of 16 scripts present (empty directory) |
| Core docs present | **FAIL** | Missing docs/, hooks/, systemd/, templates/ directories |
| Context index merged | **PARTIAL** | 145 extension entries but 0 core entries |
| Section injection | PASS | All 11 sections with `extension_oc_` prefix |
| OPENCODE.md exists | PASS | Present with routing tables |
| validate-wiring.sh | **FAIL** | 18 passed, 4 warnings, 13 failures |

**Root cause**: The extension loading process for `.opencode` appears to have created only extension content without merging core content. The `.opencode` extended directory contains ONLY extension-sourced files -- no core agents, skills, rules, commands, scripts, or core context index entries were included during assembly.

### Area 4: Routing Wiring End-to-End

Tested for neovim, lean4, epidemiology, and web:

| Language | CLAUDE.md Section | Skill Exists | Agent Exists | Context Entries |
|----------|-------------------|--------------|--------------|-----------------|
| neovim | PASS | PASS (2 skills) | PASS (2 agents) | 16 entries |
| lean4 | PASS | PASS (4 skills) | PASS (2 agents) | 22 entries |
| epidemiology | PASS | PASS (2 skills) | PASS (2 agents) | 2 entries |
| web | PASS (via section) | PASS (3 skills) | PASS (2 agents) | 20 entries |

All routing chains complete in `.claude` extended. The `.opencode` extended routing is broken because core components are missing (extension routing tables reference skills/agents that do not exist).

**Note**: Routing table format is inconsistent across extension sections. Neovim uses `Research Skill | Implementation Skill` columns while lean uses `Research Tools | Implementation Tools` columns.

### Area 5: Loader Mechanics

| Check | Status | Details |
|-------|--------|---------|
| verify.lua uses config.section_prefix | PASS | Line 177: `config.section_prefix or "extension_"` |
| verify.lua uses config.agents_subdir | PASS | Line 60: `config.agents_subdir or "agents"` |
| verify_context checks target_dir | PASS | Line 148: `target_dir .. "/context/" .. entry.path` |
| config.lua claude section_prefix | PASS | `"extension_"` |
| config.lua opencode section_prefix | PASS | `"extension_oc_"` |
| config.lua opencode agents_subdir | PASS | `"agent/subagents"` |

All loader mechanics are correctly parameterized. No hardcoded paths or prefixes.

### Area 6: Cross-System Parity

| Feature | .claude | .opencode | Parity |
|---------|---------|-----------|--------|
| Agents path | `agents/` | `agent/subagents/` | Correct (by design) |
| Section prefix | `extension_` | `extension_oc_` | Correct (by design) |
| Config file | `CLAUDE.md` | `OPENCODE.md` | Correct (by design) |
| Extension source counts | Match | Match | PASS |
| Index entry counts | Match | Match | PASS |
| Core system content | Complete | Complete | PASS |
| Extended assembly | Working | **BROKEN** | **FAIL** |

The extension source files (in nvim config) have perfect parity between `.claude/extensions/` and `.opencode/extensions/`. The divergence is in the assembly/deployment of the extended systems.

### Area 7: Fixes from Tasks 163-169

| Fix | Status | Details |
|-----|--------|---------|
| verify.lua section_prefix fix | PASS | Uses `config.section_prefix` not hardcoded |
| nvim .opencode index-entries.json synced | PASS | Both have 16 entries, matching |
| Extension source file counts | See below | 274 (claude) + 285 (opencode) = 559 total source files |
| Broken @-references | **1 remaining** | `project/repo/project-overview.md` does not exist |

### Recommendations

1. **CRITICAL: Fix .opencode extended assembly** -- The extended `.opencode` directory needs core content merged. Either:
   - Fix the assembly script/process to copy core files before adding extensions
   - Run a repair script to add missing core agents, skills, rules, commands, scripts

2. **Add unindexed context files to index-entries.json** -- 32 context files exist but are not in index entries (typst: 15, formal: 8, lean: 2, web: 2, epidemiology: 2, latex: 1, python: 1, z3: 1)

3. **Create missing project-overview.md** -- Referenced by `@.claude/context/project/repo/project-overview.md` but does not exist

4. **Standardize routing table format** -- Extension sections use inconsistent column headers (`Research Skill` vs `Research Tools`)

5. **Add code-reviewer-agent to .claude_core** -- Present in `.opencode_core` but absent from `.claude_core` (cross-system asymmetry)

## Decisions

- Classified `.opencode` extended as CRITICAL FAILURE due to missing all core components
- Classified unindexed context files as LOW priority (files exist, just not discoverable via index)
- Classified routing table format inconsistency as LOW priority (cosmetic)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| .opencode extended is non-functional | CRITICAL | Fix assembly process, add core files |
| Unindexed context files not discoverable | LOW | Add entries to index-entries.json |
| Missing project-overview.md | LOW | Create file or remove reference |

## Appendix

### Validation Script Output

`.claude` extended: 35 PASS, 0 WARN, 0 FAIL
`.opencode` extended: 18 PASS, 4 WARN, 13 FAIL

### File Counts Summary

| System | Agents | Skills | Rules | Commands | Context | Scripts |
|--------|--------|--------|-------|----------|---------|---------|
| .claude_core | 4 | 10 | 5 | 18 | 84 files | 18 |
| .claude extended | 31 | 38 | 10 | 18 | 262 files | 18 |
| .opencode_core | 6 | 13 | 6 | 20 | 100 files | 16 |
| .opencode extended | 27 | 29 | 5 | **0** | 179 files | **0** |

### Extension Sections Verified

Both `.claude/CLAUDE.md` (prefix: `extension_`) and `.opencode/OPENCODE.md` (prefix: `extension_oc_`) have all 11 extension sections injected: epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3.
