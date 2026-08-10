# Implementation Plan: Task #1008

- **Task**: 1008 - fix_orchestrate_mt_session_id_mismatch
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/1008_fix_orchestrate_mt_session_id_mismatch/reports/01_mt-session-id-self-contention.md
- **Artifacts**: plans/01_unify-mt-session-id.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill-orchestrate/SKILL.md` registers its multi-task batch in the session registry under the
bare `$session_id` (Stage MT-1) but acquires and releases each task's lock under the
task-suffixed `${session_id}_${task_num}` (Stage MT-4). Because `session_contention()`'s
self-exclusion is an exact string match on `session_id`, the batch's own registry entry — whose
`file_scope` is the union of every batch member's scope — is never excluded, so every lock
acquire in every multi-task `/orchestrate` invocation is refused against the batch's own
registration. This plan unifies the lock-touching session-id construction sites onto the bare
`$session_id`, states the parity invariant in prose at the point of use and in the canonical
lock spec, and pins the behavior with a new regression group in the existing
`test-conflict-predicate.sh` suite. Done means: the three lock-touching sites use the bare id,
the new test group passes, and no unexempted regression remains in the source store.

### Research Integration

Root cause, exact line-level sites, and the failure mechanism are taken directly from the
research report. Its four operative conclusions are carried into this plan:

- The required fix is the Stage MT-4 `acquire` and `release` call sites (the two sites the task
  description labels MT-1/MT-4 divergence); Stage MT-3's `orchestrate-batch-admit.sh
  --session-id` call is already correct and must not change.
- The `implement_agents[task_num]` dispatch context's `session_id` field must move to the bare id
  in the same change, because `general-implementation-agent.md`'s per-phase
  `task-lock.sh heartbeat` call consumes that field verbatim; fixing only `acquire`/`release`
  would convert a loud, always-reproducible ABORT into a silent heartbeat-staleness race.
- `research_agents` / `planner-agent` dispatch contexts, `skill_preflight_update` /
  `skill_postflight_update`, `git-commit-scoped.sh --session`, and `system-defect-record.sh
  --session` are explicitly OUT of scope — none of them read or write `.lock/holder.json`, and
  per-task uniqueness there is useful provenance.
- The regression test belongs in `test-conflict-predicate.sh`, driving the real `task-lock.sh`
  CLI (`session-register` then `acquire`) rather than the full skill, so it is runnable without
  the broken multi-task path.

Additional structural facts confirmed while planning, which the phases below rely on:

- The suite's fixture `state.json` already defines `820` (`file_scope: ["g4/clean"]`,
  `dependencies: []`) and `850` (`file_scope: ["g23/x"]`, `dependencies: []`), which are not
  dependency-edge-connected to each other — exactly the "unrelated batch members" shape the bug
  needs. `851` depends on `850`, not on `820`, so the edge exclusion does not fire for the pair.
- `cmd_session_register` computes the union `file_scope` internally via `get_file_scope`, so the
  test must NOT hand-write a registry fixture — calling the real CLI is what reproduces MT-1.
- `resolve_session_pid()` walks ancestors for a `claude` comm and falls back to self/ppid, and
  the dead-pid shortcut is floored by `SESSION_REGISTRY_DEAD_PID_MIN` (default 10 min). A
  freshly-registered entry has `heartbeat_at` of now, so it counts as contending regardless of
  how the pid resolves — the negative case is not pid-flaky. Group 4.2b already relies on this
  same property.
- The suite is runnable directly from the source store: `agent-system/extensions/core/scripts/`
  contains `task-lock.sh`, `orchestrate-batch-admit.sh`, `deploy-root-guard.sh`, and `lib/`, all
  of which the harness copies byte-for-byte into an isolated temp root.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Make every `skill-orchestrate/SKILL.md` site that acquires, releases, or later references the
  per-task lock use one and the same session-id value (the bare `$session_id`).
- State the session-register/acquire parity invariant in prose where a future editor will see it:
  at the MT-4 call sites and in the canonical lock spec.
- Add a regression group that fails loudly if the task-suffixed pattern is reintroduced at a
  lock-touching site.

**Non-Goals**:
- Fixing the structurally identical pattern in `commands/research.md`, `commands/plan.md`, and
  `commands/implement.md` — out of the stated TARGET; record as a follow-up recommendation only.
- Changing provenance/attribution session-id sites (`skill_preflight_update`,
  `skill_postflight_update`, `git-commit-scoped.sh --session`, `system-defect-record.sh
  --session`) or the `research_agents` / `planner-agent` dispatch contexts.
- Any change to `task-lock.sh`, `lib/file-scope-overlap.sh`, or `orchestrate-batch-admit.sh`
  logic — the lock implementation is correct; only its callers are wrong.
- Editing anything under `.claude/**` (deploy artifact) or driving verification through a
  multi-task `/orchestrate` invocation (the mechanism under repair).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Narrow fix to `acquire`/`release` only, leaving the implement dispatch context suffixed, silently breaks the per-phase heartbeat and lets a long implement run's lock go stale | H | M | Phase 1 changes all three lock-touching sites as one objective; Phase 2's heartbeat case asserts parity explicitly |
| An over-broad edit sweeps provenance-only `${session_id}_${task_num}` sites into the change, losing per-task log/commit readability | M | M | Phase 1 carries a Scope Hypothesis naming the exact three lines and requires a post-edit grep confirming the remaining suffixed sites are precisely the enumerated out-of-scope set |
| Implementer edits the deployed `.claude/skills/skill-orchestrate/SKILL.md` instead of the source store, and the change is wiped on next regeneration | H | L | Binding source-store rule restated in every phase; Phase 4 greps `.claude/**` for accidental modification |
| New test group is written against a hand-built registry fixture, not the real `session-register` CLI, and therefore does not reproduce the union-`file_scope` mechanism | M | M | Phase 2 mandates the real CLI for registration and asserts on the stderr text `cmd_acquire` emits for the session-registry path specifically |
| Test-comment prose introduces a task-number citation into a deliverable file outside `specs/**` | M | M | Phase 2 requires fixture-number phrasing ("fixture 820"), never "task 820"; Phase 4 runs `check-task-references.sh` |
| The same defect remains live in the three multi-task command files, so multi-task `/research`/`/plan`/`/implement` stay broken after this lands | H | H | Phase 4 records the follow-up recommendation with the exact call sites in the implementation summary; explicitly not fixed here |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Unify the lock-touching session-id sites in Stage MT-4 [COMPLETED]

**Goal**: Every site in `skill-orchestrate/SKILL.md` that acquires, releases, or is later
consumed by a heartbeat against the per-task lock presents the same bare `$session_id` that
Stage MT-1 registered and Stage MT-3 already passes.

**Tasks**:
- [x] Open `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (source store —
      never the `.claude/` copy). *(completed)*
- [x] In Stage MT-4's "Task-lock acquire (per-task, before dispatch)" block, change the
      `task-lock.sh acquire` argument from `"${session_id}_${task_num}"` to `"$session_id"`.
      *(completed)*
- [x] In Stage MT-4's step 6 "Task-lock release (per-task, unconditional)" block, change the
      `task-lock.sh release` argument from `"${session_id}_${task_num}"` to `"$session_id"`.
      *(completed)*
- [x] In the `implement_agents[task_num]` Agent-tool dispatch context, change the `session_id`
      field from `"${session_id}_${task_num}"` to `"$session_id"`. *(completed)*
- [x] Add prose at the acquire block stating the invariant explicitly: the bare `$session_id` is
      used here deliberately, it must equal the value Stage MT-1 passed to `session-register` and
      Stage MT-3 passes to `orchestrate-batch-admit.sh --session-id`, because
      `session_contention()`'s self-exclusion is an exact string match — a suffixed value makes
      the batch contend against its own registration. Mirror the explanatory style already used
      at the Stage MT-3 call site. *(completed)*
- [x] Add a one-line note at the release block and at the implement dispatch context pointing
      back to that invariant (the release must match the acquire; the dispatch `session_id` is
      what `general-implementation-agent`'s per-phase `task-lock.sh heartbeat` presents against
      `holder.json`). *(completed)*
- [x] Confirm Stage MT-1's `session-register` line and Stage MT-3's
      `orchestrate-batch-admit.sh --session-id` line are unchanged. *(completed: verified via
      grep, both still bare `$session_id` at lines 1418 and 1628)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly three code lines change in this phase — the `task-lock.sh acquire`
line, the `task-lock.sh release` line, and the `implement_agents[task_num]` dispatch-context
line — plus surrounding prose. Confirm at implementation time by re-running
`grep -n '\${session_id}_\${task_num}' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
and checking that every remaining hit is one of the enumerated out-of-scope sites:
`skill_preflight_update` (research/plan/implement), the `research_agents` and `planner-agent`
dispatch contexts, `system-defect-record.sh --session` (two sites), the MT append-idiom prose
note, `skill_postflight_update` (three sites), and `git-commit-scoped.sh --session`. If the
count or membership differs from this hypothesis, stop and reconcile against the research report
before proceeding — do not widen the edit to make the grep clean.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - three session-id arguments
  switched to the bare value; invariant prose added at the acquire, release, and implement
  dispatch sites.

**Verification**:
- `grep -n 'task-lock.sh acquire\|task-lock.sh release' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  shows `"$session_id"` (bare) at both sites.
- The `implement_agents[task_num]` dispatch line shows `session_id: "$session_id"`.
- The Scope Hypothesis grep returns only the enumerated out-of-scope sites.
- `git diff --stat` touches exactly one file, under `agent-system/extensions/**`.

---

### Phase 2: Add the register/acquire parity regression group [NOT STARTED]

**Goal**: A runnable regression group that reproduces the MT-1 -> MT-4 sequence against the real
`task-lock.sh` CLI, passes under the bare id, fails-as-designed under the suffixed id, and
statically guards `SKILL.md` against reintroduction of the suffixed pattern at a lock-touching
site.

**Tasks**:
- [ ] Append a new group (next sequential number after the existing Group 8) to
      `agent-system/extensions/core/scripts/test-conflict-predicate.sh`, placed after the Group 8
      block and before the `# Summary` block, using the suite's existing
      `pass`/`fail`/`info`/`reset_sessions` helpers and `"$TL"` handle.
- [ ] Registration case: call `reset_sessions`, then the real CLI
      `"$TL" session-register "sess_mt_batch" "/orchestrate (multi-task)" "820,850"`, mirroring
      Stage MT-1. Assert the registry entry exists and its `file_scope` is the union of the two
      fixture scopes (`g4/clean`, `g23/x`) — this proves the union is computed by the CLI, not by
      the fixture.
- [ ] Positive case (post-fix behavior): `"$TL" acquire 820 research "sess_mt_batch" "/orchestrate (multi-task)"`
      — same bare id as registered — assert exit 0. Release with the same bare id, then repeat
      for `850` and assert exit 0, confirming both batch members admit.
- [ ] Negative case (regression reproduction): `"$TL" acquire 820 research "sess_mt_batch_820" "/orchestrate (multi-task)"`
      — the task-suffixed id — assert exit 1 AND assert stderr contains `registered session`, so
      the assertion pins the session-registry contention path specifically rather than any other
      refusal reason.
- [ ] Heartbeat parity case: after a bare-id acquire on `820`, run
      `"$TL" heartbeat 820 "sess_mt_batch"` and assert its output does NOT contain a
      different-session WARN — guarding the implement-dispatch half of Phase 1.
- [ ] Static guard case: locate `$SCRIPT_DIR/../skills/skill-orchestrate/SKILL.md` (this relative
      path resolves in both the source-store and the deployed tree). If present, assert that no
      line matching `task-lock.sh (acquire|release|heartbeat)` in that file contains
      `${session_id}_${task_num}`. If absent, emit `info` and skip — mirror Group 8's stance on
      `SCRIPT_DIR` ambiguity rather than failing.
- [ ] Call `reset_sessions` and release any held lock at the end of the group so suite state does
      not leak into the summary.
- [ ] Write every comment and message using fixture phrasing (`fixture 820`, `the 820/850
      fixture pair`) — never "task 820". This file is a deliverable outside `specs/**`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the new group adds five cases (registration, positive,
negative, heartbeat parity, static guard) to exactly one file and requires no manifest change,
on the basis that `test-conflict-predicate.sh` is already listed under `core/manifest.json`'s
`provides.scripts`. Confirm at implementation time by
`jq '.provides.scripts' agent-system/extensions/core/manifest.json | grep test-conflict-predicate`
before concluding no manifest edit is owed; if it is absent, add it rather than assuming.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - new regression group.

**Verification**:
- `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` exits 0 and its summary
  line shows the new cases among the passes with zero failures.
- Temporarily reverting Phase 1's `acquire` line in a scratch copy makes the static guard case
  fail (confirm the guard actually bites, then discard the scratch change — do not commit it).
- `git diff --stat` touches exactly one file, under `agent-system/extensions/**`.

---

### Phase 3: State the parity invariant in the canonical lock spec [NOT STARTED]

**Goal**: A future author wiring a NEW multi-task lock consumer reads the invariant in the
canonical spec, not only in a test assertion or a single skill's inline prose.

**Tasks**:
- [ ] Open `agent-system/extensions/core/context/patterns/task-lock.md` (source store).
- [ ] In the "Consumers (Six Distinct Wiring Paths)" section, at the multi-task/wave-dispatch
      item, add one to two sentences stating the invariant directly: the `session_id` argument
      passed to `acquire`/`release`/`heartbeat` for a task MUST be byte-identical to the
      `session_id` the same batch passed to `session-register`, because D4 exclusion 1 is an
      exact string match; a per-task-suffixed variant makes the batch's own union-scope
      registration read as a foreign live session and refuses every member.
- [ ] Cross-reference the item that already documents the bare-id `session-register` requirement,
      so the two statements are reachable from each other.
- [ ] Verify the addition sits alongside, and does not contradict, the existing "Session-Registry
      Reader Contract" and "Same-Session Re-Entry" sections.
- [ ] Do not cite a task number; reference the invariant and the section names as the durable
      anchors.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - invariant sentence(s) plus
  cross-reference in the Consumers section.

**Verification**:
- Diff read-through confirms every changed hunk is prose inside the Consumers section; no code
  block or CLI contract line is altered.
- The added text names `session-register`, `acquire`, and the exact-string-match property.
- No task-number citation appears in the diff.

---

### Phase 4: Full verification, deploy-boundary check, and follow-up record [NOT STARTED]

**Goal**: The change set passes the repository's gates, no `.claude/**` file was hand-edited, and
the out-of-scope sibling defect is recorded where a human will act on it.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` and confirm a
      zero-failure summary.
- [ ] Run `bash agent-system/extensions/core/scripts/test-session-registry.sh` and confirm it
      still passes (no regression in the neighbouring registry suite).
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm zero unexempted findings
      across the deliverable trees.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it still exits zero.
- [ ] Confirm `git status --short` shows changes only under
      `agent-system/extensions/**` and `specs/**`, and specifically no modification under
      `.claude/**`.
- [ ] Re-run the Phase 1 Scope Hypothesis grep one final time and record the surviving
      out-of-scope site list in the implementation summary as the confirmed scope evidence.
- [ ] Record in the implementation summary the follow-up recommendation, with call sites, for the
      structurally identical `session-register` (bare) vs. `acquire-retry` (suffixed) pattern in
      `commands/research.md`, `commands/plan.md`, and `commands/implement.md`, noting the same
      fix shape and the same regression-test pattern apply. Do not fix those files here and do
      not create the follow-up task from inside this task — surface the recommendation for the
      orchestrator or user to act on.
- [ ] Note in the summary that verification deliberately avoided a multi-task `/orchestrate`
      invocation, per the task constraint, and that the lock-level CLI test is the substitute.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `specs/1008_fix_orchestrate_mt_session_id_mismatch/summaries/01_*-summary.md` - created at
  implementation wrap-up (task-management artifact, not a deliverable).

**Verification**:
- All four gate commands above exit zero.
- `git status --short` contains no `.claude/**` path.
- The summary contains the confirmed out-of-scope site list and the follow-up recommendation.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` exits 0, including
      the new register/acquire parity group.
- [ ] The negative case in that group asserts both exit 1 and the `registered session` stderr
      text, so it pins the session-registry contention path rather than an incidental refusal.
- [ ] The static guard case fails when the suffixed pattern is reintroduced at a lock-touching
      `SKILL.md` line (verified once against a scratch revert, then discarded).
- [ ] `bash agent-system/extensions/core/scripts/test-session-registry.sh` exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [ ] No file under `.claude/**` is modified by this change.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified: three session-id
  arguments unified to the bare value, plus invariant prose).
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (modified: new register/
  acquire parity regression group).
- `agent-system/extensions/core/context/patterns/task-lock.md` (modified: parity invariant stated
  in the Consumers section).
- `specs/1008_fix_orchestrate_mt_session_id_mismatch/summaries/01_*-summary.md` (new).

## Rollback/Contingency

All changes are confined to three text files in the source store, with no schema, state, or
generated-artifact side effects. To revert: `git revert` the phase commits, or restore the three
files from HEAD. The deployed `.claude/` tree is regenerated from the source store, so no
separate deploy rollback is required. If the new test group proves flaky in a way that cannot be
resolved (for example an environment where `resolve_session_pid` and the dead-pid floor interact
unexpectedly), keep the Phase 1 fix and downgrade the affected case to an `info` with a recorded
reason rather than reverting the fix — the fix is the critical-path item; the test is the guard.
