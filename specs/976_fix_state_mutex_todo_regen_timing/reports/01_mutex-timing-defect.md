# Research Report: Fix state-mutex / TODO-regen timing defect

**Task**: Move TODO regeneration out of the state mutex critical section (or extend the window)
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: small-medium (single targeted script change + a faster jq path + one regression test)
**Dependencies**: prerequisite for four other tasks in this batch
**Sources/Inputs**: codebase (state-write.sh, task-lock.sh, generate-todo.sh, orchestrator-postflight.sh, update-task-status.sh, test-state-write-concurrency.sh), live timing measurements against the real `specs/state.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Confirmed and reproduced**: a deployed `generate-todo.sh --dry-run` run against the current
  101-task, 636KB `specs/state.json` takes **6.9s wall time** (measured directly), worse than the
  review's ~5.5s estimate. This exceeds both `SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000` (task-lock.sh
  line 543) and `SCOPE_MUTEX_STALE_SEC=10` (line 542).
- **Root cause of the slowness, empirically isolated**: it is **jq subprocess-spawn count**, not
  file-size-driven re-parsing. A bare jq subprocess spawn costs ~2.3ms regardless of input size
  (measured: 1000 spawns of `jq -n 'null'` = 2.30s). `generate_task_entry()` in generate-todo.sh
  spawns 8-11 jq subprocesses per task (one full-file extract, then up to 7 field reads plus
  conditional dependency/artifact calls, all on an already-extracted small string), and the
  outer loop in `generate_todo()` spawns one MORE full-file jq call per task purely to classify
  terminal vs. active status — a value `generate_task_entry()` already computes internally. Over
  101 tasks that is roughly ~1,000-1,200 jq subprocess spawns, which alone accounts for the
  majority of the 6.9s.
- **A second, independent, and more severe defect than "just slow"**: `state-write.sh`'s
  `acquire_mutex()` calls `task-lock.sh scope-acquire "$SESSION_ID"` with **no `stale_sec`
  argument at all**, so it always inherits the 10s default — unlike
  `orchestrator-postflight.sh`, which explicitly passes `POSTFLIGHT_SCOPE_STALE_SEC=30` for
  exactly this reason. Worse: **the 5000ms acquire *wait budget* is not parameterizable at all**
  — `acquire_scope_mutex()` (task-lock.sh ~line 550) hardwires `wait_budget_ms` to the literal
  `SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000` global, with no CLI override and no `${VAR:-default}`
  env-var indirection (unlike `TASK_LOCK_STALE_MIN`). So even if `state-write.sh` passed a larger
  `stale_sec`, a **waiter still gives up and ABORTs after exactly 5000ms** — extending
  `stale_sec` alone fixes the "reclaim-from-live-holder" defect (consequence 2 in the task) but
  does **not** fix the "waiter ABORTs" defect (consequence 1) on its own.
- **The clean fix is item 1 (move regen out of the critical section), not item 2 or 3 alone.**
  Measured: a `state-write.sh`-shaped write cycle (jq transform + `jq empty` validate + `mv`,
  no regen) on a copy of the real state.json takes **13ms**. Moving `generate-todo.sh` outside
  the mutex bracket drops the critical section from ~6.9s to ~13ms — three orders of magnitude
  under both the 5s acquire budget and the 10s staleness window, with enormous margin, and
  without needing to touch `task-lock.sh` at all.
- **Recommendation**: combine items 1 + 3 (not 2, and 4 as the regression guard):
  1. In `state-write.sh`, release the OWNED-HERE mutex (call `release_mutex` explicitly) before
     invoking `generate-todo.sh`, but leave GUEST-mode behavior (nested inside
     `orchestrator-postflight.sh`'s own bracket) unchanged — that caller already budgets
     `POSTFLIGHT_SCOPE_STALE_SEC=30` for a regen happening inside its own critical section by
     design.
  3. Rewrite `generate-todo.sh`'s per-task section as a single-pass jq program (one full-file jq
     call emitting all task data, e.g. NDJSON) instead of ~10-12 jq subprocesses per task, and
     drop the outer loop's redundant per-task status-only full-file jq call. This is valuable
     independent of item 1, since `generate-todo.sh` also runs standalone (`--dry-run`, `/todo`,
     manual regen) and any future caller that *does* nest it in a critical section benefits too.
  4. Add the regression guard: assert `generate-todo.sh` wall time stays well under 40% of the
     10s staleness window (or, more directly, assert the state-write.sh critical section itself
     — measured via its own timing, not generate-todo.sh's — stays under ~1s), per the task's
     verification bar.
  - Item 2 (pass an explicit `stale_sec >= 30`) is not required once item 1 lands (hold time
    drops to ~13ms), but costs nothing and is reasonable defense-in-depth for any other future
    slow operation inside the critical section; a planner may include it optionally. It does
    NOT by itself close consequence 1 (the 5000ms acquire-budget constant is not overridable),
    so it must not be substituted for item 1.

## Context & Scope

`state-write.sh`, `generate-todo.sh`, and `task-lock.sh` under
`agent-system/extensions/core/scripts/` are the file_scope for this task (source-store paths;
`.claude/scripts/` is the disposable deploy copy). The defect: `state-write.sh --regen-todo`
(used by `update-task-status.sh` on every status flip) runs `generate-todo.sh` **inside** the
`specs/.scope-lock` mutex critical section, after the state.json `mv` and before mutex release
(state-write.sh lines 221-226). As `specs/state.json` grows, this regen step takes longer than
both the mutex's wait budget and its staleness window, causing either spurious `ABORT`s in
concurrent multi-task dispatch, or (worse) a waiter reclaiming the mutex from a still-live holder.

## Findings

### Codebase Patterns

**`state-write.sh`'s mutex bracket** (`agent-system/extensions/core/scripts/state-write.sh`):
- `acquire_mutex()` (lines 159-173) honors `SCOPE_MUTEX_HELD=1` guest mode (returns immediately,
  no nested acquire) or calls `"$SCRIPT_DIR/task-lock.sh" scope-acquire "$SESSION_ID"` — **note:
  no second `stale_sec` argument is ever passed**, so it always takes `cmd_scope_acquire`'s
  10s default (task-lock.sh line ~1007: `local session_id="$1" stale_sec="${2:-}"`).
- The optional in-mutex regen block (lines 221-226): `if [ "$REGEN_TODO" = true ]; then
  "$SCRIPT_DIR/generate-todo.sh" || { echo "Warning: ..." >&2; }; fi` — this runs BEFORE the
  `trap cleanup EXIT` fires `release_mutex`, i.e. strictly inside the critical section.
- `release_mutex()` (lines 175-181) is already idempotent and already a no-op when
  `MUTEX_OWNED_HERE=false` (guest mode) — this is exactly the property needed to make "release
  early, then regen, then let the EXIT trap's second release be a no-op" safe to implement.

**`task-lock.sh`'s `.scope-lock` mutex constants** (task-lock.sh lines 537-557):
```
SCOPE_MUTEX_STALE_SEC=10
SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000
acquire_scope_mutex() {
  local requested_stale="${1:-}"
  acquire_named_mutex ".scope-lock" "$requested_stale" "$SCOPE_MUTEX_STALE_SEC" "$SCOPE_MUTEX_ACQUIRE_BUDGET_MS"
}
```
`acquire_named_mutex()` (lines 491-530) does honor a per-call `requested_stale` override for the
**staleness** window (this is what `orchestrator-postflight.sh` uses), but `wait_budget_ms` is
always the caller's own hardcoded `default_stale_sec`/`wait_budget_ms` pair — for `.scope-lock`
callers that is unconditionally `SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000`, with no override parameter
and no environment-variable indirection (contrast `TASK_LOCK_STALE_MIN="${TASK_LOCK_STALE_MIN:-30}"`,
which IS overridable). **This means no caller of `scope-acquire`, however it is invoked, can ever
wait longer than 5000ms before its acquire fails and ABORTs** — extending `stale_sec` only changes
when a *waiter* is entitled to reclaim a *stale* holder; it does nothing for a *waiter that simply
gives up* after 5s of contention against a still-fresh (non-stale) holder.

**`orchestrator-postflight.sh`'s existing, wider posture** (confirmed via grep,
lines ~283-320): it already knows regen can be slow and already passes
`POSTFLIGHT_SCOPE_STALE_SEC=30` explicitly to `scope-acquire`, i.e. it is designed to tolerate a
regen happening inside ITS OWN outer bracket. This means the "regen inside the mutex" problem is
specific to **non-guest (standalone)** `state-write.sh` calls — e.g. a bare
`update-task-status.sh` invocation outside an orchestrator-postflight bracket — not to the
orchestrator-postflight-wrapped path, which already budgets for it.

**`update-task-status.sh`** (grep confirms): its header says it is "Routed through
state-write.sh ... This supersedes this script's own former acquire_state_mutex ...", and its
Stage 7-ish write path calls `"$SCRIPT_DIR/state-write.sh" ... --regen-todo` (two call sites: a
no-op dry-run regen at ~line 376, and the real write at ~line 404-415). Neither call site passes
its own mutex parameters — both simply rely on `state-write.sh`'s defaults, i.e. both are exposed
to the 10s/5000ms defaults whenever they run standalone (not nested under
orchestrator-postflight.sh).

**`generate-todo.sh`'s per-task jq-spawn structure** (`generate_task_entry()`,
lines 160-304, and the calling loop in `generate_todo()`, lines 362-394):
- One full-file jq extract per task into `$task_json` (line 165-179).
- Then 7 unconditional `printf '%s' "$task_json" | jq -r '.field'` calls reading the ALREADY
  extracted small string (lines 183-190: title, project_name, status, task_type, topic, effort,
  description) — small-input jq calls, but each still pays the ~2.3ms process-spawn cost.
- Plus conditional calls: `deps_json` (always, line 230), `dep_list` (if deps present, line 235),
  `artifacts_len` (always, line 242), `artifacts_raw` (if artifacts present, line 251) — up to
  4 more.
- **Separately, in the OUTER loop** (`generate_todo()` lines 376-379), for every task number the
  loop does its OWN full-file jq re-parse purely to classify terminal vs. active:
  ```bash
  task_status=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .status' \
    "$STATE_FILE")
  ```
  This duplicates work `generate_task_entry()` already does internally moments later (its own
  `status` field extraction) — a second full-file jq parse per task that exists only to feed the
  `terminal_count`/`active_count` tally, which could instead reuse `generate_task_entry`'s own
  status value or be folded into a single upstream pass.
- Total: **8-12 jq subprocess spawns per task**, ~2 of which re-parse the full 636KB file. Over
  101 tasks that's ~1,000-1,200 jq invocations.

### External Resources

Not applicable — this is a self-contained shell/jq performance and concurrency-correctness
question, fully resolved by reading the three in-scope scripts and measuring directly against the
real repository state.

### Live Measurements (reproduced against the real repository)

| Measurement | Result |
|---|---|
| `specs/state.json` size / task count | 636,015 bytes / 101 active_projects |
| `generate-todo.sh --dry-run` wall time (deployed copy, real state.json) | **6.923s** real (4.447s user, 3.110s sys) |
| Single full-file `jq` parse (amortized over 20 runs) | ~7.9ms each |
| 1000 bare jq subprocess spawns (`jq -n 'null'`) | 2.302s total (~2.3ms/spawn) — dominant cost is process spawn, not parse size |
| 1000 jq calls on an already-small extracted string | 2.322s total — confirms the small-string calls cost the same per-spawn overhead as full-file calls |
| A `state-write.sh`-shaped write cycle (jq transform + `jq empty` + `mv`, no regen) on a copy of the real state.json | **13ms** |
| `test-state-write-concurrency.sh` (existing suite) baseline | 4/4 PASS today (no lost update, staging isolation, fail-closed acquire, guest-mode reentrancy) |

These measurements directly confirm: (a) the review's ~5.5s estimate for regen wall time was, if
anything, optimistic — 6.9s was observed; (b) the dominant cost is subprocess-spawn count, not
per-call file-parse cost, since spawning 1000 jq processes on trivial input costs almost exactly
the same as spawning 1000 jq processes on the real extracted per-task JSON; (c) removing regen
from the critical section reduces the section's own duration from ~6.9s to ~13ms — three orders
of magnitude of margin under both the 5s acquire budget and the 10s staleness window.

### Recommendations

**Primary fix (WORK item 1): move `generate-todo.sh` out of the OWNED-HERE critical section.**

In `state-write.sh`, after the atomic `mv` succeeds, call `release_mutex` explicitly (not just
rely on the `trap cleanup EXIT`) BEFORE invoking `generate-todo.sh` when `--regen-todo` was
passed. Because `release_mutex()` is already a no-op when `MUTEX_OWNED_HERE=false` (guest mode),
this is safe in both modes:
- **Non-guest (this script itself acquired the mutex)**: releases immediately after the `mv`,
  then runs `generate-todo.sh` unsynchronized. The trap's later `release_mutex` call becomes a
  harmless no-op (idempotent, matches existing design).
- **Guest mode (nested inside `orchestrator-postflight.sh`'s own bracket)**: `release_mutex` is
  already a no-op (this script never owned the mutex to begin with), so behavior here is
  UNCHANGED — regen continues to run inside the outer caller's bracket, exactly matching that
  caller's existing `POSTFLIGHT_SCOPE_STALE_SEC=30` design intent. Do not change this path.

This is the change that actually satisfies the verification bar ("measured mutex hold time for a
status flip is under 1s") with wide margin (measured 13ms), and it requires touching only
`state-write.sh` — no changes to `task-lock.sh` are required for this fix.

**Accepted trade-off, matching the task description's own framing**: once regen runs outside the
mutex, two concurrent `state-write.sh --regen-todo` calls could each release their own mutex and
then race to run `generate-todo.sh` concurrently. `generate-todo.sh` already writes TODO.md via
its own private-tempfile-then-`mv` atomic replace (no corruption possible), so the only externally
visible effect of the race is "last regen to finish wins" — which may occasionally reflect a
state.json snapshot slightly older than the very latest write, until the next regen. The task
description explicitly accepts this ("TODO.md is a generated view; last-writer-wins after a
snapshotted consistent state read is acceptable"). A generation-counter/re-check refinement is
possible but not necessary to meet the stated verification bar; recommend leaving it as an
optional follow-up rather than in scope for the initial fix, to keep the change minimal and
reviewable.

**Secondary, complementary fix (WORK item 3): make `generate-todo.sh` a single-pass jq program.**

Replace the ~8-12-jq-calls-per-task loop in `generate_task_entry()`/`generate_todo()` with:
1. ONE jq invocation over the whole `active_projects` array that emits, per task, all fields
   already extracted today (title, project_name, status, task_type, topic, effort, description,
   dependencies, artifacts — already pre-grouped/formatted as far as jq can reasonably do, e.g.
   NDJSON or a compact `@base64`-per-line format) sorted descending by `project_number` in the
   SAME jq call (removing the separate `sort -rn` + per-task status re-lookup in the outer loop).
2. A bash loop that only FORMATS the pre-extracted fields (string interpolation, `printf`,
   the existing artifact-grouping associative-array logic) — zero further jq subprocess calls
   per task.
This is valuable independent of item 1: `generate-todo.sh` also runs standalone (`--dry-run`,
`/todo`, any future manual regen trigger), and the measured 6.9s wall time is a real UX/wall-clock
cost regardless of whether it happens inside a mutex. Expected result based on the isolated
subprocess-spawn measurement above: dropping ~1,000 jq spawns to ~2 should reduce wall time from
~6.9s to well under 1s.

**WORK item 2 (pass explicit `stale_sec >= 30`) — not required, but harmless as defense-in-depth.**
Once item 1 lands, the critical section is ~13ms, so neither the 10s staleness window nor the
5000ms acquire budget is ever in danger for a plain state.json write. Passing a larger
`stale_sec` from `state-write.sh` costs nothing and guards against some future caller adding a
slow jq transform inside the (now regen-free) critical section, but must NOT be treated as a
substitute for item 1: because `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` is a hardcoded, non-overridable
5000ms constant in `task-lock.sh` (no CLI parameter, no env-var indirection), raising only
`stale_sec` cannot, by itself, stop a >5s regen from causing waiters to ABORT — it can only stop
the SEPARATE reclaim-from-live-holder failure mode. A planner may still choose to add this as a
one-line, no-risk hardening measure alongside item 1.

**WORK item 4 (regression guard) — required by the task's own verification bar.**
Add a test asserting either: (a) `state-write.sh`'s own critical-section wall time (from mutex
acquire to mutex release, measured directly, e.g. by instrumenting or timing around the
acquire/release boundary in a test harness) stays under 1s for a realistic-size state.json; or
(b) more simply, that `generate-todo.sh` no longer runs inside any mutex bracket at all (a
structural assertion: grep `state-write.sh` for `generate-todo.sh` and confirm no code path
between `acquire_mutex`/before `release_mutex` and the call remains — or a black-box test that
starts `state-write.sh --regen-todo` in the background, and successfully acquires
`specs/.scope-lock` mutex from ANOTHER process well before the regen described by the background
job would have finished, proving regen is not blocking the mutex). Follow
`test-state-write-concurrency.sh`'s existing isolated-temp-root convention (copy the scripts
under test byte-for-byte into a throwaway `$TMPROOT`, never touch the real `specs/` tree,
interleaving driven by real predicates/fixture cost rather than blind `sleep`).

## Decisions

- Recommend combining WORK items **1 + 3 + 4**; treat item 2 as optional, low-risk
  defense-in-depth rather than a required part of the fix, since it does not by itself close the
  spurious-ABORT failure mode (the 5s acquire-wait budget is a hardcoded, non-parameterizable
  constant independent of `stale_sec`).
- The `state-write.sh` change should distinguish guest mode (leave unchanged — regen stays inside
  `orchestrator-postflight.sh`'s own, already-widened 30s-staleness bracket) from owned-here mode
  (release early, then regen unsynchronized) — do not release the mutex in guest mode, since this
  script never owns it there.
- No changes to `task-lock.sh` are required to satisfy the stated verification bar, since item 1
  alone drops the critical section to ~13ms (measured), comfortably under the "1s" bar with three
  orders of magnitude of margin. `task-lock.sh` stays in file_scope for a planner who additionally
  chooses to implement item 2, but is not mandatorily touched.
- The generation-counter/re-check refinement mentioned as an option in the task's own WORK item 1
  text is not necessary to meet the accepted last-writer-wins semantics the task description
  itself sanctions; recommend treating it as an optional future hardening, not a requirement of
  this fix.

## Risks & Mitigations

- **Risk**: releasing the mutex before regen could allow a second `state-write.sh --regen-todo`
  call's `mv` to interleave with the first's now-unsynchronized `generate-todo.sh` read, producing
  a TODO.md that reflects neither the very-first nor the very-last state.json version exactly.
  **Mitigation**: this is the explicitly accepted last-writer-wins trade-off (task description);
  `generate-todo.sh`'s own atomic tempfile-then-mv write means the FINAL TODO.md always reflects
  SOME internally-consistent state.json snapshot, never a torn/corrupt write. The next regen
  (triggered by the next status flip) will catch up.
- **Risk**: the single-pass jq rewrite (item 3) is a larger, more error-prone change than item 1
  (touches all of `generate_task_entry()`'s formatting logic, including artifact type-grouping).
  **Mitigation**: this is exactly why `test-state-write-concurrency.sh`'s sibling
  `test-todo-generation` (or equivalent, if one exists) or a straightforward diff-based check
  ("TODO.md content identical before/after the rewrite, for the same state.json fixture") should
  gate the rewrite — a planner should treat item 3 as its own reviewable, independently-verifiable
  phase, separate from item 1's mutex-release change.
- **Risk**: item 1's "release early" change touches the one script every state.json write in the
  repository funnels through (`state-write.sh`), so a mistake here is high-blast-radius.
  **Mitigation**: `test-state-write-concurrency.sh` already exercises the exact
  guest-mode/owned-here mode distinction (case 4) that this change must preserve; re-running it
  (currently 4/4 PASS) after the change is the direct regression check, plus the new concurrent-
  `update-task-status.sh` test called for by the task's verification bar.

## Context Extension Recommendations

None — this is a self-contained scripts-level fix fully documented by the three in-scope files
and `orchestrator-postflight.sh`'s existing (correct) precedent; no new context file is warranted.

## Appendix

### Commands run
```bash
jq -r '.active_projects | length' specs/state.json          # 101
jq -r '.next_project_number' specs/state.json                # 990
time bash .claude/scripts/generate-todo.sh --dry-run          # 6.923s real
time (for i in $(seq 1 1000); do jq -n 'null' >/dev/null; done)              # 2.302s
time (for i in $(seq 1 1000); do printf '%s' "$small_json" | jq -r '.title' >/dev/null; done)  # 2.322s
time (jq '.next_project_number' /tmp/state-copy.json > /tmp/stage.json && jq empty /tmp/stage.json && mv ...)  # 13ms
bash .claude/scripts/test-state-write-concurrency.sh           # 4 passed, 0 failed (baseline, pre-fix)
```

### Key line references
- `agent-system/extensions/core/scripts/state-write.sh:159-173` — `acquire_mutex()`, no
  `stale_sec` passed to `scope-acquire`
- `agent-system/extensions/core/scripts/state-write.sh:175-181` — `release_mutex()`, already
  idempotent / no-op in guest mode
- `agent-system/extensions/core/scripts/state-write.sh:221-226` — the in-mutex regen block to move
- `agent-system/extensions/core/scripts/task-lock.sh:542-543` — `SCOPE_MUTEX_STALE_SEC=10`,
  `SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000` (the latter has no override path anywhere in the file)
- `agent-system/extensions/core/scripts/task-lock.sh:491-530` — `acquire_named_mutex()`, showing
  `stale_sec` is per-call-overridable but `wait_budget_ms` is not
- `agent-system/extensions/core/scripts/task-lock.sh:1006-1033` — `cmd_scope_acquire()` CLI
  surface: `session_id`, optional `stale_sec`, no wait-budget parameter
- `agent-system/extensions/core/scripts/generate-todo.sh:160-304` — `generate_task_entry()`,
  the ~8-12-jq-spawns-per-task hot path
- `agent-system/extensions/core/scripts/generate-todo.sh:376-379` — the outer loop's redundant
  per-task full-file status-only jq call
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh:283-320` — the existing,
  correctly-widened `POSTFLIGHT_SCOPE_STALE_SEC=30` precedent for guest-mode regen
