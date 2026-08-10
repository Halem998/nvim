# Implementation Plan: Task #656

- **Task**: 656 - Add topic assignment to 6 task creation points with missing/incomplete handling
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: Task 654 (manage-topics.sh and topic-assignment-pattern.md -- already completed)
- **Research Inputs**: specs/656_add_topic_assignment_gaps/reports/01_add-topic-gaps.md
- **Artifacts**: plans/01_add-topic-gaps-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Six task creation points across the agent system have missing or incomplete topic assignment. Each site maps to one of three established patterns from topic-assignment-pattern.md: Mode C suggest-wrap (fix-it, review), Mode A picker-insert (project-overview), and Mode B inherit-with-fallback (spawn, task --expand, task --review). All inline jq topic manipulation must be replaced with calls to manage-topics.sh. Every change to a main file must be mirrored in its identical extension copy under `.claude/extensions/core/`.

### Research Integration

The research report (01_add-topic-gaps.md) confirmed all 6 gaps with exact line numbers and current code snippets. Key findings:
- All extension copies are byte-for-byte identical; changes must be mirrored
- `manage-topics.sh set` must be called AFTER the task entry exists in state.json (exit code 4 otherwise)
- Mode B sites currently have no fallback picker when parent has no topic; the task requires adding Mode A fallback
- Decision 5 from research: `set` internally calls `add`, so standalone `add` before `set` is redundant; calling only `set` after task creation is sufficient. Standalone `add` is only needed when no `set` follows (e.g., review.md where topic write is embedded in a larger jq block).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add interactive topic confirmation (Mode C) to fix-it and review command task creation
- Add full interactive topic picker (Mode A) to project-overview task creation
- Add Mode A fallback picker to spawn, --expand, and --review when parent has no topic
- Replace all inline jq topic/active_topics manipulation with manage-topics.sh calls
- Mirror every change to the corresponding `.claude/extensions/core/` copy

**Non-Goals**:
- Modifying manage-topics.sh or topic-assignment-pattern.md (already complete from task 654)
- Adding topic assignment to commands not listed in the task (e.g., /task create, /meta -- already handled)
- Changing the auto-inference heuristic logic itself (only wrapping it with user confirmation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension copy drift (forgetting to mirror) | M | M | Phase 4 is dedicated to syncing; each earlier phase lists both paths |
| `manage-topics.sh set` called before task entry exists | H | L | Research confirmed ordering; each phase specifies call placement after state.json write |
| Batch task prompt fatigue in fix-it | M | L | Confirm fires per-task only when inference is non-empty; empty-inference skips silently |
| task.md has two independent modification sites | L | L | Treated as separate subsections in one phase; clear section markers prevent cross-contamination |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Mode C Suggest-Wrap (fix-it + review) [COMPLETED]

**Goal**: Add 3-option suggest-confirmation to the two sites that auto-infer topics, and replace inline jq with manage-topics.sh calls.

**Tasks**:
- [x] **fix-it SKILL.md**: In Step 9.1, after the existing auto-inference heuristic produces a topic, insert a Mode C suggest-confirmation AskUserQuestion with 3 options: "Accept: {inferred_topic}", "Override...", "Skip (no topic)". If user selects "Override...", show follow-up free-text question. If inference produced empty string, skip confirm entirely (no topic assigned). *(completed)*
- [x] **fix-it SKILL.md**: In Step 9.3, replace the inline `active_topics` jq append block with `manage-topics.sh set "$task_num" "$topic"` call (placed AFTER the task entry is written to state.json). Remove the old inline jq snippet. *(completed)*
- [x] **fix-it SKILL.md**: Ensure the `manage-topics.sh set` call only executes when topic is non-empty and not "Skip (no topic)". *(completed)*
- [x] **review.md**: In Section 5.6.3, after the extension-aware path heuristic, insert the same 3-option Mode C confirm AskUserQuestion. *(completed)*
- [x] **review.md**: After user confirms/overrides topic, add `manage-topics.sh set "$next_num" "$topic"` call to update active_topics (the current bug: active_topics is read but never written back). *(completed)*
- [x] **review.md**: Ensure the topic variable flows into the existing `active_projects +=` jq block correctly (the inline `"topic":` expression now uses `$topic` from confirm result). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-fix-it/SKILL.md` -- Add Mode C confirm after inference, replace inline jq with manage-topics.sh
- `.claude/commands/review.md` -- Add Mode C confirm after inference, add active_topics maintenance

**Verification**:
- grep for `manage-topics.sh` in both files confirms script usage
- grep for old inline `active_topics` jq append pattern in fix-it confirms removal
- Each file contains an AskUserQuestion block with 3 options (Accept/Override/Skip)

---

### Phase 2: Mode A Picker-Insert (project-overview) [COMPLETED]

**Goal**: Add full interactive topic picker to project-overview, which currently has no topic handling at all.

**Tasks**:
- [x] **project-overview SKILL.md**: Insert a new sub-step "Step 5.2.5: Assign Topic" between the directory/artifact creation (Step 5.2) and the state.json update (Step 5.3). *(completed)*
- [x] The new step uses `manage-topics.sh list` to build the AskUserQuestion options array, following Mode A template from topic-assignment-pattern.md: existing topics + "New topic..." + "Skip (no topic)". *(completed)*
- [x] Handle "New topic..." branch with follow-up free-text AskUserQuestion for kebab-case topic name. *(completed)*
- [x] In Step 5.3's jq block that creates the task entry, add `"topic": (if ($topic == "" | not) then $topic else null end)` field, with `| if .topic == null then del(.topic) else . end` cleanup. *(completed)*
- [x] After the state.json write in Step 5.3, call `manage-topics.sh set "$next_num" "$topic"` (only if topic is non-empty and not "Skip"). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-project-overview/SKILL.md` -- Insert Mode A picker step and topic field in state.json write

**Verification**:
- File contains `manage-topics.sh list` call for option building
- File contains AskUserQuestion with "New topic..." and "Skip (no topic)" options
- The state.json jq block in Step 5.3 includes a `"topic"` field

---

### Phase 3: Mode B Inherit-with-Fallback (spawn, --expand, --review) [COMPLETED]

**Goal**: Add Mode A fallback picker to the three inheritance sites when parent task has no topic, and replace inline jq with manage-topics.sh calls.

**Tasks**:
- [x] **spawn SKILL.md**: After Stage 1 reads `parent_topic`, insert conditional: if `parent_topic` is empty, show full Mode A interactive picker (same template as Phase 2). Set `parent_topic` from picker result. No change when parent has a topic (silent inheritance continues). *(completed)*
- [x] **spawn SKILL.md**: In Stage 14a, replace inline `active_topics` append jq with `manage-topics.sh set "$new_task_num" "$parent_topic"` call. Ensure it runs AFTER the Stage 11 state.json task entry write. *(completed)*
- [x] **task.md --expand**: After Step 2.5 reads `parent_topic`, insert conditional: if empty, show Mode A picker. Set `parent_topic` from result. *(completed)*
- [x] **task.md --expand**: In Step 3 subtask creation, ensure topic is applied via `manage-topics.sh set` for each created subtask (called after each subtask entry is written to state.json). Replace any inline jq topic handling. *(completed)*
- [x] **task.md --review**: After Step 7.5 reads `parent_topic`, insert new "Step 7.6: Fallback Topic Picker": if `parent_topic` is empty, show Mode A picker. *(completed)*
- [x] **task.md --review**: In Step 8, add `manage-topics.sh set "$next_num" "$parent_topic"` call after each follow-up task state.json write. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-spawn/SKILL.md` -- Add fallback picker + replace inline jq
- `.claude/commands/task.md` -- Two sections: --expand (add fallback picker + manage-topics.sh) and --review (add fallback picker + replace inline jq)

**Verification**:
- Each file contains a conditional "if parent_topic is empty, show picker" block
- grep for `manage-topics.sh set` in all three files confirms script usage
- grep for old inline `active_topics` jq append in spawn and task.md confirms removal
- task.md has changes in both --expand and --review sections

---

### Phase 4: Extension Copy Sync + Validation [COMPLETED]

**Goal**: Mirror all Phase 1-3 changes to the identical extension copies under `.claude/extensions/core/`, then validate consistency.

**Tasks**:
- [x] Copy `.claude/skills/skill-fix-it/SKILL.md` to `.claude/extensions/core/skills/skill-fix-it/SKILL.md` *(completed)*
- [x] Copy `.claude/commands/review.md` to `.claude/extensions/core/commands/review.md` *(completed)*
- [x] Copy `.claude/skills/skill-project-overview/SKILL.md` to `.claude/extensions/core/skills/skill-project-overview/SKILL.md` *(completed)*
- [x] Copy `.claude/skills/skill-spawn/SKILL.md` to `.claude/extensions/core/skills/skill-spawn/SKILL.md` *(completed)*
- [x] Copy `.claude/commands/task.md` to `.claude/extensions/core/commands/task.md` *(completed)*
- [x] Run `diff` on each main file vs extension copy to confirm they are identical (0 differences expected) — all 5 pairs identical *(completed)*
- [x] Grep all 10 files (5 main + 5 extension) for `manage-topics.sh` to confirm script is referenced in all modified files — all 10 hit *(completed)*
- [x] Grep all 10 files for any remaining inline `active_topics` jq append patterns (should find none in the modified sections) — none found *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/extensions/core/skills/skill-fix-it/SKILL.md` -- Mirror of Phase 1 fix-it changes
- `.claude/extensions/core/commands/review.md` -- Mirror of Phase 1 review changes
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md` -- Mirror of Phase 2 changes
- `.claude/extensions/core/skills/skill-spawn/SKILL.md` -- Mirror of Phase 3 spawn changes
- `.claude/extensions/core/commands/task.md` -- Mirror of Phase 3 task.md changes

**Verification**:
- `diff` returns 0 for all 5 pairs (main vs extension copy)
- grep for `manage-topics.sh` hits all 10 files
- No stale inline jq `active_topics` append patterns remain in modified sections

---

## Testing & Validation

- [ ] All 5 main files contain references to `manage-topics.sh` (grep confirms)
- [ ] All 5 extension copies are byte-identical to their main counterparts (diff confirms)
- [ ] No inline `active_topics` jq append snippets remain in modified files (grep confirms removal)
- [ ] Each Mode C site (fix-it, review) has an AskUserQuestion with Accept/Override/Skip options
- [ ] Each Mode A site (project-overview) has a full picker with existing topics + "New topic..." + "Skip"
- [ ] Each Mode B fallback site (spawn, --expand, --review) has a conditional: if parent_topic empty then show Mode A picker
- [ ] `manage-topics.sh set` calls appear AFTER state.json task entry writes in all sites
- [ ] manage-topics.sh script itself is unchanged (no modifications to task 654 output)

## Artifacts & Outputs

- `specs/656_add_topic_assignment_gaps/plans/01_add-topic-gaps-plan.md` (this plan)
- `specs/656_add_topic_assignment_gaps/summaries/01_add-topic-gaps-summary.md` (post-implementation)
- Modified files:
  - `.claude/skills/skill-fix-it/SKILL.md` + extension copy
  - `.claude/commands/review.md` + extension copy
  - `.claude/skills/skill-project-overview/SKILL.md` + extension copy
  - `.claude/skills/skill-spawn/SKILL.md` + extension copy
  - `.claude/commands/task.md` + extension copy

## Rollback/Contingency

All target files are tracked in git. If implementation introduces issues:
1. `git checkout -- .claude/skills/skill-fix-it/SKILL.md .claude/commands/review.md .claude/skills/skill-project-overview/SKILL.md .claude/skills/skill-spawn/SKILL.md .claude/commands/task.md`
2. Apply the same checkout to the 5 extension copies under `.claude/extensions/core/`
3. manage-topics.sh and topic-assignment-pattern.md remain untouched (task 654 artifacts)
