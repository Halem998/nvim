# Implementation Plan: Task #657

- **Task**: 657 - Create shared orchestrator-postflight.sh script
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/657_create_shared_orchestrator_postflight/reports/01_postflight-extraction.md
- **Artifacts**: plans/01_postflight-script.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extract the duplicated postflight logic from skill-researcher (Stages 6-10), skill-planner (Stages 6-10), and skill-implementer (Stages 8-10) into a single `.claude/scripts/orchestrator-postflight.sh` script parameterized by operation type. The script consolidates nine operations (metadata read, artifact validation, status update, artifact number increment, completion data, memory candidate propagation, artifact linking, TTS notification, git commit, and cleanup) into one invocation, replacing approximately 120 lines of inline bash per skill with a single call. This also fixes the planner's missing memory_candidates propagation.

### Research Integration

Key findings from the research report (01_postflight-extraction.md):
- `skill-base.sh` already contains function equivalents for all postflight stages, but no SKILL.md files use them -- all postflight is inline.
- `postflight-workflow.sh` exists but covers only the state.json artifact-linking subset (3 of 10 operations).
- The planner SKILL.md is missing memory_candidates propagation -- the shared script fixes this uniformly.
- The implementer's continuation loop (Stages 5c-7 partial path) CANNOT be extracted -- it interleaves subagent spawning with metadata reading.
- Use Pattern B (`--arg atype "$artifact_type"`) for all jq operations to be Issue #1132 safe.
- The researcher has no explicit git commit stage (Stages 6-9 only, no Stage 9 git commit); the planner and implementer have explicit git commit stages.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation needed for this meta task.

## Goals & Non-Goals

**Goals**:
- Create `orchestrator-postflight.sh` that handles the full postflight pipeline for research, plan, and implement operations
- Refactor skill-researcher SKILL.md to replace inline Stages 6-9 with a single script call
- Refactor skill-planner SKILL.md to replace inline Stages 6-10 with a single script call
- Refactor skill-implementer SKILL.md to replace inline Stages 8-10 with a single script call (continuation loop stays inline)
- Fix the planner's missing memory_candidates propagation
- Use Issue #1132-safe jq patterns throughout (Pattern B with `--arg`)

**Non-Goals**:
- Extracting the implementer's continuation loop (Stages 5c-7)
- Modifying `skill-base.sh` to source `orchestrator-postflight.sh` (they remain independent)
- Deprecating or removing `postflight-workflow.sh` or the three thin wrapper scripts (separate cleanup task)
- Adding new postflight operations beyond what the three skills currently perform

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer continuation loop incompatibility | H | M | Careful scoping: shared script handles only post-loop stages (8-10); continuation loop and its Stage 7 stay inline |
| jq escaping triggers Issue #1132 | M | M | Use Pattern B (`--arg atype`) throughout; avoid hardcoded type strings in jq filters |
| Git commit from script interferes with skill-level flow | M | L | Make git commit optional via a `--no-commit` flag or skip when nothing to commit; non-blocking with `|| true` |
| Memory candidates jq with complex JSON triggers shell escaping | M | M | Use python3 approach (already proven in `skill_propagate_memory_candidates` in skill-base.sh) |
| Researcher has no git commit stage currently, adding one changes behavior | L | L | Match current behavior: researcher skips git commit, or add as new uniform behavior with opt-out |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create orchestrator-postflight.sh [COMPLETED]

**Goal**: Write the unified postflight script that encapsulates all shared postflight operations, parameterized by operation type.

**Tasks**:
- [x] Create `.claude/scripts/orchestrator-postflight.sh` with the following structure: *(completed)*
  - Argument parsing: `TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]`
  - Operation type mapping table (research/plan/implement -> success_status, artifact_type, artifact_kind, commit_message, state_status)
  - `mkdir -p specs/tmp` guard
  - Stage 6: Read `.return-meta.json` metadata (status, artifact_path, artifact_type, artifact_summary, memory_candidates; plus implement-specific fields: completion_summary, roadmap_items)
  - Stage 6a: Validate artifact via `validate-artifact.sh "$artifact_path" "$artifact_kind" --fix` (non-blocking)
  - Stage 7: Call `update-task-status.sh postflight "$task_number" "$operation" "$session_id"` (only on success status)
  - Stage 7a (research only): Increment `next_artifact_number` using python3 approach (from skill-base.sh)
  - Stage 7b (implement only): Write `completion_summary` and `roadmap_items` (non-meta) to state.json via jq
  - Stage 7c: Propagate memory_candidates using python3 approach (append semantics, all operations)
  - Stage 8: Link artifacts via two-step jq with `--arg atype "$artifact_type"` (Issue #1132 safe)
  - Stage 8a: Call `generate-todo.sh` (non-blocking)
  - Stage 8b: Fire TTS notification via `lifecycle-notify.sh` in background (non-blocking)
  - Stage 9: Git commit with operation-specific message (non-blocking, `|| true`)
  - Stage 10: Cleanup marker files (`.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json`, and `.continuation-loop-guard` for implement)
- [x] Make the script executable (`chmod +x`) *(completed)*
- [x] Add header comment with usage documentation, argument descriptions, operation mappings, and exit codes *(completed)*
- [x] Handle non-success status gracefully: skip status update and commit, but still run cleanup *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/orchestrator-postflight.sh` - Create new file

**Verification**:
- Script parses all 6 arguments correctly
- Operation type mapping produces correct values for research, plan, and implement
- All jq operations use `--arg` pattern (no hardcoded strings in filter expressions)
- Script handles missing metadata file gracefully (sets status to "failed", runs cleanup)
- `bash -n .claude/scripts/orchestrator-postflight.sh` passes (no syntax errors)

---

### Phase 2: Refactor SKILL.md files to call shared script [COMPLETED]

**Goal**: Replace inline postflight bash blocks in all three skills with a single call to `orchestrator-postflight.sh`.

**Tasks**:
- [x] Refactor `skill-researcher/SKILL.md`: Replace Stages 6 through 9 (Parse Subagent Return, Validate Artifact, Update Task Status + Increment Artifact Number, Propagate Memory Candidates, Link Artifacts, Lifecycle TTS, Cleanup) with a single call: *(completed)*
  ```
  bash .claude/scripts/orchestrator-postflight.sh \
      "$task_number" "$project_name" "$padded_num" "$session_id" "research"
  ```
  Keep Stage 10 (Return Brief Summary) inline.
- [x] Refactor `skill-planner/SKILL.md`: Replace Stages 6 through 10 (Parse Subagent Return, Validate Artifact, Update Task Status, Link Artifacts, Lifecycle TTS, Git Commit, Cleanup) with a single call: *(completed)*
  ```
  bash .claude/scripts/orchestrator-postflight.sh \
      "$task_number" "$project_name" "$padded_num" "$session_id" "plan"
  ```
  Keep Stage 11 (Return Brief Summary) inline.
- [x] Refactor `skill-implementer/SKILL.md`: Replace Stages 8 through 10 (Link Artifacts, Lifecycle TTS, Git Commit, Cleanup) with a single call: *(completed)*
  ```
  bash .claude/scripts/orchestrator-postflight.sh \
      "$task_number" "$project_name" "$padded_num" "$session_id" "implement" "$task_type"
  ```
  Keep the continuation loop (Stages 5c-7) and Stage 7 (status update, completion_summary, roadmap_items, memory_candidates for implement) INLINE -- these are tightly coupled with the loop control flow. Keep Stage 11 (Return Brief Summary) inline.
- [x] Update stage numbering in each SKILL.md to reflect the consolidation (fewer stages, renumber remaining) *(completed)*
- [x] Update Context References sections to add `orchestrator-postflight.sh` as a reference *(completed)*
- [x] Ensure the implementer's inline Stage 7 still writes completion_summary, roadmap_items, and memory_candidates before the shared script runs (shared script handles artifact linking, TTS, git commit, and cleanup only for implementer) *(completed: SKIP_COMPLETION_DATA=true env var prevents double-writing)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Replace Stages 6-9 with single script call
- `.claude/skills/skill-planner/SKILL.md` - Replace Stages 6-10 with single script call
- `.claude/skills/skill-implementer/SKILL.md` - Replace Stages 8-10 with single script call

**Verification**:
- Each SKILL.md has exactly one `orchestrator-postflight.sh` call in its postflight section
- Implementer's continuation loop logic is unchanged (Stages 5c-7 remain inline)
- Each SKILL.md retains the Return Brief Summary stage as the final stage
- No orphaned stage references (all stage numbers are sequential)
- The planner now gets memory_candidates propagation via the shared script (fixing the gap)

---

### Phase 3: Validation and edge case testing [COMPLETED]

**Goal**: Verify the refactoring preserves all existing behavior and handles edge cases correctly.

**Tasks**:
- [x] Run `bash -n .claude/scripts/orchestrator-postflight.sh` to verify no syntax errors *(completed)*
- [x] Verify the script handles each operation type correctly by tracing the code paths: *(completed)*
  - `research`: metadata read, validate report, status update, increment artifact number, memory candidates, link artifact, generate-todo, TTS, cleanup (no git commit -- matching current researcher behavior)
  - `plan`: metadata read, validate plan, status update, memory candidates, link artifact, generate-todo, TTS, git commit, cleanup
  - `implement`: (after inline Stage 7) link artifact, generate-todo, TTS, git commit, cleanup
- [x] Verify jq patterns: grep the script for any bare `!=` in jq filters (must be zero occurrences) *(completed: 0 occurrences)*
- [x] Verify the script does not source or call `skill-base.sh` (standalone only) *(completed)*
- [x] Verify each SKILL.md's stage numbering is consistent (no gaps, no duplicates) *(completed)*
- [x] Verify the implementer SKILL.md still has the full continuation loop with inline Stages 5c-7 *(completed: 23+ references to continuation tracking)*
- [x] Check that the planner's memory_candidates gap is now addressed (shared script handles it uniformly) *(completed)*
- [x] Verify specs/tmp/ directory is created before any jq write operations *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- No new files; read-only validation of files from Phases 1-2
- Minor fixes to any files if issues found

**Verification**:
- `bash -n` passes on the new script
- `grep -c '!=' .claude/scripts/orchestrator-postflight.sh` returns 0 (no unsafe jq patterns)
- All three SKILL.md files have consistent stage numbering
- Implementer continuation loop is intact

## Testing & Validation

- [ ] `bash -n .claude/scripts/orchestrator-postflight.sh` passes (syntax check)
- [ ] No `!=` in jq filter expressions within the script (Issue #1132 safety)
- [ ] Each of the three SKILL.md files contains exactly one `orchestrator-postflight.sh` invocation
- [ ] The implementer's continuation loop (Stages 5c-7) remains fully inline
- [ ] The planner now gets memory_candidates propagation (was previously missing)
- [ ] All stage numbers in each SKILL.md are sequential with no gaps
- [ ] The script's header comment documents all arguments, operations, and exit codes

## Artifacts & Outputs

- `.claude/scripts/orchestrator-postflight.sh` - New shared postflight script
- `.claude/skills/skill-researcher/SKILL.md` - Refactored postflight (reduced inline stages)
- `.claude/skills/skill-planner/SKILL.md` - Refactored postflight (reduced inline stages, memory candidates fixed)
- `.claude/skills/skill-implementer/SKILL.md` - Refactored postflight (Stages 8-10 extracted, loop intact)
- `specs/657_create_shared_orchestrator_postflight/plans/01_postflight-script.md` - This plan

## Rollback/Contingency

All three SKILL.md files are version-controlled. If the refactoring introduces issues:
1. Revert the SKILL.md changes via `git checkout` on the three files
2. The `orchestrator-postflight.sh` script can coexist harmlessly (unused) until issues are resolved
3. Individual skills can fall back to inline postflight by reverting their SKILL.md edits independently
