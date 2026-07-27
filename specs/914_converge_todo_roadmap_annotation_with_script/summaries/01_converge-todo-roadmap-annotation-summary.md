# Implementation Summary: Task #914

**Completed**: 2026-07-27
**Duration**: single session, 6 phases

## Overview

`/todo` maintained two independently-authored roadmap-annotation specifications
(`commands/todo.md`, `skills/skill-todo/SKILL.md`) that reimplemented checkbox-only, table-blind
matching and could report a clean archival pass while silently annotating zero roadmap items.
This task made `roadmap-integration.sh` the single parser and structure-signal source for both
specs (parse-only for scanning, `--annotate` against a filtered snapshot for application), while
preserving the two things the shared script structurally cannot do: meta/expanded-task exclusion
and abandoned-task annotation. All six planned phases completed.

## What Changed

- `agent-system/extensions/core/scripts/roadmap-integration.sh` — added a "Caller contract"
  subsection to the header comment block documenting parse-only mode as a first-class call shape,
  the sibling-archive-resolution behavior for filtered snapshots, and the absence of any
  `task_type` filter or abandoned-status branch. Comment-only change, no executable code touched.
- `agent-system/extensions/core/commands/todo.md` — Step 3.5 now calls `roadmap-integration.sh`
  parse-only and filters its `roadmap_matches[]` to the existing meta/expanded eligibility
  partition, replacing the old grep-over-checkbox-lines matcher entirely. Step 5.5 now builds a
  filtered `state.json` snapshot (captured pre-archival from Step 3.5's eligible-task list) and
  invokes the script's `--annotate` mode against it for completed-task annotation, while keeping
  abandoned-task annotation as `/todo`'s own logic gated on `roadmap_structure.parseable`. Step 4's
  dry-run output, the final Output section, the Section Inclusion Rules table, and the Notes
  "Roadmap Updates" subsection were all rewired to a three-way branch (omit only when parseable
  and zero matches; always print the unparseable warning; print the annotation-no-op warning) so
  an unparseable or silently-failed roadmap is never reportable as success.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — Stages 5 (`ScanRoadmap`), 8
  (`DryRunOutput`), 11 (`UpdateRoadmap`), and 16 (`OutputResults`) mirror the same design at their
  prose level of detail: parse-only scan with eligibility filtering, the same split
  completed/abandoned annotation ownership, and the same three-way output gate.

## Decisions

- Adopted the research report's recommended option (b): keep `/todo`'s two genuine requirement
  differences (abandoned-task annotation, meta/expanded exclusion) as `/todo`-owned logic, while
  reusing the shared script as the single parser/writer for the completed-task path. This avoids
  either dropping real capabilities or widening an already-fixed, already-verified script for a
  caller-specific need.
- The filtered-snapshot mechanism (scratch `mktemp -d` state.json, `trap`-cleaned, never written
  back) resolves the load-bearing sequencing constraint that Step 5.5 runs after Step 5's
  archival: the snapshot must be synthesized from the pre-archival `roadmap_eligible_tasks[]`
  capture, or an `--annotate` call against the live `specs/state.json` would see none of the
  tasks being archived this run.

## Plan Deviations

- None (implementation followed plan). One defect was caught and fixed during Phase 6's own
  consistency sweep (see Notes below) rather than left for a later pass, which is the sweep
  working as designed, not a deviation from it.

## Verification

- Build: N/A (markdown/shell documentation task)
- Tests: Passed — acceptance test (synthetic zero-structure `ROADMAP.md` fixture yields
  `parseable: false`, `warnings: ["unparseable_roadmap"]`, stderr banner present) and
  non-regression test (real `specs/ROADMAP.md` yields `parseable: true`, `checkboxes: 12`,
  `table_rows: 0`) both ran and passed live, per-phase, against `bash` invocations exactly as
  documented in the specs.
- Files verified: Yes — `bash -n` on the script exits 0; `git status --short` shows zero modified
  paths under `.claude/`; no task-number citation patterns found in the three edited files (one
  pre-existing, unrelated hit in `SKILL.md`'s vault-transition comment template is a runtime
  string built from shell variables, not a literal citation).

## Notes

**Defect caught during Phase 6's cross-spec consistency sweep**: while drafting `commands/todo.md`
Step 3.5's "Match Types" note (Phase 2), the research report's inaccurate premise ("the live
`ROADMAP.md` is table-based with zero checkboxes") was initially copied into the spec prose. The
report itself, and this plan's Overview, had already flagged this as incorrect — a live parse-only
run against this repository's actual `ROADMAP.md` reports `phases=2, checkboxes=12,
table_rows=0` (checkbox-based, zero table rows — the opposite claim). Phase 6's cross-spec
consistency task caught this before completion and it was corrected in the same phase's commit,
restating the live structure accurately while still documenting both checkbox and table-row
matching as live, non-dead-code paths in the shared script.

**Follow-up recorded, not performed** (out of this task's declared `file_scope`):
`context/patterns/roadmap-update.md` still documents the now-superseded checkbox-only matching
strategy and never mentions `roadmap-integration.sh`. A separate task should repoint it at the
parse-only + filtered-annotate pattern this task establishes.
