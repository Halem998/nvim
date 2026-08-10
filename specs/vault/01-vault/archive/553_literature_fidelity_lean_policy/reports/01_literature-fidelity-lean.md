# Research Report: Task #553

- **Task**: 553 - Create literature fidelity policy for Lean extension
- **Started**: 2026-05-12T09:00:00Z
- **Completed**: 2026-05-12T09:15:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: Lean extension standards, agents, workflows, rules, index
  - Codebase: Formal extension standards and processes (cross-reference)
  - Codebase: Core planner-agent.md
- **Artifacts**: specs/553_literature_fidelity_lean_policy/reports/01_literature-fidelity-lean.md
- **Standards**: report-format.md, status-markers.md, artifact-management.md

## Executive Summary

- The Lean extension currently has ZERO references to "literature", "textbook", "paper", "reference material", or "first principles" anywhere in its agents, standards, workflows, or rules
- The proof development loop in lean-implementation-flow.md jumps straight to tactic exploration and MCP search without any step to consult provided literature sources
- The end-to-end-proof-workflow.md "Outline the Proof" step lacks any instruction to follow a literature source's structure when one is available
- Existing standards documents (proof-conventions-lean.md, proof-debt-policy.md) establish a clear pattern: Overview, categorized rules, forbidden patterns, escalation paths, usage checklist
- The new policy should be loaded for lean-implementation-agent (primary consumer) and lean-research-agent (to extract proof structure from literature during research phase)
- The formal extension has the same gap -- its proof-construction.md "Choose Strategy" section lists direct/indirect/induction but never "follow the reference proof"

## Context & Scope

This research examines all Lean extension documents to understand where literature-following guidance is currently absent and how a new policy document should be structured to fill the gap. The user reports repeatedly needing to remind agents to follow provided literature step-by-step rather than deriving proofs from first principles.

## Findings

### 1. Existing Lean Standards Document Patterns

The two existing standards in `lean/context/project/lean4/standards/` establish a clear format:

**proof-conventions-lean.md** (56 lines):
- Overview section (1 sentence)
- Categorized guidelines: Docstrings, Naming, Tactic Hygiene, Readability, Sorry Policy, Tests
- Cross-References section linking to related docs
- Usage Checklist with checkbox items

**proof-debt-policy.md** (134 lines):
- Overview section defining scope
- Completion Gates with MANDATORY markers and hard requirements
- Forbidden Patterns with code examples showing what NOT to do
- Categories (Sorry categories, Axiom categories)
- Remediation Paths
- Usage Checklist

The proof-debt-policy.md is the closer structural match for the literature fidelity policy since it also defines forbidden patterns, escalation paths, and has a strong prescriptive tone with MANDATORY markers.

### 2. Places Where Agents Currently Bypass Literature

**lean-implementation-agent.md** (269 lines):
- "When Stuck" section (not in agent, but in lean-implementation-flow.md) only lists: lean_state_search, lean_hammer_premise, lean_local_search, return partial
- "Critical Requirements" MUST DO list has 11 items -- none mention consulting literature
- "Critical Requirements" MUST NOT list has 12 items -- none forbid ignoring literature
- No concept of "literature-guided mode" vs "first-principles mode" exists

**lean-implementation-flow.md** (173 lines):
- Stage 4B proof development loop: Read file -> lean_goal -> try tactics -> lean_multi_attempt -> lean_state_search/lean_hammer_premise -> return partial
- NO step to check for literature source before entering the loop
- NO step to translate literature steps into Lean tactics
- "Tactic Selection Strategy" goes straight to: Start Simple -> Structural -> Application -> Automation

**end-to-end-proof-workflow.md** (50 lines):
- Step 2 "Outline the Proof" says: "Write a high-level outline of the proof in comments"
- Does NOT say: "If a literature source is provided, follow its proof structure"
- Step 3 "Fill in the Proof" says: "Fill in the proof using tactics and term-mode proofs"
- No mention of translating literature steps faithfully

**lean4.md auto-applied rule** (55 lines):
- Applied to every `*.lean` file edit
- Contains: Blocked tools, Essential tools, Search tools, Workflow Pattern, Common Tactics, Build Commands
- ZERO mention of literature, reference materials, or source following
- This is the most impactful place for a reminder since it fires on every Lean file edit

**lean-research-agent.md** (185 lines):
- Has a "Research Constraints for Lean Tasks" section (about zero-debt policy)
- Does NOT have a corresponding section about extracting proof structure from literature
- "Search Decision Tree" only lists MCP search tools, not "check provided literature first"

**planner-agent.md** (366 lines):
- Stage 4 "Decompose into Phases" has no instruction to mirror literature proof structure for formal tasks
- No concept of "literature-mirroring decomposition" where plan phases correspond to literature proof steps

### 3. Formal Extension Cross-Reference

**proof-construction.md** (143 lines):
- Section "3. Choose Strategy" lists: Direct proof, Forward/backward reasoning, Induction, Case analysis
- Does NOT list: "Follow the reference proof" as a strategy option
- This is the most natural insertion point for literature-first strategy in the formal extension

**proof-conventions.md** (129 lines):
- Covers style, documentation, axiom application, inference rules
- No mention of literature fidelity

### 4. Index Integration Pattern

**lean/index-entries.json** shows consistent patterns:
- Standards entries load for `lean-implementation-agent` (proof-conventions-lean.md, proof-debt-policy.md, lean4-style-guide.md, proof-readability-criteria.md)
- The new literature fidelity policy should follow the same pattern
- It should also load for `lean-research-agent` since the research phase should extract proof structure from literature

**Recommended index entry**:
```json
{
  "path": "project/lean4/standards/literature-fidelity-policy.md",
  "description": "Policy for following literature sources vs. deriving from first principles",
  "tags": ["lean4", "literature", "fidelity", "policy"],
  "load_when": {
    "languages": ["lean4"],
    "agents": ["lean-implementation-agent", "lean-research-agent"]
  },
  "domain": "project",
  "subdomain": "lean",
  "summary": "When to follow provided literature step-by-step vs. derive from first principles"
}
```

### 5. Grep Confirmation: Zero Literature References in Lean Extension

A comprehensive grep across the entire Lean extension for keywords "literature", "textbook", "paper", "reference material", "source material", "first principles", and "from scratch" returned zero results. The formal extension only uses "literature" in the context of searching for external documentation (math-research-agent, logic-research-agent, physics-research-agent), never in the context of "follow the literature's proof structure."

## Decisions

- The new policy document will follow the proof-debt-policy.md structural pattern as it is the closest analog (prescriptive policy with forbidden patterns and escalation)
- The policy defines two explicit modes rather than a continuous spectrum, because the user's problem is binary: agents either have literature or they don't, and when they do, they ignore it
- The anti-pattern catalog should use concrete examples showing what agents actually do wrong (jumping to simp/omega, seeking shortcuts, abandoning after one failure)
- The escalation protocol should be structured as a decision tree, not a list, for faster agent navigation

## Recommendations

### Recommended Document Structure

```markdown
# Literature Fidelity Policy

## Overview
One-paragraph scope definition: when this policy applies, who it applies to.

## Mode Detection
How to determine which mode applies:
- Literature-Guided Mode: activated when...
- First-Principles Mode: default when...

## Literature-Guided Mode

### Core Principle
Follow the source step-by-step. Do not seek shortcuts.

### Source Identification
How to identify what counts as a literature source (papers, textbooks, notes
provided in task description, research reports, plan attachments).

### Translation Protocol
Step-by-step process for translating literature proof steps into Lean:
1. Read the literature step
2. Identify the mathematical claim
3. Find corresponding Lean type/lemma
4. If exact match, apply directly
5. If encoding differs, find equivalent formulation
6. If no equivalent, escalate (do not skip)

### Deviation Handling
What to do when deviating from literature is necessary:
- Document the deviation explicitly
- Flag it to the user
- Never silently substitute a different approach

## Anti-Pattern Catalog

### FORBIDDEN: Shortcut-Seeking
"The proof is hard so I'll try simp/omega/aesop instead"
Why this is wrong: [explanation]
What to do instead: [instruction]

### FORBIDDEN: Easier-Route Substitution
"I'll find an easier approach" when the literature's approach is standard
Why this is wrong: [explanation]
What to do instead: [instruction]

### FORBIDDEN: Premature Abandonment
Abandoning the literature's strategy after a single failed tactic attempt
Why this is wrong: [explanation]
What to do instead: [instruction]

### FORBIDDEN: Silent Mixing
Mixing literature steps with novel steps without flagging the deviation
Why this is wrong: [explanation]
What to do instead: [instruction]

## Escalation Protocol

Decision tree for when stuck on a literature step:
1. Re-read the source carefully
2. Try alternative Lean encodings of the same mathematical step
3. Check if the step requires an intermediate lemma
4. Search for existing Lean formulations of the concept
5. After exhausting faithful translations, flag gap to user
6. NEVER skip the step and continue

## First-Principles Mode

When no literature is provided:
- Current behavior applies (tactic exploration, MCP search, automation)
- No restrictions beyond existing standards

## Usage Checklist
- [ ] Literature source identified (if provided)
- [ ] Mode correctly determined
- [ ] Each literature step translated faithfully (if literature-guided)
- [ ] No shortcuts taken over literature steps
- [ ] Deviations documented and flagged
- [ ] Escalation protocol followed when stuck
```

### Estimated Size

Based on the proof-debt-policy.md pattern (134 lines), the literature fidelity policy should be approximately 120-160 lines. The anti-pattern catalog with examples will be the longest section.

### Integration Points for Downstream Tasks

The following documents need updates (tasks 555 and 556) to reference this policy:

1. **lean-implementation-flow.md**: Add "Stage 1.5: Check for Literature Source" between Stage 1 (Parse Delegation) and Stage 2 (Load Plan)
2. **end-to-end-proof-workflow.md**: Add "Step 0: Check for Literature Source" before Step 1
3. **proof-construction.md** (formal): Add "Follow the reference proof" to "Choose Strategy"
4. **lean4.md auto-applied rule**: Add "Literature Fidelity" section reminding agents to check for literature
5. **lean-research-agent.md**: Add section about extracting proof structure from provided literature
6. **planner-agent.md**: Add guidance about mirroring literature proof structure in plan phases for formal/lean tasks
7. **lean/index-entries.json**: Add entry for the new policy document

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Policy too verbose, agents skip it | H | M | Keep under 160 lines, front-load key rules |
| Agents still ignore policy because it's only in context, not in agent definition | H | M | Tasks 555-556 will add direct references in agent files and auto-applied rule |
| Overly strict policy blocks agents from using automation even when appropriate | M | L | Clear "First-Principles Mode" section preserves existing freedom when no literature exists |
| Policy conflicts with existing proof-debt-policy | L | L | Policies are complementary: debt policy says "no sorries", fidelity policy says "follow the source" |

## Appendix

### Files Examined

- `.claude/extensions/lean/context/project/lean4/standards/proof-conventions-lean.md` (56 lines)
- `.claude/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` (134 lines)
- `.claude/extensions/lean/agents/lean-implementation-agent.md` (269 lines)
- `.claude/extensions/lean/agents/lean-research-agent.md` (185 lines)
- `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (173 lines)
- `.claude/extensions/lean/context/project/lean4/processes/end-to-end-proof-workflow.md` (50 lines)
- `.claude/extensions/lean/rules/lean4.md` (55 lines)
- `.claude/extensions/lean/index-entries.json` (533 lines)
- `.claude/extensions/formal/context/project/logic/standards/proof-conventions.md` (129 lines)
- `.claude/extensions/formal/context/project/logic/processes/proof-construction.md` (143 lines)
- `.claude/extensions/formal/index-entries.json` (1050 lines)
- `.claude/agents/planner-agent.md` (366 lines)

### Grep Queries
- `grep -rn "literature|textbook|paper|reference material|source material|first principles|from scratch"` across lean extension, formal extension, and core agents
