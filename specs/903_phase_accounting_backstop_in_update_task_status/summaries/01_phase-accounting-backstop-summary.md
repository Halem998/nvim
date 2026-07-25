# Implementation Summary: Task #903

**Completed**: 2026-07-25
**Duration**: ~4 hours

## Overview

Added an optional, additive `--phase-check=warn|refuse` flag to `update-task-status.sh` that,
when passed, independently counts a task's plan-file `### Phase N: {name} [STATUS]` headings and
either warns about or refuses (exit 4, zero writes) a `postflight ... implement` transition when
on-disk evidence shows phases are still incomplete. The flag is absent by default at every
existing call site, so pre-existing behavior is preserved byte-for-byte. It was then threaded
per call site — `refuse` at the three sites with zero phase gate today, `warn` at the sites
where a SKILL-layer gate already made an informed decision — gated on an empirical validation
pass (Phase 3) that confirmed real completed tasks' plan files do carry all-`[COMPLETED]` phase
headings before any `refuse` shipped.

## What Changed

- `agent-system/extensions/core/scripts/update-task-status.sh` — added `--phase-check=warn|refuse`
  parsing, strict enum validation, exit code 4, and a single "PHASE 0" evidence-gathering gate
  (`resolve_plan_file_for_phase_check()` + `count_plan_phases()`) placed before
  `acquire_state_mutex`/`mkdir -p "$TMP_DIR"` so one check blocks both the state.json flip and
  `update_plan_file()`'s `[COMPLETED]` stamp.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — both the `implementing` and
  `partial` repair branches now pass `--phase-check=refuse` and branch explicitly on exit 4
  (leaves status unchanged, logs loudly) vs. any other nonzero exit (fatal). Refusals do NOT
  route through `record_refused_promotion`.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — the defensive correction now
  passes `--phase-check=refuse` only when `status_token == implement`, with an explicit exit-4
  branch distinct from other failures; stderr is no longer discarded on this call.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_postflight_update()` gained an
  optional 5th `phase_check_mode` argument (absent by default), forwarded as `--phase-check=<mode>`
  only when non-empty.
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` and
  `skill-implementer-hard/SKILL.md` — both now pass `--phase-check=refuse` on their postflight
  implement call, with a new refusal branch (Step 1a / inline) that keeps the task at
  `implementing` and records a resume point, mirroring the existing `partial` handling.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 5 + Stage MT-4) and
  `skill-orchestrate-hard/SKILL.md` — pass `"warn"` as the 5th argument to
  `skill_postflight_update` on their `implemented` arms (second opinion, never a veto — these
  gates already decided to proceed using richer context).
- Four extension implementer SKILL.md files (`skill-lean-implementation`,
  `skill-lean-implementation-hard`, `skill-cslib-implementation`,
  `skill-cslib-implementation-hard`) — appended ` --phase-check=warn` to their existing
  postflight implement call.
- `agent-system/extensions/core/context/formats/plan-format.md` — added a note under
  "Implementation Phases (format)" identifying the three consumers of the
  `### Phase N: {name} [STATUS]` heading contract: `update-phase-status.sh`,
  `update-plan-status.sh`, and `update-task-status.sh`'s `--phase-check` backstop.

## Decisions

- Evidence is gathered exclusively from `### Phase N: ... [STATUS]` headings, never `- [ ]`/
  `- [x]` checkboxes (evaluated and rejected in the research/plan as unreliable — checkboxes are
  sub-phase granularity and also appear in non-phase sections).
- No plan file, no plan directory, or zero conforming headings is treated as INCONCLUSIVE and
  always passes through, deliberately mirroring the existing SKILL-layer gate's
  `phases_total == 0` pass-through so the two layers never disagree on the meaning of "no data".
- `state_is_noop == true` (a task already at `completed` replaying postflight) is excluded from
  the gate entirely — nothing left to refuse.
- `--dry-run` always previews and exits 0, even under `--phase-check=refuse`, so a caller can
  preview a refusal without it looking like a script failure in a dry-run harness.
- `grep -c` zero-match handling uses `VAR=$(grep -c ...) || VAR=0` throughout (never the
  two-line-emitting `$(grep -c ... || echo 0)` form).
- The empirical validation gate (Phase 3) sampled 10 recent completed tasks (spanning active
  `state.json` and `specs/archive/`) and found 10/10 (100%) with `done == total` and zero
  headings stuck at `[NOT STARTED]`, well above the 80% pass criterion — `refuse` shipped as
  planned rather than being downgraded to `warn`-only.

## Plan Deviations

- None (implementation followed plan). Baseline diffing in Phase 7 used commit `49eefe2fe` (the
  last commit to `update-task-status.sh` before this task's Phase 1) as the pre-change reference,
  since `HEAD` at proof time already included this task's own commits — an implementation detail
  the plan's `git show HEAD:...` shorthand assumed a single-shot proof context for; the substance
  (diff touches only additive regions, and the full dry-run matrix is byte-for-byte identical
  modulo the live-clock timestamp present identically on both sides) is unchanged.

## Verification

- Build: N/A (bash scripts + markdown)
- Tests: `bash -n` clean on all 4 modified `.sh` files; live behavioral verification of every
  verdict branch (proceed, warn, refuse, inconclusive, state_is_noop exclusion) against real
  task plan files and a scratch test task (999999, created and fully deleted, with
  `specs/state.json`/`specs/TODO.md` restored from backup and diff-confirmed identical
  afterward); full operation × target_status × task-state `--dry-run` matrix (4 tasks × 2
  operations × 3 target statuses = 24 cells) against the pre-903 baseline produced zero
  MISMATCH with exit codes folded into the compared strings
- Files verified: Yes

## Notes

The Phase 3 empirical validation gate is a hard prerequisite this implementation honored: had
fewer than 80% of the sampled completed tasks shown `done == total`, every `refuse` in Phases 4-5
would have been downgraded to `warn`-only and the gap recorded as a follow-up blocker, per the
plan's Rollback/Contingency section. That did not happen — the 100% pass rate cleared the gate
with margin.

Twelve call sites were audited end-to-end (3 `warn` via `skill_postflight_update`'s 5th arg from
`skill-orchestrate`/`skill-orchestrate-hard`, 4 `warn` at the lean/cslib extension implementers,
2 `refuse` at `skill-implementer`/`skill-implementer-hard`, 2 `refuse` at
`reconcile-task-status.sh`'s two repair branches, 1 `refuse` at `command-gate-out.sh`'s
implement-only defensive correction) and each confirmed against the plan's assignment table by
direct `grep`.
