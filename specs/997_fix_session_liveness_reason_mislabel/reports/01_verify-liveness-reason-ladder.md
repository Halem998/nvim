# Research Report: Fix `session_liveness()` Reason Mislabel

**Task**: Report a confirmably-dead pid within the grace floor as its own liveness reason
**Started**: 2026-08-10
**Completed**: 2026-08-10
**Effort**: Small (single-function fix + doc/test updates)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/, .claude/ deployed mirror), specs/state.json task description
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's root-cause quote, line numbers, and behavioral claims all match the
  code at current HEAD exactly (verified against
  `agent-system/extensions/core/scripts/task-lock.sh` lines 1329-1369). No drift from the
  described refactor state.
- The deployed `.claude/` tree is byte-identical to the source-store copy for every file named
  in the task's `file_scope`, so no separate deployed-tree divergence exists to reconcile.
- All named consumers of `liveness_reason` are opaque string interpolation (JSON field copy or
  human-readable template substitution) — none branch on the literal `"pid-alive"` string. This
  confirms the task's claim ("known consumers interpolate it as an opaque placeholder") and
  found no counter-example.
- `cmd_session_list`'s `live_flag` case statement and `cmd_session_reap`'s reap-set case
  statement both use `dead-pid|stale-heartbeat)` as the only named branches with `*)` wildcard
  defaults — a new sixth reason therefore automatically gets `live: true` (via the list wildcard)
  and is automatically excluded from the reap set (via the reap wildcard) with **zero code
  changes needed in either case statement**. `session_contention()`'s D4 liveness exclusion
  filters on the boolean `.live` field, not the reason string, so it also needs no change. This
  is a stronger confirmation of the task's requirement #2 than the task description states: the
  verdict-preservation guarantee is not just achievable, it falls out of the existing wildcard
  branches for free.
- Found a third doc site stating "session_liveness()'s five reasons" beyond the two named in the
  task description: `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` line 133
  (a code comment, not a doc file, but textually the same claim as
  `batch-admit-schema.md` line 119).
- Test coverage gap: neither named test file actually exercises the buggy code path (dead pid,
  age below `SESSION_REGISTRY_DEAD_PID_MIN`) through `session-list`/the reason string itself.
  `test-session-registry.sh` Case 8 creates exactly this fixture but only asserts the entry
  is *not reaped* — it never calls `session-list` or inspects `liveness_reason` for it.
  `test-conflict-predicate.sh` Case 4.2's dead-pid fixture uses `mins_ago=20`, which is *above*
  the default 10-minute floor, so it exercises the `dead-pid` (not the buggy) branch. The planner
  should add a new assertion (not just rely on existing passing tests) to cover the verification
  bar's first two bullets.
- This orchestration session's own session-registry entry (`specs/.sessions/sess_1786322063_3251e8.json`)
  is registered under the *bare* session id `sess_1786322063_3251e8`, while this task's own
  delegation `session_id` is the *suffixed* per-task id `sess_1786322063_3251e8_997`. This is the
  live self-contention instance referenced in the task prompt — see the dedicated section below.
  It is orthogonal to the liveness-reason bug (a `session_id` self-exclusion mismatch in
  `session_contention()`'s D4 exclusion 1, not a `liveness_reason` labeling problem) and is
  explicitly out of scope for this task.

## Context & Scope

Verification/inventory research only, per the task description's instruction that the
description itself is a near-complete root-cause analysis. No re-diagnosis was performed; every
claim in the description was checked against current HEAD and either confirmed or refined below.

## Findings

### 1. Ladder code matches the description's quote exactly

`agent-system/extensions/core/scripts/task-lock.sh`, `session_liveness()`, lines 1329-1369:

```bash
session_liveness() {
  local f="$1"
  local pid age reason=""
  ...
  pid=$(jq -r '.pid // empty' "$f" 2>/dev/null) || true
  age=$(age_minutes "$(jq -r '.heartbeat_at // empty' "$f" 2>/dev/null)")

  if [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
    if ! kill -0 "$pid" 2>/dev/null; then
      if [ "$age" -gt "$SESSION_REGISTRY_DEAD_PID_MIN" ]; then
        reason="dead-pid"
      fi
    fi
  fi

  if [ -z "$reason" ] && [ "$age" -gt "$SESSION_REGISTRY_REAP_MIN" ]; then
    reason="stale-heartbeat"
  fi

  if [ -z "$reason" ]; then
    if [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
      reason="pid-alive"
    else
      reason="undeterminable"
    fi
  fi

  echo "$age $reason"
}
```

This is a byte-for-byte match of the description's quoted ladder. `.claude/scripts/task-lock.sh`
(the deployed copy) is identical to the source-store copy (`diff` exit 0), so there is no
deployed/source divergence to account for.

Confirmed defect mechanics: when `kill -0` fails (line 1349) but `age <= SESSION_REGISTRY_DEAD_PID_MIN`
(line 1350's `-gt` test fails), `reason` stays empty and falls through to the final `if [ -z "$reason" ]`
block (lines 1360-1366), which tests only "`pid` is numeric" — the already-computed
`kill -0` failure is discarded. The description's characterization is exact.

### 2. Consumer inventory — `liveness_reason` / `pid-alive` / `dead-pid` / `session_liveness`

Grepped `agent-system/` (source store) and `.claude/` (deployed mirror, confirmed identical) for
`liveness_reason`, `pid-alive`, `dead-pid`, `stale-heartbeat`, `undeterminable`, and
`session_liveness`. Every hit, classified:

| Site | Classification | Notes |
|---|---|---|
| `scripts/task-lock.sh` `session_liveness()` | Producer | Section 1 above |
| `scripts/task-lock.sh` `cmd_session_list()` (`live_flag` case, ~line 1497-1500) | **Branches on literal, but via wildcard default** | `case "$liveness" in dead-pid\|stale-heartbeat) live_flag="false" ;; *) live_flag="true" ;; esac` — a new reason automatically gets `live: true` with no edit needed. |
| `scripts/task-lock.sh` `cmd_session_reap()` (reap-set case, ~line 1421-1436) | **Branches on literal, but via wildcard default** | `case "$liveness" in dead-pid\|stale-heartbeat) reason="$liveness" ;; corrupt) ... ;; *) reason="" ;; esac` — a new reason automatically falls to `*) reason=""` (not reaped) with no edit needed. |
| `scripts/lib/file-scope-overlap.sh` `session_contention()` (D4 exclusion 2, line 119) | Not a reason-string consumer | Filters on `$sess.live == true` (the boolean), not on `liveness_reason` text. Unaffected either way. |
| `scripts/orchestrate-batch-admit.sh` lines 495-496 | Opaque interpolation | Copies `liveness_reason` verbatim into `session_liveness_reason` JSON field and into the templated `reason` human string. No branch. |
| `scripts/orchestrate-predispatch-review.sh` lines 404, 508 | Opaque interpolation | Re-presents the batch-admit verdict's `session_liveness_reason` field verbatim (jq passthrough) and interpolates it into a report line. No branch. |
| `scripts/orchestrate-dry-run-report.sh` line 360 | Opaque interpolation | `liveness=$(... jq -r '.session_liveness_reason // empty')`, interpolated into a `reason="..."` string. No branch on the value. |
| `skills/skill-orchestrate/SKILL.md` lines 1724, 1730 | Opaque interpolation (prose template) | `{session_liveness_reason}` placeholder in a warning-log template and a defer-ledger JSON template string. |
| `commands/orchestrate.md` line 319 | Opaque interpolation (prose template) | Same warning-log template as SKILL.md. |
| `docs/architecture/batch-admit-schema.md` lines 91, 119, 425 | Prose + a **constrained allowed-value list** | Line 91 is a full rendered example JSON blob with `"session_liveness_reason":"pid-alive"` (unaffected by the fix — real example, still valid). Line 119 is the schema table row constraining `session_liveness_reason` to `pid-alive`/`corrupt`/`undeterminable` (**needs updating** — see Section 3). Line 425 is a prose reference to the field name only. |
| `context/patterns/task-lock.md` lines 726, 744-756, 832-869 | Prose definition | Lines 832-845 enumerate the five reasons as bullet points (this is the "~line 842" `pid-alive` bullet named in the task description, confirmed at exactly line 842); lines 857-862 restate the two-signal reap logic in prose, also implicated. |
| `context/standards/orchestrator-runtime-files.md` line 39 | Prose, incidental | Mentions "pid-liveness-shortened `dead-pid` band" — not a `pid-alive` reference, unaffected. |
| `scripts/test-session-registry.sh` | Test fixture / assertion | See Section 4 — Case 8 exercises the buggy scenario but does not assert on the reason string. |
| `scripts/test-conflict-predicate.sh` | Test fixture / assertion | See Section 4 — dead-pid fixture (4.2) uses age above the floor, does not exercise the buggy branch. |
| `scripts/test-four-tier-conflict.sh` line 238 | Prose comment only | References "dead-pid" conceptually; not a literal-string consumer. |

**Conclusion**: no consumer branches on the literal `"pid-alive"` string in a way that would
break when a sixth `dead-pid-within-grace` reason is introduced. The two case statements inside
`task-lock.sh` itself use wildcard defaults that already produce the required verdict
(`live: true`, not reaped) for any *new, unnamed* reason string — this means the sixth reason can
be added with **no changes to `cmd_session_list` or `cmd_session_reap`**, only to
`session_liveness()`'s ladder itself (to emit the new reason) and its own docstring.

### 3. Five-reasons count claims — confirmed two, found a third site

- `docs/architecture/batch-admit-schema.md` line 119 (exact task-description line number
  confirmed): `"One of `session_liveness()`'s five reasons (`task-lock.sh`) — always one of
  `pid-alive` / `corrupt` / `undeterminable` here..."`. **Needs updating on two axes**: the count
  ("five" -> "six") and, separately, confirm whether the allowed-value list
  (`pid-alive`/`corrupt`/`undeterminable`) needs `dead-pid-within-grace` appended — it does,
  because the D4 exclusion this line describes filters on `live == true`, not on the literal
  `dead-pid`/`stale-heartbeat` exclusion list, so a `dead-pid-within-grace` entry (which is
  `live: true`) will reach this same `session_active` verdict path exactly like `pid-alive` does
  today.
- `context/patterns/task-lock.md` line 842 (exact task-description line number confirmed): the
  `pid-alive` bullet's definition ("not `dead-pid`, not `stale-heartbeat`, and `pid` is a
  parseable integer for which `kill -0` succeeded") is false in exactly the window this task
  fixes — will read as contradicting the fixed code unless updated. Note: this doc file does not
  literally contain the phrase "five reasons" anywhere (`grep -n "five"` on the file finds two
  unrelated hits at lines 80 and 363); it instead enumerates the five reasons as five bullet
  points (lines 834-845), so the "count claim" here is implicit (bullet count), not a literal
  string to search-and-replace.
- **Third, previously unnamed site**: `scripts/orchestrate-batch-admit.sh` line 133, a code
  comment: `"One of session_liveness()'s five reasons (task-lock.sh) — always one of pid-alive /
  corrupt / undeterminable here..."` — textually near-identical to the
  `batch-admit-schema.md` line 119 claim (same allowed-value list, same "five" count). This is a
  code comment rather than a standalone doc file, but it states the same claim and will go stale
  identically if not updated alongside the two named docs. Since the task's `file_scope` names
  `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/context/patterns/task-lock.md`, and
  `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` but not
  `orchestrate-batch-admit.sh`, the planner should decide whether to widen `file_scope` to include
  this file (recommended, since it is a direct textual duplicate of a documented defect) or treat
  it as an acceptable known-stale comment.
- No other "five reason" / "five-branch" occurrences were found anywhere under `agent-system/`.

### 4. `cmd_session_list`'s `live_flag` case and `cmd_session_reap`'s reap set — confirmed as described

Both confirmed in Section 2's table above with exact line ranges:
- `cmd_session_list` (task-lock.sh ~1493-1500): `dead-pid|stale-heartbeat) live_flag="false" ;; *) live_flag="true" ;;` — wildcard default.
- `cmd_session_reap` (task-lock.sh ~1420-1436): `dead-pid|stale-heartbeat) reason="$liveness" ;; corrupt) ... ;; *) reason="" ;;` — wildcard default, reap only fires when `reason` is non-empty.

Both match the task description's requirement #2 exactly: a new `dead-pid-within-grace` reason
will report `live: true` and will not be selected by `session-reap --dry-run`, with **no code
changes to either function** — only `session_liveness()`'s own ladder needs to change to emit the
new string in the right branch.

`session_contention()`'s D4 exclusion (`file-scope-overlap.sh` line 119,
`select($sess.live == true)`) filters on the same `.live` boolean session-list already computed,
so the contend-set is likewise unaffected without any change to `file-scope-overlap.sh`.

### 5. Test file inventory and coverage gap

Both named test files exist and are executable:
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (24440 bytes, executable)
- `agent-system/extensions/core/scripts/test-session-registry.sh` (317 lines) — this is "the
  session-registry reap tests" referenced generically in the verification bar; there is no
  separate, differently-named "session-registry reap tests" file.

**Gap identified — neither file currently exercises the buggy branch through the reason string**:

- `test-session-registry.sh` **Case 8** (`sess_dead_young`, lines 273-282) creates a dead-pid
  fixture with a young heartbeat (below `SESSION_REGISTRY_DEAD_PID_MIN`) — this is *exactly* the
  fixture shape that triggers the bug. But the assertion only checks that the file still exists
  after `session-reap` (i.e., it was not reaped) and does not appear in the reap output. It never
  invokes `session-list` or inspects `liveness_reason` for this fixture, so it currently would
  pass identically whether the reason reported is the buggy `pid-alive` or the fixed
  `dead-pid-within-grace`. **This test needs a new assertion added** (call `session-list`, assert
  `liveness_reason == "dead-pid-within-grace"` and `live == true` for this fixture) to actually
  cover the verification bar's first bullet ("reports the new reason with `live: true`").
- `test-conflict-predicate.sh` **Case 4.2** (`write_session_fixture "sess_dead" "$DEAD_PID" ...
  20`, lines 236-241) uses `mins_ago=20`, which is *above* the default 10-minute
  `SESSION_REGISTRY_DEAD_PID_MIN` floor — so this fixture exercises the `dead-pid` (already
  correctly labeled) branch, not the buggy below-floor branch. It only asserts
  `decision == "admit"` (verdict, unaffected either way), not the reason string. No fixture in
  this file currently constructs a dead-pid-below-floor session and inspects the resulting
  `liveness_reason` or `session_liveness_reason` field.
- Both files DO already have infrastructure the planner can reuse directly: `write_session_fixture`
  in `test-conflict-predicate.sh` takes a `heartbeat_minutes_ago` argument, so a new case with
  `mins_ago` less than the floor plus a dead pid, followed by inspecting `.session_liveness_reason`
  on a `session_active` defer verdict, is a small addition. Similarly `test-session-registry.sh`'s
  existing `sess_dead_young` fixture (Case 8) can be extended with a `session-list` call and a
  `liveness_reason` grep, rather than requiring a new fixture.

Given the verification bar's exact wording ("A registry entry with a dead pid and age below the
floor reports the new reason with `live: true`, and `session-reap --dry-run` does not select it"),
the planner should treat "these tests still pass" as necessary but not sufficient — the existing
tests do not currently assert the specific fact the bug fix is about, so new assertions (not just
a passing re-run) are required to actually verify the fix.

### 6. Live self-contention instance observed this session — noted, not fixed

The orchestrator flagged that this session observed a registered batch session self-contending
due to a suffixed-vs-bare session id mismatch. Confirmed directly in the live registry:

- This task's delegation context carries `session_id: "sess_1786322063_3251e8_997"` (suffixed
  with the task number).
- The actual registry entry on disk is `specs/.sessions/sess_1786322063_3251e8.json`, whose
  `session_id` field is the *bare* `"sess_1786322063_3251e8"` (no task suffix), covering
  `task_numbers: [984, 985, 986, 993, 995, 997, 1000, 1002]` — i.e., this same multi-task batch
  run, registered once under the bare id and covering all eight tasks including this one.
- `orchestrate-batch-admit.sh`'s `--session-id` flag (line 42: "the CALLER's own session id, the
  *same* id registered via ...") feeds `session_contention()`'s D4 exclusion 1 (self-exclusion by
  session id, `file-scope-overlap.sh` line ~114: `.session_id != $own_sid`). If a per-task
  dispatch passes the *suffixed* id (`..._997`) as `--session-id` while the registry holds the
  *bare* id, the self-exclusion string comparison never matches, and the session's own
  `file_scope` can be reported as contending against itself for later tasks in the same batch.

**This is orthogonal to the `liveness_reason` mislabel bug fixed by this task**: it is a
`session_id` *equality*/self-exclusion defect (D4 exclusion 1, a different code path from D4
exclusion 2's `live` filter that `session_liveness()` feeds), not a `liveness_reason` *labeling*
defect. No interaction was found between the two: fixing the reason-string ladder does not touch
`session_contention()`'s self-exclusion comparison, and fixing the self-id mismatch would not
touch `session_liveness()`'s reason ladder. Recorded here per the task prompt's instruction to
note but not fix it — worth a follow-up task if not already tracked.

## Decisions

None — this is a verification/inventory report; the fix design (sixth reason name, ladder
restructure) is already fully specified in the task description and requires no additional
research decisions.

## Risks & Mitigations

- **Risk**: the two named docs are updated but the third `orchestrate-batch-admit.sh` line-133
  comment is missed, leaving a stale "five reasons" claim in a file not listed in `file_scope`.
  **Mitigation**: flag explicitly to the planner (done above); recommend widening `file_scope` or
  treating it as an in-scope incidental edit since it is a direct textual duplicate.
- **Risk**: "tests still pass" is treated as sufficient verification when neither named test file
  currently asserts the specific fact under test. **Mitigation**: flagged in Section 5; the plan
  should include adding assertions to `test-session-registry.sh` Case 8 (and optionally a new
  case in `test-conflict-predicate.sh`) rather than only re-running the existing suite.
- **Risk**: conflating this task's fix with the self-contending session-id bug noted in Section 6.
  **Mitigation**: explicitly scoped out above; no code path overlap found.

## Context Extension Recommendations

None — `context/patterns/task-lock.md` already documents this area in depth; the task's own work
item 3 (updating that doc alongside the code) is the correct extension point, not a new file.

## Appendix

- Searches: `grep -rn "liveness_reason\|pid-alive\|dead-pid\|stale-heartbeat\|undeterminable" agent-system/ .claude/`
  (scoped to `.sh`/`.md` via task-type-appropriate follow-up greps), `grep -n "five" context/patterns/task-lock.md`,
  `diff agent-system/.../task-lock.sh .claude/scripts/task-lock.sh` (confirmed identical).
- Files read in full or by targeted range: `scripts/task-lock.sh` (session_liveness, cmd_session_reap,
  cmd_session_list), `scripts/lib/file-scope-overlap.sh` (session_contention), `scripts/orchestrate-batch-admit.sh`,
  `scripts/orchestrate-predispatch-review.sh`, `scripts/orchestrate-dry-run-report.sh`,
  `docs/architecture/batch-admit-schema.md`, `context/patterns/task-lock.md`,
  `skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`, `scripts/test-conflict-predicate.sh`,
  `scripts/test-session-registry.sh`.
- Live registry inspected: `specs/.sessions/*.json` (11 entries), specifically
  `sess_1786322063_3251e8.json` for the self-contention note.
