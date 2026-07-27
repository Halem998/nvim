# Implementation Plan: Task #908

- **Task**: 908 - Prevent git index contention between concurrently dispatched orchestrate agents
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 907 (landed; staging narrowing is a prerequisite context, not a fix for this defect)
- **Research Inputs**: specs/908_prevent_git_index_contention_in_parallel_dispatch/reports/01_git-index-contention.md
- **Artifacts**: plans/01_git-index-contention.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every commit site in the dispatch pipeline stages narrowly and then commits with a **bare
`git commit`**, which commits the entire shared index — so a concurrently-dispatched agent's
staged-but-uncommitted work is swept into whichever agent commits next. This plan fixes the defect
in two mechanisms: path-scoping every `git commit` (`git commit -m "..." -- "${stage_paths[@]}"`),
and serializing the `git add` + `git commit` pair through a new, parameterized `specs/.commit-lock/`
sibling of the existing `task-lock.sh` scope mutex. Rather than editing eleven near-duplicate bash
snippets, both mechanisms are consolidated into one shipped helper script that every call site
invokes; the eleven snippets already drifted apart once (see Verified Finding V6), and consolidating
is what stops that recurring. Definition of done: no bare `git commit` remains in the dispatch
pipeline, and a live concurrency test demonstrates both the absence of misattribution and the
absence of the `index.lock` failure-rate regression the research measured.

### Research Integration

The research report is adopted in full on its central conclusions: candidate (a) path-scoping is
necessary but insufficient alone (it converts misattribution into a ~50% `index.lock` commit-failure
rate under true concurrency), candidate (b) must reuse `task-lock.sh`'s existing mutex primitive
rather than invent new locking, and candidates (c) worktrees and (d) orchestrator-only commits are
correctly deprioritized. Two open items the report explicitly deferred to planning are settled below:
the mutex-directory question (Settled Decision 1) and the `file_scope` gap (Declared file_scope
Expansion).

### Verified Findings (this planning pass, empirical — supersede where they conflict with research)

Re-verified against the current source store, because `git-staging-scope.md`, `commands/orchestrate.md`,
both orchestrate SKILL.md files, and `skill-base.sh` were all modified earlier in this session and
line numbers in the research report have drifted.

| ID | Finding | How verified |
|----|---------|--------------|
| V1 | Exclude pathspecs **do** work on `git commit -- <paths>`. A commit with `("taskA/" ":(exclude)taskA/.orchestrator-loop-guard")` contained only `taskA/f.txt`; the ephemeral file stayed unstaged. | Scratch repo |
| V2 | A **nonexistent path** in the commit pathspec aborts the entire commit (`error: pathspec '...' did not match any file(s) known to git`, exit 1) — nothing is committed. This is a **new failure surface**: today a bad path only fails `git add`, which `orchestrator-postflight.sh` already guards; on `git commit` it kills the commit outright. | Scratch repo |
| V3 | An **exclude-only** pathspec list (no positive entry) commits *everything except* the excluded paths — strictly **wider** than a bare `git commit`. A degenerate `stage_paths` (e.g. an empty `task_dir` variable) turns the fix into a worse bug. | Scratch repo: exclude-only commit swept in the concurrent process's `taskB/f.txt` |
| V4 | "nothing to commit" exits **1** for the scoped form, identical to the bare form. Existing `\|\| echo "Note: Nothing to commit..."` fallbacks keep working unchanged. | Scratch repo |
| V5 | The reported defect reproduces and is fixed: with agent B's work staged in the shared index, agent A's scoped commit committed nothing of its own (exit 1, non-blocking) and **left B's staged content untouched**. The bare form would have committed B's work under A's message. | Scratch repo |
| V6 | **The staleness gap is broader than the research reported.** The research states `skill-implementer`'s sites "now have" the ephemeral-exclusion pathspecs. They do not. `grep -rn 'ephemeral_excludes'` matches **only** `context/standards/git-staging-scope.md`; the exclusions exist inline in `commands/orchestrate.md`'s two sites and nowhere else. `skill-implementer` (Stage 6b, Stage 9), `general-implementation-agent` (both sites), `general-implementation-hard-agent`, `skill-planner` (Stage 9), `skill-team-implement` (Stage 10, Stage 14), and `orchestrator-postflight.sh` (Stage 9) all stage a bare `"${task_dir}/"` with no exclusions. | `grep -rn 'ephemeral_excludes\|git add' agent-system/extensions/core/` |
| V7 | `skills/skill-implementer-hard/SKILL.md` contains **no** `git commit` site at all — checked and clean, needs no change. Recording this so the "did you check the hard-mode siblings" question has a documented answer rather than an omission. | `grep -n 'git commit' skills/skill-implementer-hard/SKILL.md` (no matches) |
| V8 | `general-implementation-hard-agent.md` **does** carry the identical bare-commit shape (Stage 5 Step 2, final incremental commit) and is included in the expansion below. | Direct read |
| V9 | Task 885 (status `partial`, **non-terminal**) declares `agent-system/extensions/core/scripts/orchestrator-postflight.sh` in its `file_scope` — a real, declared overlap with this plan's expansion. Its subject is event/signal-capture instrumentation, a different region of that file from the Stage 9 commit block. | `jq` over `specs/state.json` |

### Prior Plan Reference

No prior plan for this task.

### Roadmap Alignment

No ROADMAP.md consultation was requested for this dispatch.

## Settled Decisions (do not re-open during implementation)

### Decision 1: a parameterized sibling mutex `specs/.commit-lock/`, not a reuse of `specs/.scope-lock/`

The research flagged this as a planning call and recommended the sibling directory on
call-frequency grounds. That is correct but not the decisive reason. **The decisive reason is a
reentrancy-flag collision:**

`SCOPE_MUTEX_HELD=1` is a single global env flag meaning "an outer holder already owns *the*
mutex", and `update-task-status.sh`'s `acquire_state_mutex` skips its own acquire when it sees
that flag. If commit serialization shared `specs/.scope-lock/`, then a commit executed inside any
window where that flag is exported would either (a) honor the flag and run **unserialized** —
silently defeating the fix — or (b) ignore it and attempt a nested acquire on a documented
**non-reentrant** mutex. Two independent critical sections need two independent held-flags, and two
held-flags require two mutex names regardless of frequency.

Two supporting reasons:

- Reusing `.scope-lock` would **invert a deliberate, documented invariant**.
  `orchestrator-postflight.sh` explicitly releases the scope mutex *before* Stage 9, and both its
  own comments and `git-staging-scope.md`'s "State-Write Serialization" section state that Stage 9
  stays **outside** the mutex. Reusing it for commits would make Stage 9 acquire the exact mutex
  those documents say it must not — silently replacing a stated invariant with its negation. A
  distinct mutex lets both statements stay true simultaneously.
- Contention profiles differ by an order of magnitude (per-objective commits vs. per-postflight
  state writes); coupling them makes every state write queue behind unrelated commits at
  `MAX_TASKS=8`.

### Decision 2: consolidate into one shipped helper, do not edit eleven near-duplicate snippets

Verified Finding V6 is the argument: the exclusion set was added to the contract and to two of
eleven call sites, and the other nine silently drifted. Re-applying an even subtler pattern
(mutex acquire, pathspec filtering per V2, degenerate-pathspec refusal per V3, bounded retry,
token release) by hand eleven times will drift the same way. This plan ships
`agent-system/extensions/core/scripts/git-commit-scoped.sh` and converts every call site to invoke
it, so the contract has exactly one executable definition. This also closes the V6 staleness gap as
a side effect, since the helper applies the canonical exclusion set itself.

### Decision 3: closed named verbs, not a generic `mutex-acquire <name>`

`task-lock.sh` gains `commit-acquire` / `commit-release` verbs, not an open-ended
`mutex-acquire <arbitrary-name>`. Named verbs keep the set of mutexes closed and auditable; a
generic name argument invites callers to invent ad-hoc mutexes that nothing coordinates.

## Declared file_scope Expansion

Declared `file_scope` is only `commands/orchestrate.md`, `context/standards/git-staging-scope.md`,
`skills/skill-orchestrate/SKILL.md`, `skills/skill-team-implement/SKILL.md` (all under
`agent-system/extensions/core/`). The defect cannot be closed within that set: research established,
and this pass re-confirmed, that `orchestrate.md`'s own two sites run **sequentially** inside one
orchestrator thread (BATCHING RULE / COMPLETION SEQUENCING) and are therefore *not* where the
observed misattribution happened. The genuinely-concurrent, highest-frequency sites are inside the
dispatched agents and are absent from the declared scope. This plan therefore **declares** the
following expansion explicitly rather than editing out of scope silently.

| Path (under `agent-system/extensions/core/`) | Phase | Why it must be in scope |
|---|---|---|
| `agents/general-implementation-agent.md` | 5 | The two highest-frequency genuinely-concurrent commit sites (Stage 4B-iii per-objective, Phase Checkpoint Protocol step 5). This is where the reported misattribution actually occurred. |
| `skills/skill-implementer/SKILL.md` | 5 | Stage 6b (per subagent-return iteration) and Stage 9 (final) — the second-highest-frequency concurrent sites. |
| `agents/general-implementation-hard-agent.md` | 5 | Identical bare-commit shape at Stage 5 Step 2 (V8). Leaving a known-identical defect unfixed is exactly what the dispatch brief forbids. |
| `skills/skill-planner/SKILL.md` | 6 | Stage 9 has the same bare-commit shape and is **genuinely concurrent**: multi-task `/plan N,N,N` dispatches planner agents in one batch (this very session ran ten in parallel). Same defect, same fix. |
| `scripts/orchestrator-postflight.sh` | 6 | Stage 9 is the single most-shared commit site — both `plan` and `implement` postflight for every task flow through it. See the Risks table for the declared task-885 overlap and its mitigation. |
| `scripts/task-lock.sh` | 2 | Hosts the mutex primitive being parameterized. No other file can carry the `commit-acquire`/`commit-release` implementation. |
| `scripts/git-commit-scoped.sh` (new) | 3 | The shipped helper of Decision 2. |
| `manifest.json` | 3 | `provides.scripts` enumerates individual filenames, so a new script is **not deployed** unless registered. Mechanical consequence of the line above; verified against the current manifest, which lists 40 scripts by name. |
| `context/patterns/task-lock.md` | 4 | Canonical documentation of the mutex CLI; its "Scope-Mutex CLI" section must gain the commit-mutex sibling or the new verbs are undocumented. |

`skills/skill-orchestrate/SKILL.md` remains in declared scope but is **not modified** — it contains
no `git commit` site (verified). `skills/skill-implementer-hard/SKILL.md` is deliberately **not**
added: V7 confirms it has no commit site. Both non-edits are findings to record in the summary, not
omissions.

Collision check: the dispatching orchestrator verified `general-implementation-agent.md` and
`skill-implementer/SKILL.md` are collision-free. This pass additionally checked every non-terminal
task's `file_scope` and found exactly one overlap — task 885 on `orchestrator-postflight.sh` (V9),
handled in Risks below. The remaining expansion paths are collision-free.

## Binding Constraints

- **SOURCE-STORE RULE**: every edit targets `agent-system/extensions/core/**`. Never `.claude/**`.
- `.claude/` is a **stale deploy artifact** not being re-synced during this run. Source-store edits
  will not affect the in-flight orchestration. **Do not re-sync it.**
- **No task-number references** in any file outside `specs/**` (per
  `no-task-references-in-deliverables.md`). Every deliverable edited here is outside `specs/**`.
  Cite durable anchors — file names, section headings, mechanism descriptions. Note that
  `task-lock.sh` already contains legacy `task 809` / `task 882` comments; do not add more, and
  where a comment is rewritten as part of this work, drop the task number rather than carry it
  forward.
- **Re-verify before editing.** Several target files changed earlier in this session. Re-read each
  file and locate the commit site by its surrounding text, never by a line number quoted from the
  research report.

## Goals & Non-Goals

**Goals**:

- No bare (unscoped) `git commit` remains at any commit site in the dispatch pipeline.
- Concurrent `git add` + `git commit` pairs are serialized through a dedicated `specs/.commit-lock/`
  mutex, so path-scoping's `index.lock` failure-rate regression does not land.
- One executable definition of the scoped-commit contract, invoked by every call site.
- The canonical ephemeral-runtime-file exclusion set is applied at every commit site, closing the
  V6 staleness gap (which is broader than `skill-team-implement`).
- The contract is documented in `git-staging-scope.md` and `task-lock.md` so a future audit reads
  the full picture from canonical documents rather than reconstructing it from task artifacts.
- Empirical demonstration under real concurrency: no misattribution **and** no elevated
  commit-failure rate.

**Non-Goals**:

- Per-agent git worktrees (candidate c) — conflicts with `state.json`/`TODO.md` being genuinely
  shared, wholesale-regenerated files.
- Moving commits to the orchestrator (candidate d) — conflicts with the Commit-Per-Green-Substep
  Mandate that `checkpoint-before-overflow.md`'s recovery procedure depends on.
- Changing *what* gets staged (that contract landed with the staging narrowing). This plan changes
  what gets **committed** and how commits are **serialized**.
- Re-syncing or editing `.claude/**`.
- Commit sites outside the dispatch pipeline (`/todo`, `/errors`, `/task`, `/review`,
  `meta-builder-agent`) — single-threaded, user-invoked, not concurrently dispatched.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **V2: a nonexistent path in the commit pathspec aborts the whole commit.** A stale `modified_files` entry (file deleted after being reported) would silently stop committing anything. | H | M | The helper filters the pathspec list before committing: each positive path is validated with `git ls-files --error-unmatch` (or existence check for new files); unmatched entries are **dropped with a loud warning**, never passed through. Exclude pathspecs pass through unvalidated. Phase 3 task; Phase 7 tests it directly. |
| **V3: an exclude-only pathspec list commits wider than a bare commit.** A degenerate `stage_paths` turns the fix into a worse bug. | H | L | The helper **refuses to commit** (exit non-zero, loud message, no commit) if the pathspec list contains zero positive (non-`:(exclude)`) entries. Phase 3 task; Phase 7 asserts the refusal. |
| Mutex acquire timeout under `MAX_TASKS=8` reintroduces the failure it is meant to remove. | M | M | Fail **open** with a loud warning (mirroring `acquire_state_mutex`), never abort the caller — a fail-open commit is still path-scoped, so the worst case is the safe `index.lock` race, not misattribution. Additionally the commit mutex gets a larger acquire budget (15s vs the scope mutex's 5s) sized for 8 concurrent holders, plus one bounded retry of the commit itself. |
| A held commit mutex whose holder dies leaves every committer blocked. | H | L | Reuse the existing holder-declared-staleness reclaim (`stale_sec` file) verbatim; declare `COMMIT_MUTEX_STALE_SEC=30`, generous against measured sub-second commits but short enough to reclaim a genuinely stuck holder. |
| **V9: task 885 (`partial`) declares `orchestrator-postflight.sh`.** Concurrent edits to the same file. | M | L | Declared, not silent. 885's subject is event/signal-capture instrumentation, a different region from the Stage 9 commit block. Before editing that file the implementer MUST re-check 885's status and whether its task lock is held; if held, defer Phase 6's postflight edit, complete the rest of Phase 6, and report the deferral explicitly rather than editing into a live conflict. |
| Converting eleven call sites to a helper changes behavior at sites nobody tested. | M | M | The helper preserves observable behavior at every site: same commit message, same non-blocking failure semantics (V4 confirms exit code 1 is unchanged), same staging inputs. Phase 7 exercises the helper end-to-end before the plan is considered done. |
| The helper is shipped but never deployed because `manifest.json` was not updated. | H | M | `manifest.json` registration is an explicit Phase 3 task with its own verification, not an afterthought. This exact failure has precedent in this codebase. |
| Phases 5 and 6 run in parallel and collide on the git index — the very defect being fixed. | L | M | They edit disjoint file sets (territory contract stated per phase). If dispatched in parallel, each implementer must use the helper shipped in Phase 3 for its own commits. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5, 6 | 4 |
| 6 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Confirm primitives and inventory every commit site [COMPLETED]

**Goal**: Re-confirm the empirical basis in the *current* tree and produce the authoritative,
line-accurate inventory the later phases edit against. Verified Findings V1-V9 were established
during planning; this phase re-checks the ones that gate design choices and turns the inventory
into a durable artifact.

**Tasks**:

- [ ] Re-run the scoped-commit checks in a disposable scratch repo **outside** the task tree
      (session scratchpad), confirming V1 (excludes work on `git commit --`), V2 (nonexistent path
      aborts the commit), V3 (exclude-only commits wider), V4 (nothing-to-commit exits 1), and V5
      (concurrent staged content is left untouched). Record actual command output.
- [ ] Re-grep the source store for every `git commit` in the dispatch pipeline and record file +
      surrounding-heading anchor (never a bare line number) for each. Expected set: 11 sites across
      8 files, per the expansion table.
- [ ] Confirm V6 in the current tree: `grep -rn 'ephemeral_excludes' agent-system/extensions/core/`
      matches only `context/standards/git-staging-scope.md`.
- [ ] Confirm V7 (`skill-implementer-hard/SKILL.md` has no commit site) and that
      `skill-orchestrate/SKILL.md` has none either.
- [ ] Re-check task 885's status and lock state (V9) and record the finding.
- [ ] Write the inventory to `specs/908_.../reports/02_commit-site-inventory.md`.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:

- `specs/908_prevent_git_index_contention_in_parallel_dispatch/reports/02_commit-site-inventory.md` (new) — the inventory

**Verification**:

- The inventory names all 11 sites with a text anchor for each.
- Each of V1-V5 has recorded command output confirming or contradicting it. A contradiction is a
  **stop condition**: report it and do not proceed to Phase 2 on an invalidated premise.

---

### Phase 2: Add the `specs/.commit-lock/` mutex to `task-lock.sh` [COMPLETED]

**Goal**: Parameterize the existing mutex primitive by mutex name and expose
`commit-acquire`/`commit-release`, with byte-identical behavior for every existing
`scope-acquire`/`scope-release`/`cmd_acquire` caller.

**Tasks**:

- [ ] Refactor `acquire_scope_mutex [stale_sec]` into `acquire_named_mutex <mutex_dirname> [stale_sec]`
      carrying the existing logic verbatim (POSIX-atomic `mkdir`, holder-declared `stale_sec` file,
      stale reclaim with WARN, wait loop). Keep `acquire_scope_mutex` as a thin wrapper delegating
      with `.scope-lock`, so `cmd_acquire`'s existing call site is untouched.
- [ ] Do the same for `release_scope_mutex` -> `release_named_mutex <mutex_dirname>` plus a
      preserved `release_scope_mutex` wrapper (`cmd_acquire`'s `trap ... RETURN` must keep working).
- [ ] Parameterize the acquire wait budget, currently hardcoded at 5000ms: `.scope-lock` keeps
      5000ms exactly; the commit mutex uses 15000ms (sized for 8 concurrent holders at ~1.5s each).
- [ ] Add `COMMIT_MUTEX_STALE_SEC=30` alongside the existing `SCOPE_MUTEX_STALE_SEC=10`.
- [ ] Add `cmd_commit_acquire` / `cmd_commit_release` mirroring `cmd_scope_acquire` /
      `cmd_scope_release` exactly — same owner-token format (`session:pid:epoch`), same
      owner-token-verified release with a loud non-silent WARN on mismatch and never a forced
      removal, same "release always exits 0" contract.
- [ ] Register `commit-acquire` / `commit-release` in the CLI dispatch `case` and in the usage
      string; update the top-of-file usage comment block.
- [ ] Use a **distinct** reentrancy flag `COMMIT_MUTEX_HELD` (never `SCOPE_MUTEX_HELD`) — this is
      the whole point of Decision 1. Document the two-flag invariant in the file comments.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/scripts/task-lock.sh` — named-mutex refactor, commit-mutex constants, two new verbs

**Verification**:

- `bash -n` passes.
- `task-lock.sh scope-acquire <sid>` then `scope-release <token>` behaves exactly as before
  (creates/removes `specs/.scope-lock/`, prints a token, honors token mismatch).
- `task-lock.sh commit-acquire <sid>` creates `specs/.commit-lock/` and **not** `specs/.scope-lock/`;
  `commit-release <token>` removes only the former.
- Holding `.scope-lock` does not block `commit-acquire`, and vice versa.
- A second `commit-acquire` while held blocks then times out non-zero after ~15s.
- `commit-release` with a wrong token warns and does **not** remove the directory.
- Clean up both mutex directories after testing.

---

### Phase 3: Ship `git-commit-scoped.sh` and register it [COMPLETED]

**Goal**: One executable definition of the scoped-commit contract.

**Tasks**:

- [ ] Create `agent-system/extensions/core/scripts/git-commit-scoped.sh` with interface
      `git-commit-scoped.sh --message <msg> --session <session_id> [--honest-index-rows <task_number>] -- <pathspec>...`.
- [ ] **Safety gate (V3)**: refuse to run — exit non-zero, loud message, no `git add`, no commit —
      if the pathspec list contains zero positive (non-`:(exclude)`) entries.
- [ ] **Pathspec filtering (V2)**: validate each positive pathspec; drop entries git cannot match,
      each with a loud warning naming the dropped path. Pass exclude pathspecs through unvalidated.
      Re-apply the V3 gate after filtering (filtering can itself produce a degenerate list).
- [ ] Acquire `commit-acquire` with a fail-open-plus-loud-warning fallback mirroring
      `acquire_state_mutex`; honor `COMMIT_MUTEX_HELD` as the guest signal; release via
      `trap ... EXIT` so no path leaks the mutex.
- [ ] Inside the mutex: `git add "${filtered[@]}"` (guarded, warn non-blocking on failure), then the
      optional honest-index-rows scan, then
      `git commit -m "<msg>\n\nSession: <sid>\n" -- "${filtered[@]}"`.
- [ ] Move `orchestrator-postflight.sh`'s Stage 9b honest-commit-message python scan into the helper
      verbatim behind `--honest-index-rows <task_number>`; preserve its total failure-tolerance —
      any error omits the addendum and falls through to the plain message, and it must never break a
      commit. This also makes the addendum available to the other ten sites, which lack it today.
- [ ] Apply the canonical ephemeral-runtime-file exclusion set from `git-staging-scope.md` inside
      the helper when a task directory appears in the pathspec list, so call sites cannot drift out
      of sync again (the V6 fix).
- [ ] Preserve non-blocking semantics: a "nothing to commit" outcome exits 1 with the standard
      note (V4 confirms this matches the bare form), and callers keep their existing `|| echo`
      fallbacks working unchanged.
- [ ] Add one bounded retry (single retry, short randomized backoff) if the commit fails on
      `index.lock` specifically — the residual race when the mutex fails open.
- [ ] Register `git-commit-scoped.sh` in `manifest.json`'s `provides.scripts` array.

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (new)
- `agent-system/extensions/core/manifest.json` — `provides.scripts` registration

**Verification**:

- `bash -n` passes; file is executable.
- In a scratch repo: a normal scoped commit succeeds and commits only the named paths.
- Exclude-only pathspec list is **refused** with no commit created.
- A nonexistent path is dropped with a warning and the commit still succeeds for the valid paths.
- With the mutex pre-held by another process, the helper waits, then fails open with a loud warning
  and still commits (path-scoped).
- `jq -r '.provides.scripts[]' manifest.json | grep git-commit-scoped.sh` matches.

---

### Phase 4: Document the contract in the canonical standards [NOT STARTED]

**Goal**: A future audit reads the full picture from canonical documents.

**Tasks**:

- [ ] Add a section to `context/standards/git-staging-scope.md` — suggested title
      "Commit-Level Path Scoping and Cross-Process Serialization" — stating: every `git commit` in
      the pipeline MUST name its pathspec; a bare `git commit` is added to the Forbidden Operations
      list alongside `git add -A` / `git add .` / `git commit -am`; the `git add` + `git commit`
      pair MUST be serialized through the commit mutex; and `git-commit-scoped.sh` is the single
      sanctioned implementation.
- [ ] Record the two safety rules discovered empirically, since neither is obvious from git's docs:
      an exclude-only pathspec list commits **wider** than a bare commit (V3), and an unmatched path
      in the commit pathspec aborts the whole commit (V2).
- [ ] **Correct the stale claim** in that file's "State-Write Serialization" section: its assertion
      that "Stage 9 and later remain explicitly outside the mutex... a slower git/TTS/cleanup tail
      carries no data-integrity risk worth serializing" was sound when the only committer was a
      single sequential postflight process, and was invalidated by concurrent multi-task dispatch.
      Rewrite it to say Stage 9 stays outside the **state-write** mutex and inside the **commit**
      mutex, so both invariants read as true and the reasoning is not left silently wrong.
- [ ] Extend `context/patterns/task-lock.md`'s "Scope-Mutex CLI" section with the
      `commit-acquire`/`commit-release` sibling: the distinct `specs/.commit-lock/` directory, the
      distinct `COMMIT_MUTEX_HELD` reentrancy flag and why two flags are required, the 30s
      holder-declared staleness, the 15s acquire budget, and the fail-open contract.
- [ ] Update the Related Documentation lists in both files.
- [ ] No task-number citations anywhere in these edits.

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:

- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `agent-system/extensions/core/context/patterns/task-lock.md`

**Verification**:

- Both files describe the shipped helper's actual interface (re-read the helper; do not describe an
  intended one).
- `grep -nE '\btask [0-9]+' ` over both files returns no newly added matches.
- The State-Write Serialization correction leaves no sentence asserting commits are unserialized.

---

### Phase 5: Convert the in-agent, highest-frequency commit sites [NOT STARTED]

**Goal**: Fix the sites where the reported misattribution actually happened.

**Territory** (disjoint from Phase 6): `agents/general-implementation-agent.md`,
`agents/general-implementation-hard-agent.md`, `skills/skill-implementer/SKILL.md`.

**Tasks**:

- [ ] `general-implementation-agent.md` Stage 4B-iii (Green Sub-Step Commit): replace the
      `git add` + bare `git commit` pair with a `git-commit-scoped.sh` invocation, keeping the
      `stage_paths` construction (including the `files_touched` loop) as the pathspec source and the
      commit message unchanged.
- [ ] `general-implementation-agent.md` Phase Checkpoint Protocol step 5: same conversion.
- [ ] `general-implementation-hard-agent.md` Stage 5 Step 2 (final incremental commit): same
      conversion.
- [ ] `skill-implementer/SKILL.md` Stage 6b: same conversion, preserving the `modified_files` loop,
      the zero-count warning, and the existing non-blocking `|| echo "Note: Nothing to commit..."`
      note.
- [ ] `skill-implementer/SKILL.md` Stage 9: same conversion.
- [ ] Update the prose at each site so it describes serialized, path-scoped committing rather than
      the old bare-commit shape — including `skill-implementer` Stage 6b's "Composes with, does not
      duplicate" note and Stage 9's note about parity with `orchestrator-postflight.sh`.
- [ ] No task-number citations in any of these files.

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` — 2 sites
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — 1 site
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — 2 sites

**Verification**:

- `grep -n 'git commit' ` over the three files shows no bare `git commit -m` remaining in a code
  block; every commit goes through the helper.
- Each converted snippet still constructs its site-specific pathspec inputs (`files_touched` /
  `modified_files` / plan path) — the conversion must not drop them.
- Commit messages are byte-identical to before.

---

### Phase 6: Convert the coordinator, planner, and postflight commit sites [NOT STARTED]

**Goal**: Close the remaining sites, including the most-shared one.

**Territory** (disjoint from Phase 5): `skills/skill-planner/SKILL.md`,
`skills/skill-team-implement/SKILL.md`, `commands/orchestrate.md`,
`scripts/orchestrator-postflight.sh`.

**Tasks**:

- [ ] **First**: re-check task 885's status and lock state (V9). If its lock is held, defer only the
      `orchestrator-postflight.sh` edit, complete every other task in this phase, and report the
      deferral explicitly — do not edit into a live conflict and do not silently skip it.
- [ ] `skill-planner/SKILL.md` Stage 9: convert to the helper (genuinely concurrent under
      multi-task `/plan`).
- [ ] `skill-team-implement/SKILL.md` Stage 10 (per-wave): convert to the helper. This also closes
      its V6 staleness gap, since the helper applies the canonical exclusion set.
- [ ] `skill-team-implement/SKILL.md` Stage 14 (final): same conversion.
- [ ] `commands/orchestrate.md` CHECKPOINT 3 (single-task) and Step 5 (multi-task batch): convert
      both. These are sequential within the orchestrator thread, so this is defense-in-depth and
      consistency, not a fix for an observed collision — say so in the prose rather than
      overstating it.
- [ ] `orchestrator-postflight.sh` Stage 9: replace the `git add` + Stage 9b scan + bare
      `git commit` block with a `git-commit-scoped.sh --honest-index-rows "$task_number"` call.
      Keep the state-write mutex release at its current boundary — Stage 9 still runs outside
      `.scope-lock` and now inside `.commit-lock`.
- [ ] Update the comment block above Stage 9 to describe the new two-mutex arrangement accurately.
- [ ] No task-number citations in any of these files.

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:

- `agent-system/extensions/core/skills/skill-planner/SKILL.md` — 1 site
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` — 2 sites
- `agent-system/extensions/core/commands/orchestrate.md` — 2 sites
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — 1 site

**Verification**:

- `bash -n agent-system/extensions/core/scripts/orchestrator-postflight.sh` passes.
- No bare `git commit -m` remains in any code block in these four files.
- The honest-index-rows addendum still appears in postflight commit messages (exercised in Phase 7).
- Any deferral of the postflight edit is stated explicitly, with 885's observed lock state.

---

### Phase 7: Demonstrate the fix under real concurrency [NOT STARTED]

**Goal**: Empirically show both that misattribution is gone **and** that the `index.lock`
failure-rate regression the research measured does not land.

**Tasks**:

- [ ] Build a disposable scratch repo **outside** the task tree (session scratchpad), with the
      shipped `task-lock.sh` and `git-commit-scoped.sh` copied in and a `specs/`-shaped layout so
      the mutex paths resolve.
- [ ] **Baseline (control)**: 30 iterations of two simultaneous *bare* `git add` + `git commit`
      pairs on disjoint paths. Record the misattribution rate — commits whose diff contains the
      other process's path. Expect a substantial nonzero rate; this is the defect.
- [ ] **Path-scoping only**: 30 iterations of two simultaneous `git commit -- <paths>` calls with no
      mutex. Record misattribution rate (expect 0) and the `index.lock` failure rate (research
      measured ~50%). This reproduces the research's Test 5 and justifies why the mutex is needed.
- [ ] **Full fix**: 30 iterations of two simultaneous `git-commit-scoped.sh` invocations. Record
      misattribution rate (expect 0) **and** commit-failure rate (expect ~0, materially below the
      path-scoping-only arm).
- [ ] Scale to 8 concurrent committers (matching `MAX_TASKS=8`) for one run and record the
      failure rate and worst-case wall-clock wait, to check the 15s acquire budget is adequate.
- [ ] Assert the two safety gates under concurrency: exclude-only refusal (V3) and unmatched-path
      dropping (V2).
- [ ] Assert the honest-index-rows addendum still renders when `--honest-index-rows` is passed.
- [ ] Confirm the mutex directory is never leaked: after all runs,
      `ls specs/.commit-lock specs/.scope-lock` finds neither.
- [ ] Record all three arms' numbers in the implementation summary as a comparison table. If the
      full-fix arm's failure rate is not materially better than the path-scoping-only arm, that is a
      **stop condition** — report it rather than declaring success.
- [ ] Destroy the scratch repo.

**Timing**: 1.5 hours

**Depends on**: 5, 6

**Files to modify**:

- `specs/908_prevent_git_index_contention_in_parallel_dispatch/summaries/01_git-index-contention-summary.md` — the three-arm comparison table

**Verification**:

- Three arms measured with real numbers, not asserted.
- Full-fix arm: 0 misattributions and a failure rate materially below the path-scoping-only arm.
- Both safety gates fire as designed under concurrency.
- No mutex directory left behind; scratch repo removed.

---

## Testing & Validation

- [ ] `bash -n` on `task-lock.sh`, `git-commit-scoped.sh`, `orchestrator-postflight.sh`.
- [ ] Existing `scope-acquire`/`scope-release` behavior is byte-for-byte unchanged (Phase 2).
- [ ] `.scope-lock` and `.commit-lock` are mutually non-blocking (Phase 2).
- [ ] `git-commit-scoped.sh` is registered in `manifest.json` `provides.scripts` (Phase 3).
- [ ] No bare `git commit -m` remains in any dispatch-pipeline code block across all eight edited
      files (Phases 5, 6).
- [ ] Commit messages at every converted site are unchanged from before.
- [ ] `grep -nE '\btask(s)? [0-9]+' ` over every edited file outside `specs/**` shows no
      newly added task-number citations.
- [ ] Three-arm concurrency comparison recorded with real measured numbers (Phase 7).
- [ ] No edits landed under `.claude/**`; `.claude/` was not re-synced.

## Artifacts & Outputs

- `specs/908_.../plans/01_git-index-contention.md` (this file)
- `specs/908_.../reports/02_commit-site-inventory.md` (Phase 1)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (new, Phase 3)
- Modified: `scripts/task-lock.sh`, `scripts/orchestrator-postflight.sh`, `manifest.json`,
  `context/standards/git-staging-scope.md`, `context/patterns/task-lock.md`,
  `agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md`,
  `skills/skill-implementer/SKILL.md`, `skills/skill-planner/SKILL.md`,
  `skills/skill-team-implement/SKILL.md`, `commands/orchestrate.md`
- `specs/908_.../summaries/01_git-index-contention-summary.md` (Phase 7)

## Rollback/Contingency

Every phase is a separate commit, so rollback is per-phase `git revert`. The dependency chain makes
the safe rollback order the reverse of the wave order: revert call-site conversions (5, 6) before
the helper (3), and the helper before the mutex parameterization (2). Phase 4's documentation edits
are independently revertable.

Partial-landing safety: if the work stops after Phase 3, nothing has changed behaviorally — the
helper exists and is registered but no call site invokes it, and `task-lock.sh`'s new verbs are
additive with the existing ones unchanged. The first behavioral change lands in Phase 5. If Phase 7
finds the full-fix arm no better than path-scoping alone, revert Phases 2 and 3's mutex usage (keep
the path-scoping, which V5 proves fixes the reported defect on its own) and record the mutex as a
tried-and-rejected mitigation rather than leaving a serialization layer that buys nothing.
