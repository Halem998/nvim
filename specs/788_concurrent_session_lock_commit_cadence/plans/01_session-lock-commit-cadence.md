# Implementation Plan: Task #788

- **Task**: 788 - Concurrent-session protection: task lock + mandatory commit-per-green-substep
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: Task #786 (COMPLETE), Task #787 (COMPLETE)
- **Research Inputs**: specs/788_concurrent_session_lock_commit_cadence/reports/01_concurrent-session-lock-design.md
- **Artifacts**: plans/01_session-lock-commit-cadence.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Prevent concurrent Claude Code sessions from silently clobbering a shared working tree (the 427
failure: an uncommitted in-progress task wiped by a second session). The user-selected scope is
**task lock + commit-per-green-substep only** — git-worktree isolation is explicitly deferred and
out of scope. The plan introduces a per-task lockfile (`specs/{NNN}_{SLUG}/.lock`) acquired via a
genuinely atomic `mkdir` primitive, wires acquire/release/heartbeat into both the single-task gate
scripts and the multi-task/wave dispatch paths that bypass them, and reconciles the mandatory
commit-per-green-substep cadence against `git-workflow.md`'s existing (contradictory) "Do Not
Commit: intermediate states" prohibition. Definition of done: two sessions cannot both hold a
fresh lock on the same task, a stale lock is overridable with a visible warning (never silently or
permanently), in-progress work is committed at every verified-green objective, and every touched
file's `.claude/` and `.claude/extensions/core/` copies remain byte-identical.

### Research Integration

The plan operationalizes report `01_concurrent-session-lock-design.md` directly:
- **Lockfile over state.json field** (Findings 2-3): matches the existing `.orchestrator-loop-guard`
  / `.postflight-pending` marker-file precedents; avoids adding write contention to the shared
  state.json whose last-write-wins semantics motivated the task.
- **Atomic acquire via `mkdir`** (Finding 4): the codebase's `jq -n > file` pattern is NOT
  atomic-on-creation; `mkdir` gives POSIX-atomic exclusive create with no new tool dependency.
- **Heartbeat at existing checkpoints, not a timer** (Finding 5): no background timer is available;
  refresh piggybacks on the orchestrate Stage 3 cycle loop and implementer phase transitions.
  Stale threshold 30-60 min (distinct from `git-snapshot.sh`'s 120s marker), override-and-warn.
- **Two distinct wiring paths** (Findings 6-7): single-task flows funnel through
  `command-gate-in.sh`/`command-gate-out.sh`; multi-task/wave dispatch explicitly bypasses those
  scripts (`STOP. Do not continue to CHECKPOINT 1`) and needs separate hooks inside
  `skill-orchestrate`'s Stage MT dispatch and `implement.md`'s Step 3 loop.
- **Commit-per-green-substep reconciliation** (Recommendations 5-7): the mandate contradicts
  `git-workflow.md`'s "Do Not Commit: intermediate states during multi-phase operations" line,
  which must be *replaced* (not supplemented). Sub-step granularity = `progress-file.md`'s
  per-objective `objectives[]` (`status: "done"`); commit staging reuses
  `checkpoint-before-overflow.md`'s green-commit branch and the `implement` scope from
  `git-staging-scope.md` verbatim. Compose cleanly with the 785/786 hardening — edit only the
  specific bullet, never weaken the surrounding "never `git add -A`" guarantees.
- **Dual-copy discipline** (Finding 8): every touched core file is confirmed byte-identical between
  `.claude/...` and `.claude/extensions/core/...`; edit both copies in lockstep and verify with
  `diff -q`.

### Prior Plan Reference

No prior plan. This is the first plan for task 788.

### Roadmap Alignment

No `roadmap_path` was provided and `roadmap_flag` is not set; ROADMAP.md consultation skipped. This
task is part of the 779/780/781/785/786/787 git-safety + concurrency cluster (all COMPLETE) and
composes with, rather than modifies, their deliverables.

## Goals & Non-Goals

**Goals**:
- A session must reserve a task before working it: a per-task lockfile
  (`specs/{NNN}_{SLUG}/.lock/`) recording `session_id` + heartbeat, acquired atomically.
- `/research`, `/plan`, `/implement`, `/revise`, `/orchestrate` (single-task) acquire on entry and
  release on exit via the shared gate scripts; a fresh lock held by a *different* session refuses
  with clear guidance.
- Multi-task/wave dispatch (`/orchestrate N,M`, `/implement N,M-P`) — which bypasses the gate
  scripts — acquires/releases per-task inside `skill-orchestrate` Stage MT and `implement.md`
  Step 3.
- Stale locks (heartbeat older than the tunable 30-60 min threshold) are overridable with a
  visible warn-and-proceed message; never a silent steal, never a permanent refusal.
- Same-session re-entry (`/research 42` then `/plan 42` in one conversation) must NOT self-block.
- Mandate commit-per-green-substep at every verified-green objective, reconciled against
  `git-workflow.md`'s contradictory prohibition, reusing the 785/786 scoped-staging contract and
  `checkpoint-before-overflow.md`'s green-commit branch.
- All touched files' dual copies remain byte-identical (`diff -q` clean).

**Non-Goals**:
- **git-worktree isolation** — explicitly deferred by user scope; not touched here.
- **`file_scope`-granular cross-task locking** — blocking two *different* task numbers whose
  `file_scope` (from 787) overlaps. Task-number-keyed locking fully solves the 427 same-task
  cross-session failure; cross-task overlap locking requires scanning every held `.lock` at
  acquire time (a materially larger scope 787's own wave-split check deliberately avoided).
  Recommended as a SEPARATE follow-up task for the orchestrator to spawn (see Follow-Up Tasks).
- Retrofitting an atomic-creation guard onto the existing `.orchestrator-loop-guard` file (a real
  pre-existing gap, but out of this task's scope — note it in the follow-up).
- Any change to state.json's schema or write path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Lock-acquire bug in `command-gate-in.sh` blocks ALL task work system-wide (sourced by 5 command files) | H | M | Keep the acquire failure path narrow: refuse ONLY on a genuinely fresh, non-stale lock held by a *different* session_id. Same-session re-entry must pass. Stage behind dual-copy `diff -q` discipline; add a dedicated functional test in Phase 5 before any commit. |
| Drift between the single-task lock path (gate scripts) and the multi-task path (skill-orchestrate/implement.md) | M | M | Both paths call the SAME `task-lock.sh acquire/heartbeat/release` subcommands; never reimplement lock logic inline at any call site (mirrors 787's define-once/reference-many pattern). |
| A crashed session's fresh (non-stale) lock strands a task for up to the full threshold window | M | M | Document a manual override remedy (`rm -rf specs/{NNN}_{SLUG}/.lock`) in the refusal message, in addition to the automatic stale-timeout path (mirrors `guard-destructive-git.sh`'s remedy-in-stderr convention). |
| Editing `git-workflow.md`'s "Do Not Commit" line weakens the adjacent "never `git add -A`" guarantee it sits beside | H | L | Edit ONLY the specific "intermediate states" bullet; leave Commit Scope / Git Safety / Never Run sections untouched; re-grep for `git add -A` / `git commit -am` after the edit (as 786 did). |
| Non-atomic acquire (copying the `jq -n > file` pattern) reintroduces the race the lock exists to close | H | L | Acquire uses `mkdir "$lockdir"` (POSIX-atomic exclusive create) exclusively; the `jq -n > file` pattern is used ONLY for the holder-JSON write and heartbeat updates AFTER the directory is already held. |
| Dual-copy drift on any of ~7 touched files | M | M | Phase 5 runs `diff -q` on every touched pair as a hard gate; no phase self-reports done until its pairs are identical. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint file sets (gate
scripts vs. skill/command files) and may run in parallel. Phase 4 shares `skill-implementer/SKILL.md`
with Phase 3, so it is sequenced after Phase 3 to avoid a same-file collision.

---

### Phase 1: Lock helper script, schema, and canonical pattern doc [COMPLETED]

**Goal**: Create the single source of truth for the task lock — a `task-lock.sh` helper with atomic
`acquire`, plus `heartbeat`, `release`, `check` subcommands — and a canonical pattern doc that every
consumer references. This is the foundation all wiring phases depend on.

**Tasks**:
- [x] **Task 1.1**: Create `.claude/scripts/task-lock.sh` modeled stylistically on `manage-topics.sh` (usage
      header, exit-code table, tmp-file-rename write for JSON). Subcommands:
  - `acquire <task_number> <operation> <session_id> [command]` — resolve the task directory
    (`specs/{NNN}_{SLUG}/`), attempt `mkdir "$TASK_DIR/.lock"` for POSIX-atomic exclusivity. On
    success, write `.lock/holder.json` (`session_id`, `task_number`, `operation`, `acquired_at`,
    `heartbeat_at`, `command`). On `mkdir` failure, read the existing `holder.json`:
    - Same `session_id` -> refresh `heartbeat_at`, exit 0 (re-entry never self-blocks).
    - Different `session_id`, `heartbeat_at` within stale threshold -> exit non-zero with the
      two-line `ABORT:` + remedy refusal message (see below).
    - Different `session_id`, `heartbeat_at` older than the stale threshold -> print the visible
      override-and-warn message to stderr, overwrite `holder.json`, exit 0.
  - `heartbeat <task_number> <session_id>` — update `heartbeat_at` in place (tmp-file rename); no-op
    with a warning if the lock is missing or held by another session.
  - `release <task_number> <session_id>` — unconditionally remove `.lock/` (success/partial/failed
    all release); tolerate an already-absent lock (idempotent).
  - `check <task_number>` — print current holder + staleness for diagnostics; exit code encodes
    free / held-fresh / held-stale.
  *(completed: all 4 subcommands implemented; 5 functional cases manually verified: fresh acquire,
  different-session refusal, same-session re-entry, stale-threshold override, idempotent release)*
- [x] **Task 1.2**: Define a tunable stale-threshold constant (default 30 min, overridable via an env var such as
      `TASK_LOCK_STALE_MIN`), documented as distinct from and much longer than
      `guard-destructive-git.sh`'s unrelated 120s snapshot-freshness window. *(completed)*
- [x] **Task 1.3**: Author the refusal message in the established two-line `ABORT:` + remedy shape (per Finding 8),
      naming the holding session, heartbeat age, threshold, and the manual `rm -rf` remedy. *(completed)*
- [x] **Task 1.4**: Create `.claude/context/patterns/task-lock.md` as the canonical spec: lockfile schema,
      acquire/heartbeat/release/check contract, stale-threshold constant, override-and-warn behavior,
      refusal-message template. Structure it to mirror `file-footprint-overlap.md` /
      `checkpoint-before-overflow.md` so consumers reference one source of truth.
      *(completed: also added a context/index.json entry for discoverability, matching sibling
      pattern docs — index.json itself is not dual-copied, verified no core twin exists)*
- [x] **Task 1.5**: Create the dual copy `.claude/extensions/core/scripts/task-lock.sh` (byte-identical) and, if
      the core extension mirrors context docs, `.claude/extensions/core/context/patterns/task-lock.md`
      (verify whether context docs are dual-copied in this repo before creating).
      *(completed: confirmed context/patterns/ docs ARE dual-copied in this repo via
      checkpoint-before-overflow.md precedent; created both twins, diff -q clean)*

**Timing**: 1.25 hours

**Depends on**: none

**Files to create**:
- `.claude/scripts/task-lock.sh` - new atomic lock helper
- `.claude/extensions/core/scripts/task-lock.sh` - dual copy
- `.claude/context/patterns/task-lock.md` - canonical schema/contract doc
- `.claude/extensions/core/context/patterns/task-lock.md` - dual copy (only if context docs are mirrored)

**Verification**:
- `bash .claude/scripts/task-lock.sh acquire 788 plan sess_TEST` creates `.lock/holder.json`; a
  second `acquire` with a *different* session refuses; a re-`acquire` with the SAME session exits 0.
- `release` removes `.lock/`; `check` on a free task reports free.
- `chmod +x` set; `diff -q` on the script pair is clean.

---

### Phase 2: Wire acquire/release into the single-task gate scripts [COMPLETED]

**Goal**: Make every single-task command (`/research`, `/plan`, `/implement`, `/revise`, and
`/orchestrate`'s own CHECKPOINT 1) acquire the lock at gate-in and release it at gate-out, via the
two already-shared scripts — a minimal, uniform change covering all five entry points at once.

**Tasks**:
- [x] **Task 2.1**: In `command-gate-in.sh`'s `gate_in()`, add a `task-lock.sh acquire` call AFTER the existing
      terminal-status guard (so terminal-status tasks fail fast without ever touching the lock),
      passing the freshly generated `SESSION_ID`, the operation name, and the command string. On a
      non-stale different-session lock, propagate the refusal exit so the command aborts before
      DELEGATE. *(completed)*
- [x] **Task 2.2**: In `command-gate-out.sh`, add an unconditional `task-lock.sh release` call (success, partial,
      and failed skill statuses all release). Ensure release uses the same `SESSION_ID` the gate-in
      acquired with. *(completed: release call placed FIRST in the script, before the state.json /
      .return-meta.json existence checks, since the meta_file-missing branch exits 0 early and would
      otherwise skip an end-of-script release — see progress file approaches_tried)*
- [x] **Task 2.3**: Confirm `/orchestrate` single-task mode acquires once at `orchestrate.md`'s CHECKPOINT 1
      (covering the full multi-cycle lifecycle) and releases once at CHECKPOINT 2 — verify no extra
      per-cycle acquire is introduced (the loop only heartbeats; that is Phase 3). *(completed:
      confirmed via grep — single source at line 354 (CHECKPOINT 1), single release at line 402
      (CHECKPOINT 2), no per-cycle acquire in the Stage 3 loop)*
- [x] **Task 2.4**: Apply identical edits to `.claude/extensions/core/scripts/command-gate-in.sh` and
      `.claude/extensions/core/scripts/command-gate-out.sh`. *(completed, diff -q clean)*

**Deviation note (Task 2.2, altered)**: the plan expected the release call could be added
anywhere as "unconditional"; discovered during implementation that `command-gate-out.sh` has an
early `exit 0` when `.return-meta.json` is missing (a real, common failure path — see line ~53).
Placing the release call after that branch would have made it conditional in practice. Moved the
release call to the top of the script (immediately after argument parsing, before the
`state.json` existence check) so it truly always executes. Functionally verified via manual
gate-in/gate-out round-trip on task 788 itself (see Testing & Validation).

**Finding — NOT a Phase 2 deviation, recorded for Phase 5 / follow-up**: `research.md`, `plan.md`,
and `revise.md` do NOT currently `source` `command-gate-in.sh` / call `command-gate-out.sh` at
all — each has its own fully inline, duplicated CHECKPOINT 1 (GATE IN) / CHECKPOINT 2-3 (GATE OUT)
implementation (confirmed via grep: zero matches for `gate-in\|gate-out\|gate_in\|gate_out` in any
of the three files). Only `implement.md` and `orchestrate.md` actually source the shared gate
scripts. This means today's edit protects `/implement` and `/orchestrate` (single-task) — the two
commands that call the shared scripts — but does NOT yet protect `/research`, `/plan`, or
`/revise`, contrary to this plan's Goals section assumption that all five commands "acquire on
entry and release on exit via the shared gate scripts." Wiring those three commands' inline
CHECKPOINT sections was deliberately NOT done here: it is out of Phase 2's enumerated "Files to
modify" list, those three command files are not part of this plan's ~7-pair dual-copy inventory,
and changing them was not risk-assessed by this plan's Risks & Mitigations. Recorded here (and
repeated in Phase 5 / Follow-Up Tasks) as an explicit, additional follow-up for the orchestrator to
spawn — distinct from the plan's two originally-listed follow-ups.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/command-gate-in.sh` - acquire after terminal-status guard
- `.claude/scripts/command-gate-out.sh` - unconditional release
- `.claude/extensions/core/scripts/command-gate-in.sh` - dual copy
- `.claude/extensions/core/scripts/command-gate-out.sh` - dual copy

**Verification**:
- Sourcing `command-gate-in.sh` twice for the same task with the SAME session (simulating
  `/research 42` then `/plan 42`) does not self-block.
- Two different sessions gate-in on the same task: the second refuses with the ABORT message.
- After `command-gate-out.sh`, `.lock/` is gone; `diff -q` on both script pairs is clean.

---

### Phase 3: Wire multi-task/wave dispatch + heartbeat refresh [COMPLETED]

**Goal**: Close the multi-task gap — `/orchestrate N,M` and `/implement N,M-P` bypass the gate
scripts entirely — by acquiring/releasing per-task inside the wave dispatch loops, and refresh the
heartbeat at existing natural checkpoints so long runs do not go stale under their own hand.

**Tasks**:
- [x] **Task 3.1**: In `skill-orchestrate/SKILL.md` Stage MT (multi-task) dispatch, add `task-lock.sh acquire`
      immediately before each individual task's agent dispatch within a wave and `release`
      immediately after, per-task (NOT in `orchestrate.md`, which only sees the wave/dependency-graph
      JSON, never per-task dispatch). *(completed: added acquire loop before "Dispatch all groups
      in ONE message" and release in the per-task postflight loop, per-task keyed to
      `${session_id}_${task_num}`; refused tasks are deferred to a later cycle, not marked failed)*
- [x] **Task 3.2**: In `skill-orchestrate/SKILL.md` Stage 3 while-loop (the per-cycle boundary where
      `.orchestrator-loop-guard`'s `last_updated` is already refreshed), add a `task-lock.sh
      heartbeat` call at the same point so a multi-hour single-task `/orchestrate` run keeps its lock
      fresh. *(completed)*
- [x] **Task 3.3**: In `implement.md`'s multi-task Step 3 per-task dispatch loop (which invokes a skill call per
      validated task directly from the command file), add `acquire` before and `release` after each
      per-task skill invocation. *(completed)*
- [x] **Task 3.4**: In `skill-implementer/SKILL.md`, add a `task-lock.sh heartbeat` call at each plan-phase
      transition (alongside the existing `update-phase-status.sh` call) so single-task `/implement`
      runs refresh their heartbeat.
      *(completed: altered — see Deviation note below. `skill-implementer/SKILL.md` is a thin
      wrapper with no phase-transition point of its own and no `update-phase-status.sh` call;
      the heartbeat was wired into `general-implementation-agent.md` Stage 4D instead, which is
      the actual per-phase site, with a cross-reference note added to `skill-implementer/SKILL.md`)*
- [x] **Task 3.5**: All call sites invoke the shared `task-lock.sh` subcommands — no inline lock logic. *(completed;
      verified no `mkdir .lock` or lock re-implementation exists outside `task-lock.sh`)*
- [x] **Task 3.6**: Apply identical edits to each file's `.claude/extensions/core/...` twin. *(completed:
      including `general-implementation-agent.md`'s twin, which was added to this phase's file set
      — see Deviation note)*

**Deviation note (Task 3.4, altered)**: the plan assumed `skill-implementer/SKILL.md` contains a
per-phase-transition loop with an `update-phase-status.sh` call to hook alongside. In reality,
`skill-implementer/SKILL.md` is a thin wrapper (per its own header comment) that delegates the
ENTIRE phase loop to `general-implementation-agent` in a single Agent tool call (Stage 5) — it
never iterates phases itself, and `update-phase-status.sh` is not called anywhere in this repo's
standard (non-hard) implementation path (it is only referenced by
`general-implementation-hard-agent.md`). The actual per-phase-transition site for single-task
`/implement` is `general-implementation-agent.md`'s Stage 4D ("Mark Phase Complete"), which fires
once per phase as the subagent progresses through the plan — this is also literally the agent
executing THIS implementation. Wired `task-lock.sh heartbeat` there instead, and added a short
cross-reference note to `skill-implementer/SKILL.md`'s Stage 5 explaining why no heartbeat call
lives in that file. `general-implementation-agent.md` (+ its `.claude/extensions/core/agents/`
twin) is accordingly added to this phase's touched-file set, beyond the plan's original
enumeration.

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage MT acquire/release + Stage 3 heartbeat
- `.claude/commands/implement.md` - Step 3 per-task acquire/release
- `.claude/skills/skill-implementer/SKILL.md` - phase-transition heartbeat
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` - dual copy
- `.claude/extensions/core/commands/implement.md` - dual copy
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - dual copy

**Verification**:
- Read-through confirms every multi-task per-task dispatch is bracketed by acquire/release and every
  named heartbeat point calls `task-lock.sh heartbeat`.
- No call site reimplements lock logic inline (grep for `mkdir .lock` outside `task-lock.sh`).
- `diff -q` clean on all three pairs.

---

### Phase 4: Commit-per-green-substep mandate + git-workflow.md reconciliation [COMPLETED]

**Goal**: Mandate an incremental commit at every verified-green objective, and resolve the direct
contradiction with `git-workflow.md`'s "Do Not Commit: intermediate states" line — reusing the
existing green-commit branch and scoped-staging contract rather than inventing a parallel codepath.

**Tasks**:
- [x] **Task 4.1**: In `git-workflow.md`'s Commit Timing "Do Not Commit" list, REPLACE the
      "Intermediate states during multi-phase operations" bullet with an explicit carve-out: commit
      at every green *sub-step* (a `progress-file.md` objective transitioning to `status: "done"`),
      where "green" means the unit's own verification criteria passed (per
      `checkpoint-before-overflow.md`), NOT merely "some tool calls happened". Keep "Failed
      operations (rollback instead)" and "Partial/incomplete work" (half-applied, unverified edits)
      uncommittable. *(completed: added a new "Commit-Per-Green-Substep Mandate" subsection)*
- [x] **Task 4.2**: Add a Standard Actions table row for the sub-step commit message convention, e.g.
      `task {N} phase {P}.{O}: {objective_description}` (finer granularity than the existing
      per-phase row). Choose one convention and state it unambiguously. *(completed)*
- [x] **Task 4.3**: Make the sub-step commit reuse `checkpoint-before-overflow.md`'s green-commit branch and the
      `implement` scope from `git-staging-scope.md` verbatim (task dir + plan_path + self-reported
      `modified_files`, under-stage-never-over-stage) — do NOT introduce a second staging codepath.
      *(completed)*
- [x] **Task 4.4**: In `skill-implementer/SKILL.md`, wire the "commit here" action to the existing objective-done
      transition (fire the green-commit branch when an objective reaches `status: "done"`), reusing —
      not duplicating — the checkpoint commit mechanism. Compose with the Phase 3 heartbeat edit in
      the same file.
      *(completed: altered — same deviation pattern as Phase 3 Task 3.4. `skill-implementer/SKILL.md`
      is a thin wrapper with no per-objective loop; the objective-done transition lives in
      `general-implementation-agent.md`'s Stage 4B, so the green-commit action was wired into a new
      Stage 4B-iii there instead. Added a composability note to `skill-implementer/SKILL.md`'s
      Stage 6b explaining the two commit granularities compose rather than conflict.)*
- [x] **Task 4.5**: After editing `git-workflow.md`, re-grep for `git add -A` / `git commit -am` to confirm no
      over-staging reference was introduced and the surrounding Git Safety / Never Run sections are
      untouched (785/786 discipline). *(completed: only pre-existing prohibition-context matches
      remain; Git Safety / Never Run sections unchanged)*
- [x] **Task 4.6**: Apply identical edits to `.claude/extensions/core/rules/git-workflow.md` and
      `.claude/extensions/core/skills/skill-implementer/SKILL.md`. *(completed, diff -q clean; also
      synced `.claude/extensions/core/agents/general-implementation-agent.md` per the Task 4.4
      deviation)*

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/rules/git-workflow.md` - replace the contradictory bullet + add Standard Actions row
- `.claude/skills/skill-implementer/SKILL.md` - fire green-commit at objective-done
- `.claude/extensions/core/rules/git-workflow.md` - dual copy
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - dual copy

**Verification**:
- `git-workflow.md` no longer contains the "Intermediate states during multi-phase operations"
  prohibition; the new carve-out references the objective-done / green criterion.
- `grep -n "git add -A\|git commit -am" git-workflow.md` returns only pre-existing prohibition
  context, no new permissive usage.
- `diff -q` clean on both pairs.

---

### Phase 5: Verification, dual-copy parity, and follow-up handoff [COMPLETED]

**Goal**: Prove the lock behaves correctly end-to-end, confirm every touched dual-copy pair is
byte-identical, and record the deferred `file_scope`-granular locking as an explicit follow-up for
the orchestrator to spawn.

**Tasks**:
- [x] **Task 5.1**: Functional lock tests: (a) fresh acquire succeeds; (b) different-session fresh acquire refuses;
      (c) same-session re-acquire passes; (d) stale-threshold override warns-and-proceeds; (e)
      release is idempotent. Drive these through `task-lock.sh` directly with a small temp task dir.
      *(completed: all 5 cases pass — see Testing & Validation)*
- [x] **Task 5.2**: Simulated single-task path: source `command-gate-in.sh` then `command-gate-out.sh` for a test
      task and confirm acquire-then-release leaves no `.lock/`. *(completed: run against task 788's
      own real state.json entry since gate-in requires a real task lookup; round-trip clean, no
      stray `.lock/` left behind, `.return-meta.json` status untouched by the test)*
- [x] **Task 5.3**: Run `diff -q` on EVERY touched pair: `task-lock.sh`, `command-gate-in.sh`,
      `command-gate-out.sh`, `skill-orchestrate/SKILL.md`, `implement.md`, `skill-implementer/SKILL.md`,
      `git-workflow.md`, and any dual-copied context docs. All must be identical.
      *(completed: all 9 pairs clean — the 7 plan-enumerated pairs plus `task-lock.md` and
      `general-implementation-agent.md`, the two additions from the Phase 3/4 deviations)*
- [x] **Task 5.4**: Regression grep: confirm no `git add -A` / `git commit -am` introduced anywhere in this task's
      diff. *(completed: clean — only pre-existing prohibition-context matches in git-workflow.md;
      unrelated historical task 785/786 references in TODO.md/state.json predate this session and
      are not part of this diff)*
- [x] **Task 5.5**: Record the follow-up recommendation (see Follow-Up Tasks) so the orchestrator can spawn it;
      do NOT expand scope into this task. *(completed: Follow-Up Tasks section now has 3 entries —
      the plan's original 2, plus a 3rd discovered during Phase 2 implementation: research.md/
      plan.md/revise.md do not source the gate scripts at all)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Files to modify**:
- None (verification only; may create no artifacts beyond the implementation summary)

**Verification**:
- All functional lock tests pass.
- Every `diff -q` pair is clean (zero output).
- Regression grep is clean.

## Follow-Up Tasks

To be spawned by the orchestrator AFTER 788 completes — do NOT fold into 788:

1. **`file_scope`-granular cross-task locking** (defense-in-depth): block `/implement 99` while
   `/implement 42` holds a lock when their `file_scope` arrays overlap, reusing
   `file-footprint-overlap.md`'s algorithm (787's deliverable). Requires scanning every held `.lock`
   across all task directories at acquire time — a real, bounded new cost 787's own wave-split check
   deliberately avoided. Task-number-keyed locking (788) is the sufficient primary mechanism; this
   is an additive extension.
2. **Atomic-creation guard for `.orchestrator-loop-guard`** (optional): the loop-guard file is
   created via a non-atomic `jq -n > file` write with no guard against a concurrent second
   `/orchestrate` invocation racing the same file — a pre-existing gap 788 leaves untouched. Could
   reuse `task-lock.sh`'s `mkdir` primitive.
3. **Wire the task lock into `research.md`, `plan.md`, and `revise.md`'s own single-task
   CHECKPOINT 1/2 (GATE IN / GATE OUT)** (discovered during Phase 2 implementation, NOT one of
   this plan's originally anticipated follow-ups): these three command files do NOT `source`
   `command-gate-in.sh` / call `command-gate-out.sh` at all — each has its own fully inline,
   duplicated GATE IN / GATE OUT implementation (confirmed via grep: zero matches for
   `gate-in\|gate-out\|gate_in\|gate_out` in any of the three files). Only `implement.md` and
   `orchestrate.md` actually source the shared gate scripts. As a result, today's task-lock wiring
   (Phase 2) protects `/implement` and `/orchestrate` (single-task) but does NOT yet protect
   `/research`, `/plan`, or `/revise` from the same 427-style concurrent-session clobber this
   whole task exists to close. Closing this gap requires either (a) refactoring those three
   command files to actually source the shared gate scripts (a larger, orthogonal architecture
   change — see the `command-gate-in.sh` header comment's stale reference to an unfinished
   "Task 594 (skill-base.sh)" consolidation), or (b) adding equivalent inline
   `task-lock.sh acquire`/`release` calls directly into each file's own CHECKPOINT sections. Left
   out of 788's scope because: it is not in Phase 2's enumerated "Files to modify" list, these
   three command files are not part of 788's ~7-pair dual-copy inventory, and modifying them was
   not risk-assessed by this plan's Risks & Mitigations table. Recommended as a follow-up task
   with its own dedicated risk assessment, since `command-gate-in.sh` is described as "sourced by
   5 command files" but is currently only actually sourced by 2.

## Testing & Validation

- [x] `task-lock.sh acquire/heartbeat/release/check` behave per the schema (all five functional
      cases in Phase 5).
- [x] Same-session re-entry does not self-block (critical safety property — a bug here blocks all
      task work).
- [x] Single-task gate acquire-then-release round-trips cleanly.
- [x] Stale-lock override prints a visible warning and proceeds; never silent, never permanent
      refusal.
- [x] `git-workflow.md` contradiction resolved; no `git add -A` / `git commit -am` regression.
- [x] Every touched dual-copy pair is `diff -q` identical.

## Artifacts & Outputs

- `.claude/scripts/task-lock.sh` (+ core twin) - atomic lock helper
- `.claude/context/patterns/task-lock.md` (+ twin if context docs mirrored) - canonical spec
- Edits to `command-gate-in.sh`, `command-gate-out.sh`, `skill-orchestrate/SKILL.md`,
  `implement.md`, `skill-implementer/SKILL.md`, `git-workflow.md` (each + core twin)
- `specs/788_concurrent_session_lock_commit_cadence/summaries/01_session-lock-commit-cadence-summary.md`
  (on completion)

## Rollback/Contingency

- The lock helper and its wiring are additive; if the acquire path proves too aggressive (e.g.
  blocking legitimate work), revert Phases 2-3 by removing the `task-lock.sh` calls from the gate
  scripts and dispatch loops — `task-lock.sh` itself is inert if never invoked.
- The `git-workflow.md` reconciliation (Phase 4) is a documentation/behavior change; revert by
  restoring the original "Intermediate states" bullet and removing the Standard Actions row.
- Because every change is dual-copied and staged behind `diff -q`, a `git revert` of the task's
  commits cleanly restores both copies of every file.
- If any phase is interrupted, the per-phase status markers and the objective-done commit cadence
  (once Phase 4 lands) ensure completed work is already in git for resume.
