# Implementation Plan: Task #594

- **Task**: 594 - Refactor workflow skills to shared base library
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: Task 593 (completed), Task 598 (design constraint only -- not blocking)
- **Research Inputs**: reports/01_seed-research.md, reports/02_refactor-shared-base.md, reports/03_design-guidance.md
- **Artifacts**: plans/02_refactor-shared-base.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extract ~210 lines of duplicated lifecycle logic from skill-researcher (558L), skill-planner (490L), and skill-implementer (629L) into a shared shell library `.claude/scripts/skill-base.sh` containing 11 functions. Each skill retains only its unique logic: context collection (Stage 4 variants), delegation context construction, and agent invocation (Stage 5). The continuation loop in skill-implementer stays inline. Extension hooks are explicitly out of scope (deferred to task 599).

### Research Integration

Three research reports inform this plan:
- **01_seed-research.md**: Identified 8 of 11 stages as structurally identical across skills; confirmed task 500 superseded; recommended validation-first approach (refactor one skill, test, then proceed).
- **02_refactor-shared-base.md**: Line-by-line duplication analysis; mapped all 11 functions to stage blocks; identified parameter variance table; confirmed continuation loop must stay inline; size reduction estimates.
- **03_design-guidance.md**: Complete function signatures with code for all 11 functions; hook point specification; target sizes; implementation order recommendation.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is internal agent infrastructure (meta task type) that improves maintainability for future roadmap work.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Create `skill-base.sh` with 11 shared lifecycle functions
- Reduce skill-researcher from 558L to ~150L
- Reduce skill-planner from 490L to ~130L
- Reduce skill-implementer from 629L to ~200L
- Maintain functional equivalence with current behavior
- Reserve `SKILL_CONTEXT_BUDGET` variable hook for task 598

**Non-Goals**:
- Extension hooks (task 599 scope)
- Refactoring skill-reviser (separate follow-on)
- Refactoring team skills (skill-team-research, skill-team-plan, skill-team-implement)
- Context budget enforcement logic (task 598 scope)
- Modifying the continuation loop structure in skill-implementer

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Skill-base.sh sourcing across Bash invocations fails | H | M | Document that `source` + function calls must be in the same Bash invocation; test pattern in Phase 1 |
| Extension skills break after core skill refactor | H | L | Test extension skills (neovim, nix) after each core skill refactor in Phase validation |
| Abstraction overhead increases token cost | M | L | Measure skill file sizes before/after; abort if sizes exceed targets |
| Variable name collisions between sourced scripts | M | L | Use SKILL_* prefix for all skill-base.sh exports |
| Continuation loop in implementer becomes entangled with shared functions | M | L | Keep continuation loop entirely inline; only extract the non-looping stages |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

### Phase 1: Create skill-base.sh Library [COMPLETED]

**Goal**: Create the shared shell library with all 11 functions, tested in isolation.

**Tasks**:
- [ ] Create `.claude/scripts/skill-base.sh` with shebang and header comment explaining sourcing semantics
- [ ] Implement `skill_validate_input` -- jq lookup in state.json, export TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM, TASK_DIR
- [ ] Implement `skill_preflight_update` -- call update-task-status.sh preflight with operation parameter
- [ ] Implement `skill_create_postflight_marker` -- write .postflight-pending JSON file
- [ ] Implement `skill_read_artifact_number` -- read next_artifact_number from state.json, export ARTIFACT_NUMBER, ARTIFACT_PADDED (handle "current" vs "prev" mode for researcher vs planner/implementer)
- [ ] Implement `skill_read_metadata` -- read .return-meta.json, export SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES
- [ ] Implement `skill_validate_artifact` -- call validate-artifact.sh --fix (non-blocking)
- [ ] Implement `skill_postflight_update` -- call update-task-status.sh postflight, map operation to target status
- [ ] Implement `skill_increment_artifact_number` -- python3 jq-equivalent increment (research only)
- [ ] Implement `skill_propagate_memory_candidates` -- python3 append to state.json entry
- [ ] Implement `skill_link_artifacts` -- two-step jq pattern (Issue #1132 safe) + link-artifact-todo.sh call
- [ ] Implement `skill_cleanup` -- rm marker, loop-guard, and metadata files
- [ ] Add `SKILL_CONTEXT_BUDGET` variable hook with defaults (8000 for sonnet, 15000 for opus)
- [ ] Make the file executable (`chmod +x`)
- [ ] Verify `bash -n .claude/scripts/skill-base.sh` passes syntax check

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Create new (target: ~120-150 lines)

**Verification**:
- `bash -n .claude/scripts/skill-base.sh` exits 0 (syntax valid)
- All 11 function names are defined (grep for each function name)
- File size is between 100-180 lines

---

### Phase 2: Refactor skill-researcher [COMPLETED]

**Goal**: Replace duplicated lifecycle stages in skill-researcher with calls to skill-base.sh functions, reducing from 558L to ~150L while maintaining identical behavior.

**Tasks**:
- [ ] Read current skill-researcher/SKILL.md and identify each stage block that maps to a skill-base.sh function
- [ ] Rewrite Stage 1 to reference `skill_validate_input` instead of inline jq
- [ ] Rewrite Stage 2 to reference `skill_preflight_update`
- [ ] Rewrite Stage 3 to reference `skill_create_postflight_marker`
- [ ] Rewrite Stage 3a to reference `skill_read_artifact_number` with mode="current" (researcher uses current number, not prev)
- [ ] Preserve Stage 4a (memory retrieval) -- skill-specific, stays inline
- [ ] Preserve Stage 4c (roadmap consultation) -- skill-specific, stays inline
- [ ] Preserve Stage 4d (prior implementation context) -- skill-specific, stays inline
- [ ] Preserve Stage 4/4b (delegation context + format injection) -- skill-specific, stays inline
- [ ] Preserve Stage 5 (subagent invocation) -- skill-specific subagent_type
- [ ] Rewrite Stage 6 to reference `skill_read_metadata`
- [ ] Rewrite Stage 6a to reference `skill_validate_artifact`
- [ ] Rewrite Stage 7 to reference `skill_postflight_update` + `skill_increment_artifact_number`
- [ ] Rewrite Stage 7a to reference `skill_propagate_memory_candidates`
- [ ] Rewrite Stage 8 to reference `skill_link_artifacts`
- [ ] Rewrite Stage 9 (cleanup) to reference `skill_cleanup`
- [ ] Preserve Stage 5b (self-execution fallback) -- keep inline, brief
- [ ] Preserve MUST NOT / error handling sections -- keep as documentation
- [ ] Verify final line count is 130-180 lines
- [ ] Run a mental walkthrough of the full lifecycle to confirm no stage was dropped

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Major rewrite (558L -> ~150L)

**Verification**:
- Line count: `wc -l .claude/skills/skill-researcher/SKILL.md` shows 130-180 lines
- All shared stages reference skill-base.sh functions
- All skill-specific stages (4a, 4c, 4d, 4b, 5) remain inline
- Frontmatter and header documentation preserved
- No references to deleted inline code remain

---

### Phase 3: Refactor skill-planner [COMPLETED]

**Goal**: Replace duplicated lifecycle stages in skill-planner with calls to skill-base.sh functions, reducing from 490L to ~130L while maintaining identical behavior.

**Tasks**:
- [ ] Read current skill-planner/SKILL.md and identify each stage block that maps to a skill-base.sh function
- [ ] Rewrite Stage 1 to reference `skill_validate_input`
- [ ] Rewrite Stage 2 to reference `skill_preflight_update`
- [ ] Rewrite Stage 3 to reference `skill_create_postflight_marker`
- [ ] Rewrite Stage 3a to reference `skill_read_artifact_number` with mode="prev" (planner uses next-1)
- [ ] Preserve Stage 4a (memory retrieval) -- skill-specific, stays inline
- [ ] Preserve Stage 4 (prior plan discovery + delegation context) -- skill-specific, stays inline
- [ ] Preserve Stage 4b (format injection) -- skill-specific, stays inline
- [ ] Preserve Stage 5 (subagent invocation) -- skill-specific subagent_type
- [ ] Rewrite Stage 6 to reference `skill_read_metadata`
- [ ] Rewrite Stage 6a to reference `skill_validate_artifact`
- [ ] Rewrite Stage 7 to reference `skill_postflight_update` (no increment, no memory propagation for planner)
- [ ] Rewrite Stage 8 to reference `skill_link_artifacts`
- [ ] Preserve Stage 9 (git commit) -- keep inline (planner-specific: 3-line block)
- [ ] Rewrite Stage 10 (cleanup) to reference `skill_cleanup`
- [ ] Preserve Stage 5b (self-execution fallback) -- keep inline, brief
- [ ] Preserve MUST NOT / error handling sections
- [ ] Verify final line count is 110-150 lines

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Major rewrite (490L -> ~130L)

**Verification**:
- Line count: `wc -l .claude/skills/skill-planner/SKILL.md` shows 110-150 lines
- All shared stages reference skill-base.sh functions
- Prior plan discovery and git commit remain inline
- No planner-specific logic was accidentally removed

---

### Phase 4: Refactor skill-implementer [COMPLETED]

**Goal**: Replace duplicated lifecycle stages in skill-implementer with calls to skill-base.sh functions, reducing from 629L to ~200L while keeping the continuation loop and implementer-specific postflight steps inline.

**Tasks**:
- [ ] Read current skill-implementer/SKILL.md and identify each stage block that maps to a skill-base.sh function
- [ ] Rewrite Stage 1 to reference `skill_validate_input`
- [ ] Rewrite Stage 2 to reference `skill_preflight_update`
- [ ] Rewrite Stage 3 to reference `skill_create_postflight_marker`
- [ ] Rewrite Stage 3a to reference `skill_read_artifact_number` with mode="prev"
- [ ] Preserve Stage 4a (memory retrieval) -- skill-specific, stays inline
- [ ] Preserve Stage 4 (plan path discovery + delegation context) -- skill-specific, stays inline
- [ ] Preserve Stage 4b (format injection) -- skill-specific, stays inline
- [ ] Preserve Stage 5 (subagent invocation) -- skill-specific subagent_type
- [ ] Preserve Stage 5a (validate subagent return format) -- skill-specific
- [ ] Preserve Stage 5c (continuation loop init) -- skill-specific
- [ ] Rewrite Stage 6 to reference `skill_read_metadata` (note: implementer reads extra fields -- phases_completed, phases_total, completion_summary, roadmap_items, handoff_path -- these must be read inline after shared function)
- [ ] Rewrite Stage 6a to reference `skill_validate_artifact`
- [ ] Preserve Stage 6b (commit phase progress inside loop) -- skill-specific
- [ ] Preserve Stage 7 "implemented" branch Steps 2-5 (completion_summary, roadmap_items, memory candidates, recommended_order) -- implementer-specific, stays inline
- [ ] Use `skill_postflight_update` for Step 1 of Stage 7 "implemented" branch
- [ ] Preserve Stage 7 "partial" branch entirely -- continuation loop logic, stays inline
- [ ] Rewrite Stage 8 to reference `skill_link_artifacts`
- [ ] Preserve Stage 9 (git commit) -- keep inline
- [ ] Rewrite Stage 10 (cleanup) to reference `skill_cleanup` plus inline `.continuation-loop-guard` removal
- [ ] Preserve pre-delegation boundary and MUST NOT sections
- [ ] Verify final line count is 180-220 lines

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Major rewrite (629L -> ~200L)

**Verification**:
- Line count: `wc -l .claude/skills/skill-implementer/SKILL.md` shows 180-220 lines
- Continuation loop (Stages 5c, 6b, 7-partial, handoff logic) fully preserved inline
- Implementer-specific postflight steps (completion_summary, roadmap_items, recommended_order) preserved
- All shared stages reference skill-base.sh functions
- Extra metadata fields (phases_completed, handoff_path) read inline after shared skill_read_metadata

---

### Phase 5: Validation and Documentation [COMPLETED]

**Goal**: Verify functional equivalence across all three refactored skills and document the shared pattern.

**Tasks**:
- [ ] Verify skill-base.sh line count (target: 100-180 lines)
- [ ] Verify total line count across all 3 skills (target: ~480 lines combined, down from 1677)
- [ ] Confirm all 11 functions in skill-base.sh are referenced by at least one skill
- [ ] Verify extension skills still structurally valid (check that skill-neovim-research, skill-nix-research, skill-neovim-implementation, skill-nix-implementation do not hard-reference removed stage blocks from core skills)
- [ ] Verify no stage was dropped: cross-reference each skill's stage list against the original to confirm all stages are either (a) in skill-base.sh or (b) inline in the skill
- [ ] Add a comment block at the top of skill-base.sh documenting: sourcing semantics, variable exports, and that extension hooks are deferred to task 599
- [ ] Verify `SKILL_CONTEXT_BUDGET` variable is defined with defaults (8000/15000) and documented as overridable
- [ ] Confirm jq Issue #1132 safe patterns are used in skill_link_artifacts (two-step pattern with `| not`)
- [ ] Run `bash -n .claude/scripts/skill-base.sh` final syntax check

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Add/refine documentation comments
- `.claude/skills/skill-researcher/SKILL.md` - Minor fixes if validation finds issues
- `.claude/skills/skill-planner/SKILL.md` - Minor fixes if validation finds issues
- `.claude/skills/skill-implementer/SKILL.md` - Minor fixes if validation finds issues

**Verification**:
- `bash -n .claude/scripts/skill-base.sh` exits 0
- `wc -l` for all 4 files within target ranges
- Extension skill files contain no broken references to core skill internals
- All parameter variance from research report 02 is covered (operation, subagent_type, completion_status, artifact_dir, format_file, artifact_number_mode, increment, propagate_memory, git_commit, continuation_loop, link_before_label)

## Testing & Validation

- [ ] `bash -n .claude/scripts/skill-base.sh` passes (shell syntax valid)
- [ ] All 11 function names present in skill-base.sh (grep verification)
- [ ] skill-researcher line count between 130-180
- [ ] skill-planner line count between 110-150
- [ ] skill-implementer line count between 180-220
- [ ] skill-base.sh line count between 100-180
- [ ] Combined total (3 skills + skill-base.sh) under 700 lines (down from 1677)
- [ ] No hardcoded stage blocks duplicated across skills (grep for sentinel patterns like `.postflight-pending` creation -- should appear only in skill-base.sh)
- [ ] Extension skills (neovim, nix) have no broken references
- [ ] SKILL_CONTEXT_BUDGET variable defined with correct defaults

## Artifacts & Outputs

- `.claude/scripts/skill-base.sh` -- New shared library (11 functions, ~120-150 lines)
- `.claude/skills/skill-researcher/SKILL.md` -- Refactored (558L -> ~150L)
- `.claude/skills/skill-planner/SKILL.md` -- Refactored (490L -> ~130L)
- `.claude/skills/skill-implementer/SKILL.md` -- Refactored (629L -> ~200L)

## Rollback/Contingency

All three skill files are tracked in git. If the refactoring introduces regressions:
1. `git diff HEAD~1 -- .claude/skills/` shows exact changes
2. `git checkout HEAD~1 -- .claude/skills/skill-researcher/SKILL.md` (etc.) reverts individual skills
3. `skill-base.sh` can be deleted without affecting any other files since the old inline code is in git history
4. Partial rollback is possible: revert one skill while keeping others refactored, since each skill independently sources the shared library
