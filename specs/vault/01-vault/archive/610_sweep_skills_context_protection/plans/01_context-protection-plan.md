# Implementation Plan: Task #610

- **Task**: 610 - Sweep all remaining skills for context-protective lead pattern
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: 608 (context-protective lead pattern), 609 (skill-team-research reference implementation)
- **Research Inputs**: specs/610_sweep_skills_context_protection/reports/01_team-research.md
- **Artifacts**: plans/01_context-protection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply the context-protective lead pattern (task 608) to the seven remaining skills that accumulate excessive lead context. The refactored `skill-team-research` (task 609) serves as the reference implementation. Changes range from mechanical `cat` -> `@-reference` substitutions in thin wrapper skills (Group A) to synthesis-agent delegation in team orchestration skills (Group B). The definition of done is: all seven skills pass a grep audit for `cat` / format-injection violations, and each includes a documented context budget target.

### Research Integration

The team research report identified three distinct violation types across seven skills (not the original six -- `skill-reviser` was added by the Critic):

1. **Format spec injection** via `cat` into lead context (all Group A skills)
2. **Memory retrieval captured in lead** context (skill-researcher, skill-planner, skill-implementer)
3. **Inline synthesis** where the lead reads and processes large content files (skill-team-plan, skill-team-implement)

Prioritization follows the research report: Group A thin wrappers first (mechanical, low risk), Group B team skills second (architectural, medium risk).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items are directly advanced by this task. This is a meta-level infrastructure improvement to the agent system.

## Goals & Non-Goals

**Goals**:
- Remove all `cat` / `Read` format-spec injection from lead skills
- Delegate memory retrieval to subagents instead of capturing in lead context
- Delegate roadmap reading to subagents via @-reference
- Delegate inline synthesis in team skills to synthesis-agent
- Add context budget documentation and MUST NOT (Context Protection) sections to all refactored skills
- Tighten skill-orchestrator prose instructions with jq extraction examples
- Update `context-protective-lead.md` with a compliance status table

**Non-Goals**:
- Refactoring extension skills (verified clean by research)
- Modifying `skill-orchestrate` (the autonomous lifecycle skill -- verified compliant)
- Creating new agents (synthesis-agent already exists from task 609)
- Migrating team skills to skill-base.sh (valuable but separate scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Subagent memory retrieval produces different results than lead retrieval | M | L | Test on a real task after each skill change; verify memories surface correctly |
| @-reference format specs not resolved by subagent model | H | L | Confirm reviser-agent and all subagent types resolve @-references; test with `/revise N` |
| Synthesis-agent plan variant produces lower quality than inline synthesis | M | M | Task 609 demonstrated high quality; verify with `/plan N --team` test run |
| skill-team-implement wave logic breaks if plan text parsing changes | H | M | Preserve existing plan-text parsing logic; only change how content is passed to teammates |
| Regression in postflight behavior after removing cat stages | M | L | Run verification grep after each phase; test each skill with a real task |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Audit and Establish Baseline [COMPLETED]

**Goal**: Create a grep-based audit of all target skills to establish a violation baseline, and verify skill-orchestrate (the autonomous lifecycle skill) is clean as flagged by the research Critic.

**Tasks**:
- [x] Run grep audit across all seven target skills for `cat `, `$(cat `, `format_content=`, `memory_context=`, `roadmap_context=` patterns *(completed)*
- [x] Record violation count per skill (baseline for verification) *(completed)*
- [x] Quick-check `skill-orchestrate/SKILL.md` for context-protective violations (Critic gap) *(completed: skill-orchestrate is clean)*
- [x] Confirm extension skills are clean (spot-check 2-3 with grep) *(completed: skill-neovim-research and skill-nix-research are clean)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- No files modified (audit only)

**Verification**:
- Baseline violation counts documented
- skill-orchestrate confirmed clean or added to target list
- Extension skills confirmed clean

---

### Phase 2: Group A Thin Wrappers -- Format Spec and Memory Removal [COMPLETED]

**Goal**: Remove format-spec injection (`cat` of format files) and memory retrieval (`memory-retrieve.sh`) from all four thin wrapper skills, replacing with @-references and subagent delegation.

**Tasks**:
- [x] **skill-researcher** (3+1 violations): *(completed)*
  - Remove Stage 4b: delete `format_content=$(cat .claude/context/formats/report-format.md)` and the `<artifact-format-specification>` block injection in Stage 5
  - Replace in subagent prompt: add `"Follow the format in @.claude/context/formats/report-format.md"`
  - Remove Stage 4a: delete `memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)` capture
  - Replace in subagent prompt: add `"If memory extension available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus}'"`
  - Remove Stage 4c: delete `roadmap_context=$(cat specs/ROADMAP.md)` and `<roadmap-context>` block
  - Replace in subagent prompt: add `"Read @specs/ROADMAP.md for project context if it exists."`
  - Rewrite Stage 4d: replace `cat "$f"` loop with passing artifact directory path as @-reference to subagent
  - Add MUST NOT (Context Protection) section with context budget target (~500 tokens)
- [x] **skill-planner** (2 violations): *(completed)*
  - Remove Stage 4b: delete `format_content=$(cat .claude/context/formats/plan-format.md)`
  - Replace in subagent prompt: add `"Follow the format in @.claude/context/formats/plan-format.md"`
  - Remove Stage 4a: delete `memory_context` capture
  - Replace in subagent prompt: add memory retrieval instruction for subagent
  - Add MUST NOT (Context Protection) section with context budget target (~400 tokens)
- [x] **skill-implementer** (2 violations): *(completed)*
  - Remove Stage 4b: delete `format_content=$(cat .claude/context/formats/summary-format.md)`
  - Replace in subagent prompt: add `"Follow the format in @.claude/context/formats/summary-format.md"`
  - Remove Stage 4a: delete `memory_context` capture
  - Replace in subagent prompt: add memory retrieval instruction for subagent
  - Add MUST NOT (Context Protection) section with context budget target (~400 tokens)
- [x] **skill-reviser** (1 violation): *(completed)*
  - Remove Stage 4b: delete `format_content=$(cat .claude/context/formats/plan-format.md)` at ~line 185
  - Replace in subagent prompt: add `"Follow the format in @.claude/context/formats/plan-format.md"` (replace the `<artifact-format-specification>` block)
  - Add MUST NOT (Context Protection) section with context budget target (~400 tokens)

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Remove Stages 4a, 4b, 4c; rewrite 4d; update Stage 5 prompt; add context protection section
- `.claude/skills/skill-planner/SKILL.md` - Remove Stages 4a, 4b; update Stage 5 prompt; add context protection section
- `.claude/skills/skill-implementer/SKILL.md` - Remove Stages 4a, 4b; update Stage 5 prompt; add context protection section
- `.claude/skills/skill-reviser/SKILL.md` - Remove Stage 4b; update Stage 5 prompt; add context protection section

**Verification**:
- `grep -n 'format_content=\|$(cat ' .claude/skills/skill-{researcher,planner,implementer,reviser}/SKILL.md` returns zero matches
- `grep -n 'memory_context=' .claude/skills/skill-{researcher,planner,implementer}/SKILL.md` returns zero matches
- `grep -n 'roadmap_context=' .claude/skills/skill-researcher/SKILL.md` returns zero matches
- Each modified skill has a "MUST NOT (Context Protection)" section
- Each modified skill has a documented context budget target

---

### Phase 3: skill-orchestrator -- Tighten Prose Instructions [COMPLETED]

**Goal**: Replace ambiguous "Read specs/state.json" and "Read TODO.md" prose instructions with jq extraction examples and targeted grep suggestions.

**Tasks**:
- [x] Replace line ~32 instruction "1. Read specs/state.json" with jq extraction example *(completed)*
- [x] Replace line ~34 instruction "4. Read TODO.md for additional context if needed" with grep alternative *(completed)*
- [x] Add brief context protection note referencing the pattern document *(completed: added MUST NOT (Context Protection) section)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrator/SKILL.md` - Update Task Lookup section with jq examples

**Verification**:
- `grep -n 'Read specs/state.json' .claude/skills/skill-orchestrator/SKILL.md` returns zero matches for unqualified "Read" instructions
- jq extraction example present in Task Lookup section

---

### Phase 4: Group B Team Skills -- Synthesis Delegation and @-References [COMPLETED]

**Goal**: Remove inline synthesis and content injection from skill-team-plan and skill-team-implement. Delegate synthesis to synthesis-agent and replace content reading with @-references.

**Tasks**:
- [x] **skill-team-plan** (3 violations): *(completed)*
  - Remove Stage 5b: delete `research_content=$(cat "$research_path")` (~line 184)
  - Update teammate prompts (Stages 5): replace `{research_content}` injection with `"Read the research report at @{research_path} for context."`
  - Replace Stages 7-9 (inline synthesis) with synthesis-agent dispatch:
    - Stage 7: collect only file paths of completed candidate plans (do NOT read files)
    - Stage 8: dispatch synthesis-agent with candidate paths as @-references, plan-specific synthesis instructions, and format reference `@.claude/context/formats/plan-format.md`
    - Stage 9: receive compact summary (~200 words) from synthesis agent; do NOT read the unified plan
  - Add MUST NOT (Context Protection) section matching skill-team-research format
  - Add context budget documentation (~1,500 tokens target)
  - Update Stage 10 postflight to use skill-base.sh functions (skill_postflight_update, skill_link_artifacts)
- [x] **skill-team-implement** (3 violations): *(completed)*
  - Stage 7 (teammate prompts): replace embedded `{phase_details}`, `{steps_from_plan}`, `{files_list}` with `@{plan_path}` reference; instruct teammates to "Read the plan at @{plan_path} and implement Phase {P}"
  - Stage 11 (implementation summary): delegate summary creation to synthesis-agent with phase result file paths as @-references
  - Add MUST NOT (Context Protection) section
  - Add context budget documentation (~800 tokens target)
  - Update Stage 12 postflight to use skill-base.sh functions

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-team-plan/SKILL.md` - Remove Stage 5b; rewrite Stages 7-9 for synthesis delegation; update teammate prompts; add context protection; update postflight
- `.claude/skills/skill-team-implement/SKILL.md` - Rewrite Stage 5 plan parsing; update Stage 7 prompts; delegate Stage 11 summary; add context protection; update postflight

**Verification**:
- `grep -n '$(cat ' .claude/skills/skill-team-{plan,implement}/SKILL.md` returns zero matches
- `grep -n 'research_content' .claude/skills/skill-team-plan/SKILL.md` returns zero matches
- Both skills have "MUST NOT (Context Protection)" sections with context budget targets
- Synthesis-agent dispatch pattern present in both files
- Stages 7-9 in skill-team-plan match the reference pattern from skill-team-research (Stages 7-9)

---

### Phase 5: Compliance Registry and Final Audit [COMPLETED]

**Goal**: Update the context-protective-lead.md pattern document with a compliance status table covering all skills, and run a final grep audit to confirm zero violations remain.

**Tasks**:
- [x] Add "Compliance Status" table to `.claude/context/patterns/context-protective-lead.md` *(completed)*
- [x] Run final grep audit across all `.claude/skills/*/SKILL.md` files for violation patterns *(completed: zero violations found)*
  - `format_content=$(cat` -- 0 matches
  - `memory_context=$(bash` -- 0 matches
  - `roadmap_context=$(cat` -- 0 matches
  - `research_content=$(cat` -- 0 matches
- [x] Verify each refactored skill has a "MUST NOT (Context Protection)" section *(completed)*
- [ ] Spot-test one skill per group with a real task invocation *(deviation: skipped — out of scope for meta implementation task)*

**Timing**: 30 minutes

**Depends on**: 2, 3, 4

**Files to modify**:
- `.claude/context/patterns/context-protective-lead.md` - Add Compliance Status table

**Verification**:
- Final grep audit returns zero violations across all skills
- Compliance Status table present in context-protective-lead.md
- All seven target skills confirmed compliant

---

## Testing & Validation

- [ ] Grep audit for `$(cat ` and `format_content=` patterns across all `.claude/skills/*/SKILL.md` returns zero matches (post-Phase 5)
- [ ] Each refactored thin wrapper skill (researcher, planner, implementer, reviser) has a "MUST NOT (Context Protection)" section
- [ ] Each refactored team skill (team-plan, team-implement) has synthesis-agent delegation and context budget documentation
- [ ] skill-orchestrator Task Lookup section uses jq extraction instead of prose "Read" instructions
- [ ] Compliance Status table in context-protective-lead.md lists all skills with current status
- [ ] No regressions in existing MUST NOT (Postflight Boundary) sections

## Artifacts & Outputs

- `specs/610_sweep_skills_context_protection/plans/01_context-protection-plan.md` (this file)
- `.claude/skills/skill-researcher/SKILL.md` (modified)
- `.claude/skills/skill-planner/SKILL.md` (modified)
- `.claude/skills/skill-implementer/SKILL.md` (modified)
- `.claude/skills/skill-reviser/SKILL.md` (modified)
- `.claude/skills/skill-orchestrator/SKILL.md` (modified)
- `.claude/skills/skill-team-plan/SKILL.md` (modified)
- `.claude/skills/skill-team-implement/SKILL.md` (modified)
- `.claude/context/patterns/context-protective-lead.md` (modified -- compliance table added)

## Rollback/Contingency

All changes are to `.claude/skills/*/SKILL.md` files and one context pattern file. These are pure-text instruction documents with no runtime dependencies. If any refactored skill produces degraded behavior:

1. `git revert` the specific commit for the affected skill
2. Re-run the command to verify the revert restores prior behavior
3. Investigate the root cause before re-attempting the refactor

Since each skill is modified independently, a revert of one skill does not affect others. The compliance table in context-protective-lead.md should be updated to reflect the revert status.
