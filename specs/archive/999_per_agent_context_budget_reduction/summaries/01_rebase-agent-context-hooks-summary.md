# Implementation Summary: Task #999

- **Task**: 999 - Reduce the 8 per-agent context budget overruns
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T00:00:00Z
- **Completed**: 2026-08-10T03:55:00Z
- **Effort**: ~4 hours
- **Dependencies**: None (all prerequisite tasks completed)
- **Artifacts**: plans/01_rebase-agent-context-hooks.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Rebased `load_when.agents` hooks across four `index-entries.json` source files (core, nvim, nix,
memory) onto each of the eight overrunning agents' real, unconditional `@`-reference sets,
reclassifying orphaned and conditionally-gated content to `on_demand: true` or
`task_types`-only. Five agents (meta-builder-agent, planner-agent, general-research-agent,
neovim-research-agent, nix-research-agent) now clear their caps outright with positive margin.
The remaining three implementation agents (general-implementation-agent,
neovim-implementation-agent, nix-implementation-agent) hit a genuine structural floor — a shared
9,248-token "always-loaded" core bundle that alone exceeds the 8,000-token cap — and now carry
accurately measured, non-stale documented exceptions in `validate-context-budgets.sh`.
`bash .claude/scripts/validate-context-budgets.sh` reports `Violations: 0`, exits 0, with exactly
three `OK*` rows. No `CAPS` value was raised.

## What Changed

- `agent-system/extensions/core/index-entries.json` — rebased `agents[]` hooks for
  `meta-builder-agent` (132,984 -> 14,272 measured, later 13,296 after Phase 4's
  extension-deploy-modes.md drop), `planner-agent` (31,888 -> 10,400), `general-research-agent`
  (28,744 -> 9,992 pre-Phase-6, 7,160 final), `general-implementation-agent` (68,568 -> 16,688);
  added missing unconditional hooks for the shared implementation core bundle to
  `neovim-implementation-agent`/`nix-implementation-agent`; dropped
  `standards/git-staging-scope.md`'s hooks on both (unreferenced by either agent body).
- `agent-system/extensions/nvim/index-entries.json` — rebased hooks for `neovim-research-agent`
  (22,872 -> 7,360 core-file measurement) and `neovim-implementation-agent` (40,104 -> 15,336),
  dropping `meta-builder-agent`'s unreferenced hook on `project/neovim/domain/extension-deploy-modes.md`.
- `agent-system/extensions/nix/index-entries.json` — rebased hooks for `nix-research-agent`
  (20,472 -> 7,192, with deliberate extra margin) and `nix-implementation-agent`
  (23,096 -> 14,104).
- `agent-system/extensions/memory/index-entries.json` — removed the two orphaned
  `general-research-agent` hooks on `project/memory/distill-usage.md` and
  `project/memory/domain/memory-reference.md` (2,832 tok), preserving both entries' `commands`
  hooks intact. This is a justified `file_scope` extension beyond the plan's original three
  files, recorded in `state.json` and confirmed necessary: without it,
  `general-research-agent` measures 9,992 against its 8,000 cap and fails.
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` — replaced the single stale,
  inert `EXCEPTIONS` entry (cap 8,048 against a real total of 68,568, naming a no-longer-referenced
  file) with three accurate entries keyed on Phase 7's measured totals plus a 500-token headroom
  each; generalized the previously-hardcoded summary narration block into a loop over
  `EXCEPTIONS`/`EXCEPTIONS_APPLIED_TOTALS` so the printed composition can never silently drift
  from the array again; added a maintenance note on recomputation triggers.

## Decisions

- **Ghost-entry offset treated as a known constant, not chased.** The deployed
  `.claude/context/index.json` carries two entries with no source-store owner
  (`orchestration/orchestration-validation.md`, 1,864 tok, hooked to `meta-builder-agent`;
  `orchestration/subagent-validation.md`, 2,504 tok, unhooked), confirmed by full set-difference
  in Phase 1 rather than a spot check. `meta-builder-agent`'s measured total is always
  source-sum + 1,864; every other agent's measured total equals its source sum exactly. This was
  reconciled explicitly in Phase 7 rather than causing thrash.
- **A small set of genuinely-referenced-but-rare-path entries were reclassified off `agents[]`
  despite being real `@`-references**, following the research report's Finding 4 methodology
  (Tier 2 = "loaded whenever this agent is dispatched", not "mentioned anywhere in the body"):
  `patterns/checkpoint-before-overflow.md` off `general-research-agent`; `project/neovim/README.md`
  and `project/neovim/domain/plugin-ecosystem.md` off `neovim-research-agent`;
  `project/nix/README.md` off `nix-research-agent` (deliberately, for margin, per the plan's
  explicit instruction). These were the numerically necessary corrections that let those agents
  clear their caps; `general-implementation-agent`'s equivalent rare-path references
  (`checkpoint-before-overflow.md`, `context-exhaustion-detection.md`,
  `subagent-continuation-loop.md`) were left hooked since that agent receives an exception
  regardless and dropping them was not required by the plan's explicit task list.
- **Exception cap = measured total + 500-token flat headroom**, applied uniformly to all three
  exception agents, so ordinary future content drift (a few added lines to a hooked file) does
  not immediately re-break the gate the way the prior single exception went stale and inert.

## Plan Deviations

- None (implementation followed plan). The one explicit "narrow, justified `file_scope`
  extension" into the memory extension (Phase 6) was pre-authorized in the delegation context and
  already reflected in `state.json` before implementation began.

## Verification

- Build: N/A (no build system for this deliverable)
- Tests: `test-index-entries-schema.sh` 8/9 passed (1 pre-existing, unrelated failure confirmed
  via `git stash` baseline comparison); `validate-context-index.sh` PASSED (190 entries, 0
  errors); `validate-index.sh` PASSED (no missing files, no duplicates)
- Files verified: Yes — `bash -n` on the modified script passes; all four edited JSON files
  parse and validate against `index.schema.json`
- Final gate: `bash .claude/scripts/validate-context-budgets.sh` -> `Violations: 0`, exit 0,
  exactly three `OK*` rows (`general-implementation-agent` 16,688/17,188,
  `neovim-implementation-agent` 15,336/15,836, `nix-implementation-agent` 14,104/14,604)
- `generate-context-line-counts.sh --check`: 479/479 exact, no drift
- `check-task-references.sh`: PASS, 0 occurrences
- `check-extension-docs.sh`: PASS, all 18 extensions OK

## Impacts

- Five agents (`meta-builder-agent`, `planner-agent`, `general-research-agent`,
  `neovim-research-agent`, `nix-research-agent`) now dispatch with materially smaller resolved
  context: `meta-builder-agent` alone drops from ~133,000 to ~13,300 tokens of hooked content,
  a ~90% reduction, while retaining every genuinely-referenced file.
- The `validate-context-budgets.sh` budget check becomes a live, meaningful instrument again
  rather than one whose failure was permanently expected — a future regression will be caught
  rather than lost in a sea of pre-existing violations.
- The Double-Loading Check's dual-hook population shrank from 14 to 6 entries as a side effect
  of dropping over-broad `agents[]` hooks that had coincidentally also carried a `commands[]`
  hook; the redundant count stayed at 0 throughout.
- No runtime behavior changed for the three exception agents (`agents[]` hooks are inert catalog
  metadata for `neovim-implementation-agent`/`nix-implementation-agent`, and the accurate
  exception now reflects `general-implementation-agent`'s real composition) — the improvement is
  entirely in metric accuracy and the removal of a permanently-failing, un-actionable check state.

## Follow-ups

- Shrink `formats/return-metadata-file.md` (596 lines / 4,768 tokens, 59% of the 8,000-token cap
  and referenced by 7 of the original 8 overrun agents) — this is the structural unblocker that
  would let the three exception agents pass without an exception at all.
- Fold the content-duplication candidates `patterns/metadata-file-return.md` and
  `patterns/early-metadata-pattern.md` into `formats/return-metadata-file.md`.
- Extend the Double-Loading Check to catch reverse-direction redundancy (an `agents[]` hook fully
  subsumed by `commands[]` routing), which `standards/status-markers.md` exhibits today and the
  check currently misses.
- Fix the additive-merge ghost-entry defect in `install-extension.sh`'s `merge_index_entries` and
  remove the two stranded deployed files (`orchestration/orchestration-validation.md`,
  `orchestration/subagent-validation.md`) that currently have no source-store owner.

## References

- Plan: `specs/999_per_agent_context_budget_reduction/plans/01_rebase-agent-context-hooks.md`
- Research report: `specs/999_per_agent_context_budget_reduction/reports/01_reduce-agent-budget-overruns.md`
- Progress files: `specs/999_per_agent_context_budget_reduction/progress/phase-{1..9}-progress.json`
