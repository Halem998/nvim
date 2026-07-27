# Task Lock Pattern

Canonical, single-source definition of the per-task concurrency lock used to prevent two
Claude Code sessions from silently clobbering the same shared working tree (task 788; the 427
failure: an uncommitted in-progress task wiped by a second session working the same task
number). Every consumer (gate scripts, `skill-orchestrate`, `implement.md`,
`skill-implementer`) references this document and `.claude/scripts/task-lock.sh` by path and
never restates or reimplements the acquire/heartbeat/release/check logic inline.

**Related**: `.claude/scripts/task-lock.sh` (the implementation), `checkpoint-before-overflow.md`
(git checkpoint procedure this lock composes with), `file-footprint-overlap.md` (a DISTINCT
overlap-detection document; `acquire`'s cross-task check reuses its algorithm — see "Cross-Task
`file_scope` Overlap Check" below), `.claude/context/standards/git-staging-scope.md`.

## Scope

This lock is primarily **task-number-keyed**: it prevents two sessions from both working task N
at once. As of task 809, `acquire` ALSO detects and blocks two sessions working two DIFFERENT
tasks whose declared `file_scope` overlaps (directory-prefix containment, per
`file-footprint-overlap.md`) — see "Cross-Task `file_scope` Overlap Check" below. The two checks
compose: the task-number check and the cross-task `file_scope` check are independent gates
inside the same `acquire` call, and either one refusing is sufficient to refuse the acquire.

## Lockfile Schema

Location: `specs/{NNN}_{SLUG}/.lock/` — a directory, created via `mkdir` for POSIX-atomic
exclusive create (mkdir fails immediately if the directory already exists; there is no
check-then-create race window, unlike the codebase's usual `jq -n > file` write pattern used
for state.json and similar files).

Holder record: `specs/{NNN}_{SLUG}/.lock/holder.json`, written via the same tmp-file-rename
pattern as `manage-topics.sh` (`jq -n ... > holder.json.tmp && mv holder.json.tmp holder.json`)
so the JSON write itself is atomic-on-replace even though the initial directory creation is what
provides exclusivity:

```json
{
  "session_id": "sess_1736700000_a1b2c3",
  "task_number": 788,
  "operation": "plan",
  "acquired_at": "2026-07-04T18:07:17Z",
  "heartbeat_at": "2026-07-04T18:12:40Z",
  "command": "/plan 788"
}
```

| Field | Type | Description |
|-------|------|--------------|
| `session_id` | string | The holding session's ID (`sess_{timestamp}_{hex}`) |
| `task_number` | integer | The locked task's number (unpadded) |
| `operation` | string | `research` \| `plan` \| `implement` \| `revise` \| `orchestrate` |
| `acquired_at` | string (ISO8601) | When the lock was first acquired (preserved across heartbeats and same-session re-acquires) |
| `heartbeat_at` | string (ISO8601) | Last refresh; staleness is computed from this field |
| `command` | string | The invoking command string, for diagnostics (may be empty) |

## Why `mkdir`, Not `jq -n > file`

The codebase's prevailing atomic-write idiom (`manage-topics.sh`, `update-task-status.sh`) is
`jq ... > tmp && mv tmp target` — this is atomic **on replace** (the `mv` is atomic), but it is
NOT atomic **on creation**: two processes can both observe "file does not exist yet" and both
proceed to write, racing each other. That race is exactly the class of bug this lock exists to
close, so reusing that idiom for the lock's exclusivity primitive would be circular.

`mkdir "$lock_dir"` is POSIX-atomic exclusive create: the syscall itself fails with `EEXIST` if
the directory already exists, with no window between "check" and "create". This script uses
`mkdir` ONLY for the directory (the exclusivity gate); the `holder.json` content within an
already-held directory is still written with the familiar tmp-file-rename pattern, since at that
point only the lock's own holder is touching it.

## Stale Threshold

Tunable via `TASK_LOCK_STALE_MIN` (default 30, plan-sanctioned range 30-60 minutes). This
constant is **distinct from and much longer than** `git-snapshot.sh`'s unrelated 120-**second**
marker-freshness window — that window gates a single destructive-git-command exemption; this
threshold gates whether a lock is still meaningful for concurrency purposes over the timescale
of an entire `/research`/`/plan`/`/implement` invocation (which can run for many minutes).

## Contract: acquire / heartbeat / release / check / init-marker

All five subcommands are implemented exactly once in `.claude/scripts/task-lock.sh`. Call sites
NEVER reimplement lock logic inline (no ad hoc `mkdir .lock` elsewhere in the codebase).

### `acquire <task_number> <operation> <session_id> [command]`

1. Resolve the task directory (`specs/{NNN}_{SLUG}/`, preferring `state.json`'s
   `project_name`, falling back to a filesystem glob).
2. **(task 809)** Acquire the `specs/.scope-lock/` global mutex (see "Cross-Task `file_scope`
   Overlap Check" below). On mutex timeout, print an error and exit **2** (fail closed — never
   fail open). Inside the mutex: run the cross-task `file_scope` overlap scan; a fresh
   overlapping foreign lock refuses here (exit 1) before the own-task `mkdir` is ever attempted.
3. `mkdir "$TASK_DIR/.lock"`.
   - **Success** (directory did not exist): write `holder.json`, exit 0. Fresh acquire.
4. **`mkdir` failure** (directory already exists): read the existing `holder.json` and branch
   on `session_id` FIRST, before ever considering staleness:
   - **Same `session_id`** (the CRITICAL, highest-impact case — see below): refresh
     `heartbeat_at` in place, preserve `acquired_at`, exit 0. Same-session re-entry NEVER
     self-blocks, regardless of staleness.
   - **Different `session_id`, fresh** (`heartbeat_at` within `TASK_LOCK_STALE_MIN`): refuse.
     Print the two-line `ABORT:` + remedy message (see below) to stderr, exit 1.
   - **Different `session_id`, stale** (`heartbeat_at` older than the threshold): print the
     visible override-and-warn message to stderr, overwrite `holder.json` for the new session,
     exit 0. Never a silent steal, never a permanent refusal.

The mutex (step 2) wraps BOTH the cross-task scan and the entire own-task mkdir/holder sequence
(steps 2-4), closing the scan-then-mkdir TOCTOU race between two concurrent acquires with
overlapping `file_scope`.

#### Cross-Task `file_scope` Overlap Check (task 809)

In addition to the task-number check above, `acquire` scans every OTHER currently-held
`.lock/holder.json` under `specs/` for a `file_scope` overlap with the acquiring task's own
declared `file_scope`, using `file-footprint-overlap.md`'s directory-prefix algorithm exactly
(transcribed to jq in `scopes_overlap()`; not restated or forked). This is a repo-wide scan,
distinct from `file-footprint-overlap.md`'s own two batch-scoped callers (see that document's
Consumers section).

- **`file_scope` empty or absent** (either side): no protection, no scan effect, in either
  direction. `file_scope` is optional; a task without one is neither protected from nor
  protecting against overlap.
- **Same-session bypass**: a foreign lock held by the SAME literal `session_id` is skipped
  entirely, even if its `file_scope` overlaps. This mirrors the task-number check's same-session
  re-entry property. Multi-task dispatch sessions are suffixed per-task (`sess_..._${task_num}`)
  and are therefore distinct sessions for this purpose — they ARE enforced against each other.
- **Fresh overlapping foreign lock**: refuse. Two-line `ABORT:` message names the other task
  number, its holding session, its heartbeat age, the stale threshold, and the overlapping path.
  Exit 1 — same exit code as the task-number refusal, no new exit-code class.
- **Stale overlapping foreign lock**: one-line `WARN:` to stderr; proceed with the acquire. The
  foreign lock is NEVER mutated by this check — it is read-only with respect to any lock
  directory other than the acquiring task's own.
- **Mutex fail-closed**: if the `specs/.scope-lock/` mutex cannot be acquired within its bounded
  retry window, exit 2 (the existing usage/task-not-found exit-code class) rather than silently
  skipping the scan.

`acquire`'s signature and its three possible exit codes (0/1/2) are unchanged by this check —
only the internal `cmd_acquire` logic gained a scan step, so every existing and future caller
inherits the behavior with zero call-site edits.

### `heartbeat <task_number> <session_id>`

Refresh `heartbeat_at` in place if the lock is held by the SAME session. If the lock is
missing, or held by a different session, this is a **no-op with a stderr warning** — heartbeat
never blocks or errors the caller; it is a best-effort refresh at existing checkpoints (the
`/orchestrate` cycle loop, `/implement` phase transitions), not a gate.

### `release <task_number> <session_id>`

Unconditionally removes `.lock/`. Idempotent: releasing an already-absent lock is success, not
an error. Success, partial, and failed skill outcomes ALL release — release is not conditioned
on the operation's own success, only on gate-out having run.

### `check <task_number>`

Diagnostic-only: prints the holder + staleness and exits with a code encoding
free / held-fresh / held-stale (see the script's own header comment for the exact exit-code
table; `check`'s exit codes are intentionally distinct from `acquire`/`heartbeat`/`release`'s,
since `check` is a query, not a gate).

### `init-marker <file_path>` (stdin = JSON content)

A generic, atomic-on-creation primitive for marker/state files elsewhere in the codebase that
use a TOCTOU-prone "check-then-create" `if [ -f X ]; then resume; else jq -n ... > X; fi` shape
(task 808). It is **file-granularity and composes independently of the task-number `.lock/`
directory documented above** — it is not a second locking mechanism, does not replace
`acquire`/`release`, and never reads, calls, or modifies `cmd_acquire`, `write_holder`, or
`.lock/`.

1. `mkdir "${file_path}.init"` as the atomic per-file exclusivity claim (POSIX-atomic, same
   `mkdir`-for-exclusivity idiom as `.lock/` above, but a distinct directory).
2. **`mkdir` success**: read the JSON payload from stdin, write it to `"${file_path}.tmp"`,
   guard against empty output (mirrors `write_holder`'s `[ ! -s ]` check), `mv` to `"$file_path"`
   (atomic replace), `rmdir "${file_path}.init"`, exit 0 — caller treats this as a fresh start.
3. **`mkdir` failure, valid target**: if `$file_path` exists and is valid JSON (`jq empty`),
   exit 1 — caller resumes from the existing file instead of clobbering it.
4. **`mkdir` failure, orphaned claim**: if the target is still absent or corrupt after a bounded
   recheck (a short poll window that distinguishes an actively-racing writer — expected under
   concurrency — from a claim abandoned by a crashed initializer), print a `WARN:` to stderr,
   `rmdir` the stale `.init` claim, and retry the claim once. If the retry also fails, exit 2.
   Self-heal is never silent and never permanent.
5. Usage/write errors exit 2.

Exit codes: `0` = created (fresh), `1` = already exists (resume from it), `2` = usage/write-error
or unresolved orphaned claim after one retry.

## Scope-Mutex CLI: `scope-acquire` / `scope-release`

This is a DISTINCT, orthogonal primitive from the task-number `.lock/` mechanism documented
above — it does not lock a task, it locks a critical section of `specs/state.json` writes that
may span MULTIPLE process invocations (e.g. an outer script bracketing several inner scripts'
state.json read-modify-write calls). It reuses `specs/.scope-lock/`, the same global mutex
`acquire`'s cross-task `file_scope` overlap scan already uses internally (see "Cross-Task
`file_scope` Overlap Check" above) — `scope-acquire`/`scope-release` simply expose that existing
internal primitive (`acquire_scope_mutex`/`release_scope_mutex`) as a standalone CLI surface,
rather than introducing a new script or a new lock directory.

A sibling primitive, `commit-acquire`/`commit-release`, serializes a DIFFERENT critical section
(the git add + git commit pair around scoped commits) through a DIFFERENT mutex directory,
`specs/.commit-lock/` — see "Commit-Mutex CLI: `commit-acquire` / `commit-release`" below for the
full contract. Both CLIs share the same underlying `acquire_named_mutex`/`release_named_mutex`
implementation (parameterized by mutex directory name) but are otherwise fully independent:
holding one never blocks or interacts with the other.

### `scope-acquire <session_id> [stale_sec]`

Acquires `specs/.scope-lock/`, writes an owner token (`session_id:pid:epoch`) to
`specs/.scope-lock/owner`, and prints that token on stdout. Exit `0` on success. On contention,
waits out the same bounded retry window `acquire`'s internal mutex use already relies on; on
timeout, exits `2` with a diagnostic naming the current holder (read from `owner`) — fail closed,
never fail open.

### `scope-release <token>`

Releases `specs/.scope-lock/` if, and only if, `<token>` matches the current
`specs/.scope-lock/owner` token. Always exits `0` — release is best-effort and must never fail a
caller's cleanup path. A mismatch (or a release against an already-absent mutex) is a loud,
non-fatal `WARN:` on stderr, never a silent no-op and never a forced removal.

**Caller requirement — install an EXIT trap immediately after a successful `scope-acquire`.**
Unlike `acquire`'s task-number lock (whose exclusivity lives and dies within a single function
call), `scope-acquire`'s mutex is meant to outlive the acquiring call and be released by a later,
separate `scope-release` invocation — so `scope-acquire` deliberately does not install any trap
of its own. This means the CALLER is responsible for guaranteeing release on every exit path
(normal completion, an early `return`/`exit`, or a `set -e` abort partway through the critical
section): install `trap 'bash .claude/scripts/task-lock.sh scope-release "$token"' EXIT`
immediately after a successful acquire, and explicitly release-and-clear-the-trap at the natural
end of the critical section so the mutex is not held for the remainder of the script's
unserialized tail. A script that already has its own EXIT trap for other cleanup (e.g.
`update-task-status.sh`'s pre-existing tmp-file removal) may instead extend that trap to also
call release, provided the release call itself is idempotent against being invoked twice (guard
it behind an "did I acquire and not yet release" flag) — both approaches are used by this
primitive's reference consumers below.

### Reentrancy: `SCOPE_MUTEX_HELD` Is the Sanctioned Way to Nest

The `specs/.scope-lock/` mutex is **NOT reentrant**. A process that already holds it — or is
running as a guest inside an outer holder's critical section — MUST NOT attempt a second
`scope-acquire`: the `mkdir` underneath would simply fail, and the process would wait out the
full contention window before warning and proceeding unserialized (best case), or deadlock if the
inner acquire happens inside the SAME process/call chain that already holds the mutex (worst
case, and the reason this guard exists at all). The sanctioned pattern for a script that may run
either standalone or nested inside an outer holder's critical section: the outer holder exports
`SCOPE_MUTEX_HELD=1` before invoking the inner script (environment variables propagate to child
processes, so this requires no separate lock-accounting mechanism); the inner script checks for
that variable and skips BOTH `scope-acquire` and `scope-release` entirely when it is already set,
logging a brief note that an outer holder owns the section. `.claude/scripts/update-task-status.sh`
and `.claude/scripts/orchestrator-postflight.sh` are the reference implementation of this pattern
(see "Consumers" below): postflight's Stage 7 shells out to `update-task-status.sh`, which would
otherwise attempt its own nested acquire on every single postflight run.

### Holder-Declared Staleness

Unlike `acquire`'s internal use of `acquire_scope_mutex` (which always relies on the default
`SCOPE_MUTEX_STALE_SEC` of 10 seconds, appropriate for a fast scan-then-mkdir sequence),
`scope-acquire` accepts an optional `stale_sec` argument for callers whose critical section is
knowingly longer-running. Staleness is **holder-declared, not waiter-declared**: the successful
acquirer writes its own chosen `stale_sec` into `specs/.scope-lock/stale_sec` alongside
`claimed_at`, and EVERY waiter — including a waiter carrying a different or default `stale_sec`
of its own — reads that file when deciding whether to reclaim the mutex as stale. This is
deliberate: if staleness were evaluated by the waiter against its own constant instead, a
short-window waiter could reclaim a still-live, longer-running holder's mutex out from under it,
producing two simultaneous live holders — the exact lost-update this primitive exists to prevent,
now harder to diagnose because it would appear as a `mkdir` succeeding cleanly rather than as a
refusal. When no `stale_sec` is passed (or an unparseable one is), the default
`SCOPE_MUTEX_STALE_SEC` (10) governs, which is why `acquire`'s pre-existing internal call site
(which passes no argument) is unaffected by this change.

### Owner-Token-Verified Release

Because `scope-acquire` and `scope-release` are separate process invocations (unlike
`acquire_scope_mutex`'s task-number-lock use, which acquires and releases within a single
function's lifetime), an unconditional `rm -rf` on release would be unsafe: if the holder was
stale-reclaimed by a waiter and a NEW holder acquired in the interim, the original holder's
release would delete the new holder's mutex out from under it. `scope-acquire` writes the owner
token described above; `scope-release <token>` compares its argument against that file and only
removes the mutex on an exact match, as described above.

### Consumers

- `.claude/scripts/update-task-status.sh` brackets its own state.json read-modify-write plus its
  `generate-todo.sh` call in the mutex when invoked standalone, and skips acquire/release entirely
  (guest mode) when `SCOPE_MUTEX_HELD` is already set by an outer holder.
- `.claude/scripts/orchestrator-postflight.sh` acquires the mutex immediately before its Stage 7
  (update task status), with a generous, holder-declared `stale_sec` sized to the measured
  worst-case wall-clock time of Stages 7 through 8a; exports `SCOPE_MUTEX_HELD=1` so Stage 7's
  `update-task-status.sh` child inherits the guard above instead of self-deadlocking; and releases
  explicitly at the close of Stage 8a (TODO.md regeneration). The TTS notification, git commit,
  and cleanup stages that follow run OUTSIDE the mutex — see
  `.claude/context/standards/git-staging-scope.md`'s state-write hazard note for why the boundary
  stops there.

### Relationship to the Task-Number Lock

As the "Related Documentation" cross-reference below already notes, the task-number `.lock/`
mechanism "does not change checkpoint behavior" — it only adds cross-session exclusivity around a
single task's working tree. The scope mutex documented in this section is a genuinely distinct,
orthogonal primitive: it protects the SHARED `specs/state.json` (and, transitively,
`specs/TODO.md`) write path that every task's postflight touches, regardless of which
task-number lock — if any — is held at the time. A session can hold its own task-number lock
while contending with another session for the scope mutex, and vice versa: the two mechanisms
compose independently, and neither substitutes for the other.

## Commit-Mutex CLI: `commit-acquire` / `commit-release`

A sibling standalone CLI to the Scope-Mutex CLI above, serializing a DIFFERENT critical section
through a DIFFERENT mutex directory: the `git add` + `git commit` pair around a scoped commit
(`specs/.commit-lock/`, versus the scope mutex's `specs/.scope-lock/` and the state.json
read-modify-write window it protects). `scripts/git-commit-scoped.sh` is the sole intended caller
— it is the single sanctioned implementation of scoped, serialized commits described in
`context/standards/git-staging-scope.md`'s "Commit-Level Path Scoping and Cross-Process
Serialization" section, and every commit site in the dispatch pipeline invokes it rather than
acquiring this mutex directly.

### Why a Distinct Mutex Directory, Not a Reuse of `.scope-lock`

The decisive reason is a reentrancy-flag collision, not merely call-frequency (though frequency
differs by an order of magnitude too: per-objective commits vs. per-postflight state writes,
which would make every state write queue behind unrelated commits under `MAX_TASKS=8` if the two
were coupled). `SCOPE_MUTEX_HELD=1` is a single global env flag meaning "an outer holder already
owns *the* scope mutex," and `update-task-status.sh`'s `acquire_state_mutex` skips its own
acquire when it sees that flag. If commit serialization shared `specs/.scope-lock/`, a commit
executed inside any window where `SCOPE_MUTEX_HELD` is already exported would either (a) honor
the flag and run **unserialized** — silently defeating the fix — or (b) ignore it and attempt a
nested acquire on a documented **non-reentrant** mutex. Two independent critical sections need two
independent held-flags, and two held-flags require two mutex directories regardless of frequency.

Reusing `.scope-lock` for commits would also **invert a deliberate, documented invariant**:
`orchestrator-postflight.sh` explicitly releases the scope mutex *before* Stage 9 (git commit),
and `git-staging-scope.md`'s "State-Write Serialization and Honest Commit Messages" section states
that Stage 9 stays outside the state-write mutex. Reusing `.scope-lock` for commits would make
Stage 9 acquire the exact mutex those documents say it must not — silently replacing a stated
invariant with its negation. A distinct mutex (`.commit-lock`) lets both statements stay true
simultaneously: Stage 9 is outside the **state-write** mutex and inside the **commit** mutex.

### `commit-acquire <session_id> [stale_sec]`

Acquires `specs/.commit-lock/`, writes an owner token (`session_id:pid:epoch`) to
`specs/.commit-lock/owner`, and prints that token on stdout. Exit `0` on success. On contention,
waits out a **15-second** acquire budget — three times the scope mutex's 5 seconds, sized for
`MAX_TASKS=8` concurrent committers rather than a single fast scan-then-mkdir sequence — then
exits `2` with a diagnostic naming the current holder (read from `owner`).

Unlike the scope mutex's fail-CLOSED contract, `git-commit-scoped.sh` (the sole intended caller)
treats a `commit-acquire` timeout as **fail-OPEN**: it logs a loud warning and proceeds with the
commit unserialized rather than aborting. This is safe specifically because the commit is still
path-scoped — the worst case on fail-open is the safe `index.lock` race (one commit fails, retried
once, or simply fails non-blockingly), never commit misattribution. Mirrors
`update-task-status.sh`'s `acquire_state_mutex` fail-open pattern for the scope mutex exactly.

### `commit-release <token>`

Releases `specs/.commit-lock/` if, and only if, `<token>` matches the current
`specs/.commit-lock/owner` token — identical owner-token-verified contract to `scope-release`
(see above). Always exits `0`; a mismatch is a loud, non-fatal `WARN:` on stderr, never a silent
no-op and never a forced removal.

### `COMMIT_MUTEX_HELD`: the Distinct Reentrancy Flag

Exported by `git-commit-scoped.sh` immediately after a successful `commit-acquire`, and checked
before attempting one — a script that already holds `.commit-lock` (or is running as a guest
inside an outer holder's critical section) skips its own acquire/release when it sees
`COMMIT_MUTEX_HELD=1` already set. This is the commit-mutex mirror of `SCOPE_MUTEX_HELD`
documented above, and the two flags are never interchangeable — see "Why a Distinct Mutex
Directory" above for the collision this independence prevents.

### Holder-Declared Staleness

`COMMIT_MUTEX_STALE_SEC=30`, declared by the acquiring process into
`specs/.commit-lock/stale_sec` exactly as the scope mutex declares its own staleness window (see
"Holder-Declared Staleness" above) — every waiter, regardless of its own default, honors the
holder's declared window. 30 seconds is generous against measured sub-second commits but short
enough to reclaim a genuinely stuck holder.

### Consumers

- `scripts/git-commit-scoped.sh` — the sole intended caller. Acquires immediately before its
  `git add` + optional honest-index-rows scan + `git commit` sequence, releases via an `EXIT`
  trap so no code path leaks the mutex.

## The ABORT Refusal Message

Modeled on the established two-line `ABORT:` + remedy shape already used by
`command-gate-in.sh`'s terminal-status guard and `guard-destructive-git.sh`'s blocked-command
message:

```
ABORT: Task {N} is locked by session {holder_session} (heartbeat {age} min ago; stale threshold {threshold} min).
  Wait for the lock to go stale, or override manually: rm -rf "{lock_dir}"
```

Naming the holding session, the heartbeat age, the threshold, and the manual `rm -rf` remedy in
one place means a blocked caller always has an actionable next step without needing to inspect
`holder.json` by hand.

The cross-task `file_scope` overlap ABORT (task 809) follows the same two-line shape, naming the
OTHER task instead of a same-numbered holder, plus the overlapping path:

```
ABORT: Task {N}'s file_scope overlaps task {other_task}'s file_scope at "{overlap_path}" and task {other_task} is locked by session {other_session} (heartbeat {age} min ago; stale threshold {threshold} min).
  Wait for task {other_task}'s lock to go stale, or coordinate with that session before retrying.
```

## Same-Session Re-Entry: The Critical Safety Property

Per the task 788 plan's own risk register, this is the **highest-impact risk**: a bug in the
session-identity check would block ALL task work system-wide, since `command-gate-in.sh` is
sourced by five command files (`/research`, `/plan`, `/implement`, `/revise`, `/orchestrate`).
The session-identity branch is checked FIRST, unconditionally, before any staleness computation
— a session re-acquiring its own lock (e.g. `/research 42` immediately followed by `/plan 42` in
the same conversation) always succeeds. This property has a dedicated functional test in Phase 5
of the task 788 plan and should never be weakened by future edits.

## Consumers (Two Distinct Wiring Paths)

1. **Single-task gate scripts**: `command-gate-in.sh` (acquire after the terminal-status guard)
   and `command-gate-out.sh` (unconditional release) — covers `/research`, `/plan`,
   `/implement`, `/revise`, and `/orchestrate`'s own single-task CHECKPOINT 1/2.
2. **Multi-task/wave dispatch**: `skill-orchestrate/SKILL.md` Stage MT (per-task
   acquire/release inside each wave dispatch) and `implement.md` Step 3 (per-task
   acquire/release in the multi-task loop) — these paths bypass the gate scripts entirely and
   need their own acquire/release bracketing. Heartbeat refresh is wired at existing natural
   checkpoints: `skill-orchestrate/SKILL.md`'s Stage 3 cycle loop (alongside the existing
   `.orchestrator-loop-guard` refresh) and `skill-implementer/SKILL.md`'s phase-transition point
   (alongside `update-phase-status.sh`).
3. **`init-marker` call sites** (task 808, file-granularity, independent of the two paths above):
   `skill-orchestrate/SKILL.md` Stage 2 (`.orchestrator-loop-guard` creation) and
   `skill-orchestrate-hard/SKILL.md` Stage 2 (`.orchestrator-loop-guard` AND
   `.orchestrator-churn-state.json` creation).

Both `.lock/`-based paths call the SAME `task-lock.sh` subcommands — never reimplemented inline —
so the two wiring paths cannot drift from each other's semantics.

## Non-Goals (Deferred Follow-Ups)

- ~~**`file_scope`-granular cross-task locking**: blocking `/implement 99` while `/implement 42`
  holds a lock when their `file_scope` arrays overlap (reusing `file-footprint-overlap.md`'s
  algorithm)~~ — CLOSED by task 809's cross-task `file_scope` overlap check (see "Cross-Task
  `file_scope` Overlap Check" above), which scans every held `.lock` across all task directories
  at acquire time via `find_held_locks`/`get_file_scope`/`scopes_overlap`, guarded by the
  `specs/.scope-lock/` mutex. This document's task-number lock and
  `file-footprint-overlap.md`'s directory-prefix overlap algorithm remain two DISTINCT
  mechanisms — acquire now composes both rather than merging them into one.
- ~~Atomic creation of `.orchestrator-loop-guard` was missing an exclusivity guard~~ — CLOSED by
  task 808's `init-marker` subcommand (see the Contract section above), which both
  `.orchestrator-loop-guard` creation sites (and `.orchestrator-churn-state.json`'s) now call.

## Related Documentation

- `.claude/scripts/task-lock.sh` — the implementation (acquire/heartbeat/release/check/init-marker,
  plus the scope-mutex and commit-mutex CLIs documented above)
- `.claude/scripts/git-commit-scoped.sh` — the sole intended caller of `commit-acquire`/
  `commit-release`; the single sanctioned implementation of scoped, serialized commits
- `.claude/context/standards/git-staging-scope.md` — "Commit-Level Path Scoping and Cross-Process
  Serialization" section documents the same contract from the caller's perspective
- `.claude/scripts/command-gate-in.sh` / `command-gate-out.sh` — single-task wiring
- `.claude/skills/skill-orchestrate/SKILL.md` — multi-task/wave wiring + heartbeat +
  `.orchestrator-loop-guard` `init-marker` call site
- `.claude/commands/implement.md` — multi-task Step 3 wiring
- `.claude/skills/skill-implementer/SKILL.md` — phase-transition heartbeat
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — `.orchestrator-loop-guard` and
  `.orchestrator-churn-state.json` `init-marker` call sites
- `checkpoint-before-overflow.md` — the git checkpoint procedure this lock composes with (a
  session holding the lock still checkpoints/commits exactly as before; the lock only adds
  cross-session exclusivity, it does not change checkpoint behavior)
- `file-footprint-overlap.md` — the directory-prefix overlap algorithm `acquire`'s cross-task
  `file_scope` check (task 809) reuses by reference; still a distinct document from this one —
  this file owns the lock contract, that file owns the overlap rule
