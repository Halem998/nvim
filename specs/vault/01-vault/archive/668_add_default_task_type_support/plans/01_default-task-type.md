# Implementation Plan: Add default_task_type support to task creation pipeline

- **Task**: 668 - Add default_task_type support to task creation pipeline
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/668_add_default_task_type_support/reports/01_default-task-type.md
- **Artifacts**: plans/01_default-task-type.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `default_task_type` optional top-level field to state.json that lets projects override the hardcoded keyword table in task.md step 4. When present, `default_task_type` replaces the full keyword table for task type detection, except for meta keywords ("meta", "agent", "command", "skill") which always override to `meta` since those tasks modify `.claude/` itself. This addresses the CSLib problem where proof/logic keywords incorrectly route to `lean4` or `formal` instead of `cslib`.

### Research Integration

Research report `01_default-task-type.md` confirmed:
- Both `commands/task.md` and `extensions/core/commands/task.md` are byte-identical at step 4 and must be updated in sync.
- The jq pattern `jq -r '.default_task_type // empty' specs/state.json` is the correct read approach.
- The state.json schema snippet lives in `extensions/core/merge-sources/claudemd.md` (the merge source for CLAUDE.md), not CLAUDE.md directly.
- Precedence: meta keywords > default_task_type > full keyword table > general fallback.
- The field is additive and backward-compatible (absent or null = no change in behavior).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Allow projects to set a `default_task_type` in state.json that overrides the keyword table
- Preserve meta keyword detection as unconditional (safety guardrail for .claude/ modifications)
- Keep full backward compatibility when `default_task_type` is absent or null
- Update schema documentation to reflect the new field

**Non-Goals**:
- Modifying per-task `--task-type` flag behavior (already works as explicit override)
- Adding UI for setting `default_task_type` (manual state.json edit is sufficient)
- Setting `default_task_type` in any project's state.json (that is a separate follow-up action)
- Validating that `default_task_type` matches a loaded extension (lightweight, trust the user)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension copy drifts from main task.md | H | M | Phase 1 updates both files atomically; diff verification in testing |
| Merge-source edit does not propagate to CLAUDE.md | M | M | Phase 3 updates merge source; regeneration is handled by existing tooling |
| User sets invalid default_task_type | L | L | Routing gracefully falls back; no validation needed for first iteration |
| jq `// empty` returns literal "null" string | M | L | Use `// empty` (not `// ""`); verified in research as correct |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Modify task.md step 4 keyword detection [COMPLETED]

**Goal**: Insert default_task_type lookup and precedence logic into the task creation command, in both the main copy and extension copy.

**Tasks**:
- [ ] In `.claude/commands/task.md`, replace step 4 (lines 111-131) with the new precedence logic:
  - Add jq read of `default_task_type` before keyword matching
  - Check meta keywords first (unconditional override to `meta`)
  - If `default_task_type` is non-empty and no meta keyword matched, use it as `task_type`
  - Otherwise fall through to existing keyword table unchanged
  - Keep the `general` fallback at the end
- [ ] Apply the exact same changes to `.claude/extensions/core/commands/task.md` (lines 111-131)
- [ ] Run `diff` between the two files to confirm they remain byte-identical

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Step 4 replacement (lines 111-131)
- `.claude/extensions/core/commands/task.md` - Same replacement (sync copy)

**Verification**:
- `diff .claude/commands/task.md .claude/extensions/core/commands/task.md` produces no output
- Step 4 contains `jq -r '.default_task_type // empty'` read
- Meta keywords ("meta", "agent", "command", "skill") appear before the default_task_type check
- The full keyword table is preserved inside an "else" branch

---

### Phase 2: Update state-management-schema.md [COMPLETED]

**Goal**: Document the new `default_task_type` field in the canonical schema reference.

**Tasks**:
- [ ] Add `default_task_type` to the "state.json Full Structure" JSON example (top-level, after `next_project_number`)
- [ ] Add a new subsection "Global Configuration Fields" or add a row to an appropriate existing table documenting: field name, type (optional string or null), default (null/absent), description, and semantics
- [ ] Document the precedence rule: meta keywords > default_task_type > keyword table > general

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - Full Structure example and Field Reference section

**Verification**:
- `grep "default_task_type" .claude/context/reference/state-management-schema.md` returns matches
- The JSON example includes the field
- The field reference table includes a row for it

---

### Phase 3: Update CLAUDE.md merge source [COMPLETED]

**Goal**: Add `default_task_type` to the state.json schema snippet in the CLAUDE.md merge source so the generated CLAUDE.md reflects the new field.

**Tasks**:
- [ ] Edit `.claude/extensions/core/merge-sources/claudemd.md` to add `"default_task_type": "optional, overrides keyword table"` (or similar comment) to the state.json Structure JSON snippet
- [ ] Add a brief note below the snippet explaining the field's purpose and precedence

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - state.json Structure section (around lines 116-133)

**Verification**:
- `grep "default_task_type" .claude/extensions/core/merge-sources/claudemd.md` returns matches
- The JSON snippet in the merge source includes the new field

---

## Testing & Validation

- [ ] Both task.md files are byte-identical after changes (`diff` produces no output)
- [ ] Step 4 logic: meta keywords always resolve to `meta` regardless of `default_task_type`
- [ ] Step 4 logic: when `default_task_type` is set and description has no meta keywords, `task_type` equals `default_task_type`
- [ ] Step 4 logic: when `default_task_type` is absent/null, full keyword table runs as before
- [ ] Schema documentation includes the new field with correct type and semantics
- [ ] Merge source snippet includes the new field

## Artifacts & Outputs

- `specs/668_add_default_task_type_support/plans/01_default-task-type.md` (this plan)
- `.claude/commands/task.md` (modified)
- `.claude/extensions/core/commands/task.md` (modified, in sync)
- `.claude/context/reference/state-management-schema.md` (modified)
- `.claude/extensions/core/merge-sources/claudemd.md` (modified)

## Rollback/Contingency

All changes are to markdown instruction files in `.claude/`. Revert via `git checkout` on the four modified files. No runtime code, no database migrations, no external dependencies. The change is purely additive -- removing `default_task_type` from state.json restores original behavior with zero code changes needed.
