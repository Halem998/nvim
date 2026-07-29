# Implementation Summary: Task #945

- **Task**: 945 - Converge conflict detection onto one bounded predicate over locks, registry, and state
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T00:36:20Z
- **Completed**: 2026-07-29T03:32:20Z
- **Effort**: ~11.5 hours (as estimated)
- **Dependencies**: 944 (session registry — landed)
- **Artifacts**: plans/01_converge-conflict-predicate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Converged the twice-transcribed directory-prefix overlap predicate (`task-lock.sh`'s
`scopes_overlap()` and `orchestrate-batch-admit.sh`'s inline `scopes_overlap_first`) into one
shared library, `scripts/lib/file-scope-overlap.sh`, and extended it with the session registry as
a third bounded contention input consumed by both `task-lock.sh acquire` and
`orchestrate-batch-admit.sh`. The verdict schema bumped to `orchestrate-batch-admit-v4` with a new
`session_active` defer flavor and a `corroborated_by` evidence field on the existing collision
defer. Batch admission was also wired into the three plain multi-task command paths
(`/research`, `/plan`, `/implement`) that previously had only per-task locking, plus a fix to
`/orchestrate`'s real dispatch path (both standard and hard mode) which had never passed
`--session-id` at all. All 9 phases completed; the isolated-temp-root test suite
(`test-conflict-predicate.sh`, 23 cases) and all four pre-existing gate suites pass.

## What Changed

- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` — NEW. Single shared
  implementation: `scopes_overlap()` (bash), `FILE_SCOPE_OVERLAP_JQ_DEFS` (jq `norm`,
  `scopes_overlap_first`, `self_mod_match`, `edge_connected_nums`, `session_contention`).
- `agent-system/extensions/core/scripts/task-lock.sh` — deleted the local `scopes_overlap()`,
  added a lazy `ensure_file_scope_overlap_lib()` loader (scoped to `cmd_acquire` only, so
  `reap`/`session-*` never depend on the lib), factored `session_liveness()` out of
  `cmd_session_reap`, added `cmd_session_list` (the registry's first reader) and the
  `session-list` dispatch verb, and wired a session-registry contention pass into `cmd_acquire`.
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — spliced the shared lib,
  added `--session-id`, a session-registry pass reached only when the state.json collision scan
  finds no hit, `corroborated_by` on the collision verdict, and bumped every `$schema` literal to
  `orchestrate-batch-admit-v4`.
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — added an optional
  `--session-id` passthrough (forwarded only when the caller explicitly supplies it, distinct
  from this script's own pre-existing auto-generated `--repair`-mutex fallback), a new Class E
  section re-presenting `session_active` verdicts, and `corroborated_by` rendering on Class D.
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — fixed a real bug found
  during verification: the pre-existing `defer_reason` branching fell through unconditionally
  into `file_scope_collision` field reads with no `session_active` case, mis-bucketing that
  verdict as an in-batch Note instead of the Excluded entry it actually is. Added the missing
  branch, `--session-id` passthrough to both its own and its `orchestrate-predispatch-review.sh`
  subprocess call, and `corroborated_by` rendering.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — NEW. Isolated-temp-root
  suite, 23 cases across 8 groups (overlap parity, bit-for-bit preservation, non-regression shape,
  D4 session-input exclusions, D6 degradation, `session-list` output, fail-closed, deploy
  reachability).
- `agent-system/extensions/core/manifest.json` — added `lib/file-scope-overlap.sh` and
  `test-conflict-predicate.sh` to `provides.scripts`. Root-cause fix for a loader-copy gap
  previously worked around with manual one-off copies (see Decisions below).
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md` — added a "Step
  2.5: Batch Admission Pre-Check (Gap C)" between session-register and the per-task acquire loop.
- `agent-system/extensions/core/commands/orchestrate.md` — added `--session-id` to the
  illustrative batch-admit block and a `session_active` bullet to its defer-reason prose.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the REAL executing
  counterpart to `orchestrate.md`'s illustrative block: added `--session-id "$session_id"` to
  Stage MT-3 step 4.5's live call and a `session_active` defer_reason branch.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — same fix, applied per
  this file's own explicit co-maintenance mandate with the base skill.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`,
  `context/patterns/task-lock.md`, `docs/architecture/batch-admit-schema.md`,
  `context/patterns/batch-orchestration-guardrails.md` — converged onto the single implementation
  and the three-input model; `task-lock.md`'s "Non-Goal: No Reader" section replaced with the
  reader's contract; schema doc bumped to v4 with a full "v3 to v4" Version History entry.

## Decisions

- Lazy-loaded the shared lib inside `task-lock.sh` (only within `cmd_acquire`, on first use) rather
  than unconditionally at file-top as the plan's literal task text suggested — an unconditional
  source broke `test-task-lock-reap.sh`/`test-session-registry.sh`, whose fixtures never copy the
  new lib dependency and whose exercised subcommands (`reap`, `session-*`) never used
  `scopes_overlap()` in the first place.
- Isolated each test group's fixture `file_scope` into its own namespace (`g21/`, `g22/`, `g23/`,
  `g4/`) after an initial shared-namespace design caused cross-group contamination in the new test
  suite.
- Tested the "corrupt session DOES contend" D4 property at the jq-harness level (calling
  `session_contention()` directly), not through the full integration path — a real corrupt
  session-registry entry structurally can never carry `file_scope` data, so it can never produce
  an observable overlap hit end-to-end regardless of whether the exclusion logic is correct.
- Root-caused the "known extension-loader gap" for new `scripts/` files: it is not an inherent
  property of already-loaded extensions, but a missing `provides.scripts` entry in
  `manifest.json`. Fixed at the source rather than continuing to rely on the one-off manual-copy
  workaround the plan anticipated.

## Plan Deviations

- Phase 1: lazy lib-loading in `task-lock.sh` instead of unconditional top-of-file sourcing (see
  Decisions above) — required to keep the two gate test suites passing unchanged.
- Phase 4: `--session-id` is passed to `task-lock.sh session-list` via `jq -s -c` over piped
  NDJSON rather than `--slurpfile`, since `session-list`'s output is a subprocess stdout stream,
  not a file path.
- Phase 6/7/9: expanded beyond the literally declared file lists after empirical verification
  surfaced real defects — `orchestrate-dry-run-report.sh`'s fallthrough mis-bucketing bug (Phase
  6), `skill-orchestrate/SKILL.md`'s real dispatch path never having received `--session-id` at
  all (Phase 7), and `skill-orchestrate-hard/SKILL.md`'s co-maintained transcription lagging the
  base skill fix (Phase 9). Each expansion is recorded in its phase's completion notes with the
  reasoning for why fixing it was in scope rather than a deferred follow-up.
- Phase 8/9: added `manifest.json` to `provides.scripts` for the two new script files — not a
  pre-declared file, but the actual root-cause fix for the loader-copy gap the plan's Risks table
  and D1 decision anticipated working around manually.

## Verification

- Build: N/A (shell scripts and markdown)
- Tests: `test-conflict-predicate.sh` (23/23), `test-task-lock-reap.sh` (6/6),
  `test-session-registry.sh` (10/10), `test-session-runtime-files.sh` (6/6),
  `test-state-write-concurrency.sh` (4/4) — all passed
- Files verified: Yes — every path introduced or referenced across all four converged
  documentation files resolves to a real file
- `check-task-references.sh`: PASS (0 unexempted occurrences)
- `check-extension-docs.sh` / `verify-deploy.sh`: `core` extension PASS; the only remaining
  failure is the pre-existing, unrelated `literature` extension `.pyc`-cache issue documented in
  a prior task's summary

## Impacts

- `/research N,M`, `/plan N,M`, `/implement N,M`, and `/orchestrate` (both modes) now consult a
  bounded, three-input conflict-detection predicate before dispatch, closing the gap where only
  per-task locking existed before.
- The conflict-detection algorithm now lives in exactly one physical location, eliminating the
  risk of the two prior transcriptions silently drifting apart.
- Downstream report composers (`orchestrate-predispatch-review.sh`,
  `orchestrate-dry-run-report.sh`) surface the new session-registry evidence in their
  human-readable output.

## Follow-ups

- None outstanding — every consumer this task's own scope named was either verified safe,
  extended, or fixed. (See Decisions/Deviations above for what was found and closed rather than
  deferred.)

## References

- `specs/945_converge_conflict_detection_predicate/plans/01_converge-conflict-predicate.md`
- `specs/945_converge_conflict_detection_predicate/reports/01_converge-conflict-predicate.md`
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
