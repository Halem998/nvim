# Research Report: Task #101

**Task**: 101 - Add contents to language extensions
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T00:30:00Z
**Effort**: 2-4 hours
**Dependencies**: Task 99 (extension system infrastructure - COMPLETED)
**Sources/Inputs**: Codebase exploration of ProofChecker, Logos/Theory, and ModelChecker .claude/ directories
**Artifacts**: This research report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Five language extensions need content: lean, latex, z3, typst, and python
- Three reference projects provide authoritative source material for agents, skills, rules, and context
- The existing lean, latex, and neovim extensions provide a clear template pattern (manifest.json + claudemd-section.md + index-entries.json + optional settings-fragment.json + subdirectory contents)
- Missing extensions (z3, typst, python) need to be created from scratch following the same pattern
- Existing extensions (lean, latex) need their empty subdirectories populated with actual content files

## Context & Scope

This task adds content to the language extension system created in task 99. The extensions directory at `.claude/extensions/` provides a modular way to package language-specific agents, skills, rules, and context for the Claude Code Neovim configuration management system. When an extension is "installed" via the Neovim picker, its contents are merged into the project's `.claude/` directory.

### Current State

**Existing extensions with skeleton files**:
- `lean/` - Has manifest, claudemd-section, index-entries, settings-fragment; empty subdirs for agents, commands, context, hooks, rules, scripts, skills
- `latex/` - Has manifest, claudemd-section, index-entries; empty subdirs for agents, context, skills
- `neovim/` - Has manifest, claudemd-section, index-entries; empty subdirs for agents, context, rules, skills

**Missing extensions**:
- `z3/` - Not yet created
- `typst/` - Not yet created
- `python/` - Not yet created

### Reference Projects

| Reference Project | Extensions to Source From | Language Artifacts |
|------------------|-------------------------|-------------------|
| `/home/benjamin/Projects/ProofChecker/.claude/` | lean (+ math), latex | Lean agents, skills, rules, context; LaTeX rules, context |
| `/home/benjamin/Projects/Logos/Theory/.claude/` | typst, latex | Typst agents, skills, context; LaTeX context (logos-macros) |
| `/home/benjamin/Projects/ModelChecker/.claude/` | z3, python | Z3 agents, skills, context; Python agents, skills, context |

## Findings

### 1. Extension File Structure Pattern

Each extension follows a consistent pattern observed in the existing lean, latex, and neovim extensions:

```
extensions/{language}/
  manifest.json          # Extension metadata, provides, merge_targets, mcp_servers
  claudemd-section.md    # CLAUDE.md section injected on install
  index-entries.json     # Context index entries merged into .claude/context/index.json
  settings-fragment.json # (optional) MCP server and permission settings
  agents/                # Language-specific agent definitions (.md files)
  skills/                # Language-specific skill wrappers (SKILL.md files)
  commands/              # Language-specific slash commands (.md files)
  rules/                 # Language-specific development rules (.md files)
  context/               # Language-specific context documents
  scripts/               # Language-specific scripts (.sh files)
  hooks/                 # Language-specific hooks
```

### 2. Lean Extension Contents (from ProofChecker)

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/`

The lean extension is the most comprehensive. It needs content in all subdirectories:

**Agents** (2 files):
- `lean-research-agent.md` - Lean 4/Mathlib research agent with MCP tool integration, search decision tree, zero-debt policy, rate limit handling (259 lines)
- `lean-implementation-agent.md` - Lean proof implementation with MCP tools, zero-debt completion gate, blocker detection, handoff protocol (515 lines)

**Skills** (4 directories):
- `skill-lean-research/SKILL.md` - Thin wrapper delegating to lean-research-agent
- `skill-lean-implementation/SKILL.md` - Thin wrapper delegating to lean-implementation-agent
- `skill-lake-repair/SKILL.md` - Lake build repair skill
- `skill-lean-version/SKILL.md` - Lean version management skill

**Commands** (2 files):
- `lake.md` - Lake build management command
- `lean.md` - Lean-specific proof assistance command

**Rules** (1 file):
- `lean4.md` - Lean 4 development rules with MCP tool reference, search decision tree, workflow patterns (60 lines)

**Context** (extensive directory tree):
- `project/lean4/` - 17+ files covering domain, patterns, processes, standards, templates, tools
- `project/math/` - 7+ files covering algebra, lattice theory, order theory, topology, foundations
- `project/logic/` - 13+ files covering domain, processes, standards (naming, notation, proof conventions)

**Scripts** (2 files):
- `setup-lean-mcp.sh` - Configure lean-lsp MCP server
- `verify-lean-mcp.sh` - Verify lean-lsp MCP setup

**Note on math/logic context**: The ProofChecker has extensive math and logic context directories that are used by lean agents. These are project-specific but could be included as optional context in the lean extension since they represent mathematical domain knowledge used in Lean proofs.

### 3. LaTeX Extension Contents (from ProofChecker and Logos/Theory)

**Source**: Both ProofChecker and Logos/Theory have LaTeX artifacts

**Agents** (1 file):
- `latex-implementation-agent.md` - LaTeX document implementation agent

**Skills** (1 directory):
- `skill-latex-implementation/SKILL.md` - Thin wrapper for LaTeX implementation

**Rules** (1 file):
- `latex.md` - LaTeX development rules with semantic linefeeds, notation macros, theorem environments, cross-references, build commands (132 lines)

**Context** (from ProofChecker):
- `project/latex/patterns/cross-references.md`
- `project/latex/patterns/theorem-environments.md`
- `project/latex/README.md`
- `project/latex/standards/document-structure.md`
- `project/latex/standards/latex-style-guide.md`
- `project/latex/standards/notation-conventions.md`
- `project/latex/templates/subfile-template.md`
- `project/latex/tools/compilation-guide.md`

**Additional from Logos/Theory**:
- `project/latex/standards/logos-macros.md` - Project-specific (should be excluded or made optional)

### 4. Typst Extension Contents (from Logos/Theory)

**Source**: `/home/benjamin/Projects/Logos/Theory/.claude/`

**Agents** (2 files):
- `typst-implementation-agent.md` - Typst document implementation agent with compilation error handling (483 lines)
- `typst-research-agent.md` - Typst document research agent

**Skills** (2 directories):
- `skill-typst-implementation/SKILL.md` - Thin wrapper for Typst implementation
- `skill-typst-research/SKILL.md` - Thin wrapper for Typst research

**Rules**: No typst-specific rules file found (LaTeX rules handle .tex files; Typst would need .typ rules)

**Context** (from Logos/Theory):
- `project/typst/README.md` - Overview with LaTeX comparison
- `project/typst/standards/typst-style-guide.md`
- `project/typst/standards/notation-conventions.md`
- `project/typst/standards/document-structure.md`
- `project/typst/standards/textbook-standards.md` - Logos-specific (may be too project-specific)
- `project/typst/standards/dtt-foundation-standard.md` - Logos-specific (exclude)
- `project/typst/patterns/theorem-environments.md`
- `project/typst/patterns/cross-references.md`
- `project/typst/patterns/fletcher-diagrams.md`
- `project/typst/patterns/rule-environments.md`
- `project/typst/templates/chapter-template.md`
- `project/typst/tools/compilation-guide.md`

### 5. Z3 Extension Contents (from ModelChecker)

**Source**: `/home/benjamin/Projects/ModelChecker/.claude/`

**Agents** (2 files):
- `z3-research-agent.md` - Z3/SMT research agent with codebase exploration and Z3 API analysis (348 lines)
- `z3-implementation-agent.md` - Z3 constraint implementation agent with solver verification (389 lines)

**Skills** (2 directories):
- `skill-z3-research/SKILL.md` - Thin wrapper for Z3 research
- `skill-z3-implementation/SKILL.md` - Thin wrapper for Z3 implementation

**Rules**: No z3-specific rules file found in ModelChecker

**Context** (from ModelChecker):
- `project/z3/README.md` - Z3 context overview with type reference and utilities
- `project/z3/domain/z3-api.md` - Z3 Python API reference
- `project/z3/domain/smt-patterns.md` - SMT-LIB patterns and tactics
- `project/z3/patterns/constraint-generation.md` - Constraint building patterns
- `project/z3/patterns/bitvector-operations.md` - BitVec state manipulation

### 6. Python Extension Contents (from ModelChecker)

**Source**: `/home/benjamin/Projects/ModelChecker/.claude/`

**Agents** (2 files):
- `python-research-agent.md` - Python/ModelChecker research agent (324 lines)
- `python-implementation-agent.md` - Python implementation agent with testing (371 lines)

**Skills** (2 directories):
- `skill-python-research/SKILL.md` - Thin wrapper for Python research
- `skill-python-implementation/SKILL.md` - Thin wrapper for Python implementation

**Rules**: No python-specific rules file found (neovim-lua.md handles Lua, but Python has none)

**Context** (from ModelChecker):
- `project/python/README.md` - Python context overview with package structure
- `project/python/domain/model-checker-api.md` - ModelChecker package API
- `project/python/domain/theory-lib-patterns.md` - Theory library conventions
- `project/python/patterns/semantic-evaluation.md` - Semantic evaluation patterns
- `project/python/standards/code-style.md` - Python coding style

### 7. Content Adaptation Requirements

Files from reference projects need adaptation before inclusion in extensions:

**Path references**: Agent and skill files reference project-specific paths (e.g., `Code/src/model_checker/`, `Theories/Logos/latex/`) that need to be generalized or made relative.

**Project-specific content**: Some context files contain project-specific knowledge (e.g., `logos-macros.md`, `dtt-foundation-standard.md`, `model-checker-api.md`) that should be either:
- Excluded from extensions (too specific)
- Generalized to be language-generic
- Marked as optional/example content

**Agent file size**: Lean agents are very large (260-515 lines). The extension system should copy these as-is since they are self-contained agent definitions.

**MCP integration notes**: Lean extension includes MCP server configuration (lean-lsp). Z3 could optionally include z3_mcp if configured. Python could optionally include mcp_python_toolbox.

### 8. Manifest Configuration for New Extensions

Based on the existing manifest pattern, new extensions need:

**typst/manifest.json**:
```json
{
  "name": "typst",
  "version": "1.0.0",
  "description": "Typst document development with single-pass compilation",
  "language": "typst",
  "provides": {
    "agents": ["typst-implementation-agent.md"],
    "skills": ["skill-typst-implementation"],
    "rules": [],
    "context": ["project/typst"]
  }
}
```

**z3/manifest.json**:
```json
{
  "name": "z3",
  "version": "1.0.0",
  "description": "Z3 SMT solver development with constraint pattern support",
  "language": "z3",
  "provides": {
    "agents": ["z3-research-agent.md", "z3-implementation-agent.md"],
    "skills": ["skill-z3-research", "skill-z3-implementation"],
    "rules": [],
    "context": ["project/z3"]
  }
}
```

**python/manifest.json**:
```json
{
  "name": "python",
  "version": "1.0.0",
  "description": "Python development with pytest integration and type checking",
  "language": "python",
  "provides": {
    "agents": ["python-research-agent.md", "python-implementation-agent.md"],
    "skills": ["skill-python-research", "skill-python-implementation"],
    "rules": [],
    "context": ["project/python"]
  }
}
```

## Decisions

1. **Content scope**: Include agents, skills, rules, and context from reference projects; exclude hooks and scripts that are project-setup specific (e.g., systemd timers, session logging)
2. **Project-specific content**: Exclude highly project-specific context (logos-macros.md, model-checker-api.md, dtt-foundation-standard.md) but include generalizable language patterns
3. **Math/logic context for lean**: Include math and logic context in the lean extension since these are domain knowledge files used by lean agents for mathematical proofs
4. **Agent adaptation**: Copy agents as-is from reference projects -- the project-specific paths in them serve as examples and templates; users will need to customize after installation
5. **Typst research agent**: Include typst-research-agent.md from Logos/Theory since it exists there
6. **LaTeX research agent**: The ProofChecker has latex-research-agent.md which should also be included

## Recommendations

### Implementation Approach

**Phase 1: Create missing extension directories** (z3, typst, python)
- Create directory structure matching the lean/latex/neovim pattern
- Create manifest.json, claudemd-section.md, index-entries.json for each

**Phase 2: Populate lean extension subdirectories**
- Copy agents from ProofChecker (lean-research-agent.md, lean-implementation-agent.md)
- Copy skills from ProofChecker (4 skill directories)
- Copy commands from ProofChecker (lake.md, lean.md)
- Copy rules from ProofChecker (lean4.md)
- Copy context from ProofChecker (lean4/, math/, logic/ directories)
- Copy scripts from ProofChecker (setup-lean-mcp.sh, verify-lean-mcp.sh)

**Phase 3: Populate latex extension subdirectories**
- Copy agent from ProofChecker (latex-implementation-agent.md)
- Copy skill from ProofChecker (skill-latex-implementation/)
- Add rules from ProofChecker (latex.md)
- Copy context from ProofChecker (latex/ directory, excluding logos-macros.md)
- Add latex-research-agent.md and skill-latex-research if available

**Phase 4: Create typst extension with contents**
- Create all skeleton files (manifest, claudemd, index-entries)
- Copy agent from Logos/Theory (typst-implementation-agent.md)
- Copy skill from Logos/Theory (skill-typst-implementation/)
- Copy context from Logos/Theory (typst/ directory, excluding project-specific standards)
- Add typst-research-agent.md and skill-typst-research if available

**Phase 5: Create z3 extension with contents**
- Create all skeleton files
- Copy agents from ModelChecker (z3-research-agent.md, z3-implementation-agent.md)
- Copy skills from ModelChecker (skill-z3-research/, skill-z3-implementation/)
- Copy context from ModelChecker (z3/ directory)

**Phase 6: Create python extension with contents**
- Create all skeleton files
- Copy agents from ModelChecker (python-research-agent.md, python-implementation-agent.md)
- Copy skills from ModelChecker (skill-python-research/, skill-python-implementation/)
- Copy context from ModelChecker (python/ directory)

### File Count Estimate

| Extension | Agents | Skills | Commands | Rules | Context Files | Scripts | Total |
|-----------|--------|--------|----------|-------|---------------|---------|-------|
| lean | 2 | 4 | 2 | 1 | ~37 | 2 | ~48 |
| latex | 2 | 2 | 0 | 1 | ~8 | 0 | ~13 |
| typst | 2 | 2 | 0 | 0 | ~10 | 0 | ~14 |
| z3 | 2 | 2 | 0 | 0 | ~5 | 0 | ~9 |
| python | 2 | 2 | 0 | 0 | ~5 | 0 | ~9 |
| **Total** | **10** | **12** | **2** | **2** | **~65** | **2** | **~93** |

## Risks & Mitigations

1. **Risk**: Agent files contain project-specific paths (e.g., `Code/src/model_checker/`)
   - **Mitigation**: These serve as templates; document that users should customize after installation

2. **Risk**: Context files may be too project-specific
   - **Mitigation**: Curate carefully -- include only generalizable language patterns; exclude Logos-specific, ModelChecker-specific content

3. **Risk**: Large number of files (~93) makes implementation complex
   - **Mitigation**: Break into 6 phases, validate each extension independently

4. **Risk**: Skills reference project-specific state.json paths and task management patterns
   - **Mitigation**: These are part of the .claude task management system pattern, which is consistent across all projects

5. **Risk**: Math and logic context files are domain-specific, not purely lean-language
   - **Mitigation**: Include in lean extension since lean is used for mathematical proofs; users doing non-math Lean work can remove these

## Appendix

### Search Queries Used
- File listing of all three reference project .claude/ directories
- Reading of all agent, skill, and rules files relevant to the five target languages
- Reading of all context README files for lean4, z3, python, typst, latex
- Examination of existing extension manifest.json, claudemd-section.md, and index-entries.json patterns
- Git log analysis for task 99 (extension system creation) and task 100

### Reference File Locations

| Language | Agents Source | Skills Source | Rules Source | Context Source |
|----------|-------------|--------------|-------------|---------------|
| lean | ProofChecker/.claude/agents/ | ProofChecker/.claude/skills/ | ProofChecker/.claude/rules/lean4.md | ProofChecker/.claude/context/project/lean4/ |
| latex | ProofChecker/.claude/agents/ | ProofChecker/.claude/skills/ | ProofChecker/.claude/rules/latex.md | ProofChecker/.claude/context/project/latex/ |
| typst | Logos/Theory/.claude/agents/ | Logos/Theory/.claude/skills/ | (none) | Logos/Theory/.claude/context/project/typst/ |
| z3 | ModelChecker/.claude/agents/ | ModelChecker/.claude/skills/ | (none) | ModelChecker/.claude/context/project/z3/ |
| python | ModelChecker/.claude/agents/ | ModelChecker/.claude/skills/ | (none) | ModelChecker/.claude/context/project/python/ |
