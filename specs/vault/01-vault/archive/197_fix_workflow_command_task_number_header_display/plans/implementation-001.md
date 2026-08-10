# Implementation Plan: Fix Workflow Command Task Number Header Display

- **Task**: OC_197 - fix_workflow_command_task_number_header_display
- **Status**: [NOT STARTED]
- **Effort**: 45 minutes
- **Dependencies**: None
- **Research Inputs**: reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

This task fixes a display bug in the opencode workflow commands (research.md, plan.md, implement.md) where task headers do not properly show the actual task number. Currently, headers either don't display at all or show a generic placeholder 'OC_NNN' instead of the specific task number like 'OC_193'. The fix involves adding explicit "Display header" steps to the preflight sections of all three workflow command files.

### Research Integration

Based on research-001.md, the bug has two components:
- **Component 1**: All three workflow commands lack explicit instructions to display headers with actual task numbers
- **Component 2**: implement.md is missing "Display header" from its Critical Notes section entirely

The fix pattern is to add a display header step at the start of each preflight section with the format: "[Action] task OC_{N}: {project_name}"

## Goals & Non-Goals

**Goals**:
- Add "Display header" step to research.md preflight section
- Add "Display header" step to plan.md preflight section
- Add "Display header" step to implement.md preflight section
- Add "Display header" to implement.md Critical Notes section

**Non-Goals**:
- No changes to actual workflow execution logic
- No changes to research, plan, or implementation behavior beyond header display
- No new files created

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Markdown formatting issues | Medium | Low | Careful editing, verify structure preserved |
| Wrong line numbers in research | Low | Low | Read files first to verify exact locations |
| Conflicts with other changes | Low | Low | Small scope, minimal surface area |

## Implementation Phases

### Phase 1: Fix research.md Preflight Header [NOT STARTED]

**Goal**: Add explicit "Display header" step at start of preflight section

**Tasks**:
- [ ] Read `.opencode/commands/research.md` around line 43
- [ ] Add "Display header" step at start of "### 3. Execute Preflight" section
- [ ] Format: `**Display header**:`
  ```
  [Researching] task OC_{N}: {project_name}
  ```

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/commands/research.md` - Add header display step at preflight start

**Verification**:
- Verify the step appears at the correct location
- Verify formatting matches existing markdown style

---

### Phase 2: Fix plan.md Preflight Header [NOT STARTED]

**Goal**: Add explicit "Display header" step at start of preflight section

**Tasks**:
- [ ] Read `.opencode/commands/plan.md` around line 42
- [ ] Add "Display header" step at start of "### 3. Execute Preflight" section
- [ ] Format: `**Display header**:`
  ```
  [Planning] task OC_{N}: {project_name}
  ```

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/commands/plan.md` - Add header display step at preflight start

**Verification**:
- Verify the step appears at the correct location
- Verify formatting matches existing markdown style

---

### Phase 3: Fix implement.md Preflight Header [NOT STARTED]

**Goal**: Add "Display header" step and update Critical Notes

**Tasks**:
- [ ] Read `.opencode/commands/implement.md` around line 51
- [ ] Add "Display header" step at start of "### 4. Execute Preflight" section
- [ ] Update Critical Notes section to include "Display header"
- [ ] Format for preflight: `**Display header**:`
  ```
  [Implementing] task OC_{N}: {project_name}
  ```

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/commands/implement.md` - Add header display step and update Critical Notes

**Verification**:
- Verify the step appears at the correct location
- Verify Critical Notes section updated
- Verify formatting matches existing markdown style

---

### Phase 4: Verification [NOT STARTED]

**Goal**: Verify all changes applied correctly

**Tasks**:
- [ ] Review all three modified files
- [ ] Confirm headers display in correct locations
- [ ] Verify formatting consistency
- [ ] Run /research, /plan, /implement commands to test

**Timing**: 10 minutes

**Verification**:
- All three files have display header steps
- Critical Notes in implement.md updated
- Commands execute without errors
- Headers display actual task numbers (not OC_NNN)

## Testing & Validation

- [ ] research.md displays header with actual task number
- [ ] plan.md displays header with actual task number
- [ ] implement.md displays header with actual task number
- [ ] implement.md Critical Notes includes "Display header"
- [ ] No formatting errors in modified files
- [ ] Commands execute without errors

## Artifacts & Outputs

- Modified `.opencode/commands/research.md`
- Modified `.opencode/commands/plan.md`
- Modified `.opencode/commands/implement.md`

## Rollback/Contingency

If changes cause issues:
1. Revert individual file changes using git: `git checkout -- .opencode/commands/{file}.md`
2. Or manually remove the added header display steps
3. All changes are isolated to documentation/display only - no runtime logic affected
