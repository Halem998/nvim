# Implementation Summary: Task #893

**Completed**: 2026-07-25
**Duration**: ~3 hours (across an infrastructure interruption and resume)

## Overview

`reconcile-task-status.sh`'s dispatch previously treated `not_started` as an unconditional no-op
inside its `*)` catch-all, so a task whose plan (or phase handoff) was written but whose postflight
was lost stayed stuck at `not_started` forever, invisible to `/orchestrate`'s unattended reconcile
pass. This task added a dedicated `not_started)` branch with two promotion cases — a fresh plan
promotes to `planned`, a fresh phase handoff promotes to `partial` (never `implementing`) — both
gated by a new `artifact_newer_than_last_update()` mtime guard that prevents the `/task --recover`
workflow (which restores a task's whole directory, including old artifacts, and forces
`status="not_started"`) from being misread as a stranded run.

## What Changed

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — the only repository file this
  task changes. Three edits:
  1. Module header comment extended with two new artifact-to-phase mapping rows for
     `not_started`, plus a rationale block explaining why the mtime gate exists and warning a
     future maintainer not to "simplify" it into a bare presence check.
  2. New `artifact_newer_than_last_update()` helper (placed immediately after
     `handoff_status_value()`), using the GNU-then-BSD `date`/`stat` fallback idiom already
     established in `scripts/task-lock.sh` and `scripts/claude-cleanup.sh`. Ties refuse (strict
     `-gt`, not `-ge`); missing `last_updated` fails open (permit, matching
     `handoff_permits_promotion`'s existing philosophy); an unstattable artifact fails closed.
  3. New `not_started)` case in the main dispatch, inserted before the `*)` catch-all (whose
     comment no longer lists `not_started`): case (a) checks `plans/*.md` and promotes to
     `planned` via `postflight plan`; case (b), defense in depth, checks `handoffs/*.md` and
     promotes to `partial` via `postflight partial` when no fresh plan matched. Both cases are
     handoff-aware (reusing `handoff_permits_promotion`/`record_refused_promotion`) for
     consistency with the four pre-existing branches, though the mtime guard — not the handoff —
     is what actually disambiguates a recovered task from a stranded one.

No other repository file was modified by this task.

## Decisions

- Reused the exact GNU-then-BSD `date -u -d ... || date -u -j -f ...` idiom from
  `scripts/task-lock.sh` rather than the research draft's GNU-only `date -u -d`, so the guard is
  not a silent no-op on a BSD host.
- Skipped the git-log "phase commits exist" signal entirely, per the plan's explicit non-goal — a
  phase commit cannot exist without a prior plan file, so the `plans/*.md` check already covers
  every realistic case at lower cost.

## Plan Deviations

- **Phase 1/2 verification counts**: the plan's stated `grep -c 'artifact_newer_than_last_update'`
  counts (1 after Phase 1, 3 after Phase 2) do not match the actual counts (2 and 5 respectively).
  Root cause: the plan's own quoted Edit 1A/1B text contains additional self-referential comment
  mentions of the helper's name beyond what the plan's verification step anticipated. The
  implemented code is a byte-exact transcription of the plan's quoted find/replace blocks (the
  authoritative anchors per the delegation's binding constraints); only the plan's own stated grep
  count was inaccurate. All functionally load-bearing checks (bash -n, exact call-site count via
  direct inspection, absence of `git log`, absence of `not_started -> implementing`, git diff
  scoped to one file) passed independently. See `progress/phase-1-progress.json` and
  `progress/phase-2-progress.json`.
- **Phase 3 live-run scope broadened**: the plan's task list said to re-run T1, T2, T4, and T6
  LIVE; this implementation ran ALL of T1-T9 live, per the delegation's binding constraint that
  T2, T3, T4, T5, and T7 must each be proven `not_started` under a LIVE run (not merely dry-run),
  and to exercise T8/T9's full handoff-aware refuse/permit paths end-to-end. Strictly increases
  coverage; no fixture behavior changed as a result.
- **Phase 3 T10 baseline source**: the plan's task list said to obtain the regression baseline via
  `git show HEAD:...`. By the time Phase 3 executed, this task's own Phase 1 and Phase 2 commits
  were already on `HEAD` (git history in this shared, multi-agent repository advances
  continuously), so a literal `HEAD` read would have compared the new script against itself. The
  baseline was instead sourced from the commit immediately preceding this task's own Phase 1
  commit (`03e6f5660^`), which is the correct concrete resolution of the plan's "pre-change
  baseline" intent (also stated in the plan's Risks table and Rollback/Contingency section). The
  T10 comparison was additionally re-verified a second time using the exact git-committed `HEAD`
  copy of the script (rather than the live working-tree copy), because an unrelated concurrent
  agent's uncommitted edit to the same file was discovered mid-Phase-3 (see Notes below); both
  verification passes produced byte-identical dry-run and live output.

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — all 10 matrix rows (T1-T10) pass, including two independent full passes of
  T1-T9 (one during initial Phase 3 execution, one final re-verification against the exact
  git-committed `HEAD` copy) and two independent T10 regression comparisons (dry-run and live),
  both byte-identical to the pre-change baseline.
- False-positive acceptance criterion (binding): T2 (`/task --recover` shape), T3 (whole-second
  tie), T4 (empty task dir), T5 (empty `plans/` dir), and T7 (stale handoff) EACH left
  `.status == "not_started"` after a LIVE run, in both verification passes. No false positives.
- `bash -n` passes on the modified script.
- `git diff -- agent-system/extensions/core/scripts/reconcile-task-status.sh | grep -nEi 'task [0-9]+'`
  returns nothing — no task-number citations in the deliverable.
- No `git log` invocation was introduced (the rejected signal, per grep).
- No file under `.claude/**` was modified by this task.
- Files verified: Yes

## Notes

- **The fix is NOT live.** This task modified only the source-store copy at
  `agent-system/extensions/core/scripts/reconcile-task-status.sh`. The deployed copy at
  `.claude/scripts/reconcile-task-status.sh` is untouched and stays stale until the user
  re-deploys via `<leader>al` ("Load Core" / "Sync all"). An agent cannot perform that step — it
  is user-driven and out of scope for this task.
- This repository has multiple concurrent agents actively editing `agent-system/` at the same
  time as this task ran (observed task-shaped work touching `guard-destructive-git.sh`,
  `git-workflow.md`, `command-gate-out.sh`, and `reconcile-task-status.sh` itself). A concurrent,
  unrelated uncommitted edit to `reconcile-task-status.sh` (adding `--phase-check=refuse` wiring
  to the pre-existing `implementing`/`partial` branches — no relation to this task's
  `not_started)` branch) was observed mid-Phase-3 and deliberately left untouched, unstaged, and
  uncommitted by this task. This task's own Phase 2 commit was also observed to have been bundled
  by a different concurrent agent's commit (`5eaade0ce`, titled as a different task's phase 3)
  rather than landing under this task's own commit message — the content is verified correct and
  intact either way; only the commit message attribution is imprecise, a byproduct of concurrent
  multi-agent commits in this shared working tree, not a defect in this task's work.
- The plan's own Edit 1A/1B verification grep counts were slightly inaccurate (see Plan
  Deviations above); this is noted for future plan-writers as a minor lesson (self-referential
  comment text inflates naive `grep -c` counts of a helper's own name).
