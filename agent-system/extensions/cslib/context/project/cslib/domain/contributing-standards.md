# CSLib Contributing Standards

Standards and conventions for contributing to CSLib. Derived from CONTRIBUTING.md.

## Variable Names

Domain-appropriate variable names are encouraged. The mathlib convention is the baseline, but
deviate from it when the domain calls for something clearer.

**Domain-specific examples**:
- In the `Lts` library: `State` for types of states, `μ` for transition labels
- In logic modules: `φ`, `ψ`, `χ` for formulas; `w`, `v` for worlds/states

**Default mathlib conventions**:
- Local variables: `x`, `y`, `n`, `m`
- Hypotheses: `h`, `h1`, `h2`; descriptive names like `hpos`, `hlt` for clarity
- Generic type variables: `α`, `β`

## Proof Style and Golfing

Make proofs easy to follow.

Golfing and automation are welcome provided:
1. Proofs remain **reasonably readable** after golfing
2. Compilation time does not **noticeably slow down**

If a golfed proof is hard to follow or slows down compilation, prefer the more explicit version.
Use named intermediate steps with `have` to document proof intent.

## Notation Policy

CSLib hosts many languages with their own syntax and semantics. Notation is managed with
reusability and maintainability in mind.

**Rules**:
- For common concepts (reductions, transitions in operational semantics): find an existing
  typeclass that fits the need before defining new notation
- New notation that can apply to different types (e.g., syntax or semantics of other languages):
  - Keep it **locally scoped**, or
  - **Create a new typeclass** so the notation is reusable

Do not define unscoped notation that could conflict with other languages in the library.

**Check first**: Before adding notation to a file, check what notation option (A, B, or C) the
file already uses. See `domain/notation-conventions.md` for the three options.

## Documentation Requirements

Document all definitions and theorems to ease both use and reviewing.

**When formalizing a published resource**:
- Reference the resource in the documentation comment
- Use the canonical citation format: `[Author Initial(s). Surname, *Title*][BibKey]`
- See `standards/citation-conventions.md` for the full citation format

**Module docstrings** should include:
- `## Main definitions` -- key types and definitions
- `## Main results` -- key theorems
- `## Notation` -- if the file introduces notation
- `## Implementation notes` -- design decisions and non-obvious choices
- `## References` -- citations to published resources (if applicable)

## Contribution Model

### Pull Request Process

- Every PR must be approved by at least one relevant maintainer
- See [GOVERNANCE.md](https://github.com/leanprover/cslib/blob/main/GOVERNANCE.md) for the
  current list of maintainers
- Questions can be asked on the [Lean prover Zulip chat](https://leanprover.zulipchat.com/)

### Major Changes: Coordinate First on Zulip

For any major development, discuss on Zulip or open a GitHub issue **before** submitting a PR.
This avoids rework and aligns scope, dependencies, and library placement.

**What counts as major**:
- New cross-cutting abstractions, typeclasses, or notation schemes
- New foundational frameworks
- Major refactorings
- New frontend or backend components for CSLib's verification infrastructure
- Proposals for new working groups

### AI Disclosure

CSLib follows the [Mathlib AI usage policy](https://leanprover-community.github.io/contribute/index.html#use-of-ai).

If you use AI tools, disclose in the PR description:
- Which tools were used
- How they were used

This helps reviewers spot tool-specific errors (tools make different mistakes than humans).

## Working Groups

CSLib is structured to support multiple topic-focused efforts via **working groups** (informal or
formal). Working groups have a topic scope and a Zulip topic/channel for coordination.

### Joining a Working Group

Post on the relevant CSLib Zulip channel describing:
- Your background
- What you want to contribute

### Proposing a New Working Group

Write a short proposal (Zulip message or GitHub issue) with:
- **Topic**: What do you want to do?
- **Execution plan**: What is your execution plan?
- **Collaborators**: If others are already planning to work on the topic, list them

The goal is lightweight proposals while keeping CSLib coherent and reusable.

## Key Project Links

- Website: https://www.cslib.io/
- GitHub issues + PRs: https://github.com/leanprover/cslib
- Contribution board: https://github.com/leanprover/cslib/projects?query=is%3Aopen
- Community discussion: https://leanprover.zulipchat.com/
- CSLib whitepaper: https://arxiv.org/abs/2602.04846
- CS as Infrastructure paper: https://arxiv.org/abs/2602.15078
