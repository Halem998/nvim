# CSLib Mathlib Style Reference

CSLib follows the mathlib style guide for coding and documentation. This file summarizes the
upstream reference and documents CSLib-specific additions.

## Upstream Reference

**Primary style guide**: https://leanprover-community.github.io/contribute/style.html

Read the mathlib style guide before contributing. CSLib follows it as the baseline with
the additions documented below.

## Key Mathlib Conventions Applicable to CSLib

### Naming

- Theorem names use lowercase with underscores: `foo_bar_baz`
- Type names use CamelCase: `LabelledTransitionSystem`
- Namespace names use CamelCase: `Cslib.Logic.Modal`
- Instances and `@[simp]` lemma names should be descriptive about their content

### Documentation

- Use `/-! ... -/` for module docstrings at the top of files
- Use `/-- ... -/` for definition and theorem docstrings
- Module docstrings should include: `## Main definitions`, `## Main results`,
  `## Notation` (if any), `## Implementation notes` (if needed), `## References` (if any)

### Imports

- List imports at the top of the file
- Use `import` only for what is actually needed
- Prefer narrow imports over barrel imports during development

### Proof Style

- Prefer `exact` over `trivial` or `tauto` when the proof is explicit
- Use `simp only [...]` with explicit lemma list rather than bare `simp`
- Use `omega` for integer/natural number arithmetic

## CSLib-Specific Additions

### Domain Variable Names

CSLib explicitly permits domain-appropriate variable names that differ from mathlib defaults.
See `domain/contributing-standards.md` for examples.

### Proof Readability over Golfing

CSLib's golfing policy (in `patterns/proof-structure.md`) is compatible with mathlib's
but adds an explicit compilation-speed condition: golfing that noticeably slows compilation
is not acceptable even if the proof is readable.

### Notation Reuse

CSLib's notation is managed with reusability in mind. Unlike mathlib (which targets a single
library), CSLib hosts many languages, so notation conflicts are a real concern. See
`domain/notation-conventions.md` for the three notation options and `patterns/reuse-first.md`
for the typeclass reuse principle.

### Import Requirement

All CSLib files must import `Cslib.Init` (not a mathlib requirement). This is enforced by
`lake exe checkInitImports`. See `standards/ci-pipeline.md` for the full CI workflow.

### Citation Format

CSLib uses CamelCase BibKeys (`Blackburn2001`) rather than mathlib's lowercase
(`bourbaki1966`). This is a deliberate project choice. See `standards/citation-conventions.md`
for the full citation format.
