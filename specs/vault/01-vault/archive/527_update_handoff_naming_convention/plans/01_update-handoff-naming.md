# Implementation Plan: Update Handoff Naming Convention

- **Task**: 527 - update_handoff_naming_convention
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/527_update_handoff_naming_convention/reports/01_handoff-naming-research.md
- **Artifacts**: plans/01_update-handoff-naming.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update the handoff artifact system to use the `MM_HH_{handoff-slug}.md` naming convention, replacing the current timestamp-based `phase-{P}-handoff-{TIMESTAMP}.md` pattern. This change affects format specifications, agent definitions, and pattern documentation across `.opencode/context/`, `.opencode/agent/`, and their `.opencode/extensions/core/` mirrors.

### Research Integration

The research report identified **13 files** requiring updates across three categories:
- **Format specs** (2 files): `handoff-artifact.md` primary and mirror
- **Agent definitions** (3 files): `general-implementation-agent.md` primary and mirror, plus `lean-implementation-agent.md`
- **Pattern documentation** (4 files): `context-exhaustion-detection.md` and `subagent-continuation-loop.md` primary and mirrors

The `handoff_count` field in progress files already tracks handoff sequences and serves as the foundation for the `HH` component.

### Prior Plan Reference

No prior plan existed for this task.

### Roadmap Alignment

No direct ROADMAP.md item maps to this task. This is a meta-level improvement to agent system consistency and follows from ongoing context cleanup work (related to "Subagent-return reference cleanup" in Phase 1 priorities).

## Goals & Non-Goals

**Goals**:
- Update `handoff-artifact.md` format spec with new naming convention, variable definitions, and slug generation guidelines
- Update `general-implementation-agent.md` Stage 4C filename construction logic and metadata examples
- Update `lean-implementation-agent.md` handoff protocol references
- Update `context-exhaustion-detection.md` and `subagent-continuation-loop.md` example paths
- Mirror all changes to `.opencode/extensions/core/` counterparts
- Verify zero remaining references to old `phase-.*-handoff-` patterns

**Non-Goals**:
- Migrate or rename existing handoff files on disk
- Modify progress file schema beyond the filename references
- Update return-metadata-file.md or progress-file.md (no explicit old filenames present)
- Changes to the handoff content/template structure itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Inconsistent mirroring between primary and extension/core files | Medium | Medium | Use exact copy-diff workflow; verify each mirror matches primary |
| Slug generation edge cases (empty objective, special chars) not documented | Low | Medium | Include explicit fallback rules in format spec (phase-name-only, then `handoff`) |
| Old naming pattern referenced in files outside the identified 13 | Medium | Low | Final verification phase greps entire `.opencode/` for `phase-.*-handoff-` |
| General-implementation-agent Stage 4C bash logic becomes complex | Medium | Low | Keep construction simple: `handoff_count=$((handoff_count + 1))` then assemble filename |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 5, 6 | -- |
| 2 | 2, 4, 7 | 1, 3, 6 |
| 3 | 8 | 2, 4, 5, 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Handoff Format Spec (Primary) [COMPLETED]

**Goal**: Rewrite `.opencode/context/formats/handoff-artifact.md` to document the new naming convention.

**Tasks**:
- [x] **Task 1.1**: Replace file location template: `specs/{N}_{SLUG}/handoffs/MM_HH_{handoff-slug}.md` *(completed)*
- [x] **Task 1.2**: Update variable definitions table with `MM` (artifact_number, 2-digit), `HH` (handoff_count+1, 2-digit), and `{handoff-slug}` *(completed)*
- [x] **Task 1.3**: Update all example filenames in the document to use new convention *(completed)*
- [x] **Task 1.4**: Update directory tree examples to show `02_01_implement-validation-framework.md` style names *(completed)*
- [x] **Task 1.5**: Update metadata examples (`handoff_path`, artifact `path`, `partial_progress.handoff_path`) *(completed)*
- [x] **Task 1.6**: Add explicit "Slug Generation" section documenting kebab-case derivation rules, truncation, and fallback behavior *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.opencode/context/formats/handoff-artifact.md`

**Verification**:
- Read the file and confirm all 8 old-pattern occurrences are replaced
- Confirm slug generation section exists and covers edge cases

---

### Phase 2: Mirror Handoff Format Spec to Extensions/Core [COMPLETED]

**Goal**: Apply identical changes to `.opencode/extensions/core/context/formats/handoff-artifact.md`.

**Tasks**:
- [x] **Task 2.1**: Copy the updated primary file to the mirror location, or apply the same edits individually *(completed)*
- [x] **Task 2.2**: Diff primary against mirror to confirm exact match *(completed: zero differences)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/extensions/core/context/formats/handoff-artifact.md`

**Verification**:
- `diff` between primary and mirror shows zero differences (excluding any extension-specific preamble if present)

---

### Phase 3: Update General Implementation Agent [COMPLETED]

**Goal**: Rewrite filename construction and metadata examples in `.opencode/agent/subagents/general-implementation-agent.md`.

**Tasks**:
- [x] **Task 3.1**: Update Stage 4C bash `handoff_file` construction: replace `$(date -u +%Y%m%dT%H%M%SZ)` with `artifact_number`, incremented `handoff_count`, and auto-generated slug *(completed)*
- [x] **Task 3.2**: Update Stage 7 metadata JSON example: `handoff_path` value *(completed)*
- [x] **Task 3.3**: Update Stage 7 metadata JSON example: `artifacts[].path` value *(completed)*
- [x] **Task 3.4**: Review surrounding Stage 4C text for any other timestamp references *(completed: zero remaining)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.opencode/agent/subagents/general-implementation-agent.md`

**Verification**:
- Confirm 4 old-pattern occurrences are replaced
- Confirm bash logic correctly increments `handoff_count` before using it

---

### Phase 4: Mirror General Implementation Agent to Extensions/Core [COMPLETED]

**Goal**: Apply identical changes to `.opencode/extensions/core/agents/general-implementation-agent.md`.

**Tasks**:
- [x] **Task 4.1**: Apply the same edits as Phase 3 to the mirror file *(completed)*
- [x] **Task 4.2**: Diff primary against mirror to confirm exact match *(completed: zero differences)*

**Timing**: 0.5 hours

**Depends on**: 3

**Files to modify**:
- `.opencode/extensions/core/agents/general-implementation-agent.md`

**Verification**:
- `diff` between primary and mirror shows zero differences (excluding any extension-specific preamble if present)

---

### Phase 5: Update Lean Implementation Agent [COMPLETED]

**Goal**: Add explicit reference to new naming convention in `.opencode/extensions/lean/agents/lean-implementation-agent.md`.

**Tasks**:
- [x] **Task 5.1**: Locate Handoff Protocol section and verify it currently references `specs/{N}_{SLUG}/handoffs/` without filename detail *(completed)*
- [x] **Task 5.2**: Add sentence referencing `handoff-artifact.md` format spec and noting filenames follow `MM_HH_{handoff-slug}.md` *(completed)*
- [x] **Task 5.3**: Verify lean agent references general implementation agent's progress initialization (Stage 3.5) or note if `handoff_count` initialization needs explicit mention *(completed: added handoff_count note)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/lean/agents/lean-implementation-agent.md`

**Verification**:
- Confirm handoff protocol section mentions the new naming convention
- Confirm no stale `phase-.*-handoff-` references exist

---

### Phase 6: Update Pattern Documentation (Primary) [COMPLETED]

**Goal**: Update example paths in `context-exhaustion-detection.md` and `subagent-continuation-loop.md`.

**Tasks**:
- [x] **Task 6.1**: Update `context-exhaustion-detection.md` JSON example: `handoff_path` value *(completed: primary already updated)*
- [x] **Task 6.2**: Update `context-exhaustion-detection.md` JSON example: `artifacts[].path` value *(completed: primary already updated)*
- [x] **Task 6.3**: Update `subagent-continuation-loop.md` delegation context example: `continuation_context.handoff_path` value *(completed: primary already updated)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.opencode/context/patterns/context-exhaustion-detection.md`
- `.opencode/context/patterns/subagent-continuation-loop.md`

**Verification**:
- Confirm 2 old-pattern occurrences replaced in context-exhaustion-detection.md
- Confirm 1 old-pattern occurrence replaced in subagent-continuation-loop.md

---

### Phase 7: Mirror Pattern Docs to Extensions/Core [COMPLETED]

**Goal**: Apply identical changes to extension/core pattern documentation mirrors.

**Tasks**:
- [x] **Task 7.1**: Apply Phase 6 changes to `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md` *(completed)*
- [x] **Task 7.2**: Apply Phase 6 changes to `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md` *(completed)*
- [x] **Task 7.3**: Diff primaries against mirrors to confirm exact matches *(completed: zero differences)*

**Timing**: 0.5 hours

**Depends on**: 6

**Files to modify**:
- `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`

**Verification**:
- `diff` between each primary and mirror shows zero differences

---

### Phase 8: Final Verification [COMPLETED]

**Goal**: Ensure zero remaining references to old naming patterns across the entire `.opencode/` tree.

**Tasks**:
- [x] **Task 8.1**: Run `grep -r "phase-.*-handoff-" .opencode/` and confirm zero matches (excluding this plan and research report) *(completed: zero matches)*
- [x] **Task 8.2**: Run `grep -r "handoff-.*20[0-9][0-9]" .opencode/` as secondary check for timestamp-based handoff filenames *(completed: zero matches)*
- [x] **Task 8.3**: Run `grep -r "MM_HH_" .opencode/` to confirm new convention references are present in expected files *(completed: 3 matches in expected files)*
- [x] **Task 8.4**: Manual spot-check of the 9 modified files for consistency *(completed: all consistent)*

**Timing**: 0.5 hours

**Depends on**: 2, 4, 5, 7

**Files to modify**:
- None (verification only)

**Verification**:
- All grep commands return expected results (zero old patterns, new patterns present in modified files)
- Spot-check confirms formatting and consistency

## Testing & Validation

- [ ] All 9 modified files contain zero references to `phase-{P}-handoff-{TIMESTAMP}.md`
- [ ] All 4 mirror files are byte-for-byte identical to their primaries (within extension-specific boundaries)
- [ ] `handoff-artifact.md` contains a complete slug generation section with edge case handling
- [ ] `general-implementation-agent.md` Stage 4C shows correct bash logic for `handoff_count` increment and filename assembly
- [ ] `lean-implementation-agent.md` references the new convention without contradicting general implementation agent

## Artifacts & Outputs

- `specs/527_update_handoff_naming_convention/plans/01_update-handoff-naming.md` (this file)
- Modified `.opencode/context/formats/handoff-artifact.md`
- Modified `.opencode/extensions/core/context/formats/handoff-artifact.md`
- Modified `.opencode/agent/subagents/general-implementation-agent.md`
- Modified `.opencode/extensions/core/agents/general-implementation-agent.md`
- Modified `.opencode/extensions/lean/agents/lean-implementation-agent.md`
- Modified `.opencode/context/patterns/context-exhaustion-detection.md`
- Modified `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- Modified `.opencode/context/patterns/subagent-continuation-loop.md`
- Modified `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`

## Rollback/Contingency

- All changes are to documentation/specification files; no runtime code or data is affected.
- If errors are found post-implementation, revert individual files via `git checkout -- <path>`.
- If the new convention causes issues during agent execution, the old timestamp-based naming can be restored by reverting the agent definition files while keeping the format spec updated.
