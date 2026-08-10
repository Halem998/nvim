# Research Report: Task #309

**Task**: 309 - unified_artifact_numbering_research
**Started**: 2026-03-27T17:29:18Z
**Completed**: 2026-03-27T17:45:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, existing artifact patterns, skill/agent definitions
**Artifacts**: specs/309_unified_artifact_numbering_research/reports/01_unified-numbering-research.md
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- Current artifact numbering has **no centralized tracking** - each artifact type (report, plan, summary) uses independent sequences starting at 01
- This creates misalignment in multi-round scenarios (e.g., research-001.md, research-002.md, research-003.md all paired with plan-001.md)
- Proposed solution: Add `next_artifact_number` field to task entries in state.json that tracks a **unified sequence across all artifact types**
- Research drives numbering (increments), plan and summary inherit the current highest number (no increment)
- Pattern: 01_report -> 01_plan -> 01_summary -> (blocker) -> 02_report -> 02_plan -> 02_summary

## Context & Scope

This research analyzes how artifact numbering currently works across the agent system and designs a unified approach where:
1. All artifact types share a single sequence number per task
2. Research artifacts drive sequence advancement
3. Plan and summary artifacts reuse the current number from research
4. Backward compatibility is maintained for tasks without the new field

### Current State Analysis

**Artifact Naming Convention** (from artifact-formats.md):
- Format: `MM_{short-slug}.md` where MM is zero-padded sequence (01, 02, 03...)
- Each artifact type maintains **independent sequences**:
  - Reports: 01, 02, 03... (chronological research)
  - Plans: 01, 02, 03... (plan versions)
  - Summaries: 01, 02, 03... (execution summaries)

**Evidence from Codebase**:
```
# Task 308 (typical flow)
specs/308_adaptive_context_loading/reports/01_context-loading-research.md
specs/308_adaptive_context_loading/plans/01_adaptive-context-loading.md
specs/308_adaptive_context_loading/summaries/01_implementation-summary.md

# Task 032 (multi-round research)
specs/archive/032_neovim_sidebar_context_display/reports/research-001.md
specs/archive/032_neovim_sidebar_context_display/reports/research-002.md
specs/archive/032_neovim_sidebar_context_display/reports/research-003.md
specs/archive/032_neovim_sidebar_context_display/plans/implementation-001.md
```

**Problem Illustrated**:
In task 032, three research reports (001, 002, 003) all correspond to a single plan (001). The numbering doesn't reflect the relationship between artifacts in multi-round scenarios.

## Findings

### 1. Current Numbering Logic in Skills/Agents

**general-research-agent.md**:
- Stage 5: "Path: `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md`"
- No explicit logic for determining MM value
- Implicitly assumes first research is 01

**planner-agent.md**:
- Stage 5: "Find next plan version (MM_{short-slug}.md format)"
- Instruction but no concrete implementation
- Plans are created independently of research numbering

**general-implementation-agent.md**:
- Stage 6: "Write to `specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md`"
- Summary numbering is independent of plan numbering

**spawn-agent.md**:
- Hardcodes `02_spawn-analysis.md` assuming first research is 01
- This is fragile if research numbering changes

**/revise command**:
- Line 63: "Increment version: MM_{short-slug}.md format"
- Implements plan versioning (02, 03...) but independently

### 2. Artifact Numbering Semantics

**Current Semantics (Per-Type Independent)**:
```
Reports:   01 -> 02 -> 03 -> 04
Plans:     01 -> 02 -> 03
Summaries: 01 -> 02
```

**Proposed Semantics (Unified Sequence)**:
```
Round 1:  01_report -> 01_plan -> 01_summary
Round 2:  02_report -> 02_plan -> 02_summary
Round 3:  03_report -> (still working on plan)
```

### 3. Multi-Round Scenario Support

**Typical Multi-Round Flow**:
1. `/research N` creates report 01 -> next_artifact_number becomes 2
2. `/plan N` creates plan 01 (uses current-1, doesn't increment)
3. `/implement N` creates summary 01 (uses current-1, doesn't increment)
4. Task blocked, new research needed
5. `/research N` creates report 02 -> next_artifact_number becomes 3
6. `/plan N` creates plan 02 (uses current-1, doesn't increment)
7. Etc.

**Key Insight**: Research is the "driver" of the sequence. Plans and summaries inherit the research number they correspond to.

### 4. state.json Field Design

**Proposed Field Location**: Per-task entry in `active_projects[]`

```json
{
  "project_number": 309,
  "project_name": "unified_artifact_numbering",
  "status": "researched",
  "language": "meta",
  "next_artifact_number": 2,
  "artifacts": [
    {
      "type": "research",
      "path": "specs/309_unified_artifact_numbering/reports/01_unified-numbering.md",
      "summary": "..."
    }
  ]
}
```

**Field Semantics**:
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `next_artifact_number` | integer | 1 | Next artifact sequence number to use when research creates new artifact |

**Behavior**:
- Initial value: 1 (first artifact will be 01_)
- Research: Uses current value, then increments
- Plan: Uses (current - 1), does not increment
- Summary: Uses (current - 1), does not increment

### 5. Backward Compatibility

**Tasks Without Field**:
When `next_artifact_number` is missing or undefined:
1. Scan existing artifacts in task directory
2. Find highest number across all artifact types
3. Set `next_artifact_number` to (highest + 1)
4. Proceed with normal logic

**Scanning Logic**:
```bash
# Find highest existing artifact number
max_num=$(find "specs/${padded_num}_${slug}/" -name "*.md" \
  | grep -oE '[0-9]{2}_' | sort -rn | head -1 | tr -d '_')
next_num=$((max_num + 1))
```

### 6. Implementation Locations

**Files Requiring Updates**:

| File | Change Required |
|------|-----------------|
| `.claude/context/reference/state-management-schema.md` | Add `next_artifact_number` field documentation |
| `.claude/rules/artifact-formats.md` | Update "Per-Type Sequential Numbering" to "Unified Sequential Numbering" |
| `.claude/skills/skill-researcher/SKILL.md` | Read/increment `next_artifact_number` in postflight |
| `.claude/skills/skill-planner/SKILL.md` | Read `next_artifact_number - 1` in delegation context |
| `.claude/skills/skill-implementer/SKILL.md` | Read `next_artifact_number - 1` in delegation context |
| `.claude/agents/general-research-agent.md` | Use provided artifact number, document increment behavior |
| `.claude/agents/planner-agent.md` | Use provided artifact number (no increment) |
| `.claude/agents/general-implementation-agent.md` | Use provided artifact number (no increment) |
| `.claude/agents/spawn-agent.md` | Use provided artifact number instead of hardcoded 02 |
| `.claude/commands/revise.md` | Plan revision should NOT change sequence (same round) |

### 7. Delegation Context Extension

**Current Research Delegation**:
```json
{
  "task_context": {
    "task_number": 309,
    "task_name": "...",
    "language": "meta"
  },
  "metadata_file_path": "specs/309_.../... .return-meta.json"
}
```

**Proposed Research Delegation**:
```json
{
  "task_context": {
    "task_number": 309,
    "task_name": "...",
    "language": "meta"
  },
  "artifact_number": 1,
  "metadata_file_path": "specs/309_.../... .return-meta.json"
}
```

**Proposed Plan Delegation**:
```json
{
  "task_context": {
    "task_number": 309,
    "task_name": "...",
    "language": "meta"
  },
  "artifact_number": 1,
  "research_path": "specs/.../reports/01_...",
  "metadata_file_path": "specs/309_.../... .return-meta.json"
}
```

## Decisions

1. **Unified numbering across artifact types**: All artifacts in a task share a single sequence
2. **Research drives the sequence**: Only research increments `next_artifact_number`
3. **Plan/summary inherit**: They use current-1 to match their research round
4. **Backward compatible via scanning**: Missing field triggers directory scan
5. **Delegation passes number explicitly**: Skills calculate and pass the number to agents
6. **Revise doesn't change sequence**: Plan revision stays in same round (01 -> 01_revised, not 02)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backward compat issues | H | M | Scanning fallback + thorough testing |
| Edge case: research without plan | M | L | Document: research always advances sequence |
| Edge case: multiple revisions | M | L | Revisions keep same number (01_v1, 01_v2) |
| Spawn agent hardcoded value | H | H | Update spawn-agent to use passed number |

## Recommendations

### Implementation Order

1. **Task 310**: Update state-management-schema.md with `next_artifact_number` field
2. **Task 311**: Update artifact-formats.md with unified numbering semantics
3. **Task 312**: Update skills and agents:
   - skill-researcher: Read/increment field, pass to agent
   - skill-planner: Read (current-1), pass to agent
   - skill-implementer: Read (current-1), pass to agent
   - All agents: Use passed number in artifact paths

### Alternative Considered: Filename-Based Sequencing

Instead of tracking in state.json, always scan directory to determine next number.

**Pros**: No state management needed
**Cons**: Doesn't support unified numbering (can't know plan should use same number as research), slower, race conditions possible

**Rejected**: State-based tracking is cleaner and enables the unified semantics.

### Alternative Considered: Per-Type Fields

Track separate fields: `next_research_number`, `next_plan_number`, `next_summary_number`.

**Pros**: More granular control
**Cons**: Doesn't achieve the goal of unified numbering across types, more complex

**Rejected**: Unified field achieves the goal more elegantly.

## Appendix

### Searched Paths

- `.claude/rules/artifact-formats.md`
- `.claude/rules/state-management.md`
- `.claude/context/reference/state-management-schema.md`
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/agents/general-research-agent.md`
- `.claude/agents/planner-agent.md`
- `.claude/agents/general-implementation-agent.md`
- `.claude/agents/spawn-agent.md`
- `.claude/commands/revise.md`
- `specs/archive/032_*/reports/*` (multi-research example)
- `specs/308_*/` (current naming pattern)

### Example State Update

**Before research (task created)**:
```json
{
  "project_number": 500,
  "status": "not_started",
  "next_artifact_number": 1
}
```

**After first research**:
```json
{
  "project_number": 500,
  "status": "researched",
  "next_artifact_number": 2,
  "artifacts": [
    {"type": "research", "path": ".../reports/01_initial.md"}
  ]
}
```

**After plan (same round)**:
```json
{
  "project_number": 500,
  "status": "planned",
  "next_artifact_number": 2,
  "artifacts": [
    {"type": "research", "path": ".../reports/01_initial.md"},
    {"type": "plan", "path": ".../plans/01_implementation.md"}
  ]
}
```

**After blocked and second research**:
```json
{
  "project_number": 500,
  "status": "researched",
  "next_artifact_number": 3,
  "artifacts": [
    {"type": "research", "path": ".../reports/01_initial.md"},
    {"type": "plan", "path": ".../plans/01_implementation.md"},
    {"type": "research", "path": ".../reports/02_followup.md"}
  ]
}
```
