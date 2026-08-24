# Implementation Plan: Task #79

- **Task**: 79 - Make subagent-postflight hook diagnosable when its marker is malformed
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: Sequenced after the subagent-postflight marker-ownership/correlation task
  (same file, adjacent region of `find_marker()`/`main()`). No state.json dependency edge is
  recorded; the constraint is a re-read obligation in Phase 1, not a hard block.
- **Research Inputs**: specs/079_diagnosable_subagent_postflight_marker_failure/reports/01_diagnosable-postflight-marker-failure.md
- **Artifacts**: plans/01_diagnosable-postflight-marker-failure.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-script-testing.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`subagent-postflight.sh` emits `{"decision": "block", "reason": ""}` whenever the postflight
marker fails to parse as JSON, because jq's `//` alternative operator never fires on a parse
error and `2>/dev/null` swallows jq's diagnostic. The blocked subagent sees "Blocked by hook"
with no explanation. The same malformed marker simultaneously blinds `events-log-lifecycle.sh`,
whose (correct) `jq empty` guard consequences to `exit_success` — zero durable trace. This plan
fixes both channels using patterns already present in the repository (`jq empty` pre-check;
path-derived task number plus `specs/state.json` session_id lookup), adds a subprocess-driven
regression suite, and closes the hook-idiom survey by documenting the 51 tolerant-by-design
sites rather than rewriting them.

Definition of done: a malformed marker produces (a) a non-empty block reason naming the marker
path and the parse error, (b) exactly one `deviation`-category event in `specs/events.jsonl`
when a `session_id` is recoverable, (c) valid JSON on stdout for every marker content, all
covered by a registered test suite, with the survey and the two hooks' now-consistent handling
documented.

### Research Integration

The research report settles every open design question, so this plan carries decisions, not
options:

- **Fix shape (AC 1-3, one change)**: `jq empty "$MARKER_FILE"` guard before the `.reason`
  extraction; parse-failure branch builds a reason naming the marker path and jq's own error
  text (`head -1`-bounded); both branches converge on a single `jq -n --arg` output
  construction. Verified locally by research to produce valid JSON for reasons containing `"`,
  `\`, and literal newlines.
- **Block vs. fail-open (settled, not re-litigated)**: fail closed with a diagnostic reason.
  `check_loop_guard()` already removes the marker and loop guard and allows the stop
  unconditionally after `MAX_CONTINUATIONS` (3), independent of the reason text — the
  entrapment risk that would motivate fail-open is already bounded by existing code. Fail-open
  has no corresponding cap on its downside.
- **Survey (AC 5)**: 52 occurrences of the `jq -r '... // ...'` idiom across 13 core hook files;
  49 use `// empty`, 2 are field-name fallback chains terminating in `// empty`, 2 use `// ""`
  in callers that treat empty as a no-op. Exactly **one** site — the fix target — has a
  non-empty, semantically load-bearing default. AC 5 is satisfied by documenting the rest as
  tolerant-by-design; no other site gets a code change.
- **Telemetry (AC 4)**: recover the task number from `dirname "$MARKER_FILE"` via the
  `specs/([0-9]+)_` regex already used in the same branch (available pre-parse), then resolve
  `session_id` through the `.active_projects[] | select(.project_number == $num)` lookup the
  file's own Stop path already performs. `session_id` is schema-required and
  pattern-constrained, so the existing `[ -z "$session_id" ] && exit_success` fallback remains
  the correct residual behavior — the fix narrows the silent window, it does not eliminate it.
- **Event taxonomy**: `--event-type malformed_postflight_marker --category deviation`, per the
  closed 4-value `deviation|blocker|milestone|success` enum in `events-schema.json`.
- **Test pattern**: new `test-subagent-postflight-marker.sh` following
  `test-guard-destructive-git.sh`'s subprocess-driven structure, registered in
  `agent-system/extensions/core/manifest.json`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Make the blocked-subagent channel diagnosable: a parse failure yields a reason naming the
  marker path and the jq error (AC 1), distinguishable from the missing-`.reason` default
  (AC 2).
- Make the hook's stdout valid JSON for arbitrary marker content via `jq -n --arg` (AC 3).
- Make the malformed-marker case observable after the fact as one `deviation` event (AC 4).
- Close the hook-idiom survey with a documented classification (AC 5).
- Make the two hooks' handling of the same malformed marker consistent, and document the
  remaining intentional divergence (AC 6).
- Add registered regression coverage for all of the above.

**Non-Goals**:
- Fixing whichever caller wrote the key=value-shaped marker observed live (separate, already
  understood, explicitly out of scope).
- Changing marker *selection* (`find_marker()`'s `head -1`) or loop-guard semantics — owned by
  the sibling marker-ownership task.
- Rewriting any of the 51 tolerant-by-design `// empty` / `// ""` sites.
- Factoring the duplicated `find specs -maxdepth 3 -name ".postflight-pending"` resolution into
  a shared helper (noted by research as a real duplication, but a separate refactor).
- Adding a fail-open path or any new event schema/field.
- Touching the deployed `.claude/**` tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementing against a stale read of `subagent-postflight.sh` if the sibling marker-ownership task landed in between | M | M | Phase 1 opens with a mandatory fresh read of `find_marker()`/`main()`; never edit from a cached read or a line number quoted in an artifact |
| jq's stderr for a badly corrupted file is long or multi-line, bloating the reason string | L | M | `head -1` on the captured error; `jq -n --arg` handles any remaining special characters regardless of length |
| state.json lookup yields no `session_id` (task archived/vaulted), so no event can be emitted | L | M | Pre-existing, unavoidable: `session_id` is schema-required and pattern-constrained. Keep the existing `[ -z "$session_id" ] && exit_success` fallback and document it as the residual silent case |
| Adding a `set -e`-incompatible construct to `subagent-postflight.sh` | M | L | The hook does not currently run under `set -euo pipefail`; do not introduce it as a side effect of this change. Verify the script's shebang/option line is unchanged in the diff |
| New test suite passes vacuously (e.g. fixture has no marker, so every case sees the no-marker path) | M | M | First case in the suite is a fixture self-check asserting the marker exists and the hook actually reaches the block branch, mirroring `test-guard-destructive-git.sh`'s dirty-repo self-check |
| Edits land in `.claude/**` and are wiped by the next deploy | H | L | Every edit targets `agent-system/extensions/core/**`; the advisory `validate-meta-write.sh` hook flags a mistake but does not block it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 edit different files
(`subagent-postflight.sh` vs. `events-log-lifecycle.sh`) with no shared region.

### Phase 1: Guard the Marker Parse and Build Output With jq [COMPLETED]

**Goal**: `subagent-postflight.sh` distinguishes "marker does not parse" from "marker parses but
has no `.reason`", and emits valid JSON in both cases. Closes AC 1, 2, 3.

**Tasks**:
- [x] Re-read `find_marker()` and `main()` in *(completed)*
      `agent-system/extensions/core/hooks/subagent-postflight.sh` fresh; locate the `.reason`
      extraction and the hand-built `echo "{\"decision\": ...}"` line by content, not by the
      line numbers quoted in the research report or task description
- [x] Insert a `jq empty "$MARKER_FILE" 2>/dev/null` validity check before the `.reason` *(completed)*
      extraction, mirroring the identical call in `events-log-lifecycle.sh`'s SubagentStop
      branch
- [x] Parse-success branch: keep today's `jq -r '.reason // "Postflight operations pending"'` *(completed)*
      behavior byte-for-byte unchanged (AC 2)
- [x] Parse-failure branch: capture `parse_err=$(jq empty "$MARKER_FILE" 2>&1 >/dev/null | head -1)` *(completed)*
      and set a reason naming the marker path, stating it could not be parsed as JSON, and
      embedding `$parse_err` (AC 1)
- [x] Replace the hand-built JSON echo with `echo "{\"decision\": \"block\", \"reason\": $(jq -n --arg r "$reason" '$r')}"` *(completed)*
      so both branches converge on one safe construction (AC 3)
- [x] Remove the stale `# Note: Using simple JSON output - no jq dependency for robustness` *(completed)*
      comment; the `.reason` extraction already makes jq a hard dependency, so the stated
      justification is false
- [x] Add a brief comment recording *why* the `jq empty` pre-check exists (the `//` operator *(completed)*
      does not fire on parse errors), so the guard is not "simplified" away later
- [x] Leave `find_marker()`, `check_loop_guard()`, `MAX_CONTINUATIONS`, the `stop_hook_active` *(completed)*
      short-circuit, and the no-marker path untouched
- [x] Manually drive the hook against a scratch fixture (well-formed marker, marker without *(completed)*
      `.reason`, non-JSON marker) and confirm each stdout is valid JSON via `jq empty`

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research report locates the defect at two adjacent lines (the `.reason`
extraction and the JSON echo) inside `main()`, and asserts no other region of this file needs
changing. Confirm at implementation time by re-reading the file fresh and grepping for any other
`jq -r` use or hand-built JSON emission in it; if the sibling marker-ownership task has already
moved this region, adapt to the current code rather than restoring the shape described here.

**Files to modify**:
- `agent-system/extensions/core/hooks/subagent-postflight.sh` - parse-validity guard,
  parse-failure reason branch, `jq -n --arg` output construction, stale comment removal

**Verification**:
- `bash -n agent-system/extensions/core/hooks/subagent-postflight.sh` passes
- A non-JSON marker fixture yields stdout that passes `jq empty` and whose `.reason` contains
  the marker path and the substring identifying a parse failure
- A marker missing `.reason` still yields exactly `Postflight operations pending`
- A marker whose `.reason` contains `"`, `\`, and a newline yields stdout that passes `jq empty`
- `git diff` shows no change to `find_marker()` or `check_loop_guard()`

---

### Phase 2: Log the Malformed-Marker Case as a Deviation Event [COMPLETED]

**Goal**: A malformed marker leaves a durable trace in `specs/events.jsonl` instead of a silent
`exit_success`. Closes AC 4 and the events side of AC 6.

**Tasks**:
- [x] Re-read the SubagentStop branch of *(completed)*
      `agent-system/extensions/core/hooks/events-log-lifecycle.sh`
- [x] Replace the bare `jq empty "$MARKER_FILE" 2>/dev/null || exit_success` with a branch that, *(completed)*
      on parse failure: derives `task_dir=$(dirname "$MARKER_FILE")`, extracts the task number
      via the `specs/([0-9]+)_` regex already used further down the same branch, and resolves
      `session_id` from `specs/state.json` using the same
      `.active_projects[]? | select(.project_number == $num) | .session_id // empty` lookup the
      file's Stop path already performs
- [x] Guard the state.json read with the existing `[ -f specs/state.json ] || exit_success` and *(completed)*
      `jq empty specs/state.json 2>/dev/null || exit_success` idioms already used in this file
- [x] Emit exactly one event via `_events_append_observable` with *(completed)*
      `--event-type malformed_postflight_marker --category deviation --checkpoint postflight`,
      `--session "$session_id"`, `--task "$task"`, a message naming the marker path, and
      `--detail-json` carrying the marker path and the `head -1`-bounded jq error text
- [x] Thread `--cwd "$CWD"` and `--cc-session-id "$CC_SESSION_ID"` using the same *(completed)*
      `[ -n ... ] && event_args+=(...)` idiom as the sibling event construction
- [x] Keep `[ -z "$session_id" ] && exit_success` as the residual fallback when the lookup fails *(completed)*
      (archived/vaulted task) — do not invent a placeholder session id
- [x] `exit_success` after emitting; the hook must still never block and must still echo `{}` *(completed)*
- [x] Confirm `--detail-json` usage matches `events-append.sh`'s own usage block, and that *(completed)*
      `malformed_postflight_marker` is accepted by `events-schema.json` (the `category` enum is
      closed; verify whether `event_type` is likewise constrained before assuming a free-form
      value is valid)

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research report asserts that `event_type` is free-form while `category`
is a closed 4-value enum, and that `session_id` is required and pattern-constrained. Confirm by
reading `agent-system/extensions/core/context/schemas/events-schema.json` directly before
choosing the event type string; if `event_type` turns out to be enumerated, add the new value to
the schema in this phase or select an existing value, and record which was done.

**Files to modify**:
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` - malformed-marker branch with
  path-derived task number, state.json session lookup, and deviation event
- `agent-system/extensions/core/context/schemas/events-schema.json` - only if `event_type` is a
  closed enum requiring the new value

**Verification**:
- `bash -n agent-system/extensions/core/hooks/events-log-lifecycle.sh` passes
- Driven against a fixture with a malformed marker in `specs/{NNN}_{slug}/` and a matching
  `specs/state.json` entry, the hook appends exactly one line to `specs/events.jsonl` with
  `.category == "deviation"` and a `session_id` matching `^sess_[0-9]+_[a-zA-Z0-9]+$`
- Same fixture with the state.json entry removed: no event appended, hook still echoes `{}` and
  exits 0
- Hook stdout is exactly `{}` in every case (never a `decision` key)

---

### Phase 3: Regression Suite for the Malformed-Marker Path [COMPLETED]

**Goal**: Registered, subprocess-driven test coverage for every acceptance criterion that is
mechanically checkable.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` *(completed)*
      following `test-guard-destructive-git.sh`'s structure: `SCRIPT_DIR`-relative hook path
      that resolves in both source-store and deployed layouts, `pass()`/`fail()`/`info()`
      helpers, `PASSED`/`FAILED` counters, `mktemp -d` fixtures with `trap cleanup EXIT`,
      exit 0 all-pass / exit 1 any-fail
- [x] Fixture helper that builds a scratch dir containing `specs/{NNN}_{slug}/.postflight-pending` *(completed)*
      with caller-supplied content, and runs the hook as a real subprocess with cwd set there
- [x] First case is a fixture self-check: assert the hook actually reaches the block branch for a *(completed)*
      well-formed marker, so later cases cannot pass vacuously via the no-marker path
- [x] Case (a): well-formed marker with `.reason` present -> that reason passes through unchanged *(completed)*
- [x] Case (b): well-formed marker missing `.reason` -> `Postflight operations pending` (AC 2) *(completed)*
- [x] Case (c): non-JSON marker (key=value shaped, matching the live observation) -> stdout is *(completed)*
      valid JSON, `.reason` is non-empty, contains the marker path, and states parse failure
      (AC 1)
- [x] Case (d): `.reason` containing a double quote, a backslash, and a literal newline -> *(completed)*
      stdout passes `jq empty` and `.reason` round-trips to the original string (AC 3)
- [x] Case (e): loop-guard interaction unchanged — with the guard file already at *(completed)*
      `MAX_CONTINUATIONS`, a malformed marker still allows the stop (`{}`), confirming the
      fail-closed decision stays bounded
- [x] Companion case for `events-log-lifecycle.sh`: malformed marker plus a matching *(completed)*
      `specs/state.json` entry produces exactly one `deviation` event with a valid
      `session_id`; with no matching entry, no event and a clean `{}` exit (AC 4)
- [x] Register the suite in `agent-system/extensions/core/manifest.json` alongside the other *(completed)*
      `tests/test-*.sh` entries, preserving the existing ordering convention
- [x] Ensure no task-number references appear anywhere in the test file or its comments *(completed)*

**Timing**: 1.0 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that seven cases (self-check plus a-e plus the events
companion) cover all mechanically checkable acceptance criteria, and that
`test-guard-destructive-git.sh`'s `SCRIPT_DIR/../../hooks/` relative path resolves correctly for
this suite too. Confirm by reading that suite's path resolution and manifest entry directly, and
by running the new suite from both `agent-system/extensions/core/scripts/tests/` and (if a
deployed tree exists) `.claude/scripts/tests/`.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` - new suite
- `agent-system/extensions/core/manifest.json` - register the suite in the tests list

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` exits 0
  with all cases PASS
- Temporarily reverting the Phase 1 guard makes cases (c) and (d) FAIL — confirms the suite is
  not vacuous
- `jq empty agent-system/extensions/core/manifest.json` passes and the new entry is present
- `bash .claude/scripts/check-task-references.sh` (or equivalent repo lint) reports no new
  violations

---

### Phase 4: Document the Survey, the Hazard, and the Two Hooks' Consistency [NOT STARTED]

**Goal**: Close AC 5 and the documentation half of AC 6 in prose, and prevent reintroduction of
the same defect class elsewhere.

**Tasks**:
- [ ] Re-run `grep -n "jq -r '.*//.*'" agent-system/extensions/core/hooks/*.sh` and confirm the
      classification counts against the current tree before writing any number down
- [ ] Add a short subsection to the `## SubagentStop Hook Behavior` area of
      `agent-system/extensions/core/context/patterns/postflight-control.md` stating the rule:
      `// "non-empty default"` is only safe when preceded by an explicit `jq empty` parse-validity
      check; `// empty` is safe unguarded because absent-field and parse-error collapse to the
      same caller behavior
- [ ] In the same file, record the survey outcome: the count of surveyed occurrences and files,
      the fallback-shape classification, and the explicit statement that every site other than
      the fixed one is tolerant-by-design and deliberately unchanged (AC 5)
- [ ] Document how `subagent-postflight.sh` and `events-log-lifecycle.sh` now handle the same
      malformed marker: both detect it with `jq empty`; the postflight hook blocks with a
      diagnostic reason, the events hook logs a `deviation` and never blocks. State that this
      divergence is intentional and why (one is a control channel, the other is telemetry that
      must never block), and note the one remaining silent case (no recoverable `session_id`)
      (AC 6)
- [ ] Update the description of the hook's block-reason behavior in that file if it asserts the
      old always-defaults behavior
- [ ] Verify no task-number references were introduced (this file lives outside `specs/**`)

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Scope Hypothesis**: The research report asserts 52 occurrences across 13 hook files with
exactly one defective site. That count is a hypothesis about a tree that Phase 1 and 2 have since
edited. Re-run the grep and recount before writing the numbers into documentation; if the count
differs, document the observed count and reconcile the difference rather than transcribing the
report's figure.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/postflight-control.md` - jq `//` parse-error
  hazard rule, survey classification record, two-hook consistency note

**Verification**:
- Diff read-through confirms every changed hunk is prose (no executable content in this file)
- Every number written is backed by a grep run in this phase, not copied from the report
- `bash .claude/scripts/check-task-references.sh` reports no new violations
- Cross-references to `subagent-postflight.sh` and `events-log-lifecycle.sh` name functions or
  sections, never line numbers

---

### Phase 5: Full Gate Run and Acceptance-Criteria Walkthrough [NOT STARTED]

**Goal**: Confirm every acceptance criterion is met and nothing adjacent regressed.

**Tasks**:
- [ ] Run the new `test-subagent-postflight-marker.sh` suite
- [ ] Run the adjacent existing suites: `test-postflight-marker-schema.sh`,
      `test-lint-postflight-boundary.sh`, `test-loop-guard-budget-override.sh`,
      `test-loop-guard-staleness.sh`, `test-skill-base-lifecycle.sh`
- [ ] `bash -n` (and `shellcheck` if available) on both modified hooks and the new test
- [ ] `jq empty agent-system/extensions/core/manifest.json`
- [ ] Walk the six acceptance criteria explicitly, recording for each the command output or test
      case name that demonstrates it
- [ ] Confirm no file under `.claude/**` was modified (`git status --short | grep '^.M \.claude/'`
      returns nothing)
- [ ] Confirm no task-number references outside `specs/**`

**Timing**: 0.25 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase enumerates five adjacent existing suites as the regression set.
Confirm each exists under `agent-system/extensions/core/scripts/tests/` before running; if a
named suite is absent or has been renamed, substitute the current equivalent and record the
substitution rather than silently skipping it.

**Files to modify**: none (verification only)

**Verification**:
- All listed suites exit 0
- Each of the six acceptance criteria has a named, cited piece of evidence
- Working tree contains no `.claude/**` modifications

---

## Testing & Validation

- [ ] AC 1: case (c) asserts a non-empty reason naming the marker path and stating parse failure
- [ ] AC 2: case (b) asserts the `Postflight operations pending` default still fires, and case
      (c) asserts the two cases are textually distinguishable
- [ ] AC 3: case (d) asserts valid JSON stdout for a `.reason` with quote, backslash, and newline
- [ ] AC 4: events companion case asserts one `deviation` event with a valid `session_id`, and a
      clean no-event exit when the lookup fails
- [ ] AC 5: survey re-run and classification recorded in `postflight-control.md`
- [ ] AC 6: both hooks detect the malformed marker with `jq empty`; the intentional divergence
      and the residual silent case are documented
- [ ] Non-vacuity: reverting the Phase 1 guard makes cases (c) and (d) fail
- [ ] No `.claude/**` edits; no task-number references outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/subagent-postflight.sh` (modified)
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (modified)
- `agent-system/extensions/core/context/schemas/events-schema.json` (modified only if
  `event_type` is a closed enum)
- `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` (new)
- `agent-system/extensions/core/manifest.json` (modified — test registration)
- `agent-system/extensions/core/context/patterns/postflight-control.md` (modified)
- `specs/079_diagnosable_subagent_postflight_marker_failure/summaries/01_*-summary.md`

## Rollback/Contingency

All changes are confined to six files in the source store, with no data migration and no state
schema change. Rollback is `git revert` of the phase commits, or targeted `git checkout HEAD~N --
<file>` per file. The two hook changes are independent (different files, no shared code), so
either can be reverted alone: reverting Phase 1 restores the empty-reason behavior without
affecting the events logging; reverting Phase 2 restores `exit_success` silence without
affecting the block reason. If the sibling marker-ownership task lands mid-implementation and
conflicts, re-read `main()` and re-apply the Phase 1 edit against the new code rather than
resolving the conflict textually.
