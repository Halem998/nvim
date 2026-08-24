# Implementation Summary: Task #84

- **Task**: 84 - fix_duplication_gate_scope_and_extensions_root
- **Status**: [COMPLETED]
- **Started**: 2026-08-24T22:00:00Z
- **Completed**: 2026-08-24T22:27:10Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_duplication-gate-scope-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Repaired the single duplication gate (`test-common-lib.sh`'s single-source assertion) that had
two compounding defects: a fixed `../../..` root walk that silently over-scanned the whole repo
when run from the deployed `.claude/scripts/tests/` copy, and a `*.sh`-only scan that was
structurally blind to inline `sess_$(date ...)` generators duplicated across 37 `.md` command/
skill files. Fixed the gate's root resolution and scan scope, added regression fixtures pinning
both previously-invisible behaviors, then migrated the 1 real `.sh` offender and all 37 real
`.md` offenders across 7 extensions onto the existing `common_session_id()` helper. Closed
`errors.json` entry `err_1787022038113_c3VPTR` with fix evidence.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` — replaced the fixed-depth
  `EXTENSIONS_ROOT` walk with probe-based `SCAN_MODE`/`SCAN_ROOT` detection (reusing
  `run-all.sh`'s `core/manifest.json` probe verbatim); extracted `collect_session_id_offenders()`
  helper that scans `*.sh` whole-tree plus `*.md` scoped to `commands/`/`skills/`/`agents/`;
  added 6 new regression-fixture assertions (deployed-mode positive/negative, source-store
  positive, missing-subdirectory skip, mode-probe correctness in both directions).
- `agent-system/extensions/core/scripts/validate-state.sh` — sources `lib/common.sh`; the
  `--fix` session-id assignment now calls `common_session_id()`; updated the stale doc comment
  that itself matched the duplication pattern.
- `agent-system/extensions/core/scripts/lib/common.sh` — added `validate-state.sh` to the
  `common_session_id` consumer list; documented the `.md`-consumer replacement idiom
  (`source .claude/scripts/lib/common.sh` + `session_id="$(common_session_id)"`) in the file
  header.
- 37 `.md` files across `core`, `founder`, `present`, `filetypes`, `cslib`, `literature`, and
  `epidemiology` (44 individual call sites, including 3 `${var:-...}` fallback-form sites and
  cslib's alternate-entropy-source sites) — migrated to the documented idiom, preserving each
  site's existing variable name and surrounding prose exactly.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — updated prose that asserted
  skill-todo "has none of its own" session-ID mechanism, now that it sources `lib/common.sh`.
- `specs/errors.json` — closed `err_1787022038113_c3VPTR` (`fix_status: "fixed"`,
  `fixed_date`, `fix_task: 84`).

## Decisions

- Reused `run-all.sh`'s exact `core/manifest.json`-probe shape for mode detection rather than
  inventing a new heuristic, per the plan's explicit direction.
- Kept the `.sh` scan whole-tree (root fixed, reach unchanged) rather than narrowing it, to avoid
  regressing detection of a real `.sh` offender outside `commands/`/`skills`/`agents`.
- Scoped the `.md` scan to `commands/`/`skills/`/`agents/` by positive construction rather than
  by an exclusion deny-list, so `context/`, `docs/`, and `rules/` illustrative prose stays out of
  scope without needing to be enumerated.
- Migrated all 37 real `.md` offenders in one pass via a small verified Python migration script
  (regex-matched both the plain-assignment and `${var:-...}` fallback forms) rather than
  hand-editing each file, then committed per-phase (matching the plan's territory split) once all
  edits were verified against the live gate.

## Plan Deviations

- **Task 9 (errors.json closure)** altered: closed via the sanctioned `errors-append.sh update`
  CLI, which sets only `fix_status`/`fixed_date`/`fix_task` (the fields the errors-schema.json
  item type documents and every other closed entry uses). No already-closed entry carries a
  freeform "evidence" field and the CLI has no such flag, so the closing-evidence narrative
  required by the plan is recorded here and in the plan file's Phase 9 task annotations instead
  of as a new JSON field.
- Commit granularity: because the `.md`-scoped scan (Phase 3), the regression fixtures (Phase 4),
  and the root-resolution fix (Phase 1) were all authored as one continuous edit to
  `test-common-lib.sh` before any commit fired, they landed together in the Phase 1 commit
  (`af9185e42`) rather than as three separate commits; content is correct and verified, only the
  commit-message/phase attribution is coarser than the plan's per-phase commit template. The
  `.md` idiom header documentation in `common.sh` (Phase 5) similarly landed inside the Phase 2
  commit (`e8b1b110f`) rather than Phase 5's, for the same reason (both edits to `common.sh`
  landed in the working tree before the Phase 2 commit ran).

## Verification

- Build: N/A (shell scripts + Markdown)
- Tests: Passed — `test-common-lib.sh` reports `Passed: 30, Failed: 0` from both the source-store
  location and the deployed `.claude/scripts/tests/` location (after a non-destructive
  `deploy-headless.sh` resync), with byte-for-byte-identical (empty) offender sets.
- Acceptance test: a deliberately reintroduced inline generator planted into
  `agent-system/extensions/core/commands/review.md` made the gate FAIL and name that exact file;
  reverting via a saved backup returned the gate to 30 passed / 0 failed, and `git diff --stat`
  confirmed the working tree was left clean of the plant.
- `run-all.sh` (full suite runner): `test-common-lib.sh` passes; the run's only 2 failures
  (`test-skill-base-lifecycle.sh`, `test-validate-return-meta.sh`) are pre-existing and unrelated
  to this task's scope.
- `grep -rl 'sess_\$(date' agent-system/extensions/` returns exactly 14 files: `lib/common.sh`,
  `tests/test-common-lib.sh`, and the 12 illustrative-prose sites under `core/context/` (11) and
  `core/rules/git-workflow.md` (1) — matching the plan's own enumeration (the plan's summary line
  said "13 files" as an arithmetic slip; its own file list totals 14, which is what was verified).
- `bash -n` parses clean for every modified `.sh` file (`test-common-lib.sh`, `validate-state.sh`,
  `common.sh`).
- `jq . specs/errors.json` succeeds.
- Files verified: Yes.

## Impacts

- The single-source-of-truth gate for session-ID generation now actually enforces its contract
  across both the source-store and deployed layouts, and across both `.sh` and `.md` executable
  surfaces — closing the environment-dependent instability `err_1787022038113_c3VPTR` described.
- Any future re-introduction of an inline `sess_$(date ...)` generator inside `commands/`,
  `skills/`, or `agents/` (in any extension) will now fail this gate, as verified by the
  acceptance test.
- `lib/common.sh`'s header now documents one canonical `.md` idiom, so future `.md` authors have
  a discoverable pattern to reach for instead of re-inlining.

## Follow-ups

- None required for this task's scope. The plan's Non-Goals explicitly exclude cloning this
  gate's pattern to other duplication classes and touching the 12 illustrative-prose sites —
  both remain untouched by design.

## References

- `specs/084_fix_duplication_gate_scope_and_extensions_root/reports/01_duplication-gate-scope-and-extensions-root.md`
- `specs/084_fix_duplication_gate_scope_and_extensions_root/plans/01_duplication-gate-scope-fix.md`
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh`
- `agent-system/extensions/core/scripts/lib/common.sh`
