# Implementation Summary: Task #810

**Completed**: 2026-07-04
**Duration**: ~1 hour

## Overview

Routed `/research`, `/plan`, and `/revise` through the shared `command-gate-in.sh`/`command-gate-out.sh` scripts (task 788's gate infrastructure), closing the gap where these three commands carried fully-inline, duplicated CHECKPOINT logic and never touched `task-lock.sh`. Two prerequisite script corrections landed first (an operation-aware terminal-status exemption for `revise`, and a `status_token` mapping fix that also repairs a latent `orchestrate` bug), then all three commands were refactored to source the corrected scripts, and `research.md`/`plan.md`'s multi-task dispatch loops gained per-task lock bracketing matching `implement.md`'s Step 3. All 5 phases from the plan completed; all 10 dual-copy pairs verified byte-identical.

## What Changed

- `.claude/scripts/command-gate-in.sh` — wrapped the `completed|abandoned|expanded` terminal-status guard in `if [ "$operation" != "revise" ]; then ... fi` so `/revise` is never rejected on terminal-status tasks, preserving `skill-reviser`'s "works regardless of task status" contract.
- `.claude/scripts/command-gate-out.sh` — added a `status_token` variable alongside `expected_status` in the `case "$operation"` block: `research→research`, `plan→plan`, `implement→implement`, `orchestrate→implement` (fixes a latent bug — previously `orchestrate` was passed verbatim as `target_status`, which `update-task-status.sh` does not accept), `revise→plan` (new). The postflight call now passes `"$status_token"` instead of `"$operation"`.
- `.claude/commands/revise.md` — CHECKPOINT 1 now sources `command-gate-in.sh "$task_number" "revise"`; CHECKPOINT 3 now calls `command-gate-out.sh "$task_number" "revise" "$SESSION_ID"`. Kept the revise-specific plan-existence check (drives Plan-Revision vs Description-Update routing) and the description-update path's automatic skip of defensive correction. Dropped the manual TODO.md Edit-tool fallback. Updated Error Handling for lock-refusal and cross-task overlap-refusal.
- `.claude/commands/research.md` — CHECKPOINT 1 now sources `command-gate-in.sh "$task_number" "research"`; CHECKPOINT 2 now calls `command-gate-out.sh "$task_number" "research" "$SESSION_ID"`, keeping the inline artifact-existence check (gate-out's `validate-artifact.sh --fix` leg is dead code and cannot substitute). Added per-task `task-lock.sh acquire`/`release` bracketing to the MULTI-TASK DISPATCH loop (Step 3), copying `implement.md`'s pattern verbatim. Updated header to `[RESEARCH]` and Error Handling sections (both single-task and multi-task) for the new lock-refusal/overlap-refusal modes.
- `.claude/commands/plan.md` — Same shape as research.md: CHECKPOINT 1/2 now source/call the gate scripts with operation `"plan"`; kept the plan-specific "Load Context" step and the plan-file-status verification (step 6, now step 3 after the gate-out call). Added per-task lock bracketing to its MULTI-TASK DISPATCH loop. Header updated to `[PLAN]`; Error Handling updated.
- `.claude/extensions/core/scripts/command-gate-in.sh`, `.claude/extensions/core/scripts/command-gate-out.sh`, `.claude/extensions/core/commands/{research,plan,revise}.md` — identical mirrors of all edits above (verified byte-identical via `diff`, zero output on all 5 pairs).

Incidental coherence touch-ups (downstream of the CHECKPOINT rewrites, not separately listed in the plan but necessary for correctness): in `research.md` and `plan.md`, the STAGE 2 extension-routing block previously derived `task_type` from a `task_data` variable that CHECKPOINT 1 no longer sets; both now read `task_type="$TASK_TYPE"` from gate-in's export. The `session_id={session_id}` placeholders in the Skill-tool `args:` templates were updated to `session_id={SESSION_ID}` to match the variable gate-in actually exports (matching `implement.md`'s convention).

## Decisions

- Bundled the `orchestrate→implement` `target_status` fix into the same Phase 1 edit as the new `revise` arm, since both touch the identical 6-line `case` block — flagged here explicitly per the plan's Risk mitigation, not scope creep.
- Left `command-gate-out.sh`'s dead `validate-artifact.sh "$task_dir" --fix` leg untouched (pre-existing, orthogonal — candidate for a separate bug-fix task per the research report).
- `.opencode/*` was treated as out of scope throughout (pre-existing, already-diverged system; task 788 itself did not extend there either).

## Plan Deviations

- None (implementation followed plan). Two small documentation-only coherence edits (the `task_type="$TASK_TYPE"` substitution and the `session_id={SESSION_ID}` placeholder casing in `research.md`/`plan.md`'s STAGE 2 DELEGATE sections) were made beyond the plan's literal task list, but they are a direct, necessary consequence of the plan's own CHECKPOINT 1 rewrite (removing the `task_data` lookup) and are documented above under "What Changed" rather than treated as a deviation from plan intent.

## Verification

- Build: N/A (bash scripts + markdown command files)
- Tests: Passed — `bash -n` clean on both gate scripts; sandbox subshell tests confirmed (a) `command-gate-in.sh` with `operation=revise` succeeds (exit 0, no ABORT) on a fabricated `abandoned` task, while `operation=research`/`plan` still abort (exit 1); (b) `command-gate-out.sh` with `operation=revise` passes `target_status=plan` and `operation=orchestrate` passes `target_status=implement` to a stubbed `update-task-status.sh`, neither triggering its validation error
- Files verified: Yes — all 5 dual-copy pairs (`research.md`, `plan.md`, `revise.md`, `command-gate-in.sh`, `command-gate-out.sh`) diff to zero output between `.claude/` and `.claude/extensions/core/`
- Coherence audit (Phase 5): all three refactored commands source `command-gate-in.sh`/call `command-gate-out.sh` with matching operation strings, consistent with `implement.md`/`orchestrate.md`; grep confirmed no residual inline session-gen, terminal-guard, or manual TODO.md Edit-tool logic remains beyond the documented command-specific supplementary steps (research artifact check; plan Load Context + plan-file-status; revise plan-existence + description-update routing); `research.md`/`plan.md` multi-task loops acquire/release the lock per task with skip-on-refusal, matching `implement.md` Step 3 exactly

## Notes

- **Intentional header wording change**: `/research` and `/plan` headers now display `[RESEARCH]`/`[PLAN]` (gate-in's mechanical uppercasing of the operation string) instead of the prior present-participle `[Researching]`/`[Planning]`. `/revise` now displays `[REVISE]` (it previously had no CHECKPOINT-displayed header at all). This is a deliberate cosmetic change, not a regression — call this out if it surfaces in a later audit (tasks 811-813).
- **Non-Goals confirmed held**: `.opencode/*`, `.claude/context/patterns/task-lock.md`, all `.postflight-pending` write sites, and `validate-artifact.sh` were not touched by any Edit/Write call in this dispatch. These paths do appear as `M` in `git status` — that is pre-existing, uncommitted state from the coordinated batch's earlier tasks (804 touched `research.md`/`plan.md`'s flag docs prior to this dispatch; 808/809 extended `task-lock.sh` and `task-lock.md`), live in the working tree before this task began, per the batch coordination note in the delegation context. This task's own edit footprint is exactly the 10 files listed under "What Changed."
- **Single shared gate path achieved**: `/research`, `/plan`, `/revise`, `/implement`, and `/orchestrate` now all source the identical `command-gate-in.sh`/`command-gate-out.sh` pair with their respective operation strings (`research`, `plan`, `revise`, `implement`, `orchestrate`) — there is no partial variant remaining. This is the state tasks 811-813 should find when auditing the whole system.
- `.claude/commands/{research,plan,revise}.md` and their `.claude/extensions/core/commands/` mirrors, plus `.claude/scripts/{command-gate-in,command-gate-out}.sh` and their mirrors, are the 10 files this task modified.
