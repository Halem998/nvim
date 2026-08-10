# Implementation Plan: Task #554

- **Task**: 554 - Create literature fidelity policy for Formal extension
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/554_literature_fidelity_formal_policy/reports/01_literature-fidelity-formal.md
- **Artifacts**: plans/01_literature-fidelity-formal.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a literature fidelity policy document for the formal extension that defines when and how agents should follow provided literature sources versus deriving from first principles. The policy covers three domains (logic, math, physics) and includes an escalation protocol, anti-pattern catalog, and domain-specific guidance. After creating the document, update the formal extension's index-entries.json to ensure the policy is loaded for all 4 research agents plus general-implementation-agent (the fallback for formal implementation tasks).

### Research Integration

The research report (01_literature-fidelity-formal.md) identified:
- The formal extension has 4 research agents but NO implementation agents; all implementation falls back to general-implementation-agent
- Existing proof-construction.md has a "Choose Strategy" section with no mention of literature-guided proof following
- The policy must target general-implementation-agent in its load_when since no formal-specific implementation agent exists
- The languages filter (logic, math, physics, formal) prevents the policy from loading for non-formal tasks even when general-implementation-agent is in the agents list
- Five anti-patterns recommended: skipping steps, novel arguments, premature automation, abandoning after first failure, mixing strategies without flagging
- Domain-specific guidance sections for logic (canonical models, induction structure), math (lemma decomposition, diagram following), physics (orbit construction, fixed points)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create a comprehensive literature fidelity policy at `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md`
- Define two operating modes: literature-guided and first-principles
- Include escalation protocol for when literature steps do not translate cleanly
- Provide 5 anti-patterns with correct/incorrect examples
- Include domain-specific guidance for logic, math, and physics
- Integrate the policy into the formal extension's context loading via index-entries.json

**Non-Goals**:
- Modifying proof-construction.md to add literature-first strategy (that is task 555)
- Adding literature awareness to planner-agent or research agents (that is task 556)
- Creating a formal-specific implementation agent (future work)
- Including Lean-specific tactic references (those belong in the Lean extension policy, task 553)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| general-implementation-agent ignores the policy even when loaded | Medium | Medium | The languages filter ensures it only loads for formal tasks; task 556 will add complementary enforcement to planner-agent |
| Policy is too abstract without tool-specific guidance | Medium | Low | Include concrete domain-specific examples (canonical model construction, lemma decomposition, orbit construction) |
| Policy conflicts with existing proof-construction.md strategies | Low | Low | Document the interaction explicitly in the policy; task 555 will harmonize proof-construction.md |
| Index entry loads for unrelated general implementation tasks | Low | Low | Use languages filter (logic, math, physics, formal) to restrict loading scope |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Literature Fidelity Policy Document [COMPLETED]

**Goal**: Create the complete literature-fidelity-policy.md document with all sections defined in the research report.

**Tasks**:
- [x] Create the policy file at `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` *(completed: 257 lines)*
- [x] Write the Overview section explaining the policy's purpose and scope *(completed)*
- [x] Write the Two Modes section (Literature-Guided and First-Principles) *(completed)*
- [x] Write the Activation Criteria section defining how to determine which mode applies *(completed)*
- [x] Write the Step Translation Protocol for faithful literature step-by-step translation *(completed)*
- [x] Write the Escalation Protocol for handling steps that do not translate cleanly (re-read source, try alternative encodings, check for unstated lemmas, document gap, ask user) *(completed)*
- [x] Write the Anti-Pattern Catalog with 5 anti-patterns: (1) Skipping Steps, (2) Novel Arguments, (3) Premature Automation, (4) Abandoning After First Failure, (5) Mixing Strategies Without Flagging *(completed)*
- [x] Write the Domain-Specific Guidance section with subsections for Logic (frame conditions, canonical models, induction structure), Mathematics (lemma decomposition, topological characterizations, diagram following), and Physics (orbit construction, fixed point arguments) *(completed)*
- [x] Write the Interaction with Existing Processes section referencing proof-construction.md, verification-workflow.md, and proof-conventions.md *(completed)*
- [x] Write the Success Criteria checklist *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` - New file (create)

**Verification**:
- File exists at the specified path
- Contains all required sections: Overview, Two Modes, Activation Criteria, Step Translation Protocol, Escalation Protocol, Anti-Pattern Catalog (5 items), Domain-Specific Guidance (3 domains), Interaction with Existing Processes, Success Criteria
- No Lean-specific tactic references (simp, omega, aesop, lake build)
- No references to Lean MCP tools (lean_goal, lean_multi_attempt, lean_state_search)
- Domain-specific examples are concrete and actionable

---

### Phase 2: Update Index-Entries.json [COMPLETED]

**Goal**: Add the new literature-fidelity-policy.md to the formal extension's index-entries.json so it loads for the correct agents and task types.

**Tasks**:
- [x] Read current `formal/index-entries.json` to identify insertion point *(completed)*
- [x] Add new entry with path `project/logic/standards/literature-fidelity-policy.md` *(completed)*
- [x] Set load_when.agents to all 4 research agents plus general-implementation-agent: `["logic-research-agent", "formal-research-agent", "math-research-agent", "physics-research-agent", "general-implementation-agent"]` *(completed)*
- [x] Set load_when.languages to `["logic", "math", "physics", "formal"]` *(completed)*
- [x] Set load_when.topics to `["literature", "fidelity", "proof", "source", "reference"]` *(completed)*
- [x] Set category to `"standards"`, domain to `"project"`, subdomain to `"logic"` *(completed)*
- [x] Set line_count to match the actual line count of the created file *(completed: 257 lines)*
- [x] Verify the JSON is valid after editing *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/formal/index-entries.json` - Add new entry for literature-fidelity-policy.md

**Verification**:
- JSON is valid (no parse errors)
- New entry exists with correct path, agents, languages, and topics
- general-implementation-agent is included in agents list
- All 4 research agents are included
- Languages include all 3 domains plus "formal"

## Testing & Validation

- [x] Literature-fidelity-policy.md file exists at `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md`
- [x] Policy contains Two Modes, Escalation Protocol, Anti-Pattern Catalog (5 items), Domain-Specific Guidance (3 domains)
- [x] No Lean-specific references in the formal policy
- [x] Index-entries.json is valid JSON after modification
- [x] New index entry targets all 4 research agents and general-implementation-agent
- [x] Languages filter covers logic, math, physics, formal

## Artifacts & Outputs

- `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` - The literature fidelity policy document
- `.claude/extensions/formal/index-entries.json` - Updated with new entry for the policy

## Rollback/Contingency

Both changes are additive (new file creation and new JSON entry). Rollback requires:
1. Delete `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md`
2. Remove the added entry from `.claude/extensions/formal/index-entries.json`
3. Git revert the commit if needed
