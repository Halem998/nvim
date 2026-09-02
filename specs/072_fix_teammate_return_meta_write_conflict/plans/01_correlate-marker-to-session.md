# Implementation Plan: Correlate subagent-postflight marker selection to the stopping session

- **Task**: 72 - Correlate subagent-postflight marker selection to the stopping session
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/072_fix_teammate_return_meta_write_conflict/reports/01_marker-session-correlation.md
- **Artifacts**: plans/01_correlate-marker-to-session.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent hooks each select a `.postflight-pending` marker with
`find specs -maxdepth 3 -name ".postflight-pending" | head -1` and no correlation to the
stopping subagent's session: `subagent-postflight.sh`'s `find_marker()` and
`events-log-lifecycle.sh`'s SubagentStop branch (its own separate `MARKER_FILE`). With markers
from several concurrent sessions on disk, the first hook can block the wrong session, increment
a foreign task's loop guard, and on cap `rm -f` a marker it does not own; the second attributes
`subagent_stop` events in `specs/events.jsonl` to a `session_id` whose `cc_session_id` belongs
to a different Claude session. The fix adds a `cc_session_id` field to the marker written by
`skill_create_postflight_marker`, populated from `${CLAUDE_CODE_SESSION_ID:-}`, and changes both
hooks to enumerate all markers and act only on the one whose `cc_session_id` equals hook stdin's
top-level `.session_id` — acting on no marker at all when nothing matches. Done when both hooks
are correlated, cap-reached deletion is labelled distinctly from other removals in the log, and
a fixture test drives both hooks with two unrelated sessions' markers present and asserts the
foreign marker is neither acted on nor mutated.

### Research Integration

Findings carried directly into this plan:

- `$CLAUDE_CODE_SESSION_ID` (bash env, every tool invocation) and hook stdin's top-level
  `.session_id` are one id space — Claude Code's native session UUID — distinct from the
  agent-system `sess_{timestamp}_{random}` id already in the marker's `session_id` field.
  In-repo precedent with an explicit comment: `update-task-status.sh`'s `workflow-active-<key>`
  marker, keyed by `${CLAUDE_CODE_SESSION_ID:-$session_id}`. No new capture mechanism is needed;
  only a new marker field.
- The consumer surface is closed at exactly two sites. `orchestrator-postflight.sh` operates on
  an explicitly-passed `$task_dir` (unaffected); `skill-refresh`'s `-mmin +60` orphan sweep is an
  age-based sweep of all stale markers regardless of owner (unaffected); the rest are the writer,
  two task-dir-scoped `rm -f` cleanups, and test fixtures.
- `test-postflight-marker-schema.sh` asserts an exact key set
  (`EXPECTED_KEYS="created operation reason session_id skill stop_hook_active task_number"`),
  so the new field breaks that test unless updated in the same phase.
- `test-subagent-postflight-marker.sh` already drives `subagent-postflight.sh` as a real
  subprocess against `mktemp -d` fixtures and separately builds an isolated deployed-layout
  `.claude/` copy to drive `events-log-lifecycle.sh` without touching the real
  `specs/events.jsonl`. The new cross-session cases extend that file's existing
  `make_postflight_fixture`/`run_postflight` and `make_events_fixture`/`run_events_hook`
  conventions rather than introducing a new harness.
- Known, accepted limitation (research, "Known residual gap"): within a *single* Claude Code
  session holding two markers simultaneously, `cc_session_id` does not disambiguate which of that
  session's own markers belongs to the subagent that just stopped. The acceptance criterion is
  scoped to markers from unrelated concurrent tasks (cross-session), which this fix fully
  resolves. Hook stdin carries no Task-tool-call-scoped identifier the writer could know in
  advance, so closing the same-session case would require a different mechanism and is out of
  scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- `skill_create_postflight_marker` emits a `cc_session_id` field sourced from
  `${CLAUDE_CODE_SESSION_ID:-}`, with the 5-arg signature unchanged.
- `subagent-postflight.sh` acts only on the marker correlated to the stopping session, and on no
  marker at all when none correlates.
- `events-log-lifecycle.sh`'s SubagentStop branch applies the identical correlation, so a foreign
  subagent's stop is no longer attributed to another session's `session_id` in
  `specs/events.jsonl`.
- A cap-reached deletion is textually distinguishable in the hook log from the
  `stop_hook_active` removal branch and from a silent `skill_cleanup` removal.
- A fixture test proves the above with markers from at least two unrelated sessions present.

**Non-Goals**:
- Team mode, teammate `.return-meta.json` ownership, and per-teammate metadata paths (Part A of
  the original description; moot — team mode is being removed).
- Disambiguating two markers within one Claude Code session (see "Known residual gap" above).
- Changing the meaning of the marker's existing `session_id` field, or altering
  `orchestrator-postflight.sh`, `skill-refresh`'s orphan sweep, or the two task-dir-scoped
  `rm -f` cleanups.
- Consolidating the two-id-spaces explanation into a new `context/patterns/` doc (research's
  "Context Extension Recommendations" — a future `/meta` pass, explicitly not blocking).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Legacy markers on disk lack `cc_session_id` and, under the fail-safe, are never selected again — they persist until swept | M | H | This is the correct failure mode: a `head -1` fallback for legacy markers reopens the exact defect. `skill-refresh`'s existing `-mmin +60` orphan sweep already clears them. Documented as accepted in Phase 2, not designed around |
| `subagent-postflight.sh` currently reads no stdin at all; adding a read can block or mis-parse when stdin is a terminal or absent | H | M | Reuse `events-log-lifecycle.sh`'s proven `read -t 0.1` drain idiom verbatim, defaulting to `{}`; Phase 5 updates `run_postflight` to pipe an explicit payload so no fixture case inherits the harness's stdin |
| The `specs/.postflight-pending` global-fallback branch becomes an uncorrelated bypass if left untouched | H | H | Phase 2 subjects the global fallback to the same correlation check; an uncorrelated global marker is not selected |
| Existing cases in `test-subagent-postflight-marker.sh` write markers with no `cc_session_id` and pass no stdin, so they will stop reaching the block branch and pass vacuously | H | H | Phase 5 updates every existing case (including the fixture self-check, whose whole purpose is to fail loudly on a vacuous pass) before adding new ones |
| Exact-key-set schema test breaks on the added field | M | H | Fixed in the same phase as the writer change (Phase 1), not deferred |
| The two hooks drift apart if each carries its own copy of the correlation logic | M | M | Phase 3 requires the second implementation to be a deliberate mirror with a cross-reference comment naming the other site, matching the existing precedent where both hooks carry mirrored malformed-marker guards with such comments |

**Planner's choice on shared-helper vs. duplicated logic** (deliberately left open by the
research, resolved here): each hook keeps its own copy, mirrored, with a cross-reference comment.
Rationale — hooks in this tree are standalone executables invoked by Claude Code directly with no
guaranteed sourcing root, and `subagent-postflight.sh` currently sources nothing at all while
`events-log-lifecycle.sh` resolves siblings via `SCRIPT_DIR`; the two also differ in shell options
(`set -euo pipefail` in one, not the other), so a shared helper would have to be written against
the weaker of the two. The existing malformed-marker guard is already duplicated across these same
two hooks with mirrored comments, so this follows established precedent rather than inventing a
new arrangement. The implementer may extract a helper instead if it proves cleaner, provided the
fail-safe below holds identically in both.

**Fail-safe (binding, applies to every selection site in this plan)**: on no match, act on NO
marker. Never fall back to an arbitrary one. This holds for legacy markers written before
`cc_session_id` existed and for markers whose `cc_session_id` is present but empty.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5, 6 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add cc_session_id to the marker writer and its schema test [COMPLETED]

**Goal**: The single production writer of `.postflight-pending` emits a `cc_session_id` field
carrying Claude Code's native session UUID, and the exact-key-set schema test admits it.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/skill-base.sh`, extend
      `skill_create_postflight_marker`'s heredoc with `"cc_session_id": "${CLAUDE_CODE_SESSION_ID:-}"`.
      Keep the 5-arg signature unchanged — read the env var directly, exactly as
      `update-task-status.sh` does for its `workflow-active-<key>` marker. Use `:-` (empty
      string), never a placeholder sentinel. *(completed)*
- [x] Update the SHAPE A schema comment above the function to name the new field and state that
      it is the correlation key read by both hooks, distinct from the agent-system `session_id`
      already present. *(completed)*
- [x] In `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh`, add
      `cc_session_id` to `EXPECTED_KEYS` (sorted position: first) and update the pass-message
      wording that says "the seven Shape A keys". *(completed)*
- [x] Add a schema-test case asserting `cc_session_id` round-trips the value of
      `CLAUDE_CODE_SESSION_ID` set in the test's environment, and a second asserting it is the
      empty string (key present, not absent) when the env var is unset. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The marker schema's consumer set is exactly four sites — the two hooks
(Phases 2 and 3), `test-postflight-marker-schema.sh`, and
`context/patterns/postflight-control.md`'s Fields table (Phase 6). Confirm at implementation time
with `grep -rn 'postflight-pending' agent-system/` and check no additional reader of the marker's
key set exists; if one is found, treat it as in scope for this phase's key-set change.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - add `cc_session_id` to the writer's
  heredoc; update the SHAPE A comment
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` - extend
  `EXPECTED_KEYS`; add set/unset round-trip cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` passes with
  the new cases.
- A marker written with `CLAUDE_CODE_SESSION_ID` set contains that exact value under
  `.cc_session_id`; written with it unset, the key is present and empty.

---

### Phase 2: Correlate subagent-postflight.sh marker selection [COMPLETED]

**Goal**: `find_marker()` selects only the marker whose `cc_session_id` matches the stopping
session, and selects nothing when none matches.

**Tasks**:
- [x] Add a stdin read at the top of `subagent-postflight.sh` using the `read -t 0.1` drain idiom
      from `events-log-lifecycle.sh` (default `{}` when stdin is empty or absent), and extract
      `CC_SESSION_ID=$(... | jq -r '.session_id // empty')`. This hook currently reads no stdin;
      the read must never block. *(completed)*
- [x] Rewrite `find_marker()` to enumerate every `.postflight-pending` under
      `specs -maxdepth 3` (a `while read -r` loop over `find`, not `head -1`), and for each:
      run the existing `jq empty` malformed-marker guard, then compare
      `jq -r '.cc_session_id // empty'` against `CC_SESSION_ID`. Select on equality only.
      Set `MARKER_FILE`, `TASK_DIR`, `LOOP_GUARD_FILE` from the matched marker. *(completed)*
- [x] Apply the same correlation to the `specs/.postflight-pending` global-fallback branch: an
      uncorrelated global marker is not selected. Leaving that branch uncorrelated would preserve
      the defect through a second door. *(completed)*
- [x] Enforce the fail-safe explicitly: when `CC_SESSION_ID` is empty, or no marker's
      `cc_session_id` matches, or the matching value is empty, leave `MARKER_FILE` unset so main
      takes the existing "no marker — allow normal stop" path. Never fall back to the first hit. *(completed)*
- [x] Add a `log_debug` line for the no-correlation case that names how many markers were
      enumerated and the stopping `CC_SESSION_ID`, so a stuck legacy marker is diagnosable from
      the log rather than silent. *(completed)*
- [x] Add a header comment recording the accepted limitation: two markers within one Claude Code
      session are not disambiguated by `cc_session_id`. *(completed)*
- [x] Confirm the orphaned-loop-guard cleanup in the no-marker path cannot now delete a foreign
      task's loop guard — with no marker selected, `LOOP_GUARD_FILE` must stay unset. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/hooks/subagent-postflight.sh` - stdin read and `CC_SESSION_ID`
  capture; `find_marker()` enumerate-and-match; global-fallback correlation; fail-safe and
  diagnostic logging

**Verification**:
- Manual fixture: two task dirs each with a marker carrying a different `cc_session_id`; run the
  hook with a payload naming one of them; assert only that task's marker drives the block
  decision and the other task's loop guard is not created.
- Run the hook with a payload whose `session_id` matches no marker; assert `{}` on stdout and no
  file created or removed anywhere under the fixture.
- Run the hook with no stdin at all; assert it returns promptly (no block waiting on the read)
  and takes the no-marker path.

---

### Phase 3: Correlate events-log-lifecycle.sh SubagentStop marker selection [COMPLETED]

**Goal**: The SubagentStop branch attributes its event to the marker owned by the stopping
session, or emits no event at all.

**Tasks**:
- [x] Replace the SubagentStop branch's `MARKER_FILE=$(find ... | head -1)` with the same
      enumerate-and-match selection as Phase 2, matching each marker's `cc_session_id` against the
      `CC_SESSION_ID` this hook already captures from stdin's `.session_id`. *(completed)*
- [x] Preserve the branch's existing malformed-marker deviation path: a marker that fails
      `jq empty` cannot be correlated (its `cc_session_id` is unreadable), so decide and implement
      one behavior explicitly — enumerate past it without selecting it, and keep the existing
      `malformed_postflight_marker` deviation event only for a marker the enumeration reached.
      Whichever is chosen, the malformed case must not resurrect an arbitrary pick. *(completed: extracted emit_malformed_marker_event(), called per malformed marker reached during enumeration)*
- [x] Apply the fail-safe: no correlated marker means `exit_success` with no event appended,
      never an event attributed to a marker this session does not own. *(completed)*
- [x] Update the file's header comment, which currently states the SubagentStop path "locates the
      marker file the same way subagent-postflight.sh does" — keep that statement true by naming
      the correlation, and add a cross-reference to the mirrored logic in the other hook. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: `events-log-lifecycle.sh` has exactly one uncorrelated marker-selection site
(the SubagentStop branch's own `MARKER_FILE`), and the Stop branch's per-session
`workflow-active-<CC_SESSION_ID>` lookup is already correctly session-keyed and needs no change.
Confirm at implementation time by grepping this file for both `postflight-pending` and `head -1`
before editing; if the Stop path turns out to share the defect, it is in scope for this phase.

**Files to modify**:
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` - SubagentStop branch marker
  selection; malformed-marker interaction; header comment

**Verification**:
- Isolated deployed-layout fixture with two markers under different `cc_session_id` values: the
  emitted `subagent_stop` line's `session_id` is the correlated marker's, and its `cc_session_id`
  is the stopping session's — the two now describe the same session.
- A payload matching no marker appends no line to the fixture's `events.jsonl` and still echoes
  `{}`.

---

### Phase 4: Label deletion provenance in the hook log [COMPLETED]

**Goal**: A cap-reached deletion is textually distinguishable from the `stop_hook_active` removal
and from a silent `skill_cleanup` removal.

**Tasks**:
- [x] In `check_loop_guard()`'s `MAX_CONTINUATIONS` branch, replace the bare
      `"Loop guard triggered: $count >= $MAX_CONTINUATIONS"` line with an explicitly labelled
      message (e.g. a `CAP-REACHED DELETE:` prefix) naming the marker path, the task number, the
      marker's `session_id`, and the correlated `cc_session_id`. *(completed)*
- [x] Give the `stop_hook_active` removal branch an equally explicit, textually distinct label so
      the two deletion paths cannot be confused when reading the log. *(completed)*
- [x] Add a comment noting that `skill_cleanup`'s removal is a silent `rm -f` with no log line —
      the third removal path is identified by the absence of any labelled line, and the two
      labelled paths must therefore stay distinct from each other. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/hooks/subagent-postflight.sh` - `check_loop_guard()` cap branch
  log line; `stop_hook_active` branch log line

**Verification**:
- Drive the hook to the cap and confirm `.agent-logs/subagent-postflight.log` carries the labelled
  cap-reached line naming the marker and both session ids.
- Confirm the two labels do not share a substring that would make a `grep` for one match the
  other.

---

### Phase 5: Cross-session fixture tests for both hooks [COMPLETED]

**Goal**: `test-subagent-postflight-marker.sh` proves both hooks act only on the correlated
marker with foreign markers present, and every pre-existing case in the file still exercises what
it claims to.

**Tasks**:
- [x] Update `run_postflight` to pipe a synthetic SubagentStop payload (parameterised
      `session_id`) into the hook rather than inheriting the harness's stdin, mirroring
      `run_events_hook`'s `jq -n | bash` construction. *(completed)*
- [x] Update every existing `subagent-postflight.sh` case — starting with the fixture self-check,
      whose stated purpose is to fail loudly rather than let later cases pass vacuously — so its
      marker carries a `cc_session_id` and its payload carries the matching `session_id`. A case
      that silently stops reaching the block branch is a false pass, not a fix. *(completed: cases (c) and (e), which test the malformed-marker path, were revised rather than merely re-parameterised -- a malformed marker's cc_session_id is structurally unreadable so find_marker() can never select it; their assertions now check the fail-safe {} plus byte-identical marker/loop-guard survival)*
- [x] Add a `subagent-postflight.sh` case: two task dirs, two markers, two distinct
      `cc_session_id` values, payload matching one. Assert the block reason comes from the
      matched marker; assert the foreign marker still exists byte-identical after the run; assert
      no loop guard was created in the foreign task dir. *(completed: case (f))*
- [x] Add a `subagent-postflight.sh` case driving the correlated session to the
      `MAX_CONTINUATIONS` cap with a foreign marker present: assert only the correlated marker is
      deleted and the foreign one survives. *(completed: case (g), also asserts exactly one CAP-REACHED DELETE: log line)*
- [x] Add a `subagent-postflight.sh` case for a legacy marker (no `cc_session_id` key at all):
      assert `{}` on stdout, no block, and the marker untouched — the fail-safe, asserted as
      intended behavior. *(completed: case (h))*
- [x] Add an `events-log-lifecycle.sh` companion case using `make_events_fixture`/
      `run_events_hook`: two markers, two `cc_session_id` values; assert exactly one event line is
      appended, that its `session_id` is the correlated marker's, and that its `cc_session_id`
      equals the payload's. Add a no-match case asserting zero lines appended. *(completed)*
- [x] Run the full file and confirm the pass count rose by the number of new assertions rather
      than staying flat (a flat count means a new case is not executing). *(completed: 9 -> 20 passed)*

**Timing**: 1.25 hours

**Depends on**: 2, 3, 4

**Verification Tier**: local

**Scope Hypothesis**: Every pre-existing `subagent-postflight.sh` case in this file writes its
marker inline as a heredoc/`echo` without `cc_session_id` and will need updating — the count is
unknown until implementation. Confirm by grepping the file for `.postflight-pending` write sites
before editing and updating each one found; do not assume the fixture self-check is the only one.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` - parameterise
  `run_postflight` with a payload; update existing cases; add cross-session, cap-deletion,
  legacy-marker, and events-hook correlation cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` reports
  zero failures and a pass count higher than before by the number of added assertions.
- The real repo's `specs/events.jsonl` is unmodified after the run (the isolated deployed-layout
  fixture's whole purpose).

---

### Phase 6: Sync postflight-control.md to the corrected behavior [COMPLETED]

**Goal**: The marker protocol documentation and its manual-recovery snippets describe the
correlated selection rather than the `head -1` behavior that was just removed.

**Tasks**:
- [x] Add `cc_session_id` to the Fields table in
      `agent-system/extensions/core/context/patterns/postflight-control.md`, stating its source
      (`${CLAUDE_CODE_SESSION_ID:-}` at write time) and that it is distinct from the
      agent-system `session_id`. *(completed)*
- [x] Update the example writer heredocs in that file to include the field, so a reader copying
      them produces a correlatable marker. *(completed)*
- [x] Rewrite the "SubagentStop Hook Behavior" numbered steps: the hook enumerates all markers and
      selects the one matching the stopping session; the global fallback is likewise correlated;
      no match means no action. Mirror how the file already documents the malformed-marker guard.
      *(completed: also updated "Consistency Between the Two Hooks on a Malformed Marker" and
      added a "Deletion Provenance" subsection for the Phase 4 log labels)*
- [x] Update the emergency-bypass and manual-recovery snippets that use
      `find ... | head -1`: those instruct an operator to reproduce the exact selection the hooks
      no longer make. Either scope them by `cc_session_id` or state plainly that they are a
      deliberate operator-driven override of correlation. *(completed: all three head -1 snippets
      labelled "Deliberate operator override of correlation")*
- [x] Do not use task-number references in this file — it lives outside `specs/**`. Cite the
      hook and script filenames as the durable anchors. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/postflight-control.md` - Fields table, writer
  examples, SubagentStop behavior steps, recovery snippets

**Verification**:
- Every code snippet in the file that writes a marker includes `cc_session_id`; every snippet that
  selects one either correlates or is explicitly labelled an operator override.
- `grep -n 'head -1' agent-system/extensions/core/context/patterns/postflight-control.md` returns
  only lines carrying that explicit override label.

**Scope note**: this file is the one edit target outside the five in the task's binding
SOURCE-STORE list. It is inside the same source store (`agent-system/extensions/core/`), so it
violates no boundary, but it is a scope widening and is isolated in its own final phase so it can
be dropped without touching the fix. It is included because leaving it stale would have the
documented protocol and the operator recovery instructions actively contradict the shipped
behavior — the snippets would tell an operator to make exactly the arbitrary pick the fix removes.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` — zero
      failures, `cc_session_id` present in the exact key set, set/unset round-trip cases pass.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` — zero
      failures; all pre-existing cases still reach the branches they assert on; new cross-session,
      cap-deletion, legacy-marker, and events-hook cases pass.
- [ ] AC — correlated selection: with markers from two unrelated concurrent tasks present, the
      hook acts only on the marker correlated to the stopping session (fixture, Phase 5).
- [ ] AC — event attribution: a foreign subagent's stop no longer produces a `subagent_stop` line
      pairing one session's `session_id` with another's `cc_session_id` (fixture, Phase 5).
- [ ] AC — deletion provenance: a cap-reached deletion is distinguishable in the log from the
      `stop_hook_active` removal and from a silent `skill_cleanup` removal (Phase 4).
- [ ] AC — ownership: no marker can be deleted by a session that does not own it; the foreign
      marker is asserted byte-identical after both the block case and the cap case.
- [ ] `bash -n` on all three modified shell files.
- [ ] `grep -rn 'postflight-pending' agent-system/ | grep 'head -1'` returns no live-code hit
      (documentation override snippets from Phase 6 excepted and labelled).
- [ ] Confirm no edit landed under `.claude/**` (`git status --porcelain .claude/` clean of
      hand-authored changes).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` (modified)
- `agent-system/extensions/core/hooks/subagent-postflight.sh` (modified)
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` (modified)
- `agent-system/extensions/core/context/patterns/postflight-control.md` (modified, Phase 6)
- `specs/072_fix_teammate_return_meta_write_conflict/summaries/NN_{short-slug}-summary.md`

## Rollback/Contingency

- All six files are tracked; revert with `git checkout -- <path>` per file, or drop the phase's
  commit. Phases commit independently, so Phase 6 (the out-of-binding-scope doc sync) can be
  reverted alone without disturbing the fix.
- Highest-risk single change is the stdin read added to `subagent-postflight.sh` (Phase 2): if it
  ever blocks, every subagent stop stalls. Contingency — the `read -t 0.1` timeout makes this
  bounded by construction, and reverting that one file restores the prior always-`head -1`
  behavior, which is defective but non-blocking.
- If correlation causes markers to go unselected in live use (e.g. `CLAUDE_CODE_SESSION_ID`
  unexpectedly unset in some dispatch path), the symptom is stuck markers and premature stops, not
  data loss; the `skill-refresh` orphan sweep clears them and the Phase 2 diagnostic log line
  names the mismatch.
