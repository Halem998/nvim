# Implementation Plan: Fix Workflow Command Task Number Header Display

- **Task**: OC_197 - fix_workflow_command_task_number_header_display
- **Status**: [COMPLETED]
- **Date**: 2026-03-13 (Revised)
- **Feature**: Add explicit header display to workflow command preflight sections
- **Estimated Hours**: 0.5-1 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [02_opencode-best-practices.md](../reports/02_opencode-best-practices.md)
- **Dependencies**: None
- **Type**: meta

## Overview

This task fixes a display bug in the opencode workflow commands (research.md, plan.md, implement.md) where task headers do not properly show the actual task number. The fix involves adding explicit "Display header" steps to the preflight sections of all three workflow command files.

### Research Integration

**From research-001.md:**
- All three workflow commands lack explicit instructions to display headers with actual task numbers
- implement.md is missing "Display header" from its Critical Notes section entirely

**From 02_opencode-best-practices.md:**
- OpenCode has NO built-in framework-level header display mechanisms
- CLI UX best practices emphasize immediate feedback (<100ms)
- Explicit "Display header" steps are the correct approach
- Header should be displayed FIRST in preflight, BEFORE status updates

## Goals & Non-Goals

**Goals**:
- Add "Display header" step to research.md preflight section (FIRST step)
- Add "Display header" step to plan.md preflight section (FIRST step)
- Add "Display header" step to implement.md preflight section (FIRST step)
- Add "Display header" to implement.md Critical Notes section

**Non-Goals**:
- No changes to actual workflow execution logic
- No framework-level changes to OpenCode
- No changes to command-output.md standard (future enhancement)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Markdown formatting issues | Medium | Low | Careful editing, verify structure preserved |
| Placeholder not substituted | Medium | Low | Use `{N}` and `{project_name}` variables extracted at GATE IN |
| Header display timing | Low | Low | Place header as FIRST preflight step |

## Implementation Phases

### Phase 1: Fix research.md [COMPLETED]

**Goal**: Add "Display header" as FIRST step in preflight section

**Steps**:
1. Read `.opencode/commands/research.md`
2. Locate "### 3. Execute Preflight" section
3. Add header display as FIRST step (before status updates):

```markdown
**Display header**:
```
[Researching] Task OC_{N}: {project_name}
```
```

**Files to modify**:
- `.opencode/commands/research.md`

**Verification**:
- Header step appears FIRST in preflight section
- Format uses `[Action]` prefix with task number and name

---

### Phase 2: Fix plan.md [COMPLETED]

**Goal**: Add "Display header" as FIRST step in preflight section

**Steps**:
1. Read `.opencode/commands/plan.md`
2. Locate "### 3. Execute Preflight" section
3. Add header display as FIRST step:

```markdown
**Display header**:
```
[Planning] Task OC_{N}: {project_name}
```
```

**Files to modify**:
- `.opencode/commands/plan.md`

**Verification**:
- Header step appears FIRST in preflight section
- Format consistent with Phase 1

---

### Phase 3: Fix implement.md [COMPLETED]

**Goal**: Add "Display header" step AND update Critical Notes

**Steps**:
1. Read `.opencode/commands/implement.md`
2. Locate "### 4. Execute Preflight" section
3. Add header display as FIRST step:

```markdown
**Display header**:
```
[Implementing] Task OC_{N}: {project_name}
```
```

4. Locate Critical Notes section
5. Add "Display header" to preflight summary (missing per research-001.md)

**Files to modify**:
- `.opencode/commands/implement.md` (preflight section AND Critical Notes)

**Verification**:
- Header step appears FIRST in preflight section
- Critical Notes includes "Display header" mention
- Format consistent with Phases 1-2

---

### Phase 4: Verification [COMPLETED]

**Goal**: Verify all changes and test functionality

**Steps**:
1. Review all three modified files for consistency
2. Verify header format is identical across commands
3. Test with a new task:
   - Run `/research {test_task}` - verify header shows
   - Run `/plan {test_task}` - verify header shows
   - Run `/implement {test_task}` - verify header shows

**Verification Criteria**:
- All commands display `[Action] Task OC_{N}: {project_name}` immediately
- No "OC_NNN" placeholders in displayed output
- Headers appear BEFORE status update messages

## Testing & Validation

- [ ] research.md displays header with actual task number FIRST
- [ ] plan.md displays header with actual task number FIRST
- [ ] implement.md displays header with actual task number FIRST
- [ ] implement.md Critical Notes includes "Display header"
- [ ] Format consistent: `[Action] Task OC_{N}: {project_name}`

## Artifacts & Outputs

- Modified `.opencode/commands/research.md`
- Modified `.opencode/commands/plan.md`
- Modified `.opencode/commands/implement.md`

## Future Enhancement (Out of Scope)

Per 02_opencode-best-practices.md recommendations, consider adding a "Preflight Header Format" section to `command-output.md` standard to formalize this requirement for all workflow commands.

## Rollback/Contingency

If changes cause issues:
1. Revert: `git checkout -- .opencode/commands/{file}.md`
2. Changes are documentation-only, no runtime logic affected
