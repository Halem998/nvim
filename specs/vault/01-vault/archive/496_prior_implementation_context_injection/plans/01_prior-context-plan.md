# Implementation Plan: Task #496 - Prior-Implementation Context Injection for /research

- **Task**: 496 - Add prior-implementation context injection to /research
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/496_prior_implementation_context_injection/reports/01_prior-context-research.md`
- **Artifacts**: `plans/01_prior-context-plan.md` (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements prior-implementation context injection into the `skill-researcher` preflight flow. When `/research` is invoked on a task in `implementing` or `partial` status, the skill will collect existing implementation artifacts (summaries, handoffs, progress files, plans) and inject them directly into the research subagent's prompt. This prevents redundant research and enables the agent to focus on gaps and blockers.

### Research Integration

The research report (Finding 1-7) establishes:
- **skill-researcher** currently has no prior-implementation awareness (Finding 1)
- Existing injection patterns (memory context, format spec) provide templates (Finding 2)
- **skill-planner** already discovers prior plans via path reference (Finding 3)
- Relevant artifact types tracked in state.json: `summary`, `handoff`, `plan`, `research` (Finding 4)
- Task directories contain `summaries/`, `handoffs/`, `progress/`, `plans/`, `reports/` (Finding 5)
- **general-research-agent** already loads roadmap context in Stage 1.5 (Finding 7)

Decisions adopted from research:
- New Stage 4c in skill-researcher preflight (Decision 1)
- Trigger on `status == "implementing"` or `status == "partial"` (Decision 2)
- Content injected directly (not path references) (Decision 4)
- `<prior-implementation-context>` tag format (Decision 5)
- ~500 line budget with truncation (Decision 6)

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No ROADMAP.md items directly advance this task. The work improves agent system quality under "Agent System Quality" (Phase 1), specifically reducing redundant research and improving context continuity for partially-implemented tasks.

## Goals & Non-Goals

**Goals**:
- Detect `implementing` and `partial` task status in skill-researcher preflight
- Collect and inject prior implementation artifacts into the research subagent prompt
- Focus research on gaps and blockers rather than rediscovering completed work
- Maintain graceful degradation when no prior artifacts exist

**Non-Goals**:
- Modifying postflight flows
- Changing planner or implementer context handling
- Creating new artifact formats
- Modifying the memory retrieval system

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Prior context exceeds prompt budget, crowding out research instructions | Medium | Medium | Cap at 500 lines; prioritize summaries over other artifacts; truncate with notice |
| Stale context from old summaries misleads research | Medium | Low | Include file dates in injected headers; agent instructed to verify recency |
| Handoff/progress files not present in most tasks (low adoption) | Low | High | Graceful degradation: if no artifacts found, inject nothing (no error) |
| Double-loading: research agent re-reads files already injected | Low | Low | Inject content directly; add explicit instruction to NOT re-read injected files |
| Research on "planned" tasks gets unnecessary injection | Low | Low | Only trigger on "implementing" and "partial", not "planned" or "researched" |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Design Artifact Collection Logic and Truncation Strategy [COMPLETED]

**Goal**: Finalize the artifact discovery order, line budgets per artifact type, and truncation algorithm before modifying skills.

**Tasks**:
- [ ] Document artifact priority order and rationale:
  1. Implementation summaries (`summaries/*.md`) - highest value, human-readable overview
  2. Handoff documents (`handoffs/*.md`) - critical if present (context exhaustion state)
  3. Progress files (`progress/*.json`) - machine-readable objective status
  4. Latest plan (`plans/*.md`) - already discoverable but useful for research context
- [ ] Define per-type line budgets within the 500-line total cap:
  - Summaries: up to 200 lines (most recent first)
  - Handoffs: up to 150 lines (most recent 3, truncated individually)
  - Progress files: up to 50 lines (most recent 1)
  - Latest plan: up to 100 lines (truncated)
- [ ] Define truncation algorithm: hard truncate at budget with `[NOTE: truncated]` suffix
- [ ] Document file selection: sort by version (`sort -V`), take most recent for each type

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- None (design phase, output is documented in plan)

**Verification**:
- Design document reviewed and approved (self-verification)
- Budget totals do not exceed 500 lines

---

### Phase 2: Update skill-researcher SKILL.md [COMPLETED]

**Goal**: Add Stage 4c to collect prior implementation artifacts and update Stage 4/Stage 5 to inject them into the subagent prompt and delegation context.

**Tasks**:
- [ ] Add new **Stage 4c: Collect Prior Implementation Context** between Stage 4b and Stage 4:
  - Check `status` from Stage 1 (already available as `$status`)
  - If `status == "implementing"` or `status == "partial"`, collect artifacts from `specs/{NNN}_{SLUG}/`
  - Read contents of matching files, wrap in markdown sections with filenames
  - Apply 500-line total budget with truncation
  - Store result in `prior_implementation_context` variable
  - If no artifacts found or status does not match, set to empty string
- [ ] Update **Stage 4: Prepare Delegation Context** JSON to include:
  - `"prior_implementation_context": "{content or empty string}"`
- [ ] Update **Stage 5: Invoke Subagent** prompt to include:
  - Place `<prior-implementation-context>` block AFTER `<artifact-format-specification>` and BEFORE `<memory-context>`
  - Only inject if `prior_implementation_context` is non-empty
  - Wrap content in `<prior-implementation-context>` tags
  - Add instruction: "Do NOT re-read the files listed above; use the injected content directly."

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/skills/skill-researcher/SKILL.md` - Add Stage 4c, update Stage 4 JSON, update Stage 5 prompt

**Verification**:
- SKILL.md renders correctly with new stage inserted in correct sequence
- Bash logic for artifact collection is syntactically valid
- Line budget logic correctly caps at 500 lines

---

### Phase 3: Update general-research-agent.md [COMPLETED]

**Goal**: Teach the research agent how to parse and use prior implementation context to avoid redundant research.

**Tasks**:
- [ ] Add new **Stage 1.6: Load Prior Implementation Context** after Stage 1.5 (Load Roadmap Context):
  - Check if `prior_implementation_context` is provided in delegation context and non-empty
  - Parse the tagged sections (summaries, handoffs, progress, plan)
  - Extract key decisions, current state, completed work, and identified blockers
  - Store as `prior_context` for use in Stage 2
  - If empty or missing, skip gracefully
- [ ] Update **Stage 2: Analyze Task and Determine Search Strategy**:
  - Add new research question #6: "What prior implementation work exists and what gaps remain?"
  - Add guidance: If prior context is present, focus research on gaps, blockers, and follow-up items rather than rediscovering completed work
  - Add instruction: Reference existing artifacts in the new report rather than rediscovering them

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.opencode/agent/subagents/general-research-agent.md` - Add Stage 1.6, update Stage 2

**Verification**:
- Agent flow document is logically consistent
- Stage 1.6 correctly references `prior_implementation_context` field
- Stage 2 research questions are updated

---

### Phase 4: Testing and Validation [COMPLETED]

**Goal**: Verify the context injection works correctly across different task states and artifact combinations.

**Tasks**:
- [ ] **Test Case A: Task with no prior implementation** (status = `not_started` or `planned`):
  - Run `/research` on a task without summaries/handoffs
  - Verify no `<prior-implementation-context>` block appears in prompt
  - Verify no errors in preflight
- [ ] **Test Case B: Task with implementation summaries** (status = `implementing` or `partial`):
  - Identify or create a task with `summaries/*.md` files
  - Run `/research` on that task
  - Verify `<prior-implementation-context>` block contains summary content
  - Verify block is placed after format spec and before memory context
- [ ] **Test Case C: Large artifact truncation**:
  - Verify that when collected artifacts exceed 500 lines, content is truncated with `[NOTE: truncated]` notice
- [ ] **Test Case D: Research agent behavior**:
  - Verify research report references prior work rather than rediscovering it
  - Verify report includes gap analysis when prior context is present

**Timing**: 1 hour

**Depends on**: 2, 3

**Files to modify**:
- None (testing phase)

**Verification**:
- All test cases pass
- No regressions in existing `/research` behavior for non-implementing tasks

## Testing & Validation

- [ ] Test with task in `not_started` status: no injection occurs
- [ ] Test with task in `implementing` status with summaries: injection occurs
- [ ] Test with task in `partial` status with handoffs: injection occurs
- [ ] Test truncation when artifacts exceed 500 lines
- [ ] Verify prompt ordering: delegation JSON -> format spec -> prior context -> memory context -> instructions
- [ ] Verify research report avoids redundant research when prior context is present
- [ ] Verify no errors in skill preflight for missing directories (summaries/, handoffs/, progress/)

## Artifacts & Outputs

- `.opencode/skills/skill-researcher/SKILL.md` - Updated with Stage 4c, delegation context field, prompt injection
- `.opencode/agent/subagents/general-research-agent.md` - Updated with Stage 1.6 and Stage 2 gap-focused research strategy
- `specs/496_prior_implementation_context_injection/plans/01_prior-context-plan.md` - This plan

## Rollback/Contingency

If implementation causes issues with `/research`:
1. Revert changes to `skill-researcher/SKILL.md` and `general-research-agent.md` via git
2. Verify `/research` works normally on a test task
3. Debug and re-apply changes incrementally

If prompt size becomes an issue with context injection:
1. Reduce line budget from 500 to 300 lines
2. Exclude plans from automatic injection (require explicit opt-in)
3. Consider compressing/summarizing artifacts before injection (future enhancement)
