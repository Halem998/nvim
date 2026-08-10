# Implementation Plan: Audit and Align Multi-Task Creator Insertion

- **Task**: 546 - Audit and align other multi-task creators for consistent insertion
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task #545 (hardened pattern established in meta-builder-agent and core standard)
- **Research Inputs**: specs/546_audit_multi_task_creators/reports/01_multi-task-creator-audit.md
- **Artifacts**: plans/01_multi-task-creator-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply the hardened heading-anchored Edit tool insertion pattern from task #545 to 15 remaining files in the `.opencode/` system that describe or perform TODO.md task entry insertion. The audit found files spanning three priority tiers: 6 critical multi-task creators using abstract prose or dangerous pseudocode, 5 high-impact files with vague insertion instructions or special anchor requirements, and 4 reference/extension files needing alignment. All edits follow a mechanical replacement pattern: substitute abstract/vague insertion prose with concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"` syntax, add the WARNING block (anti-pattern prevention), and include a post-insertion Read verification step.

### Research Integration

The audit report (`01_multi-task-creator-audit.md`) provides an exhaustive file-level analysis of 18 files, classifying each by insertion category (Hardened, Abstract/Vague, Pseudocode/Dangerous, or N/A) and assigning P0/P1/P2 priority tiers. It documents the specific lines requiring change for each file, identifies the unique dual-anchor challenge in `commands/review.md` (task entries after `## Tasks` vs. Task Order content before `## Tasks`), flags `insert_after_heading()` as the single most dangerous pattern, and provides the canonical hardened pattern reference from task #545. This plan implements the research report's phased recommendations without deviation.

### Prior Plan Reference

No prior plan. This is the first plan for task #546.

### Roadmap Alignment

No ROADMAP.md alignment needed (meta task, self-contained `.opencode/` system hardening). The task advances "Agent System Quality" goals indirectly by reducing agent confusion and inconsistent behavior.

## Goals & Non-Goals

**Goals**:
- Replace all 15 unhardened files with concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"` Edit tool syntax
- Eliminate the dangerous `insert_after_heading()` pseudocode from the extension copy of multi-task-creation-standard.md
- Ensure multi-task creators (fix-it, learn, spawn, task --review, review) use batch insertion to preserve task ordering
- Fix the review command's dual-anchor insertion (Section 5.6.3 task entries vs. Section 6.6 Task Order) with distinct, documented anchors
- Add WARNING block and post-insertion Read verification to every hardened file
- Update cross-references in context/standards files to point at the canonical pattern

**Non-Goals**:
- Do not modify the 3 already-hardened files from task #545 (meta-builder-agent x2, core standard)
- Do not change the semantic behavior of any command or skill — only the insertion instruction syntax
- Do not alter files categorized as N/A (skill-todo, skill-status-sync, commands/errors.md, commands/spawn.md, spawn-agent, extension research/implementation agents)
- Do not change task numbering, dependency tracking, or status initialization logic in any file
- Do not add new functional features to any file

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Review command dual-anchor confusion: both Section 5.6.3 (task entries) and Section 6.6 (Task Order) target `## Tasks` but with opposite insertion semantics (after vs. before) | High | Medium | Section 6.6 keeps its distinct `oldString: "\n## Tasks"` anchor (newline prefix for before-insertion) and receives an explicit comment documenting why it differs from the standard pattern. Section 5.6.3 uses the standard `oldString: "## Tasks\n"` for after-insertion. |
| Commands/task.md --review mode collects tasks in a loop but has no batch-insertion instruction | Medium | Medium | Add explicit instruction: collect all follow-up task entries into a batch before a single Edit tool call. Insert the comment "Build batch_markdown by joining all entries with `\n\n`, then use a single insertion call." |
| Present extension files rarely tested, changes may regress silently | Low | Medium | Apply identical mechanical transformation as core files. The insertion pattern is copy-paste identical — no semantic change. Validate by grepping all 4 files for `oldString: "## Tasks\n"` after edits. |
| Command-lifecycle.md uses word "Append" which agents may interpret as end-of-file insertion | Medium | Low | Change "Append" to "Prepend after `## Tasks` heading" throughout both copies. The concrete `oldString`/`newString` pattern removes ambiguity even if the prose is misread. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Harden P0-A — Abstract Prose in Multi-Task Creators [COMPLETED]

**Goal**: Replace abstract "Prepend" prose with concrete batch-insertion Edit tool pattern in the three files that create 2+ tasks but provide zero concrete insertion syntax.

**Tasks**:
- [ ] **Task 1.1**: Harden `.opencode/skills/skill-fix-it/SKILL.md` at lines 466-478. Replace "Prepend new task entry to `## Tasks` section" and format examples with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch_markdown}\n"`, WARNING block, and Read verification. Emphasize batch insertion since fix-it creates learn-it + fix-it + TODO + research tasks.
- [ ] **Task 1.2**: Harden `.opencode/extensions/core/skills/skill-fix-it/SKILL.md` at line 466 with identical changes to the core copy (same file, different directory; extension can be loaded independently).
- [ ] **Task 1.3**: Harden `.opencode/skills/skill-learn/SKILL.md` at lines 878-904 with identical batch-insertion pattern. This file mirrors skill-fix-it's Section 9.2 exactly.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/skills/skill-fix-it/SKILL.md` — lines 466-478
- `.opencode/extensions/core/skills/skill-fix-it/SKILL.md` — line 466
- `.opencode/skills/skill-learn/SKILL.md` — lines 878-904

**Verification**:
- Grep each file for `oldString: "## Tasks\n"` — must exist in all three
- Grep for `insert_after_heading`, `Prepend new task`, `sed or Edit` — must NOT exist in any of the three
- Confirm WARNING block text is present (anti-pattern: "DO NOT search for the last `---` separator")
- Confirm post-insertion Read verification step text is present

---

### Phase 2: Harden P0-B — Dangerous Pseudocode and Multi-Mode Files [COMPLETED]

**Goal**: Eliminate the dangerous `insert_after_heading()` pseudocode from the extension standard copy, and harden the review command's Section 5.6.3 and the task command's three modes (`--create`, `--recover`, `--review`).

**Tasks**:
- [ ] **Task 2.1**: Harden `.opencode/extensions/core/docs/reference/standards/multi-task-creation-standard.md` at lines 330-332. Replace `insert_after_heading("## Tasks", batch_markdown)` with concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch_markdown}\n"`. Add WARNING block and verification step matching the core standard.
- [ ] **Task 2.2**: Harden `.opencode/commands/review.md` Section 5.6.3 (line 806-807). Replace "Add task entry following existing format in TODO.md frontmatter section" with concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"` batch-insertion pattern. Review creates multiple tasks; emphasize batch.
- [ ] **Task 2.3**: Harden `.opencode/commands/task.md` — `--create` mode (lines 164-174). Replace "Use sed or Edit to insert" with concrete `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"`. Remove "sed" suggestion entirely. Keep the format blocks, add WARNING and verification.
- [ ] **Task 2.4**: Harden `.opencode/commands/task.md` — `--recover` mode (line 248). Replace "Prepend recovered task entry" with the same concrete Edit tool pattern as `--create`.
- [ ] **Task 2.5**: Harden `.opencode/commands/task.md` — `--review` mode (lines 523-524). Replace empty `# Update TODO.md` comment with batch-insertion pattern. Add explicit note: "Collect all follow-up task entries first (loop at lines 497-523), then use a single Edit tool call with `oldString: "## Tasks\n"`."

**Timing**: 60 minutes

**Depends on**: 1 (core skill files established the reference pattern; this phase extends to complex multi-mode files)

**Files to modify**:
- `.opencode/extensions/core/docs/reference/standards/multi-task-creation-standard.md` — lines 330-332
- `.opencode/commands/review.md` — lines 806-807
- `.opencode/commands/task.md` — lines 164-174, 248, 523-524

**Verification**:
- Grep `extensions/core/docs/reference/standards/multi-task-creation-standard.md` for `insert_after_heading` — must NOT exist
- Grep `commands/task.md` for `sed or Edit` or `Use sed` — must NOT exist
- Grep `commands/review.md` for `oldString: "## Tasks\n"` — must exist in Section 5.6.3 area
- Grep `commands/task.md` for `oldString: "## Tasks\n"` — must have at least 3 occurrences (one per mode)
- Confirm `--review` mode includes "Collect all follow-up task entries first" language

---

### Phase 3: Harden P1 — Single-Task Creators and Special Anchors [COMPLETED]

**Goal**: Harden files that create single tasks or have vague insertion instructions, and fix the review command's Task Order section insertion with its distinct anchor.

**Tasks**:
- [ ] **Task 3.1**: Harden `.opencode/skills/skill-spawn/SKILL.md` at line 373. Replace "Use Edit tool to insert each task entry at the top of the Tasks section (after `## Tasks` header)" with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch}\n"`. Emphasize batch insertion since spawn can create 2+ tasks. Remove "each task entry" language (anti-pattern: individual prepending reverses order).
- [ ] **Task 3.2**: Harden `.opencode/extensions/core/skills/skill-spawn/SKILL.md` at line 345 with identical changes to the core copy.
- [ ] **Task 3.3**: Harden `.opencode/context/workflows/command-lifecycle.md` at lines 267-269 and 292-293. Replace "Append to specs/TODO.md (using Edit tool)" with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"`. Change prose wording from "Append" to "Prepend after `## Tasks` heading."
- [ ] **Task 3.4**: Harden `.opencode/context/core/workflows/command-lifecycle.md` at lines 267-269 and 292-293 with identical changes.
- [ ] **Task 3.5**: Harden `.opencode/commands/review.md` Section 6.6 Task Order insertion (lines 1045-1095). Change `old_string = "\n## Tasks"` to `oldString: "\n## Tasks"` (camelCase). Add explicit comment: "NOTE: This anchor is intentionally different from the standard task-entry anchor (`oldString: "## Tasks\n"`) because this insertion goes BETWEEN the Task Order section and the `## Tasks` heading." Keep the newline-prefix anchor for before-insertion semantics.

**Timing**: 45 minutes

**Depends on**: 1, 2 (P0 establishes the canonical pattern; P1 applies it with variations for special anchors)

**Files to modify**:
- `.opencode/skills/skill-spawn/SKILL.md` — line 373
- `.opencode/extensions/core/skills/skill-spawn/SKILL.md` — line 345
- `.opencode/context/workflows/command-lifecycle.md` — lines 267-269, 292-293
- `.opencode/context/core/workflows/command-lifecycle.md` — lines 267-269, 292-293
- `.opencode/commands/review.md` — lines 1045-1095

**Verification**:
- Grep all skill-spawn files for `each task entry` — must NOT exist (anti-pattern removed)
- Grep both command-lifecycle files for `Append to specs/TODO.md` — must NOT exist (changed to "Prepend after heading")
- Grep `commands/review.md` for `old_string` (snake_case) — must NOT exist in Section 6.6
- Grep `commands/review.md` for `oldString: "\n## Tasks"` — must exist with the distinct-anchor comment nearby
- Grep all 5 files for `oldString: "## Tasks\n"` (skill-spawn files and command-lifecycle files) — must exist

---

### Phase 4: Harden P2 — Reference Files and Present Extensions [COMPLETED]

**Goal**: Update lowest-priority files: add concrete insertion patterns to skill-project-overview, add cross-references to two context standards files, and harden four present extension files.

**Tasks**:
- [ ] **Task 4.1**: Harden `.opencode/skills/skill-project-overview/SKILL.md` at line 378. Replace "Prepend new task entry to the Tasks section in TODO.md:" prose with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n### {N}. ...\n..."` Edit tool pattern. Single-task creator, so batch insertion is not needed.
- [ ] **Task 4.2**: Update `.opencode/context/standards/task-management.md` at line 81. Keep the existing "Prepend new tasks to `## Tasks` section" guidance but add a cross-reference: "Use the heading-anchored Edit tool pattern defined in `docs/reference/standards/multi-task-creation-standard.md`." Do not add full Edit tool syntax (this is a reference document, not executable instruction).
- [ ] **Task 4.3**: Update `.opencode/rules/state-management.md` at line 20. Add same cross-reference as task-management.md.
- [ ] **Task 4.4**: Harden `.opencode/extensions/present/skills/skill-grant/SKILL.md` at line 867. Replace "prepend entry to TODO.md `## Tasks` section" with `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{entry}\n"`, WARNING block, and verification.
- [ ] **Task 4.5**: Harden `.opencode/extensions/present/commands/timeline.md` at line 204 with identical Edit tool pattern.
- [ ] **Task 4.6**: Harden `.opencode/extensions/present/commands/slides.md` at line 292 with identical Edit tool pattern.
- [ ] **Task 4.7**: Harden `.opencode/extensions/present/commands/grant.md` at line 200 with identical Edit tool pattern.

**Timing**: 30 minutes

**Depends on**: 1, 2, 3 (lowest priority, references and rarely-used extensions — do after all core hardening is complete)

**Files to modify**:
- `.opencode/skills/skill-project-overview/SKILL.md` — line 378
- `.opencode/context/standards/task-management.md` — line 81
- `.opencode/rules/state-management.md` — line 20
- `.opencode/extensions/present/skills/skill-grant/SKILL.md` — line 867
- `.opencode/extensions/present/commands/timeline.md` — line 204
- `.opencode/extensions/present/commands/slides.md` — line 292
- `.opencode/extensions/present/commands/grant.md` — line 200

**Verification**:
- Grep `skill-project-overview/SKILL.md` for `oldString: "## Tasks\n"` — must exist
- Grep `task-management.md` and `state-management.md` for `multi-task-creation-standard.md` cross-reference — must exist
- Grep all 4 present extension files for `oldString: "## Tasks\n"` — must exist in all four
- Final system-wide grep: `grep -rn "Prepend.*Tasks section\|Append.*TODO\|insert_after_heading\|old_string.*## Tasks" --include="*.md" .opencode/` — should return zero results (or only files intentionally using distinct anchors, like review.md Section 6.6)

## Testing & Validation

- [ ] Run `grep -rn "oldString: \"## Tasks\\n\"" --include="*.md" .opencode/ | wc -l` — should return >= 18 (3 already-hardened from task #545 + 15 from this task)
- [ ] Run `grep -rn "insert_after_heading" --include="*.md" .opencode/` — must return zero results
- [ ] Run `grep -rn "sed or Edit\|Use sed" --include="*.md" .opencode/` — must return zero results
- [ ] Run `grep -rn "Append to specs/TODO.md" --include="*.md" .opencode/` — must return zero results
- [ ] Verify all 4 present extension files contain `oldString: "## Tasks\n"` with `grep -rn "oldString: \"## Tasks\\n\"" .opencode/extensions/present/`
- [ ] Verify `commands/review.md` has two distinct `oldString` patterns: `"## Tasks\n"` (Section 5.6.3) and `"\n## Tasks"` (Section 6.6) with distinct-anchor comment
- [ ] Verify `commands/task.md` has `oldString: "## Tasks\n"` in all three mode sections (`--create`, `--recover`, `--review`)
- [ ] Manual spot-check: read 3 representative files (one from each tier) and confirm WARNING block, concrete Edit tool syntax, and verification step are all present

## Artifacts & Outputs

- `specs/546_audit_multi_task_creators/plans/01_multi-task-creator-plan.md` — this plan
- 15 modified files across `.opencode/` — all hardened to use heading-anchored Edit tool pattern
- Updated cross-references in 2 context/standards files — pointing to canonical pattern

## Rollback/Contingency

If hardening introduces issues, revert using git: `git checkout --` on the 15 modified files. Since all changes are mechanical prose-to-Edit-tool-syntax replacements within isolated sections, no cascading side effects are possible. Each file's behavioral intent remains unchanged — only the instruction syntax is updated.

If the review command's dual-anchor distinction causes confusion, simplify by reverting Section 6.6 to its original pseudocode and deferring to a follow-up task for deeper refactoring of the review command's insertion logic.
