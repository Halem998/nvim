# Research Report: Task #706

**Task**: 706 - Revise pr-description-format.md based on real-world PR description patterns
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Effort**: ~30 min
**Dependencies**: None
**Sources/Inputs**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` (current template)
- `cslib/specs/188_first_propositional_upstream_pr/pr-description.md` (real-world model, current)
- `cslib/specs/archive/198_submit_propositional_upstream_pr/pr-description.md` (real-world model, archived)
- `cslib/specs/archive/145_subpr_2_1_lukasiewicz_primitives/pr-description.md` (earlier PR, diff-stat format)
- `cslib/specs/archive/059_pr1_foundations_logic/pr-description-v2.md` (large PR, table format)
**Artifacts**: - This report
**Standards**: report-format.md

---

## Executive Summary

- The current template is missing four sections present in real-world PRs: Breaking Changes, Relationship to Other PRs, Contribution Roadmap, and the linked-file Changed Files variant.
- The real-world PR at `188_first_propositional_upstream_pr/pr-description.md` is the most current and feature-complete model, containing all four additions in mature form.
- Section ordering in the real-world PR differs from the template: Breaking Changes comes after Changed Files, Relationship to Other PRs appears before Contribution Roadmap, and the AI disclosure is named "AI Tools Used" rather than "AI Disclosure".
- The Changed Files section in real-world PRs uses a clean per-line linked format (`[File](link) -- **New/Modified**: desc`) for small PRs, which the template does not document.
- Title format in the real-world PR documents the H1 as `# PR Description: {conventional-commit-title}` rather than just `# {conventional-commit-title}` as the template specifies. The template should be updated to acknowledge both patterns or clarify the intended form.

---

## Context & Scope

**File to revise**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`

The task calls for four additions plus two harmonization changes:
1. Breaking Changes section (required when applicable)
2. Relationship to Other PRs section (required when applicable)
3. Contribution Roadmap section (optional)
4. Revised Changed Files format (linked format for small PRs; existing diff-stat for large PRs)
5. Title format standardization
6. AI disclosure section name harmonization

---

## Findings

### Current Document Structure

The current template has this section order:

```
## Required Sections
  1. Title (H1)
  2. Summary
  3. Context / Motivation (when applicable)
  4. File-by-file change summary
  5. AI Disclosure (always last)

## Optional Sections
  - Design Rationale
  - Dependency Graph
  - Verification (large PRs only)

## What NOT to Include
```

### Real-World PR Structure (pr-description at 188_first_propositional_upstream_pr)

The current production PR (`188_first_propositional_upstream_pr/pr-description.md`) uses:

```
# PR Description: feat(Logics/Propositional): ...  ← Title with "PR Description:" prefix

## Summary

## Design Rationale (merged Design sections as subsections: Why bot, Naming, Why Has*)

## Relationship to Other PRs
  ### PR #607
  ### PR #536
  ### PR #587

## Contribution Roadmap
  (numbered list of 9 planned PRs with scope summaries)
  (link to dev branch)

## Changed Files
  (linked format: `[File](link) — **New/Modified**: desc`)

## Breaking Changes
  (bullet list of renamed identifiers, removed constraints, removed instances)
  (Files affected upstream: ...)

## AI Tools Used
```

The archived version (`archive/198_submit_propositional_upstream_pr/pr-description.md`) is identical in structure with the same section order and format.

### Comparison: What Template Is Missing

| Section | Template Status | Real-World Usage |
|---------|----------------|-----------------|
| Breaking Changes | Not mentioned | Present, required when applicable; comes after Changed Files |
| Relationship to Other PRs | Only "stacked on" pattern under Context | Full subsection with named PRs; separate from Context |
| Contribution Roadmap | Not mentioned | Present as optional numbered list with dev branch link |
| Changed Files (linked) | Not documented | Used in small PRs; diff-stat used in older/larger PRs |

### Changed Files Format Analysis

**Current template documents** (large PR, 10+ files): diff-stat code block + H3 per file or markdown table.

**Real-world small-PR format** (4 files in production PR):
```markdown
## Changed Files

- [`Cslib/Foundations/Logic/Connectives.lean`](Cslib/Foundations/Logic/Connectives.lean) — **New**: connective typeclass hierarchy (`HasBot`, `HasImp`, `HasAnd`, `HasOr`, `PropositionalConnectives`)
- [`Cslib/Logics/Propositional/Defs.lean`](Cslib/Logics/Propositional/Defs.lean) — **Modified**: five-primitive `Proposition` type, constraint-free derived connectives, typeclass instances
```

Pattern: `- [\`filename\`](path) — **New|Modified**: description`

The dash separator is an em dash (—), not a double hyphen. The task description specified `--` (double hyphen), but the real-world PR uses `—` (em dash). The implementation should match the real-world convention.

**Older large-PR format** (from `archive/059_pr1_foundations_logic/pr-description-v2.md`, 25 files):
- H2 "File Inventory" with H3 subsections and tables (Role column)
- This is a variant of the template's markdown table format

### Breaking Changes Section Format

From the production PR:
```markdown
## Breaking Changes

- `Proposition.impl` renamed to `Proposition.imp`
- `andE₁`/`andE₂`/`orI₁`/`orI₂` renamed to `andE1`/`andE2`/`orI1`/`orI2`
- `[Bot Atom]` constraints removed from `IPL`, `IsIntuitionistic`, `IsClassical`, and
  related instances and theorems
- `[Inhabited Atom]` constraint removed from `Proposition.top`, `derivationTop`,
  `derivableIn_top`, `derivable_iff_equiv_top`
- `instBotProposition` and `instInhabitedOfBot` removed; new constraint-free instances added

Files affected upstream: `Defs.lean`, `NaturalDeduction/Basic.lean` (only consumers)
```

Key characteristics:
- Bullet list of specific renamed identifiers, removed constraints, removed instances
- Trailing "Files affected upstream:" line naming downstream consumers
- Placement: after Changed Files, before AI Disclosure

### Relationship to Other PRs Section Format

From the production PR:
```markdown
## Relationship to Other PRs

### PR #607

PR #607 by @fmontesi introduces per-operator typeclass files under `Operators/`, covering both
propositional and modal connectives. Our `Connectives.lean` overlaps in the propositional case
(`HasBot`, `HasImp`, `HasAnd`, `HasOr`). If PR #607 merges first, we can align our definitions
with its typeclass names and file structure; if ours merges first, #607 can import from
`Connectives.lean` for the propositional operators.

### PR #536
...
### PR #587
...
```

Key characteristics:
- H2 heading "Relationship to Other PRs" (not "Context")
- H3 subsection per named PR, identified by number
- Covers lateral PRs touching same files or related concerns — independent of stacked-on ordering
- Distinct from the Context section's "stacked on" pattern (which is about merge dependencies)

### Contribution Roadmap Section Format

From the production PR:
```markdown
## Contribution Roadmap

This PR is the first in a planned series contributing our propositional logic foundations upstream:

1. **This PR**: Connective typeclasses + five-primitive formula type + natural deduction update
2. **PR 2**: Hilbert proof system (`ProofSystem/`) with minimal/intuitionistic/classical axiom
   predicates and sequent derivability
3. **PR 3**: ND-Hilbert equivalence for all three logic strengths
...

All results in this roadmap have been completed in our development branch:
https://github.com/benbrastmckie/cslib/tree/main/Cslib/Logics/Propositional
```

Key characteristics:
- Numbered list with bolded PR labels (`**This PR**`, `**PR 2**`, etc.)
- Brief scope summary per planned PR
- Trailing link to development branch
- Optional section — only used for multi-PR contribution series

### Title Format Discrepancy

**Template** says: H1 heading is just `# {conventional commit title}`

**Real-world PR (188, 198)**: H1 is `# PR Description: {conventional commit title}`

**Older PRs (059, 145)**: Use `# {conventional commit title}` directly or have `**Title**: ...` as a field.

The "PR Description:" prefix appears to be a convention adopted in the more recent PRs (as of the 188/198 era). The template should document both the file-heading pattern and the GitHub PR title as the same conventional-commit string, making clear that `# PR Description: ...` is the file H1 while the actual GitHub PR title field does not include the "PR Description:" prefix.

### AI Disclosure Naming

**Template**: `## AI Disclosure`

**Real-world PRs (188, 198)**: `## AI Tools Used`

**Older PRs (145)**: `## AI Disclosure`

The two most recent production PRs use "AI Tools Used". The template should be updated to match this and note the naming change.

---

## Recommendations

### Section Ordering (Revised Required Sections)

The updated template should document this ordering for required sections:

```
1. Title (H1)
2. Summary
3. Context / Motivation (when applicable — stacked PRs, Zulip, literature)
4. Design Rationale (when applicable — optional, can appear here or after Summary)
5. Relationship to Other PRs (when applicable — lateral/concurrent PRs)
6. Contribution Roadmap (optional — multi-PR series)
7. Changed Files
8. Breaking Changes (when applicable)
9. AI Tools Used (always last)
```

Note: Design Rationale appears as optional in the current template but occurs between Summary and Relationship to Other PRs in the production PR. The template should clarify its position.

### Changed Files: Two Documented Formats

**Format A: Linked list (small PRs, fewer than ~10 files)**

```markdown
## Changed Files

- [`Cslib/Path/To/File.lean`](Cslib/Path/To/File.lean) — **New**: description of what was added
- [`Cslib/Path/To/Other.lean`](Cslib/Path/To/Other.lean) — **Modified**: description of changes
```

- Em dash (—) separator, not double hyphen (--)
- Bold **New** or **Modified** label
- Inline description following the label

**Format B: Diff-stat + H3 (large PRs, 10+ files)**

Keep existing format as documented.

**Format C: Markdown table (large PRs with many files)**

Keep existing format as documented.

### Breaking Changes Section Template

```markdown
## Breaking Changes

- `{OldIdentifier}` renamed to `{NewIdentifier}`
- `{ConstraintName}` constraint removed from `{TypeOrTheorem}` and related instances
- `{InstanceName}` removed; replaced by `{NewInstanceName}`

Files affected upstream: `{File1.lean}`, `{File2.lean}` (only consumers)
```

Include when: any identifier is renamed, any typeclass constraint is removed, any public instance is deleted, or any function signature changes.

### Relationship to Other PRs Section Template

```markdown
## Relationship to Other PRs

### PR #{N}

{Description of what PR #N does and how it relates to this PR. State: which files overlap,
whether changes are orthogonal or dependent, and what coordination is needed.}

### PR #{M}

{Same structure.}
```

Include when: concurrent PRs exist that touch the same files or related concerns. This is distinct from "stacked on" (merge ordering), which stays in Context. Relationship to Other PRs is for lateral coordination.

### Contribution Roadmap Section Template

```markdown
## Contribution Roadmap

{Introductory sentence stating this is N-th PR in a series and what the series contributes.}

1. **This PR**: {scope summary}
2. **PR 2**: {scope summary}
3. **PR 3**: {scope summary}
...

All results in this roadmap have been completed in our development branch:
{URL to development branch}
```

Include when: this PR is part of a multi-PR planned contribution series.

### Title Format

The current template documents the H1 as:
```
# {conventional commit title}
```

The production PR uses:
```
# PR Description: {conventional commit title}
```

Recommendation: document the "PR Description:" prefix as the standard H1 for the PR description file (distinguishes the file heading from the GitHub PR title). The GitHub PR title field itself uses just the conventional commit string without the prefix.

### AI Disclosure Naming

Rename `## AI Disclosure` to `## AI Tools Used` throughout the template to match the two most recent production PRs.

---

## Decisions

- Breaking Changes section placement: after Changed Files, before AI Tools Used. This is what the production PR uses.
- Relationship to Other PRs is a top-level H2 section, not nested under Context. Context retains only the "stacked on" pattern for merge ordering.
- The em dash (—) is the correct separator in the linked Changed Files format, not "--" as specified in the task description. Use em dash to match the real-world convention.
- Title H1 format: document "PR Description: {title}" as the file heading convention based on production PRs 188 and 198.
- AI disclosure naming: use "AI Tools Used" throughout.

---

## Risks & Mitigations

- **Risk**: Renaming "AI Disclosure" to "AI Tools Used" diverges from older PRs (e.g., PR 145). Mitigation: note in template that both names are acceptable; "AI Tools Used" is preferred for new PRs.
- **Risk**: "PR Description:" prefix in H1 may not be desired for all PRs. Mitigation: clarify it is the file-document heading convention, not the GitHub PR title field.

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`
- `/home/benjamin/Projects/cslib/specs/188_first_propositional_upstream_pr/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/archive/198_submit_propositional_upstream_pr/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/archive/145_subpr_2_1_lukasiewicz_primitives/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/archive/059_pr1_foundations_logic/pr-description-v2.md`

### Key Observation

The note at `/home/benjamin/Projects/cslib/specs/198_submit_propositional_upstream_pr/` does not exist (the task referenced a path that wasn't present), but `/home/benjamin/Projects/cslib/specs/archive/198_submit_propositional_upstream_pr/pr-description.md` exists and is essentially identical in content to the `188_first_propositional_upstream_pr/pr-description.md` — both contain the same four new sections in mature form.
