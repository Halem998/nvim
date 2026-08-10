# Research Report: Task #614

**Task**: 614 - post_phase_subtask_validation
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:15:00Z
**Effort**: 0.5 hours
**Dependencies**: None
**Sources/Inputs**:
- `.claude/agents/general-implementation-agent.md` (477 lines)
- `.claude/agents/neovim-implementation-agent.md` (486 lines)
- `.claude/agents/nix-implementation-agent.md` (816 lines)
- `.claude/context/formats/plan-format.md` (148 lines)
- `.claude/rules/plan-format-enforcement.md` (25 lines)
- `specs/ROADMAP.md`
**Artifacts**: `specs/614_post_phase_subtask_validation/reports/01_subtask-validation.md`
**Standards**: report-format.md

---

## Executive Summary

- All three implementation agents (general, neovim, nix) have identical post-phase review structure: they instruct the agent to re-read the checklist, annotate deviations, and handle unchecked items — but nothing mechanically blocks phase transition if items remain unchecked without annotation.
- The gap is between Stage 4D (mark `[COMPLETED]`) and Stage 4D-ii (post-phase self-review): the agent marks the phase complete *before* the self-review step, allowing a poorly-attentive execution to proceed without completing or annotating all items.
- The proposed fix is a **lightweight count-and-gate step** inserted between Stage 4D (mark COMPLETED) and Stage 4D-ii (existing post-phase review): count unchecked `- [ ]` items in the current phase's Tasks section, and if any exist, either complete them or annotate them with deviation format before proceeding to Stage 4D-iii.
- The three agent files are structurally identical in this area (same stage numbering, same step names), so the same validation text can be applied to all three with only minor domain-specific adaptations.

---

## Context & Scope

Task 614 asks for a self-check validation step to be added to implementation agents between post-phase review (Stage 4D-ii) and the handoff/next-phase transition (Stage 4D-iii). The check should:

1. Count unchecked items (`- [ ]`) remaining in the phase's Tasks checklist
2. Either complete them or annotate them with deviation format
3. Only then allow the phase to be considered truly done

The scope covers three agent files. No new tools, rules, or context files are required — this is a documentation/instruction change within agent `.md` files.

---

## Findings

### 1. Current Phase Structure (All Three Agents)

All three implementation agents share an identical high-level phase loop structure:

```
Stage 4 (Execute File Operations Loop):
  A. Mark Phase [IN PROGRESS]
  B. Execute Steps
     - Read files
     - Create/modify files
     - Verify changes
     - 4B-ii: Check off completed items in plan file (general-agent only)
  C. Verify Phase Completion (build/test commands)
  D. Mark Phase [COMPLETED]
  4D-ii. Post-Phase Self-Review   ← gap exists here
  4D-iii. Progressive Handoff Update
  [Git commit]
  → Proceed to next phase
```

The neovim and nix agents have the same structure but use slightly different step letters (e.g., nix uses A/B/C/D/E instead of A/B/C/D) and domain-specific verification commands.

---

### 2. Where Subtask Check-Off Is Instructed

#### general-implementation-agent.md (lines 156–179)

Stage 4B-ii is a dedicated sub-step explicitly labeling "Check Off Completed Items in Plan File":

1. Locate the current phase's Tasks section
2. For each objective just completed: edit `- [ ]` → `- [x]` with `*(completed)*` annotation
3. For in-progress objective: leave as `- [ ]` with optional `*(in progress)*` note
4. For deviations: annotate with skipped/altered/deferred format and log to progress file `deviations` array

This step is part of Step B execution — it runs after each objective is completed, not as a batch review.

The **key note at line 179**: "If the plan file does not use `- [ ]` checklist syntax for the current phase, skip this step."

#### neovim-implementation-agent.md (lines 150–153)

Equivalent instruction is embedded in Step B.4 (without a dedicated sub-stage label):

> "Annotate deviations in plan file — For any step deviated from (skipped, altered, or deferred):
> - Skipped: `- [ ] **Task {P}.{N}**: ...`
> - Altered: `- [x] **Task {P}.{N}**: ...`
> - Deferred: `- [ ] **Task {P}.{N}**: ...`"

The neovim agent does **not** have the explicit "check off completed items" instruction as a distinct step — it only mentions annotation for deviations. The general agent's Stage 4B-ii (marking completed items `- [x]`) is absent here. This is a documentation gap: the neovim agent only tracks deviations, not positive completions.

#### nix-implementation-agent.md (lines 178–181)

Identical to neovim: Step C.5 covers deviation annotation only. Same documentation gap: no explicit "mark completed items `- [x]`" instruction.

---

### 3. Where Post-Phase Review Happens

#### general-implementation-agent.md (lines 197–225): Stage 4D-ii

Full text of what exists:
1. Re-read the phase's task checklist
2. For each unchecked item (`- [ ]`): determine if intentionally skipped/altered or overlooked; annotate deviations; evaluate if overlooked items should be completed before proceeding
3. Record deviations in progress file `deviations` array
4. Annotate plan checklist inline for each deviation

This is comprehensive instruction, but it is **advisory**, not mechanical. The agent is told to "evaluate whether it should be completed before proceeding" — there is no explicit gate that blocks transition on unchecked/unannotated items.

#### neovim-implementation-agent.md (lines 173–182): Stage 4D-ii

Shorter version:
1. Re-read the phase's task checklist
2. For each unchecked item: determine if intentionally skipped or overlooked; annotate deviations
3. Record deviations inline
4. Verify Neovim starts without errors before proceeding

No progress file is involved (neovim agent doesn't use progress files). No explicit gate.

#### nix-implementation-agent.md (lines 199–208): Stage 4D-ii

Same as neovim:
1. Re-read the phase's task checklist
2. For each unchecked item: determine if intentionally skipped/altered or overlooked; annotate deviations
3. Record deviations in a `deviations` array note (or inline)
4. Verify `nix flake check` passes before proceeding

No explicit gate.

---

### 4. The Gap: Instructed vs. Enforced

The critical gap is:

| Agent | Phase mark COMPLETED | Post-Phase Review | Gate on unchecked items |
|-------|---------------------|-------------------|------------------------|
| general | Stage 4D (before review) | Stage 4D-ii (advisory) | None |
| neovim | Step D (before review) | Stage 4D-ii (advisory) | None |
| nix | Step E (before review) | Stage 4D-ii (advisory) | None |

The phase is marked `[COMPLETED]` *before* the post-phase self-review step runs. This means:
- If an agent stops early (context exhaustion, interruption), the phase appears complete even if items were missed
- The review step is well-written but voluntary — there is no count, no enforcement, and no blocking condition

The general agent's Stage 4B-ii should catch most cases (marking completed items during execution), but an agent under context pressure may skip 4B-ii, and then the post-phase review's advisory language ("evaluate whether it should be completed") doesn't prevent proceeding.

---

### 5. Proposed Insertion Point

The validation should be inserted **between Stage 4D (mark COMPLETED) and Stage 4D-ii (existing self-review)**. Specifically, it should become the *first action* of the existing Stage 4D-ii, making the self-review concrete rather than advisory.

**Proposed restructured Stage 4D-ii for all three agents:**

```
#### 4D-ii. Post-Phase Subtask Validation (Self-Check Gate)

After marking a phase `[COMPLETED]`, perform a mandatory self-check before
proceeding to the next phase:

**Step 1: Count Unchecked Items**
Re-read the phase's Tasks checklist in the plan file. Count items matching
`- [ ]` that do NOT already have a deviation annotation (i.e., do not contain
`*(deviation:` or `*(in progress`).

**Step 2: Address Each Unchecked Item**
For each unchecked, unannotated item:

a. **If the work was completed but not marked**: Update the checklist item:
   - `- [x] **Task {P}.{N}**: {description} *(completed)*`

b. **If the item was intentionally skipped or altered**: Annotate inline:
   - Skipped: `- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*`
   - Altered: `- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*`
   - Deferred: `- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*`

c. **If the work was overlooked**: Complete it now before proceeding, then mark
   `- [x] ... *(completed)*`.

**Step 3: Verify Zero Unannotated Unchecked Items**
After addressing all items, confirm no `- [ ]` items remain without
annotation in the current phase's Tasks section. Only then proceed to
Stage 4D-iii (handoff update) and the next phase.

**Note**: If the plan file does not use `- [ ]` checklist syntax, skip this
step. The progress file (if used) remains the authoritative tracking mechanism.
```

---

### 6. Differences Between the Three Agents

| Aspect | general-implementation-agent | neovim-implementation-agent | nix-implementation-agent |
|--------|------------------------------|-----------------------------|--------------------------| 
| Progress file | Yes (required) | No | No |
| Explicit 4B-ii check-off | Yes (Stage 4B-ii) | No (deviation-only in B.4) | No (deviation-only in C.5) |
| Post-phase step name | Stage 4D-ii | Stage 4D-ii | Stage 4D-ii |
| Domain verification in self-review | No | Yes (`nvim --headless`) | Yes (`nix flake check`) |
| Step letter for mark COMPLETED | D | D | E |

**Key implication**: The neovim and nix agents should also receive the equivalent of general's Stage 4B-ii (explicit check-off during execution), not just the post-phase gate. Or alternatively, the post-phase gate is designed to catch what 4B-ii would have missed — in which case the gate serves as the safety net for neovim/nix since they lack 4B-ii.

---

### 7. Plan File Subtask Format

From `plan-format.md` and `plan-format-enforcement.md`, the canonical formats are:

**During execution (Stage 4B-ii)**:
```
- [ ] **Task {P}.{N}**: {description}                        ← not started
- [x] **Task {P}.{N}**: {description} *(completed)*          ← completed
- [ ] **Task {P}.{N}**: {description} *(in progress)*         ← in progress
- [ ] **Task {P}.{N}**: {description} *(in progress — handoff)* ← at handoff
```

**Deviation annotations**:
```
- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*
- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*
- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*
```

The gate should consider an item "addressed" if it either:
1. Has `- [x]` (checked off as completed, possibly with a note), OR
2. Has `- [ ]` with a `*(deviation:` annotation (explicitly skipped/deferred), OR
3. Has `- [ ]` with `*(in progress — handoff)*` (acknowledged in handoff context)

An item is "unaddressed" (should trigger the gate) if it has `- [ ]` with NO annotation, OR `- [ ]` with only `*(in progress)*` (which means it was started but not finished or annotated as a deviation).

---

## Decisions

- The validation step should be inserted as the **first part of Stage 4D-ii** (not as a new Stage 4D-iii, which would renumber the existing handoff stage)
- The existing Stage 4D-ii prose should be kept but made explicitly conditional on completing Step 2 (address unchecked items) first
- The note about "if plan file does not use checklist syntax, skip this step" should be preserved from the general agent's existing 4B-ii note
- All three agent files need the same validation addition; only the "Note" in neovim/nix may differ slightly (no progress file references)
- The gate should NOT fail hard — it should require completion or annotation (two paths), not block outright

---

## Risks & Mitigations

- **Risk**: Adding an explicit count creates confusion about what counts as "addressed" (is `*(in progress)*` ok?)
  - **Mitigation**: Define the three accepted states clearly: `- [x]` (completed), `- [ ]` with `*(deviation:` (annotated skip/defer), `- [ ]` with `*(in progress — handoff)*` (handoff context only). Plain `*(in progress)*` should trigger completion.

- **Risk**: The validation step adds mechanical overhead to every phase transition
  - **Mitigation**: The step is trivially cheap — re-read a section of the plan file (already in context from earlier in the phase) and scan for `- [ ]` patterns. This is < 1 tool call overhead.

- **Risk**: Agents may mark everything `*(deviation: skipped — N/A)*` to satisfy the gate without doing real work
  - **Mitigation**: This is an acceptable tradeoff. The gate creates a paper trail of skipped items, which is more traceable than the current silent skip. The self-review language ("evaluate whether it should be completed") remains to discourage lazy skipping.

- **Risk**: Neovim/nix agents lack Stage 4B-ii, so the post-phase gate will catch more items than for the general agent
  - **Mitigation**: This is the intended behavior — the gate is a safety net. No change needed to neovim/nix step B/C for this task; the gate catches accumulated un-annotated items.

---

## Context Extension Recommendations

None — this is a meta task modifying agent files. The agent files themselves document the new behavior.

---

## Appendix

### Files to Modify
1. `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
   - Lines 197–225 (Stage 4D-ii) — restructure to add count-and-gate step as Step 1
   
2. `/home/benjamin/.config/nvim/.claude/agents/neovim-implementation-agent.md`
   - Lines 173–182 (Stage 4D-ii) — add count-and-gate step; domain verification remains as final step
   
3. `/home/benjamin/.config/nvim/.claude/agents/nix-implementation-agent.md`
   - Lines 199–208 (Stage 4D-ii) — add count-and-gate step; `nix flake check` remains as final step

### Key Line References

| File | Current Stage 4D-ii Start | Insertion Point |
|------|--------------------------|-----------------|
| general-implementation-agent.md | Line 197 | Insert before existing point 1 |
| neovim-implementation-agent.md | Line 173 | Insert before existing point 1 |
| nix-implementation-agent.md | Line 199 | Insert before existing point 1 |

### Search Queries Used
- Read: `.claude/agents/general-implementation-agent.md` (full file)
- Read: `.claude/agents/neovim-implementation-agent.md` (full file)
- Read: `.claude/agents/nix-implementation-agent.md` (full file)
- Read: `.claude/context/formats/plan-format.md` (full file)
- Read: `.claude/rules/plan-format-enforcement.md` (full file)
- Read: `specs/ROADMAP.md`
