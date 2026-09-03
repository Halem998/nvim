# Research Report: Task #72

**Task**: 72 - Correlate subagent-postflight marker selection to the stopping session
**Started**: 2026-09-02T21:01:28Z
**Completed**: 2026-09-02T21:30:00Z
**Effort**: 4h
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/hooks/, scripts/, context/patterns/, scripts/tests/), specs/state.json, specs/PATH.md
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and precisely as described: `subagent-postflight.sh`'s `find_marker()`
  (`find specs -maxdepth 3 -name ".postflight-pending" | head -1`) has zero correlation to the
  stopping subagent's own session, and `events-log-lifecycle.sh`'s SubagentStop branch has the
  **identical, independent** `head -1` selection bug.
- The correlation key already exists end-to-end and needs no new plumbing to *read*: Claude
  Code exports `$CLAUDE_CODE_SESSION_ID` into every Bash tool call within a session (confirmed
  prior art in `update-task-status.sh:613` and the memory extension's self-exclusion scripts),
  and every hook receives the same id as stdin's top-level `.session_id`. This is one id space
  (Claude Code's native session UUID), documented in `events-format.md` as `cc_session_id`,
  distinct from the agent-system `sess_{timestamp}_{random}` id already in the marker.
- Fix: `skill_create_postflight_marker` (skill-base.sh) adds a new `cc_session_id` field,
  populated from `${CLAUDE_CODE_SESSION_ID:-}` at write time. `find_marker()`
  (subagent-postflight.sh) reads stdin's `.session_id`, enumerates **all** pending markers
  (not just the first), and selects the one whose `.cc_session_id` matches — acting on no
  marker at all if none matches, rather than falling back to an arbitrary one.
- **Scope gap to flag for planning**: the AC "a foreign subagent's stop is no longer attributed
  to another session's session_id in events.jsonl" cannot be satisfied by touching only the two
  files the SOURCE-STORE RULE names (`subagent-postflight.sh`, `skill-base.sh`).
  `events-log-lifecycle.sh` has its own, separate `MARKER_FILE=$(find ... | head -1)` — fixing
  `subagent-postflight.sh` does not touch it. There is direct precedent for fixing both hooks
  together for an analogous defect (see "Consistency Between the Two Hooks on a Malformed
  Marker" in `context/patterns/postflight-control.md`), and `test-subagent-postflight-marker.sh`
  already exercises both as companion cases in one fixture file.

## Context & Scope

Researched: how `subagent-postflight.sh` selects among concurrently-existing
`.postflight-pending` markers, how the marker schema and its writer work, what identifiers
Claude Code's hook/bash-tool surface exposes for correlating a stopping subagent to its own
session, and what other production call sites share the same `find | head -1` pattern.

Per the team lead's superseding scope: team mode / teammates are out of scope entirely (task 149
deletes team mode; this task's Part A is moot). This report covers only Part B — the
session-correlation defect, which is general to any concurrent single-task sessions, not
team-specific.

## Findings

### Codebase Patterns

**The defect, `agent-system/extensions/core/hooks/subagent-postflight.sh:19-21`:**
```bash
find_marker() {
    local found_marker=$(find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null | head -1)
    ...
}
```
No read of the marker's `session_id` field, no comparison to anything about the stopping
session. With N concurrent single-task sessions each mid-skill (each having dropped its own
`specs/{NNN}_{SLUG}/.postflight-pending`), this hook fires on **every** session's SubagentStop
and always acts on whichever marker `find` happens to return first (directory-traversal order,
effectively arbitrary/oldest-task-number-first). Two concrete failure modes, matching the task
description exactly:
- **Continuation-budget burn**: a session whose own subagent already finished (no marker of its
  own) sees `{}`... but a session whose subagent stops while another session's marker exists
  gets erroneously blocked (`decision: block`) and its loop guard (`.postflight-loop-guard`,
  scoped to the WRONG task's directory) increments — corrupting a counter that belongs to a task
  the current session has no relationship to.
- **Cap-reached deletion of a foreign marker**: `check_loop_guard()` (lines 38-56), on reaching
  `MAX_CONTINUATIONS=3`, does `rm -f "$MARKER_FILE"` unconditionally. If `$MARKER_FILE` was
  never this session's marker to begin with, this silently deletes another session's
  premature-termination guard — exactly the destructive case the task names.

**`events-log-lifecycle.sh`'s SubagentStop branch has the same bug, independently.** It defines
its own `MARKER_FILE=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)`
(line 125) — a separate variable, separate selection, no correlation either. This branch reads
the (wrongly-selected) marker's `session_id` and writes it as the `subagent_stop` event's
`session_id` field in `specs/events.jsonl`, while independently capturing the *stopping* hook's
own `CC_SESSION_ID` from stdin and writing it as `cc_session_id` on the same event line. When
the selected marker belongs to a different session, the emitted event pairs the **wrong**
agent-system `session_id` with the **correct** `cc_session_id` — precisely the "subagent_stop
events attributed to a session_id whose cc_session_id belonged to a different Claude session"
symptom named in the task description. This is the file that needs fixing to move the AC on
event attribution, not `subagent-postflight.sh`.

**The correlation key already exists and requires no new capture mechanism — only a new field
in the marker.** Prior art, already in production:
- `agent-system/extensions/core/scripts/update-task-status.sh:596-613`: writes a per-session
  `workflow-active-<key>` marker keyed by `${CLAUDE_CODE_SESSION_ID:-$session_id}`, with an
  extensive comment establishing that `$CLAUDE_CODE_SESSION_ID` is "exported into every Bash
  tool invocation" and is "the SAME id space" as hook stdin's top-level `.session_id`.
- `agent-system/extensions/core/hooks/wezterm-preflight-status.sh:57-59` and
  `events-log-lifecycle.sh`'s own header comment corroborate: every hook receives `.session_id`
  = Claude Code's native session UUID, and this is the documented join key to OTel's
  `session.id` (`context/formats/events-format.md`'s `cc_session_id` field definition and
  "Claude Code OTel Correlation" section).
- The memory extension's harvest scripts (`bootstrap-harvest.sh`, `bootstrap-harvest-history.sh`,
  `bootstrap-harvest-transcripts.sh`) all read `$CLAUDE_CODE_SESSION_ID` directly from the bash
  environment as a hard requirement (`FATAL` if unset), confirming it is reliably present in
  every Bash tool invocation within a Claude Code session, not just inside hooks.

Because `skill_create_postflight_marker` (skill-base.sh) runs as ordinary bash inside the
subagent's own Bash tool call (sourced by the skill script the subagent executes), it can read
`$CLAUDE_CODE_SESSION_ID` directly at marker-creation time — no hook needed to capture it. And
because Task-tool-dispatched subagents execute within their spawning top-level Claude Code
session (they do not get an independent top-level `session_id`), a marker written by a subagent
of session A and the SubagentStop hook firing when that same subagent stops both carry the
**same** `$CLAUDE_CODE_SESSION_ID` / stdin `.session_id` value. A different terminal/session
(session B) has a different value. This is exactly the granularity the task's named scenario
needs: "several concurrent single-task sessions" = several distinct top-level Claude Code
sessions = distinct `cc_session_id` values, which is what the fix must partition on.

**Known residual gap (documented, not required by the stated AC):** within a *single* Claude
Code session that has multiple markers pending simultaneously (e.g. two parallel Task-tool
dispatches from one orchestrator, per CLAUDE.md's "run independent agents in parallel" guidance),
`cc_session_id` alone does not disambiguate which of that session's own markers belongs to the
specific subagent that just stopped — both would share the same `cc_session_id`. The task's
acceptance criterion is scoped to "markers from at least two unrelated concurrent **tasks**"
(i.e., cross-session), which `cc_session_id` correlation fully resolves. The narrower
same-session, multiple-parallel-marker case is out of scope per the stated AC but worth a
one-line note in the plan as a known, accepted limitation (hook stdin carries no
Task-tool-call-scoped identifier that the marker writer could pre-know at write time; `agent_id`
is assigned by Claude Code to the *stopping* event, not knowable in advance by the writer).

**Marker schema is centrally documented** in `context/patterns/postflight-control.md`'s "Format"
section (fields: `session_id`, `skill`, `task_number`, `operation`, `reason`, `created`,
`stop_hook_active`) and is exact-key-set tested by
`agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh`
(`EXPECTED_KEYS="created operation reason session_id skill stop_hook_active task_number"`,
line 96). **Adding `cc_session_id` will break this test's exact-key-set assertion unless
updated** — this is a concrete, mechanical follow-up for the plan, not merely a documentation
nicety.

**Other call sites of the same `find specs -maxdepth 3 -name ".postflight-pending" | head -1`
idiom** (surveyed via grep across `agent-system/`), for scoping completeness:
- `orchestrator-postflight.sh` — NOT affected: it operates on a known, explicitly-passed
  `$task_dir`, never on a `find | head -1` glob. No fix needed there.
- `skill-refresh/SKILL.md`'s orphan sweep (`-mmin +60 ... -delete`) — NOT affected: it is an
  age-based sweep of *all* stale markers regardless of owner, not a single-marker pick; no
  correctness issue.
- `context/patterns/postflight-control.md`'s "Emergency Bypass" snippet and
  `context/troubleshooting/workflow-interruptions.md` — human-invoked manual recovery
  instructions using the same `find | head -1` idiom. Not a live code defect, but worth a
  doc-consistency pass once the hook's own selection logic changes, so the manual recovery
  instructions don't contradict the corrected automated behavior.

**Existing fixture-test precedent to extend, not replace.**
`agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` already
established the exact pattern this task's fixture test should follow: it drives
`subagent-postflight.sh` as a real subprocess against `mktemp -d` fixtures with `cwd` set to the
fixture root, and separately builds an **isolated deployed-layout copy**
(`<tmp>/.claude/{hooks,scripts,scripts/lib}/`) of `events-log-lifecycle.sh` +
`events-append.sh` + `deploy-root-guard.sh` + `lib/common.sh` to drive that hook's companion
case without touching the real repo's `specs/events.jsonl` (`deploy-root-guard.sh` refuses to
run from a source-store path, and always resolves writes to the real repo's events.jsonl
regardless of cwd — hence the isolated copy). The new "act only on the correlated marker"
fixture belongs in this same file, following its `make_postflight_fixture`/`run_postflight` and
`make_events_fixture`/`run_events_hook` helper conventions, synthesizing a SubagentStop payload
with `session_id` (`cc_session_id`) set to a specific value and asserting the hook selects only
the marker whose `.cc_session_id` matches it — with a sibling marker present for an unrelated
task/session that must NOT be acted on (must not block, must not be deleted).

### Recommendations

1. **`skill-base.sh` (`skill_create_postflight_marker`)**: add `cc_session_id` to the emitted
   marker JSON, sourced from `${CLAUDE_CODE_SESSION_ID:-}` (empty string, not a placeholder,
   when unset — e.g. manual/test invocation outside Claude Code, mirroring the `:-` fallback
   idiom already used at `update-task-status.sh:613`). Keep the 5-arg function signature
   unchanged (no new parameter needed — read the env var directly, exactly as
   `update-task-status.sh` already does for the `workflow-active-<key>` marker).
2. **`subagent-postflight.sh` (`find_marker`)**: read `.session_id` from hook stdin (same
   `jq -r '.session_id // empty'` idiom used throughout the hooks directory) as
   `CC_SESSION_ID`. Change `find_marker()` from "return the first hit" to "enumerate all
   `.postflight-pending` markers, parse each with `jq empty` first (reuse the existing
   malformed-marker guard), and select the one whose `.cc_session_id` equals `CC_SESSION_ID`."
   If zero match, behave exactly as the current "no marker" path (allow stop, `echo '{}'`) —
   never fall back to an arbitrary marker. If a marker lacks `cc_session_id` entirely (legacy
   marker written before this fix, or `CLAUDE_CODE_SESSION_ID` was unset at write time), it
   cannot be positively correlated to any session and must not be selected either — this is a
   deliberate fail-safe, not a regression, since acting on it would reproduce the exact defect
   being fixed.
3. **Cap-reached deletion log line**: `check_loop_guard()`'s `log_debug` call at the
   `MAX_CONTINUATIONS` branch currently reads `"Loop guard triggered: $count >= $MAX_CONTINUATIONS"`
   with no mention that a marker is about to be deleted, nor which task/session it belongs to.
   Extend it (still inside `subagent-postflight.sh`, no new file) to name the marker path, task
   number, and correlated `cc_session_id`/`session_id`, with wording that is textually distinct
   from a normal `skill_cleanup` removal (which is a silent `rm -f` in skill-base.sh with no log
   line at all — the two paths are already structurally distinguishable by "does a log line
   exist," but the AC asks the log line itself to say which kind of deletion it is, e.g.
   `"CAP-REACHED DELETE: ..."` vs. the hook's existing `"stop_hook_active flag set, allowing
   stop"` removal branch, which should get an equally explicit label).
4. **`events-log-lifecycle.sh`**: apply the identical correlation logic to its independent
   `MARKER_FILE` selection in the SubagentStop branch (same enumerate-all + `cc_session_id`
   match). This file is not in the delegation's binding SOURCE-STORE RULE list — flag this
   explicitly to the planner as a needed scope addition, since without it the events.jsonl
   attribution AC is unreachable. (See "Scope gap to flag for planning" above and the "Risks"
   section below.)
5. **Test**: extend `test-subagent-postflight-marker.sh` with the cross-session fixture
   described above (two markers, two `cc_session_id` values, assert selection and non-mutation
   of the foreign marker), and update `test-postflight-marker-schema.sh`'s `EXPECTED_KEYS` to
   include `cc_session_id`.
6. **Docs**: update `context/patterns/postflight-control.md`'s marker Format/Fields table to add
   `cc_session_id`, and its "SubagentStop Hook Behavior" section to describe the new
   correlation step (mirroring how it already documents the malformed-marker guard).

## Decisions

- Confirmed with the team lead's framing: Part A (teammate `.return-meta.json` ownership) is
  out of scope; this report addresses Part B only.
- Correlation key is `$CLAUDE_CODE_SESSION_ID` / hook stdin `.session_id`, stored as a new
  `cc_session_id` marker field — not a new lookup table, not a change to the existing
  agent-system `session_id` field's meaning. This keeps `session_id` semantics (agent-system
  `sess_...` id) fully backward compatible for every other consumer of the marker schema.
- "Act only on the correlated marker; never on an arbitrary one" is implemented as: no match ⇒
  behave identically to "no marker present" (never guess, never fall back to `head -1`).

## Risks & Mitigations

- **Risk**: the SOURCE-STORE RULE given to this task names only two files, but the stated
  acceptance criterion on events.jsonl attribution requires a third (`events-log-lifecycle.sh`).
  **Mitigation**: flagged explicitly above; recommend the plan either (a) get scope
  confirmation to touch `events-log-lifecycle.sh` too — consistent with existing precedent
  where the two hooks were fixed together for the analogous malformed-marker defect — or (b) if
  scope is held strictly to two files, explicitly document in the plan that the events.jsonl AC
  is deferred/unreachable this round, so it isn't silently dropped.
- **Risk**: legacy `.postflight-pending` markers on disk (written before this fix deploys) will
  lack `cc_session_id` and, under the "no match ⇒ do nothing" rule, will never be picked up by
  the hook again — they become stuck until `skill-refresh`'s age-based `-mmin +60` sweep clears
  them. **Mitigation**: this is the correct, safe failure mode (silently reverting to `head -1`
  for legacy markers would reopen the exact defect), and the existing orphan-sweep mechanism
  already exists for this. Worth one line in the plan's risk section, not a design change.
- **Risk**: test-schema breakage from the new field is mechanical but easy to miss.
  **Mitigation**: named explicitly in Recommendation 5 above.

## Context Extension Recommendations

- **Topic**: Claude Code session-identity correlation (`$CLAUDE_CODE_SESSION_ID` /
  `cc_session_id`).
- **Gap**: the two-id-spaces explanation (agent-system `session_id` vs. Claude Code's native
  session UUID) is currently scattered across comments in `update-task-status.sh`,
  `wezterm-preflight-status.sh`, `events-log-lifecycle.sh`, and `events-format.md`, each
  re-deriving the same explanation rather than citing one canonical source.
- **Recommendation**: not urgent enough to block this task, but a future `/meta` pass could
  consolidate these into one `context/patterns/` doc (e.g.
  `context/patterns/cc-session-correlation.md`) that all four sites point to, the same way
  `postflight-control.md` already centralizes the marker-file protocol.

## Appendix

Key files read:
- `agent-system/extensions/core/hooks/subagent-postflight.sh` (full)
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (full)
- `agent-system/extensions/core/scripts/skill-base.sh` (marker-writer region, lines ~236-270)
- `agent-system/extensions/core/scripts/update-task-status.sh` (workflow-active marker region,
  lines ~590-635)
- `agent-system/extensions/core/hooks/wezterm-preflight-status.sh` (header + CC_SESSION_ID
  capture)
- `agent-system/extensions/core/context/formats/events-format.md` (`cc_session_id` field def,
  "Claude Code OTel Correlation" section)
- `agent-system/extensions/core/context/patterns/postflight-control.md` (full)
- `agent-system/extensions/core/scripts/tests/test-subagent-postflight-marker.sh` (full)
- `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` (EXPECTED_KEYS
  region)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (marker cleanup region, to
  confirm it is unaffected)
- `specs/state.json` (task 72 entry, `file_scope`, full description history)
- `specs/PATH.md` (team-mode deletion decision, task 72 narrowing entry at line 238)
- grep survey: all `find specs -maxdepth 3 -name ".postflight-pending"` call sites across
  `agent-system/`; all `CLAUDE_CODE_SESSION_ID` references across `agent-system/`.

Search queries used: grep for `find_marker`, `postflight-pending`, `session_id`,
`cc_session_id`, `agent_id`, `CLAUDE_CODE_SESSION_ID`, `SubagentStop` across
`agent-system/extensions/core/{hooks,scripts,context}` and `agent-system/extensions/memory/`.
