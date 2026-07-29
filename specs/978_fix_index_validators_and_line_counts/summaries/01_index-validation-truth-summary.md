# Implementation Summary: Task #978

- **Task**: 978 - fix_index_validators_and_line_counts
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T23:00:00Z
- **Completed**: 2026-07-30T02:15:00Z
- **Effort**: ~9 hours (matching plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_index-validation-truth.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Made the context-index validation layer tell the truth end to end, across nine phases: fixed the
subshell counter-discarding bug in `validate-context-index.sh` (four defective pipelines), built
a source-store `line_count` regenerator, regenerated 320 stale/missing `line_count` values across
18 of 19 extensions, converted the index-merge function from append-only to upsert semantics
(discovered during planning to be load-bearing for the whole task), indexed the 14 previously
unreachable deployed context files, redeployed and confirmed truthful zero/zero validation, added
two new lettered gates to `check-extension-docs.sh` with working negative tests, synced
documentation, and closed with a full clean `verify-deploy.sh` run.

## What Changed

- `agent-system/extensions/core/scripts/validate-context-index.sh` — converted four
  `jq | while read` pipelines to `while ... < <(jq ...)` process substitution so `ERRORS`/
  `WARNINGS` increments reach the parent shell; honest summary wording when warnings exist;
  new opt-in `--strict` flag; added a `REPO_ROOT`-bypass preamble (matching
  `check-extension-docs.sh`'s established pattern) so the script can validate the deployed index
  from the source-store copy.
- `agent-system/extensions/core/scripts/generate-context-line-counts.sh` — new script. Computes
  `line_count` from `wc -l` for every entry across all extensions' source `index-entries.json`
  (`--check` reports only; `--write` corrects in place via surgical line-oriented `awk`
  substitution/insertion, deliberately avoiding a full `jq` round-trip that would have reformatted
  every array in files using compact-array conventions). Distinguishes a present-but-wrong
  `line_count` value (replace) from an entirely absent key (insert), the latter accounting for all
  94 entries in six previously all-null extensions (cslib, latex, lean, python, typst, z3).
- `agent-system/extensions/core/manifest.json` — declared the new script in `provides.scripts`.
- `agent-system/extensions/*/index-entries.json` (18 of 19 extensions; `epidemiology` needed no
  correction) — 320 mechanical `line_count` corrections (226 mismatches + 94 missing-key
  insertions), plus 14 new entries (11 core, 1 each email/memory/nvim) for the previously
  unindexed deployed context files.
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — `M.append_index_entries` converted from
  skip-if-exists to upsert-in-place (position-preserving); stamps `version` (`"1.0.0"`, set once)
  and `generated` (refreshed ISO8601 timestamp) on every write. Discovered and documented a
  dormant same-path collision between `core` and `lean` (three `contracts/*.md` files,
  intentional lean4-specific overrides, not accidental duplicates) as a known risk, left
  unresolved since `lean` is not currently loaded and fixing override priority is a materially
  separate feature.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — two new lettered rules: Rule R
  (`check_line_count_accuracy`, per-extension source `line_count` vs `wc -l`, catches the
  unloaded-extension-null class the deployed-index validator structurally cannot see) and Rule S
  (`check_deployed_index_orphans`, project-wide, deployed `context/*.md` vs index entries).
  Discovered mid-phase that the existing `_git_deployed_files` helper (`git ls-files`) is
  silently vacuous in this repository because `.claude/` is entirely gitignored — Rule S
  therefore enumerates the filesystem directly (`find -name "*.md"`) instead. New sibling
  severity variable `INDEX_TRUTH_GATE_MODE` (default `hard`), independent of `ORPHAN_GATE_MODE`.
- `agent-system/extensions/core/merge-sources/claudemd.md` — added the regenerator to the
  Utility Scripts list.
- `agent-system/extensions/core/context/patterns/context-discovery.md` — new subsection
  documenting `line_count`'s real consumer (`validate-context-budgets.sh`) and that it is not
  currently wired into any automated gate.

## Decisions

- Regeneration targets the SOURCE `agent-system/extensions/*/index-entries.json` files, never the
  deployed `.claude/context/index.json` directly, per the source-store/deploy boundary rule.
- `--write` mode uses surgical `awk` text substitution/insertion rather than a `jq` round-trip,
  after discovering that a full-document jq re-serialization silently reformats every array in
  files using compact-array conventions (e.g. nvim's, present's) — a 535-line diff for a 21-value
  change on first attempt, corrected before landing.
- The `core`/`lean` `contracts/*.md` path collision is documented as a known dormant risk in the
  upserting function's LuaDoc, not resolved by deleting either extension's legitimate,
  intentionally-different content.
- Rule S enumerates the filesystem directly instead of reusing `_git_deployed_files`, because
  `.claude/` is entirely gitignored in this repository and `git ls-files` against it always
  returns zero results — a latent, pre-existing vacuity in Rule L as well, left unfixed as
  explicitly out of scope for this task.
- `validate-context-budgets.sh`'s violation count is recorded as an observation only (`Violations:
  11` both before and after, with the underlying per-agent token estimates shifting as expected);
  it remains unwired from `verify-deploy.sh`, matching the stated Non-Goal.

## Plan Deviations

- **Phase 1** (altered): added a `REPO_ROOT`-bypass preamble to `validate-context-index.sh`, not
  explicitly listed in the plan's task list but required for the phase's own verification command
  to run from the source-store copy against the deployed index.
- **Phase 3** (altered): rewrote the Phase 2 generator's `--write` mode from a `jq` round-trip to
  surgical `awk` substitution/insertion after discovering the format-reformatting problem during
  this phase's own diff-review task; also discovered the 94 "null" entries are actually
  entirely-missing keys, not literal JSON `null` values, requiring an insert path distinct from
  the replace path.
- **Phase 4** (documented, not fixed): found 4 same-path collisions across extensions (3
  intentional `core`/`lean` contract overrides, 1 within-file `cslib` duplicate); none deleted or
  rewritten — documented as findings per the plan's own non-goal against rewriting context files.
- **Phase 7** (altered): Rule S built on filesystem enumeration instead of the plan-assumed
  `_git_deployed_files` helper, after discovering the helper is vacuous against this repo's fully
  gitignored `.claude/` tree.
- **Phase 8** (skipped, reasoned): `README.md`/`EXTENSION.md` script listings left untouched —
  neither enumerates scripts individually (both are abbreviated, already-stale summary counts),
  so the new script is not "left undocumented" by omission.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `bash -n` passed on all three modified shell scripts; `nvim --headless` module-load check
  passed for `merge.lua`
- Files verified: Yes — all three verification-bar criteria demonstrated empirically (see below)

**Verification-bar criteria** (all three demonstrated in Phase 9, against the freshly redeployed
tree):
1. **Truthful counts**: 58 real warnings before (0 reported); 178 entries / 0 errors / 0 warnings
   after (both default and `--strict` mode).
2. **Orphan gate bites**: scratch orphan file makes `check-extension-docs.sh` FAIL naming it;
   removing it restores PASS — verified against both the source and the deployed script copy.
3. **Exact source counts**: 458/458 entries exact across all 19 extensions'
   `index-entries.json` files (`generate-context-line-counts.sh --check` exits 0).

**Supporting gates**: `verify-deploy.sh` exits 0 (12 checks, 0 failures, including gate 3
doc-lint and gate 4 task-reference lint); `validate-extension-index.sh --check-resolution` exits
0 (Errors: 0, Warnings: 30 pre-existing/unrelated); `check-task-references.sh` reports 0
occurrences.

## Impacts

- Any future `.claude/context/index.json` corruption or drift will now be caught loudly by
  `validate-context-index.sh --strict` and by the two new `check-extension-docs.sh` gates on
  every `verify-deploy.sh` run, rather than silently passing.
- `line_count` accuracy improvements changed `validate-context-budgets.sh`'s per-agent token
  estimates (e.g. `meta-builder-agent` from 115512 to 122432 against its 15000 cap) — an expected
  side effect, not a regression; that script remains unwired from any automated gate.
- The upsert semantics change to `M.append_index_entries` means any FUTURE correction to an
  existing source index entry will now actually reach the deployed index on redeploy, closing a
  previously silent failure mode.

## Follow-ups

- The dormant `core`/`lean` `contracts/*.md` override collision has no load-order-independent
  resolution mechanism; worth a dedicated design if/when `lean` becomes a loaded extension in a
  repo that also loads `core` (always true) with divergent contract content.
- Rule L (`check_context_orphans`) in `check-extension-docs.sh` shares the same
  `_git_deployed_files`/`git ls-files` vacuity this task discovered and worked around for the new
  Rule S; Rule L itself was left unfixed as out of scope.
- Wiring `validate-context-budgets.sh` into an automated gate (and fixing its pre-existing
  `tier`-field and dead-entry findings) remains unscheduled, per the stated Non-Goal.
- `agent-system/extensions/core/README.md`/`EXTENSION.md` script-count summaries (27, 52) are
  already stale relative to the manifest's actual 83-script total, independent of this task;
  worth a dedicated pass if those counts are meant to stay accurate.

## References

- `specs/978_fix_index_validators_and_line_counts/plans/01_index-validation-truth.md`
- `specs/978_fix_index_validators_and_line_counts/reports/01_context-index-validation-truth.md`
- `specs/978_fix_index_validators_and_line_counts/progress/phase-{1..9}-progress.json`
