# Task Lock Pattern

Canonical, single-source definition of the per-task concurrency lock used to prevent two
Claude Code sessions from silently clobbering the same shared working tree (task 788; the 427
failure: an uncommitted in-progress task wiped by a second session working the same task
number). Every consumer (gate scripts, `skill-orchestrate`, `implement.md`,
`skill-implementer`) references this document and `.claude/scripts/task-lock.sh` by path and
never restates or reimplements the acquire/heartbeat/release/check logic inline.

**Related**: `.claude/scripts/task-lock.sh` (the implementation), `checkpoint-before-overflow.md`
(git checkpoint procedure this lock composes with), `file-footprint-overlap.md` (a related but
DISTINCT overlap algorithm — see Non-Goals below), `.claude/context/standards/git-staging-scope.md`.

## Scope

This lock is **task-number-keyed**, not `file_scope`-granular: it prevents two sessions from
both working task N at once. It does NOT detect or block two sessions working two DIFFERENT
tasks whose declared `file_scope` overlaps — that is a separate, deferred concern (see
Non-Goals).

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

## Contract: acquire / heartbeat / release / check

All four subcommands are implemented exactly once in `.claude/scripts/task-lock.sh`. Call sites
NEVER reimplement lock logic inline (no ad hoc `mkdir .lock` elsewhere in the codebase).

### `acquire <task_number> <operation> <session_id> [command]`

1. Resolve the task directory (`specs/{NNN}_{SLUG}/`, preferring `state.json`'s
   `project_name`, falling back to a filesystem glob).
2. `mkdir "$TASK_DIR/.lock"`.
   - **Success** (directory did not exist): write `holder.json`, exit 0. Fresh acquire.
3. **`mkdir` failure** (directory already exists): read the existing `holder.json` and branch
   on `session_id` FIRST, before ever considering staleness:
   - **Same `session_id`** (the CRITICAL, highest-impact case — see below): refresh
     `heartbeat_at` in place, preserve `acquired_at`, exit 0. Same-session re-entry NEVER
     self-blocks, regardless of staleness.
   - **Different `session_id`, fresh** (`heartbeat_at` within `TASK_LOCK_STALE_MIN`): refuse.
     Print the two-line `ABORT:` + remedy message (see below) to stderr, exit 1.
   - **Different `session_id`, stale** (`heartbeat_at` older than the threshold): print the
     visible override-and-warn message to stderr, overwrite `holder.json` for the new session,
     exit 0. Never a silent steal, never a permanent refusal.

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

Both paths call the SAME `task-lock.sh` subcommands — never reimplemented inline — so the two
wiring paths cannot drift from each other's semantics.

## Non-Goals (Deferred Follow-Ups)

- **`file_scope`-granular cross-task locking**: blocking `/implement 99` while `/implement 42`
  holds a lock when their `file_scope` arrays overlap (reusing `file-footprint-overlap.md`'s
  algorithm). This lock is task-number-keyed only; cross-task overlap detection would require
  scanning every held `.lock` across all task directories at acquire time — a materially larger,
  separately scoped follow-up. Do not conflate this document's task-number lock with
  `file-footprint-overlap.md`'s directory-prefix overlap algorithm; they solve different
  problems and are not merged here.
- **Atomic-creation guard for `.orchestrator-loop-guard`**: that file is still written via the
  non-atomic `jq -n > file` pattern with no `mkdir`-style exclusivity guard. A real, pre-existing
  gap, left untouched by this lock — a candidate follow-up could reuse this script's `mkdir`
  primitive.

## Related Documentation

- `.claude/scripts/task-lock.sh` — the implementation (acquire/heartbeat/release/check)
- `.claude/scripts/command-gate-in.sh` / `command-gate-out.sh` — single-task wiring
- `.claude/skills/skill-orchestrate/SKILL.md` — multi-task/wave wiring + heartbeat
- `.claude/commands/implement.md` — multi-task Step 3 wiring
- `.claude/skills/skill-implementer/SKILL.md` — phase-transition heartbeat
- `checkpoint-before-overflow.md` — the git checkpoint procedure this lock composes with (a
  session holding the lock still checkpoints/commits exactly as before; the lock only adds
  cross-session exclusivity, it does not change checkpoint behavior)
- `file-footprint-overlap.md` — a related but distinct overlap algorithm (cross-task file-scope
  overlap, NOT this document's task-number lock)
