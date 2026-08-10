# Implementation Plan: Task #582

- **Task**: 582 - Port command integration (task.md, todo.md, review.md)
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 579 (generate-task-order.sh), Task 580 (topic schema)
- **Research Inputs**: specs/582_port_command_integration/reports/01_port-command-integration.md
- **Artifacts**: plans/01_port-command-integration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port task order auto-sync and topic support from ProofChecker into the nvim-config command files (task.md, todo.md, review.md). This task integrates the infrastructure already ported in tasks 579 (generate-task-order.sh) and 580 (state-management-schema.md topic fields) by updating the command files to use them. All ProofChecker-specific hardcoded topic keywords are replaced with dynamic `active_topics` from state.json, and the review.md manual Task Order management (~639 lines) is replaced with a single `generate-task-order.sh` call.

### Research Integration

Research report `reports/01_port-command-integration.md` provides detailed line-by-line diffs between the nvim-config and ProofChecker versions of all three files. Key findings:
- task.md has 6 additions (~104 lines): Step 4.5 topic picker, state.json topic field, Part C regen call, expand/sync/review mode topic inheritance
- todo.md has 2 additions (~34 lines): post-archival and post-vault Task Order regeneration
- review.md has 3 changes: Section 2.6 format update, Section 5.6.3 topic inference, and Sections 6.5-6.7 replacement (~639 lines replaced with ~70 lines)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is agent-system infrastructure work.

## Goals & Non-Goals

**Goals**:
- Add generalized topic picker (Step 4.5) to task.md using dynamic `active_topics` from state.json
- Add topic field to all state.json write operations in task.md (create, expand, review modes)
- Replace old `update-recommended-order.sh` call with `generate-task-order.sh --update-todo` in task.md
- Add post-archival and post-vault Task Order regeneration to todo.md
- Replace review.md Section 2.6 old category-based parsing with wave+tree format parsing
- Add extension-aware topic inference to review.md Section 5.6.3
- Replace review.md Sections 6.5-6.7 (~639 lines of manual Task Order management) with simplified script-based approach (~70 lines)
- Update review.md git commit message and standards reference table

**Non-Goals**:
- Implementing project-specific topic keywords (all topics are dynamic from state.json)
- Adding new functionality beyond what ProofChecker already has
- Modifying generate-task-order.sh or state-management-schema.md (already ported)
- Adding topic auto-inference heuristics (deferred; picker-only for now)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Empty `active_topics` in state.json causes empty picker | M | H | Ensure picker always offers "New topic..." and "Skip (no topic)" fallback options |
| Old `update-recommended-order.sh` reference in task.md may not exist | L | M | New `generate-task-order.sh` call is non-fatal with `2>/dev/null` fallback |
| review.md 639-line replacement could break surrounding sections | H | L | Verify line ranges before/after edit; use targeted Edit operations with context |
| review.md Section 2.6 wave+tree format must match generate-task-order.sh output | M | L | ProofChecker version already validated; format matches Task 579 script |
| jq `!=` operator escaping (Issue #1132) in topic conditionals | M | M | Use `if $topic == "" | not then $topic else null end` pattern per jq-escaping-workarounds.md |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: task.md -- Topic picker and state.json updates [COMPLETED]

**Goal**: Add Step 4.5 topic picker, include topic field in state.json writes, and replace Part C regen call in the Create Task Mode section.

**Tasks**:
- [x] Insert Step 4.5 (topic picker) after Step 4 (task_type detection, around line 131). Content: read `active_topics` from state.json via jq, present AskUserQuestion picker with dynamic options plus "New topic..." and "Skip (no topic)" fallbacks. No hardcoded keyword heuristic -- purely dynamic from state.json. *(completed)*
- [x] Update Step 6 (state.json update, around line 138-152) to include `--arg topic "$topic"` and the conditional topic field in the jq command. Use `| not` pattern for the empty-string check to avoid jq escaping issues. *(completed)*
- [x] Replace Part C (lines 177-183) old `update-recommended-order.sh` call with new `generate-task-order.sh --update-todo` call pattern. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Create Task Mode: Steps 4.5, 6, and Part C

**Verification**:
- Step 4.5 reads from `active_topics` in state.json, not hardcoded keywords
- Step 6 jq includes topic field with conditional presence
- Part C references `generate-task-order.sh` instead of `update-recommended-order.sh`

---

### Phase 2: task.md -- Expand, Sync, and Review mode topic inheritance [COMPLETED]

**Goal**: Add topic inheritance and backfill support to the Expand, Sync, and Review modes of task.md.

**Tasks**:
- [x] Expand Mode: Insert Step 2.5 (read parent topic from state.json) between Step 2 "Analyze description" and Step 3 "Create 2-5 subtasks" (around line 269-271). Update Step 3 to include topic inheritance in the subtask jq entries. *(completed)*
- [x] Sync Mode: Insert Step 6.5 (topic backfill) after Step 6 (git commit, around line 313). Content: detect active tasks missing topic field, present AskUserQuestion multiSelect for user to assign topics from `active_topics`. No auto-inference heuristic -- purely picker-based. *(completed)*
- [x] Review Mode: Insert Step 7.5 (read parent topic for inheritance) between Step 7 (interactive selection, around line 479-492) and Step 8 (create follow-up tasks). Update Step 8 jq command (around line 498-523) to include `--arg topic "$parent_topic"` and conditional topic field. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/task.md` - Expand Mode (Step 2.5 + Step 3 update), Sync Mode (Step 6.5), Review Mode (Step 7.5 + Step 8 update)

**Verification**:
- Expand Mode creates subtasks that inherit parent topic
- Sync Mode detects and offers to backfill tasks without topics
- Review Mode follow-up tasks inherit parent topic
- All topic assignments read from `active_topics` dynamically

---

### Phase 3: todo.md -- Post-archival and post-vault Task Order regeneration [COMPLETED]

**Goal**: Add two Task Order regeneration calls to the /todo command: one after archival (Step 5.8) and one after vault renumbering (Step 5.8.8a).

**Tasks**:
- [x] Insert new Step 5.8 (Regenerate Task Order) between the current Step 5.6 (Sync Repository Metrics, ending around line 674) and Step 5.7 (Vault Operation, starting at line 675). Content: non-fatal `generate-task-order.sh --update-todo` call with existence check and error handling. *(completed)*
- [x] Insert Step 5.8.8a (Re-run Task Order Regeneration after Renumbering) between Step 5.8.8 (Reset state, ending at line 784) and Step 5.8.9 (Add transition comment, starting at line 786). Content: same non-fatal regen call, needed because task numbers changed. *(completed)*
- [x] Update the git commit message section (Step 6, around line 799-825) to include note about appending ", regenerate task order" when Task Order regeneration ran. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/commands/todo.md` - Insert Step 5.8 after metrics sync, insert Step 5.8.8a after vault reset, update git commit note

**Verification**:
- Step 5.8 exists between metrics sync and vault operation
- Step 5.8.8a exists between vault reset and transition comment
- Both calls use non-fatal pattern with existence check
- Git commit message note references Task Order regeneration

---

### Phase 4: review.md -- Replace Task Order management and add topic inference [COMPLETED]

**Goal**: Update Section 2.6 to wave+tree format, add topic inference to Section 5.6.3, and replace Sections 6.5-6.7 with simplified script-based approach.

**Tasks**:
- [x] Replace Section 2.6 (Parse Task Order, lines 213-338) with ProofChecker's wave+tree parsing format. Key changes: replace "Parse category subsections" (step 3), "Parse task entries within each category" (step 4), "Parse dependency chains from code blocks" (step 5), and "Build dependency graph" (step 6) with "Parse wave table" (step 3), "Parse dependency tree entries" (step 4). Update the `task_order_state` structure from `categories[]`/`dependency_graph` to `waves[]`/`tree_entries[]`. *(completed)*
- [x] Add topic inference step to Section 5.6.3 (State Updates, around line 776-802). Insert Step 3 "Infer topic from file path and description" using extension-aware path matching: `.claude/`/`specs/` files -> check for "meta" or "agent-system" in `active_topics`; `lua/`/`after/` files -> check `active_topics` for neovim-related topics; fallback -> no topic. Update Step 4 jq command to include `--arg topic "$inferred_topic"` and conditional topic field. *(completed)*
- [x] Replace Section 6.5 (Prune Task Order, lines 842-964), Section 6.6 (Insert New Tasks, lines 966-1172), and Section 6.7 (Interactive Management, lines 1174-1480) with ProofChecker's simplified versions: Section 6.5 becomes single `generate-task-order.sh --update-todo` call (~30 lines); Section 6.6 becomes 3-line tombstone; Section 6.7 becomes simplified skip conditions + brief summary + goal statement update only (~90 lines). *(completed: 639 lines replaced with ~122 lines)*
- [x] Update Section 7 git commit message (around line 1504-1515) to use `Task Order: {regenerated_or_skipped}` format instead of `Task Order: {pruned_count} pruned, {inserted_count} added, {reassigned_count} reassigned`. *(completed)*
- [x] Update Standards Reference table (around line 1519-1536) to change Dependencies row from `Yes | Interactive dependency selection (Section 6.7.4)` to `Partial | Declared in state.json; Task Order generated by script`. Update the note below the table to reference `generate-task-order.sh` and Section 6.7.3. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:
- `.claude/commands/review.md` - Section 2.6 (wave+tree parsing), Section 5.6.3 (topic inference), Sections 6.5-6.7 (replacement), Section 7 (commit message), Standards Reference (table update)

**Verification**:
- Section 2.6 parses wave table and tree entries instead of categories
- Section 5.6.3 includes extension-aware topic inference using `active_topics`
- Section 6.5 uses single `generate-task-order.sh --update-todo` call
- Section 6.6 is a 3-line tombstone
- Section 6.7 has only skip conditions, brief summary, and goal statement update
- Git commit message uses `{regenerated_or_skipped}` format
- Standards Reference reflects script-based approach

---

## Testing & Validation

- [ ] Verify task.md Step 4.5 topic picker reads from state.json `active_topics` dynamically (no hardcoded keywords)
- [ ] Verify all jq commands with topic conditionals use `| not` pattern instead of `!=` to avoid Issue #1132
- [ ] Verify task.md Part C references `generate-task-order.sh` instead of `update-recommended-order.sh`
- [ ] Verify todo.md Step 5.8 is positioned between metrics sync and vault operation
- [ ] Verify todo.md Step 5.8.8a is positioned between vault reset and transition comment
- [ ] Verify review.md Section 2.6 `task_order_state` structure uses `waves[]` and `tree_entries[]` (not `categories[]`)
- [ ] Verify review.md Sections 6.5-6.7 are replaced (net reduction of ~570 lines)
- [ ] Verify no ProofChecker-specific terms remain (bilateral, algebraic-representation, Theories/Bimodal, .lean heuristics)
- [ ] Run `grep -rn "update-recommended-order" .claude/commands/` returns no results
- [ ] Run `grep -rn "hardcoded\|bilateral\|algebraic-representation" .claude/commands/` returns no results

## Artifacts & Outputs

- `.claude/commands/task.md` - Updated with topic picker, topic field in state.json, and regen call
- `.claude/commands/todo.md` - Updated with post-archival and post-vault regen steps
- `.claude/commands/review.md` - Updated with wave+tree parsing, topic inference, and simplified Task Order management
- `specs/582_port_command_integration/plans/01_port-command-integration.md` - This plan
- `specs/582_port_command_integration/summaries/01_port-command-integration-summary.md` - Implementation summary

## Rollback/Contingency

All three command files are tracked in git. If implementation fails or introduces issues:
1. `git checkout -- .claude/commands/task.md .claude/commands/todo.md .claude/commands/review.md` to revert
2. The old manual Task Order management in review.md is preserved in git history
3. Tasks 579 and 580 infrastructure remains unaffected by any rollback
