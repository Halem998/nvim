# Research Report: Task #659

**Task**: 659 - Add phase containment for orchestrator-dispatched agents
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:30:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, dispatch-agent-spec.md, handoff-schema.md, agent definitions)
**Artifacts**: specs/659_orchestrator_phase_containment/reports/01_phase-containment.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The orchestrator currently passes no phase constraint when dispatching agents — a research agent receiving its delegation context has no explicit signal that it should not spawn implementation sub-agents on its own.
- The `orchestrator_mode` flag exists but is semantically wrong for this purpose: it is set to `false` for research/plan dispatches and `true` only for implement dispatches, so research agents cannot use it to detect they are inside an orchestrator invocation.
- The correct fix is a new `phase_constraint` field in the delegation context JSON, paired with a `phase_recommendations` array in `.orchestrator-handoff.json`, and MUST NOT clauses in each agent's Critical Requirements section.
- The most robust enforcement point is the agent definition (MUST NOT section) rather than the dispatch script, because agents are document-driven; however a lightweight check in skill-base.sh or the dispatch context builder provides defense-in-depth.

## Context & Scope

The task asks for phase containment: when the orchestrator dispatches a research agent, that agent must not autonomously spawn a planning or implementation sub-agent, even if the research reveals the work is trivial. The agent may note a recommendation (e.g. "implementation appears straightforward") in the handoff for the orchestrator to act on. This preserves the orchestrator state machine, ensures artifacts are created in the standard lifecycle order, and prevents planning and implementation phases from being bypassed.

Files examined:
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — Stage 4 dispatch context construction
- `/home/benjamin/.config/nvim/.claude/docs/architecture/dispatch-agent-spec.md` — dispatch_agent() function spec
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md` — orchestrator handoff JSON schema
- `/home/benjamin/.config/nvim/.claude/docs/architecture/orchestrate-state-machine.md` — state machine transitions
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md` — research agent definition
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` — implementation agent definition
- `/home/benjamin/.config/nvim/.claude/agents/planner-agent.md` — planner agent definition
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — shared skill lifecycle functions

## Findings

### Codebase Patterns

**Current dispatch context construction (Stage 4 of skill-orchestrate SKILL.md)**

For research dispatch (state: not_started):
```json
{"task_number": N, "task_type": "T", "session_id": "S", "orchestrator_mode": false}
```

For plan dispatch (state: researched):
```json
{"task_number": N, "task_type": "T", "session_id": "S", "research_artifacts": [...], "orchestrator_mode": false}
```

For implement dispatch (state: planned/implementing):
```json
{"task_number": N, "task_type": "T", "session_id": "S", "orchestrator_mode": true, "plan_path": "..."}
```

The `orchestrator_mode: false` in research/plan dispatches means agents currently have no signal that the orchestrator is controlling their lifecycle. They can legitimately reason: "I am a research agent. I found the work is trivial. I will also implement it." Nothing in the current delegation context prevents this.

**What `orchestrator_mode` means today**

`orchestrator_mode: true` has a single semantics: write `.orchestrator-handoff.json` in the postflight. It is set to `false` for research and plan dispatches because the orchestrator reads the handoff only after implement dispatches to check for blockers/continuation. This flag is not designed to signal phase scope.

**Existing scope boundary pattern (meta-builder-agent)**

The `meta-builder-agent.md` has a strong SCOPE BOUNDARY section:
```
**SCOPE BOUNDARY**: This agent MUST NOT write to `.claude/` paths using Write or Edit tools.
It creates TASKS in `specs/` only.
```
This is enforced both by a MUST NOT section in the agent definition and by a PostToolUse hook (`validate-meta-write.sh`). This is the closest analogue to what task 659 needs.

**Existing MUST NOT sections in agent definitions**

All four primary agents (general-research-agent, general-implementation-agent, planner-agent, spawn-agent) have a Critical Requirements section with MUST NOT lists. None currently prohibit cross-phase agent spawning.

**Handoff schema — `next_action_hint` is advisory only**

The handoff schema has `next_action_hint` (values: plan, implement, revise, none) which is "advisory only — the orchestrator's state machine may override this hint." This is close to what we need for recommendations, but is about what action the orchestrator should take next, not about recording agent-level insights.

**skill-orchestrate MUST NOT section**

The orchestrate skill has its own MUST NOT list:
```
1. Read research reports (reports/*.md) during the state machine loop
2. Read plan files (plans/*.md) during the state machine loop
3. Read implementation summaries (summaries/*.md) during the state machine loop
4. Read continuation handoff files (handoffs/*.md) — pass the path, not the content
```

This shows the pattern of hard constraints in skill/agent definitions is well-established.

### Design Analysis

**Where should phase_constraint be checked?**

Three possible enforcement points:

1. **Agent definition MUST NOT section** — Agents are document-driven systems. The definition is the agent's specification. Adding "MUST NOT spawn child agents for lifecycle phases other than the one you are dispatched for" is direct and follows the meta-builder-agent pattern. However, it relies on the agent reading and following its definition — no hard enforcement.

2. **dispatch-agent.sh** — The dispatch function constructs delegation context. Adding `phase_constraint` here ensures every dispatch includes the field. But dispatch-agent.sh doesn't enforce it on the receiving side; the agent still decides what to do.

3. **skill-base.sh postflight** — Could check whether an agent that received `phase_constraint: research` wrote any unexpected artifacts (e.g., plan files). But this is post-hoc detection, not prevention.

**Recommended approach: dual enforcement**

- Add `phase_constraint` to delegation context in skill-orchestrate Stage 4 (construction side)
- Add MUST NOT clauses to all agent definitions (instruction side)
- Add `phase_recommendations` to handoff-schema.md (communication channel for recommendations)

This mirrors the meta-builder-agent pattern: the agent definition has the SCOPE BOUNDARY section AND a hook validates it.

**phase_constraint schema**

```json
{
  "phase_constraint": "research" | "plan" | "implement" | "none"
}
```

When `phase_constraint` is present and not "none":
- The agent MUST confine its work to that phase
- The agent MUST NOT use the Agent tool to spawn sub-agents that would perform a different lifecycle phase
- If the agent discovers the work would be trivial in another phase, it MUST record this in the handoff's `phase_recommendations` array

**phase_recommendations in handoff-schema.md**

Add a new optional array field to `.orchestrator-handoff.json`:

```json
"phase_recommendations": [
  {
    "recommendation": "Implementation appears trivial — single file edit",
    "triggered_by": "research finding: no complex dependencies"
  }
]
```

The orchestrator reads this field and may choose to act on it (e.g., skip plan phase for trivial tasks) or ignore it. This is the communication channel for agent insight without cross-phase execution.

**Token budget impact**

The full handoff must stay under 400 tokens. `phase_recommendations` entries should be capped at ~50 tokens total (2 entries max, each ~25 tokens). The `phase_constraint` field in delegation context is a short string — negligible cost.

**Edge cases**

1. **Research agent needs to test something**: Testing during research (e.g., `nvim --headless` sanity check) is acceptable — it is within the research phase. What is prohibited is writing plan files, creating implementation artifacts, or spawning a planner/implementer sub-agent.

2. **Blocker escalation forks**: The orchestrator itself spawns anonymous forks for blocker research (is_blocker_escalation=true). These forks should also receive `phase_constraint: research` and explicitly MUST NOT escalate further. The fork is already cache-warm and general-purpose — it should not spawn additional sub-agents.

3. **continuation_context in implement dispatch**: When `phase_constraint: implement` is set, the agent may still write handoffs (phase-N-handoff-T.md) for context exhaustion continuation. These are within the implement phase. They are not cross-phase work.

4. **Reviser agent**: Reviser is dispatched with `phase_constraint: revise`. It rewrites a plan file — this is within the revise phase, not the implement phase. The reviser should not spawn an implementer even if the revised plan looks simple.

5. **team mode**: When `--team` flag is used, each teammate receives the same `phase_constraint`. Synthesis-agent (which consolidates team research) also receives `phase_constraint: research`.

**What files need to change**

| File | Change |
|------|--------|
| `skill-orchestrate/SKILL.md` | Stage 4: add `phase_constraint` to each dispatch context JSON |
| `docs/architecture/dispatch-agent-spec.md` | Document `phase_constraint` as a standard delegation context field |
| `docs/architecture/handoff-schema.md` | Add `phase_recommendations` array field to schema |
| `agents/general-research-agent.md` | Add phase containment MUST NOT clause to Critical Requirements |
| `agents/general-implementation-agent.md` | Add phase containment MUST NOT clause |
| `agents/planner-agent.md` | Add phase containment MUST NOT clause |
| `agents/neovim-research-agent.md` | Add phase containment MUST NOT clause |
| `agents/neovim-implementation-agent.md` | Add phase containment MUST NOT clause |
| `agents/nix-research-agent.md` | Add phase containment MUST NOT clause |
| `agents/nix-implementation-agent.md` | Add phase containment MUST NOT clause |
| `agents/reviser-agent.md` | Add phase containment MUST NOT clause |

Extension agents (lean, etc.) would also need updates if present.

### Recommendations

1. **Add `phase_constraint` to dispatch context in skill-orchestrate SKILL.md**: Each dispatch in Stage 4 should include the field. Research dispatch: `phase_constraint: "research"`. Plan dispatch: `phase_constraint: "plan"`. Implement dispatch: `phase_constraint: "implement"`. Blocker research fork: `phase_constraint: "research"`. Reviser dispatch: `phase_constraint: "revise"`.

2. **Update agent MUST NOT sections**: Each agent should add:
   ```
   6. Spawn child agents for lifecycle phases other than the assigned phase_constraint value
      (when phase_constraint is present in delegation context)
   ```
   And a corresponding MUST DO:
   ```
   9. If you identify work that should be done in another phase, record it in the handoff's
      phase_recommendations array (when writing the orchestrator handoff) or in the research
      report's Recommendations section
   ```

3. **Update handoff-schema.md**: Add `phase_recommendations` as an optional array. Keep token budget impact minimal — max 2 entries, ~25 tokens each.

4. **Update dispatch-agent-spec.md**: Document the new `phase_constraint` field in the "Parameters" section and the decision matrix.

5. **Scope the change to orchestrated dispatches only**: When `phase_constraint` is absent from delegation context (i.e., agent invoked via normal `/research`, `/plan`, `/implement` commands, not orchestrator), agents behave as today. This preserves backward compatibility.

## Decisions

- `phase_constraint` is a new delegation context field, not a reuse of `orchestrator_mode`. The two flags serve different purposes: `orchestrator_mode` controls handoff writing; `phase_constraint` controls scope.
- The enforcement model is instruction-based (MUST NOT in agent definitions) rather than hook-based, because the violated behavior (spawning an Agent tool call of a different type) is hard to detect in a PostToolUse hook without knowing the subagent_type intent upfront.
- `phase_recommendations` replaces ad-hoc use of `next_action_hint` for agent-level recommendations. The `next_action_hint` field remains for its original purpose (signaling what state the orchestrator should transition to next).
- Phase containment applies only when `phase_constraint` is explicitly set. Absence of the field = no constraint (backward compatible).
- Blocker research forks receive `phase_constraint: "research"` even though they are anonymous forks — the constraint is in the delegation context JSON, which is passed regardless of fork/named-subagent dispatch mode.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent ignores MUST NOT clause | High (bypasses state machine) | Low (agents generally follow their definitions) | Add to multiple places: MUST NOT, MUST DO, and a dedicated "Phase Containment" section for visibility |
| phase_recommendations exceeds token budget | Medium (corrupts handoff) | Low | Cap at 2 entries in schema doc; add token budget table entry |
| Missing extension agents | Medium (only some agents updated) | Medium | Create a checklist in the plan covering all agents in `.claude/agents/` |
| Reviser agent confusion (plan vs revise) | Low | Low | Explicitly document "revise" as a distinct phase_constraint value |
| team mode teammates miss constraint | Medium | Low | Teammates receive same delegation context as single-agent — constraint applies equally |

## Context Extension Recommendations

None — this is a meta task. The findings will be reflected in updated agent definitions and architecture docs.

## Appendix

**Files examined**:
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/dispatch-agent-spec.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/orchestrate-state-machine.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/planner-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` (scope boundary pattern reference)
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh`

**Agents that need MUST NOT updates (complete list)**:
- general-research-agent.md
- general-implementation-agent.md
- planner-agent.md
- reviser-agent.md
- neovim-research-agent.md
- neovim-implementation-agent.md
- nix-research-agent.md
- nix-implementation-agent.md
- spawn-agent.md (lower priority — spawn is already scoped to blocker analysis)
