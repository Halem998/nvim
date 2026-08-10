# Research Report: Task #546

**Task**: 546 - Audit and align other multi-task creators for consistent insertion
**Started**: 2026-05-07T00:00:00Z
**Completed**: 2026-05-07T00:00:00Z
**Effort**: 3h
**Dependencies**: Task #545 (hardened pattern established)
**Sources/Inputs**:
- Full `.opencode/` directory tree grep for TODO.md references, insertion patterns, and `## Tasks` anchors
- Deep read of 14+ files: commands (task.md, fix-it.md, review.md, errors.md, spawn.md), skills (skill-fix-it, skill-spawn, skill-learn, skill-project-overview, skill-todo), agents (meta-builder-agent, spawn-agent), context files (task-management.md, state-management.md, command-lifecycle.md), docs (multi-task-creation-standard.md), rules (state-management.md)
- Extension directories: extensions/core/, extensions/present/, extensions/nix/, extensions/nvim/
- Task #545 research report for hardened pattern reference
**Artifacts**:
- specs/546_audit_multi_task_creators/reports/01_multi-task-creator-audit.md (this report)
**Standards**: report-format.md, multi-task-creation-standard.md

## Executive Summary

- **14 files create or describe TODO.md insertion** across the `.opencode/` system; only 3 files use the hardened `oldString: "## Tasks\n"` pattern
- **5 files use abstract prose** (pseudocode without concrete Edit tool syntax) that needs alignment
- **6 files use vague insertion instructions** (no concrete `oldString`/`newString`) that need hardening
- **2 files reference `insert_after_heading()`** — a pseudocode function that is not a real tool, which is the most dangerous pattern (agents may halt confused)
- **1 file (`commands/task.md`) contains multiple insertion patterns** across `--create`, `--recover`, and `--review` modes, all needing hardening
- **Extension-present files (4)** mirror the base patterns and need identical hardening

## Context & Scope

### What Was Audited

Every file in the `.opencode/` system that describes or performs TODO.md task entry insertion. The audit systematically checked both the core system (`.opencode/skills/`, `agent/subagents/`, `commands/`) and extension layers (`extensions/core/`, `extensions/present/`, `extensions/nix/`, `extensions/nvim/`).

### What Was Excluded (Already Hardened by Task #545)

- `.opencode/agent/subagents/meta-builder-agent.md` — uses `oldString: "## Tasks\n"` at lines 737-744 and 1360
- `.opencode/extensions/core/agents/meta-builder-agent.md` — identical clone of subagent file, same hardened pattern at lines 737-744 and 1358-1363
- `.opencode/docs/reference/standards/multi-task-creation-standard.md` — uses `oldString: "## Tasks\n"` at lines 336-343

### Classification System

| Category | Definition |
|----------|-----------|
| **Hardened** | Uses concrete Edit tool `oldString: "## Tasks\n"` pattern with verification step |
| **Abstract/Prose** | Uses pseudocode or English description without concrete Edit tool syntax |
| **Vague** | Mentions "prepend" or "insert" but no concrete `oldString`/`newString` |
| **Indirect** | Delegates to another agent/skill (pass-through) |
| **N/A** | Does not create TODO.md entries |

## Findings

### Category A: Files Using Abstract Prose (Highest Priority)

These files describe insertion using pseudocode that an agent cannot directly execute. Agents reading "insert_after_heading()" or "Prepend new task entry" must improvise, leading to inconsistent behavior.

#### 1. skill-fix-it (`.opencode/skills/skill-fix-it/SKILL.md`)

**Lines**: 466-478
**Status**: Abstract/Vague
**Current Text**:
```markdown
#### 9.2: Update TODO.md

Prepend new task entry to `## Tasks` section (new tasks at top):

**Standard format (no dependency)**:
### {N}. {Title}
...
```
**Issue**: Says "Prepend new task entry" and shows entry formats but provides ZERO concrete Edit tool invocation. An agent reading this must guess how to insert: sed? Edit? Append? Prepend-each? Batch?
**Fix needed**: Replace with concrete batch-insertion pattern using `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch}\n"` with verification step.

#### 2. skill-learn (`.opencode/skills/skill-learn/SKILL.md`)

**Lines**: 878-904
**Status**: Abstract/Vague (identical to skill-fix-it)
**Current Text**:
```markdown
#### 9.2: Update TODO.md

Prepend new task entry to `## Tasks` section (new tasks at top):
...
```
**Issue**: Identical abstract pattern to skill-fix-it. No concrete Edit tool syntax.
**Fix needed**: Same as skill-fix-it. Use hardened batch-insertion pattern.

#### 3. commands/review.md (`.opencode/commands/review.md`)

**Lines**: 806-807 (Task Order insertion lines 1045-1095, and TODO entry at 806)
**Status**: Abstract/Vague (multiple insertion points)
**Line 806-807**:
```
**4. Update TODO.md:**
Add task entry following existing format in TODO.md frontmatter section.
```
**Issue**: Says "Add task entry" but does not specify HOW. No Edit tool pattern at all.

**Lines 1045-1095** (Task Order insertion): Uses pseudocode patterns:
```
old_string = "\n## Tasks"
new_string = "\n{category_block}\n\n## Tasks"
```
**Issue**: Uses snake_case (`old_string` not `oldString`), `\n` escape sequences, and no concrete batch-insertion pattern for actual task entries. The `\n## Tasks` anchor is also fragile — should anchor on `"## Tasks\n"` for reliability.
**Fix needed**: (a) For actual task entries: use hardened `oldString: "## Tasks\n"` pattern; (b) For Task Order section insertion: standardize anchor to `"## Tasks\n"` with camelCase.

#### 4. commands/task.md (`.opencode/commands/task.md`)

**Lines**: 164-174, 248, 523-524
**Status**: Abstract/Vague (multiple modes, each with different insertion description)

**--create mode (line 164-174)**:
```
**Part B - Add task entry** by prepending to `## Tasks` section:
...
**Insertion**: Use sed or Edit to insert the new task entry immediately after the `## Tasks` line
```
**Issue**: Suggests "sed or Edit" without specifying WHICH Edit tool pattern. The "immediately after" phrasing is vague — agent may use append instead of prepend.

**--recover mode (line 248)**:
```
**Update TODO.md**: Prepend recovered task entry to `## Tasks` section
```
**Issue**: No Edit tool syntax at all. Same as fix-it/learn.

**--review mode (lines 523-524)**:
```
# Update TODO.md (add entry and update frontmatter)
```
**Issue**: Comment only. No concrete insertion instructions. The review mode creates multiple follow-up tasks (lines 496-523 use a loop), so batch insertion is needed here.

**Fix needed**: All three modes need the hardened `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"` pattern. Review mode specifically needs batch insertion since it creates multiple follow-up tasks in a loop.

#### 5. commands/review.md — Section 5.6.3

The review command has TWO separate TODO.md insertion needs:
- **5.6.3**: Creates actual task entries in `## Tasks` section (line 806-807, abstract)
- **6.6**: Inserts entries into Task Order section (between Task Order and `## Tasks`, pseudocode)

Both need separate hardening. See risks section for the Task Order insertion complexity.

### Category B: Files Using insert_after_heading() Pseudocode (Most Dangerous)

This is the most harmful pattern because `insert_after_heading()` is NOT a real tool. When an agent encounters this pseudocode, it may halt and ask "what is insert_after_heading?" or attempt to guess, leading to incorrect insertions.

#### 6. extensions/core/docs/reference/standards/multi-task-creation-standard.md

**Lines**: 330-332
**Status**: Abstract/Pseudocode (DANGEROUS)
```python
batch_markdown = "\n\n".join(batch_entries)
insert_after_heading("## Tasks", batch_markdown)
```
**Issue**: `insert_after_heading()` is a fictional function. An agent reading this will not know to use the Edit tool. This is the extension copy of the core standard and needs identical hardening.
**Fix needed**: Replace with:
```
oldString: "## Tasks\n"
newString: "## Tasks\n\n{batch_markdown}\n"
```
Include WARNING block and verification step from the core standard.

#### 7. context/workflows/command-lifecycle.md (`.opencode/context/workflows/command-lifecycle.md`)

**Lines**: 267-269, 292-293
**Status**: Abstract/Vague
```
- Format specs/TODO.md entry with proper metadata
- Append to correct priority section in specs/TODO.md
```
And the inline pseudocode (line 292):
```
# Append to specs/TODO.md (using Edit tool)
```
**Issue**: Says "Append to specs/TODO.md (using Edit tool)" but no concrete pattern. The word "Append" is misleading — the hardened pattern prepends after `## Tasks`, not appends at end of file. Agent may literally append at end, wrong behavior.
**Fix needed**: Replace with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"` and change "Append" to "Prepend after `## Tasks` heading".

### Category C: Files with Vague Insertion Instructions

#### 8. skill-spawn (`.opencode/skills/skill-spawn/SKILL.md`)

**Lines**: 373
**Status**: Vague
```
Use Edit tool to insert each task entry at the top of the Tasks section (after `## Tasks` header).
```
**Issue**: The instruction is mostly correct but lacks the concrete `oldString`/`newString` pattern. The phrase "each task entry" suggests individual prepending (anti-pattern) rather than batch insertion. Spawn may create multiple tasks; individual prepending reverses their order.
**Fix needed**: Add concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch}\n"` with batch insertion emphasis.

#### 9. skill-project-overview (`.opencode/skills/skill-project-overview/SKILL.md`)

**Lines**: 378
**Status**: Vague (single task, but still vague)
```
Prepend new task entry to the Tasks section in TODO.md:
```
**Issue**: Shows format block but no Edit tool pattern. Single task so batch not needed, but still needs concrete syntax.
**Fix needed**: Add `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n### {N}. ...\n..."` Edit tool pattern.

#### 10. context/standards/task-management.md (`.opencode/context/standards/task-management.md`)

**Lines**: 81
**Status**: Vague (standards document, not executable)
```
- Prepend new tasks to the `## Tasks` section (new tasks at top, older tasks sink down).
```
**Issue**: Correct guidance (prepend at top), but standards document does not show HOW. This is less critical since it is not a skill/command file, but should still reference the hardened pattern for agents that read it.
**Fix needed**: Add cross-reference: "Use the heading-anchored Edit tool pattern defined in multi-task-creation-standard.md."

#### 11. rules/state-management.md (`.opencode/rules/state-management.md`)

**Lines**: 20
**Status**: Vague (auto-applied rule, not executable)
```
- Single `## Tasks` section (new tasks prepended at top)
```
**Issue**: Same as task-management.md. Correct principle but no HOW.
**Fix needed**: Add cross-reference.

#### 12. context/core/workflows/command-lifecycle.md

**Lines**: 267-269, 292-293
**Status**: Identical to the non-core version (Category B, File #7). Same fix needed.

### Category D: Extension Files Needing Hardening

#### 13. extensions/core/skills/skill-fix-it/SKILL.md

**Lines**: 466
**Status**: Abstract/Vague (identical to core skill-fix-it)
**Fix needed**: Same batch-insertion pattern as core version.

#### 14. extensions/core/skills/skill-spawn/SKILL.md

**Lines**: 345
**Status**: Vague (identical to core skill-spawn)
**Fix needed**: Same concrete pattern as core version.

#### 15-18. extensions/present/ files (4 files)

- `extensions/present/skills/skill-grant/SKILL.md` line 867: "prepend entry to TODO.md `## Tasks` section" — Vague
- `extensions/present/commands/timeline.md` line 204: "prepending to `## Tasks` section" — Vague
- `extensions/present/commands/slides.md` line 292: "prepending to `## Tasks` section" — Vague
- `extensions/present/commands/grant.md` line 200: "prepending to `## Tasks` section" — Vague

All four use the same vague "prepend" language without concrete Edit tool patterns. Each needs the hardened `oldString: "## Tasks\n"` pattern.

### Category E: Files Verified as N/A (No TODO.md Insertion)

- `skill-todo/SKILL.md` — Archives tasks, reads TODO.md, but does NOT insert new task entries. N/A.
- `skill-status-sync/SKILL.md` — Atomically updates status fields in existing entries. Does not insert new entries. N/A.
- `commands/errors.md` — Delegates task creation to `/task` command (line 127: `"/task \"Fix: ...\""`). Indirect pass-through. N/A.
- `commands/spawn.md` — Delegates to skill-spawn. Indirect pass-through. N/A.
- `agent/subagents/spawn-agent.md` — Produces spawn analysis report, does not directly add tasks to TODO.md. N/A.
- `agent/subagents/general-research-agent.md` through `reviser-agent.md` — Research/implementation/plan/review agents. Do not create TODO.md entries. N/A.
- `extensions/nix/` and `extensions/nvim/` skill files — Extension research/implementation agents with postflight status updates, not task creation. N/A.

## Summary Table

| # | File | Lines | Status | Priority | Action |
|---|------|-------|--------|----------|--------|
| 1 | `skills/skill-fix-it/SKILL.md` | 466-478 | Abstract | P0 | Add batch `oldString`/`newString` |
| 2 | `skills/skill-learn/SKILL.md` | 878-904 | Abstract | P0 | Add batch `oldString`/`newString` |
| 3 | `commands/task.md` | 164-174, 248, 523 | Abstract | P0 | Add `oldString`/`newString` to all 3 modes |
| 4 | `commands/review.md` | 806-807 | Abstract | P0 | Add concrete Edit tool pattern |
| 5 | `commands/review.md` | 1045-1095 | Pseudocode | P1 | Standardize anchor, camelCase |
| 6 | `extensions/core/docs/.../multi-task-creation-standard.md` | 330-332 | DANGEROUS | P0 | Replace `insert_after_heading()` |
| 7 | `context/workflows/command-lifecycle.md` | 267-269, 292-293 | Vague | P1 | Replace "Append" with hardened pattern |
| 8 | `skills/skill-spawn/SKILL.md` | 373 | Vague | P1 | Add `oldString`/`newString`, emphasize batch |
| 9 | `skills/skill-project-overview/SKILL.md` | 378 | Vague | P2 | Add `oldString`/`newString` |
| 10 | `context/standards/task-management.md` | 81 | Vague | P2 | Add cross-reference |
| 11 | `rules/state-management.md` | 20 | Vague | P2 | Add cross-reference |
| 12 | `context/core/workflows/command-lifecycle.md` | 267-269, 292 | Vague | P1 | Same as #7 |
| 13 | `extensions/core/skills/skill-fix-it/SKILL.md` | 466 | Abstract | P0 | Same as #1 (extension copy) |
| 14 | `extensions/core/skills/skill-spawn/SKILL.md` | 345 | Vague | P1 | Same as #8 (extension copy) |
| 15 | `extensions/present/skills/skill-grant/SKILL.md` | 867 | Vague | P2 | Add `oldString`/`newString` |
| 16 | `extensions/present/commands/timeline.md` | 204 | Vague | P2 | Add `oldString`/`newString` |
| 17 | `extensions/present/commands/slides.md` | 292 | Vague | P2 | Add `oldString`/`newString` |
| 18 | `extensions/present/commands/grant.md` | 200 | Vague | P2 | Add `oldString`/`newString` |

**Priority legend**: P0 = dangerous or affects multi-task creation; P1 = affects single-task creation; P2 = context/reference/docs

## Decisions

1. **Batch insertion for multi-task creators is non-negotiable**: skill-fix-it, skill-learn, skill-spawn, and commands/task.md --review all create 2+ tasks. Individual prepending reverses order. These must all use batch insertion.

2. **`insert_after_heading()` is the most dangerous pattern**: This fictional function in the extension copy of multi-task-creation-standard.md will cause agent confusion. It is P0 priority despite being a docs file because agents read it as a standard.

3. **commands/task.md --review mode is multi-task**: Though compliance noted "Grouping: No (one task per phase)" at line 564, it creates multiple tasks in a loop (lines 497-523). It needs batch insertion.

4. **Extension files are independent copies**: The extension copies of skill-fix-it and skill-spawn use different file paths from core but identical insertion prose. They need independent fixing. They should NOT be symlinks or imports from core since extensions can be loaded/unloaded independently.

5. **Task Order section insertion (review.md) is special**: The review command inserts into the Task Order section (between `## Task Order` and `## Tasks`). This uses `old_string = "\n## Tasks"` which is a different anchor from the standard `"## Tasks\n"`. This needs its own hardening while respecting that it inserts BEFORE `## Tasks` (adding content between Task Order and Tasks), not after.

6. **Standards/context files need references, not concrete patterns**: Files like task-management.md and state-management.md are reference documents, not executable instructions. They should cross-reference the hardened pattern rather than duplicate it.

## Recommendations

### Phase 1: P0 Files (Critical — Multi-task Creators)

All P0 files create multiple tasks and currently use abstract prose or dangerous pseudocode.

1. **skill-fix-it/SKILL.md and extension copy**: Replace "Prepend new task entry" prose with batch insertion pattern. Add concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch_markdown}\n"` with WARNING block and verification step. Note: fix-it creates learn-it + fix-it + todo + research tasks, so `batch_markdown` must include all entries in correct order.

2. **skill-learn/SKILL.md**: Identical fix to skill-fix-it. Same multi-task pattern.

3. **commands/task.md --review mode**: Replace empty `# Update TODO.md` comment with batch insertion pattern. The review mode creates follow-up tasks one by one in a loop (lines 497-523); batch insertion requires collecting all entries first, THEN inserting.

4. **commands/review.md -- Section 5.6.3**: Replace "Add task entry following existing format" with concrete `oldString: "## Tasks\n"` pattern. Review creates multiple tasks; needs batch insertion.

5. **extensions/core/docs/reference/standards/multi-task-creation-standard.md**: Replace `insert_after_heading("## Tasks", batch_markdown)` with the concrete Edit tool pattern. Add WARNING block. This file serves as the authoritative standard for extension-loaded contexts.

### Phase 2: P1 Files (Single-task Creators or Reference)

6. **commands/task.md --create and --recover**: Replace "Use sed or Edit to insert" with concrete Edit tool pattern `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"`. Remove the "sed" suggestion (sed is fragile and inconsistent with the rest of the system).

7. **commands/review.md -- Task Order insertion (lines 1045-1095)**: Change `old_string = "\n## Tasks"` to `oldString: "\n## Tasks"` (camelCase). The anchor is semantically different from the task entry anchor (it inserts BEFORE `## Tasks`, not after), so document this distinction clearly.

8. **skill-spawn/SKILL.md and extension copy**: Replace "Use Edit tool to insert each task entry at the top" with concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch}\n"`. Emphasize batch insertion since spawn can create 2+ tasks.

9. **context/workflows/command-lifecycle.md and core copy**: Replace "Append to specs/TODO.md (using Edit tool)" with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"`. Change wording from "Append" to "Prepend after `## Tasks` heading".

### Phase 3: P2 Files (References and Extensions)

10. **skill-project-overview/SKILL.md**: Add Edit tool pattern to the existing format block.

11. **context/standards/task-management.md**: Add cross-reference to multi-task-creation-standard.md for the insertion pattern.

12. **rules/state-management.md**: Add cross-reference.

13. **extensions/present/ (4 files)**: Add `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"` to all four files.

## Risks & Mitigations

### Risk 1: Review command Task Order section manipulation

The review command has TWO insertion operations that share the `## Tasks` anchor but with opposite semantics:
- **Section 5.6.3**: Insert task entries AFTER `## Tasks` (into the task list)
- **Section 6.6**: Insert content BEFORE `## Tasks` (between Task Order and Tasks)

Both currently use `\n## Tasks` as anchor. If both are "hardened" to use `"## Tasks\n"`, Section 6.6 insertions will go to the wrong place.

**Mitigation**: Document that Task Order insertion in Section 6.6 uses a DIFFERENT anchor from the standard: `oldString: "\n## Tasks"` (with newline prefix) to insert before the heading. Add explicit comment: "NOTE: This anchor is intentionally different from the standard task-entry anchor because it inserts BETWEEN the Task Order section and the Tasks section."

### Risk 2: command-lifecycle.md says "Append" but should say "Prepend after heading"

The word "Append" can mean "add to end of file" or "add content." If an agent interprets it as "add to end," tasks will be inserted at the bottom of TODO.md (wrong). The hardened pattern prepends after `## Tasks`, which places new tasks at the TOP.

**Mitigation**: Change "Append" to "Prepend after `## Tasks` heading" and provide concrete `oldString`/`newString`.

### Risk 3: Present extensions are rarely tested

The present extension files (skill-grant, timeline, slides, grant commands) are extension code that may not be frequently exercised. Changes to these files may not get tested soon.

**Mitigation**: Apply the same mechanical transformation as core files. The insertion pattern is identical — just change `"prepend entry to TODO.md"` to concrete Edit tool syntax. Low risk of regression.

## Context Extension Recommendations

- **Topic**: TODO.md insertion patterns across .opencode/ system
- **Gap**: No single document maps which files perform TODO.md insertion, which are hardened, and which are abstract. The `multi-task-creation-standard.md` document lists compliance status at a high level but does not provide file-level details.
- **Recommendation**: This audit report should be maintained as the authoritative audit. After implementation, update the compliance table in `multi-task-creation-standard.md` to reflect post-hardening status. Consider adding a "TODO.md Insertion Audit" cross-reference from that standard.

## Appendix

### Search Queries Used

- `grep -rn "TODO\.md" --include="*.md" .opencode/` — 1706 matches, culled to insertion-relevant
- `grep -rn "Prepend|prepend|Append|append" --include="*.md" .opencode/` — filtered for task/entry insertion
- `grep -rn "batch_markdown|batch.*insert" --include="*.md" .opencode/` — batch insertion patterns
- `grep -rn "oldString.*## Tasks|old_string.*## Tasks" --include="*.md" .opencode/` — hardened anchors
- `grep -rn "insert_after_heading|abstract.*prose" --include="*.md" .opencode/` — dangerous pseudocode

### Hardened Pattern Reference (from Task #545)

The canonical hardened pattern:

```markdown
**WARNING**: DO NOT search for the last `---` separator and append text.
DO NOT insert at the bottom of the file.
ALWAYS use the heading-anchored Edit tool pattern with `oldString: "## Tasks\n"`.
The heading `## Tasks` is unique in TODO.md and is the only reliable insertion anchor.

**Insert the batch** using the Edit tool to prepend at the TOP of the Tasks section:

oldString: "## Tasks\n"
newString: "## Tasks\n\n{batch_markdown}\n"

**Verify insertion**: After inserting, re-read the first few lines after `## Tasks` using the Read tool:
- Confirm the first task after `## Tasks` has the expected foundational task number
- If it doesn't match, the insertion went wrong — fix and re-verify
```

### Files Already Hardened (Reference Only)

- `.opencode/agent/subagents/meta-builder-agent.md` — lines 735-751, 1358-1364
- `.opencode/extensions/core/agents/meta-builder-agent.md` — lines 735-751, 1358-1364
- `.opencode/docs/reference/standards/multi-task-creation-standard.md` — lines 334-354
