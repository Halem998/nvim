# Implementation Plan: Context Fork Refactor for Core Skills

- **Task**: 500 - add_context_fork_to_core_skills
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None (Task 499 completed)
- **Research Inputs**:
  - specs/500_add_context_fork_to_core_skills/reports/03_fork-implementation-analysis.md (definitive fork analysis, primary)
  - specs/500_add_context_fork_to_core_skills/reports/02_web-fork-best-practices.md (web research, corrective)
  - specs/500_add_context_fork_to_core_skills/reports/01_add-context-fork-skills.md (initial codebase analysis)
- **Artifacts**: plans/03_context-fork-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research report 03 definitively established that `context: fork` + `agent:` spawns a named subagent with a SEPARATE prompt cache, providing zero FORK_SUBAGENT cache-sharing benefit. The original task premise -- that adding `context: fork` to core skills would enable prompt cache sharing -- is incorrect. However, report 03 identified one viable hybrid path (Recommendation 5): omit `subagent_type` from Task calls to trigger FORK_SUBAGENT, while inlining the agent definition instructions directly into the Task prompt. This preserves specialized behavior while gaining cache sharing at the cost of larger prompts. This plan rescopes task 500 to: (1) correct fork-patterns.md with definitive findings, (2) prototype the hybrid inline-agent approach on one skill, (3) evaluate whether the trade-off is worthwhile, and (4) roll out if viable or document the decision not to.

### Research Integration

Reports integrated:
- `03_fork-implementation-analysis.md` (v3, primary): Definitive analysis proving `context: fork` + `agent:` gives separate cache. Identified fundamental incompatibility between cache sharing and agent routing. Proposed hybrid inline-agent approach as the only viable path.
- `02_web-fork-best-practices.md` (v2): Corrected fork mechanics from official Claude Code documentation. Established that `context: fork` makes SKILL.md body the subagent prompt.
- `01_add-context-fork-skills.md` (v1): Initial codebase analysis identifying all 65 skills and their delegation patterns.

### Prior Plan Reference

Plan v2 (`02_add-context-fork-skills.md`) was built on report 02's partially-correct understanding. It proposed auditing conversation-history dependencies and piloting `context: fork` + `agent:` on skill-researcher. Report 03 invalidated this approach: `context: fork` + `agent:` provides zero cache benefit because it spawns a named subagent (separate cache). The effort estimates from v2 (3 hours) informed this plan's calibration, but the phase structure is entirely new. The decision-gate pattern from v2 Phase 1 is preserved as a useful control mechanism.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. The "Agent frontmatter validation" item under "Agent System Quality" is tangentially related but is not advanced by this work.

## Goals & Non-Goals

**Goals**:
- Correct fork-patterns.md to accurately reflect the named-subagent vs fork distinction and cache-sharing mechanics
- Prototype the hybrid inline-agent approach: omit `subagent_type` from one skill's Task call and inline the agent definition in the prompt
- Measure the trade-off: prompt size increase vs cache-sharing benefit
- Make a documented go/no-go decision on whether to adopt the hybrid approach for core skills
- If go: roll out to remaining core skills with verification
- Update all related documentation to reflect the correct understanding

**Non-Goals**:
- Modifying team-mode skills (tracked by Task 501)
- Filing feature requests with Anthropic (out of scope for implementation)
- Restructuring the skill/agent separation of concerns
- Adding `context: fork` to core skill frontmatter (proven to provide no cache benefit)
- Changing extension skills (they already use `context: fork` + `agent:`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Inlined agent instructions degrade output quality compared to named subagent | H | M | Phase 2 pilot compares output quality side-by-side before rollout |
| Fork inherits parent tools/model, losing agent-specific model override | M | H | Document as known limitation; most agents use default model anyway |
| Inlined instructions bloat Task prompt, negating cache savings | M | M | Phase 2 measures prompt size delta; decision gate at Phase 3 |
| Fork nesting prohibition blocks skills that delegate further | H | L | Core skills delegate once (skill -> agent); no nesting needed |
| FORK_SUBAGENT behavior changes in future Claude Code versions | L | L | Pin minimum version in docs; monitor changelog |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Correct fork-patterns.md and related documentation [NOT STARTED]

**Goal**: Update fork-patterns.md with the definitive findings from report 03, correcting inaccuracies about `context: fork` mechanics and documenting the fundamental incompatibility between cache sharing and named agent routing.

**Tasks**:
- [ ] Read current fork-patterns.md and identify all statements that conflict with report 03 findings
- [ ] Rewrite the "Mechanism Overview" section to clearly distinguish:
  - `context: fork` + `agent:` = named subagent with SEPARATE cache (no cache sharing)
  - `context: fork` without `agent:` = general-purpose subagent (still separate cache, unless FORK_SUBAGENT fires for anonymous dispatch)
  - FORK_SUBAGENT = fork with SHARED cache, only when `subagent_type` is omitted
- [ ] Add a "Named Subagent vs Fork" comparison table (from report 03 Finding 2) documenting context, system prompt, model, and prompt cache differences
- [ ] Update the "Why core skills don't benefit today" section to reference the fundamental incompatibility (not just the explicit `subagent_type` issue)
- [ ] Add a "Hybrid Inline-Agent Approach" section documenting Recommendation 5 from report 03 as the only viable path for combining cache sharing with specialized behavior
- [ ] Add version context: v2.1.101 fix for Issue #16803, v2.1.117+ for FORK_SUBAGENT
- [ ] Check and update `.claude/context/patterns/thin-wrapper-skill.md` for any incorrect fork descriptions
- [ ] Check and update `.claude/context/architecture/system-overview.md` for fork-related content

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/fork-patterns.md` - Primary rewrite
- `.claude/context/patterns/thin-wrapper-skill.md` - Verify/correct fork references
- `.claude/context/architecture/system-overview.md` - Verify/correct fork references

**Verification**:
- fork-patterns.md correctly states that `context: fork` + `agent:` uses separate cache
- Named-subagent vs fork table present with cache distinction highlighted
- No documentation contradicts report 03 findings
- Version requirements documented

---

### Phase 2: Prototype hybrid inline-agent approach on skill-researcher [NOT STARTED]

**Goal**: Test the hybrid approach (Recommendation 5 from report 03) on skill-researcher: omit `subagent_type` from the Task call and inline the general-research-agent definition directly in the Task prompt. Evaluate whether the fork inherits enough context for correct operation and whether output quality is preserved.

**Tasks**:
- [ ] Read the current general-research-agent.md definition to capture the full agent instructions that must be inlined
- [ ] Read skill-researcher SKILL.md to identify where the Task call with `subagent_type` is constructed
- [ ] Create a backup copy of skill-researcher SKILL.md (or note the git state for rollback)
- [ ] Modify skill-researcher SKILL.md to:
  - Remove `subagent_type: "general-research-agent"` from the Task call
  - Prepend the general-research-agent instructions to the Task prompt (inline the agent definition)
  - Preserve all existing delegation context (session_id, delegation_depth, memory_context, etc.)
- [ ] Run a test research task: `/research {test_task}` and verify:
  - (a) FORK_SUBAGENT activates (fork is spawned, not a named subagent)
  - (b) The fork receives the inlined agent instructions in its Task prompt
  - (c) Preflight stages execute correctly (status update, artifact number, memory retrieval)
  - (d) The fork performs research with quality comparable to the named-subagent approach
  - (e) Postflight stages execute correctly (metadata reading, status update, artifact linking)
  - (f) Research report is created with correct format and content
- [ ] Measure prompt size: compare the inlined-instructions prompt length vs the original Task prompt length (the delta is the cost of inlining)
- [ ] Document results: quality comparison, prompt size delta, observed cache behavior, any issues

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Modify Task call to omit `subagent_type` and inline agent instructions

**Verification**:
- Test task completes full research workflow successfully
- Research report quality is comparable to named-subagent approach
- Postflight completes (status update, artifact linking, git commit)
- Prompt size delta documented

**Decision Gate**: If Phase 2 reveals that forked execution produces significantly worse output quality, or that the prompt size increase negates cache savings, stop and document findings. Do not proceed to Phase 3 rollout. Instead, proceed to Phase 4 (documentation) with the decision to not adopt the hybrid approach.

---

### Phase 3: Roll out hybrid approach to remaining core skills [NOT STARTED]

**Goal**: Apply the validated hybrid inline-agent approach from Phase 2 to all remaining core delegating skills, with spot-check verification.

**Tasks**:
- [ ] Read each remaining core skill SKILL.md and its corresponding agent definition:
  - skill-planner + planner-agent
  - skill-implementer + general-implementation-agent
  - skill-reviser + reviser-agent
  - skill-spawn + spawn-agent
- [ ] For each skill, apply the same transformation as Phase 2:
  - Remove `subagent_type` from the Task call
  - Inline the agent definition instructions into the Task prompt
  - Preserve all delegation context
- [ ] Apply the same transformation to extension delegating skills:
  - skill-neovim-research + neovim-research-agent
  - skill-neovim-implementation + neovim-implementation-agent
  - skill-nix-research + nix-research-agent
  - skill-nix-implementation + nix-implementation-agent
- [ ] Spot-check: run one `/plan {test_task}` to verify skill-planner works with inlined agent
- [ ] Spot-check: run one `/implement {test_task}` to verify skill-implementer works with inlined agent

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Inline planner-agent instructions
- `.claude/skills/skill-implementer/SKILL.md` - Inline general-implementation-agent instructions
- `.claude/skills/skill-reviser/SKILL.md` - Inline reviser-agent instructions
- `.claude/skills/skill-spawn/SKILL.md` - Inline spawn-agent instructions
- `.claude/skills/skill-neovim-research/SKILL.md` - Inline neovim-research-agent instructions
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Inline neovim-implementation-agent instructions
- `.claude/skills/skill-nix-research/SKILL.md` - Inline nix-research-agent instructions
- `.claude/skills/skill-nix-implementation/SKILL.md` - Inline nix-implementation-agent instructions

**Verification**:
- All 9 core/extension delegating skills have `subagent_type` removed and agent instructions inlined
- Spot-check plan task completes successfully
- Spot-check implement task completes successfully
- No regressions in task workflow

---

### Phase 4: Final documentation and decision record [NOT STARTED]

**Goal**: Update fork-patterns.md with the implementation outcome (hybrid approach adopted or rejected), update the decision matrix, and ensure all documentation reflects the final state.

**Tasks**:
- [ ] Update fork-patterns.md "Decision Matrix" section:
  - If hybrid adopted: add "Pattern C: Hybrid inline-agent with FORK_SUBAGENT" documenting the approach, benefits, and trade-offs
  - If hybrid rejected: document the evaluation results and why the trade-off was not worthwhile
- [ ] Update fork-patterns.md "Why core skills don't benefit today" section:
  - If hybrid adopted: rewrite to "How core skills benefit from FORK_SUBAGENT" with the inline approach
  - If hybrid rejected: keep current section, add "Evaluated and rejected" subsection with findings
- [ ] Update `.claude/CLAUDE.md` Skill-to-Agent Mapping table if the delegation pattern changed
- [ ] Update `.claude/context/patterns/thin-wrapper-skill.md` if the skill template needs to reflect the new delegation pattern
- [ ] Update `.claude/context/templates/thin-wrapper-skill.md` template if applicable
- [ ] Verify no documentation references the old incorrect understanding of `context: fork` enabling cache sharing

**Timing**: 0.5 hours

**Depends on**: 1 (documentation updates based on correct mechanics can start after Phase 1; the decision-record portion requires Phase 2/3 results but can be deferred)

**Files to modify**:
- `.claude/context/patterns/fork-patterns.md` - Decision matrix and outcome documentation
- `.claude/CLAUDE.md` - Skill-to-Agent mapping if changed
- `.claude/context/patterns/thin-wrapper-skill.md` - Template updates if applicable
- `.claude/context/templates/thin-wrapper-skill.md` - Template updates if applicable

**Verification**:
- Decision record documents the go/no-go outcome with evidence
- All documentation references the correct fork/cache-sharing mechanics
- No file references the incorrect premise that `context: fork` enables FORK_SUBAGENT cache sharing

## Testing & Validation

- [ ] Phase 1: fork-patterns.md correctly distinguishes named subagent (separate cache) from fork (shared cache)
- [ ] Phase 1: No documentation contradicts report 03 definitive findings
- [ ] Phase 2: skill-researcher test task completes full workflow with inlined agent instructions
- [ ] Phase 2: Output quality is comparable to named-subagent approach (subjective evaluation)
- [ ] Phase 2: Prompt size delta is documented and assessed against cache savings
- [ ] Phase 3: Spot-check plan and implement tasks pass after rollout (if go decision)
- [ ] Phase 4: Decision record is present in fork-patterns.md documenting evaluation outcome
- [ ] All modified SKILL.md files have valid frontmatter

## Artifacts & Outputs

- `specs/500_add_context_fork_to_core_skills/plans/03_context-fork-refactor.md` (this plan)
- `specs/500_add_context_fork_to_core_skills/summaries/03_context-fork-refactor-summary.md` (to be created on implementation)
- `.claude/context/patterns/fork-patterns.md` (updated with correct mechanics and decision record)

## Rollback/Contingency

**If hybrid approach fails during pilot (Phase 2)**:
1. Revert skill-researcher SKILL.md to restore `subagent_type: "general-research-agent"` (use git checkout)
2. Skip Phase 3 entirely
3. Complete Phase 4 with "rejected" decision record
4. Task is still valuable: Phase 1 documentation corrections stand regardless of hybrid outcome

**If rollout (Phase 3) causes regressions**:
1. Git revert the Phase 3 commit(s)
2. Restore `subagent_type` in all affected skill files
3. Update fork-patterns.md decision record to note the rollback and specific failure mode
4. Consider selective adoption (some skills hybrid, others traditional) based on which failed

**If FORK_SUBAGENT does not activate as expected**:
1. Verify `CLAUDE_CODE_FORK_SUBAGENT=1` is set in environment
2. Verify Claude Code version is >= 2.1.117
3. If environment is correct but fork does not trigger, document as a Claude Code bug and revert
