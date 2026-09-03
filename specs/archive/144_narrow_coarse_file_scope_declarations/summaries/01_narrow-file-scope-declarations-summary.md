# Implementation Summary: Task #144

- **Task**: 144 - Narrow the coarse whole-directory file_scope declarations that manufacture false collisions and needlessly serialize multi-task orchestration
- **Status**: [COMPLETED]
- **Started**: 2026-08-30 (Phase 1)
- **Completed**: 2026-09-02 (Phase 6)
- **Effort**: 7 hours
- **Dependencies**: None
- **Artifacts**: plans/01_narrow-file-scope-declarations.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the generator of coarse, directory-root `file_scope` declarations (the
`multi-task-creation-standard.md` Component 4a "bias toward over-declaring" instruction), built
an additive `proposed_file_scope` -> `--file-scope-add` write-back mechanism for the
genuinely-unknown-footprint case, and applied the per-declaration narrowings to `specs/state.json`.
This dispatch closed out Phase 6, the final verification-only phase: it deployed the Phase 3-4
script changes, ran `validate-state.sh` and `verify-deploy.sh`, confirmed Check 8 is clean with no
coarse declarations remaining, confirmed the three genuine cross-task collisions (147/148/150 on
`orchestrate-cycle-plan.sh`, 143/148/150 on `orchestrate-cycle-postflight.sh`) still serialize as
intended, and confirmed no regression was introduced outside `file_scope`.

## What Changed

- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` —
  rewrote Component 4a step 1 to declare-narrowest-at-creation and documented the
  unknown-footprint convention (Phase 1).
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — added the
  `proposed_file_scope` schema field, spec, and example (Phase 2).
- `agent-system/extensions/core/scripts/update-task-status.sh` — implemented `--file-scope-add`
  with additive union merge (Phase 3).
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — added coverage for
  the new flag (Phase 3).
- `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/orchestrator-postflight.sh`,
  `agent-system/extensions/core/scripts/command-gate-out.sh` — wired the research-postflight
  consumers of `proposed_file_scope` (Phase 4).
- `specs/state.json` — narrowed `file_scope` arrays for the 9 flagged projects (44, 88, 143, 147,
  148, 150 replaced with concrete files; 129, 142, 149 dropped with no replacement) (Phase 5).
- `specs/144_narrow_coarse_file_scope_declarations/plans/01_narrow-file-scope-declarations.md` —
  Phase 6 checklist items checked off with recorded actual results; plan-level Status updated to
  `[COMPLETED]` (Phase 6, this dispatch).

## Decisions

- Phase 6 treated `verify-deploy.sh`'s 30-check run as the repo's "full gate set" — the
  convention this repo's other tasks and the delegating orchestrator use interchangeably for that
  term.
- No source file besides the plan's own checklist annotations was touched in Phase 6: it is
  verification-only per the plan's "Files to modify: None" declaration, and no defect in Phases
  1-5's work was found that required a fix in an owning phase's file.

## Plan Deviations

- None (implementation followed plan). Phase 6's own admission — recorded inline in the plan —
  is that the plan's stated bar of "`verify-deploy.sh` green; full gate run green" cannot be met
  on this tree, because 3 of 30 checks (10 individual findings) predate this task entirely and
  are unrelated to `file_scope`/Check 8. This is not a deviation from the plan's instructions;
  it is the plan's own contingency for exactly this situation ("or record an explicit written
  justification"), followed as written.

## Verification

- Build: N/A (meta task; no compiled build)
- Tests: `verify-deploy.sh`'s check 8 (`tests/run-all.sh`) — PASS, all discovered suites passed
- Files verified: Yes

### Phase 6 verification detail

- `bash agent-system/extensions/core/scripts/deploy-headless.sh` — deploy landed; `.claude/`
  carries the Phase 3-4 script changes.
- `bash agent-system/extensions/core/scripts/validate-state.sh` — Check 8
  ("No coarse (blast radius >= 3) file_scope declarations found") PASSES, no survivors; Check 9
  (duplicate entries) PASSES. Overall run reports 2 FAILs, both the pre-existing
  `abandon_reason`/`blocks_note` unknown-entry-field findings, unrelated to `file_scope`. Check 8
  is confirmed WARN-only (it reads PASS in this run) — no gate conversion was introduced.
- Six collision memberships queried directly against `specs/state.json` via `jq`:
  - `orchestrate-cycle-plan.sh` (or its test companion): declared by projects 147, 148, 150 — all
    three confirmed.
  - `orchestrate-cycle-postflight.sh` (or its test companion): declared by projects 143, 148,
    150 — all three confirmed.
- Pre-existing unrelated FAILs unchanged: `abandon_reason` on 12 projects (141, 94, 53, 46, 31,
  42, 64, 73, 100, 115, 132, 138); `blocks_note` on 3 projects (106, 107, 109) — both counts and
  memberships match the pre-dispatch baseline exactly.
- `git diff --stat` confirms `context/patterns/file-footprint-overlap.md` (both the `.claude/`
  deploy copy and the `agent-system/extensions/core/` source-store copy) is untouched.
- `bash .claude/scripts/verify-deploy.sh` — FAIL, 3 of 30 checks failed. All 3 are pre-existing
  and predate this dispatch:
  1. Doc-lint: 4 `index-entries.json` `line_count` mismatches (`patterns/postflight-control.md`
     318/405, `reference/state-management-schema.md` 519/520, `schemas/state-schema.json`
     267/271, `project/literature/patterns/zotero-item-creation.md` 208/234). None of these files
     were touched by this task.
  2. `validate-state.sh --deep`: the same 2 unrelated unknown-entry-field findings
     (`abandon_reason`, `blocks_note`) named above.
  3. State-writer boundary lint: 4 hand-rolled `state.json` write violations in
     `agent-system/extensions/core/scripts/tests/test-force-phases.sh` (lines 261, 307, 317,
     327) — a pre-existing test-file pattern, not introduced by this task.

  This is the full accounting of the plan's stated "full gate run green" bar not being met on
  this tree: every failing line traces to one of the 10 pre-existing findings above, none of
  which this task's Phases 1-6 touched or caused.

## Impacts

- `orchestrate-batch-admit.sh` no longer defers unrelated multi-task batches due to
  directory-root false collisions on the 9 narrowed projects; the 3 genuine cross-task
  collisions on `orchestrate-cycle-plan.sh`/`orchestrate-cycle-postflight.sh` still correctly
  serialize 147/148/150 and 143/148/150 against each other.
- Task creation now has a safe additive alternative (`proposed_file_scope` /
  `--file-scope-add`) to declaring a directory root when a footprint is genuinely unknown before
  research.

## Follow-ups

- The 10 pre-existing `verify-deploy.sh` findings (index-entries.json line-count drift on 4
  files, the `abandon_reason`/`blocks_note` unknown-entry-field warnings, and the 4 hand-rolled
  `state.json` writes in `test-force-phases.sh`) remain open and are out of this task's scope —
  they predate this dispatch and are unrelated to `file_scope`/Check 8. Recommend a separate task
  to reconcile `index-entries.json` line counts and, separately, to decide whether
  `abandon_reason`/`blocks_note` should be added to the state schema's known-field enum or
  removed from the affected entries.

## References

- `specs/144_narrow_coarse_file_scope_declarations/plans/01_narrow-file-scope-declarations.md`
- `specs/144_narrow_coarse_file_scope_declarations/reports/01_narrow-coarse-file-scope.md`
- `specs/144_narrow_coarse_file_scope_declarations/progress/phase-1-progress.json` through
  `phase-6-progress.json`
