# Implementation Plan: Task #923

- **Task**: 923 - reap_stale_task_locks
- **Status**: [IMPLEMENTING]
- **Effort**: 4.75 hours
- **Dependencies**: None (the sibling `resolve_task_dir` / `create_mode` change is COMPLETE and already present in the source-store file)
- **Research Inputs**: `specs/923_reap_stale_task_locks/reports/01_reap-stale-task-locks.md`
- **Artifacts**: plans/01_reap-stale-task-locks.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a tenth subcommand, `reap`, to `agent-system/extensions/core/scripts/task-lock.sh`, wire it
into `/refresh` as its sole caller, prove it with an isolated-temp-root test fixture, and record
the threshold derivation and the correction to this task's own premise in the canonical
`task-lock.md` contract doc. The reaper is explicit-only (never invoked from
acquire/check/heartbeat/release), supports `--dry-run`, reports every reaped lock per-item rather
than removing it silently, and sweeps deep enough to reach the archived orphans that the existing
`find_held_locks()` helper structurally cannot see.

The design goal is to convert a permanently-repeating warning into a one-time, actionable,
reported event — because a warning that never stops being emitted trains the reader to ignore
lock warnings, which is what makes a genuine conflict indistinguishable from accumulated noise.

### Source-Store Rule (binding, applies to every phase)

The source of truth is `agent-system/extensions/core/`. `.claude/` is a GITIGNORED, DISPOSABLE
deploy artifact. **Every edit in every phase below MUST target `agent-system/extensions/**` and
MUST NEVER target `.claude/**`.** Reading `.claude/` to observe deployed behavior is permitted;
writing to it is not. Verification steps that must *execute* a script run the deployed copy after
a redeploy, never an edited `.claude/` file.

### Research Integration

The plan implements the research report's Design (a) recommendation and adopts its threshold
reasoning, its `find` depth correction, and its improved-reporting requirement. Four findings from
the report shape the phase structure directly:

1. `find_held_locks()` hardcodes `-mindepth 2 -maxdepth 2` and therefore cannot see
   `specs/archive/{NNN}_{slug}/.lock` (depth 3). The reaper must NOT call it verbatim.
2. `age_minutes()` and `read_holder_field()` encode GNU/BSD-portable `date` parsing that exists
   only in `task-lock.sh` — this is what makes Design (a) (subcommand in the script) correct and
   Design (b) (sweep inside the refresh skill's markdown bash) wrong.
3. `/refresh`'s existing marker sweep under-reports on the live-delete path (generic one-liner
   only, per-item paths shown in dry-run only). The reap step must improve on that baseline, not
   copy it.
4. `/refresh`'s hourly systemd timer runs only `claude-refresh.sh` (process cleanup), not the
   `specs/` sweep in `skill-refresh/SKILL.md`.

### Correction to the Task's Own Premise (CONSTRAINT 2, restated)

The task description's CONSTRAINT 2 requires that reaping "honor the holder-declared staleness
window written into the lock directory." **No such field exists for the task-number lock.**
Verified against `write_holder()` and the canonical schema: `.lock/holder.json` contains exactly
`session_id`, `task_number`, `operation`, `acquired_at`, `heartbeat_at`, `command` — and nothing
else. Staleness for the task-number lock is governed entirely by the global, env-overridable
`TASK_LOCK_STALE_MIN` (default 30), read fresh by every caller at call time.

The confusion is traceable: the two NAMED mutexes (`.scope-lock`, `.commit-lock`) *do* genuinely
write a `stale_sec` file into their own mutex directory at acquire time, and every later waiter
reads that file. Those are holder-declared in the literal sense. The task-number lock is not.

**Resolution adopted by this plan** (neither inventing the missing field nor silently dropping the
constraint): the reaper derives its threshold from the *same* `TASK_LOCK_STALE_MIN` constant every
other caller already reads, so all participants share one window. This preserves the constraint's
actual intent — "one shared window, not a fresh caller-chosen threshold" — via the mechanism that
actually exists. Phase 4 requires this correction and its resolution to be written into
`task-lock.md`, so a future reader finds the decision record in the canonical doc rather than only
here.

**MUST NOT**: add a `stale_sec`, `reap_after`, or any other staleness field to
`.lock/holder.json`. Doing so would fork the task-number lock's schema away from its canonical
spec to satisfy wording that was mistaken about the current state of the code.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no `roadmap_flag` was set, so no
roadmap phases are included and `specs/ROADMAP.md` is not consulted or modified by this plan.

## Goals & Non-Goals

**Goals**:
- A `reap` subcommand in `task-lock.sh` that removes stale `.lock` directories under `specs/`,
  including those under `specs/archive/`.
- A threshold argued from the real, checkpoint-based heartbeat cadence — with the reasoning
  shipped in the documentation, not merely in this plan.
- `--dry-run` support consistent with `/refresh`'s existing dry-run flag.
- Per-lock reporting (task number, session id, operation, age) on both the dry-run and live paths.
- `/refresh` as the sole caller, added as a new step alongside — not merged into — the existing
  postflight-marker sweep.
- A test fixture, in an isolated temp root, proving the four required behaviors.
- The constraint-2 correction, the archive-depth decision, and the systemd-timer scoping fact all
  recorded in `task-lock.md`.

**Non-Goals**:
- Changing the behavior of `acquire`, `heartbeat`, `release`, `check`, or the two named mutexes.
  Their code paths are read-only for this task except for the additive usage-comment line.
- Adding any staleness field to `.lock/holder.json` (see the correction above).
- Widening `find_held_locks()`'s depth. Its `-maxdepth 2` is load-bearing for `cmd_acquire`'s
  cross-task overlap scan (an archived task has no active `file_scope` to overlap with, so
  widening it would add work and no signal). The reaper gets its own `find`; `find_held_locks()`
  is left byte-identical.
- Wiring reap into the hourly systemd timer. Phase 3 records the scoping consequence; changing the
  timer's payload is a separable decision.
- Reaping the `.scope-lock` / `.commit-lock` named mutexes. They already self-expire via their own
  holder-declared `stale_sec`, and they sit at `specs/.scope-lock` (depth 1), structurally
  excluded by the reaper's `-mindepth 2 -name ".lock"` glob.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Reaping a live lock held by a legitimately long dispatch | H | L | Threshold is 4x the acquire-override threshold (120 min default); every observed real data point (433, 582, 920, 17500, 18700 min) clears it by >3.5x. Reap is explicit-invocation only, never on a timer today. |
| Copy-pasting `find_held_locks()` into the reaper and silently reinheriting `-maxdepth 2` | H | M | Phase 1 verification explicitly asserts the reaper finds a depth-3 lock; the test fixture in Phase 2 places one under an `archive/` subdirectory. |
| Reap report regresses to `/refresh`'s weaker generic-one-liner convention "for consistency" | M | M | Per-lock report format is specified in Phase 1 and asserted by a Phase 2 test case that greps for the task number and age in live-mode output. |
| Racing a lock mid-creation (`mkdir` done, `holder.json` not yet written) | M | L | A `.lock` with missing/unparseable `holder.json` is reaped only when the lock *directory's own mtime* also exceeds the threshold; otherwise it is reported as skipped, never removed. |
| An implementer edits `.claude/scripts/task-lock.sh` instead of the source store | H | M | Source-store rule restated at the top of this plan and in every phase's task list; Phase 1 verification includes a `git status` check that no `.claude/` path is modified. |
| A new script file is added but not registered in the core manifest, so it never deploys | M | M | Phase 2 includes manifest registration in `provides.scripts` and verifies via `jq`. |
| Task-number citations leak into shipped deliverables | L | M | Every phase carries an explicit MUST NOT; Phase 4 verification greps the changed non-`specs/` files for `task [0-9]` patterns. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(Phase 2: a new test script + `manifest.json`; Phase 3: `skill-refresh/SKILL.md` +
`commands/refresh.md`) and may run concurrently.

---

### Phase 1: Add the `reap` subcommand to `task-lock.sh` [COMPLETED]

**Goal**: `task-lock.sh reap [--dry-run]` exists, sweeps every `.lock` under `specs/` to depth 3,
removes those past the reap threshold, and reports each one per-item.

**Tasks**:
- [x] Edit `agent-system/extensions/core/scripts/task-lock.sh` (source store only — never
      `.claude/scripts/task-lock.sh`).
- [x] Add a threshold constant next to the existing `TASK_LOCK_STALE_MIN` assignment:
      `TASK_LOCK_REAP_MIN="${TASK_LOCK_REAP_MIN:-$(( TASK_LOCK_STALE_MIN * 4 ))}"`. Directly
      settable, but derived from `TASK_LOCK_STALE_MIN` when unset, so the two thresholds stay
      proportionate if a caller raises the base. Add a comment stating that this proportional
      movement is intentional, not a bug.
- [x] Add `cmd_reap()` following the existing function style (bash locals, `jq` reads via
      `read_holder_field`, no `set -e` reliance).
- [x] Argument handling: `reap [--dry-run]`. No task-number argument — reap sweeps all locks, per
      `/refresh`'s existing "sweep everything under `specs/`" shape. Reject any unrecognized
      argument with a usage line and exit 2.
- [x] Sweep with a **dedicated** `find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 3 -type d -name
      ".lock"`. Do **NOT** call `find_held_locks()` — its `-maxdepth 2` cannot reach
      `specs/archive/{NNN}_{slug}/.lock`. Leave `find_held_locks()` itself unmodified.
- [x] For each match: read `heartbeat_at` via `read_holder_field`, compute age via `age_minutes`,
      compare against `TASK_LOCK_REAP_MIN`. Reuse both helpers rather than reimplementing the
      GNU/BSD `date` parsing.
- [x] Missing/unparseable `holder.json`: fall back to the `.lock` directory's own mtime. Reap only
      if that mtime age also exceeds the threshold; otherwise emit a `SKIP:` line naming the path
      and the reason, and leave it in place. This closes the mkdir-then-write race window.
- [x] Removal: `rm -rf` the `.lock` directory (live mode only).
- [x] Report format, emitted on **both** paths — one line per lock, naming task number, session
      id, operation, and age in minutes. Dry-run lines read `would reap`; live lines read
      `reaped`. This deliberately exceeds `/refresh`'s existing marker-sweep convention, which
      shows per-item paths in dry-run only and a generic one-liner after an actual delete.
- [x] Emit a trailing summary count. When nothing qualifies, emit an explicit "no stale locks
      found" line rather than silence.
- [x] Exit 0 whether or not anything was reaped; exit 2 on usage error.
- [x] Add a `reap)` case to the dispatch `case "$SUBCMD"` block and add
      `task-lock.sh reap [--dry-run]` to the top-of-file `# Usage:` comment block.
- [x] Update the catch-all `*)` branch's usage line to include `reap` in its subcommand list.
- [x] Add NO call to `cmd_reap` from `cmd_acquire`, `cmd_heartbeat`, `cmd_release`, or `cmd_check`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes (a) the dispatch block currently has exactly nine
subcommand cases plus a catch-all, and (b) `-maxdepth 3` is sufficient — i.e. no `.lock` directory
exists at depth 4 or deeper under `specs/`. Confirm both at implementation time: count the `case`
branches in the file before editing, and run
`find specs -mindepth 2 -maxdepth 6 -type d -name ".lock"` against the live tree, verifying every
hit is at depth 2 or 3. If a deeper hit appears, widen the constant and record why in the Phase 4
doc rather than silently changing the number.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - new `TASK_LOCK_REAP_MIN` constant, new
  `cmd_reap()`, new dispatch case, updated usage comment and catch-all usage line

**Verification**:
- `bash -n agent-system/extensions/core/scripts/task-lock.sh` exits 0.
- `shellcheck` on the file introduces no new findings relative to a pre-edit baseline run.
- Redeploy, then from the deployed copy: `.claude/scripts/task-lock.sh` with no arguments prints a
  usage line containing `reap`, and `.claude/scripts/task-lock.sh reap --dry-run` runs to exit 0
  and lists the live `specs/archive/*/.lock` orphans (a depth-3 result — this is the direct proof
  that `-maxdepth 2` was not reinherited).
- `git diff --stat` shows changes only under `agent-system/extensions/**`; `git status --short`
  shows no modified path beginning with `.claude/`.
- `grep -n 'cmd_reap' agent-system/extensions/core/scripts/task-lock.sh` shows the definition and
  the dispatch case, and no occurrence inside `cmd_acquire`/`cmd_heartbeat`/`cmd_release`/
  `cmd_check`.

**MUST NOT**: cite a task number in any comment added to `task-lock.sh` (durable anchors only —
reference `context/patterns/task-lock.md` and its section names instead).

---

### Phase 2: Test fixture proving the four required behaviors [NOT STARTED]

**Goal**: An executable, self-contained test script proves the reaper's contract against an
isolated temp root, never the real `specs/` tree.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/test-task-lock-reap.sh`, following the naming
      convention of the existing `check-*.sh` / `verify-*.sh` scripts in that directory.
- [ ] Build the temp root so it satisfies `deploy-root-guard.sh`. That guard requires the script's
      parent directory to be named `.claude` or `.opencode` — so the fixture must lay out
      `$TMPROOT/.claude/scripts/` (copying in `task-lock.sh` and `deploy-root-guard.sh`) and
      `$TMPROOT/specs/`. This is what makes an isolated temp root work with zero testability hooks
      added to production code; do not add a `PROJECT_ROOT` override to `task-lock.sh` to work
      around it.
- [ ] Seed `$TMPROOT/specs/state.json` with the `active_projects` entries the fixture's task
      directories need, so `resolve_task_dir` and `get_file_scope` resolve normally.
- [ ] Create fixture locks by writing `holder.json` directly with controlled `heartbeat_at` /
      `acquired_at` timestamps (fresh = now; stale = well past the threshold), rather than by
      sleeping.
- [ ] Place at least one stale fixture lock at **depth 3** under `$TMPROOT/specs/archive/`, so a
      reinherited `-maxdepth 2` fails the suite rather than passing silently.
- [ ] Test case (a): a fresh lock (heartbeat_at = now) is NOT reaped — assert the directory still
      exists after a live `reap` and that its path does not appear in the output.
- [ ] Test case (b): a stale lock IS reaped AND reported — assert the directory is gone AND that
      live-mode stdout contains that lock's task number and an age figure.
- [ ] Test case (c): `reap --dry-run` removes nothing — assert every fixture lock directory still
      exists after the dry run, and that the output names the stale ones as `would reap`.
- [ ] Test case (d): `acquire`, `check`, `heartbeat`, and `release` never reap implicitly — run
      each of the four against the fixture root while a stale foreign lock is present, then assert
      the stale foreign lock directory is still present after all four.
- [ ] Add a case covering the missing/corrupt-`holder.json` skip-vs-reap branch from Phase 1.
- [ ] `trap`-based cleanup of the temp root on exit, including on failure.
- [ ] Print a per-case PASS/FAIL line and exit non-zero if any case fails.
- [ ] Register the new script in `agent-system/extensions/core/manifest.json` under
      `provides.scripts` so it actually deploys.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly five test cases (the four required behaviors plus
the corrupt-holder branch) and assumes `deploy-root-guard.sh` and `task-lock.sh` are the only two
files that must be copied into the temp `.claude/scripts/`. Confirm the second at implementation
time by running the fixture and reading any "no such file" error, then copying whatever additional
sourced helper the guard-satisfying layout turns out to need — do not assume the two-file list is
complete without running it.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-task-lock-reap.sh` - new test fixture
- `agent-system/extensions/core/manifest.json` - register the new script in `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0 with all cases PASS.
- The suite is proven to have teeth: temporarily change the reaper's `find` to `-maxdepth 2`,
  re-run, confirm the archive-depth case FAILS, then revert. Record that this negative check was
  performed.
- `find /tmp -maxdepth 2 -name '*task-lock-reap*'` (or the fixture's chosen temp prefix) returns
  nothing after a successful run, proving cleanup.
- `git status --short specs/` shows no change to the real `specs/` tree caused by running the
  suite.
- `jq -r '.provides.scripts[]' agent-system/extensions/core/manifest.json | grep -q
  'test-task-lock-reap.sh'` succeeds.

**MUST NOT**: point the fixture at the real `specs/` tree, or reap any real `.lock` directory as a
side effect of running tests. The three live archive orphans are useful *validation material* for
the Phase 1 dry-run check only — the automated suite must never touch them.

---

### Phase 3: Wire `reap` into `/refresh` as its sole caller [NOT STARTED]

**Goal**: `/refresh` invokes `task-lock.sh reap`, honoring its existing `dry_run` flag, and the
command doc advertises the new cleanup.

**Tasks**:
- [ ] Edit `agent-system/extensions/core/skills/skill-refresh/SKILL.md`: add a new step for the
      lock reap, placed **alongside** (not merged into) the existing
      `### Step 3: Clean Orphaned Postflight Markers`. Renumber the following steps accordingly.
- [ ] Reuse the `dry_run` boolean already threaded from `### Step 1: Parse Arguments`. Add no new
      argument parsing.
- [ ] The step's bash block calls `.claude/scripts/task-lock.sh reap` with `--dry-run` appended
      when `dry_run` is true, and echoes the subcommand's output verbatim — the per-lock detail is
      produced by the script, so the skill must not summarize it away.
- [ ] Edit `agent-system/extensions/core/commands/refresh.md`: add a row or subsection under
      `## What It Cleans` covering stale task locks under `specs/`, since that section currently
      documents only the `~/.claude/` process/directory cleanup and omits the `specs/` sweep
      entirely.
- [ ] In the same `refresh.md` addition, state plainly that this cleanup runs only on explicit
      `/refresh` invocation and is **not** on the hourly systemd cadence, because
      `claude-refresh.timer` invokes `claude-refresh.sh` (process cleanup) and not the skill's
      `specs/` sweep. Recording this is required, not optional — an operator who assumes hourly
      reaping will misread a surviving orphan as a reaper bug.
- [ ] **Decision to record**: this scoping limitation is accepted for now. Reap is a
      lower-frequency, higher-consequence operation than process cleanup, and the 120-minute
      threshold plus explicit invocation is the intended conservative posture. Moving it onto the
      timer is a separable change and is out of scope here.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `skill-refresh/SKILL.md` currently has exactly six
`### Step N` headings and that inserting one new step requires renumbering the steps after the
insertion point. Confirm by grepping `'^### Step'` before and after the edit and checking the
resulting sequence is gapless and monotonic.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - new reap step, subsequent steps
  renumbered
- `agent-system/extensions/core/commands/refresh.md` - `## What It Cleans` entry plus the
  systemd-cadence scoping note

**Verification**:
- `grep -n '^### Step' agent-system/extensions/core/skills/skill-refresh/SKILL.md` shows a
  gapless, monotonic `1..7` sequence with no duplicate numbers.
- `grep -n 'task-lock.sh reap' agent-system/extensions/core/skills/skill-refresh/SKILL.md`
  matches, and the surrounding block references the `dry_run` variable rather than parsing
  arguments again.
- Redeploy, then run the deployed `/refresh --dry-run` path end-to-end and confirm the reap
  section appears in the output and removes nothing (`find specs -mindepth 2 -maxdepth 3 -type d
  -name .lock | wc -l` is unchanged before and after).
- `grep -in 'systemd\|timer\|hourly' agent-system/extensions/core/commands/refresh.md` matches the
  new scoping note.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0.

**MUST NOT**: cite a task number in `SKILL.md` or `refresh.md` (both live outside `specs/`).

---

### Phase 4: Document the Reap Contract in `task-lock.md` [NOT STARTED]

**Goal**: The canonical pattern doc carries the reap contract, the threshold derivation, and the
constraint-2 correction — so a future maintainer re-derives rather than guesses.

**Tasks**:
- [ ] Edit `agent-system/extensions/core/context/patterns/task-lock.md`. Add a `## Reap Contract`
      section mirroring the existing per-subcommand contract sections in structure (signature,
      arguments, exit codes, dry-run behavior, output format).
- [ ] Document the threshold **with its reasoning written down**, not just its value. The
      reasoning that must appear: heartbeat cadence is checkpoint-based, not timer-based —
      `skill-orchestrate` heartbeats once per state-machine cycle and the implementation agent
      once per phase transition, so a single dispatch can run unheartbeated for an extended
      stretch. `TASK_LOCK_STALE_MIN` (30-60 min) is already the point at which the system lets a
      competing same-task `acquire` steal the lock. Reap is more consequential than an optimistic
      single-acquirer override — it runs unattended and is meant to be the final word that a lock
      is dead — so it sits at a firm multiple above, not equal to, the override threshold.
- [ ] **Answer CONSTRAINT 5 explicitly in the doc**: name the point at which a stale heartbeat
      stops being ambiguous. State the override-eligible band (past `TASK_LOCK_STALE_MIN`, stealable
      by a competing same-task acquire, NOT reap-eligible) versus the reap-eligible band (past
      `TASK_LOCK_REAP_MIN`, unambiguously dead). Name this asymmetry as intentional and explain
      why the two thresholds must differ.
- [ ] Record the observed evidence that calibrates the threshold: the two warning-generating locks
      at 582 and 920 minutes and the three live archive orphans at roughly 433, 17,500, and 18,700
      minutes — every one clearing the 120-minute default by more than 3.5x. Describe them by
      their durable characteristics (archived task directories, foreign-lock overlap warnings),
      not by task number.
- [ ] Record the CONSTRAINT 2 correction and its resolution (see this plan's "Correction to the
      Task's Own Premise"): the task-number lock has no per-lock staleness field; the reaper reads
      the same `TASK_LOCK_STALE_MIN` every other caller reads; the `.scope-lock`/`.commit-lock`
      `stale_sec` field is the genuine holder-declared case and is the likely source of the
      confusion. Cross-reference the doc's existing `### Holder-Declared Staleness` sections so a
      reader can see the contrast directly.
- [ ] Record the archive-depth decision and its reasoning: the reaper sweeps to depth 3 to reach
      `specs/archive/{NNN}_{slug}/.lock`; `find_held_locks()` deliberately stays at depth 2
      because an archived task has no active `file_scope` and therefore contributes no overlap
      signal to `cmd_acquire`'s scan. State that these two depths are intentionally different.
- [ ] Record the never-implicit invariant (CONSTRAINT 1): reap is never reachable from
      `acquire`/`heartbeat`/`release`/`check`. Note that the "never touch the foreign lock" rule
      governs only `cmd_acquire`'s cross-task `file_scope` overlap scan and is preserved unchanged
      — the separate same-task stale-override branch, which does mutate a lock, only ever touches
      the acquiring task's own lock and is likewise unchanged.
- [ ] Record that `TASK_LOCK_REAP_MIN` moving proportionally when `TASK_LOCK_STALE_MIN` is
      overridden is intentional, so it is not mistaken for a bug in review.
- [ ] Add `reap` to the doc's subcommand enumeration and add `/refresh`'s reap step to its
      `### Consumers` section as the sole intended caller.
- [ ] Note in the Consumers entry that this caller is not on the hourly systemd cadence
      (consistent with Phase 3's `refresh.md` note).

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - new `## Reap Contract` section,
  updated subcommand enumeration, updated `### Consumers`

**Verification**:
- Diff read-through confirms every changed hunk is markdown prose with no executable surface.
- `grep -n '^#\{1,3\} ' agent-system/extensions/core/context/patterns/task-lock.md` shows the new
  `## Reap Contract` heading in a sensible position relative to the existing contract sections.
- The doc's stated signature, flags, exit codes, and output format match the shipped `cmd_reap()`
  implementation exactly — verify by reading the two side by side, not by assuming.
- Every cross-reference added resolves: each referenced section heading exists in the target file.
- `grep -nE 'task [0-9]+|tasks [0-9]+' <changed non-specs files>` returns no NEW matches relative
  to the pre-edit baseline (pre-existing citations elsewhere in these files are out of scope for
  this task and must not be edited as a drive-by).
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0.

**MUST NOT**: cite a task number anywhere in the added prose. Anchor on durable references —
`context/patterns/task-lock.md` section names, `skill-refresh/SKILL.md` step names, the constant
names `TASK_LOCK_STALE_MIN` / `TASK_LOCK_REAP_MIN`.

---

## Testing & Validation

- [ ] `bash -n` clean on `task-lock.sh` and the new test script.
- [ ] `shellcheck` introduces no new findings on either shell file.
- [ ] All five fixture cases PASS, and the negative check (temporarily reverting to `-maxdepth 2`
      makes the archive-depth case FAIL) was performed and recorded.
- [ ] Fresh lock survives a live reap (case a).
- [ ] Stale lock is removed AND its task number and age appear in live-mode output (case b).
- [ ] `--dry-run` leaves every fixture lock in place (case c).
- [ ] `acquire`/`check`/`heartbeat`/`release` leave a stale foreign lock untouched (case d).
- [ ] `/refresh --dry-run` end-to-end shows the reap section and removes nothing.
- [ ] `check-extension-docs.sh` exits 0.
- [ ] `git status --short` shows zero modified paths under `.claude/` across all phases.
- [ ] `validate-artifact.sh` on this plan reports no per-phase missing-tier warnings.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` (modified) — `reap` subcommand,
  `TASK_LOCK_REAP_MIN` constant
- `agent-system/extensions/core/scripts/test-task-lock-reap.sh` (new) — isolated-temp-root suite
- `agent-system/extensions/core/manifest.json` (modified) — script registration
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` (modified) — new reap step
- `agent-system/extensions/core/commands/refresh.md` (modified) — `What It Cleans` entry +
  systemd-cadence scoping note
- `agent-system/extensions/core/context/patterns/task-lock.md` (modified) — `## Reap Contract`

Note: the task's declared `file_scope` in `state.json` lists four files; this plan adds two more
(`test-task-lock-reap.sh`, `manifest.json`). `file_scope` is descriptive rather than validated, so
this is not a blocker, but the implementer should be aware the declared footprint understates the
actual one.

## Rollback/Contingency

Every change is additive and confined to `agent-system/extensions/core/`. Rollback is
`git checkout` of the six files above followed by a redeploy; no existing subcommand's behavior,
no `holder.json` schema, and no `find_held_locks()` call site is altered, so reverting cannot
leave the lock system in a mixed state.

If the reaper is found to be removing locks it should not, the fastest mitigation without a code
revert is to raise the threshold via the `TASK_LOCK_REAP_MIN` env var at the `/refresh` call site
— the reaper reads it fresh on every invocation. If reap must be disabled outright, remove the
single reap step from `skill-refresh/SKILL.md`; the subcommand then has no caller and is inert,
because nothing in `acquire`/`heartbeat`/`release`/`check` ever reaches it.
