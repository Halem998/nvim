# Seed Research Report: Task #595

**Task**: 595 — Refactor /research, /plan, /implement commands
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to command refactoring

## Overview

Task 595 refactors the three core workflow commands (/research 500L, /plan 531L, /implement 612L) to use shared utilities from task 593 and refactored skills from task 594. This task depends on task 598 (progressive disclosure) because the context budget architecture defines what commands should and should not load.

## Current Duplication Profile (Teammate B, Direct Codebase Analysis)

| Duplicated Element | Lines Each | Total | Target |
|--------------------|-----------|-------|--------|
| `parse_task_args()` + `parse_ranges()` | ~30 | ~90 | `parse-command-args.sh` |
| STAGE 1.5 flag parsing block | ~25 | ~75 | `parse-command-args.sh` |
| Extension routing lookup | ~30 | ~90 | Shared utility |
| GATE IN template | ~80 | ~240 | @-referenced context |
| GATE OUT template | ~80 | ~240 | @-referenced context |
| Total recoverable | ~245 | ~735 | |

**Current sizes**: /research 500L, /plan 531L, /implement 612L
**Target sizes after refactoring**: ~150-200L each

## Progressive Disclosure Architecture (Task 598 Dependency)

**Why task 595 depends on task 598**: The context budget architecture defines what commands should load. Designing command refactoring before knowing the tier system would require redesigning the commands.

**Key principle from task 598 (Teammate A)**: "Commands should NOT load agent-level context. The agent loads its own context. The command's job is routing only."

**Practical implication for task 595**: After refactoring, each command should load:
- Tier 1 context (always, ~500 lines): Anti-stop patterns, return metadata, checkpoint execution
- Tier 2 context (command-specific): This command's routing table and argument docs
- NOT Tier 3 (agent-specific): The agent loads this itself at spawn time
- NOT Tier 4 (on-demand): Only loaded via explicit @-reference when needed

**Current waste (Teammate A)**: "Full 500L command file loaded even for validation-only paths — ~2K tokens per command invocation."

## Token Economics Analysis (Teammate C)

**Important caveat**: "Skills are invoked, not loaded into the context window as text... The skill's 558 lines do NOT compete with the command's 500 lines for the same context budget; they run in a separate invocation."

**What this means for task 595**: The token savings from command refactoring are in the ORCHESTRATOR's context (where the command runs), not in the subagent's context. The orchestrator uses Opus with 1M context, so the benefit is modest but real:
- Commands run in the orchestrator's context
- Shorter commands = less context consumed in the orchestrator
- The primary value is maintenance burden reduction, not token savings

**Verify before assuming savings** (Teammate C): Measure actual token cost of current commands vs. refactored versions before claiming victory.

## Command-Level Responsibilities After Refactoring

After refactoring, each command should contain ONLY:
1. Command-specific documentation (usage, flags, examples)
2. Mode-specific behavior description
3. Output formatting for this specific command type
4. @-references to shared infrastructure

**Shared infrastructure handles**:
- Argument parsing (`parse_task_args()`, flag parsing)
- Extension routing lookup (task_type → skill mapping)
- GATE IN (session generation, status validation, preflight update)
- GATE OUT (postflight verification, defensive corrections, status assertion)
- Multi-task dispatch (parallel skill invocation, consolidated output)
- COMMIT (git commit with session ID)

## Multi-Task Dispatch Infrastructure

The `/research N1, N2-N4, N7` syntax allows parallel multi-task operations. The shared dispatch infrastructure must handle:
1. Parsing the task number list (already done by `parse_task_args()`)
2. Validating all tasks exist and are in valid states
3. Routing each task to the appropriate skill (may be different for different task types)
4. Spawning skills in parallel via Agent tool
5. Collecting and consolidating results

**Implementation note**: The parallel skill invocation uses the Skill tool (not Agent) for skills. The Agent tool is for agent delegation. Each parallel operation spawns a separate Skill invocation.

## Extension Compatibility Requirements

After refactoring /research, /plan, /implement, verify:
1. Extension routing still works (neovim, nix, lean4, etc. task types route correctly)
2. Extension skills receive correct delegation context (session_id, delegation_depth, etc.)
3. Memory retrieval injection still works (memory-retrieve.sh called at preflight)
4. Roadmap injection still works

**Note (Teammate C)**: "Which of the loaded extension skills call `update-task-status.sh`, `link-artifact-todo.sh`, or other scripts directly? If all of them do, changes to those scripts' interfaces break all extensions simultaneously." Verify before changing script interfaces.

## Progressive Disclosure Implementation for Commands

**Level 1 (frontmatter or context, always)**: Core patterns every command invocation needs
**Level 2 (command file)**: This command's specific routing, argument format, mode docs
**Level 3 (NOT loaded by commands)**: Agent-specific workflow patterns — agent loads these itself

**Implementation**:
- Each command file becomes ~150-200L of command-specific content
- Shared elements removed and replaced with `@-references` to shared infrastructure
- The command file IS the Level 2 context; agents load Level 3 themselves

## Dependency on Task 594 (Skill Refactoring)

Task 595 depends on task 594 because the commands invoke skills. If the skill interface changes (e.g., skill now accepts different delegation context format), the commands must be updated simultaneously.

**Risk (Teammate C)**: "Tasks 78 (planned) and 87 (researched) are in active states; if skill interface changes, their next `/implement` or `/plan` will use the new code on old context." Verify backward compatibility at each step.

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 5 (Deduplication targets: command-level), Section 4 (Progressive disclosure)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Finding 2 (Progressive disclosure), Recommended Approach section 2 (Shared command infrastructure), section 5 (Progressive disclosure in commands)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Finding 1 (Command→agent direct delegation), Finding 2 (Unified workflow engine), Finding 3 (@include pattern)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 2 (Token economics), Finding 6 (Missing prerequisites), Finding 5 (Extension integration)
