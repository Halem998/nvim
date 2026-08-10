# Implementation Plan: Task #672

- **Task**: 672 - Standardize CSLib PR description format
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/672_pr_description_format_standard/reports/01_pr-description-format.md
- **Artifacts**: plans/01_pr-description-format-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a canonical PR description format file for the cslib extension, replacing the outdated inline template in pr-conventions.md. The research report analyzed 5 real PR descriptions and identified a converged pattern: Title / Summary / Context / File-by-file change summary / AI Disclosure -- with no CI checklist in the body. This plan creates the format file, registers it in the context index, updates pr-conventions.md to reference it, and aligns the /pr command template.

### Research Integration

Key findings from the research report:
- All 5 real PR descriptions omit CI checklists from the body; CI runs on GitHub Actions automatically
- The converged format (from PRs 138, 145, 159) uses: Title, Summary, Context (Zulip/stacked PR/literature), File-by-file change summary, AI Disclosure
- pr-conventions.md lines 85-107 contain an outdated template with CI checkboxes and missing sections (no Context, no file-by-file)
- commands/pr.md STEP 9 also generates the outdated template with CI checkboxes
- AI Disclosure is always required per Mathlib policy (not "if applicable")

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `pr-description-format.md` as the single source of truth for PR description structure
- Register the new file in index-entries.json for cslib-implementation-agent context loading
- Update pr-conventions.md to drop its inline template and reference the new file
- Update /pr command STEP 9 template to match the canonical format (minimal change: replace CI section and Changes section)

**Non-Goals**:
- Refactoring /pr command flow or steps beyond STEP 9 template text (deferred to task 674)
- Modifying existing pr-description.md files in ~/Projects/cslib/specs/
- Changes to pr-conventions.md content outside the template section (title format, review process, etc. remain as-is)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| STEP 9 template change overlaps with task 674 scope | L | M | Keep change minimal: only replace template text block, do not alter STEP 9 flow or AskUserQuestion logic |
| index-entries.json parse error from bad JSON | M | L | Validate JSON syntax with jq after edit |
| pr-conventions.md section boundary mismatch | L | L | Research report identifies exact line range (85-107); verify during implementation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create canonical format file [COMPLETED]

**Goal**: Create the pr-description-format.md file with the complete canonical PR description template.

**Tasks**:
- [x] Create file at `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` *(completed)*
- [x] Include Required Sections: Title (H1, conventional commit), Summary (2-4 sentences), Context/Motivation (Zulip, stacked PR, literature), File-by-file change summary (diff stat + per-file headings), AI Disclosure (always last, always required) *(completed)*
- [x] Include Optional Sections: Design Rationale, Dependency Graph, Verification (large PRs only) *(completed)*
- [x] Include "What NOT to Include" section explicitly prohibiting CI checklists in the body *(completed)*
- [x] Use content from research report "Proposed Format Template" section as the basis *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` - CREATE new file

**Verification**:
- File exists at the specified path
- Contains all 5 required sections with examples
- Contains optional sections with usage guidance
- Explicitly states no CI checklist in body

---

### Phase 2: Register in index-entries.json [COMPLETED]

**Goal**: Add the new format file to the cslib extension context index so it is loaded for PR-related tasks.

**Tasks**:
- [x] Add new entry to `.claude/extensions/cslib/index-entries.json` entries array, after the existing `pr-conventions.md` entry *(completed)*
- [x] Set path to `project/cslib/standards/pr-description-format.md` *(completed)*
- [x] Set load_when to `languages: ["cslib"]`, `agents: ["cslib-implementation-agent"]` *(completed)*
- [x] Set tags to `["cslib", "pr", "format", "description", "template"]` *(completed)*
- [x] Validate JSON syntax with `jq . index-entries.json` *(completed)*

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/index-entries.json` - ADD entry after pr-conventions.md entry

**Verification**:
- `jq . .claude/extensions/cslib/index-entries.json` parses without error
- New entry appears in the entries array with correct path, tags, and load_when

---

### Phase 3: Update pr-conventions.md [COMPLETED]

**Goal**: Remove the outdated inline template from pr-conventions.md and replace it with a reference to the new format file.

**Tasks**:
- [x] Remove the `## PR Description Template` section (lines 85-107: the heading plus the markdown code block containing the outdated template with CI checkboxes) *(completed)*
- [x] Replace with a `## PR Description Format` heading and a one-line reference: `See [pr-description-format.md](pr-description-format.md) for the canonical PR description template and section-by-section guidance.` *(completed)*
- [x] Verify surrounding sections (AI Disclosure Requirement above, end of file below) remain intact *(completed)*

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` - REPLACE lines 85-107

**Verification**:
- No `## CI` section with checkboxes remains in the file
- No `(if applicable)` qualifier on AI Disclosure reference
- Reference link to pr-description-format.md is present
- File reads cleanly with no orphaned markdown

---

### Phase 4: Update /pr command STEP 9 template [COMPLETED]

**Goal**: Align the /pr command auto-generated PR description with the canonical format.

**Tasks**:
- [x] In `.claude/extensions/cslib/commands/pr.md`, locate the STEP 9 template block (the markdown template starting with `## Summary` around line 564) *(completed)*
- [x] Remove the `## Changes` section (flat bullet list) *(completed)*
- [x] Remove the `## CI` section (checked checkboxes) *(completed)*
- [x] Add `## Context` section (conditional: stacked PR info, Zulip link, literature -- with guidance note that it is only included when applicable) *(completed)*
- [x] Add `## File-by-file change summary` section (diff stat in code fence + per-file headings with bullets) *(completed)*
- [x] Update `## AI Disclosure` to match the canonical boilerplate (remove generic "The mathematical content has been verified by the contributor" and use the specific format from the format file) *(completed)*
- [x] Keep the AskUserQuestion flow and options unchanged (no STEP 9 flow changes) *(completed)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - REPLACE STEP 9 template block (~lines 564-588)

**Verification**:
- STEP 9 template contains: Summary, Context (conditional), File-by-file change summary, AI Disclosure
- No `## CI` section with checkboxes in the template
- No `## Changes` section with flat bullets
- AskUserQuestion options for editing remain functional (Approve, Edit summary, Edit AI disclosure, Replace entirely)
- STEP flow (STEP 8 -> STEP 9 -> STEP 10) is unbroken

## Testing & Validation

- [x] `jq . .claude/extensions/cslib/index-entries.json` parses without error *(verified)*
- [x] New format file exists at `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` *(verified)*
- [x] pr-conventions.md no longer contains CI checkbox template *(verified)*
- [x] pr-conventions.md references pr-description-format.md *(verified)*
- [x] /pr command STEP 9 template uses the canonical format sections *(verified)*
- [x] No other STEP in pr.md was modified (only STEP 9 template text) *(verified)*

## Artifacts & Outputs

- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` (new file)
- `.claude/extensions/cslib/index-entries.json` (modified: new entry added)
- `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` (modified: template section replaced with reference)
- `.claude/extensions/cslib/commands/pr.md` (modified: STEP 9 template updated)

## Rollback/Contingency

All changes are to files within `.claude/extensions/cslib/`. Revert with `git checkout -- .claude/extensions/cslib/` if any issues arise. The format file is a new addition, so deletion reverts Phase 1. The other three files can be individually reverted with `git checkout -- <file>`.
