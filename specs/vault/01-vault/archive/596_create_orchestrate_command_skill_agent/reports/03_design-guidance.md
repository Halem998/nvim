# Design Guidance: Task 596 — Create /orchestrate Command, Skill, and dispatch_agent()

**Source**: Task 592 architecture design
**Authoritative References**:
- `.claude/docs/architecture/orchestrate-state-machine.md` — state machine details
- `.claude/docs/architecture/dispatch-agent-spec.md` — dispatch_agent() function
- `.claude/docs/architecture/handoff-schema.md` — handoff JSON schema
**Depends on**: Tasks 593 (shared utilities), 594 (skill base), 598 (context budgets)
**Blocks**: Task 599

---

## Overview

Task 596 creates the `/orchestrate` autonomous orchestration loop. Key deliverables:
1. `.claude/commands/orchestrate.md` — thin entry point (~50 lines)
2. `.claude/skills/skill-orchestrate/SKILL.md` — state machine (~200 lines)
3. `.claude/scripts/dispatch-agent.sh` — fork-vs-subagent function
4. Loop guard and orchestrator handoff infrastructure

---

## File Layout

```
.claude/commands/orchestrate.md           # NEW: entry point, arg parsing
.claude/skills/skill-orchestrate/
└── SKILL.md                              # NEW: state machine + dispatch (~200L)
.claude/scripts/dispatch-agent.sh         # NEW: dispatch function
specs/{NNN}_{SLUG}/
├── .orchestrator-handoff.json            # RUNTIME: written by skills
└── .orchestrator-loop-guard              # RUNTIME: cycle counter
```

---

## Complete State Machine State Table

| State | Detected By | Action | Success Next | Failure Next |
|-------|-------------|--------|--------------|--------------|
| `not_started` | state.json status | dispatch research (named) | researched | cycle++ |
| `researched` | state.json status | dispatch plan (named) | planned | cycle++ |
| `planned` | state.json status | dispatch implement (orch_mode=true) | completed | check handoff |
| `implementing` | state.json status | dispatch implement (resume) | completed | check handoff |
| `partial` + handoff_path | orchestrator handoff | re-dispatch implement with continuation | completed | check handoff |
| `partial` + blockers | orchestrator handoff | ESCALATE: fork research → revise → implement | completed | cycle++ |
| `partial` + no handoff + MAX_CYCLES | cycle count | report, exit loop | — | — |
| `blocked` | state.json status | read blockers → ESCALATE | planned | cycle++ |
| `completed` | state.json status | report success, exit | — | — |
| `abandoned/expanded` | state.json status | report status, exit | — | — |

**MAX_CYCLES = 5** per invocation.

---

## Loop Guard File Schema

```bash
# File: specs/{NNN}_{SLUG}/.orchestrator-loop-guard
# Created at start of /orchestrate invocation
# Updated after each dispatch cycle

{
  "session_id": "sess_...",
  "cycle_count": 2,
  "max_cycles": 5,
  "current_state": "planned",
  "started": "2026-05-22T00:00:00Z",
  "last_updated": "2026-05-22T00:30:00Z"
}
```

The loop guard persists between conversational turns so a resumed `/orchestrate` sees accumulated
cycle count.

---

## `dispatch_agent()` Full Function Specification

```bash
# File: .claude/scripts/dispatch-agent.sh
# Source this file in skill-orchestrate/SKILL.md

dispatch_agent() {
  # Parameters:
  #   $1 = agent_type             "general-research-agent" | "planner-agent" | etc.
  #                               Pass "" (empty) for fork path
  #   $2 = prompt                 Full prompt string for Agent tool
  #   $3 = context_json           Delegation context JSON string
  #   $4 = is_blocker_escalation  "true" | "false"
  #
  # Returns:
  #   exit 0 on success
  #   exit 1 on agent failure
  #   Side effect: agent writes .orchestrator-handoff.json

  local agent_type="$1"
  local prompt="$2"
  local context_json="$3"
  local is_blocker_escalation="$4"

  if [ "$is_blocker_escalation" = "true" ]; then
    # FORK PATH: no subagent_type
    # → FORK_SUBAGENT=1 applies if set
    # → parent cache prefix inherited (~90% token reduction)
    invoke_agent_fork "$prompt" "$context_json"
  else
    # NAMED SUBAGENT PATH: full structured context injection
    invoke_named_agent "$agent_type" "$prompt" "$context_json"
  fi
}
```

### Decision Matrix: When to Use Each Path

| Dispatch Reason | `is_blocker_escalation` | Path Used |
|----------------|------------------------|-----------|
| not_started → research | `false` | Named subagent |
| researched → plan | `false` | Named subagent |
| planned/partial → implement | `false` | Named subagent |
| Blocker escalation: research fork | `true` | Fork |
| Blocker escalation: revise | `false` | Named subagent |
| Blocker escalation: re-implement | `false` | Named subagent |

Only the initial blocker research step uses a fork. Reviser and re-implement always use named subagents.

---

## `.orchestrator-handoff.json` Schema

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "research | plan | implement | revise",
  "status": "researched | planned | implemented | partial | failed | blocked",
  "summary": "2-4 sentences. Budget: ~100 tokens. Describe outcome concisely.",
  "artifacts": [
    {
      "type": "report | plan | summary",
      "path": "specs/NNN_slug/type/file.md"
    }
  ],
  "blockers": [
    {
      "description": "Specific blocker description for research fork",
      "phase": "phase-N",
      "severity": "hard | soft"
    }
  ],
  "next_action_hint": "plan | implement | revise | none",
  "files_modified": ["list of modified file paths"],
  "decisions_made": ["key decision 1", "key decision 2"],
  "dead_ends": ["approach tried and failed"],
  "continuation_context": {
    "handoff_path": "specs/.../handoffs/phase-N-handoff-TIMESTAMP.md",
    "phases_completed": 2,
    "phases_total": 4,
    "orchestrator_mode": true
  }
}
```

**Token budget**: Full handoff MUST be ≤ 400 tokens. `summary` ≤ 100 tokens.

### Reading the Handoff (in skill-orchestrate)

```bash
handoff_file="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
handoff=$(cat "$handoff_file")
status=$(echo "$handoff" | jq -r '.status')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
has_blockers=$(echo "$blockers" | jq 'length > 0')
has_continuation=$(echo "$continuation" | jq '. != null')
```

---

## Blocker Escalation: 5-Step Implementation

```bash
blocker_escalation() {
  local task_number="$1"
  local padded_num="$2"
  local project_name="$3"
  local handoff_file="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"

  # Step 1: Extract blocker description
  local blocker_desc=$(jq -r '.blockers[0].description' "$handoff_file")
  local plan_path=$(jq -r '.artifacts[] | select(.type == "plan") | .path' "$handoff_file")

  # Step 2: Fork research (is_blocker_escalation=true)
  local research_prompt="Research blocker: $blocker_desc

Context: Task $task_number implementation is blocked. Research this blocker and provide
concrete findings that can inform a plan revision. Write results to .orchestrator-handoff.json."
  local research_context="{\"orchestrator_mode\": true, \"task_number\": $task_number, \"padded_num\": \"$padded_num\", \"project_name\": \"$project_name\"}"
  dispatch_agent "" "$research_prompt" "$research_context" "true"

  # Step 3: Read research findings from handoff
  local research_summary=$(jq -r '.summary' "$handoff_file")
  local research_artifact=$(jq -r '.artifacts[0].path // ""' "$handoff_file")

  # Step 4: Dispatch revise (named subagent)
  local revise_prompt="Revise the implementation plan based on research findings.
Plan path: $plan_path
Research findings: $research_summary
Research artifact: $research_artifact
Write revised plan as new version (e.g., 02_revised-plan.md)."
  local revise_context="{\"orchestrator_mode\": true, \"task_number\": $task_number, \"padded_num\": \"$padded_num\", \"project_name\": \"$project_name\", \"research_findings\": \"$research_summary\"}"
  dispatch_agent "reviser-agent" "$revise_prompt" "$revise_context" "false"

  # Step 5: Re-dispatch implement (named subagent)
  local new_plan_path=$(jq -r '.artifacts[0].path // ""' "$handoff_file")
  local implement_prompt="Implement the revised plan: $new_plan_path"
  local impl_context="{\"orchestrator_mode\": true, \"task_number\": $task_number, \"padded_num\": \"$padded_num\", \"project_name\": \"$project_name\"}"
  dispatch_agent "general-implementation-agent" "$implement_prompt" "$impl_context" "false"
}
```

---

## Nested Loop Resolution: orchestrator_mode Flag

### In skill-implementer (to be added in task 594 or 596)

```bash
# Read from delegation context
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')

# Disable inner continuation loop when orchestrator drives
if [ "$orchestrator_mode" = "true" ]; then
  max_continuations=0   # Outer orchestrator loop handles continuation
else
  max_continuations=3   # Normal inner loop
fi
```

### Flag Propagation Through Continuations

When skill-implementer runs in orchestrator_mode AND returns partial (context exhaustion):
1. Write continuation handoff: `specs/{NNN}_{SLUG}/handoffs/phase-N-handoff-T.md`
2. Write orchestrator handoff with `continuation_context.orchestrator_mode=true`

The orchestrator then passes `orchestrator_mode=true` forward in the next implement dispatch.

---

## Context Flatness Guarantee

The orchestrator loop NEVER reads full agent output. Per dispatch cycle, it reads only:
- The 400-token `.orchestrator-handoff.json` file
- Its own `.orchestrator-loop-guard` file

Orchestrator context growth per cycle: ~450 tokens (handoff + loop guard overhead).
After 5 cycles: ~2250 tokens total orchestrator context growth.

---

## Verification

```bash
# Verify new files exist
ls -la .claude/commands/orchestrate.md \
       .claude/skills/skill-orchestrate/SKILL.md \
       .claude/scripts/dispatch-agent.sh

# Functional test: end-to-end orchestration
# 1. Create a simple test task in not_started state
# 2. Run /orchestrate {task_number}
# 3. Verify research → plan → implement lifecycle completes
# 4. Verify .orchestrator-loop-guard created and updated each cycle
# 5. Verify task reaches completed status in state.json

# Test blocker escalation (requires a task that will produce a hard blocker)
# Verify: research fork dispatched, revise called, re-implement called

# Test orchestrator_mode flag:
# Verify skill-implementer max_continuations=0 when orchestrator_mode=true
```
