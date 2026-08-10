# Implementation Plan: Task #216 (Revised)

- **Task**: 216 - refactor_grant_implement_output_to_grants_dir
- **Version**: 2 (revised to integrate --revise flag)
- **Status**: [COMPLETE]
- **Effort**: 4-5 hours
- **Dependencies**: None
- **Research Inputs**:
  - [01_grant-implement-routing.md](../reports/01_grant-implement-routing.md)
  - [03_grant-revise-flag.md](../reports/03_grant-revise-flag.md)
- **Artifacts**: plans/04_grant-refactor-revised.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Refactor the grant workflow to:
1. Remove the `--finish` flag from `/grant` command
2. Route grant task implementation through `/implement N` to assemble final output in `grants/{N}_{slug}/`
3. Add `--revise` flag to create revision tasks for existing grants

### Research Integration

**Primary research** (01_grant-implement-routing.md):
- `/implement` uses language-based routing; grant needs explicit routing
- Replace "finish" workflow with "assemble" workflow triggered by /implement
- Use extension manifest routing for clean integration

**Supplemental research** (03_grant-revise-flag.md):
- Grant numbering uses task number (no separate grants/state.json needed)
- Revision tasks link via `parent_grant` and `revises_directory` fields
- Revision assembly modifies existing grant directory

## Goals & Non-Goals

**Goals**:
- Remove `--finish` flag and Finish Mode from `/grant` command
- Add `assemble` workflow type to grant-agent (replacing finish)
- Enable `/implement N` to route grant tasks through skill-grant with workflow_type=assemble
- Create final output in `grants/{N}_{grant-slug}/` directory
- Add `--revise N "desc"` flag to create revision tasks for existing grants
- Update all documentation to reflect new workflow

**Non-Goals**:
- Modifying core `/implement` command (use extension manifest routing instead)
- Changing other grant workflows (funder_research, proposal_draft, budget_develop, progress_track)
- Changing the intermediate artifact storage in specs/
- Creating separate grants/state.json (use task numbers for grant identification)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing grant tasks using --finish | Medium | Low | Document migration path; --finish was rarely used |
| /implement routing complexity | Medium | Medium | Use manifest.json routing; test thoroughly |
| Missing intermediate artifacts during assemble | High | Medium | Add validation in assemble workflow before assembly |
| Grant directory renamed/moved after creation | Medium | Low | Store revises_directory explicitly; validate at --revise time |
| Multiple concurrent revision tasks | Medium | Low | Document that only one revision should be active per grant |

## Implementation Phases

### Phase 1: Remove --finish from grant.md command [COMPLETED]

**Goal**: Remove Finish Mode section and all --finish references from the /grant command

**Tasks**:
- [ ] Remove `| Finish | /grant N --finish PATH ["prompt"] | Export materials to PATH |` from Modes table (line 19)
- [ ] Remove `| N --finish PATH [prompt]` from mode detection logic (line 45)
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

### Phase 2: Clean up skill-grant/SKILL.md routing [COMPLETED]

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

### Phase 3: Remove finish from grant-agent.md [COMPLETED]

**Goal**: Remove finish workflow references from grant-agent

**Tasks**:
- [ ] Verify grant-agent Stage 2 routing diagram (lines 142-163) does not include finish
- [ ] Remove `finish` from Status Values by Workflow table if present (lines 359-364)
- [ ] Confirm agent description accurately reflects four workflows (lines 9-11)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/agents/grant-agent.md` - Remove any finish references

**Verification**:
- No references to `finish` workflow in grant-agent.md
- Only funder_research, proposal_draft, budget_develop, progress_track workflows documented

---

### Phase 4: Add assemble workflow to grant-agent [COMPLETED]

**Goal**: Add new assemble workflow type for /implement routing that collects artifacts and writes to grants/ directory

**Tasks**:
- [ ] Update agent overview (lines 9-11) to mention assemble workflow
- [ ] Add `assemble` to Stage 2 routing diagram after progress_track:
  ```
  +--- assemble
       Tools: Read + Write + Glob
       Output: grants/{N}_{grant-slug}/
          - narrative.md (assembled from drafts)
          - budget.md (assembled from budgets)
          - checklist.md (submission checklist)
  ```
- [ ] Add assemble to Workflow Routing Table (lines 167-172)
- [ ] Add assemble workflow execution section under Stage 4 (after Progress Tracking Workflow)
- [ ] Update Stage 5: Create Artifacts to include assemble output structure
- [ ] Add `assemble` to Status Values by Workflow table with success status `assembled`
- [ ] Add assemble return format example in Stage 7
- [ ] Handle `is_revision` flag: when present, read existing grant from `revises_directory` and merge changes

**Timing**: 60 minutes

**Files to modify**:
- `.claude/extensions/present/agents/grant-agent.md` - Add assemble workflow with revision support

**Verification**:
- Assemble workflow documented with clear execution steps
- Output directory structure defined: `grants/{N}_{grant-slug}/`
- Revision mode (is_revision=true) documented
- Status transitions properly defined

---

### Phase 5: Add assemble routing to skill-grant [COMPLETED]

**Goal**: Enable skill-grant to handle assemble workflow type for /implement routing

**Tasks**:
- [ ] Add `assemble` to workflow type routing table (after progress_track)
- [ ] Add `assemble` to workflow_type validation case statement
- [ ] Add preflight status handling for assemble (implementing -> completed)
- [ ] Add postflight status mapping for assemble workflow
- [ ] Add `assemble` -> `grant` artifact type mapping
- [ ] Add `assemble` commit action: "assemble grant materials"
- [ ] Add Assemble Success return format
- [ ] Pass `is_revision` and `revises_directory` to grant-agent when task has `parent_grant` field
- [ ] Document that assemble is triggered via /implement, not /grant command

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Add assemble workflow routing with revision support

**Verification**:
- skill-grant accepts assemble workflow_type
- Proper status transitions: implementing -> completed
- Revision context passed to agent when parent_grant field exists
- Commit message uses "assemble grant materials"

---

### Phase 6: Update manifest.json for /implement routing [COMPLETED]

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

### Phase 7: Update EXTENSION.md documentation (core changes) [COMPLETED]

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

---

### Phase 8: Add --revise flag to /grant command [COMPLETED]

**Goal**: Enable creating revision tasks for existing grants

**Tasks**:
- [ ] Add `| Revise | /grant --revise N "desc" | Create revision task for grant N |` to Modes table
- [ ] Add mode detection for `--revise` flag in grant.md:
  - Pattern: `--revise N "description"` where N is the original grant's task number
- [ ] Implement Revise Mode section:
  ```markdown
  ## Revise Mode (--revise)

  Create a new task to revise an existing grant.

  ### Syntax
  `/grant --revise N "description of changes"`

  ### CHECKPOINT 1: GATE IN
  1. Generate Session ID
  2. Parse arguments: Extract task number N and revision description
  3. Validate grant exists:
     - Lookup task N in state.json (or archive)
     - Verify grants/{N}_{slug}/ directory exists
  4. ABORT if grant not found

  ### STAGE 2: CREATE REVISION TASK
  1. Get next_project_number from state.json
  2. Create slug from revision description
  3. Update state.json with new task:
     - language: "grant"
     - parent_grant: N
     - revises_directory: "grants/{N}_{slug}"
  4. Update TODO.md with task entry including "Parent Grant: Task #N"

  ### CHECKPOINT 2: COMMIT
  Git commit with "task {NEW_N}: create revision for grant {N}"
  ```
- [ ] Update state.json schema to accept `parent_grant` and `revises_directory` fields
- [ ] Update skill-grant Stage 4 to detect `parent_grant` field and pass revision context
- [ ] Update grant-agent assemble workflow to handle revision mode

**Timing**: 60 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md` - Add Revise Mode
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Pass revision context to agent
- `.claude/extensions/present/agents/grant-agent.md` - Handle revision assembly

**Verification**:
- `/grant --revise N "desc"` creates new task with parent_grant field
- New task TODO.md entry shows "Parent Grant: Task #N"
- state.json entry includes `revises_directory` path
- `/implement` on revision task updates existing grant directory

---

### Phase 9: Update EXTENSION.md documentation (--revise) [COMPLETED]

**Goal**: Document the --revise flag and revision workflow

**Tasks**:
- [ ] Add Revise Mode section after Budget Mode:
  ```markdown
  #### Revise Mode (--revise)
  ```bash
  /grant --revise N "description"
  ```
  Creates a new task to revise an existing grant (where N is the original grant task number).
  ```
- [ ] Add Revision Workflow section showing full lifecycle
- [ ] Document `parent_grant` and `revises_directory` fields
- [ ] Add example showing revision workflow

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Document --revise flag

**Verification**:
- --revise flag documented with examples
- Revision workflow clearly explained
- New state fields documented

---

## Testing & Validation

- [ ] Verify grant.md has no --finish references (grep test)
- [ ] Verify skill-grant validates assemble workflow type
- [ ] Verify grant-agent includes assemble workflow execution logic
- [ ] Verify manifest.json is valid JSON and includes routing
- [ ] Test /grant task creation shows updated recommended workflow
- [ ] Manual trace: Verify workflow from /grant "Desc" through /implement N produces grants/ output
- [ ] Test /grant --revise N "desc" creates task with parent_grant field
- [ ] Verify revision task /implement updates existing grant directory

## Artifacts & Outputs

- `.claude/extensions/present/commands/grant.md` - Finish mode removed, revise mode added
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - finish removed, assemble added with revision support
- `.claude/extensions/present/agents/grant-agent.md` - assemble workflow with revision mode
- `.claude/extensions/present/manifest.json` - implement routing added
- `.claude/extensions/present/EXTENSION.md` - documentation fully updated

## Rollback/Contingency

If issues arise:
1. Git revert all changes to the present extension
2. Tasks created with the new workflow can still be manually assembled
3. The --finish flag can be re-added if critical issues found

The clean-break approach is appropriate here since:
- Grant extension is internal tooling
- --finish flag usage is minimal/rare
- No external API contracts affected
