# Implementation Summary: Task #864

**Completed**: 2026-07-15
**Duration**: ~6 phases across a single session

## Overview

Extended the deployed-vs-source drift check in `check-extension-docs.sh` into a hard,
blocking gate enforcing "every deployed file under `.claude/` traces to a manifest-declared
source," after first repairing a live symlink-deploy regression and backfilling all 23
deployed-only orphans into their correct owning extensions (core, literature, nvim). The gate
now exits non-zero on any unsourced deployed file or broken deployed symlink, and exits 0 on
the current, remediated tree.

## What Changed

- `agent-system/extensions/core/scripts/install-extension.sh` / `.claude/scripts/install-extension.sh` — fixed the hardcoded symlink relative target (`../extensions/$EXT_NAME/...` → `../../agent-system/extensions/$EXT_NAME/...`) at all 5 creation sites, byte-identical dual-write.
- 19 broken cslib/literature/pr-review symlinks under `.claude/{agents,commands,skills}/` deleted and recreated against the corrected path; 2 dead zotero symlinks deleted (no recreation — no `zotero` extension exists).
- `agent-system/extensions/core/{rules,commands,scripts}/` — 4 new core sources: `no-task-references-in-deliverables.md`, `commands/README.md` (content rewritten — no longer stale-claims `.claude/commands/` is a deprecated mirror of `.opencode/commands/`), `lint/lint-contract-compliance.sh`, `validate-handoff.sh`; `agent-system/extensions/core/manifest.json` updated.
- `agent-system/extensions/literature/{scripts,context}/` — 8 new literature sources (6 scripts, 2 context patterns) plus `context/guides/literature-organization.md` moved under literature's own tree; `agent-system/extensions/literature/manifest.json` updated (new `"guides"` context entry, 6 new scripts entries).
- `agent-system/extensions/nvim/context/project/neovim/domain/extension-deploy-modes.md` — new source, content extended with a "Relative-path fragility (regression precedent)" section.
- `agent-system/extensions/core/context/{patterns,guides}/` — 4 new/backfilled sources: `batch-drain-loop.md`, `context-protective-lead.md`, `topic-assignment-pattern.md`, `hard-mode-routing.md`.
- `.claude/context/patterns/fork-patterns.md` — deleted (byte-identical duplicate of pre-existing `agent-system/extensions/core/docs/fork-patterns.md`); its stale `context/index.json` metadata entry removed alongside it.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` / `.claude/scripts/check-extension-docs.sh` — added `check_flat_category_orphans` (Rules J/K/M: agents, commands, scripts), `check_context_orphans` (Rule L, recursive, `merge_targets`-aware), and `check_broken_deployed_symlinks` (Rule N), all routed through a shared `orphan_report()` helper gated by `ORPHAN_GATE_MODE` (landed advisory in Phase 5, promoted to `hard` by default in Phase 6). Added a Rule A-N index block to the header comment.
- `.github/workflows/check-extension-docs.yml` — new minimal CI wiring (no prior CI/precommit hook existed anywhere in the repo).

## Decisions

- **`literature-organization.md` ownership**: moved to literature's own `context/guides/` tree and declared a new `"guides"` context entry on literature (alongside core's pre-existing, non-colliding `"guides"` entry) — per research recommendation (a), given the filename's clear literature-domain scope.
- **`fork-patterns.md` duplicate**: confirmed byte-identical (via `diff`, empty output, matching file sizes and mtimes) to `agent-system/extensions/core/docs/fork-patterns.md`. Treated `docs/fork-patterns.md` as canonical and deleted the deployed `context/patterns/` copy — no new source created.
- **`ORPHAN_GATE_MODE` toggle design**: implemented all 5 new checks (J/K/L/M/N) to route through one shared `orphan_report()` helper controlled by a single `ORPHAN_GATE_MODE` variable (default `"advisory"` in Phase 5, `"hard"` in Phase 6), so the Phase 5→6 promotion is a single one-line default flip rather than five separate `info`→`fail` edits.
- **CI wiring**: no existing CI workflow, tracked pre-commit hook, or `core.hooksPath` configuration was found anywhere in the repo. Added a minimal `.github/workflows/check-extension-docs.yml` (checkout + run the script) rather than a local git-hooks-based solution, since `.git/hooks/` is untracked and setting `core.hooksPath` would require a local git-config change (out of scope per the git safety protocol). The workflow is a plain tracked-file addition; it was not pushed.

## Plan Deviations

- **Phase 1** (altered): re-running `install-extension.sh` triggered its `merge_index_entries` side effect, which transiently dropped one unrelated pre-existing `context/index.json` entry (`project/neovim/domain/extension-deploy-modes.md`) during the cslib merge step, for reasons not fully root-caused (a faithful sandbox replica of the same jq logic did not reproduce the drop). Detected via a full before/after path diff of `context/index.json`; manually restored the exact original JSON object rather than debugging `merge_index_entries` itself, since that function is out of this task's declared scope.
- **Phase 4** (altered): deleting the duplicate `context/patterns/fork-patterns.md` left a dangling `context/index.json` metadata entry pointing at the deleted path. Removed that stale index entry as a necessary consequence of the deletion the plan explicitly calls for, to avoid introducing a new dangling-reference regression.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: `bash .claude/scripts/check-extension-docs.sh` exits 0 on the real tree; a git-tracked-then-reverted throwaway orphan file was confirmed to produce a non-zero exit (Rule K FAIL) before being removed; scratchpad fixtures (never the real tree) confirmed orphan/broken-symlink detection, non-flagging of correctly-sourced files including nested `scripts/` subpaths, exclusive broken-symlink routing (no double-reporting), and the `ORPHAN_GATE_MODE=hard` promotion behavior.
- Files verified: all new/backfilled source files confirmed byte-identical to their deployed counterparts via `diff`; both `install-extension.sh` copies and both `check-extension-docs.sh` copies confirmed byte-identical via `diff`.

## Notes

- The orphan gate's enumeration method (`git ls-files`) only sees git-tracked files by design (matching the research report's method and explicitly documented risk mitigation) — a newly-created but not-yet-`git add`ed deployed file will not trip the gate until it is staged/tracked. This is the same tracked-tree assumption any CI/precommit gate in this repo would operate under.
- `check-extension-docs.sh` lints itself: all new source files and manifest entries added in Phases 2-4 were required to (and do) satisfy the pre-existing `check_manifest_entries` check before Phase 5's new checks could report a clean baseline.
