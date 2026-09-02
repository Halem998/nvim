# Implementation Summary: Task #90

- **Task**: 90 - Adoption lint for the shared task-lookup helper
- **Status**: [COMPLETED]
- **Started**: 2026-09-01
- **Completed**: 2026-09-01
- **Effort**: ~7 hours
- **Dependencies**: 124 (resolved)
- **Artifacts**: plans/01_task-lookup-adoption-lint.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built and landed `lint-task-lookup-adoption.sh`: a structural lint that detects the hand-rolled
full-record task-lookup jq shape (`.active_projects[] | select(.project_number == $num)` with
nothing piped after it) on executable surfaces, exempts the two canonical implementations
(`skill_validate_input()` in `skill-base.sh`, `gate_in()` in `command-gate-in.sh`) and four
legitimate jq shapes by construction, and carries a reasoned, per-entry-justified allowlist so it
lands green immediately. Wired as `verify-deploy.sh` gate 18 (gate 17 was already claimed by a
concurrent sibling task's scoped-commit-boundary lint) with a fixture-driven regression suite,
and migrated three verified-safe `SKILL.md` sites to the canonical helper as a bounded pilot.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` — new lint: dual-mode
  root resolution (source-store vs. deployed), executable-surface scan scope by construction,
  a balanced-paren-aware Layer 1 classifier, and a Layer 2 allowlist (64 entries after migration).
- `agent-system/extensions/core/scripts/tests/test-lint-task-lookup-adoption.sh` — new fixture
  suite, 18 assertions, picked up automatically by `run-all.sh`.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added gate 18, modeled line-for-line
  on gate 12's structure.
- `agent-system/extensions/core/manifest.json` — registered the lint and its test under
  `provides.scripts`.
- `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md` — new context doc
  naming the zero-tolerance vs. allowlist conventions and the decision rule between them.
- `agent-system/extensions/core/index-entries.json` — added the corresponding index entry.
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` — migrated its task lookup to
  `skill_validate_input()`.
- `agent-system/extensions/web/skills/skill-web-research/SKILL.md` — migrated (task_type default
  re-derived locally to preserve its "web" fallback, since `skill_validate_input()`'s own default
  is "general").
- `agent-system/extensions/web/skills/skill-web-implementation/SKILL.md` — migrated; its prior
  completed-only status check is now redundant with (and a strict subset of)
  `skill_validate_input()`'s terminal-state block, so it was removed as dead code.

## Decisions

- **Live re-measurement, not the report's numbers, is the basis for the allowlist and metrics.**
  Phase 1's plain-regex spot-check (63 files/69 occurrences, matching the research report closely)
  undercounted: the lint's own balanced-paren-aware classifier found 3 additional real narrow-
  pattern files (`core/agents/meta-builder-agent.md`, `core/skills/skill-status-sync/SKILL.md`,
  `web/skills/skill-web-implementation/SKILL.md`) that a plain regex missed on nested-`tonumber()`
  parens, plus several files with more than one narrow occurrence apiece. The accurate,
  allowlist-driving total was 67 files / 74 occurrences before migration.
- **Candidate pattern requires the equality comparison** (`select(.project_number ==`), not just
  any `select(.project_number`. A `select(.project_number as $pn | ... index ...)` membership
  test across a candidate list (found in `orchestrate-predispatch-review.sh`) is a structurally
  different operation, not a duplicate of either helper, and was excluded from candidacy rather
  than added as a fifth "legitimate shape" exemption.
- **In-place mutation detection covers both `|=` and `+=`**, and single-field/complex-read
  detection covers any further pipe (not only `| .field`), after live testing surfaced real
  offender-list false positives on both shapes (`.artifacts += [...]`, `| (.marker_a == "written"
  and ...)`) that a narrower classifier would have wrongly flagged as violations.
- **Two of five candidate `SKILL.md` sites were rejected, not migrated**: `skill-reviser`
  explicitly documents "no status-based ABORT rules... works regardless of task status", which
  `skill_validate_input()`'s terminal-state block would break; `skill-status-sync` exists
  specifically for recovery operations on tasks that may be in unusual states, and its own Stage 1
  never extracts task_type/project_name/status at all (unlike every migrated site). Both are
  recorded with reasons in `progress/phase-7-progress.json`'s `rejected_candidates`, per the
  plan's per-site judgment requirement.

## Plan Deviations

- **Task 5.1** altered: gate 17 was already claimed by `lint-scoped-commit-boundary.sh` (a
  concurrent sibling task in this batch); landed as gate 18 instead, using gate 12's exact
  wiring template as instructed.
- **Task 7 (exclusions branch)** skipped: three candidates qualified and were migrated, so the
  `[COMPLETED WITH EXCLUSIONS]` fallback branch was not taken.

## Verification

- Build: N/A (bash scripts)
- Tests: `test-lint-task-lookup-adoption.sh` (18/18 passed), `run-all.sh` (60/60 suites passed),
  `test-common-lib.sh` (30/30 passed, unchanged), `test-deploy-verify-wiring.sh` (9/9 passed)
- Deploy: `deploy-headless.sh` succeeded; `verify-deploy.sh` (full, 29 checks) shows gate 18
  passing with 2 remaining failures — both pre-existing, unrelated to this task (`validate-state.sh
  --deep` schema drift on `abandon_reason`/`blocks_note`, and `test-force-phases.sh`
  state-writer-boundary violations), confirmed via direct inspection to predate this work
- Files verified: Yes

## Direction Metrics (Before / After)

Measured with `lint-task-lookup-adoption.sh --verbose` (`EXCLUDED_FILES` temporarily emptied for
ground-truth counting; the live allowlisted run stays green throughout).

| Metric | Before | After | Command |
|---|---|---|---|
| Narrow-pattern duplicate files (executable surfaces) | 67 | 64 | `lint-task-lookup-adoption.sh --verbose` with `EXCLUDED_FILES=()`, unique file count |
| Narrow-pattern duplicate occurrences | 74 | 71 | same, total `[VIOLATION]` line count |
| Real `skill_validate_input()` callers | 0 | 3 | `grep -rn 'skill_validate_input' agent-system/extensions --include="*.sh" --include="*.md"` minus its own definition/docs |
| `gate_in()` adopters | 8 | 8 (unchanged; no `gate_in()` migrations attempted) | `grep -rl 'command-gate-in.sh' agent-system/extensions/core/commands agent-system/extensions/core/skills` |

Full detail (grouped offender list, per-file reasons, rejected-candidate evidence) is in
`progress/phase-1-scratch-measurements.md` and `progress/phase-7-progress.json`.

## Impacts

- A newly introduced full-record task-lookup on an executable surface now fails `verify-deploy.sh`
  gate 18, preventing the duplication class from regrowing.
- Three real call sites now delegate to `skill_validate_input()` instead of hand-rolling the
  lookup, reducing (not eliminating) the duplication class.
- The bulk lifecycle-`SKILL.md` migration (skill-researcher/planner/implementer and their `-hard`
  variants, skill-orchestrate-hard) remains deferred pending the core-collapse sequencing decision
  (task 116's deletion ledger), per the plan's explicit non-goal and this dispatch's territory
  boundary (task 125).

## Follow-ups

- When the core-collapse deletion lands (or is abandoned), re-run the lint with
  `EXCLUDED_FILES=()` to re-derive the offender count and update the allowlist accordingly.
- `skill-reviser` and `skill-status-sync` remain hand-rolled by design; if either skill's
  documented status-handling contract changes, they become new migration candidates.
- `orchestrate-predispatch-review.sh`'s membership-test `select(.project_number as $pn | ...)`
  shape is intentionally out of this lint's scope; if a future adoption lint targets that shape
  too, it needs its own classifier, not an extension of this one.

## References

- `specs/090_adoption_lint_for_shared_task_lookup_helper/plans/01_task-lookup-adoption-lint.md`
- `specs/090_adoption_lint_for_shared_task_lookup_helper/reports/01_task-lookup-adoption-lint.md`
- `specs/090_adoption_lint_for_shared_task_lookup_helper/progress/phase-1-scratch-measurements.md`
- `specs/090_adoption_lint_for_shared_task_lookup_helper/progress/phase-7-progress.json`
- `agent-system/extensions/core/context/patterns/adoption-lint-conventions.md`
