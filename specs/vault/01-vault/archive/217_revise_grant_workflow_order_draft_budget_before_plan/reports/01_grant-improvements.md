# Research Report: Task #217

**Task**: 217 - Revise the /grant command workflow order and identify other improvements
**Started**: 2026-03-16T00:00:00Z
**Completed**: 2026-03-16T00:15:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of grant extension files
**Artifacts**: specs/217_revise_grant_workflow_order_draft_budget_before_plan/reports/01_grant-improvements.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The workflow order is documented inconsistently across 3 locations, with plan appearing before draft/budget in some places
- The correct workflow should place draft and budget BEFORE plan (exploratory phases inform planning)
- Found 5 additional improvement areas: consistency issues, missing validation, documentation gaps, error handling, and UX improvements

## Context & Scope

Analyzed all grant extension files to identify:
1. Locations where workflow order is documented
2. Consistency issues across command, skill, agent, and extension documentation
3. Opportunities for improvement beyond workflow order

### Files Examined

| File | Lines | Role |
|------|-------|------|
| `.claude/extensions/present/commands/grant.md` | 474 | Main command definition |
| `.claude/extensions/present/skills/skill-grant/SKILL.md` | 649 | Skill implementation |
| `.claude/extensions/present/agents/grant-agent.md` | 590 | Agent workflows |
| `.claude/extensions/present/EXTENSION.md` | 217 | User documentation |
| `.claude/extensions/present/manifest.json` | 37 | Extension configuration |

## Findings

### 1. Workflow Order Documentation (Primary Finding)

#### Current Documented Order

**Location 1: grant.md (lines 137-143)** - Task Creation Output
```
Recommended workflow:
1. /research {N} - Research funders and requirements
2. /plan {N} - Create proposal plan          <-- PLAN BEFORE DRAFT/BUDGET
3. /grant {N} --draft - Draft narrative sections
4. /grant {N} --budget - Develop budget
5. /implement {N} - Assemble grant materials to grants/{N}_{slug}/
```

**Location 2: grant.md (lines 444-456)** - Output Format Section
```
Recommended workflow:
1. /research {N} - Research funders and requirements
2. /plan {N} - Create proposal plan          <-- PLAN BEFORE DRAFT/BUDGET
3. /grant {N} --draft - Draft narrative sections
4. /grant {N} --budget - Develop budget
5. /implement {N} - Assemble grant materials to grants/{N}_{slug}/
```

**Location 3: EXTENSION.md (lines 127-134)** - Recommended Workflow
```
1. **Create task**: `/grant "Research NSF CAREER funding for AI interpretability"`
2. **Research funders**: `/research 500` (routes to skill-grant)
3. **Create plan**: `/plan 500` (routes to skill-grant)   <-- PLAN BEFORE DRAFT/BUDGET
4. **Draft narrative**: `/grant 500 --draft ["focus prompt"]`
5. **Develop budget**: `/grant 500 --budget ["budget guidance"]`
6. **Assemble materials**: `/implement 500` (creates grants/500_{slug}/)
```

**Location 4: grant.md Revise Mode (lines 385-388)** - Revision workflow
```
Recommended workflow:
1. /grant {NEW_N} --draft "Focus on sections needing revision"
2. /grant {NEW_N} --budget "Update budget items as needed"
3. /implement {NEW_N} - Update existing grant directory
```
Note: Revision workflow correctly omits /plan (revisions update existing grants).

**Location 5: EXTENSION.md Revise Mode (lines 89-93)** - Revision workflow
```
Recommended workflow:
1. /grant 505 --draft "Focus on sections needing revision"
2. /grant 505 --budget "Update budget items as needed"
3. /implement 505 - Update existing grant directory
```
Note: Consistent with grant.md revision workflow.

#### Correct Workflow Order

The workflow should be:
```
1. /grant "Description" - Create task
2. /research N - Research funders
3. /grant N --draft - Draft narrative (exploratory)
4. /grant N --budget - Develop budget (exploratory)
5. /plan N - Create plan informed by drafts
6. /implement N - Assemble to grants/{N}_{slug}/
```

**Rationale**: Draft and budget are exploratory phases that inform planning. The plan should:
- Be aware of what sections have been drafted
- Incorporate budget constraints into scope
- Reference existing artifacts in planning decisions

### 2. Consistency Issues

#### Status Transition Inconsistencies

**grant.md Draft Mode (lines 176-179)**:
- Preflight status: researched, planned, partial (allows planned)
- Postflight status: planned

**Issue**: If task is already "planned", running --draft transitions to "planned" again (no-op, but confusing semantically).

**SKILL.md Status Mapping (lines 317-329)**:
| Workflow | Meta Status | Final state.json | Final TODO.md |
|----------|-------------|-----------------|---------------|
| proposal_draft | drafted | planned | [PLANNED] |
| budget_develop | drafted | planned | [PLANNED] |

**Issue**: Both draft and budget set status to "planned", making it impossible to distinguish whether:
- Only draft was completed
- Only budget was completed
- Both were completed

#### Artifact Path Inconsistencies

**grant.md (lines 200-201)**: `specs/{NNN}_{SLUG}/drafts/`
**SKILL.md (lines 178-182)**: `drafts/{MM}_narrative-draft.md`
**grant-agent.md (lines 345-349)**: `specs/{NNN}_{SLUG}/drafts/{MM}_narrative-draft.md`

**Finding**: Paths are consistent, just documented at different levels of specificity.

#### Parameter Name Inconsistency

**grant.md (line 188)**: `args: "task_number={N} workflow_type=proposal_draft focus={draft_prompt}"`
**SKILL.md (lines 63-71)**: Documents `focus` as the parameter for guidance

**Finding**: Parameter names are consistent (`focus` is used everywhere).

### 3. Missing Features

#### No Draft/Budget Completion Tracking

Currently no way to know if a task has:
- Draft created
- Budget created
- Both created

**Suggestion**: Add `draft_status` and `budget_status` fields to task state, or use artifact detection.

#### No Prerequisite Validation for --draft

**grant.md (lines 176-179)**: Draft mode validates status is researched, planned, or partial.

**Missing**: No validation that research exists before drafting. User could run `--draft` before `/research`.

#### No Prerequisite Validation for Assemble

**grant-agent.md (lines 296-301)**: Assemble validates prerequisites.

**Missing in grant.md/SKILL.md**: No explicit validation that draft and budget exist before assemble.

### 4. Documentation Gaps

#### Undocumented Status "drafted"

**SKILL.md (line 324)**: Meta Status "drafted" is used but never documented as a valid task status.

**Question**: Is "drafted" a real status or an internal return value? If internal, this is fine. If a task status, it should be in the status markers list.

#### Core Command Routing Table Mismatch

**grant.md (lines 416-420)**:
```
| Command | Routes To | Purpose |
|---------|-----------|---------|
| /research N | skill-grant (funder_research) | Research funders |
| /plan N | skill-grant (proposal_draft) | Create proposal plan |
| /implement N | skill-grant | Execute plan phases |
```

**Issue**: `/plan N` routes to `proposal_draft` workflow? This seems incorrect. Planning should create a plan, not a proposal draft.

**EXTENSION.md (lines 115-119)**:
```
| Command | Routes To | Purpose |
|---------|-----------|---------|
| /research N | skill-grant (funder_research) | Research funders |
| /plan N | skill-grant | Create proposal plan |
| /implement N | skill-grant | Execute plan phases |
```

**Difference**: EXTENSION.md does not specify which workflow `/plan` uses.

**Actual behavior**: Need to check manifest.json routing. Current manifest only defines implement routing:
```json
"routing": {
  "implement": {
    "grant": "skill-grant:assemble"
  }
}
```

**Finding**: No routing defined for /plan or /research in manifest. They may fall back to default skill-planner/skill-researcher, not skill-grant.

#### Missing progress_track Documentation

**grant.md**: Legacy mode mentions `progress_track` but no `--progress` flag exists.

**SKILL.md (lines 47-48)**: Documents `progress_track` workflow type.

**Issue**: How is `progress_track` invoked? Only via deprecated legacy syntax?

### 5. Error Handling Issues

#### Inconsistent Error Message Formats

**grant.md (lines 429-439)**:
```
### Task Creation Errors
- Invalid description: Return guidance on expected format
- State update failure: Log error, do not commit partial state
```

**SKILL.md (lines 545-596)**: More detailed error handling with specific return formats.

**Finding**: Error handling is more detailed in SKILL.md, but the formats could be more consistent.

#### No Error Handling for Revision Mode Prerequisites

**grant.md (lines 303-315)**: Validates grant task exists and directory exists.

**Missing**: What if the original grant task is still in progress? Should revision be allowed on incomplete grants?

### 6. UX Improvements

#### Draft/Budget Flags Could Be Clearer

Current:
```
/grant N --draft ["prompt"]
/grant N --budget ["prompt"]
```

Alternative (more intuitive for users):
```
/grant N draft ["prompt"]
/grant N budget ["prompt"]
```

**Finding**: The current `--flag` syntax is fine and consistent with other commands.

#### "Next Step" Guidance Could Be Smarter

**grant.md (line 213)**: `Next: /grant {N} --budget`

**Improvement**: Could check if budget already exists and suggest `/plan` or `/implement` instead.

**grant.md (line 260)**: `Next: /implement {N}`

**Improvement**: Could check if plan exists and suggest `/plan` first if missing.

#### Progress Visibility

**Current**: No way to see grant completion status at a glance.

**Suggestion**: `/grant N --status` or enhance `/task --show N` to display grant-specific progress.

## Decisions

1. **Workflow order change is confirmed**: Draft and budget should precede plan
2. **Status "drafted" is internal**: Return value from agent, not a task status
3. **Manifest routing is incomplete**: Only implement routing defined, research/plan may use defaults
4. **progress_track is legacy-only**: No modern flag to invoke it

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Changing workflow order breaks existing docs | Medium | Update all 3 locations atomically |
| Users confused by status transitions | Low | Consider adding draft_completed/budget_completed flags |
| Missing /plan routing in manifest | Medium | Verify behavior or add explicit routing |

## Context Extension Recommendations

None - this is a meta task for .claude/ system improvements.

## Appendix

### Files Requiring Updates for Workflow Order

1. `.claude/extensions/present/commands/grant.md`
   - Lines 137-143 (Task Creation Output)
   - Lines 444-456 (Output Format Section)

2. `.claude/extensions/present/EXTENSION.md`
   - Lines 127-134 (Recommended Workflow)

### Summary of All Issues Found

| Category | Issue | Severity | Location |
|----------|-------|----------|----------|
| Workflow | Plan before draft/budget | High | 3 locations |
| Consistency | draft/budget both set "planned" status | Medium | SKILL.md |
| Missing | No draft/budget completion tracking | Low | state model |
| Missing | No prerequisite validation for draft | Medium | grant.md |
| Missing | No prerequisite validation for assemble in command | Medium | grant.md |
| Documentation | Routing table mismatch (plan->proposal_draft?) | Medium | grant.md |
| Documentation | progress_track not accessible via flag | Low | grant.md |
| Error | No validation for revision on incomplete grants | Low | grant.md |
| UX | Next step guidance not context-aware | Low | grant.md |
