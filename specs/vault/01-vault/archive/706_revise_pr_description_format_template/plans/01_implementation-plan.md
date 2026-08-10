# Implementation Plan: Task #706

- **Task**: 706 - Revise pr-description-format.md with four additions plus harmonization
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/706_revise_pr_description_format_template/reports/01_research-pr-format-revision.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Revise the CSLib PR description format template at `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` to incorporate four new sections (Breaking Changes, Relationship to Other PRs, Contribution Roadmap, dual-format Changed Files) and harmonize existing elements (title format, AI disclosure rename, section ordering) based on patterns observed in production PRs 188 and 198.

### Research Integration

The research report analyzed five real-world PR descriptions across the cslib project history and identified four missing sections, two naming discrepancies, and one section-ordering divergence. All additions are templated from the most recent production PR (188_first_propositional_upstream_pr/pr-description.md). The em dash separator in the linked Changed Files format was confirmed as the real-world convention (not double-hyphen as initially specified in the task description).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add Breaking Changes section with template and inclusion criteria
- Add Relationship to Other PRs section with H3-per-PR structure
- Add Contribution Roadmap section with numbered list format
- Document dual Changed Files format (linked for small PRs, diff-stat for large)
- Harmonize title format to `# PR Description: {conventional commit title}`
- Rename AI Disclosure to AI Tools Used throughout
- Reorder sections to match production PR convention

**Non-Goals**:
- Modifying pr-conventions.md (commit message format is separate)
- Changing the "What NOT to Include" section
- Adding new examples beyond what the template sections require
- Modifying any other extension files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Section ordering change confuses existing users | L | L | Keep existing sections recognizable; document ordering clearly |
| Older PRs used "AI Disclosure" name | L | M | Note both names acceptable in template; prefer "AI Tools Used" for new PRs |
| "PR Description:" prefix may seem redundant | L | L | Clarify it distinguishes the file heading from the GitHub PR title field |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Harmonization (title, AI disclosure rename, section order) [NOT STARTED]

**Goal**: Update the existing document structure to reflect the correct title format, rename AI Disclosure, and reorder sections to match production convention.

**Tasks**:
- [ ] Change the H1 title format from `# {conventional commit title}` to `# PR Description: {conventional commit title}`
- [ ] Add clarification that the "PR Description:" prefix is for the file heading; the GitHub PR title field uses just the conventional commit string
- [ ] Rename all occurrences of "AI Disclosure" to "AI Tools Used"
- [ ] Update the section numbering in "Required Sections" to reflect new ordering:
  1. Title (H1)
  2. Summary
  3. Design Rationale (when applicable)
  4. Relationship to Other PRs (when applicable)
  5. Contribution Roadmap (optional)
  6. Changed Files
  7. Breaking Changes (when applicable)
  8. AI Tools Used (always last)
- [ ] Move "Design Rationale" from Optional Sections into the Required Sections list (marked "when applicable") since it has a defined position in the ordering
- [ ] Update the example in the AI Disclosure/AI Tools Used section to use the new heading name
- [ ] Note that "Context / Motivation" remains optional and can appear after Summary when stacked PRs or Zulip discussions are relevant (it does not have a fixed numbered slot since it only applies in specific cases)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Title format, section name, ordering

**Verification**:
- Section numbering lists 8 items in correct order
- No remaining occurrences of "AI Disclosure" (except optional backward-compat note)
- Title example shows "PR Description:" prefix

---

### Phase 2: Add Breaking Changes section [NOT STARTED]

**Goal**: Add a Breaking Changes section template with format specification and inclusion criteria.

**Tasks**:
- [ ] Add a new subsection under Required Sections for "Breaking Changes" (position 7, after Changed Files)
- [ ] Include the following template content:

```markdown
### 7. Breaking Changes (when applicable)

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
```

- [ ] Verify the section number matches the ordering established in Phase 1

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Add Breaking Changes subsection

**Verification**:
- Breaking Changes template is present with bullet-list format
- "Files affected upstream:" line is documented
- Inclusion criteria are stated

---

### Phase 3: Add Relationship to Other PRs section [NOT STARTED]

**Goal**: Add a Relationship to Other PRs section template distinguishing it from the Context section's "stacked on" pattern.

**Tasks**:
- [ ] Add a new subsection under Required Sections for "Relationship to Other PRs" (position 4, after Design Rationale)
- [ ] Include the following template content:

```markdown
### 4. Relationship to Other PRs (when applicable)

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
```

- [ ] Add a clarification note distinguishing this from Context's "stacked on" pattern
- [ ] Verify section position matches ordering from Phase 1

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Add Relationship to Other PRs subsection

**Verification**:
- Section is present with H3-per-PR structure
- Distinction from Context "stacked on" is clearly documented
- Inclusion criteria are stated

---

### Phase 4: Add Contribution Roadmap section [NOT STARTED]

**Goal**: Add a Contribution Roadmap section template for multi-PR series contributions.

**Tasks**:
- [ ] Add a new subsection under Required Sections for "Contribution Roadmap" (position 5, after Relationship to Other PRs)
- [ ] Include the following template content:

```markdown
### 5. Contribution Roadmap (optional)

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
```

- [ ] Verify section position matches ordering from Phase 1

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Add Contribution Roadmap subsection

**Verification**:
- Section is present with numbered-list format
- Bold labels pattern is documented
- Development branch link convention is noted
- Marked as optional

---

### Phase 5: Revise Changed Files format (dual format) [NOT STARTED]

**Goal**: Document both the linked-list format (for small PRs) and the existing diff-stat format (for large PRs) as the dual Changed Files format.

**Tasks**:
- [ ] Restructure the existing "File-by-file change summary" section (rename to "Changed Files")
- [ ] Add Format A (linked list for small PRs, fewer than 10 files) as the primary format:

```markdown
### 6. Changed Files

**Format A: Linked list (small PRs, fewer than ~10 files)**

```markdown
## Changed Files

- [`Path/To/File.lean`](Path/To/File.lean) — **New**: description of what was added
- [`Path/To/Other.lean`](Path/To/Other.lean) — **Modified**: description of changes
```

- Em dash (—) separator, not double hyphen (--)
- Bold **New** or **Modified** label
- Inline description following the label
- Use for PRs with fewer than ~10 changed files
```

- [ ] Keep Format B (diff-stat + H3 per file) for large PRs with the existing documentation
- [ ] Keep Format C (markdown table) for large PRs with many files
- [ ] Add guidance on when to use each format: linked list for fewer than ~10 files; diff-stat or table for 10+ files

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Restructure Changed Files section with dual format

**Verification**:
- Format A (linked list) is documented with em dash separator
- Format B (diff-stat) is preserved from existing template
- Format C (table) is preserved from existing template
- Threshold guidance (fewer than ~10 files) is stated
- Section title is "Changed Files" (not "File-by-file change summary")

---

### Phase 6: Verification [NOT STARTED]

**Goal**: Verify the complete revised document is internally consistent and all changes are correctly applied.

**Tasks**:
- [ ] Read the modified file end-to-end
- [ ] Verify section ordering matches: Summary, Design Rationale, Relationship to Other PRs, Contribution Roadmap, Changed Files, Breaking Changes, AI Tools Used
- [ ] Verify no remaining "AI Disclosure" occurrences (except backward-compat note if included)
- [ ] Verify title format shows "PR Description:" prefix
- [ ] Verify all four new sections have inclusion criteria documented
- [ ] Verify Changed Files section documents all three formats (A, B, C) with usage guidance
- [ ] Verify Context/Motivation section is preserved as optional with "stacked on" pattern
- [ ] Check for any orphaned references to old section numbers

**Timing**: 15 minutes

**Depends on**: 2, 3, 4, 5

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Any consistency fixes

**Verification**:
- Document reads coherently from top to bottom
- No contradictions between section ordering list and actual section positions
- All template code blocks are properly fenced

## Testing & Validation

- [ ] Section ordering in the "Required Sections" list matches the actual section ordering in the document body
- [ ] All four new sections (Breaking Changes, Relationship to Other PRs, Contribution Roadmap, dual Changed Files) are present with templates
- [ ] "AI Tools Used" replaces "AI Disclosure" throughout
- [ ] Title format shows `# PR Description: {conventional commit title}`
- [ ] Em dash character is used in linked Changed Files format (not double-hyphen)
- [ ] Context / Motivation section is preserved and clearly distinguished from Relationship to Other PRs

## Artifacts & Outputs

- `specs/706_revise_pr_description_format_template/plans/01_implementation-plan.md` (this file)
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` (revised)

## Rollback/Contingency

The single file being modified is tracked in git. If the revision introduces problems, revert with:
```bash
git checkout HEAD -- .claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md
```
