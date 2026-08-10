# Research Report: Task #199

**Task**: 199 - Complete Summary Naming Migration Fix Validation Globs
**Date**: 2026-03-13
**Focus**: Identify all remaining files with old artifact naming conventions

## Summary

Task 198 partially completed the artifact naming convention migration. This research identifies 28 files with remaining old-convention patterns requiring updates. The most critical issues are: (1) broken glob patterns in validation.md that fail to match new-convention artifacts, (2) example outputs in extension agents/skills using `implementation-summary-YYYYMMDD.md` format, and (3) grep patterns for plan discovery using `implementation-*.md` globs.

## Findings

### Category 1: Broken Validation Globs (CRITICAL)

**File**: `.claude/context/core/validation.md`

| Line | Current Pattern | Required Pattern |
|------|-----------------|------------------|
| 35 | `specs/{NNN}_*/reports/research-*.md` | `specs/{NNN}_*/reports/*.md` |
| 36 | `specs/{NNN}_*/plans/implementation-*.md` | `specs/{NNN}_*/plans/*.md` |
| 37 | `specs/{NNN}_*/summaries/implementation-summary-*.md` | `specs/{NNN}_*/summaries/*-summary.md` |

**Impact**: Validation logic fails to match MM_{short-slug}.md format artifacts.

---

### Category 2: Plan/Summary File Discovery Scripts (HIGH)

**File**: `.claude/scripts/update-plan-status.sh`

| Line | Current Pattern | Required Pattern |
|------|-----------------|------------------|
| 44 | `implementation-*.md` | `*.md` (or MM pattern) |

**File**: `.claude/commands/task.md`

| Line | Current Pattern | Required Pattern |
|------|-----------------|------------------|
| 343 | `implementation-*.md` | `*.md` (or MM pattern) |

**Impact**: Plan file discovery fails with new naming convention.

---

### Category 3: Extension Implementation Agent Examples (MEDIUM)

These files have example return text using old `implementation-summary-YYYYMMDD.md` format:

| File | Lines | Old Pattern |
|------|-------|-------------|
| `.claude/extensions/web/agents/web-implementation-agent.md` | 347, 791, 802 | `implementation-summary-20260205.md` |
| `.claude/extensions/nvim/agents/neovim-implementation-agent.md` | 282 | `implementation-summary-20260202.md` |
| `.claude/extensions/nix/agents/nix-implementation-agent.md` | 302 | `implementation-summary-20260203.md` |

**Correct format**: `MM_{short-slug}-summary.md` (e.g., `03_about-page-summary.md`)

---

### Category 4: Extension Skill Examples (MEDIUM)

| File | Lines | Old Pattern |
|------|-------|-------------|
| `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` | 335, 345 | `implementation-summary-20260203.md` |
| `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` | 336, 346 | `implementation-summary-20260205.md` |

---

### Category 5: Format Specification Examples (MEDIUM)

**File**: `.claude/context/core/formats/command-output.md`

| Line | Old Pattern | Should Be |
|------|-------------|-----------|
| 103 | `implementation-summary-20260312.md` | `MM_{short-slug}-summary.md` |
| 269 | `implementation-summary-20260312.md` | `MM_{short-slug}-summary.md` |
| 343 | `implementation-summary-20260312.md` | `MM_{short-slug}-summary.md` |

**File**: `.claude/context/core/formats/return-metadata-file.md`

| Line | Old Pattern | Should Be |
|------|-------------|-----------|
| 255 | `implementation-summary-20260118.md` | `MM_{short-slug}-summary.md` |
| 289 | `implementation-summary-20260118.md` | `MM_{short-slug}-summary.md` |
| 323 | `implementation-summary-20260118.md` | `MM_{short-slug}-summary.md` |
| 357 | `implementation-summary-20260118.md` | `MM_{short-slug}-summary.md` |

---

### Category 6: Old research-NNN/implementation-NNN References (LOW)

**File**: `.claude/context/core/patterns/anti-stop-patterns.md`

| Line | Old Pattern |
|------|-------------|
| 164 | `plans/implementation-002.md` |

**File**: `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`

| Line | Old Pattern |
|------|-------------|
| 106 | `reports/research-002.md` |
| 107 | `plans/implementation-003.md` |
| 108 | `summaries/implementation-summary-20260305.md` |

---

### Category 7: Plan File Status (LOW)

**File**: `specs/198_review_recent_claude_commits_consistency/plans/02_complete-naming-migration.md`

| Line | Current | Required |
|------|---------|----------|
| 4 | `[NOT STARTED]` | `[COMPLETED]` |
| 46, 70, 101, 136 | Phase markers show `[COMPLETED]` | Correct |

**Note**: The plan file shows plan-level status as NOT STARTED but all phases are marked COMPLETED. This is an inconsistency that should be fixed.

---

## Complete File List by Priority

### Priority 1: Validation/Discovery (Fix First)
1. `.claude/context/core/validation.md` (lines 35-37)
2. `.claude/scripts/update-plan-status.sh` (line 44)
3. `.claude/commands/task.md` (line 343)

### Priority 2: Extension Agents (Examples)
4. `.claude/extensions/web/agents/web-implementation-agent.md` (lines 347, 791, 802)
5. `.claude/extensions/nvim/agents/neovim-implementation-agent.md` (line 282)
6. `.claude/extensions/nix/agents/nix-implementation-agent.md` (line 302)

### Priority 3: Extension Skills (Examples)
7. `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (lines 335, 345)
8. `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` (lines 336, 346)

### Priority 4: Format Specifications
9. `.claude/context/core/formats/command-output.md` (lines 103, 269, 343)
10. `.claude/context/core/formats/return-metadata-file.md` (lines 255, 289, 323, 357)

### Priority 5: Pattern Examples
11. `.claude/context/core/patterns/anti-stop-patterns.md` (line 164)
12. `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md` (lines 106-108)

### Priority 6: Task 198 Plan Status
13. `specs/198_review_recent_claude_commits_consistency/plans/02_complete-naming-migration.md` (line 4)

## Correct New Convention Reference

From `.claude/CLAUDE.md` and `.claude/rules/artifact-formats.md`:

```
Artifacts use MM_{short-slug}.md format:
- MM = Zero-padded sequence number (01, 02, 03...)
- {short-slug} = 3-5 word kebab-case description

Examples:
- reports/01_research-findings.md
- plans/02_implementation-plan.md
- summaries/03_execution-summary.md
```

## Recommendations

1. **Update validation.md glob patterns** to use generic patterns that match both old and new conventions, or specifically match the new MM_ prefix pattern

2. **Update plan discovery scripts** in task.md and update-plan-status.sh to handle new naming

3. **Update extension agent/skill examples** with realistic MM_{short-slug} format examples

4. **Update format specification examples** with consistent new-convention paths

5. **Mark task 198 plan as COMPLETED** since all phases are done

## Next Steps

Run /plan 199 to create implementation plan addressing these 13 files across 6 categories.
