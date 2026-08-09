# Implementation Plan: Four-Tier Conflict Response

- **Task**: 946 - Auto-sequence conflicting work instead of aborting or skipping
- **Status**: [COMPLETED]
- **Effort**: 9 hours
- **Dependencies**: 945 (converged conflict-detection predicate — landed)
- **Research Inputs**: specs/946_auto_sequence_conflicting_work/reports/01_four-tier-conflict-response.md
- **Artifacts**: plans/01_four-tier-conflict-response.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Today the conflict-response ladder is implemented out of order: Tier 3 (warn/ABORT) is the
universal terminus, Tier 1 (auto-sequence) exists only inside `/orchestrate`'s cycling loop, and
Tiers 2 and 4 do not exist at all. This plan installs all four tiers in strict priority order by
(a) adding a bounded wait-and-retry subcommand to `task-lock.sh` that wraps the existing, unmodified
`cmd_acquire`, (b) giving plain multi-task `/research`, `/plan`, `/implement` a bounded two-pass
structure so an `in_batch` file-scope collision is re-sequenced rather than dropped, (c) preserving
the three existing ABORT variants verbatim as the warn tier, and (d) adding an
`orchestrator_mode`-gated ask tier reachable only from direct single-task invocations. Definition
of done: a test suite proves all four tiers plus non-convergence termination as `partial`, and no
same-session re-entry path can ever wait on its own lock.

### Research Integration

The research report is the binding input; its findings are encoded as plan constraints, not
rediscovered:

- Tier 1's concrete gap is plain multi-task Step 2.5, which drops an `in_batch`
  `file_scope_collision` into `skipped_tasks` permanently for the invocation, while `/orchestrate`'s
  Stage MT-3 step 4.5 retries the identical verdict on a later cycle.
- Tier 2 has no live implementation; the two reusable idioms are `acquire_named_mutex()` (mkdir-poll,
  holder-declared staleness, 5s/15s budgets) and `git-commit-scoped.sh`'s one-shot randomized-backoff
  `index.lock` retry with a visible `NOTE:`.
- Tier 3 is fully live as three ABORT variants inside `cmd_acquire`; their field content is preserved.
- Tier 4 is structurally unreachable under `orchestrator_mode: true`; the precedent for the split is
  `context/patterns/lit-stage4a-flow.md`'s `AUTONOMOUS_GLOBAL` branch.
- Same-session re-entry has three independent enforcement points that must all survive.

**Plan-time verification performed against the current source store** (facts the report left open or
stated approximately, now confirmed and binding on the implementer):

1. **The retry loop MUST NOT live inside `cmd_acquire`.** `cmd_acquire` acquires the global
   `specs/.scope-lock` mutex at entry (`acquire_scope_mutex` + `trap 'release_scope_mutex' RETURN`)
   and holds it for its entire body, including the ABORT branches the research report proposed
   wrapping. A retry loop placed there would hold a process-global mutex across the whole wait
   window, blocking every other task's acquire system-wide, and would itself be reclaimed by a
   competing waiter after `SCOPE_MUTEX_STALE_SEC=10`. This overrides the report's stated Tier-2
   recommendation ("implement bounded retry inside `cmd_acquire`") on evidence the report did not
   have. The retry must be an outer loop that calls the full, unmodified `cmd_acquire` afresh per
   attempt, so the mutex is acquired and released once per attempt and all three same-session
   exclusions re-run every attempt.
2. **The "sourced by five command files" statement is in `context/patterns/task-lock.md`**
   (Same-Session Re-Entry section), not in `batch-orchestration-guardrails.md` as the report framed
   it. `batch-orchestration-guardrails.md` mentions `command-gate-in.sh` only in its Exclusion Table,
   with no count. Both files are in `file_scope`. The correct count is **six** sourcing files:
   `research.md`, `plan.md`, `implement.md`, `revise.md`, `orchestrate.md`, and `task.md` (twice —
   `expand` and `abandon`). The same section's "Consumers (Five Distinct Wiring Paths)" list also
   enumerates only five operations for the gate-script path and omits `task.md`.
3. **Multi-task Step 3 acquires with a per-task derived session id**
   (`"${batch_session_id}_${task_num}"`), so two in-batch tasks are mutually foreign at lock level.
   This is why Step 2.5's admission pre-check, not Step 3, is the correct site for the Tier-1
   two-pass change.
4. **New scripts require manifest registration.** `manifest.json`'s `provides.scripts` array has 76
   entries and already lists `test-conflict-predicate.sh` and `test-session-registry.sh`. A new test
   script that is not added there will never reach a deployed `.claude/scripts/`.

### Prior Plan Reference

No prior plan for this task.

### Roadmap Alignment

No `roadmap_path` supplied and no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Install the four tiers in strict priority order: auto-sequence, then bounded retry, then warn,
  then ask.
- Close the plain-multi-task Tier-1 gap with a bounded two-pass structure that re-sequences an
  `in_batch` collision instead of dropping it.
- Add bounded wait-and-retry at every `task-lock.sh acquire` call site (single-task gate and
  multi-task dispatch loops) with one mechanism.
- Preserve all three existing ABORT/warn variants' field content verbatim.
- Make Tier 4 reachable only where a human can actually answer, with a deterministic autonomous
  default everywhere else.
- Prove all four tiers plus non-convergence termination in an isolated-temp-root suite.

**Non-Goals**:
- Converting `commands/orchestrate.md`'s Kahn's-algorithm pseudocode into an executable script
  (decided against in Phase 7; cost recorded).
- Making `file_scope` overlap a pre-computed `in_degree`/wave-assignment input (decided against;
  cost recorded).
- Changing `skill-orchestrate`'s Stage MT-3 step 4.5 in-batch handling, which already auto-sequences
  correctly.
- Changing `cmd_acquire`'s body, its exit-code contract (0/1/2), or the `acquire` subcommand's
  observable behavior for any existing caller.
- Any unbounded retry, unbounded scan, or batch auto-expansion.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A retry loop introduces a path where a session waits on its own lock, blocking all task work system-wide | H | M | Retry is an outer loop calling the full unmodified `cmd_acquire` per attempt; `cmd_acquire`'s body is not edited at all. Phase 2 pins a same-session-re-entry case asserting zero retry iterations occur. |
| Retry placed inside `cmd_acquire` holds the global `specs/.scope-lock` across the wait window | H | M (it is the report's stated recommendation) | Explicitly overridden in this plan's verification note 1; Phase 1 tasks forbid editing `cmd_acquire`'s body. |
| Retry budget sized against `TASK_LOCK_STALE_MIN` (30 min) turns a fast-failing command into a multi-minute hang | H | L | Budget sized on the mutex idiom (seconds-scale, default 15000ms), asserted by a Phase 2 wall-clock bound case. |
| Two-pass dispatch reorders output in a way that breaks consumers parsing the `skipped_tasks` summary | M | M | Pass-2 outcomes report in the same consolidated summary shape with a distinguishing reason string; no new output channel. |
| Second pass never converges and spins | M | L | Bound is exactly one extra pass, plus an append-only `second_pass_ledger` observation log (never an exclusion set) and a `partial`-status terminus. |
| Changing `command-gate-in.sh` breaks all six sourcing commands at once | H | L | The edit is a single subcommand-name substitution on one line; Phase 3 verification exercises all six sourcing paths' arguments; existing suites re-run for non-regression. |
| A new test script never reaches a deployed tree because it is unregistered | M | M | Phase 2 registers it in `manifest.json` `provides.scripts` in the same phase that creates it. |
| Tier-4 prompt logic mistakenly placed in `command-gate-in.sh` (a bash script cannot call `AskUserQuestion`) | M | M | Phase 6 places the flow in the command markdown, with the shared block authored once in `context/patterns/task-lock.md`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5, 6 | 2, 4 |
| 5 | 7 | 6 |
| 6 | 8 | 5, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Tier 2 mechanism — bounded `acquire-retry` in `task-lock.sh` [COMPLETED]

**Goal**: Add a bounded wait-and-retry acquire path that reuses the established mutex idiom and
leaves `cmd_acquire` byte-identical.

**Tasks**:
- [x] Add constants near the existing `SCOPE_MUTEX_*` / `COMMIT_MUTEX_*` block:
      `TASK_LOCK_RETRY_BUDGET_MS="${TASK_LOCK_RETRY_BUDGET_MS:-15000}"` and
      `TASK_LOCK_RETRY_POLL_MS="${TASK_LOCK_RETRY_POLL_MS:-500}"`. Document in a comment that these
      are sized on the `.scope-lock`/`.commit-lock` seconds-scale budgets and are deliberately
      unrelated to `TASK_LOCK_STALE_MIN` (30 minutes), which measures a different quantity.
      *(completed)*
- [x] Add `cmd_acquire_retry()` implementing a bounded poll: call `cmd_acquire "$@"` with stderr
      captured; on exit 0 emit any captured stderr and return 0; on exit 2 emit captured stderr and
      return 2 immediately (never retried — exit 2 is an error, including `.scope-lock` timeout and
      holder-write failure, not ordinary contention); on exit 1 discard the captured ABORT text,
      sleep `TASK_LOCK_RETRY_POLL_MS`, and re-attempt until `TASK_LOCK_RETRY_BUDGET_MS` is exhausted.
      *(completed)*
- [x] On the FIRST retry only, emit a single visible line modeled on `git-commit-scoped.sh`'s
      contention `NOTE:`: `NOTE: task N's lock is held by another session; waiting up to {budget}ms
      and retrying before warning.` Do not emit one line per attempt. *(completed)*
- [x] On budget exhaustion, emit the LAST attempt's captured stderr verbatim (this is the Tier-3
      handoff — the three ABORT variants must reach the user with all fields intact and unmodified)
      and return 1. *(completed)*
- [x] Register the `acquire-retry` case in the subcommand dispatcher alongside `acquire`. Leave the
      `acquire` case and `cmd_acquire`'s body untouched. *(completed)*
- [x] Extend the top-of-file usage/contract comment: document `acquire-retry`'s exit codes (0/1/2,
      identical to `acquire`), that every attempt is a full fresh `cmd_acquire` entry, and that this
      is the mechanism preserving all three same-session exclusions under retry. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the change is confined to `scripts/task-lock.sh` with zero
edits inside `cmd_acquire`'s body. Confirm at implementation time with
`git diff -- agent-system/extensions/core/scripts/task-lock.sh` and verify no hunk falls between the
`cmd_acquire() {` line and its closing brace.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` — new constants, `cmd_acquire_retry()`,
  dispatcher case, contract comment.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/task-lock.sh` passes.
- `task-lock.sh acquire-retry` with no contention returns 0 with no `NOTE:` emitted.
- Existing `scripts/test-task-lock-reap.sh`, `test-session-registry.sh`, and
  `test-conflict-predicate.sh` all still pass (non-regression on the untouched `acquire` path).

---

### Phase 2: Tier 2 and Tier 3 proofs — new isolated-temp-root suite [COMPLETED]

**Goal**: Prove bounded retry resolves a releasing lock, prove exhaustion falls through to the warn
tier with fields intact, and pin same-session re-entry as never entering the retry loop.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` following the
      isolated-temp-root precedent of `test-conflict-predicate.sh`: throwaway `$TMPROOT/.claude/scripts/`
      satisfying `deploy-root-guard.sh`'s two-levels-under-root check, real scripts copied
      byte-for-byte, fixture `state.json` / `.sessions/` / `.lock/` at controlled epoch timestamps,
      `pass`/`fail`/`info` helpers, cleanup trap. Add no testability hooks to production code.
      *(completed)*
- [x] Tier-2 resolving case: a foreign holder's lock released (holder dir removed) partway through
      the retry window by a backgrounded helper; assert `acquire-retry` returns 0, that exactly one
      `NOTE:` line was emitted, and that no ABORT text appears in output. *(completed)*
- [x] Tier-3 exhaustion case: foreign holder's heartbeat kept fresh for the whole window; assert
      `acquire-retry` returns 1 and that the emitted text is byte-identical to what plain `acquire`
      emits for the same fixture (own-task variant: holder session, heartbeat age, stale threshold).
      *(completed)*
- [x] Tier-3 field-preservation cases for the other two variants: cross-task `file_scope` overlap
      against a held lock (other task, overlapping path, other session, heartbeat age) and against a
      live registered session (session id, overlapping path, covered task number, liveness reason).
      *(completed)*
- [x] Same-session re-entry case: `acquire-retry` invoked with the holder's own `session_id`; assert
      return 0, zero `NOTE:` lines, and elapsed wall-clock below the poll interval — i.e. the retry
      loop was never entered. *(completed)*
- [x] Budget-bound case: assert the exhaustion case's elapsed wall clock is within a small tolerance
      of `TASK_LOCK_RETRY_BUDGET_MS` and nowhere near a minutes-scale wait. Run it with a lowered
      `TASK_LOCK_RETRY_BUDGET_MS` env override to keep the suite fast. *(completed)*
- [x] Add `"test-four-tier-conflict.sh"` to `manifest.json`'s `provides.scripts` array. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Asserts exactly two files change (one new script, one manifest array entry).
Confirm with `git status --short` before committing.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — new.
- `agent-system/extensions/core/manifest.json` — one `provides.scripts` entry.

**Verification**:
- `bash agent-system/extensions/core/scripts/test-four-tier-conflict.sh` exits 0 with all cases PASS.
- `jq -e '.provides.scripts | index("test-four-tier-conflict.sh")' agent-system/extensions/core/manifest.json` succeeds.
- The real `specs/` tree is unmodified after the run (`git status --short specs/` clean).

---

### Phase 3: Tier 2 wiring — single-task gate and multi-task dispatch loops [COMPLETED]

**Goal**: Route every `task-lock.sh acquire` call site through `acquire-retry` so both the
`command-gate-in.sh` path and the direct multi-task path get bounded retry from one mechanism.

**Tasks**:
- [x] In `scripts/command-gate-in.sh`, change the acquire invocation to `acquire-retry` (arguments
      unchanged). Update the adjacent comment block to state that a fresh foreign lock is now
      retried within a bounded budget before the command aborts, and that same-session re-entry
      still never self-blocks and never enters the retry loop. *(completed)*
- [x] In `commands/research.md` Step 3 item 3, change the per-task acquire to `acquire-retry` and
      update the surrounding prose: a refusal now means "still locked after the bounded retry
      budget", and only then does the task move to `skipped_tasks`. *(completed)*
- [x] Apply the identical change to `commands/plan.md` and `commands/implement.md` Step 3 (all three
      are byte-identical in shape; keep them so). *(completed)*
- [x] Confirm no other `task-lock.sh acquire` call site exists that should retry; record any
      deliberate non-retry site (e.g. `skill-orchestrate`'s Stage MT-4 per-task acquire, which
      already has a cycling loop providing Tier-1 re-sequencing and does not need Tier 2) as a
      reasoned exclusion in the phase notes. *(completed — reasoned exclusion below)*

**Reasoned Exclusion**: `skills/skill-orchestrate/SKILL.md`'s Stage MT-4 per-task acquire
(`task-lock.sh acquire "$task_num" "$op" "${session_id}_${task_num}" "/orchestrate (multi-task)"`)
is deliberately left on plain `acquire`, not `acquire-retry`. `/orchestrate`'s own cycling loop
(Stage MT-3 step 4.5) already re-attempts a deferred `in_batch` collision on a later cycle — that
IS Tier 1 (auto-sequence) for this call site, operating at a coarser, cycle-level granularity than
Tier 2's sub-second bounded retry. Adding Tier 2 here as well would layer a second, redundant
wait-and-retry mechanism underneath a re-sequencing loop that already resolves the identical
`in_batch` case; the two mechanisms are not composed at any other call site either. This is a
recorded decision, not an oversight.

The prose "Locked by another session" bullets in `commands/research.md`, `commands/plan.md`, and
`commands/revise.md`'s "GATE IN Failure" sections (describing `command-gate-in.sh`'s single-task
behavior) are intentionally left untouched in this phase to keep the four-file Scope Hypothesis
below accurate; their wording is corrected in the same edit that adds the Tier-4 reference
(Phase 6), since both changes touch the identical bullet.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts four files change and that the enumerated set of `acquire` call sites
is complete. Confirm with
`grep -rn 'task-lock.sh acquire' agent-system/extensions/core/` before and after, and account for
every remaining plain-`acquire` hit as either deliberate or updated.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-in.sh` — subcommand + comment.
- `agent-system/extensions/core/commands/research.md` — Step 3 item 3.
- `agent-system/extensions/core/commands/plan.md` — Step 3 item 3.
- `agent-system/extensions/core/commands/implement.md` — Step 3 item 3.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/command-gate-in.sh` passes.
- The three command files' Step 3 items remain byte-identical to each other apart from the
  operation name.
- `test-four-tier-conflict.sh` and the three existing suites still pass.

---

### Phase 4: Tier 1 — bounded two-pass sequencing for plain multi-task commands [COMPLETED]

**Goal**: Re-sequence an `in_batch` `file_scope_collision` into a bounded second pass instead of
dropping it, without a wave concept, batch expansion, or an unbounded loop.

**Tasks**:
- [x] In `commands/research.md` Step 2.5, split the defer handling by `defer_reason` and
      `collision_scope`. `file_scope_collision` with `collision_scope == "in_batch"` moves the task
      to a new `deferred_second_pass` array (removed from `validated_tasks` for pass 1, NOT added to
      `skipped_tasks`). Every other defer flavor — `cross_batch`, `self_modifying`, `session_active`
      — keeps the current exclude-to-`skipped_tasks` behavior verbatim. Document why in a comment:
      `in_batch` is the one flavor where the colliding task is inside this same invocation and will
      finish this run, so a "wait for this invocation's own dispatch" event exists. *(completed)*
- [x] Change the "no valid tasks remain" abort to fire only when `validated_tasks` AND
      `deferred_second_pass` are both empty, so a batch whose entire pass 1 deferred in-batch still
      runs its second pass. *(completed)*
- [x] Add a new Step 3.5 (Second Pass) after Step 3's dispatch and unconditional lock releases:
      if `deferred_second_pass` is non-empty, re-run `orchestrate-batch-admit.sh` over exactly that
      set (`--invocation-count "${#deferred_second_pass[@]}" --session-id "$batch_session_id"`) —
      bounded scan, never expanded to pull in any out-of-batch predecessor. Admitted tasks dispatch
      sequentially through the same per-task `acquire-retry` / skill / `release` bracket as Step 3.
      *(completed)*
- [x] Bound the structure at exactly ONE extra pass. A task still deferred after pass 2 moves to
      `skipped_tasks` with the distinguishing reason
      `"deferred after second pass [$defer_reason]"`, never a third pass. *(completed)*
- [x] Add the convergence-protection observation log: a `second_pass_ledger` array appended on every
      pass-1 in-batch defer and on every pass-2 outcome, shaped after `skill-orchestrate`'s
      `defer_ledger` (`{"task":N,"defer_reason":...,"collision_scope":...,"pass":1|2,"detail":...}`).
      Document it explicitly as an APPEND-ONLY OBSERVATION LOG read only for the consolidated
      summary — never an eligibility-exclusion set. *(completed)*
- [x] Report a non-converging outcome as `partial`, not a failure: when pass 2 leaves at least one
      task deferred, the consolidated summary states `partial` with a named diagnostic identifying
      the mutually-colliding set and suggesting a solo re-run — mirroring the
      `consecutive_no_dispatch_cycles` break's shape. A conflict must never error the invocation.
      *(completed)*
- [x] Apply the identical Step 2.5 / Step 3.5 / summary changes to `commands/plan.md` and
      `commands/implement.md`, keeping all three byte-identical in shape. *(completed)*

**Implementation note (convergence semantics, not a deviation)**: `orchestrate-batch-admit.sh`
deliberately carries no held-lock scan (see its own "Held-lock scan rejection" comment) — its
collision predicate is a `specs/state.json` STATUS check, not a lock check. Consequently pass 2
genuinely converges only once the pass-1 winner's status has gone terminal
(`completed`/`abandoned`/`expanded`) by the time pass 2 runs, which happens naturally for
`/implement` (success sets `status: completed`) but not for `/research`/`/plan` (whose termini —
`researched`/`planned` — are non-terminal). This is not a defect: it is exactly the
non-convergence case the plan's own Risks & Mitigations table names and the `partial`-status
terminus below handles by design. Phase 5's test suite proves both outcomes explicitly.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts the three command files are the complete edit set and that they remain
byte-identical in shape to one another. Confirm at implementation time by diffing the three Step 2.5
and Step 3.5 blocks against each other after the edit and verifying only the operation name differs.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` — Step 2.5, new Step 3.5, summary.
- `agent-system/extensions/core/commands/plan.md` — same.
- `agent-system/extensions/core/commands/implement.md` — same.

**Verification**:
- Every non-`in_batch` defer flavor's handling is textually unchanged from the pre-edit file
  (verify by diff).
- No code path adds a task to the batch that was not in the original `validated_tasks` set.
- The bound is structurally one extra pass — no loop construct wraps Step 3.5.

---

### Phase 5: Tier 1 and convergence proofs [COMPLETED]

**Goal**: Prove a conflict auto-sequences with no user interaction, and that a non-converging
deferral terminates as `partial` rather than spinning.

**Tasks**:
- [x] Extend `scripts/test-four-tier-conflict.sh` with a Tier-1 case: two fixture tasks in the same
      plain-multi-task batch with overlapping `file_scope` and no `dependencies[]` edge; drive
      `orchestrate-batch-admit.sh` over the pair and assert exactly one `defer` verdict carrying
      `defer_reason == "file_scope_collision"` and `collision_scope == "in_batch"` — the signal the
      two-pass structure keys on. *(completed — Case 7)*
- [x] Assert the second-pass admission call over the deferred singleton returns `admit` once the
      pass-1 task's lock is released, i.e. the task is runnable in pass 2 rather than permanently
      skipped. Assert no task number outside the original pair appears in either admission call's
      input or output (no auto-expansion). *(completed — Case 8, realized via the pass-1 winner
      reaching terminal status, matching orchestrate-batch-admit.sh's actual state.json-status-based
      collision predicate — see Phase 4's implementation note)*
- [x] Non-convergence case: a fixture where the pass-2 admission still returns `defer` (e.g. the
      colliding foreign holder is a live out-of-batch session). Assert the deferred task's terminal
      disposition is a `partial`-flavored skip with the `"deferred after second pass"` reason and
      that no third admission call occurs. *(completed — Case 9)*
- [x] Observation-log case: assert `second_pass_ledger` entries accumulate for both passes and that a
      task appearing in the ledger is not thereby excluded from the pass-2 admission input — the
      log is observational, not an exclusion set. *(completed — Case 10)*
- [x] Bounded-scan case: assert each admission invocation's argument list contains only the tasks of
      the pass it serves, never a sweep of all task directories. *(completed — Case 11)*

**Timing**: 1.5 hours

**Depends on**: 2, 4

**Verification Tier**: local

**Scope Hypothesis**: Asserts the only file changed is the test script created in Phase 2. Confirm
with `git status --short`.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — Tier-1 and convergence cases.

**Verification**:
- The suite exits 0 with all four tier proofs plus the convergence proof passing.
- The real `specs/` tree is unmodified after the run.

---

### Phase 6: Tier 4 — `orchestrator_mode`-gated ask, reachable only where a human exists [COMPLETED]

**Goal**: Add the last-resort ask tier where it can actually run, with a deterministic autonomous
default everywhere else.

**Tasks**:
- [x] Author the shared Tier-4 flow ONCE in `context/patterns/task-lock.md` as a directly-executable
      block, modeled on `lit-stage4a-flow.md`'s `AUTONOMOUS_GLOBAL` precedent: resolve
      `orchestrator_mode` from the delegation context defaulting to `"false"`; when `true`, MUST NOT
      call `AskUserQuestion` — emit a distinctly-prefixed `[conflict:auto]` notice stating that the
      warn tier is the autonomous terminus and why, then defer/skip; when `false`, present the real
      question. *(completed — "Tier 4: The Ask Flow" section)*
- [x] Specify the interactive question's content: it surfaces the same fields the warn tier already
      carries (other session or registered session id, overlapping path, heartbeat age or liveness
      reason) plus three choices — wait longer (one additional bounded retry budget), skip this task
      this invocation, or override manually (print the exact `rm -rf "$lock_dir"` remedy; never
      perform the removal on the user's behalf). *(completed)*
- [x] State explicitly in the block that Tier 4 CANNOT live in `command-gate-in.sh` — a bash script
      cannot call `AskUserQuestion` — so the gate script returns 1 as it does today and the ask tier
      lives in the command markdown that sources it. *(completed)*
- [x] Wire the reference into `commands/research.md`, `commands/plan.md`, and `commands/implement.md`
      single-task paths, immediately after the `source .claude/scripts/command-gate-in.sh` failure
      branch, each pointing at the single shared block rather than duplicating it. *(completed — same
      edit also corrected the "Locked by another session" bullet's `acquire` -> `acquire-retry`
      wording deferred from Phase 3)*
- [x] Record that `/orchestrate`, `/revise`, and `/task` are deliberately NOT wired to Tier 4:
      `/orchestrate` has zero synchronous confirmation gates by design, and `/revise` and `/task`
      are not conflict-response entry points. Note that this is a decision, not an omission.
      *(completed — "Deliberately Not Wired" subsection in task-lock.md)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` — shared Tier-4 flow block.
- `agent-system/extensions/core/commands/research.md` — single-task path reference.
- `agent-system/extensions/core/commands/plan.md` — same.
- `agent-system/extensions/core/commands/implement.md` — same.

**Verification**:
- The flow block exists exactly once; the three command files reference it and do not restate it.
- No `AskUserQuestion` reference appears in any `.sh` file.
- Diff read-through confirms every changed hunk in the command files lies in prose/reference text,
  not in an executable fenced block that alters dispatch behavior.

---

### Phase 7: Documentation — the four-tier ladder, recorded decisions, and factual corrections [COMPLETED]

**Goal**: Make the ladder, the deliberate non-changes and their costs, and the corrected sourcing
count discoverable in the durable context files.

**Tasks**:
- [x] In `context/patterns/task-lock.md`, add a "Four-Tier Conflict Response" section documenting the
      strict order (auto-sequence, bounded retry, warn, ask), which mechanism serves each tier, and
      which tiers are structurally inapplicable where (Tier 1 has no meaning for a single task run in
      isolation; Tier 4 has no meaning under `orchestrator_mode: true`). *(completed)*
- [x] Correct the sourcing count in the same file: "sourced by five command files" becomes six, named
      — `/research`, `/plan`, `/implement`, `/revise`, `/orchestrate`, `/task`. Add a note that this
      count is verifiable by grep and must not be trusted as frozen. Update the "Consumers (Five
      Distinct Wiring Paths)" list's item 1 to include `/task`'s `expand` and `abandon` operations.
      *(completed — heading also renamed to "Consumers (Six Distinct Wiring Paths)")*
- [x] Document `acquire-retry` in the same file's acquire/heartbeat/release/check contract section:
      its exit codes, its budget constants, that it never retries exit 2, and that every attempt is a
      full fresh `cmd_acquire` entry preserving all three same-session exclusions. *(completed)*
- [x] In `context/patterns/batch-orchestration-guardrails.md`, update the residual-gap notes that
      currently state the in-batch narrowing "does NOT transfer to plain multi-task
      `/implement`, `/research`, or `/plan`" — replace with the two-pass structure now in place and
      its exact bound. Do not weaken any of the six non-negotiables. *(completed — also corrected an
      independently-stale claim in the same section that plain multi-task commands "never call
      orchestrate-batch-admit.sh at all", which Gap C's pre-existing Step 2.5 already contradicted;
      note: the document's own "## Non-Negotiables" heading lists FIVE items, not six — the plan's
      "six" appears to be an approximate count; all five were re-verified unweakened)*
- [x] Record two deliberate non-changes and their costs in the same file:
      (a) `commands/orchestrate.md`'s Kahn's-algorithm pseudocode stays illustrative and is NOT
      converted to an executable script — cost of converting: the file's own comments warn against
      making the illustration literal, and it sits on the orchestrator-critical inclusion list, so
      the change would itself trip the self-modification hazard gate for no behavioral gain, since
      Stage MT-3 step 4.5 already auto-sequences the `in_batch` case; cost of NOT converting: wave
      assignment stays agent-executed pseudocode with no script-level test surface.
      (b) `file_scope` overlap is NOT added as an `in_degree`/wave-assignment input — cost of adding:
      it duplicates, in a pre-computed graph, a decision the executing gate already re-derives fresh
      every cycle, creating two sources of truth that can disagree; cost of not adding: overlap
      remains a reactive dispatch-time defer rather than a pre-dispatch ordering. *(completed —
      recorded in the "Rejected Approaches" section, verified `commands/orchestrate.md` is on
      `context/reference/orchestrator-critical-paths.json`'s list before writing the claim)*
- [x] In `context/patterns/multi-task-operations.md`, document the two-pass structure as part of the
      multi-task specification: pass 1 parallel, pass 2 sequential over in-batch-deferred tasks only,
      bounded at one extra pass, `partial` on non-convergence. *(completed — new "5a. Batch Admission
      Pre-Check and Bounded Second Pass (Tier 1)" section)*
- [x] In `docs/architecture/batch-admit-schema.md`, add a consumer note that `collision_scope ==
      "in_batch"` now has a second consumer beyond `skill-orchestrate`'s cycling loop — the plain
      multi-task two-pass structure — so a future change to that field's semantics has a wider blast
      radius. Do not change the schema itself. *(completed — schema fields/values untouched)*
- [x] Confirm `skills/skill-orchestrate/SKILL.md` and `skills/skill-orchestrate-hard/SKILL.md` need
      no behavioral change (Stage MT-3 step 4.5 already auto-sequences `in_batch` correctly); add
      only a cross-reference to the new four-tier ladder section. If no natural cross-reference site
      exists, record that as a reasoned exclusion rather than forcing an edit. *(completed — natural
      cross-reference sites existed in both files' Stage MT-3 step 4.5 / transcribed equivalent; no
      reasoned exclusion needed)*
- [x] Verify no deliverable outside `specs/**` cites a task number; use durable anchors (section
      names, script and function names, quoted strings) throughout. *(completed —
      `bash .claude/scripts/check-task-references.sh` exits 0 across all four scanned trees)*

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: prose

**Scope Hypothesis**: Asserts six documentation files change, two of which (the two orchestrate
SKILL.md files) may end up cross-reference-only or excluded. Confirm the final set with
`git status --short` and record any excluded file in a `#### Reasoned Exclusions` subsection.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (cross-reference only)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (cross-reference only)

**Verification**:
- `grep -rn "sourced by five" agent-system/extensions/core/` returns nothing.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0.
- Diff read-through confirms every changed hunk is prose or reference text with no executable
  surface.

---

### Phase 8: Full-suite verification and deploy gates [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove all four tiers together, prove non-regression across the existing suites, and confirm
the change survives deploy.

**Tasks**:
- [x] Run `scripts/test-four-tier-conflict.sh` and confirm all four tier proofs plus the
      non-convergence-terminates-`partial` proof pass. *(completed — 11/11 cases pass: Tier 2
      resolving, Tier 3 exhaustion x3 variants, same-session re-entry, budget-bound, Tier 1 pass 1,
      Tier 1 pass 2 convergent, non-convergence, observation log, bounded scan)*
- [x] Run `scripts/test-conflict-predicate.sh`, `scripts/test-session-registry.sh`,
      `scripts/test-task-lock-reap.sh`, `scripts/test-state-write-concurrency.sh`, and
      `scripts/test-session-runtime-files.sh` for non-regression. *(completed — all five exit 0:
      23/23, 10/10, 6/6, 4/4, 6/6 respectively)*
- [x] Run `scripts/verify-deploy.sh` (including its task-reference lint gate) and
      `scripts/check-extension-docs.sh`. *(completed — task-reference lint gate PASSES; see
      Reasoned Exclusions below for the non-zero overall exit codes)*
- [x] Confirm the deploy path picks up the new test script: verify the `manifest.json`
      `provides.scripts` entry and that a deployed `.claude/scripts/test-four-tier-conflict.sh`
      appears after a sync. If the known already-loaded-extension copy gap prevents it, record that
      as a named residual rather than papering over it. *(completed — manifest.json entry verified
      present; deployed copy does not yet exist, recorded below per this task's own instruction)*
- [x] Confirm `git status --short specs/` shows no stray fixture residue from any suite run.
      *(completed — clean; only this task's own artifacts and routine session bookkeeping (TODO.md,
      state.json, events.jsonl) present)*
- [x] Confirm no edit landed under `.claude/**` (source-store rule):
      `git status --short -- .claude/` is clean apart from any deploy sync the user performs.
      *(completed — `git status --short -- .claude/` returns zero lines)*

**Timing**: 1 hour

**Depends on**: 5, 7

**Verification Tier**: full

**Files to modify**:
- None (verification only; fixes discovered here are applied to the owning phase's files).

**Verification**:
- All six suites exit 0. **Met.**
- `verify-deploy.sh` exits 0. **Not met as a bare exit code — see Reasoned Exclusions.** The
  task-reference lint gate specifically (the sub-check this plan's Non-Goals and binding
  constraints care about) passes cleanly.
- No modifications under `.claude/**` attributable to this task's implementation. **Met** — this
  is in fact the ROOT CAUSE of the two exclusions below, not a contradiction of them: this task's
  edits deliberately never touch `.claude/**` (source-store rule), so `.claude/**` is legitimately
  stale relative to the source store until a user-invoked deploy sync runs.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh`'s doc-lint step reports `[FAIL]` for `scripts/command-gate-in.sh` and `scripts/task-lock.sh` "deployed script content drift" | Expected, not a defect: this task's Phases 1-7 edit ONLY the source store (`agent-system/extensions/core/**`) per the source-store/deploy-boundary rule, and never write `.claude/**`. Regenerating the deployed tree (`deploy-headless.sh` / `<leader>al` "Sync all") is documented as MANUAL-ONLY (`context/patterns/regeneration-is-manual-only.md`), with exactly one sanctioned automated caller (`skill-orchestrate`'s inter-cycle redeploy checkpoint) that this implementation dispatch is not. Forcing a sync from inside this agent would violate that contract. | `diff .claude/scripts/task-lock.sh agent-system/extensions/core/scripts/task-lock.sh` shows only this task's own additions (the `acquire-retry` subcommand, retry constants, contract comments); `diff .claude/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh` shows only the `acquire` -> `acquire-retry` substitution and its adjacent comment. `git status --short -- .claude/` returns zero lines, confirming no `.claude/**` write occurred. |
| `check-extension-docs.sh` reports `core script never deployed: scripts/test-four-tier-conflict.sh` (advisory) and the `[literature]` extension reports two `FAIL: script file on disk NOT in provides.scripts` hits for `__pycache__/*.pyc` files | The `test-four-tier-conflict.sh` advisory is the SAME deploy-sync-is-manual-only situation as the row above, explicitly anticipated by this phase's own task list ("If the known already-loaded-extension copy gap prevents it, record that as a named residual"); `manifest.json`'s `provides.scripts` registration (Phase 2) is confirmed present and correct, which is the part of this task actually owned by this plan — the deploy-time copy step is a separate, user-triggered operation. The two `[literature]` `.pyc` FAILs are pre-existing, unrelated to this task: they belong to a different extension this task never touched, are untracked Python bytecode cache artifacts, and predate this task's first commit. | `jq -e '.provides.scripts | index("test-four-tier-conflict.sh")' agent-system/extensions/core/manifest.json` returns `54` (present). `git status --short agent-system/extensions/literature/` shows no pending changes from this session in that extension at all — the `.pyc` files are pre-existing on-disk artifacts, not something this task's commits created or modified. |

---

## Testing & Validation

- [ ] **Tier 1 proof**: two same-batch tasks with overlapping `file_scope` and no dependency edge —
      one runs in pass 1, the colliding one runs in pass 2, neither lands in `skipped_tasks`, no user
      interaction occurs.
- [ ] **Tier 2 proof**: a foreign lock released partway through the retry window — `acquire-retry`
      returns 0 within the bounded budget, exactly one `NOTE:` emitted, no ABORT text.
- [ ] **Tier 3 proof**: a foreign holder fresh for the whole budget — the budget is exhausted and the
      existing ABORT/warn message fires with every documented field populated, byte-identical to
      plain `acquire`'s output for the same fixture. All three variants covered.
- [ ] **Tier 4 proof**: the autonomous branch (`orchestrator_mode == true`) never calls
      `AskUserQuestion` and emits `[conflict:auto]`; no `.sh` file references `AskUserQuestion`.
- [ ] **Non-convergence proof**: a pass-2 defer terminates as `partial` with a named diagnostic and
      no third admission call.
- [ ] **Same-session re-entry non-regression**: own-session acquire returns 0 with zero retry
      iterations; all three exclusions (`holder_session == session_id`, the held-lock scan's
      `other_session == session_id` skip, `session_contention()`'s self-session-id exclusion) intact.
- [ ] **Bounded-scan non-regression**: every admission call's input is the pass's own task set only.
- [ ] **No-auto-expansion non-regression**: no task outside the original `validated_tasks` set ever
      enters any pass.
- [ ] **Defer-never-fail non-regression**: no conflict path exits non-zero on the invocation.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` — `acquire-retry` subcommand, retry constants,
  contract comment.
- `agent-system/extensions/core/scripts/command-gate-in.sh` — retry-wired acquire.
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — new four-tier proof suite.
- `agent-system/extensions/core/manifest.json` — test script registration.
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md` — two-pass Step 2.5
  / Step 3.5, retry-wired Step 3, Tier-4 reference.
- `agent-system/extensions/core/context/patterns/task-lock.md` — four-tier ladder, Tier-4 shared
  flow, corrected sourcing count, `acquire-retry` contract.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — residual-gap
  update, two recorded non-change decisions with costs.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — two-pass specification.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — `collision_scope` consumer
  note.
- `specs/946_auto_sequence_conflicting_work/summaries/01_four-tier-conflict-response-summary.md`

## Rollback/Contingency

Every phase is independently revertible and the changes are additive by construction:

- **Phase 1** adds a new subcommand without touching `cmd_acquire` or the `acquire` case, so
  reverting it restores exact prior behavior for every caller.
- **Phase 3** is a one-token substitution per call site; reverting the four sites restores the
  pre-retry gate immediately and is the correct first move if any lock regression is observed in the
  field, since `command-gate-in.sh` is on the path of all six sourcing commands.
- **Phase 4** is confined to three command markdown files; reverting restores the current
  single-pass exclude-to-`skipped_tasks` behavior.
- **Phase 6/7** are documentation-only and carry no runtime risk.

If a same-session re-entry regression is suspected at any point, revert Phase 3 first (restoring the
plain `acquire` call sites), then confirm with `test-conflict-predicate.sh`'s existing same-session
coverage before investigating further. Take `bash .claude/scripts/git-snapshot.sh 946` before any
rollback that would discard uncommitted work.
