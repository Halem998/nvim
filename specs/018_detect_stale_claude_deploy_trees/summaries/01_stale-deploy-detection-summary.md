# Implementation Summary: Detect stale .claude/ deploy trees and root-cause the silent staleness

- **Task**: 18 - Detect stale .claude/ deploy trees and root-cause the silent staleness
- **Status**: [COMPLETED]
- **Started**: 2026-08-17T00:15:00Z
- **Completed**: 2026-08-18T04:25:00Z
- **Effort**: ~5 hours across 6 phases
- **Dependencies**: None
- **Artifacts**: plans/01_stale-deploy-detection.md, reports/01_stale-deploy-detection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Research established there is no loader or copy-engine defect: `loader.lua`'s `copy_category`
force-overwrites every declared file on every load, `installed_files` is write-only bookkeeping
never consulted as a copy gate, and `manager.resync_all` calls `manager.load(force = true)` with
zero diffing. The staleness a consuming repo experiences is structural and by design --
regeneration is deliberately pull-only. This task implemented detection only, in two halves: a
Lua write side (`state.lua`'s `mark_loaded`) that stamps each extension's path-scoped
source-store git revision (`source_git_head`) into `.claude-extensions.json` at load time, and a
bash read side (`check-deploy-freshness.sh`) invoked non-blockingly from `command-gate-in.sh`
(CHECKPOINT 1, crossed by every ordinary command) that recomputes the current revision and WARNs,
naming the regeneration remedy, on mismatch.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/state.lua` (Phase 1, prior session) - added
  `M.resolve_source_git_head` and stamped `source_git_head` in `M.mark_loaded`
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` (Phase 2, prior session) - new
  standalone, always-`exit 0` checker
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` (Phase 3) - completed an
  untracked, interrupted-run artifact left by a prior `/orchestrate` session: inspected it,
  confirmed all 6 fixture cases (STALE, FRESH, MISSING FIELD, two UNVERIFIABLE variants, SCOPING)
  passed against the real checker, added the missing `info()` helper for full directory-convention
  compliance, and confirmed the deliberate-break check (inverting the comparison) flips 4 of 7
  cases to FAIL -- proving the suite is load-bearing
- `agent-system/extensions/core/manifest.json` - registered the test suite under
  `provides.scripts` (Phase 3, one line) and had already registered the checker (Phase 2, prior
  session)
- `agent-system/extensions/core/scripts/command-gate-in.sh` (Phase 4) - added the non-blocking
  freshness call at the end of `gate_in`, guarded on the deployed checker's existence, invoked via
  `bash ... 2>&1 || true`; updated the header comment
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (Phase 6) - added
  a "Detecting When You're Stale" section stating the root cause and documenting both halves,
  the silent-skip rationale, and the commit-granular/single-machine limitations
- `.claude-extensions.json` (Phase 5 addendum) - refreshed by running the real
  `deploy-headless.sh` regeneration; every one of the 6 active extensions now carries a 40-hex
  `source_git_head`

## Decisions

- Reused and completed the untracked `test-deploy-freshness.sh` left by the interrupted prior
  run rather than rewriting it from scratch: it was structurally sound (correct fixture,
  `set -uo pipefail`, `mktemp -d` + `trap cleanup EXIT`, PASSED/FAILED counters) and all 7
  assertions passed against the real checker on first run; only the `info()` helper named in the
  plan's directory-convention requirement was missing.
- Left the demonstrably-noise files flagged in the delegation context (`.claude-extensions.json`'s
  then-stale copy, `specs/errors.json`, `specs/events.jsonl`, and the untracked
  `agent-system/extensions/literature/scripts/literature-pyenv/` directory) untouched at the start
  of each phase's commit, staging only this task's own scope -- except that Phase 5's own
  redeploy legitimately refreshed `.claude-extensions.json` as the acceptance evidence itself, so
  that refresh was committed as a separate, clearly labeled addendum.
- Measured added preflight cost with bash `date +%s%N` deltas rather than `/usr/bin/time`, which
  is unavailable on this NixOS machine.

## Plan Deviations

- None (implementation followed plan)

## Impacts

- Every ordinary command (`/research`, `/plan`, `/implement`, `/orchestrate`, etc.) now prints a
  one-line-per-extension WARN at CHECKPOINT 1 when its deploy has drifted from the source store,
  naming `deploy-headless.sh` (or the picker's `[Reload All]`/`[Regenerate]`) as the remedy, with
  zero change to any command's admission decision, exit code, or exported variables.
- A repo deployed before this fix (no `source_git_head` field) is silently unaffected until its
  next regeneration restamps it -- no retroactive migration needed.
- `verify-deploy.sh`'s deeper per-file diffing gates are unchanged and remain the tool for
  detailed drift investigation; this check is strictly the cheap, always-on companion.

## Follow-ups

- None

## References

- specs/018_detect_stale_claude_deploy_trees/plans/01_stale-deploy-detection.md
- specs/018_detect_stale_claude_deploy_trees/reports/01_stale-deploy-detection.md
- specs/018_detect_stale_claude_deploy_trees/progress/phase-1-progress.json through phase-6-progress.json
- agent-system/extensions/core/scripts/check-deploy-freshness.sh
- agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh
- agent-system/extensions/core/scripts/command-gate-in.sh
- agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md

## Acceptance Evidence (both directions, captured verbatim)

**Root cause** (from research, restated in the new documentation section): the staleness was
never a loader defect. `loader.lua`'s `copy_category` force-overwrites every declared file on
every load; `installed_files` is write-only bookkeeping never consulted as a copy gate;
`manager.resync_all` calls `manager.load(force = true)` with zero diffing. Regeneration is
deliberately pull-only by design, so a consuming repo's `.claude/` tree freezes at its last
manual reload with no ambient signal when the source store moves on.

**Redeploy step** (regenerated this repo's own tree from source, confirming the write side):
```
[deploy-headless] Deploying extension tree into /home/benjamin/.config/nvim/.claude ...
[deploy-headless] deploy-lock: acquired (this invocation, pid 106070)
[deploy-headless] Resynced 6 extension(s) into /home/benjamin/.config/nvim/.claude
[deploy-headless] Verify with: bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh
```
(1.834s real time). Afterward, every one of the 6 active extensions carried a distinct 40-hex
`source_git_head` in `.claude-extensions.json` (email, core, memory, nvim, literature, nix).

**FRESH direction** (real gate-in path, task 20, this repo's freshly-deployed tree):
```
[IMPLEMENT] Task 20: fix_todo_metrics_sync_precommit_phantom_paths
```
No WARN line. Return code 0.

**STALE direction** (real gate-in path, a scratch target repo built via `mktemp -d`, deployed
with only the `core` extension, then `core.source_git_head` rewritten via `jq` to a real commit
10 revisions back from the current `HEAD`):
```
[IMPLEMENT] Task 20: fix_todo_metrics_sync_precommit_phantom_paths
WARN: deployed extension 'core' is stale — its .claude/ tree no longer matches the source store.
  Remedy: bash .claude/scripts/deploy-headless.sh (or the picker's [Reload All] / 'Regenerate').
  For per-file detail: bash .claude/scripts/verify-deploy.sh --findings
RETURN_CODE=0
```
The warning is non-blocking end-to-end: `gate_in` still returned 0 with the WARN present, and all
six exported variables (`SESSION_ID`, `TASK_TYPE`, `TASK_STATUS`, `PROJECT_NAME`, `DESCRIPTION`,
`PADDED_NUM`) were confirmed present in both the FRESH and a plain (non-stale) subshell test
against task 20. The terminal-status ABORT path (task 17, `completed`) and the task-not-found
path (task 999999) both still returned 1 without ever reaching the freshness call.

**Added preflight cost** (measured, not estimated): the standalone
`check-deploy-freshness.sh` invocation against this repo's real 6-extension
`.claude-extensions.json` averaged ~131ms across 3 runs (~22ms per extension) -- higher than the
Phase 1 research's raw `git log` estimate of 0.002-0.004s per extension because each entry costs
3 `jq` subprocess forks plus 2 `git` subprocess forks, not `git` alone. A full `gate_in`-in-a-
subshell comparison (includes task-lock acquire/release overhead) averaged ~488ms with the
checker present vs. ~433ms with it hidden, a ~55ms delta consistent with the isolated measurement.

**Cleanup**: the scratch target repo used for the STALE direction was removed
(`rm -rf` on its `mktemp -d` path) immediately after the demonstration; this repo's own
`.claude-extensions.json`/`HEAD` were never touched by that scratch test, and this repo's own
`.claude/` tree was left in the freshly-deployed state from the redeploy step above (confirmed
byte-identical between the deployed and source-store copies of `check-deploy-freshness.sh`).

**Regression check**: `run-all.sh` reported 41 passed / 3 failed both with and without the Phase
4 `command-gate-in.sh` edit (confirmed via a `git stash` A/B comparison) -- the 3 failures
(`validate-state.sh`'s single-source assertion, `test-skill-base-lifecycle.sh`,
`test-validate-return-meta.sh`'s fix-roundtrip case) are pre-existing and unrelated to this
change.
