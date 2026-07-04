# Research Report: Task #788

**Task**: 788 - Concurrent-session protection: task lock + mandatory commit-per-green-substep
**Started**: 2026-07-04T17:56:17Z
**Completed**: 2026-07-04T18:20:00Z
**Effort**: 4-6 hours
**Dependencies**: Task #786 (COMPLETE), Task #787 (COMPLETE)
**Sources/Inputs**:
- Codebase: `.claude/scripts/manage-topics.sh`, `.claude/scripts/command-gate-in.sh`,
  `.claude/scripts/command-gate-out.sh`, `.claude/rules/state-management.md`,
  `.claude/context/reference/state-management-schema.md`, `.claude/commands/orchestrate.md`,
  `.claude/commands/implement.md`, `.claude/skills/skill-orchestrate/SKILL.md`,
  `.claude/skills/skill-implementer/SKILL.md`, `.claude/context/standards/git-staging-scope.md`,
  `.claude/context/standards/git-safety.md`, `.claude/context/checkpoints/checkpoint-commit.md`,
  `.claude/context/patterns/checkpoint-before-overflow.md`, `.claude/rules/git-workflow.md`,
  `.claude/context/formats/progress-file.md`, `.claude/context/patterns/file-footprint-overlap.md`,
  `.claude/context/patterns/multi-task-operations.md`, task 779/780/781/786/787 reports and
  summaries.
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **No concurrency protection exists today**, confirmed by direct inspection: `manage-topics.sh`'s
  own header comment states "No flock is used; the codebase convention is tmp-file rename, which
  minimises the write window for single-threaded Claude Code agent sessions" — this is an explicit
  single-threaded assumption, not an oversight. `command-gate-in.sh` performs a pure read (task
  lookup, terminal-status check) with zero reservation semantics; two concurrent sessions calling
  it for the same task both pass cleanly.
- **Recommended design: a per-task lockfile, not a state.json field.** `specs/{NNN}_{SLUG}/.lock`
  (JSON), acquired via `mkdir`/`flock`-guarded atomic creation, mirrors the existing
  `.orchestrator-loop-guard` and `.postflight-pending` marker-file precedents already in the
  codebase. A state.json lock field would require read-modify-write `jq` cycles on the single
  shared `state.json` — exactly the last-write-wins race the lock exists to close — and would
  serialize ALL tasks' lock operations through one file's write contention instead of one
  independent file per task.
- **Acquire/release hook points**: `command-gate-in.sh` (single choke point for `/research`,
  `/plan`, `/implement`, `/revise`, and `/orchestrate`'s own CHECKPOINT 1) is the correct acquire
  site for single-task mode; `command-gate-out.sh` is the correct release site. Multi-task/wave
  dispatch (`orchestrate.md`/`implement.md` "MULTI-TASK DISPATCH" sections) bypasses both scripts
  entirely (`STOP. Do not continue to CHECKPOINT 1`) and needs its own acquire/release calls
  layered into `skill-orchestrate`'s Stage MT-* per-task dispatch, not just the single-task gate
  scripts.
- **Heartbeat/staleness**: a wall-clock timer thread is not available to a Claude Code
  command/skill; heartbeat refresh must happen at existing natural checkpoints
  (`skill-orchestrate`'s Stage 3 while-loop cycle boundary, each plan-phase transition in
  `skill-implementer`) rather than a background process. A stale threshold on the order of
  30-60 minutes (much longer than `git-snapshot.sh`'s 120-second marker freshness, which serves a
  different, much shorter-lived purpose) is recommended, with an explicit override path that
  prints clear guidance rather than silently stealing the lock.
- **`file_scope` (787) should NOT be the lock's primary granularity.** `file_scope` was built for
  a different problem (creation-time sibling-task serialization for `/orchestrate` wave ordering
  within one batch). The 427 failure is a same-task, cross-session collision, for which
  task-number-keyed locking is the correct and sufficient primary mechanism. Extending lock
  checking to cross-task `file_scope` overlap (so two *different*, independently-dispatched task
  numbers with overlapping `file_scope` also block each other) is a real, valuable but materially
  larger follow-on scope — it requires scanning all currently-held locks across all task
  directories at every acquire, reusing `file-footprint-overlap.md`'s algorithm (787's finished
  deliverable) rather than reinventing it. Recommend flagging this as an explicit Phase 2/
  follow-up decision for the plan, not folding it into 788's first implementation.
- **Commit-per-green-substep directly contradicts the current `git-workflow.md` "Do Not Commit"
  list** ("Partial/incomplete work", "Intermediate states during multi-phase operations"). This is
  the single most important compatibility finding: 788 cannot simply add new guidance — it must
  reconcile/replace this existing prohibition, aligned with the "green" concept `781` already
  established in `checkpoint-before-overflow.md` (commit only when a checkpoint's own verification
  criteria passed). The natural sub-step unit already exists: `progress-file.md`'s per-phase
  `objectives[]` array (status `done`) is the exact granularity a "green sub-step" commit should
  fire on.
- **Dual-copy pairs**: every core file this task is likely to touch is confirmed byte-identical
  between `.claude/...` and `.claude/extensions/core/...`: `command-gate-in.sh`,
  `command-gate-out.sh`, `orchestrate.md`, `implement.md`, `skill-orchestrate/SKILL.md`,
  `skill-implementer/SKILL.md`, `git-workflow.md`, `state-management.md`,
  `state-management-schema.md`, `manage-topics.sh`, `multi-task-operations.md`. Any plan for 788
  must edit both copies of each touched file and verify `diff -q` parity, per the pattern already
  established by 785/786/787.

## Context & Scope

Task 788's user-selected scope is **lock + commit-per-step only** — git-worktree isolation is
explicitly out of scope and deferred. This report investigates: (1) the lockfile-vs-state-field
design tradeoff, (2) the heartbeat/stale-threshold mechanism, (3) where `/orchestrate` and
`/implement` should acquire/release the lock, (4) how commit-per-green-substep integrates with the
existing checkpoint/git-safety cluster (779/780/781), and (5) whether the lock should key on
`file_scope` (787) instead of/in addition to task number.

## Findings

### Codebase Patterns

#### 1. Confirmed absence of concurrency protection

- `manage-topics.sh` (lines 26-28): explicit comment — "No flock is used; the codebase convention
  is tmp-file rename, which minimises the write window for single-threaded Claude Code agent
  sessions." All state.json writers in this codebase (`manage-topics.sh`,
  `update-task-status.sh`, and every skill's inline `jq ... > tmp && mv tmp -> state.json` pattern)
  follow the same tmp-file-rename convention: atomic *per write*, but with zero cross-session
  reservation — two sessions can both read stale state, both compute a new document, and the
  second `mv` silently clobbers the first's write. This is the state.json half of the 427 failure
  mode; task lock addresses the *task-level* race (two sessions working the same task
  concurrently), a related but distinct problem from raw state.json write races.
- `command-gate-in.sh` (`gate_in()` function, lines 30-73): generates a fresh `SESSION_ID`, looks
  up the task, and blocks only on **terminal status** (`completed|abandoned|expanded`). It has no
  concept of "is another session already working this." Two concurrent invocations for the same
  task number both pass gate-in successfully today.
- `command-gate-out.sh`: performs defensive status correction and artifact-link repair by reading
  `.return-meta.json`. It has no release-a-reservation step because there is no reservation to
  release.

#### 2. Existing marker-file precedent for exactly this kind of per-task, non-state.json signal

Two existing files under `specs/{NNN}_{SLUG}/` already establish the marker-file pattern the lock
should follow, rather than a state.json field:

- **`.postflight-pending`** (`skill-implementer/SKILL.md` Stage 3): a JSON marker written to
  `specs/${padded_num}_${project_name}/.postflight-pending` at the start of implementation,
  containing `session_id`, `skill`, `task_number`, `operation`, `reason`, `created`,
  `stop_hook_active`. Purpose: prevent premature termination before postflight completes. This is
  structurally almost identical to a lock record (session_id + task context + timestamp), just
  scoped to "postflight pending" rather than "task reserved."
- **`.orchestrator-loop-guard`** (`skill-orchestrate/SKILL.md` Stage 2, lines 100-131): a JSON file
  at `${TASK_DIR}/.orchestrator-loop-guard` tracking `session_id`, `cycle_count`, `max_cycles`,
  `current_state`, `started`, `last_updated` — created fresh or resumed across conversational
  turns. **This is the closest existing precedent to a lock file**: it already tracks a
  `session_id` + a `last_updated` timestamp per task directory, created via plain
  `jq -n ... > "$loop_guard_file"` (no `flock`, no atomicity guard on the initial creation — a real
  gap if two `/orchestrate` invocations for the same task raced on this exact file today).

**Conclusion**: the codebase's own precedent (loop-guard, postflight-pending) already puts
lock-shaped state in per-task marker files under the task directory, not in state.json. A new
`.lock` file at `specs/{NNN}_{SLUG}/.lock` is architecturally consistent with, not a departure
from, this convention — and closes a real pre-existing gap (the loop-guard file itself has no
atomic-creation guard against a concurrent second `/orchestrate` invocation).

#### 3. Lockfile vs. state.json field — tradeoff analysis

| Dimension | Lockfile (`specs/{NNN}_{SLUG}/.lock`) | state.json field (`active_projects[].lock`) |
|---|---|---|
| Write contention | Isolated per task; N tasks = N independent files | All tasks share one file; every lock acquire/release/heartbeat is a full state.json read-modify-write, competing with every *other* task's status updates, artifact links, and dependency edits |
| Atomicity primitive | `mkdir` (atomic exclusive create on POSIX) or `flock -n` on a sentinel fd; well-suited to a single boolean "does this exist" test | Requires a full jq read + compare + conditional write; a TOCTOU race window exists between the read and the `mv` even with tmp-file-rename, because a second session's read can happen inside that window |
| Precedent | Matches `.orchestrator-loop-guard`, `.postflight-pending` | Matches `manage-topics.sh`'s explicitly single-threaded convention — the exact pattern this task exists to fix |
| Staleness/GC | Self-contained; deleting/ignoring one stale `.lock` file cannot corrupt other tasks' state | A stuck/never-released lock field pollutes the single shared state.json schema for every task forever until manually cleaned |
| Visibility to user | `ls specs/{NNN}_{SLUG}/.lock`, `cat` it directly | Requires a `jq` query filtered to one task |
| TODO.md rendering | None needed (like `.orchestrator-loop-guard`, never rendered) | Would need explicit "no TODO.md surface" carve-out, mirroring `file_scope`'s/`next_artifact_number`'s precedent |

**Recommendation**: lockfile. It isolates lock contention per-task (avoiding new contention on the
single shared state.json this task is trying to make safer, not less safe), matches two existing
precedents in the codebase, and gives a clean atomic-creation primitive (`mkdir` or `flock`) that a
jq-based state.json field cannot cleanly provide without introducing its own new race window.

**Suggested schema** (modeled on `.orchestrator-loop-guard`'s existing shape):
```json
{
  "session_id": "sess_1783182771_c4ab90",
  "task_number": 788,
  "operation": "implement",
  "acquired_at": "2026-07-04T18:00:00Z",
  "heartbeat_at": "2026-07-04T18:14:00Z",
  "command": "/implement 788"
}
```

#### 4. Atomic acquire mechanism

A plain `jq -n ... > "$lockfile"` write (the pattern `manage-topics.sh` and
`.orchestrator-loop-guard` both use for their own files) is **not** atomic-on-creation — it always
succeeds whether or not the file existed, so two concurrent sessions racing the same `jq -n`
command both "succeed" and the second silently clobbers the first. The acquire step needs a
genuinely exclusive creation primitive. Two standard, portable options:

- `mkdir "$lockdir"` — `mkdir` is atomic on POSIX filesystems (fails with an error if the directory
  already exists); a directory-based lock (`specs/{NNN}_{SLUG}/.lock/` containing a `holder.json`
  inside it) gives atomicity for free with no extra tooling dependency.
- `flock -n 9 9>"$lockfile.flock"` around the read-check-write of the JSON content file — `flock`
  is already a standard coreutils tool; this is the more conventional Unix approach and keeps the
  lock content itself a plain file (`.lock`) rather than a directory.

Either is workable; `mkdir`-based exclusivity is slightly simpler to reason about in bash without
introducing a new command dependency, and is recommended as default unless the planning phase
finds a reason to prefer `flock`.

#### 5. Heartbeat / stale-threshold mechanism

Claude Code commands and skills execute as a single foreground tool-call sequence — there is no
background timer thread available to refresh a heartbeat on a wall-clock cadence independent of
what the agent is doing. Heartbeat refresh must therefore happen at **existing natural
checkpoints**, not a timer:

- `skill-orchestrate`'s Stage 3 while-loop (`while [ "$cycle_count" -lt "$MAX_CYCLES" ]`,
  `skill-orchestrate/SKILL.md` line 149) already has a per-cycle boundary where
  `.orchestrator-loop-guard`'s `last_updated` is naturally refreshed — the lock's `heartbeat_at`
  should be refreshed at the same point.
- `skill-implementer` has per-phase transitions (status updates via `update-phase-status.sh`) as a
  natural heartbeat point for single-task `/implement` runs.
- Contrast with `git-snapshot.sh`'s freshness marker (`checkpoint-before-overflow.md`,
  `guard-destructive-git.sh`): that marker's ~120-second freshness window exists to bound a single
  destructive-git-command race immediately after a snapshot — a fundamentally different, much
  shorter-lived purpose than a task lock that must stay valid for an entire multi-hour
  `/orchestrate` run. **Do not reuse the 120s constant** for the task lock; a much longer threshold
  (recommend 30-60 minutes, tunable) reflecting realistic dispatch durations (agent research/plan/
  implement calls routinely run many minutes) is appropriate.
- **Stale override**: if `heartbeat_at` is older than the threshold, the acquiring session should
  be allowed to steal the lock, but only with a clear, visible message (mirroring
  `guard-destructive-git.sh`'s stderr-guidance-on-block convention and the `--lit` "never a silent
  no-op" philosophy already established system-wide) — e.g. "Task 788 lock held by session
  sess_XXX, last heartbeat 47 minutes ago (stale threshold 30m) — proceeding and overriding stale
  lock. If session sess_XXX is still active, this may cause conflicting writes." This is
  deliberately not a hard refusal; it degrades to a warning once staleness is confirmed, since an
  abandoned/crashed session must never permanently strand a task.

#### 6. Acquire/release hook points — single-task mode

`command-gate-in.sh` is sourced (not subprocessed — the header comment is explicit about why:
"MUST be sourced... because it exports variables into the calling shell") by every single-task
invocation of `/research`, `/plan`, `/implement`, `/revise`, and by `/orchestrate`'s own
CHECKPOINT 1 (`orchestrate.md` line 354: `source .claude/scripts/command-gate-in.sh "$task_number"
"orchestrate"`). This makes it the single correct acquire site for all single-task commands
uniformly — a lock-acquire step added to `gate_in()` (or a new sibling function called from it)
covers every entry point without needing five separate edits.

`command-gate-out.sh` is the mirrored release site, called by every command after DELEGATE
completes (`implement.md` CHECKPOINT 2, `orchestrate.md` CHECKPOINT 2). Release should be
unconditional here (success, partial, or failed skill status all release the lock) — a
crashed/interrupted agent that never returns to gate-out is exactly the scenario the stale-lock
override exists to recover from, not a case gate-out can itself handle.

**Important nuance for `/orchestrate`**: `orchestrate.md`'s CHECKPOINT 1/2 wrap the *entire*
`skill-orchestrate` invocation, which may internally loop through several
research→plan→implement cycles (`MAX_CYCLES=5`) via its own Stage 3 while-loop, **not** through
repeated `/research`/`/plan`/`/implement` command invocations. This means the lock is acquired
once at `orchestrate.md`'s own gate-in and held for the *entire* orchestration lifecycle (all
cycles), then released once at its own gate-out — correctly modeling "this session owns this task
for the whole run," in contrast to a standalone `/implement 42` which acquires and releases within
one shorter invocation.

#### 7. Acquire/release hook points — multi-task/wave mode (the gap single-task hooking misses)

Both `orchestrate.md` and `implement.md` have a **MULTI-TASK DISPATCH** section that explicitly
bypasses CHECKPOINT 1/2 entirely:

> "**After consolidated output, STOP. Do not continue to CHECKPOINT 1.**" (`orchestrate.md` line
> 347; `implement.md` line 93 has the equivalent "**After consolidated output, STOP.**")

This means hooking lock acquire/release only into `command-gate-in.sh`/`command-gate-out.sh`
leaves every multi-task batch invocation (`/orchestrate 42,43,44`, `/implement 7,22-24,59`)
completely unlocked. For `/orchestrate`'s multi-task mode specifically, `orchestrate.md`'s
"Single-Dispatch Multi-Task Mode" delegates all wave-by-wave dispatch to a **single**
`skill-orchestrate` invocation with `multi_task_mode=true` (line 229-236), which then manages
per-task dispatch internally via its own Stage MT-* stages (referenced, not fully read in this
pass — `skill-orchestrate/SKILL.md`'s Stage 0 confirms `multi_task_mode` branches to "Stage MT-1
through MT-5"). The correct acquire/release points for multi-task mode are therefore **inside
`skill-orchestrate`'s Stage MT dispatch**, immediately before/after each individual task's
research/plan/implement agent dispatch within a wave — not in `orchestrate.md` itself (which never
sees individual per-task dispatch, only the wave/dependency-graph JSON it hands off). `implement.md`'s
multi-task mode (Step 3, "Dispatch Skills") does invoke a separate skill call per validated task
directly from the command file, so for `/implement`'s own multi-task path the acquire/release can
be added directly around each per-task skill invocation in that loop.

This is a real design fork the planning phase must resolve explicitly: single-task mode's lock
hook is a one-line addition to two already-shared scripts; multi-task mode's lock hook requires
edits inside `skill-orchestrate/SKILL.md`'s Stage MT logic (dual-copied) and `implement.md`'s
Step 3 dispatch loop (dual-copied), not the shared gate scripts.

#### 8. Refusal UX — precedent to follow

`command-gate-in.sh`'s existing terminal-status refusal (lines 56-63) is the direct style
precedent for a lock refusal message:
```
ABORT: Task $task_number is in terminal status: $TASK_STATUS
  Use --force to override (implement only), or check task status with /task --sync
```
A lock refusal should follow the same two-line ABORT + remedy-instruction shape, e.g.:
```
ABORT: Task $task_number is locked by session $lock_session_id (heartbeat $age ago)
  Wait for that session to finish, or if it has crashed, re-run to override after the stale threshold ($STALE_MIN min).
```

### External Resources

No web research was needed; this is a self-contained internal-tooling design question, fully
answerable from the referenced files and the 779/780/781/786/787 artifact trail.

### Recommendations

1. **Lock file format and location**: `specs/{NNN}_{SLUG}/.lock` (JSON), schema per Finding 3
   above. New helper script `.claude/scripts/task-lock.sh` with subcommands `acquire`, `heartbeat`,
   `release`, `check` — modeled stylistically on `manage-topics.sh` (usage header, exit-code table,
   tmp-file-rename write pattern) but using `mkdir`-based atomic exclusivity for `acquire` (Finding
   4) rather than plain `jq -n > file`. Needs a dual copy at
   `.claude/extensions/core/scripts/task-lock.sh`.

2. **Acquire/release wiring**:
   - Single-task: extend `command-gate-in.sh`'s `gate_in()` with a lock-acquire call after the
     terminal-status guard (so terminal-status tasks fail fast without ever touching the lock);
     extend `command-gate-out.sh` with an unconditional lock-release call. Both scripts need their
     `.claude/extensions/core/scripts/` twins updated in lockstep.
   - Multi-task: add acquire/release calls inside `skill-orchestrate/SKILL.md`'s Stage MT dispatch
     (per-task, around each wave member's agent dispatch) and inside `implement.md`'s multi-task
     Step 3 per-task loop — both dual-copied.
   - `/orchestrate` single-task mode acquires once at `orchestrate.md`'s CHECKPOINT 1 (covering the
     full multi-cycle lifecycle) and releases once at CHECKPOINT 2, per Finding 6.

3. **Heartbeat refresh points**: `skill-orchestrate`'s Stage 3 per-cycle boundary; per-phase
   transitions in `skill-implementer`/`general-implementation-agent`. Stale threshold: a tunable
   constant (recommend default 30-60 min, distinct from and much longer than
   `guard-destructive-git.sh`'s unrelated 120s snapshot-freshness window) with a visible
   override-and-warn behavior, never a silent steal and never a hard permanent refusal (an
   abandoned session must not permanently strand a task).

4. **`file_scope`-granularity lock checking: recommend deferring to a follow-up task**, not folding
   into 788. Task-number-keyed locking directly and sufficiently addresses the 427 failure (same
   task, two sessions). Cross-task `file_scope`-overlap lock checking (blocking `/implement 99`
   while `/implement 42` holds a lock, if their `file_scope` arrays overlap per
   `file-footprint-overlap.md`'s algorithm) is a real, valuable defense-in-depth extension that
   787 already built the reusable overlap-detection primitive for — but it requires scanning every
   *other* currently-held `.lock` file across all task directories at acquire time (a real,
   if bounded, new cost 787's own wave-split check deliberately avoided by scoping to
   "the small set of tasks already collected for this invocation" rather than a repo-wide scan).
   Recommend the 788 plan state this explicitly as an accepted Non-Goal/Risk with a named
   follow-up task, exactly as 787 itself deferred cross-batch wave-split detail as residual risk
   in its own report.

5. **Commit-per-green-substep — reconcile, don't just add**: `git-workflow.md`'s existing "Do Not
   Commit" list (lines 46-49: "Partial/incomplete work", "Failed operations (rollback instead)",
   "Intermediate states during multi-phase operations") directly contradicts the mandate. The plan
   must **replace** the "Intermediate states during multi-phase operations" line with an explicit
   carve-out aligned to `checkpoint-before-overflow.md`'s already-established "green" test
   (verification criteria passed for the unit of work, not merely "some tool calls happened") —
   i.e., commit at every green *sub-step* (not merely every green *phase*), where "sub-step" maps
   onto `progress-file.md`'s existing per-phase `objectives[]` granularity (an objective
   transitioning to `status: "done"`). This is the natural, already-instrumented unit — no new
   tracking schema is needed, only a new "commit here" action wired to the existing objective-done
   transition. "Failed operations (rollback instead)" and "Partial/incomplete work" (meaning a
   half-applied, unverified edit) should remain uncommittable — commit-per-green-substep only
   fires on a **verified-green** objective, not on every tool call.

6. **Commit scope for sub-step commits**: reuse the `implement` scope from
   `.claude/context/standards/git-staging-scope.md` verbatim (task dir + plan_path +
   self-reported `modified_files`, under-stage-never-over-stage) — this is exactly the scope
   `checkpoint-before-overflow.md`'s own "Dirty tree, confirmably green" branch already uses for
   its context-pressure checkpoint commit (Finding in Context section below), so 788's
   sub-step-commit mechanism should literally be "run the checkpoint-before-overflow green-commit
   branch at every green objective, not only at context-pressure handoff time" rather than
   inventing a second, parallel commit-staging codepath.

7. **Commit message convention**: extend `git-workflow.md`'s Standard Actions table with a new row,
   e.g. `task {N} objective {O}: {objective_description}` or reuse the existing
   `task {N} phase {P}: {phase_name}` row at finer granularity if the plan decides sub-step
   commits should carry an objective suffix (`task {N} phase {P}.{O}: {objective_description}`).
   This is a plan-level naming decision, not resolved definitively by this research.

## Decisions

- **Lockfile over state.json field** — isolates contention, matches existing marker-file
  precedent (`.orchestrator-loop-guard`, `.postflight-pending`), avoids adding new contention to
  the exact file whose write-race semantics motivated this task.
- **`mkdir`- or `flock`-based atomic acquire**, not a plain `jq -n > file` write — the existing
  `.orchestrator-loop-guard` creation pattern is not actually race-safe and should not be copied
  verbatim for the new lock's acquire step (though its JSON *shape* is a good precedent).
- **Heartbeat refresh at existing checkpoints, not a timer** — no background-thread heartbeat is
  architecturally possible in this execution model; refresh piggybacks on the orchestrate cycle
  loop and implementer phase transitions.
- **Task-number-keyed locking is the primary, in-scope mechanism for 788.** `file_scope`-keyed
  cross-task lock checking is recommended as an explicit follow-up, not in-scope here.
- **Commit-per-green-substep reuses `checkpoint-before-overflow.md`'s green-commit branch and the
  `implement` git-staging-scope contract**, rather than inventing a new staging/verification
  concept — the sub-step unit is `progress-file.md`'s existing per-objective granularity.
- **`git-workflow.md`'s "Do Not Commit: intermediate states during multi-phase operations" line
  must be edited/replaced**, not left standing alongside the new mandate — this is a direct
  contradiction the plan must resolve as a first-class phase, not a footnote.

## Risks & Mitigations

- **Risk**: Adding a lock-acquire step to `command-gate-in.sh` changes the exit/error contract of
  a script sourced by five different command files (`/research`, `/plan`, `/implement`,
  `/revise`, `/orchestrate`). A bug in the new acquire logic could block all task work
  system-wide. **Mitigation**: keep the lock-acquire failure path narrow and well-tested (only
  refuse on a genuinely fresh, non-stale lock held by a *different* session_id — same-session
  re-entry, e.g. `/research 42` then `/plan 42` in sequence within one conversation, must not
  self-block), and stage the change behind the same dual-copy `diff -q` verification discipline
  785/786/787 already established.
- **Risk**: Multi-task/wave mode's lock hook lives in a different code path
  (`skill-orchestrate/SKILL.md` Stage MT, `implement.md` Step 3) than single-task mode
  (`command-gate-in.sh`/`command-gate-out.sh`), doubling the surface area and risking drift between
  the two lock-enforcement paths. **Mitigation**: have both paths call the same
  `task-lock.sh acquire/release` subcommands rather than reimplementing lock logic inline in each
  call site — mirrors how `file-footprint-overlap.md`'s algorithm is defined once and referenced
  by every consumer (787's own pattern).
- **Risk**: A crashed session leaves a fresh (non-stale) lock that blocks a legitimate resumption
  for up to the full stale-threshold window (e.g. 30-60 min), which may be unacceptably long for
  a user trying to immediately resume interrupted work in a new session. **Mitigation**: document
  a manual override remedy in the refusal message (e.g. "if you are certain no other session is
  active, delete `specs/{NNN}_{SLUG}/.lock` manually") in addition to the automatic stale-timeout
  path, mirroring `guard-destructive-git.sh`'s own remedy-in-stderr convention.
- **Risk**: Reconciling `git-workflow.md`'s "Do Not Commit: intermediate states" line touches a
  rule with a broad `paths` matcher (`specs/**/*`, `.claude/**/*`) and is referenced by many
  agents/skills; a careless edit could weaken the "never `git add -A`" guarantee it sits next to.
  **Mitigation**: edit only the specific bullet in question, leave the surrounding
  "Commit Scope"/"Git Safety"/"Never Run" sections untouched, and re-verify (as 786 did) that no
  `git add -A`/`git commit -am` references were introduced.

## Context Extension Recommendations

- **Topic**: Task lock schema and helper script.
  **Gap**: No canonical lock-file schema or acquire/release helper exists yet, unlike the
  file-footprint-overlap algorithm (787) or the git-snapshot helper (780).
  **Recommendation**: create `.claude/context/patterns/task-lock.md` (schema, acquire/release
  contract, stale-threshold constant, refusal-message template) as the single source of truth,
  referenced by `command-gate-in.sh`, `command-gate-out.sh`, `skill-orchestrate/SKILL.md`, and
  `implement.md` — mirroring exactly how `file-footprint-overlap.md` and
  `checkpoint-before-overflow.md` are structured and referenced by their consumers.

## Appendix

### Search queries / commands used
- `grep -rln "lock" .claude/` (broad; matched many false positives like "block"/"unlock" —
  narrowed to `grep -rln "flock|\.lock\b|lockfile|task lock|task-lock|reserve.*task"`, confirming
  no existing task-lock mechanism)
- Direct `Read` of `manage-topics.sh`, `command-gate-in.sh`, `command-gate-out.sh`,
  `state-management.md`, `state-management-schema.md`, `orchestrate.md`, `implement.md`,
  `skill-orchestrate/SKILL.md` (Stage 0-3), `skill-implementer/SKILL.md` (Stage 1-3),
  `git-staging-scope.md`, `git-safety.md` (context/standards copy), `checkpoint-commit.md`,
  `checkpoint-before-overflow.md`, `git-workflow.md`, `progress-file.md`,
  `file-footprint-overlap.md`.
- `diff -q` dual-copy parity checks for `command-gate-in.sh`, `command-gate-out.sh`,
  `skill-orchestrate/SKILL.md`, `skill-implementer/SKILL.md`, `orchestrate.md`, `implement.md`,
  `git-workflow.md`, `state-management.md`, `state-management-schema.md`, `manage-topics.sh`,
  `multi-task-operations.md` — all confirmed identical.
- Read of task 779, 780, 781 summaries and the 787 report/summary for the git-safety/checkpoint
  cluster and the `file_scope`/overlap-algorithm precedent.

### References
- `.claude/scripts/manage-topics.sh` (lines 26-28, single-threaded convention comment)
- `.claude/scripts/command-gate-in.sh` (`gate_in()`, lines 30-73)
- `.claude/scripts/command-gate-out.sh` (full file)
- `.claude/skills/skill-orchestrate/SKILL.md` (Stage 0 multi-task branch, Stage 2 loop-guard lines
  100-131, Stage 3 while-loop line 149)
- `.claude/skills/skill-implementer/SKILL.md` (Stage 1-3, `.postflight-pending` lines 83-103)
- `.claude/commands/orchestrate.md` (CHECKPOINT 1 line 354, multi-task STOP line 347, Step 3/4
  wave assignment and file-safety notes lines 108-236)
- `.claude/commands/implement.md` (multi-task STOP line 93, CHECKPOINT 1/2/3)
- `.claude/context/standards/git-staging-scope.md` (full file — `implement` scope, fail-safe
  direction)
- `.claude/context/checkpoints/checkpoint-commit.md` (full file)
- `.claude/context/patterns/checkpoint-before-overflow.md` (full file — green/RED decision table,
  120s marker distinction)
- `.claude/rules/git-workflow.md` (Commit Timing "Do Not Commit" list lines 46-49, Standard
  Actions table)
- `.claude/context/formats/progress-file.md` (full file — per-objective granularity)
- `.claude/context/patterns/file-footprint-overlap.md` (full file — overlap algorithm, Non-Goals)
- `specs/779_hardmode_fix_forward_recovery_contract/summaries/01_recovery-contract-fix-forward-summary.md`
- `specs/780_agent_git_safety_preserve_uncommitted_work/summaries/01_guard-destructive-git-hook-summary.md`
- `specs/781_agent_context_overflow_checkpoint_handoff/summaries/01_checkpoint-before-overflow-summary.md`
- `specs/787_file_footprint_aware_dependencies/reports/01_file-footprint-aware-dependencies.md`
- `specs/787_file_footprint_aware_dependencies/summaries/01_file-footprint-aware-dependencies-summary.md`
