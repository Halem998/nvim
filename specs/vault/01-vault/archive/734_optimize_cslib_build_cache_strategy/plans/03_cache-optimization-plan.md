# Implementation Plan: Optimize CSLib Build Cache Strategy

- **Task**: 734 - Optimize CSLib build cache strategy
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_build-cache-research.md, reports/02_detailed-change-spec.md
- **Artifacts**: plans/03_cache-optimization-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The cslib-implementation-agent's CI pipeline omits `lake exe cache get` (Step 0), causing 30-45 minute Mathlib rebuilds on every implementation run. The fix is 5 trivial text insertions across 4 files in `.claude/extensions/cslib/`, adding cache fetch as Step 0 in the CI pipeline, cache warming in skill preflights, and alignment in the rules file. All edits have exact old_string/new_string pairs provided in Report 02. Done when all 5 edits are applied and the CI pipeline documentation is internally consistent.

### Research Integration

Report 01 identified the root cause (cache gap between documentation and agent instructions) and proposed 6 changes ranked P0-P3. Report 02 refined this to 5 implementer-ready edits (A-E) with exact text anchors, excluding Change 4 (deferred CI for PR tasks) and Change 6 (main-branch pre-build) as out of scope. Report 02 also confirmed the hard-mode skill needs a parallel Stage 2b despite its maintenance note only mentioning "postflight" mirroring.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is an internal cslib extension optimization that improves agent efficiency but does not advance any roadmap milestone.

## Goals & Non-Goals

**Goals**:
- Add `lake exe cache get` as Step 0 in the agent CI pipeline
- Add preflight cache warming (Stage 2b) to both standard and hard-mode implementation skills
- Align the rules CI verification order with `ci-pipeline.md` documentation
- Update the MUST DO step count to reflect the new Step 0

**Non-Goals**:
- Deferred CI for PR-type tasks (Change 4 from Report 01 -- requires careful scoping)
- Main-branch pre-build strategy (Change 6 from Report 01 -- fragile, P3)
- Changes to manifest.json or routing tables
- Changes to `/pr` command (already has cache fetch in STEP 5b)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `lake exe cache get` fails (network, stale token) | L | L | Non-fatal; existing behavior unchanged on failure |
| Cache fetch adds 1-2 min to PR-description tasks that skip CI | L | L | Acceptable cost; optionally guard with task_type check |
| Hard-mode skill drifts from base skill | M | M | Edit D adds parallel Stage 2b to keep both in sync |
| Hardcoded project path `/home/benjamin/Projects/cslib` | L | L | Path already hardcoded throughout the extension; consistent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Core Cache Warming Edits (Edits A, C, D) [COMPLETED]

**Goal**: Insert `lake exe cache get` into the three locations that directly affect build performance -- the agent CI pipeline and both skill preflights.

**Tasks**:
- [ ] Apply Edit A: Add Step 0 (`lake exe cache get`) to the CI pipeline section in `cslib-implementation-agent.md` (anchor: lines 192-199)
- [ ] Apply Edit C: Add Stage 2b (Preflight Cache Warming) between Stage 2 and Stage 3 in `skill-cslib-implementation/SKILL.md` (anchor: lines 21-26)
- [ ] Apply Edit D: Add Stage 2b (Preflight Cache Warming) between Stage 2 and Stage 3 in `skill-cslib-implementation-hard/SKILL.md` (anchor: lines 79-87)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Insert Step 0 before Step 1 in CI pipeline section
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Insert Stage 2b between Stage 2 and Stage 3
- `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - Insert Stage 2b between Stage 2 and Stage 3

**Verification**:
- Grep for `lake exe cache get` in all three files confirms insertion
- Grep for `Stage 2b` in both skill files confirms insertion
- Grep for `Step 0` or `**Mathlib cache fetch**` in agent file confirms insertion

---

### Phase 2: Alignment and Accuracy Edits (Edits B, E) [COMPLETED]

**Goal**: Update the MUST DO step count and rules CI order to reflect the new Step 0, ensuring internal documentation consistency.

**Tasks**:
- [ ] Apply Edit B: Update step count from "all 7 steps" to "all 8 steps, including Step 0 cache fetch" in the MUST DO list of `cslib-implementation-agent.md` (anchor: line 470)
- [ ] Apply Edit E: Add Step 0 (`lake exe cache get`) to the CI Verification Order in `cslib.md` rules file (anchor: lines 77-86)

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Update step count in MUST DO list item 7
- `.claude/extensions/cslib/rules/cslib.md` - Insert Step 0 before Step 1 in CI Verification Order

**Verification**:
- Grep for `all 8 steps` in agent file confirms update
- Grep for `lake exe cache get` in rules file confirms insertion
- Manual read of CI Verification Order in `cslib.md` to confirm steps 0-7 are listed

## Testing & Validation

- [ ] All 5 edits applied without merge conflicts (exact string matching succeeds)
- [ ] `lake exe cache get` appears in: agent CI pipeline, both skill preflights, rules CI order
- [ ] MUST DO list references "all 8 steps" (not "all 7 steps")
- [ ] No other files modified beyond the 4 target files
- [ ] Stage 2b text is identical in both standard and hard-mode skills (except surrounding context)

## Artifacts & Outputs

- `plans/03_cache-optimization-plan.md` (this plan)
- `summaries/03_cache-optimization-summary.md` (post-implementation)
- Modified files:
  - `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
  - `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
  - `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`
  - `.claude/extensions/cslib/rules/cslib.md`

## Rollback/Contingency

All edits are text insertions into markdown documentation files with no runtime dependencies. Revert with `git checkout -- .claude/extensions/cslib/` to restore all four files to their pre-edit state. No build steps, configuration changes, or external state are affected.
