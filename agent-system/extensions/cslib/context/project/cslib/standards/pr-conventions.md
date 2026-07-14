# CSLib Pull Request Conventions

Standards for submitting pull requests to CSLib. Derived from CONTRIBUTING.md.

## PR Title Format

PR titles must begin with one of the following conventional commit prefixes followed by a
colon:

```
feat|fix|doc|style|refactor|test|chore|perf[(<area>)]: <description>
```

### Prefix Meanings

| Prefix | Use for |
|--------|---------|
| `feat` | New features, formalizations, definitions, theorems |
| `fix` | Bug fixes, incorrect proofs, broken imports |
| `doc` | Documentation improvements, docstring additions |
| `style` | Formatting, linting fixes, style conformance only |
| `refactor` | Code restructuring without behavior change |
| `test` | Adding or fixing tests in `CslibTests/` |
| `chore` | Build system, CI, dependency updates |
| `perf` | Performance improvements (compilation speed, proof size) |

### Area Qualifier (Optional)

Add a parenthetical qualifier to specify which area of the library the PR affects:

```
feat(Logics): add temporal logic soundness proof
fix(Foundations): correct substitution lemma in HasSubstitution
doc(Languages/Boole): document verification condition generator
refactor(Bimodal): reorganize metalogic directory structure
```

### Examples

```
feat(Logics): prove completeness for modal logic K
fix: correct alpha-equivalence definition for pi-calculus
doc(Foundations/Syntax): add docstrings to HasAlphaEquiv
test: add tests for LTS bisimulation
chore: update mathlib dependency to latest
```

## Review Process

- Every PR requires approval from **at least one relevant maintainer**
- See [GOVERNANCE.md](https://github.com/leanprover/cslib/blob/main/GOVERNANCE.md) for the
  current maintainer list
- Questions during review can be asked on the
  [Lean prover Zulip chat](https://leanprover.zulipchat.com/)

## Coordinate First for Major Changes

For any **major development**, discuss on Zulip or open a GitHub issue **before** submitting
a PR. This avoids rework by aligning scope, dependencies, and library placement upfront.

**What counts as major** (requires prior coordination):
- New cross-cutting abstractions, typeclasses, or notation schemes
- New foundational frameworks
- Major refactorings affecting multiple modules
- New frontend or backend components for CSLib's verification infrastructure
- Proposals for new working groups

**Straightforward contributions** (no prior coordination needed):
- Bug fixes with clear scope
- Documentation improvements
- Tests for existing functionality
- Proofs of existing open TODOs
- Extensions to existing formalizations in a single module

## AI Disclosure Requirement

If you used AI tools (e.g., Claude, Copilot, GPT) when writing the PR, disclose this in the
PR description. Explain:
- **Which tools** you used
- **How you used them** (e.g., proof search, code generation, documentation drafting)

This follows the [Mathlib AI usage policy](https://leanprover-community.github.io/contribute/index.html#use-of-ai).
Reviewers can then focus on areas where AI tools are known to make characteristic mistakes.

## PR Description Format

See [pr-description-format.md](pr-description-format.md) for the canonical PR description template and section-by-section guidance.
