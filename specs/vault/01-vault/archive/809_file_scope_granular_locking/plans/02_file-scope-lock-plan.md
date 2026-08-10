# Implementation Plan: Task #809

- **Task**: 809 - File-scope-granular cross-task locking (compose task 787 overlap with task 788 locks)
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: 787 (file_scope field + file-footprint-overlap.md algorithm), 788 (task-lock.sh + task-lock.md)
- **Research Inputs**: specs/809_file_scope_granular_locking/reports/01_file-scope-lock-design.md
- **Artifacts**: plans/02_file-scope-lock-plan.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

Extend `.claude/scripts/task-lock.sh` so that lock acquisition, in addition to the existing
task-number-keyed check, also refuses (or warns-and-proceeds) when the acquiring task's
`file_scope` overlaps the `file_scope` of any *other* currently-held lock. The overlap rule is
task 787's canonical directory-prefix algorithm (`file-footprint-overlap.md`), transcribed to jq;
the refuse/warn semantics extend task 788's fresh-refuse / stale-warn model to cross-task pairs
(a foreign lock is never mutated). All new logic lives **inside** `cmd_acquire` (plus internal
helper functions), so `acquire`'s signature and its 0/1/2 exit-code contract are unchanged and no
call site needs edits. A short-lived `specs/.scope-lock/` global mutex closes the scan-then-mkdir
TOCTOU race. Definition of done: the primary script enforces cross-task overlap correctly across
all edge cases, both `extensions/core` dual copies are byte-identical, and `task-lock.md` +
`file-footprint-overlap.md` reflect the new behavior.

### Research Integration

The single research report (`reports/01_file-scope-lock-design.md`) is fully integrated:
- **Recommendation 1** (three pure helpers: `get_file_scope`, `scopes_overlap`,
  `find_held_locks`) -> Phase 1.
- **Recommendation 2** (insert cross-task check before the own-task `mkdir`) and **Recommendation
  3** (global `specs/.scope-lock/` mutex around scan-and-decide) -> Phase 2.
- **Decisions** (same-session bypass on equal `session_id`; foreign stale locks bypassed but never
  touched; no new subcommand/exit-code class; `file-footprint-overlap.md` referenced not forked;
  dual-copy scope gap) -> woven through Phases 2, 4, 5.
- **Risks & Mitigations** and **Context Extension Recommendations** (add task-lock acquire-time
  scan as a third consumer of `file-footprint-overlap.md`) -> Phases 5 and the testing section.

### Prior Plan Reference

No prior plan for task 809. Task 788's plan (Follow-Up #1) named this task and confirmed the
acquire-time repo-wide scan as the intended design rather than an oversight; that framing is
carried into the phase decomposition below.

### Roadmap Alignment

No `roadmap_flag` was set for this dispatch and no ROADMAP.md consultation was requested. This
task is the second of three coordinated follow-ups from task 788 (808: init-marker subcommand;
809: this task; 810: gate-script wiring into `/research`, `/plan`, `/revise`).

### Coordinated-Batch Constraints (tasks 808 and 810)

- **Task 808** concurrently adds an init-marker subcommand to `task-lock.sh`. This plan must NOT
  restructure the file. All 809 edits are **insertions**: new helper functions added between the
  existing helpers (after `age_minutes`, before `cmd_acquire`) and additive logic inside
  `cmd_acquire` before the own-task `mkdir`. The `case` dispatch block (lines 294-331) is left
  untouched so 808's new subcommand case slots in without conflict.
- **Task 810** later wires the gate scripts into more commands. Because 809's change is entirely
  internal to `cmd_acquire` and preserves `acquire`'s signature and 0/1/2 exit codes, every
  existing and future caller (`command-gate-in.sh`, `skill-orchestrate/SKILL.md`, `implement.md`,
  and 810's future `research.md`/`plan.md`/`revise.md`) inherits the behavior with zero edits.

## Goals & Non-Goals

**Goals**:
- Add cross-task `file_scope` overlap enforcement inside `cmd_acquire`: fresh overlapping foreign
  lock -> refuse (exit 1); stale overlapping foreign lock -> warn and proceed (exit 0), leaving
  the foreign lock untouched.
- Transcribe `file-footprint-overlap.md`'s pseudocode faithfully to jq (rtrimstr `/`, exact-match
  or either-side directory-prefix); do not fork or restate the rule.
- Close the scan-then-mkdir TOCTOU race with a short-lived `specs/.scope-lock/` mutex.
- Preserve `acquire`'s signature and 0/1/2 exit-code contract exactly (zero call-site changes).
- Keep both `.claude/` and `.claude/extensions/core/` copies of `task-lock.sh` and `task-lock.md`
  byte-identical; update `task-lock.md` and `file-footprint-overlap.md` to reflect the new
  behavior/consumer.

**Non-Goals**:
- No new subcommand, no new required argument, no new exit-code class (reuse 0/1/2). 808 owns the
  new init-marker subcommand.
- No modification of the overlap rule itself in `file-footprint-overlap.md` (algorithm is
  referenced, only its "Consumers"/"Non-Goals" prose is updated).
- No glob/regex matching; only literal directory-prefix containment.
- No mutation of a foreign task's lock directory or `holder.json`.
- No edits to any call site, to `generate-todo.sh`, or to `modified_files`/`files_touched` logic.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Accidental restructure of `task-lock.sh` collides with task 808's concurrent edit | H | M | Insert-only edits at stable anchors; never move `cmd_acquire` or the `case` block; verify `git diff` shows only additions in the helper region and inside `cmd_acquire` |
| TOCTOU: two overlapping-scope acquires both see "no held overlap" before either mkdirs | H | M | Wrap scan-and-decide + own `mkdir` in the `specs/.scope-lock/` mutex (Phase 2); test the race scenario (Phase 3) |
| Stuck `.scope-lock` fails open, silently defeating the whole feature | H | L | Fail **closed** with exit 2 on mutex-acquire timeout; give `.scope-lock` a few-second self-heal staleness window, far shorter than `TASK_LOCK_STALE_MIN` |
| Foreign task's state.json entry missing/renamed mid-scan aborts the caller | M | M | `get_file_scope` returns `[]` (no protection) on any lookup failure, never an error |
| jq transcription drifts from the canonical overlap rule | M | L | Mirror pseudocode lines 43-59 exactly; add a directed test comparing known overlap/non-overlap pairs (Phase 3) |
| Dual-copy drift between `.claude/` and `extensions/core/` | M | M | Mirror mechanically and re-run `diff -q` on both file pairs (Phases 4, 5) |
| Same-session bypass masks a real same-batch race | M | L | Bypass only on literally equal `session_id`; multi-task dispatch already suffixes `_${task_num}`, so batch tasks present distinct sessions and are still enforced; confirm with a test |
| Overlap check too aggressive, blocks legitimate unrelated work | M | L | `file_scope` optional -> tasks without it get no protection either direction; ABORT branch is a one-line edit away from WARN if it proves too strict |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |

Phases within the same wave can execute in parallel. Phases 4 and 5 touch disjoint files
(Phase 4: `task-lock.sh` dual copy; Phase 5: `task-lock.md` + `file-footprint-overlap.md` dual
copies) and are territory-safe to run concurrently.

### Phase 1: Add pure helper functions to task-lock.sh [COMPLETED]

**Goal**: Introduce the internal helper functions the cross-task check depends on, without yet
changing any acquire behavior. Purely additive; script behaves identically until Phase 2.

**Tasks**:
- [x] In `.claude/scripts/task-lock.sh`, add helpers in the region after `age_minutes()`
      (line 146) and before `cmd_acquire()` (line 151), so `cmd_acquire`'s position and the
      `case` dispatch block are untouched (808 coordination). *(deviation: altered — anchored
      by function name, not the stale literal line numbers, because task 808 landed
      concurrently and shifted them; see progress file phase-1 deviations)*
- [x] Add `get_file_scope(task_number)`: single jq call against `$STATE_FILE` returning the
      compact JSON `file_scope` array, defaulting to `[]` when the state file, jq, or the task
      entry is unavailable (mirror `resolve_task_dir`'s graceful-degradation style). A missing
      foreign entry MUST resolve to `[]`, never a non-zero exit that could break the caller.
      *(completed)*
- [x] Add `scopes_overlap(scope_a_json, scope_b_json)`: jq transcription of
      `file-footprint-overlap.md` pseudocode (lines 43-59) — `rtrimstr("/")` normalization, then
      overlap iff exact match OR either path is a `/`-prefixed ancestor of the other. Emit the
      first overlapping foreign path on stdout when found (empty stdout otherwise), so callers use
      `[ -n "$out" ]` as the boolean test and reuse the path in messages. *(completed)*
- [x] Add `find_held_locks(exclude_dir)`:
      `find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 2 -type d -name .lock`, excluding
      `exclude_dir` and skipping any dir whose `holder.json` is missing/unreadable. *(completed)*
- [x] Add mutex helpers `acquire_scope_mutex()` / `release_scope_mutex()` operating on
      `$PROJECT_ROOT/specs/.scope-lock/` via `mkdir`: bounded retry loop (~50ms sleep, ~5s total
      timeout); treat an existing `.scope-lock` older than a few seconds as stale and reclaim it;
      `acquire_scope_mutex` returns non-zero on timeout. Define the short staleness window as a
      named constant distinct from `TASK_LOCK_STALE_MIN` (e.g. `SCOPE_MUTEX_STALE_SEC=10`).
      *(completed)*
- [x] Do NOT modify `cmd_acquire`, the `case` block, or any existing helper in this phase.
      *(completed: verified via `git diff -U1` — the only hunk in the helper region is the new
      insertion; init-marker-related hunks elsewhere belong to task 808)*

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/task-lock.sh` - add 5 helper functions (~60-90 lines) in the helper region.

**Verification**:
- [x] `bash -n .claude/scripts/task-lock.sh` passes (syntax). *(confirmed)*
- [x] Sourcing the script and calling `scopes_overlap '[".claude/scripts"]' '[".claude/scripts/task-lock.sh"]'` prints the overlapping path; `scopes_overlap '[".claude/a"]' '[".claude/b"]'` prints nothing; `scopes_overlap '[]' '["x"]'` prints nothing. *(confirmed — all three match expected output)*
- [x] `get_file_scope 809` returns the task's declared array; `get_file_scope 999999` (nonexistent) returns `[]` and exit 0. *(confirmed — task 809 currently has no `file_scope` declared in state.json, so it also returns `[]`, which is the documented graceful-degradation behavior, not a bug)*
- [x] `git diff` shows only additions between line 146 and 151; `cmd_acquire` and the `case` block unchanged. *(confirmed via `git diff -U1`, adjusted for 808's line shift — see deviation above)*

---

### Phase 2: Integrate cross-task overlap check into cmd_acquire [COMPLETED]

**Goal**: Wire the helpers into `cmd_acquire` before the own-task `mkdir`, wrapped in the global
mutex, preserving the signature and 0/1/2 exit contract.

**Tasks**:
- [x] In `cmd_acquire`, after `lock_dir` is resolved (line 159) and before the own-task
      `mkdir "$lock_dir"` (line 161), acquire the global mutex via `acquire_scope_mutex`; on
      timeout, print an error and `return 2` (fail closed — a stuck mutex is a bug, not
      contention; never fail open). *(completed: line numbers shifted per Phase 1's deviation
      note; anchored by the same `lock_dir="$task_dir/.lock"` / `mkdir "$lock_dir"` statements)*
- [x] Inside the mutex critical section, compute `own_scope=$(get_file_scope "$task_number")`.
      Only if `own_scope` is non-empty and not `[]`, iterate `find_held_locks "$lock_dir"`:
  - Read `other_task` and `other_session` from each foreign lock; `continue` if `other_task` is
    empty (unreadable), equals `$task_number` (defensive), or `other_session` equals
    `$session_id` (same-session bypass per report Decisions).
  - `other_scope=$(get_file_scope "$other_task")`; `overlap_path=$(scopes_overlap "$own_scope" "$other_scope")`.
  - If `overlap_path` non-empty: compute foreign lock age from its `heartbeat_at`. Fresh
    (`age <= TASK_LOCK_STALE_MIN`) -> print the two-line `ABORT:` message naming the other task,
    session, age, threshold, and `overlap_path`; release the mutex; `return 1`. Stale -> print a
    one-line `WARN:` stating the foreign lock is stale and left untouched; continue scanning.
    *(completed)*
- [x] After the scan (no fresh overlap found), perform the existing own-task `mkdir`/holder logic
      (lines 161-201) unchanged, still inside the mutex; release the mutex on every return path
      (fresh acquire, recoverable overwrite, same-session re-entry, stale self-override, and the
      exit-1/exit-2 paths). Prefer a single `release_scope_mutex` at each `return` or a trap so no
      path leaks the mutex. *(completed: used `trap 'release_scope_mutex' RETURN` set immediately
      after the mutex is acquired — empirically verified in bash that a function-scoped RETURN
      trap fires exactly once, on that function's own return, regardless of which return
      statement executes or which nested functions it calls in between; this covers every exit
      path without touching the pre-existing own-task branches)*
- [x] Do NOT mutate any foreign lock dir or `holder.json`; the cross-task branch only reads them.
      *(completed: confirmed via `git diff` grep — the only new `rm`/`mv`/`rmdir` targets are
      `$mutex_dir` (specs/.scope-lock); no `write_holder` call was added)*
- [x] Keep the existing own-task logic byte-identical aside from the mutex release calls; do not
      renumber or reorder its branches. *(completed — existing branches are byte-identical; the
      trap approach required zero edits to them, not even a release call)*

**Timing**: ~1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/task-lock.sh` - insert the cross-task block into `cmd_acquire`; add mutex
  acquire/release around the critical section.

**Verification**:
- [x] `bash -n .claude/scripts/task-lock.sh` passes. *(confirmed)*
- [x] Signature/exit contract unchanged: usage guard for `acquire` still requires 3+ args and
      exits 2; a fresh same-session re-acquire still returns 0. *(confirmed: `acquire` with 0
      and 2 args both exit 2 with the usage message; full acquire-flow re-entry confirmed in
      Phase 3's sandbox)*
- [x] No `rm`/`mv`/`write_holder` targets a foreign `lock_dir` anywhere in the new code
      (`grep` the diff to confirm the cross-task branch is read-only w.r.t. foreign locks).
      *(confirmed via `git diff | grep`)*
- [x] After any early `return`, `specs/.scope-lock/` is not left behind (mutex always released).
      *(confirmed structurally via the RETURN-trap test above; exercised end-to-end, including
      the ABORT early-return path, in Phase 3's sandbox)*

---

### Phase 3: Behavioral test scenarios (sandbox) [COMPLETED]

**Goal**: Validate the primary script against every edge case in the research report before
mirroring to the dual copy.

**Tasks**:
- [x] Build a throwaway sandbox in the scratchpad dir mirroring `PROJECT_ROOT` layout: a temp root
      containing a copy of `task-lock.sh` at `<root>/.claude/scripts/`, a `<root>/specs/` tree with
      two task directories (e.g. `010_alpha`, `011_beta`), and a minimal `<root>/specs/state.json`
      whose two entries carry overlapping `file_scope`, plus a third `012_gamma` with a
      non-overlapping scope. This keeps all tests off the live repo (STATE_FILE derives from the
      script's own location). *(completed: sandbox built under the scratchpad dir at
      `809-sandbox/`, matching the spec exactly)*
- [x] **Overlap refusal**: acquire task 10 (session S1), then acquire task 11 (session S2, fresh
      overlapping scope) -> exit 1, ABORT message names task 10 and the overlap path. *(confirmed)*
- [x] **Non-overlap allowed**: with task 10 held, acquire task 12 (non-overlapping) -> exit 0.
      *(confirmed)*
- [x] **Stale-overlap warn-and-proceed**: hand-edit task 10's `holder.json` `heartbeat_at` to be
      older than `TASK_LOCK_STALE_MIN`, acquire task 11 -> exit 0 with WARN; assert task 10's
      `.lock/holder.json` is byte-identical afterward (foreign lock untouched). *(confirmed via
      md5sum before/after)*
- [x] **Empty file_scope**: give task 11 `file_scope: []`; with task 10 held -> exit 0 (no
      protection, no ABORT), both directions. *(confirmed both directions)*
- [x] **Same-session bypass**: acquire task 10 (session S1), then acquire task 11 with the *same*
      literal session S1 and overlapping scope -> exit 0 (bypassed). Then repeat with S1 suffixed
      `_11` vs `_10` (the multi-task dispatch pattern) -> exit 1 (enforced). *(confirmed both
      sub-cases)*
- [x] **TOCTOU mutex**: launch two overlapping-scope acquires as near-simultaneous background
      processes; assert exactly one succeeds (exit 0) and the other refuses (exit 1), never both.
      *(confirmed across 6 total trials — 1 initial + 5 repeated — all exactly-one-succeeds, no
      `.scope-lock` leaked afterward)*
- [x] **Mutex fail-closed**: pre-create `<root>/specs/.scope-lock/` fresh (< staleness window) and
      hold it; an acquire times out and returns 2 (not 0, not 1). *(confirmed: ~6s timeout, exit 2,
      pre-existing fresh mutex left untouched — not stolen since it wasn't stale)*
- [x] Record the scenario -> observed exit/message mapping in the implementation summary.
      *(completed — see summary)*
- [x] **Additional regression coverage** (not separately enumerated above but run per the
      Testing & Validation checklist): fresh same-session re-entry (exit 0), different-session
      fresh same-task refusal (exit 1), different-session stale same-task override (exit 0) —
      all confirmed intact and byte-identical in behavior to pre-809 acquire.

**Timing**: ~1 hour

**Depends on**: 2

**Files to modify**:
- None in the repo (sandbox only, under the scratchpad dir). No changes to `specs/state.json` or
  live task directories.

**Verification**:
- [x] All eight scenarios above produce the expected exit code and message. *(confirmed — see
      the scenario table in the implementation summary)*
- [x] The live repo's `specs/` is unmodified after the test run (no stray `.lock` or `.scope-lock`
      dirs; `git status specs/` clean aside from this task's own artifacts). *(confirmed: `find`
      for stray `.lock`/`.scope-lock` under the live `specs/` returned nothing; `git status
      specs/` shows only pre-existing, unrelated changes from other in-flight tasks)*

---

### Phase 4: Mirror task-lock.sh to extensions/core and address dual-copy scope gap [COMPLETED]

**Goal**: Restore byte-identical dual-copy parity for the script and flag the state.json
`file_scope` declaration gap.

**Tasks**:
- [x] Copy the finalized `.claude/scripts/task-lock.sh` to
      `.claude/extensions/core/scripts/task-lock.sh` (mechanical mirror; do not hand-edit the
      copy). *(completed)*
- [x] Confirm parity with `diff -q` (see Verification). *(confirmed)*
- [ ] Address the file_scope declaration gap (report Decisions): task 809's `file_scope` in
      `specs/state.json` omits the two `extensions/core` dual-copy targets. `file_scope` is
      descriptive, not an enforced allowlist, so touching these files is legitimate. The
      implementer MAY, for parity with task 808 (which lists both copies), append
      `.claude/extensions/core/scripts/task-lock.sh` and
      `.claude/extensions/core/context/patterns/task-lock.md` to task 809's `file_scope` in
      state.json at implement time; if so, follow the state-first update pattern
      (`jq` edit then `generate-todo.sh`). This is an optional consistency improvement, explicitly
      called out here so the parity invariant is not silently broken. *(deviation: skipped — this
      dispatch's delegation context explicitly instructs "Do NOT modify specs/state.json or
      specs/TODO.md (orchestrator handles status)"; this optional item was attempted, then
      reverted cleanly via `jq` back to the original 3-entry `file_scope` array plus a
      `generate-todo.sh` re-run, once the conflict with that instruction was recognized. Verified
      via `git diff | grep -i extensions/core` that no trace remains in either file. The
      orchestrator or a follow-up may still apply this optional parity improvement outside this
      dispatch.)*

**Timing**: ~20 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/core/scripts/task-lock.sh` - mirror of the primary.
- `specs/state.json` - optional `file_scope` parity update (implement-time only; not part of this
  planning dispatch).

**Verification**:
- [x] `diff -q .claude/scripts/task-lock.sh .claude/extensions/core/scripts/task-lock.sh` reports
      no differences. *(confirmed)*
- [x] If state.json was updated, `bash .claude/scripts/generate-todo.sh` regenerated TODO.md and
      `jq . specs/state.json` still parses. *(N/A — the optional state.json update was reverted
      per the deviation above; state.json was left in its pre-dispatch shape, confirmed still
      valid JSON)*

---

### Phase 5: Update task-lock.md and file-footprint-overlap.md docs (both dual copies) [COMPLETED]

**Goal**: Bring the spec docs in line with the new cross-task behavior and register the new
consumer of the overlap algorithm.

**Tasks**:
- [x] In `.claude/context/patterns/task-lock.md`, add a section describing the cross-task
      `file_scope` overlap check inside `acquire`: fresh-overlap refuse (exit 1), stale-overlap
      warn-and-proceed (exit 0, foreign lock untouched), same-session bypass, `[]`/missing-scope
      no-op, and the `specs/.scope-lock/` mutex with fail-closed exit 2 on timeout. Update the
      `acquire` exit-code prose (lines ~80-96) and the "Non-Goals (Deferred Follow-Ups)" section
      (line 158) to reflect that this follow-up is now implemented. *(completed: added a
      dedicated "Cross-Task `file_scope` Overlap Check" subsection, updated the `acquire`
      numbered steps to include the mutex/scan step, updated Scope, updated Non-Goals with a
      `~~strikethrough~~ CLOSED` entry matching the doc's existing style for closed follow-ups)*
- [x] Keep the ABORT message template section (line 117) consistent with the cross-task ABORT
      wording used in the script. *(completed: added the cross-task ABORT template directly below
      the existing task-number one, using the exact wording the script emits)*
- [x] In `.claude/context/patterns/file-footprint-overlap.md`, add a third bullet under
      "Consumers" (line 74) for task-lock's acquire-time repo-wide scan, and narrow the "Non-Goals"
      repo-wide-scan bullet (line 95) to clarify the *algorithm* has no scan-scope opinion — each
      caller chooses its own scope. Do NOT change the pseudocode/normalization/overlap rule.
      *(completed; confirmed via `git diff | grep` that the pseudocode block itself is
      byte-unchanged)*
- [x] Mirror `task-lock.md` to `.claude/extensions/core/context/patterns/task-lock.md`
      (mechanical copy). `file-footprint-overlap.md` has no `extensions/core` dual copy to mirror
      (confirm via `find` before assuming; if one exists, mirror it too). *(deviation: altered —
      `find` DID locate an existing `extensions/core` dual copy of `file-footprint-overlap.md`,
      contrary to the plan's assumption; mirrored it too, mechanically, alongside `task-lock.md`)*

**Timing**: ~40 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/context/patterns/task-lock.md` - cross-task section + exit-code/Non-Goals updates.
- `.claude/extensions/core/context/patterns/task-lock.md` - mirror.
- `.claude/context/patterns/file-footprint-overlap.md` - Consumers + Non-Goals prose only.

**Verification**:
- [x] `diff -q .claude/context/patterns/task-lock.md .claude/extensions/core/context/patterns/task-lock.md` reports no differences. *(confirmed)*
- [x] `task-lock.md` no longer lists cross-task file_scope locking as a deferred non-goal.
      *(confirmed — it is now a `~~strikethrough~~ CLOSED` entry, matching the doc's own
      convention for the 808 closure immediately below it)*
- [x] `file-footprint-overlap.md` lists three consumers; pseudocode block is byte-unchanged.
      *(confirmed both — and its own `extensions/core` dual copy also mirrored and verified
      with `diff -q`)*

## Testing & Validation

- [ ] `bash -n` clean on both copies of `task-lock.sh`.
- [ ] Overlap-refusal scenario: fresh overlapping foreign lock -> exit 1 with ABORT naming the
      other task and overlap path.
- [ ] Stale-lock scenario: stale overlapping foreign lock -> exit 0 with WARN; foreign
      `holder.json` byte-identical afterward.
- [ ] Empty/missing `file_scope` -> no cross-task protection, exit 0.
- [ ] Same-session bypass: equal `session_id` bypasses; `_${task_num}`-suffixed sessions are
      enforced.
- [ ] TOCTOU: two concurrent overlapping acquires -> exactly one succeeds.
- [ ] Mutex fail-closed: held `.scope-lock` -> acquire returns 2.
- [ ] Regression: existing task-number semantics intact (fresh same-session re-entry exit 0;
      different-session fresh same-task exit 1; different-session stale same-task override exit 0).
- [ ] Dual-copy parity: `diff -q` clean on both `task-lock.sh` and `task-lock.md` pairs.
- [ ] Live `specs/` untouched by testing (no stray `.lock`/`.scope-lock`).

## Artifacts & Outputs

- `.claude/scripts/task-lock.sh` (modified) and `.claude/extensions/core/scripts/task-lock.sh`
  (mirrored).
- `.claude/context/patterns/task-lock.md` (modified) and
  `.claude/extensions/core/context/patterns/task-lock.md` (mirrored).
- `.claude/context/patterns/file-footprint-overlap.md` (Consumers/Non-Goals prose updated).
- Optional: `specs/state.json` `file_scope` parity update for task 809.
- `specs/809_file_scope_granular_locking/summaries/02_file-scope-lock-summary.md` (on completion).

## Rollback/Contingency

- All changes are additive/insert-only; revert via `git checkout -- <file>` on the five files
  above (no schema migrations, no state mutations beyond the optional file_scope note).
- If the cross-task check proves too aggressive in practice, relax the ABORT branch to
  WARN-and-proceed by editing only the single branch in `cmd_acquire` (mirroring the rollback note
  already on file for `/orchestrate`'s wave-split check), then re-mirror to `extensions/core`.
- If the `.scope-lock` mutex proves problematic, it can be reduced to a shorter timeout or (last
  resort) descoped by removing the wrap while keeping the read-only cross-task scan — but note the
  residual TOCTOU risk this reintroduces.
