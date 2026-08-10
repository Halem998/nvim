# Implementation Plan: Task #216

- **Task**: 216 - refactor_grant_implement_output_to_grants_dir
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [01_grant-implement-routing.md](../reports/01_grant-implement-routing.md)
- **Artifacts**: plans/02_grant-refactor-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Refactor the grant workflow to remove the `--finish` flag from `/grant` command and route grant task implementation through `/implement N`. When `/implement N` is invoked on a `language="grant"` task, it will assemble all intermediate artifacts (drafts, budgets) from `specs/{NNN}_{SLUG}/` and write the final grant output to a new `grants/{NN}_{grant-slug}/` directory in the project root.

### Research Integration

Integrated findings from research report 01_grant-implement-routing.md:
- `/implement` command uses language-based routing; grant language needs explicit routing
- Current skill-grant has five workflow types (funder_research, proposal_draft, budget_develop, finish, progress_track)
- The "finish" workflow should be replaced with "assemble" workflow triggered by /implement
- Recommended Option A: Add grant routing to extension manifest and /implement routing table

## Goals & Non-Goals

**Goals**:
- Remove `--finish` flag and Finish Mode from `/grant` command
- Add `assemble` workflow type to grant-agent (replacing finish)
- Enable `/implement N` to route grant tasks through skill-grant with workflow_type=assemble
- Create final output in `grants/{NN}_{grant-slug}/` directory
- Update all documentation to reflect new workflow

**Non-Goals**:
- Modifying core `/implement` command (use extension manifest routing instead)
- Changing other grant workflows (funder_research, proposal_draft, budget_develop, progress_track)
- Changing the intermediate artifact storage in specs/

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing grant tasks using --finish | Medium | Low | Document migration path; --finish was rarely used |
| /implement routing complexity | Medium | Medium | Use manifest.json routing; test thoroughly |
| Missing intermediate artifacts during assemble | High | Medium | Add validation in assemble workflow before assembly |

## Implementation Phases

### Phase 1: Remove --finish from grant.md command [NOT STARTED]

**Goal**: Remove Finish Mode section and all --finish references from the /grant command

**Tasks**:
- [ ] Remove `| Finish | /grant N --finish PATH ["prompt"] | Export materials to PATH |` from Modes table (line 19)
- [ ] Remove `| N --finish PATH [prompt]` from mode detection logic (lines 45)
- [ ] Remove entire Finish Mode section (lines 265-328)
- [ ] Update recommended workflow output (lines 138-143) to show `/implement {N}` instead of `--finish`
- [ ] Update duplicate recommended workflow output (lines 391-396)
- [ ] Update Budget Mode "Next:" suggestion (line 260) from `--finish` to `/implement`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Remove finish mode, update recommended workflow

**Verification**:
- Finish Mode section no longer exists in grant.md
- No references to `--finish` remain in grant.md
- Recommended workflow shows `/implement N` as final step

---

### Phase 2: Clean up skill-grant/SKILL.md routing [NOT STARTED]

**Goal**: Remove finish workflow type from all routing tables and case statements in skill-grant

**Tasks**:
- [ ] Remove `finish` from workflow type routing table (line 47)
- [ ] Remove `finish` from workflow_type validation case statement (lines 107-113)
- [ ] Remove `finish|progress_track` handling from preflight status determination (lines 148-151)
- [ ] Remove `finish` from postflight status mapping table (lines 299-312)
- [ ] Remove `finish` case from postflight status determination (lines 329-334)
- [ ] Remove `finish` -> `export` artifact type mapping (lines 377-380)
- [ ] Remove `finish` commit action mapping (lines 427-430)
- [ ] Remove finish-specific error handling (lines 557-564)
- [ ] Remove Finish/Export Success return format (lines 497-503)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Remove all finish workflow references

**Verification**:
- No references to `finish` workflow type remain in SKILL.md
- Workflow type validation no longer accepts `finish`
- All case statements only have: funder_research, proposal_draft, budget_develop, progress_track

---

### Phase 3: Remove finish from grant-agent.md [NOT STARTED]

**Goal**: Remove finish workflow references from grant-agent

**Tasks**:
- [ ] Verify grant-agent Stage 2 routing diagram (lines 142-163) does not include finish (research shows it may already be absent)
- [ ] Remove `finish` from Status Values by Workflow table if present (lines 359-364)
- [ ] Confirm agent description accurately reflects four workflows (lines 9-11)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/agents/grant-agent.md` - Remove any finish references

**Verification**:
- No references to `finish` workflow in grant-agent.md
- Only funder_research, proposal_draft, budget_develop, progress_track workflows documented

---

### Phase 4: Add assemble workflow to grant-agent [NOT STARTED]

**Goal**: Add new assemble workflow type for /implement routing that collects artifacts and writes to grants/ directory

**Tasks**:
- [ ] Update agent overview (lines 9-11) to mention assemble workflow
- [ ] Add `assemble` to Stage 2 routing diagram after progress_track (around line 163):
  ```
  +--- assemble
       Tools: Read + Write + Glob
       Output: grants/{NN}_{grant-slug}/
          - narrative.md (assembled from drafts)
          - budget.md (assembled from budgets)
          - checklist.md (submission checklist)
  ```
- [ ] Add assemble to Workflow Routing Table (lines 167-172)
- [ ] Add assemble workflow execution section under Stage 4 (after Progress Tracking Workflow)
- [ ] Update Stage 5: Create Artifacts to include assemble output structure
- [ ] Add `assemble` to Status Values by Workflow table with success status `exported`
- [ ] Add assemble return format example in Stage 7

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/agents/grant-agent.md` - Add assemble workflow

**Verification**:
- Assemble workflow documented with clear execution steps
- Output directory structure defined: `grants/{NN}_{grant-slug}/`
- Status transitions properly defined (implementing -> exported -> completed)

---

### Phase 5: Add assemble routing to skill-grant [NOT STARTED]

**Goal**: Enable skill-grant to handle assemble workflow type for /implement routing

**Tasks**:
- [ ] Add `assemble` to workflow type routing table (after progress_track)
- [ ] Add `assemble` to workflow_type validation case statement (lines 107-113)
- [ ] Add preflight status handling for assemble (implementing -> completed)
- [ ] Add postflight status mapping for assemble workflow
- [ ] Add `assemble` -> `grant` artifact type mapping
- [ ] Add `assemble` commit action: "assemble grant materials"
- [ ] Add Assemble Success return format
- [ ] Document that assemble is triggered via /implement, not /grant command

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Add assemble workflow routing

**Verification**:
- skill-grant accepts assemble workflow_type
- Proper status transitions: implementing -> completed
- Commit message uses "assemble grant materials"

---

### Phase 6: Update manifest.json for /implement routing [NOT STARTED]

**Goal**: Add grant language routing to extension manifest so /implement can route to skill-grant

**Tasks**:
- [ ] Read current manifest.json to understand structure
- [ ] Add routing section for implement command:
  ```json
  "routing": {
    "implement": {
      "grant": "skill-grant:assemble"
    }
  }
  ```
- [ ] Verify manifest.json is valid JSON after edit

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Add implement routing

**Verification**:
- manifest.json is valid JSON
- routing.implement.grant points to skill-grant:assemble

---

### Phase 7: Update EXTENSION.md documentation [NOT STARTED]

**Goal**: Update documentation to reflect new workflow without --finish

**Tasks**:
- [ ] Remove Finish Mode (--finish) section (lines 70-83)
- [ ] Update Recommended Workflow section (lines 116-124) to use /implement as final step
- [ ] Update recommended workflow in Task Creation example (lines 26-38) to show /implement
- [ ] Add note about grants/ output directory structure
- [ ] Update Language Routing table if needed

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Update documentation

**Verification**:
- No references to --finish flag remain
- Recommended workflow ends with /implement N
- grants/ output directory documented

## Testing & Validation

- [ ] Verify grant.md has no --finish references (grep test)
- [ ] Verify skill-grant validates assemble workflow type
- [ ] Verify grant-agent includes assemble workflow execution logic
- [ ] Verify manifest.json is valid JSON and includes routing
- [ ] Test /grant task creation shows updated recommended workflow
- [ ] Manual trace: Verify workflow from /grant "Desc" through /implement N produces grants/ output

## Artifacts & Outputs

- `.claude/extensions/present/commands/grant.md` - Finish mode removed
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - finish removed, assemble added
- `.claude/extensions/present/agents/grant-agent.md` - assemble workflow added
- `.claude/extensions/present/manifest.json` - implement routing added
- `.claude/extensions/present/EXTENSION.md` - documentation updated

## Rollback/Contingency

If issues arise:
1. Git revert all changes to the present extension
2. Tasks created with the new workflow can still be manually assembled
3. The --finish flag can be re-added if critical issues found

The clean-break approach is appropriate here since:
- Grant extension is internal tooling
- --finish flag usage is minimal/rare
- No external API contracts affected
