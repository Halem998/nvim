# Implementation Plan: Task #545

- **Task**: 545 - Harden TODO.md insertion ordering in meta-builder-agent
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/545_harden_todo_md_insertion/reports/01_todo-insertion-research.md
- **Artifacts**: plans/01_todo-insertion-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the abstract `insert_after_heading("## Tasks", batch_markdown)` pseudocode in meta-builder-agent.md (main copy and core mirror) with explicit, LLM-proof Edit tool invocations that guarantee prepend-at-top behavior. Apply the same hardening to the Stage 6 Status Updates prose. Add mandatory post-insertion verification and a bold anti-pattern warning against searching for `---` separators. Update multi-task-creation-standard.md component 8 to propagate the hardened pattern as the normative standard, preventing this defect from recurring in future multi-task creators.

**Definition of done**: Every TODO.md insertion instruction in both meta-builder-agent copies and the multi-task-creation standard uses a concrete Edit tool invocation with `oldString: "## Tasks\n"` as the anchor. Post-insertion re-read verification is specified. An anti-pattern warning explicitly forbids separator-based or append strategies.

### Research Integration

Research report `01_todo-insertion-research.md` identified three documents with vulnerable pseudocode: the main agent definition (lines 699-737 and 1334-1359), the core mirror (identical), and multi-task-creation-standard.md (lines 323-335). Four other multi-task creators (fix-it, spawn, review, general-implementation) use similar abstract prose and are deferred to task 546. The recommended fix is the heading-anchored Edit tool pattern (`oldString: "## Tasks\n"` -> `newString: "## Tasks\n\n{batch}\n"`), already proven in general-implementation-agent for status marker updates.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. The task falls under the "Agent System Quality" theme (Phase 1: Current Priorities) by hardening agent instruction reliability.

## Goals & Non-Goals

**Goals**:
- Replace `insert_after_heading()` pseudocode in meta-builder-agent.md Stage 6 (CreateTasks) with concrete Edit tool invocation
- Replace abstract "insert after heading" prose in Stage 6 (Status Updates) with the same concrete Edit tool pattern
- Sync both changes to the core mirror at `.opencode/extensions/core/agents/meta-builder-agent.md`
- Add mandatory post-insertion verification: re-read first task after `## Tasks` and confirm it matches the expected foundational task number
- Add bold anti-pattern warning explicitly forbidding separator/append strategies
- Update multi-task-creation-standard.md component 8 with the hardened pattern as a precedent for all multi-task creators

**Non-Goals**:
- Fixing other multi-task creators (skill-fix-it, skill-spawn, /review) — deferred to task 546
- Creating a new standalone context file for TODO.md insertion patterns — deferred to a follow-up (research report recommendation)
- Modifying TODO.md itself or any task generation logic
- Changing state.json update procedures

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `## Tasks\n` is not unique enough in TODO.md | Medium | Low | `## Tasks` is a level-2 heading; no other `## Tasks` heading exists in TODO.md |
| Core mirror and main copy diverge after edits | High | Low | Both files modified atomically in the same implementation phase; post-edit diff comparison |
| Batch markdown accidentally contains `## Tasks\n` substring | High | Very Low | Task entries use `### N.` headings (level-3), never `##` (level-2) |
| LLM ignores concrete pattern and invents its own | Medium | Medium | Post-insertion re-read verification catches this immediately; bold anti-pattern warning increases compliance |
| `\n` literal vs actual newline confusion in Edit tool | Medium | Medium | Plan spec uses explicit `\n` in prose but implementation must verify Edit tool receives literal newline characters |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Harden Stage 6 CreateTasks insertion [COMPLETED]

**Goal**: Replace `insert_after_heading("## Tasks", batch_markdown)` pseudocode in both copies of meta-builder-agent.md with a concrete Edit tool invocation, anti-pattern warning, and post-insertion verification.

**Tasks**:
- [x] **Task 1.1**: Read meta-builder-agent.md Stage 6 CreateTasks section (lines 690-745) in both main copy and core mirror to confirm current pseudocode matches research findings *(completed)*
- [x] **Task 1.2**: Replace `insert_after_heading("## Tasks", batch_markdown)` pseudocode (line ~736) in the main copy with a concrete Edit tool invocation block *(completed)*
- [x] **Task 1.3**: Add anti-pattern warning immediately before the Edit tool invocation in the main copy *(completed)*
- [x] **Task 1.4**: Add post-insertion verification step after the Edit tool invocation in the main copy *(completed)*
- [x] **Task 1.5**: Apply identical changes to the core mirror at `.opencode/extensions/core/agents/meta-builder-agent.md` *(completed)*
- [x] **Task 1.6**: Verify both copies match by diffing the CreateTasks sections to confirm atomic sync *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/agent/subagents/meta-builder-agent.md` — replace pseudocode at lines ~699-740 with hardened pattern
- `.opencode/extensions/core/agents/meta-builder-agent.md` — sync identical changes

**Verification**:
- Edit tool invocation in both files uses `oldString: "## Tasks\n"` and `newString: "## Tasks\n\n{batch_markdown}\n"`
- Anti-pattern warning appears in bold immediately before the Edit tool block
- Post-insertion re-read verification step follows the Edit tool block
- `diff <(sed -n '690,750p' main) <(sed -n '690,750p' mirror)` shows only path/comment differences, not logic differences

### Phase 2: Harden Stage 6 Status Updates insertion [COMPLETED]

**Goal**: Replace the abstract prose in meta-builder-agent.md Stage 6 Status Updates section (lines ~1334-1359) with the same concrete Edit tool pattern, anti-pattern warning, and verification used in Phase 1. Sync to core mirror.

**Tasks**:
- [x] **Task 2.1**: Read meta-builder-agent.md Stage 6 Status Updates section in both copies to confirm prose-only vulnerability *(completed)*
- [x] **Task 2.2**: Replace the abstract "Insert batch into TODO.md" prose in the main copy with the same concrete Edit tool invocation pattern from Phase 1, referencing it as the canonical insertion pattern *(completed)*
- [x] **Task 2.3**: Apply identical changes to the core mirror *(completed)*
- [x] **Task 2.4**: Verify both copies match for the Status Updates section *(completed)*

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/agent/subagents/meta-builder-agent.md` — replace prose at lines ~1334-1359 with hardened pattern
- `.opencode/extensions/core/agents/meta-builder-agent.md` — sync identical changes

**Verification**:
- Status Updates section references the canonical Edit tool pattern (not re-invented prose)
- Anti-pattern warning is present or cross-referenced from Phase 1's insertion pattern
- Post-insertion verification is specified or cross-referenced
- Both copies are identical in their Status Updates insertion logic

### Phase 3: Update multi-task-creation-standard.md component 8 [COMPLETED]

**Goal**: Replace the abstract `insert_after_heading()` pseudocode in component 8 of multi-task-creation-standard.md with the hardened Edit tool pattern, establishing it as the normative precedent for all multi-task creators.

**Tasks**:
- [x] **Task 3.1**: Read multi-task-creation-standard.md component 8 (lines ~300-340) to confirm current pseudocode matches research findings *(completed)*
- [x] **Task 3.2**: Replace the abstract pseudocode with the concrete Edit tool invocation pattern matching Phase 1 *(completed)*
- [x] **Task 3.3**: Add a brief note that other multi-task creators should adopt this pattern (precedent for task 546) *(completed)*
- [x] **Task 3.4**: Verify the updated standard is internally consistent — no remaining `insert_after_heading()` or abstract insertion prose in the document *(completed)*

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/docs/reference/standards/multi-task-creation-standard.md` — replace pseudocode in component 8 (lines ~323-335) with hardened pattern

**Verification**:
- No `insert_after_heading()` call remains anywhere in the file
- Component 8 uses `oldString: "## Tasks\n"` / `newString: "## Tasks\n\n{batch}\n"` pattern
- Post-insertion verification and anti-pattern warning are present or referenced

## Testing & Validation

- [ ] Confirm both copies of meta-builder-agent.md are byte-identical in their TOD0.md insertion sections (excluding path differences in comments)
- [ ] Confirm `grep -n "insert_after_heading" .opencode/agent/subagents/meta-builder-agent.md` returns no results
- [ ] Confirm `grep -n "insert_after_heading" .opencode/extensions/core/agents/meta-builder-agent.md` returns no results
- [ ] Confirm `grep -n "insert_after_heading" .opencode/docs/reference/standards/multi-task-creation-standard.md` returns no results
- [ ] Confirm `grep -n 'oldString.*## Tasks' .opencode/agent/subagents/meta-builder-agent.md` returns at least 2 matches (CreateTasks + Status Updates)
- [ ] Confirm `grep -n 'oldString.*## Tasks' .opencode/extensions/core/agents/meta-builder-agent.md` returns at least 2 matches
- [ ] Confirm `grep -n 'oldString.*## Tasks' .opencode/docs/reference/standards/multi-task-creation-standard.md` returns at least 1 match
- [ ] Manual review: the Edit tool `oldString` is exactly `## Tasks\n` (not `## Tasks` without newline, not `## Tasks\n\n`)
- [ ] Manual review: the anti-pattern warning explicitly forbids searching for `---` separators

## Artifacts & Outputs

- `.opencode/agent/subagents/meta-builder-agent.md` — hardened Stage 6 CreateTasks and Status Updates sections
- `.opencode/extensions/core/agents/meta-builder-agent.md` — synced core mirror with identical hardening
- `.opencode/docs/reference/standards/multi-task-creation-standard.md` — updated component 8 with concrete Edit tool pattern
- `specs/545_harden_todo_md_insertion/summaries/01_todo-insertion-summary.md` — implementation summary (produced by /implement)

## Rollback/Contingency

All changes are text replacements in three files with no structural refactoring. To roll back:

1. Revert each file via `git checkout -- <path>` before the implementation commit
2. If only partial rollback is needed, revert specific files individually — the three files are independent of each other (no cross-file import/require dependencies)
3. The core mirror can be regenerated from the main copy if needed: `cp .opencode/agent/subagents/meta-builder-agent.md .opencode/extensions/core/agents/meta-builder-agent.md`
