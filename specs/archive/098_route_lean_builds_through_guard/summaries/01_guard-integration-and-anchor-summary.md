# Implementation Summary: Task #98

- **Task**: 98 - Route lean extension builds through the guard and rewrite the multi-instance operations anchor
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T16:45:52Z
- **Completed**: 2026-08-25T18:30:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: 97 (lake-build-guard.sh — complete, shipped)
- **Artifacts**: plans/01_guard-integration-and-anchor.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wired the shared Lean build guard (`agent-system/extensions/core/scripts/lake-build-guard.sh`)
into its first consumer, `lean-sorry-census.sh`'s `--cross-check` branch, with a three-way
graceful-degradation branch and a test-seam env var. Extended the regression suite with four new
fixtures proven non-vacuous via a falsifiability gate run against the unmodified script. Recorded
the "no lean lifecycle hook" decision with its four reasons and verified the manifest needs no
edit. Rewrote `multi-instance-optimization.md` from human-advisory prose into guard mechanism
documentation with corrected, measurement-backed figures.

## What Changed

- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` — resolves `GUARD_BIN` (overridable
  via `LEAN_SORRY_CENSUS_GUARD_BIN`), implements a three-way `--cross-check` branch (lake absent /
  lake present+guard absent / both present, routing through `"$GUARD_BIN" build -- build`),
  extends the non-zero warning to name the guard when the guarded path was taken, and documents
  the routing and env var in the header.
- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` — added Fixtures F
  (lake absent), G (lake present/guard absent), H (both present), and I (guarded non-zero exit),
  plus `make_isolated_bin_without_lake`, `make_synthetic_lean_project`, `make_stub_lake`, and
  `make_stub_guard` helpers. All 14 assertions pass (Passed: 14, Failed: 0).
- `agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md`
  — full rewrite: preserved Overview/Root Cause/Monitoring/MCP-env-config; deleted the
  human-advisory remedies; added "The Build Guard" mechanism section, "Invoking the guard",
  "Detached builds and the guard: they must land together" (the amplification interaction),
  "What an operator can still do by hand" (manual fallback), "Measured Results" (29.9 GB
  illustrative figure replacing the falsified 8GB/16GB+/60-80% claims), a forward reference to
  `operations/long-builds.md` by filename only, and "Why there is no lean lifecycle hook" (the
  four-reason decision record).
- `agent-system/extensions/lean/manifest.json` — confirmed unchanged (verified via `jq`, not
  assumed): `has("hooks")` is `false`, `provides.hooks` is `[]`.

## Decisions

- No lean lifecycle hook is added. Hook resolution keys strictly on `task_type == "lean4"` so a
  `meta`-typed task (like this one) would get nothing; hooks are non-blocking by design so a
  preflight hook cannot enforce a refusal; the guard's own PSI/swap preflight is already directly
  invocable without hook machinery; and any real refusal obligation belongs in contract text this
  scope does not own. Recorded in the anchor doc's "Why there is no lean lifecycle hook" section.
- Fixture H proves the guarded path was taken indirectly (a distinctive `compiler_sorry_count`
  value from the guard stub, differing from both Fixture G's and the unused plain-lake stub's
  counts) rather than by grepping for the guard stub's marker line in the census script's own
  output — the marker is trapped inside the internal `BUILD_OUTPUT` capture, which the production
  script correctly never echoes verbatim.
- The census call site passes `-- build` explicitly and does not pass `--dir`, `--memory-bound`,
  `--defer-on-pressure`, or `--no-share`: memory bounding stays opt-in/off here because the census
  is a verification read-out whose value is a correct count, and an aborted/deferred build would
  silently under-count rather than fail loudly.

## Plan Deviations

- None (implementation followed plan). One correction was made mid-Phase-1/2 to how Fixture F
  isolates `lake` from `PATH` (see progress files' `approaches_tried`), but this was a fixture
  implementation detail, not a deviation from any plan task or verification criterion — all Phase
  1 and Phase 2 tasks were completed exactly as specified.

## Verification

- Build: N/A (shell scripts + markdown; no build step)
- Tests: Passed — `test-lean-sorry-census.sh` exits 0, all 14 assertions (Fixtures A-I) green
- `bash -n`: clean on both changed scripts
- `shellcheck`: identical finding set to pre-change baseline on both scripts (0 new findings)
- Files verified: Yes — all four `file_scope` entries checked; `manifest.json` confirmed
  unchanged via `jq`
- Scope: this task's own four commits touch only the three intended source files (plus
  `specs/098_.../` task artifacts); no `.claude/**` path; none of the eight background-builds
  contract files touched
- Task-reference lint: zero matches across all changed source files

## Impacts

- `lean-sorry-census.sh --cross-check` now serializes against other concurrent `lake build`
  invocations of the same project when the guard is deployed, with opt-in memory-pressure
  awareness inherited from the guard, while remaining fully functional in a repo where the guard
  has not been deployed.
- `multi-instance-optimization.md` now documents an actual, invocable mechanism instead of
  advice a human must remember to follow, and no longer asserts memory figures contradicted by
  the 29.9 GB measurement on record.
- Establishes the guard-integration pattern (env-var test seam, three-way degrade, extended
  warning naming the guard) that the background-builds task's own eight contract-file edits can
  follow at their own call sites.

## Follow-ups

- None within this task's scope. The reverse cross-reference (from `operations/long-builds.md`
  back to this anchor) is owned by the concurrent background-builds task; `long-builds.md` was
  observed to already exist on disk during the Phase 5 sweep, created by that task's own commit
  (`c82663d3c`), not by this task.

## References

- `specs/098_route_lean_builds_through_guard/reports/01_route-census-through-guard.md`
- `specs/098_route_lean_builds_through_guard/plans/01_guard-integration-and-anchor.md`
- `specs/098_route_lean_builds_through_guard/progress/phase-{1,2,3,4,5}-progress.json`
