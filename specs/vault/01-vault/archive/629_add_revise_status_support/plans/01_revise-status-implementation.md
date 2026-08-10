# Implementation Plan: Add "revise" support to update-task-status.sh and skill-reviser

- **Task**: 629 - Add "revise" support to update-task-status.sh and skill-reviser
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/629_add_revise_status_support/reports/01_revise-status-research.md
- **Artifacts**: plans/01_revise-status-implementation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/revise` command currently bypasses preflight status tracking and incorrectly sets postflight status to `[PLANNED]` instead of the standard-prescribed `[REVISED]`. Three files need surgical edits to bring `/revise` into alignment with `/research`, `/plan`, and `/implement`: `update-task-status.sh` must accept "revise" as a valid target_status, `skill-base.sh` must recognize "revised" as a success status, and `skill-reviser/SKILL.md` must call preflight and use the correct postflight target.

### Research Integration

The research report (01_revise-status-research.md) confirmed that `status-markers.md` already defines `[REVISING]`/`[REVISED]` as the correct pair, and that `preflight-pattern.md` and `postflight-pattern.md` both specify `"revise"` mappings. Five specific edits across three files were identified. No plan file update logic is needed for revise (revised plans are new artifacts, not status header updates).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Enable `update-task-status.sh` to accept "revise" as a target_status with correct `[REVISING]`/`[REVISED]` mappings
- Add "revised" to `skill-base.sh` postflight success-status allow-list
- Make `skill-reviser/SKILL.md` call preflight (setting `[REVISING]`) and use correct postflight target (setting `[REVISED]`)
- Achieve parity with `/research`, `/plan`, and `/implement` status lifecycle patterns

**Non-Goals**:
- Adding `revise:postflight` logic to `update_plan_file()` (not needed; revised plans are new artifacts)
- Refactoring `skill-reviser` to use `skill_postflight_update` instead of direct script call (optional future work)
- Modifying `status-markers.md` (already correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing tasks at `[PLANNED]` from old revise postflight | L | M | Permissive model allows all commands from any non-terminal status; no remediation needed |
| TTS/WezTerm hooks receive new "revising"/"revised" values | L | L | Hooks use STATE_STATUS directly; they will announce new values correctly |
| Preflight now writes workflow-active marker for revise | L | L | Desired behavior -- suppresses Stop hook mid-workflow |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extend update-task-status.sh [COMPLETED]

**Goal**: Add "revise" as a valid target_status with correct preflight/postflight mappings.

**Tasks**:
- [x] Update usage string (line 60): add "revise" to target_status help text *(completed)*
- [x] Update validation whitelist (lines 69-72): add `&& "$target_status" != "revise"` to the guard *(completed)*
- [x] Update error message (line 70): add "revise" to the list of valid values *(completed)*
- [x] Add preflight:revise case entry (after line 92): `STATE_STATUS="revising"; TODO_STATUS="REVISING"` *(completed)*
- [x] Add postflight:revise case entry (after line 95): `STATE_STATUS="revised"; TODO_STATUS="REVISED"` *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - Three edits: usage string, validation block, case statement

**Exact edits**:

Edit 1 -- Usage string (line 60):
```
old: echo "  target_status: research | plan | implement" >&2
new: echo "  target_status: research | plan | implement | revise" >&2
```

Edit 2 -- Validation whitelist (lines 69-71):
```
old: if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" ]]; then
       echo "Error: target_status must be 'research', 'plan', or 'implement', got '$target_status'" >&2
       exit 1
new: if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" && "$target_status" != "revise" ]]; then
       echo "Error: target_status must be 'research', 'plan', 'implement', or 'revise', got '$target_status'" >&2
       exit 1
```

Edit 3 -- Case statement (insert after line 92 for preflight, after line 95 for postflight):
```
old:
    preflight:implement)  STATE_STATUS="implementing";  TODO_STATUS="IMPLEMENTING" ;;
    postflight:research)  STATE_STATUS="researched";    TODO_STATUS="RESEARCHED" ;;

new:
    preflight:implement)  STATE_STATUS="implementing";  TODO_STATUS="IMPLEMENTING" ;;
    preflight:revise)     STATE_STATUS="revising";      TODO_STATUS="REVISING" ;;
    postflight:research)  STATE_STATUS="researched";    TODO_STATUS="RESEARCHED" ;;
```

```
old:
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;

new:
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    postflight:revise)    STATE_STATUS="revised";       TODO_STATUS="REVISED" ;;
```

**Verification**:
- Run `bash .claude/scripts/update-task-status.sh` with no args; confirm usage includes "revise"
- Run `bash .claude/scripts/update-task-status.sh preflight 999 revise test_sess --dry-run` should fail with "task 999 not found" (passes validation)

---

### Phase 2: Update skill-base.sh [COMPLETED]

**Goal**: Add "revised" to the postflight success-status allow-list so `skill_postflight_update` forwards revise operations to `update-task-status.sh`.

**Tasks**:
- [x] Update comment at line 273: add "revised" to the list *(completed)*
- [x] Update case pattern at line 281: add `revised` to the allow-list *(completed)*

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Two edits: comment and case pattern

**Exact edits**:

Edit 1 -- Comment (line 273):
```
old: # Only updates state when status is a success value (researched/planned/implemented)
new: # Only updates state when status is a success value (researched/planned/revised/implemented)
```

Edit 2 -- Case pattern (line 281):
```
old:     researched|planned|implemented)
new:     researched|planned|revised|implemented)
```

**Verification**:
- Read the file and confirm both edits are applied
- The case pattern should now match "revised" and forward to `update-task-status.sh`

---

### Phase 3: Update skill-reviser/SKILL.md [COMPLETED]

**Goal**: Add preflight call at Stage 2 and fix postflight target_status at Stage 7 to use "revise" instead of "plan".

**Tasks**:
- [x] Replace Stage 2 content (lines 62-66) with preflight call using `skill_preflight_update` *(completed)*
- [x] Replace Stage 7 postflight command (line 296): change `plan` to `revise` in the script call *(completed)*
- [x] Update Stage 7 description text (lines 291-293): change "planned" references to "revised" *(completed)*
- [x] Update Stage 11 example output (line 438): change `[PLANNED]` to `[REVISED]` *(completed)*

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/skills/skill-reviser/SKILL.md` - Four edits: Stage 2 content, Stage 7 description, Stage 7 command, Stage 11 example

**Exact edits**:

Edit 1 -- Stage 2 (lines 62-66), replace entire block:
```
old:
### Stage 2: Preflight

No intermediate "revising" status is needed for revision. The task transitions directly to "planned" on success (via postflight). Skip preflight status update.

**Rationale**: Unlike `/plan` which sets "planning" as an intermediate status, `/revise` is lightweight enough that an intermediate status adds no value. The postflight script handles the final status update.

new:
### Stage 2: Preflight

Update task status to `[REVISING]` before beginning revision work:

```bash
skill_preflight_update "$task_number" "revise" "$session_id"
```

This follows the same pattern as `/research`, `/plan`, and `/implement`, giving users immediate visibility that revision is underway.
```

Edit 2 -- Stage 7 description (lines 291-293):
```
old:
**For Plan Revision** (status == "planned"):

Update task status to "planned" using the centralized script:

new:
**For Plan Revision** (status == "planned"):

Update task status to "revised" using the centralized script:
```

Edit 3 -- Stage 7 command (line 296):
```
old: bash .claude/scripts/update-task-status.sh postflight $task_number plan $session_id
new: bash .claude/scripts/update-task-status.sh postflight $task_number revise $session_id
```

Edit 4 -- Stage 11 example (line 438):
```
old: - Status updated to [PLANNED]
new: - Status updated to [REVISED]
```

**Verification**:
- Grep SKILL.md for "plan" in the context of postflight; confirm no references to the old `plan` target_status remain
- Confirm Stage 2 now contains `skill_preflight_update` call
- Confirm Stage 11 example references `[REVISED]`

---

### Phase 4: End-to-End Verification [COMPLETED]

**Goal**: Verify the full preflight/postflight cycle works correctly and no stale references remain.

**Tasks**:
- [x] Dry-run test: `bash .claude/scripts/update-task-status.sh preflight 629 revise sess_test --dry-run` *(completed)*
- [x] Dry-run test: `bash .claude/scripts/update-task-status.sh postflight 629 revise sess_test --dry-run` *(completed)*
- [x] Grep all three modified files for stale references to the old behavior *(completed)*
- [x] Verify `skill-base.sh` comment at line 138 already mentions "revise" (no change needed) *(completed)*
- [x] Verify `update_plan_file()` in `update-task-status.sh` has no revise case (correct -- no change needed) *(completed)*

**Timing**: 10 minutes

**Depends on**: 3

**Files to modify**: (none -- verification only)

**Verification**:
- Dry-run preflight should print: `[dry-run] state.json: task 629 status '...' -> 'revising'`
- Dry-run postflight should print: `[dry-run] state.json: task 629 status '...' -> 'revised'`
- Grep for `"plan"` in SKILL.md Stage 7 context should return no matches related to postflight target
- Grep for `researched|planned|implemented` in skill-base.sh should return zero matches (replaced with `researched|planned|revised|implemented`)

## Testing & Validation

- [x] Dry-run preflight revise succeeds (passes validation, shows correct status mapping) *(completed)*
- [x] Dry-run postflight revise succeeds (passes validation, shows correct status mapping) *(completed)*
- [x] `skill-base.sh` case pattern matches "revised" *(completed)*
- [x] `skill-reviser/SKILL.md` Stage 2 calls `skill_preflight_update` with "revise" *(completed)*
- [x] `skill-reviser/SKILL.md` Stage 7 calls `update-task-status.sh` with "revise" (not "plan") *(completed)*
- [x] No remaining references to old `plan` target in reviser postflight context *(completed)*
- [x] Existing commands (`research`, `plan`, `implement`) still work (case statement is additive) *(completed)*

## Artifacts & Outputs

- `specs/629_add_revise_status_support/plans/01_revise-status-implementation.md` (this plan)
- Modified files:
  - `.claude/scripts/update-task-status.sh`
  - `.claude/scripts/skill-base.sh`
  - `.claude/skills/skill-reviser/SKILL.md`

## Rollback/Contingency

All changes are additive to existing case statements and validation blocks. Rollback is straightforward:
- Revert the three files to their pre-edit state using `git checkout -- .claude/scripts/update-task-status.sh .claude/scripts/skill-base.sh .claude/skills/skill-reviser/SKILL.md`
- Existing `/research`, `/plan`, `/implement` commands are unaffected by these changes since the edits only add new branches to existing case/if statements
