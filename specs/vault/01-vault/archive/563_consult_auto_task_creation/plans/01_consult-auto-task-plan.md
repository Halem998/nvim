# Implementation Plan: Task #563

- **Task**: 563 - Make /consult always create a task automatically
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: Task 562 (completed)
- **Research Inputs**: specs/563_consult_auto_task_creation/reports/01_consult-auto-task-research.md
- **Artifacts**: plans/01_consult-auto-task-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan eliminates the standalone/temp-file mode from `/consult` and makes every invocation create a task automatically. Gate In of `consult.md` gains auto-task creation logic (slug generation, state.json update, TODO.md entry) for non-task-number inputs. `skill-consult` is simplified to always expect a task number, removing the standalone branch and temp-file cleanup. Gate Out is updated to always display the created task number and next steps. The existing "attach to existing task" path (user provides a task number) remains unchanged.

### Research Integration

The research report identified the exact change scope across six files (three in the nvim extension, three mirrored in the Vision project). Key findings:
- The `task.md` command provides the canonical pattern for slug generation, state.json updates, and TODO.md entry creation.
- Task type for auto-created consult tasks should be `founder`.
- Slug convention: `consult_{domain}_{slugified_input}`.
- The `rm -f "$metadata_file"` cleanup in skill-consult Stage 8 must be removed or guarded to avoid deleting task-directory metadata.
- Status after auto-creation remains `not_started` since the consultation is not a research or plan phase.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is a founder extension workflow improvement that does not map to current roadmap phases.

## Goals & Non-Goals

**Goals**:
- Every `/consult` invocation creates a task entry in state.json and TODO.md
- Task artifacts (reports, metadata) are always stored in `specs/{NNN}_{SLUG}/`
- Gate Out always displays task number and recommends `/plan N` as next step
- Existing "attach to existing task" path (`/consult --legal 458`) continues to work unchanged
- Both nvim extension and Vision project copies are updated in sync

**Non-Goals**:
- Changing the legal-analysis-agent's internal workflow or report format (done in task 562)
- Adding new domain flags (`--investor`, `--technical`, `--competitor`)
- Implementing auto-plan or auto-research after consultation
- Changing the task status after consultation (stays `not_started`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Metadata file deletion in Stage 8 removes task directory metadata | H | M | Remove the `rm -f` entirely; task-directory metadata should persist for postflight |
| Auto-slug generation produces poor slugs from long or unusual input | M | L | Prefix with `consult_{domain}_` and truncate to 50 chars; good enough for tracking |
| `specs/tmp/` directory missing when jq writes scratch file | M | L | Add `mkdir -p specs/tmp` before jq command, matching task.md pattern |
| Vision project copy diverges from nvim extension after update | M | M | Explicit verification phase with diff comparison |
| Existing task-number input path (`/consult --legal 458`) breaks | H | L | Preserve the `input_type == "task_number"` branch unchanged; test explicitly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Update consult.md Gate In and Gate Out [COMPLETED]

**Goal**: Add auto-task creation logic to Gate In (Step 4) and update Gate Out to always display task number and next steps.

**Tasks**:
- [ ] Update the Overview section to remove "standalone immediate-mode" language and document that every invocation creates a task
- [ ] Update Syntax section examples to show that bare invocations create a task automatically
- [ ] Update Input Types table to note auto-task creation for file_path, inline_text, and design_question inputs
- [ ] Replace Step 4 ("Resolve Task Context if task number") with expanded logic:
  - If `input_type == "task_number"`: existing path unchanged (resolve from state.json)
  - Else: auto-create task:
    1. Read `next_project_number` from `specs/state.json` via jq
    2. Generate slug: `consult_{domain}_{slugify(input_first_35_chars)}` (lowercase, underscores, remove special chars, max 50 chars)
    3. Generate description: `Legal design consultation: {input summary}`
    4. Update state.json via jq: increment `next_project_number`, prepend entry to `active_projects` with `task_type: "founder"`, `status: "not_started"`
    5. Update TODO.md frontmatter: increment `next_project_number`
    6. Update TODO.md: prepend task entry after `## Tasks` line
    7. Set `task_number` variable for downstream use
- [ ] Update Gate Out Step 1 to always display task number, report path, and "Next: /plan {N}"
- [ ] Update Gate Out Step 2 to always git commit (remove the `if [ -n "$task_number" ]` conditional since task_number is always set)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/commands/consult.md` - Add auto-task creation in Gate In Step 4, update Gate Out, update Overview/Syntax/Input Types sections

**Verification**:
- Step 4 has both `input_type == "task_number"` branch (unchanged) and `else` branch (auto-create)
- Gate Out always displays task number and "Next: /plan {N}"
- Gate Out always commits (no conditional)
- Overview no longer mentions "standalone immediate-mode"

---

### Phase 2: Update skill-consult and legal-analysis-agent [COMPLETED]

**Goal**: Remove standalone/temp-file mode from skill-consult and update the agent's standalone path comment.

**Tasks**:
- [ ] In `skill-consult/SKILL.md` Stage 2, remove the `else` branch that sets `metadata_file="/tmp/consult-meta-${session_id}.json"` -- `task_number` is now always provided by the command
- [ ] In Stage 2, keep only the task-attached branch (always derive `task_dir` from `task_number`)
- [ ] In Stage 8 (Cleanup), remove the `rm -f "$metadata_file"` line entirely -- metadata files in task directories should persist for postflight artifact linking
- [ ] In Stage 9 (Return), change `"Task attached: {task_number or 'standalone'}"` to always show the task number: `"Task: #{task_number}"`
- [ ] In `legal-analysis-agent.md` Stage 6, update the report path comment from "or a standalone path if immediate-mode" to reflect that the report always goes to a task directory
- [ ] Update the skill's overview text to remove references to standalone mode

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/skills/skill-consult/SKILL.md` - Remove standalone branch in Stage 2, remove cleanup in Stage 8, update Stage 9 return text
- `.claude/extensions/founder/agents/legal-analysis-agent.md` - Update Stage 6 comment about standalone paths

**Verification**:
- No references to `/tmp/consult-meta-` remain in skill-consult
- No references to "standalone" remain in skill-consult Stage 9
- Stage 8 no longer deletes metadata files
- legal-analysis-agent Stage 6 no longer mentions standalone/immediate-mode paths

---

### Phase 3: Mirror Changes to Vision Project and Verify [COMPLETED]

**Goal**: Copy updated files to the Vision project and verify consistency.

**Tasks**:
- [ ] Copy updated `consult.md` from nvim extension to Vision project, preserving any Vision-specific differences (Task tool vs Agent tool references)
- [ ] Copy updated `skill-consult/SKILL.md` from nvim extension to Vision project, preserving Vision-specific tool references
- [ ] Copy updated `legal-analysis-agent.md` from nvim extension to Vision project
- [ ] Run diff comparison between nvim and Vision copies to verify only expected differences remain (tool references)
- [ ] Verify the `input_type == "task_number"` branch is preserved in both copies

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `~/Projects/Logos/Vision/.claude/commands/consult.md` - Mirror nvim changes
- `~/Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` - Mirror nvim changes (preserve Task tool)
- `~/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` - Mirror agent update

**Verification**:
- `diff` between nvim and Vision copies shows only expected tool reference differences
- No standalone mode references remain in either copy
- Both copies have identical auto-task creation logic in Gate In

---

## Testing & Validation

- [ ] Verify `consult.md` Gate In Step 4 contains both branches: existing-task lookup and auto-create
- [ ] Verify slug generation pattern produces valid slugs: `consult_legal_{input_slug}` format, max 50 chars
- [ ] Verify state.json update pattern includes `mkdir -p specs/tmp` guard
- [ ] Verify no `rm -f "$metadata_file"` remains in skill-consult Stage 8
- [ ] Verify Gate Out always displays task number and "Next: /plan {N}"
- [ ] Verify all six files (3 nvim + 3 Vision) are updated
- [ ] Verify diff between nvim and Vision copies shows only expected differences

## Artifacts & Outputs

- `.claude/extensions/founder/commands/consult.md` - Updated with auto-task creation
- `.claude/extensions/founder/skills/skill-consult/SKILL.md` - Standalone mode removed
- `.claude/extensions/founder/agents/legal-analysis-agent.md` - Standalone path comment updated
- `~/Projects/Logos/Vision/.claude/commands/consult.md` - Vision mirror
- `~/Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` - Vision mirror
- `~/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` - Vision mirror

## Rollback/Contingency

All changes are to markdown instruction files (commands, skills, agents). If any change causes issues, `git revert` the commit to restore previous behavior. No compiled code, no database migrations, no infrastructure changes. The existing task-number attachment path is preserved unchanged, so reverting only affects the new auto-creation behavior.
