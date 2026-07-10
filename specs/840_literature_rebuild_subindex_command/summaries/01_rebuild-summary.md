# Implementation Summary: Task #840

**Completed**: 2026-07-10
**Duration**: single session

## Overview

Added a `/literature --rebuild [--dry-run]` flag that brings a repo's per-repo sub-index
(`specs/literature-index.json`) into conformance with the global Literature corpus, via four
selectable jobs (dangling-ref lint, structural-minimum schema conformance, coverage refresh,
per-directory chunk/search-index coverage audit). All work landed in the extension source
(`.claude/extensions/literature/`) only, per the task's file-scope constraint; the deployed
`.claude/commands/literature.md` and `.claude/skills/skill-literature/` copies were not touched
(they are updated by the separate sync mechanism). All six plan phases completed and were
verified against live data (cslib, BimodalLogic, this repo, and the global Literature corpus).

## What Changed

- `.claude/extensions/literature/commands/literature.md` — added `--rebuild` as a new
  priority-0 mode-detection branch (before `--validate`), `--dry-run` parsing, a sub-mode
  summary row, a FILE/QUERY validation table row, a new `<step_3b>` delegating to
  `skill-literature` with `mode=rebuild dry_run={true|false}`, a "Rebuild mode" presentation
  block in step_5, updated `argument-hint` frontmatter, and updated "Unknown flag" error text.
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — added `rebuild)
  handle_rebuild ;;` to the step-4 dispatch case and updated the "Unknown mode" list; added a
  new "## Mode: Rebuild" section containing `handle_rebuild()` (absent-sub-index deferral to
  `literature-create-setup-task.sh`, an `AskUserQuestion` multiSelect job-picker, and a
  report-aggregation shell) plus four job functions: `rebuild_job1_dangling_ref_lint()`,
  `rebuild_job2_schema_conformance()`, `rebuild_job4_coverage_audit()`, and
  `rebuild_job3_coverage_refresh()`. The previously-dead "Sub-Index Management > Validate"
  block (unreachable, referenced a never-parsed `--subindex` flag) was neutralized with a
  pointer to the now-wired-up Job 1.
- `.claude/context/project/literature/domain/literature-index.md` — added a "Sub-Index Rebuild
  (`--rebuild`)" section documenting the live schema-divergence finding (structural-minimum
  check rationale) and the `document_metadata` empty-table note.
- `specs/840_literature_rebuild_subindex_command/plans/01_rebuild-plan.md` — all 6 phases
  checked off with completion/deviation annotations.

## Decisions

- Job 1 and Job 2 reuse/adapt the dead "Sub-Index Management > Validate" block rather than
  writing new dangling-ref logic from scratch, per the plan.
- Job 2 checks structural minimums only (`doc_id` non-empty AND `relevance` OR `reason`
  present) and never flags/strips extra curation fields — verified live against BimodalLogic's
  `hazard`/`citation_rule`/`known_corrections`/`audits` fields, which produced 0 violations.
- Job 3 (coverage refresh) is the only writer, gated by `AskUserQuestion` confirm-after-diff,
  append-only via `jq .entries += [...]`, and skips the write step entirely under `--dry-run`.
- Absent-sub-index handling defers to the existing `literature-create-setup-task.sh` rather than
  duplicating its state.json-mutation logic, mirroring the `--lit` flow's precedent.
- `--rebuild` is inserted as priority-0 in the mode-detection table (before `--validate`),
  mutually exclusive with `--validate`/`--index`/`--convert`.

## Plan Deviations

- **Task 4.2** (Job 4 directory→doc_id resolution) altered from the plan's proposed approach:
  the plan suggested mirroring `literature-fidelity-audit.sh`'s parent/child `parent_doc`
  fan-out resolution. Live-data verification showed this doesn't apply — `chunks_data.doc_id`
  in the SQLite FTS5 database is keyed directly on the `sources/<dir>/` directory *basename*
  (e.g. `blackburn_2002`), not on any individual `index.json` entry `.id` or its `parent_doc`
  chain (that fan-out logic answers a different question: which `index.json` chapter/section
  entries to stamp with a `provenance_fidelity` value, not which chunk rows exist for a
  directory). Implemented as a direct `doc_id = <directory basename>` lookup instead. This was
  live-verified to reproduce the exact expected 25-directory missing-coverage list from the
  research report (girard_1989, rabinovich_2014, burgess_1982_i, hodkinson_2006, tarjan_1972,
  thomas_1997, baier_katoen_2008, and 18 others), so the deviation is confirmed correct rather
  than a guess.

## Verification

- **Job 1 + Job 2, cslib** (11 entries): 0 dangling, 0 schema violations. sha256 of
  `~/Projects/cslib/specs/literature-index.json` unchanged before/after.
- **Job 1 + Job 2, BimodalLogic** (2 entries): 0 dangling, 0 schema violations; the `reason`,
  `hazard`, `citation_rule`, `known_corrections`, and `audits` fields on the `rabinovich_2014`
  entry were NOT flagged or stripped. sha256 unchanged before/after.
- **Job 2 chunk-id check**: 0 hits for `^chunk_[0-9]+$`-pattern doc_ids on both live sub-indexes.
- **Job 4, global corpus**: live-executed against `~/Projects/Literature` — 72 covered / 25
  missing `sources/<dir>/` directories (exact match to the research baseline); 11/11 legacy
  `chunks_dir`-schema entries audited, 0 missing; 0 chunked quarantine artifacts
  (`.md.bak-<UTC>`/`.md.rejected`) found, confirming the `*.md`-glob-strictness assumption.
  sha256 of `.literature.db` and global `index.json` unchanged before/after.
- **Absent sub-index (nvim)**: confirmed `specs/literature-index.json` is absent in this repo;
  live-executed the Step-2 detection control flow. The actual call into
  `literature-create-setup-task.sh` was intentionally NOT executed for real — that script
  unconditionally mutates this repo's own live `specs/state.json`/`TODO.md` by creating a new
  task, and doing so as a side effect of verification would have polluted this repo's actual
  task list. Verified instead that `state.json`/`TODO.md` sha256 are unchanged after the trace,
  and that the (pre-existing, unmodified) script is already relied upon by the `--lit` flow, so
  only the new detection/delegation code — not the script's own correctness — was in question.
- **Job 3**: append-only jq write shape verified against a scratch copy of cslib's sub-index
  (never a live file); confirmed the original cslib file's sha256 was unaffected by that test.
  `--dry-run` branch returns before any write in `rebuild_job3_coverage_refresh()`.
- **No-mutation guarantee**: sha256 before/after checks across all of the above confirm no job
  (1/2/4, and Job 3 under `--dry-run`) mutated any corpus file or sub-index without explicit
  confirmation.
- **Drift guard**: `bash .claude/scripts/check-extension-docs.sh` reports the identical
  "FAIL: 6 issue(s) found" both before (via `git stash`) and after this task's changes — all 6
  failures are pre-existing issues in the `core`/`lean`/`literature` extensions (missing
  `provides.scripts` manifest entries, undeployed `lean` sub-extension skills) unrelated to
  `--rebuild`. This task introduced zero new drift-guard failures.
- Build: N/A (markdown/bash instruction files, no build step)
- Tests: N/A (no automated test suite for this extension; verification was live-data execution
  as documented above)
- Files verified: Yes

## Notes

- The `handle_rebuild()` job functions (`rebuild_job1_dangling_ref_lint`,
  `rebuild_job2_schema_conformance`, `rebuild_job4_coverage_audit`,
  `rebuild_job3_coverage_refresh`) are referenced by `handle_rebuild()`'s report-aggregation
  shell before their own definitions later in the file — this mirrors the existing
  forward-reference pattern already used elsewhere in `SKILL.md` (e.g. `handle_import()` is
  called from "Search Step 7" before its own definition at "Import Step 8").
- A bash-syntax-only check (`bash -n`) was run against all 9 bash code blocks in the new "Mode:
  Rebuild" section (concatenated) and passed with no syntax errors.
- The optional `document_metadata`-empty-table note was added to
  `.claude/context/project/literature/domain/literature-index.md` along with a note on the
  live schema-divergence finding, since Job 4 explicitly avoids querying that table.
- Since `--rebuild` is only reachable through the `/literature` command's normal Claude-Code
  execution path (SKILL.md is agent-interpreted, not a literally-sourced shell script), true
  end-to-end verification of the full `/literature --rebuild` UX (including the
  `AskUserQuestion` job-picker and confirm-after-diff gate) requires an actual `/literature
  --rebuild` invocation in a live session — the verification performed here directly executed
  the equivalent bash logic against live repos/corpus to prove correctness of each job's core
  algorithm and its no-mutation guarantees, which is the strongest verification available
  without triggering unwanted side effects on the live task list.
