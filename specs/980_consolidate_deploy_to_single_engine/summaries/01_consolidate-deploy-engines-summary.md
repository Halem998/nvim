# Implementation Summary: Task #980

- **Task**: 980 - One deploy engine: idempotent manifest-driven load, wipe+regenerate, full-category verification
- **Status**: [COMPLETED]
- **Started**: 2026-08-05T02:25:00Z
- **Completed**: 2026-08-05T21:45:00Z
- **Effort**: ~15 hours (across two dispatches; the prior dispatch completed Phases 1-5 and the first half of Phase 6)
- **Dependencies**: 966 (verify-deploy baseline/delta semantics) — COMPLETED, constraint satisfied
- **Artifacts**: plans/01_consolidate-deploy-engines.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Two independent deploy engines used to write `.claude/`/`.opencode/`: the manifest-driven loader
(correct but unreachable for an already-loaded extension) and a glob+allow-list `load_all_globally`
path that `deploy-headless.sh` and the picker's "Load Core" entry drove (reachable but silently
dropped every subdirectory-declared `provides.scripts`/`provides.hooks` entry). This task retired
the second engine entirely, made the first idempotently re-runnable, gave it a correct
wipe+regenerate sequence with preserved-state snapshotting, and extended post-load verification to
declared-vs-deployed parity with content-hash equality over all 11 `provides.*` categories. One
engine, one bulk entry point shared by the picker and `deploy-headless.sh`, and a scratch-tree
regression test now prove a newly declared `scripts/lib/` file lands on both a fresh deploy and a
resync.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — 11 near-identical per-category copiers
  collapsed into one descriptor-driven `M.copy_category`, table-driven by `CATEGORY_DESCRIPTORS`
  (Phase 2).
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — `opts.force` on `manager.load`;
  `manager.resync_all` (Kahn's-algorithm dependency-ordered force-resync, Phase 3); the
  regenerate-sequence ordering bug fixed (settings restore now runs BEFORE the per-extension load
  loop, not after, Phase 5); `manager.wipe` (the full snapshot → `rm -rf` → regenerate →
  restore → clear-staging sequence, Phase 5); `ensure_default_syncprotect`, auto-seeding a default
  `.syncprotect` on `core`'s first-ever load into a project that has none (Phase 9, a genuine gap
  found by the verification bar's own execution — see Deviations).
- `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua` — extended to snapshot/restore
  every `.syncprotect`-listed path alongside the two settings files, plus an explicit
  staging-clear step and pcall-hardened backup so a snapshot failure never surfaces as an
  uncaught Lua error (Phase 4).
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` — manifest-driven declared-vs-deployed
  parity plus content-hash equality across all 11 `provides.*` categories, driven by
  `loader.CATEGORY_DESCRIPTORS` (Phase 7). Content hashing uses the same line-array semantics the
  copy engine itself reads/writes (`vim.fn.readfile`-joined content), not raw bytes, avoiding a
  false-positive on any source file lacking a final trailing newline.
- `agent-system/extensions/core/scripts/deploy-headless.sh` — default (no-flag) invocation
  rewired to a bootstrap-safe `manager.load('core', {force=true})` then `manager.resync_all`
  (not a bare `resync_all`, which would silently deploy zero files on any repo only ever deployed
  via the retired engine); `--wipe` added, driving `manager.wipe` (Phase 6).
- `agent-system/extensions/core/scripts/verify-deploy.sh` — additive gate5 running
  `manager.verify_all` headlessly and routing findings through the existing `FINDINGS_LIST`
  accumulator (Phase 7).
- `lua/neotex/plugins/ai/claude/commands/picker/{init.lua,display/entries.lua,display/previewer.lua,operations/sync.lua}`
  — `[Regenerate]` special entry added (wired to `manager.wipe` behind a `vim.fn.confirm` dialog);
  `load_all_globally` and its allow-list post-filter, plus 14 exclusively-owned helper functions
  discovered by tracing every internal call chain, removed from `sync.lua`; the 6 dead
  `is_load_all` consumer sites removed from `init.lua`/`previewer.lua`; `M.scan_all_artifacts`
  deliberately kept (still exercised by `sync_spec.lua`) (Phase 6).
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` — new scratch-tree
  regression harness (Phase 1); `REPO_ROOT` resolution later made depth-independent via
  `git rev-parse --show-toplevel` (Phase 7), since a single fixed levels-up guess cannot be
  correct for both the harness's source-store and deployed invocation depths.
- 17 files across `agent-system/extensions/core/{rules,context,scripts,docs}/**` and one nvim
  extension domain doc — every stale reference to the retired engine's picker button labels
  (`"Load Core"`/`"Sync all"`) and the 11 Phase-2-retired per-category function names corrected;
  two full reference-guide documents (`loader-reference.md`, `extension-system.md`'s Loader
  section) comprehensively rewritten around the current descriptor-driven design (Phase 8).
- Two `index-entries.json` files (`core`, `nvim`) — `line_count` fields regenerated via the
  sanctioned `generate-context-line-counts.sh --write` after Phase 8's prose edits, which also
  resolved one genuinely pre-existing, unrelated finding (`formats/summary-format.md`) that had
  predated this task.

## Decisions

- **Bootstrap-safety fix to `deploy-headless.sh`'s default invocation** (Phase 6): a bare
  `manager.resync_all` only resyncs extensions a target's state file already marks active; the
  retired engine never wrote that state file, so any repo only ever deployed via it would
  silently receive zero files on the first post-consolidation run. Fixed to force-load `core`
  first, then `resync_all`.
- **`[Regenerate]` calls `manager.wipe`, not `manager.regenerate`** (Phase 6): `manager.wipe` is
  the function that performs the full destructive sequence (snapshot → `rm -rf` → regenerate);
  `manager.regenerate` alone does not remove `base_dir` first.
- **`M.scan_all_artifacts` kept as a tested-but-currently-uncalled utility** (Phase 6): still
  exercised directly by `sync_spec.lua`'s 5 test cases; removing it would have required a second,
  separately-scoped decision about rewriting or deleting those tests.
- **Content-hash equality applies to all 11 categories, not just the 7 newly-covered ones**
  (Phase 7): the plan's own Verification bullet requires catching staleness in `skills`, a
  category that was already presence-covered before this task.
- **Content hashed via line-array-joined content, not raw bytes** (Phase 7): matches the copy
  engine's own `vim.fn.readfile`/`writefile` semantics exactly, avoiding a systemic false
  positive on any source file lacking a final trailing newline.
- **`.syncprotect` auto-seeding restored via `ensure_default_syncprotect`** (Phase 9): a
  deliberate, faithful carry-over of the retired engine's own auto-seed step, not new policy —
  required because that step had no equivalent anywhere in the manifest-driven engine once it
  became the sole bulk-sync path.

## Plan Deviations

- **Phase 6 sync.lua removal scope widened**: beyond the plan's 5 named "exclusively-owned"
  helpers, tracing each one's own internal calls surfaced 9 more transitively-dead module-locals
  (`sync_files`, `detect_untracked`, `count_by_depth`, `strip_extension_sections`,
  `strip_extension_settings`, `preserve_sections`, `restore_sections`, `read_json`,
  `read_file_string`), all removed alongside the named 5 rather than left as dead code.
- **Phase 6 `is_load_all` site count corrected**: 6 sites, not the plan's hypothesized 5 — a
  `previewer.lua` preview branch the plan's prose enumeration didn't name.
- **Phase 7 uncovered-category count corrected**: 7, not 6 — `commands` (18 declared entries) was
  omitted from the plan's Scope Hypothesis; caught for free since the implementation is driven
  generically from `loader.CATEGORY_DESCRIPTORS`.
- **Phase 7/8 unanticipated bug fixes**: a copy-engine trailing-newline false positive (content
  hashing fix, see Decisions); an OSC7-terminal-escape-sequence parsing bug in
  `verify-deploy.sh`'s gate5 (fixed via unanchored `grep`, matching `deploy-headless.sh`'s own
  established pattern); `test-deploy-propagation.sh`'s `REPO_ROOT` depth-mismatch bug (fixed via
  `git rev-parse --show-toplevel`).
- **Phase 8 scope widened from 12 files to 17**: the plan's Scope Hypothesis grep pattern did not
  match the 11 Phase-2-retired per-category function names — a second, independent staleness
  class found via a broader sweep. Also found and fixed a third staleness class (two docs
  described the wipe sequence's restore step as running after `regenerate`, the pre-Phase-5 buggy
  ordering Phase 5 itself fixed).
- **Phase 9 genuine regression found and fixed**: the wipe+regenerate round-trip test itself
  surfaced that the retired engine's `.syncprotect` auto-seed step had no equivalent in the new
  engine, meaning a brand-new consuming repo could silently lose a customized
  `context/repo/project-overview.md` on its first regenerate. Fixed via `ensure_default_syncprotect`
  in `init.lua` rather than deferred, since Phase 9 found it to be a real, in-scope correctness
  defect discovered by the very verification bar the phase was executing — not a harness artifact
  that could "land back in Phase 1" per the phase's original file-scope note.

## Verification

- **Build**: N/A (Lua/shell configuration repository, no compiled build step)
- **Tests**:
  - `test-deploy-propagation.sh` (Phase 1's scratch-tree regression harness): `4 passed, 0 failed`
    (was `1 passed, 3 failed` at Phase 1 authorship) — the core defect class this task exists to
    fix is demonstrably closed, from both the source-store and deployed-copy invocation paths.
  - `sync_spec.lua` (5 cases covering `M.scan_all_artifacts`'s allow-list post-filter, the one
    piece of the retired engine's machinery kept as a tested utility): `5/5 passed`.
  - Phase 9's live scratch-manifest execution: a brand-new `scripts/lib/` entry landed on both a
    fresh deploy and a resync; full declared-vs-deployed parity (`status=passed, errors=0`,
    `scripts` checked=90 including the new entry); both `skill-orchestrate` and
    `skill-orchestrate-hard` deliberately staled, caught (`status=failed`, both errors present),
    and cleared after redeploy; wipe+regenerate round trip survived `settings.local.json` and a
    customized `context/repo/project-overview.md` byte-identically, 7 hook registrations present
    post-wipe, two consecutive `--wipe` runs produced a byte-identical file listing.
- **Files verified**: Yes — every phase's own Verification section captured direct empirical
  evidence (scratch-tree comparisons, before/after listing diffs, `manager.verify_all` output)
  rather than relying on code inspection alone.
- **`verify-deploy.sh`** (this repository's own live deploy, re-run after every phase and finally
  after Phase 9's fix): **16/16 checks, 0 failures** — a full clean pass, including the one
  genuinely pre-existing, task-980-unrelated finding (`formats/summary-format.md` line_count
  mismatch, confirmed via `git log` to predate this task) that was resolved as a side effect of
  Phase 8's required line-count regeneration.

## Impacts

- Any repository consuming this extension system's manifest-driven deploy engine now correctly
  receives subdirectory-declared `provides.scripts`/`provides.hooks` entries on both a fresh
  deploy and a resync — the exact defect class this task exists to fix.
- The picker's `[Regenerate]` entry gives interactive users a destructive wipe+rebuild path with
  the same snapshot/restore safety `deploy-headless.sh --wipe` has always had headlessly.
- `verify-deploy.sh`'s new gate5 gives every future task a full-category, content-hash-aware
  deploy-drift detector, routed through the existing pre/post-diff mechanism the inter-cycle
  redeploy checkpoint already relies on.
- A brand-new consuming repo (one that has never been deployed before) now gets the same
  `.syncprotect` default-protection guarantee an already-established repo has always had, closing
  a gap this task's own retirement of the old engine would otherwise have silently introduced.

## Follow-ups

- `M.scan_all_artifacts` and its allow-list post-filter remain in `sync.lua`, used only by
  `sync_spec.lua`'s tests and `M.update_artifact_from_global`'s blocklist path — not by any bulk
  sync entry point. Whether to keep it as a tested utility indefinitely, or eventually retire it
  alongside a rewrite of those 5 test cases, was deliberately left as a future, separately-scoped
  decision (see Phase 6's notes).
- The extension implementation agents `neovim-implementation-agent`, `nix-implementation-agent`,
  and `email-implementation-agent` still lack the no-task-references MUST-NOT bullet that
  `general-implementation-agent` and its cslib counterparts carry (a pre-existing, unrelated gap
  noted in passing while editing `no-task-references-in-deliverables.md` during Phase 8 — out of
  scope for this task).

## References

- Plan: `specs/980_consolidate_deploy_to_single_engine/plans/01_consolidate-deploy-engines.md`
  (every phase section carries its own detailed verification evidence and deviation notes)
- Research report: `specs/980_consolidate_deploy_to_single_engine/reports/01_consolidate-deploy-engines.md`
- Progress files: `specs/980_consolidate_deploy_to_single_engine/progress/phase-{1..9}-progress.json`
- Handoffs: `specs/980_consolidate_deploy_to_single_engine/handoffs/phase-{6,7,8}-handoff-*.md`
  (Phase 6 handoffs from both the original dispatch and this dispatch's continuation)
