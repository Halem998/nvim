# Implementation Summary: Task #908

**Completed**: 2026-07-27
**Duration**: ~1 session (7 phases)

## Overview

Every commit site in the dispatch pipeline staged narrowly but then committed with a bare
`git commit`, which commits the entire shared git index — so a concurrently-dispatched agent's
staged-but-uncommitted work got swept into whichever agent committed next. This implementation
closes the defect in two mechanisms: every commit site now names its pathspec
(`git commit -m "..." -- <paths>`), and the `git add` + `git commit` pair is serialized through a
new `specs/.commit-lock/` mutex (a parameterized sibling of the existing `specs/.scope-lock/`
mutex in `task-lock.sh`). Both mechanisms are shipped as one executable helper,
`agent-system/extensions/core/scripts/git-commit-scoped.sh`, invoked by all eleven commit sites
across seven files, rather than re-deriving the pattern at each site by hand.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — generalized `acquire_scope_mutex`/
  `release_scope_mutex` into `acquire_named_mutex`/`release_named_mutex` (parameterized by mutex
  directory name), added `COMMIT_MUTEX_STALE_SEC=30` and a 15s acquire budget, added
  `commit-acquire`/`commit-release` CLI verbs using a distinct `COMMIT_MUTEX_HELD` reentrancy
  flag. `.scope-lock` behavior is byte-for-byte unchanged.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — new. The single sanctioned
  implementation of scoped, serialized commits: refuses exclude-only pathspec lists (V3),
  validates and drops unmatched positive pathspecs with a loud warning (V2), auto-injects the
  canonical ephemeral-runtime-file exclusion set for any task-directory pathspec, acquires the
  commit mutex with a fail-open warning on timeout, runs the optional honest-index-rows scan
  (moved verbatim from `orchestrator-postflight.sh`'s former Stage 9b), and retries once on an
  `index.lock`-specific commit failure.
- `agent-system/extensions/core/manifest.json` — registered `git-commit-scoped.sh` in
  `provides.scripts`.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added "Commit-Level
  Path Scoping and Cross-Process Serialization" section; added bare `git commit` to Forbidden
  Operations; corrected the "State-Write Serialization" section's now-stale claim that commits
  stay unserialized (Stage 9 is outside the state-write mutex but inside the new commit mutex).
- `agent-system/extensions/core/context/patterns/task-lock.md` — added "Commit-Mutex CLI:
  `commit-acquire` / `commit-release`" section documenting the sibling mutex, the
  `COMMIT_MUTEX_HELD` flag, and why a distinct mutex directory is required (not just call-volume,
  but a `SCOPE_MUTEX_HELD` reentrancy-flag collision).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — converted both commit
  sites (Stage 4B-iii per-objective, Phase Checkpoint Protocol step 5) to the helper.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — converted its one
  commit site (Stage 5 Step 2).
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — converted both sites
  (Stage 6b, Stage 9); Stage 9 additionally gained `--honest-index-rows`.
- `agent-system/extensions/core/skills/skill-planner/SKILL.md` — converted Stage 9.
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` — converted Stage 10
  (per-wave) and Stage 14 (final); both also gained automatic ephemeral-exclusion coverage,
  closing that site's staleness gap.
- `agent-system/extensions/core/commands/orchestrate.md` — converted CHECKPOINT 3 (single-task)
  and Step 5 (multi-task batch); simplified the batch site's caller-side exclude construction
  since the helper now injects it automatically.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — converted Stage 9; updated
  both comment blocks describing the scope-mutex boundary to reflect the new two-mutex
  arrangement (outside the state-write mutex, inside the commit mutex).
- `specs/908_.../reports/02_commit-site-inventory.md` (new) — Phase 1's re-verification of V1-V9
  and the full 11-site inventory.

## Decisions

- **`specs/.commit-lock/` is a distinct mutex directory from `specs/.scope-lock/`**, per the
  plan's Settled Decision 1: the decisive reason is a `SCOPE_MUTEX_HELD` reentrancy-flag
  collision (not merely call-frequency), and reusing `.scope-lock` would invert the documented
  invariant that Stage 9 runs outside the state-write mutex.
- **One shipped helper, not eleven hand-edited snippets**, per Settled Decision 2 — directly
  motivated by Verified Finding V6, where the ephemeral-exclusion set had already drifted out of
  sync at nine of eleven sites after being added to the standard but not systematically applied.
- **Closed named verbs (`commit-acquire`/`commit-release`), not a generic `mutex-acquire <name>`**,
  per Settled Decision 3, to keep the set of mutexes closed and auditable.

## Plan Deviations

- **Commit-site count**: the plan's Phase 1 task description expected "11 sites across 8 files."
  Re-verification confirmed 11 sites but only 7 files (the two `commands/orchestrate.md` sites
  count as one file). Recorded in `reports/02_commit-site-inventory.md` as a minor correction to
  the task description, not a contradiction of any Verified Finding.
- **Pre-existing latent bug fixed as a mechanical side effect**: `skill-planner/SKILL.md` Stage 9
  and `skill-team-implement/SKILL.md` Stages 10/14 had an illustrative bash snippet with a missing
  closing `"` before the message heredoc's closing fence. Converting these sites to invoke the
  helper necessarily produces syntactically valid bash; the broken quoting was not carried
  forward. This is a mechanical consequence of the conversion, not separate scope creep.
- **`commands/orchestrate.md`'s two sites' caller-side `ephemeral_excludes` construction was
  simplified/removed**, since `git-commit-scoped.sh` now injects the same exclusion set
  automatically for any task-directory pathspec — leaving the caller's manual construction in
  place would have been redundant, not wrong, but removing it is a cleaner realization of
  Decision 2's "one executable definition" intent.
- **`skill-implementer/SKILL.md` Stage 9 and `commands/orchestrate.md`'s single-task CHECKPOINT 3
  gained `--honest-index-rows`**, which they did not have before. This was explicitly anticipated
  by the plan's Phase 3 task ("This also makes the addendum available to the other ten sites,
  which lack it today") rather than being an undeclared addition.
- No deviations required deferral: task 885 remained `partial`/lock-free at both the Phase 1 and
  Phase 6 checks, so the `orchestrator-postflight.sh` edit proceeded without deferral.

## Verification

- **Build**: N/A (bash + markdown; `bash -n` passed on `task-lock.sh`,
  `git-commit-scoped.sh`, and `orchestrator-postflight.sh`).
- **Tests**: Passed — see the three-arm concurrency comparison below plus the per-phase
  functional tests recorded in `progress/phase-{2,3}-progress.json`.
- **Files verified**: Yes — `grep` confirms no bare `git commit -m` remains in any code block
  across all eight edited files; `manifest.json` registration confirmed via `jq`;
  `grep -nE '\btask(s)? [0-9]+'` over every edited file outside `specs/**` shows no newly-added
  task-number citations (only pre-existing legacy references in `task-lock.md`).

### Three-Arm Concurrency Comparison (Phase 7)

Disposable scratch repo, session scratchpad, destroyed after the run. Two concurrent committers
on disjoint paths, 30 iterations per arm, deliberately raced with a short randomized sleep
between `git add` and `git commit` to maximize the contention window.

| Arm | Misattribution | Failure rate | Notes |
|---|---|---|---|
| Baseline (bare `git add` + bare `git commit`) | 1/30 | not separately measured | Reproduces the reported defect. Most races in this arm surface as `index.lock` contention (visible in raw output) rather than a clean sweep, since bare commits race on the same lock file as scoped ones — a clean misattribution requires timing where one process's `git add` lands inside the other's commit window without a lock collision. |
| Path-scoping only (`git commit -- <paths>`, no mutex) | 0/30 | 10/30 (~33%) `index.lock` commit failures | Confirms the research's central finding: path-scoping alone eliminates misattribution but converts it into a substantial `index.lock` failure rate. |
| Full fix (`git-commit-scoped.sh`) | 0/30 | 0/30 | Both defects closed simultaneously. |

**Stop-condition check**: the full-fix arm's failure rate (0/30) is materially better than the
path-scoping-only arm's (10/30) — the stop condition (full-fix not materially better) did not
trigger.

**8-concurrent-committer scale run** (matching `MAX_TASKS=8`): all 8 committers completed in
0.48s wall-clock, 0/8 warnings or errors, 8 distinct successful commits — well within the 15s
acquire budget.

**Safety gates under concurrency**: both fired correctly without disrupting a concurrent sibling
commit — the V3 exclude-only refusal (exit 2, no commit attempted) ran alongside a concurrent
commit that succeeded independently; the V2 unmatched-path drop (loud warning, commit proceeds
for the valid path) likewise ran alongside an independent concurrent commit.

**honest-index-rows addendum**: rendered correctly under a concurrent setup —
`Also carries current index rows for tasks: 99` appeared in the commit message as expected.

**Mutex leak check**: `ls -a specs/ | grep -E 'commit-lock|scope-lock'` found neither directory
after any run in this phase.

## Notes

- `skills/skill-orchestrate/SKILL.md` was re-confirmed to contain no `git commit` site (matches
  V7) and was left unmodified, as the plan specified.
- `skills/skill-implementer-hard/SKILL.md` was re-confirmed clean (V7) and needed no change.
- All source-store edits landed under `agent-system/extensions/core/**`; `git status --porcelain
  .claude/` was verified empty at completion, and `.claude/` was not re-synced during this run.
