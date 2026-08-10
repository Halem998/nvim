# Implementation Plan: Task #500 - Add context: fork to core skills (Revised)

- **Task**: 500 - add_context_fork_to_core_skills
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: Task #499 (completed)
- **Research Inputs**:
  - specs/500_add_context_fork_to_core_skills/reports/01_add-context-fork-skills.md (codebase analysis)
  - specs/500_add_context_fork_to_core_skills/reports/02_web-fork-best-practices.md (web research, corrective)
- **Artifacts**: plans/02_add-context-fork-skills.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Web research (report 02) corrected the understanding of `context: fork` and `CLAUDE_CODE_FORK_SUBAGENT=1` mechanics established in report 01. The original plan recommended abandoning task 500 based on the incorrect conclusion that `context: fork` would break core skill orchestration. In reality, `context: fork` makes the SKILL.md body the subagent's prompt (losing parent conversation history, not tool access), and `FORK_SUBAGENT=1` only fires when `subagent_type` is omitted from Task calls. Since core skills always specify `subagent_type` explicitly, they currently receive zero cache benefit from the user's global `FORK_SUBAGENT=1` setting.

This revised plan investigates whether core skills can safely adopt `context: fork` and/or omit `subagent_type` (using `agent:` frontmatter routing instead) to enable prompt cache sharing. Definition of done: core skills either adopt the optimization with verified correctness, or a documented decision explains why they cannot.

### Research Integration

Reports integrated into this plan:
- `01_add-context-fork-skills.md` (v1 plan, codebase-only analysis -- conclusions partially corrected by report 02)
- `02_web-fork-best-practices.md` (web research, corrected fork mechanics from official Claude Code docs)

### Prior Plan Reference

`plans/01_add-context-fork-skills.md` (v1) recommended abandoning task 500. That recommendation is superseded by this revised plan based on corrected research.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Determine whether core delegating skills depend on parent conversation history (the only thing `context: fork` removes)
- If safe, add `context: fork` to core skills to enable execution isolation
- Investigate whether omitting `subagent_type` from Task calls (using `agent:` frontmatter) enables `FORK_SUBAGENT=1` cache sharing without breaking agent routing
- Pilot changes on skill-researcher before rolling out to other skills
- Update fork-patterns.md with corrected mechanics from official docs
- Update any other documentation that contains the pre-correction understanding

**Non-Goals**:
- Restructuring core skill preflight/postflight architecture
- Changing how extension skills handle delegation (they already use `context: fork` + `agent:`)
- Modifying team-mode skills (separate concern tracked by task 501)
- Adding new skills or agents

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Core skill preflight/postflight relies on parent conversation history | H | M | Phase 1 audit each skill's orchestration stages for implicit history dependencies before making changes |
| `agent:` frontmatter routing produces different agent than explicit `subagent_type` | H | L | Phase 2 pilot verifies correct agent invocation on skill-researcher before rollout |
| `context: fork` causes skill body to be interpreted differently than expected | M | L | Phase 2 test verifies preflight/postflight still execute correctly |
| Omitting `subagent_type` does not trigger FORK_SUBAGENT cache sharing | M | M | Phase 2 test checks for cache-sharing indicators in agent spawn logs |
| Changes break existing workflows for users without FORK_SUBAGENT=1 | H | L | `context: fork` and `agent:` frontmatter are independent of FORK_SUBAGENT; test both paths |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Audit conversation history dependencies [NOT STARTED]

**Goal**: Determine whether any core delegating skill's orchestration stages implicitly rely on parent conversation history (the only capability lost with `context: fork`).

**Tasks**:
- [ ] Read each core skill SKILL.md body and identify all Stage operations: skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-spawn
- [ ] Read each extension skill SKILL.md body: skill-neovim-research, skill-neovim-implementation, skill-nix-research, skill-nix-implementation
- [ ] For each skill, classify every preflight and postflight stage as either (a) self-contained (uses only Bash scripts, jq, file I/O) or (b) history-dependent (implicitly references prior conversation turns)
- [ ] Document findings: which skills are safe for `context: fork` and which have history dependencies
- [ ] If any skill has history dependencies, document what would need to change to remove them

**Timing**: 1 hour

**Depends on**: none

**Files to examine**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-reviser/SKILL.md`
- `.claude/skills/skill-spawn/SKILL.md`
- `.claude/skills/skill-neovim-research/SKILL.md`
- `.claude/skills/skill-neovim-implementation/SKILL.md`
- `.claude/skills/skill-nix-research/SKILL.md`
- `.claude/skills/skill-nix-implementation/SKILL.md`

**Verification**:
- Each skill has a documented classification (safe / history-dependent)
- Decision recorded: proceed with `context: fork` adoption, or stop and document why not

**Decision Gate**: If Phase 1 finds that all core skills have history dependencies that cannot be removed, stop at Phase 1 and update documentation with findings. Do not proceed to Phase 2.

### Phase 2: Pilot on skill-researcher [NOT STARTED]

**Goal**: Add `context: fork` and `agent:` frontmatter to skill-researcher, verify that orchestration stages still execute correctly, and test whether FORK_SUBAGENT cache sharing activates.

**Tasks**:
- [ ] Add `context: fork` to skill-researcher SKILL.md frontmatter
- [ ] Add `agent: general-research-agent` to skill-researcher SKILL.md frontmatter
- [ ] Verify that skill-researcher's Stage 5 Task call still uses explicit `subagent_type: "general-research-agent"` (do NOT remove `subagent_type` yet -- test `context: fork` in isolation first)
- [ ] Run a test research task through the system: `/research {test_task}` and verify:
  - (a) Preflight stages execute (status update, postflight marker, artifact number, memory retrieval)
  - (b) Subagent spawns with correct agent type
  - (c) Postflight stages execute (metadata reading, status update, artifact linking, git commit, cleanup)
  - (d) Research report is created correctly
- [ ] If `context: fork` test passes, additionally test omitting `subagent_type` from the Task call (relying on `agent:` frontmatter routing):
  - (e) Verify correct agent type is selected
  - (f) Check spawn logs for FORK_SUBAGENT cache-sharing indicators
- [ ] Document test results and any issues found

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add `context: fork` and `agent:` to frontmatter; optionally remove `subagent_type` from Task call

**Verification**:
- Test task completes successfully through full research workflow
- Postflight marker is cleaned up
- State.json and TODO.md are correctly updated
- If `subagent_type` was removed: correct agent type still invoked

### Phase 3: Roll out to remaining core skills [NOT STARTED]

**Goal**: Apply the verified changes from Phase 2 to all remaining core and extension delegating skills.

**Tasks**:
- [ ] Apply frontmatter changes to skill-planner (add `context: fork`, `agent: planner-agent`)
- [ ] Apply frontmatter changes to skill-implementer (add `context: fork`, `agent: general-implementation-agent`)
- [ ] Apply frontmatter changes to skill-reviser (add `context: fork`, `agent: reviser-agent`)
- [ ] Apply frontmatter changes to skill-spawn (add `context: fork`, `agent: spawn-agent`)
- [ ] Apply frontmatter changes to skill-neovim-research (add `context: fork`, `agent: neovim-research-agent`)
- [ ] Apply frontmatter changes to skill-neovim-implementation (add `context: fork`, `agent: neovim-implementation-agent`)
- [ ] Apply frontmatter changes to skill-nix-research (add `context: fork`, `agent: nix-research-agent`)
- [ ] Apply frontmatter changes to skill-nix-implementation (add `context: fork`, `agent: nix-implementation-agent`)
- [ ] If Phase 2 confirmed `subagent_type` removal is safe, remove `subagent_type` from Task calls in all modified skills
- [ ] Spot-check: run one plan task and one implement task to verify end-to-end correctness

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-reviser/SKILL.md`
- `.claude/skills/skill-spawn/SKILL.md`
- `.claude/skills/skill-neovim-research/SKILL.md`
- `.claude/skills/skill-neovim-implementation/SKILL.md`
- `.claude/skills/skill-nix-research/SKILL.md`
- `.claude/skills/skill-nix-implementation/SKILL.md`

**Verification**:
- All 9 delegating skills have `context: fork` in frontmatter
- Spot-check tasks complete successfully
- No regressions in task workflow

### Phase 4: Update documentation [NOT STARTED]

**Goal**: Update fork-patterns.md and related documentation to reflect the corrected understanding of `context: fork` and `FORK_SUBAGENT` mechanics from official docs.

**Tasks**:
- [ ] Update `.claude/context/patterns/fork-patterns.md`:
  - Correct the `context: fork` description: it makes the SKILL.md body the subagent's prompt, losing parent conversation history (not context loading)
  - Update "Why core skills don't benefit today" section if core skills now DO benefit
  - Update decision matrix to reflect that core skills can use `context: fork` when they don't depend on parent conversation history
  - Add a "Corrected Mechanics" note referencing the web research findings
- [ ] Check `.claude/context/architecture/system-overview.md` for any references to fork mechanics that need correction
- [ ] Check `.claude/context/patterns/thin-wrapper-skill.md` for any fork-related guidance that needs updating
- [ ] Check `.claude/context/templates/thin-wrapper-skill.md` for template accuracy
- [ ] Update `.claude/docs/guides/creating-skills.md` if it references fork mechanics

**Timing**: 0.5 hours

**Depends on**: 1 (documentation updates can proceed as soon as corrected mechanics are understood, independent of skill changes)

**Files to modify**:
- `.claude/context/patterns/fork-patterns.md` (primary)
- `.claude/context/architecture/system-overview.md` (if fork-related content exists)
- `.claude/context/patterns/thin-wrapper-skill.md` (if fork-related content exists)
- `.claude/context/templates/thin-wrapper-skill.md` (if fork-related content exists)
- `.claude/docs/guides/creating-skills.md` (if fork-related content exists)

**Verification**:
- fork-patterns.md accurately describes `context: fork` as "SKILL.md body becomes subagent prompt, loses parent conversation history"
- Decision matrix reflects current state (core skills using or not using `context: fork`)
- No documentation contradicts the corrected understanding

## Testing & Validation

- [ ] Phase 1: Each core/extension skill classified as history-safe or history-dependent
- [ ] Phase 2: skill-researcher test task completes full workflow (preflight, subagent, postflight)
- [ ] Phase 2: If `subagent_type` removed, verify correct agent routing via `agent:` frontmatter
- [ ] Phase 3: Spot-check plan and implement tasks after rollout
- [ ] Phase 4: fork-patterns.md review for accuracy against official docs
- [ ] All modified SKILL.md files have valid frontmatter (no YAML parse errors)
- [ ] No regressions in existing task workflows

## Artifacts & Outputs

- `specs/500_add_context_fork_to_core_skills/reports/01_add-context-fork-skills.md` (existing codebase research)
- `specs/500_add_context_fork_to_core_skills/reports/02_web-fork-best-practices.md` (existing web research)
- `specs/500_add_context_fork_to_core_skills/plans/02_add-context-fork-skills.md` (this revised plan)
- `specs/500_add_context_fork_to_core_skills/summaries/02_add-context-fork-skills-summary.md` (to be created on implementation)

## Rollback/Contingency

If changes cause skill failures after rollout:
1. Revert frontmatter changes: remove `context: fork` and `agent:` from affected SKILL.md files
2. Restore `subagent_type` in Task calls if it was removed
3. Git revert the relevant commits

If Phase 1 finds all skills have conversation history dependencies:
1. Stop at Phase 1, do not proceed to Phases 2-3
2. Complete Phase 4 (documentation updates) with findings
3. Mark task as completed with summary explaining why `context: fork` cannot be adopted for core skills currently
