# Implementation Summary: Task #859

**Completed**: 2026-07-14
**Duration**: ~1 session, 6 phases across 3 dependency waves

## Overview

Implemented the plan's single canonical `normalize_topic()` helper (lowercase kebab-case) and
routed every topic write and every topic read/comparison through it, fixing the origin bug
(dependency tree rendering flat for non-lowercase topics), preventing duplicate case/separator
headings, keeping the `.claude/` and `.opencode/` renderers behaviorally identical, adding an
autonomous-context deterministic-default directive, and documenting the `topic`/`active_topics`
schema fields. All work followed the plan's 3-wave dependency ordering (Wave 1: phases 1, 4, 5;
Wave 2: phases 2, 3; Wave 3: phase 6) with no deviations.

## What Changed

- `.claude/scripts/manage-topics.sh` — Added `normalize_topic()` and applied it in the `add`,
  `set`, and `validate` subcommands so every stored topic and every membership comparison is
  canonical at the write chokepoint.
- `.claude/extensions/core/scripts/generate-task-order.sh` — Added the byte-identical
  `normalize_topic()` block; routed the grouping key (previously `${var,,}` lowercasing only)
  and both comparison guards (the origin bug's two `!=` checks) through it.
- `.claude/scripts/generate-task-order.sh` — Mirrored the identical change (deployed copy
  invoked by `generate-todo.sh`); this copy is regenerated from the core extension source on
  next extension load.
- `.opencode/scripts/generate-task-order.sh` — Mirrored the render-side fix only (grouping key
  + both guards); write-side topic-assignment parity for `.opencode/` is explicitly flagged as
  an out-of-scope follow-up in a script-header comment, not silently omitted.
- `.claude/context/patterns/topic-assignment-pattern.md` — Added an "Autonomous Context"
  subsection: when `orchestrator_mode == true`, callers must not invoke `AskUserQuestion`; the
  deterministic default is inherit -> infer -> sentinel-with-visible-`[topic:auto]`-notice,
  mirroring the `--lit` flag's `AUTONOMOUS_GLOBAL` directive. Documented directive only — no
  caller (`/spawn`, `/fix-it`, `/review`) was rewired.
- `.claude/context/reference/state-management-schema.md` — Added the `topic` field row to the
  Project Entry Fields table, added `active_topics` to the JSON structure example, and added a
  new "Topic Fields" subsection documenting the canonical form and write-time enforcement.

## Decisions

- Fixture testing used self-contained scratchpad directory trees (`.claude/scripts/` +
  `specs/state.json` copied into a temp dir) rather than a `STATE_FILE` env-var override, so
  each script's own `SCRIPT_DIR`/`PROJECT_ROOT` resolution naturally targeted the fixture with
  no code changes needed for testability.
- `manage-topics.sh validate` normalizes its input before comparison (the plan's recommended
  option), so `validate "Modal Logic"` correctly matches a stored `modal-logic`.
- Preserved each script's own pre-existing unrelated stylistic difference (e.g.
  `declare -a all_task_nums` vs `declare -a all_task_nums=()`) rather than overwriting one file
  wholesale with another — only the `normalize_topic`-related lines were changed in each copy.

## Plan Deviations

- None (implementation followed plan).

## Verification

- **Phase 1** (fixture): `add "Modal Logic"` stores `modal-logic`; repeated `add` with
  `modal_logic`/`modal-logic` variants are no-ops (idempotent); `set` stores `code-hygiene` for
  `"Code Hygiene"`; `validate "Modal Logic"` exits 0. Real `specs/state.json` confirmed
  untouched (`git diff` clean).
- **Phase 2** (fixture): a 4-task chain (1->2->3->4) with topics `"Modal Logic"` (x3) and
  `"modal-logic"` (x1) rendered as exactly ONE `### Modal Logic` heading with 3 `└─` indented
  lines — origin bug fixed, no duplicate heading.
- **Phase 3** (fixture): `.claude/scripts/generate-task-order.sh --print` and
  `.opencode/scripts/generate-task-order.sh --print` against the identical fixture produced
  byte-identical Grouped-by-Topic sections (`diff` clean).
- **Phase 4**: `grep -n "orchestrator_mode" .claude/context/patterns/topic-assignment-pattern.md`
  returns the new directive naming the deterministic default and forbidding `AskUserQuestion`.
- **Phase 5**: `grep -n "active_topics"` and `grep -n "topic"` against
  `state-management-schema.md` confirm both fields are documented with the canonical-form note.
- **Phase 6**: Fixed-point loop over the live `specs/state.json` found 0 non-canonical values
  across 3 `active_topics` entries and 3 `active_projects[].topic` values — **confirming no
  migration is needed for this repository** (matches research Finding 8). `bash
  .claude/scripts/generate-todo.sh` regenerated cleanly (exit 0, no diff to `specs/TODO.md`).
  `git diff specs/state.json` and `specs/TODO.md` are clean of any topic-data mutation
  attributable to this work.
- Build: N/A (bash scripts + markdown docs; `bash -n` syntax-checked all three modified shell
  scripts).
- Tests: All fixture-based verification steps above passed.
- Files verified: Yes.
- No task-number references were introduced in any deliverable file outside `specs/**`
  (verified via repo-wide grep across all six modified deliverable files).

## Notes

- Migration scope for this repository is **zero tasks** — all existing `active_topics` and
  `active_projects[].topic` values were already canonical lowercase kebab-case before this
  change. The fix is preventive/structural: it lands in the shared core extension source
  (`.claude/extensions/core/scripts/generate-task-order.sh`), so it also protects any other
  repository that loads this extension and later introduces a non-canonical topic string.
- Follow-up (flagged, not implemented): `.opencode/` has no `manage-topics.sh`, no
  `topic-assignment-pattern.md`, and no `/task` topic-assignment step — write-side topic
  normalization parity for `.opencode/` remains a recommended follow-up task.
