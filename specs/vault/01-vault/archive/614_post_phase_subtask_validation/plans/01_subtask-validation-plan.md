# Implementation Plan: Task #614

- **Task**: 614 - post_phase_subtask_validation
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/614_post_phase_subtask_validation/reports/01_subtask-validation.md
- **Artifacts**: plans/01_subtask-validation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a mandatory count-and-gate validation step to the post-phase self-review (Stage 4D-ii) of all three implementation agents. Currently, agents are instructed to review unchecked items but nothing blocks phase transition if items remain unaddressed. The fix restructures Stage 4D-ii into a three-step gate: (1) count unchecked/unannotated items, (2) address each one, (3) verify zero remain before proceeding. Additionally, the neovim and nix agents lack the general agent's Stage 4B-ii check-off instruction, so that instruction will be backported to both.

### Research Integration

Research report (01_subtask-validation.md) confirmed:
- All three agents mark phase `[COMPLETED]` before the advisory post-phase review runs
- Stage 4D-ii is advisory only with no count, gate, or enforcement
- Neovim and nix agents lack the general agent's Stage 4B-ii (explicit check-off of completed items during execution)
- The same validation text applies to all three agents with minor domain-specific adaptations (progress file references for general, `nvim --headless` for neovim, `nix flake check` for nix)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This falls under the broader "Agent System Quality" category but is not an explicit roadmap item.

## Goals & Non-Goals

**Goals**:
- Add a mandatory count-and-gate step to Stage 4D-ii in all three implementation agents
- Backport the Stage 4B-ii check-off instruction to neovim and nix agents
- Ensure consistent validation behavior across all implementation agents
- Create a paper trail (deviation annotations) for any skipped/deferred items

**Non-Goals**:
- Changing when `[COMPLETED]` is marked (it remains at Stage 4D, before the self-review)
- Adding automated tooling or scripts for validation (this is instruction-level enforcement)
- Modifying other agent types (research, planner, meta)
- Adding progress file support to neovim or nix agents

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agents satisfying gate with lazy `*(deviation: skipped)` annotations | M | M | Acceptable tradeoff: creates traceable paper trail vs silent skips |
| Validation adds overhead to every phase transition | L | L | Step is trivially cheap: re-read plan section already in context, scan for `- [ ]` patterns |
| Inconsistent annotation format across agents | M | L | Use identical format strings in all three agents, referencing plan-format-enforcement.md |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add count-and-gate validation to general-implementation-agent.md [COMPLETED]

**Goal**: Restructure Stage 4D-ii in the general implementation agent to include a mandatory three-step gate (count, address, verify) while preserving existing deviation annotation format and progress file references.

**Tasks**:
- [x] **Task 1.1**: Read current Stage 4D-ii text (lines 197-225) in `general-implementation-agent.md` *(completed)*
- [x] **Task 1.2**: Replace Stage 4D-ii heading and content with restructured version that adds Step 1 (count unchecked/unannotated items), Step 2 (address each item with three paths: mark completed, annotate deviation, or complete now), and Step 3 (verify zero unannotated unchecked items remain) *(completed)*
- [x] **Task 1.3**: Preserve existing progress file references (deviations array, objective note field) within the restructured text *(completed)*
- [x] **Task 1.4**: Verify the note about "if plan file does not use checklist syntax, skip this step" is retained *(completed)*
- [x] **Task 1.5**: Read the modified file to confirm structural consistency with surrounding stages (4D, 4D-iii) *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` - Restructure Stage 4D-ii (lines 197-225)

**Verification**:
- Stage 4D-ii contains three numbered steps: "Count Unchecked Items", "Address Each Unchecked Item", "Verify Zero Unannotated Unchecked Items"
- Existing deviation format references are preserved
- Progress file integration is maintained
- The closing line "Only then proceed to Stage 4D-iii..." remains

---

### Phase 2: Add check-off instruction and count-and-gate validation to neovim-implementation-agent.md [COMPLETED]

**Goal**: Add the missing Stage 4B-ii check-off instruction (backported from general agent) after Step B.4, then restructure Stage 4D-ii to include the same count-and-gate validation with neovim-specific domain verification.

**Tasks**:
- [x] **Task 2.1**: Read current Step B section (lines 133-153) and Stage 4D-ii (lines 173-182) in `neovim-implementation-agent.md` *(completed)*
- [x] **Task 2.2**: Insert a new `#### 4B-ii. Check Off Completed Items in Plan File` section after the existing Step B.4 (deviation annotation) block, adapted from the general agent's 4B-ii but without progress file references *(completed)*
- [x] **Task 2.3**: Replace Stage 4D-ii heading and content with the restructured count-and-gate version, adapted for neovim (no progress file, domain verification via `nvim --headless`) *(completed)*
- [x] **Task 2.4**: Ensure the domain verification step ("Verify Neovim starts without errors") is preserved as part of the restructured 4D-ii *(completed)*
- [x] **Task 2.5**: Read the modified file to confirm structural consistency *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/neovim-implementation-agent.md` - Add 4B-ii after Step B.4; restructure Stage 4D-ii (lines 173-182)

**Verification**:
- New Stage 4B-ii section exists between Step B.4 and Step C
- Stage 4D-ii contains three numbered steps matching Phase 1's structure
- `nvim --headless` verification command is preserved
- No progress file references are present (neovim agent does not use them)

---

### Phase 3: Add check-off instruction and count-and-gate validation to nix-implementation-agent.md [COMPLETED]

**Goal**: Add the missing Stage 4B-ii check-off instruction (backported from general agent) after Step C.5, then restructure Stage 4D-ii to include the same count-and-gate validation with nix-specific domain verification.

**Tasks**:
- [x] **Task 3.1**: Read current Step C section (lines 156-181) and Stage 4D-ii (lines 199-208) in `nix-implementation-agent.md` *(completed)*
- [x] **Task 3.2**: Insert a new `#### 4C-ii. Check Off Completed Items in Plan File` section after the existing Step C.5 (deviation annotation) block, adapted from the general agent's 4B-ii but without progress file references. Note: uses "C" step lettering, so the sub-stage label references Step C.5 appropriately *(completed: labeled 4C-ii to match C step naming)*
- [x] **Task 3.3**: Replace Stage 4D-ii heading and content with the restructured count-and-gate version, adapted for nix (no progress file, domain verification via `nix flake check`) *(completed)*
- [x] **Task 3.4**: Ensure the domain verification step ("Verify nix flake check passes") is preserved as part of the restructured 4D-ii *(completed)*
- [x] **Task 3.5**: Read the modified file to confirm structural consistency *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add 4B-ii after Step C.5; restructure Stage 4D-ii (lines 199-208)

**Verification**:
- New check-off section exists between Step C.5 and Step D
- Stage 4D-ii contains three numbered steps matching Phase 1's structure
- `nix flake check` verification command is preserved
- No progress file references are present (nix agent does not use them)

## Testing & Validation

- [ ] All three agent files have structurally identical Stage 4D-ii content (same three steps, same annotation format, same gate logic)
- [ ] The general agent's Stage 4B-ii is unchanged (it already exists)
- [ ] The neovim agent has a new 4B-ii section with check-off instructions (no progress file references)
- [ ] The nix agent has a new check-off section with check-off instructions (no progress file references)
- [ ] Domain-specific verification commands are preserved in each agent's 4D-ii (general: progress file; neovim: nvim --headless; nix: nix flake check)
- [ ] No other stages or sections in any agent file are modified
- [ ] The annotation format strings (`*(completed)*`, `*(deviation: skipped -- {reason})*`, etc.) match plan-format-enforcement.md

## Artifacts & Outputs

- `.claude/agents/general-implementation-agent.md` - Restructured Stage 4D-ii
- `.claude/agents/neovim-implementation-agent.md` - New 4B-ii + restructured Stage 4D-ii
- `.claude/agents/nix-implementation-agent.md` - New check-off section + restructured Stage 4D-ii
- `specs/614_post_phase_subtask_validation/plans/01_subtask-validation-plan.md` (this file)

## Rollback/Contingency

All changes are to markdown instruction files in `.claude/agents/`. Rollback via `git checkout` of the three agent files. No code, configuration, or state changes are involved.
