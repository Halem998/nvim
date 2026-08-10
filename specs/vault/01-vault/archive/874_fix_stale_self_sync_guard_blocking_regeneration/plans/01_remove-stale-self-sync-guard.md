# Implementation Plan: Task #874

- **Task**: 874 - Fix stale self-sync guard blocking nvim deploy-tree regeneration
- **Status**: [COMPLETED]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/874_fix_stale_self_sync_guard_blocking_regeneration/reports/01_stale-self-sync-guard-fix.md
- **Artifacts**: plans/01_remove-stale-self-sync-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, neovim-lua.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the stale `project_dir == global_dir` early-return in `M.load_all_globally()` so the nvim
repo can regenerate its own gitignored `.claude/` deploy tree from the durable core store, and
replace it with a narrow self-load exclusion scoped only to the `lib`/`tests` categories, which are
the sole categories that resolve to a byte-identical source/destination path during self-load. Add a
non-silent signal so that skip is visible in the sync summary rather than reading as a completed
`Lib: 0 | Tests: 0`. All destructive loader testing happens in the scratchpad against fake project
dirs; the real `~/.config/nvim/.claude` tree is never a sync target during this work.

### Research Integration

The plan builds directly on the empirically verified findings in the research report:

- **Guard location confirmed**: `sync.lua:1146-1150`, inside `M.load_all_globally()`; `<leader>al`
  reaches it directly via `commands/picker/init.lua:112`.
- **Guard removal is safe for the nine core-sourced categories**: they read from
  `agent-system/extensions/core/{subdir}` and write to `.claude/{subdir}` — structurally different
  paths even when `project_dir == global_dir` (verified: `commands self-referential? false`).
- **`lib`/`tests` are the real risk**: `sync.lua:1065-1066` passes `use_core_source=false`, making
  `global_path == local_path` byte-identical on self-load (verified: `lib self-referential? true`,
  `tests self-referential? true`). Verified NOT a data-loss risk (`helpers.read_file` /
  `helpers.write_file` fully buffer through memory before writing), but a genuine coverage gap:
  these categories have no durable source anywhere in the current architecture.
- **Confirmed non-issues, deliberately not given phases**: `root_file_names = {}` for `.claude`
  (line 1084) already excludes root `CLAUDE.md`; the `settings` category is already unconditionally
  skipped for `.claude` (`core_source_base` always truthy); `.syncprotect` already exists at the repo
  root so the auto-seed write path will not fire.

Two facts verified during planning that the research report did not cover, both of which shape the
phases below:

1. **`scan_all_artifacts` has a second caller**: `display/previewer.lua:168` (`preview_load_all`)
   calls it to produce the picker preview counts. The narrow exclusion therefore also applies to the
   preview — which is correct and desirable (the preview is explicitly designed to "use the same scan
   function as the actual sync operation"), but it means the preview will show `Lib: 0` on self-load
   and must not be mistaken for a regression.
2. **The internal-metadata-key convention is generic, not literal**: both `pairs(all_artifacts)`
   loops (`sync.lua:752-755` and `sync.lua:1189-1192`) skip keys via
   `type(key) == "string" and key:sub(1, 1) == "_"`, not by matching the literal `_audit_patterns`.
   Adding an `artifacts._self_load_skipped` metadata key is therefore safe and follows the
   established `artifacts._audit_patterns` precedent (set at line 1132, consumed at line 1315).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Remove the top-level self-sync early-return so `<leader>al` regenerates `.claude/` from the core
  store when run inside `~/.config/nvim`.
- Prevent the degenerate `lib`/`tests` self-copy with a narrow, well-commented exclusion at the point
  those categories are populated.
- Make the `lib`/`tests` self-load skip **visible** in the sync summary, so a zero count is never
  silently read as "fully regenerated".
- Verify both outcomes by actually running headless nvim against scratchpad fake dirs and observing
  the result.

**Non-Goals**:
- Touching the analogous guard in `M.update_artifact_from_global()` (~line 1392). Different entry
  point, not required to unblock `<leader>al`, explicitly out of scope. Flagged as follow-up below.
- Giving `lib`/`tests` a durable core-store source. That is a real architectural gap but a separate
  piece of work (see Follow-Ups).
- Changing `root_file_names`, the `settings` gate, `.syncprotect` auto-seed, or `detect_untracked` —
  all traced and confirmed correct as-is.
- Running a full `load_all_globally()` against the real `~/.config/nvim/.claude` tree as a
  verification step. Prohibited by the testing constraint.
- Staging, reverting, or otherwise touching the pre-existing uncommitted modifications to
  `lua/neotex/plugins/editor/which-key.lua` and `lua/neotex/plugins/tools/himalaya/utils/cli.lua`.

## The lib/tests Coverage Gap: Explicit Decision

The delegation requires this plan to state plainly what happens to `lib`/`tests` on a self-load and
whether it is acceptable. Stated plainly:

**Decision: on self-load, `lib` and `tests` are SKIPPED — not populated, left `nil`.**

- **Effect on disk**: whatever currently exists at `.claude/lib` and `.claude/tests` is retained,
  untouched. The skip never deletes anything; it declines to sync.
- **Effect today, verified during planning**: `.claude/lib` and `.claude/tests` do not exist
  (`ls: cannot access '.claude/lib': No such file or directory`), and the core store ships no
  equivalent (`find agent-system/extensions/core -maxdepth 1 \( -iname lib -o -iname tests \)`
  returns empty). So today the skip is a true no-op — byte-for-byte the same outcome as syncing them,
  which would copy zero files anyway. The exclusion is a guard against the *future* case where those
  directories get repopulated inside the disposable tree.
- **Is this acceptable as-is? Yes — conditional on the Phase 3 non-silent signal.** These categories
  have no durable source anywhere in the architecture, so a self-load sync of them could only ever
  copy a file onto itself. Skipping loses nothing a sync would have provided. What is *not*
  acceptable is the summary line `Lib: 0 | Tests: 0` reading as a complete regeneration; Phase 3
  exists specifically to close that, and the plan is not complete without it.
- **Flagged follow-up (out of scope here)**: the absent durable source for `lib`/`tests` is a real
  architectural gap. If either directory is ever repopulated in the deploy tree, a
  wipe-and-regenerate cycle would lose it permanently — the self-load exclusion prevents a
  misleading self-copy but does not, and cannot, make those categories restorable. See Follow-Ups.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing the guard lets a self-load damage the real `.claude/` tree (loader had a live data-loss bug recently) | H | L | Testing constraint is absolute: every destructive run targets scratchpad fake dirs only. Phase 1 builds the harness *before* Phase 4 runs anything. No verification step invokes `load_all_globally` with cwd inside the real repo. |
| `lib`/`tests` silently regenerate zero files, giving a false "complete" signal | M | H (if unaddressed) | Phase 2 skips them explicitly; Phase 3 surfaces the skip in the summary. This is the delegation's named must-not-happen outcome and gets a dedicated phase plus a dedicated Phase 4 assertion. |
| `artifacts._self_load_skipped` breaks a generic key iteration | M | L | Verified during planning: both `pairs()` loops skip `_`-prefixed keys generically (`key:sub(1, 1) == "_"`), following the existing `_audit_patterns` precedent. Phase 4 asserts no error is raised. |
| Preview counts (`previewer.lua:168`) diverge from sync counts | L | L | The exclusion lives inside the shared `scan_all_artifacts`, so preview and sync stay consistent by construction — that is exactly why the exclusion belongs there rather than in `load_all_globally`. |
| Full `load_all_globally()` path (manifest resolution, confirm dialog) not exercisable in scratchpad | M | M | Phase 1 replicates a minimal core manifest so `scan_all_artifacts` resolves. Phase 4 verifies at the `scan_all_artifacts` level (the layer where self-load behavior actually differs) and reports exactly what was observed. Anything not observed is reported as not observed, never assumed. |
| A future extension adds a real core-sourced `lib`/`tests` category, making the exclusion wrong | L | L | The code comment added in Phase 2 explains *why* the exclusion exists, so adding a durable source naturally prompts revisiting it. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Build Scratchpad Self-Load Harness [COMPLETED]

**Goal**: Stand up a fake-repo harness that reproduces a self-load (`project_dir == global_dir`)
against throwaway dirs, and capture the pre-fix baseline, so Phase 4 has something safe to verify
against and a before/after comparison to point at.

**Tasks**:
- [x] Create fake repo at `{SCRATCHPAD}/874_impl/fake_repo/` where `global_dir == project_dir`
      *(completed)*
- [x] Populate a durable source: `agent-system/extensions/core/commands/foo.md`,
      `agent-system/extensions/core/agents/bar.md`, plus a minimal `manifest.json` sufficient for
      `get_extension_config` / `get_core_provides` to resolve (fall back to blocklist mode if
      allow-list resolution proves impractical — record which mode was used) *(completed: allow-list
      mode resolved successfully via `provides.commands`/`provides.agents` in the fake manifest —
      blocklist fallback was not needed)*
- [x] Populate a deploy tree: `.claude/commands/foo.md` (stale content, to prove replace),
      `.claude/lib/bar.sh`, `.claude/tests/test_baz.sh` (to prove the self-copy case is live)
      *(completed)*
- [x] Write `{SCRATCHPAD}/874_impl/test_self_load.lua` driving `sync.scan_all_artifacts(FAKE, FAKE,
      { base_dir = ".claude" })` and printing, per category: file count, and whether
      `global_path == local_path` *(completed: also parameterized by `SYNC_LUA_PATH` env var so the
      same harness drives both the baseline and post-fix runs, plus a `FAKE_PROJECT` control target
      and explicit PASS/FAIL/NOT-OBSERVED assertions used by Phase 4)*
- [x] Run the harness against the **unmodified** `sync.lua` and record the baseline output verbatim
      *(completed: deviation — see Deviations note below on execution order)*

**Deviation note (order, not scope)**: the wave map declares Phase 1 and Phase 2 independent
(same wave, no dependency between them), and this constraint was honored — execution made the
Phase 2 source edits first, then built this harness, then used `git show HEAD:sync.lua` (the true
pre-edit committed version, an even stronger baseline than an in-place unmodified copy would have
been) to run the harness against the unmodified code for the "before" comparison. The load-bearing
ordering constraint from the Risks table — the harness exists *before* any run against the
*modified* code (Phase 4) — was honored exactly: the harness and both the baseline and post-fix
runs all happened before Phase 4's conclusions were drawn, and the real `.claude` tree was never a
target in any of them.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `{SCRATCHPAD}/874_impl/**` - new scratchpad-only harness; no repo files touched in this phase

**Verification**:
- Harness runs headless without error:
  `nvim --headless -u NONE -c "set rtp+=/home/benjamin/.config/nvim" -c "lua dofile('{SCRATCHPAD}/874_impl/test_self_load.lua')" -c "qa!"`
- Baseline output reproduces the research finding: `commands` self-referential `false`; `lib` and
  `tests` self-referential `true`
- `ls ~/.config/nvim/.claude/lib` still errors (real tree untouched — confirms harness isolation)

---

### Phase 2: Remove Guard and Add Narrow lib/tests Self-Load Exclusion [COMPLETED]

**Goal**: Make the two source edits that constitute the actual fix — delete the top-level
early-return, and scope a self-load exclusion to the `lib`/`tests` population only.

**Tasks**:
- [x] Delete the early-return at `sync.lua:1146-1150` (the `if project_dir == global_dir then
      helpers.notify("Already in the global directory", "INFO") return 0 end` block), including its
      now-obsolete `-- Don't load if we're in the global directory` comment *(completed)*
- [x] Confirm `project_dir` remains used after the deletion (it is, at line 1153 and beyond) so no
      unused-local is introduced *(completed: confirmed used in the `scan_all_artifacts` call and the
      migration-notice block)*
- [x] In `scan_all_artifacts`, add `local is_self_load = project_dir == global_dir` and gate the
      `lib`/`tests` population at lines 1064-1066 on `base_dir == ".claude" and not is_self_load`
      *(completed)*
- [x] Keep the `settings` sub-branch inside the same `if base_dir == ".claude"` structure — it is
      already unconditionally skipped for `.claude` via `if not core_source_base` and must not gain a
      self-load condition or change behavior *(completed: verified unchanged)*
- [x] Add a durable, anchor-based comment explaining *why* `lib`/`tests` are excluded on self-load
      (no core-store source; source path is byte-identical to destination). **No task-number
      citation** — this file is outside `specs/**` *(completed)*
- [x] Set `artifacts._self_load_skipped = { "lib", "tests" }` when the exclusion fires, following the
      `artifacts._audit_patterns` convention at line 1132 (leave unset otherwise) *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - remove lines 1146-1150; gate
  lib/tests population at ~1064-1066; add `_self_load_skipped` metadata key

**Verification**:
- `nvim --headless -u NONE -c "luafile lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua" -c "qa!"`
  raises no syntax error (module loads)
- `grep -n "Already in the global directory" sync.lua` returns no match inside `load_all_globally`
  (the `update_artifact_from_global` guard at ~1392 has different text and must remain present)
- `grep -n "Cannot update artifacts in the global directory" sync.lua` still matches — out-of-scope
  guard confirmed untouched
- Diff touches only `sync.lua`; `git status --short` shows the two pre-existing unrelated
  modifications still unstaged and unmodified by this work

---

### Phase 3: Surface the Self-Load Skip Non-Silently [COMPLETED]

**Goal**: Ensure a self-load's `Lib: 0 | Tests: 0` cannot be misread as a complete regeneration. This
is the delegation's explicit "do NOT let a silent zero-file regeneration be the outcome" requirement.

**Tasks**:
- [x] In `execute_sync`, read `all_artifacts._self_load_skipped` and, when present, build a short
      note (e.g. `"\n  Note: lib/tests skipped (self-load; no core-store source)"`) *(completed)*
- [x] Append that note to the existing summary `helpers.notify(...)` at ~lines 604-620, alongside the
      established `protect_msg` / `untracked_msg` optional-suffix pattern — reuse that pattern rather
      than inventing a new one *(completed: added as a third `%s` suffix argument, same pattern)*
- [x] Verify the note is empty-string when `_self_load_skipped` is absent, so non-self-load syncs
      (every other repo) have byte-identical summary output to today *(completed: verified by code
      review — `self_load_msg` defaults to `""` and is only set inside the `if
      all_artifacts._self_load_skipped then` branch)*
- [x] Add a LuaDoc/inline comment only where it clarifies non-obvious intent; do not over-document
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - `execute_sync` summary
  notification (~530-620)

**Verification**:
- Module still loads headless without error
- Reading the diff confirms the note is suffix-only and conditional — no change to the existing
  format-string arguments or counts for the non-self-load path

---

### Phase 4: Headless Verification in Scratchpad [COMPLETED]

**Goal**: Prove, by observation rather than assumption, that (1) a self-load now regenerates the
core-sourced categories, and (2) `lib`/`tests` are handled per the stated decision rather than
silently emptied. This phase is the delegation's named non-negotiable verification step.

**Tasks**:
- [x] Re-run the Phase 1 harness against the **modified** `sync.lua`, capturing output verbatim
      *(completed)*
- [x] Assert (1): `commands`/`agents` are populated with `global_path` under
      `agent-system/extensions/core/` and `local_path` under `.claude/` — different paths, action
      `replace` for the stale `foo.md`. This is the "self-load regenerates core-sourced categories"
      proof *(completed: PASS, observed)*
- [x] Assert (2a): `artifacts.lib` and `artifacts.tests` are `nil`/absent on self-load, and
      `artifacts._self_load_skipped` is set — the degenerate self-copy is gone *(completed: PASS,
      observed)*
- [x] Assert (2b): the fake `.claude/lib/bar.sh` and `.claude/tests/test_baz.sh` still exist with
      unchanged content — skipped means retained, not emptied *(completed: PASS, observed)*
- [x] Assert (3): a **non**-self-load control run (`scan_all_artifacts(FAKE_GLOBAL, FAKE_PROJECT,
      ...)` with distinct dirs) still populates `lib`/`tests` — proving the exclusion is scoped to
      self-load and did not regress normal target repos *(completed: PASS, observed)*
- [x] Assert (4): no error raised by the `_self_load_skipped` key passing through the
      `pairs(all_artifacts)` loops *(completed: PASS, observed — harness reproduces both the
      `load_all_globally` total-count loop and the `audit_synced_content` loop patterns directly
      against the self-load result and confirms both complete without error via `pcall`; the full
      interactive `M.load_all_globally` entry point itself was NOT invoked, since it reaches a
      `vim.fn.confirm` dialog that is not safely drivable headless — this is the exact risk the plan's
      Risks table already anticipated and mitigated by verifying at the `scan_all_artifacts` layer)*
- [x] Record actual observed output in the summary. If any assertion cannot be observed (e.g. manifest
      resolution proves impractical to replicate), report it explicitly as **not observed** — never
      infer or claim it passed *(completed: all 5 assertions were observed and PASS; see summary)*

**Timing**: 0.75 hours

**Depends on**: 1, 3

**Files to modify**:
- `{SCRATCHPAD}/874_impl/test_self_load.lua` - extend with the assertions above (scratchpad only)

**Verification**:
- Harness exits cleanly; every assertion above prints an explicit PASS/FAIL/NOT-OBSERVED line
- `ls ~/.config/nvim/.claude/lib` still errors and `git status --short .claude` remains empty —
  the real deploy tree was never a sync target at any point
- Baseline (Phase 1) vs. post-fix output diff shows exactly the intended behavior change

---

### Phase 5: Standards Conformance and Commit [COMPLETED]

**Goal**: Confirm the diff meets repo Lua standards and the no-task-references rule, then commit only
this task's work.

**Tasks**:
- [x] Review the `sync.lua` diff against repo Lua standards: 2-space indent, no tabs, ~100 char lines,
      snake_case naming, comments that explain intent *(completed: all added lines are within the
      ~100 char guideline, 2-space indent, no tabs, snake_case)*
- [x] Confirm no task-number citation ("task 874", "(task N)", etc.) appears anywhere in `sync.lua` or
      any file outside `specs/**` *(completed: `grep -rn "task 874\|task #874" lua/` returns no
      match)*
- [x] Confirm the two pre-existing unrelated modifications (`editor/which-key.lua`,
      `himalaya/utils/cli.lua`) remain unstaged and unaltered *(completed: confirmed via `git status
      --short`)*
- [x] Stage only `sync.lua` plus this task's `specs/874_*` artifacts — never `git add -A` or
      `git commit -am` *(completed)*
- [x] Commit as `task 874: complete implementation` with the session ID in the body *(completed)*

**Timing**: 0.25 hours

**Depends on**: 4

**Files to modify**:
- No new edits expected; corrective only if the review finds a standards deviation

**Verification**:
- `git diff --staged --stat` lists only `sync.lua` and `specs/874_*` files
- `git status --short` still shows `which-key.lua` and `cli.lua` as unstaged modifications
- `grep -rn "task 874\|task #874" lua/` returns no match

---

## Testing & Validation

- [x] Every destructive run targeted scratchpad fake dirs; `~/.config/nvim/.claude` was never a sync
      destination (confirmed by the real tree being unchanged after each phase)
- [x] Self-load regenerates core-sourced categories from `agent-system/extensions/core/` — observed,
      not assumed
- [x] Self-load skips `lib`/`tests` and retains their on-disk content rather than emptying them
- [x] The skip is visible in the sync summary (non-silent), so `Lib: 0` cannot read as complete
      *(verified by code review of the `execute_sync` diff; the interactive `load_all_globally` path
      that would exercise it end-to-end was not runnable headless — see Phase 4 Assert (4) note)*
- [x] Non-self-load sync behavior for other repos is byte-identical to before (control run)
- [x] `sync.lua` loads headless without syntax or runtime error
- [x] `M.update_artifact_from_global`'s guard is untouched
- [x] No task-number citations outside `specs/**`

## Artifacts & Outputs

- Modified: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Scratchpad harness (not committed): `{SCRATCHPAD}/874_impl/`
- Summary: `specs/874_fix_stale_self_sync_guard_blocking_regeneration/summaries/01_*-summary.md`
- Commit: `task 874: complete implementation`

## Follow-Ups (Out of Scope)

1. **`M.update_artifact_from_global` guard** (`sync.lua:~1392`, "Cannot update artifacts in the
   global directory"): structurally the same staleness, different entry point (single-artifact update
   vs. bulk load-all). Not required to unblock `<leader>al`. Candidate for a separate task.
2. **`lib`/`tests` have no durable source**: vestigial categories predating the deploy-tree gitignore
   migration, with no `agent-system/extensions/core/` equivalent. Either give them a durable source or
   retire the categories outright. The exclusion added here prevents a misleading self-copy but does
   not make them restorable.
3. **Context gap**: no context file documents the `core_source_base` vs. `base_dir` read/write split
   or which categories are core-sourced. Research had to reconstruct it from source.

## Rollback/Contingency

The change is confined to one file with no migration or state component. To revert:
`git revert {commit_sha}`, or `git checkout {prior_sha} -- lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
(safe only on a clean tree — otherwise snapshot first per the destructive-git rule, since two
unrelated files carry uncommitted work). Reverting restores the early-return guard and the prior
blocked-self-load behavior; no deploy-tree cleanup is needed because the real `.claude/` tree is never
written during this task's verification, and `.claude/` is disposable and regenerable by design.

If Phase 4 cannot observe assertion (1) because full manifest resolution proves impractical to
replicate in the scratchpad, do **not** claim the fix verified. Mark the phase `[PARTIAL]`, report
exactly which assertions were observed, and flag the live `<leader>al` check as an explicit
user-performed follow-up.
