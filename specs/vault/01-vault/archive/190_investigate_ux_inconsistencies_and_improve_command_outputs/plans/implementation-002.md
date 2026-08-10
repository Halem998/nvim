# Implementation Plan: Task #190 (Revised)

- **Task**: 190 - Investigate UX inconsistencies and improve command outputs
- **Status**: [COMPLETED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: research-001.md, research-002.md, research-003.md
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This revised plan addresses UX inconsistencies across the .claude/ agent system, now incorporating interactive selection standardization from research-003.md. The implementation spans two main areas: (1) output format standardization with 3 templates and verbosity reduction, and (2) interactive selection pattern standardization with a new dedicated standard document. The plan retains the 6 output-focused phases from v001 and adds 3 new phases for interactive selection standardization.

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

From research-003.md:
- 22 files using AskUserQuestion patterns with 6 distinct selector styles
- No dedicated interactive-selection standard exists
- `/task --review` uses text-based selection instead of AskUserQuestion
- Proposed standardization: AskUserQuestion schema, header/label/description guidelines, threshold rules

## Goals & Non-Goals

**Goals**:
- Standardize task number format across all commands (`Task #{N}`)
- Create and document 3 output templates in command-output.md
- Reduce /todo output from 30-40 lines to 15-20 lines
- Reduce /review output from 30-50 lines to 20-25 lines
- Consolidate next step patterns to 2 formats: single (`Next: /cmd {N}`) and multiple (`Next Steps:`)
- Create new interactive-selection.md standard document
- Migrate `/task --review` from text-based to AskUserQuestion pattern
- Standardize header/label/description formats across interactive commands

**Non-Goals**:
- Changing skill return formats (already consistent)
- Adding validation lint scripts (low priority, deferred)
- Restructuring /meta 7-stage interview (complex, low ROI)
- Changing /review tiered selection (already well-designed)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking user expectations | Low | Low | Changes are refinements, not redesigns |
| Template doesn't fit edge case | Medium | Low | Templates are guidelines; edge cases can deviate with justification |
| Verbose output had hidden value | Low | Low | Move details to artifacts, keep summaries |
| Scope creep during implementation | Medium | Medium | Strict adherence to priority levels from research |
| `/task --review` migration complexity | Medium | Low | Current implementation is simple; migration is straightforward |

## Implementation Phases

### Phase 1: Update command-output.md Standard [COMPLETED]

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

### Phase 2: Apply Simple Template (4-6 lines) [COMPLETED]

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

### Phase 3: Apply Standard Template (8-12 lines) [COMPLETED]

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

### Phase 4: Apply Complex Template - Verbosity Reduction [COMPLETED]

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

### Phase 5: Apply Complex Template - Multi-Task Commands [COMPLETED]

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

### Phase 6: Create Interactive Selection Standard [COMPLETED]

**Goal**: Create new `.claude/context/core/standards/interactive-selection.md` with comprehensive guidelines

**Tasks**:
- [ ] Create interactive-selection.md with AskUserQuestion schema standardization
- [ ] Document question format guidelines (action confirmation, selection prompt, choice prompt, filter prompt)
- [ ] Document header format guidelines (1-3 word noun phrases, Title Case)
- [ ] Document label format guidelines (action phrases, descriptive nouns, all/skip options)
- [ ] Document description format guidelines (consequence, item details, count summary, source reference)
- [ ] Add threshold guidelines table (1-10 direct, 11-20 consider grouping, 21-50 add "Select all", 51-100 require narrowing, >100 hard limit)
- [ ] Add confirmation vs selection pattern decision tree
- [ ] Reference /fix-it and /meta as implementation examples
- [ ] Update context/index.json with new standard entry

**Timing**: 1.5 hours

**Files to create**:
- `.claude/context/core/standards/interactive-selection.md` - New standard document

**Files to modify**:
- `.claude/context/index.json` - Add entry for new standard

**Verification**:
- interactive-selection.md contains all 6 guideline sections
- Threshold table covers all ranges (1-10, 11-20, 21-50, 51-100, >100)
- Decision tree distinguishes confirmation from selection patterns
- index.json has valid entry with appropriate load_when conditions

---

### Phase 7: Migrate /task --review to AskUserQuestion [COMPLETED]

**Goal**: Replace text-based "all"/"none" selection in `/task --review` with standard AskUserQuestion pattern

**Tasks**:
- [ ] Identify current text-based selection code in /task.md
- [ ] Replace with AskUserQuestion multiSelect pattern
- [ ] Add "Select all" option when item count exceeds 20
- [ ] Ensure empty selection = no action (consistent with /fix-it)
- [ ] Update output section to reflect new interactive flow

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/task.md` - Update --review mode to use AskUserQuestion

**Verification**:
- /task --review uses AskUserQuestion with multiSelect: true
- Options include proper label/description format per interactive-selection.md
- "Select all" appears when >20 items
- Empty selection behaves correctly (no tasks selected)

---

### Phase 8: Update Interactive Commands to Follow Standard [COMPLETED]

**Goal**: Ensure /fix-it, /todo, and other interactive commands follow the new interactive-selection.md standard

**Tasks**:
- [ ] Review /fix-it.md interactive sections against new standard
- [ ] Review /todo.md orphan handling and CLAUDE.md suggestion prompts
- [ ] Standardize header formats to 1-3 word noun phrases
- [ ] Verify all labels use consistent patterns (action phrase or descriptive noun)
- [ ] Ensure descriptions follow consequence/detail/count patterns

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/fix-it.md` - Align with interactive-selection.md
- `.claude/commands/todo.md` - Align with interactive-selection.md

**Verification**:
- All AskUserQuestion usages follow interactive-selection.md patterns
- Header formats are consistent across commands
- Label and description formats are standardized

---

### Phase 9: Final Verification and Cross-Reference [COMPLETED]

**Goal**: Verify all changes are consistent and cross-referenced

**Tasks**:
- [ ] Read all 11 command files and verify Output sections
- [ ] Verify command-output.md template assignment table is accurate
- [ ] Verify no `**Next Steps**:` (bold) remains in any command
- [ ] Verify no `Task #{N}:` (with colon after) remains in any command
- [ ] Verify interactive-selection.md is referenced appropriately
- [ ] Document any intentional deviations from templates/standards
- [ ] Update .claude/CLAUDE.md if needed (add reference to interactive-selection.md)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Add reference to interactive-selection.md in Context Discovery section (if appropriate)

**Verification**:
- All 11 commands follow their assigned output template
- All next step patterns use correct format
- All task number formats use `Task #{N}` (no trailing colon)
- All interactive selections follow interactive-selection.md patterns
- Cross-references between standards are accurate

## Testing & Validation

### Output Standardization Tests
- [ ] Grep for `\*\*Next Steps\*\*:` in commands/ - should return 0 results
- [ ] Grep for `Task #[0-9]+:` (with colon after number) in commands/ - should return 0 results
- [ ] Manual review of each command's Output section

### Interactive Selection Tests
- [ ] Verify /task --review uses AskUserQuestion (not text input)
- [ ] Verify interactive-selection.md is syntactically valid
- [ ] Verify index.json entry for interactive-selection.md is valid JSON

### Cross-Reference Tests
- [ ] Verify command-output.md template table matches actual command implementations
- [ ] Verify .claude/CLAUDE.md references are accurate

## Artifacts & Outputs

- `specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/plans/implementation-002.md` (this file)
- `.claude/context/core/standards/interactive-selection.md` (new standard)
- `specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/summaries/implementation-summary-YYYYMMDD.md` (created on completion)

## Rollback/Contingency

All changes are to markdown documentation files with no runtime impact. If changes cause confusion:
1. Revert via `git checkout HEAD~1 -- .claude/commands/ .claude/context/core/formats/command-output.md .claude/context/core/standards/interactive-selection.md`
2. Review feedback and adjust templates/standards
3. Re-apply with modifications

For interactive selection changes specifically:
- /task --review can be reverted independently if the AskUserQuestion migration causes issues
- The new interactive-selection.md can be revised without affecting command functionality
