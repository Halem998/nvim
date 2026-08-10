# Implementation Summary: Task #659

**Completed**: 2026-06-11
**Duration**: ~45 minutes

## Overview

Added a `phase_constraint` field to all 12 dispatch context construction sites in skill-orchestrate
(single-task and multi-task modes). Added MUST NOT / Phase Containment clauses to 9 agent definition
files, and documented the new field in the dispatch-agent spec and handoff schema.

## What Changed

- `.claude/skills/skill-orchestrate/SKILL.md` — Added `phase_constraint` to all 12 dispatch context JSON objects (not_started, researched, planned/implementing, partial-continuation, drift-inspect fork, drift-revise, blocker-research fork, blocker-revise, blocker-re-implement, MT-research, MT-plan, MT-implement)
- `.claude/docs/architecture/dispatch-agent-spec.md` — Added `phase_constraint` documentation to Parameters section; expanded Decision Matrix from 6 to 12 rows with phase_constraint column
- `.claude/docs/architecture/handoff-schema.md` — Added `phase_recommendations` optional array field to schema, Field Definitions section, and Token Budget Constraints table
- `.claude/agents/general-research-agent.md` — Added MUST NOT item 7 and Phase Containment item 8
- `.claude/agents/general-implementation-agent.md` — Added MUST NOT item 6 and Phase Containment item 9
- `.claude/agents/planner-agent.md` — Added MUST NOT item 7 and Phase Containment item 8
- `.claude/agents/reviser-agent.md` — Added MUST NOT item 9 and Phase Containment item 10
- `.claude/agents/neovim-research-agent.md` — Added MUST NOT item 7 and Phase Containment item 8
- `.claude/agents/neovim-implementation-agent.md` — Added MUST NOT item 10 and Phase Containment item 11
- `.claude/agents/nix-research-agent.md` — Added MUST NOT item 9 and Phase Containment item 10
- `.claude/agents/nix-implementation-agent.md` — Added MUST NOT item 11 and Phase Containment item 12
- `.claude/agents/spawn-agent.md` — Added MUST NOT item 8 and Phase Containment item 9

## Decisions

- Used 12 dispatch sites rather than the plan's 11 — the drift-inspect fork is a separate context from the drift-revise dispatch, both requiring constraints
- Used "Phase Containment" as a named section header after MUST NOT, rather than numbering these items directly in the MUST DO list (clearer grouping for the conditional nature of the constraint)
- `orchestrator_mode` was NOT renamed or conflated with `phase_constraint` (16 orchestrator_mode occurrences remain unchanged)

## Plan Deviations

- **Phase 1 site count**: Plan specified 11 sites; implementation found 12 (drift-inspect fork is a separate context from drift-revise). Both are correctly assigned `"research"` and `"revise"` respectively.
- **Phase Containment section**: Used a named "Phase Containment" section header rather than inline MUST DO numbering, for clarity when the constraint is conditional.

## Verification

- Build: N/A (documentation changes)
- Tests: N/A
- Grep `phase_constraint` in SKILL.md: 12 occurrences (all dispatch sites covered)
- Grep `phase_constraint` in agent files: 9 files (all target agents covered)
- Grep `phase_recommendations` in handoff-schema.md: 4 occurrences (schema, field definitions, token budget table, example)
- Grep `phase_constraint` in dispatch-agent-spec.md: 3 occurrences (parameters, decision matrix)
- `orchestrator_mode` confirmed NOT conflated with `phase_constraint`

## Notes

The blocker escalation reviser and drift inspection reviser both correctly receive
`phase_constraint: "revise"` (not "plan"), distinguishing plan revision from new plan creation.
The fork-path dispatches (blocker research, drift inspect) both correctly receive
`phase_constraint: "research"`.
