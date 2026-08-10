# Research Report: Task #555

- **Task**: 555 - Update proof workflow docs with literature-first stages
- **Started**: 2026-05-12T18:00:00Z
- **Completed**: 2026-05-12T18:15:00Z
- **Effort**: 1-2 hours
- **Dependencies**: Task #553 (Lean literature fidelity policy), Task #554 (Formal literature fidelity policy)
- **Sources/Inputs**:
  - Codebase: 3 target workflow files, 2 literature fidelity policies, tactic-patterns.md, verification-workflow.md
- **Artifacts**:
  - `specs/555_update_proof_workflow_literature/reports/01_proof-workflow-literature.md`
- **Standards**: report-format.md

## Executive Summary

- All three target files exist and have clear insertion points for literature-first stages
- `lean-implementation-flow.md` (173 lines) needs a new Stage 1.5 and modifications to Stage 4B's proof loop
- `end-to-end-proof-workflow.md` (52 lines) needs a new Step 0 prerequisite and modifications to Step 2
- `proof-construction.md` (143 lines) needs a literature-first strategy in the "Choose Strategy" section
- `tactic-patterns.md` could benefit from a brief note but is NOT required (it is a reference, not a workflow)
- Both literature fidelity policies (Lean: 127 lines, Formal: 258 lines) are well-structured and can be cross-referenced cleanly

## Context & Scope

Task 553 created a literature fidelity policy for the Lean extension. Task 554 created one for the Formal extension. These policies define two modes (literature-guided vs. first-principles) and anti-patterns. However, the existing workflow documents that agents follow during proof development do not reference these policies. This task modifies three workflow documents to integrate literature-first stages so agents consult literature BEFORE entering tactic exploration and automation loops.

## Findings

### File 1: lean-implementation-flow.md

**Path**: `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
**Lines**: 173
**Current structure**:
- Stage 1: Parse Delegation Context (lines 12-31)
- Stage 2: Load and Parse Implementation Plan (lines 35-42)
- Stage 3: Find Resume Point (lines 46-53)
- Stage 4: Execute Proof Development Loop (lines 57-93)
  - 4A: Mark Phase In Progress
  - 4B: Execute Proof Development (lines 69-84) -- the main proof loop
  - 4C: Verify Phase Completion
  - 4D: Mark Phase Complete
- Stage 5-8: Final build, summary, metadata, return

**Insertion Point 1: New Stage 1.5** (between line 31 and line 35)

Insert a new "Stage 1.5: Check for Literature Source" after Stage 1 (Parse Delegation Context) and before Stage 2 (Load and Parse Implementation Plan). This stage examines the task description and delegation context for literature references.

**Insertion Point 2: Modify Stage 4B** (lines 69-84)

The current Stage 4B proof loop is:
```
1. Read target file, locate proof point
2. Check current proof state using lean_goal
3. Develop proof iteratively
   REPEAT until goals closed or stuck:
     a. Use lean_goal to see current state
     b. Use lean_multi_attempt to try candidate tactics
     c. If promising tactic found, apply via Edit
     d. If stuck, use lean_state_search, lean_hammer_premise
     e. If still stuck, log state and return partial
4. Verify step completion with lean_goal and lake build
```

This needs to be modified so step 3 starts with "Consult literature source" BEFORE trying lean_multi_attempt. When in literature-guided mode, the agent should:
1. Identify which literature step corresponds to the current goal
2. Translate that step into Lean tactics
3. Only fall back to lean_multi_attempt/automation if the literature doesn't cover this specific sub-goal

**Insertion Point 3: Modify Tactic Selection Strategy** (lines 142-147)

The "Tactic Selection Strategy" section lists:
1. Start Simple: simp, rfl, trivial, decide, ring, omega
2. Structural Tactics: intro, cases, rcases, induction
3. Application Tactics: exact h, apply lemma, have
4. Automation: simp [...], aesop, omega

This should be prefixed with: "Step 0 (literature-guided mode only): Follow the literature's prescribed tactic/approach for this step."

**Cross-reference**: Link to `literature-fidelity-policy.md` (Lean extension) for full policy details.

### File 2: end-to-end-proof-workflow.md

**Path**: `.claude/extensions/lean/context/project/lean4/processes/end-to-end-proof-workflow.md`
**Lines**: 52
**Current structure**:
- Overview (lines 1-6)
- When to Use (lines 8-10)
- Prerequisites (lines 12-15): Clear theorem statement, understanding of math concepts
- Step 1: State the Theorem (lines 19-23)
- Step 2: Outline the Proof (lines 25-29)
- Step 3: Fill in the Proof (lines 31-35)
- Step 4: Refactor the Proof (lines 37-41)
- Context Dependencies (lines 43-47)
- Success Criteria (lines 49-52)

**Insertion Point 1: New "Step 0: Check for Literature Source"** (between lines 17-19)

Insert a new Step 0 before Step 1 that checks whether a literature source is provided. If yes, the agent enters literature-guided mode. If no, first-principles mode applies and the rest of the workflow proceeds unchanged.

**Insertion Point 2: Modify Step 2 (Outline the Proof)** (lines 25-29)

Current Step 2:
```
**Action**: Write a high-level outline of the proof in comments.
**Validation**: The outline should be a valid argument for the theorem.
**Output**: A commented proof outline.
```

When a literature source is provided, Step 2 should explicitly state: "Extract the proof outline from the literature source rather than composing one independently. The outline should mirror the source's argument structure."

**Insertion Point 3: Add to Context Dependencies** (lines 43-47)

Add `literature-fidelity-policy.md` to the context dependencies list.

**Insertion Point 4: Add to Success Criteria** (lines 49-52)

Add: "When a literature source is provided, the proof structure mirrors the source."

**Cross-reference**: Link to `literature-fidelity-policy.md` (Lean extension).

### File 3: proof-construction.md

**Path**: `.claude/extensions/formal/context/project/logic/processes/proof-construction.md`
**Lines**: 143
**Current structure**:
- Overview (lines 1-5)
- Proof Planning (lines 7-25):
  - 1. Analyze the Goal (lines 9-13)
  - 2. Identify Available Tools (lines 15-19)
  - 3. Choose Strategy (lines 21-25): "Direct proof vs indirect proof / Forward vs backward reasoning / Induction vs case analysis"
- Proof Development Phases 1-4 (lines 27-52)
- Best Practices (lines 54-70)
- Common Proof Patterns (lines 72-100)
- Lean 4 Proof Tactics (lines 102-117)
- Quality Criteria (lines 119-136)
- References (lines 138-143)

**Insertion Point 1: Modify "Choose Strategy" section** (lines 21-25)

Current:
```
### 3. Choose Strategy

- Direct proof vs indirect proof
- Forward vs backward reasoning
- Induction vs case analysis
```

This should be expanded to include a literature-first option. When a reference proof exists, the strategy is "follow the reference" -- the existing strategy options (direct/indirect/induction) apply only in first-principles mode.

**Insertion Point 2: Add note to Proof Development Phases** (lines 27-52)

Phase 1 (Sketch) currently says:
```
1. Write informal proof idea
2. Identify key lemmas needed
3. Note potential difficulties
```

When in literature-guided mode, Phase 1 becomes: "Extract the proof structure from the provided literature source" rather than "Write informal proof idea."

**Insertion Point 3: Add to References** (line 143)

Add the formal extension's literature fidelity policy as a reference.

**Cross-reference**: Link to `literature-fidelity-policy.md` (Formal extension).

### Additional Files Assessed

**tactic-patterns.md** (`.claude/extensions/lean/context/project/lean4/patterns/tactic-patterns.md`, 151 lines): This is a reference document listing tactic syntax. It does NOT contain workflow logic or decision-making guidance. Adding a literature-first note here would be out of scope -- the tactic selection strategy in `lean-implementation-flow.md` already handles this. No changes needed.

**verification-workflow.md** (`.claude/extensions/formal/context/project/logic/processes/verification-workflow.md`, 131 lines): The formal extension's literature fidelity policy already documents the interaction with verification-workflow.md (lines 238-241): "Verification in literature-guided mode has an additional dimension: checking correspondence to the source's steps." The formal policy handles this cross-reference. No direct modifications needed.

**modal-proof-strategies.md** and **temporal-proof-strategies.md**: These are domain-specific strategy documents. They would benefit from a literature-first note in a future task, but are out of scope for this task (which targets the three files listed in the task description).

## Decisions

- The tactic-patterns.md file does NOT need modification (reference doc, not workflow)
- The verification-workflow.md file does NOT need modification (already cross-referenced by the formal literature fidelity policy)
- Each of the three target files should cross-reference the literature fidelity policy from its own extension (Lean files reference Lean policy, Formal files reference Formal policy)

## Draft Content Snippets

### lean-implementation-flow.md: Stage 1.5

```markdown
## Stage 1.5: Check for Literature Source

Before loading the plan, check whether the task involves a literature source:

1. **Scan delegation context** for literature references in task description
2. **Check plan artifacts** (if previously loaded) for literature step annotations
3. **Determine mode**: If literature source found, enter **literature-guided mode**; otherwise, **first-principles mode**

In literature-guided mode:
- Load the literature source (paper, textbook section, proof sketch)
- Identify the proof strategy prescribed by the source
- Map source steps to expected proof development stages
- Carry this mapping into Stage 4B for step-by-step translation

See `literature-fidelity-policy.md` for full mode detection criteria and anti-patterns.

---
```

### lean-implementation-flow.md: Modified Stage 4B

```markdown
### 4B. Execute Proof Development

For each proof/theorem in the phase:

1. **Read target file, locate proof point**
2. **Check current proof state** using `lean_goal`
3. **Consult literature source** (literature-guided mode only)
   - Identify which literature step corresponds to the current goal
   - Translate the literature step into Lean tactics/terms
   - If translation is clear, apply directly via Edit
   - If translation is unclear, follow escalation protocol from `literature-fidelity-policy.md`
4. **Develop proof iteratively** (first-principles mode, or when literature step is not applicable)
   ```
   REPEAT until goals closed or stuck:
     a. Use lean_goal to see current state
     b. Use lean_multi_attempt to try candidate tactics
     c. If promising tactic found, apply via Edit
     d. If stuck, use lean_state_search, lean_hammer_premise
     e. If still stuck, log state and return partial
   ```
5. **Verify step completion** with `lean_goal` and `lake build`
```

### lean-implementation-flow.md: Modified Tactic Selection Strategy

```markdown
### Tactic Selection Strategy

0. **Literature step** (literature-guided mode): Follow the tactic/approach prescribed by the source for this step. See `literature-fidelity-policy.md`.
1. **Start Simple**: `simp`, `rfl`, `trivial`, `decide`, `ring`, `omega`
2. **Structural Tactics**: `intro`, `cases`, `rcases`, `induction`
3. **Application Tactics**: `exact h`, `apply lemma`, `have`
4. **Automation**: `simp [...]`, `aesop`, `omega`
```

### end-to-end-proof-workflow.md: Step 0

```markdown
### Step 0: Check for Literature Source

**Action**: Determine whether a literature source (paper, textbook, lecture notes) is provided for this proof.
**Validation**: If a source exists, identify the specific proof or argument to follow.
**Output**: Mode determination -- literature-guided or first-principles.

When a literature source is provided:
- Extract the proof structure from the source before proceeding to Step 1
- Steps 2-4 should follow the source's argument structure
- See `literature-fidelity-policy.md` for full policy details
```

### end-to-end-proof-workflow.md: Modified Step 2

```markdown
### Step 2: Outline the Proof

**Action**: Write a high-level outline of the proof in comments. In literature-guided mode, extract the outline from the literature source rather than composing one independently.
**Validation**: The outline should be a valid argument for the theorem. In literature-guided mode, it should mirror the source's argument structure (same decomposition, same ordering).
**Output**: A commented proof outline, with literature step references when applicable.
```

### proof-construction.md: Modified "Choose Strategy"

```markdown
### 3. Choose Strategy

- **Literature-guided** (when a reference proof is provided): Follow the reference. The strategy, lemma decomposition, and proof technique are determined by the source. See `literature-fidelity-policy.md`.
- **First-principles** (when no reference is provided): Choose from:
  - Direct proof vs indirect proof
  - Forward vs backward reasoning
  - Induction vs case analysis
```

### proof-construction.md: Modified Phase 1

```markdown
### Phase 1: Sketch

1. Write informal proof idea (first-principles) OR extract proof structure from literature source (literature-guided)
2. Identify key lemmas needed
3. Note potential difficulties
```

## Recommendations

- **Priority 1**: Modify all three target files as documented above
- **Priority 2**: Add literature-fidelity-policy.md to the Context Dependencies section of end-to-end-proof-workflow.md
- **Priority 3**: Add a literature-guided success criterion to end-to-end-proof-workflow.md
- No changes needed to tactic-patterns.md, verification-workflow.md, or other process docs

## Risks & Mitigations

- **Risk**: Adding too much content to lean-implementation-flow.md could make Stage 4B harder to follow
  - **Mitigation**: Keep the literature consultation step brief and reference the full policy document for details
- **Risk**: Agents may interpret the modified workflow as requiring literature checks even in first-principles mode
  - **Mitigation**: Each insertion explicitly gates on "literature-guided mode only" or "when a reference proof is provided"
- **Risk**: Cross-references between lean/formal extensions could create confusion about which policy applies
  - **Mitigation**: Each file references only its own extension's policy (lean files -> lean policy, formal files -> formal policy)

## Appendix

### Files Read
- `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (173 lines)
- `.claude/extensions/lean/context/project/lean4/processes/end-to-end-proof-workflow.md` (52 lines)
- `.claude/extensions/formal/context/project/logic/processes/proof-construction.md` (143 lines)
- `.claude/extensions/lean/context/project/lean4/standards/literature-fidelity-policy.md` (127 lines)
- `.claude/extensions/formal/context/project/logic/standards/literature-fidelity-policy.md` (258 lines)
- `.claude/extensions/lean/context/project/lean4/patterns/tactic-patterns.md` (151 lines)
- `.claude/extensions/formal/context/project/logic/processes/verification-workflow.md` (131 lines)

### Cross-Reference Summary
| Target File | Policy to Reference | Extension |
|---|---|---|
| lean-implementation-flow.md | literature-fidelity-policy.md | lean |
| end-to-end-proof-workflow.md | literature-fidelity-policy.md | lean |
| proof-construction.md | literature-fidelity-policy.md | formal |
