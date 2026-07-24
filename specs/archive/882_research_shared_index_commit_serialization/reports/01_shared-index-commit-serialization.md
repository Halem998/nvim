# Research Report: Task #882

**Task**: 882 - Decide whether shared-index commits need serialization (research-first)
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T00:00:00Z
**Effort**: research
**Dependencies**: None
**Sources/Inputs**: - Codebase (`.claude/scripts/orchestrator-postflight.sh`, `.claude/scripts/task-lock.sh`, `.claude/scripts/generate-todo.sh`, `.claude/scripts/update-task-status.sh`, `.claude/context/standards/git-staging-scope.md`, `.claude/context/patterns/task-lock.md`), git history archaeology (`git log`/`git show` across ~400 commits touching `specs/state.json`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The mechanism described in the task is verified exactly as stated: `orchestrator-postflight.sh`
  Stage 9 unconditionally stages `specs/TODO.md` and `specs/state.json` alongside the task
  directory; `generate-todo.sh` regenerates TODO.md wholesale from ALL `active_projects` in
  `state.json`; `task-lock.sh` locks are per-task and never gate the commit path.
- The narrower question the task poses — "is a commit that carries other tasks' *already-landed*
  TODO.md/state.json rows corrupt or just cosmetically noisy?" — resolves to **benign**. Both
  files legitimately reflect current, correctly-written state at commit time; reverting such a
  commit is a real but minor problem (it silently reverts other tasks' latest field values too).
- However, git archaeology surfaced a **sharper, distinct defect** the task's framing does not
  fully separate out: `specs/state.json` is mutated by up to **five independent, unlocked
  read-modify-write round trips per postflight invocation** (Stages 7a/7b/7c/7d/8 in
  `orchestrator-postflight.sh`, plus `update-task-status.sh`'s own read-modify-write), each doing
  `jq`/`python3` read → mutate-in-memory → `mv`-replace against the *same shared file*, with
  **zero concurrency protection anywhere in that chain**. A concrete historical example
  (commit `c9c055187`, task 682) shows a `last_updated` timestamp for an unrelated task (670)
  jumping *backward* in the same commit that also introduces a wholly new task row (693) neither
  task 682's session created — a real fingerprint of concurrent, uncoordinated state.json writes,
  not the "riding along" story alone.
- **Recommendation**: a hybrid of the second and third options, not full serialization of the
  commit path. (1) Treat commit-message mixing as benign and fix it cheaply with **honest,
  accurate commit messages** naming every task whose rows changed, rather than adding a mutex to
  the hot commit path. (2) Separately, **do** reuse `acquire_scope_mutex`/`release_scope_mutex`
  (exposing them via new `task-lock.sh scope-acquire`/`scope-release` subcommands, the
  constraint-mandated reuse) to bracket the **state.json read-modify-write window** in
  `orchestrator-postflight.sh` (Stages 7a through 8, i.e., "read-state → mutate-state →
  regenerate-TODO") — this is the actual data-integrity gap, and it is a narrow, cheap critical
  section (typically milliseconds of `jq`/`python3` calls), not the whole "stage → commit"
  window, which can safely stay outside the mutex.

## Context & Scope

Task 882 asks research to settle, with evidence, whether cross-session mixing in `specs/TODO.md`
and `specs/state.json` commits is a defect worth serializing, benign, or better addressed by
honest commit messages — and explicitly forbids pre-resolving toward serialization. The task also
supplies a reusable primitive (`acquire_scope_mutex`/`release_scope_mutex` in `task-lock.sh`) to
reuse if serialization *is* warranted, and cites live evidence (concurrent `/meta` sessions
racing on `next_project_number`, commit `aeef5a4a7`) that the underlying concurrency problem is
real and ongoing.

Scope of this research: (1) verify every mechanism claim in the task description against the
actual scripts; (2) search the repository's own git history for concrete evidence of the "rode
along" phenomenon actually firing; (3) weigh the three options the task poses; (4) recommend
one (or a considered hybrid), grounded in what was actually found rather than assumed.

## Findings

### Codebase Patterns

**Mechanism claims — all verified against source**:

1. `orchestrator-postflight.sh:439` (Stage 9): `stage_paths=("${task_dir}/" "specs/TODO.md"
   "specs/state.json")` for `plan` and `implement` operations (`do_git_commit=true`). Confirmed
   verbatim. `research` never commits (`do_git_commit=false`) but still mutates `state.json` at
   Stage 7a (`next_artifact_number` increment) and regenerates TODO.md at Stage 8a — so the
   write hazard below applies to `research` too, even though it never stages/commits.

2. `generate-todo.sh:362-363`: `task_numbers=$(jq -r '.active_projects[].project_number'
   "$STATE_FILE" | sort -rn)` — confirmed wholesale regeneration from every row in
   `active_projects`, not scoped to any one task. Output is written via `mktemp` + `mv`
   (`generate-todo.sh` lines ~412-420), so the *regeneration step itself* is atomic — but its
   *input* (`state.json`) can be a torn or racily-interleaved read if another writer is mid
   read-modify-write at the same instant (see below).

3. `task-lock.sh` dispatch (`case "$SUBCMD" in acquire|heartbeat|release|check|init-marker`,
   lines 501-544) confirms `acquire_scope_mutex`/`release_scope_mutex` (lines 215-245) are
   **file-local internal functions**, called only from `cmd_acquire` (line 264) to guard the
   cross-task `file_scope` overlap scan. There is no CLI subcommand that exposes them — the task
   description's claim that exposing them is part of any serialization work is correct.

4. `.claude/context/patterns/task-lock.md:262`: "a session holding the lock still
   checkpoints/commits exactly as before — the lock only adds cross-session exclusivity, it does
   not change checkpoint behavior" — confirmed verbatim. The per-task lock is orthogonal to the
   commit path entirely.

5. `task-lock.sh` locks are keyed on `specs/{NNN}_{SLUG}/.lock/` (per task directory), so two
   sessions on *different* tasks never contend for the same lock — confirmed by
   `resolve_task_dir()`.

**A deeper mechanism the task description does not fully separate out**: `specs/state.json` is
not purely a "derived index" the way `TODO.md` is. It is mutated by independent, *unlocked*
read-modify-write round trips at multiple points in the SAME postflight invocation:

- Stage 7 (`update-task-status.sh`): its own `jq` read → tmp file → `mv` (lines 184-208).
- Stage 7a (research only): `python3` `json.load` → mutate → `json.dump` (lines 291-302).
- Stage 7b (implement only): two more `python3` load/dump round trips (lines 315-343).
- Stage 7c (all operations, when `memory_candidates` non-empty): another `python3` round trip
  (lines 350-365).
- Stage 7d (implement only): a `jq` read → `mv` round trip (lines 378-381).
- Stage 8 (when `artifact_path` set): **two more** sequential `jq` read → `mv` round trips
  (lines 392-406).

None of these round trips are protected by any lock, mutex, or `flock`. Grep across
`orchestrator-postflight.sh`, `update-task-status.sh`, and `generate-todo.sh` for
`scope-lock|acquire_scope_mutex|flock|\.lock` returns zero hits — confirmed. Each round trip
reads the *whole* `state.json` file, mutates one task's fields in memory, and writes the *whole*
file back. If two sessions' postflight pipelines interleave any of these round trips — which is
entirely possible across two concurrent `/research`, `/plan`, or `/implement` invocations on
different tasks, since nothing prevents it — one session's in-memory copy of `state.json` can be
stale by the time it writes, silently discarding the other session's already-applied write. This
is a genuine **lost-update race on the primary data store**, not merely a cosmetic commit-history
artifact.

### External Resources

Not applicable — this is a codebase-internal concurrency question, not a subject for general web
research (no external library or standard applies to this repository's bespoke state-file
design).

### Git History Evidence

A scripted survey of ~400 commits touching `specs/state.json`, isolating single-task,
non-spawn/non-create/non-multi-task commit messages (`^task N: <action>`, excluding messages
containing "spawn", "create", "orchestrate", "revise", "tasks ") and checking whether the
`state.json` diff also touched a *different* task's `project_number` block, surfaced roughly a
dozen candidates across the repository's history (e.g. commits `50397d71`, `86b68cb6`,
`1bc29577`, `fbe90555`, `b7b22063`, `c9c05518`, and others).

Most of these turned out to be **same-session, multi-task orchestration artifacts** (the presence
of `specs/.orchestrator-multi-state.json` in the diff, e.g. commit `ad7891ad` for task 747
touching 748-753, confirms the committing session legitimately processed all of those tasks in
one `/orchestrate` batch — not cross-session mixing).

One commit is a clean, structurally distinct positive: **`c9c055187bb383f5d4928eda8979dc543db00b02`**
("task 682: complete implementation", no multi-task-state file present in the diff). Its
`state.json` diff, beyond task 682's own status update, also:

- Flips task 670's `status` from `"implemented"` to `"completed"`, **and moves its
  `last_updated` timestamp backward** (`2026-06-14T18:39:00Z` → `2026-06-14T00:00:00Z`) — a
  strong fingerprint of a second, concurrently-running writer (a `/todo` archival pass, most
  plausibly) whose update this commit's postflight swept up wholesale via the unconditional
  `specs/state.json` stage, landing an *older-timestamped* value than what task 682's own
  in-memory read had seen for a wholly unrelated task.
- Introduces a brand-new task row (693, "fix_lit_flag_missing_script") that task 682's
  `/implement` operation had no mechanism to create (task creation is `/task`/`/spawn`-only in
  this codebase's design) — meaning a second session's `/task` run landed on disk between task
  682's read and its postflight's write-back, and got carried along.

This is concrete, in-repository proof that the "rode along" mechanism does fire in practice, and
that it is not confined to cosmetic TODO.md noise — `state.json` field values for other tasks
(including timestamps) are being overwritten with values from a different point in time than
when they were actually current, which is exactly the lost-update signature a read-modify-write
race produces. The task's own cited evidence (`aeef5a4a7` claiming task numbers 873-875 out from
under a concurrent batch) is a second, independent confirmation that concurrent sessions writing
`specs/state.json` without coordination is a live, ongoing hazard in this repository — not a
hypothetical.

### Weighing the Three Options

**Option 1 — Serialize the whole "stage → commit" window.** Rejected as the *sole* fix. The
`TODO.md`/`state.json` rows that ride along in a commit, when no interleaved write race
occurred, are not corrupt — `generate-todo.sh` regenerated TODO.md faithfully from whatever
`state.json` said at that instant, and any state.json rows for other tasks reflect their true
latest field values, not made-up ones. Serializing the *entire* stage-through-commit sequence
(which can include slow steps: `validate-artifact.sh`, TTS notification spawn, `git status
--porcelain` residual check) would hold the mutex far longer than the actual risk window
requires, adding latency to the hot path for a problem (commit-history noise) that is mostly
cosmetic.

**Option 2 — Benign, leave alone.** Correct for the commit-history-mixing question in isolation,
*given* state.json's own writes are otherwise race-free — but the evidence above shows they are
NOT race-free today. "Leave alone" without addressing the underlying read-modify-write hazard
would let the lost-update defect (task 670's backward timestamp, and by extension any field on
any task that a concurrent session is also touching) continue to fire silently.

**Option 3 — Honest commit messages.** Correct and cheap for the *cosmetic* half of the problem
(git-log attribution, `git log -- <task-dir>` misleadingness, revert semantics) — a
`git diff --staged -- specs/state.json` scan for `project_number` values other than the task
being committed, folded into the commit message body (e.g. "also carries current index rows for
tasks N, M"), fully addresses the "who did what" concern the task raises, at zero latency cost
and zero new locking machinery. It does **not**, by itself, address the lost-update race, because
an honest message describing what a commit *contains* says nothing about whether that content was
correctly computed in the first place.

**Recommendation — hybrid, not a pure pick of one of the three**: adopt Option 3 for the
commit-message/attribution concern (cheap, always applicable, no hot-path cost), and separately
apply a *narrow* form of Option 1 — not to the whole stage-through-commit window, but
specifically to the `state.json` read-modify-write critical section (Stages 7a-8 in
`orchestrator-postflight.sh`, plus `update-task-status.sh`'s own round trip, and
`generate-todo.sh`'s read) — because that is where the actual, evidenced lost-update defect
lives, not in the git-staging/commit step per se. This directly follows the task's own
constraint ("strongly prefer reusing `acquire_scope_mutex` over any new script") and its own
identification of the correct window ("read-state → regenerate-TODO → stage → commit"), narrowed
by evidence to the read-modify-write portion of that window rather than the whole thing.

## Decisions

- The three-way framing in the task description conflates two distinct concerns that this
  research separates: (a) commit-history attribution/noise (benign, fixable with honest
  messages), and (b) an unlocked, multi-step read-modify-write race on `specs/state.json` itself
  (a real defect, evidenced in this repository's own git history, and worth the narrow mutex
  fix).
- `acquire_scope_mutex`/`release_scope_mutex` should be exposed via new `task-lock.sh
  scope-acquire`/`scope-release` CLI subcommands (reusing the existing `specs/.scope-lock`
  POSIX-atomic `mkdir` primitive, `SCOPE_MUTEX_STALE_SEC=10`, 5s timeout, fail-closed) rather than
  writing any new locking script, per the task's explicit constraint.
- The mutex should bracket only the `state.json` read-modify-write + TODO.md-regeneration window
  (Stages 7-8a of `orchestrator-postflight.sh`, and `update-task-status.sh`'s internal round
  trip when invoked standalone), not the `git add`/`git commit`/TTS-notify/residual-check
  steps that follow.
- Honest commit messages (naming every task whose `state.json`/`TODO.md` rows are present in the
  diff, not just the task the commit is nominally "for") should be implemented independently of
  the mutex work, as the low-cost fix for the git-history attribution complaint.
- This report does not implement either fix — task 882 is explicitly research-first. A follow-up
  planning task should scope: (1) the `scope-acquire`/`scope-release` CLI addition to
  `task-lock.sh`; (2) wiring those calls around `orchestrator-postflight.sh` Stages 7-8a and
  `update-task-status.sh`'s standalone invocation path; (3) the honest-commit-message diff-scan
  addition to Stage 9.

## Risks & Mitigations

- **Risk**: bracketing Stages 7-8a in a mutex could deadlock if any of those stages themselves
  shell out to something that re-enters `acquire_scope_mutex` (e.g. via a nested `task-lock.sh
  acquire` call for `file_scope` overlap checking during a task's own status transition).
  **Mitigation**: audit call sites before wiring; `acquire_scope_mutex` already fails closed
  with a 5s timeout, so a true deadlock would surface as a loud timeout error rather than a silent
  hang, but the audit should still happen at plan time.
- **Risk**: the `SCOPE_MUTEX_STALE_SEC=10` staleness window was tuned for the existing
  `cmd_acquire` overlap-scan use case (fast operation); the state.json read-modify-write chain in
  postflight (5+ round trips, each spawning `jq`/`python3`) may occasionally run longer than 10s
  under load, causing legitimate lock reclamation mid-operation. **Mitigation**: measure actual
  Stage 7-8a wall-clock time before committing to reusing the same constant, and consider (at
  plan time, not here) whether a distinct constant is warranted — though the task's constraint to
  reuse the existing primitive suggests reusing the constant too unless measurement shows
  otherwise.
- **Risk**: honest commit messages require diffing `state.json` before staging to enumerate
  affected `project_number`s, adding a small amount of work to Stage 9. **Mitigation**: this is a
  cheap `git diff --staged -- specs/state.json | grep` operation, not a new locking primitive, and
  fits entirely within the existing non-blocking, best-effort character of Stage 9.

## Context Extension Recommendations

- **Topic**: state.json write-path concurrency.
- **Gap**: `.claude/context/standards/git-staging-scope.md` documents *what* gets staged per
  operation type but says nothing about the *unlocked read-modify-write hazard* on
  `specs/state.json` across the 5+ round trips in `orchestrator-postflight.sh`. A future
  standards doc (or an addendum to `git-staging-scope.md`) should record this once the
  `scope-acquire`/`scope-release` fix lands, so future skill/script authors adding another
  `state.json` mutation point know to bracket it.
- **Recommendation**: when a follow-up implementation task lands the `scope-acquire`/
  `scope-release` CLI and wires it into postflight, extend `.claude/context/patterns/task-lock.md`
  with a new section documenting the exposed scope-mutex CLI surface (currently undocumented
  because it has no CLI surface at all), and cross-reference it from
  `git-staging-scope.md`.

## Appendix

### Search Queries / Commands Used

```bash
# Mechanism verification
sed -n '1,60p;380,427p' .claude/scripts/generate-todo.sh
grep -n "active_projects\|task_numbers=" .claude/scripts/generate-todo.sh
grep -n "checkpoints/commits exactly as before" -A3 -B10 .claude/context/patterns/task-lock.md
grep -n "scope-lock\|acquire_scope_mutex\|flock\|\.lock" .claude/scripts/update-task-status.sh \
  .claude/scripts/orchestrator-postflight.sh .claude/scripts/generate-todo.sh

# Git-history survey for cross-task state.json mixing on single-task, non-multi-task commits
for c in $(git log --oneline -400 --format='%H' -- specs/state.json); do
  msg=$(git log -1 --format='%s' "$c")
  echo "$msg" | grep -qiE 'spawn|create|orchestrate|revise|tasks ' && continue
  task_in_msg=$(echo "$msg" | grep -oE '^task [0-9]+' | grep -oE '[0-9]+')
  [ -z "$task_in_msg" ] && continue
  changed_nums=$(git show "$c" -- specs/state.json | grep -E '^[+-].*"project_number"' \
    | grep -oE '[0-9]+' | sort -u)
  other_nums=$(echo "$changed_nums" | grep -v "^${task_in_msg}$")
  [ -n "$other_nums" ] && echo "$c | msg_task=$task_in_msg | other_changed=$other_nums"
done

# Positive-case inspection
git show c9c055187bb383f5d4928eda8979dc543db00b02 -- specs/state.json
git show aeef5a4a785b980dc045b99595341b3c7f5bc0db --stat
```

### References

- `.claude/scripts/orchestrator-postflight.sh` (Stages 6-10; commit staging at Stage 9)
- `.claude/scripts/task-lock.sh` (`acquire_scope_mutex`/`release_scope_mutex`, lines 215-245;
  dispatch table, lines 495-546)
- `.claude/scripts/generate-todo.sh` (wholesale regeneration, lines 362-363, 412-420)
- `.claude/scripts/update-task-status.sh` (state.json read-modify-write, lines 166-213)
- `.claude/context/patterns/task-lock.md` (per-task lock spec; line 262 checkpoint-composability
  note)
- `.claude/context/standards/git-staging-scope.md` (per-operation staging contract)
- Git commit `c9c055187bb383f5d4928eda8979dc543db00b02` (task 682 — cross-session state.json
  mixing evidence)
- Git commit `aeef5a4a785b980dc045b99595341b3c7f5bc0db` (task-number collision evidence cited in
  the task description, independently confirmed)
