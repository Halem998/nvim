# Research Report: Task #945

**Task**: 945 - converge_conflict_detection_predicate
**Started**: 2026-07-28T00:00:00Z
**Completed**: 2026-07-28T00:00:00Z
**Effort**: large (multi-file schema change + new read surface + 3 command-file wirings)
**Dependencies**: 944 (session registry — landed; verified below)
**Sources/Inputs**: Codebase read (agent-system/extensions/core/**), specs/state.json task 945 description
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Gap B (the two transcriptions) is NOT drifted.** `task-lock.sh`'s `scopes_overlap()` and
  `orchestrate-batch-admit.sh`'s `scopes_overlap_first()` are semantically byte-identical in
  their normalization and match rule; the batch-admit copy's own comment says it is "mirroring
  task-lock.sh scopes_overlap() exactly." The duplication is real but has not (yet) drifted —
  this task is a preventive convergence, not a bug fix.
- **The two are shaped differently and cannot share one literal function.** `scopes_overlap()` is
  a bash function that shells out to `jq -n` per call and returns a path string via command
  substitution. `scopes_overlap_first()` is a jq `def` embedded inside one large `jq -n --slurpfile`
  program that also defines `self_mod_match()` (the fourth, self-modification, application of the
  same predicate). A shared library needs to serve both call shapes — recommend a small jq-only
  lib file whose text both a bash wrapper (for `task-lock.sh`) and the embedded program (for
  `orchestrate-batch-admit.sh`) source/splice, not a `jq -L` module import (no precedent for that
  in this codebase — plain `jq` invocations only).
- **Only two of the four named consumers implement the algorithm at all.** `orchestrate-predispatch-review.sh`
  and `orchestrate-dry-run-report.sh` never re-transcribe the overlap predicate — they call
  `orchestrate-batch-admit.sh` as a subprocess and consume its NDJSON. Converging the predicate
  inside `orchestrate-batch-admit.sh` (and `task-lock.sh`) therefore automatically propagates to
  those two consumers; they need no independent code change, only schema-version awareness.
- **Input (1) held-locks and input (3) non-terminal-state are not independent scope sources —
  input (1) is a liveness/confidence signal layered on input (3).** `find_held_locks` returns lock
  directories; `holder.json` carries no `file_scope` field. The "other" side's scope is always
  re-fetched from `specs/state.json` via `get_file_scope(other_task)` — i.e. input 1 never
  supplies its own scope data, it only tells you a given state.json task_number is *currently,
  confirmably locked* (and by whom, and how fresh). Input (2), the session registry, is different
  in kind: `session-register` precomputes and stores its own `file_scope` **union** across
  possibly several `task_numbers`, independently of any single task's state.json entry, and can
  cover work that has not yet flipped a task's status away from a non-terminal value the scan
  would already have caught, or — read the other way — can be the only signal precise enough to
  say a state.json status string is trustworthy right now.
- **The session registry has no read surface yet, by design** (gap explicitly called out in
  `task-lock.md`'s "Non-Goal: No Reader" section). This task is the first reader, and per that
  section's own instruction the reader must add its own freshness/ownership checks, not assume
  the registry's mere existence proves anything. Recommend a new `task-lock.sh session-list`
  subcommand (read-only NDJSON dump with a computed liveness field), reusing (not re-deriving) the
  two-signal dead-pid/stale-heartbeat logic currently embedded only inside `cmd_session_reap`.
- **The verdict schema must version-bump, not additively-field, again.** `batch-admit-schema.md`'s
  own Version History shows both v1→v2 and v2→v3 were version bumps specifically because a new
  defer flavor or a narrowed semantic changes what a pre-existing consumer's `defer_reason`
  branch must do. Adding a third contention source (session registry) that can surface a
  genuinely new defer reason (e.g. a task with no held lock, no locked-and-listed non-terminal
  status corroboration, but an actively heartbeating session) is the same class of change and
  should be `orchestrate-batch-admit-v4` under the same reasoning, not squeezed into v3's field
  set.
- **Gap C's exact anchor in all three multi-task commands is the same shape**: right after Step 2
  (`session-register`, already landed) and before Step 3's per-task `task-lock.sh acquire` loop.
  No batch-admission call exists there today — only the per-task lock acquire.

## Context & Scope

Task 945 is a meta task converging three existing, independently-evolved conflict-detection
mechanisms onto one documented, unified predicate consumed by four scripts, and extending
coverage to three command files that currently only do per-task locking. Three prerequisite
tasks landed immediately before this one (state-write.sh mutex writer, session-suffixed batch
runtime singletons, and the session registry itself) — this research reads their *current*,
already-landed state rather than a stale mental model, per the task's own instruction.

The task's four RECORDED CONSTRAINTS (bounded scan only; exclude-never-auto-expand; blocking
stays blocking; deferral-direction rule preserved bit-for-bit) are settled and are treated here
as inputs to the design, not open questions.

## Findings

### 1. The two overlap transcriptions — verbatim comparison

**`task-lock.sh` `scopes_overlap()`** (bash function wrapping a `jq -n` one-shot call):

```bash
scopes_overlap() {
  local scope_a="$1" scope_b="$2"
  jq -n -r --argjson a "$scope_a" --argjson b "$scope_b" '
    def norm: rtrimstr("/");
    ($a // []) as $sa | ($b // []) as $sb |
    [ $sa[] as $pa | $sb[] as $pb |
      ($pa|norm) as $na | ($pb|norm) as $nb |
      select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/"))) |
      $pb
    ] | first // empty
  ' 2>/dev/null
}
```

Called as `scopes_overlap "$own_scope" "$other_scope"` from `cmd_acquire`'s cross-task check
(preceded by `acquire_scope_mutex`/TOCTOU-safe). `$other_scope` is always freshly fetched via
`get_file_scope "$other_task"` — i.e. `holder.json` (session_id, task_number, operation,
acquired_at, heartbeat_at, command) never itself carries `file_scope`; the scope always comes
from `specs/state.json`.

**`orchestrate-batch-admit.sh` `scopes_overlap_first()`** (jq `def` inside a larger `jq -n
--slurpfile state_arr` program):

```jq
def scopes_overlap_first(own_scope; other_scope):
  def norm: rtrimstr("/");
  (own_scope // []) as $sa | (other_scope // []) as $sb |
  [ $sa[] as $pa | $sb[] as $pb |
    ($pa|norm) as $na | ($pb|norm) as $nb |
    select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/"))) |
    $pb
  ] | first // empty;
```

Byte-for-byte identical `norm`/select logic to `scopes_overlap()`; only the wrapping differs
(jq `def` vs. bash-function-around-`jq -n`). The same file also defines `self_mod_match($cscope;
$crit)`, a second application of the identical predicate against a static declared list
(`orchestrator-critical-paths.json`) instead of another task's `file_scope` — this is explicitly
documented as "a FURTHER APPLICATION of the SAME overlap predicate... not a new matching rule,"
with one load-bearing difference from `scopes_overlap_first`: it uses `| first` (never `| first
// empty`) because its result is bound outside an array comprehension via `as $sm_hit |`, and an
`empty` there would silently drop the whole candidate's NDJSON line.

**Verdict on drift**: none detected. Both use `rtrimstr("/")` normalization and the identical
three-clause `select` (`==` or either-side `startswith(x + "/")`). The batch-admit copy's own
header comment explicitly states it mirrors `task-lock.sh scopes_overlap()` "exactly" — this is a
maintained-by-convention duplication, not an accidental fork, but it is still two source
locations that a future edit could silently desync, which is exactly gap B's stated hazard.

**Where the shared implementation should live**: the precedent named in the task
(`scripts/lib/task-reference-patterns.sh`, sourced by both a lint gate and a write-time hook) is
a bash-sourceable file — appropriate for two bash *callers*. Here, though, one caller needs a
bash-callable function (`task-lock.sh`'s `cmd_acquire`) and the other needs the SAME logic
embedded as a jq `def` inside one big `jq -n --slurpfile` invocation for performance (a single
read of `state.json`, no per-candidate subprocess). Two structurally different consumption
shapes rule out a single "just source it" bash file for both. Options surfaced, with a
recommendation:

- **(a) A jq-only lib file** (e.g. `scripts/lib/file-scope-overlap.jq`) holding only the `def
  norm`, `def overlaps(a;b)`, and `def scopes_overlap_first(own;other)`/`def
  self_mod_match($cscope;$crit)` definitions as jq source text. `task-lock.sh` would source it
  via a bash function that slurps the file's text into the `jq -n` program string (string
  concatenation, not `jq -L`/`import`, since no `jq -L` precedent exists anywhere in this
  codebase's ~dozen `.sh` scripts and introducing module-import machinery for one shared
  predicate is disproportionate). `orchestrate-batch-admit.sh` would do the identical
  text-splice when building its larger program. **This keeps exactly one physical location for
  the match rule** while accommodating both consumption shapes, and is the recommended option.
- **(b) A bash lib exporting both a callable function AND a jq-def string constant** (e.g.
  `scripts/lib/file-scope-overlap.sh` defining `scopes_overlap()` as today, plus a
  `FILE_SCOPE_OVERLAP_JQ_DEFS` variable holding the identical jq def text for splicing). This
  keeps the file extension consistent with the cited precedent (a `.sh` lib) at the cost of
  encoding jq source as a bash string literal (readability/escaping cost, since the jq body
  itself contains `"`/`+`/`|` characters that must survive bash quoting).
- Both options are single-source-of-truth; (a) is cleaner for jq syntax highlighting/lint but
  introduces a `.jq` file type new to this codebase's `scripts/lib/`; (b) fits the existing `.sh`
  convention. This is a genuine open fork for the planning stage, not resolved here.

`self_mod_match` should move into the same shared file as a second def (same predicate, applied
to a fixed list) rather than staying only in `orchestrate-batch-admit.sh`, since the task
description frames it as part of "the overlap algorithm," and `file-footprint-overlap.md` already
documents it as the same rule.

### 2. `context/patterns/file-footprint-overlap.md` — what needs updating

The document is well-structured for this convergence: it already names its algorithm as
canonical, already lists four consumers (task-level, phase-level, lock-acquisition-level,
batch-admission-level) plus the self-modification application as a fifth bullet, and already has
a "Non-Goals" section stating it defines the *predicate* only, not scan scope (so BOUNDED SCAN
ONLY / adding a third input does not require touching that section).

**Required edit**: the "Lock-acquisition-level" and "Batch-admission-level" bullets currently
say "via the `scopes_overlap()` jq transcription" and describe two separate transcriptions. Once
converged, this section must instead say both consumers call the ONE shared implementation
(name whichever of options (a)/(b) above the plan selects), and add a new bullet for the
session-registry application (`session-list`'s liveness-scoped scope union, or wherever the
predicate consumes it) — this is again "a further application of the same predicate," worded the
same way the self-modification bullet already is, not a new matching rule.

### 3. `docs/architecture/batch-admit-schema.md` — schema-change analysis

Current: **v3** (`orchestrate-batch-admit-v3`). Two defer flavors exist today,
discriminated by `defer_reason`: `self_modifying` and `file_scope_collision` (further split by
`collision_scope` into `in_batch`/`cross_batch`).

**Is a third contention input additive or breaking?** Breaking in the same sense v1→v2 and
v2→v3 were — the document's own Version History is explicit that BOTH prior bumps were version
bumps rather than additive fields, for the identical reason each time: a pre-existing consumer's
`defer` branch makes an assumption (v1: every defer is a collision; v2→v3: a `self_modifying`
defer is a permanent whole-invocation exclusion) that a new/changed defer shape would silently
violate if left unversioned. Concretely:

- If the session-registry input produces its OWN new `defer_reason` value (e.g.
  `"session_active"` for "no held lock, no fresher-than-status corroboration from state.json
  alone, but an actively-heartbeating session's own file_scope union overlaps") — this is a new
  branch a `defer_reason`-switching consumer must add, exactly the v1→v2 shape. **This needs
  `orchestrate-batch-admit-v4`.**
- If instead the session-registry input is folded into the EXISTING `file_scope_collision`
  shape as additional evidence fields on an already-fired collision (e.g. an added
  `corroborated_by: ["held_lock","session_registry","non_terminal_status"]` array on a verdict
  that already has `defer_reason == "file_scope_collision"`), this is closer to additive — but
  the schema doc's own field table format ("Present only when defer_reason == X") means even a
  new *optional* field is new consumer-visible surface a `--consumer requirement` note (already
  present under "Consumer requirement (since v2, unchanged by v3)") would need to be re-stated
  for. Given the doc's own precedent of treating any semantic-consequence change as a version
  bump rather than purely additive, **recommend treating this as v4 regardless of which shape is
  chosen**, and writing a "v3 to v4" Version History entry mirroring the existing two, including
  the same "every in-repo consumer's status as of v4" table the v3 entry has.
- Either way, `$schema` literal must become `"orchestrate-batch-admit-v4"`, and both existing
  downstream report composers (`orchestrate-predispatch-review.sh`, `orchestrate-dry-run-report.sh`)
  are recorded in the doc as "pins no `$schema` string literal and already branches on
  `defer_reason`" for v3 — so they are LIKELY (not guaranteed — must be re-verified, not assumed)
  to remain compatible with a new `defer_reason` value without edits, the same way they survived
  v2→v3 unedited. This should be explicitly re-verified in the plan/implementation, not assumed
  from this precedent alone.

**A1 asymmetry note carries forward**: the schema doc's "A1 — dependency-edge exemption
asymmetry" section explains why the self-modification dimension has no dependency exemption
(edge-connected pairs can never co-occupy a same-cycle dispatch, so the exemption would be dead
code). A session-registry-sourced hit needs the SAME reasoning re-examined: can a
dependencies[]-edge-connected task ever be the one whose *session* — as opposed to its state.json
status — collides? Yes, in principle (a predecessor's session can still be running while a
successor is being considered in a different, not-yet-eligible wave) — but the existing
`comparison_set` construction already excludes dependency-edge-connected tasks from the state.json
scan for exactly the reason an edge already serializes them. Whether the session-registry
comparison should reuse task-level dependency exclusion, or should instead exclude by
session-covers-a-dependency-connected-task-number (since one session can cover several
task_numbers, only some of which may be edge-connected to the candidate) is a genuine design
question for planning — flagged, not resolved, here.

### 4. The four consumer call sites and current contracts

| Consumer | Current relationship to the overlap algorithm |
|---|---|
| `task-lock.sh` `cmd_acquire` | Direct transcription owner (`scopes_overlap()`), scans every currently-held `.lock/` dir repo-wide via `find_held_locks`, re-fetches each other task's scope from state.json via `get_file_scope`. Blocking (ABORT) on a fresh overlapping lock; WARN-and-proceed on a stale one. |
| `orchestrate-batch-admit.sh` | Direct transcription owner (`scopes_overlap_first()` + `self_mod_match()`), single `--slurpfile` read of `specs/state.json`, compares candidate against every non-terminal task minus dependency-edge-connected ones. Emits NDJSON verdicts; never touches locks or the session registry today. |
| `orchestrate-predispatch-review.sh` | **No transcription** — calls `orchestrate-batch-admit.sh` as a subprocess once for the validated candidate set and re-presents Classes C (`self_modifying`) and D (`file_scope_collision && cross_batch`) verdicts with added diagnosis/suggested-edge text. Pins no `$schema` literal; branches on `defer_reason`. |
| `orchestrate-dry-run-report.sh` | **No transcription** — same subprocess-call relationship as above (Step 4), reproducing admitted/excluded sets and per-verdict notes for a human-readable report. Also pins no `$schema` literal; branches on `defer_reason`. |

**Practical consequence for this task**: only `task-lock.sh` and `orchestrate-batch-admit.sh`
need the actual predicate change (shared lib + third input). The other two "consumers" named in
the task description are downstream report composers that inherit the new predicate automatically
once `orchestrate-batch-admit.sh`'s verdict stream changes — their own work item is limited to
(a) verifying they still branch correctly on any new `defer_reason` value (both already branch on
`defer_reason` rather than assuming a fixed set, per the schema doc's v3 compatibility note) and
(b) updating whatever human-readable text they template for the new evidence fields, not
re-implementing any overlap logic.

### 5. Gap C — exact anchors in `research.md`, `plan.md`, `implement.md`

All three multi-task command files already register a batch session (landed in the immediately
preceding session-registry task) but never call `orchestrate-batch-admit.sh` — they go straight
from session-register to a per-task `task-lock.sh acquire` loop with no batch-level pre-check.
The anchor is structurally identical across all three files:

- `research.md`: `#### Step 2: Generate Batch Session ID` (ends with the `session-register`
  call quoted below) immediately followed by `#### Step 3: Dispatch Skills`, whose numbered
  item 3 is the per-task acquire: `bash .claude/scripts/task-lock.sh acquire "$task_num" research
  "${batch_session_id}_${task_num}" "/research (multi-task)"`. The `session-register` call is:
  `bash .claude/scripts/task-lock.sh session-register "$batch_session_id" "/research (multi-task)"
  "$(IFS=,; echo "${validated_tasks[*]}")"`.
- `plan.md`: same shape — session-register call at the end of its batch-session-ID step, followed
  immediately by a `#### Step 3` (or equivalently numbered) dispatch step whose item 3 is `bash
  .claude/scripts/task-lock.sh acquire "$task_num" plan "${batch_session_id}_${task_num}"
  "/plan (multi-task)"`.
- `implement.md`: same shape, `session-register` at line-adjacent position to its own per-task
  `task-lock.sh acquire ... implement ...` loop.

**Where a batch-admission call belongs**: immediately after each file's `session-register` call
and before the per-task acquire loop begins — i.e. a new step (or a prepended item within the
existing dispatch step) that calls `orchestrate-batch-admit.sh --invocation-count
"${#validated_tasks[@]}" "${validated_tasks[@]}"` once for the whole validated set, and moves any
`decision == "defer"` task from `validated_tasks` to `skipped_tasks` (mirroring the existing
`"locked by another session"` skip-reason convention already used in the per-task-acquire-refusal
branch) BEFORE the per-task acquire loop runs — never removing an admitted candidate from the
loop's own subsequent per-task lock semantics, which stay unchanged. This inserts one new
subprocess call per multi-task invocation, consistent with how
`orchestrate-predispatch-review.sh` and `orchestrate-dry-run-report.sh` already call it once for
their whole set.

`commands/orchestrate.md`'s multi-task path is NOT part of gap C — it (and its executing
counterpart `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5) already calls
`orchestrate-batch-admit.sh` per the schema doc's "Read by" list; only the three bare
`/research`, `/plan`, `/implement` multi-task paths lack it.

### 6. Session registry read surface

Confirmed: `context/patterns/task-lock.md`'s "Non-Goal: No Reader" section states plainly that
nothing in the source store reads `specs/.sessions/` today, and instructs a future reader-adder
to bring its own freshness/ownership checks — this task is that reader.

**Entry shape** (`specs/.sessions/{session_id}.json`, written by `session-register`/
`session-heartbeat`): `session_id`, `pid`, `pid_source` (`ancestor-claude`|`ppid`|`self`|
`explicit`), `command`, `task_numbers` (array of ints), `file_scope` (deduplicated union across
those tasks, precomputed at register-time via `get_file_scope`), `started_at`, `heartbeat_at`.

**Liveness/staleness, already implemented but only inside `cmd_session_reap`** (two-signal,
evaluated in this order):
1. `dead-pid`: `kill -0 "$pid"` fails AND `heartbeat_at` age exceeds `SESSION_REGISTRY_DEAD_PID_MIN`
   (default 10 min — a floor guarding against a misresolved pid reaping a genuinely live,
   recently-heartbeated session).
2. `stale-heartbeat`: otherwise (pid alive or liveness undeterminable — missing/non-numeric pid),
   `heartbeat_at` age exceeds `SESSION_REGISTRY_REAP_MIN` (default 240 min / 4 hours — deliberately
   NOT derived from `TASK_LOCK_STALE_MIN`, since a batch session can legitimately run far longer
   than a single task's lock window).
`kill -0` succeeding is explicitly documented as never proof of liveness on its own — it only
prevents the dead-pid shortcut; the stale-heartbeat band is always the eventual fallback (same-host
liveness only, cross-host is a stated Non-Goal). A missing/unparseable entry falls back to the
file's own mtime and is still reported, never silently skipped.

**Recommendation**: add `task-lock.sh session-list` — read-only, no mutation, no `--dry-run`
flag needed since nothing is deleted — that globs `specs/.sessions/*.json` (a bounded,
dedicated-directory scan; NOT a repo-wide or every-task-directory scan, satisfying BOUNDED SCAN
ONLY) and prints one NDJSON line per entry, each carrying the raw fields above plus a computed
`live` boolean and `liveness_reason` string (`pid-alive`|`dead-pid`|`stale-heartbeat`|`corrupt`),
by FACTORING the two-signal computation OUT of `cmd_session_reap` into a shared bash function
(e.g. `session_liveness()`) that both `cmd_session_reap` and the new `cmd_session_list` call —
this is itself a small instance of gap B's spirit (don't let a second consumer re-derive the
same two-signal rule) inside the implementation, worth flagging to the planner even though it is
not one of the three named file_scope overlap transcriptions.

**How the predicate should treat liveness**: per the recorded precision position ("a false
positive costs a deferred task, not silent data loss... do not trade precision for correctness"),
the conservative direction is to treat `live == true` AND `corrupt`/undeterminable entries as
contending (never silently drop a session whose liveness could not be confirmed), while a
confirmed `dead-pid`/`stale-heartbeat` entry should NOT contend — mirroring how a stale *lock*
already warns-and-proceeds rather than blocking. This mirrors the existing `TASK_LOCK_STALE_MIN`
fresh-vs-stale split at the lock layer and should reuse the same "stale acts like it is not there"
philosophy rather than inventing a new one for sessions.

### 7. Preserving the in-batch/cross-batch deferral-direction rule bit-for-bit

The existing rule, verified from the live jq in `orchestrate-batch-admit.sh`:

```jq
($cands | index($other_num)) as $in_batch_idx |
(if $in_batch_idx == null then "cross_batch" else "in_batch" end) as $scope_kind |
select($scope_kind == "cross_batch" or $other_num < $c) |
```

— i.e. `in_batch` collisions only fire against a strictly LOWER `project_number` than the
candidate (`$other_num < $c`); `cross_batch` collisions fire unconditionally (no ordering
constraint) since the colliding task cannot possibly be dispatched this cycle to resolve the
tie the other way. The dependency exclusion (`comparison_set` construction) already drops any
task connected to the candidate by a `dependencies[]` edge in EITHER direction, via:

```jq
select(
  ($t.project_number != $c) and
  ((($t.status // "") | is_terminal) | not) and
  (($c_deps | index($t.project_number)) == null) and
  ((($t.dependencies // []) | index($c)) == null)
)
```

**Preservation requirement for the convergence**: the state.json-derived (`in_batch`/
`cross_batch`) branch and its dependency exclusion must be left structurally untouched — the
session-registry input should be layered as an ADDITIONAL comparison pass (or an additional
evidence annotation on an already-found hit), never as a change to the existing `$other_num < $c`
ordering test or the dependency-edge exclusion predicate above. If the session-registry pass
independently discovers a colliding session whose `task_numbers` include a task connected to the
candidate by a dependency edge, the same dependency-edge exclusion logic must be re-applied there
too (per-task-number, since one session can cover several tasks only some of which may be
edge-connected) — this is a real design question flagged in Finding 3's A1 discussion, not yet
resolved, and should not be silently different from the state.json-branch's own treatment.

## Decisions

(None made by this research task — 945 is research-only. The following are OPEN DESIGN
QUESTIONS the plan must resolve, not decisions made here.)

## Open Design Questions for Planning

1. Shared-lib file shape: `.jq`-only file spliced by both bash callers (recommended), vs. a
   `.sh` lib exporting both a bash function and a jq-def string constant.
2. Schema version: this research recommends `orchestrate-batch-admit-v4` (following the v1→v2,
   v2→v3 precedent of version-bumping on any consumer-visible defer-shape/semantic change), with
   a new `defer_reason` value for a session-registry-only hit, OR corroboration fields added to
   the existing `file_scope_collision` shape — the plan must pick one and write the matching
   Version History entry plus the "every in-repo consumer's status as of v4" table.
3. Whether a session-registry hit that ALSO corresponds to a non-terminal state.json task (the
   common case) should be reported as ONE verdict with combined evidence (`corroborated_by:
   [...]`), or whether the session-registry pass runs independently and can fire on its own even
   when no state.json task matches (e.g. a session covering task numbers not yet in state.json,
   or covering a task whose status the session's own liveness contradicts).
4. Whether/how the dependency-edge exclusion applies per-task-number within a session's
   `task_numbers` array when only some of a session's covered tasks are edge-connected to the
   candidate.
5. `task-lock.sh session-list` field/flag shape (proposed here as a starting point, not final):
   NDJSON, one line per `specs/.sessions/*.json` entry, raw fields plus `live`/`liveness_reason`,
   liveness computed via a `session_liveness()` helper factored out of `cmd_session_reap`.

## Risks & Mitigations

- **Risk**: introducing `orchestrate-batch-admit-v4` without updating both downstream report
  composers' documented "pins no `$schema` literal, already branches on `defer_reason`"
  assumption could leave stale prose in `batch-admit-schema.md`'s own "verified v3-compatible,
  NOT edited" table. **Mitigation**: the v3 entry's table format should be copied for v4 and the
  two composer scripts' actual compatibility re-verified (not assumed from the v2→v3 precedent
  alone), per Finding 3.
- **Risk**: a shared jq-splice lib introduces a new file type/pattern to `scripts/lib/` with no
  existing precedent, unlike the cited `task-reference-patterns.sh` bash precedent. **Mitigation**:
  flagged explicitly as an open fork (Open Design Questions #1) rather than silently decided here.
- **Risk**: session-registry liveness computed twice (once inside `cmd_session_reap`, once inside
  a new `cmd_session_list`) would recreate gap B's exact hazard one layer down. **Mitigation**:
  Finding 6 explicitly recommends factoring liveness into a shared `session_liveness()` helper
  before adding `session-list`.
- **Risk**: Gap C's new batch-admission call in `research.md`/`plan.md`/`implement.md` could be
  wired to move a task to the wrong bucket (`invalid_tasks` instead of `skipped_tasks`, or vice
  versa) — `plan.md`'s existing per-task-acquire-refusal text mentions both `skipped_tasks` AND
  `invalid_tasks` in one sentence while `research.md`/`implement.md` mention only
  `skipped_tasks`. **Mitigation**: the plan should follow each file's own existing bucket-naming
  convention exactly rather than assuming uniformity across the three files.

## Context Extension Recommendations

None — `file-footprint-overlap.md`, `task-lock.md`, and `batch-admit-schema.md` already form a
complete, well-cross-referenced documentation set for this predicate; this task's own deliverable
is to update them, not to create new context files.

## Appendix

### Symbols/anchors referenced (for the plan to grep, not line numbers)

- `scopes_overlap()`, `find_held_locks()`, `get_file_scope()`, `acquire_scope_mutex` —
  `agent-system/extensions/core/scripts/task-lock.sh`
- `session_registry_dir()`, `resolve_session_pid()`, `cmd_session_register`,
  `cmd_session_heartbeat`, `cmd_session_release`, `cmd_session_reap`,
  `SESSION_REGISTRY_REAP_MIN`, `SESSION_REGISTRY_DEAD_PID_MIN` — same file
- `scopes_overlap_first()`, `self_mod_match()`, `is_terminal`, `comparison_set`,
  `collision_scope`, `"orchestrate-batch-admit-v3"` —
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- "Non-Goal: No Reader", "Session-Registry CLI" — `agent-system/extensions/core/context/patterns/task-lock.md`
- "Consumers" section (four bullets), "Non-Goals" section —
  `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
- "Version History", "Why `--invocation-count` Exists", "A1 — dependency-edge exemption
  asymmetry" — `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- `#### Step 2: Generate Batch Session ID`, `#### Step 3: Dispatch Skills`, `session-register`,
  `task-lock.sh acquire ... research/plan/implement` — `agent-system/extensions/core/commands/research.md`,
  `plan.md`, `implement.md`
- "a task that is neither in this invocation's set nor currently holding a lock is invisible to
  all three simultaneously", "Self-Modification Hazard: The Fourth Admission Dimension",
  "Accompanying bounded-scope note" —
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`

### Searches performed

Codebase-only research (no web search needed for this meta/internal-architecture task):
`grep -n scopes_overlap`, `grep -n "overlap|file_scope"` across the four consumer scripts,
targeted `Read` of `file-footprint-overlap.md`, `batch-admit-schema.md`, `task-lock.md`'s
Session-Registry CLI section (lines 607-766), `cmd_session_register`/`cmd_session_heartbeat`/
`cmd_session_release`/`cmd_session_reap` bodies, `research.md`/`plan.md`/`implement.md` multi-task
Step 2/Step 3 anchors, `batch-orchestration-guardrails.md`'s scan-scope-gap and exclude-vs-expand
sections, and threshold-constant `grep` (`TASK_LOCK_STALE_MIN`, `SESSION_REGISTRY_REAP_MIN`,
`SESSION_REGISTRY_DEAD_PID_MIN`).
