# Implementation Plan: Task #320

- **Task**: 320 - study_personal_ai_infrastructure
- **Status**: [NOT STARTED]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/320_study_personal_ai_infrastructure/reports/01_personal-ai-research.md
- **Artifacts**: plans/01_pai-improvements.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements selected improvements from the Personal AI Infrastructure (PAI) study, prioritizing features that enhance quality assurance and continuous improvement without adding excessive complexity. The focus is on three high-priority features (rating capture, URL verification, ISC-style criteria) and two medium-priority features (hook-based context loading, structured reflection).

### Research Integration

The research report analyzed PAI v4.0.3 and identified 7 recommendations across priority levels. This plan covers the top 5 recommendations, deferring lower-priority items (research depth modes, pack install pattern) for future consideration.

## Goals & Non-Goals

**Goals**:
- Implement post-completion rating capture with failure context logging
- Add URL verification protocol for research artifacts
- Convert plan phases to atomic, verifiable ISC-style criteria
- Explore hook-based context automation for session management
- Add structured reflection prompts for continuous improvement

**Non-Goals**:
- Voice/TTS integration (not applicable to terminal workflow)
- TELOS life OS (beyond project-focused task management scope)
- Research depth modes (requires significant team mode changes)
- Full PAI Algorithm adoption (over-engineering risk)
- Agent personas with backstories (adds complexity without clear benefit)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing workflows with new verification requirements | High | Medium | Implement as opt-in first, make mandatory after validation |
| Context bloat from accumulated signals/reflections | Medium | Medium | Implement retention policies and periodic archival |
| Over-engineering simple tasks with ISC criteria | Medium | Low | Apply ISC only to phases, not individual tasks |
| Hook integration requiring Claude Code settings changes | Low | High | Document settings.json configuration clearly |
| Rating fatigue from prompts after every task | Low | Medium | Make rating optional, not blocking |

## Implementation Phases

### Phase 1: Rating/Feedback Capture System [NOT STARTED]

**Goal**: Enable post-completion feedback collection with failure context capture for continuous improvement analysis.

**Tasks**:
- [ ] Create `.claude/context/formats/signals-format.md` defining JSONL schema for ratings
- [ ] Create `specs/signals.jsonl` file for storing task completion ratings
- [ ] Add rating capture logic to `skill-todo` postflight (after task completion)
- [ ] Implement failure context dump for ratings <= 3 (store in `.memory/failures/`)
- [ ] Document rating scale and usage in `.claude/docs/guides/rating-capture.md`

**Files to modify**:
- `.claude/skills/skill-todo.md` - Add rating prompt and signal storage
- `.claude/context/formats/signals-format.md` - Create signals schema
- `specs/signals.jsonl` - Create signals storage file
- `.memory/failures/` - Create directory for failure dumps

**Timing**: 1.5 hours

**Verification**:
- Running `/todo` after completing a task prompts for rating (1-10)
- Ratings are appended to `specs/signals.jsonl` in correct format
- Low ratings (<=3) trigger failure context capture to `.memory/failures/`

---

### Phase 2: URL Verification Protocol [NOT STARTED]

**Goal**: Ensure all URLs in research reports are verified before inclusion, preventing hallucinated sources.

**Tasks**:
- [ ] Create `.claude/context/patterns/url-verification-protocol.md` documenting verification rules
- [ ] Add `verified` field to research report source citations format
- [ ] Update `general-research-agent.md` to include URL verification step
- [ ] Update `report-format.md` to require verification status for web sources
- [ ] Add URL verification to research skill preflight/postflight

**Files to modify**:
- `.claude/context/patterns/url-verification-protocol.md` - Create protocol doc
- `.claude/context/formats/report-format.md` - Add verified field requirement
- `.claude/agents/general-research-agent.md` - Add verification step
- `.claude/skills/skill-researcher.md` - Add verification to workflow

**Timing**: 1 hour

**Verification**:
- Research reports include `verified: true/false` for each URL source
- Agent documentation references verification protocol
- Report format validation would fail without verification status

---

### Phase 3: ISC-Style Plan Criteria [NOT STARTED]

**Goal**: Convert plan phases to atomic, verifiable criteria with binary testable outcomes.

**Tasks**:
- [ ] Create `.claude/context/patterns/isc-criteria-pattern.md` documenting ISC approach
- [ ] Update `plan-format.md` to include ISC-style criteria format
- [ ] Add criteria tracking format to implementation summary artifacts
- [ ] Update `planner-agent.md` to generate ISC-style criteria
- [ ] Add phase completion as N/M criteria passed tracking

**Files to modify**:
- `.claude/context/patterns/isc-criteria-pattern.md` - Create ISC pattern doc
- `.claude/context/formats/plan-format.md` - Add criteria format
- `.claude/context/formats/summary-format.md` - Add criteria tracking
- `.claude/agents/planner-agent.md` - Update to generate ISC criteria

**Timing**: 1.5 hours

**Verification**:
- New plans include atomic criteria with checkbox verification
- Implementation summaries show N/M criteria passed
- Planner agent generates criteria per phase

---

### Phase 4: Hook-Based Context Loading [NOT STARTED]

**Goal**: Automate context injection using Claude Code hooks for session start and tool usage.

**Tasks**:
- [ ] Research Claude Code hook system and settings.json configuration
- [ ] Create `.claude/hooks/` directory for hook definitions
- [ ] Create `SessionStart` hook for automatic context loading
- [ ] Create `PostToolUse` hook for progress tracking (optional)
- [ ] Document hook configuration in `.claude/docs/guides/hook-configuration.md`

**Files to modify**:
- `.claude/settings.json` - Add hooks configuration
- `.claude/hooks/session-start.md` - Create SessionStart hook
- `.claude/hooks/post-tool-use.md` - Create PostToolUse hook (optional)
- `.claude/docs/guides/hook-configuration.md` - Create documentation

**Timing**: 1.5 hours

**Verification**:
- SessionStart hook loads relevant context automatically
- Hook configuration documented with examples
- Settings.json includes valid hook definitions

---

### Phase 5: Structured Reflection (LEARN Phase) [NOT STARTED]

**Goal**: Add post-completion reflection prompts to capture learnings for algorithm improvement.

**Tasks**:
- [ ] Create `.claude/context/formats/reflections-format.md` defining JSONL schema
- [ ] Create `.memory/reflections.jsonl` for storing task reflections
- [ ] Add reflection prompts to `skill-implementer` postflight
- [ ] Define reflection questions (what worked, what didn't, what to do differently)
- [ ] Document reflection workflow in `.claude/docs/guides/structured-reflection.md`

**Files to modify**:
- `.claude/context/formats/reflections-format.md` - Create reflections schema
- `.memory/reflections.jsonl` - Create reflections storage
- `.claude/skills/skill-implementer.md` - Add reflection prompts
- `.claude/docs/guides/structured-reflection.md` - Create documentation

**Timing**: 1 hour

**Verification**:
- Completing implementation triggers reflection prompts
- Reflections stored in `.memory/reflections.jsonl` in correct format
- Reflection questions documented and consistent

## Testing & Validation

- [ ] Phase 1: Complete a task and verify rating prompt appears, signal stored correctly
- [ ] Phase 2: Run research with web sources and verify URLs are verified
- [ ] Phase 3: Create a plan with new format and verify ISC criteria present
- [ ] Phase 4: Start a new session and verify context loaded via hook
- [ ] Phase 5: Complete implementation and verify reflection prompts appear
- [ ] Integration: Full workflow from research through completion with all new features

## Artifacts & Outputs

- `specs/320_study_personal_ai_infrastructure/plans/01_pai-improvements.md` (this file)
- `specs/320_study_personal_ai_infrastructure/summaries/01_pai-improvements-summary.md` (after implementation)
- `.claude/context/formats/signals-format.md`
- `.claude/context/formats/reflections-format.md`
- `.claude/context/patterns/url-verification-protocol.md`
- `.claude/context/patterns/isc-criteria-pattern.md`
- `.claude/docs/guides/rating-capture.md`
- `.claude/docs/guides/hook-configuration.md`
- `.claude/docs/guides/structured-reflection.md`
- `specs/signals.jsonl`
- `.memory/reflections.jsonl`

## Rollback/Contingency

Each phase is independently reversible:
- **Phase 1**: Remove rating prompt from skill-todo, delete signals.jsonl
- **Phase 2**: Remove verified field requirement, revert agent changes
- **Phase 3**: Revert plan-format.md to previous version
- **Phase 4**: Remove hooks from settings.json, delete hooks/ directory
- **Phase 5**: Remove reflection prompts from skill-implementer, delete reflections.jsonl

All changes are to the agent system itself, not user code, so rollback involves reverting .claude/ files only.
