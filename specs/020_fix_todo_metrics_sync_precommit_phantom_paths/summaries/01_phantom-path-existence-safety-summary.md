# Implementation Summary: Task #20

- **Task**: 20 - Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T23:08:08Z
- **Completed**: 2026-09-03T00:20:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_phantom-path-existence-safety.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

Implemented all 4 phases of the plan making `assess-repo-health.sh` existence-safe against
`git ls-files`' index/worktree divergence, surfacing dropped candidates as a new `phantom_paths`
diagnostic, re-sequencing `/todo`'s metrics sync to run after its own commit with a dedicated
follow-up commit, and locking both directions with three new git-fixture regression cases. All
work landed under `agent-system/extensions/core/**` (never `.claude/**`), verified with a
`git status --short .claude/` check at every phase boundary.

## What Changed

- `agent-system/extensions/core/scripts/assess-repo-health.sh` — Filtered `SH_FILES`/`JSON_FILES`
  for on-disk existence at their single population site via a new `populate_filtered()` helper
  (nameref-based, fed through process substitution rather than a pipe — see Decisions below),
  tracking dropped candidates in a `phantom_paths` counter. `total_candidates` now reflects only
  real candidates, so the all-phantom case correctly reports the pre-existing degenerate
  `build_errors: null` / `status: "unknown"` branch rather than a false `critical`. Emits
  `phantom_paths` as a fifth, always-integer key. Header block (`Output`, `Enumeration`,
  `Degenerate case` sections) and the cross-reference to `commands/todo.md`'s step number both
  updated. `count_marker()` left unchanged with a comment explaining why.
- `agent-system/extensions/core/context/schemas/state-schema.json` — Added `phantom_paths`
  (`"type": "integer"`) to `repository_health.properties`, satisfying its
  `additionalProperties: false` constraint.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — Added the
  matching `phantom_paths` row to the Repository Health Fields table.
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` — Added a git-fixture
  helper (`git_fixture_init`/`git_fixture_commit`) and three new cases (Bar 4/5/6), the suite's
  first fixtures built as real git work trees rather than `mktemp -d` directories, exercising the
  `git ls-files` enumeration path specifically. Updated the header `Cases:` block.
- `agent-system/extensions/core/commands/todo.md` — Relocated `### 5.6. Sync Repository Metrics`
  to `### 6.5. Sync Repository Metrics`, now running after Step 6's archival commit instead of
  before it. Added a rationale paragraph, a new metrics-only commit substep
  (`git-commit-scoped.sh` scoped to `specs/state.json`, message `todo: sync repository metrics`),
  non-blocking-failure prose, and `metrics_phantom_paths` to the tracked output values. Fixed the
  Step 5.7 vault section's cross-reference to the new step number.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — Updated the
  `(Step 5.6.1)` cross-reference to `(Step 6.5.1)`.

## Decisions

- **Pipe-subshell bug caught and fixed during Phase 1**: the first `SH_FILES`/`JSON_FILES`
  population attempt piped `enumerate_by_glob | filter_existing`, but bash runs the right side of
  a `|` in a subshell — a counter incremented there is invisible to the parent shell once the
  pipe exits, so `phantom_paths` would have silently stayed 0 forever. Replaced with a
  nameref-based `populate_filtered()` function fed via `< <(...)` process substitution instead,
  which keeps the `while` loop (and its counter writes) in the current shell. Caught by direct
  manual testing before any test-suite run; recorded as a memory candidate below.
- **Phase 2's "phantom-only" fixture deviates from the plan's literal wording**: the plan
  describes committing exactly one file, then moving it — but that shape has zero real candidates
  remaining after Phase 1's filter, which correctly hits the degenerate `build_errors: null` /
  `status: "unknown"` branch (that is Bar 6's subject), not the `build_errors == 0` /
  `status == "healthy"` the case asserts. Added a companion untouched valid `*.sh` to Bar 4's
  fixture so `total_candidates` stays nonzero, matching the case's actual intent. Verified against
  the negative control that this still fails against the pre-fix script. Recorded in the plan's
  Phase 2 checklist and the phase-2 progress file's `deviations` array.
- **Phase 4's first evidence fixture hit the same degenerate-branch pitfall**: an initial
  reduced-scale fixture with no untouched companion file produced a trivial
  `null`-vs-`0` "disagreement" between the pre-commit and post-commit post-fix readings, which
  wasn't a meaningful comparison (the disagreement was Bar 6's phenomenon, not a Phase 3 defect).
  Rebuilt with a companion `stable.sh`, producing a genuine agree/disagree comparison
  (`build_errors: 0` / `status: healthy` in both readings).

## Plan Deviations

- **Task 2.2** (Phase 2, "phantom-only" case) altered: added a companion untouched valid `*.sh`
  file to the fixture so `total_candidates` stays nonzero post-filter, producing the
  `build_errors == 0` / `status == "healthy"` the case asserts, rather than hitting the
  all-phantom degenerate branch the literal single-file fixture would trigger. See Decisions
  above and `progress/phase-2-progress.json`'s `deviations[0]`.

## Verification

- Build: N/A (bash/markdown/JSON, no build step)
- Tests: Passed — `test-assess-repo-health.sh` exits 0, 24 passed / 0 failed, including the three
  new git-fixture cases (Bar 4/5/6)
- Files verified: Yes — every modified file confirmed to exist and contain the expected changes;
  `bash -n` clean on `assess-repo-health.sh` and every bash block extracted from the relocated
  `todo.md` section; `jq empty` clean on `state-schema.json`

### Measured before/after evidence (Phase 4)

Reduced-scale git fixture (3 tracked structural candidates under a directory, plus one untouched
companion file, moved without staging):

| Reading | build_errors | status | phantom_paths |
|---|---|---|---|
| Pre-fix probe (parent commit, pre-commit tree) | 3 | critical | (field did not exist) |
| Post-fix probe, pre-commit tree | 0 | healthy | 3 |
| Post-fix probe, post-commit tree | 0 | healthy | 0 |

The two post-fix readings agree on `build_errors` and `status` — the task's stated acceptance
condition. Reverse-direction check (a genuinely broken file added alongside an unrelated moved
file): `build_errors: 1`, `status: critical`, `phantom_paths: 1` — the real defect is still
counted exactly once.

Negative control: both the Bar 4-shaped and Bar 6-shaped fixtures were run against the pre-Phase-1
script (`git show`'d from the parent commit) and confirmed to report `build_errors: 1` /
`status: critical` with no `phantom_paths` field at all — proving the new assertions are genuine
regression locks, not tautologies.

`validate-state.sh --deep` against a synthetic `state.json` whose `repository_health` carries
`phantom_paths`: exit 0, 0 failures (3 WARN findings, all unrelated to the schema addition —
caused by the synthetic fixture lacking a git worktree and sibling TODO.md).

`grep -rln "assess-repo-health" agent-system/` re-confirms `commands/todo.md` is the sole
production caller (the other hits are the script itself, its test suite, docs inventory
self-reference, and `manifest.json`'s file-copy registration, not a caller).

The Step 5A `--argjson` argument-length defect named in the task description was verified closed
upstream by the research pass (against the `state-write.sh` transparent-spill fix and its
regression suites) and is deliberately untouched by this plan.

## Impacts

- `/todo` runs will no longer report inflated `build_errors`/`status: critical` for uncommitted
  directory moves that occur during its own archival/vault steps — the exact defect the task
  reported (184 phantom paths in production).
- `repository_health.phantom_paths` is now a visible diagnostic distinguishing "moved but not yet
  committed" from "actually broken," for any future consumer of `state.json`'s health snapshot.
- `assess-repo-health.sh`'s existence-safety fix benefits every caller of the script, not just
  `/todo` (though `/todo` is currently the only production caller).

## Follow-ups

- None required by this task. The research report's suggestion to add a general
  "existence-check requirement for `git ls-files` enumerators" subsection to
  `context/standards/census-methodology.md` is explicitly out of scope (see the plan's
  Non-Goals) and left as a candidate future task.

## References

- `specs/020_fix_todo_metrics_sync_precommit_phantom_paths/plans/01_phantom-path-existence-safety.md`
- `specs/020_fix_todo_metrics_sync_precommit_phantom_paths/reports/01_metrics-sync-phantom-paths.md`
- `specs/020_fix_todo_metrics_sync_precommit_phantom_paths/progress/phase-{1,2,3,4}-progress.json`
- Commits: `ae2986612` (phase 1), `c56823b03` (phase 2), `8c399254b` (phase 3), `d043a99d4` (phase 4)
