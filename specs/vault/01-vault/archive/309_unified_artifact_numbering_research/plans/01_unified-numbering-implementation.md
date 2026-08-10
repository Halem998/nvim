# Implementation Plan: Task #309

- **Task**: 309 - unified_artifact_numbering_research
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/309_unified_artifact_numbering_research/reports/01_unified-numbering-research.md
- **Artifacts**: plans/01_unified-numbering-implementation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement unified artifact numbering across the agent system, where all artifact types (reports, plans, summaries) share a single sequence number per task. Research drives sequence advancement while plan and summary inherit the current research number. This ensures artifacts created in the same "round" share the same sequence number (e.g., 01_report -> 01_plan -> 01_summary).

### Research Integration

Key findings from 01_unified-numbering-research.md:
- Add `next_artifact_number` field to task entries in state.json (initial value: 1)
- Research increments the field after use; plan/summary use (current - 1)
- Backward compatibility via directory scanning when field is missing
- 10 files need updates across documentation, skills, and agents
- Delegation context extended with `artifact_number` field

## Goals & Non-Goals

**Goals**:
- Unified artifact numbering where research, plan, and summary share the same sequence number within a round
- Research operations advance the sequence; plan/summary reuse the current number
- Backward compatibility for existing tasks without the new field
- Clear delegation of artifact number from skills to agents

**Non-Goals**:
- Changing existing artifact file names (historical artifacts remain unchanged)
- Complex migration of existing task state (scanning fallback handles legacy tasks)
- Per-type sequence tracking (rejected in research as overly complex)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backward compat issues | H | M | Scanning fallback + verify with existing tasks |
| Off-by-one errors in numbering | M | M | Clear documentation of "use then increment" vs "current-1" semantics |
| Spawn agent hardcoded value | H | H | Explicit update in Phase 3 |
| Skills passing wrong number | M | L | Unit test skill logic before agent updates |

## Implementation Phases

### Phase 1: Documentation Updates [NOT STARTED]

**Goal**: Establish the schema and rules for unified artifact numbering before code changes

**Tasks**:
- [ ] Update `.claude/context/reference/state-management-schema.md` to add `next_artifact_number` field documentation
- [ ] Update `.claude/rules/artifact-formats.md` to change from "Per-Type Sequential Numbering" to "Unified Sequential Numbering"

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - Add field schema, semantics, and examples
- `.claude/rules/artifact-formats.md` - Update numbering section to reflect unified approach

**Verification**:
- Documentation clearly explains the unified numbering semantics
- Research/plan/summary inheritance rules are explicit
- Backward compatibility via scanning is documented

---

### Phase 2: Skill Updates [NOT STARTED]

**Goal**: Update skills to read/write `next_artifact_number` and pass correct artifact number to agents

**Tasks**:
- [ ] Update `skill-researcher` to read `next_artifact_number`, pass to agent, then increment in postflight
- [ ] Update `skill-planner` to read `next_artifact_number`, calculate (current-1), pass to agent in delegation context
- [ ] Update `skill-implementer` to read `next_artifact_number`, calculate (current-1), pass to agent in delegation context

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add preflight read, delegation context extension, postflight increment
- `.claude/skills/skill-planner/SKILL.md` - Add preflight read (current-1), delegation context extension
- `.claude/skills/skill-implementer/SKILL.md` - Add preflight read (current-1), delegation context extension

**Verification**:
- Skills correctly extract `next_artifact_number` from state.json
- Research skill increments after use; plan/implement skills use (current-1)
- Delegation context includes `artifact_number` field
- Backward compatibility scanning logic is included when field is missing

---

### Phase 3: Agent Updates [NOT STARTED]

**Goal**: Update agents to use the artifact number passed via delegation context

**Tasks**:
- [ ] Update `general-research-agent.md` to use provided `artifact_number` in report path
- [ ] Update `planner-agent.md` to use provided `artifact_number` in plan path
- [ ] Update `general-implementation-agent.md` to use provided `artifact_number` in summary path
- [ ] Update `spawn-agent.md` to use provided `artifact_number` instead of hardcoded 02

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/general-research-agent.md` - Use `artifact_number` from delegation context
- `.claude/agents/planner-agent.md` - Use `artifact_number` from delegation context
- `.claude/agents/general-implementation-agent.md` - Use `artifact_number` from delegation context
- `.claude/agents/spawn-agent.md` - Remove hardcoded 02, use passed number

**Verification**:
- Agents extract `artifact_number` from delegation context
- Artifact paths use the passed number, not hardcoded or independently calculated
- Spawn agent no longer assumes first research is 01

---

### Phase 4: Command Updates [NOT STARTED]

**Goal**: Ensure /revise command maintains same-round semantics

**Tasks**:
- [ ] Update `.claude/commands/revise.md` to document that plan revision stays in same round
- [ ] Verify revise does not trigger artifact number changes

**Timing**: 15 minutes

**Files to modify**:
- `.claude/commands/revise.md` - Document same-round semantics for plan revisions

**Verification**:
- /revise documentation clarifies it creates a new plan version within the same artifact round
- No artifact number increment occurs during revision

---

### Phase 5: Verification and Testing [NOT STARTED]

**Goal**: Verify the complete flow works end-to-end

**Tasks**:
- [ ] Verify backward compatibility by checking existing tasks without `next_artifact_number`
- [ ] Trace through a hypothetical multi-round scenario to verify numbering logic
- [ ] Review all changes for consistency

**Timing**: 15 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- Existing tasks work correctly (scanning fallback)
- Multi-round scenario produces correct artifact numbers (01 -> 01 -> 01 -> 02 -> 02 -> 02)
- All documentation, skills, and agents are consistent

## Testing & Validation

- [ ] Existing tasks without `next_artifact_number` still work (backward compat)
- [ ] New task with /research creates 01_report and sets next_artifact_number=2
- [ ] Subsequent /plan uses 01_plan (not 02_plan)
- [ ] Subsequent /implement uses 01_summary (not 02_summary)
- [ ] After blocker, new /research creates 02_report and sets next_artifact_number=3
- [ ] /revise stays in same round (does not change artifact number)
- [ ] /spawn uses correct artifact number, not hardcoded 02

## Artifacts & Outputs

- `.claude/context/reference/state-management-schema.md` - Updated with `next_artifact_number` field
- `.claude/rules/artifact-formats.md` - Updated with unified numbering semantics
- `.claude/skills/skill-researcher/SKILL.md` - Updated with read/increment logic
- `.claude/skills/skill-planner/SKILL.md` - Updated with (current-1) logic
- `.claude/skills/skill-implementer/SKILL.md` - Updated with (current-1) logic
- `.claude/agents/general-research-agent.md` - Updated to use passed artifact number
- `.claude/agents/planner-agent.md` - Updated to use passed artifact number
- `.claude/agents/general-implementation-agent.md` - Updated to use passed artifact number
- `.claude/agents/spawn-agent.md` - Updated to use passed artifact number
- `.claude/commands/revise.md` - Updated with same-round semantics

## Rollback/Contingency

If unified numbering causes issues:
1. Revert skill changes (skills stop passing `artifact_number`)
2. Revert agent changes (agents resume independent numbering)
3. Remove `next_artifact_number` field from schema (optional, field can remain unused)
4. Existing artifacts remain unchanged - only new artifact naming affected
