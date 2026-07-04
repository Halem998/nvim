# Implementation Summary: Task #808

**Completed**: 2026-07-04
**Duration**: ~1 hour

## Overview

Closed the TOCTOU gap in `.orchestrator-loop-guard` and `.orchestrator-churn-state.json`
creation by adding a new, generic `task-lock.sh init-marker <file_path>` subcommand that reuses
the script's existing `mkdir`-gate + tmp-file-`mv` exclusivity idiom, then swapping all three
non-atomic `jq -n ... > file` creation branches (across four `SKILL.md` copies) to call it with a
resume-read fallback on a lost race. All edits are additive: `cmd_acquire`, `write_holder`, and
the task-number `.lock/` directory (task 809's territory) were not touched, and
`.postflight-pending` (task 810's territory) was not touched.

## What Changed

- `.claude/scripts/task-lock.sh` — added `cmd_init_marker()` (mkdir-gate + tmp-mv write, bounded
  recheck + one self-heal retry for orphaned claims), a new `init-marker)` case arm, and an
  exit-code table in the header comment block.
- `.claude/extensions/core/scripts/task-lock.sh` — byte-identical mirror.
- `.claude/skills/skill-orchestrate/SKILL.md` — Stage 2 loop-guard `else` branch now pipes its
  `jq -n` payload through `init-marker "$loop_guard_file"`; on exit 1 it resume-reads
  `cycle_count` exactly as the `if`-branch does.
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — Stage 2 loop-guard `else` branch swapped the
  same way, resume-reading **both** `cycle_count` and `burnout_signals_this_session` on exit 1;
  the churn-state `else` branch swapped similarly, resume-reading `total_churn` on exit 1.
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` and
  `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — byte-identical mirrors.
- `.claude/context/patterns/task-lock.md` — added an `### init-marker <file_path>` contract
  subsection (renamed the parent heading to include it), retired the "Atomic-creation guard for
  `.orchestrator-loop-guard`" Non-Goals bullet with a CLOSED back-reference to task 808, and added
  the four `init-marker` call sites to Consumers / Related Documentation.
- `.claude/extensions/core/context/patterns/task-lock.md` — byte-identical mirror.

## Decisions

- Reused `write_holder`'s exact tmp-file + `[ ! -s ]` emptiness-guard idiom for `init-marker`'s
  payload write, rather than inventing a new write pattern, per the plan's non-goal that this is
  not a second locking mechanism.
- Implemented the "bounded recheck" (Risk register / Phase 1 spec) as a 10-iteration, 50ms-spaced
  poll loop after a losing `mkdir`, so that a currently-racing writer (expected under the N=20
  stress test) is correctly distinguished from a truly orphaned claim left by a crashed
  initializer — this was necessary to avoid a losing writer prematurely `rmdir`-ing an in-flight
  winner's claim directory mid-write.
- Left `git add`/`git commit` out of this dispatch per the delegation's explicit "Do NOT git
  commit" instruction; all edits remain as uncommitted working-tree changes for the orchestrator
  to commit.

## Plan Deviations

- **Task 3.2** altered: the plan's suggested "remove the bullet... optionally add a one-line
  back-reference" was implemented as a paraphrased strikethrough + `CLOSED` back-reference rather
  than a literal strikethrough of the original bullet text, because a literal strikethrough would
  still contain the exact retired phrase ("Atomic-creation guard for") that the plan's own
  verification step greps for as absent. See `progress/phase-3-progress.json` for the full
  deviation record.

## Verification

- Build: N/A (bash scripts + markdown docs)
- Tests:
  - `bash -n` passes on both `task-lock.sh` copies.
  - Concurrent-creation stress test: N=20 parallel `init-marker` writers → exactly one exit 0
    (winner's payload became the final file), all 19 others exit 1, no leftover `.init`/`.tmp`
    artifacts.
  - Orphan-recovery test: a pre-created stale `.init` directory with no target file self-healed
    (WARN to stderr), created the file, and exited 0.
  - Integration smoke test: ran the Stage 2 bash block against a temp `TASK_DIR` twice in one
    shell (fresh, then resume after simulating a refresh-site bump) — the second run correctly
    resumed with `cycle_count=3` instead of clobbering it back to 0.
  - `diff -q` byte-identity confirmed across all four dual-copy pairs: `task-lock.sh`,
    `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, `task-lock.md`.
  - Grep-verified: no bare creation `>` redirect remains at any of the three swapped sites; all
    six tmp+`mv` refresh sites are unchanged; `cmd_acquire`/`write_holder` are byte-unchanged
    (only referenced in new comments); the retired gap-note phrase no longer appears in either
    `task-lock.md` copy.
- Files verified: Yes

## Coordination Notes (Batch 804/808/809/810)

Per the coordinated-batch instructions for this dispatch:
- Did not touch `parse-command-args.sh` or model-flag documentation (task 804's territory) —
  confirmed no edits made to any file matching those patterns.
- `task-lock.sh`'s edits are strictly additive: a new `cmd_init_marker()` function placed after
  `cmd_check`/before the `# Dispatch` divider, and a new `init-marker)` case arm appended to the
  existing `case` block. `cmd_acquire` and its dispatch arm were not restructured, read, or
  reordered, leaving task 809's planned extension of `cmd_acquire` unobstructed.
- `.postflight-pending` was not referenced or modified anywhere in this task's edits (task 810's
  territory).

## Notes

The task-lock lock (`specs/808_loop_guard_atomic_creation/.lock/holder.json`) held by this
session's orchestrator was left untouched by this agent — release is the orchestrator's
responsibility. No git commit was made in this dispatch per explicit delegation instructions;
the orchestrator's postflight owns committing these changes.
