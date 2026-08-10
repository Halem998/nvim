# Research Report: Task #666

**Task**: 666 - Create cslib context and rules
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:05:00Z
**Effort**: ~1 hour implementation
**Dependencies**: lean extension (already loaded)
**Sources/Inputs**:
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md` (328 lines, fully read)
- `/home/benjamin/Projects/cslib/NOTATION.md` (46 lines, fully read)
- `/home/benjamin/Projects/cslib/ORGANISATION.md` (230 lines, fully read)
- `/home/benjamin/Projects/cslib/Cslib/Init.lean` (first 22 lines)
- `/home/benjamin/Projects/cslib/lakefile.toml` (full)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/rules/lean4.md` (reference)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/context/project/lean4/standards/lean4-style-guide.md` (reference)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md` (reference)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/index-entries.json` (target paths)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/rules/cslib.md` (current stub)
**Artifacts**: `specs/666_create_cslib_context_rules/reports/01_cslib-context-rules-research.md`
**Standards**: report-format.md

---

## Executive Summary

- CSLib is a Lean 4 computer science formalization library under the `leanprover` organization with two pillars: CS formalization (algorithms, logics, semantics) and code reasoning (Boole verification infrastructure)
- Key CSLib-specific conventions: PR titles require `feat|fix|doc|style|refactor|test|chore|perf:` prefix; all files must import `Cslib.Init`; notation must use typeclasses for reusability
- CI has four distinct linting layers: syntax linters (build-time), `lake lint` (environment), `lake exe lint-style` (text), and `lake exe checkInitImports` (import completeness)
- The cslib extension context directory is empty; all 10 files declared in `index-entries.json` need to be created from scratch
- The `cslib.md` rules file is a stub needing full content

---

## Context & Scope

This research gathers source material to populate the CSLib extension at
`/home/benjamin/.config/nvim/.claude/extensions/cslib/`. The extension scaffold (manifest,
index-entries, agents, skills) already exists. The context directory and rules file are empty/stubs.

Files to create (from `index-entries.json`):

```
context/project/cslib/
├── domain/
│   ├── contributing-standards.md
│   ├── notation-conventions.md
│   └── project-organization.md
├── patterns/
│   ├── proof-structure.md
│   └── reuse-first.md
├── standards/
│   ├── ci-pipeline.md
│   ├── pr-conventions.md
│   └── mathlib-style.md
└── tools/
    ├── lake-commands.md
    └── linters.md
```

Plus the rules file: `rules/cslib.md`

---

## Findings

### From CONTRIBUTING.md

**Variable Names**
- Domain-appropriate variable names are encouraged (e.g., `State` for LTS state types, `μ` for transition labels)
- Follow mathlib conventions otherwise: `x`, `y`, `n`, `m` for local variables; `h`, `h1`, `h2` or descriptive `hpos` for hypotheses; `α`, `β` for generic types

**Proof Style**
- Make proofs easy to follow
- Golfing and automation are welcome when proofs remain readable and compilation speed is not noticeably affected
- Golfed proofs should not sacrifice readability

**Notation Policy**
- For common concepts (reductions, transitions), find an existing typeclass
- New notation applicable to multiple types: keep locally scoped OR create a new typeclass
- Avoid notation that is not scoped or typeclass-backed if it may apply to other types

**Documentation**
- Document all definitions and theorems
- When formalizing a published resource concept, reference the resource in the doc comment

**Contribution Model**
- PRs require at least one relevant maintainer approval
- Major developments must be discussed on Zulip first (cross-cutting abstractions, new frameworks, major refactors, new frontend/backend components, new working groups)
- AI usage must be disclosed in PR description (which tools, how used)

**Working Groups**
- CSLib is organized into topic-focused working groups
- To join: post on relevant CSLib Zulip channel with background and intended contribution
- To propose new working group: write short proposal on Zulip or GitHub issue with Topic, Execution Plan, Collaborators

**Design Principle: Reuse**
- Central focus: reusable abstractions and their consistent usage across the library
- New definitions should instantiate existing abstractions (e.g., a labelled transition system should use `LTS`)

### From NOTATION.md

**Equivalences**
- Alpha equivalence: `m =α n`
- Bisimilarity: `p ~[lts] q`

**Option A (main notation)**
- Reduction: `m → n`
- Multi-step reduction: `m ↠ n` (extra arrowhead = reflexive-transitive closure)
- Transition: `p [μ]→ q`
- Multi-step transition: `p [μs]↠ q`
- Saturated transitions: `p [μ]⇒ q`
- Multi-step saturated transitions: `p [μs]➾ q`
- Alternative semantics suffix: `m →[cbv] n`, `p [μ]→[late] q`

**Option B**
- Uses `*` for reflexive-transitive closure: `m →* n`, `p [μs]→* q`, `p [μs]⇒* q`

**Option C (triangle heads)**
- Distinguishes arrows from Lean implication `→`
- Reduction: `m ⭢ n`, Multi-step: `m ⯮ n`
- Transition: `p μ⭢ q`, Multi-step: `p [μs]⯮ q`
- Saturated: `p μ⇒ q`, Multi-step: `p μs➾ q`
- Alternative suffix: `m ⭢cbv n`, `p μ⭢late q`

### From ORGANISATION.md

**Top-Level Namespace Structure**
- `Cslib/` root with subdirectories: `Foundations/`, `Logics/`, `Languages/`, `Computability/`, `Algorithms/`, `Crypto/`, `MachineLearning/`, `Probability/`
- `CslibTests/` for tests
- `Cslib.lean` = barrel import of all library files

**Foundations/ (shared infrastructure)**
- `Logic/` - abstract proof systems, connective typeclasses (`HasBot`, `HasImp`, `HasBox`)
- `Data/` - general data structures (`HasFresh`, `Relation`, `ListHelpers`, `RelatesInSteps`)
- `Semantics/` - operational semantics (`LTS/`, `FLTS/`)
- `Syntax/` - abstract syntax infrastructure (`HasAlphaEquiv`, `HasWellFormed`, `HasSubstitution`)
- `Lint/` - custom linting rules

**Logics/ Dependency Hierarchy**
```
Foundations/Logic  (abstract infrastructure)
       │
       ▼
  Propositional
       │
       ├──────────────┐
       ▼              ▼
     Modal         Temporal
       │              │
       └──────┬───────┘
              ▼
           Bimodal
```

**Namespace Convention**
- `Cslib.Logic` spans both `Foundations/Logic/` and `Logics/`
- Infrastructure in `Foundations/`, specific logics in `Logics/`

### From Cslib/Init.lean

```lean
module -- shake: keep-downstream, shake: keep-all

public import Cslib.Foundations.Lint.Basic
public import Mathlib.Init
public import Mathlib.Tactic.Common
```

- Sets up default linting and tactics for entire library
- Has special `shake:` comments to preserve imports against lake shake
- All CSLib files must import this (checked by `lake exe checkInitImports`)

### From lakefile.toml

**Project Configuration**
- `name = "cslib"`, `version = "0.1.0"`
- `defaultTargets = ["Cslib"]`
- `testDriver = "CslibTests"` -> used by `lake test`
- `lintDriver = "batteries/runLinter"` -> used by `lake lint`

**Linter Options**
- `weak.linter.mathlibStandardSet = true` - enables mathlib standard linters
- `weak.linter.flexible = true`
- Disabled due to incompatibility: `pythonStyle`, `checkInitImports`, `allScriptsDocumented`, `unicodeLinter`

**Dependency**
- `mathlib` at specific rev `d90090f647cae4f4ad4da99c0ac8bab2ca8c34ab`

**Executable**
- `lake exe checkInitImports` - from `scripts/CheckInitImports.lean`

### From CI Pipeline (CONTRIBUTING.md)

**PR Title Format**
- Must begin with: `feat`, `fix`, `doc`, `style`, `refactor`, `test`, `chore`, or `perf`
- Followed by colon
- Optional parenthetical for area: `feat(Logics): add temporal logic soundness`

**Testing (local)**
```bash
lake test                      # runs CslibTests/
lake exe checkInitImports      # checks all files import Cslib.Init
```

**Linting (local)**
```bash
lake build                     # also runs syntax linters
lake lint                      # or use #lint command for environment linters
lake exe lint-style            # text linters
lake exe lint-style --fix      # auto-fix text lint issues
```

**Import Check**
```bash
lake exe mk_all --module       # ensures Cslib.lean imports all files
```

**Import Minimization**
```bash
lake shake --add-public --keep-implied --keep-prefix   # check minimized imports
lake shake --add-public --keep-implied --keep-prefix --fix  # auto-fix
```

**Special Shake Comments** (from Init.lean)
```lean
-- shake: keep-downstream   -- preserve for downstream modules
-- shake: keep-all          -- preserve for all callers
```

### From Lean Extension Reference (lean4.md)

The `cslib.md` rules file should inherit the structure of `lean4.md`:
- CRITICAL blocked MCP tools section
- Essential MCP tools table
- Search decision tree
- Workflow pattern
- Build commands

CSLib-specific additions needed:
- CSLib-specific CI verification order
- Import requirement (`Cslib.Init`)
- PR title convention
- Naming conventions from CONTRIBUTING.md

---

## Decisions

1. **Rules file structure**: Extend lean4.md pattern with CSLib-specific additions. Keep blocked tools section identical. Add CSLib CI section after build commands.

2. **Notation conventions file**: Encode all three notation options (A, B, C) from NOTATION.md verbatim. Agents need to know which option a specific file uses before contributing notation.

3. **Linters file vs ci-pipeline file**: Keep separate per index-entries.json. `ci-pipeline.md` = order and commands; `linters.md` = detailed tool descriptions and options.

4. **reuse-first.md vs proof-structure.md**: `reuse-first.md` focuses on typeclass instantiation philosophy; `proof-structure.md` focuses on proof style, golfing policy, readability standards.

5. **mathlib-style.md**: Since CSLib explicitly follows mathlib style, this file should be a concise reference pointing to the upstream URL and capturing the CSLib-specific additions/differences.

6. **project-organization.md**: Directly encode the ORGANISATION.md module tree. This is the most important file for agents placing new code.

7. **contributing-standards.md**: Encode CONTRIBUTING.md standards (variable names, AI usage, documentation, working groups, contribution model). Not CI-specific content.

---

## Content to Encode

### rules/cslib.md

```markdown
---
paths: "**/*.lean"
---

# CSLib Development Rules

## CRITICAL: Blocked MCP Tools

**DO NOT call**: `lean_diagnostic_messages` (hangs), `lean_file_outline` (unreliable)

Use `lean_goal` + `lake build` instead.

## Essential MCP Tools
[same table as lean4.md]

## Search Tools (Rate Limited)
[same table as lean4.md]

## Search Decision Tree
[same as lean4.md]

## Workflow Pattern
[same as lean4.md]

## CSLib-Specific Requirements

### Import Requirement
Every CSLib file MUST begin with:
```lean
import Cslib.Init
```

### PR Title Format
`feat|fix|doc|style|refactor|test|chore|perf[(<area>)]: <description>`

### CI Verification Order
1. `lake build` - syntax linters
2. `lake exe checkInitImports` - all files import Cslib.Init
3. `lake lint` - environment linters
4. `lake exe lint-style` - text linters (or `--fix`)
5. `lake test` - run CslibTests/
6. `lake exe mk_all --module` - after adding new files
7. `lake shake --add-public --keep-implied --keep-prefix` - import minimization

### Naming Conventions
- Domain-appropriate variable names (e.g., `State` for LTS state types, `μ` for transition labels)
- Otherwise follow mathlib: `x`, `y`, `n`, `m`; `h`, `hpos`, `hlt` for hypotheses; `α`, `β` for types

### Notation Policy
- Use existing typeclasses for common concepts (reductions, transitions)
- New multi-type notation: locally scope or create typeclass

### AI Disclosure
If AI tools were used, disclose in PR description: which tools, how used.

## Common Tactics
[inherited from lean4.md]

## Build Commands
[lean4.md content plus CSLib specifics]
```

### domain/contributing-standards.md

Key sections:
- Variable names (domain-specific encouraged)
- Proof style (readable > golfed; golfing OK if readable + fast)
- Notation policy (typeclass-backed or locally scoped)
- Documentation requirements (doc comments, published resource citations)
- Contribution model (PR approval, major changes need Zulip first, AI disclosure)
- Working groups (how to join, how to propose)

### domain/notation-conventions.md

Full encoding of NOTATION.md:
- Alpha equivalence: `m =α n`
- Bisimilarity: `p ~[lts] q`
- Three notation options (A, B, C) with full symbol tables
- How to determine which option a file uses (check existing notation in file)

### domain/project-organization.md

Full encoding of ORGANISATION.md:
- Top-level directory structure
- Foundations/ tree (detailed)
- Logics/ dependency hierarchy
- Namespace convention (Cslib.Logic spans Foundations/Logic + Logics/)
- Module placement guide

### patterns/proof-structure.md

- Proof readability standards
- Golfing policy: OK when readable + no compilation slowdown
- Named intermediate steps with `have`
- Automation: bounded `simp only`, `omega`, `ring` preferred over unbounded `simp`
- Tactic block format
- When to use term vs tactic mode

### patterns/reuse-first.md

- Central design principle: instantiate existing abstractions
- Example: new LTS implementation should use `LTS` typeclass
- Where to find abstractions: `Foundations/Semantics/LTS/`, `Foundations/Syntax/`
- Typeclass hierarchy: `HasAlphaEquiv`, `HasWellFormed`, `HasSubstitution`, `HasFresh`
- Notation reuse: find existing typeclass before defining new notation

### standards/ci-pipeline.md

Complete ordered CI checklist with commands:
1. Build (syntax linters)
2. checkInitImports
3. lake lint
4. lint-style
5. lake test
6. mk_all (when adding files)
7. lake shake (import minimization)

### standards/pr-conventions.md

- Title format: `feat|fix|doc|style|refactor|test|chore|perf[(<area>)]: <description>`
- AI disclosure requirement
- Review process: at least one relevant maintainer
- Major changes: coordinate on Zulip first
- What counts as major: cross-cutting abstractions, new frameworks, major refactors, new frontend/backend components, new working groups

### standards/mathlib-style.md

- Reference: https://leanprover-community.github.io/contribute/style.html
- Key mathlib conventions that apply to CSLib
- CSLib additions: domain-specific variable names, proof readability, golfing policy

### tools/lake-commands.md

All lake commands for CSLib:
- `lake build` - build (runs syntax linters)
- `lake build Module.Name` - scoped build (preferred)
- `lake test` - run CslibTests/
- `lake lint` - environment linters (or `#lint` in editor)
- `lake exe lint-style` - text linters
- `lake exe lint-style --fix` - auto-fix text lint
- `lake exe checkInitImports` - verify all files import Cslib.Init
- `lake exe mk_all --module` - update Cslib.lean barrel import
- `lake shake --add-public --keep-implied --keep-prefix` - minimize imports
- `lake shake --add-public --keep-implied --keep-prefix --fix` - auto-fix imports
- `lake clean && lake build` - clean rebuild

### tools/linters.md

Three linter categories:
1. **Syntax linters** - run during `lake build`, appear as warnings inline
2. **Environment linters** - `lake lint` or `#lint` command
3. **Text linters** - `lake exe lint-style`

Special topics:
- `lake shake` - import minimization (not technically a linter but related)
- Shake comments: `-- shake: keep-downstream`, `-- shake: keep-all`
- Disabled linters (from lakefile.toml): pythonStyle, checkInitImports (lakefile), allScriptsDocumented, unicodeLinter

---

## Risks & Mitigations

- **Notation options A/B/C**: Files may use different options. Agents must check existing notation in a file before adding new notation. Include this check in the notation conventions context file.
- **lake shake incompatibility**: Disabled in lakefile but available as standalone command. Document the distinction to avoid confusion.
- **checkInitImports disabled in lakefile**: The lakefile disables `weak.linter.checkInitImports` but the `lake exe checkInitImports` standalone exe is still active and required. Clarify this in ci-pipeline.md.

---

## Context Extension Recommendations

None for this task - this task IS creating the context extension.

---

## Appendix

### File Paths

**Rules file** (to update):
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/rules/cslib.md`

**Context files** (to create, all under `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/`):
- `project/cslib/domain/contributing-standards.md`
- `project/cslib/domain/notation-conventions.md`
- `project/cslib/domain/project-organization.md`
- `project/cslib/patterns/proof-structure.md`
- `project/cslib/patterns/reuse-first.md`
- `project/cslib/standards/ci-pipeline.md`
- `project/cslib/standards/pr-conventions.md`
- `project/cslib/standards/mathlib-style.md`
- `project/cslib/tools/lake-commands.md`
- `project/cslib/tools/linters.md`

**Source documents** (read-only reference):
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md`
- `/home/benjamin/Projects/cslib/NOTATION.md`
- `/home/benjamin/Projects/cslib/ORGANISATION.md`
- `/home/benjamin/Projects/cslib/Cslib/Init.lean`
- `/home/benjamin/Projects/cslib/lakefile.toml`

### Key CSLib Links

- Website: https://www.cslib.io/
- GitHub: https://github.com/leanprover/cslib
- Mathlib style guide: https://leanprover-community.github.io/contribute/style.html
- AI usage policy: https://leanprover-community.github.io/contribute/index.html#use-of-ai
- Zulip: https://leanprover.zulipchat.com/
- CSLib whitepaper: https://arxiv.org/abs/2602.04846
- CS as Infrastructure paper: https://arxiv.org/abs/2602.15078
