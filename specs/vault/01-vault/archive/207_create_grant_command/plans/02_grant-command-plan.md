# Implementation Plan: Task #207

- **Task**: 207 - create_grant_command
- **Status**: [COMPLETED]
- **Effort**: 1.5-2 hours
- **Dependencies**: Task #206 (skill-grant wrapper must exist)
- **Research Inputs**: [01_grant-command-research.md](../reports/01_grant-command-research.md)
- **Artifacts**: plans/02_grant-command-plan.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Create the `/grant` command for the grant extension, enabling users to execute grant workflows (funder research, proposal drafting, budget development, progress tracking) via a simple slash command interface. The command follows the checkpoint-based execution pattern (GATE IN -> DELEGATE -> GATE OUT) and delegates to skill-grant, which handles status updates and git commits internally.

### Research Integration

Key findings from research report:
- Command should be placed at `.claude/extensions/grant/commands/grant.md`
- Use simplified 2-checkpoint pattern (skill-grant handles commits)
- Workflow types: funder_research, proposal_draft, budget_develop, progress_track
- Each workflow type maps to specific status transitions
- Extension manifest.json needs updating to register the command

## Goals & Non-Goals

**Goals**:
- Create a functional `/grant` command following existing command patterns
- Support all four workflow types with appropriate argument parsing
- Integrate with skill-grant via Skill tool delegation
- Provide clear error messages for invalid inputs
- Update manifest.json to register the new command

**Non-Goals**:
- Modifying skill-grant behavior (already implemented in Task #206)
- Creating new agent definitions
- Implementing workflow logic (delegated to skill-grant)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Argument parsing edge cases | Medium | Medium | Comprehensive validation in GATE IN with clear error messages |
| Workflow type validation | Low | Low | Validate against known enum values before delegation |
| Manifest.json merge conflicts | Low | Low | Use jq for atomic JSON updates |
| Extension not loaded at runtime | Medium | Low | Add validation check for extension presence |

## Implementation Phases

### Phase 1: Create Command File Structure [COMPLETED]

**Goal**: Create the `/grant` command file with proper frontmatter and skeleton structure

**Tasks**:
- [ ] Create `.claude/extensions/grant/commands/` directory if not exists
- [ ] Create `grant.md` with YAML frontmatter (description, allowed-tools, argument-hint, model)
- [ ] Add command header and purpose documentation
- [ ] Document argument format: `TASK_NUMBER WORKFLOW_TYPE [FOCUS]`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/grant/commands/grant.md` - Create new file

**Verification**:
- File exists with valid YAML frontmatter
- Frontmatter includes: description, allowed-tools, argument-hint, model

---

### Phase 2: Implement CHECKPOINT 1 (GATE IN) [COMPLETED]

**Goal**: Implement preflight validation including session ID generation, task lookup, and workflow type validation

**Tasks**:
- [ ] Add session ID generation pattern
- [ ] Implement task lookup via jq from state.json
- [ ] Add task existence validation
- [ ] Add status validation (allow: not_started, researched, planned, partial, blocked)
- [ ] Add workflow_type validation (enum: funder_research, proposal_draft, budget_develop, progress_track)
- [ ] Define ABORT conditions with user-friendly messages

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/grant/commands/grant.md` - Add CHECKPOINT 1 section

**Verification**:
- Session ID generation follows `sess_{timestamp}_{random}` format
- Task lookup query is valid jq syntax
- All four workflow types are validated
- Error messages are clear and actionable

---

### Phase 3: Implement STAGE 2 (DELEGATE) [COMPLETED]

**Goal**: Implement skill-grant delegation with proper argument passing

**Tasks**:
- [ ] Add Skill tool invocation pattern
- [ ] Pass required arguments: task_number, workflow_type, focus_prompt, session_id
- [ ] Document expected skill behavior (status updates, artifact creation)
- [ ] Add delegation success/failure handling

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/grant/commands/grant.md` - Add STAGE 2 section

**Verification**:
- Skill invocation uses correct skill name: `skill-grant`
- All required arguments are passed
- Delegation transitions are documented

---

### Phase 4: Implement CHECKPOINT 2 (GATE OUT) [COMPLETED]

**Goal**: Implement postflight verification without commit (skill-grant handles commits)

**Tasks**:
- [ ] Add return validation (status, summary, artifacts fields)
- [ ] Add artifact existence verification
- [ ] Add status verification based on workflow_type:
  - funder_research -> researched
  - proposal_draft, budget_develop -> planned
  - progress_track -> no status change
- [ ] Add RETRY logic for validation failures
- [ ] Note: Skip CHECKPOINT 3 (skill-grant handles commits)

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/grant/commands/grant.md` - Add CHECKPOINT 2 section

**Verification**:
- Return validation covers all required fields
- Workflow-to-status mapping is correct
- No CHECKPOINT 3 (confirmed skill handles commits)

---

### Phase 5: Add Output and Error Handling [COMPLETED]

**Goal**: Complete command with output formatting and error handling sections

**Tasks**:
- [ ] Add Output section with success message format
- [ ] Add workflow-specific output messages (research, draft, budget, progress)
- [ ] Add Error Handling section covering:
  - GATE IN failures (task not found, invalid status, invalid workflow)
  - DELEGATE failures (skill error, timeout)
  - GATE OUT failures (missing artifacts, status mismatch)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/grant/commands/grant.md` - Add Output and Error Handling sections

**Verification**:
- Output format matches existing command patterns
- Error handling covers all checkpoints
- Error messages include recovery guidance

---

### Phase 6: Update Extension Manifest [COMPLETED]

**Goal**: Register the new command in the grant extension manifest

**Tasks**:
- [ ] Update `.claude/extensions/grant/manifest.json` to add `grant.md` to `provides.commands`
- [ ] Verify JSON remains valid after update

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/grant/manifest.json` - Update provides.commands array

**Verification**:
- manifest.json is valid JSON
- `provides.commands` includes `"grant.md"`

## Testing & Validation

- [ ] Command file has valid YAML frontmatter
- [ ] All workflow types are documented and validated
- [ ] Skill invocation pattern matches existing commands
- [ ] manifest.json is valid JSON with command registered
- [ ] Manual test: invoke `/grant 207 funder_research` (requires extension loaded)

## Artifacts & Outputs

- `.claude/extensions/grant/commands/grant.md` - The /grant command implementation
- `.claude/extensions/grant/manifest.json` - Updated with command registration
- `specs/207_create_grant_command/summaries/03_grant-command-summary.md` - Implementation summary (created on completion)

## Rollback/Contingency

1. Delete `.claude/extensions/grant/commands/grant.md`
2. Revert `provides.commands` in manifest.json to empty array `[]`
3. No state.json or TODO.md changes needed for rollback (command is isolated)
