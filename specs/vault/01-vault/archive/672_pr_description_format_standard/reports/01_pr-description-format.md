# Research Report: Task #672

**Task**: 672 - pr_description_format_standard
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:20:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md`
- `.claude/extensions/cslib/index-entries.json`
- `.claude/extensions/cslib/manifest.json`
- All 5 pr-description.md files in `~/Projects/cslib/specs/`
- `~/Projects/cslib/specs/012_.../coordination/pr-description-template.md`
- `.claude/extensions/cslib/commands/pr.md` (generated template in STEP 9)
**Artifacts**: `specs/672_pr_description_format_standard/reports/01_pr-description-format.md`
**Standards**: report-format.md

---

## Executive Summary

- The existing `pr-conventions.md` contains an **outdated and incorrect** inline template: it includes a CI checklist (checkboxes for `lake build`, etc.) in the PR body, which conflicts with real practice — all 5 observed PRs omit the CI checklist from the body entirely
- The 5 real pr-description.md files reveal a consistent, well-evolved format: Title / Summary / Context (with Zulip + literature + stacked-PR info) / File-by-file change summary / AI Disclosure — in that exact order
- The `/pr` command in `pr.md` (STEP 9 template) also includes a CI checklist in the body, perpetuating the outdated pattern — both files need updating
- A new canonical format file should be created at `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`
- `pr-conventions.md` should drop its inline template block and instead reference the new format file
- The new file should be registered in `index-entries.json` with `load_when` scoped to `cslib-implementation-agent` and language `cslib`

---

## Context & Scope

**What was researched**:
1. The existing `pr-conventions.md` content and its inline template
2. All 5 real pr-description.md files from the cslib project specs:
   - `specs/138_subpr_1_1_1_proposition_refactor/pr-description.md` — Sub-PR 1.1.1 (refactor, stacked)
   - `specs/145_subpr_2_1_lukasiewicz_primitives/pr-description.md` — Sub-PR 2.1 (refactor, stacked)
   - `specs/159_subpr_3_1_temporal_formula/pr-description.md` — PR 3.1 (feat, stacked, design rationale)
   - `specs/archive/059_pr1_foundations_logic/pr-description.md` — PR 1 (large feat, verification)
   - `specs/archive/122_fix_propositional_ci_checks/pr-description.md` — Large feat with completeness
3. A 6th artifact: `specs/012_.../pr-description-template.md` — an older template with CI checklist
4. `index-entries.json` structure and how existing entries are registered
5. The `/pr` command file (STEP 9) to see what template is currently auto-generated

**Key constraint**: No CI checklist in the PR body. CI is verified locally and runs automatically on GitHub Actions; claiming it in the description is redundant and misleading (since the description is written before CI runs in practice). This is the pattern from all real PRs and from the task description's citation of PR #635.

---

## Findings

### Pattern Analysis: 5 Real PR Descriptions

All 5 pr-description.md files use a consistent structure, though earlier ones (archive/059, archive/122) have minor variations. The converged pattern (from 138, 145, 159) is:

#### Structure (converged pattern)

```
# {Title line}

**Title**: `{conventional commit title}` (optional, in sub-PR format)
**Base branch**: `leanprover/cslib:main`         (optional)
**Head branch**: `benbrastmckie/cslib:{branch}` (optional)

## Summary

{2-4 sentences describing what the PR adds/changes, highlighting key constructs}

## Context

{Zulip link, stacked-PR info, literature references — present in 3 of 5 PRs}

## {Optional design rationale section(s)}

{Present in 2 of 5 PRs — detailed design reasoning, only for large/complex PRs}

## File-by-file change summary

```diff
{git diff --stat output}
```

### {File.lean} (+N, -M [, NEW])
- {bullet describing each significant change}
...

## AI Disclosure

{2-3 sentence standard boilerplate about Claude Code usage}
```

#### Section-by-Section Analysis

**Title line**: Always `# {Title}` at top. The title is the conventional commit string itself (`feat(Area): description`). Earlier PRs repeat it as `**Title**: ...` below, later ones drop the redundancy.

**Summary** (always present, 2-5 sentences):
- Describes what is added/changed
- Names key types, theorems, or modules
- States scope (N files, ~M lines) for large PRs
- Uses bullet point sub-list for multi-part contributions in larger PRs

**Context** (present in 138, 145, 159 — absent in archive/059, archive/122):
- Zulip link: `**Zulip topic**: [URL]`
- Stacked PR declaration: `This PR is **stacked on #NNN**` with merge request
- Literature reference (full citation with book title/publisher/year)

**Design rationale** (optional, named sections like "## Why {X} as the primitives"):
- Present in 159 (temporal) and archive/059 (large foundations PR)
- Only for novel design decisions needing explanation
- Named with the specific design question as the heading

**File-by-file change summary** (always present):
- Starts with `git diff --stat` block in a code fence
- Then `### File.lean (+N, -M)` per file with bullet points
- 138 and 145 use this exact format
- archive/059 and archive/122 use a markdown table (`| File | Role |`) for large file inventories
- 159 uses a hybrid: `### File.lean (new, N lines)` with prose + tables for derived operators

**AI Disclosure** (always present, always last):
- 138, 145: "This PR was prepared with the assistance of Claude Code (Anthropic). The AI tool was used for: [bullets]. All Lean code was written by the authors [names] and verified to compile cleanly on the PR branch."
- 159: Short variant — "This PR was prepared with the assistance of Claude Code (Anthropic), used for drafting/extracting files from a development branch, running CI verification commands, and drafting this description. All Lean code was written by the author (Benjamin Brast-McKie) and verified to compile on the PR branch."
- archive/122: Footnote-style — "> **AI Disclosure**: This contribution was developed with assistance from Claude (Anthropic). All proofs have been reviewed and machine-verified by the Lean 4 type checker."

**NO CI checklist in any of the 3 recent real PRs** (138, 145, 159). The archive/059 pr-description-v2.md omits the checklist entirely; archive/122 adds it in a `## Verification` section with results (not checkboxes), which is a different purpose — it lists what was verified and passed.

### What the Current pr-conventions.md Template Gets Wrong

The current template in `pr-conventions.md` (lines 87-107):
```markdown
## Summary
Brief description of what this PR adds or fixes.

## Changes
- List of specific changes made

## CI
- [ ] `lake build` passes
- [ ] `lake exe checkInitImports` passes
...

## AI Disclosure (if applicable)
```

Issues:
1. **`## CI` with checkboxes** — Not used in any real PR. CI runs automatically; the description doesn't serve as a checklist.
2. **No `## Context` section** — Missing the Zulip/stacked-PR/literature section entirely.
3. **No file-by-file summary** — The most informative and consistently-present section in real PRs.
4. **`## Changes` as bullets** — Too vague; real PRs use file-by-file breakdown.
5. **`(if applicable)` on AI Disclosure** — AI disclosure is always required per CSLib/Mathlib policy.

### The `/pr` Command STEP 9 Template (also needs updating)

The template in `commands/pr.md` STEP 9 also includes a CI section with checked checkboxes:
```markdown
## CI
- [x] `lake build` passes
- [x] `lake exe checkInitImports` passes
...
```
This needs to be updated to remove the CI section and add the Context and file-by-file sections.

### Existing Index-Entry Pattern

From `index-entries.json`, the `pr-conventions.md` entry:
```json
{
  "path": "project/cslib/standards/pr-conventions.md",
  "description": "CSLib PR title conventions, conventional commits, review process",
  "tags": ["cslib", "pr", "git", "commits"],
  "load_when": {
    "languages": ["cslib"],
    "agents": ["cslib-implementation-agent"]
  },
  "domain": "project",
  "subdomain": "cslib",
  "summary": "CSLib PR title conventions, conventional commits, review process"
}
```

The new format file should follow the same pattern, scoped to `cslib-implementation-agent` since the `/pr` command runs under that agent context. It should also be loaded for `pr`-type commands — but since the extension system routes by language not command, loading for `cslib-implementation-agent` is correct.

---

## Proposed Format Template

The canonical format file should define this template:

```markdown
# CSLib PR Description Format

Canonical format for CSLib pull request descriptions. Based on established patterns
from the cslib project PR history (PRs #635, #637, and subsequent sub-PRs).

## Required Sections

All CSLib PRs must include these sections, in this order:

### 1. Title (H1 heading)

The PR title as the document heading:

```
# {conventional commit title}
```

The conventional commit title uses the format from `pr-conventions.md`:
```
{feat|fix|doc|style|refactor|test|chore|perf}[({area})]: {description}
```

Examples:
```
# feat(Logics/Temporal): temporal logic formula type with primitives and derived operators
# refactor: Proposition type to Lukasiewicz convention
# fix(Foundations): correct substitution lemma in HasSubstitution
```

### 2. Summary

2-4 sentences describing what the PR adds or changes. Name the key types, theorems,
modules, or definitions introduced. For large PRs, include scope (N files, ~M lines).

```markdown
## Summary

{2-4 sentences. Name key constructs. State scope for large PRs.}
```

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

### 4. File-by-file change summary

Always present. Shows the git diff --stat followed by per-file bullet summaries.

```markdown
## File-by-file change summary

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
```

For large PRs with many files (10+), use a markdown table instead of per-file bullets:

```markdown
| File | Lines | Role |
|------|------:|------|
| `Path/To/File.lean` | N | Brief role description |
```

### 5. AI Disclosure (always last)

Required for all CSLib PRs per the Mathlib AI usage policy. Always the last section.

```markdown
## AI Disclosure

This PR was prepared with the assistance of Claude Code (Anthropic). The AI tool was used for:
- Drafting and extracting files from a development branch to create a clean PR branch
- Running CI verification commands
- Drafting this PR description

All Lean code was written by the {author(s) — names} and verified to compile cleanly on the PR branch.
```

Short variant (for smaller PRs):

```markdown
## AI Disclosure

This PR was prepared with the assistance of Claude Code (Anthropic), used for drafting/extracting
files from a development branch, running CI verification commands, and drafting this description.
All Lean code was written by the author ({name}) and verified to compile on the PR branch.
```

---

## Optional Sections

These sections appear in some PRs but are not required:

### Design Rationale

Use for novel design decisions that require explanation. Name the section after the specific
design question:

```markdown
## Why {X} as the primitives
## Design: {component} architecture
## Argument convention: {name}
```

Include when:
- The primitive/representation choice is non-obvious and needs justification
- Literature references support the design
- The choice will affect all downstream PRs

### Dependency Graph

For large PRs with complex import structures:

```markdown
## Dependency Graph

```
ModuleA
    +-- ModuleB
        +-- ModuleC
```
```

### Verification (large PRs only)

Use only for large PRs to document that sorry-free verification was performed.
Not a checklist — state results:

```markdown
## Verification

- `lake build`: 0 errors (N jobs)
- `grep -rn "sorry"`: 0 hits across all contributed files
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
```

---

## Files to Create/Modify

### 1. CREATE (new file)

**Path**: `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`

Content: The canonical format document as specified in "Proposed Format Template" above.

### 2. MODIFY: `pr-conventions.md`

**Path**: `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md`

Changes:
- Remove the `## PR Description Template` section (lines 85-107, the markdown code block with the outdated template)
- Replace with a two-line reference: `## PR Description Format` + `See [pr-description-format.md](pr-description-format.md) for the canonical PR description template and section-by-section guidance.`

### 3. MODIFY: `index-entries.json`

**Path**: `.claude/extensions/cslib/index-entries.json`

Add after the existing `pr-conventions.md` entry:

```json
{
  "path": "project/cslib/standards/pr-description-format.md",
  "description": "CSLib PR description canonical format: Summary, Context, file-by-file summary, AI Disclosure",
  "tags": ["cslib", "pr", "format", "description", "template"],
  "load_when": {
    "languages": ["cslib"],
    "agents": ["cslib-implementation-agent"]
  },
  "domain": "project",
  "subdomain": "cslib",
  "summary": "Canonical PR description format with required sections, optional sections, and AI disclosure boilerplate"
}
```

### 4. MODIFY: `commands/pr.md` (STEP 9 template)

**Path**: `.claude/extensions/cslib/commands/pr.md`

In STEP 9, replace the `## CI` section with a `## Context` section (or omit if not applicable)
and the `## Changes` bullet list with a `## File-by-file change summary` section.

The updated STEP 9 template:

```markdown
## Summary

{working_desc — 2-4 sentences about what this PR adds/changes}

## Context

{Include this section only if applicable:
- Stacked on another PR: "This PR is **stacked on #{NNN}**..."
- Zulip discussion exists: "**Zulip topic**: [URL]"
- Literature motivation: full citation}

## File-by-file change summary

{git diff --stat output in a code fence}

### {filename.lean} (+N, -M)
{bullet points describing key changes}

## AI Disclosure

This PR was prepared with the assistance of Claude Code (Anthropic). The AI tool was used for:
- Drafting and extracting files from a development branch to create a clean PR branch
- Running CI verification commands
- Drafting this PR description

All Lean code was written by the author (Benjamin Brast-McKie) and verified to compile cleanly on the PR branch.
```

---

## Index-Entries.json Additions Needed

Add this entry to the `entries` array in `.claude/extensions/cslib/index-entries.json`, after the `pr-conventions.md` entry:

```json
{
  "path": "project/cslib/standards/pr-description-format.md",
  "description": "CSLib PR description canonical format: Summary, Context, file-by-file summary, AI Disclosure",
  "tags": ["cslib", "pr", "format", "description", "template"],
  "load_when": {
    "languages": ["cslib"],
    "agents": ["cslib-implementation-agent"]
  },
  "domain": "project",
  "subdomain": "cslib",
  "summary": "Canonical PR description format with required sections, optional sections, and AI disclosure boilerplate"
}
```

---

## Decisions

1. **No CI checklist in body**: The key insight from PR #635 and all recent real PRs — CI runs automatically on GitHub Actions, no body checklist needed
2. **Context section required when stacked**: All sub-PRs use `## Context` with stacked-PR declaration, Zulip link, and literature reference
3. **File-by-file over bullet list**: `## File-by-file change summary` with per-file `### File.lean` headings and bullets is more informative than `## Changes` with flat bullets
4. **AI Disclosure always required**: Not "(if applicable)" — always required per Mathlib policy
5. **Load for cslib-implementation-agent**: Same scope as pr-conventions.md since /pr command runs there
6. **Update both pr-conventions.md and commands/pr.md**: Both have the outdated CI-checklist template

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `/pr` command STEP 9 regenerates old template | Update the template in STEP 9 of `commands/pr.md` |
| pr-conventions.md template drift | Remove the template block entirely, add reference to format file |
| Format file not loaded for `/pr` command | Register in index-entries.json with `cslib-implementation-agent` |
| File-by-file section guidance unclear | Include explicit git diff --stat instruction in format file |

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/index-entries.json`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md`
- `/home/benjamin/Projects/cslib/specs/138_subpr_1_1_1_proposition_refactor/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/145_subpr_2_1_lukasiewicz_primitives/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/159_subpr_3_1_temporal_formula/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/archive/059_pr1_foundations_logic/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/archive/059_pr1_foundations_logic/pr-description-v2.md`
- `/home/benjamin/Projects/cslib/specs/archive/122_fix_propositional_ci_checks/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/012_coordinate_cslib_pr_submission_bimodal_logic/coordination/pr-description-template.md`
