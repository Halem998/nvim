# Implementation Plan: Update extension trigger wording to mechanism-agnostic

- **Task**: 411 - Update extension trigger wording to mechanism-agnostic
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_update-trigger-wording.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Replace the Neovim-specific trigger condition `Extension is loaded via \`<leader>ac\`` with mechanism-agnostic wording in 5 extension skill files across the epidemiology and present extensions. This is a straightforward text replacement that makes skills portable across different extension loading methods (keybinding, pre-merged, CLI flag, etc.).

### Research Integration

No research was conducted. The task description provides exact file paths, line numbers, and replacement text.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace all 5 instances of Neovim-specific `<leader>ac` trigger wording with mechanism-agnostic alternatives
- Epidemiology extension skills use "Epidemiology extension is available"
- Present extension skills use "Present extension is available"

**Non-Goals**:
- Changing any other skill content beyond the trigger condition line
- Updating skills in other extensions (only these 5 files are affected)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Exact text differs from expected | L | L | Read each file before editing to confirm exact text |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Replace trigger wording in all 5 skill files [COMPLETED]

**Goal**: Update all trigger condition lines from Neovim-specific to mechanism-agnostic wording.

**Tasks**:
- [ ] Edit `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` line 34
  - Old: `- Extension is loaded via \`<leader>ac\``
  - New: `- Epidemiology extension is available`
- [ ] Edit `.claude/extensions/epidemiology/skills/skill-epi-research/SKILL.md` line 33
  - Old: `- Extension is loaded via \`<leader>ac\``
  - New: `- Epidemiology extension is available`
- [ ] Edit `.claude/extensions/present/skills/skill-funds/SKILL.md` line 36
  - Old: `- Extension is loaded via \`<leader>ac\``
  - New: `- Present extension is available`
- [ ] Edit `.claude/extensions/present/skills/skill-grant/SKILL.md` line 34
  - Old: `- Extension is loaded via \`<leader>ac\``
  - New: `- Present extension is available`
- [ ] Edit `.claude/extensions/present/skills/skill-timeline/SKILL.md` line 35
  - Old: `- Extension is loaded via \`<leader>ac\``
  - New: `- Present extension is available`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` - Replace trigger condition
- `.claude/extensions/epidemiology/skills/skill-epi-research/SKILL.md` - Replace trigger condition
- `.claude/extensions/present/skills/skill-funds/SKILL.md` - Replace trigger condition
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Replace trigger condition
- `.claude/extensions/present/skills/skill-timeline/SKILL.md` - Replace trigger condition

**Verification**:
- Grep all 5 files for `<leader>ac` -- should return zero matches
- Grep epidemiology skills for "Epidemiology extension is available" -- should return 2 matches
- Grep present skills for "Present extension is available" -- should return 3 matches

## Testing & Validation

- [ ] No remaining `<leader>ac` references in the 5 modified skill files
- [ ] Each file retains its other trigger conditions unchanged
- [ ] Epidemiology skills say "Epidemiology extension is available"
- [ ] Present skills say "Present extension is available"

## Artifacts & Outputs

- `specs/411_update_extension_trigger_wording/plans/01_update-trigger-wording.md` (this plan)
- `specs/411_update_extension_trigger_wording/summaries/01_update-trigger-wording-summary.md` (after implementation)

## Rollback/Contingency

Revert via `git checkout HEAD -- <file>` for any of the 5 files. Changes are isolated single-line text replacements with no behavioral dependencies.
