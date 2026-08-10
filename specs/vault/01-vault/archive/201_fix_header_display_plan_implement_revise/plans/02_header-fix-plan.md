# Implementation Plan: Fix Header Display in /plan, /implement, and /revise Commands

- **Task**: 201 - fix_header_display_plan_implement_revise
- **Status**: [COMPLETE]
- **Effort**: 0.5-1 hour
- **Dependencies**: None
- **Research Inputs**: [01_header-display-fix.md](../reports/01_header-display-fix.md)
- **Artifacts**: plans/02_header-fix-plan.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/system/artifact-management.md
  - .opencode/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan addresses the header display inconsistency between the `/research` command (which correctly shows task numbers like "[Researching] Task OC_72: project_name") and the `/plan`, `/implement`, and `/revise` commands (which do not). The fix involves adding a header instruction block immediately after the frontmatter in each command file, following the proven pattern from `/research`.

### Research Integration

The research report identified that:
- The `/research` command has a working header instruction block at lines 5-9
- The pattern uses prohibition-first language ("DO NOT start with a markdown heading")
- All three target commands lack this top-of-file instruction
- The fix is straightforward: copy and adapt the pattern for each command

## Goals & Non-Goals

**Goals**:
- Add header instruction block to `/plan` command with "[Planning]" action verb
- Add header instruction block to `/implement` command with "[Implementing]" action verb
- Add header instruction block to `/revise` command with "[Revising]" action verb
- Ensure consistent format across all four task-related commands

**Non-Goals**:
- Modifying any other command behavior
- Changing the header format (keeping existing "[Action] Task OC_N: project_name" pattern)
- Adding header instructions to commands that are not task-scoped (e.g., /todo, /review)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Instruction may be ignored by some models | Medium | Low | Use strong prohibition language ("DO NOT") matching /research pattern |
| Format inconsistency across commands | Low | Low | Use identical instruction block structure, only changing action verb |
| Disruption to existing command flow | Low | Very Low | Adding content at top does not modify existing logic |

## Implementation Phases

### Phase 1: Add Header Instruction to /plan Command [COMPLETED]

**Goal**: Add the header instruction block to `.opencode/commands/plan.md` immediately after frontmatter

**Tasks**:
- [ ] Edit `.opencode/commands/plan.md`
- [ ] Insert header instruction block after line 3 (after frontmatter closing `---`)
- [ ] Use "[Planning]" as the action verb
- [ ] Add horizontal rule separator after instruction block

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/commands/plan.md` - Insert header instruction block after line 3

**Content to insert** (after line 3, before line 5):
```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Planning] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS - never output "OC_N" or "OC_NN" literally.

---
```

**Verification**:
- Line 5 should now contain "**DO NOT start with a markdown heading.**"
- The original content "Create an implementation plan..." should now be at approximately line 13

---

### Phase 2: Add Header Instruction to /implement Command [COMPLETED]

**Goal**: Add the header instruction block to `.opencode/commands/implement.md` immediately after frontmatter

**Tasks**:
- [ ] Edit `.opencode/commands/implement.md`
- [ ] Insert header instruction block after line 3 (after frontmatter closing `---`)
- [ ] Use "[Implementing]" as the action verb
- [ ] Add horizontal rule separator after instruction block

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/commands/implement.md` - Insert header instruction block after line 3

**Content to insert** (after line 3, before line 5):
```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Implementing] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS - never output "OC_N" or "OC_NN" literally.

---
```

**Verification**:
- Line 5 should now contain "**DO NOT start with a markdown heading.**"
- The original content "Execute the implementation plan..." should now be at approximately line 13

---

### Phase 3: Add Header Instruction to /revise Command [COMPLETED]

**Goal**: Add the header instruction block to `.opencode/commands/revise.md` immediately after frontmatter

**Tasks**:
- [ ] Edit `.opencode/commands/revise.md`
- [ ] Insert header instruction block after line 3 (after frontmatter closing `---`)
- [ ] Use "[Revising]" as the action verb
- [ ] Add horizontal rule separator after instruction block

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/commands/revise.md` - Insert header instruction block after line 3

**Content to insert** (after line 3, before line 5):
```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Revising] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS - never output "OC_N" or "OC_NN" literally.

---
```

**Verification**:
- Line 5 should now contain "**DO NOT start with a markdown heading.**"
- The original content "**Task Input (required):**" should now be at approximately line 13

---

### Phase 4: Verification and Testing [COMPLETED]

**Goal**: Verify all three commands have correct header instruction blocks

**Tasks**:
- [ ] Verify `/plan` command file has header instruction at lines 5-11
- [ ] Verify `/implement` command file has header instruction at lines 5-11
- [ ] Verify `/revise` command file has header instruction at lines 5-11
- [ ] Confirm all three use identical instruction format (differing only in action verb)

**Timing**: 10 minutes

**Verification**:
- All three files should have "**DO NOT start with a markdown heading.**" at line 5
- Each file should have the appropriate action verb: [Planning], [Implementing], [Revising]
- Horizontal rule separator should follow the instruction block in each file

## Testing & Validation

- [ ] Grep for "DO NOT start with a markdown heading" in all three command files
- [ ] Verify each action verb matches the command: [Planning] for plan, [Implementing] for implement, [Revising] for revise
- [ ] Confirm no syntax errors introduced (files remain valid markdown)

## Artifacts & Outputs

- `.opencode/commands/plan.md` - Modified with header instruction block
- `.opencode/commands/implement.md` - Modified with header instruction block
- `.opencode/commands/revise.md` - Modified with header instruction block
- `specs/OC_201_fix_header_display_plan_implement_revise/summaries/03_header-fix-summary.md` - Implementation summary

## Rollback/Contingency

If header instructions cause issues:
1. Remove the inserted lines 5-11 from each modified command file
2. Restore original line structure (content starting at line 5)
3. The changes are isolated additions - no existing functionality is modified
