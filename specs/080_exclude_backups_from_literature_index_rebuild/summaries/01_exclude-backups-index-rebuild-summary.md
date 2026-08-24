# Implementation Summary: Task #80

- **Task**: 80 - Stop the literature index rebuild from indexing backed-up chunk manifests
- **Status**: [COMPLETED]
- **Started**: 2026-08-24
- **Completed**: 2026-08-24
- **Effort**: ~5.5 hours (matches plan estimate)
- **Dependencies**: None blocking
- **Artifacts**: plans/01_exclude-backups-index-rebuild.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`literature-build-index.sh`'s manifest discovery had no prune guard against dot-prefixed
directories, so every rebuild descended into `.backups/` and any other backup/quarantine/staging
directory and indexed superseded chunk manifests as if they were live. This implementation added
a root-and-nested dot-directory exclusion to the one unguarded traversal, made a `doc_id` claimed
by two or more manifests loud (with an opt-in `--strict-duplicates` fatal mode), replaced
counter-derived rebuild stats with database-derived per-`doc_id` counts, locked all three behind
a new scratch-directory regression test, documented the exclusion predicate and duplicate policy
in a new context file, and finally proved the manual `chunks.json.bak` rename workaround
unnecessary by reverting all 14 renames and rebuilding the live corpus clean.

## What Changed

- `agent-system/extensions/literature/scripts/literature-build-index.sh` — pruned manifest
  discovery (`-mindepth 1 \( -name '.*' -type d -prune \) -o \( -name 'chunks.json' -print \)`,
  excluding dot-prefixed directories at any depth); `--strict-duplicates` flag with duplicate-
  `doc_id` detection, warning, and exit code 3; database-derived stats (`SELECT COUNT(*)`,
  per-`doc_id` `GROUP BY`, declared-vs-actual mismatch warnings); a `set +e`/`set -e` fix around
  the Python heredoc and the outer per-target dispatch loop so a deliberate `sys.exit(3)`
  propagates cleanly without leaving a stray `.literature.db.tmp` file (found and fixed during
  Phase 3, not in the original plan).
- `agent-system/extensions/literature/scripts/tests/test-literature-build-index.sh` — new. Nine
  tests: Tests A-F from the plan (backup-present/absent equivalence, stale-survivor absence,
  nested `.chunks/` exclusion, explicit dot-named `--dir` target, duplicate-`doc_id` default/strict
  behavior, declared/actual mismatch reporting) plus a clean-run sanity check and a corpus-mutation
  guard. Verified non-vacuous: reverting the Phase 2 prune makes Tests A, B, C fail.
- `agent-system/extensions/literature/manifest.json` — registered the new test in
  `provides.scripts`.
- `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md`
  — new. Documents the "live corpus directory" predicate, the exact prune expression, the
  `.chunks/` legacy case as the worked nested-directory example, the duplicate-`doc_id` policy and
  its reconciliation with `literature-ingest.sh`'s precedent, and a freshly re-run traversal survey
  covering every script in the extension.
- `~/Projects/Literature/.backups/**/chunks.json.bak` → `chunks.json` (14 files, corpus mutation
  outside the repository; exact mapping recorded before renaming).
- `~/Projects/Literature/.literature.db` — rebuilt from the live corpus (backed up to a
  timestamped sibling before the rebuild).
- `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_pre-fix-audit.txt`,
  `01_bak-rename-mapping.txt`, `01_post-fix-audit.txt` — new task-management artifacts.

## Decisions

- Corrected acceptance criterion 3's audit method: `chunks_data.source_path` is a bare filename,
  never containing `.backups`, so a `LIKE '%.backups%'` query is structurally unsatisfiable.
  Substituted a per-`doc_id` chunk_id-set diff (Phase 1 baseline, Phase 7 re-run, asserts zero
  stale survivors).
- Duplicate-`doc_id` default is warn-not-fail, matching `literature-ingest.sh`'s existing
  warn-then-overwrite precedent at the `index.json` layer, because `skill-literature`'s convert
  flow wraps the index rebuild in a non-fatal `|| echo ... non-fatal`, so a hard failure there
  would silently leave the entire global index un-rebuilt rather than surfacing one ambiguous
  document. `--strict-duplicates` is the opt-in fatal mode (exit 3) for CI-style deterministic
  assertion.
- Exclusion predicate is "any dot-prefixed directory at any depth," not a literal `.backups`
  match — the corpus root also holds `.sources-recovered/` and `.online-ingest-staging/`, and a
  real nested case (`sources/thomas_2003_reactive/.chunks/`) was found live during planning.

## Plan Deviations

- Phase 2/Phase 7 verification requiring `shellcheck` clean was substituted with `bash -n` plus
  extensive scratch-directory functional testing — `shellcheck` is not installed in this
  environment.
- Phase 3 discovered and fixed a `set -euo pipefail` interaction bug not named in the plan: a bare
  `python3 <<PYEOF ... PYEOF` heredoc followed by capturing `$?` aborts the script immediately on
  any nonzero Python exit (including the new deliberate `sys.exit(3)` for `--strict-duplicates`),
  skipping cleanup and leaving a stray `.literature.db.tmp` file. Fixed by wrapping the heredoc in
  `set +e`/`set -e` and converting the outer per-target dispatch loop to an `if`-guarded call.
- Phase 6: `format-decision.md` was inspected but not modified — its manifest-discovery
  description never claimed the traversal was unguarded, so the plan's conditional edit did not
  trigger.

## Verification

- Build: N/A (bash/Python scripts, no compiled build step)
- Tests: Passed — `tests/test-literature-build-index.sh` 9/9, `tests/test-literature-convert.sh`
  13/13, both exit 0. Anti-vacuity confirmed: reverting the Phase 2 prune makes exactly Tests A, B,
  C fail.
- Files verified: Yes — all new/modified files read back and content-checked; `jq . manifest.json`
  parses.
- Live corpus verification (Phase 7): global rebuild with all 14 `.bak` renames reverted reports
  204 manifests (16 skipped in non-corpus directories), zero stale `chunk_id`s, zero duplicate-
  `doc_id` warnings, `thomas_2003_reactive` at its correct 36-chunk count (down from the
  pre-existing 37), idempotent across two consecutive rebuilds, and `literature-search.sh` returns
  usable results against the rebuilt database.

## Impacts

- The literature index rebuild (`--global`, `--local`, and `--dir`) no longer silently indexes
  content from `.backups/`, `.sources-recovered/`, `.online-ingest-staging/`, or any other
  dot-prefixed directory, at any depth. The manual `chunks.json.bak` rename workaround (14 files)
  is no longer necessary and has been reverted.
- A `doc_id` claimed by more than one manifest is now visible in rebuild output by default and can
  be made a hard failure via `--strict-duplicates` for stricter operational contexts.
- Rebuild stderr now reports database-derived, per-`doc_id` counts and flags declared/actual
  mismatches. This surfaced 30 pre-existing internal chunk_id-collision mismatches unrelated to
  this task's defect (out of scope; see Non-Goals in the plan).
- Future scripts that need to traverse the corpus root have a documented predicate and exact prune
  expression to reuse (`corpus-directory-conventions.md`), rather than re-deriving one.

## Follow-ups

- The 30 declared/actual chunk-count mismatches newly surfaced by Phase 4's reporting (internal
  duplicate `chunk_id` collisions within individual manifests, e.g. `baier_katoen_2008`
  declared=1264/actual=1263) are a distinct, pre-existing defect class. Not fixed here — out of
  scope per the plan's Non-Goals — but now visible for a future task to address if desired.
- The literature global-index schema-unification task (noted as a sequenced-after advisory in the
  plan's Dependencies) also lists `literature-build-index.sh` in its file scope. If it lands after
  this implementation, no rebase should be needed since this work does not touch `index.json`
  entry shape; if it lands first, re-verify line numbers before any further edits to this script.

## References

- Plan: `specs/080_exclude_backups_from_literature_index_rebuild/plans/01_exclude-backups-index-rebuild.md`
- Research: `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_exclude-backups-from-index-rebuild.md`
- Pre-fix audit: `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_pre-fix-audit.txt`
- .bak rename mapping: `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_bak-rename-mapping.txt`
- Post-fix audit: `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_post-fix-audit.txt`
- New context doc: `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md`
