# Research Report: Task #657

**Task**: 657 - Create shared orchestrator-postflight.sh script
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:30:00Z
**Effort**: 2-3 hours (implementation)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/scripts/skill-base.sh`
- `.claude/scripts/postflight-workflow.sh`
- `.claude/scripts/postflight-research.sh`
- `.claude/scripts/postflight-plan.sh`
- `.claude/scripts/postflight-implement.sh`
- `.claude/scripts/update-task-status.sh`
- `.claude/scripts/validate-artifact.sh`
- `.claude/context/patterns/jq-escaping-workarounds.md`
**Artifacts**: - specs/657_create_shared_orchestrator_postflight/reports/01_postflight-extraction.md
**Standards**: report-format.md

## Executive Summary

- The three skills (researcher, planner, implementer) each contain near-identical postflight logic in Stages 6-10 of their SKILL.md files, but none of them source or call `skill-base.sh` (which already contains function equivalents for all these stages).
- A `postflight-workflow.sh` already exists in `.claude/scripts/` that partially unifies the three thin `postflight-research/plan/implement.sh` scripts, but it covers only state.json artifact linking - not the full postflight pipeline (metadata read, validation, memory propagation, generate-todo, TTS, git commit, cleanup).
- The recommended approach is to create `orchestrator-postflight.sh` as a standalone script that encapsulates Stages 6-10 for all three operation types, parameterized by `OPERATION_TYPE` (`research`, `plan`, `implement`). The three skills would then call this single script instead of repeating inline bash blocks.

## Context & Scope

### What Was Researched

The full postflight pipeline across three skills was analyzed to:
1. Identify every operation performed in Stages 6-10 across skill-researcher, skill-planner, and skill-implementer.
2. Determine which operations are identical, which differ by operation type only (parameterizable), and which are genuinely operation-specific.
3. Understand existing shared infrastructure (`skill-base.sh`, `postflight-workflow.sh`, `update-task-status.sh`) to avoid redundancy.
4. Design a clean interface for the shared script.

### Key Discovery: skill-base.sh Already Provides These Functions

`skill-base.sh` (22,779 bytes) already contains function equivalents for every postflight operation:

| Function | Covers |
|---|---|
| `skill_read_metadata()` | Stage 6: read .return-meta.json |
| `skill_validate_artifact()` | Stage 6a: validate artifact format |
| `skill_postflight_update()` | Stage 7: update-task-status.sh postflight |
| `skill_increment_artifact_number()` | Stage 7 (research only): increment next_artifact_number |
| `skill_propagate_memory_candidates()` | Stage 7a: append memory candidates |
| `skill_link_artifacts()` | Stage 8: two-step jq artifact linking + generate-todo.sh |
| `skill_cleanup()` | Stage 9/10: remove .postflight-pending, .postflight-loop-guard, .return-meta.json |

None of the three skill SKILL.md files source `skill-base.sh` or call any of these functions. All postflight logic is currently inlined as bash blocks in each SKILL.md.

### What is NOT in skill-base.sh

The following operations from the SKILL.md postflight are not currently in `skill-base.sh`:
1. **TTS notification** (Stage 8a): `lifecycle-notify.sh "$STATE_STATUS" &` — present in all three skills but no equivalent function in skill-base.sh.
2. **Git commit** (Stage 9): The `git add -A && git commit` is also inline in each skill with different commit messages. No function in skill-base.sh.
3. **Completion data (implement-only)**: `completion_summary`, `roadmap_items`, and `claudemd_suggestions` written to state.json — these are implement-specific.
4. **Continuation loop (implement-only)**: The implementer has a complex continuation loop for multi-phase resumption; this is definitionally not shareable across operations.
5. **Phase commit (implement-only)**: Per-phase git commit inside the continuation loop.

## Findings

### Shared vs. Operation-Specific Operations

#### Stage 6: Parse Subagent Return (Read Metadata File)
**Shared** — identical across all three skills. Both researcher and planner read the same fields. The implementer reads additional fields:
- `phases_completed`, `phases_total` (implement only)
- `completion_summary`, `roadmap_items` (implement only)
- `handoff_path` (implement only, for continuation loop)
- `memory_candidates` (all three, identical)

**Resolution**: The shared script reads the base fields; implementer-specific fields can be read by the caller or by a dedicated code path.

#### Stage 6a: Validate Artifact
**Shared** — identical structure across all three. Differences:
- Researcher: validates when `status == "researched"`, kind `"report"`
- Planner: validates when `status == "planned"`, kind `"plan"`
- Implementer: validates when `status == "implemented"` or `"partial"`, kind `"summary"`

**Resolution**: Parameterize by `OPERATION_TYPE` to derive the success status and artifact kind.

#### Stage 7: Update Task Status
**Shared** — all three call `update-task-status.sh postflight $task_number $operation $session_id`. The implementer also has an additional 3-step process for completion_summary, roadmap_items, and memory_candidates.

**Resolution**: The `update-task-status.sh` call is shared. The implementer-specific completion data steps must be in an `implement` code path.

#### Stage 7a: Propagate Memory Candidates
**Shared** — identical logic in researcher (inline jq) and implementer. The planner SKILL.md does **not** have a memory candidates stage currently.

**Discovery**: The planner postflight is missing the `memory_candidates` propagation step. This is a gap that the shared script could fix uniformly.

#### Stage 7 (research only): Increment next_artifact_number
**Research only** — only researcher increments `next_artifact_number`. This is correctly handled by `skill_increment_artifact_number()` in `skill-base.sh`.

#### Stage 8: Link Artifacts (Two-Step jq Pattern)
**Shared** — identical structure. Both steps use the Issue #1132-safe `| not` pattern. Only the artifact type differs:
- researcher: `type == "research" | not` / adds `"research"` type
- planner: `type == "plan" | not` / adds `"plan"` type
- implementer: `type == "summary" | not` / adds `"summary"` type

This is already parameterized in `postflight-workflow.sh` and in `skill_link_artifacts()` in `skill-base.sh`.

#### Stage 8: generate-todo.sh
**Shared** — all three call `bash .claude/scripts/generate-todo.sh || echo "WARNING: ..."` identically.

#### Stage 8a: TTS Notification
**Shared** — identical in all three skills:
```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
    bash "$lifecycle_script" "$STATE_STATUS" &
fi
```
Currently no equivalent in `skill-base.sh`.

#### Stage 9: Git Commit
**Differs by operation** — commit message varies:
- researcher: `"task ${task_number}: complete research"`
- planner: `"task ${task_number}: create implementation plan"`
- implementer: `"task ${task_number}: complete implementation"`

The structure (`git add -A && git commit -m "..."`) is identical; only the message suffix differs.

#### Stage 10: Cleanup
**Shared base** — all three remove `.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json`. The implementer also removes `.continuation-loop-guard`.

### Comparison of SKILL.md Postflight vs skill-base.sh Functions

| Operation | skill-base.sh function | Researcher | Planner | Implementer |
|---|---|---|---|---|
| Read metadata | `skill_read_metadata()` | Inline | Inline | Inline |
| Validate artifact | `skill_validate_artifact()` | Inline | Inline | Inline |
| Status update | `skill_postflight_update()` | Calls `update-task-status.sh` directly | Calls `update-task-status.sh` directly | Calls `update-task-status.sh` directly |
| Increment artifact number | `skill_increment_artifact_number()` | Inline jq | N/A | N/A |
| Memory candidates | `skill_propagate_memory_candidates()` | Inline jq | **Missing** | Inline jq |
| Link artifacts | `skill_link_artifacts()` | Inline jq | Inline jq | Inline jq |
| generate-todo.sh | (inside `skill_link_artifacts`) | Separate call after jq | Separate call after jq | Separate call after jq |
| TTS notification | **Not in skill-base.sh** | Inline | Inline | Inline |
| Git commit | **Not in skill-base.sh** | Inline | Inline | Inline |
| Cleanup | `skill_cleanup()` | Inline | Inline | Inline (+continuation) |

**Key finding**: `skill_link_artifacts()` already calls `generate-todo.sh` internally, so the separate call in each SKILL.md is redundant if skills use `skill_link_artifacts()`.

### Existing postflight-workflow.sh Analysis

The existing `postflight-workflow.sh` (5,114 bytes) handles only:
- State.json status update and timestamp (Step 1)
- Artifact deduplication (Step 2, Issue #1132 safe using `--arg atype "$artifact_type"`)
- Artifact addition (Step 3)

It does NOT handle: metadata reading, validation, memory candidates, generate-todo.sh, TTS, git commit, or cleanup. It is a lower-level helper focused exclusively on state.json mutations.

### jq-escaping-workarounds.md Pattern Analysis

The SKILL.md files use two patterns for Issue #1132:

**Pattern A (inline, hardcoded type string)**:
```bash
jq '...| select(.type == "research" | not)]' ...
```

**Pattern B (used in skill-base.sh and postflight-workflow.sh, safer)**:
```bash
jq --arg atype "$artifact_type" \
  '...| select(.type == $atype | not)]' ...
```

Pattern B (with `--arg`) is strictly safer because the type string is injected via `--arg`, avoiding any shell escaping of the filter itself. The new `orchestrator-postflight.sh` should use Pattern B throughout.

Note: The old `postflight-research/plan/implement.sh` scripts use `select(.type != "X")` which is the **unsafe** pattern. Only the newer `postflight-workflow.sh` and `skill-base.sh` use the safe `| not` pattern with `--arg`.

### Operation-Specific Differences Summary

| Aspect | research | plan | implement |
|---|---|---|---|
| Success status | `researched` | `planned` | `implemented` |
| state.json status | `researched` | `planned` | `completed` |
| Artifact type | `research` | `plan` | `summary` |
| Artifact kind (for validation) | `report` | `plan` | `summary` |
| Timestamp field | `researched` | `planned` | `completed` |
| next_artifact_number | Increment | No change | No change |
| completion_summary | No | No | Yes |
| roadmap_items | No | No | Yes (non-meta) |
| memory_candidates | Yes | (missing, add it) | Yes |
| Continuation loop | No | No | Yes (separate concern) |
| Phase commit | No | No | Yes (separate concern) |
| TTS STATE_STATUS var | `researched` | `planned` | `completed` |
| Git commit message | "complete research" | "create implementation plan" | "complete implementation" |
| Extra cleanup files | None | None | `.continuation-loop-guard` |

## Decisions

1. **Proposed script name**: `.claude/scripts/orchestrator-postflight.sh` — as specified in the task description.
2. **Interface**: Positional arguments `TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]`
   - `OPERATION_TYPE`: `research | plan | implement`
   - `TASK_TYPE`: optional, needed to determine if meta task (affects roadmap_items behavior)
3. **Script reads metadata file itself** — rather than accepting metadata values as arguments, the script reads `specs/${padded_num}_${project_name}/.return-meta.json` internally (like `skill-base.sh`'s `skill_read_metadata()`).
4. **Implement-specific logic in a branch** — completion_summary, roadmap_items, and claudemd_suggestions are behind an `if [ "$operation_type" = "implement" ]` guard.
5. **Continuation loop stays in SKILL.md** — the continuation loop in skill-implementer is complex and interleaved with subagent spawning; it cannot be moved to postflight-only.
6. **TTS notification added as new function** — not currently in skill-base.sh, should be added as a shared step in the new script.
7. **Git commit added to shared script** — with commit message derived from operation_type.
8. **Memory candidates gap fixed** — the planner currently lacks the memory candidates step; the shared script applies it uniformly to all three operations.
9. **Use Pattern B (--arg) for jq** — use `--arg atype "$artifact_type"` rather than hardcoded strings to be maximally safe against Issue #1132.
10. **Relationship to skill-base.sh** — the new script is a **standalone** script (not sourced), designed to be called with `bash .claude/scripts/orchestrator-postflight.sh ...`. It wraps the same logic as `skill-base.sh`'s functions but in a single-call form suitable for use in SKILL.md without requiring sourcing.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Implementer continuation loop cannot be extracted | High (known) | Leave continuation loop in SKILL.md; shared script handles post-loop stages only |
| Memory candidates jq pattern triggers Issue #1132 | Medium | Use `python3` approach (already in `skill_propagate_memory_candidates()`) or `--argjson` pattern |
| Implement completion_summary / roadmap_items fields missing | Medium | Add explicit `if [ "$operation_type" = "implement" ]` guards; test with both meta and non-meta task types |
| lifecycle-notify.sh may not exist | Low | Already guarded with `[ -f "$lifecycle_script" ]` check in all three skills |
| skills source skill-base.sh (in future) creating double-execution | Low | The new script should not call skill-base.sh functions — standalone implementation only |
| specs/tmp/ may not exist | Low | Add `mkdir -p specs/tmp` guard at script start |

## Proposed Interface

```bash
#!/usr/bin/env bash
# orchestrator-postflight.sh — Unified postflight for research, plan, and implement operations
#
# Usage:
#   bash .claude/scripts/orchestrator-postflight.sh \
#       TASK_NUMBER PROJECT_NAME PADDED_NUM SESSION_ID OPERATION_TYPE [TASK_TYPE]
#
# Arguments:
#   TASK_NUMBER      Task number (unpadded integer, e.g. 657)
#   PROJECT_NAME     Task slug (e.g. create_shared_orchestrator_postflight)
#   PADDED_NUM       Zero-padded task number (e.g. 657)
#   SESSION_ID       Session identifier string
#   OPERATION_TYPE   research | plan | implement
#   TASK_TYPE        Optional: task type for completion logic (default: "general")
#                    Used to determine if roadmap_items should be written (meta tasks skip it)
#
# Operations performed:
#   1. Read .return-meta.json metadata (SUBAGENT_STATUS, ARTIFACT_PATH, etc.)
#   2. Validate artifact format via validate-artifact.sh (non-blocking)
#   3. Update task status via update-task-status.sh postflight
#   4. (research only) Increment next_artifact_number in state.json
#   5. (implement only) Write completion_summary and roadmap_items to state.json
#   6. Propagate memory_candidates to state.json (append semantics)
#   7. Link artifact to state.json via two-step jq (Issue #1132 safe)
#   8. Regenerate TODO.md via generate-todo.sh
#   8a. Fire TTS lifecycle notification (non-blocking, background)
#   9. Git commit (operation-specific message)
#   10. Cleanup marker and metadata files
#
# Exit codes:
#   0 - Success (or non-success status handled gracefully)
#   1 - Argument validation error
#   2 - state.json not found
#   3 - Metadata file missing or invalid (status set to "failed")
```

### SKILL.md Call Pattern After Refactoring

```bash
# In skill-researcher.SKILL.md, Stage 6-10 replaced with:
bash .claude/scripts/orchestrator-postflight.sh \
    "$task_number" "$project_name" "$padded_num" "$session_id" "research"

# In skill-planner.SKILL.md, Stage 6-10 replaced with:
bash .claude/scripts/orchestrator-postflight.sh \
    "$task_number" "$project_name" "$padded_num" "$session_id" "plan"

# In skill-implementer.SKILL.md, after continuation loop exits, Stage 8-10 replaced with:
bash .claude/scripts/orchestrator-postflight.sh \
    "$task_number" "$project_name" "$padded_num" "$session_id" "implement" "$task_type"
# NOTE: Stage 7 (implemented branch) stays inline for continuation loop compatibility
```

### What Remains Inline in skill-implementer

The implementer has unique complexity that cannot be fully extracted:
- **Continuation loop** (Stages 5c, 6-7 for partial): The loop interleaves reading metadata, spawning subagents, and phase commits. These must stay inline.
- **Phase commit** (Stage 6b): `git commit` after each phase inside the loop.
- **completion_summary/roadmap_items** (Stage 7 implemented path): Can be moved into the shared script under `if [ "$operation_type" = "implement" ]`.
- **Partial status update** (Stage 7 partial path): The `resume_phase` update stays inline because `update-task-status.sh` doesn't handle partial.

The implementer will still benefit from using the shared script for Stages 8-10 (artifact linking, TTS, final git commit, cleanup), even if Stage 7's complexity remains inline.

## Context Extension Recommendations

- **Topic**: Shared postflight script documentation
- **Gap**: The `jq-escaping-workarounds.md` mentions `postflight-research/plan/implement.sh` as reference scripts but does not mention the newer `postflight-workflow.sh` or the forthcoming `orchestrator-postflight.sh`. The references should be updated after implementation.
- **Recommendation**: Update `.claude/context/patterns/jq-escaping-workarounds.md` Postflight Scripts table to reference `orchestrator-postflight.sh` and deprecate the three thin wrappers.

## Appendix

### Search Queries Used
- Filesystem glob: `.claude/skills/skill-{researcher,planner,implementer}/SKILL.md`
- Filesystem glob: `.claude/scripts/*.sh`
- Direct reads of all relevant files

### Key File Sizes
- `skill-base.sh`: 22,779 bytes (contains all function equivalents)
- `postflight-workflow.sh`: 5,114 bytes (state.json-only subset)
- `postflight-research.sh`: 2,425 bytes
- `postflight-plan.sh`: 2,377 bytes
- `postflight-implement.sh`: 2,449 bytes

### Note on Discrepancy Between Two Sets of SKILL.md Files

This codebase has two sets of SKILL.md files with differing postflight detail:
- **`.claude/skills/`** (nvim-local, e.g., `/home/benjamin/.config/nvim/.claude/skills/`): The **authoritative current state** with full postflight logic (Stages 6-11 with detailed inline bash blocks, TTS notification, memory candidates, generate-todo.sh, etc.)
- **`~/.config/.claude/skills/`** (parent config, simpler): An older/simpler version without memory candidates, lifecycle TTS, or generate-todo.sh calls.

The task should target the nvim-local `.claude/skills/` files.
