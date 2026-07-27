# Research Report: Task #923

**Task**: 923 - reap_stale_task_locks
**Started**: 2026-07-27T17:20:00Z
**Completed**: 2026-07-27T17:40:00Z
**Effort**: medium (one new subcommand + one new /refresh step + one doc update)
**Dependencies**: None remaining (sibling `create_mode`/`resolve_task_dir` change is COMPLETE and already reflected in the current file)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/task-lock.sh` (843 lines, read in full)
- `agent-system/extensions/core/context/patterns/task-lock.md` (canonical spec, read in full)
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` (Step 3 "Clean Orphaned Postflight Markers")
- `agent-system/extensions/core/commands/refresh.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 3, heartbeat call site)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (heartbeat note)
- `agent-system/extensions/core/systemd/claude-refresh.timer`, `claude-refresh.service`, `scripts/claude-refresh.sh`
- Live filesystem evidence: `specs/**/.lock/holder.json`, `specs/state.json`, `.gitignore`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `scripts/task-lock.sh` has exactly nine subcommands (`acquire, heartbeat, release, check,
  init-marker, scope-acquire, scope-release, commit-acquire, commit-release`) — confirmed
  against both the dispatch `case` block and the top-of-file usage comment. No `reap`, `gc`,
  `prune`, or `list` subcommand exists anywhere in the file.
- The literal "never touch the foreign lock" rule is the comment at line 428, `# Stale
  overlapping foreign lock: warn and proceed. Never touch the foreign lock.` — it governs only
  the **cross-task `file_scope` overlap scan inside `cmd_acquire`** (the `find_held_locks` loop,
  lines ~404-432), not the task's-own-lock override branch a few lines earlier (lines 462-474),
  which DOES mutate a stale lock — but only when it is the SAME task number, overridden by a
  DIFFERENT session's fresh `acquire` call. These are two different code paths with two
  different mutation policies; only the cross-task foreign-lock path is absolutely read-only.
- **There is no per-lock "holder-declared staleness window" field for the task-number lock.**
  `holder.json` contains only `session_id, task_number, operation, acquired_at, heartbeat_at,
  command` — no `stale_sec`/staleness field. Staleness for `.lock/holder.json` is governed
  entirely by the global, env-overridable `TASK_LOCK_STALE_MIN` (default 30, script line 114),
  read fresh by whichever process calls `acquire`/`check`. This is different from the
  `.scope-lock`/`.commit-lock` NAMED mutexes, which genuinely do write their own `stale_sec`
  into the mutex directory at acquire time (`acquire_named_mutex`, lines 290-329) — those two
  ARE literally "holder-declared, written into the lock directory." Constraint 2 ("honor the
  holder-declared staleness window ... not a fresh caller-chosen threshold") is best satisfied,
  for the task-number lock specifically, by having the reaper read the SAME `TASK_LOCK_STALE_MIN`
  constant every other subcommand already reads — not by inventing an unrelated threshold — while
  documenting that this is the closest available equivalent, not a literal per-lock field.
- Design (a) — add a `reap`/`prune` subcommand to `task-lock.sh` — is the evidence-backed choice.
  `age_minutes()` and `read_holder_field()` are genuinely reusable (platform-sensitive GNU/BSD
  `date` parsing lives only here), but the existing `find_held_locks()` helper is **not**
  directly reusable as-is: it hardcodes `-mindepth 2 -maxdepth 2`, which misses locks that live
  deeper than one task-directory level under `specs/` — confirmed live in this repo, where three
  orphaned `.lock/` directories sit under `specs/archive/{NNN}_{slug}/.lock` (depth 3, invisible
  to `find_held_locks`). A reaper needs its own wider glob (depth 3, matching `/refresh`'s own
  `-maxdepth 3` convention for `.postflight-pending`), while still reusing the age/holder-read
  primitives.
- **Live evidence in this repo (research focus point 6)**: four `.lock/` directories currently
  exist under `specs/`. One (`specs/923_.../​.lock`) is this task's own fresh, active lock. Three
  are orphans that were never released: `specs/archive/856_scrub_task_number_leaks_from_wrapper_contracts/.lock`
  (acquired 2026-07-13T19:21:06Z, ~13 days / ~18,700 min old), `specs/archive/860_enforce_plan_compliance_rule/.lock`
  (acquired 2026-07-14T20:27:38Z, ~12 days / ~17,500 min old), and
  `specs/archive/921_throwaway_verify_meta_task_creation_pipeline/.lock` (acquired
  2026-07-27T10:12:13Z, ~7.2 hours / ~433 min old). All three tasks are archived and absent from
  `state.json`'s `active_projects`, so their `file_scope` resolves to `[]` and they currently
  trigger NO warning (the cross-task overlap check only fires when both sides have a non-empty,
  overlapping `file_scope`) — but they are exactly the class of permanent, unreaped orphan the
  task description describes, just not currently noisy. `.lock/` is gitignored
  (`**/.lock/` in `.gitignore`), so these are pure local-filesystem accumulation, invisible to
  `git status`, silently surviving `/todo` archival with no cleanup path.
- Heartbeat cadence is checkpoint-based, not timer-based: once per `/orchestrate` cycle (Stage
  3b, `skill-orchestrate/SKILL.md`) and once per implementation phase transition
  (`general-implementation-agent.md` Stage 4D). A single cycle/phase can itself be a long-running
  subagent dispatch with no intermediate heartbeat. Recommendation: a reap threshold of
  **4× `TASK_LOCK_STALE_MIN`** (default 120 minutes / 2 hours), documented and env-overridable,
  reusing the SAME base constant rather than an unrelated number — see Decisions and Risks below
  for the full reasoning against the observed 433/17,500/18,700-minute data points.
- `/refresh`'s systemd timer (`claude-refresh.timer`, hourly) invokes only `claude-refresh.sh`
  (process cleanup), NOT the full `skill-refresh` SKILL.md (which contains the `specs/` marker
  sweep). The `specs/` sweep — and, by extension, any new lock-reap step added there — currently
  only runs when a human or agent explicitly invokes the `/refresh` command; it is not on the
  automated hourly cadence today. This is a scoping fact worth documenting in the implementation,
  not a blocker.

## Context & Scope

Task 923 asks for research (not implementation) into how to close a real, observed gap: stale
foreign task locks are correctly detected and warned about by `scripts/task-lock.sh`'s
`cmd_acquire` cross-task `file_scope` overlap check, but nothing in the system ever removes or
reports them as a one-time event — the same warning repeats on every subsequent invocation for
the life of the session (and, per the live evidence above, indefinitely across sessions, since
`.lock/` directories persist on local disk with no expiry). The task supplies five binding
constraints on any eventual fix and asks this research pass to settle: the exact current
subcommand surface, the location and format of any staleness field, `/refresh`'s existing sweep
convention, design (a) vs (b) with evidence, a concretely-reasoned reap threshold, and live
verification of lock state in this repo. A dependent, file-serializing sibling task (adding an
opt-in `create_mode` parameter to `resolve_task_dir`) is confirmed COMPLETE and its change is
already present in the current source-store file (lines 116-166): `resolve_task_dir() { local
task_number="$1" create_mode="${2:-}" ...`, with only `cmd_acquire` passing the literal string
`"create"` (line 386: `resolve_task_dir "$task_number" "create"`). No further coordination with
that sibling is needed.

## Findings

### Codebase Patterns

#### 1. Full subcommand enumeration (task-lock.sh)

Confirmed from both the header usage comment (lines 15-24) and the dispatch `case` block (lines
762-842): `acquire`, `heartbeat`, `release`, `check`, `init-marker`, `scope-acquire`,
`scope-release`, `commit-acquire`, `commit-release` — nine total, no more, no fewer. The
catch-all `*)` branch (line 838) prints the same nine-item usage list and exits 2. No `reap`,
`gc`, `prune`, or `list` subcommand exists.

#### 2. The "never touch the foreign lock" rule, quoted and scoped exactly

Verbatim, line 428:
```
        # Stale overlapping foreign lock: warn and proceed. Never touch the foreign lock.
```
This sits inside `cmd_acquire`'s cross-task `file_scope` overlap loop (lines 392-433), which
iterates every OTHER task's held `.lock` via `find_held_locks` (lines 259-271) and, for each
overlap found via `scopes_overlap` (lines 238-257), either ABORTs (fresh foreign lock, line 424)
or WARNs and proceeds (stale foreign lock, line 429) — in neither branch does it write to,
remove, or otherwise touch the OTHER task's `.lock` directory. `task-lock.md`'s own prose
restates this identically (lines 137-139): "The foreign lock is NEVER mutated by this check — it
is read-only with respect to any lock directory other than the acquiring task's own."

This is distinct from the task's-own-lock stale-override branch a few lines below (lines
462-474), which explicitly DOES overwrite `holder.json` when the SAME task number's lock is held
by a DIFFERENT, stale session (`WARN: ... is stale (> N min threshold); overriding and acquiring
for $session_id.`) — that path only ever touches the acquiring task's own lock directory, never
another task's. Both rules are correct and unrelated to reaping: the first says a query
(`acquire`) must never destructively resolve someone else's unrelated lock; the second says a
task-scoped `acquire` may reclaim its OWN task's lock. Neither path offers, or should offer, a
route to garbage-collect an orphan belonging to a different, no-longer-active task.

#### 3. Where staleness actually lives

`holder.json` schema (script `write_holder`, lines 178-200; spec doc lines 36-54): `session_id,
task_number, operation, acquired_at, heartbeat_at, command`. No staleness/expiry field is ever
written per-lock. Staleness is computed on read, by `age_minutes()` (lines 208-218, tolerant of
both GNU `date -u -d` and BSD `date -u -j -f` syntax, defaulting to `999999` — i.e. maximally
stale — on unparseable timestamps) against the single global `TASK_LOCK_STALE_MIN` env var
(default 30, script line 114; spec doc line 72 confirms "plan-sanctioned range 30-60 minutes").
Every one of `cmd_acquire`, `cmd_check` reads this same constant fresh at call time (lines 421,
464, 553, 557) — so in practice every waiter DOES already honor "the same window," it is just a
process-wide default/env-var rather than a value physically written inside the lock directory.

Contrast with the two NAMED mutexes (`.scope-lock`, `.commit-lock`), which are genuinely
holder-declared in the literal sense the task description describes: `acquire_named_mutex` (lines
278-329) writes the ACQUIRER's own `stale_sec` choice into `$mutex_dir/stale_sec` (line 304), and
every later waiter reads that file (line 310) rather than applying its own default — this is the
`task-lock.md` "Holder-Declared Staleness" section (lines 265-280, 380-386) verbatim. The
task-number `.lock/holder.json` has no equivalent field.

**Implication for constraint 2**: since there is no literal per-lock staleness field to "honor,"
the closest and most consistent-with-precedent implementation is for a new `reap` subcommand to
read the SAME `TASK_LOCK_STALE_MIN` constant (or a documented, still-`TASK_LOCK_STALE_MIN`-
derived multiple of it — see Decisions) rather than introduce an unrelated, independently-chosen
threshold constant. This keeps "every reader/waiter/reaper honors the same declared window"
true in spirit even though the mechanism differs from the `.scope-lock`/`.commit-lock` case.

#### 4. `/refresh`'s existing orphaned-marker sweep — the convention to match

`skill-refresh/SKILL.md` Step 3, "Clean Orphaned Postflight Markers" (lines 45-89):
- **Glob shape**: `find specs -maxdepth 3 -name ".postflight-pending" -mmin +60 -type f` and the
  analogous `.postflight-loop-guard` pattern — a hardcoded age threshold (`-mmin +60`, 60
  minutes) baked directly into the `find` invocation, not read from any shared constant.
- **Legacy/global variant**: also unconditionally checks for two non-task-scoped legacy paths
  (`specs/.postflight-pending`, `specs/.postflight-loop-guard`) with no age check at all.
- **Dry-run**: a single `dry_run` boolean threaded from Step 1's argument parsing; the dry-run
  branch echoes the list of paths that WOULD be deleted, the live branch runs the identical
  `find ... -delete` and a generic one-line confirmation (`"Cleaned orphaned postflight
  markers."`). There is no per-item report in the live-delete branch beyond the generic line —
  paths are shown only in dry-run, not after an actual delete. This is a real gap relative to
  constraint 4 ("a reaped lock must be REPORTED, not silently removed"): the existing convention
  under-reports on the live path. A new lock-reap step should improve on this baseline (echo the
  per-lock task number, session id, operation, and age at delete time), not merely copy it.
- `refresh.md` (the command doc) does not mention this sweep at all — it only documents the
  `~/.claude/` process/directory cleanup. The `specs/` orphan sweep is entirely internal to
  `skill-refresh/SKILL.md` and undocumented at the command-doc level; a new lock-reap step should
  likely get at least a line in `refresh.md`'s "What It Cleans" table for discoverability.

#### 5. Design (a) vs (b), settled with evidence

Design (a) — `reap`/`prune` subcommand inside `task-lock.sh`, called only from `/refresh` — is
favored, but with a concrete caveat found by testing the reuse claim rather than assuming it:

- **Genuinely reusable as-is**: `read_holder_field()` (lines 202-206) and `age_minutes()` (lines
  208-218). The latter in particular encodes non-trivial GNU-vs-BSD `date` portability logic that
  exists ONLY in this file; reimplementing it in the refresh path (a separate skill file with no
  shell-script backing beyond `claude-refresh.sh`/`claude-cleanup.sh`) would be exactly the kind
  of "two copies drift apart" duplication the task description warns against.
- **Not reusable as-is**: `find_held_locks()` (lines 259-271) hardcodes `find "$PROJECT_ROOT/specs"
  -mindepth 2 -maxdepth 2 -type d -name ".lock"`. Verified live in this repo: this glob finds
  only `specs/923_reap_stale_task_locks/.lock` (the depth-2 active task) and MISSES all three
  `specs/archive/{NNN}_{slug}/.lock` orphans, which sit at depth 3. A dedicated
  `find ... -mindepth 2 -maxdepth 3 ...` (matching `/refresh`'s own existing `-maxdepth 3`
  convention for postflight markers) is required for a reap sweep to reach archived orphans at
  all — `find_held_locks` would need a maxdepth parameter added (or a new, sibling `find`
  invocation in the new `cmd_reap`) rather than being called verbatim.
- **Net evidence for (a) over (b)**: the age-computation and holder-read primitives that DO
  transfer cleanly already live in `task-lock.sh` and nowhere else; the piece that does NOT
  transfer cleanly (the glob depth) is a one-line `find` invocation, cheap to write correctly
  once inside `task-lock.sh` and reused by both the archive-reachable and non-archive cases. Design
  (b) (sweep entirely inside the refresh skill) would need to reimplement `age_minutes`'s
  GNU/BSD-portable date parsing from scratch (skills are markdown-embedded bash blocks, not a
  shared library) — the same fragility class the canonical doc explicitly calls out. Design (a)
  wins on the evidence.

### External Resources

Not applicable — this is a pure codebase/internal-convention task with no external library or
API surface.

### Recommendations

1. Add `reap` (or `prune`; either name is available and unclaimed) as a tenth subcommand to
   `scripts/task-lock.sh`, implemented as a new `cmd_reap()` following the existing function
   style (bash locals, `jq`-based JSON reads, tmp-file-rename where anything is written).
2. Signature suggestion: `task-lock.sh reap [--dry-run]`. No task number argument — reap sweeps
   ALL `.lock/` directories under `specs/` (including `specs/archive/`), not one task's lock,
   matching `/refresh`'s existing "sweep everything under `specs/`" pattern rather than a
   per-task CLI shape.
3. Internals: a dedicated `find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 3 -type d -name
   ".lock"` (three levels covers both `specs/{NNN}_{slug}/.lock` and
   `specs/archive/{NNN}_{slug}/.lock`; confirm no deeper nesting exists elsewhere before locking
   in this constant — none was found in this repo's live sweep). For each match, reuse
   `read_holder_field` for `session_id`/`heartbeat_at`/`task_number`/`operation` and `age_minutes`
   for the staleness computation; apply the reap threshold (see Decisions) rather than
   `TASK_LOCK_STALE_MIN` directly.
4. Reporting: emit one line per reaped lock naming task number, session id, operation, and age
   (improving on `/refresh`'s existing generic-line-only convention — see Findings §4), both in
   `--dry-run` ("would reap") and live mode ("reaped"). This satisfies constraint 4 (report, never
   silent) more thoroughly than the existing marker sweep does today.
5. `/refresh` (`skill-refresh/SKILL.md`) gets a new step calling `task-lock.sh reap
   [--dry-run]`, placed alongside (not merged into) the existing Step 3 postflight-marker sweep —
   same file, same `dry_run` variable already threaded from Step 1, no new argument parsing
   needed. Add a corresponding line to `refresh.md`'s "What It Cleans" table.
6. Update `context/patterns/task-lock.md` with a new "Reap Contract" section documenting the
   threshold, the never-runs-on-acquire/check/heartbeat/release invariant (constraint 1), and the
   constraint-5 unambiguous-staleness reasoning below, so future readers get the decision record
   in the canonical doc rather than only in a commit message.

## Decisions

- **Reap threshold**: `TASK_LOCK_STALE_MIN × 4`, i.e. a new default of **120 minutes (2 hours)**,
  computed FROM the existing constant rather than as an independent literal, and itself
  overridable via a new env var (suggest `TASK_LOCK_REAP_MULTIPLIER`, default `4`, OR a directly
  settable `TASK_LOCK_REAP_MIN` that defaults to `TASK_LOCK_STALE_MIN * 4` if unset — either
  satisfies "derived from the holder-declared window, not an unrelated number"). Reasoning,
  grounded in the actual heartbeat cadence (research focus point 5):
  - Heartbeat is checkpoint-based, not a fixed-interval timer: `skill-orchestrate/SKILL.md` Stage
    3b calls `task-lock.sh heartbeat` once per state-machine cycle (`MAX_CYCLES=5`, script line
    124), and `general-implementation-agent.md` Stage 4D calls it once per implementation phase
    transition. Between two heartbeats, a single subagent dispatch (one cycle's `research`/
    `plan`/`implement` Agent-tool call, or one implementation phase) can legitimately run for an
    extended, unheartbeated stretch — there is no intra-dispatch heartbeat tick.
  - `TASK_LOCK_STALE_MIN` (30-60 min) is already the threshold at which the SYSTEM ITSELF treats
    a lock as unreliable enough that a competing `acquire` for the SAME task may steal it
    (override-and-warn, lines 471-474) — so 30-60 minutes is already established, by the existing
    design, as "plausibly a single long dispatch, still worth a cautious override rather than an
    outright refusal." A reap operation is more consequential than an optimistic single-acquirer
    override: it runs unattended (`/refresh`, human- or agent-invoked, not itself gated by a
    per-lock confirmation) and is meant to be the FINAL word that a lock is dead, not merely
    stale-for-one-competing-acquirer's-purposes. It should therefore sit at a firm multiple above
    the acquire-override threshold, not equal to it.
  - 4× gives 120 minutes at the default (30 min base) and up to 240 minutes at the documented
    upper end of the "plan-sanctioned range" (60 min base) — comfortably longer than any
    documented cycle/phase duration in this codebase (no single dispatch is described anywhere as
    running for hours), while remaining far below both this task's own OBSERVED real-world data
    (582 and 920 minutes — 4.8× and 7.7× even the 120-minute default) and this repo's LIVE
    evidence (433, 17,500, and 18,700 minutes — the smallest of which, 433 min, is still 3.6× the
    120-minute default). Every real data point this research found clears the proposed threshold
    by a wide margin, so the threshold is conservative without being toothless.
  - This also composes cleanly with `/refresh`'s hourly systemd cadence (`claude-refresh.timer`):
    a 120-minute reap threshold means a lock survives roughly two `/refresh` runs before becoming
    eligible, giving an implicit "seen stale across at least one full hour, still stale" grace
    window even though (per the next point) the `specs/` sweep is not actually wired into the
    automated hourly run today.
- **Design (a) over (b)**: settled per Findings §5 — reuse `read_holder_field`/`age_minutes`
  inside `task-lock.sh`; do not duplicate GNU/BSD date-parsing logic into the refresh skill.
- **Constraint 5, answered directly**: a stale heartbeat is unambiguous (safe to reap) once its
  age exceeds `TASK_LOCK_STALE_MIN × 4` (120 min at defaults). Below that line — and especially
  in the 30-120 minute band where `acquire`'s own override logic already treats the lock as
  "stale enough to steal for a competing acquire" but reap should NOT yet treat it as "dead" —
  the holding session may still be a genuinely slow single dispatch; reap must not act on it. This
  distinction (override-eligible vs. reap-eligible) is a new, intentionally asymmetric pair of
  thresholds that should be named explicitly in the implementation and in `task-lock.md`, not left
  implicit.
- **Reap must never run on acquire/check/heartbeat/release paths** (constraint 1): trivially
  satisfied by making it a wholly separate `cmd_reap()`/subcommand with its own dispatch case,
  invoked ONLY from `/refresh`'s new step — no existing function gains a call to it.

## Risks & Mitigations

- **Risk**: a reap sweep that runs while a legitimately very-long dispatch (e.g. `--hard --team`,
  documented at up to ~15-25x cost multiplier) is still in progress could reap a live lock.
  **Mitigation**: the 120-minute-default threshold is 4x the existing override threshold and
  `/refresh` is not on any automatic per-minute cadence — a human or orchestrating agent invokes
  it deliberately; document the threshold's derivation (this report's Decisions section) in
  `task-lock.md` so a future maintainer can re-derive rather than guess if cadence assumptions
  change (e.g. if a future mode introduces genuinely multi-hour single dispatches).
- **Risk**: `find_held_locks`'s current `-maxdepth 2` silently misses deeper orphans (confirmed
  live against `specs/archive/*`). **Mitigation**: the new reap sweep must NOT call
  `find_held_locks` verbatim; it needs its own `-maxdepth 3` glob (documented above), and this
  finding itself should be called out in the implementation plan so it isn't silently
  reintroduced by copy-paste.
- **Risk**: reporting-only convention drift — `/refresh`'s existing marker sweep under-reports
  (generic one-liner, no per-item detail on the live-delete path). **Mitigation**: explicitly spec
  the reap report format (per-lock task/session/operation/age) in the plan so it does not
  regress to the existing weaker convention "for consistency."
- **Risk**: `TASK_LOCK_STALE_MIN` is env-overridable per-invocation; if a caller sets it very high
  (e.g. 60, the documented upper bound, or higher, off-spec), a `4×`-derived reap threshold moves
  with it, which is intentional (keeps the two thresholds proportionate) but should be
  DOCUMENTED as intentional so it isn't mistaken for a bug during review.

## Context Extension Recommendations

- **Topic**: Reap contract for the task-number lock.
- **Gap**: `context/patterns/task-lock.md` currently documents `acquire/heartbeat/release/check/
  init-marker` plus the two named mutexes in full contractual detail, but has no section for a
  reap/prune operation (because none exists yet).
- **Recommendation**: once implemented, add a "Reap Contract" section to `task-lock.md` mirroring
  the existing per-subcommand contract sections (exit codes, dry-run behavior, threshold
  derivation, the override-eligible-vs-reap-eligible distinction from this report's Decisions),
  and add `reap` to the top-of-file usage comment's subcommand list and the "Consumers" section
  (new entry: "`/refresh`'s specs/ sweep, Step N — the sole intended caller").

## Appendix

### Search queries / commands used

```bash
find . -path ./node_modules -prune -o -name "task-lock.sh" -print
find agent-system/extensions/core -iname "*task-lock*"
find agent-system/extensions/core -iname "*refresh*"
grep -n -i "orphan\|marker\|specs/" agent-system/extensions/core/skills/skill-refresh/SKILL.md
grep -n "heartbeat\|MAX_CYCLES=" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
grep -rln "task-lock.sh heartbeat" agent-system/extensions/core/
find specs -maxdepth 3 -type d -name ".lock"
find "$(pwd)/specs" -mindepth 2 -maxdepth 2 -type d -name ".lock"   # matches find_held_locks exactly — misses archive/
find "$(pwd)/specs" -mindepth 2 -maxdepth 3 -type d -name ".lock"   # finds all 4, including 3 archive/ orphans
jq -r '.active_projects[] | select(.project_number==856 or ==860 or ==921)' specs/state.json  # confirms none are active
git check-ignore -v specs/archive/.../​.lock/holder.json   # confirms **/.lock/ gitignore rule
cat agent-system/extensions/core/systemd/claude-refresh.timer  # hourly, but only runs claude-refresh.sh (process cleanup), not the specs/ sweep
```

### Key file:line references

- `agent-system/extensions/core/scripts/task-lock.sh:114` — `TASK_LOCK_STALE_MIN` default 30
- `agent-system/extensions/core/scripts/task-lock.sh:131-166` — `resolve_task_dir` with the
  already-complete `create_mode` sibling change
- `agent-system/extensions/core/scripts/task-lock.sh:208-218` — `age_minutes` (GNU/BSD portable)
- `agent-system/extensions/core/scripts/task-lock.sh:259-271` — `find_held_locks`
  (`-mindepth 2 -maxdepth 2`, misses `specs/archive/**`)
- `agent-system/extensions/core/scripts/task-lock.sh:392-433` — cross-task overlap scan;
  line 428 is the exact "never touch the foreign lock" comment
- `agent-system/extensions/core/scripts/task-lock.sh:462-474` — same-task stale-override branch
  (the one case where a stale lock IS mutated, but only the acquiring task's own)
- `agent-system/extensions/core/scripts/task-lock.sh:762-842` — subcommand dispatch, nine cases
- `agent-system/extensions/core/context/patterns/task-lock.md:265-280` — holder-declared
  staleness contract for the NAMED mutexes (not the task-number lock)
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md:45-89` — existing orphan-marker
  sweep convention to match
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:234-239` — per-cycle heartbeat
  call site
