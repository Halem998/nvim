# Research Report: Enhance General Implementation Agent

- **Task**: 569 - enhance_general_implementation_agent
- **Started**: 2026-05-13T00:00:00Z
- **Completed**: 2026-05-13T00:10:00Z
- **Effort**: 0.25h
- **Dependencies**: 568
- **Sources/Inputs**:
  - `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
  - `/home/benjamin/.config/nvim/.claude/context/formats/handoff-artifact.md`
  - `/home/benjamin/.config/nvim/.claude/context/patterns/context-exhaustion-detection.md`
  - `/home/benjamin/.config/nvim/.claude/context/formats/progress-file.md`
  - `/home/benjamin/.config/nvim/.claude/rules/plan-format-enforcement.md`
  - `/home/benjamin/.config/nvim/.claude/context/formats/summary-format.md`
- **Artifacts**: `specs/569_enhance_general_implementation_agent/reports/01_agent-enhancement-research.md`
- **Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The agent file uses lettered sub-stages (4A, 4B-ii, 4C, 4D) but is missing the numbering for the new Stage 4D-ii (post-phase self-review); Stage 4D marks phase complete, so 4D-ii slots in immediately after it, before the phase loop moves to the next phase.
- Progressive handoff is not currently mentioned; it should be added as a new Stage 4E immediately after Stage 4D (and before Stage 4C, which currently handles only context-pressure handoffs — the naming must be reconciled).
- Deviation annotation is partially present (Stage 4B-ii has `*(completed)*` and `*(in progress)*` annotations) but the `*(deviation: ...)*` format is not referenced in the agent at all; a new Step 4 inside Stage 4B-ii is needed.
- Context-exhaustion detection references `context-exhaustion-detection.md` in Stage 4C, but the agent's Step 1 inside Stage 4C says only "Update progress file" — it does not include the new Step 1.5 "Annotate Plan File (Final Checkpoint)" that was added to the pattern document in task 568.
- The implementation summary template in Stage 6 does not include `## Plan Deviations`; this section must be added to match the updated `summary-format.md`.
- The Phase Checkpoint Protocol (separate section at the bottom of the file) lists 6 steps but does not mention self-review or deviation annotation; it should be updated to cross-reference the new stages.

---

## Context & Scope

Task 569 adds four behavioral improvements to `general-implementation-agent.md`. Task 568 already updated the format contract documents (progress-file.md, plan-format-enforcement.md, handoff-artifact.md, context-exhaustion-detection.md, summary-format.md). The agent file itself is the only file that needs editing in task 569. All four improvements are purely additive (no existing behavior is removed); the primary challenge is correct placement and consistent labeling.

---

## Findings

### Current Agent Structure

Full stage inventory (line references approximate):

| Label | Lines | Description |
|-------|-------|-------------|
| Stage 0 | 27-29 | Initialize early metadata |
| Stage 1 | 31-50 | Parse delegation context (+ Successor Behavior) |
| Stage 2 | 52-56 | Load and parse implementation plan |
| Codebase Exploration Note | 58-61 | Boundary note (informational) |
| Stage 3 | 63-70 | Find resume point |
| Stage 3.5 | 72-103 | Initialize progress tracking |
| Stage 4 (header) | 106-117 | Execute file operations loop (intro + context monitoring) |
| Stage 4.5 | 110-117 | Context exhaustion monitoring thresholds |
| Stage 4A | 119-125 | Mark phase in progress |
| Stage 4B | 127-153 | Execute steps (sub-steps 1-4) |
| Stage 4B-ii | 156-171 | Check off completed items in plan file |
| Stage 4C (labeled "Verify Phase Completion") | 173-178 | Run verification criteria |
| Stage 4D (labeled "Mark Phase Complete") | 180-187 | Edit plan heading to [COMPLETED] |
| Stage 4C again (labeled "Handoff on Context Pressure") | 189-213 | Context pressure handoff protocol |
| Stage 5 | 215-219 | Run final verification |
| Stage 6 | 221-253 | Create implementation summary |
| Stage 6a | 256-283 | Generate completion data |
| Stage 6b | 285-309 | Emit memory candidates |
| Stage 7 | 311-335 | Write metadata file |
| Stage 8 | 337-339 | Return brief text summary |
| Phase Checkpoint Protocol | 341-362 | Summary protocol table |
| Error Handling | 364-371 | Error patterns |
| Critical Requirements | 373-392 | MUST DO / MUST NOT lists |

**Key naming conflict**: There are two sections both labeled "Stage 4C" in the file. Lines 173-178 are labeled `**C. Verify Phase Completion**` and lines 189-213 are labeled `#### E. Handoff on Context Pressure (Stage 4C)`. The lettering uses A, B, 4B-ii, C, D, E but the parenthetical labels say 4C for the E item. This is an existing inconsistency that the implementation should preserve or fix.

**Actual letter sequence as of current file**:
- A = Mark Phase In Progress
- B = Execute Steps
- 4B-ii = Check Off Completed Items
- C = Verify Phase Completion
- D = Mark Phase Complete
- E = Handoff on Context Pressure (parenthetical says "Stage 4C" — a mislabeling)

The new additions are:
- 4D-ii = Post-Phase Self-Review (after D, before next phase iteration)
- New lettered step for Progressive Handoff at phase end (could be "F", after E)

---

### Post-Phase Self-Review (Stage 4D-ii)

**Location**: Immediately after Stage 4D "Mark Phase Complete" (lines 180-187), before the loop moves to the next phase. This is what the task description calls "Stage 4D-ii".

**Trigger**: Runs every time a phase is marked `[COMPLETED]`, not only on context pressure.

**What it must do** (derived from progress-file.md Update Protocol step 2.5):
> After completing a phase (post-phase self-review): Re-read the phase task checklist in the plan. For each unchecked item that will not be completed, add a deviation entry. Write deviation annotations into the plan file checklist.

**Exact wording for the new section**:

```
#### 4D-ii. Post-Phase Self-Review

After marking a phase `[COMPLETED]`, perform a self-review before proceeding to the next phase:

1. **Re-read the phase's task checklist** in the plan file (the `## Tasks` or checklist block for the current phase).

2. **For each checklist item that remains unchecked** (`- [ ]`):
   - If the item was intentionally skipped or altered, add a deviation entry to the progress file and annotate the checklist item inline (see Stage 4B-ii for annotation format).
   - If the item was overlooked, evaluate whether it should be completed before proceeding.

3. **Record any deviations in the progress file** `deviations` array:
   ```json
   {
     "task_id": "{P}.{N}",
     "description": "{plan step text}",
     "type": "skipped|altered|deferred",
     "reason": "One sentence explanation",
     "annotation": "*(deviation: skipped — reason)*"
   }
   ```

4. **Annotate the plan checklist inline** for each deviation:
   - Skipped: `- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*`
   - Altered: `- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*`
   - Deferred: `- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*`

5. **Note any skipped items** in the progress file `note` field of the objective if applicable.

Only then proceed to the next phase (or to Stage 5 if all phases are done).
```

---

### Progressive Handoff Updates

**Current state**: The agent writes a handoff only in Stage 4E (context pressure). The `handoff-artifact.md` updated in task 568 now includes a preamble note: "Handoffs should be written (or updated) at the end of each phase, not only when context exhaustion is detected."

**Location**: After Stage 4D-ii (post-phase self-review), before entering the next phase iteration. This is effectively a new Stage 4E for "Normal Phase-End Handoff", with the context-pressure handoff becoming Stage 4F. However, to minimize diff and preserve the existing label `#### E. Handoff on Context Pressure`, the progressive handoff can be inserted as a new sub-section **before** the existing 4E section.

**Recommended approach**: Insert a new `#### 4D-iii. Progressive Handoff Update` immediately after `4D-ii`, before `#### E. Handoff on Context Pressure`. This keeps the existing E section intact.

**Exact wording for the new section**:

```
#### 4D-iii. Progressive Handoff Update

At the end of each successfully completed phase, write or update a handoff artifact. This ensures a recovery point exists even if context exhaustion occurs mid-next-phase.

1. **Write a phase-end handoff** to `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`:
   ```bash
   mkdir -p "specs/{NNN}_{SLUG}/handoffs"
   handoff_file="specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-$(date -u +%Y%m%dT%H%M%SZ).md"
   ```

2. **Use a condensed template** (the handoff is a checkpoint, not an emergency):
   - **Immediate Next Action**: First step of the next phase (or "All phases complete, proceed to Stage 5")
   - **Current State**: Phase {P} completed. Plan and progress file are up to date.
   - **Key Decisions Made**: Any decisions made during this phase relevant to future phases
   - **Deviations from Plan**: Populate from the progress file `deviations` array (or `- None`)
   - **What NOT to Try**: Approaches that failed during this phase
   - **References**: Plan path and current phase

3. **Increment `handoff_count`** in the progress file only if this is an emergency handoff (context pressure). Phase-end handoffs do NOT increment `handoff_count`.

**Note**: If no meaningful next action exists (e.g., this is the last phase and Stage 5 is trivial), the phase-end handoff may be omitted. The goal is to have a useful recovery point, not to generate files mechanically.
```

---

### Deviation Annotation in Plan

**Current state**: Stage 4B-ii (lines 156-171) describes annotating checklist items with `*(completed)*` and `*(in progress)*`. It does NOT mention `*(deviation: ...)*` annotations.

**Location**: Inside Stage 4B-ii, a new Step 4 (after the existing Step 3 for in-progress items) that covers deviation annotations. Additionally, the post-phase self-review (Stage 4D-ii) handles deviations discovered at phase end. Stage 4B-ii handles deviations discovered mid-phase (when the agent realizes it must skip or alter a step).

**What needs to change in Stage 4B-ii**: Add Step 4 immediately after the current Step 3 (`*(in progress)*` annotation):

```
4. **For a step being deviated from** (skipped, altered, or deferred):
   - Add a deviation entry to the progress file `deviations` array
   - Annotate the checklist item inline using the deviation format:
     - Skipped: `- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*`
     - Altered: `- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*`
     - Deferred: `- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*`
   - Reference: `.claude/rules/plan-format-enforcement.md` for the deviation annotation format
```

This change ensures deviation annotations happen inline during execution, while Stage 4D-ii catches any that were missed at phase end.

---

### Final Context-Exhaustion Checkpoint

**Current state**: Stage 4E (lines 189-213) describes the handoff protocol with:
- Step 1: Update progress file
- Step 2: Write handoff artifact
- Step 3: Increment `handoff_count`
- Step 4: Skip remaining steps and return partial

The `context-exhaustion-detection.md` pattern (updated in task 568) now has a Step 1.5 between Step 1 and Step 2:
> **1.5. Annotate Plan File (Final Checkpoint)** — Before writing the handoff document, update the plan file to reflect exact current state: ensure completed tasks have `*(completed)*`, in-progress task has `*(in progress — handoff)*`, and each deviation in the progress file `deviations` array is annotated inline.

**The agent's Stage 4E must add Step 1.5** between its current Step 1 and Step 2.

**Exact wording to insert** (between Steps 1 and 2 of Stage 4E):

```
   1.5. **Annotate plan file (final checkpoint)** — before writing the handoff document, update the plan file:
      - For each completed task in the current phase: ensure `- [x]` with `*(completed)*` annotation
      - For the in-progress task (if any): append `*(in progress — handoff)*`
      - For each deviation in the progress file `deviations` array: write the `annotation` value inline on the corresponding checklist item
      
      This ensures the plan file is a reliable resume point even if the handoff artifact is lost.
```

**Note on numbering**: The existing Stage 4E steps are numbered 1-4. After inserting Step 1.5, the numbering becomes 1, 1.5, 2, 3, 4. This is consistent with how `context-exhaustion-detection.md` handles the same insert.

---

### Summary Format Update

**Current state**: Stage 6 (lines 221-253) contains a hardcoded summary template with sections: Changes Made, Files Modified, Verification, Notes. This does NOT match `summary-format.md`.

**What summary-format.md requires** (updated in task 568):
Structure items 1-7: Overview, What Changed, Decisions, Plan Deviations, Impacts, Follow-ups, References.

The `## Plan Deviations` section (item 4) is now required:
> Bullets of plan steps skipped, altered, or deferred. Use `- None (implementation followed plan)` when no deviations occurred.

**What needs to change**: The inline template in Stage 6 should be updated to include `## Plan Deviations`. The Stage 6 template is more abbreviated than the full `summary-format.md` standard, which is appropriate. The minimal change is to add `## Plan Deviations` between `## Changes Made` and a new `## Verification` section, or (better) align the section names with `summary-format.md`.

**Recommended replacement for Stage 6 template**:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Duration**: {time}

## Overview

{2-3 sentences on scope and what was accomplished}

## What Changed

- `path/to/file.ext` — {change description}
- `path/to/new-file.ext` — Created new file

## Decisions

- {Key decision made during implementation}

## Plan Deviations

- **Task {P}.{N}** skipped: {reason}
- **Task {P}.{N}** altered: {what changed and why}
(or: `- None (implementation followed plan)`)

## Verification

- Build: Success/Failure/N/A
- Tests: Passed/Failed/N/A
- Files verified: Yes

## Notes

{Any additional notes, follow-up items, or caveats}
```

The `## Plan Deviations` section should be populated from the `deviations` arrays across all phase progress files. If all deviations arrays are empty, write `- None (implementation followed plan)`.

---

### Phase Checkpoint Protocol (Secondary Update)

The "Phase Checkpoint Protocol" section at the bottom of the agent file (lines 341-362) lists 6 steps: read plan, update to IN PROGRESS, execute steps, update to COMPLETED/BLOCKED/PARTIAL, git commit, proceed or return. This section does not reference the new self-review or progressive handoff steps.

**Recommended update to step 4**: Change from:
```
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
```
To:
```
4. **Update phase status** to `[COMPLETED]` (Stage 4D), then perform post-phase self-review (Stage 4D-ii) and write a progressive handoff (Stage 4D-iii)
```

This keeps the Protocol section in sync with the detailed Stage 4 flow.

---

## Decisions

1. **Stage 4D-ii label**: Use `#### 4D-ii.` to match the task description language and the existing `#### 4B-ii.` pattern in the file. This is the clearest way to express sub-stages.

2. **Progressive handoff as 4D-iii, not a renaming of 4E**: The existing "E. Handoff on Context Pressure" section stays intact; the progressive handoff is inserted as a separate 4D-iii section before it. This avoids breaking references and keeps the distinction between "normal phase-end checkpoint" and "emergency context-pressure handoff" clear.

3. **Deviation annotation in 4B-ii as Step 4**: The existing steps in 4B-ii are numbered 1-3. Appending Step 4 for deviation annotations is consistent with the existing numbering pattern and avoids restructuring the section.

4. **Step 1.5 for plan annotation in context-exhaustion handoff**: Mirror the exact label used in `context-exhaustion-detection.md` ("1.5") to make cross-references obvious. Using a decimal number for a mid-sequence insert is already established precedent in the reference document.

5. **Summary template update**: Align the inline template in Stage 6 with `summary-format.md` section names (Overview, What Changed, Decisions, Plan Deviations, Verification, Notes) rather than the old names (Changes Made, Files Modified, Verification, Notes). The existing "Changes Made" and "Files Modified" sections can be merged into "What Changed" with file paths as bullets.

6. **Populate Plan Deviations from progress files**: The agent should read each phase's `deviations` array from the progress JSON files when writing the summary. This is the most reliable source since it was maintained incrementally during execution.

---

## Recommendations

Listed in implementation order (each subsequent change may depend on reading earlier sections):

### 1. Add deviation annotation to Stage 4B-ii (Step 4)

**File**: `.claude/agents/general-implementation-agent.md`
**Location**: After the current Step 3 block in `#### 4B-ii. Check Off Completed Items in Plan File` (around line 171), before the closing `**Note**` paragraph.

**Insert**:
```markdown
4. **For a step being deviated from** (skipped, altered, or deferred during execution):
   - Add a deviation entry to the progress file `deviations` array (see progress-file.md schema)
   - Annotate the checklist item inline:
     - Skipped: `- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*`
     - Altered: `- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*`
     - Deferred: `- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*`
```

### 2. Add Stage 4D-ii (Post-Phase Self-Review) after Stage 4D

**File**: `.claude/agents/general-implementation-agent.md`
**Location**: After the closing sentence of `**D. Mark Phase Complete**` (around line 187), before `#### E. Handoff on Context Pressure`.

**Insert** the `#### 4D-ii. Post-Phase Self-Review` section (full wording in Findings above).

### 3. Add Stage 4D-iii (Progressive Handoff) after Stage 4D-ii

**File**: `.claude/agents/general-implementation-agent.md`
**Location**: Immediately after Stage 4D-ii, before `#### E. Handoff on Context Pressure`.

**Insert** the `#### 4D-iii. Progressive Handoff Update` section (full wording in Findings above).

### 4. Add Step 1.5 to Stage 4E (Context-Exhaustion Handoff)

**File**: `.claude/agents/general-implementation-agent.md`
**Location**: Inside `#### E. Handoff on Context Pressure`, after Step 1 "Update progress file" and before Step 2 "Write handoff artifact" (around line 198).

**Insert** the Step 1.5 wording (full text in Findings above).

### 5. Update Stage 6 summary template to include Plan Deviations

**File**: `.claude/agents/general-implementation-agent.md`
**Location**: The markdown code block in Stage 6 (lines 230-254).

**Replace** the existing template with the updated version (full wording in Findings above).

### 6. Update Phase Checkpoint Protocol step 4

**File**: `.claude/agents/general-implementation-agent.md`
**Location**: Phase Checkpoint Protocol numbered list, Step 4 (around line 349).

**Change** step 4 to reference Stage 4D-ii and 4D-iii.

---

## Appendix

### Key Excerpt: Stage 4B-ii (Insertion Point for Step 4)

```
**B. Execute Steps**
...
3. **For the current in-progress objective** (if any): Leave as `- [ ]` but optionally append a note:
   - `- [ ] **Task {P}.{N}**: {description} *(in progress)*`

**Note**: If the plan file does not use `- [ ]` checklist syntax for the current phase, skip this step. The progress file remains the authoritative tracking mechanism.
```
Step 4 goes between the Step 3 block and the `**Note**` paragraph.

### Key Excerpt: Stage 4D (Insertion Point for 4D-ii and 4D-iii)

```
**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

#### E. Handoff on Context Pressure (Stage 4C)
```
Stage 4D-ii and 4D-iii insert between Stage 4D's closing line and `#### E.`.

### Key Excerpt: Stage 4E Step 1 (Insertion Point for Step 1.5)

```
#### E. Handoff on Context Pressure (Stage 4C)
...
1. **Update progress file** to reflect the exact current state:
   - Set current objective status to `in_progress` (or `done` if just completed)
   - Update `last_updated`

2. **Write handoff artifact** to `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`:
```
Step 1.5 inserts between Step 1 and Step 2.

### Note on Existing Label Inconsistency

The existing file labels the Handoff on Context Pressure section as both `#### E.` (by letter) and `(Stage 4C)` (in the parenthetical). This is a pre-existing inconsistency (E is the fifth letter after A, B, C, D, but the parenthetical calls it 4C). The implementation plan author should decide whether to fix this label during task 569 or leave it as-is. The research recommendation is to leave it as-is to minimize diff scope, but note the inconsistency.
```
