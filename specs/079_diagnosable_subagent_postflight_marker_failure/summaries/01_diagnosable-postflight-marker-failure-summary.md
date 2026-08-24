# Implementation Summary: Task #79

- **Task**: 79 - Make subagent-postflight hook diagnosable when its marker is malformed
- **Status**: [COMPLETED]
- **Started**: 2026-08-24
- **Completed**: 2026-08-24
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_diagnosable-postflight-marker-failure.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`subagent-postflight.sh` previously emitted an empty block reason whenever its
`.postflight-pending` marker failed to parse as JSON, because jq's `//` alternative operator
never fires on a parse error. The same malformed marker simultaneously blinded
`events-log-lifecycle.sh`'s telemetry, which silently exited with zero durable trace. This
implementation guards both hooks with an explicit `jq empty` parse-validity check, converges the
postflight hook's output on a single `jq -n --arg` construction, adds deviation-event telemetry
for the malformed-marker case, adds a registered 9-case regression suite, and documents the
hook-idiom survey and the two hooks' now-consistent (and intentionally divergent) handling.

## What Changed

- `agent-system/extensions/core/hooks/subagent-postflight.sh` — added a `jq empty` guard before
  the `.reason` extraction; a parse-failure branch builds a reason naming the marker path and
  jq's own error text; both branches converge on `jq -n --arg` output construction; removed the
  stale "no jq dependency" comment.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — the SubagentStop branch now
  distinguishes a malformed marker from `[ -z "$MARKER_FILE" ]`: on parse failure it derives the
  task number from the marker's parent directory, resolves `session_id` via
  `specs/state.json`'s `active_projects` lookup, and emits exactly one
  `malformed_postflight_marker` / `deviation` event (never blocking). Also fixed a `set -euo
  pipefail` trip discovered during manual verification: the `parse_err=$(... | head -1)`
  assignment needed an `|| true` guard since jq's non-zero parse-error exit inside the pipeline
  otherwise aborted the script under this file's stricter shell options (unlike
  `subagent-postflight.sh`, which has no `set -e`).
- `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` — new,
  registered suite: a fixture self-check plus cases (a)-(e) covering AC 1-3 and loop-guard
  interaction for `subagent-postflight.sh`, plus an events companion case covering AC 4. The
  events case runs against an isolated copy of the four files it needs
  (`events-log-lifecycle.sh`, `events-append.sh`, `deploy-root-guard.sh`, `lib/common.sh`)
  under a `<tmp>/.claude/...` fixture tree, since `events-append.sh`'s root resolution is
  anchored to its own script path (not cwd) and `deploy-root-guard.sh` refuses to run from a
  source-store path at all — driving it in place would either hard-fail or pollute the real
  repo's `specs/events.jsonl`.
- `agent-system/extensions/core/manifest.json` — registered the new test in the `tests/test-*.sh`
  list.
- `agent-system/extensions/core/context/patterns/postflight-control.md` — added "The `jq //`
  Parse-Error Hazard" subsection (the general rule, plus the re-counted survey: 52 occurrences
  across 13 hook files, 49 `// empty` + 2 `// ""` tolerant-by-design, exactly one now-fixed
  load-bearing-default site) and "Consistency Between the Two Hooks on a Malformed Marker"
  (documents the intentional control-vs-telemetry divergence and the residual no-`session_id`
  silent case); also expanded item 3 of the `## SubagentStop Hook Behavior` list to describe the
  three now-distinguishable reason cases.

## Decisions

- Followed the research report's settled design exactly: fail-closed with a diagnostic reason
  (the loop guard already bounds the entrapment risk after 3 continuations, independent of
  reason text); `jq -n --arg` for both hooks' JSON construction; task-number-from-path plus
  state.json session_id lookup for telemetry correlation.
- Left all 51 other `jq -r '... // empty'` / `// ""` sites unchanged, per the plan's Non-Goals —
  documented them as tolerant-by-design rather than rewriting.
- Designed the events-companion test case around an isolated `.claude`-shaped fixture copy
  rather than driving the deployed or source-store hook in place, after discovering that
  `events-append.sh`'s `deploy-root-guard.sh` unconditionally refuses source-store invocation
  and that its root resolution is anchored to script location, not cwd — neither of which is
  mentioned in the plan's Scope Hypothesis, and both of which would otherwise have caused the
  companion case to either hard-fail or write test rows into the real `specs/events.jsonl`.

## Plan Deviations

- **Phase 2**: discovered and fixed a `set -euo pipefail` script-abort bug in the new
  `events-log-lifecycle.sh` branch (the `parse_err=$(... | head -1)` pipeline needed `|| true`)
  during manual verification. Not specified in the plan's task list, but necessary for the
  branch to function at all; recorded in `progress/phase-2-progress.json`'s `approaches_tried`.
- **Phase 3**: the plan's Scope Hypothesis proposed following `test-guard-destructive-git.sh`'s
  direct-invocation structure uniformly. For the events companion case specifically, direct
  invocation was infeasible (see Decisions above); adapted to an isolated fixture-copy technique
  instead, as the Scope Hypothesis's own "adapt to the current code rather than restoring the
  shape described here" clause anticipates. All other cases use direct invocation as planned.
- No other deviations; all five phases completed as scoped.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-subagent-postflight-marker.sh` — 9/9 passed. Regression set: 5/5 adjacent suites
  passed (`test-postflight-marker-schema.sh`, `test-lint-postflight-boundary.sh`,
  `test-loop-guard-budget-override.sh`, `test-loop-guard-staleness.sh`) except
  `test-skill-base-lifecycle.sh`, which fails one pre-existing case
  (`skill_cleanup left at least one lifecycle temp file behind`) unrelated to this task's files —
  confirmed identical on the pre-Phase-1 commit, so not a regression introduced here.
- Non-vacuity: reverting both hooks to their pre-fix state (via `git show`, then restored)
  reproduced failures in cases (c), (d), and the events companion case, confirming the suite is
  not vacuous.
- Files verified: `bash -n` clean on both hooks and the new test; `jq empty` clean on
  `manifest.json`; no `.claude/**` modifications; zero task-reference occurrences outside
  `specs/**` (`check-task-references.sh` full-repo run).

## Impacts

- A blocked subagent facing a malformed postflight marker now sees a reason naming the marker
  path and the parse error, instead of an empty string.
- A malformed marker now leaves a durable `deviation` event in `specs/events.jsonl` (when a
  `session_id` is recoverable), closing a previously silent observability gap.
- No behavior change for well-formed markers (with or without `.reason`) or for any of the other
  51 surveyed `jq -r '... // ...'` sites.

## Follow-ups

- None required by this task. Two items explicitly out of scope per the plan's Non-Goals remain
  open for separate work: fixing whichever caller produces the key=value-shaped marker observed
  live, and factoring the duplicated `find specs -maxdepth 3 -name ".postflight-pending"`
  resolution into a shared helper.

## References

- specs/079_diagnosable_subagent_postflight_marker_failure/plans/01_diagnosable-postflight-marker-failure.md
- specs/079_diagnosable_subagent_postflight_marker_failure/reports/01_diagnosable-postflight-marker-failure.md
- specs/079_diagnosable_subagent_postflight_marker_failure/progress/phase-{1,2,3,4}-progress.json
