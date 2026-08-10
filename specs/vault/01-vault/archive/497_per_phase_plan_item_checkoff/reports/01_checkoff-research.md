# Research Report: Task #497

**Task**: 497 - Add per-phase plan item check-off to implementation agent
**Started**: 2026-05-04T10:00:00Z
**Completed**: 2026-05-04T10:45:00Z
**Effort**: 1 hour
**Dependencies**: Task 495 (multi-subagent continuation loop) - COMPLETE
**Sources/Inputs**:
  - `.opencode/agent/subagents/general-implementation-agent.md` (current Stage 4 structure)
  - `.opencode/skills/skill-implementer/SKILL.md` (postflight continuation loop)
  - `.opencode/context/formats/progress-file.md` (progress tracking schema)
  - `.opencode/context/formats/handoff-artifact.md` (handoff structure)
  - `.opencode/context/patterns/subagent-continuation-loop.md` (continuation loop pattern)
  - `.opencode/context/patterns/context-exhaustion-detection.md` (context pressure heuristics)
  - Existing plan files: `specs/518_*/plans/01_unified-ai-picker.md`, `specs/495_*/plans/01_continuation-plan.md`, `specs/522_*/plans/01_fix-refs-plan.md`
  - `specs/495_multi_subagent_continuation_loop/summaries/01_continuation-summary.md` (task 495 completion)
  - `specs/TODO.md` (task 497 description)
**Artifacts**: - `specs/497_per_phase_plan_item_checkoff/reports/01_checkoff-research.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The general-implementation-agent currently tracks per-objective progress in a **separate JSON progress file** (`progress/phase-{P}-progress.json`) but does **not** modify the plan file's `- [ ]` checklist items in-place.
- Plan files use `- [ ]` markdown checklist syntax for individual tasks within each phase (e.g., `Task 1.1`, `Task 1.2`). These remain unchecked even after phases are marked `[COMPLETED]`.
- The recommended approach is to **add a new sub-stage within Stage 4B** (after updating the progress file) that edits the plan file to convert `- [ ]` to `- [x]` for completed items, optionally appending brief completion notes.
- This enhancement must preserve the **continuation loop semantics** from Task 495: successors reading handoffs can cross-reference the checked-off plan to understand exactly where work stopped.
- **No separate progress file is needed** — the plan file itself becomes the human-readable progress artifact, while the JSON progress file retains machine-readable state for the continuation loop.

## Context & Scope

Task 495 (multi-subagent continuation loop) is now complete. It added:
1. Progress file creation (Stage 3.5)
2. Progress file updates after each objective (Stage 4B)
3. Handoff artifact writing on context pressure (Stage 4C)
4. Skill-level continuation loop that spawns successors from handoffs

Task 497 builds on this by adding **granular check-off within the plan file itself**, making progress visible to humans without requiring them to read JSON progress files.

## Findings

### Current Agent Stage 4 Structure

From `general-implementation-agent.md` (lines 104-169), Stage 4 is:

```
Stage 4: Execute File Operations Loop
├── 4.5: Context Exhaustion Monitoring
├── A: Mark Phase In Progress (edit plan heading [NOT STARTED] -> [IN PROGRESS])
├── B: Execute Steps
│   ├── 1. Read existing files
│   ├── 2. Create/modify files
│   ├── 3. Verify step completion
│   └── 4. Update Progress File (Stage 4B)
├── C: Verify Phase Completion
├── D: Mark Phase Complete (edit plan heading [IN PROGRESS] -> [COMPLETED])
└── E: Handoff on Context Pressure (Stage 4C)
```

**Key observation**: The agent edits the plan file **only twice per phase**:
1. At the start: `### Phase {P}: {Name} [NOT STARTED]` → `[IN PROGRESS]`
2. At the end: `### Phase {P}: {Name} [IN PROGRESS]` → `[COMPLETED]`

There is **no editing of individual checklist items** (`- [ ]` → `- [x]`) within the phase.

### Plan File Checklist Structure

All examined plan files use identical checklist syntax within phase **Tasks** sections:

```markdown
### Phase 1: Fix Pre-existing Bugs [COMPLETED]

**Tasks**:
- [ ] **Task 1.1**: Clean up 9,611 orphaned backup files...
- [ ] **Task 1.2**: Fix dead `opencode_terminal` filetype detection...
- [ ] **Task 1.3**: Fix `<leader>as` collision...
- [ ] **Task 1.4**: Correct `<C-c>` → `<C-CR>` documentation errors...
```

Even after a phase is marked `[COMPLETED]`, the checklist items remain `- [ ]` (unchecked). This is confirmed in `specs/518_*/plans/01_unified-ai-picker.md` where all four phases are `[COMPLETED]` but all task checkboxes are still empty.

There are **642 existing uses** of `- [x]` in the codebase, but these appear exclusively in:
- Implementation summaries (verification checklists)
- Archived plan files (post-hoc documentation)
- TODO.md (manually maintained)

**No active plan file currently has in-place `- [x]` check-off updated during implementation.**

### Current Progress Tracking (Stage 4B)

Stage 4B updates `specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`:

```json
{
  "phase": 3,
  "phase_name": "Implement validation framework",
  "objectives": [
    {"id": 1, "description": "Define ValidationResult type", "status": "done"},
    {"id": 2, "description": "Implement field validators", "status": "in_progress"}
  ],
  "current_objective": 2,
  "handoff_count": 0
}
```

The progress file is **machine-readable** and consumed by:
1. Successor subagents (to know which objectives to skip)
2. Handoff artifacts (referenced in the `Current State` section)
3. Skill postflight (to determine `phases_completed`)

### Handoff Artifact Integration

Handoff artifacts reference the progress file:

```markdown
## Current State
- **File**: ...
- **Progress**: `specs/259_configure_feature/progress/phase-3-progress.json`
  - Objectives 1-2 done, objective 3 in_progress
```

The handoff does **not** currently reference individual plan checklist items because they are not updated. With per-phase check-off, handoffs could optionally reference the plan file directly:

```markdown
## Current State
- **Plan**: `specs/497_.../plans/01_...md`
  - Phase 2: Tasks 2.1-2.3 checked off, Task 2.4 in progress
- **Progress**: `specs/497_.../progress/phase-2-progress.json`
```

### Continuation Loop Interaction (Task 495)

The continuation loop in `skill-implementer` (Stage 6-7 postflight) works as follows:

1. Subagent returns `partial` with `handoff_path`
2. Skill increments `continuation_count`, creates successor delegation context
3. Successor reads handoff artifact FIRST, then progress file
4. Successor resumes from indicated phase/objective

**Impact of adding plan check-off**:
- The plan file now contains human-readable granular state that mirrors the JSON progress file
- Successors **should still use the progress file** as the primary resume point (it's machine-readable and unambiguous)
- The checked-off plan serves as a **secondary reference** for successors and for human reviewers
- The skill continuation loop does **not** need modification — it already passes `plan_path` in the delegation context

## Decisions

### 1. Modify Plan File In-Place (Yes)

The plan file should be edited in-place to convert `- [ ]` → `- [x]` for completed items. This provides:
- Human-readable progress without opening JSON files
- Natural integration with markdown viewers and git diffs
- Persistent record of what was accomplished within each phase

### 2. Integration Point: Stage 4B (Update Progress File)

The check-off should happen **immediately after** the progress file update in Stage 4B (line 143 of general-implementation-agent.md). This ensures:
- Machine-readable state (JSON) is updated first
- Human-readable state (plan markdown) is updated second
- Both are in sync before any verification or handoff

### 3. Check-Off Syntax: `- [x]` with Optional Note

Use standard markdown checklist syntax:

```markdown
- [x] **Task 1.1**: Clean up orphaned backup files *(completed: removed 9,611 files)*
```

For partially completed tasks (rare, but possible):

```markdown
- [x] **Task 2.1**: Define ValidationResult type *(completed)*
- [~] **Task 2.2**: Implement field validators *(partial: 3 of 5 done - handed off)*
```

**Note**: Markdown does not have a standard "partial" checkbox. Options:
- Use `- [~]` (non-standard but visually clear)
- Use `- [x]` with an explicit partial note
- Leave as `- [ ]` with a partial note

**Recommendation**: Use `- [x]` with a note for completed items, and leave `- [ ]` with a note for partially completed items. This is the most compatible with standard markdown renderers.

### 4. Do Not Replace Progress File

The JSON progress file should **remain the primary tracking mechanism** for:
- Continuation loop resumption
- Handoff artifact generation
- Machine-readable state

The plan check-off is a **human-readable augmentation**, not a replacement.

### 5. Scope: Per-Phase, Not Per-Step

Check-off happens **after completing each objective/step within a phase**, not after every micro-step. This aligns with:
- The existing Stage 4B progress file update frequency
- The granularity of `- [ ]` items in plan files (which are typically objective-level)
- The context pressure guidelines (avoid excessive plan file edits)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plan file edit conflicts with phase heading edits | Medium | Low | Use precise `old_string` matching that includes the full `- [ ]` line. The Edit tool requires exact matches, so concurrent edits to different lines are safe. |
| Check-off consumes extra tool calls, accelerating context pressure | Low | Medium | Only check off after completing an objective (not every micro-step). Each check-off is a single Edit tool call. Given plans have ~5-10 tasks per phase, this adds ~5-10 Edit calls per phase — negligible compared to file operations. |
| Successor confusion about which source of truth to use | Low | Low | Document clearly in agent instructions: progress file is primary, plan check-off is secondary/human-readable. Successors should read progress file first. |
| Plan file becomes cluttered with completion notes | Low | Low | Keep notes brief (≤ 10 words). Example: `*(completed)*` or `*(done: 3 validators)*`. Do not add timestamps or verbose descriptions. |
| Inconsistent check-off syntax across plan styles | Medium | Low | Plan files consistently use `- [ ] **Task X.Y**: description...` format. Agent should match this exact pattern. If a plan uses a different checklist style, agent falls back to progress file only. |

## Recommended Integration Points

### A. Modify Stage 4B (general-implementation-agent.md)

After the existing progress file update (line 143), add:

```markdown
#### 4B-ii. Check Off Completed Items in Plan File

After updating the progress file, also update the plan file to reflect completed work:

1. **Locate the current phase's Tasks section** in the plan file
2. **For each objective just completed**: Edit the corresponding checklist item:
   - old_string: `- [ ] **Task {P}.{N}**: {description}`
   - new_string: `- [x] **Task {P}.{N}**: {description} *(completed)*`
   
   If a brief completion note adds value (e.g., "removed 9,611 files", "3 of 5 validators done"), append it:
   - new_string: `- [x] **Task {P}.{N}**: {description} *(completed: {brief note})*`

3. **For the current in-progress objective** (if any): Leave as `- [ ]` but optionally append a note:
   - `- [ ] **Task {P}.{N}**: {description} *(in progress)*`

**Note**: If the plan file does not use `- [ ]` checklist syntax for the current phase, skip this step. The progress file remains the authoritative tracking mechanism.
```

### B. Update Handoff Artifact Template Reference

In `handoff-artifact.md` (optional enhancement), add to the `Current State` section example:

```markdown
## Current State
- **File**: /home/user/project/src/validators/date.lua
- **Location**: Line 1, new file
- **Plan**: `specs/259_configure_feature/plans/02_implementation-plan.md`
  - Phase 3: Tasks 3.1-3.2 checked off, Task 3.3 in progress
- **Progress**: `specs/259_configure_feature/progress/phase-3-progress.json`
```

### C. Update Successor Behavior (general-implementation-agent.md Stage 1)

In the successor behavior instructions (line 42-46), add:

```markdown
5. **Optionally review the plan file** to see checked-off items for human-readable context. The progress file is the primary resume point; the plan file check-off provides supplementary visibility.
```

### D. Example of What Checked-Off Plan Items Would Look Like

**Before implementation**:
```markdown
### Phase 2: Build the Core ai-tool-picker.lua Module [IN PROGRESS]

**Tasks**:
- [ ] **Task 2.1**: Create `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` with module skeleton
- [ ] **Task 2.2**: Implement tool preference persistence
- [ ] **Task 2.3**: Implement active terminal detection
- [ ] **Task 2.4**: Implement `smart_toggle()` entry point
- [ ] **Task 2.5**: Implement Stage 1 `show_tool_picker()`
- [ ] **Task 2.6**: Implement Stage 2 Claude path
- [ ] **Task 2.7**: Implement Stage 2 OpenCode path
- [ ] **Task 2.8**: Implement OpenCode session tracking
- [ ] **Task 2.9**: Implement `setup()` function
```

**After completing Tasks 2.1-2.3, with 2.4 in progress**:
```markdown
### Phase 2: Build the Core ai-tool-picker.lua Module [IN PROGRESS]

**Tasks**:
- [x] **Task 2.1**: Create `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` with module skeleton *(completed)*
- [x] **Task 2.2**: Implement tool preference persistence *(completed)*
- [x] **Task 2.3**: Implement active terminal detection *(completed: both Claude and OpenCode detection working)*
- [ ] **Task 2.4**: Implement `smart_toggle()` entry point *(in progress)*
- [ ] **Task 2.5**: Implement Stage 1 `show_tool_picker()`
- [ ] **Task 2.6**: Implement Stage 2 Claude path
- [ ] **Task 2.7**: Implement Stage 2 OpenCode path
- [ ] **Task 2.8**: Implement OpenCode session tracking
- [ ] **Task 2.9**: Implement `setup()` function
```

**After phase complete**:
```markdown
### Phase 2: Build the Core ai-tool-picker.lua Module [COMPLETED]

**Tasks**:
- [x] **Task 2.1**: Create `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` with module skeleton *(completed)*
- [x] **Task 2.2**: Implement tool preference persistence *(completed)*
- [x] **Task 2.3**: Implement active terminal detection *(completed)*
- [x] **Task 2.4**: Implement `smart_toggle()` entry point *(completed)*
- [x] **Task 2.5**: Implement Stage 1 `show_tool_picker()` *(completed)*
- [x] **Task 2.6**: Implement Stage 2 Claude path *(completed)*
- [x] **Task 2.7**: Implement Stage 2 OpenCode path *(completed)*
- [x] **Task 2.8**: Implement OpenCode session tracking *(completed)*
- [x] **Task 2.9**: Implement `setup()` function *(completed)*
```

## Context Extension Recommendations

- **Topic**: Plan file checklist syntax
- **Gap**: No documented convention for how plan files should structure checklist items, or how agents should interact with them
- **Recommendation**: Add a section to `plan-format.md` (or create `plan-checklist-convention.md`) specifying:
  - Use `- [ ] **Task {P}.{N}**: {description}` format within phase **Tasks** sections
  - Agents may check off items during implementation
  - Checked-off plans are human-readable; progress files remain machine-readable primary source

- **Topic**: Agent interaction with plan file during execution
- **Gap**: The agent documentation focuses on heading status edits (`[NOT STARTED]` → `[COMPLETED]`) but does not mention checklist item edits
- **Recommendation**: Update `general-implementation-agent.md` Stage 4 to include check-off behavior as a standard part of execution

## Appendix

### Search Queries Used
- `Glob: **/general-implementation-agent.md`
- `Glob: **/skill-implementer/SKILL.md`
- `Glob: specs/518_*/plans/*.md`
- `Glob: specs/495_*/**/*.md`
- `Grep: - [.] in specs/**/*.md`
- `Grep: - [x] in specs/**/*.md`
- `Grep: 497 in specs/TODO.md`

### References
- `.opencode/agent/subagents/general-implementation-agent.md` — Agent execution flow (Stage 4)
- `.opencode/skills/skill-implementer/SKILL.md` — Skill postflight continuation loop
- `.opencode/context/formats/progress-file.md` — JSON progress tracking schema
- `.opencode/context/formats/handoff-artifact.md` — Handoff document template
- `.opencode/context/patterns/subagent-continuation-loop.md` — Continuation loop architecture
- `.opencode/context/patterns/context-exhaustion-detection.md` — Context pressure heuristics
- `specs/518_unified_ai_tool_picker_session_management/plans/01_unified-ai-picker.md` — Example plan with checklist items
- `specs/495_multi_subagent_continuation_loop/plans/01_continuation-plan.md` — Example plan with checklist items
- `specs/495_multi_subagent_continuation_loop/summaries/01_continuation-summary.md` — Task 495 completion summary
