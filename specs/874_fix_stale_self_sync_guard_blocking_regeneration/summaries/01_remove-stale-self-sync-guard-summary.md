# Implementation Summary: Task #874

**Completed**: 2026-07-15
**Duration**: ~1.5 hours

## Overview

Removed the stale `project_dir == global_dir` early-return guard in `M.load_all_globally()` inside
`sync.lua`, which was blocking the nvim repo from regenerating its own gitignored `.claude/` deploy
tree via `<leader>al`. Replaced it with a narrow self-load exclusion scoped only to the `lib`/`tests`
categories inside `scan_all_artifacts` (the only categories with no durable core-store source, where
self-load would otherwise resolve to a degenerate copy-onto-itself), and made that exclusion visible
in the sync summary notification so a zero-file `Lib`/`Tests` count can never be misread as a
complete regeneration.

## What Changed

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`:
  - Deleted the early-return block (`if project_dir == global_dir then ... return 0 end`, formerly
    lines 1146-1150) from `M.load_all_globally()`, including its now-obsolete comment.
  - Added `local is_self_load = project_dir == global_dir` near the top of `scan_all_artifacts`, with
    a comment explaining why core-sourced categories remain safe on self-load.
  - Gated the `lib`/`tests` population (formerly lines 1064-1066) on `not is_self_load`; on self-load
    they are left `nil` and `artifacts._self_load_skipped = { "lib", "tests" }` is set instead. The
    `settings` sub-branch was left untouched inside the same `if base_dir == ".claude"` block.
  - In `execute_sync`, added a `self_load_msg` suffix (empty string when `_self_load_skipped` is
    absent) appended to the existing summary `helpers.notify(...)` call, following the same optional
    -suffix pattern already used by `protect_msg`/`untracked_msg`.
- No other repository files were modified. `display/previewer.lua:168`, the second caller of
  `scan_all_artifacts`, required no change — the exclusion lives inside the shared scan function, so
  the picker preview and the actual sync stay consistent by construction.

## Decisions

- Followed the plan's explicit decision: on self-load, `lib`/`tests` are SKIPPED (left `nil`), never
  emptied or deleted. Whatever exists on disk at `.claude/lib`/`.claude/tests` is retained untouched.
  This is a true no-op today (verified: neither directory exists in this repo's deploy tree, and the
  core store ships no equivalent), acceptable specifically because Phase 3 makes the skip visible in
  the sync summary rather than letting it read as a silent complete regeneration.
- `M.update_artifact_from_global` (~line 1392, "Cannot update artifacts in the global directory") was
  left untouched, per the plan's explicit non-goal. Verified its guard text is still present and its
  own single-artifact-update entry point is unaffected.
- Used allow-list resolution (not blocklist fallback) for the scratchpad harness's fake manifest —
  `get_core_provides`/`build_allow_list` resolved successfully against a minimal
  `provides.commands`/`provides.agents` manifest, so the blocklist fallback path was not exercised.

## Plan Deviations

- **Phase 1 vs. Phase 2 execution order**: the plan's wave map declares Phases 1 and 2 independent
  (same wave, no dependency between them). Execution made the Phase 2 source edits first, then built
  the Phase 1 harness, then used `git show HEAD:sync.lua` (the true pre-edit committed version — a
  stronger baseline than an in-place unmodified copy) to run the harness against the unmodified code
  for the "before" comparison. This is an order change, not a scope or dependency violation: the
  load-bearing constraint from the Risks table (the harness exists before Phase 4 runs anything
  against the *modified* code) was honored exactly, and the real `.claude` tree was never a sync
  target at any point in either order.
- **Phase 4 Assert (4)**: verified by reproducing the exact skip-underscore-prefix loop patterns from
  both `load_all_globally`'s total-count loop and `audit_synced_content`'s loop directly against the
  self-load scan result (via `pcall`), rather than by invoking the full interactive
  `M.load_all_globally()` entry point. The full entry point reaches a `vim.fn.confirm()` dialog that
  is not safely drivable in headless mode — this is precisely the risk the plan's Risks table
  anticipated ("Full `load_all_globally()` path ... not exercisable in scratchpad") and mitigated by
  directing verification to the `scan_all_artifacts` layer instead. Reported as observed and PASS,
  not inferred.
- **Testing & Validation checklist item "the skip is visible in the sync summary"**: verified by code
  review of the `execute_sync` diff (the `self_load_msg` suffix construction and its conditional,
  empty-by-default behavior), not by a live headless run reaching that notification, for the same
  `vim.fn.confirm()` reason above. No assertion was inferred or claimed without this caveat.

## Verification

- Build: N/A (no compiled build step for this Lua module)
- Module load: `nvim --headless -u NONE -c "luafile sync.lua" -c "qa!"` — exit 0, no error
- Headless scratchpad harness (`/tmp/.../scratchpad/874_impl/test_self_load.lua`), run twice — once
  against the true `git show HEAD:sync.lua` baseline, once against the modified working-tree file:
  - **Baseline** (pre-fix): confirms the research finding exactly — `commands` self-referential
    `false` (action `replace`), `lib`/`tests` self-referential `true` (both would self-copy). This
    reproduces the exact bug being fixed.
  - **Post-fix**: all 5 Phase 4 assertions **PASS** and were actually observed (not inferred):
    1. Self-load regenerates core-sourced categories (`commands` action=`replace`, distinct
       `global_path`/`local_path` under `agent-system/extensions/core/` vs `.claude/`) — PASS
    2a. `artifacts.lib`/`artifacts.tests` are `nil` on self-load, `_self_load_skipped = {lib, tests}`
        set — PASS
    2b. Fake `.claude/lib/bar.sh` and `.claude/tests/test_baz.sh` retained on disk, byte-identical to
        their original content — PASS
    3. Non-self-load control run (distinct `FAKE_PROJECT` dir) still populates `lib`/`tests`
       normally, no `_self_load_skipped` key — PASS (proves the exclusion is scoped to self-load only)
    4. `_self_load_skipped` passes through both `pairs(all_artifacts)` skip-loop patterns without
       error — PASS
  - Real tree isolation confirmed after every run: `ls ~/.config/nvim/.claude/lib` still errors
    (`No such file or directory`), `git status --short .claude` empty throughout.
- `grep -n "Already in the global directory" sync.lua` — no match (guard removed)
- `grep -n "Cannot update artifacts in the global directory" sync.lua` — still matches (out-of-scope
  guard confirmed untouched)
- `grep -rn "task 874\|task #874" lua/` — no match (no-task-references rule honored)
- Diff scope: only `sync.lua` modified in `lua/`; `which-key.lua` and `himalaya/utils/cli.lua` remain
  unstaged, untouched pre-existing user work
- Files verified: Yes

## Notes

- Follow-ups flagged in the plan (out of scope here, not actioned): (1) the analogous stale guard in
  `M.update_artifact_from_global` at ~line 1422 (single-artifact update entry point), (2) `lib`/`tests`
  having no durable core-store source at all (the exclusion added here prevents a misleading self-copy
  but does not make them restorable if ever repopulated), (3) no context file documents the
  `core_source_base` vs `base_dir` read/write split.
- The live `<leader>al` regeneration inside this repo (the actual user-facing fix) was not exercised
  interactively as part of this task, per the testing constraint prohibiting any sync target against
  the real `.claude` tree. All verification was performed at the `scan_all_artifacts` layer against
  scratchpad fake dirs, which is where self-load behavior actually differs. A live `<leader>al` check
  in this repo remains a reasonable user-performed follow-up to confirm end-to-end.
- Scratchpad harness artifacts (`/tmp/.../scratchpad/874_impl/`) are ephemeral and not committed, per
  the plan's Artifacts & Outputs section.
