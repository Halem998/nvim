# Research Report: Task #908

**Task**: 908 - prevent_git_index_contention_in_parallel_dispatch
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), empirical scratch-repo git tests
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The just-landed staging narrowing (git-staging-scope.md, orchestrate.md) mitigates a related but
  **distinct** hazard (sweeping ephemeral runtime files / other tasks' unrelated worktree state
  into a commit). It does **not** touch the actual defect: every commit site in the codebase still
  ends in a **bare `git commit`** with no path restriction, so once two processes share one git
  index, a bare `git commit` still commits the whole index regardless of how narrowly `git add`
  staged it. Residual exposure is effectively 100% unchanged by the narrowing.
- **Candidate (a) — path-scoped commit (`git commit -m "..." -- <paths>`) — works and is cheap.**
  Empirically verified in a disposable scratch repo: it commits only the named paths, leaves a
  concurrent process's staged-but-different-path content untouched in the real index, and even
  pre-commit hooks only see a temporary index scoped to the named paths (`GIT_INDEX_FILE` points
  at a `next-index-*.lock` file, not the real index) — so hook-side `git diff --cached` cannot leak
  a foreign task's staged diff either.
- **New finding, not anticipated by the four candidates as stated**: path-scoped commits do not
  eliminate contention, they change its *failure mode*. Under literally-simultaneous `git commit -- 
  <path>` calls from two processes, git's own `index.lock` (a real, single, non-sharded file)
  still serializes at the OS level — one racer wins, the other gets `fatal: Unable to create
  '.../index.lock': File exists.` and its commit **fails outright** (exit 128), leaving its work
  staged-but-uncommitted rather than misattributed. In a 30-iteration concurrent stress test with
  two simultaneous scoped commits per iteration, roughly half failed this way. This is *safe*
  (no misattribution, no lost content) but is a real increase in "nothing to commit or commit
  failed (non-blocking)" outcomes exactly where the codebase's per-objective/per-phase commit
  sites already treat commit failure as swallowed and non-blocking.
- **Recommendation: combine (a) + a lightweight version of (b).** Add pathspec scoping to every
  bare `git commit` call site (a genuine, mechanical, low-risk fix), AND wrap the `git add` +
  `git commit -- <paths>` pair at each site in the **existing** `task-lock.sh scope-acquire` /
  `scope-release` mutex primitive — the same generic mutex already used by
  `update-task-status.sh`'s `acquire_state_mutex`/`release_state_mutex` — rather than inventing a
  new lock. This removes the residual `index.lock` race entirely (only one committer proceeds at
  a time) while keeping the existing "agents commit their own work per phase/objective" property
  intact. (c) worktrees and (d) orchestrator-only commits are both rejected/deprioritized below —
  they are higher-cost and conflict with established, deliberate design properties elsewhere in
  the codebase.
- **`skill-team-implement/SKILL.md` shares the exposure on both axes**: its own two commit sites
  (Stage 10 per-wave, Stage 14 final) use bare `git commit` (no pathspec) AND were **not** part of
  the sibling narrowing — they still lack the canonical ephemeral-exclusion pathspecs that
  `orchestrate.md`'s two sites and `skill-implementer`'s two sites now have. It is *intra-task*
  safe (its own teammates never commit; only the coordinator commits, sequentially, after
  teammates return) but shares the *cross-task* exposure identically to everything else if two
  different task numbers' team-implement sessions are dispatched concurrently.
- Scope note confirmed: single-task `/orchestrate` is unaffected by construction (one Agent tool
  call in flight at a time, so no two processes ever share the index concurrently). The cited
  five-sequential-task run is consistent with, but does not test, this — it's corroboration of the
  scope boundary, not evidence about the defect itself, exactly as flagged.

## Context & Scope

Task 908 investigates a git-index-contention defect observed during a 4-task concurrent
`/orchestrate` wave: commit attribution was scrambled across concurrently-dispatched
implementation agents even though their declared `file_scope`s were genuinely disjoint (the
existing overlap check passed correctly). The root cause is structural: the git index is one
shared resource per working tree, and `git add <paths>; git commit` (no path restriction on the
`commit` itself) commits *the whole index*, not just the paths the caller intended.

A sibling task (907) landed **immediately before** this research, narrowing the staging contract:
`agent-system/extensions/core/context/standards/git-staging-scope.md` now documents a canonical
ephemeral-runtime-file exclusion set (`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`,
`.drift-inspection.json`, `.lock/`) applied via `:(exclude)...)` pathspecs at every task-directory
`git add` in `orchestrate.md`'s two staging sites (CHECKPOINT 3 single-task, Step 5 multi-task
batch commit). This was assessed precisely per the task brief's instruction not to double-count it
as a fix for candidate (a): **it narrows what gets staged into the index; it says nothing about
what gets committed out of the index.** A bare `git commit` after a narrowed `git add` is exactly
as exposed to sweeping in a *different* process's *already-staged* paths as it was before the
narrowing — the narrowing only helps against a single task's own ephemeral files, not against
another concurrent process's staged content.

## Findings

### Root-cause confirmation: every commit site in the codebase uses a bare `git commit`

Grepped every `git commit` call site across the commands/skills/agents that participate in
implementation dispatch. All of them follow the same shape — targeted `git add "${stage_paths[@]}"`
followed by an **unscoped** `git commit -m "..."`:

| Site | File | Frequency |
|------|------|-----------|
| Per-objective green commit (Stage 4B-iii) | `agent-system/extensions/core/agents/general-implementation-agent.md` | Once per verified-green objective — the innermost, highest-frequency site |
| Per-iteration progress commit (Stage 6b) | `agent-system/extensions/core/skills/skill-implementer/SKILL.md` | Once per subagent-return iteration |
| Final "complete implementation" commit (Stage 9) | `agent-system/extensions/core/skills/skill-implementer/SKILL.md` | Once per task |
| Single-task CHECKPOINT 3 | `agent-system/extensions/core/commands/orchestrate.md` | Once per orchestrate cycle |
| Multi-task Step 5 batch commit | `agent-system/extensions/core/commands/orchestrate.md` | Once per multi-task invocation (sequential relative to other commits — see below) |
| Per-wave commit (Stage 10) | `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` | Once per wave |
| Final team commit (Stage 14) | `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` | Once per team-implement task |

None of these pass a pathspec to `git commit` itself. All are candidates for the fix.

### Which sites are actually concurrent (this matters — not all bare-commit sites are equally exposed)

`skill-orchestrate/SKILL.md` states the dispatch model explicitly (line ~1164):

> **BATCHING RULE**: ALL Agent tool calls for the current cycle's dispatch batch MUST be issued in
> a SINGLE orchestrator message with multiple tool-use content blocks... Claude Code processes all
> calls in a single message concurrently.

and (line ~1254): **postflight for each dispatched task runs AFTER all Agent tool calls in the wave
return** — i.e. the orchestrator's own per-task postflight (which is where CHECKPOINT 3-equivalent
and the Step 5 batch commit fire) is single-threaded and sequential across tasks in a wave. So:

- `orchestrate.md`'s own two staging sites (CHECKPOINT 3, Step 5) are **not** where concurrent
  commits actually collide — the orchestrator thread that runs them processes one task's postflight
  at a time, even for a multi-task wave.
- The actual collision site is **inside each dispatched agent's own execution**, which genuinely
  runs concurrently with sibling agents in the same wave (per the BATCHING RULE above): every
  `general-implementation-agent` commits at Stage 4B-iii (per objective) and every
  `skill-implementer` commits at Stage 6b (per iteration) *while its own Agent tool call is still
  in flight*, concurrently with however many other tasks (up to `MAX_TASKS=8`) are in the same
  wave. This is confirmed by `skill-git-workflow/SKILL.md`'s own description of the four execution
  sites: "`general-implementation-agent.md`'s Phase Checkpoint Protocol (per-phase commit) — the
  innermost, once-per-phase commit site" is explicitly called out as running "independently of
  `orchestrator-postflight.sh`."
- This reconciles with the observed defect exactly: the task description's collision was reported
  by *implementation agents themselves* ("two of its own phase commits bundled under other agents'
  commit messages" / "phase-7 commit swept into a concurrent session's commit") — i.e. the
  in-flight, per-agent commit sites, not the orchestrator's own sequential postflight sites.

This also means: **the existing `state.json` mutex (`acquire_state_mutex`/`release_state_mutex` in
`update-task-status.sh`) does not protect this at all**, and was never meant to — its own
documentation in `git-staging-scope.md`'s "State-Write Serialization" section explicitly scopes
itself to the state.json read-modify-write window and states "Stage 9 and later remain explicitly
outside the mutex... a slower git/TTS/cleanup tail carries no data-integrity risk worth
serializing." That reasoning was sound when the only writer of Stage 9 (git add/commit) was a
single sequential orchestrator-postflight process. It is **no longer accurate** once
`general-implementation-agent`'s own inline per-objective commits are considered, because those run
inside literally-concurrent Agent tool calls. This is a load-bearing assumption in a currently-true
document that the introduction of concurrent multi-task dispatch quietly invalidated — flagging
this explicitly since it's exactly the kind of drift the task description warns against
double-counting or under-counting.

### Candidate (a): path-scoped commit — empirically verified to work, with one caveat discovered

Test environment: disposable scratch repo at
`/tmp/claude-*/scratchpad/git-index-test` (outside the task tree, discarded after testing).

**Test 1 — basic scoping.** Two tracked files `taskA/f.txt` and `taskB/f.txt` were both modified
and both `git add`ed (simulating: agent A stages its own file; a concurrent agent B has *already*
staged its own file in the same shared index, matching the real per-objective commit's `git add`
timing). Agent A then ran `git commit -m "..." -- taskA`. Result: the commit's diff contained ONLY
`taskA/f.txt`; after the commit, `git status --short` still showed `M  taskB/f.txt` — task B's
staged content was left exactly as staged, untouched and uncommitted. **Confirms the task
description's premise directly**: `git commit -- <paths>` does *not* commit the whole index.

**Test 2 — pathspec commit without a prior `git add` for the named path.** Running
`git commit -m "..." -- taskA/f.txt` on a working-tree change that was never explicitly `git
add`ed also worked and left the other file's staged state untouched. (Per git's documented
behavior, naming paths on `git commit` implicitly stages *those* paths from the working tree as
part of the commit — it does not require a prior explicit `add` for the named paths, though the
codebase's existing convention of `git add "${stage_paths[@]}"` immediately before commit is
harmless and keeps `git status` legible mid-flight.)

**Test 3 — `git commit -o`/`--only`.** Behaves identically to the plain pathspec form in this
scenario (commits only the named path, leaves the other staged file alone). No material advantage
over the plain pathspec form for this use case; the plain form (`git commit -m "..." -- "${stage_paths[@]}"`)
is simpler and is what's already documented elsewhere in the codebase's terminology, so it's the
recommended spelling — `-o` adds no value here and one fewer flag to explain is better.

**Test 4/4b — hook interaction (a real, previously-unverified risk this task explicitly asked
about).** A `pre-commit` hook was installed that runs `git diff --cached --name-only`. With a
pathspec-scoped commit, the hook saw **only** the named path (`taskA/f.txt`), not the foreign
`taskB/f.txt` that was also staged in the real index at that moment. Inspecting the hook's
environment confirmed why: git constructs a **temporary index file**
(`GIT_INDEX_FILE=.../.git/next-index-<pid>.lock`) scoped to just the committed paths, runs
pre-commit/commit-msg hooks against *that* temporary index, and only briefly locks the real
`.git/index` at the end to write back the (correctly narrow) update. So a hook cannot leak a
concurrent task's staged diff even if it inspects the staged index directly. This closes an
otherwise-plausible objection to candidate (a).

**Test 5 — the caveat: true simultaneous scoped commits still race on `index.lock`.** Ran 30
iterations of two background processes committing at the same instant
(`git commit -m "A iter $i" -- taskA/f.txt &` / `git commit -m "B iter $i" -- taskB/f.txt &` then
`wait`). Roughly half of the 60 total commit attempts failed with `fatal: Unable to create
'.../index.lock': File exists.` (exit code 128) — because even a pathspec-scoped commit still
takes a real, single, non-sharded lock on `.git/index` for the brief window it writes the update
back. **This is a safe failure mode** — no misattribution, no content loss, the failed commit's
changes remain staged (or working-tree, per Test 2) for the *next* commit attempt to pick up — but
it is a real, mechanically-verified increase in commit-attempt failure rate exactly at the sites
(`general-implementation-agent` Stage 4B-iii, `skill-implementer` Stage 6b) that already treat
commit failure as non-blocking ("Note: Nothing to commit or commit failed (non-blocking)"). Under
`MAX_TASKS=8` concurrent tasks each committing at every green objective, this failure rate would
be non-trivial in practice — likely resulting in objectives whose work never gets committed until a
later phase's commit happens to succeed (or the final commit at end of the agent's run), which is
an availability/timeliness regression even though it is not a correctness regression.

**Conclusion for (a) alone**: genuinely fixes the misattribution defect (the actual reported bug),
but does not fully close the gap the task asks about — a meaningful fraction of concurrent commits
will still silently fail (in the existing "non-blocking" sense) rather than committing on time.

### Candidate (b): commit mutex — an established, reusable primitive already exists

`agent-system/extensions/core/scripts/task-lock.sh` already implements exactly the primitive this
candidate needs, and it predates this task (introduced for `update-task-status.sh`'s `state.json`
serialization, "task 809"/"task 882" per its own comments):

- `task-lock.sh scope-acquire <session_id> [stale_sec]` / `scope-release <token>` expose a generic
  `specs/.scope-lock/` mutex built on POSIX-atomic `mkdir` (no TOCTOU), with **holder-declared
  staleness** (the acquirer writes its own tolerated window so a longer critical section is
  respected by all waiters, not just the mutex's own short default), **owner-token-verified
  release** (a stale-reclaimed holder's late release can never delete a successor's mutex), and a
  documented **non-reentrant** contract with a `SCOPE_MUTEX_HELD` env-var convention for a callee
  to detect an outer holder and skip a nested acquire (already used by `update-task-status.sh`'s
  `acquire_state_mutex` when it runs as a Stage-7 child of `orchestrator-postflight.sh`).
- `update-task-status.sh`'s `acquire_state_mutex`/`release_state_mutex` (lines ~55-104) is the
  proven consumer pattern: acquire before a critical section, fail-open with a loud non-blocking
  warning on timeout (never abort the caller), release in a `trap ... EXIT` cleanup, and respect
  `SCOPE_MUTEX_HELD` to avoid self-deadlock when nested.

**Recommendation**: wrap each `git add ...; git commit -- ...` pair (per site above) in this same
`scope-acquire`/`scope-release` pattern, mirroring `acquire_state_mutex`/`release_state_mutex`
byte-for-byte rather than inventing new locking logic — the task brief explicitly asks for this.
One design decision to flag rather than decide unilaterally: `acquire_scope_mutex`/
`release_scope_mutex` today hardcode a single mutex directory, `specs/.scope-lock/` — the same
resource `update-task-status.sh` already uses for the state.json write window. Two live options:
  1. **Reuse the same `specs/.scope-lock/` resource** for commit serialization too. Simplest,
     zero script changes, and both critical sections are short (sub-second git operations / a few
     JSON read-modify-writes), so the extra cross-purpose queuing is negligible. Con: a task's
     phase-commit could transiently queue behind an unrelated task's state.json write, and vice
     versa — harmless but slightly conflates two logically distinct critical sections under one
     name.
  2. **Add a second, sibling mutex directory** (e.g. `specs/.commit-lock/`) by parameterizing
     `acquire_scope_mutex`/`release_scope_mutex`/the `scope-acquire`/`scope-release` CLI verbs with
     an optional mutex-name argument (default `.scope-lock` for exact backward compatibility).
     Slightly more code (a parameterization change to `task-lock.sh`), but keeps state-write
     serialization and commit serialization independent, which is the cleaner long-term shape
     given they really are different critical sections with different natural call sites
     (postflight-only vs. every commit site listed above, including deep inside
     `general-implementation-agent`'s own loop).

  Option 2 is the better fit given how much more frequently the commit-mutex would be
  acquired/released (once per objective, potentially dozens of times per task) compared to the
  state-write mutex (once per postflight run) — needlessly coupling their contention profiles
  seems avoidable for a small, mechanical script change. This is a recommendation, not a
  unilaterally-made decision; the planning phase should confirm which shape the implementer
  should build.

  Either way, the mutex's default `SCOPE_MUTEX_STALE_SEC=10` / 5-second acquire timeout is
  generous relative to a `git commit`'s actual duration (well under 1 second in the stress test
  above), so serializing every phase/objective commit through it should add negligible observed
  latency even at `MAX_TASKS=8` concurrent tasks.

### Candidates (c) and (d): assessed and deprioritized

**(c) Per-agent git worktrees.** Would give each concurrently-dispatched agent its own index,
eliminating the shared-resource problem at the root. Rejected as the primary fix because:
  - `specs/state.json` and `specs/TODO.md` are **genuinely shared, wholesale-regenerated index
    files** across *all* tasks (not per-task) — this is explicit, deliberate design in
    `git-staging-scope.md`'s Per-Operation Scope section. A worktree-per-agent model would need a
    merge/reconciliation step for these two files after every commit from every worktree, not just
    at task completion — since agents commit progressively (per-objective), this reconciliation
    would need to happen at the same frequency as today's commits, effectively re-inventing a
    serialization point anyway, just one layer further from the actual git primitive.
  - Dispatch is via the `Agent`/`Skill` tool, not a shell-level process the orchestrator directly
    forks into a prepared worktree — adopting worktrees would require new dispatch-layer plumbing
    (worktree creation, path rebasing for every file operation the agent performs, worktree
    teardown/merge) well beyond a git-staging-contract change.
  - Cost/benefit is poor relative to (a)+(b): it solves the same problem (b) already solves with
    an existing, proven primitive, at substantially higher implementation and operational cost.

**(d) Serialize commits through the orchestrator (agents report paths, orchestrator commits).**
This is the strongest *structural* fix for the specific race (removes concurrency from the commit
step by construction, since the orchestrator thread that issues concurrent Agent-tool calls is
itself single-threaded and already processes returns sequentially — see "COMPLETION SEQUENCING" in
`skill-orchestrate/SKILL.md`: "After ALL Agent tool calls complete... read handoffs for every
dispatched task. Do NOT read handoffs interleaved with dispatches."). However, it requires a
**larger, deliberate behavior change**, not a drop-in fix: agents currently commit progressively,
*during their own execution*, and this is load-bearing elsewhere:
  - `general-implementation-agent.md`'s Stage 4B-iii commit is explicitly named the "Green
    Sub-Step Commit (Mandatory)" per the Commit-Per-Green-Substep Mandate, and is explicitly
    reused ("not duplicated") by `checkpoint-before-overflow.md`'s context-exhaustion handoff
    procedure — i.e. the recovery story for an agent running out of context *depends on* commits
    having already happened progressively, live, before the overflow point. Deferring all commits
    to post-return orchestrator batching would mean a context-exhausted agent's verified-good work
    is sitting uncommitted in the working tree with no commit boundary to recover from, which is a
    real regression against an established, deliberate safety property.
  - This candidate is the right answer *only* if that property (commit progressively for
    checkpoint-recovery) were also being reworked, which is out of this task's stated scope
    (four candidates to compare for *this* defect, not a redesign of the checkpoint-recovery
    story). Flagging as a longer-term option worth a dedicated follow-up if the codebase later
    decides progressive in-flight commits aren't worth their concurrency cost, but not
    recommended as the fix here.

### Q4: does `skill-team-implement/SKILL.md` share the exposure?

Yes, on both axes the task asked about:

1. **Staleness relative to the sibling narrowing.** `Stage 10: Per-Wave Commits` and
   `Stage 14: Final Git Commit` both stage with plain `git add specs/${padded_num}_${project_name}/
   ...` and **no** `:(exclude)...)` pathspecs for the canonical ephemeral-runtime-file set that
   `orchestrate.md`'s two sites and `skill-implementer`'s sites now carry. The sibling task's
   rewrite (per the delegation brief) touched `orchestrate.md`'s two sites and
   `skill-implementer`/`skill-implementer-hard`'s SKILL.md files, but not
   `skill-team-implement/SKILL.md` — this is a real, distinct staleness gap worth flagging for the
   planning phase alongside the index-contention fix, since `skill-team-implement` is in this
   task's declared `file_scope`.
2. **The index-contention defect itself.** Both of `skill-team-implement`'s commit sites use a
   bare (unscoped) `git commit`, identical in shape to every other site in the table above. Its
   *intra-task* concurrency is safe: teammates spawned via `spawn_phase_implementer(phase)` never
   commit themselves (their prompt template only instructs writing result files, not git
   operations) — only the coordinating `skill-team-implement` thread commits, and it does so
   sequentially (Stage 10 fires "after each wave completes," Stage 14 fires "after all waves
   complete"), matching the same single-threaded-postflight safety property `orchestrate.md`'s own
   two sites have. But *cross-task* concurrency — e.g. `--team` implement dispatched for two
   different task numbers at the same time, or one running alongside a plain (non-team)
   `/orchestrate` wave touching a different task — races exactly like every other site: a bare
   `git commit` after Stage 10/14's `git add` will sweep in whatever else is currently staged in
   the shared index, including another task's in-flight staged content.

Both gaps should be closed by the same fix applied everywhere else: pathspec-scope the `git
commit` call, add the canonical exclusion set to the `git add`, and wrap the pair in the
commit mutex.

### Q5: scope note — single-task `/orchestrate` confirmed unaffected

Confirmed structurally, not just by absence-of-observed-failure: single-task `/orchestrate`
(`len(TASK_NUMBERS) == 1`) never issues more than one Agent tool call in flight at a time — its
state machine (CHECKPOINT 1 GATE IN -> DELEGATE -> CHECKPOINT 2 GATE OUT -> CHECKPOINT 3 COMMIT,
looped per cycle) is inherently sequential; there is no code path in `orchestrate.md` or
`skill-orchestrate/SKILL.md` that dispatches two Agent tool calls for the *same* task
concurrently. The five-sequential-task run this session performed (~25 clean per-phase commits,
zero contention) is consistent with this — each task's Agent tool call fully returned before the
next task's was issued — but as the task brief itself notes, this is corroboration of the *scope
boundary* (single-task-at-a-time is safe), not a test of the *defect* (which requires two
processes genuinely in flight at the same wall-clock instant, as this report's Test 5 constructed
directly).

## Decisions

- Candidate (a) (pathspec-scoped `git commit`) is validated as necessary and should be applied to
  every bare `git commit` call site listed in the table above, including
  `skill-team-implement/SKILL.md`'s two sites.
- Candidate (a) alone is **insufficient** to fully close the gap — it changes the failure mode from
  "misattribution" (silent, wrong) to "commit-attempt failure" (safe, but non-trivial rate under
  concurrency per Test 5) — so it should be paired with candidate (b).
- Candidate (b) should reuse `task-lock.sh`'s existing `scope-acquire`/`scope-release` mutex
  primitive rather than invent new locking logic, mirroring `update-task-status.sh`'s
  `acquire_state_mutex`/`release_state_mutex` consumer pattern (fail-open with a loud warning on
  timeout, `trap ... EXIT` release, respect `SCOPE_MUTEX_HELD` reentrancy signal). Whether it
  shares `specs/.scope-lock/` with the state-write mutex or gets a parameterized sibling mutex
  directory is a planning-phase call — this report recommends the sibling-directory option given
  the much higher call frequency of a per-objective commit mutex versus a per-postflight
  state-write mutex, but does not treat this as settled.
- Candidates (c) and (d) are not recommended for this task: (c) is high-cost and conflicts with
  the shared, wholesale-regenerated nature of `specs/state.json`/`specs/TODO.md`; (d) conflicts
  with the established Commit-Per-Green-Substep Mandate and its reuse by the
  context-exhaustion checkpoint-recovery procedure, and would need to be a deliberate, larger
  redesign rather than a fix scoped to this defect.
- `skill-team-implement/SKILL.md`'s missing ephemeral-exclusion pathspecs (a staleness gap
  relative to the sibling narrowing, separate from but adjacent to the index-contention fix)
  should be closed in the same implementation pass since the file is already in scope and the fix
  is the same shape as the other four sites already updated.

## Declared `file_scope` vs. actual fix surface — flag for planning

Task 908's declared `file_scope` is:
```
agent-system/extensions/core/commands/orchestrate.md
agent-system/extensions/core/context/standards/git-staging-scope.md
agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
agent-system/extensions/core/skills/skill-team-implement/SKILL.md
```

Per the "Which sites are actually concurrent" finding above, the *actual* collision sites the
observed defect came from — `general-implementation-agent.md`'s Stage 4B-iii per-objective commit
and `skill-implementer/SKILL.md`'s Stage 6b/Stage 9 commits — are only partially covered:
`skill-implementer/SKILL.md` is not in the declared scope at all, and
`general-implementation-agent.md` is not either. `orchestrate.md`'s own two sites, while worth
fixing for consistency and defense-in-depth, are **not** where the observed misattribution
actually happened (they run sequentially inside a single orchestrator thread, per the BATCHING
RULE / COMPLETION SEQUENCING analysis above). Fixing only the four declared files would touch the
*documentation front* (`git-staging-scope.md`) and the *lower-frequency, already-sequential* sites,
while leaving the *highest-frequency, genuinely-concurrent* sites (inside
`general-implementation-agent.md` and `skill-implementer/SKILL.md`) unfixed — which is where the
task's own observed evidence says the collision actually occurred. The planning phase should
either widen `file_scope` to include `agent-system/extensions/core/agents/general-implementation-agent.md`
and `agent-system/extensions/core/skills/skill-implementer/SKILL.md`, or explicitly scope this task
to the documentation contract + `orchestrate`/`skill-team-implement` sites and spawn a follow-up
task for the two implementation-agent-level sites — but leaving them out silently would not
actually close the reported defect.

## Risks & Mitigations

- **Risk**: wrapping every per-objective commit in a mutex could add meaningful latency under
  `MAX_TASKS=8` concurrent tasks each committing frequently. **Mitigation**: the mutex's existing
  timeout (5s) and stale window (10s) are generous relative to measured commit duration
  (sub-second in Test 5); if this proves too slow in practice, the stale/timeout values are
  already env/parameter-overridable per `task-lock.sh`'s documented contract, without touching the
  call sites.
- **Risk**: a mutex acquire timeout means the fix could reintroduce the exact "non-blocking commit
  failure" behavior it's meant to eliminate, just moved from `index.lock` contention to mutex
  contention. **Mitigation**: `acquire_state_mutex`'s established pattern already fails open with
  a loud warning rather than aborting the caller — the same pattern here means a timed-out commit
  attempt logs loudly and is treated exactly like today's "nothing to commit" non-blocking case,
  which is a strict improvement (was: silent misattribution or a bare index.lock race with no
  warning at all; becomes: loud, logged, non-blocking skip that a later commit will still pick up).
- **Risk**: reusing the same `specs/.scope-lock/` resource for both state-write and commit
  serialization could mask two independent contention sources as one in diagnostics.
  **Mitigation**: if reused, log messages already name the operation type distinctly
  (`acquire_state_mutex` logs "status update," a new commit-mutex caller would log "commit") so
  the *reason* for a given wait is still distinguishable even if the *resource* is shared.

## Context Extension Recommendations

- **Topic**: Cross-process git-index serialization for concurrent agent dispatch.
- **Gap**: `git-staging-scope.md` currently documents staging scope but has no section on
  commit-level path-scoping or on serializing the actual `git add`/`git commit` operation across
  concurrently-dispatched agents (its own "State-Write Serialization" section explicitly and
  correctly scopes itself to state.json only, and its assumption that "Stage 9 and later... carr[y]
  no data-integrity risk worth serializing" predates concurrent multi-task dispatch's introduction
  of genuinely concurrent in-agent commit sites).
- **Recommendation**: once a plan lands for this task, extend `git-staging-scope.md` with a new
  section (e.g. "Commit-Level Path Scoping and Cross-Process Serialization") documenting the
  `-- <paths>` requirement on every `git commit` call and the commit-mutex wrapping, so future
  audits of this contract see the full picture in one canonical document rather than needing to
  reconstruct it from this task's artifacts.

## Appendix

### Search/verification methodology

- Read `specs/state.json`'s task 908 description in full (root cause, four candidates, binding
  constraints, five specific questions).
- Read the current (post-sibling-change) contents of `git-staging-scope.md` and the two staging
  sites in `orchestrate.md`, confirmed via `git log -p` that they were rewritten in commit
  `9de517d08` ("task 907 phase 2: narrow the staging contract and both orchestrate staging
  sites").
- Read `task-lock.sh` in full (the `scope-acquire`/`scope-release` CLI and its
  `acquire_scope_mutex`/`release_scope_mutex` internals) and `update-task-status.sh`'s
  `acquire_state_mutex`/`release_state_mutex` (lines ~55-104).
- Read `orchestrate.md`'s multi-task dispatch stages (batch validation, dependency graph,
  Kahn's-algorithm wave assignment, runtime wave-split check, Step 4 single-dispatch multi-task
  invocation, Step 5 batch commit) and CHECKPOINT 3 (single-task commit).
- Read `skill-orchestrate/SKILL.md`'s BATCHING RULE and COMPLETION SEQUENCING statements, and its
  per-task postflight sequencing after all Agent tool calls in a wave return.
- Read `skill-implementer/SKILL.md` Stage 6b and Stage 9, `general-implementation-agent.md` Stage
  4B-iii, and `skill-git-workflow/SKILL.md`'s "Relationship to orchestrator-postflight.sh" section
  naming all four execution sites explicitly.
- Read `skill-team-implement/SKILL.md`'s teammate spawn model, Phase Implementer Prompt Template,
  Stage 10, and Stage 14, confirming teammates never commit and only the coordinator does.
- Ran five empirical tests in a disposable scratch git repository (created and destroyed under the
  session scratchpad directory, never inside the task tree): basic pathspec scoping; pathspec
  scoping without a prior `git add`; `git commit -o`; pre-commit hook visibility via `git diff
  --cached`; and `GIT_INDEX_FILE` inspection plus a 30-iteration true-concurrency stress test of
  two simultaneous scoped commits.

### Recommended fix shape (informative, not binding — planning phase to finalize)

For each of the seven commit sites listed in the root-cause table:

```bash
# 1. git add already targeted per git-staging-scope.md (unchanged)
git add "${stage_paths[@]}"

# 2. NEW: acquire the commit mutex (mirrors acquire_state_mutex's pattern)
token=$(.claude/scripts/task-lock.sh scope-acquire "$session_id") || {
  echo "WARNING: failed to acquire commit mutex; proceeding unserialized (non-blocking)." >&2
  token=""
}

# 3. NEW: pathspec-scope the commit itself
git commit -m "..." -- "${stage_paths[@]}" || echo "Note: nothing to commit or commit failed (non-blocking)"

# 4. NEW: release the mutex
[ -n "$token" ] && .claude/scripts/task-lock.sh scope-release "$token"
```
