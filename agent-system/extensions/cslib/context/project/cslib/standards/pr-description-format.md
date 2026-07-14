# CSLib PR Description Format

Canonical format for CSLib pull request descriptions. Based on established patterns
from the cslib project PR history (PRs #635, #637, and subsequent sub-PRs).

## Required Sections

All CSLib PRs must include these sections, in this order:

1. Title (H1)
2. Summary
3. Context / Motivation (when applicable, no fixed slot — after Summary when stacked PRs or Zulip discussions apply)
4. Design Rationale (when applicable)
5. Relationship to Other PRs (when applicable)
6. Contribution Roadmap (optional)
7. Changed Files
8. Breaking Changes (when applicable)
9. AI Tools Used (always last)

---

### 1. Title (H1 heading)

The document heading uses the "PR Description:" prefix to distinguish it from the
GitHub PR title field. The GitHub PR title field uses just the conventional commit
string without the prefix.

```
# PR Description: {conventional commit title}
```

The conventional commit title uses the format from `pr-conventions.md`:
```
{feat|fix|doc|style|refactor|test|chore|perf}[({area})]: {description}
```

Examples:
```
# PR Description: feat(Logics/Temporal): temporal logic formula type with primitives and derived operators
# PR Description: refactor: Proposition type to Lukasiewicz convention
# PR Description: fix(Foundations): correct substitution lemma in HasSubstitution
```

---

### 2. Summary

2-4 sentences describing what the PR adds or changes. Name the key types, theorems,
modules, or definitions introduced. For large PRs, include scope (N files, ~M lines).

```markdown
## Summary

{2-4 sentences. Name key constructs. State scope for large PRs.}
```

---

### 3. Context / Motivation (when applicable)

Include when any of the following apply:
- The PR is stacked on another unmerged PR
- There is a relevant Zulip discussion
- The design choice requires literature support

```markdown
## Context

{Stacked PR declaration:}
This PR is **stacked on #{NNN}** ("{PR title}"), which introduces {what it provides}.
{What this PR needs from that PR.} Please review/merge #{NNN} first.

{Zulip link:}
**Zulip topic**: [{channel/topic description}]({URL})

{Literature references:}
{Author, A. & Author, B. (year). *Title*. Publisher. {Specific chapter/section if relevant.}}
```

---

### 4. Design Rationale (when applicable)

Use for novel design decisions that require explanation. Name the section after the
specific design question.

Include when:
- The primitive/representation choice is non-obvious and needs justification
- Literature references support the design
- The choice will affect all downstream PRs

```markdown
## Why {X} as the primitives
## Design: {component} architecture
## Argument convention: {name}
```

---

### 5. Relationship to Other PRs (when applicable)

Include when: concurrent PRs exist that touch the same files or related concerns. This
is distinct from "stacked on" (merge ordering) in Context -- Relationship to Other PRs
covers lateral coordination with concurrent/parallel PRs.

```markdown
## Relationship to Other PRs

### PR #{N}

{Description of what PR #N does and how it relates to this PR. State: which files overlap,
whether changes are orthogonal or dependent, and what coordination is needed.}

### PR #{M}

{Same structure for each related PR.}
```

Format:
- H2 heading "Relationship to Other PRs"
- H3 subsection per named PR, identified by number
- Each subsection describes overlap, dependency direction, and coordination strategy

---

### 6. Contribution Roadmap (optional)

Include when: this PR is part of a multi-PR planned contribution series.

```markdown
## Contribution Roadmap

{Introductory sentence stating this is the N-th PR in a series and what the series contributes.}

1. **This PR**: {scope summary}
2. **PR 2**: {scope summary}
3. **PR 3**: {scope summary}
...

All results in this roadmap have been completed in our development branch:
{URL to development branch}
```

Format:
- Numbered list with bolded PR labels (`**This PR**`, `**PR 2**`, etc.)
- Brief scope summary per planned PR (1-2 lines)
- Trailing link to development branch (optional but recommended)
- Only used for multi-PR contribution series

---

### 7. Changed Files

Always present. Choose the format based on PR size.

**Format A: Linked list (small PRs, fewer than ~10 files)**

```markdown
## Changed Files

- [`Path/To/File.lean`](Path/To/File.lean) — **New**: description of what was added
- [`Path/To/Other.lean`](Path/To/Other.lean) — **Modified**: description of changes
```

Format A notes:
- Em dash (—) separator, not double hyphen (--)
- Bold **New** or **Modified** label
- Inline description following the label
- Use for PRs with fewer than ~10 changed files

**Format B: Diff-stat + H3 per file (large PRs, 10+ files)**

````markdown
## Changed Files

{Paste git diff --stat output in a code fence:}
```
 File1.lean   | N ++++++++++++
 File2.lean   | M +++---
 N files changed, X insertions(+), Y deletions(-)
```

### {File1.lean} (+N[, -M] [, NEW])

- {Bullet describing the key change in this file}
- {Another key change}

### {File2.lean} (+N, -M)

- {Bullet describing the key change}
````

**Format C: Markdown table (large PRs with many files)**

```markdown
| File | Lines | Role |
|------|------:|------|
| `Path/To/File.lean` | N | Brief role description |
```

**Format selection guidance**:
- Format A (linked list): fewer than ~10 changed files
- Format B (diff-stat + H3): 10+ files, where per-file detail matters
- Format C (table): 10+ files, where a compact overview suffices

---

### 8. Breaking Changes (when applicable)

Include when: any identifier is renamed, any typeclass constraint is removed, any public
instance is deleted, or any function signature changes.

```markdown
## Breaking Changes

- `{OldIdentifier}` renamed to `{NewIdentifier}`
- `{ConstraintName}` constraint removed from `{TypeOrTheorem}` and related instances
- `{InstanceName}` removed; replaced by `{NewInstanceName}`

Files affected upstream: `{File1.lean}`, `{File2.lean}` (only consumers)
```

Format:
- Bullet list of specific renamed identifiers, removed constraints, or removed instances
- Trailing "Files affected upstream:" line naming downstream consumers
- Placed after Changed Files, before AI Tools Used

---

### 9. AI Tools Used (always last)

Required for all CSLib PRs per the Mathlib AI usage policy. Always the last section.

Note: Older PRs used the heading "AI Disclosure"; "AI Tools Used" is the preferred
heading for new PRs. Both names are acceptable.

```markdown
## AI Tools Used

This PR was prepared with the assistance of Claude Code (Anthropic). The AI tool was used for:
- Drafting and extracting files from a development branch to create a clean PR branch
- Running CI verification commands
- Drafting this PR description

All Lean code was written by the {author(s) — names} and verified to compile cleanly on the PR branch.
```

Short variant (for smaller PRs):

```markdown
## AI Tools Used

This PR was prepared with the assistance of Claude Code (Anthropic), used for drafting/extracting
files from a development branch, running CI verification commands, and drafting this description.
All Lean code was written by the author ({name}) and verified to compile on the PR branch.
```

---

## Optional Sections

### Dependency Graph

For large PRs with complex import structures:

````markdown
## Dependency Graph

```
ModuleA
    +-- ModuleB
        +-- ModuleC
```
````

### Verification (large PRs only)

Use only for large PRs to document that sorry-free verification was performed.
Not a checklist — state results:

```markdown
## Verification

- `lake build`: 0 errors (N jobs)
- `.claude/scripts/lean-sorry-census.sh`: `sorry_count: 0` across all contributed files
- CI validation suite passed: `lake test`, `lake shake`, `lake exe checkInitImports`, `lake lint`, `lake exe lint-style`
```

---

## What NOT to Include

**No CI checklist in the PR body.** Do not add:
```markdown
## CI
- [ ] `lake build` passes
- [ ] `lake lint` passes
```

CI runs automatically on GitHub Actions after the PR is submitted. Including a self-reported
checklist in the body is redundant and the boxes are written before CI has actually run.
The `/pr` command verifies CI locally before submission; that verification is not claimed
in the PR description itself.
