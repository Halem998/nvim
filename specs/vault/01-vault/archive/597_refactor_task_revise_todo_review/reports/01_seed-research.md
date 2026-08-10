# Seed Research Report: Task #597

**Task**: 597 — Refactor /task, /revise, /todo, /review commands
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to secondary command refactoring

## Overview

Task 597 refactors four secondary commands (/task 710L, /revise 161L, /todo 1047L, /review 1040L) for consistency with the new architecture from task 593. The critical new requirement from task 591 research is adding memory harvest automation to /todo's archival pipeline. This task depends only on task 593 (shared utilities) and can proceed in parallel with task 594 (skills refactoring).

## Memory Vault Gap — Critical New Requirement (Teammate D)

**Finding (Teammate D)**: "571 archived tasks have `memory_candidates` in state.json but only 3 memories exist in the vault. The `/todo` archival process does not harvest memory candidates automatically — this is silent information loss."

**Root cause**: The memory harvest step (creating memory vault entries from `memory_candidates` in state.json) requires calling `/learn` or the memory skill. The current /todo command does not do this automatically.

**Impact**: Every completed task that generates implementation findings, decisions, or architectural discoveries loses those learnings unless the user manually runs `/learn --task N`. With 571 archived tasks, this represents a significant accumulated knowledge gap.

**Fix for task 597**: Add auto-harvest to /todo's archival pipeline:
1. Before archiving each task, read its `memory_candidates` array from state.json
2. For each candidate with confidence >= 0.7, call `memory-create.sh` (or equivalent)
3. Log harvested memories in the archival summary
4. Report harvest count in /todo output

**Implementation note**: The memory harvest can be batch-processed across all tasks being archived in a single /todo run, not one at a time. The memory deduplication in `memory-index.json` prevents duplicate entries.

## /todo Decomposition — High-Risk Task

**Warning (Teammate C)**: "/todo (1047 lines) handles vault archival, task renumbering, ROADMAP.md annotation, and orphan detection. A single bug in a refactored /todo could corrupt `state.json` or `TODO.md` — the system's primary state stores."

**Recommended approach**: 
1. Create snapshot/regression tests for /todo before decomposing
2. Extract one module at a time (not all at once)
3. Validate each extraction with full /todo integration test

**Decomposition targets** (task 591 plan):
- Orphan detection module (~100-150L extracted)
- Roadmap sync module (~100-150L extracted)
- Vault operation module (~150-200L extracted)
- Metrics collection module (~100L extracted)
- Memory harvest module (NEW — ~100L added)

**Goal**: /todo reduced from 1047L to ~400-500L of coordination logic, with extracted modules in `.claude/scripts/todo-*.sh`.

## /review Decomposition (Similar Concern)

**Warning (Teammate C)**: Applies equally to /review (1040L) — complex decomposition.

**Decomposition targets** (task 591 plan):
- Issue grouping algorithm (~180L)
- Roadmap integration (~120L)
- 3-tier selection flow (~150L)

**Goal**: /review reduced from 1040L to ~400-500L with extracted modules.

## /revise Integration with Orchestrator Handoff

**Current state**: /revise is already compact (161L). It invokes the reviser-agent which produces a new plan version.

**Update required**: /revise needs to accept a blocker handoff path as input, so that /orchestrate can invoke it with the blocker research findings:

```bash
/revise N [--from-blocker /path/to/blocker-handoff.json]
```

When `--from-blocker` is provided:
- Skip the "why are you revising" prompt
- Inject the blocker findings into the reviser agent's context
- Write the revised plan to the standard plan path
- Return a revise-handoff file for the orchestrator to consume

## /task Shared Utilities Integration

/task (710L) handles 5 modes: create, recover, expand, sync, abandon. Each mode has substantial shared logic (reading state.json, validating task numbers, updating state.json + TODO.md).

**Extraction targets** from /task:
1. Task number validation function (check task exists, is in valid state)
2. State + TODO atomic update utility (already partially in `update-task-status.sh`)
3. Task display formatting (for `--sync` output)
4. Mode dispatch pattern (shared GATE IN/OUT structure)

**Goal**: /task from 710L to ~400L with clearer mode separation.

## Consistency Pattern for Secondary Commands

After refactoring with shared utilities from task 593, secondary commands should follow the same structural pattern as primary commands (after task 595 refactoring):

- Command file: ~150-400L of command-specific logic only
- Shared infrastructure: argument parsing, status validation, git commit
- Mode-specific behavior: inline or in separate mode functions
- Error handling: consistent with error-handling.md patterns

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 8 (Memory vault gap), Synthesis (Gaps identified: memory harvest automation)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 6 (Missing prerequisites: /todo refactor risks), Finding 5 (Extension integration)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 4 (Memory vault gap, /todo auto-harvest recommendation), Finding 1 (/orchestrate design, /revise integration)
