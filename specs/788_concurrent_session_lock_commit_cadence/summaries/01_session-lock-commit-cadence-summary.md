# Implementation Summary: Task #788

**Completed**: 2026-07-04
**Duration**: ~1.5 hours

## Overview

Implemented all 5 phases of the concurrent-session-lock plan: an atomic, `mkdir`-based per-task
lock (`task-lock.sh` + `task-lock.md` canonical spec), wired into the single-task gate scripts
(`command-gate-in.sh`/`command-gate-out.sh`) and the multi-task/wave dispatch paths
(`skill-orchestrate/SKILL.md` Stage MT, `implement.md` Step 3), plus heartbeat refresh at
existing checkpoints and a reconciled commit-per-green-substep mandate in `git-workflow.md`. All
functional lock tests pass, all 9 dual-copy pairs are `diff -q` clean, and no `git add -A` /
`git commit -am` regression was introduced. git-worktree isolation remains explicitly out of
scope, as specified.

## What Changed

- `.claude/scripts/task-lock.sh` — new atomic lock helper: `acquire`/`heartbeat`/`release`/`check`
  subcommands, `mkdir`-based exclusive create, `TASK_LOCK_STALE_MIN` (default 30 min) tunable,
  two-line `ABORT:` + remedy refusal message, override-and-warn on stale locks. Same-session
  re-entry never self-blocks (checked before staleness).
- `.claude/context/patterns/task-lock.md` — canonical spec doc: lockfile schema, full contract,
  rationale for `mkdir` over the codebase's usual non-atomic `jq -n > file` pattern, consumer
  list, and explicit Non-Goals (file_scope-granular locking, loop-guard atomic gap).
- `.claude/scripts/command-gate-in.sh` — acquires the lock after the terminal-status guard.
- `.claude/scripts/command-gate-out.sh` — unconditionally releases the lock, placed FIRST in the
  script (before the state.json/`.return-meta.json` existence checks) so it always executes even
  when those checks would otherwise `exit 0` early.
- `.claude/skills/skill-orchestrate/SKILL.md` — Stage MT per-task acquire/release around each
  wave-cycle dispatch (deferring, not failing, a task whose lock is held by another session); Stage
  3 per-cycle heartbeat alongside the existing `.orchestrator-loop-guard` refresh.
- `.claude/commands/implement.md` — Step 3 multi-task per-task acquire/release around each skill
  invocation.
- `.claude/agents/general-implementation-agent.md` — Stage 4D phase-transition heartbeat; new
  Stage 4B-iii "Green Sub-Step Commit (Mandatory)" firing a scoped commit whenever a progress-file
  objective reaches `status: "done"` with verification passed.
- `.claude/skills/skill-implementer/SKILL.md` — cross-reference notes explaining why the
  heartbeat and green-commit mechanisms live in `general-implementation-agent.md` rather than
  this thin-wrapper file (see Plan Deviations).
- `.claude/rules/git-workflow.md` — replaced the contradictory "Intermediate states during
  multi-phase operations" Do-Not-Commit bullet with a new "Commit-Per-Green-Substep Mandate"
  section; added a Standard Actions row (`task {N} phase {P}.{O}: {objective_description}`).
- `.claude/context/index.json` — added a discovery entry for `patterns/task-lock.md` (not
  dual-copied; verified no `.claude/extensions/core/context/index.json` exists).
- Dual copies (byte-identical, `diff -q` verified) of all 8 files above under
  `.claude/extensions/core/...`: `scripts/task-lock.sh`, `context/patterns/task-lock.md`,
  `scripts/command-gate-in.sh`, `scripts/command-gate-out.sh`,
  `skills/skill-orchestrate/SKILL.md`, `commands/implement.md`,
  `agents/general-implementation-agent.md`, `skills/skill-implementer/SKILL.md`,
  `rules/git-workflow.md`.

## Decisions

- Used `mkdir` (not `jq -n > file`) as the sole exclusivity primitive, per the plan's explicit
  requirement — the JSON `holder.json` content is still written with the familiar tmp-file-rename
  pattern once the directory is already held.
- Session-identity is checked BEFORE staleness in `acquire`, guaranteeing same-session re-entry
  never self-blocks regardless of lock age — the plan's highest-impact risk.
- `command-gate-out.sh`'s release call was placed at the TOP of the script (not the bottom): the
  script has an early `exit 0` when `.return-meta.json` is missing, which would have silently
  skipped an end-of-script release call, violating the "unconditional release" requirement.
- Multi-task dispatch acquire refusals defer the task to a later cycle rather than marking it
  failed — mirrors the existing wave-split defer-not-fail pattern already used for `file_scope`
  overlap in `skill-orchestrate/SKILL.md` Stage MT-3.

## Plan Deviations

- **Task 2.2** (altered): the release call in `command-gate-out.sh` was moved to the top of the
  script rather than appended after the existing logic, because the meta-file-missing branch's
  early `exit 0` would otherwise skip it. Functionally verified via manual gate-in/gate-out
  round-trip.
- **Task 3.4** (altered): the plan named `skill-implementer/SKILL.md` for the phase-transition
  heartbeat, assuming it contains a per-phase loop with an `update-phase-status.sh` call.
  `skill-implementer/SKILL.md` is actually a thin wrapper that delegates the entire phase loop to
  `general-implementation-agent` in one Agent call; `update-phase-status.sh` is not called
  anywhere in the standard (non-hard) path. Wired the heartbeat into
  `general-implementation-agent.md` Stage 4D instead (the real per-phase-transition site), adding
  that file (+ its core twin) to the touched-file set beyond the plan's original enumeration.
- **Task 4.4** (altered): same root cause as Task 3.4 — the objective-done green-commit action was
  wired into a new `general-implementation-agent.md` Stage 4B-iii rather than
  `skill-implementer/SKILL.md`, with a composability note added to the latter's Stage 6b.
- **Finding, not a deviation, recorded as a 3rd Follow-Up Task**: `research.md`, `plan.md`, and
  `revise.md` do not `source` `command-gate-in.sh`/`command-gate-out.sh` at all — each has its own
  fully inline, duplicated CHECKPOINT 1/2 implementation. Only `implement.md` and `orchestrate.md`
  (single-task) actually source the shared gate scripts. Phase 2's wiring therefore protects
  `/implement` and `/orchestrate` but not yet `/research`/`/plan`/`/revise`. Deliberately left
  unfixed here (not in Phase 2's enumerated files, not in the ~7-pair dual-copy inventory, not
  risk-assessed by this plan) and recorded as a new Follow-Up Task for the orchestrator to spawn.

## Verification

- Build: N/A (meta task, no build step)
- Tests: Passed — all 5 functional lock-test cases (fresh acquire, different-session refusal,
  same-session re-acquire, stale-threshold override, idempotent release) plus a simulated
  single-task gate-in/gate-out round-trip against task 788's own real state.json entry (no
  contamination of task 788's own status/`.return-meta.json` from the test).
- Files verified: Yes — all 9 dual-copy pairs `diff -q` clean; `bash -n` syntax-checked on
  `task-lock.sh`, `command-gate-in.sh`, `command-gate-out.sh`.
- Regression grep: clean — no new `git add -A` / `git commit -am` usage; only pre-existing
  prohibition-context references remain in `git-workflow.md`.
- Inline-lock-logic grep: clean — no `mkdir .lock` reimplementation exists outside `task-lock.sh`.

## Notes

- git-worktree isolation remains explicitly out of scope (Non-Goal), per the user-selected scope.
- Two follow-up tasks from the original plan, plus one discovered during implementation, are
  recorded in the plan's Follow-Up Tasks section for the orchestrator to spawn as separate tasks:
  (1) `file_scope`-granular cross-task locking, (2) atomic-creation guard for
  `.orchestrator-loop-guard`, (3) wiring the task lock into `research.md`/`plan.md`/`revise.md`'s
  own inline CHECKPOINT sections (since they bypass the shared gate scripts entirely).
