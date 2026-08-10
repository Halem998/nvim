# Seed Research Report: Task #596

**Task**: 596 — Create /orchestrate command, skill, and orchestrator agent
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to /orchestrate design

## Overview

Task 596 creates the /orchestrate command — the highest-value novel capability in the entire refactoring suite. The user direction is clear: /orchestrate should be a fire-and-forget autonomous loop, not a confirmation-gated command. This decision was made against Teammate D's dissent (which recommended confirmation gates). The blocker escalation mechanism is the primary safety feature of the autonomous loop.

## Design Decision: Fire-and-Forget Autonomous Loop

**User directive**: /orchestrate drives the full lifecycle autonomously without confirmation gates.

**Teammate D's dissent** (noted for reference): Teammate D recommended human confirmation gates between phases. Argument: "Research that goes off-track should be caught before a plan is built on it." This is a valid concern for the default behavior.

**Resolution**: The user has specified autonomous loop as the correct behavior. Task 596 should implement this as specified. The `--auto` flag mentioned in the delegation context is the interface — by default, /orchestrate is the autonomous loop.

**Subsumes task 501**: Task 501 (optimize team-mode fork cache sharing) is subsumed by /orchestrate's implementation of fork caching for blocker escalation.

## State Machine Design (Teammates A, B, D)

```
READ state.json → determine current_status
  ├── not_started → dispatch research (fresh subagent) → read research handoff → continue
  ├── researched  → dispatch plan agent (fresh) → read plan handoff → continue  
  ├── planned     → dispatch implement agent (fresh) → read impl handoff → loop:
  │     ├── implemented → mark complete, exit
  │     ├── partial + handoff_path → dispatch successor (fresh) → loop
  │     ├── partial, no handoff → mark blocked, notify user, exit
  │     └── blocked + blocker_desc → BLOCKER ESCALATION (see below)
  └── terminal (completed/abandoned/expanded) → report, exit
```

**Loop guard**: Max 10 cycles (extends current max-3 convention for single-phase). Uses `.continuation-loop-guard` file mechanism. Persists loop count across interruptions.

## Blocker Escalation (The Highest-Value Capability)

From the team research synthesis: "Blocker escalation: detect -> research -> revise -> resume is the highest-value novel capability."

**Escalation flow** (Teammates A, B, D):

```
implement phase N → blocker detected in handoff artifact
  → orchestrator reads blocker description from handoff
  → dispatch research fork (same-turn, cache-warm, ~90% token savings)
    ↑ Uses FORK_SUBAGENT=1; no subagent_type — inherits orchestrator's warm context
  → research fork writes blocker findings to disk
  → orchestrator reads blocker findings handoff
  → dispatch reviser agent (fresh subagent with findings + current plan)
  → reviser writes revised plan to disk  
  → orchestrator reads revised plan handoff
  → re-dispatch implementation from the blocked phase
  → loop continues
```

**Why fork for blocker research**: "The orchestrator's context is warm with the task context, plan state, and blocker description. A fork re-uses this cache (~90% input token reduction)" (Teammate D). The research for the blocker doesn't need a specialized agent prompt — the orchestrator already has all needed context.

## Nested Loop Resolution (Teammate C — Critical)

**Problem**: The orchestrator's outer loop and skill-implementer's inner continuation loop could nest, causing unpredictable behavior.

**Solution** (Teammate C's recommendation, confirmed by team synthesis): The two loops must be exclusive alternatives, not nested layers.

**Implementation**:
1. When /orchestrate dispatches /implement, it writes a flag file: `.orchestrate-outer-loop-active`
2. skill-implementer checks for this flag at Stage 5c (continuation loop detection)
3. If flag is present, skill-implementer skips its inner continuation loop — just returns `partial` with handoff path
4. The orchestrator's outer loop handles continuation
5. When /orchestrate exits (success or failure), it removes the flag file

**Guard file location**: `.claude/tmp/.orchestrate-outer-loop-active` (existing tmp directory)

## Handoff-Only Communication (Teammates A, B)

The orchestrator must NEVER accumulate agent output in its own context:

**Pattern**:
1. Orchestrator dispatches agent with prompt (including task context, delegation context)
2. Agent writes structured handoff to disk (200-400 tokens)
3. Agent returns brief text summary (3 lines max)
4. Orchestrator reads handoff file from disk
5. Orchestrator makes next dispatch decision based on handoff
6. Orchestrator's own context stays flat regardless of cycle count

**Structured handoff schema** (Teammate B, adapting OpenAI's pattern):
```json
{
  "phase": "research|plan|implement",
  "status": "completed|partial|blocked",
  "summary": "What was found/done. Key decisions made.",
  "artifacts": ["path/to/artifact.md"],
  "blockers": [{"description": "...", "context": "..."}],
  "next_action_hint": "plan|implement|block|done"
}
```

## Fork vs. Fresh Agent Decision for /orchestrate

| State | Fork or Fresh? | Agent | Handoff Read |
|-------|----------------|-------|-------------|
| `not_started` | Fresh (`subagent_type`) | `general-research-agent` | reads research handoff |
| `researched` | Fresh (`subagent_type`) | `planner-agent` | reads plan handoff |
| `planned` | Fresh (`subagent_type`) | `general-implementation-agent` | reads impl handoff |
| `implementing/partial + handoff_path` | Fresh (successor) | `general-implementation-agent` | reads impl handoff |
| `blocked` (blocker research) | **Fork** (no `subagent_type`) | (inherited context) | reads blocker handoff |
| `blocked` (revise) | Fresh (`subagent_type`) | `reviser-agent` | reads revised plan |

## Context Budget Architecture for Orchestrator

The orchestrator runs in the main session (not as a subagent). Per Teammate A: "Subagents cannot spawn other subagents... The orchestrator must be the main session."

**Orchestrator context management**:
- Read handoffs from files (not inline accumulation)
- Clear previous cycle's tool output before next cycle
- Keep orchestrator state as structured JSON (not conversational prose)
- Force early compaction via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` on worker agents

**Note (task 598 dependency)**: The orchestrator should use context budget caps from task 598 when injecting context into dispatched agents.

## Implementation Scope

**New files to create**:
- `.claude/commands/orchestrate.md` — command definition (~150-200L)
- `.claude/skills/skill-orchestrator/SKILL.md` — replaces vestigial 128L skill
- `.claude/agents/orchestrator-agent.md` — new orchestrator agent definition

**Agent responsibilities**:
- Read state.json to determine current task status
- Choose dispatch pattern (fork vs. fresh) per state machine
- Write orchestration progress to `.orchestrate-state.json`
- Read handoff artifacts (never inline agent output)
- Handle blocker escalation cycle
- Write final handoff artifact (for orchestrator's own successor if needed)

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Orchestrator accumulates tool output across cycles | Handoff-only communication pattern |
| Nested loops with implementer | Flag file mechanism (.orchestrate-outer-loop-active) |
| Blocker escalation creates infinite revision cycle | Cap blocker escalation at 2 attempts; require human on 3rd |
| Runaway loop on consistently failing task | Max 10 cycles guard + guard file persistence |
| Research fork fails (context not warm) | Degrade gracefully to fresh subagent with error notice |

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 2 (/orchestrate design), Synthesis table (conflicts resolved)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Finding 4 (Orchestration state machines), Recommended approach section 3
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Finding 4 (OpenAI handoff pattern), Finding 5 (LangGraph conditional routing)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 3 (/orchestrate reliability concerns, nested loop issue)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 1 (/orchestrate design, state machine, confirmation gates dissent)
- `specs/501_optimize_team_mode_fork_cache_sharing/` — Prior team mode fork research (subsumed)
