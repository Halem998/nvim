# Implementation Plan: Task #666

- **Task**: 666 - Create cslib context and rules
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (lean extension already loaded; cslib extension scaffold exists)
- **Research Inputs**: specs/666_create_cslib_context_rules/reports/01_cslib-context-rules-research.md
- **Artifacts**: plans/01_cslib-context-rules-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create 12 files for the CSLib extension: 1 rules file (`rules/cslib.md`) and 11 context files organized under `context/project/cslib/` in domain/, patterns/, standards/, and tools/ subdirectories. Content is derived from CSLib source documents (CONTRIBUTING.md, NOTATION.md, ORGANISATION.md, Init.lean, lakefile.toml) as captured in the research report. The rules file extends the lean4.md pattern with CSLib-specific CI, import, naming, and PR conventions.

### Research Integration

Key findings integrated from the research report:
- CSLib CI pipeline has 7 ordered verification steps (lake build -> checkInitImports -> lint -> lint-style -> test -> mk_all -> shake)
- Three notation option sets (A/B/C) from NOTATION.md must be fully documented
- Project organization spans Foundations/ (shared infrastructure) and domain-specific directories (Logics/, Languages/, etc.)
- PR titles require conventional commit prefixes; AI usage must be disclosed
- Reuse-first design principle: new definitions should instantiate existing typeclasses

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create complete `rules/cslib.md` with blocked tools, MCP tools, search tree, CI verification order, and CSLib-specific conventions
- Create all 10 context files declared in `index-entries.json` with accurate, actionable content
- Ensure content is derived from CSLib source documents, not fabricated

**Non-Goals**:
- Modifying the extension manifest or index-entries.json (already correct)
- Creating agent definitions or skill files (separate task scope)
- Testing the context files against live CSLib development (post-implementation validation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Notation options A/B/C may change upstream | M | L | Document all three options verbatim; note to check existing file notation before contributing |
| checkInitImports confusion (disabled in lakefile but exe still required) | H | M | Explicitly clarify distinction in ci-pipeline.md and linters.md |
| lean4.md rules may drift from cslib.md over time | M | M | cslib.md inherits structure but documents CSLib-specific additions; blocked tools section identical |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create rules/cslib.md [COMPLETED]

**Goal**: Replace the stub rules file with full CSLib development rules inheriting lean4.md structure.

**Tasks**:
- [ ] Write `rules/cslib.md` with frontmatter `paths: "**/*.lean"`, blocked MCP tools, essential MCP tools table, search tools table, search decision tree, workflow pattern, CSLib-specific requirements (import requirement, PR title format, CI verification order, naming conventions, notation policy, AI disclosure), common tactics, and build commands

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/rules/cslib.md` - Replace stub with full content

**Verification**:
- File has frontmatter with `paths: "**/*.lean"`
- Contains CRITICAL blocked MCP tools section
- Contains CSLib CI verification order (7 steps)
- Contains import requirement (`Cslib.Init`)
- Contains PR title format specification

---

### Phase 2: Create domain/ context files [COMPLETED]

**Goal**: Create the three domain knowledge files covering contributing standards, notation conventions, and project organization.

**Tasks**:
- [ ] Create `domain/contributing-standards.md` with variable names, proof style, notation policy, documentation requirements, contribution model (PR approval, Zulip coordination), AI disclosure, and working groups
- [ ] Create `domain/notation-conventions.md` with all three notation options (A, B, C), equivalences, transition notation, and guidance on determining which option a file uses
- [ ] Create `domain/project-organization.md` with top-level namespace structure, Foundations/ tree, Logics/ dependency hierarchy, namespace convention, and module placement guide

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/domain/contributing-standards.md` - Create new
- `.claude/extensions/cslib/context/project/cslib/domain/notation-conventions.md` - Create new
- `.claude/extensions/cslib/context/project/cslib/domain/project-organization.md` - Create new

**Verification**:
- All three files exist with proper markdown structure
- notation-conventions.md contains all three option tables (A, B, C)
- project-organization.md contains the Logics/ dependency hierarchy diagram
- contributing-standards.md covers AI disclosure requirement

---

### Phase 3: Create patterns/ context files [COMPLETED]

**Goal**: Create the two pattern files covering proof structure and reuse-first design philosophy.

**Tasks**:
- [ ] Create `patterns/proof-structure.md` with proof readability standards, golfing policy, named intermediate steps, automation preferences (bounded simp only, omega, ring), tactic block format, and term vs tactic mode guidance
- [ ] Create `patterns/reuse-first.md` with central design principle, typeclass instantiation examples, where to find abstractions (Foundations/Semantics/LTS/, Foundations/Syntax/), typeclass hierarchy documentation, and notation reuse policy

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/patterns/proof-structure.md` - Create new
- `.claude/extensions/cslib/context/project/cslib/patterns/reuse-first.md` - Create new

**Verification**:
- proof-structure.md documents golfing policy with conditions (readable + no compilation slowdown)
- reuse-first.md references specific typeclass names (HasAlphaEquiv, HasWellFormed, HasSubstitution, HasFresh)

---

### Phase 4: Create standards/ context files [COMPLETED]

**Goal**: Create the three standards files covering CI pipeline, PR conventions, and mathlib style.

**Tasks**:
- [ ] Create `standards/ci-pipeline.md` with complete ordered CI checklist (7 steps), each with command, purpose, and when to run; clarify checkInitImports distinction (disabled in lakefile vs standalone exe still required)
- [ ] Create `standards/pr-conventions.md` with title format, AI disclosure requirement, review process, Zulip coordination for major changes, and definition of "major changes"
- [ ] Create `standards/mathlib-style.md` with reference URL, key mathlib conventions applicable to CSLib, and CSLib-specific additions/differences
- [ ] Create `standards/citation-conventions.md` adapted from `/home/benjamin/Projects/cslib/.claude/context/standards/citation-conventions.md` — covers CamelCase BibKey format (e.g. `Blackburn2001`), canonical citation display in module docstrings (`## References` section), `references.bib` workflow, internal cross-reference format, legacy pattern conversion rules, and line-wrapping conventions

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md` - Create new
- `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` - Create new
- `.claude/extensions/cslib/context/project/cslib/standards/mathlib-style.md` - Create new

**Verification**:
- ci-pipeline.md has 7 numbered steps with exact commands
- ci-pipeline.md clarifies checkInitImports lakefile vs exe distinction
- pr-conventions.md includes conventional commit prefix list
- mathlib-style.md links to upstream style guide URL
- citation-conventions.md documents BibKey naming (CamelCase) and canonical display format

---

### Phase 5: Create tools/ context files [COMPLETED]

**Goal**: Create the two tools files covering lake commands and linters.

**Tasks**:
- [ ] Create `tools/lake-commands.md` with all lake commands for CSLib (build, build Module.Name, test, lint, lint-style, lint-style --fix, checkInitImports, mk_all --module, shake, shake --fix, clean && build)
- [ ] Create `tools/linters.md` with three linter categories (syntax, environment, text), lake shake documentation, shake comments (keep-downstream, keep-all), and disabled linters list from lakefile.toml

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md` - Create new
- `.claude/extensions/cslib/context/project/cslib/tools/linters.md` - Create new

**Verification**:
- lake-commands.md lists all 11 lake commands with descriptions
- linters.md documents all three linter categories
- linters.md explains shake comments syntax

---

### Phase 6: Verification [COMPLETED]

**Goal**: Validate all 11 files exist, have correct structure, and contain no placeholder content.

**Tasks**:
- [ ] Verify all 11 files exist at expected paths
- [ ] Check that rules/cslib.md has proper YAML frontmatter
- [ ] Confirm no files contain stub or placeholder text
- [ ] Validate directory structure matches index-entries.json declarations

**Timing**: 5 minutes

**Depends on**: 2, 3, 4, 5

**Files to modify**:
- None (read-only verification)

**Verification**:
- `find .claude/extensions/cslib/context/project/cslib -name "*.md" | wc -l` returns 11
- `grep -l "Stub" .claude/extensions/cslib/rules/cslib.md` returns empty (no stub text)
- All files have content beyond a minimal header

---

## Testing & Validation

- [ ] All 12 files exist at declared paths
- [ ] `rules/cslib.md` has YAML frontmatter with `paths: "**/*.lean"`
- [ ] No file contains "Stub" or "TODO" placeholder text
- [ ] Context file count matches declarations (11 context files)
- [ ] Each context file has a level-1 heading and at least one substantive section
- [ ] citation-conventions.md accurately reflects BibKey CamelCase format and references.bib workflow

## Artifacts & Outputs

- `.claude/extensions/cslib/rules/cslib.md` - Full CSLib development rules
- `.claude/extensions/cslib/context/project/cslib/domain/contributing-standards.md`
- `.claude/extensions/cslib/context/project/cslib/domain/notation-conventions.md`
- `.claude/extensions/cslib/context/project/cslib/domain/project-organization.md`
- `.claude/extensions/cslib/context/project/cslib/patterns/proof-structure.md`
- `.claude/extensions/cslib/context/project/cslib/patterns/reuse-first.md`
- `.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md`
- `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md`
- `.claude/extensions/cslib/context/project/cslib/standards/mathlib-style.md`
- `.claude/extensions/cslib/context/project/cslib/standards/citation-conventions.md`
- `.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md`
- `.claude/extensions/cslib/context/project/cslib/tools/linters.md`

## Rollback/Contingency

All files are new creations (except the rules stub replacement). Rollback is straightforward:
- Delete all files under `.claude/extensions/cslib/context/project/cslib/`
- Restore `rules/cslib.md` to its stub content
- No other files in the repository are modified by this task
