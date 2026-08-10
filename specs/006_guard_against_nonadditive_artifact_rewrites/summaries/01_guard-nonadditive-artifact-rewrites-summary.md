# Implementation Summary: Task #6

- **Task**: 6 - guard_against_nonadditive_artifact_rewrites
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T22:38:00Z
- **Completed**: 2026-08-11T00:06:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None (task 5 is adjacent but shares no code surface)
- **Artifacts**: plans/01_guard-nonadditive-artifact-rewrites.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a writer-agnostic, content-inspecting invariant that detects net artifact-link loss in
`specs/state.json`: a new FAIL-level `--deep` check (D5) in `validate-state.sh` requiring, per
`project_number` and per artifact `type`, that the count of paths removed relative to the prior
git-committed version never exceed the count added. A repeatable
`--allow-artifact-removal <project_number>[:<type>]` CLI opt-in makes genuine deletion
expressible. All five plan phases completed: baseline triage, the check itself, bidirectional
fixture tests, prose/agent-contract updates, and end-to-end integration verification against the
deployed pipeline.

## What Changed

- `agent-system/extensions/core/scripts/validate-state.sh` — new `--allow-artifact-removal` flag
  parsing (repeatable, `<project_number>[:<type>]` form, hard error exit 2 on malformed input),
  new D5 per-type artifact-loss check inside the existing `--deep` D4 git block (reuses the same
  `prior_json`), header comment and `--help` line-range updates (`2,57p` -> `2,74p`).
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — new source-store-first
  `D5_VALIDATOR_CANDIDATES` resolution (grepped for the "Check D5" identifier before trusting, so
  a stale deployed copy cannot produce a false green), a git-backed fixture helper
  (`make_d5_baseline`), and six new fixture cases: negative (rejection, raw `jq`-composed write),
  positive (identical write accepted under the opt-in flag), regression (1-for-1 same-type
  supersession), pure-append, untyped-entry (sentinel grouping), and scoped-flag (wrong-type
  opt-in does not over-permit).
- `agent-system/extensions/core/rules/state-management.md` — new "Artifacts Are Append-Only (With
  Same-Type Supersession)" subsection stating the append-only contract, the sanctioned exception,
  the prohibition on wholesale `.artifacts = [...]` assignment, the enforcement mechanism, and the
  periodic-enforcement limitation.
- `agent-system/extensions/core/scripts/skill-base.sh` — comment-only addition above
  `skill_link_artifacts`'s two-step block explaining why its same-type removal is exempt by
  construction under the new invariant (no functional change; verified via diff).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — new MUST NOT bullet 8
  against wholesale `.artifacts` assignment.

## Decisions

- Per-type count invariant (`removed(T) <= added(T)`), not a strict global path-superset rule,
  because every sanctioned writer's same-type remove-then-add idiom would otherwise fail —
  adopted from the research report's Finding 1-2.
- FAIL-level, not WARN-level: Phase 1's empirical baseline probe found zero violating
  `(project_number, type)` pairs in the live `specs/state.json` against its prior committed
  version, satisfying the plan's pre-declared decision rule for landing FAIL-level.
- D5 lives in `validate-state.sh --deep`, reusing D4's already-fetched `prior_json`, rather than
  in `state-write.sh` — content inspection is writer-agnostic by construction and fires
  identically on a hand-composed `jq ... > tmp && mv` write, which is the exact observed failure
  mode this task exists to catch.
- Untyped entries (absent/null `.type`) are grouped under an explicit sentinel key `(untyped)` so
  they participate in the invariant instead of being silently excluded.
- The bidirectional fixture tests resolve a dedicated, source-store-first validator candidate
  list (distinct from the suite's existing deployed-first `$VALIDATOR`), so the fixtures can
  genuinely execute and pass without depending on a prior deploy step, while still guarding
  against a stale copy via an explicit grep-for-identifier check.

## Plan Deviations

- **Phase 3's Scope Hypothesis** estimated seven new fixture cases; the actual, reported number is
  six (the phase's own Tasks list enumerates exactly six named fixtures — negative, positive,
  regression, pure-append, untyped, scoped). Reported per the hypothesis's own instruction to
  state the real count.
- **Phase 5's `verify-deploy.sh` gate 10 check**: the plan anticipated PASS or PASS-with-warning;
  the actual result is FAIL, but for a pre-existing, unrelated D3 dangling-dependency finding
  (project 9 depends on project 1015, which is absent from both `active_projects` and the
  archive) that predates this task's changes and was already present in Phase 1's control-run
  baseline. The new D5 check itself reports zero findings against the live state. Fixing project
  9's dependency graph is outside this task's declared file scope and Non-Goals, so it was left
  untouched and reported honestly rather than silently patched.

## Verification

- Build: N/A (bash scripts and markdown only)
- Tests: Passed — `bash .claude/scripts/tests/test-validate-state.sh` (deployed copy): 14 passed,
  0 failed, exit 0. Both directions of the verification bar visibly executed in the same run,
  plus four regression/edge-case fixtures.
- Files verified: Yes — `bash -n` clean on all three shell scripts; `--help` output diffed against
  the header comment (no truncation, no code leakage); `check-task-references.sh` and
  `lint-agent-contracts.sh` both exit 0; `skill-base.sh`'s diff confirmed comment-only.

## Impacts

- `verify-deploy.sh` gate 10 now additionally enforces artifact-link append-only integrity on
  every deploy verification run, FAIL-level, for any repo whose `specs/state.json` has git
  history.
- Any future direct `jq`-composed write to `specs/state.json` (bypassing `state-write.sh` and the
  sanctioned helpers) that nets artifact-link loss will now be caught by `validate-state.sh
  --deep`, closing the exact silent-loss failure mode this task's premise describes — subject to
  the named periodic-enforcement limitation below.
- The four existing sanctioned artifact-writing call sites (`skill_link_artifacts`,
  `orchestrator-postflight.sh` Stage 8, `link_artifact` in `reconcile-task-status.sh`,
  `skill-reviser/SKILL.md` Stage 8) are functionally unchanged and confirmed, via both fixture
  tests and a live end-to-end round trip through the real `state-write.sh`, to produce no finding
  under the new check.

## Follow-ups

- **Accepted limitation (restated per Phase 5's requirement)**: enforcement is periodic, not
  write-time. It runs only when `validate-state.sh --deep` is invoked (currently via
  `verify-deploy.sh` gate 10), so a lossy direct-`jq` write can still land between validation
  passes, and a subsequent legitimate commit moves the comparison baseline forward, potentially
  hiding an earlier loss from a later diff. Closing this fully would require a synchronous
  (write-time) enforcement path, which was deliberately out of scope for this task.
- The pre-existing, unrelated dangling-dependency finding on project 9 (`9 -> 1015`) remains
  unresolved — it is orthogonal to this task's scope and should be triaged separately.
- Not pursued (per the plan's stated Non-Goals): converting any of the four sanctioned writers to
  `state-write.sh`; modifying `state-write.sh` or `context/schemas/state-schema.json`; detecting
  adversarial 1-for-1 substitution (a known, bounded blind spot of the count-based rule).

## References

- Plan: `specs/006_guard_against_nonadditive_artifact_rewrites/plans/01_guard-nonadditive-artifact-rewrites.md`
- Research report: `specs/006_guard_against_nonadditive_artifact_rewrites/reports/01_guard-nonadditive-artifact-rewrites.md`
- Progress files: `specs/006_guard_against_nonadditive_artifact_rewrites/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/006_guard_against_nonadditive_artifact_rewrites/handoffs/phase-{1..5}-handoff-*.md`
