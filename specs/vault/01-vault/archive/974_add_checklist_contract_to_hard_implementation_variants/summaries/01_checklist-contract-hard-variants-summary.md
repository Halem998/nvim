# Implementation Summary: Task #974

- **Task**: 974 - Add plan-checklist mark-completed contract to the two hard-mode implementation agent variants
- **Status**: [COMPLETED]
- **Started**: 2026-07-30T02:00:00Z
- **Completed**: 2026-07-30T02:25:50Z
- **Effort**: 1.0 hours
- **Dependencies**: None (task 971, referenced by the plan, is COMPLETED)
- **Artifacts**: plans/01_checklist-contract-hard-variants.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Replaced the bare one-line placeholder bullet (`- For each completed checklist item: check off in
plan file`) in both hard-mode implementation agent variants with the full canonical
`Check Off Completed Items in Plan File` contract, quoted byte-for-byte verbatim from
`general-implementation-agent.md`'s `#### 4B-ii.` section. Each insertion uses the bold-label
`**B-ii.**` sub-section convention matching each file's existing lettered-step structure, sited
immediately before the file's own `**C. Verify Phase Completion**` step.

## What Changed

- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — deleted the
  placeholder bullet from the `**B. Execute Steps**` list; inserted `**B-ii. Check Off Completed
  Items in Plan File**` with the canonical block body verbatim, immediately before
  `**C. Verify Phase Completion**`.
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` — deleted the same
  placeholder bullet, keeping the two Lean-specific bullets (`lean_goal`, `lean_multi_attempt`) in
  place and in order; inserted the same `**B-ii.**` sub-section verbatim, immediately before
  `**C. Verify Phase Completion** - Run CSLib CI pipeline steps...`.

## Decisions

- Used a bold-label `**B-ii.**` sub-section (matching each hard file's existing `**A.**`/`**B.**`/
  `**C.**`/`**D.**` convention) rather than a `####` heading (the base agent's convention), per the
  plan's analysis that the two hard files render lettered steps as bold labels, not headings.
- Preserved each file's existing em-dash convention; the canonical block's own em-dashes pasted in
  unchanged (no ASCII `--` conversion needed or performed, in either direction).

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (markdown-only change)
- Tests: N/A
- Files verified: Yes — both insertions confirmed byte-identical to the canonical source via
  `diff` (empty diffs); `git diff --stat` shows exactly the two declared source-store paths
  changed with 37 and 39 insertions plus 1 deletion each, a single contiguous hunk per file;
  `bash .claude/scripts/check-task-references.sh` reports `PASS: 0 unexempted task-reference
  occurrences`; em-dash counts rose from 18->22 (core) and 4->8 (cslib), exactly the canonical
  block's 4 em-dashes per file; `sorry_inventory` (10), `orchestrator-handoff.json` (4), and the
  two Lean-specific bullets in the cslib file are all unchanged from baseline; neither file's
  Stage 5 region appears in the diff.

## Impacts

- Both hard-mode implementation agents now carry an explicit, unambiguous checklist-matching
  contract instead of an implicit inheritance (core) or a bug-propagating bare instruction
  (cslib), matching the fix already applied to the base `general-implementation-agent.md`.
- No behavioral change to H9 wrap-up, `sorry_inventory`, territory contracts, Stage 5a marker
  repair, or `.orchestrator-handoff.json` handling in either file.

## Follow-ups

- Recommended (not created by this task, no existing task covers it): apply the same canonical
  loosened checklist-matching wording to `web-implementation-agent.md` and
  `neovim-implementation-agent.md`, which still carry the brittle `**Task {P}.{N}**:` prefix idiom
  in their deviation-annotation and summary-template lines.
- `cslib-implementation-agent.md` (the non-hard cslib sibling) also carries the brittle prefix but
  is already tracked as a separate, named downstream task — no action needed here.

## References

- Plan: specs/974_add_checklist_contract_to_hard_implementation_variants/plans/01_checklist-contract-hard-variants.md
- Research report: specs/974_add_checklist_contract_to_hard_implementation_variants/reports/01_checklist-contract-hard-variants.md
- Canonical source section: `agent-system/extensions/core/agents/general-implementation-agent.md` `#### 4B-ii. Check Off Completed Items in Plan File`
