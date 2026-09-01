# Implementation Summary: Task #124

- **Task**: 124 - Delete /research, /plan, /implement commands and update the CLAUDE.md command reference
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T23:29:10Z
- **Completed**: 2026-09-02T00:20:00Z
- **Effort**: ~1 hour
- **Dependencies**: Task 117, Task 68, Task 81, Task 126 (all [COMPLETED])
- **Artifacts**: plans/01_lifecycle-command-deletion.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Deleted `commands/research.md` (615 lines), `commands/plan.md` (645 lines), and
`commands/implement.md` (506 lines) from the core extension source store, de-registered them
from `manifest.json` in the same atomic commit, and reconciled every reference the deletion
would otherwise leave dangling in the two files this task owned end-to-end:
`merge-sources/claudemd.md` and `index-entries.json`. Retired the three now-vacuous static test
guards, pruned the stale deployed command copies, and produced a triaged inventory of the wider
out-of-scope reference surface. All 7 phases completed; every verification criterion passed or
was confirmed byte-identical to the Phase 1 baseline.

## What Changed

- `agent-system/extensions/core/commands/research.md` — deleted (615 lines)
- `agent-system/extensions/core/commands/plan.md` — deleted (645 lines)
- `agent-system/extensions/core/commands/implement.md` — deleted (506 lines)
- `agent-system/extensions/core/manifest.json` — three `provides.commands` entries removed
  (research.md, plan.md, implement.md); `revise.md` and `orchestrate.md` unaffected
- `agent-system/extensions/core/merge-sources/claudemd.md` — three Command Reference table rows
  removed; `/orchestrate` row amended to state all six load-bearing semantic points word-for-word
  (composability, canonical ordering, stop-after-last, new artifact round, no status regression,
  single-task-only); six prose sites reconciled (Multi-task syntax, Model Enforcement, Team Mode,
  Routing Mechanism, `--hard` Per-Invocation Only, Error Handling)
- `agent-system/extensions/core/index-entries.json` — six `load_when.commands` arrays retargeted:
  three dead command names pruned from each; `/orchestrate` added to the four entries
  (`patterns/multi-task-operations.md`, `standards/status-markers.md`,
  `standards/git-workflow-narrative.md`, `standards/error-recovery-strategies.md`) that would
  otherwise have emptied or lost their lifecycle-phase trigger; the other two
  (`patterns/task-lock.md`, `standards/git-staging-scope.md`) were prune-only
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — cases 9.6, 9.7, 9.8 (static
  guards over the deleted files) removed in full, no renumbering; suite now 33 passed/0 failed
  (baseline 36 minus exactly 3)
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — stale comment retargeted to
  the surviving caller (`skill-orchestrate/SKILL.md`'s Stage MT-3 step 4.5)
- `agent-system/extensions/core/scripts/update-task-status.sh` — stale comment retargeted to the
  surviving anchor (`skill-orchestrate/SKILL.md`'s Stage MT-3 step 7 inter-cycle redeploy
  checkpoint)
- `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md` —
  removed (deploy artifacts, gitignored, not tracked changes); `.claude/` redeployed via
  non-destructive `deploy-headless.sh`

## Decisions

- Strengthened the `/orchestrate` Command Reference row beyond the plan's minimum ask (add
  single-task-only) to state all six load-bearing semantic points explicitly, per Phase 2's own
  verification criterion demanding word-for-word coverage.
- The `--lit` "Per-Invocation Only" sentence named in the plan's Phase 2 task list lives in the
  literature extension's own merge-source file, not core's `claudemd.md`; left untouched as it is
  outside this task's declared file scope (Phase 2's Files-to-modify names only the core file,
  and the Scope Hypothesis grep was scoped to the core file only).
- Retargeted comments in `test-four-tier-conflict.sh` and `update-task-status.sh` describe the
  deleted files generically rather than spelling out their literal paths, since the plan's own
  verification demands zero grep hits for those literal path strings under `scripts/`.
- Confirmed a structural limitation, not a task defect: Rule K (`check-extension-docs.sh`'s
  deployed-command-orphan detection) can never fire for anything under `.claude/`, because
  `.claude/` is entirely gitignored (`.gitignore` line 6: `/.claude/`) and Rule K's
  `_git_deployed_files()` helper enumerates via `git ls-files`, which returns nothing for a
  gitignored path — verified directly. The plan's Risk table and Phase 4/6 verification text both
  expected a Rule K failure to appear and then clear; that expectation never held, and no Rule K
  failure appeared at either phase. The deployed tree is nonetheless free of orphaned command
  files, confirmed by direct `ls` inspection (the plan's own primary verification mechanism).

## Plan Deviations

- None (see Decisions above for scope clarifications and a corrected verification-mechanism
  expectation, neither of which changed the plan's actual required work).

## Verification

- Build: N/A (documentation/config task)
- Tests: `test-conflict-predicate.sh` 33/33 passed; `test-four-tier-conflict.sh` 13/13 passed
- Files verified: Yes — all deletions, edits, and retargets confirmed via direct inspection and
  the plan's own per-phase verification criteria
- `check-extension-docs.sh`: byte-identical to the Phase 1 baseline (3 pre-existing, unrelated
  FAILs — missing script registrations for `test-state-write-large-payload.sh`,
  `tests/test-force-phases.sh`, `tests/test-roadmap-argv-ceiling.sh` — zero new failures)
- `check-task-references.sh` (deployed): PASS, 0 unexempted occurrences across 4 trees
- `validate-context-index.sh` (deployed): 215 entries, 0 errors, 0 warnings, PASSED
- `jq .` parses `manifest.json` and `index-entries.json` cleanly
- Deployed `CLAUDE.md` and `.claude/context/index.json` confirmed to carry the Phase 2/3 edits
- Manual smoke: `/orchestrate` resolves in both source and deployed trees; its Options table
  documents all three phase-forcing flags with full semantics

## Impacts

- The command surface shrinks by 1,766 lines; `/orchestrate NNN --research/--plan/--implement`
  is now the sole documented replacement spelling for the deleted commands' phase-forcing
  behavior.
- Three context files (`patterns/multi-task-operations.md`, `standards/git-workflow-narrative.md`,
  `standards/error-recovery-strategies.md`) that would otherwise have become permanently
  unreachable now load via `/orchestrate` instead.
- This lands the precondition Task 125 (deleting the three lifecycle skills) needs before it can
  proceed.

## Follow-ups

**Recommended as a single scoped follow-up task** (not created by this plan, per its own
Non-Goals):

Sweep and update the wider out-of-scope reference surface uncovered by Phase 7's audit. The
Phase 1 baseline inventory was 76 files under `agent-system/extensions/core/` naming `/research`,
`/plan`, or `/implement` as literal command names; post-deletion this is 73 files (2 dropped out
because the files themselves were deleted; 1 — `merge-sources/claudemd.md` — was already cleaned
by this task's Phase 2). Triage:

- **Operational (12 files, highest priority)** — text that instructs an agent or user to invoke a
  now-dead command as a step: `commands/task.md`, `commands/project-overview.md`,
  `commands/merge.md`, `docs/guides/user-guide.md` (troubleshooting steps), `docs/examples/fix-it-flow-example.md`,
  `agents/meta-builder-agent.md` (5 sites), `skills/skill-fix-it/SKILL.md`,
  `context/meta/meta-guide.md` (2 sites), `skills/skill-project-overview/SKILL.md` (5 sites),
  `skills/skill-meta/SKILL.md`, `docs/architecture/orchestrate-state-machine.md`, and
  **`skills/skill-orchestrate/SKILL.md` line 2708** — the single most urgent finding: this is a
  *live, non-deprecated skill file* whose blocker-escalation message still suggests
  `(1) /research $task_number, (2) /revise $task_number, (3) /implement $task_number` as
  manual-intervention steps, two of which are now nonexistent commands.
- **Descriptive (~58 files)** — prose describing the historical three-command lifecycle without
  instructing invocation. Lower priority; wrong but not actionable-wrong.
- **Legitimate (1 file)** — `context/standards/task-reference-exemptions.md:55`, a self-referential
  documentation example, not an instruction.
- **Wholesale-orphaned files** (content entirely or predominantly about the deleted commands, all
  named at plan time and confirmed still present): `docs/examples/research-flow-example.md`,
  `context/processes/research-workflow.md`, `context/processes/planning-workflow.md`,
  `context/processes/implementation-workflow.md`, `context/patterns/multi-task-operations.md`.
  The three `context/processes/*-workflow.md` files were already `on_demand: true` with an empty
  `load_when.commands` array before this task (pre-existing, unrelated condition) — they are
  content-orphaned, not newly reachability-orphaned.

## References

- Plan: `specs/124_delete_lifecycle_commands_and_update_reference/plans/01_lifecycle-command-deletion.md`
- Research report: `specs/124_delete_lifecycle_commands_and_update_reference/reports/01_lifecycle-command-deletion-preconditions.md`
- Progress files: `specs/124_delete_lifecycle_commands_and_update_reference/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/124_delete_lifecycle_commands_and_update_reference/handoffs/phase-{1..6}-handoff-*.md`
