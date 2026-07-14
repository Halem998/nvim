---
paths: "**/*.lean"
---

# CSLib Development Rules

## CRITICAL: Blocked MCP Tools

**DO NOT call**: `lean_diagnostic_messages` (hangs), `lean_file_outline` (unreliable)

Use `lean_goal` + `lake build` instead.

## Essential MCP Tools

| Tool | Purpose |
|------|---------|
| `lean_goal` | Proof state at position - MOST IMPORTANT |
| `lean_hover_info` | Type signatures + docs |
| `lean_completions` | IDE autocomplete |
| `lean_local_search` | Fast local declaration search |
| `lean_verify` | Axiom check + source scan (use fully qualified name) |
| `lean_multi_attempt` | Test tactics without editing - use BEFORE applying edits |

## Search Tools (Rate Limited)

| Tool | Rate | Query Style |
|------|------|-------------|
| `lean_leansearch` | 3/30s | Natural language |
| `lean_loogle` | 3/30s | Type pattern |
| `lean_leanfinder` | 10/30s | Semantic concept |
| `lean_state_search` | 3/30s | Goal -> closing lemmas |
| `lean_hammer_premise` | 3/30s | Goal -> simp/aesop hints |

## Search Decision Tree

1. "Does X exist locally?" -> `lean_local_search`
2. "Lemma that says X" -> `lean_leansearch`
3. "Type pattern match" -> `lean_loogle`
4. "Lean name for concept" -> `lean_leanfinder`
5. "What closes this goal?" -> `lean_state_search`

## Workflow Pattern

1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
2. During proof (inner loop): `lean_goal` constantly; `lean_multi_attempt` BEFORE editing; `lean_verify` for axiom/sorry check
3. After editing a step: `lean_goal` to confirm; `lean_verify` if axiom safety needed
4. Phase-end: `lake build Module.Name` (scoped); fall back to `lake build` if module name unknown
5. Final verification only: `lake build` (full project)

## CSLib-Specific Requirements

### Import Requirement

Every CSLib file MUST begin with:

```lean
import Cslib.Init
```

This is enforced by `lake exe checkInitImports`. The `Cslib.Init` module sets up default
linting rules and common tactics for the entire library.

### PR Title Format

PR titles must begin with one of the following conventional commit prefixes followed by a colon:

```
feat|fix|doc|style|refactor|test|chore|perf[(<area>)]: <description>
```

Examples:
- `feat(Logics): add temporal logic soundness proof`
- `fix: correct substitution lemma in HasSubstitution`
- `doc(Foundations): document LTS typeclass interface`

### CSLib CI Verification Order

Run in this order before submitting a PR:

0. `lake exe cache get` -- fetch Mathlib .olean cache (once per branch; prevents 30-45 min rebuild)
1. `lake build` -- syntax linters (runs during build)
2. `lake exe checkInitImports` -- all files import `Cslib.Init`
3. `lake lint` -- environment linters (or use `#lint` command in editor)
4. `lake exe lint-style` -- text linters (or `--fix` to auto-fix)
5. `lake test` -- run `CslibTests/`
6. `lake exe mk_all --module` -- update `Cslib.lean` barrel import (only when adding new files)
7. `lake shake --add-public --keep-implied --keep-prefix` -- import minimization (or `--fix`)

### Naming Conventions

Domain-appropriate variable names are encouraged:
- In `Lts` library: `State` for state types, `μ` for transition labels
- Otherwise follow mathlib conventions:
  - Local variables: `x`, `y`, `n`, `m`
  - Hypotheses: `h`, `h1`, `h2`, `hpos`, `hlt`
  - Generic types: `α`, `β`

### Notation Policy

- For common concepts (reductions, transitions): find an existing typeclass before defining new notation
- New notation applicable to multiple types: keep locally scoped OR create a typeclass
- Avoid unscoped notation that is not backed by a typeclass when it may apply to other types
- Check the existing notation in a file before adding new notation (files may use Option A, B, or C -- see notation-conventions.md)

### AI Disclosure

If AI tools were used in writing the PR, disclose in the PR description:
- Which tools were used
- How they were used

This follows the Mathlib AI usage policy and helps reviewers spot tool-specific errors.

## Common Tactics

Automation: `simp`, `aesop`, `omega`, `ring`, `decide`
Structure: `intro`, `apply`, `exact`, `constructor`, `cases`, `induction`
Rewriting: `rw`, `simp only`, `conv`

## Build Commands

Prefer scoped: `lake build Module.Name` | Full project: `lake build` | Clean: `lake clean && lake build`

**When to use each**:
- `lake build Module.Name` -- phase-end verification (preferred; faster)
- `lake build` -- final verification only (after all phases complete)

## Literature Fidelity

When a literature source (paper, textbook, proof sketch) is referenced in the task or plan:

- **Follow the source step-by-step** -- do not seek shortcuts or alternative proofs
- **FORBIDDEN**: Using `simp`/`omega`/`aesop` to bypass steps the literature handles explicitly
- **FORBIDDEN**: Abandoning the literature's approach after a single tactic failure
- **FORBIDDEN**: Mixing literature steps with novel steps without flagging the deviation
- **Escalation**: Re-read source -> try alternative Lean encodings -> check for unstated lemmas -> flag gap to user
- **No literature referenced?** First-principles mode: all tactics and strategies permitted freely

## Vacuous Definitions (PROHIBITED)

The following definition patterns are **strictly prohibited**:

```lean
def Foo := True
theorem Foo := trivial
instance Foo := True
```

These are semantically equivalent to `sorry`. If you cannot implement `X`, mark the phase
**[BLOCKED]** and document the blocker. Do NOT create vacuous placeholders.
