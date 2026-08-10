# Implementation Plan: Update Continuation Loop Documentation

- **Task**: 528 - update_continuation_loop_docs
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: Task 527 (soft dependency - naming convention definition)
- **Research Inputs**: specs/528_update_continuation_loop_docs/reports/01_continuation-loop-docs-research.md
- **Artifacts**: plans/01_update-continuation-loop-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown

## Overview

Task 527 introduces a new handoff artifact naming convention `MM_HH_{handoff-slug}.md`. This task updates all pattern documents, format specifications, and agent definitions that contain example `handoff_path` values to use the new convention instead of the old `phase-{P}-handoff-{TIMESTAMP}.md` pattern. After updating the primary files in `.opencode/context/`, `.opencode/agent/`, and `.opencode/skills/`, all changes are synced to their `.opencode/extensions/core/` mirrors. A final verification pass ensures no stale references remain anywhere in the codebase.

### Research Integration

The research report (01_continuation-loop-docs-research.md) identified exactly 8 files requiring updates (4 primary + 4 mirrors) and mapped every occurrence line-by-line. The report also confirmed that `.opencode/skills/skill-implementer/SKILL.md` does not contain literal old-style example paths, but the task description explicitly requests a verification pass through that file.

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No direct ROADMAP.md items are advanced by this task. This is a meta-level documentation consistency task that supports the broader Agent System Quality initiative.

## Goals & Non-Goals

**Goals**:
- Replace all `phase-{P}-handoff-{TIMESTAMP}.md` example paths with `MM_HH_{handoff-slug}.md` in pattern documents
- Update the `handoff-artifact.md` format specification to document the new naming convention components (MM, HH, slug)
- Update `general-implementation-agent.md` Stage 4C handoff filename construction to reference the new variables
- Sync all primary file changes to `.opencode/extensions/core/` mirrors
- Verify `skill-implementer/SKILL.md` contains no stale example paths
- Confirm zero remaining occurrences of the old naming convention across `.opencode/skills/`, `.opencode/agent/`, `.opencode/context/patterns/`, and mirrors

**Non-Goals**:
- Changing the actual handoff filename generation logic in running code (Task 527 scope)
- Updating progress file naming (`phase-{P}-progress.json` is unchanged)
- Adding new features or changing handoff artifact schema structure
- Updating files outside the `.opencode/` tree

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Task 527 changes the exact slug generation algorithm after this task completes, causing mismatches | Medium | Low | Document dependency on Task 527 in plan; if 527 changes, re-run grep verification |
| Mirror files have intentional differences (e.g., handoff-artifact.md missing lines 51-52 and 167-168) that get overwritten | Low | Medium | Read each mirror before syncing; preserve known intentional differences |
| Stale references in unexpected files (e.g., other skills referencing old pattern) | Medium | Low | Broad grep search across `.opencode/` during verification phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Primary Pattern Documents [COMPLETED]

**Goal**: Update the two pattern documents that contain example `handoff_path` values.

**Tasks**:
- [x] **Task 1.1**: Update `.opencode/context/patterns/subagent-continuation-loop.md` line 95: replace `"handoff_path": "specs/495_.../handoffs/phase-2-handoff-20260504T120000Z.md"` with `"handoff_path": "specs/495_.../handoffs/02_01_implement-core-module.md"` *(completed)*
- [x] **Task 1.2**: Update `.opencode/context/patterns/context-exhaustion-detection.md` line 137: replace `"handoff_path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"` with `"handoff_path": "specs/259_configure_feature/handoffs/02_01_implement-date-validator.md"` *(completed)*
- [x] **Task 1.3**: Update `.opencode/context/patterns/context-exhaustion-detection.md` line 144: replace `"path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"` with `"path": "specs/259_configure_feature/handoffs/02_01_implement-date-validator.md"` *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/context/patterns/subagent-continuation-loop.md`
- `.opencode/context/patterns/context-exhaustion-detection.md`

**Verification**:
- Read modified lines to confirm replacements
- grep for `phase-.*-handoff-` in both files returns zero matches

---

### Phase 2: Update Primary Format Spec and Agent Definition [COMPLETED]

**Goal**: Update the format specification and agent definition that document or construct handoff filenames.

**Tasks**:
- [x] **Task 2.1**: Update `.opencode/context/formats/handoff-artifact.md`:
  - Line 12: replace template path with `specs/{NNN}_{SLUG}/handoffs/MM_HH_{handoff-slug}.md`
  - Line 21: replace example with `specs/259_configure_feature/handoffs/02_01_implement-date-validator.md`
  - Lines 32-34: replace three directory examples with `02_01_define-validation-types.md`, `02_02_implement-field-validators.md`, `03_01_integrate-with-handler.md`
  - Line 115: replace artifact path example
  - Line 132: replace `handoff_path` example
  - Update the `Where:` bullet list (lines 15-19) to document MM, HH, and slug components *(completed: already updated by Task 527)*
- [x] **Task 2.2**: Update `.opencode/agent/subagents/general-implementation-agent.md`:
  - Line 196: replace template path with `specs/{NNN}_{SLUG}/handoffs/{MM}_{HH}_{handoff-slug}.md`
  - Line 199: replace bash variable construction to reference `artifact_number`, `handoff_count_padded`, and `handoff_slug`
  - Line 322: replace placeholder handoff_path example
  - Line 329: replace placeholder path example *(completed: already updated by Task 527)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/context/formats/handoff-artifact.md`
- `.opencode/agent/subagents/general-implementation-agent.md`

**Verification**:
- Read modified lines to confirm replacements
- grep for `phase-.*-handoff-` in both files returns zero matches

---

### Phase 3: Sync Changes to Extension Core Mirrors [COMPLETED]

**Goal**: Copy all updated primary files to their `.opencode/extensions/core/` counterparts, preserving intentional differences.

**Tasks**:
- [x] **Task 3.1**: Sync `.opencode/context/formats/handoff-artifact.md` to `.opencode/extensions/core/context/formats/handoff-artifact.md`, preserving the known missing lines (51-52 and 167-168) *(completed: already synced by Task 527, files are identical)*
- [x] **Task 3.2**: Sync `.opencode/context/patterns/subagent-continuation-loop.md` to `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md` *(completed: already synced)*
- [x] **Task 3.3**: Sync `.opencode/context/patterns/context-exhaustion-detection.md` to `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md` *(completed: already synced)*
- [x] **Task 3.4**: Sync `.opencode/agent/subagents/general-implementation-agent.md` to `.opencode/extensions/core/agents/general-implementation-agent.md` *(completed: already synced by Task 527)*

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.opencode/extensions/core/context/formats/handoff-artifact.md`
- `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`
- `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- `.opencode/extensions/core/agents/general-implementation-agent.md`

**Verification**:
- diff primary vs mirror for each file to confirm sync; intentional differences (handoff-artifact.md missing lines) are preserved

---

### Phase 4: Verification and Consistency Check [COMPLETED]

**Goal**: Ensure zero old-style naming convention references remain in any skill, agent, pattern, or mirror file.

**Tasks**:
- [x] **Task 4.1**: Run grep across `.opencode/skills/`, `.opencode/agent/`, `.opencode/context/patterns/`, `.opencode/context/formats/`, and `.opencode/extensions/core/` for `phase-[0-9]+-handoff-[0-9]{8}T` and confirm zero matches *(completed: PASS)*
- [x] **Task 4.2**: Inspect `.opencode/skills/skill-implementer/SKILL.md` for any literal old-style example paths in continuation loop documentation or Stage 7 partial handling; if found, update them *(completed: PASS - no stale paths found)*
- [x] **Task 4.3**: Inspect any other `.opencode/skills/*/SKILL.md` files for stale references (skill-researcher, skill-planner, etc.) *(completed: PASS - no stale references)*
- [x] **Task 4.4**: Inspect `.opencode/context/formats/return-metadata-file.md` and `progress-file.md` for any stale handoff path examples *(completed: PASS - no stale examples)*

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- Potentially `.opencode/skills/skill-implementer/SKILL.md` if stale references are found
- Any other files discovered during verification

**Verification**:
- Final grep for old pattern returns zero matches across all searched directories
- All 8 known files (4 primary + 4 mirrors) contain only the new naming convention

## Testing & Validation

- [ ] grep for `phase-[0-9]+-handoff-` across `.opencode/` returns zero matches
- [ ] grep for `phase-P-handoff-TIMESTAMP` returns zero matches
- [ ] diff confirms primary files and mirrors are in sync (except known intentional differences)
- [ ] All example paths in updated files use the `MM_HH_{handoff-slug}.md` format
- [ ] `handoff-artifact.md` `Where:` section documents MM, HH, and slug components

## Artifacts & Outputs

- Updated `.opencode/context/patterns/subagent-continuation-loop.md`
- Updated `.opencode/context/patterns/context-exhaustion-detection.md`
- Updated `.opencode/context/formats/handoff-artifact.md`
- Updated `.opencode/agent/subagents/general-implementation-agent.md`
- Synced `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`
- Synced `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- Synced `.opencode/extensions/core/context/formats/handoff-artifact.md`
- Synced `.opencode/extensions/core/agents/general-implementation-agent.md`
- `specs/528_update_continuation_loop_docs/plans/01_update-continuation-loop-docs.md` (this plan)

## Rollback/Contingency

If any update introduces incorrect paths or breaks formatting, revert individual files using git checkout:
```bash
git checkout -- .opencode/context/patterns/subagent-continuation-loop.md
# (repeat for each affected file)
```
If the new convention changes after Task 527 completes, re-run Phases 1-4 with the updated convention.
