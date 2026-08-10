# Task 535: Establish Single Source of Truth for Resume Points

## Problem

When resuming implementation (`/implement N`), the agent receives conflicting signals about where to resume:
- `state.json` contains a `resume_phase` field
- The plan file contains phase status markers (`[COMPLETED]`, `[PARTIAL]`, `[NOT STARTED]`)

For Task 107, `state.json` said `resume_phase: 2`, but the plan file showed Phase 4 as `[PARTIAL]` and Phase 5 as `[COMPLETED]`. The agent spent significant time reconciling these conflicting sources with no documented precedence rule.

## Impact

- Agents waste tokens reasoning about which source to trust
- Resumes may start from the wrong phase if state.json is stale
- No standardized behavior across different skills

## Solution

1. Update `/implement` command specification to declare: **plan file markers are the PRIMARY source of truth**; `state.json` `resume_phase` is a cached secondary source
2. If the two sources disagree by more than 1 phase, prefer plan markers and log a warning
3. Update `skill-implementer` and extension implementation skills to calculate resume point from plan file, not from the `resume_phase` parameter passed by the orchestrator
4. Optionally: remove `resume_phase` from state.json schema (or keep it as advisory only)

## Acceptance Criteria

- [ ] `/implement` command doc specifies plan markers as primary source of truth
- [ ] Skills read plan file to determine resume point rather than relying on `resume_phase` parameter
- [ ] When sources disagree, a warning is logged and plan markers win

## Effort

1-2 hours

## Type

meta

## Dependencies

None

## Key Files

- `.opencode/commands/implement.md`
- `.opencode/skills/skill-implementer/SKILL.md`
- Extension implementation skills (e.g., `skill-lean-implementation`)
