# Implementation Plan: Task #190

- **Task**: 190 - Investigate UX inconsistencies and improve command outputs
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: research-001.md, research-002.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task standardizes command output UX across the .claude/ agent system. Two research reports identified 6 distinct "next step" patterns, inconsistent task number formatting, and excessive verbosity in /todo and /review commands. The implementation will update command-output.md with 3 output templates (Simple, Standard, Complex), then apply these templates to all 11 commands, consolidating patterns to a consistent, concise format.

### Research Integration

From research-001.md:
- 6 distinct "next step" patterns identified - consolidate to 2
- Existing command-output.md standard exists but is not consistently applied
- Status marker presentation varies across commands

From research-002.md:
- Task number format: standardize on `Task #{N}` (no colon after)
- Artifact format: labeled paths for console (`Report: {path}`), markdown links for files
- 3 output templates proposed: Simple (4-6 lines), Standard (8-12 lines), Complex (15-25 lines)
- /todo and /review need verbosity reduction

## Goals & Non-Goals

**Goals**:
- Standardize task number format across all commands (`Task #{N}`)
- Create and document 3 output templates in command-output.md
- Reduce /todo output from 30-40 lines to 15-20 lines
- Reduce /review output from 30-50 lines to 20-25 lines
- Consolidate next step patterns to 2 formats: single (`Next: /cmd {N}`) and multiple (`Next Steps:`)
- Ensure all commands follow their assigned template

**Non-Goals**:
- Changing skill return formats (already consistent)
- Changing interactive selection patterns (already use AskUserQuestion consistently)
- Adding validation lint scripts (low priority, deferred)
- Creating new command-authoring documentation (low priority, deferred)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking user expectations | Low | Low | Changes are refinements, not redesigns |
| Template doesn't fit edge case | Medium | Low | Templates are guidelines; edge cases can deviate with justification |
| Verbose output had hidden value | Low | Low | Move details to artifacts, keep summaries |
| Scope creep during implementation | Medium | Medium | Strict adherence to priority levels from research |

## Implementation Phases

### Phase 1: Update command-output.md Standard [NOT STARTED]

**Goal**: Establish the canonical output standard with 3 templates

**Tasks**:
- [ ] Add Template A (Simple: 4-6 lines) with example
- [ ] Add Template B (Standard: 8-12 lines) with example
- [ ] Add Template C (Complex: 15-25 lines) with example
- [ ] Update header format section to specify `Task #{N}` (no colon)
- [ ] Add section documenting next step patterns (single vs multiple)
- [ ] Add template assignment table mapping commands to templates

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/core/formats/command-output.md` - Add templates section, update header format

**Verification**:
- command-output.md contains 3 clearly defined templates with examples
- Header format section specifies `Task #{N}` format
- Template assignment table lists all 11 commands

---

### Phase 2: Apply Simple Template (4-6 lines) [NOT STARTED]

**Goal**: Update commands assigned to Simple template: /research, /plan, /task

**Tasks**:
- [ ] Update /research.md Output section to match Simple template
- [ ] Update /plan.md Output section to match Simple template
- [ ] Verify /task.md Output section (already concise, may need minor adjustments)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/research.md` - Update Output section
- `.claude/commands/plan.md` - Update Output section
- `.claude/commands/task.md` - Verify/update Output section

**Verification**:
- Each command's Output section matches Simple template structure
- Task number format is `Task #{N}` (no colon after number)
- Next step format is `Next: /command {N}`

---

### Phase 3: Apply Standard Template (8-12 lines) [NOT STARTED]

**Goal**: Update commands assigned to Standard template: /implement, /revise, /errors

**Tasks**:
- [ ] Update /implement.md Output section to match Standard template
- [ ] Update /revise.md Output section to match Standard template
- [ ] Update /errors.md Output section to match Standard template
- [ ] Change /errors.md next step from `Next: /implement {N} to fix` to `Next: /implement {N}`

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/implement.md` - Update Output section
- `.claude/commands/revise.md` - Update Output section
- `.claude/commands/errors.md` - Update Output section, fix next step format

**Verification**:
- Each command's Output section matches Standard template structure
- Metrics section present where applicable
- Next step format is `Next: /command {N}`

---

### Phase 4: Apply Complex Template - Verbosity Reduction [NOT STARTED]

**Goal**: Update verbose commands assigned to Complex template: /todo, /review

**Tasks**:
- [ ] Update /todo.md Output section to use grouping and counts instead of item lists
- [ ] Target /todo output: 15-20 lines max
- [ ] Update /review.md Output section to summarize issues, move details to report
- [ ] Target /review output: 20-25 lines max
- [ ] Ensure both use `Next Steps:` (capitalized, no bold) for multiple steps

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/commands/todo.md` - Major Output section rewrite with grouping
- `.claude/commands/review.md` - Major Output section rewrite with summarization

**Verification**:
- /todo output example in command file is 15-20 lines
- /review output example in command file is 20-25 lines
- Details are referenced to artifact files, not inline
- Next step format uses `Next Steps:` (capitalized)

---

### Phase 5: Apply Complex Template - Multi-Task Commands [NOT STARTED]

**Goal**: Update remaining commands assigned to Complex template: /meta, /fix-it, /refresh

**Tasks**:
- [ ] Update /meta.md Output section to use `Next Steps:` format (not bold)
- [ ] Update /fix-it.md Output section to use `Next Steps:` format (not bold)
- [ ] Verify /refresh.md Output section (already well-structured)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/commands/meta.md` - Update Next Steps format
- `.claude/commands/fix-it.md` - Update Next Steps format
- `.claude/commands/refresh.md` - Verify Output section

**Verification**:
- Next step format uses `Next Steps:` (not `**Next Steps**:`)
- Output examples follow Complex template structure

---

### Phase 6: Final Verification and Cross-Reference [NOT STARTED]

**Goal**: Verify all changes are consistent and cross-referenced

**Tasks**:
- [ ] Read all 11 command files and verify Output sections
- [ ] Verify command-output.md template assignment table is accurate
- [ ] Verify no `**Next Steps**:` (bold) remains in any command
- [ ] Verify no `Task #{N}:` (with colon after) remains in any command
- [ ] Document any intentional deviations from templates

**Timing**: 30 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- All 11 commands follow their assigned template
- All next step patterns use correct format
- All task number formats use `Task #{N}` (no trailing colon)

## Testing & Validation

- [ ] Grep for `\*\*Next Steps\*\*:` in commands/ - should return 0 results
- [ ] Grep for `Task #[0-9]+:` in commands/ - should return 0 results (except in examples showing OLD format)
- [ ] Manual review of each command's Output section
- [ ] Verify command-output.md is self-consistent

## Artifacts & Outputs

- `specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/plans/implementation-001.md` (this file)
- `specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/summaries/implementation-summary-YYYYMMDD.md` (created on completion)

## Rollback/Contingency

All changes are to markdown documentation files with no runtime impact. If changes cause confusion:
1. Revert via `git checkout HEAD~1 -- .claude/commands/ .claude/context/core/formats/command-output.md`
2. Review feedback and adjust templates
3. Re-apply with modifications
