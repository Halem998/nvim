# Research Report: Task #226

**Task**: Implement multi-line artifact linking in TODO.md for 2+ artifacts
**Date**: 2026-03-18
**Focus**: Audit of current artifact linking format across the .claude/ system

## Summary

The current artifact linking format concatenates all artifacts of the same type on a single line,
comma-separated. For tasks that accumulate many research reports (e.g., 10 for task 981, 6 for
task 988 in ProofChecker), this makes TODO.md entries unreadable. This report identifies every
file in the .claude/ system that defines, implements, or documents artifact links, establishes
the problem clearly with real examples, and proposes a new multi-line standard with before/after
examples for each affected component type.

## Findings

### 1. The Problem in Practice

From `/home/benjamin/Projects/ProofChecker/specs/TODO.md`, task 981 has this research line:

```
- **Research**: [research-001.md](...), [research-002.md](...), [research-003.md](...),
[research-004.md](...), [research-005.md](...), [research-006.md](...),
[research-007.md](...), [research-008.md](...), [research-009.md](...),
[research-010.md](...)
```

10 artifacts on one logical line. Task 988 has 6 research reports, 3 summaries, and 1 plan all
using the same inline comma-separated pattern. Neither task's entry is readable at a glance.

The problem is a direct consequence of how skills append artifact links: each postflight stage
adds one link to an existing `- **Research**: ...` line by appending `, [filename](path)` to
whatever already exists, with no awareness of how many links are already there.

### 2. Current Artifact Linking Format

All files define or implement this single-line pattern:

**Single artifact** (readable, currently used):
```markdown
- **Research**: [01_research-findings.md](NNN_slug/reports/01_research-findings.md)
```

**Multiple artifacts** (broken, current behavior):
```markdown
- **Research**: [01_research-findings.md](...), [02_team-findings.md](...), [03_synthesis.md](...)
```

### 3. Complete File Inventory

The following 13 files across the .claude/ system define or implement artifact linking and must
all be updated to use the new standard.

#### Standards / Documentation (define the format)

| # | File | Role | Lines Affected |
|---|------|------|----------------|
| 1 | `.claude/rules/state-management.md` | Canonical format spec for TODO.md entries | Lines 73-74, 227-247 |
| 2 | `.claude/rules/artifact-formats.md` | Artifact naming conventions and schemas | Referenced by all skills |
| 3 | `.claude/context/core/patterns/inline-status-update.md` | Reusable patterns for inline status updates | Lines 186-199 (Adding Artifact Links section) |
| 4 | `.claude/context/project/processes/research-workflow.md` | Research workflow process documentation | Line 238 |
| 5 | `.claude/context/project/processes/planning-workflow.md` | Planning workflow process documentation | Line 207 |

#### Core Skills (write artifact links in postflight)

| # | File | Role | Stage Affected |
|---|------|------|----------------|
| 6 | `.claude/skills/skill-researcher/SKILL.md` | Research skill postflight | Stage 8: Link Artifacts (lines 199-224) |
| 7 | `.claude/skills/skill-planner/SKILL.md` | Planning skill postflight | Stage 8: Link Artifacts (lines 206-231) |
| 8 | `.claude/skills/skill-implementer/SKILL.md` | Implementation skill postflight | Stage 8: Link Artifacts (lines 290-315) |
| 9 | `.claude/skills/skill-status-sync/SKILL.md` | Standalone artifact_link operation | Lines 203-215 (artifact_link table) |

#### Extension Skills (also write artifact links in postflight)

| # | File | Role | Location |
|---|------|------|----------|
| 10 | `.claude/extensions/web/skills/skill-web-research/SKILL.md` | Web research postflight | Line 190 |
| 11 | `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` | Web implementation postflight | Line 264 |
| 12 | `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` | Nix implementation postflight | Line 263 |
| 13 | `.claude/extensions/present/skills/skill-grant/SKILL.md` | Grant workflow postflight | Lines 452-455 |

#### README (illustrative examples)

| # | File | Role | Location |
|---|------|------|----------|
| 14 | `.claude/README.md` | System documentation with example task entry | Lines 363-366 |

### 4. How Skills Currently Append Links

In the core skills, the artifact linking pattern at Stage 8 instructs:

```markdown
**Update TODO.md**: Add research artifact link:
- **Research**: [MM_{short-slug}.md]({artifact_path})
```

This implies inserting a new `- **Research**: ...` line, but in practice when re-research occurs
(status cycles back through researching -> researched), the skill appends to the existing line
rather than replacing it, producing the comma-accumulation problem. The standard must be explicit
about both the insert-fresh and append-to-existing cases.

### 5. Proposed New Standard

**Rule**: Use inline format when there is exactly 1 artifact of a given type. Use multi-line list
format when there are 2 or more artifacts of the same type.

#### Single artifact (unchanged, inline):
```markdown
- **Research**: [01_research-findings.md](NNN_slug/reports/01_research-findings.md)
- **Plan**: [01_implementation-plan.md](NNN_slug/plans/01_implementation-plan.md)
- **Summary**: [01_execution-summary.md](NNN_slug/summaries/01_execution-summary.md)
```

#### Multiple artifacts (new, multi-line list):
```markdown
- **Research**:
  - [01_research-findings.md](NNN_slug/reports/01_research-findings.md)
  - [02_team-findings.md](NNN_slug/reports/02_team-findings.md)
  - [03_synthesis.md](NNN_slug/reports/03_synthesis.md)
- **Plan**: [01_implementation-plan.md](NNN_slug/plans/01_implementation-plan.md)
- **Summary**: [01_execution-summary.md](NNN_slug/summaries/01_execution-summary.md)
```

The label line (`- **Research**:`) ends with a colon and no link when multi-line. Each artifact
gets its own `  - [filename](path)` line indented with 2 spaces. Plans and summaries, which
rarely exceed 1-2 artifacts, use the same rule but will typically remain inline.

### 6. Before/After Examples by Component Type

#### state-management.md (Artifact Linking section)

**Before**:
```markdown
### Research Completion
- **Status**: [RESEARCHED]
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

**After**:
```markdown
### Research Completion (single artifact)
- **Status**: [RESEARCHED]
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)

### Research Completion (multiple artifacts)
- **Status**: [RESEARCHED]
- **Research**:
  - [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
  - [02_supplemental.md]({NNN}_{SLUG}/reports/02_supplemental.md)
```

#### inline-status-update.md (Adding Artifact Links section)

**Before**:
```markdown
Research artifact:
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

**After**:
```markdown
Research artifact (1 artifact):
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)

Research artifact (2+ artifacts):
- **Research**:
  - [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
  - [02_supplemental.md]({NNN}_{SLUG}/reports/02_supplemental.md)
```

#### skill-researcher/SKILL.md (Stage 8 instruction)

**Before**:
```markdown
**Update TODO.md**: Add research artifact link:
- **Research**: [MM_{short-slug}.md]({artifact_path})
```

**After**:
```markdown
**Update TODO.md**: Add research artifact link using count-aware format:

1. Read existing research links from the current TODO.md task entry
2. If no existing research line: insert `- **Research**: [MM_{short-slug}.md]({artifact_path})`
3. If existing research line has 1 inline link: convert to multi-line format:
   ```
   - **Research**:
     - [existing-file.md](existing/path)
     - [MM_{short-slug}.md]({artifact_path})
   ```
4. If existing research line is already multi-line: append new `  - [link](path)` item
```

#### skill-status-sync/SKILL.md (artifact_link table)

**Before**:
```markdown
| research | `- **Research**: [MM_{short-slug}.md]({path})` |
| plan     | `- **Plan**: [MM_{short-slug}.md]({path})` |
| summary  | `- **Summary**: [MM_{short-slug}-summary.md]({path})` |
```

**After**:
```markdown
| research | Inline if first/only; multi-line list if 2+ (see Artifact Linking Format) |
| plan     | Inline if first/only; multi-line list if 2+ |
| summary  | Inline if first/only; multi-line list if 2+ |
```

With a reference to the new Artifact Linking Format section in state-management.md.

#### Extension skills (skill-web-research, skill-web-implementation, skill-nix-implementation, skill-grant)

Each has a one-liner like:
```markdown
- **Research**: [MM_{short-slug}.md]({todo_link_path})
```

These should be updated to reference the same count-aware logic defined in state-management.md,
either by inline description or @-reference to the canonical standard.

### 7. Edit Tool Strategy for Skills

The critical implementation detail is how a skill uses the Edit tool to add a new link when
re-research occurs. The skill must:

1. **Detect the current format** by reading the existing TODO.md task entry
2. **Branch on count**:
   - If `- **Research**: [single-link]` (inline): replace that line with the 2-item multi-line block
   - If `- **Research**:\n  - [items]` (multi-line): append one more `  - [link](path)` line
   - If no research line exists: insert inline single-link line

The Edit tool's `old_string` / `new_string` pattern handles all three cases by matching the
existing line(s) precisely.

### 8. TODO.md Frontmatter Note

The frontmatter `next_project_number` field in TODO.md must also be kept in sync (incremented
from 226 to 227 as part of this task creation), which this audit confirms was done correctly.

## Recommendations

1. **Update state-management.md** (the authoritative standard) first, adding a "Artifact Linking
   Format" subsection with the single/multi-line rule and examples for all three artifact types.

2. **Update inline-status-update.md** to show both single and multi-line patterns in the
   "Adding Artifact Links" section.

3. **Update core skills** (skill-researcher, skill-planner, skill-implementer) Stage 8 with
   count-aware Edit logic. These are the primary sources of new artifact links.

4. **Update skill-status-sync** artifact_link operation to apply the same count-aware logic
   for manual/recovery use.

5. **Update extension skills** by replacing the one-liner format strings with a reference to the
   canonical standard or inline count-aware instructions.

6. **Update process docs** (research-workflow.md, planning-workflow.md) to reference the new
   format in their postflight update sections.

7. **Update README.md** example task entry to demonstrate the multi-line format for a task with
   multiple research artifacts.

## Next Steps

Run `/plan 226` to create an implementation plan that phases these changes in logical order,
starting with the standard definition and working outward to the skill implementations.
