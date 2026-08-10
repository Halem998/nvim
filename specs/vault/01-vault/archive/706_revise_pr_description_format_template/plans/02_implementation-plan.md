# Implementation Plan: Task #706

- **Task**: 706 - Revise pr-description-format.md based on real-world PR description patterns
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/706_revise_pr_description_format_template/reports/01_research-pr-format-revision.md
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Revise the CSLib PR description format template to incorporate four new sections discovered in production PRs (Breaking Changes, Relationship to Other PRs, Contribution Roadmap, linked Changed Files format) and harmonize two naming conventions (title H1 format and AI disclosure section name). All changes target a single file: `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`.

### Research Integration

The research report analyzed 4 real-world PR descriptions and identified: (1) the production PRs at tasks 188/198 contain all four missing sections in mature form; (2) the em dash separator is the correct convention for linked Changed Files format; (3) section ordering should place Breaking Changes after Changed Files and before AI Tools Used; (4) "AI Tools Used" replaces "AI Disclosure" based on the two most recent production PRs.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is an extension-level standards update for the cslib project.

## Goals & Non-Goals

**Goals**:
- Add Breaking Changes section template with examples (required when applicable)
- Add Relationship to Other PRs section template (required when applicable)
- Add Contribution Roadmap section template (optional)
- Document linked format for Changed Files in small PRs alongside existing diff-stat format
- Standardize H1 title as `# PR Description: {conventional commit title}`
- Rename "AI Disclosure" to "AI Tools Used" throughout

**Non-Goals**:
- Changing the pr-conventions.md file (commit message format is separate)
- Modifying any existing PR description files in cslib specs
- Restructuring the document beyond what is specified (preserve existing content where not contradicted)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Section ordering conflicts with existing content | M | L | Follow research-determined ordering: Summary > Context > Design Rationale > Relationship to Other PRs > Contribution Roadmap > Changed Files > Breaking Changes > AI Tools Used |
| Em dash vs double-hyphen confusion | L | M | Document em dash explicitly with a note in the Changed Files section |
| Backward compatibility with older PRs using "AI Disclosure" | L | L | Add a note that both names are acceptable; "AI Tools Used" is preferred for new PRs |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Edit pr-description-format.md [NOT STARTED]

**Goal**: Apply all six changes to the template file in a single coherent pass.

**Tasks**:
- [ ] Update the Title section (Required Section 1): change H1 format from `# {conventional commit title}` to `# PR Description: {conventional commit title}`, add note that GitHub PR title field omits the "PR Description:" prefix
- [ ] Rename "AI Disclosure" to "AI Tools Used" in Required Section 5 heading and all references throughout the document
- [ ] Revise the "File-by-file change summary" section (Required Section 4) to become "Changed Files" with two documented formats:
  - Format A: Linked list for small PRs (fewer than ~10 files) using em dash separator pattern
  - Format B: Existing diff-stat + H3 format for large PRs (keep current content as-is)
  - Format C: Existing markdown table for large PRs (keep current content as-is)
- [ ] Add "Breaking Changes" section as a new Required Section (after Changed Files, before AI Tools Used) with: bullet list template, "Files affected upstream" trailing line, include-when guidance
- [ ] Add "Relationship to Other PRs" to the Optional Sections with: H3-per-PR structure, include-when guidance (lateral/concurrent PRs distinct from "stacked on" in Context), template example
- [ ] Add "Contribution Roadmap" to the Optional Sections with: numbered list format, bolded PR labels, dev branch link, include-when guidance (multi-PR series)
- [ ] Update the Required Sections ordering summary at the top to reflect the new section order:
  1. Title (H1)
  2. Summary
  3. Context / Motivation (when applicable)
  4. Changed Files
  5. Breaking Changes (when applicable)
  6. AI Tools Used (always last)
- [ ] Update the Optional Sections list to include: Design Rationale, Relationship to Other PRs, Contribution Roadmap, Dependency Graph, Verification

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Full revision with all six changes

**Verification**:
- All six additions/harmonizations are present in the file
- Section ordering matches the research-recommended order
- Examples use em dash for linked format
- "AI Disclosure" does not appear except in a backward-compatibility note
- Title format shows "PR Description:" prefix convention

---

### Phase 2: Coherence Review and Final Polish [NOT STARTED]

**Goal**: Verify the revised document reads coherently, with consistent cross-references and no internal contradictions.

**Tasks**:
- [ ] Read the full revised file end-to-end to verify logical flow
- [ ] Check that section numbering in the Required Sections overview matches the detailed sections below it
- [ ] Verify no stale references to "AI Disclosure" or old "File-by-file change summary" heading remain (except backward-compatibility notes)
- [ ] Confirm that the "When to include" guidance for each new section is clear and non-overlapping (Breaking Changes vs Context, Relationship to Other PRs vs stacked-on in Context)
- [ ] Verify all code fence examples are syntactically valid markdown
- [ ] Fix any issues discovered during review

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - Minor corrections if needed

**Verification**:
- Document passes a manual coherence check (no contradictions between overview and detailed sections)
- All markdown code fences properly terminated
- No orphaned references to removed/renamed headings

## Testing & Validation

- [ ] Verify the file has no syntax errors (valid markdown)
- [ ] Confirm all six changes from the task description are addressed
- [ ] Check that the new sections include both template examples and "include when" guidance
- [ ] Verify backward compatibility note for AI disclosure naming

## Artifacts & Outputs

- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` (revised)

## Rollback/Contingency

The file is tracked in git. If changes are unsatisfactory, revert with `git checkout HEAD -- .claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`.
