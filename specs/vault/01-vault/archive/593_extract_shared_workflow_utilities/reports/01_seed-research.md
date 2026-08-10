# Seed Research Report: Task #593

**Task**: 593 — Extract shared workflow utilities
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to shared utility extraction

## Overview

Task 593 extracts the highest-confidence, lowest-risk deduplication targets from the current system into reusable shared utilities. The research from task 591 provides clear guidance on which targets are safe to extract immediately vs. which require careful design. This task must also establish baseline token measurements before extraction to validate the refactoring.

## Safe Extraction Targets (High Confidence, Low Risk)

### 1. parse_task_args() — ~90 Lines Recoverable (Teammate B)

**Current state**: The `parse_task_args()` function (and its companion `parse_ranges()`) is copy-pasted verbatim into three command files: `/research` (500L), `/plan` (531L), `/implement` (612L). Approximately 30 lines each = ~90 lines total.

**Extraction target**: `.claude/scripts/parse-command-args.sh`

```bash
# Each command becomes:
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/parse-command-args.sh"
```

**Risk**: Minimal. The function is syntactically identical across all three commands; no behavioral divergence.

**Evidence** (Teammate B, direct codebase diff): "The `parse_task_args()` and STAGE 1.5 flag-parsing blocks... appear verbatim in all three commands."

### 2. Flag Parsing (STAGE 1.5) — ~75 Lines Recoverable (Teammate B)

**Current state**: The STAGE 1.5 flag-parsing block (25 lines) is copy-pasted 3 times across the same three commands.

**Extraction target**: Include in `parse-command-args.sh` alongside `parse_task_args()`.

**Risk**: Minimal — same flags across all three commands (--team, --clean, --force, --fast, --hard, --haiku, --sonnet, --opus).

### 3. Unified postflight-workflow.sh — ~130 Lines Recoverable (Teammate B)

**Current state**: Three near-identical postflight scripts (`postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`) differ only in 7 variable strings:
- `status: "researched"` vs `"planned"` vs `"implemented"`
- `artifact.type: "research"` vs `"plan"` vs `"summary"`
- `researched: $ts` vs `planned: $ts` vs `implemented: $ts`

**Evidence** (Teammate B): "These 69-line scripts are identical except for [these 7 strings]"

**Extraction target**: Single `postflight-workflow.sh TASK_NUMBER ARTIFACT_PATH [SUMMARY] OPERATION_TYPE` where `OPERATION_TYPE` is `research|plan|implement`.

```bash
# Current (3 scripts):
bash postflight-research.sh "$task_number" "$artifact_path" "$summary"
bash postflight-plan.sh "$task_number" "$artifact_path" "$summary"
bash postflight-implement.sh "$task_number" "$artifact_path" "$summary"

# Proposed (1 script):
bash postflight-workflow.sh "$task_number" "$artifact_path" "$summary" "research"
bash postflight-workflow.sh "$task_number" "$artifact_path" "$summary" "plan"
bash postflight-workflow.sh "$task_number" "$artifact_path" "$summary" "implement"
```

**Risk**: Minimal. Pure parameterization of identical code. Maintenance burden drops ~65% for this subsystem.

**Note**: Token savings from this extraction are zero (scripts run in bash, not LLM context). The value is maintenance burden reduction.

### 4. Shared GATE IN/OUT Templates — ~240 Lines Recoverable (Teammates A, B)

**Current state**: The GATE IN and GATE OUT protocol blocks appear in all 3 commands with ~80% identical content. The content covers: session_id generation, status validation, preflight status update, postflight verification, defensive corrections, status assertion.

**Extraction target**: @-referenced context files that commands can reference instead of copy-pasting:
- `.claude/context/patterns/shared-gate-in.md`
- `.claude/context/patterns/shared-gate-out.md`

**Approach** (Teammate B): "Move shared pseudocode blocks to `@.claude/context/patterns/shared-command-logic.md`... The commands show a pointer, not the full text." This does NOT reduce runtime token cost but massively reduces maintenance burden.

**Risk**: Low. The @-reference pattern is already used throughout the system.

## Baseline Token Measurement Requirement (Teammate C)

**Critical prerequisite**: Before extracting any utilities, establish baseline measurements of actual per-command token cost.

**Why this matters** (Teammate C's caution): "The plan contains no baseline measurement of token usage. Without before/after data, there is no way to validate that the refactoring achieved its goal."

**Measurement methodology**:
1. Run `/research N`, `/plan N`, `/implement N` with a simple test task
2. Record input tokens, output tokens, and total cost per invocation
3. Note which phases of each command contribute the most tokens
4. Document baseline in `specs/593_extract_shared_workflow_utilities/reports/02_baseline-measurements.md`
5. After extraction, run the same test and compare

**What to measure**:
- Command file token cost (read at invocation in orchestrator context)
- Skill file token cost (read in subagent context)
- Postflight script token cost (zero — runs in bash)
- Total per-operation token cost

## GATE IN/OUT Template Architecture

The GATE IN template should standardize:
- Session ID generation format: `sess_{timestamp}_{random}`
- Status validation: task must exist and be in non-terminal state
- Preflight status update: update state.json and TODO.md before starting work
- Postflight marker creation: `.postflight-pending` file for SubagentStop hook

The GATE OUT template should standardize:
- Postflight status assertion: verify status was updated by agent
- Defensive correction: if agent returned early, force-update status
- Artifact linking: call `link-artifact-todo.sh` for any new artifacts
- Git commit: standard format `task {N}: {action}`

## Multi-Task Dispatch Utilities

For parallel multi-task operations (`/research 7, 22-24, 59`):
- Input validation: all tasks exist, all are in valid states
- Parallel skill invocation: one skill per task via Agent tool
- Consolidated output: summarize results from all parallel operations

**Risk note (Teammate C)**: "Rapid concurrent writes could cause read-modify-write races in edge cases." The extracted GATE IN utility must use atomic writes (the current `update-task-status.sh` already handles this via scoped jq operations).

## What NOT to Extract in Task 593

**Reserved for task 594 (higher risk)**:
- Shared skill base pattern
- Agent prompt construction templates
- Context injection mechanisms

**Reserved for task 595 (depends on 594 and 598)**:
- Command-level routing logic
- Progressive disclosure command patterns

**Extraction that requires design decision (task 592)**:
- dispatch_agent() function (encapsulates fork vs. subagent decision)
- Extension routing lookup (may change with new architecture)

## Prioritization of Extraction Targets

| Target | Lines | Maintenance Value | Token Value | Risk | Priority |
|--------|-------|------------------|-------------|------|----------|
| Unified postflight-workflow.sh | ~130 | High | Zero | Minimal | 1 |
| parse_task_args() + flag parsing | ~165 | High | Low | Minimal | 2 |
| Shared GATE IN/OUT templates | ~240 | High | Medium | Low | 3 |
| Baseline token measurements | N/A | Critical | Critical | N/A | 0 (prerequisite) |

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 5 (Practical deduplication targets), Section 3 (Token efficiency)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Finding 2 (Progressive disclosure context loading), Finding 3 (Token efficiency techniques)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Finding 2 (Unified workflow engine), Finding 3 (@include pattern workarounds), Finding 8 (Structured handoff payload)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 2 (Token economics unvalidated), Finding 4 (Concurrent write risk), Finding 6 (Missing prerequisites)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 3 (dispatch_agent abstraction)
