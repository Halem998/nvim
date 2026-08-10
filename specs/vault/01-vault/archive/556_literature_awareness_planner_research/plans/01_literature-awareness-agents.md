# Implementation Plan: Task #556

- **Task**: 556 - Add literature awareness to planner, research agents, and lean4 rule
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task #553 (completed), Task #554 (completed)
- **Research Inputs**: specs/556_literature_awareness_planner_research/reports/01_literature-awareness-agents.md
- **Artifacts**: plans/01_literature-awareness-agents.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add literature-following guidance to three agent/rule files so that agents working on Lean and formal tasks with literature references know to mirror the source material's proof structure rather than inventing a novel decomposition. The planner-agent gets a new conditional Stage 4.5, the lean-research-agent gets a Literature Extraction Protocol section, and the lean4.md auto-applied rule gets a compact Literature Fidelity section. All three modifications are additive (no existing content removed) and reference the literature-fidelity-policy.md documents created in tasks 553 and 554.

### Research Integration

The research report (01_literature-awareness-agents.md) provided exact insertion points and draft content for all three files. Key findings:
- planner-agent.md: Insert Stage 4.5 between Stage 4 (Decompose into Phases) and Stage 5 (Create Plan File), plus conditional @-references and a plan template subsection
- lean-research-agent.md: Insert Literature Extraction Protocol between Research Constraints and Stage 0, plus a MUST NOT addition
- lean4.md: Append Literature Fidelity section after Build Commands (compact, ~8 lines)
- lean/index-entries.json: Already has the correct entry from task 553 (verify only)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Planner-agent conditionally mirrors literature proof structure in plan phases for lean4/formal tasks
- Lean-research-agent extracts and documents proof structure from literature into research reports
- lean4.md rule reminds agents to follow literature when available on every *.lean file edit
- Verify lean/index-entries.json already has the correct entry

**Non-Goals**:
- Modifying formal-research-agent.md or logic-research-agent.md (future task)
- Duplicating the full literature-fidelity-policy.md content into agent files (use cross-references)
- Modifying the lean-implementation-flow.md or other workflow documents (task 555 scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage 4.5 adds plan verbosity for non-literature tasks | L | L | Stage is conditional -- skipped when no literature is referenced |
| lean4.md rule adds cognitive load on every *.lean edit | M | M | Kept compact (8 lines); "no literature? skip" is prominent |
| Planner references lean/formal policies that may not be loaded | M | L | Use conditional @-references ("when task_type is lean4/formal") |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add Literature-Guided Phase Structuring to planner-agent.md [COMPLETED]

**Goal**: Add Stage 4.5, conditional @-references, and Literature Source Mapping subsection to the planner-agent so it mirrors literature proof structure in plan phases for lean4/formal tasks.

**Tasks**:
- [x] Add conditional @-references to Context References section (after existing references): literature-fidelity-policy.md for lean4 and formal task types *(completed)*
- [x] Insert new Stage 4.5 ("Literature-Guided Phase Structuring") between Stage 4 and Stage 5, using draft content from research report *(completed)*
- [x] Add "Literature Source Mapping" subsection to the plan template in Stage 5, after the "Research Integration" subsection *(completed: after Roadmap Alignment subsection)*
- [x] Verify the file parses correctly (no broken markdown structure) *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/planner-agent.md` - Add Stage 4.5, conditional @-references, plan template subsection

**Verification**:
- Stage 4.5 exists between Stage 4 and Stage 5
- Stage 4.5 is conditional on task_type being lean4 or formal AND literature being referenced
- Context References section includes conditional @-references to both lean and formal literature-fidelity-policy.md
- Plan template includes "Literature Source Mapping" subsection

---

### Phase 2: Add Literature Extraction Protocol to lean-research-agent.md [COMPLETED]

**Goal**: Add a Literature Extraction Protocol section so the lean-research-agent produces structured step maps from literature sources for downstream planner consumption.

**Tasks**:
- [x] Insert "Literature Extraction Protocol" section between "Research Constraints for Lean Tasks" section and "Stage 0" section, using draft content from research report *(completed)*
- [x] Add MUST NOT item 14 to the Critical Requirements list: "Ignore literature sources referenced in the task" *(completed)*
- [x] Verify the file parses correctly (no broken markdown structure) *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/agents/lean-research-agent.md` - Add Literature Extraction Protocol section and MUST NOT item

**Verification**:
- Literature Extraction Protocol section exists between Research Constraints and Stage 0
- Protocol includes 5-step extraction process and cross-reference to literature-fidelity-policy.md
- MUST NOT list includes item about not ignoring literature sources

---

### Phase 3: Add Literature Fidelity section to lean4.md and verify index [COMPLETED]

**Goal**: Add a compact Literature Fidelity section to the lean4.md auto-applied rule and verify lean/index-entries.json already has the correct entry.

**Tasks**:
- [x] Append "Literature Fidelity" section after "Build Commands" in lean4.md, using draft content from research report (~8 lines, compact bullet format) *(completed: 12 lines added)*
- [x] Verify lean/index-entries.json contains the literature-fidelity-policy.md entry with correct agents (lean-implementation-agent, lean-research-agent) *(completed: entry confirmed at lines 186-207)*
- [x] Verify the lean4.md file parses correctly (no broken markdown structure) *(completed)*

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/rules/lean4.md` - Append Literature Fidelity section

**Files to verify (read-only)**:
- `.claude/extensions/lean/index-entries.json` - Confirm entry exists (no modification needed)

**Verification**:
- lean4.md has Literature Fidelity section after Build Commands
- Section includes 3 FORBIDDEN patterns and escalation sequence
- Section includes "no literature? first-principles mode" guidance
- lean/index-entries.json has literature-fidelity-policy.md entry for both lean agents

## Testing & Validation

- [x] All three modified files have valid markdown structure (no orphaned headings or broken links)
- [x] planner-agent.md Stage 4.5 references both lean and formal literature-fidelity-policy.md
- [x] lean-research-agent.md Literature Extraction Protocol includes structured step map template
- [x] lean4.md Literature Fidelity section is compact (under 10 lines of content)
- [x] lean/index-entries.json entry confirmed present (read-only verification)

## Artifacts & Outputs

- plans/01_literature-awareness-agents.md (this file)
- summaries/01_literature-awareness-agents-summary.md (post-implementation)

## Rollback/Contingency

All changes are additive text insertions. To revert, use `git diff` to identify added sections and remove them. No existing content is modified or deleted, so rollback carries no risk of data loss.
