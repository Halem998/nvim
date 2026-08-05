# Implementation Plan: Task #980

- **Task**: 980 - One deploy engine: idempotent manifest-driven load, wipe+regenerate, full-category verification
- **Status**: [IMPLEMENTING]
- **Effort**: 15 hours
- **Dependencies**: 966 (verify-deploy baseline/delta semantics) — COMPLETED, constraint satisfied
- **Research Inputs**: specs/980_consolidate_deploy_to_single_engine/reports/01_consolidate-deploy-engines.md
- **Artifacts**: plans/01_consolidate-deploy-engines.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent engines currently write `.claude/`/`.opencode/`: the manifest-driven loader
(`lua/neotex/plugins/ai/shared/extensions/loader.lua` + `init.lua`) and the glob+allow-list
`load_all_globally` path in `picker/operations/sync.lua` that `deploy-headless.sh` drives. The
manifest-driven engine is correct but unreachable for an already-loaded extension; the
`load_all_globally` engine is reachable but silently drops every `provides.scripts` /
`provides.hooks` entry that names a subdirectory path. This plan retires the second engine,
makes the first idempotently re-runnable, gives it a correct wipe+regenerate sequence with
preserved-state snapshotting, and extends post-load verification to declared-vs-deployed parity
with content-hash equality over all 11 `provides.*` categories. Done means: one engine, one bulk
entry point shared by the picker and the headless script, and a scratch-tree regression test that
proves a newly declared `scripts/lib/` file lands on both a fresh deploy and a resync.

### Research Integration

The research report confirmed all six root causes with file:line evidence and supplies three
findings this plan builds on directly:

- `manager.regenerate` (`init.lua:943-1035`) and `settings_backup.backup`
  (`settings_backup.lua:46-68`) both exist with **zero callers**. The gap is wiring and ordering,
  not missing mechanism — this plan wires them rather than writing new equivalents.
- A **third** bulk-resync path exists beyond the two named in the task description: the picker's
  "Reload All" (`picker/init.lua:127-260`) reimplements a Kahn's-algorithm unload-all/load-all
  cycle using `exts.unload`/`exts.load` directly. The plan consolidates all three onto one
  `manager`-level entry point rather than leaving a survivor.
- The exact copier divergence table (11 functions; return arity 2/3/4; symlink guard in 2 of 11;
  `preserve_perms` hardcoded per category) — reproduced as the acceptance checklist for Phase 2.

Two gaps the report flagged for planning-time resolution were closed before writing this plan:

- **`verify-deploy.sh --findings` contract** (the dependency's output): the script emits
  normalized one-per-line `FINDING <gate> <text>` records via a `fail`-adjacent
  `FINDINGS_LIST` accumulator, with an optional override argument for messages embedding a
  numeric count. Phase 7's new findings MUST be emitted through that same accumulator so a
  pre-existing failure is absorbed by the pre/post baseline diff instead of deferring a
  multi-task batch.
- **Whether any current `verify_*` function hashes content**: none do. `verify.lua` has
  `file_exists`, `dir_exists`, `read_json`, and a single substring fingerprint check inside
  `verify_section_injection`. Content-hash equality is entirely new work, not an extension of an
  existing mechanism.

### Prior Plan Reference

No prior plan. Two abandoned predecessor tasks are subsumed; their verification bars are
preserved verbatim in `## Testing & Validation` below.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- One deploy engine (the manifest-driven loader), reachable both interactively and headlessly.
- `manager.load` re-runnable against an already-loaded extension without unload.
- One `manager`-level bulk entry point shared by the picker and `deploy-headless.sh`; the
  `load_all_globally` path, the dead `is_load_all` branch, and the picker-local "Reload All"
  reimplementation all retired onto it.
- A correct `--wipe` sequence: snapshot -> wipe -> regenerate -> restore-as-merge-base ->
  re-apply settings fragments -> clear staging, with `.syncprotect`-listed paths surviving.
- One table-driven copier so the symlink guard and permission handling hold for every category
  by construction.
- Declared-vs-deployed parity plus content-hash equality for every `provides.*` category.
- A scratch-tree regression test that would have caught the original defect.

**Non-Goals**:

- Changing manifest schema or the `provides.*` category vocabulary.
- Changing `.syncprotect`'s overwrite-protection semantics (this plan *adds* snapshot/restore
  alongside them, it does not replace them).
- Reworking `verify-deploy.sh`'s gate structure or its baseline/delta mechanism — this plan
  consumes that contract, it does not modify it.
- Any edit under `.claude/**` (see Source-Store Rule below).

## Binding Constraints (carry into every phase)

- **SOURCE-STORE RULE**: deploy machinery edits target `lua/neotex/plugins/ai/**`; script and
  rule edits target `agent-system/extensions/**`. **Never `.claude/**`** — it is a gitignored,
  regenerated deploy artifact and any hand-authored file there is wiped by the next deploy.
- **DELIVERABLE RULE**: no task-number citations in any file outside `specs/**`. Use durable
  anchors — function names (`manager.resync_all`), entry names (`[Regenerate]`), script names
  (`deploy-headless.sh`), section headings. This applies to every code comment, docstring, and
  prose edit made by this plan, including Phase 8.
- **Self-modification hazard**: `deploy-headless.sh` runs inside the repo it targets and a
  running shell script re-read after in-place overwrite is undefined behavior. The script's own
  header documents this. Any change to it must preserve the "every exit path calls `exit`
  explicitly" invariant.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Collapsing 11 copiers regresses `copy_manifest` (realpath self-load skip) or `copy_data_dirs` (merge-copy to project root, different base path) | H | M | Express both as explicit table fields (`self_load_skip`, `merge_copy_only`, `target_is_project_root`), never as forced uniformity. Phase 1's harness runs before and after Phase 2 as the regression net. |
| Extending `verify.lua` to 6 uncovered categories creates new standing failures that convert multi-task `/orchestrate` into run-one-then-defer | H | H | Route every new finding through `verify-deploy.sh`'s existing `FINDINGS_LIST` accumulator so the pre/post baseline diff absorbs pre-existing failures. Phase 7 explicitly verifies a pre-existing failure does not defer. |
| Retiring `load_all_globally` breaks the only working headless deploy before its replacement is proven | H | M | Phase 6 is `atomic-batch` and depends on Phases 3+5 landing first; the replacement entry point is exercised by Phase 1's harness before the old one is removed. |
| `--wipe` loses `.syncprotect`-listed paths (e.g. `context/repo/project-overview.md`) | H | M | Phase 4 lands snapshot/restore for protected paths *before* Phase 5 wires the wipe. `--wipe` must refuse to run if the snapshot step reports failure. |
| A stale `.settings-backup/` staging dir silently reverts settings on a later regenerate | M | H | Phase 4 clears staging on successful restore and Phase 5 orders restore before the load loop so fresh merges win. |
| Wipe of `base_dir` while an interactive session holds file handles / a concurrent deploy runs | M | L | Reuse the existing `specs/.deploy-lock` mutex in `deploy-headless.sh`; do not add a second locking mechanism. |
| Self-overwrite of `deploy-headless.sh` mid-run | H | L | Phase 6 preserves the explicit-`exit` invariant; verify by reading the changed file's every exit path. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6, 7 | 5 |
| 6 | 8 | 6 |
| 7 | 9 | 6, 7, 8 |

Phases within the same wave can execute in parallel. Phases 2 and 4 touch disjoint files
(`loader.lua` vs `settings_backup.lua`); Phases 6 and 7 touch disjoint files
(`deploy-headless.sh` + `sync.lua` + `picker/**` vs `verify.lua`).

---

### Phase 1: Scratch-tree deploy regression harness [COMPLETED]

**Goal**: Author the missing test scaffold that runs a real headless deploy against a scratch git
tree and asserts a subdirectory-declared script lands. This establishes the red baseline that
every later phase is measured against.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` following the
      conventions of the existing sibling tests in that directory (`test-phase-heading-patterns.sh`
      is the closest structural model for assertion helpers). *(completed)*
- [x] Harness sets up a scratch git repo in a temp dir, points the deploy at it, and runs the real
      headless deploy — reusing `deploy-headless.sh`'s own stub-and-invoke technique
      (`nvim --headless` with `vim.fn.confirm` stubbed). *(completed: invokes deploy-headless.sh
      as a subprocess against a scratch target rather than reimplementing the stub inline, since
      the script itself already encapsulates the stub-and-invoke technique end to end)*
- [x] Assertion A (fresh deploy): a manifest-declared `scripts/lib/*.sh` entry exists in the
      deployed tree after a from-scratch deploy. *(completed)*
- [x] Assertion B (resync): the same assertion holds after a second deploy against the
      already-deployed tree. *(completed)*
- [x] Assertion C (parity): every entry of every `provides.*` category present in the source
      manifest exists in the deployed tree. *(completed: manifest-driven via jq, independent of
      verify.lua)*
- [x] Assertion D (content equality): a deliberately-staled deployed file is detected as differing
      from source. *(completed: direct `diff` check; verify.lua gains equivalent content-hash
      teeth in Phase 7)*
- [x] Record the initial red/green status of each assertion in the phase notes — this is the
      before-state the final verification compares against. *(completed, see Initial Baseline
      below)*

**Initial Baseline** (recorded at harness authorship, `bash agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`):
- Assertion A: **RED** — `scripts/lib/phase-heading-patterns.sh` missing after a fresh deploy
  (310 artifacts deployed, but the whole `scripts/lib/` subdirectory never lands).
- Assertion B: **RED** — same file still missing after a resync deploy (309 artifacts).
- Assertion C: **RED** — 22 of 204 checked entries missing (all of `scripts/lib/`,
  `scripts/lint/`, `scripts/tests/`, plus `commands/README.md`, `docs/README.md`,
  `templates/*-template.md`, `root_files/.gitignore`, `root_files/settings.local.json`,
  `context/README.md` — a broader gap than the scripts-only defect this task named, confirming
  the "6 uncovered categories" diagnosis).
- Assertion D: **GREEN** — the direct `diff` mechanic itself works (canary was seeded
  synthetically since A/B were red); this assertion validates the *mechanism*, not the product
  under test — Phase 7 gives `verify.lua` equivalent teeth as a real, non-synthetic check.
- Overall: 1 passed, 3 failed, exit 1 — matches the plan's expected-red baseline for A/B; C's
  broader-than-expected redness is additional evidence for Phase 2/6/7's scope, not a sign the
  harness is miscalibrated.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Asserts that no existing test under
`agent-system/extensions/core/scripts/tests/` references sync/loader/deploy/verify, so the harness
must be authored from scratch rather than extended. Confirm at implementation time with
`grep -rl 'load_all_globally\|manager\.load\|verify_extension\|deploy-headless' agent-system/extensions/core/scripts/tests/`
— if that returns a file, extend it instead of creating a new one.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - new harness

**Verification**:
- Harness runs to completion and reports per-assertion status without crashing.
- Assertions A and B are expected RED at this point (that is the defect). A green A/B here means
  the diagnosis is wrong — stop and re-investigate before proceeding.

---

### Phase 2: Collapse the 11 copiers into one table-driven copier [COMPLETED]

**Goal**: Replace `copy_simple_files`, `copy_skill_dirs`, `copy_context_dirs`, `copy_scripts`,
`copy_hooks`, `copy_systemd`, `copy_docs`, `copy_templates`, `copy_root_files`, `copy_manifest`,
and `copy_data_dirs` with one descriptor-driven copier so the symlink guard and permission
handling hold for every category by construction.

**Tasks**:
- [x] Define a category descriptor table with at minimum
      `{category, source_subdir, target_subdir, recursive, preserve_perms, install_once}` plus the
      three fields needed to express the two genuinely-different copiers: `self_load_skip`
      (manifest realpath self-load skip), `merge_copy_only` (copy only if absent), and
      `target_is_project_root` (data dirs land under `project_dir`, not `target_dir`).
      *(completed: `CATEGORY_DESCRIPTORS` in loader.lua, keyed by category name; `recursive` is
      expressed via `entry_kind` ("file"/"dir"/"file_or_dir"), which also captures the
      context/docs "entry may be a file or a directory" case the plan's minimal field list didn't
      separately name)*
- [x] Implement one copier consuming the descriptor, with a **uniform 4-value return**
      `(copied_files, created_dirs, skipped_count, symlink_skipped_count)` for every category.
      *(completed: `M.copy_category(category, manifest, source_dir, target_dir, protected_paths,
      opts)`, including `manifest` and `data`, both of which previously returned only 2 values)*
- [x] Make `preserve_perms` a descriptor value derived from one shared rule, not a per-call-site
      hardcode. Preserve today's effective behavior: executable perms retained for scripts and
      hooks and for any `.sh` file in any category. *(completed: `resolve_preserve_perms(mode,
      filename)` with modes "always"/"sh_only"/"none"; verified byte-identical deployed file
      listing + permission strings before/after via a direct `manager.load` scratch-tree
      comparison, see Verification below)*
- [x] Ensure `.syncprotect` `protected_paths` are honored for **every** category — including the
      manifest copy, which currently has no `protected_paths` parameter at all. *(completed: both
      `manifest` and `data` now thread `protected_paths`/`rel_path` through `copy_file` — data
      previously had no `protected_paths` parameter either, a second gap beyond the one the task
      named)*
- [x] Update all 13 call sites in `init.lua`'s copy sequence (3 of them are the same
      `copy_simple_files` function with different category arguments) to the new uniform signature
      and 4-value return. *(completed)*
- [x] Do not leave dead wrappers behind — remove the old functions rather than aliasing them.
      *(completed: `grep` confirms zero remaining references to any of the 11 old function names
      outside doc-comments)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts exactly 11 copier functions in `loader.lua` with 13 call sites in
`init.lua`'s copy sequence, and that the symlink guard is present in exactly 2 of the 11. Confirm
at implementation time with `grep -n 'function M\.copy_' lua/neotex/plugins/ai/shared/extensions/loader.lua`
and `grep -n 'loader_mod\.copy_' lua/neotex/plugins/ai/shared/extensions/init.lua`. If the counts
differ, reconcile before editing — the descriptor table must cover the actual set, not the
hypothesized one.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - descriptor table + single copier; remove 11 functions
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - copy sequence call sites updated to uniform signature

**Verification**:
- Phase 1 harness assertions C and D behave no worse than their Phase 1 baseline. *(confirmed:
  re-ran `test-deploy-propagation.sh` after this phase's edits — identical result, 1 passed/3
  failed, since Phase 2 touches Engine A (`manager.load`) and `deploy-headless.sh` still drives
  Engine B (`load_all_globally`) until Phase 6)*
- A full interactive load of one extension into a scratch tree produces the same deployed file set
  as before the change (compare deployed file listings before/after). *(confirmed: captured a
  `find . -type f -printf '%M %p\n' | sort` listing from a direct `manager.load("core", ...)`
  call against a scratch target both before and after this phase's edit — `diff` reports zero
  differences, 339 files, across the full deployed tree)*
- Executable bit is present on deployed `.sh` files in every category that had it before.
  *(confirmed by the same before/after listing diff above, since `%M` includes the permission
  string; spot-checked `hooks/guard-destructive-git.sh` and `scripts/deploy-headless.sh` both
  land `-rwxr-xr-x`)*

---

### Phase 3: Force/resync mode and one bulk-resync entry point [COMPLETED]

**Goal**: Make `manager.load` re-runnable against an already-loaded extension, and promote a
single `manager`-level bulk-resync function that the picker and the headless script will both
call.

**Tasks**:
- [x] Add `opts.force` handling to `manager.load` that bypasses **only** the already-loaded abort
      (`init.lua:253-254`). Everything downstream is already idempotent/overwrite-safe given the
      install-once root-files guard; do not add further special-casing. *(completed)*
- [x] Verify `opts.force` is not conflated with the existing `force` reference used for dependency
      loads — either reuse it deliberately with a comment naming both effects, or introduce a
      distinctly named option. Do not leave the ambiguity unresolved. *(completed: reused
      deliberately, documented inline — forcing a resync also force-resyncs already-loaded
      dependencies transitively)*
- [x] Add `manager.resync_all(opts)`: a **non-destructive** force-resync of every currently active
      extension, in dependency order. Promote the Kahn's-algorithm topological ordering out of the
      picker's "Reload All" handler into this function rather than writing a third ordering
      implementation. *(completed)*
- [x] Return a structured result (per-extension success/failure plus aggregate counts) suitable
      for both a picker notification and a headless script's stdout parse. *(completed:
      `{succeeded = {name,...}, failed = {{name=,error=},...}, total = N}`)*
- [x] Rewire the picker's "Reload All" to call `manager.resync_all`, deleting the picker-local
      unload-all/load-all reimplementation. *(completed; "Unload All" keeps its own Kahn's-sort
      copy since it's a distinct operation `manager.resync_all` doesn't perform — see phase notes)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - `opts.force` in `manager.load`; new `manager.resync_all`
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - "Reload All" rewired; local Kahn implementation removed

**Verification**:
- Loading an already-loaded extension with `force` succeeds and re-copies files (previously
  returned `false, "Extension already loaded"`). *(confirmed via direct headless call: without
  force -> `OK=false ERR=Extension already loaded: core`; with `force=true` -> `OK=true`, and a
  before/after `find -printf '%M %p'` listing diff is empty, i.e. the re-copy reproduced the same
  339-file tree byte-for-byte)*
- Loading without `force` still returns the same refusal — no behavior change on the default path.
  *(confirmed, same test above)*
- Phase 1 harness assertion B (resync) flips from RED to GREEN. **Not yet true at this phase's
  close, and this is expected, not a defect**: `deploy-headless.sh` still drives Engine B
  (`load_all_globally`) until Phase 6 rewires its default invocation to `manager.resync_all`;
  Phase 3 only fixes Engine A, which the harness doesn't exercise until Phase 6 lands. Verified
  directly instead via `manager.resync_all({project_dir=...})` against a scratch tree with
  `core` loaded: `total=1 succeeded=1 failed=0`. Re-ran `test-deploy-propagation.sh` after this
  phase — unchanged, 1 passed/3 failed, confirming no regression. This flip is deferred to
  Phase 6's own verification bullet, which already names the same assertion.
- "Reload All" from the picker still resyncs every active extension in dependency order.
  *(structurally verified: `exts.resync_all()` — the re-exported `manager.resync_all` — performs
  the same Kahn's-ordered forward pass the deleted reimplementation did, minus the destructive
  unload step; both modules load cleanly under `nvim --headless`)*

**Phase Deviation**: the plan's own Verification bullet for this phase ("Phase 1 harness
assertion B flips from RED to GREEN") is only achievable after Phase 6 rewires
`deploy-headless.sh`'s entry point — Phase 3 alone cannot make the harness (which drives
`deploy-headless.sh`) observe an Engine A fix. Recorded as a deviation rather than silently
declared satisfied; re-verified directly against Engine A instead (see above).

---

### Phase 4: Preserved-state snapshot and restore [COMPLETED]

**Goal**: Give the wipe path a correct, leak-free preserved-state mechanism covering both the
settings files and every `.syncprotect`-listed path.

**Tasks**:
- [x] Extend the settings-backup module to snapshot `.syncprotect`-listed paths alongside
      `settings.json` and `settings.local.json` — same staging directory, same lifecycle. Do not
      invent a second staging mechanism. *(completed: `M.backup` now accepts an optional
      `protected_paths` argument, staged under `{staging_dir}/protected/{rel_path}` preserving
      nested structure; `M.restore` walks that subdirectory back onto `base_dir`)*
- [x] Add an explicit staging-clear function and call it on successful restore, closing the leak
      where a stale staging dir silently re-applies on every later regenerate. *(completed:
      `M.clear_staging`, called at the end of a fully-successful `M.restore`; verified a second
      restore immediately after is a no-op — 0 files restored)*
- [x] Make `restore` report success/failure explicitly so a caller can refuse to proceed with a
      wipe when the snapshot step failed. *(already true pre-existing: `M.restore` already
      returned `(boolean success, table restored)`; preserved unchanged, now also covers the
      protected-paths branch's own read/write failures)*
- [x] Preserve `.syncprotect`'s existing overwrite-protection semantics unchanged — snapshot/restore
      is additive. *(completed: no change to `copy_file`'s protection check in loader.lua)*
- [x] Leave `settings_backup.backup` wiring to Phase 5 (this phase makes it correct; Phase 5 calls it).
      *(completed: `M.backup` has zero callers as of this phase, confirmed by
      `grep -rn 'settings_backup\.backup' lua/` matching only the module's own definition)*

**Verification evidence** (ad hoc headless round-trip against a scratch tree with a seeded
`context/repo/project-overview.md`): backup staged 3 entries (2 settings files + 1 protected
path); after deleting all three originals (simulating a wipe), restore recovered all 3 with
byte-identical content (`diff` clean); the staging directory was absent immediately after;
a second restore call reported 0 restored (no-op), confirming the leak-close requirement.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts the staging module currently backs up exactly two files
(`settings.json`, `settings.local.json`) and that `backup`, `has_backup`, and `staging_path` have
zero callers outside the module. Confirm with
`grep -rn 'settings_backup\.' lua/` before editing; a surviving caller changes the blast radius.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua` - protected-path snapshot, staging clear, explicit restore status

**Verification**:
- Snapshot then restore round-trips a `.syncprotect`-listed file byte-identically.
- Staging directory is absent after a successful restore.
- A second restore immediately after a successful one is a no-op rather than re-applying stale content.

---

### Phase 5: Correct the regenerate sequence [COMPLETED]

**Goal**: Fix `manager.regenerate`'s settings-ordering bug and wire it into a complete, correctly
ordered wipe sequence.

**Tasks**:
- [x] Move the settings restore to run **before** the per-extension load loop, so the loop's
      settings-fragment merge runs on top of restored settings and newly registered merge-source
      fragments survive. Today the restore runs after the loop and overwrites the fresh merge.
      *(completed)*
- [x] Restore `.syncprotect`-listed paths in the same pre-loop step. *(completed: same
      `settings_backup.restore` call now covers both, per Phase 4)*
- [x] Clear the staging directory at the end of a successful sequence. *(completed: inherited
      from Phase 4's `M.restore` auto-clear-on-success; no separate call needed here)*
- [x] Wire `settings_backup.backup` as the explicit first step of the wipe sequence: snapshot ->
      remove `base_dir` -> regenerate -> restore-as-merge-base -> re-apply settings fragments ->
      clear staging. *(completed: new `manager.wipe(opts)`, the one place the full six-step
      sequence is wired end to end)*
- [x] Refuse to wipe when the snapshot step reports failure; surface the refusal, do not fall
      through silently. *(completed, and hardened beyond the original ask: `settings_backup.backup`
      can throw rather than return `false` on some failures — e.g. `helpers.ensure_directory`'s
      `vim.fn.mkdir` errors on a path collision — discovered empirically by staging a file at the
      would-be staging directory path. `manager.wipe` now pcall-wraps the backup call so this
      surfaces as the same clean refusal string, not an uncaught Lua error)*
- [x] Build `manager.regenerate` on `manager.resync_all` for its load loop rather than keeping a
      separate per-extension loop — the wipe is the only thing that distinguishes it.
      *(completed: the historical "reset state to empty, reload one at a time, re-check state
      each iteration" dance is removed entirely — `state_mod.mark_loaded` unconditionally
      overwrites `state.extensions[name]`, so `resync_all`'s `force=true` loads make it
      unnecessary)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - `manager.regenerate` reordered, wipe sequence, backup wired

**Verification**:
- After a wipe+regenerate, a merge-source hook registration added since the last deploy is present
  in the deployed settings. *(confirmed: after `manager.wipe` against a scratch tree with `core`
  loaded, `settings.json`'s `.hooks` object has 7 registered event keys — the core manifest's
  merge-source hook registrations, present post-wipe)*
- After a wipe+regenerate, `settings.local.json` and every `.syncprotect`-listed path survive.
  *(confirmed: hand-edited `settings.local.json` with a `custom_hook` marker and a seeded
  `context/repo/project-overview.md` protected path both survive `manager.wipe` byte-identical —
  this is the install-once-guard-plus-restore-ordering fix working end to end: restore recreates
  `settings.local.json` BEFORE the load loop's `copy_category("root_files", ...)` runs, so its
  install-once check sees the file already present and skips overwriting it)*
- Running wipe+regenerate twice in a row produces byte-identical trees. *(confirmed: full
  `find -type f -printf '%M %p' | sort` listing diff between two consecutive `manager.wipe` calls
  against the same scratch tree is empty)*
- A simulated snapshot failure aborts before the wipe rather than proceeding. *(confirmed: staged
  a plain file at the would-be `.claude-settings-backup` staging path so directory creation
  fails; `manager.wipe` returns `false` with a descriptive refusal string, and `base_dir`'s file
  count is unchanged (339 before, 339 after) — `rm -rf base_dir` never ran)*

---

### Phase 6: Consolidate entry points; retire the second engine [IN PROGRESS]

**Goal**: Point `deploy-headless.sh` at the manifest-driven engine, add its `--wipe` flag, expose a
`[Regenerate]` picker entry, and delete the retired `load_all_globally` path and the dead
`is_load_all` branch.

**Tasks**:
- [x] Rewire `deploy-headless.sh`'s default (no-flag) invocation to `manager.resync_all` —
      non-destructive, behaviorally closest to today's intent. *(completed, WITH a
      plan-deviating correction — see "Bootstrap-safety deviation" below: the default invocation
      is `manager.load('core', {force=true})` THEN `manager.resync_all`, not a bare
      `resync_all` call alone)*
- [x] Add `--wipe` to `deploy-headless.sh` driving `manager.regenerate`'s full sequence. Document
      it in the usage text and the `--dry-run` output as explicitly destructive. *(completed:
      drives `manager.wipe`, the Phase 5 function that wires the complete snapshot -> rm -rf ->
      regenerate sequence)*
- [x] Preserve the script's existing invariants: the `specs/.deploy-lock` mutex, `--dry-run`, the
      git-repo and `nvim`-availability preconditions, and the "every exit path calls `exit`
      explicitly" self-overwrite guard. *(completed, verified by re-reading every exit path in
      the rewritten file)*
- [x] Update the script's header comments to describe the new entry points. Use durable anchors —
      function and script names — and no task numbers. *(completed)*
- [ ] Add a `[Regenerate]` special entry to the picker's entry constructor and its handler,
      wired to `manager.regenerate` behind a confirmation (it is destructive). **NOT STARTED --
      see Continuation Notes below.**
- [ ] Remove `load_all_globally` and the allow-list post-filter it depends on from
      `picker/operations/sync.lua`, plus any now-unreachable scan helpers exclusive to it.
      **NOT STARTED -- see "scan_all_artifacts non-exclusivity discovery" below, which changes
      the scope of this item.**
- [ ] Remove the dead `is_load_all` consumer sites in the picker (an Enter-key handler and four
      keymap guards) — they have no producer and are unreachable. **NOT STARTED -- see
      "is_load_all site-count correction" below.**
- [x] Confirm no surviving caller of `load_all_globally` anywhere before deleting it.
      *(completed as a reconnaissance step -- see the two discovery notes below; the deletion
      itself is deferred to the continuation)*

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts 5 `is_load_all` consumer sites in the picker and zero producers, and
that `deploy-headless.sh` is the only non-picker caller of `load_all_globally`. Confirm with
`grep -rn 'is_load_all\|load_all_globally' lua/ agent-system/` before deleting. Any additional
caller must be rewired, not orphaned.

**Scope Hypothesis reconciliation (performed)**: the hypothesized "5 `is_load_all` sites" is
**off by one — the actual count is 6**: `picker/init.lua`'s Enter-key handler (line ~111-121, the
one that calls `load_all_globally` directly) plus 4 keymap guard conditions (lines ~353, 377,
401, 425), PLUS a 6th site in `picker/display/previewer.lua` (~line 751,
`elseif entry.value.is_load_all then`) that the hypothesis's grep target (`lua/` recursively)
would have caught but the plan's prose enumeration ("an Enter-key handler and four keymap
guards") did not name. `picker/display/entries.lua` confirmed to have ZERO `is_load_all`
producer (only `is_help` and `is_reload_all` are ever set) — the hypothesis's "zero producers"
half holds exactly. All 6 sites are therefore genuinely dead/unreachable code and safe to delete
in the continuation; the count correction is recorded here rather than silently reconciled.

**Bootstrap-safety deviation (discovered during implementation, not anticipated by the plan)**:
a literal `manager.resync_all` call as `deploy-headless.sh`'s default invocation is a **critical
regression** the plan's own phrasing didn't anticipate. `manager.resync_all` only resyncs
extensions a target repo's project-root state file (`.claude-extensions.json`) already marks
`status = "active"`. The retired `load_all_globally` engine was **stateless** -- it never wrote
that state file at all, being a glob+copy mechanism with no `manager` involvement. Consequently
ANY target repo that has only ever been deployed via the old engine (the historically normal
case -- this is exactly what "Load Core" / `deploy-headless.sh` have always driven) has **no
`core` entry** in its state file, and a bare `resync_all` would silently deploy **zero files** on
such a repo's first post-consolidation run -- reproduced empirically against a from-scratch
scratch git repo before the fix (0 files) and after (339 files, correct). The fix: the default
invocation force-loads `core` first (`manager.load('core', {force=true, confirm=false, ...})`,
idempotent and safe whether or not core is already active), THEN calls `manager.resync_all` to
also refresh any other extensions the target already has active. This closes the gap while
remaining behaviorally closest to "Load All"'s historical unconditional-core-deploy intent --
arguably closer to it than a bare `resync_all` would have been. See `deploy-headless.sh`'s own
"Bootstrap safety" header section for the full rationale, written for a future reader with no
access to this plan.

**`scan_all_artifacts` non-exclusivity discovery (changes the scope of the sync.lua removal
task)**: `M.scan_all_artifacts` (and the allow-list post-filter inside it) is **NOT exclusive**
to `load_all_globally` as the plan assumed. Two other live consumers exist:
`picker/display/previewer.lua:168` (used to compute accurate preview counts for the -- also
dead, also being removed in this same phase -- `is_load_all` preview branch) and a dedicated
`picker/operations/sync_spec.lua` with 5 test cases exercising `scan_all_artifacts` directly.
`execute_sync`, `count_actions`, `audit_synced_content`, `reinject_loaded_extensions`, and
`run_contract_drift_validator` (all module-local to `sync.lua`), by contrast, ARE exclusively
called from within `load_all_globally` and become genuinely dead once it is removed -- confirmed
by grep, no other call site anywhere. **Continuation guidance**: delete `load_all_globally`
itself plus the 5 exclusively-owned helpers above; do NOT delete `scan_all_artifacts` or its
allow-list filter without FIRST also deciding what happens to `sync_spec.lua` (delete/rewrite
those 5 test cases) and confirming no other planned consumer needs it post-Phase-6 -- this is a
second, smaller decision the continuation dispatch should make deliberately rather than
inheriting by inertia. Note `previewer.lua`'s `is_load_all` branch (Task 6's "dead is_load_all
consumer sites") is being deleted in the same phase regardless, which removes `scan_all_artifacts`'s
other live caller -- so by the time this phase closes, `scan_all_artifacts` may end up
referenced only by its own spec file. That outcome is fine (a tested utility with no current
caller is not a defect) but should be a **deliberate** choice, recorded in the phase's completion
notes, not an accident of what got deleted alongside it.

**Verification performed for the completed sub-items** (see "Verification" below for the full
phase bar, most of which is deferred with the phase):
- `deploy-headless.sh --dry-run` against both a fresh and an already-populated scratch tree
  reports the new entry points ("`manager.load('core', {force=true}) -> manager.resync_all()`"
  default; "`manager.wipe() [DESTRUCTIVE...]`" for `--wipe`) and writes nothing.
- Fresh bootstrap: `deploy-headless.sh` (no flags) against a from-scratch scratch git repo
  deployed 339 files including `scripts/lib/*.sh` -- the exact defect class this task exists to
  fix, now working through the DEFAULT headless entry point rather than only through direct Lua
  `manager.load` calls.
- Resync: a second `deploy-headless.sh` run against the same now-populated tree preserved the
  canary file and reported success.
- `--wipe`: full round trip against the same tree with a hand-edited `settings.local.json` and a
  seeded `.syncprotect` path -- both survived byte-identical.
- **`test-deploy-propagation.sh` (the Phase 1 harness): all 4 assertions now PASS** (previously
  1 passed / 3 failed) -- `4 passed, 0 failed`. This is the plan's own stated Phase 6 success
  criterion for Assertions A and B, achieved.
- **This repository's own `.claude/` was redeployed** via the fixed `deploy-headless.sh` (a
  sanctioned use of the deploy mechanism itself, not a hand-edit under `.claude/**` -- see
  `.claude/rules/source-store-deploy-boundary.md`'s "the deploy/reload process... is not a
  violation" exception) to pick up the corrected script and prove the harness's deployed-copy
  resolution path (which the harness prefers over the source-store fallback) actually exercises
  the fix. `verify-deploy.sh` reports 14/15 checks passing; the one failure
  (`formats/summary-format.md` line_count mismatch) is a pre-existing, unrelated drift --
  confirmed via `git log` to predate this task by several commits and touching a file this task
  never edits.
- A real gap this redeploy surfaced and fixed: the Phase 1 harness's own new test script,
  `scripts/tests/test-deploy-propagation.sh`, was never added to the core manifest's
  `provides.scripts` list, tripping `check-extension-docs.sh`'s "script file on disk NOT in
  provides.scripts" gate. Fixed by adding the entry to
  `agent-system/extensions/core/manifest.json` and redeploying again -- doc-lint now reports
  only the pre-existing unrelated finding.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` - default retargeted, `--wipe` added, header rewritten
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - `load_all_globally` and allow-list filter removed
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - dead `is_load_all` sites removed; `[Regenerate]` handler
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - `[Regenerate]` special entry produced

**Verification**:
- `deploy-headless.sh --dry-run` reports the new entry point and does not write.
- `deploy-headless.sh` against a scratch tree deploys successfully; Phase 1 harness assertions A
  and B are GREEN.
- `deploy-headless.sh --wipe` against a scratch tree completes the full sequence and satisfies the
  Phase 5 survival checks.
- `grep -rn 'load_all_globally\|is_load_all' lua/` returns nothing.
- The picker opens without error and `[Regenerate]` is reachable by keyboard.

---

### Phase 7: Full-category verification with content-hash parity [NOT STARTED]

**Goal**: Extend post-load verification from 4 covered categories to declared-vs-deployed parity
plus content-hash equality across all 11 `provides.*` categories, without creating standing
failures that defer batch orchestration.

**Tasks**:
- [ ] Add per-category verification for the six currently-uncovered categories: `scripts`, `hooks`,
      `docs`, `templates`, `systemd`, `root_files`. Follow the structural pattern of the existing
      rules/context verifiers.
- [ ] Drive verification from the manifest's `provides.*` keys rather than a hand-maintained list,
      so a future category is covered by construction.
- [ ] Add content-hash equality: a declared source file whose deployed counterpart differs in
      content is a finding, not just a presence check. No existing verifier hashes content — this
      is new. Exempt install-once root files from hash equality (they are intentionally allowed to
      diverge) and honor `.syncprotect` exemptions.
- [ ] Route every new finding through `verify-deploy.sh`'s existing `FINDINGS_LIST` accumulator so
      the pre/post baseline diff at the inter-cycle redeploy checkpoint absorbs pre-existing
      failures. Use the optional finding-text override where a narrative message embeds a count, so
      findings stay stable across runs and diffable.
- [ ] Do not alter `verify-deploy.sh`'s gate structure, exit codes, or default-mode narrative
      output — the additive `--findings` contract must remain byte-for-byte compatible.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: Asserts 11 `provides.*` categories in the core manifest (`agents`,
`commands`, `context`, `docs`, `hooks`, `root_files`, `rules`, `scripts`, `skills`, `systemd`,
`templates`) with 6 uncovered, and that no current verifier hashes content. Confirm with
`jq -r '.provides | keys[]' agent-system/extensions/core/manifest.json` and
`grep -n 'sha256\|hash' lua/neotex/plugins/ai/shared/extensions/verify.lua`. A non-core extension
declaring a category outside this set must also be covered by the manifest-driven approach.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - manifest-driven per-category parity + content hashing

**Verification**:
- Two known-stale deployed skill definitions (`skill-orchestrate`, `skill-orchestrate-hard`) are
  reported as findings by the new content-hash check **before** a redeploy, and clean after.
- A deliberately-staled deployed file is caught; reverting it clears the finding.
- Declared-vs-deployed parity reports zero findings across all 11 categories after a clean deploy.
- A pre-existing failure present in both the pre and post baselines does **not** defer a
  multi-task batch; a newly introduced one still does.
- No previously-passing verification regresses.

---

### Phase 8: Correct the stale prose and remediation instructions [NOT STARTED]

**Goal**: Update every document and advisory string that names a retired entry point or records
the superseded mis-diagnosis.

**Tasks**:
- [ ] Rewrite the mis-diagnosis in
      `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`'s deploy-mechanism
      gap section: the missing-scripts symptom was not an already-loaded skip in the manifest-driven
      loader — the retired glob+allow-list engine never ran the script copier for anyone, and its
      top-path-segment allow-list match dropped every subdirectory-declared entry on fresh and
      resync deploys alike. State the resolution (single engine, manifest-driven, subdirectory-safe).
- [ ] Rewrite `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — its
      "Automated Exception" section is framed entirely around the retired entry point and needs a
      rewrite, not a find-replace.
- [ ] Update the user-facing error message in
      `agent-system/extensions/core/scripts/deploy-root-guard.sh`.
- [ ] Update the advisory strings in `agent-system/extensions/core/scripts/check-extension-docs.sh`
      (the largest concentration of "Load Core / Sync all" remediation text).
- [ ] Sweep the lower-priority mentions and update those that name a retired entry point:
      `orchestrate-batch-admit.sh`, `generate-context-line-counts.sh`, `task-lock.sh`,
      `docs/README.md`, `context/patterns/batch-orchestration-guardrails.md`,
      `context/standards/task-management.md`, `merge-sources/claudemd.md`.
- [ ] Run a final `grep -rn 'shared/extensions' agent-system/extensions/` sweep for the stale path
      form the task description names. The research pass found no occurrences in the core extension
      tree; confirm or find the outlier before closing this phase.
- [ ] **DELIVERABLE RULE**: every edit in this phase names durable anchors (function names, entry
      names, script names, section headings) and contains no task numbers.
- [ ] **SOURCE-STORE RULE**: all edits land under `agent-system/extensions/**`. Never `.claude/**`.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: prose

**Scope Hypothesis**: Asserts an edit set of 5 high-priority files plus 7 lower-priority sweeps.
Confirm with `grep -rln 'Load Core\|Sync all\|load_all_globally\|shared/extensions' agent-system/extensions/`
at implementation time and reconcile the list before editing; the confirmed set replaces this
hypothesis.

**Files to modify**:
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - mis-diagnosis corrected
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - rewritten around new entry points
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` - error message updated
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - advisory strings updated
- (plus the confirmed lower-priority sweep set)

**Verification**:
- No surviving reference to a retired entry point in `agent-system/extensions/`.
- The task-reference lint gate reports no new findings.
- Every changed hunk lies inside prose or a user-facing string — confirm by diff read-through.

---

### Phase 9: Execute the full verification bar [NOT STARTED]

**Goal**: Run the union of the two subsumed tasks' verification bars end to end against a scratch
tree and record the evidence.

**Tasks**:
- [ ] Declare a new script under `scripts/lib/` in a scratch manifest; run the real headless deploy;
      assert the file lands. Repeat against an already-deployed tree (resync).
- [ ] Assert declared-vs-deployed parity over the full `provides.*` surface after a single deploy
      pass.
- [ ] Deliberately stale a deployed skill definition; assert content-hash equality catches it;
      assert a redeploy clears it.
- [ ] Run the wipe+regenerate round trip: assert `.syncprotect`-listed paths and
      `settings.local.json` survive, assert a new merge-source hook registration is present after,
      and assert two consecutive runs are byte-identical.
- [ ] Assert no regression for already-correct entries — compare the full deployed file listing
      against a pre-change baseline.
- [ ] Assert the two known-stale deployed skill definitions were caught before the fix and are clean
      after.
- [ ] Record every result as evidence in the implementation summary.

**Timing**: 1.5 hours

**Depends on**: 6, 7, 8

**Verification Tier**: full

**Files to modify**:
- (none — execution and evidence capture only; harness fixes land back in the Phase 1 file if needed)

**Verification**:
- All six bar items above pass with captured evidence.
- The repository's own deploy is re-run and `verify-deploy.sh` reports no newly introduced findings.

---

## Testing & Validation

The verification bar below is the union of the two subsumed predecessor tasks' bars, preserved
verbatim in substance:

- [ ] A test declaring a new script under `scripts/lib/` runs the real headless deploy against a
      scratch tree and asserts the file lands.
- [ ] The same assertion holds for a re-sync of an already-loaded extension.
- [ ] Declared-vs-deployed parity over the **full** `provides.*` surface (not just scripts) after a
      single deploy pass.
- [ ] Content-hash equality catches a deliberately-staled deployed skill definition.
- [ ] Wipe+regenerate round-trip: protected files and `settings.local.json` survive; new
      merge-source hook registrations are present after; running it twice is byte-identical.
- [ ] No regression for already-correct entries.
- [ ] The two currently-stale deployed skill definitions (`skill-orchestrate`,
      `skill-orchestrate-hard`) are caught by the new verification before the fix and clean after.
- [ ] A pre-existing verification failure is reported loudly but does not defer a multi-task batch;
      a newly introduced one still defers.

## Artifacts & Outputs

- `specs/980_consolidate_deploy_to_single_engine/plans/01_consolidate-deploy-engines.md` (this file)
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` (new)
- Modified: `lua/neotex/plugins/ai/shared/extensions/{loader,init,settings_backup,verify}.lua`
- Modified: `lua/neotex/plugins/ai/claude/commands/picker/{init.lua,operations/sync.lua,display/entries.lua}`
- Modified: `agent-system/extensions/core/scripts/deploy-headless.sh` (plus prose sweep set)
- `specs/980_consolidate_deploy_to_single_engine/summaries/01_consolidate-deploy-engines-summary.md`

## Rollback/Contingency

- Every phase commits independently (Phases 2 and 6 as declared atomic batches), so any single
  phase can be reverted with `git revert` of its commit range without unwinding the rest.
- The highest-risk irreversible operation is `--wipe`. It is opt-in, gated behind a snapshot that
  must succeed, and never the default for either the picker or `deploy-headless.sh`. If Phase 5 or
  6 cannot be made safe, ship Phases 1-4 and 7-8 (force-resync + full verification, no wipe) —
  that alone closes the original defect class; the wipe path is an enhancement.
- If Phase 2's copier collapse proves to regress the manifest or data-dir copiers, revert Phase 2
  alone and re-attempt with those two left as explicitly named exceptions. Phases 3-9 do not
  structurally depend on the collapse, only on its uniform return shape.
- If Phase 7 produces unabsorbable standing failures, gate the new categories behind an opt-in
  flag rather than reverting, so the parity mechanism stays available while the backlog is worked
  down.
