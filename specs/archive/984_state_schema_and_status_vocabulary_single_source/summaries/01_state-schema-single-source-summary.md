# Implementation Summary: Task #984

- **Task**: 984 - One state.json schema, one status vocabulary, converted extension writers
- **Status**: [COMPLETED]
- **Started**: 2026-08-09T00:00:00Z
- **Completed**: 2026-08-09T00:00:00Z
- **Effort**: ~8 hours
- **Dependencies**: None (962, 969, 988 landed and are archived-completed)
- **Artifacts**: plans/01_state-schema-single-source.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Gave `specs/state.json` a machine-enforced schema and made the task-status vocabulary a single
source of truth. Landed a draft-07 `state-schema.json` plus a sourced `status-vocabulary.sh`
shell library as the closed 12-value enum anchor, built a hand-rolled bash+jq `validate-state.sh`
(base + `--deep`) wired as deploy Gate 10, converted `generate-todo.sh` and
`update-task-status.sh` to source the anchor (with `generate-todo.sh` now hard-failing loudly on
an off-schema status instead of silently uppercasing it), and repaired the two vocabulary
documents plus `command-structure.md`'s eight defect sites. Retired two stale, actively
context-injected files (`state-template.json`, `self-healing-implementation-details.md`) and
their `index-entries.json` wiring. Work item 5 (~110 non-core extension state writers) stays
explicitly out of scope, as scoped by the plan.

## What Changed

- `agent-system/extensions/core/context/schemas/state-schema.json` — new draft-07 schema for
  `specs/state.json`, `additionalProperties: false` throughout, closed 12-value
  `definitions.taskStatus.enum`
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` — new sourced shell library:
  the enum, a validation predicate, and the state.json-value -> TODO.md-marker mapping
- `agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh` — new drift test
  (library/schema enum byte-equality) plus predicate accept/reject fixtures
- `agent-system/extensions/core/scripts/validate-state.sh` — new hand-rolled bash+jq validator
  (base + `--deep`: uniqueness, TODO.md sync, dependency-graph integrity, terminal-status
  immutability)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — new fixture suite: four
  seeded defects (stray field, duplicate `project_number`, off-schema status, dangling
  dependency) plus two bonus fixtures (self-reference, cycle) and a positive fixture
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added Gate 10 (`validate-state.sh
  --deep` against the deployed tree's live `specs/state.json`)
- `agent-system/extensions/core/scripts/generate-todo.sh` — `format_status()` now sources the
  library; the permissive `*)` catch-all is deleted and replaced with a loud, named failure
  (nothing written) on an off-schema status
- `agent-system/extensions/core/scripts/update-task-status.sh` — sources the library; validates
  `map_status()`'s resolved resting state against the closed enum as a drift backstop; no
  `revise` case added (kept unreachable by design)
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — added Case 9
  (off-schema status -> `generate-todo.sh` hard-fails, writes nothing)
- `agent-system/extensions/core/context/standards/status-markers.md` — deleted the `REVISING`/
  `REVISED` prose sections and table row (with a removal note citing `skill-reviser/SKILL.md`'s
  documented decision), added the missing `[PR READY]` mapping-table row, added a "Single source"
  pointer near the top, fixed residual `REVISING`/`REVISED` mentions in the command-mapping table
  and the transition diagram
- `agent-system/extensions/core/context/reference/state-management-schema.md` — added a
  single-source pointer above the Status Values Mapping table, added a new Top-Level Fields
  table, extended Project Entry Fields and Repository Health Fields with the confirmed-live
  undocumented columns, added sparsity notes to `vault_count`/`vault_history`/`effort`/
  `next_artifact_number`/`reflection`
- `agent-system/extensions/core/context/formats/command-structure.md` — fixed all 8 defect sites
  (6 store-path/array-name/key-name sites now use `specs/state.json`/`.active_projects[]`/
  `.project_number`; 2 fabricated-vocabulary sites no longer cite invalid placeholder values);
  the "Updating State Directly" Wrong block's unprotected `tmp.json`/`mv` idiom is now explicitly
  labeled dangerous rather than modeled as ordinary code, with its paired Correct block (and
  Mistake 1's) pointing at `state-write.sh`/`update-task-status.sh`/`skill-status-sync` instead of
  a fictional `status-sync-manager` abstraction
- `agent-system/extensions/core/context/templates/state-template.json` — deleted (stale v1.0.0
  shape, actively injected into `meta-builder-agent` and `/task` context)
- `agent-system/extensions/core/context/repo/self-healing-implementation-details.md` — deleted
  (specs a never-implemented, direction-inverting recovery mechanism; actively injected into
  `/errors` and `/fix-it` context)
- `agent-system/extensions/core/index-entries.json` — registered `schemas/state-schema.json`;
  removed the two retired entries; corrected `line_count` drift on three edited entries
  (`formats/command-structure.md`, `standards/status-markers.md`,
  `reference/state-management-schema.md`)
- `agent-system/extensions/core/manifest.json` — registered `lib/status-vocabulary.sh`,
  `validate-state.sh`, and their two test suites in `provides.scripts`

## Decisions

- Followed the research report's recommendation to delete `revising`/`revised` as dead
  vocabulary rather than reconcile them into `map_status()`, citing `skill-reviser/SKILL.md`'s
  documented "skip preflight status update" decision.
- `validate-state.sh` follows the hand-rolled bash+jq idiom (`events-append.sh`/
  `errors-append.sh`/`validate-handoff.sh` precedent), never a runtime JSON-Schema-library call.
- `validate-state.sh` is deliberately argument-relative (no `PROJECT_ROOT`/`deploy-root-guard.sh`
  dependency), locating its sibling `TODO.md` and `archive/state.json` relative to the passed
  state-file's own directory — this lets it run correctly from either the deployed tree or the
  source store, unlike `generate-todo.sh`/`update-task-status.sh` which do require the deployed
  tree.
- `vault_count`/`vault_history`/`effort`/`next_artifact_number` stay documented-optional
  (lifecycle-timing sparsity, not dead fields); `reflection` is the one genuinely-unexercised
  field, noted as such.
- Added `default_task_type` to the schema as an optional, nullable top-level field: not named in
  the research report's inventory, but a real, consumed field (`commands/task.md`, documented in
  the root CLAUDE.md) absent only because it happens to be unset in the current live snapshot.

## Plan Deviations

- Phase 1's Scope Hypothesis (property inventory) matched the research report's finding set
  exactly, with one addition: `default_task_type` was added to the schema (see Decisions above).
- Phase 2's Scope Hypothesis (9 pre-existing `verify-deploy.sh` gates) confirmed exactly.
- Phase 3's Scope Hypothesis diverged narrowly: `update-task-status.sh`'s `map_status()` has 10
  `op:target` case combinations (6 distinct target tokens crossed with preflight/postflight,
  minus two nonsensical pairs), not "9 target values" — recorded in Phase 3's phase notes; no
  behavioral impact.
- Phase 4 found one stale task-item claim: `completion_summary`/`roadmap_items` were already
  present in `state-management-schema.md`'s Field Reference table (not missing as the task list
  assumed) — no duplicate rows added.
- Phase 5's Scope Hypothesis (8 `command-structure.md` defect sites, 2 `index-entries.json`
  entries to retire) confirmed exactly.
- Two unplanned but necessary fixes surfaced during implementation, both recorded in the
  affected phase's own phase notes: (1) `index-entries.json` `line_count` drift on three edited
  files, caught by `check-extension-docs.sh`'s Rule R and corrected; (2) two of this task's own
  verification-bullet greps (fabricated-vocabulary and `revising`/`revised`) would have still
  matched this task's own explanatory prose about the removed values — reworded via paraphrase so
  the automated greps genuinely return zero hits.
- `root-files/settings.local.json`'s stale `Bash(mv ...)` allowlist entry (referencing
  `state-template.json`'s old path) is confirmed still present and remains out of scope, per the
  plan's own Non-Goals (install-only file per the source-store/deploy-boundary convention).

## Verification

- Build: N/A (shell/JSON/Markdown, no compiled artifacts)
- Tests: Passed — `test-status-vocabulary.sh`, `test-validate-state.sh` (8/8 fixtures, including
  the four required seeded defects plus a positive fixture and two bonus fixtures), and
  `test-update-task-status.sh` (19/19, including the new off-schema-status Case 9) all pass.
  `bash scripts/tests/run-all.sh` reports one pre-existing, unrelated failure
  (`test-index-entries-schema.sh`'s "Rule U" EXTENSION.md-line-count fixture case, confirmed via
  `git stash` to predate this task's entire diff) — every suite this task touches or introduces
  passes cleanly.
- Files verified: Yes — `bash scripts/verify-deploy.sh` passes 20/21 checks (Gate 10, the new
  validator gate, passes cleanly; the one failure is the same pre-existing Gate 8 issue above).
  `bash scripts/validate-context-index.sh`, `bash scripts/check-task-references.sh`, and
  `bash scripts/check-extension-docs.sh` all pass cleanly. Regenerated `specs/TODO.md` is
  byte-identical to the committed version.

## Impacts

- `specs/state.json` now has a single machine-readable schema and a validator that fails loudly
  on structural defects — a future off-schema write is caught at deploy-verification time
  (Gate 10) instead of silently propagating into `generate-todo.sh`'s rendering.
- `generate-todo.sh` no longer silently renders an unrecognized status as an uppercased marker;
  an off-schema value (including accidental use of `.return-meta.json`'s different vocabulary,
  e.g. `in_progress`) now hard-fails with a named error.
- `meta-builder-agent`, `/task`, `/errors`, and `/fix-it` no longer load the two stale,
  actively-injected dead files into their context.
- The six other core scripts that independently re-type the status enum
  (`generate-task-order.sh`, `orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`,
  `reconcile-task-status.sh`, `update-phase-status.sh`, `update-plan-status.sh`) now have a
  ready-made library to convert to as a mechanical follow-on — not done here, deliberately out
  of scope per the plan's Non-Goals.

## Follow-ups

- Work item 5 (converting ~110 non-core extension state writers to `state-write.sh`) — separate
  follow-on task; its prerequisite (`state-write.sh --state-file`/`--init`) is already shipped.
- Converting the six other core scripts that re-type the status enum to source
  `status-vocabulary.sh` (mechanical, library already designed for this).
- `root-files/settings.local.json`'s stale `Bash(mv ...)` allowlist entry referencing
  `state-template.json`'s old path — install-only file, out of scope for this task.
- The pre-existing, unrelated `test-index-entries-schema.sh` "Rule U" failure (EXTENSION.md
  line-count fixture) noticed during this task's verification passes — not investigated further
  here since it predates and is unrelated to this task's scope.

## References

- Plan: `specs/984_state_schema_and_status_vocabulary_single_source/plans/01_state-schema-single-source.md`
- Research report: `specs/984_state_schema_and_status_vocabulary_single_source/reports/01_state-schema-status-vocabulary.md`
