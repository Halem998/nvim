# Phase Synchronization Protocol

**Version**: 1.0
**Last Updated**: 2026-03-04
**Applies to**: OpenCode `/implement` command and skill-implementer

## Overview

The phase synchronization protocol ensures that three critical files remain consistent during task implementation:

1. **specs/state.json** - Task metadata and high-level status
2. **specs/TODO.md** - Task overview and progress tracking
3. **specs/{NNN}_*/plans/implementation-*.md** - Detailed phase tracking

When these files are synchronized, the system can:
- Resume interrupted implementations from the correct point
- Provide accurate progress visibility
- Maintain audit trails of work completed
- Enable reliable recovery from failures

## The Three Files

### 1. state.json

**Purpose**: Central task registry tracking all active and completed projects.

**Status Field**:
- `"planned"` - Task ready to start
- `"implementing"` - Currently being worked on
- `"completed"` - All phases finished successfully
- `"abandoned"` - Task stopped before completion

**When Updated**:
- `/implement` starts → Set to `"implementing"`
- Implementation completes → Set to `"completed"`

### 2. TODO.md

**Purpose**: Human-readable task list with status markers.

**Status Markers**:
- `[PLANNED]` - Task ready to start
- `[IMPLEMENTING]` - Currently in progress
- `[COMPLETED]` - All work finished
- `[PARTIAL]` - Started but blocked

**When Updated**:
- `/implement` starts → Change to `[IMPLEMENTING]`
- Implementation completes → Change to `[COMPLETED]`

### 3. Plan File (implementation-NNN.md)

**Purpose**: Detailed phase-by-phase execution plan.

**Phase Status Markers**:
- `[NOT STARTED]` - Phase not yet begun
- `[IN PROGRESS]` - Phase currently executing
- `[COMPLETED]` - Phase finished successfully
- `[PARTIAL]` - Phase started but blocked

**When Updated**:
- Phase begins → Update to `[IN PROGRESS]`
- Phase completes → Update to `[COMPLETED]`
- Phase fails → Update to `[PARTIAL]`

## Phase Status Lifecycle

```
[NOT STARTED] → [IN PROGRESS] → [COMPLETED] (success path)
                              ↘ [PARTIAL] (failure path)
```

### Status Definitions

| Status | Meaning | Can Resume? |
|--------|---------|-------------|
| [NOT STARTED] | Phase waiting to begin | Yes (will execute) |
| [IN PROGRESS] | Phase currently executing | Yes (will retry) |
| [COMPLETED] | Phase successfully finished | No (skip) |
| [PARTIAL] | Phase started but incomplete | Yes (will resume) |

## Synchronization Workflow

### 1. Implementation Start

When `/implement {N}` is invoked:

```
1. Read current state from all three files
2. Update state.json: status → "implementing"
3. Update TODO.md: [PLANNED] → [IMPLEMENTING]
4. Identify first non-completed phase in plan file
5. Begin execution
```

**Files Modified**: state.json, TODO.md

### 2. Phase Execution

For each phase in the plan:

```
1. Skip if status is [COMPLETED]
2. Update plan file: [NOT STARTED] → [IN PROGRESS]
3. Execute phase steps
4. Verify completion criteria
5. Update plan file: [IN PROGRESS] → [COMPLETED]
6. Commit phase changes
7. Report completion
```

**Files Modified**: implementation-NNN.md

### 3. Implementation Complete

When all phases are finished:

```
1. Update state.json: status → "completed"
2. Update TODO.md: [IMPLEMENTING] → [COMPLETED]
3. Create summary artifact
4. Final commit
```

**Files Modified**: state.json, TODO.md

## Resume Behavior

The plan file's phase status markers serve as the **source of truth** for resume points.

### Resume Algorithm

```
For each phase in plan file:
  If phase status is [COMPLETED]:
    Skip (already done)
  Else if phase status is [IN PROGRESS]:
    Resume from this phase (retry)
  Else if phase status is [PARTIAL]:
    Resume from this phase (continue)
  Else ([NOT STARTED]):
    Execute normally
```

### Example Resume Scenario

**Initial State After Interruption**:
```markdown
### Phase 1: Setup [COMPLETED]
### Phase 2: Core Implementation [IN PROGRESS]
### Phase 3: Testing [NOT STARTED]
```

**Resume Behavior**:
1. Phase 1: Skipped (already completed)
2. Phase 2: Resumed from beginning (status was IN PROGRESS)
3. Phase 3: Executed normally

## Postflight Verification

The skill-implementer includes a verification stage (Stage 5) that ensures consistency:

### Verification Process

1. **Read plan file** - Extract all phase status markers
2. **Count completed phases** - Tally [COMPLETED] markers
3. **Compare with metadata** - Check against metadata.phases_completed
4. **Detect mismatches** - Identify any inconsistencies
5. **Auto-correct** - Update plan file if needed

### Recovery Logic

```
If metadata.phases_completed > plan [COMPLETED] count:
  → Update plan to mark additional phases as [COMPLETED]
  → Log correction

If metadata.phases_completed < plan [COMPLETED] count:
  → Log warning
  → Do not downgrade (completed is final)
```

## Responsibilities

### /implement Command

**Responsibilities**:
- Update state.json and TODO.md at start/end
- Read plan file to identify resume point
- Execute phases in order
- Update phase statuses in plan file
- Commit after each phase

### general-implementation-agent

**Responsibilities**:
- Execute phase steps as specified in plan
- Update phase status to [IN PROGRESS] at start
- Update phase status to [COMPLETED] on success
- Update phase status to [PARTIAL] on failure
- Perform verification steps

### skill-implementer

**Responsibilities**:
- Orchestrate the implementation workflow
- Load context and validate inputs
- Delegate to general-implementation-agent
- Perform postflight verification
- Ensure all three files are synchronized

## Common Issues and Solutions

### Issue 1: Phases Not Marked as Completed

**Symptom**: Task shows as completed in state.json but phases in plan file still marked [IN PROGRESS]

**Cause**: Agent failed to update plan file before exiting

**Solution**: 
1. Postflight verification detects mismatch
2. Plan file is auto-corrected based on metadata
3. Log entry created documenting the correction

### Issue 2: Resume from Wrong Phase

**Symptom**: Implementation starts from Phase 1 when it should resume from Phase 3

**Cause**: Plan file phase statuses not properly updated

**Solution**:
1. Review plan file and manually correct phase statuses
2. Ensure [COMPLETED] markers are accurate
3. Re-run `/implement`

### Issue 3: TODO.md Out of Sync

**Symptom**: TODO.md shows [IMPLEMENTING] but task is already completed

**Cause**: Postflight update to TODO.md failed

**Solution**:
1. Manually update TODO.md status to [COMPLETED]
2. Add summary link if missing
3. Check state.json for consistency

## Best Practices

### For Skill Developers

1. **Always update phase status** - Mark [IN PROGRESS] at start, [COMPLETED] at end
2. **Commit per phase** - Never batch multiple phases into one commit
3. **Verify before marking complete** - Ensure all phase criteria are met
4. **Use [PARTIAL] for failures** - Don't leave as [IN PROGRESS] if blocked

### For Task Runners

1. **Check plan file before resume** - Verify phase statuses match your understanding
2. **Review commits** - Ensure per-phase commits are being created
3. **Monitor TODO.md** - Watch for status synchronization issues
4. **Report discrepancies** - If files are out of sync, investigate and fix

## Example: Correct Implementation Flow

**Task**: 100 - Sample Task

### Step 1: Start Implementation

**Command**: `/implement 100`

**Changes**:
- state.json: `"status": "implementing"`
- TODO.md: `[IMPLEMENTING]`

### Step 2: Execute Phase 1

**Plan file**:
```markdown
### Phase 1: Setup [IN PROGRESS]
```

**Work**: Perform setup tasks

**After completion**:
```markdown
### Phase 1: Setup [COMPLETED]
```

**Commit**: `task {N} phase 1: Setup`

### Step 3: Execute Phase 2

**Plan file**:
```markdown
### Phase 2: Core Work [IN PROGRESS]
```

**Work**: Perform core implementation

**After completion**:
```markdown
### Phase 2: Core Work [COMPLETED]
```

**Commit**: `task {N} phase 2: Core Work`

### Step 4: Complete Implementation

**Changes**:
- state.json: `"status": "completed"`
- TODO.md: `[COMPLETED]`
- New file: `summaries/implementation-summary-YYYYMMDD.md`

**Final commit**: `task {N}: finalize implementation and create summary`

## Troubleshooting Guide

### Check Synchronization Status

```bash
# Check state.json
jq '.active_projects[] | select(.project_number == 100)' specs/state.json

# Check TODO.md
grep -A 3 "100" specs/TODO.md

# Check plan file phases
grep "^### Phase" specs/100_*/plans/implementation-*.md
```

### Fix Out-of-Sync Phase Status

If plan file phases don't match expected state:

```bash
# Edit plan file to correct phase statuses
vim specs/100_*/plans/implementation-001.md

# Update markers:
# **Status**: [NOT STARTED] → [IN PROGRESS] → [COMPLETED]
```

### Force Re-synchronization

If automatic verification fails:

1. Manually update state.json status
2. Manually update TODO.md status marker
3. Manually update plan file phase statuses
4. Commit changes: `git commit -m "manual sync: fix phase statuses"`

## Summary

The phase synchronization protocol ensures that:

1. **state.json** tracks high-level task status (planned/implementing/completed)
2. **TODO.md** provides human-readable progress indicators
3. **Plan file** serves as the authoritative source for resume points

By maintaining consistency across these three files, the system provides reliable resume functionality, accurate progress tracking, and clear audit trails for all implementation work.

**Key Takeaway**: The plan file's phase status markers are the **source of truth**. Always keep them synchronized with actual progress to ensure reliable resume behavior.
