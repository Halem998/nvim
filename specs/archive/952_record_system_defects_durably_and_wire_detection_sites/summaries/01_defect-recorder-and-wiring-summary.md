# Implementation Summary: Task #952

- **Task**: 952 - Record detected system defects durably and wire the ready detection sites
- **Status**: [COMPLETED]
- **Started**: 2026-08-07T08:40:00Z
- **Completed**: 2026-08-07T17:10:00Z
- **Effort**: 11 hours
- **Dependencies**: 951 (completed, prerequisite contract), 962, 988
- **Artifacts**: plans/01_defect-recorder-and-wiring.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Built `agent-system/extensions/core/scripts/system-defect-record.sh`, a thin house-style wrapper
over `events-append.sh` that turns a detected agent-system defect into a durable, deduplicated
`event_type: "system_defect"` / `category: "deviation"` row on `specs/events.jsonl`, then wired
non-fatal recorder calls into every detection site the prerequisite's registry (task 951's
discrimination document) classifies as ready: the Deliverable 2(a) `ARTIFACTS_SHAPE_MISMATCH`
consumer, the Deliverable 2(b) off-schema/stale-handoff/stray-handoff sites, and the five
Deliverable 2(c) ephemeral PostToolUse hooks. This dispatch resumed a stalled prior run: Phases
1-6 were already complete and committed; this run inspected, verified, and closed the
already-in-flight Phase 7 (the five hooks) and then executed the full Phase 8 acceptance test
(matched positive/negative recorder proof plus the repository gate set), discovering and fixing
two pre-existing, unrelated defects along the way (see Deviations).

## What Changed

- `agent-system/extensions/core/hooks/validate-meta-write.sh` — added a non-fatal recorder call
  (`SOURCE_STORE_BOUNDARY_VIOLATION`) before the existing advisory `additionalContext` output;
  output and exit 0 preserved byte-identical.
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` — added a non-fatal recorder
  call (`HANDOFF_MISLOCATED`, expected log-only per D4) before the existing `exit 2`.
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` — added a non-fatal
  recorder call (`TASK_REFERENCE_IN_DELIVERABLE`) at each of the two `exit 2` sites (phase-pattern
  and task-pattern); fail-open behavior when the shared pattern library is unsourceable, and the
  final `exit 0`, are both unchanged.
- `agent-system/extensions/core/hooks/validate-plan-write.sh` — added `.cwd`/`.session_id`
  capture and a non-fatal recorder call (`ARTIFACT_FORMAT_VIOLATION`, expected log-only per D4)
  at the validation-errors branch; advisory `exit 0` unchanged.
- `agent-system/extensions/core/hooks/validate-state-sync.sh` — added `.cwd`/`.session_id`
  capture and a non-fatal recorder call (`STATE_SYNC_DIVERGENCE`, expected log-only per D4) at
  the malformed-JSON branch; the pre-existing `exit 1` there and the success-path `exit 0` are
  both unchanged.
- `agent-system/extensions/core/scripts/system-defect-record.sh` — fixed a pre-existing,
  unrelated defect: the D5 session-ID fallback re-implemented `sess_$(date +%s)_...` inline
  instead of calling the already-sourced `common_session_id` (`lib/common.sh`), violating the
  repo's single-source-of-truth assertion (`tests/test-common-lib.sh`). Swapped to
  `common_session_id`; output format (`sess_<epoch>_<6hex>`) is unchanged.
- `agent-system/extensions/core/index-entries.json` — corrected two stale `line_count` values
  left over from Phase 1 (`patterns/system-defect-discrimination.md`: 345 -> 382;
  `reference/orchestrator-critical-paths.json`: 62 -> 70), via
  `generate-context-line-counts.sh --write`.
- `specs/952_record_system_defects_durably_and_wire_detection_sites/plans/01_defect-recorder-and-wiring.md`
  — Phase 7 and Phase 8 headings marked `[COMPLETED]`, all task checklist items checked off with
  completion notes.
- `specs/952_record_system_defects_durably_and_wire_detection_sites/progress/phase-7-progress.json`,
  `phase-8-progress.json` — created.

## Decisions

- Inspected the prior dispatch's uncommitted Phase 7 work before touching anything (per the
  resume context) rather than redoing it: all five hooks' recorder wiring was already correctly
  authored — every exit-code contract, the shared `SCRIPT_DIR`-relative resolution idiom (mirrored
  from `hooks/events-log-lifecycle.sh`), and the `||`-guarded non-fatal call shape matched the
  plan exactly. This run's Phase 7 work was verification (`bash -n`, synthetic-stdin exit-contract
  regression for all five hooks, fail-open confirmation with the shared pattern library removed)
  and plan/progress bookkeeping, not further hook edits.
- For the Phase 8 dedup check, reproduced Phase 3's own verification shape (manually promoting a
  row's `linked_task_number` to point at a non-terminal task) rather than expecting a bare re-run
  to suppress. The recorder's `linked_task_number` is a hardcoded `null` at write time — this
  task's scope never promotes a detection to a task (Non-Goal: no `AskUserQuestion`, no task
  creation) — so per the discrimination document's own rule ("a prior matching event ... with no
  `linked_task_number` ... -> not a duplicate"), a bare re-run legitimately produces a fresh
  record, not a duplicate. Confirmed both behaviors explicitly.
- Fixed the two pre-existing defects discovered by Phase 8's own mandatory gate run (`index-entries.json`
  line_count drift, `system-defect-record.sh`'s non-single-source session-ID generator) rather
  than treating `verify-deploy.sh`'s FAIL as out of scope, since Phase 8 explicitly requires "all
  six gate commands exit 0" and both fixes are small, additive, source-store-only corrections
  within files this same task (952) authored or touched in earlier phases.

## Plan Deviations

- **Phase 8, `index-entries.json` line_count correction** (not itself a plan task, but required
  to satisfy the phase's gate requirement): `check-extension-docs.sh` failed with two stale
  `line_count` declarations for files Phase 1 modified
  (`patterns/system-defect-discrimination.md`, `reference/orchestrator-critical-paths.json`).
  Fixed via `bash .claude/scripts/generate-context-line-counts.sh --write` (the documented tool
  for exactly this correction). Metadata-only; no content change.
- **Phase 8, `system-defect-record.sh` session-ID single-source fix** (not itself a plan task,
  but required to satisfy the phase's gate requirement): `tests/run-all.sh` (part of
  `verify-deploy.sh`'s check 8) failed `test-common-lib.sh`'s single-source assertion because
  `system-defect-record.sh`'s D5 fallback re-implemented session-ID generation inline instead of
  calling the shared `common_session_id` (`lib/common.sh`), which the script already sources.
  Fixed by delegating to `common_session_id`; the `sess_<epoch>_<6hex>` output format is
  unchanged, and the positive/negative recorder tests were re-verified after the fix.

## Verification

- Build: N/A (shell scripts and markdown/hook wiring)
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/run-all.sh`: 29 passed, 0
  failed, 0 skipped
- Files verified: Yes — `bash -n` clean on all six modified `.sh` files; `git diff --name-only`
  for Phase 7 confirmed exactly the five hook paths (no `settings.json`, no `.claude/**`)

### Full gate set (Phase 8, final run)

- `bash .claude/scripts/verify-deploy.sh` — PASS, 19 check(s), 0 failure(s)
- `bash .claude/scripts/check-task-references.sh` — PASS, 0 unexempted occurrences
- `bash .claude/scripts/check-extension-docs.sh` — PASS, all extensions OK
- `bash .claude/scripts/lint/lint-agent-contracts.sh` — PASS, 33 passed / 0 failed
- `bash .claude/scripts/lint/lint-routing-wiring.sh` — PASS, 323 passed / 0 failed
- `bash -n` on every modified `.sh` — all clean
- `git status --short` — changes only under `agent-system/extensions/**` and `specs/**`; no
  tracked `.claude/**` change

### Positive/negative recorder proof (Phase 8)

- **Positive**: synthetic `.return-meta.json` `{"status":"planned","artifacts":["some/path.md"]}`
  -> `orchestrate-recover-outcome.sh` reports `evidence_reason == "ARTIFACTS_SHAPE_MISMATCH"` ->
  driving the Phase-4 consumer arm's exact recorder invocation produced **exactly one** new
  `specs/events.jsonl` line: `event_type: "system_defect"`, `category: "deviation"`,
  `detail.attributed_source_path: "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"`,
  `detail.defect_key: "ARTIFACTS_SHAPE_MISMATCH:agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"`.
- **Negative (`failed`, schema-conformant)**: `evidence_suspect: false`, `evidence_reason: "NONE"`
  — the consumer arm's `elif` never fires. Delta: **0**.
- **Negative (`partial`, schema-conformant)**: same — `evidence_suspect: false`,
  `evidence_reason: "NONE"`. Delta: **0**.
- **Dedup**: manually promoted the positive row's `linked_task_number` to task 952 (non-terminal
  in `state.json`), matching Phase 3's own verification shape; re-running the identical recorder
  call then correctly returned `SUPPRESSED:duplicate` with delta 0. A bare re-run without
  promotion is, by the discrimination document's own rule, NOT a duplicate (no linked task exists
  to protect) and correctly produced a fresh row — this is intentional recorder behavior, not a
  defect.
- **Cleanup**: `specs/events.jsonl` restored to its pre-Phase-8 committed line count (913) via
  `git show HEAD:specs/events.jsonl > specs/events.jsonl`; confirmed clean via
  `git status --porcelain`. No test rows persisted in the live event log.

## D4 Attribution-Outcome Table (actual results)

| Hook | Defect class | Attribution outcome (actual) | Why |
|---|---|---|---|
| `validate-meta-write.sh` | `SOURCE_STORE_BOUNDARY_VIOLATION` | **Attributed** | `FILE` (the offending `.claude/` write target) resolves under `agent-system/extensions/**` via the recorder's deploy->source transform |
| `validate-no-task-references.sh` | `TASK_REFERENCE_IN_DELIVERABLE` | **Attributed** | `--attributed-path` is the offending deliverable file itself |
| `validate-handoff-location.sh` | `HANDOFF_MISLOCATED` | **Log-only (expected)** | The misplaced handoff lives under `specs/**`, not the source store; no writer identity is available at a PostToolUse hook, so Signal B attribution deliberately fails closed |
| `validate-plan-write.sh` | `ARTIFACT_FORMAT_VIOLATION` | **Log-only (expected), and presently UNREACHABLE** | Same `specs/**` attribution gap as above by design (log-only). Additionally, a **pre-existing, unrelated defect** in this same file (`output=$(bash "$VALIDATOR" ...) || true; exit_code=$?`) always yields `exit_code=0` due to bash command-substitution exit-status semantics — the `case $exit_code in 1) ...` branch carrying the recorder call is currently dead code. This predates this task (present at `HEAD` before any Phase 7 edit) and was left unfixed as out of this task's declared scope (Phase 7 only adds recorder calls at existing detection sites; it does not repair site logic). Flagged here as a residual gap for a future task. |
| `validate-state-sync.sh` | `STATE_SYNC_DIVERGENCE` | **Log-only (expected)** | Same `specs/**` attribution gap by design; verified reachable (malformed `state.json` still exercises the branch and still exits 1 as before) |

Three of five hooks logging only (per D4) is the predicate working as designed, not breakage —
none of these sites has a resolvable writer identity at a PostToolUse hook.

## Known Residual Gaps

- **Handoff-present detection hole** (named as a Non-Goal at plan time): `skill-orchestrate/SKILL.md`'s
  handoff-present branch (Stage 5's `else`) never calls `orchestrate-recover-outcome.sh`, so
  `ARTIFACTS_SHAPE_MISMATCH` is never *computed* on that path — genuinely undetected, not merely
  unconsumed.
- **`ARTIFACTS_MISSING_ON_SUCCESS`** (named by the prerequisite's registry) has no detector
  anywhere in the codebase. The recorder's interface is general enough that a future detector
  needs no reshaping, but building one was out of scope here.
- **`validate-plan-write.sh`'s exit-code-capture bug** (discovered during this phase's own
  verification, described in the D4 table above): its `case 1)`/`case 2)` branches — including
  this task's own `ARTIFACT_FORMAT_VIOLATION` recorder call — are unreachable in practice because
  `exit_code` is always `0`. Pre-existing, unrelated to Deliverable 2(c), and left unfixed as
  outside this task's declared scope; recorded here so a future reader does not mistake the
  correctly-wired-but-unreachable recorder call for a wiring defect.

## Impacts

- Every detection site the prerequisite's registry classified as ready now durably records to
  `specs/events.jsonl` on a non-fatal, best-effort basis, without changing any existing hook's
  blocking/advisory contract or banner text.
- `ARTIFACTS_SHAPE_MISMATCH` now has a real consumer across all three reachable Stage-5/Stage-MT-4
  branches in both orchestration engines (base and hard mode).
- No task is ever created or surfaced by this recording pipeline (binding Non-Goal, verified: no
  `AskUserQuestion` was added anywhere).

## Follow-ups

- Consider a future task to fix `validate-plan-write.sh`'s exit-code-capture bug so its
  `ARTIFACT_FORMAT_VIOLATION` recorder call (and its own `additionalContext` diagnostic) actually
  fire.
- Consider a future task to close the handoff-present detection hole and/or build an
  `ARTIFACTS_MISSING_ON_SUCCESS` detector — both explicitly out of this task's scope.

## References

- `specs/952_record_system_defects_durably_and_wire_detection_sites/plans/01_defect-recorder-and-wiring.md`
- `specs/952_record_system_defects_durably_and_wire_detection_sites/reports/01_recorder-and-wiring-research.md`
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
- Progress files: `progress/phase-1-progress.json` through `progress/phase-8-progress.json`
