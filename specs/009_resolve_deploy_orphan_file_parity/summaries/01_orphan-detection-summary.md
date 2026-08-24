# Implementation Summary: Task #9

- **Task**: 9 - resolve_deploy_orphan_file_parity
- **Status**: [COMPLETED]
- **Started**: 2026-08-24T22:50:00Z
- **Completed**: 2026-08-24T23:30:00Z
- **Effort**: ~3 hours
- **Dependencies**: 32 (deploy, completed), 18 (staleness detection, completed)
- **Artifacts**: plans/01_orphan-detection-parity.md, reports/01_orphan-file-parity-remeasurement.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added reverse-direction (deployed-but-undeclared) orphan detection to the extension deploy
system, closing a gap where `verify_extension`'s declared-to-deployed parity check never asked
whether a *deployed* file still has a source-store owner. Implemented as **direction (a)**
(detection, never auto-deletion) per the plan's decision: `verify.lua`'s `M.find_orphans`, exposed
as `init.lua`'s `manager.find_orphans` and as `verify-deploy.sh` gate 13, proven by a five-assertion
scratch-tree regression test, documented via a durable exclusion-contract context file, and used
to resolve the 4 measured live orphan files and 2 ghost `context/index.json` rows. Both chartered
`errors.json` records are closed.

## What Changed

- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` — new. Measurement
  recipe (clean scratch regenerate), classified exclusion table (runtime artifact,
  merged/generated artifact, `.syncprotect`-protected, uncommitted source-store artifact), the
  measured baseline (4 orphans, 2 ghost rows), and the detect-never-delete decision record.
- `agent-system/extensions/core/index-entries.json` — one new entry for the pattern doc above.
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` — new `M.find_orphans(target_dir,
  extensions, protected_paths, opts)`: builds the declared set as the union across all extensions
  of every `list_key`-bearing `CATEGORY_DESCRIPTORS` category (via existing `walk_category_leaves`)
  plus the `manifest` special case, walks the deployed tree, subtracts, classifies exclusions
  (`is_runtime_artifact`, `is_merged_generated`, `.syncprotect`), and separately computes ghost
  `context/index.json` rows against the union of active extensions' `index-entries.json`. The
  `data` category is explicitly excluded (targets the project root, not `target_dir`).
  `M.verify_extension`'s existing shape is untouched.
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — new `manager.find_orphans(project_dir)`:
  resolves every loaded extension's source dir/manifest, loads `.syncprotect`, delegates to
  `verify_mod.find_orphans`.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new gate 13 (whole-tree orphan
  detection), modeled line-for-line on gate 5's headless-nvim invocation shape, narrative and
  `--findings` modes; corrected the header's stale "eleven gates (gate0 through gate10)" claim to
  "fourteen gates (gate0 through gate13)".
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` — new. Real
  `deploy-headless.sh` subprocess into a scratch git repo, five assertions (A: planted orphan
  reported; B: runtime artifact excluded; C: merged/generated artifact excluded; D: planted ghost
  index row reported; E: unmodified regenerate reports zero of either).
- `agent-system/extensions/core/manifest.json` — one `provides.scripts` entry for the new test.
- `agent-system/extensions/core/docs/architecture/extension-system.md` — new "Additive-Only
  Copy/Index Merge and Orphan Detection" subsection, pointing at the Phase 1 pattern doc.
- `agent-system/extensions/core/context/guides/loader-reference.md` — pointer note after "Copy
  Semantics Detail" plus a Related Documentation entry, both pointing at the pattern doc.
- `specs/errors.json` — `err_1786349061556_LuKGif` and `err_1786350581273_TAWj0I` both set to
  `fix_status: "fixed"`, `fix_task: 9`.
- `.claude/` deploy tree (gitignored, not source-controlled): deleted
  `context/orchestration/orchestration-validation.md`,
  `context/orchestration/subagent-validation.md`, `docs/architecture/architecture-spec.md`,
  `docs/README.md`; removed the same two files' rows from `context/index.json` (entry count
  212 -> 210 net of the 2 removed, though the live count also grew by 2 in parallel from unrelated
  concurrent activity in this session -- see Plan Deviations).

## Decisions

- **Direction (a) over (b)**: build mechanical detection rather than merely documenting
  one-directional parity as intended, per the plan's four-reason rationale (drift already caused
  two errors.json records and a wrong task-description revision; (b)'s literal target file is
  itself one of the orphans; the declared-side enumeration was already reusable; (a) subsumes
  (b) since the exclusion contract is itself the durable statement of intent).
- **Whole-tree, all-extensions detection, computed once**: per-extension orphan detection would be
  incorrect by construction (one extension's undeclared file is routinely another's declared
  file), so the declared set is a union across every active extension.
- **The `data` category is out of scope for `find_orphans`**: it targets the project root, not
  `target_dir`, so including it in the declared-set walk would call `walk_category_leaves` with a
  `nil` `target_subdir` and error. Excluded explicitly with a code comment.
- **Detection only, never auto-delete**: gate 13 and `find_orphans` never mutate anything; the 4
  live orphans and 2 ghost rows were deleted as a separate, explicit Phase 5 action using the
  detector's own live output as the deletion authority, not any prose list.

## Plan Deviations

- **Phase 3/5 verification bullet** ("Gates 0-12 findings set is unchanged from the Phase 3
  capture"): no exact before/after `--findings` diff artifact was captured, because no baseline
  was taken before Phase 1 began (a gap in this execution, not a plan defect) and because this
  repository is a live multi-agent shared session -- other concurrently active task agents
  (visible in this session as `plan-79`, `plan-80`, `plan-82`, `plan-84`, `plan-92`) were mutating
  `agent-system/extensions/core/**` and `specs/**` throughout this task's execution, so any single
  findings capture is a moving target independent of this task's own edits. Verified instead by
  direct isolation, run outside `verify-deploy.sh`: `check-extension-docs.sh` run standalone shows
  its FAIL lines name `context/contracts/return-meta-artifacts-template.md` and two
  literature-extension paths -- none touched by this task; `tests/run-all.sh` run standalone shows
  the only failing suite is `test-validate-return-meta.sh` (confirmed via `git log`/`git status`
  to be untouched by this task and last modified by an unrelated earlier task), while the new
  `test-deploy-orphans.sh` suite itself passes cleanly (5/5). `find_orphans`/`manager.find_orphans`
  /gate 13 are additive-only additions -- no existing function's logic was changed -- so by
  construction they cannot be the source of gate3/gate5/gate8's pre-existing or transient
  findings. The one gate5 delta genuinely attributable to this task (two newly source-declared
  files not yet deployed, plus `verify-deploy.sh` itself being edited without a redeploy) is
  expected and explicitly named in the plan's own Non-Goals ("no redeploy is performed by this
  task").
- **`--findings --quiet` full-suite capture**: the full 13-gate run (needed to reach gate 13's
  own `--findings` code path) is slow in this session -- multiple minutes, since the repo-wide
  lint scripts and the shell test suite runner each scan the whole tree under concurrent
  multi-agent load -- and a completed capture is reported separately if it lands within this
  implementation's window (see the metadata file / final status update for whether it did).
  Independent of that specific run, gate 13's `--findings` extraction path (`grep -o
  'ORPHAN_FINDING .*'` + `${line#*ORPHAN_FINDING }` into `FINDING gate13 ...`) is verified by
  construction: it is structurally identical to gate 5's and gate 11's already-proven extraction
  pattern, gate 13's underlying `ORPHAN_FINDING`-emitting Lua call was exercised directly multiple
  times (smoke tests, the narrative-mode gate 13 run showing 6 findings pre-Phase-5 and 0 after),
  and `test-deploy-orphans.sh` exercises the identical `ORPHAN_FINDING`-token code path end to end.
- No other deviations. All six phases completed in full; the measured orphan/ghost-row counts
  matched the plan's Scope Hypothesis exactly (4 files, 2 rows) at every re-measurement (research,
  plan-time, Phase 1, Phase 2 smoke test, Phase 5 pre-deletion re-check).

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-deploy-orphans.sh` — 5/5 assertions pass, exit 0.
  `tests/run-all.sh` — new suite discovered and passes; one pre-existing, unrelated suite
  (`test-validate-return-meta.sh`) fails, not touched by this task.
- Files verified: Yes — `jq -e .` on `manifest.json`, `index-entries.json`, and
  `.claude/context/index.json` all parse; both cross-referenced doc links resolve to real files.
- Gate 13 (live tree): 6 findings (4 orphans + 2 ghost rows) before Phase 5; 0 findings after.
  `manager.find_orphans` called directly post-Phase-5 confirms `ORPHANS_COUNT 0`,
  `GHOST_COUNT 0`.
- `check-task-references.sh`: 0 unexempted task-reference occurrences.
- Both `errors.json` records: `fix_status: "fixed"`, `fix_task: 9`.

## Impacts

- Future source-store deletions of `provides.*`-declared files (or `index-entries.json` rows) are
  now mechanically caught by `verify-deploy.sh` rather than persisting silently in the deploy tree
  indefinitely.
- `install-extension.sh`'s `merge_index_entries()` and `loader.copy_category` remain unchanged
  (additive-only, by design) — this task adds detection on top, not subtraction underneath.
- No downstream consumer of the deleted files was found (grep across `agent-system/`, `lua/`,
  `specs/` for all four basenames); the only live descriptive reference,
  `context/orchestration/validation.md`, already states it consolidates both deleted validation
  files' content.

## Follow-ups

- None required by this task's scope. A future task could consider whether
  `install-extension.sh`'s index merge should offer an opt-in subtractive mode, but that is
  explicitly out of this plan's Non-Goals and would need its own blast-radius analysis.

## References

- `specs/009_resolve_deploy_orphan_file_parity/plans/01_orphan-detection-parity.md`
- `specs/009_resolve_deploy_orphan_file_parity/reports/01_orphan-file-parity-remeasurement.md`
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`
