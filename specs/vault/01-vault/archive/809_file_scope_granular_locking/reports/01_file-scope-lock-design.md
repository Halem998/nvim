# Research Report: Task #809

**Task**: 809 - Extend task-lock.sh with file_scope-granular cross-task locking
**Started**: 2026-07-04T12:21:00Z
**Completed**: 2026-07-04T12:50:00Z
**Effort**: Medium (single-file logic extension + one doc update; no call-site changes required)
**Dependencies**: 787 (file_scope field + file-footprint-overlap.md algorithm), 788 (task-lock.sh + task-lock.md)
**Sources/Inputs**: Codebase read of `.claude/scripts/task-lock.sh`, `.claude/context/patterns/task-lock.md`, `.claude/context/patterns/file-footprint-overlap.md`, `.claude/context/reference/state-management-schema.md`, `.claude/context/patterns/multi-task-operations.md`, `.claude/commands/orchestrate.md`, `.claude/commands/implement.md`, `.claude/scripts/command-gate-in.sh`, `.claude/scripts/command-gate-out.sh`, `.claude/skills/skill-orchestrate/SKILL.md`, task 787/788 plans and reports, `specs/state.json` entries for tasks 808/809/810
**Artifacts**: - this report (`specs/809_file_scope_granular_locking/reports/01_file-scope-lock-design.md`)
**Standards**: report-format.md, artifact-formats.md, subagent-return.md

## Executive Summary

- `task-lock.sh` (788) is task-**number**-keyed only: `cmd_acquire` (lines 151-201) checks
  whether *this* task's own `.lock` directory is held, branching on same-vs-different
  `session_id` and fresh-vs-stale `heartbeat_at`. It never looks at any *other* task's lock or
  at `file_scope`. `task-lock.md` names this gap explicitly as "Non-Goals" (lines 158-166) and
  the 788 plan lists it as Follow-Up #1 (lines 415-421) — this is exactly task 809.
- `file_scope` (787) is a task-creation-time, optional `array of strings` field on each
  `active_projects[]` entry in `specs/state.json` (schema: `state-management-schema.md` lines
  208-224). The canonical directory-prefix overlap algorithm lives in
  `file-footprint-overlap.md` (exact-match, or either path is a `/`-prefix ancestor of the
  other) and today has exactly two callers — task-creation-time auto-dependency (787 Component
  4a) and `/orchestrate`'s in-batch runtime wave-split check (`orchestrate.md` lines 158-178) —
  **neither of which scans locks system-wide or protects independently-invoked commands**
  (e.g., two different terminals each running `/implement` on a different task number).
- **Recommendation**: add the overlap check *inside* `cmd_acquire`, before the existing
  own-task-number `mkdir`, scanning all *other* currently-held `.lock/holder.json` files under
  `specs/*/`. Fresh overlapping lock -> refuse (exit 1, new ABORT variant naming the other task).
  Stale overlapping lock -> warn-and-proceed *without* touching the other task's lock (a
  different flavor of "override" than same-task override, since it is not this task's lock to
  overwrite). This requires **zero changes to any call site** (`command-gate-in.sh`,
  `command-gate-out.sh`, `skill-orchestrate/SKILL.md`, `implement.md`, and 810's future
  `research.md`/`plan.md`/`revise.md` wiring) because `acquire`'s signature and exit-code
  contract (0/1/2) are unchanged — the new logic is entirely internal to `cmd_acquire`.
- A genuine TOCTOU race exists in a naive "scan-then-mkdir" implementation: two acquire calls
  for different, overlapping-scope tasks can both scan and see "no held overlap" before either
  has created its own lock directory, then both succeed. Closing this fully requires wrapping
  the scan-and-decide step in a short-lived global mutex (a second, much-shorter-lived
  `mkdir`-based lock at `specs/.scope-lock/`) — recommended as part of this design, not deferred,
  since leaving it open would undercut the task's own purpose.

## Context & Scope

Task 809 is the first of three coordinated follow-ups from task 788 (808: atomic marker-file
creation; 809: this task; 810: gate-script wiring into `/research`, `/plan`, `/revise`). The
user's explicit coordination note requires 809 to preserve `task-lock.sh`'s existing interface
so that 808's and 810's usage of it keeps working. This report scopes the change to
`.claude/scripts/task-lock.sh` (+ its `extensions/core` dual copy) and
`.claude/context/patterns/task-lock.md` (+ its dual copy), per task 809's stated goal of
composing 787's overlap algorithm with 788's locking. `file-footprint-overlap.md` itself is
**referenced, not modified** — task 809's `file_scope` lists it, but the algorithm is already
generic; task 809 only needs a jq transcription of it (no new normalization/overlap rule).

## Findings

### Codebase Patterns

**Current `task-lock.sh` structure** (`.claude/scripts/task-lock.sh`):
- `resolve_task_dir()` (lines 68-94): task_number -> `specs/{NNN}_{SLUG}` path, preferring
  `state.json`'s `project_name`, falling back to a filesystem glob. Directly reusable for
  resolving *other* task numbers found while scanning held locks.
- `write_holder()` / `read_holder_field()` (lines 107-134): tmp-file-rename write and single-field
  jq read of `holder.json`. `read_holder_field` is directly reusable for reading `session_id`,
  `task_number`, `heartbeat_at` off *any* lock directory, not just the caller's own.
- `age_minutes()` (lines 137-146): ISO8601 -> minutes-elapsed. Reusable verbatim for staleness of
  a foreign lock, using the *same* `TASK_LOCK_STALE_MIN` constant (line 63) — task 809's design
  should not introduce a second staleness constant for the "is a foreign lock still fresh"
  question; the 30-minute threshold is about "is this lock still meaningful for concurrency
  purposes" regardless of which task/session created it.
- `cmd_acquire()` (lines 151-201): the sole locus of change.
  - Lines 161-165: fresh `mkdir` success -> write holder, return 0.
  - Lines 168-174: lock dir exists but `holder.json` missing/corrupt -> treat as recoverable,
    overwrite, return 0.
  - Lines 176-186: **same-session re-entry** — session_id match checked FIRST, before any
    staleness computation, per the "highest-impact risk" callout in `task-lock.md` lines 132-140.
    Never self-blocks.
  - Lines 188-200: different-session branch — fresh (`age <= STALE_MIN`) refuses with the
    two-line `ABORT:` + remedy message (lines 192-193, template restated in `task-lock.md`
    lines 117-126); stale overrides with a `WARN:` message and overwrites `holder.json`
    (lines 197-199).
- Dispatch block (lines 291-330): thin `case` over `acquire|heartbeat|release|check`, each with
  a minimum-arg-count usage guard. **No new subcommand or argument is needed for 809** — the
  overlap check is additive logic inside `cmd_acquire`, invoked identically by every existing
  caller.

**`file_scope` location and semantics** (`state-management-schema.md` lines 55-70, 208-224;
`.claude/rules/state-management.md` lines 74-79):
- Optional `array of strings` on each `specs/state.json` `active_projects[]` entry, default `[]`.
- Prospective/anticipated, not filesystem-validated, never mutated by status-sync scripts.
- `state.json`-only — no `TODO.md` rendering, so no `generate-todo.sh` template change is
  implicated by this task.
- Explicitly contrasted with `modified_files`/`files_touched` (retrospective, self-reported by
  implementation agents) — task 809 must read `file_scope`, never `modified_files`.

**Overlap algorithm** (`file-footprint-overlap.md`, full file read):
- Normalize: strip trailing slash only (no filesystem resolution).
- Overlap iff: exact match, OR one path is a `/`-prefix ancestor of the other (directory-prefix
  containment; no glob/regex).
- Canonical pseudocode (lines 42-59) is the exact transcription target for a jq implementation.
- Two existing callers — task-creation-time auto-dependency (787 Component 4a) and
  `/orchestrate`'s **in-batch, already-collected-tasks-only** runtime wave-split check
  (`orchestrate.md` lines 158-178, mirrored in `skill-orchestrate/SKILL.md` line 622) — both
  explicitly scoped as "not a repo-wide scan" (`file-footprint-overlap.md` lines 91-97). Task 809
  is the first caller that scans repo-wide (across all currently-held `.lock` dirs), which
  `file-footprint-overlap.md`'s "Non-Goals" section anticipates as *out of that document's own
  scope* but does not forbid a caller from doing — task 809 does not modify
  `file-footprint-overlap.md`, only reuses its rule.
- 788's own plan (lines 415-421) already named this exact tradeoff: task-number locking is
  "the sufficient primary mechanism," and file_scope cross-task locking is explicitly framed as
  "requires scanning every held `.lock` across all task directories at acquire time — a real,
  bounded new cost 787's own wave-split check deliberately avoided." This confirms the acquire-time
  scan is the intended design, not an oversight to avoid.

**Call sites that must gain the behavior with zero code changes** (interface-preservation
constraint):
- `command-gate-in.sh` line 69: `task-lock.sh acquire "$task_number" "$operation" "$SESSION_ID" "/$operation $task_number"`.
- `skill-orchestrate/SKILL.md` line 671 (multi-task/wave dispatch): `acquire "$task_num" "$op" "${session_id}_${task_num}" "/orchestrate (multi-task)"` — note the **per-task session_id suffix**, meaning tasks in the *same* orchestrate batch already present as *distinct* `session_id`s to `task-lock.sh`. This is important: it means same-batch tasks will NOT hit a "same-session bypass" (see Edge Cases) even though a single orchestrate invocation is driving both.
- `implement.md` line 89 (multi-task loop): `acquire "$task_num" implement "${batch_session_id}_${task_num}" "/implement (multi-task)"` — same per-task-suffix pattern.
- `command-gate-out.sh` line 37 and the two release call sites above: unaffected, `release` needs
  no overlap logic (releasing your own lock never needs to know about anyone else's).
- Task 810 (not yet implemented) will add `research.md`/`plan.md`/`revise.md` as *additional*
  callers of the exact same `command-gate-in.sh`/`command-gate-out.sh` path — since 809's change
  lives inside `cmd_acquire` itself, 810 requires no awareness of 809's change at all.

**Dual-copy obligation**: `.claude/scripts/task-lock.sh` / `.claude/extensions/core/scripts/task-lock.sh`
and `.claude/context/patterns/task-lock.md` / `.claude/extensions/core/context/patterns/task-lock.md`
are currently byte-identical (`diff` confirmed clean on both pairs). Task 809's own declared
`file_scope` in `specs/state.json` (lines ~1279 region) lists only the non-`extensions/core`
paths plus `file-footprint-overlap.md` — **it omits the two `extensions/core` dual-copy targets**.
Task 808's `file_scope`, by contrast, explicitly lists both copies of the file it touches. This
is a gap the implementation plan should close (file_scope is descriptive/anticipated, not a hard
constraint on what a plan may touch — see Decisions below) so the 788-established parity
invariant is not silently broken.

### Recommendations

**1. New pure functions in `task-lock.sh`** (no interface change — internal helpers only):

- `get_file_scope(task_number)` — one jq call against `$STATE_FILE`:
  `jq -c --argjson num "$task_number" '.active_projects[]? | select(.project_number == $num) | .file_scope // [] // empty' "$STATE_FILE"`,
  defaulting to `[]` when the task/state file/jq is unavailable (mirrors `resolve_task_dir`'s own
  graceful-degradation style at lines 74-85). A **missing entry for a foreign task_number found
  during the scan must never abort the acquiring caller** — treat as `[]` (no protection for that
  stale/unresolvable lock), not as an error.
- `scopes_overlap(scope_a_json, scope_b_json)` — jq transcription of
  `file-footprint-overlap.md`'s pseudocode (rtrimstr `/`, exact-match-or-either-prefix), taking
  two JSON array arguments and returning (recommended) the first overlapping *foreign* path on
  stdout when found, empty stdout otherwise — this doubles as the boolean test (`[ -n "$out" ]`)
  and gives the ABORT/WARN messages a concrete path to name, consistent with `task-lock.md`'s own
  design principle that "a blocked caller always has an actionable next step" (line 128-130).
- `find_held_locks(exclude_dir)` — `find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 2 -type d -name .lock`
  filtered to exclude `exclude_dir` (the caller's own lock dir) and to skip any dir whose
  `holder.json` is missing/unreadable at scan time (best-effort; a lock mid-creation or
  mid-teardown by its own owner is not this caller's problem to solve — see Edge Cases).

**2. Insert the cross-task check into `cmd_acquire`, BEFORE the existing own-task `mkdir`**
(not after): resolve `task_dir`/`lock_dir` as today, then:

```
own_scope=$(get_file_scope "$task_number")
if [ "$own_scope" != "[]" ] && [ -n "$own_scope" ]; then
  for other_lock_dir in $(find_held_locks "$lock_dir"); do
    other_session=$(read_holder_field "$other_lock_dir" session_id)
    other_task=$(read_holder_field "$other_lock_dir" task_number)
    [ -z "$other_task" ] && continue                    # unreadable third-party lock: skip
    [ "$other_task" = "$task_number" ] && continue       # defensive: shouldn't happen, but skip
    [ "$other_session" = "$session_id" ] && continue     # same-session bypass (see Decisions)
    other_scope=$(get_file_scope "$other_task")
    overlap_path=$(scopes_overlap "$own_scope" "$other_scope")
    if [ -n "$overlap_path" ]; then
      other_heartbeat=$(read_holder_field "$other_lock_dir" heartbeat_at)
      age=$(age_minutes "$other_heartbeat")
      if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then
        echo "ABORT: Task $task_number's file_scope overlaps task $other_task's currently-held lock (session $other_session; heartbeat ${age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min) on path \"$overlap_path\"." >&2
        echo "  Wait for task $other_task's lock to release or go stale, or override manually: rm -rf \"$other_lock_dir\"" >&2
        return 1
      else
        echo "WARN: Task $task_number's file_scope overlaps task $other_task's lock (session $other_session; heartbeat ${age} min ago) on path \"$overlap_path\", but that lock is stale (> ${TASK_LOCK_STALE_MIN} min); proceeding. Task $other_task's lock is left untouched." >&2
      fi
    fi
  done
fi
# ... existing own-task mkdir logic, unchanged, follows here ...
```

Placing this *before* the own-task `mkdir` avoids ever needing to roll back a just-created own
lock on a cross-task refusal — the existing own-task logic (lines 161-201) is otherwise
untouched, byte-for-byte, preserving the interface exactly.

**3. Close the TOCTOU race with a short-lived global mutex.** As designed above, two acquire
calls for different, mutually-overlapping-scope tasks racing at the same instant can both
observe "no held overlap yet" before either has created its own `.lock` dir, and both succeed —
reintroducing exactly the class of race task 788's `mkdir` primitive exists to close, just at a
cross-task granularity. Recommend wrapping "scan other locks -> decide -> mkdir own lock" in a
brief `mkdir`-based mutex at a new top-level `specs/.scope-lock/` (sibling to task directories,
grep-confirmed unused today), acquired with a short bounded retry loop (e.g. 50ms sleep, ~5s
total timeout — this critical section is a handful of jq calls plus one `mkdir`, not a
long-held resource) and released immediately after `cmd_acquire` returns. Use a *much shorter*
staleness window for `.scope-lock` itself than `TASK_LOCK_STALE_MIN` (e.g. a few seconds) so a
crashed holder self-heals fast, since this mutex is meant to be held for milliseconds, never for
the duration of a `/research`/`/plan`/`/implement` invocation. If the global mutex cannot be
obtained within the timeout, fail with exit 2 (usage/error class, distinct from the exit-1
refusal class) rather than fail-open — a stuck `.scope-lock` indicates a bug, not legitimate
contention, and failing open would silently defeat the whole point of this task.

## Decisions

- **Same-session bypass extended to cross-task pairs**: if the *foreign* held lock's
  `session_id` equals the acquiring `session_id`, skip the overlap check for that pairing
  entirely (treat as if no overlap were found), extending 788's "a session cannot race itself"
  principle from same-task re-entry to cross-task pairs. Rationale: a single session is
  inherently sequential and cannot race itself. **Caveat surfaced by this research**: the two
  existing multi-task dispatch paths (`skill-orchestrate/SKILL.md` line 671, `implement.md` line
  89) already suffix `session_id` with `_${task_num}` per task, so tasks *within the same
  orchestrate/implement batch* present as distinct `session_id`s and will NOT hit this bypass —
  which is correct, since that is precisely the scenario (same batch, overlapping scope, missed
  by the wave-split check) this task-lock-level check exists to catch as defense-in-depth. The
  bypass only matters for the narrower case of a single un-suffixed session (e.g. a raw
  `/research 42` then, without releasing, some nested flow touching an overlapping task 43 under
  the same literal `$SESSION_ID`) — recommend confirming this bypass at plan time rather than
  silently assuming it; the stricter alternative (no bypass, cross-task always enforced
  regardless of session) is also viable and simpler to reason about, at the cost of a
  theoretical self-block in that narrow nested case.
- **Foreign stale locks are never touched, only bypassed.** Unlike same-task stale override
  (which overwrites `holder.json` because it *is* the acquiring session's own resource once
  claimed), a stale *foreign* lock's directory/holder.json is left exactly as-is — the acquiring
  task proceeds past it but does not `rm -rf` or rewrite it. Rationale: deleting another task's
  lock as a side effect of an unrelated task's acquire risks a nasty interaction if the
  "stale" holder's session is mid-heartbeat at that exact moment; leaving it alone means the
  foreign lock's own eventual heartbeat/release/override path (already correct per 788) is the
  only thing that ever mutates it.
- **No new subcommand, no new required argument, no new exit code class** beyond reusing
  existing 0/1/2 (`acquire`'s ABORT variant still returns 1; the new global-mutex-timeout failure
  returns 2, consistent with `resolve_task_dir` failures already using 2 for "could not proceed
  due to an environment/lookup problem" as opposed to "refused due to contention"). This is the
  key structural choice enabling zero call-site changes for 808/810.
- **`file-footprint-overlap.md` is referenced, not edited.** Task 809's jq transcription must
  stay faithful to the existing canonical pseudocode (lines 42-59); if a future change is needed
  to the overlap rule itself, it belongs in `file-footprint-overlap.md` and should be inherited
  by task 809's jq function, not forked.
- **Dual-copy scope gap**: recommend the implementation plan explicitly include
  `.claude/extensions/core/scripts/task-lock.sh` and
  `.claude/extensions/core/context/patterns/task-lock.md` as files to modify (kept byte-identical
  to their `.claude/` counterparts per the 788-established parity invariant), even though task
  809's current `file_scope` in `state.json` does not list them — `file_scope` is
  descriptive/anticipated per `state-management.md` line 74-76, not an enforced allowlist, so
  this is a documentation gap to flag, not a hard blocker.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| TOCTOU race between two concurrent acquires for different overlapping-scope tasks | Wrap scan-and-decide in the short-lived `specs/.scope-lock/` global mutex (see Recommendation 3); document the residual risk if this is descoped for a leaner v1 |
| Performance: scanning `specs/*/.lock/` on every acquire | Bounded by the number of *currently active* locks (typically 0-8, matching `MAX_TASKS` used elsewhere); each iteration is 2-3 cheap jq calls; acquire is not a hot loop (called once per command invocation, plus per-task in multi-task dispatch) |
| A foreign task's `state.json` entry vanishes/renames between scan and lookup | `get_file_scope` treats lookup failure as `[]` (no protection), never an error, so the acquiring caller's own acquire never breaks due to a foreign task's bad state |
| Cross-task check becomes overly strict and blocks legitimate unrelated concurrent work | `file_scope` is optional; tasks that don't declare it get no cross-task protection either direction — same graceful-degradation posture as the existing wave-split check; if it proves too aggressive, the ABORT branch can be relaxed to WARN-and-proceed by editing only `cmd_acquire`, mirroring the rollback note already on file for the wave-split check (`orchestrate.md` lines 176-178) |
| Same-session bypass masks a real same-batch race | Bypass only applies when `session_id` strings are literally equal; both existing multi-task dispatch paths already suffix per-task, so the bypass does not apply to the batch scenario that matters most — confirmed above under Decisions |
| Dual-copy drift (`.claude/` vs `extensions/core/`) | Explicitly call out both file pairs in the plan's Files-to-Modify list and re-run the same `diff -q` parity check pattern task 788 Phase 5 used |

## Context Extension Recommendations

- **Topic**: acquire-time repo-wide lock scanning pattern (as opposed to the two existing
  batch-scoped overlap callers).
- **Gap**: `file-footprint-overlap.md`'s "Consumers" section (lines 74-89) lists exactly two
  callers (task-creation Component 4a, and `/orchestrate`'s in-batch wave-split check). Once 809
  lands, task-lock.sh's `cmd_acquire` becomes a **third caller with a materially different
  scanning scope** (repo-wide `.lock` directories, not a single already-collected batch).
- **Recommendation**: at implementation time, add task-lock's acquire-time check as a third
  bullet under `file-footprint-overlap.md`'s "Consumers" section, and correspondingly narrow its
  "Non-Goals" bullet ("No repo-wide scan across all tasks in `state.json`") to clarify that the
  *algorithm itself* has no repo-wide-scan opinion — it is individual callers, not the shared
  algorithm doc, that choose their own scan scope. This keeps the canonical doc accurate once a
  third, differently-scoped consumer exists.

## Appendix

### Search queries / exploration used
- Direct reads: `task-lock.sh` (full), `task-lock.md` (full), `file-footprint-overlap.md` (full)
- `grep -n "file_scope"` across `.claude/rules/`, `.claude/context/`, `specs/state.json`
- Read `state-management.md` (55-105) and `state-management-schema.md` (55-90, 195-230)
- Read `multi-task-operations.md` (535-575) for the "File Footprint Overlap as a Serialization
  Edge" section and its same-batch/cross-batch distinction
- Read `orchestrate.md` (140-200) for the concrete runtime wave-split check design (the closest
  existing analog to this task's acquire-time check, but scoped to an already-collected batch)
- `grep -n "task-lock\|TASK_LOCK"` across `command-gate-in.sh`, `command-gate-out.sh`,
  `skill-orchestrate/SKILL.md`, `implement.md` to enumerate every call site
- `diff -q` on both `.claude/` vs `.claude/extensions/core/` dual-copy pairs (both clean)
- Read task 787 and 788 state.json descriptions/summaries; read 788's plan Follow-Up Tasks
  section (lines 405-421) confirming this task, 808, and 810 as its three named follow-ups
- Read `state.json` entries for tasks 808/809/810 (`file_scope`, `dependencies`, `description`)
  to verify batch coherence (dependency graph: 809 depends on [787, 788]; 810 depends on
  [788, 804, 809])

### References
- `.claude/scripts/task-lock.sh` (lines 1-331, especially `cmd_acquire` 151-201)
- `.claude/context/patterns/task-lock.md` (full; especially Non-Goals 158-171)
- `.claude/context/patterns/file-footprint-overlap.md` (full)
- `.claude/context/reference/state-management-schema.md` (55-90, 195-230)
- `.claude/rules/state-management.md` (74-79)
- `.claude/context/patterns/multi-task-operations.md` (535-575)
- `.claude/commands/orchestrate.md` (140-200)
- `.claude/scripts/command-gate-in.sh` (line 69), `.claude/scripts/command-gate-out.sh` (line 37)
- `.claude/skills/skill-orchestrate/SKILL.md` (lines 176-177, 622, 666-671, 716)
- `.claude/commands/implement.md` (lines 83-93)
- `specs/788_concurrent_session_lock_commit_cadence/plans/01_session-lock-commit-cadence.md`
  (lines 405-444, Follow-Up Tasks)
- `specs/state.json` (task 808/809/810 entries)
