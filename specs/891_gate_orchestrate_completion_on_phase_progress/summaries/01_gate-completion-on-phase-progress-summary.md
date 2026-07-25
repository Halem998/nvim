# Implementation Summary: Task #891

**Completed**: 2026-07-25
**Duration**: ~0.5 hours

## Overview

`/orchestrate` previously flipped a task to `completed` on any `dispatch_status = "implemented"`
handoff, with zero awareness of phase accounting — an implementation agent that prematurely
self-declared "implemented" after phase 4 of 8 could permanently mark the task (and its plan
file) complete. This implementation added a phase-completion gate at the two ungated call sites
in the base `skill-orchestrate` skill (single-task Stage 5, multi-task Stage MT-4), and confirmed
— without editing — that the equivalent hard-mode site already carries the guard.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 `implemented)` case
  arm (previously an unconditional `skill_postflight_update` call) now gates the transition on
  `[ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]`. When false, the
  postflight call is skipped, a progress line is logged, and the task stays `implementing`
  (state transition unchanged — `cycle_count` increment and the artifact-linking block remain
  outside the `case`, so loop bookkeeping is unaffected).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4 per-task
  postflight step 2 now reads `phases_completed`/`phases_total` freshly per task from that task's
  own handoff (previously absent entirely from this stage); step 3's `"implemented"` bullet
  applies the identical gate. Steps 1, 4, 5, 6 are unchanged; step 5's existing
  `fresh_status = "implementing"` → `Otherwise` branch already handles the non-completed case
  correctly, so no downstream change was needed.

No other files were modified. `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
was read (lines 655-690) and confirmed — not edited — to already implement the equivalent guard.

## Decisions

- **Base-mode gate uses the pass-through form, not the hard-mode form.** Base mode uses
  `[ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]` (OR / pass-through
  on zero), while hard mode uses `[ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge
  "$phases_total" ]` (AND / require nonzero). This asymmetry is deliberate and documented inline
  in the added comment: base-mode handoffs frequently carry no phase accounting at all and must
  keep completing exactly as before (the binding non-regression constraint), whereas hard mode's
  per-phase dispatch model always populates phase accounting, so requiring `phases_total > 0`
  there is safe and already correct.
- **Hard-mode site left untouched.** `skill-orchestrate-hard/SKILL.md` Stage 5 (lines 669-679)
  already implements the requested guard from a prior fix. This task confirmed it via read-only
  inspection and left it — and the three pre-existing citation-style comments in that file near
  lines 619/661/717 — completely untouched; cleaning those up is explicitly out of scope here.
- **No `update-task-status.sh` change.** The script-layer defense-in-depth backstop remains a
  deliberate follow-up task, per the binding scope constraint; it was not touched.

## Plan Deviations

- None (implementation followed plan). Both edits used the plan's exact replacement text
  verbatim.

## Verification

- Build: N/A (markdown skill-definition change, no executable build)
- Tests: N/A (no executable test harness for this file type)
- Files verified: Yes — `git diff --stat -- agent-system/` shows exactly one file changed
  (`skill-orchestrate/SKILL.md`); `skill-orchestrate-hard/SKILL.md` shows zero diff;
  `git status --short --untracked-files=all -- .claude` shows no output (no deploy-tree edits);
  `agent-system/extensions/core/scripts/` shows zero diff (`update-task-status.sh`/`skill-base.sh`
  untouched); grep for task-number citation patterns in the `agent-system/` diff returns none;
  `continuation_context` does not appear in either new gate.

## Notes

- **Deploy note**: this fix becomes live in `.claude/` only after the user regenerates the
  deploy tree via the `<leader>al` picker/loader — no `.claude/` file was written by this task.
- **Follow-up recommended**: an `update-task-status.sh` defense-in-depth backstop was identified
  by research as a separate follow-up task (the script currently takes no phase-accounting
  arguments and is shared by `reconcile-task-status.sh`, `manage-topics.sh`, and
  `command-gate-out.sh`).
- **Behavior is narrowing-only**: the change can prevent a completion that previously happened,
  but cannot cause a completion that previously did not — the only regression risk is a task
  stuck at `implementing`, which is visible in `state.json`/TODO.md, bounded by
  `MAX_CYCLES`/`MAX_CYCLES_MT`, and recoverable via `/implement 891` or a manual status sync.
