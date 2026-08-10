# Seed Research Report: Task #592

**Task**: 592 — Design unified workflow architecture
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to architecture design decisions

## Overview

Task 592 is the foundational design task for the entire workflow refactoring suite (tasks 592-599). The architecture design must produce a unified specification covering: shared command infrastructure, shared skill base, /orchestrate state machine, fork vs. subagent decision tree, handoff protocol, extension integration points, and nested loop resolution.

## Key Architecture Findings

### 1. Fork vs. Subagent Decision Matrix (Teammates A, B, C)

The core architectural decision is when to use fork (FORK_SUBAGENT=1) vs. fresh named subagents:

| Scenario | Pattern | Rationale |
|----------|---------|-----------|
| Sequential phase dispatch (research -> plan -> implement) | Fresh subagent (`subagent_type`) | Cache cold between phases; agent needs specialized prompt |
| Blocker escalation within same turn | Fork (no `subagent_type`) | Orchestrator context warm; ~90% token savings |
| Team mode parallel teammates | Fork (teammates 2-N) | Shared prefix; ~60% total cost reduction |
| Extension task routing | Fresh subagent | Needs domain-specific agent definition |

**Critical constraint (Teammate A)**: Prompt cache TTL is 5 minutes (changed from 60 min in early 2026). Fork cache-sharing only benefits operations completing within a single conversational turn.

**Resolved conflict (Teammate C vs. task 500)**: "Fork cache sharing is fundamentally incompatible with named agent routing." The resolution: use forks ONLY where named routing isn't needed (blocker escalation, team mode); fresh subagents where named routing is needed (core workflow dispatch).

### 2. dispatch_agent() Abstraction (Teammate D)

The architecture must include a single function that encapsulates the fork-vs-subagent decision:

```bash
# In shared-workflow-utils.sh
dispatch_agent() {
  local agent_type="$1"
  local prompt="$2"
  local context="$3"

  if [ "$CLAUDE_CODE_FORK_SUBAGENT" = "1" ] && context_is_warm "$agent_type"; then
    invoke_fork "$prompt" "$context"
  else
    invoke_named_subagent "$agent_type" "$prompt" "$context"
  fi
}
```

This makes the fork/named-subagent decision configurable and future-proof. When Anthropic provides a "named fork" API (identified as the most consequential missing platform feature), only this function needs updating.

### 3. Structured Handoff Protocol (Teammates A, B)

The orchestrator must use file-based handoffs, NOT inline context accumulation:

```json
{
  "phase": "research",
  "status": "completed",
  "summary": "Found X, Y, Z. Key decision: use approach A.",
  "artifacts": ["specs/591.../reports/01_report.md"],
  "blockers": [],
  "next_action_hint": "plan"
}
```

**Why this matters**: This replaces raw artifact injection (2000-5000 tokens) with a 200-400 token structured delta. The orchestrator's context stays flat regardless of how many agents have run.

**Principle**: The orchestrator NEVER inlines agent output. It dispatches an agent, reads the handoff file from disk after completion, makes the next dispatch decision based on the handoff.

### 4. /orchestrate State Machine Design (Teammates A, D)

The state machine for the /orchestrate command:

```
READ state.json → determine current_status
  ├── not_started → dispatch research (fresh subagent) → read research handoff → continue
  ├── researched  → dispatch plan agent (fresh) → read plan handoff → continue
  ├── planned     → dispatch implement agent (fresh) → read impl handoff → loop:
  │     ├── implemented → mark complete, exit
  │     ├── partial + handoff_path → dispatch successor → loop
  │     ├── partial, no handoff → wait for user → exit
  │     └── blocked → dispatch research fork (cache-warm) → read → dispatch reviser → re-dispatch impl
  └── terminal (completed/abandoned/expanded) → report, exit
```

**Fire-and-forget behavior** (User directive, confirmed against team research synthesis): /orchestrate runs autonomously without confirmation gates. The --auto flag distinction was considered but the final user direction specifies an autonomous loop as the default behavior.

**Note on Teammate D's dissent**: Teammate D recommended confirmation gates. The user direction overrides this: the system should be fire-and-forget by default. Blocker escalation is the safety mechanism — it's autonomous loop management at the level of "research the blocker and fix it" rather than "ask the user."

### 5. Nested Loop Resolution (Teammate C)

The orchestrator's outer loop and skill-implementer's inner continuation loop MUST be exclusive, not nested. This is a critical architectural constraint:

- When /orchestrate dispatches /implement, set a flag that disables skill-implementer's inner continuation loop
- The orchestrator handles continuation at the outer level
- Two nested loops with different termination conditions are likely to interfere and cause unpredictable behavior

**Evidence**: The `.continuation-loop-guard` file mechanism already exists in the current system. The /orchestrate design should detect this guard and take over loop management when present.

### 6. Shared Skill Base Architecture (Teammates A, B, C)

For the shared skill base design (which feeds task 594):

- **Safe to share**: ~8 of ~11 stages are structurally identical across the 4 core skills
- **Must remain skill-specific**: context-collection stages (researcher has 4a/4b/4c/4d; planner has only 4a; implementer has 4a only)
- **Implementation**: `.claude/scripts/skill-base.sh` with `source`-based composition; each skill provides agent prompt construction + skill-specific context parameters

**Caution (Teammate C)**: The duplication was partially intentional — deliberate architectural trade where code length was exchanged for reliability. A shared base needs careful conditional inclusion design to avoid adding abstraction overhead.

### 7. Extension Integration Points (Teammate D)

Extensions must be first-class citizens in the new architecture. The design must specify lifecycle hooks in manifest.json:

```json
{
  "hooks": {
    "preflight": "scripts/nix-preflight.sh",
    "context_injection": "scripts/nix-context.sh",
    "postflight": "scripts/nix-postflight.sh"
  }
}
```

**Current problem**: Extension skills must duplicate the entire lifecycle pattern. When the core changes, extension skills diverge silently (nix-implementation uses non-standard stage format).

**Architectural requirement**: The unified architecture must define the extension hook interface at design time (task 592) so that tasks 594-598 implement against a stable interface.

### 8. Command Infrastructure Deduplication (Teammates A, B)

For the shared command infrastructure design (which feeds task 593):

Target components for `command-base.sh` or equivalent:
- `parse_task_args()` — handles `N[,N-N]` syntax (~30 lines x3 commands)
- Flag parsing — effort, model, clean, team flags (~50 lines x3)
- `route_to_skill()` — task-type-based routing via `index.json`
- `gate_in()` — session_id generation + status validation + preflight status update
- `gate_out()` — postflight status update + artifact linking + git commit

**Key principle**: Commands should NOT load agent-level context. The agent loads its own context. The command's job is routing only.

## Architecture Deliverables for Task 592

The design task must produce:
1. **Fork decision matrix document** — table mapping scenario to fork/subagent pattern with rationale
2. **dispatch_agent() specification** — function signature, parameters, fork-vs-named decision logic
3. **Handoff protocol specification** — JSON schema, 200-400 token budget, what fields are required
4. **State machine design** — states, transitions, agent dispatch per state, handoff consumption
5. **Shared skill base architecture** — which stages are shared, which are skill-specific, conditional inclusion design
6. **Extension lifecycle hook interface** — manifest.json schema for hooks, hook execution contract
7. **Nested loop resolution mechanism** — how /orchestrate detects and disables skill-implementer's loop
8. **Context budget architecture overview** — tier system (to be detailed in task 598, but the design must acknowledge it)

## Dependencies and Blockers

**Inputs required before task 592 can complete**:
- Task 591 research (this seed report satisfies that requirement)

**What task 592 unblocks**:
- Task 593: Shared utilities extraction (follows the architecture)
- Task 598: Progressive disclosure (informed by the architecture's context budget requirements)

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 1 (Fork decision matrix), Section 4 (Progressive disclosure), Synthesis (Conflicts resolved)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Finding 1 (Fork vs. subagent), Finding 4 (State machine design)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Finding 2 (Unified postflight), Finding 4 (Handoff pattern), Finding 6 (Fork cache architecture)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 1 (Intentional duplication), Finding 3 (/orchestrate reliability concerns), Finding 5 (Extension integration)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 1 (/orchestrate design), Finding 2 (Extension evolution), Finding 3 (dispatch_agent abstraction)
