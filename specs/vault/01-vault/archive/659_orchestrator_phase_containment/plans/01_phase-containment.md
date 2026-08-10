# Implementation Plan: Add Phase Containment for Orchestrator-Dispatched Agents

- **Task**: 659 - Add phase containment for orchestrator-dispatched agents
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/659_orchestrator_phase_containment/reports/01_phase-containment.md
- **Artifacts**: plans/01_phase-containment.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `phase_constraint` field to the delegation context that skill-orchestrate passes when dispatching agents. When present, agents must confine their work to the assigned phase and must not spawn child agents for other lifecycle phases. Agents can note cross-phase recommendations in a new `phase_recommendations` array in the orchestrator handoff schema. This requires updates to skill-orchestrate dispatch context construction, the handoff schema, the dispatch-agent spec, and MUST NOT sections in 9 agent definitions.

### Research Integration

The research report identified that `orchestrator_mode` is semantically wrong for phase containment (it controls handoff writing, not scope). The correct approach is a separate `phase_constraint` field with values `research|plan|implement|revise|none`, paired with instruction-based enforcement via MUST NOT clauses in agent definitions (following the meta-builder-agent SCOPE BOUNDARY pattern). The report also identified that blocker escalation forks need `phase_constraint: "research"` and that the drift-triggered reviser dispatch needs `phase_constraint: "revise"`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `phase_constraint` field to all orchestrator dispatch contexts (single-task and multi-task modes)
- Add `phase_recommendations` array to the orchestrator handoff schema
- Add MUST NOT / MUST DO clauses for phase containment to all 9 dispatched agent definitions
- Update dispatch-agent-spec.md to document the new field and decision matrix column

**Non-Goals**:
- Hook-based enforcement (PostToolUse hooks) -- instruction-based enforcement is sufficient for now
- Modifying non-orchestrated dispatch paths (normal `/research`, `/plan`, `/implement` commands)
- Updating extension agents outside `.claude/agents/` (lean, etc.) -- those are handled by extension maintainers

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent ignores MUST NOT clause | High (bypasses state machine) | Low | Place constraint in multiple visible locations: Critical Requirements and a dedicated Phase Containment section |
| Missing a dispatch context site in SKILL.md | Medium (some dispatches lack constraint) | Medium | Systematic grep for all `orchestrator_mode` occurrences to find every dispatch context construction |
| phase_recommendations exceeds handoff token budget | Medium (corrupts handoff) | Low | Cap at 2 entries in schema doc; add token budget table entry |
| Reviser confusion between plan and revise phases | Low | Low | Explicitly document "revise" as a distinct phase_constraint value |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Dispatch Context Construction in skill-orchestrate [COMPLETED]

**Goal**: Add `phase_constraint` to every dispatch context JSON in SKILL.md (single-task and multi-task modes).

**Tasks**:
- [ ] Add `"phase_constraint": "research"` to the `not_started` state handler dispatch context (line ~203)
- [ ] Add `"phase_constraint": "plan"` to the `researched` state handler dispatch context (line ~230)
- [ ] Add `"phase_constraint": "implement"` to the `planned`/`implementing` state handler dispatch context (line ~253)
- [ ] Add `"phase_constraint": "implement"` to the `partial` state continuation dispatch context (line ~280)
- [ ] Add `"phase_constraint": "research"` to the blocker escalation fork context in Stage 6 (line ~526)
- [ ] Add `"phase_constraint": "revise"` to the blocker escalation reviser dispatch context in Stage 6 (line ~546)
- [ ] Add `"phase_constraint": "implement"` to the blocker escalation re-implement dispatch context in Stage 6 (line ~560)
- [ ] Add `"phase_constraint": "revise"` to the drift inspection reviser dispatch context in Stage 5a (line ~478)
- [ ] Add `"phase_constraint": "research"` to multi-task research dispatch context (line ~915)
- [ ] Add `"phase_constraint": "plan"` to multi-task plan dispatch context (line ~937)
- [ ] Add `"phase_constraint": "implement"` to multi-task implement dispatch context (line ~965)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add phase_constraint to all 11 dispatch context construction sites

**Verification**:
- Grep for `orchestrator_mode` in SKILL.md and confirm every dispatch context also has `phase_constraint`
- Verify correct phase value at each site (research/plan/implement/revise)

---

### Phase 2: Update Architecture Documentation [COMPLETED]

**Goal**: Document `phase_constraint` in the dispatch-agent spec and add `phase_recommendations` to the handoff schema.

**Tasks**:
- [ ] Add `phase_constraint` to the Parameters section of dispatch-agent-spec.md with values enum and semantics
- [ ] Add a `phase_constraint` column to the Decision Matrix table in dispatch-agent-spec.md showing the constraint value for each dispatch context row
- [ ] Add `phase_recommendations` array field to the handoff-schema.md JSON schema (optional, max 2 entries)
- [ ] Add `phase_recommendations` to the Field Definitions section in handoff-schema.md with description, entry format (`recommendation` + `triggered_by` fields), and token budget (~50 tokens)
- [ ] Update the Token Budget Constraints table in handoff-schema.md to include `phase_recommendations` (~50 tokens, taken from advisory fields)
- [ ] Add a note to handoff-schema.md clarifying `phase_recommendations` vs `next_action_hint` distinction

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/docs/architecture/dispatch-agent-spec.md` - Add phase_constraint parameter and decision matrix column
- `.claude/docs/architecture/handoff-schema.md` - Add phase_recommendations field, update token budget table

**Verification**:
- Confirm the handoff schema example JSON includes `phase_recommendations` as an optional field
- Confirm dispatch-agent-spec.md decision matrix has all 6 rows annotated with phase_constraint values

---

### Phase 3: Add Phase Containment to Agent Definitions [COMPLETED]

**Goal**: Add MUST NOT and MUST DO clauses for phase containment to all 9 dispatched agent definitions.

**Tasks**:
- [ ] Add phase containment MUST NOT clause to `general-research-agent.md` Critical Requirements (after existing item 6)
- [ ] Add phase containment MUST DO clause to `general-research-agent.md` (record recommendations in report or handoff)
- [ ] Add phase containment MUST NOT clause to `general-implementation-agent.md` Critical Requirements (after existing item 5)
- [ ] Add phase containment MUST DO clause to `general-implementation-agent.md`
- [ ] Add phase containment MUST NOT clause to `planner-agent.md` Critical Requirements (after existing item 6)
- [ ] Add phase containment MUST DO clause to `planner-agent.md`
- [ ] Add phase containment MUST NOT clause to `reviser-agent.md` Critical Requirements
- [ ] Add phase containment MUST DO clause to `reviser-agent.md`
- [ ] Add phase containment MUST NOT clause to `neovim-research-agent.md` Critical Requirements
- [ ] Add phase containment MUST DO clause to `neovim-research-agent.md`
- [ ] Add phase containment MUST NOT clause to `neovim-implementation-agent.md` Critical Requirements
- [ ] Add phase containment MUST DO clause to `neovim-implementation-agent.md`
- [ ] Add phase containment MUST NOT clause to `nix-research-agent.md` Critical Requirements
- [ ] Add phase containment MUST DO clause to `nix-research-agent.md`
- [ ] Add phase containment MUST NOT clause to `nix-implementation-agent.md` Critical Requirements
- [ ] Add phase containment MUST DO clause to `nix-implementation-agent.md`
- [ ] Add phase containment MUST NOT clause to `spawn-agent.md` Critical Requirements
- [ ] Add phase containment MUST DO clause to `spawn-agent.md`

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-research-agent.md` - Add MUST NOT item 7 and MUST DO item 8
- `.claude/agents/general-implementation-agent.md` - Add MUST NOT item 6 and MUST DO item 9
- `.claude/agents/planner-agent.md` - Add MUST NOT item 7 and MUST DO item 8
- `.claude/agents/reviser-agent.md` - Add MUST NOT items and MUST DO items
- `.claude/agents/neovim-research-agent.md` - Add MUST NOT and MUST DO items
- `.claude/agents/neovim-implementation-agent.md` - Add MUST NOT and MUST DO items
- `.claude/agents/nix-research-agent.md` - Add MUST NOT and MUST DO items
- `.claude/agents/nix-implementation-agent.md` - Add MUST NOT and MUST DO items
- `.claude/agents/spawn-agent.md` - Add MUST NOT and MUST DO items

**Verification**:
- Grep all 9 agent files for "phase_constraint" to confirm the clause was added
- Verify MUST NOT and MUST DO numbering is sequential and does not skip or duplicate

**Standard clause text** (adapt to each agent's existing numbering):

MUST NOT addition:
```
N. Spawn child agents for lifecycle phases other than the assigned phase_constraint
   (when phase_constraint is present in delegation context). Research agents must not
   spawn planners or implementers; implementation agents must not spawn researchers
   or planners; planners must not spawn implementers or researchers.
```

MUST DO addition:
```
N. Record cross-phase recommendations in the report's Recommendations section or
   the handoff's phase_recommendations array when phase_constraint is present,
   rather than executing the work directly.
```

---

### Phase 4: Verification and Consistency Check [COMPLETED]

**Goal**: Validate all changes are internally consistent and no dispatch sites were missed.

**Tasks**:
- [ ] Run `grep -c "phase_constraint" .claude/skills/skill-orchestrate/SKILL.md` and verify count matches expected 11 sites
- [ ] Run `grep -l "phase_constraint" .claude/agents/*.md` and verify all 9 agents are listed
- [ ] Run `grep -c "phase_recommendations" .claude/docs/architecture/handoff-schema.md` and verify non-zero
- [ ] Run `grep -c "phase_constraint" .claude/docs/architecture/dispatch-agent-spec.md` and verify non-zero
- [ ] Verify that blocker escalation fork context includes `phase_constraint: "research"` (not implement)
- [ ] Verify that drift reviser context includes `phase_constraint: "revise"` (not plan)
- [ ] Spot-check that `orchestrator_mode` is NOT renamed or conflated with `phase_constraint` in any file

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (verification only)

**Verification**:
- All grep counts match expectations
- No dispatch context in SKILL.md has `orchestrator_mode` without also having `phase_constraint`

## Testing & Validation

- [ ] Grep all dispatch context construction sites in SKILL.md for `phase_constraint` -- count should be 11
- [ ] Grep all agent definitions for phase containment MUST NOT clause -- count should be 9 agents
- [ ] Verify handoff-schema.md includes `phase_recommendations` in schema and field definitions
- [ ] Verify dispatch-agent-spec.md decision matrix has `phase_constraint` column
- [ ] Verify no file uses `orchestrator_mode` as a substitute for `phase_constraint`
- [ ] Verify phase_constraint is absent from non-orchestrated dispatch paths (backward compatibility)

## Artifacts & Outputs

- plans/01_phase-containment.md (this plan)
- Modified `.claude/skills/skill-orchestrate/SKILL.md` (11 dispatch context sites)
- Modified `.claude/docs/architecture/dispatch-agent-spec.md` (parameter docs + decision matrix)
- Modified `.claude/docs/architecture/handoff-schema.md` (phase_recommendations field)
- Modified 9 agent definition files (MUST NOT/MUST DO clauses)

## Rollback/Contingency

All changes are additive (new JSON fields, new MUST NOT/MUST DO list items, new schema fields). Rollback involves reverting the commit. No destructive changes to existing behavior -- `phase_constraint` is only checked when present; its absence preserves current behavior.
