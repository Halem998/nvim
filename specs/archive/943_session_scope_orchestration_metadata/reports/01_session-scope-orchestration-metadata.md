# Research Report: Session-Scope Batch-Level Orchestration Metadata

- **Task**: 943 - Session-scope batch-level orchestration metadata and verify session_id on read
- **Started**: 2026-07-28T00:00:00Z
- **Completed**: 2026-07-28T00:00:00Z
- **Effort**: Medium (touches 6 source-store files across skills/commands/context/scripts; no new subsystem)
- **Dependencies**: None functional. Task 942 (serialize `specs/state.json` writers) is a wave-1
  sibling in the `orchestration-concurrency` topic but does not overlap this task's file scope —
  see Decisions below.
- **Sources/Inputs**:
  - Codebase: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
    `skills/skill-orchestrate-hard/SKILL.md`, `skills/skill-refresh/SKILL.md`,
    `commands/orchestrate.md`, `commands/refresh.md`,
    `docs/architecture/handoff-schema.md`, `context/standards/orchestrator-runtime-files.md`,
    `scripts/check-runtime-file-tracking.sh`, `scripts/task-lock.sh`,
    `scripts/test-task-lock-reap.sh`, `scripts/command-gate-in.sh`, `root-files/.gitignore`
  - Repo root `/.gitignore` (hand-maintained, distinct from `root-files/.gitignore`)
  - `specs/state.json`, `specs/TODO.md` (task 942 cross-check)
  - Live `git check-ignore` probes against candidate session-scoped filenames
- **Artifacts**:
  - This report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- Confirmed both singletons (`specs/.orchestrator-multi-state.json`,
  `specs/.return-meta-multi.json`) are the only repo-level runtime files matching the
  "fixed-path, cross-invocation batch state, no session component" pattern; three momentary mutex
  directories and one dead legacy marker were audited and correctly excluded (see Findings §1).
- **Recommend the `{session_id}`-suffix scheme**, not a `specs/.orchestrations/{session_id}/`
  directory — live `git check-ignore` probing shows the suffix scheme needs only one widened
  gitignore pattern plus two widened `check-runtime-file-tracking.sh` patterns, while the
  directory scheme needs an entirely new pattern and new probes with no existing coverage at all
  (Findings §3).
- `specs/.return-meta-multi.json` is a **write-only file today** — no reader exists anywhere in
  the source store. Session-scoping its path still matters (collision/audit hygiene, future
  readers), but read-time `session_id` verification does not apply to it because nothing reads it
  back (Findings §2, §4).
- **Critical design catch**: `.orchestrator-loop-guard` and `.orchestrator-churn-state.json` are
  *designed* to be resumed by a **different** `session_id` on a later `/orchestrate` invocation
  of the same task (`SESSION_ID` is freshly generated per invocation in
  `command-gate-in.sh:38`, but the guard is meant to survive "across conversational turns" —
  `skill-orchestrate/SKILL.md:114`). A hard-fail session mismatch check on these two files would
  **break the intended resume path** — verification here must be observational (log/track
  `last_session_id`), never a gate (Findings §4).
- `.drift-inspection.json` does not currently carry a `session_id` field at all (the write
  instruction at `SKILL.md:980` lists only `drift_pct`/`deviation_count`/`total_items`/
  `completed_items`/`summary`) — the baseline's claim that it "carries session identity" is
  imprecise; adding verification there requires first adding the field, and the write-then-read
  happens synchronously in the same fork call, so realistic collision risk is near zero
  (Findings §4).
- The session-suffixed handoff path documented in `docs/architecture/handoff-schema.md:444-450`
  has zero producers and zero consumers in code — confirmed by grepping every `HANDOFF_PATH_ABS`
  assignment in both orchestrate skills, both of which are static
  `"${TASK_DIR_ABS}/.orchestrator-handoff.json"`. Recommend **delete**, not implement
  (Findings §5).
- No ordering dependency against task 942 (state.json writer serialization): 942's mutex-guarded
  helper concerns `specs/state.json` only; this task's two singletons are separate files never
  written through a state.json mutex path. The two tasks are independently dispatchable, matching
  their shared wave-1 placement (Decisions).

## Context & Scope

This report supports implementation planning for session-scoping
`specs/.orchestrator-multi-state.json` and `specs/.return-meta-multi.json`, adding read-time
`session_id` verification to runtime-file readers that already carry the field, resolving the
dead session-suffixed handoff documentation, updating the tracking/gitignore machinery, and
adding a reap path for abandoned per-session files. Per-task runtime files
(`.orchestrator-handoff.json`, `.orchestrator-loop-guard`, `.orchestrator-churn-state.json`,
`.drift-inspection.json`, per-task `.return-meta-{task}.json`) are already correctly isolated by
task directory and are explicitly out of scope for re-isolation — only their *read-time
verification* behavior is in scope. No session registry, no conflict-detection changes. All edits
target the source store (`agent-system/extensions/core/**`); `.claude/**` is a disposable deploy
artifact and must never be hand-edited directly.

## Findings

### 1. Confirmed scope of repo-level singletons (re-measured, baseline not missed)

Grepped every `specs/\.[a-zA-Z_-]*` literal across `agent-system/extensions/core/`. Beyond the
two named singletons, four other repo-level `specs/.*` paths exist, all correctly excluded from
this task's scope:

| Path | Nature | Why excluded |
|------|--------|---------------|
| `specs/.scope-lock/`, `specs/.commit-lock/`, `specs/.deploy-lock/` | Momentary mutex directories (`task-lock.sh` named-mutex primitives, `deploy-headless.sh`) | Repo-level sharing is the *intended function* — a mutex coordinates all sessions by design via mkdir-exclusivity + staleness reclaim. Session-scoping a mutex would defeat its purpose. |
| `specs/.postflight-pending` (bare, repo-root form) | Dead/legacy — `skill-refresh/SKILL.md:61-82` sweeps and deletes it as a "legacy global marker"; no current writer targets the bare repo-root path (every live writer targets the per-task `specs/{padded_num}_{project_name}/.postflight-pending` form, already isolated) | Confirmed no writer exists at the bare path; already handled by existing cleanup, no session-scoping needed |
| `specs/.events.lock` | `flock`-scoped mutex around `events-append.sh`, released at the end of a single append | Momentary, same rationale as the three mutexes above |

No additional persistent, session-relevant repo-level singleton was found. The baseline's
enumeration of exactly two singletons is confirmed complete.

### 2. Writer/reader map for both singletons

**`specs/.orchestrator-multi-state.json`**:
- Writer: `skill-orchestrate/SKILL.md` Stage MT-1 (`mt_state_file` init, no resume branch — every
  multi-task invocation starts fresh, unlike the per-task loop guard's resume-on-exists check),
  mutated continuously through Stage MT-3/MT-4/MT-5 (cycle_count, current_statuses,
  dispatch_start_ts, defer_ledger, deployed_critical_paths, etc.).
- Reader: `commands/orchestrate.md` Step 5 (residue check + consolidated output), hardcoded as
  `mt_state_file="specs/.orchestrator-multi-state.json"` at line 398. `batch_session_id` (the
  exact value needed for a session-scoped path) is already in scope at this read site — it is
  generated at line 330 and threaded unchanged through to line 398, so no new plumbing is needed
  to make Step 5 session-aware.
- `skill-orchestrate-hard/SKILL.md` has **no separate multi-task path**: its Stage 0 states it
  reuses "base multi-task stages" (Stage MT-1 through MT-5) verbatim — confirmed by its own text
  at line ~1239/1252/1281 referencing the base file's stages directly. One writer/reader pair to
  update, not two.

**`specs/.return-meta-multi.json`**:
- Writer: `skill-orchestrate/SKILL.md` Stage MT-5 step 5 (`jq -n ... > "specs/.return-meta-multi.json"`).
  Its own JSON payload does **not** include a `session_id` field (only `status` and a `metadata`
  object with `tasks_completed`/`tasks_failed`/`forward_progress_violated`/`defer_ledger`/
  `cycles_used`/`multi_task_mode`).
- Reader: **none found**. Grepped every occurrence of `return-meta-multi` in the source store —
  all remaining hits are documentation/comments (`context/formats/return-metadata-file.md`,
  `context/standards/orchestrator-runtime-files.md`) or the write site itself. No script or
  SKILL.md reads this file back. It exists purely as a status-vocabulary parity artifact with the
  per-task `.return-meta.json` convention.
- **Consequence for read-time verification (item 2 of the deliverable)**: there is nothing to
  verify on read for this file today, because nothing reads it. Session-scoping the *path* is
  still worthwhile (audit hygiene, collision prevention for a future reader, and to keep the
  suffixed-`.return-meta-*` tracking pattern's semantics uniform across all its variants), but a
  `session_id` read-time check would have no call site to attach to unless a reader is added —
  which is out of this task's scope.

### 3. Session-scoping scheme: suffix vs directory (recommend suffix)

Live-probed both schemes against the actual repo-root `.gitignore` (not `root-files/.gitignore`
— see the important scope note under Findings §6):

```
$ git check-ignore -v "specs/.return-meta-multi-sess_1234_abcd.json"
.gitignore:39:**/.return-meta-*.json	specs/.return-meta-multi-sess_1234_abcd.json
   -> MATCHES (no change needed for this file under the suffix scheme)

$ git check-ignore -v "specs/.orchestrator-multi-state-sess_1234_abcd.json"
   -> NO MATCH (exit 1) — the literal **/.orchestrator-multi-state.json pattern does not cover a suffix

$ git check-ignore -v "specs/.orchestrations/sess_1234_abcd/return-meta-multi.json"
$ git check-ignore -v "specs/.orchestrations/sess_1234_abcd/orchestrator-multi-state.json"
   -> NO MATCH on either (exit 1) — no existing pattern covers a new subdirectory at all
```

This directly answers the deliverable's "verify rather than assume" instruction for
`**/.return-meta-*.json`: **confirmed, that pattern already covers a suffixed
`.return-meta-multi-{session_id}.json` name with zero changes required.**

**Suffix scheme cost**: widen one existing gitignore line
(`**/.orchestrator-multi-state.json` → `**/.orchestrator-multi-state*.json`), widen two
`check-runtime-file-tracking.sh` items (the literal `EPHEMERAL_PROBES` entry at line 41 from
`"specs/.orchestrator-multi-state.json"` to a representative suffixed probe, and the Check-B
regex at line 86 from `'\.orchestrator-multi-state\.json$'` to a pattern tolerant of a
`-{session_id}` infix, e.g. `'\.orchestrator-multi-state(-[^/]+)?\.json$'`). The
`.return-meta-multi` side needs **no** gitignore change and **no** Check-A probe change; only its
Check-B regex (`'\.return-meta-[^/]*\.json$'`, line 87) already matches any suffix — confirmed
above — so no script change is needed there either.

**Directory scheme cost**: a wholly new gitignore entry (e.g. `specs/.orchestrations/`), an
entirely new Check-A probe pair, an entirely new Check-B regex pair, and a new row in
`orchestrator-runtime-files.md`'s class table describing a directory-shaped runtime-file class
that has no precedent anywhere in the existing two-class vocabulary (every entry in that table
today is a flat filename, never a nested directory of scratch files).

**Recommendation**: adopt the **`{session_id}`-suffix scheme** —
`specs/.orchestrator-multi-state-{session_id}.json` and
`specs/.return-meta-multi-{session_id}.json`. It is strictly less invasive (one gitignore line
widened vs. one added; two regexes widened vs. four new probes plus a new table row), it reuses
the exact suffix convention the codebase already applies to the per-task
`.return-meta-{task}.json` family, and it keeps every runtime-file class flat, consistent with
the rest of `orchestrator-runtime-files.md`'s Class Table. The directory scheme's one genuine
advantage — a single `rm -rf specs/.orchestrations/{session_id}/` reap primitive instead of a
two-glob sweep — is not worth the wider blast radius, since a two-glob reap (Findings §6) is
comparably simple to implement and test.

### 4. Read-time `session_id` verification, per file (not one-size-fits-all)

| File | Has `session_id` today? | Verification design | Rationale |
|------|--------------------------|----------------------|-----------|
| `specs/.orchestrator-multi-state-{session_id}.json` | Yes, written at Stage MT-1 init | **Assert/hard-fail** if content `session_id` ≠ the reading session's own `batch_session_id` (or, more simply, ≠ the `{session_id}` embedded in the path itself) | Fresh-per-invocation, no resume-across-turns semantics (Stage MT-1 has no `if -f` resume branch, unlike the loop guard). A mismatch here can only mean a real bug (stale variable reuse, wrong path resolved) — never an expected condition. Cheap, unconditional to add. |
| `specs/.return-meta-multi-{session_id}.json` | No `session_id` field currently written | N/A today — no reader exists (Findings §2). If a future reader is added, it should both add the field and check it the same way as the multi-state file (fresh-per-invocation, same rationale). | Out of scope until a reader exists. |
| `.orchestrator-loop-guard` (per-task) | Yes, written at fresh-start | **Do NOT hard-fail.** Track/update a `last_session_id` field and log an informational note when it changes across a resume. | `SESSION_ID` is regenerated per `/orchestrate` invocation (`command-gate-in.sh:38`) even for the same task across conversational turns — this file's own doc comment says it "tracks cycle count across conversational turns" (`SKILL.md:114`). A strict-equality gate would break the designed resume path. The existing per-task `task-lock.sh acquire` mutex (already gating concurrent operations on the same task number) is the real concurrency guard here — session_id in the guard is an observability field, not a safety gate. |
| `.orchestrator-churn-state.json` (hard mode, per-task) | Yes, written at fresh-start (`skill-orchestrate-hard/SKILL.md:267`) | Same as loop guard: observational only, never hard-fail | Identical resume-across-turns design as the loop guard; same task-lock mutex already covers true concurrency. |
| `.drift-inspection.json` (per-task) | **No** — current write instruction (`SKILL.md:980`) omits `session_id` entirely | Low priority. If added: warn-only, not hard-fail | The file is written by a same-call synchronous fork and read back in the very next step of the *same* stage (`SKILL.md:983`), all within one session's own turn — there is no realistic window for a foreign session's file to be read here. Adding the field costs one line in the fork prompt's write instruction; the check itself should be advisory. |
| `.orchestrator-handoff.json` (per-task) | **No** field in the JSON schema at all (`handoff-schema.md`'s Complete JSON Schema, lines 103-289, has no `session_id` key) | Out of scope — this file already has a documented (if unimplemented) path-suffix mechanism for the concurrent case (see Findings §5); it is explicitly listed in the task baseline as "already works, leave alone" for its existing mtime freshness gate. | Confirms the baseline's own framing: content-level session verification was never proposed for the handoff; only the dead path-suffix idea references session at all. |

**This is the single most important design correction to carry into planning**: a naive reading
of the task deliverable ("add read-time session_id verification wherever a session-owned runtime
file is consumed") would tempt an implementer to add a uniform hard-fail check to all four
session-bearing files. Doing so to the loop guard or churn-state file would silently break
legitimate multi-turn `/orchestrate` resumption — the file even documents its own reasoning for
*not* doing this today ("No session_id or mtime check ... this is precisely why a
git-restorable guard would corrupt the cycle budget", `SKILL.md:138-139`, which is about a
different hazard — restored-from-git-history — but establishes that this file's mismatch
tolerance is deliberate, not an oversight). The verification design must be per-file, keyed on
whether the file is genuinely single-invocation-scoped (multi-state: yes, hard-fail-safe) or
meant to survive across separately-invoked sessions (loop-guard/churn-state: no, observational
only).

### 5. Dead session-suffixed handoff documentation — recommend delete

`docs/architecture/handoff-schema.md` lines 444-450:

> **Exception**: If concurrent `/orchestrate` invocations are possible, include session_id:
> `handoff_path="specs/${padded_num}_${project_name}/.orchestrator-handoff-${session_id}.json"`
> The orchestrator reads its own session's file using the same session_id it wrote to the loop
> guard.

Confirmed dead by exhaustive search: every `HANDOFF_PATH_ABS`/`handoff_file` assignment in both
`skill-orchestrate/SKILL.md` (line 66, 133) and `skill-orchestrate-hard/SKILL.md` (line 125, 243)
is the static `"${TASK_DIR_ABS}/.orchestrator-handoff.json"` — no producer ever writes the
session-suffixed form, and no reader ever looks for it. It is also internally
self-contradictory with the surrounding "File Path" subsection's own opening claim two lines
above it ("The filename is static (not timestamped). Each dispatch cycle overwrites the previous
handoff.") — the "Exception" paragraph contradicts the rule it is appended to without any code
ever implementing the exception.

**Recommendation: delete**, not implement, for two reasons:
1. The per-task handoff is explicitly in the "already works, leave alone" baseline category —
   per-task directories already isolate concurrent *different-task* sessions, and `task-lock.sh`
   already serializes concurrent *same-task* sessions via its acquire/heartbeat/release contract
   at the top of the same stage. There is no live scenario where two sessions write the same
   task's handoff concurrently that isn't already prevented by the lock.
2. Implementing it would require adding a `session_id` field to the handoff JSON schema itself
   (currently absent, Findings §4's table) purely to serve a mechanism this task's scope
   explicitly excludes (no new concurrency mechanism for per-task files). That is scope creep
   relative to the stated deliverable, which only asks to "resolve" the dead documentation, not
   extend the handoff schema.

Deleting is a same-file, doc-only edit — no code path is affected either way since nothing
implements the exception today.

**`orchestrator_mode` dual-consumer contract check**: neither the singleton session-scoping nor
the read-time verification design touches `orchestrator_mode` (a distinct boolean gating whether
a handoff is written at all / whether literature Stage 4a auto-selects the global corpus). The
two mechanisms are independent — `session_id` values and the `orchestrator_mode` flag are
orthogonal fields with no shared code path in any file this task edits. No interaction to flag.

### 6. Reap path for abandoned per-session files

Modeled on the existing stale-task-lock reap (`task-lock.sh reap`, wired into
`skill-refresh/SKILL.md` Step 4, documented in `commands/refresh.md`'s "Stale Task Locks"
section).

- **Staleness criterion**: file mtime, mirroring `task-lock.sh cmd_reap`'s own fallback path
  (dir mtime when `holder.json` is missing/unparseable, `task-lock.sh:627-634`) and the general
  reap-threshold pattern (`TASK_LOCK_REAP_MIN` derived as `4 × TASK_LOCK_STALE_MIN` in
  `task-lock.sh:128`). Note this does **not** conflict with the "no freshness check on read"
  principle in `orchestrator-runtime-files.md` — that principle governs whether an in-flight
  *read* trusts an old file's content; reap is a distinct, explicitly-invoked *deletion* sweep
  that already uses mtime elsewhere in this exact codebase for the identical purpose
  (`task-lock.sh reap` itself). The two are not in tension.
  - Since `mt_state_file` is mutated on every dispatch cycle (cycle_count, current_statuses,
    dispatch_start_ts, etc. all rewrite the file each cycle), its mtime is a live signal:
    it only stops advancing once the writing invocation truly terminates (normal exit or crash).
  - Suggested default threshold: a new dedicated env var (e.g. `ORCHESTRATOR_SESSION_REAP_MIN`,
    default on the order of 120-240 minutes) rather than reusing `TASK_LOCK_REAP_MIN` directly —
    multi-task batch invocations can run one skill call through up to
    `MAX_CYCLES_MT = min(task_count * 5, 25)` cycles, each potentially a full research + plan +
    implement dispatch per task, so the safe threshold should be materially longer than the
    task-lock's own 2-hour default to avoid reaping a legitimately still-running batch. This
    specific number is a judgment call for the planner/implementer to confirm, not a verified
    fact — flagging it explicitly rather than asserting a number as settled.
- **Where it hooks in**: `skill-refresh/SKILL.md`, as a new "Step 4.5" immediately after the
  existing Step 4 (Reap Stale Task Locks). Using an `X.5` step number follows this codebase's own
  existing convention for inserting a step without renumbering everything downstream (the same
  pattern is already used for "Stage MT-3 step 4.5" in `skill-orchestrate/SKILL.md`). This avoids
  churning Step 5/6/7's existing references in both `SKILL.md` and `refresh.md`.
- **`commands/refresh.md` needs updating**: yes. It currently documents the "Stale Task Locks"
  behavior as its own subsection under "What It Cleans"; a parallel "Stale Session-Scoped
  Orchestration Files" subsection should be added there, following the same reporting shape
  (what's swept, dry-run vs live, threshold source) as the existing subsection.
  `commands/refresh.md`'s own note that this cleanup runs "only on explicit `/refresh`
  invocation... not on the hourly systemd cadence" applies identically to the new reap.
- **Must never delete**: a live session's own in-progress files. Since there is no PID/heartbeat
  mechanism for the batch orchestrator (unlike `task-lock.sh`'s heartbeat), the mtime-based
  threshold *is* the only available liveness proxy — set generously (per above) precisely because
  there is no cheaper/more precise signal to combine it with. The existing `test-task-lock-reap.sh`
  precedent (Findings below) is the model for proving the threshold boundary behaves correctly
  without flaking on real in-progress runs.

### 7. Verification strategy

Follow the isolated-temp-root precedent in `scripts/test-task-lock-reap.sh` (builds a throwaway
`$TMPROOT` with `.claude/scripts/` + `specs/` fixture trees, copies the real scripts under test
byte-for-byte so production code never learns it's under test, uses controlled epoch arithmetic
for fixture timestamps instead of real sleeping).

Suggested new/extended test files (final names/exact assertions are for the planner to fix):
- A collision test proving two concurrent multi-task orchestrations no longer collide: fixture
  two distinct `batch_session_id` values, simulate both writing to their respective
  session-scoped `specs/.orchestrator-multi-state-{session_id}.json` paths, assert both files
  persist independently with distinct `cycle_count`/`current_statuses` content (this is a
  filesystem-path-isolation test, not a concurrency/locking test — the whole point of
  session-scoping is that no lock is needed for this case).
- A foreign-session-detection test: write a `specs/.orchestrator-multi-state-{sidA}.json` whose
  content `session_id` is deliberately set to a different value than its own filename/path
  session_id, assert the read-time check in `commands/orchestrate.md` Step 5 rejects/flags it
  rather than silently trusting it.
- A reap test mirroring `test-task-lock-reap.sh`'s exact shape: fixture stale (old mtime, past
  threshold) and fresh (recent mtime, within threshold) session-scoped multi-state/return-meta-multi
  files, assert `--dry-run` reports without deleting and the live run deletes only the stale ones,
  never a fresh one representing a live session's own files.
- A gitignore-coverage test extending `check-runtime-file-tracking.sh`'s existing Check A/B
  pattern, adding representative session-suffixed probe paths for both singletons.

Suggested test file location: alongside `scripts/test-task-lock-reap.sh` in the same flat
`scripts/` directory (not a new subdirectory) — this sidesteps the documented deploy-loader gap
for brand-new files in brand-new subdirectories under `scripts/<subdir>/` (see Findings §8),
since it adds a new file to an *existing* directory the loader already covers.

### 8. Deploy path

All six in-scope files (`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`,
`skill-refresh/SKILL.md`, `commands/orchestrate.md`, `commands/refresh.md`,
`docs/architecture/handoff-schema.md`, `context/standards/orchestrator-runtime-files.md`,
`scripts/check-runtime-file-tracking.sh`) are **edits to already-deployed, already-existing
files** — no new file, no new subdirectory. Per
`.claude/rules/no-task-references-in-deliverables.md`'s documented Enforcement section, the two
known loader gaps (stale `root-files/settings.json` install-only copy; `copy_scripts`/
`copy_manifest` not re-run for already-loaded extensions) are both specifically about **brand-new
files failing to reach an already-deployed `.claude/` tree** — neither gap applies to editing
files that already exist there. Standard "Sync all"/"Load Core" resync should propagate these
edits without any special-cased workaround. The one new artifact this task's plan should include
(a new test script, Findings §7) should be placed in the existing flat `scripts/` directory to
avoid the subdirectory-specific gap, and the plan's own verification phase should include an
explicit post-deploy `diff` or `check-runtime-file-tracking.sh` run against the redeployed
`.claude/` copy as a final confirmation step, consistent with how this repo's own prior sessions
have worked around the gap (a direct one-off invocation of the loader's copy primitives, per that
rule file's own recorded precedent).

## Decisions

- Adopt the `{session_id}`-suffix scheme for both singletons, not a `specs/.orchestrations/`
  directory (Findings §3).
- Read-time `session_id` verification is **hard-fail for the multi-state file**, **observational
  only (never hard-fail) for the loop guard and churn-state file**, **not applicable today for
  return-meta-multi** (no reader) and **low-priority/advisory if added for drift-inspection**
  (Findings §4). This per-file differentiation, not a uniform policy, is the key planning input.
- Delete the dead session-suffixed handoff documentation in `handoff-schema.md` rather than
  implement it (Findings §5).
- No ordering dependency exists against task 942 — verified via file-scope non-overlap (942
  touches only `specs/state.json`-writer serialization; this task's two files are never written
  through a state.json mutex path). Both tasks can proceed independently within wave 1.
- New reap logic belongs in `skill-refresh/SKILL.md` as a new "Step 4.5", with a corresponding new
  subsection in `commands/refresh.md`; mtime-based staleness with a dedicated, generously-sized
  threshold env var (exact value left to the planner).

## Recommendations

Prioritized, actionable, highest priority first — consolidating the per-topic recommendations
from Findings §3-§8 into a single implementation-ready list:

1. **(Highest) Transcribe the per-file verification table (Findings §4) directly into the plan's
   acceptance criteria before any code is written.** This is the one finding most likely to be
   silently overridden by a uniform-policy assumption. Owner: planner. Next step: copy the table
   verbatim into the plan document, one phase/checklist item per row, so hard-fail vs
   observational-only is never left to implementer discretion.
2. **Implement the `{session_id}`-suffix scheme for both singletons** (Findings §3): rename
   `specs/.orchestrator-multi-state.json` → `specs/.orchestrator-multi-state-{session_id}.json`
   and `specs/.return-meta-multi.json` → `specs/.return-meta-multi-{session_id}.json`, updating
   the one writer (`skill-orchestrate/SKILL.md` Stage MT-1/MT-5) and one reader
   (`commands/orchestrate.md` Step 5, which already has `batch_session_id` in scope at line 398 —
   no new plumbing required). Owner: implementer. Next step: land this before the verification
   and gitignore changes below, since they both key off the new filename shape.
3. **Add hard-fail read-time `session_id` verification to `specs/.orchestrator-multi-state-{session_id}.json`
   only** (Findings §2, §4): compare the file's content `session_id` against `batch_session_id` at
   the `commands/orchestrate.md` Step 5 read site. Owner: implementer. Next step: add the check
   immediately after the existing `if [ -f "$mt_state_file" ]` branch at line 399.
4. **Widen exactly two `check-runtime-file-tracking.sh` patterns and one gitignore line**
   (Findings §3): the `EPHEMERAL_PROBES` literal (line 41) and the Check-B regex (line 86) for
   `.orchestrator-multi-state`, plus the repo's own hand-maintained root `.gitignore` line for the
   same file (see the Appendix scope note on `root-files/.gitignore` vs. the actual root
   `.gitignore`). No change is needed for the `.return-meta-multi` side — its existing
   `**/.return-meta-*.json` pattern and Check-B regex already cover the suffixed name (verified,
   Findings §3). Owner: implementer. Next step: also update `orchestrator-runtime-files.md`'s
   Class Table rows and its "Consumer Repo Setup" code block to document the new suffix
   convention.
5. **Delete the dead session-suffixed handoff exception in `docs/architecture/handoff-schema.md`
   (lines 444-450)** rather than implement it (Findings §5). Owner: implementer. Next step:
   remove the "Exception" paragraph; no code path is affected either way.
6. **Add the mtime-based reap step** (Findings §6): a new "Step 4.5: Reap Stale Session-Scoped
   Orchestration Files" in `skill-refresh/SKILL.md` immediately after Step 4, plus a matching new
   subsection in `commands/refresh.md`. Owner: implementer. Next step: introduce a dedicated
   `ORCHESTRATOR_SESSION_REAP_MIN` env var (default on the order of 120-240 minutes, to be
   confirmed by the planner) rather than reusing `TASK_LOCK_REAP_MIN`.
7. **Add the test suite** (Findings §7) modeled on `scripts/test-task-lock-reap.sh`'s
   isolated-temp-root pattern: a path-isolation test (two concurrent batches, distinct session
   files), a foreign-session-detection test (mismatched content vs. path session_id), and a reap
   test with both a stale and a fresh fixture. Owner: implementer. Next step: place the new test
   file directly in the existing flat `scripts/` directory, not a new subdirectory, to avoid the
   documented deploy-loader gap for brand-new subdirectories (Findings §8).
8. **(Lowest priority, optional) Add a `session_id` field to `.drift-inspection.json`'s write
   instruction and a warn-only check on read** (Findings §4): only worth doing as a low-cost
   consistency improvement: the file's write-then-read happens synchronously within one stage of
   one session, so the realistic collision risk is near zero. Owner: implementer, if time permits;
   safe to defer to a follow-up task otherwise.

## Risks & Mitigations

- **Risk**: an implementer applies a uniform hard-fail session check to all four session-bearing
  files, breaking `/orchestrate`'s multi-turn resume for the loop guard/churn-state.
  **Mitigation**: Findings §4's per-file table should be transcribed directly into the
  implementation plan's acceptance criteria, not just referenced.
- **Risk**: choosing the directory scheme later without re-checking gitignore coverage, silently
  leaving new session directories untracked-but-uncleaned or (worse) accidentally tracked.
  **Mitigation**: the live `git check-ignore` probes in Findings §3 are reproducible and should be
  re-run against whatever the plan actually implements, not assumed from this report alone.
- **Risk**: reap threshold set too aggressively, deleting a legitimately long-running multi-task
  batch's own state mid-run. **Mitigation**: default to a generous threshold (Findings §6) and
  require the reap test suite (Findings §7) to include a "fresh, still within threshold" fixture
  case, not just a stale one.

## Context Extension Recommendations

- None — `orchestrator-runtime-files.md`'s existing Class Table structure is sufficient to extend
  in place (add a note to the `specs/.orchestrator-multi-state.json` and
  `specs/.return-meta-*.json` rows describing the new suffix convention); no new context file is
  warranted.

## Appendix

- Search queries used: `grep -rn "orchestrator-multi-state\|return-meta-multi"`,
  `grep -rn "session_id"` (scoped per file), `grep -rohn '"specs/\.[a-zA-Z_-]*\.json"...'`
  (repo-level singleton sweep), live `git check-ignore -v` probes against four candidate paths.
- `git check-ignore` probes were run against this repo's actual root `.gitignore`
  (`/home/benjamin/.config/nvim/.gitignore`), **not** `root-files/.gitignore` — the latter deploys
  into `.claude/` (itself wholly gitignored via `/.claude/` in the repo-root `.gitignore`), so it
  has no bearing on repo-root tracking of `specs/*` runtime files. `root-files/.gitignore`
  currently contains only unrelated hook-log/tmp patterns. If item 4 of the task description's
  deliverable ("the gitignore patterns in `root-files/`") is read literally, note that the
  substantive change actually belongs in the repo's own hand-maintained root `.gitignore` per
  `orchestrator-runtime-files.md`'s own "Consumer Repo Setup" section, which states explicitly:
  "There is no automatic way for the source store to deliver a repo-root `.gitignore`
  contribution... Add the following block to the consumer repo's own root `/.gitignore` by hand,
  once." The planner should treat the `orchestrator-runtime-files.md` "Consumer Repo Setup" code
  block as the canonical place to update the documented pattern, and treat the actual edit to
  this repo's own root `.gitignore` as a separate, already-precedented manual action distinct
  from `root-files/.gitignore`.
