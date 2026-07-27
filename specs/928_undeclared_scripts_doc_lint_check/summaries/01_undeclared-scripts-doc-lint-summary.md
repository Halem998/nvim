# Implementation Summary: Task #928

**Completed**: 2026-07-27
**Duration**: ~45 minutes

## Overview

Added `check_undeclared_scripts` (Rule Q) to
`agent-system/extensions/core/scripts/check-extension-docs.sh`: a disk-driven check that walks
each extension's `scripts/` tree and fails on any file present on disk but absent from that
extension's `provides.scripts[]`, matching by full relative path, exempting `deprecated/`, and
covering all file types. The three genuine latent defects the new check exposed
(`nix/nix-context.sh`, `nix/nix-preflight.sh`, `nvim/nvim-context.sh` — three lifecycle-hook
scripts that were never declared and therefore never deployable) were resolved by populating
`provides.scripts` in the `nix` and `nvim` manifests. All edits stayed within
`agent-system/extensions/**`; nothing under `.claude/` was touched.

## What Changed

- `agent-system/extensions/core/scripts/check-extension-docs.sh` — added `check_undeclared_scripts()`
  (Rule Q), its rule-letter index entry, and its registration in the per-extension check loop
  immediately after `check_undeclared_rules()`.
- `agent-system/extensions/nix/manifest.json` — `provides.scripts` populated with
  `["nix-preflight.sh", "nix-context.sh"]` (was `[]`).
- `agent-system/extensions/nvim/manifest.json` — `provides.scripts` populated with
  `["nvim-context.sh"]` (was `[]`).
- `specs/928_undeclared_scripts_doc_lint_check/summaries/01_undeclared-scripts-doc-lint-summary.md` (new, this file).

## Decisions

- Matched Rules A/H's `fail`-based reporting style rather than the `advisory()`/`orphan_report()`
  helpers, per the plan's explicit instruction — an undeclared script is a hard defect (it can
  never deploy), not an advisory.
- Resolved the trailing-slash gotcha the research flagged: the per-extension loop's `ext_path`
  carries a trailing slash, so the prefix-strip normalizes it first
  (`local ext_path_norm="${ext_path%/}"`) before matching against `find`'s output — an unnormalized
  strip would have produced a double-slash prefix that never matches, degrading the check to a
  false-positive-on-everything failure mode.
- Resolved the three baseline findings by declaring the files in `provides.scripts`, per the
  research's empirical loader trace (no deploy path ever reads a `hooks`-object-referenced script
  directly) — never by adding a `hooks`-object exclusion to Rule Q, which would have silenced a
  real defect class rather than fixed it.

## Plan Deviations

- **Task 3.1** (Phase 3, "confirm exit 0 with all extensions PASS") altered: the full-tree
  doc-lint run exits 1, not 0. `core` FAILs with 2 Rule F ("deployed script content drift") hits:
  `scripts/check-extension-docs.sh` (self-drift — the deployed `.claude/scripts/` copy no longer
  matches the now-edited source, an unavoidable byproduct of touching the doc-lint script's own
  source under this task's Non-Goal barring any `.claude/` edit or regeneration step) and
  `scripts/roadmap-integration.sh` (a pre-existing, unrelated drift introduced by a concurrent
  sibling task's source edit — commit `f9d29bff3`, landed minutes before this task's Phase 1
  commit — entirely outside this task's declared `file_scope`). Rule Q's own 3 baseline findings
  are fully resolved (0 remaining `NOT in provides.scripts` lines), and both `nix` and `nvim` are
  back to PASS, which is what this task owns and what Phase 2 verified.
- **Task 3.2** (probe-injection liveness check) altered: since the baseline itself is non-zero
  (see above), liveness was demonstrated via a FAIL-count delta rather than a return to exit 0.
  Injecting an empty scratch file at
  `agent-system/extensions/nix/scripts/.scratch-probe-928.sh` moved the total FAIL count from 2 to
  3, with a new `NOT in provides.scripts` line naming the probe file; removing it returned the
  count to exactly 2 (byte-identical to the pre-probe baseline). This proves Rule Q actively runs
  and detects an injected undeclared file — the property the probe step exists to verify — even
  though the surrounding exit code stays non-zero for unrelated reasons.

## Verification

- Build: N/A (bash script; `bash -n` syntax check passed)
- Tests: Passed — Phase 1's scope hypothesis (exactly 3 findings, matching all 3 expected paths),
  Phase 2's manifest-fix re-verification (0 remaining Rule Q findings, both `jq empty` calls
  succeed, `nix`/`nvim` back to PASS), and Phase 3's full battery (probe-injection liveness,
  `literature`'s `deprecated/`-exempt + `tests/`-in-scope confirmation, `git status --short`
  source-store-only audit, task-citation grep) all passed as designed.
- Files verified: Yes — both manifests are valid JSON; `check-extension-docs.sh` parses clean
  under `bash -n`.
- **Actual full-tree run** (`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`):
  `EXIT=1`, `FAIL: 2 issue(s) found`. Extension table: every extension PASS except `core`
  (`nix` and `nvim` both PASS). The 2 `core` FAILs are the Rule F content-drift items described
  above — Rule Q itself contributes zero findings post-fix.

## Residual Gaps (disclosed, not fixed — out of scope)

1. **Lifecycle-hook runtime gap** (anticipated by the plan): even with `nix-preflight.sh`,
   `nix-context.sh`, and `nvim-context.sh` now declared in `provides.scripts`, the `nix`/`nvim`
   lifecycle hooks still will not fire at runtime, for two independent reasons in
   `skill-base.sh`: (a) `skill_run_extension_hook` resolves `hook_path` under
   `.claude/extensions/<name>/`, a location no deploy path ever populates with a `scripts/`
   subtree; and (b) `skill_get_extension_dir` queries `.claude-extensions.json` for a
   `.loaded_extensions[]` key the live file's schema does not have. Both are outside this task's
   declared `file_scope`; the choice between "hook reads from the flat `.claude/scripts/`
   directory" and "a new deploy step populates `.claude/extensions/<name>/scripts/`" is a design
   decision this task does not own. **Warrants a follow-up task against `skill-base.sh`.**
2. **Core Rule F self-drift** (not anticipated by the plan, discovered during Phase 3): any
   future source-store edit to `check-extension-docs.sh` itself will always register as a Rule F
   "deployed script content drift" FAIL for `core` until someone runs the deploy-tree
   regeneration (`<leader>al` "Sync all (replace existing)" or `scripts/deploy-headless.sh`) —
   which this task's Non-Goals explicitly forbid performing here. This is a structural
   characteristic of Rule F (it treats `core`'s own scripts identically to every other
   extension's, unlike Rule O's ADVISORY treatment of a *missing* — as opposed to *drifted* —
   core deployment), not a defect introduced by this change, but it is worth naming so a future
   reader does not mistake the current non-zero exit for a regression in Rule Q.
3. **Unrelated sibling drift**: `scripts/roadmap-integration.sh`'s deployed-vs-source drift was
   introduced by a different, concurrently-running task (commit `f9d29bff3`) and is unrelated to
   this task's `file_scope`; it was left untouched.
