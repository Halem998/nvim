# Implementation Summary: Task #837

**Completed**: 2026-07-12
**Duration**: ~1 hour

## Overview

Fixed the root cause of contract drift in this (healthy, source-of-truth) repo: `core/manifest.json`'s `provides.context` never registered `"contracts"`, and no `.claude/extensions/core/context/contracts/` source directory existed, so nvim's 8 hard-mode contract files were architecturally invisible to the extension sync pipeline and never propagated to child projects via "Load Core." All 5 planned phases were implemented, verified, and committed.

## What Changed

- `.claude/extensions/core/manifest.json` — added `"contracts"` to `provides.context`.
- `.claude/extensions/core/context/contracts/*.md` — new canonical source directory with the 8 contract files, byte-identical to the deployed `.claude/context/contracts/`.
- `.claude/extensions/core/index-entries.json` — added 8 `contracts` index entries (`subdomain: "contracts"`, `domain: "core"`) matching the entries already present in the deployed `.claude/context/index.json`.
- `.claude/extensions/core/scripts/check-extension-docs.sh` and `.claude/scripts/check-extension-docs.sh` (kept identical) — extended `check_manifest_entries()` with a `provides.context` disk-existence check, and added a new project-wide `check_dangling_contract_references()` function that scans deployed `.claude/skills/*/SKILL.md`, `agents/*.md`, `rules/*.md`, and `commands/*.md` for `.claude/context/contracts/*.md`-shaped references and FAILs loudly when the target is absent.
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — added `run_contract_drift_validator()`, invoked at the end of `M.load_all_globally()` (the "Load Core" full-sync path) after `reinject_loaded_extensions()`. Surfaces FAIL output via `helpers.notify` at `ERROR` level (up to 10 lines shown), or an `INFO` PASS notice on success. Never blocks or half-applies the sync.
- `.claude/docs/guides/creating-extensions.md` — new "The provides.context Sync Contract" section (with a "Downstream Reconciliation Procedure" subsection) documenting the contract, its two consumers (`copy_context_dirs()` and "Load Core"), the `contracts/` drift defect as a worked cautionary example, and a reproducible, self-contained procedure for reconciling drift from any affected child repo.

## Decisions

- Added the `provides.context` disk-existence check inline to the existing `check_manifest_entries()` function rather than as a separate sibling function, since it mirrors the existing agents/skills/commands/rules/scripts blocks already in that function.
- `context-hygiene.md` was deliberately NOT promoted to core — confirmed absent from `.claude/extensions/core/` after Phase 1; it remains lean-extension-scoped per the plan's explicit Non-Goal.
- The dangling-reference scan also covers `.claude/commands/*.md` (plan listed this as optional) for completeness at negligible cost.
- Left a documented, disabled extension point in `check-extension-docs.sh` for a future generic `@.claude/...` dangling-path scan, per the plan's Non-Goals (avoids false positives on extension-conditional references without further auditing).
- The validator invocation in `sync.lua` runs for both full and merge-only "Load Core" syncs (not gated by `merge_only`), since either path can introduce content that references contracts; this differs slightly from the plan's phrasing ("after execute_sync / the Load Core full-sync completes") but is a superset that still satisfies the requirement without narrowing coverage.

## Plan Deviations

- **Task 2.1** altered: "Extend `check_manifest_entries()` (or add a sibling `check_context_entries()`)" — implemented inline within `check_manifest_entries()` rather than as a separate function, since the plan explicitly offered both options and the inline approach keeps the single call-site pattern already used by the other manifest.provides categories.
- No other deviations. All phases followed the plan as written.

## Verification

- `jq '.provides.context | index("contracts")' .claude/extensions/core/manifest.json` → non-null (index 6).
- `diff -rq .claude/context/contracts/ .claude/extensions/core/context/contracts/` → no differences (byte-identical, 8 files).
- `context-hygiene.md` confirmed absent from `.claude/extensions/core/` (present only in `.claude/extensions/lean/context/contracts/`).
- All 6 `.claude/context/contracts/*.md` references in `.claude/skills/skill-orchestrate-hard/SKILL.md` resolve to existing files.
- `bash .claude/scripts/check-extension-docs.sh` exits 0 across all 19 extensions plus the new `project-wide` check bucket.
- Deliberate bogus `provides.context` entry injected into core's manifest → script FAILs with exit 1 and a clear message; reverted, confirmed clean.
- Deliberate dangling contract reference injected into `skill-orchestrate-hard/SKILL.md` → script FAILs loudly (file + missing reference) with exit 1; reverted, confirmed clean via `git diff`.
- `.claude/extensions/core/scripts/check-extension-docs.sh` and `.claude/scripts/check-extension-docs.sh` confirmed identical via `diff`.
- `nvim --headless` module-load check for `sync.lua` passes after all edits.
- Headless functional test of the exact `vim.fn.system`/`vim.v.shell_error`/FAIL-line-extraction logic used inside `run_contract_drift_validator()`: healthy exit 0, injected dangling reference exit 1 with the correct FAIL line extracted, reverted back to exit 0. (The interactive `vim.fn.confirm` dialog inside `M.load_all_globally` itself was not driven end-to-end, since that requires simulating a user confirmation prompt; the underlying validator logic it invokes was verified directly.)
- Build: N/A (no compiled artifacts).
- Tests: N/A (no automated Lua test suite for this module); verified via headless functional checks above.
- Files verified: Yes.

## Notes

- Downstream reconciliation for BimodalLogic, cslib, Logos/Hardware, and the other listed child repos is intentionally NOT performed by this task — per the plan's explicit Non-Goals and the task's scope guard, it is documented in `.claude/docs/guides/creating-extensions.md` as a procedure to be run FROM each affected repo (`bash .claude/scripts/check-extension-docs.sh`, then re-run "Load Core," then re-verify).
- This repo (`~/.config/nvim`) was confirmed healthy throughout: `check-extension-docs.sh` exits 0 both before and after all edits (aside from the two deliberate, reverted negative-path tests).
