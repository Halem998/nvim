# Implementation Plan: Task #553

- **Task**: 553 - Create literature fidelity policy for Lean extension
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/553_literature_fidelity_lean_policy/reports/01_literature-fidelity-lean.md
- **Artifacts**: plans/01_literature-fidelity-lean.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a standalone literature fidelity policy document for the Lean extension and register it in the context index. The policy defines two modes (literature-guided and first-principles), includes an anti-pattern catalog of four forbidden behaviors, and provides an escalation protocol for when literature steps resist direct Lean translation. The document follows the structural pattern established by proof-debt-policy.md (~120-160 lines, prescriptive tone, FORBIDDEN markers, usage checklist).

### Research Integration

The research report (01_literature-fidelity-lean.md) confirmed:
- Zero existing references to "literature", "textbook", "paper", or "first principles" anywhere in the Lean extension
- Six specific bypass points where agents skip literature (lean-implementation-flow.md tactic selection, end-to-end-proof-workflow.md outline step, lean4.md auto-applied rule, lean-implementation-agent.md MUST DO list, lean-research-agent.md search tree, planner-agent.md decomposition)
- proof-debt-policy.md (134 lines) is the closest structural analog with its FORBIDDEN patterns, completion gates, and escalation paths
- Recommended index entry with load_when for lean-implementation-agent and lean-research-agent

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation required.

## Goals & Non-Goals

**Goals**:
- Create the core literature fidelity policy document at the specified path
- Define clear mode detection logic (literature-guided vs. first-principles)
- Catalog four specific anti-patterns with FORBIDDEN markers
- Provide a structured escalation protocol as a decision tree
- Register the policy in lean/index-entries.json for the correct agents

**Non-Goals**:
- Modifying agent definitions or workflow documents (tasks 555, 556)
- Adding literature references to the auto-applied lean4.md rule (task 556)
- Creating the parallel formal extension policy (task 554)
- Changing any existing Lean extension behavior without literature present

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Policy document too verbose, agents ignore it | H | M | Keep under 160 lines, front-load critical rules, use FORBIDDEN markers for scanability |
| Policy conflicts with existing proof-debt-policy | L | L | Policies are complementary: debt = "no sorries", fidelity = "follow the source" |
| Index entry misconfigured, policy not loaded | M | L | Verify entry matches existing standards entries pattern exactly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create literature-fidelity-policy.md [COMPLETED]

**Goal**: Write the complete policy document following the proof-debt-policy.md structural pattern.

**Tasks**:
- [ ] Create the file at `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md`
- [ ] Write the Overview section (1 paragraph defining scope: applies to lean-implementation-agent and lean-research-agent when literature sources are provided)
- [ ] Write Mode Detection section defining the two modes:
  - Literature-Guided Mode: activated when a literature source (paper, textbook, notes, proof sketch) is referenced in the task description, research report, or plan artifacts
  - First-Principles Mode: default when no literature is provided; current behavior applies without restriction
- [ ] Write Literature-Guided Mode section with subsections:
  - Core Principle: Follow the source step-by-step, do not seek shortcuts
  - Source Identification: What counts as a literature source (papers, textbooks, lecture notes, proof sketches provided in task description, research reports, or plan attachments)
  - Translation Protocol (6-step process): (1) Read the literature step, (2) Identify the mathematical claim, (3) Find corresponding Lean type/lemma, (4) If exact match apply directly, (5) If encoding differs find equivalent formulation, (6) If no equivalent escalate -- do not skip
  - Deviation Handling: Document deviations explicitly, flag to user, never silently substitute
- [ ] Write Anti-Pattern Catalog with four FORBIDDEN entries:
  - FORBIDDEN: Shortcut-Seeking -- "The proof is hard so I'll try simp/omega/aesop instead" -- wrong because it bypasses the literature's proof structure; instead, translate the literature step faithfully
  - FORBIDDEN: Easier-Route Substitution -- "I'll find an easier approach" when the literature's approach is standard -- wrong because it discards the user's chosen reference; instead, follow the reference approach
  - FORBIDDEN: Premature Abandonment -- Abandoning the literature's strategy after a single failed tactic attempt -- wrong because a single tactic failure does not mean the mathematical step is wrong; instead, try alternative Lean encodings of the same step
  - FORBIDDEN: Silent Mixing -- Mixing literature steps with novel steps without flagging the deviation -- wrong because it makes the proof untraceable to the source; instead, mark any deviation with a comment and flag to user
- [ ] Write Escalation Protocol as a numbered decision tree:
  1. Re-read the source carefully (often the issue is misunderstanding the step)
  2. Try alternative Lean encodings of the same mathematical step
  3. Check if the step requires an intermediate lemma not stated in the source
  4. Search for existing Lean/Mathlib formulations of the concept
  5. After exhausting faithful translations, flag the gap to the user with: (a) the literature step that resists translation, (b) what was tried, (c) the current proof state
  6. NEVER skip the step and continue to the next one
- [ ] Write First-Principles Mode section (brief: current behavior applies, tactic exploration/MCP search/automation all permitted, no restrictions beyond existing standards)
- [ ] Write Usage Checklist with checkbox items matching the proof-debt-policy pattern
- [ ] Add Cross-References section linking to proof-debt-policy.md, proof-conventions-lean.md, and end-to-end-proof-workflow.md
- [ ] Verify document is 120-160 lines and follows existing standards formatting conventions

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md` - Create new file

**Verification**:
- File exists at the specified path
- Document contains all required sections: Overview, Mode Detection, Literature-Guided Mode (with Translation Protocol, Deviation Handling), Anti-Pattern Catalog (4 FORBIDDEN entries), Escalation Protocol, First-Principles Mode, Usage Checklist, Cross-References
- Document length is 120-160 lines
- FORBIDDEN markers are used consistently for anti-patterns
- Tone matches proof-debt-policy.md (prescriptive, direct, no hedging)

---

### Phase 2: Update index-entries.json [COMPLETED]

**Goal**: Register the new policy document in the Lean extension's context index so it loads for the correct agents.

**Tasks**:
- [ ] Add new entry to `.claude/extensions/lean/index-entries.json` following the existing standards entry pattern:
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
- [ ] Place the entry adjacent to other standards entries (after proof-readability-criteria.md entry) for organizational consistency
- [ ] Verify the JSON is valid after the edit

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/lean/index-entries.json` - Add new entry

**Verification**:
- JSON parses without errors (`jq . index-entries.json`)
- New entry exists with correct path, tags, load_when agents, and summary
- Entry loads for both lean-implementation-agent and lean-research-agent

## Testing & Validation

- [ ] Policy file exists at `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md`
- [ ] Policy file is 120-160 lines
- [ ] Policy contains all four FORBIDDEN anti-patterns
- [ ] Policy contains 6-step escalation protocol
- [ ] Policy defines both literature-guided and first-principles modes
- [ ] `index-entries.json` parses as valid JSON
- [ ] New index entry targets lean-implementation-agent and lean-research-agent
- [ ] No existing index entries were accidentally modified

## Artifacts & Outputs

- `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md` - New policy document
- `.claude/extensions/lean/index-entries.json` - Updated with new entry
- `specs/553_literature_fidelity_lean_policy/plans/01_literature-fidelity-lean.md` - This plan

## Rollback/Contingency

- Delete the new policy file: `rm .claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md`
- Revert the index-entries.json edit via `git checkout .claude/extensions/lean/index-entries.json`
- Both changes are additive (new file + new JSON entry) with no modification of existing files, so rollback is straightforward
