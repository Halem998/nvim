# Implementation Summary: Task #71

- **Task**: 71 - Fix validate-mode directory-path false positives and normalize-authors flag mismatch
- **Status**: [COMPLETED]
- **Started**: 2026-08-18
- **Completed**: 2026-08-18
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_validate-dirpath-flag-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two low-severity defects in the literature extension's `/literature --validate` path.
Defect 1: Validate Step 2's `stale_entries` check used a bare `-f` test, which is unconditionally
false for directory-path entries (book/parent-level records), producing a 100% false-positive
stale report for that schema variant and silently skipping their schema/authors-shape checks.
Defect 2: the Validate Step 4 report template told users to pass a `--dry-run` flag to
`literature-normalize-authors.sh` that the script hard-rejected with `Unknown argument`. Both
fixes are confined to the source store (`agent-system/extensions/literature/**`).

## What Changed

- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — Validate Step 2:
  replaced the two-way `-f`/else branch with a three-way branch (directory-path entries checked
  with `-d`, missing file-path entries, existing file-path entries); hoisted the schema-field and
  authors-shape `jq` checks out of the file-only branch so they run for every resolvable entry,
  directory entries included; updated the numbered prose preamble to describe existence checking
  per path-variant and scope the token-drift recount to file-path entries. Validate Step 4:
  reworded the "Authors Shape Warnings" instruction to stop naming a nonexistent `--dry-run` flag
  as a distinct mechanism, stating instead that omitting the flag (the default) previews the
  change.
- `agent-system/extensions/literature/scripts/literature-normalize-authors.sh` — added `--dry-run`
  as an explicit no-op alias in the argument-parsing `case` (alongside `--apply|--write`), and
  updated the header comment block and `usage()` output to describe the same three-way flag
  surface, for consistency with sibling scripts (`literature-repair-combining.sh`,
  `zotero-write.sh`) that already accept an explicit `--dry-run`. Default behavior (bare
  invocation = dry-run) is unchanged.
- `specs/071_fix_validate_directory_path_false_positives_and_flag_mismatch/summaries/01_validate-dirpath-flag-fix-summary.md` — this summary.

## Decisions

- Kept the alias in addition to the doc fix (per the plan's guidance) rather than doc-fix-only:
  it made `--dry-run` a safe explicit invocation independent of doc wording, consistent with two
  sibling scripts in the same directory that already accept it. No ambiguity was introduced in
  `usage()` output, so the alias was kept rather than dropped.
- Left the `jq` programs for schema-field and authors-shape checks byte-identical, only relocated
  them out of the file-only branch — per the plan's explicit instruction not to rewrite them.

## Plan Deviations

- None (implementation followed plan). One additional, previously-undocumented finding was
  discovered during Phase 3 end-to-end verification and recorded below as a new deferred item
  (see "Follow-ups" — legacy `chunks_dir`-only null-path entries); it did not require altering
  any plan checklist item, since Defect 1's fix scope was specifically directory-path entries and
  correctly leaves this distinct variant's stale reporting behavior unchanged (not a regression).

## Verification

- Build: N/A (bash/markdown source-store edits)
- Tests: N/A (no test suite for this skill)
- Files verified: Yes — `bash -n` clean on `literature-normalize-authors.sh`; the edited Validate
  Step 2 block was extracted verbatim from `SKILL.md` and executed against the live global index
  (`~/Projects/Literature/index.json`, 369 entries) both before and after the edit

### Confirmed counts (live global index, 369 entries)

| Metric | Before fix | After fix |
|---|---|---|
| `stale_entries` | 80 | 15 |
| `drift_entries` | 56 | 56 (unchanged) |
| `schema_warnings` | 35 | 35 (unchanged) |
| `authors_shape_warnings` | 53 | 60 (+7, now covering directory entries) |

- Directory-path entries in the live index: **65** confirmed via direct `-d`/`-f` classification
  of every `.entries[].path` (larger than the research report's 34, consistent with the report's
  own note that the corpus is under concurrent modification — the report separately cited the
  team lead's live run count of 65 as matching this same bug at a later corpus snapshot).
- File-path entries: **289**. Legacy null-path entries (see Follow-ups): **15**.
- Zero directory-path entries remain in `stale_entries` after the fix (all 65 correctly resolve
  as existing directories).
- The existence check was verified not weakened: a fabricated entry pointing at a non-existent
  directory (`sources/definitely_does_not_exist_xyz/`) was still correctly reported stale
  (`"... (missing directory)"`) when run through the actual extracted `SKILL.md` Step 2 block.
- `drift_entries` and `schema_warnings` are exactly unchanged from the pre-fix baseline —
  confirms file-path entry behavior was not altered by the branch restructure.
- `literature-normalize-authors.sh --dry-run` exits 0 and produces byte-identical output to the
  bare invocation; `--apply` still applies correctly (tested against a throwaway copy of the live
  index, never the live one); an unknown flag (`--bogus`) still exits 1 with
  `Unknown argument: --bogus`.
- `git status --short` after all edits shows zero `.claude/**` paths; all source edits are
  confined to `agent-system/extensions/literature/**` and `specs/071_*/**`.
- Quarantine-artifact conclusion re-confirmed: `.md.rejected`/`.md.bak-*` files remain invisible
  to both the stale check (only indexed paths are iterated; quarantine artifacts are never
  indexed) and the unindexed-file scan (`find -maxdepth 1`, which never descends into `sources/`
  where the quarantine artifacts actually live).

## Impacts

- `/literature --validate` no longer reports the 65 directory-path (book/parent-level) entries as
  false-positive stale — the validate report is now a trustworthy signal for genuinely missing
  files.
- Directory-path entries now receive the same schema-field and authors-shape coverage as
  file-path entries (7 new `authors_shape_warnings` surfaced as a result — a real coverage gain,
  not noise).
- The documented `literature-normalize-authors.sh --dry-run` invocation from the Validate Step 4
  report template now succeeds instead of hard-failing with `Unknown argument`.

## Follow-ups

- **Token-drift re-baselining** (deferred, from research report Adjacent Finding A): the 56
  `drift_entries` include a systematic subset (~52) drifting the same direction in a tight ratio
  band, suggesting a changed token-count formula or bulk re-conversion for a specific batch
  rather than corpus-wide drift. Independent of this task; a separate scheduling decision for the
  team lead.
- **`sources/diamondsareforever/chunk_0001.md` schema co-mingling** (deferred, from research
  report Adjacent Finding B): this record mixes the legacy `chunks_dir` schema with the current
  `path` schema in one entry, carries `token_count: 95000` against a 903-byte single-chunk `path`
  target, and `provenance_fidelity: "unverified_no_baseline"`. A data-correctness question (which
  field is authoritative), not a validate-logic bug — deliberately left un-special-cased per the
  plan's Non-Goals.
- **NEW — 15 null-path legacy `chunks_dir`-only entries** (deferred, discovered during this
  task's Phase 3 end-to-end verification, not documented in the research report): 15 entries in
  the live global index have `path == null` and only a `chunks_dir` field (e.g. `brics-rs-96-35`,
  `cattani-winskel-2005-profunctors`, `brics-rs-94-7`, `schultz-spivak-temporal-type-theory`,
  `fong-speranzon-spivak-temporal-landscapes`,
  `schultz-spivak-vasilakopoulou-dynamical-systems-sheaves`, `thomason-1970-indeterminist-time`,
  `rutten-2000-universal-coalgebra`, `jacobs-coalgebra-intro-draft`, `danos-krivine-rccs`,
  `reynolds-2003-ockhamist`, `rumberg-zanardo-2019-transition-structures`, plus 3 entries with
  `id == null` as well). These are a third schema variant distinct from both the file-path and
  directory-path variants this task's Defect 1 fix addresses. They were already reported stale
  before this fix (the old `-f` test against `$lit_dir/null` was also false) and remain reported
  stale after it, via the fixed three-way branch's missing-file-path fallback — not a regression,
  but also not resolved by this task. Whether these should be migrated to the current `path`
  schema, given a directory-path `path` value, or handled as a distinct third branch in Validate
  Step 2 is a data-correctness/schema-migration question for the team lead to schedule, in the
  same vein as Adjacent Finding B above.

## References

- `specs/071_fix_validate_directory_path_false_positives_and_flag_mismatch/plans/01_validate-dirpath-flag-fix.md`
- `specs/071_fix_validate_directory_path_false_positives_and_flag_mismatch/reports/01_validate-false-positives-flag-mismatch.md`
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (Validate Step 2, Step 4)
- `agent-system/extensions/literature/scripts/literature-normalize-authors.sh`
