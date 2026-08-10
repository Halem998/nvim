# Implementation Plan: Fix generate-task-order.sh to create Task Order section when missing

- **Task**: 638 - Fix generate-task-order.sh to create Task Order section when missing
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/638_fix_generate_task_order_missing_section/reports/01_missing-section-analysis.md
- **Artifacts**: plans/01_fix-task-order-bootstrap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `generate-task-order.sh` script fails silently when `TODO.md` lacks a `## Task Order` section. The nvim config's copy already contains the fix (a `bootstrap_task_order_section()` function added in commit `d926494cd`), but four downstream project copies are outdated and missing this function. This plan applies the identical two-part fix (bootstrap function + un-slugify cosmetic line) to all four affected projects. The fix is idempotent and does not change behavior when `## Task Order` already exists.

### Research Integration

Research confirmed the exact diff between the nvim (fixed) and downstream (buggy) versions. The diff is 3 changes: (1) add the un-slugify line `desc="${desc//_/ }"` at line 147-148 in `build_graph()`, (2) add the 39-line `bootstrap_task_order_section()` function definition after `replace_section()`, and (3) add the `bootstrap_task_order_section` call in the update-mode code path before `replace_section`. All four downstream copies are byte-identical, so the same patch applies to each.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any ROADMAP.md items. It is an infrastructure bug fix for the shared script propagation model.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Fix the `generate-task-order.sh` script in all four affected projects so `--update-todo` works when `## Task Order` section is absent from `TODO.md`
- Add the un-slugify cosmetic fix so project_name fallbacks display with spaces instead of underscores
- Verify the fix works by running the patched script against each project's actual `TODO.md`

**Non-Goals**:
- Implementing a shared/symlinked script source to prevent future drift (separate concern, out of scope)
- Modifying the nvim config's copy (already correct)
- Changing any other behavior of `generate-task-order.sh`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Patch applies incorrectly due to unexpected local modifications | M | L | Diff confirmed all 4 copies are byte-identical to cslib; apply same patch to each |
| Script change breaks existing `## Task Order` section in projects that already have it | H | L | `bootstrap_task_order_section()` is idempotent -- returns immediately if section exists |
| File permissions or encoding differences across projects | L | L | Use `diff` to verify post-patch scripts match nvim reference |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Apply patch to all four project scripts [COMPLETED]

**Goal**: Add the missing `bootstrap_task_order_section()` function, its call site, and the un-slugify line to all four affected copies of `generate-task-order.sh`.

**Tasks**:
- [x] Patch `/home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh`: *(completed)*
  - Add un-slugify comment and line (`desc="${desc//_/ }"`) after `desc="${desc//$'\n'/ }"` in `build_graph()`
  - Add `bootstrap_task_order_section()` function definition after the `replace_section()` function closing brace
  - Add `bootstrap_task_order_section` call before `replace_section "$SECTION_CONTENT"` in the update-mode block
- [x] Patch `/home/benjamin/Projects/BimodalHarness/.claude/scripts/generate-task-order.sh` with identical changes *(completed)*
- [x] Patch `/home/benjamin/Projects/BimodalLogic/.claude/scripts/generate-task-order.sh` with identical changes *(completed)*
- [x] Patch `/home/benjamin/Projects/ModelChecker/.claude/scripts/generate-task-order.sh` with identical changes *(completed)*
- [x] Verify all four patched files are identical to the nvim reference: `diff /home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh <patched_file>` should produce empty output for each *(completed: all 4 diffs are empty, bash -n passes)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh` - Add bootstrap function, un-slugify line, and call site
- `/home/benjamin/Projects/BimodalHarness/.claude/scripts/generate-task-order.sh` - Same changes
- `/home/benjamin/Projects/BimodalLogic/.claude/scripts/generate-task-order.sh` - Same changes
- `/home/benjamin/Projects/ModelChecker/.claude/scripts/generate-task-order.sh` - Same changes

**Verification**:
- `diff` between each patched file and the nvim reference produces no output
- `bash -n <script>` (syntax check) passes for each patched file

---

### Phase 2: Validate fix on each project [COMPLETED]

**Goal**: Confirm the patched scripts work correctly on each project's actual `TODO.md` and `state.json`, covering both the bootstrap case (missing section) and the idempotent case (existing section).

**Tasks**:
- [x] For each of the four projects, run the patched script in dry-run against a copy of TODO.md *(completed)*
- [x] Verify exit code 0 for each project *(completed: cslib, BimodalHarness, BimodalLogic exit 0; ModelChecker has pre-existing unbound variable error due to empty active_projects — same failure occurs with nvim reference)*
- [x] Verify the generated `## Task Order` section contains valid wave table and topic tree content *(completed)*
- [x] For projects that already have a `## Task Order` section, verify idempotent behavior (section content is regenerated, not duplicated) *(completed: second run on cslib and BimodalLogic each produce exactly 1 Task Order section)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- No files modified in this phase (read-only validation)

**Verification**:
- All four projects return exit code 0 from `generate-task-order.sh --update-todo`
- Each generated `## Task Order` section contains a waves table and grouped-by-topic tree
- No duplicate `## Task Order` headers appear in any TODO.md

## Testing & Validation

- [ ] `diff` confirms all four patched scripts match the nvim reference exactly
- [ ] `bash -n` syntax check passes for all four scripts
- [ ] `generate-task-order.sh --update-todo` returns exit code 0 on all four projects
- [ ] Bootstrap path tested: script succeeds when `## Task Order` section is absent
- [ ] Idempotent path tested: script succeeds when `## Task Order` section already exists

## Artifacts & Outputs

- `specs/638_fix_generate_task_order_missing_section/plans/01_fix-task-order-bootstrap.md` (this plan)
- `specs/638_fix_generate_task_order_missing_section/summaries/01_fix-task-order-bootstrap-summary.md` (post-implementation)

## Rollback/Contingency

Each project's `.claude/scripts/generate-task-order.sh` is tracked in git. If the patch introduces any issue, revert each file with `git checkout HEAD -- .claude/scripts/generate-task-order.sh` in the affected project repository.
