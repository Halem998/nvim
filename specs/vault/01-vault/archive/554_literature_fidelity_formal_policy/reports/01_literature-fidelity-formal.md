# Research Report: Task #554

**Task**: 554 - Create literature fidelity policy for Formal extension
**Started**: 2026-05-12T16:27:01Z
**Completed**: 2026-05-12T16:35:00Z
**Effort**: 1 hour
**Dependencies**: None (task 553 is a sibling, not a dependency)
**Sources/Inputs**: Codebase exploration of formal extension, Lean extension cross-reference
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The formal extension has 4 research agents (formal, logic, math, physics) but NO implementation agents -- all implementation falls back to `general-implementation-agent`, which has zero formal domain awareness
- The existing `proof-construction.md` workflow document has a "Choose Strategy" section with no mention of literature-guided proof following
- The Lean extension's `proof-conventions-lean.md` and `proof-debt-policy.md` provide the formatting pattern for the new policy document
- The formal extension's `index-entries.json` currently loads standards only for research agents (`logic-research-agent`, `formal-research-agent`) -- the new policy must also target implementation agents (which means `general-implementation-agent` since no formal-specific one exists)
- The policy must cover three domains (logic, math, physics) without Lean-specific tactic references, replacing them with domain-appropriate anti-patterns

## Context & Scope

This research examines the formal extension to determine:
1. Current structure and gaps relevant to a literature fidelity policy
2. How the policy should differ from the Lean-specific version (task 553)
3. How to integrate the policy into the formal extension's context loading system
4. What anti-patterns are appropriate for formal/logic/math/physics domains

## Findings

### 1. Formal Extension Structure

**Manifest** (`formal/manifest.json`):
- Task type: `formal` with sub-routes `formal:logic`, `formal:math`, `formal:physics`
- Dependencies: `["core"]`
- Provides 4 agents (all research-only), 4 skills (all research-only)
- Routing for `plan` and `implement` goes to generic `skill-planner` and `skill-implementer`

**Critical gap**: There are NO formal-specific implementation agents. All formal implementation tasks are handled by `general-implementation-agent`, which:
- Has no formal domain context references
- Has no proof construction guidance
- Has no literature fidelity awareness
- Treats all tasks identically (meta, general, markdown)

This means the literature fidelity policy, once created, will need to be loaded for `general-implementation-agent` when working on formal tasks. The `index-entries.json` must use a `load_when` that includes both the research agents AND the general implementation fallback.

**Agents** (all research-only):
- `formal-research-agent.md`: Coordinator, routes to specialists by domain keywords
- `logic-research-agent.md`: Modal/temporal logic, Kripke semantics specialist
- `math-research-agent.md`: Algebra, lattice theory, topology, category theory specialist
- `physics-research-agent.md`: Dynamical systems, chaos theory specialist

### 2. Existing Standards and Processes

**`proof-conventions.md`** (logic standards):
- Proof structure template with Lean 4 syntax examples
- Style guidelines (step comments, `have` statements, hypothesis naming)
- Axiom application patterns, inference rules
- Common pitfalls (necessitation on assumptions, confusing |- and |=)
- No mention of literature sources or literature-guided proof construction

**`proof-construction.md`** (logic processes):
- 4-phase workflow: Sketch -> Formalization -> Detail -> Verification
- "Choose Strategy" section lists: Direct, Indirect, Induction, Case analysis
- No "Follow the reference" strategy option
- References Lean 4 proof tactics (intro, apply, exact, have, simp, cases)
- Task 555 will add literature-first guidance here, but the standalone policy (task 554) provides the authoritative rules

**`verification-workflow.md`** (logic processes):
- 4-stage workflow: Specification -> Implementation -> Verification -> Review
- Property types: Safety, Liveness, Fairness
- Lean 4 verification (type checking, tactic verification)
- No literature reference tracking

### 3. Index-Entries.json Analysis

Current `formal/index-entries.json` contains 40 entries across 3 subdomains:
- **Logic** (19 entries): domain knowledge, processes, standards
- **Math** (15 entries): algebra, lattice theory, order theory, topology, category theory, foundations
- **Physics** (2 entries): dynamical systems

**Loading patterns observed**:
- Standards files load for `logic-research-agent` and `formal-research-agent`
- NO entries target implementation agents (because none exist in the formal extension)
- The `load_when` uses `agents` and `languages` arrays

**For the new policy entry**, the `load_when` should include:
- `agents`: All 4 research agents PLUS a wildcard or note about `general-implementation-agent`
- `languages`: `["logic", "math", "physics", "formal"]`
- `topics`: `["literature", "fidelity", "proof", "source"]`

**Challenge**: The `general-implementation-agent` is a core agent, not a formal extension agent. The formal `index-entries.json` entries are merged into the main `context/index.json` by the extension loader, so adding `general-implementation-agent` to the agents list should work if the agent queries the merged index. However, this would cause the policy to load for ALL general implementation tasks, not just formal ones. The `languages` field should restrict this -- the policy loads only when both the agent matches AND the language matches.

### 4. Differences from Lean Policy (Task 553)

The Lean literature fidelity policy (task 553, not yet created) will be Lean-specific:
- References Lean tactics (`simp`, `omega`, `aesop`, `lean_multi_attempt`)
- References Lean MCP tools (lean_goal, lean_state_search)
- References Lean build system (`lake build`)
- Anti-patterns involve Lean-specific automation shortcuts

The formal extension policy must be **domain-general** across logic, math, and physics:

| Aspect | Lean Policy | Formal Policy |
|--------|-------------|---------------|
| Scope | Lean 4 proof assistant | Logic, math, physics formal reasoning |
| Tactics | simp, omega, aesop, exact, etc. | Abstract proof strategies (direct, indirect, induction) |
| Tools | lean_multi_attempt, lean_goal | General codebase tools (Read, Write, Grep) |
| Anti-patterns | "Try simp/omega instead of following literature" | "Skip proof steps", "attempt novel arguments", "use overly generic automation" |
| Verification | `lake build`, `lean_verify` | Peer review, manual verification, proof checking |
| Build | lake build | Varies by project (may include lake build if formal proofs in Lean) |

### 5. Recommended Policy Structure

The policy should be placed at: `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md`

**Recommended sections** (adapted from task 553's description):

```
# Literature Fidelity Policy

## Overview
When and how to follow provided literature vs. derive from first principles.

## Two Modes

### Mode 1: Literature-Guided (when source provided)
- Follow the source's proof/argument structure step-by-step
- Translate each step faithfully into the target formalism
- Do not seek shortcuts even when the argument is hard
- Document which literature step each formal step corresponds to

### Mode 2: First-Principles (default when no source)
- Use standard proof strategies freely
- Choose approach based on proof-construction.md workflow
- Apply automation and exploration as normal

## Activation Criteria
How to determine which mode applies:
- Task description references a paper, textbook, or notes
- Plan phases are labeled with literature section/theorem numbers
- Research report documents a proof structure from a source

## Step Translation Protocol
For each literature step:
1. Identify the mathematical claim
2. Determine the formal encoding
3. Construct the proof of that step
4. If the step does not translate cleanly -> escalation

## Escalation Protocol
When a literature step does not translate cleanly:
1. Re-read the source for implicit assumptions
2. Try alternative encodings of the same mathematical claim
3. Check if the source relies on unstated lemmas
4. Document the gap precisely
5. Ask the user rather than improvising

## Anti-Pattern Catalog

### Anti-Pattern 1: Skipping Steps
WRONG: Omitting difficult intermediate steps from the literature
RIGHT: Translate every step, even hard ones

### Anti-Pattern 2: Novel Arguments
WRONG: Inventing a different proof when the literature's approach is the standard one
RIGHT: Follow the literature's approach, which is standard for a reason

### Anti-Pattern 3: Premature Automation
WRONG: Using broad automation to bypass steps the literature handles explicitly
RIGHT: Only automate what the literature treats as trivial/routine

### Anti-Pattern 4: Abandoning After First Failure
WRONG: Switching to a novel approach after a single encoding attempt fails
RIGHT: Try multiple faithful encodings before considering deviation

### Anti-Pattern 5: Mixing Strategies Without Flagging
WRONG: Silently combining literature steps with novel steps
RIGHT: Explicitly document any deviation from the literature

## Domain-Specific Guidance

### Logic
- Modal logic proofs: Follow the literature's frame conditions and accessibility relations exactly
- Completeness proofs: Use the literature's canonical model construction, not an alternative
- Soundness proofs: Follow the literature's induction structure on derivation length or formula complexity

### Mathematics
- Algebraic proofs: Follow the literature's lemma decomposition, do not merge steps
- Topological arguments: Preserve the literature's choice of open/closed set characterization
- Category-theoretic proofs: Follow the literature's diagram exactly, do not factor through different objects

### Physics
- Dynamical systems: Follow the literature's iteration/orbit construction precisely
- Fixed point arguments: Use the literature's contraction/continuity conditions, not alternatives

## Interaction with Existing Processes
- proof-construction.md "Choose Strategy" section: When literature is provided, the strategy IS "follow the reference"
- verification-workflow.md: Verification should check correspondence to literature steps
- proof-conventions.md: Literature step annotations join the existing docstring requirements

## Success Criteria
- [ ] Every formal step has a documented correspondence to a literature step
- [ ] No steps were skipped or merged without documentation
- [ ] No novel arguments were introduced without flagging
- [ ] Escalation protocol was followed for any gaps
- [ ] Deviations from literature are explicitly documented
```

### 6. Index-Entries.json Integration

New entry to add to `formal/index-entries.json`:

```json
{
  "path": "project/logic/standards/literature-fidelity-policy.md",
  "summary": "Policy for following provided literature sources in formal proofs",
  "category": "standards",
  "line_count": 150,
  "load_when": {
    "agents": [
      "logic-research-agent",
      "formal-research-agent",
      "math-research-agent",
      "physics-research-agent",
      "general-implementation-agent"
    ],
    "languages": [
      "logic",
      "math",
      "physics",
      "formal"
    ],
    "topics": [
      "literature",
      "fidelity",
      "proof",
      "source",
      "reference"
    ]
  },
  "domain": "project",
  "subdomain": "logic"
}
```

**Note on `general-implementation-agent` inclusion**: Since formal tasks fall back to this generic agent, including it in the `load_when.agents` array ensures the policy loads during formal implementation. The `languages` filter prevents it from loading for non-formal tasks. This is the correct approach given the current architecture where no formal-specific implementation agent exists.

## Decisions

1. **File location**: `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` -- placed in the logic standards directory because the formal extension's standards live under `project/logic/standards/`, and this policy applies across all formal domains
2. **Include domain-specific sections**: The policy should have brief domain-specific guidance sections for logic, math, and physics rather than being purely abstract
3. **Include `general-implementation-agent` in load targets**: Despite being a core agent, it must receive this context since it handles all formal implementations
4. **No Lean-specific references**: The formal policy should NOT reference Lean tactics, MCP tools, or `lake build` -- those belong in the Lean extension's version (task 553)
5. **Anti-patterns should be abstract**: Instead of "try simp/omega/aesop instead", use "use broad automation to bypass explicit steps", "skip difficult intermediate arguments", "invent alternative proofs when the literature's approach is standard"

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `general-implementation-agent` ignores the policy even when loaded | High - defeats the purpose | Task 556 adds literature awareness to planner-agent, which structures plans with literature references; the plan itself becomes the enforcement mechanism |
| Policy is too abstract without Lean-specific guidance | Medium - agents may not apply it concretely | Include concrete domain-specific examples (logic: canonical model construction; math: lemma decomposition; physics: orbit construction) |
| Policy conflicts with existing proof-construction.md "Choose Strategy" | Low - but could confuse agents | Task 555 will modify proof-construction.md to add literature-first strategy; the standalone policy references this interaction |
| No formal-specific implementation agent means weak enforcement | High - generic agent may not check literature | Document as a known architectural gap; future work could create `formal-implementation-agent` |

## Context Extension Recommendations

- **Topic**: Formal implementation agent
- **Gap**: The formal extension has no implementation agent; all implementation falls through to `general-implementation-agent` which has no formal domain awareness
- **Recommendation**: Consider creating a `formal-implementation-agent.md` (or at minimum a formal auto-applied rule similar to `lean4.md`) that enforces formal proof standards during implementation

## Appendix

### Files Examined
- `.claude/extensions/formal/manifest.json` - Extension manifest
- `.claude/extensions/formal/index-entries.json` - 40 context index entries
- `.claude/extensions/formal/agents/formal-research-agent.md` - Coordinator agent
- `.claude/extensions/formal/agents/logic-research-agent.md` - Logic specialist
- `.claude/extensions/formal/agents/math-research-agent.md` - Math specialist
- `.claude/extensions/formal/agents/physics-research-agent.md` - Physics specialist
- `.claude/extensions/formal/context/project/logic/standards/proof-conventions.md` - Proof style conventions
- `.claude/extensions/formal/context/project/logic/processes/proof-construction.md` - Proof workflow
- `.claude/extensions/formal/context/project/logic/processes/verification-workflow.md` - Verification workflow
- `.claude/agents/general-implementation-agent.md` - Fallback implementation agent
- `.claude/extensions/lean/context/project/lean4/standards/proof-conventions-lean.md` - Lean proof conventions (pattern reference)
- `.claude/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` - Lean proof debt policy (pattern reference)
- `.claude/extensions/lean/index-entries.json` - Lean context index (pattern reference)

### Cross-Reference with Related Tasks
- **Task 553** (sibling): Creates the Lean-specific literature fidelity policy; the formal policy should follow the same structural pattern but with domain-general content
- **Task 555** (depends on 553): Will modify `proof-construction.md` to add literature-first strategy; the formal policy anticipates this change
- **Task 556** (depends on 553): Will add literature awareness to planner-agent and research agents; the formal policy is complementary
