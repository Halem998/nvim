# Implementation Summary: Task #876

**Completed**: 2026-07-15
**Duration**: ~1 hour

## Overview

Wired the already-in-scope `skill_preflight_update()` wrapper (from `skill-base.sh`) into every
research/plan/implement Agent-tool dispatch site on both `/orchestrate` paths — the base
single-task and multi-task (Stage MT-4) handlers in `skill-orchestrate/SKILL.md`, and all four
single-task handlers (including the H4 adversarial-verification-gated `plan` dispatch) in
`skill-orchestrate-hard/SKILL.md`. Tasks driven by `/orchestrate` now transition to
`researching`/`planning`/`implementing` during the work window instead of sitting at their
pre-dispatch status (`not_started`/`researched`/`planned`) for the entire dispatch. Also renamed
both misleadingly-named "Stage 2: Preflight — Loop Guard[...]" headings (loop-guard
initialization, not a status preflight) and added a note to the state-machine architecture doc.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — renamed the Stage 2 heading
  to "Loop Guard Initialization"; added `skill_preflight_update` calls in the `not_started`,
  `researched`, `planned`/`implementing`, and `partial`-continuation single-task handlers; added
  per-task `skill_preflight_update` calls (using the `"${session_id}_${task_num}"` form) before
  each of Stage MT-4's `research_tasks`/`plan_tasks`/`implement_tasks` dispatch loops, with an
  inline note that this does not violate the BATCHING RULE and is idempotent.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — renamed the Stage 2
  heading to "Loop Guard and Churn State Initialization"; added `skill_preflight_update` for
  `research` in the `not_started` handler; added `skill_preflight_update` for `plan` strictly
  inside the `if [ "$adversarial_verified" = "true" ]` block (never in the H4 verification
  re-dispatch branch), with a 4-line inline comment documenting the constraint; added
  `skill_preflight_update` for `implement` inside the `if [ -n "$next_phase" ]` per-phase-dispatch
  branch only (not in the skeleton-exhaustion `elif` or all-complete `else` branches), with a
  note on why the one-time side effects don't collide with the heading-scan phase selector; added
  the same `implement` preflight (defense-in-depth) in the `partial` continuation sub-state.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — added a note
  under the Complete State Table stating that `dispatch(...)` now performs the preflight status
  transition immediately before invoking the Agent tool, citing the relevant skill-file sections
  (durable anchors only, no task-number references).
- The three files above were also mirrored into the deployed `.claude/` copies
  (`.claude/skills/skill-orchestrate/SKILL.md`, `.claude/skills/skill-orchestrate-hard/SKILL.md`,
  `.claude/docs/architecture/orchestrate-state-machine.md`) so the live session's skill
  definitions match immediately, without waiting for the next full redeploy.

## Decisions

- **Canonical source is `agent-system/extensions/core/`, not `.claude/`.** `.claude/` is a
  disposable, gitignored deploy tree (`/.claude/` in `.gitignore`) regenerated from
  `agent-system/extensions/` per `.claude-extensions.json`. All edits described in the plan as
  targeting `.claude/skills/...` and `.claude/docs/...` were applied to the git-tracked source
  under `agent-system/extensions/core/` (the files that actually persist and ship), and mirrored
  into the deployed `.claude/` copies for immediate effect in the current session. Every commit
  in this implementation stages only the `agent-system/` source paths (plus this task's own
  `specs/` artifacts), since the `.claude/` mirror is gitignored and never appears in `git status`.
- A pre-existing, unrelated drift was discovered between the two trees (`orchestrator_mode: true`
  in `agent-system/extensions/core/skills/skill-orchestrate*/SKILL.md` for research/plan
  dispatches, vs. `orchestrator_mode: false` in the deployed `.claude/` copies). This predates
  this task, is out of scope (not part of the preflight-wiring plan), and was left untouched —
  confirmed by diffing before and after each edit that this was the *only* remaining difference
  between the two trees beyond my intended changes.

## Plan Deviations

- None (implementation followed plan). The canonical-source discovery above is not a deviation
  from the plan's intent — the plan's Goals and every named file were edited exactly as
  specified; it is a mechanical detail of *where* those edits had to land to actually persist in
  git, since the paths named in the plan (`.claude/skills/...`, `.claude/docs/...`) are the
  deployed mirror of the git-tracked source.

## Verification

- Build: N/A (markdown/meta skill-definition changes, no build step)
- Tests: N/A (no orchestrate test harness exists; Phase 5 manual/static verification performed
  instead, per plan)
- Files verified: Yes — `grep -c "skill_preflight_update"` returns 7 in
  `skill-orchestrate/SKILL.md` (4 single-task + 3 MT-4) and 4 in
  `skill-orchestrate-hard/SKILL.md`, in both the canonical source and the deployed `.claude/`
  copies. `grep -rn "Stage 2: Preflight"` returns nothing in either skill file (either tree). The
  H4 ordering was confirmed by reading: the `plan` preflight is the first line inside
  `if [ "$adversarial_verified" = "true" ]`, immediately before `subagent_type: $PLANNER_AGENT`;
  the earlier verification re-dispatch branch (`subagent_type: $RESEARCH_AGENT`, while status is
  still `researched`) has no preflight call. The `implement` preflight in the hard skill's
  per-phase handler was confirmed to sit only inside `if [ -n "$next_phase" ]`, not in the
  `elif`/`else` branches. `update-task-status.sh` lines 133-144 were read and confirmed to no-op
  when `current_state_status == STATE_STATUS`, before any state.json write.

## Notes

No new scripts were created or modified — this task wires the existing
`skill_preflight_update()`/`update-task-status.sh` machinery into the orchestrate dispatch sites,
per the plan's non-goals. The architecture-doc note and both `SKILL.md` inline comments cite
durable anchors (file names, section headings) only, honoring
`no-task-references-in-deliverables.md`.
