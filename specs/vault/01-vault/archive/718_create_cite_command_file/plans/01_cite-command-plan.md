# Implementation Plan: Create cite.md Command File

- **Task**: 718 - Create cite.md command file
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/718_create_cite_command_file/reports/01_cite-command-research.md
- **Artifacts**: plans/01_cite-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `/cite` command file at `.claude/extensions/literature/commands/cite.md` following the established command file pattern from `literature.md` in the same directory. The command parses four invocation modes (task-only, freeform text, task+gaps, task+focus), validates task existence against `specs/state.json`, and delegates to `skill-cite` with structured arguments.

### Research Integration

Research report (`01_cite-command-research.md`) established:
- Frontmatter format: `description`, `allowed-tools: Skill`, `argument-hint`
- Argument parsing uses flag-first approach with `--gaps` as additive modifier
- Task validation via jq against `specs/state.json`
- Delegation passes structured args (`task_num`, `show_gaps`, `description`) to skill-cite
- literature.md is the authoritative reference pattern for file structure and XML blocks

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create cite.md with correct YAML frontmatter (description, allowed-tools, argument-hint)
- Implement argument parsing for all four invocation modes
- Validate task existence in state.json when task number is provided
- Delegate to skill-cite with structured arguments
- Match the structure and conventions of literature.md exactly

**Non-Goals**:
- Modifying skill-cite's SKILL.md or any other file
- Adding /cite to CLAUDE.md command tables (separate task)
- Implementing citation verification logic (that lives in skill-cite)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Argument format mismatch with skill-cite parser | M | L | Research confirmed skill-cite parses task_num, show_gaps, description from structured args |
| Missing edge case in freeform vs task mode detection | L | L | Parsing order defined: strip --gaps, find numeric token, remaining text is description |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Create cite.md Command File [COMPLETED]

**Goal**: Create the complete `/cite` command file with frontmatter, argument parsing, workflow execution, and error handling sections.

**Tasks**:
- [ ] Create file at `.claude/extensions/literature/commands/cite.md`
- [ ] Add YAML frontmatter:
  - `description: Verify citations in task artifacts against Literature/ index and Zotero library`
  - `allowed-tools: Skill`
  - `argument-hint: N [--gaps] ["focus text"] | "description text"`
- [ ] Write `# Command: /cite` header with Purpose, Layer, Delegates To fields
- [ ] Write `## Argument Parsing` section with `<argument_parsing>` XML block:
  - Strip `--gaps` flag, set `show_gaps` boolean
  - Extract first numeric token as `task_num`
  - Remaining non-flag text becomes `description` (focus or freeform)
  - Error if no task_num and no description (bare `/cite` invocation)
- [ ] Write `## Workflow Execution` section with `<workflow_execution>` XML block:
  - Step 1: Validate arguments (task_num lookup in state.json via jq when present)
  - Step 2: Delegate to skill-cite with `args: "task_num={N} show_gaps={true|false} description={text}"`
  - Step 3: Present results (pass through from skill-cite)
- [ ] Write `## Error Handling` section with `<error_handling>` XML block:
  - No arguments: usage error with examples
  - Task N not found in state.json: error message
  - Skill failure: return error details
- [ ] Verify file structure matches literature.md conventions (XML blocks, heading hierarchy, step numbering)

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/commands/cite.md` - New file (create)

**Verification**:
- File exists at correct path
- Frontmatter parses correctly (3 fields present)
- All four invocation modes have parsing logic
- Task validation uses jq against specs/state.json
- Delegation args match what skill-cite Step 1 expects
- Structure mirrors literature.md (same XML blocks, heading levels, step numbering)

## Testing & Validation

- [ ] File exists at `.claude/extensions/literature/commands/cite.md`
- [ ] Frontmatter contains description, allowed-tools, argument-hint fields
- [ ] Argument parsing handles: `/cite N`, `/cite "text"`, `/cite N --gaps`, `/cite N "focus"`
- [ ] Task validation section uses jq to check state.json
- [ ] Skill delegation uses `skill: "skill-cite"` with structured args
- [ ] Error handling covers: no args, task not found, skill failure
- [ ] File structure matches literature.md pattern (XML blocks, step numbering)

## Artifacts & Outputs

- `.claude/extensions/literature/commands/cite.md` - The command file
- `specs/718_create_cite_command_file/plans/01_cite-command-plan.md` - This plan

## Rollback/Contingency

Delete `.claude/extensions/literature/commands/cite.md` since it is a new file with no existing content to revert.
